# Analysis code

**English** · [中文](README.zh-CN.md)

R scripts that reproduce **every result in the manuscript** from the tables in [`../data/`](../data).
They print the headline numbers to the console and write the supplementary tables to `../outputs/`.
No internet or raw sequence reads are needed (only a one-off package install on first run).

---

## Requirements

- **R ≥ 4.1** (for the native `|>` pipe; tested on 4.3.3).
- Figure 1 only: **Python ≥ 3.12** with Pillow — see
  [`map_generator/README.md`](map_generator/README.md). The R pipeline does not need it.
- Packages, **installed automatically** by `00_setup.R` if missing: `vegan`, `FD`, `iNEXT`,
  `indicspecies`, `cluster`, `dplyr`, `tidyr`, `purrr`, `stringr`, `glue`.
- **Figures:** `ggplot2`, `patchwork`, `scales`, `ggrepel`, installed by `figure_style.R` on first run.
- **Not required:** `betapart`. Script `03` computes the functional beta-diversity partition itself, from
  branch lengths on a UPGMA trait dendrogram.

## How to run

From the `reproducibility/` folder (the parent of this one):

```sh
Rscript code/run_all.R
```

That sources `01`–`09` in order. To run a single step (each one sources `00_setup.R` itself):

```sh
Rscript code/03_beta_diversity.R
```

**Order matters:** `05`, `06` and `07` read the alpha-diversity table that `02` writes, so run
`02` (or the whole pipeline) before them.

## Scripts

| File                        | What it does                                                               | Manuscript            |
| --------------------------- | -------------------------------------------------------------------------- | --------------------- |
| `00_setup.R`                | Load data, build matrices, attach/install packages, define constants.      | (sourced by all)      |
| `01_composition.R`          | Reads, order/family/genus counts, shared/unique taxa, coverage, dominants. | Results 3.1, Fig. 2, Tables S14, S18 |
| `02_alpha_diversity.R`      | Taxonomic and functional alpha; seasonal paired Wilcoxon (BH-FDR).         | Fig. 3, Table S1      |
| `03_beta_diversity.R`       | PERMANOVA, betadisper, PCoA and turnover/nestedness, taxonomic and functional. | Fig. 4            |
| `04_simper_leaveout.R`      | SIMPER; leave-one-out PERMANOVA; IndVal.g; migratory read share.           | Fig. S1, Tables S2-S4 |
| `05_taxonomy_function.R`    | Taxonomy-function coupling: Spearman (alpha), Mantel (beta).               | Fig. 5, Tables S5-S6  |
| `06_environment_gradient.R` | PCA; alpha vs PC1; composition vs PC1; dbRDA; Mantel/partial Mantel.       | Figs 6-8, Table 1, Tables S7-S8, S11-S13, S15-S17 |
| `07_water_quality_supp.R`   | Water quality and land cover vs alpha diversity; four dbRDA models.        | Fig. S2, Tables S9-S10 |
| `08_figures_main.R`         | Draws Figures 2-8 from `outputs/`, at journal specification.                | Figs 2-8              |
| `09_figures_supp.R`         | Draws Figures S1-S2 from `outputs/`, at journal specification.             | Figs S1-S2            |
| `figure_style.R`            | Artwork specification: column widths, 7 pt minimum, 500 dpi, palettes, save-and-verify. | (sourced by 08-09) |
| `run_all.R`                 | Run 01-09 in order, then report.                                           | -                     |
| `map_generator/`            | Figure 1 (study area + river-network position). **Python**; see its README. | Fig. 1                |

## Configuration

All tunable values live in the **"Analysis parameters"** block near the top of `00_setup.R`, so they
can be changed in one place:

- `SEASONS`, `SPRING`, `AUTUMN` — season labels used throughout.
- `RANDOM_SEED` — seed for the permutation tests (reproducibility).
- `N_PERM` (9999) — the permutation count for every test in the package. Pairwise section contrasts are
  exactly enumerated instead, because their group sizes admit few enough assignments.
- `FDR_ALPHA` (0.05) — significance threshold after Benjamini–Hochberg correction.
- `STAT_DP`, `PCT_DP`, `VAR_DP`, `DIST_DP`, `P_SIGFIG`, `P_FMT` — rounding / display precision.
- `NL`, `NAME_SEP` — newline and the `Season_Site[_replicate]` name separator.

Input file names (and the shared alpha-table path) are also constants in `00_setup.R`; each script
declares its own output-file constants at the top. A handful of script-specific parameters are defined
locally, e.g. `N_PCOA_AXES` (02), `N_TOP_SIMPER` / `AUTUMN_GROUP` / `CHUM_SALMON` (04),
`N_TOP_PRINT` (07), `EARTH_RADIUS_KM` (06).

## Inputs and outputs

- **Inputs:** the CSVs in [`../data/`](../data) — see [`../data/README.md`](../data/README.md) for what
  each one is and where it came from.
- **Outputs:** written to `../outputs/` (created automatically): `alpha_diversity_site_level.csv`,
  `Table_top_abundant_taxa.csv`, `Fig2_seasonal_occurrence.csv`, `beta_partition_taxonomic.csv`,
  `alpha_vs_PC1.csv`, `Table1_site_characteristics.csv`, and `TableS1`–`TableS18`.

## Conventions

- Every function carries a roxygen2 doc block (`#'` with `@param` / `@return`).
- Bilingual (English / 中文) file headers and section titles; 4-space indent; lines ≤ 120 chars.
- Repeated literals are named constants (see *Configuration*).
- `internal_processes/` (one level up) holds provenance scripts and working notes and is **not** part
  of the submission.

## License

Dual-licensed (both attribution + non-commercial): **code** under the PolyForm Noncommercial License
1.0.0 ([`../LICENSES/LICENSE-CODE`](../LICENSES/LICENSE-CODE)); **data and docs** under CC BY-NC 4.0
([`../LICENSES/LICENSE-DATA`](../LICENSES/LICENSE-DATA)); summary in [`../LICENSE`](../LICENSE). To cite, see
`../CITATION.cff` (or `../CITATION.bib` for BibTeX/LaTeX).
Repository: <https://github.com/liruiyi2002/heilongjiang-rivers-fish-analysis>;
archived release DOI (all versions): <https://doi.org/10.5281/zenodo.21622889>.
