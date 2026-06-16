# LAYER 1: Base Image
# We use micromamba for a tiny, lightning-fast C++ implementation of Conda
FROM mambaorg/micromamba:1.5-bullseye-slim

LABEL maintainer="Himanshu Bhandary <2032ushimanshu@gmail.com>"
LABEL description="Host runner environment for BDB-Genomics CUT&RUN Pipeline"

# Set working directory inside the container
WORKDIR /app

# LAYER 2: Copy the environment file and create the Conda environment
# We do this BEFORE copying the rest of the code to leverage Docker caching.
COPY --chown=$MAMBA_USER:$MAMBA_USER envs/main.yaml /tmp/env.yaml

RUN micromamba install -y -n base -f /tmp/env.yaml && \
    micromamba clean --all --yes

# LAYER 3: Copy the actual pipeline code into the container
COPY --chown=$MAMBA_USER:$MAMBA_USER . /app

# Ensure binaries are in the system PATH
ENV PATH="/opt/conda/bin:$PATH"

# Set the entrypoint to run Snakemake under micromamba's environment wrapper.
# This ensures the conda environment is activated when the container runs.
ENTRYPOINT ["/usr/local/bin/_entrypoint.sh", "snakemake"]

# Default to showing help if no arguments are provided
CMD ["--help"]
