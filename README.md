# Ussuri River freshwater-fish eDNA — analysis code and data

**English** · [中文](README.zh-CN.md)

Reproducible R code and derived data for a 12S environmental-DNA (eDNA) metabarcoding study of the
freshwater fish community of the **Ussuri River** (a large transboundary tributary of the Amur /
Heilongjiang). The scripts reproduce every result in the manuscript — community composition, alpha and
beta diversity, taxonomic–functional coupling, and the longitudinal hydro-geographic gradient — from the
tables in [`data/`](data), with no internet access or raw sequence reads required.

*中文摘要：* 本仓库提供乌苏里江淡水鱼类 12S eDNA 宏条形码研究的可重现 R 代码与派生数据，仅用 `data/` 中的数据即可重现
稿件全部结果（群落组成、alpha 与 beta 多样性、分类—功能耦合、纵向水文—地理梯度），无需联网或原始测序数据。

## Repository layout

```
.
├── code/                 # analysis scripts 00–07, figure scripts 08–09 + run_all.R  (see code/README.md)
│   ├── figure_style.R      # journal artwork specification: widths, 7 pt minimum, 500 dpi, palettes
│   └── map_generator/      # Figure 1 study-area map  (Python + Pillow; see its README)
├── data/                 # input CSVs + README.md (data provenance: what each file is, where it's from)
│   └── geo/              # clipped basemap extracts for Figure 1  (see geo/SOURCES.md)
├── outputs/              # results and tables written by the scripts  (generated; not tracked in git)
├── figures/              # every figure as TIFF + PNG + PDF  (generated; not tracked in git)
├── README.md             # this file
├── CITATION.cff          # how to cite  (also CITATION.bib for BibTeX/LaTeX)
├── LICENSE               # dual-license summary
└── LICENSES/             # the licences themselves, and their Chinese versions
    ├── LICENSE-CODE      # PolyForm Noncommercial 1.0.0  (applies to code/)
    └── LICENSE-DATA      # CC BY-NC 4.0                   (applies to data/ and docs)
```

## Requirements

- **R ≥ 4.1** (native `|>` pipe; tested on 4.3.3).
- Packages are **installed automatically** on first run by `code/00_setup.R` and `code/figure_style.R`:
  `vegan`, `FD`, `iNEXT`, `indicspecies`, `cluster`, `ape`, `dplyr`, `tidyr`, `purrr`, `stringr`, `glue`,
  and for the figures `ggplot2`, `patchwork`, `scales`, `ggrepel`.
- **Python ≥ 3.12 with Pillow**, for Figure 1 only.
- No package outside that list is needed. The functional beta-diversity partition is computed here from
  branch lengths on a trait dendrogram, so `betapart` is **not** required.

## Quick start

```sh
git clone https://github.com/liruiyi2002/heilongjiang-rivers-fish-analysis.git
cd heilongjiang-rivers-fish-analysis
Rscript code/run_all.R                                # results, tables and Figures 2–8, S1–S2
python code/map_generator/make_figure.py --print      # Figure 1 (the study-area map)
```

That reproduces **everything the manuscript reports**: headline numbers print to the console, the
supplementary tables land in `outputs/`, and every figure lands in `figures/` as a 500 dpi LZW TIFF, a
matching PNG and a vector PDF. Each figure is drawn only from files in `outputs/`, so a figure cannot
disagree with the statistic it reports — change an analysis and the figure follows on the next run.
Artwork is written at the journal's own limits (90/140/190 mm column widths, 7 pt minimum lettering,
500 dpi for combination artwork). Lettering size is set by construction from a single constant rather
than measured; each figure's TIFF is measured after writing, and the run stops if any figure is out of
specification.

To run one step at a time, execute any `code/NN_*.R` script directly (each sources `code/00_setup.R`).
Scripts `05`–`07` need the alpha-diversity table written by `02`, and the figure scripts `08`–`09` need
`01`–`07`, so run the full pipeline first if in doubt. See [`code/README.md`](code/README.md) for a
per-script guide and the configurable parameters.

## Data

The input tables live in [`data/`](data); **[`data/README.md`](data/README.md)** documents each file
and its source. In brief: the site-by-species read table is the summed field replicates; the replicate-level
table, species taxonomy, and water-quality table derive from the sequencing provider's deliveries and
field measurements; the trait and hydro-geographic environment tables are compiled from FishBase, the
primary literature, and open datasets (HydroRIVERS, Copernicus GLO-90 DEM, NASA POWER, ESA WorldCover).

Raw FASTQ sequence reads are **not** part of this repository; they are to be deposited separately in the
NCBI Sequence Read Archive (see the manuscript's data-availability statement for the accession).

## Citation

Please cite the associated article together with this repository — see [`CITATION.cff`](CITATION.cff),
or [`CITATION.bib`](CITATION.bib) for a BibTeX/LaTeX entry. The archived release (v1.0.0) has a
persistent DOI on Zenodo: [10.5281/zenodo.21622889](https://doi.org/10.5281/zenodo.21622889). That DOI covers all versions and
resolves to the most recent; the results in the article were produced with **v1.1.0**.

## License

This repository is **dual-licensed**, both requiring attribution and permitting non-commercial use only:

- **Code** (`code/`) — [PolyForm Noncommercial License 1.0.0](LICENSES/LICENSE-CODE).
- **Data and documentation** (`data/`, `outputs/`, and the docs) — [Creative Commons
  Attribution-NonCommercial 4.0 International (CC BY-NC 4.0)](LICENSES/LICENSE-DATA).

See [`LICENSE`](LICENSE) for the summary and [`CITATION.cff`](CITATION.cff) / [`CITATION.bib`](CITATION.bib)
for how to attribute.
