# src/download.R — extract & cache the drug-target cis windows from the remote
# GLGC (exposure, hg19) and FinnGen (outcome, hg38) bgzipped GWAS via tabix.
# We never download the full multi-GB files; only the ~6 small gene windows.
# Idempotent: skips a target if its cached .tsv already exists and is non-empty.

suppressMessages({library(data.table)})
source("config.R")

dir.create(DIR_GLGC,    recursive = TRUE, showWarnings = FALSE)
dir.create(DIR_FINNGEN, recursive = TRUE, showWarnings = FALSE)
dir.create(DIR_RESULTS, recursive = TRUE, showWarnings = FALSE)

# Build "chr:start-end" region strings for a given build.
regions_for <- function(build = c("hg19","hg38")) {
  build <- match.arg(build)
  key <- if (build == "hg19") "win_hg19" else "win_hg38"
  vapply(GENES, function(g) sprintf("%d:%d-%d", g$chr, g[[key]][1], g[[key]][2]), character(1))
}

# One tabix call, all regions, -> data.table (raw, no header assumed on stdout).
tabix_extract <- function(url, regions) {
  args <- c(shQuote(url), regions)
  out <- suppressWarnings(system2(TABIX, args, stdout = TRUE, stderr = FALSE))
  if (length(out) == 0) return(data.table())
  fread(text = paste(out, collapse = "\n"), header = FALSE, sep = "\t")
}

# ---- GLGC exposure (hg19) -----------------------------------------------------
fetch_glgc <- function(trait) {
  dest <- file.path(DIR_GLGC, paste0(trait, ".tsv"))
  if (file.exists(dest) && file.size(dest) > 0) { cat("[cache] ", dest, "\n"); return(dest) }
  url <- file.path(GLGC_BASE, GLGC_FILES[[trait]])
  cat("[tabix] GLGC", trait, "...\n")
  dt <- tabix_extract(url, regions_for("hg19"))
  stopifnot(ncol(dt) == length(GLGC_COLS))
  setnames(dt, GLGC_COLS)
  dt[, chr := as.integer(chr)][, pos := as.integer(trimws(pos))]
  fwrite(dt, dest, sep = "\t")
  cat("        ", nrow(dt), "variants ->", dest, "\n")
  dest
}

# ---- FinnGen outcome (hg38) ---------------------------------------------------
FINNGEN_COLS <- c("chrom","pos","ref","alt","rsids","nearest_genes",
                  "pval","mlogp","beta","sebeta","af_alt","af_alt_cases","af_alt_controls")
fetch_finngen <- function(key) {
  dest <- file.path(DIR_FINNGEN, paste0(key, ".tsv"))
  if (file.exists(dest) && file.size(dest) > 0) { cat("[cache] ", dest, "\n"); return(dest) }
  url <- file.path(FINNGEN_BASE, FINNGEN_ENDPOINTS[[key]])
  cat("[tabix] FinnGen", key, "(", FINNGEN_ENDPOINTS[[key]], ") ...\n")
  dt <- tabix_extract(url, regions_for("hg38"))
  stopifnot(ncol(dt) == length(FINNGEN_COLS))
  setnames(dt, FINNGEN_COLS)
  fwrite(dt, dest, sep = "\t")
  cat("        ", nrow(dt), "variants ->", dest, "\n")
  dest
}

# ---- Assert every Phase-1 instrument rsID landed in the exposure extract ------
assert_instruments <- function(trait = EXPOSURE_MAIN) {
  dt <- fread(file.path(DIR_GLGC, paste0(trait, ".tsv")))
  want <- unlist(lapply(GENES, `[[`, "rsids"))
  miss <- setdiff(want, dt$rsID)
  if (length(miss)) {
    warning("Missing instrument rsIDs in GLGC ", trait, " extract: ",
            paste(miss, collapse = ", "), " — widen the cis window in config.R.")
  } else {
    cat("[ok] all", length(want), "instrument rsIDs present in GLGC", trait, "\n")
  }
  invisible(miss)
}

if (sys.nframe() == 0) {   # only when run as `Rscript src/download.R`, not when source()'d
  # Phase-0 scope: main exposure + all four FinnGen endpoints (Phase-2 outcomes staged).
  fetch_glgc(EXPOSURE_MAIN)
  invisible(lapply(names(FINNGEN_ENDPOINTS), fetch_finngen))
  assert_instruments()
  cat("\nPhase-0 extract complete.\n")
}
