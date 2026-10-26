#!/usr/bin/env Rscript
# go-enrichment.R — GO / pathway enrichment dot plot
#
# Usage:
#   Rscript templates/R/go-enrichment.R --data fixtures/go-enrichment \
#       --style nature-dotplot --out out/go-enrichment/nature.png \
#       --width 120 --height 120 --dpi 300

suppressPackageStartupMessages({
  library(ggplot2)
  library(data.table)
  library(yaml)
  library(scales)
})

args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default) {
  i <- match(flag, args); if (is.na(i) || i == length(args)) default else args[i + 1]
}
data_dir <- get_arg("--data", "fixtures/go-enrichment")
style_id <- get_arg("--style", "nature-dotplot")
preset_arg <- get_arg("--preset", "")
out_file <- get_arg("--out", "go-enrichment.png")
width_mm <- as.numeric(get_arg("--width", "120"))
height_mm <- as.numeric(get_arg("--height", "120"))
dpi <- as.numeric(get_arg("--dpi", "300"))

preset_path <- if (nzchar(preset_arg)) preset_arg else
  file.path("templates/presets/go-enrichment", paste0(style_id, ".yaml"))
if (!file.exists(preset_path)) stop("preset not found: ", preset_path)
st <- read_yaml(preset_path)

FONT <- if (grepl("\\.pdf$", out_file, ignore.case = TRUE)) "Helvetica" else
  if (!is.null(st$font)) st$font else "Arial"
if (grepl("\\.pdf$", out_file, ignore.case = TRUE)) {
  message("PDF device cannot embed Arial here; falling back to Helvetica. Export SVG for Arial.")
}

go <- fread(file.path(data_dir, "go.tsv"))
go[, neglog10 := -log10(as.numeric(p_adjust))]
go[, x := as.numeric(get(st$x_var))]
go <- go[!is.na(x) & !is.na(neglog10)]

go[, ontology := factor(ontology, levels = intersect(c("BP", "CC", "MF"), unique(ontology)))]
go <- go[order(ontology, -neglog10)]
go[, term := factor(term, levels = rev(unique(term)))]
go[, term_wrapped := vapply(as.character(term), function(s)
  paste(strwrap(s, width = st$wrap), collapse = "\n"), character(1))]

top <- go[, head(.SD, st$top_n), by = ontology]
top <- top[order(ontology, neglog10)]
top[, term_wrapped := factor(term_wrapped, levels = unique(term_wrapped))]

p <- ggplot(top, aes(x = x, y = term_wrapped)) +
  geom_jitter(width = 0, height = 0.12, aes(size = count, colour = neglog10)) +
  facet_grid(ontology ~ ., scales = "free_y", space = "free_y") +
  scale_size_continuous(range = c(st$point_min, st$point_max), name = st$size_title) +
  scale_colour_gradient(low = st$colour_low, high = st$colour_high, name = st$colour_title) +
  scale_x_continuous(expand = expansion(mult = c(0.05, 0.08))) +
  labs(x = st$x_label, y = NULL) +
  theme_classic(base_size = st$base_size, base_family = FONT) +
  theme(
    axis.text = element_text(size = st$axis_text, colour = "black"),
    axis.title = element_text(size = st$base_size),
    strip.background = element_blank(),
    strip.text = element_text(size = st$axis_text, face = st$strip_face, hjust = 0),
    strip.text.y = element_text(angle = 0, hjust = 0, face = st$strip_face),
    legend.position = st$legend,
    legend.title = element_text(size = st$axis_text),
    legend.text = element_text(size = st$axis_text - 0.5),
    legend.key.size = unit(3, "mm"),
    plot.margin = margin(2, 3, 1, 2)
  )
if (isTRUE(st$panel_border)) {
  p <- p + theme(panel.border = element_rect(colour = "#777777", fill = NA, linewidth = 0.3))
}
if (isTRUE(st$grid)) {
  p <- p + theme(panel.grid.major = element_line(colour = "#EFEFEF", linewidth = 0.2))
}

if (grepl("\\.svg$", out_file, ignore.case = TRUE)) {
  if (!requireNamespace("svglite", quietly = TRUE)) stop("SVG export needs svglite")
  ggsave(out_file, p, width = width_mm, height = height_mm, units = "mm", device = svglite::svglite)
} else if (grepl("\\.pdf$", out_file, ignore.case = TRUE)) {
  ggsave(out_file, p, width = width_mm, height = height_mm, units = "mm", device = "pdf")
} else {
  ggsave(out_file, p, width = width_mm, height = height_mm, units = "mm", dpi = dpi, device = ragg::agg_png)
}
cat("wrote", out_file, "with preset", basename(preset_path), "\n")
