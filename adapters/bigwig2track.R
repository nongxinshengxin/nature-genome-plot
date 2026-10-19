#!/usr/bin/env Rscript
# bigwig2track.R — bigWig / bedGraph -> linear-tracks track table
#
# Usage:
#   Rscript adapters/bigwig2track.R --input x.bw --chrom chr1 --start 1 --end 2000000 \
#       --out tracks.tsv --name Coverage --bin 5000
#
# .bw needs rtracklayer. Without it, convert first:
#   bigWigToBedGraph x.bw x.bedGraph
# then pass --input x.bedGraph (bedGraph path is handled without rtracklayer).

suppressPackageStartupMessages(library(data.table))

args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default) {
  i <- match(flag, args); if (is.na(i) || i == length(args)) default else args[i + 1]
}
in_file <- get_arg("--input", "")
out_file <- get_arg("--out", "tracks.tsv")
chrom <- get_arg("--chrom", "")
start <- as.numeric(get_arg("--start", "0"))
end <- as.numeric(get_arg("--end", "0"))
track_name <- get_arg("--name", "Coverage")
bin <- as.numeric(get_arg("--bin", "5000"))
if (!nzchar(in_file) || !file.exists(in_file)) stop("input not found: ", in_file)

read_bedgraph <- function(path) {
  dt <- fread(path, header = FALSE, col.names = c("chrom", "start", "end", "value"))
  dt[order(chrom, start)]
}

if (grepl("\\.(bw|bigwig)$", in_file, ignore.case = TRUE)) {
  if (!requireNamespace("rtracklayer", quietly = TRUE)) {
    stop("bigWig input needs rtracklayer. Either install it, or convert first:\n",
         "  bigWigToBedGraph ", in_file, " out.bedGraph\n",
         "then rerun with --input out.bedGraph")
  }
  gr <- rtracklayer::import(in_file)
  dt <- as.data.table(as.data.frame(gr))[, .(chrom = seqnames, start = start, end = end, value = score)]
} else {
  dt <- read_bedgraph(in_file)
}

if (nzchar(chrom)) dt <- dt[chrom == ..chrom]
if (start > 0) dt <- dt[end > start]
if (end > 0) dt <- dt[start < end]

# bin to fixed windows
dt[, bin_start := floor((start - 1) / bin) * bin + 1]
agg <- dt[, .(value = mean(value, na.rm = TRUE)), by = .(chrom, bin_start)]
agg[, `:=`(start = bin_start, end = bin_start + bin - 1, track = track_name)]
agg <- agg[, .(chrom, start, end, track, value = round(value, 4))]
fwrite(agg, out_file, sep = "\t", scipen = 999)
cat("wrote", nrow(agg), "bins ->", out_file, "\n")
