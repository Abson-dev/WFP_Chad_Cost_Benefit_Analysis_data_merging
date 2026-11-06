# Deposit in IFPRI Dataverse

This folder holds the script that prepares the merged data for [IFPRI Dataverse](https://dataverse.harvard.edu/dataverse/IFPRI), following [IFPRI's guide to publishing data](https://rdm.ifpri.info/guide-to-publishing-data/). The script does not upload or publish anything.

```bash
Rscript deposit/prepare_dataverse_package.R     # from the repository's root, after app/prepare_app_data.R
```

It writes outside this repository, next to the merged file:

| Folder | Content | Share? |
|---|---|---|
| `dataverse_deposit/` | Data files by module, README, codebook, treatment of each variable, known issues, disclosure review | With IFPRI's Knowledge Management team, once ready |
| `dataverse_deposit_private/` | Link between household keys and original IDs, and submission notes | **Keep the key file private.** The notes are for the submission |

## What happens to the 497 columns

The script reads `WFP_Chad_2018-2023_20261106_v4.dta`: the merged file with the modules added in November 2026. Shocks, assets and livestock, livelihoods and agriculture (`merge/16_WFP_Chad_add_new_modules.do`) are published as files 012 to 015; expenditure, disability, education and migration (`merge/17_WFP_Chad_add_more_modules.do`) as files 016 to 019; protection and accountability, and debt (`merge/18_WFP_Chad_add_protection_debt.do`) as files 020 and 021; social cohesion and climate adaptation (`merge/19_WFP_Chad_add_cohesion_adaptation.do`) as files 022 and 023. Nutrition (MAD, MDD-W) is not included: its link to households is broken in four rounds. All columns are accounted for in `900_variable_treatment.csv`.

| Treatment | Columns | Why |
|---|---|---|
| Removed (11) | `Longitude`, `Latitude`, their precision, `village`, `DateDerniereAssist_other`; the five 2018 baseline areas as reported (`AgrArea...Reported`) | Coordinates point to households; villages make most households unique; free text can hold names; the baseline areas mix units and reach millions (their hectare values are kept) |
| Replaced (1) | `ID`, by the random `hh_key` | Direct identifier |
| Coarsened (58) | `SvyDate` to year and month; `HHHAge` to 10-year bands; `HHSize` at 15; composition counts at 10; livestock counts, TLU, areas and expenditure at their 99.5th percentile; months of own production at 12; shocks in 5 years at 10; migrants at 10; girls at school at 5 | The guide's rules, rare values that identify households, and impossible values |
| Kept as merged (427) | All others | |

The values are those of the merged file, including its known defects: see `902_known_issues.csv`. The script stops if an identifier reaches the package, or if a kept value differs from the merged file.

**The package is not cleared as anonymous.** Many households remain unique on combinations such as round, department, sex, age band and household size: see `910_disclosure_review.csv`. IFPRI's review may require coarser data.

## Scope of the release

The project brief (`Project brief.docx`, kept with the data) sets out two products. This script builds only the start of the second one:

| Product | Content | Status |
|---|---|---|
| Layer 1: round-level datasets | 10 cleaned, labelled, anonymized files with every variable collected in each round | Not started |
| Layer 2: extended harmonized dataset | The harmonized file, plus shocks, assets, livelihoods, agriculture and nutrition modules matched across rounds | Harmonized file only |

The submission notes take the title, description and scope from the brief, and flag where the brief and the data differ: the brief lists 8 regions while the data hold 10, and it calls the data representative by region although the files hold no weights.

## Steps to publication

1. Get WFP's written permission to publish.
2. Decide whether to fix the known defects first.
3. Complete the metadata in `SUBMISSION_NOTES_for_IFPRI_KM.md`, add the questionnaires as PDF and choose a licence.
4. Send the package to IFPRI's Knowledge Management team (IFPRI-Data@cgiar.org). They review it and flag identifying information; any corrections are the researchers' responsibility.
