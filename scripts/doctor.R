#!/usr/bin/env Rscript
# doctor.R — environment check with plain-language fixes
#
# Usage:
#   Rscript scripts/doctor.R            # check only
#   Rscript scripts/doctor.R --install  # install missing R deps, print pip command

args <- commandArgs(trailingOnly = TRUE)
do_install <- "--install" %in% args

cran <- c("ggplot2", "data.table", "patchwork", "yaml", "circlize",
          "ggrepel", "scales", "ragg", "svglite", "colorspace")
bioc <- c("ComplexHeatmap", "ggtree", "treeio")
py <- c("pandas", "yaml", "PIL")

ok <- TRUE
line <- function(...) cat(..., "\n", sep = "")

line("== R ==")
line("  版本: ", R.version.string,
     if (getRversion() >= "4.4.0") "  [ok]" else "  [警告: 建议 >= 4.4]")

libs <- .libPaths()
if (dir.exists(".Rlib")) libs <- c(normalizePath(".Rlib"), libs)
inst <- rownames(installed.packages(lib.loc = libs))
miss_cran <- setdiff(cran, inst)
miss_bioc <- setdiff(bioc, inst)
line("  CRAN 缺失: ", if (length(miss_cran)) paste(miss_cran, collapse = ", ") else "无",
     if (dir.exists(".Rlib")) "  (含项目内 .Rlib)" else "")
line("  Bioc 缺失: ", if (length(miss_bioc)) paste(miss_bioc, collapse = ", ") else "无")
if (length(miss_cran) || length(miss_bioc)) ok <- FALSE

line("")
line("== 字体 ==")
fonts <- tryCatch(systemfonts::system_fonts()$family, error = function(e) character())
has_helv <- any(grepl("^Helvetica$", fonts))
has_arial <- any(grepl("^Arial$", fonts))
line("  Helvetica: ", if (has_helv) "有" else "无",
     " | Arial: ", if (has_arial) "有" else "无",
     if (has_helv || has_arial) "  [ok]" else "  [警告: 至少装一个]")
if (!has_helv && !has_arial) ok <- FALSE

line("")
line("== Python ==")
py_bin <- Sys.which("python3")
if (!nzchar(py_bin)) {
  line("  python3: 未找到  [警告: 校验脚本需要]")
  ok <- FALSE
} else {
  out <- suppressWarnings(system2(py_bin, c("-c",
    shQuote(sprintf("import importlib.util as u; print(','.join(m for m in %s if u.find_spec(m) is None))",
                   deparse(py)))) , stdout = TRUE, stderr = FALSE))
  miss_py <- if (length(out) && nzchar(out[1])) strsplit(out[1], ",")[[1]] else character()
  line("  python3: ", py_bin)
  line("  缺失模块: ", if (length(miss_py)) paste(miss_py, collapse = ", ") else "无")
  if (length(miss_py)) ok <- FALSE
}

line("")
if (isTRUE(ok)) {
  line("环境就绪。可以开始出图。")
  quit(status = 0)
}

line("== 修复 ==")
if (do_install) {
  line("正在安装缺失的 R 包 ...")
  sys <- file.path("scripts", "install_deps.R")
  if (file.exists(sys)) {
    system2("Rscript", sys)
  } else {
    line("找不到 scripts/install_deps.R")
  }
} else {
  line("  安装 R 依赖: Rscript scripts/install_deps.R")
  if (exists("miss_py") && length(miss_py)) {
    line("  安装 Python 依赖: pip install ", paste(c("pandas", "pyyaml", "pillow"), collapse = " "))
  }
  line("  或让我来装: Rscript scripts/doctor.R --install")
}
quit(status = if (isTRUE(do_install)) 0 else 1)
