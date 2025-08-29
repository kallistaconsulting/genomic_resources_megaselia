#!/usr/bin/env python3

# Also whipped up by chatGPT. These are just little reformatting 
# scripts.  This one goes through the gff and creates a file that
# has two column, gene locus_tag and the protein_id.  With this 
# we can link between blast results and jbrowse.  Any results should
# be double checked against original gff file, as it is impossible 
# to guarentee against all edge cases in 20k genes, even if I 
# wrote this by hand :).

import sys, gzip
from collections import defaultdict, OrderedDict

def open_any(path):
    if path == "-" or path is None:
        return sys.stdin
    if path.endswith(".gz"):
        return gzip.open(path, "rt")
    return open(path, "r")

def parse_attrs(attr_str):
    od = OrderedDict()
    if not attr_str or attr_str == ".":
        return od
    for part in attr_str.split(";"):
        if not part:
            continue
        if "=" in part:
            k, v = part.split("=", 1)
            od[k] = v
        else:
            od[part] = ""
    return od

def main(path):
    mrna_to_genes = defaultdict(set)
    gene_locus = {}
    proteins_by_parent = defaultdict(set)
    gene_ids_seen = set()

    with open_any(path) as fh:
        for raw in fh:
            line = raw.rstrip("\n")
            if not line or line.startswith("#"):
                continue
            cols = line.split("\t")
            if len(cols) < 9:
                continue
            ftype = cols[2]
            attrs = parse_attrs(cols[8])
            if ftype == "gene":
                gid = attrs.get("ID")
                if gid:
                    gene_ids_seen.add(gid)
                    loc = attrs.get("locus_tag") or attrs.get("Name") or gid
                    gene_locus[gid] = loc
                pid = attrs.get("protein_id")
                if pid and gid:
                    for p in pid.split(","):
                        proteins_by_parent[gid].add(p)
            elif ftype in ("mRNA", "transcript"):
                mid = attrs.get("ID")
                parent = attrs.get("Parent")
                if mid and parent:
                    for p in parent.split(","):
                        mrna_to_genes[mid].add(p)
                pid = attrs.get("protein_id")
                if pid and mid:
                    for p in pid.split(","):
                        proteins_by_parent[mid].add(p)
            elif ftype == "CDS":
                parent = attrs.get("Parent")
                pid = attrs.get("protein_id")
                if pid and parent:
                    for par in parent.split(","):
                        for p in pid.split(","):
                            proteins_by_parent[par].add(p)

    gene_to_proteins = defaultdict(set)
    for parent, pids in proteins_by_parent.items():
        if parent in gene_ids_seen:
            gene_to_proteins[parent].update(pids)
    for mid, genes in mrna_to_genes.items():
        pids = proteins_by_parent.get(mid, set())
        for g in genes:
            gene_to_proteins[g].update(pids)
    for parent, pids in proteins_by_parent.items():
        if parent not in gene_to_proteins and parent in gene_ids_seen:
            gene_to_proteins[parent].update(pids)

    seen_pairs = set()
    out = sys.stdout
    for gid in sorted(gene_locus):
        locus = gene_locus[gid]
        for pid in sorted(gene_to_proteins.get(gid, [])):
            pair = (pid, locus)
            if pair in seen_pairs:
                continue
            seen_pairs.add(pair)
            out.write(f"{pid}\t{locus}\n")

if __name__ == "__main__":
    infile = sys.argv[1] if len(sys.argv) > 1 else "-"
    main(infile)
