/*
Adds the 29 workbook variables that were dropped before the merge (issue "Workbook variables dropped before the merge"),
after do-file 23: the respondent's age, sex, relationship to the head and consent, 7 savings and 11 social capital
questions, 3 migration questions, the asset benefit participant's sex and the assets created, and the analysts' food
expenditure share, and the date assistance started.

They are built from the raw files by merge/24_WFP_Chad_add_dropped_variables.R, which puts them on the merged file's
scales (see its header). This do-file only adds them: every household must match, none of the 29 may exist already,
and no other value of the file changes. The input file is read, not changed. The output is a new file, saved without
replace.
*/

clear all
version 16

global modules "C:\Users\AHema\OneDrive - CGIAR\Desktop\WFP Resilience dataset\data\output_data\Chad"
global data "C:\Users\AHema\OneDrive - CGIAR\Desktop\2024\WFP\CBA - Chad\data"
global old_merged "WFP_Chad_2018-2023_20261111_v9.dta"
global new_merged "WFP_Chad_2018-2023_20261116_v10.dta"

use "$modules\WFP_Chad_dropped_variables.dta", clear
isid ID
ds ID, not
local added `r(varlist)'
local n_added : word count `added'
assert `n_added' == 29
tempfile add
save `add'

use "$data\\$old_merged", clear
local n_merged = _N
local k_merged = c(k)
isid ID
foreach v of local added {
	capture confirm variable `v', exact
	assert _rc != 0
}
merge 1:1 ID using `add'
assert _merge == 3
drop _merge

assert _N == `n_merged'
assert c(k) == `k_merged' + 29
isid ID

* The recoded scales.
assert inlist(RESPSex, 1, 2, .)
assert inlist(ABISexparticipant, 1, 2, .)
assert inlist(RESPConsent, 0, 1, .)
assert inrange(ExpFoodShareAnalysts, 0, 100) | missing(ExpFoodShareAnalysts)
format DebutAssistance %td
tab ROUND RESPSex, missing
tab ROUND RESPConsent, missing

notes: 29 workbook variables dropped before the merge added from the raw files by 24_WFP_Chad_add_dropped_variables.R and .do.
save "$data\\$new_merged"
