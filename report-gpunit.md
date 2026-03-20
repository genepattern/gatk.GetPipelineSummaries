## GPUnit Test Generation for `GATK.GetPileupSummaries`

### Summary
A single happy-path GPUnit test (`test.yml`) has been generated for the **GATK.GetPileupSummaries** module. The validator confirmed structural and module-level checks passed; parameter name errors from attempt 1 were corrected by using the proper dot-notation parameter names (`input.bam`, `input.bai`, `variant.vcf`, `variant.vcf.tbi`, `intervals.file`, `intervals.index`) instead of underscore-separated names.

---

### Key Design Decisions

| Decision | Detail |
|---|---|
| **Module name** | `GATK.GetPileupSummaries` (correct case, matching expected) |
| **BAM input** | `input.bam` → `/Users/liefeld/Desktop/gatk/normal.bam` |
| **BAM index** | `input.bai` → `/Users/liefeld/Desktop/gatk/normal.bam.bai` (separate GenePattern file param; wrapper copies both to working dir) |
| **Variant VCF** | `variant.vcf` → `chr17_small_exac_common_3_grch38.vcf.gz` |
| **VCF index** | `variant.vcf.tbi` → `chr17_small_exac_common_3_grch38.vcf.gz.tbi` (separate GenePattern file param) |
| **Intervals file** | `intervals.file` → same VCF as variant (per instructions: intervals can equal the VCF) |
| **Intervals index** | `intervals.index` → same `.tbi` as VCF index |
| **Wrapper staging** | Both BAM+BAI and VCF+TBI pairs must be copied into the writable job working directory before calling GATK; cleaned up via `trap` on EXIT |
| **Output assertion** | Checks for existence of `normal.pileups.table` (standard GATK GetPileupSummaries output) |

---

### Wrapper Staging Notes (for module developer)
1. **BAM + BAI**: Copy `input.bam` and `input.bai` into `$PWD`; pass local copies to GATK via `-I ./$(basename bam)`.
2. **VCF + TBI**: Copy `variant.vcf` and `variant.vcf.tbi` into `$PWD`; pass local VCF to GATK via `-V ./$(basename vcf)`.
3. **Intervals + index**: Copy `intervals.file` and `intervals.index` into `$PWD`; pass local intervals to GATK via `-L ./$(basename intervals)`.
4. **Cleanup**: Use `trap 'rm -f $local_bam $local_bai $local_vcf $local_tbi $local_intervals $local_intervals_idx' EXIT` so files are removed on success or failure.
