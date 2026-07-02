#!/usr/bin/env python3
"""Validate the CUT&RUN config and sample sheet before Snakemake builds the DAG."""

from __future__ import annotations

import csv
import re
import sys
from pathlib import Path
from typing import Any

import yaml  # type: ignore[import-untyped]


SAMPLE_COLUMNS = ("sample", "fastq_r1", "fastq_r2", "replicate", "condition")
SAMPLE_NAME_PATTERN = re.compile(r"^[A-Za-z0-9._-]+$")
CONFIG_ACCESS_PATTERN = re.compile(r"config((?:\[['\"][^'\"]+['\"]\])+)")
CONFIG_KEY_PATTERN = re.compile(r"\[['\"]([^'\"]+)['\"]\]")
SAMPLES_LIST_USAGE_PATTERN = re.compile(r"sample\s*=\s*config\[['\"]samples['\"]\]")


# ANSI Color codes
class Colors:
    HEADER = '\033[95m'
    BLUE = '\033[94m'
    CYAN = '\033[96m'
    GREEN = '\033[92m'
    YELLOW = '\033[93m'
    RED = '\033[91m'
    ENDC = '\033[0m'
    BOLD = '\033[1m'


def fail(errors: list[str]) -> None:
    print(f"\n{Colors.BOLD}{Colors.RED}┏━ CONFIGURATION VALIDATION FAILED ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓{Colors.ENDC}")
    
    # Categorize errors
    categories: dict[str, list[str]] = {
        "Reference Files": [],
        "Sample Sheet": [],
        "Schema/Keys": [],
        "Parameters": []
    }
    
    for msg in errors:
        if any(x in msg for x in ["path not found", "index prefix", "not a file", "Index prefix"]):
            categories["Reference Files"].append(msg)
        elif "Sample sheet" in msg or "sample ID" in msg or "FASTQ" in msg or "Sample '" in msg:
            categories["Sample Sheet"].append(msg)
        elif "Missing config key" in msg:
            categories["Schema/Keys"].append(msg)
        else:
            categories["Parameters"].append(msg)

    for cat, msgs in categories.items():
        if msgs:
            print(f"\n  {Colors.BOLD}{Colors.YELLOW}[{cat}]{Colors.ENDC}")
            for m in msgs:
                print(f"    • {m}")
                # Add specific hints
                if "data/" in m:
                    parts = m.split(':')
                    path_part = parts[-1].strip() if len(parts) > 1 else m
                    print(f"      {Colors.CYAN}Hint: Check if the file exists at: {Path(path_part).absolute()}{Colors.ENDC}")

    print(f"\n{Colors.BOLD}{Colors.RED}┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛{Colors.ENDC}")
    print(f"\n{Colors.YELLOW}Check your 'config.yaml' and ensure all required data is in the 'data/' directory.{Colors.ENDC}\n")
    sys.exit(1)


def workflow_root() -> Path:
    return Path(__file__).resolve().parents[2]


def resolve_cli_path(raw_path: str | Path, root: Path) -> Path:
    path = Path(raw_path).expanduser()
    if path.is_absolute():
        resolved = path.resolve()
        if not resolved.is_relative_to(root):
            fail([f"Security Error: Config path '{resolved}' is outside the project workspace '{root}'."])
        return resolved
    cwd_candidate = (Path.cwd() / path).resolve()
    if cwd_candidate.exists() and cwd_candidate.is_relative_to(root):
        return cwd_candidate
    root_candidate = (root / path).resolve()
    if not root_candidate.is_relative_to(root):
        fail([f"Security Error: Config path '{root_candidate}' is outside the project workspace '{root}'."])
    return root_candidate


def load_config(config_path: Path, errors: list[str]) -> dict[str, Any]:
    if not config_path.exists():
        errors.append(f"Config file not found: {config_path}")
        return {}
    try:
        with config_path.open("r", encoding="utf-8") as handle:
            data = yaml.safe_load(handle) or {}
    except yaml.YAMLError as exc:
        errors.append(f"Could not parse YAML config '{config_path}': {exc}")
        return {}

    if not isinstance(data, dict):
        errors.append("Config root must be a mapping/object.")
        return {}
    return data


def candidate_paths(raw_value: str, bases: list[Path], root: Path) -> list[Path]:
    raw_path = Path(raw_value).expanduser()
    candidates: list[Path] = []
    
    if raw_path.is_absolute():
        resolved = raw_path.resolve()
        if resolved.is_relative_to(root):
            candidates.append(resolved)
        return candidates

    seen: set[Path] = set()
    for base in bases:
        candidate = (base / raw_path).resolve()
        if candidate not in seen:
            if candidate.is_relative_to(root):
                candidates.append(candidate)
            seen.add(candidate)
    return candidates


def resolve_existing_path(raw_value: str, bases: list[Path], root: Path) -> Path | None:
    for candidate in candidate_paths(raw_value, bases, root):
        if candidate.exists():
            return candidate
    return None


def get_config_value(config: dict[str, Any], keys: tuple[str, ...]) -> Any:
    current: Any = config
    for key in keys:
        if not isinstance(current, dict) or key not in current:
            return None
        current = current[key]
    return current


def has_config_value(config: dict[str, Any], keys: tuple[str, ...]) -> bool:
    current: Any = config
    for key in keys:
        if not isinstance(current, dict) or key not in current:
            return False
        current = current[key]
    return True


def collect_required_config_paths(root: Path, errors: list[str]) -> list[tuple[str, ...]]:
    paths: set[tuple[str, ...]] = set()
    workflow_files = [root / "Snakefile", *sorted((root / "rules").glob("*.smk"))]

    for workflow_file in workflow_files:
        if not workflow_file.exists():
            errors.append(f"Workflow file not found while discovering config paths: {workflow_file}")
            continue

        with workflow_file.open("r", encoding="utf-8") as handle:
            for line in handle:
                for raw_keys in CONFIG_ACCESS_PATTERN.findall(line):
                    keys = tuple(CONFIG_KEY_PATTERN.findall(raw_keys))
                    if keys:
                        paths.add(keys)

    return sorted(paths, key=lambda item: (len(item), item))


def validate_required_config_paths(
    config: dict[str, Any], required_paths: list[tuple[str, ...]], errors: list[str]
) -> None:
    missing_prefixes: set[tuple[str, ...]] = set()

    for path_keys in required_paths:
        if any(path_keys[:prefix_len] in missing_prefixes for prefix_len in range(1, len(path_keys))):
            continue
        if not has_config_value(config, path_keys):
            missing_prefixes.add(path_keys)
            errors.append(f"Missing config key: {'.'.join(path_keys)}")


def validate_scalar_config_values(config: dict[str, Any], errors: list[str]) -> None:
    positive_int_suffixes = (
        "threads",
        "mem_mb",
        "trim_front1",
        "trim_front2",
        "length_required",
        "MAPQ",
        "flags",
        "min_length",
        "max_length",
        "max_fragment",
        "upstream",
        "downstream",
        "bin_size",
        "scale_constant",
    )
    positive_float_suffixes = (
        "M",
        "background",
        "min_tss",
    )
    non_empty_string_suffixes = (
        "time",
        "mito_chr",
        "feature_types",
        "norm",
        "stringency",
        "colormap",
        "validation_stringency",
        "remove_duplicates",
    )

    for suffix in positive_int_suffixes:
        for path_keys in iter_matching_paths(config, suffix):
            value = get_config_value(config, path_keys)
            if not isinstance(value, int) or value <= 0:
                errors.append(f"Config value '{'.'.join(path_keys)}' must be a positive integer.")

    for suffix in positive_float_suffixes:
        for path_keys in iter_matching_paths(config, suffix):
            value = get_config_value(config, path_keys)
            if not isinstance(value, (int, float)) or value < 0:
                errors.append(f"Config value '{'.'.join(path_keys)}' must be a non-negative number.")

    for suffix in non_empty_string_suffixes:
        for path_keys in iter_matching_paths(config, suffix):
            value = get_config_value(config, path_keys)
            if suffix == "time" and isinstance(value, (int, float)) and value > 0:
                continue
            if not isinstance(value, str) or not value.strip():
                errors.append(f"Config value '{'.'.join(path_keys)}' must be a non-empty string or a positive number.")


def iter_matching_paths(config: dict[str, Any], leaf_key: str) -> list[tuple[str, ...]]:
    matches: list[tuple[str, ...]] = []

    def walk(prefix: tuple[str, ...], node: Any) -> None:
        if not isinstance(node, dict):
            return
        for key, value in node.items():
            next_prefix = prefix + (key,)
            if key == leaf_key:
                matches.append(next_prefix)
            walk(next_prefix, value)

    walk((), config)
    return matches


def validate_samples_sheet(
    config: dict[str, Any], config_path: Path, root: Path, errors: list[str]
) -> list[dict[str, Any]]:
    samples_value = get_config_value(config, ("global", "samples"))
    if samples_value is None:
        return []
    if not isinstance(samples_value, str) or not samples_value.strip():
        errors.append("Config key 'global.samples' must be a non-empty path string to a TSV sample sheet.")
        return []

    bases = [config_path.parent, root, Path.cwd()]
    samples_path = resolve_existing_path(samples_value, bases, root)
    if samples_path is None:
        rendered = ", ".join(str(path) for path in candidate_paths(samples_value, bases, root))
        errors.append(
            "Sample sheet not found for config key 'global.samples'. Checked: " + rendered
        )
        return []
    if not samples_path.is_file():
        errors.append(f"Sample sheet is not a file: {samples_path}")
        return []

    records: list[dict[str, Any]] = []
    with samples_path.open("r", encoding="utf-8", newline="") as handle:
        reader = csv.DictReader(handle, delimiter="\t")
        if reader.fieldnames is None:
            errors.append("Sample sheet is empty or missing a header row.")
            return []

        reader.fieldnames = [name.strip() if name else "" for name in reader.fieldnames]
        missing_columns = [column for column in SAMPLE_COLUMNS if column not in reader.fieldnames]
        if missing_columns:
            errors.append(
                "Sample sheet is missing required columns: " + ", ".join(missing_columns)
            )
            return []

        seen_samples: set[str] = set()
        seen_condition_replicates: set[tuple[str, int]] = set()

        for row_number, raw_row in enumerate(reader, start=2):
            row = {key: (value or "").strip() for key, value in raw_row.items() if key}
            sample = row["sample"]
            condition = row["condition"]
            replicate_text = row["replicate"]
            r1 = row["fastq_r1"]
            r2 = row["fastq_r2"]

            if not sample:
                errors.append(f"Empty sample ID at row {row_number}.")
                continue
            if not SAMPLE_NAME_PATTERN.match(sample):
                errors.append(
                    f"Sample '{sample}' at row {row_number} contains unsupported characters."
                )
            if sample in seen_samples:
                errors.append(f"Duplicate sample ID '{sample}' at row {row_number}.")
            seen_samples.add(sample)

            if not condition:
                errors.append(f"Missing condition for sample '{sample}' at row {row_number}.")

            replicate = None
            try:
                replicate = int(replicate_text)
                if replicate <= 0:
                    raise ValueError
            except ValueError:
                errors.append(
                    f"Replicate for sample '{sample}' at row {row_number} must be a positive integer."
                )

            if replicate is not None and condition:
                pair = (condition, replicate)
                if pair in seen_condition_replicates:
                    errors.append(
                        "Duplicate condition/replicate pair "
                        f"'{condition}' replicate {replicate} at row {row_number}."
                    )
                seen_condition_replicates.add(pair)

            if not r1 or not r2:
                errors.append(f"Missing FASTQ path(s) for sample '{sample}' at row {row_number}.")
                continue
            if r1 == r2:
                errors.append(f"FASTQ R1 and R2 are identical for sample '{sample}' at row {row_number}.")

            fastq_bases = [samples_path.parent, config_path.parent, root, Path.cwd()]
            resolved_r1 = resolve_existing_path(r1, fastq_bases, root)
            resolved_r2 = resolve_existing_path(r2, fastq_bases, root)

            if resolved_r1 is None:
                errors.append(
                    f"FASTQ R1 not found for sample '{sample}' at row {row_number}: {r1}"
                )
            if resolved_r2 is None:
                errors.append(
                    f"FASTQ R2 not found for sample '{sample}' at row {row_number}: {r2}"
                )

            records.append(
                {
                    "sample": sample,
                    "condition": condition,
                    "replicate": replicate,
                    "fastq_r1": resolved_r1,
                    "fastq_r2": resolved_r2,
                }
            )

        if not records:
            errors.append(f"Sample sheet has no sample rows: {samples_path}")

    return records


def validate_fastp_input_mapping(
    config: dict[str, Any],
    sample_records: list[dict[str, Any]],
    config_path: Path,
    root: Path,
    errors: list[str],
) -> None:
    fastp_input = get_config_value(config, ("fastp", "input"))
    if fastp_input is None:
        return
    if not isinstance(fastp_input, dict):
        errors.append("Config key 'fastp.input' must be a mapping if provided.")
        return

    bases = [config_path.parent, root, Path.cwd()]
    input_records: dict[str, tuple[Path | None, Path | None]] = {}

    for sample_name, pair in fastp_input.items():
        if not isinstance(pair, dict):
            errors.append(f"Config key 'fastp.input.{sample_name}' must be a mapping with R1/R2.")
            continue
        r1 = pair.get("R1")
        r2 = pair.get("R2")
        if not isinstance(r1, str) or not r1.strip():
            errors.append(f"Config key 'fastp.input.{sample_name}.R1' must be a non-empty string.")
        if not isinstance(r2, str) or not r2.strip():
            errors.append(f"Config key 'fastp.input.{sample_name}.R2' must be a non-empty string.")
        resolved_r1 = resolve_existing_path(r1, bases, root) if isinstance(r1, str) and r1.strip() else None
        resolved_r2 = resolve_existing_path(r2, bases, root) if isinstance(r2, str) and r2.strip() else None
        if isinstance(r1, str) and r1.strip() and resolved_r1 is None:
            errors.append(f"Configured FASTQ file not found: fastp.input.{sample_name}.R1 -> {r1}")
        if isinstance(r2, str) and r2.strip() and resolved_r2 is None:
            errors.append(f"Configured FASTQ file not found: fastp.input.{sample_name}.R2 -> {r2}")
        input_records[sample_name] = (resolved_r1, resolved_r2)

    if not sample_records:
        return

    sample_sheet_names = {record["sample"] for record in sample_records}
    fastp_input_names = set(input_records)
    if sample_sheet_names != fastp_input_names:
        only_sheet = sorted(sample_sheet_names - fastp_input_names)
        only_fastp = sorted(fastp_input_names - sample_sheet_names)
        details: list[str] = []
        if only_sheet:
            details.append("only in sample sheet: " + ", ".join(only_sheet))
        if only_fastp:
            details.append("only in fastp.input: " + ", ".join(only_fastp))
        errors.append("Sample IDs differ between top-level sample sheet and fastp.input (" + "; ".join(details) + ").")

    for record in sample_records:
        sample = record["sample"]
        if sample not in input_records:
            continue
        expected_r1, expected_r2 = input_records[sample]
        if record["fastq_r1"] and expected_r1 and record["fastq_r1"] != expected_r1:
            errors.append(
                f"Sample '{sample}' FASTQ R1 differs between sample sheet and fastp.input."
            )
        if record["fastq_r2"] and expected_r2 and record["fastq_r2"] != expected_r2:
            errors.append(
                f"Sample '{sample}' FASTQ R2 differs between sample sheet and fastp.input."
            )


def validate_path_checks(
    config: dict[str, Any], config_path: Path, root: Path, errors: list[str]
) -> None:
    bases = [config_path.parent, root, Path.cwd()]
    
    def walk(prefix: tuple[str, ...], node: Any) -> None:
        if not isinstance(node, dict):
            return
        for key, value in node.items():
            next_prefix = prefix + (key,)
            if isinstance(value, dict):
                walk(next_prefix, value)
            elif isinstance(value, str) and value.strip():
                # Dynamically validate static reference file paths (under global)
                # or pipeline tool resources (script/config)
                is_global_ref = (next_prefix[0] == "global" and (
                    key.endswith(("_fa", "_bed", "_gtf", "_index", "_sizes", "_db")) or
                    key == "blacklist"
                ))
                is_tool_resource = (key in ("script", "config"))

                if is_global_ref or is_tool_resource:
                    if key in ("bowtie_index", "ecoli_index", "bowtie2_index"):
                        if not bowtie_index_exists(value, bases, root):
                            errors.append(f"Index prefix not found for config key '{'.'.join(next_prefix)}': {value}")
                    else:
                        resolved = resolve_existing_path(value, bases, root)
                        if resolved is None:
                            errors.append(f"Configured path not found for '{'.'.join(next_prefix)}': {value}")
                        elif not resolved.is_file():
                            errors.append(f"Configured path for '{'.'.join(next_prefix)}' must be a file: {resolved}")

    walk((), config)


def bowtie_index_exists(index_prefix: str, bases: list[Path], root: Path) -> bool:
    for prefix in candidate_paths(index_prefix, bases, root):
        if prefix.exists():
            return True
        if prefix.parent.exists():
            matches = list(prefix.parent.glob(prefix.name + "*.bt2"))
            matches.extend(prefix.parent.glob(prefix.name + "*.bt2l"))
            if matches:
                return True
    return False


def validate_samples_usage(root: Path, config: dict[str, Any], errors: list[str]) -> None:
    samples_value = get_config_value(config, ("global", "samples"))
    if isinstance(samples_value, list):
        return

    offenders: list[str] = []
    for workflow_file in sorted((root / "rules").glob("*.smk")):
        text = workflow_file.read_text(encoding="utf-8")
        if SAMPLES_LIST_USAGE_PATTERN.search(text):
            offenders.append(str(workflow_file.relative_to(root)))

    if offenders and isinstance(samples_value, str):
        errors.append(
            "Top-level config key 'global.samples' is a sample-sheet path string, but these rules use it "
            "as a list of sample names: " + ", ".join(offenders)
        )


def validate_conda_environments(root: Path, errors: list[str]) -> None:
    conda_pattern = re.compile(r"conda:\s*['\"]([^'\"]+)['\"]")
    workflow_files = sorted((root / "rules").glob("*.smk"))

    for workflow_file in workflow_files:
        if not workflow_file.exists():
            continue
        with workflow_file.open("r", encoding="utf-8") as handle:
            for line_no, line in enumerate(handle, start=1):
                match = conda_pattern.search(line)
                if match:
                    conda_path_str = match.group(1)
                    # Snakemake resolves conda: paths relative to the .smk file's
                    # directory, so "envs/foo.yaml" in rules/bar.smk resolves to
                    # rules/envs/foo.yaml — mirror that behaviour here.
                    resolved_path = (workflow_file.parent / conda_path_str).resolve()
                    if not resolved_path.exists():
                        errors.append(
                            f"Conda environment file not found: '{conda_path_str}' "
                            f"(referenced in {workflow_file.relative_to(root)}:{line_no})"
                        )


def main() -> None:
    root = workflow_root()
    config_arg = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("config.yaml")
    config_path = resolve_cli_path(config_arg, root)

    errors: list[str] = []
    config = load_config(config_path, errors)
    required_paths = collect_required_config_paths(root, errors)

    if config:
        validate_required_config_paths(config, required_paths, errors)
        validate_scalar_config_values(config, errors)
        sample_records = validate_samples_sheet(config, config_path, root, errors)
        validate_fastp_input_mapping(config, sample_records, config_path, root, errors)
        validate_path_checks(config, config_path, root, errors)
        validate_samples_usage(root, config, errors)
        validate_conda_environments(root, errors)

    if errors:
        fail(errors)

    samples_value = get_config_value(config, ("global", "samples"))
    if samples_value is None:
        fail(["Missing config key: global.samples"])

    samples_path = resolve_existing_path(str(samples_value), [config_path.parent, root, Path.cwd()], root)
    print(f"[CONFIG VALIDATION] OK: {samples_path}")


if __name__ == "__main__":
    main()
