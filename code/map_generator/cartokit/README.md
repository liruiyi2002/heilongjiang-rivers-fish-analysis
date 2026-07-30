# cartokit

A small, dependency-light cartographic drawing toolkit for **print-quality figures**. It sits directly
on Pillow and does two things a general plotting library does not:

1. **Every size is physical.** Fonts are given in points, markers and spacing in millimetres, strokes in
   points, all against a declared print width and resolution. A label asked for at 8 pt is 8 pt on the
   printed page whatever the render resolution, so a fast low-resolution proof and a 500 dpi submission
   render cannot drift apart.
2. **Labels never overprint.** Every piece of text is placed through a collision registry that reserves
   the footprints of the data marks first. A label that cannot be placed is dropped and reported rather
   than drawn on top of something else, and an audit pass re-checks the finished figure.

There is no GIS stack and no network requirement: geometry comes from plain GeoJSON, and the only
third-party dependency is Pillow.

## Modules

| Module | Contents |
| ------------- | ---------------------------------------------------------------------------------------- |
| `layout.py`   | `FigureMetrics` (millimetre, point, and dpi conversion; font loading), `FontWeight` |
| `geometry.py` | `AlbersEqualArea`, `Viewport`, `Coordinate`, `ground_distance_km` |
| `geojson.py`  | `GeoFeature`, `load_feature_collection`, `polygon_rings`, `line_strings` |
| `labels.py`   | `LabelSet`, `Rectangle`, `LabelOffset`, `LabelAudit`, `report_audit` |
| `drawing.py`  | `Symbol`, `LegendEntry`, polygon/line/marker primitives, graticule, scale bar, north arrow, legend |

## Usage

```python
from cartokit import (
    AlbersEqualArea, FigureMetrics, FontWeight, LabelSet, Symbol, Viewport, draw_marker, report_audit,
)

metrics = FigureMetrics(width_mm=190.0, height_mm=150.0, dpi=500, supersample=2, minimum_point_size=7.0)
canvas = Image.new("RGB", (metrics.canvas_width, metrics.canvas_height), "#fcfcfb")
draw = ImageDraw.Draw(canvas)

viewport = Viewport(AlbersEqualArea(134.0, 47.0, 45.6, 48.4), (132.95, 45.28, 135.10, 48.52),
                    metrics.canvas_width, metrics.canvas_height)
labels = LabelSet(width=metrics.canvas_width, height=metrics.canvas_height, padding=metrics.mm(0.35))

x, y = viewport(134.03, 46.80)
draw_marker(draw, x, y, Symbol.CIRCLE, metrics.mm(0.95), "#2a78d6", ring="#fcfcfb", ring_width=metrics.pt(0.75))
labels.reserve(labels.text_box(draw, (x, y), "W03", metrics.font(8.5, FontWeight.BOLD), "lm"), "site-W03")

report_audit((labels.audit("map"),), metrics.undersized_points, metrics.minimum_point_size)
canvas.resize((metrics.width_px, metrics.height_px), Image.LANCZOS).save("figure.tif", dpi=(500, 500))
```

Reserve the marks before drawing decoration, then let `LabelSet.anchored` search a list of candidate
offsets for each label; the audit tells you what, if anything, had to be dropped.

## Requirements

Python ≥ 3.12 (PEP 695 `type` aliases, `match` statements) and Pillow.

## Licence

**PolyForm Noncommercial License 1.0.0** — see [`LICENSE`](LICENSE).

Copyright (c) 2026 Pouria Hadjibagheri.

Two conditions follow from that licence:

- **Attribution is required.** The licence's *Notices* clause obliges you to pass on the
  `Required Notice: Copyright (c) 2026 Pouria Hadjibagheri` line with any copy or derivative.
- **Noncommercial use only.** Permitted purposes are personal use, research, teaching, and other
  noncommercial work, as defined in the licence text.

This licence covers `cartokit` only. The surrounding repository is licensed separately; see the
repository `LICENSE` file.
