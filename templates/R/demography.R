#!/usr/bin/env Rscript
# demography.R — SFS + PSMC + LD decay
#
# Usage:
#   Rscript templates/R/demography.R --data fixtures/demography \
#       --style minimal-editorial --out out/demography/minimal.png \
#       --width 183 --height 55 --dpi 300

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

data_dir <- get_arg("--data", "fixtures/demography")
style_id <- get_arg("--style", "minimal-editorial")
preset_arg <- get_arg("--preset", "")
out_file <- get_arg("--out", "demography.png")
width_mm <- as.numeric(get_arg("--width", "183"))
height_mm <- as.numeric(get_arg("--height", "55"))
dpi <- as.numeric(get_arg("--dpi", "300"))

preset_path <- if (nzchar(preset_arg)) preset_arg else
  file.path("templates/presets/demography", paste0(style_id, ".yaml"))
if (!file.exists(preset_path)) stop("preset not found: ", preset_path)
st <- read_yaml(preset_path)

sfs <- fread(file.path(data_dir, "sfs.tsv"))
psmc <- fread(file.path(data_dir, "psmc.tsv"))
ld <- fread(file.path(data_dir, "ld.tsv"))

pal <- unlist(st$palette)
base_theme <- theme_classic(base_size = st$base_size, base_family = "Helvetica") +
  theme(
    axis.text = element_text(size = st$axis_text, colour = "#333333"),
    axis.title = element_text(size = st$base_size),
    legend.position = "none",
    plot.margin = margin(2, 3, 1, 1)
  )
if (isTRUE(st$panel_border)) {
  base_theme <- base_theme + theme(panel.border = element_rect(colour = "#777777", fill = NA, linewidth = 0.3))
}
if (isTRUE(st$grid)) {
  base_theme <- base_theme + theme(panel.grid.major = element_line(colour = "#EFEFEF", linewidth = 0.2))
}

p_sfs <- ggplot(sfs, aes(frequency, count)) +
  geom_col(fill = pal[1], width = 0.85, colour = NA) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.05))) +
  labs(x = "Derived allele frequency", y = "Count") +
  base_theme

p_psmc <- ggplot(psmc, aes(time_ka, ne)) +
  geom_step(colour = pal[2], linewidth = st$line_width) +
  scale_x_log10(labels = label_number(scale_cut = cut_short_scale())) +
  scale_y_log10(labels = label_number(scale_cut = cut_short_scale())) +
  labs(x = "Time (ka)", y = "Effective size") +
  base_theme

p_ld <- ggplot(ld, aes(distance, r2)) +
  geom_point(colour = pal[3], size = 0.7, alpha = 0.8) +
  geom_smooth(method = "loess", span = 0.7, se = FALSE,
              colour = pal[3], linewidth = st$line_width, linetype = "solid") +
  scale_x_log10(labels = label_number(scale_cut = cut_short_scale())) +
  labs(x = "Distance (bp)", y = expression(r^2)) +
  base_theme

p <- p_sfs + p_psmc + p_ld + plot_layout(widths = c(1, 1, 1))

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
