# ======================================================================================================================
# figure_style.R
#
# Journal artwork specification and shared plot style
# ---------------------------------------------------
# One place for everything that decides how a figure looks on the page: the permitted column widths, the minimum
# lettering size, the output resolution, the palettes, and the save-and-verify step. Sourced by 08_figures_main.R and
# 09_figures_supp.R. Every figure in the manuscript is drawn through this file, so changing a rule here changes it
# everywhere.
#
# The targets are Elsevier's, because they are the stricter of the two submissions: 90 / 140 / 190 mm column widths,
# 7 pt minimum lettering, and 500 dpi for combination artwork (line work plus shaded areas, which is what all of these
# figures are). Meeting that also satisfies PeerJ, which asks for 300 dpi and roughly 2 mm label height.
#
# 期刊插图规范与统一绘图风格
# --------------------------
# 集中定义决定成图外观的全部规则：允许的栏宽、最小字号、输出分辨率、配色，以及保存与校验步骤。由
# 08_figures_main.R 与 09_figures_supp.R 调用。所有插图均经此文件绘制，故在此修改规则即全局生效。
#
# 以 Elsevier 的要求为准（两个投稿目标中较严者）：栏宽 90 / 140 / 190 mm，最小字号 7 pt，组合图 500 dpi。
# 满足该标准即同时满足 PeerJ（300 dpi、标签高度约 2 mm）。
# ======================================================================================================================


# --- Plotting packages ------------------------------------------------------------------------------------------------
# ggplot2 draws every panel; patchwork composes the multi-panel figures; scales supplies the axis formatters; ggrepel
# pushes point and arrow labels apart, which is what keeps the ordination panels legible at 7 pt.
figure_packages <- c("ggplot2", "patchwork", "scales", "ggrepel")
missing_figure_packages <- setdiff(figure_packages, rownames(installed.packages()))
if (length(missing_figure_packages)) {
    install.packages(missing_figure_packages, repos = "https://cloud.r-project.org")
}
suppressMessages(invisible(lapply(figure_packages, library, character.only = TRUE)))


# --- Page geometry and resolution -------------------------------------------------------------------------------------
# Elsevier's three permitted artwork widths. A figure must be drawn at one of these, never at an arbitrary size, or the
# typesetter rescales it and the lettering no longer matches the declared point size.
WIDTH_SINGLE_MM  <- 90      # single column
WIDTH_ONEHALF_MM <- 140     # 1.5 columns
WIDTH_FULL_MM    <- 190     # full page width

# 500 dpi is the combination-artwork requirement. At 190 mm that is 3740 px, which is what verify_figure() checks.
JOURNAL_DPI <- 500L

# 7 pt is Elsevier's minimum lettering size after any scaling. Because figures are drawn at final size, the base size
# is the size on the page and nothing shrinks later.
BASE_PT  <- 7
TITLE_PT <- 8               # panel titles, the only text allowed above the base size
SMALL_PT <- 6               # permitted only for sub/superscripts, per the same specification

# TIFF for the Elsevier submission, PDF for a vector copy that survives any later rescaling.
TIFF_COMPRESSION <- "lzw"


# --- Mark sizes -------------------------------------------------------------------------------------------------------
# Collected here because marker size is the easiest thing to get wrong: a size that looks right on screen at 1400 px
# disappears on a 90 mm column. These are ggplot2 point sizes, which are diameters in millimetres, so POINT_SIZE = 2
# is a 2 mm dot on the printed page and stays comfortably visible.
POINT_SIZE       <- 2.0     # ordination markers and sparse scatters, where every point is a site
POINT_SIZE_DENSE <- 1.3     # scatters of every site pair, where hundreds of points overlap
JITTER_SIZE      <- 1.4     # points overlaid on a boxplot or bar, showing the raw observations
POINT_STROKE     <- 0.3     # white outline that separates overlapping filled markers
MARKER_ALPHA     <- 0.75    # transparency for the dense scatters only

# How far along its own direction an ordination arrow's label is anchored, as a multiple of the arrow length. Above 1
# the label sits beyond the arrow head, away from the crowded origin where collinear arrows converge.
LABEL_RADIUS <- 1.28

#' Repelled arrow labels on their own translucent background. / 带半透明衬底的可避让箭头标签。
#'
#' In a constrained ordination the arrows all start at the origin, which sits inside the point cloud, so a label for a
#' short arrow has nowhere to go that is not over an arrow or a marker. Repulsion alone cannot solve it. Giving each
#' label a translucent white plate does: the label stays where it belongs and remains readable over whatever it covers,
#' which is the usual treatment for a crowded biplot.
#'
#' @param data Data frame holding label_x, label_y and label columns.
#' @return A ggplot2 layer.
arrow_labels <- function(data) {
    ggrepel::geom_label_repel(
        data = data, aes(label_x, label_y, label = label),
        size = text_size(BASE_PT), colour = INK_PRIMARY, inherit.aes = FALSE,
        # linewidth 0 rather than label.size: ggplot2 4.x moved the label border onto linewidth, and leaving it at the
        # default draws a box around every label, which is a lot of ink for a plate that is only there to mask.
        fill = scales::alpha("white", 0.72), linewidth = 0, label.size = NA,
        label.padding = unit(0.5, "mm"),
        segment.size = 0.15, segment.colour = INK_SECONDARY, min.segment.length = 0.2,
        box.padding = 0.25, force = 4, force_pull = 0.6,
        max.overlaps = Inf, max.iter = 20000, seed = RANDOM_SEED
    )
}


# --- Palettes ---------------------------------------------------------------------------------------------------------
# Taken verbatim from the original figure scripts so the redrawn figures keep the published colour scheme.
PAL_SEASON  <- c(Spring = "#3C8DAD", Autumn = "#E08E45")
PAL_SECTION <- c(Upstream = "#66A182", Downstream = "#8E7CC3", Tributary = "#E0995E")

# The beta-diversity ordination used a lighter pair than the boxplots, and the partition bars a third set.
PAL_SEASON_LIGHT <- c(Spring = "#8DD3C7", Autumn = "#BEBADA")
PAL_COMPONENT    <- c(Total = "#BDBDBD", Turnover = "#80B1D3", Nestedness = "#FDB462")

# Diverging scale for the correlation heat maps: one cool hue, a neutral midpoint, one warm hue. Never a rainbow, and
# never a hue at the midpoint, so that zero correlation reads as absence of colour.
DIVERGING_LOW  <- "#9BB7D4"
DIVERGING_MID  <- "#F7F7F7"
DIVERGING_HIGH <- "#E6B87D"

# Recessive ink for grid lines, axes and annotation, so the data marks stay dominant.
INK_PRIMARY   <- "#1A1A1A"
INK_SECONDARY <- "#4D4D4D"
INK_GRID      <- "#E6E6E6"


# --- Display labels ---------------------------------------------------------------------------------------------------
# Column names are machine-friendly; these are what a reader sees on an axis or an ordination arrow. Kept here rather
# than in the analysis scripts so that renaming something on a figure never touches a computation.
ENV_LABELS <- c(
    elev_m         = "Elevation",
    strahler       = "Strahler",
    log_drainage   = "log Drainage",
    log_discharge  = "log Discharge",
    log_width      = "log Width",
    grad_dem       = "Gradient",
    dist_source_km = "Dist-source",
    dist_mouth_km  = "Dist-mouth",
    MAT_C          = "Air temp",
    MAP_mm         = "Precip"
)

# Water-quality and land-cover variables, for the supplementary correlation heat maps.
LOCAL_LABELS <- c(
    temperature_C          = "WT",
    pH                     = "pH",
    conductivity_uS_cm     = "Cond",
    dissolved_oxygen_mg_L  = "DO",
    total_phosphorus_mg_L  = "TP",
    total_nitrogen_mg_L    = "TN",
    ammonia_nitrogen_mg_L  = "NH3-N",
    cropland               = "Cropland",
    forest                 = "Forest",
    shrub                  = "Shrub",
    grassland              = "Grassland",
    water                  = "Water",
    snow_ice               = "Snow/Ice",
    barren                 = "Barren",
    impervious             = "Impervious",
    wetland                = "Wetland"
)

#' Layers that mark the significant cells of a correlation heat map. / 标注热图中显著单元格的图层。
#'
#' A trailing asterisk on a number is easy to miss, especially at the small lettering a 16-row heat map forces. These
#' layers mark a significant cell three ways at once: a dark box around the cell, the value in bold, and the asterisk.
#' Any one of them is enough to spot, and none of them relies on the fill colour, which is already carrying the
#' correlation itself.
#'
#' @param data The full panel data frame.
#' @param significant Logical vector, one per row of `data`, TRUE where the cell is significant.
#' @param label_size Text size in points for the cell labels.
#' @return A list of ggplot2 layers, to be added after the base geom_tile.
significance_layers <- function(data, significant, label_size = BASE_PT) {
    marked <- data[significant, , drop = FALSE]
    list(
        # Outline drawn only on significant cells, on top of the fill so it is not overpainted.
        geom_tile(data = marked, fill = NA, colour = INK_PRIMARY, linewidth = 0.55),
        geom_text(data = marked, aes(label = label), size = text_size(label_size),
                  colour = INK_PRIMARY, fontface = "bold"),
        geom_text(data = data[!significant, , drop = FALSE], aes(label = label),
                  size = text_size(label_size), colour = INK_SECONDARY)
    )
}

#' Wrap a long caption to a fixed character width. / 将长题注按固定字符宽度换行。
#'
#' A caption set as one line overflows the figure and is silently clipped by the device, which is how a note ends up
#' half-missing on a submitted figure. Wrapping keeps it inside the width.
#'
#' @param text The caption text.
#' @param width Characters per line (default 150, which suits a 190 mm figure at 6 pt).
#' @return A single string with newlines inserted.
wrap_caption <- function(text, width = 150) paste(strwrap(text, width = width), collapse = "\n")

#' Format a p-value for display on a figure. / 将 p 值格式化用于图上显示。
#'
#' A permutation test cannot return a p-value below 1/(permutations + 1), so printing "1e-04" claims a precision the
#' test does not have and reads as a formatting slip. Anything at or below the floor is shown as an inequality, and
#' everything else to two significant figures.
#'
#' Vectorised, so it can be used inside mutate() as well as on a single value.
#'
#' @param p A p-value, or a vector of them.
#' @param floor_value Smallest value the test could return (default 0.001).
#' @return A character vector of strings such as "< 0.001" or "0.041".
format_p <- function(p, floor_value = 0.001) {
    vapply(p, \(value) {
        if (is.na(value)) {
            "NA"
        } else if (value < floor_value) {
            paste("<", format(floor_value, scientific = FALSE))
        } else {
            format(signif(value, 2), scientific = FALSE)
        }
    }, character(1), USE.NAMES = FALSE)
}

#' Look up display labels, falling back to the original name. / 查询显示标签，未定义时回退为原始名称。
#'
#' @param names Character vector of column names.
#' @param lookup Named character vector of labels (default ENV_LABELS).
#' @return Character vector of labels, the same length as `names`.
display_label <- function(names, lookup = ENV_LABELS) {
    labels <- unname(lookup[names])
    ifelse(is.na(labels), names, labels)
}


# --- Unit conversion --------------------------------------------------------------------------------------------------

#' Convert a point size to the millimetre size that ggplot2's text geoms expect. / 将磅值转换为文本图层所用的毫米值。
#'
#' ggplot2 sizes `geom_text` and `geom_label` in millimetres, while journals specify lettering in points. Passing a
#' point value straight to `size` silently produces text about 2.8 times too large, which is the usual reason a figure
#' fails an artwork check.
#'
#' @param points Size in points.
#' @return The equivalent size in millimetres, for use as `size =` in a text geom.
text_size <- function(points) points / .pt

#' Convert a point size to the millimetre size for a geom's line width. / 将磅值转换为线宽所用的毫米值。
#'
#' @param points Stroke width in points.
#' @return The equivalent `linewidth` value.
line_size <- function(points) points / .stroke * 2


# --- Shared theme -----------------------------------------------------------------------------------------------------

#' The house theme for every figure in the manuscript. / 全部插图统一使用的主题。
#'
#' Sets all lettering at or above the journal minimum, keeps the grid and axes recessive, and removes the panel
#' furniture that only adds ink. Legend position is left to the caller because it depends on the panel shape.
#'
#' @param base_points Base lettering size in points (default BASE_PT).
#' @param grid Which grid lines to keep: "both", "y", "x" or "none".
#' @return A ggplot2 theme object.
theme_journal <- function(base_points = BASE_PT, grid = "both") {
    keep_y <- grid %in% c("both", "y")
    keep_x <- grid %in% c("both", "x")

    theme_bw(base_size = base_points, base_family = "") +
        theme(
            # Text: nothing below base_points anywhere on the figure.
            text            = element_text(colour = INK_PRIMARY, size = base_points),
            axis.text       = element_text(colour = INK_SECONDARY, size = base_points),
            axis.title      = element_text(colour = INK_PRIMARY, size = base_points),
            plot.title      = element_text(colour = INK_PRIMARY, size = TITLE_PT, hjust = 0.5),
            plot.subtitle   = element_text(colour = INK_SECONDARY, size = base_points, hjust = 0.5),
            strip.text      = element_text(colour = INK_PRIMARY, size = base_points),
            legend.text     = element_text(colour = INK_PRIMARY, size = base_points),
            legend.title    = element_text(colour = INK_PRIMARY, size = base_points),

            # Recessive furniture: thin panel border, faint grid, no minor grid at all.
            panel.border     = element_rect(colour = INK_SECONDARY, fill = NA, linewidth = 0.3),
            panel.grid.major.y = if (keep_y) element_line(colour = INK_GRID, linewidth = 0.2) else element_blank(),
            panel.grid.major.x = if (keep_x) element_line(colour = INK_GRID, linewidth = 0.2) else element_blank(),
            panel.grid.minor = element_blank(),
            strip.background = element_blank(),

            # Ticks short and light; margins tight, because the width is fixed by the journal.
            axis.ticks      = element_line(colour = INK_SECONDARY, linewidth = 0.2),
            axis.ticks.length = unit(1, "mm"),
            legend.key      = element_blank(),
            legend.key.size = unit(3, "mm"),
            legend.margin   = margin(0, 0, 0, 0),
            plot.margin     = margin(1, 1, 1, 1, "mm"),

            # Panel tags (A, B, C ...) as patchwork applies them: bold, at the title size.
            plot.tag        = element_text(colour = INK_PRIMARY, size = TITLE_PT, face = "bold")
        )
}

# Applied once so that individual figure scripts do not have to repeat it.
theme_set(theme_journal())


# --- Saving and verification ------------------------------------------------------------------------------------------

#' Write a figure as TIFF, PNG and vector PDF, then verify it. / 输出图形为 TIFF、PNG 与矢量 PDF 并校验。
#'
#' Three files, because three things need them. The TIFF is the Elsevier submission artwork. The PNG is what the
#' manuscript builders embed into the .docx, so it has to be regenerated alongside the TIFF or the built manuscript
#' keeps showing an older figure. The PDF is the vector copy, for a journal that asks for editable artwork or wants to
#' rescale. All three are the same figure at the same physical size.
#'
#' The width must be one of the three permitted column widths, and this refuses anything else rather than quietly
#' producing a file the typesetter will rescale.
#'
#' @param plot A ggplot or patchwork object.
#' @param name Figure name without extension, e.g. "Figure4".
#' @param width_mm Width in millimetres; must be WIDTH_SINGLE_MM, WIDTH_ONEHALF_MM or WIDTH_FULL_MM.
#' @param height_mm Height in millimetres.
#' @return The path of the TIFF, invisibly.
save_figure <- function(plot, name, width_mm, height_mm) {
    permitted <- c(WIDTH_SINGLE_MM, WIDTH_ONEHALF_MM, WIDTH_FULL_MM)
    if (!isTRUE(any(abs(width_mm - permitted) < 1e-9))) {
        stop(glue("{name}: width {width_mm} mm is not a permitted column width ",
                  "({paste(permitted, collapse = ' / ')} mm)"), call. = FALSE)
    }

    # Raster at the journal resolution. type = "cairo" gives antialiased text and honours the LZW request.
    grDevices::tiff(file.path(FIG_DIR, paste0(name, ".tif")),
                    width = width_mm, height = height_mm, units = "mm",
                    res = JOURNAL_DPI, compression = TIFF_COMPRESSION, type = "cairo")
    print(plot)
    grDevices::dev.off()

    grDevices::png(file.path(FIG_DIR, paste0(name, ".png")),
                   width = width_mm, height = height_mm, units = "mm",
                   res = JOURNAL_DPI, type = "cairo")
    print(plot)
    grDevices::dev.off()

    # Vector copy at the same physical size, so all three files describe the same figure.
    grDevices::cairo_pdf(file.path(FIG_DIR, paste0(name, ".pdf")),
                         width = width_mm / 25.4, height = height_mm / 25.4)
    print(plot)
    grDevices::dev.off()

    verify_figure(name, width_mm, height_mm)
    invisible(file.path(FIG_DIR, paste0(name, ".tif")))
}

#' Read a written TIFF back and check it against the journal specification. / 回读 TIFF 并按期刊规范校验。
#'
#' A figure can be requested at the right size and still come out wrong if a device silently falls back. Reading the
#' file back is the only way to know what was actually written, so every save is audited and any breach is reported
#' rather than left for a reviewer to find.
#'
#' @param name Figure name without extension.
#' @param width_mm Requested width in millimetres.
#' @param height_mm Requested height in millimetres.
#' @return TRUE if the file meets the specification, FALSE otherwise (invisibly).
verify_figure <- function(name, width_mm, height_mm) {
    tiff_path <- file.path(FIG_DIR, paste0(name, ".tif"))
    if (!file.exists(tiff_path)) {
        cat(glue("  {name}: FAIL - no file written"), NL)
        return(invisible(FALSE))
    }

    expected_px <- round(width_mm / 25.4 * JOURNAL_DPI)
    actual_px   <- tiff_dimensions(tiff_path)[1]
    within      <- abs(actual_px - expected_px) <= 2      # allow the device's own rounding

    cat(glue("  {str_pad(name, 10, 'right')} {width_mm} x {height_mm} mm  ",
             "{actual_px} px @ {JOURNAL_DPI} dpi  ",
             "{if (within) 'ok' else paste0('FAIL - expected ', expected_px, ' px')}"), NL)
    invisible(within)
}

#' Read the pixel dimensions from a TIFF header. / 从 TIFF 头部读取像素尺寸。
#'
#' Avoids a dependency on the tiff package, which is not needed for anything else, by reading the two tags directly.
#' Handles both byte orders and both TIFF field sizes.
#'
#' @param path Path to a TIFF file.
#' @return An integer vector c(width, height) in pixels.
tiff_dimensions <- function(path) {
    connection <- file(path, "rb")
    on.exit(close(connection))

    byte_order <- rawToChar(readBin(connection, "raw", 2))
    endian     <- if (byte_order == "II") "little" else "big"
    readBin(connection, "integer", 1, size = 2, endian = endian)              # magic number 42
    ifd_offset <- readBin(connection, "integer", 1, size = 4, endian = endian)

    seek(connection, ifd_offset)
    entry_count <- readBin(connection, "integer", 1, size = 2, signed = FALSE, endian = endian)

    dimensions <- c(width = NA_integer_, height = NA_integer_)
    for (i in seq_len(entry_count)) {
        tag        <- readBin(connection, "integer", 1, size = 2, signed = FALSE, endian = endian)
        field_type <- readBin(connection, "integer", 1, size = 2, signed = FALSE, endian = endian)
        readBin(connection, "integer", 1, size = 4, endian = endian)          # value count
        # A SHORT value sits in the first two bytes of the four-byte value field; a LONG fills it.
        value <- if (field_type == 3) {
            v <- readBin(connection, "integer", 1, size = 2, signed = FALSE, endian = endian)
            readBin(connection, "raw", 2)
            v
        } else {
            readBin(connection, "integer", 1, size = 4, endian = endian)
        }
        if (tag == 256) dimensions[["width"]]  <- value
        if (tag == 257) dimensions[["height"]] <- value
    }
    dimensions
}
