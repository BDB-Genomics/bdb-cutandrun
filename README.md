# BDB-Genomics CUT&RUN Pipeline

A production-grade Snakemake pipeline for CUT&RUN sequencing data. Handles the full lifecycle from raw FASTQ reads through alignment, spike-in calibration, peak calling, differential binding analysis, and final reporting.

---

## 🏗️ Pipeline Architecture

```mermaid
graph TD
    %% ── Stage 1: Preprocessing ──
    Raw[Raw FASTQ Files] --> FastP[fastp<br>QC & Trimming]
    FastP --> FastQC[FastQC]

    %% ── Stage 2: Alignment ──
    FastP --> AlignTarget[Bowtie2<br>Target Genome]
    FastP --> AlignSpike[Bowtie2<br>Spike-in E. coli]

    %% ── Stage 3: Post-Alignment ──
    AlignTarget --> Sort[samtools sort]
    Sort --> MitoCalc[Calculate Mito Reads]
    MitoCalc --> MitoRm[Remove Mito Reads]
    MitoRm --> Fixmate[samtools fixmate]
    Fixmate --> Dedup[samtools markdup]
    Dedup --> Filter[samtools view<br>MAPQ Filter]
    Filter --> Stats[samtools stats]
    Filter --> Fragments[BAM to Fragments]
    Fragments --> FragSize[Fragment Size Analysis]

    %% ── Stage 4: QC & Gating ──
    Filter -.-> Picard[Picard Metrics]
    Filter -.-> Qualimap[Qualimap BamQC]
    Filter -.-> Preseq[Preseq Complexity]
    Filter -.-> TSS[TSS Enrichment]

    %% ── Stage 5: Spike-in Calibration ──
    AlignSpike --> SpikeCalib[Spike-in<br>Calibration Factor]

    %% ── Stage 6: Coverage ──
    Fragments --> BedGraph[bedtools genomecov]
    SpikeCalib -.->|Normalization| BedGraph
    BedGraph --> SortBG[Sort BedGraph]
    SortBG --> BigWig[BigWig Conversion]

    %% ── Stage 7: Peak Calling ──
    SortBG --> SEACR[SEACR Peak Calling]
    SEACR --> Blacklist[Blacklist Filter]

    %% ── Stage 8: Downstream Analysis ──
    Blacklist --> PeakAnnot[Peak Annotation<br>ChIPseeker]
    Blacklist --> Motif[Motif Analysis<br>HOMER]
    BigWig --> Heatmap[TSS Heatmaps<br>deepTools]
    BigWig --> Correlation[Sample Correlation<br>deepTools]

    %% ── Stage 9: Differential Binding ──
    Blacklist --> Consensus[Consensus Peaks]
    Consensus --> CountPeaks[Count Peaks]
    CountPeaks --> DiffBind[Differential Binding<br>DESeq2]

    %% ── Stage 10: Reporting ──
    Picard -.-> MultiQC[MultiQC Report]
    FastQC -.-> MultiQC
    PeakAnnot -.-> MultiQC

    %% ── Styling ──
    classDef input fill:#f8f9fa,stroke:#6c757d,color:#000;
    classDef process fill:#e2e3e5,stroke:#383d41,color:#000;
    classDef analysis fill:#d1ecf1,stroke:#0c5460,color:#000;
    classDef diffbind fill:#e8daef,stroke:#6c3483,color:#1a1a2e;
    classDef qc fill:#fff3cd,stroke:#856404,color:#856404;
    classDef report fill:#d4edda,stroke:#28a745,color:#155724;

    class Raw input;
    class FastP,AlignTarget,AlignSpike,Sort,MitoCalc,MitoRm,Fixmate,Dedup,Filter,Stats,Fragments,FragSize,BedGraph,SortBG,SpikeCalib process;
    class SEACR,Blacklist,BigWig,PeakAnnot,Motif,Heatmap,Correlation analysis;
    class Consensus,CountPeaks,DiffBind diffbind;
    class Picard,Qualimap,Preseq,TSS,FastQC qc;
    class MultiQC report;
```

---

## ⚙️ Quick Start

```bash
# 1. Configure paths, resources, and parameters
vim config.yaml

# 2. Populate sample sheet (columns: sample, replicate, condition, fastq_r1, fastq_r2)
vim data/samples.tsv

# 3. Standard execution
snakemake --cores 8 --use-conda

# 4. Low-resource batch mode (≤4GB RAM machines)
python3 rules/scripts/run_batched.py --batch-size 2 --cores 4 --memory 4000
```

---

## 🔒 Security & Robustness

| Layer | Mechanism |
|---|---|
| **Pre-flight validation** | `validate_config.py` checks all config keys, scalar types, and physical file paths before DAG construction |
| **Sample sanitization** | Regex rejects shell metacharacters and `..` path traversal in sample names |
| **Shell safety** | Every rule uses `set -euo pipefail`; Python subprocesses use `shell=False` |
| **Graceful degradation** | R/Python analytics write placeholder outputs on zero-data scenarios instead of crashing |
| **Type safety** | Config path extractor rejects boolean/None coercion into file paths |
| **Reproducibility** | Pinned Conda environments + Singularity container directives on every rule |
