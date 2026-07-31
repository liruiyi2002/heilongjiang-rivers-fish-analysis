# ======================================================================================================================
# 04_simper_leaveout.R
#
# Drivers of the seasonal signal (Fig. S1, Tables S2-S4)
# ------------------------------------------------------
# SIMPER, leave-one-out PERMANOVA (chum salmon / autumn indicators / migratory taxa), IndVal.g indicator taxa, and
# migratory read shares.
#
# 季节信号的驱动类群（图 S1，表 S2-S4）
# -------------------------------------
# SIMPER、留一 PERMANOVA（大麻哈鱼 / 秋季指示种 / 洄游类群）、IndVal.g 指示种、洄游读数占比。
# ======================================================================================================================


# --- Load shared setup ------------------------------------------------------------------------------------------------
.args <- commandArgs(trailingOnly = FALSE)
.file <- sub("^--file=", "", grep("^--file=", .args, value = TRUE))
.dir  <- if (length(.file)) dirname(gsub("~\\+~", " ", .file)) else "."
source(file.path(.dir, "00_setup.R"))
set.seed(RANDOM_SEED)

# Output files written by this script, plus a few analysis parameters.
# 本脚本的输出文件及若干分析参数。
SIMPER_FILE    <- file.path(OUT_DIR, "TableS2_simper_top15.csv")
LEAVEOUT_FILE  <- file.path(OUT_DIR, "TableS3_leaveout_permanova.csv")
READSHARE_FILE <- file.path(OUT_DIR, "TableS4_migratory_readshare.csv")
N_TOP_SIMPER   <- 15                     # SIMPER contributors to report
AUTUMN_GROUP   <- 2L                     # IndVal.g cluster index for Autumn
CHUM_SALMON    <- "Oncorhynchus_keta"    # the autumn-dominant chum salmon


# --- SIMPER: top contributors to spring-autumn dissimilarity ----------------------------------------------------------
simper_res <- summary(simper(rel, season, permutations = N_PERM_QUICK))[[1]]
simper_res <- simper_res[order(-simper_res$average), ]

# vegan returns each taxon's average contribution in dissimilarity units, and those contributions sum to the mean
# Bray-Curtis dissimilarity between the seasons. A taxon's percentage contribution is therefore its share of that
# total, which is the quantity SIMPER results are conventionally reported as. Multiplying the raw average by 100
# would give a number on the wrong scale.
# vegan 给出的 average 以相异性为单位，其总和等于季节间平均 Bray-Curtis；百分比应为占该总量的份额。
overall_dissimilarity <- sum(simper_res$average)
simper_res$share_pct  <- 100 * simper_res$average / overall_dissimilarity

# Which season a taxon is more abundant in. It is not part of the SIMPER statistic, but a contribution says only how
# much a taxon separates the seasons, not which way, so Fig. S1A colours each bar by direction.
# 类群在哪个季节更丰富。贡献度只说明分异程度，不说明方向，故另行标注。
season_means <- vapply(SEASONS, \(season_name) colMeans(rel[season == season_name, , drop = FALSE]),
                       numeric(ncol(rel)))
higher_in    <- ifelse(season_means[rownames(simper_res), AUTUMN] >
                       season_means[rownames(simper_res), SPRING], AUTUMN, SPRING)

# The per-season mean relative sequence abundances are reported alongside the contribution, so a reader can see both
# how much a taxon separates the seasons and how abundant it actually was in each.
# 同时报告各季节平均相对序列丰度，使读者既见分异贡献亦见实际丰度。
top_contributors <- tibble(
    taxon            = rownames(simper_res),
    spring_rsa_pct   = round(100 * season_means[rownames(simper_res), SPRING], PCT_DP),
    autumn_rsa_pct   = round(100 * season_means[rownames(simper_res), AUTUMN], PCT_DP),
    higher_in        = unname(higher_in),
    contribution_pct = round(simper_res$share_pct, PCT_DP),
    cumulative_pct   = round(cumsum(simper_res$share_pct), PCT_DP)
) |>
    slice_head(n = N_TOP_SIMPER)
cat(NL, "== SIMPER: top contributors to spring-autumn dissimilarity ==", NL, sep = "")
cat(glue("Mean Bray-Curtis dissimilarity between seasons: {round(overall_dissimilarity, STAT_DP)}"), NL)
print(as.data.frame(top_contributors), row.names = FALSE)
write.csv(top_contributors, SIMPER_FILE, row.names = FALSE)


# --- IndVal.g autumn indicator taxa -----------------------------------------------------------------------------------
indval <- multipatt(as.data.frame(reads), season, func = "IndVal.g", control = how(nperm = N_PERM_QUICK))
indval$sign$FDR   <- p.adjust(indval$sign$p.value, "BH")
autumn_indicators <- rownames(indval$sign)[indval$sign$index == AUTUMN_GROUP & indval$sign$FDR < FDR_ALPHA]
cat(glue("{NL}Autumn indicator taxa (IndVal.g, FDR < {FDR_ALPHA}): {length(autumn_indicators)}"), NL)


# --- Migratory taxa (from the trait table) ----------------------------------------------------------------------------
migratory <- traits$Species_code[traits$`Migration type` == "Migratory"]
cat(glue("Migratory taxa (trait table): {length(migratory)}"), NL)


# --- Leave-one-out PERMANOVA ------------------------------------------------------------------------------------------

#' Season effect (PERMANOVA R2) after dropping a set of taxa. / 剔除若干类群后季节效应的 R2。
#'
#' Removes the given taxa, renormalises each site's surviving reads to proportions,
#' and re-runs the Bray-Curtis PERMANOVA of composition against season.
#'
#' @param drop_taxa Character vector of taxon names to remove (default none).
#' @return Named numeric vector: the season R2 and its permutation p-value for the reduced community.
season_r2 <- function(drop_taxa = character()) {
    kept_reads   <- rel[, !colnames(rel) %in% drop_taxa, drop = FALSE]
    nonzero_rows <- rowSums(kept_reads) > 0
    renormalised <- sweep(kept_reads[nonzero_rows, ], 1, rowSums(kept_reads[nonzero_rows, ]), "/")
    result       <- adonis2(vegdist(renormalised, "bray") ~ season[nonzero_rows], permutations = N_PERM_QUICK)
    c(R2 = result$R2[1], p = result[["Pr(>F)"]][1])
}

# Each scenario keeps its p-value as well as its R2: a reduced R2 that is no longer significant would mean something
# different from one that is, and the table has to be able to show the difference.
# 各情景同时保留 p 值：R2 下降后是否仍显著，含义不同。
scenarios <- list(
    "Full community"               = character(),
    "Remove chum salmon (O. keta)" = CHUM_SALMON,
    "Remove autumn indicator taxa" = autumn_indicators,
    "Remove migratory taxa"        = migratory
)
scenario_results <- map(scenarios, season_r2)
full_r2 <- scenario_results[["Full community"]][["R2"]]

leave_out <- tibble(
    scenario = names(scenarios),
    removed  = as.integer(lengths(scenarios)),
    R2       = round(map_dbl(scenario_results, "R2"), STAT_DP),
    p        = signif(map_dbl(scenario_results, "p"), P_SIGFIG)
) |>
    mutate(reduction_pct = round(100 * (full_r2 - R2) / full_r2, PCT_DP))
cat(NL, "== Leave-one-out PERMANOVA ==", NL, sep = "")
print(as.data.frame(leave_out), row.names = FALSE)
write.csv(leave_out, LEAVEOUT_FILE, row.names = FALSE)


# --- Migratory and chum-salmon read share by season -------------------------------------------------------------------

#' Percentage of each season's reads belonging to a set of taxa. / 各季节归属某类群集合的读数占比。
#'
#' @param taxa Character vector of taxon names.
#' @return Numeric vector of two percentages, c(Spring, Autumn).
read_share <- function(taxa) {
    map_dbl(SEASONS, \(season_name) {
        season_reads <- reads[season == season_name, , drop = FALSE]
        100 * sum(season_reads[, colnames(season_reads) %in% taxa]) / sum(season_reads)
    })
}

share <- tibble(
    season          = SEASONS,
    migratory_pct   = round(read_share(migratory), PCT_DP),
    chum_salmon_pct = round(read_share(CHUM_SALMON), STAT_DP)
)
cat(NL, "== Migratory read share ==", NL, sep = "")
print(as.data.frame(share), row.names = FALSE)
write.csv(share, READSHARE_FILE, row.names = FALSE)
