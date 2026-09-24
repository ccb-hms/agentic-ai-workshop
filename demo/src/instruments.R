# src/instruments.R — Phase 2 de-novo instrument selection (replaces hardcoded rsIDs).
# Reproduces the paper's selection: cis variants in the gene window, GWAS-significant,
# LD-clumped to r^2 <= 0.05 against a local 1000G EUR panel, F > 10. Then checks that
# the paper's named rsIDs (config GENES$rsids) are recovered.

suppressMessages({library(data.table); library(TwoSampleMR); library(ieugwasr)})

# Returns list(exposure = formatted exposure df or NULL, report = one-row data.frame).
select_instruments_denovo <- function(gene_name, trait = EXPOSURE_MAIN) {
  g   <- GENES[[gene_name]]
  dt  <- fread(file.path(DIR_GLGC, paste0(trait, ".tsv")))
  dt[, pval := as.numeric(pval)]
  # cis window is already the extracted region; enforce genome-significance.
  cand <- dt[chr == g$chr & pos >= g$win_hg19[1] & pos <= g$win_hg19[2] & pval < DENOVO_PVAL]
  named_in_cand <- sum(g$rsids %in% cand$rsID)   # named SNPs that ARE GWAS-sig cis variants
  rep0 <- function(n_clumped = 0L, named_recovered = 0L, note = "")
    data.frame(gene = gene_name, trait = trait, n_cand = nrow(cand),
               n_clumped = n_clumped, named_n = length(g$rsids),
               named_sig = named_in_cand, named_lead = named_recovered, note = note,
               stringsAsFactors = FALSE)
  if (nrow(cand) == 0L) return(list(exposure = NULL, report = rep0(note = "no GWAS-sig cis variants")))

  # LD clump locally (r^2 <= 0.05). ieugwasr::ld_clump drops variants absent from panel.
  clumped <- tryCatch(
    ld_clump(dplyr::tibble(rsid = cand$rsID, pval = cand$pval, id = gene_name),
             clump_r2 = DENOVO_CLUMP_R2, clump_kb = DENOVO_CLUMP_KB,
             bfile = BFILE_EUR, plink_bin = PLINK),
    error = function(e) { message("clump error ", gene_name, ": ", conditionMessage(e)); NULL })
  if (is.null(clumped) || nrow(clumped) == 0L)
    return(list(exposure = NULL, report = rep0(note = "clumping returned nothing")))

  sub <- dt[rsID %in% clumped$rsid]
  sub[, Fstat := (beta / se)^2]
  sub <- sub[Fstat > F_MIN]                       # Assumption 1
  if (nrow(sub) == 0L) return(list(exposure = NULL, report = rep0(note = "no SNP with F>10")))
  sub[, exposure := paste0(gene_name, " (", trait, ", de-novo)")]

  exp <- format_data(
    as.data.frame(sub), type = "exposure",
    snp_col = "rsID", beta_col = "beta", se_col = "se",
    effect_allele_col = "effect_allele", other_allele_col = "other_allele",
    eaf_col = "eaf", pval_col = "pval", phenotype_col = "exposure")
  exp$Fstat.exposure <- sub$Fstat[match(exp$SNP, sub$rsID)]
  exp$gene <- gene_name

  named_rec <- sum(g$rsids %in% exp$SNP)
  lead <- intersect(g$rsids, exp$SNP)
  note <- if (length(lead)) paste("named as clump lead:", paste(lead, collapse = "|"))
          else if (named_in_cand > 0) "named SNP(s) GWAS-sig but absorbed into a clump (not lead)"
          else "named SNP(s) not GWAS-sig for this trait in GLGC"
  list(exposure = exp,
       report = rep0(n_clumped = nrow(exp), named_recovered = named_rec, note = note))
}
