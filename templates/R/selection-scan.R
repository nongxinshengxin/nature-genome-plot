#!/usr/bin/env Rscript
# selection-scan.R — genome-wide Fst / pi tracks with candidate regions
#
# Usage:
#   Rscript templates/R/selection-scan.R --data fixtures/selection-scan \
#       --style minimal-editorial --out out/selection-scan/minimal.png \
#       --width 183 --height 80 --dpi 300

suppressPackageStartupMessages({
  library(ggplot2)
  library(data.table)
  library(yaml)
})

args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default) {
  i <- match(flag, args)
  if (is.na(i) || i == length(args)) default else args[i + 1]
}

data_dir <- get_arg("--data", "fixtures/selection-scan")
style_id <- get_arg("--style", "minimal-editorial")
preset_arg <- get_arg("--preset", "")
out_file <- get_arg("--out", "selection-scan.png")
width_mm <- as.numeric(get_arg("--width", "183"))
height_mm <- as.numeric(get_arg("--height", "80"))
dpi <- as.numeric(get_arg("--dpi", "300"))

preset_path <- if (nzchar(preset_arg)) preset_arg else
  file.path("templates/presets/selection-scan", paste0(style_id, ".yaml"))
if (!file.exists(preset_path)) stop("preset not found: ", preset_path)
st <- read_yaml(preset_path)

win <- fread(file.path(data_dir, "windows.tsv"))
reg <- fread(file.path(data_dir, "regions.tsv"))

win[, mid := (start + end) / 2]
win[, CHR := factor(chrom, levels = unique(chrom))]
chr_len <- win[, .(len = max(end)), by = CHR][order(CHR)]
chr_len[, offset := cumsum(as.numeric(len)) - as.numeric(len)]
win <- merge(win, chr_len[, .(CHR, offset)], by = "CHR", sort = FALSE)
win[, cum := mid + offset]
axis_dt <- chr_len[, .(CHR, center = offset + len / 2)]

long <- melt(win[, .(chrom, cum, fst, pi)], id.vars = c("chrom", "cum"),
             variable.name = "stat", value.name = "value")
long[, stat := factor(stat, levels = c("fst", "pi"))]

reg[, CHR := factor(chrom, levels = levels(win$CHR))]
reg <- merge(reg, chr_len[, .(CHR, offset)], by = "CHR", sort = FALSE)
reg[, `:=`(xmin = start + offset, xmax = end + offset)]

pal <- unlist(st$palette)
base_theme <- theme_classic(base_size = st$base_size, base_family = "Helvetica") +
  theme(
    axis.text = element_text(size = st$axis_text, colour = "#333333"),
    axis.title = element_text(size = st$base_size),
    strip.background = element_blank(),
    strip.text = element_text(size = st$base_size, hjust = 0),
    legend.position = "none",
    plot.margin = margin(2, 2, 1, 1)
  )
if (isTRUE(st$panel_border)) {
  base_theme <- base_theme + theme(panel.border = element_rect(colour = "#777777", fill = NA, linewidth = 0.3))
}
if (isTRUE(st$grid)) {
  base_theme <- base_theme + theme(panel.grid.major.y = element_line(colour = "#EFEFEF", linewidth = 0.2))
}

p <- ggplot(long, aes(cum, value, colour = stat)) +
  geom_rect(data = reg, aes(xmin = xmin, xmax = xmax, ymin = -Inf, ymax = Inf),
            fill = st$highlight, colour = NA, inherit.aes = FALSE) +
  geom_line(linewidth = st$line_width) +
  facet_wrap(~stat, ncol = 1, scales = "free_y",
             labeller = as_labeller(c(fst = "Fst", pi = "Nucleotide diversity (pi)"))) +
  scale_colour_manual(values = c(fst = pal[1], pi = pal[2])) +
  scale_x_continuous(breaks = axis_dt$center, labels = axis_dt$CHR, expand = c(0.01, 0)) +
  labs(x = NULL, y = NULL) +
  base_theme

if (!is.null(st$threshold_fst) && !is.na(st$threshold_fst)) {
  thr <- data.table(stat = factor("fst", levels = c("fst", "pi")), y = st$threshold_fst)
  p <- p + geom_hline(data = thr, aes(yintercept = y), linetype = "dashed",
                      linewidth = 0.25, colour = "#888888")
}

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
