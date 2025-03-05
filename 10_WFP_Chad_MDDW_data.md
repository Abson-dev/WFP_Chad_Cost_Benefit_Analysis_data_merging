---
title: "WFP datasets wrangling - Chad : Consistency check"
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
library(haven)
MDDW_ea_2021 <- read_sav(paste0(path,"/data/input_data/Chad/MAD_MDDW data/consent_HHSize1549F_MDDW_rpt_Decembre_2021.sav"))
MDDW_ea_2022 <- read_sav(paste0(path,"data/input_data/Chad/MAD_MDDW data/consent_HHSize1549F_MDDW_rpt_Decembre_2022.sav"))
MDDW_ea_2023 <- read_sav(paste0(path,"data/input_data/Chad/MAD_MDDW data/consent_HHSize1549F_MDDW_rpt_Decembre_2023.sav"))
MDDW_pdm_2022 <- read_sav(paste0(path,"data/input_data/Chad/MAD_MDDW data/consent_HHSize1549F_MDDW_rpt_Juillet_2022.sav"))
MDDW_pdm_2023 <- read_sav(paste0(path,"data/input_data/Chad/MAD_MDDW data/consent_HHSize1549F_MDDW_rpt_Juillet_2023.sav"))
```


```r
Chad_pdm_2022$ID = 1:nrow(Chad_pdm_2022)
```


# EA 2021


```r
df_ea_2021 = Chad_ea_2021 %>% 
  dplyr::select(`@_id`,`@_index`)

names(df_ea_2021) <-c("ID","Key_with_subset_data")
MDDW_ea_2021$Key_with_subset_data <- MDDW_ea_2021$`@_parent_index`
MDDW_ea_2021 = dplyr::left_join(df_ea_2021, MDDW_ea_2021, by = "Key_with_subset_data")

mddw_variables = c("MDDW_resp_age","HHSize1549F_MDDW_calc",MDDW_ea_2021 %>% dplyr::select(gtsummary::starts_with("PWMDD")) %>% names())
MDDW_ea_2021 = MDDW_ea_2021 %>% 
  dplyr::select("ID",mddw_variables)


MDDW_ea_2021 = MDDW_ea_2021 %>% 
  dplyr::filter(!is.na(MDDW_resp_age))
# MDDW_ea_2021 = MDDW_ea_2021 %>%
#   dplyr::group_by(ID) %>% 
#   dplyr::summarise_at(mddw_variables,max, na.rm = TRUE)
```


# EA 2022


```r
df_ea_2022 = Chad_ea_2022 %>% 
  dplyr::select(`@_id`,`@_index`)

names(df_ea_2022) <- c("ID","Key_with_subset_data")
MDDW_ea_2022$Key_with_subset_data <- MDDW_ea_2022$`@_parent_index`
MDDW_ea_2022 = dplyr::left_join(df_ea_2022, MDDW_ea_2022, by = "Key_with_subset_data")

mddw_variables = c("MDDW_resp_age","HHSize1549F_MDDW_calc",MDDW_ea_2022 %>% dplyr::select(gtsummary::starts_with("PWMDD")) %>% names())
MDDW_ea_2022 = MDDW_ea_2022 %>% 
  dplyr::select("ID",mddw_variables)
MDDW_ea_2022 = MDDW_ea_2022 %>% 
  dplyr::filter(!is.na(MDDW_resp_age))
# MDDW_ea_2022 = MDDW_ea_2022 %>%
#   dplyr::group_by(ID) %>% 
#   dplyr::summarise_at(mddw_variables,max, na.rm = TRUE)
```


# EA 2023


```r
df_ea_2023 = Chad_ea_2023 %>% 
  dplyr::select(`@_id`,`@_index`)

names(df_ea_2023) <- c("ID","Key_with_subset_data")
MDDW_ea_2023$Key_with_subset_data <- MDDW_ea_2023$`@_parent_index`
MDDW_ea_2023 = dplyr::left_join(df_ea_2023, MDDW_ea_2023, by = "Key_with_subset_data")

mddw_variables = c("MDDW_resp_age","HHSize1549F_MDDW_calc",MDDW_ea_2023 %>% dplyr::select(gtsummary::starts_with("PWMDD")) %>% names())
MDDW_ea_2023 = MDDW_ea_2023 %>% 
  dplyr::select("ID",mddw_variables)
MDDW_ea_2023 = MDDW_ea_2023 %>% 
  dplyr::filter(!is.na(MDDW_resp_age))
# MDDW_ea_2023 = MDDW_ea_2023 %>%
#   dplyr::group_by(ID) %>% 
#   dplyr::summarise_at(mddw_variables,max, na.rm = TRUE)
```

# PDM 2022


```r
df_pdm_2022 = Chad_pdm_2022 %>% 
  dplyr::select("ID",`@_index`)

names(df_pdm_2022) = c("ID","Key_with_subset_data")

MDDW_pdm_2022$Key_with_subset_data <- MDDW_pdm_2022$`@_parent_index`
MDDW_pdm_2022 = dplyr::left_join(df_pdm_2022, MDDW_pdm_2022, by = "Key_with_subset_data")

mddw_variables = c("MDDW_resp_age","HHSize1549F_MDDW_calc",MDDW_pdm_2022 %>% dplyr::select(gtsummary::starts_with("PWMDD")) %>% names())
MDDW_pdm_2022 = MDDW_pdm_2022 %>% 
  dplyr::select("ID",mddw_variables)
MDDW_pdm_2022 = MDDW_pdm_2022 %>% 
  dplyr::filter(!is.na(MDDW_resp_age))
# MDDW_pdm_2022 = MDDW_pdm_2022 %>%
#   dplyr::group_by(ID) %>% 
#   dplyr::summarise_at(mddw_variables,max, na.rm = TRUE)
```


# PDM 2023


```r
df_pdm_2023 = Chad_pdm_2023 %>% 
  dplyr::select(`@_id`,`@_index`)

names(df_pdm_2023) <- c("ID","Key_with_subset_data")
MDDW_pdm_2023$Key_with_subset_data <- MDDW_pdm_2023$`@_parent_index`
MDDW_pdm_2023 = dplyr::left_join(df_pdm_2023, MDDW_pdm_2023, by = "Key_with_subset_data")


mddw_variables = c("MDDW_resp_age","HHSize1549F_MDDW_calc",MDDW_pdm_2023 %>% dplyr::select(gtsummary::starts_with("PWMDD")) %>% names())
MDDW_pdm_2023 = MDDW_pdm_2023 %>% 
  dplyr::select("ID",mddw_variables)

mddw_variables = MDDW_pdm_2023 %>% dplyr::select(gtsummary::starts_with("PWMDD")) %>% names()

MDDW_pdm_2023 <- MDDW_pdm_2023 %>%
  mutate(across(mddw_variables, ~ifelse(.==0, 1, 2)))

MDDW_pdm_2023 = MDDW_pdm_2023 %>% 
  dplyr::filter(!is.na(MDDW_resp_age))
# Labels mapping
label_map <- c(
  Non = 1,
  Oui = 2
)

# Apply labels using mutate() and across()
MDDW_pdm_2023 <- MDDW_pdm_2023 %>%
  mutate(across(mddw_variables,
                ~ labelled::labelled(., label_map)))

# MDDW_pdm_2023 = MDDW_pdm_2023 %>%
#   dplyr::group_by(ID) %>% 
#   dplyr::summarise_at(mddw_variables,max, na.rm = TRUE)
```


# Export all data


```r
dir_output_data = "C:/Users/AHema/OneDrive - CGIAR/Desktop/WFP Resilience dataset/data/output_data/Chad"
```




```r
WFP_Chad_MDDW<-plyr::rbind.fill(MDDW_ea_2021,
MDDW_ea_2022,
MDDW_ea_2023,
MDDW_pdm_2022,
MDDW_pdm_2023)

mddw_variables = WFP_Chad_MDDW %>% dplyr::select(gtsummary::starts_with("PWMDD")) %>% names()

WFP_Chad_MDDW <- WFP_Chad_MDDW %>%
  mutate(across(mddw_variables, ~ifelse(is.na(.),NA,ifelse(.==1, 0, 1))))


# Labels mapping
label_map <- c(
  Non = 0,
  Oui = 1
)

# Apply labels using mutate() and across()
WFP_Chad_MDDW <- WFP_Chad_MDDW %>%
  mutate(across(mddw_variables,
                ~ labelled::labelled(., label_map)))
WFP_Chad_MDDW$HHSize1549F_MDDW_calc <- as.numeric(WFP_Chad_MDDW$HHSize1549F_MDDW_calc)
WFP_Chad_MDDW$ID <- as.character(WFP_Chad_MDDW$ID)

WFP_Chad_MDDW <- WFP_Chad_MDDW %>% 
  dplyr::select("ID","MDDW_resp_age",mddw_variables)
write_sav(WFP_Chad_MDDW, paste0(dir_output_data,"/WFP_Chad_MDDW.sav"))
write_dta(WFP_Chad_MDDW, paste0(dir_output_data,"/WFP_Chad_MDDW.dta"))
```

