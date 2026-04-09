rule sorted_bedgraph:
    input:
        bedgraph=lambda wildcards: f"{config['sorted_bedgraph']['input']['bedgraph']}/{wildcards.sample}.bedGraph"
        
    output:
        sorted_bedgraph=f"{config['sorted_bedgraph']['output']['sorted_bedgraph']}/{{sample}}.sorted.bedGraph"
        
    resources:
        mem_mb=config['sorted_bedgraph']['resources']['mem_mb'],
        time=config['sorted_bedgraph']['resources']['time']
    
    benchmark: "benchmarks/sorted_bedgraph/{sample}.txt"            
    log: "logs/sorted_bedgraph/{sample}.err"    
    threads: config['sorted_bedgraph']['threads']
        
    message:
        "[sort]  Sample:  {wildcards.sample} | BedGraph: {input.bedgraph} | Sorted BedGraph: {output.sorted_bedgraph} | Resources: {resources.mem_mb}...  "
        
    shell:
        """
        set -euo pipefail
        sort \
        -k1,1 -k2,2n \
        --parallel {threads} \
        -S {resources.mem_mb}M \
        {input.bedgraph} \
        > {output.sorted_bedgraph} \
        2> {log}
        """
        
