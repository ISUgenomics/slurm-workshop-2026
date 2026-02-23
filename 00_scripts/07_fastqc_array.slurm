#!/usr/bin/env bash

# ===== SLURM directives =====
#SBATCH --job-name=fastqc_array
#SBATCH --account=short_term
#SBATCH --partition=interactive
#SBATCH --time=00:05:00
#SBATCH --nodes=1
#SBATCH --cpus-per-task=2
#SBATCH --mem=2G
# Use master job ID (%A) and array index (%a) for per-task logs
#SBATCH --output=logs/%x_%A_%a.out
#SBATCH --error=logs/%x_%A_%a.err
#SBATCH --array=0-9

set -euo pipefail

# Always start in the submission directory for predictable paths
cd "$SLURM_SUBMIT_DIR"

# Output directory 
OUTPUT_DIR=08_fastqc_slurm_array
LOG_DIR=logs

# Ensure output directories exist
mkdir -p logs $OUTPUT_DIR

# Load modules needed by the job
module load fastqc || true

# Build the file list. The array index selects which file this task processes.
FILES=(01_data/*.fastq.gz)
TARGET="${FILES[$SLURM_ARRAY_TASK_ID]}"

# Derive a clean basename for naming logs and outputs (beginner-friendly)
sample_id=$(basename "$TARGET" .fastq.gz)        # e.g., bio_sample_01_R1

fastqc "$TARGET" -o $OUTPUT_DIR/ \
  > "$LOG_DIR/06_fastqc_slurm_array_${sample_id}.log" 2>&1
