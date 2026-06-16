#!/usr/bin/env python3
"""Aggregate pipeline logs and benchmarks into a single structured JSON summary.

Adapted from the BDB-Genomics ATAC-seq Framework.
Sweeps logs/ and benchmarks/ directories, filters noise and false positives,
and produces a clean pipeline_execution_summary.json for humans and AI agents.
"""

import os
import json
import sys
import glob
import csv
from datetime import datetime


def parse_benchmarks(benchmarks_dir="benchmarks"):
    """Parse all Snakemake benchmark TSV files into structured dicts.

    Each benchmark file contains columns like: s, h:m:s, max_rss, max_vms, etc.
    """
    metrics = []
    if not os.path.exists(benchmarks_dir):
        return metrics

    for filepath in sorted(glob.glob(f"{benchmarks_dir}/**/*.txt", recursive=True)):
        rule_name = os.path.basename(os.path.dirname(filepath))
        sample_name = os.path.basename(filepath).replace(".txt", "")
        try:
            with open(filepath, "r") as f:
                reader = csv.DictReader(f, delimiter="\t")
                for row in reader:
                    metrics.append({
                        "rule": rule_name,
                        "sample": sample_name,
                        "cpu_time_seconds": float(row.get("s", 0)),
                        "peak_memory_mb": float(row.get("max_rss", 0)),
                    })
        except (ValueError, KeyError):
            continue
    return metrics


def is_actual_error(line):
    """Determine if a log line contains a real error, filtering out false positives.

    Many bioinformatics tools emit lines like '0 errors found' or 'error rate: 0.00%'
    which are SUCCESS messages, not failures. This function filters those out.
    """
    line_lower = line.lower()

    # Must contain an error-like keyword
    has_error_keyword = any(
        k in line_lower
        for k in ["error", "exception", "failed", "fatal", "critical", "traceback"]
    )
    if not has_error_keyword:
        return False

    # Filter out common false positive messages
    false_positives = [
        "0 error", "no error", "zero error", "error rate: 0", "errors: 0",
        "no exception", "0 exception", "exception: none", "successful",
        "0 failed", "no failed", "errors = 0", "error_rate", "overall error",
        "alignment error rate", "mismatch error",
    ]
    if any(fp in line_lower for fp in false_positives):
        return False

    return True


def extract_errors(logs_dir="logs"):
    """Walk the logs/ directory and extract genuine error lines from log files.

    Scans both .log and .err files (CUT&RUN uses both patterns).
    Returns the last 5 real error lines per file to keep the output concise.
    """
    errors = []
    if not os.path.exists(logs_dir):
        return errors

    # Search all files in the logs directory regardless of extension
    for filepath in sorted(glob.glob(f"{logs_dir}/**/*", recursive=True)):
        try:
            with open(filepath, "r") as f:
                lines = f.readlines()
        except (IOError, UnicodeDecodeError):
            continue

        error_lines = [l.strip() for l in lines if is_actual_error(l)]
        if error_lines:
            rule_name = os.path.basename(os.path.dirname(filepath))
            sample_name = os.path.splitext(os.path.basename(filepath))[0]
            errors.append({
                "rule": rule_name,
                "target": sample_name,
                "log_file": filepath,
                "error_snippets": error_lines[-5:],
            })
    return errors


def main():
    if len(sys.argv) < 2:
        print("Usage: python aggregate_logs.py <status: success/error> [output_json]")
        sys.exit(1)

    status = sys.argv[1]
    
    if len(sys.argv) > 2:
        output_json = sys.argv[2]
    else:
        output_json = "results/reporting/pipeline_execution_summary.json"

    benchmarks = parse_benchmarks("benchmarks")
    total_cpu = sum(m["cpu_time_seconds"] for m in benchmarks)
    peak_mem = max((m["peak_memory_mb"] for m in benchmarks), default=0)

    summary = {
        "pipeline": "BDB-Genomics/cutandrun-pipeline",
        "timestamp": datetime.now().isoformat(),
        "status": status,
        "total_cpu_seconds": round(total_cpu, 2),
        "peak_memory_mb": round(peak_mem, 2),
        "rules_profiled": len(benchmarks),
        "performance_metrics": benchmarks,
        "errors": extract_errors("logs") if status == "error" else [],
    }

    os.makedirs(os.path.dirname(output_json) or ".", exist_ok=True)
    with open(output_json, "w") as f:
        json.dump(summary, f, indent=4)

    print(f"Aggregated pipeline execution summary written to {output_json}")


if __name__ == "__main__":
    main()
