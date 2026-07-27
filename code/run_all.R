# ======================================================================================================================
# run_all.R
#
# Run the full analysis pipeline
# ------------------------------
# Sources 01-07 in order to reproduce every result from the data in data/. No internet required. Usage: Rscript
# code/run_all.R
#
# 运行完整分析流程
# ----------------
# 依次运行 01-07，仅用 data/ 中的数据重现全部结果，无需联网。用法：Rscript code/run_all.R
# ======================================================================================================================

.args <- commandArgs(trailingOnly = FALSE)
.file <- sub("^--file=", "", grep("^--file=", .args, value = TRUE))
code_dir <- if (length(.file)) dirname(gsub("~\\+~", " ", .file)) else "code"

scripts <- c(
    "01_composition.R",
    "02_alpha_diversity.R",
    "03_beta_diversity.R",
    "04_simper_leaveout.R",
    "05_taxonomy_function.R",
    "06_environment_gradient.R",
    "07_water_quality_supp.R"
)

for (script in scripts) {
    cat("\n\n################  ", script, "  ################\n")
    source(file.path(code_dir, script))
}

cat("\n\nAll scripts finished. Outputs are in reproducibility/outputs/.\n")
