/*
Adds the cost module to the merged dataset, after do-file 20:
  WFP_Chad_Costs.dta   costs/prepare_household_cost_module.R (after costs/prepare_community_costs.R
                       and costs/prepare_household_costs.R; see costs/README.md)

The module is built from the merged file itself, so it has one row per household and no repeated or
refused interview. Every household must match. The input file is read, not changed. The output is a
new file, saved without replace.
*/

clear all
version 16

global modules "C:\Users\AHema\OneDrive - CGIAR\Desktop\WFP Resilience dataset\data\output_data\Chad"
global data "C:\Users\AHema\OneDrive - CGIAR\Desktop\2024\WFP\CBA - Chad\data"
global old_merged "WFP_Chad_2018-2023_20261106_v5.dta"
* v6 (8 November 2026) had the automatic village matches only; v7 adds the village decisions of 10 November 2026.
global new_merged "WFP_Chad_2018-2023_20261110_v7.dta"

use "$data\\$old_merged", clear
local n_merged = _N
local k_merged = c(k)
isid ID
unab merged_vars : _all

use "$modules\WFP_Chad_Costs.dta", clear
isid ID
assert _N == `n_merged'
unab vars : _all
local clash : list vars & merged_vars
assert "`clash'" == "ID"
local new : list vars - merged_vars
local k_costs : word count `new'
tempfile costs
save `costs'

use "$data\\$old_merged", clear
merge 1:1 ID using `costs'
assert _merge == 3
drop _merge

assert _N == `n_merged'
assert c(k) == `k_merged' + `k_costs'
isid ID

* No cost before the programme years; a source for every household from 2019 on.
assert missing(cost_comm_source) if YEAR == 2018
assert !missing(cost_comm_source) if YEAR >= 2019
assert cost_comm_transfer_xaf == 0 if cost_comm_source == 0
assert cost_comm_transfer_xaf >= 0 & cost_comm_capacity_xaf >= 0 & cost_interv_xaf >= 0 if !missing(cost_total_xaf)

display _n "Community cost source by round"
tab ROUND cost_comm_source, missing
display _n "Mean costs by round, XAF"
tabstat cost_comm_transfer_xaf cost_comm_capacity_xaf cost_interv_xaf cost_total_xaf, by(ROUND) stat(mean n) format(%12.0fc)

notes: Costs per household (community transfer and capacity costs, household-level interventions, total in XAF), from costs/prepare_household_cost_module.R. See 21_WFP_Chad_add_costs.do and costs/README.md.
save "$data\\$new_merged"
