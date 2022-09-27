###########################################################################
#                                                                         #
# Program Name: Prog_3_EDA_Variable_Selection.R                           #
# Date Created: 8/9/2022                                                  #
# Created By: Elsa Haynes (elsa.c.haynes@kp.org)                          #
#                                                                         #
# Uses sampled datasets to reduce the number of variables in the final    #
#  datasets. Outputs updated final datasets with the selected variables.  #
#                                                                         #
###########################################################################

# %% Initialize Libraries and Paths

library(data.table)
library(dplyr)
library(janitor)
library(stringr)
library(Information)
library(factoextra)
library(randomForest)
library(MASS)
library(car)
library(caret)
library(corrr)
library(ROSE) # Over/Under Sampling
`%ni%` <- Negate(`%in%`)

setwd("C:/Users/c156934") # Set file path
source("//cs.msds.kp.org/scal/REGS/share15/KPIF_Analytics/Elsa/_Scripts for GitHub/portfolio/Modules/Classification_Model_Variable_Selection.R") 

# %% Remove columns that need to be kept in the final set
ListReportingCols <- c('AGLTY_INDIV_ID', 'OE_Season', 'Audience_CY',
                       'Treatment_Flag', 'Timing_Main_Flag', 'Timing_Late_Flag',
                       'OE7_Test_MainHIOrd1_Flag', 'OE7_Test_MainHIOrd2_Flag',
                       'OE7_Test_MainHIOrd3_Flag', 'OE7_Test_MainHIOrd4_Flag',
                       'OE7_Test_MainSL1_Flag', 'OE8_Test_MainHIOrd1_Flag',
                       'OE8_Test_MainHIOrd2_Flag', 'OE8_Test_MainHIOrd3_Flag',
                       'OE8_Test_MainHIOrd4_Flag', 'OE9_Test_MainSL1_Flag',
                       'OE9_Test_MainHIOrd1_Flag', 'OE9_Test_MainHIOrd2_Flag',
                       'OE9_Test_MainHIOrd3_Flag', 'OE9_Test_MainHIOrd4_Flag',
                       'OE9_Test_LateClock_Flag', 'KPIF_SEP_EM_Flag_PY',
                       'KPIF_OE_DM_Flag', 'Email_Open_Flag_PY',
                       'PRIOR_MODEL_SCORE', 'Region', 'ST_CD', 'CNTY_NM',
                       'SVC_AREA_NM', 'CITY_NM', 'TAPESTRY_SEGMENT',
                       'TAPESTRY_LIFESTYLE', 'TAPESTRY_URBAN')

########################### FM OFF ###########################
FM_Off <- VariableSelection_Part1('T14_FM_Off_Sample', "ListColsDrop_FM_Off.rds", 
                                  Conv_Enroll_OffHIX_Flag ~ .)
## MANUAL - remove perfect multicollinearity ##
Log <- glm(Conv_Enroll_OffHIX_Flag ~ ., data = FM_Off, family = "binomial")
attributes(alias(Log)$Complete)$dimnames[[1]] # Enter variable names in list below
ExclusionList <- c("KBM_ADDR_VRFN_CD", "FMLY_POS_CD", "NIELSEN_COUNTY_SIZE_CD",
                   "DIGITAL_DEVICES_S9")
remove(Log)
finalcols <- VariableSelection_Part2(FM_Off, "ListColsDrop_FM_Off.rds", ExclusionList,
                                     Conv_Enroll_OffHIX_Flag ~ .)
print(finalcols)
remove(FM_Off)
remove(ExclusionList)
remove(finalcols)
gc()

########################### FM ON ###########################
FM_On <- VariableSelection_Part1('T15_FM_On_Sample', "ListColsDrop_FM_On.rds", 
                                 Conv_Enroll_OnHIX_Flag ~ .)
## MANUAL - remove perfect multicollinearity ##
Log <- glm(Conv_Enroll_OnHIX_Flag ~ ., data = FM_On, family = "binomial")
attributes(alias(Log)$Complete)$dimnames[[1]] # Enter variable names in list below
ExclusionList <- c("KBM_ADDR_VRFN_CD", "FMLY_POS_CD", "NIELSEN_COUNTY_SIZE_CD")
remove(Log)
finalcols <- VariableSelection_Part2(FM_On, "ListColsDrop_FM_On.rds", ExclusionList,
                                     Conv_Enroll_OnHIX_Flag ~ .)
print(finalcols)
remove(FM_On)
remove(ExclusionList)
remove(finalcols)
gc()

########################### RW OFF ###########################
RW_Off <- VariableSelection_Part1('T16_RW_Off_Sample', "ListColsDrop_RW_Off.rds", 
                                  Conv_Enroll_OffHIX_Flag ~ .)
## MANUAL - remove perfect multicollinearity ##
Log <- glm(Conv_Enroll_OffHIX_Flag ~ ., data = RW_Off, family = "binomial")
attributes(alias(Log)$Complete)$dimnames[[1]] # Enter variable names in list below
ExclusionList <- c("KBM_ADDR_VRFN_CD", "FMLY_POS_CD", "NIELSEN_COUNTY_SIZE_CD")
remove(Log)
gc()
finalcols <- VariableSelection_Part2(RW_Off, "ListColsDrop_RW_Off.rds", 
                                     ExclusionList, Conv_Enroll_OffHIX_Flag ~ .)
print(finalcols)
remove(RW_Off)
remove(ExclusionList)
remove(finalcols)
gc()

########################### RW ON ###########################
RW_On <- VariableSelection_Part1('T17_RW_On_Sample', "ListColsDrop_RW_On.rds", 
                                 Conv_Enroll_OnHIX_Flag ~ .)
## MANUAL - remove perfect multicollinearity ##
Log <- glm(Conv_Enroll_OnHIX_Flag ~ ., data = RW_On, family = "binomial")
attributes(alias(Log)$Complete)$dimnames[[1]] # Enter variable names in list below
ExclusionList <- c("KBM_ADDR_VRFN_CD", "FMLY_POS_CD", "NIELSEN_COUNTY_SIZE_CD")
remove(Log)
finalcols <- VariableSelection_Part2(RW_On, "ListColsDrop_RW_On.rds", 
                                     ExclusionList, Conv_Enroll_OnHIX_Flag ~ .)
print(finalcols)
remove(RW_On)
remove(ExclusionList)
remove(finalcols)

########################### Export ###########################

remove(CalcCorrExclList)
remove(CalcPCA)
remove(CalcRFImportance)
remove(VariableSelection_Part1)
remove(VariableSelection_Part2)
gc()

SaveFiles('RNC/WPL', 'ListColsDrop_RW_Off.rds', 'ListColsDrop_RW_On.rds',
          'Final Model Set RW Off HIX.csv', 'Final Model Set RW On HIX.csv')
SaveFiles('FM', 'ListColsDrop_FM_Off.rds', 'ListColsDrop_FM_On.rds',
          'Final Model Set FM Off HIX.csv', 'Final Model Set FM On HIX.csv')

