#!/usr/bin/env python3
"""
Extract genomic coordinates from a nucleotide FASTA for protein IDs found
in a hAMRonized output file.
"""

import csv
import re
import sys

from pathlib import Path


def parse_fasta_coords(fasta_path):
    """
    Parse a Prodigal-annotated nucleotide FASTA and return a dict mapping
    sequence ID -> (start, stop).
    
    Header format: >k141_2103332_2 # 364 # 945 # 1 # ID=...
    """
    coords = {}
    pattern = re.compile(r'^>(\S+)\s+#\s+(\d+)\s+#\s+(\d+)')

    with open(fasta_path) as f:
        for line in f:
            if line.startswith('>'):
                m = pattern.match(line)
                if m:
                    seq_id, start, stop = m.group(1), m.group(2), m.group(3)
                    coords[seq_id] = (start, stop)

    return coords


def parse_hamronized_ids(hamronized_path):
    """
    Parse the hAMRonized TSV and return a list of unique input_sequence_id values.
    """
    seen = set()

    with open(hamronized_path) as f:
        reader = csv.DictReader(f, delimiter='\t')
        for row in reader:
            if row.get("analysis_software_name", "") == "deeparg":
                seq_id = row.get('input_sequence_id', '').strip()
                if seq_id and seq_id not in seen:
                    yield seq_id
                    seen.add(seq_id)


def main():
    if len(sys.argv) != 4:
        print(
            "Usage: python extract_coords.py "
            "<hamronized.tsv> <prodigal.fna> <output.tsv>",
            file=sys.stderr
        )
        sys.exit(1)

    hamronized_path = sys.argv[1]
    fasta_path      = sys.argv[2]
    output_path     = sys.argv[3]

    print("Parsing FASTA coordinates...", file=sys.stderr)
    fasta_coords = parse_fasta_coords(fasta_path)
    print(f"  Loaded {len(fasta_coords):,} sequences from FASTA.", file=sys.stderr)

    print("Parsing hAMRonized IDs...", file=sys.stderr)
    seq_ids = list(parse_hamronized_ids(hamronized_path))
    print(f"  Found {len(seq_ids):,} unique input_sequence_id values.", file=sys.stderr)

    missing = []
    n_rows = 0

    # Write output TSV
    with open(output_path, 'w') as out:
        out.write("input_sequence_id\tstart\tstop\n")
        for seq_id in seq_ids:
            coords = fasta_coords.get(seq_id, fasta_coords.get(seq_id[:seq_id.rfind("_")]))
            if coords:
                print(seq_id, *coords, sep="\t", file=out)
                n_rows += 1
            else:
                missing.append(seq_id)

    print(f"\nWrote {n_rows:,} rows to {output_path}.", file=sys.stderr)

    if missing:
        print(
            f"\nWARNING: {len(missing):,} ID(s) from the hAMRonized file "
            "were not found in the FASTA:",
            file=sys.stderr
        )
        for m in missing:
            print(f"  {m}", file=sys.stderr)


if __name__ == "__main__":
    main()
    

# example usage: 
# python extract_coords.py \
#  SAMEA112496619_METAG_H5WNWDSXC.SW051-2.psa_megahit.prodigal.mapping.hamronized.tsv \
#  SAMEA112496619_METAG_H5WNWDSXC.SW051-2.psa_megahit.prodigal.fna \
#  coords_output.tsv