/*
Corrects rCSIBorrow and rCSI in the merged dataset, without rerunning the whole pipeline.

Why: the workbook mapped rCSIBorrow to the rCSILessQlty column in three rounds (2022 PDM, 2023 PDM,
2023 Annual). The workbook is now corrected, and module_fixed comes from Rmd 06 run with it.
Only these two variables, in these three rounds, should change. The script stops otherwise.
The old merged file is kept. The formula is the one in do-file 12.

If you rerun Rmds 01 to 11 and do-files 12 and 13 with the corrected workbook, this file is not needed.
*/

clear all
version 16
args module_fixed

global data "C:\Users\AHema\OneDrive - CGIAR\Desktop\2024\WFP\CBA - Chad\data"
global old_merged "WFP_Chad_2018-2023_20250423.dta.dta"
global new_merged "WFP_Chad_2018-2023_20261105.dta"

if "`module_fixed'" == "" {
	display as error "Give the corrected rCSI module file as an argument."
	exit 198
}

use ID rCSIBorrow using "`module_fixed'", clear
tostring ID, replace
rename rCSIBorrow Borrow_fixed
* As do-file 12: the module still holds the 2021 PDM duplicates.
duplicates drop ID, force
isid ID
tempfile fixed
save `fixed'

use "$data\\$old_merged", clear
local n_before = _N
local k_before = c(k)

* Every household must find its corrected value.
merge 1:1 ID using `fixed', keep(master match) nogenerate
assert !missing(Borrow_fixed) if !missing(rCSIBorrow)

* Only the three rounds may change: 7 = 2022 PDM, 9 = 2023 PDM, 10 = 2023 Annual.
gen byte changed = (rCSIBorrow != Borrow_fixed)
assert changed == 0 if !inlist(ROUND, 7, 9, 10)
tab ROUND changed

replace rCSIBorrow = Borrow_fixed if inlist(ROUND, 7, 9, 10)
drop Borrow_fixed changed

* Same formula as do-file 12.
tempvar rcsi
gen double `rcsi' = (rCSILessQlty * 1) + (rCSIBorrow * 2) + (rCSIMealNb * 1) + (rCSIMealSize * 1) + (rCSIMealAdult * 3)
replace rCSI = `rcsi' if inlist(ROUND, 7, 9, 10)
drop `rcsi'

assert _N == `n_before'
assert c(k) == `k_before'
isid ID
tab ROUND, summarize(rCSI) means

notes rCSI: rCSIBorrow corrected in rounds 7, 9 and 10 by 14_WFP_Chad_fix_rCSIBorrow.do.
save "$data\\$new_merged"
