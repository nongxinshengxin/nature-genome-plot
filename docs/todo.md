# 已知问题 / 待办（2026-10-19）

## 模板
- assembly-qc：NGx 的组装配色没有图例（BUSCO 图例只覆盖类别）
- selection-scan：fixture 的候选区坐标与注入峰不一致，演示时像错位
- circos：底部染色体标签可能倒置，需按角度翻转
- linear-tracks：基因标签与基因箭头/坐标轴贴得太近
- PDF 走 `pdf()`，字体为 Type1 Helvetica（未嵌入）；严格投稿前需 embedFonts 或改用 SVG

## 数据坑
- Manhattan：`p=0` 或过小值按下限丢弃（默认 1e-50），不要钳到下限
- 染色体顺序统一按数字自然排序

## 证据
- 39 个 preset 全部是原型（Nature 惯例 + 本机审美），未按「每卡 ≥3 篇论文」回填
- 需要把 figure-inventory 的 caption 映射到 style card 的 observed 字段

## 工程
- 冒烟已固化：`scripts/validate/smoke.py`（39/39）
- preset 只做了结构校验（文件存在、卡片齐全），字段级 schema 未做
- 缺 fixtures 的 README（字段说明）
- SKILL.md 已接 catalog，软链已装；需在真实会话里跑一次 dogfood
