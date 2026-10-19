#!/usr/bin/env Rscript
# presence-absence.R — pangenome presence/absence heatmap
#
# Usage:
#   Rscript templates/R/presence-absence.R --data fixtures/presence-absence \
#       --style minimal-editorial --out out/presence-absence/minimal.png \
#       --width 183 --height 120 --dpi 300

suppressPackageStartupMessages({
  library(ComplexHeatmap)
  library(circlize)
  library(data.table)
  library(yaml)
  library(grid)
})

args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default) {
  i <- match(flag, args)
  if (is.na(i) || i == length(args)) default else args[i + 1]
}

data_dir <- get_arg("--data", "fixtures/presence-absence")
style_id <- get_arg("--style", "minimal-editorial")
preset_arg <- get_arg("--preset", "")
out_file <- get_arg("--out", "presence-absence.png")
width_mm <- as.numeric(get_arg("--width", "183"))
height_mm <- as.numeric(get_arg("--height", "120"))
dpi <- as.numeric(get_arg("--dpi", "300"))

preset_path <- if (nzchar(preset_arg)) preset_arg else
  file.path("templates/presets/presence-absence", paste0(style_id, ".yaml"))
if (!file.exists(preset_path)) stop("preset not found: ", preset_path)
st <- read_yaml(preset_path)

mat_dt <- fread(file.path(data_dir, "pav.tsv"))
samples <- fread(file.path(data_dir, "samples.tsv"))
genes <- fread(file.path(data_dir, "genes.tsv"))
cat_levels <- unique(genes$category)

mat <- as.matrix(mat_dt[, -1])
rownames(mat) <- mat_dt$gene
samples <- samples[match(colnames(mat), sample)]
genes <- genes[match(rownames(mat), gene)]

group_cols <- unlist(st$group_colors)
names(group_cols) <- unique(samples$group)
cat_cols <- unlist(st$cat_colors)
names(cat_cols) <- cat_levels

mat_cols <- colorRamp2(c(0, 1), c(st$low, st$high))

top_ha <- HeatmapAnnotation(
  Group = samples$group,
  col = list(Group = group_cols),
  show_annotation_name = FALSE,
  annotation_name_side = "left",
  annotation_name_gp = gpar(fontsize = st$col_font - 0.5),
  simple_anno_size = unit(3, "mm"),
  annotation_legend_param = list(Group = list(title_gp = gpar(fontsize = st$col_font),
                                              labels_gp = gpar(fontsize = st$col_font - 0.5)))
)

row_ha <- rowAnnotation(
  Category = genes$category,
  col = list(Category = cat_cols),
  show_annotation_name = FALSE,
  annotation_name_side = "top",
  annotation_name_gp = gpar(fontsize = st$row_font - 0.5),
  simple_anno_size = unit(2.5, "mm")
)

ht <- Heatmap(
  mat,
  name = st$legend_title,
  col = mat_cols,
  top_annotation = top_ha,
  left_annotation = row_ha,
  cluster_rows = TRUE,
  cluster_columns = FALSE,
  column_split = factor(samples$group, levels = unique(samples$group)),
  column_title = NULL,
  row_split = if (isTRUE(st$row_split)) factor(genes$category, levels = cat_levels) else NULL,
  row_title_gp = gpar(fontsize = st$col_font),
  row_title_rot = 0,
  row_gap = unit(1, "mm"),
  show_row_names = isTRUE(st$show_row_names),
  show_column_names = FALSE,
  show_row_dend = isTRUE(st$show_row_dend),
  row_names_gp = gpar(fontsize = st$row_font),
  border = TRUE,
  border_gp = gpar(col = st$border_color, lwd = st$border_lw),
  rect_gp = gpar(col = st$border_color, lwd = st$border_lw),
  use_raster = isTRUE(st$raster),
  heatmap_legend_param = list(
    title_gp = gpar(fontsize = st$col_font),
    labels_gp = gpar(fontsize = st$col_font - 0.5),
    grid_height = unit(4, "mm"),
    grid_width = unit(3, "mm")
  )
)

draw_ht <- function() {
  draw(ht, merge_legend = TRUE,
       padding = unit(c(2, 2, 2, 2), "mm"))
}

if (grepl("\\.pdf$", out_file, ignore.case = TRUE)) {
  pdf(out_file, width = width_mm / 25.4, height = height_mm / 25.4, family = "Helvetica")
} else {
  ragg::agg_png(out_file, width = width_mm, height = height_mm, units = "mm", res = dpi)
}
draw_ht()
dev.off()
cat("wrote", out_file, "with preset", basename(preset_path), "\n")
