# Conditional package startup message suppression for clean logging / debugging support
if (Sys.getenv("SNAKEMAKE_DEBUG") == "TRUE") {
    library(ATACseqQC)
    library(GenomicFeatures)
    library(txdbmaker)
    library(GenomicAlignments)
    library(Rsamtools)
    library(ChIPpeakAnno)
    library(GenomeInfoDb)
} else {
    suppressPackageStartupMessages({
        library(ATACseqQC)
        library(GenomicFeatures)
        library(txdbmaker)
        library(GenomicAlignments)
        library(Rsamtools)
        library(ChIPpeakAnno)
        library(GenomeInfoDb)
    })
}

# Get command line arguments from snakemake
bamfile <- snakemake@input[["bam"]]
out_text <- snakemake@output[["text"]]
out_pdf <- snakemake@output[["pdf"]]
sample_name <- snakemake@wildcards[["sample"]]
annotation_file <- snakemake@params[["annotation"]]
upstream <- as.numeric(snakemake@params[["upstream"]])
downstream <- as.numeric(snakemake@params[["downstream"]])

cat("===========================================\n")
cat("TSS Enrichment Analysis (adapted for CUT&RUN)\n")
cat("===========================================\n")
cat("Sample:", sample_name, "\n")
cat("BAM file:", bamfile, "\n")
cat("Annotation:", annotation_file, "\n")
cat("===========================================\n\n")

cat("Loading transcript database from:", annotation_file, "\n")
txdb <- makeTxDbFromGFF(annotation_file)

# Check BAM chromosome names
cat("Checking BAM chromosome naming style...\n")
bam_chroms <- scanBamHeader(bamfile)[[1]]$targets
bam_chr_names <- names(bam_chroms)
cat("BAM chromosomes (first 5):", paste(head(bam_chr_names, 5), collapse=", "), "\n")

# Determine BAM naming style by checking standard chromosomes to avoid alternative contig bias
standard_chrom_matches <- grepl("^(chr)?[0-9XYM]+T?$", bam_chr_names)
has_chr_prefix <- if (any(standard_chrom_matches)) {
    any(grepl("^chr[0-9XYM]+T?$", bam_chr_names[standard_chrom_matches]))
} else {
    any(grepl("^chr", bam_chr_names))
}
cat("BAM uses", ifelse(has_chr_prefix, "UCSC", "NCBI/Ensembl"), "style naming\n\n")

# Load transcripts and create TSS regions
cat("Loading transcript database...\n")
txs <- transcripts(txdb)

# Create TSS regions BEFORE converting chromosome names
cat("Creating TSS regions...\n")
tss_regions <- promoters(txs, upstream=upstream, downstream=downstream)

# Convert TSS regions to match BAM chromosome naming style
# Robustly includes human, mouse, rat standard sequences and avoids mitochondrial build discrepancies
if(has_chr_prefix) {
    cat("Converting TSS regions to UCSC style (with 'chr' prefix)...\n")
    seqlevelsStyle(tss_regions) <- "UCSC"
    standard_chroms <- c(paste0("chr", c(1:99, "X", "Y", "M")), "chrMT")
} else {
    cat("Converting TSS regions to NCBI style (no 'chr' prefix)...\n")
    seqlevelsStyle(tss_regions) <- "NCBI"
    standard_chroms <- c(as.character(1:99), "X", "Y", "MT", "M")
}

# Keep only standard chromosomes that exist in the annotation and the BAM file header
available_chroms <- intersect(seqlevels(tss_regions), standard_chroms)
available_chroms <- intersect(available_chroms, bam_chr_names)
tss_regions <- keepSeqlevels(tss_regions, available_chroms, pruning.mode="coarse")

cat("TSS regions after filtering:", length(tss_regions), "regions\n")
cat("Using chromosomes:", paste(head(seqlevels(tss_regions), 10), collapse=", "), "\n\n")

# Read BAM file - restricted to TSS regions for extreme memory efficiency and OOM prevention
cat("Reading BAM file (optimized region-specific chunking)...\n")
bamParam <- ScanBamParam(
    flag = scanBamFlag(isProperPair = TRUE, 
                      isUnmappedQuery = FALSE,
                      isSecondaryAlignment = FALSE,
                      isSupplementaryAlignment = FALSE),
    what = c("qname", "flag", "mapq"),
    which = tss_regions
)

gal <- readGAlignments(bamfile, use.names = TRUE, param = bamParam)
cat("Read", format(length(gal), big.mark=","), "alignments within target windows\n")

# Gracefully handle zero alignments overlapping TSS (common in low-depth mock tests)
if (length(gal) == 0) {
    cat("[WARNING] Zero alignments found overlapping TSS regions. Creating fallback results and plots.\n")
    # Save fallback results text file
    result_df <- data.frame(
        Sample = sample_name, 
        TSS_Enrichment = 0.0,
        Total_Alignments = 0,
        TSS_Regions = length(tss_regions),
        Common_Chromosomes = 0,
        Quality = "Poor",
        stringsAsFactors = FALSE
    )
    write.table(result_df, file=out_text, sep="\t", quote=FALSE, row.names=FALSE)
    
    # Save fallback plot PDF
    pdf(out_pdf, width=10, height=5)
    plot(1, type = "n", xlim = c(-10, 10), ylim = c(-10, 10), 
         xlab = "", ylab = "", main = paste0(sample_name, " - TSS Enrichment"), axes=FALSE)
    text(0, 0, "Warning: Zero alignments overlapping TSS regions.\nCannot compute TSS enrichment profile.", cex=1.3, col="red")
    dev.off()
    
    cat("TSS Enrichment Analysis Complete (Graceful Fallback)!\n")
    quit(save="no", status=0)
}

# Check overlap between BAM and TSS regions
cat("\nChecking chromosome overlap...\n")
gal_chroms <- unique(as.character(seqnames(gal)))
tss_chroms <- unique(as.character(seqnames(tss_regions)))
common_chroms <- intersect(gal_chroms, tss_chroms)

cat("BAM chromosomes:", length(gal_chroms), "\n")
cat("TSS chromosomes:", length(tss_chroms), "\n")
cat("Common chromosomes:", length(common_chroms), "\n")

if(length(common_chroms) == 0) {
    stop("ERROR: No common chromosomes between BAM and TSS regions!\n",
         "BAM has: ", paste(head(gal_chroms, 5), collapse=", "), "\n",
         "TSS has: ", paste(head(tss_chroms, 5), collapse=", "))
}

cat("Common chromosomes:", paste(head(common_chroms, 10), collapse=", "), "\n\n")

# Keep only common chromosomes in both objects
gal <- keepSeqlevels(gal, common_chroms, pruning.mode="coarse")
tss_regions <- keepSeqlevels(tss_regions, common_chroms, pruning.mode="coarse")

cat("After filtering to common chromosomes:\n")
cat("  Alignments:", format(length(gal), big.mark=","), "\n")
cat("  TSS regions:", format(length(tss_regions), big.mark=","), "\n\n")

# Calculate TSS enrichment score
cat("Calculating TSS enrichment score...\n")

tsse_score <- tryCatch({
    # ATACseqQC::TSSEscore expects the original un-promoted transcripts annotation GRanges,
    # because it internally localizes exact TSS coordinates.
    txs_filtered <- keepSeqlevels(txs, common_chroms, pruning.mode="coarse")
    tsse_result <- TSSEscore(gal, txs = txs_filtered)
    score <- if(is.list(tsse_result)) tsse_result$TSSEscore else tsse_result
    cat("TSS Enrichment Score:", round(score, 4), "\n\n")
    score
}, error = function(e) {
    cat("ERROR in TSSEscore:", conditionMessage(e), "\n")
    cat("Attempting alternative calculation...\n")
    
    # Alternative: calculate enrichment manually
    reads_gr <- as(gal, "GRanges")
    overlaps <- countOverlaps(tss_regions, reads_gr)
    
    tss_coverage <- sum(overlaps > 0) / length(tss_regions)
    tss_avg_depth <- mean(overlaps[overlaps > 0])
    
    # Safely sum actual chromosome sizes on disk
    matched_idx <- match(common_chroms, names(bam_chroms))
    valid_idx <- matched_idx[!is.na(matched_idx)]
    genome_size <- sum(as.numeric(bam_chroms[valid_idx]))
    
    # Query index stats for total mapped reads across the genome without loading them
    idxstats <- idxstatsBam(bamfile)
    total_reads_count <- sum(idxstats$mapped)
    
    genome_avg <- total_reads_count / (genome_size / median(width(tss_regions)))
    
    score <- tss_avg_depth / max(genome_avg, 1)
    cat("Manual TSS Enrichment Score:", round(score, 4), "\n\n")
    score
})

# Determine quality based on dynamic/parameterized thresholds
min_tss <- if ("min_tss" %in% names(snakemake@params)) as.numeric(snakemake@params[["min_tss"]]) else 7.0
if(tsse_score > min_tss) {
    quality <- "Excellent"
    color <- "darkgreen"
} else if(tsse_score > (min_tss * 0.9)) {
    quality <- "Good" 
    color <- "green"
} else if(tsse_score > (min_tss * 0.7)) {
    quality <- "Acceptable"
    color <- "orange"
} else {
    quality <- "Poor"
    color <- "red"
}

cat("Quality Assessment:", quality, "\n")
cat("===========================================\n\n")

# Create publication-quality multi-panel plot
cat("Generating comprehensive TSS enrichment plots...\n")
# Aspect ratio optimized for side-by-side landscape visualization
on.exit(if (names(dev.cur()) != "null device") dev.off())
pdf(out_pdf, width=15, height=5)

# Set up layout for multiple plots side-by-side with perfect balanced weight
layout(matrix(c(1, 2, 3), 1, 3, byrow=TRUE))
par(mar=c(5, 5, 4, 2))

# PANEL 1: TSS Enrichment Profile (Main Plot)
cat("Panel 1: Computing TSS enrichment profile...\n")
tryCatch({
    reads <- coverage(gal)
    # Ensure tss_regions only contains chromosomes that actually have coverage in reads
    coverage_chroms <- names(reads)
    tss_regions_cov <- tss_regions[as.character(seqnames(tss_regions)) %in% coverage_chroms]
    tss_regions_cov <- keepSeqlevels(tss_regions_cov, intersect(seqlevels(tss_regions_cov), coverage_chroms), pruning.mode="coarse")
    
    n_sample <- min(length(tss_regions_cov), 10000)
    tss_sample <- tss_regions_cov
    if (length(tss_regions_cov) > n_sample) {
        set.seed(42)
        tss_sample <- tss_regions_cov[sample(length(tss_regions_cov), n_sample)]
        cat("  Sampling", n_sample, "TSS regions for visualization\n")
    }
    sigs <- featureAlignedSignal(
        reads,
        feature.gr = tss_sample,
        upstream = upstream,
        downstream = downstream,
        n.tile = 200
    )
    
    # Average signal
    avg_signal <- colMeans(sigs, na.rm = TRUE)
    
    # Dynamically select first 10% and last 10% of bins for robust baseline calculation
    n_bins <- length(avg_signal)
    first_ten_percent <- 1:round(n_bins * 0.1)
    last_ten_percent <- round(n_bins * 0.9):n_bins
    baseline <- mean(c(avg_signal[first_ten_percent], avg_signal[last_ten_percent]), na.rm = TRUE)
    if(baseline > 0 && !is.na(baseline)) {
        avg_signal <- avg_signal / baseline
    }
    
    # Defensive ylim selection to protect against infinite bounds on failed coverage
    max_val <- max(avg_signal, na.rm = TRUE)
    plot_ymax <- if (is.finite(max_val) && max_val > 0) max_val * 1.15 else 2.0
    
    # Create main plot with enhanced styling
    plot(avg_signal, 
         type = "l", 
         lwd = 4, 
         col = "#2E86AB",
         xlab = "Distance from TSS (bp)",
         ylab = "Normalized Read Density",
         main = paste0(sample_name, " - TSS Profile\nScore: ", 
                      round(tsse_score, 3), " (", quality, ")"),
         xaxt = "n",
         las = 1,
         ylim = c(0, plot_ymax),
         cex.lab = 1.4,
         cex.axis = 1.2,
         cex.main = 1.5)
    
    # Add shaded confidence region
    se_signal <- apply(sigs, 2, sd, na.rm=TRUE) / sqrt(nrow(sigs))
    polygon(c(1:n_bins, n_bins:1),
            c(avg_signal + se_signal, rev(avg_signal - se_signal)),
            col = rgb(0.18, 0.53, 0.67, 0.2), border = NA)
    
    # Redraw main line
    lines(avg_signal, lwd = 4, col = "#2E86AB")
    
    # Add custom x-axis
    axis(1, at = seq(1, n_bins, length.out = 5),
         labels = round(seq(-upstream, downstream, length.out = 5)),
         cex.axis = 1.2)
    
    # Add vertical line at TSS (the center bin)
    abline(v = round(n_bins / 2), lty = 2, col = "red", lwd = 2)
    
    # Add horizontal baseline
    if(baseline > 0) {
        abline(h = 1, lty = 3, col = "gray40", lwd = 1.5)
    }
    
    # Add grid
    grid(col = "gray70", lty = "dotted")
    
    # PANEL 2: Heatmap of individual TSS regions
    cat("Panel 2: Creating TSS heatmap...\n")
    par(mar=c(5, 5, 4, 2))
    
    # Sample and sort TSS regions by signal strength
    n_heatmap <- min(500, nrow(sigs))
    # Dynamically define peak region as the middle 10% of the bins to be fully generalizable to any n.tile resolution
    center_bin <- round(n_bins / 2)
    peak_half_width <- round(n_bins * 0.05)
    peak_bins <- (center_bin - peak_half_width):(center_bin + peak_half_width)
    
    signal_strength <- rowMeans(sigs[, peak_bins], na.rm=TRUE)
    top_idx <- order(signal_strength, decreasing=TRUE)[1:n_heatmap]
    
    heatmap_data <- sigs[top_idx, ]
    
    # Create color palette
    colors <- colorRampPalette(c("white", "yellow", "orange", "red", "darkred"))(100)
    
    # Plot heatmap
    image(t(heatmap_data[nrow(heatmap_data):1, ]),
          col = colors,
          xlab = "Distance from TSS (bp)",
          ylab = paste0("TSS Regions (top ", n_heatmap, " by signal)"),
          main = "TSS Signal Heatmap",
          axes = FALSE,
          cex.lab = 1.3,
          cex.main = 1.3)
    
    # Add axes
    axis(1, at = seq(0, 1, by = 0.25),
         labels = round(seq(-upstream, downstream, length.out = 5)),
         cex.axis = 1.1)
    axis(2, las = 1, cex.axis = 1.1)
    
    # Add TSS line
    abline(v = 0.5, col = "white", lwd = 2, lty = 2)
    
    # Add color scale legend
    legend_breaks <- seq(min(heatmap_data, na.rm=TRUE), 
                        max(heatmap_data, na.rm=TRUE), 
                        length.out = 5)
    legend("topright", 
           legend = round(legend_breaks, 2),
           fill = colorRampPalette(colors)(5),
           title = "Signal",
           cex = 0.9,
           bg = "white")
    
    # PANEL 3: Summary statistics
    cat("Panel 3: Creating summary plot...\n")
    par(mar=c(5, 5, 4, 2))
    
    # Calculate signal distribution dynamically based on bin count
    flank_width <- round(n_bins * 0.1)
    left_flank <- 1:flank_width
    right_flank <- (n_bins - flank_width + 1):n_bins
    
    peak_signal <- avg_signal[peak_bins]
    flanking_signal <- c(avg_signal[left_flank], avg_signal[right_flank])
    
    boxplot(list("TSS Peak\n(-250 to +250bp)" = peak_signal,
                 "Flanking Regions\n(±1500-2000bp)" = flanking_signal),
            col = c("#2E86AB", "#95D5D8"),
            main = "Signal Distribution",
            ylab = "Normalized Read Density",
            las = 1,
            cex.lab = 1.3,
            cex.axis = 1.2,
            cex.main = 1.3)
    
    # Add enrichment score
    text(1.5, max(c(peak_signal, flanking_signal)) * 0.9,
         paste0("Enrichment: ", round(tsse_score, 2), "x\n",
                "Quality: ", quality),
         cex = 1.4, col = color, font = 2)
    
    grid(col = "gray70", lty = "dotted")
    
}, error = function(e) {
    cat("Error in creating plots:", conditionMessage(e), "\n")
    
    # Fallback: simple plot
    plot(1, type = "n", 
         xlim = c(-upstream, downstream),
         ylim = c(0, max(2, tsse_score)),
         xlab = "Distance from TSS (bp)",
         ylab = "Enrichment Score",
         main = paste0(sample_name, "\nTSS Score: ", round(tsse_score, 3)),
         las = 1,
         cex.lab = 1.3,
         cex.main = 1.5)
    
    text(0, tsse_score/2, 
         paste0("TSS Enrichment Score:\n", round(tsse_score, 3)),
         cex = 2.5, col = color, font = 2)
    
    text(0, tsse_score * 0.75,
         paste0("Quality: ", quality),
         cex = 2, col = color)
    
    abline(v = 0, lty = 2, col = "red", lwd = 2)
    grid(col = "gray70")
})

dev.off()
cat("Plots saved to:", out_pdf, "\n\n")

# Save results
cat("Saving results...\n")
result_df <- data.frame(
    Sample = sample_name, 
    TSS_Enrichment = round(tsse_score, 4),
    Total_Alignments = length(gal),
    TSS_Regions = length(tss_regions),
    Common_Chromosomes = length(common_chroms),
    Quality = quality,
    stringsAsFactors = FALSE
)

write.table(result_df, file=out_text, sep="\t", 
            quote=FALSE, row.names=FALSE)

cat("Results saved to:", out_text, "\n")
cat("===========================================\n")
cat("TSS Enrichment Analysis Complete!\n")
cat("Final Score:", round(tsse_score, 4), "-", quality, "\n")
cat("===========================================\n")
