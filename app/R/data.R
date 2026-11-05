# Load everything the app shows. All inputs are metadata or aggregates (see prepare_app_data.R).

# Synthetic mode (WFP_CBA_DEMO=1): invented estimates from make_demo_data.R, for screenshots.
demo_mode <- function() identical(Sys.getenv("WFP_CBA_DEMO"), "1")
app_data_dir <- function() {
  if (!demo_mode()) return("data")
  if (!dir.exists("demo_data")) stop("demo_data is missing: run Rscript make_demo_data.R", call. = FALSE)
  "demo_data"
}

# One row per geography x round x indicator, for the Data page and its exports.
indicators_long <- function(ind_round, ind_region, rounds, flags) {
  one <- function(x, geo, level) {
    do.call(rbind, lapply(seq_len(nrow(IND)), function(i) {
      id <- IND$id[i]
      data.frame(level = level, geography = geo, round_id = x$round_id, domain = IND$domain[i], indicator = IND$label[i], unit = IND$unit[i],
                 as_merged = round(x[[paste0(id, "_m")]], 2), with_corrections = round(x[[paste0(id, "_c")]], 2),
                 households = x$households, group = IND$group[i])
    }))
  }
  out <- rbind(one(ind_round, "All surveyed households", "All"), one(ind_region, ind_region$region, "Region"))
  out <- out[!(is.na(out$as_merged) & is.na(out$with_corrections)), ]
  key <- paste(flags$indicator_group, flags$round_id)
  out$flagged <- paste(out$group, out$round_id) %in% key
  i <- match(out$round_id, rounds$round_id)
  out$round <- rounds$label[i]
  out$survey <- rounds$survey[i]
  out$series <- rounds$series[i]
  out[, c("level", "geography", "round_id", "round", "survey", "series", "domain", "indicator", "unit",
          "as_merged", "with_corrections", "flagged", "households")]
}

load_app_data <- function(dir = app_data_dir()) {
  f <- function(x) file.path(dir, x)
  rd <- function(x, ...) as.data.frame(readr::read_csv(f(x), show_col_types = FALSE, ...))

  rounds <- rd("rounds.csv")
  rounds <- rounds[order(rounds$round), ]
  rounds$choice <- sprintf("R%d · %s", rounds$round, rounds$label)
  rounds$short <- sprintf("R%d %s", rounds$round, sub("Baseline", "Base", sub("Annual", "Annual", rounds$label)))
  add_round <- function(x) {
    i <- match(x$round_id, rounds$round_id)
    x$label <- factor(rounds$label[i], levels = rounds$label)
    x$series <- rounds$series[i]
    x$year <- rounds$year[i]
    x$round <- rounds$round[i]
    x
  }
  flags <- rd("flags.csv", col_types = readr::cols(.default = "c", fixed = "l"))
  ind_round <- add_round(rd("indicators_by_round.csv"))
  ind_region <- add_round(rd("indicators_by_round_region.csv"))
  flags <- flags[order(flags$indicator_group, flags$round_id), ]
  issues <- as.data.frame(readr::read_csv("config/issues.csv", show_col_types = FALSE))
  # The issue texts quote real figures: not in the synthetic version.
  if (demo_mode()) issues$found <- "Illustration: the description is hidden in the synthetic version."

  list(
    rounds = rounds,
    round_levels = rounds$label,
    round_ids = rounds$round_id,
    flags = flags,
    ind_round = ind_round[order(ind_round$round), ],
    ind_region = ind_region,
    ind_long = indicators_long(ind_round, ind_region, rounds, flags),
    admin2 = rd("households_by_department.csv"),
    ch_phase = rd("ch_phase_by_round.csv"),
    merge_steps = rd("merge_steps.csv"),
    module_round = rd("module_by_round.csv"),
    module_rebuild = rd("module_rebuild_check.csv"),
    crosswalk = rd("crosswalk_long.csv"),
    crosswalk_summary = rd("crosswalk_summary.csv"),
    mapping_duplicates = rd("mapping_duplicates.csv"),
    agree_variable = rd("source_agreement_variable.csv"),
    agree_family = rd("source_agreement_family.csv"),
    rcsi = rd("rcsi_comparison.csv"),
    lcs_items = rd("lcs_items.csv"),
    assistance = rd("assistance_by_round.csv"),
    assistance_region = rd("assistance_by_region.csv"),
    assistance_audit = rd("assistance_audit.csv"),
    assistance_documented = rd("assistance_documented_differences.csv"),
    nutrition = rd("nutrition_rows.csv"),
    cost_recon = rd("cost_reconciliation.csv"),
    cost_category = rd("cost_by_category.csv"),
    cost_area = rd("cost_by_area.csv"),
    cost_partner = rd("cost_by_partner.csv"),
    cost_link = rd("cost_survey_link.csv"),
    cost_crosswalk = rd("cost_department_crosswalk.csv"),
    composition = rd("composition_usd.csv"),
    merged_columns = rd("merged_columns.csv"),
    column_coverage = rd("merged_column_coverage.csv"),
    variable_values = rd("variable_values.csv", col_types = readr::cols(value = "c", label = "c")),
    variable_numeric = rd("variable_numeric.csv"),
    family_coverage = rd("merged_family_coverage.csv"),
    places = rd("place_corrections.csv"),
    checks = rd("checks.csv"),
    issues = issues,
    interventions = as.data.frame(readr::read_csv("config/interventions.csv", show_col_types = FALSE)),
    modules = as.data.frame(readr::read_csv("config/modules.csv", show_col_types = FALSE)),
    manifest = jsonlite::fromJSON(f("manifest.json")),
    xlsx_path = f("WFP_Chad_crosswalk_2018-2023.xlsx")
  )
}
