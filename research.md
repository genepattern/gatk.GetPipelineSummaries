---

# Comprehensive Research Report: `gatk.GetPileupSummaries`

---

## 1. Tool Purpose and Scientific Applications

### Overview
`GetPileupSummaries` is a GATK4 tool that **summarizes per-site read counts** supporting the reference allele, the first alternate allele, and any other alleles at genomic positions specified in a population variant VCF. Its sole purpose within the GATK ecosystem is to generate the allele-count table consumed by `CalculateContamination`, which then estimates cross-sample contamination fractions used to filter somatic variant calls.

### Scientific Context
| Aspect | Detail |
|--------|--------|
| **Primary Use** | Quantify allele support at common germline SNP sites as prerequisite for contamination estimation |
| **Research Domain** | Cancer genomics, somatic variant calling, tumor sequencing QC |
| **Biological Rationale** | At common heterozygous SNP sites, contaminating DNA introduces reads at unexpected allele ratios; counting these deviations reveals contamination fraction |
| **Pipeline Role** | Step 2 (of 6) in GATK Best Practices somatic pipeline — after Mutect2, before CalculateContamination |
| **Output Consumer** | `CalculateContamination` → `FilterMutectCalls` |

### Key Applications
- **Tumor contamination estimation**: Determine what fraction of tumor BAM reads originate from a different individual (cross-sample contamination)
- **Matched normal contamination**: Run on both tumor and matched normal to improve contamination estimates
- **Tumor-only workflows**: Run without matched normal using a population allele frequency resource
- **Quality control**: Pre-analysis QC step before somatic variant interpretation
- **Cohort-level QC**: Identify mislabeled or swapped samples in large sequencing studies

---

## 2. Input/Output Formats and Requirements

### Input Files

#### Required Input 1: Aligned Reads (`-I / --input`)
| Property | Detail |
|----------|--------|
| **Formats** | BAM (`.bam`), SAM (`.sam`), CRAM (`.cram`) |
| **Sorting** | Must be **coordinate-sorted** |
| **Index** | `.bai` for BAM; `.crai` or `.csi` for CRAM — **must be co-located** |
| **Multi-sample** | Allowed; use `--tumor-sample` to specify SM tag |
| **Deduplication** | Recommended (MarkDuplicates) but not enforced |
| **Base Quality Recalibration** | Recommended (BQSR) but not required |

#### Required Input 2: Variant Sites VCF (`-V / --variant`)
| Property | Detail |
|----------|--------|
| **Formats** | VCF (`.vcf`), bgzipped VCF (`.vcf.gz`), BCF (`.bcf`) |
| **Index** | `.tbi` for VCF.gz; `.idx` for uncompressed VCF — **must be co-located** |
| **Content** | Common germline SNP sites (AF > 5% recommended) |
| **AF field** | `AF` INFO field used directly; if absent, MAF computed from genotypes |
| **Recommended resources** | `small_exac_common_3.hg38.vcf.gz`, `af-only-gnomad.hg38.vcf.gz` |
| **Genome build** | Must match the BAM reference (hg38/GRCh38 or hg19/GRCh37) |

#### Required Input 3: Intervals (`-L / --intervals`)
| Property | Detail |
|----------|--------|
| **Formats** | VCF, BED, Picard `.interval_list`, GATK strings (`chr1:1-1000`), `.list` files |
| **Index** | Required when using a file (`.tbi` for VCF.gz intervals) — **must be co-located** |
| **Common practice** | **Use the same file as `-V`** (variant VCF serves as both sites and intervals) |
| **Purpose** | Restricts traversal to specified regions for efficiency |
| **⚠️ Note** | Despite not always appearing in simplified documentation, **this argument is required** |

#### Optional Input 4: Arguments File (`--arguments_file`)
| Property | Detail |
|----------|--------|
| **Format** | Plain text; one argument/value pair per line |
| **Use case** | Pass additional GATK parameters without explicit module parameters |

### Output Files

#### Primary Output: Pileup Summary Table (`-O / --output`)
```
#[GetPileupSummaries] ... version header ...
contig    position    ref_count    alt_count    other_alt_count    allele_frequency
chr1      10000        45            3             1                 0.061
chr1      20000        38            0             0                 0.023
chr17     7674220     102            5             2                 0.048
```

| Column | Type | Description |
|--------|------|-------------|
| `contig` | String | Chromosome/scaffold name |
| `position` | Integer | 1-based genomic position |
| `ref_count` | Integer | Read count supporting reference allele |
| `alt_count` | Integer | Read count supporting first alternate allele |
| `other_alt_count` | Integer | Read count supporting any other allele |
| `allele_frequency` | Float | Population AF from input VCF |

**This table is the direct, unmodified input to `CalculateContamination`.**

---

## 3. Parameter Analysis and Usage Patterns

### The Four Required Arguments

```bash
gatk GetPileupSummaries \
  -I  <input.bam>           \   # Coordinate-sorted, indexed BAM
  -V  <variants.vcf.gz>     \   # Common SNP sites with AF
  -L  <intervals.vcf.gz>    \   # Genomic intervals (often same as -V)
  -O  <output.table>            # Output pileup summary table
```

### Key Optional Parameters

| Parameter | Default | Biological Significance |
|-----------|---------|------------------------|
| `--tumor-sample` | null | SM tag from BAM header; required for multi-sample BAMs |
| `--max-depth-per-sample` | 200 | Higher values improve sensitivity but increase memory; for deeply sequenced tumors consider increasing |
| `--interval-padding` | 0 | Adds flanking bases around each interval |
| `--interval-set-rule` | UNION | UNION or INTERSECTION when multiple -L provided |
| `--read-validation-stringency` | SILENT | STRICT will fail on malformed reads; SILENT ignores them |
| `--disable-sequence-dictionary-validation` | false | Use if BAM/VCF headers have compatible but non-identical contigs |
| `--tmp-dir` | system | Specify for HPC environments with limited /tmp |
| `--arguments_file` | null | Pass additional arguments; the GenePattern module's escape valve |

### Parameter Groups for GenePattern UI

```
GROUP 1 — Required Inputs (always shown):
  input.bam, input.bai, variant.vcf.gz, variant.vcf.gz.tbi,
  intervals.file, intervals.index, output.file.name

GROUP 2 — Sample Options (advanced):
  --tumor-sample, --max-depth-per-sample

GROUP 3 — Additional Arguments (advanced):
  --arguments_file (for any other GATK options)
```

---

## 4. Installation and Dependency Requirements

### Runtime Dependencies
| Component | Version | Notes |
|-----------|---------|-------|
| **Java** | 8+ (GATK 4.0–4.2); Java 17 supported in GATK 4.3+ | JRE sufficient; JDK not needed |
| **GATK4 JAR** | 4.4.0.0 (latest stable) | All Picard/HTSJDK/Tribble bundled |
| **Samtools** | Optional | For pre-processing; not needed at runtime |

### Docker (Recommended for GenePattern)
```bash
# Official Broad image (recommended)
docker pull broadinstitute/gatk:latest
docker pull broadinstitute/gatk:4.4.0.0

# Run GATK within container
docker run --rm -v /data:/data broadinstitute/gatk:4.4.0.0 \
  gatk GetPileupSummaries -I /data/tumor.bam ...
```

### Conda Installation
```bash
conda install -c bioconda gatk4
# or
conda create -n gatk4 -c bioconda gatk4
```

### Direct Download
```bash
# From GitHub releases
wget https://github.com/broadinstitute/gatk/releases/download/4.4.0.0/gatk-4.4.0.0.zip
unzip gatk-4.4.0.0.zip
./gatk-4.4.0.0/gatk GetPileupSummaries --help
```

### System Resources
| Resource | Minimum | Recommended |
|----------|---------|-------------|
| RAM | 4 GB | 8–16 GB (WGS) |
| CPU | 1 core | 2–4 cores (Java GC benefit) |
| Disk I/O | HDD | SSD strongly preferred |
| Runtime (WES) | ~15 min | ~30 min |
| Runtime (WGS) | ~2 hr | ~4 hr |

---

## 5. Common Workflows and Use Cases

### Primary Workflow: GATK4 Somatic Best Practices Pipeline

```
BAM (tumor) ──────────────────────────────────┐
                                               ▼
                                   GetPileupSummaries (tumor) ──┐
                                                                  ▼
BAM (normal, optional) ──────────────────────►GetPileupSummaries (normal)──►CalculateContamination──►FilterMutectCalls
                                                                                                              ▲
BAM (tumor) ──► Mutect2 ──► raw.vcf ──────────────────────────────────────────────────────────────────────────┘
```

### Workflow Step-by-Step

```bash
# Step 1: Mutect2 somatic calling
gatk Mutect2 -R ref.fa -I tumor.bam -I normal.bam \
  -normal NORMAL_SM -O somatic_raw.vcf.gz ...

# Step 2a: GetPileupSummaries on tumor
gatk GetPileupSummaries \
  -I tumor.bam \
  -V small_exac_common_3.hg38.vcf.gz \
  -L small_exac_common_3.hg38.vcf.gz \
  -O tumor_pileups.table

# Step 2b: GetPileupSummaries on matched normal (optional but improves accuracy)
gatk GetPileupSummaries \
  -I normal.bam \
  -V small_exac_common_3.hg38.vcf.gz \
  -L small_exac_common_3.hg38.vcf.gz \
  -O normal_pileups.table

# Step 3: CalculateContamination
gatk CalculateContamination \
  -I tumor_pileups.table \
  -matched normal_pileups.table \
  -O contamination.table \
  --tumor-segmentation segments.table

# Step 4: FilterMutectCalls
gatk FilterMutectCalls \
  -R ref.fa -V somatic_raw.vcf.gz \
  --contamination-table contamination.table \
  --tumor-segmentation segments.table \
  -O somatic_filtered.vcf.gz
```

### Test Data Pattern (from provided example)
The test data provided (`normal.bam`, `chr17_small_exac_common_3_grch38.vcf.gz`, `.tbi`) represents a **chr17-restricted ExAC common variants resource** typical of WES pilot testing. The VCF serves as **both `-V` and `-L`**, which is the standard GATK practice.

---

## 6. GenePattern Integration — Critical Implementation Details

### ⚠️ Critical File Staging Architecture

Because GATK requires index files to be **co-located** with their parent files in the **same directory**, and the GenePattern input staging directory **may be read-only**, all input files must be **copied to the writable job working directory** before invoking GATK.

#### Complete Wrapper Script Template

```bash
#!/bin/bash
set -euo pipefail

# ── GenePattern parameter bindings ──────────────────────────────────────────
BAM_FILE="$1"        # input BAM file
BAI_FILE="$2"        # BAM index (.bai)
VCF_FILE="$3"        # variant sites VCF (.vcf.gz)
VCF_TBI_FILE="$4"    # VCF tabix index (.vcf.gz.tbi)
INTERVALS_FILE="$5"  # intervals file (may be same as VCF)
INTERVALS_TBI="$6"   # intervals index (.vcf.gz.tbi)
OUTPUT_NAME="${7:-pileup_summary.table}"   # output file name
ARGS_FILE="${8:-}"   # optional arguments file

# ── Staged local paths in writable working directory ────────────────────────
LOCAL_BAM="$PWD/staged_input.bam"
LOCAL_BAI="$PWD/staged_input.bam.bai"
LOCAL_VCF="$PWD/staged_variants.vcf.gz"
LOCAL_VCF_TBI="$PWD/staged_variants.vcf.gz.tbi"
LOCAL_INTERVALS="$PWD/staged_intervals.vcf.gz"
LOCAL_INTERVALS_TBI="$PWD/staged_intervals.vcf.gz.tbi"

# ── Cleanup trap: always runs on EXIT (success or failure) ──────────────────
trap 'echo "Cleaning up staged files..."; \
      rm -f "$LOCAL_BAM" "$LOCAL_BAI" \
            "$LOCAL_VCF" "$LOCAL_VCF_TBI" \
            "$LOCAL_INTERVALS" "$LOCAL_INTERVALS_TBI"' EXIT

# ── Stage files into writable working directory ─────────────────────────────
echo "Staging BAM and index..."
cp "$BAM_FILE" "$LOCAL_BAM"
cp "$BAI_FILE" "$LOCAL_BAI"

echo "Staging VCF and index..."
cp "$VCF_FILE" "$LOCAL_VCF"
cp "$VCF_TBI_FILE" "$LOCAL_VCF_TBI"

echo "Staging intervals and index..."
cp "$INTERVALS_FILE" "$LOCAL_INTERVALS"
cp "$INTERVALS_TBI" "$LOCAL_INTERVALS_TBI"

# ── Build GATK command ───────────────────────────────────────────────────────
GATK_ARGS=(
  GetPileupSummaries
  -I  "$LOCAL_BAM"
  -V  "$LOCAL_VCF"
  -L  "$LOCAL_INTERVALS"
  -O  "$OUTPUT_NAME"
)

if [[ -n "$ARGS_FILE" ]]; then
  GATK_ARGS+=(--arguments_file "$ARGS_FILE")
fi

# ── Execute ──────────────────────────────────────────────────────────────────
echo "Running GATK GetPileupSummaries..."
gatk "${GATK_ARGS[@]}"

echo "Done. Output written to: $OUTPUT_NAME"
```

### GenePattern Module Manifest Parameters

| GP Param Name | Type | Required | GATK Flag | Notes |
|--------------|------|----------|-----------|-------|
| `input.bam` | File | ✅ | `-I` (staged) | `.bam` file |
| `input.bai` | File | ✅ | staged with BAM | `.bai` index; staged as `staged_input.bam.bai` |
| `variant.vcf.gz` | File | ✅ | `-V` (staged) | bgzipped VCF with AF annotations |
| `variant.vcf.gz.tbi` | File | ✅ | staged with VCF | `.tbi` tabix index |
| `intervals.file` | File | ✅ | `-L` (staged) | Can be same file as `variant.vcf.gz` |
| `intervals.index` | File | ✅ | staged with intervals | `.tbi` or `.idx` index |
| `output.file.name` | String | ✅ | `-O` | Default: `pileup_summary.table` |
| `arguments.file` | File | ❌ | `--arguments_file` | Pass any additional GATK args |

### File Index Co-location Rules

```
✅ CORRECT: Both BAM and BAI in same directory
  $PWD/staged_input.bam
  $PWD/staged_input.bam.bai    ← GATK auto-discovers this

✅ CORRECT: VCF and TBI in same directory  
  $PWD/staged_variants.vcf.gz
  $PWD/staged_variants.vcf.gz.tbi   ← GATK auto-discovers this

✅ CORRECT: Intervals and index in same directory
  $PWD/staged_intervals.vcf.gz
  $PWD/staged_intervals.vcf.gz.tbi   ← GATK auto-discovers this

❌ WRONG: Staging to read-only input directory
  /data/input_staging/input.bam     ← May not be writable
  /data/input_staging/input.bam.bai ← Cannot write index here
```

---

## 7. Comparative Ecosystem Analysis

### Tool Positioning

| Tool | Role in Somatic Pipeline | Relationship to GetPileupSummaries |
|------|-------------------------|-------------------------------------|
| **GetPileupSummaries** | Allele count collection | **Target tool** |
| **CalculateContamination** | Contamination fraction estimation | Direct downstream consumer |
| **FilterMutectCalls** | Somatic variant filtering | Uses contamination output |
| **Mutect2** | Somatic variant calling | Upstream; its output is filtered using contamination |
| **VerifyBamID2** | Alternative contamination method | SVD-based; no VCF sites required; not part of GATK pipeline |
| **CollectAllelicCounts** | Allele counting for CNV analysis | Similar mechanism; different purpose (CNV vs contamination) |
| **Samtools mpileup** | General pileup | Predecessor approach; requires custom parsing |

### Why GetPileupSummaries for GenePattern?
- **Native GATK4 integration**: Output format is precisely what `CalculateContamination` expects — no conversion
- **Standard of care**: Required step in GATK Mutect2 somatic Best Practices pipeline, used by thousands of cancer genomics studies
- **Simple parameterization**: Only 4 required arguments (+ 3 index files)
- **Well-validated**: Peer-reviewed across TCGA, PCAWG, and clinical sequencing contexts
- **Dockerized**: `broadinstitute/gatk:latest` provides a fully self-contained, portable environment

---

## 8. Known Issues and Caveats

| Issue | Details | Mitigation |
|-------|---------|------------|
| **Index co-location** | GATK refuses to run if index not in same directory as parent file | Stage both files to working directory (implemented in wrapper) |
| **Read-only staging** | GenePattern input staging may be read-only | Copy to `$PWD` before execution; use trap for cleanup |
| **Intervals required** | `-L` is required even though some documentation omits it | Always include intervals parameter in module |
| **Reference genome mismatch** | BAM and VCF must use same genome build | Document supported builds; validate contig names |
| **Low-coverage sites** | Sites with zero coverage are silently excluded from output | Normal behavior; downstream tools handle sparse tables |
| **Multi-sample BAM** | Without `--tumor-sample`, tool processes all reads | Expose `--tumor-sample` as optional parameter |
| **Java version** | GATK 4.3+ requires Java 11+; earlier versions need Java 8 | Pin Docker image to specific GATK version |
| **Memory** | WGS with high-coverage BAM may require >8GB | Set JVM `-Xmx` via `--java-options` |
| **Temp disk space** | Large BAMs create substantial temp files | Set `--tmp-dir` to a location with sufficient space |

---

## 9. Resource Files and References

### GATK Resource Bundle (Common Variant Sites)
```
# GRCh38/hg38
gs://gatk-best-practices/somatic-hg38/small_exac_common_3.hg38.vcf.gz
gs://gatk-best-practices/somatic-hg38/af-only-gnomad.hg38.vcf.gz

# GRCh37/hg19
gs://gatk-best-practices/somatic-b37/small_exac_common_3_b37.vcf.gz

# Public HTTP access
https://console.cloud.google.com/storage/browser/genomics-public-data/resources/broad/hg38/v0
```

### Key References
1. **GATK Best Practices**: Van der Auwera & O'Connor, *Genomics in the Cloud* (O'Reilly, 2020)
2. **Somatic Pipeline Paper**: Cibulskis et al., *Nature Biotechnology* 31, 213–219 (2013) — MuTect (predecessor)
3. **GATK4 Framework**: DePristo et al., *Nature Genetics* 43, 491–498 (2011)
4. **Official Tool Docs**: https://gatk.broadinstitute.org/hc/en-us/articles/360037593451-GetPileupSummaries
5. **WDL Workflow**: https://github.com/broadinstitute/gatk/blob/master/scripts/mutect2_wdl/mutect2.wdl
6. **Docker Hub**: https://hub.docker.com/r/broadinstitute/gatk

---

## 10. Summary Checklist for GenePattern Module Development

```
□ PARAMETERS (4 required GATK args + 3 paired index files + 1 output name)
  ☑ -I  input.bam         → paired with input.bai
  ☑ -V  variant.vcf.gz    → paired with variant.vcf.gz.tbi
  ☑ -L  intervals.file    → paired with intervals.index
  ☑ -O  output.file.name  → string, default "pileup_summary.table"
  ☑ --arguments_file      → optional, for additional GATK args

□ WRAPPER SCRIPT REQUIREMENTS
  ☑ Stage BAM + BAI to $PWD before GATK invocation
  ☑ Stage VCF + TBI to $PWD before GATK invocation
  ☑ Stage intervals + index to $PWD before GATK invocation
  ☑ trap 'rm -f ...' EXIT for guaranteed cleanup on success OR failure
  ☑ Pass local $PWD copies to GATK -I, -V, -L flags
  ☑ NEVER write indexes to input staging directory

□ DOCKER / RUNTIME
  ☑ Use broadinstitute/gatk:4.4.0.0 (or :latest)
  ☑ Java heap: configure via --java-options "-Xmx4g" (or higher for WGS)

□ TESTING
  ☑ Test data: normal.bam + chr17_small_exac_common_3_grch38.vcf.gz + .tbi
  ☑ Use VCF as both -V and -L (standard GATK pattern)
  ☑ Verify output .table has correct 6-column format
  ☑ Verify output is parseable by CalculateContamination
```