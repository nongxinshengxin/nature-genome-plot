#!/usr/bin/env Rscript
# Example mapping step for WF2: messy GWAS csv -> manhattan-qq contract
suppressPackageStartupMessages(library(data.table))
dt <- fread("examples/messy-gwas.csv")
setnames(dt, c("chromosome", "position", "p_value"), c("CHR", "BP", "P"))
dt[, CHR := sub("^chr", "", CHR)]
dt[, CHR := paste0("chr", CHR)]
dt <- dt[!is.na(P) & P >= 0]   # 0 留给模板处理，模板会截断并提示
dt <- dt[, .(CHR, BP, P)]
dir.create("examples/gwas-clean", showWarnings = FALSE)
fwrite(dt, "examples/gwas-clean/gwas.tsv", sep = "\t")
cat("clean rows:", nrow(dt), "\n")
