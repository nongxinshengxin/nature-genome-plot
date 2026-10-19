# M1 报告：200 篇开放获取语料（2026-10-18）

## 方法

1. `scripts/harvest/epmc_harvest.py`：Europe PMC REST，六刊 × 四个年份分别检索（OA + 主题词 + Article），按相关度打分（标题强主题词、摘要命中、引用数、新近度），每刊按年份配额截取。
2. `scripts/harvest/extract_code.py`：对 200 个 PMCID 并发抓取全文 XML，抽取 Code/Data availability 段落、仓库链接、绘图库提及、图数量。

## 语料构成

| 期刊 | 数量 | 2023 | 2024 | 2025 | 2026 |
|---|---|---|---|---|---|
| Nature Communications | 90 | 23 | 23 | 22 | 22 |
| Nature | 30 | 8 | 8 | 7 | 7 |
| Nature Genetics | 30 | 8 | 8 | 7 | 7 |
| Nature Microbiology | 20 | 5 | 5 | 5 | 5 |
| Nature Plants | 15 | 4 | 4 | 4 | 3 |
| Nature Ecology & Evolution | 15 | 4 | 4 | 4 | 3 |
| **合计** | **200** | 52 | 52 | 49 | 47 |

## 代码可得性

| 指标 | 数量 |
|---|---|
| 全文抓取成功 | 200 / 200 |
| 有 Code availability 段落 | 78 |
| 给出仓库链接 | 92（GitHub 57、Figshare 8、Zenodo 5） |
| 同时有 Code 段落 + GitHub | 57 |
| 图数量中位数 / 均值 / 最大 | 6 / 8.4 / 17 |

## 绘图库提及（全文中出现，含方法/引用）

ggplot2 56、pheatmap 17、ggtree 15、RIdeogram 8、ggpubr 7、seaborn 7、circlize 7、karyoploteR 5、matplotlib 4、CMplot 4、ComplexHeatmap 3。

R 生态占绝对主导，支持「R 为主、Python 补位」的决策。

## 已知偏差

- 检索按相关度排序取前 100/年/刊，非穷举；NC 占比 45%（配额所致）。
- 「有仓库链接」≠「有可运行绘图代码」；T1/T2 判定需在 M2 打开仓库逐个核。
- plot_libs 为全文关键词命中，含引用文献里的提及，只能当趋势信号。

## 下一步（M2）

1. 解析 figure legends → 每篇的图清单与图型标签
2. 12 个 archetype 的覆盖度盘点，缺口回补
3. 70–90 篇深读：仓库树、绘图文件、license
