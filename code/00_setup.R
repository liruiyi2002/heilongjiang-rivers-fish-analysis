# ======================================================================================================================
# 00_setup.R
#
# Shared setup
# ------------
# Loads every data table, builds the derived matrices, and attaches packages. Sourced by each analysis script (01-07).
# No internet or raw reads required.
#
# 共享初始化
# ----------
# 载入全部数据表、构建派生矩阵并加载 R 包；被每个分析脚本 (01-07) 调用。无需联网，也无需原始测序数据。
# ======================================================================================================================


# --- R packages: set the library path, install any that are missing, then attach --------------------------------------
.libPaths(c("~/R/library", .libPaths()))

# vegan (ecology: distances, PERMANOVA, ordination), FD (functional diversity),
# iNEXT (sample coverage), indicspecies (IndVal.g), cluster (Gower distance);
# dplyr / tidyr / purrr / stringr / glue (tidy data manipulation and strings).
required_packages <- c("vegan", "FD", "iNEXT", "indicspecies", "cluster",
                       "dplyr", "tidyr", "purrr", "stringr", "glue")
missing_packages <- setdiff(required_packages, rownames(installed.packages()))
if (length(missing_packages)) {
    install.packages(missing_packages, repos = "https://cloud.r-project.org")
}
suppressMessages(invisible(lapply(required_packages, library, character.only = TRUE)))


# --- Locate the package folders from this script's own path -----------------------------------------------------------
command_args <- commandArgs(trailingOnly = FALSE)
this_file    <- sub("^--file=", "", grep("^--file=", command_args, value = TRUE))

CODE_DIR <- if (length(this_file)) {
    normalizePath(dirname(gsub("~\\+~", " ", this_file)))       # Rscript run
} else if (file.exists("00_setup.R")) {
    normalizePath(".")                                          # sourced from code/
} else {
    normalizePath("code")                                       # sourced from the package root
}

REPRO_DIR <- normalizePath(file.path(CODE_DIR, ".."))
DATA_DIR  <- file.path(REPRO_DIR, "data")
OUT_DIR   <- file.path(REPRO_DIR, "outputs")
dir.create(OUT_DIR, showWarnings = FALSE, recursive = TRUE)


# --- Data file names, and the one output shared between scripts -------------------------------------------------------
SITE_READS_FILE       <- "site_by_species_reads.csv"
REPLICATE_READS_FILE  <- "replicate_by_species_reads.csv"
SITE_METADATA_FILE    <- "site_metadata.csv"
SPECIES_TRAITS_FILE   <- "species_traits.csv"
SPECIES_TAXONOMY_FILE <- "species_taxonomy.csv"
GOWER_DIST_FILE       <- "gower_distance.csv"
SITE_ENV_FILE         <- "site_environment.csv"
WATER_QUALITY_FILE    <- "site_water_quality.csv"
ALPHA_SITE_FILE       <- file.path(OUT_DIR, "alpha_diversity_site_level.csv")  # written by 02, read by 05-07


# --- Analysis parameters: adjust these in one place -------------------------------------------------------------------
SPRING  <- "Spring"
AUTUMN  <- "Autumn"
SEASONS <- c(SPRING, AUTUMN)

RANDOM_SEED  <- 1         # seed for the permutation-based tests
N_PERM       <- 9999      # permutations for PERMANOVA, Mantel and betadisper
N_PERM_QUICK <- 999       # permutations for SIMPER, IndVal.g, dbRDA and leave-one-out

FDR_ALPHA <- 0.05         # significance threshold after BH-FDR correction

STAT_DP  <- 3             # decimals for statistics (means, R2, rho)
PCT_DP   <- 2             # decimals for percentages
VAR_DP   <- 1             # decimals for percentage-of-variance
DIST_DP  <- 4             # decimals for distance / beta-partition values
P_SIGFIG <- 3             # significant figures for p-values
P_FMT    <- "%.4f"        # sprintf format for displayed p-values

NL       <- "\n"          # newline for cat()
NAME_SEP <- "_"           # separator in the Season_Site[_replicate] sample names


# --- Data reader ------------------------------------------------------------------------------------------------------

#' Read a CSV from the data folder, keeping original column names. / 读取 data/ 中的 CSV，保留原始列名。
#'
#' @param file_name File name inside data/.
#' @param ... Extra arguments passed to read.csv (e.g. row.names).
#' @return A data frame with column names left untouched.
read_data <- function(file_name, ...) read.csv(file.path(DATA_DIR, file_name), check.names = FALSE, ...)


# --- Site-level community table (26 site-seasons x 100 taxa) ----------------------------------------------------------
# Reads summed across the three field replicates per site (see replicate table).
reads <- as.matrix(read_data(SITE_READS_FILE, row.names = 1))

meta <- read_data(SITE_METADATA_FILE, stringsAsFactors = FALSE)
meta <- meta[match(rownames(reads), meta$sample), ]           # align to the read table

season  <- factor(meta$season, levels = SEASONS)              # Spring 2023, Autumn 2024
site    <- meta$site
section <- factor(meta$section, levels = c("Upstream", "Downstream", "Tributary"))

rel <- sweep(reads, 1, rowSums(reads), "/")                   # relative sequence abundance / 相对丰度
presence_absence <- (reads > 0) * 1L                          # presence-absence / 有无矩阵


# --- Replicate-level table (78 samples x 100 taxa) --------------------------------------------------------------------
# Three replicates per site per season; sums exactly to the site-level table.
# Used for incidence-based sample coverage. Row names are Season_Site_replicate.
replicate_reads <- as.matrix(read_data(REPLICATE_READS_FILE, row.names = 1))

# Row names look like "Spring_W01_1" -> split into season / site / replicate.
name_parts     <- str_split_fixed(rownames(replicate_reads), NAME_SEP, 3)
replicate_meta <- data.frame(
    sample = rownames(replicate_reads),
    season = name_parts[, 1],
    site   = name_parts[, 2],
    rep    = name_parts[, 3],
    stringsAsFactors = FALSE
)


# --- Species traits, taxonomy and functional distance -----------------------------------------------------------------
traits <- read_data(SPECIES_TRAITS_FILE, stringsAsFactors = FALSE)
rownames(traits) <- traits$Species_code

taxonomy <- read_data(SPECIES_TAXONOMY_FILE, stringsAsFactors = FALSE)
rownames(taxonomy) <- taxonomy$species                        # species -> order / family / genus

gower_dist <- read_data(GOWER_DIST_FILE, row.names = 1) |>
    as.matrix() |>
    as.dist()                                                 # species x species Gower distance


# --- Environment ------------------------------------------------------------------------------------------------------
# Hydro-geographic descriptors (13 sites) drive the main gradient analysis
# (Figs 6-8); the water-quality set (8 vars) backs the supplementary Fig. S2 only.
env <- read_data(SITE_ENV_FILE, stringsAsFactors = FALSE)
rownames(env) <- env$site
ENV_VARS <- c("elev_m", "strahler", "log_drainage", "log_discharge", "log_width",
              "grad_dem", "dist_source_km", "dist_mouth_km", "MAT_C", "MAP_mm")

water_quality <- read_data(WATER_QUALITY_FILE, row.names = 1)


# --- Per-season community and the site environment aligned to it ------------------------------------------------------

#' Community and matching environment for one season. / 单季节的群落及对应环境。
#'
#' Bundles the reads, relative abundances and presence-absence for one season with
#' the per-site environment, all in the same site order (ready for paired analyses).
#'
#' @param season_name Season label, "Spring" or "Autumn".
#' @return A list: reads, rel, presence_absence, env (one row per site) and site_ids.
season_subset <- function(season_name) {
    in_season <- season == season_name
    site_ids  <- meta$site[match(rownames(reads)[in_season], meta$sample)]

    list(
        reads            = reads[in_season, , drop = FALSE],
        rel              = rel[in_season, , drop = FALSE],
        presence_absence = presence_absence[in_season, , drop = FALSE],
        env              = env[site_ids, , drop = FALSE],
        site_ids         = site_ids
    )
}

season_counts <- paste(table(season), collapse = "/")
cat(glue("setup OK: {nrow(reads)} site-seasons x {ncol(reads)} taxa; ",
         "seasons {season_counts}; replicates {nrow(replicate_reads)}"), NL)
