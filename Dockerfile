# Use a lightweight official Python image as the Base Image (Layer 1)
FROM python:3.10-slim

# Set environment variables to avoid interactive prompts during installation
ENV DEBIAN_FRONTEND=noninteractive

# Install core system dependencies in a single, optimized layer (Layer 2)
# Notice how we update, install, and clean up in one single RUN command!
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    wget \
    git \
    bc \
    bash \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install Mamba (the fast package manager) (Layer 3)
RUN curl -L https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh -o miniforge.sh \
    && bash miniforge.sh -b -p /opt/conda \
    && rm miniforge.sh

# Add Mamba to the system PATH so we can use it (Layer 4)
ENV PATH="/opt/conda/bin:${PATH}"

# Install Snakemake using Mamba and immediately clean the cache (Layer 5)
RUN mamba install -y -c conda-forge -c bioconda snakemake \
    && mamba clean -a -y

# Set the working directory where our pipeline will live inside the container
WORKDIR /app

# Copy all the pipeline files from your computer into the container
COPY . /app/

# The default command that runs when the container starts
CMD ["snakemake", "--help"]
