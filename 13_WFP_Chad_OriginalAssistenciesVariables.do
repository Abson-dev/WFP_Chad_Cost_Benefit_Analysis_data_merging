clear all
global input_data "C:\Users\AHema\OneDrive - CGIAR\Desktop\WFP Resilience dataset\data\output_data\Chad"
global output_data "C:\Users\AHema\OneDrive - CGIAR\Desktop\2024\WFP\CBA - Chad\data"

// 2018
use "$input_data\Chad_baseline_2018_assistance_originalVars.dta",clear
tostring ID, replace
duplicates drop ID, force
gen ROUND = 1
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
gen ROUND = 2
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
gen ROUND = 3
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
gen ROUND = 4
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
gen ROUND = 5
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
gen ROUND = 6
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
gen ROUND = 7
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
gen ROUND = 8
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
gen ROUND = 9
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
gen ROUND = 10
tab1 BanqueCerealiere10 - AutreTransferts10
tab1 BanqueCerealiere10 - AutreTransferts10,nolab
drop BanqueCerealiere1 - AutreTransferts9
//append  using "$output_data\WFP_Chad_assistance_originalVars.dta", force
//save "$output_data\WFP_Chad_assistance_originalVars.dta",replace
merge 1:1 ID using "$output_data\WFP_Chad_assistance_originalVars.dta"
tab _m
drop _m
save "$output_data\WFP_Chad_assistance_originalVars.dta",replace

tab ROUND


tab1 BanqueCerealiere - AutreTransferts if YEAR == 2023 & SURVEY == "Enquête annuelle" // ROUND 10 (Non  => Non, Ne Sait Pas => Ne Sait Pas)
tab1 BanqueCerealiere10 - AutreTransferts10
tab1 BanqueCerealiere - AutreTransferts if YEAR == 2023 & SURVEY == "PDM" // ROUND 9 (Non  => Non, Ne Sait Pas => Ne Sait Pas)
tab1 BanqueCerealiere9 - AutreTransferts9
tab1 BanqueCerealiere - AutreTransferts if YEAR == 2022 & SURVEY == "Enquête annuelle"  // ROUND 8 (Non => Ne Sait Pas, Ne Sait Pas  => Non)
tab1 BanqueCerealiere8 - AutreTransferts8


sort YEAR SURVEY
order ID SvyDatePDM YEAR SURVEY ROUND ADMIN0Name adm0_ocha ADMIN1Name adm1_ocha ADMIN2Name adm2_ocha village Longitude Latitude Longitude_precision Latitude_precision IP_var exercise_year exercise_code exercise_code exercise_label 



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

label var ROUND		"Survey ROUND"

// Confused by coding of two modalities in PDM 2020
tab BanqueCerealiere3 BanqueCerealiere if ROUND==3, missing nolab
tab CashTransfert3 CashTransfert if ROUND==3, missing

tab CashTransfert10 CashTransfert if ROUND==10, missing

// More confusing with coding of ROUND 6
forvalues i=6(1)6{
	foreach v in BanqueCerealiere VivreContreTravail ArgentContreTravail DistribVivresSoudure DistribArgentSoudure BoursesAdo BlanketFeedingChildren BlanketFeedingWomen MAMChildren MASChildren MAMPLWomen FARNcommunaut FormationRenfCapacite CashTransfert CantineScolaire AutreTransferts { 
	tab `v'`i' `v' if ROUND==`i', m
	
}
}
forvalues i=10(1)10{
	foreach v in BanqueCerealiere VivreContreTravail ArgentContreTravail DistribVivresSoudure DistribArgentSoudure BoursesAdo BlanketFeedingChildren BlanketFeedingWomen MAMChildren MASChildren MAMPLWomen FARNcommunaut FormationRenfCapacite CashTransfert CantineScolaire AutreTransferts { 
	tab `v'`i' `v' if ROUND==`i', m
	
}
}

forvalues i=9(1)9{
	foreach v in BanqueCerealiere VivreContreTravail ArgentContreTravail DistribVivresSoudure DistribArgentSoudure BoursesAdo BlanketFeedingChildren BlanketFeedingWomen MAMChildren MASChildren MAMPLWomen FARNcommunaut FormationRenfCapacite CashTransfert CantineScolaire AutreTransferts { 
	tab `v'`i' `v' if ROUND==`i', m
	
}
}

// Additional lines


*** REORDERING, RENAMING AND RELABELING OF VARIABLES
// so that variables that belong to the same module are placed together
order ID-exercise_label adm0_name-TransfBenef
move Montant DateDerniereAssist
lab var Montant "Estimated amount from primary income source"

rename SvyDatePDM SvyDate

//rename round ROUND

move month_survey SURVEY
rename month_survey SvyMonth
lab var SvyMonth "Interview Month (imputed to link with IPC)" 

label var HDDS_hema "Household Dietary Diversity Score"

lab var SCA "Food Consumption Score (incorrect)"
lab var FCS "Food Consumption Score (correct)"

move rCSI SCA


des BanqueCerealiere-AutreTransferts
label define assistance 1 "Oui" 2 "Oui Autre" 3 "Non" 4 "Ne Sait Pas", replace
label values BanqueCerealiere-AutreTransferts assistance
des BanqueCerealiere-AutreTransferts


*** based on info from WFP-Chad (Regis)
// VivreContreTravail was discontinued but the name FFA remained while payments were done in cash (Regis suggested to recode those obs)
replace ArgentContreTravail=1 if VivreContreTravail==1
recode VivreContreTravail (1=3)

// MASChildren, CashTransfert, AutreTransferts seem to be provided by other organizations; Regis suggested to get rid of those 
tab1 MASChildren CashTransfert AutreTransferts, m 
recode MASChildren CashTransfert AutreTransferts (1=2) // these "oui" recoded as "oui autre"


*** non-needed additions for now
drop RCSAnticipatory-RCSSAdaptiveCat33 


save "$output_data\WFP_Chad_2018-2023_20250318.dta",replace

use "$output_data\WFP_Chad_2018-2023_20250318.dta",clear
// Confused by coding of two modalities in PDM 2020
tab BanqueCerealiere3 BanqueCerealiere if ROUND==3, missing nolab
tab CashTransfert3 CashTransfert if ROUND==3, missing

tab CashTransfert10 CashTransfert if ROUND==10, missing

forvalues i=3(1)3{
	foreach v in BanqueCerealiere VivreContreTravail ArgentContreTravail DistribVivresSoudure DistribArgentSoudure BoursesAdo BlanketFeedingChildren BlanketFeedingWomen MAMChildren MASChildren MAMPLWomen FARNcommunaut FormationRenfCapacite CashTransfert CantineScolaire AutreTransferts { 
	tab `v'`i' `v' if ROUND==`i', m
	
}
}

//
forvalues i=4(1)4{
	foreach v in BanqueCerealiere VivreContreTravail ArgentContreTravail DistribVivresSoudure DistribArgentSoudure BoursesAdo BlanketFeedingChildren BlanketFeedingWomen MAMChildren MASChildren MAMPLWomen FARNcommunaut FormationRenfCapacite CashTransfert CantineScolaire AutreTransferts { 
	tab `v'`i' `v' if ROUND==`i', m
	
}
}

//
forvalues i=5(1)5{
	foreach v in BanqueCerealiere VivreContreTravail ArgentContreTravail DistribVivresSoudure DistribArgentSoudure BoursesAdo BlanketFeedingChildren BlanketFeedingWomen MAMChildren MASChildren MAMPLWomen FARNcommunaut FormationRenfCapacite CashTransfert CantineScolaire AutreTransferts { 
	tab `v'`i' `v' if ROUND==`i', m
	
}
}

//
forvalues i=6(1)6{
	foreach v in BanqueCerealiere VivreContreTravail ArgentContreTravail DistribVivresSoudure DistribArgentSoudure BoursesAdo BlanketFeedingChildren BlanketFeedingWomen MAMChildren MASChildren MAMPLWomen FARNcommunaut FormationRenfCapacite CashTransfert CantineScolaire AutreTransferts { 
	tab `v'`i' `v' if ROUND==`i', m
	
}

}

//Non et NSP, PDM 2022
forvalues i=7(1)7{
	foreach v in BanqueCerealiere VivreContreTravail ArgentContreTravail DistribVivresSoudure DistribArgentSoudure BoursesAdo BlanketFeedingChildren BlanketFeedingWomen MAMChildren MASChildren MAMPLWomen FARNcommunaut FormationRenfCapacite CashTransfert CantineScolaire AutreTransferts { 
	tab `v'`i' `v' if ROUND==`i', m
	
}
}

//Non et NSP,EA 2022
forvalues i=8(1)8{
	foreach v in BanqueCerealiere VivreContreTravail ArgentContreTravail DistribVivresSoudure DistribArgentSoudure BoursesAdo BlanketFeedingChildren BlanketFeedingWomen MAMChildren MASChildren MAMPLWomen FARNcommunaut FormationRenfCapacite CashTransfert CantineScolaire AutreTransferts { 
	tab `v'`i' `v' if ROUND==`i', m
	
}
}


forvalues i=9(1)9{
	foreach v in BanqueCerealiere VivreContreTravail ArgentContreTravail DistribVivresSoudure DistribArgentSoudure BoursesAdo BlanketFeedingChildren BlanketFeedingWomen MAMChildren MASChildren MAMPLWomen FARNcommunaut FormationRenfCapacite CashTransfert CantineScolaire AutreTransferts { 
	tab `v'`i' `v' if ROUND==`i', m
	
}
}




forvalues i=10(1)10{
	foreach v in BanqueCerealiere VivreContreTravail ArgentContreTravail DistribVivresSoudure DistribArgentSoudure BoursesAdo BlanketFeedingChildren BlanketFeedingWomen MAMChildren MASChildren MAMPLWomen FARNcommunaut FormationRenfCapacite CashTransfert CantineScolaire AutreTransferts { 
	tab `v'`i' `v' if ROUND==`i', m
	
}
}


/*

*/