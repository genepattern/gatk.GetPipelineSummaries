# gatk.GetPileupSummaries (v1)

**Description**: Tabulates pileup metrics — counts of reads supporting the reference allele, the alternate allele, and other alleles — at a set of common biallelic variant sites. The resulting table is the required input for GATK's CalculateContamination tool, which estimates cross-sample contamination in sequencing data.
**Authors**: Broad Institute of MIT and Harvard; GenePattern Team, UC San Diego
**Contact**: [GenePattern Community Forum](https://groups.google.com/g/genepattern-help)
**Algorithm Version**: GATK 4.x GetPileupSummaries

## Summary

Cross-sample contamination — the presence of DNA from one individual in a sequencing library intended to represent a different individual — is a significant source of artifact in somatic variant calling pipelines. Even low levels of contamination (e.g., 1–2%) can inflate false-positive somatic variant calls, particularly for low-allele-fraction mutations.

**gatk.GetPileupSummaries** is the first step in GATK's contamination-estimation workflow. Given an aligned BAM file and a reference panel of common germline variant sites (population allele frequency > ~5%), this module counts how many sequencing reads at each site support:

- The **reference allele** (`ref_count`)
- The **alternate allele** (`alt_count`)
- **Other alleles** not matching reference or alternate (`other_alt_count`)

These site-level pileup counts are written to a tab-separated table, which is then passed directly to **gatk.CalculateContamination** to compute a per-sample contamination estimate.

**Typical workflow:**

```
Aligned BAM
     │
     ▼
gatk.GetPileupSummaries  ──►  pileup_summary.table
                                      │
                                      ▼
                         gatk.CalculateContamination  ──►  contamination.table
                                                                    │
                                                                    ▼
                                                         Mutect2 FilterMutectCalls
```

**What sites should I use?** The variant VCF input (and corresponding intervals) should contain common biallelic SNPs from a large population database such as [gnomAD](https://gnomad.broadinstitute.org/) or ExAC. The GATK resource bundle provides pre-filtered VCFs suitable for this purpose (e.g., `small_exac_common_3.hg38.vcf.gz`). Sites are chosen to be common enough that a contaminated sample will predictably carry reads from a different individual's alleles.

**Important notes on input staging:** Because GenePattern's input staging directory may be read-only on the server, the wrapper script copies the BAM, BAM index, VCF, VCF index, intervals file, and intervals index into the writable job working directory before invoking GATK. After the job completes (successfully or with an error), all locally staged copies are automatically removed. Users do not need to take any special action; this behavior is handled transparently by the wrapper.

## References

1. Van der Auwera, G.A. & O'Connor, B.D. (2020). *Genomics in the Cloud: Using Docker, GATK, and WDL in Terra*. O'Reilly Media.
2. McKenna, A. et al. (2010). The Genome Analysis Toolkit: A MapReduce framework for analyzing next-generation DNA sequencing data. *Genome Research*, 20(9):1297–1303. [https://doi.org/10.1101/gr.107524.110](https://doi.org/10.1101/gr.107524.110)
3. Poplin, R. et al. (2018). Scaling accurate genetic variant discovery to tens of thousands of samples. *bioRxiv*. [https://doi.org/10.1101/201178](https://doi.org/10.1101/201178)
4. GATK GetPileupSummaries tool documentation: [https://gatk.broadinstitute.org/hc/en-us/articles/360037593451-GetPileupSummaries](https://gatk.broadinstitute.org/hc/en-us/articles/360037593451-GetPileupSummaries)
5. GATK Resource Bundle: [https://gatk.broadinstitute.org/hc/en-us/articles/360035890811-Resource-bundle](https://gatk.broadinstitute.org/hc/en-us/articles/360035890811-Resource-bundle)

## Source Links

* [GenePattern gatk.GetPileupSummaries source repository](https://github.com/genepattern/gatk.GetPileupSummaries)
* [Docker image: ghcr.io/genepattern/gatk_getpileupsummaries:latest](https://ghcr.io/genepattern/gatk_getpileupsummaries)
* [GATK Official Docker image: broadinstitute/gatk](https://hub.docker.com/r/broadinstitute/gatk)

## Parameters

| Name | Description | Default Value |
| :--- | :--- | :--- |
| input bam \* | Coordinate-sorted, indexed BAM file containing the aligned reads to be analyzed. A corresponding BAM index file (`.bai`) must be provided separately via the **input bam index** parameter. | — |
| input bam index \* | The BAM index file (`.bai`) corresponding to the **input bam**. Both files are staged together into the job working directory before GATK is invoked. | — |
| variant vcf \* | bgzipped VCF file (`.vcf.gz`) containing common biallelic germline variant sites with population allele frequency annotations (AF INFO field). Recommended source: GATK resource bundle (e.g., `small_exac_common_3.hg38.vcf.gz`). A tabix index (`.vcf.gz.tbi`) must be provided via **variant vcf index**. | — |
| variant vcf index \* | Tabix index file (`.vcf.gz.tbi`) corresponding to the **variant vcf**. Both the VCF and its index are staged together into the job working directory before GATK is invoked. | — |
| intervals \* | Genomic intervals file specifying which sites to include in the pileup analysis. Typically the same file as the **variant vcf**. Accepts GATK-supported interval formats (bgzipped VCF, BED, Picard interval_list, `.list`). A corresponding index file must be supplied via **intervals index**. | — |
| intervals index \* | Index file for the **intervals** file (e.g., `.vcf.gz.tbi` for a bgzipped VCF intervals file). Both the intervals file and its index are staged together into the job working directory before GATK is invoked. | — |
| output filename \* | The desired name for the output pileup summary table file (e.g., `sample_pileups.table`). This tab-separated file is the direct input to gatk.CalculateContamination. | `output_pileup_summary.table` |
| arguments file | Optional text file containing additional GATK arguments to pass to GetPileupSummaries, one argument (or `argument=value` pair) per line. Use this to specify advanced options not exposed as explicit module parameters (e.g., `--max-depth-per-sample`, `--java-options`, `--tmp-dir`). Passed to GATK as `--arguments_file`. | — |

\* required

## Input Files

1. **input bam**
   A coordinate-sorted, indexed BAM (Binary Alignment Map) file containing the sequencing reads to be analyzed. This file must be sorted by genomic coordinate (not by read name). The BAM file corresponds to the sample for which you want to estimate contamination — typically a tumor sample in a somatic variant calling workflow, though normal samples can also be processed. The file is passed to GATK via the `-I` / `--input` argument.
   - **Format**: Binary BAM (`.bam`)
   - **Requirements**: Coordinate-sorted; must have a corresponding `.bai` index file provided as a separate input
   - **Note**: The wrapper script copies both the BAM and its index into the writable job working directory prior to GATK invocation to avoid read-only staging directory issues.

2. **input bam index**
   The BAM index file corresponding to the **input bam**. GATK requires the index to be present alongside the BAM file (same directory, same base name) to enable random-access retrieval of reads at specific genomic loci.
   - **Format**: BAM index (`.bai`)
   - **Requirements**: Must match the **input bam** exactly (same base filename, e.g., `sample.bam` → `sample.bam.bai` or `sample.bai`)
   - **Note**: Staged into the same working directory as the BAM file by the wrapper script.

3. **variant vcf**
   A bgzipped VCF file containing a curated panel of common biallelic germline variant sites. Each site must have a population allele frequency annotation in the `AF` INFO field. These sites are used by GATK to count read support for reference and alternate alleles. The genome build of this VCF must match the genome build used for read alignment. The file is passed to GATK via the `-V` / `--variant` argument.
   - **Format**: bgzipped VCF (`.vcf.gz`)
   - **Recommended sources**:
     - `small_exac_common_3.hg38.vcf.gz` (GATK resource bundle — hg38)
     - `small_exac_common_3.hg19.vcf.gz` (GATK resource bundle — hg19/GRCh37)
     - `af-only-gnomad.hg38.vcf.gz` filtered to common sites
   - **Requirements**: Must have a tabix index (`.vcf.gz.tbi`) supplied via **variant vcf index**; genome build must match the BAM file
   - **Note**: Staged into the job working directory alongside its index by the wrapper script.

4. **variant vcf index**
   The tabix index file for the **variant vcf**. GATK requires the tabix index to be present in the same directory as the VCF for rapid random-access queries.
   - **Format**: Tabix index (`.vcf.gz.tbi`)
   - **Requirements**: Must correspond to the **variant vcf** (same base filename)
   - **Note**: Staged into the same working directory as the VCF file by the wrapper script.

5. **intervals**
   A file specifying the genomic intervals (regions) at which pileup counts should be computed. In the standard contamination estimation workflow, this is the **same file** as the **variant vcf** — restricting analysis to those known common-variant sites is both efficient and appropriate. Providing an intervals file is required to ensure GATK does not attempt to process the entire genome, which would be computationally prohibitive and would include uninformative sites.
   - **Accepted formats**: bgzipped VCF (`.vcf.gz`), BED (`.bed`), Picard interval list (`.interval_list`), GATK-format list file (`.list`), or a plain text file of `chr:start-end` interval strings
   - **Typical usage**: Supply the same file used for **variant vcf**
   - **Requirements**: Must have a corresponding index file supplied via **intervals index**
   - **Note**: Staged into the job working directory alongside its index by the wrapper script.

6. **intervals index**
   The index file for the **intervals** file. If the intervals file is a bgzipped VCF, provide the corresponding `.vcf.gz.tbi` tabix index. This index enables GATK to efficiently retrieve interval information.
   - **Format**: Tabix index (`.vcf.gz.tbi`) for bgzipped VCF intervals; `.idx` for uncompressed VCF or other formats
   - **Requirements**: Must correspond to the **intervals** file
   - **Note**: Staged into the same working directory as the intervals file by the wrapper script.

7. **arguments file** *(optional)*
   A plain-text file containing additional GATK command-line arguments, one per line or as `argument=value` pairs. This provides access to all GetPileupSummaries options not exposed as dedicated module parameters. Passed to GATK via `--arguments_file`.
   - **Format**: Plain text (`.txt` or `.args`)
   - **Example contents**:
     ```
     --max-depth-per-sample
     200
     --java-options
     -Xmx8g
     ```

## Output Files

1. **output pileup summary table** (filename specified by the **output filename** parameter, default: `output_pileup_summary.table`)
   A tab-separated values (TSV) table summarizing allele counts at each queried variant site. This file is the required input for the **gatk.CalculateContamination** module.

   **Columns:**
   | Column | Description |
   | :--- | :--- |
   | `contig` | Chromosome or contig name |
   | `position` | 1-based genomic position of the variant site |
   | `ref_count` | Number of reads supporting the reference allele |
   | `alt_count` | Number of reads supporting the alternate allele |
   | `other_alt_count` | Number of reads supporting alleles other than ref or alt |
   | `allele_frequency` | Population allele frequency of the alternate allele (from the input VCF AF field) |

   **Example rows:**
   ```
   contig  position  ref_count  alt_count  other_alt_count  allele_frequency
   chr1    10736     8          0          0                0.474
   chr1    11008     14         0          0                0.475
   chr1    11012     13         0          0                0.472
   ```

## Example Data

Input:
- Example tumor BAM and index: [GATK Somatic Workflows Tutorial Data](https://gatk.broadinstitute.org/hc/en-us/articles/360035890411)
- Common biallelic sites VCF (hg38): `small_exac_common_3.hg38.vcf.gz` from [GATK Resource Bundle](https://gatk.broadinstitute.org/hc/en-us/articles/360035890811-Resource-bundle)

Output:
- Example pileup summary table: See GATK tutorial outputs at [GATK Somatic CNV/Contamination Tutorial](https://gatk.broadinstitute.org/hc/en-us/articles/360035531092)

## Requirements

- **Docker image**: `ghcr.io/genepattern/gatk_getpileupsummaries:latest` (includes GATK 4.x and all Java dependencies)
- **Runtime environment**: GenePattern server with Docker support
- **Memory**: Minimum 4 GB RAM recommended; 8 GB or more for whole-genome BAM files. Java heap size can be adjusted via `--java-options -Xmx<N>g` in the **arguments file**
- **Disk space**: Sufficient space to stage BAM (potentially tens of GB for whole-genome data), VCF, and intervals files in the job working directory
- **Input format requirements**:
  - BAM must be coordinate-sorted and indexed
  - VCF must be bgzipped (`.vcf.gz`) and tabix-indexed (`.vcf.gz.tbi`)
  - All genome builds must be consistent across BAM, VCF, and intervals files
- **Staging note**: The wrapper script automatically copies all input files (BAM + index, VCF + index, intervals + index) into the writable job working directory before invoking GATK and removes them upon completion. This is required because GenePattern input staging directories may be read-only.

## License

The GATK tool itself is licensed under the [BSD 3-Clause License](https://github.com/broadinstitute/gatk/blob/master/LICENSE.TXT) by the Broad Institute of MIT and Harvard. The GenePattern module wrapper is made available under the [MIT License](https://opensource.org/licenses/MIT). Use of GATK for commercial purposes may require a separate license; see the [Broad Institute GATK licensing page](https://gatk.broadinstitute.org/hc/en-us/articles/360057165250) for details.

## Version Comments

| Version | Release Date | Description |
| :--- | :--- | :--- |
| 1 | 2025-07-01 | Initial release of the gatk.GetPileupSummaries GenePattern module wrapping GATK 4.x GetPileupSummaries. Exposes required inputs (BAM + index, variant VCF + index, intervals + index, output filename) and optional arguments file. Wrapper stages all indexed input files into the writable job working directory and performs automatic cleanup on exit. |
