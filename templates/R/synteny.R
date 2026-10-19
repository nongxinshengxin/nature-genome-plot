#!/usr/bin/env Rscript
# synteny.R — synteny dot plot between two assemblies
#
# Usage:
#   Rscript templates/R/synteny.R --data fixtures/synteny \
#       --style minimal-editorial --out out/synteny/minimal.png \
#       --width 120 --height 120 --dpi 300

suppressPackageStartupMessages({
  library(ggplot2)
  library(data.table)
  library(yaml)
})

args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default) {
  i <- match(flag, args)
  if (is.na(i) || i == length(args)) default else args[i + 1]
}

data_dir <- get_arg("--data", "fixtures/synteny")
style_id <- get_arg("--style", "minimal-editorial")
preset_arg <- get_arg("--preset", "")
out_file <- get_arg("--out", "synteny.png")
width_mm <- as.numeric(get_arg("--width", "120"))
height_mm <- as.numeric(get_arg("--height", "120"))
dpi <- as.numeric(get_arg("--dpi", "300"))

preset_path <- if (nzchar(preset_arg)) preset_arg else
  file.path("templates/presets/synteny", paste0(style_id, ".yaml"))
if (!file.exists(preset_path)) stop("preset not found: ", preset_path)
st <- read_yaml(preset_path)

blocks <- fread(file.path(data_dir, "blocks.tsv"))
qchr <- fread(file.path(data_dir, "qchrom.tsv"))[order(chrom)]
tchr <- fread(file.path(data_dir, "tchrom.tsv"))[order(chrom)]

qchr[, offset := cumsum(as.numeric(length)) - as.numeric(length)]
tchr[, offset := cumsum(as.numeric(length)) - as.numeric(length)]
qchr[, center := offset + length / 2]
tchr[, center := offset + length / 2]

blocks <- merge(blocks, qchr[, .(q_chr = chrom, q_off = offset)], by = "q_chr")
blocks <- merge(blocks, tchr[, .(t_chr = chrom, t_off = offset)], by = "t_chr")
blocks[, `:=`(qx0 = q_start + q_off, qx1 = q_end + q_off,
              tx0 = t_start + t_off, tx1 = t_end + t_off)]

# densify each block into points; inversions map q -> reverse(t)
n <- as.integer(st$point_density)
blocks[, block := .I]
pts <- blocks[, {
  len <- as.numeric(q_end - q_start)
  np <- max(2L, as.integer(n * len / 3e6))
  f <- seq(0, 1, length.out = np)
  qy <- qx0 + f * (qx1 - qx0)
  tx <- if (strand[1] == 1) tx0 + f * (tx1 - tx0) else tx1 - f * (tx1 - tx0)
  .(tx = tx, qy = qy, strand = strand[1])
}, by = block]

pal <- unlist(st$palette)
base_theme <- theme_classic(base_size = st$base_size, base_family = "Helvetica") +
  theme(
    axis.text = element_text(size = st$axis_text, colour = "#333333"),
    axis.title = element_text(size = st$base_size),
    legend.position = "none",
    plot.margin = margin(2, 2, 2, 2)
  )
if (isTRUE(st$panel_border)) {
  base_theme <- base_theme + theme(panel.border = element_rect(colour = "#777777", fill = NA, linewidth = 0.3))
}
if (isTRUE(st$grid)) {
  base_theme <- base_theme + theme(panel.grid.major = element_line(colour = "#EFEFEF", linewidth = 0.2))
}

p <- ggplot(pts, aes(tx, qy)) +
  geom_vline(xintercept = tchr$offset[-1], linewidth = 0.15, colour = "#CCCCCC") +
  geom_hline(yintercept = qchr$offset[-1], linewidth = 0.15, colour = "#CCCCCC") +
  geom_point(aes(colour = factor(strand)), size = st$point_size,
             alpha = st$point_alpha, stroke = 0) +
  scale_colour_manual(values = if (isTRUE(st$color_strand)) c("-1" = pal[2], "1" = pal[1]) else
    c("-1" = st$single_color, "1" = st$single_color)) +
  scale_x_continuous(breaks = tchr$center, labels = tchr$chrom, expand = c(0.01, 0)) +
  scale_y_continuous(breaks = qchr$center, labels = qchr$chrom, expand = c(0.01, 0)) +
  labs(x = NULL, y = NULL) +
  base_theme

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
