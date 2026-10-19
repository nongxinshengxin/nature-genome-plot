# 验收报告（2026-10-19）

## 交付物

| 层 | 内容 | 位置 |
|---|---|---|
| 路由 | SKILL.md + manifest.yaml（5 工作流） | 根目录 |
| 知识 | 12 图型契约、39 张风格卡、选型规则 | `catalog/` |
| 代码 | 12 个 R 模板、39 个 YAML 预设 | `templates/` |
| 数据 | 12 套 fixture、5 个适配器 | `fixtures/`, `adapters/` |
| 工作流 | WF1–WF5 + 期刊规格 + 质检清单 | `references/` |
| 验证 | 冒烟、catalog、风格审计脚本 | `scripts/validate/` |

## 验证证据

| 检查 | 命令 | 结果 |
|---|---|---|
| 渲染矩阵 | `python3 scripts/validate/smoke.py` | **39/39 通过**（2026-10-19） |
| 结构完整性 | `python3 scripts/validate/catalog_check.py` | 12 图型 / 39 卡，0 错误 |
| 风格可及性 | `Rscript scripts/validate/style_audit.R` | 25 ok、9 幻灯片专用、2 装饰、3 单色/连续 |
| 适配器 | 5 个 smoke 命令 | 5/5 通过 |
| 矢量导出 | PNG / SVG / PDF | 三种均可，PDF 为 Type1 Helvetica |
| 安装 | 软链 `~/.dsh/skills/nature-genome-plot` | 本会话已成功加载 |

## 端到端案例

1. `examples/walkthrough-gwas.md`：脏 GWAS 表 → 诊断 → 映射 → Manhattan（修掉 2 个模板 bug）
2. `out/demo-population-structure/`：完整交付包（图 + spec + 诊断 + 质检 + 复现说明）
3. `out/circos/styles-compare.png`：同一数据 6 种风格

## 已知限制

- 风格卡为 `draft`：证据来自图注匹配（DOI + 图号可回指），**未做像素级风格核对**（出版社图床拒绝匿名抓取）
- PDF 字体未嵌入（Type1），严格投稿需 `embedFonts` 或改交 SVG
- `soft-pastel` / `warm-editorial` 未过色盲阈值，仅装饰用
- 适配器缺 PLINK bed 与 bigWig 原生解析（前者用 eigenvec，后者需 rtracklayer 或先转 bedGraph）
- 证据池 200 篇为 OA 配额抽样，风格归纳偏向 Nature Communications（90/200）
