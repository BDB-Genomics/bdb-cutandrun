import sys
from pathlib import Path
from typing import Any

# Ensure validate_config is importable
sys.path.append(str(Path(__file__).parent))
import validate_config


def test_resolve_cli_path(tmp_path: Path) -> None:
    root = tmp_path / "root"
    root.mkdir()
    
    # Test absolute path
    abs_path = (root / "absolute").resolve()
    assert validate_config.resolve_cli_path(str(abs_path), root) == abs_path
    
    # Test relative path
    rel_path = "relative/path"
    expected = (root / rel_path).resolve()
    assert validate_config.resolve_cli_path(rel_path, root) == expected


def test_load_config(tmp_path: Path) -> None:
    # Test file doesn't exist
    errors: list[str] = []
    config = validate_config.load_config(tmp_path / "nonexistent.yaml", errors)
    assert not config
    assert len(errors) == 1
    assert "Config file not found" in errors[0]
    
    # Test invalid YAML
    invalid_file = tmp_path / "invalid.yaml"
    invalid_file.write_text("global:\n  - unmatched_indent: {")
    errors = []
    config = validate_config.load_config(invalid_file, errors)
    assert not config
    assert len(errors) == 1
    assert "Could not parse YAML config" in errors[0]
    
    # Test valid config
    valid_file = tmp_path / "valid.yaml"
    valid_file.write_text("global:\n  samples: data/samples.tsv")
    errors = []
    config = validate_config.load_config(valid_file, errors)
    assert config == {"global": {"samples": "data/samples.tsv"}}
    assert not errors


def test_get_and_has_config_value() -> None:
    config = {
        "global": {
            "samples": "data/samples.tsv",
            "nested": {
                "key": 42
            }
        }
    }
    
    # get_config_value
    assert validate_config.get_config_value(config, ("global", "samples")) == "data/samples.tsv"
    assert validate_config.get_config_value(config, ("global", "nested", "key")) == 42
    assert validate_config.get_config_value(config, ("global", "missing")) is None
    assert validate_config.get_config_value(config, ("missing",)) is None
    
    # has_config_value
    assert validate_config.has_config_value(config, ("global", "samples")) is True
    assert validate_config.has_config_value(config, ("global", "nested", "key")) is True
    assert validate_config.has_config_value(config, ("global", "missing")) is False
    assert validate_config.has_config_value(config, ("missing",)) is False


def test_validate_required_config_paths() -> None:
    config = {
        "global": {
            "samples": "data/samples.tsv"
        }
    }
    
    # All present
    errors: list[str] = []
    validate_config.validate_required_config_paths(config, [("global", "samples")], errors)
    assert not errors
    
    # Missing key
    errors = []
    validate_config.validate_required_config_paths(config, [("global", "samples"), ("global", "non_existent")], errors)
    assert len(errors) == 1
    assert "Missing config key: global.non_existent" in errors[0]


def test_validate_scalar_config_values() -> None:
    # Test valid scalar values
    config: dict[str, Any] = {
        "fastqc": {
            "threads": 4,
        },
        "seacr": {
            "resources": {
                "mem_mb": 4000
            },
            "params": {
                "background": 0.05
            }
        },
        "multiqc": {
            "resources": {
                "time": "02:00:00"
            }
        }
    }
    errors: list[str] = []
    validate_config.validate_scalar_config_values(config, errors)
    assert not errors

    # Test invalid values (negative or incorrect types)
    invalid_config: dict[str, Any] = {
        "fastqc": {
            "threads": -2,  # Should be positive integer
        },
        "seacr": {
            "resources": {
                "mem_mb": "4G"  # Should be integer, not string
            },
            "params": {
                "background": -0.05  # Should be non-negative
            }
        },
        "multiqc": {
            "resources": {
                "time": ""  # Should be non-empty string
            }
        }
    }
    errors = []
    validate_config.validate_scalar_config_values(invalid_config, errors)
    assert len(errors) == 4


def test_validate_samples_sheet(tmp_path: Path) -> None:
    config = {
        "global": {
            "samples": "samples.tsv"
        }
    }
    
    # 1. Test missing sheet
    errors: list[str] = []
    validate_config.validate_samples_sheet(config, tmp_path / "config.yaml", tmp_path, errors)
    assert len(errors) == 1
    assert "Sample sheet not found" in errors[0]
    
    # 2. Test valid sheet (using mock FASTQ files)
    fastq_dir = tmp_path / "fastq"
    fastq_dir.mkdir()
    r1 = fastq_dir / "sample1_R1.fastq.gz"
    r2 = fastq_dir / "sample1_R2.fastq.gz"
    r1.touch()
    r2.touch()
    
    tsv_content = (
        "sample\tfastq_r1\tfastq_r2\treplicate\tcondition\n"
        f"sample1\t{r1}\t{r2}\t1\ttreatment\n"
    )
    sheet_path = tmp_path / "samples.tsv"
    sheet_path.write_text(tsv_content)
    
    errors = []
    records = validate_config.validate_samples_sheet(config, tmp_path / "config.yaml", tmp_path, errors)
    assert not errors
    assert len(records) == 1
    assert records[0]["sample"] == "sample1"
    
    # 3. Test duplicate samples/conditions
    tsv_dup = (
        "sample\tfastq_r1\tfastq_r2\treplicate\tcondition\n"
        f"sample1\t{r1}\t{r2}\t1\ttreatment\n"
        f"sample1\t{r1}\t{r2}\t1\ttreatment\n"
    )
    sheet_path.write_text(tsv_dup)
    errors = []
    validate_config.validate_samples_sheet(config, tmp_path / "config.yaml", tmp_path, errors)
    assert any("Duplicate sample ID" in e for e in errors)
    assert any("Duplicate condition/replicate pair" in e for e in errors)


def test_validate_fastp_input_mapping(tmp_path: Path) -> None:
    config = {
        "fastp": {
            "input": {
                "sample1": {
                    "R1": "fastq/sample1_R1.fastq.gz",
                    "R2": "fastq/sample1_R2.fastq.gz"
                }
            }
        }
    }
    
    # Create fastqs
    fastq_dir = tmp_path / "fastq"
    fastq_dir.mkdir(parents=True, exist_ok=True)
    r1 = fastq_dir / "sample1_R1.fastq.gz"
    r2 = fastq_dir / "sample1_R2.fastq.gz"
    r1.touch()
    r2.touch()
    
    sample_records = [
        {
            "sample": "sample1",
            "fastq_r1": r1.resolve(),
            "fastq_r2": r2.resolve(),
        }
    ]
    
    errors: list[str] = []
    validate_config.validate_fastp_input_mapping(config, sample_records, tmp_path / "config.yaml", tmp_path, errors)
    assert not errors


def test_validate_path_checks(tmp_path: Path) -> None:
    config = {
        "global": {
            "genome_fa": "genome.fa",
        }
    }
    
    # File doesn't exist
    errors: list[str] = []
    validate_config.validate_path_checks(config, tmp_path / "config.yaml", tmp_path, errors)
    assert len(errors) == 1
    assert "Configured path not found" in errors[0]
    
    # File exists
    (tmp_path / "genome.fa").touch()
    errors = []
    validate_config.validate_path_checks(config, tmp_path / "config.yaml", tmp_path, errors)
    assert not errors


def test_validate_samples_usage(tmp_path: Path) -> None:
    rules_dir = tmp_path / "rules"
    rules_dir.mkdir()
    
    offending_rule = rules_dir / "offender.smk"
    offending_rule.write_text("sample = config['samples']")
    
    config = {
        "global": {
            "samples": "data/samples.tsv"
        }
    }
    
    errors: list[str] = []
    validate_config.validate_samples_usage(tmp_path, config, errors)
    assert len(errors) == 1
    assert "is a sample-sheet path string, but these rules use it as a list" in errors[0]


def test_validate_conda_environments(tmp_path: Path) -> None:
    rules_dir = tmp_path / "rules"
    rules_dir.mkdir()
    
    rule_file = rules_dir / "align.smk"
    rule_file.write_text("conda: 'envs/test.yaml'")
    
    errors: list[str] = []
    validate_config.validate_conda_environments(tmp_path, errors)
    assert len(errors) == 1
    assert "Conda environment file not found" in errors[0]
    
    env_dir = rules_dir / "envs"
    env_dir.mkdir()
    (env_dir / "test.yaml").touch()
    
    errors = []
    validate_config.validate_conda_environments(tmp_path, errors)
    assert not errors
