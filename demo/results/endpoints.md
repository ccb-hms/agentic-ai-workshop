# FinnGen endpoint mapping (release R12, GRCh38)

Outcome endpoints used, mapped to the ICD definitions in [research.md](../research.md) §6.
Confirm phenocode definitions in Risteys: https://risteys.finregistry.fi/

| Our key | FinnGen phenocode | File | Outcome | ICD (research.md §6) | Phase |
|---|---|---|---|---|---|
| `dementia_all` | `F5_DEMENTIA` | `finngen_R12_F5_DEMENTIA.gz` | All-cause dementia (composite) | vascular + unspecified + AD + F02 + dementia drugs | 1 |
| `ihd` | `I9_IHD` | `finngen_R12_I9_IHD.gz` | Ischemic heart disease (**positive control**) | ICD-10 I20–I25 | 1 |
| `ad` | `G6_ALZHEIMER` | `finngen_R12_G6_ALZHEIMER.gz` | Alzheimer's disease | ICD-10 F00, G30 | 2 |
| `vascular` | `F5_VASCDEM` | `finngen_R12_F5_VASCDEM.gz` | Vascular dementia | ICD-10 F01 | 2 |
| `unspecified` | `F5_DEMNAS` | `finngen_R12_F5_DEMNAS.gz` | Unspecified dementia | ICD-10 F03; ICD-9 290, 2941 | 2 |

## Correction: unspecified dementia

An earlier version of this file recorded that unspecified dementia had "no clean standalone R12
public endpoint". **That was wrong**, and it is now included in the run. Enumerating all 2,489
endpoints in the R12 public `summary_stats` release turns up both missing components, and both
fetch without an application:

| Endpoint | File | Outcome | ICD |
|---|---|---|---|
| `F5_DEMNAS` | `finngen_R12_F5_DEMNAS.gz` | Unspecified dementia | ICD-10 F03; ICD-9 290, 2941; ICD-8 2900, 29019 |
| `F5_DEMINOTH` | `finngen_R12_F5_DEMINOTH.gz` | Dementia in other diseases | ICD-10 F02 |

`F5_DEMNAS` was confirmed in Risteys and matches research.md §6. The earlier miss looks like a
name-search false negative — `DEMNAS` matches neither "UNSPEC" nor "F03".

`F5_DEMINOTH` (F02) stays out: it is a component of the `dementia_all` composite, not one of the
four endpoints the paper reports separately.

With `unspecified` added, the Phase-2 grid is the paper's **four dementia endpoints + IHD**.

## Build note
GLGC exposure is **hg19**; FinnGen R12 outcome is **hg38**. We extract cis windows in each file's
own build (config.R `win_hg19` / `win_hg38`) and harmonize by **rsID + alleles**, so the coordinate
difference does not affect the MR estimate.
