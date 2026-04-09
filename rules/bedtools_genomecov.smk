rule bedtools_genomecov:
    input:
        fragments=lambda wildcards: f"{config['bedtools_genomecov']['input']['fragments']}/{wildcards.sample}_fragments.bed",
        scaling_factor=lambda wildcards: f"{config['bedtools_genomecov']['input']['scaling_factor']}/{wildcards.sample}_scaling_factor.txt"

    output:
        bedgraph=f"{config['bedtools_genomecov']['output']['bedgraph']}/{{sample}}.bedGraph"

    params:
        extra=config['bedtools_genomecov']['params']['extra'],
        genome=config['global']['genome_chrom_sizes']

    resources:
        mem_mb=config['bedtools_genomecov']['resources']['mem_mb'],
        time=config['bedtools_genomecov']['resources']['time']

    benchmark: "benchmarks/bedtools_genomecov/{sample}.txt"
    log: "logs/bedtools_genomecov/{sample}.err"
    conda: "envs/bedtools.yaml"
    container: "https://depot.galaxyproject.org/singularity/bedtools:2.31.1--h13024bc_3"
    threads: config['bedtools_genomecov']['threads']

    message:
        "[bedtools genomecov] sample: {wildcards.sample} | Fragments: {input.fragments} | Scale: {input.scaling_factor} | Output: {output.bedgraph}"

    shell:
        """
        set -euo pipefail
        scale=$(cat {input.scaling_factor}) && \
        echo "Applying spike-in scaling factor: ${{scale}}" >> {log} && \

        bedtools genomecov \
          -i {input.fragments} \
          -g {params.genome} \
          -scale ${{scale}} \
          {params.extra} \
          > {output.bedgraph} \
          2>> {log}
        """
