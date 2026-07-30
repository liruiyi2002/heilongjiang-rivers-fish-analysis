# 数据溯源

[English](README.md) · **中文**

本目录中每个文件的内容与来源。数值精度保持在数据可支撑的水平：Gower 距离保留 4 位小数；坐标与 PC 得分 3 位小数；
连续型性状 1-2 位小数；读数为整数。

## 文件

| 文件                             | 内容与来源                                                     |
| -------------------------------- | -------------------------------------------------------------- |
| `site_by_species_reads.csv`      | 26 站点-季节 x 100 类群；eDNA 读数；野外三重复之精确加和。     |
| `replicate_by_species_reads.csv` | 78 样本 x 100 类群；重复级读数（春 = BZ2023，秋 = BZ2024）。   |
| `species_taxonomy.csv`           | 100 类群对应的属 / 科 / 目（12 / 27 / 72）；源自测序公司谱系。 |
| `species_traits.csv`             | 100 类群 x 9 项功能性状；FishBase、区域文献、原始文献。        |
| `trait_value_glossary.csv`       | 分类型性状取值的原文与英文对照。                               |
| `gower_distance.csv`             | 100 x 100 类群间 Gower 距离；由 species_traits.csv 计算。      |
| `site_environment.csv`           | 13 站点 x 水文-地理变量与 PC1-PC3；源自开放数据集。            |
| `site_metadata.csv`              | 26 站点-季节：站点、季节、河段、名称、河道类型、坐标。         |
| `site_water_quality.csv`         | 13 站点 x 8 项水质变量；**仅春季**——见下文说明。               |
| `site_water_quality_seasonal.csv` | 26 站点-季节 x 7 项变量（含氨氮）；作者的野外/实验室数据表。   |
| `site_land_use.csv`              | 13 站点 x 9 类 CLCD 土地覆被比例（2 km 缓冲区）及像元计数。    |
| `geo/`                           | 图 1 所用底图裁剪子集——见 [`geo/SOURCES.zh-CN.md`](geo/SOURCES.zh-CN.md)。 |

## 群落数据的构建

测序公司两次交付各含 13 站点 × 3 个野外重复。按站点求和即得站点级表（`site_by_species_reads.csv`），且季节归属明确：
**BZ2023 = 春季**（2023 年 4 月采样），**BZ2024 = 秋季**（2024 年 10 月采样）。大麻哈鱼（*Oncorhynchus keta*，
秋季产卵洄游）在秋季交付中约占读数的 14%，在春季交付中约为 0%。重复求和可精确重现站点级表（在全部 2,600 个
类群 × 站点-季节单元中最大差异为 0）。

原始 FASTQ 测序数据**不**包含于此；将提交至 NCBI 序列读取档案库（SRA）并在稿件中引用。上游生物信息学分析
（读数 → 物种表）由测序公司完成，不属于本包。

## 环境数据

**水质。** `site_water_quality_seasonal.csv` 收录作者两个季节的实测数据：水温、pH、电导率、溶解氧、
总磷、总氮与氨氮。野外指标使用 YSI ProQuatro 水质仪测定，营养盐于实验室测定。请优先使用该文件；
`site_water_quality.csv` 为保持连续性而保留，但**仅含春季数值**（其另有硬度与透明度两项，不属于作者
数据表，且缺少氨氮）。

**土地覆被。** `site_land_use.csv` 给出各站点 **2 km 缓冲区**内 CLCD 九个类别的比例，由原始分类像元
计数计算（CLCD 30 m；Yang & Huang, 2021）。缓冲半径由计数本身确认：五个内陆支流缓冲区各覆盖
12.55 km²，而 pi x 2^2 = 12.57 km²。CLCD 仅覆盖中国境内，因此八个界河站点的缓冲区在河道处被截断
（5.4–8.8 km²）；比例系相对于**已分类**面积，故一并给出 `classified_pixels` 与 `buffer_area_km2`
以明确说明。土地覆被为站点固有属性，不随季节变化。各站点冰雪类别均为 0。

## 类群命名

有一个类群在两套注释中名称不同：本研究的 *Chanodichthys erythropterus* 在测序公司当前参考库中记为
*Chanodichthys ilishaeformis*（同属、读数完全相同）。此处沿用本研究采用的名称。

## 许可协议

本仓库的数据与文档采用 **CC BY-NC 4.0**（署名、非商业使用）；分析代码另行采用 **PolyForm Noncommercial License
1.0.0**。见 `../LICENSE`、`../LICENSE-DATA`（中文 `../LICENSE-DATA.zh-CN`）与 `../LICENSE-CODE`
（中文 `../LICENSE-CODE.zh-CN`）。
