# run_phase2.R — Phase 2 "make it right": all 4 outcomes; LDL/TG sensitivity exposures;
# IVW/Egger/mode estimators + pleiotropy/heterogeneity for multi-SNP genes; de-novo
# cis+clump instrument selection verified against the paper's named rsIDs. Writes
# results/*.csv, forest plots, and results/RESULTS.md.
# Run: `Rscript run_phase2.R`  (requires the 1000G EUR panel in data/ld for de-novo step)

suppressMessages({library(data.table); library(ggplot2)})
source("config.R")
source("src/exposure.R"); source("src/outcome.R"); source("src/mr.R"); source("src/instruments.R")
dir.create(DIR_RESULTS, showWarnings = FALSE)
genes <- names(GENES)

DISCLAIMER <- paste(
  "2SMR arm only (GLGC exposure x FinnGen R12 outcome). NOT the paper's numbers:",
  "FinnGen-only outcome (no UKB/Copenhagen); OR per 1 SD LOWER exposure. Method demo.")

say <- function(...) cat(..., "\n")

# ==== 1. Main (non-HDL) x all outcomes ========================================
main_rows <- list()
exp_main <- setNames(lapply(genes, build_exposure), genes)         # non-HDL, reuse
for (gn in genes) for (oc in PHASE2_OUTCOMES)
  main_rows[[length(main_rows)+1L]] <- run_target_mr(gn, oc, exposure = exp_main[[gn]])
main <- rbindlist(main_rows)[, exposure_trait := "nonHDL"]

# ==== 2. Sensitivity exposure (LDL / logTG) x all outcomes ====================
sens_rows <- list()
for (gn in genes) {
  tr <- SENSITIVITY_EXPOSURE[[gn]]
  ex <- build_exposure(gn, trait = tr)
  for (oc in PHASE2_OUTCOMES) {
    r <- run_target_mr(gn, oc, exposure = ex); r$exposure_trait <- tr
    sens_rows[[length(sens_rows)+1L]] <- r
  }
}
sens <- rbindlist(sens_rows)

allpe <- rbind(main, sens)
for (c in c("or","or_lci","or_uci")) set(allpe, j = c, value = round(allpe[[c]], 3))
allpe[, min_F := round(min_F, 1)]
fwrite(allpe, file.path(DIR_RESULTS, "mr_phase2_point_estimates.csv"))

# ==== 3. Sensitivity estimators (multi-SNP genes, non-HDL) ====================
est <- rbindlist(lapply(MULTI_SNP_GENES, function(gn)
  rbindlist(lapply(PHASE2_OUTCOMES, function(oc)
    run_all_estimators(gn, oc, exp_main[[gn]]))) ), fill = TRUE)
for (c in c("or","or_lci","or_uci")) set(est, j = c, value = round(est[[c]], 3))
fwrite(est, file.path(DIR_RESULTS, "mr_phase2_estimators.csv"))

# ==== 4. Diagnostics: pleiotropy + heterogeneity (multi-SNP genes) ============
diag <- rbindlist(lapply(MULTI_SNP_GENES, function(gn)
  rbindlist(lapply(PHASE2_OUTCOMES, function(oc)
    run_diagnostics(gn, oc, exp_main[[gn]]))) ), fill = TRUE)
num <- c("egger_intercept","egger_intercept_p","Q","Q_pval")
for (c in num) if (c %in% names(diag)) set(diag, j = c, value = round(diag[[c]], 4))
fwrite(diag, file.path(DIR_RESULTS, "mr_phase2_diagnostics.csv"))

# ==== 5. De-novo instrument selection (needs LD panel) ========================
have_ld <- file.exists(paste0(BFILE_EUR, ".bed"))
denovo_report <- denovo_mr <- NULL
if (have_ld) {
  say("[de-novo] selecting instruments via local LD clumping ...")
  sel <- setNames(lapply(genes, select_instruments_denovo), genes)
  denovo_report <- rbindlist(lapply(sel, `[[`, "report"), fill = TRUE)
  fwrite(denovo_report, file.path(DIR_RESULTS, "instruments_denovo.csv"))
  dn_rows <- list()
  for (gn in genes) {
    ex <- sel[[gn]]$exposure
    if (is.null(ex)) next
    for (oc in PHASE2_OUTCOMES)
      dn_rows[[length(dn_rows)+1L]] <- run_target_mr(gn, oc, exposure = ex)
  }
  denovo_mr <- rbindlist(dn_rows, fill = TRUE)
  for (c in c("or","or_lci","or_uci")) set(denovo_mr, j = c, value = round(denovo_mr[[c]], 3))
  fwrite(denovo_mr, file.path(DIR_RESULTS, "mr_phase2_denovo.csv"))
} else {
  say("[de-novo] SKIPPED: LD panel not found at", paste0(BFILE_EUR, ".bed"),
      "-- run once data/ld/EUR.* is present.")
}

# ==== 6. Forest plots: main non-HDL, all outcomes =============================
for (oc in PHASE2_OUTCOMES) {
  d <- main[outcome == oc & !is.na(or)]; if (!nrow(d)) next
  d[, gene := factor(gene, levels = rev(genes))]
  p <- ggplot(d, aes(or, gene)) +
    geom_vline(xintercept = 1, linetype = 2, colour = "grey50") +
    geom_errorbar(aes(xmin = or_lci, xmax = or_uci), orientation = "y", width = 0.2) +
    geom_point(size = 2.4) + scale_x_log10() +
    labs(title = sprintf("Per 1 SD lower non-HDL -> %s (FinnGen %s)", oc, FINNGEN_REL),
         x = "Odds ratio (log scale)", y = NULL,
         caption = paste(strwrap(DISCLAIMER, 90), collapse = "\n")) +
    theme_minimal(base_size = 11)
  ggsave(file.path(DIR_RESULTS, paste0("forest2_", oc, ".png")), p, width = 7, height = 3.6, dpi = 130)
}

# ==== 7. RESULTS.md ===========================================================
source("src/write_results.R")
write_results_md(allpe, est, diag, denovo_report, denovo_mr, DISCLAIMER)

say("\nPhase 2 complete. See results/RESULTS.md")
print(allpe[exposure_trait == "nonHDL", .(gene, outcome, n_snp, method, or, or_lci, or_uci, pval)])
