# Pipeline Scripts & Telemetry

This directory contains utility scripts for the CUT&RUN pipeline.

---

## `aggregate_logs.py`

This script is automatically triggered by Snakemake when the pipeline finishes. It sweeps the `benchmarks/` and `logs/` directories to generate a structured JSON report (`pipeline_execution_summary.json`).

### Key Features

**1. Default Path Fallback**
Prevents `IndexError` crashes by falling back to a default JSON output path if the user or Snakemake does not provide one in the terminal.
```python
if len(sys.argv) > 2:
    output_json = sys.argv[2]
else:
    output_json = "results/reporting/pipeline_execution_summary.json"
```

**2. Extension-Agnostic Sweeping**
Uses the `**/*` wildcard with a `try/except` block to safely scan all outputs. It gracefully skips directories and unreadable binary files without relying on strict `.log` or `.err` extensions.
```python
for filepath in sorted(glob.glob(f"{logs_dir}/**/*", recursive=True)):
    try:
        with open(filepath, "r") as f:
            lines = f.readlines()
    except (IOError, UnicodeDecodeError):
        continue
```

**3. False Positive Filtering**
Filters out tools that print harmless biology metrics disguised as errors (e.g., "0 errors").
```python
false_positives = ["0 error", "no error", "zero error"]
if any(fp in line_lower for fp in false_positives):
    return False
```

### Data Flow Architecture

```mermaid
graph TD
    %% Main Entry Point
    Start((Pipeline Ends)) --> A[Snakemake calls aggregate_logs.py]
    
    %% Fallback Logic
    A --> Args{Did user provide <br> output path?}
    Args -- Yes --> B1[Use provided path]
    Args -- No --> B2[Use default path]
    B1 & B2 --> B{Did the pipeline fail?}

    %% Path 1: Success
    B -- No (Success) --> C[Parse Benchmarks Only]
    C --> F[Build JSON Output]
    F --> G((pipeline_execution_summary.json))

    %% Path 2: Failure
    B -- Yes (Error) --> H[Parse Benchmarks]
    H --> I[Scan logs/ Directory]

    %% The Scanning Loop
    I --> J[Find **/* regardless of extension]
    J --> K{Is it a File?}
    
    %% EAFP Handling
    K -- No (Directory) --> L[try/except catches IOError & skips]
    K -- Yes (File) --> M[Read file line-by-line]
    
    %% The Filtering Logic
    M --> N{Does line contain <br> 'error' or 'failed'?}
    N -- No --> O[Ignore Line]
    N -- Yes --> P{Is it a False Positive? <br> e.g. '0 errors'}
    
    %% Verdict
    P -- Yes --> O
    P -- No --> Q[Flag as Genuine Error]
    
    %% Extraction
    Q --> R[Extract Rule & Target Name]
    R --> S[Save last 5 error snippets]
    
    %% Assembly
    S --> U[Build JSON Output with Errors]
    U --> G

    %% Styling
    classDef success fill:#d4edda,stroke:#28a745,color:#155724;
    classDef error fill:#f8d7da,stroke:#dc3545,color:#721c24;
    classDef logic fill:#cce5ff,stroke:#004085,color:#004085;
    classDef artifact fill:#fff3cd,stroke:#856404,color:#856404;

    class B,N,P,K,Args logic;
    class C,B1,B2 success;
    class Q,R,S error;
    class G artifact;
```

---

## `validate_config.py`

This script is automatically called by Snakemake at startup before building the DAG. It validates that your `config.yaml` and sample sheet contain all required keys, valid parameter ranges, and that all files exist on disk.

### Key Features

**1. Dynamic Configuration Key Discovery**
Instead of hardcoding a list of required keys, it scans the `Snakefile` and all `rules/*.smk` rule files using Regular Expressions to identify exactly what config keys are accessed by the pipeline code.
```python
for raw_keys in CONFIG_ACCESS_PATTERN.findall(line):
    keys = tuple(CONFIG_KEY_PATTERN.findall(raw_keys))
    if keys:
        paths.add(keys)
```

**2. Conda Environment Validation**
Scans all rule files for conda env requirements and verifies that the referenced `.yaml` environment files exist on disk.
```python
resolved_path = (workflow_file.parent / conda_path_str).resolve()
if not resolved_path.exists():
    errors.append(
        f"Conda environment file not found: '{conda_path_str}'"
    )
```

**3. Dynamic Reference Path Checking**
Iterates through the config map to dynamically identify reference genome files (`_fa`, `_bed`, `_gtf`, `_sizes`, `_db`, `blacklist`) and index prefixes (`bowtie_index`, `ecoli_index`), checking their existence on disk.
```python
is_global_ref = (next_prefix[0] == "global" and (
    key.endswith(("_fa", "_bed", "_gtf", "_index", "_sizes", "_db")) or
    key == "blacklist"
))
```

### Validation Flow Architecture

```mermaid
graph TD
    %% Start
    Start([Run validate_config.py]) --> A[Load config.yaml]
    
    %% Gate 1
    A --> Gate1{Is YAML valid?}
    Gate1 -- No --> Fail[Print Categorized Errors & Exit 1]
    
    %% Gate 2
    Gate1 -- Yes --> B["Scan Smk files for config[...] keys"]
    B --> Gate2{Do all keys exist in config.yaml?}
    Gate2 -- No --> Fail
    
    %% Gate 3
    Gate2 -- Yes --> C[Validate Parameter Suffixes <br> e.g. threads, mem_mb, time]
    C --> Gate3{Are parameter values valid?}
    Gate3 -- No --> Fail
    
    %% Gate 4
    Gate3 -- Yes --> D[Load sample sheet TSV]
    D --> Gate4{Are headers valid? <br> Do FASTQ files exist? <br> Any duplicates?}
    Gate4 -- No --> Fail
    
    %% Gate 5
    Gate4 -- Yes --> E[Scan global reference files <br> FASTA, GTF, Indexes]
    E --> Gate5{Do all files exist on disk?}
    Gate5 -- No --> Fail
    
    %% Gate 6
    Gate5 -- Yes --> F[Scan rule conda environments]
    F --> Gate6{Do env .yaml files exist?}
    Gate6 -- No --> Fail
    
    %% Success
    Gate6 -- Yes --> Success([Validation OK - Start Snakemake])

    %% Styling
    classDef error fill:#f8d7da,stroke:#dc3545,color:#721c24;
    classDef success fill:#d4edda,stroke:#28a745,color:#155724;
    classDef logic fill:#cce5ff,stroke:#004085,color:#004085;
    
    class Gate1,Gate2,Gate3,Gate4,Gate5,Gate6 logic;
    class Fail error;
    class Success success;
```
