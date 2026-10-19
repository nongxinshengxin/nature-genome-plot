#!/usr/bin/env Rscript
# paf2synteny.R — PAF alignments -> synteny dotplot contract
#
# Usage:
#   Rscript adapters/paf2synteny.R --paf aln.paf --out-dir data/synteny
#
# Writes qchrom.tsv, tchrom.tsv, blocks.tsv (q_chr,q_start,q_end,t_chr,t_start,t_end,strand)

suppressPackageStartupMessages(library(data.table))

args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default) {
  i <- match(flag, args); if (is.na(i) || i == length(args)) default else args[i + 1]
}
paf_file <- get_arg("--paf", "")
out_dir <- get_arg("--out-dir", "data/synteny")
if (!nzchar(paf_file) || !file.exists(paf_file)) stop("PAF not found: ", paf_file)
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

cols <- c("q_chr","q_len","q_start","q_end","strand","t_chr","t_len","t_start","t_end",
          "n_match","aln_len","mapq")
dt <- fread(paf_file, sep = "\t", header = FALSE, select = 1:12, col.names = cols,
            colClasses = list(character = c(1,5,6)))

dt <- dt[aln_len >= 5000]                    # drop micro-alignments
if (!nrow(dt)) stop("no alignments >= 5 kb")

q <- unique(dt[, .(chrom = q_chr, length = as.numeric(q_len))])
t <- unique(dt[, .(chrom = t_chr, length = as.numeric(t_len))])
blocks <- dt[, .(q_chr, q_start = as.numeric(q_start), q_end = as.numeric(q_end),
                 t_chr, t_start = as.numeric(t_start), t_end = as.numeric(t_end),
                 strand = ifelse(strand == "-", -1L, 1L))]

fwrite(q, file.path(out_dir, "qchrom.tsv"), sep = "\t", scipen = 999)
fwrite(t, file.path(out_dir, "tchrom.tsv"), sep = "\t", scipen = 999)
fwrite(blocks, file.path(out_dir, "blocks.tsv"), sep = "\t", scipen = 999)
cat("wrote", nrow(blocks), "blocks ->", out_dir, "\n")
