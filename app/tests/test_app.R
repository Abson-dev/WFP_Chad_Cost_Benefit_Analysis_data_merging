# Checks of the whole app: every page and output for every round, the figures against an independent
# recomputation from the merged file, the claims of config/issues.csv, the data boundary and the login.
# Run from the app/ folder, after prepare_app_data.R:   Rscript tests/test_app.R
# Exits with status 1 if any check fails. The merged file is read only if it is found on this computer.

Sys.setenv(WFP_CBA_LOCAL = "1")
suppressPackageStartupMessages({ library(shiny); library(bslib) })
for (f in list.files("R", full.names = TRUE)) source(f)
d <- load_app_data("data")
cat(sprintf("data: %d rounds, %d variables, %d checks, %d flags\n", nrow(d$rounds), nrow(d$crosswalk_summary), nrow(d$checks), nrow(d$flags)))

failures <- 0; n_checks <- 0; verbose <- "--verbose" %in% commandArgs(trailingOnly = TRUE)
ok <- function(label, expr) {
  n_checks <<- n_checks + 1
  r <- tryCatch({ force(expr); "OK" }, error = function(e) {
    if (inherits(e, "shiny.silent.error")) "OK" else paste("ERROR:", conditionMessage(e))
  })
  if (r != "OK") failures <<- failures + 1
  if (verbose || r != "OK") cat(sprintf("%-55s %s\n", label, r))
}
# A chart must serialise to valid JSON: named vectors or wrong lengths fail only in the browser.
plotly_json <- function(p) { jsonlite::fromJSON(plotly::plotly_json(p, jsonedit = FALSE, pretty = FALSE)); invisible(TRUE) }
section <- function(s) cat("-", s, "\n")

section("UI builders")
for (m in c("situation", "merge", "validation", "issues", "variables", "costs", "trends", "regions", "assistance", "approach", "process", "crosswalk", "rounds", "data", "about")) {
  ok(paste("ui:", m), get(paste0(m, "_ui"))(m, d))
}

section("Pages that follow the reference round, for every round and both views")
for (rid in d$round_ids) for (e in c("m", "c")) {
  ref <- shiny::reactive(rid); est <- shiny::reactive(e)
  testServer(situation_server, args = list(d = d, ref = ref, est = est), {
    ok(sprintf("situation[%s,%s]", rid, e), { output$chip; output$kpis; output$attention; output$table })
    for (g in c("g_fcs", "g_rcsi", "g_lcs")) ok(sprintf("situation %s[%s,%s]", g, rid, e), output[[g]])
  })
  testServer(trends_server, args = list(d = d, ref = ref, est = est), {
    session$setInputs(indicator = "fcs_pb", geo = "")
    ok(sprintf("trends[%s,%s]", rid, e), { output$season; output$table; output$fcs; output$lcs; output$title })
  })
  testServer(regions_server, args = list(d = d, ref = ref, est = est), {
    session$setInputs(region = "Lac", metric = "fcs_pb", compare = c("Lac", "Kanem", "Batha"))
    ok(sprintf("regions[%s,%s]", rid, e), { output$kpis; output$rank; output$heat; output$trend; output$table; output$table_title; output$rank_title; output$heat_title })
    session$setInputs(region = "Ennedi Est")  # surveyed in one round only
    ok(sprintf("regions Ennedi Est[%s,%s]", rid, e), { output$kpis; output$table })
  })
  testServer(assistance_server, args = list(d = d, ref = ref), {
    session$setInputs(variable = "CashTransfert")
    ok(sprintf("assistance[%s]", rid), { output$chip; output$matrix; output$trend; output$region; output$audit; output$documented })
  })
}

section("All indicators, all areas")
ref <- shiny::reactive("R10"); est <- shiny::reactive("m")
testServer(trends_server, args = list(d = d, ref = ref, est = est), {
  for (id in IND$id) for (geo in c("", "Lac", "Ennedi Est")) {
    session$setInputs(indicator = id, geo = geo)
    ok(sprintf("trends[%s,%s]", id, geo), { output$season; output$table })
  }
})
testServer(regions_server, args = list(d = d, ref = ref, est = est), {
  for (id in IND$id) {
    session$setInputs(region = "Lac", metric = id, compare = c("Lac", "Kanem"))
    ok(sprintf("regions[%s]", id), { output$rank; output$heat; output$trend })
  }
})
testServer(assistance_server, args = list(d = d, ref = ref), {
  for (v in d$interventions$variable) { session$setInputs(variable = v); ok(sprintf("assistance[%s]", v), { output$trend; output$region }) }
})

section("Other pages")
testServer(merge_server, args = list(d = d), {
  ok("merge", { output$rows; output$flow; output$steps; output$modules; output$families; output$ch; output$places; output$nutrition; output$columns })
})
testServer(validation_server, args = list(d = d), {
  for (s in c("", "fail", "warn", "pass")) { session$setInputs(status = s, sens = "lcs_ce", lcs_view = "merged_yes"); ok(sprintf("validation[%s]", s), output$checks) }
  for (id in SENSITIVITY) { session$setInputs(sens = unname(id)); ok(sprintf("validation sens[%s]", id), output$sens_plot) }
  for (v in c("merged_yes", "corrected_yes")) { session$setInputs(lcs_view = v); ok(sprintf("validation lcs[%s]", v), output$lcs) }
  ok("validation others", { output$rcsi; output$agree })
})
testServer(issues_server, args = list(d = d), {
  session$setInputs(severity = "All", state = "All"); ok("issues all", { output$count; output$cards })
  ok("issues count", stopifnot(nrow(shown()) == nrow(d$issues)))
  session$setInputs(severity = "High", state = "Open"); ok("issues high open", { output$cards; stopifnot(all(shown()$severity == "High")) })
  session$setInputs(severity = "Low", state = "Open"); ok("issues low open", output$cards)
})
section("Costs page")
testServer(costs_server, args = list(d = d), {
  ok("costs outputs", { output$by_period; output$recon; output$link; output$cat_heat; output$types; output$crosswalk; output$composition; output$partners })
})
cost_total <- d$cost_recon$reconciled_total_xaf[d$cost_recon$period == "All"]
ok("costs: reconciled total", stopifnot(abs(cost_total - 8629285049) < 1, abs(d$cost_recon$difference_xaf[d$cost_recon$period == "All"] - 211503517) < 1))
ok("costs: only 2019 differs from the workbook", stopifnot(all(abs(d$cost_recon$difference_xaf[!d$cost_recon$period %in% c("2019", "All")]) < 1)))
ok("costs: every table adds up to the total", stopifnot(abs(sum(d$cost_category$cash_xaf) - cost_total) < 1, abs(sum(d$cost_area$cash_xaf) - cost_total) < 1, abs(sum(d$cost_partner$cash_xaf) - cost_total) < 1, abs(sum(d$cost_link$cost_xaf, na.rm = TRUE) - cost_total) < 1))
ok("costs: lump sums stay apart, in one period", {
  l <- d$cost_category[d$cost_category$amount_category == LUMP_CATEGORY, ]
  stopifnot(identical(unique(l$period), "2020 Apr-Dec"), abs(sum(l$cash_xaf) - 2350967290) < 1, !any(d$cost_category$period == "2020 Apr-Dec" & d$cost_category$amount_category != LUMP_CATEGORY))
})
ok("costs: 2020 keeps two periods", stopifnot(all(c("2020 Jan-Mar", "2020 Apr-Dec") %in% d$cost_recon$period)))
ok("costs: unclear activities stay few", stopifnot(sum(d$cost_category$cash_xaf[d$cost_category$amount_category == "Other or unclear"]) < 0.01 * cost_total))
ok("costs: every category has a colour", stopifnot(all(d$cost_category$amount_category %in% names(CATEGORY_COL))))
ok("costs: crosswalk codes are surveyed departments", {
  xw <- d$cost_crosswalk[!is.na(d$cost_crosswalk$adm2_ocha), ]
  # The community template's own spellings repeat a department on purpose; the workbook's rows do not.
  wb <- xw[!grepl("community template", xw$note, ignore.case = TRUE), ]
  stopifnot(!anyDuplicated(wb$adm2_ocha), !anyDuplicated(paste(xw$cost_department, xw$adm2_ocha)))
})
section("Costs per household")
testServer(costs_server, args = list(d = d), {
  ok("household cost outputs", { output$hh_round; output$hh_source; output$hh_items; output$hh_assets; output$hh_region; output$ledger; output$vs_revised })
})
ok("household costs: every 2019-2023 household has a source", stopifnot(all(with(d$cost_hh_round, source_village + source_area + source_none + source_unknown == households))))
ok("household costs: households with a total are those with a known source", stopifnot(all(with(d$cost_hh_round, with_total == households - source_unknown))))
ok("household costs: the ledger traces the template's 17.4 billion XAF", stopifnot(abs(sum(d$cost_ledger$transfer_xaf) - 10290087109) < 1, abs(sum(d$cost_ledger$capacity_xaf) - 7126217899) < 1))
ok("household costs: small cells are hidden", {
  stopifnot(all(is.na(d$cost_hh_region$total_mean[d$cost_hh_region$households < 30])), all(is.na(d$cost_hh_items$mean_if_recipient[d$cost_hh_items$recipients < 30])))
})
ok("household costs: every asset type has a colour", stopifnot(all(d$cost_hh_assets$asset %in% names(CATEGORY_COL))))
ok("household costs: the cost checks pass, except the unknown households", {
  ck <- d$checks[d$checks$group == "Costs", ]
  stopifnot(nrow(ck) == 7, all(ck$status[ck$check != "Every 2019-2023 household has a community cost"] == "pass"))
})
ok("costs: composition is in USD, 6 packages", stopifnot(nrow(unique(d$composition[, c("programme", "target")])) == 6, min(d$composition$value_usd_per_person_month) == 10.9, max(d$composition$value_usd_per_person_month) == 31.75))
ok("costs: no activity text or village in the app's tables", {
  for (f in list.files("data", pattern = "^(cost|composition)", full.names = TRUE)) stopifnot(!"activity" %in% names(readr::read_csv(f, n_max = 1, show_col_types = FALSE)))
  stopifnot(!any(grepl("Ngueri|Doubane|Korbo|Fassaladjoul", unlist(lapply(list.files("data", pattern = "^cost", full.names = TRUE), readLines, warn = FALSE)))))
})

section("Variables page: every column of the merged file")
ok("variables: all columns listed once", stopifnot(nrow(d$merged_columns) == d$manifest$columns, !anyDuplicated(d$merged_columns$variable)))
ok("variables: completeness for every column and round", stopifnot(nrow(d$column_coverage) == d$manifest$columns * nrow(d$rounds)))
ok("variables: every column has a kind", stopifnot(all(d$merged_columns$kind %in% c("categorical", "numeric", "hidden"))))
testServer(variables_server, args = list(d = d), {
  session$setInputs(family = "", gaps = "")
  ok("variables table", { output$table; output$count; output$profile_head; output$dist; output$cover; output$dist_note })
  ok("variables csv", stopifnot(file.size(output$dl_list) > 0, file.size(output$dl_values) > 0))
  session$setInputs(family = "Household", gaps = "gaps"); ok("variables filtered", output$table)
  session$setInputs(family = "", gaps = "one"); ok("variables one round", output$table)
  for (v in d$merged_columns$variable) {
    selected(v)
    ok(sprintf("variables profile[%s]", v), { output$profile_head; output$dist; output$cover; output$dist_note })
  }
})

testServer(approach_server, args = list(d = d), ok("approach", output$hh_plot))
testServer(process_server, args = list(d = d), {
  ok("process", { output$flow; output$node_detail; output$domains })
  session$setInputs(node = 4); ok("process node", output$node_detail)
})
testServer(crosswalk_server, args = list(d = d), {
  all_f <- unique(d$crosswalk_summary$family)
  session$setInputs(families = all_f, gaps_only = FALSE, jump = "")
  ok("crosswalk all", { output$matrix_ui; output$matrix; output$table; output$details; output$dups; output$concept_card; output$concept_rounds })
  session$setInputs(jump = "LhCSIStress1"); ok("crosswalk jump", { output$concept_card; output$concept_rounds })
  session$setInputs(families = c("Reduced coping (rCSI)"), gaps_only = TRUE); ok("crosswalk filtered", { output$matrix; output$table })
  ok("crosswalk csv", stopifnot(file.size(output$dl_csv) > 0)); ok("crosswalk xlsx", stopifnot(file.size(output$dl_xlsx) > 0))
})
testServer(rounds_server, args = list(d = d), ok("rounds", { output$calendar; output$inventory; output$departments }))
testServer(data_server, args = list(d = d), {
  session$setInputs(indicators = NULL, geo = NULL, rounds = NULL, series = "")
  ok("data all", { output$count; output$table; stopifnot(nrow(shown()) == nrow(d$ind_long)) })
  session$setInputs(indicators = IND$label[1], geo = "Lac", rounds = "2023 Annual", series = "Post-harvest")
  ok("data one row", stopifnot(nrow(shown()) == 1))
  ok("data csv", stopifnot(file.size(output$csv) > 0)); ok("data excel", stopifnot(file.size(output$excel) > 0))
})
testServer(about_server, args = list(d = d), ok("about", output$inputs))

section("Charts serialise to valid JSON")
for (rid in c("R01", "R03", "R10")) {
  x <- d$ind_round
  ok(sprintf("series_bars json[%s]", rid), plotly_json(series_bars(x, "fcs_pb", rid, "m", d, "#FBC4A8", "#F0512D")))
}

section("Column content")
ok("crosswalk: label holds the SPSS label, not the round", stopifnot(!any(d$crosswalk$label %in% as.character(d$rounds$label))))
ok("crosswalk and columns: a label is never a bare number", stopifnot(!any(grepl("^[0-9.-]+$", d$crosswalk$label)), !any(grepl("^[0-9.-]+$", d$merged_columns$label))))
ok("crosswalk: rCSIBorrow no longer uses another item's column", {
  z <- d$crosswalk[d$crosswalk$variable == "rCSIBorrow", ]
  stopifnot(!any(z$source %in% "rCSILessQlty"), all(z$source[z$round_id %in% c("R07", "R09", "R10")] == "rCSIBorrow"))
})
ok("flags and checks agree: rCSI, FCS, ABI and coping are cleared, only the unlabelled 2019 coping codes stay", stopifnot(!any(c("rcsi", "fcs", "abi") %in% d$flags$indicator_group), identical(d$flags$round_id[d$flags$indicator_group == "lcs"], "R02"), sum(d$checks$status == "fail") == 0))

section("Comparison rules")
nat <- d$ind_round
ok("compare: same series only", { c1 <- ind_compare(nat, "rcsi_mean", "R08", "m", d); stopifnot(c1$base_id == "R06") })
ok("compare: flagged base is skipped", { c2 <- ind_compare(nat, "rcsi_mean", "R05", "m", d); stopifnot(c2$base_id == "R03"); c3 <- ind_compare(nat, "lcs_ce", "R05", "m", d); stopifnot(c3$base_id == "R03", !is.na(c3$diff)) })
ok("compare: flagged round has no change", { c4 <- ind_compare(nat, "lcs_ce", "R02", "m", d); stopifnot(c4$flagged, is.na(c4$diff)) })
ok("compare: corrected view compares it", { c5 <- ind_compare(nat, "fcs_pb", "R05", "c", d); stopifnot(c5$base_id == "R03", abs(c5$diff - (nat$fcs_pb_c[nat$round_id == "R05"] - nat$fcs_pb_c[nat$round_id == "R03"])) < 1e-9) })
ok("compare: first round has no base", stopifnot(is.na(ind_compare(nat, "fcs_pb", "R01", "m", d)$diff)))
ok("flags: unresolved stay flagged in the corrected view", stopifnot("R02" %in% flagged_rounds(d, "lcs_ce", "c"), !"R10" %in% flagged_rounds(d, "lcs_ce", "c")))
ok("attention: serious point on a round with a known defect", { rid <- d$flags$round_id[d$flags$fixed][1]; stopifnot(!is.na(rid), any(vapply(attention_points(d, rid, "m"), function(p) p$level == "serious", TRUE))) })
ok("attention: uncertain coping codes of 2019 Annual are a point to watch", stopifnot(any(vapply(attention_points(d, "R02", "m"), function(p) p$level == "watch" && grepl("Livelihood coping", p$title), TRUE))))

section("Figures against an independent recomputation from the merged file")
merged_path <- file.path(Sys.getenv("WFP_MERGED_DIR", "C:/Users/AHema/OneDrive - CGIAR/Desktop/2024/WFP/CBA - Chad/data"), "WFP_Chad_2018-2023_20261111_v9.dta")
if (file.exists(merged_path) && !demo_mode()) {
  x <- haven::zap_labels(haven::read_dta(merged_path))
  x$rid <- sprintf("R%02d", x$ROUND)
  chk <- function(id, fn, tol = 0.006) {
    ok(sprintf("figures: %s", id), {
      a <- nat[[paste0(id, "_m")]]; b <- vapply(d$round_ids, function(r) fn(x[x$rid == r, ]), 0)
      k <- !is.na(a) & !is.na(b); stopifnot(sum(k) >= 4, max(abs(a[k] - b[k])) < tol, identical(which(is.na(a)), unname(which(is.na(b)))))
    })
  }
  m_or_na <- function(v) if (all(is.na(v))) NA_real_ else mean(v, na.rm = TRUE)
  chk("fcs_pb", function(z) 100 * mean(z$FCS <= 42))
  chk("fcs_mean", function(z) mean(z$FCS))
  chk("rcsi_mean", function(z) m_or_na(z$rCSI))
  chk("lcs_ce", function(z) 100 * mean(z$Max_coping_behaviourFS >= 3))
  chk("abi_mean", function(z) m_or_na(z$ABIScore))
  chk("rcs_mean", function(z) m_or_na(z$RCS))
  chk("hdds_mean", function(z) m_or_na(z$HDDS_hema))
  chk("hh_size", function(z) mean(z$HHSize))
  ok("figures: households", stopifnot(sum(nat$households) == nrow(x), all(nat$households == as.integer(table(x$rid)[d$round_ids]))))
  ok("figures: regional households add up", stopifnot(sum(d$ind_region$households) == nrow(x)))
  ok("figures: columns", stopifnot(d$manifest$columns == ncol(x) - 1))

  section("Claims of config/issues.csv")
  mean_r <- function(col, r) mean(x[[col]][x$rid == r], na.rm = TRUE)
  ok("claim: FCS fixed: 2020 PDM takes the SCA, mean 53.2, groups 24/61/186, main groups empty", {
    z <- x[x$rid == "R03", ]
    stopifnot(all(z$FCS == z$SCA), round(mean(z$FCS), 1) == 53.2, all(as.integer(table(z$FCSCat28)) == c(24, 61, 186)), all(is.na(z[c("FCSStap", "FCSPulse", "FCSDairy", "FCSPr", "FCSVeg", "FCSFruit", "FCSFat", "FCSSugar")])))
    stopifnot(all(!is.na(z[c("FCSPrMeatF", "FCSVegGre", "FCSCond")])), nat$fcs_pb_m[nat$round_id == "R03"] == nat$fcs_pb_c[nat$round_id == "R03"])
    ck <- d$checks[d$checks$check == "Rounds without day counts use the analysts' score and groups", ]; stopifnot(ck$status == "pass", grepl("2020 PDM", ck$observed))
  })
  ok("claim: rCSI fixed: merged equals the analysts' value in rounds 7, 9 and 10", {
    stopifnot(all(round(nat$rcsi_mean_m[nat$round_id %in% c("R07", "R09", "R10")], 2) == c(7.59, 4.63, 4.89)), all(nat$rcsi_mean_m == nat$rcsi_mean_c))
    z <- d$rcsi[d$rcsi$round_id %in% c("R07", "R09", "R10"), ]; stopifnot(all(z$merged_same == 100))
  })
  ok("claim: emergency coping fixed by do-file 23", stopifnot(max(abs(nat$lcs_em_m[nat$round_id %in% c("R01", "R03", "R10")] - c(21.2, 8.5, 5.8))) < .06, all(nat$lcs_em_m == nat$lcs_em_c), max(abs(nat$lcs_em_c[nat$round_id %in% c("R01", "R03", "R10")] - c(21.2, 8.5, 5.8))) < .06))
  ok("claim: ABI 2022 Annual fixed by do-file 23", stopifnot(sum(x$rid == "R08" & !is.na(x$ABIScore)) == 1701, round(mean(x$ABIScore[x$rid == "R08"], na.rm = TRUE), 1) == 5.8, round(nat$abi_mean_m[nat$round_id == "R08"], 1) == 5.8, all(x$HHAssetProtect[x$rid == "R08"] == x$ABIProteger[x$rid == "R08"], na.rm = TRUE)))
  ok("claim: LhCSIStress1 restored in every round", stopifnot(sum(tapply(x$LhCSIStress1, x$rid, function(v) all(v == 4))) == 0))
  ok("claim: no weight column", stopifnot(!any(grepl("weight|pond|^wt", names(x), ignore.case = TRUE))))
  ok("claim: household size", stopifnot(sum(x$HHSize > 30) == 89, max(x$HHSize) == 352, sum(x$HHSize == 0) == 60, round(mean_r("HHSize", "R07"), 1) == 11.9, round(mean(x$HHSize[x$rid == "R07" & x$HHSize <= 30]), 1) == 7.0, max(x$HHSize05M, na.rm = TRUE) == 333))
  ok("claim: regions change", stopifnot(sum(x$rid == "R01" & x$ADMIN1Name == "Wadi Fira") == 629, sum(x$rid == "R09" & x$ADMIN1Name == "Wadi Fira") == 11, sum(x$rid == "R10" & x$ADMIN1Name == "Wadi Fira") == 0, all(x$rid[x$ADMIN1Name == "Ennedi Est"] == "R10")))
  ok("claim: female-headed 39% to 59%", stopifnot(round(min(nat$female_head_m)) == 39, round(max(nat$female_head_m)) == 59))
  ok("claim: 35 without phase or department", stopifnot(sum(is.na(x$phase_class)) == 35, sum(x$ADMIN2Name == "" | is.na(x$ADMIN2Name)) == 35, all(x$rid[is.na(x$phase_class)] == "R03")))
  ok("claim: 14 + 1 rows removed", stopifnot(sum(d$rounds$duplicates_removed) == 14, sum(d$rounds$empty_removed) == 1, sum(d$rounds$raw_rows) == 17270, d$rounds$duplicates_removed[d$rounds$round_id == "R05"] == 14))
  ok("claim: 14 dates outside, 10 missing, in 5 rounds", stopifnot(sum(d$rounds$dates_outside) == 14, sum(d$rounds$dates_missing) == 10, sum(d$rounds$dates_outside > 0) == 5))
  ok("claim: cash for assets shares", { y <- d$assistance[d$assistance$variable == "ArgentContreTravail" & d$assistance$answered > 0, ]; stopifnot(all(round(y$yes_pct[y$round_id %in% c("R02", "R03")]) == c(98, 99)), round(min(y$yes_pct)) == 68, round(max(y$yes_pct[!y$round_id %in% c("R02", "R03")])) == 94) })
  ok("claim: 91 assistance pairs same", stopifnot(nrow(d$assistance_audit) == 91, all(d$assistance_audit$pct_same == 100)))
  ok("claim: 12 report cells differ", stopifnot(nrow(d$assistance_documented) == 12))
  crops <- sub("^CrpHarvest_", "", grep("^CrpHarvest_", names(x), value = TRUE))
  ok("claim: crop units (2022 Annual area codes, 61 unlabelled in 2021 Annual)", stopifnot(sum(x$CrpHarvestUnit %in% 71:73) == 1478, all(x$rid[x$CrpHarvestUnit %in% 71:73] == "R08"),
    sum(x$CrpHarvestUnit %in% 6) == 61, all(x$CrpHarvestUnit[x$rid %in% c("R09", "R10")] %in% c(1, 3, 4, NA))))
  ok("claim: 216 households with a crop area above 100, up to 40,000", {
    a <- as.matrix(x[, paste0("CrpArea_", crops)]); stopifnot(sum(rowSums(a > 100, na.rm = TRUE) > 0) == 216, max(a, na.rm = TRUE) == 40000) })
  ok("claim: 567 households sell more kg than they harvest (144/204/219)", {
    s <- Reduce(`|`, lapply(crops, function(k) { a <- x[[paste0("CrpSold_", k)]]; b <- x[[paste0("CrpHarvest_", k)]]; !is.na(a) & !is.na(b) & x$CrpHarvestUnit %in% 1 & x$CrpSoldUnit %in% 1 & a > b }))
    stopifnot(sum(s) == 567, all(as.integer(table(x$rid[s])) == c(144, 204, 219))) })
  ok("claim: impossible crop values set to missing", stopifnot(all(x$CrpGardeningMonths <= 12, na.rm = TRUE),
    all(as.matrix(x[, grep("^CrpArea_|^CrpHarvest_[A-Z]|^CrpSold_[A-Z]|^CrpPostHarvestLoss$", names(x))]) >= 0, na.rm = TRUE)))
  ok("claim: months usually covered by own production from 2022 PDM; AgrMonthsOwnProduction not in 2022 PDM",
    stopifnot(all(x$rid[!is.na(x$CrpMonthsOwnProdUsual)] %in% c("R07", "R08", "R09", "R10")), sum(!is.na(x$CrpMonthsOwnProdUsual[x$rid == "R07"])) == 1368, all(is.na(x$AgrMonthsOwnProduction[x$rid == "R07"]))))
  ok("claim: tuber sources asked of the cereal households", stopifnot(identical(is.na(x$FsrOwnProdGift_Tubers), is.na(x$FsrOwnProdGift_Cereals)), sum(!is.na(x$FsrOwnProdGift_Cereals)) > 8000))
  any_pos <- function(z, p) { m <- as.matrix(z[, grep(p, names(z))]); v <- ifelse(rowSums(!is.na(m)) == 0, NA, rowSums(m > 0, na.rm = TRUE) > 0); m_or_na(100 * v) }
  chk("crp_harvest_any", function(z) any_pos(z, "^CrpHarvest_[A-Z]"))
  chk("crp_sold_any", function(z) any_pos(z, "^CrpSold_[A-Z]"))
  chk("fsr_bought", function(z) m_or_na(100 * (z$FsrBoughtFood7d == 1)))
  chk("fsr_own_cereals", function(z) m_or_na(100 * (z$FsrOwnProdGift_Cereals == 1)))
  ok("claim: places", stopifnot(d$places$value[d$places$measure == "Village names before cleaning"] == 387, d$places$value[d$places$measure == "Village names in the merged file"] == 321, d$places$value[d$places$measure == "Households without a department before cleaning"] == 272))
} else cat("  merged file not found or demo data: skipped\n")

section("Data boundary")
ok("no household columns in data/", {
  for (f in list.files("data", pattern = "\\.csv$", full.names = TRUE)) {
    hdr <- gsub("\"", "", strsplit(readLines(f, n = 1, warn = FALSE), ",")[[1]])
    stopifnot(!any(c("ID", "hh_id", "uuid", "village", "Longitude", "Latitude") %in% hdr))
  }
})
ok("no household rows: every table is smaller than the survey", stopifnot(max(vapply(list.files("data", pattern = "\\.csv$", full.names = TRUE), function(f) length(readLines(f, warn = FALSE)), 0L)) < d$manifest$households))
hidden_cols <- c("ID", "village", "Longitude", "Latitude", "Longitude_precision", "Latitude_precision", "DateDerniereAssist_other", "IP_var", "SvyDate")
ok("identifying columns have no values or ranges", stopifnot(!any(d$variable_values$variable %in% hidden_cols), !any(d$variable_numeric$variable %in% hidden_cols), all(hidden_cols %in% d$merged_columns$variable[d$merged_columns$kind == "hidden"])))
ok("answers under 5 households have no count or share", stopifnot(all(is.na(d$variable_values$households[d$variable_values$suppressed])), all(is.na(d$variable_values$pct[d$variable_values$suppressed])), all(d$variable_values$households[!d$variable_values$suppressed] >= 5)))
ok("regional cells under 30 households suppressed", {
  small <- d$ind_region[d$ind_region$households < 30, ]; cols <- grep("_[mc]$", names(small), value = TRUE)
  stopifnot(nrow(small) > 0, all(is.na(small[, cols])))
})
ok("department cells under 30 households hidden", stopifnot(all(is.na(d$admin2$households) | d$admin2$households >= 30)))
ok("assistance cells under 30 answers suppressed", stopifnot(all(is.na(d$assistance_region$yes_pct[d$assistance_region$answered < 30]))))
ok("no local paths in the manifest", stopifnot(!any(grepl("[A-Za-z]:[\\\\/]|OneDrive|AHema", readLines("data/manifest.json", warn = FALSE)))))
ok("no village or geography labels in the crosswalk", {
  geo <- d$crosswalk[d$crosswalk$family == "Geography", ]
  stopifnot(all(is.na(geo$value_labels)), all(is.na(geo$range)))
})
ok("flags computed: every flag has a reason", stopifnot(all(nzchar(d$flags$reason))))

section("Login")
Sys.setenv(WFP_CBA_LOCAL = "", WFP_CBA_ACCOUNTS_DB = file.path(tempdir(), "none.sqlite"), WFP_CBA_ACCOUNTS_SECRET = "")
ok("auth: required on a server", stopifnot(auth_required() || interactive()))
if (!interactive()) {
  r <- local({ wd <- setwd(tempdir()); on.exit(setwd(wd)); tryCatch({ check_auth(); "started" }, error = function(e) conditionMessage(e)) })
  ok("auth: refuses to start without accounts", stopifnot(grepl("refusing", r)))
  if (requireNamespace("shinymanager", quietly = TRUE)) {
    db <- file.path(tempdir(), "accounts_test.sqlite")
    shinymanager::create_db(data.frame(user = "tester", password = "correct-horse", admin = FALSE, stringsAsFactors = FALSE), sqlite_path = db, passphrase = "test-secret")
    Sys.setenv(WFP_CBA_ACCOUNTS_DB = db, WFP_CBA_ACCOUNTS_SECRET = "test-secret")
    ok("auth: starts with accounts", check_auth())
    ok("auth: login page built", stopifnot(is.function(protect_ui(shiny::fluidPage()))))
    chk_login <- shinymanager::check_credentials(db, passphrase = "test-secret")
    ok("auth: right password", stopifnot(isTRUE(chk_login("tester", "correct-horse")$result)))
    ok("auth: wrong password", stopifnot(isFALSE(chk_login("tester", "wrong")$result)))
  }
}
Sys.setenv(WFP_CBA_LOCAL = "1", WFP_CBA_ACCOUNTS_DB = "", WFP_CBA_ACCOUNTS_SECRET = "")

ok("shinyAppDir", app <- shiny::shinyAppDir("."))

cat(if (failures) sprintf("\n%d of %d checks FAILED\n", failures, n_checks) else sprintf("\nAll %d checks passed\n", n_checks))
if (failures) quit(status = 1)
