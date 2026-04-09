rule samtools_stats:
    input:
        filtered_bam=lambda wildcards: f"{config['samtools_stats']['input']['filtered_bam']}/{wildcards.sample}.filtered.bam"
        
    output:
        stats=f"{config['samtools_stats']['output']['stats']}/{{sample}}_postFiltering.stats.txt"
    
    resources:
        mem_mb=config['samtools_stats']['resources']['mem_mb'], 
        time=config['samtools_stats']['resources']['time']
                    
    benchmark: "benchmarks/samtools_stats/{sample}.txt"        
    log: "logs/samtools_stats/{sample}.err"
    conda: "envs/samtools.yaml"
    container: "https://depot.galaxyproject.org/singularity/samtools:1.21--h96c455f_1"
    threads: config['samtools_stats']['threads']
        
    message:
        "[SAMTOOLS STATISTICS] SAMPLE: {wildcards.sample}| INPUT: {input.filtered_bam}| OUTPUT: {output.stats}"
        
    shell:
        """
        set -euo pipefail
        samtools stats \
        -@ {threads} \
        {input.filtered_bam} \
        > {output.stats} \
        2> {log} 
        """

   
