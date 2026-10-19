#!/usr/bin/env Rscript
# sv-cnv.R — structural-variation landscape
#
# Usage:
#   Rscript templates/R/sv-cnv.R --data fixtures/sv-cnv \
#       --style minimal-editorial --out out/sv-cnv/minimal.png \
#       --width 183 --height 80 --dpi 300

suppressPackageStartupMessages({
  library(ggplot2)
  library(data.table)
  library(patchwork)
  library(scales)
  library(yaml)
})

args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default) {
  i <- match(flag, args)
  if (is.na(i) || i == length(args)) default else args[i + 1]
}

data_dir <- get_arg("--data", "fixtures/sv-cnv")
style_id <- get_arg("--style", "minimal-editorial")
preset_arg <- get_arg("--preset", "")
out_file <- get_arg("--out", "sv-cnv.png")
width_mm <- as.numeric(get_arg("--width", "183"))
height_mm <- as.numeric(get_arg("--height", "80"))
dpi <- as.numeric(get_arg("--dpi", "300"))

preset_path <- if (nzchar(preset_arg)) preset_arg else
  file.path("templates/presets/sv-cnv", paste0(style_id, ".yaml"))
if (!file.exists(preset_path)) stop("preset not found: ", preset_path)
st <- read_yaml(preset_path)

sv <- fread(file.path(data_dir, "sv.tsv"))
sv[, `:=`(start = as.numeric(start), end = as.numeric(end), length = as.numeric(length), af = as.numeric(af))]
sv[, CHR := factor(chrom, levels = unique(chrom))]
sv[, type := factor(type, levels = c("DEL", "INS", "INV", "DUP"))]

chr_len <- sv[, .(len = max(end)), by = CHR][order(CHR)]
chr_len[, offset := cumsum(as.numeric(len)) - as.numeric(len)]
sv <- merge(sv, chr_len[, .(CHR, offset)], by = "CHR", sort = FALSE)
sv[, cum := start + offset]
axis_dt <- chr_len[, .(CHR, center = offset + len / 2)]

bin <- as.numeric(st$bin_mb) * 1e6
sv[, bin := floor(cum / bin) * bin]
dens <- sv[, .(n = .N), by = .(CHR, bin, type)]

pal <- unlist(st$palette)
names(pal) <- levels(sv$type)

base_theme <- theme_classic(base_size = st$base_size, base_family = "Helvetica") +
  theme(
    axis.text = element_text(size = st$axis_text, colour = "#333333"),
    axis.title = element_text(size = st$base_size),
    legend.title = element_blank(),
    legend.text = element_text(size = st$axis_text),
    legend.key.size = unit(3, "mm"),
    plot.margin = margin(2, 2, 1, 1)
  )
if (isTRUE(st$panel_border)) {
  base_theme <- base_theme + theme(panel.border = element_rect(colour = "#777777", fill = NA, linewidth = 0.3))
}
if (isTRUE(st$grid)) {
  base_theme <- base_theme + theme(panel.grid.major.y = element_line(colour = "#EFEFEF", linewidth = 0.25))
}

p_dens <- ggplot(dens, aes(bin, n, fill = type)) +
  geom_col(width = bin, colour = NA) +
  scale_fill_manual(values = pal) +
  scale_x_continuous(breaks = axis_dt$center, labels = axis_dt$CHR, expand = c(0.01, 0)) +
  labs(x = NULL, y = "SV count / bin") +
  base_theme +
  theme(legend.position = "none")

p_len <- ggplot(sv, aes(length, fill = type)) +
  geom_histogram(aes(y = after_stat(density)), bins = 40, colour = "white", linewidth = 0.1) +
  scale_x_log10(labels = label_number(scale_cut = cut_short_scale()), expand = c(0.01, 0)) +
  scale_fill_manual(values = pal) +
  labs(x = "SV length (bp)", y = "Density") +
  base_theme +
  theme(legend.position = "none")

p_af <- ggplot(sv, aes(af, fill = type)) +
  geom_histogram(bins = 30, colour = "white", linewidth = 0.1, alpha = st$fill_alpha) +
  scale_fill_manual(values = pal) +
  labs(x = "Allele frequency", y = "SV count") +
  base_theme +
  theme(legend.position = "right")

p <- (p_dens / (p_len + p_af + plot_layout(widths = c(1, 1)))) +
  plot_layout(heights = c(1, 1))

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
