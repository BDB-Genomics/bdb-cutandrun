#!/usr/bin/env python3
"""Aggregate pipeline logs and benchmarks into a single structured JSON summary.

Adapted from the BDB-Genomics ATAC-seq Framework.
Sweeps logs/ and benchmarks/ directories, filters noise and false positives,
and produces a clean pipeline_execution_summary.json for humans and AI agents.
"""

import csv
import json
import pathlib
import sys
from collections import deque
from datetime import datetime
from typing import Any


def parse_benchmarks(benchmarks_dir: pathlib.Path) -> list[dict[str, Any]]:
    """Parse all Snakemake benchmark TSV files into structured dicts.

    Each benchmark file contains columns like: s, h:m:s, max_rss, max_vms, etc.
    """
    metrics: list[dict[str, Any]] = []
    if not benchmarks_dir.exists():
        return metrics

    for filepath in sorted(benchmarks_dir.rglob("*.txt")):
        rule_name = filepath.parent.name
        sample_name = filepath.stem
        try:
            with open(filepath, "r") as f:
                reader = csv.DictReader(f, delimiter="\t")
                for row in reader:
                    try:
                        metrics.append(
                            {
                                "rule": rule_name,
                                "sample": sample_name,
                                "cpu_time_seconds": float(row.get("s", 0)),
                                "peak_memory_mb": float(row.get("max_rss", 0)),
                            }
                        )
                    except (ValueError, KeyError):
                        continue
        except (IOError, UnicodeDecodeError):
            continue
    return metrics


def is_actual_error(line: str) -> bool:
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
        "0 error",
        "no error",
        "zero error",
        "error rate: 0",
        "errors: 0",
        "no exception",
        "0 exception",
        "exception: none",
        "successful",
        "0 failed",
        "no failed",
        "errors = 0",
        "error_rate",
        "overall error",
        "alignment error rate",
        "mismatch error",
    ]
    if any(fp in line_lower for fp in false_positives):
        return False

    return True


def extract_errors(logs_dir: pathlib.Path) -> list[dict[str, Any]]:
    """Walk the logs/ directory and extract genuine error lines from log files.

    Scans both .log and .err files (CUT&RUN uses both patterns).
    Returns the last 5 real error lines per file to keep the output concise.
    """
    errors: list[dict[str, Any]] = []
    if not logs_dir.exists():
        return errors

    # Search all files in the logs directory
    for filepath in sorted(logs_dir.rglob("*")):
        if not filepath.is_file():
            continue

        error_lines: deque[str] = deque(maxlen=5)
        try:
            with open(filepath, "r") as f:
                for line in f:
                    stripped_line = line.strip()
                    if is_actual_error(stripped_line):
                        error_lines.append(stripped_line)
        except (IOError, UnicodeDecodeError):
            continue

        if error_lines:
            rule_name = filepath.parent.name
            sample_name = filepath.stem
            errors.append(
                {
                    "rule": rule_name,
                    "target": sample_name,
                    "log_file": str(filepath),
                    "error_snippets": list(error_lines),
                }
            )
    return errors


def main() -> None:
    if len(sys.argv) < 2:
        print("Usage: python aggregate_logs.py <status: success/error> [output_json]")
        sys.exit(1)

    status = sys.argv[1]
    root = pathlib.Path(__file__).resolve().parents[2]

    if len(sys.argv) > 2:
        output_json = pathlib.Path(sys.argv[2])
    else:
        output_json = root / "results/reporting/pipeline_execution_summary.json"

    benchmarks_dir = root / "benchmarks"
    logs_dir = root / "logs"

    benchmarks = parse_benchmarks(benchmarks_dir)
    total_cpu = sum(m["cpu_time_seconds"] for m in benchmarks)
    peak_mem = max((m["peak_memory_mb"] for m in benchmarks), default=0.0)

    summary = {
        "pipeline": "BDB-Genomics/cutandrun-pipeline",
        "timestamp": datetime.now().isoformat(),
        "status": status,
        "total_cpu_seconds": round(total_cpu, 2),
        "peak_memory_mb": round(peak_mem, 2),
        "rules_profiled": len(benchmarks),
        "performance_metrics": benchmarks,
        "errors": extract_errors(logs_dir) if status == "error" else [],
    }

    output_json.parent.mkdir(parents=True, exist_ok=True)
    with open(output_json, "w") as f:
        json.dump(summary, f, indent=4)

    print(f"Aggregated pipeline execution summary written to {output_json}")


if __name__ == "__main__":
    main()
