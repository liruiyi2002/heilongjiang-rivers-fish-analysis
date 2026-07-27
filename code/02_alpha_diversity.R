# ======================================================================================================================
# 02_alpha_diversity.R
#
# Taxonomic and functional alpha diversity (Fig. 3, Table S1)
# -----------------------------------------------------------
# Alpha indices at the site scale reproduce the seasonal paired comparisons (paired Wilcoxon, matched sites, BH-FDR).
# Sample coverage uses the replicate table from 01_composition.R.
#
# 分类与功能 alpha 多样性（图 3，表 S1）
# --------------------------------------
# 站点尺度的 alpha 指标重现季节配对比较（配对 Wilcoxon、同站点配对、BH-FDR）；样本覆盖度使用 01_composition.R 的重复级数
# 据。
# ======================================================================================================================


# --- Load shared setup ------------------------------------------------------------------------------------------------
.args <- commandArgs(trailingOnly = FALSE)
.file <- sub("^--file=", "", grep("^--file=", .args, value = TRUE))
.dir  <- if (length(.file)) dirname(gsub("~\\+~", " ", .file)) else "."
source(file.path(.dir, "00_setup.R"))

# Output file written by this script (ALPHA_SITE_FILE is defined in 00_setup.R).
PAIRED_TESTS_FILE <- file.path(OUT_DIR, "TableS1_alpha_paired_tests_site_level.csv")
N_PCOA_AXES       <- 4   # PCoA axes retained for the functional-diversity indices


# --- Taxonomic alpha diversity per site-season ------------------------------------------------------------------------
alpha_tax <- data.frame(
    Richness      = rowSums(presence_absence),
    Shannon       = diversity(reads, "shannon"),
    Simpson       = diversity(reads, "simpson"),
    Pielou        = diversity(reads, "shannon") / log(rowSums(presence_absence)),
    Hill_q1       = exp(diversity(reads, "shannon")),
    Hill_q2       = diversity(reads, "invsimpson"),
    Berger_Parker = apply(rel, 1, max)
)


# --- Functional alpha diversity: Gower distance + abundances, N_PCOA_AXES PCoA axes -----------------------------------
functional <- FD::dbFD(gower_dist, reads, m = N_PCOA_AXES, corr = "cailliez",
                       calc.FRic = TRUE, calc.FDiv = TRUE, stand.FRic = TRUE, messages = FALSE)
alpha_fun <- data.frame(
    FRic = functional$FRic,
    FEve = functional$FEve,
    FDis = functional$FDis,
    FDiv = functional$FDiv,
    RaoQ = functional$RaoQ
)

alpha <- cbind(meta[, c("sample", "site", "season")], round(cbind(alpha_tax, alpha_fun), STAT_DP))
write.csv(alpha, ALPHA_SITE_FILE, row.names = FALSE)


# --- Seasonal paired Wilcoxon on matched sites, with BH-FDR -----------------------------------------------------------
indices <- cbind(alpha_tax, alpha_fun)

#' Index rows for one season, ordered by site. / 单季节的指标行，按站点排序。
#'
#' Ordering by site lets spring and autumn line up pairwise for the paired tests.
#'
#' @param season_name Season label, "Spring" or "Autumn".
#' @return A data frame of alpha indices, one row per site, ordered by site.
ordered_by_site <- function(season_name) {
    indices[season == season_name, ][order(meta$site[season == season_name]), ]
}

spring_indices <- ordered_by_site(SPRING)
autumn_indices <- ordered_by_site(AUTUMN)
spring_mean    <- colMeans(spring_indices)
autumn_mean    <- colMeans(autumn_indices)

#' Paired Wilcoxon p-value for one index (spring vs autumn, same sites). / 单指标的配对 Wilcoxon p 值。
#'
#' @param index_name Column name of the diversity index to test.
#' @return The two-sided paired Wilcoxon p-value.
paired_p <- function(index_name) {
    suppressWarnings(
        wilcox.test(spring_indices[[index_name]], autumn_indices[[index_name]], paired = TRUE)$p.value
    )
}

paired <- tibble(
    index       = colnames(indices),
    spring_mean = round(spring_mean, STAT_DP),
    autumn_mean = round(autumn_mean, STAT_DP),
    direction   = if_else(spring_mean >= autumn_mean,
                          paste(SPRING, ">", AUTUMN), paste(AUTUMN, ">", SPRING)),
    p           = map_dbl(index, paired_p)
) |>
    mutate(
        FDR    = p.adjust(p, "BH"),
        result = if_else(FDR < FDR_ALPHA, "Significant", "Not significant"),
        p      = signif(p, P_SIGFIG),
        FDR    = signif(FDR, P_SIGFIG)
    )

cat(NL, "== Alpha diversity: paired Wilcoxon (site level) ==", NL, sep = "")
print(as.data.frame(paired), row.names = FALSE)
write.csv(paired, PAIRED_TESTS_FILE, row.names = FALSE)
