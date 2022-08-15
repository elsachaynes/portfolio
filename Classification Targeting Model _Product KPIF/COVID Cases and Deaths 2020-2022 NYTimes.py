# -*- coding: utf-8 -*-
"""
------------------------------------------------------------------------------
Program Name: COVID Cases and Deaths 2020-2022 NYTimes.py
Date Created: 7/14/2022
Created By: Elsa Haynes (elsa.c.haynes@kp.org)

Pulls data from NYTimes GitHub repositories for COVID cases and deaths.

------------------------------------------------------------------------------
"""

# %% Initialize Libraries and Page Path

import pandas as pd
import requests
import io

# README https://github.com/nytimes/covid-19-data/blob/master/README.md

# %% Downloading the 2020 csv file from GitHub

url = "https://raw.githubusercontent.com/nytimes/covid-19-data/master/us-counties-2020.csv" # Make sure the url is the raw version of the file on GitHub
download = requests.get(url).content

# Reading the downloaded content and turning it into a pandas dataframe

dfCases_Deaths_2020 = pd.read_csv(io.StringIO(download.decode('utf-8')))

# Printing out the first 5 rows of the dataframe

print(dfCases_Deaths_2020.head())


# %% Downloading the 2021 csv file from GitHub

url = "https://raw.githubusercontent.com/nytimes/covid-19-data/master/us-counties-2021.csv" # Make sure the url is the raw version of the file on GitHub
download = requests.get(url).content
dfCases_Deaths_2021 = pd.read_csv(io.StringIO(download.decode('utf-8')))
print(dfCases_Deaths_2021.head())

# %% Downloading the csv file from GitHub

url = "https://raw.githubusercontent.com/nytimes/covid-19-data/master/us-counties-2022.csv" # Make sure the url is the raw version of the file on GitHub
download = requests.get(url).content
dfCases_Deaths_2022 = pd.read_csv(io.StringIO(download.decode('utf-8')))
print(dfCases_Deaths_2022.head())

# %% Compiling and saving

dfCases_Deaths_2020_2022 = pd.concat([dfCases_Deaths_2020, dfCases_Deaths_2021,
                                      dfCases_Deaths_2022])
outputpath = (r'\\cs.msds.kp.org\scal\REGS\share15\KPIF_ANALYTICS\Elsa'
             r'\KPIF_ Targeting Model 2023 OE\01 Raw Data\External Data')
dfCases_Deaths_2020_2022.to_csv(outputpath + '\COVID Cases and Deaths 2020-2022.csv')
