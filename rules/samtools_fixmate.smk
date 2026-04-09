rule samtools_fixmate:
    input:
        sorted_bam_noMT = lambda wildcards: f"{config['samtools_fixmate']['input']['sorted_bam_noMT']}/{wildcards.sample}_noMT.sorted.bam"
    
    output:
        sorted_bam_noMT_fixmate = f"{config['samtools_fixmate']['output']['sorted_bam_noMT_fixmate']}/{{sample}}_noMT.sorted.fixmate.bam"

    resources:
        mem_mb = config["samtools_fixmate"]['resources']['mem_mb'], 
        time = config["samtools_fixmate"]['resources']['time']

    benchmark: "benchmarks/samtools_fixmate/{sample}_noMT.sorted.fixmate.bam.txt"
    log: "logs/samtools_fixmate/{sample}_noMT.sorted.fixmate.bam.log"
    conda: "envs/samtools.yaml"
    container: "https://depot.galaxyproject.org/singularity/samtools:1.21--h96c455f_1"
    threads: config["samtools_fixmate"]["threads"]

    message:
        "[SAMTOOLS FIXMATE] SAMPLE: {wildcards.sample}| INPUT: {input.sorted_bam_noMT}| OUTPUT: {output.sorted_bam_noMT_fixmate}"
 
    shell:
        """
        set -euo pipefail
        samtools sort -n -@ {threads} {input.sorted_bam_noMT} |  samtools fixmate -m -@ {threads} - - | samtools sort -@ {threads} -o {output.sorted_bam_noMT_fixmate} - 2> {log}
       """ 
       
