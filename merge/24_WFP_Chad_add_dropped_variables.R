# Builds the 29 workbook variables that Rmds 01 to 11 and 20 dropped before the merge, for do-file 24.
#
# The harmonisation workbook maps each of them to a raw column, but the Rmds keep a fixed list of variables per
# module, so they never reached the merged file (issue "Workbook variables dropped before the merge"). They are read
# again from the raw SPSS files, through the workbook, for the households of the merged file, and put on the merged
# file's scales:
#   - RESPSex and ABISexparticipant: 1 Femme, 2 Homme, as HHHSex. The raw codes are 1 Masculin, 2 Féminin (2018
#     Baseline, 2020 Annual), 1 Femme, 2 Homme (2021 Annual to 2022 Annual) and 0 Femme, 1 Homme (2023).
#   - RESPConsent: 0 Non, 1 Oui. Raw: 1 accepte / 2 refus / 3 absence (2018), text Oui/Non (2019), 0/1 (2020, 2021,
#     2023), 1 Non / 2 Oui (2022).
#   - ExpFoodShareAnalysts: percent. The 2021 Annual gives a fraction; it is multiplied by 100.
#   - DebutAssistance: the date assistance started (2020 PDM, 2021 Annual to 2023 Annual; numbers are days since
#     1970, as Rmd 03 reads them). In the 2020 Annual the workbook maps it to a yes/no question already merged as
#     DateDerniereAssist and DistribVivresArgentSoudure: left out there (app/config/excluded_variables.csv).
#   - RESPAge, RelationWith_HHH, the savings and social capital questions: raw codes and labels, the same in every
#     round where they are asked (checked below).
#   - DestinationMigration, RaisonAccesServices, AutreRaisonEconomiques, Actifcreesrehabi, SCIPersAAiderCom: questions
#     with several answers, whose numeric codes stand for different combinations in each round. They are kept as text,
#     as answered: the label of the raw code (an option, or option numbers separated by spaces), or the raw text.
# Every raw code is checked against the round's value labels before it is recoded; the script stops on an unknown one.
#
# Output: WFP_Chad_dropped_variables.dta in the module folder, one row per household of the merged file.

suppressMessages({ library(haven); library(readxl); library(dplyr) })
DIR_INPUT <- Sys.getenv("WFP_INPUT_DIR", "C:/Users/AHema/OneDrive - CGIAR/Desktop/WFP Resilience dataset/data/input_data/Chad")
DIR_MODULES <- Sys.getenv("WFP_MODULES_DIR", "C:/Users/AHema/OneDrive - CGIAR/Desktop/WFP Resilience dataset/data/output_data/Chad")
DIR_MERGED <- Sys.getenv("WFP_MERGED_DIR", "C:/Users/AHema/OneDrive - CGIAR/Desktop/2024/WFP/CBA - Chad/data")
MERGED <- "WFP_Chad_2018-2023_20261111_v9.dta"

hv <- as.data.frame(read_excel(file.path(DIR_INPUT, "Chad_Harmonization.xlsx"), "variables_harmonization"))
ext <- as.data.frame(read_excel(file.path(DIR_INPUT, "Chad_Harmonization_extension.xlsx"), "variables_harmonization"))
de <- as.data.frame(read_excel(file.path(DIR_INPUT, "Chad_Harmonization.xlsx"), "description"))
x <- zap_labels(read_dta(file.path(DIR_MERGED, MERGED), col_select = c(ID, ROUND)))
ROUND_OF <- c(Chad_baseline_2018 = 1, Chad_ea_2019 = 2, Chad_pdm_2020 = 3, Chad_ea_2020 = 4, Chad_pdm_2021 = 5,
              Chad_ea_2021 = 6, Chad_pdm_2022 = 7, Chad_ea_2022 = 8, Chad_pdm_2023 = 9, Chad_ea_2023 = 10)
source_of <- function(ds, v) {
  tab <- if (v %in% ext$NewVariable_Name) ext else hv
  s <- tab[tab$NewVariable_Name == v, ds]
  if (length(s) && !is.na(s[1])) s[1] else NA_character_
}

YESNO <- c("Non" = 1, "Oui" = 2, "Ne sait pas" = 3, "Ne souhaite pas répondre" = 4)
# Target variables: kind, English label, and for coded ones the merged file's value labels.
SPEC <- list(
  RESPAge = list(kind = "number", label = "Age of the respondent (years)"),
  RESPSex = list(kind = "sex", label = "Sex of the respondent"),
  RelationWith_HHH = list(kind = "codes", label = "Respondent's relationship to the head of household"),
  RESPConsent = list(kind = "consent", label = "The respondent consented to the interview"),
  ExistGroupeEpargne = list(kind = "codes", label = "A savings group exists in the community"),
  MembreGroupeEpargne = list(kind = "codes", label = "A household member belongs to a savings group"),
  EpargnePieds = list(kind = "codes", label = "The household has savings in livestock"),
  EpargneAvantPam = list(kind = "codes", label = "The household saved before WFP's assistance"),
  EpargneSansPam = list(kind = "codes", label = "The household could save without WFP's assistance"),
  PossibilitePret = list(kind = "codes", label = "The household could borrow if needed"),
  AutreSourcePret = list(kind = "codes", label = "The household has another source of loans"),
  SCIAideAubesoin = list(kind = "codes", label = "Social capital: the household could get help when needed"),
  SCIAideDehorsCom = list(kind = "codes", label = "Social capital: who outside the community would help (0: no label)"),
  SCIAideIntraCom = list(kind = "codes", label = "Social capital: who in the community would help (0: no label)"),
  SCICapAideGvnmt = list(kind = "codes", label = "Social capital: the household could get help from the government"),
  SCIConMembreGvrnmt = list(kind = "codes", label = "Social capital: the household knows a government member"),
  SCIConMembreNGO = list(kind = "codes", label = "Social capital: the household knows an NGO member"),
  SCIEvolRessSociales = list(kind = "codes", label = "Social capital: change in social resources"),
  SCIPersAAiderCom = list(kind = "text", label = "Social capital: whom the household helps in the community (as answered)"),
  SCIPersAAiderEnDehorsCom = list(kind = "codes", label = "Social capital: who the household helps outside the community (0: no label)"),
  SCIPersConMembreGvrnmt = list(kind = "codes", label = "Social capital: who the government member known is"),
  SCIPersConMembreNGO = list(kind = "codes", label = "Social capital: who the NGO member known is"),
  DestinationMigration = list(kind = "text", label = "Migration: destination (as answered)"),
  RaisonAccesServices = list(kind = "text", label = "Migration: services sought (as answered)"),
  AutreRaisonEconomiques = list(kind = "text", label = "Migration: other economic reasons (as answered)"),
  ABISexparticipant = list(kind = "sex", label = "Asset benefit: sex of the participant in the asset work"),
  Actifcreesrehabi = list(kind = "text", label = "Asset benefit: assets created or rehabilitated (as answered)"),
  ExpFoodShareAnalysts = list(kind = "share", label = "Food expenditure share as computed by the analysts (%)"),
  DebutAssistance = list(kind = "date", label = "Date the household's assistance started")
)

# Raw sex codes -> 1 Femme, 2 Homme, from the round's labels.
sex_map <- function(vl) {
  lab <- tolower(iconv(names(vl), to = "ASCII//TRANSLIT"))
  fem <- vl[grepl("^fem", lab)]; mal <- vl[grepl("^hom|^masc", lab)]
  if (length(fem) != 1 || length(mal) != 1) stop("Sex labels not understood: ", paste(names(vl), collapse = ", "), call. = FALSE)
  setNames(c(1, 2), c(fem, mal))
}
consent_map <- function(vl) {
  lab <- tolower(iconv(names(vl), to = "ASCII//TRANSLIT"))
  yes <- vl[grepl("^oui|accepte", lab)]; no <- vl[grepl("^non|refus|absence", lab)]
  if (length(yes) != 1 || !length(no)) stop("Consent labels not understood: ", paste(names(vl), collapse = ", "), call. = FALSE)
  setNames(c(1, rep(0, length(no))), c(yes, no))
}

out <- data.frame(ID = x$ID, ROUND = x$ROUND)
for (v in names(SPEC)) out[[v]] <- switch(SPEC[[v]]$kind, text = NA_character_, date = as.Date(NA), NA_real_)
codes_seen <- list()
for (ds in names(ROUND_OF)) {
  r <- read_sav(file.path(DIR_INPUT, de$Data[de$Name == ds]))
  ids <- if (ds == "Chad_pdm_2022") as.character(seq_len(nrow(r))) else as.character(zap_labels(r[[source_of(ds, "ID")]]))
  keep <- !duplicated(ids)                       # first occurrence, as in do-file 12
  here <- which(out$ROUND == ROUND_OF[[ds]])
  j <- match(out$ID[here], ids[keep])
  if (anyNA(j)) stop(ds, ": ", sum(is.na(j)), " households of the merged file have no raw row.", call. = FALSE)
  for (v in names(SPEC)) {
    s <- source_of(ds, v)
    if (is.na(s) || (v == "DebutAssistance" && ds == "Chad_ea_2020")) next
    if (!s %in% names(r)) stop(ds, ": the workbook maps ", v, " to ", s, ", which is not in the raw file.", call. = FALSE)
    z <- r[[s]]; vl <- attr(z, "labels", exact = TRUE)
    raw <- zap_labels(z)[keep][j]
    kind <- SPEC[[v]]$kind
    if (kind == "date") {
      val <- if (inherits(z, "Date")) as.Date(z)[keep][j] else as.Date(suppressWarnings(as.numeric(raw)), origin = "1970-01-01")
      if (any(val < as.Date("2010-01-01") | val > as.Date("2024-12-31"), na.rm = TRUE))
        message(ds, " DebutAssistance: ", sum(val < as.Date("2010-01-01") | val > as.Date("2024-12-31"), na.rm = TRUE), " dates outside 2010-2024, kept as given")
    } else if (kind == "number") {
      val <- suppressWarnings(as.numeric(raw))
    } else if (kind == "share") {
      val <- suppressWarnings(as.numeric(raw)) * if (ds == "Chad_ea_2021") 100 else 1
    } else if (kind %in% c("sex", "consent")) {
      if (is.character(raw)) {           # 2019 Annual: Oui / Non as text
        t <- tolower(trimws(raw)); val <- ifelse(t == "oui", 1, ifelse(t == "non", 0, NA))
        if (any(nzchar(t) & !t %in% c("oui", "non") & !is.na(t))) stop(ds, " ", v, ": unknown text answers.", call. = FALSE)
      } else {
        m <- if (kind == "sex") sex_map(vl) else consent_map(vl)
        unknown <- setdiff(unique(raw[!is.na(raw)]), as.numeric(names(m)))
        if (length(unknown)) stop(ds, " ", v, ": codes without a label: ", paste(unknown, collapse = ", "), call. = FALSE)
        val <- unname(m[as.character(raw)])
      }
    } else if (kind == "codes") {
      val <- suppressWarnings(as.numeric(raw))
      codes_seen[[v]][[ds]] <- vl
    } else {                             # several answers: the label of the code, or the raw text
      if (is.character(raw)) {
        val <- ifelse(nzchar(trimws(raw)), trimws(raw), NA_character_)
      } else {
        lab <- if (is.null(vl)) character(0) else setNames(trimws(names(vl)), vl)
        val <- ifelse(is.na(raw), NA_character_, ifelse(as.character(raw) %in% names(lab), lab[as.character(raw)], as.character(raw)))
        val[!is.na(val) & !nzchar(val)] <- NA_character_      # a code whose label is empty: no answer
      }
    }
    out[[v]][here] <- val
  }
}

# Coded variables keep their raw codes: check that every round uses the same labels, and take them.
for (v in names(codes_seen)) {
  ls <- codes_seen[[v]]
  key <- vapply(ls, function(l) if (is.null(l)) "" else paste(paste0(l, "=", trimws(names(l))), collapse = "|"), "")
  if (length(unique(key)) > 1) stop(v, ": the value labels differ between rounds; recode before merging.", call. = FALSE)
  SPEC[[v]]$labels <- ls[[1]]
}

for (v in names(SPEC)) {
  sp <- SPEC[[v]]
  vl <- switch(sp$kind, sex = c("Femme" = 1, "Homme" = 2), consent = c("Non" = 0, "Oui" = 1),
               codes = { l <- sp$labels; if (is.null(l)) NULL else setNames(as.numeric(l), trimws(names(l))) }, NULL)
  vl <- vl[nzchar(names(vl))]
  out[[v]] <- if (is.null(vl) || !length(vl)) structure(out[[v]], label = sp$label) else labelled(out[[v]], vl, label = sp$label)
}
out$ROUND <- NULL
write_dta(out, file.path(DIR_MODULES, "WFP_Chad_dropped_variables.dta"))
cat("Written:", nrow(out), "households,", ncol(out) - 1, "variables\n")
print(sapply(out[-1], function(z) sum(!is.na(z) & (!is.character(z) | nzchar(z)))))
