# Plan: Reproducing the lipid drug-target → dementia MR pipeline (GLGC + FinnGen)

Companion to [research.md](research.md). This is the build plan; `research.md` is the fact base.

## 0. What we are (and are not) reproducing

**Goal:** reproduce the *two-sample Mendelian randomization (2SMR) arm* of Nordestgaard et al. 2025 —
per-drug-target odds ratios for dementia from genetically-proxied lower non-HDL cholesterol — using
the **only two no-request public datasets** in the paper: **GLGC** (lipid GWAS, exposure) and
**FinnGen** (dementia / IHD GWAS, outcome). Workshop-grade tutorial.

**Explicitly NOT goals** (state these loudly in every output):

1. **Not the paper's numbers.** The paper meta-analyzed 2SMR estimates that *also* included UK
   Biobank and Copenhagen (CGPS/CCHS) individual-level data. A GLGC-exposure + FinnGen-outcome-only
   run uses a different, smaller outcome sample and *will* give different ORs and much wider CIs
   (dementia subtypes in FinnGen have only 2,667–6,145 cases). §9 of research.md lists the paper's
   values only as a rough direction/sanity anchor.
2. **Not the Cox-regression or one-sample MR arms.** Those need individual-level CGPS/CCHS/UKB data
   that cannot be obtained without an application. Out of scope, permanently.
3. **Not per-mmol/L scaling.** GLGC betas are in SD units, so the 2SMR arm reports **per 1 SD lower
   non-HDL cholesterol** (the individual-level arms used per 1 mmol/L). Every table says "per SD".

We reproduce the *2SMR machinery*; the ORs illustrate the method, not clinical drug effects.

### Chosen defaults (swap-friendly — veto any of these)
| Decision | Default | Why | Where set |
|---|---|---|---|
| Language / stack | **R + `TwoSampleMR`** | paper-faithful; gives harmonization, Wald, weighted-median, IVW, Egger, mode, F-stats for free | project-wide |
| Data + LD source | **local files + local 1000G EUR LD panel** | fully offline & reproducible; matches the "2 datasets" framing | `config.R`, `data/` |
| Phase-1 instruments | **hardcoded rsIDs** (research.md §4) | deterministic MVP; no clumping needed to get end-to-end | `config.R: INSTRUMENTS` |
| Phase-2 instruments | **de-novo cis-window + clump (r²≤0.05, F>10)** | reproduces the actual selection method | `src/instruments.R` |
| Exposure (main) | **non-HDL cholesterol**, European, **non-UKB** | comparable across all 6 targets; non-UKB avoids overlap | `config.R: EXPOSURE` |
| FinnGen release | **latest available** (confirm phenocodes in Risteys) | paper's F10 is superseded; latest = most power | `config.R: FINNGEN_REL` |
| Genome build | **GRCh37 (hg19)** for both files | paper build; must match before harmonizing | `config.R` |
| Cross-cohort meta-analysis | **omitted** | single outcome source (FinnGen only) → nothing to pool | documented deviation |

---

## Phase 0 — Environment & data acquisition ("get the bytes") ✅ DONE

**Result:** R 4.5 + `TwoSampleMR`/`ieugwasr`/`data.table`/`ggplot2`; `htslib` (tabix) and the
plink 1.9 bundled by `genetics.binaRies`. Instead of downloading ~5 GB of full GLGC/FinnGen
files, `src/download.R` uses **remote `tabix`** to pull only the 6 cis-gene windows (~10–20k
variants/file) — offline after first fetch. GLGC = non-UKB EUR (hg19); FinnGen = **R12** (hg38);
harmonize by rsID so the build gap is moot. Endpoints resolved to `F5_DEMENTIA`, `G6_ALZHEIMER`,
`F5_VASCDEM`, `I9_IHD` (`results/endpoints.md`). All 10 Phase-1 instrument rsIDs present. 1000G
EUR LD panel cached in `data/ld/` (Phase-2 only).


**Tasks**
1. **R env.** R ≥ 4.1. Packages: `TwoSampleMR`, `ieugwasr` (clumping/LD helpers), `data.table`
   (fast summary-stat reads), `dplyr`, `meta` (only if we ever pool), `ggplot2` for forest plots.
   Pin versions in `renv.lock` (or a `sessionInfo()` dump in `results/`). `plinkbinr` or a system
   `plink` 1.9 binary for **local** LD clumping.
2. **Download exposure — GLGC** (https://www.lipidgenetics.org/, non-UKB European) into `data/glgc/`:
   non-HDL (main), plus **LDL** and **triglycerides** (Phase-2 sensitivity). Keep columns:
   rsID, chr, pos (hg19), effect/other allele, EAF, beta, SE, P, N.
3. **Download outcome — FinnGen** (https://www.finngen.fi/en/access_results, latest release) into
   `data/finngen/`: the endpoint files for **AD**, **vascular dementia**, **unspecified dementia**,
   **all-cause dementia**, and **IHD** (positive control). Resolve exact phenocodes in **Risteys**
   for the release you pull (§6 of research.md gives the ICD definitions to match against).
4. **LD reference panel** into `data/ld/`: 1000 Genomes Phase 3 **EUR** plink bfiles (bed/bim/fam),
   hg19. **Only exercised in Phase 2** (de-novo clumping); not on the Phase-1 hot path.
5. `src/download.R` (or a `Makefile`/`get_data.sh`) that fetches + caches (skip if present) and
   prints a manifest (rows, cols, build) per file. `data/` is gitignored.

**Exit criteria:** every GLGC/FinnGen file reads into a `data.table` with the expected columns and
build; endpoint→phenocode mapping recorded in `results/endpoints.md`; LD panel present. No download
step in the analysis hot path.

---

## Phase 1 — Make it work (minimal end-to-end, non-HDL, hardcoded rsIDs) ✅ DONE

**Result** (`run_phase1.R` → `results/mr_phase1.csv`, `forest_*.png`): all 6 genes × {all-cause
dementia, IHD} produced finite ORs; F 62–492. **Positive control PASSED** — HMGCR/PCSK9/LPL/CETP
all protective for IHD. Concordance with paper §9 is strong: IHD near-exact (ANGPTL4 0.23 vs 0.23,
PCSK9 0.62 vs 0.63, HMGCR 0.44 vs 0.41), dementia directions all match with wider CIs as expected
(FinnGen-only). Bug fixed: 2-SNP case (Wald needs 1, weighted-median needs ≥3) → IVW fallback.

Produce a per-target OR table for **all 6 genes × {all-cause dementia, IHD}** from local files in one
runnable script. Mechanics over fidelity.

**1.1 Instruments (`config.R`).** Hardcode the rsIDs from research.md §4:
- 1-SNP: **HMGCR** rs5909, **NPC1L1** rs217434, **ANGPTL4** rs116843064, **LPL** rs328.
- 3-SNP: **PCSK9** {rs11591147, rs2479409, rs11206510}, **CETP** {rs3764261, rs1800775, rs247616}.
- *Flag:* the paper did not individually name the PCSK9/CETP SNPs — these are the "common alternative
  cis instruments" from §4, so PCSK9/CETP MVP results are approximate; Phase 2 de-novo is the real
  selection. No clumping is needed in Phase 1 (SNP lists are fixed).

**1.2 Build exposure (`src/exposure.R`).** For each gene, pull its rsID(s) from the GLGC **non-HDL**
file. Format as a TwoSampleMR exposure dataframe (`format_data(type="exposure")`): beta, SE, effect/
other allele, EAF, P. Compute **per-SNP F statistic** (`F = (beta/se)^2`) and assert F > 10.

**1.3 Extract outcome (`src/outcome.R`).** Pull the same rsIDs from each FinnGen outcome file
(all-cause dementia, IHD) on the log-odds (beta/SE) scale; `format_data(type="outcome")`.

**1.4 Harmonize + estimate (`src/mr.R`).**
- `harmonise_data(exposure, outcome)` — align to a common effect allele. **Palindromic-SNP guard:**
  a single-SNP target whose one SNP is an ambiguous palindrome with intermediate EAF gets dropped and
  the whole target goes NA — detect and log this explicitly rather than silently emitting a blank row.
- Estimate per target:
  - **1 instrument → Wald ratio** (HMGCR, NPC1L1, ANGPTL4, LPL).
  - **≥3 instruments → weighted median** as the main method (PCSK9, CETP).
- Convert to **OR (95% CI) per 1 SD lower non-HDL** (sign so that *lower* exposure is the contrast).

**1.5 Output (`run_phase1.R`).** `results/mr_phase1.csv` + a forest plot per outcome, columns:
gene, outcome, n_snp, method, OR, CI, P, min-F. Header carries the §0 disclaimer.

**Exit criteria (how we know it "works"):**
- One `Rscript run_phase1.R` runs end-to-end from local files, no manual steps.
- All 6 genes emit a finite OR for both outcomes (or a *logged* reason if a target drops on harmonize).
- **Positive-control sanity (not paper-matching):** IHD ORs point protective (<1) for the
  anti-atherogenic targets (HMGCR, LPL, PCSK9, CETP) — the paper's whole logic is "trust dementia
  only after IHD behaves." If IHD is null/inverted across the board, stop and debug harmonization
  (allele flips) before interpreting dementia.

---

## Phase 2 — Make it right (fidelity, sensitivity, assumption checks) ✅ DONE

**Result** (`run_phase2.R` → `results/RESULTS.md`, `mr_phase2_*.csv`, `instruments_denovo.csv`,
`forest2_*.png`):
- **All 5 outcomes** × 6 genes — all-cause dementia, AD, vascular dementia, unspecified dementia
  and IHD, i.e. the paper's four dementia endpoints plus the positive control; **LDL/logTG
  sensitivity exposures** (CETP-via-LDL IHD 0.33; ANGPTL4/LPL via logTG per-SD).
  - *Unspecified dementia was initially omitted* on the false premise that FinnGen R12 published no
    standalone endpoint for it. It does — `F5_DEMNAS` (ICD-10 F03), public, no application. Added
    and re-run; every estimate is null with wide CIs (~4.4k cases). See `results/endpoints.md`.
  - The re-run reproduced the previous four outcomes to 3 decimal places, so nothing else moved.
  - **De-novo selection was not re-run** (no local 1000G LD panel / plink on this machine), so
    `results/RESULTS.md` now reports it as skipped. `instruments_denovo.csv` and
    `mr_phase2_denovo.csv` are the earlier 4-outcome run.
- **5 estimators** (IVW/median/mode×2/Egger) for PCSK9 & CETP — tight agreement; Egger unstable at
  3 SNPs (shown). **Pleiotropy** (Egger intercept ≈ 0) and **heterogeneity** (Cochran's Q) clean
  except PCSK9→IHD (Q p=0.024).
- **De-novo cis+clump selection** via local plink/1000G-EUR (r²≤0.05, F>10): every paper-named SNP
  is GWAS-significant here (`named_sig` = `named_n` for all 6); 3/6 survive as clump leads, the rest
  absorbed into a stronger-lead clump. De-novo MR agrees in direction with the curated instruments;
  IHD positive control holds under de-novo too.
- Bug fixed: markdown-table renderer recycled row 1 (`ifelse` length-1 test).

Iterate the working pipeline toward the paper's actual method. Each item independently shippable;
suggested order.

**2.1 De-novo instrument selection (`src/instruments.R`).** Replace hardcoded rsIDs with the
reproducible selection from research.md §4: for each gene take GLGC variants in the **cis window**
(gene ± fixed flank, e.g. 100 kb, on hg19 coords from §4), keep GWAS-significant P, **LD-clump to
r² ≤ 0.05** against the local 1000G EUR panel, require **F > 10**. Then *verify the paper's named
rsIDs fall out* as a regression check. This is where the LD panel finally earns its keep.

**2.2 All outcomes.** Extend from {dementia, IHD} to the full set: **AD, vascular dementia,
unspecified dementia, all-cause dementia, IHD**. Tabulate gene × outcome. Expect vascular/unspecified
signals nominally larger than AD (research.md §9).

**2.3 Sensitivity exposures.** Re-run each target on the trait it primarily acts on (research.md §5):
**LDL** for HMGCR/NPC1L1/PCSK9/CETP; **triglycerides** for ANGPTL4/LPL (log2-transform, scale per
*halving* of TG: `log2_trig = ln(TRIG)/ln(2)`). HDL is *not* an exposure for CETP.

**2.4 Sensitivity estimators (multi-SNP genes only: PCSK9, CETP).** Add **IVW, weighted mode,
simple mode, MR-Egger** alongside weighted median (`mr()` with the method list). Report all so the
reader sees estimator agreement.

**2.5 Assumption / robustness checks.**
- **Pleiotropy:** MR-Egger intercept (`mr_pleiotropy_test`) — intercept ≈ 0, P > 0.05 desired.
- **Heterogeneity:** Cochran's Q (`mr_heterogeneity`).
- **Relevance (Assumption 1):** per-instrument F table (already computed in 1.2).
- **Exclusion restriction (Assumption 3) falsification:** check each instrument's association with
  *other* lipids/apolipoproteins in GLGC (LDL/HDL/TG) — a clean cis instrument should move mainly its
  target trait.

**2.6 Results writeup (`results/RESULTS.md`).** Gene × outcome OR tables (main + sensitivity),
forest plots, assumption-check tables, and the §0 caveats front and center — including an explicit
"why these differ from the paper's §9 values" paragraph (FinnGen-only outcome, no UKB/Copenhagen).

**Exit criteria:** de-novo instruments reproduce the named rsIDs; full outcome × exposure grid with
sensitivity estimators and pleiotropy/heterogeneity/F diagnostics; `RESULTS.md` with the FinnGen-only
divergence stated plainly.

---

## Phase 3 — Breadth (optional / stretch) ✅ PARTLY DONE (AD extension + meta done)

**Framing:** this phase is an **EXTENSION, not reproduction** — Bellenguez/Kunkle were *not* used by
the original authors. Kept in separate outputs (`RESULTS_phase3.md`) so it never conflates with the
reproduction. `run_phase3.R`; token in gitignored `.Renviron` (`OPENGWAS_JWT`).

- **Alternative AD outcomes via IEU OpenGWAS** ✅ DONE. AD arm re-run vs **Bellenguez 2022**
  (`ebi-a-GCST90027158`, ~39k+proxy) and **Kunkle 2019** (`ieu-b-2`, ~22k, clean). Precision rose as
  designed: e.g. ANGPTL4 AD FinnGen 2.56 (0.88–7.44) → Bellenguez 2.65 (1.20–5.87, now significant).
  Notable source disagreement flagged: HMGCR flips harmful only in Kunkle (1-SNP Wald, noisy).
- **Cross-source meta-analysis** ✅ DONE. Fixed-effect inverse-variance pool of **FinnGen + Bellenguez**
  (independent). **Kunkle deliberately NOT pooled** — Bellenguez already contains the Kunkle/IGAP
  samples (double-count). Cochran's Q p>0.05 for all genes (sources agree). ANGPTL4 meta 2.62
  (1.38–4.95, p=0.003). `src/mr.R::meta_fixed`.
- **Narrative notebook** ✅ DONE: `report.Rmd` → `report.html` ties all phases into one document,
  reading the cached `results/*.csv` + forest PNGs (knits fast/offline; no re-run of plink/OpenGWAS).
  `code_folding: hide`, TOC. Token never enters the HTML (verified).
- **Multivariable MR** ⏳ NOT DONE (stretch): LDL + TG jointly for LPL/ANGPTL4 to separate pathways.

---

## Repo layout (proposed)
```
neuroprotective_lipid_genes/
  plan.md  research.md  ALZ-21-e70638.pdf
  renv.lock  (or sessionInfo dump)
  config.R                  # GENES/instruments, EXPOSURE, FINNGEN_REL, cis windows, LD/plink
  src/ download.R  exposure.R  outcome.R  mr.R  instruments.R  write_results.R
  run_phase1.R  run_phase2.R
  data/ glgc/  finngen/  ld/     (gitignored; cis extracts + 1000G EUR panel)
  results/                       # mr_phase{1,2}_*.csv, instruments_denovo.csv, forest*.png,
                                 #   endpoints.md, RESULTS.md
```

## Open questions to revisit (non-blocking; sensible defaults chosen)
1. **Cis-window flank** — 100 kb assumed for Phase-2 de-novo selection. Tighten (e.g. gene body only)
   or widen if a target yields too few/many SNPs? (Default: ±100 kb, documented.)
2. **FinnGen endpoint granularity** — use the exact FinnGen composite endpoints, or rebuild "all-cause
   dementia" from subtype endpoints ourselves? (Default: use FinnGen's own endpoints; confirm in Risteys.)
   *Resolved:* FinnGen's own endpoints were used, and all four of the paper's dementia endpoints are
   now in the grid. Rebuilding the composite ourselves is also possible from public files — every
   component is published (`F5_VASCDEM`, `F5_DEMNAS`, `G6_ALZHEIMER`, `F5_DEMINOTH`) — contrary to
   the note previously in `config.R`.
3. **PCSK9/CETP MVP SNPs** — the paper didn't name them, so Phase-1 uses §4's alternatives. Accept that
   these two are approximate until Phase 2 de-novo? (Default: yes, flagged in output.)
4. **Ambiguous-palindrome fallback** — drop them (default TwoSampleMR `action=2`), or attempt EAF-based
   resolution? For single-SNP targets a drop = losing the whole target. (Default: drop + loud log; revisit
   per-target if a key gene disappears.)
```
