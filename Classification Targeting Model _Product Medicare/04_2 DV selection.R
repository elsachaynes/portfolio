#################### Choosing DV & whether AEP+SEP or AEP-only ############

###########################################################################
#                                                                         #
#                           Final Model Run                               #
#                                                                         #
###########################################################################
library(data.table)
library(dplyr)
library(caret)
library(janitor)
library(MASS)
library(car)
library(InformationValue)
library(cutpointr)
library(Hmisc)
library(ggplot2)

setwd("~/")

## Import final table (this has been re-done)
DF <-data.table::fread(file='MED_DM_22_Targeting_Final.csv')

# Set DV as numeric
DF$CONV_RESP_30DAY_FLAG <- as.numeric(DF$CONV_RESP_30DAY_FLAG)
DF$CONV_RESP_60DAY_FLAG <- as.numeric(DF$CONV_RESP_60DAY_FLAG)
DF$CONV_ENROLL_90DAY_FLAG <- as.numeric(DF$CONV_ENROLL_90DAY_FLAG)
DF$CONV_ENROLL_120DAY_FLAG <- as.numeric(DF$CONV_ENROLL_120DAY_FLAG)

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
DF <- as.data.frame(DF)
DF[ListFactors.PH] <- lapply(DF[ListFactors.PH], as.factor)
DF[ListFactors.TAP] <- lapply(DF[ListFactors.TAP], as.factor)
DF[ListFactors.KBM] <- lapply(DF[ListFactors.KBM], as.factor)
DF[ListFactors.AD] <- lapply(DF[ListFactors.AD], as.factor)
str(DF)
remove(ListFactors.AD)
remove(ListFactors.KBM)
remove(ListFactors.PH)
remove(ListFactors.TAP)

# scale
#ListDV <- DF %>% dplyr::select(starts_with("CONV")) %>% names()
#ListDV <- which(colnames(DF) %in% ListDV)
#ListNumeric <- sapply(DF, is.numeric)
#ListNumeric[ListDV[1]] <- FALSE
#ListNumeric[ListDV[2]] <- FALSE
#ListNumeric[ListDV[3]] <- FALSE
#ListNumeric[ListDV[4]] <- FALSE
#names(DF[ListNumeric])
#DF[ListNumeric] <- lapply(DF[ListNumeric], scale)
#remove(ListDV)
#remove(ListNumeric)

## Train/Test split
size <- floor(0.7 * nrow(DF)) # 70%
set.seed(123)
flag <- sample(seq_len(nrow(DF)), size = size)
DF.train <- DF[flag, ]
DF.test <- DF[-flag, ]
remove(size)
remove(flag)

## Baseline conversion rates sprintf("%1.2f%%", 100*m)
ResponseRate.30days <- sprintf("%1.3f%%",100*prop.table(table(DF$CONV_RESP_30DAY_FLAG))[2])
ResponseRate.60days <- sprintf("%1.3f%%",100*prop.table(table(DF$CONV_RESP_60DAY_FLAG))[2])
EnrollmentRate.90days <- sprintf("%1.3f%%",100*prop.table(table(DF$CONV_ENROLL_90DAY_FLAG))[2])
EnrollmentRate.120days <- sprintf("%1.3f%%",100*prop.table(table(DF$CONV_ENROLL_120DAY_FLAG))[2])

tabyl(DF$CONV_RESP_30DAY_FLAG)
tabyl(DF$CONV_RESP_60DAY_FLAG)
tabyl(DF$CONV_ENROLL_90DAY_FLAG)
tabyl(DF$CONV_ENROLL_120DAY_FLAG)

## By Region
EnrollmentRate.ByRegion <- DF %>%
  group_by(Region) %>%
  summarise(Conversion_Rate = mean(CONV_ENROLL_120DAY_FLAG))
EnrollmentRate.ByRegion

## By Service Area
EnrollmentRate.BySVCA <- DF %>%
  group_by(SVC_AREA_NM) %>%
  summarise(Conversion_Rate = mean(CONV_ENROLL_120DAY_FLAG))
EnrollmentRate.BySVCA

## Baseline conversion rates AEP
DF.AEP <- DF %>% filter(Campaign=="AEP")
ResponseRate.30days.AEP <- sprintf("%1.3f%%",100*prop.table(table(DF.AEP$CONV_RESP_30DAY_FLAG))[2])
ResponseRate.60days.AEP <- sprintf("%1.3f%%",100*prop.table(table(DF.AEP$CONV_RESP_60DAY_FLAG))[2])
EnrollmentRate.90days.AEP <- sprintf("%1.3f%%",100*prop.table(table(DF.AEP$CONV_ENROLL_90DAY_FLAG))[2])
EnrollmentRate.120days.AEP <- sprintf("%1.3f%%",100*prop.table(table(DF.AEP$CONV_ENROLL_120DAY_FLAG))[2])

tabyl(DF.AEP$CONV_RESP_30DAY_FLAG)
tabyl(DF.AEP$CONV_RESP_60DAY_FLAG)
tabyl(DF.AEP$CONV_ENROLL_90DAY_FLAG)
tabyl(DF.AEP$CONV_ENROLL_120DAY_FLAG)

remove(DF)
remove(DF.AEP)

## Determine which conversion metric is most predictable & run our baseline model

# Response-30
DF.train.30 <- DF.train %>% dplyr::select(-CONV_RESP_60DAY_FLAG,-CONV_ENROLL_90DAY_FLAG,-CONV_ENROLL_120DAY_FLAG)
DF.train.30 <- DF.train.30 %>% dplyr::select(-KBM_Flag,-POS_Premium,-OCCU_CD,-TAPESTRY_SEGMENT_CD,-SUB_REGN_CD,
                                             -SCORE_10,-POP_PER_SQ_MILE_FY,-MEDIAN_WHITE_FEMALE_AGE,-SEP_DROP_9_FLAG,
                                             -POS_Inpatient,-BENE_TotalValAdd,-CENS_HH_CHILD_PCT,-MAIL_ORD_RSPDR_CD,
                                             -SCORE_9,-HH_CHILD_CNT,-CENS_MARRIED_PCT,-CENS_HISPANIC_PCT,-AGE_VAL,
                                             -MA_Penetration_Rt,-SEP_LATINO_DM_FLAG,-SEP_DROP_8_FLAG,-EDUC_HS,
                                             -EDUC_NO_HS,-SEP_DROP_7_FLAG,-SEP_DROP_6_FLAG,-POP_65_up_IN_LABOR_FORCE,
                                             -HH_INCOME_15_25k_FY,-HH_INCOME_200k,-POP_HISPANIC_FY,-POP_AVG_HH_SIZE,
                                             -POP_AGE_85_up,-HH_INCOME_0k_15k,-MEDIAN_HISP_MALE_AGE,-SCORE_6,
                                             -MEDIAN_HISP_MALE_AGE,-UNIT_NBR_PRSN_IND,-HH_PERSS_CNT,-IMAGE_MAIL_ORD_BYR_CD,
                                             -MAIL_ORD_RSPDR_CD)
Log.30 <- glm(CONV_RESP_30DAY_FLAG ~ ., data = DF.train.30, family=binomial(logit)) %>% stepAIC(direction="forward")
summary(Log.30)
vif(Log.30) 

# goodness of fit
DF.test.30 <- DF.test %>% dplyr::select(-CONV_RESP_60DAY_FLAG,-CONV_ENROLL_90DAY_FLAG,-CONV_ENROLL_120DAY_FLAG)
DF.test.30$prediction <- predict(Log.30, newdata = DF.test.30, type = "response")
DF.train.30$prediction <- predict(Log.30, newdata = DF.train.30, type = "response")
#roc_info<- cutpointr(DF.test.30,prediction,CONV_RESP_30DAY_FLAG,pos_class=1,method=minimize_metric,metric=abs_d_sens_spec) 
#summary(roc_info)
roc_info<- cutpointr(DF.test.30,prediction,CONV_RESP_30DAY_FLAG,pos_class=1,method=minimize_metric,metric=misclassification_cost,cost_fp=1,cost_fn=1200) 
summary(roc_info)
cm <- caret::confusionMatrix(data = as.factor(ifelse(DF.test.30$prediction>=roc_info$optimal_cutpoint,1,0)), 
                             reference = as.factor(DF.test.30$CONV_RESP_30DAY_FLAG),
                             mode="everything",positive="1")
auc(roc_info)
cm 
roc_info$optimal_cutpoint
cm2 <- caret::confusionMatrix(data = as.factor(ifelse(DF.train.30$prediction>=roc_info$optimal_cutpoint,1,0)), 
                              reference = as.factor(DF.train.30$CONV_RESP_30DAY_FLAG),
                              mode="everything",positive="1")
F1.test <- cm$byClass[7]
F1.train <- cm2$byClass[7]
sprintf("%1.4f%%",(F1.test-F1.train)/F1.test)
remove(cm)
remove(cm2)
remove(F1.test)
remove(F1.train)

# charts
DF.train.30$decile <- ntile(-DF.train.30$prediction, 10)
DF.test.30$decile <- ntile(-DF.test.30$prediction, 10)
Test.Predicted <- DF.test.30 %>% 
  dplyr::group_by(decile) %>% 
  summarise(Conversion_Rate = mean(ifelse(prediction>=roc_info$optimal_cutpoint,1,0)),
            Conversions = sum(ifelse(prediction>=roc_info$optimal_cutpoint,1,0))) %>%
  mutate(Value="Predicted-Test") 
Test.Actual <- DF.test.30 %>% 
  group_by(decile) %>% 
  summarise(Conversion_Rate = mean(CONV_RESP_30DAY_FLAG),
            Conversions = sum(CONV_RESP_30DAY_FLAG)) %>%
  mutate(Value="Actual-Test")
Train.Predicted <- DF.train.30 %>% 
  dplyr::group_by(decile) %>% 
  summarise(Conversion_Rate = mean(ifelse(prediction>=roc_info$optimal_cutpoint,1,0)),
            Conversions = sum(ifelse(prediction>=roc_info$optimal_cutpoint,1,0))) %>%
  mutate(Value="Predicted-Train")  
Train.Actual <- DF.train.30 %>% 
  group_by(decile) %>% 
  summarise(Conversion_Rate = mean(CONV_RESP_30DAY_FLAG),
            Conversions = sum(CONV_RESP_30DAY_FLAG)) %>%
  mutate(Value="Actual-Train")
# plot 1: x-axis: decile, y-axis: conversion rate. 2 bars: train vs. test (ACTUAL) -- add baseline
Plot1 <- rbind(Train.Actual,Test.Actual)
# plot 2: x-axis: decile, y-axis: conversion rate. 2 bars: train vs. test (PREDICTED) -- add baseline
Plot2 <- rbind(Test.Actual,Test.Predicted) 
p1<-ggplot(data=Plot1, aes(x=decile, y=Conversion_Rate, fill=Value)) +
  geom_bar(stat="identity", position = position_dodge(1), alpha = 0.75)+
  geom_text(aes(label=sprintf("%1.2f%%",Conversion_Rate*100)), hjust=-0.1, size=3.5,position=position_dodge(1),angle = 90)+
  scale_x_continuous(breaks=c(1,2,3,4,5,6,7,8,9,10))+
  scale_y_continuous(limits=c(0,0.003),labels=scales::percent_format(accuracy = 0.001)) +
  labs(x = "\n Decile", y = "Response Rate\n", title = "\n Actual Response Rate by Decile \n Train vs. Test \n 30-day Window, AEP & SEP") +
  theme_minimal()
p1
p2<-ggplot(data=Plot2, aes(x=decile, y=Conversion_Rate, fill=Value)) +
  geom_bar(stat="identity", position = position_dodge(), alpha = 0.75)+
  geom_text(aes(label=sprintf("%1.2f%%",Conversion_Rate*100)), hjust=-0.1, size=3.5,position=position_dodge(1),angle = 90)+
  scale_x_continuous(breaks=c(1,2,3,4,5,6,7,8,9,10))+
  #scale_y_continuous(limits=c(0,1.1),labels=scales::percent_format(accuracy = 1)) +
  labs(x = "\n Decile", y = "Response Rate\n", title = "\n Actual v. Predicted Response Rate by Decile \n Test Set (30%) \n 30-day Window, AEP & SEP") +
  theme_minimal()
p2

# Response-60
gc()
DF.train.60 <- DF.train %>% dplyr::select(-CONV_RESP_30DAY_FLAG,-CONV_ENROLL_90DAY_FLAG,-CONV_ENROLL_120DAY_FLAG)
DF.train.60 <- DF.train.60 %>% dplyr::select(-KBM_Flag,-POS_Premium,-OCCU_CD,-SUB_REGN_CD,-TAPESTRY_SEGMENT_CD,
                                             -IMAGE_MAIL_ORD_BYR_CD,-MAIL_ORD_RSPDR_CD,
                                             -SCORE_10,-POP_PER_SQ_MILE_FY,-MEDIAN_WHITE_FEMALE_AGE,-EDUC_NO_HS,
                                             -SEP_LATINO_DM_FLAG,-SEP_DROP_9_FLAG,-POS_Inpatient,-BENE_TotalValAdd,
                                             -CENS_HH_CHILD_PCT,-CENS_HISPANIC_PCT,-SCORE_9,-SCORE_6,-HH_CHILD_CNT,
                                             -MA_Penetration_Rt,-EDUC_HS,-POP_65_up_IN_LABOR_FORCE,-POP_HISPANIC_FY,
                                             -POP_AVG_HH_SIZE,-POP_AGE_85_up,-HH_PERSS_CNT,-HH_INCOME_15_25k_FY,
                                             -HH_INCOME_200k,-MEDIAN_HISP_MALE_AGE,-HH_INCOME_0k_15k) 
Log.60 <- glm(CONV_RESP_60DAY_FLAG ~ ., data = DF.train.60, family=binomial(logit)) %>% stepAIC(direction="forward")
summary(Log.60)
vif(Log.60)

# goodness of fit
DF.test.60 <- DF.test %>% dplyr::select(-CONV_RESP_30DAY_FLAG,-CONV_ENROLL_90DAY_FLAG,-CONV_ENROLL_120DAY_FLAG)
DF.test.60$prediction <- predict(Log.60, newdata = DF.test.60, type = "response")
DF.train.60$prediction <- predict(Log.60, newdata = DF.train.60, type = "response")
#roc_info<- cutpointr(DF.test.60,prediction,CONV_RESP_60DAY_FLAG,pos_class=1,method=minimize_metric,metric=abs_d_sens_spec) 
#summary(roc_info)
roc_info<- cutpointr(DF.test.60,prediction,CONV_RESP_60DAY_FLAG,pos_class=1,method=minimize_metric,metric=misclassification_cost,cost_fp=1,cost_fn=1200) 
summary(roc_info)
cm <- caret::confusionMatrix(data = as.factor(ifelse(DF.test.60$prediction>=roc_info$optimal_cutpoint,1,0)), 
                             reference = as.factor(DF.test.60$CONV_RESP_60DAY_FLAG),
                             mode="everything",positive="1")
auc(roc_info)
cm
roc_info$optimal_cutpoint
cm2 <- caret::confusionMatrix(data = as.factor(ifelse(DF.train.60$prediction>=roc_info$optimal_cutpoint,1,0)), 
                              reference = as.factor(DF.train.60$CONV_RESP_60DAY_FLAG),
                              mode="everything",positive="1")
F1.test <- cm$byClass[7]
F1.train <- cm2$byClass[7]
sprintf("%1.4f%%",((F1.test-F1.train)/F1.test)*100)
remove(cm)
remove(cm2)
remove(F1.test)
remove(F1.train)

# charts
DF.train.60$decile <- ntile(-DF.train.60$prediction, 10)
DF.test.60$decile <- ntile(-DF.test.60$prediction, 10)

DF.train.60$Region <- ifelse(DF.train$SUB_REGN_CD %in% c("CANC","CASC"),as.character(DF.train$SUB_REGN_CD),"ROC")
DF.test.60$Region <- ifelse(DF.test$SUB_REGN_CD %in% c("CANC","CASC"),as.character(DF.test$SUB_REGN_CD),"ROC")

DF.train.60 <- DF.train.60 %>% group_by(Region) %>% mutate(decile_region = ntile(-prediction, 10)) %>% ungroup()
DF.test.60 <- DF.test.60 %>% group_by(Region) %>% mutate(decile_region = ntile(-prediction, 10)) %>% ungroup()
tabyl(DF.train.60,decile_region,Region)

Test.Predicted <- DF.test.60 %>% 
  dplyr::group_by(decile_region) %>% 
  summarise(Conversion_Rate = mean(ifelse(prediction>=roc_info$optimal_cutpoint,1,0)),
            Conversions = sum(ifelse(prediction>=roc_info$optimal_cutpoint,1,0))) %>%
  mutate(Value="Predicted-Test") 
Test.Actual <- DF.test.60 %>% 
  group_by(decile_region) %>% 
  summarise(Conversion_Rate = mean(CONV_RESP_60DAY_FLAG),
            Conversions = sum(CONV_RESP_60DAY_FLAG)) %>%
  mutate(Value="Actual-Test")
Train.Predicted <- DF.train.60 %>% 
  dplyr::group_by(decile_region) %>% 
  summarise(Conversion_Rate = mean(ifelse(prediction>=roc_info$optimal_cutpoint,1,0)),
            Conversions = sum(ifelse(prediction>=roc_info$optimal_cutpoint,1,0))) %>%
  mutate(Value="Predicted-Train")  
Train.Actual <- DF.train.60 %>% 
  group_by(decile_region) %>% 
  summarise(Conversion_Rate = mean(CONV_RESP_60DAY_FLAG),
            Conversions = sum(CONV_RESP_60DAY_FLAG)) %>%
  mutate(Value="Actual-Train")
# plot 1: x-axis: decile, y-axis: conversion rate. 2 bars: train vs. test (ACTUAL) -- add baseline
Plot1 <- rbind(Train.Actual,Test.Actual)
# plot 2: x-axis: decile, y-axis: conversion rate. 2 bars: train vs. test (PREDICTED) -- add baseline
Plot2 <- rbind(Test.Actual,Test.Predicted) 
p1<-ggplot(data=Plot1, aes(x=decile_region, y=Conversion_Rate, fill=Value)) +
  geom_bar(stat="identity", position = position_dodge(1), alpha = 0.75)+
  geom_text(aes(label=sprintf("%1.2f%%",Conversion_Rate*100)), hjust=-0.1, size=3.5,position=position_dodge(1),angle = 90)+
  scale_x_continuous(breaks=c(1,2,3,4,5,6,7,8,9,10))+
  scale_y_continuous(limits=c(0,0.004),labels=scales::percent_format(accuracy = 0.001)) +
  labs(x = "\n Decile", y = "Response Rate\n", title = "\n Actual Response Rate by Decile \n Train vs. Test \n 60-day Window, AEP & SEP") +
  theme_minimal()
p1
p2<-ggplot(data=Plot2, aes(x=decile_region, y=Conversion_Rate, fill=Value)) +
  geom_bar(stat="identity", position = position_dodge(), alpha = 0.75)+
  geom_text(aes(label=sprintf("%1.2f%%",Conversion_Rate*100)), hjust=-0.1, size=3.5,position=position_dodge(1),angle = 90)+
  scale_x_continuous(breaks=c(1,2,3,4,5,6,7,8,9,10))+
  scale_y_continuous(limits=c(0,1.1),labels=scales::percent_format(accuracy = 1)) +
  labs(x = "\n Decile", y = "Response Rate\n", title = "\n Actual v. Predicted Response Rate by Decile \n Test Set (30%) \n 60-day Window, AEP & SEP") +
  theme_minimal()

Train.Actual <- DF.train.60 %>% 
  group_by(decile_region,Region) %>% 
  summarise(Conversion_Rate = mean(CONV_RESP_60DAY_FLAG),
            Conversions = sum(CONV_RESP_60DAY_FLAG)) %>%
  mutate(Value="Actual-Train") %>%
  arrange(Region,decile_region) %>%
  ungroup()
Test.Actual <- DF.test.60 %>% 
  group_by(decile_region,Region) %>% 
  summarise(Conversion_Rate = mean(CONV_RESP_60DAY_FLAG),
            Conversions = sum(CONV_RESP_60DAY_FLAG)) %>%
  mutate(Value="Actual-Test") %>%
  arrange(Region,decile_region) %>%
  ungroup()
Plot1.r <- rbind(Train.Actual,Test.Actual)
p1.r<-ggplot(data=Plot1.r, aes(x=decile_region, y=Conversion_Rate, fill=Value)) +
  geom_bar(stat="identity", position = position_dodge(1), alpha = 0.75)+
  geom_text(aes(label=sprintf("%1.2f%%",Conversion_Rate*100)), hjust=-0.1, size=3,position=position_dodge(1),angle = 90)+
  scale_x_continuous(breaks=c(1,2,3,4,5,6,7,8,9,10))+
  scale_y_continuous(limits=c(0,0.005),labels=scales::percent_format(accuracy = 0.001)) +
  labs(x = "\n Decile", y = "Response Rate\n", title = "\n Actual Response Rate by Decile \n Train vs. Test \n 60-day Window, AEP & SEP") +
  theme_minimal()
p1.r + facet_grid(cols = vars(Region))

remove(Plot1)
remove(Plot2)
remove(p1)
remove(p2)
remove(Log.60)
remove(DF.test.60)
remove(DF.train.60)
remove(roc_info)
remove(p1.r)
remove(Plot1.r)

# Enrollment-90
gc()
remove(Log.90)
DF.train.90 <- DF.train %>% dplyr::select(-CONV_RESP_30DAY_FLAG,-CONV_RESP_60DAY_FLAG,-CONV_ENROLL_120DAY_FLAG)
DF.train.90 <- DF.train.90 %>% dplyr::select(-SUB_REGN_CD,-OCCU_CD,-IMAGE_MAIL_ORD_BYR_CD,-MAIL_ORD_RSPDR_CD,
                                             -SCORE_10,-KBM_Flag,-TAPESTRY_SEGMENT_CD,-SCORE_9,-HH_CHILD_CNT,
                                             -HH_PERSS_CNT,-MA_Penetration_Rt,-SEP_DROP_9_FLAG,-SEP_LATINO_DM_FLAG,
                                             -EDUC_NO_HS,-HH_INCOME_200k,-HH_INCOME_0k_15k,-POP_HISPANIC_FY,
                                             -POP_PER_SQ_MILE_FY,-POP_AGE_85_up,-MEDIAN_WHITE_FEMALE_AGE,
                                             -SEP_DROP_8_FLAG,-SEP_DROP_7_FLAG,-SEP_DROP_6_FLAG,-CENS_HH_CHILD_PCT,
                                             -UNIT_NBR_PRSN_IND,-SEP_DROP_5_FLAG,-UNEMPLOYMENT_RT )
Log.90 <- glm(CONV_ENROLL_90DAY_FLAG ~ ., data = DF.train.90, family=binomial(logit)) %>% stepAIC(direction="forward")
summary(Log.90)
vif(Log.90)

# goodness of fit
DF.test.90 <- DF.test %>% dplyr::select(-CONV_RESP_30DAY_FLAG,-CONV_RESP_60DAY_FLAG,-CONV_ENROLL_120DAY_FLAG)
DF.test.90$prediction <- predict(Log.90, newdata = DF.test.90, type = "response")
DF.train.90$prediction <- predict(Log.90, newdata = DF.train.90, type = "response")
#roc_info<- cutpointr(DF.test.90,prediction,CONV_ENROLL_90DAY_FLAG,pos_class=1,method=minimize_metric,metric=abs_d_sens_spec) 
#summary(roc_info)
roc_info<- cutpointr(DF.test.90,prediction,CONV_ENROLL_90DAY_FLAG,pos_class=1,method=minimize_metric,metric=misclassification_cost,cost_fp=1,cost_fn=1200) 
summary(roc_info)
cm <- caret::confusionMatrix(data = as.factor(ifelse(DF.test.90$prediction>=roc_info$optimal_cutpoint,1,0)), 
                             reference = as.factor(DF.test.90$CONV_ENROLL_90DAY_FLAG),
                             mode="everything",positive="1")
auc(roc_info)
cm 
roc_info$optimal_cutpoint
cm2 <- caret::confusionMatrix(data = as.factor(ifelse(DF.train.90$prediction>=roc_info$optimal_cutpoint,1,0)), 
                              reference = as.factor(DF.train.90$CONV_ENROLL_90DAY_FLAG),
                              mode="everything",positive="1")
F1.test <- cm$byClass[7]
F1.train <- cm2$byClass[7]
sprintf("%1.4f%%",((F1.test-F1.train)/F1.test)*100)
remove(cm)
remove(cm2)
remove(F1.test)
remove(F1.train)

# charts
DF.train.90$decile <- ntile(-DF.train.90$prediction, 10)
DF.test.90$decile <- ntile(-DF.test.90$prediction, 10)

DF.train.90$Region <- ifelse(DF.train$SUB_REGN_CD %in% c("CANC","CASC"),as.character(DF.train$SUB_REGN_CD),"ROC")
DF.test.90$Region <- ifelse(DF.test$SUB_REGN_CD %in% c("CANC","CASC"),as.character(DF.test$SUB_REGN_CD),"ROC")

DF.train.90 <- DF.train.90 %>% group_by(Region) %>% mutate(decile_region = ntile(-prediction, 10)) %>% ungroup()
DF.test.90 <- DF.test.90 %>% group_by(Region) %>% mutate(decile_region = ntile(-prediction, 10)) %>% ungroup()
tabyl(DF.train.90,decile_region,Region)

Test.Predicted <- DF.test.90 %>% 
  dplyr::group_by(decile_region) %>% 
  summarise(Conversion_Rate = mean(ifelse(prediction>=roc_info$optimal_cutpoint,1,0)),
            Conversions = sum(ifelse(prediction>=roc_info$optimal_cutpoint,1,0))) %>%
  mutate(Value="Predicted-Test") 
Test.Actual <- DF.test.90 %>% 
  group_by(decile_region) %>% 
  summarise(Conversion_Rate = mean(CONV_ENROLL_90DAY_FLAG),
            Conversions = sum(CONV_ENROLL_90DAY_FLAG)) %>%
  mutate(Value="Actual-Test")
Train.Predicted <- DF.train.90 %>% 
  dplyr::group_by(decile_region) %>% 
  summarise(Conversion_Rate = mean(ifelse(prediction>=roc_info$optimal_cutpoint,1,0)),
            Conversions = sum(ifelse(prediction>=roc_info$optimal_cutpoint,1,0))) %>%
  mutate(Value="Predicted-Train")  
Train.Actual <- DF.train.90 %>% 
  group_by(decile_region) %>% 
  summarise(Conversion_Rate = mean(CONV_ENROLL_90DAY_FLAG),
            Conversions = sum(CONV_ENROLL_90DAY_FLAG)) %>%
  mutate(Value="Actual-Train")
# plot 1: x-axis: decile, y-axis: conversion rate. 2 bars: train vs. test (ACTUAL) -- add baseline
Plot1 <- rbind(Train.Actual,Test.Actual)
# plot 2: x-axis: decile, y-axis: conversion rate. 2 bars: train vs. test (PREDICTED) -- add baseline
Plot2 <- rbind(Test.Actual,Test.Predicted) 
p1<-ggplot(data=Plot1, aes(x=decile_region, y=Conversion_Rate, fill=Value)) +
  geom_bar(stat="identity", position = position_dodge(1), alpha = 0.75)+
  geom_text(aes(label=sprintf("%1.2f%%",Conversion_Rate*100)), hjust=-0.1, size=3.5,position=position_dodge(1),angle = 90)+
  scale_x_continuous(breaks=c(1,2,3,4,5,6,7,8,9,10))+
  scale_y_continuous(limits=c(0,0.005),labels=scales::percent_format(accuracy = 0.001)) +
  labs(x = "\n Decile", y = "Enrollment Rate\n", title = "\n Actual Enrollment Rate by Decile \n Train vs. Test \n 90-day Window, AEP & SEP") +
  theme_minimal()
p1
p2<-ggplot(data=Plot2, aes(x=decile_region, y=Conversion_Rate, fill=Value)) +
  geom_bar(stat="identity", position = position_dodge(), alpha = 0.75)+
  geom_text(aes(label=sprintf("%1.2f%%",Conversion_Rate*100)), hjust=-0.1, size=3.5,position=position_dodge(1),angle = 90)+
  scale_x_continuous(breaks=c(1,2,3,4,5,6,7,8,9,10))+
  scale_y_continuous(limits=c(0,1.1),labels=scales::percent_format(accuracy = 1)) +
  labs(x = "\n Decile", y = "Enrollment Rate\n", title = "\n Actual v. Predicted Enrollment Rate by Decile \n Test Set (30%) \n 90-day Window, AEP & SEP") +
  theme_minimal()
p2

Train.Actual <- DF.train.90 %>% 
  group_by(decile_region,Region) %>% 
  summarise(Conversion_Rate = mean(CONV_ENROLL_90DAY_FLAG),
            Conversions = sum(CONV_ENROLL_90DAY_FLAG)) %>%
  mutate(Value="Actual-Train") %>%
  arrange(Region,decile_region) %>%
  ungroup()
Test.Actual <- DF.test.90 %>% 
  group_by(decile_region,Region) %>% 
  summarise(Conversion_Rate = mean(CONV_ENROLL_90DAY_FLAG),
            Conversions = sum(CONV_ENROLL_90DAY_FLAG)) %>%
  mutate(Value="Actual-Test") %>%
  arrange(Region,decile_region) %>%
  ungroup()
Plot1.r <- rbind(Train.Actual,Test.Actual)
p1.r<-ggplot(data=Plot1.r, aes(x=decile_region, y=Conversion_Rate, fill=Value)) +
  geom_bar(stat="identity", position = position_dodge(1), alpha = 0.75)+
  geom_text(aes(label=sprintf("%1.2f%%",Conversion_Rate*100)), hjust=-0.1, size=3,position=position_dodge(1),angle = 90)+
  scale_x_continuous(breaks=c(1,2,3,4,5,6,7,8,9,10))+
  scale_y_continuous(limits=c(0,0.005),labels=scales::percent_format(accuracy = 0.001)) +
  labs(x = "\n Decile", y = "Enrollment Rate\n", title = "\n Actual Enrollment Rate by Decile \n Train vs. Test \n 90-day Window, AEP & SEP") +
  theme_minimal()
p1.r + facet_grid(cols = vars(Region))

remove(Plot1)
remove(Plot2)
remove(p1)
remove(p2)
remove(Log.90)
remove(DF.test.90)
remove(DF.train.90)
remove(roc_info)
remove(p1.r)
remove(Plot1.r)

# Enrollment-120
DF.train.120 <- DF.train %>% dplyr::select(-CONV_RESP_30DAY_FLAG,-CONV_RESP_60DAY_FLAG,-CONV_ENROLL_90DAY_FLAG)
DF.train.120 <- DF.train.120 %>% dplyr::select(-Region,-OCCU_CD,
                                               -SCORE_10,-KBM_Flag,-TAPESTRY_SEGMENT_CD,-SCORE_9,-HH_CHILD_CNT,
                                               -HH_PERSS_CNT,-MA_Penetration_Rt,-SEP_DROP_9_FLAG,-SEP_DROP_8_FLAG,
                                               -SEP_DROP_7_FLAG,-SEP_LATINO_DM_FLAG,-HH_INCOME_200k,-HH_INCOME_0k_15k,
                                               -POP_HISPANIC_FY,-POP_PER_SQ_MILE_FY,-POP_AGE_85_up,-UNIT_NBR_PRSN_IND,
                                               -EDUC_NO_HS,-MEDIAN_WHITE_FEMALE_AGE,-POS_Professional,-CENS_HH_CHILD_PCT,
                                               -MAIL_ORDER_BUYER)
Log.120 <- glm(CONV_ENROLL_120DAY_FLAG ~ ., data = DF.train.120, family=binomial(logit)) %>% stepAIC(direction="forward")
summary(Log.120)
vif(Log.120)
coef <- as.data.frame(Log.120$coefficients) %>% arrange(desc(abs(Log.120$coefficients))) %>% as.data.frame
write.table(coef, "clipboard", sep="\t")

# goodness of fit
DF.test.120 <- DF.test %>% dplyr::select(-CONV_RESP_30DAY_FLAG,-CONV_RESP_60DAY_FLAG,-CONV_ENROLL_90DAY_FLAG)
DF.test.120$prediction <- predict(Log.120, newdata = DF.test.120, type = "response")
DF.train.120$prediction <- predict(Log.120, newdata = DF.train.120, type = "response")
roc_info<- cutpointr(DF.test.120,prediction,CONV_ENROLL_120DAY_FLAG,pos_class=1,method=maximize_metric,metric=sens_constrain,min_constrain=0.55) 
summary(roc_info)
#roc_info<- cutpointr(DF.test.120,prediction,CONV_ENROLL_120DAY_FLAG,pos_class=1,method=minimize_metric,metric=misclassification_cost,cost_fp=1,cost_fn=1200) 
#summary(roc_info)
cm <- caret::confusionMatrix(data = as.factor(ifelse(DF.test.120$prediction>=roc_info$optimal_cutpoint,1,0)), 
                             reference = as.factor(DF.test.120$CONV_ENROLL_120DAY_FLAG),
                             mode="everything",positive="1")
auc(roc_info)
cm 
roc_info$optimal_cutpoint
cm2 <- caret::confusionMatrix(data = as.factor(ifelse(DF.train.120$prediction>=roc_info$optimal_cutpoint,1,0)), 
                              reference = as.factor(DF.train.120$CONV_ENROLL_120DAY_FLAG),
                              mode="everything",positive="1")
F1.test <- cm$byClass[7]
F1.train <- cm2$byClass[7]
sprintf("%1.4f%%",((F1.test-F1.train)/F1.test)*100)
remove(cm)
remove(cm2)
remove(F1.test)
remove(F1.train)

# charts
DF.train.120$Region <- DF.train$Region
DF.test.120$Region <- DF.test$Region

DF.train.120 <- DF.train.120 %>% group_by(Region) %>% mutate(decile_region = ntile(-prediction, 10)) %>% ungroup()
DF.test.120 <- DF.test.120 %>% group_by(Region) %>% mutate(decile_region = ntile(-prediction, 10)) %>% ungroup()

Test.Predicted <- DF.test.120 %>% 
  dplyr::group_by(decile_region) %>% 
  summarise(Conversion_Rate = mean(ifelse(prediction>=roc_info$optimal_cutpoint,1,0)),
            Conversions = sum(ifelse(prediction>=roc_info$optimal_cutpoint,1,0))) %>%
  mutate(Value="Predicted-Test") 
Test.Actual <- DF.test.120 %>% 
  group_by(decile_region) %>% 
  summarise(Conversion_Rate = mean(CONV_ENROLL_120DAY_FLAG),
            Conversions = sum(CONV_ENROLL_120DAY_FLAG)) %>%
  mutate(Value="Actual-Test")
Train.Predicted <- DF.train.120 %>% 
  dplyr::group_by(decile_region) %>% 
  summarise(Conversion_Rate = mean(ifelse(prediction>=roc_info$optimal_cutpoint,1,0)),
            Conversions = sum(ifelse(prediction>=roc_info$optimal_cutpoint,1,0))) %>%
  mutate(Value="Predicted-Train")  
Train.Actual <- DF.train.120 %>% 
  group_by(decile_region) %>% 
  summarise(Conversion_Rate = mean(CONV_ENROLL_120DAY_FLAG),
            Conversions = sum(CONV_ENROLL_120DAY_FLAG)) %>%
  mutate(Value="Actual-Train")
# plot 1: x-axis: decile, y-axis: conversion rate. 2 bars: train vs. test (ACTUAL) -- add baseline
Plot1 <- rbind(Train.Actual,Test.Actual)
# plot 2: x-axis: decile, y-axis: conversion rate. 2 bars: train vs. test (PREDICTED) -- add baseline
Plot2 <- rbind(Test.Actual,Test.Predicted) 
p1<-ggplot(data=Plot1, aes(x=decile_region, y=Conversion_Rate, fill=Value)) +
  geom_bar(stat="identity", position = position_dodge(1), alpha = 0.75)+
  geom_text(aes(label=sprintf("%1.2f%%",Conversion_Rate*100)), hjust=-0.1, size=3.5,position=position_dodge(1),angle = 90)+
  scale_x_continuous(breaks=c(1,2,3,4,5,6,7,8,9,10))+
  scale_y_continuous(limits=c(0,0.005),labels=scales::percent_format(accuracy = 0.001)) +
  labs(x = "\n Decile", y = "Enrollment Rate\n", title = "\n Actual Enrollment Rate by Decile \n Train vs. Test \n 120-day Window, AEP & SEP") +
  theme_minimal()
p1 + geom_hline(aes(yintercept=extract_numeric(EnrollmentRate.120days)/100),linetype=2) +
  annotate("text", x=9, y=0.0002+(extract_numeric(EnrollmentRate.120days)/100), label=paste("Base Rate:",EnrollmentRate.120days))
p2<-ggplot(data=Plot2, aes(x=decile_region, y=Conversion_Rate, fill=Value)) +
  geom_bar(stat="identity", position = position_dodge(), alpha = 0.75)+
  geom_text(aes(label=sprintf("%1.2f%%",Conversion_Rate*100)), hjust=-0.1, size=3.5,position=position_dodge(1),angle = 90)+
  scale_x_continuous(breaks=c(1,2,3,4,5,6,7,8,9,10))+
  scale_y_continuous(limits=c(0,1.1),labels=scales::percent_format(accuracy = 1)) +
  labs(x = "\n Decile", y = "Enrollment Rate\n", title = "\n Actual v. Predicted Enrollment Rate by Decile \n Test Set (30%) \n 120-day Window, AEP & SEP") +
  theme_minimal()
p2 + geom_hline(aes(yintercept=extract_numeric(EnrollmentRate.120days)/100),linetype=2) +
  annotate("text", x=9, y=0.0002+(extract_numeric(EnrollmentRate.120days)/100), label=paste("Base Rate:",EnrollmentRate.120days))

Train.Actual <- DF.train.120 %>% 
  group_by(decile_region,Region) %>% 
  summarise(Conversion_Rate = mean(CONV_ENROLL_120DAY_FLAG),
            Conversions = sum(CONV_ENROLL_120DAY_FLAG)) %>%
  mutate(Value="Actual-Train") %>%
  arrange(Region,decile_region) %>%
  ungroup()
Test.Actual <- DF.test.120 %>% 
  group_by(decile_region,Region) %>% 
  summarise(Conversion_Rate = mean(CONV_ENROLL_120DAY_FLAG),
            Conversions = sum(CONV_ENROLL_120DAY_FLAG)) %>%
  mutate(Value="Actual-Test") %>%
  arrange(Region,decile_region) %>%
  ungroup()
Plot1.r <- rbind(Train.Actual,Test.Actual)
p1.r<-ggplot(data=Plot1.r, aes(x=decile_region, y=Conversion_Rate, fill=Value)) +
  geom_bar(stat="identity", position = position_dodge(1), alpha = 0.75)+
  geom_text(aes(label=sprintf("%1.1f%%",Conversion_Rate*100)), hjust=-0.1, size=3,position=position_dodge(1),angle = 90)+
  scale_x_continuous(breaks=c(1,2,3,4,5,6,7,8,9,10),expand=c(0, 1.2))+
  scale_y_continuous(limits=c(0,0.005),labels=scales::percent_format(accuracy = 0.001)) +
  labs(x = "\n Decile", y = "Enrollment Rate\n", title = "\n Actual Enrollment Rate by Decile \n Train vs. Test \n 120-day Window, AEP & SEP") +
  theme_minimal()
p1.r + facet_grid(cols = vars(Region)) +
  geom_hline(data = EnrollmentRate.ByRegion, aes(yintercept = Conversion_Rate),linetype=2)

remove(Plot1)
remove(Plot2)
remove(p1)
remove(p2)
#remove(Log.120)
remove(DF.test.120)
remove(DF.train.120)
remove(roc_info)
remove(p1.r)
remove(Plot1.r)
remove(coef)
remove(cm)

## Determine which AEP-only or AEP+SEP is most predictable & run our baseline model

# AEP-only (120)
DF.train.120 <- DF.train %>% filter(Campaign=="AEP") %>% dplyr::select(-CONV_RESP_60DAY_FLAG,-CONV_ENROLL_90DAY_FLAG,-CONV_RESP_30DAY_FLAG,-Campaign)
DF.train.120 <- DF.train.120 %>% dplyr::select(-SUB_REGN_CD,-OCCU_CD,-IMAGE_MAIL_ORD_BYR_CD,-MAIL_ORD_RSPDR_CD,
                                               -SCORE_10,-KBM_Flag,-TAPESTRY_SEGMENT_CD,-SCORE_9,-SEP_DROP_9_FLAG,
                                               -SEP_DROP_8_FLAG,-SEP_DROP_7_FLAG,-SEP_DROP_6_FLAG,-POS_Professional,
                                               -POS_Premium,-SEP_DROP_3_FLAG,-SEP_DROP_2_FLAG,-SEP_DROP_1_FLAG,
                                               -HH_CHILD_CNT,-HH_PERSS_CNT,-SEP_DROP_5_FLAG,-EDUC_NO_HS,-UNEMPLOYMENT_RT,
                                               -HH_INCOME_200k,-HH_INCOME_0k_15k,-HH_INCOME_15_25k_FY,-DIVERSITY_INDEX,
                                               -POP_PER_SQ_MILE_FY,-POP_AGE_85_up,-HOMEOWNER_CD,-BENE_TotalValAdd,
                                               -PMPM_ValueAdd_YoY,-SEP_LATINO_DM_FLAG,-EDUC_HS,-MAIL_ORDER_BUYER,
                                               -CENS_HH_CHILD_PCT,-MA_Penetration_Rt,-MEDIAN_WHITE_FEMALE_AGE)
Log.120 <- glm(CONV_ENROLL_120DAY_FLAG ~ ., data = DF.train.120, family=binomial(logit)) %>% stepAIC(direction="forward")
summary(Log.120)
vif(Log.120) 

# goodness of fit
DF.test.120 <- DF.test %>% filter(Campaign=="AEP") %>% dplyr::select(-CONV_RESP_60DAY_FLAG,-CONV_ENROLL_90DAY_FLAG,-CONV_RESP_30DAY_FLAG)
DF.test.120$prediction <- predict(Log.120, newdata = DF.test.120, type = "response")
DF.train.120$prediction <- predict(Log.120, newdata = DF.train.120, type = "response")
roc_info<- cutpointr(DF.test.120,prediction,CONV_ENROLL_120DAY_FLAG,pos_class=1,method=maximize_metric,metric=sens_constrain,min_constrain=0.55) 
summary(roc_info)
#roc_info<- cutpointr(DF.test.120,prediction,CONV_ENROLL_120DAY_FLAG,pos_class=1,method=minimize_metric,metric=misclassification_cost,cost_fp=1,cost_fn=1200) 
#summary(roc_info)
cm <- caret::confusionMatrix(data = as.factor(ifelse(DF.test.120$prediction>=roc_info$optimal_cutpoint,1,0)), 
                             reference = as.factor(DF.test.120$CONV_ENROLL_120DAY_FLAG),
                             mode="everything",positive="1")
auc(roc_info)
cm 
roc_info$optimal_cutpoint
cm2 <- caret::confusionMatrix(data = as.factor(ifelse(DF.train.120$prediction>=roc_info$optimal_cutpoint,1,0)), 
                              reference = as.factor(DF.train.120$CONV_ENROLL_120DAY_FLAG),
                              mode="everything",positive="1")
F1.test <- cm$byClass[7]
F1.train <- cm2$byClass[7]
sprintf("%1.4f%%",((F1.test-F1.train)/F1.test)*100)
remove(cm)
remove(cm2)
remove(F1.test)
remove(F1.train)

# charts
DF.train.120$decile <- ntile(-DF.train.120$prediction, 10)
DF.test.20$decile <- ntile(-DF.test.120$prediction, 10)

DF.train.120$Region <- ifelse(DF.train$SUB_REGN_CD %in% c("CANC","CASC"),as.character(DF.train$SUB_REGN_CD),"ROC")
DF.test.120$Region <- ifelse(DF.test$SUB_REGN_CD %in% c("CANC","CASC"),as.character(DF.test$SUB_REGN_CD),"ROC")

DF.train.120 <- DF.train.120 %>% group_by(Region) %>% mutate(decile_region = ntile(-prediction, 10)) %>% ungroup()
DF.test.120 <- DF.test.120 %>% group_by(Region) %>% mutate(decile_region = ntile(-prediction, 10)) %>% ungroup()
tabyl(DF.train.120,decile_region,Region)

Test.Predicted <- DF.test.120 %>% 
  dplyr::group_by(decile_region) %>% 
  summarise(Conversion_Rate = mean(ifelse(prediction>=roc_info$optimal_cutpoint,1,0)),
            Conversions = sum(ifelse(prediction>=roc_info$optimal_cutpoint,1,0))) %>%
  mutate(Value="Predicted-Test") 
Test.Actual <- DF.test.120 %>% 
  group_by(decile_region) %>% 
  summarise(Conversion_Rate = mean(CONV_ENROLL_120DAY_FLAG),
            Conversions = sum(CONV_ENROLL_120DAY_FLAG)) %>%
  mutate(Value="Actual-Test")
Train.Predicted <- DF.train.120 %>% 
  dplyr::group_by(decile_region) %>% 
  summarise(Conversion_Rate = mean(ifelse(prediction>=roc_info$optimal_cutpoint,1,0)),
            Conversions = sum(ifelse(prediction>=roc_info$optimal_cutpoint,1,0))) %>%
  mutate(Value="Predicted-Train")  
Train.Actual <- DF.train.120 %>% 
  group_by(decile_region) %>% 
  summarise(Conversion_Rate = mean(CONV_ENROLL_120DAY_FLAG),
            Conversions = sum(CONV_ENROLL_120DAY_FLAG)) %>%
  mutate(Value="Actual-Train")
# plot 1: x-axis: decile, y-axis: conversion rate. 2 bars: train vs. test (ACTUAL) -- add baseline
Plot1 <- rbind(Train.Actual,Test.Actual)
# plot 2: x-axis: decile, y-axis: conversion rate. 2 bars: train vs. test (PREDICTED) -- add baseline
Plot2 <- rbind(Test.Actual,Test.Predicted) 
p1<-ggplot(data=Plot1, aes(x=decile_region, y=Conversion_Rate, fill=Value)) +
  geom_bar(stat="identity", position = position_dodge(1), alpha = 0.75)+
  geom_text(aes(label=sprintf("%1.2f%%",Conversion_Rate*100)), hjust=-0.1, size=3.5,position=position_dodge(1),angle = 90)+
  scale_x_continuous(breaks=c(1,2,3,4,5,6,7,8,9,10))+
  scale_y_continuous(limits=c(0,0.005),labels=scales::percent_format(accuracy = 0.001)) +
  labs(x = "\n Decile", y = "Enrollment Rate\n", title = "\n Actual Enrollment Rate by Decile \n Train vs. Test \n 120-day Window, AEP-only") +
  theme_minimal()
p1
p2<-ggplot(data=Plot2, aes(x=decile_region, y=Conversion_Rate, fill=Value)) +
  geom_bar(stat="identity", position = position_dodge(), alpha = 0.75)+
  geom_text(aes(label=sprintf("%1.2f%%",Conversion_Rate*100)), hjust=-0.1, size=3.5,position=position_dodge(1),angle = 90)+
  scale_x_continuous(breaks=c(1,2,3,4,5,6,7,8,9,10))+
  scale_y_continuous(limits=c(0,1.1),labels=scales::percent_format(accuracy = 1)) +
  labs(x = "\n Decile", y = "Enrollment Rate\n", title = "\n Actual v. Predicted Enrollment Rate by Decile \n Test Set (30%) \n 120-day Window, AEP-only") +
  theme_minimal()
p2

Train.Actual <- DF.train.120 %>% 
  group_by(decile_region,Region) %>% 
  summarise(Conversion_Rate = mean(CONV_ENROLL_120DAY_FLAG),
            Conversions = sum(CONV_ENROLL_120DAY_FLAG)) %>%
  mutate(Value="Actual-Train") %>%
  arrange(Region,decile_region) %>%
  ungroup()
Test.Actual <- DF.test.120 %>% 
  group_by(decile_region,Region) %>% 
  summarise(Conversion_Rate = mean(CONV_ENROLL_120DAY_FLAG),
            Conversions = sum(CONV_ENROLL_120DAY_FLAG)) %>%
  mutate(Value="Actual-Test") %>%
  arrange(Region,decile_region) %>%
  ungroup()
Plot1.r <- rbind(Train.Actual,Test.Actual)
p1.r<-ggplot(data=Plot1.r, aes(x=decile_region, y=Conversion_Rate, fill=Value)) +
  geom_bar(stat="identity", position = position_dodge(1), alpha = 0.75)+
  geom_text(aes(label=sprintf("%1.2f%%",Conversion_Rate*100)), hjust=-0.1, size=3,position=position_dodge(1),angle = 90)+
  scale_x_continuous(breaks=c(1,2,3,4,5,6,7,8,9,10))+
  scale_y_continuous(limits=c(0,0.005),labels=scales::percent_format(accuracy = 0.001)) +
  labs(x = "\n Decile", y = "Enrollment Rate\n", title = "\n Actual Enrollment Rate by Decile \n Train vs. Test \n 120-day Window, AEP-only") +
  theme_minimal()
p1.r + facet_grid(cols = vars(Region))

remove(Plot1)
remove(Plot2)
remove(p1)
remove(p2)
remove(Log.120)
remove(DF.test.120)
remove(DF.train.120)
remove(roc_info)
remove(p1.r)
remove(Plot1.r)