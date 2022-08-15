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
library(cutpointr)
library(Hmisc)
library(ggplot2)
library(tidyr)
library(rpart)
library(rpart.plot)
library(DMwR)
library(ROSE)
library(ROCR)

setwd("~/")

## Import final table (this has been re-done)
DF <-data.table::fread(file='MED_DM_22_Targeting_Final.csv')

# Clean
DF$SVC_AREA_NM <- ifelse(DF$Region=="HI",as.character(DF$SUB_REGN_CD),as.character(DF$SVC_AREA_NM))
DF$Region_Granular <- ifelse(DF$Region %in% c("CANC","CASC","CO","GA","NW","U"),as.character(DF$Region),as.character(DF$SVC_AREA_NM))

# Set DV as numeric
DF$CONV_RESP_30DAY_FLAG <- as.numeric(DF$CONV_RESP_30DAY_FLAG)
DF$CONV_RESP_60DAY_FLAG <- as.numeric(DF$CONV_RESP_60DAY_FLAG)
DF$CONV_ENROLL_90DAY_FLAG <- as.numeric(DF$CONV_ENROLL_90DAY_FLAG)
DF$CONV_ENROLL_120DAY_FLAG <- as.numeric(DF$CONV_ENROLL_120DAY_FLAG)

# Set IV as factors
ListFactors.AD <- c("Region","SUB_REGN_CD","SVC_AREA_NM","Region_Granular")
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
  
  # Roc-only
  #DF <- DF %>% filter(Region != "CANC" & Region != "CASC") 
  
  ## Baseline conversion rates sprintf("%1.2f%%", 100*m)
  #ResponseRate.30days <- sprintf("%1.3f%%",100*prop.table(table(DF$CONV_RESP_30DAY_FLAG))[2])
  #ResponseRate.60days <- sprintf("%1.3f%%",100*prop.table(table(DF$CONV_RESP_60DAY_FLAG))[2])
  #EnrollmentRate.90days <- sprintf("%1.3f%%",100*prop.table(table(DF$CONV_ENROLL_90DAY_FLAG))[2])
  EnrollmentRate.120days <- sprintf("%1.3f%%",100*prop.table(table(DF$CONV_ENROLL_120DAY_FLAG))[2])
  
  #tabyl(DF$CONV_RESP_30DAY_FLAG)
  #tabyl(DF$CONV_RESP_60DAY_FLAG)
  #tabyl(DF$CONV_ENROLL_90DAY_FLAG)
  tabyl(DF$CONV_ENROLL_120DAY_FLAG)
  
  ## By Region
  EnrollmentRate.ByRegion <- DF %>%
    group_by(Region) %>%
    summarise(Conversion_Rate = mean(CONV_ENROLL_120DAY_FLAG)) %>%
    as.data.frame
  EnrollmentRate.ByRegion
  #write.table(EnrollmentRate.ByRegion, "clipboard", sep="\t")
  
  ## By Service Area

  EnrollmentRate.BySVCA <- DF %>%
    group_by(Region,Region_Granular) %>%
    summarise(Conversion_Rate = mean(CONV_ENROLL_120DAY_FLAG)) %>%
    arrange(Region,desc(Conversion_Rate)) %>%
    ungroup() %>%
    as.data.frame
  EnrollmentRate.BySVCA
  #write.table(EnrollmentRate.BySVCA, "clipboard", sep="\t")

  
  ## Baseline conversion rates AEP
  #DF.AEP <- DF %>% filter(Campaign=="AEP")
  #ResponseRate.30days.AEP <- sprintf("%1.3f%%",100*prop.table(table(DF.AEP$CONV_RESP_30DAY_FLAG))[2])
  #ResponseRate.60days.AEP <- sprintf("%1.3f%%",100*prop.table(table(DF.AEP$CONV_RESP_60DAY_FLAG))[2])
  #EnrollmentRate.90days.AEP <- sprintf("%1.3f%%",100*prop.table(table(DF.AEP$CONV_ENROLL_90DAY_FLAG))[2])
  #EnrollmentRate.120days.AEP <- sprintf("%1.3f%%",100*prop.table(table(DF.AEP$CONV_ENROLL_120DAY_FLAG))[2])
  
  #tabyl(DF.AEP$CONV_RESP_30DAY_FLAG)
  #tabyl(DF.AEP$CONV_RESP_60DAY_FLAG)
  #tabyl(DF.AEP$CONV_ENROLL_90DAY_FLAG)
  #tabyl(DF.AEP$CONV_ENROLL_120DAY_FLAG)

## Train/Test split
size <- floor(0.7 * nrow(DF)) # 70%
set.seed(123)
#set.seed(456) # for second validation
flag <- sample(seq_len(nrow(DF)), size = size)
DF.train <- DF[flag, ]
DF.test <- DF[-flag, ]
  remove(size)
  remove(flag)
Train <- DF.train %>% dplyr::select(-CONV_RESP_60DAY_FLAG,-CONV_ENROLL_90DAY_FLAG,-CONV_RESP_30DAY_FLAG,
                                    -SCORE_10,-SCORE_9,-SCORE_6,
                                    -SEP_DROP_9_FLAG,-SEP_DROP_8_FLAG,-SEP_DROP_7_FLAG)
Test <- DF.test %>% dplyr::select(-CONV_RESP_60DAY_FLAG,-CONV_ENROLL_90DAY_FLAG,-CONV_RESP_30DAY_FLAG,
                                  -SCORE_10,-SCORE_9,-SCORE_6,
                                  -SEP_DROP_9_FLAG,-SEP_DROP_8_FLAG,-SEP_DROP_7_FLAG)

Test$CONV_ENROLL_120DAY_FLAG <- as.factor(Test$CONV_ENROLL_120DAY_FLAG)
Train$CONV_ENROLL_120DAY_FLAG <- as.factor(Train$CONV_ENROLL_120DAY_FLAG)

## Sampling
#Train.OVUN.30 <- ovun.sample(CONV_ENROLL_120DAY_FLAG ~ ., data = Train, method = "both",p=0.3, N = 3000000, seed = 1)$data
#Train.OVUN.50 <- ovun.sample(CONV_ENROLL_120DAY_FLAG ~ ., data = Train, method = "both",p=0.5, N = 1000000, seed = 1)$data
#Train.SMOTE <- SMOTE(form=CONV_ENROLL_120DAY_FLAG ~ .,as.data.frame(Train),perc.over=900,perc.under=300)
Train.OVUN.50.ROC <- ovun.sample(CONV_ENROLL_120DAY_FLAG ~ ., data = Train, method = "both",p=0.5, N = 200000, seed = 1)$data

Train.Region <- Train$Region
Test.Region <- Test$Region
Train.Region_Granular <- Train$Region_Granular
Test.Region_Granular <- Test$Region_Granular
  remove(DF.train)
  remove(DF.test)
  remove(DF)
  #remove(DF.AEP)
  
  ## functions
  # labeling improvement
  split.fun <- function(x, labs, digits, varlen, faclen)
  {
    # replace commas with spaces (needed for strwrap)
    labs <- gsub(",", " ", labs)
    for(i in 1:length(labs)) {
      # split labs[i] into multiple lines
      labs[i] <- paste(strwrap(labs[i], width = 15), collapse = "\n")
    }
    labs
  }
  
  # goodness of fit
  model.gof <- function(model,Train.Data,model.name) {
    
    # determine optimal cutpoint (between 0 and 1)
    roc_info <<- cutpointr(Test,prediction,CONV_ENROLL_120DAY_FLAG,pos_class=1,
                           method=maximize_metric,metric=sens_constrain,min_constrain=0.55,
                           boot_runs=5,direction=">=",break_ties=median) 
    #roc_info<- cutpointr(Test,prediction,CONV_ENROLL_120DAY_FLAG,pos_class=1,method=minimize_metric,metric=abs_d_sens_spec,direction=">=") 
    
    # build confusion matrix for test and train
    cm.test <- caret::confusionMatrix(data = as.factor(ifelse(Test$prediction>=roc_info$optimal_cutpoint,1,0)), 
                                      reference = as.factor(Test$CONV_ENROLL_120DAY_FLAG),
                                      mode="everything",positive="1")
    cm.train <- caret::confusionMatrix(data = as.factor(ifelse(Train.Data$prediction>=roc_info$optimal_cutpoint,1,0)), 
                                       reference = as.factor(Train.Data$CONV_ENROLL_120DAY_FLAG),
                                       mode="everything",positive="1")
    # calculate difference in accuracy 
    F1.test <- cm.test$byClass[7]
    F1.train <- cm.train$byClass[7]
    # roc
    perf.test = prediction(Test$prediction, Test$CONV_ENROLL_120DAY_FLAG)
    roc.test = performance(perf.test, "tpr","fpr")
    perf.train = prediction(Train.Data$prediction, Train.Data$CONV_ENROLL_120DAY_FLAG)
    roc.train = performance(perf.train, "tpr","fpr")
    plot(roc.test,main=paste("ROC Curve for",model.name),col=2,lwd=2)
    plot(roc.train, add = TRUE,col="blue")
    abline(a=0,b=1,lwd=2,lty=2,col="gray")
    
    print(summary(roc_info))
    print(cm.test)
    print(paste("AUC:",auc(roc_info)))
    print(paste("Optimal cutpoint:",roc_info$optimal_cutpoint))
    print(paste("Difference in F1 accuracy: Test-Train:",F1.test,"-",F1.train,":",sprintf("%1f%%",F1.test*100-F1.train*100)))
    
  }
  
  # decile charts
  model.charts <- function(model,Train.Data,model.name) {
    
    # save local dataset
    plot.data.train <- Train.Data
    plot.data.test <- Test
    
    # set DV as numeric for calculations
    plot.data.train$CONV_ENROLL_120DAY_FLAG <- as.numeric(as.character(plot.data.train$CONV_ENROLL_120DAY_FLAG))
    plot.data.test$CONV_ENROLL_120DAY_FLAG <- as.numeric(as.character(plot.data.test$CONV_ENROLL_120DAY_FLAG))
    
    # add deciles by region & subregion
    plot.data.train$Region <- Train.Region
    plot.data.test$Region <- Test.Region
    plot.data.train <- plot.data.train %>% group_by(Region) %>% mutate(decile_region = ntile(-prediction, 10)) %>% ungroup()
    plot.data.test <- plot.data.test %>% group_by(Region) %>% mutate(decile_region = ntile(-prediction, 10)) %>% ungroup()
    plot.data.train$Region_Granular <- Train.Region_Granular
    plot.data.test$Region_Granular <- Test.Region_Granular
    plot.data.train <- plot.data.train %>% group_by(Region_Granular) %>% mutate(decile_SVC = ntile(-prediction, 10)) %>% ungroup()
    plot.data.test <- plot.data.test %>% group_by(Region_Granular) %>% mutate(decile_SVC = ntile(-prediction, 10)) %>% ungroup()
    
    # plot overall deciles
    Test.Predicted <- plot.data.test %>% 
      dplyr::group_by(decile_region) %>% 
      summarise(Conversion_Rate = mean(ifelse(prediction>=roc_info$optimal_cutpoint,1,0)),
                Conversions = sum(ifelse(prediction>=roc_info$optimal_cutpoint,1,0))) %>%
      mutate(Value="Predicted-Test") 
    Test.Actual <<- plot.data.test %>% 
      group_by(decile_region) %>% 
      summarise(Conversion_Rate = mean(CONV_ENROLL_120DAY_FLAG),
                Conversions = sum(CONV_ENROLL_120DAY_FLAG)) %>%
      mutate(Value="Actual-Test")
    Train.Predicted <- plot.data.train %>% 
      dplyr::group_by(decile_region) %>% 
      summarise(Conversion_Rate = mean(ifelse(prediction>=roc_info$optimal_cutpoint,1,0)),
                Conversions = sum(ifelse(prediction>=roc_info$optimal_cutpoint,1,0))) %>%
      mutate(Value="Predicted-Train")  
    Train.Actual <<- plot.data.train %>% 
      group_by(decile_region) %>% 
      summarise(Conversion_Rate = mean(CONV_ENROLL_120DAY_FLAG),
                Conversions = sum(CONV_ENROLL_120DAY_FLAG)) %>%
      mutate(Value="Actual-Train")
    Plot1 <- rbind(Train.Actual,Test.Actual)
    Plot2 <- rbind(Test.Actual,Test.Predicted) 
    p1<-ggplot(data=Plot1, aes(x=decile_region, y=Conversion_Rate, fill=Value)) +
      geom_bar(stat="identity", position = position_dodge(1), alpha = 0.75)+
      geom_text(aes(label=sprintf("%1.2f%%",Conversion_Rate*100)), hjust=-0.1, size=3.5,position=position_dodge(1),angle = 90)+
      scale_x_continuous(breaks=c(1,2,3,4,5,6,7,8,9,10))+
      scale_y_continuous(limits=c(0,0.005),labels=scales::percent_format(accuracy = 0.001)) +
      labs(x = "\n Decile", y = "Enrollment Rate\n", title = paste0(model.name,"\n Actual Enrollment Rate by Decile \n Train vs. Test \n 120-day Window, AEP & SEP")) +
      theme_minimal()
    p1 + geom_hline(aes(yintercept=extract_numeric(EnrollmentRate.120days)/100),linetype=2) +
      annotate("text", x=9, y=0.0002+(extract_numeric(EnrollmentRate.120days)/100), label=paste("Base Rate:",EnrollmentRate.120days))
    p2<-ggplot(data=Plot2, aes(x=decile_region, y=Conversion_Rate, fill=Value)) +
      geom_bar(stat="identity", position = position_dodge(), alpha = 0.75)+
      geom_text(aes(label=sprintf("%1.2f%%",Conversion_Rate*100)), hjust=-0.1, size=3.5,position=position_dodge(1),angle = 90)+
      scale_x_continuous(breaks=c(1,2,3,4,5,6,7,8,9,10))+
      scale_y_continuous(limits=c(0,1.1),labels=scales::percent_format(accuracy = 1)) +
      labs(x = "\n Decile", y = "Enrollment Rate\n", title = paste0(model.name,"\n Actual v. Predicted Enrollment Rate by Decile \n Test Set (30%) \n 120-day Window, AEP & SEP")) +
      theme_minimal()
    p2 + geom_hline(aes(yintercept=extract_numeric(EnrollmentRate.120days)/100),linetype=2) +
      annotate("text", x=9, y=0.0002+(extract_numeric(EnrollmentRate.120days)/100), label=paste("Base Rate:",EnrollmentRate.120days))
    
    #plot regional deciles
    Train.Actual <- plot.data.train %>% 
      group_by(decile_region,Region) %>% 
      summarise(Conversion_Rate = mean(CONV_ENROLL_120DAY_FLAG),
                Conversions = sum(CONV_ENROLL_120DAY_FLAG)) %>%
      mutate(Value="Actual-Train") %>%
      arrange(Region,decile_region) %>%
      ungroup()
    Test.Actual <- plot.data.test %>% 
      group_by(decile_region,Region) %>% 
      summarise(Conversion_Rate = mean(CONV_ENROLL_120DAY_FLAG),
                Conversions = sum(CONV_ENROLL_120DAY_FLAG)) %>%
      mutate(Value="Actual-Test") %>%
      arrange(Region,decile_region) %>%
      ungroup()
    Plot1.r <- rbind(Train.Actual,Test.Actual)
    p1.r<-ggplot(data=Plot1.r, aes(x=decile_region, y=Conversion_Rate, fill=Value)) +
      geom_bar(stat="identity", position = position_dodge(1), alpha = 0.75)+
      #geom_text(aes(label=sprintf("%1.1f%%",Conversion_Rate*100)), hjust=-0.1, size=3,position=position_dodge(1),angle = 90)+
      scale_x_continuous(breaks=c(1,2,3,4,5,6,7,8,9,10),expand=c(0, 1.2))+
      scale_y_continuous(limits=c(0,0.005),labels=scales::percent_format(accuracy = 0.001)) +
      labs(x = "\n Decile", y = "Enrollment Rate\n", title = paste0(model.name,"\n Actual Enrollment Rate by Decile \n Train vs. Test \n 120-day Window, AEP & SEP")) +
      theme_minimal()
    p1.r + facet_wrap(~Region,ncol = 4) +
      geom_hline(data = EnrollmentRate.ByRegion, aes(yintercept = Conversion_Rate),linetype=2)
    
    # plot Sub-Region deciles
    Train.Actual <- plot.data.train %>% 
      group_by(decile_SVC,Region_Granular) %>% 
      summarise(Conversion_Rate = mean(CONV_ENROLL_120DAY_FLAG),
                Conversions = sum(CONV_ENROLL_120DAY_FLAG)) %>%
      mutate(Value="Actual-Train") %>%
      arrange(Region_Granular,decile_SVC) %>%
      ungroup()
    Test.Actual <- plot.data.test %>% 
      group_by(decile_SVC,Region_Granular) %>% 
      summarise(Conversion_Rate = mean(CONV_ENROLL_120DAY_FLAG),
                Conversions = sum(CONV_ENROLL_120DAY_FLAG)) %>%
      mutate(Value="Actual-Test") %>%
      arrange(Region_Granular,decile_SVC) %>%
      ungroup()
    Plot1.r <- rbind(Train.Actual,Test.Actual)
    p1.sr<-ggplot(data=Plot1.r, aes(x=decile_SVC, y=Conversion_Rate, fill=Value)) +
      geom_bar(stat="identity", position = position_dodge(1), alpha = 0.75)+
      #geom_text(aes(label=sprintf("%1.1f%%",Conversion_Rate*100)), hjust=-0.1, size=3,position=position_dodge(1),angle = 90)+
      scale_x_continuous(breaks=c(1,2,3,4,5,6,7,8,9,10),expand=c(0, 1.2))+
      scale_y_continuous(limits=c(0,0.005),labels=scales::percent_format(accuracy = 0.001)) +
      labs(x = "\n Decile", y = "Enrollment Rate\n", title = paste0(model.name,"\n Actual Enrollment Rate by Decile \n Train vs. Test \n 120-day Window, AEP & SEP")) +
      theme_minimal()
    p1.sr + facet_wrap(~Region_Granular,ncol = 7) +
      geom_hline(data = EnrollmentRate.BySVCA, aes(yintercept = Conversion_Rate),linetype=2)
    
    return(list(p1 + geom_hline(aes(yintercept=extract_numeric(EnrollmentRate.120days)/100),linetype=2) +
                  annotate("text", x=9, y=0.0002+(extract_numeric(EnrollmentRate.120days)/100), label=paste("Base Rate:",EnrollmentRate.120days)),
                p2 + geom_hline(aes(yintercept=extract_numeric(EnrollmentRate.120days)/100),linetype=2) +
                  annotate("text", x=9, y=0.0002+(extract_numeric(EnrollmentRate.120days)/100), label=paste("Base Rate:",EnrollmentRate.120days)),
                p1.r + facet_wrap(~Region,ncol = 4) +
                  geom_hline(data = EnrollmentRate.ByRegion, aes(yintercept = Conversion_Rate),linetype=2),
                p1.sr + facet_wrap(~Region_Granular,ncol = 7) +
                  geom_hline(data = EnrollmentRate.BySVCA, aes(yintercept = Conversion_Rate),linetype=2)))
    
  }
  
  
  
  
  
  
  
  
  # Logistic
  Train.Log <- Train %>% dplyr::select(-Region,-Region_Granular,-BENE_AEPGrowth,-SUB_REGN_CD,-SVC_AREA_NM,-BENE_TotalValAdd
                                      #,-prediction
                                      )
  Train.Log <- Train.Log %>% dplyr::select(-OCCU_CD,-KBM_Flag,-TAPESTRY_SEGMENT_CD,-HH_CHILD_CNT
                                           # p-val > 0.5
                                           ,-MOB_DIST_MSR,-HH_INCOME_200k,-HH_INCOME_0k_15k,-POP_HISPANIC_FY,-EDUC_NO_HS
                                           # p-val > 0.15
                                           ,-UNIT_NBR_PRSN_IND,-PRSN_CHILD_IND,-CENS_HH_CHILD_PCT
                                           )
  Log <- glm(CONV_ENROLL_120DAY_FLAG ~ ., data = Train.Log, family=binomial(logit), model=FALSE, y=FALSE) %>% stepAIC(direction="forward")
  summary(Log)
  vif(Log)
  coef <- as.data.frame(Log$coefficients) %>% arrange(desc(abs(Log$coefficients))) %>% as.data.frame
  write.table(coef, "clipboard", sep="\t")

  #Log <- readRDS("M1_Log.rds")
  #Log.cutpoint <- readRDS("M1_Log_cutpoint.rds")
  
  Test$prediction <- predict(Log, newdata = Test, type = "response")
  Train$prediction <- predict(Log, newdata = Train, type = "response")

  model.gof(Log,Train,"Logistic")
  model.charts(Log,Train,"Logistic")
  
  # make the glm object smaller
  Log[c("residuals", "weights", "fitted.values","data","prior.weights","na.action","linear.predictors","effects")] <- NULL
  Log$qr$qr <- NULL
  
  #saveRDS(Log, "M1_Log.rds")
  #saveRDS(roc_info$optimal_cutpoint,"M1_Log_cutpoint.rds")
  
  remove(Log)
  remove(Train.Log)
  remove(coef)
  remove(roc_info)

  
  
  
  
  
  
  
# Tree with Under/Over sampling 50 % 1M

tabyl(Train$CONV_ENROLL_120DAY_FLAG) #0.136% w/ 5.3M total Train records
tabyl(Train.OVUN.50$CONV_ENROLL_120DAY_FLAG) #50% w/ 1M total Train records

Train.Tree1 <- Train.OVUN.50 %>% dplyr::select(-Region,-Region_Granular,
                                           -SVC_AREA_NM,-SUB_REGN_CD,-BENE_AEPGrowth,
                                           #-prediction
                                           #,-decile_region,-decile_SVC
                                           )
  remove(Train.OVUN.50)
tree1 <- rpart(CONV_ENROLL_120DAY_FLAG ~ ., 
              data = Train.Tree1, #too imbalanced to use full Train set
              method = "class",
              control = rpart.control(minbucket = nrow(Train.Tree1)/600, xval = 10, cp = 0.0005, maxdepth=8)) #, cp=0.01
printcp(tree1)
prp(tree1, type=3, split.fun = split.fun, cex=0.5,
    box.palette = "RdYlGn", main = "Decision Tree with Over/Under-Sampling to 50% w/ 1M rec")
varimp <- as.data.frame(tree1$variable.importance)
write.table(varimp, "clipboard", sep="\t")
plotcp(tree1)

#tree1 <- readRDS("tree1")
#tree1.cutpoint <- readRDS("tree1_cutpoint.rds")

Test$prediction <- predict(tree1, newdata = Test, type = "prob")[,2]
Train$prediction <- predict(tree1, newdata = Train, type = "prob")[,2]

model.gof(tree1,Train,"Decision Tree 1")
model.charts(tree1,Train,"Decision Tree 1")

saveRDS(tree1, "tree1.rds")
saveRDS(roc_info$optimal_cutpoint,"tree1_cutpoint.rds")

remove(tree1)
remove(varimp)
remove(Train.Tree1)
remove(Train.OVUN.50)
remove(roc_info)







# Tree with Over/Under sampling 30% 3M

tabyl(Train$CONV_ENROLL_120DAY_FLAG) #0.136% w/ 5.3M total Train records
tabyl(Train.OVUN.30$CONV_ENROLL_120DAY_FLAG) #30% w/ 3M total Train records

Train.Tree2 <- Train.OVUN.30 %>% dplyr::select(-Region,-Region_Granular,
                                               -SVC_AREA_NM,-SUB_REGN_CD,-BENE_AEPGrowth,
                                               #-prediction
                                               #,-decile_region,-decile_SVC
                                                )
  remove(Train.OVUN.30)
tree2 <- rpart(CONV_ENROLL_120DAY_FLAG ~ ., 
               data = Train.Tree2, #too imbalanced to use full Train set
               method = "class",
               control = rpart.control(minbucket = nrow(Train.Tree2)/600, xval = 10, cp = 0.0005, maxdepth=7)) #, cp=0.01
printcp(tree2)
prp(tree2, type=3, split.fun = split.fun, cex=0.5,
    box.palette = "RdYlGn", main = "Decision Tree with Over/Under-Sampling to 30% w/ 3M rec")
varimp <- as.data.frame(tree2$variable.importance)
write.table(varimp, "clipboard", sep="\t")
plotcp(tree2)

#tree2 <- readRDS("tree2")
#tree2.cutpoint <- readRDS("tree2_cutpoint.rds")

Test$prediction <- predict(tree2, newdata = Test, type = "prob")[,2]
Train$prediction <- predict(tree2, newdata = Train, type = "prob")[,2]

model.gof(tree2,Train,"Decision Tree 2")
model.charts(tree2,Train,"Decision Tree 2")

saveRDS(tree2, "tree2.rds")
saveRDS(roc_info$optimal_cutpoint, "tree2_cutpoint.rds")

remove(tree2)
remove(roc_info)
remove(varimp)
remove(Train.Tree2)
remove(Train.OVUN.30)






# Bagged CART tree
Train.treebag <- Train.OVUN.50 %>% dplyr::select(-Region,-Region_Granular,
                                            -SVC_AREA_NM,-SUB_REGN_CD,-BENE_AEPGrowth,
                                            -prediction
)
  remove(Train.OVUN.50)
  gc()
tree.bag <- train(CONV_ENROLL_120DAY_FLAG ~ ., data = Train.treebag, method = "treebag",
                  #metric = "ROC", 
                  #nbagg = 5,
                  #cp = 0.0005,
                  trControl = trainControl(method = "cv", number = 3, verboseIter = TRUE))

printcp(tree.bag)
prp(tree.bag, type=3, split.fun = split.fun, cex=0.5,
    box.palette = "RdYlGn", main = "Bagged Decision Tree Over/Under sampling to 50% w/ 1M rec")
varimp <- as.data.frame(tree.bag$variable.importance)
write.table(varimp, "clipboard", sep="\t")
plotcp(tree.bag)

#tree.bag <- readRDS("M4_treebag.rds")
#tree.bag.cutpoint <- readRDS("M4_treebag_cutpoint.rds")

Test$prediction <- predict(tree.bag, newdata = Test, type = "prob")[,2]
Train$prediction <- predict(tree.bag, newdata = Train, type = "prob")[,2]

model.gof(tree.bag,Train,"Bagged CART")
model.charts(tree.bag,Train,"Bagged CART")

saveRDS(tree.bag, "M4_treebag.rds")
saveRDS(roc_info$optimal_cutpoint, "M4_treebag_cutpoint.rds")

remove(tree.bag)
remove(roc_info)




         
# RF
library(randomForest)
Train.RF <- Train.SMOTE %>% dplyr::select(-Region,-Region_Granular,
                                            -SVC_AREA_NM,-SUB_REGN_CD,-BENE_AEPGrowth,
                                            -OCCU_CD,-TAPESTRY_SEGMENT_CD
                                            #-prediction
                                              #,-decile_region,-decile_SVC
                                            )

  remove(Train.OVUN.50)
# determine number of variables in each tree
#mtry <- tuneRF(x=Train.RF[-28],y=Train.RF$CONV_ENROLL_120DAY_FLAG, ntreeTry=20,stepFactor=1.5,improve=0.01, trace=TRUE, plot=TRUE)
gc()
rf <- randomForest(CONV_ENROLL_120DAY_FLAG ~., data = Train.RF,ntree=100,mtry=5,importance=TRUE) 
print(rf)
importance(rf)
varImpPlot(rf)

#rf <- readRDS("rf.rds")
 
Test$prediction <- predict(rf, newdata = Test, type = "prob")[,2]
Train$prediction <- predict(rf, newdata = Train, type = "prob")[,2]

model.gof(rf,Train,"Random Forest")
model.charts(rf,Train,"Random Forest")

saveRDS(rf, "rf.rds")
saveRDS(roc_info$optimal_cutpoint, "rf_cutpoint.rds")

remove(rf)
remove(roc_info)
remove(Train.RF)
gc()

# RF2 - ROC only
library(randomForest)
Train.RF2 <- Train.OVUN.50.ROC %>% dplyr::select(-Region,-Region_Granular,
                                            -SVC_AREA_NM,-SUB_REGN_CD,-BENE_AEPGrowth,
                                            -OCCU_CD,-TAPESTRY_SEGMENT_CD
                                            #-prediction
                                            #,-decile_region,-decile_SVC
)
  remove(Train.OVUN.50.ROC)
#mtry <- tuneRF(x=Train.RF2[-27],y=Train.RF2$CONV_ENROLL_120DAY_FLAG, ntreeTry=100,stepFactor=1.5,improve=0.01, trace=TRUE, plot=TRUE)
remove(mtry)
gc()
rf2 <- randomForest(CONV_ENROLL_120DAY_FLAG ~., data = Train.RF2,ntree=50,mtry=10,importance=T) 
print(rf2)
importance(rf2)
varImpPlot(rf2)

rf2 <- readRDS("M8_rfROC.rds")
rf2$terms

Test$prediction <- predict(rf2, newdata = Test, type = "prob")[,2]
Train$prediction <- predict(rf2, newdata = Train, type = "prob")[,2]

model.gof(rf2,Train,"Random Forest - ROC")
model.charts(rf2,Train,"Random Forest - ROC")

saveRDS(rf2, "M8_rfROC.rds")
saveRDS(roc_info$optimal_cutpoint, "M8_rfROC_cutpoint.rds")

remove(rf2)
remove(roc_info)
remove(Train.RF2)
gc()




# ANN
library(neuralnet)
library(nnet)

Train.ANN <- Train.SMOTE %>% dplyr::select(-Region,-Region_Granular,-BENE_AEPGrowth,
                                           -SUB_REGN_CD,-SVC_AREA_NM,-BENE_TotalValAdd
                                            #,-prediction
)

# scale
ListDV <- Train.ANN %>% dplyr::select(starts_with("CONV")) %>% names()
ListDV <- which(colnames(Train.ANN) %in% ListDV)
ListNumeric <- sapply(Train.ANN, is.numeric)
ListNumeric[ListDV[1]] <- FALSE
names(Train.ANN[ListNumeric])
Train.ANN[ListNumeric] <- lapply(Train.ANN[ListNumeric], scale)
  remove(ListDV)
  remove(ListNumeric)

Train.ANN.matrix <- model.matrix(~ CONV_ENROLL_120DAY_FLAG+POP_AGE_85_UP+POP_AVG_HH_SIZE+POP_PER_SQ_MILE_FY+
                                   HOUSIG_ARRORDAB_INDEX+DIVERSITY_INDEX+MEDIAN_WHITE_FEMALE_AGE+MEDIAN_HISP_MALE_AGE+
                                   POP_HISPANIC_FY+HH_INCOME_0k_15k+HH_INCOME_200k+MEDIAN_NET_WORTH_65_74+HH_INCOME_15_25k_FY+
                                   UNEMPLOYMENT_RT+POP_65_up_IN_LABOR_FORCE+EDUC_NO_HIS+EDUC_HS+PROMOTED_SEP_FLAG+
                                   LIST_SOURCE_EXPERIAN_FLAG+SEP_LATINO_DM_FLAG+SEP_DROP_1_FLAG+SEP_DROP_1_FLAG+
                                   SEP_DROP_3_FLAG+SEP_DROP_4_FLAG+SEP_DROP_5_FLAG+SEP_DROP_6_FLAG+MA_Penetration_Rt+
                                   POS_Premium+POS_Inpatient+POS_Professional+PMPM_ValueAdd_YOY+HOSP_DIST_MSR+
                                   BENE_TotalValAdd+AGE_VAL+CENS_HH_CHILD_PCT+CENS_HISPANIC_PCT+CENS_MARRIED_PCT+
                                   CENS_SINGLE_HOME_PCT+CENS_WHITE_PCT+HH_PERSS_CNT+HH_CHILD_CNT+
                                   Campaign+ONE_PER_ADDR_IND+PRSN_CHILD_IND+UNIT_NBR_PRSN_IND+ADDR_VRFN_CD+KBM_Flag+
                                   LENGTH_RESID_BIN+MEXICO_CO_ORIGIN_FLAG+HOMEOWNER_CD+MAIL_ORDER_BUYER+MAIL_ORDER_BUYER_M,
                                 data = Train.ANN 
                              )
head(Train.ANN.matrix)
set.seed(123)
ann <- neuralnet(CONV_ENROLL_120DAY_FLAG ~., data = Train.ANN.matrix, 
                 hidden=3, #start small, also c(2,2,2)
                 act.fct = "logistic",
                 linear.output = T,
                 lifesign="full",
                 threshold=0.01,
                 #rep = 2,
                 #algorithm = "rprop+",
                 #stepmax = 100000
                 )
plot(ann)

#ann <- train(Train.ANN, Train.ANN$CONV_ENROLL_120DAY_FLAG,
#                    method = "nnet",
#                    linout=T,
#                    size=3
#                    trControl= trainControl(method = "cv", number = 3, verboseIter = TRUE))

Test$prediction = compute(ann, Test[-28])$net.result
Train$prediction = compute(ann, Train[-28])$net.result

model.gof(ann,Train,"Neural Net")
model.charts(ann,Train,"Neural Net")

saveRDS(ann, "M9_ann.rds")
saveRDS(roc_info$optimal_cutpoint, "M9_ann_cutpoint.rds")

remove(ann)
remove(roc_info)
remove(Train.ANN)
gc()

# For plotting
DF$CONV_ENROLL_120DAY_FLAG <- as.factor(DF$CONV_ENROLL_120DAY_FLAG)

  # Log
  Log <- readRDS("M1_Log.rds")
  DF$prediction <- predict(Log, newdata = DF, type = "response")
  
  # RF for MAS and NW
  RF.ROC <- readRDS("M8_rfROC.rds")
  DF$predictionROC <- predict(RF.ROC, newdata = DF, type = "prob")[,2]
  DF$prediction <- ifelse(DF$Region %in% c("MAS","NW"),DF$predictionROC,DF$prediction)
  DF <- DF %>% dplyr::select(-predictionROC)
  
DF$CONV_ENROLL_120DAY_FLAG <- as.numeric(as.character(DF$CONV_ENROLL_120DAY_FLAG))
  
  DF <- DF %>% filter(Campaign=="AEP") %>% group_by(Region) %>% mutate(decile_region = ntile(-prediction, 10)) %>% ungroup()
  DF$decile_region <- factor(DF$decile_region, levels = c("1","2","3","4","5","6","7","8","9","10"))

  Plot <- DF %>% 
    group_by(decile_region) %>% 
    summarise(Conversion_Rate = mean(CONV_ENROLL_120DAY_FLAG),
              Conversions = sum(CONV_ENROLL_120DAY_FLAG),
              CNT = n()) 
  write.table(Plot, "clipboard", sep="\t")
  
  #plot regional deciles
  Plot.Region <- DF %>% 
    filter(Region != "U") %>%
    group_by(decile_region,Region) %>% 
    summarise(Conversion_Rate = mean(CONV_ENROLL_120DAY_FLAG),
              Conversions = sum(CONV_ENROLL_120DAY_FLAG),
              CNT = n()) %>%
    arrange(Region,decile_region) %>%
    ungroup()
  
  EnrollmentRate.ByRegion <- DF %>%
    filter(Region != "U") %>%
    group_by(Region) %>%
    summarise(Conversion_Rate = mean(CONV_ENROLL_120DAY_FLAG)) %>%
    as.data.frame
  EnrollmentRate.ByRegion
 
  p1.r<-ggplot(data=Plot.Region, aes(x=decile_region, y=Conversion_Rate)) +
    geom_bar(stat="identity", position = position_dodge(1), alpha = 0.75)+
    geom_text(aes(label=sprintf("%1.2f%%",Conversion_Rate*100)), hjust=-0.1, size=3,position=position_dodge(1),angle = 90)+
    #scale_x_continuous(breaks=c(1,2,3,4,5,6,7,8,9,10),expand=c(0, 1.2))+
    scale_y_continuous(limits=c(0,0.005),labels=scales::percent_format(accuracy = 0.001)) +
    labs(x = "\n Decile", y = "Enrollment Rate\n", title = paste0("\n AEP Enrollment Rate by Decile \n by Region")) +
    theme_minimal()
  p1.r + facet_wrap(~Region,ncol = 5) +
    geom_hline(data = EnrollmentRate.ByRegion, aes(yintercept = Conversion_Rate),linetype=2)
  
  p1.r<-ggplot(data=Plot.Region, aes(x=decile_region, y=Conversion_Rate)) +
    geom_bar(stat="identity", position = position_dodge(1), alpha = 0.75)+
    geom_text(aes(label=sprintf("%1.2f%%",Conversion_Rate*100)), hjust=-0.1, size=3,position=position_dodge(1),angle = 90)+
    #scale_x_continuous(breaks=c(1,2,3,4,5,6,7,8,9,10),expand=c(0, 1.2))+
    scale_y_continuous(limits=c(0,0.025),labels=scales::percent_format(accuracy = 0.001)) +
    labs(x = "\n Decile", y = "Enrollment Rate\n", title = paste0("\n AEP Enrollment Rate by Decile \n by Region")) +
    theme_minimal()
  p1.r + facet_wrap(~Region,ncol = 5) +
    geom_hline(data = EnrollmentRate.ByRegion, aes(yintercept = Conversion_Rate),linetype=2)
  