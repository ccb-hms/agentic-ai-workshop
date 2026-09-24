# run_phase1.R — Phase 1 "make it work": non-HDL -> {all-cause dementia, IHD} for all
# 6 drug-target genes, hardcoded rsID instruments, Wald/weighted-median, OR per 1 SD
# LOWER non-HDL. Runnable end-to-end: `Rscript run_phase1.R`.

suppressMessages({library(data.table); library(ggplot2)})
source("config.R")
source("src/exposure.R"); source("src/outcome.R"); source("src/mr.R")
dir.create(DIR_RESULTS, showWarnings = FALSE)

DISCLAIMER <- paste(
  "2SMR arm only (GLGC exposure x FinnGen outcome). NOT the paper's numbers:",
  "FinnGen-only outcome, no UKB/Copenhagen; OR is per 1 SD LOWER non-HDL cholesterol.",
  "Illustrates the method, not clinical drug effects. See plan.md section 0.")

# ---- Run the grid: gene x outcome --------------------------------------------
genes <- names(GENES)
rows <- list()
for (gn in genes) {
  exp <- build_exposure(gn)                       # build once per gene, reuse across outcomes
  for (oc in PHASE1_OUTCOMES) {
    rows[[length(rows) + 1L]] <- run_target_mr(gn, oc, exposure = exp)
  }
}
res <- rbindlist(rows)
res[, `:=`(or = round(or, 3), or_lci = round(or_lci, 3), or_uci = round(or_uci, 3),
           min_F = round(min_F, 1))]

# ---- Write table with disclaimer header --------------------------------------
csv <- file.path(DIR_RESULTS, "mr_phase1.csv")
writeLines(paste0("# ", DISCLAIMER), csv)
fwrite(res, csv, append = TRUE, col.names = TRUE)
cat("\n=== Phase 1 results (per 1 SD lower non-HDL) ===\n")
print(res[, .(gene, outcome, n_snp, method, or, or_lci, or_uci, pval, min_F, note)])
cat("\nwrote", csv, "\n")

# ---- Forest plot per outcome -------------------------------------------------
for (oc in PHASE1_OUTCOMES) {
  d <- res[outcome == oc & !is.na(or)]
  if (nrow(d) == 0) next
  d[, gene := factor(gene, levels = rev(genes))]
  p <- ggplot(d, aes(or, gene)) +
    geom_vline(xintercept = 1, linetype = 2, colour = "grey50") +
    geom_errorbar(aes(xmin = or_lci, xmax = or_uci), orientation = "y", width = 0.2) +
    geom_point(size = 2.4) +
    scale_x_log10() +
    labs(title = sprintf("Per 1 SD lower non-HDL -> %s (FinnGen %s)", oc, FINNGEN_REL),
         subtitle = "OR (95% CI); Wald ratio (1 SNP) / weighted median (>=3 SNP)",
         x = "Odds ratio (log scale)", y = NULL,
         caption = strwrap(DISCLAIMER, width = 90) |> paste(collapse = "\n")) +
    theme_minimal(base_size = 11)
  ggsave(file.path(DIR_RESULTS, paste0("forest_", oc, ".png")), p,
         width = 7, height = 3.6, dpi = 130)
}

# ---- Positive-control sanity check (plan.md exit criterion) ------------------
ihd <- res[outcome == "ihd" & !is.na(or)]
anti <- c("HMGCR","LPL","PCSK9","CETP")   # established anti-atherogenic targets
prot <- ihd[gene %in% anti & or < 1, gene]
cat("\n--- Positive control (IHD) ---\n")
cat("Anti-atherogenic targets protective for IHD (OR<1):",
    paste(prot, collapse = ", "), "\n")
if (length(prot) >= 3) {
  cat("PASS: IHD behaves as a positive control -> dementia estimates interpretable.\n")
} else {
  cat("CHECK: IHD not broadly protective -> inspect harmonization/allele flips before trusting dementia.\n")
}
