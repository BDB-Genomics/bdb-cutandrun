rule heatmap:
    input:
        filtered_peaks=lambda wildcards: f"{config['heatmap']['input']['filtered_peaks']}/{wildcards.sample}_filtered_peaks.bed",
        bigwig=lambda wildcards: f"{config['heatmap']['input']['bigwig']}/{wildcards.sample}.bw"
        
    output:
        matrix=f"{config['heatmap']['output']['matrix']}/{{sample}}_matrix.gz", 
        regions=f"{config['heatmap']['output']['regions']}/{{sample}}_regions.bed", 
        plot=f"{config['heatmap']['output']['plot']}/{{sample}}_tss_heatmap.pdf"
        
    params:
        upstream=config['heatmap']['params'].get('upstream', 3000),
        downstream=config['heatmap']['params'].get('downstream', 3000), 
        colormap=config['heatmap']['params'].get("colormap", "coolwarm"),
        binsize=config['heatmap']['params'].get('bin_size', 10)

    resources:
        mem_mb=config['heatmap']['resources']['mem_mb'], 
        time=config['heatmap']['resources']['time']
        
    benchmark: "benchmarks/heatmap/{sample}.txt"
    log:
        matrix="logs/heatmap/matrix/{sample}.err", 
        plot="logs/heatmap/plot/{sample}.err" 
    conda: "envs/deeptools.yaml"
    container: "https://depot.galaxyproject.org/singularity/deeptools:3.5.5--pyhdfd78af_0"
    threads: config['heatmap']['threads']    
        
    message:
        "[deepTools heatmap] Sample: {wildcards.sample} | BigWig: {input.bigwig} | Peaks: {input.filtered_peaks} | Output: {output.plot}"
        
    script:
        "scripts/run_heatmap.py"

