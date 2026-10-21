#!/usr/bin/env Rscript
# manhattan-qq.R — Manhattan plot + QQ plot
#
# Usage:
#   Rscript templates/R/manhattan-qq.R --data fixtures/manhattan-qq \
#       --style minimal-editorial --out out/manhattan-qq/minimal.png \
#       --width 183 --height 70 --dpi 300

suppressPackageStartupMessages({
  library(ggplot2)
  library(data.table)
  library(patchwork)
  library(yaml)
  library(ggrepel)
})

args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default) {
  i <- match(flag, args)
  if (is.na(i) || i == length(args)) default else args[i + 1]
}

data_dir <- get_arg("--data", "fixtures/manhattan-qq")
style_id <- get_arg("--style", "minimal-editorial")
preset_arg <- get_arg("--preset", "")
out_file <- get_arg("--out", "manhattan.png")
width_mm <- as.numeric(get_arg("--width", "183"))
height_mm <- as.numeric(get_arg("--height", "70"))
dpi <- as.numeric(get_arg("--dpi", "300"))

preset_path <- if (nzchar(preset_arg)) preset_arg else
  file.path("templates/presets/manhattan-qq", paste0(style_id, ".yaml"))
if (!file.exists(preset_path)) stop("preset not found: ", preset_path)
st <- read_yaml(preset_path)

FONT <- if (grepl("\\.pdf$", out_file, ignore.case = TRUE)) "Helvetica" else
  if (!is.null(st$font)) st$font else "Arial"
if (grepl("\\.pdf$", out_file, ignore.case = TRUE)) {
  message("PDF device cannot embed Arial here; falling back to Helvetica. Export SVG for Arial.")
}


gwas <- fread(file.path(data_dir, "gwas.tsv"))
setnames(gwas, toupper(names(gwas)))
gwas <- gwas[!is.na(P) & P <= 1]
# p == 0 or absurdly small values break -log10; clip at p_floor and report it
p_floor <- if (is.null(st$p_floor)) 1e-50 else as.numeric(st$p_floor)
n_drop <- sum(gwas$P < p_floor, na.rm = TRUE)
if (n_drop > 0) {
  message(sprintf("dropped %d p-values below %g (cannot be drawn as -log10)", n_drop, p_floor))
  gwas <- gwas[P >= p_floor]
}
gwas <- gwas[P > 0]

# natural chromosome order: 1,2,...,10,X,Y,MT
chr_levels <- unique(as.character(gwas$CHR))
chr_num <- suppressWarnings(as.integer(gsub("[^0-9]", "", chr_levels)))
chr_levels <- chr_levels[order(ifelse(is.na(chr_num), 1e9, chr_num), chr_levels)]
gwas[, CHR := factor(CHR, levels = chr_levels)]
gwas[, logp := -log10(P)]

# cumulative coordinates
chr_len <- gwas[, .(len = max(BP)), by = CHR][order(CHR)]
chr_len[, offset := cumsum(as.numeric(len)) - as.numeric(len)]
gwas <- merge(gwas, chr_len[, .(CHR, offset, len)], by = "CHR", sort = FALSE)
gwas[, cum := BP + offset]
gwas[, CHR := factor(CHR, levels = levels(chr_len$CHR))]
axis_dt <- chr_len[, .(CHR, center = offset + len / 2, len)]

pal <- unlist(st$palette)
chr_levels <- levels(gwas$CHR)
gwas[, col_group := as.integer(CHR) %% 2]

lead <- gwas[order(P)][1:min(st$top_labels, nrow(gwas))]
lead <- lead[P < 0.01]

base_theme <- theme_classic(base_size = st$base_size, base_family = FONT) +
  theme(
    axis.text = element_text(size = st$axis_text, colour = "#333333"),
    axis.title = element_text(size = st$base_size),
    plot.margin = margin(2, 2, 1, 1),
    legend.position = "none"
  )
if (isTRUE(st$grid)) {
  base_theme <- base_theme + theme(panel.grid.major.y = element_line(colour = "#ECECEC", linewidth = 0.25))
}

p_man <- ggplot(gwas, aes(cum, logp)) +
  geom_point(aes(colour = factor(col_group)), size = st$point_size, alpha = st$point_alpha, stroke = 0) +
  geom_hline(yintercept = -log10(st$threshold), linetype = "dashed",
             linewidth = 0.3, colour = st$threshold_color) +
  scale_colour_manual(values = c("0" = pal[1], "1" = pal[2])) +
  scale_x_continuous(breaks = axis_dt$center, labels = axis_dt$CHR, expand = c(0.01, 0)) +
  labs(x = NULL, y = expression(-log[10](italic(P)))) +
  base_theme

if (nrow(lead)) {
  p_man <- p_man + geom_point(data = lead, colour = st$lead_color, size = st$point_size * 2.2, stroke = 0) +
    geom_text_repel(data = lead, aes(label = paste0(CHR, ":", BP)),
                    size = st$axis_text / .pt, colour = st$lead_color,
                    min.segment.length = 0, segment.size = 0.2,
                    nudge_y = 0.8, max.overlaps = 20)
}

# QQ
qq <- gwas[order(P)]
qq[, expected := -log10(ppoints(.N))]
p_qq <- ggplot(qq, aes(expected, logp)) +
  geom_abline(slope = 1, intercept = 0, linewidth = 0.25, colour = "#999999") +
  geom_point(size = st$qq_point_size, colour = pal[1], alpha = 0.8, stroke = 0) +
  labs(x = expression(Expected~~-log[10](italic(P))), y = expression(Observed~~-log[10](italic(P)))) +
  base_theme +
  theme(plot.margin = margin(2, 4, 1, 1))

p <- p_qq + p_man + plot_layout(widths = c(1, 3.2))

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
