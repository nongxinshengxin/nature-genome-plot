#!/usr/bin/env Rscript
# gff2genes.R — convert GFF3/GTF to the genes.tsv contract
#
# Usage:
#   Rscript adapters/gff2genes.R --gff in.gff3 --out genes.tsv --feature gene
#
# Contract (catalog/archetypes/linear-tracks.yaml):
#   chrom, start, end, strand, name

suppressPackageStartupMessages(library(data.table))

args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default) {
  i <- match(flag, args); if (is.na(i) || i == length(args)) default else args[i + 1]
}
gff_file <- get_arg("--gff", "")
out_file <- get_arg("--out", "genes.tsv")
feature <- get_arg("--feature", "gene")
if (!nzchar(gff_file)) stop("--gff is required")
if (!file.exists(gff_file)) stop("GFF not found: ", gff_file)

lines <- readLines(gff_file, warn = FALSE)
lines <- lines[!grepl("^#", lines) & nzchar(lines)]
if (!length(lines)) stop("empty GFF")

dt <- fread(text = paste(lines, collapse = "\n"), sep = "\t", header = FALSE,
            col.names = c("chrom", "source", "type", "start", "end", "score",
                          "strand", "phase", "attrs"),
            quote = "")

dt <- dt[type == feature]
if (!nrow(dt)) stop("no features of type '", feature, "' found")

get_attr <- function(x, key) {
  pat <- paste0("(^|;)\\s*", key, "[ =]([^;]+)")
  m <- regmatches(x, gregexpr(pat, x))
  vapply(m, function(h) if (length(h)) trimws(sub(paste0(".*", key, "[ =]"), "", h[1])) else NA_character_,
         character(1))
}

nm <- get_attr(dt$attrs, "Name")
id <- get_attr(dt$attrs, "ID")
name <- ifelse(!is.na(nm) & nm != "", nm, ifelse(!is.na(id) & id != "", id, NA_character_))
name[is.na(name) | name == ""] <- paste0(feature, "_", seq_len(sum(is.na(name) | name == "")))

out <- data.table(chrom = dt$chrom, start = as.integer(dt$start), end = as.integer(dt$end),
                  strand = dt$strand, name = name)
fwrite(out, out_file, sep = "\t")
cat("wrote", nrow(out), "features ->", out_file, "\n")
