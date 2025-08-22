# HLA-LA Docker Image

This Docker image provides implementation of HLALA (HLA typing from Linearly projected graph Alignments v1.04). HLALA is a graph-based method for accurate HLA typing from whole-genome sequencing (WGS), whole-exome sequencing (WES), and long-read sequencing data.

## Features

- Pre-built graph indices: The Docker image includes pre-indexed BWA references and prepared HLA-LA graphs to minimize runtime
- Optimized image size: Multi-stage build process reduces the final image size while maintaining functionality
- Cromwell/WDL compatible: Designed for seamless integration with Cromwell workflow engine using Google Batch API
- Support for CRAM/BAM files: Handles both CRAM and BAM input formats with appropriate reference genome handling

## Usage

### Pulling the Pre-Built Image

```bash
docker pull jiachenzdocker/hla-la:2.0
```

### Building from Source

```bash
# Clone the repo with Dockerfile
git clone https://github.com/jiachenzhang99/HLA-LA.git
cd Step_1_Docker

# Build the Docker image
docker build -f HLA_LA.v2.Dockerfile -t hla-la:2.0 .
```


## Technical Details

This Docker image includes:

1. HLA-LA software: Version from bioconda
2. PRG graph: PRG_MHC_GRCh38_withIMGT pre-downloaded and prepared
3. BWA indices: Pre-built for the extended reference genome
4. Dependencies: samtools, bwa, perl modules

### Graph Preparation

The image build process automatically:

1. Downloads the PRG_MHC_GRCh38_withIMGT graph (MD5: 525a8aa0c7f357bf29fe2c75ef1d477d)
2. Indexes the extended reference genome with BWA
3. Prepares the HLA-LA graph using `--action prepareGraph`


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


