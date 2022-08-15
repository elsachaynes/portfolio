###########################################################################
#                                                                         #
# Program Name: Goodness_Of_Fit.R                                         #
# Date Created: 8/15/2022                                                 #
# Created By: Elsa Haynes (elsa.c.haynes@kp.org)                          #
#                                                                         #
# Outputs GOF metrics for a classification model.                         #
# Required packages: cutpointr, caret                                     #
#                                                                         #
###########################################################################

CalcGoodnessOfFit <- function(model, 
                              Train_DF, Test_DF, DepVar, 
                              model.name.text) {
  
  # determine optimal cutpoint (between 0 and 1)
  roc_info <- cutpointr(Test_DF, prediction, DepVar, 
                        pos_class=1, 
                        method = maximize_metric, metric = sens_constrain, 
                        min_constrain = 0.55,
                        boot_runs = 5,direction = ">=", break_ties=median) 
  #roc_info<- cutpointr(TesTest_DFt,prediction,DepVar,pos_class=1,method=minimize_metric,metric=abs_d_sens_spec,direction=">=")
  cutpoint <- roc_info$opimal_cutpoint
  
  # build confusion matrix for test and train
  cm.test <- caret::confusionMatrix(data = as.factor(ifelse(Test_DF$prediction>=cutpoint,1,0)), 
                                    reference = as.factor(Test_DF$DepVar),
                                    mode="everything", positive="1")
  cm.train <- caret::confusionMatrix(data = as.factor(ifelse(Train_DF$prediction>=cutpoint,1,0)), 
                                     reference = as.factor(Train_DF$DepVar),
                                     mode="everything", positive="1")
  # calculate difference in accuracy 
  F1.test <- cm.test$byClass[7]
  F1.train <- cm.train$byClass[7]
  # roc
  perf.test = prediction(Test_DF$prediction, Test_DF$DepVar)
  roc.test = performance(perf.test, "tpr","fpr")
  perf.train = prediction(Train_DF$prediction, Train_DF$DepVar)
  roc.train = performance(perf.train, "tpr","fpr")
  plot(roc.test,main=paste("ROC Curve for",model.name.text),col=2,lwd=2)
  plot(roc.train, add = TRUE,col="blue")
  abline(a=0,b=1,lwd=2,lty=2,col="gray")
  
  print(summary(roc_info))
  print(cm.test)
  print(paste("AUC:",auc(roc_info)))
  print(paste("Optimal cutpoint:",cutpoint))
  print(paste("Difference in F1 accuracy: Test-Train:",F1.test,"-",F1.train,":",
              sprintf("%1f%%",F1.test*100-F1.train*100)))
  return(roc_info)
}