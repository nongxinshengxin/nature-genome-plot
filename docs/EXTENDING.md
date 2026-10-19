# 扩展协议：加模板 / 加风格

这个项目的状态全部在文件里，不依赖某一次对话的上下文。
**新会话接手时，先跑 `python3 scripts/extend/status.py`，再读本文件。**

---

## 0. 你需要提供什么

| 给什么 | 作用 |
|---|---|
| 图（截图/PDF/补充材料）或 DOI + 图号 | 判断图型与风格 |
| 一句话：你想复刻**图型**还是**风格** | 决定走哪条流程 |
| 你的数据样例（列名/维度） | 定契约、做 fixture |
| 可选：3 篇以上同类论文 | 风格卡需要 ≥3 条证据 |

图片放 `inbox/`，已在 `.gitignore` 里，不会提交。
**不要**把论文原图放进 `catalog/` 或 `fixtures/`——版权原因，只提炼属性。

---

## 1. 先分类

- **新风格**：图型没变，只是配色/布局/注释方式不同 → 走 A
- **新图型**：回答的问题变了（比如从「谁和谁像」变成「基因家族扩张」）→ 走 B
- 拿不准时按 B 处理，因为 B 需要新契约，A 可以随时补。

---

## A. 加一个风格（约 15 分钟）

```bash
python3 scripts/extend/new_style.py <archetype> <style-id> \
  --label "显示名" --base minimal-editorial
```

生成：

- `templates/presets/<archetype>/<style-id>.yaml`（从 base 复制，改颜色/字号/线宽）
- `catalog/styles/<archetype>.<style-id>.yaml`（draft，证据为空）
- 自动登记进 `catalog/archetypes/<archetype>.yaml` 与 `catalog/index.yaml`

然后：

1. 改 preset 的视觉参数（只动参数，不动数据逻辑）
2. 填 3 条以上证据（DOI + 图号 + 观察到的做法）
3. 渲染验证：
   ```bash
   Rscript templates/R/<archetype>.R --data fixtures/<archetype> \
     --style <style-id> --out /tmp/t.png
   python3 scripts/validate/smoke.py --only <archetype>
   Rscript scripts/validate/style_audit.R
   ```
4. 卡片状态从 `draft` 改 `validated`，前提是证据齐且渲染过

---

## B. 加一个图型（约 2–4 小时）

```bash
python3 scripts/extend/new_archetype.py <id> --label "中文名" --implementation ggplot2
```

生成：

- `catalog/archetypes/<id>.yaml`（契约骨架，inputs 全是 TODO）
- `templates/R/<id>.R`（会直接 `stop()`，保证冒烟测试不会假通过）
- `fixtures/<id>/README.md`
- `catalog/index.yaml` 登记

要补的六件事：

1. **契约**：`inputs` 的列名/类型/取值域；`rules` 写「什么情况不该用这张图」
2. **模板**：读 preset + data，出错时报告缺哪列；单图 <10 s
3. **fixture**：合成数据，生物上自洽，≤2 MB，README 写字段
4. **预设**：`python3 scripts/extend/new_style.py <id> minimal-editorial`
5. **证据**：`catalog/styles/` 里至少 3 篇 DOI + 图号
6. **验证**：
   ```bash
   python3 scripts/validate/catalog_check.py
   python3 scripts/validate/smoke.py --only <id>
   ```

---

## 2. 硬约束（扩的时候不能破）

- 绘图脚本只写 **R**（默认）或 Python；不引入 shell/perl/JS 绘图
- 模板只读 preset，不把颜色写死
- 不改已有 preset 的字段名（模板按字段取值，改了就断）
- 不复制论文图与第三方代码；`inspired by`，不是 `reproduced from`
- 证据不足就保持 `draft`，不要为了「齐」而编 DOI

## 3. 一次只加一个

加完一个就提交、跑测试，再动下一个。批量加会让回归失败点难以定位。

## 4. 新会话怎么接

1. `python3 scripts/extend/status.py` —— 看数量、校验状态
2. `docs/EXTENDING.md` —— 本文件
3. `docs/todo.md` —— 还缺什么
4. `docs/acceptance.md` —— 上一轮的验收证据

不需要读整个仓库，也不需要上一轮对话。
