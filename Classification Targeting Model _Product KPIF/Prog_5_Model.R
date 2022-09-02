###########################################################################
#                                                                         #
# Program Name: Prog_5_Model.R                                            #
# Date Created: 8/12/2022                                                 #
# Created By: Elsa Haynes (elsa.c.haynes@kp.org)                          #
#                                                                         #
# Uses final datasets to predict conversion in a decision tree.           #
#                                                                         #
###########################################################################

# %% Initialize Libraries and Paths

library(data.table) # Data prep
library(dplyr) # Data prep
library(janitor) # Tabulation
library(ROSE) # Over/Under Sampling
library(DMwR) # SMOTE Sampling
library(cutpointr) # Finding the optimal cutpoint for GOF
library(car) # vif (multicollinearity)
library(ROCR) # Predictions
library(rpart) # Building Decision Trees
library(rpart.plot) # Plotting Decision Trees
library(Metrics) # DT Performance
library(mlr) # DT hyperparameter tuning
library(ggplot2) # Plotting
library(scales) # Plotting labels
library(wesanderson) # Plotting color palette
library(mlr) # Tuning
library(parallelMap) # Tuning in parallel
library(mltools) # One-hot encoding
library(beepr) # Alert after long processes finish
`%ni%` <- Negate(`%in%`)

setwd("C:/Users/c156934") # Set file path
source("//cs.msds.kp.org/scal/REGS/share15/KPIF_Analytics/Elsa/_Scripts for GitHub/portfolio/Modules/Goodness_Of_Fit.R") 
source("//cs.msds.kp.org/scal/REGS/share15/KPIF_Analytics/Elsa/_Scripts for GitHub/portfolio/Modules/Classification_Model_Charts.R") 

################## define function and then repeat for all DFs

# %% Import final DF
DF <- fread('Final Model Set FM On HIX.csv',colClasses=c(AGLTY_INDIV_ID="character")) # manual edit
DF <- rename(DF, Conv_Enroll_Flag = Conv_Enroll_OnHIX_Flag) # manual edit

## Conditional data cleaning
#DF <- DF %>% filter(FM_TENURE_MO > 0)

## Overall data cleaning
DF <- DF %>% dplyr::select(-Timing_Main_Flag) # multicollinearity with Treatment_Flag
DF <- DF %>% dplyr::select(-Timing_Late_Flag,-OE9_Test_LateClock_Flag) # everyone in CA and DC gets a late flag
DF <- DF %>% dplyr::select(-contains(c("OE7","OE8","OE9"))) # correlated with prior model score
## Misc cleaning
DF <- DF %>%
  mutate(
    ESRI_HHINCOME_AVG = ESRI_HHINCOME_AVG/1000, # Avg income in 1k units
    Market_Share_Unins_5YRchg = Market_Share_Unins_5YRchg*100, # decimal pct to integer
    Market_Share_Medi_YOYchg = Market_Share_Medi_YOYchg*100, # decimal pct to integer
    Cases_OE1_vs_1mo_ago = Cases_OE1_vs_1mo_ago*100, # decimal pct to integer
    RP_Lowest_ONHIX_ALL = RP_Lowest_ONHIX_ALL*100, # decimal pct to integer
    RP_LowestIncr_OFFHIX_ALL = RP_LowestIncr_OFFHIX_ALL*100, # decimal pct to integer
    CA_Flag = ifelse(Region %in% c("CASC","CANC"),1,0),
    TAPESTRY_LIFESTYLE = gsub(" ", "", TAPESTRY_LIFESTYLE),
    TAPESTRY_URBAN = gsub(" ", "", TAPESTRY_URBAN))  %>%
  rename(ESRI_HHINCOME_AVG_1k = ESRI_HHINCOME_AVG,
         Cases_OE1_vs_1mo_ago_PctChg = Cases_OE1_vs_1mo_ago,
         Market_Share_Unins_3YRchg = Market_Share_Unins_5YRchg) %>%
  rename_with(~gsub("Market_Share", "Market_Size", .x,))

## One-hot encoding
ListColsRemove <- c('AGLTY_INDIV_ID', 'Audience_CY','PRIOR_MODEL_SCORE','ST_CD', 
                    'CNTY_NM','SVC_AREA_NM', 'CITY_NM', 'TAPESTRY_SEGMENT')
DF <- subset(DF,select = names(DF) %ni% ListColsRemove)
remove(ListColsRemove)
ListColsOneHot <- c('Region', 'OE_Season','MODEL_OWN_RENT','TAPESTRY_LIFESTYLE',
                    'TAPESTRY_URBAN')
DF <- as.data.frame(DF)
DF[ListColsOneHot] <- lapply(DF[ListColsOneHot], as.factor)
remove(ListColsOneHot)
DF <- DF %>%
  rename(Region_Flag = Region,
         OE_Season_Flag = OE_Season,
         MODEL_OWN_RENT_Flag = MODEL_OWN_RENT,
         TAPLIFE_Flag = TAPESTRY_LIFESTYLE,
         TAPURBAN_Flag = TAPESTRY_URBAN)
DF <- one_hot(as.data.table(DF), dropCols = FALSE)
ListColsOneHot <- c('Region', 'OE_Season_Flag','MODEL_OWN_RENT_Flag',
                    'TAPLIFE_Flag','TAPURBAN_Flag')
DF <- DF %>% rename(Region = Region_Flag)

# HOSP_DIST_MSR
quants <- quantile(DF$HOSP_DIST_MSR, c(0, 0.25, 0.5, 0.75, 1))
DF$HOSP_DIST_MSR_BIN <- cut(DF$HOSP_DIST_MSR,
                            quants, include.lowest = TRUE, dig.lab = 4,
                            labels = sprintf("%0.0f-%0.0f", head(quants, n = -1), quants[-1]))
remove(quants)
DF <- DF %>% dplyr::select(-HOSP_DIST_MSR)

## Set DV as numeric & check stats
Average_Enrollment_Rate <- sprintf("%1.3f%%",100*prop.table(table(DF$Conv_Enroll_Flag))[2])
tabyl(DF$Conv_Enroll_Flag)
Average_Enrollment_Rate.ROC <- DF %>%
                               filter(Region %ni% c("CANC","CASC")) %>%
                               summarise(Conversion_Rate = mean(Conv_Enroll_Flag)) 
Average_Enrollment_Rate.ROC <- sprintf("%1.3f%%",100*Average_Enrollment_Rate.ROC$Conversion_Rate)
Average_Enrollment_Rate.CA  <- DF %>%
                               filter(Region %in% c("CANC","CASC")) %>%
                               summarise(Conversion_Rate = mean(Conv_Enroll_Flag)) 
Average_Enrollment_Rate.CA  <- sprintf("%1.3f%%",100*Average_Enrollment_Rate.CA$Conversion_Rate)
tabyl(DF,Region,Conv_Enroll_Flag)
#tabyl(DF,CA_Flag,Conv_Enroll_Flag)
## By Region
Average_Enrollment_Rate.ByRegion <- DF %>%
                                    group_by(Region) %>%
                                    summarise(Conversion_Rate = mean(Conv_Enroll_Flag)) %>%
                                    as.data.frame
Average_Enrollment_Rate.ByRegion
Average_Enrollment_Rate.ByRegion.ROC <- Average_Enrollment_Rate.ByRegion %>%
                                        filter(Region %ni% c("CANC","CASC"))
Average_Enrollment_Rate.ByRegion.CA  <- Average_Enrollment_Rate.ByRegion %>%
                                        filter(Region %in% c("CANC","CASC"))

## Set non-numeric IV as factors
ListFlags <- DF %>% 
  dplyr::select(contains("_Flag", ignore.case = T)) %>%
  colnames()
ListFlags <- c(ListFlags)
ListChar  <- DF %>% select_if(is.character) %>% colnames()
ListDV    <- DF %>% dplyr::select(contains("Conv", ignore.case = T)) %>%colnames()
DF <- as.data.frame(DF)
DF[ListFlags] <- lapply(DF[ListFlags], as.factor)
DF[ListChar] <- lapply(DF[ListChar], as.factor)
DF[ListDV] <- lapply(DF[ListDV], as.factor)
str(DF)
remove(ListFlags)
remove(ListChar)

## Train/Test split
set.seed(123)
flag <- sample(c(TRUE, FALSE), nrow(DF), replace=TRUE, prob=c(0.7,0.3))
Train <- DF[flag, ]
Test <- DF[!flag, ]
remove(flag)

## Get Region vectors for each train and test
Train.Region <- Train$Region
Test.Region <- Test$Region
Train.Region.ROC <- Train %>% select(Region) %>% filter(Region %ni% c("CANC","CASC"))
Test.Region.ROC <- Test %>% select(Region) %>% filter(Region %ni% c("CANC","CASC"))
Train.Region.CA <- Train %>% select(Region) %>% filter(Region %in% c("CANC","CASC"))
Test.Region.CA <- Test %>% select(Region) %>% filter(Region %in% c("CANC","CASC"))
gc()

## Set aside reporting variables
ListDummyVarTrap <- c('OE_Season_Flag_2020','Region_Flag_U',
                      'MODEL_OWN_RENT_Flag_UNKNOWN','TAPURBAN_Flag_U',
                      'TAPLIFE_Flag_U','TAPURBAN_Flag_UrbanPeriphery') # dummy var trap
ListReportingCols <- c(ListColsOneHot, ListDummyVarTrap, 'AGLTY_INDIV_ID', 
                       'Audience_CY', 'SVC_AREA_NM', 'CITY_NM',
                       'PRIOR_MODEL_SCORE', 'Region', 'ST_CD', 'CNTY_NM')
DF <- subset(DF,select = names(DF) %ni% ListReportingCols)
Train <- subset(Train,select = names(Train) %ni% ListReportingCols)
Test <- subset(Test,select = names(Test) %ni% ListReportingCols)
remove(ListColsOneHot)
remove(ListReportingCols)

## Sampling
lim <- round(nrow(Train)*0.5,-4)
Train.OVUN.30 <- ovun.sample(Conv_Enroll_Flag ~ ., data = Train, 
                             method = "both", p=0.3, N=lim, seed = 1)$data
tabyl(Train.OVUN.30$Conv_Enroll_Flag)
lim <- round(nrow(Train)*0.3,-4)
Train.OVUN.50 <- ovun.sample(Conv_Enroll_Flag ~ ., data = Train, 
                             method = "both", p=0.5, N=lim, seed = 1)$data
tabyl(Train.OVUN.50$Conv_Enroll_Flag)
#Train.SMOTE <- SMOTE(form=Conv_Enroll_Flag ~ .,as.data.frame(Train),perc.over=900, perc.under=300)
#tabyl(Train.SMOTE$Conv_Enroll_Flag)
remove(lim)
gc()

################################## Model Run  ##################################

############################# BASELINE: Logistic  ##############################

## Sampling: None

# Initialize temporary training dataset
TrainData <- Train 
TrainData <- TrainData %>% dplyr::select(-HOSP_DIST_MSR_BIN,-CA_Flag,
                                         -TAPLIFE_Flag_FamilyLandscapes,
                                         -TAPLIFE_Flag_CozyCountryLiving,
                                         -TAPLIFE_Flag_GenXurban,
                                         -TAPLIFE_Flag_SeniorStyles,
                                         -TAPLIFE_Flag_ScholarsandPatriots,
                                         -TAPLIFE_Flag_AffluentEstates,
                                         -TAPURBAN_Flag_MetroCities,
                                         -TAPURBAN_Flag_SuburbanPeriphery,
                                         -TAPURBAN_Flag_Rural,
                                         -Region_Flag_CANC) # not significant/multicollinearity
TestData <- Test
# Run model
Log <- glm(Conv_Enroll_Flag ~ ., data = TrainData, family = binomial(logit), model = FALSE, y = FALSE) 
summary(Log)
vif(Log)
# Predict
TestData$prediction  <- predict(Log, newdata = TestData, type = "response")
TrainData$prediction <- predict(Log, newdata = TrainData, type = "response")
# Output performance metrics
Log.ROCInfo <- CalcGoodnessOfFit(Log, TrainData, TestData, "Conv_Enroll_Flag", 0.55,
                                 "FM On-HIX \n Logistic Regression (no sampling)")
CreateModelCharts(Log, Log.ROCInfo,
                  TrainData, TestData, 
                  "FM On-HIX \nLogistic Regression (no sampling)",
                  Train.Region, Test.Region, 3.5)

# Save
coef <- as.data.frame(Log$coefficients) %>% 
  arrange(desc(abs(Log$coefficients))) %>% 
  as.data.frame
write.table(coef, "clipboard", sep="\t")

# Documentation
modelvar <- attr(Log$terms,"term.labels")
subset <- DF %>% select(modelvar)
subset.fact <- subset %>% select_if(is.factor) %>% colnames()
subset[subset.fact] <- lapply(subset[subset.fact], as.character)
subset[subset.fact] <- lapply(subset[subset.fact], as.numeric)
mean <- lapply(subset[modelvar],mean)
mean <- as.data.frame(do.call(rbind,mean)) %>% rename(Mean=V1) %>% round(digits=2)
max <- lapply(subset[modelvar],max)
max <- as.data.frame(do.call(rbind,max)) %>% rename(Max=V1) %>% round()
q1 <- lapply(subset[modelvar], quantile, probs=0.25)
q1 <- as.data.frame(do.call(rbind,q1)) %>% rename(Q1="25%") %>% round()
q3 <- lapply(subset[modelvar], quantile, probs=0.75)
q3 <- as.data.frame(do.call(rbind,q3)) %>% rename(Q3="75%") %>% round()
iqr <- paste(q1$Q1,"-",q3$Q3)
documentation <- cbind(iqr,mean,max)
documentation
remove(modelvar)
remove(subset)
remove(subset.fact)
remove(mean)
remove(max)
remove(q1)
remove(q3)
remove(iqr)

# make the glm object smaller
Log[c("residuals", "weights", "fitted.values","data","prior.weights","na.action","linear.predictors","effects")] <- NULL
Log$qr$qr <- NULL
saveRDS(Log, "FM_On_Logistic.rds")
remove(Log)
remove(Log.ROCInfo)
remove(coef)

## Sampling: Over/Under 30%

TrainData <- Train.OVUN.30
TrainData <- TrainData %>% dplyr::select(-HOSP_DIST_MSR_BIN,-CA_Flag,
                                         -TAPURBAN_Flag_Rural,-Region_Flag_CANC,
                                         -TAPLIFE_Flag_AffluentEstates,
                                         -TAPLIFE_Flag_FamilyLandscapes) # not significant
TestData <- Test
# Run model
Log <- glm(Conv_Enroll_Flag ~ ., data = TrainData, family = binomial(logit), model = FALSE, y = FALSE) 
summary(Log)
vif(Log)
# Predict
TrainData <- Train #use non-sampled
TestData$prediction  <- predict(Log, newdata = TestData, type = "response")
TrainData$prediction <- predict(Log, newdata = TrainData, type = "response")
# Output performance metrics
Log.ROCInfo <- CalcGoodnessOfFit(Log, TrainData, TestData, "Conv_Enroll_Flag", 0.55,
                                 "FM On-HIX \n Logistic Regression (Sampling: Over 30%)")
CreateModelCharts(Log, Log.ROCInfo,
                  TrainData, TestData, 
                  "FM On-HIX \nLogistic Regression (Sampling: Over/Under 30%)",
                  Train.Region, Test.Region, 4)

remove(Log)
remove(Log.ROCInfo)

################################ Decision Tree  ################################

## ROC

gc()
Train.OVUN.30.ROC <- Train.OVUN.30[Train.OVUN.30$CA_Flag==0,]
Train.OVUN.50.ROC <- Train.OVUN.50[Train.OVUN.50$CA_Flag==0,]
Train.ROC <- Train[Train$CA_Flag==0,]
Test.ROC <- Test[Test$CA_Flag==0,]

TrainData <- Train.OVUN.50.ROC
TestData <- Test.ROC
TrainData <- TrainData %>% dplyr::select(-Region_Flag_CANC, -Region_Flag_CASC,
                                         -CA_Flag)
  # TUNE
  set.seed(123)
  n_cores <- parallel::detectCores()-4
  getParamSet('classif.rpart')
  
  RunTune <- function(){
    
    controlgrid <- makeTuneControlGrid() 
    Train.task  <- makeClassifTask(data = TrainData, target="Conv_Enroll_Flag", positive = 1)
    rdesc       <- makeResampleDesc("CV", iters = 3L) 
    lrn         <- makeLearner('classif.rpart', predict.type = "prob", 
                               fix.factors.prediction = TRUE)
    start <- Sys.time()
    print(start)
    parallelStartSocket(n_cores) #8
    Tree.tune   <- tuneParams(learner = lrn,
                              task = Train.task,
                              resampling = rdesc,
                              measures = list(auc, acc, bac, tpr),
                              par.set = paramgrid,
                              control = controlgrid,
                              show.info = TRUE)
    parallelStop()
    #tuneresult  <- generateHyperParsEffectData(Tree.tune, partial.dep = TRUE)
    #ggplot(data = tuneresult$data, aes(x = maxdepth, y=auc.test.mean)) + geom_line(color = 'darkblue')
    runtime <- Sys.time() - start
    print(runtime)
    beep("treasure")
    return(Tree.tune)
  }
  # Part 1
  bin_low  <- nrow(TrainData)*0.005
  bin_high <- nrow(TrainData)*0.05
  bin_seq <- (bin_high - bin_low)/5
  paramgrid   <- makeParamSet(makeDiscreteParam("maxdepth", values = 7:15)
                              ,makeDiscreteParam("minbucket", values = seq(bin_low, bin_high, by = bin_seq))
                              )
  Tree.tune <- RunTune()
  tune.minbucket <- Tree.tune$x$minbucket
  tune.maxdepth <- Tree.tune$x$maxdepth
  # Part 2
  paramgrid   <- makeParamSet(makeNumericParam("cp", lower = 0.0001, upper = 0.001))
  Tree.tune <- RunTune()
  tune.cp <- Tree.tune$x$cp
  # END TUNE

# Run model
Tree <- rpart(Conv_Enroll_Flag ~ ., data = TrainData, method = "class",
              control = rpart.control(minbucket = nrow(TrainData)/100, 
                                      xval = 10, 
                                      cp = tune.cp, 
                                      maxdepth= tune.maxdepth)) 
beep("treasure")
rpart.plot(Tree, type=3, box.palette = "RdYlGn",
           split.fun = split.fun, cex=0.6,
           main = "ROC FM On-HIX\nDecision Tree (Sampling: 50%)")
#varimp <- as.data.frame(Tree$variable.importance)
#varimp
#write.table(varimp, "clipboard", sep="\t")
#plotcp(Tree)
#printcp(Tree)
# Predict
TrainData <- Train.ROC
TestData$prediction <- predict(Tree, newdata = TestData, type = "prob")[,2]
TrainData$prediction <- predict(Tree, newdata = TrainData, type = "prob")[,2]
# Output performance metrics
Tree.ROCInfo <- CalcGoodnessOfFit(Tree, TrainData, TestData, "Conv_Enroll_Flag",
                                  0.5, "ROC FM On-HIX \nDecision Tree (no sampling)")
CreateModelChartsRegion(Tree, Tree.ROCInfo,
                  TrainData, TestData,
                  "ROC FM On-HIX \nDecision Tree (no sampling)",
                  Train.Region.ROC, Test.Region.ROC, 4,
                  Average_Enrollment_Rate.ROC, Average_Enrollment_Rate.ByRegion.ROC)
saveRDS(Tree, "M2_FM_On_Tree_ROC.rds")

## CA

gc()
Train.OVUN.30.CA <- Train.OVUN.30[Train.OVUN.30$CA_Flag==1,]
Train.OVUN.50.CA <- Train.OVUN.50[Train.OVUN.50$CA_Flag==1,]
Train.CA <- Train[Train$CA_Flag==1,]
Test.CA <- Test[Test$CA_Flag==1,]

TrainData <- Train.OVUN.50.CA
TestData <- Test.CA
TrainData <- TrainData %>% dplyr::select(-Region_Flag_MAS, -Region_Flag_GA,
                                         -Region_Flag_CO, -Region_Flag_NW,
                                         -Region_Flag_HI,-CA_Flag,
                                         -HOSP_DIST_MSR_BIN)
# TUNE
set.seed(123)
n_cores <- parallel::detectCores()-4
getParamSet('classif.rpart')
# Part 1
bin_low  <- nrow(TrainData)*0.005
bin_high <- nrow(TrainData)*0.05
bin_seq <- (bin_high - bin_low)/5
paramgrid   <- makeParamSet(makeDiscreteParam("maxdepth", values = 7:15)
                            ,makeDiscreteParam("minbucket", values = seq(bin_low, bin_high, by = bin_seq))
)
Tree.tune <- RunTune()
tune.minbucket <- Tree.tune$x$minbucket
tune.maxdepth <- Tree.tune$x$maxdepth
# Part 2
paramgrid   <- makeParamSet(makeNumericParam("cp", lower = 0.0001, upper = 0.001))
Tree.tune <- RunTune()
tune.cp <- Tree.tune$x$cp
# END TUNE

# Run model
Tree <- rpart(Conv_Enroll_Flag ~ ., data = TrainData, method = "class",
              control = rpart.control(minbucket = tune.minbucket, 
                                      xval = 10, 
                                      cp = tune.cp, 
                                      maxdepth= tune.maxdepth)) 
beep("treasure")
rpart.plot(Tree, type=3, box.palette = "RdYlGn",
           split.fun = split.fun, cex=0.5,
           main = "CA FM On-HIX\nDecision Tree (Sampling: 50%)")
#varimp <- as.data.frame(Tree$variable.importance)
#varimp
#write.table(varimp, "clipboard", sep="\t")
#plotcp(Tree)
#printcp(Tree)
# Predict
TrainData <- Train.CA
TestData$prediction <- predict(Tree, newdata = TestData, type = "prob")[,2]
TrainData$prediction <- predict(Tree, newdata = TrainData, type = "prob")[,2]
# Output performance metrics
Tree.ROCInfo <- CalcGoodnessOfFit(Tree, TrainData, TestData, "Conv_Enroll_Flag",
                                  0.5, "CA FM On-HIX \nDecision Tree (no sampling)")
CreateModelChartsRegion(Tree, Tree.ROCInfo,
                        TrainData, TestData,
                        "CA FM On-HIX \nDecision Tree (no sampling)",
                        Train.Region.CA, Test.Region.CA, 4,
                        Average_Enrollment_Rate.CA, Average_Enrollment_Rate.ByRegion.CA)
saveRDS(Tree, "M2_FM_On_Tree_CA.rds")


