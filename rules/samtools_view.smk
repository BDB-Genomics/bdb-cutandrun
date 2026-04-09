rule samtools_view:
    input:
        dedup_bam=lambda wildcards: f"{config['samtools_view']['input']['markdup_bam']}/{wildcards.sample}_noMT.sorted.dedup.bam"
        
    output:
        filtered_bam=f"{config['samtools_view']['output']['filtered_bam']}/{{sample}}.filtered.bam"
    
    params:
        minimum_mapq=config['samtools_view']['params']['MAPQ'], 
        filter_flags=config['samtools_view']['params']['flags']
    
    resources:
        mem_mb=config['samtools_view']['resources']['mem_mb'], 
        time=config['samtools_view']['resources']['time']
            
    benchmark: "benchmarks/samtools_view/{sample}.txt"        
    log: "logs/samtools_view/{sample}.out"             
    conda: "envs/samtools.yaml"
    container: "https://depot.galaxyproject.org/singularity/samtools:1.21--h96c455f_1"    
    threads: config['samtools_view']['threads']
        
    message:
        "[SAMTOOLS VIEW] SAMPLE: {wildcards.sample} | INPUT: {input.dedup_bam} | OUTPUT: {output.filtered_bam}| MINIMUM MAPQ: {params.minimum_mapq} | FILTER FLAGS: {params.filter_flags}"
        
    shell:
        """
        set -euo pipefail
        samtools view \
        -@ {threads} \
        -b \
        -q {params.minimum_mapq} \
        -F {params.filter_flags} \
        -f 2 \
        {input.dedup_bam} \
        -o {output.filtered_bam} \
        2> {log}
        """

   
