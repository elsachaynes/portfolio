###########################################################################
#                                                                         #
#                         Feature Selection                               #
#                                                                         #
###########################################################################
gc()
library(data.table)
library(dplyr)
library(janitor)
library(stringr)

## Import: Combine (Sample) DepVars and IndepVars
Dep.Vars <-data.table::fread(file='MED_DM_22_Targeting_DepVars_Final_Sample500k.csv',colClasses=c(AGLTY_INDIV_ID="character")) ## 2 seconds
Indep.Vars <-data.table::fread(file='MED_DM_22_Targeting_IndepVars_Final_Sample500k.csv',colClasses=c(AGLTY_INDIV_ID="character")) ## 30 seconds
Sample.Table <- setDF(setDT(Dep.Vars)[setDT(Indep.Vars),on=.(AGLTY_INDIV_ID,Campaign)])
  remove(Dep.Vars)
  remove(Indep.Vars)
  
# Remove RNC and FM records
RNC <-data.table::fread(file='MED_DM_22_Targeting_RNCs_EXCLUDE.csv',colClasses=c(AGLTY_INDIV_ID="character")) ## 2 seconds 
FM <-data.table::fread(file='MED_DM_22_Targeting_FM_EXCLUDE.csv',colClasses=c(AGLTY_INDIV_ID="character")) ## 2 seconds
Sample.Table.Clean <- Sample.Table %>% anti_join(RNC, Sample.Table, by="AGLTY_INDIV_ID") %>% as.data.frame
Sample.Table.Clean <- Sample.Table %>% anti_join(FM, Sample.Table.Clean, by="AGLTY_INDIV_ID") %>% as.data.frame
  remove(RNC)
  remove(FM)
  remove(Sample.Table)
  
# Remove FM variables
Sample.Table.Clean <- Sample.Table.Clean %>% dplyr::select(-SUBSCRIBER_FLAG,-MEDICAID_MBR_FLAG)
# Remove other variables
Sample.Table.Clean <- Sample.Table.Clean %>% dplyr::select(-AGLTY_INDIV_ID,-WEALTH_INDEX)

# Save a numeric version
Sample.Table.Clean.Num <- Sample.Table.Clean

# Set DV as numeric
ListDV <- c("CONV_ENROLL_90DAY_FLAG","CONV_ENROLL_120DAY_FLAG","CONV_RESP_30DAY_FLAG","CONV_RESP_60DAY_FLAG")
Sample.Table.Clean[ListDV] <- lapply(Sample.Table.Clean[ListDV], as.numeric)
  remove(ListDV)

# Set IV as factors
ListFactors.AD <- c("CARR_RTE_CD.ADDR","COUNTY_OOA","DWELL_TYPE_CD.ADDR","HOSP_FCLTY_ID","KP_Region",
                    "MOB_FCLTY_ID","REGN_CD","SUB_REGN_CD","SVC_AREA_NM")
ListFactors.PH <- c("TIMES_PROMOTED_AEP","TIMES_PROMOTED_SEP","PROMOTED_SEP_FLAG","LIST_SOURCE_EXPERIAN_FLAG","SEGMENT_LATINO_FLAG",
                    "SEP_LATINO_DM_FLAG","SEGMENT_UNRESPONSIVE_FLAG","AEP_DROP_1_FLAG","AEP_DROP_2_FLAG","AEP_DROP_3_FLAG","Campaign",
                    "AEP_DROP_4_FLAG","AEP_DROP_5_FLAG","AEP_DROP_6_FLAG","AEP_DROP_7_FLAG","AEP_DROP_8_FLAG","SEP_DROP_1_FLAG",
                    "SEP_DROP_2_FLAG","SEP_DROP_3_FLAG","SEP_DROP_4_FLAG","SEP_DROP_5_FLAG","SEP_DROP_6_FLAG","SEP_DROP_7_FLAG","SEP_DROP_8_FLAG",
                    "SEP_DROP_9_FLAG")
ListFactors.TAP <- c("TAPESTRY_LIFESTYLE","TAPESTRY_SEGMENT","TAPESTRY_SEGMENT_CD","TAPESTRY_URBAN")
ListFactors.KBM <- c("ADDR_VRFN_CD","AGE_RNG_CD","BANK_CARD_CD","CARR_RTE_CD.KBM","CENS_BLOCK_GRP_CD",
                     "CENS_EDU_LVL_CD","CENS_INFO_LVL_CD","CENS_TRACT_NBR","CENS_TRACT_SUB_CD","CRDT_ACTV_IND",
                     "DGTL_INVMNT_CD","DGTL_SEG_CD","DMA_CD","DONOR_CD","DWELL_TYPE_CD.KBM","EST_HH_INCM_CD",
                     "ETHN_CD","FINC_SVCS_BNKG_IND","FINC_SVCS_INSR_IND","FINC_SVCS_INSTL_IND","FMLY_POS_CD",
                     "GNDR_CD","HH_LVL_MATCH_IND","HH_ONLN_IND","HLTH_INSR_RSPDR_CD","HMOWN_STAT_CD","HOME_IMPMNT_IND",
                     "HOME_OFC_SUPPLY_IND","HOME_PHN_NBR","HOUSE_VAL_CD","IMAGE_MAIL_ORD_BYR_CD","INDIV_LVL_MATCH_IND",
                     "KBM_Flag","LEN_RES_CD","LIST_SOURCE_EXPERIAN_FLAG","LOW_END_DEPT_STOR_IND","MAIL_ORD_RSPDR_CD",
                     "MAIN_STR_RTL_IND","MARRIED_IND","MISC_IND","NIELSEN_CNTY_SZ_CD","OCCU_CD","OCCU2_CD","OIL_CO_IND",
                     "ONE_PER_ADDR_IND","OWN_RENT_CD","PC_IND","PC_OWN_IND","PRSN_CHILD_IND","PRSN_ELDER_IND","PUBL_HOUSING_IND",
                     "RTL_CARD_IND","SCORE_1","SCORE_2","SCORE_3","SCORE_4","SCORE_5","SCORE_6","SCORE_9",
                     "SCORE_10","SEASNL_ADDR_IND","SOHO_HH_IND","SOHO_INDIV_IND","SPLTY_APRL_IND","SPLTY_IND","SPORT_GOODS_IND",
                     "SPOUSE_OCCU_CD","SRC_CD","ST_CD","STD_RTL_IND","TRVL_PERSNL_SVCS_IND","TV_MAIL_ORD_IND","UNIT_NBR_PRSN_IND",
                     "UPSCL_RTL_IND","WHSE_MBR_IND")
Sample.Table.Clean[ListFactors.PH] <- lapply(Sample.Table.Clean[ListFactors.PH], as.factor)
Sample.Table.Clean[ListFactors.TAP] <- lapply(Sample.Table.Clean[ListFactors.TAP], as.factor)
Sample.Table.Clean[ListFactors.KBM] <- lapply(Sample.Table.Clean[ListFactors.KBM], as.factor)
Sample.Table.Clean[ListFactors.AD] <- lapply(Sample.Table.Clean[ListFactors.AD], as.factor)
  remove(ListFactors.AD)
  remove(ListFactors.KBM)
  remove(ListFactors.PH)
  remove(ListFactors.TAP)

## One table per DV
Sample.Table.30 <- Sample.Table.Clean %>% dplyr::select(-CONV_RESP_60DAY_FLAG,-CONV_ENROLL_90DAY_FLAG,-CONV_ENROLL_120DAY_FLAG)
Sample.Table.60 <- Sample.Table.Clean %>% dplyr::select(-CONV_RESP_30DAY_FLAG,-CONV_ENROLL_90DAY_FLAG,-CONV_ENROLL_120DAY_FLAG)
Sample.Table.90 <- Sample.Table.Clean %>% dplyr::select(-CONV_RESP_30DAY_FLAG,-CONV_RESP_60DAY_FLAG,-CONV_ENROLL_120DAY_FLAG)
Sample.Table.120 <- Sample.Table.Clean %>% dplyr::select(-CONV_RESP_30DAY_FLAG,-CONV_RESP_60DAY_FLAG,-CONV_ENROLL_90DAY_FLAG)
  
## WOE / IV -- remove variables with IV < 0.02 or >0.5
library(Information)

compute.WOE <- function(DV){
 
  split<-str_split(DV, "_")
  WindowDays <- str_replace(sapply(split, `[`, 3),"DAY","")
  raw_data <- get(paste0('Sample.Table.', WindowDays))
  df_name <- paste0('IV_Value.', WindowDays)
  
  IV <- create_infotables(data=raw_data, y=DV, bins=10, parallel=FALSE)
  temp1 <- as.data.frame(IV$Summary)
  assign(df_name, temp1, envir=.GlobalEnv)
}

compute.WOE("CONV_RESP_30DAY_FLAG")
write.table(IV_Value.30, "clipboard", sep="\t")
compute.WOE("CONV_RESP_60DAY_FLAG")
write.table(IV_Value.60, "clipboard", sep="\t")
compute.WOE("CONV_ENROLL_90DAY_FLAG")
write.table(IV_Value.90, "clipboard", sep="\t")
compute.WOE("CONV_ENROLL_120DAY_FLAG")
write.table(IV_Value.120, "clipboard", sep="\t")

  remove(raw_data)
  remove(IV)
  remove(split)
  remove(temp1)
  remove(df_name)
  remove(DV)
  remove(WindowDays)
  
## PCA
library(factoextra)
  
Sample.Table.Clean.Num <- Sample.Table.Clean.Num[,unlist(lapply(Sample.Table.Clean.Num, is.numeric))]
PCA <- prcomp(Sample.Table.Clean.Num, center = TRUE, scale = TRUE)
fviz_eig(PCA)
cap<-5 #choose the number of dimensions
res.var <- get_pca_var(PCA) # Contribution in % towards components
contrib <- as.data.frame(res.var$contrib[,1:4])
write.table(contrib, "clipboard", sep="\t")
contrib <- as.data.frame(res.var$contrib[,5])
write.table(contrib, "clipboard", sep="\t")

# Clear up some space by removing the least predictive variables (listed by least to more predictive)
to.remove <- c("SEASNL_ADDR_IND",
               "COUNTY_OOA",
               "POP_ISLANDER_65_69",
               "SPLTY_IND",
               "POP_ISLANDER_60_64",
               "PC_IND",
               "TV_MAIL_ORD_IND",
               "WHSE_MBR_IND",
               "FINC_SVCS_INSTL_IND",
               "POP_ISLANDER_60_64_FY",
               "SPORT_GOODS_IND",
               "OIL_CO_IND",
               "SOHO_HH_IND",
               "UPSCL_RTL_IND",
               "PUBL_HOUSING_IND",
               "FINC_SVCS_BNKG_IND",
               "MARRIED_IND",
               "LOW_END_DEPT_STOR_IND",
               "POP_ISLANDER_65_69_FY",
               "MISC_IND",
               "HOME_PHN_NBR",
               "STD_RTL_IND",
               "MAIN_STR_RTL_IND",
               "HOME_IMPMNT_IND",
               "DONOR_CD",
               "CENS_MOBL_HOME_PCT",
               "CRDT_ACTV_IND",
               "SPLTY_APRL_IND",
               "TRVL_PERSNL_SVCS_IND",
               "FINC_SVCS_INSR_IND",
               "PC_OWN_IND",
               "SOHO_INDIV_IND",
               "AEP_DROP_5_FLAG",
               "HLTH_INSR_RSPDR_CD",
               "MEDIAN_BLACK_AGE_FY",
               "MEDIAN_ISLANDER_MALE_AGE_FY",
               "HOME_OFC_SUPPLY_IND",
               "MEDIAN_ISLANDER_AGE",
               "POP_PACIFIC",
               "MEDIAN_ISLANDER_MALE_AGE",
               "POP_PACIFIC_FY",
               "HH_INCOME_50_75k",
               "MEDIAN_BLACK_MALE_AGE",
               "MEDIAN_ISLANDER_AGE_FY",
               "INDIV_LVL_MATCH_IND",
               "HH_LVL_MATCH_IND",
               "MEDIAN_BLACK_FEMALE_AGE_FY",
               "POP_ASIAN_65_69_FY",
               "EDUC_SOME_COLLEGE",
               "POP_ASIAN_65_69",
               "MEDIAN_ISLANDER_FEMALE_AGE",
               "PRSN_ELDER_IND",
               "POP_DIVORCED",
               "POP_GROUP_LIVING",
               "POP_GROUP_LIVING_FY",
               "HH_INCOME_50_75k_FY",
               "POP_WIDOWED",
               "MEDIAN_BLACK_FEMALE_AGE",
               "MEDIAN_ISLANDER_FEMALE_AGE_FY",
               "MEDIAN_HISP_FEMALE_AGE_FY",
               "MEDIAN_HH_INCOME_GRWTH_RT",
               "MEDIAN_ASIAN_AGE_FY",
               "MEDIAN_BLACK_AGE",
               "MEDIAN_ASIAN_AGE",
               "HOUSE_VAL_CD",
               "MEDIAN_BLACK_MALE_AGE_FY",
               "MEDIAN_HISP_FEMALE_AGE",
               "POP_TOTAL",
               "POS_Supplemental",
               "DWELL_TYPE_CD.ADDR",
               "MEDIAN_ASIAN_MALE_AGE_FY",
               "HH_INCOME_25_35k",
               "MEDIAN_HISP_AGE_FY",
               "AEP_DROP_8_FLAG",
               "EDUC_GED",
               "RTL_CARD_IND",
               "MEDIAN_ASIAN_MALE_AGE",
               "SPOUSE_OCCU_CD",
               "POP_IN_LABOR_FORCE",
               "PCT_OF_INCOME_MORTGAGE",
               "POP_NEVER_MARRIED",
               "POP_UNEMPLOYED",
               "MEDIAN_ASIAN_FEMALE_AGE",
               "MEDIAN_ASIAN_FEMALE_AGE_FY",
               "HH_ONLN_IND",
               "HH_ADULTS_CNT",
               "HH_INCOME_15_25k",
               "MEDIAN_HISP_AGE",
               "PER_CAPITA_INCOME_GRWTH_RT",
               "POP_EMPLOYED",
               "OWNER_OCCUPIED_GRWTH_RT",
               "HH_INCOME_75_100k_FY",
               "HH_INCOME_35_50k")
`%ni%` <- Negate(`%in%`)
Sample.Table.Clean <- subset(Sample.Table.Clean,select = names(Sample.Table.Clean) %ni% to.remove)

  # refresh
  Sample.Table.30 <- Sample.Table.Clean %>% dplyr::select(-CONV_RESP_60DAY_FLAG,-CONV_ENROLL_90DAY_FLAG,-CONV_ENROLL_120DAY_FLAG)
  Sample.Table.60 <- Sample.Table.Clean %>% dplyr::select(-CONV_RESP_30DAY_FLAG,-CONV_ENROLL_90DAY_FLAG,-CONV_ENROLL_120DAY_FLAG)
  Sample.Table.90 <- Sample.Table.Clean %>% dplyr::select(-CONV_RESP_30DAY_FLAG,-CONV_RESP_60DAY_FLAG,-CONV_ENROLL_120DAY_FLAG)
  Sample.Table.120 <- Sample.Table.Clean %>% dplyr::select(-CONV_RESP_30DAY_FLAG,-CONV_RESP_60DAY_FLAG,-CONV_ENROLL_90DAY_FLAG)

  remove(Sample.Table.30)
  remove(Sample.Table.90)
  remove(Sample.Table.120)
  
## Correlation matrix (to remove multicollinearity)
  library(caret)
  Sample.Table.Clean.Num <- Sample.Table.Clean[,unlist(lapply(Sample.Table.Clean, is.numeric))]
  cor <- cor(Sample.Table.Clean.Num)
  cor.table <- as.data.table(cor)
  fwrite(cor.table,file='MED_DM_22_Targeting_CORR.csv')
  #print(cor)
  highlyCorrelated <- findCorrelation(cor, cutoff=0.5) # find attributes that are highly corrected (ideally >0.75)
  # In batches: 1-20
  highlyCorrelated1 <- highlyCorrelated[1:20]
  corrplot:corrplot(cor(Sample.Table.Clean.Num[highlyCorrelated1]))
  cor(Sample.Table.Clean.Num[highlyCorrelated1[c(1,8,11,13)]]) #kept: verify
  ListRemove1 <- names(Sample.Table.Clean.Num[highlyCorrelated1[-c(1,8,11,13)]]) #removed
  # In batches: 21-40
  highlyCorrelated1 <- highlyCorrelated[21:40]
  corrplot:corrplot(cor(Sample.Table.Clean.Num[highlyCorrelated1]))
  cor(Sample.Table.Clean.Num[highlyCorrelated1[c(3,9,14,19)]]) #kept: verify
  ListRemove2 <- names(Sample.Table.Clean.Num[highlyCorrelated1[-c(3,9,14,19)]]) #removed
  # In batches: 41-60
  highlyCorrelated1 <- highlyCorrelated[41:60]
  corrplot:corrplot(cor(Sample.Table.Clean.Num[highlyCorrelated1]))
  corrplot(cor(Sample.Table.Clean.Num[highlyCorrelated1[c(4,6,14,16)]])) #kept: verify
  ListRemove3 <- names(Sample.Table.Clean.Num[highlyCorrelated1[-c(4,6,14,16)]]) #removed
  # In batches: 61-80
  highlyCorrelated1 <- highlyCorrelated[61:80]
  corrplot:corrplot(cor(Sample.Table.Clean.Num[highlyCorrelated1]))
  corrplot(cor(Sample.Table.Clean.Num[highlyCorrelated1[c(1,2,3,6,9,12,13)]])) #kept: verify
  ListRemove4 <- names(Sample.Table.Clean.Num[highlyCorrelated1[-c(1,2,3,6,9,12,13)]]) #removed
  # In batches: 81-100
  highlyCorrelated1 <- highlyCorrelated[81:100]
  corrplot:corrplot(cor(Sample.Table.Clean.Num[highlyCorrelated1]))
  corrplot(cor(Sample.Table.Clean.Num[highlyCorrelated1[c(4,8,13,20)]])) #kept: verify
  ListRemove5 <- names(Sample.Table.Clean.Num[highlyCorrelated1[-c(4,8,13,20)]]) #removed
  # In batches: 101-120
  highlyCorrelated1 <- highlyCorrelated[101:120]
  corrplot:corrplot(cor(Sample.Table.Clean.Num[highlyCorrelated1]))
  corrplot(cor(Sample.Table.Clean.Num[highlyCorrelated1[c(1,3,5,8,9,13,20)]])) #kept: verify
  ListRemove6 <- names(Sample.Table.Clean.Num[highlyCorrelated1[-c(1,3,5,8,9,13,20)]]) #removed  
  # In batches: 121-140
  highlyCorrelated1 <- highlyCorrelated[121:140]
  corrplot:corrplot(cor(Sample.Table.Clean.Num[highlyCorrelated1]))
  corrplot(cor(Sample.Table.Clean.Num[highlyCorrelated1[c(3,6,12,14,15,17,19)]])) #kept: verify
  ListRemove7 <- names(Sample.Table.Clean.Num[highlyCorrelated1[-c(3,6,12,14,15,17,19)]]) #removed  
  # In batches: 141-156
  highlyCorrelated1 <- highlyCorrelated[141:156]
  corrplot:corrplot(cor(Sample.Table.Clean.Num[highlyCorrelated1]))
  corrplot(cor(Sample.Table.Clean.Num[highlyCorrelated1[c(2,3,4,6,7,8,10,12,14:16)]])) #kept: verify
  ListRemove8 <- names(Sample.Table.Clean.Num[highlyCorrelated1[-c(2,3,4,6,7,8,10,12,14:16)]]) #removed 
  # Remove variables causing multicollinearity
  to.remove <- c(ListRemove1,ListRemove2,ListRemove3,ListRemove4,ListRemove5,ListRemove6,ListRemove7,ListRemove8)
    remove(ListRemove1)
    remove(ListRemove2)
    remove(ListRemove3)
    remove(ListRemove4)
    remove(ListRemove5)
    remove(ListRemove6)
    remove(ListRemove7)
    remove(ListRemove8)
  Sample.Table.Clean <- subset(Sample.Table.Clean,select = names(Sample.Table.Clean) %ni% to.remove)
  # Re-check multicollinearity with reduced set
  Sample.Table.Clean.Num <- Sample.Table.Clean[,unlist(lapply(Sample.Table.Clean, is.numeric))]
  cor <- cor(Sample.Table.Clean.Num)
  highlyCorrelated <- findCorrelation(cor, cutoff=0.5)
  # In batches: 1-15
  highlyCorrelated1 <- highlyCorrelated[1:15]
  corrplot(cor(Sample.Table.Clean.Num[highlyCorrelated1]))
  corrplot(cor(Sample.Table.Clean.Num[highlyCorrelated1[c(4,10,12,14)]])) #kept: verify
  ListRemove1.1 <- names(Sample.Table.Clean.Num[highlyCorrelated1[-c(4,10,12,14)]]) #removed 
  # In batches: 16-30
  highlyCorrelated1 <- highlyCorrelated[16:30]
  corrplot(cor(Sample.Table.Clean.Num[highlyCorrelated1]))
  corrplot(cor(Sample.Table.Clean.Num[highlyCorrelated1[c(1,2,3,6:15)]])) #kept: verify
  ListRemove1.2 <- names(Sample.Table.Clean.Num[highlyCorrelated1[-c(1,2,3,6:15)]]) #removed 
  # In batches: 31-48
  highlyCorrelated1 <- highlyCorrelated[31:48]
  corrplot(cor(Sample.Table.Clean.Num[highlyCorrelated1]))
  corrplot(cor(Sample.Table.Clean.Num[highlyCorrelated1[c(1,2,4,5,7,8,10,12:18)]])) #kept: verify
  ListRemove1.3 <- names(Sample.Table.Clean.Num[highlyCorrelated1[-c(1,2,4,5,7,8,10,12:18)]]) #removed 
  to.remove <- c(ListRemove1.1,ListRemove1.2,ListRemove1.3)
    remove(ListRemove1.1)
    remove(ListRemove1.2)
    remove(ListRemove1.3)
  Sample.Table.Clean <- subset(Sample.Table.Clean,select = names(Sample.Table.Clean) %ni% to.remove)
  # Re-check multicollinearity with reduced set
  Sample.Table.Clean.Num <- Sample.Table.Clean[,unlist(lapply(Sample.Table.Clean, is.numeric))]
  cor <- cor(Sample.Table.Clean.Num)
  highlyCorrelated <- findCorrelation(cor, cutoff=0.6)
  corrplot(cor(Sample.Table.Clean.Num[highlyCorrelated]))
    remove(cor)
    remove(cor.table)
    remove(highlyCorrelated)
    remove(highlyCorrelated1)
    
  # Other removals
  Sample.Table.Clean <- Sample.Table.Clean %>% dplyr::select(-POP_ASIAN)
  Sample.Table.Clean <- Sample.Table.Clean %>% dplyr::select(-POP_PER_SQ_MILE,-HH_INCOME_200k_FY,-MEDIAN_WHITE_FEMALE_AGE_FY)

## VIF/Multicollinearity for character variables using Logistic forward selection
library(MASS)
library(car)
# Character-only
Sample.Table.60 <- Sample.Table.Clean %>% dplyr::select(-CONV_RESP_30DAY_FLAG,-CONV_ENROLL_90DAY_FLAG,-CONV_ENROLL_120DAY_FLAG)
Sample.Table.Log <- Sample.Table.60
#Sample.Table.Log$CONV_RESP_60DAY_FLAG <- Sample.Table.60$CONV_RESP_60DAY_FLAG
remove(Log.60)
Log.60 <- glm(CONV_RESP_60DAY_FLAG ~ ., data = Sample.Table.Log, family = "binomial") %>% stepAIC(direction="forward")
summary(Log.60)
vif(Log.60)
# re-bin hawaii
Sample.Table.Clean$SUB_REGN_CD <- ifelse(Sample.Table.Clean$SUB_REGN_CD==c("HI","HIHA","HIHO","HIMA"),"HI",Sample.Table.Clean$SUB_REGN_CD)
# times_promoted_aep should be numeric
Sample.Table.Clean$TIMES_PROMOTED_AEP <- as.numeric(Sample.Table.Clean$TIMES_PROMOTED_AEP)
# Length of residency should be numeric
Sample.Table.Clean$LEN_RES_CD <- as.numeric(Sample.Table.Clean$LEN_RES_CD)
Sample.Table.Clean$LEN_RES_CD <- ifelse(Sample.Table.Clean$LEN_RES_CD==99,NA,Sample.Table.Clean$LEN_RES_CD)
Sample.Table.Clean$LEN_RES_CD <- ifelse(is.na(Sample.Table.Clean$LEN_RES_CD),median(Sample.Table.Clean$LEN_RES_CD,na.rm=T),Sample.Table.Clean$LEN_RES_CD)
# Score_4, Score_6, Score_9, Score_10 should be numeric
Sample.Table.Clean$SCORE_4 <- as.numeric(Sample.Table.Clean$SCORE_4)
Sample.Table.Clean$SCORE_4 <- ifelse(is.na(Sample.Table.Clean$SCORE_4),median(Sample.Table.Clean$SCORE_4,na.rm=T),Sample.Table.Clean$SCORE_4)
tabyl(Sample.Table.Clean$SCORE_4)
Sample.Table.Clean$SCORE_6 <- ifelse(Sample.Table.Clean$SCORE_6=="U",NA,Sample.Table.Clean$SCORE_4)
Sample.Table.Clean$SCORE_6 <- as.numeric(Sample.Table.Clean$SCORE_6)
Sample.Table.Clean$SCORE_6 <- ifelse(is.na(Sample.Table.Clean$SCORE_6),median(Sample.Table.Clean$SCORE_6,na.rm=T),Sample.Table.Clean$SCORE_6)
tabyl(Sample.Table.Clean$SCORE_6)
Sample.Table.Clean$SCORE_9 <- ifelse(Sample.Table.Clean$SCORE_9==99,NA,Sample.Table.Clean$SCORE_9)
Sample.Table.Clean$SCORE_9 <- as.numeric(Sample.Table.Clean$SCORE_9)
Sample.Table.Clean$SCORE_9 <- ifelse(is.na(Sample.Table.Clean$SCORE_9),median(Sample.Table.Clean$SCORE_9,na.rm=T),Sample.Table.Clean$SCORE_9)
tabyl(Sample.Table.Clean$SCORE_9)
Sample.Table.Clean$SCORE_10 <- ifelse(Sample.Table.Clean$SCORE_10==99,NA,Sample.Table.Clean$SCORE_10)
Sample.Table.Clean$SCORE_10 <- as.numeric(Sample.Table.Clean$SCORE_10)
Sample.Table.Clean$SCORE_10 <- ifelse(is.na(Sample.Table.Clean$SCORE_10),median(Sample.Table.Clean$SCORE_10,na.rm=T),Sample.Table.Clean$SCORE_10)
tabyl(Sample.Table.Clean$SCORE_10)
# bin tapestry segments
library(tidyr)
Sample.Table.Clean$TAPESTRY_SEGMENT_CD <- readr::parse_number(as.character(Sample.Table.Clean$TAPESTRY_SEGMENT_CD))
Sample.Table.Clean$TAPESTRY_SEGMENT_CD <- as.factor(Sample.Table.Clean$TAPESTRY_SEGMENT_CD)

# Other removals
Sample.Table.Clean <- Sample.Table.Clean %>% dplyr::select(-POP_PER_SQ_MILE,-HH_INCOME_200k_FY,-MEDIAN_WHITE_FEMALE_AGE_FY,
                                                           -POP_ASIAN_FY,-OWNER_OCCUPIED_UNITS,-TIMES_PROMOTED_SEP,
                                                           -AEP_DROP_1_FLAG,-AEP_DROP_2_FLAG,-AEP_DROP_6_FLAG,-AEP_DROP_7_FLAG,
                                                           -TAPESTRY_SEGMENT,-TAPESTRY_LIFESTYLE,-MOB_FCLTY_ID,-KP_Region,
                                                           -HOSP_FCLTY_ID,-ST_CD,-CARR_RTE_CD.ADDR,-SRC_CD,-REGN_CD,
                                                           -CENS_TRACT_SUB_CD,-AGE_RNG_CD,-TAPESTRY_URBAN,-CENS_TRACT_NBR,
                                                           -SVC_AREA_NM,-CARR_RTE_CD.KBM,-CENS_BLOCK_GRP_CD,-CENS_INFO_LVL_CD,-BANK_CARD_CD,
                                                           -DGTL_SEG_CD,-DMA_CD,-DWELL_TYPE_CD.KBM,-FMLY_POS_CD,-OWN_RENT_CD,
                                                           -NIELSEN_CNTY_SZ_CD,-OCCU2_CD,-GNDR_CD,-ETHN_CD,-DGTL_INVMNT_CD,
                                                           -SCORE_2,-SCORE_3,-SCORE_5,-EST_HH_INCM_CD)
## remove based on PCA
to.remove <- c("CENS_BLACK_PCT",
                "CENS_AVG_AUTO_CNT",
                "CENS_EDU_LVL_CD",
                "DLVR_PT_CD",
                "POP_BLACK_60_64_FY",
                "HOUSEHOLDS_INCOME_AGE_75up_FY",
                "MOB_DIST_MSR",
                "MEDIAN_HOME_VALUE",
                "POP_CMPD_ANNUAL_GRWTH_RT",
                "POP_65_up_DEP_RATIO",
                "POP_ASIAN_FY",
                "RENTER_OCCUPIED_UNITS",
                "ZIP_LVL_INCM_DCL_CD",
                "MA_Eligibles",
                "POP_ASIAN_60_64",
                "AEP_DROP_3_FLAG",
                "AEP_DROP_6_FLAG",
                "AEP_DROP_4_FLAG")
Sample.Table.Clean <- subset(Sample.Table.Clean,select = names(Sample.Table.Clean) %ni% to.remove)

  remove(Log.60)
  remove(Sample.Table.60)
  remove(Sample.Table.Log)

# Variable list
to.keep <- names(Sample.Table.Clean)
to.keep <- as.data.frame(to.keep)
write.table(to.keep, "clipboard", sep="\t") # add to documentation

############################ REDUCE VARIABLE SET ############################################
## Import: Combine (Sample) DepVars and IndepVars (FINAL)
Dep.Vars <-data.table::fread(file='MED_DM_22_Targeting_DepVars_Final.csv',colClasses=c(AGLTY_INDIV_ID="character")) ## 2 seconds
Indep.Vars <-data.table::fread(file='MED_DM_22_Targeting_IndepVars_Final.csv',colClasses=c(AGLTY_INDIV_ID="character")) ## 30 seconds
Final.Table <- setDF(setDT(Dep.Vars)[setDT(Indep.Vars),on=.(AGLTY_INDIV_ID,Campaign)])
  remove(Dep.Vars)
  remove(Indep.Vars)

# Remove RNC and FM records
RNC <-data.table::fread(file='MED_DM_22_Targeting_RNCs_EXCLUDE.csv',colClasses=c(AGLTY_INDIV_ID="character")) ## 2 seconds 
FM <-data.table::fread(file='MED_DM_22_Targeting_FM_EXCLUDE.csv',colClasses=c(AGLTY_INDIV_ID="character")) ## 2 seconds
Final.Table.Clean <- Final.Table %>% anti_join(RNC, Final.Table, by="AGLTY_INDIV_ID") %>% as.data.frame
Final.Table.Clean <- Final.Table %>% anti_join(FM, Final.Table.Clean, by="AGLTY_INDIV_ID") %>% as.data.frame
  remove(RNC)
  remove(FM)
  remove(Final.Table)
to.keep <- append(to.keep,"AGLTY_INDIV_ID")
Final.Table.Clean <- subset(Final.Table.Clean,select = names(Final.Table.Clean) %in% to.keep)
data.table::fwrite(Final.Table.Clean,file='MED_DM_22_Targeting_Final.csv') #save

## Append _Tapestry
library(odbc)
library(RODBC)
con <- dbConnect(odbc::odbc(), "WS_EHAYNES") # To navigate the SQL Server schemas
connection <- odbcConnect("WS_EHAYNES") # To pull data from SQL Server
Tapestry <- sqlQuery(connection, "select * from MED_DM_22_Targeting_Tapestry")
Tapestry$AGLTY_INDIV_ID <- as.character(Tapestry$AGLTY_INDIV_ID) 
Tapestry <- subset(Tapestry,select = names(Tapestry) %in% to.keep)
odbcCloseAll()
dbDisconnect(con)

## Join
Final.Table.Complete <- setDF(setDT(Tapestry)[setDT(Final.Table.Clean),on=.(AGLTY_INDIV_ID)]) 
remove(Tapestry)
remove(Final.Table.Clean)
Final.Table.Complete <- Final.Table.Complete %>% dplyr::select(-AGLTY_INDIV_ID)
data.table::fwrite(Final.Table.Complete,file='MED_DM_22_Targeting_Final.csv') #save

## Cleaning - fill missing with median
replaceWithMedian <- function(var){
  var <- ifelse(is.na(var),median(var,na.rm=T),var)
}
listNumeric <- unlist(lapply(Final.Table.Complete, is.numeric))  
Final.Table.Complete[listNumeric] <- lapply(Final.Table.Complete[listNumeric],replaceWithMedian)

# re-bin hawaii
tabyl(Final.Table.Complete$SUB_REGN_CD)
Final.Table.Complete$SUB_REGN_CD <- ifelse(Final.Table.Complete$SUB_REGN_CD %in% c("HI","HIHA","HIHO","HIMA"),"HI",Final.Table.Complete$SUB_REGN_CD)
# times_promoted_aep should be numeric and capped at 8
tabyl(Final.Table.Complete$TIMES_PROMOTED_AEP)
Final.Table.Complete$TIMES_PROMOTED_AEP <- ifelse(Final.Table.Complete$TIMES_PROMOTED_AEP>=8,8,Final.Table.Complete$TIMES_PROMOTED_AEP)
# Length of residency should be numeric
Final.Table.Complete$LEN_RES_CD <- as.numeric(Final.Table.Complete$LEN_RES_CD)
Final.Table.Complete$LEN_RES_CD <- ifelse(Final.Table.Complete$LEN_RES_CD==99,NA,Final.Table.Complete$LEN_RES_CD)
Final.Table.Complete$LEN_RES_CD <- ifelse(is.na(Final.Table.Complete$LEN_RES_CD),median(Final.Table.Complete$LEN_RES_CD,na.rm=T),Final.Table.Complete$LEN_RES_CD)
# Score_4, Score_6, Score_9, Score_10 should be numeric
tabyl(Final.Table.Complete$SCORE_6)
Final.Table.Complete$SCORE_6 <- ifelse(Final.Table.Complete$SCORE_6=="U",NA,Final.Table.Complete$SCORE_6)
Final.Table.Complete$SCORE_6 <- as.numeric(Final.Table.Complete$SCORE_6)
Final.Table.Complete$SCORE_6 <- ifelse(is.na(Final.Table.Complete$SCORE_6),median(Final.Table.Complete$SCORE_6,na.rm=T),Final.Table.Complete$SCORE_6)
tabyl(Final.Table.Complete$SCORE_9)
Final.Table.Complete$SCORE_9 <- ifelse(Final.Table.Complete$SCORE_9==99,NA,Final.Table.Complete$SCORE_9)
Final.Table.Complete$SCORE_9 <- ifelse(is.na(Final.Table.Complete$SCORE_9),median(Final.Table.Complete$SCORE_9,na.rm=T),Final.Table.Complete$SCORE_9)
tabyl(Final.Table.Complete$SCORE_10)
Final.Table.Complete$SCORE_10 <- ifelse(Final.Table.Complete$SCORE_10==99,NA,Final.Table.Complete$SCORE_10)
Final.Table.Complete$SCORE_10 <- ifelse(is.na(Final.Table.Complete$SCORE_10),median(Final.Table.Complete$SCORE_10,na.rm=T),Final.Table.Complete$SCORE_10)

# bin tapestry segments
tabyl(Final.Table.Complete$TAPESTRY_SEGMENT_CD)
Final.Table.Complete$TAPESTRY_SEGMENT_CD <- readr::parse_number(as.character(Final.Table.Complete$TAPESTRY_SEGMENT_CD))
Final.Table.Complete$TAPESTRY_SEGMENT_CD <- ifelse(is.na(Final.Table.Complete$TAPESTRY_SEGMENT_CD),"U",Final.Table.Complete$TAPESTRY_SEGMENT_CD)

## Export
data.table::fwrite(Final.Table.Complete,file='MED_DM_22_Targeting_Final.csv') #save
remove(Sample.Complete)