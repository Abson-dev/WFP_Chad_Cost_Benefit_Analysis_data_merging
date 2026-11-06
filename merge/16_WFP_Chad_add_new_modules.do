/*
Adds the modules harmonized in November 2026 to the merged dataset:
  WFP_Chad_Shocks.dta        harmonization/16_WFP_Chad_Shocks_data.Rmd
  WFP_Chad_Assets.dta        harmonization/17_WFP_Chad_Assets_data.Rmd
  WFP_Chad_Livelihoods.dta   harmonization/18_WFP_Chad_Livelihoods_data.Rmd
  WFP_Chad_Agriculture.dta   harmonization/19_WFP_Chad_Agriculture_data.Rmd

The modules hold every raw row. They are reduced to the households of the merged file the same way
as in do-file 12:
  - duplicated IDs (2021 PDM): the first occurrence in file order is kept, as do-file 12 does;
  - the refused interview dropped by do-file 12 has no match in the merged file and is left out.

The merged file is read, not changed. The output is a new file, saved without replace.
Nutrition (MAD, MDD-W) is not added: its link to households is broken in four rounds.
*/

clear all
version 16

global modules "C:\Users\AHema\OneDrive - CGIAR\Desktop\WFP Resilience dataset\data\output_data\Chad"
global data "C:\Users\AHema\OneDrive - CGIAR\Desktop\2024\WFP\CBA - Chad\data"
global old_merged "WFP_Chad_2018-2023_20261105_v2.dta"
global new_merged "WFP_Chad_2018-2023_20261106.dta"
local modules Shocks Assets Livelihoods Agriculture

* ---- Variables already in the merged file: a module must not hold any of them ----
use "$data\\$old_merged", clear
local n_merged = _N
local k_merged = c(k)
isid ID
unab merged_vars : _all

* ---- Each module: one row per household ID ----
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

* ---- Merge ----
use "$data\\$old_merged", clear
foreach m of local modules {
	merge 1:1 ID using `mod_`m''
	* Every household of the merged file is in the module
	assert _merge != 1
	* Only the refused interview is in the module and not in the merged file
	count if _merge == 2
	assert r(N) == 1
	drop if _merge == 2
	drop _merge
}

assert _N == `n_merged'
assert c(k) == `k_merged' + `k_Shocks' + `k_Assets' + `k_Livelihoods' + `k_Agriculture'
isid ID

* ---- Coverage by round ----
foreach v in Shk12m_Drought ShkAny6m AstRadio LvsTLU LivIncomeSource1 AgrPractice AgrMonthsOwnProduction {
	display _n "`v': households answering, by round"
	tab ROUND if !missing(`v')
}

notes: Shocks, assets and livestock, livelihoods and agriculture added from the modules of harmonization/16 to 19. See 16_WFP_Chad_add_new_modules.do.
save "$data\\$new_merged"
