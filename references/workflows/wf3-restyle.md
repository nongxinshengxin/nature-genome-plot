# WF3 换风格 / 改现有图

## 情况 A：模板出的图
换 `--style` 重渲染即可，数据不动。

## 情况 B：用户自己的 R/Python 脚本
1. 抽出视觉参数：尺寸、字号、配色、线宽、图例位置、网格
2. 写成 preset YAML（参照 `templates/presets/<id>/<name>.yaml`）
3. 把硬编码参数替换成读 YAML
4. 重渲染 + 与旧图逐项对比

## 情况 C：只有图片
1. 目测抽出 dials（尺寸、字号、配色、面板布局）
2. 选最接近的 archetype + preset
3. 用用户数据重绘，不接受像素级复刻
4. 给 diff 清单：改了什么、为什么

## 边界
- 不复制论文图；措辞用 inspired by / observed in
- 用户脚本是 shell/perl/JS 时，只做视觉参数提取，重写为 R（默认）或 Python
