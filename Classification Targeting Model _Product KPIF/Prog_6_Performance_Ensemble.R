###########################################################################
#                                                                         #
# Program Name: Prog_6_Performance_Ensemble.R                             #
# Date Created: 9/6/2022                                                  #
# Created By: Elsa Haynes (elsa.c.haynes@kp.org)                          #
#                                                                         #
# Ensembles and compares new vs. old model for deck.                      #
#                                                                         #
###########################################################################

# %% Initialize Libraries and Paths
gc()
library(data.table) # Data prep
library(dplyr) # Data prep
library(mltools) # One-hot encoding
`%ni%` <- Negate(`%in%`)

setwd("C:/Users/c156934") # Set file path

# %% Import final DFs
DF_RN <- fread('Final Model Set RW On HIX.csv',colClasses=c(AGLTY_INDIV_ID="character"))
DF_RF <- fread('Final Model Set RW Off HIX.csv',colClasses=c(AGLTY_INDIV_ID="character"))
DF_RW <- setDF(setDT(DF_RN)[setDT(DF_RF),on=.(AGLTY_INDIV_ID)])
remove(DF_RN)
remove(DF_RF)
DF_FN <- fread('Final Model Set FM On HIX.csv',colClasses=c(AGLTY_INDIV_ID="character"))
DF_FF <- fread('Final Model Set FM Off HIX.csv',colClasses=c(AGLTY_INDIV_ID="character"))
DF_FM <- setDF(setDT(DF_FN)[setDT(DF_FF),on=.(AGLTY_INDIV_ID)])
remove(DF_FN)
remove(DF_FF)
# %% Data cleaning
DF_RW <- DF_RW %>%
          filter(FM_TENURE_DY == 0) %>% # Remove for actual scoring
          select(-c(Timing_Main_Flag,Timing_Late_Flag),-contains(c("OE7","OE8","OE9","i.","FM_TENURE"))) %>% # Remove for actual scoring except I and fm
          mutate(CENS_MED_HH_INCM_1k = CENS_MED_HH_INCM_1k/10, # Remove for actual scoring
                 CENS_MED_HOME_VAL_1k = CENS_MED_HOME_VAL_1k/10, # Remove for actual scoring
                 Market_Share_Ind_YOYchg = Market_Share_Ind_YOYchg*100, # Remove for actual scoring
                 Market_Share_Unins_YOYchg = Market_Share_Unins_YOYchg*100, # Remove for actual scoring
                 Market_Share_Unins_FYchg = Market_Share_Unins_FYchg*100, # Remove for actual scoring
                 Market_Share_B2B_FYchg = Market_Share_B2B_FYchg*100, # Remove for actual scoring
                 Market_Share_Medi_5YRchg = Market_Share_Medi_5YRchg*100, # Remove for actual scoring
                 RP_LowestRel_ONHIX_SLV = RP_LowestRel_ONHIX_SLV*100, # Remove for actual scoring
                 RP_LowestIncr_ONHIX_ALL = RP_LowestIncr_ONHIX_ALL*100, # Remove for actual scoring
                 RP_WeightedAvg_OFFHIX_BRZ = RP_WeightedAvg_OFFHIX_BRZ*100, # Remove for actual scoring
                 TAPESTRY_LIFESTYLE = gsub(" ", "", TAPESTRY_LIFESTYLE),
                 TAPESTRY_URBAN = gsub(" ", "", TAPESTRY_URBAN),
                 Region_Flag = Region) %>%
          rename(CENS_MED_HH_INCM_10k = CENS_MED_HH_INCM_1k, # Remove for actual scoring
                 CENS_MED_HOME_VAL_10k = CENS_MED_HOME_VAL_1k, # Remove for actual scoring
                 Market_Share_Medi_3YRchg = Market_Share_Medi_5YRchg, # Remove for actual scoring
                 OE_Season_Flag = OE_Season,
                 MODEL_OWN_RENT_Flag = MODEL_OWN_RENT,
                 TAPLIFE_Flag = TAPESTRY_LIFESTYLE,
                 TAPURBAN_Flag = TAPESTRY_URBAN) %>% 
          rename_with(~gsub("Market_Share", "Market_Size", .x,)) %>% # Remove for actual scoring
          as.data.frame
gc()

DF_FM <- DF_FM %>%
          filter(FM_TENURE_MO > 0) %>% # Remove for actual scoring
          select(-c(Timing_Main_Flag,Timing_Late_Flag),-contains(c("OE7","OE8","OE9","i."))) %>% # Remove for actual scoring except I
          mutate(ESRI_PER_CAPITA_INCOME = ESRI_PER_CAPITA_INCOME/1000, # Remove for actual scoring
                 ESRI_HHINCOME_AVG = ESRI_HHINCOME_AVG/1000, # Remove for actual scoring
                 Market_Share_Unins_YOYchg = Market_Share_Unins_YOYchg*100, # Remove for actual scoring
                 Market_Share_Unins_5YRchg = Market_Share_Unins_5YRchg*100, # Remove for actual scoring
                 Market_Share_Medi_YOYchg = Market_Share_Medi_YOYchg*100, # Remove for actual scoring
                 RP_Lowest_ONHIX_ALL = RP_Lowest_ONHIX_ALL*100, # Remove for actual scoring
                 RP_LowestIncr_OFFHIX_ALL = RP_LowestIncr_OFFHIX_ALL*100, # Remove for actual scoring
                 Cases_OE1_vs_1mo_ago = Cases_OE1_vs_1mo_ago*100, # Remove for actual scoring
                 TAPESTRY_LIFESTYLE = gsub(" ", "", TAPESTRY_LIFESTYLE),
                 TAPESTRY_URBAN = gsub(" ", "", TAPESTRY_URBAN),
                 Region_Flag = Region) %>%
          rename(ESRI_PER_CAPITA_INCOME_1k = ESRI_PER_CAPITA_INCOME, # Remove for actual scoring
                 ESRI_HHINCOME_AVG_1k = ESRI_HHINCOME_AVG, # Remove for actual scoring
                 Market_Share_Unins_3YRchg = Market_Share_Unins_5YRchg, # Remove for actual scoring
                 Cases_OE1_vs_1mo_ago_PctChg = Cases_OE1_vs_1mo_ago, # Remove for actual scoring
                 OE_Season_Flag = OE_Season,
                 MODEL_OWN_RENT_Flag = MODEL_OWN_RENT,
                 TAPLIFE_Flag = TAPESTRY_LIFESTYLE,
                 TAPURBAN_Flag = TAPESTRY_URBAN) %>% 
          rename_with(~gsub("Market_Share", "Market_Size", .x,)) %>% # Remove for actual scoring
          as.data.frame
gc()

# %% One-hot coding
ColsOH       <- c('Region_Flag', 'OE_Season_Flag','MODEL_OWN_RENT_Flag',
                   'TAPLIFE_Flag', 'TAPURBAN_Flag')
OneHotFactor <- function(df, cols) {
  df[cols]   <- lapply(df[cols], as.factor)
  df         <- one_hot(as.data.table(df), cols = cols)
  df         <- as.data.frame(df)
  return(df)
}
DF_RW <- OneHotFactor(DF_RW, ColsOH)
DF_FM <- OneHotFactor(DF_FM, ColsOH)
remove(ColsOH)
names(which(colSums(is.na(DF_RW))>0))
names(which(colSums(is.na(DF_FM))>0))

# %% Set as factors
SetAsFactors <- function(df){
  ColsFlags     <- df %>% 
                    dplyr::select(contains("_Flag", ignore.case = T)) %>%
                    colnames()
  ColsFlags     <- c(ColsFlags)
  ColsChar      <- df %>% 
                    select_if(is.character) %>% 
                    colnames()
  ColsDV        <- df %>% 
                    dplyr::select(contains("Conv", ignore.case = T)) %>% 
                    colnames()
  df[ColsFlags] <- lapply(df[ColsFlags], as.factor)
  df[ColsChar]  <- lapply(df[ColsChar], as.factor)
  df[ColsDV]    <- lapply(df[ColsDV], as.factor)
  str(df)
  return(df)
}
DF_RW <- SetAsFactors(DF_RW)
DF_FM <- SetAsFactors(DF_FM)

# %% Import models
Model_RN <- readRDS("RW_On_Logistic.rds")
Model_RF <- readRDS("RW_Off_Logistic.rds")
Model_FN <- readRDS("FM_On_Logistic.rds")
Model_FF <- readRDS("FM_Off_Logistic.rds")

# %% Score
DF_RW$pred_onhix  <- predict(Model_RN, newdata = DF_RW, type = "response")
DF_RW$pred_offhix <- predict(Model_RF, newdata = DF_RW, type = "response")
DF_FM$pred_onhix  <- predict(Model_FN, newdata = DF_FM, type = "response")
DF_FM$pred_offhix <- predict(Model_FF, newdata = DF_FM, type = "response")

# %% Merge & Ensemble

EnsembleWeights <- function(df){
  df$Conv_Enroll_Flag <- ifelse(df$Conv_Enroll_OffHIX_Flag == 1 |
                                  df$Conv_Enroll_OnHIX_Flag == 1, 1, 0)
  Weights           <- glm(Conv_Enroll_Flag ~ pred_onhix + pred_offhix, data = df, 
                           family = binomial(logit), model = FALSE, y = FALSE) 
  coef_onhix        <- Weights$coefficients[2]
  coef_offhix       <- Weights$coefficients[3]
  coef_on_off       <- cbind(coef_onhix, coef_offhix)
  return(coef_on_off)
}
Coef_RW <- EnsembleWeights(DF_RW)
Coef_FM <- EnsembleWeights(DF_FM)

EnsemblePred <- function(df, coef){
  df$Conv_Enroll_Flag <- ifelse(df$Conv_Enroll_OffHIX_Flag == 1 |
                                  df$Conv_Enroll_OnHIX_Flag == 1, 1, 0)
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
  weight_onhix      <- abs(coef[1]) / (abs(coef[1]) + abs(coef[2]))
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
EnsembleTable <- function(df){
  plot.data     <- df %>% dplyr::select(Conv_Enroll_Flag, 
                                         decile_max, decile_min, decile_mean, decile_weight, 
                                         PRIOR_MODEL_SCORE)
  table.min     <-  plot.data %>% 
                      group_by(decile_min) %>% 
                      summarise(Conversion_Rate_Min = mean(Conv_Enroll_Flag),
                                Conversions_Min = sum(Conv_Enroll_Flag)) %>%
                      rename(Decile=decile_min)
  table.max     <-  plot.data %>% 
                      group_by(decile_max) %>% 
                      summarise(Conversion_Rate_Max = mean(Conv_Enroll_Flag),
                                Conversions_Max = sum(Conv_Enroll_Flag)) %>%
                      rename(Decile=decile_max)
  table.mean    <-  plot.data %>% 
                      group_by(decile_mean) %>% 
                      summarise(Conversion_Rate_Mean = mean(Conv_Enroll_Flag),
                                Conversions_Mean = sum(Conv_Enroll_Flag)) %>%
                      rename(Decile=decile_mean)
  table.weight  <-  plot.data %>% 
                      group_by(decile_weight) %>% 
                      summarise(Conversion_Rate_Weight = mean(Conv_Enroll_Flag),
                                Conversions_Weight = sum(Conv_Enroll_Flag)) %>%
                      rename(Decile=decile_weight)
  table.new     <- merge(table.min,table.max, by = "Decile", all=T)
  table.new     <- merge(table.new,table.mean, by = "Decile", all=T)
  table.new     <- merge(table.new,table.weight, by = "Decile", all=T)
  table.new
  table.old     <- plot.data %>% 
                    group_by(PRIOR_MODEL_SCORE) %>% 
                    summarise(Conversion_Rate_Old = mean(Conv_Enroll_Flag),
                              Conversions_Old = sum(Conv_Enroll_Flag)) %>%
                    rename(Decile=PRIOR_MODEL_SCORE)
  table         <- merge(table.old,table.new, by = "Decile", all=T)
  order         <- c("1","2","3","4","5","6","7","8","9","10","U")
  table$Decile  <- factor(as.character(table$Decile), levels=order)
  table         <- table[order(table$Decile),]
  print(table)
  return(table)
}
gc()
DF_FM    <- EnsemblePred(DF_FM, Coef_FM)
FM.table <- EnsembleTable(DF_FM)
DF_RW    <- EnsemblePred(DF_RW, Coef_RW)
RW.table <- EnsembleTable(DF_RW)
write.table(FM.table, "clipboard", sep="\t")  
write.table(RW.table, "clipboard", sep="\t")  
  
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
DF_FM   <- DF_FM %>% 
            rename(prediction = pred_weight,
                   decile = decile_weight)
DF_RW   <- DF_RW %>% 
            rename(prediction = pred_mean,
                   decile = decile_mean)
DF_FM <- FinalizeEnsemble(DF_FM)
DF_RW <- FinalizeEnsemble(DF_RW)
DF    <- rbind(DF_FM,DF_RW)

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
head(Epsilon.Output)
# Max lengths accepted: AGILITY_INDIVIDUAL_ID (15), MODEL_SCORE_VALUE (26), MODEL_DECILE_VALUE (2), MODEL_PERCENTILE_VALUE (3), 
# TAPESTRY_CODE (2), TAPESTRY_DESC (40), PROBABILITY_SCORE_VALUE (10)
apply(Epsilon.Output, 2, function(x) max(nchar(x))) 

# Check for dupes
dupes <- Epsilon.Output %>% get_dupes(AGILITY_INDIVIDUAL_ID) 
dupes <- merge(x=dupes,y=DF,by.x="AGILITY_INDIVIDUAL_ID",by.y="AGLTY_INDIV_ID") # it's the old_model_decile
Epsilon.Output <- Epsilon.Output %>% distinct(., .keep_all = TRUE) # remove dupes
Epsilon.Output %>% get_dupes(AGILITY_INDIVIDUAL_ID) # re-check for dupes
remove(dupes)

Epsilon.Header <- DF %>%
                  mutate(MODEL_MAINTAINER = 'IMC ANALYTICS',
                         MODEL_CREATOR = 'IMC ANALYTICS',
                         MODEL_DATE = '20220909',
                         BUSINESS_LINE_CD = 'I') %>%
                  rename(MODEL_VERSION_NUM = MODEL_NUMBER,
                         MODEL_DESCRIPTION = MODEL_NAME) %>%
                  select(MODEL_VERSION_NUM,MODEL_DESCRIPTION,MODEL_MAINTAINER,
                         MODEL_CREATOR,MODEL_DATE,BUSINESS_LINE_CD) %>%
                  slice(1)
head(Epsilon.Header)

## Export
data.table::fwrite(Epsilon.Output,file='kais.imsr.20220909.a.NL_KPIF_EM_ENROLL_MODEL.01of01.1.dat',sep='|',col.names = FALSE) #3 minutes
data.table::fwrite(Epsilon.Header,file='kais.mmsr.20220909.a.NL_KPIF_EM_ENROLL_MODEL.01of01.1.dat',sep='|',col.names = FALSE) #3 minutes
remove(Epsilon.Header)
remove(Epsilon.Output) 
remove(Scoring.Data.Combined)