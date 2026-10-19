# WF2 适配用户数据

## 1. 诊断
先跑最小检查（列名、类型、缺失、染色体命名、取值范围、重复键），产出 `data-profile.md`。

## 2. 映射
```bash
python3 scripts/profile/infer_archetype.py --data <file>
Rscript scripts/profile/map_data.R --data <file> --map map.yaml --out mapped.tsv
```
`map.yaml` 支持 rename / constants / drop / chr_prefix / drop_na。
- 一对一：直接改名
- 一对多：拆分（如 `pos` → `start/end`）
- 多对一：合并（如多列 K → 长表）

## 3. 格式转换
| 输入 | 输出 | 工具 |
|---|---|---|
| VCF | sv.tsv | `Rscript adapters/vcf2sv.R --vcf in.vcf --out sv.tsv` |
| GFF3/GTF | genes.tsv | `Rscript adapters/gff2genes.R --gff in.gff3 --out genes.tsv` |
| PLINK bed | PCA 坐标 | 待补（先用 plink2 出 eigenvec） |
| bigwig | 窗口均值 | 待补（先用 bedtools makewindows + map） |
| PAF | blocks.tsv + 染色体长度 | `Rscript adapters/paf2synteny.R --paf in.paf --out-dir data/synteny` |

已实现的两个适配器见 `adapters/README.md`；未实现的给等价命令，不静默降级。

## 4. 回到 WF1
数据落成 tidy 后，按 WF1 第 4–6 步执行。
