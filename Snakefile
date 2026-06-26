#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
#>              Modular CUT&RUN Pipeline                                                                          #>
#>              Author: Himanshu Bhandary          
#>              Mail: 2032ushimanshu@gmail.com                                                              #>
#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

import csv
import subprocess
from pathlib import Path

configfile: "config.yaml"

# Validate configuration on start
subprocess.run(
    ["python3", "rules/scripts/validate_config.py", "config.yaml"],
    check=True,
)

SAMPLES_TSV = Path(config["global"]["samples"])
if SAMPLES_TSV.exists():
    with SAMPLES_TSV.open(newline="") as handle:
        rows = list(csv.DictReader(handle, delimiter="\t"))
    SAMPLES = [row["sample"] for row in rows]
    FASTQ_R1 = {row["sample"]: row["fastq_r1"] for row in rows}
    FASTQ_R2 = {row["sample"]: row["fastq_r2"] for row in rows}
else:
    SAMPLES = []
    FASTQ_R1 = {}
    FASTQ_R2 = {}

#--- Include "as-is" rules ---
include: "rules/fastp.smk"
include: "rules/fastqc.smk"
include: "rules/bowtie2.smk" 
include: "rules/samtools_sort.smk"
include: "rules/calculate_mito_reads.smk"
include: "rules/remove_mito_reads.smk"
include: "rules/samtools_fixmate.smk"
include: "rules/samtools_markdup.smk"
include: "rules/samtools_index_after_markdup.smk"
include: "rules/samtools_view.smk"
include: "rules/samtools_index_post_filter.smk"
include: "rules/samtools_stats.smk"
include: "rules/bam_to_fragments.smk"
include: "rules/spike_in_align.smk"
include: "rules/spike_in_calibration.smk"
include: "rules/fragment_size_analysis.smk"
include: "rules/picard_alignment_metrics.smk"
include: "rules/picard_insert_size_metrics.smk"
include: "rules/bedtools_genomecov.smk"
include: "rules/sorted_bedgraph.smk"
include: "rules/bigwig_conversion.smk"
include: "rules/seacr_peak_calling.smk"
include: "rules/blacklist_region_filter.smk"
include: "rules/preseq.smk"
include: "rules/qualimap_bamqc.smk"
include: "rules/heatmap.smk"
include: "rules/peak_annotation.smk"
include: "rules/motif_analysis.smk"
include: "rules/correlation_analysis.smk"
include: "rules/multiqc.smk"
include: "rules/consensus_peaks.smk"
include: "rules/count_peaks.smk"
include: "rules/differential_binding.smk"



# Pipeline targets grouped by stage
PREPROCESSING_TARGETS = (
    expand("results/fastp/{sample}_R1_trimmed.fastq.gz", sample=SAMPLES)
    + expand("results/fastp/{sample}_R2_trimmed.fastq.gz", sample=SAMPLES)
    + expand("results/fastp/{sample}.html", sample=SAMPLES)
    + expand("results/fastp/{sample}.json", sample=SAMPLES)
    + expand("results/fastqc/{sample}_R1_trimmed_fastqc.html", sample=SAMPLES)
    + expand("results/fastqc/{sample}_R1_trimmed_fastqc.zip", sample=SAMPLES)
    + expand("results/fastqc/{sample}_R2_trimmed_fastqc.html", sample=SAMPLES)
    + expand("results/fastqc/{sample}_R2_trimmed_fastqc.zip", sample=SAMPLES)
)

ALIGNMENT_TARGETS = expand("results/bowtie2/{sample}.bam", sample=SAMPLES)

POST_ALIGNMENT_TARGETS = (
    expand("results/samtools_sort/{sample}.sorted.bam", sample=SAMPLES)
    + expand("results/mito_stats/{sample}_mito_stats.txt", sample=SAMPLES)
    + expand("results/samtools_fixmate/{sample}_noMT.sorted.fixmate.bam", sample=SAMPLES)
    + expand("results/samtools_markdup/{sample}_noMT.sorted.dedup.bam", sample=SAMPLES)
    + expand("results/samtools_index_post_markdup/{sample}_noMT.sorted.dedup.bam.bai", sample=SAMPLES)
    + expand("results/samtools_view/{sample}.filtered.bam", sample=SAMPLES)
    + expand("results/samtools_index_post_filter/{sample}.filtered.bam.bai", sample=SAMPLES)
    + expand("results/samtools_stats/{sample}_postFiltering.stats.txt", sample=SAMPLES)
    + expand("results/fragments/{sample}_fragments.bed", sample=SAMPLES)
    + expand("results/fragment_size_analysis/{sample}_fragment_sizes.txt", sample=SAMPLES)
    + expand("results/fragment_size_analysis/{sample}_fragment.png", sample=SAMPLES)
    + expand("results/fragment_size_analysis/{sample}_fragment_stats.txt", sample=SAMPLES)
)

PICARD_METRICS_TARGETS = (
    expand("results/picard/CollectAlignmentSummaryMetrics/{sample}.alignment_metrics.txt", sample=SAMPLES)
    + expand("results/picard/CollectInsertSizeMetrics/{sample}.insert_metrics.txt", sample=SAMPLES)
    + expand("results/picard/CollectInsertSizeMetrics/{sample}.insert_histogram.pdf", sample=SAMPLES)
)

COVERAGE_TARGETS = (
    expand("results/bedtools_genomecov/{sample}.bedGraph", sample=SAMPLES)
    + expand("results/sorted_bedgraph/{sample}.sorted.bedGraph", sample=SAMPLES)
    + expand("results/bigwig/{sample}.bw", sample=SAMPLES)
)

SPIKEIN_TARGETS = (
    expand("results/spike_in/{sample}_ecoli.bam", sample=SAMPLES)
    + expand("results/spike_in/{sample}_ecoli.bam.bai", sample=SAMPLES)
    + expand("results/spike_in/{sample}_scaling_factor.txt", sample=SAMPLES)
)

PEAK_CALLING_TARGETS = (
    expand("results/seacr/{sample}.peaks.stringent.bed", sample=SAMPLES)
    + expand("results/filtered_peaks/{sample}_filtered_peaks.bed", sample=SAMPLES)
)

QC_TARGETS = (
    expand("results/preseq/{sample}.ccurve.txt", sample=SAMPLES)
    + expand("results/qualimap/{sample}_qualimap_report", sample=SAMPLES)
)

VISUALIZATION_TARGETS = (
    expand("results/heatmap/{sample}_tss_heatmap.pdf", sample=SAMPLES)
)

ANNOTATION_TARGETS = (
    expand("results/peak_annotation/{sample}_peak_annotation.txt", sample=SAMPLES)
)

MOTIF_TARGETS = [
    "results/motif_analysis/motif_analysis"
]

CORRELATION_TARGETS = [
    "results/correlation_analysis/matrix.npz",
    "results/correlation_analysis/matrix.tab",
    "results/correlation_analysis/correlation_heatmap.png",
    "results/correlation_analysis/correlation_values.tab",
]
MULTIQC_TARGETS = ["results/multiqc"]

DIFFERENTIAL_TARGETS = [
    "results/differential_binding/plots/volcano_plot.pdf",
    "results/differential_binding/plots/ma_plot.pdf",
    "results/differential_binding/plots/heatmap_plot.pdf",
    "results/differential_binding/plots/pca_plot.pdf",
    "results/differential_binding/differential_binding_results.tsv"
]

rule all:
    input:
        (
            PREPROCESSING_TARGETS
            + ALIGNMENT_TARGETS
            + POST_ALIGNMENT_TARGETS
            + SPIKEIN_TARGETS
            + PICARD_METRICS_TARGETS
            + COVERAGE_TARGETS
            + PEAK_CALLING_TARGETS
            + VISUALIZATION_TARGETS
            + ANNOTATION_TARGETS
            + MOTIF_TARGETS
            + CORRELATION_TARGETS
            + QC_TARGETS
            + MULTIQC_TARGETS
            + DIFFERENTIAL_TARGETS
        )