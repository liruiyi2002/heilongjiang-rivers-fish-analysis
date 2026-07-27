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

# Output files written by this script (ALPHA_SITE_FILE is defined in 00_setup.R).
ALPHA_PC1_FILE <- file.path(OUT_DIR, "alpha_vs_PC1.csv")
SECTIONS_FILE  <- file.path(OUT_DIR, "TableS7_spatial_sections.csv")
EARTH_RADIUS_KM <- 6371   # mean Earth radius, for the haversine distance


# --- PCA of the hydro-geographic gradient (13 sites) ------------------------------------------------------------------
pca           <- prcomp(env[, ENV_VARS], scale. = TRUE)
var_explained <- round(100 * pca$sdev^2 / sum(pca$sdev^2), VAR_DP)
cat(NL, "== PCA of hydro-geographic variables ==", NL, sep = "")
cat(glue("Variance explained (PC1-3): ",
         "{var_explained[1]}% {var_explained[2]}% {var_explained[3]}%"), NL)
cat("PC1 loadings:", NL, sep = "")
print(round(sort(pca$rotation[, 1]), STAT_DP))


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
for (season_name in SEASONS) {
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
        season_data$rel ~ elev_m + strahler + log_discharge + log_width + grad_dem + dist_source_km,
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
}


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


# --- Spatial beta diversity among river sections (within season) ------------------------------------------------------
sections <- map(SEASONS, \(season_name) {
    season_data        <- season_subset(season_name)
    bray_dist          <- vegdist(season_data$rel, "bray")
    river_section      <- factor(section[season == season_name])
    section_permanova  <- adonis2(bray_dist ~ river_section, permutations = N_PERM)
    section_dispersion <- anova(betadisper(bray_dist, river_section))
    tibble(
        season       = season_name,
        PERMANOVA_R2 = round(section_permanova$R2[1], STAT_DP),
        PERMANOVA_p  = signif(section_permanova[["Pr(>F)"]][1], P_SIGFIG),
        betadisper_p = signif(section_dispersion[["Pr(>F)"]][1], P_SIGFIG)
    )
}) |>
    bind_rows()
cat(NL, "== Spatial beta diversity among sections (taxonomic) ==", NL, sep = "")
print(as.data.frame(sections), row.names = FALSE)
write.csv(sections, SECTIONS_FILE, row.names = FALSE)
