/*
Uses the analysts' Food Consumption Score for the 2020 PDM (round 3) in the merged dataset,
without rerunning the whole pipeline.

Why: in this round the eight main food groups hold 0/1 flags, not days, so the FCS built from them
cannot exceed 16 and every household is Poor. The day counts cannot be rebuilt from the raw file.
The raw file does hold the analysts' SCA for all 271 households, and do-file 12 keeps it.

What changes, in round 3 only:
  FCS                  takes the value of SCA
  FCSCat21, FCSCat28   recomputed from it with the thresholds of do-file 12
  FCSStap, FCSPulse, FCSDairy, FCSPr, FCSVeg, FCSFruit, FCSFat, FCSSugar   set to missing: they are not days

The sub-items (FCSPrMeatF, FCSVegGre, ...) and FCSCond do hold days, and stay. The input file is kept.
Do-file 12 now applies the same rule, so this file is not needed after a full rerun.
*/

clear all
version 16

global data "C:\Users\AHema\OneDrive - CGIAR\Desktop\2024\WFP\CBA - Chad\data"
global old_merged "WFP_Chad_2018-2023_20261105.dta"
global new_merged "WFP_Chad_2018-2023_20261105_v2.dta"
local main_groups FCSStap FCSPulse FCSDairy FCSPr FCSVeg FCSFruit FCSFat FCSSugar

use "$data\\$old_merged", clear
local n_before = _N
local k_before = c(k)

* The defect is as described, and the replacement is complete.
assert _N > 0
count if ROUND == 3
assert r(N) == 271
assert !missing(SCA) if ROUND == 3
foreach v of local main_groups {
	assert inlist(`v', 0, 1) if ROUND == 3
}

replace FCS = SCA if ROUND == 3
foreach v of local main_groups {
	replace `v' = . if ROUND == 3
}
* Same thresholds as do-file 12.
replace FCSCat21 = cond(FCS <= 21, 1, cond(FCS <= 35, 2, 3)) if ROUND == 3
replace FCSCat28 = cond(FCS <= 28, 1, cond(FCS <= 42, 2, 3)) if ROUND == 3

assert _N == `n_before'
assert c(k) == `k_before'
isid ID
tab ROUND, summarize(FCS) means
tab ROUND FCSCat28

notes FCS: Round 3 uses the analysts' SCA, because its main food groups hold 0/1 flags. See 15_WFP_Chad_fix_FCS_2020PDM.do.
save "$data\\$new_merged"
