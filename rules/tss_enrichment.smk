rule tss_enrichment:
    input: 
        bam=lambda wildcards: f"{config['tss_enrichment']['input']['bam']}/{wildcards.sample}.filtered.bam", 
        bam_index=lambda wildcards: f"{config['tss_enrichment']['input']['bam_index']}/{wildcards.sample}.filtered.bam.bai"
        
    output:
        text=f"{config['tss_enrichment']['output']['dir']}/{{sample}}_tss_enrichment.txt", 
        pdf=f"{config['tss_enrichment']['output']['dir']}/{{sample}}_tss_enrichment.pdf"
        
    params:
        annotation=config['tss_enrichment']['params']['annotation'], 
        upstream=config['tss_enrichment']['params']['upstream'], 
        downstream=config['tss_enrichment']['params']['downstream'],
        min_tss=config['tss_enrichment']['params'].get('min_tss', 7.0)
        
    resources:
        mem_mb=config['tss_enrichment']['resources']['mem_mb'], 
        time=config['tss_enrichment']['resources']['time']
  
    log: "logs/tss_enrichment/{sample}.err"
    benchmark: "benchmarks/tss_enrichment/{sample}.txt"
    conda: "envs/tss_enrichment.yaml"
    container: "https://depot.galaxyproject.org/singularity/bioconductor-atacseqqc:1.22.0--r42hdfd78af_0"
    threads: config['tss_enrichment']['threads']
    message: "[TSS ENRICHMENT] SAMPLE: {wildcards.sample}| INPUT: {input.bam} | OUTPUT: {output.text} {output.pdf}| ANNOTATION: {params.annotation}| UPSTREAM: {params.upstream}| DOWNSTREAM: {params.downstream}"
        
    script:
        "scripts/tss_enrichment.R"
