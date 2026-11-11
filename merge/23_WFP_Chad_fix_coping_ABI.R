# Builds the corrected coping (LCS) and ABI answers that do-file 23 puts into the merged file.
#
# The answers are taken again from the raw SPSS files, through the harmonisation workbook, and put on the merged
# file's scale (LhCSI: 1 No, no need; 2 No, already exhausted; 3 Yes; 4 Not applicable). Each round's raw codes
# are read with the meaning its own labels give:
#   - 2018 Baseline: 0 Non, 1 Oui, 2 already exhausted, 3 no need. Rmd 05 recoded 0 to Yes.
#   - 2020 PDM: 0 has no label and is read as No, as in 2018 (assumption, to confirm with the questionnaire).
#   - 2023 Annual: 1 Oui, 2 no need, 3 already exhausted. Rmd 05 left the codes unchanged, so "no need" counted as coping.
#   - LhCSIStress1 (selling non-productive assets): Rmd 05 set it to 4 (Not applicable) for every household in
#     9 rounds, although the raw files hold the answers. It is taken from the raw files in every round.
#   - 2019 Annual: its codes have no labels; they are left as merged (open issue "Unlabelled coping codes").
# ABI, 2022 Annual: the 7 score questions and ABITensions are coded 0/1 in the raw file, but carry the 1 Non /
# 2 Oui / 3 Ne sait pas labels of the file's other questions. Rmd 07 recoded 1 to 0, so every answer became 0.
# They are read as 0 No, 1 Yes (assumption: about 85% Yes, as in the other rounds; to confirm with the questionnaire).
#
# Output: WFP_Chad_fix_coping_ABI.dta in the module folder, one row per household of the merged file.
# The script stops if a household of the merged file has no raw row.

suppressMessages({ library(haven); library(readxl); library(dplyr) })
DIR_INPUT <- Sys.getenv("WFP_INPUT_DIR", "C:/Users/AHema/OneDrive - CGIAR/Desktop/WFP Resilience dataset/data/input_data/Chad")
DIR_MODULES <- Sys.getenv("WFP_MODULES_DIR", "C:/Users/AHema/OneDrive - CGIAR/Desktop/WFP Resilience dataset/data/output_data/Chad")
DIR_MERGED <- Sys.getenv("WFP_MERGED_DIR", "C:/Users/AHema/OneDrive - CGIAR/Desktop/2024/WFP/CBA - Chad/data")
MERGED <- "WFP_Chad_2018-2023_20261111_v8.dta"

hv <- as.data.frame(read_excel(file.path(DIR_INPUT, "Chad_Harmonization.xlsx"), "variables_harmonization"))
de <- as.data.frame(read_excel(file.path(DIR_INPUT, "Chad_Harmonization.xlsx"), "description"))
x <- zap_labels(read_dta(file.path(DIR_MERGED, MERGED), col_select = c(ID, ROUND)))
ROUND_OF <- c(Chad_baseline_2018 = 1, Chad_ea_2019 = 2, Chad_pdm_2020 = 3, Chad_ea_2020 = 4, Chad_pdm_2021 = 5,
              Chad_ea_2021 = 6, Chad_pdm_2022 = 7, Chad_ea_2022 = 8, Chad_pdm_2023 = 9, Chad_ea_2023 = 10)
source_of <- function(ds, v) { s <- hv[hv$NewVariable_Name == v, ds]; if (length(s) && !is.na(s)) s else NA_character_ }

LCS <- c(paste0("LhCSIStress", 1:4), paste0("LhCSICrisis", 1:3), paste0("LhCSIEmergency", 1:3))
# Raw code -> merged scale, from each round's value labels. Blank or unknown codes become 4 (Not applicable), as in Rmd 05.
LCS_SCALE <- list(
  `1` = c("0" = 1, "1" = 3, "2" = 2, "3" = 1, "4" = 4), `2` = c("1" = 1, "2" = 2, "3" = 3, "4" = 4),
  `3` = c("0" = 1, "1" = 3, "2" = 1, "3" = 2, "4" = 4), `4` = c("1" = 3, "2" = 1, "3" = 2, "4" = 4),
  `5` = c("1" = 3, "2" = 1, "3" = 2, "4" = 4), `6` = c("1" = 1, "2" = 2, "3" = 3, "4" = 4),
  `7` = c("1" = 1, "2" = 2, "3" = 3, "4" = 4), `8` = c("1" = 1, "2" = 2, "3" = 3, "4" = 4),
  `9` = c("1" = 1, "2" = 2, "3" = 3, "4" = 4), `10` = c("1" = 3, "2" = 1, "3" = 2, "4" = 4))
ABI <- c("ABIProteger", "ABIProduction", "ABIdifficultes", "ABIMarches", "ABIGererActifs", "ABIEnvironnement", "ABIutiliseractifs", "ABITensions")

out <- data.frame(ID = x$ID, ROUND = x$ROUND)
for (v in c(paste0(LCS, "_fix"), paste0(ABI, "_fix"))) out[[v]] <- NA_real_
for (ds in names(ROUND_OF)) {
  r <- read_sav(file.path(DIR_INPUT, de$Data[de$Name == ds]))
  ids <- if (ds == "Chad_pdm_2022") as.character(seq_len(nrow(r))) else as.character(zap_labels(r[[source_of(ds, "ID")]]))
  keep <- !duplicated(ids)                       # first occurrence, as in do-file 12
  here <- which(out$ROUND == ROUND_OF[[ds]])
  j <- match(out$ID[here], ids[keep])
  if (anyNA(j)) stop(ds, ": ", sum(is.na(j)), " households of the merged file have no raw row.", call. = FALSE)
  for (v in LCS) {
    s <- source_of(ds, v)
    if (is.na(s)) { out[[paste0(v, "_fix")]][here] <- 4; next }   # no source: Not applicable, as in Rmd 05
    raw <- as.character(zap_labels(r[[s]]))[keep][j]
    raw[!nzchar(trimws(raw))] <- NA
    z <- unname(LCS_SCALE[[as.character(ROUND_OF[[ds]])]][raw]); z[is.na(z)] <- 4
    out[[paste0(v, "_fix")]][here] <- z
  }
  if (ds == "Chad_ea_2022") for (v in ABI) {
    raw <- as.numeric(zap_labels(r[[source_of(ds, v)]]))[keep][j]
    if (!all(raw %in% c(0, 1, NA))) stop(v, ": codes other than 0/1 in the 2022 Annual.", call. = FALSE)
    out[[paste0(v, "_fix")]][here] <- raw
  }
}
for (v in paste0(LCS, "_fix")) {
  out[[v]] <- labelled(out[[v]], c("No, because I did not need to" = 1, "No, already sold or done and cannot continue" = 2, "Yes" = 3, "Not applicable" = 4),
                       label = paste("Corrected", sub("_fix", "", v), "(do-file 23)"))
}
for (v in paste0(ABI, "_fix")) out[[v]] <- labelled(out[[v]], c("Non" = 0, "Oui" = 1), label = paste("Corrected", sub("_fix", "", v), "(do-file 23; 2022 Annual only)"))
out$ROUND <- NULL
write_dta(out, file.path(DIR_MODULES, "WFP_Chad_fix_coping_ABI.dta"))
cat("Written:", nrow(out), "households,", ncol(out) - 1, "corrected variables\n")
