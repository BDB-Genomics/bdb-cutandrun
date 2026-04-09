rule seacr_peak_calling:
    input:
        sorted_bedgraph = lambda wildcards: f"{config['seacr']['input']['sorted_bedgraph']}/{wildcards.sample}.sorted.bedGraph"
    
    output:
        stringent = f"{config['seacr']['output']['peaks']}/{{sample}}.peaks.stringent.bed",
        relaxed = f"{config['seacr']['output']['peaks']}/{{sample}}.peaks.relaxed.bed"

    params:
        background = config['seacr']['params']['background'],
        norm = config['seacr']['params']['norm'],
        stringency = config['seacr']['params']['stringency'],
        prefix = lambda wildcards, output: output.stringent.replace(".stringent.bed", "")

    resources:
        mem_mb = config['seacr']['resources']['mem_mb'],
        time = config['seacr']['resources']['time']

    benchmark: "benchmarks/seacr/{sample}.txt"
    log: "logs/seacr/{sample}.log"
    conda: "envs/seacr.yaml"
    container: "https://depot.galaxyproject.org/singularity/seacr:1.3--hdfd78af_2"
    threads: config['seacr']['threads']

    message:         
        "[SEACR Peak Calling] Sample: {wildcards.sample} | Input: {input.sorted_bedgraph} | Output Prefix: {params.prefix}"

    shell:
        """
        set -euo pipefail
        # If using the seacr wrapper/command from bioconda
        # Usage: seacr [target.bg] [threshold/control.bg] [norm/non] [stringent/relaxed] [output_prefix]
        SEACR_1.3.sh \
          {input.sorted_bedgraph} \
          {params.background} \
          {params.norm} \
          {params.stringency} \
          {params.prefix}    \
          2> {log}
        """

        
