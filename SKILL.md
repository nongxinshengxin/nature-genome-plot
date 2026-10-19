---
name: nature-genome-plot
description: >-
  Turn genome, pangenome and population-genomics results into Nature-grade figures.
  Ships 12 figure archetypes (circos/chord, linear tracks, synteny, assembly QC,
  pangenome composition, presence-absence, SV/CNV, population structure, Manhattan/QQ,
  selection scan, demography, phylogenomics), 39 style presets, runnable R templates,
  data contracts and fixtures, distilled from 200 open-access 2023-2026 papers in
  Nature, Nature Genetics, Nature Plants, Nature Ecology & Evolution, Nature Microbiology
  and Nature Communications. Also restyles, adapts and audits existing figures against
  Nature artwork specifications.
  Use for 基因组图、泛基因组图、弦图、circos、共线性、群体结构、PCA、admixture、
  曼哈顿图、QQ 图、选择清除、群体历史、组装质控、系统发育图、存在缺失热图、SV/CNV、
  Nature 风格绘图、投稿图合规检查、改图、配色与字号调整.
---

# nature-genome-plot — Router

12 个图型、39 个预设，全部可运行。**绘图脚本只出 R 或 Python，默认 R。**

## 1. 判定工作流

| 工作流 | 触发 | 读 |
|---|---|---|
| new-figure | 有数据，要出图 | `references/workflows/wf1-new-figure.md` |
| adapt-data | 数据格式不规范 | `wf2-adapt-data.md` |
| restyle | 已有图/脚本要换风格 | `wf3-restyle.md` |
| audit | 只做合规检查 | `wf4-audit.md` |
| browse | 无数据，问能画什么 | `wf5-browse.md` |

## 2. 加载顺序（渐进披露）

1. 读 `catalog/index.yaml`（12 行摘要），按意图 + 数据签名匹配 `id`。
2. 匹配不到：读 `references/core/decision-rules.md` 取最近邻，并**告诉用户这是最近邻**。
3. 读 `catalog/archetypes/<id>.yaml`：输入契约、结构、规则。
4. 读 1–3 张 `catalog/styles/<id>.<preset>.yaml`：看证据与适用场景。
5. 需要时读 `references/core/journal-specs.md`（尺寸/字号/格式/色盲）。
6. 模板路径在 style card 的 `template` 字段，**不要**先读模板再定图型。

## 3. 数据先落地

```bash
python3 scripts/profile/infer_archetype.py --data <file-or-dir>   # 猜图型 + 缺哪列
Rscript scripts/profile/profile_data.R --data <file> --out profile.md  # 列/缺失/命名/异常
Rscript scripts/profile/map_data.R --data <file> --map map.yaml --out mapped.tsv
```

`map.yaml` 用 `rename/constants/drop/chr_prefix/drop_na` 把用户列名映射到契约。
映射失败时报告「哪个源列不存在」，不要猜。

## 4. 环境自检与安装

任何命令报「没有叫 X 的包 / No module named X」时，先跑：

```bash
Rscript scripts/doctor.R
```

它会检查 R 版本、CRAN/Bioconductor 包、Helvetica/Arial 字体、Python 模块，并用大白话给出修复方案。

**替用户装依赖的规矩**：

1. 先说清楚缺什么、要装什么、大概多大、要不要写系统目录
2. 用户说「装」再执行 `Rscript scripts/doctor.R --install`，或逐条给命令让用户自己跑
3. 装完重跑原命令，确认真的能出图；不要假装成功
4. 权限不足、网络不通时，给离线方案（conda/renv/容器），不要反复重试

## 5. 渲染

```bash
Rscript templates/R/<id>.R --data <dir> --style <preset> \
  --out out/<slug>/<id>.<preset>.png --width 183 --height <h> --dpi 300
```

- 同一数据渲 2 个预设给用户对比
- 尺寸默认：单栏 89 mm、双栏 183 mm、主图高 ≤170 mm
- 每轮说明「改了什么、为什么」

## 6. 12 个图型

circos/弦图（6 风格）、线性轨道、共线性、组装质控、泛基因组构成、存在缺失、
SV/CNV、群体结构、Manhattan/QQ、选择清除、群体历史、系统发育。

风格族：`minimal-editorial`（主图）、`dense-diagnostic`（补充图）、`high-contrast`（汇报）；
circos 另有 `soft-pastel`、`mono-blue`、`warm-editorial`。

**可及性**：每张风格卡带 `submission_safe` 与 CVD 色差数值（`docs/style-audit.md`）。
`minimal-editorial` 与 `dense-diagnostic` 已过色盲检查；`high-contrast` 是 8 pt 幻灯片专用，
`soft-pastel` / `warm-editorial` 为装饰用，投稿前应换回安全组。

**数据适配**：`adapters/` 提供 VCF→SV、GFF→基因、PAF→共线性、PLINK eigenvec→PCA、
bedGraph/bigWig→轨道；缺失格式给等价命令，不静默降级。

## 7. 硬规则

1. 不复制论文图、不搬运第三方代码；措辞用 inspired by，不用 reproduced from。
2. 绘图脚本只写 R（默认）或 Python；不交 shell/perl/JS/matlab 绘图脚本。
3. 不静默处理数据：不丢行、不降采样、不改数值。
4. 主图不交 PNG：Nature 主图要矢量、文字可编辑。
5. 不编造风格依据：style card 的证据可回指 DOI + 图号；没有就说没有。
6. 没验证过的输出标 `unverified`。

## 8. 交付包

```
out/<slug>/
├── fig.png / fig.pdf
├── plot.R（或 plot.py）
├── figure-spec.yaml
├── data-profile.md
├── qa-report.md
└── README-run.md
```

## 9. 失败与降级

| 情况 | 处理 |
|---|---|
| 图型未收录 | 最近邻 + `unverified`，不虚构 |
| R 包缺失 | 跑 `scripts/doctor.R`，按 §4 说明后安装；不假装跑过 |
| 列不匹配 | 2–3 种映射让用户选 |
| 渲染溢出 | 先调字号/边距/repel，再换结构 |
| PDF 导不出 | 先出 PNG/SVG；PDF 走 `pdf()`，字体未嵌入需说明 |

## 10. 扩展模板 / 风格

用户给新图或新风格时，按 `docs/EXTENDING.md` 走：

```bash
python3 scripts/extend/new_style.py <archetype> <style-id>      # 加风格
python3 scripts/extend/new_archetype.py <id>                    # 加图型
python3 scripts/extend/status.py                                # 当前状态
```

规矩：一次只加一个；证据不足保持 `draft`；加完必须过 `catalog_check` 与 `smoke`。

## 11. 边界

图注/正文写作 → `nature-writing`；文献检索 → `nature-academic-search`。
本 skill 只负责「数据 → 图 + 可运行代码 + 合规检查」。
