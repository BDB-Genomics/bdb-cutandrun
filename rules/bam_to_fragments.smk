rule bam_to_fragments:
    input:
        bam=lambda wildcards: f"{config['bam_to_fragments']['input']['bam']}/{wildcards.sample}.filtered.bam"
    output:
        fragments=f"{config['bam_to_fragments']['output']['fragments']}/{{sample}}_fragments.bed"
    
    resources:
        mem_mb=config['bam_to_fragments']['resources']['mem_mb'],
        time=config['bam_to_fragments']['resources']['time']

    benchmark: "benchmarks/bam_to_fragments/{sample}.txt"
    log: "logs/bam_to_fragments/{sample}.err" 
    threads: config['bam_to_fragments']['threads']
    conda: "envs/bedtools.yaml"   
    container: "https://depot.galaxyproject.org/singularity/bedtools:2.31.1--h13024bc_3"

    message:
        "[BAM TO FRAGMENTS] SAMPLE: {wildcards.sample} | INPUT: {input.bam} | OUTPUT: {output.fragments}"
    
    shell:
        """
        set -euo pipefail
        # Sort by name, extract paired-end coords, and find Min(start) Max(end) for actual fragment size
        samtools sort -n -@ {threads} {input.bam} | \\
        bedtools bamtobed -bedpe -i stdin | \\
        awk -v OFS='\\t' '{{if($1==$4 && $6!=$9) {{start=($2<$5)?$2:$5; end=($3>$6)?$3:$6; print $1, start, end, $7, $8, $9}}}}' | \\
        sort -k1,1 -k2,2n > {output.fragments}
        """
