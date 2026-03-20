Generated a production-ready bash wrapper script for gatk.GetPileupSummaries (gatk_getpileupsummaries_wrapper.sh).

Key implementation details:
- Language: Bash (required for JVM/Java tools)
- All 8 parameter flags preserved exactly: --input.bam, --input.bai, --variant.vcf, --variant.vcf.tbi, --intervals.file, --intervals.index, --output.file.name, --arguments.file
- GATK invocation uses only the four required arguments: -I (input BAM), -V (variant VCF), -L (intervals), -O (output), plus optional --arguments_file
- BAM + BAI staging: both copied to working directory; BAI renamed to <bam>.bai so GATK auto-discovers it
- VCF + TBI staging: both copied to working directory; TBI named <vcf>.tbi so GATK auto-discovers it
- Intervals + index staging: both copied to working directory; index named <intervals>.tbi so GATK auto-discovers it
- EXIT trap ensures cleanup of all staged files on success or failure
- Comprehensive validation of all required parameters and file existence
- Clear [INFO]/[ERROR] prefixed logging throughout
- set -euo pipefail for strict error handling