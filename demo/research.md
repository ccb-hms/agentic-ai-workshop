# Research notes: Reproducing "Cholesterol-lowering drug targets reduce risk of dementia"

Source paper: Nordestgaard LT, Hanson A, Sanderson E, et al. "Cholesterol-lowering drug
targets reduce risk of dementia: Mendelian randomization and meta-analyses of 1 million
individuals." *Alzheimer's & Dementia* 2025;21:e70638. DOI: 10.1002/alz.70638.
(File: `ALZ-21-e70638.pdf`)

These notes contain only the facts needed to ask a similar question and run similar
methods for a workshop tutorial. They do **not** aim for exact numerical replication.

---

## 1. Research question

Does genetically proxied lowering of non-HDL cholesterol via specific lipid-lowering
**drug-target genes** reduce the risk of dementia (all-cause dementia, Alzheimer's disease,
vascular dementia, unspecified dementia)? Ischemic heart disease (IHD) is used as a
**positive control** (a well-established effect of anti-atherogenic targets).

Because the genetic instruments proxy *lifelong* differences in exposure, the estimated
effect reflects the effect of lifelong lower non-HDL cholesterol on dementia risk.

Drug-target genes tested (6): **HMGCR** (statins), **NPC1L1** (ezetimibe),
**PCSK9** (alirocumab/evolocumab), **ANGPTL4**, **LPL**, **CETP**.

---

## 2. Which parts are reproducible with NO-request public data

The paper used 5 data sources. Only 2 are downloadable without an application/request:

| Source | Data level | Access | Reproducible without request? |
|---|---|---|---|
| CGPS + CCHS (Copenhagen) | individual-level | Danish law forbids public sharing | **No** |
| UK Biobank | individual-level | requires application | **No** |
| **FinnGen** | summary-level GWAS | free download | **Yes** |
| **GLGC** (Global Lipids Genetics Consortium) | summary-level GWAS | free download | **Yes** |

Consequence: the reproducible workshop path is the **two-sample Mendelian randomization
(2SMR) arm** only, using **GLGC as the exposure** (lipid GWAS) and **FinnGen as the
outcome** (dementia / AD / IHD GWAS). The Cox-regression and one-sample MR arms require
individual-level data and cannot be reproduced without a request.

Optional alternative/additional public outcome sources (not used by the paper but useful
for a workshop, all queryable via the `TwoSampleMR` R package / IEU OpenGWAS):
- Alzheimer's disease GWAS: Bellenguez 2022, Kunkle 2019, Lambert 2013, Jansen 2019.
- Lipid exposure GWAS are also mirrored in IEU OpenGWAS (GLGC ids).

---

## 3. Datasets and download locations

- **GLGC lipid GWAS summary statistics** (exposure): https://www.lipidgenetics.org/
  (paper's link: `https://www.lipidgenetics.org/#data-downloads-title`).
  - Traits available: non-HDL cholesterol, LDL cholesterol, HDL cholesterol,
    triglycerides, total cholesterol.
  - Use the **European-ancestry** results, **excluding UK Biobank** (the paper used the
    non-UKB dataset to avoid sample overlap).
  - Underlying GWAS: Graham et al. 2021 *Nature* (ref 34) and/or Willer et al. 2013
    *Nat Genet* (ref 23, n = 173,082 European).
- **FinnGen summary statistics** (outcome): https://www.finngen.fi/en/access_results
  - Summary-level results are free to download (no application needed).
  - Paper used release **F10 (2023-12-18)**, n = 412,181. Use the latest available
    release for the workshop.
  - Endpoint phenocodes/definitions: look up in Risteys (https://risteys.finregistry.fi/
    or https://risteys.finngen.fi/).
- Build note: paper used **genome build GRCh37 (hg19)**. Ensure exposure and outcome
  files are on the same build (lift over if needed) before harmonizing.

---

## 4. Drug-target genes: instruments

Instruments are **cis** variants located in/near each drug-target gene that are strongly
associated with the relevant lipid trait. Counts of variants used per gene in the paper:

| Gene | # variants | Chr (GRCh37) approx. region | rsIDs named in paper | Common alternative cis instruments |
|---|---|---|---|---|
| HMGCR | 1 | chr5 ~74.63–74.66 Mb | rs5909 | rs12916 |
| NPC1L1 | 1 | chr7 ~44.55–44.58 Mb | rs217434 | rs2073547 |
| PCSK9 | 3 | chr1 ~55.50–55.53 Mb | (not individually named) | rs11591147, rs2479409, rs11206510, rs562556 |
| ANGPTL4 | 1 | chr19 ~8.43–8.44 Mb | rs116843064 (E40K) | — |
| LPL | 1 | chr8 ~19.80–19.82 Mb | rs328 (S447X) | — |
| CETP | 3 | chr16 ~56.99–57.02 Mb | (not individually named) | rs3764261, rs1800775, rs247616 |

Instrument-selection rules used (reproducible version):
- Restrict to variants mapping to the drug-target gene (cis window, e.g. gene ± a fixed
  flank such as 100 kb — the paper selected variants that "map to the drug target genes").
- Strong association with the lipid trait in GLGC (paper's variants had GWAS-significant
  P-values, e.g. HMGCR P = 6×10⁻¹¹⁶, NPC1L1 P = 2×10⁻²⁰, PCSK9 down to 5×10⁻³²⁴).
- LD clumping to keep independent variants: **r² threshold ≤ 0.05** (variants with
  r² > 0.05 were treated as correlated and excluded from the restricted-variant analyses).
- **Instrument strength: F statistic > 10** required (all variants used exceeded this;
  reported F statistics in GLGC ranged ~62–661).
- Variants must not be discovered in the outcome sample (avoid winner's curse / overlap;
  FinnGen has no overlap with GLGC).

---

## 5. Exposure trait choice

- **Main analyses: non-HDL cholesterol** (= total cholesterol − HDL cholesterol). Chosen
  for comparability across all 6 targets because it captures atherogenic cholesterol in
  both LDL and triglyceride-rich lipoproteins.
- **Sensitivity analyses:** use the trait each target primarily acts on —
  - LDL cholesterol for HMGCR, NPC1L1, PCSK9, CETP;
  - triglycerides for ANGPTL4, LPL (log-transformed; effects scaled per *halving* of
    triglycerides because TG is not normally distributed: `log2_trig = ln(TRIG)/ln(2)`).
- HDL cholesterol is **not** used as an exposure for CETP (HDL not shown to be causal for
  atherosclerosis); LDL / non-HDL used instead.

---

## 6. Outcomes and definitions

Endpoints: **all-cause dementia**, **Alzheimer's disease (AD)**, **vascular dementia**,
**unspecified dementia**, and **IHD** (positive control).

ICD definitions used (map to FinnGen endpoints via Risteys):
- Vascular dementia: ICD-9 290.4; ICD-10 F01.
- Unspecified dementia: ICD-8 290.09/290.18/290.19; ICD-9 294.2; ICD-10 F03.
- AD: ICD-8 290; ICD-9 331.0; ICD-10 F00, G30.
- All-cause dementia (FinnGen): vascular + unspecified + AD + dementia in other diseases
  (ICD-10 F02) + use of anticholinesterases/dementia drugs (KELA reimb. code 307,
  ATC N06D).
- IHD (positive control): ICD-8/9 410–414; ICD-10 I20–I25 (includes MI: ICD-10 I21–I22).

FinnGen case counts (F10, for scale/power reference): all-cause dementia 19,157
(vascular 2,667; unspecified 4,408; AD 6,145); IHD 69,101. IHD is far better powered than
any single dementia subtype, which motivates its use as a positive control.

For a workshop, pick the matching FinnGen endpoint per outcome (e.g. AD-type,
vascular-dementia-type, all-dementia-type, IHD-type endpoints; confirm exact phenocode in
Risteys for the release you download).

---

## 7. Two-sample MR method (the reproducible arm)

Software: **R** (paper used R 4.1.0), package **`TwoSampleMR`**
(https://mrcieu.github.io/TwoSampleMR/), meta-analysis with the **`meta`** package
(fixed-effect models).

Per-target workflow:
1. **Extract exposure instruments** from GLGC for the target gene region (Section 4):
   effect allele, other allele, beta, SE, EAF, P.
2. **Extract the same variants from the FinnGen outcome** GWAS (beta/SE on log-odds
   scale, or OR).
3. **Harmonize** exposure and outcome on the same effect allele (align strands; drop
   ambiguous palindromic SNPs or resolve by EAF).
4. **Estimate the causal effect:**
   - If the target has **1 instrument** → **Wald ratio** (HMGCR, NPC1L1, ANGPTL4, LPL).
   - If the target has **≥3 instruments** → **weighted median** as the main method
     (PCSK9, CETP).
5. **Effect scaling:** two-sample MR estimates are reported **per 1 standard deviation
   (SD) lower non-HDL cholesterol** (note: the individual-level arms used per 1 mmol/L
   = 39 mg/dL; the 2SMR arm uses per-SD because GLGC betas are in SD units).
6. Report **odds ratio (OR)** and 95% CI for each outcome.

Sensitivity / assumption checks (for targets with ≥3 instruments):
- Additional estimators: **IVW**, **weighted mode**, **simple mode**, **MR-Egger**.
- **Pleiotropy:** MR-Egger intercept test (`mr_pleiotropy_test`); intercept ≈ 0 with
  P > 0.05 indicates little directional pleiotropy.
- **Heterogeneity:** Cochran's Q (`mr_heterogeneity`).
- **Assumption 1 (relevance):** F statistics per instrument (> 10).
- **Assumption 3 (exclusion restriction) falsification:** check association of each
  instrument with other lipids/apolipoproteins.

Meta-analysis: combine cohort-specific 2SMR estimates per outcome using fixed-effect
meta-analysis (`meta` package). For a public-only reproduction with a single outcome
source (FinnGen), meta-analysis across cohorts is optional/omitted.

---

## 8. Mendelian randomization assumptions (state in tutorial)

1. Instruments are strongly associated with the exposure (relevance) — tested via F stat.
2. No unmeasured confounders of instrument–outcome association (independence).
3. Instruments affect the outcome only through the exposure (exclusion restriction) —
   falsified via pleiotropy tests and lipid-association checks.

Rationale for cis drug-target instruments: selecting few, well-characterized variants
within the target gene minimizes pleiotropy and models the effect of pharmacologically
inhibiting that target.

---

## 9. Target results to compare against (two-sample MR arm)

Per 1 SD lower non-HDL cholesterol; OR (95% CI). These are the paper's meta-analyzed 2SMR
values (which also included UKB/Copenhagen), useful as a rough sanity check even though a
GLGC+FinnGen-only run will differ:

All-cause dementia:
- HMGCR (Wald): 0.59 (0.35–0.99)
- NPC1L1 (Wald): 0.43 (0.14–1.33)
- ANGPTL4 (Wald): 1.08 (0.50–2.32)
- LPL (Wald): 1.60 (1.01–2.55)
- PCSK9 (weighted median): 1.03 (0.90–1.17)
- CETP (weighted median): 0.54 (0.37–0.78)

IHD (positive control):
- HMGCR 0.41 (0.30–0.55); NPC1L1 0.65 (0.34–1.23); ANGPTL4 0.23 (0.15–0.36);
  LPL 0.48 (0.37–0.62); PCSK9 0.63 (0.58–0.68); CETP 0.49 (0.40–0.60)

Paper's headline conclusion: lifelong genetic lowering of non-HDL cholesterol via
**HMGCR, NPC1L1, and CETP** reduces all-cause dementia risk; an effect via PCSK9,
ANGPTL4, and LPL cannot be excluded. Effects were nominally larger for vascular and
unspecified dementia than for AD.

---

## 10. Minimal workshop reproduction plan

1. Download GLGC European (non-UKB) non-HDL (and LDL, TG) summary statistics.
2. Download a FinnGen release; identify AD, vascular-dementia, all-dementia, and IHD
   endpoint files.
3. In R, load `TwoSampleMR`.
4. For each of the 6 genes: pull cis instruments from GLGC (clump r² ≤ 0.05, F > 10),
   pull the same SNPs from each FinnGen outcome, harmonize.
5. Run Wald ratio (1-SNP genes) or weighted median (≥3-SNP genes); run IVW/Egger/mode
   as sensitivity for multi-SNP genes.
6. Tabulate ORs per SD lower non-HDL for each gene × outcome; confirm IHD shows the
   expected protective direction (positive control) before interpreting dementia results.
