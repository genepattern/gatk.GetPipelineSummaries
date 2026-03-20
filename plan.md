## GATK.GetPileupSummaries — GenePattern Module Plan

---

### 1. Module Overview

**Tool**: GATK4 GetPileupSummaries
**GenePattern Module Name**: GATK.GetPileupSummaries
**Version**: 1 (production)
**Docker Image**: broadinstitute/gatk:4.1.4.1
**LSID**: urn:lsid:broad.mit.edu:cancer.software.genepattern.module.generated:37981:1
**Language**: Java (invoked via bash wrapper calling the `gatk` CLI)
**Author**: GenePattern Team
**Categories**: Variant Analysis, Somatic Variant Calling, Quality Control

**Scientific Summary**:
GetPileupSummaries tabulates, at each of a set of common germline SNP sites, the number of reads supporting the reference allele, the first alternate allele, and any other allele. This allele count table is consumed directly by CalculateContamination, which estimates the fraction of reads in a tumor (or normal) BAM that originate from a contaminating individual. This contamination estimate is then applied by FilterMutectCalls to remove spurious somatic variant calls. The tool is Step 2 of the GATK4 Best Practices Somatic Variant Calling Pipeline.

---

### 2. Module Architecture

#### 2.1 Wrapper Script: `gatk_getpileupsummaries_wrapper.sh`
The wrapper is a bash script because GATK is a Java/JVM tool invoked through its CLI. The script:
1. Parses named command-line arguments (--input.bam, --input.bai, etc.)
2. Stages all input files + indexes into the writable job working directory ($PWD)
3. Registers a trap on EXIT to clean up staged files regardless of success/failure
4. Builds and executes the `gatk GetPileupSummaries` command using the staged local copies
5. Optionally passes an --arguments_file for advanced GATK options

#### 2.2 Complete Wrapper Script (gatk_getpileupsummaries_wrapper.sh)
```bash
#!/bin/bash
set -euo pipefail

# ── Parse named arguments ────────────────────────────────────────────────────
BAM_FILE=""
BAI_FILE=""
VCF_FILE=""
VCF_TBI_FILE=""
INTERVALS_FILE=""
INTERVALS_INDEX=""
OUTPUT_NAME="pileup_summary.table"
ARGS_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --input.bam)        BAM_FILE="$2";        shift 2 ;;
    --input.bai)        BAI_FILE="$2";        shift 2 ;;
    --variant.vcf)      VCF_FILE="$2";        shift 2 ;;
    --variant.vcf.tbi)  VCF_TBI_FILE="$2";    shift 2 ;;
    --intervals.file)   INTERVALS_FILE="$2";  shift 2 ;;
    --intervals.index)  INTERVALS_INDEX="$2"; shift 2 ;;
    --output.file.name) OUTPUT_NAME="$2";     shift 2 ;;
    --arguments.file)   ARGS_FILE="$2";       shift 2 ;;
    *) echo "Unknown argument: $1" >&2; shift ;;
  esac
done

# ── Staged local paths ────────────────────────────────────────────────────────
LOCAL_BAM="$PWD/staged_input.bam"
LOCAL_BAI="$PWD/staged_input.bam.bai"
LOCAL_VCF="$PWD/staged_variants.vcf.gz"
LOCAL_VCF_TBI="$PWD/staged_variants.vcf.gz.tbi"
LOCAL_INTERVALS="$PWD/staged_intervals.vcf.gz"
LOCAL_INTERVALS_TBI="$PWD/staged_intervals.vcf.gz.tbi"

# ── Cleanup trap ──────────────────────────────────────────────────────────────
trap 'echo "Cleaning up staged files..."; \
      rm -f "$LOCAL_BAM" "$LOCAL_BAI" \
            "$LOCAL_VCF" "$LOCAL_VCF_TBI" \
            "$LOCAL_INTERVALS" "$LOCAL_INTERVALS_TBI"' EXIT

# ── Stage files ───────────────────────────────────────────────────────────────
echo "Staging BAM and index..."
cp "$BAM_FILE" "$LOCAL_BAM"
cp "$BAI_FILE" "$LOCAL_BAI"

echo "Staging VCF and index..."
cp "$VCF_FILE" "$LOCAL_VCF"
cp "$VCF_TBI_FILE" "$LOCAL_VCF_TBI"

echo "Staging intervals file and index..."
cp "$INTERVALS_FILE" "$LOCAL_INTERVALS"
cp "$INTERVALS_INDEX" "$LOCAL_INTERVALS_TBI"

# ── Build GATK command ────────────────────────────────────────────────────────
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

# ── Execute GATK ──────────────────────────────────────────────────────────────
echo "Running GATK GetPileupSummaries..."
gatk "${GATK_ARGS[@]}"

echo "Done. Output written to: $OUTPUT_NAME"
```

---

### 3. Parameter Definitions

All parameters follow GenePattern naming conventions (lowercase, dot-separated).

#### GROUP 1: Required Input Files

**input.bam** (File, Required)
- GATK flag: -I / --input
- Accepted formats: BAM, SAM, CRAM
- Must be coordinate-sorted
- Must have a corresponding index file provided via input.bai
- Example: normal.bam

**input.bai** (File, Required)
- Not a direct GATK flag; staged as co-located index
- Accepted formats: BAI, CRAI, CSI
- Must correspond exactly to input.bam
- Staged to $PWD/staged_input.bam.bai alongside the BAM
- Example: normal.bai

**variant.vcf** (File, Required)
- GATK flag: -V / --variant
- Accepted formats: VCF, VCF.GZ (bgzipped), BCF
- Must contain AF INFO field with population allele frequencies
- Must be indexed (see variant.vcf.tbi)
- Recommended: small_exac_common_3.hg38.vcf.gz (GATK resource bundle)
- Example: chr17_small_exac_common_3_grch38.vcf.gz

**variant.vcf.tbi** (File, Required)
- Not a direct GATK flag; staged as co-located index
- Accepted formats: TBI, IDX
- Must correspond exactly to variant.vcf
- Staged to $PWD/staged_variants.vcf.gz.tbi alongside the VCF
- Example: chr17_small_exac_common_3_grch38.vcf.gz.tbi

**intervals.file** (File, Required)
- GATK flag: -L / --intervals
- Accepted formats: VCF, VCF.GZ, BED, LIST, INTERVAL_LIST
- REQUIRED even though not always documented as such
- Standard practice: use the same file as variant.vcf
- Must be indexed (see intervals.index)

**intervals.index** (File, Required)
- Not a direct GATK flag; staged as co-located index
- Accepted formats: TBI, IDX
- Must correspond exactly to intervals.file
- Staged to $PWD/staged_intervals.vcf.gz.tbi alongside the intervals file

#### GROUP 2: Output

**output.file.name** (Text, Required)
- GATK flag: -O / --output
- Default: pileup_summary.table
- Output format: tab-separated with columns: contig, position, ref_count, alt_count, other_alt_count, allele_frequency
- Used directly as input to GATK CalculateContamination

#### GROUP 3: Advanced Options

**arguments.file** (File, Optional)
- GATK flag: --arguments_file
- Plain text file, one argument or key=value per line
- For passing any GATK options not exposed in the UI, e.g.:
  --tumor-sample MY_SAMPLE_NAME
  --max-depth-per-sample 500
  --java-options -Xmx16g
  --tmp-dir /tmp/gatk

---

### 4. Command Line

```
bash <libdir>gatk_getpileupsummaries_wrapper.sh \
  --input.bam <input.bam> \
  --input.bai <input.bai> \
  --variant.vcf <variant.vcf> \
  --variant.vcf.tbi <variant.vcf.tbi> \
  --intervals.file <intervals.file> \
  --intervals.index <intervals.index> \
  --output.file.name <output.file.name> \
  <arguments.file>
```

Note: arguments.file uses prefix_only_if_value=true, so GenePattern only includes the --arguments.file flag when the user provides a value.

---

### 5. File Staging Architecture (CRITICAL)

GATK requires BAM, VCF, and intervals index files to reside in the SAME DIRECTORY as their parent files. GenePattern's input staging directory may be read-only, so:

1. ALL files (BAM+BAI, VCF+TBI, intervals+index) are copied into $PWD (the writable job working directory)
2. GATK is invoked with the local $PWD copies
3. A bash `trap EXIT` ensures cleanup of ALL staged files whether GATK succeeds or fails
4. The output table is written directly to $PWD (the job working directory) and is NOT cleaned up

Staged file naming convention:
- $PWD/staged_input.bam      ← BAM
- $PWD/staged_input.bam.bai  ← BAI (GATK discovers this automatically)
- $PWD/staged_variants.vcf.gz      ← VCF
- $PWD/staged_variants.vcf.gz.tbi  ← TBI (GATK discovers automatically)
- $PWD/staged_intervals.vcf.gz     ← intervals
- $PWD/staged_intervals.vcf.gz.tbi ← intervals index (GATK discovers automatically)

---

### 6. Output Format

The output pileup summary table (default: pileup_summary.table) is a tab-separated file with the following columns:

| Column | Type | Description |
|--------|------|-------------|
| contig | String | Chromosome/scaffold |
| position | Integer | 1-based genomic position |
| ref_count | Integer | Reads supporting reference allele |
| alt_count | Integer | Reads supporting first alternate allele |
| other_alt_count | Integer | Reads supporting any other allele |
| allele_frequency | Float | Population AF from variant VCF |

This table is the direct, unmodified input to GATK CalculateContamination.

---

### 7. Docker and Runtime Requirements

- **Docker Image**: broadinstitute/gatk:4.1.4.1 (use EXACTLY as specified)
- **CPU**: 2 cores (Java GC benefits from multiple cores)
- **Memory**: 8 GB (4 GB for WES; 8-16 GB recommended for WGS)
- **Runtime**: ~15-30 min WES; ~2-4 hr WGS
- **Java**: Bundled in GATK Docker image
- Note: For high-coverage WGS or deeply sequenced samples, users can increase JVM heap via --java-options "-Xmx16g" in an arguments.file

---

### 8. Validation and Testing

#### Test Data
- normal.bam (chr17-restricted, coordinate sorted)
- chr17_small_exac_common_3_grch38.vcf.gz (common ExAC variants on chr17, GRCh38)
- chr17_small_exac_common_3_grch38.vcf.gz.tbi (tabix index)
- Use the VCF as BOTH variant.vcf AND intervals.file (standard GATK pattern)
- Use the TBI as BOTH variant.vcf.tbi AND intervals.index

#### Test Validation Criteria
1. Output file exists and is non-empty
2. Output has exactly 6 tab-separated columns
3. Header line starts with #[GetPileupSummaries]
4. allele_frequency column contains values between 0 and 1
5. All staged files are cleaned up after completion
6. Output is parseable by gatk CalculateContamination

#### Error Cases to Test
- Missing BAI file → GATK should fail with clear error
- Read-only staging directory → wrapper must still succeed via $PWD staging
- GATK failure → trap must still clean up staged files
- Empty arguments.file → no --arguments_file flag should be passed

---

### 9. Pipeline Context

```
BAM (tumor/normal)
       │
       ▼
[GATK.GetPileupSummaries]  ← This module
       │ pileup_summary.table
       ▼
[GATK.CalculateContamination]
       │ contamination.table + segments.table
       ▼
[GATK.FilterMutectCalls]  ← combined with Mutect2 raw VCF
       │
       ▼
Filtered somatic VCF
```

---

### 10. Implementation Roadmap

1. **Phase 1 - Wrapper Development**: Write and unit-test gatk_getpileupsummaries_wrapper.sh with staging/cleanup logic
2. **Phase 2 - Docker Testing**: Validate wrapper inside broadinstitute/gatk:4.1.4.1 container
3. **Phase 3 - GenePattern Module Manifest**: Create module.yaml / manifest with all parameters
4. **Phase 4 - Integration Testing**: Run full test with provided example data on GenePattern server
5. **Phase 5 - Documentation**: Write user-facing help text and parameter descriptions
6. **Phase 6 - Release**: Publish to GenePattern module repository