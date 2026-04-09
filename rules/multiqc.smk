rule multiqc:
    input:
        expand("results/fastqc/{sample}_R1_trimmed_fastqc.zip", sample=SAMPLES),
        expand("results/fastqc/{sample}_R2_trimmed_fastqc.zip", sample=SAMPLES),
        expand("results/fastp/{sample}.json", sample=SAMPLES),
        expand("results/samtools_stats/{sample}_postFiltering.stats.txt", sample=SAMPLES),
        expand("results/picard/CollectAlignmentSummaryMetrics/{sample}.alignment_metrics.txt", sample=SAMPLES),
        expand("results/picard/CollectInsertSizeMetrics/{sample}.insert_metrics.txt", sample=SAMPLES),
        expand("results/picard/CollectInsertSizeMetrics/{sample}.insert_histogram.pdf", sample=SAMPLES),
        expand("results/preseq/{sample}.ccurve.txt", sample=SAMPLES),
        expand("results/qualimap/{sample}_qualimap_report", sample=SAMPLES)
        
    output:
        report_dir=directory(config['multiqc']['output']['report'])
        
    resources:
        mem_mb=config['multiqc']['resources']['mem_mb'], 
        time=config['multiqc']['resources']['time']
            
    log: "logs/multiqc/multiqc.err"
    container: "https://depot.galaxyproject.org/singularity/multiqc:1.26--pyhdfd78af_0"
    conda: "envs/multiqc.yaml"
    threads: config['multiqc']['threads']
        
    message:
        "Running MultiQC to aggregate all QC reports| INPUT: {input}"
        
    shell:
        """
        set -euo pipefail
        multiqc {input} -o {output.report_dir} \
            --title "Cut&Run Pipeline QC Report" \
            --comment "Comprehensive quality control metrics for CUT&RUN analysis" \
            2> {log}
        """
