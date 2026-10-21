#!/usr/bin/env Rscript
# binned-correlation.R — decile boxplots of features along a diversity gradient
#
# Usage:
#   Rscript templates/R/binned-correlation.R --data fixtures/binned-correlation \
#       --style nature-decile --out out/binned-correlation/nature.png \
#       --width 75 --height 150 --dpi 300

suppressPackageStartupMessages({
  library(ggplot2)
  library(data.table)
  library(patchwork)
  library(yaml)
})

args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default) {
  i <- match(flag, args); if (is.na(i) || i == length(args)) default else args[i + 1]
}
data_dir <- get_arg("--data", "fixtures/binned-correlation")
style_id <- get_arg("--style", "nature-decile")
preset_arg <- get_arg("--preset", "")
out_file <- get_arg("--out", "binned-correlation.png")
width_mm <- as.numeric(get_arg("--width", "75"))
height_mm <- as.numeric(get_arg("--height", "150"))
dpi <- as.numeric(get_arg("--dpi", "300"))

preset_path <- if (nzchar(preset_arg)) preset_arg else
  file.path("templates/presets/binned-correlation", paste0(style_id, ".yaml"))
if (!file.exists(preset_path)) stop("preset not found: ", preset_path)
st <- read_yaml(preset_path)

dt <- fread(file.path(data_dir, "windows.tsv"))
xvar <- st$xvar
if (!xvar %in% names(dt)) stop("x column not found: ", xvar)

# decile bins on the diversity axis
q <- quantile(dt[[xvar]], probs = seq(0, 1, length.out = st$bins + 1), na.rm = TRUE)
dt[, bin := cut(get(xvar), breaks = q, include.lowest = TRUE, labels = FALSE)]
dt[, bin := as.numeric(bin)]

pal <- unlist(st$gradient)

theme_panel <- theme_classic(base_size = st$base_size, base_family = "Helvetica") +
  theme(
    axis.text.x = element_text(size = st$axis_text, colour = "black"),
    axis.text.y = element_text(size = st$axis_text, colour = "black"),
    axis.title = element_text(size = st$base_size),
    axis.ticks = element_line(linewidth = st$tick_lw, colour = "black"),
    axis.ticks.length = unit(1.6, "mm"),
    legend.position = "none",
    plot.margin = margin(2, 3, 1, 1)
  )
if (isTRUE(st$panel_border)) {
  theme_panel <- theme_panel +
    theme(panel.border = element_rect(colour = "black", fill = NA, linewidth = st$border_lw))
}

fmt_p <- function(p) {
  if (is.na(p)) return(NA)
  if (p < 2.2e-16) return("italic(P) < 2.2 %*% 10^-16")
  e <- floor(log10(p)); m <- p / 10^e
  sprintf("italic(P) == %.1f %%*%% 10^%d", m, e)
}

panels <- list()
tags <- letters[2:(length(st$features) + 1)]
for (i in seq_along(st$features)) {
  spec <- st$features[[i]]
  d <- dt[!is.na(get(spec$key))]
  ct <- suppressWarnings(cor.test(d[[xvar]], d[[spec$key]], method = "spearman", exact = FALSE))
  rho <- unname(ct$estimate)
  d[, value := get(spec$key)]
  ymin <- min(d$value, na.rm = TRUE)
  ymax <- max(d$value, na.rm = TRUE)
  ytop <- ymax + (ymax - ymin) * 0.28

  p <- ggplot(d, aes(x = bin, y = value, group = bin, fill = bin)) +
    geom_boxplot(width = st$box_width, outlier.shape = NA,
                 colour = st$outline, linewidth = st$box_lw) +
    scale_fill_gradientn(colours = pal, guide = "none") +
    scale_x_continuous(breaks = seq_len(st$bins), labels = paste0(seq(10, 100, length.out = st$bins), "%"),
                       expand = expansion(mult = c(0.02, 0.02))) +
    scale_y_continuous(limits = c(ymin - (ymax - ymin) * 0.02, ytop), expand = c(0, 0)) +
    labs(x = NULL, y = spec$label) +
    coord_cartesian(clip = "off") +
    theme_panel +
    annotate("text", x = 0.28, y = ytop, label = tags[i], hjust = 0, vjust = 1.1,
             size = st$letter_size / .pt, fontface = st$letter_face) +
    annotate("text", x = 1.05, y = ytop, hjust = 0, vjust = 1.1,
             label = sprintf("rho = %.4f", rho),
             size = st$rho_size / .pt, fontface = "bold") +
    annotate("text", x = 1.05, y = ytop - (ymax - ymin) * 0.10, hjust = 0, vjust = 1.1,
             label = fmt_p(ct$p.value), parse = TRUE,
             size = st$rho_size / .pt, fontface = "bold")

  if (i < length(st$features)) {
    p <- p + theme(axis.text.x = element_blank(), axis.ticks.x = element_blank())
  } else {
    p <- p + labs(x = st$x_label) +
      theme(axis.text.x = element_text(size = st$axis_text, angle = 45, hjust = 1, vjust = 1))
  }
  panels[[i]] <- p
}

# custom colour bar above the panels
leg_dt <- data.table(x = seq(0, 1, length.out = 200))
leg <- ggplot(leg_dt, aes(x = x, y = 1, fill = x)) +
  geom_raster() +
  scale_fill_gradientn(colours = pal, guide = "none") +
  scale_x_continuous(expand = c(0, 0), breaks = c(0, 1), labels = c("0.0", "1.0"),
                     position = "top") +
  scale_y_continuous(expand = c(0, 0)) +
  labs(title = st$legend_title) +
  theme_void(base_size = st$base_size, base_family = "Helvetica") +
  theme(
    plot.title = element_text(size = st$base_size, hjust = 0, margin = margin(b = 1)),
    axis.text.x = element_text(size = st$axis_text, vjust = 1),
    axis.ticks.x = element_line(linewidth = 0.3),
    axis.ticks.length = unit(1, "mm"),
    plot.margin = margin(0, 3, 0, 1)
  )

body <- wrap_plots(panels, ncol = 1) &
  theme(plot.margin = margin(2, 3, 1, 5))

p <- leg / body + plot_layout(heights = c(st$legend_h, length(panels)))

if (grepl("\\.svg$", out_file, ignore.case = TRUE)) {
  if (!requireNamespace("svglite", quietly = TRUE)) stop("SVG export needs svglite")
  ggsave(out_file, p, width = width_mm, height = height_mm, units = "mm", device = svglite::svglite)
} else if (grepl("\\.pdf$", out_file, ignore.case = TRUE)) {
  ggsave(out_file, p, width = width_mm, height = height_mm, units = "mm", device = "pdf")
} else {
  ggsave(out_file, p, width = width_mm, height = height_mm, units = "mm", dpi = dpi, device = ragg::agg_png)
}
cat("wrote", out_file, "with preset", basename(preset_path), "\n")
