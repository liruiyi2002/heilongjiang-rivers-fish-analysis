# 底图数据 —— 来源与许可

[English](SOURCES.md) · **中文**

以下文件是两个公开数据集的小型裁剪子集，随仓库一并提供，使图 1 无需联网即可重绘。坐标已取整
（4 位小数，约 11 m；定位小图为 2 位小数），OpenStreetMap 河道已按约 180 m 的顶点间距简化。
这些均非研究数据 —— 采样点本身来自 [`../site_metadata.csv`](../site_metadata.csv) 与
[`../site_environment.csv`](../site_environment.csv)。

| 文件                            | 要素数   | 来源                                          | 许可             |
| ------------------------------ | -------- | --------------------------------------------- | ---------------- |
| `land_50m.geojson`             | 2        | Natural Earth 1:50m 国界（中国、俄罗斯）        | 公有领域         |
| `locator_countries.geojson`    | 11       | Natural Earth 1:50m 国界（东亚，2 位小数）      | 公有领域         |
| `provinces_cn.geojson`         | 1        | Natural Earth 1:50m 省界（黑龙江）              | 公有领域         |
| `lakes_10m.geojson`            | 2        | Natural Earth 1:10m 湖泊（含兴凯湖）            | 公有领域         |
| `rivers_named_10m.geojson`     | 7        | Natural Earth 1:10m 河流中心线                  | 公有领域         |
| `rivers_osm.geojson`           | 1069     | OpenStreetMap `waterway=river`/`canal`        | **ODbL 1.0**     |
| `places_osm.geojson`           | 10       | OpenStreetMap `place=city`/`town`             | **ODbL 1.0**     |

## 署名

- **Natural Earth** —— 公有领域，无需署名；此处出于惯例予以致谢。
  <https://www.naturalearthdata.com/>
- **OpenStreetMap** —— © OpenStreetMap 贡献者，依据开放数据库许可协议（ODbL）1.0 提供。
  <https://www.openstreetmap.org/copyright> · <https://opendatacommons.org/licenses/odbl/>

ODbL 属"相同方式共享"许可：若再分发这些子集或由其派生的数据库，必须保留上述署名与许可声明。
该义务**仅**适用于两个 `*_osm.geojson` 文件，并**独立于**本仓库其余部分的许可协议
（见 [`../../LICENSE`](../../LICENSE)）。图 1 页脚已含署名，图题中亦重复说明。

## 重新生成或扩展子集

这些子集裁剪自以下完整公开数据集：

- Natural Earth GeoJSON：<https://github.com/nvkelso/natural-earth-vector/tree/master/geojson>
- OpenStreetMap，经 Overpass API 获取范围 44.6–48.9 °N、132.0–135.8 °E 内的
  `waterway=river|canal`：<https://overpass-api.de/>

如需扩大制图范围或增加图层，请从上述来源重新获取并按新范围裁剪。

以上中文说明为便利性翻译，如有歧义以英文版为准。
