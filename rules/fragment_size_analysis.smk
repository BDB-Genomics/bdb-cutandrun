rule fragment_size_analysis:
    input:
        fragments=lambda wildcards: f"{config['fragment_size_analysis']['input']['fragments']}/{wildcards.sample}_fragments.bed"
        
    output:
        fragment_sizes=config['fragment_size_analysis']['output'] + "/{sample}_fragment_sizes.txt", 
        histogram=config['fragment_size_analysis']['output'] + "/{sample}_fragment.png", 
        stats=config['fragment_size_analysis']['output'] + "/{sample}_fragment_stats.txt"
    
    params:
        min_length=config['fragment_size_analysis']['params']['min_length'], 
        max_length=config['fragment_size_analysis']['params']['max_length'],  
        max_fragment=config['fragment_size_analysis']['params']['max_fragment'],    
        sample="{sample}"
        
    resources:
        mem_mb=config['fragment_size_analysis']['resources']['mem_mb'], 
        time=config['fragment_size_analysis']['resources']['time']

    benchmark: "benchmarks/fragment_size_analysis/{sample}.txt"
    log: "logs/fragment_size_analysis/{sample}.err"     
    conda: "envs/baseR.yaml"
    container: "docker://rocker/r-base:4.3.2"
    threads: config['fragment_size_analysis']['threads']
        
    message:
        "[FRAGMENT SIZE ANALYSIS] SAMPLES: {wildcards.sample}| INPUT: {input.fragments}| OUTPUT: {output.fragment_sizes} {output.histogram} {output.stats}|MIN LENGTH: {params.min_length}| MAX LENGTH: {params.max_length}| MAX FRAGMENT: {params.max_fragment} "
        
    shell:
        """
        set -euo pipefail
        echo '
        # Read fragment bounds
        data <- read.table("{input.fragments}", header=FALSE)
        fragments <- data$V3 - data$V2
    
        # Write fragment sizes
        write.table(fragments, "{output.fragment_sizes}", row.names=FALSE, col.names=FALSE, quote=FALSE)
    
        # Generate histogram
        png("{output.histogram}")
        hist(fragments, main="Fragment Size Distribution", xlab="Fragment Size (bp)", col="skyblue", breaks=50)
        dev.off()
    
        # Generate statistics
        stats_summary <- c(
              paste("Total_fragments:", length(fragments)),
              paste("Mean_size:", round(mean(fragments), 2)),
              paste("Min_size:", min(fragments)),
              paste("Max_size:", max(fragments))
        )
        writeLines(stats_summary, "{output.stats}")
        ' | Rscript - 2> {log}
        """
