#!/usr/bin/env python3
"""
Run the CUT&RUN pipeline in sequential sample batches for very low-resource machines.

Usage:
    python3 rules/scripts/run_batched.py --batch-size 1 --cores 2 --memory 4000
    python3 rules/scripts/run_batched.py --batch-size 2 --cores 4 --memory 8000

This script:
    1. Reads the sample sheet and config.yaml
    2. Splits samples into batches
    3. Runs snakemake for each batch sequentially using dynamic target files
    4. Each batch shares the same results/ directory (Snakemake resumes automatically)
    5. Final MultiQC aggregates all results

Ideal for machines with ≤4GB RAM where even --jobs 2 causes OOM.
"""

import argparse
import csv
import re
import subprocess
import sys
from pathlib import Path
from typing import Any
import yaml  # type: ignore[import-untyped]

SAMPLE_NAME_PATTERN = re.compile(r"^(?!.*\.\.)[A-Za-z0-9._-]+$")


def get_samples(sample_sheet: Path) -> list[str]:
    """Read sample names from the TSV sample sheet."""
    with sample_sheet.open(newline="") as f:
        reader = csv.DictReader(f, delimiter="\t")
        samples = []
        for row in reader:
            s = row.get("sample", "").strip()
            if not s:
                continue
            if not SAMPLE_NAME_PATTERN.match(s):
                print(f"ERROR: Invalid sample name '{s}' in sample sheet. Only alphanumeric characters, dashes, and underscores are allowed.", file=sys.stderr)
                sys.exit(1)
            samples.append(s)
        return samples


def get_config_path(config: dict[str, Any], path_keys: tuple[str, ...]) -> str:
    """Safely get a nested configuration value using get() or exit with an error message."""
    curr: Any = config
    for k in path_keys:
        if isinstance(curr, dict):
            curr = curr.get(k)
            if curr is None:
                print(f"ERROR: Missing required config key: {'.'.join(path_keys)}", file=sys.stderr)
                sys.exit(1)
        else:
            print(f"ERROR: Missing required config key: {'.'.join(path_keys)}", file=sys.stderr)
            sys.exit(1)
    
    val_str = str(curr)
    if re.match(r"^(True|False|None)$", val_str, re.IGNORECASE):
        print(f"ERROR: Config path key '{'.'.join(path_keys)}' has invalid value: '{val_str}' (cannot be a boolean or None).", file=sys.stderr)
        sys.exit(1)
    return val_str


def run_batch(
    samples: list[str],
    batch_id: int,
    cores: int,
    memory: int,
    config: dict[str, Any],
    conda_frontend: str,
    extra_args: list[str],
) -> int:
    """Run snakemake for a single batch of samples."""
    target_files = []
    for s in samples:
        target_files.extend([
            f"{get_config_path(config, ('fastp', 'output', 'dir'))}/{s}_R1_trimmed.fastq.gz",
            f"{get_config_path(config, ('bowtie2', 'output'))}/{s}.bam",
            f"{get_config_path(config, ('samtools_sort', 'output', 'sorted_bam'))}/{s}.sorted.bam",
            f"{get_config_path(config, ('samtools_markdup', 'output', 'markdup_bam'))}/{s}_noMT.sorted.dedup.bam",
            f"{get_config_path(config, ('bam_to_fragments', 'output', 'fragments'))}/{s}_fragments.bed",
            f"{get_config_path(config, ('seacr', 'output', 'peaks'))}/{s}.peaks.stringent.bed",
            f"{get_config_path(config, ('blacklist_region_filter', 'output', 'filtered_peaks'))}/{s}_filtered_peaks.bed",
            f"{get_config_path(config, ('bigwig', 'output', 'bigwig'))}/{s}.bw",
        ])

    cmd = [
        "snakemake",
        "--use-conda",
        "--conda-frontend", conda_frontend,
        "--cores", str(cores),
        "--resources", f"mem_mb={memory}",
        "--profile", "profile/low_resource",
        "--rerun-incomplete",
        "--keep-going",
        *target_files,
        *extra_args,
    ]

    print(f"\n{'='*60}")
    print(f"BATCH {batch_id}: {', '.join(samples)}")
    print(f"{'='*60}")
    print(f"Command: {' '.join(cmd)}\n")

    result = subprocess.run(cmd)
    return result.returncode


def main() -> None:
    parser = argparse.ArgumentParser(description="Run CUT&RUN pipeline in sample batches")
    parser.add_argument("--batch-size", type=int, default=1, help="Samples per batch (default: 1)")
    parser.add_argument("--cores", type=int, default=2, help="CPU cores per batch (default: 2)")
    parser.add_argument("--memory", type=int, default=4000, help="Memory limit in MB (default: 4000)")
    parser.add_argument("--config", type=str, default="config.yaml", help="Path to config.yaml")
    parser.add_argument("--sample-sheet", type=str, default="data/samples.tsv", help="Path to sample sheet")
    parser.add_argument("--conda-frontend", type=str, default="mamba", choices=["conda", "mamba"],
                        help="Conda frontend: conda or mamba (default: mamba)")
    parser.add_argument("--dry-run", action="store_true", help="Show batches without running")
    parser.add_argument("extra_args", nargs=argparse.REMAINDER, help="Extra arguments passed to snakemake")
    args = parser.parse_args()

    root = Path(__file__).resolve().parents[2]
    config_path = root / args.config
    sample_sheet = root / args.sample_sheet

    if not config_path.exists():
        print(f"ERROR: Config file not found: {config_path}", file=sys.stderr)
        sys.exit(1)

    # Load default config first to ensure all default parameters are present
    default_config_path = root / "config.yaml"
    config: dict[str, Any]
    if default_config_path.exists():
        with default_config_path.open() as f:
            config = yaml.safe_load(f) or {}
    else:
        config = {}

    # Merge with custom config overrides if specified
    if config_path != default_config_path and config_path.exists():
        with config_path.open() as f:
            custom_config = yaml.safe_load(f) or {}
        def merge_dicts(d1: dict[str, Any], d2: dict[str, Any]) -> None:
            for k, v in d2.items():
                if k in d1 and isinstance(d1[k], dict) and isinstance(v, dict):
                    merge_dicts(d1[k], v)
                else:
                    d1[k] = v
        merge_dicts(config, custom_config)

    # Check if sample sheet exists
    # If the configured sample sheet path in config differs, try using that
    config_sample_sheet = config.get("global", {}).get("samples")
    if config_sample_sheet:
        config_sample_sheet_path = root / config_sample_sheet
        if config_sample_sheet_path.exists():
            sample_sheet = config_sample_sheet_path

    if not sample_sheet.exists():
        print(f"ERROR: Sample sheet not found: {sample_sheet}", file=sys.stderr)
        sys.exit(1)

    samples = get_samples(sample_sheet)
    if not samples:
        print("ERROR: No samples found in sample sheet", file=sys.stderr)
        sys.exit(1)

    # Split into batches
    batches = [samples[i:i + args.batch_size] for i in range(0, len(samples), args.batch_size)]

    print(f"Total samples: {len(samples)}")
    print(f"Batch size: {args.batch_size}")
    print(f"Total batches: {len(batches)}")
    print(f"Cores per batch: {args.cores}")
    print(f"Memory limit: {args.memory} MB")

    if args.dry_run:
        print("\nBatches (dry-run):")
        for i, batch in enumerate(batches, 1):
            print(f"  Batch {i}: {', '.join(batch)}")
        return

    # Run batches sequentially
    failed_batches = []
    for i, batch in enumerate(batches, 1):
        ret = run_batch(batch, i, args.cores, args.memory, config, args.conda_frontend, args.extra_args)
        if ret != 0:
            failed_batches.append((i, batch))
            print(f"WARNING: Batch {i} had errors (exit code {ret})")

    # Summary
    print(f"\n{'='*60}")
    print("BATCH SUMMARY")
    print(f"{'='*60}")
    print(f"Total batches: {len(batches)}")
    print(f"Successful: {len(batches) - len(failed_batches)}")
    print(f"Failed: {len(failed_batches)}")

    if failed_batches:
        for batch_id, batch_samples in failed_batches:
            print(f"  Batch {batch_id} FAILED: {', '.join(batch_samples)}")
        sys.exit(1)

    # Run final aggregation steps (MultiQC & Differential Binding)
    print("\nRunning final aggregation...")
    multiqc_report_dir = config.get("multiqc", {}).get("output", {}).get("report", "results/multiqc")
    final_targets = [
        f"{multiqc_report_dir}/multiqc_report.html",
        "results/differential_binding/differential_binding_results.tsv"
    ]
    final_cmd = [
        "snakemake",
        "--use-conda",
        "--conda-frontend", args.conda_frontend,
        "--cores", "1",
        "--profile", "profile/low_resource",
        *final_targets,
        *args.extra_args,
    ]
    print(f"Command: {' '.join(final_cmd)}\n")
    subprocess.run(final_cmd)

    print("Pipeline complete.")


if __name__ == "__main__":
    main()
