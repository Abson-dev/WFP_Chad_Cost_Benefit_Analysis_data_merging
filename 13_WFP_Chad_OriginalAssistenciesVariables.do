clear all
global input_data "C:\Users\AHema\OneDrive - CGIAR\Desktop\WFP Resilience dataset\data\output_data\Chad"
global output_data "C:\Users\AHema\OneDrive - CGIAR\Desktop\2024\WFP\CBA - Chad\data"

// 2018
use "$input_data\Chad_baseline_2018_assistance_originalVars.dta",clear
tostring ID, replace
duplicates drop ID, force
gen round = 1
tab1 BanqueCerealiere1 - AutreTransferts1
drop BanqueCerealiere2 - AutreTransferts10
merge 1:1 ID using "$output_data\WFP_Chad_2018-2023_20250314.dta"
tab _m
drop _m
save "$output_data\WFP_Chad_assistance_originalVars.dta",replace

//2019
use "$input_data\Chad_ea_2019_assistance_originalVars.dta",clear
tostring ID, replace
duplicates drop ID, force
gen round = 2
tab1 BanqueCerealiere2 - AutreTransferts2
tab1 BanqueCerealiere2 - AutreTransferts2,nolab
drop BanqueCerealiere1 - AutreTransferts1
drop BanqueCerealiere3 - AutreTransferts10

//append  using "$output_data\WFP_Chad_assistance_originalVars.dta", force
//save "$output_data\WFP_Chad_assistance_originalVars.dta",replace
merge 1:1 ID using "$output_data\WFP_Chad_assistance_originalVars.dta"
tab _m
drop _m
save "$output_data\WFP_Chad_assistance_originalVars.dta",replace

// PDM 2020
use "$input_data\Chad_pdm_2020_assistance_originalVars.dta",clear
tostring ID, replace
duplicates drop ID, force
gen round = 3
tab1 BanqueCerealiere3 - AutreTransferts3
tab1 BanqueCerealiere3 - AutreTransferts3,nolab
drop BanqueCerealiere1 - AutreTransferts2
drop BanqueCerealiere4 - AutreTransferts10
//append  using "$output_data\WFP_Chad_assistance_originalVars.dta", force
//save "$output_data\WFP_Chad_assistance_originalVars.dta",replace
merge 1:1 ID using "$output_data\WFP_Chad_assistance_originalVars.dta"
tab _m
drop _m
save "$output_data\WFP_Chad_assistance_originalVars.dta",replace


// EA 2020
use "$input_data\Chad_ea_2020_assistance_originalVars.dta",clear
tostring ID, replace
duplicates drop ID, force
gen round = 4
tab1 BanqueCerealiere4 - AutreTransferts4
tab1 BanqueCerealiere4 - AutreTransferts4,nolab
drop BanqueCerealiere1 - AutreTransferts3
drop BanqueCerealiere5 - AutreTransferts10
//append  using "$output_data\WFP_Chad_assistance_originalVars.dta", force
//save "$output_data\WFP_Chad_assistance_originalVars.dta",replace
merge 1:1 ID using "$output_data\WFP_Chad_assistance_originalVars.dta"
tab _m
drop _m
save "$output_data\WFP_Chad_assistance_originalVars.dta",replace

// PDM 2021
use "$input_data\Chad_pdm_2021_assistance_originalVars.dta",clear
duplicates drop ID, force
gen round = 5
tab1 BanqueCerealiere5 - AutreTransferts5
tab1 BanqueCerealiere5 - AutreTransferts5,nolab
drop BanqueCerealiere1 - AutreTransferts4
drop BanqueCerealiere6 - AutreTransferts10
//append  using "$output_data\WFP_Chad_assistance_originalVars.dta", force
//save "$output_data\WFP_Chad_assistance_originalVars.dta",replace
merge 1:1 ID using "$output_data\WFP_Chad_assistance_originalVars.dta"
tab _m
drop _m
save "$output_data\WFP_Chad_assistance_originalVars.dta",replace

// EA 2021
use "$input_data\Chad_ea_2021_assistance_originalVars.dta",clear
duplicates drop ID, force
tostring ID, replace
gen round = 6
tab1 BanqueCerealiere6 - AutreTransferts6
tab1 BanqueCerealiere6 - AutreTransferts6,nolab
drop BanqueCerealiere1 - AutreTransferts5
drop BanqueCerealiere7 - AutreTransferts10
//append  using "$output_data\WFP_Chad_assistance_originalVars.dta", force
//save "$output_data\WFP_Chad_assistance_originalVars.dta",replace
merge 1:1 ID using "$output_data\WFP_Chad_assistance_originalVars.dta"
tab _m
drop _m
save "$output_data\WFP_Chad_assistance_originalVars.dta",replace


// PDM 2022
use "$input_data\Chad_pdm_2022_assistance_originalVars.dta",clear
drop ID
gen ID = _n
tostring ID, replace
duplicates drop ID, force
gen round = 7
tab1 BanqueCerealiere7 - AutreTransferts7
tab1 BanqueCerealiere7 - AutreTransferts7,nolab
drop BanqueCerealiere1 - AutreTransferts6
drop BanqueCerealiere8 - AutreTransferts10
//append  using "$output_data\WFP_Chad_assistance_originalVars.dta", force
//save "$output_data\WFP_Chad_assistance_originalVars.dta",replace
merge 1:1 ID using "$output_data\WFP_Chad_assistance_originalVars.dta"
tab _m
drop _m
save "$output_data\WFP_Chad_assistance_originalVars.dta",replace



// EA 2022
use "$input_data\Chad_ea_2022_assistance_originalVars.dta",clear
tostring ID, replace
duplicates drop ID, force
gen round = 8
tab1 BanqueCerealiere8 - AutreTransferts8
tab1 BanqueCerealiere8 - AutreTransferts8,nolab
drop BanqueCerealiere1 - AutreTransferts7
drop BanqueCerealiere9 - AutreTransferts10
//append  using "$output_data\WFP_Chad_assistance_originalVars.dta", force
//save "$output_data\WFP_Chad_assistance_originalVars.dta",replace
merge 1:1 ID using "$output_data\WFP_Chad_assistance_originalVars.dta"
tab _m
drop _m
save "$output_data\WFP_Chad_assistance_originalVars.dta",replace

// PDM 2023
use "$input_data\Chad_pdm_2023_assistance_originalVars.dta",clear
tostring ID, replace
duplicates drop ID, force
gen round = 9
tab1 BanqueCerealiere9 - AutreTransferts9
tab1 BanqueCerealiere9 - AutreTransferts9,nolab
drop BanqueCerealiere1 - AutreTransferts8
drop BanqueCerealiere10 - AutreTransferts10
//append  using "$output_data\WFP_Chad_assistance_originalVars.dta", force
//save "$output_data\WFP_Chad_assistance_originalVars.dta",replace
merge 1:1 ID using "$output_data\WFP_Chad_assistance_originalVars.dta"
tab _m
drop _m
drop if ID == "41057035"
save "$output_data\WFP_Chad_assistance_originalVars.dta",replace

// EA 2023
use "$input_data\Chad_ea_2023_assistance_originalVars.dta",clear
tostring ID, replace
duplicates drop ID, force
gen round = 10
tab1 BanqueCerealiere10 - AutreTransferts10
tab1 BanqueCerealiere10 - AutreTransferts10,nolab
drop BanqueCerealiere1 - AutreTransferts9
//append  using "$output_data\WFP_Chad_assistance_originalVars.dta", force
//save "$output_data\WFP_Chad_assistance_originalVars.dta",replace
merge 1:1 ID using "$output_data\WFP_Chad_assistance_originalVars.dta"
tab _m
drop _m
save "$output_data\WFP_Chad_assistance_originalVars.dta",replace

tab round


tab1 BanqueCerealiere - AutreTransferts if YEAR == 2023 & SURVEY == "Enquête annuelle" // round 10 (Non  => Non, Ne Sait Pas => Ne Sait Pas)
tab1 BanqueCerealiere10 - AutreTransferts10
tab1 BanqueCerealiere - AutreTransferts if YEAR == 2023 & SURVEY == "PDM" // round 9 (Non  => Non, Ne Sait Pas => Ne Sait Pas)
tab1 BanqueCerealiere9 - AutreTransferts9
tab1 BanqueCerealiere - AutreTransferts if YEAR == 2022 & SURVEY == "Enquête annuelle"  // round 8 (Non => Ne Sait Pas, Ne Sait Pas  => Non)
tab1 BanqueCerealiere8 - AutreTransferts8


sort YEAR SURVEY
order ID SvyDatePDM YEAR SURVEY round ADMIN0Name adm0_ocha ADMIN1Name adm1_ocha ADMIN2Name adm2_ocha village Longitude Latitude Longitude_precision Latitude_precision IP_var exercise_year exercise_code exercise_code exercise_label 



tab1 BanqueCerealiere - AutreTransferts if YEAR == 2023 & SURVEY == "Enquête annuelle" 
tab1 BanqueCerealiere10 - AutreTransferts10
tab1 BanqueCerealiere - AutreTransferts if YEAR == 2023 & SURVEY == "PDM" 
tab1 BanqueCerealiere9 - AutreTransferts9
tab1 BanqueCerealiere - AutreTransferts if YEAR == 2022 & SURVEY == "Enquête annuelle"
tab1 BanqueCerealiere8 - AutreTransferts8  
tab1 BanqueCerealiere - AutreTransferts if YEAR == 2022 & SURVEY == "PDM"
tab1 BanqueCerealiere7 - AutreTransferts7  
tab1 BanqueCerealiere - AutreTransferts if YEAR == 2021 & SURVEY == "Enquête annuelle"  //so
tab1 BanqueCerealiere6 - AutreTransferts6
tab1 BanqueCerealiere - AutreTransferts if YEAR == 2021 & SURVEY == "PDM"
tab1 BanqueCerealiere5 - AutreTransferts5   
tab1 BanqueCerealiere - AutreTransferts if YEAR == 2020 & SURVEY == "Enquête annuelle" 
tab1 BanqueCerealiere4 - AutreTransferts4
tab1 BanqueCerealiere - AutreTransferts if YEAR == 2020 & SURVEY == "PDM"  //soucis
tab1 BanqueCerealiere3 - AutreTransferts3 
tab1 BanqueCerealiere - AutreTransferts if YEAR == 2019 & SURVEY == "Enquête annuelle" 
tab1 BanqueCerealiere2 - AutreTransferts2

label var round		"Survey round"

// Confused by coding of two modalities in PDM 2020
tab BanqueCerealiere3 BanqueCerealiere if round==3, missing nolab
tab CashTransfert3 CashTransfert if round==3, missing

tab CashTransfert10 CashTransfert if round==10, missing

// More confusing with coding of round 6
forvalues i=6(1)6{
	foreach v in BanqueCerealiere VivreContreTravail ArgentContreTravail DistribVivresSoudure DistribArgentSoudure BoursesAdo BlanketFeedingChildren BlanketFeedingWomen MAMChildren MASChildren MAMPLWomen FARNcommunaut FormationRenfCapacite CashTransfert CantineScolaire AutreTransferts { 
	tab `v'`i' `v' if round==`i', m
	
}
}
forvalues i=10(1)10{
	foreach v in BanqueCerealiere VivreContreTravail ArgentContreTravail DistribVivresSoudure DistribArgentSoudure BoursesAdo BlanketFeedingChildren BlanketFeedingWomen MAMChildren MASChildren MAMPLWomen FARNcommunaut FormationRenfCapacite CashTransfert CantineScolaire AutreTransferts { 
	tab `v'`i' `v' if round==`i', m
	
}
}

forvalues i=9(1)9{
	foreach v in BanqueCerealiere VivreContreTravail ArgentContreTravail DistribVivresSoudure DistribArgentSoudure BoursesAdo BlanketFeedingChildren BlanketFeedingWomen MAMChildren MASChildren MAMPLWomen FARNcommunaut FormationRenfCapacite CashTransfert CantineScolaire AutreTransferts { 
	tab `v'`i' `v' if round==`i', m
	
}
}


save "$output_data\WFP_Chad_2018-2023_20250317.dta",replace