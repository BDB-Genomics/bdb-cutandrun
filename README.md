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

---

## 🚀 Production-Ready Features

This pipeline has undergone a rigorous architecture and security audit, resulting in a hardened, fail-safe production-grade system.

### 1. Pre-Flight Configuration Validation
Before DAG execution, `rules/scripts/validate_config.py` enforces strict schema checks on `config.yaml`. It verifies that all referenced configurations exist, scalar values meet strict type boundaries (e.g., positive floats/integers), and required physical references (genomes, indices, blacklists) are present on disk.

### 2. Low-Resource Batch Orchestration
For environments with severe memory constraints (e.g., laptops with ≤4GB RAM), the `run_batched.py` orchestrator parses the sample sheet, strictly sanitizes sample names against directory traversal vulnerabilities, and sequentially orchestrates Snakemake execution in manageable cohorts to prevent Out-Of-Memory (OOM) failures.

### 3. Graceful Error Degradation
Analytic downstream scripts (`tss_enrichment.R`, `diff_binding.R`, `peak_annotation.R`) are built with fail-safe logic. In the event of catastrophic data quality (e.g., zero peaks called, insufficient library depth), the pipeline avoids unhandled crashes. Instead, it generates empty/dummy matrices and placeholder plots, logs the failure, and allows the remaining cohort to complete successfully.

### 4. Bulletproof Execution
* **Safe Shell Pipes:** All `shell:` directives utilize `set -euo pipefail` to ensure silent upstream piping errors immediately halt execution.
* **Type & Syntax Safety:** Prevents boolean coercion errors in file path generation by explicitly blocking `True`/`False`/`None` configuration bugs.
* **Command Injection Prevention:** Python subprocesses use sanitized arrays (`shell=False`) instead of vulnerable shell string interpolations.
* **Containerized Workflows:** Every bioinformatics tool relies on strictly pinned Conda environments (`envs/*.yaml`) and immutable BioContainer Singularity images, guaranteeing bit-for-bit reproducibility across machines.

---

## ⚙️ Quick Start

```bash
# 1. Edit configuration
vim config.yaml

# 2. Add your samples (Ensure fastq_r1 and fastq_r2 columns exist)
vim data/samples.tsv

# 3. Run the pipeline orchestrator (batches samples automatically)
python3 rules/scripts/run_batched.py --batch-size 4 --cores 8 --memory 16000
```
