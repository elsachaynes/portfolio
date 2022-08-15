## Removing FM and RNC

gc()
library(odbc)
library(RODBC)
library(dplyr)
library(data.table)
library(janitor)
library(ggplot2)
library(stringr)
library(lubridate)

## To navigate the SQL Server schemas
con <- dbConnect(odbc::odbc(), "WS_EHAYNES")
## To pull data from SQL Server
connection <- odbcConnect("WS_EHAYNES")

## For each project table in WS_EHAYNES (MED_DM_22_Targeting).
##     Roll up to one row per AGLTY_INDIV_ID.


############################## RESPONSES/RNC ###################################

raw_RespILMR <- sqlQuery(connection, "select * from MED_DM_22_Targeting_RespILMR")
raw_RespILR <- sqlQuery(connection, "select * from MED_DM_22_Targeting_RespILR")
raw_RespILKR <- sqlQuery(connection, "select * from MED_DM_22_Targeting_RespILKR")

## Fix variable type
RespILMR <- raw_RespILMR
RespILR <- raw_RespILR
RespILKR <- raw_RespILKR

RespILMR$AGLTY_INDIV_ID <- as.character(raw_RespILMR$AGLTY_INDIV_ID) 
RespILR$AGLTY_INDIV_ID <- as.character(raw_RespILR$AGLTY_INDIV_ID) 
RespILKR$AGLTY_INDIV_ID <- as.character(raw_RespILKR$AGLTY_INDIV_ID) 

## Rename for standardization & change to date type
RespILMR$Response_Date <- as.Date(RespILMR$ACTVY_START_DT)
RespILR$Response_Date <- as.Date(RespILR$TP_START_DT) 
RespILKR$Response_Date <- as.Date(RespILKR$TP_START_DT)

  remove(raw_RespILMR)
  remove(raw_RespILR)
  remove(raw_RespILKR)

# Fill in missing TP_START_DT with REC_RECV_DT
invalid.dates <- is.na(RespILR$Response_Date)
if(any(invalid.dates)) {RespILR$Response_Date[invalid.dates] <- as.Date(RespILR$REC_RECV_DT)[invalid.dates]}
remove(invalid.dates)

# Filter BUSN_LN_IND
RespILR <-  RespILR %>% filter(BUSN_LN_IND == "KPMAI" | BUSN_LN_IND == "KPMA TELESALES")

# Filter to Response Dates
RespILMR <- RespILMR %>% filter(!is.na(Response_Date))

# Filter ACTVTY_TYPE_CD to inbound touchpoints only (no outbound sales contact)
tabyl(RespILMR$ACTVY_TYPE_CD)
RespILMR <-  RespILMR %>% filter(!ACTVY_TYPE_CD %in% c("OBC","UNABLE_TO_REACH","CALLBACK"))

# Filter ACTVY_TYPE_CD remove negative touchpoints
RespILMR <-  RespILMR %>% filter(!ACTVY_TYPE_CD %in% c("DISENROLLED","DO_NOT_SOLICIT"))  

# Filter ACTVY_TYPE_CD remove status tracking
RespILMR <-  RespILMR %>% filter(!ACTVY_TYPE_CD %in% c("FULFILLMENT","APPOINTMENT","DUPE_MERGE","OWNERSHIP") | grepl("APPOINTMENT ATTENDED",ACTVY_OTCM_CD))

## Get response date in one set

RespILMR <- RespILMR %>% distinct(AGLTY_INDIV_ID,Response_Date)
RespILR <- RespILR %>% distinct(AGLTY_INDIV_ID,Response_Date)
RespILKR <- RespILR %>% distinct(AGLTY_INDIV_ID,Response_Date)
Resp <- merge(RespILMR,RespILR,all=TRUE) %>% distinct()
Resp <- merge(Resp,RespILKR,all=TRUE) %>% distinct()
  remove(RespILMR)
  remove(RespILR)
  remove(RespILKR)
  
# Reduce to the first response
  Resp.First <- Resp %>% 
                    group_by(AGLTY_INDIV_ID) %>% 
                    filter(Response_Date == min(Response_Date)) %>% 
                    distinct %>%
                    as.data.frame

## Join to InHomeDate
raw_InHomeDate<-data.table::fread(file='MED_DM_22_Targeting_PH_IH.csv',colClasses=c(AGLTY_INDIV_ID="character")) ## 30 seconds
raw_InHomeDate$Inhome_Date <- as.Date(raw_InHomeDate$Inhome_Date)

# Reduce to the first in-home date
InHome.First <- raw_InHomeDate %>% 
                      group_by(AGLTY_INDIV_ID) %>% 
                      filter(Inhome_Date == min(Inhome_Date)) %>% 
                      distinct %>%
                      as.data.frame

# Join for removal: All records with their first response before the first inhome date.
RNC <- setDF(setDT(Resp.First)[setDT(InHome.First), on = .(AGLTY_INDIV_ID, Response_Date < Inhome_Date),nomatch=0, 
                               .(AGLTY_INDIV_ID = i.AGLTY_INDIV_ID, 
                                 Response_Date = x.Response_Date, 
                                 Inhome_Date = i.Inhome_Date,
                                 Campaign = i.Campaign)])
RNC$daysdif <- with(RNC,difftime(Inhome_Date,Response_Date,units=c("days")))
RNC$daysdif <- ifelse(is.na(RNC$daysdif),0,RNC$daysdif)
RNC %>% filter(daysdif >= 60)
RNC <- RNC %>% filter(daysdif >= 60) # maybe responses within 60 days didn't register before the data pull, so keep those IDs
RNC.IDs <- RNC %>% distinct(AGLTY_INDIV_ID) #88k RNCs in the "prospect" list
data.table::fwrite(RNC.IDs,file='MED_DM_22_Targeting_RNCs_EXCLUDE.csv') ## 5 seconds

  remove(RNC)
  remove(Resp)
  remove(Resp.First)
  
## Join to Promo IDs -- what promo IDs captured the RNC?
raw_PromoHist <- sqlQuery(connection, "select * from MED_DM_22_Targeting_AgilityIDs")
raw_PromoHist$AGLTY_INDIV_ID <- as.character(raw_PromoHist$AGLTY_INDIV_ID)
RNC.PromoIDs <- setDF(setDT(raw_PromoHist)[setDT(RNC.IDs),on=.(AGLTY_INDIV_ID)])
RNC.IDs$FlagRNC <- 1
All.PromoIDs <- setDF(setDT(RNC.IDs)[setDT(raw_PromoHist),on=.(AGLTY_INDIV_ID)])
All.PromoIDs$FlagRNC <- ifelse(is.na(All.PromoIDs$FlagRNC),0,All.PromoIDs$FlagRNC)
PromoIDs.W.RNC <-as.data.frame(tabyl(RNC.PromoIDs$PROMO_ID))
tabyl(All.PromoIDs,PROMO_ID,FlagRNC)
prop.table(table(All.PromoIDs$PROMO_ID,All.PromoIDs$FlagRNC),margin=1) #max 15% per promoID, but generally less.
  remove(PromoID246278)
  remove(PromoIDs.W.RNC)
  remove(RNC.PromoIDs)
  remove(RNC.IDs)
  
  ############################### MEMBERS/FM ###################################

raw_Member <- sqlQuery(connection, "select * from MED_DM_22_Targeting_Member") ## 30 seconds
  
## Fix variable type
raw_Member$AGLTY_INDIV_ID <- as.character(raw_Member$AGLTY_INDIV_ID)
  
# Remove enrollment after 1/1/2022
Member <- raw_Member %>% filter(ELGB_START_DT <= "2022-01-01")
  remove(raw_Member)
  
# Remove ELGB_END_DT < ELGB_START_DT
Member <- Member %>% filter(ELGB_START_DT < ELGB_END_DT)

# Reduce to the first response
Member.First <- Member %>% 
  group_by(AGLTY_INDIV_ID) %>% 
  filter(ELGB_START_DT == min(ELGB_START_DT)) %>% 
  distinct %>%
  as.data.frame

Member %>% filter(AGLTY_INDIV_ID=="5000040570593")
Member.First %>% filter(AGLTY_INDIV_ID=="5000040570593")
Member %>% filter(AGLTY_INDIV_ID=="5000064332821")
Member.First %>% filter(AGLTY_INDIV_ID=="5000064332821")
Member %>% filter(AGLTY_INDIV_ID=="5000064258134")
Member.First %>% filter(AGLTY_INDIV_ID=="5000064258134")

# Already have InHome.First (first promotion date)
  head(FM)
## Join for removal: All records with their first membership before the first inhome date.
FM <- setDF(setDT(Member.First)[setDT(InHome.First), on = .(AGLTY_INDIV_ID, ELGB_START_DT < Inhome_Date),nomatch=0, 
                               .(AGLTY_INDIV_ID = i.AGLTY_INDIV_ID, 
                                 ELGB_START_DT = x.ELGB_START_DT, 
                                 Inhome_Date = i.Inhome_Date,
                                 Campaign = i.Campaign)])
FM$daysdif <- with(FM,difftime(Inhome_Date,ELGB_START_DT,units=c("days")))
FM$daysdif <- ifelse(is.na(FM$daysdif),0,FM$daysdif)
FM %>% filter(daysdif < 60)
FM <- FM %>% filter(daysdif >= 60) # maybe enrollments within 60 days didn't register before the data pull, so keep those IDs
FM.IDs <- FM %>% distinct(AGLTY_INDIV_ID) #304k FM in the "prospect" list
data.table::fwrite(FM.IDs,file='MED_DM_22_Targeting_FM_EXCLUDE.csv') ## 5 seconds

remove(FM)
remove(Member)
remove(Member.First)

## Join to Promo IDs -- what promo IDs captured the FM?
#raw_PromoHist <- sqlQuery(connection, "select * from MED_DM_22_Targeting_AgilityIDs")
#raw_PromoHist$AGLTY_INDIV_ID <- as.character(raw_PromoHist$AGLTY_INDIV_ID)
FM.PromoIDs <- setDF(setDT(raw_PromoHist)[setDT(FM.IDs),on=.(AGLTY_INDIV_ID)])
FM.IDs$FlagFM <- 1
All.PromoIDs <- setDF(setDT(FM.IDs)[setDT(raw_PromoHist),on=.(AGLTY_INDIV_ID)])
All.PromoIDs$FlagFM <- ifelse(is.na(All.PromoIDs$FlagFM),0,All.PromoIDs$FlagFM)
PromoIDs.W.FM <-as.data.frame(tabyl(FM.PromoIDs$PROMO_ID))
View(PromoIDs.W.FM)
tabyl(All.PromoIDs,PROMO_ID,FlagFM)
prop.table(table(All.PromoIDs$PROMO_ID,All.PromoIDs$FlagFM),margin=1) #max 30% per promoID, but generally less.

#these were 28% FM  247214, 247193 

raw_PromoHist %>% filter(PROMO_ID=="247193") %>% distinct(PROMO_ID)

  remove(PromoIDs.W.FM)
  remove(FM.PromoIDs)
  remove(FM.IDs)
  
 