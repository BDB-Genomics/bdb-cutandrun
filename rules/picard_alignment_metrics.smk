rule picard_CollectAlignmentSummaryMetrics:
    input:
        markdup_bam=lambda wildcards:f"{config['picard_collect_alignment_summary_metrics']['input']['markdup_bam']}/{wildcards.sample}_noMT.sorted.dedup.bam"
        
    output:
        alignment_metrics=f"{config['picard_collect_alignment_summary_metrics']['output']['alignment_metrics']}/{{sample}}.alignment_metrics.txt"
        
    params:
        reference_genome=ancient(config['picard_collect_alignment_summary_metrics']['params']['reference_genome']), 
        validation_stringency=config['picard_collect_alignment_summary_metrics']['params']['validation_stringency']
        
    resources:
        mem_mb=config['picard_collect_alignment_summary_metrics']['resources']['mem_mb'], 
        time=config['picard_collect_alignment_summary_metrics']['resources']['time']

    benchmark: "benchmarks/picard/CollectAlignmentSummaryMetrics/{sample}.txt"
    log: "logs/picard/CollectAlignmentSummaryMetrics/{sample}.err"
    conda: "envs/picard_metrics.yaml"
    container: "https://depot.galaxyproject.org/singularity/picard:3.3.0--hdfd78af_0"
    threads: config['picard_collect_alignment_summary_metrics']['threads']
        
    message:
        "[PICARD COLLECTALIGNMENTSUMMARYMETRICS] SAMPLE: {wildcards.sample}| INPUT: {input.markdup_bam}| OUTPUT: {output.alignment_metrics}| REFERENCE GENOME: {params.reference_genome}| VALIDATION STRINGENCY: {params.validation_stringency}."
        
    shell:
        """
        PICARD_VERSION=$(picard --help 2>&1 | head -n 1 || echo "Picard Version Unknown" )
        echo "PICARD VERSION: ${{PICARD_VERSION}}" >> {log}
        
        set -euo pipefail 
        
        picard CollectAlignmentSummaryMetrics \
        --INPUT {input.markdup_bam} \
        --OUTPUT {output.alignment_metrics} \
        --REFERENCE_SEQUENCE {params.reference_genome} \
        --VALIDATION_STRINGENCY {params.validation_stringency} \
        2>> {log} 

        EXIT_STATUS=$?
        if [ "${{EXIT_STATUS}}" -eq 0 ]; then 
           echo "SUCCESSFULL; EXIT STATUS: ${{EXIT_STATUS}}" >> {log}
        else 
           echo "UNSUCCESSFULL; EXIT STATUS:  ${{EXIT_STATUS}}" >> {log}
        fi  
        """   
