# Peak annotation script using ChIPseeker stable APIs
# Exposes logging and safe error trapping

log_file <- file(snakemake@log[[1]], open = "wt")
sink(log_file)
sink(log_file, type = "message")

tryCatch({
  library(ChIPseeker)
  library(GenomicFeatures)
  library(txdbmaker)
  
  peakfile <- snakemake@input[["filtered_peaks"]]
  gff_file <- snakemake@params[["gff"]]
  
  if (file.info(peakfile)$size == 0) {
    message("Peak file is empty. Writing empty annotation and summary outputs.")
    
    # Write empty annotation table with header
    anno_df <- data.frame(seqnames=character(), start=integer(), end=integer(), width=integer(), strand=character(), annotation=character(), geneId=character(), distanceToTSS=integer(), stringsAsFactors=FALSE)
    write.table(anno_df, snakemake@output[["annotation"]], sep = "\t", row.names = FALSE, quote = FALSE)
    
    # Write empty summary table with header
    feature_summary <- data.frame(Feature=character(), Peak_Count=integer(), stringsAsFactors=FALSE)
    write.table(feature_summary, snakemake@output[["summary"]], sep = "\t", row.names = FALSE, quote = FALSE)
    
    message("Peak annotation completed successfully (empty file safeguard)!")
    return(TRUE)
  }
  
  message("Building TxDb database from GFF/GTF: ", gff_file)
  txdb <- makeTxDbFromGFF(gff_file, format = "gtf")
  
  message("Annotating peaks for file: ", peakfile)
  peakAnno <- annotatePeak(peakfile, TxDb = txdb, tssRegion = c(-3000, 3000), verbose = FALSE)
  
  # Coerce to stable DataFrame format
  anno_df <- as.data.frame(peakAnno)
  
  message("Writing detailed peak annotations to: ", snakemake@output[["annotation"]])
  write.table(anno_df, snakemake@output[["annotation"]], sep = "\t", row.names = FALSE, quote = FALSE)
  
  # Stable extraction of the annotation column
  message("Calculating genomic feature summary statistics using stable public API...")
  annotation_col <- anno_df$annotation
  
  # Clean up annotations (group complex subclasses into major groups if desired, or keep direct)
  feature_summary <- as.data.frame(table(annotation_col))
  colnames(feature_summary) <- c("Feature", "Peak_Count")
  
  message("Writing genomic feature summary stats to: ", snakemake@output[["summary"]])
  write.table(feature_summary, snakemake@output[["summary"]], sep = "\t", row.names = FALSE, quote = FALSE)
  
  message("Peak annotation completed successfully!")
}, error = function(e) {
  message("CRITICAL ERROR: Peak annotation failed!")
  message(conditionMessage(e))
  stop(e)
})
