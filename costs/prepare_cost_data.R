# Build a clean table from WFP's resilience cost workbook. From the repository's root:
#   Rscript costs/prepare_cost_data.R
#
# Reads "Cost related data_ Resilience 2019-2023 revised.xlsx", read-only, and writes to a new folder
# next to it, outside this repository. Rules from WFP's note (Regis):
#   - 2020 has two sheets: January to March (activities created) and April to December (lump sums, COVID-19).
#     They stay separate periods, and lump sums are not split across activities.
#   - All costs are in XAF.
# The composition file's values per person are not converted or labelled XAF: their size (10.9 to 31.75
# per person per month) does not fit, and the currency is to be confirmed with WFP.
#
# Subtotal rows are left out, including Farchana's, which have no label. The script stops if the lines
# do not reconcile with the workbook's own subtotals and totals.

suppressPackageStartupMessages({ library(readxl); library(dplyr); library(readr) })
BASE <- Sys.getenv("WFP_MERGED_DIR", "C:/Users/AHema/OneDrive - CGIAR/Desktop/2024/WFP/CBA - Chad/data")
SRC <- file.path(BASE, "cost data", "Cost related data_ Resilience 2019-2023 revised.xlsx")
OUT <- file.path(BASE, "cost data clean")
dir.create(OUT, showWarnings = FALSE)

PERIODS <- list(
  "2019" = list(year = 2019, period = "2019", basis = "Activity"),
  "janv-mars 2020" = list(year = 2020, period = "2020 Jan-Mar", basis = "Activity"),
  "avril-Decembre 2020" = list(year = 2020, period = "2020 Apr-Dec", basis = "Partner lump sum (COVID-19)"),
  "2021" = list(year = 2021, period = "2021", basis = "Activity"),
  "2022" = list(year = 2022, period = "2022", basis = "Activity"),
  "2023" = list(year = 2023, period = "2023", basis = "Activity")
)
fill_down <- function(v) { for (i in seq_along(v)[-1]) if (is.na(v[i])) v[i] <- v[i - 1]; v }
num <- function(v) suppressWarnings(as.numeric(v))
sheets <- excel_sheets(SRC)
if (!setequal(trimws(sheets), names(PERIODS))) stop("Unexpected sheets: ", paste(sheets, collapse = ", "), call. = FALSE)

lines <- list(); recon <- list()
for (s in sheets) {
  p <- PERIODS[[trimws(s)]]
  x <- as.data.frame(suppressMessages(read_excel(SRC, s, col_names = FALSE, col_types = "text")))
  h <- which(apply(x, 1, function(r) any(r %in% "Sub office")))[1]
  names(x) <- make.names(trimws(as.character(unlist(x[h, ]))), unique = TRUE)
  b <- x[(h + 1):nrow(x), , drop = FALSE]
  if (!"Menage" %in% names(b)) b$Menage <- NA_character_
  b$source_row <- seq_len(nrow(b)) + h   # position among the rows read, for checking against the sheet
  b$cash <- num(b$Cash)
  is_total <- !is.na(b$Sub.office) & grepl("^total", b$Sub.office, ignore.case = TRUE)
  is_general <- is_total & grepl("general", b$Sub.office, ignore.case = TRUE)
  # A row with an amount but no activity is an unlabelled subtotal only if it equals the lines above it
  # (Farchana). Otherwise it is a real amount, such as a lump sum with no activity text (Guereda).
  # Every labelled subtotal is also checked against its lines.
  unlabelled <- rep(FALSE, nrow(b)); acc <- 0
  for (i in seq_len(nrow(b))) {
    if (is_general[i]) next
    if (is_total[i]) {
      if (abs(b$cash[i] - acc) > 1) stop(sprintf("%s row %d: subtotal %.0f, lines %.0f", s, b$source_row[i], b$cash[i], acc), call. = FALSE)
      acc <- 0
    } else if (!is.na(b$cash[i]) && is.na(b$Actif[i]) && acc > 0 && abs(b$cash[i] - acc) <= 1) {
      unlabelled[i] <- TRUE; acc <- 0
    } else if (!is.na(b$cash[i])) acc <- acc + b$cash[i]
  }
  sub <- ifelse(is_total, NA, b$Sub.office)
  # Fill places within each sub-office block only, so that a total row does not carry over.
  b$sub_office <- fill_down(sub); b$province <- fill_down(ifelse(is_total, NA, b$Province)); b$department <- fill_down(ifelse(is_total, NA, b$Departement))
  b$partner <- fill_down(ifelse(is_total, NA, b$CP))
  keep <- !is_total & !unlabelled & (!is.na(b$Actif) | !is.na(b$cash))
  lines_s <- b[keep, ]
  lines[[s]] <- data.frame(
    year = p$year, period = p$period, cost_basis = p$basis, sub_office = trimws(lines_s$sub_office), province = trimws(lines_s$province), department = trimws(lines_s$department),
    partner = trimws(lines_s$partner), activity = trimws(gsub("\\s+", " ", lines_s$Actif)), unit = trimws(lines_s$Unit.mea), outcome = num(lines_s$Outcome),
    cash_xaf = lines_s$cash, households = num(lines_s$Menage), source_sheet = trimws(s), stringsAsFactors = FALSE)
  stated <- b$cash[is_general][1]; sum_lines <- sum(lines_s$cash, na.rm = TRUE)
  recon[[s]] <- data.frame(period = p$period, cost_basis = p$basis, lines = nrow(lines_s), lines_with_amount = sum(!is.na(lines_s$cash)), stated_total_xaf = stated, reconciled_total_xaf = sum_lines, difference_xaf = sum_lines - stated, unlabelled_subtotals = sum(unlabelled))
}
costs <- bind_rows(lines) |> mutate(order = match(period, vapply(PERIODS, `[[`, "", "period"))) |> arrange(order) |> select(-order)
recon <- bind_rows(recon) |> mutate(order = match(period, vapply(PERIODS, `[[`, "", "period"))) |> arrange(order) |> select(-order)
recon <- bind_rows(recon, data.frame(period = "All", cost_basis = "", lines = sum(recon$lines), lines_with_amount = sum(recon$lines_with_amount), stated_total_xaf = sum(recon$stated_total_xaf), reconciled_total_xaf = sum(recon$reconciled_total_xaf), difference_xaf = sum(recon$difference_xaf), unlabelled_subtotals = sum(recon$unlabelled_subtotals)))

# Expected: only 2019 differs, by Farchana's subtotal, which its TOTAL GENERAL formula leaves out.
d <- recon[recon$period != "All", ]
if (any(abs(d$difference_xaf[d$period != "2019"]) > 1)) stop("A period other than 2019 does not reconcile.", call. = FALSE)
if (abs(d$difference_xaf[d$period == "2019"] - 211503517) > 1) stop("The 2019 difference has changed: check the workbook.", call. = FALSE)
# Rule: April-December 2020 stays at partner level.
lump <- costs[costs$period == "2020 Apr-Dec", ]
per_partner <- lump |> group_by(sub_office, partner) |> summarise(amounts = sum(!is.na(cash_xaf)), rows = n(), .groups = "drop")
if (any(per_partner$amounts > 1)) stop("A lump-sum partner has several amounts: review it.", call. = FALSE)
if (anyNA(costs$sub_office) || anyNA(costs$partner)) stop("Lines without a sub-office or partner.", call. = FALSE)

# ---- Department crosswalk --------------------------------------------------------------------------
xw <- as.data.frame(read_csv("costs/department_crosswalk.csv", show_col_types = FALSE))
unmapped <- setdiff(costs$department, xw$cost_department)
if (length(unmapped)) stop("Cost departments missing from the crosswalk: ", paste(unmapped, collapse = ", "), call. = FALSE)
areas <- xw[!duplicated(xw$cost_department), c("cost_department", "cost_area", "region", "link_type")]
costs <- left_join(costs, areas, by = c("department" = "cost_department"))
costs$partner <- toupper(costs$partner)

# ---- Activity categories: first matching rule wins ----------------------------------------------------
rules <- as.data.frame(read_csv("costs/activity_categories.csv", show_col_types = FALSE))
rules <- rules[order(rules$order), ]
plain <- function(v) tolower(chartr("àâäéèêëîïôöùûüçœ’'", "aaaeeeeiioouuuco''", tolower(v)))
categorise <- function(text) {
  t <- plain(text); out <- rep(NA_character_, length(t)); type <- rep(NA_character_, length(t))
  for (i in seq_len(nrow(rules))) {
    hit <- is.na(out) & !is.na(t) & grepl(rules$pattern[i], t, perl = TRUE)
    out[hit] <- rules$category[i]; type[hit] <- rules$assistance_type[i]
  }
  list(category = ifelse(is.na(out), "Other or unclear", out), assistance_type = ifelse(is.na(type), "Other assets", type))
}
ct <- categorise(costs$activity)
costs$category <- ct$category; costs$assistance_type <- ct$assistance_type
# Lump sums: WFP's amount sits on a partner's first row, so it says nothing about that row's activity.
# The category describes what was done; the money is reported apart.
LUMP_LABEL <- "Partner lump sum (COVID-19), not allocated"
costs$amount_category <- ifelse(costs$period == "2020 Apr-Dec", LUMP_LABEL, costs$category)

by_category <- costs |> filter(!is.na(cash_xaf)) |> group_by(period, amount_category, assistance_type) |>
  summarise(cash_xaf = sum(cash_xaf), lines = n(), .groups = "drop") |> mutate(assistance_type = ifelse(amount_category == LUMP_LABEL, "Not allocated", assistance_type)) |>
  group_by(period, amount_category, assistance_type) |> summarise(cash_xaf = sum(cash_xaf), lines = sum(lines), .groups = "drop")
by_area <- costs |> filter(!is.na(cash_xaf)) |> group_by(cost_area, region, link_type, year, period, cost_basis) |> summarise(cash_xaf = sum(cash_xaf), lines = n(), partners = n_distinct(partner), .groups = "drop")
by_partner <- costs |> filter(!is.na(cash_xaf)) |> group_by(partner, year, period) |> summarise(cash_xaf = sum(cash_xaf), lines = n(), .groups = "drop")
activities_lump <- costs |> filter(period == "2020 Apr-Dec") |> group_by(category) |> summarise(activity_rows = n(), .groups = "drop")

# Every franc must land in each table.
total <- sum(costs$cash_xaf, na.rm = TRUE)
for (t in list(by_category, by_area, by_partner)) if (abs(sum(t$cash_xaf) - total) > 1) stop("A cost table does not add up to the total.", call. = FALSE)

# ---- Link to the surveys: cost area x year -------------------------------------------------------------
sv <- haven::zap_labels(haven::read_dta(file.path(BASE, "WFP_Chad_2018-2023_20261105_v2.dta"), col_select = c(YEAR, SURVEY, ADMIN1Name, ADMIN2Name, adm2_ocha, ArgentContreTravail)))
sv <- as.data.frame(sv); sv$adm2_ocha[is.na(sv$adm2_ocha)] <- ""
mapped <- xw[!is.na(xw$adm2_ocha), c("adm2_ocha", "cost_area")]
sv$cost_area <- mapped$cost_area[match(sv$adm2_ocha, mapped$adm2_ocha)]
sv$no_cost_area <- is.na(sv$cost_area)
sv$cost_area <- ifelse(sv$no_cost_area, ifelse(sv$ADMIN2Name == "" | is.na(sv$ADMIN2Name), paste0(sv$ADMIN1Name, " (no department)"), sv$ADMIN2Name), sv$cost_area)
survey_side <- sv |> filter(YEAR >= 2019) |> group_by(cost_area, year = YEAR) |> summarise(
  region_survey = ADMIN1Name[1], not_in_cost_data = no_cost_area[1], households_surveyed = n(), households_pdm = sum(SURVEY == "PDM"), households_annual = sum(SURVEY != "PDM"),
  answered_cash_for_assets = sum(!is.na(ArgentContreTravail)), yes_cash_for_assets = sum(ArgentContreTravail == 1, na.rm = TRUE), .groups = "drop")
cost_side <- costs |> filter(!is.na(cash_xaf)) |> group_by(cost_area, region, link_type, year) |> summarise(
  cost_xaf = sum(cash_xaf), cost_activity_xaf = sum(cash_xaf[cost_basis == "Activity"]), cost_lump_sum_xaf = sum(cash_xaf[cost_basis != "Activity"]), .groups = "drop")
link <- full_join(cost_side, survey_side, by = c("cost_area", "year")) |>
  mutate(region = ifelse(is.na(region), region_survey, region),
         link_type = ifelse(is.na(link_type), ifelse(not_in_cost_data %in% TRUE, "No cost data", areas$link_type[match(cost_area, areas$cost_area)]), link_type),
         status = case_when(!is.na(cost_xaf) & !is.na(households_surveyed) ~ "Cost and survey", !is.na(cost_xaf) ~ "Cost only", TRUE ~ "Survey only"),
         pct_cash_for_assets = ifelse(answered_cash_for_assets >= 30, round(100 * yes_cash_for_assets / answered_cash_for_assets, 1), NA)) |>
  select(cost_area, region, link_type, year, status, cost_xaf, cost_activity_xaf, cost_lump_sum_xaf, households_surveyed, households_pdm, households_annual, pct_cash_for_assets) |>
  arrange(region, cost_area, year)
if (abs(sum(link$cost_xaf, na.rm = TRUE) - total) > 1) stop("The survey link loses money.", call. = FALSE)
if (sum(link$households_surveyed, na.rm = TRUE) != sum(sv$YEAR >= 2019)) stop("The survey link loses households.", call. = FALSE)
survey_only <- sort(setdiff(unique(sv$ADMIN2Name[sv$no_cost_area & sv$ADMIN2Name != ""]), ""))

# ---- Composition of the assistance packages: values per person per month are in USD ----------------------
comp_file <- file.path(BASE, "cost data", "Composition de packet d'assistance integrated resilience.xlsx")
cx <- as.data.frame(suppressMessages(read_excel(comp_file, 1, col_names = FALSE, col_types = "text")))
names(cx)[1:3] <- c("a", "b", "c")
starts <- which(cx$b %in% "g/pers/d")
composition <- bind_rows(lapply(seq_along(starts), function(k) {
  from <- starts[k] + 1; to <- if (k < length(starts)) starts[k + 1] - 1 else nrow(cx)
  r <- cx[from:to, ]; r <- r[!is.na(r$a), ]
  value <- num(r$c[!is.na(r$c)][1])
  target <- ifelse(grepl("PLW", r$a), "Pregnant and lactating women", ifelse(grepl("Nut CH", r$a), "Children", NA))
  target_k <- if (any(!is.na(target))) target[!is.na(target)][1] else "All beneficiaries"
  items <- r[!grepl("^Nut ", r$a), ]
  data.frame(programme = cx$a[starts[k]], target = target_k, commodity = trimws(items$a), grams_per_person_day = num(items$b), value_usd_per_person_month = value, stringsAsFactors = FALSE)
}))
if (anyNA(composition$value_usd_per_person_month) || !all(composition$value_usd_per_person_month > 5 & composition$value_usd_per_person_month < 50)) stop("Composition values are not the expected USD amounts.", call. = FALSE)

write_csv(select(costs, -amount_category), file.path(OUT, "cost_lines.csv"), na = "")
write_csv(recon, file.path(OUT, "cost_reconciliation.csv"), na = "")
write_csv(by_category, file.path(OUT, "cost_by_category.csv"), na = "")
write_csv(by_area, file.path(OUT, "cost_by_area.csv"), na = "")
write_csv(by_partner, file.path(OUT, "cost_by_partner.csv"), na = "")
write_csv(activities_lump, file.path(OUT, "cost_lump_sum_activities.csv"), na = "")
write_csv(link, file.path(OUT, "cost_survey_link.csv"), na = "")
write_csv(xw, file.path(OUT, "cost_department_crosswalk.csv"), na = "")
write_csv(composition, file.path(OUT, "composition_usd.csv"), na = "")
unlink(file.path(OUT, "cost_by_period_province.csv"))

cat("\nActivity amounts by category, XAF (lump sums apart)\n")
print(as.data.frame(by_category |> group_by(amount_category) |> summarise(xaf = format(round(sum(cash_xaf)), big.mark = ","), lines = sum(lines)) |> arrange(desc(lines))), row.names = FALSE, right = FALSE)
o <- costs |> filter(category == "Other or unclear")
cat(sprintf("\nOther or unclear: %d lines, %s XAF on activity basis\n", nrow(o), format(round(sum(o$cash_xaf[o$cost_basis == "Activity"], na.rm = TRUE)), big.mark = ",")))
if (Sys.getenv("WFP_COST_AUDIT") == "1") {
  cat(paste0("  ? ", substr(o$activity, 1, 100)), sep = "\n")
  for (g in unique(costs$category)) { k <- costs[costs$category == g & costs$cost_basis == "Activity", ]; k <- k[order(-k$cash_xaf), ]; cat("\n##", g, "\n"); cat(paste0("  ", format(round(k$cash_xaf[1:min(12, nrow(k))] / 1e6, 1)), "  ", substr(k$activity[1:min(12, nrow(k))], 1, 95)), sep = "\n") }
}
cat("\nSurvey link by status\n"); print(as.data.frame(link |> group_by(status) |> summarise(area_years = n(), xaf = format(round(sum(cost_xaf, na.rm = TRUE)), big.mark = ","), households = sum(households_surveyed, na.rm = TRUE))), row.names = FALSE, right = FALSE)
cat("Surveyed departments with no cost data:", paste(survey_only, collapse = ", "), "\n")

fmt <- function(v) format(round(v), big.mark = ",", scientific = FALSE, trim = TRUE)
out <- transform(recon, stated_total_xaf = fmt(stated_total_xaf), reconciled_total_xaf = fmt(reconciled_total_xaf), difference_xaf = fmt(difference_xaf))
print(out[, c("period", "cost_basis", "lines", "lines_with_amount", "stated_total_xaf", "reconciled_total_xaf", "difference_xaf", "unlabelled_subtotals")], row.names = FALSE)
cat(sprintf("\nApr-Dec 2020: %d partner blocks, %d with an amount, %d activity rows without an amount (not allocated).\n", nrow(per_partner), sum(per_partner$amounts == 1), sum(is.na(lump$cash_xaf))))
cat("Blocks without an amount:", paste(paste(per_partner$sub_office[per_partner$amounts == 0], per_partner$partner[per_partner$amounts == 0], sep = "/"), collapse = ", "), "\n")
cat("Output:", OUT, "\n")
