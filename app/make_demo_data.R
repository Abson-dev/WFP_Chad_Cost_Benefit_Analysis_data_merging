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

# Text with figures: replaced, so that no real estimate leaves in a screenshot.
ck <- read("checks.csv")
ck$detail <- ifelse(ck$status == "pass", ck$detail, "Illustration: detail hidden in the synthetic version.")
ck$observed <- ifelse(ck$status == "pass", ck$observed, "(synthetic)")
write(ck, "checks.csv")
cat("demo_data/ built. Run the app with WFP_CBA_DEMO=1.\n")
