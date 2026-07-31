# ======================================================================================================================
# 09_figures_supp.R
#
# Supplementary figures S1-S2
# ---------------------------
# Figure S1: which taxa drive the seasonal difference (SIMPER) and how much of the seasonal signal depends on them
# (leave-one-out PERMANOVA). Figure S2: the local water-quality and land-cover correlations, which are reported as
# supplementary because almost none of them survive correction.
#
# As with the main-text figures, everything is read from outputs/ so the artwork cannot disagree with the tables. Run
# scripts 01-07 first.
#
# 补充插图 S1-S2
# --------------
# 图 S1：驱动季节差异的类群（SIMPER）及季节信号对其的依赖程度（留一法 PERMANOVA）。图 S2：局域水质与土地覆被相关性，
# 因校正后几乎均不显著，故列为补充材料。
#
# 与正文插图一致，全部数据取自 outputs/，故图形与表格不会脱节。请先运行脚本 01-07。
# ======================================================================================================================


# --- Load shared setup and figure style -------------------------------------------------------------------------------
.args <- commandArgs(trailingOnly = FALSE)
.file <- sub("^--file=", "", grep("^--file=", .args, value = TRUE))
.dir  <- if (length(.file)) dirname(gsub("~+~", " ", .file, fixed = TRUE)) else "."
source(file.path(.dir, "00_setup.R"))
source(file.path(.dir, "figure_style.R"))

#' Read one of the pipeline's output files. / 读取流程输出文件。
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

#' Format a taxon name for display, in italics. / 将类群名格式化为斜体显示。
#'
#' @param taxa Character vector of underscore-separated taxon names.
#' @return Character vector of plotmath expressions.
italic_taxon <- function(taxa) paste0("italic('", gsub("_", " ", taxa), "')")

cat(NL, "== Supplementary figures / 补充插图 ==", NL, sep = "")


# --- Figure S1: seasonal drivers --------------------------------------------------------------------------------------
# Panel A ranks the taxa by their contribution to the mean between-season dissimilarity, coloured by the season each is
# more abundant in, because a contribution says how much a taxon separates the seasons but not in which direction.
# Panel B removes those taxa and re-runs the seasonal test, which turns "these taxa differ" into "the seasonal signal
# depends on them by this much".
simper   <- read_output("TableS2_simper_top15.csv",         "04_simper_leaveout.R")
leaveout <- read_output("TableS3_leaveout_permanova.csv",   "04_simper_leaveout.R")

# Where the cumulative share first reaches half of the total dissimilarity, stated on the panel so the reader does not
# have to add the bars up.
half_at <- which(simper$cumulative_pct >= 50)[1]

figure_s1a <- simper |>
    mutate(
        taxon     = factor(taxon, levels = rev(taxon)),
        higher_in = factor(higher_in, levels = SEASONS)
    ) |>
    ggplot(aes(contribution_pct, taxon, fill = higher_in)) +
    geom_col(width = 0.7, colour = INK_SECONDARY, linewidth = 0.15) +
    scale_fill_manual(values = PAL_SEASON, name = "Higher in") +
    scale_y_discrete(labels = \(taxa) parse(text = italic_taxon(taxa))) +
    scale_x_continuous(expand = expansion(mult = c(0, 0.05))) +
    labs(x = "Contribution to Spring-Autumn Bray-Curtis dissimilarity (%)", y = NULL,
         title = sprintf("Top %d SIMPER contributors (%d taxa reach 50%%)", nrow(simper), half_at)) +
    theme_journal(grid = "x") +
    theme(legend.position = "right")

figure_s1b <- leaveout |>
    mutate(
        scenario = factor(scenario, levels = scenario),
        # The full-community bar is the reference, so its reduction is not labelled as a drop.
        label    = if_else(reduction_pct < 1,
                           sprintf("R² = %.3f", R2),
                           sprintf("R² = %.3f\n(-%.1f%%)", R2, reduction_pct))
    ) |>
    ggplot(aes(scenario, R2)) +
    geom_col(width = 0.6, fill = PAL_SEASON[[SPRING]], colour = INK_SECONDARY, linewidth = 0.15) +
    geom_text(aes(label = label), vjust = -0.35, size = text_size(BASE_PT), colour = INK_PRIMARY,
              lineheight = 1.05) +
    scale_y_continuous(expand = expansion(mult = c(0, 0.22))) +
    # The scenario names are sentences, and set on one line they run into each other. Wrapping to a fixed character
    # width keeps each label under its own bar.
    scale_x_discrete(labels = scales::label_wrap(18)) +
    labs(x = NULL, y = "Seasonal PERMANOVA R²",
         title = "Dependence of the seasonal signal on these taxa") +
    theme_journal(grid = "y")

# The legend is collected to the foot of the figure. Left inside panel A it would take width from that panel only, and
# patchwork would then inset panel B to match, leaving an empty column beside it.
figure_s1 <- (figure_s1a / figure_s1b) +
    plot_layout(heights = c(1.35, 1), guides = "collect") +
    plot_annotation(tag_levels = "A") &
    theme(legend.position = "bottom", legend.margin = margin(-1, 0, 0, 0))
save_figure(figure_s1, "FigureS1", WIDTH_FULL_MM, 155)


# --- Figure S2: local water quality and land cover against diversity --------------------------------------------------
# One heat map per season, over both variable families. Cells are labelled with the correlation and starred only where
# it survives BH correction within its family, which is what makes the near-absence of real signal visible: the panels
# are full of moderate correlations and almost no stars.
local_corr <- read_output("TableS8_local_alpha_spearman.csv", "07_water_quality_supp.R")
local_dbrda <- read_output("TableS9_local_dbrda.csv",         "07_water_quality_supp.R")

# Rows are ordered water quality first, then land cover, each in the order the data tables declare them, so the two
# families read as blocks rather than being interleaved alphabetically.
variable_order <- intersect(names(LOCAL_LABELS), unique(local_corr$variable))
index_order    <- unique(local_corr$alpha)

#' One correlation heat map for a season. / 单季节的相关性热图。
#'
#' @param season_name Season label.
#' @param show_legend Whether to draw the colour bar (only the right-hand panel needs it).
#' @return A ggplot object.
correlation_panel <- function(season_name, show_legend) {
    panel_data <- local_corr[local_corr$season == season_name, ] |>
        mutate(
            variable = factor(variable, levels = rev(variable_order)),
            alpha    = factor(alpha, levels = index_order),
            label    = sprintf("%.2f%s", rho, if_else(FDR < FDR_ALPHA, "*", ""))
        )

    ggplot(panel_data, aes(alpha, variable, fill = rho)) +
        geom_tile(colour = "white", linewidth = 0.3) +
        # With 120 cells per panel a trailing asterisk is far too easy to miss, and in this figure the whole point is
        # that almost nothing is significant - so the one cell that is has to be unmistakable.
        significance_layers(panel_data, panel_data$FDR < FDR_ALPHA, BASE_PT) +
        scale_fill_gradient2(low = DIVERGING_LOW, mid = DIVERGING_MID, high = DIVERGING_HIGH,
                             midpoint = 0, limits = c(-1, 1), name = "Spearman ρ",
                             guide = if (show_legend) "colourbar" else "none") +
        scale_y_discrete(labels = \(v) display_label(v, LOCAL_LABELS)) +
        labs(x = "Diversity index", y = if (show_legend) NULL else "Environmental variable",
             title = season_name) +
        theme_journal(grid = "none") +
        theme(
            axis.text.x = element_text(angle = 45, hjust = 1),
            legend.key.width = unit(2.5, "mm"),
            legend.key.height = unit(10, "mm")
        )
}

# The dbRDA results belong with this figure, so they are stated in the caption strip rather than left only in Table S9.
# The note is wrapped, because set as one line it overflows the 190 mm width and the device silently clips the end.
dbrda_note <- local_dbrda |>
    mutate(text = sprintf("%s %s adj. R² = %.3f, P = %s", season, tolower(family), adj_R2, format_p(p))) |>
    pull(text) |>
    paste(collapse = "; ")

figure_s2_caption <- wrap_caption(paste0(
    "Boxed, bold and starred cells are significant after BH correction within their variable family. ",
    "Distance-based redundancy analysis on the same variables: ", dbrda_note, "."
))

figure_s2 <- (correlation_panel(SPRING, FALSE) | correlation_panel(AUTUMN, TRUE)) +
    plot_annotation(
        tag_levels = "A",
        caption = figure_s2_caption,
        theme = theme(
            plot.caption = element_text(size = SMALL_PT, colour = INK_SECONDARY, hjust = 0, lineheight = 1.15),
            plot.margin  = margin(1, 2, 1, 1, "mm")
        )
    )
save_figure(figure_s2, "FigureS2", WIDTH_FULL_MM, 135)

cat(NL, "Supplementary figures written to figures/", NL, sep = "")
