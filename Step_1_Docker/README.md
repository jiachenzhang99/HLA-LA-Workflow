# HLA-LA Docker Image

This Docker image provides a containerized environment for running HLA-LA.

## Features

- Based on Debian Bullseye (slim)
- Uses micromamba for efficient dependency management
- **Pre-indexed graph files** for immediate use without setup
- Multi-stage build for smaller final image size
- User-friendly wrapper script for running HLA-LA

## Usage

### Pulling the Built Image

```bash
docker pull jiachenzdocker/hla-la
```

### Building the Docker Image

```bash
# Clone the repo with Dockerfile
git clone https://github.com/jiachenzhang99/HLA-LA.git
cd Step_1_Docker

# Build the Docker image
docker build -t hla-la:latest .
```


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


## Wrapper Script
The image includes a user-friendly wrapper script `type_hla.sh` that:

- Validates input parameters and file existence

- Extracts sample ID from CRAM/BAM filename

- Runs HLA-LA with appropriate parameters

- Copies output files to standardized locations

- Provides clear error messages and usage instructions


## Requirements to Build Image


- At least 64GB RAM (128GB+ recommended)
- At least 8 CPU cores (16+ recommended)
- At least 60GB disk space

