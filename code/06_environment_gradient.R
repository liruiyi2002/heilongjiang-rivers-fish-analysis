# ======================================================================================================================
# 06_environment_gradient.R
#
# Longitudinal environmental gradient (Figs 6-8, Table S7)
# --------------------------------------------------------
# PCA of the hydro-geographic variables; alpha vs PC1; composition vs PC1 (PERMANOVA); dbRDA; Mantel and partial Mantel
# (environmental vs geographic distance); and spatial beta diversity among river sections. Tests run within each season
# (n = 13).
#
# 纵向环境梯度（图 6-8，表 S7）
# -----------------------------
# 水文—地理变量的 PCA；alpha 对 PC1；组成对 PC1（PERMANOVA）；dbRDA；Mantel 与偏 Mantel（环境距离 vs 地理距离）；河段间
# 空间 beta 多样性。检验均在各季节内（n = 13）进行。
# ======================================================================================================================


# --- Load shared setup ------------------------------------------------------------------------------------------------
.args <- commandArgs(trailingOnly = FALSE)
.file <- sub("^--file=", "", grep("^--file=", .args, value = TRUE))
.dir  <- if (length(.file)) dirname(gsub("~\\+~", " ", .file)) else "."
source(file.path(.dir, "00_setup.R"))
set.seed(RANDOM_SEED)

# Output files written by this script (ALPHA_SITE_FILE is defined in 00_setup.R). The Fig. 6-8 files carry the
# plot-ready ordination coordinates, arrow coordinates and pair lists, so each figure is drawn from the same numbers
# this script reports rather than from a second, independent computation.
ALPHA_PC1_FILE <- file.path(OUT_DIR, "alpha_vs_PC1.csv")
SECTIONS_FILE  <- file.path(OUT_DIR, "TableS7_spatial_sections.csv")
CONTRASTS_FILE <- file.path(OUT_DIR, "TableS7b_section_contrasts.csv")
PCA_SCORES_FILE    <- file.path(OUT_DIR, "Fig6_pca_scores.csv")
PCA_LOADINGS_FILE  <- file.path(OUT_DIR, "Fig6_pca_loadings.csv")
PCA_VARIANCE_FILE  <- file.path(OUT_DIR, "Fig6_pca_variance.csv")
DBRDA_SCORES_FILE  <- file.path(OUT_DIR, "Fig7_dbrda_scores.csv")
DBRDA_ARROWS_FILE  <- file.path(OUT_DIR, "Fig7_dbrda_arrows.csv")
DBRDA_STATS_FILE   <- file.path(OUT_DIR, "Fig7_dbrda_stats.csv")
ENV_PAIRS_FILE     <- file.path(OUT_DIR, "Fig8_env_pairs.csv")
MANTEL_STATS_FILE  <- file.path(OUT_DIR, "Fig8_mantel_stats.csv")

VARPART_FILE     <- file.path(OUT_DIR, "TableS10_variation_partitioning.csv")
FUNC_GRADIENT_FILE <- file.path(OUT_DIR, "TableS11_functional_composition_PC1.csv")
DECAY_FILE       <- file.path(OUT_DIR, "TableS12_distance_decay.csv")

# Written by earlier scripts; needed here.
FUNCTIONAL_DIST_FILE <- file.path(OUT_DIR, "functional_distance.csv")   # 03, for the spatial-section analysis
CWM_FILE             <- file.path(OUT_DIR, "cwm_by_site_season.csv")    # 05, for functional composition vs PC1

EARTH_RADIUS_KM <- 6371   # mean Earth radius, for the haversine distance

# The hydro-geographic predictors entered into the dbRDA, kept in one place because both the model and its arrow
# labels are built from it.
DBRDA_VARS <- c("elev_m", "strahler", "log_discharge", "log_width", "grad_dem", "dist_source_km")


# --- PCA of the hydro-geographic gradient (13 sites) ------------------------------------------------------------------
pca           <- prcomp(env[, ENV_VARS], scale. = TRUE)
var_explained <- round(100 * pca$sdev^2 / sum(pca$sdev^2), VAR_DP)
cat(NL, "== PCA of hydro-geographic variables ==", NL, sep = "")
cat(glue("Variance explained (PC1-3): ",
         "{var_explained[1]}% {var_explained[2]}% {var_explained[3]}%"), NL)
cat("PC1 loadings:", NL, sep = "")
print(round(sort(pca$rotation[, 1]), STAT_DP))

# Plot-ready PCA for Fig. 6: site scores with their river section, variable loadings, and the variance per axis.
tibble(
    site    = rownames(pca$x),
    section = as.character(section[match(rownames(pca$x), meta$site)]),
    PC1     = round(pca$x[, 1], STAT_DP),
    PC2     = round(pca$x[, 2], STAT_DP)
) |>
    write.csv(PCA_SCORES_FILE, row.names = FALSE)

tibble(
    variable = rownames(pca$rotation),
    PC1      = round(pca$rotation[, 1], STAT_DP),
    PC2      = round(pca$rotation[, 2], STAT_DP)
) |>
    write.csv(PCA_LOADINGS_FILE, row.names = FALSE)

tibble(axis = paste0("PC", seq_along(var_explained)), percent = var_explained) |>
    head(3) |>
    write.csv(PCA_VARIANCE_FILE, row.names = FALSE)


# --- Great-circle (haversine) distance between sites ------------------------------------------------------------------

#' Great-circle (haversine) distance matrix between sites, in km. / 站点间的大圆（haversine）距离矩阵。
#'
#' @param lon Numeric vector of site longitudes (degrees).
#' @param lat Numeric vector of site latitudes (degrees).
#' @return A "dist" object of pairwise great-circle distances in kilometres.
haversine_dist <- function(lon, lat) {
    lon_rad     <- lon * pi / 180
    lat_rad     <- lat * pi / 180
    site_count  <- length(lon)
    dist_matrix <- matrix(0, site_count, site_count)

    for (from_site in seq_len(site_count)) {
        for (to_site in seq_len(site_count)) {
            delta_lon      <- lon_rad[to_site] - lon_rad[from_site]
            delta_lat      <- lat_rad[to_site] - lat_rad[from_site]
            haversine_term <- sin(delta_lat / 2)^2 +
                cos(lat_rad[from_site]) * cos(lat_rad[to_site]) * sin(delta_lon / 2)^2
            dist_matrix[from_site, to_site] <- 2 * EARTH_RADIUS_KM * asin(sqrt(haversine_term))
        }
    }

    as.dist(dist_matrix)
}


# --- Environment-community relationships, within each season (n = 13) -------------------------------------------------
# The per-season results are collected rather than only printed, because Figs 7 and 8 are drawn from them. Each season
# contributes its dbRDA ordination, its arrow coordinates, and its full list of site pairs.
gradient_results <- map(SEASONS, \(season_name) {
    season_data <- season_subset(season_name)
    season_env  <- season_data$env
    bray_dist   <- vegdist(season_data$rel, "bray")
    pc1_scores  <- pca$x[match(season_data$site_ids, rownames(env)), 1]

    # Composition ~ PC1
    pc1_permanova <- adonis2(bray_dist ~ pc1_scores, permutations = N_PERM)
    cat(glue("{NL}[{season_name}] composition ~ PC1: R2 = {round(pc1_permanova$R2[1], STAT_DP)}, ",
             "p = {sprintf(P_FMT, pc1_permanova[['Pr(>F)']][1])}"), NL)

    # dbRDA on the individual hydro-geographic factors
    dbrda <- capscale(
        as.formula(paste("season_data$rel ~", paste(DBRDA_VARS, collapse = " + "))),
        data = season_env, distance = "bray"
    )
    dbrda_test <- anova(dbrda, permutations = N_PERM_QUICK)
    cat(glue("[{season_name}] dbRDA (hydro-geographic factors): ",
             "adj R2 = {round(RsquareAdj(dbrda)$adj.r.squared, STAT_DP)}, ",
             "p = {round(dbrda_test[['Pr(>F)']][1], STAT_DP)}"), NL)

    # Mantel and partial Mantel: environmental vs geographic distance
    env_dist           <- dist(scale(season_env[, ENV_VARS]))
    geo_dist           <- haversine_dist(season_env$lon, season_env$lat)
    mantel_env         <- mantel(bray_dist, env_dist, permutations = N_PERM)
    mantel_env_partial <- mantel.partial(bray_dist, env_dist, geo_dist, permutations = N_PERM)
    cat(glue("[{season_name}] Mantel comm~env: r = {round(mantel_env$statistic, STAT_DP)}, ",
             "p = {sprintf(P_FMT, mantel_env$signif)} | partial (|geo): ",
             "r = {round(mantel_env_partial$statistic, STAT_DP)}, ",
             "p = {sprintf(P_FMT, mantel_env_partial$signif)}"), NL)

    # --- Plot-ready pieces for Figs 7 and 8 ---
    # Constrained axis percentages are taken over the constrained inertia, which is what a dbRDA axis label means.
    constrained_eig <- dbrda$CCA$eig
    axis_percent    <- 100 * constrained_eig / sum(constrained_eig)

    site_scores <- scores(dbrda, display = "wa", choices = 1:2, scaling = 2)
    arrows      <- scores(dbrda, display = "bp", choices = 1:2, scaling = 2)

    # Pairwise environmental distance against compositional dissimilarity, one row per site pair.
    pair_index <- which(lower.tri(as.matrix(bray_dist)), arr.ind = TRUE)
    site_ids   <- rownames(as.matrix(bray_dist))

    # Resolved before the tibble below, because a column named `season` would otherwise shadow the global season
    # vector inside the same tibble() call and silently return all 26 rows instead of this season's 13.
    season_sections <- as.character(section[season == season_name])

    list(
        scores = tibble(
            season  = season_name,
            site    = season_data$site_ids,
            section = season_sections,
            CAP1    = round(site_scores[, 1], STAT_DP),
            CAP2    = round(site_scores[, 2], STAT_DP)
        ),
        arrows = tibble(
            season   = season_name,
            variable = rownames(arrows),
            CAP1     = round(arrows[, 1], STAT_DP),
            CAP2     = round(arrows[, 2], STAT_DP)
        ),
        stats = tibble(
            season       = season_name,
            adj_R2       = round(RsquareAdj(dbrda)$adj.r.squared, STAT_DP),
            p            = signif(dbrda_test[["Pr(>F)"]][1], P_SIGFIG),
            cap1_percent = round(axis_percent[1], VAR_DP),
            cap2_percent = round(axis_percent[2], VAR_DP)
        ),
        pairs = tibble(
            season       = season_name,
            site_1       = site_ids[pair_index[, "row"]],
            site_2       = site_ids[pair_index[, "col"]],
            env_distance = round(as.matrix(env_dist)[pair_index], STAT_DP),
            bray         = round(as.matrix(bray_dist)[pair_index], DIST_DP)
        ),
        mantel = tibble(
            season    = season_name,
            mantel_r  = round(mantel_env$statistic, STAT_DP),
            p         = signif(mantel_env$signif, P_SIGFIG),
            partial_r = round(mantel_env_partial$statistic, STAT_DP),
            partial_p = signif(mantel_env_partial$signif, P_SIGFIG)
        )
    )
})

# Variables keep their column names here; the figure scripts attach display labels, so nothing presentational leaks
# into the analysis output.
map(gradient_results, "scores") |> bind_rows() |> write.csv(DBRDA_SCORES_FILE, row.names = FALSE)
map(gradient_results, "arrows") |> bind_rows() |> write.csv(DBRDA_ARROWS_FILE, row.names = FALSE)
map(gradient_results, "stats")  |> bind_rows() |> write.csv(DBRDA_STATS_FILE,  row.names = FALSE)
map(gradient_results, "pairs")  |> bind_rows() |> write.csv(ENV_PAIRS_FILE,    row.names = FALSE)
map(gradient_results, "mantel") |> bind_rows() |> write.csv(MANTEL_STATS_FILE, row.names = FALSE)


# --- Alpha diversity vs PC1 (within season, BH-FDR across the 22 tests) -----------------------------------------------
if (file.exists(ALPHA_SITE_FILE)) {
    alpha         <- read.csv(ALPHA_SITE_FILE, check.names = FALSE)
    alpha$PC1     <- pca$x[match(alpha$site, rownames(env)), 1]
    alpha_indices <- c("Richness", "Shannon", "Simpson", "Pielou", "Hill_q1", "Hill_q2",
                       "FRic", "FEve", "FDis", "FDiv", "RaoQ")

    alpha_vs_pc1 <- map(SEASONS, \(season_name) {
        season_alpha <- alpha[alpha$season == season_name, ]
        tibble(
            season = season_name,
            index  = alpha_indices,
            rho    = map_dbl(alpha_indices, \(index_name)
                cor(season_alpha[[index_name]], season_alpha$PC1, method = "spearman")),
            p      = map_dbl(alpha_indices, \(index_name)
                cor.test(season_alpha[[index_name]], season_alpha$PC1, method = "spearman", exact = FALSE)$p.value)
        )
    }) |>
        bind_rows() |>
        mutate(FDR = p.adjust(p, "BH"))

    cat(glue("{NL}== alpha ~ PC1: significant after FDR: ",
             "{sum(alpha_vs_pc1$FDR < FDR_ALPHA)} of {nrow(alpha_vs_pc1)} tests =="), NL)

    alpha_vs_pc1 |>
        mutate(rho = round(rho, STAT_DP), p = signif(p, P_SIGFIG), FDR = signif(FDR, P_SIGFIG)) |>
        write.csv(ALPHA_PC1_FILE, row.names = FALSE)
}


# --- Variation partitioning: season, environment and space ------------------------------------------------------------
# The envfit and dbRDA results above cannot say whether composition follows the environment or simply follows position
# along the river, because the river-size gradient *is* spatial. Partitioning the pooled variation into what season,
# environment and space each explain uniquely answers that directly, and answers it honestly: if the unique
# environmental fraction is not significant, the two cannot be separated with these data and the paper should say so
# rather than implying an environmental cause.
community_distance <- vegdist(rel, "bray")

# One frame holding all three predictor sets, so every model below is built from named columns of the same data. The
# alternative, a formula with `~ .` plus Condition() on a matrix, does not survive model.matrix().
SEASON_TERMS <- "season"
ENV_TERMS    <- ENV_VARS
SPACE_TERMS  <- c("lon", "lat")

predictors <- cbind(
    data.frame(season = factor(season)),
    as.data.frame(scale(env[match(meta$site, rownames(env)), ENV_VARS])),
    meta[, SPACE_TERMS]
)

partition <- varpart(community_distance, predictors[SEASON_TERMS], predictors[ENV_TERMS], predictors[SPACE_TERMS])
fractions <- partition$part$indfract

#' Significance of one unique fraction, conditioning on the other two. / 以另两组为条件检验某一独立部分的显著性。
#'
#' @param target_terms Column names of the predictor set being tested.
#' @param condition_terms Column names to partial out.
#' @return The permutation p-value.
unique_fraction_p <- function(target_terms, condition_terms) {
    model <- dbrda(
        reformulate(c(target_terms, sprintf("Condition(%s)", condition_terms)), response = "community_distance"),
        data = predictors
    )
    anova(model, permutations = N_PERM_QUICK)[["Pr(>F)"]][1]
}

variation <- tibble(
    component = c("Season | environment + space", "Environment | season + space", "Space | season + environment"),
    adj_R2    = round(fractions$Adj.R.square[1:3], STAT_DP),
    p         = signif(c(
        unique_fraction_p(SEASON_TERMS, c(ENV_TERMS, SPACE_TERMS)),
        unique_fraction_p(ENV_TERMS,    c(SEASON_TERMS, SPACE_TERMS)),
        unique_fraction_p(SPACE_TERMS,  c(SEASON_TERMS, ENV_TERMS))
    ), P_SIGFIG)
)

cat(NL, "== Variation partitioning (pooled, 26 site-seasons) ==", NL, sep = "")
print(as.data.frame(variation), row.names = FALSE)
write.csv(variation, VARPART_FILE, row.names = FALSE)


# --- Functional composition against the gradient ----------------------------------------------------------------------
# The taxonomic side of this question is answered above. The functional side is the one the introduction raises and is
# tested here on the same community-weighted trait means the Mantel test uses, so the two are commensurable.
if (!file.exists(CWM_FILE)) stop("Run 05_taxonomy_function.R first (needs cwm_by_site_season.csv).")
cwm_matrix <- read.csv(CWM_FILE, row.names = 1, check.names = FALSE)
cwm_matrix[] <- lapply(cwm_matrix, \(column) if (is.character(column)) as.factor(column) else column)

functional_gradient <- map(SEASONS, \(season_name) {
    season_rows <- season == season_name
    pc1_scores  <- pca$x[match(meta$site[season_rows], rownames(env)), 1]
    result      <- adonis2(gowdis(cwm_matrix[season_rows, ]) ~ pc1_scores, permutations = N_PERM)
    tibble(season = season_name,
           R2     = round(result$R2[1], STAT_DP),
           p      = result[["Pr(>F)"]][1])
}) |>
    bind_rows() |>
    mutate(FDR = signif(p.adjust(p, "BH"), P_SIGFIG), p = signif(p, P_SIGFIG))

cat(NL, "== Functional composition (Gower on CWM) ~ PC1 ==", NL, sep = "")
print(as.data.frame(functional_gradient), row.names = FALSE)
write.csv(functional_gradient, FUNC_GRADIENT_FILE, row.names = FALSE)


# --- Distance decay: environment versus geography ---------------------------------------------------------------------
# The partial Mantel above controls geography when testing environment. Running it the other way round is what shows
# the asymmetry, and a plain geographic decay model shows how little distance alone accounts for. Reported together so
# the claim "turnover tracks environment rather than distance" rests on both halves rather than on one.
decay <- map(SEASONS, \(season_name) {
    season_data <- season_subset(season_name)
    season_env  <- season_data$env
    bray_dist   <- vegdist(season_data$rel, "bray")
    env_dist    <- dist(scale(season_env[, ENV_VARS]))
    geo_dist    <- haversine_dist(season_env$lon, season_env$lat)
    # Distance along the river network, as the difference in distance-from-source between two sites.
    network_dist <- dist(season_env$dist_source_km)

    environment_given_geography <- mantel.partial(bray_dist, env_dist, geo_dist, permutations = N_PERM)
    geography_given_environment <- mantel.partial(bray_dist, geo_dist, env_dist, permutations = N_PERM)
    network_only                <- mantel(bray_dist, network_dist, permutations = N_PERM)
    geography_only              <- mantel(bray_dist, geo_dist, permutations = N_PERM)

    tibble(
        season = season_name,
        test   = c("Community ~ network position", "Community ~ geographic distance",
                   "Community ~ environment | geography", "Community ~ geography | environment"),
        mantel_r = round(c(network_only$statistic, geography_only$statistic,
                           environment_given_geography$statistic, geography_given_environment$statistic), STAT_DP),
        p        = signif(c(network_only$signif, geography_only$signif,
                            environment_given_geography$signif, geography_given_environment$signif), P_SIGFIG),
        # Share of turnover variance a simple linear decay on that distance accounts for.
        decay_R2 = round(c(summary(lm(as.vector(bray_dist) ~ as.vector(network_dist)))$r.squared,
                           summary(lm(as.vector(bray_dist) ~ as.vector(geo_dist)))$r.squared,
                           NA_real_, NA_real_), STAT_DP)
    )
}) |>
    bind_rows()

cat(NL, "== Distance decay: environment versus geography ==", NL, sep = "")
print(as.data.frame(decay), row.names = FALSE)
write.csv(decay, DECAY_FILE, row.names = FALSE)


# --- Spatial beta diversity among river sections (within season, both dimensions) -------------------------------------
# Both the taxonomic and the functional dimension are tested, because the manuscript reports them separately: only the
# functional one differs among sections in spring, and only it shows a dispersion difference in autumn. The functional
# distance matrix comes from script 03, which is the one place it is built.
if (!file.exists(FUNCTIONAL_DIST_FILE)) stop("Run 03_beta_diversity.R first (needs functional_distance.csv).")
functional_matrix <- as.matrix(read.csv(FUNCTIONAL_DIST_FILE, row.names = 1, check.names = FALSE))

#' FDR-corrected pairwise PERMANOVA between every pair of river sections. / 河段两两 PERMANOVA（FDR 校正）。
#'
#' An overall section effect does not say which sections differ, and the manuscript names a specific contrast, so the
#' pairwise tests are run and corrected across the three comparisons within each season and dimension.
#'
#' The full permutation count is used, not the quick one. These contrasts land close to the 0.05 threshold, and with
#' 999 permutations the autumn downstream-tributary result flips between significant and not depending only on the
#' random draw. A published claim must not depend on the seed, so the tests are run at N_PERM.
#'
#' @param distance_matrix Full distance matrix for the season's samples.
#' @param groups Factor of river sections, aligned to the matrix rows.
#' @return A list of the per-contrast tibble and a character summary of the FDR-significant contrasts.
pairwise_sections <- function(distance_matrix, groups) {
    combinations <- combn(levels(droplevels(groups)), 2, simplify = FALSE)
    tests <- map(combinations, \(pair) {
        keep <- groups %in% pair
        result <- adonis2(as.dist(distance_matrix[keep, keep]) ~ droplevels(groups[keep]),
                          permutations = N_PERM)
        tibble(
            contrast = paste(pair, collapse = "-"),
            n        = sum(keep),
            R2       = round(result$R2[1], STAT_DP),
            p        = result[["Pr(>F)"]][1]
        )
    }) |>
        bind_rows() |>
        mutate(FDR = p.adjust(p, "BH"))

    significant <- tests$contrast[tests$FDR < FDR_ALPHA]
    list(
        tests   = tests,
        summary = if (length(significant)) paste(significant, collapse = "; ") else "None"
    )
}

# One entry per season and dimension, each carrying both the overall summary row and its three pairwise contrasts.
section_results <- map(SEASONS, \(season_name) {
    season_rows   <- season == season_name
    season_data   <- season_subset(season_name)
    river_section <- factor(section[season_rows])

    # Taxonomic and functional, from the same section factor so the two rows are directly comparable.
    dimensions <- list(
        Taxonomic  = as.matrix(vegdist(season_data$rel, "bray")),
        Functional = functional_matrix[season_rows, season_rows]
    )

    map(names(dimensions), \(dimension_name) {
        distance_matrix    <- dimensions[[dimension_name]]
        section_permanova  <- adonis2(as.dist(distance_matrix) ~ river_section, permutations = N_PERM)
        section_dispersion <- anova(betadisper(as.dist(distance_matrix), river_section))
        pairwise           <- pairwise_sections(distance_matrix, river_section)
        list(
            summary = tibble(
                dimension       = dimension_name,
                season          = season_name,
                PERMANOVA_R2    = round(section_permanova$R2[1], STAT_DP),
                PERMANOVA_p     = signif(section_permanova[["Pr(>F)"]][1], P_SIGFIG),
                betadisper_p    = signif(section_dispersion[["Pr(>F)"]][1], P_SIGFIG),
                fdr_significant = pairwise$summary
            ),
            pairwise = pairwise$tests |>
                mutate(dimension = dimension_name, season = season_name, .before = 1) |>
                mutate(p = signif(p, P_SIGFIG), FDR = signif(FDR, P_SIGFIG))
        )
    })
}) |>
    list_flatten()

sections  <- map(section_results, "summary")  |> bind_rows() |> arrange(dimension, season)
contrasts <- map(section_results, "pairwise") |> bind_rows() |> arrange(dimension, season, contrast)

cat(NL, "== Spatial beta diversity among sections ==", NL, sep = "")
print(as.data.frame(sections), row.names = FALSE)
cat(NL, "-- pairwise contrasts (BH-corrected within each season and dimension) --", NL, sep = "")
print(as.data.frame(contrasts), row.names = FALSE)

write.csv(sections,  SECTIONS_FILE,  row.names = FALSE)
write.csv(contrasts, CONTRASTS_FILE, row.names = FALSE)
