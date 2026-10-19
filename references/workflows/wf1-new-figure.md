# WF1 从零出图

## 0. 环境自检
跑 `Rscript scripts/doctor.R`；缺包先按 SKILL.md §4 处理，再往下走。

## 1. 判定图型
先跑 `python3 scripts/profile/infer_archetype.py --data <file>` 拿候选与缺失列，
再用意图词在 `catalog/index.yaml` 中确认 `id`。匹配不到时读 `references/core/decision-rules.md` 取最近邻，并明确告知用户。

## 2. 校验数据
按 `catalog/archetypes/<id>.yaml` 的 `inputs` 逐列核对：
- 缺列：给 2–3 种映射方案让用户选，不猜
- 染色体命名不统一（chr1 vs 1）：先统一
- 数值列含 NA/Inf：报告比例，超过 5% 停下

## 3. 选 2 个风格
主图用 `minimal-editorial`，补充图用 `dense-diagnostic`，汇报用 `high-contrast`。
circos 可选 6 个：另加 `soft-pastel`、`mono-blue`、`warm-editorial`。

## 4. 渲染
```bash
Rscript templates/R/<id>.R --data <dir> --style <preset> \
  --out out/<slug>/<id>.<preset>.png --width 183 --height <h> --dpi 300
```
同一数据渲两个 preset，让用户对比后再定稿。

## 5. 质检
按 `references/checklists/figure-qa.md` 逐项检查；至少覆盖字号、留白、图例、色盲。

## 6. 交付
```
out/<slug>/
├── fig.png / fig.pdf
├── plot.R
├── figure-spec.yaml
├── data-profile.md
├── qa-report.md
└── README-run.md
```
`figure-spec.yaml` 必须写清：archetype、preset、数据映射、尺寸、改动理由。
