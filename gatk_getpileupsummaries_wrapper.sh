#!/bin/bash
set -euo pipefail

# gatk.GetPileupSummaries GenePattern wrapper
# Summarizes counts of reads that support reference, alternate, and other alleles for given sites.
# Results can be used with CalculateContamination.
#
# Required GATK arguments used: -I (input BAM), -V (variant VCF), -L (intervals), -O (output)
# Additional arguments can be passed via --arguments.file.

TOOL_NAME="gatk.GetPileupSummaries"

# ---------------------------------------------------------------------------
# Parameter variables (populated by parse_arguments)
# ---------------------------------------------------------------------------
INPUT_BAM=""
INPUT_BAI=""
VARIANT_VCF=""
VARIANT_VCF_TBI=""
INTERVALS_FILE=""
INTERVALS_INDEX=""
OUTPUT_FILE_NAME=""
ARGUMENTS_FILE=""

# ---------------------------------------------------------------------------
# Staged (local working-directory) copies - tracked for cleanup
# ---------------------------------------------------------------------------
LOCAL_BAM=""
LOCAL_BAI=""
LOCAL_VCF=""
LOCAL_VCF_TBI=""
LOCAL_INTERVALS=""
LOCAL_INTERVALS_IDX=""

# ---------------------------------------------------------------------------
# Cleanup trap - always runs on EXIT (success or failure)
# ---------------------------------------------------------------------------
cleanup() {
    echo "[INFO] Cleaning up staged input files from working directory..."
    [[ -n "$LOCAL_BAM"          && -f "$LOCAL_BAM"          ]] && rm -f "$LOCAL_BAM"          && echo "[INFO] Removed $LOCAL_BAM"
    [[ -n "$LOCAL_BAI"          && -f "$LOCAL_BAI"          ]] && rm -f "$LOCAL_BAI"          && echo "[INFO] Removed $LOCAL_BAI"
    [[ -n "$LOCAL_VCF"          && -f "$LOCAL_VCF"          ]] && rm -f "$LOCAL_VCF"          && echo "[INFO] Removed $LOCAL_VCF"
    [[ -n "$LOCAL_VCF_TBI"      && -f "$LOCAL_VCF_TBI"      ]] && rm -f "$LOCAL_VCF_TBI"      && echo "[INFO] Removed $LOCAL_VCF_TBI"
    [[ -n "$LOCAL_INTERVALS"    && -f "$LOCAL_INTERVALS"    ]] && rm -f "$LOCAL_INTERVALS"    && echo "[INFO] Removed $LOCAL_INTERVALS"
    [[ -n "$LOCAL_INTERVALS_IDX" && -f "$LOCAL_INTERVALS_IDX" ]] && rm -f "$LOCAL_INTERVALS_IDX" && echo "[INFO] Removed $LOCAL_INTERVALS_IDX"
    echo "[INFO] Cleanup complete."
}
trap cleanup EXIT

# ---------------------------------------------------------------------------
# Usage
# ---------------------------------------------------------------------------
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "GenePattern wrapper for GATK GetPileupSummaries"
    echo ""
    echo "Required options:"
    echo "  --input.bam FILE          Coordinate-sorted, indexed BAM file"
    echo "  --input.bai FILE          BAM index (.bai) file corresponding to --input.bam"
    echo "  --variant.vcf FILE        bgzipped VCF of common germline variant sites with AF"
    echo "  --variant.vcf.tbi FILE    Tabix index (.tbi) for --variant.vcf"
    echo "  --intervals.file FILE     Intervals/sites file (VCF, BED, .list, etc.)"
    echo "  --intervals.index FILE    Index file for --intervals.file (e.g. .tbi or .idx)"
    echo "  --output.file.name TEXT   Name for the output pileup summary table"
    echo ""
    echo "Optional options:"
    echo "  --arguments.file FILE     GATK arguments file with additional parameters"
    echo "  -h, --help                Show this help message and exit"
    exit 1
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
parse_arguments() {
    if [[ $# -eq 0 ]]; then
        echo "[ERROR] No arguments provided."
        usage
    fi

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --input.bam)
                INPUT_BAM="$2"
                shift 2
                ;;
            --input.bai)
                INPUT_BAI="$2"
                shift 2
                ;;
            --variant.vcf)
                VARIANT_VCF="$2"
                shift 2
                ;;
            --variant.vcf.tbi)
                VARIANT_VCF_TBI="$2"
                shift 2
                ;;
            --intervals.file)
                INTERVALS_FILE="$2"
                shift 2
                ;;
            --intervals.index)
                INTERVALS_INDEX="$2"
                shift 2
                ;;
            --output.file.name)
                OUTPUT_FILE_NAME="$2"
                shift 2
                ;;
            --arguments.file)
                ARGUMENTS_FILE="$2"
                shift 2
                ;;
            -h|--help)
                usage
                ;;
            *)
                echo "[ERROR] Unknown option: $1"
                usage
                ;;
        esac
    done
}

# ---------------------------------------------------------------------------
# Input validation
# ---------------------------------------------------------------------------
validate_inputs() {
    local errors=0

    # Required parameter presence checks
    if [[ -z "$INPUT_BAM" ]];        then echo "[ERROR] --input.bam is required";        errors=$((errors+1)); fi
    if [[ -z "$INPUT_BAI" ]];        then echo "[ERROR] --input.bai is required";        errors=$((errors+1)); fi
    if [[ -z "$VARIANT_VCF" ]];      then echo "[ERROR] --variant.vcf is required";      errors=$((errors+1)); fi
    if [[ -z "$VARIANT_VCF_TBI" ]];  then echo "[ERROR] --variant.vcf.tbi is required";  errors=$((errors+1)); fi
    if [[ -z "$INTERVALS_FILE" ]];   then echo "[ERROR] --intervals.file is required";   errors=$((errors+1)); fi
    if [[ -z "$INTERVALS_INDEX" ]];  then echo "[ERROR] --intervals.index is required";  errors=$((errors+1)); fi
    if [[ -z "$OUTPUT_FILE_NAME" ]]; then echo "[ERROR] --output.file.name is required"; errors=$((errors+1)); fi

    # File existence checks (only when the variable is set)
    if [[ -n "$INPUT_BAM"       && ! -f "$INPUT_BAM" ]];       then echo "[ERROR] BAM file not found: $INPUT_BAM";              errors=$((errors+1)); fi
    if [[ -n "$INPUT_BAI"       && ! -f "$INPUT_BAI" ]];       then echo "[ERROR] BAI file not found: $INPUT_BAI";              errors=$((errors+1)); fi
    if [[ -n "$VARIANT_VCF"     && ! -f "$VARIANT_VCF" ]];     then echo "[ERROR] Variant VCF not found: $VARIANT_VCF";         errors=$((errors+1)); fi
    if [[ -n "$VARIANT_VCF_TBI" && ! -f "$VARIANT_VCF_TBI" ]]; then echo "[ERROR] Variant VCF TBI not found: $VARIANT_VCF_TBI"; errors=$((errors+1)); fi
    if [[ -n "$INTERVALS_FILE"  && ! -f "$INTERVALS_FILE" ]];  then echo "[ERROR] Intervals file not found: $INTERVALS_FILE";   errors=$((errors+1)); fi
    if [[ -n "$INTERVALS_INDEX" && ! -f "$INTERVALS_INDEX" ]]; then echo "[ERROR] Intervals index not found: $INTERVALS_INDEX";  errors=$((errors+1)); fi
    if [[ -n "$ARGUMENTS_FILE"  && ! -f "$ARGUMENTS_FILE" ]];  then echo "[ERROR] Arguments file not found: $ARGUMENTS_FILE";   errors=$((errors+1)); fi

    if [[ "$errors" -gt 0 ]]; then
        echo "[ERROR] $errors validation error(s) found. Exiting."
        exit 1
    fi

    echo "[INFO] Input validation passed."
}

# ---------------------------------------------------------------------------
# Stage inputs into the writable job working directory
#
# GATK requires the index file to sit alongside the data file and share the
# same base name, e.g.:
#   tumor.bam  +  tumor.bam.bai
#   variants.vcf.gz  +  variants.vcf.gz.tbi
#   intervals.vcf.gz +  intervals.vcf.gz.tbi
#
# The GenePattern staging directory may be read-only, so we copy everything
# into the current working directory (the writable job directory).
# ---------------------------------------------------------------------------
stage_inputs() {
    local workdir
    workdir="$(pwd)"
    echo "[INFO] Staging input files into job working directory: $workdir"

    # -- BAM ------------------------------------------------------------------
    LOCAL_BAM="${workdir}/$(basename "${INPUT_BAM}")"
    echo "[INFO] Copying BAM:  ${INPUT_BAM} -> ${LOCAL_BAM}"
    cp "${INPUT_BAM}" "${LOCAL_BAM}"

    # BAI must be named <bam>.bai  (GATK auto-discovers <input>.bai)
    LOCAL_BAI="${LOCAL_BAM}.bai"
    echo "[INFO] Copying BAI:  ${INPUT_BAI} -> ${LOCAL_BAI}"
    cp "${INPUT_BAI}" "${LOCAL_BAI}"

    # -- Variant VCF ----------------------------------------------------------
    LOCAL_VCF="${workdir}/$(basename "${VARIANT_VCF}")"
    echo "[INFO] Copying VCF:  ${VARIANT_VCF} -> ${LOCAL_VCF}"
    cp "${VARIANT_VCF}" "${LOCAL_VCF}"

    # TBI must be named <vcf>.tbi  (GATK auto-discovers <input>.tbi)
    LOCAL_VCF_TBI="${LOCAL_VCF}.tbi"
    echo "[INFO] Copying VCF TBI: ${VARIANT_VCF_TBI} -> ${LOCAL_VCF_TBI}"
    cp "${VARIANT_VCF_TBI}" "${LOCAL_VCF_TBI}"

    # -- Intervals file -------------------------------------------------------
    LOCAL_INTERVALS="${workdir}/$(basename "${INTERVALS_FILE}")"
    echo "[INFO] Copying intervals: ${INTERVALS_FILE} -> ${LOCAL_INTERVALS}"
    cp "${INTERVALS_FILE}" "${LOCAL_INTERVALS}"

    # Intervals index must be named <intervals>.tbi
    LOCAL_INTERVALS_IDX="${LOCAL_INTERVALS}.tbi"
    echo "[INFO] Copying intervals index: ${INTERVALS_INDEX} -> ${LOCAL_INTERVALS_IDX}"
    cp "${INTERVALS_INDEX}" "${LOCAL_INTERVALS_IDX}"

    echo "[INFO] Staging complete."
}

# ---------------------------------------------------------------------------
# Execute GATK GetPileupSummaries
# ---------------------------------------------------------------------------
run_tool() {
    # Build the command array with the four required GATK arguments:
    #   -I  input BAM
    #   -V  variant VCF (common germline sites with allele frequencies)
    #   -L  intervals (required even when using a VCF as sites)
    #   -O  output pileup summary table
    local -a cmd=(
        gatk GetPileupSummaries
        -I "${LOCAL_BAM}"
        -V "${LOCAL_VCF}"
        -L "${LOCAL_INTERVALS}"
        -O "${OUTPUT_FILE_NAME}"
    )

    # Append optional arguments file if provided
    if [[ -n "$ARGUMENTS_FILE" ]]; then
        cmd+=(--arguments_file "${ARGUMENTS_FILE}")
    fi

    echo "[INFO] Executing: ${cmd[*]}"
    echo "-------------------------------------------------------------------"

    "${cmd[@]}"
    local exit_code=$?

    echo "-------------------------------------------------------------------"
    if [[ "$exit_code" -ne 0 ]]; then
        echo "[ERROR] gatk GetPileupSummaries failed with exit code ${exit_code}."
        exit "${exit_code}"
    fi

    echo "[INFO] gatk GetPileupSummaries completed successfully."
    echo "[INFO] Output written to: ${OUTPUT_FILE_NAME}"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
    echo "[INFO] === ${TOOL_NAME} wrapper starting ==="
    echo "[INFO] Working directory: $(pwd)"

    parse_arguments "$@"
    validate_inputs
    stage_inputs
    run_tool

    echo "[INFO] === ${TOOL_NAME} wrapper finished successfully ==="
}

main "$@"
