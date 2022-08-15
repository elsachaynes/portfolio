# -*- coding: utf-8 -*-
"""
------------------------------------------------------------------------------
Program Name: Prog_1_Transform_And_Clean_Impute.py
Date Created: 8/2/2022
Created By: Elsa Haynes (elsa.c.haynes@kp.org)

Imputes missing data for all model datasets and outputs cleaned datafiles.
Also exports descriptive stats for all variables before and after imputation.

------------------------------------------------------------------------------
"""

# %% Initialize Libraries and Paths

import pandas as pd
import numpy as np
import os.path
from openpyxl import load_workbook

inputpath = (r'\\cs.msds.kp.org\kpctinas1\NC\CSDT_SAS_Grid\ndc_grid'
             r'\po_imca_digital\EHaynes\__Models\KPIF_EmailTargeting_2022')

outputpath = (r'\\cs.msds.kp.org\scal\REGS\share15\KPIF_ANALYTICS\Elsa'
              r'\KPIF_ Targeting Model 2023 OE')

localdisk = (r'C:\Users\c156934')

# %% Import CSV files


def import_csv(csv_name):
    global inputpath
    df = pd.read_csv(inputpath + csv_name + '.csv',
                     dtype={'AGLTY_INDIV_ID': object})
    return(df)


raw_treatment = import_csv(r'\T9_Rollup_Treatment')  # 7,246,772 rows
raw_convert = import_csv(r'\T10_Rollup_Conversion')  # 7,246,772 rows
raw_external = import_csv(r'\T12_Rollup_External')  # 7,246,772 rows
raw_demog = import_csv(r'\T13_Rollup_Demog')  # 7,246,772 rows
raw_tapestry = import_csv(r'\T11_Rollup_Tapestry')  # 7,246,772 rows

# %% Inspect Data Types and Correct

"""
Best practice: variables that should not be treated as a number are not stored
               as a numeric data type and this is verified in an earlier data
               cleaning step. By the time the data reaches this program the
               default import types should be sufficient.
"""

raw_treatment.info()
raw_convert.info()
raw_tapestry.info()
raw_external.info()
raw_demog.info()

# %% Append region (in raw_demog) onto all datasets for use in imputation

raw_treatment = pd.merge(raw_treatment,
                         raw_demog[['AGLTY_INDIV_ID', 'OE_Season', 'Region']],
                         how="left", on=['AGLTY_INDIV_ID', 'OE_Season'])
raw_convert = pd.merge(raw_convert,
                       raw_demog[['AGLTY_INDIV_ID', 'OE_Season', 'Region']],
                       how="left", on=['AGLTY_INDIV_ID', 'OE_Season'])
raw_external = pd.merge(raw_external,
                        raw_demog[['AGLTY_INDIV_ID', 'OE_Season', 'Region']],
                        how="left", on=['AGLTY_INDIV_ID', 'OE_Season'])
raw_tapestry = pd.merge(raw_tapestry,
                        raw_demog[['AGLTY_INDIV_ID', 'OE_Season', 'Region']],
                        how="left", on=['AGLTY_INDIV_ID', 'OE_Season'])

# %% Impute var with missing values


def impute_missing(df, name):
    global outputpath

    # List missing
    nmiss = df.isnull().sum().to_frame()
    nmiss = nmiss.loc[nmiss[0] > 0]
    nmiss = nmiss.index.to_list()

    # List descriptive stats for numeric and char var
    n = df.shape[0]
    stats = df.describe(include='all').transpose()
    stats['nmiss'] = df.isnull().sum().to_frame()
    stats['pctmiss'] = stats['nmiss']/n

    if len(nmiss) > 0:

        # Create distinction between Pre/Post imputation
        stats = stats.add_suffix('_PRE')

        # Split out var to impute by datatype
        list_cols_all = list(df.columns.values)
        list_cols_num = list(df.select_dtypes(include=['int64', 'float64'])
                             .columns.values)
        list_cols_str = [x for x in list_cols_all if x not in list_cols_num]
        list_cols_flag = []
        flag_types = ['_FLAG', '_Flag', '_flag']
        for i in flag_types:
            for j in list_cols_num:
                if(j.find(i) != -1 and j not in list_cols_flag):
                    list_cols_flag.append(j)
        list_cols_num = [x for x in list_cols_num if x not in list_cols_flag]
        list_cols_num = [x for x in nmiss if x in list_cols_num]
        list_cols_str = [x for x in nmiss if x in list_cols_str]
        list_cols_flag = [x for x in nmiss if x in list_cols_flag]

        # If the % missing is > 20% then do not impute numeric var, bin instead
        # Note: for KPIF models, KBM is missing for 60.24% of records
        """
        list_cols_miss = stats.loc[stats['pctmiss_PRE'] > 0.2].index.to_list()
        list_cols_miss = [x for x in list_cols_miss if x in list_cols_num]
        list_cols_num = [x for x in list_cols_num if x not in list_cols_miss]
        stats['Bin_Flag'] = np.where(stats.index.isin(list_cols_miss), 1, 0)
        """
        # Impute
        for column in list_cols_num:  # Impute float by median
            df[column] = df[column]\
                        .fillna(df.groupby(['OE_Season', 'Region'])[column]
                                .transform('median'))
        for column in list_cols_flag:  # Impute dummy w/ 0
            df[column] = df[column].fillna(0)
        for column in list_cols_str:  # Impute categorical with 'U' for Unknown
            df[column] = df[column].fillna('U')
        """
        NOTE: Need to dynamically update labels if edges are the same
        for column in list_cols_miss:  # Impute float with >20% missing as bins
            bin_labels = []
            bin_labels.append('(' + str(round(df.column.min()))
                              + ' - ' + str(round(df.column.quantile(0.25)))
                              + ']')
            bin_labels.append('(' + str(round(df.column.quantile(0.25)))
                              + ' - ' + str(round(df.column.quantile(0.5)))
                              + ']')
            bin_labels.append('(' + str(round(df.column.quantile(0.5)))
                              + ' - ' + str(round(df.column.quantile(0.75)))
                              + ']')
            bin_labels.append('(' + str(round(df.column.quantile(0.75)))
                              + ' - ' + str(round(df.column.max()))
                              + ']')
            df[column] = pd.qcut(df[column], 4, precision=0, duplicates='drop',
                                 labels=bin_labels)
            df[column] = np.where(df[column].isna(),'U', df[column])
        """
        # After imputing: List descriptive stats for numeric and char var
        stats_after = df.describe(include='all').transpose()
        stats_after['nmiss'] = df.isnull().sum().to_frame()
        stats_after = stats_after.add_suffix('_POST')
        stats = pd.concat([stats, stats_after], axis=1, join="inner")
        # Still missing values! Completely missing for that region/period
        list_nmiss_after = stats[stats['nmiss_POST'] > 0].index.to_list()
        stats['Removed_Flag'] = np.where(stats.index.isin(list_nmiss_after),
                                         1, 0)
        df.drop(list_nmiss_after, axis=1)  # Remove these var

    # Save to Excel
    excel_path = outputpath + '\Initial_Tabulations.xlsx'
    if os.path.exists(excel_path):
        book = load_workbook(excel_path)
        writer = pd.ExcelWriter(excel_path, engine='openpyxl')
        writer.book = book
        writer.sheets = dict((ws.title, ws) for ws in book.worksheets)
        stats.to_excel(writer, sheet_name=name)
        writer.save()
        writer.close()
        # if new
    else:
        stats.to_excel(excel_path, sheet_name=name)

    # Return
    return nmiss, stats


nmiss_treatment, stats_treatment = impute_missing(raw_treatment, 'Treatment')
nmiss_convert, stats_convert = impute_missing(raw_convert, 'Conversion')
nmiss_demog, stats_demog = impute_missing(raw_demog, 'Demographics')
nmiss_external, stats_external = impute_missing(raw_external, 'External')
nmiss_tapestry, stats_tapestry = impute_missing(raw_tapestry, 'Tapestry')

# %% Save imputed datasets

# THIS NEEDS WORK. SO. SLOW!

raw_treatment.drop(['Region'], axis=1, inplace=True)
raw_convert.drop(['Region'], axis=1, inplace=True)
raw_external.drop(['Region'], axis=1, inplace=True)
raw_tapestry.drop(['Region'], axis=1, inplace=True)

raw_treatment.to_csv(localdisk + r'\T9_Rollup_Treatment.csv', chunksize=5000,
                     index=False)
raw_convert.to_csv(localdisk + r'\T10_Rollup_Conversion.csv', chunksize=5000,
                   index=False)
raw_demog.to_csv(localdisk + r'\T13_Rollup_Demog.csv', chunksize=5000,
                 index=False)
raw_external.to_csv(localdisk + r'\T12_Rollup_External.csv', chunksize=5000,
                    index=False)
raw_tapestry.to_csv(localdisk + r'\T11_Rollup_Tapestry.csv', chunksize=5000,
                    index=False)
