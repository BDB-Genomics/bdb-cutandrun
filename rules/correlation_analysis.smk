
def get_bigwig_files(wildcards):
   """Generate  bigwig input files"""
   return expand("{path}/{sample}.bw",
                 path = config['correlation_analysis']['input']['bigwig'],
                 sample = SAMPLES)
                       

rule correlation_analysis: 
    input: 
        bigwig=get_bigwig_files
        
    output: 
         npz=f"{config['correlation_analysis']['output']}/matrix.npz", 
         tab=f"{config['correlation_analysis']['output']}/matrix.tab", 
         heatmap=f"{config['correlation_analysis']['output']}/correlation_heatmap.png",
         cor_matrix=f"{config['correlation_analysis']['output']}/correlation_values.tab"
         
    params:
        bin_size=config['correlation_analysis']['params']['bin_size']
        
    resources:
        mem_mb=config['correlation_analysis']['resources']['mem_mb'], 
        time=config['correlation_analysis']['resources']['time']

    benchmark: "benchmarks/correlation_analysis/correlation_analysis.txt"
    log: "logs/correlation_analysis/correlation_analysis.err"
    threads: config['correlation_analysis']['threads']
    conda: "envs/deeptools.yaml"
    container: "https://depot.galaxyproject.org/singularity/deeptools:3.5.5--pyhdfd78af_0"     

    message:
        "[multiBigwigSummary +  plotCorrelation] | BigWigs: {input.bigwig} | Outputs: {output.npz}, {output.tab}, {output.heatmap} | Binsize: {params.bin_size} ..."
         
    shell: 
        """
        set -euo pipefail
        multiBigwigSummary bins \
            --bwfiles {input.bigwig} \
            --binSize {params.bin_size} \
            --numberOfProcessors {threads} \
            --outFile {output.npz} \
            --outRawCounts {output.tab} \
            2> {log} && \
             
        plotCorrelation \
            --corData {output.npz} \
            --corMethod pearson \
            --whatToPlot heatmap \
            --plotNumbers \
            --outFileCorMatrix {output.cor_matrix} \
            --plotFile {output.heatmap} \
            --removeOutliers \
            --skipZeros \
            2>> {log}
   
        """
