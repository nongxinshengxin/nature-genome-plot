# 数据诊断

- 文件：`messy-gwas.csv`
- 规模：4001 行 × 7 列
- 染色体：列 `chromosome`：10 个取值；带 chr 前缀 5 个，不带 5 个
- 重复键：0

## 列概览

| 列 | 类型 | 缺失 | 缺失率 | 范围 |
|---|---|---|---|---|
| SNP | character | 0 | 0.00% |  |
| chromosome | character | 0 | 0.00% |  |
| position | integer | 0 | 0.00% | 286 ~ 4.52e+07 |
| p_value | numeric | 31 | 0.77% | 0 ~ 1 |
| beta | numeric | 0 | 0.00% | -0.3 ~ 0.3 |
| se | numeric | 0 | 0.00% | 0.01 ~ 0.1 |
| note | character | 4000 | 99.98% |  |

## 问题

- 染色体命名混用 chr1 与 1，必须先统一
- 列 `p_value` 有 41 个 0，log10 会变 Inf，需截断
- 高缺失列：note

## 建议

- 以 `chromosome` 为染色体列，注意 chr 前缀
- p 值列 `p_value` 取 -log10 前先截断到 1e-300
