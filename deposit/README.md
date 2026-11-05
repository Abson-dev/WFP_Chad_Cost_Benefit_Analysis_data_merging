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

## What happens to the 305 columns

All columns are accounted for in `900_variable_treatment.csv`.

| Treatment | Columns | Why |
|---|---|---|
| Removed | `Longitude`, `Latitude`, their precision, `village`, `DateDerniereAssist_other` | Coordinates point to households; villages make most households unique; free text can hold names |
| Replaced | `ID`, by the random `hh_key` | Direct identifier |
| Coarsened | `SvyDate` to year and month; `HHHAge` to 10-year bands; `HHSize` at 15; composition counts at 10 | The guide's rules, and rare values |
| Kept as merged | All others | |

The values are those of the merged file, including its known defects: see `902_known_issues.csv`. The script stops if an identifier reaches the package, or if a kept value differs from the merged file.

**The package is not cleared as anonymous.** Many households remain unique on combinations such as round, department, sex, age band and household size: see `910_disclosure_review.csv`. IFPRI's review may require coarser data.

## Steps to publication

1. Get WFP's written permission to publish.
2. Decide whether to fix the known defects first.
3. Complete the metadata in `SUBMISSION_NOTES_for_IFPRI_KM.md`, add the questionnaires as PDF and choose a licence.
4. Send the package to IFPRI's Knowledge Management team (IFPRI-Data@cgiar.org). They review it and flag identifying information; any corrections are the researchers' responsibility.
