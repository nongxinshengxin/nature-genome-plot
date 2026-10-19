# nature-genome-plot · 项目统筹设计 v0.1

**状态**：M0–M6 完成，skill 已安装可用；验收见 `docs/acceptance.md`。决策已由 agent 按用户授权代选（2026-10-18）；异议点集中在 §12，其余按本文执行。
**一句话**：把 2023–2026 年六刊基因组/泛基因组/群体基因组论文里的可视化范式，做成可查询、可组合、可运行的绘图资产，让用户拿自己的数据换来一张能过 Nature 美术编辑的图。

---

## 0. 一页纸

### 是什么

一个三层结构的 skill：

| 层 | 内容 | 用户感知 |
|---|---|---|
| 知识层 | 12 个图型（archetype）+ 3 个风格家族（每个图型 2–3 个预设）+ 选型规则 | 「我这个数据该画什么图」 |
| 代码层 | CLI 可运行的 R/Python 模板、数据契约、格式适配器、toy fixture | 「给我能直接跑的代码」 |
| 交互层 | 路由、数据诊断、渲染迭代、期刊合规质检、交付包 | 「按我的数据改到能用」 |

### 不是什么

- 不是文献综述工具（检索只服务于建库，不对外提供综述）
- 不是数据分析工具（只做「已算好的结果 → 图」，不做 GWAS/PCA 的统计计算本身）
- 不复制论文图，不搬运论文代码（版权与许可约束，见 §9）
- 不做 schematic/模式图（那是 Illustrator 的领域，只给版式规范）

### 三种典型用法

1. **从零出图**：用户给 `pca.tsv`（sample, PC1, PC2, group）说「要主图，投 Nature Genetics」→ skill 判定 `population-structure` → 推荐 2 个风格预设 → 渲染对比 → 定稿 → 交付 PDF + 代码 + spec。
2. **模仿风格**：用户指某篇论文的泛基因组图说「照这个感觉来」→ 匹配最接近的 style card（不做像素级复刻）→ 套到用户矩阵上。
3. **救火**：用户已有 circos 代码/图，说「字号被编辑打回」→ 走 `restyle`/`audit` 工作流，输出改动清单 + 新图。

### 建库成本（估）

约 17.5 个 agent-day：导出 spike 0.5d、采集筛选 1.5d、证据抽取 1.5d、风格合成 3d、模板实现 6d、路由 1.5d、质检 2d、dogfood 1d。

---

## 1. 定位与场景边界

### 1.1 目标用户

做基因组、泛基因组、群体遗传、进化基因组、微生物基因组的研究者；手上已有统计结果（表/矩阵/区间），缺的是「Nature 级排版」和「图型选型」。

### 1.2 触发场景

| 场景 | 入口工作流 | 典型输入 |
|---|---|---|
| 我有数据，不知道画什么 | WF1 new-figure | tidy 表、矩阵 |
| 我知道画什么，要专业代码 | WF1 | 同上 + 指定 archetype |
| 我要模仿某篇论文的图 | WF3 restyle | 数据 + 论文 DOI/截图 |
| 我图有了，要合规/好看 | WF4 audit | PDF/PNG + 目标期刊 |
| 我要改自己的绘图脚本 | WF3 | 现有 .R/.py |

### 1.3 明确排除

- 统计建模与显著性计算（只消费结果，不生产结果）
- 原始数据质控（fastq/比对层面）
- 3D 基因组 Hi-C 矩阵的原始处理（只接受已算好的接触矩阵，v1.1 再纳入）
- 中文期刊排版规范（v1 只覆盖 Nature 系）

---

## 2. 决策台账

| # | 决策点 | 结论 | 理由 |
|---|---|---|---|
| D1 | 知识库形态 | 构建期一次性 harvest，产出静态 catalog 随 skill 发布；运行时不联网 | 可复现、可测试、风格归纳稳定；实时抓取无法保证代码可跑 |
| D2 | 兜底 | 目录缺项时允许现场检索，但结果标 `unverified`，不得冒充已验证模板 | 保留长尾能力，同时守住质量线 |
| D3 | 主语言 | **绘图脚本只用 R 或 Python；默认 R**。Python 仅在 R 生态明显弱时使用（UMAP/单细胞/部分矩阵图） | 用户约束（2026-10-18）；本机 R 4.5.2 生态完整 |
| D4 | 双语范围 | 仅 3–5 个跨生态图型做 Python 实现，其余只出 R；**不接受 R/Python 之外的绘图脚本**（shell/perl/JS/matlab 仅作参考） | 全量双语维护成本翻倍；语言约束来自用户 |
| D5 | 图型边界 | 12 个数据图 archetype + 1 个 composition 模块（拼版/字号/导出），不做 schematic | 示意图不适合代码化，版式规范可复用 |
| D6 | 输入契约 | tidy 表 / 矩阵 / 坐标表为一等公民；VCF、GFF、PLINK 走适配器转 tidy | 模板数量可控，脏数据可救 |
| D7 | 已有图 | 走「逆向 spec」路径：抽 dials → 生成 spec → 重绘 | 比直接改别人的代码可控 |
| D8 | 版权 | 自研实现，不复制图、不 vendor 第三方代码；provenance 记 DOI/仓库/commit/license | 法律风险 + 学术诚信 |
| D9 | 运行时 | 检测环境→渲染→视觉检查→最多 3 轮迭代；缺依赖时降级为代码+依赖清单并标注 unverified | 「按我的数据调」必须闭环 |
| D10 | 风格组织 | 3 个 house style 家族 × 每个 archetype 2–3 个预设，而非「一篇论文一套风格」 | 避免 36 份代码分叉，保证跨图一致性 |
| D11 | 验收 | 每个 archetype×预设必须过 smoke test + 12 项视觉检查 + 期刊规格校验 | 没有渲染验证的模板等于没有 |
| D12 | 文献窗口 | 2023-01-01 起滚动（当前覆盖 2023–2026），六刊，Article only | 符合「近三年」，留出索引滞后余量 |

---

## 3. 产物结构

```
nature-genome-plot/
├── SKILL.md                     # 路由层：意图 → 工作流 → 按需加载
├── manifest.yaml                # 轴定义：workflow / archetype / language
├── DESIGN.md                    # 本文
├── README.md                    # 安装与用法
├── catalog/
│   ├── index.yaml               # 轻量索引（一行摘要），路由只读这个
│   ├── archetypes/              # 12 个图型定义（输入契约、结构变体、规则）
│   ├── styles/                  # 24–36 张 style card（YAML）
│   └── papers/                  # provenance 记录（DOI、图号、观察、代码仓库）
├── references/
│   ├── core/
│   │   ├── figure-grammar.md    # 视觉语法：编码通道、层级、留白
│   │   ├── journal-specs.md     # Nature 系硬规格（尺寸/字号/格式/色盲）
│   │   └── decision-rules.md    # 选型 if→then 规则库
│   ├── workflows/               # wf1–wf5 工作流说明
│   └── checklists/              # 投稿前 12 项视觉检查、数据契约检查
├── templates/
│   ├── R/                       # 12 个 .R 模板 + 共享 theme/工具函数
│   ├── python/                  # 3–5 个 .py 模板
│   └── presets/                 # 每个 archetype 的 2–3 个 YAML 预设
├── adapters/                    # vcf→tidy、gff→track、plink→pca、bigwig→track
├── fixtures/                    # 每个 archetype 一份 toy 数据（≤2 MB）
├── scripts/
│   ├── harvest/                 # ePMC 检索、全文抓取、代码链接抽取
│   ├── screen/                  # 评分与去重
│   ├── render/                  # 批量渲染与导出
│   └── validate/                # smoke、CVD、尺寸、字体检查
├── contracts/                   # 每个 archetype 的列名/类型/取值域
└── docs/                        # 建库报告、语料偏差声明、CHANGELOG
```

**加载策略（渐进披露）**：SKILL.md 只读 `catalog/index.yaml`；命中 archetype 后才读该 archetype 的定义 + 候选 style card；绝不整目录加载。

---

## 4. 知识层设计

### 4.1 图型清单（12 核心 + 5 扩展）

核心 12 覆盖六刊基因组论文的绝大多数数据图。每个图型有 1–2 个结构变体、2–3 个风格预设。

| # | id | 中文 | 典型画面 | 输入 | 结构变体 |
|---|---|---|---|---|---|
| 1 | `circos-landscape` | 环形基因组全景 / 弦图 | 染色体环 + 基因/TE/GC 密度 + 染色体内外弦（chord） | chrom sizes + 轨道值 + links | circular（**4–6 个风格预设**） |
| 2 | `linear-tracks` | 线性多轨道 | 基因模型、重复、覆盖度、保守性堆叠 | BED/GFF/bigwig → tidy | stacked / mirrored |
| 3 | `synteny` | 共线性 | dotplot 或 ribbon 弧 | 双物种坐标对 | dotplot / ribbon |
| 4 | `assembly-qc` | 组装质量 | NGx 曲线、BUSCO、k-mer 谱、QV | 统计表 | curves+bars / panel grid |
| 5 | `pangenome-composition` | 泛基因组构成 | 增长曲线 + core/accessory 堆叠 + Upset | 基因×基因组 0/1 | curve+stack / upset |
| 6 | `presence-absence` | 存在缺失热图 | 聚类热图 + 注释条 | 0/1 矩阵 | heatmap / heatmap+tree |
| 7 | `sv-cnv` | 结构变异全景 | 密度轨、长度谱、AF、示例位点 | SV 表（VCF→tidy） | genome-wide / locus |
| 8 | `population-structure` | 群体结构 | PCA/UMAP + ADMIXTURE + 树 | 基因型或 PC/admix 表 | pca+admix / umap |
| 9 | `manhattan-qq` | 关联分析 | Manhattan + QQ + 区域放大 | GWAS sumstats | single / stacked |
| 10 | `selection-scan` | 选择清除 | Fst/π/Tajima/XP-EHH 多轨 + 候选区 | 窗口统计表 | tracks / composite |
| 11 | `demography` | 群体历史 | SFS、PSMC、Treemix、LD 衰减、IBD | 汇总统计 | multi-panel / single |
| 12 | `phylogenomics` | 系统发育 | 树 + 热图 + 祖先状态 | 树文件 + 矩阵 | rectangular / circular |

**扩展（v1.1）**：`sampling-map`（地理采样）、`methylation`（甲基化/表观）、`hic-contact`（接触矩阵）、`gene-family-cafe`（基因家族扩张）、`expression-eqtl`（表达/eQTL）。

**边界判定**：一个图如果主要靠「示意」而非「数据编码」传达信息（模型卡通、流程示意），不进 catalog。

### 4.2 三个风格家族（house styles）

不是「每篇论文一种风格」，而是从语料中归纳出的三个模态，各自参数化：

| 家族 | 定位 | 视觉特征 | 适用 |
|---|---|---|---|
| `minimal-editorial` | Nature 主图 | 白底、无网格、0.25–0.5 pt 细线、Okabe-Ito 低饱和、直接标注替代图例、5–7 pt | 首图、机制主张图 |
| `dense-diagnostic` | 补充图/Extended Data | 多子图、细密刻度、浅灰网格、信息密度优先、允许 6 pt | 全基因组扫描、质控矩阵 |
| `high-contrast` | 汇报/预印本/可及性优先 | 加粗线、深填充、7 pt、强对比、CVD 双保险 | 组会、slides、低质量投影 |

每个 archetype 从中挑 2–3 个落地为预设；论文里的独特做法记作 `variant_note`，不单独成卡。

### 4.3 style card schema

```yaml
id: population-structure.minimal-editorial
archetype: population-structure
label: 极简编辑风（Nature 主图）
status: validated            # draft | validated | deprecated
provenance:
  papers:
    - doi: 10.1038/s41467-025-XXXXX
      figure: Fig. 1c–e
      observed: PCA 三分面；ADMIXTURE K=3–7；无网格；浅灰须线
  support: 8 篇中 5 篇同构
  synthesis: 2026-11 风格合成批次 2
grammar:
  panels: [pca, admixture, tree]
  encoding: 分类色 ≤6；跨面板同群体同色；点大小随 n 递减
  annotations: 直接标注群体名；不画图例框
dials:
  width_mm: 183
  height_mm: 60
  base_font_pt: 7
  font: Arial
  line_pt: 0.4
  point_pt: 0.9
  grid: none
  spine: bottom-left
  palette: okabe-ito-6
code:
  r: templates/R/population-structure.R
  preset: templates/presets/population-structure/minimal-editorial.yaml
  python: templates/python/population_structure.py   # 可选
contract: contracts/population-structure.yaml
when_to_use: 主图；需一屏讲清群体分化与混合比例
avoid_when: n>5000 且群体连续渐变（改用 UMAP+密度等高线）
pitfalls:
  - ADMIXTURE K 过多导致条形图不可读 → 限 K≤7，其余进补充
  - 群体标签在 PCA 边缘重叠 → repel + 引线
qa: [label_overlap, cvd, font_embed, size]
```

**关键约束**：style card 只描述「怎么画」，不描述「画什么数据」。数据语义在 archetype 与 contract 里。

### 4.4 选型决策规则（节选，完整版进 `references/core/decision-rules.md`）

| 条件 | 决策 |
|---|---|
| 染色体/contig 数 > 40 | 禁用 circos，改 `linear-tracks` 或 `manhattan-qq` |
| 样本 > 5000 且群体连续 | 不用 UMAP 散点，改 PCA + 密度等高线 |
| 泛基因组 > 300 基因组 | presence–absence 必做聚类排序 + 抽样展示，并给完整矩阵下载 |
| GWAS 无显著 lead SNP | 不画 locuszoom，改区域窗 + 全基因组 Manhattan 双面板 |
| Fst 窗口 < 10 kb | 必须平滑（滚动中位数），否则锯齿不可读 |
| 树 > 200 叶 | 改 circular 或折叠支，热图列聚类 |
| 只有 2 个群体 | 不做 admixture K 扫描，改 Fst 分布 + PCA |

### 4.5 circlize 弦图专项（用户 2026-10-18 追加）

- 实现统一走 **circlize**，参考其 GitHub 示例（`circos.genomicTrack` / `circos.genomicLink` / `circos.initialize`）与 Nature 系版式。
- 弦图（chord）是独立卖点：共线性、SV 介导的片段交换、泛基因组区块共享都用它表达。
- **预设备选 6 个，已全部落地并出图**：极简编辑风、高密度诊断风、高对比风、柔和粉彩风、单色蓝、暖色编辑风。其中前 4 个来自原型，后 2 个按 Nature 常见用色补充；M3 再用论文证据校准。
- 已产出：`templates/R/circos-landscape.R`（读 YAML preset）+ `templates/presets/circos-landscape/*.yaml`（6 个）+ `catalog/archetypes/circos-landscape.yaml`（数据契约）+ `fixtures/circos/`。同一份数据切 6 个风格，输出 PNG/PDF。
- 参数化点：轨道高度、sector 间隙、标签朝向、弦的透明度与配色（按源染色体着色）、网格开关、字号。

### 4.6 期刊硬规格基线（已核对 Nature 官方 2026 版）

来源：[Nature research figure guide — Building and exporting figure panels](https://research-figure-guide.nature.com/figures/building-and-exporting-figure-panels/)

- 宽度：单栏 **89 mm**，双栏 **183 mm**；Nature 主图最大高度 **170 mm**（给图注留位）
- 字号：**5–7 pt**，Arial/Helvetica，字体嵌入（TrueType 2/42），文字保持可编辑、不得转曲
- 主图格式：`.ai` / `.eps` / `.pdf`（保留编辑能力）/ `.svg`；**不接受** jpeg/tiff/png
- Extended Data：RGB，≤300 dpi，jpeg（首选）/tiff/eps，单文件 ≤10 MB
- 色盲：官方给出 Okabe–Ito 8 色（`#000000 #E69F00 #56B4E9 #009E73 #F0E442 #0072B2 #D55E00 #CC79A7`）；避免红绿组合与彩虹色阶；文本对比度 >4.5:1；避免彩色文字
- 版面：面板按字母顺序、留白最小化

> Nature Communications / Nature Plants 等子刊的 artwork 细则可能有差异，M6 逐刊复核后写入 `journal-specs.md`，catalog 只引用该文件。

---

## 5. 采集与合成流水线

### 5.1 检索（S1）

Europe PMC REST，六刊分刊检索后合并：

```
(JOURNAL:"Nature" OR JOURNAL:"Nature Genetics" OR JOURNAL:"Nature Plants"
 OR JOURNAL:"Nature Ecology & Evolution" OR JOURNAL:"Nature Microbiology"
 OR JOURNAL:"Nature Communications")
AND PUB_YEAR:[2023 TO 2026]
AND OPEN_ACCESS:y
AND (TITLE_ABS:"genome assembly" OR TITLE_ABS:pangenome OR TITLE_ABS:"pan-genome"
     OR TITLE_ABS:"structural variation" OR TITLE_ABS:"population genomics"
     OR TITLE_ABS:"population structure" OR TITLE_ABS:admixture
     OR TITLE_ABS:"selective sweep" OR TITLE_ABS:"selection signature"
     OR TITLE_ABS:GWAS OR TITLE_ABS:"genome-wide association"
     OR TITLE_ABS:introgression OR TITLE_ABS:"demographic history"
     OR TITLE_ABS:"conservation genomics" OR TITLE_ABS:domestication)
NOT (PUB_TYPE:"review" OR PUB_TYPE:"comment" OR PUB_TYPE:"editorial" OR PUB_TYPE:"correction")
```

- 时间窗按 36 个月滚动；`PUB_YEAR` 只做粗筛，最终以 `firstPublicationDate` 为准
- 去重键：DOI；保留 `pmcid`、OA 状态、license
- 只保留 Article / Article in press；News & Views、Research Highlights 一律排除

### 5.2 证据分级

| 级别 | 定义 | 用途 |
|---|---|---|
| **T1** | 有绘图代码（R/Python/notebook），能定位到具体图，且可运行或有运行记录 | 模板实现的直接参照 |
| **T2** | 有代码仓库但绘图部分不完整/不可运行/无 license | 风格参照 + 实现灵感 |
| **T3** | 无可执行代码，但图注 + 方法完整描述了图型与参数 | 风格证据（仅用于归纳，不用于代码） |

**结论先行**：T1 会比预期少。抽样验证（2026-10-18）：`PMC12808307` 的 Code availability 指向 GitHub 仓库，根目录有 `visualization/`，但仓库**无 license**；`baozg/Potato_C88` 只有 `Snakefiles` + `script/`，同样无 license。所以代码层必须是「按范式重写」，不是「搬运论文代码」。

### 5.3 评分卡（0–10）

| 维度 | 分值 | 判据 |
|---|---|---|
| 图件相关性 | 0–3 | 图是否属于 12 个 archetype 之一；是否为核心图 |
| 代码证据 | 0–4 | 4=T1 可运行绘图代码；2=T2；1=T3 图注详尽；0=无 |
| 风格辨识度 | 0–2 | 是否有可命名的视觉选择（配色逻辑、布局、注释策略） |
| 领域代表性 | 0–1 | 是否覆盖尚未饱和的图型/亚领域 |

- 硬门槛：OA 全文可得 + 主题命中 + 至少 1 张目标图型 + Article
- **总量封顶 200 篇**：按分数排序，再按期刊/年份/图型配额截取（见 5.4），不追求穷举
- ≥7：深读（T1/T2 优先），进 provenance
- 5–6：保留在 200 篇语料内，只作风格证据
- <5：排除

### 5.4 漏斗（实测 vs 估计）

| 阶段 | 数量 | 来源 |
|---|---|---|
| 六刊宽主题词原始命中（2023–2025） | **14,362** | 实测：NC 10,990 / Nature 1,730 / NG 791 / NM 432 / NP 239 / NEE 180 |
| 其中开放获取（OA） | **12,845** | 实测 |
| NC 中命中 "code availability" 且主题收窄 | **565** | 实测 |
| 收紧到 TITLE_ABS + Article + 去重 | 2,000–3,000 | 估计，M1 实测 |
| **入选语料（封顶）** | **200** | 已完成（M1）：NC 90 / Nature 30 / NG 30 / NM 20 / NP 15 / NEE 15 |
| 深读（T1/T2 优先） | 60–80 | 计划 |
| 风格证据 | 200 篇的图注与方法 | 计划 |
| 落地产出 | 12 archetype × 2–3 预设 = 24–36 卡 | 计划 |

**200 篇的配额**（保证每刊 ≥15、每图型 ≥10、年份均衡）：

| 期刊 | 配额 | 理由 |
|---|---|---|
| Nature Communications | 80 | 全 OA，体量最大，是主力语料 |
| Nature | 35 | 主图范式最权威 |
| Nature Genetics | 30 | 群体/泛基因组核心刊 |
| Nature Microbiology | 25 | 微生物基因组代表 |
| Nature Plants | 15 | 植物泛基因组代表 |
| Nature Ecology & Evolution | 15 | 保护/进化基因组代表 |

> 语料偏差照旧写进 `docs/corpus-bias.md`：五刊非 OA 文章按可得性丢弃，NC 占比 40%，风格归纳仍偏向 NC；配额保证的是「每刊有声音」，不是「每刊等权」。

### 5.5 抽取字段（每篇一条 YAML）

`doi, journal, year, title, oa_status, license, pmcid, code_links[], code_tier, repo_license, plotting_files[], figure_inventory[{fig, panels, archetype_tags}], style_attributes{palette, layout, axis, annotation_density}, notes`

### 5.6 风格合成（S8）

1. 每个 archetype 汇总 ≥6 篇的 style_attributes
2. 按「配色逻辑 / 面板组织 / 注释策略 / 密度」四轴聚类
3. 取 2–3 个模态 → 命名 → 写 card
4. 三角验证：一个 style 至少 3 篇支持；孤例降级为 `variant_note`
5. 每条观察必须能回指 `doi + 图号`，否则不写

### 5.7 实现与回填（S9）

模板落地后用 toy 数据渲染，与 card 描述逐条对照；不符则改卡或改码，不允许「卡一套、码一套」。

---

## 6. 代码与模板工程

### 6.1 模板标准

- CLI：`Rscript population-structure.R --data d.tsv --preset p.yaml --out out/fig.pdf --width 183 --height 60 --dpi 300 --seed 42`
- 无绝对路径、无网络、无交互；同一输入同一输出（固定 seed）
- 单图渲染 < 10 s；失败时报「缺哪一列、允许什么取值」，不报堆栈
- 数据逻辑与视觉参数分离：数据在模板里，dials 在 preset 里
- 每模板一份 `contracts/*.yaml`：列名、类型、取值域、示例

### 6.2 组合模型

```
archetype (12) × structure variant (1–2) × style preset (2–3)
```

不是 36 份代码，而是 **12 份模板 + 参数化预设**。结构变体（如 synteny 的 dotplot/ribbon）用 `--variant` 切换，共享数据层。

### 6.3 数据契约与适配器

一等公民：`tidy 表`（长表，每行一个观测）、`矩阵`（行=特征，列=样本）、`坐标表`（chrom/start/end + value/link）。

适配器（一次性预处理，不混进模板）：

| 适配器 | 输入 | 输出 | 依赖 |
|---|---|---|---|
| `vcf2tidy` | VCF/BCF | SV/SNP tidy 表 | bcftools 或 vcfR |
| `gff2track` | GFF3/GTF | 基因模型区间表 | rtracklayer |
| `plink2pca` | bed/bim/fam | PCA 坐标表 | plink2 |
| `bigwig2track` | bigwig | 窗口均值表 | rtracklayer |
| `paf2synteny` | PAF | 共线性坐标对 | 纯解析 |

适配器失败时给「装什么 / 换什么格式 / 用哪条命令」三选一，不静默降级。

### 6.4 依赖策略

- R：`renv.lock` 锁版本；核心依赖 ggplot2、circlize、ggtree、ComplexHeatmap、patchwork、ragg、svglite（需安装）、scales、dplyr、data.table
- 语言红线：交付模板与用户脚本只能是 `.R`/`.Rmd` 或 `.py`；分析流程类 shell/Snakefile 不作为绘图交付物
- Python：**不用本机 3.14**（缺 scanpy 等轮子）；用 `uv` 建 3.12 venv，`requirements.txt` 锁版本
- 可选依赖（scanpy、plotly）单列 `requirements-optional.txt`，缺失时模板降级到 matplotlib

### 6.5 fixture 设计

每个 archetype 一份合成数据，生物学上自洽（染色体长度幂律分布、群体有真实分化结构、SV 长度重尾），体积 ≤2 MB，附 `README` 说明字段与预期图形特征（用于人工核对）。

### 6.6 导出链路（实测，2026-10-18）

本机实测见 [docs/env-probe.md](docs/env-probe.md)：

| 链路 | 实测结果 |
|---|---|
| R `cairo_pdf()` + Arial | 失败：`字体类别出错`（invalid font type） |
| R `cairo_pdf()` + Helvetica | 不报错但不产出文件 |
| R `pdf()` base | 出图正常，字体为 Type1，不嵌入 |
| R `ragg::agg_png()` | 正常 |
| R `svglite` | 未安装，未测 |
| Python matplotlib PDF | 正常，ArialMT 子集嵌入，页面精确 183×60 mm |

**决策**：向量交付**不走 cairo_pdf 默认链路**。

- 主向量：SVG（`svglite`，装在项目 `.Rlib`；Nature 接受 `.svg`，文本保持可编辑）
- PDF：`grDevices::pdf()`（Type1 Helvetica，矢量、可编辑；字体未嵌入，投稿前可按需 `embedFonts`）
- 预览位图：PNG（`ragg`，300 dpi）
- `cairo_pdf` 停用（本机不可用）
- 所有导出在 M0.5 定版，结论写进 `journal-specs.md` 与模板默认参数

---

## 7. 运行时工作流

### 7.1 五个入口

| 工作流 | 输入 | 动作 | 产出 |
|---|---|---|---|
| WF1 new-figure | 数据 + 意图 | 判型 → 选 2 风格 → 渲染对比 → 定稿 | 图 + 代码 + spec |
| WF2 adapt-data | 数据（格式不规范） | 诊断 → 映射 → 适配器 → 渲染 | 图 + 映射报告 |
| WF3 restyle | 现有图/代码 + 目标风格 | 逆向 spec → 替换 dials → 重绘 | 新图 + diff 说明 |
| WF4 audit | 图 + 目标期刊 | 12 项检查 → 问题清单 → 修复建议 | 质检报告 |
| WF5 browse | 无数据 | 列 archetype/style + 示例 | 选型建议 |

### 7.2 渲染闭环

```
数据诊断 → 契约校验 → 选 preset → 渲染 → 自动检查 → 人看 → 改 dials/结构 → 重渲染（≤3 轮）
```

数据诊断输出 `data-profile.md`：行数、缺失、染色体命名规范（chr1 vs 1）、数值范围、离群、重复键、样本量分档。**命名不规范是最常见的翻车点**，必须前置拦截。

### 7.3 交付包

```
out/<slug>/
├── fig.pdf / fig.svg / fig.png
├── plot.R（或 .py）
├── figure-spec.yaml      # 选了什么、为什么、dial 取值、数据映射
├── data-profile.md
├── qa-report.md          # 12 项检查结果
└── README-run.md         # 依赖、命令、复现步骤
```

### 7.4 降级路径

- 缺 R 包 → 给安装命令 + 代码 + 标注 `unverified`
- 数据列缺失 → 不猜，列 2–3 种可选映射让用户选
- 渲染超时/内存爆 → 降采样 + 说明，不静默改数据

### 7.5 渐进披露

`catalog/index.yaml` 每行 ≤120 字符；路由只读索引；命中后再读 archetype + 2–3 张 card；`references/core/*` 常驻但控制在 3 个文件内。

---

## 8. 质量验收

### 8.1 smoke 矩阵

12 archetypes × 2–3 presets × 结构变体 ≈ **40–50 次渲染**，每次断言：

- 退出码 0；PDF 存在且 > 10 KB；页面尺寸 = 请求尺寸 ±0.5 mm
- 无 `Inf`/`NaN` 警告；无「Removed N rows containing missing values」
- 渲染时间 < 10 s（fixture 规模）

### 8.2 十二项视觉检查

1. 文本无裁切（尤其 y 轴标签、图例、注释）
2. 标签无重叠（repel 或引线）
3. 图例在图内且不压数据
4. 最终尺寸下字号 5–7 pt
5. 线宽 ≥0.25 pt，点可见
6. CVD 模拟下类别可辨（protan/deutan）
7. 文本对比度 >4.5:1
8. 连续量不用彩虹色阶（viridis/magma/单色渐变）
9. 面板字母 8 pt 粗体、左上角、顺序正确
10. 字体嵌入且文本可编辑（不转曲）
11. 尺寸符合 89/183/≤170 mm
12. 坐标轴单位、刻度、数量级可读（log 轴标注）

### 8.3 自动化

- CVD：`colorspace::simulate_cvd()` 生成对照图 + 色差阈值
- 尺寸/字体：用 **PyMuPDF (`fitz`)** 读页面尺寸与嵌入字体（本机可用）；poppler 的 `pdffonts`/`pdfinfo` 未安装，不作依赖
- 溢出：渲染后跑 `svglite` 文本包围盒检查（粗筛），人工复核兜底
- CI：GitHub Actions（R 4.5 + Python 3.12），全矩阵 < 10 min；失败阻断合并

---

## 9. 版权、provenance 与学术诚信

1. **不存论文图**：catalog 只存结构化属性（配色、布局、注释策略）+ 出处，不存截图
2. **不 vendor 第三方代码**：只读参考；无 license 仓库一行代码都不复制
3. **示例图自绘**：card 的示例图用 fixture 渲染，不用论文原图
4. **措辞**：`inspired by` / `observed in`，不写 `reproduced from`
5. **provenance 必填**：DOI、图号、仓库 URL、commit、license、抓取日期；缺一项卡片不入库
6. **用户数据**：只在本地处理，不上传；交付包不含用户原始数据的副本（只含路径引用）

---

## 10. 里程碑

| 阶段 | 产出 | 工作量 | 验收 gate |
|---|---|---|---|
| M0 设计 | 本文 + SKILL.md 草案 | 0.5d | 决策台账无空白 |
| M0.5 导出 spike | `docs/env-probe.md` 补导出结论 | 0.5d | SVG/PNG/PDF 三条链路在本机跑通并定版 |
| M1 采集筛选 ✅ | `docs/corpus.csv`（200 篇）、`docs/code-audit.csv` | 1.5d | 已完成：200/200 全文，78 篇 Code availability，92 篇仓库链接 |
| M2 证据抽取 ✅ | `docs/figure-inventory.csv` + `catalog/styles/*` | 1.5d | 12 类每类 ≥25 篇、每卡 ≥3 篇证据 |
| M3 风格合成 ✅ | 39 张风格卡 + `decision-rules.md` | 3d | 每类 3–6 个预设，卡片含 DOI 证据（状态 draft） |
| M4 模板实现 ✅ | 12 模板 + 39 预设 + fixture | 6d | 冒烟 39/39，CVD 审计完成 |
| M5 路由与工作流 ✅ | `SKILL.md`、`manifest.yaml`、wf1–wf5 | 1.5d | 已软链安装并成功加载 |
| M6 质检文档 ✅ | `journal-specs.md`、`acceptance.md`、`style-audit.md` | 2d | 见验收报告 |
| M7 dogfood 🔶 | `examples/walkthrough-gwas.md` + demo 交付包 | 1d | 1/3 完成（脏 GWAS），余 2 个待真实数据 |

依赖关系：M1→M2→M3→M4 串行；M5 可与 M4 并行；M6 依赖 M4。

---

## 11. 风险登记

| # | 风险 | 影响 | 缓解 |
|---|---|---|---|
| R1 | 论文绘图代码稀缺（多为分析 pipeline） | 无法「复现论文代码」 | 改为「按范式重写」；T1/T2/T3 分级；期望管理写进 README |
| R2 | 仓库无 license | 法律风险 | 只读参考，不复制；卡片记 license 字段 |
| R3 | 非 OA 全文不可得 | 语料偏向 NC | 记录 OA 状态；用图注 + 方法补足；声明偏差 |
| R4 | 12×3 组合爆炸 | 维护失控 | style 参数化，不 fork 代码 |
| R5 | 风格主张无据 | 学术可信度受损 | 每卡 ≥3 篇支持 + 图号回指 |
| R6 | 包版本漂移 | CI 飘、用户跑不通 | renv/venv 锁版本；CI 固定矩阵 |
| R7 | 字体/CJK 问题 | 编辑退回 | 默认 Helvetica（Arial 在 cairo 下实测失败）；CJK 走 Noto Sans CJK；导出前检查 |
| R8 | 「调我的数据」需求模糊 | 来回返工 | 数据契约 + 自动诊断 + 明确失败信息 |
| R9 | 误用论文图 | 版权投诉 | 不存图、不截图、示例自绘 |
| R10 | 期刊规格变更 | 交付不合规 | journal-specs 单一来源，季度复核 |
| R11 | 导出链路不稳（本机 cairo_pdf 失败、svglite 未装） | 交不出「矢量 + 可编辑」的图 | M0.5 定版链路；主推 SVG；matplotlib PDF 兜底；CI 固定镜像 |

---

## 12. 需要你知道的三个判断

1. **「论文里可复现的绘图代码」比字面意思少。** 抽样两篇 2025 年 NC 泛基因组论文：一篇的 GitHub 仓库有 `visualization/` 目录但无 license，另一篇只有分析流程脚本、无 license。所以 skill 提供的是**按论文范式重写的、可运行、可回归测试的代码**，provenance 记录灵感来源——不是论文代码的搬运。如果你要的是「原样复现某篇论文的脚本」，这个设计需要改。

2. **语料定为 200 篇开放获取文献，NC 占 40%。** 六刊中 NC 全 OA，其余五刊只有部分 OA；按要求只取 OA，配额为 NC 80 / Nature 35 / NG 30 / NM 25 / NP 15 / NEE 15，每刊保底 15 篇、每图型 ≥10 篇。样本量足以支撑 12 个图型 × 2–3 风格（每卡仍需 ≥3 篇支持），但「某刊特有习惯」的统计力有限；若后续要补非 OA，可增量追加，不动现有卡片。

3. **有两处硬规格容易被忽略**：Nature 主图最大高度是 **170 mm**（不是常被误传的 247 mm），主图**不收 PNG/TIFF**（要矢量、文字可编辑），Extended Data 反过来只收 ≤300 dpi 的位图。这三条会让不少「看起来不错」的图在投稿时被打回，skill 的 audit 工作流会先拦一遍。

> 以上三条若不同意，回复即可，我改设计；否则按 M1 开工（先跑检索与筛选，产出可核对的语料清单，再动模板）。

---

## 13. 待定项（不阻塞 M1）

- 是否接 Zotero/BibTeX 导出（锦上添花，v1.1）
- composition 模块（多面板拼版）是否提前到 v1（当前排在 v1.1）
- 是否支持中文标注字体（默认 Arial；CJK 需按目标期刊确认）
- 是否内置「图注生成」（figure legend 草稿）—— 与 nature-writing 有重叠，倾向只做模板化图注骨架
