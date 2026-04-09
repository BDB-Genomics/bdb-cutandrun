rule motif_analysis:
    input:
        filtered_peaks=expand("results/filtered_peaks/{sample}_filtered_peaks.bed", sample=SAMPLES),
        genome=config['global']['genome_fa']

    output:
        html=directory(f"{config['motif_analysis']['output']}/motif_analysis")
  
    resources:
        mem_mb=config['motif_analysis']['resources']['mem_mb'],
        time=config['motif_analysis']['resources']['time']
            
    benchmark: "benchmarks/motif_analysis/motif_analysis.txt"
    log: "logs/motif_analysis/motif_analysis.log"
    container: "https://depot.galaxyproject.org/singularity/homer:4.9.1--pl5.22.0_0"
    conda: "envs/homer.yaml"
    threads: config['motif_analysis']['threads']

    message:
        "[Motif analysis] Sample: All combined | Peaks: {input.filtered_peaks} | Output: {output.html}"

    shell:
        """
        set -euo pipefail
        cat {input.filtered_peaks} > merged_peaks.tmp && \
        findMotifsGenome.pl merged_peaks.tmp {input.genome} {output.html} \
            -p {threads} \
        2> {log} && \

        rm -rf merged_peaks.tmp
        """
