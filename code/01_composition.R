# ======================================================================================================================
# 01_composition.R
#
# Community composition (Results 3.1; Fig. 2)
# -------------------------------------------
# Total reads; order/family/genus counts; seasonal shared and unique taxa; replicate-level sample coverage; and the
# most abundant taxa per season.
#
# 群落组成（结果 3.1；图 2）
# --------------------------
# 总读数；目/科/属计数；季节共有与特有类群；重复级样本覆盖度；各季节优势类群。
# ======================================================================================================================


# --- Load shared setup ------------------------------------------------------------------------------------------------
.args <- commandArgs(trailingOnly = FALSE)
.file <- sub("^--file=", "", grep("^--file=", .args, value = TRUE))
.dir  <- if (length(.file)) dirname(gsub("~\\+~", " ", .file)) else "."
source(file.path(.dir, "00_setup.R"))

# Output files written by this script, and the size of the "most abundant" summaries.
# 本脚本的输出文件，以及优势类群汇总的条目数。
TOP_TAXA_FILE   <- file.path(OUT_DIR, "Table_top_abundant_taxa.csv")
OCCURRENCE_FILE <- file.path(OUT_DIR, "Fig2_seasonal_occurrence.csv")
SHARES_FILE     <- file.path(OUT_DIR, "Fig2_composition_shares.csv")
# The asymptotic-completeness figures are quoted in the Results, so they are written out rather than only printed.
# 渐近完整度数值在结果中被引用，故写出文件而非仅打印。
COMPLETENESS_FILE <- file.path(OUT_DIR, "TableS13_asymptotic_completeness.csv")
# The per-order and per-family taxa counts and read shares quoted in the first Results paragraph.
# 结果首段所引各目、各科的类群数与读数占比。
RANK_SHARES_FILE  <- file.path(OUT_DIR, "TableS17_rank_read_shares.csv")
TOP_N           <- 10

cat(NL, "== Community composition / 群落组成 ==", NL, sep = "")
cat(glue("Total valid fish reads: {format(sum(reads), big.mark = ',')}"), NL)
cat(glue("Taxa detected: {ncol(reads)}"), NL)

# Order / family / genus counts, read from the shipped taxonomy table.
# 目 / 科 / 属计数，取自随包提供的分类表。
ranks <- taxonomy[colnames(reads), ]
cat(glue("Orders: {n_distinct(ranks$order)} | ",
         "Families: {n_distinct(ranks$family)} | ",
         "Genera: {n_distinct(ranks$genus)}"), NL)


# --- Taxa and read share by order and by family -----------------------------------------------------------------------
# The first Results paragraph names the leading orders and families with a taxon count and a read share each. Those ten
# numbers had no generator and appeared in no output file, so a reader could not check them and a rerun could not
# re-verify them. They are computed here and written out.
# 结果首段列出各主要目与科的类群数与读数占比；此十个数值原先无生成器、亦不见于任何输出文件，读者无从核对、
# 重跑亦无从复验，故在此计算并写出。

#' Taxa count and read share for each level of one taxonomic rank. / 某分类阶元各类别的类群数与读数占比。
#'
#' @param rank_name Column of the taxonomy table, "order" or "family".
#' @return A tibble ordered by descending read share, with taxa, reads and percent columns.
rank_summary <- function(rank_name) {
    level <- ranks[[rank_name]]
    tibble(
        rank    = rank_name,
        group   = level,
        reads   = colSums(reads)
    ) |>
        summarise(taxa = n(), reads = sum(reads), .by = c(rank, group)) |>
        mutate(percent = round(100 * reads / sum(reads), PCT_DP)) |>
        arrange(desc(reads))
}

rank_shares <- bind_rows(rank_summary("order"), rank_summary("family"))
stopifnot(nrow(rank_shares) == n_distinct(ranks$order) + n_distinct(ranks$family))
write.csv(rank_shares, RANK_SHARES_FILE, row.names = FALSE)
cat(NL, "== Leading orders and families by read share ==", NL, sep = "")
print(as.data.frame(head(rank_shares[rank_shares$rank == "order", ], 3)), row.names = FALSE)
print(as.data.frame(head(rank_shares[rank_shares$rank == "family", ], 3)), row.names = FALSE)


# --- Seasonal shared and unique taxa ----------------------------------------------------------------------------------

#' Taxa detected in a season (presence-based). / 某季节检出的类群。
#'
#' @param season_name Season label, "Spring" or "Autumn".
#' @return Character vector of taxon names with at least one read that season.
taxa_in_season <- function(season_name) {
    detected <- colSums(presence_absence[season == season_name, , drop = FALSE]) > 0
    colnames(presence_absence)[detected]
}

spring_taxa <- taxa_in_season(SPRING)
autumn_taxa <- taxa_in_season(AUTUMN)
cat(glue(
    "{SPRING} taxa: {length(spring_taxa)} | {AUTUMN} taxa: {length(autumn_taxa)} | ",
    "Shared: {length(intersect(spring_taxa, autumn_taxa))} | ",
    "{SPRING}-only: {length(setdiff(spring_taxa, autumn_taxa))} | ",
    "{AUTUMN}-only: {length(setdiff(autumn_taxa, spring_taxa))}"
), NL)


# --- Sample coverage (incidence-based over the three replicates per site) ---------------------------------------------

#' Incidence frequencies for iNEXT, from the three replicates per site. / iNEXT 所需的出现频次向量。
#'
#' Sample coverage is estimated at the replicate scale (39 replicates per season).
#'
#' @param season_name Season label, "Spring" or "Autumn".
#' @return Integer vector c(number_of_samples, incidence frequencies) for iNEXT.
incidence_frequencies <- function(season_name) {
    season_replicates <- replicate_reads[replicate_meta$season == season_name, , drop = FALSE]
    taxon_incidence   <- colSums(season_replicates > 0)          # replicates each taxon appears in
    c(nrow(season_replicates), sort(taxon_incidence[taxon_incidence > 0], decreasing = TRUE))
}

frequencies <- setNames(map(SEASONS, incidence_frequencies), SEASONS)
coverage    <- iNEXT(frequencies, q = 0, datatype = "incidence_freq")
cat(NL, "Sample coverage (incidence-based, replicate scale):", NL, sep = "")
print(coverage$DataInfo[, c("Assemblage", "SC")])

# Observed richness as a share of the Chao asymptotic estimate. Coverage says how much of the community's
# abundance was sampled; this says how much of its richness was, which is the quantity the manuscript quotes.
# 观测丰富度占 Chao 渐近估计的比例：覆盖度衡量丰度采样程度，此处衡量丰富度采样程度。
completeness <- map(SEASONS, \(season_name) {
    estimate <- ChaoRichness(frequencies[[season_name]], datatype = "incidence_freq")
    tibble(
        season         = season_name,
        observed       = sum(frequencies[[season_name]][-1] > 0),
        chao_estimate  = round(estimate$Estimator, STAT_DP),
        observed_pct   = round(100 * sum(frequencies[[season_name]][-1] > 0) / estimate$Estimator, PCT_DP)
    )
}) |>
    bind_rows()

cat(NL, "Observed richness as a share of the Chao asymptotic estimate:", NL, sep = "")
print(as.data.frame(completeness), row.names = FALSE)
write.csv(completeness, COMPLETENESS_FILE, row.names = FALSE)


# --- Most sequence-abundant taxa per season ---------------------------------------------------------------------------

#' Most sequence-abundant taxa in a season, as a table. / 某季节序列丰度最高的类群（表）。
#'
#' @param season_name Season label, "Spring" or "Autumn".
#' @param top_count Number of taxa to return (default TOP_N).
#' @return A tibble of season, taxon and its relative read percentage.
top_taxa <- function(season_name, top_count = TOP_N) {
    read_share <- sort(colSums(reads[season == season_name, , drop = FALSE]), decreasing = TRUE)
    read_share <- read_share / sum(read_share)
    tibble(
        season  = season_name,
        taxon   = names(read_share)[1:top_count],
        rel_pct = round(100 * unname(read_share[1:top_count]), PCT_DP)
    )
}

#' Cumulative read share of the top-N taxa in a season. / 某季节前 N 个类群的累计读数占比。
#'
#' @param season_name Season label, "Spring" or "Autumn".
#' @param top_count Number of taxa to sum (default TOP_N).
#' @return A single percentage, rounded to PCT_DP decimals.
top_n_share <- function(season_name, top_count = TOP_N) {
    total_by_taxon <- colSums(reads[season == season_name, , drop = FALSE])
    round(100 * sum(sort(total_by_taxon, decreasing = TRUE)[1:top_count]) / sum(total_by_taxon), PCT_DP)
}

top_taxa_table <- map(SEASONS, top_taxa) |> bind_rows()
cat(glue("{NL}Top-{TOP_N} cumulative read share: ",
         "{SPRING} {top_n_share(SPRING)}% | {AUTUMN} {top_n_share(AUTUMN)}%"), NL)


# --- Fig. 2 occurrence table: presence of each taxon in each season ---------------------------------------------------
occurrence <- tibble(taxon = union(spring_taxa, autumn_taxa)) |>
    mutate(
        spring = as.integer(taxon %in% spring_taxa),
        autumn = as.integer(taxon %in% autumn_taxa)
    )


# --- Fig. 2B stacked composition: named taxa plus a pooled remainder --------------------------------------------------
# Panel B stacks the taxa that are dominant in at least one season, so a taxon abundant only in autumn still appears in
# the spring bar at its true (small) share. Everything outside that set is pooled into one remainder band, which keeps
# the bars summing to 100% without a legend of 100 entries.
# 图 2B 堆叠至少在一个季节占优的类群，其余合并为“其他”，使柱状图合计为 100%。
named_taxa <- union(
    top_taxa(SPRING)$taxon,
    top_taxa(AUTUMN)$taxon
)

#' Read shares for one season, with the unnamed taxa pooled. / 某季节的读数占比，未列出的类群合并为其他。
#'
#' @param season_name Season label, "Spring" or "Autumn".
#' @return A tibble of season, taxon (or "Others") and percentage of that season's reads.
composition_shares <- function(season_name) {
    season_totals <- colSums(reads[season == season_name, , drop = FALSE])
    percentages   <- 100 * season_totals / sum(season_totals)
    bind_rows(
        tibble(season = season_name, taxon = named_taxa, rel_pct = unname(percentages[named_taxa])),
        tibble(season = season_name, taxon = "Others",   rel_pct = sum(percentages[setdiff(names(percentages),
                                                                                          named_taxa)]))
    )
}

# Ordered by pooled abundance so the stacking order is stable and the legend reads largest-first, with the remainder
# band last regardless of its size.
# 按合并丰度排序，确保堆叠顺序稳定、图例自大到小，“其他”始终置末。
taxon_order <- names(sort(colSums(reads)[named_taxa], decreasing = TRUE))

shares <- map(SEASONS, composition_shares) |>
    bind_rows() |>
    mutate(
        taxon   = factor(taxon, levels = c(taxon_order, "Others")),
        rel_pct = round(rel_pct, PCT_DP)
    ) |>
    arrange(season, taxon)

cat(glue("{NL}Fig. 2B: {length(named_taxa)} named taxa plus a pooled remainder"), NL)

write.csv(top_taxa_table, TOP_TAXA_FILE,   row.names = FALSE)
write.csv(occurrence,     OCCURRENCE_FILE, row.names = FALSE)
write.csv(shares,         SHARES_FILE,     row.names = FALSE)
cat(NL, "wrote outputs/Table_top_abundant_taxa.csv, Fig2_seasonal_occurrence.csv, Fig2_composition_shares.csv, ",
    "TableS13_asymptotic_completeness.csv", NL, sep = "")
