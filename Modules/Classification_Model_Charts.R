###########################################################################
#                                                                         #
# Program Name: Classification_Model_Charts.R                             #
# Date Created: 8/15/2022                                                 #
# Created By: Elsa Haynes (elsa.c.haynes@kp.org)                          #
#                                                                         #
# Outputs test v. train model performance for a classification model.     #
# Required packages: ggplot2, readr, scales, wesanderson                  #
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
                              Train_DF, Test_DF, 
                              model.name.text,
                              RegionVectorTrain, RegionVectorTest,
                              lift){
  
  # save local dataset
  plot.data.train <- Train_DF
  plot.data.test <- Test_DF
  
  # set DV as numeric for calculations
  train.dv <- subset(plot.data.train, select=names(plot.data.train) %in% ListDV)
  test.dv <- subset(plot.data.test, select=names(plot.data.test) %in% ListDV)
  plot.data.train[ListDV] <- as.numeric(levels(train.dv[,1]))[train.dv[,1]]
  plot.data.test[ListDV] <- as.numeric(levels(test.dv[,1]))[test.dv[,1]]
  remove(train.dv)
  remove(test.dv)
  
  # calculate deciles by region
  plot.data.train$Region <- RegionVectorTrain
  plot.data.test$Region <- RegionVectorTest
  plot.data.train <- plot.data.train %>% group_by(Region) %>% mutate(decile_region = ntile(-prediction, 10)) %>% ungroup()
  plot.data.test <- plot.data.test %>% group_by(Region) %>% mutate(decile_region = ntile(-prediction, 10)) %>% ungroup()
  
  # Plot data
  cutpoint <- roc_info_model[[1]]$optimal_cutpoint
  Test.Predicted <- plot.data.test %>% 
                    dplyr::group_by(decile_region) %>% 
                    summarise(Conversion_Rate = mean(ifelse(prediction>=cutpoint,1,0)),
                              Conversions = sum(ifelse(prediction>=cutpoint,1,0))) %>%
                    mutate(Value="Predicted-Test") 
  Test.Actual <-  plot.data.test %>% 
                  group_by(decile_region) %>% 
                  summarise(Conversion_Rate = mean(!! sym(ListDV)),
                            Conversions = sum(!! sym(ListDV))) %>%
                  mutate(Value="Actual-Test")
  Train.Predicted <- plot.data.train %>% 
                     dplyr::group_by(decile_region) %>% 
                     summarise(Conversion_Rate = mean(ifelse(prediction>=cutpoint,1,0)),
                               Conversions = sum(ifelse(prediction>=cutpoint,1,0))) %>%
                     mutate(Value="Predicted-Train")  
  Train.Actual <- plot.data.train %>% 
                   group_by(decile_region) %>% 
                   summarise(Conversion_Rate = mean(!! sym(ListDV)),
                             Conversions = sum(!! sym(ListDV))) %>%
                   mutate(Value="Actual-Train")
  
  # Plot 1: Actual Enrollment Rate by Decile, Test vs. Train. Overall
  lim <- readr::parse_number(Average_Enrollment_Rate)/100*lift
  Plot1 <- rbind(Train.Actual,Test.Actual)
  p1 <- ggplot(data = Plot1, 
               aes(x = decile_region, y = Conversion_Rate, fill = Value)) +
               geom_bar(stat = "identity", position = position_dodge(1), alpha = 0.75) +
               geom_text(aes(label = sprintf("%1.2f%%", Conversion_Rate*100)), 
                         hjust = -0.1, size = 3.5, position = position_dodge(1),
                         angle = 90) +
               scale_x_continuous(breaks = c(1, 2, 3, 4, 5, 6, 7, 8, 9, 10)) +
               scale_y_continuous(limits = c(0,lim), 
                                  oob = rescale_none, 
                                  labels = scales::percent_format(accuracy = 0.1)) +
               labs(x = "\n Decile", y = "Enrollment Rate\n", 
                    title = paste0(model.name.text,
                                   "\nActual Enrollment Rate by Decile \nTrain vs. Test")) +
               theme_minimal()
  
  # Plot 2: Actual vs. Predicted Enrollment Rate by Decile, Test only
  Plot2 <- rbind(Test.Actual,Test.Predicted) 
  p2 <- ggplot(data = Plot2, 
               aes(x = decile_region, y = Conversion_Rate, fill = Value)) +
               geom_bar(stat = "identity", position = position_dodge(1), alpha = 0.75) +
               geom_text(aes(y=0, label = sprintf("%1.2f%%", Conversion_Rate*100)),
  
                         hjust = -0.1, size = 3.5, position = position_dodge(1),
                         angle = 90) +
               scale_x_continuous(breaks = c(1, 2, 3, 4, 5, 6, 7, 8, 9, 10))+
               scale_y_continuous(limits = c(0, lim), 
                                  oob = rescale_none, 
                                  labels = scales::percent_format(accuracy = 0.1)) +
               labs(x = "\n Decile", y = "Enrollment Rate\n", 
                    title = paste0(model.name.text,"\nActual v. Predicted Enrollment Rate by Decile \nTest-only")) +
               theme_minimal()
  
  # Plot data: regional
  Train.Actual <- plot.data.train %>% 
                  group_by(decile_region,Region) %>% 
                  summarise(Conversion_Rate = mean(!! sym(ListDV)),
                            Conversions = sum(!! sym(ListDV))) %>%
                  mutate(Value="Actual-Train") %>%
                  arrange(Region,decile_region) %>%
                  ungroup()
  Test.Actual <- plot.data.test %>% 
                 group_by(decile_region,Region) %>% 
                 summarise(Conversion_Rate = mean(!! sym(ListDV)),
                           Conversions = sum(!! sym(ListDV))) %>%
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
                 scale_y_continuous(limits = c(0, lim), 
                                    oob = rescale_none,
                                    labels = scales::percent_format(accuracy = 0.1)) +
                 labs(x = "\n Decile", y = "Enrollment Rate\n", 
                      title = paste0(model.name.text,"\nActual Enrollment Rate by Decile \nTrain vs. Test \nBy Region")) +
                 theme_minimal()
  
  # Average label
  AvgRateNum <- readr::parse_number(Average_Enrollment_Rate)/100
  AvgRateNumJitter <- AvgRateNum*1.5
  
  return(list(p1 + 
                geom_hline(aes(yintercept = AvgRateNum), linetype = 2) +
                annotate("text", x = 9, y = AvgRateNumJitter, label = paste("Base Rate:",Average_Enrollment_Rate)) +
                scale_fill_manual(values = wes_palette("Darjeeling1", 2, type = "discrete")), 
              #p2 + 
                #geom_hline(aes(yintercept = AvgRateNum), linetype = 2) +
                #annotate("text", x = 9, y = AvgRateNumJitter, label = paste("Base Rate:",Average_Enrollment_Rate)) +
                #scale_fill_manual(values = wes_palette("Darjeeling1", 2, type = "discrete")),
              p1.r + facet_wrap(~Region, ncol = 4) +
                geom_hline(data = Average_Enrollment_Rate.ByRegion, aes(yintercept = Conversion_Rate), linetype=2) +
                scale_fill_manual(values = wes_palette("Darjeeling1", 2, type = "discrete"))))
  
}

# model decile charts
CreateModelChartsRegion <- function(model, roc_info_model,
                              Train_DF, Test_DF, 
                              model.name.text,
                              RegionVectorTrain, RegionVectorTest,
                              lift,
                              AverageEnrollmentRate, AverageEnrollmentTable){
  
  # save local dataset
  plot.data.train <- Train_DF
  plot.data.test <- Test_DF
  
  # set DV as numeric for calculations
  train.dv <- subset(plot.data.train, select=names(plot.data.train) %in% ListDV)
  test.dv <- subset(plot.data.test, select=names(plot.data.test) %in% ListDV)
  plot.data.train[ListDV] <- as.numeric(levels(train.dv[,1]))[train.dv[,1]]
  plot.data.test[ListDV] <- as.numeric(levels(test.dv[,1]))[test.dv[,1]]
  remove(train.dv)
  remove(test.dv)
  
  # calculate deciles by region
  plot.data.train$Region <- RegionVectorTrain$Region
  plot.data.test$Region <- RegionVectorTest$Region
  plot.data.train <- plot.data.train %>% group_by(Region) %>% mutate(decile_region = ntile(-prediction, 10)) %>% ungroup()
  plot.data.test <- plot.data.test %>% group_by(Region) %>% mutate(decile_region = ntile(-prediction, 10)) %>% ungroup()
  
  # Plot data
  cutpoint <- roc_info_model[[1]]$optimal_cutpoint
  Test.Predicted <- plot.data.test %>% 
    dplyr::group_by(decile_region) %>% 
    summarise(Conversion_Rate = mean(ifelse(prediction>=cutpoint,1,0)),
              Conversions = sum(ifelse(prediction>=cutpoint,1,0))) %>%
    mutate(Value="Predicted-Test") 
  Test.Actual <-  plot.data.test %>% 
    group_by(decile_region) %>% 
    summarise(Conversion_Rate = mean(!! sym(ListDV)),
              Conversions = sum(!! sym(ListDV))) %>%
    mutate(Value="Actual-Test")
  Train.Predicted <- plot.data.train %>% 
    dplyr::group_by(decile_region) %>% 
    summarise(Conversion_Rate = mean(ifelse(prediction>=cutpoint,1,0)),
              Conversions = sum(ifelse(prediction>=cutpoint,1,0))) %>%
    mutate(Value="Predicted-Train")  
  Train.Actual <- plot.data.train %>% 
    group_by(decile_region) %>% 
    summarise(Conversion_Rate = mean(!! sym(ListDV)),
              Conversions = sum(!! sym(ListDV))) %>%
    mutate(Value="Actual-Train")
  
  # Plot 1: Actual Enrollment Rate by Decile, Test vs. Train. Overall
  lim <- readr::parse_number(AverageEnrollmentRate)/100*lift
  Plot1 <- rbind(Train.Actual,Test.Actual)
  p1 <- ggplot(data = Plot1, 
               aes(x = decile_region, y = Conversion_Rate, fill = Value)) +
    geom_bar(stat = "identity", position = position_dodge(1), alpha = 0.75) +
    geom_text(aes(label = sprintf("%1.2f%%", Conversion_Rate*100)), 
              hjust = -0.1, size = 3.5, position = position_dodge(1),
              angle = 90) +
    scale_x_continuous(breaks = c(1, 2, 3, 4, 5, 6, 7, 8, 9, 10)) +
    scale_y_continuous(limits = c(0,lim), 
                       oob = rescale_none, 
                       labels = scales::percent_format(accuracy = 0.1)) +
    labs(x = "\n Decile", y = "Enrollment Rate\n", 
         title = paste0(model.name.text,
                        "\nActual Enrollment Rate by Decile \nTrain vs. Test")) +
    theme_minimal()
  
  # Plot 2: Actual vs. Predicted Enrollment Rate by Decile, Test only
  Plot2 <- rbind(Test.Actual,Test.Predicted) 
  p2 <- ggplot(data = Plot2, 
               aes(x = decile_region, y = Conversion_Rate, fill = Value)) +
    geom_bar(stat = "identity", position = position_dodge(1), alpha = 0.75) +
    geom_text(aes(y=0, label = sprintf("%1.2f%%", Conversion_Rate*100)),
              
              hjust = -0.1, size = 3.5, position = position_dodge(1),
              angle = 90) +
    scale_x_continuous(breaks = c(1, 2, 3, 4, 5, 6, 7, 8, 9, 10))+
    scale_y_continuous(limits = c(0, lim), 
                       oob = rescale_none, 
                       labels = scales::percent_format(accuracy = 0.1)) +
    labs(x = "\n Decile", y = "Enrollment Rate\n", 
         title = paste0(model.name.text,"\nActual v. Predicted Enrollment Rate by Decile \nTest-only")) +
    theme_minimal()
  
  # Plot data: regional
  Train.Actual <- plot.data.train %>% 
    group_by(decile_region,Region) %>% 
    summarise(Conversion_Rate = mean(!! sym(ListDV)),
              Conversions = sum(!! sym(ListDV))) %>%
    mutate(Value="Actual-Train") %>%
    arrange(Region,decile_region) %>%
    ungroup()
  Test.Actual <- plot.data.test %>% 
    group_by(decile_region,Region) %>% 
    summarise(Conversion_Rate = mean(!! sym(ListDV)),
              Conversions = sum(!! sym(ListDV))) %>%
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
    scale_y_continuous(limits = c(0, lim), 
                       oob = rescale_none,
                       labels = scales::percent_format(accuracy = 0.1)) +
    labs(x = "\n Decile", y = "Enrollment Rate\n", 
         title = paste0(model.name.text,"\nActual Enrollment Rate by Decile \nTrain vs. Test \nBy Region")) +
    theme_minimal()
  
  # Average label
  AvgRateNum <- readr::parse_number(AverageEnrollmentRate)/100
  AvgRateNumJitter <- AvgRateNum*1.5
  
  return(list(p1 + 
                geom_hline(aes(yintercept = AvgRateNum), linetype = 2) +
                annotate("text", x = 9, y = AvgRateNum*1.2, label = paste("Base Rate:",AverageEnrollmentRate)) +
                scale_fill_manual(values = wes_palette("Darjeeling1", 2, type = "discrete")), 
              #p2 + 
              #geom_hline(aes(yintercept = AvgRateNum), linetype = 2) +
              #annotate("text", x = 9, y = AvgRateNumJitter, label = paste("Base Rate:",AverageEnrollmentRate)) +
              #scale_fill_manual(values = wes_palette("Darjeeling1", 2, type = "discrete")),
              p1.r + facet_wrap(~Region, ncol = 4) +
                geom_hline(data = AverageEnrollmentTable, aes(yintercept = Conversion_Rate), linetype=2) +
                scale_fill_manual(values = wes_palette("Darjeeling1", 2, type = "discrete"))))
  
}

