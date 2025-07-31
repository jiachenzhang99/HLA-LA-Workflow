# HLA-LA Docker Image

This Docker image provides a containerized environment for running HLA-LA.

## Features

- Based on Debian Bullseye (slim)
- Uses micromamba for efficient dependency management
- **Pre-indexed graph files** for immediate use without setup
- Multi-stage build for smaller final image size
- User-friendly wrapper script for running HLA-LA

## Usage

### Building the Docker Image

```bash
# Build the Docker image
docker build -t hla-la:latest .
```

## Docker Image Creation

The Docker image is built using a multi-stage approach for optimal size and performance:

### Stage 1: Builder

Base Image: Debian Bullseye (slim)

Package Manager: micromamba (lightweight alternative to Anaconda)

HLA-LA Installation: Installed via bioconda package manager

Graph Data: Downloads and extracts PRG_MHC_GRCh38_withIMGT.tar.gz

Pre-indexing: Runs HLA-LA --action prepareGraph during build time


### Stage 2: Final Runtime Image

Base Image: Debian Bullseye (slim)

Components: Copies only the pre-built conda environment with indexed graphs

User Setup: Creates non-root user for security

Wrapper Script: Includes type_hla.sh for simplified execution


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
