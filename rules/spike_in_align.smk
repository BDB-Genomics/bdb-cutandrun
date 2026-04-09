rule spike_in_align:
    input:
        R1=lambda wildcards: f"{config['spike_in_align']['input']['R1']}/{wildcards.sample}_R1_trimmed.fastq.gz",
        R2=lambda wildcards: f"{config['spike_in_align']['input']['R2']}/{wildcards.sample}_R2_trimmed.fastq.gz"
    output:
        bam=f"{config['spike_in_align']['output']['bam']}/{{sample}}_ecoli.bam",
        bai=f"{config['spike_in_align']['output']['bam']}/{{sample}}_ecoli.bam.bai"

    params:
        index=config['spike_in_align']['params']['index'],
        extra=config['spike_in_align']['params']['extra']

    resources:
        mem_mb=config['spike_in_align']['resources']['mem_mb'],
        time=config['spike_in_align']['resources']['time']

    benchmark: "benchmarks/spike_in_align/{sample}.txt"
    log: "logs/spike_in_align/{sample}.err"
    conda: "envs/bowtie2.yaml"
    container: "https://depot.galaxyproject.org/singularity/bowtie2:2.3.4.1--py27h2d50403_1"
    threads: config['spike_in_align']['threads']

    message:
        "[SPIKE-IN ALIGN] SAMPLE: {wildcards.sample} | R1: {input.R1} | R2: {input.R2} | E.coli BAM: {output.bam}"

    shell:
        """
        set -euo pipefail
        bowtie2 {params.extra} \
            -p {threads} \
            -x {params.index} \
            -1 {input.R1} \
            -2 {input.R2} \
            2> {log} | \
        samtools view -bS -F 4 - | \
        samtools sort -@ {threads} -o {output.bam} && \
        samtools index {output.bam}
        """
