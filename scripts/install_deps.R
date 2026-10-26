#!/usr/bin/env Rscript
# install_deps.R — install missing R dependencies (CRAN + Bioconductor)
#
# Usage:
#   Rscript scripts/install_deps.R          # install what is missing
#   Rscript scripts/install_deps.R --check  # only report

if (dir.exists(".Rlib")) .libPaths(c(".Rlib", .libPaths()))

args <- commandArgs(trailingOnly = TRUE)
check_only <- "--check" %in% args

cran <- c("ggplot2", "data.table", "patchwork", "yaml", "circlize",
          "ggrepel", "scales", "ragg", "svglite", "colorspace", "gggenes")
bioc <- c("ComplexHeatmap", "ggtree", "treeio")

installed <- rownames(installed.packages())
miss_cran <- setdiff(cran, installed)
miss_bioc <- setdiff(bioc, installed)

cat("R:", R.version.string, "\n")
cat("CRAN missing:", if (length(miss_cran)) paste(miss_cran, collapse = ", ") else "none", "\n")
cat("Bioc missing:", if (length(miss_bioc)) paste(miss_bioc, collapse = ", ") else "none", "\n")

if (check_only) quit(status = 0)

if (length(miss_cran)) {
  install.packages(miss_cran, repos = "https://cloud.r-project.org")
}
if (length(miss_bioc)) {
  if (!requireNamespace("BiocManager", quietly = TRUE)) {
    install.packages("BiocManager", repos = "https://cloud.r-project.org")
  }
  BiocManager::install(miss_bioc, ask = FALSE, update = FALSE)
}

still <- setdiff(c(cran, bioc), rownames(installed.packages()))
if (length(still)) {
  cat("\nstill missing:", paste(still, collapse = ", "), "\n")
  quit(status = 1)
}
cat("\nall R dependencies present\n")
