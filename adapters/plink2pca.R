#!/usr/bin/env Rscript
# plink2pca.R — PLINK eigenvec/eigenval -> population-structure contract
#
# Usage:
#   Rscript adapters/plink2pca.R --eigenvec plink.eigenvec --out pca.tsv \
#       [--group-file pop.tsv] [--npc 4]
#
# group-file: two columns, sample<TAB>group (optional)

suppressPackageStartupMessages(library(data.table))

args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default) {
  i <- match(flag, args); if (is.na(i) || i == length(args)) default else args[i + 1]
}
eig <- get_arg("--eigenvec", "")
out_file <- get_arg("--out", "pca.tsv")
grp_file <- get_arg("--group-file", "")
npc <- as.integer(get_arg("--npc", "4"))
if (!nzchar(eig) || !file.exists(eig)) stop("eigenvec not found: ", eig)

dt <- fread(eig, header = FALSE)
if (grepl("^#?FID$", as.character(dt[1, 1]))) dt <- dt[-1]   # drop header row if present
if (ncol(dt) < 3) stop("eigenvec needs at least FID IID PC1")
setnames(dt, 1:2, c("FID", "IID"))
pc_cols <- paste0("PC", seq_len(min(npc, ncol(dt) - 2)))
setnames(dt, 3:(2 + length(pc_cols)), pc_cols)
dt[, sample := IID]

if (nzchar(grp_file)) {
  if (!file.exists(grp_file)) stop("group file not found: ", grp_file)
  g <- fread(grp_file, header = FALSE, col.names = c("sample", "group"))
  dt <- merge(dt, g, by = "sample", all.x = TRUE)
} else {
  dt[, group := FID]
}

out <- dt[, c("sample", pc_cols, "group"), with = FALSE]
fwrite(out, out_file, sep = "\t")
cat("wrote", nrow(out), "samples x", length(pc_cols), "PCs ->", out_file, "\n")
