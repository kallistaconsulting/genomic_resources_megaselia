#!/usr/bin/env bash
# Usage: ./add_product_to_gene.sh input.gff3 > output.gff3

# ChatGPT wrote this little support script with my prompting.  
# I read through it and tested it, but if anyone wants to 
# write a real one, let me know and I'll use it :)  But I have 
# done my time hacking gff files into compliance. 

awk -F'\t' '
BEGIN { OFS="\t"; has_gene = 0; pc = 0 }

function remove_product(attr,    n,i,kv,out) {
    n = split(attr, kv, /;/)
    out = ""
    for (i = 1; i <= n; i++) {
        if (kv[i] == "") continue
        if (kv[i] ~ /^product=/) continue
        out = (out == "" ? kv[i] : out ";" kv[i])
    }
    return out
}

function add_word(word) {
    if (word == "" || (word in seen)) return
    seen[word] = 1
    words[++pc] = word
}

function flush_gene(    plist,i,attr) {
    if (!has_gene) return
    plist = ""
    for (i = 1; i <= pc; i++) {
        plist = (plist == "" ? words[i] : plist "," words[i])
    }
    attr = gene[9]
    if (plist != "") {
        attr = remove_product(attr)
        attr = (attr == "" ? "product=" plist : attr ";product=" plist)
    }
    gene[9] = attr
    print gene[1], gene[2], gene[3], gene[4], gene[5], gene[6], gene[7], gene[8], gene[9]

    # reset state
    delete gene
    for (i in seen) delete seen[i]
    for (i in words) delete words[i]
    pc = 0
    has_gene = 0
}

# comments/directives straight through
/^#/ { print; next }

# new gene: flush previous, then buffer this one
$3 == "gene" {
    flush_gene()
    for (i = 1; i <= NF; i++) gene[i] = $i
    has_gene = 1
    next
}

# non-gene features: first print buffered gene if not yet printed
{
    if (has_gene) {
        # collect product first word
        if (NF >= 9) {
            n = split($9, a, /;/)
            for (i = 1; i <= n; i++) {
                if (a[i] ~ /^product=/) {
                    split(a[i], kv, /=/)
                    split(kv[2], wordsplit, /[ \.]+/)
                    add_word(wordsplit[1])
                }
            }
        }
        # print gene now
        flush_gene()
    }

    print
}

END { flush_gene() }
' "$1"
