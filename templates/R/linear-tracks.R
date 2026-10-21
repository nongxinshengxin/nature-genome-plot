#!/usr/bin/env Rscript
# linear-tracks.R — locus view: gene models + stacked tracks
#
# Usage:
#   Rscript templates/R/linear-tracks.R --data fixtures/linear-tracks \
#       --style minimal-editorial --out out/linear-tracks/minimal.png \
#       --width 183 --height 80 --dpi 300

suppressPackageStartupMessages({
  library(ggplot2)
  library(data.table)
  library(patchwork)
  library(yaml)
})

args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default) {
  i <- match(flag, args)
  if (is.na(i) || i == length(args)) default else args[i + 1]
}

data_dir <- get_arg("--data", "fixtures/linear-tracks")
style_id <- get_arg("--style", "minimal-editorial")
preset_arg <- get_arg("--preset", "")
out_file <- get_arg("--out", "linear-tracks.png")
width_mm <- as.numeric(get_arg("--width", "183"))
height_mm <- as.numeric(get_arg("--height", "80"))
dpi <- as.numeric(get_arg("--dpi", "300"))

preset_path <- if (nzchar(preset_arg)) preset_arg else
  file.path("templates/presets/linear-tracks", paste0(style_id, ".yaml"))
if (!file.exists(preset_path)) stop("preset not found: ", preset_path)
st <- read_yaml(preset_path)

FONT <- if (grepl("\\.pdf$", out_file, ignore.case = TRUE)) "Helvetica" else
  if (!is.null(st$font)) st$font else "Arial"
if (grepl("\\.pdf$", out_file, ignore.case = TRUE)) {
  message("PDF device cannot embed Arial here; falling back to Helvetica. Export SVG for Arial.")
}


genes <- fread(file.path(data_dir, "genes.tsv"))
tracks <- fread(file.path(data_dir, "tracks.tsv"))
reg <- fread(file.path(data_dir, "region.tsv"))

genes <- genes[chrom == reg$chrom & end >= reg$start & start <= reg$end]
tracks <- tracks[chrom == reg$chrom & end >= reg$start & start <= reg$end]
tracks[, track := factor(track, levels = c("Coverage", "GC", "TE"))]

pal <- unlist(st$palette)
names(pal) <- c("Coverage", "GC", "TE")

base_theme <- theme_classic(base_size = st$base_size, base_family = FONT) +
  theme(
    axis.text = element_text(size = st$axis_text, colour = "#333333"),
    axis.title = element_text(size = st$base_size),
    strip.background = element_blank(),
    strip.text = element_text(size = st$axis_text, hjust = 0),
    legend.position = "none",
    plot.margin = margin(1, 2, 1, 1)
  )
if (isTRUE(st$panel_border)) {
  base_theme <- base_theme + theme(panel.border = element_rect(colour = "#777777", fill = NA, linewidth = 0.3))
}
if (isTRUE(st$grid)) {
  base_theme <- base_theme + theme(panel.grid.major.y = element_line(colour = "#EFEFEF", linewidth = 0.2))
}

genes[, mid := (start + end) / 2]
label_every <- as.integer(st$label_every)
lab <- if (label_every > 0) genes[seq(1, .N, by = label_every)] else genes[0]
p_genes <- ggplot(genes) +
  geom_segment(aes(x = start, xend = end, y = 0.5, yend = 0.5),
               linewidth = st$gene_lw, colour = st$gene_color) +
  geom_segment(aes(x = ifelse(strand == "+", start, end), xend = ifelse(strand == "+", end, start),
                   y = 0.5, yend = 0.5),
               linewidth = st$gene_lw, colour = st$gene_color,
               arrow = arrow(length = unit(st$arrow_size, "cm"), type = "closed")) +
  geom_text(data = lab, aes(x = mid, y = 0.15, label = name),
            size = st$axis_text / .pt, colour = "#333333") +
  scale_y_continuous(limits = c(0, 1), expand = c(0, 0)) +
  scale_x_continuous(expand = c(0, 0), labels = function(x) paste0(x / 1e6, " Mb")) +
  labs(x = NULL, y = NULL) +
  base_theme

p_tracks <- ggplot(tracks, aes(start, value, colour = track, fill = track)) +
  geom_area(alpha = st$track_alpha * 0.35, colour = NA, show.legend = FALSE) +
  geom_line(linewidth = 0.4) +
  facet_wrap(~track, ncol = 1, scales = "free_y") +
  scale_colour_manual(values = pal) +
  scale_fill_manual(values = pal) +
  scale_x_continuous(expand = c(0, 0), labels = function(x) paste0(x / 1e6, " Mb")) +
  labs(x = NULL, y = NULL) +
  base_theme +
  theme(axis.text.y = element_blank(), axis.ticks.y = element_blank())

p <- p_genes / p_tracks + plot_layout(heights = unlist(st$heights))

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
