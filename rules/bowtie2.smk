rule bowtie2:
    input:
        R1 = lambda wildcards: f"{config['bowtie2']['input']['R1']}/{wildcards.sample}_R1_trimmed.fastq.gz", 
        R2 = lambda wildcards: f"{config['bowtie2']['input']['R2']}/{wildcards.sample}_R2_trimmed.fastq.gz",
     
    output:
        bam = f"{config['bowtie2']['output']}/{{sample}}.bam"
         
    params:
        index = config['global']['bowtie_index'],
        extra = config['bowtie2']['params']['extra']

    resources:
        mem_mb = config['bowtie2']['resources']['mem_mb'],
        time = config['bowtie2']['resources']['time'] 

    benchmark: "benchmark/bowtie2/{sample}.txt"
    log: "logs/bowtie2/{sample}.log"
    conda: "envs/bowtie2.yaml"
    container: "https://depot.galaxyproject.org/singularity/bowtie2:2.3.4.1--py27h2d50403_1"
    threads: config['bowtie2']['threads']

    shell:
        r"""
        set -euo pipefail

        bowtie2 \
            -p {threads} \
            -x {params.index} \
            {params.extra} \
            -1 {input.R1} \
            -2 {input.R2} \
            2> {log} | samtools view -Sb -F 4 -f 2 - > {output.bam} 2>> {log}
        """