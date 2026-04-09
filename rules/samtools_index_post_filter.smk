rule samtools_index_post_filter:
    input:
        filtered_bam=lambda wildcards: f"{config['samtools_index_post_filter']['input']['filtered_bam']}/{wildcards.sample}.filtered.bam"
        
    output:
        filtered_bam_indexed=f"{config['samtools_index_post_filter']['output']['filtered_bam_indexed']}/{{sample}}.filtered.bam.bai"
    
    resources:
        mem_mb=config['samtools_index_post_filter']['resources']['mem_mb'], 
        time=config['samtools_index_post_filter']['resources']['time']

    benchmark: "benchmarks/samtools_index_post_filter/{sample}.txt"
    log: "logs/samtools_index_post_filter/{sample}.out"  
    conda: "envs/samtools.yaml"        
    container: "https://depot.galaxyproject.org/singularity/samtools:1.21--h96c455f_1"
    threads: config['samtools_index_post_filter']['threads']
        
    message:
        "[SAMTOOLS INDEX POST FILTER] SAMPLE: {wildcards.sample}| INPUT: {input.filtered_bam}| OUTPUT: {output.filtered_bam_indexed}"
        
    shell:
        """
        set -euo pipefail
        samtools index \
        -@ {threads} \
        {input.filtered_bam} \
        {output.filtered_bam_indexed} \
        2> {log}
        """
