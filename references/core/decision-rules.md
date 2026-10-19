# 选型决策规则

## 从数据形状选图型

| 数据 | 首选 | 备选 |
|---|---|---|
| 基因型矩阵 → 群体分化 | population-structure | phylogenomics |
| GWAS 汇总统计 | manhattan-qq | selection-scan |
| 窗口统计（Fst/π） | selection-scan | manhattan-qq |
| 基因×基因组 0/1 | presence-absence | pangenome-composition |
| 计数增长曲线 | pangenome-composition | assembly-qc |
| 两物种坐标对 | synteny | circos-landscape（弦） |
| 组装指标 | assembly-qc | — |
| 树 + 性状矩阵 | phylogenomics | presence-absence |
| 区间 + 数值轨道 | linear-tracks | circos-landscape |
| SFS/PSMC/LD | demography | — |

## 硬约束

- 染色体/contig > 40：不用 circos，改 linear-tracks 或 manhattan-qq
- 样本 > 5000 且连续：PCA 加密度等高线，不用 UMAP 散点
- 泛基因组 > 300 基因组：presence–absence 必须聚类排序 + 抽样
- GWAS 无 lead SNP：不画 locuszoom，改区域窗
- Fst 窗口 < 10 kb：必须平滑
- 树 > 200 叶：circular 或折叠
- 只有 2 个群体：不做 admixture K 扫描，改 Fst 分布 + PCA

## 风格选择

- 主图：minimal-editorial
- 补充图/全基因组扫描：dense-diagnostic
- 汇报/预印本/低质量投影：high-contrast
- 单栏小图：mono-blue（circos）
