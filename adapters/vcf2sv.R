#!/usr/bin/env Rscript
# vcf2sv.R — convert symbolic-SV VCF to the tidy sv.tsv contract
#
# Usage:
#   Rscript adapters/vcf2sv.R --vcf in.vcf --out sv.tsv
#
# Contract (catalog/archetypes/sv-cnv.yaml):
#   chrom, start, end, type, length, af

suppressPackageStartupMessages(library(data.table))

args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default) {
  i <- match(flag, args); if (is.na(i) || i == length(args)) default else args[i + 1]
}
vcf_file <- get_arg("--vcf", "")
out_file <- get_arg("--out", "sv.tsv")
if (!nzchar(vcf_file)) stop("--vcf is required")
if (!file.exists(vcf_file)) stop("VCF not found: ", vcf_file)

read_vcf <- function(path) {
  lines <- readLines(path, warn = FALSE)
  lines <- lines[!grepl("^##", lines)]
  header <- strsplit(sub("^#", "", lines[1]), "\t")[[1]]
  body <- lines[-1]
  body <- body[nzchar(body)]
  dt <- fread(text = paste(c(paste(header, collapse = "\t"), body), collapse = "\n"),
              sep = "\t", header = TRUE, fill = TRUE)
  dt
}

dt <- read_vcf(vcf_file)
setnames(dt, toupper(names(dt)))
if (!"CHROM" %in% names(dt) || !"INFO" %in% names(dt)) stop("VCF lacks CHROM/INFO columns")

info_get <- function(info, key) {
  pat <- paste0("(^|;)", key, "=([^;]+)")
  m <- regmatches(info, gregexpr(pat, info))
  vapply(m, function(x) if (length(x)) sub(paste0(".*", key, "="), "", x[1]) else NA_character_,
         character(1))
}

dt[, END := as.numeric(info_get(INFO, "END"))]
dt[, SVLEN := as.numeric(info_get(INFO, "SVLEN"))]
dt[, AF := as.numeric(info_get(INFO, "AF"))]
dt[, SVTYPE := info_get(INFO, "SVTYPE")]

dt[, type := toupper(ifelse(is.na(SVTYPE) | SVTYPE == "",
                            ifelse(grepl("<", ALT), gsub("[<>]", "", ALT), "SNP"),
                            SVTYPE))]
# CNV is rendered as DUP: the sv-cnv contract has four shape classes
dt[type == "CNV", type := "DUP"]
keep <- c("DEL", "INS", "INV", "DUP")
dt <- dt[type %in% keep]
if (!nrow(dt)) stop("no DEL/INS/INV/DUP/CNV records found")

dt[, start := as.numeric(POS)]
dt[, end := ifelse(is.na(END), start + abs(ifelse(is.na(SVLEN), 1, SVLEN)), END)]
dt[, length := ifelse(!is.na(SVLEN), abs(SVLEN), end - start)]
gt_cols <- setdiff(names(dt), c("CHROM","POS","ID","REF","ALT","QUAL","FILTER","INFO","FORMAT",
                                "END","SVLEN","AF","SVTYPE","type","start","end","length"))
gt_af <- rep(NA_real_, nrow(dt))
if (length(gt_cols)) {
  gt <- as.matrix(dt[, ..gt_cols])
  alt_count <- rowSums(gt != "0/0" & gt != "0|0" & gt != "./." & gt != ".", na.rm = TRUE)
  gt_af <- alt_count / length(gt_cols)
}
dt[, af := ifelse(is.na(AF), gt_af, AF)]

out <- dt[, .(chrom = CHROM, start = as.integer(start), end = as.integer(end),
              type = type, length = as.integer(length), af = round(af, 4))]
fwrite(out, out_file, sep = "\t")
cat("wrote", nrow(out), "SV records ->", out_file, "\n")
