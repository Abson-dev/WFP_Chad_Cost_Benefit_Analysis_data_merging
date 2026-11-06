/*
Adds five more modules to the merged dataset, after do-file 19:
  WFP_Chad_ShockImpact.dta     harmonization/28_WFP_Chad_ShockImpact_data.Rmd
  WFP_Chad_Effects.dta         harmonization/29_WFP_Chad_Effects_data.Rmd
  WFP_Chad_Markets.dta         harmonization/30_WFP_Chad_Markets_data.Rmd
  WFP_Chad_Accountability.dta  harmonization/31_WFP_Chad_Accountability_data.Rmd
  WFP_Chad_Additions.dta       harmonization/32_WFP_Chad_Additions_data.Rmd

Same rules as do-files 16 to 19: the first occurrence of each duplicated ID (2021 PDM) is kept, and the
refused interview dropped by do-file 12 is left out. The input file is read, not changed. The output
is a new file, saved without replace.
*/

clear all
version 16

global modules "C:\Users\AHema\OneDrive - CGIAR\Desktop\WFP Resilience dataset\data\output_data\Chad"
global data "C:\Users\AHema\OneDrive - CGIAR\Desktop\2024\WFP\CBA - Chad\data"
global old_merged "WFP_Chad_2018-2023_20261106_v4.dta"
global new_merged "WFP_Chad_2018-2023_20261106_v5.dta"
local modules ShockImpact Effects Markets Accountability Additions

use "$data\\$old_merged", clear
local n_merged = _N
local k_merged = c(k)
isid ID
unab merged_vars : _all

foreach m of local modules {
	use "$modules\WFP_Chad_`m'.dta", clear
	assert !missing(ID)
	unab vars : _all
	local new : list vars - merged_vars
	local clash : list vars & merged_vars
	assert "`clash'" == "ID"
	local k_`m' : word count `new'

	* First occurrence of each ID, in file order
	gen long _row = _n
	bysort ID (_row): gen byte _first = (_n == 1)
	count if !_first
	display "`m': " r(N) " repeated rows dropped"
	keep if _first
	drop _row _first
	isid ID
	tempfile mod_`m'
	save `mod_`m''
}

use "$data\\$old_merged", clear
foreach m of local modules {
	merge 1:1 ID using `mod_`m''
	assert _merge != 1
	count if _merge == 2
	assert r(N) == 1
	drop if _merge == 2
	drop _merge
}

assert _N == `n_merged'
assert c(k) == `k_merged' + `k_ShockImpact' + `k_Effects' + `k_Markets' + `k_Accountability' + `k_Additions'
isid ID

foreach v in ShkRecNow_Drought EffChanged_Income MktSoldProduce AapSatisfied FsnNotEnoughFood30d {
	display _n "`v': households answering, by round"
	tab ROUND if !missing(`v')
}

notes: Shock impact and recovery, changes credited to the programme, markets, more accountability questions and additions to earlier modules, from harmonization/28 to 32. See 20_WFP_Chad_add_recovery_effects_markets.do.
save "$data\\$new_merged"
