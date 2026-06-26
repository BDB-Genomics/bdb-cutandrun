rule differential_binding:
    input:
        counts=expand("{path}/{sample}_peak_counts.tsv", path=config['count_peaks']['output']['counts'], sample=SAMPLES),
        sample_sheet=config['global']['sample_sheet']

    output:
        results=f"{config['differential_binding']['output']['results']}/differential_binding_results.tsv",
        plot_volcano=f"{config['differential_binding']['output']['plots']}/volcano_plot.pdf",
        plot_ma=f"{config['differential_binding']['output']['plots']}/ma_plot.pdf",
        plot_heatmap=f"{config['differential_binding']['output']['plots']}/heatmap_plot.pdf",
        plot_pca=f"{config['differential_binding']['output']['plots']}/pca_plot.pdf"

    params:
        fdr_threshold=config['differential_binding']['params']['fdr_threshold'],
        log2fc_threshold=config['differential_binding']['params']['log2fc_threshold']

    resources:
        mem_mb=config['differential_binding']['resources']['mem_mb'],
        time=config['differential_binding']['resources']['time']

    log: "logs/differential_binding/deseq2.err"
    benchmark: "benchmarks/differential_binding/deseq2.txt"
    conda: "envs/r_analysis.yaml"
    threads: config['differential_binding']['threads']
    message: "[Differential Binding] Running DESeq2 Analysis on {input.sample_sheet}"

    script:
        "scripts/diff_binding.R"
