# ======================================================================================================================
# 03_beta_diversity.R
#
# Seasonal beta diversity (Fig. 4)
# --------------------------------
# Taxonomic PERMANOVA, betadisper and PCoA, plus turnover/nestedness partitioning, for both the taxonomic and the
# functional facet. The functional partition is computed here from branch lengths on a UPGMA trait dendrogram, so no
# extra package is needed.
#
# 季节 beta 多样性（图 4）
# ------------------------
# 分类学与功能两个层面的 PERMANOVA、betadisper、PCoA 以及周转/嵌套分解。功能分解基于 UPGMA 性状树的枝长直接计算，
# 无需额外依赖包。
# ======================================================================================================================


# --- Load shared setup ------------------------------------------------------------------------------------------------
.args <- commandArgs(trailingOnly = FALSE)
.file <- sub("^--file=", "", grep("^--file=", .args, value = TRUE))
.dir  <- if (length(.file)) dirname(gsub("~\\+~", " ", .file)) else "."
source(file.path(.dir, "00_setup.R"))
set.seed(RANDOM_SEED)

# Output files written by this script. The three Fig. 4 files carry the plot-ready coordinates and statistics, so the
# figure is drawn from exactly the numbers reported here and cannot drift away from them.
BETA_PARTITION_FILE      <- file.path(OUT_DIR, "beta_partition_taxonomic.csv")
BETA_PARTITION_FUNC_FILE <- file.path(OUT_DIR, "beta_partition_functional.csv")
PCOA_SCORES_FILE         <- file.path(OUT_DIR, "Fig4_pcoa_scores.csv")
PCOA_STATS_FILE          <- file.path(OUT_DIR, "Fig4_pcoa_stats.csv")


# --- Taxonomic composition: PERMANOVA, dispersion, PCoA ---------------------------------------------------------------
bray_dist <- vegdist(rel, "bray")

permanova <- adonis2(bray_dist ~ season, permutations = N_PERM)
cat(NL, "== Seasonal PERMANOVA (Bray-Curtis) ==", NL, sep = "")
cat(glue("F = {round(permanova$F[1], STAT_DP)}, R2 = {round(permanova$R2[1], STAT_DP)}, ",
         "p = {sprintf(P_FMT, permanova[['Pr(>F)']][1])}"), NL)

dispersion      <- betadisper(bray_dist, season)
dispersion_test <- anova(dispersion)
cat(glue("betadisper: F = {round(dispersion_test[['F value']][1], STAT_DP)}, ",
         "p = {round(dispersion_test[['Pr(>F)']][1], STAT_DP)}"), NL)

# Bray-Curtis is non-Euclidean, so the raw eigenvalues include negative ones and a share taken over the positive
# eigenvalues alone overstates each axis. A Lingoes correction removes the negative eigenvalues, and its relative
# corrected eigenvalues are the percentages reported here and on the Fig. 4 axes. The same convention is applied to
# the functional ordination below, so the two panels are directly comparable.
pcoa              <- ape::pcoa(bray_dist, correction = "lingoes")
taxonomic_percent <- 100 * pcoa$values$Rel_corr_eig[1:2]
cat(glue("PCoA axes 1-2 variance (Lingoes-corrected): ",
         "{round(taxonomic_percent[1], VAR_DP)}%, {round(taxonomic_percent[2], VAR_DP)}%"), NL)


# --- Taxonomic turnover / nestedness (Baselga; paired spring vs autumn) -----------------------------------------------

#' Simpson-family partition of Sorensen dissimilarity for one site. / 单站点 Sorensen 相异性的分解。
#'
#' Splits the total taxonomic beta (Sorensen) between the two seasons at one site
#' into turnover (Simpson) and nestedness components (Baselga, 2010).
#'
#' @param site_name Site code, e.g. "W01".
#' @return A one-row tibble: site, total, turnover, nestedness.
partition_site <- function(site_name) {
    spring_pa <- presence_absence[paste0(SPRING, NAME_SEP, site_name), ]
    autumn_pa <- presence_absence[paste0(AUTUMN, NAME_SEP, site_name), ]

    shared      <- sum(spring_pa == 1 & autumn_pa == 1)   # taxa in both seasons
    spring_only <- sum(spring_pa == 1 & autumn_pa == 0)   # taxa only in spring
    autumn_only <- sum(spring_pa == 0 & autumn_pa == 1)   # taxa only in autumn

    denominator <- 2 * shared + spring_only + autumn_only
    sorensen    <- (spring_only + autumn_only) / denominator
    turnover    <- (spring_only + autumn_only - abs(spring_only - autumn_only)) /
                   (denominator - abs(spring_only - autumn_only))

    tibble(
        site       = site_name,
        total      = sorensen,
        turnover   = turnover,
        nestedness = sorensen - turnover
    )
}

partition <- map(unique(meta$site), partition_site) |> bind_rows()

cat(NL, "== Taxonomic beta partition (paired, mean +/- SD across 13 sites) ==", NL, sep = "")

# Print the across-site mean +/- SD for each partition component.
walk(c("total", "turnover", "nestedness"), \(component) {
    values <- partition[[component]]
    cat(glue("  {str_pad(component, 11, 'right')} ",
             "{sprintf('%.3f +/- %.3f', mean(values), sd(values))}"), NL)
})

partition |>
    mutate(across(c(total, turnover, nestedness), \(x) round(x, DIST_DP))) |>
    write.csv(BETA_PARTITION_FILE, row.names = FALSE)


# --- Functional beta partition (branch lengths on a UPGMA trait dendrogram) --------------------------------------------
# The functional facet uses the same Sorensen-family partition as the taxonomic one, but measured in trait-dendrogram
# branch length instead of taxon counts. Two assemblages that hold different taxa occupying the same part of trait
# space therefore come out functionally similar, which is the point of the comparison.
#
# For a pair of assemblages, with branch length shared by both (a) and unique to each (b, c):
#   total (Sorensen) = (b + c) / (2a + b + c)
#   turnover (Simpson) = min(b, c) / (a + min(b, c))
#   nestedness = total - turnover
# The three quantities are obtained from the length spanned by each assemblage and by their union, which is all that
# is needed and avoids a dependency on betapart.
functional_tree <- ape::as.phylo(hclust(gower_dist, method = "average"))     # UPGMA functional dendrogram

# Tip set below every edge, accumulated in one leaves-to-root sweep so that spanned_length() is a lookup rather than a
# repeated tree walk. Without this the 325 site-season pairs take minutes instead of seconds.
edge_tip_sets <- vector("list", max(functional_tree$edge))
for (row_index in rev(seq_len(nrow(functional_tree$edge)))) {
    parent_node <- functional_tree$edge[row_index, 1]
    child_node  <- functional_tree$edge[row_index, 2]
    child_tips  <- if (child_node <= ape::Ntip(functional_tree)) child_node else edge_tip_sets[[child_node]]
    edge_tip_sets[[child_node]]  <- child_tips
    edge_tip_sets[[parent_node]] <- union(edge_tip_sets[[parent_node]], child_tips)
}

#' Total dendrogram branch length spanned by a set of tips. / 一组叶节点所跨越的树枝长度总和。
#'
#' An edge counts once if any tip below it belongs to the set, which is Faith's rooted measure applied to a trait
#' dendrogram rather than a phylogeny.
#'
#' @param tip_indices Integer indices into the tree's tip labels.
#' @return The summed branch length.
spanned_length <- function(tip_indices) {
    on_path <- vapply(seq_len(nrow(functional_tree$edge)),
                      \(row_index) any(edge_tip_sets[[functional_tree$edge[row_index, 2]]] %in% tip_indices),
                      logical(1))
    sum(functional_tree$edge.length[on_path])
}

#' Tip indices for the taxa present in one sample. / 某样本中出现类群对应的叶节点索引。
#'
#' @param sample_name Row name of presence_absence, e.g. "Spring_W01".
#' @return Integer indices into the tree's tip labels.
sample_tips <- function(sample_name) {
    present <- colnames(presence_absence)[presence_absence[sample_name, ] == 1]
    match(present, functional_tree$tip.label)
}

# Spanned length per sample, computed once; there are only 26.
sample_spanned <- vapply(rownames(presence_absence), \(s) spanned_length(sample_tips(s)), numeric(1))

#' Sorensen-family functional partition between two samples. / 两样本间功能 beta 的 Sorensen 族分解。
#'
#' @param first_sample Row name of presence_absence.
#' @param second_sample Row name of presence_absence.
#' @return Named numeric vector: total, turnover, nestedness.
functional_partition_pair <- function(first_sample, second_sample) {
    union_length  <- spanned_length(union(sample_tips(first_sample), sample_tips(second_sample)))
    shared        <- sample_spanned[[first_sample]] + sample_spanned[[second_sample]] - union_length
    first_unique  <- union_length - sample_spanned[[second_sample]]
    second_unique <- union_length - sample_spanned[[first_sample]]

    sorensen <- (first_unique + second_unique) / (2 * shared + first_unique + second_unique)
    simpson  <- min(first_unique, second_unique) / (shared + min(first_unique, second_unique))
    c(total = sorensen, turnover = simpson, nestedness = sorensen - simpson)
}

# Paired spring-versus-autumn partition at each site, matching the taxonomic partition above.
functional_partition <- map(unique(meta$site), \(site_name) {
    components <- functional_partition_pair(paste0(SPRING, NAME_SEP, site_name),
                                            paste0(AUTUMN, NAME_SEP, site_name))
    tibble(site = site_name, total = components[["total"]],
           turnover = components[["turnover"]], nestedness = components[["nestedness"]])
}) |>
    bind_rows()

cat(NL, "== Functional beta partition (paired, mean +/- SD across 13 sites) ==", NL, sep = "")
walk(c("total", "turnover", "nestedness"), \(component) {
    values <- functional_partition[[component]]
    cat(glue("  {str_pad(component, 11, 'right')} ",
             "{sprintf('%.3f +/- %.3f', mean(values), sd(values))}"), NL)
})

functional_partition |>
    mutate(across(c(total, turnover, nestedness), \(x) round(x, DIST_DP))) |>
    write.csv(BETA_PARTITION_FUNC_FILE, row.names = FALSE)


# --- Functional composition: PERMANOVA, dispersion, PCoA --------------------------------------------------------------
# The full pairwise total-functional-beta matrix, which is the functional counterpart of bray_dist.
sample_names     <- rownames(presence_absence)
functional_total <- matrix(0, length(sample_names), length(sample_names),
                           dimnames = list(sample_names, sample_names))
for (i in seq_len(length(sample_names) - 1L)) {
    for (j in seq(i + 1L, length(sample_names))) {
        value <- functional_partition_pair(sample_names[i], sample_names[j])[["total"]]
        functional_total[i, j] <- functional_total[j, i] <- value
    }
}
functional_dist <- as.dist(functional_total)

functional_permanova <- adonis2(functional_dist ~ season, permutations = N_PERM)
cat(NL, "== Functional PERMANOVA (Sorensen on trait-dendrogram branch length) ==", NL, sep = "")
cat(glue("F = {round(functional_permanova$F[1], STAT_DP)}, ",
         "R2 = {round(functional_permanova$R2[1], STAT_DP)}, ",
         "p = {sprintf(P_FMT, functional_permanova[['Pr(>F)']][1])}"), NL)

functional_dispersion_test <- anova(betadisper(functional_dist, season))
cat(glue("betadisper: F = {round(functional_dispersion_test[['F value']][1], STAT_DP)}, ",
         "p = {round(functional_dispersion_test[['Pr(>F)']][1], STAT_DP)}"), NL)

functional_pcoa    <- ape::pcoa(functional_dist, correction = "lingoes")
functional_percent <- 100 * functional_pcoa$values$Rel_corr_eig[1:2]
cat(glue("PCoA axes 1-2 variance (Lingoes-corrected): ",
         "{round(functional_percent[1], VAR_DP)}%, {round(functional_percent[2], VAR_DP)}%"), NL)


# --- Plot-ready coordinates and statistics for Fig. 4 -----------------------------------------------------------------
# Corrected coordinates go with the corrected percentages, so each panel's points and axis labels describe the same
# ordination. The correction shifts the coordinates only in the third decimal, so the picture is unchanged.
pcoa_scores <- bind_rows(
    tibble(facet = "Taxonomic", sample = rownames(pcoa$vectors.cor),
           axis1 = pcoa$vectors.cor[, 1], axis2 = pcoa$vectors.cor[, 2]),
    tibble(facet = "Functional", sample = rownames(functional_pcoa$vectors.cor),
           axis1 = functional_pcoa$vectors.cor[, 1], axis2 = functional_pcoa$vectors.cor[, 2])
) |>
    mutate(
        season = sub(paste0(NAME_SEP, ".*$"), "", sample),
        site   = sub(paste0("^[^", NAME_SEP, "]*", NAME_SEP), "", sample),
        across(c(axis1, axis2), \(x) round(x, DIST_DP))
    )

pcoa_stats <- tibble(
    facet         = c("Taxonomic", "Functional"),
    axis1_percent = round(c(taxonomic_percent[1], functional_percent[1]), VAR_DP),
    axis2_percent = round(c(taxonomic_percent[2], functional_percent[2]), VAR_DP),
    permanova_F   = round(c(permanova$F[1], functional_permanova$F[1]), STAT_DP),
    permanova_R2  = round(c(permanova$R2[1], functional_permanova$R2[1]), STAT_DP),
    permanova_p   = c(permanova[["Pr(>F)"]][1], functional_permanova[["Pr(>F)"]][1]),
    betadisper_p  = round(c(dispersion_test[["Pr(>F)"]][1], functional_dispersion_test[["Pr(>F)"]][1]), STAT_DP)
)

write.csv(pcoa_scores, PCOA_SCORES_FILE, row.names = FALSE)
write.csv(pcoa_stats,  PCOA_STATS_FILE,  row.names = FALSE)
cat(NL, "wrote outputs/beta_partition_taxonomic.csv, beta_partition_functional.csv, ",
    "Fig4_pcoa_scores.csv, Fig4_pcoa_stats.csv", NL, sep = "")
