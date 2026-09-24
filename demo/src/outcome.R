# src/outcome.R — build a TwoSampleMR outcome dataframe for one FinnGen endpoint,
# restricted to a given set of instrument rsIDs (matched by rsID across the hg19/hg38
# build difference). FinnGen beta is per-alt-allele log-odds.

suppressMessages({library(data.table); library(TwoSampleMR)})

# Phase 3 extension: pull an outcome from IEU OpenGWAS by rsID (needs OPENGWAS_JWT).
# Returns a TwoSampleMR outcome df, or NULL if nothing found. `label` names the source.
build_outcome_opengwas <- function(opengwas_id, snps, label = opengwas_id) {
  out <- tryCatch(
    TwoSampleMR::extract_outcome_data(snps = snps, outcomes = opengwas_id, proxies = FALSE),
    error = function(e) { message("OpenGWAS fetch failed (", opengwas_id, "): ", conditionMessage(e)); NULL })
  if (is.null(out) || nrow(out) == 0L) return(NULL)
  out$outcome <- label
  out
}

build_outcome <- function(endpoint_key, snps) {
  dt <- fread(file.path(DIR_FINNGEN, paste0(endpoint_key, ".tsv")))
  # `rsids` can occasionally be comma-joined; split and match any target rsID.
  dt[, rsid1 := tstrsplit(rsids, ",", fixed = TRUE, keep = 1L)]
  sub <- dt[rsid1 %in% snps]
  if (nrow(sub) == 0L) return(NULL)
  sub[, outcome := endpoint_key]
  format_data(
    as.data.frame(sub), type = "outcome",
    snp_col = "rsid1", beta_col = "beta", se_col = "sebeta",
    effect_allele_col = "alt", other_allele_col = "ref",
    eaf_col = "af_alt", pval_col = "pval", phenotype_col = "outcome"
  )
}
