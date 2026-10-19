#!/usr/bin/env Rscript
# profile_data.R — diagnose a table before plotting
#
# Usage:
#   Rscript scripts/profile/profile_data.R --data in.tsv --out out/data-profile.md

suppressPackageStartupMessages({
  library(data.table)
  library(jsonlite)
})

args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default) {
  i <- match(flag, args); if (is.na(i) || i == length(args)) default else args[i + 1]
}
in_file <- get_arg("--data", "")
out_file <- get_arg("--out", "data-profile.md")
if (!nzchar(in_file) || !file.exists(in_file)) stop("input not found: ", in_file)

sep <- if (grepl("\\.csv$", in_file, ignore.case = TRUE)) "," else "\t"
dt <- fread(in_file, sep = sep, na.strings = c("", "NA", "NaN", "null", "."))

n <- nrow(dt); p <- ncol(dt)
issues <- character()

prof <- data.table(column = names(dt), type = vapply(dt, function(x) class(x)[1], character(1)),
                   n_missing = vapply(dt, function(x) sum(is.na(x)), integer(1)))
prof[, pct_missing := round(100 * n_missing / n, 2)]

# numeric ranges
num_ranges <- list()
for (nm in names(dt)) {
  if (is.numeric(dt[[nm]])) {
    num_ranges[[nm]] <- c(min(dt[[nm]], na.rm = TRUE), max(dt[[nm]], na.rm = TRUE))
  }
}

# chromosome-like column
chr_col <- names(dt)[vapply(dt, function(x) {
  is.character(x) && mean(grepl("^(chr)?[0-9XYM]+$", x), na.rm = TRUE) > 0.8
}, logical(1))]
chr_note <- "未检出染色体列"
if (length(chr_col)) {
  vals <- unique(dt[[chr_col[1]]])
  has_chr <- grepl("^chr", vals)
  chr_note <- sprintf("列 `%s`：%d 个取值；带 chr 前缀 %d 个，不带 %d 个",
                      chr_col[1], length(vals), sum(has_chr), sum(!has_chr))
  if (any(has_chr) && any(!has_chr)) issues <- c(issues, "染色体命名混用 chr1 与 1，必须先统一")
}

# p-value sanity
p_col <- names(dt)[vapply(dt, function(x) is.numeric(x) && all(x[!is.na(x)] >= 0 & x[!is.na(x)] <= 1) && any(x[!is.na(x)] < 1e-3), logical(1))]
if (length(p_col)) {
  bad0 <- sum(dt[[p_col[1]]] == 0, na.rm = TRUE)
  if (bad0 > 0) issues <- c(issues, sprintf("列 `%s` 有 %d 个 0，log10 会变 Inf，需截断", p_col[1], bad0))
}

# duplicates
dup_keys <- 0
if (length(chr_col) && any(grepl("pos|start|bp", names(dt), ignore.case = TRUE))) {
  pos_col <- names(dt)[grepl("pos|start|bp", names(dt), ignore.case = TRUE)][1]
  dup_keys <- sum(duplicated(dt[, c(chr_col[1], pos_col), with = FALSE]))
  if (dup_keys > 0) issues <- c(issues, sprintf("染色体+位置有 %d 个重复键", dup_keys))
}

if (any(prof$pct_missing > 20)) {
  issues <- c(issues, paste0("高缺失列：", paste(prof[pct_missing > 20, column], collapse = ", ")))
}
if (n < 10) issues <- c(issues, "样本行数 < 10，图形可能没有统计意义")

lines <- c(
  "# 数据诊断", "",
  sprintf("- 文件：`%s`", basename(in_file)),
  sprintf("- 规模：%d 行 × %d 列", n, p),
  sprintf("- 染色体：%s", chr_note),
  sprintf("- 重复键：%d", dup_keys), "",
  "## 列概览", "",
  "| 列 | 类型 | 缺失 | 缺失率 | 范围 |", "|---|---|---|---|---|"
)
for (i in seq_len(nrow(prof))) {
  nm <- prof$column[i]
  rng <- if (!is.null(num_ranges[[nm]])) sprintf("%.3g ~ %.3g", num_ranges[[nm]][1], num_ranges[[nm]][2]) else ""
  lines <- c(lines, sprintf("| %s | %s | %d | %.2f%% | %s |", nm, prof$type[i], prof$n_missing[i], prof$pct_missing[i], rng))
}
lines <- c(lines, "", "## 问题", "")
lines <- c(lines, if (length(issues)) paste0("- ", issues) else "- 未发现阻塞性问题")
lines <- c(lines, "", "## 建议", "",
  if (length(chr_col)) sprintf("- 以 `%s` 为染色体列%s", chr_col[1], if (any(grepl("^chr", dt[[chr_col[1]]]))) "，注意 chr 前缀" else "") else "- 需指定染色体列",
  if (length(p_col)) sprintf("- p 值列 `%s` 取 -log10 前先截断到 1e-300", p_col[1]) else "- 未识别到 p 值列")

writeLines(lines, out_file)
jsonlite::write_json(list(rows = n, cols = p, issues = issues,
                          columns = prof, chr_column = chr_col,
                          p_column = p_col, duplicate_keys = dup_keys),
                     sub("\\.md$", ".json", out_file), pretty = TRUE, auto_unbox = TRUE)
cat("wrote", out_file, "\n")
