rule samtools_index_postmarkdup:
    input:
        markdup_bam=lambda wildcards: f"{config['samtools_index_post_markdup']['input']['markdup_bam']}/{wildcards.sample}_noMT.sorted.dedup.bam"
        
    output:
        indexed_markdup_bam=f"{config['samtools_index_post_markdup']['output']['index']}/{{sample}}_noMT.sorted.dedup.bam.bai"

    resources:
        mem_mb=config['samtools_index_post_markdup']['resources']['mem_mb'], 
        time=config['samtools_index_post_markdup']['resources']['time']
             
    benchmark: "benchmarks/samtools_index/post_markdup/{sample}.txt"        
    log: "logs/samtools_index/post_markdup/{sample}.err"        
    conda: "envs/samtools.yaml"    
    container: "https://depot.galaxyproject.org/singularity/samtools:1.21--h96c455f_1"       
    threads: config['samtools_index_post_markdup']['threads']
        
    message:
        "[SAMTOOLS INDEX POST MARKDUP] SAMPLE: {wildcards.sample}| INPUT: {input.markdup_bam}| OUTPUT: {output.indexed_markdup_bam}"
        
    shell:
        """
        set -euo pipefail
        samtools index \
        -@ {threads} \
        {input.markdup_bam}\
        {output.indexed_markdup_bam} \
        2> {log}
        """
         
