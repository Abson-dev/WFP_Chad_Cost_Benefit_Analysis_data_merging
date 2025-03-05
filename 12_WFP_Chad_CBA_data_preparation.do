/*
##################################### IFPRI ##########################################

# WFP Chad CBA data merging (from 2018 to 2023)
# 
# Contributors : Aboubacar Hema, 
# Other resources used:
# Version of code : 2.0.0
# Description:
# Last edited by : Aboubacar Hema
# Imput data used:

				WFP_Chad_admin.dta
				WFP_Chad_assistance.dta
				WFP_Chad_FCS.dta
				WFP_Chad_HH.dta
				WFP_Chad_LhCSI.dta
				WFP_Chad_rCSI.dta
				WFP_Chad_SERS.dta
				WFP_Chad_ABI.dta
				WFP_Chad_HDDS.dta
				
# Output data produced:

				WFP_Chad_admin.dta
				WFP_Chad_assistance.dta
				WFP_Chad_FCS.dta
				WFP_Chad_HH.dta
				WFP_Chad_LhCSI.dta
				WFP_Chad_rCSI.dta
				WFP_Chad_SERS.dta
				WFP_Chad_ABI.dta
				WFP_Chad_HDDS.dta	
				WFP_Chad_2018-2023_20250305
#################################### Africa #########################################
*/


global input_data "C:\Users\AHema\OneDrive - CGIAR\Desktop\WFP Resilience dataset\data\output_data\Chad"
global output_data "C:\Users\AHema\OneDrive - CGIAR\Desktop\2024\WFP\CBA - Chad\data"
global output_data_name "WFP_Chad_2018-2023"

/*
global current_datetime = date("$S_DATE", "DMY")
format current_datetime %td
display "$current_datetime"
*/

/*

********************************************************************************
*					  Duplicate rows and some inconsistencies
*******************************************************************************/

// Import WFP admin data
use "$input_data\WFP_Chad_admin.dta",clear

//Identify Duplicate Rows
duplicates report

//List Duplicate Rows
duplicates list ID

//create a new variable that flags duplicate rows
duplicates tag, generate(dup_flag)
/*
- dup_flag will be 0 for unique rows.
- It will be 1 or higher for duplicates.
*/
//list only the duplicate rows:
list ID if dup_flag > 0

// have an overview of survey and year
tab SURVEY YEAR if dup_flag > 0

//remove duplicate rows while keeping the first occurrence
duplicates drop ID, force

// admin 1 check
tab ID if adm1_ocha == ""

tab SURVEY YEAR if adm1_ocha == "" //PDM 2023, 1 observation
// In the original data for this ID, the interviwer didn't accept to participate and we have missing for all the variables. We need to drop this ID.
drop if adm1_ocha == ""
//or
drop if ID == "41057035"
drop dup_flag

//convert the variable YEAR from string to numeric while replacing the original variable
destring YEAR, replace

//assign labels
label var ID "Household ID"
label var SvyDatePDM "Interview Date"
label var ADMIN1Name "Region (ADMIN1) where the household is located"
label var ADMIN2Name "District (ADMIN2) where the household is located"
label var village "Village where the household is located"

	
/*
Barh El Gazel Sud	TCD1901
Barh El Gazel Nord	TCD1902
Barh El Gazel Ouest	TCD1903

*/	
********************************************************************************
*					  Correct inconsistencies in Village and Admin 2 variables
*******************************************************************************/
tab village

//Replaces missing values with "UNKNOWN"
replace village = "UNKNOWN" if missing(village)
tab village

//remove any numeric digits (0-9) from the village variable using regular expressions
replace village = ustrregexra(village, "[0-9]", "")
tab village

//Replaces missing values with "UNKNOWN"
replace village = "UNKNOWN" if missing(village)
tab village

//remove leading and trailing spaces from the village variable
replace village = trim(village)
tab village

//generate a cross-tabulation of YEAR and SURVEY, but with a condition filtering cases where village is either empty ("") or "UNKNOWN"
tab YEAR SURVEY if missing(village) | village == "UNKNOWN"

/*
          |    Type d'enquête
     Annee | Enquête..        PDM |     Total
-----------+----------------------+----------
      2020 |         0         35 |        35 
      2021 |       118          0 |       118 
      2022 |         0          1 |         1 
-----------+----------------------+----------
     Total |       118         36 |       154 
*/



//Sort the dataset by YEAR and SURVEY
sort YEAR SURVEY

//Reorder the variables
order ID SvyDatePDM YEAR SURVEY ADMIN0Name adm0_ocha ADMIN1Name adm1_ocha ADMIN2Name adm2_ocha village Longitude Latitude Longitude_precision Latitude_precision

//relationship between adm1_ocha and adm2_ocha to display counts of how often each combination of values in adm1_ocha and adm2_ocha occurs
table (adm1_ocha adm2_ocha)


tab village if missing(adm2_ocha)

tab YEAR SURVEY if 	missing(adm2_ocha)
/*

           |    Type
           | d'enquête
     Annee |       PDM |     Total
-----------+-----------+----------
      2020 |       271 |       271 
-----------+-----------+----------
     Total |       271 |       271 


*/
count if missing(adm2_ocha) & YEAR == 2020 & SURVEY == "PDM"

tab village if missing(adm2_ocha) & YEAR == 2020 & SURVEY == "PDM"

// We will fill Admin 2 information using village name

tab ADMIN2Name adm2_ocha  if village == "ABGARA"
/*

In which ADMIN2Name |
   is the household | Admin 2 ID
           located? |    TD0101 |     Total
--------------------+-----------+----------
        Batha Ouest |        42 |        42 
--------------------+-----------+----------
              Total |        42 |        42 


*/

replace adm2_ocha ="TD0101"  if village == "ABGARA"
replace ADMIN2Name ="Batha Ouest"  if adm2_ocha == "TD0101" & ADMIN2Name ==""

tab ADMIN2Name adm2_ocha if village == "AMCHALAKHAT"
replace village = "AMCHALAHAT SAHAYAR" if village == "AMCHALAKHAT"
tab ADMIN2Name adm2_ocha if village == "AMCHALAHAT SAHAYAR"
/*

In which ADMIN2Name |
   is the household | Admin 2 ID
           located? |    TD0101 |     Total
--------------------+-----------+----------
        Batha Ouest |        29 |        29 
--------------------+-----------+----------
              Total |        29 |        29 

*/
replace adm2_ocha ="TD0101"  if village == "AMCHALAHAT SAHAYAR"
replace ADMIN2Name ="Batha Ouest"  if village =="AMCHALAHAT SAHAYAR"
/*
*/
tab ADMIN2Name adm2_ocha if village == "AMCHARMA",m
/*
In which ADMIN2Name |
   is the household |      Admin 2 ID
           located? |               TD0102 |     Total
--------------------+----------------------+----------
                    |         1          0 |         1 
          Batha Est |         0         23 |        23 
--------------------+----------------------+----------
              Total |         1         23 |        24 


*/
replace adm2_ocha ="TD0102"  if village == "AMCHARMA"
replace ADMIN2Name ="Batha Est"  if adm2_ocha == "TD0102" & village == "AMCHARMA"

tab ADMIN2Name adm2_ocha if village == "AMCHOKA",m
/*
In which ADMIN2Name |
   is the household |      Admin 2 ID
           located? |               TD0102 |     Total
--------------------+----------------------+----------
                    |         2          0 |         2 
          Batha Est |         0         63 |        63 
--------------------+----------------------+----------
              Total |         2         63 |        65 

*/
replace adm2_ocha ="TD0102"  if village == "AMCHOKA"
replace ADMIN2Name ="Batha Est"  if adm2_ocha == "TD0102" & village == "AMCHOKA"


tab ADMIN2Name adm2_ocha if village == "AMDAKOUR",m
/*

In which ADMIN2Name |
   is the household |      Admin 2 ID
           located? |               TD0401 |     Total
--------------------+----------------------+----------
                    |         5          0 |         5 
              Guera |         0        137 |       137 
--------------------+----------------------+----------
              Total |         5        137 |       142 

*/

replace adm2_ocha ="TD0401"  if village == "AMDAKOUR"
replace ADMIN2Name ="Guera"  if adm2_ocha == "TD0401" & village == "AMDAKOUR"

tab ADMIN2Name adm2_ocha if village == "AMDJOUFOUR",m
/*

In which ADMIN2Name |
   is the household |      Admin 2 ID
           located? |               TD0102 |     Total
--------------------+----------------------+----------
                    |         1          0 |         1 
          Batha Est |         0        150 |       150 
--------------------+----------------------+----------
              Total |         1        150 |       151 

*/
replace adm2_ocha ="TD0102"  if village == "AMDJOUFOUR"
replace ADMIN2Name ="Batha Est"  if adm2_ocha == "TD0102" & village == "AMDJOUFOUR"

tab ADMIN2Name adm2_ocha if village == "ANGOULO",m
/*

In which ADMIN2Name |
   is the household |            Admin 2 ID
           located? |               TD1401     TD1403 |     Total
--------------------+---------------------------------+----------
                    |         7          0          0 |         7 
          Assoungha |         0          0          4 |         4 
              Ouara |         0         17          0 |        17 
--------------------+---------------------------------+----------
              Total |         7         17          4 |        28 
This village isn't in the excel community file
*/

tab YEAR  SURVEY if village == "ANGOULO",m

tab ADMIN2Name adm2_ocha if village == "ANGOULO" & YEAR == 2018,m
/*
In which ADMIN2Name |
   is the household |      Admin 2 ID
           located? |    TD1401     TD1403 |     Total
--------------------+----------------------+----------
          Assoungha |         0          4 |         4 
              Ouara |        17          0 |        17 
--------------------+----------------------+----------
              Total |        17          4 |        21 

*/
tab adm2_ocha adm1_ocha if village == "ANGOULO" & YEAR == 2018,m
/*

           | Admin 1 ID
Admin 2 ID |      TD14 |     Total
-----------+-----------+----------
    TD1401 |        17 |        17 
    TD1403 |         4 |         4 
-----------+-----------+----------
     Total |        21 |        21 

*/

replace adm2_ocha ="TD1401"  if village == "ANGOULO"
replace ADMIN2Name ="Ouara"  if adm2_ocha == "TD1401" & village == "ANGOULO"

/*
*/
tab ADMIN2Name adm2_ocha if village == "ATILO",m
/*
In which ADMIN2Name |
   is the household |      Admin 2 ID
           located? |               TD1401 |     Total
--------------------+----------------------+----------
                    |        11          0 |        11 
              Ouara |         0        119 |       119 
--------------------+----------------------+----------
              Total |        11        119 |       130 

*/

replace adm2_ocha ="TD1401"  if village == "ATILO"
replace ADMIN2Name ="Ouara"  if adm2_ocha == "TD1401" & village == "ATILO"




tab ADMIN2Name adm2_ocha if village == "BARDE",m
/*

In which ADMIN2Name |
   is the household |      Admin 2 ID
           located? |               TD0101 |     Total
--------------------+----------------------+----------
                    |         1          0 |         1 
        Batha Ouest |         0         67 |        67 
--------------------+----------------------+----------
              Total |         1         67 |        68 

*/
replace adm2_ocha ="TD0101"  if village == "BARDE"
replace ADMIN2Name ="Batha Ouest"  if adm2_ocha == "TD0101" & village == "BARDE"


tab ADMIN2Name adm2_ocha if village == "BIBI BARRAGE",m
/*
In which ADMIN2Name |
   is the household |            Admin 2 ID
           located? |               TD0701     TD0703 |     Total
--------------------+---------------------------------+----------
                    |         2          0          0 |         2 
               Kaya |         0          0         44 |        44 
              Mamdi |         0         17          0 |        17 
--------------------+---------------------------------+----------
              Total |         2         17         44 |        63 

*/
tab adm2_ocha adm1_ocha if village == "BIBI BARRAGE"
/*

           | Admin 1 ID
Admin 2 ID |      TD07 |     Total
-----------+-----------+----------
    TD0701 |        17 |        17 
    TD0703 |        44 |        44 
-----------+-----------+----------
     Total |        61 |        61 

*/


tab ADMIN2Name ADMIN1Name if village == "BIBI BARRAGE"

replace adm2_ocha ="TD0703"  if village == "BIBI BARRAGE"
replace ADMIN2Name ="Kaya"  if adm2_ocha == "TD0703" & village == "BIBI BARRAGE"
/*
*/
tab ADMIN2Name adm2_ocha if village == "BOULOUNGOU",m
/*
In which ADMIN2Name |
   is the household |            Admin 2 ID
           located? |               TD1901     TD1902 |     Total
--------------------+---------------------------------+----------
                    |        12          0          0 |        12 
  Barh-El-Gazel Sud |         0        152        198 |       350 
--------------------+---------------------------------+----------
              Total |        12        152        198 |       362 

*/

replace adm2_ocha ="TD1901"  if village == "BOULOUNGOU"
replace ADMIN2Name ="Barh-El-Gazel Sud"  if adm2_ocha == "TD1901" & village == "BOULOUNGOU"

/*
*/

/*
*/
tab ADMIN2Name adm2_ocha if village == "BRÉGUÉ BIRGUIT",m
/*
In which ADMIN2Name |
   is the household |                 Admin 2 ID
           located? |               TD0101     TD0102     TD1502 |     Total
--------------------+--------------------------------------------+----------
                    |         4          0          0          0 |         4 
           Aboudeia |         0          0          0        165 |       165 
          Batha Est |         0          0        179          0 |       179 
        Batha Ouest |         0          1          0          0 |         1 
--------------------+--------------------------------------------+----------
              Total |         4          1        179        165 |       349 

*/

replace adm2_ocha ="TD0102"  if village == "BRÉGUÉ BIRGUIT"

replace ADMIN2Name ="Batha Est"  if adm2_ocha =="TD0102"  & village == "BRÉGUÉ BIRGUIT"

tab ADMIN2Name adm2_ocha if village == "CHAOUIR",m
/*

In which ADMIN2Name |
   is the household |      Admin 2 ID
           located? |               TD0401 |     Total
--------------------+----------------------+----------
                    |         5          0 |         5 
              Guera |         0        193 |       193 
--------------------+----------------------+----------
              Total |         5        193 |       198 

*/
replace adm2_ocha ="TD0401"  if village == "CHAOUIR"

replace ADMIN2Name ="Guera"  if adm2_ocha =="TD0401"  & village == "CHAOUIR"

tab ADMIN2Name adm2_ocha if village == "DANKOUTCHE",m
/*
In which ADMIN2Name |
   is the household |      Admin 2 ID
           located? |               TD1403 |     Total
--------------------+----------------------+----------
                    |         4          0 |         4 
          Assoungha |         0         76 |        76 
--------------------+----------------------+----------
              Total |         4         76 |        80 

*/

replace adm2_ocha ="TD1403"  if village == "DANKOUTCHE"
replace ADMIN2Name ="Assoungha"  if adm2_ocha =="TD1403"  & village == "DANKOUTCHE"


tab ADMIN2Name adm2_ocha if village == "DOURBANE",m

/*

In which ADMIN2Name |
   is the household |      Admin 2 ID
           located? |               TD0102 |     Total
--------------------+----------------------+----------
                    |         3          0 |         3 
          Batha Est |         0         56 |        56 
--------------------+----------------------+----------
              Total |         3         56 |        59 

*/
replace adm2_ocha ="TD0102"  if village == "DOURBANE"
replace ADMIN2Name ="Batha Est"  if adm2_ocha =="TD0102"  & village == "DOURBANE"

tab ADMIN2Name adm2_ocha if village == "FORKOULOM",m
/*

In which ADMIN2Name |
   is the household | Admin 2 ID
           located? |    TD0703 |     Total
--------------------+-----------+----------
                    |        10 |        10 
               Kaya |       274 |       274 
              Mamdi |        20 |        20 
--------------------+-----------+----------
              Total |       304 |       304 


The right mane in the excel file is FOURKOULOM	
https://www.bing.com/maps?q=FOURKOULOM&FORM=HDRSC7&cp=13.607178%7E14.132731&lvl=16.0		  
*/
tab SURVEY YEAR if village == "FORKOULOM"

replace adm2_ocha ="TD0703"  if village == "FORKOULOM"
replace ADMIN2Name ="Kaya"  if adm2_ocha =="TD0703"  & village == "FORKOULOM"
replace village ="FOURKOULOM"  if village == "FORKOULOM"


tab ADMIN2Name adm2_ocha if village == "GAMÉ",m
/*

In which ADMIN2Name |
   is the household |      Admin 2 ID
           located? |               TD0401 |     Total
--------------------+----------------------+----------
                    |        10          0 |        10 
              Guera |         0        298 |       298 
--------------------+----------------------+----------
              Total |        10        298 |       308 

*/


tab adm2_ocha if village == "GOUM EST"
tab adm2_ocha if village == "GOUM OUEST"


tab ADMIN2Name adm2_ocha if village == "KADJALA",m
/*

In which ADMIN2Name |
   is the household |      Admin 2 ID
           located? |               TD1403 |     Total
--------------------+----------------------+----------
                    |         7          0 |         7 
          Assoungha |         0         71 |        71 
--------------------+----------------------+----------
              Total |         7         71 |        78 

*/
replace adm2_ocha ="TD1403"  if village == "KADJALA"
replace ADMIN2Name ="Assoungha"  if adm2_ocha =="TD1403"  & village == "KADJALA"


tab ADMIN2Name adm2_ocha if village == "KAMKALAGA",m
/*

In which ADMIN2Name |
   is the household |      Admin 2 ID
           located? |               TD1902 |     Total
--------------------+----------------------+----------
                    |         9          0 |         9 
  Barh-El-Gazel Sud |         0         47 |        47 
--------------------+----------------------+----------
              Total |         9         47 |        56 

*/
replace adm2_ocha ="TD1902"  if village == "KAMKALAGA"
replace ADMIN2Name ="Barh-El-Gazel Sud"  if adm2_ocha =="TD1902"  & village == "KAMKALAGA"


tab ADMIN2Name adm2_ocha if village == "KOKORDEYE",m
/*

In which ADMIN2Name |
   is the household |      Admin 2 ID
           located? |               TD1902 |     Total
--------------------+----------------------+----------
                    |         3          0 |         3 
  Barh-El-Gazel Sud |         0         21 |        21 
--------------------+----------------------+----------
              Total |         3         21 |        24 

*/
replace adm2_ocha ="TD1902"  if village == "KOKORDEYE"
replace ADMIN2Name ="Barh-El-Gazel Sud"  if adm2_ocha =="TD1902"  & village == "KOKORDEYE"

tab ADMIN2Name adm2_ocha if village == "KONDOKO",m
/*

In which ADMIN2Name |
   is the household |      Admin 2 ID
           located? |               TD1702 |     Total
--------------------+----------------------+----------
                    |        24          0 |        24 
           Dar-Tama |         0         22 |        22 
--------------------+----------------------+----------
              Total |        24         22 |        46 

*/

replace adm2_ocha ="TD1702"  if village == "KONDOKO"
replace ADMIN2Name ="Dar-Tama"  if adm2_ocha =="TD1702"  & village == "KONDOKO"

tab ADMIN2Name adm2_ocha if village == "KOULKIME",m
/*

In which ADMIN2Name |
   is the household |            Admin 2 ID
           located? |               TD0701     TD0703 |     Total
--------------------+---------------------------------+----------
                    |         5          0          0 |         5 
               Kaya |         0          0         18 |        18 
              Mamdi |         0         10          0 |        10 
--------------------+---------------------------------+----------
              Total |         5         10         18 |        33 

https://www.bing.com/maps?q=KOULKIME&FORM=HDRSC7&cp=13.495653%7E14.466007&lvl=17.9
*/
replace adm2_ocha ="TD0703"  if village == "KOULKIME"
replace ADMIN2Name ="Kaya"  if adm2_ocha =="TD0703"  & village == "KOULKIME"



tab ADMIN2Name adm2_ocha if village == "KOURSIGUE",m
/*

In which ADMIN2Name |
   is the household |      Admin 2 ID
           located? |               TD1702 |     Total
--------------------+----------------------+----------
                    |        12          0 |        12 
           Dar-Tama |         0         72 |        72 
--------------------+----------------------+----------
              Total |        12         72 |        84 

*/
replace adm2_ocha ="TD1702"  if village == "KOURSIGUE"
replace ADMIN2Name ="Dar-Tama"  if adm2_ocha =="TD1702"  & village == "KOURSIGUE"

tab ADMIN2Name adm2_ocha if village == "MALLAH",m
/*

In which ADMIN2Name |
   is the household |      Admin 2 ID
           located? |               TD0401 |     Total
--------------------+----------------------+----------
                    |         5          0 |         5 
              Guera |         0         86 |        86 
--------------------+----------------------+----------
              Total |         5         86 |        91 

*/
replace adm2_ocha ="TD0401"  if village == "MALLAH"
replace ADMIN2Name ="Guera"  if adm2_ocha =="TD0401"  & village == "MALLAH"

tab ADMIN2Name adm2_ocha if village == "MANDABA",m
/*

In which ADMIN2Name |
   is the household |      Admin 2 ID
           located? |               TD1401 |     Total
--------------------+----------------------+----------
                    |         9          0 |         9 
              Ouara |         0        135 |       135 
--------------------+----------------------+----------
              Total |         9        135 |       144 

*/
replace adm2_ocha ="TD1401"  if village == "MANDABA"
replace ADMIN2Name ="Ouara"  if adm2_ocha =="TD1401"  & village == "MANDABA"

tab ADMIN2Name adm2_ocha if village == "NGOUBOUA",m
/*

In which ADMIN2Name |
   is the household |            Admin 2 ID
           located? |               TD0701     TD0703 |     Total
--------------------+---------------------------------+----------
                    |         8          0          0 |         8 
               Kaya |         0          0         52 |        52 
              Mamdi |         0          2          0 |         2 
--------------------+---------------------------------+----------
              Total |         8          2         52 |        62 

The real name is N'Gouboua			  
*/
replace adm2_ocha ="TD0703"  if village == "NGOUBOUA"
replace ADMIN2Name ="Kaya"  if adm2_ocha =="TD0703"  & village == "NGOUBOUA"

tab ADMIN2Name adm2_ocha if village == "TABO",m
/*
In which ADMIN2Name |
   is the household |      Admin 2 ID
           located? |               TD0401 |     Total
--------------------+----------------------+----------
                    |        15          0 |        15 
              Guera |         0        313 |       313 
--------------------+----------------------+----------
              Total |        15        313 |       328 


*/
replace adm2_ocha ="TD0401"  if village == "TABO"
replace ADMIN2Name ="Guera"  if adm2_ocha =="TD0401"  & village == "TABO"

tab ADMIN2Name adm2_ocha if village == "TARKAMA",m
/*

In which ADMIN2Name |
   is the household |      Admin 2 ID
           located? |               TD0101 |     Total
--------------------+----------------------+----------
                    |         2          0 |         2 
        Batha Ouest |         0         82 |        82 
--------------------+----------------------+----------
              Total |         2         82 |        84 

*/
replace adm2_ocha ="TD0101"  if village == "TARKAMA"
replace ADMIN2Name ="Batha Ouest"  if adm2_ocha =="TD0101"  & village == "TARKAMA"

tab ADMIN2Name adm2_ocha if village == "TCHALLA",m
/*

In which ADMIN2Name |
   is the household |      Admin 2 ID
           located? |               TD0601 |     Total
--------------------+----------------------+----------
                    |        13          0 |        13 
              Kanem |         0        193 |       193 
--------------------+----------------------+----------
              Total |        13        193 |       206 

*/
replace adm2_ocha ="TD0601"  if village == "TCHALLA"
replace ADMIN2Name ="Kanem"  if adm2_ocha =="TD0601"  & village == "TCHALLA"

tab ADMIN2Name adm2_ocha if village == "TCHARIKOURATI",m
/*

In which ADMIN2Name |
   is the household | Admin 2 ID
           located? |           |     Total
--------------------+-----------+----------
                    |         2 |         2 
--------------------+-----------+----------
              Total |         2 |         2 

*/

replace village ="TCHIRI OUDACHERI"  if village == "TCHARIKOURATI"
tab adm2_ocha  if village == "TCHADI KOLORI"
//TD0601
replace village ="TCHIRI OUADACHARI"  if village == "TCHADI KOLORI"
tab adm2_ocha  if village == "TCHARI KOURARI",m
//TD0701
//TD0703
replace village ="TCHIRI OUADACHARI"  if village == "TCHARI KOURARI"
tab adm2_ocha  if village == "TCHARI OUDACHERI"
//TD0601                                      
replace village ="TCHIRI OUADACHARI"  if village == "TCHARI OUDACHERI"
tab adm2_ocha  if village == "TCHARIKOURARI"
//TD0601
replace village ="TCHIRI OUDACHARI"  if village == "TCHARIKOURARI"
tab adm2_ocha  if village == "TCHIRI OUDACHERI"
//TD0601
replace village ="TCHIRI OUDACHARI"  if village == "TCHARI OUDACHERI"

tab adm2_ocha if village == "TCHIRI OUDACHERI",m
replace adm2_ocha ="TD0601"  if village == "TCHIRI OUDACHARI"
tab ADMIN2Name if village == "TCHIRI OUDACHERI",m
replace ADMIN2Name ="Kanem"  if village == "TCHIRI OUDACHERI"
replace village ="TCHIRI OUDACHARI"  if village == "TCHIRI OUDACHERI"
replace ADMIN2Name ="Kanem"  if village == "TCHIRI OUDACHARI"
replace adm2_ocha ="TD0601"  if village == "TCHIRI OUDACHARI"

tab ADMIN2Name adm2_ocha if village == "TONGOLI",m
/*

In which ADMIN2Name |
   is the household |      Admin 2 ID
           located? |               TD0101 |     Total
--------------------+----------------------+----------
                    |         1          0 |         1 
        Batha Ouest |         0         75 |        75 
--------------------+----------------------+----------
              Total |         1         75 |        76

*/
replace adm2_ocha ="TD0101"  if village == "TONGOLI"
replace ADMIN2Name ="Batha Ouest"  if adm2_ocha =="TD0101"  & village == "TONGOLI"

tab ADMIN2Name adm2_ocha if village == "WADICHAGARA",m
/*

In which ADMIN2Name |
   is the household |                 Admin 2 ID
           located? |               TD1901     TD1902     TD2101 |     Total
--------------------+--------------------------------------------+----------
                    |        15          0          0          0 |        15 
  Barh-El-Gazel Sud |         0         93        223          0 |       316 
             Kimiti |         0          0          0         67 |        67 
--------------------+--------------------------------------------+----------
              Total |        15         93        223         67 |       398 

*/
replace adm2_ocha ="TD1902"  if village == "WADICHAGARA"
replace ADMIN2Name ="Barh-El-Gazel Sud"  if adm2_ocha =="TD1902"  & village == "WADICHAGARA"


tab ADMIN2Name adm2_ocha if village == "WALDALMARA",m
/*

In which ADMIN2Name |
   is the household |      Admin 2 ID
           located? |               TD0102 |     Total
--------------------+----------------------+----------
                    |         8          0 |         8 
          Batha Est |         0         59 |        59 
--------------------+----------------------+----------
              Total |         8         59 |        67 

*/
replace adm2_ocha ="TD0102"  if village == "WALDALMARA"
replace ADMIN2Name ="Batha Est"  if adm2_ocha =="TD0102"  & village == "WALDALMARA"

tab ADMIN2Name adm2_ocha if village == "WOLEROM",m
/*

In which ADMIN2Name |
   is the household |            Admin 2 ID
           located? |               TD0701     TD0703 |     Total
--------------------+---------------------------------+----------
                    |         6          0          0 |         6 
               Kaya |         0          0         22 |        22 
              Mamdi |         0          2          0 |         2 
--------------------+---------------------------------+----------
              Total |         6          2         22 |        30 

*/
replace adm2_ocha ="TD0703"  if village == "WOLEROM"
replace ADMIN2Name ="Kaya"  if adm2_ocha =="TD0703"  & village == "WOLEROM"

tab ADMIN2Name adm2_ocha if village == "ZOBO",m
/*

In which ADMIN2Name |
   is the household |            Admin 2 ID
           located? |               TD0101     TD0102 |     Total
--------------------+---------------------------------+----------
                    |         4          0          0 |         4 
          Batha Est |         0          0        362 |       362 
        Batha Ouest |         0          2          0 |         2 
--------------------+---------------------------------+----------
              Total |         4          2        362 |       368 

*/

replace adm2_ocha ="TD0102"  if village == "ZOBO"
replace ADMIN2Name ="Batha Est"  if adm2_ocha =="TD0102"  & village == "ZOBO"


tab ADMIN2Name adm2_ocha if village == "GAMÉ",m
/*

In which ADMIN2Name |
   is the household |      Admin 2 ID
           located? |               TD0401 |     Total
--------------------+----------------------+----------
                    |        10          0 |        10 
              Guera |         0        298 |       298 
--------------------+----------------------+----------
              Total |        10        298 |       308 

*/
replace adm2_ocha ="TD0401"  if village == "GAMÉ"
replace ADMIN2Name ="Guera"  if adm2_ocha =="TD0401"  & village == "GAMÉ"
///




tab village
tab ADMIN2Name,m
tab village if missing(adm2_ocha) & YEAR == 2020 & SURVEY == "PDM"
replace village ="TCHIRI OUDACHARI"  if village == "TCHIRI OUDACHERI" & missing(adm2_ocha) & YEAR == 2020 & SURVEY == "PDM"
replace ADMIN2Name ="Kanem"  if village == "TCHIRI OUDACHARI" &  missing(adm2_ocha) & YEAR == 2020 & SURVEY == "PDM"
replace adm2_ocha ="TD0601"  if village == "TTCHIRI OUDACHARI" &  missing(adm2_ocha) & YEAR == 2020 & SURVEY == "PDM"




//replace ADMIN2Name = "Barh-El-Gazel Nord" if adm2_ocha == "TD1902"



table (adm1_ocha adm2_ocha)

tab village if adm1_ocha == "TD04" & adm2_ocha == "TD1901"
replace adm2_ocha ="TD1901"  if village == "BOULOUNGOU"
replace adm1_ocha ="TD19"  if village == "BOULOUNGOU"
replace ADMIN2Name ="Barh-El-Gazel Sud"  if adm2_ocha == "TD1901" & village == "BOULOUNGOU"
replace ADMIN1Name ="Barh-El-Gazel"  if village == "BOULOUNGOU"
//
tab village if adm1_ocha == "TD07" & adm2_ocha == "TD0601"
replace adm1_ocha ="TD06"  if village == "TCHIRI OUDACHARI"
replace ADMIN1Name ="Kanem"  if village == "TCHIRI OUDACHARI"
//


tab village if adm1_ocha == "TD14" & adm2_ocha == "TD1902"
replace adm1_ocha ="TD19"  if village == "KOKORDEYE"
replace ADMIN1Name ="Barh-El-Gazel"  if village == "KOKORDEYE"
//

tab village if adm1_ocha == "TD15" & adm2_ocha == "TD0102"
replace adm1_ocha ="TD01"  if village == "BRÉGUÉ BIRGUIT"
replace ADMIN1Name ="Batha"  if village == "BRÉGUÉ BIRGUIT"

//
tab village if adm1_ocha == "TD21" & adm2_ocha == "TD1902"
replace adm1_ocha ="TD19"  if village == "WADICHAGARA"
replace ADMIN1Name ="Barh-El-Gazel"  if village == "WADICHAGARA"


table (village adm2_ocha)

///////////////////////////////////////////////////////////////////////////////////////////////////////

tab SURVEY YEAR  if village == "ADOUMBA ARABE" // 1 observation
tab ADMIN2Name adm2_ocha  if village == "ADOUMBA ARABE"
tab village if adm2_ocha == "TD1702"
//
tab SURVEY YEAR  if village == "AMBADAYE"
tab ADMIN2Name adm2_ocha  if village == "AMBADAYE"
replace adm1_ocha ="TD01"  if village == "AMBADAYE"
replace ADMIN1Name ="Batha"  if village == "AMBADAYE"
replace adm2_ocha ="TD0101"  if village == "AMBADAYE"
replace ADMIN1Name ="Batha Ouest"  if village == "AMBADAYE"
//
tab SURVEY YEAR  if village == "AMDAYE" //1 observation
tab ADMIN2Name adm2_ocha  if village == "AMDAYE"
replace adm1_ocha ="TD01"  if village == "AMDAYE"
replace ADMIN1Name ="Batha"  if village == "AMDAYE"
replace adm2_ocha ="TD0101"  if village == "AMDAYE"
replace ADMIN1Name ="Batha Ouest"  if village == "AMDAYE"
replace village ="AMBADAYE"  if village == "AMDAYE"

//
tab SURVEY YEAR  if village == "AMIEYOUNA" //1 observation
tab ADMIN2Name adm2_ocha  if village == "AMIEYOUNA"
tab village if adm2_ocha == "TD1403"
replace village ="AMLEYOUNA"  if village == "AMIEYOUNA"

//
tab SURVEY YEAR  if village == "AMKALA" //1 observation
tab ADMIN2Name adm2_ocha  if village == "AMKALA"
tab village if adm2_ocha == "TD0103"
replace village ="DANKALA"  if village == "AMKALA"
replace village ="DANKALA"  if village == "DAMBALA"
replace village ="DANKALA"  if village == "DAMKALA"
//
tab SURVEY YEAR  if village == "AMKOUA" //more admin2
tab ADMIN2Name adm2_ocha  if village == "AMKOUA"
replace adm2_ocha ="TD1901"  if adm2_ocha == "TD1902"
//
tab SURVEY YEAR  if village == "AMLEYOUNA" //more admin2
tab ADMIN2Name adm2_ocha  if village == "AMLEYOUNA"
replace adm2_ocha ="TD1403"  if village == "AMLEYOUNA"
replace ADMIN2Name ="Assoungha"  if village == "AMLEYOUNA"
//
tab SURVEY YEAR  if village == "AMKOUDJOUR" //1 observation
tab ADMIN2Name adm2_ocha  if village == "AMKOUDJOUR"
tab village if adm2_ocha == "TD0401"
replace village ="AMDAKOUR"  if village == "AMKOUDJOUR"
replace village ="TCHÉLATI"  if village == "TCHELATI"
replace village ="BANDARO"  if village == "BANDA"
replace village ="CHAOUIR"  if village == "CHAIR"
//

tab SURVEY YEAR  if village == "ARADIP" //more admin2
tab ADMIN2Name adm2_ocha  if village == "ARADIP"
replace adm2_ocha ="TD0101"  if village == "ARADIP"
replace ADMIN2Name ="Batha Ouest"  if village == "ARADIP"

//
tab SURVEY YEAR  if village == "ARTCHINA" //1 observation
tab ADMIN2Name adm2_ocha  if village == "ARTCHINA"
tab village if adm2_ocha == "TD0601"
replace village ="TCHIRI OUDACHARI"  if village == "TCHIRI OUDACHERI"
tab ADMIN2Name adm2_ocha  if village == "TCHIRI OUDACHARI"

//

tab SURVEY YEAR  if village == "ATCHOULÉ" //2 observation
tab ADMIN2Name adm2_ocha  if village == "ATCHOULÉ"
tab village if adm2_ocha == "TD1401"
replace village ="ATCHILÉ"  if village == "ATCHOULÉ"
//



tab SURVEY YEAR  if village == "BAOUDA" //more admin2
tab ADMIN2Name adm2_ocha  if village == "BAOUDA"
replace adm2_ocha ="TD0101"  if village == "BAOUDA"
replace ADMIN2Name ="Batha Ouest"  if village == "BAOUDA"
replace adm1_ocha ="TD01"  if village == "BAOUDA"

//
tab SURVEY YEAR  if village == "BARARINGUÉ" //1 observation
tab ADMIN2Name adm2_ocha  if village == "BARARINGUÉ"
tab village if adm2_ocha == "TD1702"
replace village ="KONDOKO"  if village == "KNDOKO"
replace village ="KONDOKO"  if village == "KODOUGOU"


tab SURVEY YEAR  if village == "BARKADOUSSOU" //more admin2
tab ADMIN2Name adm2_ocha  if village == "BARKADOUSSOU"
replace adm2_ocha ="TD0602"  if village == "BARKADOUSSOU"
replace ADMIN2Name ="Nord Kanem"  if village == "BARKADOUSSOU"

tab SURVEY YEAR  if village == "BOULAKAKOUM" //3 observation
tab SURVEY YEAR  if village == "CAFOK" //2 observation
tab SURVEY YEAR  if village == "CAMP DE DJABAL" //1 observation
tab SURVEY YEAR  if village == "CHAIR" //1 observation
tab SURVEY YEAR  if village == "DJEDIDÉ" //1 observation
tab SURVEY YEAR  if village == "EASSALAFJOUL" //1 observation
tab SURVEY YEAR  if village == "ELIKONORY" //3 observation
tab SURVEY YEAR  if village == "ELINGA" //4 observation
tab SURVEY YEAR  if village == "EMOUSSARI" //1 observation
//
tab SURVEY YEAR  if village == "FASCAL" //more admin2
tab ADMIN2Name adm2_ocha  if village == "FASCAL"
replace adm2_ocha ="TD0703"  if village == "FASCAL"
replace ADMIN2Name ="Kaya"  if village == "FASCAL"


//
tab SURVEY YEAR  if village == "FASSALADJOUL" //more admin2
tab ADMIN2Name adm2_ocha  if village == "FASSALADJOUL"

tab SURVEY YEAR  if village == "FITRA" //1 observation
tab SURVEY YEAR  if village == "FOUKOUGOUROU" //3 observation

//
tab SURVEY YEAR  if village == "GOUMACHIROM" //more admin2
tab ADMIN2Name adm2_ocha  if village == "GOUMACHIROM"
replace adm2_ocha ="TD0703"  if village == "GOUMACHIROM"
replace ADMIN2Name ="Kaya"  if village == "GOUMACHIROM"

tab SURVEY YEAR  if village == "GRETY" //1 observation
tab SURVEY YEAR  if village == "GUISKA" //1 observation
tab SURVEY YEAR  if village == "HIDA" //1 observation
//
tab SURVEY YEAR  if village == "HIDJÉLIDJÉ-ERLÉ" //more admin2
tab ADMIN2Name adm2_ocha  if village == "HIDJÉLIDJÉ-ERLÉ"
replace adm2_ocha ="TD1403"  if village == "HIDJÉLIDJÉ-ERLÉ"
replace ADMIN2Name ="Assoungha"  if village == "HIDJÉLIDJÉ-ERLÉ"

tab SURVEY YEAR  if village == "HONDJEFOUR" //1 observation
tab SURVEY YEAR  if village == "HOZBEDA" //1 observation
tab SURVEY YEAR  if village == "IWIRI" //2 observation
//
tab SURVEY YEAR  if village == "KABARE" //more admin2
tab ADMIN2Name adm2_ocha  if village == "KABARE"
replace adm2_ocha ="TD0102"  if village == "KABARE"
replace ADMIN2Name ="Batha Ouest"  if village == "KABARE"

tab SURVEY YEAR  if village == "KADARANG" //2 observation
tab ADMIN2Name adm2_ocha  if village == "KANGALIA"
replace adm2_ocha ="TD0703"  if village == "KANGALIA"
replace ADMIN2Name ="Kaya"  if village == "KANGALIA"

tab ADMIN2Name adm2_ocha  if village == "KEREY"
tab ADMIN2Name adm2_ocha  if village == "KETEGNÉ"
tab ADMIN2Name adm2_ocha  if village == "KHOUMI"
tab ADMIN2Name adm2_ocha  if village == "KIRITOLI"
tab ADMIN2Name adm2_ocha  if village == "KNDOKO"
tab ADMIN2Name adm2_ocha  if village == "KODOUGOU"
//
tab ADMIN2Name adm2_ocha  if village == "KOTA"
replace adm2_ocha ="TD0602"  if village == "KOTA"
replace ADMIN2Name ="Nord Kanem"  if village == "KOTA"

tab ADMIN2Name adm2_ocha  if village == "KOTOUFOU"
tab ADMIN2Name adm2_ocha  if village == "KOUBAGRI"
tab ADMIN2Name adm2_ocha  if village == "KOUCHANG"
tab ADMIN2Name adm2_ocha  if village == "KOULOULA"
//
tab ADMIN2Name adm2_ocha  if village == "KOUMBAGRI"
replace adm2_ocha ="TD0601"  if village == "KOUMBAGRI"
replace ADMIN2Name ="Kanem"  if village == "KOUMBAGRI"

tab ADMIN2Name adm2_ocha  if village == "KOUNDJOUROU"
tab ADMIN2Name adm2_ocha  if village == "KOUNOUNGOU  KEBIR"
//
tab ADMIN2Name adm2_ocha  if village == "KOUNOUSSI"
tab village  if adm2_ocha == "TD2101"
tab village  if adm2_ocha == "TD1901"
replace village ="DEBE"  if village == "DEBE AMSEKMANGA"
replace village ="DEBE"  if village == "DEBE FOROU"
replace village ="DEBE"  if village == "DEBE IMARI"
replace village ="DEBE"  if village == "DEBE TOUKOULMOU"
replace village ="FASSALADJOUL"  if village == "EASSALAFJOUL"
/*
replace adm2_ocha ="TD0601"  if village == "KOUNOUSSI"
replace ADMIN2Name ="Kanem"  if village == "KOUNOUSSI"
*/
replace village ="N'GORLOLI"  if village == "NGORLOLI"

tab ADMIN2Name adm2_ocha  if village == "KOÏDÉ"
tab ADMIN2Name adm2_ocha  if village == "KÉKÉDINA"
tab ADMIN2Name adm2_ocha  if village == "LOUNÉ"
tab ADMIN2Name adm2_ocha  if village == "MADALA"
//
tab ADMIN2Name adm2_ocha  if village == "MAGAR"
replace adm2_ocha ="TD0101"  if village == "MAGAR"
replace ADMIN2Name ="Batha Ouest"  if village == "MAGAR"
replace adm1_ocha ="TD01"  if village == "MAGAR"
replace ADMIN1Name ="Batha"  if village == "MAGAR"
replace village ="MAAGAR"  if village == "MAGAR"

tab ADMIN2Name adm2_ocha  if village == "MALANGA"
replace adm2_ocha ="TD1401"  if village == "MALANGA"
replace ADMIN2Name ="Ouara"  if village == "MALANGA"
replace adm1_ocha ="TD14"  if village == "MALANGA"
replace ADMIN1Name ="Ouaddai"  if village == "MALANGA"


tab ADMIN2Name adm2_ocha  if village == "MALMARI"
replace adm2_ocha ="TD0703"  if village == "MALMARI"
replace ADMIN2Name ="Mamdi"  if village == "MALMARI"
replace adm1_ocha ="TD07"  if village == "MALMARI"
replace ADMIN1Name ="Lac"  if village == "MALMARI"

tab ADMIN2Name adm2_ocha  if village == "MALSERY"

tab ADMIN2Name adm2_ocha  if village == "MAMDI"
replace adm2_ocha ="TD0701"  if village == "MAMDI"
replace ADMIN2Name ="Mamdi"  if village == "MAMDI"

tab ADMIN2Name adm2_ocha  if village == "MANGA"
replace adm2_ocha ="TD1401"  if village == "MANGA"
replace ADMIN2Name ="Ouara"  if village == "MANGA"
replace adm1_ocha ="TD14"  if village == "MANGA"
replace ADMIN1Name ="Ouaddai"  if village == "MANGA"
replace village ="MALANGA"  if village == "MANGA"


tab ADMIN2Name adm2_ocha  if village == "MARGARE"
tab ADMIN2Name adm2_ocha  if village == "MASSAMA"
tab ADMIN2Name adm2_ocha  if village == "MEDI"
tab ADMIN2Name adm2_ocha  if village == "MIDI-KOURA"
tab ADMIN2Name adm2_ocha  if village == "MILE DOURNE"
tab ADMIN2Name adm2_ocha  if village == "MOINKOURA"
tab ADMIN2Name adm2_ocha  if village == "MOLLORI"

tab ADMIN2Name adm2_ocha  if village == "MOUKOULOU"
replace adm2_ocha ="TD0402"  if village == "MOUKOULOU"
replace ADMIN2Name ="Abtouyour"  if village == "MOUKOULOU"

tab ADMIN2Name adm2_ocha  if village == "MOUNDAYE"
replace adm2_ocha ="TD1501"  if village == "MOUNDAYE"
replace ADMIN2Name ="Bahr-Azoum"  if village == "MOUNDAYE"
replace adm1_ocha ="TD15"  if village == "MOUNDAYE"
replace ADMIN1Name ="Salamat"  if village == "MOUNDAYE"
replace village ="MOURAYE"  if village == "MOUNDAYE"

tab ADMIN2Name adm2_ocha  if village == "MOUNKOURA"
replace adm2_ocha ="TD0701"  if village == "MOUNKOURA"
replace ADMIN2Name ="Mamdi"  if village == "MOUNKOURA"


tab ADMIN2Name adm2_ocha  if village == "MÉLÉA"
replace adm2_ocha ="TD0701"  if village == "MÉLÉA"
replace ADMIN2Name ="Mamdi"  if village == "MÉLÉA"


tab ADMIN2Name adm2_ocha  if village == "NIERGUI"
replace adm2_ocha ="TD0601"  if village == "NIERGUI"
replace ADMIN2Name ="Kanem"  if village == "NIERGUI"
replace adm1_ocha ="TD06"  if village == "NIERGUI"
replace ADMIN1Name ="Kanem"  if village == "NIERGUI"


tab ADMIN2Name adm2_ocha  if village == "NOKOU"
replace adm2_ocha ="TD0601"  if village == "NOKOU"
replace ADMIN2Name ="Kanem"  if village == "NOKOU"
replace adm1_ocha ="TD06"  if village == "NOKOU"
replace ADMIN1Name ="Kanem"  if village == "NOKOU"


tab ADMIN2Name adm2_ocha  if village == "OBÉ"
tab ADMIN2Name adm2_ocha  if village == "QUARTIER HILLE KABIR"

tab ADMIN2Name adm2_ocha  if village == "RAKANA"
replace adm2_ocha ="TD1403"  if village == "RAKANA"
replace ADMIN2Name ="Assoungha"  if village == "RAKANA"


tab ADMIN2Name adm2_ocha  if village == "STRENA"
replace adm2_ocha ="TD1403"  if village == "STRENA"
replace ADMIN2Name ="Assoungha"  if village == "STRENA"


tab ADMIN2Name adm2_ocha  if village == "TALANGA"
replace adm2_ocha ="TD1401"  if village == "TALANGA"
replace ADMIN2Name ="Ouara"  if village == "TALANGA"
replace adm1_ocha ="TD14"  if village == "TALANGA"
replace ADMIN1Name ="Ouaddai"  if village == "TALANGA"
replace village ="MALANGA"  if village == "TALANGA"


tab ADMIN2Name adm2_ocha  if village == "TANDAL"

tab ADMIN2Name adm2_ocha  if village == "TCHAFOCK"
replace village ="CHAFOK"  if village == "TCHAFOCK"

tab ADMIN2Name adm2_ocha  if village == "TCHIRAMARE"
tab ADMIN2Name adm2_ocha  if village == "TCHOUKOU"

tab ADMIN2Name adm2_ocha  if village == "TOUBOUN KANNYA"
replace adm2_ocha ="TD0703"  if village == "TOUBOUN KANNYA"
replace ADMIN2Name ="Kaya"  if village == "TOUBOUN KANNYA"

tab ADMIN2Name adm2_ocha  if village == "UNKNOWN"
tab SURVEY YEAR  if village == "UNKNOWN"

tab ID if village == "UNKNOWN" & SURVEY == "PDM" & YEAR == 2022
tab ADMIN2Name if village == "UNKNOWN" & SURVEY == "PDM" & YEAR == 2022
tab village if SURVEY == "PDM" & YEAR == 2022
tab ADMIN1Name adm2_ocha  if village == "ISSEROM"
replace adm2_ocha ="TD0702"  if village == "UNKNOWN" & SURVEY == "PDM" & YEAR == 2022
replace ADMIN2Name ="Wayi"  if village == "UNKNOWN" & SURVEY == "PDM" & YEAR == 2022
replace adm1_ocha ="TD07"  if village == "UNKNOWN" & SURVEY == "PDM" & YEAR == 2022
replace ADMIN1Name ="Lac"  if village == "UNKNOWN" & SURVEY == "PDM" & YEAR == 2022
replace village ="ISSEROM"  if village == "UNKNOWN" & SURVEY == "PDM" & YEAR == 2022

// I need to check EN 2021 with 
tab ID if village == "UNKNOWN" & SURVEY == "Enquête annuelle" & YEAR == 2021
tab ADMIN1Name if village == "UNKNOWN" & SURVEY == "Enquête annuelle" & YEAR == 2021
tab ADMIN2Name if village == "UNKNOWN" & SURVEY == "Enquête annuelle" & YEAR == 2021

tab ADMIN2Name adm2_ocha  if village == "WALA"
replace adm2_ocha ="TD0701"  if village == "WALA"
replace ADMIN2Name ="Mamdi"  if village == "WALA"

tab ADMIN2Name adm2_ocha  if village == "WARASSOU"
tab ADMIN2Name adm2_ocha  if village == "YABARKA"

//
tab ID if village == "UNKNOWN" & SURVEY == "PDM" & YEAR == 2020

tab village if missing(adm2_ocha) & YEAR == 2020 & SURVEY == "PDM"

tab village if missing(adm2_ocha)
/*

   Village where the |
household is located |      Freq.     Percent        Cum.
---------------------+-----------------------------------
            GOUM EST |          3        7.32        7.32
          GOUM OUEST |          3        7.32       14.63
             UNKNOWN |         35       85.37      100.00
---------------------+-----------------------------------
               Total |         41      100.00

*/

// save 
save "$output_data\WFP_Chad_admin.dta",replace

/////////////
// Import WFP_Chad_assistance data
use "$input_data\WFP_Chad_assistance.dta",clear

//Identify Duplicate Rows
duplicates report

//List Duplicate Rows
duplicates list ID

//create a new variable that flags duplicate rows
duplicates tag, generate(dup_flag)
/*
- dup_flag will be 0 for unique rows.
- It will be 1 or higher for duplicates.
*/
//list only the duplicate rows:
list ID if dup_flag > 0

//remove duplicate rows while keeping the first occurrence
duplicates drop ID, force

br if ID == "41057035"
drop if ID == "41057035"
drop dup_flag
// save 
save "$output_data\WFP_Chad_assistance.dta",replace


/////////////
// Import WFP_Chad_HH data
use "$input_data\WFP_Chad_HH.dta",clear

//Identify Duplicate Rows
duplicates report

//List Duplicate Rows
duplicates list ID

//create a new variable that flags duplicate rows
duplicates tag, generate(dup_flag)
/*
- dup_flag will be 0 for unique rows.
- It will be 1 or higher for duplicates.
*/
//list only the duplicate rows:
list ID if dup_flag > 0

//remove duplicate rows while keeping the first occurrence
duplicates drop ID, force

br if ID == "41057035"
drop if ID == "41057035"
drop dup_flag
// save 
save "$output_data\WFP_Chad_HH.dta",replace


//////////////////////

/////////////
// Import WFP_Chad_FCS data
use "$input_data\WFP_Chad_FCS.dta",clear

//Identify Duplicate Rows
duplicates report

//List Duplicate Rows
duplicates list ID

//create a new variable that flags duplicate rows
duplicates tag, generate(dup_flag)
/*
- dup_flag will be 0 for unique rows.
- It will be 1 or higher for duplicates.
*/
//list only the duplicate rows:
list ID if dup_flag > 0

//remove duplicate rows while keeping the first occurrence
duplicates drop ID, force

br if ID == "41057035"
drop if ID == "41057035"
drop dup_flag
// save 
save "$output_data\WFP_Chad_FCS.dta",replace


/////////////
// Import WFP_Chad_LhCSI data
use "$input_data\WFP_Chad_LhCSI.dta",clear

//Identify Duplicate Rows
duplicates report

//List Duplicate Rows
duplicates list ID

//create a new variable that flags duplicate rows
duplicates tag, generate(dup_flag)
/*
- dup_flag will be 0 for unique rows.
- It will be 1 or higher for duplicates.
*/
//list only the duplicate rows:
list ID if dup_flag > 0

//remove duplicate rows while keeping the first occurrence
duplicates drop ID, force

br if ID == "41057035" // here he answered for this section
drop if ID == "41057035"
drop dup_flag
// save 
save "$output_data\WFP_Chad_LhCSI.dta",replace


/////////////
// Import WFP_Chad_rCSI data
use "$input_data\WFP_Chad_rCSI.dta",clear

//Identify Duplicate Rows
duplicates report

//List Duplicate Rows
duplicates list ID

//create a new variable that flags duplicate rows
duplicates tag, generate(dup_flag)
/*
- dup_flag will be 0 for unique rows.
- It will be 1 or higher for duplicates.
*/
//list only the duplicate rows:
list ID if dup_flag > 0

//remove duplicate rows while keeping the first occurrence
duplicates drop ID, force

br if ID == "41057035"
drop if ID == "41057035"
drop dup_flag
// save 
save "$output_data\WFP_Chad_rCSI.dta",replace


/////////////
// Import WFP_Chad_ABI data
use "$input_data\WFP_Chad_ABI.dta",clear

//Identify Duplicate Rows
duplicates report

//List Duplicate Rows
duplicates list ID

//create a new variable that flags duplicate rows
duplicates tag, generate(dup_flag)
/*
- dup_flag will be 0 for unique rows.
- It will be 1 or higher for duplicates.
*/
//list only the duplicate rows:
list ID if dup_flag > 0

//remove duplicate rows while keeping the first occurrence
duplicates drop ID, force

br if ID == "41057035"
drop if ID == "41057035"
drop dup_flag
// save 
save "$output_data\WFP_Chad_ABI.dta",replace


/////////////
// Import WFP_Chad_SERS data
use "$input_data\WFP_Chad_SERS.dta",clear

//Identify Duplicate Rows
duplicates report

//List Duplicate Rows
duplicates list ID

//create a new variable that flags duplicate rows
duplicates tag, generate(dup_flag)
/*
- dup_flag will be 0 for unique rows.
- It will be 1 or higher for duplicates.
*/
//list only the duplicate rows:
list ID if dup_flag > 0

//remove duplicate rows while keeping the first occurrence
duplicates drop ID, force

br if ID == "41057035"
drop if ID == "41057035"
drop dup_flag
// save 
save "$output_data\WFP_Chad_SERS.dta",replace

/////////////
// Import WFP_Chad_HDDS data
use "$input_data\WFP_Chad_HDDS.dta",clear

//Identify Duplicate Rows
duplicates report

//List Duplicate Rows
duplicates list ID

//create a new variable that flags duplicate rows
duplicates tag, generate(dup_flag)
/*
- dup_flag will be 0 for unique rows.
- It will be 1 or higher for duplicates.
*/
//list only the duplicate rows:
list ID if dup_flag > 0

//remove duplicate rows while keeping the first occurrence
duplicates drop ID, force

br if ID == "41057035"
drop if ID == "41057035"
drop dup_flag
// save 
save "$output_data\WFP_Chad_HDDS.dta",replace

/////////////////////////////////////////////////////////////






////////////////////////////////////////////////////////////
//loads  WFP_Chad_admin dataset
use "$output_data\WFP_Chad_admin.dta",clear
merge 1:1 ID using "$output_data\WFP_Chad_assistance.dta"
tab _merge
drop _m

//
merge 1:1 ID using "$output_data\WFP_Chad_FCS.dta"
tab _merge
drop _m

//
merge 1:1 ID using "$output_data\WFP_Chad_HH.dta"
tab _merge
drop _m

//
merge 1:1 ID using "$output_data\WFP_Chad_LhCSI.dta"
tab _merge
drop _m


//
merge 1:1 ID using "$output_data\WFP_Chad_rCSI.dta"
tab _merge
drop _m



//
merge 1:1 ID using "$output_data\WFP_Chad_SERS.dta"
tab _merge
drop _m


//
merge 1:1 ID using "$output_data\WFP_Chad_ABI.dta"
tab _merge
drop _m

//
merge 1:1 ID using "$output_data\WFP_Chad_HDDS.dta"
tab _merge
drop _m



//Sort the dataset by YEAR and SURVEY
sort YEAR SURVEY

//Reorder the variables
order ID SvyDatePDM YEAR SURVEY ADMIN0Name adm0_ocha ADMIN1Name adm1_ocha ADMIN2Name adm2_ocha village Longitude Latitude Longitude_precision Latitude_precision



*------------------------------------------------------------------------------*

*	                        
*                     WFP Assistencies

*------------------------------------------------------------------------------

// Correct WFP 2023 intervention labels values
foreach var of varlist TransfBenef BanqueCerealiere VivreContreTravail ArgentContreTravail DistribVivresSoudure DistribArgentSoudure BoursesAdo BlanketFeedingChildren BlanketFeedingWomen MAMChildren MASChildren MAMPLWomen FARNcommunaut FormationRenfCapacite CashTransfert CantineScolaire AutreTransferts { 
    recode `var' (1 = 1) (2 = 3) (3 = 4) if YEAR == 2023
}


//creates a label definition
lab def assistency 1"Oui PAM" 2"Oui Autre" 3"Non" 4"Ne Sait Pas"

//apply the label definition
foreach var of varlist TransfBenef BanqueCerealiere VivreContreTravail ArgentContreTravail DistribVivresSoudure DistribArgentSoudure BoursesAdo BlanketFeedingChildren BlanketFeedingWomen MAMChildren MASChildren MAMPLWomen FARNcommunaut FormationRenfCapacite CashTransfert CantineScolaire AutreTransferts { 
    label values `var' assistency
}

order DateDerniereAssist DateDerniereAssist_other Montant TransfBenef BanqueCerealiere VivreContreTravail ArgentContreTravail DistribVivresSoudure DistribArgentSoudure BoursesAdo BlanketFeedingChildren BlanketFeedingWomen MAMChildren MASChildren MAMPLWomen FARNcommunaut FormationRenfCapacite CashTransfert CantineScolaire AutreTransferts



	label var Montant "Amount"
	label var DateDerniereAssist "Last assistance received from WFP "
	label var DateDerniereAssist_other "Last assistance received from WFP : Other"
	label var TransfBenef "Has the household  or any member of your household  benefited in the last 12 months?"
	label var BanqueCerealiere "Cereal bank"
	label var VivreContreTravail "Vivre contre travail/ Food assistance for asset"
	label var ArgentContreTravail "Cash assistance for asset"
	label var DistribVivresSoudure "Free food distribution (e.g. during the lean period)"
	label var DistribArgentSoudure "Distribution gratuite d'argent (p. ex. pendant la période de soudure)"
	label var BoursesAdo "School bursaries for teenage girls"
	label var BlanketFeedingChildren "Blanket feeding - NSPAMM (children 6-23 months)"
	label var BlanketFeedingWomen "Blanket feeding-NSPAMM (pregnant and breastfeeding women)"
	label var MAMChildren "Management of moderate acute malnutrition in children aged 6 to 59 months at the health centre"
	label var MASChildren "Management of severe acute malnutrition in children aged between 6 and 59 months in health centres"
	label var MAMPLWomen "Management of acute malnutrition in pregnant or breast-feeding women at the health centre"
	label var FARNcommunaut "FARN/community nutrition"
	label var FormationRenfCapacite "Training/capacity building"
	label var CashTransfert "Cash transfer (social safety nets or other structures)"
	label var CantineScolaire "School canteen for children or take-home ration"
	label var AutreTransferts "Other transaction"

tab DateDerniereAssist_other
replace DateDerniereAssist_other = lower(DateDerniereAssist_other)
replace DateDerniereAssist_other = trim(DateDerniereAssist_other)  // Removes leading and trailing spaces
tab DateDerniereAssist_other	
gen WFP_beneciary = .
replace WFP_beneciary = 0 if regexm(DateDerniereAssist_other, "temoin|temoi|non|pas|aucun|aucune|jamais") & YEAR!=2018
replace WFP_beneciary = 1 if regexm(DateDerniereAssist_other, "passée") & WFP_beneciary == 0
replace WFP_beneciary = 1 if missing(WFP_beneciary)	& YEAR!=2018 
//drop WFP_beneciary  depuis l'année passé
tab WFP_beneciary

tab DateDerniereAssist_other WFP_beneciary	if WFP_beneciary == 0

foreach var of varlist TransfBenef BanqueCerealiere VivreContreTravail ArgentContreTravail DistribVivresSoudure DistribArgentSoudure BoursesAdo BlanketFeedingChildren BlanketFeedingWomen MAMChildren MASChildren MAMPLWomen FARNcommunaut FormationRenfCapacite CashTransfert CantineScolaire AutreTransferts { 
    recode `var' (1 = 3) (2 = 3) (4 = 3) if WFP_beneciary == 0
}


foreach var of varlist TransfBenef BanqueCerealiere VivreContreTravail ArgentContreTravail DistribVivresSoudure DistribArgentSoudure BoursesAdo BlanketFeedingChildren BlanketFeedingWomen MAMChildren MASChildren MAMPLWomen FARNcommunaut FormationRenfCapacite CashTransfert CantineScolaire AutreTransferts { 
    label values `var' assistency
}


drop WFP_beneciary


*------------------------------------------------------------------------------*

*	                        
*                     Household information

*------------------------------------------------------------------------------

order HHHSex HHHAge HHHEdu HHHMainActivity HHHMatrimonial HHSourceIncome
	label var HHSize "household size"
	label var HHHSex "What is the sex of the head of household?"
	label var HHHAge "What is the age of the head of household (in years)?"
	label var HHHEdu "What is the level of education attained by the head of household?"  
	
	label var HHHMainActivity "What is the main activity of the head of household?"
	label var HHHMatrimonial "What is the marital status of the head of household?"
	label var HHSourceIncome "What is the source of income of the head of household?"
	
	label var HHSize05M "Boys aged 0 to 5 months"
	label var HHSize23M "Boys aged 6 to 23 months"
	label var HHSize59M "Boys aged 24 to 59 months"
	label var HHSize5114M "Boys aged 5 to 14 years"
	label var HHSize1549M "Men aged 15 to 49"
	label var HHSize5064M "Men aged 50 to 64"
	label var HHSize65AboveM "Men aged 65 and over"

order HHSize HHSize05M HHSize23M HHSize59M HHSize5114M HHSize1549M HHSize5064M HHSize65AboveM HHSize05F HHSize23F HHSize59F HHSize5114F HHSize1549F HHSize5064F HHSize65AboveF
	label var HHSize05F "Girls aged 0 to 5 months"
	label var HHSize23F "Girls aged 6 to 23 months"
	label var HHSize59F "Girls aged 24 to 59 months"
	label var HHSize5114F "Girls aged 5 to 14 years"
	label var HHSize1549F "Women aged 15 to 49"
	label var HHSize5064F "Women aged 50 to 64"
	label var HHSize65AboveF "Women aged 65 and over"

*------------------------------------------------------------------------------*

*	                        
*                     Food Consumption Score (FCS)

*-----------------------------------------------------------------------------


** Label FCS relevant variables
	label var FCSStap		"Consumption over the past 7 days: cereals, grains and tubers"
	label var FCSPulse		"Consumption over the past 7 days: pulses"
	label var FCSDairy		"Consumption over the past 7 days: dairy products"
	label var FCSPr			"Consumption over the past 7 days: meat, fish and eggs"
	label var FCSVeg		"Consumption over the past 7 days: vegetables"
	label var FCSFruit		"Consumption over the past 7 days: fruit"
	label var FCSFruitOrg	"Consumption over the past 7 days: Orange fruit"	
	label var FCSFat		"Consumption over the past 7 days: fat and oil"
	label var FCSSugar		"Consumption over the past 7 days: sugaror sweets"
	label var FCSCond		"Consumption over the past 7 days: condiments or spices"
	
	label var FCSStapSRf "Source: cereals, grains and tubers"
	label var FCSPulseSRf "Source: pulses"
	label var FCSDairySRf "Source: dairy products"
	label var FCSPrSRf "Source: meat, fish and eggs"
	label var FCSVegSRf "Source: vegetables"
	label var FCSFruitSRf "Source: fruit"
	label var FCSFatSRf "Source: fat and oil"
	label var FCSSugarSRf "Source: sugaror sweets"
	label var FCSCondSRf	"Source: condiments or spices"

	label var SCA	"Food Consumption Score"
	label var FCS	"Food Consumption Score"	
	label var FCSCondSRf	"Source: condiments or spices"	
	
*Values labels: 
//Food acquisition codes
lab def food_acquisition 1"Own production (crops, animal)" 2"Fishing / Hunting " 3"Gathering" 4"Loan" 5"market (purchase with cash)" 6"market (purchase on credit)" 7"begging for food" 8"exchange labor or items for food" 9"gift (food) from family relatives or friends" 10"food aid from civil society, NGOs, government, WFP etc"

foreach var of varlist FCSStapSRf FCSPulseSRf FCSDairySRf FCSPrSRf FCSVegSRf FCSFruitSRf FCSFatSRf FCSSugarSRf FCSCondSRf { 
    label values `var' food_acquisition
}
 	
order SCA FCS FCS_hema FCSCat21 FCSCat28  FCSStap FCSStapSRf FCSPulse FCSPulseSRf FCSDairy FCSDairySRf FCSPr FCSPrSRf FCSPrMeatF FCSPrMeatO FCSPrFish FCSPrEgg FCSVeg FCSVegSRf FCSVegOrg FCSVegGre FCSFruit FCSFruitSRf FCSFruitOrg FCSFat FCSFatSRf FCSSugar FCSSugarSRf FCSCond FCSCondSRf	


*------------------------------------------------------------------------------*

*	                        
*                     reduced Coping Strategy Index (rCSI)

*-----------------------------------------------------------------------------
order rCSI rCSILessQlty rCSIBorrow rCSIMealSize rCSIMealAdult rCSIMealNb	


*------------------------------------------------------------------------------*

*	                        
*           Livelihood Coping Strategy for Food Security (LCS-FS) indicator

*-----------------------------------------------------------------------------	
*Values labels: 

lab def LcsEN_label 1"No, because I did not need to" 2"No, because I already sold those assets or have engaged in this activity within the last 12 months and cannot continue to do it" 3"Yes" 4"Not applicable (don't have children/these assets)" 
foreach var of varlist LhCSIStress1 LhCSIStress2 LhCSIStress3 LhCSIStress4 LhCSICrisis1 LhCSICrisis2 LhCSICrisis3 LhCSIEmergency1 LhCSIEmergency2 LhCSIEmergency3 { 
    label values `var' LcsEN_label
}

	

	label var LhCSIStress1 "Sold household assets/goods (radio, furniture, refrigerator, television, jewellery etc.) due to lack of food"
	label var LhCSIStress2 "Spent savings due to lack of food"
	label var LhCSIStress3 "Sent household members to eat elsewhere/live with family or friends due to lack of food"
	label var LhCSIStress4 "Purchased food/non-food on credit (incur debts) due to lack of food"
	label var LhCSICrisis1 "Sold productive assets or means of transport (sewing machine, wheelbarrow, bicycle, car, etc.)  due to lack of food"
	label var LhCSICrisis2 "Reduced expenses on health (including drugs)"
	label var LhCSICrisis3 "Withdrew children from school due to lack of food"
	label var LhCSIEmergency1 "Mortgaged/Sold house or land due to lack of food"
	label var LhCSIEmergency2 "Begged and/or scavenged (asked strangers for money/food) due to lack of food"
	label var LhCSIEmergency3 "Engaged in illegal income activities (theft, prostitution) due to lack of food"
 
/*
order LhCSIStress1 LhCSIStress2 LhCSIStress3 LhCSIStress4 LhCSICrisis1 LhCSICrisis2 LhCSICrisis3 LhCSIEmergency1 LhCSIEmergency2 LhCSIEmergency3 stress_coping_FS crisis_coping_FS emergency_coping_FS Max_coping_behaviourFS	
*/	

*------------------------------------------------------------------------------*

*	                        
*                     (HDDS): "Household Dietary Diversity Score"

*-----------------------------------------------------------------------------
label var   HDDS     "Household Dietary Diversity Score"
label var   HDDSStapCer     "household eat/consume the following foods yesterday: Rice, pasta, bread, sorghum, millet, maize."
label var   HDDSStapRoot     "household eat/consume the following foods yesterday: Potato, yam, cassava, white sweet potato."
label var   HDDSPulse     "household eat/consume the following foods yesterday: Beans, cowpeas, peanuts, lentils, nut, soy, pigeon pea and/or other nuts"
label var   HDDSDairy     "household eat/consume the following foods yesterday: Fresh milk/sour, yogurt, cheese, other dairy products (Exclude margarine/butter or small amounts of milk for tea/coffee)"
label var   HDDSPrMeat     "household eat/consume the following foods yesterday: Goat, beef, chicken, pork, blood (meat consumed in large quantities and not as a condiment)"
label var   HDDSPrFish     "household eat/consume the following foods yesterday: Fish, including canned tuna, escargot, and / or other seafood (fish in large quantities and not as a condiment)."
label var   HDDSPrEgg     "household eat/consume the following foods yesterday: Eggs"
label var   HDDSVegOrg   "household eat/consume the following foods yesterday: Orange vegetables (vegetables rich in Vitamin A)"
label var   HDDSVegGre   "household eat/consume the following foods yesterday: Green leafy vegetables"
label var   HDDSVegOth   "household eat/consume the following foods yesterday: Other vegetables"
label var   HDDSFruitOrg   "household eat/consume the following foods yesterday: Orange fruits (Fruits rich in Vitamin A)"
label var   HDDSFruitOth   "household eat/consume the following foods yesterday: Other fruits"
label var   HDDSFat     "household eat/consume the following foods yesterday: Vegetable oil, palm oil, shea butter, margarine, other fats/oil."
label var   HDDSSugar     "household eat/consume the following foods yesterday: Sugar, honey, jam, cakes, candy, cookies, pastries, cakes and other sweet (sugary drinks)."
label var   HDDSCond     "household eat/consume the following foods yesterday: Tea, coffee/cocoa, salt, garlic, spices, yeast/baking powder, lanwin, tomato/sauce, meat or fish as a condiment, condiments including small amount of milk/tea coffee."

label var   HDDSPrMeatF "household eat/consume the following foods yesterday: Flesh meat"
label var   HDDSPrMeatO  "household eat/consume the following foods yesterday: Organ meat"
label var   HDDSCat_IPC  "IPC Classification for HDDS"
order HDDS_hema HDDS HDDS_CH HDDSCat_IPC HDDSStapCer HDDSStapRoot HDDSPulse HDDSVegOrg HDDSVegGre HDDSVegOth HDDSFruitOrg HDDSFruitOth HDDSPrMeatF HDDSPrMeatO HDDSPrFish HDDSPrEgg HDDSDairy HDDSSugar HDDSFat HDDSCond HDDSPrMeat HDDSVegAll HDDSFruitAll HDDSPrMeatAll  HDDSStapCer_calc HDDSStapRoot_calc HDDSVeg_calc HDDSFruit_calc HDDSPrMeat_calc HDDSPrEgg_calc HDDSPrFish_calc HDDSPulse_calc HDDSDairy_calc HDDSFat_calc HDDSSugar_calc HDDSCond_calc


drop HDDSVegAll - HDDSCond_calc

*------------------------------------------------------------------------------*

*	                        
*                    (ABI): "ASSET BENEFIT INDICATOR"

*-----------------------------------------------------------------------------


lab var ABIProteger         "Do you think that the assets that have been created or rehabilitated in your community are likely to protect your household, its property and its production capacity (fields, equipment, etc.) against floods/droughts/disasters?"
lab var ABIProduction         "Do you think that the assets that have been created or rehabilitated in your community have enabled your household to increase or diversify its production (agriculture / livestock / other)?"
lab var ABIdifficultes         "Do you think that the assets that have been created or rehabilitated in your community have reduced daily hardship, reduced the burden and duration of domestic chores: (time spent collecting water/wood for heating, women drawing water to prepare food)? 0=No ; 1=Yes ; 888=Don't know ;"
lab var ABIMarches         "Do you think that the assets that have been created or rehabilitated in your community have improved the ability of members of your household to access markets and/or basic services (water, sanitation, health, education, etc.)? "
lab var ABIGererActifs         "Do you think that the training and other support provided in your community has improved your household's capacity to manage and maintain assets?"
lab var ABIEnvironnement         "Do you think the assets that have been built or rehabilitated in your community have improved your natural environment (e.g. more vegetation cover, increased water table, less erosion, etc.)? "
lab var ABIutiliseractifs         "Do you think that the work carried out in your community has restored your ability to access and/or use the assets? "
lab var ABITensions         "Do you think that the [assets] created/rehabilitated have helped to reduce tensions over access to and use of natural resources in your community? "
lab var ActifCreationEmploi         "Do you think the [name the assets] rehabilitated/created have generated employment opportunities in your community? "
lab var BeneficieEmploi         "Have you or any member of your household ever had the opportunity to work as a result of the [name the assets] created or rehabilitated in your community? "
lab var TRavailMaintienActif         "Have you or any member of your household had work in the maintenance and management of the [name the assets] created or rehabilitated in your community? "


tab ABIScore,m
tab YEAR SURVEY if ABIScore==.

tab1 ABIProteger ABIProduction ABIdifficultes ABIMarches ABIGererActifs ABIEnvironnement ABIutiliseractifs ABITensions ActifCreationEmploi BeneficieEmploi TRavailMaintienActif


*------------------------------------------------------------------------------*

*	                        
*                    Self-evaluated resilience score

*-----------------------------------------------------------------------------
//https://github.com/WFP-VAM/RAMResourcesScripts/blob/main/Indicators/Resilience-capacity-score/RCS-indicator-calculation.do

lab var SERSRebondir         "Your household can bounce back from any climatic, economic or socio-political challenge that life may throw at it.    "
lab var SERSRevenue         "If affected by a climate, economic or socio-political challenge, your household can change or adapt its primary source of income to meet the challenges that other members of your community face."
lab var SERSMoyen         "If the climatic, economic or socio-political threats to your household become more frequent and intense, you will always find a way to cope."
lab var SERSDifficultes         "Your household could easily access the financial support it would need if it were affected by a climatic, economic or socio-political problem that would cause it hardship.  "
lab var SERSSurvivre         "Your household can afford everything it needs to survive and prosper"
lab var SERSFamAmis         "In the event of unmet basic needs due to events/shocks/stress (climatic OR economic OR conflict OR other), your household can count on the support of family and friends."
lab var SERSPoliticiens         "In the event of basic needs not being met due to events/shocks/stress (climatic OR economic OR conflict OR other), your household can count on support from the public/governmental administration or other institutions."
lab var SERSLecons         "Your household has learned important lessons from past difficulties caused by events/shocks/stresses (climatic OR economic OR conflicts OR other) that help you to better prepare for similar threats in the near future."
lab var SERSPreparerFuture         "Your household is fully prepared for any future event/shock/stress (climatic OR economic OR conflict OR other) that may occur in your area."
lab var SERSAvertissementEven         "Your household receives advance warning of future variability (climatic OR economic OR conflict OR other) and weather risks that help prepare and protect against future shocks/stresses."


gen HHRCSBounce = SERSRebondir
gen HHRCSRevenue = SERSRevenue 
gen HHRCSIncrease = SERSMoyen
gen HHRCSFinAccess = SERSDifficultes
gen HHRCSSupportCommunity = SERSFamAmis
gen HHRCSLessonsLearnt = SERSLecons
gen HHRCSFutureChallenge = SERSPreparerFuture  
gen HHRCSWarningAccess = SERSAvertissementEven
gen HHRCSSupportPublic = SERSPoliticiens     


//recode HHRCSBounce HHRCSRevenue HHRCSIncrease HHRCSFinAccess HHRCSSupportCommunity HHRCSLessonsLearnt HHRCSFutureChallenge HHRCSWarningAccess HHRCSSupportPublic (. = 0) if (YEAR !=2018 |  YEAR !=2019)

label var HHRCSBounce          "Your household can bounce back from any challenge that life throws at it."
label var HHRCSRevenue         "During times of hardship your household can change its primary income or source of livelihood if needed."
label var HHRCSIncrease        "If threats to your household became more frequent and intense, you would still find a way to get by."
label var HHRCSFinAccess       "During times of hardship your household can access the financial support you need."
label var HHRCSSupportCommunity "Your household can rely on the support of family or friends when you need help."
label var HHRCSLessonsLearnt    "Your household has learned important lessons from past hardships that will help you to better prepare for future challenges."
label var HHRCSSupportPublic    "Your household can rely on the support from public administration/government or other institutions when you need help."
label var HHRCSFutureChallenge  "Your household is fully prepared for any future challenges or threats that life throws at it."
label var HHRCSWarningAccess    "Your household receives useful information warning you about future risks in advance."

label define Likert5 1 "Strongly Agree" 2 "Partially agree" 3 "Neutral" 4 "Somewhat disagree" 5 "Totally disagree"
label values HHRCSBounce HHRCSRevenue HHRCSIncrease HHRCSFinAccess HHRCSSupportCommunity HHRCSSupportPublic HHRCSLessonsLearnt HHRCSFutureChallenge HHRCSWarningAccess Likert5

egen temp_nonmiss_numberHHRCS = rownonmiss(HHRCSBounce HHRCSRevenue HHRCSIncrease HHRCSFinAccess HHRCSSupportCommunity HHRCSSupportPublic HHRCSLessonsLearnt HHRCSFutureChallenge HHRCSWarningAccess) 
tab temp_nonmiss_numberHHRCS
tab temp_nonmiss_numberHHRCS YEAR
egen RCS= rowtotal(HHRCSBounce HHRCSRevenue HHRCSIncrease HHRCSFinAccess HHRCSSupportCommunity HHRCSSupportPublic HHRCSLessonsLearnt HHRCSFutureChallenge HHRCSWarningAccess) 
replace RCS=(100-0)*((RCS/9)-5)/(1-5) + 0 if temp_nonmiss_numberHHRCS!=0
replace RCS=. if temp_nonmiss_numberHHRCS==0
label var RCS "Resilience Capacity Score"

tab YEAR SURVEY if RCS==.
/*
Once the RCS is calculated, households are divided in terciles (low-medium-high) to show the distribution of the RCS within the target population. Therefore:
	 if RCS<33 the household is categorized as reporting a low RCS,
	 if 33=<RCS<66 the household is categorized as reporting a medium RCS and
	 if RCS>=66 then the household is categorized as reporting a high RCS.
*/

gen RCSCat33=cond(RCS<33,1,cond(RCS<66,2,3))  if temp_nonmiss_numberHHRCS!=0
label var RCSCat33 "RCS Categories, thresholds 33-66"
*** define variables labels and properties for "RCS Categories".
label define RCSCat 1 "low RCS" 2 "medium RCS" 3 "high RCS"
label define RCSCat2 1 "low" 2 "medium" 3 "high"

label values RCSCat33 RCSCat

*produce the scores of resilience capacities as follows:
gen RCSAnticipatory=(100-0)*(HHRCSFutureChallenge-5)/(1-5) + 0 if temp_nonmiss_numberHHRCS!=0
gen RCSAbsorptive=(100-0)*(HHRCSBounce-5)/(1-5) + 0 if temp_nonmiss_numberHHRCS!=0
gen RCSTransformative=(100-0)*(HHRCSRevenue-5)/(1-5) + 0 if temp_nonmiss_numberHHRCS!=0
gen RCSAdaptive=(100-0)*(HHRCSIncrease-5)/(1-5) + 0 if temp_nonmiss_numberHHRCS!=0

label var RCSAnticipatory "Resilience Capacity - Anticipatory"
label var RCSAbsorptive "Resilience Capacity - Absorptive"
label var RCSTransformative "Resilience Capacity - Transformative"
label var RCSAdaptive "Resilience Capacity - Adaptive"



gen RCSAnticipatoryCat33=cond(RCSAnticipatory<33,1,cond(RCSAnticipatory<66,2,3)) if temp_nonmiss_numberHHRCS!=0
gen RCSAbsorptiveCat33=cond(RCSAbsorptive<33,1,cond(RCSAbsorptive<66,2,3)) if temp_nonmiss_numberHHRCS!=0
gen RCSTransformativeCat33=cond(RCSTransformative<33,1,cond(RCSTransformative<66,2,3)) if temp_nonmiss_numberHHRCS!=0
gen RCSSAdaptiveCat33=cond(RCSAdaptive<33,1,cond(RCSAdaptive<66,2,3)) if temp_nonmiss_numberHHRCS!=0

label values RCSAnticipatoryCat33 RCSAbsorptiveCat33 RCSTransformativeCat33 RCSSAdaptiveCat33 RCSCat2

label var RCSAnticipatoryCat33 "Resilience Capacity - Anticipatory Categories, thresholds 33-66"
label var RCSAbsorptiveCat33 "Resilience Capacity - Absorptive Categories, thresholds 33-66"
label var RCSTransformativeCat33 "Resilience Capacity - Transformative Categories, thresholds 33-66"
label var RCSSAdaptiveCat33 "Resilience Capacity - Adaptive Categories, thresholds 33-66"
drop temp_nonmiss_numberHHRCS

*** Let's now create the table of results needed in COMET reporting:
tabulate RCSAnticipatoryCat33, matcell(freq1) matrow(names1)
tabulate RCSAbsorptiveCat33, matcell(freq2) matrow(names2)
tabulate RCSTransformativeCat33, matcell(freq3) matrow(names3)
tabulate RCSSAdaptiveCat33, matcell(freq4) matrow(names4)
tabulate RCSCat33, matcell(freq5) matrow(names5)


matrix Anticipatory=freq1'/r(N)
matrix Absorptive=freq2'/r(N)
matrix Transformative=freq3'/r(N)
matrix Adaptive=freq4'/r(N)
matrix RCS=freq5'/r(N)
*All key results to be reported in the following table:
putexcel set "RCS_table.xlsx", replace
putexcel B1:D1, merge
putexcel A1=("RCS - Components") B1=("RCS Levels (percentages)") A3=("Anticipatory capacity") A4=("Absorptive capacity") A5=("Transformative capacity") A6=("Adaptive capacity") A7=("Resilience capacity")
putexcel B2=("Low") C2=("Medium") D2=("High")
putexcel B3=matrix(Anticipatory), nformat("#.0 %")
putexcel B4=matrix(Absorptive), nformat("#.0 %")
putexcel B5=matrix(Transformative), nformat("#.0 %")
putexcel B6=matrix(Adaptive), nformat("#.0 %")
putexcel B7=matrix(RCS), nformat("#.0 %")



//Sort the dataset by YEAR and SURVEY
sort YEAR SURVEY

//Reorder the variables
order ID SvyDatePDM YEAR SURVEY ADMIN0Name adm0_ocha ADMIN1Name adm1_ocha ADMIN2Name adm2_ocha village Longitude Latitude Longitude_precision Latitude_precision

save "$output_data\WFP_Chad_2018-2023_20250305.dta",replace
*** ----------------------------------------------------------------------------------------------------------------*

***	                 		IPC/CH Information

*** ----------------------------------------------------------------------------------------------------------------*

gen month_survey = month(SvyDatePDM)
tab month_survey,m
tab YEAR SURVEY if month_survey ==.

/*

           |    Type
           | d'enquête
     Annee |       PDM |     Total
-----------+-----------+----------
      2020 |        10 |        10 
-----------+-----------+----------
     Total |        10 |        10 

*/
replace month_survey = 8 if month_survey ==.
//Meeting Abel/Aboubacar on 22 May 2024 and  28 May 2024, 11h for clarifications
/*
Two times per year
-	July-August for PDM :lean season
-	December for enquête annuelle
*/
tab month_survey SURVEY,m  
/*

month_surv |          Type d'enquête
        ey |  Baseline  Enquête..        PDM |     Total
-----------+---------------------------------+----------
         1 |         4      3,428          0 |     3,432 
         2 |         0        169          1 |       170 
         4 |         0          0          2 |         2 
         5 |         0          1          0 |         1 
         6 |         0          0          2 |         2 
         7 |         0          0         43 |        43 
         8 |         0          0      4,454 |     4,454 
         9 |         3          0      1,002 |     1,005 
        10 |         6          2          0 |         8 
        11 |     3,639        774          0 |     4,413 
        12 |       327      3,398          0 |     3,725 
-----------+---------------------------------+----------
     Total |     3,979      7,772      5,504 |    17,255 

We need to recode some month_survey to ajust with SURVEY timing
*/

replace month_survey = 8 if (month_survey == 2 | month_survey == 4 | month_survey == 6 | month_survey == 9) & SURVEY == "PDM"
replace month_survey = 11 if (month_survey == 1 | month_survey == 9 | month_survey == 10) & SURVEY == "Baseline"
replace month_survey = 12 if (month_survey == 1 | month_survey == 2 | month_survey == 5 | month_survey == 10) & SURVEY == "Enquête annuelle"

tab SURVEY month_survey

tab YEAR month_survey


gen exercise_code = 1
replace exercise_code = 2 if month_survey >= 10
tab exercise_code

gen IP_var = string(YEAR) + string(exercise_code) + adm2_ocha if YEAR != 2018
replace IP_var = "2017" + string(exercise_code) + adm2_ocha if YEAR == 2018
tab IP_var
drop exercise_code
save "$output_data\WFP_Chad_2018-2023_20250305.dta",replace
//////////////////////////////////////////////////
/*
The Cadre Harmonise leads two cycle of analyses every year. One around October/November (after the publication of harvest forecasts and the results of nutrition and market surveys), and one around February/March (after the publication of the final results of agricultural production and any new data on nutrition, HEA, food consumption, etc.). The validity periods of the analyses are the same every year and they cover: March-May (current) and June-August (projection) for the March cycle, and October-December (current) and June-August (projection) for the November cycle of analysis.
*/


import excel "$output_data\cadre_harmonise_caf_ipc_mar24_final_ver-2.xlsx", sheet("Sheet1") firstrow clear

keep if adm0_pcod2 == "TD" & exercise_year >= 2017 & exercise_year != 2024
tab exercise_label exercise_year
tab adm2_pcod2 exercise_label 
tab chtype
keep if chtype == "current"
tab exercise_label exercise_year
tab phase_class
tab phase_class,m
drop if phase_class==.
tab phase_class


/*

STEP 4 : ESTIMATING NUTRITION AND FOOD-INSECURE 
POPULATIONS

 Producing population estimates is a complex exercise that involves the convergence of evidence and 
not a mathematical calculation. It consists of distributing populations of an area analysed by severity 
level (phase) of acute food and nutrition insecurity. It is done once the phase classification of the area 
is determined based on the convergence of available evidence and in a consensual manner. The basic 
principle is compliance with the 20% rule. This means that once the area is classified into a given phase, 
there should be at least 20% of the populations in this area spread over this phase or worse. For example, 
if the area is classified in Phase 2 (Stressed), the sum of the population proportions in Phase 2 to 5 
should be above 20%, and the sum of the population proportions in Phases 3 to 5 below 20%.
*/
gen p_phase1 = phase1/population
gen p_phase2 = phase2/population
gen p_phase3 = phase3/population
gen p_phase35 = phase35/population

drop foodconsumption_phase - usethisperiod
drop adm0_5_name adm0_5_pcod2 adm1_5_name adm1_5_pcod2 adm2_5_name adm2_5_pcod2
drop adm3_pcod2 adm0_pcod3
compare exercise_code reference_code
drop adm3_name
save "$output_data\cadre_harmonise_caf_ipc_mar24_final.dta",replace
gen IP_var = string(exercise_year) + string(exercise_code) + adm2_pcod2
tab IP_var

merge 1:m IP_var using "$output_data\WFP_Chad_2018-2023_20250305.dta"
/*

    Result                      Number of obs
    -----------------------------------------
    Not matched                           875
        from master                       834  (_merge==1)
        from using                         41  (_merge==2)

    Matched                            17,214  (_merge==3)
    -----------------------------------------


*/
tab _m
keep if _merge == 2 | _merge == 3
drop _m
sort YEAR SURVEY
order ID SvyDatePDM YEAR SURVEY ADMIN0Name adm0_ocha ADMIN1Name adm1_ocha ADMIN2Name adm2_ocha village Longitude Latitude Longitude_precision Latitude_precision IP_var exercise_year exercise_code exercise_code exercise_label
//drop IP_var

save "$output_data\WFP_Chad_2018-2023_20250305.dta",replace
//////////////////////////////////////////////////