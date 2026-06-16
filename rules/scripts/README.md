# Pipeline Scripts & Telemetry

This directory contains utility scripts for the CUT&RUN pipeline.

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
