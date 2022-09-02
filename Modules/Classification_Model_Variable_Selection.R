###########################################################################
#                                                                         #
# Program Name: Classification_Model_Variable_Selection.R                 #
# Date Created: 8/15/2022                                                 #
# Created By: Elsa Haynes (elsa.c.haynes@kp.org)                          #
#                                                                         #
# Outputs exclusion lists for classification models variables.            #
# Required packages: data.table, dplyr, janitor, stringr, Information,    #
#                    factoextra, MASS, car, caret, corrr, doParallel      #
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
  df  <- df %>% mutate_if(is.character, as.factor)
  df  <- df %>% mutate_if(is.factor, as.numeric)
  PCA <- prcomp(df, center = TRUE, scale = TRUE)
  return(PCA)
}

# Calculates RF Variable Importance
CalcRFImportance <- function(df, formula){
  start.time   <- proc.time()
  print(Sys.time())
  print('Running RF...')
  RF           <- randomForest(formula = formula, data = df, 
                               ntree = 300, importance = TRUE, mtry=2)
  stop.time    <- proc.time()
  run.time     <- stop.time-start.time
  print('Completed RF.')
  print(run.time[3]/60)
  Imp          <- as.data.frame(RF$importance) %>% 
                  dplyr::select("MeanDecreaseAccuracy") %>% 
                  arrange(desc(MeanDecreaseAccuracy))
  Imp$name     <- rownames(Imp)
  return(Imp)
}

# Lists variables to exclude based on high collinearity and IV
CalcCorrExclList <- function(df, ListDV, numeric_DF, cutoff){
  highlyCorrl   <- numeric_DF %>%
                   correlate() %>% 
                   stretch() %>% 
                   arrange(r) %>%
                   filter(abs(r)>cutoff) %>%
                   as.data.frame()
  highlyCorrl   <- highlyCorrl[c(TRUE,FALSE),]
  print(paste0("Number correlated pairs: ", nrow(highlyCorrl)))
  IV           <- create_infotables(data=df, y=ListDV, bins=10, parallel=FALSE)
  IV            <- IV$Summary %>% as.data.frame()
  CompileRemove <- c()
  while(nrow(highlyCorrl)>1){
    print("Running loop...")
    highlyCorrl      <- merge(highlyCorrl, IV, by.x = "x", by.y = "Variable", 
                              all.x = TRUE) %>% rename(X_IV = IV)
    highlyCorrl      <- merge(highlyCorrl, IV, by.x = "y", by.y = "Variable", 
                              all.x = TRUE) %>% rename(Y_IV = IV)
    highlyCorrl$excl <- ifelse(highlyCorrl$X_IV >= highlyCorrl$Y_IV, 
                               highlyCorrl$y, 
                               highlyCorrl$x)
    highlyCorrl$keep <- ifelse(highlyCorrl$X_IV >= highlyCorrl$Y_IV, 
                               highlyCorrl$x, 
                               highlyCorrl$y)
    List             <- setdiff(highlyCorrl$excl[!duplicated(highlyCorrl$excl)],
                           highlyCorrl$keep)
    CompileRemove    <- c(CompileRemove, List)
    # Re-set
    numeric_DF       <- numeric_DF[ , !(names(numeric_DF) %in% CompileRemove)]
    highlyCorrl      <- numeric_DF %>%
                        correlate() %>% 
                        stretch() %>% 
                        arrange(r) %>%
                        filter(abs(r)>cutoff) %>%
                        as.data.frame()
    highlyCorrl      <- highlyCorrl[c(TRUE,FALSE),]
    print(paste0("Number correlated pairs remaining: ", nrow(highlyCorrl)))
  }
  print("Running last time...")
  highlyCorrl      <- merge(highlyCorrl, IV, by.x = "x", by.y = "Variable", 
                            all.x = TRUE) %>% rename(X_IV = IV)
  highlyCorrl      <- merge(highlyCorrl, IV, by.x = "y", by.y = "Variable", 
                            all.x = TRUE) %>% rename(Y_IV = IV)
  highlyCorrl$excl <- ifelse(highlyCorrl$X_IV >= highlyCorrl$Y_IV, 
                             highlyCorrl$y, 
                             highlyCorrl$x)
  highlyCorrl$keep <- ifelse(highlyCorrl$X_IV >= highlyCorrl$Y_IV, 
                             highlyCorrl$x, 
                             highlyCorrl$y)
  List             <- setdiff(highlyCorrl$excl[!duplicated(highlyCorrl$excl)],
                              highlyCorrl$keep)
  CompileRemove    <- c(CompileRemove, List)
  print("Variables removed:")
  print(CompileRemove)
  return(CompileRemove)
}

# Remove vars in exclusion list
JoinRemoveVars <- function(df, joinTable, ExclusionList){
  df <- setDF(setDT(joinTable)[setDT(df),on=.(AGLTY_INDIV_ID,OE_Season)])
  df <- subset(df,select = names(df) %ni% ExclusionList)
}

# Main Function (pt1): Outputs an RDS to WD with variables to exclude.
VariableSelection_Part1 <- function(csv_name, list_cols_drop_RDSname, formula){
  
  print("Initializing.")
  df            <- import_csv(csv_name) 
  df            <- subset(df,select = names(df) %ni% ListReportingCols) 
  # Prep to set var as factors
  df            <- as.data.frame(df)
  ListFlags     <- df %>% 
                   dplyr::select(contains("_Flag", ignore.case = T)) %>%
                   colnames()
  ListChar      <- df %>% select_if(is.character) %>% colnames()
  ListDV        <- df %>% dplyr::select(contains("Conv", ignore.case = T)) %>%
                   colnames()
  ListFlags     <- setdiff(ListFlags, ListDV)
  df[ListChar]  <- lapply(df[ListChar], as.factor)
  # Initialize lists
  ListAllCols   <- colnames(df) 
  ListColsDrop  <- c()
  ListColsKeep  <- c()
  print("Initializing complete.")
  
  # %% WOE/IV
  # Exclude where IV < 0.02 (useless) or > 0.5 (suspicious)
  # Modified to exclude where IV < 0.1
  # Keep where IV between 0.3-0.5 (strong)
  print("Calculating IV.")
  df_factor            <- df
  df_factor[ListFlags] <- lapply(df_factor[ListFlags], as.factor)
  IV                   <- create_infotables(data = df_factor, y=ListDV, 
                                            bins=10, parallel=FALSE)
  ExclusionList        <- IV$Summary[,1][IV$Summary[,2] >= 0.5 | IV$Summary[,2] <= 0.1]
  ListColsDrop         <- c(ListColsDrop, ExclusionList)
  KeepList             <- IV$Summary[,1][IV$Summary[,2] >= 0.3 & IV$Summary[,2] < 0.5]
  ListColsKeep         <- c(ListColsKeep, KeepList)
  remove(ExclusionList)
  remove(KeepList)
  print("Calculating IV complete.")
  
  # %% Random Forest Variable Importance
  print("Calculating RF Variable Importance.")
  df_factor_dv         <- df_factor
  df_factor_dv[ListDV] <- lapply(df_factor_dv[ListDV], as.factor)
  remove(df_factor)
  # Create random variables for benchmarking
  df_factor_dv$rand_num <- sample(-1:1, size = nrow(df_factor_dv), replace = T)
  df_factor_dv$rand_cat <- sample(LETTERS[1:4], nrow(df_factor_dv), replace = T, 
                                     prob=c(0.15, 0.2, 0.4, 0.25))
  RowLim               <- nrow(df_factor_dv)*0.25
  sampled              <- df_factor_dv[sample(nrow(df_factor_dv),RowLim),]
  Importance           <- CalcRFImportance(sampled, formula) 
  #remove var less important than random vars
  threshold            <- Importance %>% 
                          filter(Importance$name == "rand_num" | Importance$name == "rand_cat")
  threshold            <- max(threshold$MeanDecreaseAccuracy) 
  ExclusionList        <- Importance %>% 
                          filter(MeanDecreaseAccuracy < threshold) %>% 
                          rownames()
  KeepList             <- Importance %>% 
                          slice_max(MeanDecreaseAccuracy, n=15) %>% 
                          rownames()
  ListColsDrop         <- c(ListColsDrop, ExclusionList)
  ListColsKeep         <- c(ListColsKeep, KeepList)
  remove(Importance)
  remove(threshold)
  remove(ExclusionList)
  remove(KeepList)
  remove(sampled)
  print("Calculating RF Variable Importance complete.")
  
  # %% PCA
  print("Calculating PCA.")
  PCAOut        <- CalcPCA(df_factor_dv)
  #fviz_eig(PCAOut)
  res.var       <- get_pca_var(PCAOut)
  # Keep 5 most important vars from each dimension up to cap
  ListColsKeep  <- c(ListColsKeep,row.names(as.data.frame(sort(round(res.var$contrib[,1],3),decreasing=T)))[1:5])
  ListColsKeep  <- c(ListColsKeep,row.names(as.data.frame(sort(round(res.var$contrib[,2],3),decreasing=T)))[1:5])
  ListColsKeep  <- c(ListColsKeep,row.names(as.data.frame(sort(round(res.var$contrib[,3],3),decreasing=T)))[1:5])
  ListColsKeep  <- c(ListColsKeep,row.names(as.data.frame(sort(round(res.var$contrib[,4],3),decreasing=T)))[1:5])
  ListColsKeep  <- c(ListColsKeep,row.names(as.data.frame(sort(round(res.var$contrib[,5],3),decreasing=T)))[1:5])
  ListColsKeep <- ListColsKeep[!duplicated(ListColsKeep)]
  # Remove least important var by compiling last 30 var from all dimensions and de-duping
  CompileRemove <- c()
  CompileRemove <- c(CompileRemove,row.names(as.data.frame(sort(round(res.var$contrib[,1],3),decreasing=F)))[1:30])
  CompileRemove <- c(CompileRemove,row.names(as.data.frame(sort(round(res.var$contrib[,2],3),decreasing=F)))[1:30])
  CompileRemove <- c(CompileRemove,row.names(as.data.frame(sort(round(res.var$contrib[,3],3),decreasing=F)))[1:30])
  CompileRemove <- c(CompileRemove,row.names(as.data.frame(sort(round(res.var$contrib[,4],3),decreasing=F)))[1:30])
  CompileRemove <- c(CompileRemove,row.names(as.data.frame(sort(round(res.var$contrib[,5],3),decreasing=F)))[1:30])
  CompileKeep   <- c()
  CompileKeep   <- c(CompileKeep,row.names(as.data.frame(sort(round(res.var$contrib[,1],3),decreasing=T)))[1:30])
  CompileKeep   <- c(CompileKeep,row.names(as.data.frame(sort(round(res.var$contrib[,2],3),decreasing=T)))[1:30])
  CompileKeep   <- c(CompileKeep,row.names(as.data.frame(sort(round(res.var$contrib[,3],3),decreasing=T)))[1:30])
  CompileKeep   <- c(CompileKeep,row.names(as.data.frame(sort(round(res.var$contrib[,4],3),decreasing=T)))[1:30])
  CompileKeep   <- c(CompileKeep,row.names(as.data.frame(sort(round(res.var$contrib[,5],3),decreasing=T)))[1:30])
  CompileRemove <- setdiff(CompileRemove[!duplicated(CompileRemove)], CompileKeep)
  ListColsDrop  <- c(ListColsDrop, CompileRemove)
  remove(PCAOut)
  remove(res.var)
  remove(CompileRemove)
  remove(CompileKeep)
  print("Calculating PCA complete.")
  
  # %% Finalize Exclusion List: Remove from exclusion lists where in keep lists
  print("Saving.")
  ListColsDrop <- setdiff(ListColsDrop[!duplicated(ListColsDrop)], ListColsKeep)
  # Also keep conversion variables
  ListColsDrop <- setdiff(ListColsDrop, ListDV)
  # Save
  saveRDS(ListColsDrop, file = list_cols_drop_RDSname)
  # Update df
  df           <- subset(df,select = names(df) %ni% ListColsDrop)
  print("Saving Complete.")
  
  # %% Test for multi-collinearity among all remaining variables
  # Correlation
  # Drop highly correlated (>0.6) variables, keeping the one with higher IV
  print("Calculating correlations.")
  num           <- df %>% dplyr::select(where(is.numeric))
  num           <- num[ , !(names(num) %in% ListDV)]
  ExclusionList <- CalcCorrExclList(df, ListDV, num, 0.6)
  ListColsDrop  <- c(ListColsDrop, ExclusionList)
  remove(num)
  remove(ExclusionList)
  print("Calculating correlations complete.")
  
  print("Saving.")
  # Also keep conversion variables
  ListColsDrop <- setdiff(ListColsDrop, ListDV)
  # Save
  saveRDS(ListColsDrop, file = list_cols_drop_RDSname)
  # Update df and return list to exclude
  df_factor_dv  <- subset(df_factor_dv,select = names(df_factor_dv) %ni% ListColsDrop)
  return(df_factor_dv)
  print("Variable Selection Part 1 Finished.")
  
}

# Main Function (pt2): Outputs an RDS to WD with variables to exclude.
VariableSelection_Part2 <- function(df, list_cols_drop_RDSname, exclusion_list,
                                    formula){
  print("Loading Exclusion List.")
  ListColsDrop <- readRDS(list_cols_drop_RDSname)
  ListColsDrop <- c(ListColsDrop, exclusion_list)
  saveRDS(ListColsDrop, file = list_cols_drop_RDSname)
  print("Exclusion List updated.")
  
  # VIF
  # Exclude where VIF > 8 (high multi-collinearity)
  print("Calculating VIF.")
  vifDF         <- subset(df,select = names(df) %ni% ListColsDrop)
  Log           <- glm(formula, data = vifDF, family = "binomial")
  VIF           <- vif(Log) %>% as.data.frame
  ExclusionList <- rownames(VIF[(VIF$`GVIF^(1/(2*Df))`)^2 >= 8,])
  ListColsDrop  <- c(ListColsDrop, ExclusionList)
  ExclusionList <- rownames(VIF[VIF$GVIF >= 8,])
  print('Excluded by VIF:')
  print(ExclusionList)
  ListColsDrop  <- c(ListColsDrop, ExclusionList)
  remove(vifDF)
  remove(Log)
  remove(VIF)
  remove(ExclusionList)
  print("Calculating VIF complete.")
  
  # Update Exclusion list
  # Also keep conversion variables
  ListDV        <- df %>% dplyr::select(contains("Conv", ignore.case = T)) %>%
    colnames()
  ListColsDrop  <- setdiff(ListColsDrop, ListDV)
  finalcols     <- subset(df, select = names(df) %ni% ListColsDrop) %>% colnames()
  saveRDS(ListColsDrop, file = list_cols_drop_RDSname)
  print("Variable Selection Part 2 Finished./n")
  return(finalcols)
  
}

# Export and update final datasets
SaveFiles <- function(audience.condition, 
                      list_cols_drop_RDSname.off, list_cols_drop_RDSname.on,
                      final.csvname.offhix, final.csvname.onhix){
  
  # Import exclusion lists
  print("Loading Exclusion Lists.")
  ListColsDrop_Off <- readRDS(list_cols_drop_RDSname.off)
  ListColsDrop_On  <- readRDS(list_cols_drop_RDSname.on)
  print("Loading Exclusion Lists Complete.")
  
  # Step 1: Segment
  print(paste0("Segmenting to where Audience_CY==",audience.condition,"."))
  treatment        <- import_csv('T9_Rollup_Treatment')  # 7,246,772 rows
  df               <- treatment[treatment$Audience_CY == audience.condition,]
  df               <- df %>% dplyr::select(-V1,-Audience_CY)
  remove(treatment)
  print("Segmenting Complete.")
  
  # Step 2: Join conversion
  print("Joining Conversion.")
  conversion       <- import_csv('T10_Rollup_Conversion')  # 7,246,772 rows
  df               <- setDF(setDT(conversion)[setDT(df), on=.(AGLTY_INDIV_ID, OE_Season)])
  df               <- df %>% dplyr::select(-V1)
  remove(conversion)
  print("Joining Conversion Complete.")
  
  # Step 3: Segment into On/Off
  print("Segmenting to On- and Off-HIX.")
  OffHIX           <- df %>% dplyr::select(-Conv_Resp_InboundCall,-Conv_Enroll_OnHIX_Flag)
  OnHIX            <- df %>% dplyr::select(-Conv_Resp_InboundCall,-Conv_Enroll_OffHIX_Flag)
  remove(df)
  print("Segmenting to On- and Off-HIX Complete.")
  
  # Step 4: Join tapestry and remove vars
  print("Joining to Tapestry")
  tapestry         <- import_csv('T11_Rollup_Tapestry')  # 7,246,772 rows
  tapestry         <- tapestry %>% dplyr::select(-V1, -Region)
  OffHIX           <- JoinRemoveVars(OffHIX, tapestry, ListColsDrop_Off)
  OnHIX            <- JoinRemoveVars(OnHIX, tapestry, ListColsDrop_On)
  remove(tapestry)
  print("Joining to Tapestry Complete.")
  
  # Step 5: Join demographics and remove vars
  print("Joining to Demographics.")
  demog            <- import_csv('T13_Rollup_Demog')  # 7,246,772 rows
  demog            <- demog %>% dplyr::select(-V1)
  OffHIX           <- JoinRemoveVars(OffHIX, demog, ListColsDrop_Off)
  OnHIX            <- JoinRemoveVars(OnHIX, demog, ListColsDrop_On)
  remove(demog)
  gc()
  print("Joining to Demographics Complete.")
  
  # Step 6: Join external data and remove vars
  print("Joining to External Data.")
  external         <- import_csv('T12_Rollup_External')  # 7,246,772 rows
  external         <- external %>% dplyr::select(-V1)
  OffHIX           <- JoinRemoveVars(OffHIX, external, ListColsDrop_Off)
  OnHIX            <- JoinRemoveVars(OnHIX, external, ListColsDrop_On)
  remove(external)
  print("Joining to External Data Complete.")
  
  # Step 6: Save
  print("Checking if OK to save: Off-HIX.")
  remove           <- names(which(colSums(is.na(OffHIX))>0))
  print("Columns with missing data Off-HIX will be removed:")
  print(remove)
  OffHIX           <- subset(OffHIX,select = names(OffHIX) %ni% remove)
  print("Column names for Off-HIX data")
  print(colnames(OffHIX))
  data.table::fwrite(OffHIX,file=final.csvname.offhix) 
  remove(OffHIX)
  gc()
  print("Saved Off-HIX.")
  
  print("Checking if OK to save: On-HIX.")
  remove           <- names(which(colSums(is.na(OnHIX))>0))
  print("Columns with missing data On-HIX. will be removed:")
  print(remove)
  OnHIX            <- subset(OnHIX,select = names(OnHIX) %ni% remove)
  print("Column names for On-HIX data")
  print(colnames(OnHIX))
  data.table::fwrite(OnHIX,file=final.csvname.onhix) 
  remove(OnHIX)
  gc()
  print("Saved On-HIX.")

}