###########################################################################
#                                                                         #
# Program Name: Classification_Model_Variable_Selection.R                 #
# Date Created: 8/15/2022                                                 #
# Created By: Elsa Haynes (elsa.c.haynes@kp.org)                          #
#                                                                         #
# Outputs exclusion lists for classification models variables.            #
# Required packages: data.table, dplyr, janitor, stringr, Information,    #
#                    factoextra, randomForest, MASS, car, caret, corrr    #
#                                                                         #
###########################################################################

# Helper Functions

`%ni%` <- Negate(`%in%`)

# Imports CSVs with Agility IDs
import_csv <- function(csv_name){
  df <- fread(paste0(csv_name,'.csv'),
              colClasses=c(AGLTY_INDIV_ID="character")) 
}

# Calculates PCA
CalcPCA <- function(df){
  # only numeric.
  df <- df %>% mutate_if(is.character, as.factor)
  df <- df %>% mutate_if(is.factor, as.numeric)
  PCA <- prcomp(df, center = TRUE, scale = TRUE)
  return(PCA)
}

# Calculates RF Variable Importance
CalcRFImportance <- function(df, formula){
  RF <- randomForest(formula=formula, data=df, 
                     ntree=100, mtry=3, importance=TRUE)
  Importance <- as.data.frame(RF$importance) %>% 
    dplyr::select("MeanDecreaseAccuracy") %>% 
    arrange(desc(MeanDecreaseAccuracy))
  Importance$name <- rownames(Importance)
  return(Importance)
}

# Lists variables to exclude based on high collinearity and IV
CalcCorrExclList <- function(df, depvar, numeric_DF, cutoff){
  highlyCorrelated <- numeric_DF %>%
    correlate() %>% 
    stretch() %>% 
    arrange(r) %>%
    filter(abs(r)>cutoff) %>%
    as.data.frame()
  highlyCorrelated <- highlyCorrelated[c(TRUE,FALSE),]
  IV <- create_infotables(data=df, y=depvar, bins=10, parallel=FALSE)
  IV <- IV$Summary %>% as.data.frame()
  highlyCorrelated <- merge(highlyCorrelated, IV, by.x = "x", by.y = "Variable", 
                            all.x = TRUE) %>% rename(X_IV = IV)
  highlyCorrelated <- merge(highlyCorrelated, IV, by.x = "y", by.y = "Variable", 
                            all.x = TRUE) %>% rename(Y_IV = IV)
  highlyCorrelated$exclude_var <- ifelse(highlyCorrelated$X_IV >= 
                                           highlyCorrelated$Y_IV, 
                                         highlyCorrelated$x, 
                                         highlyCorrelated$y)
  List <- highlyCorrelated$exclude_var[!duplicated(highlyCorrelated$exclude_var)]
  return(List)
}

# Main Function (pt1): Outputs an RDS to WD with variables to exclude.
VariableSelection_Part1 <- function(csv_name, depvar_unquoted, depvar_quoted,
                                    list_cols_drop_RDSname, rf_formula){
  
  print("Initializing.")
  df = import_csv(csv_name)
  df <- subset(df,select = names(df) %ni% ListReportingCols) 
  # Prep to set var as factors
  df <- as.data.frame(df)
  ListFlags <- df %>% 
    dplyr::select(contains("_Flag", ignore.case = T)) %>%
    colnames()
  ListChar  <- df %>% select_if(is.character) %>% colnames()
  ListDV    <- df %>% dplyr::select(contains("Conv", ignore.case = T)) %>%
    colnames()
  ListFlags <- setdiff(ListFlags, ListDV)
  df[ListChar]  <- lapply(df[ListChar], as.factor)
  df_factor <- df
  df_factor[ListFlags] <- lapply(df_factor[ListFlags], as.factor)
  # Initialize lists
  ListAllCols <- colnames(df) # make sure not to introduce new cols later
  ListColsDrop <- c() # Initialize Var Exclusion Lists
  ListColsKeep <- c() # Initialize Var Keep Lists
  print("Initializing complete.")
  
  # %% WOE/IV
  # Exclude where IV < 0.02 (useless) or > 0.5 (suspicious)
  # Keep where IV between 0.3-0.5 (strong)
  print("Calculating IV.")
  IV <- create_infotables(data=df_factor, y=depvar_quoted, bins=10, parallel=FALSE)
  ExclusionList <- IV$Summary[,1][IV$Summary[,2] >= 0.5 | IV$Summary[,2] <= 0.02]
  ListColsDrop <- c(ListColsDrop, ExclusionList)
  KeepList <- IV$Summary[,1][IV$Summary[,2] > 0.3 & IV$Summary[,2] < 0.5]
  ListColsKeep <- c(ListColsKeep, KeepList)
  #remove(IV)
  remove(ExclusionList)
  remove(KeepList)
  print("Calculating IV complete.")
  
  # %% Random Forest Variable Importance
  
  print("Calculating RF Variable Importance.")
  df_factor_dv <- df_factor
  df_factor_dv[ListDV] <- lapply(df_factor_dv[ListDV], as.factor)
  # Create random variables for benchmarking
  df_factor_dv$random_num <- sample(-1:1, size = nrow(df_factor_dv), replace = T)
  df_factor_dv$random_catg <- sample(LETTERS[1:4], nrow(df_factor_dv), replace = T, 
                                     prob=c(0.15, 0.2, 0.4, 0.25))
  Importance <- CalcRFImportance(df_factor_dv, rf_formula) 
  threshold <- Importance %>% 
    filter(Importance$name == "random_num" | Importance$name == "random_catg")
  threshold <- max(threshold$MeanDecreaseAccuracy) #remove var worse than random vars
  ExclusionList <- Importance %>% 
    filter(MeanDecreaseAccuracy < threshold) %>% 
    rownames()
  KeepList <- Importance %>% 
    slice_max(MeanDecreaseAccuracy, n=10) %>% 
    rownames()
  ListColsDrop <- c(ListColsDrop, ExclusionList)
  ListColsKeep <- c(ListColsKeep, KeepList)
  remove(Importance)
  remove(threshold)
  remove(ExclusionList)
  remove(KeepList)
  print("Calculating RF Variable Importance complete.")
  
  # %% PCA
  print("Calculating PCA.")
  PCAOut <- CalcPCA(df_factor_dv)
  fviz_eig(PCAOut)
  res.var <- get_pca_var(PCAOut)
  # Keep 5 most important vars from each dimension up to cap
  ListColsKeep <- c(ListColsKeep,row.names(as.data.frame(sort(round(res.var$contrib[,1],3),decreasing=T)))[1:5])
  ListColsKeep <- c(ListColsKeep,row.names(as.data.frame(sort(round(res.var$contrib[,2],3),decreasing=T)))[1:5])
  ListColsKeep <- c(ListColsKeep,row.names(as.data.frame(sort(round(res.var$contrib[,3],3),decreasing=T)))[1:5])
  ListColsKeep <- c(ListColsKeep,row.names(as.data.frame(sort(round(res.var$contrib[,4],3),decreasing=T)))[1:5])
  ListColsKeep <- c(ListColsKeep,row.names(as.data.frame(sort(round(res.var$contrib[,5],3),decreasing=T)))[1:5])
  # Remove least important var by compiling last 50 var from all dimensions and de-duping
  CompileRemove <- c()
  CompileRemove <- c(CompileRemove,row.names(as.data.frame(sort(round(res.var$contrib[,1],3),decreasing=F)))[1:50])
  CompileRemove <- c(CompileRemove,row.names(as.data.frame(sort(round(res.var$contrib[,2],3),decreasing=F)))[1:50])
  CompileRemove <- c(CompileRemove,row.names(as.data.frame(sort(round(res.var$contrib[,3],3),decreasing=F)))[1:50])
  CompileRemove <- c(CompileRemove,row.names(as.data.frame(sort(round(res.var$contrib[,4],3),decreasing=F)))[1:50])
  CompileRemove <- c(CompileRemove,row.names(as.data.frame(sort(round(res.var$contrib[,5],3),decreasing=F)))[1:50])
  CompileKeep <- c()
  CompileKeep <- c(CompileKeep,row.names(as.data.frame(sort(round(res.var$contrib[,1],3),decreasing=T)))[1:50])
  CompileKeep <- c(CompileKeep,row.names(as.data.frame(sort(round(res.var$contrib[,2],3),decreasing=T)))[1:50])
  CompileKeep <- c(CompileKeep,row.names(as.data.frame(sort(round(res.var$contrib[,3],3),decreasing=T)))[1:50])
  CompileKeep <- c(CompileKeep,row.names(as.data.frame(sort(round(res.var$contrib[,4],3),decreasing=T)))[1:50])
  CompileKeep <- c(CompileKeep,row.names(as.data.frame(sort(round(res.var$contrib[,5],3),decreasing=T)))[1:50])
  CompileRemove <- setdiff(CompileRemove[!duplicated(CompileRemove)], CompileKeep)
  ListColsDrop <- c(ListColsDrop, CompileRemove)
  remove(PCAOut)
  remove(res.var)
  remove(CompileRemove)
  remove(CompileKeep)
  print("Calculating PCA complete.")
  
  # %% Finalize Exclusion List: Remove from exclusion lists where in keep lists
  
  print("Saving.")
  ListColsDrop <- setdiff(ListColsDrop[!duplicated(ListColsDrop)], ListColsKeep)
  # Also keep conversion variables
  ListConvVar <- c(depvar_quoted)
  ListColsDrop <- setdiff(ListColsDrop, ListConvVar)
  # Save
  saveRDS(ListColsDrop, file = list_cols_drop_RDSname)
  # Update df
  df <- subset(df,select = names(df) %ni% ListColsDrop)
  print("Saving Complete.")
  
  # %% Test for multi-collinearity among all remaining variables
  
  # Correlation
  # Drop highly correlated (>0.6) variables, keeping the one with higher IV
  print("Calculating correlations.")
  num <- df %>% dplyr::select(where(is.numeric))
  num <- num[ , !(names(num) %in% ListDV)]
  ExclusionList <- CalcCorrExclList(df, depvar_quoted, num, 0.6)
  ListColsDrop <- c(ListColsDrop, ExclusionList)
  remove(num)
  remove(ExclusionList)
  print("Calculating correlations complete.")
  
  # Update df and return list to exclude
  df_factor_dv <- subset(df_factor_dv,select = names(df_factor_dv) %ni% ListColsDrop)
  return(df_factor_dv)
  print("Variable Selection Part 1 Finished.")
  
}

# Main Function (pt2): Outputs an RDS to WD with variables to exclude.
VariableSelection_Part2 <- function(df, depvar_unquoted, depvar_quoted,
                                    list_cols_drop_RDSname, exclusion_list,
                                    formula){
  print("Loading Exclusion List.")
  ListColsDrop <- readRDS(list_cols_drop_RDSname)
  ListColsDrop <- c(ListColsDrop, exclusion_list)
  saveRDS(ListColsDrop, file = list_cols_drop_RDSname)
  print("Exclusion List updated.")
  
  # VIF
  # Exclude where VIF > 8 (high multi-collinearity)
  print("Calculating VIF.")
  vifDF <- subset(df,select = names(df) %ni% ListColsDrop)
  Log <- glm(formula, data = vifDF, family = "binomial")
  VIF <- vif(Log) %>% as.data.frame
  ExclusionList <- rownames(VIF[(VIF$`GVIF^(1/(2*Df))`)^2 > 8,])
  ListColsDrop <- c(ListColsDrop, ExclusionList)
  remove(vifDF)
  remove(Log)
  remove(VIF)
  remove(ExclusionList)
  print("Calculating VIF complete.")
  
  # Update Exclusion list
  # Also keep conversion variables
  ListColsDrop <- setdiff(ListColsDrop, depvar_quoted)
  finalcols <- subset(df,select = names(df) %ni% ListColsDrop) %>% colnames()
  saveRDS(ListColsDrop, file = list_cols_drop_RDSname)
  print("Variable Selection Part 2 Finished./n")
  return(finalcols)
  
}