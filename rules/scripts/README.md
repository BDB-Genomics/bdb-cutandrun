# Pipeline Scripts

Core Python and R utilities that power the CUT&RUN pipeline's validation, quality control, analytics, and telemetry.

---

## 🏗️ Integration Architecture

```mermaid
graph TD
    Start((Pipeline Start)) --> V[validate_config.py]
    V -- Fail --> Halt1[Exit 1]
    V -- Pass --> DAG[Snakemake DAG]

    DAG --> QC[parse_qc_metrics.py]
    QC -- Sample Fails --> Halt2[Flag FAILED]
    QC -- Sample Passes --> Continue[Continue]

    DAG --> TSS[tss_enrichment.R]
    DAG --> Heatmap[run_heatmap.py]
    DAG --> PeakAnnot[peak_annotation.R]
    DAG --> DiffBind[diff_binding.R]

    Continue --> End((Pipeline Finish))
    Halt2 --> End
    End --> A[aggregate_logs.py]
    A --> JSON((pipeline_execution_summary.json))

    classDef script fill:#cce5ff,stroke:#004085,color:#004085;
    classDef rscript fill:#e8daef,stroke:#6c3483,color:#1a1a2e;
    classDef halt fill:#f8d7da,stroke:#dc3545,color:#721c24;
    classDef artifact fill:#fff3cd,stroke:#856404,color:#856404;

    class V,QC,Heatmap,A script;
    class TSS,PeakAnnot,DiffBind rscript;
    class Halt1,Halt2 halt;
    class JSON artifact;
```

---

## 📁 Script Reference

### Python Scripts

| Script | When it Runs | Purpose |
|---|---|---|
| `validate_config.py` | Before DAG | Scans `.smk` files for config references, verifies keys exist, checks scalar types, confirms physical files |
| `parse_qc_metrics.py` | After alignment | Evaluates FRiP, TSS enrichment, and mapping rates against thresholds; flags failures |
| `run_batched.py` | Manual invocation | Batches samples for sequential Snakemake execution on low-memory machines |
| `run_heatmap.py` | After BigWig | Wraps deepTools `computeMatrix` + `plotHeatmap`; handles empty peak files gracefully |
| `aggregate_logs.py` | After completion | Streams `benchmarks/` and `logs/` into a single JSON summary; filters false-positive errors |
| `generate_test_data.py` | CI/CD only | Builds synthetic reference genomes, indices, and paired-end FASTQs for automated testing |
| `test_validate_config.py` | CI/CD only | Unit tests for `validate_config.py` |

### R Scripts

| Script | When it Runs | Purpose |
|---|---|---|
| `tss_enrichment.R` | After filtering | Computes per-sample TSS enrichment scores from filtered BAMs; writes fallback outputs on zero overlaps |
| `diff_binding.R` | After peak counting | Runs DESeq2 differential binding with volcano, MA, PCA, and heatmap plots; handles < 10 peaks gracefully |
| `peak_annotation.R` | After blacklist filter | Annotates peaks with ChIPseeker/TxDb; writes empty frames if peak file is zero-size |

---

## 🔒 Fail-Safe Boundaries

Every analytic script implements defensive error handling to prevent a single bad sample from crashing a multi-day cohort run:

| Script | Failure Scenario | Behavior |
|---|---|---|
| `tss_enrichment.R` | Zero TSS overlaps | Writes `0.0` enrichment TSV + warning PDF |
| `diff_binding.R` | < 10 consensus peaks | Writes dummy matrices + placeholder plots |
| `peak_annotation.R` | Empty peak file | Writes empty data frames with correct headers |
| `run_heatmap.py` | Empty filtered peaks | Skips deepTools, writes placeholder image |
| `parse_qc_metrics.py` | Parse failure | Defaults metrics to `0.0`, flags sample as `FAILED` |

---

## 📊 Script Flowcharts

### 1. `validate_config.py` (Startup Validator)
<details>
<summary>▶ Click to Expand Flowchart</summary>

```mermaid
graph TD
    A[config.yaml] --> B(Load & Parse YAML)
    B --> C{Syntactically Valid?}
    C -- No --> D[Exit 1]
    C -- Yes --> E(Scan .smk rules for config keys)
    E --> F{All keys present?}
    F -- No --> D
    F -- Yes --> G(Verify type bounds & physical path existence)
    G --> H{All valid?}
    H -- No --> D
    H -- Yes --> I[Exit 0 / Allow Execution]
```

</details>

### 2. `parse_qc_metrics.py` (QC Gate)
<details>
<summary>▶ Click to Expand Flowchart</summary>

```mermaid
graph TD
    A[BAM Stats, FRiP, TSS Enrichment] --> B(Load metrics for sample)
    B --> C{Values present?}
    C -- No --> D[Set defaults to 0.0 & flag FAILED]
    C -- Yes --> E(Check against user-defined thresholds)
    E --> F{All thresholds met?}
    F -- No --> G[Flag sample FAILED]
    F -- Yes --> H[Flag sample PASSED]
    D --> I(Write metrics to JSON & log)
    G --> I
    H --> I
    I --> J{Did sample FAIL?}
    J -- Yes --> K[Exit 1 to halt downstream]
    J -- No --> L[Exit 0]
```

</details>

### 3. `run_batched.py` (Low-Resource Batch Orchestrator)
<details>
<summary>▶ Click to Expand Flowchart</summary>

```mermaid
graph TD
    A[samples.tsv] --> B(Validate sample names regex)
    B --> C{Contains traversal/invalid chars?}
    C -- Yes --> D[Exit 1]
    C -- No --> E(Chunk samples into batches)
    E --> F{Dry Run?}
    F -- Yes --> G[Print batches & Exit 0]
    F -- No --> H(Sequentially invoke Snakemake per batch)
    H --> I[Run final MultiQC on complete cohort]
```

</details>

### 4. `run_heatmap.py` (Heatmap Visualizer)
<details>
<summary>▶ Click to Expand Flowchart</summary>

```mermaid
graph TD
    A[BigWig + Filtered Peaks] --> B{Is peak file empty?}
    B -- Yes --> C[Write placeholder heatmap image & log warning]
    B -- No --> D(Run deepTools computeMatrix)
    D --> E(Run deepTools plotHeatmap)
```

</details>

### 5. `aggregate_logs.py` (Telemetry Aggregater)
<details>
<summary>▶ Click to Expand Flowchart</summary>

```mermaid
graph TD
    A[benchmarks/ + logs/] --> B{Pipeline failed?}
    B -- Yes --> C(Scan logs line-by-line via rolling deque buffer)
    C --> D(Filter out false positive warnings)
    D --> E(Add actual errors to summary)
    B -- No --> F(Parse time & memory metrics from benchmarks)
    F --> G(Format final telemetry report)
    E --> G
    G --> H[pipeline_execution_summary.json]
```

</details>

### 6. `generate_test_data.py` (CI/CD Synthetic Generator)
<details>
<summary>▶ Click to Expand Flowchart</summary>

```mermaid
graph TD
    A[Start] --> B(Build small synthetic target & E.coli genomes)
    B --> C(Generate GTF annotation & chrom.sizes)
    C --> D{bowtie2-build on PATH?}
    D -- No --> E[Raise FileNotFoundError]
    D -- Yes --> F(Build target & spike-in indices)
    F --> G(Simulate paired-end FASTQs via random sampling)
```

</details>

### 7. `tss_enrichment.R` (TSS Coverage Engine)
<details>
<summary>▶ Click to Expand Flowchart</summary>

```mermaid
graph TD
    A[Filtered BAM + GTF] --> B{Any alignment overlaps with TSS?}
    B -- No --> C[Write 0.0 score TSV & warning placeholder PDF]
    B -- Yes --> D(Calculate coverage around TSS matrix)
    D --> E(Normalize against background & compute TSS enrichment score)
    E --> F[Save score TSV & TSS profile plot PDF]
```

</details>

### 8. `diff_binding.R` (DESeq2 Contrast Engine)
<details>
<summary>▶ Click to Expand Flowchart</summary>

```mermaid
graph TD
    A[Peak Count Matrix + Metadata] --> B{Peak count >= 10?}
    B -- No --> C[Write empty results table & placeholder plot PDFs]
    B -- Yes --> D(Run DESeq2 differential analysis)
    D --> E(Generate Volcano, MA, PCA, and Pheatmap plots)
    E --> F[Save differential TSV & diagnostic PDFs]
```

</details>

### 9. `peak_annotation.R` (ChIPseeker Annotator)
<details>
<summary>▶ Click to Expand Flowchart</summary>

```mermaid
graph TD
    A[Filtered Peaks + GTF] --> B{Peak file empty?}
    B -- Yes --> C[Write empty annotation TSV & summary table]
    B -- No --> D(Build TxDb database from GTF)
    D --> E(Annotate peak distances to TSS using ChIPseeker)
    E --> F[Save annotation TSV & feature statistics]
```

</details>
