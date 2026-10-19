#!/usr/bin/env Rscript
# pangenome-composition.R — pangenome growth + core/accessory composition
#
# Usage:
#   Rscript templates/R/pangenome-composition.R --data fixtures/pangenome-composition \
#       --style minimal-editorial --out out/pangenome-composition/minimal.png \
#       --width 183 --height 70 --dpi 300

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

data_dir <- get_arg("--data", "fixtures/pangenome-composition")
style_id <- get_arg("--style", "minimal-editorial")
preset_arg <- get_arg("--preset", "")
out_file <- get_arg("--out", "pangenome-composition.png")
width_mm <- as.numeric(get_arg("--width", "183"))
height_mm <- as.numeric(get_arg("--height", "70"))
dpi <- as.numeric(get_arg("--dpi", "300"))

preset_path <- if (nzchar(preset_arg)) preset_arg else
  file.path("templates/presets/pangenome-composition", paste0(style_id, ".yaml"))
if (!file.exists(preset_path)) stop("preset not found: ", preset_path)
st <- read_yaml(preset_path)

growth <- fread(file.path(data_dir, "growth.tsv"))

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
  base_theme <- base_theme + theme(panel.grid.major = element_line(colour = "#EFEFEF", linewidth = 0.25))
}

long <- melt(growth, id.vars = "genomes",
             measure.vars = c("pan", "core"),
             variable.name = "curve", value.name = "genes")

p_growth <- ggplot(long, aes(genomes, genes, colour = curve)) +
  geom_smooth(method = "loess", se = TRUE, span = 0.35, linewidth = st$line_width,
              alpha = st$fill_alpha, level = 0.95) +
  scale_colour_manual(values = c(pan = st$palette_pan, core = st$palette_core),
                      labels = c(pan = "Pan-genome", core = "Core genome")) +
  labs(x = "Number of genomes", y = "Gene families") +
  base_theme +
  theme(legend.position = c(0.98, 0.98), legend.justification = c(1, 1))

cats <- melt(growth, id.vars = "genomes",
             measure.vars = c("core", "softcore", "shell", "cloud"),
             variable.name = "category", value.name = "genes")
cats[, category := factor(category, levels = c("core", "softcore", "shell", "cloud"))]

p_comp <- ggplot(cats, aes(genomes, genes, fill = category)) +
  geom_area(alpha = 0.9, colour = NA) +
  scale_fill_manual(values = unlist(st$palette_cat),
                    labels = c(core = "Core", softcore = "Softcore", shell = "Shell", cloud = "Cloud")) +
  labs(x = "Number of genomes", y = "Gene families") +
  base_theme +
  theme(legend.position = "right")

p <- p_growth + p_comp + plot_layout(widths = c(1, 1))

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
