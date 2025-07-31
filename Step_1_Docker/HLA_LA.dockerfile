# Stage 1: Builder - Installs micromamba, HLA-LA, downloads, and indexes the graph
FROM debian:bullseye-slim AS builder

ARG APP_USER_NAME=appuser
ARG APP_USER_UID=1001
ARG APP_USER_GID=1001
ARG CONDA_ENV_NAME=hlala_env
ARG HLA_LA_VERSION=1.0.4
ARG HLA_LA_GRAPH_URL="http://www.well.ox.ac.uk/downloads/PRG_MHC_GRCh38_withIMGT.tar.gz"
ARG HLA_LA_GRAPH_ARCHIVE="PRG_MHC_GRCh38_withIMGT.tar.gz"
ARG HLA_LA_GRAPH_MD5="525a8aa0c7f357bf29fe2c75ef1d477d"
ARG HLA_LA_GRAPH_DIR_NAME="PRG_MHC_GRCh38_withIMGT"

ENV DEBIAN_FRONTEND=noninteractive
ENV MAMBA_ROOT_PREFIX="/opt/conda"
ENV PATH="${MAMBA_ROOT_PREFIX}/bin:/usr/local/bin:${PATH}"
ENV APP_USER_NAME=${APP_USER_NAME}
ENV CONDA_ENV_NAME=${CONDA_ENV_NAME}
ENV HLA_LA_VERSION=${HLA_LA_VERSION}
ENV CONDA_ENV_PATH="${MAMBA_ROOT_PREFIX}/envs/${CONDA_ENV_NAME}"
ENV HLA_LA_SCRIPT_PATH="${CONDA_ENV_PATH}/bin/HLA-LA.pl"
ENV HLA_LA_BIN_PATH="${CONDA_ENV_PATH}/opt/hla-la/bin/HLA-LA"
ENV HLA_LA_GRAPHS_PATH="${CONDA_ENV_PATH}/opt/hla-la/graphs"

USER root
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget \
    ca-certificates \
    bzip2 \
    procps \
    coreutils \
    gosu \
    curl \
    rsync \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

RUN groupadd -r ${APP_USER_NAME} --gid ${APP_USER_GID} && \
    useradd --no-log-init -r -m -d /home/${APP_USER_NAME} -s /bin/bash \
            -g ${APP_USER_NAME} --uid ${APP_USER_UID} ${APP_USER_NAME}

# Set up micromamba
RUN mkdir -p /usr/local/bin && \
    mkdir -p ${MAMBA_ROOT_PREFIX}/envs && \
    curl -Ls https://micro.mamba.pm/api/micromamba/linux-64/latest | tar -xvj -C /usr/local/bin --strip-components=1 bin/micromamba && \
    chown -R ${APP_USER_NAME}:${APP_USER_NAME} ${MAMBA_ROOT_PREFIX}

# Create conda environment
RUN gosu ${APP_USER_NAME} /usr/local/bin/micromamba create -y -n ${CONDA_ENV_NAME} -c bioconda -c conda-forge \
    hla-la=${HLA_LA_VERSION} \
    perl && \
    gosu ${APP_USER_NAME} /usr/local/bin/micromamba clean -afy

# Create directories for graph data
ENV GRAPH_DOWNLOAD_DIR="/opt/downloaded_graph_data"
RUN mkdir -p ${GRAPH_DOWNLOAD_DIR} && \
    chown -R ${APP_USER_NAME}:${APP_USER_NAME} ${GRAPH_DOWNLOAD_DIR}

# Download and extract graph data
USER ${APP_USER_NAME}
WORKDIR ${GRAPH_DOWNLOAD_DIR}
RUN echo "Downloading and extracting graph data..." && \
    wget -q ${HLA_LA_GRAPH_URL} -O ${HLA_LA_GRAPH_ARCHIVE} && \
    echo "${HLA_LA_GRAPH_MD5}  ${HLA_LA_GRAPH_ARCHIVE}" | md5sum -c - && \
    mkdir -p ${HLA_LA_GRAPHS_PATH}/${HLA_LA_GRAPH_DIR_NAME} && \
    tar -xzf ${HLA_LA_GRAPH_ARCHIVE} -C ${HLA_LA_GRAPHS_PATH}/${HLA_LA_GRAPH_DIR_NAME} --strip-components=1 && \
    rm ${HLA_LA_GRAPH_ARCHIVE}

# Index the graph
RUN echo "Preparing graph index..." && \
    cd /tmp && \
    ${HLA_LA_BIN_PATH} --action prepareGraph --PRG_graph_dir ${HLA_LA_GRAPHS_PATH}/${HLA_LA_GRAPH_DIR_NAME} && \
    echo "Graph preparation completed successfully."

# Stage 2: Final image - Copies Conda env with indexed graph
FROM debian:bullseye-slim AS final

ARG APP_USER_NAME=appuser
ARG APP_USER_UID=1001
ARG APP_USER_GID=1001
ARG CONDA_ENV_NAME=hlala_env

ENV DEBIAN_FRONTEND=noninteractive
ENV MAMBA_ROOT_PREFIX="/opt/conda"
ENV CONDA_ENV_PATH="${MAMBA_ROOT_PREFIX}/envs/${CONDA_ENV_NAME}"
ENV PATH="${CONDA_ENV_PATH}/bin:${MAMBA_ROOT_PREFIX}/bin:/usr/local/bin:${PATH}"
ENV HLA_LA_SCRIPT_PATH="${CONDA_ENV_PATH}/bin/HLA-LA.pl"
ENV HLA_LA_BIN_PATH="${CONDA_ENV_PATH}/opt/hla-la/bin/HLA-LA"
ENV HLA_LA_GRAPHS_PATH="${CONDA_ENV_PATH}/opt/hla-la/graphs"

RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    procps \
    coreutils \
    && groupadd -r ${APP_USER_NAME} --gid ${APP_USER_GID} && \
    useradd --no-log-init -r -m -d /home/${APP_USER_NAME} -s /bin/bash -g ${APP_USER_NAME} --uid ${APP_USER_UID} ${APP_USER_NAME} \
    && rm -rf /var/lib/apt/lists/*

# Copy the conda environment with indexed graph
COPY --from=builder --chown=${APP_USER_NAME}:${APP_USER_NAME} ${MAMBA_ROOT_PREFIX} ${MAMBA_ROOT_PREFIX}

# Copy the type_hla.sh script
COPY type_hla.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/type_hla.sh && \
    chown ${APP_USER_NAME}:${APP_USER_NAME} /usr/local/bin/type_hla.sh

USER ${APP_USER_NAME}
WORKDIR /data

# Default command provides usage information
CMD ["type_hla.sh"]