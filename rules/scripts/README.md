# Pipeline Scripts

This directory contains the core Python utilities that power the CUT&RUN pipeline infrastructure. They ensure configuration safety, enforce quality control (QC), and collect performance telemetry.

---

## 🏗️ Pipeline Integration Architecture

```mermaid
graph TD
    %% Global Nodes
    Start((Pipeline Start))
    End((Pipeline Finish))
    
    %% Scripts
    V[validate_config.py]
    QC[parse_qc_metrics.py]
    A[aggregate_logs.py]
    
    %% Pipeline Flow
    Start --> V
    V -- Validation Fails --> Halt1[Halt Execution]
    V -- Validation Passes --> BuildDAG[Snakemake Runs DAG]
    
    BuildDAG -.-> QC
    QC -- Sample Fails Thresholds --> Halt2[Halt Sample Execution]
    QC -- Sample Passes --> Continue[Continue Processing]
    
    Continue -.-> End
    Halt1 -.-> A
    Halt2 -.-> A
    End --> A
    
    A --> JSON((pipeline_execution_summary.json))

    %% Styling
    classDef script fill:#cce5ff,stroke:#004085,color:#004085;
    classDef halt fill:#f8d7da,stroke:#dc3545,color:#721c24;
    classDef artifact fill:#fff3cd,stroke:#856404,color:#856404;
    
    class V,QC,A script;
    class Halt1,Halt2 halt;
    class JSON artifact;
```

---

## 📁 Individual Script Details
*Click on a script below to expand its specific critical features, code architecture, and logic flowchart.*

<details>
<summary><b><code>► validate_config.py</code></b> (Startup Validation)</summary>

<br>

**When it runs:** Immediately at pipeline startup.

Ensures fail-fast behavior before compute resources are wasted by verifying that the `config.yaml` and environment files are completely robust.

### Critical Features
- **Dynamic Configuration Key Discovery:** Scans all `.smk` rule files using Regular Expressions to dynamically guarantee every requested key actually exists in the config.
  ```python
  for raw_keys in CONFIG_ACCESS_PATTERN.findall(line):
      keys = tuple(CONFIG_KEY_PATTERN.findall(raw_keys))
      if keys:
          paths.add(keys)
  ```
- **Conda Environment Validation:** Verifies that the referenced `.yaml` environment files physically exist on disk before Snakemake attempts to build them.

### Validation Flowchart
```mermaid
graph TD
    Start([Run validate_config.py]) --> A[Load config.yaml]
    A --> Gate1{Is YAML valid?}
    Gate1 -- No --> Fail[Exit 1]
    Gate1 -- Yes --> B["Scan Smk files for config keys"]
    B --> Gate2{Do all keys exist?}
    Gate2 -- No --> Fail
    Gate2 -- Yes --> Success([Start Snakemake])

    classDef error fill:#f8d7da,stroke:#dc3545,color:#721c24;
    classDef success fill:#d4edda,stroke:#28a745,color:#155724;
    class Fail error;
    class Success success;
```

</details>

<details>
<summary><b><code>► parse_qc_metrics.py</code></b> (QC Gating)</summary>

<br>

**When it runs:** After alignment and peak calling for each individual sample.

Evaluates sample quality against strict, user-defined thresholds (like FRiP or Target Mapping Rate).

### Critical Features
- **Hard Gating & MultiQC Integration:** Failing samples immediately halt. Output telemetry is written directly to a JSON file for dashboard integration.
- **Early-Exit OOM Protection:** Streams file iterators and breaks early to guarantee zero Out-Of-Memory crashes, even if a user accidentally passes a massive `.bam` file.
- **Cross-Platform & Typed:** Uses `pathlib.Path` objects and `mypy` strict typing to eliminate OS-level path bugs.
  ```python
  def parse_frip(frip_path: Path) -> float | None:
      ...
  ```

### QC Logic Flowchart
```mermaid
graph TD
    Start([Run parse_qc_metrics.py]) --> A[Load FRiP, TSS, and BAM Stats]
    A --> B{Are values missing?}
    B -- Yes --> Fail[Flag as Failed]
    B -- No --> C[Calculate Metrics]
    C --> D{Metrics >= Target?}
    D -- No --> Fail
    D -- Yes --> Success[Flag as Passed]
    Fail --> Output[Write JSON & Log]
    Success --> Output
    Output --> Check{Overall FAILED?}
    Check -- Yes --> Kill([sys.exit 1 to halt downstream])

    classDef error fill:#f8d7da,stroke:#dc3545,color:#721c24;
    classDef success fill:#d4edda,stroke:#28a745,color:#155724;
    class Fail,Kill error;
    class Success success;
```

</details>

<details>
<summary><b><code>► aggregate_logs.py</code></b> (Telemetry Aggregation)</summary>

<br>

**When it runs:** At the very end of the pipeline (on both success and failure).

Sweeps all generated `benchmarks/` and `logs/` to produce a final, summarized JSON report for humans and AI agents.

### Critical Features
- **Memory Safe Streaming (OOM Protection):** Streams massive log files line-by-line using a rolling `deque` buffer to completely prevent Out-Of-Memory crashes.
  ```python
  error_lines: deque[str] = deque(maxlen=5)
  with open(filepath, "r") as f:
      for line in f:
          if is_actual_error(line):
              error_lines.append(line.strip())
  ```
- **False Positive Filtering:** Intelligently ignores tools that print harmless biology metrics disguised as errors.
  ```python
  false_positives = ["0 error", "no error", "zero error"]
  if any(fp in line_lower for fp in false_positives):
      return False
  ```

### Aggregation Flowchart
```mermaid
graph TD
    Start([Run aggregate_logs.py]) --> A{Did the pipeline fail?}
    A -- No (Success) --> B[Parse Benchmarks]
    A -- Yes (Error) --> C[Parse Benchmarks & Scan logs/]
    
    C --> D[Stream log files line-by-line]
    D --> E{Contains 'error' <br> but NOT '0 errors'?}
    E -- Yes --> F[Add to deque buffer]
    
    B --> G
    F --> G[Build JSON Output]
    G --> End([pipeline_execution_summary.json])
```

</details>
