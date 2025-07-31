#!/bin/bash
set -e

# Display usage if no parameters are provided
if [ $# -lt 3 ]; then
    echo "HLA-LA Typing Tool"
    echo "==================="
    echo ""
    echo "Usage: $(basename $0) <nr_threads> <cram_file> <ref_fasta_file>"
    echo ""
    echo "Parameters:"
    echo "  nr_threads     Number of CPU threads to use (e.g., 8)"
    echo "  cram_file      Path to input CRAM or BAM file"
    echo "  ref_fasta_file Path to reference FASTA file used to create the CRAM/BAM"
    echo ""
    echo "Example:"
    echo "  $(basename $0) 8 /data/sample.cram /data/reference.fasta"
    echo ""
    exit 1
fi

# Input parameters
nr_threads=$1
cram_file_name=$2
ref_fasta_file_name=$3
sample_id=$(basename "$cram_file_name" | cut -f1 -d".")
graph_dir="${HLA_LA_GRAPHS_PATH}/PRG_MHC_GRCh38_withIMGT"

# Output parameters
output_dir="/data"
best_out_file_name="${output_dir}/${sample_id}_output_G.txt"
all_out_file_name="${output_dir}/${sample_id}_output.txt"

# Display configuration
echo "=== HLA-LA Typing Configuration ==="
echo "Sample ID: $sample_id"
echo "Threads: $nr_threads"
echo "CRAM/BAM file: $cram_file_name"
echo "Reference FASTA: $ref_fasta_file_name"
echo "Graph directory: $graph_dir"
echo "Working directory: $output_dir"
echo "=================================="

# Verify files exist
if [ ! -f "$cram_file_name" ]; then
    echo "Error: Input file $cram_file_name does not exist"
    exit 1
fi

if [ ! -f "$ref_fasta_file_name" ]; then
    echo "Error: Reference file $ref_fasta_file_name does not exist"
    exit 1
fi

# Run HLA typing
echo "Starting HLA typing..."
HLA-LA.pl \
    --BAM "$cram_file_name" \
    --graph PRG_MHC_GRCh38_withIMGT \
    --sampleID "$sample_id" \
    --samtools_T "$ref_fasta_file_name" \
    --maxThreads "$nr_threads" \
    --workingDir "$output_dir"

# Check if HLA-LA completed successfully
if [ $? -eq 0 ]; then
    echo "HLA-LA typing completed successfully"
    
    # Copy output files if they exist
    if [ -f "$output_dir/$sample_id/hla/R1_bestguess_G.txt" ]; then
        cp "$output_dir/$sample_id/hla/R1_bestguess_G.txt" "$best_out_file_name"
        echo "Created best HLA allele calls file: $best_out_file_name"
    else
        echo "Warning: Best HLA allele calls file not found at $output_dir/$sample_id/hla/R1_bestguess_G.txt"
    fi
    
    if [ -f "$output_dir/$sample_id/hla/R1_bestguess.txt" ]; then
        cp "$output_dir/$sample_id/hla/R1_bestguess.txt" "$all_out_file_name"
        echo "Created all possible HLA alleles file: $all_out_file_name"
    else
        echo "Warning: All possible HLA alleles file not found at $output_dir/$sample_id/hla/R1_bestguess.txt"
    fi
else
    echo "Error: HLA-LA typing failed"
    exit 1
fi

echo "HLA typing completed. Results are in $output_dir"