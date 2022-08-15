# -*- coding: utf-8 -*-
"""
------------------------------------------------------------------------------
Program Name: Prog_2_Transform_And_Clean_Dataset_Prep.py
Date Created: 8/8/2022
Created By: Elsa Haynes (elsa.c.haynes@kp.org)

Compiles 5 separate model CSVs into 1 dataset. Restricted to a random sample.

For KPIF: Separates both datasets into 4 more datasets (2x4=8 output)
    1. FM audience + On-HIX dependent var
    2. FM audience + Off-HIX dependent var
    3. RW audience + On-HIX dependent var
    4. RW audience + Off-HIX dependent var

------------------------------------------------------------------------------
"""

# %% Initialize Libraries and Paths

import pandas as pd
import gc

path = (r'C:\Users\c156934')

LOB = 'KPIF'

# %% Import CSV files


def import_csv(csv_name):
    global path
    df = pd.read_csv(path + csv_name + '.csv',
                     index_col=[0],
                     dtype={'AGLTY_INDIV_ID': object})
    return(df)


raw_sample = import_csv(r'\T8_Sample_Agilities')  # 500,000 rows
raw_treatment = import_csv(r'\T9_Rollup_Treatment')  # 7,246,772 rows
raw_convert = import_csv(r'\T10_Rollup_Conversion')  # 7,246,772 rows
raw_external = import_csv(r'\T12_Rollup_External')  # 7,246,772 rows
raw_demog = import_csv(r'\T13_Rollup_Demog')  # 7,246,772 rows
raw_tapestry = import_csv(r'\T11_Rollup_Tapestry')  # 7,246,772 rows

# %% Sample 500k
# do the random sampling here
# %% Compile Full Dataset

sample_appended = pd.merge(raw_treatment, raw_sample,
                           how="inner", on=['AGLTY_INDIV_ID'])
sample_appended = pd.merge(sample_appended, raw_convert,
                           how="left", on=['AGLTY_INDIV_ID', 'OE_Season'])
sample_appended = pd.merge(sample_appended, raw_tapestry,
                           how="left", on=['AGLTY_INDIV_ID', 'OE_Season'])
sample_appended = pd.merge(sample_appended, raw_external,
                           how="left", on=['AGLTY_INDIV_ID', 'OE_Season'])
sample_appended = pd.merge(sample_appended, raw_demog,
                           how="left", on=['AGLTY_INDIV_ID', 'OE_Season'])
del raw_sample
del raw_treatment
del raw_convert
del raw_tapestry
del raw_external
del raw_demog
gc.collect()

# %% Split into model sets

if LOB == 'KPIF':

    # sample_appended.groupby('Audience_CY').count()
    FM = sample_appended[sample_appended['Audience_CY'] == 'FM']
    RW = sample_appended[sample_appended['Audience_CY'] == 'RNC/WPL']
    del sample_appended

    FM_Off = FM.drop(['Conv_Resp_InboundCall', 'Conv_Enroll_OnHIX_Flag'],
                     axis=1)
    FM_On = FM.drop(['Conv_Resp_InboundCall', 'Conv_Enroll_OffHIX_Flag'],
                    axis=1)
    RW_Off = RW.drop(['Conv_Resp_InboundCall', 'Conv_Enroll_OnHIX_Flag'],
                     axis=1)
    RW_On = RW.drop(['Conv_Resp_InboundCall', 'Conv_Enroll_OffHIX_Flag'],
                    axis=1)
    del FM
    del RW

    FM_Off.to_csv(path + r'\T14_FM_Off_Sample.csv', index=False)
    FM_On.to_csv(path + r'\T15_FM_On_Sample.csv', index=False)
    RW_Off.to_csv(path + r'\T16_RW_Off_Sample.csv', index=False)
    RW_On.to_csv(path + r'\T17_RW_On_Sample.csv', index=False)

