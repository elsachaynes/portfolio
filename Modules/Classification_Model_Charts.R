###########################################################################
#                                                                         #
# Program Name: Classification_Model_Charts.R                             #
# Date Created: 8/15/2022                                                 #
# Created By: Elsa Haynes (elsa.c.haynes@kp.org)                          #
#                                                                         #
# Outputs test v. train model performance for a classification model.     #
# Required packages: ggplot2                                              #
#                                                                         #
###########################################################################

# labeling improvement for trees
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

# model decile charts
CreateModelCharts <- function(model, roc_info_model,
                              Train_DF, Test_DF, Depvar,
                              model.name.text,
                              RegionVectorTrain, RegionVectorTest,
                              OverallEnrollmentRate, RegionalEnrollmentRate){
  
  # save local dataset
  plot.data.train <- Train_DF
  plot.data.test <- Test_DF
  
  # set DV as numeric for calculations
  plot.data.train$DepVar <- as.numeric(levels(plot.data.train$DepVar))[plot.data.train$DepVar]
  plot.data.test$DepVar <- as.numeric(levels(plot.data.test$DepVar))[plot.data.test$DepVar]
  
  # calculate deciles by region
  plot.data.train$Region <- RegionVectorTrain
  plot.data.test$Region <- RegionVectorTest
  plot.data.train <- plot.data.train %>% group_by(Region) %>% mutate(decile_region = ntile(-prediction, 10)) %>% ungroup()
  plot.data.test <- plot.data.test %>% group_by(Region) %>% mutate(decile_region = ntile(-prediction, 10)) %>% ungroup()
  
  # Plot data
  Test.Predicted <- plot.data.test %>% 
                    dplyr::group_by(decile_region) %>% 
                    summarise(Conversion_Rate = mean(ifelse(prediction>=roc_info$cutpoint,1,0)),
                              Conversions = sum(ifelse(prediction>=roc_info$optimal_cutpoint,1,0))) %>%
                    mutate(Value="Predicted-Test") 
  Test.Actual <<- plot.data.test %>% 
                  group_by(decile_region) %>% 
                  summarise(Conversion_Rate = mean(Depvar),
                            Conversions = sum(Depvar)) %>%
                  mutate(Value="Actual-Test")
  Train.Predicted <- plot.data.train %>% 
                     dplyr::group_by(decile_region) %>% 
                     summarise(Conversion_Rate = mean(ifelse(prediction>=roc_info$optimal_cutpoint,1,0)),
                               Conversions = sum(ifelse(prediction>=roc_info$optimal_cutpoint,1,0))) %>%
                     mutate(Value="Predicted-Train")  
  Train.Actual <<- plot.data.train %>% 
                   group_by(decile_region) %>% 
                   summarise(Conversion_Rate = mean(Depvar),
                             Conversions = sum(Depvar)) %>%
                   mutate(Value="Actual-Train")
  
  # Plot 1: Actual Enrollment Rate by Decile, Test vs. Train. Overall
  Plot1 <- rbind(Train.Actual,Test.Actual)
  p1 <- ggplot(data = Plot1, 
               aes(x = decile_region, y = Conversion_Rate, fill = Value)) +
               geom_bar(stat = "identity", position = position_dodge(1), alpha = 0.75) +
               geom_text(aes(label = sprintf("%1.2f%%", Conversion_Rate*100)), 
                         hjust = -0.1, size = 3.5, position = position_dodge(1),
                         angle = 90) +
               scale_x_continuous(breaks = c(1, 2, 3, 4, 5, 6, 7, 8, 9, 10)) +
               scale_y_continuous(limits = c(0,0.005), 
                                  labels = scales::percent_format(accuracy = 0.001)) +
               labs(x = "\n Decile", y = "Enrollment Rate\n", 
                    title = paste0(model.name.text,
                                   "\n Actual Enrollment Rate by Decile \n Train vs. Test")) +
               theme_minimal()
  
  # Plot 2: Actual vs. Predicted Enrollment Rate by Decile, Test only
  Plot2 <- rbind(Test.Actual,Test.Predicted) 
  p2 <- ggplot(data = Plot2, 
               aes(x = decile_region, y = Conversion_Rate, fill = Value)) +
               geom_bar(stat = "identity", position = position_dodge(1), alpha = 0.75) +
               geom_text(aes(label = sprintf("%1.2f%%", Conversion_Rate*100)), 
                         hjust = -0.1, size = 3.5, position = position_dodge(1),
                         angle = 90) +
               scale_x_continuous(breaks = c(1, 2, 3, 4, 5, 6, 7, 8, 9, 10))+
               scale_y_continuous(limits = c(0, 1.1), 
                                  labels = scales::percent_format(accuracy = 1)) +
               labs(x = "\n Decile", y = "Enrollment Rate\n", 
                    title = paste0(model.name.text,"\n Actual v. Predicted Enrollment Rate by Decile \n Test-only")) +
               theme_minimal()
  
  # Plot data: regional
  Train.Actual <- plot.data.train %>% 
                  group_by(decile_region,Region) %>% 
                  summarise(Conversion_Rate = mean(DepVar),
                            Conversions = sum(DepVar)) %>%
                  mutate(Value="Actual-Train") %>%
                  arrange(Region,decile_region) %>%
                  ungroup()
  Test.Actual <- plot.data.test %>% 
                 group_by(decile_region,Region) %>% 
                 summarise(Conversion_Rate = mean(DepVar),
                           Conversions = sum(DepVar)) %>%
                 mutate(Value="Actual-Test") %>%
                 arrange(Region,decile_region) %>%
                 ungroup()
  
  # Plot: regional
  Plot1.r <- rbind(Train.Actual,Test.Actual)
  p1.r <- ggplot(data = Plot1.r, 
                 aes(x = decile_region, y = Conversion_Rate, fill = Value)) +
                 geom_bar(stat = "identity", position = position_dodge(1), alpha = 0.75)+
                 #geom_text(aes(label = sprintf("%1.1f%%", Conversion_Rate*100)), 
                                #hjust = -0.1, size = 3, position = position_dodge(1), 
                 #angle = 90) +
                 scale_x_continuous(breaks=c(1, 2, 3, 4, 5, 6, 7, 8, 9, 10),
                                    expand = c(0, 1.2)) +
                 scale_y_continuous(limits = c(0, 0.005), 
                                    labels = scales::percent_format(accuracy = 0.001)) +
                 labs(x = "\n Decile", y = "Enrollment Rate\n", 
                      title = paste0(model.name.text,"\n Actual Enrollment Rate by Decile \n Train vs. Test \n By Region")) +
                 theme_minimal()
  
  return(list(p1 + 
                geom_hline(aes(yintercept = extract_numeric(OverallEnrollmentRate)/100), linetype = 2) +
                annotate("text", x = 9, y = 0.0002+(extract_numeric(OverallEnrollmentRate)/100), label = paste("Base Rate:",OverallEnrollmentRate)),
              p2 + 
                geom_hline(aes(yintercept = extract_numeric(OverallEnrollmentRate)/100), linetype = 2) +
                annotate("text", x = 9, y = 0.0002+(extract_numeric(OverallEnrollmentRate)/100), label = paste("Base Rate:",OverallEnrollmentRate)),
              p1.r + facet_wrap(~Region, ncol = 4) +
                geom_hline(data = EnrollmentRate.ByRegion, aes(yintercept = Conversion_Rate), linetype=2)))
  
}