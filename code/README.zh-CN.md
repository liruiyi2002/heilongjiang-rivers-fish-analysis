# 分析代码

[English](README.md) · **中文**

本目录的 R 脚本仅用 [`../data/`](../data) 中的数据即可重现稿件的**全部结果**，主要数值打印到控制台，附表写入
`../outputs/`。运行时无需联网或原始测序数据（仅首次运行时自动安装缺失的 R 包）。

---

## 环境要求

- **R ≥ 4.1**（原生 `|>` 管道；已在 4.3.3 上测试）。
- 首次运行时由 `00_setup.R` **自动安装**缺失的包：`vegan`、`FD`、`iNEXT`、`indicspecies`、`cluster`、
  `dplyr`、`tidyr`、`purrr`、`stringr`、`glue`。
- 可选：`betapart`。若未安装，脚本 `03` 会为功能 beta 多样性分解打印可直接运行的模板，其余结果照常运行。

## 如何运行

在 `reproducibility/` 目录（本目录的上一级）下：

```sh
Rscript code/run_all.R
```

该命令依次运行 `01`–`07`。也可单独运行某一步（每个脚本都会自行 source `00_setup.R`）：

```sh
Rscript code/03_beta_diversity.R
```

**顺序要求：** `05`、`06`、`07` 需要 `02` 写出的 alpha 多样性表，故请先运行 `02`（或整个流程）。

## 脚本

| 文件                        | 功能                                                     | 稿件对应           |
| --------------------------- | -------------------------------------------------------- | ------------------ |
| `00_setup.R`                | 载入数据、构建矩阵、加载/安装 R 包、定义常量。           | （被所有脚本调用） |
| `01_composition.R`          | 读数、目/科/属计数、共有/特有类群、覆盖度、优势类群。    | 结果 3.1、图 2     |
| `02_alpha_diversity.R`      | 分类与功能 alpha；季节配对 Wilcoxon（BH-FDR）。          | 图 3、表 S1        |
| `03_beta_diversity.R`       | PERMANOVA、betadisper、PCoA；周转/嵌套分解。             | 图 4               |
| `04_simper_leaveout.R`      | SIMPER；留一 PERMANOVA；IndVal.g；洄游读数占比。         | 图 S1、表 S2-S4    |
| `05_taxonomy_function.R`    | 分类-功能耦合：Spearman（alpha）、Mantel（beta）。       | 图 5、表 S5-S6     |
| `06_environment_gradient.R` | PCA；alpha 对 PC1；组成对 PC1；dbRDA；Mantel/偏 Mantel。 | 图 6-8、表 S7      |
| `07_water_quality_supp.R`   | 水质与 alpha 多样性（附加分析；不含土地利用）。          | 图 S2（部分）      |
| `run_all.R`                 | 依次运行 01-07。                                         | -                  |

## 配置

所有可调数值集中在 `00_setup.R` 顶部的 **“Analysis parameters”** 区块，可在一处修改：

- `SEASONS`、`SPRING`、`AUTUMN` —— 通用的季节标签。
- `RANDOM_SEED` —— 置换检验的随机种子（保证可重现）。
- `N_PERM`（9999）/ `N_PERM_QUICK`（999）—— 较重与较轻检验的置换次数。
- `FDR_ALPHA`（0.05）—— BH-FDR 校正后的显著性阈值。
- `STAT_DP`、`PCT_DP`、`VAR_DP`、`DIST_DP`、`P_SIGFIG`、`P_FMT` —— 取整/显示精度。
- `NL`、`NAME_SEP` —— 换行符与 `Season_Site[_replicate]` 名称分隔符。

输入文件名（及共享的 alpha 表路径）同样以常量定义在 `00_setup.R` 中；每个脚本在顶部声明各自的输出文件常量。少数
脚本特有的参数就地定义，例如 `N_PCOA_AXES`（02）、`N_TOP_SIMPER` / `AUTUMN_GROUP` / `CHUM_SALMON`（04）、
`N_TOP_PRINT`（07）、`EARTH_RADIUS_KM`（06）。

## 输入与输出

- **输入：** [`../data/`](../data) 中的 CSV —— 各文件的内容与来源见 [`../data/README.zh-CN.md`](../data/README.zh-CN.md)。
- **输出：** 写入 `../outputs/`（自动创建）：`alpha_diversity_site_level.csv`、`Table_top_abundant_taxa.csv`、
  `Fig2_seasonal_occurrence.csv`、`beta_partition_taxonomic.csv`、`alpha_vs_PC1.csv`，以及 `TableS1`–`TableS8`。

## 约定

- 每个函数均带 roxygen2 文档块（`#'`，含 `@param` / `@return`）。
- 双语（英文 / 中文）文件头与章节标题；4 空格缩进；每行 ≤ 120 字符。
- 重复出现的字面量均提取为具名常量（见“配置”）。
- 上一级的 `internal_processes/` 存放溯源脚本与内部工作笔记，**不**属于提交内容。

## 许可协议

双许可（均要求署名且仅限非商业使用）：**代码**采用 PolyForm Noncommercial License 1.0.0
（[`../LICENSE-CODE`](../LICENSE-CODE)，中文 [`../LICENSE-CODE.zh-CN`](../LICENSE-CODE.zh-CN)）；
**数据与文档**采用 CC BY-NC 4.0（[`../LICENSE-DATA`](../LICENSE-DATA)，中文
[`../LICENSE-DATA.zh-CN`](../LICENSE-DATA.zh-CN)）；概览见 [`../LICENSE`](../LICENSE)。引用方式见
`../CITATION.cff`（或 `../CITATION.bib`）。仓库：<https://github.com/liruiyi2002/heilongjiang-rivers-fish-analysis>。
