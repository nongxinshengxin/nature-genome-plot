# WF4 投稿合规审计

## 1. 读规格
`references/core/journal-specs.md`，确认目标刊与图类型（主图 / Extended Data）。

## 2. 12 项检查
逐条过 `references/checklists/figure-qa.md`，每项给 通过 / 风险 / 不通过 + 证据。

## 3. 可自动化的部分
- 尺寸：PyMuPDF 或 PIL 读页面/像素
- 字体：PyMuPDF 读嵌入字体
- 色盲：`colorspace::simulate_cvd()` 出对照图
- 字号：按最终尺寸换算 pt，低于 5 pt 直接判不通过

## 4. 输出
`qa-report.md`：问题清单 + 修复建议 + 优先级。修复走 WF3。
