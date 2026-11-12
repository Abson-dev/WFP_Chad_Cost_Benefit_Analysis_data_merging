# The Excel workbook of the "Original vs merged" page, built from the tables the app has loaded, so it always matches
# what the page shows (and is synthetic in the synthetic version).

OVM_STATUS_FILL <- c("Identical" = "#E5F4E4", "Same values, different number of answers" = "#F9EEDA",
                     "Values differ: recoded on purpose, or a defect" = "#FBEBEB")

ovm_summary <- function(d) {
  v <- d$ovm_variables[!is.na(d$ovm_variables$pct_same), ]
  out <- do.call(rbind, lapply(split(v, list(v$workbook, v$round_id), drop = TRUE), function(g) data.frame(
    workbook = g$workbook[1], round_id = g$round_id[1], variables_compared = nrow(g),
    identical = sum(g$status == "Identical"), same_values_other_answers = sum(g$status == "Same values, different number of answers"),
    values_differ = sum(g$status == "Values differ: recoded on purpose, or a defect"),
    households_compared = sum(g$compared), pct_same = round(100 * sum(g$same_value) / sum(g$compared), 1))))
  out$round <- d$rounds$label[match(out$round_id, d$rounds$round_id)]
  out <- out[order(out$workbook, match(out$round_id, d$rounds$round_id)), ]
  out[, c("workbook", "round_id", "round", setdiff(names(out), c("workbook", "round_id", "round")))]
}

original_workbook <- function(d, path) {
  lab <- function(x) { x$round <- d$rounds$label[match(x$round_id, d$rounds$round_id)]; x[, c("round_id", "round", setdiff(names(x), c("round_id", "round")))] }
  sheets <- list(
    Rounds = data.frame(round_id = d$rounds$round_id, round = d$rounds$label, survey = d$rounds$survey, series = d$rounds$series,
                        raw_file = d$rounds$raw_file, raw_rows = d$rounds$raw_rows, duplicates_removed = d$rounds$duplicates_removed,
                        empty_removed = d$rounds$empty_removed, merged_households = d$rounds$final_rows),
    Summary = ovm_summary(d),
    Indicators = lab(d$ovm_indicators),
    Variables = lab(d$ovm_variables),
    Categories = lab(d$ovm_categories)
  )
  wb <- openxlsx::createWorkbook()
  openxlsx::modifyBaseFont(wb, fontSize = 10, fontName = "Calibri")
  head_st <- openxlsx::createStyle(fontColour = "#FFFFFF", fgFill = "#17324D", textDecoration = "bold", wrapText = TRUE, valign = "center")
  openxlsx::addWorksheet(wb, "Read me")
  readme <- c(
    "WFP Chad resilience surveys, 2018-2023: the original files against the merged file",
    "",
    sprintf("Merged file: %s (%s households, %d columns). Original files: the 10 raw SPSS files of WFP. Data refreshed %s.",
            d$manifest$merged_file, fmt_int(d$manifest$households), d$manifest$columns, substr(d$manifest$run_utc, 1, 10)),
    "Every variable of the two harmonisation workbooks is compared, round by round, on the households of the merged file: each merged household is matched to its raw row by ID (the first row of a duplicated ID, as in the merge; the 2022 PDM by row number).",
    "",
    "Sheets",
    "  Rounds: rows in each raw file, duplicates and empty interviews removed, households in the merged file.",
    "  Summary: by workbook and round, how many variables are identical, keep their values with a different number of answers, or have different values.",
    "  Indicators: mean FCS, poor + borderline FCS and mean rCSI computed from the raw items (through the workbook's mapping) and in the merged file, with the reason for any difference.",
    "  Variables: one row per variable and round: answers in the raw file and in the merged file, mean, median, min and max on both sides (raw codes as they are), and the share of households with the same value.",
    "  Categories: for coded variables (40 values or fewer), how each raw code became a merged code: households per pair, totals per code, and whether the code was kept.",
    "",
    "Status of a variable",
    "  Identical: every household has the same value, and the same households answered.",
    "  Same values, different number of answers: the merge left some answers out or added some (a question asked of some households only, or answers set to missing on purpose).",
    "  Values differ: the merge recoded the variable on purpose (codes put on one scale across rounds, see Categories), or a defect: the issue register (Data issues page) says which.",
    "  Built in the merge: the merged variable has no raw column in that round. Means of coded variables compare codes, not quantities.",
    "",
    "Limits",
    "  National figures by round only, unweighted, over the households surveyed. No identifier, place, GPS or free text; category counts under 5 households are blank.",
    "  The data belong to WFP: share this file only as agreed with WFP."
  )
  if (demo_mode()) readme <- c("SYNTHETIC DATA: every figure in this workbook is invented.", "", readme)
  openxlsx::writeData(wb, "Read me", readme)
  openxlsx::addStyle(wb, "Read me", openxlsx::createStyle(fontSize = 14, textDecoration = "bold", fontColour = "#17324D"), 1, 1)
  openxlsx::setColWidths(wb, "Read me", 1, 160)
  for (nm in names(sheets)) {
    df <- sheets[[nm]]
    openxlsx::addWorksheet(wb, nm)
    openxlsx::writeData(wb, nm, df, headerStyle = head_st, withFilter = TRUE)
    openxlsx::freezePane(wb, nm, firstRow = TRUE)
    openxlsx::setColWidths(wb, nm, seq_along(df), "auto")
  }
  sc <- match("status", names(sheets$Variables))
  for (s in names(OVM_STATUS_FILL)) {
    rows <- which(sheets$Variables$status == s) + 1
    if (length(rows)) openxlsx::addStyle(wb, "Variables", openxlsx::createStyle(fgFill = OVM_STATUS_FILL[[s]]), rows, sc, gridExpand = TRUE, stack = TRUE)
  }
  openxlsx::saveWorkbook(wb, path, overwrite = TRUE)
  invisible(path)
}
