#!/usr/bin/env Rscript
# region-architecture.R — one genomic segment: genes, repeats and tracks
#
# Usage:
#   Rscript templates/R/region-architecture.R --data fixtures/region-architecture \
#       --style nature-region --out out/region-architecture/nature.png \
#       --width 183 --height 85 --dpi 300

suppressPackageStartupMessages({
  library(ggplot2)
  library(data.table)
  library(patchwork)
  library(yaml)
  library(scales)
})

args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default) {
  i <- match(flag, args); if (is.na(i) || i == length(args)) default else args[i + 1]
}
data_dir <- get_arg("--data", "fixtures/region-architecture")
style_id <- get_arg("--style", "nature-region")
preset_arg <- get_arg("--preset", "")
out_file <- get_arg("--out", "region-architecture.png")
width_mm <- as.numeric(get_arg("--width", "183"))
height_mm <- as.numeric(get_arg("--height", "85"))
dpi <- as.numeric(get_arg("--dpi", "300"))

preset_path <- if (nzchar(preset_arg)) preset_arg else
  file.path("templates/presets/region-architecture", paste0(style_id, ".yaml"))
if (!file.exists(preset_path)) stop("preset not found: ", preset_path)
st <- read_yaml(preset_path)

FONT <- if (grepl("\\.pdf$", out_file, ignore.case = TRUE)) "Helvetica" else
  if (!is.null(st$font)) st$font else "Arial"
if (grepl("\\.pdf$", out_file, ignore.case = TRUE)) {
  message("PDF device cannot embed Arial here; falling back to Helvetica. Export SVG for Arial.")
}

genes <- fread(file.path(data_dir, "genes.tsv"))
reps <- fread(file.path(data_dir, "repeats.tsv"))
reg <- fread(file.path(data_dir, "region.tsv"))
has_tracks <- file.exists(file.path(data_dir, "tracks.tsv"))
tracks <- if (has_tracks) fread(file.path(data_dir, "tracks.tsv")) else NULL

keep <- function(d) d[chrom == reg$chrom & end >= reg$start & start <= reg$end]
genes <- keep(genes); reps <- keep(reps)
if (!is.null(tracks)) tracks <- keep(tracks)

gene_cols <- unlist(st$gene_colors)
te_cols <- unlist(st$te_colors)
genes[, col := ifelse(family %in% names(gene_cols), gene_cols[family], "#777777")]
reps[, col := ifelse(class %in% names(te_cols), te_cols[class], "#BBBBBB")]

plus <- genes[strand == "+"]; minus <- genes[strand == "-"]
labels <- genes[order(-(end - start))][1:min(st$label_n, nrow(genes))]
labels[, `:=`(y = ifelse(strand == "+", st$gene_plus_y + 0.10, st$gene_minus_y - 0.10),
              hjust = 0.5)]

tab <- table(reps$class)
lane_of <- setNames(seq_along(names(tab)) - 1, names(tab))
reps[, lane := lane_of[class]]
reps[, `:=`(ymin = st$te_y0 + lane * st$te_lane_h,
            ymax = st$te_y0 + lane * st$te_lane_h + st$te_lane_h * 0.78)]

span <- reg$end - reg$start
bar_kb <- if (identical(st$scalebar_kb, "auto") || is.null(st$scalebar_kb)) {
  signif(span / 10, 1) / 1000
} else as.numeric(st$scalebar_kb)

x_breaks <- seq(reg$start, reg$end, by = st$tick_kb * 1000)
x_labels <- sprintf("%.1f", x_breaks / 1e6)

p_main <- ggplot() +
  geom_rect(data = reps, aes(xmin = start, xmax = end, ymin = ymin, ymax = ymax, fill = class),
            colour = NA) +
  geom_segment(data = plus, aes(x = start, xend = end, y = st$gene_plus_y, yend = st$gene_plus_y,
                                colour = family),
               linewidth = st$gene_lw, lineend = "butt",
               arrow = arrow(length = unit(st$arrow_size, "cm"), type = "closed")) +
  geom_segment(data = minus, aes(x = end, xend = start, y = st$gene_minus_y, yend = st$gene_minus_y,
                                 colour = family),
               linewidth = st$gene_lw, lineend = "butt",
               arrow = arrow(length = unit(st$arrow_size, "cm"), type = "closed")) +
  geom_text(data = labels, aes(x = (start + end) / 2, y = y, label = name),
            size = st$label_size / .pt, fontface = "italic", colour = "#222222",
            check_overlap = TRUE) +
  annotate("segment", x = reg$start, xend = reg$start + bar_kb * 1000,
           y = -0.02, yend = -0.02, linewidth = 0.5, colour = "black") +
  annotate("text", x = reg$start + bar_kb * 500, y = -0.10,
           label = paste0(bar_kb, " kb"), size = st$axis_text / .pt) +
  scale_fill_manual(values = te_cols, name = "Repeat class") +
  scale_colour_manual(values = gene_cols, name = "Gene family") +
  scale_x_continuous(limits = c(reg$start, reg$end), expand = c(0, 0),
                     breaks = x_breaks, labels = x_labels) +
  scale_y_continuous(limits = c(-0.16, 1.25), expand = c(0, 0)) +
  labs(x = sprintf("Position on %s (Mb)", reg$chrom), y = NULL) +
  theme_classic(base_size = st$base_size, base_family = FONT) +
  theme(
    axis.text = element_text(size = st$axis_text, colour = "black"),
    axis.title = element_text(size = st$base_size),
    axis.text.y = element_blank(), axis.ticks.y = element_blank(),
    axis.line.y = element_blank(),
    legend.position = st$legend,
    legend.box = "horizontal",
    legend.title = element_text(size = st$axis_text),
    legend.text = element_text(size = st$axis_text - 0.5),
    legend.key.size = unit(3, "mm"),
    plot.margin = margin(2, 3, 1, 2)
  )
if (isTRUE(st$panel_border)) {
  p_main <- p_main + theme(panel.border = element_rect(colour = "black", fill = NA, linewidth = 0.4))
}

panels <- list(p_main)
if (!is.null(tracks) && nrow(tracks)) {
  track_cols <- unlist(st$track_colors)
  for (tr in unique(tracks$track)) {
    d <- tracks[track == tr]
    ymax <- max(d$value, na.rm = TRUE) * 1.15
    p <- ggplot(d, aes(start, value)) +
      geom_area(fill = track_cols[[tr]], alpha = 0.25, colour = NA) +
      geom_line(colour = track_cols[[tr]], linewidth = 0.4) +
      scale_x_continuous(limits = c(reg$start, reg$end), expand = c(0, 0)) +
      scale_y_continuous(limits = c(0, ymax), expand = c(0, 0)) +
      labs(x = NULL, y = tr) +
      theme_classic(base_size = st$base_size, base_family = FONT) +
      theme(
        axis.text.x = element_blank(), axis.ticks.x = element_blank(),
        axis.text.y = element_text(size = st$axis_text - 1, colour = "black"),
        axis.title.y = element_text(size = st$axis_text, angle = 0, vjust = 0.5),
        axis.title.x = element_blank(),
        plot.margin = margin(0.5, 3, 0.5, 2)
      )
    p <- p + theme(panel.border = element_rect(colour = "#CCCCCC", fill = NA, linewidth = 0.3))
    panels[[length(panels) + 1]] <- p
  }
}

p <- wrap_plots(panels, ncol = 1) +
  plot_layout(heights = c(2.2, rep(0.7, length(panels) - 1)), guides = "collect") &
  theme(legend.position = st$legend)

if (grepl("\\.svg$", out_file, ignore.case = TRUE)) {
  if (!requireNamespace("svglite", quietly = TRUE)) stop("SVG export needs svglite")
  ggsave(out_file, p, width = width_mm, height = height_mm, units = "mm", device = svglite::svglite)
} else if (grepl("\\.pdf$", out_file, ignore.case = TRUE)) {
  ggsave(out_file, p, width = width_mm, height = height_mm, units = "mm", device = "pdf")
} else {
  ggsave(out_file, p, width = width_mm, height = height_mm, units = "mm", dpi = dpi, device = ragg::agg_png)
}
cat("wrote", out_file, "with preset", basename(preset_path), "\n")
