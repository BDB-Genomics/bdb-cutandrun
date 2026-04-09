rule samtools_markdup:
    input:
        sorted_bam_noMT_fixmate=lambda wildcards: f"{config['samtools_markdup']['input']['sorted_bam_noMT_fixmate']}/{wildcards.sample}_noMT.sorted.fixmate.bam"
        
    output:
        deduplicated_bam=f"{config['samtools_markdup']['output']['markdup_bam']}/{{sample}}_noMT.sorted.dedup.bam"
    
    params:
        remove_duplicates=config['samtools_markdup']['params']['remove_duplicates']    
    
    resources:
        mem_mb=config['samtools_markdup']['resources']['mem_mb'], 
        time=config['samtools_markdup']['resources']['time']
        
    benchmark: "benchmarks/samtools_markdup/{sample}.txt"        
    log: "logs/samtools_markdup/{sample}.err"        
    conda: "envs/samtools.yaml"    
    container: "https://depot.galaxyproject.org/singularity/samtools:1.21--h96c455f_1"    
    threads: config['samtools_markdup']['threads']
        
    message:
        "[SAMTOOLS MARKDUP] SAMPLE: {wildcards.sample}| INPUT: {input.sorted_bam_noMT_fixmate}| OUTPUT: {output.deduplicated_bam}"
        
    shell:
        """
        set -euo pipefail
        samtools markdup \
        -{params.remove_duplicates} \
        -@ {threads} \
        {input.sorted_bam_noMT_fixmate} \
        {output.deduplicated_bam} \
        2> {log}
        """

