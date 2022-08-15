############################## Re-Creating MED_DM_22_Targetin_Final with service area ############################

## Import final table
DF <-data.table::fread(file='MED_DM_22_Targeting_Final.csv')

# Variable list
to.keep <- names(DF)

# Add back in some other variables
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

names(Final.Table.Clean)

# Subset to variables we want to keep
to.keep <- append(to.keep,c("AGLTY_INDIV_ID","SVC_AREA_NM","MOB_DIST_MSR"))
Final.Table.Clean <- subset(Final.Table.Clean,select = names(Final.Table.Clean) %in% to.keep)
#data.table::fwrite(Final.Table.Clean,file='MED_DM_22_Targeting_Final.csv') #save

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

## clean
Final.Table.Complete$MA_Penetration_Rt <- Final.Table.Complete$MA_Penetration_Rt*100

Final.Table.Complete$LENGTH_RESID_BIN <- ifelse(Final.Table.Complete$LEN_RES_CD<=3,"0-3","") 
Final.Table.Complete$LENGTH_RESID_BIN <- ifelse(Final.Table.Complete$LEN_RES_CD<=10 & Final.Table.Complete$LEN_RES_CD>3,"4-10",Final.Table.Complete$LENGTH_RESID_BIN)
Final.Table.Complete$LENGTH_RESID_BIN <- ifelse(Final.Table.Complete$LEN_RES_CD>10,"11+",Final.Table.Complete$LENGTH_RESID_BIN)
Final.Table.Complete$LENGTH_RESID_BIN <- ifelse(Final.Table.Complete$LEN_RES_CD==99,"U",Final.Table.Complete$LENGTH_RESID_BIN)

Final.Table.Complete$MEXICO_CO_ORIGIN_FLAG <- ifelse(Final.Table.Complete$SCORE_4==1,1,0)

Final.Table.Complete$HOMEOWNER_CD <- ifelse(Final.Table.Complete$HMOWN_STAT_CD %in% c("R","T"),"Renter","U")
Final.Table.Complete$HOMEOWNER_CD <- ifelse(Final.Table.Complete$HMOWN_STAT_CD %in% c("P","Y"),"Owner",Final.Table.Complete$HOMEOWNER_CD)

Final.Table.Complete$MAIL_ORDER_BUYER <- ifelse(Final.Table.Complete$MAIL_ORD_RSPDR_CD %in% c("M","Y"),1,0)
Final.Table.Complete$MAIL_ORDER_BUYER_M <- ifelse(Final.Table.Complete$IMAGE_MAIL_ORD_BYR_CD=="M",1,0)

Final.Table.Complete$Region <- ifelse(Final.Table.Complete$SUB_REGN_CD %in% c("MRDC","MRMD","MRVA"),"MAS",as.character(Final.Table.Complete$SUB_REGN_CD))
Final.Table.Complete$Region <- ifelse(Final.Table.Complete$SUB_REGN_CD %in% c("NWOR","NWWA"),"NW",as.character(Final.Table.Complete$Region))
Final.Table.Complete$Region <- ifelse(Final.Table.Complete$SUB_REGN_CD == "COCO","CO",as.character(Final.Table.Complete$Region))
Final.Table.Complete$Region <- ifelse(Final.Table.Complete$SUB_REGN_CD %in% c("HI","HIHA","HIHO","HIMA"),"HI",as.character(Final.Table.Complete$Region))

Final.Table.Complete$PRSN_CHILD_IND <- ifelse(Final.Table.Complete$PRSN_CHILD_IND %in% c("P","Y"),1,0)

Final.Table.Complete <- Final.Table.Complete %>% 
                          dplyr::select(-SEGMENT_UNRESPONSIVE_FLAG,-SEGMENT_LATINO_FLAG,-SCORE_1,-SCORE_4,-LEN_RES_CD,
                           -TIMES_PROMOTED_AEP,-HMOWN_STAT_CD,-IMAGE_MAIL_ORD_BYR_CD,-MAIL_ORD_RSPDR_CD) %>% 
                          as.data.frame

# Set DV as numeric
Final.Table.Complete$CONV_RESP_30DAY_FLAG <- as.numeric(Final.Table.Complete$CONV_RESP_30DAY_FLAG)
Final.Table.Complete$CONV_RESP_60DAY_FLAG <- as.numeric(Final.Table.Complete$CONV_RESP_60DAY_FLAG)
Final.Table.Complete$CONV_ENROLL_90DAY_FLAG <- as.numeric(Final.Table.Complete$CONV_ENROLL_90DAY_FLAG)
Final.Table.Complete$CONV_ENROLL_120DAY_FLAG <- as.numeric(Final.Table.Complete$CONV_ENROLL_120DAY_FLAG)

# Set IV as factors
ListFactors.AD <- c("Region","SUB_REGN_CD","SVC_AREA_NM")
ListFactors.PH <- c("PROMOTED_SEP_FLAG","LIST_SOURCE_EXPERIAN_FLAG","SEP_LATINO_DM_FLAG","Campaign",
                    "SEP_DROP_1_FLAG","SEP_DROP_2_FLAG","SEP_DROP_3_FLAG","SEP_DROP_4_FLAG",
                    "SEP_DROP_5_FLAG","SEP_DROP_6_FLAG","SEP_DROP_7_FLAG","SEP_DROP_8_FLAG",
                    "SEP_DROP_9_FLAG")
ListFactors.TAP <- c("TAPESTRY_SEGMENT_CD")
ListFactors.KBM <- c("ADDR_VRFN_CD","HOMEOWNER_CD","OCCU_CD","ONE_PER_ADDR_IND","PRSN_CHILD_IND","UNIT_NBR_PRSN_IND",
                     "KBM_Flag","SCORE_6","SCORE_9","SCORE_10","MEXICO_CO_ORIGIN_FLAG","LENGTH_RESID_BIN",
                     "MAIL_ORDER_BUYER","MAIL_ORDER_BUYER_M")
Final.Table.Complete[ListFactors.PH] <- lapply(Final.Table.Complete[ListFactors.PH], as.factor)
Final.Table.Complete[ListFactors.TAP] <- lapply(Final.Table.Complete[ListFactors.TAP], as.factor)
Final.Table.Complete[ListFactors.KBM] <- lapply(Final.Table.Complete[ListFactors.KBM], as.factor)
Final.Table.Complete[ListFactors.AD] <- lapply(Final.Table.Complete[ListFactors.AD], as.factor)
str(Final.Table.Complete)
  remove(ListFactors.AD)
  remove(ListFactors.KBM)
  remove(ListFactors.PH)
  remove(ListFactors.TAP)

## Cleaning - fill missing with median
replaceWithMedian <- function(var){
  var <- ifelse(is.na(var),median(var,na.rm=T),var)
}
listNumeric <- unlist(lapply(Final.Table.Complete, is.numeric))  
Final.Table.Complete[listNumeric] <- lapply(Final.Table.Complete[listNumeric],replaceWithMedian)

# bin tapestry segments
tabyl(Final.Table.Complete$TAPESTRY_SEGMENT_CD)
Final.Table.Complete$TAPESTRY_SEGMENT_CD <- readr::parse_number(as.character(Final.Table.Complete$TAPESTRY_SEGMENT_CD))
Final.Table.Complete$TAPESTRY_SEGMENT_CD <- ifelse(is.na(Final.Table.Complete$TAPESTRY_SEGMENT_CD),"U",Final.Table.Complete$TAPESTRY_SEGMENT_CD)

## Export
data.table::fwrite(Final.Table.Complete,file='MED_DM_22_Targeting_Final.csv') #save
remove(Final.Table.Complete)
