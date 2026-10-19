#!/usr/bin/env Rscript
# assembly-qc.R — BUSCO composition + NGx curve
#
# Usage:
#   Rscript templates/R/assembly-qc.R --data fixtures/assembly-qc \
#       --style minimal-editorial --out out/assembly-qc/minimal.png \
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

data_dir <- get_arg("--data", "fixtures/assembly-qc")
style_id <- get_arg("--style", "minimal-editorial")
preset_arg <- get_arg("--preset", "")
out_file <- get_arg("--out", "assembly-qc.png")
width_mm <- as.numeric(get_arg("--width", "183"))
height_mm <- as.numeric(get_arg("--height", "70"))
dpi <- as.numeric(get_arg("--dpi", "300"))

preset_path <- if (nzchar(preset_arg)) preset_arg else
  file.path("templates/presets/assembly-qc", paste0(style_id, ".yaml"))
if (!file.exists(preset_path)) stop("preset not found: ", preset_path)
st <- read_yaml(preset_path)

busco <- fread(file.path(data_dir, "busco.tsv"))
ngx <- fread(file.path(data_dir, "ngx.tsv"))

busco[, class := factor(class, levels = c("Complete (single-copy)", "Complete (duplicated)",
                                          "Fragmented", "Missing"))]
busco[, assembly := factor(assembly, levels = unique(busco$assembly))]
ngx[, assembly := factor(assembly, levels = levels(busco$assembly))]

pal <- unlist(st$palette)
lab_pal <- unlist(st$lab_palette)

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

p_busco <- ggplot(busco, aes(assembly, percent, fill = class)) +
  geom_col(width = 0.7, colour = "white", linewidth = 0.2) +
  scale_fill_manual(values = pal) +
  scale_y_continuous(expand = c(0, 0), limits = c(0, 100)) +
  labs(x = NULL, y = "BUSCO (%)") +
  base_theme +
  theme(legend.position = "right")

p_ngx <- ggplot(ngx, aes(x, mb, colour = assembly)) +
  geom_line(linewidth = st$lwd) +
  scale_colour_manual(values = lab_pal) +
  scale_x_continuous(breaks = c(0, 25, 50, 75, 100), expand = c(0.01, 0)) +
  labs(x = "x (%)", y = "NGx (Mb)") +
  base_theme +
  theme(legend.position = "none")

p <- p_busco + p_ngx + plot_layout(widths = c(1.2, 1))

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
