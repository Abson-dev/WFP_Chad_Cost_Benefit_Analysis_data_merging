# Rebuilds the education and main activity of the head of household from the raw files, for do-file 25.
#
# Rmd 02 converts each round to label text and recodes the stacked rounds by exact label, so every answer whose
# label it did not expect became missing (issue "Education, main activity and income source answers lost in the
# harmonisation"):
#   - HHHEdu: "Supérieur" in the 2018 Baseline to the 2022 Annual (the rounds were relabelled "Superieur", without the
#     accent), and "Aucun", "1er cycle fondamentale" and "2e cycle fondamentale" in the 2023 PDM and 2023 Annual.
#   - HHHMainActivity: the 2019 Annual, 2020 Annual and 2021 PDM use an 11-category list ("Agriculture", "Elevage",
#     "Agriculture-Elevage"...) that the recode did not know; only "Autre" was kept.
#   - HHSourceIncome, 2019 Annual: the text "Vente des produits maraîchers" was matched with a trailing space, so its
#     115 answers became missing.
#
# Crosswalks, by the raw label (accents, case and spaces ignored). The script stops on a label it does not know.
#   HHHEdu, on the merged scale 1 Aucune, 2 Alphabétisé ou Coranique, 3 Primaire, 4 Secondaire, 5 Supérieur:
#     Aucun / Aucune Instruction -> 1; Coranique / Alphabétisé ou Coranique -> 2; Primaire, 1er and 2e cycle
#     fondamentale -> 3 (as Rmd 02 already does for the 2021 Annual to 2022 Annual); Secondaire, Secondaire 1er and
#     2e cycle -> 4; Supérieur -> 5.
#   HHHMainActivity keeps the 14 categories of the 2018 Baseline. The 11-category list does not map one to one: an
#     answer gets a detailed category only where it is unambiguous (Pêche -> 6, Artisanat/petit metier and
#     Maçon/Charpentier -> 9 Ouvrier/Artisan, Enseignant and Emploi salarial -> 10, Commerce de gros -> 11, Autre ->
#     14) and stays missing otherwise (Agriculture and Elevage do not say whether for consumption or for sale; Petit
#     commerce does not say whether food). "Pas autre" (2018 code 15) stays missing, as in Rmd 02.
#   HHHMainActivityGroup (new): 9 groups that both lists map to, for the four rounds that ask the question.
#   HHSourceIncome, 2019 Annual only: the text answers on the merged codes, as Rmd 02 maps them (maraîchers -> 3).
# Every answer the merged file already has must be rebuilt identically; do-file 25 checks this, so only lost answers
# are filled in.
#
# Output: WFP_Chad_fix_education_activity.dta in the module folder, one row per household of the merged file.

suppressMessages({ library(haven); library(readxl) })
DIR_INPUT <- Sys.getenv("WFP_INPUT_DIR", "C:/Users/AHema/OneDrive - CGIAR/Desktop/WFP Resilience dataset/data/input_data/Chad")
DIR_MODULES <- Sys.getenv("WFP_MODULES_DIR", "C:/Users/AHema/OneDrive - CGIAR/Desktop/WFP Resilience dataset/data/output_data/Chad")
DIR_MERGED <- Sys.getenv("WFP_MERGED_DIR", "C:/Users/AHema/OneDrive - CGIAR/Desktop/2024/WFP/CBA - Chad/data")
MERGED <- "WFP_Chad_2018-2023_20261116_v10.dta"

hv <- as.data.frame(read_excel(file.path(DIR_INPUT, "Chad_Harmonization.xlsx"), "variables_harmonization"))
de <- as.data.frame(read_excel(file.path(DIR_INPUT, "Chad_Harmonization.xlsx"), "description"))
x <- zap_labels(read_dta(file.path(DIR_MERGED, MERGED), col_select = c(ID, ROUND)))
ROUND_OF <- c(Chad_baseline_2018 = 1, Chad_ea_2019 = 2, Chad_pdm_2020 = 3, Chad_ea_2020 = 4, Chad_pdm_2021 = 5,
              Chad_ea_2021 = 6, Chad_pdm_2022 = 7, Chad_ea_2022 = 8, Chad_pdm_2023 = 9, Chad_ea_2023 = 10)
norm <- function(s) gsub("\\s+", " ", trimws(tolower(iconv(s, from = "UTF-8", to = "ASCII//TRANSLIT"))))

EDU <- c("aucun" = 1, "aucune instruction" = 1, "coranique" = 2, "alphabetise ou coranique" = 2,
         "primaire" = 3, "1er cycle fondamentale" = 3, "2e cycle fondamentale" = 3,
         "secondaire" = 4, "secondaire 1er cycle (6e a 3e)" = 4, "secondaire 2e cycle (1ere a tle)" = 4,
         "superieur" = 5)
EDU_LABELS <- c("Aucune" = 1, "Alphabétisé ou Coranique" = 2, "Primaire" = 3, "Secondaire" = 4, "Supérieur" = 5)

# The 14-category list: detailed code = raw code; group as below. "Pas autre" (15): missing.
GROUP_OF_14 <- c(1, 1, 2, 2, 5, 4, 5, 7, 7, 6, 5, 8, 8, 9)
# The 11-category list: detailed code (NA where ambiguous) and group.
ACT11 <- list("agriculture" = c(NA, 1), "elevage" = c(NA, 2), "agriculture-elevage" = c(NA, 3), "peche" = c(6, 4),
              "petit commerce" = c(NA, 5), "commerce de gros" = c(11, 5), "enseignant" = c(10, 6),
              "emploi salarial" = c(10, 6), "artisanat/petit metier" = c(9, 7), "macon/charpentier" = c(9, 7),
              "autre" = c(14, 9))
INCOME19 <- c("aides/dons et transfert d'argent" = 13, "artisanat/petits metiers" = 9, "autre a preciser" = 15,
              "commerce des produits alimentaires ou animaux (non produits par le menage lui-meme)" = 7,
              "petit commerce de produits non alimentaires" = 8, "vente de produits agricoles produits par le menage" = 1,
              "vente d'animaux ou produits d'elevage" = 4, "vente de produits de chasse/cueillette" = 6,
              "vente de produits de peche" = 5, "vente des produits maraichers" = 3, "travail journalier" = 10,
              "salaire/pension" = 11)
GROUP_LABELS <- c("Agriculture" = 1, "Élevage" = 2, "Agriculture et élevage" = 3, "Pêche/Chasse/cueillette" = 4,
                  "Commerce" = 5, "Fonctionnaire/salarié" = 6, "Artisan/Ouvrier/Journalier" = 7,
                  "Transferts/Aide/Mendicité" = 8, "Autre" = 9)

# The raw answer as label text: the value label of a code, or the text itself.
as_label <- function(z) {
  vl <- attr(z, "labels", exact = TRUE); raw <- zap_labels(z)
  if (is.character(raw)) return(ifelse(nzchar(trimws(raw)), raw, NA_character_))
  if (is.null(vl)) stop("no value labels", call. = FALSE)
  lab <- setNames(names(vl), vl)
  out <- unname(lab[as.character(raw)])
  if (any(!is.na(raw) & is.na(out))) stop("codes without a label: ", paste(unique(raw[!is.na(raw) & is.na(out)]), collapse = ", "), call. = FALSE)
  out
}
lookup <- function(lab, table, what, ds) {
  k <- norm(lab)
  unknown <- unique(lab[!is.na(k) & !k %in% names(table)])
  if (length(unknown)) stop(ds, " ", what, ": labels not in the crosswalk: ", paste(unknown, collapse = "; "), call. = FALSE)
  k
}

out <- data.frame(ID = x$ID, HHHEdu_fix = NA_real_, HHHMainActivity_fix = NA_real_, HHHMainActivityGroup = NA_real_,
                  HHSourceIncome_fix = NA_real_)
for (ds in names(ROUND_OF)) {
  s_edu <- hv[hv$NewVariable_Name == "HHHEdu", ds]; s_act <- hv[hv$NewVariable_Name == "HHHMainActivity", ds]
  if (is.na(s_edu) && is.na(s_act)) next
  r <- read_sav(file.path(DIR_INPUT, de$Data[de$Name == ds]))
  ids <- if (ds == "Chad_pdm_2022") as.character(seq_len(nrow(r))) else as.character(zap_labels(r[[hv[hv$NewVariable_Name == "ID", ds]]]))
  keep <- !duplicated(ids)                       # first occurrence, as in do-file 12
  here <- which(x$ROUND == ROUND_OF[[ds]])
  j <- match(as.character(x$ID[here]), ids[keep])
  if (anyNA(j)) stop(ds, ": ", sum(is.na(j)), " households of the merged file have no raw row.", call. = FALSE)
  if (!is.na(s_edu)) {
    lab <- as_label(r[[s_edu]])[keep][j]
    out$HHHEdu_fix[here] <- unname(EDU[lookup(lab, EDU, "HHHEdu", ds)])
  }
  if (!is.na(s_act)) {
    z <- r[[s_act]]
    lab <- as_label(z)[keep][j]
    k <- norm(lab)
    if (all(k[!is.na(k)] %in% names(ACT11))) {   # the 11-category list
      lookup(lab, ACT11, "HHHMainActivity", ds)
      out$HHHMainActivity_fix[here] <- vapply(k, function(a) if (is.na(a)) NA_real_ else ACT11[[a]][1], 0)
      out$HHHMainActivityGroup[here] <- vapply(k, function(a) if (is.na(a)) NA_real_ else ACT11[[a]][2], 0)
    } else {                                     # the 14-category list: check its labels, keep the codes
      vl <- attr(z, "labels", exact = TRUE)
      if (is.null(vl) || !all(1:15 %in% vl) || norm(names(vl)[vl == 15]) != "pas autre" || norm(names(vl)[vl == 1]) != "agriculture pour consommation")
        stop(ds, " HHHMainActivity: neither the 11- nor the 14-category list.", call. = FALSE)
      code <- as.numeric(zap_labels(z))[keep][j]
      code[code == 15] <- NA
      out$HHHMainActivity_fix[here] <- code
      out$HHHMainActivityGroup[here] <- GROUP_OF_14[code]
    }
  }
  if (ds == "Chad_ea_2019") {
    s <- hv[hv$NewVariable_Name == "HHSourceIncome", ds]
    lab <- as_label(r[[s]])[keep][j]
    k <- gsub("[ .?]+$", "", norm(lab))          # "Autre à préciser ……" ends in dots
    unknown <- unique(lab[!is.na(k) & !k %in% names(INCOME19)])
    if (length(unknown)) stop(ds, " HHSourceIncome: labels not in the crosswalk: ", paste(unknown, collapse = "; "), call. = FALSE)
    out$HHSourceIncome_fix[here] <- unname(INCOME19[k])
  }
  cat(sprintf("%-20s education %5d  activity %5d  group %5d\n", ds, sum(!is.na(out$HHHEdu_fix[here])),
              sum(!is.na(out$HHHMainActivity_fix[here])), sum(!is.na(out$HHHMainActivityGroup[here]))))
}

out$HHHEdu_fix <- labelled(out$HHHEdu_fix, EDU_LABELS, label = "HHHEdu rebuilt from the raw files")
out$HHHMainActivity_fix <- structure(out$HHHMainActivity_fix, label = "HHHMainActivity rebuilt from the raw files")
out$HHSourceIncome_fix <- structure(out$HHSourceIncome_fix, label = "HHSourceIncome rebuilt from the raw file (2019 Annual)")
out$HHHMainActivityGroup <- labelled(out$HHHMainActivityGroup, GROUP_LABELS,
                                     label = "Main activity of the head of household, grouped (comparable across rounds)")
write_dta(out, file.path(DIR_MODULES, "WFP_Chad_fix_education_activity.dta"))
cat("Written:", nrow(out), "households\n")
print(table(ROUND = x$ROUND, HHHEdu = as.numeric(out$HHHEdu_fix), useNA = "ifany"))
print(table(ROUND = x$ROUND, Group = as.numeric(out$HHHMainActivityGroup), useNA = "ifany"))
