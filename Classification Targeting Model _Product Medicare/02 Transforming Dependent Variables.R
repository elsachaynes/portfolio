gc()
library(purrr)
#install.packages("bit64")

## All IDs
raw_InHomeDate<-data.table::fread(file='MED_DM_22_Targeting_PH_IH.csv',colClasses=c(AGLTY_INDIV_ID="character")) ## 30 seconds
raw_InHomeDate$Inhome_Date <- as.Date(raw_InHomeDate$Inhome_Date)
IDs <- unique(raw_InHomeDate,by=c("AGLTY_INDIV_ID","Campaign")) %>% select(AGLTY_INDIV_ID,Campaign)
remove(raw_InHomeDate)

## Conversion: Enrollment (not sure why I split this out in the first place)
Enroll.AEP <-data.table::fread(file='MED_DM_22_Targeting_MBR_AEP.csv',colClasses=c(AGLTY_INDIV_ID="character")) ## 10 seconds
Enroll.AEP$Campaign <- "AEP"
Enroll.SEP <-data.table::fread(file='MED_DM_22_Targeting_MBR_SEP.csv',colClasses=c(AGLTY_INDIV_ID="character")) ## 10 seconds
Enroll.SEP$Campaign <- "SEP"
Enroll.combined <- rbind(Enroll.AEP,Enroll.SEP)
  remove(Enroll.AEP)
  remove(Enroll.SEP)

## Conversion: Response (not sure why I split this out in the first place)
Resp.AEP <-data.table::fread(file='MED_DM_22_Targeting_RESP_AEP.csv',colClasses=c(AGLTY_INDIV_ID="character")) ## 10 seconds
Resp.AEP$Campaign <- "AEP"
Resp.SEP <-data.table::fread(file='MED_DM_22_Targeting_RESP_SEP.csv',colClasses=c(AGLTY_INDIV_ID="character")) ## 10 seconds
Resp.SEP$Campaign <- "SEP"
Resp.combined <- rbind(Resp.AEP,Resp.SEP)
  remove(Resp.SEP)
  remove(Resp.AEP)
  
## Promotion/Treatment
Promotion <-data.table::fread(file='MED_DM_22_Targeting_PH.csv',colClasses=c(AGLTY_INDIV_ID="character")) ## 10 seconds

## Final Set
Dep.Vars <- setDF(setDT(Enroll.combined)[setDT(IDs),on=.(AGLTY_INDIV_ID,Campaign)])
Dep.Vars <- setDF(setDT(Resp.combined)[setDT(Dep.Vars),on=.(AGLTY_INDIV_ID,Campaign)])
Dep.Vars <- setDF(setDT(Promotion)[setDT(Dep.Vars),on=.(AGLTY_INDIV_ID)])
  remove(Enroll.combined)
  remove(Resp.combined)
  remove(Promotion)
  
# Fill in missing
Dep.Vars <- Dep.Vars %>% 
  map_if(is.numeric,~ifelse(is.na(.x),0,.x)) %>%
  as.data.frame

# Clear out values for AEP treatment from SEP rows
Dep.Vars <- Dep.Vars %>% select(-PROMOTED_AEP_FLAG)
Dep.Vars$TIMES_PROMOTED_AEP <- ifelse(Dep.Vars$Campaign=="SEP",0,Dep.Vars$TIMES_PROMOTED_AEP)
Dep.Vars$AEP_DROP_1_FLAG <- ifelse(Dep.Vars$Campaign=="SEP",0,Dep.Vars$AEP_DROP_1_FLAG)
Dep.Vars$AEP_DROP_2_FLAG <- ifelse(Dep.Vars$Campaign=="SEP",0,Dep.Vars$AEP_DROP_2_FLAG)
Dep.Vars$AEP_DROP_3_FLAG <- ifelse(Dep.Vars$Campaign=="SEP",0,Dep.Vars$AEP_DROP_3_FLAG)
Dep.Vars$AEP_DROP_4_FLAG <- ifelse(Dep.Vars$Campaign=="SEP",0,Dep.Vars$AEP_DROP_4_FLAG)
Dep.Vars$AEP_DROP_5_FLAG <- ifelse(Dep.Vars$Campaign=="SEP",0,Dep.Vars$AEP_DROP_5_FLAG)
Dep.Vars$AEP_DROP_6_FLAG <- ifelse(Dep.Vars$Campaign=="SEP",0,Dep.Vars$AEP_DROP_6_FLAG)
Dep.Vars$AEP_DROP_7_FLAG <- ifelse(Dep.Vars$Campaign=="SEP",0,Dep.Vars$AEP_DROP_7_FLAG)
Dep.Vars$AEP_DROP_8_FLAG <- ifelse(Dep.Vars$Campaign=="SEP",0,Dep.Vars$AEP_DROP_8_FLAG)

## Validate
tabyl(Dep.Vars,Campaign,CONV_ENROLL_90DAY_FLAG)
tabyl(Dep.Vars,Campaign,CONV_ENROLL_120DAY_FLAG)
tabyl(Dep.Vars,Campaign,CONV_RESP_30DAY_FLAG)
tabyl(Dep.Vars,Campaign,CONV_RESP_60DAY_FLAG)
tabyl(Dep.Vars,Campaign,SUBSCRIBER_FLAG)
tabyl(Dep.Vars,Campaign,MEDICAID_MBR_FLAG)
tabyl(Dep.Vars,Campaign,TIMES_PROMOTED_AEP)
tabyl(Dep.Vars,Campaign,TIMES_PROMOTED_SEP)
tabyl(Dep.Vars,Campaign,PROMOTED_SEP_FLAG)
tabyl(Dep.Vars,Campaign,LIST_SOURCE_EXPERIAN_FLAG)
tabyl(Dep.Vars,Campaign,SEGMENT_LATINO_FLAG)
tabyl(Dep.Vars,Campaign,SEP_LATINO_DM_FLAG)
tabyl(Dep.Vars,Campaign,SEGMENT_UNRESPONSIVE_FLAG)
tabyl(Dep.Vars,Campaign,AEP_DROP_1_FLAG)
tabyl(Dep.Vars,Campaign,SEP_DROP_1_FLAG)

## Sample Set
library(RODBC)
connection <- odbcConnect("WS_EHAYNES")
SampleIDs <- sqlQuery(connection, "select * from MED_DM_22_Targeting_Sample")
SampleIDs$AGLTY_INDIV_ID <- as.character(SampleIDs$AGLTY_INDIV_ID_CHAR) 
SampleIDs <- SampleIDs %>% select(-AGLTY_INDIV_ID_CHAR)
# Join
Sample.Complete <- setDF(setDT(SampleIDs)[setDT(Dep.Vars),on=.(AGLTY_INDIV_ID),nomatch=0]) #inner join has 717k records (dupes for both periods)
  remove(SampleIDs)
   
## Export
data.table::fwrite(Dep.Vars,file='MED_DM_22_Targeting_DepVars_Final.csv') #30 seconds
data.table::fwrite(Sample.Complete,file='MED_DM_22_Targeting_DepVars_Final_Sample500k.csv') #5 seconds
  remove(Sample.Complete)
  remove(Dep.Vars)
  remove(IDs)  
  remove(Promotion)  
  

  