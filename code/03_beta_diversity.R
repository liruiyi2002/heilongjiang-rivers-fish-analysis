# ======================================================================================================================
# 03_beta_diversity.R
#
# Seasonal beta diversity (Fig. 4)
# --------------------------------
# Taxonomic PERMANOVA, betadisper and PCoA, plus turnover/nestedness partitioning. The functional partition uses
# betapart (optional); if it is not installed, a ready-to-run template is printed.
#
# 季节 beta 多样性（图 4）
# ------------------------
# 分类学 PERMANOVA、betadisper、PCoA，以及周转/嵌套分解。功能分解依赖 betapart（可选）；若未安装则打印可直接运行的模板。
# ======================================================================================================================


# --- Load shared setup ------------------------------------------------------------------------------------------------
.args <- commandArgs(trailingOnly = FALSE)
.file <- sub("^--file=", "", grep("^--file=", .args, value = TRUE))
.dir  <- if (length(.file)) dirname(gsub("~\\+~", " ", .file)) else "."
source(file.path(.dir, "00_setup.R"))
set.seed(RANDOM_SEED)

# Output file written by this script.
BETA_PARTITION_FILE <- file.path(OUT_DIR, "beta_partition_taxonomic.csv")


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

pcoa         <- cmdscale(bray_dist, k = 2, eig = TRUE)
positive_eig <- pcoa$eig[pcoa$eig > 0]
cat(glue("PCoA axes 1-2 variance: {round(100 * pcoa$eig[1] / sum(positive_eig), VAR_DP)}%, ",
         "{round(100 * pcoa$eig[2] / sum(positive_eig), VAR_DP)}%"), NL)


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


# --- Functional beta partition (requires the betapart package) --------------------------------------------------------
# Paper values: total 0.147, turnover 0.119, nestedness 0.029; functional PERMANOVA
# R2 = 0.562. betapart is not part of this run's environment, so the template below
# is printed for the reader to run: it builds a UPGMA functional dendrogram from the
# Gower distance and partitions the paired seasons.
cat(NL, "== Functional beta partition: run the template below with betapart installed ==", NL, sep = "")

functional_template <- '
library(betapart)
tree  <- hclust(gower_dist, method = "average")          # UPGMA functional dendrogram
fpart <- lapply(unique(meta$site), function(site_name) {
    paired_pa <- presence_absence[c(paste0(SPRING, NAME_SEP, site_name), paste0(AUTUMN, NAME_SEP, site_name)), ]
    core      <- functional.betapart.core(paired_pa, tree)
    pair      <- functional.beta.pair(core, index.family = "sorensen")
    c(total      = pair$funct.beta.sor[1],
      turnover   = pair$funct.beta.sim[1],
      nestedness = pair$funct.beta.sne[1])
})
colMeans(do.call(rbind, fpart))
'
cat(functional_template, NL)
