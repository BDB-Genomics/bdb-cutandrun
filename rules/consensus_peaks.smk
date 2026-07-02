rule consensus_peaks:
    input:
        peaks=expand("{path}/{sample}_filtered_peaks.bed", path=config['blacklist_region_filter']['output']['filtered_peaks'], sample=SAMPLES)

    output:
        consensus=f"{config['consensus_peaks']['output']['consensus']}/consensus_peaks.bed",
        counts=f"{config['consensus_peaks']['output']['counts']}/peak_sample_counts.txt"

    params:
        min_samples=config['consensus_peaks']['params']['min_samples'],
        merge_distance=config['consensus_peaks']['params']['merge_distance'],
        n_peaks=lambda wildcards, input: len(input.peaks)

    resources:
        mem_mb=lambda wildcards, input, attempt: max(config['consensus_peaks']['resources']['mem_mb'], int(input.size_mb * 1.5)) * attempt,
        time=lambda wildcards, attempt: config['consensus_peaks']['resources']['time'] * attempt,

    log: "logs/consensus_peaks/consensus.err"
    benchmark: "benchmarks/consensus_peaks/consensus.txt"
    conda: "envs/bedtools.yaml"
    container: "https://depot.galaxyproject.org/singularity/bedtools:2.31.1--h13024bc_3"
    threads: config['consensus_peaks']['threads']
    message: "[Consensus Peaks] Merging {params.n_peaks} peak sets | Min samples: {params.min_samples}"

    shell:
        """
        set -euo pipefail
        cat {input.peaks} | sort -k1,1 -k2,2n > {output.consensus}.merged.tmp

        bedtools merge -i {output.consensus}.merged.tmp \
            -d {params.merge_distance} \
        > {output.consensus}.candidate.bed

        > {output.consensus}.overlaps.tmp
        for peak_file in {input.peaks}; do
            sample=$(basename "$peak_file" _filtered_peaks.bed)
            bedtools intersect -u -a {output.consensus}.candidate.bed -b "$peak_file" \
            | awk -v s="$sample" '{{print $1"\\t"$2"\\t"$3"\\t"s}}' >> {output.consensus}.overlaps.tmp
        done

        awk -v min="{params.min_samples}" '
            {{
                key=$1"\\t"$2"\\t"$3
                count[key]++
            }}
            END {{
                for (k in count) {{
                    if (count[k] >= min) {{
                        print k"\\t"count[k]
                    }}
                }}
            }}
        ' {output.consensus}.overlaps.tmp | sort -k1,1 -k2,2n > {output.consensus}

        cp {output.consensus} {output.counts}

        rm -f {output.consensus}.merged.tmp {output.consensus}.candidate.bed {output.consensus}.overlaps.tmp
        """
