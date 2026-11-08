# Step 3: the cost of the household-level interventions each surveyed household reports. From the repository's root:
#   Rscript costs/prepare_household_costs.R
#
# Reads the merged survey file read-only, the unit costs (costs/household_unit_costs.csv, from IFPRI's household
# template filled with WFP) and the exchange rates (costs/exchange_rates.csv). Writes one row per household to
# "cost data clean/", outside this repository.
#
#   cost = units x amount x months, for each intervention the household answers "yes" to (code 1).
#
# Units (unit_rule):
#   household 1 | persons_6 6 (WFP's operational household size) | one_person, one_woman 1
#   children_6_23m  boys and girls aged 6-23 months, at least 1 when the household says yes
#   children_5_14   boys and girls aged 5-14, at least 1 (an upper bound for primary-school children)
#   child_and_woman at most one child aged 0-59 months plus at most one woman aged 15-49, at least 1
# Amounts stay in their currency (USD or XAF). XAF totals include USD amounts only for years with an exchange rate.
# Cash for assets is not costed here: its transfer and capacity costs come from the community template (step 4).
# Not costed, as agreed with WFP: CashTransfert, AutreTransferts (not WFP) and MASChildren (UNICEF).

suppressPackageStartupMessages({ library(dplyr); library(readr); library(haven) })
BASE <- Sys.getenv("WFP_MERGED_DIR", "C:/Users/AHema/OneDrive - CGIAR/Desktop/2024/WFP/CBA - Chad/data")
MERGED <- file.path(BASE, "WFP_Chad_2018-2023_20261106_v5.dta")
OUT <- file.path(BASE, "cost data clean")

uc <- as.data.frame(read_csv("costs/household_unit_costs.csv", show_col_types = FALSE, col_types = cols(year = "c", amount = "d", months = "d", .default = "c")))
fx <- as.data.frame(read_csv("costs/exchange_rates.csv", show_col_types = FALSE, col_types = cols(year = "i", xaf_per_usd = "d", source = "c")))
RULES <- c("household", "persons_6", "one_person", "one_woman", "children_6_23m", "children_5_14", "child_and_woman")
if (!all(uc$unit_rule %in% RULES)) stop("Unknown unit rule: ", paste(setdiff(uc$unit_rule, RULES), collapse = ", "), call. = FALSE)
if (!all(uc$currency %in% c("USD", "XAF"))) stop("Currency must be USD or XAF.", call. = FALSE)

comp <- c("HHSize05M", "HHSize05F", "HHSize23M", "HHSize23F", "HHSize59M", "HHSize59F", "HHSize5114M", "HHSize5114F", "HHSize1549F")
vars <- unique(uc$variable)
sv <- as.data.frame(zap_labels(read_dta(MERGED, col_select = all_of(c("ID", "YEAR", "SURVEY", comp, vars)))))
if (anyDuplicated(sv$ID)) stop("Household IDs are not unique.", call. = FALSE)
sv <- sv[sv$YEAR >= 2019, ]
n0 <- function(x) ifelse(is.na(x), 0, x)
units <- list(
  household = rep(1, nrow(sv)), persons_6 = rep(6, nrow(sv)), one_person = rep(1, nrow(sv)), one_woman = rep(1, nrow(sv)),
  children_6_23m = pmax(1, n0(sv$HHSize23M) + n0(sv$HHSize23F)),
  children_5_14 = pmax(1, n0(sv$HHSize5114M) + n0(sv$HHSize5114F)),
  child_and_woman = pmax(1, pmin(1, n0(sv$HHSize05M) + n0(sv$HHSize05F) + n0(sv$HHSize23M) + n0(sv$HHSize23F) + n0(sv$HHSize59M) + n0(sv$HHSize59F)) +
                           pmin(1, n0(sv$HHSize1549F))))

out <- sv[, c("ID", "YEAR", "SURVEY")]
out$cost_usd <- 0; out$cost_xaf_native <- 0; out$interventions_costed <- 0; out$interventions_not_costed <- 0
detail <- list()
for (k in unique(uc$cost_name)) {
  rows <- uc[uc$cost_name == k, ]
  v <- rows$variable[1]
  yes <- !is.na(sv[[v]]) & sv[[v]] == 1
  r <- rows[match(as.character(sv$YEAR), rows$year), ]
  r_all <- rows[rows$year == "all", ]
  if (nrow(r_all)) r[is.na(r$cost_name), ] <- r_all[rep(1, sum(is.na(r$cost_name))), ]
  cost <- ifelse(yes, units[[rows$unit_rule[1]]] * r$amount * r$months, 0)
  missing_rate <- yes & is.na(cost)
  out[[paste0("cost_", k)]] <- ifelse(yes, cost, ifelse(is.na(sv[[v]]), NA, 0))
  cur <- rows$currency[1]
  if (cur == "USD") out$cost_usd <- out$cost_usd + n0(cost) else out$cost_xaf_native <- out$cost_xaf_native + n0(cost)
  out$interventions_costed <- out$interventions_costed + (yes & !missing_rate)
  out$interventions_not_costed <- out$interventions_not_costed + missing_rate
  detail[[k]] <- data.frame(cost_name = k, variable = v, currency = cur, unit_rule = rows$unit_rule[1], status = paste(unique(rows$status), collapse = "; "),
                            households_yes = sum(yes), costed = sum(yes & !missing_rate), not_costed = sum(missing_rate),
                            total = sum(cost, na.rm = TRUE), mean_per_yes = if (sum(yes & !missing_rate)) mean(cost[yes & !missing_rate]) else NA)
}
rate <- fx$xaf_per_usd[match(out$YEAR, fx$year)]
out$cost_xaf <- ifelse(is.na(rate) & out$cost_usd > 0, NA, out$cost_xaf_native + n0(rate) * out$cost_usd)
detail <- bind_rows(detail)
by_round <- out |> group_by(YEAR, SURVEY) |> summarise(households = n(), with_cost = sum(interventions_costed > 0), mean_usd = round(mean(cost_usd), 1),
                                                     mean_usd_if_any = round(mean(cost_usd[interventions_costed > 0]), 1), mean_xaf_native = round(mean(cost_xaf_native)),
                                                     not_costed = sum(interventions_not_costed > 0), .groups = "drop")

write_csv(out, file.path(OUT, "household_intervention_costs.csv"), na = "")
write_csv(detail, file.path(OUT, "household_intervention_costs_by_item.csv"), na = "")
write_csv(by_round, file.path(OUT, "household_intervention_costs_by_round.csv"), na = "")

cat("\nBy intervention (all rounds 2019-2023)\n")
print(transform(detail, total = format(round(total), big.mark = ","), mean_per_yes = round(mean_per_yes, 1)), row.names = FALSE)
cat("\nBy round\n"); print(as.data.frame(by_round), row.names = FALSE)
cat(sprintf("\nExchange rates given for %d of 5 years: XAF totals %s.\n", sum(!is.na(fx$xaf_per_usd)),
            if (all(is.na(fx$xaf_per_usd))) "hold the XAF-priced items only (USD items need costs/exchange_rates.csv)" else "include the USD items for those years"))
cat("Output:", OUT, "\n")
