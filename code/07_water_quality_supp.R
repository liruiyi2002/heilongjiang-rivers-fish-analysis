# ======================================================================================================================
# 07_water_quality_supp.R
#
# Supplementary: local water quality vs alpha diversity (Fig. S2, part)
# ---------------------------------------------------------------------
# Exploratory Spearman correlations between the 8 water-quality variables and site-level alpha diversity, within each
# season, BH-FDR corrected. Reproduces the water-quality part of Fig. S2; the land-use variables are not included (see
# internal_processes/NOT_INCLUDED_and_why). Run 02_alpha_diversity.R first.
#
# 附加分析：局地水质与 alpha 多样性（图 S2，部分）
# ------------------------------------------------
# 8 个水质变量与站点级 alpha 多样性的分季节 Spearman 相关（BH-FDR）；重现图 S2 的水质部分；土地利用变量未包含（见
# internal_processes/NOT_INCLUDED_and_why）。请先运行 02_alpha_diversity.R。
# ======================================================================================================================


# --- Load shared setup ------------------------------------------------------------------------------------------------
.args <- commandArgs(trailingOnly = FALSE)
.file <- sub("^--file=", "", grep("^--file=", .args, value = TRUE))
.dir  <- if (length(.file)) dirname(gsub("~\\+~", " ", .file)) else "."
source(file.path(.dir, "00_setup.R"))
set.seed(RANDOM_SEED)

# Output file written by this script (ALPHA_SITE_FILE is defined in 00_setup.R).
WATER_QUALITY_CORR_FILE <- file.path(OUT_DIR, "TableS8_waterquality_alpha_spearman.csv")
N_TOP_PRINT             <- 8   # strongest correlations to print to the console

if (!file.exists(ALPHA_SITE_FILE)) stop("Run 02_alpha_diversity.R first.")
alpha <- read.csv(ALPHA_SITE_FILE, check.names = FALSE)

water_quality_vars <- colnames(water_quality)
alpha_indices      <- c("Richness", "Shannon", "Simpson", "Pielou", "FRic", "FEve", "FDis", "FDiv")


# --- Water quality vs alpha diversity (Spearman, within season, BH-FDR) -----------------------------------------------

#' Alpha x water-quality Spearman correlations for one season. / 单季节 alpha 指标与水质的 Spearman 相关。
#'
#' Water quality is one measurement per site, aligned to each row's site;
#' p-values are BH-FDR corrected within the season.
#'
#' @param season_name Season label, "Spring" or "Autumn".
#' @return A tibble: season, alpha index, water-quality variable, rho, p and FDR.
season_corr <- function(season_name) {
    season_alpha <- alpha[alpha$season == season_name, ]
    site_wq      <- water_quality[season_alpha$site, , drop = FALSE]

    expand.grid(alpha = alpha_indices, wq = water_quality_vars, stringsAsFactors = FALSE) |>
        as_tibble() |>
        mutate(
            season = season_name,
            rho    = map2_dbl(alpha, wq, \(alpha_name, wq_name)
                suppressWarnings(cor(season_alpha[[alpha_name]], site_wq[[wq_name]], method = "spearman"))),
            p      = map2_dbl(alpha, wq, \(alpha_name, wq_name)
                suppressWarnings(cor.test(season_alpha[[alpha_name]], site_wq[[wq_name]], method = "spearman",
                                          exact = FALSE)$p.value)),
            FDR    = p.adjust(p, "BH")
        )
}

results <- map(SEASONS, season_corr) |>
    bind_rows() |>
    mutate(rho = round(rho, STAT_DP), p = signif(p, P_SIGFIG), FDR = signif(FDR, P_SIGFIG))

cat(NL, "== Water quality vs alpha diversity (Spearman, within season, BH-FDR) ==", NL, sep = "")
cat(glue("Significant after FDR (< {FDR_ALPHA}): {sum(results$FDR < FDR_ALPHA)} of {nrow(results)} tests"), NL)
cat(glue("Uncorrected p < {FDR_ALPHA}: {sum(results$p < FDR_ALPHA)} of {nrow(results)} tests"), NL)
print(as.data.frame(slice_head(arrange(results, p), n = N_TOP_PRINT)), row.names = FALSE)

write.csv(results, WATER_QUALITY_CORR_FILE, row.names = FALSE)
cat(NL, "wrote outputs/TableS8_waterquality_alpha_spearman.csv", NL, sep = "")
cat("NOTE: land-use variables (Fig. S2) are not included; see internal_processes/NOT_INCLUDED_and_why.", NL, sep = "")
