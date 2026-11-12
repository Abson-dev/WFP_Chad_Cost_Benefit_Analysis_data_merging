# Build demo_data/: a copy of data/ with invented estimates, for screenshots and demonstrations.
# From the app/ folder:   Rscript make_demo_data.R
# Then run the app with the environment variable WFP_CBA_DEMO=1: a banner says the data are synthetic.
# Structure (rounds, variables, checks) is metadata and stays; only figures about households change.

if (!dir.exists("data")) stop("Run prepare_app_data.R first.", call. = FALSE)
set.seed(20260105)
if (dir.exists("demo_data")) unlink("demo_data", recursive = TRUE)
dir.create("demo_data")
file.copy(list.files("data", full.names = TRUE), "demo_data", overwrite = TRUE)

read <- function(f) as.data.frame(readr::read_csv(file.path("demo_data", f), show_col_types = FALSE))
write <- function(x, f) readr::write_csv(x, file.path("demo_data", f), na = "")
jitter_pct <- function(v, sd = 6) { o <- v + stats::rnorm(length(v), 0, sd); ifelse(is.na(v), NA, pmin(pmax(o, 0), 100)) }
jitter_rel <- function(v, sd = .12) { o <- v * (1 + stats::rnorm(length(v), 0, sd)); ifelse(is.na(v), NA, pmax(o, 0)) }

scramble_indicators <- function(x) {
  est <- grep("_m$", names(x), value = TRUE)
  for (m in est) {
    co <- sub("_m$", "_c", m)
    is_share <- !grepl("mean|hh_size", m)
    new <- if (is_share) jitter_pct(x[[m]]) else jitter_rel(x[[m]])
    same <- !is.na(x[[m]]) & !is.na(x[[co]]) & abs(x[[m]] - x[[co]]) < 1e-9
    new_c <- if (is_share) jitter_pct(x[[co]]) else jitter_rel(x[[co]])
    x[[co]] <- round(ifelse(same, new, new_c), 2)
    x[[m]] <- round(new, 2)
  }
  x
}
write(scramble_indicators(read("indicators_by_round.csv")), "indicators_by_round.csv")
write(scramble_indicators(read("indicators_by_round_region.csv")), "indicators_by_round_region.csv")

a <- read("assistance_by_round.csv")
a$yes_pct <- round(jitter_pct(a$yes_pct, 8), 1)
a$yes <- round(a$answered * a$yes_pct / 100); a$yes[is.na(a$yes)] <- 0
a$dont_know <- round(a$answered * .04); a$no <- a$answered - a$yes - a$dont_know
write(a, "assistance_by_round.csv")
ar <- read("assistance_by_region.csv"); ar$yes_pct <- round(jitter_pct(ar$yes_pct, 10), 1); write(ar, "assistance_by_region.csv")

l <- read("lcs_items.csv")
for (k in c("merged_yes", "corrected_yes")) l[[k]] <- round(jitter_pct(l[[k]], 3), 1)
write(l, "lcs_items.csv")
rc <- read("rcsi_comparison.csv")
for (k in c("merged", "corrected", "analysts")) rc[[k]] <- round(jitter_rel(rc[[k]]), 2)
write(rc, "rcsi_comparison.csv")
ch <- read("ch_phase_by_round.csv"); ch$households <- round(jitter_rel(ch$households, .25)); write(ch, "ch_phase_by_round.csv")

for (f in c("cost_by_category.csv", "cost_by_area.csv", "cost_by_partner.csv")) { x <- read(f); x$cash_xaf <- round(jitter_rel(x$cash_xaf, .25)); write(x, f) }
x <- read("cost_survey_link.csv"); for (k in c("cost_xaf", "cost_activity_xaf", "cost_lump_sum_xaf")) x[[k]] <- round(jitter_rel(x[[k]], .25)); write(x, "cost_survey_link.csv")
x <- read("cost_reconciliation.csv"); for (k in c("stated_total_xaf", "reconciled_total_xaf", "difference_xaf")) x[[k]] <- round(jitter_rel(x[[k]], .25)); write(x, "cost_reconciliation.csv")

# Original against merged: the same invented factor on both sides of a variable, so its status still reads true.
ov <- read("original_vs_merged_variables.csv")
f <- 1 + stats::rnorm(nrow(ov), 0, .15)
for (k in c("raw_mean", "merged_mean", "raw_median", "merged_median")) ov[[k]] <- round(ov[[k]] * f, 3)
for (k in c("raw_rows_answered", "raw_answered", "merged_answered", "compared", "same_value")) ov[[k]] <- round(ov[[k]] * f)
write(ov, "original_vs_merged_variables.csv")
oc <- read("original_vs_merged_categories.csv")
for (k in c("households", "raw_code_total", "merged_code_total")) oc[[k]] <- round(jitter_rel(oc[[k]], .25))
oc$pct_of_raw_code <- round(100 * oc$households / oc$raw_code_total, 1)
write(oc, "original_vs_merged_categories.csv")
oi <- read("original_vs_merged_indicators.csv")
f <- 1 + stats::rnorm(nrow(oi), 0, .12)
for (k in c("raw_value", "merged_value", "difference")) oi[[k]] <- round(oi[[k]] * f, 3)
oi$note <- ifelse(oi$note == "Same.", oi$note, "Illustration: note hidden in the synthetic version.")
write(oi, "original_vs_merged_indicators.csv")

# Text with figures: replaced, so that no real estimate leaves in a screenshot.
ck <- read("checks.csv")
ck$detail <- ifelse(ck$status == "pass", ck$detail, "Illustration: detail hidden in the synthetic version.")
ck$observed <- ifelse(ck$status == "pass", ck$observed, "(synthetic)")
write(ck, "checks.csv")
cat("demo_data/ built. Run the app with WFP_CBA_DEMO=1.\n")
