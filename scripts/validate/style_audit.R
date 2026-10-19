#!/usr/bin/env Rscript
# style_audit.R — check palettes for CVD separation and font-size compliance
#
# Usage: Rscript scripts/validate/style_audit.R

suppressPackageStartupMessages({
  library(yaml)
  library(colorspace)
})

min_dE <- function(cols) {
  if (length(unique(cols)) < 2) return(NA_real_)
  lab <- as(hex2RGB(cols), "LAB")@coords
  d <- as.matrix(dist(lab))
  diag(d) <- Inf
  min(d)
}

get_pal <- function(p) {
  for (k in c("palette", "chrom_cols", "palette_cat", "group_colors", "cat_colors", "lab_palette")) {
    if (!is.null(p[[k]])) return(as.character(unlist(p[[k]])))
  }
  NULL
}

idx <- yaml::read_yaml("catalog/index.yaml")
rows <- list()
for (a in idx$archetypes) {
  for (preset in a$presets) {
    p <- yaml::read_yaml(file.path("templates/presets", a$id, paste0(preset, ".yaml")))
    pal <- get_pal(p)
    base <- as.numeric(p$base_size %||% 7)
    if (is.null(pal) || length(pal) < 2) {
      rows[[length(rows) + 1]] <- data.frame(archetype = a$id, preset = preset, n_col = length(pal),
        dE = NA, dE_deutan = NA, dE_protan = NA, font = base, flag = "single/continuous palette")
      next
    }
    d0 <- min_dE(pal); dd <- min_dE(deutan(pal)); dp <- min_dE(protan(pal))
    flags <- character()
    if (!is.na(dd) && dd < 10) flags <- c(flags, "deutan<10")
    if (!is.na(dp) && dp < 10) flags <- c(flags, "protan<10")
    if (base > 7) flags <- c(flags, "font>7pt")
    rows[[length(rows) + 1]] <- data.frame(archetype = a$id, preset = preset, n_col = length(pal),
      dE = round(d0, 1), dE_deutan = round(dd, 1), dE_protan = round(dp, 1), font = base,
      flag = if (length(flags)) paste(flags, collapse = ",") else "ok")
  }
}
tab <- do.call(rbind, rows)
write.csv(tab, "docs/style-audit.csv", row.names = FALSE)

lines <- c("# 风格审计", "",
  sprintf("- 组合：%d；标记问题：%d", nrow(tab), sum(tab$flag != "ok")), "",
  "| archetype | preset | 色数 | ΔE | deutan | protan | 字号 | 标记 |",
  "|---|---|---|---|---|---|---|---|")
for (i in seq_len(nrow(tab))) {
  r <- tab[i, ]
  lines <- c(lines, sprintf("| %s | %s | %d | %s | %s | %s | %.1f | %s |",
    r$archetype, r$preset, r$n_col, r$dE, r$dE_deutan, r$dE_protan, r$font, r$flag))
}
writeLines(lines, "docs/style-audit.md")

bad <- tab[tab$flag != "ok" & tab$flag != "single/continuous palette", ]
if (nrow(bad)) {
  cat("flagged:\n"); print(bad[, c("archetype", "preset", "flag")], row.names = FALSE)
} else {
  cat("all palettes pass (ΔE >= 10 under deutan/protan; font <= 7pt)\n")
}
