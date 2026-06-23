#!/usr/bin/env python3
"""Generate synthetic test data for CUT&RUN CI pipeline validation.

This script produces a minimal synthetic dataset to ensure all CUT&RUN
rules — including spike-in alignment, SEACR peak calling, and heatmap
generation — execute successfully in CI without downloading real data.
"""

import gzip
import os
import pathlib
import random
import subprocess
from collections import defaultdict
from dataclasses import dataclass

# Genome layout
GENOME = {
    "chr1": 500_000,
    "chr2": 250_000,
    "chrM": 16_569,
}

ECOLI_GENOME = {
    "ecoli": 50_000,
}

# Annotation parameters
GENES_CHR1 = 50
GENES_CHR2 = 30
GENE_LENGTH = 3000
GENE_LENGTH = 3000
GENE_START_OFFSET = 10_000

# FASTQ parameters
READS_PER_SAMPLE = 7500
READ_LENGTH = 75
FRAGMENT_MEAN = 200
FRAGMENT_SD = 30
TSS_TARGETED_FRACTION = 0.60
SPIKEIN_FRACTION = 0.15  # 15% reads map to E. coli
TSS_WINDOW = 2000
SAMPLES = {
    "sample1": {"condition": "IgG", "replicate": 1},
    "sample2": {"condition": "IgG", "replicate": 2},
    "sample3": {"condition": "H3K4me3", "replicate": 1},
    "sample4": {"condition": "H3K4me3", "replicate": 2},
}
MAX_FRAGMENT_LEN = 400


@dataclass
class ReferenceData:
    genome_seqs: dict[str, str]
    ecoli_seqs: dict[str, str]
    genes: list[dict]


def reverse_complement(seq: str) -> str:
    """Returns the reverse complement of a DNA sequence."""
    table = str.maketrans("ACGTNacgtn", "TGCANtgcan")
    return seq.translate(table)[::-1]


def random_seq(length: int) -> str:
    """Generates a random DNA string of the specified length."""
    return "".join(random.choices("ACGT", k=length))


def generate_genome(filepath: str, genome_dict: dict[str, int]) -> dict[str, str]:
    sequences = {}
    offset = 0
    with open(filepath, "w") as fh, open(filepath + ".fai", "w") as fai:
        for chrom, size in genome_dict.items():
            seq = random_seq(size)
            sequences[chrom] = seq
            header = f">{chrom}\n"
            fh.write(header)
            offset += len(header)
            fai.write(f"{chrom}\t{size}\t{offset}\t80\t81\n")
            for i in range(0, len(seq), 80):
                chunk = seq[i : i + 80] + "\n"
                fh.write(chunk)
                offset += len(chunk)
    return sequences


def generate_chrom_sizes(filepath: str) -> None:
    with open(filepath, "w") as fh:
        for chrom, size in GENOME.items():
            fh.write(f"{chrom}\t{size}\n")


def _make_genes(chrom: str, n_genes: int, chrom_size: int) -> list[dict]:
    """Calculate synthetic gene coordinates distributed across a chromosome."""
    genes = []
    # Dynamically calculate spacing so genes perfectly fit the chromosome
    spacing = (chrom_size - (GENE_START_OFFSET * 2)) // max(1, n_genes)

    for i in range(n_genes):
        start = GENE_START_OFFSET + i * spacing
        end = start + GENE_LENGTH
        if end >= chrom_size - 1000:
            import sys

            print(
                f"ERROR: Cannot fit {n_genes} genes on {chrom}. Truncation prevented.",
                file=sys.stderr,
            )
            sys.exit(1)
        strand = "+" if i % 2 == 0 else "-"
        gene_id = f"{chrom.upper()}_GENE{i + 1:03d}"
        genes.append(
            dict(chrom=chrom, start=start, end=end, strand=strand, gene_id=gene_id)
        )
    return genes


def generate_annotation(filepath: str) -> list[dict]:
    all_genes = []
    all_genes += _make_genes("chr1", GENES_CHR1, GENOME["chr1"])
    all_genes += _make_genes("chr2", GENES_CHR2, GENOME["chr2"])
    with open(filepath, "w") as fh:
        for g in all_genes:
            c, s, e, st, gid = (
                g["chrom"],
                g["start"],
                g["end"],
                g["strand"],
                g["gene_id"],
            )
            tx_id = f"TX_{gid}"
            fh.write(
                f'{c}\ttest\tgene\t{s}\t{e}\t.\t{st}\t.\tgene_id "{gid}"; gene_name "{gid}";\n'
            )
            fh.write(
                f'{c}\ttest\ttranscript\t{s}\t{e}\t.\t{st}\t.\tgene_id "{gid}"; transcript_id "{tx_id}";\n'
            )
            fh.write(
                f'{c}\ttest\texon\t{s}\t{s + 1000}\t.\t{st}\t.\tgene_id "{gid}"; transcript_id "{tx_id}";\n'
            )
            fh.write(
                f'{c}\ttest\texon\t{e - 1000}\t{e}\t.\t{st}\t.\tgene_id "{gid}"; transcript_id "{tx_id}";\n'
            )
    return all_genes


def _tss_position(gene: dict) -> int:
    """Returns the Transcription Start Site coordinate based on strand."""
    return gene["start"] if gene["strand"] == "+" else gene["end"]


def _write_fragment(
    f1,
    f2,
    seqs: dict[str, str],
    quals: str,
    read_idx: int,
    tss_dict: dict[str, list[int]] | None = None,
) -> int:
    """Calculates a DNA fragment and writes it to the FASTQ files. Returns the next read_idx."""
    chroms = (
        list(seqs.keys()) if tss_dict is None else [c for c in tss_dict if c in seqs]
    )
    if not chroms:
        return read_idx
    chrom = random.choice(chroms)
    seq = seqs[chrom]
    frag_len = max(
        READ_LENGTH + 10,
        min(int(random.gauss(FRAGMENT_MEAN, FRAGMENT_SD)), MAX_FRAGMENT_LEN),
    )
    if len(seq) <= frag_len:
        return read_idx

    if tss_dict is not None:
        tss = random.choice(tss_dict[chrom])
        offset = random.randint(-TSS_WINDOW, TSS_WINDOW)
        pos = max(0, min(tss + offset, len(seq) - frag_len))
    else:
        pos = random.randint(0, len(seq) - frag_len)

    fragment = seq[pos : pos + frag_len]
    f1.write(f"@READ{read_idx:06d}/1\n{fragment[:READ_LENGTH]}\n+\n{quals}\n")
    f2.write(
        f"@READ{read_idx:06d}/2\n{reverse_complement(fragment[-READ_LENGTH:])}\n+\n{quals}\n"
    )
    return read_idx + 1


def generate_fastq_paired(
    r1_path: str,
    r2_path: str,
    ref: ReferenceData,
    n_reads: int = READS_PER_SAMPLE,
) -> None:
    genome_seqs = ref.genome_seqs
    ecoli_seqs = ref.ecoli_seqs
    genes = ref.genes

    quals = "I" * (READ_LENGTH - 15) + "5" * 15
    n_targeted = int(n_reads * TSS_TARGETED_FRACTION)
    n_spikein = int(n_reads * SPIKEIN_FRACTION)
    n_random = n_reads - n_targeted - n_spikein

    tss_by_chrom: dict[str, list[int]] = defaultdict(list)
    for g in genes:
        tss_by_chrom[g["chrom"]].append(_tss_position(g))

    with gzip.open(r1_path, "wt") as f1, gzip.open(r2_path, "wt") as f2:
        read_idx = 0

        # 1. Targeted reads
        for _ in range(n_targeted):
            read_idx = _write_fragment(
                f1, f2, genome_seqs, quals, read_idx, tss_by_chrom
            )

        # 2. Spike-in reads
        for _ in range(n_spikein):
            read_idx = _write_fragment(f1, f2, ecoli_seqs, quals, read_idx)

        # 3. Random background reads
        for _ in range(n_random):
            read_idx = _write_fragment(f1, f2, genome_seqs, quals, read_idx)


def generate_blacklist(filepath: str) -> None:
    with open(filepath, "w") as fh:
        fh.write("chr1\t100000\t101000\n")
        fh.write("chr2\t50000\t51000\n")


def generate_bt2_index(index_dir: str, prefix: str, fasta: str) -> None:
    os.makedirs(index_dir, exist_ok=True)
    try:
        subprocess.run(
            ["bowtie2-build", fasta, os.path.join(index_dir, prefix)],
            check=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        print(f"  Bowtie2 index '{prefix}' built successfully.")
    except Exception as e:
        import sys

        print(f"ERROR: bowtie2-build failed or missing. {e}", file=sys.stderr)
        sys.exit(1)


def generate_samples_tsv(filepath: str, root_dir: pathlib.Path) -> None:
    os.makedirs(os.path.dirname(filepath), exist_ok=True)
    with open(filepath, "w") as fh:
        fh.write("sample\tfastq_r1\tfastq_r2\treplicate\tcondition\n")
        for sample, info in SAMPLES.items():
            r1 = root_dir / f"data/fastq/{sample}_R1.fastq.gz"
            r2 = root_dir / f"data/fastq/{sample}_R2.fastq.gz"
            fh.write(
                f"{sample}\t{r1}\t{r2}\t{info['replicate']}\t{info['condition']}\n"
            )


def main() -> None:
    random.seed(42)
    root = pathlib.Path(__file__).resolve().parents[2]
    print("=" * 60)
    print("Generating synthetic CI test data for CUT&RUN")
    print("=" * 60)
    for subdir in [
        "data/fastq",
        "data/reference/bowtie2",
        "data/reference/ecoli/bowtie2",
        "data/fastp",
    ]:
        os.makedirs(os.path.join(root, subdir), exist_ok=True)

    genome_fa = os.path.join(root, "data/reference/genome.fa")
    ecoli_fa = os.path.join(root, "data/reference/ecoli/ecoli.fa")

    print("\n[1/6] Reference genomes ...")
    genome_seqs = generate_genome(genome_fa, GENOME)
    ecoli_seqs = generate_genome(ecoli_fa, ECOLI_GENOME)
    print(f"  Target genome: {sum(len(s) for s in genome_seqs.values()):,} bp")
    print(f"  E. coli spike-in: {sum(len(s) for s in ecoli_seqs.values()):,} bp")

    print("[2/6] Chromosome sizes & Annotation ...")
    generate_chrom_sizes(os.path.join(root, "data/reference/genome.chrom.sizes"))
    genes = generate_annotation(os.path.join(root, "data/reference/annotation.gtf"))
    generate_blacklist(os.path.join(root, "data/reference/ENCODE_blacklist.bed"))

    print("[3/6] Target Bowtie2 index ...")
    generate_bt2_index(
        os.path.join(root, "data/reference/bowtie2"), "genome", genome_fa
    )

    print("[4/6] E. coli Bowtie2 index ...")
    generate_bt2_index(
        os.path.join(root, "data/reference/ecoli/bowtie2"), "ecoli", ecoli_fa
    )

    print(
        f"[5/6] Paired-end FASTQs ({READS_PER_SAMPLE} reads/sample, {int(TSS_TARGETED_FRACTION * 100)}% TSS-targeted, {int(SPIKEIN_FRACTION * 100)}% Spike-in) ..."
    )
    refs = ReferenceData(
        genome_seqs=genome_seqs,
        ecoli_seqs=ecoli_seqs,
        genes=genes,
    )
    for sample in SAMPLES:
        generate_fastq_paired(
            os.path.join(root, f"data/fastq/{sample}_R1.fastq.gz"),
            os.path.join(root, f"data/fastq/{sample}_R2.fastq.gz"),
            refs,
        )
        print(f"  {sample} ✓")

    print("[6/6] Sample sheet ...")
    generate_samples_tsv(os.path.join(root, "data/samples.tsv"), root)

    print("\n" + "=" * 60)
    print("Test data generated successfully.")


if __name__ == "__main__":
    main()
