# ======================================================================================================================
# 08_figures_main.R
#
# Main-text figures 2-8
# ---------------------
# Draws every main-text figure except Figure 1, which is the study-area map and is drawn by map_generator/. Each figure
# is built only from files in outputs/, written by scripts 01-07, so a figure can never disagree with the statistic it
# reports: change an analysis and the figure follows on the next run. Run scripts 01-07 first.
#
# Every figure is written twice, as a 500 dpi LZW TIFF for the Elsevier submission and as a vector PDF, at one of the
# three permitted column widths. figure_style.R holds the specification and audits each file after writing it.
#
# 正文插图 2-8
# ------------
# 绘制除图 1（研究区地图，由 map_generator/ 生成）以外的全部正文插图。所有图形仅取自 outputs/ 中由脚本 01-07 写出的
# 文件，因此图形与其所报告的统计量不会脱节：分析一旦改变，下次运行图形即随之更新。请先运行脚本 01-07。
#
# 每幅图同时输出 500 dpi LZW TIFF（供 Elsevier 投稿）与矢量 PDF，宽度取三种允许栏宽之一。规范定义与写出后的校验均在
# figure_style.R 中。
# ======================================================================================================================


# --- Load shared setup and figure style -------------------------------------------------------------------------------
.args <- commandArgs(trailingOnly = FALSE)
.file <- sub("^--file=", "", grep("^--file=", .args, value = TRUE))
.dir  <- if (length(.file)) dirname(gsub("~+~", " ", .file, fixed = TRUE)) else "."
source(file.path(.dir, "00_setup.R"))
source(file.path(.dir, "figure_style.R"))

#' Read one of the pipeline's output files. / 读取流程输出文件。
#'
#' Fails loudly with the name of the script that produces the file, because a missing input here means the analysis was
#' not run rather than that anything is wrong with the figure.
#'
#' @param file_name File name inside outputs/.
#' @param produced_by Name of the script that writes it, used in the error message.
#' @return A data frame.
read_output <- function(file_name, produced_by) {
    path <- file.path(OUT_DIR, file_name)
    if (!file.exists(path)) {
        stop(glue("{file_name} is missing - run {produced_by} first."), call. = FALSE)
    }
    read.csv(path, check.names = FALSE)
}

cat(NL, "== Main-text figures / 正文插图 ==", NL, sep = "")


# --- Figure 2: community composition ----------------------------------------------------------------------------------
# Panel A counts taxa shared between and unique to the seasons; panel B stacks each season's read shares. Together they
# separate the two things a composition figure has to say: which taxa were present, and how the reads were distributed
# among them.
occurrence <- read_output("Fig2_seasonal_occurrence.csv",   "01_composition.R")
shares     <- read_output("Fig2_composition_shares.csv",    "01_composition.R")

#' Points tracing a circle, for the Venn diagram. / 生成圆周坐标，用于绘制 Venn 图。
#'
#' Drawn as a path rather than with a Venn package, so the figure carries no dependency for two circles.
#'
#' @param centre_x Centre x coordinate.
#' @param radius Circle radius.
#' @param points Number of vertices (default 200, which is smooth at print size).
#' @return A data frame of x and y coordinates.
circle_path <- function(centre_x, radius, points = 200) {
    angle <- seq(0, 2 * pi, length.out = points)
    data.frame(x = centre_x + radius * cos(angle), y = radius * sin(angle))
}

shared_count <- sum(occurrence$spring == 1 & occurrence$autumn == 1)
spring_only  <- sum(occurrence$spring == 1 & occurrence$autumn == 0)
autumn_only  <- sum(occurrence$spring == 0 & occurrence$autumn == 1)

venn_offset <- 0.55
venn_radius <- 1
figure_2a <- ggplot() +
    geom_polygon(data = circle_path(-venn_offset, venn_radius), aes(x, y),
                 fill = PAL_SEASON[[SPRING]], alpha = 0.35, colour = PAL_SEASON[[SPRING]], linewidth = 0.3) +
    geom_polygon(data = circle_path(venn_offset, venn_radius), aes(x, y),
                 fill = PAL_SEASON[[AUTUMN]], alpha = 0.35, colour = PAL_SEASON[[AUTUMN]], linewidth = 0.3) +
    # Counts sit in the three regions; the season names sit above their own circle.
    annotate("text", x = -1.05, y = 0, label = spring_only,  size = text_size(BASE_PT), colour = INK_PRIMARY) +
    annotate("text", x =     0, y = 0, label = shared_count, size = text_size(BASE_PT), colour = INK_PRIMARY) +
    annotate("text", x =  1.05, y = 0, label = autumn_only,  size = text_size(BASE_PT), colour = INK_PRIMARY) +
    annotate("text", x = -venn_offset, y = venn_radius + 0.22, label = SPRING,
             size = text_size(BASE_PT), colour = INK_PRIMARY) +
    annotate("text", x =  venn_offset, y = venn_radius + 0.22, label = AUTUMN,
             size = text_size(BASE_PT), colour = INK_PRIMARY) +
    coord_equal(xlim = c(-1.9, 1.9), ylim = c(-1.25, 1.45)) +
    theme_void(base_size = BASE_PT)

# Species names are italicised, the pooled remainder is not, so the legend distinguishes taxa from the summary band.
share_levels <- levels(factor(shares$taxon, levels = unique(shares$taxon)))
species_fill <- c(
    setNames(hcl.colors(length(share_levels) - 1, "Spectral"), setdiff(share_levels, "Others")),
    Others = "#CCCCCC"
)
legend_labels <- vapply(share_levels, \(taxon_name) {
    if (taxon_name == "Others") "Others" else paste0("italic('", gsub("_", " ", taxon_name), "')")
}, character(1))

figure_2b <- shares |>
    mutate(
        season = factor(season, levels = SEASONS),
        taxon  = factor(taxon, levels = share_levels)
    ) |>
    ggplot(aes(season, rel_pct, fill = taxon)) +
    # A thin light border between segments separates adjacent bands without adding a heavy grid of outlines.
    geom_col(width = 0.6, colour = "white", linewidth = 0.15) +
    scale_fill_manual(values = species_fill, labels = parse(text = legend_labels), name = NULL) +
    scale_y_continuous(expand = expansion(mult = c(0, 0.02))) +
    labs(x = NULL, y = "Relative sequence abundance (%)") +
    theme_journal(grid = "y") +
    theme(legend.position = "right", legend.key.size = unit(2.4, "mm"))

figure_2 <- (figure_2a | figure_2b) +
    plot_layout(widths = c(1, 2.1)) +
    plot_annotation(tag_levels = "A")
save_figure(figure_2, "Figure2", WIDTH_FULL_MM, 78)


# --- Figure 3: taxonomic and functional alpha diversity ---------------------------------------------------------------
# Boxplots of the site-level indices, one panel per index, with the paired test in each panel title. The points are the
# 13 sites per season, which is the scale the paired Wilcoxon was run at, so the figure shows exactly the observations
# the reported p-value is based on.
alpha        <- read_output("alpha_diversity_site_level.csv",              "02_alpha_diversity.R")
paired_tests <- read_output("TableS1_alpha_paired_tests_site_level.csv",   "02_alpha_diversity.R")

TAXONOMIC_INDICES <- c("Richness", "Shannon", "Pielou", "Hill_q2")
FUNCTIONAL_INDICES <- c("FRic", "FEve", "FDis", "FDiv")

#' Panel title carrying the paired test result. / 面板标题，附配对检验结果。
#'
#' Both the raw and the corrected p-value are shown, because significance in this manuscript is decided after BH
#' correction across the twelve indices and the raw value alone would overstate it.
#'
#' @param index_name Index column name.
#' @return A single-element character label, with a line break before the statistics.
panel_title <- function(index_name) {
    row <- paired_tests[paired_tests$index == index_name, ]
    # Underscores are a column-name convention, not something a reader should see on a panel.
    sprintf("%s\nP = %s, FDR = %s", gsub("_", " ", index_name),
            format(signif(row$p, 2), scientific = FALSE),
            format(signif(row$FDR, 2), scientific = FALSE))
}

#' One row of alpha-diversity boxplots. / 一行 alpha 多样性箱线图。
#'
#' @param index_names Index column names to draw, left to right.
#' @param axis_label y-axis label for the row.
#' @return A ggplot object with one facet per index.
alpha_row <- function(index_names, axis_label) {
    long <- alpha |>
        select(site, season, all_of(index_names)) |>
        pivot_longer(all_of(index_names), names_to = "index", values_to = "value") |>
        mutate(
            season = factor(season, levels = SEASONS),
            index  = factor(index, levels = index_names,
                            labels = vapply(index_names, panel_title, character(1)))
        )

    ggplot(long, aes(season, value, fill = season)) +
        geom_boxplot(outlier.shape = NA, width = 0.55, linewidth = 0.25, colour = INK_SECONDARY) +
        # Jitter shows every site; a white stroke keeps overlapping points readable.
        geom_jitter(width = 0.13, height = 0, size = JITTER_SIZE, shape = 21,
                    colour = "white", stroke = POINT_STROKE, aes(fill = season)) +
        scale_fill_manual(values = PAL_SEASON, guide = "none") +
        facet_wrap(~ index, nrow = 1, scales = "free_y") +
        labs(x = NULL, y = axis_label) +
        theme_journal(grid = "y")
}

figure_3 <- (alpha_row(TAXONOMIC_INDICES, "Taxonomic") / alpha_row(FUNCTIONAL_INDICES, "Functional")) +
    plot_annotation(tag_levels = "A")
save_figure(figure_3, "Figure3", WIDTH_FULL_MM, 105)


# --- Figure 4: taxonomic and functional beta diversity ----------------------------------------------------------------
# Left column: ordinations, one per facet, with the seasonal test annotated. Right column: the paired partition of that
# facet's beta diversity into turnover and nestedness. Reading across a row answers "do the seasons differ?" and then
# "by replacement or by loss?".
pcoa_scores <- read_output("Fig4_pcoa_scores.csv",             "03_beta_diversity.R")
pcoa_stats  <- read_output("Fig4_pcoa_stats.csv",              "03_beta_diversity.R")
partition_taxonomic  <- read_output("beta_partition_taxonomic.csv",  "03_beta_diversity.R")
partition_functional <- read_output("beta_partition_functional.csv", "03_beta_diversity.R")

#' One PCoA panel. / 单个 PCoA 面板。
#'
#' @param facet_name "Taxonomic" or "Functional".
#' @return A ggplot object.
pcoa_panel <- function(facet_name) {
    points <- pcoa_scores[pcoa_scores$facet == facet_name, ] |>
        mutate(season = factor(season, levels = SEASONS))
    stats  <- pcoa_stats[pcoa_stats$facet == facet_name, ]

    # Annotation is placed in relative coordinates so it never lands on a point regardless of the axis ranges.
    annotation <- sprintf("PERMANOVA: R² = %.3f, P %s\nBetadisper: P = %.3f",
                          stats$permanova_R2,
                          if (stats$permanova_p < 0.001) "< 0.001" else paste("=", format_p(stats$permanova_p)),
                          stats$betadisper_p)

    ggplot(points, aes(axis1, axis2, fill = season)) +
        stat_ellipse(aes(colour = season), linewidth = 0.25, show.legend = FALSE) +
        geom_point(size = POINT_SIZE, shape = 21, colour = "white", stroke = POINT_STROKE) +
        annotate("text", x = -Inf, y = Inf, label = annotation, hjust = -0.05, vjust = 1.25,
                 size = text_size(BASE_PT), colour = INK_SECONDARY, lineheight = 1.05) +
        scale_fill_manual(values = PAL_SEASON_LIGHT, name = NULL) +
        scale_colour_manual(values = PAL_SEASON_LIGHT, name = NULL) +
        labs(x = sprintf("PCoA1 (%.1f%%)", stats$axis1_percent),
             y = sprintf("PCoA2 (%.1f%%)", stats$axis2_percent)) +
        # Headroom at the top so the annotation block never collides with the ellipses.
        scale_y_continuous(expand = expansion(mult = c(0.05, 0.28))) +
        theme_journal()
}

#' One beta-partition panel: component means with the individual sites behind them. / 单个 beta 分解面板。
#'
#' @param partition Data frame with site, total, turnover and nestedness columns.
#' @param axis_label y-axis label.
#' @return A ggplot object.
partition_panel <- function(partition, axis_label) {
    components <- c("Total", "Turnover", "Nestedness")
    long <- partition |>
        pivot_longer(c(total, turnover, nestedness), names_to = "component", values_to = "value") |>
        mutate(component = factor(tools::toTitleCase(component), levels = components))

    summary_stats <- long |>
        group_by(component) |>
        summarise(mean = mean(value), se = sd(value) / sqrt(n()), .groups = "drop")

    ggplot(summary_stats, aes(component, mean, fill = component)) +
        geom_col(width = 0.6, colour = INK_SECONDARY, linewidth = 0.2) +
        geom_errorbar(aes(ymin = mean - se, ymax = mean + se), width = 0.16, linewidth = 0.25,
                      colour = INK_PRIMARY) +
        # Every site shown, so the reader sees the spread the mean is drawn from rather than only an error bar.
        geom_jitter(data = long, aes(component, value), width = 0.12, height = 0,
                    size = JITTER_SIZE, shape = 21, fill = "white", colour = INK_SECONDARY, stroke = POINT_STROKE,
                    inherit.aes = FALSE) +
        scale_fill_manual(values = PAL_COMPONENT, guide = "none") +
        scale_y_continuous(expand = expansion(mult = c(0, 0.08))) +
        labs(x = NULL, y = axis_label) +
        theme_journal(grid = "y")
}

# The season legend is identical in both ordination panels, so it is collected once at the foot of the figure.
figure_4 <- ((pcoa_panel("Taxonomic")  | partition_panel(partition_taxonomic,  "Taxonomic beta diversity")) /
             (pcoa_panel("Functional") | partition_panel(partition_functional, "Functional beta diversity"))) +
    plot_layout(guides = "collect") +
    plot_annotation(tag_levels = "A") &
    theme(legend.position = "bottom", legend.margin = margin(-1, 0, 0, 0))
save_figure(figure_4, "Figure4", WIDTH_FULL_MM, 140)


# --- Figure 5: taxonomic-functional coupling --------------------------------------------------------------------------
# Panel A is the alpha-scale correlation matrix; panel B the beta-scale Mantel relationship. The two panels answer the
# same question at the two scales at which it can be asked.
alpha_coupling <- read_output("TableS5_taxfun_alpha_spearman.csv", "05_taxonomy_function.R")
beta_pairs     <- read_output("Fig5_beta_pairs.csv",               "05_taxonomy_function.R")
mantel_stats   <- read_output("TableS6_taxfun_beta_mantel.csv",    "05_taxonomy_function.R")

coupling_cells <- alpha_coupling |>
    mutate(
        tax   = factor(tax, levels = rev(c("Richness", "Shannon", "Simpson", "Pielou"))),
        fun   = factor(fun, levels = c("FRic", "FEve", "FDis", "FDiv")),
        label = sprintf("%.2f%s", rho, if_else(FDR < FDR_ALPHA, "*", ""))
    )

figure_5a <- ggplot(coupling_cells, aes(fun, tax, fill = rho)) +
    geom_tile(colour = "white", linewidth = 0.4) +
    # Significant cells are boxed and bolded as well as starred, so they are visible at a glance rather than needing
    # the reader to hunt for a small asterisk.
    significance_layers(coupling_cells, coupling_cells$FDR < FDR_ALPHA, BASE_PT) +
    scale_fill_gradient2(low = DIVERGING_LOW, mid = DIVERGING_MID, high = DIVERGING_HIGH,
                         midpoint = 0, limits = c(-1, 1), name = expression(Spearman~rho),
                         # Title above the bar, or it collides with the -1.0 end label.
                         guide = guide_colourbar(title.position = "top", title.hjust = 0.5)) +
    labs(x = "Functional alpha", y = "Taxonomic alpha",
         caption = "Boxed, bold and starred cells are significant after BH correction") +
    coord_equal() +
    theme_journal(grid = "none") +
    # A horizontal colour bar under the matrix, rather than a vertical one beside it, which would otherwise sit in the
    # gap between the two panels and read as belonging to neither.
    theme(
        legend.position   = "bottom",
        legend.key.height = unit(2.2, "mm"),
        legend.key.width  = unit(12, "mm"),
        legend.margin     = margin(-2, 0, 0, 0),
        plot.caption      = element_text(size = SMALL_PT, colour = INK_SECONDARY, hjust = 0)
    )

pooled_mantel <- mantel_stats[mantel_stats$scope == "pooled", ]
figure_5b <- ggplot(beta_pairs, aes(taxonomic, functional)) +
    geom_point(size = POINT_SIZE_DENSE, colour = INK_SECONDARY, alpha = MARKER_ALPHA * 0.7) +
    geom_smooth(method = "lm", formula = y ~ x, linewidth = 0.4,
                colour = PAL_SEASON[[SPRING]], fill = PAL_SEASON[[SPRING]], alpha = 0.18) +
    annotate("text", x = -Inf, y = Inf,
             label = sprintf("Mantel r = %.3f, P = %s", pooled_mantel$mantel_r, format_p(pooled_mantel$p)),
             hjust = -0.05, vjust = 1.6, size = text_size(BASE_PT), colour = INK_PRIMARY) +
    labs(x = "Taxonomic dissimilarity (Bray-Curtis)", y = "Functional dissimilarity (Gower on CWM)") +
    scale_y_continuous(expand = expansion(mult = c(0.05, 0.2))) +
    theme_journal()

figure_5 <- (figure_5a | figure_5b) +
    plot_layout(widths = c(1, 1.15)) +
    plot_annotation(tag_levels = "A")
save_figure(figure_5, "Figure5", WIDTH_FULL_MM, 82)


# --- Figure 6: hydro-geographic PCA -----------------------------------------------------------------------------------
# A biplot of the 13 sites and the ten hydro-geographic variables. PC1 is the longitudinal gradient, so the horizontal
# axis orders the sites from small headwater to large downstream channel, which is stated on the panel so the reader
# does not have to infer the direction from the loadings.
pca_scores   <- read_output("Fig6_pca_scores.csv",   "06_environment_gradient.R")
pca_loadings <- read_output("Fig6_pca_loadings.csv", "06_environment_gradient.R")
pca_variance <- read_output("Fig6_pca_variance.csv", "06_environment_gradient.R")

# Loadings are unit vectors, so they are scaled to the spread of the site scores to make both readable on one pair of
# axes. This is the usual biplot scaling and changes no relationship, only the arrow length. The factor is deliberately
# well under 1: arrows that reach the panel edge leave their labels nowhere to go, and the labels matter more than the
# last millimetre of arrow.
arrow_scale <- 0.55 * max(abs(range(c(pca_scores$PC1, pca_scores$PC2)))) /
                      max(abs(range(c(pca_loadings$PC1, pca_loadings$PC2))))

# Both kinds of label in one frame, each carrying its own colour, so they can be placed in a single repulsion pass.
# Variable labels are anchored beyond their arrow head, along the arrow's own direction; anchoring them at the head
# would drop the crowded Elevation / Precip / Strahler cluster straight onto the origin.
pca_label_set <- bind_rows(
    pca_scores |>
        transmute(label_x = PC1, label_y = PC2, label = site,
                  label_colour = unname(PAL_SECTION[section])),
    pca_loadings |>
        transmute(label_x = PC1 * arrow_scale * LABEL_RADIUS,
                  label_y = PC2 * arrow_scale * LABEL_RADIUS,
                  label = display_label(variable), label_colour = INK_SECONDARY)
)

figure_6 <- ggplot(pca_scores, aes(PC1, PC2)) +
    geom_hline(yintercept = 0, colour = INK_GRID, linewidth = 0.25) +
    geom_vline(xintercept = 0, colour = INK_GRID, linewidth = 0.25) +
    geom_segment(data = pca_loadings,
                 aes(x = 0, y = 0, xend = PC1 * arrow_scale, yend = PC2 * arrow_scale),
                 arrow = arrow(length = unit(1.2, "mm")), linewidth = 0.25, colour = INK_SECONDARY,
                 inherit.aes = FALSE) +
    geom_point(aes(fill = section), size = POINT_SIZE, shape = 21, colour = "white", stroke = POINT_STROKE) +
    # Site codes and variable names are placed by a single repulsion pass over the combined set, so the two kinds of
    # label avoid each other as well as themselves. Two separate repel layers cannot do this: each is blind to the
    # other, and a variable label lands on top of a site code, hiding which site it was.
    ggrepel::geom_text_repel(
        data = pca_label_set, aes(label_x, label_y, label = label, colour = label_colour),
        size = text_size(BASE_PT), inherit.aes = FALSE,
        segment.size = 0.15, segment.colour = INK_SECONDARY, min.segment.length = 0.2,
        box.padding = 0.3, force = 5, force_pull = 0.5,
        max.overlaps = Inf, max.iter = 20000, show.legend = FALSE, seed = RANDOM_SEED
    ) +
    scale_colour_identity() +
    annotate("text", x = Inf, y = -Inf, label = "larger / downstream →", hjust = 1.05, vjust = -0.6,
             size = text_size(BASE_PT), colour = INK_SECONDARY) +
    scale_fill_manual(values = PAL_SECTION, name = NULL, limits = names(PAL_SECTION)) +
    labs(x = sprintf("PC1 (%.1f%%)", pca_variance$percent[1]),
         y = sprintf("PC2 (%.1f%%)", pca_variance$percent[2])) +
    # Room around the point cloud for the repelled labels, so none is pushed against the panel border or clipped.
    scale_x_continuous(expand = expansion(mult = 0.14)) +
    scale_y_continuous(expand = expansion(mult = 0.12)) +
    theme_journal() +
    theme(legend.position = "bottom", legend.margin = margin(-2, 0, 0, 0))
save_figure(figure_6, "Figure6", WIDTH_ONEHALF_MM, 120)


# --- Figure 7: dbRDA of composition on the hydro-geographic factors ---------------------------------------------------
# One constrained ordination per season, on the same six predictors, so the two panels are directly comparable. The
# model statistics are annotated because a constrained ordination always separates the groups visually, whether or not
# the constraint is significant.
dbrda_scores <- read_output("Fig7_dbrda_scores.csv", "06_environment_gradient.R")
dbrda_arrows <- read_output("Fig7_dbrda_arrows.csv", "06_environment_gradient.R")
dbrda_stats  <- read_output("Fig7_dbrda_stats.csv",  "06_environment_gradient.R")

#' One dbRDA panel for a season. / 单季节的 dbRDA 面板。
#'
#' @param season_name Season label.
#' @return A ggplot object.
dbrda_panel <- function(season_name) {
    points <- dbrda_scores[dbrda_scores$season == season_name, ]
    arrows_data <- dbrda_arrows[dbrda_arrows$season == season_name, ]
    stats  <- dbrda_stats[dbrda_stats$season == season_name, ]

    # Five of the six predictors are collinear measures of river size, so their arrows nearly coincide and their labels
    # compete for the same space. Short arrows plus a generous panel expansion is what makes all six readable.
    scale_factor <- 0.5 * max(abs(range(c(points$CAP1, points$CAP2)))) /
                          max(abs(range(c(arrows_data$CAP1, arrows_data$CAP2))))

    # Labels are anchored further out along each arrow's own direction, not at its tip. Anchoring at the tip puts every
    # label back into the crowded centre where the arrows converge and the sites sit; pushing them out along the same
    # ray separates them and moves them clear of the markers before repulsion is applied at all.
    label_anchors <- arrows_data |>
        mutate(
            label_x = CAP1 * scale_factor * LABEL_RADIUS,
            label_y = CAP2 * scale_factor * LABEL_RADIUS,
            label   = display_label(variable)
        )

    # An ellipse needs at least three points, and the upstream section holds only two sites. Those groups are filtered
    # out rather than left to fail, so the panel draws without a warning and without an empty layer.
    ellipse_points <- points |>
        group_by(section) |>
        filter(n() >= 3) |>
        ungroup()

    ggplot(points, aes(CAP1, CAP2)) +
        geom_hline(yintercept = 0, colour = INK_GRID, linewidth = 0.25) +
        geom_vline(xintercept = 0, colour = INK_GRID, linewidth = 0.25) +
        stat_ellipse(data = ellipse_points, aes(colour = section), linewidth = 0.25, show.legend = FALSE) +
        geom_segment(data = arrows_data,
                     aes(x = 0, y = 0, xend = CAP1 * scale_factor, yend = CAP2 * scale_factor),
                     arrow = arrow(length = unit(1.1, "mm")), linewidth = 0.22, colour = INK_SECONDARY,
                     inherit.aes = FALSE) +
        geom_point(aes(fill = section), size = POINT_SIZE, shape = 21, colour = "white", stroke = POINT_STROKE) +
        # Drawn last, so the label plates sit above both the arrows and the markers.
        arrow_labels(label_anchors) +
        annotate("text", x = -Inf, y = Inf,
                 label = sprintf("adj. R² = %.3f, P = %s", stats$adj_R2, format_p(stats$p)),
                 hjust = -0.05, vjust = 1.6, size = text_size(BASE_PT), colour = INK_PRIMARY) +
        scale_fill_manual(values = PAL_SECTION, name = NULL, limits = names(PAL_SECTION)) +
        scale_colour_manual(values = PAL_SECTION, limits = names(PAL_SECTION)) +
        # Wide margins on both axes: the labels are repelled outward, and they must land inside the panel.
        scale_x_continuous(expand = expansion(mult = 0.16)) +
        scale_y_continuous(expand = expansion(mult = c(0.10, 0.22))) +
        labs(title = season_name,
             x = sprintf("CAP1 (%.1f%%)", stats$cap1_percent),
             y = sprintf("CAP2 (%.1f%%)", stats$cap2_percent)) +
        theme_journal()
}

figure_7 <- (dbrda_panel(SPRING) | dbrda_panel(AUTUMN)) +
    plot_layout(guides = "collect") &
    theme(legend.position = "bottom", legend.margin = margin(-2, 0, 0, 0))
save_figure(figure_7, "Figure7", WIDTH_FULL_MM, 92)


# --- Figure 8: community dissimilarity against environmental distance -------------------------------------------------
# The Mantel relationship, one panel per season. Each point is a pair of sites, so the panels show whether sites that
# are environmentally further apart also hold more different communities.
env_pairs        <- read_output("Fig8_env_pairs.csv",     "06_environment_gradient.R")
env_mantel_stats <- read_output("Fig8_mantel_stats.csv",  "06_environment_gradient.R")

#' One Mantel scatter panel for a season. / 单季节的 Mantel 散点面板。
#'
#' @param season_name Season label.
#' @return A ggplot object.
mantel_panel <- function(season_name) {
    pairs <- env_pairs[env_pairs$season == season_name, ]
    stats <- env_mantel_stats[env_mantel_stats$season == season_name, ]

    ggplot(pairs, aes(env_distance, bray)) +
        geom_point(size = POINT_SIZE_DENSE, colour = PAL_SEASON[[season_name]], alpha = MARKER_ALPHA) +
        geom_smooth(method = "lm", formula = y ~ x, linewidth = 0.4,
                    colour = INK_PRIMARY, fill = INK_SECONDARY, alpha = 0.15) +
        annotate("text", x = -Inf, y = Inf,
                 label = sprintf("Mantel r = %.3f, P = %s", stats$mantel_r, format_p(stats$p)),
                 hjust = -0.08, vjust = 1.8, size = text_size(BASE_PT), colour = INK_PRIMARY) +
        labs(title = season_name, x = "Multivariate environmental distance",
             y = "Bray-Curtis dissimilarity") +
        scale_y_continuous(expand = expansion(mult = c(0.05, 0.20))) +
        theme_journal()
}

# A shared y range makes the two seasons comparable by eye, which is the whole point of putting them side by side.
shared_y <- range(env_pairs$bray)
figure_8 <- (mantel_panel(SPRING) | mantel_panel(AUTUMN)) &
    coord_cartesian(ylim = shared_y)
save_figure(figure_8, "Figure8", WIDTH_ONEHALF_MM, 72)

cat(NL, "Main-text figures written to figures/", NL, sep = "")
