# BDB-Genomics CUT&RUN Pipeline

This repository hosts a robust, highly automated Snakemake pipeline designed for CUT&RUN (Cleavage Under Targets and Release Using Nuclease) sequencing data. It provides end-to-end processing—from raw FASTQ quality control and Bowtie2 alignment, to stringent deduplication, Spike-in calibration, SEACR peak calling, and final motif/heatmap generation. The pipeline is fully containerized, strictly typed, and fortified with automated quality control gating to ensure high reproducibility and fail-safe execution.

---

## 🏗️ Pipeline Architecture

```mermaid
graph TD
    %% Input
    Raw[Raw FASTQ Files] --> FastP[fastp<br>QC & Trimming]
    
    %% Alignment Branching
    FastP --> AlignTarget[Bowtie2<br>Target Genome]
    FastP --> AlignSpike[Bowtie2<br>Spike-in Genome]
    
    %% Target Processing
    AlignTarget --> Sort[samtools sort]
    Sort --> Mito[Remove Mitochondrial Reads]
    Mito --> Dedup[samtools markdup]
    Dedup --> Filter[samtools view<br>Filter MAPQ]
    Filter --> Blacklist[Remove Blacklisted Regions]
    
    %% QC & Gating
    Blacklist -.-> Picard[Picard & Qualimap QC]
    Blacklist -.-> QCGate{QC Gate<br>parse_qc_metrics.py}
    
    %% Spike in Calibration
    AlignSpike --> SpikeCalib[Spike-in Calibration Factor]
    
    %% Fragments & Coverage
    QCGate -- Pass --> Fragments[Extract Fragments]
    Fragments --> BedGraph[bedtools genomecov]
    
    %% Normalization applies to Coverage
    SpikeCalib -.->|Normalization| BedGraph
    
    %% Peak Calling
    BedGraph --> BigWig[Generate BigWig]
    BedGraph --> SEACR[SEACR Peak Calling]
    
    %% Downstream Analysis
    SEACR --> PeakAnnot[Peak Annotation]
    SEACR --> Motif[Motif Analysis]
    BigWig --> Heatmap[TSS Heatmaps]
    BigWig --> Correlation[Correlation Analysis]
    
    %% Reporting
    Picard -.-> MultiQC
    PeakAnnot -.-> MultiQC
    MultiQC[MultiQC Report &<br>aggregate_logs.py JSON]
    
    %% Styling Classes
    classDef input fill:#f8f9fa,stroke:#6c757d,color:#000;
    classDef process fill:#e2e3e5,stroke:#383d41,color:#000;
    classDef analysis fill:#d1ecf1,stroke:#0c5460,color:#000;
    classDef gate fill:#fff3cd,stroke:#856404,color:#856404;
    classDef report fill:#d4edda,stroke:#28a745,color:#155724;

    class Raw input;
    class FastP,AlignTarget,AlignSpike,Sort,Mito,Dedup,Filter,Blacklist,Fragments,BedGraph,SpikeCalib process;
    class SEACR,BigWig,PeakAnnot,Motif,Heatmap,Correlation analysis;
    class QCGate,Picard gate;
    class MultiQC report;
```
