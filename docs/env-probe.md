# 环境探测记录（2026-10-18）

建库前对本机与数据源做的实测，用于锁定依赖与导出链路。命令可复跑。

## 1. 运行时

| 项 | 结果 |
|---|---|
| macOS / R | R 4.5.2 (2025-10-31)，299 个包 |
| Python | 3.14.0（Homebrew Framework 路径） |
| R 绘图包在装 | ggplot2, circlize, ggtree, ComplexHeatmap, patchwork, ggpubr, scales, dplyr, data.table, ragg, showtext, sysfonts, gridGraphics |
| R 绘图包缺失 | **svglite**, pdftools, magick, CMplot, qqman, RIdeogram, karyoploteR |
| Python 在装 | matplotlib, seaborn, pandas, numpy, scipy |
| Python 缺失 | scanpy, pypdf, pikepdf；**PyMuPDF (fitz) 可用** |

## 2. 字体

- Arial 存在：`/System/Library/Fonts/Supplemental/Arial.ttf`；`systemfonts::match_font("Arial")` 能解析。
- Helvetica 存在：`/System/Library/Fonts/Helvetica.ttc`。
- matplotlib 能直接取到 Arial 与 Helvetica。

## 3. 导出链路实测（关键）

| 链路 | 结果 |
|---|---|
| R `cairo_pdf()` + Arial，183×60 mm | **失败**：`字体类别出错`（invalid font type） |
| R `cairo_pdf()` + Helvetica | 设备调用不报错，但**不产出文件** |
| R `pdf()`（base） | 出图正常；字体为 Type1 标准字体，不嵌入 TrueType |
| R `ragg::agg_png()` | 正常，183 mm / 300 dpi 输出 29 KB |
| R `svglite` | 已装入 `.Rlib`，SVG 出口正常 |
| Python matplotlib `savefig(pdf)` | **正常**：页面 518.74×170.08 pt（=183×60 mm），字体子集 `GOFYPY+ArialMT` 已嵌入 |

**结论**：本机 R 的 cairo PDF 通道不可用，matplotlib PDF 通道可用。

**2026-10-19 更新**：已改用 `grDevices::pdf()`（Type1 Helvetica，矢量、文字可编辑）导出 PDF；
并把 `svglite` 装进项目 `.Rlib`，`.svg` 出口可用（字体按名引用、文字可编辑）。cairo_pdf 不再使用。

## 4. 数据源探测（Europe PMC）

原始命中（宽主题词 OR，2023–2025，含非 OA）：

| 期刊 | 命中 |
|---|---|
| Nature Communications | 10,990 |
| Nature | 1,730 |
| Nature Genetics | 791 |
| Nature Microbiology | 432 |
| Nature Plants | 239 |
| Nature Ecology & Evolution | 180 |
| **合计** | **14,362** |

收窄后：
- NC + "code availability" + pangenome/population genomics/genome assembly = **565**
- 该查询取回的前 5 篇均带 PMCID，全文 XML 可抓（例：PMC12808307，Medicago 超级泛基因组，2025）。

## 5. 论文代码仓库抽样

| 仓库 | license | 内容 |
|---|---|---|
| `futurefanzhang/genomic-adaptation-of-autotetraploid-alfalfa` | **无** | `step1–step5` + `visualization/` |
| `baozg/Potato_C88` | **无** | `Snakefiles` + `script/` |

结论：Code availability 常见，但（a）多为分析流程而非绘图代码，（b）常无 license，不能直接复用。

## 6. 由探测得出的设计约束

1. 导出链路要在 M0.5 用 spike 锁定；候选：svglite(SVG) / ragg(PNG) / matplotlib(PDF)。
2. 字体策略：默认 Helvetica 或 Arial；R 端若 cairo 不可用，走 SVG + 系统字体引用。
3. QA 用 PyMuPDF 读页面尺寸与嵌入字体，不依赖 poppler（未安装）。
4. 代码层是「按范式重写」，不是搬运论文脚本（见 DESIGN.md §9）。
