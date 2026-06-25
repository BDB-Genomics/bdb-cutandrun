#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any


# Note: Colors class is duplicated from validate_config.py for script portability
# to run in self-contained workflow environments without virtual environment path pollution.
class Colors:
    HEADER = "\033[95m"
    OKBLUE = "\033[94m"
    OKGREEN = "\033[92m"
    WARNING = "\033[93m"
    FAIL = "\033[91m"
    ENDC = "\033[0m"
    BOLD = "\033[1m"


def parse_frip(frip_path: Path) -> float | None:
    """Parses FRiP value from file (handles headers, single columns, or TSVs)."""
    try:
        with open(frip_path, "r") as f:
            lines: list[str] = []
            for line in f:
                stripped = line.strip()
                if stripped:
                    lines.append(stripped)
                    if len(lines) == 2:
                        break
            if not lines:
                return None

            # Use second line if first has headers, otherwise first line
            target_line = (
                lines[1]
                if len(lines) > 1 and "sample" in lines[0].lower()
                else lines[0]
            )
            parts = target_line.split("\t")

            if len(parts) == 1:
                return float(parts[0])
            else:
                return float(parts[1])
    except FileNotFoundError:
        print(
            f"{Colors.FAIL}FRiP file not found: {frip_path}{Colors.ENDC}",
            file=sys.stderr,
        )
    except (ValueError, IndexError) as e:
        print(
            f"{Colors.FAIL}Error parsing FRiP format in {frip_path}: {e}{Colors.ENDC}",
            file=sys.stderr,
        )
    except Exception as e:
        print(
            f"{Colors.FAIL}Unexpected error parsing FRiP: {e}{Colors.ENDC}",
            file=sys.stderr,
        )
    return None


def parse_number(val: str) -> float | int | None:
    """Parses value from scientific notation or standard formatting robustly."""
    val = val.strip().replace("%", "")
    try:
        return int(val)
    except ValueError:
        try:
            return float(val)
        except ValueError:
            return None


def parse_samtools_stats(stats_path: Path) -> dict[str, Any]:
    """Parses samtools stats using a robust, colon-agnostic mapping approach."""
    metrics: dict[str, Any] = {
        "total_reads": None,
        "mapped_properly": None,
        "mapped_properly_count": None,
        "duplicates": None,
    }
    # Keys do not have trailing colons to be fully robust to all samtools versions
    mapping = {
        "sequences": "total_reads",
        "properly paired": "mapped_properly_count",
        "percentage of properly paired reads": "mapped_properly",
        "reads duplicated": "duplicates",
    }
    try:
        with open(stats_path, "r") as f:
            for line in f:
                if not line.startswith("SN"):
                    continue
                for key, target in mapping.items():
                    if key in line:
                        parts = line.split("\t")
                        if len(parts) >= 3:
                            metrics[target] = parse_number(parts[2])
    except FileNotFoundError:
        print(
            f"{Colors.FAIL}Samtools stats file not found: {stats_path}{Colors.ENDC}",
            file=sys.stderr,
        )
    except Exception as e:
        print(
            f"{Colors.FAIL}Error parsing samtools stats: {e}{Colors.ENDC}",
            file=sys.stderr,
        )
    return metrics


def main() -> None:
    parser = argparse.ArgumentParser(description="CUT&RUN QC Gating System")
    parser.add_argument("--sample", required=True)
    parser.add_argument("--frip-file", required=True)
    parser.add_argument("--stats-file", required=True)
    parser.add_argument("--min-frip", type=float, required=True)
    parser.add_argument("--min-mapping-rate", type=float, required=True)
    parser.add_argument("--max-duplicate-rate", type=float, required=True)
    parser.add_argument("--log", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--json-output", required=True)

    args = parser.parse_args()

    # 1. Parse Data
    frip = parse_frip(Path(args.frip_file))
    stats = parse_samtools_stats(Path(args.stats_file))

    # Check for parsing failures and handle them gracefully by flagging as failed rather than halting the pipeline
    parse_failed = False
    if frip is None:
        frip = 0.0
        parse_failed = True

    for k in ("total_reads", "mapped_properly", "duplicates"):
        if stats.get(k) is None:
            stats[k] = 0
            parse_failed = True

    # 2. Calculate Derived Metrics safely, checking for None values and avoiding Division-by-Zero
    dup_rate = 0.0
    if (
        stats["total_reads"] is not None
        and stats["duplicates"] is not None
        and stats["total_reads"] > 0
    ):
        dup_rate = (stats["duplicates"] * 100.0) / stats["total_reads"]

    # mapping_rate is the percentage of properly paired reads (value from samtools stats matches the config's min_mapping_rate % units)
    mapping_rate = (
        stats["mapped_properly"] if stats["mapped_properly"] is not None else 0.0
    )

    # 3. Validation and Tiering
    qc_data: dict[str, Any] = {
        "sample": args.sample,
        "metrics": {
            "frip": {"val": frip, "target": args.min_frip, "status": "PASS"},
            "mapping": {
                "val": mapping_rate,
                "target": args.min_mapping_rate,
                "status": "PASS",
            },
            "duplicates": {
                "val": dup_rate,
                "target": args.max_duplicate_rate,
                "status": "PASS",
            },
        },
        "overall": "PASSED",
    }

    def check(metric: str, val: float, target: float, operator: str = ">=") -> str:
        # 10% warning buffer is an advisory threshold that flags samples nearing failure
        warn_threshold = target * 1.1 if operator == "<=" else target * 0.9
        if (operator == ">=" and val < target) or (operator == "<=" and val > target):
            qc_data["metrics"][metric]["status"] = "FAIL"
            qc_data["overall"] = "FAILED"
            return f"{Colors.FAIL}[FAIL] {metric.upper()}: {val:.3f} (Target {operator} {target}){Colors.ENDC}"
        elif (operator == ">=" and val < warn_threshold) or (
            operator == "<=" and val > warn_threshold
        ):
            qc_data["metrics"][metric]["status"] = "WARN"
            return f"{Colors.WARNING}[WARN] {metric.upper()}: {val:.3f} (Borderline){Colors.ENDC}"
        return f"{Colors.OKGREEN}[PASS] {metric.upper()}: {val:.3f}{Colors.ENDC}"

    # Generate Report Lines
    report = [
        f"{Colors.BOLD}QC Report for {args.sample}{Colors.ENDC}",
        "-------------------------------",
    ]
    report.append(check("frip", frip, args.min_frip))
    report.append(check("mapping", mapping_rate, args.min_mapping_rate))
    report.append(check("duplicates", dup_rate, args.max_duplicate_rate, "<="))
    report.append("-------------------------------")

    if parse_failed:
        qc_data["overall"] = "FAILED"

    result_color = Colors.OKGREEN if qc_data["overall"] == "PASSED" else Colors.FAIL
    report.append(f"OVERALL RESULT: {result_color}{qc_data['overall']}{Colors.ENDC}")

    # Ensure target output and log directories exist
    Path(args.output).parent.mkdir(parents=True, exist_ok=True)
    Path(args.log).parent.mkdir(parents=True, exist_ok=True)

    # 4. Output Files
    # Text Log
    with open(args.log, "w") as f:
        # Strip ANSI codes for file output robustly using regex
        ansi_escape = re.compile(r"\x1b\[[0-9;]*m")
        clean_report = [ansi_escape.sub("", line) for line in report]
        f.write("\n".join(clean_report) + "\n")

    # JSON Data for MultiQC/Dashboard
    with open(args.json_output, "w") as f:
        json.dump(qc_data, f, indent=4)

    # Snakemake Trigger Output
    with open(args.output, "w") as f:
        f.write(f"{args.sample}\t{qc_data['overall']}\n")

    # Console Output
    print("\n".join(report))

    if qc_data["overall"] == "FAILED":
        sys.exit(0)


if __name__ == "__main__":
    main()
