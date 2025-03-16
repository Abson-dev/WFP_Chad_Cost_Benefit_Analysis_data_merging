global input_data "C:\Users\AHema\OneDrive - CGIAR\Desktop\WFP Resilience dataset\data\output_data\Chad"


use "C:\Users\AHema\OneDrive - CGIAR\Desktop\2024\WFP\CBA - Chad\data\WFP_Chad_2018-2023_20250314.dta", clear
tab1 BanqueCerealiere - AutreTransferts if YEAR == 2023 & SURVEY == "Enquête annuelle" // round 10 (Non  => Non, Ne Sait Pas => Ne Sait Pas)
tab1 BanqueCerealiere - AutreTransferts if YEAR == 2023 & SURVEY == "PDM" // round 9 (Non  => Non, Ne Sait Pas => Ne Sait Pas)
tab1 BanqueCerealiere - AutreTransferts if YEAR == 2022 & SURVEY == "Enquête annuelle"  // round 8 (Non => Ne Sait Pas, Ne Sait Pas  => Non)
tab1 BanqueCerealiere - AutreTransferts if YEAR == 2022 & SURVEY == "PDM"  // round 7 (Non => Ne Sait Pas, Ne Sait Pas  => Non)
tab1 BanqueCerealiere - AutreTransferts if YEAR == 2021 & SURVEY == "Enquête annuelle"  // round 6 (Non => Ne Sait Pas,"5" => Ne Sait Pas, "4" => Ne Sait Pas,Ne Sait Pas  => Non)
tab1 BanqueCerealiere - AutreTransferts if YEAR == 2021 & SURVEY == "PDM"   // round 5 (Non => Ne Sait Pas)
tab1 BanqueCerealiere - AutreTransferts if YEAR == 2020 & SURVEY == "Enquête annuelle"  // round 4 (Non => Ne Sait Pas)
tab1 BanqueCerealiere - AutreTransferts if YEAR == 2020 & SURVEY == "PDM"   // round 3 (Non => Ne Sait Pas)
tab1 BanqueCerealiere - AutreTransferts if YEAR == 2019 & SURVEY == "Enquête annuelle"  // round 2 (need to add CantineScolaire variable)


//2019
use "$input_data\Chad_ea_2019_assistance_originalVars.dta",clear
tab1 BanqueCerealiere2 - AutreTransferts2
tab1 BanqueCerealiere2 - AutreTransferts2,nolab

// PDM 2020
use "$input_data\Chad_pdm_2020_assistance_originalVars.dta",clear
tab1 BanqueCerealiere3 - AutreTransferts3
tab1 BanqueCerealiere3 - AutreTransferts3,nolab

// EA 2020
use "$input_data\Chad_ea_2020_assistance_originalVars.dta",clear
tab1 BanqueCerealiere4 - AutreTransferts4
tab1 BanqueCerealiere4 - AutreTransferts4,nolab

// PDM 2021
use "$input_data\Chad_pdm_2021_assistance_originalVars.dta",clear
tab1 BanqueCerealiere5 - AutreTransferts5
tab1 BanqueCerealiere5 - AutreTransferts5,nolab

// EA 2021
use "$input_data\Chad_ea_2021_assistance_originalVars.dta",clear
tab1 BanqueCerealiere6 - AutreTransferts6
tab1 BanqueCerealiere6 - AutreTransferts6,nolab

// PDM 2022
use "$input_data\Chad_pdm_2022_assistance_originalVars.dta",clear
tab1 BanqueCerealiere7 - AutreTransferts7
tab1 BanqueCerealiere7 - AutreTransferts7,nolab

// EA 2022
use "$input_data\Chad_ea_2022_assistance_originalVars.dta",clear
tab1 BanqueCerealiere8 - AutreTransferts8
tab1 BanqueCerealiere8 - AutreTransferts8,nolab

// PDM 2023
use "$input_data\Chad_pdm_2023_assistance_originalVars.dta",clear
tab1 BanqueCerealiere9 - AutreTransferts9
tab1 BanqueCerealiere9 - AutreTransferts9,nolab

// EA 2023
use "$input_data\Chad_ea_2023_assistance_originalVars.dta",clear
tab1 BanqueCerealiere10 - AutreTransferts10
tab1 BanqueCerealiere10 - AutreTransferts10,nolab
