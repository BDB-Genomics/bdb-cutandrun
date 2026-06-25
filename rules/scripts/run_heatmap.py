# ruff: noqa: F821
import gzip
import subprocess
from pathlib import Path
from typing import Any

import matplotlib  # type: ignore
matplotlib.use('Agg')
import matplotlib.pyplot as plt  # type: ignore

# Satisfy mypy for the dynamically injected snakemake object
snakemake: Any


# Retrieve variables from snakemake object
filtered_peaks = Path(snakemake.input.filtered_peaks)
bigwig = Path(snakemake.input.bigwig)
matrix = Path(snakemake.output.matrix)
regions = Path(snakemake.output.regions)
plot = Path(snakemake.output.plot)

upstream = snakemake.params.upstream
downstream = snakemake.params.downstream
colormap = snakemake.params.colormap
binsize = snakemake.params.binsize

log_matrix = Path(snakemake.log.matrix)
log_plot = Path(snakemake.log.plot)
threads = snakemake.threads
sample = snakemake.wildcards.sample

# Create directories safely using pathlib
matrix.parent.mkdir(parents=True, exist_ok=True)
regions.parent.mkdir(parents=True, exist_ok=True)
plot.parent.mkdir(parents=True, exist_ok=True)
log_matrix.parent.mkdir(parents=True, exist_ok=True)
log_plot.parent.mkdir(parents=True, exist_ok=True)

# Check if peaks file is empty
is_empty = True
if filtered_peaks.exists() and filtered_peaks.stat().st_size > 0:
    with open(filtered_peaks, 'r') as f:
        for line in f:
            if line.strip():
                is_empty = False
                break

if is_empty:
    # Generate dummy outputs if peak file is completely empty
    with open(log_matrix, 'w') as f:
        f.write("[WARNING] Peak file is empty. Generating dummy heatmap outputs.\n")
    
    with gzip.open(matrix, 'wb') as f:
        f.write(b'# computeMatrix dummy')
        
    with open(regions, 'w') as f:
        f.write('')
        
    try:
        fig, ax = plt.subplots()
        ax.text(0.5, 0.5, 'No peaks found for heatmap', size=15, ha='center', va='center')
        plt.savefig(plot)
    except Exception as e:
        with open(log_plot, 'w') as f:
            f.write(f"Error generating dummy plot: {str(e)}\n")
else:
    # Run computeMatrix
    cmd_matrix = [
        "computeMatrix", "reference-point",
        "--referencePoint", "TSS",
        "-b", str(upstream), "-a", str(downstream),
        "-R", str(filtered_peaks),
        "-S", str(bigwig),
        "--skipZeros",
        "--missingDataAsZero",
        "--binSize", str(binsize),
        "--numberOfProcessors", str(threads),
        "-out", str(matrix),
        "--outFileSortedRegions", str(regions)
    ]
    with open(log_matrix, 'w') as f:
        subprocess.run(cmd_matrix, stdout=f, stderr=f, check=True)
        
    # Run plotHeatmap
    cmd_plot = [
        "plotHeatmap",
        "-m", str(matrix),
        "-out", str(plot),
        "--colorMap", colormap,
        "--regionsLabel", "TSS",
        "--samplesLabel", sample,
        "--heatmapHeight", "12", "--heatmapWidth", "6"
    ]
    with open(log_plot, 'w') as f:
        subprocess.run(cmd_plot, stdout=f, stderr=f, check=True)
