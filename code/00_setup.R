# ======================================================================================================================
# 00_setup.R
#
# Shared setup
# ------------
# Loads every data table, builds the derived matrices, and attaches packages. Sourced by each analysis script (01-09).
# No internet or raw reads required.
#
# 共享初始化
# ----------
# 载入全部数据表、构建派生矩阵并加载 R 包；被每个分析脚本 (01-09) 调用。无需联网，也无需原始测序数据。
# ======================================================================================================================


# --- R packages: set the library path, install any that are missing, then attach --------------------------------------
# The user library is created before it is used and then named explicitly. `.libPaths()` silently DISCARDS a
# path that does not exist, so on a machine with no personal R library the first entry became the system
# library, which is not writable, and install.packages() failed with a non-zero exit. A reviewer on a fresh
# machine could not run this package at all.
# 先创建再显式指定用户库路径。`.libPaths()` 会静默丢弃不存在的路径，故在没有个人 R 库的机器上，首位路径会变成
# 不可写的系统库，install.packages() 随即以非零状态失败——审稿人在全新环境中根本无法运行本流程。
USER_LIB <- path.expand("~/R/library")
dir.create(USER_LIB, recursive = TRUE, showWarnings = FALSE)
.libPaths(c(USER_LIB, .libPaths()))

# vegan (ecology: distances, PERMANOVA, ordination), FD (functional diversity),
# iNEXT (sample coverage), indicspecies (IndVal.g), cluster (Gower distance),
# ape (trait dendrogram and corrected PCoA for the functional beta partition);
# dplyr / tidyr / purrr / stringr / glue (tidy data manipulation and strings).
# 以上为分析所需 R 包：生态学统计、功能多样性、覆盖度、指示种、性状距离与数据整理。
required_packages <- c("vegan", "FD", "iNEXT", "indicspecies", "cluster", "ape",
                       "dplyr", "tidyr", "purrr", "stringr", "glue")
missing_packages <- setdiff(required_packages, rownames(installed.packages()))
if (length(missing_packages)) {
    install.packages(missing_packages, lib = USER_LIB, repos = "https://cloud.r-project.org")
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
FIG_DIR   <- file.path(REPRO_DIR, "figures")     # submission-ready artwork, written by 08 and 09
dir.create(OUT_DIR, showWarnings = FALSE, recursive = TRUE)
dir.create(FIG_DIR, showWarnings = FALSE, recursive = TRUE)


# --- Data file names, and the one output shared between scripts -------------------------------------------------------
SITE_READS_FILE       <- "site_by_species_reads.csv"
REPLICATE_READS_FILE  <- "replicate_by_species_reads.csv"
SITE_METADATA_FILE    <- "site_metadata.csv"
SPECIES_TRAITS_FILE   <- "species_traits.csv"
SPECIES_TAXONOMY_FILE <- "species_taxonomy.csv"
GOWER_DIST_FILE       <- "gower_distance.csv"
SITE_ENV_FILE         <- "site_environment.csv"
WATER_QUALITY_FILE    <- "site_water_quality_seasonal.csv"
LAND_USE_FILE         <- "site_land_use.csv"
ALPHA_SITE_FILE       <- file.path(OUT_DIR, "alpha_diversity_site_level.csv")  # written by 02, read by 05-07


# --- Analysis parameters: adjust these in one place -------------------------------------------------------------------
SPRING  <- "Spring"
AUTUMN  <- "Autumn"
SEASONS <- c(SPRING, AUTUMN)

RANDOM_SEED  <- 1         # seed for the permutation-based tests
# One permutation count for every test in the package. A second, smaller count used to exist for the
# slower models; it made those tests quietly weaker than the 9,999 the manuscript quotes, and produced a
# boundary p-value in the local dbRDA whose significance moved with the seed.
# 全流程统一使用同一置换次数。此前另设较小的次数用于较慢的模型，致该等检验实际弱于稿件所述的 9,999 次，
# 并使局部 dbRDA 出现随随机种子摆动的临界 p 值。
N_PERM       <- 9999      # permutations for PERMANOVA, Mantel and betadisper

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
# 站点级读数为每站三个野外重复之和。
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
# 每站每季三个重复；求和后与站点级表完全一致。
replicate_reads <- as.matrix(read_data(REPLICATE_READS_FILE, row.names = 1))

# Row names look like "Spring_W01_1" -> split into season / site / replicate.
# 行名形如 Spring_W01_1，据此拆分为季节 / 站点 / 重复。
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
# (Figs 6-8); water quality and land cover back the supplementary Fig. S2 only.
# 水文—地理描述量（13 站点），主梯度分析的输入。
env <- read_data(SITE_ENV_FILE, stringsAsFactors = FALSE)
rownames(env) <- env$site
ENV_VARS <- c("elev_m", "strahler", "log_drainage", "log_discharge", "log_width",
              "grad_dem", "dist_source_km", "dist_mouth_km", "MAT_C", "MAP_mm")

# Water quality is measured once per site AND season, so it is kept long and joined on both keys.
# 水质按站点与季节各测一次，故保持长表并按双键合并。
water_quality      <- read_data(WATER_QUALITY_FILE, stringsAsFactors = FALSE)
WATER_QUALITY_VARS <- c("temperature_C", "pH", "conductivity_uS_cm", "dissolved_oxygen_mg_L",
                        "total_phosphorus_mg_L", "total_nitrogen_mg_L", "ammonia_nitrogen_mg_L")

# Land cover is a fixed site property (shares of the classified area in a 2 km buffer), so one row per site.
# The pixel count and buffer area travel with the table for transparency but are not analysis variables.
# 土地覆被为站点固定属性（2 km 缓冲区内各类占比），每站一行。
land_use      <- read_data(LAND_USE_FILE, row.names = 1)
LAND_USE_VARS <- c("cropland", "forest", "shrub", "grassland", "water", "snow_ice", "barren",
                   "impervious", "wetland")


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
