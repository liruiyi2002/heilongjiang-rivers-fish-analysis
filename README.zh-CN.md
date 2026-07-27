# 乌苏里江淡水鱼类 eDNA —— 分析代码与数据

[English](README.md) · **中文**

本仓库提供乌苏里江（阿穆尔河 / 黑龙江的大型跨境支流）淡水鱼类 12S 环境 DNA（eDNA）宏条形码研究的可重现 R 代码与派生
数据。脚本仅用 [`data/`](data) 中的数据即可重现稿件的全部结果——群落组成、alpha 与 beta 多样性、分类—功能耦合，
以及纵向水文—地理梯度——无需联网或原始测序数据。

## 仓库结构

```
.
├── code/                 # 分析脚本 00–07 + run_all.R（见 code/README.md）
├── data/                 # 输入 CSV + README.md（数据溯源：各文件的内容与来源）
├── outputs/              # 脚本生成的结果表（自动生成；不纳入 git）
├── README.md             # 英文说明
├── README.zh-CN.md       # 本文件（中文说明）
├── CITATION.cff          # 引用信息（BibTeX/LaTeX 见 CITATION.bib）
├── LICENSE               # 双许可协议概览（中文见 LICENSE.zh-CN）
├── LICENSE-CODE          # PolyForm Noncommercial 1.0.0（适用于 code/；中文见 LICENSE-CODE.zh-CN）
└── LICENSE-DATA          # CC BY-NC 4.0（适用于 data/ 与文档；中文见 LICENSE-DATA.zh-CN）
```

## 环境要求

- **R ≥ 4.1**（原生 `|>` 管道；已在 4.3.3 上测试）。
- 首次运行时由 `code/00_setup.R` **自动安装**缺失的包：`vegan`、`FD`、`iNEXT`、`indicspecies`、`cluster`、
  `dplyr`、`tidyr`、`purrr`、`stringr`、`glue`。
- 可选：`betapart`（脚本 `03` 在其缺失时打印可直接运行的模板）。

## 快速开始

```sh
git clone https://github.com/liruiyi2002/heilongjiang-rivers-fish-analysis.git
cd heilongjiang-rivers-fish-analysis
Rscript code/run_all.R
```

主要数值打印到控制台，附表写入 `outputs/`。也可单独运行任一 `code/NN_*.R` 脚本（每个都会 source
`code/00_setup.R`）；注意 `05`、`06`、`07` 需要 `02` 写出的 alpha 多样性表，请先运行 `02`（或整个流程）。逐脚本
说明与可调参数见 [`code/README.zh-CN.md`](code/README.zh-CN.md)。

## 数据

输入数据表位于 [`data/`](data)；**[`data/README.zh-CN.md`](data/README.zh-CN.md)** 说明各文件及其来源。简言之：
站点级读数表为野外三重复之和；重复级表、物种分类与水质表源自测序公司交付数据与野外测量；性状与水文—地理环境表整理
自 FishBase、原始文献及开放数据集（HydroRIVERS、Copernicus GLO-90 DEM、NASA POWER、ESA WorldCover）。

原始 FASTQ 测序数据**不**包含于本仓库；将另行提交至 NCBI 序列读取档案库（SRA），登录号见稿件的数据可用性声明。

## 引用

请同时引用相关文章与本仓库——见 [`CITATION.cff`](CITATION.cff)，或 [`CITATION.bib`](CITATION.bib)（BibTeX/LaTeX）。

## 许可协议

本仓库采用**双许可**，两者均要求署名且仅限非商业使用：

- **代码**（`code/`）—— [PolyForm Noncommercial License 1.0.0](LICENSE-CODE)（中文说明见
  [`LICENSE-CODE.zh-CN`](LICENSE-CODE.zh-CN)）。
- **数据与文档**（`data/`、`outputs/` 及文档）—— [知识共享 署名—非商业性使用 4.0 国际
  （CC BY-NC 4.0）](LICENSE-DATA)（中文说明见 [`LICENSE-DATA.zh-CN`](LICENSE-DATA.zh-CN)）。

概览见 [`LICENSE`](LICENSE)（中文见 [`LICENSE.zh-CN`](LICENSE.zh-CN)）。以上中文许可说明均为便利性翻译，如有歧义
以英文版为准。
