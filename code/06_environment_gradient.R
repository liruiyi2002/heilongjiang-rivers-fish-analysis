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
# 本脚本的输出文件；图 6-8 的文件含排序坐标、箭头坐标与样本对清单。
ALPHA_PC1_FILE <- file.path(OUT_DIR, "alpha_vs_PC1.csv")
# The manuscript's only main-text table. / 稿件唯一的正文表格。
SITE_TABLE_FILE <- file.path(OUT_DIR, "Table1_site_characteristics.csv")
SECTIONS_FILE  <- file.path(OUT_DIR, "TableS7_spatial_sections.csv")
CONTRASTS_FILE <- file.path(OUT_DIR, "TableS8_section_contrasts.csv")
PCA_SCORES_FILE    <- file.path(OUT_DIR, "Fig6_pca_scores.csv")
PCA_LOADINGS_FILE  <- file.path(OUT_DIR, "Fig6_pca_loadings.csv")
PCA_VARIANCE_FILE  <- file.path(OUT_DIR, "Fig6_pca_variance.csv")
DBRDA_SCORES_FILE  <- file.path(OUT_DIR, "Fig7_dbrda_scores.csv")
DBRDA_ARROWS_FILE  <- file.path(OUT_DIR, "Fig7_dbrda_arrows.csv")
DBRDA_STATS_FILE   <- file.path(OUT_DIR, "Fig7_dbrda_stats.csv")
ENV_PAIRS_FILE     <- file.path(OUT_DIR, "Fig8_env_pairs.csv")
MANTEL_STATS_FILE  <- file.path(OUT_DIR, "Fig8_mantel_stats.csv")

VARPART_FILE     <- file.path(OUT_DIR, "TableS11_variation_partitioning.csv")
FUNC_GRADIENT_FILE <- file.path(OUT_DIR, "TableS12_functional_composition_PC1.csv")
DECAY_FILE       <- file.path(OUT_DIR, "TableS13_distance_decay.csv")
# Composition against PC1 and the envfit correlates are quoted in the Results, so both are written out rather than
# only printed. / 组成对 PC1 与 envfit 相关量在结果中被引用，故一并写出文件。
PC1_PERMANOVA_FILE <- file.path(OUT_DIR, "TableS15_composition_PC1.csv")
ENVFIT_FILE        <- file.path(OUT_DIR, "TableS16_envfit.csv")
# The Results also state that no index tracked a single representative variable and that main-stem and tributary sites
# did not differ. Both are computed and written here, so neither claim rests on an analysis with no generator.
# 结果中另称「无指数随单一代表性变量变化」「干流与支流无差异」，两者在此计算并写出，不留无生成器的论断。
ALPHA_LOCAL_FILE   <- file.path(OUT_DIR, "TableS17_alpha_local_gradient.csv")

# Written by earlier scripts; needed here.
# 由前序脚本写出、本脚本需要读取的文件。
FUNCTIONAL_DIST_FILE <- file.path(OUT_DIR, "functional_distance.csv")   # 03, for the spatial-section analysis
CWM_FILE             <- file.path(OUT_DIR, "cwm_by_site_season.csv")    # 05, for functional composition vs PC1

EARTH_RADIUS_KM <- 6371   # mean Earth radius, for the haversine distance

# The hydro-geographic predictors entered into the dbRDA, kept in one place because both the model and its arrow
# labels are built from it.
# 进入 dbRDA 的水文—地理预测变量，集中定义以供模型与箭头标签共用。
DBRDA_VARS <- c("elev_m", "strahler", "log_discharge", "log_width", "grad_dem", "dist_source_km")


# --- PCA of the hydro-geographic gradient (13 sites) ------------------------------------------------------------------
pca           <- prcomp(env[, ENV_VARS], scale. = TRUE)
var_explained <- round(100 * pca$sdev^2 / sum(pca$sdev^2), VAR_DP)
cat(NL, "== PCA of hydro-geographic variables ==", NL, sep = "")
cat(glue("Variance explained (PC1-3): ",
         "{var_explained[1]}% {var_explained[2]}% {var_explained[3]}%"), NL)
cat("PC1 loadings:", NL, sep = "")
print(round(sort(pca$rotation[, 1]), STAT_DP))


# --- Table 1: site characteristics (main text) -------------------------------------------------------------------------
# The paper had eight figures and no table. For an applied journal the first thing a reader wants is the sites
# themselves: where they are, how big the river is there, and where each sits on the gradient every later analysis
# uses. Everything here is already in data/, so the table is a presentation of the deposited data rather than a new
# result, and it is generated rather than typed so it cannot drift from the analysis.
# 表 1：站点概况（正文）。原稿有八幅图而无表；对应用类期刊而言，读者首先需要的是站点本身——位置、河道规模，
# 以及各站点在后续分析所用梯度上的位置。数据均已在 data/ 中，故此表为已交付数据的呈现而非新结果，且由代码
# 生成，不会与分析脱节。
site_table <- tibble(
    site        = rownames(env),
    site_name   = env$site_name,
    section     = as.character(section[match(rownames(env), meta$site)]),
    channel     = env$channel_type,
    lat         = round(env$lat, 3),
    lon         = round(env$lon, 3),
    strahler    = as.integer(env$strahler),
    drainage    = round(env$drainage_km2, 0),
    discharge   = round(env$discharge_cms, 2),
    dist_source = round(env$dist_source_km, 1),
    PC1         = round(pca$x[, 1], STAT_DP)
) |>
    arrange(desc(PC1))
stopifnot(nrow(site_table) == 13L, !anyNA(site_table))
write.csv(site_table, SITE_TABLE_FILE, row.names = FALSE)
cat(NL, "== Table 1: site characteristics ==", NL, sep = "")
print(as.data.frame(site_table), row.names = FALSE)

# Plot-ready PCA for Fig. 6: site scores with their river section, variable loadings, and the variance per axis.
# 图 6 所需的 PCA 绘图数据：站点得分与河段、变量载荷、各轴方差。
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
# 逐季节结果予以收集而非仅打印，因图 7、8 由其绘制。
gradient_results <- map(SEASONS, \(season_name) {
    season_data <- season_subset(season_name)
    season_env  <- season_data$env
    bray_dist   <- vegdist(season_data$rel, "bray")
    pc1_scores  <- pca$x[match(season_data$site_ids, rownames(env)), 1]

    # Composition ~ PC1, plus the dispersion check that the Results report alongside it.
    # 组成对 PC1，并附结果中一并报告的离散度检验。
    pc1_permanova  <- adonis2(bray_dist ~ pc1_scores, permutations = N_PERM)
    pc1_dispersion <- anova(betadisper(bray_dist, cut(pc1_scores, 2, labels = c("low", "high"))))
    cat(glue("{NL}[{season_name}] composition ~ PC1: R2 = {round(pc1_permanova$R2[1], STAT_DP)}, ",
             "p = {sprintf(P_FMT, pc1_permanova[['Pr(>F)']][1])}"), NL)

    # Envfit of the hydro-geographic variables on the unconstrained ordination. The Results name the strongest
    # correlates, so the whole table is written rather than left to the console.
    # 水文—地理变量在非约束排序上的 envfit；结果中提及最强相关量，故整表写出。
    ordination <- capscale(bray_dist ~ 1)
    fitted_env <- envfit(ordination, season_env[, ENV_VARS], permutations = N_PERM)

    # dbRDA on the individual hydro-geographic factors
    # 以各单一水文—地理因子为约束的 dbRDA。
    dbrda <- capscale(
        as.formula(paste("season_data$rel ~", paste(DBRDA_VARS, collapse = " + "))),
        data = season_env, distance = "bray"
    )
    # N_PERM, not N_PERM_QUICK. At 999 permutations the Monte-Carlo standard error on this p-value is about 0.006,
    # which is larger than its distance from 0.05: a sweep over seeds spanned 0.027 to 0.055, so the significance
    # call moved with the seed. Every neighbouring test here already uses N_PERM.
    # 此处须用 N_PERM。999 次置换下该 p 值的蒙特卡洛标准误约 0.006，大于其与 0.05 之距：不同随机种子下
    # 结果在 0.027 至 0.055 间摆动，显著性判断随种子而变。相邻各检验本已使用 N_PERM。
    dbrda_test <- anova(dbrda, permutations = N_PERM)
    cat(glue("[{season_name}] dbRDA (hydro-geographic factors): ",
             "adj R2 = {round(RsquareAdj(dbrda)$adj.r.squared, STAT_DP)}, ",
             "p = {round(dbrda_test[['Pr(>F)']][1], STAT_DP)}"), NL)

    # Mantel and partial Mantel: environmental vs geographic distance
    # Mantel 与偏 Mantel：环境距离 vs 地理距离。
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
    # 约束轴百分比按约束惯量计算，此即 dbRDA 轴标签的含义。
    constrained_eig <- dbrda$CCA$eig
    axis_percent    <- 100 * constrained_eig / sum(constrained_eig)

    site_scores <- scores(dbrda, display = "wa", choices = 1:2, scaling = 2)
    arrows      <- scores(dbrda, display = "bp", choices = 1:2, scaling = 2)

    # Pairwise environmental distance against compositional dissimilarity, one row per site pair.
    # 两两环境距离对组成相异性，每个站点对一行。
    pair_index <- which(lower.tri(as.matrix(bray_dist)), arr.ind = TRUE)
    site_ids   <- rownames(as.matrix(bray_dist))

    # Resolved before the tibble below, because a column named `season` would otherwise shadow the global season
    # vector inside the same tibble() call and silently return all 26 rows instead of this season's 13.
    # 先在 tibble 之外求值：同名列 season 会遮蔽全局向量，导致 13 行静默变为 26 行。
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
        ),
        pc1 = tibble(
            season       = season_name,
            R2           = round(pc1_permanova$R2[1], STAT_DP),
            p            = signif(pc1_permanova[["Pr(>F)"]][1], P_SIGFIG),
            betadisper_p = signif(pc1_dispersion[["Pr(>F)"]][1], P_SIGFIG)
        ),
        envfit = tibble(
            season   = season_name,
            variable = names(fitted_env$vectors$r),
            r2       = round(fitted_env$vectors$r, STAT_DP),
            p        = signif(fitted_env$vectors$pvals, P_SIGFIG)
        )
    )
})

# Variables keep their column names here; the figure scripts attach display labels, so nothing presentational leaks
# into the analysis output.
# 此处保留原始列名；显示标签由绘图脚本添加，避免呈现细节渗入分析输出。
map(gradient_results, "scores") |> bind_rows() |> write.csv(DBRDA_SCORES_FILE, row.names = FALSE)
map(gradient_results, "arrows") |> bind_rows() |> write.csv(DBRDA_ARROWS_FILE, row.names = FALSE)
map(gradient_results, "stats")  |> bind_rows() |> write.csv(DBRDA_STATS_FILE,  row.names = FALSE)
map(gradient_results, "pairs")  |> bind_rows() |> write.csv(ENV_PAIRS_FILE,    row.names = FALSE)
map(gradient_results, "mantel") |> bind_rows() |> write.csv(MANTEL_STATS_FILE, row.names = FALSE)
map(gradient_results, "pc1")    |> bind_rows() |> write.csv(PC1_PERMANOVA_FILE, row.names = FALSE)
map(gradient_results, "envfit") |> bind_rows() |> arrange(season, -r2) |>
    write.csv(ENVFIT_FILE, row.names = FALSE)


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

    # --- Alpha diversity against a single representative variable, and against channel type ---------------------------
    # The Results state that no index tracked "a representative single variable" and that main-stem and tributary sites
    # did not differ. Both claims were being made with no code behind them, so they are computed here rather than
    # asserted. Distance from source is the representative variable: it is the strongest envfit correlate in spring and
    # is not a log transform of another predictor.
    # 结果中「单一代表性变量」与「干流—支流无差异」两项此前无代码支撑，故在此实算而非空言。以离源距离
    # 为代表性变量：其在春季 envfit 中相关最强，且非其他变量的对数变换。
    env_row <- match(alpha$site, rownames(env))
    alpha$dist_source_km <- env$dist_source_km[env_row]
    alpha$channel_type   <- env$channel_type[env_row]
    stopifnot(!anyNA(alpha$dist_source_km), !anyNA(alpha$channel_type),
              length(unique(alpha$channel_type)) == 2L)

    alpha_local <- map(SEASONS, \(season_name) {
        season_alpha <- alpha[alpha$season == season_name, ]
        tibble(
            season      = season_name,
            index       = alpha_indices,
            rho_dist    = map_dbl(alpha_indices, \(index_name)
                cor(season_alpha[[index_name]], season_alpha$dist_source_km, method = "spearman")),
            p_dist      = map_dbl(alpha_indices, \(index_name)
                cor.test(season_alpha[[index_name]], season_alpha$dist_source_km,
                         method = "spearman", exact = FALSE)$p.value),
            p_channel   = map_dbl(alpha_indices, \(index_name)
                wilcox.test(season_alpha[[index_name]] ~ season_alpha$channel_type)$p.value)
        )
    }) |>
        bind_rows() |>
        mutate(FDR_dist = p.adjust(p_dist, "BH"), FDR_channel = p.adjust(p_channel, "BH"))

    cat(glue("{NL}== alpha ~ distance from source: {sum(alpha_local$FDR_dist < FDR_ALPHA)} of ",
             "{nrow(alpha_local)} significant after FDR; main-stem vs tributary: ",
             "{sum(alpha_local$FDR_channel < FDR_ALPHA)} of {nrow(alpha_local)} =="), NL)

    alpha_local |>
        mutate(across(c(rho_dist), \(x) round(x, STAT_DP)),
               across(c(p_dist, p_channel, FDR_dist, FDR_channel), \(x) signif(x, P_SIGFIG))) |>
        write.csv(ALPHA_LOCAL_FILE, row.names = FALSE)
}


# --- Variation partitioning: season, environment and space ------------------------------------------------------------
# The envfit and dbRDA results above cannot say whether composition follows the environment or simply follows position
# along the river, because the river-size gradient *is* spatial. Partitioning the pooled variation into what season,
# environment and space each explain uniquely answers that directly, and answers it honestly: if the unique
# environmental fraction is not significant, the two cannot be separated with these data and the paper should say so
# rather than implying an environmental cause.
# 上文的 envfit 与 dbRDA 无法区分组成是随环境还是随网络位置变化；方差分解可直接回答，且能诚实作答。
community_distance <- vegdist(rel, "bray")

# One frame holding all three predictor sets, so every model below is built from named columns of the same data. The
# alternative, a formula with `~ .` plus Condition() on a matrix, does not survive model.matrix().
# 三组预测变量合于一个数据框，使下方各模型均由同一数据的具名列构建。
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
# 分类学一侧已在上文回答；功能一侧才是引言所提出的问题。
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
# 上文的偏 Mantel 在检验环境时控制地理；反向再做一次方能显示这一不对称。
decay <- map(SEASONS, \(season_name) {
    season_data <- season_subset(season_name)
    season_env  <- season_data$env
    bray_dist   <- vegdist(season_data$rel, "bray")
    env_dist    <- dist(scale(season_env[, ENV_VARS]))
    geo_dist    <- haversine_dist(season_env$lon, season_env$lat)
    # Distance along the river network, as the difference in distance-from-source between two sites.
    # 沿河网的距离，以两站点距源距离之差表示。
    network_dist <- dist(season_env$dist_source_km)

    # environment | geography is already tested in the loop above; reusing it keeps the two tables in agreement,
    # whereas testing it twice gave two different permutation p-values for one test.
    # 环境|地理 已在上文检验；此处复用其结果，避免同一检验出现两个不同的置换 p 值。
    loop_mantel <- map(gradient_results, "mantel") |> bind_rows()
    environment_given_geography <- list(
        statistic = loop_mantel$partial_r[loop_mantel$season == season_name],
        signif    = loop_mantel$partial_p[loop_mantel$season == season_name]
    )
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
        # 该距离的简单线性衰减所能解释的周转方差比例。
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
# 分类学与功能两个层面分别检验，因稿件对二者分别报告。
if (!file.exists(FUNCTIONAL_DIST_FILE)) stop("Run 03_beta_diversity.R first (needs functional_distance.csv).")
functional_matrix <- as.matrix(read.csv(FUNCTIONAL_DIST_FILE, row.names = 1, check.names = FALSE))

#' FDR-corrected pairwise PERMANOVA between every pair of river sections. / 河段两两 PERMANOVA（FDR 校正）。
#'
#' An overall section effect does not say which sections differ, and the manuscript names a specific contrast, so the
#' pairwise tests are run and corrected across the three comparisons within each season and dimension.
#'
#' Every distinct relabelling of a two-group comparison. / 两组比较的全部不同标签分配。
#'
#' A two-group PERMANOVA on n samples has only choose(n, n1) genuinely different group assignments, which for the
#' eleven downstream and tributary sites is 462. Asking vegan for 9,999 permutations therefore does not sample the
#' space more thoroughly, it samples a space of 462 outcomes 9,999 times at random, and the resulting p-value moves
#' from run to run. These contrasts sit near 0.05, so that movement decided significance: the autumn
#' downstream-tributary result crossed the threshold between runs. Enumerating all 462 gives the exact p-value.
#'
#' @param groups Factor of group membership, already ordered so that the first level comes first.
#' @return An integer matrix whose rows are the permutations to test.
exact_permutations <- function(groups) {
    sample_count <- length(groups)
    first_size   <- sum(groups == levels(groups)[1])
    assignments  <- combn(sample_count, first_size, simplify = FALSE)
    t(vapply(assignments,
             \(chosen) as.integer(c(chosen, setdiff(seq_len(sample_count), chosen))),
             integer(sample_count)))
}

#' Pairwise PERMANOVA between river sections, tested exactly and corrected within the set.
#' 河段间两两 PERMANOVA，精确检验并在组内校正。
#'
#' @param distance_matrix Full distance matrix for the season's samples.
#' @param groups Factor of river sections, aligned to the matrix rows.
#' @return A list of the per-contrast tibble and a character summary of the FDR-significant contrasts.
pairwise_sections <- function(distance_matrix, groups) {
    combinations <- combn(levels(droplevels(groups)), 2, simplify = FALSE)
    tests <- map(combinations, \(pair) {
        keep <- groups %in% pair
        # Ordered by group so that exact_permutations() can build assignments by position.
        # 按组排序，使 exact_permutations() 能按位置构建标签分配。
        order_by_group <- order(factor(groups[keep], levels = pair))
        pair_groups    <- droplevels(factor(groups[keep][order_by_group], levels = pair))
        pair_distance  <- as.dist(distance_matrix[keep, keep][order_by_group, order_by_group])

        result <- adonis2(pair_distance ~ pair_groups,
                          permutations = exact_permutations(pair_groups))
        tibble(
            contrast     = paste(pair, collapse = "-"),
            n            = sum(keep),
            permutations = nrow(exact_permutations(pair_groups)),
            R2           = round(result$R2[1], STAT_DP),
            p            = result[["Pr(>F)"]][1]
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
# 每个季节与层面一个条目，同时携带总体汇总行及其三个两两对比。
section_results <- map(SEASONS, \(season_name) {
    season_rows   <- season == season_name
    season_data   <- season_subset(season_name)
    river_section <- factor(section[season_rows])

    # Taxonomic and functional, from the same section factor so the two rows are directly comparable.
    # 分类学与功能取自同一河段因子，使两行可直接比较。
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
