#!/usr/bin/env Rscript
# gene-structure.R — exon/intron structure and domain architecture of genes
#
# Usage:
#   Rscript templates/R/gene-structure.R --data fixtures/gene-structure \
#       --style nature-gene-model --out out/gene-structure/nature.png \
#       --width 183 --height 80 --dpi 300

if (dir.exists(".Rlib")) .libPaths(c(".Rlib", .libPaths()))
suppressPackageStartupMessages({
  library(ggplot2)
  library(data.table)
  library(gggenes)
  library(yaml)
  library(grid)
})

args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default) {
  i <- match(flag, args); if (is.na(i) || i == length(args)) default else args[i + 1]
}
data_dir <- get_arg("--data", "fixtures/gene-structure")
style_id <- get_arg("--style", "nature-gene-model")
preset_arg <- get_arg("--preset", "")
out_file <- get_arg("--out", "gene-structure.png")
width_mm <- as.numeric(get_arg("--width", "183"))
height_mm <- as.numeric(get_arg("--height", "80"))
dpi <- as.numeric(get_arg("--dpi", "300"))

preset_path <- if (nzchar(preset_arg)) preset_arg else
  file.path("templates/presets/gene-structure", paste0(style_id, ".yaml"))
if (!file.exists(preset_path)) stop("preset not found: ", preset_path)
st <- read_yaml(preset_path)

FONT <- if (grepl("\\.pdf$", out_file, ignore.case = TRUE)) "Helvetica" else
  if (!is.null(st$font)) st$font else "Arial"
if (grepl("\\.pdf$", out_file, ignore.case = TRUE)) {
  message("PDF device cannot embed Arial here; falling back to Helvetica. Export SVG for Arial.")
}

genes <- fread(file.path(data_dir, "genes.tsv"))
exons <- fread(file.path(data_dir, "exons.tsv"))
doms <- fread(file.path(data_dir, "domains.tsv"))

genes[, len_kb := (end - start) / 1000]
genes[, y := rev(seq_len(.N))]
setkey(genes, gene)

exons <- merge(exons, genes[, .(gene, gstart = start, y)], by = "gene")
exons[, `:=`(x0 = (start - gstart) / 1000, x1 = (end - gstart) / 1000)]
exons[, type := factor(type, levels = c("UTR", "CDS"))]
exons <- exons[order(gene, x0)]
introns <- exons[, .(x0 = head(x1, -1), x1 = tail(x0, -1), y = head(y, -1)), by = gene]

doms <- merge(doms, genes[, .(gene, gstart = start, y)], by = "gene")
doms[, `:=`(x0 = (start - gstart) / 1000, x1 = (end - gstart) / 1000)]

gene_rows <- genes[order(y)]
p <- ggplot() +
  geom_gene_arrow(data = genes,
                  aes(xmin = 0, xmax = len_kb, y = y, forward = strand == "+"),
                  fill = st$gene_fill, colour = st$gene_border, linewidth = 0.3,
                  arrowhead_height = unit(2.0, "mm"), arrow_body_height = unit(2.6, "mm")) +
  geom_segment(data = introns, aes(x = x0, xend = x1, y = y, yend = y),
               linewidth = 0.35, colour = "#555555") +
  geom_rect(data = exons,
            aes(xmin = x0, xmax = x1, ymin = y - st$exon_h / 2, ymax = y + st$exon_h / 2,
                fill = type),
            colour = "#1A1A1A", linewidth = st$exon_lw) +
  geom_segment(data = doms,
               aes(x = x0, xend = x1, y = y - st$domain_offset, yend = y - st$domain_offset,
                   colour = domain),
               linewidth = 2.2, lineend = "butt") +
  scale_fill_manual(values = unlist(st$exon_fill), name = "Exon") +
  scale_colour_manual(values = unlist(st$domain_colors), name = "Domain") +
  scale_y_continuous(breaks = gene_rows$y, labels = gene_rows$gene,
                     expand = expansion(add = c(0.45, 0.35))) +
  scale_x_continuous(expand = c(0.01, 0.01)) +
  labs(x = "Position within gene (kb)", y = NULL) +
  theme_classic(base_size = st$base_size, base_family = FONT) +
  theme(
    axis.text = element_text(size = st$axis_text, colour = "black"),
    axis.text.y = element_text(face = "italic", size = st$axis_text),
    axis.title = element_text(size = st$base_size),
    legend.position = st$legend,
    legend.box = "horizontal",
    legend.title = element_text(size = st$axis_text),
    legend.text = element_text(size = st$axis_text - 0.5),
    legend.key.size = unit(3, "mm"),
    plot.margin = margin(2, 3, 1, 2)
  )
if (isTRUE(st$panel_border)) {
  p <- p + theme(panel.border = element_rect(colour = "black", fill = NA, linewidth = 0.4))
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
