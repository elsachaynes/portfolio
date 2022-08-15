###########################################################################
#                                                                         #
#                           Model Scoring                                 #
#                                                                         #
###########################################################################

library(odbc)
library(RODBC)
library(janitor)
library(dplyr)
library(caret)
library(randomForest)
library(data.table)

## Import Scoring Data: 4,611,528 records
connection <- odbcConnect("WS_EHAYNES") # To pull data from SQL Server
Scoring.Data <- sqlQuery(connection, "select * from MED_DM_22_Scoring_Final")
Scoring.Data$AGLTY_INDIV_ID <- as.character(Scoring.Data$AGLTY_INDIV_ID)  
odbcCloseAll()
remove(connection)

## Clean variables and replace missing

  # Translate variables into flags where 1=Y
  createFlag <- function(var){
    var <- ifelse(var=="Y",1,0)
  }
  flagList <- c("ONE_PER_ADDR_IND","UNIT_NBR_PRSN_IND")
  tabyl(Scoring.Data$ONE_PER_ADDR_IND)
  tabyl(Scoring.Data$UNIT_NBR_PRSN_IND)
  Scoring.Data[flagList] <- lapply(Scoring.Data[flagList],createFlag)
  tabyl(Scoring.Data$ONE_PER_ADDR_IND)
  tabyl(Scoring.Data$UNIT_NBR_PRSN_IND)
    remove(flagList)
    remove(createFlag)
  
  # Replace with U for character variables
  replaceWithU <- function(var){
    var <- ifelse(is.na(var),"U",var)
  }
  listChar <- c("Region","SUB_REGN_CD","SVC_AREA_NM",
                "TAPESTRY_SEGMENT","TAPESTRY_LIFESTYLE","TAPESTRY_URBAN")
  Scoring.Data[listChar] <- lapply(Scoring.Data[listChar],replaceWithU)
    remove(listChar)
    remove(replaceWithU)
  
  # replace numeric NA with 0 for specific variables
  replaceWithZero <- function(var){
    var <- ifelse(is.na(var),0,var)
  }
  listNAtoZero <- c("LIST_SOURCE_EXPERIAN_FLAG","SEP_LATINO_DM_FLAG","SEP_DROP_1_FLAG",
                    "SEP_DROP_2_FLAG","SEP_DROP_3_FLAG","SEP_DROP_4_FLAG","SEP_DROP_5_FLAG",
                    "SEP_DROP_6_FLAG","KBM_Flag","PROMOTED_SEP_FLAG")
  Scoring.Data[listNAtoZero] <- lapply(Scoring.Data[listNAtoZero],replaceWithZero)
    remove(listNAtoZero)
    remove(replaceWithZero)

  # Misc cleaning
    
  Scoring.Data$KBM_Flag <- factor(Scoring.Data$KBM_Flag, levels = c("0","1"))
  Scoring.Data$Campaign <- factor(Scoring.Data$Campaign, levels = c("AEP","SEP"))
  Scoring.Data$LIST_SOURCE_EXPERIAN_FLAG <- factor(Scoring.Data$LIST_SOURCE_EXPERIAN_FLAG, levels = c("0","1"))
  Scoring.Data$SEP_LATINO_DM_FLAG <- factor(Scoring.Data$SEP_LATINO_DM_FLAG, levels = c("0","1"))
  
  Scoring.Data$Old_Model_Decile <- factor(Scoring.Data$Old_Model_Decile, levels = c("1","2","3","4","5","6","7","8","9","10","U"))
  tabyl(Scoring.Data$Old_Model_Decile)
  
  tabyl(Scoring.Data$HMOWN_STAT_CD)
  Scoring.Data$HOMEOWNER_CD <- ifelse(Scoring.Data$HMOWN_STAT_CD %in% c("R","T"),"Renter","U")
  Scoring.Data$HOMEOWNER_CD <- ifelse(Scoring.Data$HMOWN_STAT_CD %in% c("P","Y"),"Owner",Scoring.Data$HOMEOWNER_CD)
  Scoring.Data <- Scoring.Data %>% dplyr::select(-HMOWN_STAT_CD)
  tabyl(Scoring.Data$HOMEOWNER_CD)
  
  tabyl(Scoring.Data$LEN_RES_CD)
  Scoring.Data$LENGTH_RESID_BIN <- ifelse(Scoring.Data$LEN_RES_CD<=3,"0-3","") 
  Scoring.Data$LENGTH_RESID_BIN <- ifelse(Scoring.Data$LEN_RES_CD<=10 & Scoring.Data$LEN_RES_CD>3,"4-10",Scoring.Data$LENGTH_RESID_BIN)
  Scoring.Data$LENGTH_RESID_BIN <- ifelse(Scoring.Data$LEN_RES_CD>10 & Scoring.Data$LEN_RES_CD!=99,"11+",Scoring.Data$LENGTH_RESID_BIN)
  Scoring.Data$LENGTH_RESID_BIN <- ifelse(Scoring.Data$LEN_RES_CD==99,"U",Scoring.Data$LENGTH_RESID_BIN)
  Scoring.Data$LENGTH_RESID_BIN <- factor(Scoring.Data$LENGTH_RESID_BIN, levels = c("0-3","4-10","11+","U"))
  Scoring.Data <- Scoring.Data %>% dplyr::select(-LEN_RES_CD)
  tabyl(Scoring.Data$LENGTH_RESID_BIN)
  
  tabyl(Scoring.Data$IMAGE_MAIL_ORD_BYR_CD)
  tabyl(Scoring.Data$MAIL_ORD_RSPDR_CD)
  Scoring.Data$MAIL_ORDER_BUYER_M <- ifelse(Scoring.Data$IMAGE_MAIL_ORD_BYR_CD=="M",1,0)
  Scoring.Data$MAIL_ORDER_BUYER <- ifelse(Scoring.Data$MAIL_ORD_RSPDR_CD %in% c("M","Y"),1,0)
  Scoring.Data <- Scoring.Data %>% dplyr::select(-IMAGE_MAIL_ORD_BYR_CD,-MAIL_ORD_RSPDR_CD)
  tabyl(Scoring.Data$MAIL_ORDER_BUYER_M)
  tabyl(Scoring.Data$MAIL_ORDER_BUYER)
  
  tabyl(Scoring.Data$SCORE_4)
  Scoring.Data$MEXICO_CO_ORIGIN_FLAG <- ifelse(Scoring.Data$SCORE_4==1,1,0)
  Scoring.Data <- Scoring.Data %>% dplyr::select(-SCORE_4)
  tabyl(Scoring.Data$MEXICO_CO_ORIGIN_FLAG)
  
  tabyl(Scoring.Data$PRSN_CHILD_IND)
  Scoring.Data$PRSN_CHILD_IND <- ifelse(Scoring.Data$PRSN_CHILD_IND %in% c("P","Y"),1,0) 
  tabyl(Scoring.Data$PRSN_CHILD_IND)
  
  tabyl(Scoring.Data$ADDR_VRFN_CD)
  Scoring.Data$ADDR_VRFN_CD <- ifelse(is.na(Scoring.Data$ADDR_VRFN_CD),"00",Scoring.Data$ADDR_VRFN_CD)
  tabyl(Scoring.Data$ADDR_VRFN_CD)
  
  ## Set IV as factors
  ListFactors.AD <- c("Region","SUB_REGN_CD","SVC_AREA_NM")
  ListFactors.PH <- c("PROMOTED_SEP_FLAG","LIST_SOURCE_EXPERIAN_FLAG","SEP_LATINO_DM_FLAG","Campaign",
                      "MODEL_NAME","MODEL_NUMBER","Old_Model_Decile",
                      "SEP_DROP_1_FLAG","SEP_DROP_2_FLAG","SEP_DROP_3_FLAG","SEP_DROP_4_FLAG",
                      "SEP_DROP_5_FLAG","SEP_DROP_6_FLAG")
  ListFactors.TAP <- c("TAPESTRY_SEGMENT","TAPESTRY_LIFESTYLE","TAPESTRY_URBAN")
  ListFactors.KBM <- c("ADDR_VRFN_CD","HOMEOWNER_CD","ONE_PER_ADDR_IND","PRSN_CHILD_IND","UNIT_NBR_PRSN_IND",
                       "KBM_Flag","MEXICO_CO_ORIGIN_FLAG","LENGTH_RESID_BIN",
                       "MAIL_ORDER_BUYER","MAIL_ORDER_BUYER_M")
  Scoring.Data[ListFactors.AD] <- lapply(Scoring.Data[ListFactors.AD], as.factor)
  Scoring.Data[ListFactors.PH] <- lapply(Scoring.Data[ListFactors.PH], as.factor)
  Scoring.Data[ListFactors.TAP] <- lapply(Scoring.Data[ListFactors.TAP], as.factor)
  Scoring.Data[ListFactors.KBM] <- lapply(Scoring.Data[ListFactors.KBM], as.factor)
  str(Scoring.Data)
    remove(ListFactors.AD)
    remove(ListFactors.KBM)
    remove(ListFactors.PH)
    remove(ListFactors.TAP)
  
  # Cleaning - fill missing with median
  replaceWithMedian <- function(var){
    var <- ifelse(is.na(var),median(var,na.rm=T),var)
  }
  listNumeric <- unlist(lapply(Scoring.Data, is.numeric))  
  Scoring.Data[listNumeric] <- lapply(Scoring.Data[listNumeric],replaceWithMedian)
    remove(listNumeric)
    remove(replaceWithMedian)
    
  # Check for missing data
  apply(is.na(Scoring.Data), 2, which)

## ROC-only subset
  
  Scoring.Data.ROC <- Scoring.Data %>% filter(Region %in% c("MAS","NW")) 
  Scoring.Data <- Scoring.Data %>% filter(!Region %in% c("MAS","NW")) 
  
## Import models

  # National Model
  Log <- readRDS("M1_Log.rds")
  Log.cutpoint <- readRDS("M1_Log_cutpoint.rds")
  
  RF.ROC <- readRDS("M8_rfROC.rds")
  RF.ROC.cutpoint <- readRDS("M8_rfROC_cutpoint.rds")
  
## Score
  
  # CANC, CASC, CO, GA, HI
  Scoring.Data$prediction <- predict(Log, newdata = Scoring.Data, type = "response")
  
  # MAS, NW
  Scoring.Data.ROC$prediction <- predict(RF.ROC, newdata = Scoring.Data.ROC, type = "prob")[,2]
    remove(Log)
    remove(RF.ROC)
  
  # Combine
  Scoring.Data.Combined <- rbind(Scoring.Data,Scoring.Data.ROC)
    remove(Scoring.Data)
    remove(Scoring.Data.ROC)
  
 # Group into deciles
    
  Scoring.Data.Combined <- Scoring.Data.Combined %>% group_by(Region) %>% mutate(decile_region = ntile(-prediction, 10)) %>% ungroup()
  Scoring.Data.Combined <- Scoring.Data.Combined %>% group_by(SUB_REGN_CD) %>% mutate(decile_subregion = ntile(-prediction, 10)) %>% ungroup()
  Scoring.Data.Combined <- Scoring.Data.Combined %>% group_by(SVC_AREA_NM) %>% mutate(decile_svc = ntile(-prediction, 10)) %>% ungroup()
  
  Scoring.Data.Combined$decile_region <- factor(Scoring.Data.Combined$decile_region, levels = c("1","2","3","4","5","6","7","8","9","10"))
  Scoring.Data.Combined$decile_subregion <- factor(Scoring.Data.Combined$decile_subregion, levels = c("1","2","3","4","5","6","7","8","9","10"))
  Scoring.Data.Combined$decile_svc <- factor(Scoring.Data.Combined$decile_svc, levels = c("1","2","3","4","5","6","7","8","9","10"))
  
  # I will use decile_region. Get percentile.
  Scoring.Data.Combined <- Scoring.Data.Combined %>% group_by(Region) %>% mutate(percentile_region = ntile(-prediction, 100)) %>% ungroup()
  
## Format for upload
  Epsilon.Output <- Scoring.Data.Combined %>% 
                        mutate(PROBABILITY_SCORE_VALUE = round(prediction,2),
                               TAPESTRY_CODE = NA,
                               TAPESTRY_DESC = NA) %>%
                        rename(AGILITY_INDIVIDUAL_ID = AGLTY_INDIV_ID,
                               MODEL_SCORE_VALUE = prediction,
                               MODEL_DECILE_VALUE = decile_region,
                               MODEL_PERCENTILE_VALUE = percentile_region) %>%
                        select(AGILITY_INDIVIDUAL_ID,MODEL_SCORE_VALUE,MODEL_DECILE_VALUE,MODEL_PERCENTILE_VALUE,TAPESTRY_CODE,TAPESTRY_DESC,PROBABILITY_SCORE_VALUE)
  head(Epsilon.Output)
  # Max lengths accepted: AGILITY_INDIVIDUAL_ID (15), MODEL_SCORE_VALUE (26), MODEL_DECILE_VALUE (2), MODEL_PERCENTILE_VALUE (3), 
    # TAPESTRY_CODE (2), TAPESTRY_DESC (40), PROBABILITY_SCORE_VALUE (10)
  apply(Epsilon.Output, 2, function(x) max(nchar(x))) 
  
  # Check for dupes
  dupes <- Epsilon.Output %>% get_dupes(AGILITY_INDIVIDUAL_ID) 
    dupes <- merge(x=dupes,y=Scoring.Data.Combined,by.x="AGILITY_INDIVIDUAL_ID",by.y="AGLTY_INDIV_ID") # it's the old_model_decile
  Epsilon.Output <- Epsilon.Output %>% distinct(., .keep_all = TRUE) # remove dupes
  Epsilon.Output %>% get_dupes(AGILITY_INDIVIDUAL_ID) # re-check for dupes
    remove(dupes)
  
  Epsilon.Header <- Scoring.Data.Combined %>%
                        mutate(MODEL_MAINTAINER = 'IMC ANALYTICS',
                               MODEL_CREATOR = 'IMC ANALYTICS',
                               MODEL_DATE = '20220531',
                               BUSINESS_LINE_CD = 'M') %>%
                        rename(MODEL_VERSION_NUM = MODEL_NUMBER,
                               MODEL_DESCRIPTION = MODEL_NAME) %>%
                        select(MODEL_VERSION_NUM,MODEL_DESCRIPTION,MODEL_MAINTAINER,MODEL_CREATOR,MODEL_DATE,BUSINESS_LINE_CD) %>%
                        slice(1)
  head(Epsilon.Header)
  
## Export
  data.table::fwrite(Scoring.Data.Combined,file='MED_DM_22_Scoring_Final.csv') #3 minutes
  data.table::fwrite(Epsilon.Output,file='kais.imsr.20220531.a.NL_MEDICARE_DM_RESPONSE_MODEL.01of01.1.dat',sep='|',col.names = FALSE) #3 minutes
  data.table::fwrite(Epsilon.Header,file='kais.mmsr.20220531.a.NL_MEDICARE_DM_RESPONSE_MODEL.01of01.1.dat',sep='|',col.names = FALSE) #3 minutes
    remove(Epsilon.Header)
    remove(Epsilon.Output) 
    remove(Scoring.Data.Combined)
    