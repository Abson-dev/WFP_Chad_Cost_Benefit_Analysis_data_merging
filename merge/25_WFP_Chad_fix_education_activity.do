/*
Restores the education and main activity answers of the head of household that the harmonisation lost (issue
"Education, main activity and income source answers lost in the harmonisation"), after do-file 24:
  - HHHEdu: "Supérieur" in the 2018 Baseline to the 2022 Annual; "Aucun", "1er cycle fondamentale" and "2e cycle
    fondamentale" in the 2023 PDM and 2023 Annual. The value label 5 "Superieur" gets its accent back.
  - HHHMainActivity: the 2019 Annual, 2020 Annual and 2021 PDM answers, where the 11-category list maps to a single
    category of the 14.
  - HHSourceIncome, 2019 Annual: the 115 "Vente des produits maraîchers" answers (code 3), lost to a trailing space.
  - HHHMainActivityGroup (new): the main activity in 9 groups, comparable across the four rounds that ask it.

The answers come from merge/25_WFP_Chad_fix_education_activity.R (see its header for the crosswalks). Only missing
values may be filled in: every answer the merged file already has must be rebuilt identically, or the do-file stops.
The input file is read, not changed. The output is a new file, saved without replace.
*/

clear all
version 16

global modules "C:\Users\AHema\OneDrive - CGIAR\Desktop\WFP Resilience dataset\data\output_data\Chad"
global data "C:\Users\AHema\OneDrive - CGIAR\Desktop\2024\WFP\CBA - Chad\data"
global old_merged "WFP_Chad_2018-2023_20261116_v10.dta"
global new_merged "WFP_Chad_2018-2023_20261116_v11.dta"

use "$modules\WFP_Chad_fix_education_activity.dta", clear
isid ID
tempfile fix
save `fix'

use "$data\\$old_merged", clear
local n_merged = _N
local k_merged = c(k)
isid ID
capture confirm variable HHHMainActivityGroup, exact
assert _rc != 0
merge 1:1 ID using `fix'
assert _merge == 3
drop _merge

* HHSourceIncome is rebuilt for the 2019 Annual only.
assert missing(HHSourceIncome_fix) if ROUND != 2
foreach v in HHHEdu HHHMainActivity HHSourceIncome {
	* Existing answers are rebuilt identically; only missing ones are filled in.
	if "`v'" == "HHSourceIncome" assert `v' == `v'_fix if !missing(`v') & ROUND == 2
	else assert `v' == `v'_fix if !missing(`v')
	quietly count if missing(`v') & !missing(`v'_fix)
	display "`v': " r(N) " lost answers restored"
	tab ROUND if missing(`v') & !missing(`v'_fix)
	replace `v' = `v'_fix if missing(`v')
	drop `v'_fix
}
local lab : value label HHHEdu
label define `lab' 5 "Supérieur", modify

assert inrange(HHHEdu, 1, 5) | missing(HHHEdu)
assert inrange(HHHMainActivity, 1, 14) | missing(HHHMainActivity)
assert inrange(HHSourceIncome, 1, 15) | missing(HHSourceIncome)
assert inrange(HHHMainActivityGroup, 1, 9) | missing(HHHMainActivityGroup)
assert missing(HHHMainActivityGroup) if !inlist(ROUND, 1, 2, 4, 5)
order HHHMainActivityGroup, after(HHHMainActivity)

assert _N == `n_merged'
assert c(k) == `k_merged' + 1
isid ID
tab ROUND HHHEdu, missing
tab ROUND HHHMainActivityGroup, missing

notes: Education, main activity and 2019 income source answers lost in the harmonisation restored, and HHHMainActivityGroup added, from the raw files by 25_WFP_Chad_fix_education_activity.R and .do.
save "$data\\$new_merged"
