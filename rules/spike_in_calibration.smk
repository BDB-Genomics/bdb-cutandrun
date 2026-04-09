rule spike_in_calibration:
    input:
        bam=lambda wildcards: f"{config['spike_in_calibration']['input']['bam']}/{wildcards.sample}_ecoli.bam"
    output:
        scaling_factor=f"{config['spike_in_calibration']['output']['scaling_factor']}/{{sample}}_scaling_factor.txt"

    params:
        scale_constant=config['spike_in_calibration']['params']['scale_constant']

    resources:
        mem_mb=config['spike_in_calibration']['resources']['mem_mb'],
        time=config['spike_in_calibration']['resources']['time']

    benchmark: "benchmarks/spike_in_calibration/{sample}.txt"
    log: "logs/spike_in_calibration/{sample}.err"
    conda: "envs/samtools.yaml"
    container: "https://depot.galaxyproject.org/singularity/samtools:1.21--h96c455f_1"
    threads: config['spike_in_calibration']['threads']

    message:
        "[SPIKE-IN CALIBRATION] SAMPLE: {wildcards.sample} | E.coli BAM: {input.bam} | Scaling Factor: {output.scaling_factor}"

    shell:
        """
        set -euo pipefail
        # Count mapped spike-in reads (only primary, properly paired, mapped reads)
        spike_in_reads=$(samtools view -c -F 4 -f 2 {input.bam} 2>> {log})

        echo "Spike-in reads: ${{spike_in_reads}}" >> {log}

        if [ "${{spike_in_reads}}" -eq 0 ]; then
            echo "[WARNING] Zero spike-in reads detected for {wildcards.sample}. Setting scaling factor to 1." >> {log}
            echo "1.0" > {output.scaling_factor}
        else
            # scaling_factor = scale_constant / spike_in_reads
            scaling_factor=$(echo "scale=10; {params.scale_constant} / ${{spike_in_reads}}" | bc -l)
            echo "${{scaling_factor}}" > {output.scaling_factor}
            echo "Scaling factor: ${{scaling_factor}}" >> {log}
        fi
        """
