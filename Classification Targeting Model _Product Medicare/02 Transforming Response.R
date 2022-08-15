## NOTES: I created an ODBC connection "WS_EHAYNES" on my computer
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

raw_RespILMR <- sqlQuery(connection, "select * from MED_DM_22_Targeting_RespILMR")
raw_RespILR <- sqlQuery(connection, "select * from MED_DM_22_Targeting_RespILR")

## Fix variable type
RespILMR <- raw_RespILMR
RespILR <- raw_RespILR

RespILMR$AGLTY_INDIV_ID <- as.character(raw_RespILMR$AGLTY_INDIV_ID) 
RespILR$AGLTY_INDIV_ID <- as.character(raw_RespILR$AGLTY_INDIV_ID) 

## Rename for standardization & change to date type
RespILMR$Response_Date <- as.Date(RespILMR$ACTVY_START_DT)
RespILR$Response_Date <- as.Date(RespILR$TP_START_DT)

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
Resp <- merge(RespILMR,RespILR,all=TRUE)

  head(Resp)
  remove(raw_RespILR)
  remove(raw_RespILMR)
  remove(RespILR)
  remove(RespILMR)
  
  ### plot responses
  theme_set(theme_minimal())
  plotdata <- Resp %>% 
     filter(year(Response_Date) >= 2019) %>%
      mutate(Response_Week = week(Response_Date),
             Response_Year = as.character(year(Response_Date))) %>%
      group_by(Response_Year,Response_Week) %>% 
      summarise(n=n()) %>%
      arrange(Response_Year,Response_Week) %>%
      ungroup()
  
  p <- ggplot(data = plotdata, aes(x = Response_Week, y = n)) +
    geom_area(aes(color = Response_Year, fill = Response_Year), 
              alpha = 0.5, position = position_dodge(0.8))
  p + labs(title="Response volume by week YoY",
           x="Response week", y="Responses")
  
  remove(plotdata)
  remove(p)

## Join to InHomeDate
raw_InHomeDate<-data.table::fread(file='MED_DM_22_Targeting_PH_IH.csv',colClasses=c(AGLTY_INDIV_ID="character")) ## 30 seconds
raw_InHomeDate$Inhome_Date <- as.Date(raw_InHomeDate$Inhome_Date)

# Join for Conversion: End product should have ALL Agility IDs/Inhome_Date in AEP and SEP and some rows should have Response_Date
Resp.conv <- setDF(setDT(Resp)[setDT(raw_InHomeDate), on = .(AGLTY_INDIV_ID, Response_Date >= Inhome_Date), 
                           .(AGLTY_INDIV_ID = i.AGLTY_INDIV_ID, 
                             Response_Date = x.Response_Date, 
                             Inhome_Date = i.Inhome_Date,
                             Campaign = i.Campaign)])

## Conversions: Only 10/1-12/7 are allowed as response dates for AEP. 
Resp.conv$Response_Date[Resp.conv$Campaign=="AEP" & (Resp.conv$Response_Date > "2021-12-07" | Resp.conv$Response_Date < "2021-10-01")] <- NA
## Conversions: All dates except 10/1-12/7 are allowed for SEP.
Resp.conv$Response_Date[Resp.conv$Campaign=="SEP" & Resp.conv$Response_Date <= "2021-12-07" & Resp.conv$Response_Date >= "2021-10-01"] <- NA

## Create conversion flags
Resp.conv$daysdif <- with(Resp.conv,difftime(Response_Date,Inhome_Date,units=c("days")))
Resp.conv$daysdif <- ifelse(is.na(Resp.conv$daysdif),0,Resp.conv$daysdif)
## Conversion within 30 days flag
## Conversion within 60 days flag
Resp.conv$CONV_RESP_30DAY_FLAG <- ifelse(Resp.conv$daysdif>0 & Resp.conv$daysdif<=30,1,0)
Resp.conv$CONV_RESP_60DAY_FLAG <- ifelse(Resp.conv$daysdif>0 & Resp.conv$daysdif<=60,1,0)

## Roll up 30 and 60 days

rollup <- function(data, attrWindow){
  split<-str_split(attrWindow, "_")
  WindowDays <- str_replace(sapply(split, `[`, 3),"DAY","")
  
  ## Experimenting with first touch
  df_name <- paste0('Resp.Conv.FirstTouch.', WindowDays)
  temp1 <- data %>%
    filter(.[[attrWindow]]==1) %>%
    group_by(AGLTY_INDIV_ID,Campaign) %>%
    slice_max(daysdif) %>%
    distinct(AGLTY_INDIV_ID, Response_Date, Inhome_Date, Campaign, daysdif,
             CONV_RESP_30DAY_FLAG,CONV_RESP_60DAY_FLAG) %>%
    ungroup()
  
  temp1 <- as.data.frame(temp1)
  assign(df_name, temp1, envir=.GlobalEnv)
  
  plot(temp1$Inhome_Date,temp1$Response_Date,xlab="In Home Date",ylab="Response Date",main=paste0(WindowDays,"-Day Window First Touch")) #exported
  table1 <- table("Mailed"=month(temp1$Inhome_Date),"Responded"=month(temp1$Response_Date))
  assign("table1",table1,envir=.GlobalEnv)
  
  ## Experimenting with last touch
  df_name <- paste0('Resp.Conv.LastTouch.', WindowDays)
  temp2 <- data %>%
    filter(.[[attrWindow]]==1) %>%
    group_by(AGLTY_INDIV_ID,Campaign) %>%
    slice_min(daysdif) %>%
    distinct(AGLTY_INDIV_ID, Response_Date, Inhome_Date, Campaign, daysdif,
             CONV_RESP_30DAY_FLAG,CONV_RESP_60DAY_FLAG) %>%
    ungroup()
  
  temp2 <- as.data.frame(temp2)
  assign(df_name, temp2, envir=.GlobalEnv)
  
  plot(temp2$Inhome_Date,temp2$Response_Date,xlab="In Home Date",ylab="Response Date",main=paste0(WindowDays,"-Day Window Last Touch")) #exported
  table2 <- table("Mailed"=month(temp2$Inhome_Date),"Enrolled"=month(temp2$Response_Date))
  assign("table2",table2,envir=.GlobalEnv)
}

rollup(Resp.conv,"CONV_RESP_30DAY_FLAG")
rollup(Resp.conv,"CONV_RESP_60DAY_FLAG")

write.table(table1, "clipboard", sep="\t")
write.table(table2, "clipboard", sep="\t")

  remove(Resp.conv)

## I like 30-day last touch and 60-day last touch since they maximize responses and are evenly distributed,
# but slightly more concentrated at the beginning of the drop. I will keep these and drop the rest.

Resp.conv <- setDF(funion(setDT(Resp.Conv.LastTouch.30),setDT(Resp.Conv.LastTouch.60)))

#No dupes -- one row per AGLTY_INDIV_ID
Resp.conv[duplicated(Resp.conv,by="AGLTY_INDIV_ID")]

#spot check
#head(setDT(Resp.conv)[CONV_RESP_60DAY_FLAG==1],n=100) %>% distinct(AGLTY_INDIV_ID)
#ID<-"5000001610404"
#Resp %>% filter(AGLTY_INDIV_ID==ID)
#Resp.Conv.LastTouch.30 %>% filter(AGLTY_INDIV_ID==ID) ##11/26
#Resp.Conv.LastTouch.60 %>% filter(AGLTY_INDIV_ID==ID) ##11/26
#Resp.Conv.FirstTouch.30 %>% filter(AGLTY_INDIV_ID==ID) ##11/26
#Resp.Conv.FirstTouch.60 %>% filter(AGLTY_INDIV_ID==ID) ##11/26

  remove(enroll.Member.LastTouch.30)
  remove(enroll.Member.LastTouch.60)
  remove(Resp.Conv.FirstTouch.30)
  remove(Resp.Conv.FirstTouch.60)

## Rollup
IDs <- unique(raw_InHomeDate,by=c("AGLTY_INDIV_ID","Campaign")) %>% select(AGLTY_INDIV_ID,Campaign)
remove(raw_InHomeDate)

Resp.combined <- IDs %>% 
  left_join(.,Resp.conv,by=c("AGLTY_INDIV_ID","Campaign")) %>%
  distinct(AGLTY_INDIV_ID,Campaign,CONV_RESP_30DAY_FLAG,CONV_RESP_60DAY_FLAG)
remove(IDs)

  remove(Resp.conv)

## Cleaning
Resp.combined$CONV_RESP_30DAY_FLAG <- ifelse(is.na(Resp.combined$CONV_RESP_30DAY_FLAG),0,Resp.combined$CONV_RESP_30DAY_FLAG)
Resp.combined$CONV_RESP_60DAY_FLAG <- ifelse(is.na(Resp.combined$CONV_RESP_60DAY_FLAG),0,Resp.combined$CONV_RESP_60DAY_FLAG)

tabyl(Resp.combined,Campaign,CONV_RESP_30DAY_FLAG)
tabyl(Resp.combined,Campaign,CONV_RESP_60DAY_FLAG)

## Split into AEP and SEP sets
Resp.AEP <- Resp.combined %>%
  filter(Campaign=="AEP") %>%
  distinct(AGLTY_INDIV_ID, .keep_all = TRUE) %>%
  select(-Campaign)

Resp.SEP <- Resp.combined %>%
  filter(Campaign=="SEP") %>%
  distinct(AGLTY_INDIV_ID, .keep_all = TRUE) %>%
  select(-Campaign)

remove(Resp.combined)

## Export
data.table::fwrite(Resp.AEP,file='MED_DM_22_Targeting_RESP_AEP.csv') 
data.table::fwrite(Resp.SEP,file='MED_DM_22_Targeting_RESP_SEP.csv') 

remove(Resp.AEP)
remove(Resp.SEP)

odbcCloseAll()
dbDisconnect(con)
