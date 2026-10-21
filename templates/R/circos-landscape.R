#!/usr/bin/env Rscript
# circos-landscape.R — genome landscape with chord links (circlize)
#
# Usage:
#   Rscript templates/R/circos-landscape.R --data fixtures/circos \
#       --style minimal-editorial --out out/circos/minimal.png \
#       --width 160 --height 160 --dpi 300
#
#   --preset path/to/preset.yaml overrides --style.
#   Presets live in templates/presets/circos-landscape/ and only carry visual
#   parameters; the data contract never changes between styles.

suppressPackageStartupMessages({
  library(circlize)
  library(data.table)
  library(yaml)
})

args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default) {
  i <- match(flag, args)
  if (is.na(i) || i == length(args)) default else args[i + 1]
}

data_dir   <- get_arg("--data", "fixtures/circos")
style_id   <- get_arg("--style", "minimal-editorial")
preset_arg <- get_arg("--preset", "")
out_file   <- get_arg("--out", "circos.png")
width_mm   <- as.numeric(get_arg("--width", "160"))
height_mm  <- as.numeric(get_arg("--height", "160"))
dpi        <- as.numeric(get_arg("--dpi", "300"))
title_txt  <- get_arg("--title", "")

preset_path <- if (nzchar(preset_arg)) preset_arg else
  file.path("templates/presets/circos-landscape", paste0(style_id, ".yaml"))
if (!file.exists(preset_path)) {
  stop("preset not found: ", preset_path,
       "\n  available: ", paste(list.files("templates/presets/circos-landscape"), collapse = ", "))
}
st <- read_yaml(preset_path)

FONT <- if (grepl("\\.pdf$", out_file, ignore.case = TRUE)) "Helvetica" else
  if (!is.null(st$font)) st$font else "Arial"
if (grepl("\\.pdf$", out_file, ignore.case = TRUE)) {
  message("PDF device cannot embed Arial here; falling back to Helvetica. Export SVG for Arial.")
}


chrom  <- fread(file.path(data_dir, "chrom.tsv"))
tracks <- fread(file.path(data_dir, "tracks.tsv"))
links  <- fread(file.path(data_dir, "links.tsv"))

chrom[, `:=`(start = as.numeric(start), end = as.numeric(end))]
tracks[, `:=`(start = as.numeric(start), end = as.numeric(end), value = as.numeric(value))]
links[, `:=`(start1 = as.numeric(start1), end1 = as.numeric(end1),
             start2 = as.numeric(start2), end2 = as.numeric(end2))]

lev <- as.character(chrom$chrom)
chrom[, chrom := factor(chrom, levels = lev)]
tracks[, chrom := factor(chrom, levels = lev)]
links[, `:=`(chrom1 = factor(chrom1, levels = lev),
             chrom2 = factor(chrom2, levels = lev))]

draw <- function() {
  par(mar = c(0.5, 0.5, 0.5, 0.5), bg = st$bg, family = FONT)
  circos.clear()
  circos.par(
    start.degree = 90,
    gap.after = as.numeric(st$gaps),
    track.margin = c(0.004, 0.004),
    cell.padding = c(0, 0, 0, 0),
    points.overflow.warning = FALSE
  )
  circos.genomicInitialize(as.data.frame(chrom[, .(chrom, start, end)]), plotType = NULL)

  heights <- as.numeric(st$track_heights)
  fills <- as.character(st$sector_fill)

  # 1. ideogram ring
  circos.track(ylim = c(0, 1), track.height = heights[1],
               bg.border = st$sector_border, bg.lwd = st$border_lwd,
               panel.fun = function(x, y) {
                 i <- match(CELL_META$sector.index, lev)
                 fill <- if (length(fills) > 1) fills[i] else fills
                 circos.rect(CELL_META$xlim[1], 0, CELL_META$xlim[2], 1,
                             col = fill, border = NA)
               })

  # 2. chromosome labels, outside the ring
  circos.track(ylim = c(0, 1), track.height = 0.03, bg.border = NA,
               panel.fun = function(x, y) {
                 circos.text(CELL_META$xcenter, st$label_offset, CELL_META$sector.index,
                             facing = "bending.inside", niceFacing = TRUE,
                             cex = st$label_cex, font = st$label_font, adj = c(0.5, 0))
               })

  # 3. genomic tracks
  for (i in seq_along(st$tracks)) {
    spec <- st$tracks[[i]]
    d <- tracks[track == spec$key]
    if (!nrow(d)) next
    ymax <- max(d$value, na.rm = TRUE) * 1.08
    circos.genomicTrack(as.data.frame(d[, .(chrom, start, end, value)]),
                        ylim = c(0, ymax), track.height = heights[i + 1],
                        bg.border = if (isTRUE(st$grid)) "#DDDDDD" else NA,
                        bg.lwd = 0.3,
                        panel.fun = function(region, value, ...) {
                          if (identical(spec$type, "h")) {
                            circos.genomicLines(region, value, type = "h",
                                                col = spec$color, lwd = st$border_lwd)
                          } else {
                            circos.genomicLines(region, value, type = "l",
                                                col = spec$color, lwd = st$border_lwd * 1.6)
                          }
                          if (isTRUE(st$grid)) {
                            circos.segments(CELL_META$xlim[1], CELL_META$ylim[2] * 0.5,
                                            CELL_META$xlim[2], CELL_META$ylim[2] * 0.5,
                                            col = "#E6E6E6", lwd = 0.3, lty = 3)
                          }
                        })
  }

  # 4. chord links
  chrom_cols <- as.character(st$chrom_cols)
  link_col <- switch(as.character(st$link_color_by),
    source = chrom_cols[as.integer(links$chrom1)],
    target = chrom_cols[as.integer(links$chrom2)],
    single = rep(as.character(st$link_color), nrow(links)),
    chrom_cols[as.integer(links$chrom1)]
  )
  link_col <- adjustcolor(link_col, alpha.f = as.numeric(st$link_alpha))
  circos.genomicLink(
    as.data.frame(links[, .(chrom1, start1, end1)]),
    as.data.frame(links[, .(chrom2, start2, end2)]),
    col = link_col, border = NA, lwd = as.numeric(st$link_lwd)
  )

  if (nzchar(title_txt)) title(title_txt, cex.main = 0.9, font.main = 1, line = -1.2)
}

if (grepl("\\.pdf$", out_file, ignore.case = TRUE)) {
  pdf(out_file, width = width_mm / 25.4, height = height_mm / 25.4, family = FONT)
} else {
  ragg::agg_png(out_file, width = width_mm, height = height_mm, units = "mm", res = dpi)
}
draw()
dev.off()
circos.clear()
cat("wrote", out_file, "with preset", basename(preset_path), "\n")
