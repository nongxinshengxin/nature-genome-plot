# M2 图型覆盖报告（自动标注）

- 论文数：200；图数：1672；平均每篇 8.4 张图
- 至少被标注一次的图：797

| archetype | 覆盖论文数 | 覆盖图数 | 达标（≥10 篇） |
|---|---|---|---|
| circos-landscape | 25 | 32 | ✅ |
| linear-tracks | 25 | 38 | ✅ |
| synteny | 57 | 97 | ✅ |
| assembly-qc | 42 | 70 | ✅ |
| pangenome-composition | 62 | 156 | ✅ |
| presence-absence | 39 | 60 | ✅ |
| sv-cnv | 52 | 95 | ✅ |
| population-structure | 83 | 130 | ✅ |
| manhattan-qq | 65 | 111 | ✅ |
| selection-scan | 56 | 99 | ✅ |
| demography | 25 | 39 | ✅ |
| phylogenomics | 100 | 217 | ✅ |

## 分刊覆盖（论文数）

| 期刊 | circos-landscape | linear-tracks | synteny | assembly-qc | pangenome-composition | presence-absence | sv-cnv | population-structure | manhattan-qq | selection-scan | demography | phylogenomics |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Nature | 2 | 6 | 14 | 15 | 13 | 9 | 10 | 13 | 5 | 7 | 7 | 17 |
| Nature Genetics | 4 | 4 | 13 | 5 | 15 | 5 | 9 | 13 | 15 | 14 | 3 | 19 |
| Nature Plants | 3 | 3 | 7 | 2 | 0 | 1 | 1 | 5 | 2 | 3 | 2 | 5 |
| Nature Ecology & Evolution | 1 | 1 | 4 | 3 | 3 | 3 | 2 | 5 | 2 | 4 | 0 | 9 |
| Nature Microbiology | 1 | 0 | 0 | 4 | 2 | 3 | 1 | 7 | 3 | 1 | 3 | 12 |
| Nature Communications | 14 | 11 | 19 | 13 | 29 | 18 | 29 | 40 | 38 | 27 | 10 | 38 |

## 深读名单（80 篇）

- 覆盖：12 类图型每类 ≥9 篇（最少 circos 9，最多系统发育 42）
- 期刊：Nature 18、Nature Communications 30、Nature Genetics 11、Nature Ecology & Evolution 7、Nature Microbiology 7、Nature Plants 7
- 79 / 80 篇有代码可用性声明或仓库链接（筛选时优先，便于做 provenance）
- 共计 717 张图可与代码对照

## 口径

本轮已把词表收紧为「强指示词」，例如 `sv-cnv` 只认 structural variation / CNV，不再认 deletion/insertion 这类泛词；覆盖率因此更保守（circos 25 篇、群体结构 83 篇）。仍存在图注误匹配，深读阶段逐篇人工确认。

## 仓库审计（摘要）

55 个仓库中 50 个可克隆；26 个含 R 文件、29 个含 Python；25 个能识别到绘图库；21 个有 license。详见仓库审计记录。
