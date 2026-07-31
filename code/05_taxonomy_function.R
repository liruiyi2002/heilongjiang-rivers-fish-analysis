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

# Output files written by this script (ALPHA_SITE_FILE is defined in 00_setup.R). The Fig. 5 file holds one row per
# sample pair, which is what panel B plots, so the scatter and the Mantel statistic come from the same numbers.
# 本脚本的输出文件；图 5 的文件按样本对逐行记录，使散点与 Mantel 统计量同源。
ALPHA_TAXFUN_FILE <- file.path(OUT_DIR, "TableS5_taxfun_alpha_spearman.csv")
BETA_MANTEL_FILE  <- file.path(OUT_DIR, "TableS6_taxfun_beta_mantel.csv")
BETA_PAIRS_FILE   <- file.path(OUT_DIR, "Fig5_beta_pairs.csv")

# The community-weighted trait means are built here and also needed by 06, which tests functional composition against
# the environmental gradient. Written out rather than rebuilt, so both scripts use the same matrix.
# 群落加权性状均值在此构建，脚本 06 亦需使用，故写出文件以共用同一矩阵。
CWM_FILE          <- file.path(OUT_DIR, "cwm_by_site_season.csv")

if (!file.exists(ALPHA_SITE_FILE)) stop("Run 02_alpha_diversity.R first.")
alpha <- read.csv(ALPHA_SITE_FILE, check.names = FALSE)


# --- Alpha scale: taxonomic vs functional indices (Spearman, pooled, BH-FDR) ------------------------------------------
tax_indices  <- c("Richness", "Shannon", "Simpson", "Pielou")
func_indices <- c("FRic", "FEve", "FDis", "FDiv")

#' Spearman correlations between taxonomic and functional indices, over one subset. / 分类与功能指数间的 Spearman 相关。
#'
#' FDR correction is applied **within** each scope, because the 16 tests of one scope are the family being
#' corrected; pooling all 48 across scopes would correct against tests that answer a different question.
#'
#' @param scope_name Label for the subset: "Combined", "Spring" or "Autumn".
#' @param rows Logical vector selecting rows of `alpha`.
#' @return A tibble of scope, tax, fun, rho, p, FDR and result.
scope_correlations <- function(scope_name, rows) {
    subset_alpha <- alpha[rows, ]
    expand.grid(tax = tax_indices, fun = func_indices, stringsAsFactors = FALSE) |>
        as_tibble() |>
        mutate(
            scope  = scope_name,
            rho    = map2_dbl(tax, fun, \(tax_index, func_index)
                cor(subset_alpha[[tax_index]], subset_alpha[[func_index]], method = "spearman")),
            p      = map2_dbl(tax, fun, \(tax_index, func_index)
                cor.test(subset_alpha[[tax_index]], subset_alpha[[func_index]],
                         method = "spearman", exact = FALSE)$p.value),
            FDR    = p.adjust(p, "BH"),
            result = if_else(FDR < FDR_ALPHA, "Significant", "Not significant"),
            rho    = round(rho, STAT_DP),
            p      = signif(p, P_SIGFIG),
            FDR    = signif(FDR, P_SIGFIG)
        ) |>
        select(scope, tax, fun, rho, p, FDR, result)
}

# Pooled across seasons, then within each season, which is what the supplementary table reports.
# 先合并各季节，再分季节计算，与补充表的呈现一致。
alpha_corr <- bind_rows(
    scope_correlations("Combined", rep(TRUE, nrow(alpha))),
    map(SEASONS, \(season_name) scope_correlations(season_name, alpha$season == season_name))
)

cat(NL, "== Alpha-scale taxonomic-functional Spearman (pooled and by season) ==", NL, sep = "")
print(as.data.frame(alpha_corr[alpha_corr$scope == "Combined", ]), row.names = FALSE)

# One line per scope, so it is obvious how much of the coupling survives correction in each.
# 每个范围一行，便于看出校正后仍显著的耦合数量。
alpha_corr |>
    group_by(scope) |>
    summarise(significant = sum(FDR < FDR_ALPHA), tests = n(), .groups = "drop") |>
    mutate(line = glue("  {scope}: {significant} of {tests} significant after FDR")) |>
    pull(line) |>
    walk(\(line) cat(line, NL))

write.csv(alpha_corr, ALPHA_TAXFUN_FILE, row.names = FALSE)


# --- Beta scale: Mantel between compositional and functional dissimilarity --------------------------------------------
# Functional distance = Gower distance among community-weighted trait means (CWM).
# 功能距离 = 群落加权性状均值（CWM）间的 Gower 距离。
trait_columns  <- c("Diet", "Mouth position", "Trophic level", "Water layer", "Migration type",
                    "Body shape", "Max body length (cm)", "Egg ecological type", "Resilience")
trait_table    <- traits[colnames(reads), trait_columns]     # keep species as row names
is_categorical <- vapply(trait_table, is.character, logical(1))
trait_table[is_categorical] <- lapply(trait_table[is_categorical], as.factor)

cwm       <- FD::functcomp(trait_table, reads)
func_dist <- FD::gowdis(cwm)
bray_dist <- vegdist(rel, "bray")

write.csv(cwm, CWM_FILE)

pooled_mantel <- mantel(bray_dist, func_dist, method = "pearson", permutations = N_PERM)
cat(NL, "== Beta-scale Mantel (Bray-Curtis vs functional CWM distance) ==", NL, sep = "")
cat(glue("  pooled: r = {round(pooled_mantel$statistic, STAT_DP)}, ",
         "p = {sprintf(P_FMT, pooled_mantel$signif)}"), NL)

#' One Mantel table row, with the sample and pair counts. / Mantel 结果表的一行，附样本数与配对数。
#'
#' The counts matter for interpretation: a Mantel r from 13 samples and 78 pairs is a weaker claim than the
#' same r from 26 samples and 325 pairs, so the table states both rather than leaving them implied.
#'
#' @param scope_name Label for the subset: "Combined", "Spring" or "Autumn".
#' @param result A vegan mantel object.
#' @param sample_count Number of samples the test used.
#' @return A one-row tibble.
mantel_row <- function(scope_name, result, sample_count) {
    tibble(
        scope        = scope_name,
        mantel_r     = round(result$statistic, STAT_DP),
        p            = signif(result$signif, P_SIGFIG),
        n_samples    = sample_count,
        n_pairs      = sample_count * (sample_count - 1L) / 2L,
        permutations = N_PERM,
        result       = if_else(result$signif < FDR_ALPHA, "Significant", "Not significant")
    )
}

seasonal_results <- map(SEASONS, \(season_name) {
    seasonal_rows   <- season == season_name
    seasonal_bray   <- vegdist(rel[seasonal_rows, ], "bray")
    seasonal_cwm    <- gowdis(cwm[seasonal_rows, ])
    seasonal_mantel <- mantel(seasonal_bray, seasonal_cwm, permutations = N_PERM)
    cat(glue("  {season_name}: r = {round(seasonal_mantel$statistic, STAT_DP)}, ",
             "p = {sprintf(P_FMT, seasonal_mantel$signif)}"), NL)
    mantel_row(season_name, seasonal_mantel, sum(seasonal_rows))
}) |>
    bind_rows()

# Pooled first, then each season, so the table carries every value quoted in the text.
# 先合并再分季节，使表中涵盖正文引用的全部数值。
bind_rows(
    mantel_row("Combined", pooled_mantel, nrow(rel)),
    seasonal_results
) |>
    write.csv(BETA_MANTEL_FILE, row.names = FALSE)


# --- Plot-ready pair list for Fig. 5B ---------------------------------------------------------------------------------
# One row per sample pair, holding the two dissimilarities the Mantel test compares. Panel B is a scatter of exactly
# these columns, so the cloud of points and the reported r describe the same comparison. Whether a pair is within or
# between seasons is carried too, since that is the structure the pooled correlation is built on.
# 按样本对逐行记录 Mantel 所比较的两种相异性；面板 B 即为该两列的散点。
pair_index  <- which(lower.tri(as.matrix(bray_dist)), arr.ind = TRUE)
sample_ids  <- rownames(as.matrix(bray_dist))

beta_pairs <- tibble(
    sample_1      = sample_ids[pair_index[, "row"]],
    sample_2      = sample_ids[pair_index[, "col"]],
    taxonomic     = round(as.matrix(bray_dist)[pair_index], DIST_DP),
    functional    = round(as.matrix(func_dist)[pair_index], DIST_DP)
) |>
    mutate(
        season_1 = sub(paste0(NAME_SEP, ".*$"), "", sample_1),
        season_2 = sub(paste0(NAME_SEP, ".*$"), "", sample_2),
        comparison = if_else(season_1 == season_2, paste("Within", season_1), "Between seasons")
    ) |>
    select(sample_1, sample_2, comparison, taxonomic, functional)

write.csv(beta_pairs, BETA_PAIRS_FILE, row.names = FALSE)
cat(NL, "wrote outputs/TableS5_taxfun_alpha_spearman.csv, TableS6_taxfun_beta_mantel.csv, Fig5_beta_pairs.csv",
    NL, sep = "")
