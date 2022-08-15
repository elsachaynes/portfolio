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
KBM<-data.table::fread(file='MED_DM_22_Targeting_IndepVars.csv',colClasses=c(AGLTY_INDIV_ID="character")) ## 30 seconds

Indep.Vars <- Benefits.join %>% 
                  left_join(.,KBM,by=c("AGLTY_INDIV_ID","Campaign"))

  remove(KBM)
  remove(Benefits.join)

## Export
data.table::fwrite(Indep.Vars,file='MED_DM_22_Targeting_IndepVars2.csv') #3 minutes
  remove(Indep.Vars)









### --------- NEXT SET OF RAW DATA --------- ###








#_Address ??
Address <- sqlQuery(connection, "select * from MED_DM_22_Targeting_Address")
remove zip_cd, zip4_cd, cnty_nm, st_cd, countyfips, aglty_addr_id_char, geocode, aglty_indiv_id_char, aglty_addr_id_vchar
tabyl(REGN_CN)
tabyl(SUB_REGN_CD)
tabyl(SVC_AREA_NM)
tabyl(PRSN_IND)
tabyl(DWELL_TYPE_CD)
tabyl(HOSP_FCLTY_ID)
tabyl(HOSP_DIST_MSR)
tabyl(MOB_FCLTY_ID)
tabyl(MOD_DIST_MSR)
tabyl(CARR_RTE_CD)

remove(Address)







### --------- NEXT SET OF RAW DATA --------- ###








#_Share
Share <- sqlQuery(connection, "select * from MED_DM_22_Targeting_Share")

tabyl(KP_Region) <-- already in Benefits. Better?
tabyl(ST_CD) <-- already in KBM. Better?
tabyl(CNTY_NM) remove
tabyl(Market_Position)
tabyl(POS_Premium)
tabyl(POS_PartBBuyDown)
tabyl(POS_Inpatient)
tabyl(POS_Outpatient)
tabyl(POS_Professional)
tabyl(POS_OMC)
tabyl(POS_Supplemental)
tabyl(POS_Drug)
tabyl(Market_Share)
tabyl(POS_ValueAdd)
tabyl(POS_ValueAdd_YoY)
tabyl(POS_ValueAdd_Lag1Yr_Cum)
tabyl(POS_ValueAdd_Lag2Yr_Cum)
tabyl(POS_ValueAdd_Lag3Yr_Cum)
tabyl(POS_ValueAdd_Lag4Yr_Cum)
tabyl(POS_ValueAdd_Lag5Yr_Cum)

remove(Share)






### --------- NEXT SET OF RAW DATA --------- ###








#_MAPen
MAPen <- sqlQuery(connection, "select * from MED_DM_22_Targeting_MAPen")
remove COUNTYFIPS
tabyl(MA_Eligibles) 
tabyl(MA_Enrolled) 
tabyl(MA_Penetration_Rt) 


remove(MAPen)







### --------- NEXT SET OF RAW DATA --------- ###








#_Tenure --- NEED TO RE-DO EXCLUDING MEMBERSHIP BEFORE INHOME!!
Tenure <- sqlQuery(connection, "select * from MED_DM_22_Targeting_Tenure")
tabyl(tenure_years)
tabyl(tenure_months)
tabyl(tenure_days)
replace all missing with 0

remove(Tenure)








### --------- NEXT SET OF RAW DATA --------- ###








#_TapestrySamp
TapestrySamp <- sqlQuery(connection, "select * from MED_DM_22_Targeting_TapestrySamp")
remove Aglty_addr_id_char, geocode, aglty_indiv_id_char
  remove(TapestrySamp)

#_Sample restriction.
SampleIDs <- sqlQuery(connection, "select * from MED_DM_22_Targeting_Sample")

--> only this set has tapestry for now

odbcCloseAll()
dbDisconnect(con)
