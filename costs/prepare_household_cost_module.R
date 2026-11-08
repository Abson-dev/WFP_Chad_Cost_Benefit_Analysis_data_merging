# Step 4: the cost module, one row per household of the merged file. From the repository's root, after
# prepare_community_costs.R and prepare_household_costs.R:
#   Rscript costs/prepare_household_cost_module.R
#
# Community costs follow the rule of IFPRI's community template (sheet "cost assignment"):
#   took part in cash for assets, village with assets  -> transfer cost / beneficiary households + capacity cost / households
#   did not take part, village with assets             -> capacity cost / households
#   village without assets                             -> 0
# Decisions of 8 November 2026:
#   - the template's costs are the reference, where they differ from WFP's revised workbook;
#   - "households" is WFP's beneficiary households of the village (the template's Menage column), for both costs;
#   - USD amounts are converted at the World Bank's annual average rate (costs/exchange_rates.csv).
# A surveyed village linked to several cost villages pools them: the cost per beneficiary is the ratio of the sums.
# Costs of year Y apply to households surveyed in year Y (2020: January-March and April-December together).
# A household that took part in cash for assets in a village with no matched cost that year gets the average cost
# per beneficiary of its department and year (cost_comm_source = 2). The 2018 baseline has no costs (missing).
#
# Writes WFP_Chad_Costs.dta to the module folder, for merge/21, and a CSV copy to "cost data clean/".

suppressPackageStartupMessages({ library(dplyr); library(readr); library(haven); library(labelled) })
BASE <- Sys.getenv("WFP_MERGED_DIR", "C:/Users/AHema/OneDrive - CGIAR/Desktop/2024/WFP/CBA - Chad/data")
MODULES <- Sys.getenv("WFP_MODULES_DIR", "C:/Users/AHema/OneDrive - CGIAR/Desktop/WFP Resilience dataset/data/output_data/Chad")
MERGED <- file.path(BASE, "WFP_Chad_2018-2023_20261106_v5.dta")
CLEAN <- file.path(BASE, "cost data clean")
plain <- function(v) trimws(gsub("\\s+", " ", gsub("[^A-Z0-9 ]", " ", toupper(stringi::stri_trans_general(v, "Latin-ASCII")))))

vc <- as.data.frame(read_csv(file.path(CLEAN, "community_village_costs.csv"), show_col_types = FALSE))
vm <- as.data.frame(read_csv(file.path(CLEAN, "community_village_match.csv"), show_col_types = FALSE, col_types = cols(.default = "c", distance = "d")))
ic <- as.data.frame(read_csv(file.path(CLEAN, "household_intervention_costs.csv"), show_col_types = FALSE, col_types = cols(ID = "c")))
fx <- as.data.frame(read_csv("costs/exchange_rates.csv", show_col_types = FALSE))
xw <- as.data.frame(read_csv("costs/department_crosswalk.csv", show_col_types = FALSE))
if (anyNA(fx$xaf_per_usd)) stop("costs/exchange_rates.csv has a missing rate.", call. = FALSE)

sv <- as.data.frame(zap_labels(read_dta(MERGED, col_select = c(ID, YEAR, SURVEY, adm2_ocha, village, ArgentContreTravail, VivreContreTravail))))
id_numeric <- is.numeric(sv$ID)
sv$ID <- as.character(sv$ID)
if (anyDuplicated(sv$ID)) stop("Household IDs are not unique.", call. = FALSE)
sv$village_plain <- plain(sv$village)
sv$act <- (sv$ArgentContreTravail %in% 1) | (sv$VivreContreTravail %in% 1)   # food for assets is recoded to cash (WFP)

# Costs of each surveyed village and year, pooling its cost villages.
link <- vm[!is.na(vm$survey_village), c("department", "cost_village", "survey_village", "adm2_ocha")]
village_year <- vc |> filter(village != "(no village)") |>
  inner_join(link, by = c("department", "village" = "cost_village"), relationship = "many-to-many") |>
  group_by(survey_village, adm2_ocha, year) |>
  summarise(transfer_xaf = sum(transfer_xaf), capacity_xaf = sum(capacity_xaf), capacity_repeats_xaf = sum(capacity_repeats_transfer_xaf),
            beneficiaries = sum(beneficiary_households), cost_villages = n_distinct(paste(department, village)), .groups = "drop")

# Department averages per beneficiary, for cash-for-assets households outside a matched village.
xw$key <- plain(xw$cost_department)
dept <- vc |> mutate(key = plain(department)) |> inner_join(xw[!is.na(xw$adm2_ocha), c("key", "adm2_ocha")], by = "key", relationship = "many-to-many") |>
  group_by(adm2_ocha, year) |> summarise(d_transfer = sum(transfer_xaf), d_capacity = sum(capacity_xaf), d_benef = sum(beneficiary_households), .groups = "drop")

h <- sv |> filter(YEAR >= 2019) |>
  left_join(village_year, by = c("village_plain" = "survey_village", "adm2_ocha", "YEAR" = "year")) |>
  left_join(dept, by = c("adm2_ocha", "YEAR" = "year"))
has_village_cost <- !is.na(h$transfer_xaf) & (h$transfer_xaf > 0 | h$capacity_xaf > 0)
per_benef_ok <- has_village_cost & h$beneficiaries > 0
# Sources: 1 the village's costs per beneficiary; 2 the cost area's average per beneficiary, for a participant outside a
# matched village, or any household of a village with a cost but no beneficiary count; 0 no village cost; 3 unknown.
area_ok <- !is.na(h$d_benef) & h$d_benef > 0
needs_area <- (h$act & !has_village_cost) | (has_village_cost & !per_benef_ok)
h$cost_comm_source <- case_when(per_benef_ok ~ 1L, needs_area & area_ok ~ 2L, needs_area ~ 3L, TRUE ~ 0L)
h$cost_comm_transfer_xaf <- case_when(h$cost_comm_source == 1 ~ ifelse(h$act, h$transfer_xaf / h$beneficiaries, 0),
                                      h$cost_comm_source == 2 ~ ifelse(h$act, h$d_transfer / h$d_benef, 0),
                                      h$cost_comm_source == 3 ~ NA_real_, TRUE ~ 0)
h$cost_comm_capacity_xaf <- case_when(h$cost_comm_source == 1 ~ h$capacity_xaf / h$beneficiaries,
                                      h$cost_comm_source == 2 ~ h$d_capacity / h$d_benef,
                                      h$cost_comm_source == 3 ~ NA_real_, TRUE ~ 0)
h$cost_comm_repeat <- as.integer(h$cost_comm_source == 1 & !is.na(h$capacity_repeats_xaf) & h$capacity_repeats_xaf > 0)

# ---- Context, so that no cost information is lost on the way to the household ------------------------------------
# Village, cumulated from 2019 up to the survey year: assets built in earlier years still serve the household.
vc_link <- vc |> filter(village != "(no village)") |> inner_join(link, by = c("department", "village" = "cost_village"), relationship = "many-to-many")
cum <- sv |> filter(YEAR >= 2019) |> select(ID, village_plain, adm2_ocha, YEAR) |>
  inner_join(vc_link |> select(survey_village, adm2_ocha, year, transfer_xaf, capacity_xaf, beneficiary_households, department, village, period),
             by = c("village_plain" = "survey_village", "adm2_ocha"), relationship = "many-to-many") |>
  filter(year <= YEAR) |> distinct(ID, department, village, period, .keep_all = TRUE) |>
  group_by(ID) |> summarise(cost_vill_cum_transfer_xaf = sum(transfer_xaf), cost_vill_cum_capacity_xaf = sum(capacity_xaf),
                            cost_vill_cum_benef = sum(beneficiary_households), cost_vill_cost_years = n_distinct(year), .groups = "drop")
h <- left_join(h, cum, by = "ID")
for (v in c("cost_vill_cum_transfer_xaf", "cost_vill_cum_capacity_xaf", "cost_vill_cum_benef", "cost_vill_cost_years")) h[[v]][is.na(h[[v]])] <- 0
# Cost area totals of the year, from WFP's revised workbook (the department costs of prepare_cost_data.R).
ba <- as.data.frame(read_csv(file.path(CLEAN, "cost_by_area.csv"), show_col_types = FALSE))
area_of <- distinct(xw[!is.na(xw$adm2_ocha), c("adm2_ocha", "cost_area")]) |> filter(cost_area %in% ba$cost_area)
rev <- ba |> group_by(cost_area, year) |> summarise(cash = sum(cash_xaf), .groups = "drop") |>
  inner_join(area_of, by = "cost_area", relationship = "many-to-many") |> group_by(adm2_ocha, year) |> summarise(cost_area_revised_xaf = sum(cash), .groups = "drop")
h <- left_join(h, rev, by = c("adm2_ocha", "YEAR" = "year"))
h$cost_area_revised_xaf[is.na(h$cost_area_revised_xaf)] <- 0
h$cost_vill_transfer_xaf <- ifelse(is.na(h$transfer_xaf), 0, h$transfer_xaf)
h$cost_vill_capacity_xaf <- ifelse(is.na(h$capacity_xaf), 0, h$capacity_xaf)
h$cost_vill_benef <- ifelse(is.na(h$beneficiaries), 0, h$beneficiaries)
h$cost_area_transfer_xaf <- ifelse(is.na(h$d_transfer), 0, h$d_transfer)
h$cost_area_capacity_xaf <- ifelse(is.na(h$d_capacity), 0, h$d_capacity)
h$cost_area_benef <- ifelse(is.na(h$d_benef), 0, h$d_benef)
context_cols <- c("cost_vill_transfer_xaf", "cost_vill_capacity_xaf", "cost_vill_benef", "cost_vill_cum_transfer_xaf", "cost_vill_cum_capacity_xaf",
                  "cost_vill_cum_benef", "cost_vill_cost_years", "cost_area_transfer_xaf", "cost_area_capacity_xaf", "cost_area_benef", "cost_area_revised_xaf")
if (any(h$cost_vill_cum_transfer_xaf + 0.01 < h$cost_vill_transfer_xaf)) stop("A cumulated village cost is below the year's cost.", call. = FALSE)

# Community cost by asset type: the same rule, applied to each activity category (community_village_costs_by_asset.csv).
ASSETS <- c("Land recovery: dikes, half-moons, anti-erosion" = "land", "Trees, nurseries and dune fixation" = "trees",
            "Water: wells, ponds, dams, irrigation" = "water", "Market gardening and crops" = "garden",
            "Household hygiene and improved stoves" = "hygiene", "Compost and soil fertility" = "compost",
            "Roads, buildings and maintenance" = "roads", "Training and capacity building" = "training", "School support" = "school",
            "Cereal banks and storage" = "storage", "Livestock and fish" = "livestock", "Other or unclear" = "other",
            "Partner lump sum (COVID-19), not allocated" = "lump2020")
va <- as.data.frame(read_csv(file.path(CLEAN, "community_village_costs_by_asset.csv"), show_col_types = FALSE))
if (!all(va$category %in% names(ASSETS))) stop("Unknown asset category: ", paste(setdiff(va$category, names(ASSETS)), collapse = ", "), call. = FALSE)
va$asset <- ASSETS[va$category]
wide <- function(d, keys) {
  t <- d |> group_by(across(all_of(c(keys, "asset")))) |> summarise(tr = sum(transfer_xaf), ca = sum(capacity_xaf), .groups = "drop")
  tr <- tidyr::pivot_wider(t[, c(keys, "asset", "tr")], names_from = asset, values_from = tr, values_fill = 0, names_prefix = "tr_")
  ca <- tidyr::pivot_wider(t[, c(keys, "asset", "ca")], names_from = asset, values_from = ca, values_fill = 0, names_prefix = "ca_")
  full_join(tr, ca, by = keys)
}
va_village <- va |> filter(village != "(no village)") |> inner_join(link, by = c("department", "village" = "cost_village"), relationship = "many-to-many") |>
  wide(c("survey_village", "adm2_ocha", "year"))
va_dept <- va |> mutate(key = plain(department)) |> inner_join(xw[!is.na(xw$adm2_ocha), c("key", "adm2_ocha")], by = "key", relationship = "many-to-many") |>
  wide(c("adm2_ocha", "year"))
names(va_dept)[-(1:2)] <- paste0("d", names(va_dept)[-(1:2)])
h <- h |> left_join(va_village, by = c("village_plain" = "survey_village", "adm2_ocha", "YEAR" = "year")) |> left_join(va_dept, by = c("adm2_ocha", "YEAR" = "year"))
asset_cols <- paste0("cost_asset_", ASSETS, "_xaf")
for (a in ASSETS) {
  g <- function(col) { x <- h[[col]]; if (is.null(x)) rep(0, nrow(h)) else ifelse(is.na(x), 0, x) }
  village <- (ifelse(h$act, g(paste0("tr_", a)), 0) + g(paste0("ca_", a))) / h$beneficiaries
  dept <- (ifelse(h$act, g(paste0("dtr_", a)), 0) + g(paste0("dca_", a))) / h$d_benef
  h[[paste0("cost_asset_", a, "_xaf")]] <- case_when(h$cost_comm_source == 1 ~ village, h$cost_comm_source == 2 ~ dept,
                                                     h$cost_comm_source == 0 ~ 0, TRUE ~ NA_real_)
}
gap <- rowSums(h[, asset_cols]) - (h$cost_comm_transfer_xaf + h$cost_comm_capacity_xaf)
if (max(abs(gap), na.rm = TRUE) > 0.01) stop("The asset columns do not add up to the community cost.", call. = FALSE)

# Household-level interventions, converted to XAF: one column per intervention, then their sum.
uc <- as.data.frame(read_csv("costs/household_unit_costs.csv", show_col_types = FALSE, col_types = cols(.default = "c")))
items <- uc[!duplicated(uc$cost_name), c("cost_name", "variable", "currency")]
iv_labels <- as.data.frame(read_csv("app/config/interventions.csv", show_col_types = FALSE))
items$label <- iv_labels$label[match(items$variable, iv_labels$variable)]
h <- left_join(h, ic[, c("ID", "cost_usd", "cost_xaf_native", "interventions_costed", paste0("cost_", items$cost_name))], by = "ID")
h$rate <- fx$xaf_per_usd[match(h$YEAR, fx$year)]
item_cols <- paste0("cost_", items$cost_name, "_xaf")
for (i in seq_len(nrow(items))) {
  native <- h[[paste0("cost_", items$cost_name[i])]]
  h[[item_cols[i]]] <- if (items$currency[i] == "USD") native * h$rate else native
}
h$cost_interv_xaf <- h$cost_xaf_native + h$cost_usd * h$rate
chk <- rowSums(h[, item_cols], na.rm = TRUE)
if (max(abs(chk - h$cost_interv_xaf), na.rm = TRUE) > 0.01) stop("The intervention columns do not add up to their total.", call. = FALSE)
h$cost_total_xaf <- h$cost_comm_transfer_xaf + h$cost_comm_capacity_xaf + h$cost_interv_xaf

module <- sv[, "ID", drop = FALSE] |>
  left_join(h[, c("ID", "cost_comm_source", "cost_comm_transfer_xaf", "cost_comm_capacity_xaf", "cost_comm_repeat", asset_cols, item_cols, "cost_usd", "cost_interv_xaf", "cost_total_xaf", context_cols)], by = "ID") |>
  rename(cost_interv_usd = cost_usd)
for (v in c("cost_comm_transfer_xaf", "cost_comm_capacity_xaf", asset_cols, item_cols, "cost_interv_usd", "cost_interv_xaf", "cost_total_xaf", context_cols)) module[[v]] <- round(module[[v]], 2)
if (nrow(module) != nrow(sv) || anyDuplicated(module$ID)) stop("The module does not have one row per household.", call. = FALSE)
if (id_numeric) module$ID <- as.numeric(module$ID)

module$cost_comm_source <- labelled(module$cost_comm_source, c("No village cost" = 0L, "Village" = 1L, "Department average" = 2L, "Unknown" = 3L))
module$cost_comm_repeat <- labelled(module$cost_comm_repeat, c("No" = 0L, "Yes" = 1L))
var_label(module) <- list(
  ID = "Household ID",
  cost_comm_source = "Source of the community cost (village, department average)",
  cost_comm_transfer_xaf = "Community transfer cost per household, XAF (cash for assets)",
  cost_comm_capacity_xaf = "Community capacity cost per household, XAF",
  cost_comm_repeat = "Village capacity cost includes rows repeating the transfer cost (to confirm with WFP)",
  cost_interv_usd = "Cost of household-level interventions, USD",
  cost_interv_xaf = "Cost of household-level interventions, XAF",
  cost_total_xaf = "Total cost per household, XAF (community + household-level)",
  cost_vill_transfer_xaf = "Village: community transfer cost of the survey year, XAF (template)",
  cost_vill_capacity_xaf = "Village: community capacity cost of the survey year, XAF (template)",
  cost_vill_benef = "Village: WFP beneficiary households of the survey year (template)",
  cost_vill_cum_transfer_xaf = "Village: transfer cost cumulated 2019 to the survey year, XAF",
  cost_vill_cum_capacity_xaf = "Village: capacity cost cumulated 2019 to the survey year, XAF",
  cost_vill_cum_benef = "Village: beneficiary households summed 2019 to the survey year",
  cost_vill_cost_years = "Village: number of years with community costs, 2019 to the survey year",
  cost_area_transfer_xaf = "Cost area: community transfer cost of the survey year, XAF (template)",
  cost_area_capacity_xaf = "Cost area: community capacity cost of the survey year, XAF (template)",
  cost_area_benef = "Cost area: WFP beneficiary households of the survey year (template)",
  cost_area_revised_xaf = "Cost area: cost of the survey year in WFP's revised workbook, XAF")
for (i in seq_along(asset_cols)) var_label(module[[asset_cols[i]]]) <- substr(paste0("Community cost, asset type: ", names(ASSETS)[i], ", XAF"), 1, 80)
for (i in seq_along(item_cols)) var_label(module[[item_cols[i]]]) <- substr(paste0("Cost: ", items$label[i], " (", items$variable[i], "), XAF"), 1, 80)
# The documentation must describe exactly the variables written.
codebook <- read_csv("costs/cost_variables.csv", show_col_types = FALSE)
if (!setequal(codebook$variable, setdiff(names(module), "ID"))) stop("costs/cost_variables.csv and the module disagree: ",
  paste(c(setdiff(codebook$variable, names(module)), setdiff(setdiff(names(module), "ID"), codebook$variable)), collapse = ", "), call. = FALSE)
write_dta(module, file.path(MODULES, "WFP_Chad_Costs.dta"), version = 15)
write_csv(zap_labels(module), file.path(CLEAN, "household_cost_module.csv"), na = "")

fmt <- function(v) format(round(v), big.mark = ",", scientific = FALSE, trim = TRUE)
s <- h |> group_by(YEAR, SURVEY) |> summarise(
  households = n(), cash_for_assets = sum(act), village = sum(cost_comm_source == 1), dept_avg = sum(cost_comm_source == 2), unknown = sum(cost_comm_source == 3),
  transfer_mean = fmt(mean(cost_comm_transfer_xaf[act], na.rm = TRUE)), capacity_mean = fmt(mean(cost_comm_capacity_xaf, na.rm = TRUE)),
  interv_mean = fmt(mean(cost_interv_xaf, na.rm = TRUE)), total_mean = fmt(mean(cost_total_xaf, na.rm = TRUE)), repeat_flag = sum(cost_comm_repeat), .groups = "drop")
cat("\nCost module by round (means in XAF; transfer over cash-for-assets households)\n"); print(as.data.frame(s), row.names = FALSE)
tp <- h$cost_comm_transfer_xaf[h$act & h$cost_comm_source == 1]
cat(sprintf("\nTransfer cost per cash-for-assets household (village source): median %s XAF, 10th-90th percentiles %s to %s (WFP: 30,000 XAF in hand)\n",
            fmt(median(tp)), fmt(quantile(tp, 0.1)), fmt(quantile(tp, 0.9))))
cat("Module:", file.path(MODULES, "WFP_Chad_Costs.dta"), "\n")
