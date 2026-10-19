# 深读集代码仓库审计（2026-10-18）

对象：80 篇深读论文中给出的 GitHub 仓库，共 55 个（一篇可含多个）。方法：`git clone --depth 1 --filter=blob:none --no-checkout` 只取文件树，再按需取少量 R/Python 文件检索绘图库。

## 结果

| 指标 | 数量 |
|---|---|
| 链接到的仓库 | 55 |
| 成功克隆 | 50（5 个已删除/改名/私有） |
| 含 R 文件 | 26 |
| 含 Python 文件 | 29 |
| 含 notebook | 4 |
| 能识别到绘图库 | 25 |
| 有 LICENSE | 21（42%） |

绘图库命中：ggplot2 / ggplot( 17、ggpubr 6、ggtree 6、matplotlib 6、RIdeogram 3、patchwork 2、pheatmap 2、plotly 2、seaborn 2、ComplexHeatmap 1、circlize 1。

## 判断

- 一半仓库只放分析流程（shell/Snakefile），真正的绘图脚本往往只有几个文件，甚至没有。
- license 缺失接近六成，代码不能直接复用；模板仍按范式重写。
- R 与 Python 大致对半，但 R 侧集中在 ggplot2 生态，符合「默认 R」。

## 语言约束（用户 2026-10-18）

交付与参考脚本只允许 R / Python，默认 R；shell、perl、JS、matlab 脚本只作阅读参考，不进 catalog、不交付给用户。
