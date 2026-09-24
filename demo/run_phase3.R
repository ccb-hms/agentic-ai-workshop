# run_phase3.R — EXTENSION (not reproduction): boost AD power with independent AD GWAS
# the original authors did NOT use, via IEU OpenGWAS. Compares the AD estimate across
# FinnGen R12 / Bellenguez 2022 / Kunkle 2019, and meta-analyzes FinnGen + Bellenguez.
#
#   *** These are NOT the paper's data sources. Results are an independent replication /
#       power extension, kept in separate tables from the reproduction (Phases 1-2). ***
#
# Needs an OpenGWAS token in .Renviron (OPENGWAS_JWT). Run: `Rscript run_phase3.R`

readRenviron(".Renviron")
suppressMessages({library(data.table); library(ggplot2)})
source("config.R")
source("src/exposure.R"); source("src/outcome.R"); source("src/mr.R"); source("src/write_results.R")
dir.create(DIR_RESULTS, showWarnings = FALSE)
genes <- names(GENES)

# AD outcome sources. `pool` flags which are independent enough to meta-analyze.
# Bellenguez 2022 INCLUDES the Kunkle/IGAP samples -> do NOT pool Bellenguez with Kunkle.
AD_SOURCES <- list(
  list(key = "FinnGen R12",     type = "finngen",  id = "ad",                  pool = TRUE),
  list(key = "Bellenguez 2022", type = "opengwas", id = "ebi-a-GCST90027158",  pool = TRUE),
  list(key = "Kunkle 2019",     type = "opengwas", id = "ieu-b-2",             pool = FALSE))

# ---- Per-gene x per-source AD MR (shared non-HDL instruments) -----------------
exp_main <- setNames(lapply(genes, build_exposure), genes)   # non-HDL, hardcoded rsIDs
rows <- list()
for (gn in genes) {
  snps <- exp_main[[gn]]$SNP
  for (s in AD_SOURCES) {
    od <- if (s$type == "finngen") build_outcome(s$id, snps)
          else build_outcome_opengwas(s$id, snps, label = s$key)
    rows[[length(rows)+1L]] <- transform(mr_pair(gn, s$key, exp_main[[gn]], od), pool = s$pool)
  }
}
ad <- rbindlist(rows, fill = TRUE)
fwrite(ad, file.path(DIR_RESULTS, "mr_phase3_ad_multisource.csv"))

# ---- Meta-analysis: FinnGen + Bellenguez (independent), fixed-effect IV --------
meta <- rbindlist(lapply(genes, function(gn) {
  d <- ad[gene == gn & pool == TRUE & is.finite(b)]
  m <- meta_fixed(d); if (is.null(m)) NULL else data.table(m, sources = paste(d$source, collapse = " + "))
}), fill = TRUE)
if (nrow(meta)) fwrite(meta, file.path(DIR_RESULTS, "mr_phase3_meta.csv"))

# ---- Console summary ----------------------------------------------------------
cat("\n=== AD, per 1 SD lower non-HDL, by outcome source (n cases: FinnGen ~6k, Kunkle ~22k, Bellenguez ~39k+proxy) ===\n")
print(ad[!is.na(or), .(gene, source, n_snp, method,
        OR = sprintf("%.2f (%.2f-%.2f)", or, or_lci, or_uci), pval = signif(pval, 2))])
cat("\n=== Meta-analysis (FinnGen + Bellenguez, fixed-effect) ===\n")
if (nrow(meta)) print(meta[, .(gene, k_sources,
        OR = sprintf("%.2f (%.2f-%.2f)", or, or_lci, or_uci), pval = signif(pval, 2), Q_pval = round(Q_pval, 3))])

# ---- Forest: AD estimate by source (all genes) --------------------------------
d <- ad[!is.na(or)]
d[, gene := factor(gene, levels = rev(genes))]
d[, source := factor(source, levels = c("FinnGen R12","Kunkle 2019","Bellenguez 2022"))]
p <- ggplot(d, aes(or, gene, colour = source)) +
  geom_vline(xintercept = 1, linetype = 2, colour = "grey50") +
  geom_errorbar(aes(xmin = or_lci, xmax = or_uci), orientation = "y",
                width = 0.25, position = position_dodge(width = 0.6)) +
  geom_point(size = 2, position = position_dodge(width = 0.6)) +
  scale_x_log10() +
  labs(title = "Alzheimer's disease: per 1 SD lower non-HDL, by outcome GWAS",
       subtitle = "EXTENSION — Bellenguez/Kunkle were NOT used by the original authors",
       x = "Odds ratio (log scale)", y = NULL, colour = "AD outcome GWAS") +
  theme_minimal(base_size = 11)
ggsave(file.path(DIR_RESULTS, "forest_phase3_AD_by_source.png"), p, width = 7.5, height = 4, dpi = 130)

# ---- Extension writeup --------------------------------------------------------
write_phase3_md(ad, meta)
cat("\nPhase 3 complete. See results/RESULTS_phase3.md\n")
