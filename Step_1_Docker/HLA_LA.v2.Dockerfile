# HLA-LA runtime with pre-baked PRG graph + pre-indexed extended reference
# Buildable as-is: downloads the official PRG_MHC_GRCh38_withIMGT graph tarball
# and pre-indexes extendedReferenceGenome.fa with BWA during the build.

# -----------------------------
# Stage 1: builder
# -----------------------------
FROM mambaorg/micromamba:1.5.8 AS builder

ARG MAMBA_DOCKERFILE_ACTIVATE=1
ARG CONDA_ENV_NAME=hlala_env
ENV MAMBA_ROOT_PREFIX=/opt/conda
ENV CONDA_ENV_PATH=${MAMBA_ROOT_PREFIX}/envs/${CONDA_ENV_NAME}
ENV PATH=${CONDA_ENV_PATH}/bin:${MAMBA_ROOT_PREFIX}/bin:/usr/local/bin:/usr/bin:/bin
SHELL ["/bin/bash", "-lc"]

# Create env with required tools
RUN micromamba create -y -n ${CONDA_ENV_NAME} -c conda-forge -c bioconda \
      hla-la bwa samtools curl && \
    micromamba clean -a -y

# Location HLA-LA and your wrapper expect
ENV HLA_LA_GRAPHS_PATH=${CONDA_ENV_PATH}/opt/hla-la/graphs
WORKDIR ${HLA_LA_GRAPHS_PATH}

# Download the graph bundle, verify checksum, unpack
RUN micromamba run -n ${CONDA_ENV_NAME} curl -fsSL \
      "http://www.well.ox.ac.uk/downloads/PRG_MHC_GRCh38_withIMGT.tar.gz" \
      -o PRG_MHC_GRCh38_withIMGT.tar.gz && \
    echo "525a8aa0c7f357bf29fe2c75ef1d477d  PRG_MHC_GRCh38_withIMGT.tar.gz" | md5sum -c - && \
    tar -xzf PRG_MHC_GRCh38_withIMGT.tar.gz && \
    rm -f PRG_MHC_GRCh38_withIMGT.tar.gz

# Pre-build BWA index for the extended reference to avoid per-run indexing
RUN micromamba run -n ${CONDA_ENV_NAME} bwa index \
      PRG_MHC_GRCh38_withIMGT/extendedReferenceGenome/extendedReferenceGenome.fa && \
    ls -lh PRG_MHC_GRCh38_withIMGT/extendedReferenceGenome/extendedReferenceGenome.fa*

# Prepare the HLA-LA graph - CRITICAL STEP
RUN micromamba run -n ${CONDA_ENV_NAME} ${CONDA_ENV_PATH}/opt/hla-la/bin/HLA-LA \
      --action prepareGraph \
      --PRG_graph_dir PRG_MHC_GRCh38_withIMGT && \
    echo "Graph preparation completed" && \
    ls -la PRG_MHC_GRCh38_withIMGT/serializedGRAPH* 2>/dev/null || echo "Warning: serializedGRAPH files not found"

# -----------------------------
# Stage 2: runtime
# -----------------------------
FROM debian:bullseye-slim

ARG CONDA_ENV_NAME=hlala_env
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
      bash ca-certificates coreutils procps \
    && rm -rf /var/lib/apt/lists/*

# Copy the conda tree with env, tools, and pre-indexed graphs
COPY --from=builder /opt/conda /opt/conda

# Runtime env
ENV MAMBA_ROOT_PREFIX=/opt/conda
ENV CONDA_ENV_PATH=${MAMBA_ROOT_PREFIX}/envs/${CONDA_ENV_NAME}
ENV PATH=${CONDA_ENV_PATH}/bin:${MAMBA_ROOT_PREFIX}/bin:/usr/local/bin:/usr/bin:/bin
ENV HLA_LA_GRAPHS_PATH=${CONDA_ENV_PATH}/opt/hla-la/graphs

# Wrapper script
COPY type_hla.sh /usr/local/bin/type_hla.sh
RUN chmod +x /usr/local/bin/type_hla.sh

# Create data directory and set as working directory
RUN mkdir -p /data && chmod 777 /data
WORKDIR /data

CMD ["type_hla.sh"]
