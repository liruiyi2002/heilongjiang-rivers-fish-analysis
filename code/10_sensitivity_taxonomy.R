# ======================================================================================================================
# 10_sensitivity_taxonomy.R
#
# Robustness of the conclusions to the biogeographically questionable taxa (Table S21)
# ------------------------------------------------------------------------------------
# Six taxa in the species list sit outside their published native range for the Amur basin: Luciobarbus capito
# (Caspian-Aral), Hemiculter bleekeri (Yangtze), Rutilus rutilus, Perca fluviatilis, Tinca tinca and Oryzias latipes.
# Two of them carry enough reads to matter: H. bleekeri is 8.91% of spring fish reads and L. capito 2.53%.
#
# The provider has not supplied per-ASV BLAST identity or coverage, so the labels cannot be confirmed or rejected from
# the deliveries. Their representative sequences are, however, clearly distinct from every other taxon detected - the
# dominant H. bleekeri variant differs from H. leucisculus at 7 of 178 bases, and L. capito from its nearest match at
# 27 of 170 - so these are real, abundant sequences rather than clustering artefacts. What is uncertain is the species
# label, not the signal.
#
# This script therefore does not judge the labels. It removes all six taxa, re-runs every analysis whose conclusion
# they could affect, and reports both versions side by side, so a reader can see whether the paper's claims depend on
# them. Renormalisation is applied after removal, exactly as in 04_simper_leaveout.R.
#
# 分类学稳健性检验（表 S21）
# --------------------------
# 物种名单中有六个类群的自然分布不含黑龙江流域；其中两个读数占比可观（H. bleekeri 占春季鱼类读数 8.91%，
# L. capito 占 2.53%）。公司未提供每条 ASV 的 BLAST 一致性与覆盖度，故无法据交付资料判定其真伪；但其代表序列与
# 已检出的其他类群明显不同（优势变异体与 H. leucisculus 相差 178 bp 中的 7 bp），说明这些序列真实且丰度不低，
# 存疑者为物种名称而非信号本身。本脚本不判定名称，而是移除这六个类群后重跑所有可能受其影响的分析，并列出两种
# 情形下的结果，以显示结论是否依赖于它们。
# ======================================================================================================================


# --- Load shared setup ------------------------------------------------------------------------------------------------
.args <- commandArgs(trailingOnly = FALSE)
.file <- sub("^--file=", "", grep("^--file=", .args, value = TRUE))
.dir  <- if (length(.file)) dirname(gsub("~\\+~", " ", .file)) else "."
source(file.path(.dir, "00_setup.R"))
set.seed(RANDOM_SEED)

SENSITIVITY_FILE <- file.path(OUT_DIR, "TableS21_taxonomy_sensitivity.csv")

# The six taxa, named exactly as in species_taxonomy.csv.
# 六个存疑类群，名称与 species_taxonomy.csv 一致。
QUESTIONABLE <- c("Luciobarbus_capito", "Hemiculter_bleekeri", "Rutilus_rutilus",
                  "Perca_fluviatilis", "Tinca_tinca", "Oryzias_latipes")
present_questionable <- intersect(QUESTIONABLE, colnames(reads))
stopifnot(length(present_questionable) >= 5L)

cat(NL, "== Sensitivity to the questionable taxa / 存疑类群的稳健性检验 ==", NL, sep = "")
cat(glue("Removing {length(present_questionable)} taxa: {paste(present_questionable, collapse = ', ')}"), NL)
cat(glue("They carry {round(100 * sum(reads[, present_questionable]) / sum(reads), 2)}% of all fish reads"), NL)

reduced_reads <- reads[, setdiff(colnames(reads), present_questionable), drop = FALSE]
reduced_rel   <- sweep(reduced_reads, 1, rowSums(reduced_reads), "/")   # renormalised after removal
full_rel      <- sweep(reads, 1, rowSums(reads), "/")


#' One row of the comparison table. / 比较表中的一行。
#'
#' @param quantity Name of the quantity being compared.
#' @param full Value with all 100 taxa.
#' @param reduced Value with the six taxa removed.
#' @param note Short interpretation.
#' @return A one-row tibble.
comparison <- function(quantity, full, reduced, note) {
    tibble(quantity = quantity,
           all_taxa = decimal(full),
           questionable_removed = decimal(reduced),
           conclusion_unchanged = note)
}

#' Render a number as a plain decimal. / 以十进制小数呈现数值。
#'
#' This column holds R2 values and p-values together, so the builder's probability-column rule cannot pick it
#' out; a p of 1e-04 would otherwise reach the published table in scientific notation.
#' 该列同时含 R2 与 p 值，构建脚本的概率列规则无法识别；若不处理，1e-04 会以科学记数法进入已发表表格。
#'
#' @param x A single number.
#' @return A character string in fixed notation, trailing zeros trimmed.
decimal <- function(x) sub("[.]?0+$", "", formatC(x, format = "f", digits = 4))

rows <- list()


# --- Seasonal PERMANOVA on composition --------------------------------------------------------------------------------
full_permanova    <- adonis2(vegdist(full_rel, "bray") ~ season, permutations = N_PERM)
reduced_permanova <- adonis2(vegdist(reduced_rel, "bray") ~ season, permutations = N_PERM)
rows <- append(rows, list(comparison(
    "Seasonal PERMANOVA R2 (taxonomic composition)",
    round(full_permanova$R2[1], STAT_DP), round(reduced_permanova$R2[1], STAT_DP),
    if (reduced_permanova[["Pr(>F)"]][1] < FDR_ALPHA) "yes, still significant" else "NO")))
rows <- append(rows, list(comparison(
    "Seasonal PERMANOVA p",
    signif(full_permanova[["Pr(>F)"]][1], P_SIGFIG), signif(reduced_permanova[["Pr(>F)"]][1], P_SIGFIG),
    "-")))


# --- Turnover versus nestedness ---------------------------------------------------------------------------------------
#' Sorensen turnover share of total beta diversity between the paired seasons. / 配对季节间周转占比。
#'
#' @param matrix_in A site-by-taxon read matrix.
#' @return Named numeric vector: total, turnover, nestedness, and turnover's share of total.
turnover_share <- function(matrix_in) {
    presence <- (matrix_in > 0) * 1L
    sites <- unique(meta$site)
    totals <- turnovers <- numeric(0)
    for (this_site in sites) {
        spring_row <- presence[meta$site == this_site & season == SPRING, , drop = FALSE]
        autumn_row <- presence[meta$site == this_site & season == AUTUMN, , drop = FALSE]
        if (!nrow(spring_row) || !nrow(autumn_row)) next
        shared  <- sum(spring_row == 1 & autumn_row == 1)
        only_s  <- sum(spring_row == 1 & autumn_row == 0)
        only_a  <- sum(spring_row == 0 & autumn_row == 1)
        totals    <- c(totals, (only_s + only_a) / (2 * shared + only_s + only_a))
        turnovers <- c(turnovers, min(only_s, only_a) / (shared + min(only_s, only_a)))
    }
    c(total = mean(totals), turnover = mean(turnovers),
      share = mean(turnovers) / mean(totals))
}

full_beta    <- turnover_share(reads)
reduced_beta <- turnover_share(reduced_reads)
rows <- append(rows, list(comparison(
    "Turnover share of total taxonomic beta diversity",
    round(full_beta[["share"]], STAT_DP), round(reduced_beta[["share"]], STAT_DP),
    if (reduced_beta[["share"]] > 0.5) "yes, still turnover-dominated" else "NO")))


# --- Composition against the gradient, within season ------------------------------------------------------------------
for (season_name in SEASONS) {
    rows_in_season <- season == season_name
    pc1 <- env$PC1[match(meta$site[rows_in_season], rownames(env))]
    full_pc1    <- adonis2(vegdist(full_rel[rows_in_season, ], "bray") ~ pc1, permutations = N_PERM)
    reduced_pc1 <- adonis2(vegdist(reduced_rel[rows_in_season, ], "bray") ~ pc1, permutations = N_PERM)
    rows <- append(rows, list(comparison(
        glue("Composition ~ PC1, {season_name}: R2"),
        round(full_pc1$R2[1], STAT_DP), round(reduced_pc1$R2[1], STAT_DP),
        if (reduced_pc1[["Pr(>F)"]][1] < FDR_ALPHA) "yes, still significant" else "NO")))
    rows <- append(rows, list(comparison(
        glue("Composition ~ PC1, {season_name}: p"),
        signif(full_pc1[["Pr(>F)"]][1], P_SIGFIG), signif(reduced_pc1[["Pr(>F)"]][1], P_SIGFIG),
        "-")))
}


# --- Alpha diversity: the two indices that carried a seasonal signal --------------------------------------------------
#' Paired Wilcoxon p for one alpha index between seasons, at the site scale. / 站点级配对 Wilcoxon 检验。
#'
#' @param matrix_in A site-by-taxon read matrix.
#' @param index_fn Function mapping a row of relative abundances to a scalar.
#' @return The paired p-value.
paired_index_p <- function(matrix_in, index_fn) {
    relative <- sweep(matrix_in, 1, rowSums(matrix_in), "/")
    values   <- apply(relative, 1, index_fn)
    spring_values <- values[season == SPRING][order(meta$site[season == SPRING])]
    autumn_values <- values[season == AUTUMN][order(meta$site[season == AUTUMN])]
    wilcox.test(spring_values, autumn_values, paired = TRUE)$p.value
}

hill_q1 <- function(p) { p <- p[p > 0]; exp(-sum(p * log(p))) }
rows <- append(rows, list(comparison(
    "Hill q1, paired seasonal p",
    signif(paired_index_p(reads, hill_q1), P_SIGFIG),
    signif(paired_index_p(reduced_reads, hill_q1), P_SIGFIG),
    if (paired_index_p(reduced_reads, hill_q1) < FDR_ALPHA) "yes, still significant" else "NO")))


# --- Write the comparison ---------------------------------------------------------------------------------------------
sensitivity <- bind_rows(rows)
cat(NL)
print(as.data.frame(sensitivity), row.names = FALSE)
write.csv(sensitivity, SENSITIVITY_FILE, row.names = FALSE)
cat(glue("{NL}wrote {basename(SENSITIVITY_FILE)}"), NL)
