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
