#!/usr/bin/env Rscript
# population-structure.R — PCA + ADMIXTURE panel
#
# Usage:
#   Rscript templates/R/population-structure.R --data fixtures/population-structure \
#       --style minimal-editorial --out out/population-structure/minimal.png \
#       --width 183 --height 62 --dpi 300

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

data_dir <- get_arg("--data", "fixtures/population-structure")
style_id <- get_arg("--style", "minimal-editorial")
preset_arg <- get_arg("--preset", "")
out_file <- get_arg("--out", "population-structure.png")
width_mm <- as.numeric(get_arg("--width", "183"))
height_mm <- as.numeric(get_arg("--height", "62"))
dpi <- as.numeric(get_arg("--dpi", "300"))

preset_path <- if (nzchar(preset_arg)) preset_arg else
  file.path("templates/presets/population-structure", paste0(style_id, ".yaml"))
if (!file.exists(preset_path)) stop("preset not found: ", preset_path)
st <- read_yaml(preset_path)

FONT <- if (grepl("\\.pdf$", out_file, ignore.case = TRUE)) "Helvetica" else
  if (!is.null(st$font)) st$font else "Arial"
if (grepl("\\.pdf$", out_file, ignore.case = TRUE)) {
  message("PDF device cannot embed Arial here; falling back to Helvetica. Export SVG for Arial.")
}


pca <- fread(file.path(data_dir, "pca.tsv"))
adm <- fread(file.path(data_dir, "admixture.tsv"))

lev <- unique(pca$group)
pca[, group := factor(group, levels = lev)]
adm[, group := factor(group, levels = lev)]
adm[, sample := factor(sample, levels = sample)]

k_cols <- grep("^K[0-9]+$", names(adm), value = TRUE)
long <- melt(adm, id.vars = c("sample", "group"), measure.vars = k_cols,
             variable.name = "K", value.name = "prop")

pal <- unlist(st$palette)

base_theme <- theme_classic(base_size = st$base_size, base_family = FONT) +
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
  base_theme <- base_theme + theme(panel.grid.major = element_line(colour = "#ECECEC", linewidth = 0.25),
                                   panel.grid.minor = element_blank())
}

p_pca <- ggplot(pca, aes(PC1, PC2, colour = group)) +
  geom_hline(yintercept = 0, linewidth = 0.2, colour = "#BBBBBB") +
  geom_vline(xintercept = 0, linewidth = 0.2, colour = "#BBBBBB") +
  geom_point(size = st$point_size, alpha = st$point_alpha, stroke = 0) +
  scale_colour_manual(values = pal) +
  labs(x = "PC1", y = "PC2") +
  base_theme +
  theme(legend.position = st$legend)

if (isTRUE(st$ellipse)) {
  p_pca <- p_pca + stat_ellipse(aes(group = group), type = "norm", level = 0.68,
                                linewidth = 0.3, show.legend = FALSE)
}

p_adm <- ggplot(long, aes(sample, prop, fill = K)) +
  geom_col(width = 1, colour = st$admix_border, linewidth = st$admix_lwd) +
  facet_grid(~group, scales = "free_x", space = "free") +
  scale_fill_manual(values = pal[seq_along(k_cols)]) +
  scale_y_continuous(expand = c(0, 0)) +
  labs(x = NULL, y = "Ancestry") +
  base_theme +
  theme(
    axis.text.x = element_blank(),
    axis.ticks.x = element_blank(),
    strip.background = element_blank(),
    strip.text = element_text(size = st$axis_text),
    panel.spacing.x = unit(0.6, "mm")
  )

p <- p_pca + p_adm + plot_layout(widths = c(st$pca_width, st$admix_width))

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
