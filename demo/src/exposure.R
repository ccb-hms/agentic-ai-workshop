# src/exposure.R — build a TwoSampleMR exposure dataframe for one drug-target gene
# from the cached GLGC cis-window extract, restricted to that gene's instrument rsIDs.

suppressMessages({library(data.table); library(TwoSampleMR)})

# Returns a formatted exposure df (or NULL if no instruments found), with a per-SNP
# F statistic column. beta is per-SD of the lipid trait (GLGC is inverse-normalised).
build_exposure <- function(gene_name, trait = EXPOSURE_MAIN) {
  g   <- GENES[[gene_name]]
  dt  <- fread(file.path(DIR_GLGC, paste0(trait, ".tsv")))
  sub <- dt[rsID %in% g$rsids]
  if (nrow(sub) == 0L) return(NULL)
  sub[, pval := as.numeric(pval)]   # GLGC P can read as char (tiny sci-notation) -> coerce
  sub[, `:=`(exposure = paste0(gene_name, " (", trait, ")"),
             Fstat = (beta / se)^2)]
  exp <- format_data(
    as.data.frame(sub), type = "exposure",
    snp_col = "rsID", beta_col = "beta", se_col = "se",
    effect_allele_col = "effect_allele", other_allele_col = "other_allele",
    eaf_col = "eaf", pval_col = "pval", phenotype_col = "exposure"
  )
  # carry F through (format_data drops unknown cols)
  exp$Fstat.exposure <- sub$Fstat[match(exp$SNP, sub$rsID)]
  exp$gene <- gene_name
  exp
}
