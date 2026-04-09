rule samtools_sort:
    input:
        unsorted_bam=lambda wildcards: f"{config['samtools_sort']['input']['unsorted_bam']}/{wildcards.sample}.bam"
        
    output:
        bam_sorted=f"{config['samtools_sort']['output']['sorted_bam']}/{{sample}}.sorted.bam"
    
    resources:
        mem_mb=config['samtools_sort']['resources']['mem_mb'], 
        time=config['samtools_sort']['resources']['time']
            
    benchmark: "benchmarks/samtools_sort/{sample}.txt"        
    log: "logs/samtools_sort/{sample}.err"      
    conda: "envs/samtools.yaml"
    container: "https://depot.galaxyproject.org/singularity/samtools:1.21--h96c455f_1"        
    threads: config["samtools_sort"]["threads"]
        
    message:
        "[SAMTOOLS SORT] SAMPLE: {wildcards.sample}| INPUT: {input.unsorted_bam}| OUTPUT: {output.bam_sorted}"
        
    shell:
        """
        set -euo pipefail
        samtools sort \
        -@ {threads} \
        -O BAM \
        -o {output.bam_sorted} \
        {input.unsorted_bam} \
        2> {log} 
        """
        
        
        
