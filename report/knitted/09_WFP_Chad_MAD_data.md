---
title: "WFP datasets wrangling - Chad : Régime alimentaire minimum acceptable"
author: "Aboubacar HEMA"
date: "2025-03-05"
output: 
  html_document:
    toc: true
    toc_depth: 3
    toc_float: true
    number_sections: true
    code_folding: show
    keep_md: true
---







```r
library(haven)
library(labelled) # for general functions to work with labelled data
library(tidyverse) # general wrangling
library(dplyr)
library(Hmisc)
library(gtsummary) # to demonstrate automatic use of variable labels in summary tables
library(readxl)
library(foreign)
library(sjPlot)
library(sjmisc)
library(sjlabelled) # for example efc data set with variable labels
library(stringr)
```





```r
rm(list = ls())
```



```r
dir_input_data = "C:/Users/AHema/OneDrive - CGIAR/Desktop/WFP Resilience dataset/data/input_data/Chad"
dir_output_data = "C:/Users/AHema/OneDrive - CGIAR/Desktop/WFP Resilience dataset/data/output_data/Chad"
```


```r
Chad_Harmonization_variables <- read_excel(paste0(dir_input_data,"/Chad_Harmonization.xlsx"), 
    sheet = "variables_harmonization")
#View(Chad_Harmonization_variables)

Chad_Harmonization_description <- read_excel(paste0(dir_input_data,"/Chad_Harmonization.xlsx"), 
    sheet = "description")
#View(Chad_Harmonization_description)
```


```r
lst_data = Chad_Harmonization_description$Data
lst_test = Chad_Harmonization_description$Name

for(i in 1:length(lst_data)) {                              # Head of for-loop
  assign(lst_test[i],                                   # Read and store data frames
         read_sav(paste0(dir_input_data,"/",lst_data[i])))
}
```

# Data consistency  Check







## Drop duplicated observations



## Consent check



## ID Check 








```r
path = "C:/Users/AHema/OneDrive - CGIAR/Desktop/WFP Resilience dataset/"
```


```r
MAD_ea_2021 <- read_sav(paste0(path,"data/input_data/Chad/MAD_MDDW data/consent_PCMADRepeat623_Decembre_2021.sav"))
MAD_ea_2022 <- read_sav(paste0(path,"data/input_data/Chad/MAD_MDDW data/consent_PCMADRepeat623_Decembre_2022.sav"))
MAD_ea_2023 <- read_sav(paste0(path,"data/input_data/Chad/MAD_MDDW data/consent_PCMADRepeat623_Decembre_2023.sav"))
MAD_pdm_2022 <- read_sav(paste0(path,"data/input_data/Chad/MAD_MDDW data/consent_PCMADRepeat623_Juillet_2022.sav"))
MAD_pdm_2023 <- read_sav(paste0(path,"data/input_data/Chad/MAD_MDDW data/consent_PCMADRepeat623_Juillet_2023.sav"))
```


```r
Chad_pdm_2022$ID = 1:nrow(Chad_pdm_2022)
```



# EA 2021


```r
df_ea_2021 = Chad_ea_2021 %>% 
  dplyr::select(`@_id`,`@_index`)

names(df_ea_2021) <- c("ID","Key_with_subset_data")

MAD_ea_2021$Key_with_subset_data <- MAD_ea_2021$`@_parent_index`
MAD_ea_2021 = dplyr::left_join(df_ea_2021, MAD_ea_2021, by = "Key_with_subset_data")

MAD_ea_2021 = MAD_ea_2021 %>% 
  dplyr::select(!starts_with("@"))

MAD_ea_2021 = MAD_ea_2021 %>% 
  dplyr::filter(!is.na(PCMAD_childnumber))
```


# EA 2022


```r
df_ea_2022 = Chad_ea_2022 %>% 
  dplyr::select(`@_id`,`@_index`)

names(df_ea_2022) <- c("ID","Key_with_subset_data")

MAD_ea_2022$Key_with_subset_data <- MAD_ea_2022$`@_parent_index`
MAD_ea_2022 = dplyr::left_join(df_ea_2022, MAD_ea_2022, by = "Key_with_subset_data")

MAD_ea_2022 = MAD_ea_2022 %>% 
  dplyr::select(!starts_with("@"))

MAD_ea_2022 = MAD_ea_2022 %>% 
  dplyr::filter(!is.na(PCMAD_childnumber))
```



# EA 2023


```r
df_ea_2023 = Chad_ea_2023 %>% 
  dplyr::select(`@_id`,`@_index`)

names(df_ea_2023) <- c("ID","Key_with_subset_data")

MAD_ea_2023$Key_with_subset_data <- MAD_ea_2023$`@_parent_index`
MAD_ea_2023 = dplyr::left_join(df_ea_2023, MAD_ea_2023, by = "Key_with_subset_data")

MAD_ea_2023 = MAD_ea_2023 %>% 
  dplyr::select(!starts_with("@"))

MAD_ea_2023 = MAD_ea_2023 %>% 
  dplyr::filter(!is.na(PCMAD_childnumber))

MAD_ea_2023 <- MAD_ea_2023 %>%
  mutate(across(MAD_sex, ~ifelse(.==0, 1, 2)))


# Labels mapping
label_map <- c(
  Femme = 1,
  Homme = 2
)

# Apply labels using mutate() and across()
MAD_ea_2023 <- MAD_ea_2023 %>%
  mutate(across(MAD_sex,
                ~ labelled::labelled(., label_map)))



MAD_ea_2023 <- MAD_ea_2023 %>%
  mutate(across(c(EverBreastF,PCIYCBreastF,PCMADStapCer,PCMADVegOrg,PCMADStapRoo,PCMADVegGre,PCMADFruitOrg,PCMADVegFruitOth,PCMADPrMeatO,PCMADPrMeatF,PCMADPrEgg,PCMADPrFish,PCMADPulse,PCMADDairy,PCMADFatRpalm,PCMADSnfChild,PCMADSnfPowd,PCMADSnfLns), ~ifelse(is.na(.),NA,ifelse(.==0, 1, ifelse(.==1,2,3)))))
# Labels mapping
label_map <- c(
  Non = 1,
  Oui = 2,
  `Ne sait pas` = 3
)

# Apply labels using mutate() and across()
MAD_ea_2023 <- MAD_ea_2023 %>%
  mutate(across(c(EverBreastF,PCIYCBreastF,PCMADStapCer,PCMADVegOrg,PCMADStapRoo,PCMADVegGre,PCMADFruitOrg,PCMADVegFruitOth,PCMADPrMeatO,PCMADPrMeatF,PCMADPrEgg,PCMADPrFish,PCMADPulse,PCMADDairy,PCMADFatRpalm,PCMADSnfChild,PCMADSnfPowd,PCMADSnfLns),
                ~ labelled::labelled(., label_map)))
```



# PDM 2022


```r
df_pdm_2022 = Chad_pdm_2022 %>% 
  dplyr::select("ID",`@_index`)

names(df_pdm_2022) = c("ID","Key_with_subset_data")

MAD_pdm_2022$Key_with_subset_data <- MAD_pdm_2022$`@_parent_index`
MAD_pdm_2022 = dplyr::left_join(df_pdm_2022, MAD_pdm_2022, by = "Key_with_subset_data")

MAD_pdm_2022 = MAD_pdm_2022 %>% 
  dplyr::select(!starts_with("@"))

MAD_pdm_2022 = MAD_pdm_2022 %>% 
  dplyr::filter(!is.na(PCMAD_childnumber))
```



# PDM 2023



```r
df_pdm_2023 = Chad_pdm_2023 %>% 
  dplyr::select(`@_id`,`@_index`)

names(df_pdm_2023) <- c("ID","Key_with_subset_data")
MAD_pdm_2023$Key_with_subset_data <- MAD_pdm_2023$`@_parent_index`
MAD_pdm_2023 = dplyr::left_join(df_pdm_2023, MAD_pdm_2023, by = "Key_with_subset_data")

MAD_pdm_2023 = MAD_pdm_2023 %>% 
  dplyr::select(!starts_with("@"))

MAD_pdm_2023 = MAD_pdm_2023 %>% 
  dplyr::filter(!is.na(PCMAD_childnumber))
```


# Régime alimentaire minimum acceptable (MAD)

# Export all data


```r
dir_output_data = "C:/Users/AHema/OneDrive - CGIAR/Desktop/WFP Resilience dataset/data/output_data/Chad"
```





```r
WFP_Chad_MAD<-plyr::rbind.fill(MAD_ea_2021,
                                MAD_ea_2022,
                                MAD_ea_2023,
                                MAD_pdm_2022,
                                MAD_pdm_2023)


WFP_Chad_MAD$ID <- as.character(WFP_Chad_MAD$ID)
WFP_Chad_MAD = WFP_Chad_MAD %>% 
  dplyr::select(-c("Key_with_subset_data","MAD_name","MAD_dob","PCMAD_childnumber"))


WFP_Chad_MAD <- WFP_Chad_MAD %>%
  mutate(across(MAD_sex, ~ifelse(is.na(.),NA,ifelse(.==1, 0, 1))))


# Labels mapping
label_map <- c(
  Femme = 0,
  Homme = 1
)

# Apply labels using mutate() and across()
WFP_Chad_MAD <- WFP_Chad_MAD %>%
  mutate(across(MAD_sex,
                ~ labelled::labelled(., label_map)))


WFP_Chad_MAD <- WFP_Chad_MAD %>%
  mutate(across(c(EverBreastF,PCIYCBreastF,PCMADStapCer,PCMADVegOrg,PCMADStapRoo,PCMADVegGre,PCMADFruitOrg,PCMADVegFruitOth,PCMADPrMeatO,PCMADPrMeatF,PCMADPrEgg,PCMADPrFish,PCMADPulse,PCMADDairy,PCMADFatRpalm,PCMADSnfChild,PCMADSnfPowd,PCMADSnfLns), ~ifelse(is.na(.),NA,ifelse(.==1,0, ifelse(.==2,1,888)))))

# Labels mapping
label_map <- c(
  Non = 0,
  Oui = 1,
  `Ne sait pas` = 888
)

# Apply labels using mutate() and across()
WFP_Chad_MAD <- WFP_Chad_MAD %>%
  mutate(across(c(EverBreastF,PCIYCBreastF,PCMADStapCer,PCMADVegOrg,PCMADStapRoo,PCMADVegGre,PCMADFruitOrg,PCMADVegFruitOth,PCMADPrMeatO,PCMADPrMeatF,PCMADPrEgg,PCMADPrFish,PCMADPulse,PCMADDairy,PCMADFatRpalm,PCMADSnfChild,PCMADSnfPowd,PCMADSnfLns),
                ~ labelled::labelled(., label_map)))
```





```r
write_sav(WFP_Chad_MAD, paste0(dir_output_data,"/WFP_Chad_MAD.sav"))
write_dta(WFP_Chad_MAD, paste0(dir_output_data,"/WFP_Chad_MAD.dta"))
```





