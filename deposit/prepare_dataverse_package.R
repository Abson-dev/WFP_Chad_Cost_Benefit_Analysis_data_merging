# Build the package to submit to IFPRI Dataverse, following IFPRI's guide to publishing data
# (https://rdm.ifpri.info/guide-to-publishing-data/). From the repository's root:
#   Rscript deposit/prepare_dataverse_package.R
#
# Reads the merged file, read-only. Writes OUTSIDE the repository, so that household-level files can
# never be committed:
#   <data>/dataverse_deposit/          the package, for IFPRI's Knowledge Management (KM) team
#   <data>/dataverse_deposit_private/  link between household keys and original IDs: NEVER share
#
# Every one of the merged file's columns gets a treatment in 900_variable_treatment.csv. The script
# stops if an identifier reaches the package or if any kept value differs from the merged file.
# It does not upload or publish anything.

suppressPackageStartupMessages({ library(haven); library(dplyr); library(readr) })
if (!file.exists("app/config/issues.csv")) stop("Run this script from the repository's root.", call. = FALSE)

DIR_MERGED <- Sys.getenv("WFP_MERGED_DIR", "C:/Users/AHema/OneDrive - CGIAR/Desktop/2024/WFP/CBA - Chad/data")
FINAL_FILE <- "WFP_Chad_2018-2023_20261105.dta"
OUT <- file.path(DIR_MERGED, "dataverse_deposit")
PRIVATE <- file.path(DIR_MERGED, "dataverse_deposit_private")
dir.create(OUT, showWarnings = FALSE); dir.create(PRIVATE, showWarnings = FALSE)
if (normalizePath(OUT, mustWork = FALSE) == normalizePath(getwd(), mustWork = FALSE) || startsWith(normalizePath(OUT, winslash = "/"), normalizePath(getwd(), winslash = "/"))) stop("The package must stay outside the repository.", call. = FALSE)
unlink(list.files(OUT, full.names = TRUE))

x <- read_dta(file.path(DIR_MERGED, FINAL_FILE))
# exact = TRUE: without it, attr() falls back on "labels" for a column with no variable label.
get_label <- function(v) attr(v, "label", exact = TRUE)
# Original assistance answers without a label take the harmonised variable's, with their round.
for (v in names(x)) {
  base <- sub("[0-9]+$", "", v)
  if (is.null(get_label(x[[v]])) && base != v && base %in% names(x) && !is.null(get_label(x[[base]]))) {
    attr(x[[v]], "label") <- paste0(get_label(x[[base]]), " (original answer, round ", sub("^.*[^0-9]", "", v), ")")
  }
}
# Other columns with no label. ABItransferts stays without one: its meaning needs the questionnaire.
extra_labels <- c(
  IP_var = "Key of the Cadre Harmonise link: year, cycle and department code",
  p_phase1 = "Share of the department's population in Cadre Harmonise phase 1", p_phase2 = "Share of the department's population in Cadre Harmonise phase 2",
  p_phase3 = "Share of the department's population in Cadre Harmonise phase 3", p_phase35 = "Share of the department's population in Cadre Harmonise phases 3 to 5",
  ABIParticipation = get_label(x$HHFFAPart),
  DistribVivresArgentSoudure = "Lean-season food or cash distribution (combined item)", BlanketFeedingChildrenWomen = "Blanket feeding of children or women (combined item)",
  MAMMASChildrenMAMPLWomen = "Malnutrition treatment (combined item)", CantineScolaireBoursesAdo = "School feeding or scholarships (combined item)"
)
for (v in names(extra_labels)) if (is.null(get_label(x[[v]]))) attr(x[[v]], "label") <- extra_labels[[v]]
N <- nrow(x); ALL <- names(x)
x$ID <- as.character(x$ID)

# ---- Household key: random, kept stable between versions, unrelated to the original ID or row order ----
key_file <- file.path(PRIVATE, "CONFIDENTIAL_household_key_to_ID.csv")
keys <- if (file.exists(key_file)) read_csv(key_file, show_col_types = FALSE, col_types = "cc") else data.frame(ID = character(), hh_key = character())
new_ids <- setdiff(x$ID, keys$ID)
if (length(new_ids)) {
  used <- as.integer(sub("^H", "", keys$hh_key))
  pool <- setdiff(100000:999999, used)
  picks <- pool[order(as.integer(openssl::rand_num(length(pool)) * .Machine$integer.max))][seq_along(new_ids)]
  keys <- bind_rows(keys, data.frame(ID = new_ids, hh_key = paste0("H", picks)))
  write_csv(keys, key_file)
}
x$hh_key <- keys$hh_key[match(x$ID, keys$ID)]
stopifnot(!anyNA(x$hh_key), !anyDuplicated(x$hh_key))
attr(x$hh_key, "label") <- "Random household key, joins the files of this deposit"

# ---- What cannot be published as it is ------------------------------------------------------------
REMOVED <- c(
  Longitude = "Coordinates point to households: IFPRI's guide requires their removal.",
  Latitude = "Coordinates point to households: IFPRI's guide requires their removal.",
  Longitude_precision = "Comes with the coordinates.", Latitude_precision = "Comes with the coordinates.",
  village = "Village with age, sex and household size makes most households unique (see 910_disclosure_review.csv).",
  DateDerniereAssist_other = "Free text, which can hold names: 393 distinct entries, not reviewed one by one."
)
REPLACED <- c(ID = "Replaced by hh_key, a random key. The link to the original ID stays private.")
COARSENED <- c(
  SvyDate = "Interview date limited to year and month (SvyYearMonth), as IFPRI's guide requires.",
  HHHAge = "Age of the household head grouped in 10-year bands (HHHAge_group).",
  HHSize = "Top-coded at 15 members: rare sizes identify households, and values above 30 are errors."
)
COMPOSITION <- grep("^HHSize.+[MF]$", ALL, value = TRUE)
COARSENED[COMPOSITION] <- "Top-coded at 10 members: rare counts identify households, and some values are impossible."

x$SvyYearMonth <- format(as.Date(x$SvyDate), "%Y-%m")
attr(x$SvyYearMonth, "label") <- "Interview year and month"
age <- as.numeric(zap_labels(x$HHHAge))
x$HHHAge_group <- labelled(as.numeric(cut(age, c(-Inf, 19, 29, 39, 49, 59, 69, Inf), labels = FALSE)),
                           c("Under 20" = 1, "20-29" = 2, "30-39" = 3, "40-49" = 4, "50-59" = 5, "60-69" = 6, "70 or more" = 7),
                           label = "Age of the household head, in bands")
hhsize_raw <- as.numeric(zap_labels(x$HHSize))
top <- function(v, cap) { lab <- get_label(v); o <- pmin(as.numeric(zap_labels(v)), cap); attr(o, "label") <- paste0(lab, " (top-coded at ", cap, ")"); o }
x$HHSize <- top(x$HHSize, 15)
for (v in COMPOSITION) x[[v]] <- top(x[[v]], 10)

# ---- Files by module, as the guide asks. All join on hh_key ---------------------------------------
module_of <- function(v) {
  dplyr::case_when(
    v %in% c("YEAR", "SvyMonth", "SURVEY", "SvyYearMonth", "ADMIN0Name", "adm0_ocha", "ADMIN1Name", "adm1_ocha", "ADMIN2Name", "adm2_ocha") ~ "001_survey_geography",
    grepl("^(exercise|reference|adm[012]_name|adm[012]_pcod|chtype|population|phase|p_phase|IP_var)", v) ~ "002_cadre_harmonise",
    grepl("^HHRCS|^RCS|^SERS", v) ~ "008_resilience_sers_rcs",
    grepl("^ABI|^HHAsset|^HHFFA|^HHTraining|^HHWork|^Actif|^BeneficieEmploi|^TRavail", v) ~ "009_asset_benefit_abi",
    grepl("^HDDS", v) ~ "005_dietary_diversity_hdds",
    grepl("^HH", v) ~ "003_household",
    grepl("^FCS|^SCA$", v) ~ "004_food_consumption_fcs",
    grepl("^LhCSI|coping", v) ~ "006_livelihood_coping_lcs",
    grepl("^rCSI", v) ~ "007_reduced_coping_rcsi",
    grepl("[0-9](_q1[23])?$", v) ~ "011_assistance_original_answers",
    TRUE ~ "010_assistance_harmonised"
  )
}
KEYS <- c("hh_key", "ROUND")
published <- c(setdiff(ALL, c(names(REMOVED), names(REPLACED), "SvyDate", "HHHAge", "ROUND")), "SvyYearMonth", "HHHAge_group")
mods <- module_of(published)
# Random row order: the original order could point back to the source files.
ord <- order(x$hh_key)
files <- list()
for (m in sort(unique(mods))) {
  vars <- published[mods == m]
  d <- x[ord, c(KEYS, vars)]
  fn <- paste0(m, ".dta")
  write_dta(d, file.path(OUT, fn), version = 14)
  files[[m]] <- data.frame(file = fn, rows = nrow(d), variables = ncol(d))
}
files <- bind_rows(files)

# ---- Treatment of every column of the merged file -------------------------------------------------
var_label <- function(v) { l <- get_label(x[[v]]); if (is.null(l)) "" else trimws(gsub("\\s+", " ", gsub("<[^>]+>", " ", l[1]))) }
treatment <- data.frame(merged_variable = ALL, stringsAsFactors = FALSE) |>
  mutate(treatment = case_when(merged_variable %in% names(REMOVED) ~ "Removed", merged_variable %in% names(REPLACED) ~ "Replaced",
                               merged_variable %in% names(COARSENED) ~ "Coarsened", TRUE ~ "Kept as merged"),
         published_as = case_when(merged_variable == "ID" ~ "hh_key", merged_variable == "SvyDate" ~ "SvyYearMonth", merged_variable == "HHHAge" ~ "HHHAge_group",
                                  merged_variable %in% names(REMOVED) ~ "", TRUE ~ merged_variable),
         file = ifelse(merged_variable == "ROUND", "All files", ifelse(published_as %in% c("", "hh_key"), ifelse(published_as == "hh_key", "All files", ""), paste0(module_of(published_as), ".dta"))),
         reason = case_when(merged_variable %in% names(REMOVED) ~ unname(REMOVED[merged_variable]), merged_variable %in% names(REPLACED) ~ unname(REPLACED[merged_variable]),
                            merged_variable %in% names(COARSENED) ~ unname(COARSENED[merged_variable]), TRUE ~ ""))
write_csv(treatment, file.path(OUT, "900_variable_treatment.csv"), na = "")

# ---- Codebook ------------------------------------------------------------------------------------
DERIVED <- c(
  FCS = "Cereals x2 + pulses x3 + dairy x4 + protein x4 + vegetables x1 + fruit x1 + fat x0.5 + sugar x0.5, days in the last 7. Missing items count as 0.",
  FCSCat28 = "From FCS: Poor up to 28, Borderline up to 42, Acceptable above.", FCSCat21 = "From FCS: Poor up to 21, Borderline up to 35, Acceptable above.",
  rCSI = "Less preferred x1 + borrow x2 + meal number x1 + meal size x1 + adults x3, days in the last 7.",
  stress_coping_FS = "1 if any stress strategy is answered Yes or already exhausted.", crisis_coping_FS = "1 if any crisis strategy is answered Yes or already exhausted.",
  emergency_coping_FS = "1 if any emergency strategy is answered Yes or already exhausted.", Max_coping_behaviourFS = "Highest level of coping strategy adopted, from the 10 strategies.",
  RCS = "Mean of the 9 HHRCS statements, rescaled from 1-5 to 0-100.", RCSCat33 = "From RCS: low below 33, medium below 66, high from 66.",
  ABIScore = "Count of Yes among the 7 asset benefit questions. Don't know counts as 0.", HDDS_hema = "Count of the 12 food groups eaten in the last 24 hours, computed in Rmd 11.",
  SvyMonth = "Interview month, imputed to link with Cadre Harmonisé.", IP_var = "Year, cycle and department code: the key of the Cadre Harmonisé link.",
  hh_key = "Random household key. Joins the files of this deposit. Not linked to any published ID.", ROUND = "Survey round, 1 to 10.",
  SvyYearMonth = "Year and month of the interview date.", HHHAge_group = "HHHAge in bands."
)
flags <- read_csv("app/data/flags.csv", show_col_types = FALSE)
rnd <- zap_labels(x$ROUND)
codebook <- bind_rows(lapply(c(KEYS, published), function(v) {
  z <- x[[v]]; zz <- zap_labels(z); nm <- if (is.character(zz)) !is.na(zz) & nzchar(trimws(zz)) else !is.na(zz)
  l <- attr(z, "labels")
  data.frame(file = if (v %in% KEYS) "All files" else paste0(module_of(v), ".dta"), variable = v, label = var_label(v),
             type = if (is.character(zz)) "text" else "number",
             value_labels = if (is.null(l)) NA_character_ else trimws(gsub("<[^>]+>", " ", paste(paste0(l, " = ", names(l)), collapse = "; "))),
             rounds_with_data = paste(sort(unique(rnd[nm])), collapse = " "), answered = sum(nm), missing = sum(!nm),
             minimum = if (is.numeric(zz) && any(nm)) min(zz[nm]) else NA, maximum = if (is.numeric(zz) && any(nm)) max(zz[nm]) else NA,
             derivation = if (v %in% names(DERIVED)) DERIVED[[v]] else NA_character_, stringsAsFactors = FALSE)
}))
write_csv(codebook, file.path(OUT, "901_codebook.csv"), na = "")
write_csv(read_csv("app/config/issues.csv", show_col_types = FALSE), file.path(OUT, "902_known_issues.csv"), na = "")

# ---- Disclosure review ---------------------------------------------------------------------------
xz <- zap_labels(x)
review <- function(name, vars, note) {
  k <- do.call(paste, c(lapply(vars, function(v) as.character(xz[[v]])), sep = "|")); t <- table(k)
  data.frame(what_someone_might_know = name, in_package = note, unique_households = sum(t == 1), households_in_groups_under_5 = sum(t[t < 5]), pct_under_5 = round(100 * sum(t[t < 5]) / N, 1))
}
disclosure <- bind_rows(
  review("Round, village, sex, exact age", c("ROUND", "village", "HHHSex", "HHHAge"), "No"),
  review("Round, department, sex, exact age", c("ROUND", "ADMIN2Name", "HHHSex", "HHHAge"), "No"),
  review("Round, department, sex, age band, top-coded size", c("ROUND", "ADMIN2Name", "HHHSex", "HHHAge_group", "HHSize"), "Yes"),
  review("Round, region, sex, age band, top-coded size", c("ROUND", "ADMIN1Name", "HHHSex", "HHHAge_group", "HHSize"), "Yes"),
  review("Round, department, sex, age band, size, education, marital status", c("ROUND", "ADMIN2Name", "HHHSex", "HHHAge_group", "HHSize", "HHHEdu", "HHHMatrimonial"), "Yes")
)
small <- as.data.frame(table(round = xz$ROUND, department = xz$adm2_ocha), stringsAsFactors = FALSE) |> filter(Freq > 0, Freq < 30)
write_csv(disclosure, file.path(OUT, "910_disclosure_review.csv"))

# ---- Documents for the Knowledge Management team --------------------------------------------------
rounds <- read_csv("app/data/rounds.csv", show_col_types = FALSE)
geo <- paste(sort(unique(as.character(xz$ADMIN1Name))), collapse = ", ")
writeLines(enc2utf8(c(
  "WFP Chad resilience household surveys, merged dataset, 2018-2023: public-use files",
  "",
  sprintf("%s households, 10 survey rounds, %d data files that join on hh_key. ROUND is in every file.", format(N, big.mark = ","), nrow(files)),
  "",
  "IMPORTANT",
  "- These files keep the values of the merged file, including known defects that change results in several rounds.",
  "  Read 902_known_issues.csv before any analysis. Main ones: emergency coping in rounds 1, 3 and 10; FCS in round 3; ABI in round 8.",
  "- There are no sampling weights. Figures describe the households surveyed in WFP programme areas, not a population.",
  "- Lean-season (PDM) and post-harvest (baseline, annual) rounds differ systematically: compare within a series.",
  "- Regions covered change between rounds.",
  "",
  "ROUNDS",
  sprintf("  %2d  %-14s %-14s %6s households", rounds$round, rounds$label, rounds$series, format(rounds$final_rows, big.mark = ",")),
  "",
  "FILES",
  sprintf("  %-40s %6d rows %4d variables", files$file, files$rows, files$variables),
  "  900_variable_treatment.csv               what happened to each of the merged file's columns",
  "  901_codebook.csv                         labels, values, coverage, derivation of each variable",
  "  902_known_issues.csv                     issues found in the merged data, and what to do",
  "  910_disclosure_review.csv                re-identification review",
  "",
  "TO PROTECT RESPONDENTS",
  sprintf("  Removed: %s.", paste(names(REMOVED), collapse = ", ")),
  "  Replaced: ID, by a random key (hh_key).",
  "  Coarsened: interview date to year and month; head's age to 10-year bands; household size at 15; composition counts at 10.",
  "",
  "SOURCE CODE",
  "  https://github.com/Abson-dev/WFP_Chad_Cost_Benefit_Analysis_data_merging",
  "",
  "CODES",
  "  Empty cells are missing. Some assistance and ABI questions use 888 for Don't know: see the value labels in the codebook."
)), file.path(OUT, "000_README.txt"), useBytes = TRUE)

meta <- c(
  "# Submission notes for IFPRI Knowledge Management (not part of the published files)",
  "",
  "Contact from IFPRI's guide: IFPRI-Data@cgiar.org",
  "",
  "## Metadata required by the guide",
  "",
  "| Element | Draft | Status |",
  "|---|---|---|",
  "| Title | WFP Chad resilience household surveys, merged dataset, 2018-2023 | To confirm |",
  "| Authors | International Food Policy Research Institute (IFPRI), as the guide requires; outside co-authors with affiliations | **Author to confirm co-authors** |",
  "| Contributors | Aboubacar Hema (data merging) | **To complete** |",
  sprintf("| Description | Merged data from 10 household survey rounds on WFP resilience interventions in Chad: %s households, %d published variables on food consumption, coping, dietary diversity, asset benefits, resilience capacity, assistance and Cadre Harmonise phases. | To confirm |", format(N, big.mark = ","), length(published) + 2),
  "| Funder (grant number) | Raw file names mention BMZ | **Author to provide** |",
  "| Sample and sampling procedure | Not documented in these files | **Author to provide** |",
  sprintf("| Time period | %s to %s | To confirm |", rounds$year[1], rounds$year[nrow(rounds)]),
  sprintf("| Date of collection | %s to %s (1st to 99th percentile of interview dates) | To confirm |", min(rounds$date_p01), max(rounds$date_p99)),
  "| Geographic coverage | Chad |  |",
  sprintf("| Geographic unit | Region and department. Regions: %s | To confirm |", geo),
  "| Universe | Households in WFP resilience programme areas of the surveys | **Author to confirm** |",
  "| Unit of analysis | Household |  |",
  "| Producer | **To confirm: WFP Chad for data collection, IFPRI for merging** | **Author to provide** |",
  "| Production place | **To confirm** | **Author to provide** |",
  "",
  "## Still needed before submission",
  "",
  "1. **WFP's written permission** to publish: the surveys are WFP's.",
  "2. **Questionnaires as PDF:** required by the guide. Convert from `Questionnaires WFP Chad.zip` and the RBD standardized questionnaires on the author's computer.",
  "3. **A licence** for reuse, as the guide asks.",
  "4. **A decision on the known defects:** publish version 1 with them documented, or fix the pipeline first.",
  "",
  "## For the Knowledge Management team to review",
  "",
  sprintf("- **Re-identification risk remains:** on round, department, sex, age band and household size, %.1f%% of households are in groups under 5. Decide whether department, household size or the composition counts need coarsening. See `910_disclosure_review.csv`.", disclosure$pct_under_5[3]),
  "- `ABItransferts` has no label: its meaning needs the questionnaire.",
  sprintf("- %d round and department cells have fewer than 30 households.", nrow(small)),
  "- Whether the removed columns can be offered under restricted access. The guide does not describe this option.",
  "- `Montant` (cash amount received) is kept as merged, but could be rare in some places.",
  "- The guide advises files by module and non-proprietary formats. Files are Stata, to keep the labels; it says Dataverse converts them."
)
writeLines(enc2utf8(meta), file.path(PRIVATE, "SUBMISSION_NOTES_for_IFPRI_KM.md"), useBytes = TRUE)

# ---- Checks: the script stops rather than leave an unsafe or wrong package --------------------------
source_all <- read_dta(file.path(DIR_MERGED, FINAL_FILE))
src <- zap_labels(source_all); src$ID <- as.character(src$ID)
src_key <- keys$hh_key[match(src$ID, keys$ID)]
dta <- list.files(OUT, "\\.dta$", full.names = TRUE)
seen <- character(); forbidden <- c("ID", names(REMOVED), "SvyDate", "HHHAge")
for (f in dta) {
  d <- read_dta(f); dz <- zap_labels(d)
  if (any(forbidden %in% names(d))) stop("Identifier in ", f, call. = FALSE)
  if (nrow(d) != N || anyDuplicated(d$hh_key)) stop("Rows wrong in ", f, call. = FALSE)
  if (is.unsorted(d$hh_key)) stop("Row order not randomised in ", f, call. = FALSE)
  j <- match(dz$hh_key, src_key)
  for (v in setdiff(names(d), c(KEYS, "SvyYearMonth", "HHHAge_group", "HHSize", COMPOSITION))) {
    a <- dz[[v]]; b <- src[[v]][j]
    if (is.character(a)) { a[is.na(a)] <- ""; b[is.na(b)] <- ""; same <- all(a == b) } else same <- isTRUE(all.equal(as.numeric(a), as.numeric(b), tolerance = 1e-6))
    if (!same) stop("Value differs from the merged file: ", v, call. = FALSE)
  }
  seen <- c(seen, setdiff(names(d), KEYS))
  all_text <- unlist(lapply(d[vapply(d, is.character, TRUE)], unique))
  if (any(unique(as.character(src$ID)) %in% all_text)) stop("Original ID in ", f, call. = FALSE)
  villages <- setdiff(unique(src$village), c("", NA, "UNKNOWN"))
  if (any(villages %in% all_text[!all_text %in% unique(c(src$ADMIN1Name, src$ADMIN2Name, src$adm1_name, src$adm2_name))])) stop("Village name in ", f, call. = FALSE)
}
if (anyDuplicated(seen)) stop("A variable is in two files: ", paste(seen[duplicated(seen)], collapse = ", "), call. = FALSE)
if (!setequal(seen, published)) stop("Published variables do not match the plan.", call. = FALSE)
if (!setequal(treatment$merged_variable, ALL) || nrow(treatment) != length(ALL)) stop("Not all columns have a treatment.", call. = FALSE)
if (any(grepl("[ ]", list.files(OUT)))) stop("Spaces in file names.", call. = FALSE)
if (any(grepl(paste0("(^|[^0-9])(", paste(head(src$ID[nchar(src$ID) >= 7], 200), collapse = "|"), ")([^0-9]|$)"), c(readLines(file.path(OUT, "000_README.txt"), warn = FALSE))))) stop("ID in the README.", call. = FALSE)

cat("\nPublished variables with no label:", sum(codebook$label == ""), ":", paste(codebook$variable[codebook$label == ""], collapse = ", "), "\n")
cat("\nPackage:", OUT, "\n")
print(as.data.frame(files), row.names = FALSE)
cat("\nTreatment of the", length(ALL), "merged columns:\n"); print(table(treatment$treatment))
cat("\nHousehold-level rows checked against the merged file: all kept values identical.\n\nDisclosure review:\n")
print(as.data.frame(disclosure), row.names = FALSE)
cat("\nSmall department x round cells:", nrow(small), "\nPackage size MB:", round(sum(file.size(list.files(OUT, full.names = TRUE))) / 1e6, 1), "\n")
