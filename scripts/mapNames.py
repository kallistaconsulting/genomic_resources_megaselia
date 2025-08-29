#!/usr/bin/env python3

# Also whipped up by chatGPT. These are just little reformatting 
# scripts.  This one reformats the header on the sequence file 
# used only for blast - so you can always check the sequences 
# against the original file (downloadable from the website) if 
# you don't trust it.  However, this takes the KAL protein_id
# and adds the associated gene's locus_tag.  With this we can 
# link between blast results and jbrowse.  Any results should
# be doublechecked against original files, as it is impossible 
# to guarentee against all edge cases in 20k genes, even if I 
# wrote this by hand :).

import sys

def load_map(mapfile):
    kal_to_ac = {}
    with open(mapfile) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            kal, ac = line.split("\t")
            kal_to_ac[kal] = ac
    return kal_to_ac

def rewrite_fasta(fastafile, kal_to_ac):
    with open(fastafile) as f:
        for line in f:
            if line.startswith(">"):
                header = line[1:].strip().split()[0]
                ac = kal_to_ac.get(header)
                if ac:
                    sys.stdout.write(f">{ac} protein_id={header}\n")
                else:
                    sys.stdout.write(line)
            else:
                sys.stdout.write(line)

if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.stderr.write(f"Usage: {sys.argv[0]} map.tsv input.fasta > output.fasta\n")
        sys.exit(1)
    kal_to_ac = load_map(sys.argv[1])
    rewrite_fasta(sys.argv[2], kal_to_ac)
