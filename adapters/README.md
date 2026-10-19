# 适配器

把常见基因组格式转成模板需要的 tidy 表。全部为纯 R 实现，不依赖 bcftools/plink。

## vcf2sv.R → `sv-cnv` 契约

```bash
Rscript adapters/vcf2sv.R --vcf in.vcf --out sv.tsv
```

- 支持 `<DEL> <INS> <INV> <DUP> <CNV>`（CNV 归入 DUP）
- 长度优先取 SVLEN，其次 END-POS
- 频率优先取 INFO/AF，缺失时用 GT 估算
- 输出：chrom, start, end, type, length, af

## gff2genes.R → `linear-tracks` 契约

```bash
Rscript adapters/gff2genes.R --gff in.gff3 --out genes.tsv --feature gene
```

- 名称依次取 Name → ID → 自动编号
- 输出：chrom, start, end, strand, name

## paf2synteny.R → `synteny` 契约

```bash
Rscript adapters/paf2synteny.R --paf aln.paf --out-dir data/synteny
```

- 过滤 < 5 kb 的比对
- 同时写出 `qchrom.tsv`、`tchrom.tsv`、`blocks.tsv`
- 负链记为 strand = -1

## 待补

- `plink2pca.R`（bed/bim/fam → PCA 坐标；本机无 plink2）
- `bigwig2track.R`（需要 rtracklayer，未装）
