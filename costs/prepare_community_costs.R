# Community costs by village, and the match of the cost villages to the surveyed villages. From the repository's root:
#   Rscript costs/prepare_community_costs.R
#
# Reads IFPRI's community template ("TEMPLATE_Community (resilience)_20241216.xlsx"), which gives the villages of
# each cost line and splits its cost into transfer and capacity costs, and the merged survey file, all read-only.
# Writes to "cost data clean/", outside this repository: village names identify places below the department.
#
# Step 1. Costs by village
#   - A cost sits on one row and covers the rows below it in the same partner block until the next row with a cost
#     of the same kind (in 2020 April-December, one lump sum per partner). The block's villages are those of all its
#     rows; a row with no village takes the villages of the row above, within the partner block.
#   - A block's cost is split equally between its villages (assumption: no village weights are given). Transfer and
#     capacity costs are split separately. The beneficiary households (Menage) are split the same way.
#   - Blocks with no village keep their cost at department level ("no village").
# Step 2. Match to the surveyed villages
#   - Names are compared once written plainly (capitals, no accents or punctuation).
#   - Within the surveyed departments the cost department maps to (costs/department_crosswalk.csv): same name, then a
#     close name (Jaro-Winkler distance up to 0.12). Otherwise the same name elsewhere in the region.
#   - Decisions of a person, kept in "cost data/village_matches_manual.csv" (outside the repository), win.
#
# The script stops if a sheet's lines disagree with its subtotals or the split loses money.

suppressPackageStartupMessages({ library(readxl); library(dplyr); library(readr); library(stringdist) })
BASE <- Sys.getenv("WFP_MERGED_DIR", "C:/Users/AHema/OneDrive - CGIAR/Desktop/2024/WFP/CBA - Chad/data")
SRC <- file.path(BASE, "cost data", "TEMPLATE_Community (resilience)_20241216.xlsx")
REVISED <- file.path(BASE, "cost data clean", "cost_reconciliation.csv")
MERGED <- file.path(BASE, "WFP_Chad_2018-2023_20261106_v5.dta")
MANUAL <- Sys.getenv("WFP_VILLAGE_DECISIONS", file.path(BASE, "cost data", "village_matches_manual.csv"))  # another file to try decisions
OUT <- file.path(BASE, "cost data clean")
dir.create(OUT, showWarnings = FALSE)

PERIODS <- list(
  "2019" = list(year = 2019, period = "2019"),
  "2020 (jan-mar)" = list(year = 2020, period = "2020 Jan-Mar"),
  "2020 (apr-dec)" = list(year = 2020, period = "2020 Apr-Dec"),
  "2021" = list(year = 2021, period = "2021"),
  "2022" = list(year = 2022, period = "2022"),
  "2023" = list(year = 2023, period = "2023"))
num <- function(v) suppressWarnings(as.numeric(gsub("[ \u00a0\u202f,]", "", ifelse(trimws(v) %in% c("-", ""), NA, v))))
plain <- function(v) {
  v <- toupper(stringi::stri_trans_general(v, "Latin-ASCII"))
  v <- gsub("[^A-Z0-9 ]", " ", v)
  trimws(gsub("\\s+", " ", v))
}
# "Village A1, Village A2 et Village B; Village C" -> four names
split_villages <- function(s) {
  if (is.na(s) || !nzchar(trimws(s))) return(character(0))
  parts <- unlist(strsplit(s, "(?i)\\s*(,|;|/|&|\\bet\\b|\\+)\\s*", perl = TRUE))
  parts <- plain(parts)
  parts <- sub("^(VILLAGES?|VLG) ", "", parts)
  parts <- trimws(gsub("\\b[0-9]+ ?(HA|M3|ML|KM)\\b", "", parts))   # "VILLAGE 30HA": an area, not part of the name
  unique(parts[nchar(parts) >= 2])
}

sheets <- excel_sheets(SRC)
period_sheets <- sheets[trimws(sheets) %in% names(PERIODS)]
if (length(period_sheets) != length(PERIODS)) stop("Unexpected sheets: ", paste(sheets, collapse = ", "), call. = FALSE)

lines <- list(); recon <- list()
for (s in period_sheets) {
  p <- PERIODS[[trimws(s)]]
  x <- as.data.frame(suppressMessages(read_excel(SRC, s, col_names = FALSE, col_types = "text")))
  h <- which(apply(x, 1, function(r) any(r %in% "Sub office")))[1]
  names(x) <- make.names(trimws(as.character(unlist(x[h, ]))), unique = TRUE)
  b <- x[(h + 1):nrow(x), , drop = FALSE]
  b$source_row <- seq_len(nrow(b)) + h
  b$transfer <- num(b$Transfer.cost); b$capacity <- num(b$Capacity.cost)
  # A sub-office cell that is a bare number is a stray value, not a place.
  b$Sub.office[grepl("^[0-9.]+$", trimws(b$Sub.office))] <- NA
  is_total <- !is.na(b$Sub.office) & grepl("^total", trimws(b$Sub.office), ignore.case = TRUE)
  is_general <- is_total & grepl("general", b$Sub.office, ignore.case = TRUE)
  # Check each labelled subtotal of the transfer cost against the lines above it. Excel's SUM skips amounts typed
  # as text ("1 450 500"): such a subtotal is accepted, and recorded, when it equals the lines typed as numbers.
  as_typed <- suppressWarnings(as.numeric(b$Transfer.cost))
  checked <- 0; text_skipped <- 0; acc <- 0; acc_typed <- 0
  unlabelled <- rep(FALSE, nrow(b))
  for (i in seq_len(nrow(b))) {
    if (is_general[i]) next
    # A row with an amount but no activity that equals the lines above it is an unlabelled subtotal (Farchana).
    if (!is_total[i] && !is.na(b$transfer[i]) && is.na(b$Actif[i]) && acc > 0 && abs(b$transfer[i] - acc) <= 1) {
      unlabelled[i] <- TRUE; checked <- checked + 1; acc <- 0; acc_typed <- 0; next
    }
    if (is_total[i]) {
      if (!is.na(b$transfer[i])) {
        if (abs(b$transfer[i] - acc) > 1) {
          if (abs(b$transfer[i] - acc_typed) > 1) stop(sprintf("%s row %d: transfer subtotal %.0f, lines %.0f", s, b$source_row[i], b$transfer[i], acc), call. = FALSE)
          text_skipped <- text_skipped + 1
        }
        checked <- checked + 1
      }
      acc <- 0; acc_typed <- 0
    } else if (!is.na(b$transfer[i])) { acc <- acc + b$transfer[i]; acc_typed <- acc_typed + ifelse(is.na(as_typed[i]), 0, as_typed[i]) }
  }
  keep <- !is_total & !unlabelled & (!is.na(b$Actif) | !is.na(b$transfer) | !is.na(b$capacity))
  # Places are filled down within a sub-office block; the partner within a department.
  fill <- function(v) { v <- ifelse(is_total, NA, v); for (i in seq_along(v)[-1]) if (is.na(v[i]) && !is_total[i]) v[i] <- v[i - 1]; v }
  b$sub_office <- fill(b$Sub.office); b$province <- fill(b$Province); b$department <- fill(b$Departement); b$partner <- fill(b$CP)
  b <- b[keep, ]
  lines[[s]] <- data.frame(year = p$year, period = p$period, source_sheet = trimws(s), source_row = b$source_row,
                           sub_office = trimws(b$sub_office), province = trimws(b$province), department = trimws(b$department),
                           partner = toupper(trimws(b$partner)), villages_text = trimws(b$Villages), activity = trimws(gsub("\\s+", " ", b$Actif)),
                           unit = trimws(b$Unit.mea), outcome = num(b$Outcome), transfer_xaf = b$transfer, capacity_xaf = b$capacity,
                           households = num(b$Menage), stringsAsFactors = FALSE)
  recon[[s]] <- data.frame(period = p$period, lines = nrow(b), transfer_xaf = sum(b$transfer, na.rm = TRUE), capacity_xaf = sum(b$capacity, na.rm = TRUE),
                           subtotals_checked = checked, subtotals_skipping_text = text_skipped)
}
cl <- bind_rows(lines)
cl$period <- factor(cl$period, levels = vapply(PERIODS, `[[`, "", "period"))
cl <- arrange(cl, period, source_row) |> mutate(period = as.character(period))
recon <- bind_rows(recon)
# A sub-office lost to a stray number (2022, Mao) is taken from the same department in the other rows.
known <- cl[!is.na(cl$sub_office), ]; known <- known[!duplicated(known$department), ]
cl$sub_office <- ifelse(is.na(cl$sub_office), known$sub_office[match(cl$department, known$department)], cl$sub_office)
cl$partner[is.na(cl$partner)] <- "(NOT GIVEN)"
# Rows whose capacity cost repeats the transfer cost: possibly a copied column, to confirm with WFP.
cl$capacity_equals_transfer <- !is.na(cl$transfer_xaf) & !is.na(cl$capacity_xaf) & cl$transfer_xaf > 0 & abs(cl$transfer_xaf - cl$capacity_xaf) < 1
if (anyNA(cl$sub_office) || anyNA(cl$partner)) {
  print(cl[is.na(cl$sub_office) | is.na(cl$partner), c("period", "source_row", "sub_office", "department", "partner", "transfer_xaf", "capacity_xaf")])
  stop("Lines without a sub-office or partner.", call. = FALSE)
}

# Villages: a row without villages takes those of the row above in the same partner block.
nr <- nrow(cl)
cl$block_partner <- cumsum(c(TRUE, with(cl, period[-1] != period[-nr] | sub_office[-1] != sub_office[-nr] | partner[-1] != partner[-nr] |
                                          department[-1] != department[-nr])))
cl$villages_filled <- cl$villages_text
for (i in seq_len(nrow(cl))[-1]) if ((is.na(cl$villages_filled[i]) || !nzchar(cl$villages_filled[i])) && cl$block_partner[i] == cl$block_partner[i - 1]) cl$villages_filled[i] <- cl$villages_filled[i - 1]
cl$village_list <- lapply(cl$villages_filled, split_villages)

# ---- Step 1: cost blocks and the split by village ----------------------------------------------------------
blocks_of <- function(kind) {
  amount <- cl[[paste0(kind, "_xaf")]]
  out <- list()
  for (g in unique(cl$block_partner)) {
    idx <- which(cl$block_partner == g)
    starts <- idx[!is.na(amount[idx])]
    for (k in seq_along(starts)) {
      rows <- starts[k]:(if (k < length(starts)) starts[k + 1] - 1 else max(idx))
      v <- unique(unlist(cl$village_list[rows]))
      out[[length(out) + 1]] <- data.frame(kind = kind, period = cl$period[starts[k]], year = cl$year[starts[k]], sub_office = cl$sub_office[starts[k]],
                                           department = cl$department[starts[k]], partner = cl$partner[starts[k]], first_row = cl$source_row[starts[k]],
                                           rows = length(rows), amount_xaf = amount[starts[k]], households = sum(cl$households[rows], na.rm = TRUE),
                                           villages = paste(v, collapse = "; "), n_villages = length(v),
                                           repeats_transfer = kind == "capacity" && isTRUE(cl$capacity_equals_transfer[starts[k]]),
                                           row_idx = paste(rows, collapse = ","), stringsAsFactors = FALSE)
    }
  }
  bind_rows(out)
}
blocks <- bind_rows(blocks_of("transfer"), blocks_of("capacity"))
split <- bind_rows(lapply(seq_len(nrow(blocks)), function(i) {
  r <- blocks[i, ]; v <- if (r$n_villages > 0) strsplit(r$villages, "; ", fixed = TRUE)[[1]] else "(no village)"
  data.frame(r[c("kind", "period", "year", "sub_office", "department", "partner", "first_row", "repeats_transfer")], village = v, amount_xaf = r$amount_xaf / length(v),
             households = r$households / length(v), share = 1 / length(v), stringsAsFactors = FALSE, row.names = NULL)
}))
for (k in c("transfer", "capacity")) {
  if (abs(sum(split$amount_xaf[split$kind == k]) - sum(cl[[paste0(k, "_xaf")]], na.rm = TRUE)) > 1) stop("The split by village loses ", k, " costs.", call. = FALSE)
}
village_costs <- split |> group_by(year, period, sub_office, department, village) |>
  summarise(transfer_xaf = sum(amount_xaf[kind == "transfer"]), capacity_xaf = sum(amount_xaf[kind == "capacity"]),
            capacity_repeats_transfer_xaf = sum(amount_xaf[kind == "capacity" & repeats_transfer]),
            beneficiary_households = sum(households[kind == "transfer"]), blocks = n_distinct(paste(kind, first_row)),
            shared_blocks = sum(share < 1), partners = paste(sort(unique(partner)), collapse = "; "), .groups = "drop")

# ---- Step 1b: asset type, with the activity rules of the department costs (costs/activity_categories.csv) -------
# A block's cost is shared equally between the activity rows it covers, then between its villages. The 2020
# April-December lump sums are not allocated to an activity, as in prepare_cost_data.R.
rules <- as.data.frame(read_csv("costs/activity_categories.csv", show_col_types = FALSE))
rules <- rules[order(rules$order), ]
plain_text <- function(v) tolower(chartr("àâäéèêëîïôöùûüçœ’'", "aaaeeeeiioouuuco''", tolower(v)))
categorise <- function(text) {
  t <- plain_text(text); out <- rep(NA_character_, length(t))
  for (i in seq_len(nrow(rules))) { hit <- is.na(out) & !is.na(t) & grepl(rules$pattern[i], t, perl = TRUE); out[hit] <- rules$category[i] }
  ifelse(is.na(out), "Other or unclear", out)
}
LUMP <- "Partner lump sum (COVID-19), not allocated"
cl$category <- categorise(cl$activity)
cl$amount_category <- ifelse(cl$period == "2020 Apr-Dec", LUMP, cl$category)
long <- bind_rows(lapply(seq_len(nrow(blocks)), function(i) {
  r <- blocks[i, ]; idx <- as.integer(strsplit(r$row_idx, ",", fixed = TRUE)[[1]])
  v <- if (r$n_villages > 0) strsplit(r$villages, "; ", fixed = TRUE)[[1]] else "(no village)"
  g <- expand.grid(village = v, row = idx, stringsAsFactors = FALSE)
  data.frame(kind = r$kind, year = r$year, period = r$period, sub_office = r$sub_office, department = r$department, village = g$village,
             category = cl$amount_category[g$row], amount_xaf = r$amount_xaf / nrow(g), stringsAsFactors = FALSE)
}))
village_category <- long |> group_by(year, period, sub_office, department, village, category) |>
  summarise(transfer_xaf = sum(amount_xaf[kind == "transfer"]), capacity_xaf = sum(amount_xaf[kind == "capacity"]), .groups = "drop")
if (abs(sum(village_category$transfer_xaf) - sum(village_costs$transfer_xaf)) > 1 ||
    abs(sum(village_category$capacity_xaf) - sum(village_costs$capacity_xaf)) > 1) stop("The split by asset type loses money.", call. = FALSE)

# ---- Step 2: match the cost villages to the surveyed villages ------------------------------------------------
xw <- as.data.frame(read_csv("costs/department_crosswalk.csv", show_col_types = FALSE, locale = locale(encoding = "UTF-8")))
xw$key <- plain(xw$cost_department)
sv <- as.data.frame(haven::zap_labels(haven::read_dta(MERGED, col_select = c(YEAR, ADMIN1Name, ADMIN2Name, adm2_ocha, village))))
sv <- sv[!is.na(sv$village) & nzchar(sv$village), ]
sv$village_plain <- plain(sv$village)
survey_villages <- sv |> group_by(adm2_ocha, ADMIN1Name, ADMIN2Name, village_plain) |>
  summarise(survey_name = names(sort(table(village), decreasing = TRUE))[1], households = n(),
            years = paste(sort(unique(YEAR)), collapse = ";"), .groups = "drop")

cost_villages <- village_costs |> filter(village != "(no village)") |> distinct(department, province = NA_character_, village)
cost_villages$province <- cl$province[match(cost_villages$department, cl$department)]
cost_villages$dept_key <- plain(cost_villages$department)
region_of <- function(prov) { r <- plain(prov); r[r == "OUADDAI"] <- "OUADDAI"; r }

match_one <- function(v, dept_key, province) {
  ocha <- xw$adm2_ocha[xw$key == dept_key & !is.na(xw$adm2_ocha)]
  cand <- survey_villages[survey_villages$adm2_ocha %in% ocha, ]
  if (nrow(cand)) {
    ex <- cand[cand$village_plain == v, ]
    if (nrow(ex)) return(data.frame(match = "Same name", survey_village = ex$village_plain[1], survey_name = ex$survey_name[1], adm2_ocha = ex$adm2_ocha[1], distance = 0))
    # "<surveyed name> <site>": the surveyed name followed by a site or a neighbourhood.
    pre <- cand[nchar(cand$village_plain) >= 4 & startsWith(v, paste0(cand$village_plain, " ")), ]
    if (nrow(pre)) {
      pre <- pre[order(-nchar(pre$village_plain)), ]
      return(data.frame(match = "Surveyed name + suffix", survey_village = pre$village_plain[1], survey_name = pre$survey_name[1], adm2_ocha = pre$adm2_ocha[1], distance = NA))
    }
    # The surveys spell one village several ways: every close spelling is kept, one row each.
    d <- stringdist(v, cand$village_plain, method = "jw", p = 0.1)
    close <- which(d <= 0.12)
    if (length(close)) {
      close <- close[order(d[close])]
      return(data.frame(match = "Close name", survey_village = cand$village_plain[close], survey_name = cand$survey_name[close],
                        adm2_ocha = cand$adm2_ocha[close], distance = round(d[close], 3)))
    }
  }
  reg <- survey_villages[plain(survey_villages$ADMIN1Name) == region_of(province) & survey_villages$village_plain == v, ]
  if (nrow(reg)) return(data.frame(match = "Same name, other department", survey_village = reg$village_plain[1], survey_name = reg$survey_name[1], adm2_ocha = reg$adm2_ocha[1], distance = 0))
  data.frame(match = if (!length(ocha)) "No surveyed department" else "Not surveyed", survey_village = NA, survey_name = NA, adm2_ocha = NA, distance = NA)
}
vm <- bind_rows(lapply(seq_len(nrow(cost_villages)), function(i) {
  m <- match_one(cost_villages$village[i], cost_villages$dept_key[i], cost_villages$province[i])
  cbind(cost_villages[rep(i, nrow(m)), ], m, row.names = NULL)
}))
# A person's decisions: all rows of a (department, cost village) pair in the file replace the automatic ones.
# An empty survey_village means "checked, not a surveyed village".
if (file.exists(MANUAL)) {
  man <- as.data.frame(read_csv(MANUAL, show_col_types = FALSE, col_types = cols(.default = "c")))
  man$key <- paste(plain(man$department), plain(man$cost_village))
  for (k in unique(man$key)) {
    w <- which(paste(plain(vm$department), vm$village) == k)
    if (!length(w)) { warning("Manual match not found: ", k); next }
    base <- vm[w[1], c("department", "province", "village", "dept_key")]
    rows <- man[man$key == k, ]
    new <- bind_rows(lapply(seq_len(nrow(rows)), function(j) {
      s <- rows$survey_village[j]
      if (is.na(s) || !nzchar(s)) return(data.frame(base, match = "Checked: not surveyed", survey_village = NA, survey_name = NA, adm2_ocha = NA, distance = NA))
      sv_j <- survey_villages[survey_villages$village_plain == plain(s), ]
      if (!is.na(rows$adm2_ocha[j]) && nzchar(rows$adm2_ocha[j])) sv_j <- sv_j[sv_j$adm2_ocha == rows$adm2_ocha[j], ]
      if (!nrow(sv_j)) stop("Manual match: surveyed village not found: ", s, call. = FALSE)
      data.frame(base, match = "Checked by hand", survey_village = sv_j$village_plain[1], survey_name = sv_j$survey_name[1], adm2_ocha = sv_j$adm2_ocha[1], distance = NA)
    }))
    vm <- bind_rows(vm[-w, ], new)
  }
}
vm <- distinct(vm)
vm <- select(vm, department, province, cost_village = village, match, survey_village, survey_name, adm2_ocha, distance)

# How many surveyed households live in a village with community costs, by year.
matched <- vm[!is.na(vm$survey_village), ]
cost_years <- village_costs |> filter(village != "(no village)") |> inner_join(matched, by = c("department", "village" = "cost_village")) |>
  distinct(survey_village, adm2_ocha, year)
sv_year <- sv |> filter(YEAR >= 2019) |> mutate(has_cost_village = paste(village_plain, adm2_ocha) %in% paste(matched$survey_village, matched$adm2_ocha),
                                                 cost_same_year = paste(village_plain, adm2_ocha, YEAR) %in% paste(cost_years$survey_village, cost_years$adm2_ocha, cost_years$year))
coverage <- sv_year |> group_by(year = YEAR) |> summarise(households = n(), villages = n_distinct(paste(village_plain, adm2_ocha)),
                                                          in_cost_village_any_year = sum(has_cost_village), in_cost_village_same_year = sum(cost_same_year), .groups = "drop") |>
  mutate(pct_same_year = round(100 * in_cost_village_same_year / households, 1))

# Surveyed villages of a department with community costs that match no cost village, with the nearest cost name:
# the other half of the review list.
cost_dept_ocha <- xw[xw$key %in% unique(cost_villages$dept_key) & !is.na(xw$adm2_ocha), c("key", "adm2_ocha")]
unmatched_sv <- survey_villages |> filter(adm2_ocha %in% cost_dept_ocha$adm2_ocha, !paste(village_plain, adm2_ocha) %in% paste(matched$survey_village, matched$adm2_ocha))
unmatched_sv$nearest_cost_village <- NA_character_; unmatched_sv$distance <- NA_real_
for (i in seq_len(nrow(unmatched_sv))) {
  keys <- cost_dept_ocha$key[cost_dept_ocha$adm2_ocha == unmatched_sv$adm2_ocha[i]]
  pool <- unique(cost_villages$village[cost_villages$dept_key %in% keys])
  if (!length(pool)) next
  d <- stringdist(unmatched_sv$village_plain[i], pool, method = "jw", p = 0.1)
  unmatched_sv$nearest_cost_village[i] <- pool[which.min(d)]; unmatched_sv$distance[i] <- round(min(d), 3)
}
unmatched_sv <- arrange(unmatched_sv, distance)

# ---- Ledger: where every franc of the template goes -------------------------------------------------------------
# Each village share of each block lands in exactly one destination, and the ledger must add up to the template.
sv_years <- sv |> distinct(village_plain, adm2_ocha, YEAR)
dest <- split |> left_join(distinct(vm, department, cost_village, survey_village, adm2_ocha, match), by = c("department", "village" = "cost_village"), relationship = "many-to-many")
# A cost village with several surveyed spellings counts once: keep its first match row for the destination.
dest <- dest |> group_by(kind, period, first_row, village) |> mutate(surveyed_that_year = any(paste(survey_village, adm2_ocha, year) %in% paste(sv_years$village_plain, sv_years$adm2_ocha, sv_years$YEAR))) |>
  slice(1) |> ungroup()
dest$destination <- case_when(dest$village == "(no village)" ~ "4 No village named (kept at department level)",
                              dest$match %in% "No surveyed department" ~ "5 Department not surveyed",
                              !is.na(dest$survey_village) & dest$surveyed_that_year ~ "1 Surveyed village, same year (reaches households)",
                              !is.na(dest$survey_village) ~ "2 Surveyed village, other years only",
                              TRUE ~ "3 Village not surveyed")
ledger <- dest |> group_by(period, destination) |> summarise(transfer_xaf = sum(amount_xaf[kind == "transfer"]), capacity_xaf = sum(amount_xaf[kind == "capacity"]),
                                                             village_shares = n(), .groups = "drop") |> arrange(period, destination)
for (k in c("transfer", "capacity")) {
  if (abs(sum(ledger[[paste0(k, "_xaf")]]) - sum(cl[[paste0(k, "_xaf")]], na.rm = TRUE)) > 1) stop("The ledger loses ", k, " costs.", call. = FALSE)
}
ledger_all <- ledger |> group_by(destination) |> summarise(transfer_xaf = sum(transfer_xaf), capacity_xaf = sum(capacity_xaf), .groups = "drop") |>
  mutate(pct_of_total = round(100 * (transfer_xaf + capacity_xaf) / sum(transfer_xaf + capacity_xaf), 1))

# ---- Template against the revised workbook ---------------------------------------------------------------------
compare <- recon
if (file.exists(REVISED)) {
  rv <- as.data.frame(read_csv(REVISED, show_col_types = FALSE))
  compare$revised_cash_xaf <- rv$reconciled_total_xaf[match(compare$period, rv$period)]
  compare$transfer_minus_revised_xaf <- compare$transfer_xaf - compare$revised_cash_xaf
}

write_csv(select(cl, -village_list, -block_partner), file.path(OUT, "community_cost_lines.csv"), na = "")
write_csv(blocks, file.path(OUT, "community_cost_blocks.csv"), na = "")
write_csv(village_costs, file.path(OUT, "community_village_costs.csv"), na = "")
write_csv(village_category, file.path(OUT, "community_village_costs_by_asset.csv"), na = "")
write_csv(ledger, file.path(OUT, "community_cost_ledger.csv"), na = "")
write_csv(vm, file.path(OUT, "community_village_match.csv"), na = "")
# "Not surveyed" is reviewed from the other side (community_survey_villages_unmatched.csv).
write_csv(filter(vm, match %in% c("Surveyed name + suffix", "Close name", "Same name, other department")) |> arrange(department, cost_village, distance),
          file.path(OUT, "community_village_match_to_review.csv"), na = "")
write_csv(coverage, file.path(OUT, "community_survey_coverage.csv"), na = "")
write_csv(select(unmatched_sv, ADMIN1Name, ADMIN2Name, adm2_ocha, survey_village = village_plain, survey_name, households, years, nearest_cost_village, distance),
          file.path(OUT, "community_survey_villages_unmatched.csv"), na = "")
write_csv(compare, file.path(OUT, "community_vs_revised.csv"), na = "")

fmt <- function(v) format(round(v), big.mark = ",", scientific = FALSE, trim = TRUE)
cat("\nTemplate totals by period, XAF\n")
print(transform(compare, transfer_xaf = fmt(transfer_xaf), capacity_xaf = fmt(capacity_xaf),
                revised_cash_xaf = if (!is.null(compare$revised_cash_xaf)) fmt(revised_cash_xaf) else NA,
                transfer_minus_revised_xaf = if (!is.null(compare$transfer_minus_revised_xaf)) fmt(transfer_minus_revised_xaf) else NA), row.names = FALSE)
cat(sprintf("\nBlocks: %d transfer, %d capacity; %d shared by several villages; %d with no village (%s XAF kept at department level)\n",
            sum(blocks$kind == "transfer"), sum(blocks$kind == "capacity"), sum(blocks$n_villages > 1), sum(blocks$n_villages == 0),
            fmt(sum(blocks$amount_xaf[blocks$n_villages == 0]))))
eq <- cl |> group_by(period, sub_office, partner) |> summarise(rows_with_both = sum(!is.na(transfer_xaf) & !is.na(capacity_xaf)),
                                                               rows_equal = sum(capacity_equals_transfer), capacity_xaf = sum(capacity_xaf, na.rm = TRUE), .groups = "drop") |>
  filter(rows_equal > 0)
write_csv(eq, file.path(OUT, "community_capacity_equals_transfer.csv"), na = "")
cat(sprintf("Capacity cost equal to the transfer cost: %d rows in %d partner blocks, %s XAF of capacity cost\n",
            sum(cl$capacity_equals_transfer), nrow(eq), fmt(sum(cl$capacity_xaf[cl$capacity_equals_transfer]))))
print(as.data.frame(eq |> mutate(capacity_xaf = fmt(capacity_xaf))), row.names = FALSE)
cat("\nLedger: where the template's costs go, XAF (all periods)\n")
print(as.data.frame(ledger_all |> mutate(transfer_xaf = fmt(transfer_xaf), capacity_xaf = fmt(capacity_xaf))), row.names = FALSE, right = FALSE)
cat("\nCommunity costs by asset type, XAF (all periods)\n")
print(as.data.frame(village_category |> group_by(category) |> summarise(transfer = sum(transfer_xaf), capacity = sum(capacity_xaf)) |>
                      arrange(desc(transfer + capacity)) |> mutate(transfer = fmt(transfer), capacity = fmt(capacity))), row.names = FALSE, right = FALSE)
cat(sprintf("\nCost villages: %d (department x village)\n", nrow(vm)))
print(as.data.frame(count(vm, match, name = "villages")), row.names = FALSE)
cat("\nSurveyed households in a village with community costs\n"); print(as.data.frame(coverage), row.names = FALSE)
cat(sprintf("Surveyed villages in a cost department with no cost village: %d (%d households); %d have a cost name within 0.15\n",
            nrow(unmatched_sv), sum(unmatched_sv$households), sum(unmatched_sv$distance <= 0.15, na.rm = TRUE)))
cat("Output:", OUT, "\n")
