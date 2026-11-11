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
# The merged file with the modules added in November 2026: shocks, assets, livelihoods and agriculture
# (merge/16), expenditure, disability, education and migration (merge/17), protection and debt (merge/18),
# social cohesion and climate adaptation (merge/19), shock impact, programme effects, markets, accountability and
# additions to earlier modules (merge/20), and the costs per household (merge/21, built by the scripts of costs/)
FINAL_FILE <- "WFP_Chad_2018-2023_20261111_v8.dta"
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
# 2018 baseline areas as reported: units mixed (hectares, square metres, cordes) and values up to millions.
# The hectare values are published in the AgrArea variables, and the units in the AgrArea...Unit variables.
for (v in grep("^AgrArea.+Reported$", ALL, value = TRUE)) REMOVED[v] <- "2018 baseline value in mixed units, with extreme values that identify households. The hectare values are in the variable without 'Reported'."
# Costs per household (merge/21): the village totals are unique to each village and year, so they would point to the
# village, which is removed. They stay in the merged file.
for (v in grep("^cost_vill_", ALL, value = TRUE)) REMOVED[v] <- "Village cost totals: unique to each village and year, they would point to the household's village, which is removed. Kept in the merged file."
REPLACED <- c(ID = "Replaced by hh_key, a random key. The link to the original ID stays private.")
COARSENED <- c(
  SvyDate = "Interview date limited to year and month (SvyYearMonth), as IFPRI's guide requires.",
  HHHAge = "Age of the household head grouped in 10-year bands (HHHAge_group).",
  HHSize = "Top-coded at 15 members: rare sizes identify households, and values above 30 are errors."
)
COMPOSITION <- grep("^HHSize.+[MF]$", ALL, value = TRUE)
COARSENED[COMPOSITION] <- "Top-coded at 10 members: rare counts identify households, and some values are impossible."
# New modules (November 2026): large herds and farms identify households, and the largest values are errors.
# Livestock, TLU and areas are top-coded at their 99.5th percentile, rounded up.
CAPS <- c()
for (v in c(grep("^Lvs(Cattle|Sheep|Goats|Poultry|Camels|Horses|Donkeys|Pigs|TLU)$", ALL, value = TRUE), grep("^AgrArea[A-Za-z]+$", setdiff(ALL, names(REMOVED)), value = TRUE))) {
  if (grepl("Unit$", v)) next
  CAPS[v] <- ceiling(quantile(as.numeric(zap_labels(x[[v]])), 0.995, na.rm = TRUE))
  COARSENED[v] <- sprintf("Top-coded at %s, the 99.5th percentile: very large %s identify households, and the largest values are errors.", CAPS[[v]], if (startsWith(v, "Lvs")) "herds" else "areas")
}
CAPS["AgrMonthsOwnProduction"] <- 12
COARSENED["AgrMonthsOwnProduction"] <- "Top-coded at 12 months: values reach 300,000 and are errors."
for (v in grep("^Shk5yN_", ALL, value = TRUE)) { CAPS[v] <- 10; COARSENED[v] <- "Top-coded at 10 times: values reach 211 in 5 years and are errors." }
for (v in grep("^Exp(Food|NonFoodShort|NonFoodLong|Total)Monthly$", ALL, value = TRUE)) {
  CAPS[v] <- ceiling(quantile(as.numeric(zap_labels(x[[v]])), 0.995, na.rm = TRUE) / 1000) * 1000
  COARSENED[v] <- sprintf("Top-coded at %s XAF, the 99.5th percentile rounded up: very high spending identifies households. The food share is computed before top-coding.", format(CAPS[[v]], big.mark = ","))
}
# Crops (Rmd 33): areas, quantities, losses and sales income have rare very large values that identify farms, and some are errors.
for (v in grep("^CrpArea_|^CrpHarvest_[A-Z]|^CrpSold_[A-Z]|^CrpPostHarvestLoss$|^CrpSalesIncome$", ALL, value = TRUE)) {
  q <- quantile(as.numeric(zap_labels(x[[v]])), 0.995, na.rm = TRUE)
  CAPS[v] <- if (v == "CrpSalesIncome") ceiling(q / 1000) * 1000 else ceiling(q)
  COARSENED[v] <- sprintf("Top-coded at %s%s, the 99.5th percentile rounded up: very large farms, harvests and sales identify households, and the largest values are errors.", format(CAPS[[v]], big.mark = ","), if (v == "CrpSalesIncome") " XAF" else "")
}
CAPS["MigNumber"] <- 10
COARSENED["MigNumber"] <- "Top-coded at 10 migrants: larger numbers are rare and identify households."
for (v in grep("^EduGirls(Primary|Secondary)(Supported)?$|^EduGirlsSupportedPast$", ALL, value = TRUE)) {
  CAPS[v] <- 5
  COARSENED[v] <- "Top-coded at 5 girls: larger numbers are rare, and values up to 30,000 are amounts entered by mistake."
}
# Costs per household. Community costs are the same for every household of a village and year, so they would point
# to the village: they are replaced by the mean of the household's department, round and participation group (the
# department is published). Asset types follow, so they still add up. Costs that grow with the number of children are
# top-coded at their 99.5th percentile, as rare counts identify households. Totals are recomputed from the published parts.
COMM_COSTS <- c("cost_comm_transfer_xaf", "cost_comm_capacity_xaf", grep("^cost_asset_", ALL, value = TRUE))
for (v in COMM_COSTS) COARSENED[v] <- "Village amounts replaced by the mean of the department, round and participation group (participants in cash for assets or not): the exact amount would point to the household's village, which is removed."
for (v in intersect(c("cost_blanket_children_xaf", "cost_blanket_combined_xaf", "cost_school_meals_xaf", "cost_school_combined_xaf"), ALL)) {
  CAPS[v] <- ceiling(quantile(as.numeric(zap_labels(x[[v]])), 0.995, na.rm = TRUE) / 1000) * 1000
  COARSENED[v] <- sprintf("Top-coded at %s XAF, the 99.5th percentile rounded up: the cost grows with the number of children, and rare counts identify households.", format(CAPS[[v]], big.mark = ","))
}
for (v in intersect(c("cost_interv_xaf", "cost_interv_usd", "cost_total_xaf"), ALL)) COARSENED[v] <- "Recomputed from the published parts (community costs averaged, child-based costs top-coded)."
cost_as_merged <- as.data.frame(zap_labels(x[, intersect(c("ROUND", "adm2_ocha", "village", "HHHSex", "HHSize", COMM_COSTS), names(x))]))

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
for (v in names(CAPS)) x[[v]] <- top(x[[v]], CAPS[[v]])
if (length(COMM_COSTS)) {
  g <- paste(zap_labels(x$ROUND), x$adm2_ocha, zap_labels(x$cost_comm_transfer_xaf) > 0, zap_labels(x$cost_comm_source) %in% c(1, 2))
  for (v in COMM_COSTS) {
    lab <- get_label(x[[v]]); z <- as.numeric(zap_labels(x[[v]]))
    m <- ave(z, g, FUN = function(a) if (all(is.na(a))) NA_real_ else mean(a, na.rm = TRUE))
    x[[v]] <- round(ifelse(is.na(z), NA, m), 2); attr(x[[v]], "label") <- paste0(lab, " (mean of department, round and participation)")
  }
  usd_items <- intersect(grep("^cost_(lean|blanket|mam|farn|school)", ALL, value = TRUE), ALL)
  items <- intersect(c(usd_items, "cost_bursary_xaf"), ALL)
  fx <- read_csv("costs/exchange_rates.csv", show_col_types = FALSE)
  rate_of <- fx$xaf_per_usd[match(zap_labels(x$YEAR), fx$year)]
  relabel <- function(v, value) { lab <- get_label(x[[v]]); o <- value; attr(o, "label") <- lab; o }
  x$cost_interv_xaf <- relabel("cost_interv_xaf", round(rowSums(as.data.frame(lapply(items, function(v) as.numeric(zap_labels(x[[v]])))), na.rm = TRUE), 2))
  x$cost_interv_xaf[is.na(zap_labels(x$cost_comm_source))] <- NA
  x$cost_total_xaf <- relabel("cost_total_xaf", round(as.numeric(x$cost_comm_transfer_xaf) + as.numeric(x$cost_comm_capacity_xaf) + as.numeric(x$cost_interv_xaf), 2))
  x$cost_interv_usd <- relabel("cost_interv_usd", round(rowSums(as.data.frame(lapply(usd_items, function(v) as.numeric(zap_labels(x[[v]])))), na.rm = TRUE) / rate_of, 2))
  x$cost_interv_usd[is.na(zap_labels(x$cost_comm_source))] <- NA
}

# ---- Files by module, as the guide asks. All join on hh_key ---------------------------------------
module_of <- function(v) {
  dplyr::case_when(
    grepl("^ShkImp|^ShkRec", v) ~ "024_shock_impact_recovery",
    grepl("^Eff[A-Z]", v) ~ "025_programme_effects",
    grepl("^Mkt[A-Z]", v) ~ "026_markets",
    grepl("^Fsn[A-Z]", v) ~ "027_food_shortage_2018_2021",
    grepl("^cost_", v) ~ "028_costs",
    grepl("^Crp[A-Z]", v) ~ "029_crops",
    grepl("^Fsr[A-Z]", v) ~ "030_food_sources",
    grepl("^Shk", v) ~ "012_shocks",
    grepl("^Ast|^Lvs", v) ~ "013_assets_livestock",
    grepl("^Liv[A-Z]", v) ~ "014_livelihoods",
    grepl("^Agr[A-Z]", v) ~ "015_agriculture",
    grepl("^Exp[A-Z]", v) ~ "016_expenditure",
    grepl("^Dis[A-Z]", v) ~ "017_disability",
    grepl("^Edu[A-Z]", v) ~ "018_education",
    grepl("^Mig[A-Z]", v) ~ "019_migration",
    grepl("^Prt[A-Z]|^Aap[A-Z]", v) ~ "020_protection_accountability",
    grepl("^Dbt[A-Z]", v) ~ "021_debt",
    grepl("^Coh[A-Z]", v) ~ "022_social_cohesion",
    grepl("^Adp[A-Z]", v) ~ "023_climate_adaptation",
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
  FCS = "Cereals x2 + pulses x3 + dairy x4 + protein x4 + vegetables x1 + fruit x1 + fat x0.5 + sugar x0.5, days in the last 7. Missing items count as 0. Round 3 (2020 PDM) takes the analysts' SCA instead, as its main food groups were recorded as 0/1 flags and are left empty.",
  FCSCat28 = "From FCS: Poor up to 28, Borderline up to 42, Acceptable above.", FCSCat21 = "From FCS: Poor up to 21, Borderline up to 35, Acceptable above.",
  rCSI = "Less preferred x1 + borrow x2 + meal number x1 + meal size x1 + adults x3, days in the last 7.",
  stress_coping_FS = "1 if any stress strategy is answered Yes or already exhausted.", crisis_coping_FS = "1 if any crisis strategy is answered Yes or already exhausted.",
  emergency_coping_FS = "1 if any emergency strategy is answered Yes or already exhausted.", Max_coping_behaviourFS = "Highest level of coping strategy adopted, from the 10 strategies.",
  RCS = "Mean of the 9 HHRCS statements, rescaled from 1-5 to 0-100.", RCSCat33 = "From RCS: low below 33, medium below 66, high from 66.",
  ABIScore = "Count of Yes among the 7 asset benefit questions. Don't know counts as 0.", HDDS_hema = "Count of the 12 food groups eaten in the last 24 hours, computed in Rmd 11.",
  SvyMonth = "Interview month, imputed to link with Cadre Harmonisé.", IP_var = "Year, cycle and department code: the key of the Cadre Harmonisé link.",
  hh_key = "Random household key. Joins the files of this deposit. Not linked to any published ID.", ROUND = "Survey round, 1 to 10.",
  SvyYearMonth = "Year and month of the interview date.", HHHAge_group = "HHHAge in bands.",
  ShkCount12m = "Count of the 17 shocks answered Yes for the last 12 months (Rmd 16).",
  ShkAny12m = "1 if any of the 17 shocks is answered Yes for the last 12 months (Rmd 16).",
  AstCount = "Count of the durable goods owned. The lists differ between rounds, so counts compare only within a round (Rmd 17).",
  LvsTLU = "Camels x1 + cattle x0.7 + horses x0.8 + donkeys x0.5 + pigs x0.2 + sheep and goats x0.1 + poultry x0.01, from the counts before top-coding (Rmd 17).",
  LivIncomeSource1 = "2019 to 2021 PDM: 13-source list recoded to the 15-source list of later rounds; 2019 text answers matched to codes (Rmd 18).",
  AgrAreaCultivated = "2022 and 2023: no unit recorded, taken as hectares. 2018 baseline: kept only where the unit is hectares or the area is 0 (Rmd 19). Same rule for the other AgrArea variables.",
  AgrMonthsOwnProduction = "From 2021 the question refers to the last harvest; before, to a usual year (Rmd 19).",
  ExpFoodMonthly = "The analysts' monthly total in the raw file (Rmd 20). Same for the two non-food totals.",
  ExpTotalMonthly = "Food + short-term non-food + long-term non-food, before top-coding (Rmd 20).",
  ExpFoodShare = "Food / total monthly expenditure, before top-coding. Agrees with the analysts' share in more than 99% of households (Rmd 20).",
  ExpFoodShareCat = "From ExpFoodShare: below 50%, 50-65%, 65-75%, 75% or more (Rmd 20).",
  DisCognition = "Stored as difficultes_entendre in the raw files except the 2023 PDM (difficultes_cognitive); the 2023 label confirms it asks about remembering or concentrating (Rmd 21).",
  DisAny = "1 if any of the six domains is 'a lot of difficulty' or 'cannot do at all', the Washington Group cut-off (Rmd 21).",
  MigMainReason = "2021 and 2022 codes shifted by an empty first code: matched to the 2023 list by label (Rmd 23). Same for MigDuration.",
  MigWork12m = "2021 and 2022: 1 No, 2 Yes, 3 Don't know; recoded to 0, 1, 888 as in 2023 (Rmd 23).",
  PrtAnyProblem = "1 if any of the safety, access, site or other problem questions is Yes (Rmd 24).",
  PrtAccessProblem = "2022 annual survey: 168 answers coded 3 or 4, which have no label, set to missing (Rmd 24).",
  AapInformed = "1 if the household knows why it was selected, what it is entitled to and the distribution cycle, WFP's accountability indicator (Rmd 24).",
  AapComplaintFiled = "Asked in 2020 annual and from 2022; the 2019 annual and 2021 PDM ask about 'the complaint' without asking whether one was filed, so they are left out of the complaint questions (Rmd 24).",
  DbtUsedForFood = "Code 1 (food) among the answers of a multiple-choice question; 2022 annual stores combinations as codes and is left out (Rmd 25).",
  DbtReasonHealth = "Matched by label: item 2 in 2021 annual, item 3 from 2022 (Rmd 25).",
  CohTensionsReduced = "Same question as ABITensions, asked again in the cohesion section; the two answers agree for about three households in four (Rmd 26).",
  AdpKnowCount = "Number of the four techniques (soil conservation, crop rotation, destocking, pasture) the household knows (Rmd 27).",
  AdpApplyAny = "1 if the household applies at least one of the four techniques; 0 also when it knows none, as it was not asked (Rmd 27).",
  MktDaysPerWeek = "Values above 7 (62 households, up to 100,000) set to missing (Rmd 30).",
  AapDecideAssistanceUse = "Continues AapDecideAssistance (2019-2021) with the 2022-2023 wording (Rmd 31).",
  PrtSafetyLevel = "2022 annual: 19 answers coded 4, which has no label, set to missing (Rmd 31).",
  FsnNotEnoughFood30d = "Text in 2019, 0/1 elsewhere (Rmd 32). Same for FsnMalnourishedChild and DisMemberDisabled.",
  DbtSavingsGroup = "The analysts' variable in the raw files, kept as computed (Rmd 32).",
  MigReasonIncrease = "2021 and 2022 codes shifted by an empty first code: matched to the 2023 list by label (Rmd 32). Same for MigReasonDecrease."
)
for (v in grep("^ShkImp|^ShkRec", ALL, value = TRUE)) DERIVED[v] <- "Located by position after each shock's 12-month question, as 2021 annual names some after another shock. Answers kept only where the shock happened in the last 12 months (removes 1,133 to 1,351 answers per question for theft and death in 2021 annual). Impact: don't know 888, refusals missing (Rmd 28)."
for (v in grep("^EffDirection_", ALL, value = TRUE)) DERIVED[v] <- "Asked only for the areas the household selected in the matching EffChanged variable (Rmd 29)."
for (v in grep("^Mkt(AccessDifficult|SoldProduce)$|^Aap(AssistanceReceived3m|Satisfied|KnowHowSelected|ToldEntitlement|ToldProgrammeEnd|KnowHowToContact|TreatedWithRespect|DignifiedSites)$", ALL, value = TRUE)) DERIVED[v] <- "1 No, 2 Yes in 2022 and 0/1 in 2023: recoded to 0 = No, 1 = Yes (Rmds 30 and 31)."
for (v in c("CrpHarvestUnit", "CrpSoldUnit")) DERIVED[v] <- "One unit per household for all crops. Codes put on one list; the 2022 annual codes carry area labels and are kept apart (71 to 73). Non-kg codes look unreliable: compare quantities in kg only (Rmd 33)."
for (v in grep("^CrpArea_|^CrpPostHarvestLoss$", ALL, value = TRUE)) DERIVED[v] <- "No unit recorded in any round. Negative values set to missing (Rmd 33). Not comparable with the AgrArea variables."
for (v in grep("^CrpHarvest_[A-Z]|^CrpSold_[A-Z]", ALL, value = TRUE)) DERIVED[v] <- "As reported, in the unit of CrpHarvestUnit or CrpSoldUnit, never converted. 567 households sell more kg of a crop than they harvested (Rmd 33)."
DERIVED["CrpGardeningMonths"] <- "Values above 12 (264 households, up to 2,000,000) and negative values set to missing (Rmd 33)."
DERIVED["CrpMonthsOwnProdUsual"] <- "Months own production usually covers after a season; a different question from AgrMonthsOwnProduction (last harvest). Do not pool (Rmd 33)."
for (v in grep("^Fsr", ALL, value = TRUE)) DERIVED[v] <- "1 No, 2 Yes in 2022 and 0/1 in 2023: recoded to 0 = No, 1 = Yes. Source questions asked only of households that ate the food group; tubers asked of the cereal households (Rmd 34)."
for (v in grep("^CohInteract", ALL, value = TRUE)) DERIVED[v] <- "2021 and 2022: 1 No, 2 Yes, 3 Don't know; recoded to 0, 1, 888 as in 2023 (Rmd 26)."
for (v in grep("^Adp(Know|Apply|Trained|Processing)", ALL, value = TRUE)) if (!v %in% names(DERIVED)) DERIVED[v] <- "1 Yes, 2 No, 3 Don't know recoded to 1, 0, 888; unlabelled codes 4 and 5 of 2021 annual set to missing (Rmd 27)."
for (v in grep("^(Prt|Aap)", ALL, value = TRUE)) if (!v %in% names(DERIVED)) DERIVED[v] <- "Text in 2019, 0/1 in 2020, 2021 and 2023, 1/2 in 2022: recoded to one scale. From 2022 asked mostly of households that received assistance (Rmd 24)."
for (v in grep("^Dis(Seeing|Hearing|Walking|SelfCare|Communication)$", ALL, value = TRUE)) DERIVED[v] <- "Refused (5) and don't know (6) set to missing (Rmd 21)."
for (v in grep("^Edu(Girls|Boys).+Complete$", ALL, value = TRUE)) DERIVED[v] <- "1 Yes, 2 No, 3 Don't know recoded to 1, 0, 888; codes outside the list (0 in 2022 annual, 4-5 in 2021 annual) set to missing (Rmd 22)."
cost_rules <- read_csv("costs/cost_variables.csv", show_col_types = FALSE)
for (i in seq_len(nrow(cost_rules))) if (cost_rules$variable[i] %in% ALL) DERIVED[cost_rules$variable[i]] <- paste0(cost_rules$rule[i], " Source: ", cost_rules$source[i], ". See costs/README.md.")
for (v in grep("^Shk12m_", ALL, value = TRUE)) DERIVED[v] <- "Asked only when the shock happened in the last 5 years: set to No when the 5-year count is 0 (Rmd 16)."
for (v in grep("^Lvs(Cattle|Sheep|Goats|Poultry|Camels|Horses|Donkeys)$", ALL, value = TRUE)) DERIVED[v] <- "2018 baseline and 2022-2023: adult animals only. 2019 to 2021: all animals; set to 0 when the household does not raise livestock (Rmd 17)."
for (v in c("AstCart", "AstPlough", "AstBicycle", "AstPushcart", "AstMotorbike")) DERIVED[v] <- "2018 baseline asked the number: owned when above 0 (Rmd 17)."
DERIVED[c("AstBed", "AstMattress")] <- "2018 baseline: from one question on beds with or without a mattress (Rmd 17)."
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
  review("Round, department, sex, age band, size, education, marital status", c("ROUND", "ADMIN2Name", "HHHSex", "HHHAge_group", "HHSize", "HHHEdu", "HHHMatrimonial"), "Yes"),
  review("Round, department, sex, age band, top-coded size, top-coded cattle and camels", c("ROUND", "ADMIN2Name", "HHHSex", "HHHAge_group", "HHSize", "LvsCattle", "LvsCamels"), "Yes")
)
# Community costs: as merged they single out the village; as published (department means) they do not.
if (length(COMM_COSTS)) {
  one_village <- function(cost) {
    k <- paste(cost_as_merged$ROUND, cost_as_merged$adm2_ocha, cost)
    nv <- tapply(cost_as_merged$village, k, function(v) length(unique(v)))
    villages_dept <- tapply(cost_as_merged$village, paste(cost_as_merged$ROUND, cost_as_merged$adm2_ocha), function(v) length(unique(v)))
    sel <- !is.na(cost) & cost > 0
    # Share of households whose cost narrows their department and round down to one village, where it has several.
    round(100 * mean((nv[k] == 1 & villages_dept[paste(cost_as_merged$ROUND, cost_as_merged$adm2_ocha)] > 1)[sel]), 1)
  }
  disclosure <- bind_rows(disclosure, data.frame(
    what_someone_might_know = c("Round, department, community capacity cost as merged: households whose cost singles out one village of several", "The same, with the cost as published (department mean)"),
    in_package = c("No", "Yes"), unique_households = NA, households_in_groups_under_5 = NA,
    pct_under_5 = c(one_village(cost_as_merged$cost_comm_capacity_xaf), one_village(as.numeric(zap_labels(x$cost_comm_capacity_xaf))))))
}
small <- as.data.frame(table(round = xz$ROUND, department = xz$adm2_ocha), stringsAsFactors = FALSE) |> filter(Freq > 0, Freq < 30)
write_csv(disclosure, file.path(OUT, "910_disclosure_review.csv"))

# ---- Documents for the Knowledge Management team --------------------------------------------------
rounds <- read_csv("app/data/rounds.csv", show_col_types = FALSE)
geo <- paste(sort(unique(as.character(xz$ADMIN1Name))), collapse = ", ")
# Description, scope and release structure follow the project brief (Project brief.docx, kept with the data, not here).
BRIEF_REGIONS <- c("Barh-El-Gazel", "Batha", "Guera", "Kanem", "Lac", "Ouaddai", "Sila", "Wadi Fira")
not_in_brief <- table(as.character(xz$ADMIN1Name))[setdiff(unique(as.character(xz$ADMIN1Name)), BRIEF_REGIONS)]
not_in_brief_txt <- paste(sprintf("%s (%s households)", names(not_in_brief), format(as.integer(not_in_brief), big.mark = ",")), collapse = " and ")
writeLines(enc2utf8(c(
  "WFP Chad Integrated Resilience Programme household survey data, 2018-2023: harmonized dataset, public-use files",
  "",
  sprintf("%s households, 10 survey rounds, %d data files that join on hh_key. ROUND is in every file.", format(N, big.mark = ","), nrow(files)),
  "",
  "ABOUT",
  "  Household surveys of the World Food Programme's Integrated Resilience Programme in Chad: the 2018 baseline,",
  "  annual outcome surveys from 2019 to 2023, and post-distribution monitoring (PDM) rounds from 2020 to 2023.",
  "  The rounds used changing questionnaires and variable names. They were mapped to a common structure,",
  "  administrative codes were matched to OCHA subnational boundaries, and comparable WFP food-security and",
  "  resilience indicators were computed: FCS, rCSI, LCS, ABI, SERS and HDDS. The files also hold household",
  "  demographics, assistance received and the Cadre Harmonise phase of each household's area, and modules on",
  "  shocks, durable goods and livestock, livelihoods (income sources), agriculture (land, areas, own production),",
  "  expenditure (monthly totals and food share), disability (Washington Group questions), education, migration,",
  "  protection and accountability to affected populations, decisions within the household, debt, social cohesion,",
  "  climate adaptation practices, the impact of shocks and recovery from them, changes credited to the programme,",
  "  markets, crop production and sales (029_crops; quantities as reported, units unreliable), and the sources of the",
  "  food eaten (030_food_sources). 028_costs.dta holds the cost of WFP's assistance per household (2019 to 2023), in XAF: community costs",
  "  of cash for assets and the assets built (by asset type), the household-level interventions it reports, and the",
  "  costs of its department, from WFP's cost data and IFPRI's cost templates.",
  "  The harmonized data were first built for IFPRI's 2026 cost-benefit analysis of the programme.",
  "",
  "IMPORTANT",
  "- These files keep the values of the merged file, including known defects that change results in several rounds.",
  "  Read 902_known_issues.csv before any analysis. Main ones: emergency coping in rounds 1, 3 and 10; ABI in round 8.",
  "- There are no sampling weights. Figures describe the households surveyed in WFP programme areas, not a population.",
  "- Lean-season (PDM) and post-harvest (baseline, annual) rounds differ systematically: compare within a series.",
  "- Regions covered change between rounds.",
  "- Expenditure, disability and migration were asked from the 2021 annual survey only; education changed in 2021.",
  "- The shocks, assets, livelihoods and agriculture modules were not asked in every round, and some questions changed:",
  "  see rounds_with_data and derivation in 901_codebook.csv. Shocks have two designs (17 shocks over 12 months and",
  "  5 years in 2021-2023; the main shock of the last 6 months from the 2022 PDM). Livestock counts are of adult animals",
  "  in 2018 and 2022-2023, and of all animals in 2019-2021. Areas of 2022-2023 have no recorded unit: taken as hectares.",
  "- Child (MAD) and women's (MDD-W) diet data are not included: their link to households is broken in four rounds.",
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
  "  Coarsened: interview date to year and month; head's age to 10-year bands; household size at 15; composition counts at 10;",
  "  livestock counts, TLU, areas and expenditure at their 99.5th percentile; months of own production at 12;",
  "  shocks in 5 years at 10; migrants at 10; girls at school at 5; crop areas, harvests, sales, losses and sales income",
  "  at their 99.5th percentile.",
  "  Costs: village cost totals removed; community costs per household replaced by the mean of the department, round and",
  "  participation group; costs that grow with the number of children top-coded at their 99.5th percentile.",
  "  Removed too: the 2018 baseline areas in mixed units (the hectare values are kept).",
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
  "The description, scope and release structure follow the project brief (`Project brief.docx`), which IFPRI funded under",
  "Open and FAIR Data (Digital Transformation). The data must be public by 31 December 2026.",
  "",
  "## Metadata required by the guide",
  "",
  "| Element | Draft | Status |",
  "|---|---|---|",
  "| Title | WFP Chad Integrated Resilience Programme household survey data, 2018-2023 | From the brief; to confirm |",
  "| Authors | International Food Policy Research Institute (IFPRI), as the guide requires; outside co-authors with affiliations | **Author to confirm co-authors** |",
  "| Contributors | Aboubacar Hema (data merging) | **To complete** |",
  sprintf("| Description | Household survey data from the World Food Programme's Integrated Resilience Programme in Chad: the 2018 baseline, annual outcome surveys from 2019 to 2023 and post-distribution monitoring rounds from 2020 to 2023, with %s households across 10 rounds. The rounds were mapped to a common structure, administrative codes matched to OCHA subnational boundaries, and comparable WFP indicators computed: Food Consumption Score, reduced Coping Strategy Index, Livelihood Coping Strategies, Asset Benefit Indicator, Self-Evaluated Resilience Score and Household Dietary Diversity Score, with household demographics, assistance received and the Cadre Harmonise phase of each household's area. Modules on shocks, durable goods and livestock, income sources, agriculture, expenditure, disability, education, migration, protection and accountability, debt, social cohesion, climate adaptation, shock impact and recovery, programme effects, markets, crop production and sales, and the sources of the food eaten are matched across the rounds that asked them. The data were first harmonized for IFPRI's 2026 cost-benefit analysis of the programme. | From the brief; to confirm |", format(N, big.mark = ",")),
  "| Keywords | Chad; food security; resilience; World Food Programme; household survey; Food Consumption Score; coping strategies; dietary diversity; Cadre Harmonise; humanitarian assistance | To confirm |",
  "| Related publication | IFPRI (2026). Cost-benefit analysis of WFP's integrated resilience programme in Chad (2018-2023) | **Author to add the citation** |",
  "| Funder (grant number) | Release: IFPRI, Open and FAIR Data under Digital Transformation (USD 16,000; cost center to come). Data collection: raw file names mention BMZ | **Author to provide grant numbers** |",
  "| Sample and sampling procedure | The brief says the data are representative at region (Admin 1) level within the programme areas, not nationally. The files hold no weights and no sampling documentation; some rounds have about 40 households per region | **WFP to document the sampling and weights** |",
  sprintf("| Time period | %s to %s | To confirm |", rounds$year[1], rounds$year[nrow(rounds)]),
  sprintf("| Date of collection | %s to %s (1st to 99th percentile of interview dates) | To confirm |", min(rounds$date_p01), max(rounds$date_p99)),
  "| Geographic coverage | Chad: WFP programme areas |  |",
  sprintf("| Geographic unit | Region and department. Regions: %s | **The brief lists 8 regions. The data also hold %s** |", geo, not_in_brief_txt),
  "| Universe | Households in WFP Integrated Resilience Programme areas | **Author to confirm** |",
  "| Unit of analysis | Household. Individual-level diet files exist for women (MDD-W) and children aged 6-23 months (MAD), 2021 to 2023, but are not in this package |  |",
  "| Kind of data | Survey data |  |",
  "| Producer | **To confirm: WFP Chad for data collection, IFPRI for harmonization** | **Author to provide** |",
  "| Production place | **To confirm** | **Author to provide** |",
  "| Licence | The brief asks for a suitable licence; CGIAR's open-access policy usually uses CC BY 4.0 | **Author to choose** |",
  "",
  "## Release structure in the brief, and where this package stands",
  "",
  "| Product | Brief | This package |",
  "|---|---|---|",
  "| Layer 1: round-level datasets | 10 cleaned, labelled and anonymized files with all variables collected in each round (about 6,288 variables) | **Not started** |",
  sprintf("| Layer 2: extended harmonized dataset | The existing harmonized file plus priority modules matched across rounds: shocks, assets, livelihoods, agriculture, nutrition | **Built except nutrition:** %d variables in %d modules, with shocks, assets and livestock, livelihoods, agriculture, expenditure, disability, education, migration, protection and accountability, debt, social cohesion, climate adaptation, shock impact and recovery, programme effects, markets, crop production and sales, and food sources added, and the costs per household (`028_costs.dta`). Nutrition (MAD, MDD-W) left out: its link to households is broken in four rounds |", length(published) + 2, nrow(files)),
  "| Codebook and variable metadata | Complete | Layer 2 only: `901_codebook.csv`, `900_variable_treatment.csv` |",
  "| Harmonization and indicator methods | Documented | In the source code and its report; the codebook gives each derived variable's formula |",
  "| Sampling and weights | Documented | **Missing** |",
  "| Disclosure review | Completed | **Started:** `910_disclosure_review.csv`; not cleared |",
  "| Quality assurance | Senior researcher review | **To do**; known defects in `902_known_issues.csv` |",
  "| Data Paper | If funding allows | Not started |",
  "",
  "## Still needed before submission",
  "",
  "1. **WFP's written permission** to publish: the surveys are WFP's.",
  "2. **Questionnaires as PDF:** required by the guide. Convert from `Questionnaires WFP Chad.zip` and the RBD standardized questionnaires on the author's computer.",
  "3. **A licence** for reuse, as the guide asks.",
  "4. **A decision on the known defects:** publish version 1 with them documented, or fix the pipeline first.",
  "5. **Layer 1 and the Layer 2 extension**, as the brief commits to them, or an agreed narrower first release.",
  "6. **Sampling and weight documentation** from WFP, to support the brief's claim of regional representativeness.",
  "",
  "## For the Knowledge Management team to review",
  "",
  sprintf("- **Re-identification risk remains:** on round, department, sex, age band and household size, %.1f%% of households are in groups under 5. Decide whether department, household size or the composition counts need coarsening. See `910_disclosure_review.csv`.", disclosure$pct_under_5[3]),
  "- `ABItransferts` has no label: its meaning needs the questionnaire.",
  sprintf("- %d round and department cells have fewer than 30 households.", nrow(small)),
  "- Whether the removed columns can be offered under restricted access. The guide does not describe this option; the brief asks that data which cannot be open go through the restricted-access process, with a discoverable metadata record.",
  "- `Montant` (cash amount received) is kept as merged, but could be rare in some places.",
  sprintf("- **Costs per household:** community costs as merged single out the village for %.1f%% of households with a cost; as published (department means) for %.1f%%. Village cost totals are removed. The exact values could go under restricted access. See `910_disclosure_review.csv`.", disclosure$pct_under_5[nrow(disclosure) - 1], disclosure$pct_under_5[nrow(disclosure)]),
  "- `cost_comm_repeat` marks villages whose capacity cost may repeat the transfer cost: a binary flag kept as merged.",
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
  for (v in setdiff(names(d), c(KEYS, "SvyYearMonth", "HHHAge_group", names(COARSENED)))) {
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
