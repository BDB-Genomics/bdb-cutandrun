rule fastp_trim :
    input: 
      R1 = lambda wildcards: FASTQ_R1[wildcards.sample],
      R2 = lambda wildcards: FASTQ_R2[wildcards.sample]
    
    output:
      R1_trimmed = f"{config['fastp']['output']['dir']}/{{sample}}_R1_trimmed.fastq.gz",
      R2_trimmed = f"{config['fastp']['output']['dir']}/{{sample}}_R2_trimmed.fastq.gz",
      html = f"{config['fastp']['output']['dir']}/{{sample}}.html",
      json = f"{config['fastp']['output']['dir']}/{{sample}}.json"
  
    params:
      trim_front1 = config["fastp"]["params"]["trim_front1"],
      trim_front2 = config["fastp"]["params"]["trim_front2"],
      length_required = config["fastp"]["params"]["length_required"]
      
    resources:
        mem_mb=config['fastp']['resources']['mem_mb'], 
        time=config['fastp']['resources']['time']
          
    benchmark: "benchmarks/fastp/{sample}.txt"
    log: "logs/fastp/{sample}.err"
    conda: "envs/fastp.yaml"
    container: "https://depot.galaxyproject.org/singularity/fastp:1.1.0--heae3180_0"
    threads: config["fastp"]["threads"]
    
    message:
      "[FASTP] SAMPLES: {input.R1} {input.R2}|OUTPUT: {output.R1_trimmed} {output.R2_trimmed} {output.html} {output.json}| TRIMFRONT1: {params.trim_front1}| TRIMFRONT2: {params.trim_front2}|LENGTH REQUIRED: {params.length_required}"
    
    shell:
      """
      set -euo pipefail
      fastp \
      -i {input.R1} \
      -I {input.R2} \
      -o {output.R1_trimmed} \
      -O {output.R2_trimmed} \
      --detect_adapter_for_pe \
      --trim_front1 {params.trim_front1} \
      --trim_front2 {params.trim_front2} \
      --length_required {params.length_required} \
      --thread {threads} \
      --html {output.html} \
      --json {output.json} \
      > {log} 2>&1
     """



 
    
