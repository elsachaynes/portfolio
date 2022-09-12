###########################################################################
#                                                                         #
# Program Name: Prog_7_Score.R                                            #
# Date Created: 9/8/2022                                                  #
# Created By: Elsa Haynes (elsa.c.haynes@kp.org)                          #
#                                                                         #
# Requires: Prepare input data with "3_1 Data pull for scoring.sas"       #
# Scores KPIF OE EM population.                                           #
#                                                                         #
###########################################################################

# %% Initialize Libraries and Paths
gc()
library(RODBC) # Data pull from SQL server
library(data.table) # Data prep
library(dplyr) # Data prep
library(mltools) # One-hot encoding
library(janitor) # Data validation
`%ni%` <- Negate(`%in%`)

setwd("C:/Users/c156934") # Set file path where models are saved

# %% Import final DF
connection        <- odbcConnect("WS_EHAYNES") # To pull data from SQL Server
DF                <- sqlQuery(connection, "select * from KPIF_EM_23_Scoring_Final")
DF$AGLTY_INDIV_ID <- as.character(DF$AGLTY_INDIV_ID)  
odbcCloseAll()
remove(connection)

# %% Data cleaning
DF <- DF %>%
        filter(Region != "WA") %>% # pretty sure this was a mistake, WA is not part of campaign
        mutate(TAPESTRY_LIFESTYLE = gsub(" ", "", TAPESTRY_LIFESTYLE),
               TAPESTRY_URBAN = gsub(" ", "", TAPESTRY_URBAN),
               Region_Flag = Region) %>%
        rename(KBM_FLAG = KBM_Flag, #oops
               Cases_OE1_vs_1mo_ago_PctChg = Cases_OE1_vs_1mo_ago, # also oops
               MODEL_OWN_RENT_Flag = MODEL_OWN_RENT,
               TAPLIFE_Flag = TAPESTRY_LIFESTYLE,
               TAPURBAN_Flag = TAPESTRY_URBAN) %>%
        as.data.frame
gc()

# %% One-hot coding
ColsOH       <- c('Region_Flag','MODEL_OWN_RENT_Flag','TAPLIFE_Flag', 
                  'TAPURBAN_Flag')
DF[ColsOH]   <- lapply(DF[ColsOH], as.factor)
DF           <- one_hot(as.data.table(DF), cols = ColsOH)
DF           <- as.data.frame(DF)
remove(ColsOH)

# %% Set as factors
ColsFlags     <- DF %>% 
                  dplyr::select(contains("_Flag", ignore.case = T)) %>%
                  colnames()
ColsFlags     <- c(ColsFlags)
DF[ColsFlags] <- lapply(DF[ColsFlags], as.factor)
str(DF)
remove(ColsFlags)

# %% Imputation
replaceWithMedian <- function(var){
  var <- ifelse(is.na(var),median(var,na.rm=T),var)
}
listNumeric <- unlist(lapply(DF, is.numeric)) 
colnames(DF[listNumeric])
DF[listNumeric] <- lapply(DF[listNumeric], replaceWithMedian)
remove(listNumeric)
names(which(colSums(is.na(DF))>0))

# %% Import models
Model_RN <- readRDS("RW_On_Logistic.rds")
Model_RF <- readRDS("RW_Off_Logistic.rds")
Model_FN <- readRDS("FM_On_Logistic.rds")
Model_FF <- readRDS("FM_Off_Logistic.rds")

# %% Score
FM <- DF %>% filter(Audience == "FM")
RW <- DF %>% filter(Audience == "RNC/WPL")
RW$pred_onhix  <- predict(Model_RN, newdata = RW, type = "response")
RW$pred_offhix <- predict(Model_RF, newdata = RW, type = "response")
FM$pred_onhix  <- predict(Model_FN, newdata = FM, type = "response")
FM$pred_offhix <- predict(Model_FF, newdata = FM, type = "response")
remove(Model_FF, Model_FN, Model_RF, Model_RN)

# %% Merge & Ensemble
Decile <- function(df, coef_onhix, coef_offhix){
  # by max prediction
  df$pred_max       <- pmax(df$pred_onhix, df$pred_offhix)
  df                <- df %>% 
    group_by(Region) %>% 
    mutate(decile_max = ntile(-pred_max, 10)) %>% 
    ungroup()
  df$decile_max     <- factor(df$decile_max, 
                              levels = c("1","2","3","4","5","6","7","8","9","10"))
  # by mean
  df$pred_mean      <- rowMeans(subset(df, select = c(pred_onhix, pred_offhix)), na.rm=T) 
  df                <- df %>% 
                        group_by(Region) %>% 
                        mutate(decile_mean = ntile(-pred_mean, 10)) %>% 
                        ungroup()
  df$decile_mean    <- factor(df$decile_mean, 
                              levels = c("1","2","3","4","5","6","7","8","9","10"))
  # by weights determined through regression
  weight_onhix      <- abs(coef_onhix) / (abs(coef_onhix) + abs(coef_offhix))
  weight_offhix     <- 1 - weight_onhix
  df$pred_weight    <- (df$pred_offhix * weight_offhix) + (df$pred_onhix * weight_onhix)
  df                <- df %>% 
                        group_by(Region) %>% 
                        mutate(decile_weight = ntile(-pred_weight, 10)) %>% 
                        ungroup()
  df$decile_weight  <- factor(df$decile_weight, 
                              levels = c("1","2","3","4","5","6","7","8","9","10"))
  # by min decile
  df                <- df %>% 
                        group_by(Region) %>% 
                        mutate(decile_on = ntile(-pred_onhix, 10),
                               decile_off = ntile(-pred_offhix, 10)) %>% 
                        ungroup()
  df$decile_min     <- pmin(df$decile_on, df$decile_off)
  df                <- df %>% 
                        group_by(Region) %>% 
                        mutate(decile_min = ntile(decile_min, 10)) %>% 
                        ungroup()
  df$decile_min     <- factor(df$decile_min, 
                              levels = c("1","2","3","4","5","6","7","8","9","10"))
  
  return(df)
}

FM    <- Decile(FM, 51.92696, 72.32238)
RW    <- Decile(RW, 78.31125, 61.39287)
DF    <- rbind(FM,RW)

# %% Save a backup version of the full raw data plus scores
MODEL_NUMBER     <- DF$MODEL_NUMBER[1]
MODEL_NAME       <- DF$MODEL_NAME[1]
MODEL_DATE       <- strftime(Sys.Date(),'%Y%m%d')
DF$FINAL_DECILE  <- ifelse(DF$Audience=="FM", DF$decile_weight, DF$decile_mean)
DF$FINAL_PREDICT <- ifelse(DF$Audience=="FM", DF$pred_weight, DF$pred_mean)
data.table::fwrite(DF,file='Final Model Score OE 2023 KPIF EM.csv') 

# %% Finalize Chosen Ensemble Method
FinalizeEnsemble <- function(df){
  df    <- df %>% 
            group_by(Region) %>% 
            mutate(percentile = ntile(-prediction, 100)) %>% 
            ungroup()
  df    <- df %>% 
            dplyr::select(AGLTY_INDIV_ID, prediction, decile, percentile)
  return(df)
}
FM <- FM %>% 
        rename(prediction = pred_weight,
               decile = decile_weight)
RW <- RW %>% 
        rename(prediction = pred_mean,
               decile = decile_mean)
FM <- FinalizeEnsemble(FM)
RW <- FinalizeEnsemble(RW)
DF <- rbind(FM,RW)
remove(FM, RW)

# %% Format for upload
Epsilon.Output <- DF %>% 
                  mutate(PROBABILITY_SCORE_VALUE = round(prediction,2),
                         TAPESTRY_CODE = NA,
                         TAPESTRY_DESC = NA) %>%
                  rename(AGILITY_INDIVIDUAL_ID = AGLTY_INDIV_ID,
                         MODEL_SCORE_VALUE = prediction,
                         MODEL_DECILE_VALUE = decile,
                         MODEL_PERCENTILE_VALUE = percentile) %>%
                  select(AGILITY_INDIVIDUAL_ID,MODEL_SCORE_VALUE,
                         MODEL_DECILE_VALUE,MODEL_PERCENTILE_VALUE,TAPESTRY_CODE,
                         TAPESTRY_DESC,PROBABILITY_SCORE_VALUE)
Epsilon.Header <- DF %>%
                  mutate(MODEL_MAINTAINER = 'IMC ANALYTICS',
                         MODEL_CREATOR = 'IMC ANALYTICS',
                         MODEL_DATE = MODEL_DATE,
                         MODEL_VERSION_NUM = MODEL_NUMBER,
                         MODEL_DESCRIPTION = MODEL_NAME,
                         BUSINESS_LINE_CD = 'I') %>%
                  select(MODEL_VERSION_NUM,MODEL_DESCRIPTION,MODEL_MAINTAINER,
                         MODEL_CREATOR,MODEL_DATE,BUSINESS_LINE_CD) %>%
                  slice(1)

# %% Validate
head(Epsilon.Output)
head(Epsilon.Header)
# Max lengths accepted: AGILITY_INDIVIDUAL_ID (15), MODEL_SCORE_VALUE (26), 
#  MODEL_DECILE_VALUE (2), MODEL_PERCENTILE_VALUE (3), TAPESTRY_CODE (2),
#  TAPESTRY_DESC (40), PROBABILITY_SCORE_VALUE (10)
apply(Epsilon.Output, 2, function(x) max(nchar(x))) 
# Check for dupes
dupes <- Epsilon.Output %>% get_dupes(AGILITY_INDIVIDUAL_ID) 
dupes <- merge(x=dupes, y=DF,
               by.x="AGILITY_INDIVIDUAL_ID",
               by.y="AGLTY_INDIV_ID")
Epsilon.Output <- Epsilon.Output %>% distinct(., .keep_all = TRUE) # remove dupes
Epsilon.Output %>% get_dupes(AGILITY_INDIVIDUAL_ID) # re-check for dupes
remove(dupes)

# %% Export
data.table::fwrite(Epsilon.Output,file='kais.imsr.20220912.a.NL_KPIF_EM_ENROLL_MODEL.01of01.1.dat',sep='|',col.names = FALSE) 
data.table::fwrite(Epsilon.Header,file='kais.mmsr.20220912.a.NL_KPIF_EM_ENROLL_MODEL.01of01.1.dat',sep='|',col.names = FALSE)
remove(Epsilon.Header, Epsilon.Output, DF) 
