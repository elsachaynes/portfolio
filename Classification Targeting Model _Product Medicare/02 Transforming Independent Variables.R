## NOTES: I created an ODBC connection "WS_EHAYNES" on my computer

library(odbc)
library(RODBC)
library(dplyr)
library(data.table)
library(janitor)
library(purrr)

## To navigate the SQL Server schemas
con <- dbConnect(odbc::odbc(), "WS_EHAYNES")
## To pull data from SQL Server
connection <- odbcConnect("WS_EHAYNES")

## For each project table in WS_EHAYNES (MED_DM_22_Targeting).
##     Roll up to one row per AGLTY_INDIV_ID.

## Join to InHomeDate
raw_InHomeDate<-data.table::fread(file='MED_DM_22_Targeting_PH_IH.csv',colClasses=c(AGLTY_INDIV_ID="character")) ## 30 seconds
raw_InHomeDate$Inhome_Date <- as.Date(raw_InHomeDate$Inhome_Date)
IDs <- unique(raw_InHomeDate,by=c("AGLTY_INDIV_ID","Campaign")) %>% select(AGLTY_INDIV_ID,Campaign)
remove(raw_InHomeDate)









### --------- NEXT SET OF RAW DATA --------- ###







#_KBM
raw_KBM <- sqlQuery(connection, "select * from MED_DM_22_Targeting_KBM")
raw_KBM$AGLTY_INDIV_ID <- as.character(raw_KBM$AGLTY_INDIV_ID) 
KBM <- raw_KBM %>% select(-AGLTY_INDIV_ID_CHAR,-SRC_FILE_ID,-FILE_REC_NBR,-MID_INIT_TXT,-CITY_NM,-ZIP_CD,-ZIP4_CD,
                          -REC_EFFV_DT,-BANK_CARD_ISSUE_DT,-BIRTH_DT,-BLOCK_SUFX_CD,-CENS_FMLY_LIFE_CD,
                          -CRDT_ACTVY_LAST_DT,-DPV_STAT_CD,-DRIVE_RSTCT_CD,-EMAIL_ADDR_IND,
                          -FIPS_CNTY_CD,-FIPS_ST_CD,-KBM_HH_NBR,-HOME_PHONE_NBR_PBLSH_DT,
                          -KBM_1_INDIV_ID,-KBM_2_INDIV_ID,-CARR_RTE_SORT_NBR,-MAILBL_REC_IND,
                          -MAIL_ORD_INSR_RSPDR_IND,-KBM_SRC_CNT,-PREM_BANK_CARD_IND,-VCNT_ADDR_IND,
                          -REC_INS_DT,-GENS_CD,-EXPD_IND,-EXPD_DT,-REC_UPDT_DT,-CAT_SHOWROOM_IND,
                          -GROCERY_IND,-FURNITURE_IND,
                          #too many levels
                          -CENS_STATS_AREA_CD)
  # Cleaning
  attach(KBM)
  KBM$AGE_RNG_CD <- ifelse(is.na(KBM$AGE_RNG_CD),"U",KBM$AGE_RNG_CD) #fill missing
  KBM$HOME_PHN_NBR <- ifelse(is.na(KBM$HOME_PHN_NBR),0,1) #bin
  KBM$CARR_RTE_CD <- substr(CARR_RTE_CD,1,1) #reduce number of factors
  KBM$CENS_TRACT_SUB_CD <- as.character(round(as.integer(CENS_TRACT_SUB_CD)/10))
  KBM$CENS_TRACT_NBR <- as.character(round(as.integer(CENS_TRACT_NBR)/100))
  KBM$HLTH_INSR_RSPDR_CD <- ifelse(is.na(HLTH_INSR_RSPDR_CD),0,1)
  KBM$HOUSE_VAL_CD <- round(as.integer(HOUSE_VAL_CD)/1000)
  KBM$OCCU_CD <- substr(OCCU_CD,1,1)
  KBM$OCCU_CD <- ifelse(is.na(KBM$OCCU_CD),"U",KBM$OCCU_CD)
  KBM$OCCU2_CD <- as.character(OCCU2_CD)
  KBM$SPOUSE_OCCU_CD <- substr(SPOUSE_OCCU_CD,1,1)
  KBM$SPOUSE_OCCU_CD <- ifelse(is.na(KBM$SPOUSE_OCCU_CD),"U",KBM$SPOUSE_OCCU_CD)
  KBM$SCORE_1 <- substr(SCORE_1,1,1)
  KBM$SCORE_3 <- substr(SCORE_3,1,1)
  KBM$SCORE_5 <- as.character(SCORE_5)
  KBM$SCORE_6 <- ifelse(is.na(SCORE_6),"U",SCORE_6)
  KBM$KBM_Flag <- 1
  KBM$CENS_BLOCK_GRP_CD <- as.character(CENS_BLOCK_GRP_CD)
  KBM$DMA_CD <- as.character(DMA_CD)
  KBM$OWN_RENT_CD <- as.character(OWN_RENT_CD)
  KBM$DONOR_CD <- ifelse(DONOR_CD=="P","Y",DONOR_CD) ## will be 1 for P or Y

    # Translate variables into flags where 1=Y
    createFlag <- function(var){
      var <- ifelse(var=="Y",1,0)
    }
    flagList <- c("PC_IND","PC_OWN_IND","CRDT_ACTV_IND","FINC_SVCS_BNKG_IND",
                  "FINC_SVCS_INSR_IND","FINC_SVCS_INSTL_IND",
                  "HH_LVL_MATCH_IND","HH_ONLN_IND","HOME_IMPMNT_IND","HOME_OFC_SUPPLY_IND",
                  "INDIV_LVL_MATCH_IND","LOW_END_DEPT_STOR_IND","MAIN_STR_RTL_IND","MARRIED_IND",
                  "MISC_IND","OIL_CO_IND","ONE_PER_ADDR_IND","PUBL_HOUSING_IND","PRSN_ELDER_IND",
                  "SEASNL_ADDR_IND","SOHO_HH_IND","SOHO_INDIV_IND","SPLTY_IND","SPLTY_APRL_IND",
                  "SPORT_GOODS_IND","STD_RTL_IND","TRVL_PERSNL_SVCS_IND","TV_MAIL_ORD_IND",
                  "UNIT_NBR_PRSN_IND","UPSCL_RTL_IND","WHSE_MBR_IND","DONOR_CD")
    KBM[flagList] <- lapply(KBM[flagList],createFlag)
    
    remove(raw_KBM)
    
## Merge 
Indep.Vars <- IDs %>% 
              left_join(.,KBM,by=c("AGLTY_INDIV_ID")) %>%
              as.data.frame

## Fill in missing

  # replace NA with median for specific variables
  replaceWithMedian <- function(var){
                                    var <- ifelse(is.na(var),median(var,na.rm=T),var)
  }
  listNumeric <- c("AGE_VAL","CENS_AVG_AUTO_CNT","CENS_EDU_LVL_CD","CENS_INCM_PCTL_CD",
                   "CENS_MED_AGE_HHER_VAL","CENS_MED_HH_INCM_CD","CENS_MED_HOME_VAL_CD",
                   "CENS_BLACK_PCT","CENS_BLUE_CLLR_PCT","CENS_HH_CHILD_PCT","CENS_HISPANIC_PCT",
                   "CENS_HMOWN_PCT","CENS_MARRIED_PCT","CENS_MOBL_HOME_PCT","CENS_SINGLE_HOME_PCT",
                   "CENS_WHITE_PCT","CENS_WHITE_CLLR_PCT","DLVR_PT_CD","HH_ADULTS_CNT","HH_PERSS_CNT",
                   "HH_CHILD_CNT","ZIP_LVL_INCM_DCL_CD","SCORE_4")
  Indep.Vars[listNumeric] <- lapply(Indep.Vars[listNumeric],replaceWithMedian)
  
  # replace NA with 99 for specific variables
  Indep.Vars <- Indep.Vars %>% 
                  mutate(DGTL_INVMNT_CD = ifelse(is.na(DGTL_INVMNT_CD),99,DGTL_INVMNT_CD),
                         DGTL_SEG_CD = ifelse(is.na(DGTL_SEG_CD),99,DGTL_SEG_CD),
                         LEN_RES_CD = ifelse(is.na(LEN_RES_CD),99,LEN_RES_CD),
                         ADDR_VRFN_CD = ifelse(is.na(ADDR_VRFN_CD),99,ADDR_VRFN_CD),
                         SCORE_9 = ifelse(is.na(SCORE_9),99,SCORE_9),
                         SCORE_10 = ifelse(is.na(SCORE_10),99,SCORE_10)) 
  
  # replace numeric NA with 0
  Indep.Vars <- Indep.Vars %>% 
                  map_if(is.numeric,~ifelse(is.na(.x),0,.x)) 
  
  # replace character NA with U
  Indep.Vars <- Indep.Vars %>%
                  map_if(is.character,~ifelse(is.na(.x),"U",.x)) %>%
                  as.data.frame

  # variables must be in factor form unless numeric
  factorList <- c("SRC_CD","ST_CD","BANK_CARD_CD","CARR_RTE_CD","CENS_INFO_LVL_CD",
                  "CENS_BLOCK_GRP_CD","DMA_CD","DWELL_TYPE_CD","ETHN_CD","FMLY_POS_CD",
                  "GNDR_CD","CENS_TRACT_SUB_CD","CENS_TRACT_NBR","OWN_RENT_CD",
                  "OCCU_CD","OCCU2_CD","PRSN_CHILD_IND","RTL_CARD_IND","SPOUSE_OCCU_CD",
                  "MAIL_ORD_RSPDR_CD","IMAGE_MAIL_ORD_BYR_CD","HMOWN_STAT_CD",
                  ## ordered?
                  "NIELSEN_CNTY_SZ_CD","ZIP_LVL_INCM_DCL_CD","EST_HH_INCM_CD",
                  "ADDR_VRFN_CD","AGE_RNG_CD","SCORE_1","SCORE_2","SCORE_6")
  Indep.Vars[factorList] <- lapply(Indep.Vars[factorList], as.factor)
  
  remove(IDs)
  remove(KBM)
  remove(factorList)
  remove(flagList)
  remove(listNumeric)

## Export
data.table::fwrite(Indep.Vars,file='MED_DM_22_Targeting_IndepVars.csv') #3 minutes
remove(Indep.Vars)








### --------- NEXT SET OF RAW DATA --------- ###








#_Benefits 
Benefits <- sqlQuery(connection, "select * from MED_DM_22_Targeting_Benefits")
Benefits$AGLTY_INDIV_ID <- as.character(Benefits$AGLTY_INDIV_ID_CHAR) 
Benefits <- Benefits %>% select(-AGLTY_INDIV_ID_CHAR,-CNTY_NM)

## Join to InHomeDate
raw_InHomeDate<-data.table::fread(file='MED_DM_22_Targeting_PH_IH.csv',colClasses=c(AGLTY_INDIV_ID="character")) ## 30 seconds
raw_InHomeDate$Inhome_Date <- as.Date(raw_InHomeDate$Inhome_Date)
IDs <- unique(raw_InHomeDate,by=c("AGLTY_INDIV_ID","Campaign")) %>% select(AGLTY_INDIV_ID,Campaign)
remove(raw_InHomeDate)

## join all columns by AGLTY_INDIV_ID and Campaign   
# Merge final
Benefits.join <- IDs %>% 
  left_join(.,Benefits,by=c("AGLTY_INDIV_ID","Campaign"))
remove(Benefits)
remove(IDs)

## Cleaning

Benefits.join$KP_Region <- ifelse(is.na(Benefits.join$KP_Region),"U",Benefits.join$KP_Region)
Benefits.join <- as.data.frame(Benefits.join)

# replace NA with median for specific variables
replaceWithMedian <- function(var){
  var <- ifelse(is.na(var),median(var,na.rm=T),var)
}
NumericList <- c("BENE_TotalValAdd","BENE_InpatientCopay","BENE_SpecialistCopay","BENE_AEPGrowth")
Benefits.join[NumericList] <- lapply(Benefits.join[NumericList],replaceWithMedian)

## Join
Indep.Vars.Orig<-data.table::fread(file='MED_DM_22_Targeting_IndepVars.csv',colClasses=c(AGLTY_INDIV_ID="character")) ## 30 seconds

Indep.Vars.Add <- Benefits.join %>% 
  left_join(.,Indep.Vars.Orig,by=c("AGLTY_INDIV_ID","Campaign"))

remove(Indep.Vars.Orig)
remove(Benefits.join)

## Export
data.table::fwrite(Indep.Vars.Add,file='MED_DM_22_Targeting_IndepVars2.csv') #3 minutes
remove(Indep.Vars.Add)










### --------- NEXT SET OF RAW DATA --------- ###








#_Address
gc()
Address <- sqlQuery(connection, "select * from MED_DM_22_Targeting_Address")
Address$AGLTY_INDIV_ID <- as.character(Address$AGLTY_INDIV_ID) 
Address <- Address %>% select(-ZIP_CD,-ZIP4_CD,-CNTY_NM,-ST_CD,-COUNTYFIPS,
                              -AGLTY_ADDR_ID_CHAR,-AGLTY_ADDR_ID_VCHAR,-GEOCODE,
                              -AGLTY_INDIV_ID_CHAR,-PRSN_IND)

## Join to InHomeDate
raw_InHomeDate<-data.table::fread(file='MED_DM_22_Targeting_PH_IH.csv',colClasses=c(AGLTY_INDIV_ID="character")) ## 30 seconds
raw_InHomeDate$Inhome_Date <- as.Date(raw_InHomeDate$Inhome_Date)
IDs <- unique(raw_InHomeDate,by=c("AGLTY_INDIV_ID","Campaign")) %>% select(AGLTY_INDIV_ID,Campaign)
remove(raw_InHomeDate)

## join all columns by AGLTY_INDIV_ID 
# Merge final
Address.join <- IDs %>% 
                  left_join(.,Address,by=c("AGLTY_INDIV_ID"))
remove(Address)
remove(IDs)

## Cleaning

Address.join$HOSP_FCLTY_ID <- substr(Address.join$HOSP_FCLTY_ID,1,regexpr("-", Address.join$HOSP_FCLTY_ID, fixed = TRUE) - 1)
Address.join$MOB_FCLTY_ID <- substr(Address.join$MOB_FCLTY_ID,1,regexpr("-", Address.join$MOB_FCLTY_ID, fixed = TRUE) - 1)
Address.join$CARR_RTE_CD <- substr(Address.join$CARR_RTE_CD,1,2)

Address.join <- as.data.frame(Address.join)

# Replace with U for character variables
replaceWithU <- function(var){
  var <- ifelse(is.na(var),"U",var)
}
listChar <- c("REGN_CD","SUB_REGN_CD","SVC_AREA_NM","DWELL_TYPE_CD","HOSP_FCLTY_ID",
              "MOB_FCLTY_ID","CARR_RTE_CD")
Address.join[listChar] <- lapply(Address.join[listChar],replaceWithU)

# Replace with median
replaceWithMedian <- function(var){
  var <- ifelse(is.na(var),median(var,na.rm=T),var)
}
listNumeric <- c("HOSP_DIST_MSR","MOB_DIST_MSR")
Address.join[listNumeric] <- lapply(Address.join[listNumeric],replaceWithMedian)

## Duplicate across SEP and AEP campaigns
Address.join$Campaign <- "AEP"
Address.join2 <- Address.join %>% mutate(Campaign = "SEP")
Address.join <- union(Address.join,Address.join2)
  remove(Address.join2)

## Join
Indep.Vars.Orig <- data.table::fread(file='MED_DM_22_Targeting_IndepVars2.csv',colClasses=c(AGLTY_INDIV_ID="character")) ## 30 seconds
Indep.Vars.Add <- setDF(setDT(Address.join)[setDT(Indep.Vars.Orig),on=.(AGLTY_INDIV_ID,Campaign)])

  remove(Address.join)
  remove(Indep.Vars.Orig)

## Export
data.table::fwrite(Indep.Vars.Add,file='MED_DM_22_Targeting_IndepVars3.csv') #3 minutes
remove(Indep.Vars.Add)








### --------- NEXT SET OF RAW DATA --------- ###








#_Share
gc()
Share <- sqlQuery(connection, "select * from MED_DM_22_Targeting_Share")
Share$AGLTY_INDIV_ID <- as.character(Share$AGLTY_INDIV_ID_CHAR) 
Share <- Share %>% select(-CNTY_NM,-KP_Region,-ST_CD,-AGLTY_INDIV_ID_CHAR)

## Join to InHomeDate
raw_InHomeDate<-data.table::fread(file='MED_DM_22_Targeting_PH_IH.csv',colClasses=c(AGLTY_INDIV_ID="character")) ## 30 seconds
raw_InHomeDate$Inhome_Date <- as.Date(raw_InHomeDate$Inhome_Date)
IDs <- unique(raw_InHomeDate,by=c("AGLTY_INDIV_ID","Campaign")) %>% select(AGLTY_INDIV_ID,Campaign)
remove(raw_InHomeDate)

## join all columns by AGLTY_INDIV_ID 
# Merge final
Share.join <- IDs %>% 
  left_join(.,Share,by=c("AGLTY_INDIV_ID","Campaign"))
remove(Share)
remove(IDs)

## Cleaning

Share.join <- as.data.frame(Share.join)

# Replace with median
replaceWithMedian <- function(var){
  var <- ifelse(is.na(var),median(var,na.rm=T),var)
}
listNumeric <- c("Market_Position","POS_Premium","POS_PartBBuyDown","POS_Inpatient","POS_Outpatient",
                 "POS_Professional","POS_OMC","POS_Supplemental","POS_Drug","Market_Share","PMPM_ValueAdd",
                 "PMPM_ValueAdd_YoY","PMPM_ValueAdd_Lag1Yr_Cum","PMPM_ValueAdd_Lag2Yr_Cum","PMPM_ValueAdd_Lag3Yr_Cum",
                 "PMPM_ValueAdd_Lag4Yr_Cum","PMPM_ValueAdd_Lag5Yr_Cum")
Share.join[listNumeric] <- lapply(Share.join[listNumeric],replaceWithMedian)

## Join
Indep.Vars.Orig <- data.table::fread(file='MED_DM_22_Targeting_IndepVars3.csv',colClasses=c(AGLTY_INDIV_ID="character")) ## 30 seconds
Indep.Vars.Add <- setDF(setDT(Share.join)[setDT(Indep.Vars.Orig),on=.(AGLTY_INDIV_ID,Campaign)])

## do I need to rename any columns?

remove(Share.join)
remove(Indep.Vars.Orig)

## Export
data.table::fwrite(Indep.Vars.Add,file='MED_DM_22_Targeting_IndepVars4.csv') #3 minutes
remove(Indep.Vars.Add)






### --------- NEXT SET OF RAW DATA --------- ###








#_MAPen
gc()
MAPen <- sqlQuery(connection, "select * from MED_DM_22_Targeting_MAPen")
MAPen$AGLTY_INDIV_ID <- as.character(MAPen$AGLTY_INDIV_ID_CHAR) 
MAPen <- MAPen %>% select(-COUNTYFIPS,-AGLTY_INDIV_ID_CHAR) %>% distinct()

## Join to InHomeDate
raw_InHomeDate<-data.table::fread(file='MED_DM_22_Targeting_PH_IH.csv',colClasses=c(AGLTY_INDIV_ID="character")) ## 30 seconds
raw_InHomeDate$Inhome_Date <- as.Date(raw_InHomeDate$Inhome_Date)
IDs <- unique(raw_InHomeDate,by=c("AGLTY_INDIV_ID","Campaign")) %>% select(AGLTY_INDIV_ID,Campaign)
remove(raw_InHomeDate)

## join all columns by AGLTY_INDIV_ID 
# Merge final
MAPen.join <- IDs %>% 
  left_join(.,MAPen,by=c("AGLTY_INDIV_ID","Campaign"))
remove(MAPen)
remove(IDs)

## Cleaning

MAPen.join <- as.data.frame(MAPen.join)

# Replace with median
replaceWithMedian <- function(var){
  var <- ifelse(is.na(var),median(var,na.rm=T),var)
}
listNumeric <- c("MA_Eligibles","MA_Enrolled","MA_Penetration_Rt")
MAPen.join[listNumeric] <- lapply(MAPen.join[listNumeric],replaceWithMedian)

## Join
Indep.Vars.Orig <- data.table::fread(file='MED_DM_22_Targeting_IndepVars4.csv',colClasses=c(AGLTY_INDIV_ID="character")) ## 30 seconds
Indep.Vars.Add <- setDF(setDT(MAPen.join)[setDT(Indep.Vars.Orig),on=.(AGLTY_INDIV_ID,Campaign)])

remove(MAPen.join)
remove(Indep.Vars.Orig)

Indep.Vars.Add <- Indep.Vars.Add %>% 
                      rename(DWELL_TYPE_CD.ADDR=DWELL_TYPE_CD) %>%
                      rename(DWELL_TYPE_CD.KBM=i.DWELL_TYPE_CD) %>%
                      rename(CARR_RTE_CD.ADDR=CARR_RTE_CD) %>%
                      rename(CARR_RTE_CD.KBM=i.CARR_RTE_CD)

## Export
data.table::fwrite(Indep.Vars.Add,file='MED_DM_22_Targeting_IndepVars_Final.csv') #3 minutes
remove(Indep.Vars.Add)








### --------- NEXT SET OF RAW DATA --------- ###








#_Tenure --- THERE SHOULDN'T BE TENURE FOR PROSPECT MAIL
#Tenure <- sqlQuery(connection, "select * from MED_DM_22_Targeting_Tenure")
#tabyl(tenure_years)
#tabyl(tenure_months)
#tabyl(tenure_days)
#replace all missing with 0
#remove(Tenure)








### --------- NEXT SET OF RAW DATA --------- ###








#_Sample restriction.
gc()
SampleIDs <- sqlQuery(connection, "select * from MED_DM_22_Targeting_Sample")
SampleIDs$AGLTY_INDIV_ID <- as.character(SampleIDs$AGLTY_INDIV_ID_CHAR) 
SampleIDs <- SampleIDs %>% select(-AGLTY_INDIV_ID_CHAR)

## Append _TapestrySamp
TapestrySamp <- sqlQuery(connection, "select * from MED_DM_22_Targeting_TapestrySamp")
TapestrySamp$AGLTY_INDIV_ID <- as.character(TapestrySamp$AGLTY_INDIV_ID) 
TapestrySamp <- TapestrySamp %>% select(-AGLTY_INDIV_ID_CHAR,-GEOCODE,-AGLTY_ADDR_ID_CHAR)

## Join
Sample.Complete <- setDF(setDT(TapestrySamp)[setDT(SampleIDs),on=.(AGLTY_INDIV_ID)]) 
  remove(TapestrySamp)
  remove(SampleIDs)
  
  ## Cleaning - fill missing with median
  replaceWithMedian <- function(var){
    var <- ifelse(is.na(var),median(var,na.rm=T),var)
  }
  listNumeric <- unlist(lapply(Sample.Complete, is.numeric))  
  Sample.Complete[listNumeric] <- lapply(Sample.Complete[listNumeric],replaceWithMedian)

## Join to full set of independent vars
Indep.Vars.Orig <- data.table::fread(file='MED_DM_22_Targeting_IndepVars_Final.csv',colClasses=c(AGLTY_INDIV_ID="character")) ## 30 seconds
Sample.Complete <- setDF(setDT(Sample.Complete)[setDT(Indep.Vars.Orig),on=.(AGLTY_INDIV_ID),nomatch=0]) #inner join has 720k records (dupes for both periods)

  remove(Indep.Vars.Orig)

## Export
data.table::fwrite(Sample.Complete,file='MED_DM_22_Targeting_IndepVars_Final_Sample500k.csv') #3 minutes
remove(Sample.Complete)

odbcCloseAll()
dbDisconnect(con)
