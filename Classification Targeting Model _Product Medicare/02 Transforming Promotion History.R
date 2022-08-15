## NOTES: Need to standardize "Creative" and "Segment"/"Segments" fields in campaign matrix for productionalization
##        I created an ODBC connection "WS_EHAYNES" on my computer

library(odbc)
library(RODBC)
library(dplyr)
library(stringr)
library(lubridate)
library(data.table)
library(janitor)

## To navigate the SQL Server schemas
con <- dbConnect(odbc::odbc(), "WS_EHAYNES")
## To pull data from SQL Server
connection <- odbcConnect("WS_EHAYNES")

## For each project table in WS_EHAYNES (MED_DM_22_Targeting).
##     Roll up to one row per AGLTY_INDIV_ID.

## Promo History + Promo ID info

raw_PromoHist <- sqlQuery(connection, "select * from MED_DM_22_Targeting_AgilityIDs")

## Fix variable type
raw_PromoHist$AGLTY_INDIV_ID <- as.character(raw_PromoHist$AGLTY_INDIV_ID)

## Remove "SEP 2020" promotion history that slipped through
## Remove variables not needed
PromoHist <- raw_PromoHist %>% 
  filter((grepl("2021 SEP",Creative) | grepl("2022 AEP",Creative)) & Segments != "Past Leads") %>%
  select(-PROMO_ID,-AGLTY_INDIV_ID_CHAR,-Region,-Segment,-Channel,-'_00_Number',-Offer,-Segment)
remove(raw_PromoHist)

## Remove variables & Rollup
PromoHist_rollup <- PromoHist %>%
  distinct(AGLTY_INDIV_ID)

## Flags: Batch 1
flags1.PromoHist <- PromoHist %>%
  mutate(
    SEP_LOCALAWARE_GA_FLAG = ifelse(grepl("GA Local Awareness",Creative),1,0),
    SEP_LOCALEDUC_GA_FLAG = ifelse(grepl("GA Local Education",Creative),1,0),
    LIST_SOURCE_KBM_FLAG = ifelse(Media_Detail=="DM-KBM",1,0), 
    LIST_SOURCE_EXPERIAN_FLAG = ifelse(Media_Detail=="DM-EXP",1,0), ## discontinued
    SEGMENT_LATINO_FLAG = ifelse(Segments=="Latino",1,0), ## rolled into general pop
    SEP_LATINO_DM_FLAG = ifelse(grepl("Latino",Creative),1,0), ## rolled into general pop
    SEGMENT_UNRESPONSIVE_FLAG = ifelse(Segments=="Unresponsive" | Segments=="Unresponsive Decile",1,0)) %>%
  group_by(AGLTY_INDIV_ID) %>%
  summarize_all(max) %>%
  ungroup() 

flags1.PromoHist <- flags1.PromoHist %>%
                              select(-Inhome_Date,-Campaign,-Creative,-Media_Detail,-Segments)

PromoHist_rollup <- PromoHist_rollup %>% 
                              left_join(flags1.PromoHist,by="AGLTY_INDIV_ID") 
  remove(flags1.PromoHist)

## Flags: Batch 2
flags2.PromoHist <- PromoHist %>%
  mutate(
    AEP_DROP_1_FLAG = ifelse(grepl("AEP Direct Mail D1",Creative),1,0),
    AEP_DROP_2_FLAG = ifelse(grepl("AEP Direct Mail D2",Creative),1,0),
    AEP_DROP_3_FLAG = ifelse(grepl("AEP Direct Mail D3",Creative),1,0),
    AEP_DROP_4_FLAG = ifelse(grepl("AEP Direct Mail D4",Creative),1,0),
    AEP_DROP_5_FLAG = ifelse(grepl("AEP Direct Mail D5",Creative),1,0),
    AEP_DROP_6_FLAG = ifelse(grepl("AEP Direct Mail D6",Creative),1,0),
    AEP_DROP_7_FLAG = ifelse(grepl("AEP Direct Mail D7",Creative),1,0),
    AEP_DROP_8_FLAG = ifelse(grepl("AEP Direct Mail D8",Creative),1,0),
    SEP_DROP_1_FLAG = ifelse(grepl("SEP Direct Mail D1",Creative),1,0),
    SEP_DROP_2_FLAG = ifelse(grepl("SEP Direct Mail D2",Creative),1,0),
    SEP_DROP_3_FLAG = ifelse(grepl("SEP Direct Mail D3",Creative),1,0),
    SEP_DROP_4_FLAG = ifelse(grepl("SEP Direct Mail D4",Creative),1,0),
    SEP_DROP_5_FLAG = ifelse(grepl("SEP Direct Mail D5",Creative),1,0),
    SEP_DROP_6_FLAG = ifelse(grepl("SEP Direct Mail D6",Creative),1,0),
    SEP_DROP_7_FLAG = ifelse(grepl("SEP Direct Mail D7",Creative),1,0),
    SEP_DROP_8_FLAG = ifelse(grepl("SEP Direct Mail D8",Creative) | Creative=="2021 SEP Latino August Direct Mail D8",1,0),
    SEP_DROP_9_FLAG = ifelse(Creative=="2021 SEP Latino September Direct Mail D9",1,0)) %>%
  group_by(AGLTY_INDIV_ID) %>%
  summarize_all(max) %>%
  ungroup()

flags2.PromoHist <- flags2.PromoHist %>%
                            select(-Inhome_Date,-Campaign,-Creative,-Media_Detail,-Segments)

PromoHist_rollup <- flags2.PromoHist[PromoHist_rollup,on=.(AGLTY_INDIV_ID)]
  remove(flags2.PromoHist)

## Flags: Batch 3
flags3.PromoHist <- PromoHist %>%
  select(-Inhome_Date,-Creative,-Media_Detail,-Segments) %>%
  group_by(AGLTY_INDIV_ID) %>%
  summarise(
    TIMES_PROMOTED_AEP = length(which(Campaign=="AEP")),
    TIMES_PROMOTED_SEP = length(which(Campaign=="SEP")),
    PROMOTED_AEP_FLAG = ifelse(TIMES_PROMOTED_AEP>0,1,0),
    PROMOTED_SEP_FLAG = ifelse(TIMES_PROMOTED_SEP>0,1,0))    

PromoHist_rollup <- setDF(setDT(flags3.PromoHist)[setDT(PromoHist_rollup),on=.(AGLTY_INDIV_ID)])
  remove(flags3.PromoHist)

## Store InHome_Date in a separate table for conversion metrics
raw_InHomeDate <- PromoHist %>% select(AGLTY_INDIV_ID,Campaign,Inhome_Date)

## DO TABULATIONS ON NEW FLAGS
attach(PromoHist_rollup)
tabyl(SEP_LOCALAWARE_GA_FLAG) #<1%=1
tabyl(SEP_LOCALEDUC_GA_FLAG)
tabyl(LIST_SOURCE_KBM_FLAG)
tabyl(LIST_SOURCE_EXPERIAN_FLAG)
tabyl(SEGMENT_LATINO_FLAG)
tabyl(SEP_LATINO_DM_FLAG)
# Remove variables
PromoHist_rollup <- PromoHist_rollup %>% select(-SEP_LOCALAWARE_GA_FLAG,-SEP_LOCALEDUC_GA_FLAG,-LIST_SOURCE_KBM_FLAG)
tabyl(AEP_DROP_1_FLAG)
tabyl(AEP_DROP_2_FLAG)
tabyl(AEP_DROP_3_FLAG)
tabyl(AEP_DROP_4_FLAG)
tabyl(AEP_DROP_5_FLAG)
tabyl(AEP_DROP_6_FLAG)
tabyl(AEP_DROP_7_FLAG)
tabyl(AEP_DROP_8_FLAG)
tabyl(SEP_DROP_1_FLAG)
tabyl(SEP_DROP_2_FLAG)
tabyl(SEP_DROP_3_FLAG)
tabyl(SEP_DROP_4_FLAG)
tabyl(SEP_DROP_5_FLAG)
tabyl(SEP_DROP_6_FLAG)
tabyl(SEP_DROP_7_FLAG)
tabyl(SEP_DROP_8_FLAG)
tabyl(SEP_DROP_9_FLAG)
tabyl(TIMES_PROMOTED_AEP)
tabyl(TIMES_PROMOTED_SEP)
tabyl(PROMOTED_AEP_FLAG)
tabyl(PROMOTED_SEP_FLAG)

## Clear and save
remove(PromoHist)

data.table::fwrite(PromoHist_rollup,file='MED_DM_22_Targeting_PH.csv') ## 30 seconds
  remove(PromoHist_rollup)

data.table::fwrite(raw_InHomeDate,file='MED_DM_22_Targeting_PH_IH.csv') ## 30 seconds
  remove(raw_InHomeDate)

##PromoHist_rollup <- data.table::fread(file='MED_DM_22_Targeting_PH.csv',colClasses=c(AGLTY_INDIV_ID="character")) ## 30 seconds
##raw_InHomeDate <- data.table::fread(file='MED_DM_22_Targeting_PH_IH.csv',colClasses=c(AGLTY_INDIV_ID="character")) ## 30 seconds