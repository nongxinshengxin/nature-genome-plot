# M3/M4 进度：13 个图型模板（2026-10-21）

| # | archetype | 实现 | 预设 | 结构变体 |
|---|---|---|---|---|
| 1 | `assembly-qc` | 组装质量（BUSCO + NGx） | ggplot2 + patchwork | 3 | busco+ngx |
| 2 | `circos-landscape` | 环形基因组全景 / 弦图 | circlize | 6 | circular |
| 3 | `demography` | 群体历史（SFS / PSMC / LD 衰减） | ggplot2 + patchwork | 3 | triple_panel |
| 4 | `linear-tracks` | 线性基因组轨道（基因模型 + 多轨道） | ggplot2 + patchwork | 3 | stacked, mirrored |
| 5 | `manhattan-qq` | Manhattan + QQ | ggplot2 + patchwork + ggrepel | 3 | qq+manhattan, manhattan_only |
| 6 | `pangenome-composition` | 泛基因组构成（增长曲线 + core/accessory） | ggplot2 + patchwork | 3 | growth+stack |
| 7 | `phylogenomics` | 系统发育（树 + 性状热图） | ggtree + gheatmap | 3 | rectangular, circular |
| 8 | `population-structure` | 群体结构（PCA / ADMIXTURE） | ggplot2 + patchwork | 3 | pca+admixture, pca_only |
| 9 | `presence-absence` | 泛基因组存在缺失热图 | ComplexHeatmap | 3 | heatmap+annotations, heatmap+tree |
| 10 | `selection-scan` | 选择清除（Fst / π 轨道） | ggplot2 (facet) | 3 | two_tracks, composite |
| 11 | `sv-cnv` | 结构变异全景（密度 + 长度谱 + 频率） | ggplot2 + patchwork | 3 | genome-wide, locus |
| 12 | `synteny` | 共线性（dotplot / ribbon） | ggplot2 | 3 | dotplot |
| 13 | `binned-correlation` | 分位箱线相关图（多样性 × TE/基因密度） | ggplot2 + patchwork | 3 | stacked_panels |

- 预设总数：42 个 YAML（12 类 × 3，circos 6，binned-correlation 3）
- 冒烟测试：42/42 通过（2026-10-21）
- 数据契约：`catalog/archetypes/*.yaml`
- 已知问题见 `docs/todo.md`
