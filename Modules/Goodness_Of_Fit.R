###########################################################################
#                                                                         #
# Program Name: Goodness_Of_Fit.R                                         #
# Date Created: 8/15/2022                                                 #
# Created By: Elsa Haynes (elsa.c.haynes@kp.org)                          #
#                                                                         #
# Outputs GOF metrics for a classification model.                         #
# Required packages: cutpointr, ROCR                                      #
#                                                                         #
###########################################################################

CalcGoodnessOfFit <- function(model, 
                              Train_DF, Test_DF, DepVar_Quoted,
                              min_constrain,
                              model.name.text) {
  
  print("Convert dependent var to vectors.")
  Train_Y <- Train_DF[[DepVar_Quoted]]
  Test_Y <- Test_DF[[DepVar_Quoted]]
  print("Convert dependent var to vectors complete.")
  
  print("Determine optimal cutpoint.")
  roc_info <- cutpointr(Test_DF, prediction, Conv_Enroll_Flag, 
                        pos_class=1, 
                        method = maximize_metric, metric = sens_constrain, 
                        min_constrain = min_constrain,
                        boot_runs = 5,direction = ">=", break_ties=median) 
  #roc_info<- cutpointr(TesTest_DFt,prediction,DepVar,pos_class=1,method=minimize_metric,metric=abs_d_sens_spec,direction=">=")
  cutpoint <- roc_info$optimal_cutpoint
  print("Determine optimal cutpoint complete.")
  
  print("Build confusion matrix.")
  cm.test <- caret::confusionMatrix(data = as.factor(ifelse(Test_DF$prediction>=cutpoint,1,0)), 
                                    reference = Test_Y,
                                    mode="everything", positive="1")
  cm.train <- caret::confusionMatrix(data = as.factor(ifelse(Train_DF$prediction>=cutpoint,1,0)), 
                                     reference = Train_Y,
                                     mode="everything", positive="1")
  print("Build confusion matrix complete.")
  
  print("Printing accuracy metrics.")
  F1.test <- cm.test$byClass[7]
  F1.train <- cm.train$byClass[7]
  print(summary(roc_info))
  print(cm.test)
  print(paste("AUC:",roc_info$AUC))
  print(paste("Optimal cutpoint:",cutpoint))
  print(paste("Difference in F1 accuracy: Test-Train:",F1.test,"-",F1.train,":",
              sprintf("%1f%%",F1.test*100-F1.train*100)))
  
  print("Plotting ROC curve.")
  perf.test = prediction(Test_DF$prediction, Test_Y)
  roc.test = ROCR::performance(perf.test, "tpr","fpr")
  perf.train = prediction(Train_DF$prediction, Train_Y)
  roc.train = ROCR::performance(perf.train, "tpr","fpr")
  plot(roc.test,main=paste("ROC Curve for",model.name.text),col=2,lwd=2)
  plot(roc.train, add = TRUE,col="blue")
  abline(a=0,b=1,lwd=2,lty=2,col="gray")
  print("Plotting ROC curve complete.")
  
  return(list(roc_info, 
         plot(roc.test,main=paste("ROC Curve for",model.name.text),col=2,lwd=2),
         plot(roc.train, add = TRUE,col="blue"),
         abline(a=0,b=1,lwd=2,lty=2,col="gray"))
         )
}