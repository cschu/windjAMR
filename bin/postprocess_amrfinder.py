#!/usr/bin/env python3
# python3 - "$FAA_FILE" "$INPUT_FILE" "$PREPPED_INPUT" <<'EOF'
import re
import sys

faa_file   = sys.argv[1]
input_file = sys.argv[2]
out_file   = sys.argv[3]

# Parse FAA: >protein_id # start # stop # strand # ...
# Strand: 1 -> "+", -1 -> "-"
coords = {}
header_re = re.compile(r'^>(\S+)\s+#\s+(\d+)\s+#\s+(\d+)\s+#\s+(-?\d+)')

with open(faa_file) as f:
    for line in f:
        if line.startswith('>'):
            m = header_re.match(line)
            if m:
                pid    = m.group(1)
                start  = m.group(2)
                stop   = m.group(3)
                strand = "+" if m.group(4) == "1" else "-"
                coords[pid] = (start, stop, strand)

missing = []

with open(input_file) as fin, open(out_file, 'w') as fout:
    for i, line in enumerate(fin):
        fields = line.rstrip('\n').split('\t')
        if i == 0:
            # Header: prepend new column names
            fout.write('\t'.join(['Contig id', 'Start', 'Stop', 'Strand'] + fields) + '\n')
        else:
            protein_id = fields[0]
            if protein_id in coords:
                start, stop, strand = coords[protein_id]
            else:
                # Fall back to placeholders and warn
                start, stop, strand = '1', '100', '+'
                missing.append(protein_id)
            fout.write('\t'.join([protein_id, start, stop, strand] + fields) + '\n')

if missing:
    print(f"[PREP] WARNING: {len(missing)} protein ID(s) not found in FAA, used placeholder coordinates:")
    for pid in missing:
        print(f"  {pid}")
