rule bigwig_conversion:
    input:
        sorted_bedgraph=lambda wildcards:f"{config['bigwig']['input']['sorted_bedgraph']}/{wildcards.sample}.sorted.bedGraph"
        
    output:
        bigwig=f"{config['bigwig']['output']['bigwig']}/{{sample}}.bw"

    resources:
        mem_mb=config['bigwig']['resources']['mem_mb'], 
        time=config['bigwig']['resources']['time']
            
    params:
        genome=config['bigwig']['params']['genome']
        
    benchmark: "benchmarks/bigwig/{sample}.txt"
    log: "logs/bigwig/{sample}.err" 
    conda: "envs/bedGraph_to_bigwig.yaml"
    container: "https://depot.galaxyproject.org/singularity/ucsc-bedgraphtobigwig:472--h664eb37_2"     
    threads: config['bigwig']['threads']
            
    message:
       "[bedGraphToBigWig] Sample: {wildcards.sample} | Sorted BedGraph: {input.sorted_bedgraph} | BigWig: {output.bigwig} | Genome: {params.genome}... "
       
    shell:
        """
        set -euo pipefail
        bedGraphToBigWig \
        {input.sorted_bedgraph} \
        {params.genome} \
        {output.bigwig} \
        2> {log} 
        """
        
