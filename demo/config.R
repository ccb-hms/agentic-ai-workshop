# config.R — central configuration for the lipid-target -> dementia 2SMR reproduction.
# See plan.md (build plan) and research.md (fact base). Values here are veto-friendly.

# ---- Paths -------------------------------------------------------------------
DIR_DATA     <- "data"
DIR_GLGC     <- file.path(DIR_DATA, "glgc")      # cached exposure cis-window extracts
DIR_FINNGEN  <- file.path(DIR_DATA, "finngen")   # cached outcome cis-window extracts
DIR_LD       <- file.path(DIR_DATA, "ld")        # 1000G EUR plink panel (Phase 2 only)
DIR_RESULTS  <- "results"

# ---- Remote data sources -----------------------------------------------------
# GLGC (Graham 2021), European ancestry, WITHOUT UK Biobank (avoids sample overlap
# with the outcome side / matches the paper). Genome build GRCh37 (hg19).
# Files are bgzipped + tabix-indexed, so we pull only cis windows remotely.
GLGC_BASE <- "https://csg.sph.umich.edu/willer/public/glgc-lipids2021/results/ancestry_specific"
GLGC_FILES <- list(
  nonHDL = "without_UKB_nonHDL_INV_EUR_HRC_1KGP3_others_ALL.meta.singlevar.results.gz",
  LDL    = "without_UKB_LDL_INV_EUR_HRC_1KGP3_others_ALL.meta.singlevar.results.gz",
  logTG  = "without_UKB_logTG_INV_EUR_HRC_1KGP3_others_ALL.meta.singlevar.results.gz"
)
# GLGC has NO header row. Column order (1-indexed), confirmed by inspection:
#  1 rsID  2 CHROM  3 POS(b37)  4 REF(other)  5 ALT(effect)  6 N  7 N_studies
#  8 ALT_AF(EAF)  9 EFFECT_SIZE(beta,per-SD)  10 SE  11 -log10P  12 P  13 -log10P_GC  14 P_GC
GLGC_COLS <- c("rsID","chr","pos","other_allele","effect_allele","N","n_studies",
               "eaf","beta","se","neglog10p","pval","neglog10p_gc","pval_gc")

# FinnGen R12 (latest public release as of 2026-07). Genome build GRCh38 (hg38).
# Outcome endpoints (phenocodes confirmed against the R12 summary_stats manifest;
# ICD definitions in research.md section 6, confirm in Risteys).
FINNGEN_REL  <- "R12"
FINNGEN_BASE <- "https://storage.googleapis.com/finngen-public-data-r12/summary_stats/release"
FINNGEN_ENDPOINTS <- list(
  dementia_all = "finngen_R12_F5_DEMENTIA.gz",    # all-cause dementia (composite)
  ad           = "finngen_R12_G6_ALZHEIMER.gz",   # Alzheimer's disease
  vascular     = "finngen_R12_F5_VASCDEM.gz",     # vascular dementia
  ihd          = "finngen_R12_I9_IHD.gz",         # ischemic heart disease (positive control)
  # An earlier note here claimed unspecified dementia (ICD-10 F03) had no clean standalone R12
  # public endpoint. That was wrong: R12 publishes it as F5_DEMNAS (Risteys: "Unspecified
  # dementia", ICD-10 F03, ICD-9 290/2941, ICD-8 2900/29019). Now included, which completes
  # the paper's four dementia endpoints (research.md section 6).
  unspecified  = "finngen_R12_F5_DEMNAS.gz"       # unspecified dementia (ICD-10 F03)
  # F02 "dementia in other diseases" is likewise public as F5_DEMINOTH — the remaining
  # component of the dementia_all composite, not an endpoint the paper reports separately.
)
# FinnGen column names (file HAS a header): #chrom pos ref alt rsids nearest_genes
#  pval mlogp beta sebeta af_alt af_alt_cases af_alt_controls
# effect allele = alt, other = ref, beta = per-alt log-odds.

# Phase-1 outcomes (must include the IHD positive control per plan.md exit criteria).
PHASE1_OUTCOMES <- c("dementia_all", "ihd")

# ---- Drug-target genes & instruments ----------------------------------------
# rsIDs from research.md section 4 (Phase-1 hardcoded instruments).
# n_snp drives the estimator: 1 -> Wald ratio; >=3 -> weighted median (main).
# PCSK9/CETP SNPs were NOT individually named in the paper -> flagged approximate;
# Phase 2 replaces all of these with de-novo cis+clump selection (src/instruments.R).
# cis windows given per build for tabix extraction (generous +/- ~120kb; rsID-filtered after).
GENES <- list(
  HMGCR    = list(chr = 5,  rsids = "rs5909",
                  win_hg19 = c(74530000, 74760000), win_hg38 = c(75230000, 75470000),
                  approx = FALSE),
  NPC1L1   = list(chr = 7,  rsids = "rs217434",
                  win_hg19 = c(44450000, 44680000), win_hg38 = c(44410000, 44640000),
                  approx = FALSE),
  PCSK9    = list(chr = 1,  rsids = c("rs11591147","rs2479409","rs11206510"),
                  win_hg19 = c(55400000, 55630000), win_hg38 = c(54920000, 55170000),
                  approx = TRUE),
  ANGPTL4  = list(chr = 19, rsids = "rs116843064",
                  win_hg19 = c(8330000, 8540000),   win_hg38 = c(8260000, 8480000),
                  approx = FALSE),
  LPL      = list(chr = 8,  rsids = "rs328",
                  win_hg19 = c(19690000, 19930000), win_hg38 = c(19830000, 20080000),
                  approx = FALSE),
  CETP     = list(chr = 16, rsids = c("rs3764261","rs1800775","rs247616"),
                  win_hg19 = c(56890000, 57120000), win_hg38 = c(56850000, 57090000),
                  approx = TRUE)
)

# ---- Analysis knobs ----------------------------------------------------------
EXPOSURE_MAIN <- "nonHDL"   # main exposure trait (per-SD)
F_MIN         <- 10         # instrument-strength floor (Assumption 1)
HARMONISE_ACTION <- 2       # TwoSampleMR: 2 = drop ambiguous palindromes (default)

# ---- Phase 2 settings --------------------------------------------------------
# All outcomes: the paper's four dementia endpoints (research.md section 6) + the IHD
# positive control.
PHASE2_OUTCOMES <- c("dementia_all", "ad", "vascular", "unspecified", "ihd")

# Sensitivity exposure trait per target (research.md section 5): the trait each target
# primarily acts on. LDL for the LDL-lowering targets; logTG for the TG targets.
# (GLGC logTG is inverse-normalised -> reported per-SD, not per-halving; deviation noted.)
SENSITIVITY_EXPOSURE <- c(HMGCR = "LDL", NPC1L1 = "LDL", PCSK9 = "LDL", CETP = "LDL",
                          ANGPTL4 = "logTG", LPL = "logTG")

# Genes with >=3 instruments -> get IVW/Egger/mode + pleiotropy/heterogeneity.
MULTI_SNP_GENES <- c("PCSK9", "CETP")

# De-novo instrument selection (Phase 2, src/instruments.R).
DENOVO_PVAL    <- 5e-8      # GWAS-significant cis variants only
DENOVO_CLUMP_R2 <- 0.05     # r^2 threshold (research.md section 4: correlated if r2>0.05)
DENOVO_CLUMP_KB <- 1000     # clump window (kb) — large enough to span each cis region

# LD reference (1000G EUR, build 37; from MRC IEU) + plink 1.9 binary.
# Default to the plink bundled with genetics.binaRies (what ieugwasr::ld_clump expects).
BFILE_EUR <- file.path(DIR_LD, "EUR")
PLINK <- Sys.getenv("PLINK_BIN", unset = "")
if (PLINK == "") PLINK <- tryCatch(genetics.binaRies::get_plink_binary(),
                                   error = function(e) "/opt/homebrew/bin/plink")

# tabix binary (brew htslib). Overridable via env.
TABIX <- Sys.getenv("TABIX_BIN", unset = "/opt/homebrew/bin/tabix")
