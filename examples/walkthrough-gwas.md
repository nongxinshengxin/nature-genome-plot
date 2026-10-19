# 案例：一份脏 GWAS 表 → Manhattan 图

输入：`examples/messy-gwas.csv`（4001 行 × 7 列，模拟真实投稿数据）

## 1. 诊断

```bash
Rscript scripts/profile/profile_data.R --data examples/messy-gwas.csv --out examples/messy-profile.md
```

报出 3 个问题：

- 染色体命名混用 `chr1` 与 `1`
- `p_value` 有 41 个 0（`-log10` 会变 Inf）
- `note` 列 99.98% 缺失（无关列，忽略）

## 2. 映射

```bash
Rscript examples/clean-gwas.R   # chromosome/position/p_value → CHR/BP/P
```

只做重命名与 chr 前缀统一；`P = 0` 原样保留，交给模板处理。

## 3. 渲染

```bash
Rscript templates/R/manhattan-qq.R --data examples/gwas-clean \
  --style minimal-editorial --out examples/walkthrough-gwas.png \
  --width 183 --height 70
```

模板做两件事并打印日志：

- 丢弃 `P < 1e-50` 的 41 条记录（钳到下限会在顶部形成假天花板）
- 染色体按数字自然排序（首版按出现顺序，已修）

## 4. 结果

`examples/walkthrough-gwas.png`：QQ + Manhattan，阈值线、5 个 lead SNP 标注，y 轴 0–12.5。

## 5. 这次 dogfood 抓到的真问题

1. **染色体顺序**：模板原来按出现顺序排，脏数据一切换顺序就乱；已改为按数字排序。
2. **p = 0**：钳到 1e-300 会让 y 轴到 300、整张图压扁；现在按下限丢弃并提示。
3. **profile 先行的价值**：三个问题里有两个在渲染前就能发现。
