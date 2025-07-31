# Workflow Overview

The hla_la_wf.wdl workflow wraps the HLA-LA Docker container from step 1 (jiachenzdocker/hla-la:latest) to provide a scalable solution for HLA typing on cloud platforms. The workflow:

- Takes CRAM/BAM files and reference genome as input
- Runs HLA-LA typing using the containerized environment
- Outputs best HLA allele calls and all possible alleles
