# ======================================================================================================================
# 07_water_quality_supp.R
#
# Supplementary: local water quality and land cover vs the community (Fig. S2)
# ---------------------------------------------------------------------------
# Two exploratory families, both within season. Spearman correlations between the local variables and site-level alpha
# diversity (BH-FDR corrected), and four distance-based redundancy analyses of composition: water quality and land
# cover, each in spring and autumn. Reproduces Fig. S2 in full. Run 02_alpha_diversity.R first.
#
# 附加分析：局地水质与土地覆被同群落的关系（图 S2）
# ------------------------------------------------
# 两类探索性分析，均在季节内进行：局地变量与站点级 alpha 多样性的 Spearman 相关（BH-FDR 校正），以及四个基于距离的
# 冗余分析（dbRDA）——水质与土地覆被各在春、秋两季。完整重现图 S2。请先运行 02_alpha_diversity.R。
# ======================================================================================================================


# --- Load shared setup ------------------------------------------------------------------------------------------------
.args <- commandArgs(trailingOnly = FALSE)
.file <- sub("^--file=", "", grep("^--file=", .args, value = TRUE))
.dir  <- if (length(.file)) dirname(gsub("~\\+~", " ", .file)) else "."
source(file.path(.dir, "00_setup.R"))
set.seed(RANDOM_SEED)

# Output files written by this script (ALPHA_SITE_FILE is defined in 00_setup.R).
# 本脚本的输出文件（ALPHA_SITE_FILE 在 00_setup.R 中定义）。
LOCAL_CORR_FILE  <- file.path(OUT_DIR, "TableS9_local_alpha_spearman.csv")
LOCAL_DBRDA_FILE <- file.path(OUT_DIR, "TableS10_local_dbrda.csv")

N_TOP_PRINT   <- 8                              # strongest correlations to print per variable family
WATER_QUALITY <- "Water quality"                # variable-family labels used in both outputs
LAND_COVER    <- "Land cover"

if (!file.exists(ALPHA_SITE_FILE)) stop("Run 02_alpha_diversity.R first.")
alpha <- read.csv(ALPHA_SITE_FILE, check.names = FALSE)

alpha_indices <- c("Richness", "Shannon", "Simpson", "Pielou", "FRic", "FEve", "FDis", "FDiv")


# --- Drop classes that carry no signal --------------------------------------------------------------------------------
# A land-cover class absent from every buffer has zero variance, so a correlation with it is undefined rather than
# null. Those classes are reported and excluded so the test count reflects what was actually testable.
# 在所有缓冲区内均缺失的土地覆被类别方差为零，相关系数无定义，故予剔除。

land_use_constant <- LAND_USE_VARS[map_lgl(LAND_USE_VARS, \(class_name) sd(land_use[[class_name]]) == 0)]
land_use_vars     <- setdiff(LAND_USE_VARS, land_use_constant)

cat(NL, "== Fig. S2: local water quality and land cover ==", NL, sep = "")
cat(glue("Land-cover classes present in at least one buffer: {length(land_use_vars)} of {length(LAND_USE_VARS)}"), NL)

if (length(land_use_constant)) {
    cat(glue("Excluded as absent everywhere: {str_c(land_use_constant, collapse = ', ')}"), NL)
}


# --- Local variables per site-season ----------------------------------------------------------------------------------

#' Local variable table for one season, in the site order of the alpha table. / 单季节局地变量表（与 alpha 表同序）。
#'
#' Water quality varies by season and is joined on season and site; land cover is a fixed site
#' property and is joined on site alone.
#'
#' @param season_name Season label, "Spring" or "Autumn".
#' @param site_ids Site codes, in the order the alpha rows appear.
#' @return A data frame of local variables, one row per site, in the requested order.
season_locals <- function(season_name, site_ids) {
    season_wq <- water_quality[water_quality$season == season_name, ]
    rownames(season_wq) <- season_wq$site

    cbind(
        season_wq[site_ids, WATER_QUALITY_VARS, drop = FALSE],
        land_use[site_ids, land_use_vars, drop = FALSE]
    )
}


# --- Local variables vs alpha diversity (Spearman, within season, BH-FDR) ---------------------------------------------

#' Alpha x local-variable Spearman correlations for one season. / 单季节 alpha 指标与局地变量的 Spearman 相关。
#'
#' p-values are BH-FDR corrected within the season and variable family, so the two families are
#' corrected separately rather than pooled.
#'
#' @param season_name Season label, "Spring" or "Autumn".
#' @return A tibble: season, family, alpha index, variable, rho, p and FDR.
season_corr <- function(season_name) {
    season_alpha <- alpha[alpha$season == season_name, ]
    locals       <- season_locals(season_name, season_alpha$site)

    expand.grid(alpha = alpha_indices, variable = colnames(locals), stringsAsFactors = FALSE) |>
        as_tibble() |>
        mutate(
            season = season_name,
            family = if_else(variable %in% WATER_QUALITY_VARS, WATER_QUALITY, LAND_COVER),
            rho    = map2_dbl(alpha, variable, \(alpha_name, var_name)
                suppressWarnings(cor(season_alpha[[alpha_name]], locals[[var_name]], method = "spearman"))),
            p      = map2_dbl(alpha, variable, \(alpha_name, var_name)
                suppressWarnings(cor.test(season_alpha[[alpha_name]], locals[[var_name]], method = "spearman",
                                          exact = FALSE)$p.value))
        ) |>
        group_by(family) |>
        mutate(FDR = p.adjust(p, "BH")) |>
        ungroup()
}

correlations <- map(SEASONS, season_corr) |>
    bind_rows() |>
    mutate(rho = round(rho, STAT_DP), p = signif(p, P_SIGFIG), FDR = signif(FDR, P_SIGFIG)) |>
    select(season, family, alpha, variable, rho, p, FDR)

for (family_name in c(WATER_QUALITY, LAND_COVER)) {
    family_results <- filter(correlations, family == family_name)

    cat(NL, glue("-- {family_name} vs alpha diversity (Spearman, within season, BH-FDR) --"), NL, sep = "")
    cat(glue("Significant after FDR (< {FDR_ALPHA}): {sum(family_results$FDR < FDR_ALPHA)} of ",
             "{nrow(family_results)} tests"), NL)
    cat(glue("Uncorrected p < {FDR_ALPHA}: {sum(family_results$p < FDR_ALPHA)} of {nrow(family_results)} tests"), NL)
    print(as.data.frame(slice_head(arrange(family_results, p), n = N_TOP_PRINT)), row.names = FALSE)
}


# --- Composition vs the local variables (dbRDA, within season) --------------------------------------------------------
# Four models in total, one per variable family per season. These are the models the manuscript reports as
# non-significant, so each is tested explicitly rather than inferred from the correlations above.
# 共四个模型，每季节各变量族一个，即稿件所报告者。

#' dbRDA of composition on one variable family in one season. / 单季节、单一变量族的组成 dbRDA。
#'
#' @param season_name Season label, "Spring" or "Autumn".
#' @param family_name Variable-family label, used in the returned row.
#' @param variables Column names of the predictors to constrain on.
#' @return A one-row tibble: season, family, number of predictors, adjusted R2 and p.
season_dbrda <- function(season_name, family_name, variables) {
    season_data <- season_subset(season_name)
    predictors  <- season_locals(season_name, season_data$site_ids)

    model      <- capscale(season_data$rel ~ ., data = predictors[, variables, drop = FALSE], distance = "bray")
    model_test <- anova(model, permutations = N_PERM)

    tibble(
        season      = season_name,
        family      = family_name,
        n_variables = length(variables),
        adj_R2      = round(RsquareAdj(model)$adj.r.squared, STAT_DP),
        p           = signif(model_test[["Pr(>F)"]][1], P_SIGFIG)
    )
}

dbrda_results <- map(SEASONS, \(season_name) bind_rows(
    season_dbrda(season_name, WATER_QUALITY, WATER_QUALITY_VARS),
    season_dbrda(season_name, LAND_COVER, land_use_vars)
)) |>
    bind_rows()

cat(NL, "-- Composition vs local variables (dbRDA, within season) --", NL, sep = "")
print(as.data.frame(dbrda_results), row.names = FALSE)
cat(glue("Significant models (p < {FDR_ALPHA}): {sum(dbrda_results$p < FDR_ALPHA)} of {nrow(dbrda_results)}"), NL)


# --- Write the supplementary tables -----------------------------------------------------------------------------------
write.csv(correlations, LOCAL_CORR_FILE, row.names = FALSE)
write.csv(dbrda_results, LOCAL_DBRDA_FILE, row.names = FALSE)

cat(NL, "wrote outputs/TableS9_local_alpha_spearman.csv", NL, sep = "")
cat("wrote outputs/TableS10_local_dbrda.csv", NL, sep = "")
