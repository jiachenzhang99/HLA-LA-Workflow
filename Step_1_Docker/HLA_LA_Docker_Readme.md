# HLA-LA Docker Image

This Docker image provides a containerized environment for running HLA-LA - a tool for HLA type inference from sequencing data.

## Features

- Based on Debian Bullseye (slim)
- Uses micromamba for efficient dependency management
- **Pre-indexed graph files** for immediate use without setup
- Multi-stage build for smaller final image size
- User-friendly wrapper script for running HLA-LA

## Usage

### Building the Docker Image

```bash
# Clone this repository
git clone https://github.com/your-username/hla-la-docker.git
cd hla-la-docker

# Build the Docker image
docker build -t hla-la:latest .
```

### Running HLA-LA

To run HLA typing on your data:

```bash
docker run -v /path/to/data:/data hla-la:latest type_hla.sh <nr_threads> <cram_file> <ref_fasta_file>
```

Parameters:
- `nr_threads`: Number of CPU threads to use (e.g., 8)
- `cram_file`: Path to input CRAM or BAM file
- `ref_fasta_file`: Path to reference FASTA file used to create the CRAM/BAM

Example:
```bash
docker run -v $(pwd):/data hla-la:latest type_hla.sh 8 /data/sample.cram /data/reference.fasta
```

The output files will be created in the mounted directory:
- `sample_output_G.txt`: Best HLA allele calls
- `sample_output.txt`: All possible HLA alleles

## Technical Details

This Docker image:

1. Uses a multi-stage build process:
   - First stage: Installs HLA-LA and indexes the graph
   - Second stage: Creates a minimal runtime image with only necessary components

2. **Pre-indexes graph files during the build process**:
   - Downloads the PRG_MHC_GRCh38_withIMGT.tar.gz graph package
   - Verifies the checksum for security
   - Runs the graph indexing step using `HLA-LA --action prepareGraph`

3. Uses micromamba instead of full Anaconda for a lighter image

4. Sets up a non-root user to follow security best practices

## Requirements

### Resources

- At least 8GB RAM (16GB+ recommended)
- At least 4 CPU cores (8+ recommended)
- At least 20GB disk space

### Input Files

- CRAM/BAM file with corresponding index (.crai/.bai)
- Reference FASTA file with index (.fai)

## Troubleshooting

If you encounter issues:

1. **Missing index files**: Ensure your CRAM/BAM files have corresponding index files (.crai/.bai)
2. **Memory issues**: Try running on a machine with more RAM (HLA-LA needs at least 8GB)
3. **Path issues**: Ensure paths are correct and files are readable

## References

- HLA-LA GitHub: https://github.com/DiltheyLab/HLA-LA
- Original paper: https://doi.org/10.1186/s13059-018-1561-7