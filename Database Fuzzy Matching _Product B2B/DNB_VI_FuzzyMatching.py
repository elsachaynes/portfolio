#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""
------------------------------------------------------------------------------
Program Name: DNB_VI_FuzzyMatching.py
Date Created: 6/20/2022
Created By: Elsa Haynes (elsa.c.haynes@kp.org)

Uses fuzzy matching to match the DNB data append data back to SalesConnect
    accounts, leads, and brokers.

    Research questions:
        1. What % of DNB BW Website Visits are businesses already in SC?
        2. What % of [...] are current KP accounts?
        3. What % of [...] are current KP brokers?
        4. What % of [...] are current KP leads?
        5. What % of [...] are open KP opportunities?
        6. How many eligibles in these open opportunities?
        7. What % of open KP opportunities have visited the BW site?
        8. How can we use this information to improve user experience
           on the website?

Inputs: VI_SalesConnect.csv (SalesConnect data via SALESFORCE_BACKUP),
        VI_Demographics.csv (DNB data via Google Analytics API)

------------------------------------------------------------------------------
"""

# %% Initialize Libraries and Page Path

import pandas as pd
import numpy as np
from fuzzywuzzy import fuzz
# from fuzzywuzzy import process
from timeit import default_timer as timer
from datetime import timedelta

inputpath = (r'\\cs.msds.kp.org\scal\REGS\share15\KPIF_ANALYTICS\Elsa'
             r'\B2B_ DNB Visitor Intelligence Data Append\01 Raw Data')

outputpath = (r'\\cs.msds.kp.org\scal\REGS\share15\KPIF_ANALYTICS\Elsa'
             r'\B2B_ DNB Visitor Intelligence Data Append\02 Analysis\Elsa')

# %% Import DNB data
"""
dnb = pd.read_csv(inputpath + '\VI_Demographics.csv',
                  usecols=['DUNS_Number', 'DUNS_CompanyName', 'DUNS_AddrLine1',
                           'DUNS_AddrCity', 'DUNS_AddrState', 'DUNS_AddrZip',
                           'DUNS_CompanyPhone'],
                  dtype=object)
dnb.info()

dnb['DUNS_CompanyName'] = dnb['DUNS_CompanyName']\
    .str.upper()\
    .str.replace(',', '', regex=True)\
    .str.replace('.', '', regex=True)

dnb['DUNS_FullAddress'] = dnb.DUNS_AddrLine1\
    .str.cat(others=[dnb.DUNS_AddrCity,
                     dnb.DUNS_AddrState,
                     dnb.DUNS_AddrZip], sep=' ')\
    .str.upper()

dnbFinal = dnb[['DUNS_Number', 'DUNS_CompanyName', 'DUNS_FullAddress',
                'DUNS_CompanyPhone']]
del(dnb)
"""

# Saved previous work
dnbFinal = pd.read_csv(outputpath + '\dnbFinal_exactmatches.csv',
                       index_col=0,
                       dtype={'DUNS_Number': object,
                              'DUNS_CompanyPhone': object})
# %% Import SalesConnect data

sc = pd.read_csv(inputpath + '\VI_SalesConnect.csv',
                 parse_dates=['Rec_Updt_Dt'])
sc.info()

# Cleaning has already been done in SAS
scFinal = sc[['ID', 'AccountID', 'LeadID', 'BrokerID', 'CompanyName',
              'CompanyDBAName', 'CompanyAddr_1', 'CompanyAddr_2',
              'CompanyAddr_3', 'CompanyPhone', 'DUNS_Number']]

scFinal.info()
del(sc)


# Saved previous work
scFinal = pd.read_csv(outputpath + '\scFinal_exactmatches.csv',
                      index_col=0,
                      dtype=object,
                      converters={'Match': int}) 
scFinal.info()
# %% Set up match vectors


def create_match_vector_on_dnb(vector_name, var1, var2):
    global dnbFinal
    dnbFinal[vector_name] = np.where(dnbFinal[var1].notnull() &
                                     dnbFinal[var2].notnull(),
                                     dnbFinal[var1].str.cat(dnbFinal[var2],
                                                            sep='|'),
                                     np.nan)


def create_match_vector_on_sc(vector_name, var1, var2):
    global scFinal
    scFinal[vector_name] = np.where(scFinal[var1].notnull() &
                                    scFinal[var2].notnull(),
                                    scFinal[var1].astype(str)
                                    .str.cat(scFinal[var2].astype(str),
                                             sep='|'),
                                    np.nan)


# (1) Name+DUNS
create_match_vector_on_dnb('DNB_Name_ID', 'DUNS_CompanyName', 'DUNS_Number')
create_match_vector_on_sc('SC_Name_ID', 'CompanyName', 'DUNS_Number')

# (2) Name+Phone
create_match_vector_on_dnb('DNB_Name_Phone', 'DUNS_CompanyName',
                           'DUNS_CompanyPhone')
create_match_vector_on_sc('SC_Name1_Phone', 'CompanyName', 'CompanyPhone')
create_match_vector_on_sc('SC_Name2_Phone', 'CompanyDBAName', 'CompanyPhone')

# (3) Name+Address
create_match_vector_on_dnb('DNB_Name_Addr', 'DUNS_CompanyName',
                           'DUNS_FullAddress')
create_match_vector_on_sc('SC_Name_Addr1', 'CompanyName', 'CompanyAddr_1')
create_match_vector_on_sc('SC_Name_Addr2', 'CompanyName', 'CompanyAddr_2')
create_match_vector_on_sc('SC_Name_Addr3', 'CompanyName', 'CompanyAddr_3')

# %% Exact Matching

dnbFinal['Match'] = 0
scFinal['Match'] = 0


def exact_match(DNB_varname, SC_varname):
    global dnbFinal
    global scFinal

    # Get exact matches
    df = pd.merge(dnbFinal[~dnbFinal[DNB_varname].isnull()][[DNB_varname,
                                                             'DUNS_Number']]
                  .drop_duplicates(keep='first'),
                  scFinal[~scFinal[SC_varname].isnull()][[SC_varname, 'ID']]
                  .drop_duplicates(keep='first'),
                  left_on=DNB_varname,
                  right_on=SC_varname,
                  how='inner').drop_duplicates(keep='first')

    # Document exact matches in dnbFinal
    dnbFinal = pd.merge(dnbFinal,
                        df[[DNB_varname, 'ID']],
                        on=DNB_varname,
                        how='left',
                        indicator=True)
    dnbFinal.loc[dnbFinal['_merge'] == 'both', 'Match'] = 1  # Set match flag=1
    dnbFinal.loc[dnbFinal['_merge'] == 'both', SC_varname] = dnbFinal['ID']
    matches = dnbFinal.groupby('Match').size()[1]  # validate counts
    dnbFinal.drop('_merge', inplace=True, axis=1)  # reset
    dnbFinal.drop('ID', inplace=True, axis=1)  # reset

    # Document exact matches in scFinal
    scFinal = pd.merge(scFinal,
                       df.rename({'DUNS_Number': 'DUNS_ID'}, axis=1)
                       [[SC_varname, 'DUNS_ID']],
                       on=SC_varname,
                       how='left',
                       indicator=True)
    scFinal.loc[scFinal['_merge'] == 'both', 'Match'] = 1  # Set match flag=1
    scFinal.loc[scFinal['_merge'] == 'both', DNB_varname] = \
        scFinal['DUNS_ID']
    scFinal.drop('_merge', inplace=True, axis=1)  # reset
    scFinal.drop('DUNS_ID', inplace=True, axis=1)  # reset

    print("Cumulative exact matches: ", matches)


# (1) Name+DUNS
exact_match('DNB_Name_ID', 'SC_Name_ID')  # 191

# (2) Name+Phone
exact_match('DNB_Name_Phone', 'SC_Name1_Phone')  # 594
exact_match('DNB_Name_Phone', 'SC_Name2_Phone')  # 606

# (3) Name+Addr
exact_match('DNB_Name_Addr', 'SC_Name_Addr1')  # 1080
exact_match('DNB_Name_Addr', 'SC_Name_Addr2')  # 1085
exact_match('DNB_Name_Addr', 'SC_Name_Addr3')  # 1086

# Matches may be duplicates with multiple ID numbers for the same company
dnbFinal.to_csv(outputpath + '\dnbFinal_exactmatches.csv')
scFinal.to_csv(outputpath + '\scFinal_exactmatches.csv')

# %% Fuzzy Matching


def fuzzy_match_term(term, inp_list, min_score=0):
    # -1 score in case I don't get any matches
    max_score = -1

    # return empty for no match
    max_name = ''

    # iterate over all names in the other
    for term2 in inp_list:
        # find the fuzzy match score
        score = fuzz.token_sort_ratio(term, term2)

        # checking if I am above my threshold and have a better score
        if (score > min_score) & (score > max_score):
            max_name = term2
            max_score = score
    return (max_name, max_score)


def fuzzy_matching(DNB_List, SC_List, Output_List):

    start_time = timer()

    for name in DNB_List:

        # use the defined function above to find the best match,
        # also set the threshold to a chosen #
        match = fuzzy_match_term(name, SC_List, 80)

        dict_ = {}  # new dict for storing data
        dict_.update({'DNB': name})
        dict_.update({'SC': match[0]})
        dict_.update({'score': match[1]})

        if match[1] > -1:
            Output_List.append(dict_)

    end_time = timer()
    run_time = timedelta(seconds=end_time-start_time)

    return(Output_List, run_time)
    print("--- Runtime: " % run_time)


def fuzzy_match_join(dfMatches, DNB_varname, SC_varname,
                     DNB_varname_fuzzy, SC_varname_fuzzy):

    global scFinal
    global dnbFinal

    # Append IDs
    dfMatches = dfMatches.rename({'SC': SC_varname, 'DNB': DNB_varname},
                                 axis=1)\
        .sort_values([SC_varname, 'score'], ascending=[True, False])\
        .drop_duplicates(keep='first')
    dfMatches = pd.merge(dfMatches,
                         scFinal[~scFinal[SC_varname].isnull()]\
                         [[SC_varname, 'ID']]
                         .drop_duplicates(keep='first'),
                         on=SC_varname,
                         how='left').drop_duplicates(keep='first')
    dfMatches = pd.merge(dfMatches,
                         dnbFinal[~dnbFinal[DNB_varname].isnull()]\
                         [[DNB_varname, 'DUNS_Number']]
                         .drop_duplicates(keep='first'),
                         on=DNB_varname,
                         how='left').drop_duplicates(keep='first')
    # Document exact matches in dnbFinal
    dnbFinal = pd.merge(dnbFinal,
                        dfMatches[[DNB_varname, 'ID']],
                        on=DNB_varname,
                        how='left',
                        indicator=True)
    dnbFinal.loc[dnbFinal['_merge'] == 'both', 'Match'] = 1  # Set match flag=1
    dnbFinal.loc[dnbFinal['_merge'] == 'both',
                 SC_varname_fuzzy] = dnbFinal['ID']
    matches = dnbFinal.groupby('Match').size()[1]  # validate counts
    dnbFinal.drop(['_merge', 'ID'], inplace=True, axis=1)  # reset
    # Document exact matches in scFinal
    scFinal = pd.merge(scFinal,
                       dfMatches.rename({'DUNS_Number': 'DUNS_ID'}, axis=1)
                       [[SC_varname, 'DUNS_ID']],
                       on=SC_varname,
                       how='left',
                       indicator=True)
    scFinal.loc[scFinal['_merge'] == 'both', 'Match'] = 1  # Set match flag=1
    scFinal.loc[scFinal['_merge'] == 'both',
                DNB_varname_fuzzy] = scFinal['DUNS_ID']
    scFinal.drop(['_merge', 'DUNS_ID'], inplace=True, axis=1)  # reset

    print("Cumulative exact matches: ", matches)
    return(dfMatches)


def create_fuzzy_match_vector_dnb(DNB_varname):
    global dnbUnmatched
    ser = dnbUnmatched[~dnbUnmatched[DNB_varname].isnull()][DNB_varname]
    ser = pd.Series(pd.unique(ser))
    return(ser)


def create_fuzzy_match_vector_sc(SC_varname):
    ser = scFinal[~scFinal[SC_varname].isnull()][SC_varname]
    ser = pd.Series(pd.unique(ser))
    return(ser)


# %% Fuzzy Matching: (1) Name+Phone
# Name+Phone 1 of 2
# Complete

# Updated list for matching
dnbUnmatched = dnbFinal[dnbFinal['Match'] == 0]
DNB_Name_Phone = create_fuzzy_match_vector_dnb('DNB_Name_Phone')
SC_Name2_Phone = create_fuzzy_match_vector_sc('SC_Name2_Phone')
Dict_NP_1 = []  # store output
fuzzy_matching(DNB_Name_Phone, SC_Name2_Phone, Dict_NP_1)
match_NP_1 = pd.DataFrame.from_dict(Dict_NP_1)
del Dict_NP_1
match_NP_1.to_csv(outputpath + '\Matches_NP_1.csv')
match_NP_1 = fuzzy_match_join(match_NP_1, 'DNB_Name_Phone', 'SC_Name2_Phone',
                              'DNB_Name_Phone_Fuzzy', 'SC_Name2_Phone_Fuzzy')
# 1131 cumulative matches
dnbFinal.to_csv(outputpath + '\dnbFinal_exactmatches.csv')
scFinal.to_csv(outputpath + '\scFinal_exactmatches.csv')

# Name+Phone 2 of 2
# Incomplete

# Updated list for matching
dnbUnmatched = dnbFinal[dnbFinal['Match'] == 0]
DNB_Name_Phone = create_fuzzy_match_vector_dnb('DNB_Name_Phone')
SC_Name1_Phone = create_fuzzy_match_vector_sc('SC_Name1_Phone')
Dict_NP_2 = []  # store output
fuzzy_matching(DNB_Name_Phone, SC_Name1_Phone, Dict_NP_2)
match_NP_2 = pd.DataFrame.from_dict(Dict_NP_2)
match_NP_2.to_csv(outputpath + '\Matches_NP_2.csv')
match_NP_2 = fuzzy_match_join(match_NP_2, 'DNB_Name_Phone', 'SC_Name1_Phone',
                              'DNB_Name_Phone_Fuzzy', 'SC_Name1_Phone_Fuzzy')
# 1896 cumulative matches
dnbFinal.to_csv(outputpath + '\dnbFinal_exactmatches.csv')
scFinal.to_csv(outputpath + '\scFinal_exactmatches.csv')

# %% Fuzzy Matching: (2) Name+Address
# Name+Address 1 of 3 
# Incomplete

# Updated list for matching
dnbUnmatched = dnbFinal[dnbFinal['Match'] == 0]
DNB_Name_Addr = create_fuzzy_match_vector_dnb('DNB_Name_Addr')
SC_Name_Addr1 = create_fuzzy_match_vector_sc('SC_Name_Addr1')
Dict_NA_1 = []  # store output
fuzzy_matching(DNB_Name_Addr, SC_Name_Addr1, Dict_NA_1)
match_NA_1 = pd.DataFrame.from_dict(Dict_NA_1)
match_NA_1.to_csv(inputpath + '\Matches_NA_1.csv')
match_NA_1 = fuzzy_match_join(match_NA_1, 'DNB_Name_Addr', 'SC_Name_Addr1',
                                'DNB_Name_Addr_Fuzzy', 'SC_Name_Addr1_Fuzzy')
# 2037 cumulative matches
dnbFinal.to_csv(outputpath + '\dnbFinal_exactmatches.csv')
scFinal.to_csv(outputpath + '\scFinal_exactmatches.csv')

# Name+Address 2 of 3
# Complete

# Updated list for matching
dnbUnmatched = dnbFinal[dnbFinal['Match'] == 0]
DNB_Name_Addr = create_fuzzy_match_vector_dnb('DNB_Name_Addr')
SC_Name_Addr2 = create_fuzzy_match_vector_sc('SC_Name_Addr2')
Dict_NA_2 = []  # store output
fuzzy_matching(DNB_Name_Addr, SC_Name_Addr2, Dict_NA_2) 
match_NA_2 = pd.DataFrame.from_dict(Dict_NA_2)
match_NA_2.to_csv(inputpath + '\Matches_NA_2.csv')
match_NA_2 = fuzzy_match_join(match_NA_2, 'DNB_Name_Addr', 'SC_Name_Addr2',
                              'DNB_Name_Addr_Fuzzy', 'SC_Name_Addr2_Fuzzy')
# 2258 cumulative matches
dnbFinal.to_csv(outputpath + '\dnbFinal_exactmatches.csv')
scFinal.to_csv(outputpath + '\scFinal_exactmatches.csv')

# Name+Address 3 of 3 
# Complete (no new matches)

# Updated list for matching
dnbUnmatched = dnbFinal[dnbFinal['Match'] == 0] 
DNB_Name_Addr = create_fuzzy_match_vector_dnb('DNB_Name_Addr')
SC_Name_Addr3 = create_fuzzy_match_vector_sc('SC_Name_Addr3')
Dict_NA_3 = []  # store output
fuzzy_matching(DNB_Name_Addr, SC_Name_Addr3, Dict_NA_3) # HERE!
match_NA_3 = pd.DataFrame.from_dict(Dict_NA_3)
match_NA_3.to_csv(inputpath + '\Matches_NA_3.csv')
match_NA_3 = fuzzy_match_join(match_NA_3, 'DNB_Name_Addr', 'SC_Name_Addr3',
                              'DNB_Name_Addr_Fuzzy', 'SC_Name_Addr3_Fuzzy')

#%% Fuzzy Matching: (3) Name+DUNS
# Name+DUNS 1 of 1
# Complete

# Updated list for matching
dnbUnmatched = dnbFinal[dnbFinal['Match'] == 0]
DNB_Name_ID = create_fuzzy_match_vector_dnb('DNB_Name_ID')
SC_Name_ID = create_fuzzy_match_vector_sc('SC_Name_ID')

Dict_NI = []  # store output
fuzzy_matching(DNB_Name_ID, SC_Name_ID, Dict_NI)
match_NI = pd.DataFrame.from_dict(Dict_NI)
match_NI.to_csv(inputpath + '\Matches_NI.csv')
match_NI = fuzzy_match_join(match_NI, 'DNB_Name_ID', 'SC_Name_ID',
                              'DNB_Name_ID_Fuzzy', 'SC_Name_ID_Fuzzy')
# 2206 cumulative matches
dnbFinal.to_csv(outputpath + '\dnbFinal_exactmatches.csv')
scFinal.to_csv(outputpath + '\scFinal_exactmatches.csv')

# %% Clean DNB to one row per DUNS_Number

# 1 row per unique SC ID

dnbSmall = dnbFinal[~dnbFinal['SC_Name_ID'].isnull()]\
            [['DUNS_Number', 'Match', 'SC_Name_ID']]\
            .rename({'SC_Name_ID': 'SC_ID'}, axis=1)\
            .drop_duplicates(keep='first')


def Clean_DNB_Unique_Row(SC_Match_Key):
    global dnbSmall
    newdnbSmall = dnbFinal[~dnbFinal[SC_Match_Key].isnull()]\
        [['DUNS_Number', 'Match', SC_Match_Key]]\
        .rename({SC_Match_Key: 'SC_ID'}, axis=1)\
        .drop_duplicates(keep='first')
    dnbSmall = pd.concat([newdnbSmall, dnbSmall.loc[:]]).reset_index(drop=True)
    dnbSmall = dnbSmall.drop_duplicates()


Clean_DNB_Unique_Row('SC_Name1_Phone')
Clean_DNB_Unique_Row('SC_Name2_Phone')
Clean_DNB_Unique_Row('SC_Name_Addr1')
Clean_DNB_Unique_Row('SC_Name_Addr2')
Clean_DNB_Unique_Row('SC_Name_Addr3')
Clean_DNB_Unique_Row('SC_Name_ID_Fuzzy')
Clean_DNB_Unique_Row('SC_Name1_Phone_Fuzzy')
Clean_DNB_Unique_Row('SC_Name2_Phone_Fuzzy')
Clean_DNB_Unique_Row('SC_Name_Addr1_Fuzzy')
Clean_DNB_Unique_Row('SC_Name_Addr2_Fuzzy')

# Transpose
dnbSmall['idx'] = dnbSmall.groupby('DUNS_Number').cumcount()
tmp = []
for var in ['SC_ID']:
    dnbSmall['tmp_idx'] = var + '_' + dnbSmall.idx.astype(str)
    tmp.append(dnbSmall.pivot(index='DUNS_Number',
                              columns='tmp_idx', values=var))
dnbSmall = pd.concat(tmp, axis=1)
del tmp
del var

dnbSmall.to_csv(outputpath + '\dnbSmall_exactmatches.csv') 

# keep only 3 SC IDs

dnbSmall['SC_ID_0'].notnull().sum()  # 1291
dnbSmall['SC_ID_1'].notnull().sum()  # 215
dnbSmall['SC_ID_2'].notnull().sum()  # 76
dnbSmall['SC_ID_3'].notnull().sum()  # 37

dnbSmall = dnbSmall.reset_index()
dnbSmall = dnbSmall[['DUNS_Number', 'SC_ID_0', 'SC_ID_1', 'SC_ID_2']]

# append DNB name and SC name and export for verification
dnbSmall = pd.merge(dnbSmall,
                    dnbFinal[['DUNS_Number', 'DUNS_CompanyName']],
                    on='DUNS_Number',
                    how='left').drop_duplicates()
dnbSmall = pd.merge(dnbSmall,
                    scFinal.rename({'ID': 'SC_ID_0', 'CompanyName': 'SCName1'},
                                   axis=1)[['SC_ID_0', 'SCName1']],
                    on='SC_ID_0',
                    how='left').drop_duplicates()
dnbSmall = pd.merge(dnbSmall,
                    scFinal.rename({'ID': 'SC_ID_1', 'CompanyName': 'SCName2'},
                                   axis=1)[['SC_ID_1', 'SCName2']],
                    on='SC_ID_1',
                    how='left').drop_duplicates()
dnbSmall = pd.merge(dnbSmall,
                    scFinal.rename({'ID': 'SC_ID_2', 'CompanyName': 'SCName3'},
                                   axis=1)[['SC_ID_2', 'SCName3']],
                    on='SC_ID_2',
                    how='left').drop_duplicates()
dnbSmall.to_csv(outputpath + '\dnbSmall_exactmatches.csv')  

# Import cleaned/verified dataset
dnbSmall_validated = pd.read_csv(outputpath + '\dnbSmall_validated.csv',
                                 index_col=0, dtype=object,
                                 converters={'Match': int, 'Approved': int})

# append non-match DNBs back to list
dnbUnmatched = dnbFinal[dnbFinal['Match'] == 0][['DUNS_Number',
                                                 'Match',
                                                 'DUNS_CompanyName']]
dnbUnmatched['Approved'] = 1
dnbMatchedFinal = pd.concat([dnbUnmatched, dnbSmall_validated.loc[:]])\
                    .reset_index(drop=True)
dnbMatchedFinal['Match'].sum()  # 1148 matches
dnbMatchedFinal.to_csv(outputpath + '\DNB_Matched_Final.csv') 

scFinal.info()
# Group the SC IDs into account, lead, or broker
dnbMatchedFinal = pd.merge(dnbMatchedFinal,
                scFinal[['ID','AccountID','LeadID','BrokerID']],
                left_on='SC_ID_0',
                right_on='ID',
                suffixes=(None,'_0'),
                how='left').drop_duplicates()
dnbMatchedFinal = pd.merge(dnbMatchedFinal,
                scFinal[['ID','AccountID','LeadID','BrokerID']],
                left_on='SC_ID_1',
                right_on='ID',
                suffixes=(None,'_1'),
                how='left').drop_duplicates()
dnbMatchedFinal = pd.merge(dnbMatchedFinal,
                scFinal[['ID','AccountID','LeadID','BrokerID']],
                left_on='SC_ID_2',
                right_on='ID',
                suffixes=(None,'_2'),
                how='left').drop_duplicates()

dnbMatchedFinal = dnbMatchedFinal.drop(['Approved', 'SC_ID_0',
                                        'SC_ID_1','SC_ID_2',
                                        'SCName1','SCName2',
                                        'SCName3','ID',
                                        'ID_1','ID_2'], axis=1)
dnbMatchedFinal = dnbMatchedFinal.rename({'AccountID_1': 'AccountID_2',
                                          'LeadID_1': 'LeadID_2',
                                          'BrokerID_1': 'BrokerID_2',
                                          'AccountID_2': 'AccountID_3',
                                          'LeadID_2': 'LeadID_3',
                                          'BrokerID_2': 'BrokerID_3',
                                          'AccountID': 'AccountID_1',
                                          'LeadID': 'LeadID_1',
                                          'BrokerID': 'BrokerID_1'}, axis=1)
dnbMatchedFinal = dnbMatchedFinal[['Match', 'DUNS_Number', 'DUNS_CompanyName',
                                   'AccountID_1', 'AccountID_2', 'AccountID_3',
                                   'LeadID_1', 'LeadID_2', 'LeadID_3',
                                   'BrokerID_1','BrokerID_2','BrokerID_3']]
   
# Account_Flag
dnbMatchedFinal['Account_Flag'] = 0
dnbMatchedFinal.loc[dnbMatchedFinal['AccountID_1'].notnull() | \
                    dnbMatchedFinal['AccountID_2'].notnull() | \
                    dnbMatchedFinal['AccountID_3'].notnull(), 'Account_Flag'] = 1  
# Lead_Flag
dnbMatchedFinal['Lead_Flag'] = 0
dnbMatchedFinal.loc[dnbMatchedFinal['LeadID_1'].notnull() | \
                    dnbMatchedFinal['LeadID_2'].notnull() | \
                    dnbMatchedFinal['LeadID_3'].notnull(), 'Lead_Flag'] = 1  
# Broker_Flag
dnbMatchedFinal['Broker_Flag'] = 0
dnbMatchedFinal.loc[dnbMatchedFinal['BrokerID_1'].notnull() | \
                    dnbMatchedFinal['BrokerID_2'].notnull() | \
                    dnbMatchedFinal['BrokerID_3'].notnull(), 'Broker_Flag'] = 1 

dnbMatchedFinal.to_csv(outputpath + '\DNB_Matched_Final.csv')

## %% Analysis

# 1. What % of DNB BW Website Visits are businesses already in SC?
# Numerator: count of unique DUNS_Numbers with at least 1 SC ID
# Denominator: count of unique DUNS_Numbers
pct_dnb_in_sc = (dnbMatchedFinal['Match'].sum() / len(dnbMatchedFinal))*100
print(pct_dnb_in_sc)  

# 2. What % of [...] are current KP accounts?
# Numerator: count of unique DUNS_Numbers where SC ID is an Account ID
# Demoninator: count of unique DUNS_Numbers
pct_dnb_kpAcct = (dnbMatchedFinal['Account_Flag'].sum() / len(dnbMatchedFinal))*100
print(pct_dnb_kpAcct)   

# Active accounts vs opportunities vs. termed accts

# 3. What % of [...] are KP brokers?
# Numerator: count of unique DUNS_Numbers where SC ID is a Lead ID
# Demoninator: count of unique DUNS_Numbers
pct_dnb_kpBkr = (dnbMatchedFinal['Broker_Flag'].sum() / len(dnbMatchedFinal))*100
print(pct_dnb_kpBkr) 

# active vs. termed? # eligibles on open opps?

# 4. What % of [...] are KP leads?
# Numerator: count of unique DUNS_Numbers where SC ID is a Lead ID
# Demoninator: count of unique DUNS_Numbers
pct_dnb_kpLead = (dnbMatchedFinal['Lead_Flag'].sum() / len(dnbMatchedFinal))*100
print(pct_dnb_kpLead)  

# Year/Month of the KP leads

# 5. What % of [...] are open KP opportunities?
# 6. How many eligibles in these open opportunities?
# 7. What % of open KP opportunities have visited the BW site?

# % of SC leads/accounts

# BW metrics for matches?

