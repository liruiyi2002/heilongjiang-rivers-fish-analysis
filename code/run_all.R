# ======================================================================================================================
# run_all.R
#
# Run the full analysis pipeline
# ------------------------------
# Sources 01-09 in order to reproduce every result, table and figure from the data in data/. Scripts 01-07 write the
# numerical results to outputs/; scripts 08-09 draw the figures from those files into figures/, at journal
# specification. No internet required. Usage: Rscript code/run_all.R
#
# Figure 1 is the study-area map and is the one figure not drawn here: it needs Python and Pillow rather than R. Run
# `python code/map_generator/make_figure.py --print` for it; without --print it writes only a low-resolution proof.
#
# 运行完整分析流程
# ----------------
# 依次运行 01-09，仅用 data/ 中的数据重现全部结果、表格与插图。脚本 01-07 将数值结果写入 outputs/；脚本 08-09 依据
# 这些文件按期刊规范绘制插图并写入 figures/。无需联网。用法：Rscript code/run_all.R
#
# 图 1 为研究区地图，是唯一不在此处绘制的插图：它依赖 Python 与 Pillow 而非 R。请运行
# `python code/map_generator/make_figure.py --print`；不加 --print 仅输出低分辨率校样。
# ======================================================================================================================

.args <- commandArgs(trailingOnly = FALSE)
.file <- sub("^--file=", "", grep("^--file=", .args, value = TRUE))
code_dir <- if (length(.file)) dirname(gsub("~\\+~", " ", .file)) else "code"

# Analysis first, then figures: 08 and 09 read only what 01-07 have written, so the order matters.
# 先分析后绘图：08 与 09 仅读取 01-07 写出的文件，故顺序不可颠倒。
scripts <- c(
    "01_composition.R",
    "02_alpha_diversity.R",
    "03_beta_diversity.R",
    "04_simper_leaveout.R",
    "05_taxonomy_function.R",
    "06_environment_gradient.R",
    "07_water_quality_supp.R",
    "08_figures_main.R",
    "09_figures_supp.R"
)

for (script in scripts) {
    cat("\n\n################  ", script, "  ################\n")
    source(file.path(code_dir, script))
}

cat("\n\nAll scripts finished.\n")
cat("  results and tables -> reproducibility/outputs/\n")
cat("  figures 2-8, S1-S2 -> reproducibility/figures/\n")
cat("  figure 1 (map)     -> python code/map_generator/make_figure.py --print\n")
