# Figure 1 — study area map

**English** · [中文](README.zh-CN.md)

Draws the two-panel Figure 1: **(a)** the Ussuri study reach with the 13 eDNA sampling sites, and
**(b)** each site's position in the river network against distance to the Ussuri–Amur confluence.

This is the only part of the package written in **Python** rather than R, because it is a cartographic
drawing task. It is split in two:

| Path | Role |
| ------------------ | ------------------------------------------------------------------------------- |
| `cartokit/` | A general, reusable print-cartography library (see its own README and LICENSE) |
| `make_figure.py` | The study-specific script: site records, palette, panel layout, and the figure |

The map is generated using **`cartokit`, an open-source library created and supplied by Pouria
Hadjibagheri**, released under the PolyForm Noncommercial License 1.0.0 — attribution required,
noncommercial use only. The script in this folder holds only the study-specific content; all of the
cartography, print-metric sizing, and label placement come from that library.

## Requirements

- **Python ≥ 3.12** and **Pillow** (`pip install pillow`). Nothing else — no GIS stack, no network.
- A sans-serif TrueType font. Arial (Windows), DejaVu Sans (Linux) and Helvetica (macOS) are probed in
  turn; a system with none of them falls back to Pillow's built-in font and the script warns.

## How to run

From this folder:

```sh
python make_figure.py            # 150 dpi PNG proof + label audit
python make_figure.py --print    # 500 dpi TIFF and 300 dpi PNG for submission
```

Output goes to `../../outputs/`. The script exits non-zero if the audit is not clean, so it can be wired
into a check.

## Inputs

| Input | What it provides |
| --------------------------------- | ---------------------------------------------------- |
| `../../data/site_metadata.csv` | site code, name, river section, longitude, latitude |
| `../../data/site_environment.csv` | Strahler stream order and distance to the confluence |
| `../../data/geo/*.geojson` | clipped land, provinces, lakes, rivers and towns |

Basemap provenance and licences are in [`../../data/geo/SOURCES.md`](../../data/geo/SOURCES.md). The
OpenStreetMap layers are **ODbL**, so the credit line must stay on the figure.

## Artwork compliance

Sizes are declared in **physical units** — fonts in points, markers and spacing in millimetres, strokes
in points — against a stated print width, so the output holds its specification exactly:

- **190 mm** wide, the usual full-width (double-column) figure size.
- **All text ≥ 7 pt**, the common minimum for printed lettering; body labels sit at 7.5–8.5 pt, which
  also clears the ~2 mm label-height guidance some publishers apply.
- **500 dpi** TIFF for combination artwork, plus a 300 dpi PNG.

The width, minimum point size, and resolutions are named constants at the top of `make_figure.py`, so a
different specification is a one-line change rather than a re-layout.

Every label is placed through `cartokit`'s collision registry, and the script prints an **audit** after
rendering that reports any residual overlap, any dropped label, and any font below the minimum. A clean
run ends in `RESULT: PASS`; decorative graticule or lake labels may be dropped when space is tight,
which is expected and reported.

## Conventions

Marker **shape** repeats the section distinction carried by colour, so identity never depends on colour
alone; the three hues come from a colourblind-validated categorical order. Overlapping markers keep a
surface-coloured ring so they stay separable.

## Licensing note

`cartokit/` carries its own [`LICENSE`](cartokit/LICENSE) — PolyForm Noncommercial 1.0.0, copyright
Pouria Hadjibagheri, requiring attribution and permitting noncommercial use only. Everything else in
this repository is licensed as described in the repository [`LICENSE`](../../LICENSE): code under
PolyForm Noncommercial 1.0.0 and data under CC BY-NC 4.0. The two are the same licence with different
copyright holders, so no additional restriction is introduced by including the library here.
