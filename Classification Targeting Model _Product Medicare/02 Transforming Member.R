## NOTES: I created an ODBC connection "WS_EHAYNES" on my computer

library(odbc)
library(RODBC)
library(dplyr)
library(janitor)
library(stringr)
library(data.table)
library(lubridate)

## To navigate the SQL Server schemas
con <- dbConnect(odbc::odbc(), "WS_EHAYNES")
## To pull data from SQL Server
connection <- odbcConnect("WS_EHAYNES")

## For each project table in WS_EHAYNES (MED_DM_22_Targeting).
##     Roll up to one row per AGLTY_INDIV_ID.

raw_Member <- sqlQuery(connection, "select * from MED_DM_22_Targeting_Member") ## 30 seconds

## Fix variable type
raw_Member$AGLTY_INDIV_ID <- as.character(raw_Member$AGLTY_INDIV_ID)

## Remove enrollment after 1/1/2022
Member <- raw_Member %>% filter(ELGB_START_DT <= "2022-01-01")
  remove(raw_Member)

## Import e_Date
raw_InHomeDate<-data.table::fread(file='MED_DM_22_Targeting_PH_IH.csv',colClasses=c(AGLTY_INDIV_ID="character")) ## 1 min
raw_InHomeDate$Inhome_Date <- as.Date(raw_InHomeDate$Inhome_Date)

# Join for prior-membership information (predictive).
Member.vars <- setDF(setDT(Member)[setDT(raw_InHomeDate), on = .(AGLTY_INDIV_ID, ELGB_START_DT < Inhome_Date), nomatch=0,
                           .(AGLTY_INDIV_ID = i.AGLTY_INDIV_ID, 
                             ELGB_START_DT = x.ELGB_START_DT, 
                             Inhome_Date = i.Inhome_Date,
                             Campaign = i.Campaign,
                             MEDICAID_IND = x.MEDICAID_IND,
                             ACCT_ROLE_CD = x.ACCT_ROLE_CD)])
  
## Rollup metrics into vectors for join -- ONLY pre-promotion membership information
Member.vars$SUBSCRIBER_FLAG <- ifelse(Member.vars$ACCT_ROLE_CD=="SU",1,0)
Member.vars$MEDICAID_MBR_FLAG <- ifelse(Member.vars$MEDICAID_IND=="Y",1,0)

Member.vars <- Member.vars %>%
  group_by(AGLTY_INDIV_ID,Campaign) %>%
  summarise_at(vars(SUBSCRIBER_FLAG,MEDICAID_MBR_FLAG),max,na.rm=T) %>%
  ungroup()

tabyl(Member.vars$SUBSCRIBER_FLAG)
tabyl(Member.vars$MEDICAID_MBR_FLAG)

## Cleaning -Inf for those NAs
Member.vars$MEDICAID_MBR_FLAG <- ifelse(Member.vars$MEDICAID_MBR_FLAG==1,1,0)

# Join for Conversion: End product should have ALL Agility IDs/Inhome_Date in AEP and SEP and some rows should have ELGB_START_DT
Member.conv <- setDF(setDT(Member)[setDT(raw_InHomeDate), on = .(AGLTY_INDIV_ID, ELGB_START_DT > Inhome_Date), 
                                   .(AGLTY_INDIV_ID = i.AGLTY_INDIV_ID, 
                                     ELGB_START_DT = x.ELGB_START_DT, 
                                     Inhome_Date = i.Inhome_Date,
                                     Campaign = i.Campaign)])

  remove(Member)

## Conversions: Only 1/1 is allowed as start dates for AEP. 
Member.conv$ELGB_START_DT[Member.conv$Campaign=="AEP" & Member.conv$ELGB_START_DT != "2022-01-01"] <- NA
## Conversions: All dates are allowed for SEP except 1/1.
Member.conv$ELGB_START_DT[Member.conv$Campaign=="SEP" & Member.conv$ELGB_START_DT == "2022-01-01"] <- NA

## Create conversion flags
Member.conv$daysdif <- with(Member.conv,difftime(ELGB_START_DT,Inhome_Date,units=c("days")))
Member.conv$daysdif <- ifelse(is.na(Member.conv$daysdif),0,Member.conv$daysdif)
Member.conv$CONV_ENROLL_AEP_FLAG <- ifelse(Member.conv$Campaign=="AEP" & Member.conv$ELGB_START_DT == "2022-01-01",1,0)
Member.conv$CONV_ENROLL_SEP_60DAY_FLAG <- ifelse(Member.conv$Campaign == "SEP" & Member.conv$daysdif>0 & Member.conv$daysdif<=60,1,0)
Member.conv$CONV_ENROLL_SEP_90DAY_FLAG <- ifelse(Member.conv$Campaign == "SEP" & Member.conv$daysdif>0 & Member.conv$daysdif<=90,1,0)
Member.conv$CONV_ENROLL_SEP_120DAY_FLAG <- ifelse(Member.conv$Campaign == "SEP" & Member.conv$daysdif>0 & Member.conv$daysdif<=120,1,0)
Member.conv$CONV_ENROLL_SEP_180DAY_FLAG <- ifelse(Member.conv$Campaign == "SEP" & Member.conv$daysdif>0 & Member.conv$daysdif<=180,1,0)

# Combine
Member.conv$CONV_ENROLL_60DAY_FLAG <- ifelse(Member.conv$CONV_ENROLL_SEP_60DAY_FLAG == 1 | Member.conv$CONV_ENROLL_AEP_FLAG == 1,1,0)
Member.conv$CONV_ENROLL_90DAY_FLAG <- ifelse(Member.conv$CONV_ENROLL_SEP_90DAY_FLAG == 1 | Member.conv$CONV_ENROLL_AEP_FLAG == 1,1,0)
Member.conv$CONV_ENROLL_120DAY_FLAG <- ifelse(Member.conv$CONV_ENROLL_SEP_120DAY_FLAG == 1 | Member.conv$CONV_ENROLL_AEP_FLAG == 1,1,0)
Member.conv$CONV_ENROLL_180DAY_FLAG <- ifelse(Member.conv$CONV_ENROLL_SEP_180DAY_FLAG == 1 | Member.conv$CONV_ENROLL_AEP_FLAG == 1,1,0)
  
Member.conv <- Member.conv %>% select(-CONV_ENROLL_AEP_FLAG, -CONV_ENROLL_SEP_60DAY_FLAG, -CONV_ENROLL_SEP_90DAY_FLAG, -CONV_ENROLL_SEP_120DAY_FLAG, -CONV_ENROLL_SEP_180DAY_FLAG)
 
## Roll up 60, 90, 120, and 180 days

rollup <- function(data, attrWindow){
  split<-str_split(attrWindow, "_")
  WindowDays <- str_replace(sapply(split, `[`, 3),"DAY","")
  
  ## Experimenting with first touch
  df_name <- paste0('enroll.Member.FirstTouch.', WindowDays)
  temp1 <- data %>%
    filter(.[[attrWindow]]==1) %>%
    group_by(AGLTY_INDIV_ID,Campaign) %>%
    slice_max(daysdif) %>%
    ungroup() %>%
    distinct (AGLTY_INDIV_ID, ELGB_START_DT, Inhome_Date, Campaign, daysdif, CONV_ENROLL_60DAY_FLAG,
              CONV_ENROLL_90DAY_FLAG, CONV_ENROLL_120DAY_FLAG, CONV_ENROLL_180DAY_FLAG)
  
  temp1 <- as.data.frame(temp1)
  assign(df_name, temp1, envir=.GlobalEnv)
  
  plot(temp1$Inhome_Date,temp1$ELGB_START_DT,xlab="In Home Date",ylab="Enrollment Start Date",main=paste0(WindowDays,"-Day Window First Touch")) #exported
  table1 <- table("Mailed"=month(temp1$Inhome_Date),"Enrolled"=month(temp1$ELGB_START_DT))
  assign("table1",table1,envir=.GlobalEnv)
  
  ## Experimenting with last touch
  df_name <- paste0('enroll.Member.LastTouch.', WindowDays)
  temp2 <- data %>%
    filter(.[[attrWindow]]==1) %>%
    group_by(AGLTY_INDIV_ID,Campaign) %>%
    slice_min(daysdif) %>%
    ungroup() %>%
    distinct (AGLTY_INDIV_ID, ELGB_START_DT, Inhome_Date, Campaign, daysdif, CONV_ENROLL_60DAY_FLAG,
              CONV_ENROLL_90DAY_FLAG, CONV_ENROLL_120DAY_FLAG, CONV_ENROLL_180DAY_FLAG)
              
  
  temp2 <- as.data.frame(temp2)
  assign(df_name, temp2, envir=.GlobalEnv)
  
  plot(temp2$Inhome_Date,temp2$ELGB_START_DT,xlab="In Home Date",ylab="Enrollment Start Date",main=paste0(WindowDays,"-Day Window Last Touch")) #exported
  table2 <- table("Mailed"=month(temp2$Inhome_Date),"Enrolled"=month(temp2$ELGB_START_DT))
  assign("table2",table2,envir=.GlobalEnv)
}

rollup(Member.conv,"CONV_ENROLL_60DAY_FLAG")
rollup(Member.conv,"CONV_ENROLL_90DAY_FLAG")
rollup(Member.conv,"CONV_ENROLL_120DAY_FLAG")
rollup(Member.conv,"CONV_ENROLL_180DAY_FLAG")
  
write.table(table1, "clipboard", sep="\t")
write.table(table2, "clipboard", sep="\t")

  remove(Member.conv)

## I like 90-day last touch and 120-day last touch since they maximize enrollments and are evenly distributed,
    # but slightly more concentrated at the beginning of the drop. I will keep these and drop the rest.

enroll.Member <- setDF(funion(setDT(enroll.Member.LastTouch.90),setDT(enroll.Member.LastTouch.120)))

  #No dupes -- one row per AGLTY_INDIV_ID
  enroll.Member[duplicated(enroll.Member,by="AGLTY_INDIV_ID")]
  
    #spot check
    #head(Member[CONV_ENROLL_120DAY_FLAG==1],n=100) %>% distinct(AGLTY_INDIV_ID)
    #ID<-"5000062042381"
    #Member %>% filter(AGLTY_INDIV_ID==ID)
    #enroll.Member.LastTouch.60 %>% filter(AGLTY_INDIV_ID==ID) ##11/26
    #enroll.Member.LastTouch.90 %>% filter(AGLTY_INDIV_ID==ID) ##11/26
    #enroll.Member.LastTouch.120 %>% filter(AGLTY_INDIV_ID==ID) ##11/26
    #enroll.Member.LastTouch.180 %>% filter(AGLTY_INDIV_ID==ID) ##11/26
    #enroll.Member  %>% filter(AGLTY_INDIV_ID==ID) ##11/26
  
  remove(enroll.Member.LastTouch.90)
  remove(enroll.Member.LastTouch.120)
  remove(enroll.Member.FirstTouch.60)
  remove(enroll.Member.FirstTouch.90)
  remove(enroll.Member.FirstTouch.120)
  remove(enroll.Member.FirstTouch.180)
  remove(enroll.Member.LastTouch.60)
  remove(enroll.Member.LastTouch.180)

enroll.Member <- enroll.Member %>% select(-CONV_ENROLL_60DAY_FLAG,-CONV_ENROLL_180DAY_FLAG)
IDs <- unique(raw_InHomeDate,by=c("AGLTY_INDIV_ID","Campaign")) %>% select(AGLTY_INDIV_ID,Campaign)
  remove(raw_InHomeDate)
  
Member.LastTouch <- IDs %>% 
                      left_join(.,enroll.Member,by=c("AGLTY_INDIV_ID","Campaign")) %>%
                      distinct(AGLTY_INDIV_ID,Campaign,CONV_ENROLL_90DAY_FLAG,CONV_ENROLL_120DAY_FLAG)
  remove(IDs)
  remove(enroll.Member)
  
## Append member flags
Member_rollup <- setDF(setDT(Member.vars)[setDT(Member.LastTouch), on = .(AGLTY_INDIV_ID = AGLTY_INDIV_ID, Campaign = Campaign)])
  remove(Member.vars)
  remove(Member.LastTouch)

## Cleaning
Member_rollup$CONV_ENROLL_90DAY_FLAG <- ifelse(is.na(Member_rollup$CONV_ENROLL_90DAY_FLAG),0,Member_rollup$CONV_ENROLL_90DAY_FLAG)
Member_rollup$CONV_ENROLL_120DAY_FLAG <- ifelse(is.na(Member_rollup$CONV_ENROLL_120DAY_FLAG),0,Member_rollup$CONV_ENROLL_120DAY_FLAG)
Member_rollup$SUBSCRIBER_FLAG <- ifelse(is.na(Member_rollup$SUBSCRIBER_FLAG),0,Member_rollup$SUBSCRIBER_FLAG)
Member_rollup$MEDICAID_MBR_FLAG <- ifelse(is.na(Member_rollup$MEDICAID_MBR_FLAG),0,Member_rollup$MEDICAID_MBR_FLAG)

  tabyl(Member_rollup,CONV_ENROLL_90DAY_FLAG,Campaign)
  tabyl(Member_rollup,CONV_ENROLL_120DAY_FLAG,Campaign)
  tabyl(Member_rollup,SUBSCRIBER_FLAG,Campaign)
  tabyl(Member_rollup,MEDICAID_MBR_FLAG,Campaign)

## Split into AEP and SEP sets
Member.AEP <- Member_rollup %>%
                  filter(Campaign=="AEP") %>%
                  distinct(AGLTY_INDIV_ID, .keep_all = TRUE) %>%
                  select(-Campaign)

Member.SEP <- Member_rollup %>%
                  filter(Campaign=="SEP") %>%
                  distinct(AGLTY_INDIV_ID, .keep_all = TRUE) %>%
                  select(-Campaign)

  remove(Member_rollup)

## Export
data.table::fwrite(Member.AEP,file='MED_DM_22_Targeting_MBR_AEP.csv') 
data.table::fwrite(Member.SEP,file='MED_DM_22_Targeting_MBR_SEP.csv') 

  remove(Member.AEP)
  remove(Member.SEP)
  
odbcCloseAll()
dbDisconnect(con)
