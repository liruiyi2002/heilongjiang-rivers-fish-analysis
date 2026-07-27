# Ussuri River freshwater-fish eDNA — analysis code and data

**English** · [中文](README.zh-CN.md)

Reproducible R code and derived data for a 12S environmental-DNA (eDNA) metabarcoding study of the
freshwater fish community of the **Ussuri River** (a large transboundary tributary of the Amur /
Heilongjiang). The scripts reproduce every result in the manuscript — community composition, alpha and
beta diversity, taxonomic–functional coupling, and the longitudinal hydro-geographic gradient — from the
tables in [`data/`](data), with no internet access or raw sequence reads required.

## Repository layout

```
.
├── code/                 # analysis scripts 00–07 + run_all.R  (see code/README.md)
├── data/                 # input CSVs + README.md (data provenance: what each file is, where it's from)
├── outputs/              # tables written by the scripts  (generated; not tracked in git)
├── README.md             # this file
├── CITATION.cff          # how to cite  (also CITATION.bib for BibTeX/LaTeX)
├── LICENSE               # dual-license summary
├── LICENSE-CODE          # PolyForm Noncommercial 1.0.0  (applies to code/)
└── LICENSE-DATA          # CC BY-NC 4.0                   (applies to data/ and docs)
```

## Requirements

- **R ≥ 4.1** (native `|>` pipe; tested on 4.3.3).
- Packages are **installed automatically** on first run by `code/00_setup.R`: `vegan`, `FD`, `iNEXT`,
  `indicspecies`, `cluster`, `dplyr`, `tidyr`, `purrr`, `stringr`, `glue`.
- Optional: `betapart` (script `03` prints a ready-to-run template if it is absent).

## Quick start

```sh
git clone https://github.com/liruiyi2002/heilongjiang-rivers-fish-analysis.git
cd heilongjiang-rivers-fish-analysis
Rscript code/run_all.R
```

Headline numbers print to the console; the supplementary tables are written to `outputs/`. To run one
step at a time, execute any `code/NN_*.R` script directly (each sources `code/00_setup.R`); note that
`05`, `06` and `07` need the alpha-diversity table written by `02`, so run `02` (or the full pipeline)
first. See [`code/README.md`](code/README.md) for a per-script guide and the configurable parameters.

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
or [`CITATION.bib`](CITATION.bib) for a BibTeX/LaTeX entry.

## License

This repository is **dual-licensed**, both requiring attribution and permitting non-commercial use only:

- **Code** (`code/`) — [PolyForm Noncommercial License 1.0.0](LICENSE-CODE).
- **Data and documentation** (`data/`, `outputs/`, and the docs) — [Creative Commons
  Attribution-NonCommercial 4.0 International (CC BY-NC 4.0)](LICENSE-DATA).

See [`LICENSE`](LICENSE) for the summary and [`CITATION.cff`](CITATION.cff) / [`CITATION.bib`](CITATION.bib)
for how to attribute.
