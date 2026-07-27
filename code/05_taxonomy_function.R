# ======================================================================================================================
# 05_taxonomy_function.R
#
# Taxonomic-functional coupling (Fig. 5, Tables S5-S6)
# ----------------------------------------------------
# Alpha scale: pooled Spearman correlations with BH-FDR. Beta scale: Mantel between taxonomic (Bray-Curtis) and
# functional dissimilarity. Run 02_alpha_diversity.R first.
#
# 分类—功能耦合（图 5，表 S5-S6）
# -------------------------------
# alpha 尺度：合并的 Spearman 相关（BH-FDR）。beta 尺度：分类学（Bray-Curtis）与功能相异性的 Mantel 检验。请先运行
# 02_alpha_diversity.R。
# ======================================================================================================================


# --- Load shared setup ------------------------------------------------------------------------------------------------
.args <- commandArgs(trailingOnly = FALSE)
.file <- sub("^--file=", "", grep("^--file=", .args, value = TRUE))
.dir  <- if (length(.file)) dirname(gsub("~\\+~", " ", .file)) else "."
source(file.path(.dir, "00_setup.R"))
set.seed(RANDOM_SEED)

# Output files written by this script (ALPHA_SITE_FILE is defined in 00_setup.R).
ALPHA_TAXFUN_FILE <- file.path(OUT_DIR, "TableS5_taxfun_alpha_spearman.csv")
BETA_MANTEL_FILE  <- file.path(OUT_DIR, "TableS6_taxfun_beta_mantel.csv")

if (!file.exists(ALPHA_SITE_FILE)) stop("Run 02_alpha_diversity.R first.")
alpha <- read.csv(ALPHA_SITE_FILE, check.names = FALSE)


# --- Alpha scale: taxonomic vs functional indices (Spearman, pooled, BH-FDR) ------------------------------------------
tax_indices  <- c("Richness", "Shannon", "Simpson", "Pielou")
func_indices <- c("FRic", "FEve", "FDis", "FDiv")

alpha_corr <- expand.grid(tax = tax_indices, fun = func_indices, stringsAsFactors = FALSE) |>
    as_tibble() |>
    mutate(
        rho    = map2_dbl(tax, fun, \(tax_index, func_index)
            cor(alpha[[tax_index]], alpha[[func_index]], method = "spearman")),
        p      = map2_dbl(tax, fun, \(tax_index, func_index)
            cor.test(alpha[[tax_index]], alpha[[func_index]], method = "spearman", exact = FALSE)$p.value),
        FDR    = p.adjust(p, "BH"),
        result = if_else(FDR < FDR_ALPHA, "Significant", "Not significant"),
        rho    = round(rho, STAT_DP),
        p      = signif(p, P_SIGFIG),
        FDR    = signif(FDR, P_SIGFIG)
    )
cat(NL, "== Alpha-scale taxonomic-functional Spearman (pooled, 26 site-seasons) ==", NL, sep = "")
print(as.data.frame(alpha_corr), row.names = FALSE)
write.csv(alpha_corr, ALPHA_TAXFUN_FILE, row.names = FALSE)


# --- Beta scale: Mantel between compositional and functional dissimilarity --------------------------------------------
# Functional distance = Gower distance among community-weighted trait means (CWM).
trait_columns  <- c("Diet", "Mouth position", "Trophic level", "Water layer", "Migration type",
                    "Body shape", "Max body length (cm)", "Egg ecological type", "Resilience")
trait_table    <- traits[colnames(reads), trait_columns]     # keep species as row names
is_categorical <- vapply(trait_table, is.character, logical(1))
trait_table[is_categorical] <- lapply(trait_table[is_categorical], as.factor)

cwm       <- FD::functcomp(trait_table, reads)
func_dist <- FD::gowdis(cwm)
bray_dist <- vegdist(rel, "bray")

pooled_mantel <- mantel(bray_dist, func_dist, method = "pearson", permutations = N_PERM)
cat(NL, "== Beta-scale Mantel (Bray-Curtis vs functional CWM distance) ==", NL, sep = "")
cat(glue("  pooled: r = {round(pooled_mantel$statistic, STAT_DP)}, ",
         "p = {sprintf(P_FMT, pooled_mantel$signif)}"), NL)

for (season_name in SEASONS) {
    seasonal_bray   <- vegdist(rel[season == season_name, ], "bray")
    seasonal_cwm    <- gowdis(cwm[season == season_name, ])
    seasonal_mantel <- mantel(seasonal_bray, seasonal_cwm, permutations = N_PERM)
    cat(glue("  {season_name}: r = {round(seasonal_mantel$statistic, STAT_DP)}, ",
             "p = {sprintf(P_FMT, seasonal_mantel$signif)}"), NL)
}

write.csv(
    tibble(scope = "pooled",
           mantel_r = round(pooled_mantel$statistic, STAT_DP),
           p = signif(pooled_mantel$signif, P_SIGFIG)),
    BETA_MANTEL_FILE, row.names = FALSE
)
