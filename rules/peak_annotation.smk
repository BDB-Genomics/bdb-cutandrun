rule peak_annotation:
    input:
        filtered_peaks=lambda wildcards: f"{config['peak_annotation']['input']['filtered_peaks']}/{wildcards.sample}_filtered_peaks.bed"
   
    output:
        annotation=f"{config['peak_annotation']['output']}/{{sample}}_peak_annotation.txt",
        summary=f"{config['peak_annotation']['output']}/{{sample}}_peak_annotation_summary.txt"
        
    params:
        gff=config['global']['annotation_gtf'],
        genome=config['global']['genome_fa'],
        feature_types=config['peak_annotation']['params'].get('feature_types', "gene,exon,CDS")
       
    resources:
        mem_mb=config['peak_annotation']['resources']['mem_mb'],
        time=config['peak_annotation']['resources']['time']
                 
    benchmark: "benchmarks/peak_annotation/{sample}.txt"
    log: "logs/peak_annotation/{sample}.err"
    conda: "envs/chipseeker.yaml"
    container: "https://depot.galaxyproject.org/singularity/bioconductor-chipseeker:1.10.0--r3.3.1_0S"
    threads: config['peak_annotation']['threads']
   
    message:
        "[Peak annotation] Sample: {wildcards.sample} | Peaks: {input.filtered_peaks} | Output: {output.annotation}"
        
    script:
        "scripts/peak_annotation.R"

