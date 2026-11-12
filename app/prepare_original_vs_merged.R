# Statistics of the original (raw SPSS) files against the merged file, variable by variable and round by round.
# Sourced by prepare_app_data.R, which has already read the raw files (raw), the merged file (x, final_lab), the two
# workbooks (hv, ext) and the rounds (cfg_rounds). Writes three tables of aggregates and adds checks:
#   original_vs_merged_variables.csv   one row per variable and round: answers, mean, median, min, max on both sides,
#                                      households with the same value, and a status
#   original_vs_merged_categories.csv  how each raw code became a merged code (coded variables, 40 values or fewer)
#   original_vs_merged_indicators.csv  FCS and rCSI computed from the raw items, against the merged file
# National figures by round only. Identifiers, places, GPS and dates of interview are left out; text is only counted;
# category counts under 5 households are blank.

say("Original files against the merged file...")
OVM_MIN_COUNT <- 5
OVM_MAX_CATEGORIES <- 40
OVM_STATUS <- c(identical = "Identical", coverage = "Same values, different number of answers",
                differ = "Values differ: recoded on purpose, or a defect", built = "Built in the merge (no raw column)",
                absent = "Not in the merged file", text = "Text: answers counted only", date = "Date: answers counted only",
                none = "No household answered in both")

ovm_source <- function(ds, v) { s <- source_any(ds, v); if (!is.na(s) && s %in% names(raw[[ds]])) s else NA_character_ }
# The raw row of each merged household of a round, in the merged file's order (first row of an ID, as in do-file 12).
ovm_index <- list()
for (i in seq_len(nrow(cfg_rounds))) {
  ds <- cfg_rounds$dataset[i]; ids <- raw_ids(ds); keep <- which(!duplicated(ids))
  ovm_index[[ds]] <- keep[match(x$ID[x$round_id == cfg_rounds$round_id[i]], ids[keep])]
}
ovm_vars <- setdiff(unique(ALL_MAPPED), c(SENSITIVE_META, "SvyDatePDM"))
ovm_nonmiss <- function(z) if (is.character(z)) !is.na(z) & nzchar(trimws(z)) else !is.na(z)
ovm_stats <- function(z) { z <- z[!is.na(z)]; if (!length(z)) return(rep(NA_real_, 4)); c(mean(z), stats::median(z), min(z), max(z)) }
ovm_label <- function(code, vl) {
  if (is.na(code)) return("(missing)")
  if (is.null(vl)) return("")
  m <- names(vl)[match(code, vl)]
  if (is.na(m)) "" else clean_text(m)
}

ovm_rows <- list(); ovm_cats <- list()
for (i in seq_len(nrow(cfg_rounds))) {
  ds <- cfg_rounds$dataset[i]; rid <- cfg_rounds$round_id[i]
  xr <- x[x$round_id == rid, ]; idx <- ovm_index[[ds]]
  for (v in ovm_vars) {
    s <- ovm_source(ds, v)
    in_merged <- v %in% names(x)
    if (is.na(s) && (!in_merged || !any(ovm_nonmiss(xr[[v]])))) next
    raw_all <- if (!is.na(s)) raw[[ds]][[s]] else NULL
    raw_m <- if (!is.na(s)) haven::zap_labels(raw_all)[idx] else NULL
    mer <- if (in_merged) xr[[v]] else NULL
    is_text <- (!is.null(raw_m) && is.character(raw_m)) || (!is.null(mer) && is.character(mer))
    is_date <- !is.null(raw_all) && inherits(raw_all, c("Date", "POSIXt"))
    a <- if (!is.null(raw_m) && !is_text && !is_date) suppressWarnings(as.numeric(raw_m)) else NULL
    b <- if (!is.null(mer) && !is_text && !is_date) suppressWarnings(as.numeric(mer)) else NULL
    k <- if (!is.null(a) && !is.null(b)) !is.na(a) & !is.na(b) else logical(0)
    n_raw <- if (!is.null(raw_m)) sum(ovm_nonmiss(raw_m)) else NA_integer_
    n_mer <- if (!is.null(mer)) sum(ovm_nonmiss(mer)) else NA_integer_
    same <- if (any(k)) sum(a[k] == b[k]) else NA_integer_
    pct <- if (any(k)) round(100 * mean(a[k] == b[k]), 1) else NA_real_
    status <- if (is.na(s)) OVM_STATUS[["built"]] else if (!in_merged) OVM_STATUS[["absent"]] else if (is_text) OVM_STATUS[["text"]] else
      if (is_date) OVM_STATUS[["date"]] else if (!any(k)) OVM_STATUS[["none"]] else if (pct == 100 && n_raw == n_mer) OVM_STATUS[["identical"]] else
      if (pct == 100) OVM_STATUS[["coverage"]] else OVM_STATUS[["differ"]]
    sr <- if (!is.null(a)) ovm_stats(a) else rep(NA_real_, 4)
    sm <- if (!is.null(b)) ovm_stats(b) else rep(NA_real_, 4)
    ovm_rows[[length(ovm_rows) + 1]] <- data.frame(
      round_id = rid, variable = v, family = family_of(v),
      workbook = if (v %in% ext$NewVariable_Name) "2026 modules" else "First harmonisation",
      raw_column = if (is.na(s)) NA_character_ else s,
      raw_rows_answered = if (!is.null(raw_all)) sum(ovm_nonmiss(haven::zap_labels(raw_all))) else NA_integer_,
      raw_answered = n_raw, merged_answered = n_mer,
      raw_mean = sr[1], merged_mean = sm[1], raw_median = sr[2], merged_median = sm[2],
      raw_min = sr[3], merged_min = sm[3], raw_max = sr[4], merged_max = sm[4],
      compared = sum(k), same_value = same, pct_same = pct, status = status, stringsAsFactors = FALSE)

    # How each raw code became a merged code, for coded variables with few values.
    if (!is.null(a) && !is.null(b)) {
      raw_vl <- attr(raw_all, "labels", exact = TRUE); mer_vl <- attr(final_lab[[v]], "labels", exact = TRUE)
      if ((!is.null(raw_vl) || !is.null(mer_vl)) && length(unique(c(a[!is.na(a)], b[!is.na(b)]))) <= OVM_MAX_CATEGORIES) {
        tab <- as.data.frame(table(raw_code = a, merged_code = b, useNA = "ifany"), stringsAsFactors = FALSE)
        tab <- tab[tab$Freq > 0, ]
        if (nrow(tab)) {
          rc <- suppressWarnings(as.numeric(tab$raw_code)); mc <- suppressWarnings(as.numeric(tab$merged_code))
          key <- function(z) ifelse(is.na(z), "NA", format(z, scientific = FALSE, trim = TRUE))
          rt <- table(key(a)); mt <- table(key(b))
          ovm_cats[[length(ovm_cats) + 1]] <- data.frame(
            round_id = rid, variable = v, raw_code = rc, raw_label = vapply(rc, ovm_label, "", vl = raw_vl),
            merged_code = mc, merged_label = vapply(mc, ovm_label, "", vl = mer_vl), households = tab$Freq,
            raw_code_total = as.integer(rt[key(rc)]), merged_code_total = as.integer(mt[key(mc)]), stringsAsFactors = FALSE)
        }
      }
    }
  }
}
ovm_variables <- bind_rows(ovm_rows) |>
  mutate(across(c(raw_mean, merged_mean, raw_median, merged_median, raw_min, merged_min, raw_max, merged_max), ~ round(.x, 3)))
ovm_categories <- bind_rows(ovm_cats) |>
  mutate(pct_of_raw_code = round(100 * households / raw_code_total, 1),
         same_code = (is.na(raw_code) & is.na(merged_code)) | (!is.na(raw_code) & !is.na(merged_code) & raw_code == merged_code),
         suppressed = households < OVM_MIN_COUNT) |>
  mutate(across(c(households, raw_code_total, merged_code_total), ~ ifelse(.x < OVM_MIN_COUNT, NA, .x)),
         pct_of_raw_code = ifelse(suppressed, NA, pct_of_raw_code)) |>
  arrange(match(round_id, cfg_rounds$round_id), match(variable, ovm_vars), raw_code, merged_code)

# FCS and rCSI from the raw items, through the workbook's mapping, against the merged scores.
OVM_FCS_W <- c(FCSStap = 2, FCSPulse = 3, FCSDairy = 4, FCSPr = 4, FCSVeg = 1, FCSFruit = 1, FCSFat = .5, FCSSugar = .5)
OVM_RCSI_W <- c(rCSILessQlty = 1, rCSIBorrow = 2, rCSIMealNb = 1, rCSIMealSize = 1, rCSIMealAdult = 3)
ovm_score <- function(ds, w) {
  cols <- vapply(names(w), function(v) ovm_source(ds, v), "")
  if (anyNA(cols)) return(NULL)
  m <- sapply(cols, function(s) suppressWarnings(as.numeric(haven::zap_labels(raw[[ds]][[s]])))[ovm_index[[ds]]])
  as.numeric(m %*% w)
}
ovm_ind <- list()
for (i in seq_len(nrow(cfg_rounds))) {
  ds <- cfg_rounds$dataset[i]; rid <- cfg_rounds$round_id[i]; xr <- x[x$round_id == rid, ]
  f_raw <- ovm_score(ds, OVM_FCS_W); r_raw <- ovm_score(ds, OVM_RCSI_W)
  one <- function(ind, unit, rv, mv, fun) data.frame(
    round_id = rid, indicator = ind, unit = unit,
    raw_households = if (is.null(rv)) NA_integer_ else sum(!is.na(rv)), raw_value = if (is.null(rv)) NA_real_ else fun(rv),
    merged_households = sum(!is.na(mv)), merged_value = fun(mv), stringsAsFactors = FALSE)
  pb <- function(f) 100 * mean(f <= 42, na.rm = TRUE)
  avg <- function(f) mean(f, na.rm = TRUE)
  ovm_ind[[i]] <- rbind(one("Mean FCS", "score", f_raw, xr$FCS, avg), one("Poor + borderline FCS (28/42)", "%", f_raw, xr$FCS, pb),
                        one("Mean rCSI", "score", r_raw, xr$rCSI, avg))
}
# A known difference is explained here; any other one fails the check below.
OVM_EXPLAINED <- c(R03 = "Fixed on purpose: the merged FCS takes the analysts' SCA, as the raw day counts give implausible scores (do-file 15).")
ovm_indicators <- bind_rows(ovm_ind) |>
  mutate(difference = round(merged_value - raw_value, 3), raw_value = round(raw_value, 3), merged_value = round(merged_value, 3),
         note = case_when(
           is.na(raw_value) ~ "Not computable from the raw items: an item has no raw column in this round.",
           abs(difference) < 0.05 ~ "Same.",
           grepl("FCS", indicator) & round_id %in% names(OVM_EXPLAINED) ~ unname(OVM_EXPLAINED[round_id]),
           raw_households != merged_households ~ sprintf("Differs by the households scored: %d in the merged file, %d from the raw items.", merged_households, raw_households),
           TRUE ~ "Unexplained difference."))

n_unexplained <- sum(ovm_indicators$note == "Unexplained difference.")
add_check("Original files", "FCS and rCSI from the raw items equal the merged scores, or the difference is explained",
          pass_if(n_unexplained == 0), sprintf("%d unexplained", n_unexplained), "0",
          sprintf("Mean FCS, poor + borderline FCS and mean rCSI in %d rounds, recomputed from the raw items through the workbook.", nrow(cfg_rounds)))
st_count <- table(factor(ovm_variables$status, OVM_STATUS))
add_check("Original files", "Every mapped variable is compared with its raw column", pass_if(st_count[[OVM_STATUS[["none"]]]] == 0, "warn"),
          sprintf("%d of %s variable-rounds identical; %d differ", st_count[[OVM_STATUS[["identical"]]]], format(nrow(ovm_variables), big.mark = ","),
                  st_count[[OVM_STATUS[["differ"]]]]),
          "No variable without a household answered in both",
          sprintf("%d variable-rounds have a raw column but no household answered in both files. Values that differ are mostly recodes: see the Original vs merged page.",
                  st_count[[OVM_STATUS[["none"]]]]))

write_out(ovm_variables, "original_vs_merged_variables.csv")
write_out(ovm_categories, "original_vs_merged_categories.csv")
write_out(ovm_indicators, "original_vs_merged_indicators.csv")
