# src/mr.R — per-target two-sample MR: harmonize exposure+outcome, pick the estimator
# by instrument count (1 -> Wald ratio; >=3 -> weighted median main), and report the
# odds ratio per 1 SD LOWER non-HDL cholesterol (sign-flipped from GLGC's per-SD-higher).

suppressMessages({library(TwoSampleMR)})

# One gene x one outcome. Returns a one-row data.frame (or a row with NA + reason).
run_target_mr <- function(gene_name, endpoint_key, exposure = NULL) {
  na_row <- function(reason, nsnp = NA_integer_, method = NA_character_, minF = NA_real_)
    data.frame(gene = gene_name, outcome = endpoint_key, n_snp = nsnp, method = method,
               or = NA_real_, or_lci = NA_real_, or_uci = NA_real_, pval = NA_real_,
               min_F = minF, note = reason, stringsAsFactors = FALSE)

  if (is.null(exposure)) exposure <- build_exposure(gene_name)
  if (is.null(exposure)) return(na_row("no exposure instruments in GLGC extract"))
  minF <- suppressWarnings(min(exposure$Fstat.exposure, na.rm = TRUE))

  out <- build_outcome(endpoint_key, exposure$SNP)
  if (is.null(out)) return(na_row("no instruments found in FinnGen outcome", nrow(exposure), minF = minF))

  h <- harmonise_data(exposure, out, action = HARMONISE_ACTION)
  h <- h[h$mr_keep, , drop = FALSE]
  n <- nrow(h)
  if (n == 0L) return(na_row("all instruments dropped at harmonize (palindromic/ambiguous)",
                             nrow(exposure), minF = minF))

  method <- if (n >= 3L) "mr_weighted_median" else if (n == 2L) "mr_ivw" else "mr_wald_ratio"
  res <- mr(h, method_list = method)
  if (nrow(res) == 0L || is.na(res$b[1]))
    return(na_row("estimator returned no estimate", n, method, minF))

  b <- res$b[1]; se <- res$se[1]        # per 1 SD HIGHER non-HDL
  # flip to per 1 SD LOWER non-HDL (paper's contrast)
  data.frame(
    gene = gene_name, outcome = endpoint_key, n_snp = n,
    method = sub("^mr_", "", method),
    or     = exp(-b),
    or_lci = exp(-b - 1.96 * se),
    or_uci = exp(-b + 1.96 * se),
    pval   = res$pval[1],
    min_F  = minF,
    note   = if (n < nrow(exposure)) sprintf("%d/%d SNPs kept", n, nrow(exposure)) else "",
    stringsAsFactors = FALSE
  )
}

# ---- Phase 3: MR from an arbitrary (exposure, outcome-df) pair ----------------
# Returns raw b/se (per 1 SD HIGHER exposure, poolable across sources for meta-analysis)
# AND the OR per 1 SD LOWER. `source_label` names the outcome source.
mr_pair <- function(gene_name, source_label, exposure, outcome_df) {
  na_row <- function(reason, n = NA_integer_) data.frame(
    gene = gene_name, source = source_label, n_snp = n, method = NA_character_,
    b = NA_real_, se = NA_real_, or = NA_real_, or_lci = NA_real_, or_uci = NA_real_,
    pval = NA_real_, note = reason, stringsAsFactors = FALSE)
  if (is.null(exposure) || is.null(outcome_df) || nrow(outcome_df) == 0L)
    return(na_row("no exposure or outcome data"))
  h <- harmonise_data(exposure, outcome_df, action = HARMONISE_ACTION)
  h <- h[h$mr_keep, , drop = FALSE]; n <- nrow(h)
  if (n == 0L) return(na_row("all SNPs dropped at harmonize"))
  method <- if (n >= 3L) "mr_weighted_median" else if (n == 2L) "mr_ivw" else "mr_wald_ratio"
  res <- mr(h, method_list = method)
  if (nrow(res) == 0L || is.na(res$b[1])) return(na_row("no estimate", n))
  b <- res$b[1]; se <- res$se[1]
  data.frame(gene = gene_name, source = source_label, n_snp = n,
             method = sub("^mr_", "", method), b = b, se = se,
             or = exp(-b), or_lci = exp(-b - 1.96*se), or_uci = exp(-b + 1.96*se),
             pval = res$pval[1], note = "", stringsAsFactors = FALSE)
}

# Fixed-effect inverse-variance meta-analysis of per-source b/se (log-odds, per SD higher).
# Reports pooled OR per 1 SD LOWER + Cochran's Q across sources.
meta_fixed <- function(df) {   # df: one gene, rows = sources, cols b/se
  d <- df[is.finite(df$b) & is.finite(df$se), ]
  if (nrow(d) < 2L) return(NULL)
  w <- 1 / d$se^2
  b <- sum(w * d$b) / sum(w); se <- sqrt(1 / sum(w))
  Q <- sum(w * (d$b - b)^2); Qdf <- nrow(d) - 1L; Qp <- pchisq(Q, Qdf, lower.tail = FALSE)
  data.frame(gene = d$gene[1], k_sources = nrow(d),
             or = exp(-b), or_lci = exp(-b - 1.96*se), or_uci = exp(-b + 1.96*se),
             pval = 2 * pnorm(-abs(b / se)), Q = Q, Q_pval = Qp, stringsAsFactors = FALSE)
}

# ---- Phase 2: harmonise once, reuse for estimators + diagnostics --------------
# Returns list(h = harmonised-kept df, minF = , reason = ) or reason on failure.
harmonise_target <- function(gene_name, endpoint_key, exposure) {
  if (is.null(exposure)) return(list(reason = "no exposure instruments"))
  minF <- suppressWarnings(min(exposure$Fstat.exposure, na.rm = TRUE))
  out  <- build_outcome(endpoint_key, exposure$SNP)
  if (is.null(out)) return(list(reason = "no instruments in outcome", minF = minF))
  h <- harmonise_data(exposure, out, action = HARMONISE_ACTION)
  h <- h[h$mr_keep, , drop = FALSE]
  if (nrow(h) == 0L) return(list(reason = "all SNPs dropped at harmonize", minF = minF))
  list(h = h, minF = minF)
}

# All estimators for a multi-SNP target, OR per 1 SD LOWER exposure.
run_all_estimators <- function(gene_name, endpoint_key, exposure,
                               methods = c("mr_ivw","mr_weighted_median",
                                           "mr_weighted_mode","mr_simple_mode","mr_egger_regression")) {
  hh <- harmonise_target(gene_name, endpoint_key, exposure)
  if (is.null(hh$h)) return(NULL)
  res <- mr(hh$h, method_list = methods)
  data.frame(
    gene = gene_name, outcome = endpoint_key, n_snp = res$nsnp,
    method = sub("^mr_", "", res$method),
    or = exp(-res$b), or_lci = exp(-res$b - 1.96*res$se), or_uci = exp(-res$b + 1.96*res$se),
    pval = res$pval, min_F = hh$minF, stringsAsFactors = FALSE
  )
}

# Pleiotropy (MR-Egger intercept) + heterogeneity (Cochran's Q) for a multi-SNP target.
run_diagnostics <- function(gene_name, endpoint_key, exposure) {
  hh <- harmonise_target(gene_name, endpoint_key, exposure)
  if (is.null(hh$h)) return(NULL)
  plt <- tryCatch(mr_pleiotropy_test(hh$h), error = function(e) NULL)
  het <- tryCatch(mr_heterogeneity(hh$h, method_list = "mr_ivw"), error = function(e) NULL)
  data.frame(
    gene = gene_name, outcome = endpoint_key, n_snp = nrow(hh$h),
    egger_intercept = if (!is.null(plt)) plt$egger_intercept else NA_real_,
    egger_intercept_p = if (!is.null(plt)) plt$pval else NA_real_,
    Q = if (!is.null(het)) het$Q[1] else NA_real_,
    Q_df = if (!is.null(het)) het$Q_df[1] else NA_real_,
    Q_pval = if (!is.null(het)) het$Q_pval[1] else NA_real_,
    stringsAsFactors = FALSE
  )
}
