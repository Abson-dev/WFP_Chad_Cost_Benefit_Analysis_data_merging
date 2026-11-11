/*
Corrects the high-severity defects of the coping (LCS) and asset benefit (ABI) answers, after do-file 22:
  - 2023 Annual: the coping answers were not recoded, so "no need" counted as coping;
  - 2018 Baseline and 2020 PDM: raw coping code 0 was recoded to Yes;
  - LhCSIStress1 was set to Not applicable for every household in 9 rounds;
  - 2022 Annual: every ABI answer was 0, so the ABI score was 0 for every household.

The corrected answers come from merge/23_WFP_Chad_fix_coping_ABI.R, which reads them again from the raw files
(see its header for the reading of each round's codes and the two assumptions to confirm). Rmds 05 and 07 still
hold the defects: run this do-file after them and do-files 12 to 22.

Only these values may change; the script stops otherwise. The scores are recomputed with the rules of do-file 12
(coping) and Rmd 07 (ABI). The input file is read, not changed. The output is a new file, saved without replace.
*/

clear all
version 16

global modules "C:\Users\AHema\OneDrive - CGIAR\Desktop\WFP Resilience dataset\data\output_data\Chad"
global data "C:\Users\AHema\OneDrive - CGIAR\Desktop\2024\WFP\CBA - Chad\data"
global old_merged "WFP_Chad_2018-2023_20261111_v8.dta"
global new_merged "WFP_Chad_2018-2023_20261111_v9.dta"

local lcs LhCSIStress1 LhCSIStress2 LhCSIStress3 LhCSIStress4 LhCSICrisis1 LhCSICrisis2 LhCSICrisis3 LhCSIEmergency1 LhCSIEmergency2 LhCSIEmergency3
local abi ABIProteger ABIProduction ABIdifficultes ABIMarches ABIGererActifs ABIEnvironnement ABIutiliseractifs
local hh  HHAssetProtect HHAssetProduct HHAssetDecHardship HHAssetAccess HHTrainingAsset HHAssetEnv HHWorkAsset

use "$modules\WFP_Chad_fix_coping_ABI.dta", clear
isid ID
tempfile fix
save `fix'

use "$data\\$old_merged", clear
local n_merged = _N
local k_merged = c(k)
isid ID
merge 1:1 ID using `fix'
assert _merge == 3
drop _merge

* ---- Coping (LCS) ---------------------------------------------------------------------------------
* Changes allowed: every item in 2018 Baseline (1), 2020 PDM (3) and 2023 Annual (10); LhCSIStress1 in any round.
foreach v of local lcs {
	assert !missing(`v'_fix)
	gen byte _chg = (`v' != `v'_fix)
	if "`v'" != "LhCSIStress1" assert _chg == 0 if !inlist(ROUND, 1, 3, 10)
	quietly count if _chg
	display "`v': " r(N) " answers corrected"
	replace `v' = `v'_fix
	drop _chg `v'_fix
}

* Same rules as do-file 12.
foreach s in stress crisis emergency Max {
	local old_`s' = cond("`s'" == "Max", "Max_coping_behaviourFS", "`s'_coping_FS")
	clonevar _old_`s' = `old_`s''
}
replace stress_coping_FS = (LhCSIStress1==2 | LhCSIStress1==3) | (LhCSIStress2==2 | LhCSIStress2==3) | (LhCSIStress3==2 | LhCSIStress3==3) | (LhCSIStress4==2 | LhCSIStress4==3)
replace crisis_coping_FS = (LhCSICrisis1==2 | LhCSICrisis1==3) | (LhCSICrisis2==2 | LhCSICrisis2==3) | (LhCSICrisis3==2 | LhCSICrisis3==3)
replace emergency_coping_FS = (LhCSIEmergency1==2 | LhCSIEmergency1==3) | (LhCSIEmergency2==2 | LhCSIEmergency2==3) | (LhCSIEmergency3==2 | LhCSIEmergency3==3)
egen _nonmiss = rownonmiss(`lcs')
replace Max_coping_behaviourFS = cond(_nonmiss > 0, 1, .)
replace Max_coping_behaviourFS = 2 if stress_coping_FS == 1
replace Max_coping_behaviourFS = 3 if crisis_coping_FS == 1
replace Max_coping_behaviourFS = 4 if emergency_coping_FS == 1
drop _nonmiss
* The 2019 Annual keeps its answers, so its scores must not move.
foreach s in stress crisis emergency Max {
	assert `old_`s'' == _old_`s' if ROUND == 2
	drop _old_`s'
}
display _n "Maximum coping category by round, corrected"
tab ROUND Max_coping_behaviourFS, row nofreq

* ---- Asset benefit (ABI), 2022 Annual only ------------------------------------------------------------
foreach v in `abi' ABITensions {
	assert missing(`v'_fix) if ROUND != 8
	assert `v' == 0 | missing(`v') if ROUND == 8
	assert missing(`v') == missing(`v'_fix) if ROUND == 8
	replace `v' = `v'_fix if ROUND == 8
	drop `v'_fix
}
* The HHAsset copies used by the score, as in Rmd 07 (888 and 999 count as 0; none in this round).
local i = 0
foreach h of local hh {
	local ++i
	local a : word `i' of `abi'
	replace `h' = `a' if ROUND == 8
}
egen _nonmiss = rownonmiss(`abi')
egen _score = rowtotal(`hh')
replace ABIScore = cond(_nonmiss > 0, _score, .) if ROUND == 8
drop _nonmiss _score
assert inrange(ABIScore, 0, 7) | missing(ABIScore)
display _n "ABI score by round, corrected"
tabstat ABIScore, by(ROUND) stat(mean n) format(%5.2f)

assert _N == `n_merged'
assert c(k) == `k_merged'
isid ID

notes: Coping answers of 2018 Baseline, 2020 PDM and 2023 Annual, LhCSIStress1 in 9 rounds, and the 2022 Annual ABI answers corrected from the raw files by 23_WFP_Chad_fix_coping_ABI.R and .do.
save "$data\\$new_merged"
