# Build the dashboard's data folder from the merging pipeline's files. From the app/ folder:
#   Rscript prepare_app_data.R
#
# Reads the raw SPSS files, the harmonisation workbook, the module files and the merged dataset, all
# read-only. Writes to data/ ONLY aggregates and metadata: no household identifier, no village name,
# no GPS, and any regional cell under 30 households is suppressed. Everything the Validation page
# reports is computed here, so a rerun after a pipeline fix updates the checks by itself.
#
# Folders can be overridden with the environment variables below.

suppressPackageStartupMessages({
  library(haven); library(dplyr); library(tidyr); library(readxl); library(readr); library(jsonlite); library(digest)
})
options(dplyr.summarise.inform = FALSE)
if (!file.exists("app.R")) stop("Run this script from the app/ folder.", call. = FALSE)

base <- "C:/Users/AHema/OneDrive - CGIAR/Desktop"
env_dir <- function(name, default) { v <- Sys.getenv(name); if (nzchar(v)) v else default }
DIR_INPUT <- env_dir("WFP_INPUT_DIR", file.path(base, "WFP Resilience dataset/data/input_data/Chad"))
DIR_MODULES <- env_dir("WFP_MODULES_DIR", file.path(base, "WFP Resilience dataset/data/output_data/Chad"))
DIR_MERGED <- env_dir("WFP_MERGED_DIR", file.path(base, "2024/WFP/CBA - Chad/data"))
# The merged file with the 17 modules added in November 2026 (do-files 16 to 20) and the cost module (do-file 21),
# and the file before the 2026 modules.
FINAL_FILE <- "WFP_Chad_2018-2023_20261108_v6.dta"
PREV_FILE <- "WFP_Chad_2018-2023_20261105_v2.dta"
REPO <- ".."
MIN_CELL <- 30
OUT <- "data"
dir.create(OUT, showWarnings = FALSE)
for (d in c(DIR_INPUT, DIR_MODULES, DIR_MERGED)) if (!dir.exists(d)) stop("Folder not found: ", d, call. = FALSE)

say <- function(...) cat(sprintf(...), "\n")
clean_text <- function(x) trimws(gsub("\\s+", " ", gsub("<[^>]+>", " ", x[1])))
clean_text2 <- function(x) trimws(gsub("\\s+", " ", gsub("<[^>]+>", " ", x)))
write_out <- function(x, name) { readr::write_csv(x, file.path(OUT, name), na = ""); say("  %-32s %5d rows", name, nrow(x)) }

# ---- Configuration ------------------------------------------------------------------------------
cfg_rounds <- readr::read_csv("config/rounds.csv", show_col_types = FALSE)
cfg_modules <- readr::read_csv("config/modules.csv", show_col_types = FALSE)
cfg_interv <- readr::read_csv("config/interventions.csv", show_col_types = FALSE, col_types = readr::cols(.default = "c"))
rid_of <- function(r) cfg_rounds$round_id[match(r, cfg_rounds$round)]

# ---- Sources ------------------------------------------------------------------------------------
say("Reading the merged dataset and the workbook...")
final_lab <- haven::read_dta(file.path(DIR_MERGED, FINAL_FILE))
x <- haven::zap_labels(final_lab)
x$ID <- as.character(x$ID)
x$round_id <- rid_of(x$ROUND)
N_FINAL <- nrow(x)
final_var_labels <- vapply(final_lab, function(v) { l <- attr(v, "label", exact = TRUE); if (is.null(l)) "" else clean_text(l) }, "")

wb_path <- file.path(DIR_INPUT, "Chad_Harmonization.xlsx")
hv <- as.data.frame(readxl::read_excel(wb_path, "variables_harmonization"))
de <- as.data.frame(readxl::read_excel(wb_path, "description"))
repo_hv <- as.data.frame(readxl::read_excel(file.path(REPO, "harmonization", "Chad_Harmonization.xlsx"), "variables_harmonization"))
# Mapping of the modules added in November 2026 (Rmds 16 to 23)
ext_path <- file.path(DIR_INPUT, "Chad_Harmonization_extension.xlsx")
ext <- as.data.frame(readxl::read_excel(ext_path, "variables_harmonization"))
repo_ext <- as.data.frame(readxl::read_excel(file.path(REPO, "harmonization", "Chad_Harmonization_extension.xlsx"), "variables_harmonization"))

say("Reading the 10 raw SPSS files...")
raw <- list()
for (i in seq_len(nrow(de))) raw[[de$Name[i]]] <- haven::read_sav(file.path(DIR_INPUT, de$Data[i]))
source_of <- function(ds, v) { s <- hv[hv$NewVariable_Name == v, ds]; if (length(s) && !is.na(s)) s else NA_character_ }
# IDs as the pipeline builds them: PDM 2022 has no ID column, so the Rmds use the row number.
raw_ids <- function(ds) {
  if (ds == "Chad_pdm_2022") return(as.character(seq_len(nrow(raw[[ds]]))))
  as.character(raw[[ds]][[source_of(ds, "ID")]])
}
# Value of a raw variable for the merged households of a round, in merged-file order.
raw_for_round <- function(ds, rawvar) {
  ids <- raw_ids(ds); keep <- !duplicated(ids)
  rid <- cfg_rounds$round_id[cfg_rounds$dataset == ds]
  j <- match(x$ID[x$round_id == rid], ids[keep])
  haven::zap_labels(raw[[ds]][[rawvar]])[keep][j]
}

# ---- Checks: every result below ends up on the Validation page ----------------------------------
checks <- list()
add_check <- function(group, check, status, observed, expected = "", detail = "") {
  checks[[length(checks) + 1]] <<- data.frame(group = group, check = check, status = status, observed = as.character(observed),
                                              expected = as.character(expected), detail = detail, stringsAsFactors = FALSE)
}
pass_if <- function(ok, otherwise = "fail") if (isTRUE(ok)) "pass" else otherwise
rounds_txt <- function(rids) paste(cfg_rounds$label[match(rids, cfg_rounds$round_id)], collapse = ", ")

# ---- Rows: raw file to merged file --------------------------------------------------------------
say("Row flow...")
flow <- bind_rows(lapply(seq_len(nrow(cfg_rounds)), function(i) {
  cr <- cfg_rounds[i, ]; ids <- raw_ids(cr$dataset)
  data.frame(round_id = cr$round_id, raw_rows = length(ids), raw_cols = ncol(raw[[cr$dataset]]),
             mapped_vars = sum(!is.na(hv[[cr$dataset]])), duplicates_removed = sum(duplicated(ids)),
             final_rows = sum(x$round_id == cr$round_id))
})) |> mutate(empty_removed = raw_rows - duplicates_removed - final_rows)

mod_files <- setNames(cfg_modules$file, cfg_modules$module)
mod_new <- setNames(cfg_modules$stage == 2026, cfg_modules$module)
read_mod <- function(dir, m) { y <- haven::zap_labels(haven::read_dta(file.path(dir, paste0(mod_files[[m]], ".dta")))); y$ID <- as.character(y$ID); y }
# Module files as the merge used them: do-file 12 saved cleaned copies of the first 9; do-files 16 and 17
# read the others from the module folder and clean them in memory.
mod_path <- function(m) file.path(if (mod_new[[m]]) DIR_MODULES else DIR_MERGED, paste0(mod_files[[m]], ".dta"))
adm_pre <- read_mod(DIR_MODULES, "admin")

# Duplicated IDs before the do-file's "duplicates drop ID, force": true duplicates or different interviews?
dup_groups <- adm_pre |> group_by(ID) |> filter(n() > 1) |>
  summarise(rows = n(), n_rounds = n_distinct(paste(YEAR, SURVEY)), round = paste(YEAR[1], SURVEY[1]),
            same = n_distinct(paste(ADMIN2Name, village, SvyDatePDM)) == 1) |> ungroup()

add_check("Rows", "Raw rows minus removed rows equal the merged rows",
          pass_if(sum(flow$raw_rows) - sum(flow$duplicates_removed) - sum(flow$empty_removed) == N_FINAL),
          sprintf("%s - %d - %d = %s", format(sum(flow$raw_rows), big.mark = ","), sum(flow$duplicates_removed), sum(flow$empty_removed), format(N_FINAL, big.mark = ",")),
          "Exact", "Every household in the 10 raw files is accounted for.")
add_check("Rows", "ID is unique in the merged file", pass_if(!anyDuplicated(x$ID)), sum(duplicated(x$ID)), "0 duplicates")
add_check("Rows", "Every round keeps one survey and year", pass_if(all(table(paste(x$YEAR, x$SURVEY), x$ROUND) %in% c(0, flow$final_rows))),
          n_distinct(paste(x$YEAR, x$SURVEY, x$ROUND)), "10 combinations")
add_check("Rows", "No ID is shared across rounds", pass_if(all(dup_groups$n_rounds == 1)), sum(dup_groups$n_rounds > 1), "0 IDs",
          "The merge is 1:1 on ID alone, so an ID reused across rounds would silently merge two households.")
add_check("Rows", "Removed duplicates are true repeats of one interview", pass_if(all(dup_groups$same), "warn"),
          sprintf("%d of %d duplicated IDs identical", sum(dup_groups$same), nrow(dup_groups)), "All identical",
          sprintf("All duplicates are in %s. %d ID has rows with a different place or date; the do-file keeps the first row.",
                  paste(unique(dup_groups$round), collapse = ", "), sum(!dup_groups$same)))

# ---- Merge replay -------------------------------------------------------------------------------
say("Replaying the 1:1 merge...")
clean_mods <- lapply(setNames(cfg_modules$module, cfg_modules$module), function(m) read_mod(if (mod_new[[m]]) DIR_MODULES else DIR_MERGED, m))
# Do-files 16 and 17: first occurrence of each ID, and drop what the master does not have.
new_left_out <- c()
for (m in names(which(mod_new))) {
  y <- clean_mods[[m]]; y <- y[!duplicated(y$ID), ]
  new_left_out[m] <- sum(!y$ID %in% clean_mods$admin$ID)
  clean_mods[[m]] <- y[y$ID %in% clean_mods$admin$ID, ]
}
mod_ids <- lapply(clean_mods, `[[`, "ID")
cur <- mod_ids$admin
merge_steps <- bind_rows(lapply(cfg_modules$module, function(m) {
  i <- mod_ids[[m]]
  r <- data.frame(module = m, master_before = length(cur), using_rows = length(i), using_duplicates = sum(duplicated(i)),
                  matched = length(intersect(cur, i)), master_only = length(setdiff(cur, i)), using_only = length(setdiff(i, cur)),
                  columns_added = ncol(clean_mods[[m]]) - 1)
  cur <<- union(cur, i)
  r
})) |> left_join(select(cfg_modules, module, label, rmd, merge_order, description), by = "module")

module_round <- expand.grid(module = cfg_modules$module, round_id = cfg_rounds$round_id, stringsAsFactors = FALSE) |>
  rowwise() |>
  mutate(households = sum(x$ID[x$round_id == round_id] %in% mod_ids[[module]]),
         round_total = sum(x$round_id == round_id), pct = round(100 * households / round_total, 1)) |>
  ungroup()

add_check("Merge", "All module files are unique on ID", pass_if(all(merge_steps$using_duplicates == 0)), sum(merge_steps$using_duplicates), "0 duplicates")
add_check("Merge", "No household exists only in a later module", pass_if(all(merge_steps$using_only == 0)), sum(merge_steps$using_only), "0 households",
          "The administrative file is the master: every other module's households are found in it.")
add_check("Merge", "The replayed merge gives the merged file's households", pass_if(setequal(cur, x$ID)), length(cur), format(N_FINAL, big.mark = ","))
# The cost module is built from the merged file itself (costs/prepare_household_cost_module.R), so it leaves out nobody.
DERIVED_MODULES <- "Costs"
expected_left_out <- ifelse(names(new_left_out) %in% DERIVED_MODULES, 0, 1)
add_check("Merge", "New modules leave out only the refused interview", pass_if(all(new_left_out == expected_left_out)),
          sprintf("%s household left out per survey module; %s for the cost module", paste(unique(new_left_out[expected_left_out == 1]), collapse = "/"), paste(new_left_out[expected_left_out == 0], collapse = "/")),
          "1 per survey module, 0 for the cost module",
          sprintf("Do-files 16 to 20 keep the first of each duplicated ID, as do-file 12 does, and drop the one interview do-file 12 removed. The cost module (do-file 21) is built from the merged file. %d modules checked.", length(new_left_out)))
# The modules added in 2026 must not change anything that was already in the merged file.
prev <- haven::zap_labels(haven::read_dta(file.path(DIR_MERGED, PREV_FILE))); prev$ID <- as.character(prev$ID)
prev_same <- identical(prev$ID, x$ID) && isTRUE(all.equal(as.data.frame(prev), as.data.frame(x[names(prev)]), check.attributes = FALSE))
add_check("Merge", "The 2026 modules leave the earlier columns unchanged", pass_if(prev_same), if (prev_same) sprintf("%d columns identical", ncol(prev)) else "Changed", "Identical",
          sprintf("Against %s, the merged file before do-files 16 and 17. %d columns added.", PREV_FILE, ncol(final_lab) - ncol(prev)))
rm(prev)
miss_ch <- sum(is.na(x$phase_class))
add_check("Merge", "Every household links to a Cadre Harmonisé phase", pass_if(miss_ch == 0, "warn"), sprintf("%d without a phase", miss_ch), "0",
          sprintf("In %s, where %d of them also have no department, the link's key. The comment in the do-file records 41 unmatched when it was written.",
                  rounds_txt(unique(x$round_id[is.na(x$phase_class)])), sum(is.na(x$phase_class) & (is.na(x$ADMIN2Name) | x$ADMIN2Name == ""))))

# Do the module files re-knitted after the merge still give what the merge used?
stale <- bind_rows(lapply(cfg_modules$module, function(m) {
  a <- read_mod(DIR_MODULES, m); b <- clean_mods[[m]]
  a <- a[!duplicated(a$ID), ]; j <- match(b$ID, a$ID)
  com <- setdiff(intersect(names(a), names(b)), "ID")
  diff <- vapply(com, function(v) sum(!(as.character(a[[v]][j]) == as.character(b[[v]]) | (is.na(a[[v]][j]) & is.na(b[[v]]))), na.rm = TRUE), 0)
  data.frame(module = m, columns_changed = sum(diff > 0))
}))
add_check("Merge", "Module files re-knitted in May 2025 match the files used by the merge",
          pass_if(all(stale$columns_changed[stale$module != "admin"] == 0)),
          sprintf("%d columns changed", sum(stale$columns_changed[stale$module != "admin"])), "0 columns",
          sprintf("Outside the administrative module, whose %d changed columns are the do-file's intended place-name corrections.", stale$columns_changed[stale$module == "admin"]))

# Workbook
same_wb <- identical(hv, repo_hv)
add_check("Workbook", "The repository's workbook is the one the pipeline reads", pass_if(same_wb), if (same_wb) "Identical" else "Different", "Identical")
missing_map <- unlist(lapply(names(raw), function(n) setdiff(stats::na.omit(hv[[n]]), names(raw[[n]]))))
add_check("Workbook", "Every mapped source variable exists in its raw file", pass_if(!length(missing_map)), length(missing_map), "0 missing",
          sprintf("%s mappings tested across the 10 rounds.", format(sum(!is.na(hv[, names(raw)])), big.mark = ",")))
same_ext <- identical(ext, repo_ext)
add_check("Workbook", "The repository's extension workbook is the one the 2026 modules read", pass_if(same_ext), if (same_ext) "Identical" else "Different", "Identical")
missing_ext <- unlist(lapply(names(raw), function(n) setdiff(stats::na.omit(ext[[n]]), names(raw[[n]]))))
add_check("Workbook", "Every source variable of the extension workbook exists in its raw file", pass_if(!length(missing_ext)), length(missing_ext), "0 missing",
          sprintf("%d mappings of %d variables tested.", sum(!is.na(ext[, names(raw)])), nrow(ext)))
map_dups <- bind_rows(lapply(names(raw), function(n) {
  m <- hv[!is.na(hv[[n]]), c("NewVariable_Name", n)]; names(m) <- c("target", "source")
  m |> group_by(source) |> filter(n() > 1) |> summarise(targets = paste(target, collapse = ", ")) |> ungroup() |>
    mutate(round_id = cfg_rounds$round_id[cfg_rounds$dataset == n])
}))
# ---- Crosswalk ----------------------------------------------------------------------------------
say("Crosswalk...")
NEW_FAMILY <- c(Shocks = "Shocks", Assets = "Assets and livestock", Livelihoods = "Livelihoods", Agriculture = "Agriculture",
                Expenditure = "Expenditure", Disability = "Disability", Education = "Education", Migration = "Migration",
                Protection = "Protection and accountability", Debt = "Debt", Cohesion = "Social cohesion", Adaptation = "Climate adaptation",
                ShockImpact = "Shock impact and recovery", Effects = "Programme effects", Markets = "Markets", Accountability = "Protection and accountability")
# Variables of the 2026 modules by name prefix; the "Additions" module's variables join the family of their prefix.
prefix_family <- function(v) dplyr::case_when(
  grepl("^ShkImp|^ShkRec", v) ~ "Shock impact and recovery", grepl("^Shk", v) ~ "Shocks", grepl("^Ast|^Lvs", v) ~ "Assets and livestock",
  grepl("^Liv[A-Z]", v) ~ "Livelihoods", grepl("^Agr[A-Z]", v) ~ "Agriculture", grepl("^Exp[A-Z]", v) ~ "Expenditure", grepl("^Dis[A-Z]", v) ~ "Disability",
  grepl("^Edu[A-Z]", v) ~ "Education", grepl("^Mig[A-Z]", v) ~ "Migration", grepl("^Prt[A-Z]|^Aap[A-Z]", v) ~ "Protection and accountability",
  grepl("^Dbt[A-Z]", v) ~ "Debt", grepl("^Coh[A-Z]", v) ~ "Social cohesion", grepl("^Adp[A-Z]", v) ~ "Climate adaptation",
  grepl("^Eff[A-Z]", v) ~ "Programme effects", grepl("^Mkt[A-Z]", v) ~ "Markets", grepl("^Fsn[A-Z]", v) ~ "Food shortage (2018-2021)")
family_of <- function(v) {
  in_ext <- v %in% ext$NewVariable_Name
  fam_ext <- ifelse(in_ext, prefix_family(v), NA_character_)
  dplyr::case_when(
    !is.na(fam_ext) ~ fam_ext,
    v %in% c("ID", "Key_with_subset_data", "SvyDatePDM", "RESPConsent") ~ "Identification",
    v %in% c("ADMIN1Name", "ADMIN2Name", "ADMIN3Name", "sous_bureau", "site", "site_autre", "village", "village_autre", "Longitude", "Latitude", "Longitude_precision", "Latitude_precision") ~ "Geography",
    v %in% c("RESPAge", "RESPSex", "RelationWith_HHH") ~ "Respondent",
    grepl("^HH", v) ~ "Household",
    grepl("^FCS|^SCA$", v) ~ "Food consumption (FCS)",
    grepl("^rCSI", v) ~ "Reduced coping (rCSI)",
    grepl("^LhCSI", v) ~ "Livelihood coping (LCS)",
    grepl("^SERS", v) ~ "Resilience (SERS)",
    grepl("^ABI|^Actif|^BeneficieEmploi|^TRavail", v) ~ "Asset benefit (ABI)",
    grepl("Assist|Montant|TransfBenef", v) | v %in% cfg_interv$variable ~ "Assistance",
    grepl("Epargne|Pret|chocs|Gravite|CACRetab", v) ~ "Savings and shocks",
    grepl("Migration|Migrants|DestinationMig|DureeMig|TendanceMig|RaisonHausse|RaisonBaisse|RaisonMig|RaisonAcces|AutreRaison", v) ~ "Migration",
    grepl("^SCI", v) ~ "Social capital",
    grepl("^PW|^MDDW", v) ~ "Women's diet (MDDW)",
    grepl("^MAD|^PCMAD|^PCIYC|^EverBreast", v) ~ "Child diet (MAD)",
    TRUE ~ "Other"
  )
}
FAMILY_ORDER <- c("Identification", "Geography", "Respondent", "Household", "Food consumption (FCS)", "Reduced coping (rCSI)",
                  "Livelihood coping (LCS)", "Assistance", "Resilience (SERS)", "Asset benefit (ABI)", "Savings and shocks",
                  "Migration", "Social capital", "Women's diet (MDDW)", "Child diet (MAD)",
                  "Shocks", "Assets and livestock", "Livelihoods", "Agriculture", "Expenditure", "Disability", "Education",
                  "Protection and accountability", "Debt", "Social cohesion", "Climate adaptation", "Shock impact and recovery",
                  "Programme effects", "Markets", "Food shortage (2018-2021)", "Other")
SENSITIVE_META <- c("ID", "Key_with_subset_data", "ADMIN1Name", "ADMIN2Name", "ADMIN3Name", "sous_bureau", "site", "site_autre", "village", "village_autre", "Longitude", "Latitude", "Longitude_precision", "Latitude_precision")
final_names <- c(names(x), "SvyDatePDM")

# Both workbooks: the 217 variables of 2025 and the variables of the 2026 modules.
ALL_MAPPED <- c(hv$NewVariable_Name, ext$NewVariable_Name)
source_any <- function(ds, v) { if (v %in% ext$NewVariable_Name) { s <- ext[ext$NewVariable_Name == v, ds]; if (length(s) && !is.na(s)) s else NA_character_ } else source_of(ds, v) }
crosswalk <- bind_rows(lapply(seq_len(nrow(cfg_rounds)), function(i) {
  cr <- cfg_rounds[i, ]; r <- raw[[cr$dataset]]
  bind_rows(lapply(ALL_MAPPED, function(v) {
    s <- source_any(cr$dataset, v)
    if (is.na(s) || !s %in% names(r)) return(data.frame(variable = v, round_id = cr$round_id, source = NA_character_, type = NA_character_,
                                                        coverage = NA_real_, range = NA_character_, label = NA_character_, value_labels = NA_character_))
    z <- r[[s]]; zz <- haven::zap_labels(z)
    nonmiss <- if (is.character(zz)) !is.na(zz) & nzchar(trimws(zz)) else !is.na(zz)
    lab <- attr(z, "label", exact = TRUE); vl <- attr(z, "labels", exact = TRUE); sens <- v %in% SENSITIVE_META
    rng <- if (!sens && is.numeric(zz) && any(nonmiss)) sprintf("%s to %s", format(min(zz[nonmiss]), trim = TRUE), format(max(zz[nonmiss]), trim = TRUE)) else NA_character_
    data.frame(variable = v, round_id = cr$round_id, source = s,
               type = if (inherits(z, "haven_labelled")) "labelled" else if (is.character(zz)) "text" else if (inherits(z, "Date")) "date" else "numeric",
               coverage = round(100 * mean(nonmiss), 1), range = rng,
               label = if (is.null(lab)) NA_character_ else clean_text(lab),
               value_labels = if (sens || is.null(vl)) NA_character_ else substr(clean_text(paste(paste0(vl, " = ", names(vl)), collapse = "; ")), 1, 400))
  }))
})) |> mutate(family = family_of(variable), in_final = variable %in% final_names)

crosswalk_summary <- crosswalk |> group_by(variable, family, in_final) |>
  summarise(rounds_mapped = sum(!is.na(source)), .groups = "drop") |>
  mutate(order = match(variable, ALL_MAPPED)) |> arrange(match(family, FAMILY_ORDER), order)
n_duplicate_map <- nrow(map_dups)

# ---- Source to merged agreement -----------------------------------------------------------------
say("Comparing raw values with the merged file...")
pass_vars <- setdiff(intersect(hv$NewVariable_Name, names(x)), c("ID", "Key_with_subset_data", "village", "ADMIN1Name", "ADMIN2Name", "Longitude", "Latitude", "Longitude_precision", "Latitude_precision"))
source_agree <- bind_rows(lapply(seq_len(nrow(cfg_rounds)), function(i) {
  cr <- cfg_rounds[i, ]
  xx <- x[x$round_id == cr$round_id, ]
  bind_rows(lapply(pass_vars, function(v) {
    s <- source_of(cr$dataset, v)
    if (is.na(s) || !s %in% names(raw[[cr$dataset]])) return(NULL)
    a <- suppressWarnings(as.numeric(raw_for_round(cr$dataset, s))); b <- suppressWarnings(as.numeric(xx[[v]]))
    k <- !is.na(a) & !is.na(b)
    if (!any(k)) return(NULL)
    data.frame(variable = v, family = family_of(v), round_id = cr$round_id, compared = sum(k), same = sum(a[k] == b[k]), pct_same = round(100 * mean(a[k] == b[k]), 1))
  }))
}))
agree_family <- source_agree |> group_by(family, round_id) |>
  summarise(compared = sum(compared), pct_same = round(100 * sum(same) / sum(compared), 1), .groups = "drop")

# PDM 2022 has row-number IDs in every Rmd: do the rows still line up?
r7 <- x[x$round_id == "R07", ]; y7 <- raw$Chad_pdm_2022
align <- mean(as.numeric(haven::zap_labels(y7$rCSIMealSize))[as.integer(r7$ID)] == r7$rCSIMealSize, na.rm = TRUE)
add_check("Merge", "PDM 2022 rows still line up with their row-number IDs", pass_if(align == 1), sprintf("%.1f%% same", 100 * align), "100%",
          "This round has no ID in the raw file; each Rmd assigns the row number before any filter.")

# ---- Scores and the indicative corrections ------------------------------------------------------
say("Recomputing scores...")
num <- function(v) as.numeric(v)
fcs_calc <- with(x, FCSStap * 2 + FCSPulse * 3 + FCSDairy * 4 + FCSPr * 4 + FCSVeg + FCSFruit + FCSFat * .5 + FCSSugar * .5)
rcsi_calc <- with(x, rCSILessQlty + 2 * rCSIBorrow + rCSIMealNb + rCSIMealSize + 3 * rCSIMealAdult)
# A round with no main-group day counts has nothing to recompute from: the check below covers it.
add_check("Formulas", "FCS follows the WFP formula", pass_if(all(abs(fcs_calc - x$FCS) < 1e-6, na.rm = TRUE)), sum(abs(fcs_calc - x$FCS) >= 1e-6, na.rm = TRUE), "0 differences", "Cereals x2, pulses x3, dairy x4, protein x4, vegetables x1, fruit x1, fat x0.5, sugar x0.5. Tested on rounds with day counts.")
cat28 <- ifelse(x$FCS <= 28, 1, ifelse(x$FCS <= 42, 2, 3)); cat21 <- ifelse(x$FCS <= 21, 1, ifelse(x$FCS <= 35, 2, 3))
add_check("Formulas", "FCS groups follow the 28/42 and 21/35 thresholds", pass_if(all(cat28 == x$FCSCat28) && all(cat21 == x$FCSCat21)), sum(cat28 != x$FCSCat28) + sum(cat21 != x$FCSCat21), "0 differences")
add_check("Formulas", "rCSI follows the WFP formula", pass_if(all(abs(rcsi_calc - x$rCSI) < 1e-6, na.rm = TRUE)), sum(abs(rcsi_calc - x$rCSI) >= 1e-6, na.rm = TRUE), "0 differences", "Less preferred x1, borrow x2, meal number x1, meal size x1, adults x3.")

LCS_S <- c("LhCSIStress1", "LhCSIStress2", "LhCSIStress3", "LhCSIStress4")
LCS_C <- c("LhCSICrisis1", "LhCSICrisis2", "LhCSICrisis3")
LCS_E <- c("LhCSIEmergency1", "LhCSIEmergency2", "LhCSIEmergency3")
LCS_ALL <- c(LCS_S, LCS_C, LCS_E)
max_coping <- function(d) {
  a <- function(v) rowSums(sapply(d[v], function(k) k %in% c(2, 3))) > 0
  ifelse(a(LCS_E), 4, ifelse(a(LCS_C), 3, ifelse(a(LCS_S), 2, 1)))
}
add_check("Formulas", "Maximum coping category follows its rule", pass_if(all(max_coping(x) == x$Max_coping_behaviourFS)), sum(max_coping(x) != x$Max_coping_behaviourFS), "0 differences", "Highest level with a strategy answered Yes or already exhausted.")

rcs_items <- c("HHRCSBounce", "HHRCSRevenue", "HHRCSIncrease", "HHRCSFinAccess", "HHRCSSupportCommunity", "HHRCSLessonsLearnt", "HHRCSFutureChallenge", "HHRCSWarningAccess", "HHRCSSupportPublic")
rcs_calc <- 100 * (rowMeans(x[rcs_items], na.rm = TRUE) - 1) / 4
# Stata stores RCS as a float, hence the wider tolerance.
add_check("Formulas", "Resilience Capacity Score follows its formula", pass_if(all(abs(rcs_calc - x$RCS) < 1e-3, na.rm = TRUE)), sum(abs(rcs_calc - x$RCS) >= 1e-3, na.rm = TRUE), "0 differences", "Mean of 9 statements on a 1-to-5 scale, rescaled to 0-100.")
rcs_tab <- suppressMessages(as.data.frame(readxl::read_excel(file.path(REPO, "merge", "RCS_table.xlsx"))))
rcs_saved <- as.numeric(rcs_tab[rcs_tab[[1]] %in% "Resilience capacity", 2:4])
rcs_now <- as.numeric(prop.table(table(factor(x$RCSCat33, 1:3))))
add_check("Formulas", "RCS groups match the saved RCS_table.xlsx", pass_if(all(abs(rcs_saved - rcs_now) < 1e-3)), sprintf("%.1f / %.1f / %.1f%%", 100 * rcs_now[1], 100 * rcs_now[2], 100 * rcs_now[3]), sprintf("%.1f / %.1f / %.1f%%", 100 * rcs_saved[1], 100 * rcs_saved[2], 100 * rcs_saved[3]))
abi_items <- c("ABIProteger", "ABIProduction", "ABIdifficultes", "ABIMarches", "ABIGererActifs", "ABIEnvironnement", "ABIutiliseractifs")
abi_calc <- rowSums(x[abi_items] == 1, na.rm = TRUE); abi_ok <- !is.na(x$ABIScore)
add_check("Formulas", "ABI score counts the 7 Yes answers", pass_if(all(abi_calc[abi_ok] == x$ABIScore[abi_ok])), sum(abi_calc[abi_ok] != x$ABIScore[abi_ok]), "0 differences")

out_of_range <- c(FCS = sum(x$FCS < 0 | x$FCS > 112), rCSI = sum(x$rCSI < 0 | x$rCSI > 56, na.rm = TRUE), HDDS = sum(x$HDDS_hema < 0 | x$HDDS_hema > 12, na.rm = TRUE), RCS = sum(x$RCS < 0 | x$RCS > 100, na.rm = TRUE), ABI = sum(x$ABIScore < 0 | x$ABIScore > 7, na.rm = TRUE))
add_check("Formulas", "Scores stay in their possible range", pass_if(all(out_of_range == 0)), sum(out_of_range), "0 values", "FCS 0-112, rCSI 0-56, HDDS 0-12, RCS 0-100, ABI 0-7.")
days_bad <- sum(x[c("FCSStap", "FCSPulse", "FCSDairy", "FCSPr", "FCSVeg", "FCSFruit", "FCSFat", "FCSSugar", "rCSILessQlty", "rCSIBorrow", "rCSIMealNb", "rCSIMealSize", "rCSIMealAdult")] > 7, na.rm = TRUE)
add_check("Formulas", "FCS and rCSI day counts do not exceed 7", pass_if(days_bad == 0), days_bad, "0 values")

# FCS: a round whose day counts are only 0 or 1 has not recorded days.
fcs_days_max <- x |> group_by(round_id) |> summarise(mx = suppressWarnings(max(c(FCSStap, FCSVeg, FCSFat, FCSSugar), na.rm = TRUE)))
binary_rounds <- fcs_days_max |> filter(is.finite(mx), mx <= 1) |> pull(round_id)
add_check("Plausibility", "FCS day counts hold more than 0/1 where they exist", pass_if(!length(binary_rounds)),
          if (length(binary_rounds)) rounds_txt(binary_rounds) else "No round with flags", "No round with flags",
          if (length(binary_rounds)) sprintf("The mapped jour_conso_* variables of %s hold 0/1 flags, so the FCS averages %.1f and %.0f%% of households are Poor. The analysts' own SCA in the same file averages %.1f.",
                  rounds_txt(binary_rounds), mean(x$FCS[x$round_id %in% binary_rounds]), 100 * mean(x$FCSCat28[x$round_id %in% binary_rounds] == 1), mean(x$SCA[x$round_id %in% binary_rounds], na.rm = TRUE)) else "")
# A round without day counts must carry the analysts' score and groups, household by household.
no_days_rounds <- fcs_days_max |> filter(!is.finite(mx)) |> pull(round_id)
fcs_from_analysts <- vapply(no_days_rounds, function(rid) {
  ds <- cfg_rounds$dataset[cfg_rounds$round_id == rid]; i <- x$round_id == rid
  all(abs(x$FCS[i] - as.numeric(raw_for_round(ds, "SCA"))) < 1e-6) && all(x$FCSCat28[i] == as.numeric(raw_for_round(ds, "SCA_Group")))
}, TRUE)
add_check("Plausibility", "Rounds without day counts use the analysts' score and groups", pass_if(all(fcs_from_analysts)),
          if (length(no_days_rounds)) rounds_txt(no_days_rounds) else "No such round", "Same as raw SCA and SCA_Group",
          if (length(no_days_rounds)) sprintf("The main food groups of %s are empty, because the raw file holds only 0/1 flags. FCS and FCSCat28 are compared with the raw SCA and SCA_Group for each household.", rounds_txt(no_days_rounds)) else "")

# rCSI: the workbook maps rCSIBorrow to another column in some rounds; the raw rCSI settles which is right.
rcsi_workbook_bad <- map_dups |> filter(source == "rCSILessQlty") |> pull(round_id)
add_check("Workbook", "No two rCSI items share a source column", pass_if(!length(rcsi_workbook_bad)), if (length(rcsi_workbook_bad)) rounds_txt(rcsi_workbook_bad) else "None", "None",
          if (length(rcsi_workbook_bad)) "rCSIBorrow points to the rCSILessQlty column in the workbook, although the raw files have an rCSIBorrow column." else "")
# The merged file decides, not the workbook: a corrected workbook does not fix a merged file built before it.
rcsi_map_bad <- cfg_rounds$round_id[vapply(cfg_rounds$dataset, function(ds) {
  if (!"rCSIBorrow" %in% names(raw[[ds]])) return(FALSE)
  a <- as.numeric(raw_for_round(ds, "rCSIBorrow")); b <- x$rCSIBorrow[x$round_id == cfg_rounds$round_id[cfg_rounds$dataset == ds]]
  mean(a == b, na.rm = TRUE) < .99
}, TRUE)]
add_check("Plausibility", "Merged rCSIBorrow equals its raw column", pass_if(!length(rcsi_map_bad)), if (length(rcsi_map_bad)) rounds_txt(rcsi_map_bad) else "All rounds with that column", "All", "")
rcsi_true <- x$rCSI; borrow_true <- x$rCSIBorrow
rcsi_rows <- list()
for (rid in cfg_rounds$round_id) {
  ds <- cfg_rounds$dataset[cfg_rounds$round_id == rid]; here <- x$round_id == rid
  has_raw <- "rCSI" %in% names(raw[[ds]])
  raw_rcsi <- if (has_raw) as.numeric(raw_for_round(ds, "rCSI")) else rep(NA_real_, sum(here))
  if (rid %in% rcsi_map_bad) {
    b <- as.numeric(raw_for_round(ds, "rCSIBorrow")); borrow_true[here] <- b
    rcsi_true[here] <- with(x[here, ], rCSILessQlty + 2 * b + rCSIMealNb + rCSIMealSize + 3 * rCSIMealAdult)
  }
  rcsi_rows[[rid]] <- data.frame(round_id = rid, merged = mean(x$rCSI[here], na.rm = TRUE), corrected = mean(rcsi_true[here], na.rm = TRUE),
                                 analysts = if (has_raw) mean(raw_rcsi, na.rm = TRUE) else NA_real_,
                                 merged_same = if (has_raw) mean(abs(x$rCSI[here] - raw_rcsi) < .01, na.rm = TRUE) else NA_real_,
                                 corrected_same = if (has_raw) mean(abs(rcsi_true[here] - raw_rcsi) < .01, na.rm = TRUE) else NA_real_)
}
rcsi_compare <- bind_rows(rcsi_rows) |> mutate(across(c(merged, corrected, analysts), ~ round(.x, 2)), across(c(merged_same, corrected_same), ~ round(100 * .x, 1)))
bad_rcsi <- rcsi_compare |> filter(!is.na(merged_same), merged_same < 99, round_id %in% rcsi_map_bad)
add_check("Plausibility", "rCSI matches the analysts' rCSI where the mapping is at fault", pass_if(!nrow(bad_rcsi)),
          if (nrow(bad_rcsi)) rounds_txt(bad_rcsi$round_id) else "All", "All",
          if (nrow(bad_rcsi)) sprintf("Merged rCSI equals the analysts' for %.0f%% to %.0f%% of households. Using the true rCSIBorrow column reproduces it for %.0f%%.",
                                      min(bad_rcsi$merged_same), max(bad_rcsi$merged_same), min(bad_rcsi$corrected_same)) else "")
other_rcsi <- rcsi_compare |> filter(!is.na(merged_same), merged_same < 99, !round_id %in% rcsi_map_bad)
add_check("Plausibility", "rCSI matches the analysts' rCSI in the other rounds", pass_if(!nrow(other_rcsi), "warn"),
          if (nrow(other_rcsi)) rounds_txt(other_rcsi$round_id) else "All", "All",
          if (nrow(other_rcsi)) sprintf("%s: mean %.2f against the analysts' %.2f, same value for %.0f%% of households. No mapping error here; the analysts may have used another formula.",
                                        rounds_txt(other_rcsi$round_id[1]), other_rcsi$merged[1], other_rcsi$analysts[1], other_rcsi$merged_same[1]) else "")

# ABI: all-zero rounds, and the score the raw answers imply.
abi_means <- x |> filter(!is.na(ABIScore)) |> group_by(round_id) |> summarise(m = mean(ABIScore))
abi_zero <- abi_means$round_id[abi_means$m == 0]
abi_true <- x$ABIScore
for (rid in abi_zero) {
  ds <- cfg_rounds$dataset[cfg_rounds$round_id == rid]; here <- which(x$round_id == rid)
  m <- sapply(abi_items, function(v) as.numeric(raw_for_round(ds, source_of(ds, v))))
  abi_true[here] <- ifelse(rowSums(!is.na(m)) > 0, rowSums(m == 1, na.rm = TRUE), NA)
}
add_check("Plausibility", "ABI score is not zero for a whole round", pass_if(!length(abi_zero)), if (length(abi_zero)) rounds_txt(abi_zero) else "None", "None",
          sprintf("The recode in Rmd 07 reads 1 as No, following the labels, but the raw answers are coded 0/1. The raw answers imply a mean of %.1f.", mean(abi_true[x$round_id %in% abi_zero], na.rm = TRUE)))

# LCS: restate each round's answers on the common scale from the raw file, with the scale its labels declare.
# yes_code: raw code meaning Yes; the others follow the file's labels. Raw 0 is treated as No (labelled Non in 2018).
lcs_scale <- list(
  R01 = c("0" = 1, "1" = 3, "2" = 2, "3" = 1, "4" = 4), R02 = c("1" = 1, "2" = 2, "3" = 3, "4" = 4),
  R03 = c("0" = 1, "1" = 3, "2" = 1, "3" = 2, "4" = 4), R04 = c("1" = 3, "2" = 1, "3" = 2, "4" = 4),
  R05 = c("1" = 3, "2" = 1, "3" = 2, "4" = 4), R06 = c("1" = 1, "2" = 2, "3" = 3, "4" = 4),
  R07 = c("1" = 1, "2" = 2, "3" = 3, "4" = 4), R08 = c("1" = 1, "2" = 2, "3" = 3, "4" = 4),
  R09 = c("1" = 1, "2" = 2, "3" = 3, "4" = 4), R10 = c("1" = 3, "2" = 1, "3" = 2, "4" = 4))
lcs_c <- x[LCS_ALL]
lcs_item_rows <- list()
for (rid in cfg_rounds$round_id) {
  ds <- cfg_rounds$dataset[cfg_rounds$round_id == rid]; here <- which(x$round_id == rid)
  for (v in LCS_ALL) {
    s <- source_of(ds, v)
    if (is.na(s)) { lcs_c[[v]][here] <- 4; lcs_item_rows[[length(lcs_item_rows) + 1]] <- data.frame(item = v, round_id = rid, raw_answered = NA_real_, merged_answered = round(100 * mean(x[[v]][here] != 4), 1), merged_yes = round(100 * mean(x[[v]][here] %in% c(2, 3)), 1), corrected_yes = 0, mapped = FALSE); next }
    r <- as.character(raw_for_round(ds, s)); r[!nzchar(trimws(r))] <- NA
    v2 <- unname(lcs_scale[[rid]][r]); v2[is.na(v2)] <- 4
    lcs_c[[v]][here] <- v2
    lcs_item_rows[[length(lcs_item_rows) + 1]] <- data.frame(item = v, round_id = rid, raw_answered = round(100 * mean(r %in% c("0", "1", "2", "3")), 1),
                                                             merged_answered = round(100 * mean(x[[v]][here] != 4), 1),
                                                             merged_yes = round(100 * mean(x[[v]][here] %in% c(2, 3)), 1), corrected_yes = round(100 * mean(v2 %in% c(2, 3)), 1), mapped = TRUE)
  }
}
lcs_items <- bind_rows(lcs_item_rows)
coping_c <- max_coping(lcs_c)
stress1 <- lcs_items |> filter(item == "LhCSIStress1")
stress1_lost <- stress1$round_id[stress1$merged_answered == 0 & stress1$raw_answered > 0]
add_check("Plausibility", "Every mapped coping strategy keeps its answers", pass_if(!length(stress1_lost)), sprintf("LhCSIStress1 empty in %d rounds", length(stress1_lost)), "None",
          sprintf("LhCSIStress1 (selling non-productive assets) has answers in the raw files but is 4 (Not applicable) for all households in %s.", rounds_txt(stress1_lost)))
ce <- function(v, rid) 100 * mean(v[x$round_id == rid] == 4)
# A round is left unrecoded if its labels say 1 = Oui and the merged codes still equal the raw ones.
scale_state <- bind_rows(lapply(seq_len(nrow(cfg_rounds)), function(i) {
  cr <- cfg_rounds[i, ]; s <- source_of(cr$dataset, "LhCSIEmergency1")
  z <- raw[[cr$dataset]][[s]]; l <- attr(z, "labels")
  yes_first <- !is.null(l) && any(unname(l) == 1 & grepl("^Oui", names(l)))
  r <- as.numeric(raw_for_round(cr$dataset, s)); m <- x$LhCSIEmergency1[x$round_id == cr$round_id]
  zero_to_yes <- sum(vapply(setdiff(LCS_ALL, "LhCSIStress1"), function(v) {
    sv <- source_of(cr$dataset, v); if (is.na(sv)) return(0)
    rv <- suppressWarnings(as.numeric(raw_for_round(cr$dataset, sv))); sum(rv == 0 & x[[v]][x$round_id == cr$round_id] == 3, na.rm = TRUE)
  }, 0))
  data.frame(round_id = cr$round_id, labelled = !is.null(l), yes_first = yes_first, unchanged = mean(r == m, na.rm = TRUE) > .99, zero_to_yes = zero_to_yes)
}))
scale_bad <- scale_state$round_id[scale_state$yes_first & scale_state$unchanged]
zero_bad <- scale_state$round_id[scale_state$zero_to_yes > 0]
unlabelled <- scale_state$round_id[!scale_state$labelled]
add_check("Plausibility", "Coping answers share one scale after recoding", pass_if(!length(scale_bad)), if (length(scale_bad)) rounds_txt(scale_bad) else "All rounds", "All rounds",
          if (length(scale_bad)) sprintf("In %s the file's labels are 1 = Yes, 2 = No need, but the codes pass through unchanged, so No need counts as coping. Emergency coping reads %.1f%%; recoded, it is %.1f%%.",
                                         rounds_txt(scale_bad), ce(x$Max_coping_behaviourFS, scale_bad[1]), ce(coping_c, scale_bad[1])) else "")
add_check("Plausibility", "Raw coping code 0 stays a No", pass_if(!length(zero_bad)), if (length(zero_bad)) rounds_txt(zero_bad) else "All rounds", "All rounds",
          if (length(zero_bad)) paste0("Rmd 05 recodes raw 0 to Yes, although 0 is labelled Non in 2018 and has no label in 2020 PDM. Emergency coping if 0 is No: ",
                                       paste(sprintf("%s %.1f%% merged, %.1f%%", cfg_rounds$label[match(zero_bad, cfg_rounds$round_id)], vapply(zero_bad, function(r) ce(x$Max_coping_behaviourFS, r), 0), vapply(zero_bad, function(r) ce(coping_c, r), 0)), collapse = "; "), ".") else "")
# Codes with no value labels: the scale can only be inferred. Shown as a scenario, never as a correction.
alt_scale <- c("1" = 3, "2" = 1, "3" = 2, "4" = 4); lcs_alt <- lcs_c
for (rid in unlabelled) {
  ds <- cfg_rounds$dataset[cfg_rounds$round_id == rid]; here <- which(x$round_id == rid)
  for (v in LCS_ALL) { s <- source_of(ds, v); if (is.na(s)) next; r <- as.character(raw_for_round(ds, s)); r[!nzchar(trimws(r))] <- NA; a <- unname(alt_scale[r]); a[is.na(a)] <- 4; lcs_alt[[v]][here] <- a }
}
alt_cope <- max_coping(lcs_alt)
add_check("Plausibility", "Every round's coping codes have value labels", pass_if(!length(unlabelled), "warn"), if (length(unlabelled)) rounds_txt(unlabelled) else "All rounds", "All rounds",
          if (length(unlabelled)) sprintf("The file has no labels, and the pipeline reads 2 as already exhausted. Its answers look like the 1 = Yes, 2 = No need scale of the neighbouring rounds. If so, emergency coping is %.1f%%, not %.1f%%. Only the questionnaire can settle this.",
                                          ce(alt_cope, unlabelled[1]), ce(x$Max_coping_behaviourFS, unlabelled[1])) else "")
no_crisis1 <- lcs_items$round_id[lcs_items$item == "LhCSICrisis1" & !lcs_items$mapped]
add_check("Plausibility", "All 10 coping strategies have a source in all rounds", pass_if(!length(no_crisis1), "warn"), sprintf("%d rounds with 9 strategies", length(no_crisis1)), "0",
          sprintf("LhCSICrisis1 (selling productive assets) has no source in %s, so crisis coping rests on fewer strategies there.", rounds_txt(no_crisis1)))

# Household size, dates, labels, documentation
hh_big <- x |> group_by(round_id) |> summarise(n = sum(HHSize > 30), mx = max(HHSize)) |> filter(n > 0)
add_check("Plausibility", "Household size is below 30", pass_if(!nrow(hh_big), "warn"), sprintf("%d households", sum(hh_big$n)), "0",
          sprintf("%s. Largest: %d. Means are distorted: 2022 PDM averages %.1f members, %.1f without them.",
                  paste(sprintf("%s: %d", cfg_rounds$label[match(hh_big$round_id, cfg_rounds$round_id)], hh_big$n), collapse = ", "), max(hh_big$mx),
                  mean(x$HHSize[x$round_id == "R07"]), mean(x$HHSize[x$round_id == "R07" & x$HHSize <= 30])))
hh_zero <- sum(x$HHSize == 0)
add_check("Plausibility", "Household size is at least 1", pass_if(hh_zero == 0, "warn"), hh_zero, "0 households", "Size is the sum of the composition variables, so an empty composition gives 0.")
dts <- as.Date(x$SvyDate)
date_tab <- cfg_rounds |> rowwise() |> mutate(
  outside = { d <- dts[x$round_id == round_id]; sum(d < as.Date(expected_start) | d > as.Date(expected_end), na.rm = TRUE) },
  missing = sum(is.na(dts[x$round_id == round_id]))) |> ungroup()
add_check("Plausibility", "Interview dates fall in the round's fieldwork", pass_if(sum(date_tab$outside) == 0, "warn"), sprintf("%d outside, %d missing", sum(date_tab$outside), sum(date_tab$missing)), "0",
          "The month is imputed before the link to Cadre Harmonisé, so these dates do not change the phase.")
mont_lab <- attr(raw$Chad_ea_2019[[source_of("Chad_ea_2019", "Montant")]], "label", exact = TRUE)
mont_wrong <- grepl("income", final_var_labels[["Montant"]], ignore.case = TRUE)
add_check("Documentation", "Montant keeps its meaning", pass_if(!mont_wrong, "warn"), if (mont_wrong) "Label changed" else "Kept", "Cash received",
          sprintf("The source question is about cash received at the last distribution (%s...); the merged file labels it \"%s\".", substr(clean_text(mont_lab), 1, 45), final_var_labels[["Montant"]]))

# ---- The 2026 modules ---------------------------------------------------------------------------
say("2026 modules...")
# Food share: recomputed from the analysts' totals, compared with their own share (a fraction in 2021, a percentage after).
share_agree <- bind_rows(lapply(cfg_rounds$round_id[cfg_rounds$round >= 6], function(rid) {
  ds <- cfg_rounds$dataset[cfg_rounds$round_id == rid]; a <- as.numeric(raw_for_round(ds, "FoodExp_share")); if (rid != "R06") a <- a / 100
  b <- x$ExpFoodShare[x$round_id == rid]; k <- !is.na(a) & !is.na(b)
  data.frame(round_id = rid, compared = sum(k), same = sum(abs(a[k] - b[k]) < 0.001))
}))
add_check("New modules", "Food share recomputed from the totals equals the analysts' share", pass_if(all(share_agree$same / share_agree$compared > 0.99)),
          sprintf("%.1f%% of %s households", 100 * sum(share_agree$same) / sum(share_agree$compared), format(sum(share_agree$compared), big.mark = ",")), "Over 99% in each round",
          "The analysts' share is a fraction in 2021 annual and a percentage from 2022: the recomputed share uses one rule for all rounds.")
shk_types <- sub("^Shk12m_", "", grep("^Shk12m_", names(x), value = TRUE))
shk_gap <- sum(vapply(shk_types, function(s) sum(is.na(x[[paste0("Shk12m_", s)]]) & !is.na(x[[paste0("Shk5yN_", s)]])), 0))
add_check("New modules", "Every shock counted over 5 years has a 12-month answer", pass_if(shk_gap == 0), shk_gap, "0 gaps",
          "The 12-month question was asked only when the 5-year count was above 0; Rmd 16 sets it to No otherwise.")
mig_top <- x |> filter(!is.na(MigMainReason)) |> count(round_id, MigMainReason) |> group_by(round_id) |> slice_max(n, n = 1, with_ties = FALSE) |> ungroup()
add_check("New modules", "Migration reasons line up across rounds", pass_if(n_distinct(mig_top$MigMainReason) == 1),
          sprintf("Most frequent reason: code %s in %d rounds", paste(unique(mig_top$MigMainReason), collapse = "/"), nrow(mig_top)), "The same reason in every round",
          "In 2021 and 2022 the lists start with an empty code, which shifts every answer by one. Rmd 23 matches the answers by label; economic opportunities should lead everywhere.")
cog <- vapply(cfg_rounds$dataset[cfg_rounds$round >= 6], function(ds) { l <- attr(raw[[ds]][[source_any(ds, "DisCognition")]], "label", exact = TRUE); if (is.null(l)) "" else l }, "")
add_check("New modules", "The cognition question is the one mapped to DisCognition", pass_if(any(grepl("cognitiv", cog, ignore.case = TRUE)), "warn"),
          sprintf("%d of 5 rounds label it cognitive", sum(grepl("cognitiv", cog, ignore.case = TRUE))), "Labelled in every round",
          "Its raw name, difficultes_entendre, suggests hearing, but hearing is asked separately (difficultes_audition), and the 2023 labels describe memory or concentration. The 2021 and 2022 files have no question labels to confirm it.")
girls_bad <- sum(x$EduGirlsPrimarySupported > x$EduGirlsPrimary, na.rm = TRUE) + sum(x$EduGirlsSecondarySupported > x$EduGirlsSecondary, na.rm = TRUE)
girls_amount <- sum(x$EduGirlsPrimarySupported >= 100 | x$EduGirlsSecondarySupported >= 100 | x$EduGirlsSecondary >= 100, na.rm = TRUE)
add_check("New modules", "Girls supported do not outnumber girls at school", pass_if(girls_bad == 0, "warn"), sprintf("%d households", girls_bad), "0",
          sprintf("%d households have 100 or more girls, up to %s: money amounts entered in a count. The Dataverse package top-codes these counts at 5.", girls_amount,
                  format(max(c(x$EduGirlsPrimarySupported, x$EduGirlsSecondarySupported, x$EduGirlsSecondary), na.rm = TRUE), big.mark = ",")))
area_big <- sum(x$AgrAreaCultivated > 100 | x$AgrAreaOwned > 100, na.rm = TRUE)
add_check("New modules", "Farm areas are plausible in hectares", pass_if(area_big == 0, "warn"), sprintf("%d households above 100 ha", area_big), "0",
          sprintf("The 2022 and 2023 questionnaires record no unit; the areas are taken as hectares (median %.1f). The largest, up to %s, are probably square metres.",
                  stats::median(x$AgrAreaCultivated[x$round_id %in% c("R07", "R08", "R09", "R10")], na.rm = TRUE), format(max(x$AgrAreaOwned, na.rm = TRUE), big.mark = ",")))
months_big <- sum(x$AgrMonthsOwnProduction > 24, na.rm = TRUE)
add_check("New modules", "Months covered by own production stay within two years", pass_if(months_big == 0, "warn"), sprintf("%d households", months_big), "0",
          sprintf("Values reach %s. Kept as reported in the merged file; the Dataverse package top-codes them at 12.", format(max(x$AgrMonthsOwnProduction, na.rm = TRUE), big.mark = ",")))

# Assistance: are harmonised answers the original answers?
say("Assistance...")
assist_vars <- cfg_interv$variable
assist_rows <- bind_rows(lapply(assist_vars, function(v) x |> group_by(round_id) |> summarise(
  variable = v, yes = sum(.data[[v]] == 1, na.rm = TRUE), no = sum(.data[[v]] == 2, na.rm = TRUE), dont_know = sum(.data[[v]] == 3, na.rm = TRUE),
  answered = sum(!is.na(.data[[v]])), households = n()))) |>
  mutate(yes_pct = ifelse(answered > 0, round(100 * yes / answered, 1), NA), answered_pct = round(100 * answered / households, 1))
assist_region <- bind_rows(lapply(assist_vars, function(v) x |> group_by(round_id, region = ADMIN1Name) |> summarise(
  variable = v, answered = sum(!is.na(.data[[v]])), yes = sum(.data[[v]] == 1, na.rm = TRUE), .groups = "drop"))) |>
  mutate(yes_pct = ifelse(answered >= MIN_CELL, round(100 * yes / answered, 1), NA)) |> select(round_id, region, variable, answered, yes_pct) |>
  filter(answered > 0)
audit_rows <- list()
for (v in setdiff(assist_vars, c("VivreContreTravail", "ArgentContreTravail"))) for (i in 2:10) {
  o <- paste0(v, i)
  if (!o %in% names(final_lab)) next
  here <- x$ROUND == i
  orig <- final_lab[[o]][here]
  # The 2020 PDM training composite built in do-file 13 is already labelled yes/no.
  oy <- (if (is.character(orig)) orig else as.character(haven::as_factor(orig))) %in% c("Oui", "yes")
  oy[is.na(orig)] <- NA
  h <- x[[v]][here]; k <- !is.na(oy) & !is.na(h)
  if (!any(k)) next
  audit_rows[[length(audit_rows) + 1]] <- data.frame(variable = v, round_id = rid_of(i), compared = sum(k), same = sum(oy[k] == (h[k] == 1)))
}
assist_audit <- bind_rows(audit_rows) |> mutate(pct_same = round(100 * same / compared, 1))
add_check("Assistance", "Harmonised Yes equals the original Oui", pass_if(all(assist_audit$pct_same == 100), "warn"),
          sprintf("%d of %d variable x round pairs identical", sum(assist_audit$pct_same == 100), nrow(assist_audit)), "All",
          "Against the original answers kept in the merged file. Food for assets and cash for assets are left out: they are recoded on purpose.")
vct <- x$VivreContreTravail
add_check("Assistance", "Food for assets recoded to cash, as advised by WFP Chad", pass_if(sum(vct == 1, na.rm = TRUE) == 0), sum(vct == 1, na.rm = TRUE), "0 Yes", "Food for assets ended, but the name stayed while payments were in cash; these households are counted under cash for assets.")
documented <- cfg_interv |> rowwise() |> mutate(documented = list(as.integer(strsplit(documented_rounds, ";")[[1]]))) |> ungroup()
doc_diff <- bind_rows(lapply(seq_len(nrow(documented)), function(i) {
  v <- documented$variable[i]; have <- which(vapply(1:10, function(r) sum(!is.na(x[[v]][x$ROUND == r])) > 0, TRUE))
  bind_rows(lapply(union(setdiff(have, documented$documented[[i]]), setdiff(documented$documented[[i]], have)), function(r)
    data.frame(variable = v, round_id = rid_of(r), status = if (r %in% have) "In the data, not in the report" else "In the report, not in the data")))
}))
add_check("Documentation", "The Issues report's Table 1 matches the data", pass_if(!nrow(doc_diff), "warn"), sprintf("%d cells differ", nrow(doc_diff)), "0 cells",
          "Table 1 of the Word report on assistance variables, against the rounds with answers in the merged file.")

# MAD and MDDW: built, not merged.
say("MAD and MDDW...")
nut_files <- data.frame(
  module = rep(c("MAD", "MDDW"), each = 5),
  file = c(paste0("consent_PCMADRepeat623_", c("Decembre_2021", "Juillet_2022", "Decembre_2022", "Juillet_2023", "Decembre_2023"), ".sav"),
           paste0("consent_HHSize1549F_MDDW_rpt_", c("Decembre_2021", "Juillet_2022", "Decembre_2022", "Juillet_2023", "Decembre_2023"), ".sav")),
  round_id = rep(c("R06", "R07", "R08", "R09", "R10"), 2), stringsAsFactors = FALSE)
nut_files$rows <- vapply(nut_files$file, function(f) nrow(haven::read_sav(file.path(DIR_INPUT, "MAD_MDDW data", f))), 0L)
nut_in_final <- any(grepl("^PCMAD|^PWMDDW", names(x)))
nut_mod <- lapply(c(MAD = "WFP_Chad_MAD", MDDW = "WFP_Chad_MDDW"), function(f) as.character(haven::read_dta(file.path(DIR_MODULES, paste0(f, ".dta")), col_select = "ID")$ID))
nut_counts <- bind_rows(lapply(names(nut_mod), function(m) as.data.frame(table(round_id = x$round_id[match(nut_mod[[m]], x$ID)]), responseName = "module_rows", stringsAsFactors = FALSE) |> mutate(module = m)))
nutrition <- nut_files |> select(module, round_id, raw_rows = rows) |> left_join(nut_counts, by = c("module", "round_id"))
nut_more <- nutrition |> filter(module_rows != raw_rows)
# Why the module files hold too many rows: the household index the repeat files point to is not unique.
nut_index <- vapply(c("Chad_ea_2021", "Chad_pdm_2022", "Chad_ea_2022", "Chad_pdm_2023", "Chad_ea_2023"), function(ds) {
  h <- raw[[ds]]; i <- haven::zap_labels(h$`@_index`); f <- haven::zap_labels(h$`@_xform_id`)
  c(unique_index = !anyDuplicated(i), forms = length(unique(f)))
}, c(unique_index = TRUE, forms = 0))
bad_link <- colnames(nut_index)[!as.logical(nut_index["unique_index", ])]
add_check("Merge", "MAD and MDDW module files have the rows of their raw repeat files", pass_if(!nrow(nut_more), "warn"), sprintf("%d of %d differ", nrow(nut_more), nrow(nutrition)), "0",
          sprintf("In %s the household file combines %s survey forms, each numbering its households from 1, and the repeat files lost the form identifier. Children and women then match several households, which inflates the module files. Only 2023 Annual links cleanly.",
                  rounds_txt(cfg_rounds$round_id[match(bad_link, cfg_rounds$dataset)]), paste(range(nut_index["forms", bad_link]), collapse = " to ")))
add_check("Merge", "MAD and MDDW are in the merged file", pass_if(nut_in_final, "warn"), if (nut_in_final) "Yes" else "No", "Yes",
          sprintf("Rmds 09 and 10 build them (%s child and %s woman rows), but they are left out of the merge and of the release until their link to households is rebuilt.",
                  format(length(nut_mod$MAD), big.mark = ","), format(length(nut_mod$MDDW), big.mark = ",")))

# ---- Indicators ---------------------------------------------------------------------------------
say("Indicators...")
x$fcs_c <- ifelse(x$round_id %in% binary_rounds, x$SCA, x$FCS)
x$fcat_c <- ifelse(x$fcs_c <= 28, 1, ifelse(x$fcs_c <= 42, 2, 3))
x$rcsi_c <- rcsi_true; x$abi_c <- abi_true; x$coping_c <- coping_c
x$hhsize_c <- ifelse(x$HHSize > 30, NA, x$HHSize)

pct <- function(cond) if (all(is.na(cond))) NA_real_ else 100 * mean(cond, na.rm = TRUE)
avg <- function(v) if (all(is.na(v))) NA_real_ else mean(v, na.rm = TRUE)
valid <- function(v) sum(!is.na(v))
indicators <- function(d) {
  tibble(
    households = nrow(d),
    fcs_pb_m = pct(d$FCSCat28 <= 2), fcs_pb_c = pct(d$fcat_c <= 2), fcs_poor_m = pct(d$FCSCat28 == 1), fcs_poor_c = pct(d$fcat_c == 1),
    fcs_border_m = pct(d$FCSCat28 == 2), fcs_border_c = pct(d$fcat_c == 2), fcs_accept_m = pct(d$FCSCat28 == 3), fcs_accept_c = pct(d$fcat_c == 3),
    fcs_mean_m = avg(d$FCS), fcs_mean_c = avg(d$fcs_c),
    rcsi_mean_m = avg(d$rCSI), rcsi_mean_c = avg(d$rcsi_c), rcsi_p3_m = pct(d$rCSI >= 19), rcsi_p3_c = pct(d$rcsi_c >= 19),
    lcs_none_m = pct(d$Max_coping_behaviourFS == 1), lcs_none_c = pct(d$coping_c == 1), lcs_stress_m = pct(d$Max_coping_behaviourFS == 2), lcs_stress_c = pct(d$coping_c == 2),
    lcs_crisis_m = pct(d$Max_coping_behaviourFS == 3), lcs_crisis_c = pct(d$coping_c == 3), lcs_em_m = pct(d$Max_coping_behaviourFS == 4), lcs_em_c = pct(d$coping_c == 4),
    lcs_ce_m = pct(d$Max_coping_behaviourFS >= 3), lcs_ce_c = pct(d$coping_c >= 3),
    hdds_mean_m = avg(d$HDDS_hema), hdds_mean_c = avg(d$HDDS_hema), hdds_low_m = pct(d$HDDS_hema <= 4), hdds_low_c = pct(d$HDDS_hema <= 4),
    abi_mean_m = avg(d$ABIScore), abi_mean_c = avg(d$abi_c),
    rcs_mean_m = avg(d$RCS), rcs_mean_c = avg(d$RCS), rcs_low_m = pct(d$RCSCat33 == 1), rcs_low_c = pct(d$RCSCat33 == 1), rcs_high_m = pct(d$RCSCat33 == 3), rcs_high_c = pct(d$RCSCat33 == 3),
    ch_p3_m = pct(d$phase_class >= 3), ch_p3_c = pct(d$phase_class >= 3),
    female_head_m = pct(d$HHHSex == 1), female_head_c = pct(d$HHHSex == 1), hh_size_m = avg(d$HHSize), hh_size_c = avg(d$hhsize_c)
  ) |> bind_cols(both(new_indicators(d)))
}
# The 2026 modules: no indicative correction, so as merged and corrected are the same.
new_indicators <- function(d) {
  mig <- ifelse(d$MigWork12m == 888, NA, d$MigWork12m)
  tibble(
    shk_any12m = pct(d$ShkAny12m == 1), shk_any6m = pct(d$ShkAny6m == 1), shk_drought = pct(d$Shk12m_Drought == 1), shk_price = pct(d$Shk12m_FoodPriceRise == 1),
    lvs_any = pct(d$LvsTLU > 0), lvs_tlu = avg(d$LvsTLU), ast_radio = pct(d$AstRadio == 1), ast_phone = pct(d$AstPhone == 1),
    liv_nsrc = avg(d$LivNbIncomeSources), liv_farm = pct(d$LivIncomeSource1 == 1),
    agr_practice = pct(d$AgrPractice == 1), agr_owner = pct(d$AgrLandTenure == 1), agr_6m = pct(d$AgrMonthsOwnProduction >= 6),
    exp_share = avg(100 * d$ExpFoodShare), exp_share75 = pct(d$ExpFoodShare >= 0.75),
    dis_any = pct(d$DisAny == 1),
    edu_primary = pct(d$EduChildrenPrimary == 1), edu_girls = pct(d$EduGirlsPrimary > 0),
    mig_work = pct(mig == 1),
    prt_any = pct(d$PrtAnyProblem == 1), aap_informed = pct(d$AapInformed == 1), aap_complaint = pct(d$AapComplaintFiled == 1),
    aap_women = pct(ifelse(is.na(d$AapDecideAssistance), NA, d$AapDecideAssistance %in% c(2, 3))),
    dbt_contracted = pct(d$DbtContracted == 1), dbt_current = pct(ifelse(d$DbtCurrent == 888, NA, d$DbtCurrent) == 1),
    coh_hosts_good = pct(d$CohRelationHosts >= 4), coh_tension = pct(d$CohTensionsReduced == 1), coh_nobody = pct(d$CohCouldHelpNobody == 1),
    adp_apply_any = pct(d$AdpApplyAny == 1), adp_trained = pct(ifelse(d$AdpTrainedAgriculture == 888, NA, d$AdpTrainedAgriculture) == 1),
    adp_compost = pct(d$AdpPracticeCompostPits == 1),
    shk_rec_drought = pct(ifelse(is.na(d$ShkRecNow_Drought), NA, d$ShkRecNow_Drought >= 2)),
    eff_income_up = pct(ifelse(is.na(d$EffChanged_Income), NA, d$EffDirection_Income %in% 3)),
    mkt_difficult = pct(d$MktAccessDifficult == 1), mkt_sold = pct(d$MktSoldProduce == 1),
    aap_satisfied = pct(d$AapSatisfied == 1), aap_contact = pct(d$AapKnowHowToContact == 1),
    fsn_not_enough = pct(d$FsnNotEnoughFood30d == 1)
  )
}
both <- function(t) { m <- setNames(t, paste0(names(t), "_m")); c <- setNames(t, paste0(names(t), "_c")); bind_cols(m, c) }
ind_round <- x |> group_by(round_id) |> group_modify(~ indicators(.x)) |> ungroup()
ind_region <- x |> group_by(round_id, region = ADMIN1Name) |> group_modify(~ indicators(.x)) |> ungroup()
# Small cells: below MIN_CELL households, no estimate leaves this script.
est_cols <- grep("_[mc]$", names(ind_region), value = TRUE)
ind_region[ind_region$households < MIN_CELL, est_cols] <- NA
ind_round <- mutate(ind_round, across(all_of(est_cols), ~ round(.x, 2)))
ind_region <- mutate(ind_region, across(all_of(est_cols), ~ round(.x, 2)))

# Departments: households only, cells under the threshold not shown.
admin2 <- x |> group_by(region = ADMIN1Name, department = ADMIN2Name, round_id) |> summarise(households = n(), .groups = "drop") |>
  mutate(households = ifelse(households < MIN_CELL, NA, households), small_cell = is.na(households))

ch_phase <- x |> filter(!is.na(phase_class)) |> group_by(round_id, phase = phase_class) |>
  summarise(households = n(), districts = n_distinct(IP_var), .groups = "drop")

# ---- Flags: which indicator cells the app hatches. Computed from the checks, so a fix clears them. --
# fixed = TRUE: the indicative corrections rebuild the value. FALSE: they cannot, so it stays flagged.
flag <- function(group, rids, reason, fixed = TRUE) if (length(rids)) data.frame(indicator_group = group, round_id = rids, reason = reason, fixed = fixed)
hh_rounds <- x |> group_by(round_id) |> summarise(n = sum(HHSize > 30)) |> filter(n > 0) |> pull(round_id)
flags <- bind_rows(
  flag("fcs", binary_rounds, "The day counts of this round are 0/1 flags, not days, so the FCS cannot exceed about 16."),
  flag("rcsi", rcsi_map_bad, "rCSIBorrow is mapped to the rCSILessQlty column."),
  flag("lcs", zero_bad, "Raw code 0 is recoded to Yes."),
  flag("lcs", scale_bad, "The answer scale is not recoded: code 2 (No need) counts as coping."),
  flag("lcs", unlabelled, "The codes have no value labels, and may follow the 1 = Yes scale. Check against the questionnaire.", FALSE),
  flag("abi", abi_zero, "The recode turns every answer into 0, so the score is 0 for all households."),
  flag("hhsize", hh_rounds, "Household composition holds impossible values (households above 30 members).")
)

# ---- Rounds table -------------------------------------------------------------------------------
fw <- x |> mutate(d = dts) |> group_by(round_id) |> summarise(
  date_p01 = as.Date(stats::quantile(d, .01, type = 1, na.rm = TRUE)), date_median = as.Date(stats::median(d, na.rm = TRUE)),
  date_p99 = as.Date(stats::quantile(d, .99, type = 1, na.rm = TRUE)), linked_month = paste(sort(unique(SvyMonth)), collapse = ", "),
  regions = n_distinct(ADMIN1Name), departments = n_distinct(ADMIN2Name), villages = n_distinct(village), gps_pct = round(100 * mean(!is.na(Longitude)), 1))
rounds <- cfg_rounds |> left_join(flow, by = "round_id") |> left_join(fw, by = "round_id") |>
  left_join(select(date_tab, round_id, dates_outside = outside, dates_missing = missing), by = "round_id") |>
  mutate(raw_file = de$Data[match(dataset, de$Name)])

# ---- Final dataset's columns --------------------------------------------------------------------
col_family <- function(v) {
  # Columns of the 2026 modules: those in the extension workbook and those derived from them (ShkAny12m, LvsTLU...)
  new_mod <- v %in% ext$NewVariable_Name | grepl("^(Shk|Ast|Lvs|Liv|Agr|Exp|Dis|Edu|Mig|Prt|Aap|Dbt|Coh|Adp|Eff|Mkt|Fsn)[A-Z0-9_]", v)
  derived_ext <- ifelse(new_mod, prefix_family(v), NA_character_)
  dplyr::case_when(
    !is.na(derived_ext) ~ derived_ext,
    grepl("^cost_", v) ~ "Costs",
    grepl("^(exercise|reference|adm[012]_name|adm[012]_pcod|chtype|population|phase|p_phase|IP_var)", v) ~ "Cadre Harmonisé",
    v %in% c("ID", "SvyDate", "YEAR", "SvyMonth", "SURVEY", "ROUND", "round_id") ~ "Identification",
    v %in% c("ADMIN0Name", "adm0_ocha", "ADMIN1Name", "adm1_ocha", "ADMIN2Name", "adm2_ocha", "village", "Longitude", "Latitude", "Longitude_precision", "Latitude_precision") ~ "Geography",
    grepl("^HDDS", v) ~ "Dietary diversity (HDDS)",
    grepl("^HH(RCS)|^RCS|^SERS", v) ~ "Resilience (SERS / RCS)",
    grepl("^ABI|^HHAsset|^HHFFA|^HHTraining|^HHWork|^Actif|^BeneficieEmploi|^TRavail", v) ~ "Asset benefit (ABI)",
    grepl("^HH", v) ~ "Household",
    grepl("^FCS|^SCA$", v) ~ "Food consumption (FCS)",
    grepl("^rCSI", v) ~ "Reduced coping (rCSI)",
    grepl("^LhCSI|coping", v) ~ "Livelihood coping (LCS)",
    grepl("[0-9]$", v) & sub("[0-9]+$", "", v) %in% cfg_interv$variable ~ "Assistance: original answers",
    v %in% cfg_interv$variable | grepl("Montant|DateDerniere", v) ~ "Assistance: harmonised",
    TRUE ~ "Other"
  )
}
vars_final <- setdiff(names(final_lab), character(0))
final_cols <- data.frame(variable = vars_final, family = col_family(vars_final), label = unname(final_var_labels[vars_final]), stringsAsFactors = FALSE)
sensitive_cols <- c("Longitude", "Latitude", "Longitude_precision", "Latitude_precision", "village", "ID")
final_cov <- bind_rows(lapply(vars_final, function(v) {
  z <- x[[v]]; nm <- if (is.character(z)) !is.na(z) & nzchar(trimws(z)) else !is.na(z)
  data.frame(variable = v, round_id = x$round_id, nm = nm) |> group_by(variable, round_id) |> summarise(pct = round(100 * mean(nm), 1), .groups = "drop")
}))
final_cols <- final_cols |> left_join(final_cov |> group_by(variable) |> summarise(rounds_with_data = sum(pct > 0)), by = "variable")
family_cov <- final_cov |> left_join(select(final_cols, variable, family), by = "variable") |> group_by(family, round_id) |>
  summarise(pct = round(mean(pct), 1), columns_with_data = sum(pct > 0), .groups = "drop")

# ---- Every column of the merged file: summaries by round, for the Variables page -----------------
# Identifying columns get completeness only. Answer counts under 5 households are not written.
say("Summarising all %d columns...", length(vars_final))
MIN_VALUE_COUNT <- 5
HIDDEN_VALUES <- c("ID", "village", "Longitude", "Latitude", "Longitude_precision", "Latitude_precision", "DateDerniereAssist_other", "IP_var", "SvyDate")
kind_of <- function(v) {
  z <- x[[v]]
  if (v %in% HIDDEN_VALUES) return("hidden")
  if (is.character(z)) return("categorical")
  if (!is.null(attr(final_lab[[v]], "labels")) || length(unique(z[!is.na(z)])) <= 15) return("categorical")
  "numeric"
}
var_kind <- vapply(vars_final, kind_of, "")
final_cols$kind <- unname(var_kind[final_cols$variable])
final_cols$type <- vapply(final_cols$variable, function(v) if (is.character(x[[v]])) "text" else if (inherits(x[[v]], "Date")) "date" else "number", "", USE.NAMES = FALSE)
final_cols$coverage <- vapply(final_cols$variable, function(v) { z <- x[[v]]; round(100 * mean(if (is.character(z)) !is.na(z) & nzchar(trimws(z)) else !is.na(z)), 1) }, 0, USE.NAMES = FALSE)
final_cols$value_labels <- vapply(final_cols$variable, function(v) {
  if (v %in% HIDDEN_VALUES) return(NA_character_)
  l <- attr(final_lab[[v]], "labels")
  if (is.null(l)) NA_character_ else substr(clean_text(paste(paste0(l, " = ", names(l)), collapse = "; ")), 1, 400)
}, "", USE.NAMES = FALSE)
variable_values <- bind_rows(lapply(vars_final[var_kind == "categorical"], function(v) {
  z <- x[[v]]; if (is.character(z)) z[!nzchar(trimws(z))] <- NA
  l <- attr(final_lab[[v]], "labels")
  d <- data.frame(round_id = x$round_id, value = as.character(z), stringsAsFactors = FALSE)
  d <- d[!is.na(d$value), , drop = FALSE]
  if (!nrow(d)) return(NULL)
  out <- d |> count(round_id, value, name = "households") |> group_by(round_id) |> mutate(answered = sum(households)) |> ungroup()
  out$variable <- v
  out$label <- if (is.null(l)) out$value else { k <- match(out$value, as.character(unname(l))); ifelse(is.na(k), out$value, clean_text2(names(l)[k])) }
  out$suppressed <- out$households < MIN_VALUE_COUNT
  out$pct <- ifelse(out$suppressed, NA, round(100 * out$households / out$answered, 1))
  out$households[out$suppressed] <- NA
  out[, c("variable", "round_id", "value", "label", "households", "answered", "pct", "suppressed")]
}))
variable_numeric <- bind_rows(lapply(vars_final[var_kind == "numeric"], function(v) {
  bind_rows(lapply(cfg_rounds$round_id, function(r) {
    z <- as.numeric(x[[v]][x$round_id == r]); z <- z[!is.na(z)]
    if (length(z) < MIN_VALUE_COUNT) return(NULL)
    q <- stats::quantile(z, c(.1, .5, .9), names = FALSE, type = 7)
    data.frame(variable = v, round_id = r, answered = length(z), mean = round(mean(z), 2), p10 = round(q[1], 2), median = round(q[2], 2), p90 = round(q[3], 2), min = round(min(z), 2), max = round(max(z), 2))
  }))
}))

# Place-name corrections, from the do-file and the module files.
do_lines <- readLines(file.path(REPO, "merge", "12_WFP_Chad_CBA_data_preparation.do"), warn = FALSE, encoding = "UTF-8")
admin_block <- do_lines[seq(grep("Correct inconsistencies in Village and Admin 2", do_lines)[1], grep("save \"\\$output_data\\\\WFP_Chad_admin.dta\"", do_lines)[1])]
places <- data.frame(
  measure = c("Village names before cleaning", "Village names in the merged file", "Households with no usable village name", "Households without a department before cleaning",
              "Households without a department in the merged file", "Village correction lines in the do-file", "Department correction lines in the do-file", "Region correction lines in the do-file"),
  value = c(n_distinct(adm_pre$village), n_distinct(x$village), sum(is.na(x$village) | x$village %in% c("", "UNKNOWN")), sum(is.na(adm_pre$ADMIN2Name) | adm_pre$ADMIN2Name == ""),
            sum(is.na(x$ADMIN2Name) | x$ADMIN2Name == ""), sum(grepl("^\\s*replace village", admin_block)), sum(grepl("^\\s*replace (ADMIN2Name|adm2_ocha)", admin_block)), sum(grepl("^\\s*replace (ADMIN1Name|adm1_ocha)", admin_block))))

# ---- Provenance ---------------------------------------------------------------------------------
say("Hashing inputs...")
hash_row <- function(path, role, round_id = NA) data.frame(role = role, round_id = round_id, file = basename(path), size_mb = round(file.size(path) / 1e6, 2),
                                                           modified = format(file.mtime(path), "%Y-%m-%d"), sha256 = digest::digest(file = path, algo = "sha256"))
inputs <- bind_rows(
  bind_rows(lapply(seq_len(nrow(rounds)), function(i) hash_row(file.path(DIR_INPUT, rounds$raw_file[i]), "Raw survey file", rounds$round_id[i]))),
  hash_row(wb_path, "Harmonisation workbook"),
  hash_row(ext_path, "Harmonisation workbook, 2026 modules"),
  bind_rows(lapply(cfg_modules$module, function(m) hash_row(mod_path(m), if (mod_new[[m]]) "Module file (2026)" else "Cleaned module file"))),
  hash_row(file.path(DIR_MERGED, FINAL_FILE), "Merged dataset"),
  bind_rows(lapply(c("12_WFP_Chad_CBA_data_preparation.do", "13_WFP_Chad_OriginalAssistenciesVariables.do", "14_WFP_Chad_fix_rCSIBorrow.do",
                     "15_WFP_Chad_fix_FCS_2020PDM.do", "16_WFP_Chad_add_new_modules.do", "17_WFP_Chad_add_more_modules.do",
                     "18_WFP_Chad_add_protection_debt.do", "19_WFP_Chad_add_cohesion_adaptation.do", "20_WFP_Chad_add_recovery_effects_markets.do",
                     "21_WFP_Chad_add_costs.do"),
                   function(f) hash_row(file.path(REPO, "merge", f), "Merge code"))),
  bind_rows(lapply(c("prepare_cost_data.R", "prepare_community_costs.R", "prepare_household_costs.R", "prepare_household_cost_module.R",
                     "household_unit_costs.csv", "exchange_rates.csv", "department_crosswalk.csv", "activity_categories.csv", "cost_variables.csv"),
                   function(f) hash_row(file.path(REPO, "costs", f), "Cost code and rules"))))

# ---- Crosswalk workbook for download ------------------------------------------------------------
wide <- crosswalk |> select(variable, round_id, source) |> mutate(round = cfg_rounds$label[match(round_id, cfg_rounds$round_id)]) |>
  select(-round_id) |> pivot_wider(names_from = round, values_from = source)
writexl::write_xlsx(list(
  Crosswalk = left_join(select(crosswalk_summary, Family = family, Variable = variable, `Rounds mapped` = rounds_mapped, `In merged file` = in_final), wide, by = c(Variable = "variable")),
  Details = crosswalk |> transmute(Family = family, Variable = variable, Round = cfg_rounds$label[match(round_id, cfg_rounds$round_id)], Source = source, Type = type, `Coverage %` = coverage, Range = range, Label = label, `Value labels` = value_labels),
  `Merged file columns` = final_cols,
  Rounds = rounds |> select(Round = label, Survey = survey, Series = series, `Raw file` = raw_file, `Raw rows` = raw_rows, `Merged rows` = final_rows)
), file.path(OUT, "WFP_Chad_crosswalk_2018-2023.xlsx"))

# ---- Costs: tables built by costs/prepare_cost_data.R. Activity texts, which name villages, stay out. ----
DIR_COSTS <- file.path(DIR_MERGED, "cost data clean")
COST_TABLES <- c("cost_reconciliation", "cost_by_category", "cost_by_area", "cost_by_partner", "cost_lump_sum_activities", "cost_survey_link", "cost_department_crosswalk", "composition_usd")
absent_costs <- COST_TABLES[!file.exists(file.path(DIR_COSTS, paste0(COST_TABLES, ".csv")))]
if (length(absent_costs)) stop("Run Rscript costs/prepare_cost_data.R from the repository's root first. Missing: ", paste(absent_costs, collapse = ", "), call. = FALSE)
for (t in COST_TABLES) {
  ct <- readr::read_csv(file.path(DIR_COSTS, paste0(t, ".csv")), show_col_types = FALSE)
  if ("activity" %in% names(ct)) stop("Activity text in ", t, call. = FALSE)
  write_out(ct, paste0(t, ".csv"))
}

# ---- Costs per household: the 44 cost variables of the merged file (do-file 21), as aggregates --------
say("Costs per household...")
cost_vars <- grep("^cost_", names(x), value = TRUE)
codebook <- readr::read_csv(file.path(REPO, "costs", "cost_variables.csv"), show_col_types = FALSE)
add_check("Costs", "The cost dictionary describes exactly the cost variables", pass_if(setequal(codebook$variable, cost_vars)),
          sprintf("%d variables, %d documented", length(cost_vars), nrow(codebook)), "Same set", "costs/cost_variables.csv against the merged file.")
asset_vars <- grep("^cost_asset_", cost_vars, value = TRUE)
item_vars <- setdiff(grep("^cost_.*_xaf$", cost_vars, value = TRUE), c(asset_vars, grep("^cost_(comm|vill|area|interv|total)", cost_vars, value = TRUE)))
gap_asset <- max(abs(rowSums(x[asset_vars]) - x$cost_comm_transfer_xaf - x$cost_comm_capacity_xaf), na.rm = TRUE)
gap_item <- max(abs(rowSums(x[item_vars], na.rm = TRUE) - x$cost_interv_xaf), na.rm = TRUE)
gap_total <- max(abs(x$cost_comm_transfer_xaf + x$cost_comm_capacity_xaf + x$cost_interv_xaf - x$cost_total_xaf), na.rm = TRUE)
add_check("Costs", "Asset types add up to the community cost", pass_if(gap_asset < 0.1), sprintf("Largest gap %.2f XAF", gap_asset), "Under 0.1 XAF (rounding)",
          sprintf("%d asset columns against transfer + capacity, household by household.", length(asset_vars)))
add_check("Costs", "Interventions add up to their total", pass_if(gap_item < 0.1), sprintf("Largest gap %.2f XAF", gap_item), "Under 0.1 XAF (rounding)",
          sprintf("%d intervention columns against cost_interv_xaf.", length(item_vars)))
add_check("Costs", "The total cost is community plus interventions", pass_if(gap_total < 0.1), sprintf("Largest gap %.2f XAF", gap_total), "Under 0.1 XAF")
add_check("Costs", "No cost before the programme years", pass_if(all(is.na(x$cost_comm_source[x$round_id == "R01"]))), sum(!is.na(x$cost_comm_source[x$round_id == "R01"])), "0 households in 2018")
n_unknown <- sum(x$cost_comm_source %in% 3)
add_check("Costs", "Every 2019-2023 household has a community cost", pass_if(n_unknown == 0, "warn"), sprintf("%s unknown", format(n_unknown, big.mark = ",")), "0",
          "Participants in cash for assets in an area and year with no cost, or no beneficiary count, in either cost file. Left missing, not guessed: see the issue register.")
ledger <- readr::read_csv(file.path(DIR_COSTS, "community_cost_ledger.csv"), show_col_types = FALSE)
tpl_lines <- readr::read_csv(file.path(DIR_COSTS, "community_cost_lines.csv"), show_col_types = FALSE, col_select = c(transfer_xaf, capacity_xaf))
ledger_ok <- abs(sum(ledger$transfer_xaf) - sum(tpl_lines$transfer_xaf, na.rm = TRUE)) < 1 && abs(sum(ledger$capacity_xaf) - sum(tpl_lines$capacity_xaf, na.rm = TRUE)) < 1
add_check("Costs", "Every franc of the community template has a destination", pass_if(ledger_ok),
          sprintf("%s XAF traced", format(round(sum(ledger$transfer_xaf) + sum(ledger$capacity_xaf)), big.mark = ",")), "Equal to the template",
          "The ledger of costs/prepare_community_costs.R, by period and destination.")
cost_ledger <- ledger
cost_vs_revised <- readr::read_csv(file.path(DIR_COSTS, "community_vs_revised.csv"), show_col_types = FALSE)

hh <- x[x$round_id != "R01", ]
cost_hh_round <- hh |> group_by(round_id) |> summarise(
  households = n(), with_total = sum(!is.na(cost_total_xaf)), source_village = sum(cost_comm_source == 1), source_area = sum(cost_comm_source == 2),
  source_none = sum(cost_comm_source == 0), source_unknown = sum(cost_comm_source == 3), participants = sum(cost_comm_transfer_xaf > 0, na.rm = TRUE),
  repeat_flag = sum(cost_comm_repeat == 1, na.rm = TRUE),
  transfer_mean = mean(cost_comm_transfer_xaf[!is.na(cost_total_xaf)]), capacity_mean = mean(cost_comm_capacity_xaf[!is.na(cost_total_xaf)]),
  interv_mean = mean(cost_interv_xaf[!is.na(cost_total_xaf)]), total_mean = mean(cost_total_xaf, na.rm = TRUE), total_median = median(cost_total_xaf, na.rm = TRUE),
  transfer_participant_median = median(cost_comm_transfer_xaf[cost_comm_transfer_xaf > 0], na.rm = TRUE), .groups = "drop") |>
  mutate(across(ends_with(c("_mean", "_median")), ~ round(.x)))
item_lab <- setNames(codebook$rule, codebook$variable)
cost_hh_items <- bind_rows(lapply(c("cost_comm_transfer_xaf", "cost_comm_capacity_xaf", item_vars), function(v) {
  hh |> group_by(round_id) |> summarise(asked = sum(!is.na(.data[[v]])), recipients = sum(.data[[v]] > 0, na.rm = TRUE),
                                        mean_if_recipient = mean(.data[[v]][.data[[v]] > 0], na.rm = TRUE), total_xaf = sum(.data[[v]], na.rm = TRUE), .groups = "drop") |>
    mutate(variable = v, label = sub(" \\(.*", "", sub("^Cost: ", "", unname(final_var_labels[v]))))
})) |> mutate(suppressed = recipients > 0 & recipients < MIN_CELL, mean_if_recipient = ifelse(recipients < MIN_CELL, NA, round(mean_if_recipient)), total_xaf = round(total_xaf)) |>
  filter(asked > 0)
cost_hh_assets <- bind_rows(lapply(asset_vars, function(v) {
  hh |> filter(!is.na(.data[[v]])) |> group_by(round_id) |> summarise(households = n(), with_cost = sum(.data[[v]] > 0), mean_xaf = mean(.data[[v]]), .groups = "drop") |>
    mutate(variable = v, asset = sub(", XAF$", "", sub("^Community cost, asset type: ", "", unname(final_var_labels[v]))))
})) |> mutate(mean_xaf = round(mean_xaf))
cost_hh_region <- hh |> filter(!is.na(cost_total_xaf)) |> group_by(round_id, region = ADMIN1Name) |>
  summarise(households = n(), total_mean = mean(cost_total_xaf), total_median = median(cost_total_xaf), community_mean = mean(cost_comm_transfer_xaf + cost_comm_capacity_xaf),
            interv_mean = mean(cost_interv_xaf), .groups = "drop") |>
  mutate(suppressed = households < MIN_CELL, across(c(total_mean, total_median, community_mean, interv_mean), ~ ifelse(suppressed, NA, round(.x))))
write_out(cost_hh_round, "cost_household_by_round.csv")
write_out(cost_hh_items, "cost_household_items.csv")
write_out(cost_hh_assets, "cost_household_assets.csv")
write_out(cost_hh_region, "cost_household_region.csv")
write_out(cost_ledger, "cost_ledger.csv")
write_out(cost_vs_revised, "cost_template_vs_revised.csv")

# ---- Write --------------------------------------------------------------------------------------
say("Writing %s/ ...", OUT)
checks_df <- bind_rows(checks) |> mutate(status = factor(status, c("fail", "warn", "pass"))) |> arrange(status, group) |> mutate(status = as.character(status))
write_out(rounds, "rounds.csv")
write_out(ind_round, "indicators_by_round.csv")
write_out(ind_region, "indicators_by_round_region.csv")
write_out(admin2, "households_by_department.csv")
write_out(ch_phase, "ch_phase_by_round.csv")
write_out(merge_steps, "merge_steps.csv")
write_out(module_round, "module_by_round.csv")
write_out(stale, "module_rebuild_check.csv")
write_out(crosswalk, "crosswalk_long.csv")
write_out(crosswalk_summary, "crosswalk_summary.csv")
write_out(map_dups, "mapping_duplicates.csv")
write_out(source_agree, "source_agreement_variable.csv")
write_out(agree_family, "source_agreement_family.csv")
write_out(rcsi_compare, "rcsi_comparison.csv")
write_out(lcs_items, "lcs_items.csv")
write_out(assist_rows, "assistance_by_round.csv")
write_out(assist_region, "assistance_by_region.csv")
write_out(assist_audit, "assistance_audit.csv")
write_out(doc_diff, "assistance_documented_differences.csv")
write_out(nutrition, "nutrition_rows.csv")
write_out(final_cols, "merged_columns.csv")
write_out(final_cov, "merged_column_coverage.csv")
write_out(variable_values, "variable_values.csv")
write_out(variable_numeric, "variable_numeric.csv")
write_out(family_cov, "merged_family_coverage.csv")
write_out(places, "place_corrections.csv")
write_out(checks_df, "checks.csv")
write_out(flags, "flags.csv")
jsonlite::write_json(list(
  run_utc = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"), merged_file = FINAL_FILE,
  households = N_FINAL, columns = ncol(final_lab), min_cell = MIN_CELL,
  mapped_variables = nrow(hv), mapped_variables_extension = nrow(ext), mapped_in_final = sum(crosswalk_summary$in_final),
  modules_2025 = sum(!mod_new), modules_2026 = sum(mod_new),
  software = list(r = paste(R.version$major, R.version$minor, sep = "."), haven = as.character(packageVersion("haven"))),
  inputs = inputs
), file.path(OUT, "manifest.json"), pretty = TRUE, auto_unbox = TRUE, dataframe = "rows")

# Boundary check on what was written: refuse to leave household-level content behind.
forbidden <- c("ID", "hh_id", "uuid", "village", "Longitude", "Latitude")
for (f in list.files(OUT, pattern = "\\.csv$", full.names = TRUE)) {
  hdr <- strsplit(readLines(f, n = 1, warn = FALSE), ",")[[1]]
  if (any(gsub("\"", "", hdr) %in% forbidden)) stop("Household-level column in ", f, call. = FALSE)
}
cat("\n"); print(table(checks_df$status))
print(as.data.frame(checks_df[checks_df$status != "pass", c("status", "check", "observed")]), right = FALSE)
say("Done: %s households, %d columns.", format(N_FINAL, big.mark = ","), ncol(final_lab))
