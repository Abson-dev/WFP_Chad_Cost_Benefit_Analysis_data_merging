---
title: "WFP datasets wrangling - Chad : Assistency"
author: "Aboubacar HEMA"
date: "2025-03-16"
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
Chad_Harmonization_variables <- read_excel(paste0(dir_input_data,"/Chad_Harmonization_assistance.xlsx"), 
    sheet = "variables_harmonization")
#View(Chad_Harmonization_variables)

Chad_Harmonization_description <- read_excel(paste0(dir_input_data,"/Chad_Harmonization_assistance.xlsx"), 
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


```r
Chad_pdm_2022$ID = 1:nrow(Chad_pdm_2022)
```



```r
for (j in 1:length(lst_test)){
         df=  get(lst_test[j], envir = .GlobalEnv)
          for (i in 1:nrow(Chad_Harmonization_variables)){
            df[,Chad_Harmonization_variables$NewVariable_Name[i]]=ifelse(is.na(Chad_Harmonization_variables[i,lst_test[j]]),NA,df[,Chad_Harmonization_variables[i,lst_test[j]][[1]]])
          }
    
    df<-df %>% select(Chad_Harmonization_variables$NewVariable_Name)
    assign(lst_test[j],                                   # Read and store data frames
         df)
#write_sav(df, paste0(dir_output_data,"/",lst_test[j],".sav"))
write_dta(df, paste0(dir_output_data,"/",lst_test[j],"_assistance_originalVars.dta"))
    

}
```










