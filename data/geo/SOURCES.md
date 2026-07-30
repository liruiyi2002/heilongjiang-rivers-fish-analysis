# Basemap extracts — sources and licences

**English** · [中文](SOURCES.zh-CN.md)

These files are small clipped extracts of two public datasets, committed so that Figure 1 can be
redrawn without network access. Coordinates are rounded (4 dp, ~11 m; 2 dp for the locator) and the
OpenStreetMap channels are simplified to a ~180 m vertex spacing. Nothing here is study data — the
sampling sites themselves come from [`../site_metadata.csv`](../site_metadata.csv) and
[`../site_environment.csv`](../site_environment.csv).

| File | Features | Source | Licence |
| ------------------------------ | -------- | ------------------------------------------------- | ---------------- |
| `land_50m.geojson`             | 2        | Natural Earth 1:50m admin-0 (China, Russia)       | Public domain    |
| `locator_countries.geojson`    | 11       | Natural Earth 1:50m admin-0 (East Asia, 2 dp)     | Public domain    |
| `provinces_cn.geojson`         | 1        | Natural Earth 1:50m admin-1 (Heilongjiang)        | Public domain    |
| `lakes_10m.geojson`            | 2        | Natural Earth 1:10m lakes (incl. Lake Khanka)     | Public domain    |
| `rivers_named_10m.geojson`     | 7        | Natural Earth 1:10m river centrelines             | Public domain    |
| `rivers_osm.geojson`           | 1069     | OpenStreetMap `waterway=river`/`canal`            | **ODbL 1.0**     |
| `places_osm.geojson`           | 10       | OpenStreetMap `place=city`/`town`                 | **ODbL 1.0**     |

## Attribution

- **Natural Earth** — public domain, no attribution required; credited as a courtesy.
  <https://www.naturalearthdata.com/>
- **OpenStreetMap** — © OpenStreetMap contributors, available under the Open Database Licence
  (ODbL) 1.0. <https://www.openstreetmap.org/copyright> · <https://opendatacommons.org/licenses/odbl/>

The ODbL is a share-alike licence: if you redistribute these extracts, or a database derived from
them, you must keep this attribution and licence notice. This obligation applies to the two
`*_osm.geojson` files only, and is **separate from** the licences covering the rest of this
repository (see [`../../LICENSE`](../../LICENSE)). Figure 1 carries the credit line in its footer,
and the figure legend repeats it.

## Regenerating or extending the extracts

The extracts were cut from the full public datasets:

- Natural Earth GeoJSON: <https://github.com/nvkelso/natural-earth-vector/tree/master/geojson>
- OpenStreetMap via the Overpass API, `waterway=river|canal` within
  44.6–48.9 °N, 132.0–135.8 °E: <https://overpass-api.de/>

To widen the map extent or add layers, refetch from those sources and clip to the new window.
