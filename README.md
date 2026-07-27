# Ussuri River freshwater-fish eDNA — analysis code and data

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
├── code/                 # analysis scripts 00–07 + run_all.R  (see code/README.md)
├── data/                 # input CSVs + DATA_PROVENANCE.docx (what each file is and where it came from)
├── outputs/              # tables written by the scripts  (generated; not tracked in git)
├── README.md             # this file
├── README.docx           # the same overview as a Word document (for journal submission)
├── LICENSE               # CC BY-NC 4.0
└── CITATION.cff          # how to cite
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

The input tables live in [`data/`](data); **`data/DATA_PROVENANCE.docx`** documents each file and its
source. In brief: the site-by-species read table is the summed field replicates; the replicate-level
table, species taxonomy, and water-quality table derive from the sequencing provider's deliveries and
field measurements; the trait and hydro-geographic environment tables are compiled from FishBase, the
primary literature, and open datasets (HydroRIVERS, Copernicus GLO-90 DEM, NASA POWER, ESA WorldCover).

Raw FASTQ sequence reads are **not** part of this repository; they are to be deposited separately in the
NCBI Sequence Read Archive (see the manuscript's data-availability statement for the accession).

## Citation

Please cite the associated article together with this repository — see [`CITATION.cff`](CITATION.cff).

## License

Code, data, and documentation are released under the **Creative Commons Attribution-NonCommercial 4.0
International License (CC BY-NC 4.0)** — free to share and adapt **with attribution** and **for
non-commercial purposes**. See [`LICENSE`](LICENSE).
