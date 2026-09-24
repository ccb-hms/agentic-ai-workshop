# Reproducing a Mendelian randomization study with Claude Code

Material for a workshop on using Claude Code for biomedical data science.

The example project is a simplified reproduction of an *Alzheimer's & Dementia* paper
(`ALZ-21-e70638`, included here) — a Mendelian randomization study of whether lifelong,
genetically-proxied lipid lowering through six drug-target genes protects against dementia —
using only the data that can be downloaded without an application.

This reproduction serves as an example to demonstrate a framework to manage context and
improve project results. The framework has 4 phases that should be performed in seperate chat
sessions: **Research → Plan → Execute →
Reflect**, where Execute and Reflect loop are repeated as needed.

## The slides

`workshop/deck.html` — open it in a browser. Arrow keys or click to advance. 
It walks through the whole project: the prompts, and what Claude did in response.

## Repository layout

| | |
|---|---|
| `research.md` | what the Research phase pulled out of the paper |
| `plan.md` | the phased plan that came out of Plan phase |
| `src/`, `run_phase*.R` | the pipeline |
| `report.Rmd`, `report.html` | the write-ups |
| `results/`, `figure/` | outputs |
| `conversation.md` | every prompt, and what Claude did in response |

## Running the analysis

```bash
Rscript run_phase1.R    # 6 genes × {dementia, IHD}, curated instruments — the IHD positive control gate
Rscript run_phase2.R    # all 4 outcomes, sensitivity exposures, 5 estimators, de-novo instruments
Rscript run_phase3.R    # OpenGWAS AD extension + meta-analysis  (needs OPENGWAS_JWT)
Rscript -e 'rmarkdown::render("report.Rmd")'
```

Needs R with `TwoSampleMR`, `ieugwasr`, `data.table`, `ggplot2`; `tabix` (htslib); and for Phase 2's
de-novo step, the PLINK 1.9 binary from `genetics.binaRies`. `data/` is not committed — the pipeline
fetches its own cis-window extracts on first run (`src/download.R`), and the 1000G LD panel is ~1.5 GB.
