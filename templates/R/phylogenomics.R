#!/usr/bin/env Rscript
# phylogenomics.R — tree with trait heatmap (ggtree)
#
# Usage:
#   Rscript templates/R/phylogenomics.R --data fixtures/phylogenomics \
#       --style minimal-editorial --out out/phylogenomics/minimal.png \
#       --width 140 --height 120 --dpi 300

suppressPackageStartupMessages({
  library(ggtree)
  library(ggplot2)
  library(data.table)
  library(yaml)
  library(treeio)
})

args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default) {
  i <- match(flag, args)
  if (is.na(i) || i == length(args)) default else args[i + 1]
}

data_dir <- get_arg("--data", "fixtures/phylogenomics")
style_id <- get_arg("--style", "minimal-editorial")
preset_arg <- get_arg("--preset", "")
out_file <- get_arg("--out", "phylogenomics.png")
width_mm <- as.numeric(get_arg("--width", "140"))
height_mm <- as.numeric(get_arg("--height", "120"))
dpi <- as.numeric(get_arg("--dpi", "300"))

preset_path <- if (nzchar(preset_arg)) preset_arg else
  file.path("templates/presets/phylogenomics", paste0(style_id, ".yaml"))
if (!file.exists(preset_path)) stop("preset not found: ", preset_path)
st <- read_yaml(preset_path)

FONT <- if (grepl("\\.pdf$", out_file, ignore.case = TRUE)) "Helvetica" else
  if (!is.null(st$font)) st$font else "Arial"
if (grepl("\\.pdf$", out_file, ignore.case = TRUE)) {
  message("PDF device cannot embed Arial here; falling back to Helvetica. Export SVG for Arial.")
}


tree <- read.tree(file.path(data_dir, "tree.nwk"))
mat_dt <- fread(file.path(data_dir, "matrix.tsv"))
mat <- as.data.frame(mat_dt)
rownames(mat) <- mat$tip
mat$tip <- NULL
mat <- as.matrix(mat)

p <- ggtree(tree, layout = st$layout, linewidth = st$branch_lw, colour = st$tree_color,
            size = st$branch_lw) +
  geom_tiplab(size = st$tip_size / .pt, colour = "#222222",
              offset = st$offset, align = FALSE)

if (isTRUE(st$show_support) && !is.null(tree$node.label)) {
  p <- p + geom_text2(aes(subset = !isTip & !is.na(label) & label != ""),
                      label = tree$node.label, size = st$tip_size / .pt * 0.75,
                      colour = "#666666", hjust = -0.1, vjust = -0.2)
}

p <- gheatmap(p, mat, offset = st$offset * 4, width = 0.55,
              colnames_angle = 45, colnames_offset_y = 0.25, colnames_position = "bottom",
              font.size = st$tip_size / .pt,
              color = st$heat_border) +
  scale_fill_gradientn(colours = unlist(st$heat_scale), name = NULL) +
  theme(text = element_text(family = FONT),
        legend.position = "right",
        legend.key.size = unit(3, "mm"),
        legend.text = element_text(size = st$tip_size),
        plot.margin = margin(2, 2, 9, 2))

if (dir.exists(".Rlib")) .libPaths(c(".Rlib", .libPaths()))
if (grepl("\\.svg$", out_file, ignore.case = TRUE)) {
  if (!requireNamespace("svglite", quietly = TRUE)) stop("SVG export needs svglite: install.packages('svglite')")
  ggsave(out_file, p, width = width_mm, height = height_mm, units = "mm", device = svglite::svglite)
} else if (grepl("\\.pdf$", out_file, ignore.case = TRUE)) {
  ggsave(out_file, p, width = width_mm, height = height_mm, units = "mm", device = "pdf")
} else {
  ggsave(out_file, p, width = width_mm, height = height_mm, units = "mm", dpi = dpi, device = ragg::agg_png)
}
cat("wrote", out_file, "with preset", basename(preset_path), "\n")
