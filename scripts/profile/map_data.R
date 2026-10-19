#!/usr/bin/env Rscript
# map_data.R — remap a messy table onto an archetype contract
#
# Usage:
#   Rscript scripts/profile/map_data.R --data in.csv --map map.yaml --out out.tsv
#
# map.yaml:
#   rename:      {CHR: chromosome, BP: position, P: p_value}   # target: source
#   constants:   {track: Coverage}
#   drop:        [note, beta]
#   chr_prefix:  add | strip | keep
#   drop_na:     [P]

suppressPackageStartupMessages({
  library(data.table)
  library(yaml)
})

args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default) {
  i <- match(flag, args); if (is.na(i) || i == length(args)) default else args[i + 1]
}
in_file <- get_arg("--data", "")
map_file <- get_arg("--map", "")
out_file <- get_arg("--out", "mapped.tsv")
if (!file.exists(in_file)) stop("input not found: ", in_file)
if (!file.exists(map_file)) stop("map not found: ", map_file)

spec <- read_yaml(map_file)
sep <- if (grepl("\\.csv$", in_file, ignore.case = TRUE)) "," else "\t"
dt <- fread(in_file, sep = sep, na.strings = c("", "NA", "NaN", "null", "."))

ren <- spec$rename
if (!is.null(ren)) {
  for (target in names(ren)) {
    src <- ren[[target]]
    if (!src %in% names(dt)) stop(sprintf("map: source column '%s' not found (for target '%s')", src, target))
    setnames(dt, src, target)
  }
}

if (!is.null(spec$constants)) {
  for (nm in names(spec$constants)) dt[, (nm) := spec$constants[[nm]]]
}

if (!is.null(spec$chr_prefix) && "CHR" %in% names(dt)) {
  if (spec$chr_prefix == "strip") dt[, CHR := sub("^chr", "", CHR)]
  if (spec$chr_prefix == "add") dt[, CHR := paste0("chr", sub("^chr", "", CHR))]
}

if (!is.null(spec$drop)) {
  keep <- setdiff(names(dt), unlist(spec$drop))
  dt <- dt[, ..keep]
}

if (!is.null(spec$drop_na)) {
  for (col in unlist(spec$drop_na)) {
    if (col %in% names(dt)) dt <- dt[!is.na(get(col))]
  }
}

fwrite(dt, out_file, sep = "\t")
cat("wrote", nrow(dt), "rows x", ncol(dt), "cols ->", out_file, "\n")
cat("columns:", paste(names(dt), collapse = ", "), "\n")
