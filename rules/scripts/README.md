# Pipeline Scripts & Telemetry

This directory contains utility scripts used by the CUT&RUN pipeline to handle execution, observability, and data formatting.

## `aggregate_logs.py`

This script is the core of the pipeline's observability architecture. It is automatically triggered by Snakemake upon pipeline completion (both success and failure). It sweeps the `benchmarks/` and `logs/` directories to generate a single, structured JSON report (`pipeline_execution_summary.json`) that can be easily parsed by AI Agents (like LangChain) or human engineers.

### Key Features
1. **Extension-Agnostic Log Sweeping:** Uses the `**/*` wildcard combined with an EAFP (Easier to Ask for Forgiveness than Permission) `try-except` block to recursively scan all outputs, ignoring directories and binary corruption gracefully.
2. **False Positive Filtering:** Prevents JSON bloat by filtering out tools that print harmless success metrics disguised as errors (e.g., "0 errors found", "error rate: 0").
3. **Automated Resource Calculation:** Parses Snakemake TSV benchmark files to calculate total CPU time and peak memory across the entire run.

### Data Flow Architecture

```mermaid
graph TD
    %% Main Entry Point
    Start((Pipeline Ends)) --> A[Snakemake calls aggregate_logs.py]
    A --> B{Did the pipeline fail?}

    %% Path 1: Success
    B -- No (Success) --> C[Parse Benchmarks Only]
    C --> D[Calculate total_cpu_seconds]
    C --> E[Calculate peak_memory_mb]
    D & E --> F[Build JSON Output]
    F --> G((pipeline_execution_summary.json))

    %% Path 2: Failure
    B -- Yes (Error) --> H[Parse Benchmarks]
    H --> I[Scan logs/ Directory]

    %% The Scanning Loop
    I --> J[Find **/* regardless of extension]
    J --> K{Is it a File?}
    
    %% EAFP Handling
    K -- No (Directory) --> L[try/except catches IOError & Skips]
    K -- Yes (File) --> M[Read file line-by-line]
    
    %% The Filtering Logic
    M --> N{Does line contain 'error', 'failed', 'fatal'?}
    N -- No --> O[Ignore Line]
    N -- Yes --> P{Is it a False Positive? \n e.g. '0 errors'}
    
    %% Verdict
    P -- Yes --> O
    P -- No --> Q[Flag as Genuine Error]
    
    %% Extraction
    Q --> R[Extract Rule & Target Name]
    R --> S[Save last 5 error snippets]
    
    %% Assembly
    S --> T[Calculate CPU & RAM]
    T --> U[Build JSON Output with Errors Array]
    U --> G

    %% Styling
    classDef success fill:#d4edda,stroke:#28a745,color:#155724;
    classDef error fill:#f8d7da,stroke:#dc3545,color:#721c24;
    classDef logic fill:#cce5ff,stroke:#004085,color:#004085;
    classDef artifact fill:#fff3cd,stroke:#856404,color:#856404;

    class B,N,P,K logic;
    class C,D,E success;
    class Q,R,S error;
    class G artifact;
```
