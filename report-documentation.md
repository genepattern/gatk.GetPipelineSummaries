Documentation generated successfully for the GenePattern module 'gatk.GetPileupSummaries' (v1).

The README.md covers all required sections per the GenePattern documentation template:
- Module overview with workflow context diagram
- Full parameter table with all 6 required + 2 optional parameters marked appropriately
- Detailed Input Files section covering BAM + index, VCF + index, intervals + index, and optional arguments file
- Output Files section with full column-level description of the pileup summary table
- Example Data with links to GATK resource bundle and tutorial data
- Requirements including Docker image, memory, disk, and important input staging notes
- License section for both GATK (BSD 3-Clause) and the GenePattern wrapper (MIT)
- Version Comments table

Key documentation highlights:
1. All 6 required parameters and the intervals parameter are clearly marked with asterisks
2. The BAM index (.bai) requirement and staging behavior is fully described
3. The VCF index (.vcf.gz.tbi) requirement and staging behavior is fully described
4. The intervals + intervals index requirement and staging behavior is fully described
5. The wrapper's EXIT trap cleanup behavior is described in both the Summary and Requirements sections
6. The arguments_file optional parameter is documented for advanced GATK options
7. The note that intervals can be the same file as the variant VCF is included prominently