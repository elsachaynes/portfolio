#!/usr/bin/env python
# coding: utf-8

# In[5]:


# @hidden_cell
# The project token is an authorization token that is used to access project resources like data sources, connections, and used by platform APIs.
from project_lib import Project
project = Project(project_id='85c22417-fa77-4c5e-839a-0df65f888eea', project_access_token='p-edb2d677a5e0da8b0928136b8cce06e89a50b8cd')
pc = project.project_context


# In[6]:


# !pip install --upgrade google-api-python-client oauth2client

# !pip install cryptography


# # Google SA360 API

# In[7]:


import argparse
import httplib2
from apiclient.discovery import build
from oauth2client import GOOGLE_TOKEN_URI
from oauth2client.client import OAuth2Credentials, HttpAccessTokenRefreshError
import time
from datetime import datetime,timedelta

from requests_oauthlib import OAuth2Session

import pandas as pd
import requests
import json

import pprint
# import simplejson
from googleapiclient.errors import HttpError

from cryptography.fernet import Fernet

def create_credentials(client_id, client_secret, refresh_token):
    """Create Google OAuth2 credentials.

      Args:
        client_id: Client id of a Google Cloud console project.
        client_secret: Client secret of a Google Cloud console project.
        refresh_token: A refresh token authorizing the Google Cloud console project
          to access the DS data of some Google user.

      Returns:
        OAuth2Credentials
    """
    return OAuth2Credentials(access_token=None,
                           client_id=client_id,
                           client_secret=client_secret,
                           refresh_token=refresh_token,
                           token_expiry=None,
                           token_uri=GOOGLE_TOKEN_URI,
                           user_agent=None)


def get_service(credentials):
    """Set up a new Doubleclicksearch service.

      Args:
        credentials: An OAuth2Credentials generated with create_credentials, or
        flows in the oatuh2client.client package.
      Returns:
        An authorized Doubleclicksearch serivce.
      """
      # Use the authorize() function of OAuth2Credentials to apply necessary credential
      # headers to all requests.
    http = credentials.authorize(http = httplib2.Http())

    # Construct the service object for the interacting with the Search Ads 360 API.
    service = build('doubleclicksearch', 'v2', http=http)
#     service = build('analyticsreporting', 'v4', http=http)
    return service


def generate_report(service,body):
    """Generate and print sample report.

    Args:
    service: An authorized Doubleclicksearch service. See Set Up Your Application.
    """
    request = service.reports().request(body = body)


    print(request.execute())
    return request.execute()
    
    


def poll_report(service, report_id, t=10,filepath=''):
    """Poll the API with the reportId until the report is ready, up to ten times.

    Args:
        service: An authorized Doubleclicksearch service.
        report_id: The ID DS has assigned to a report.
    """
    for _ in range(10):
        try:
            request = service.reports().get(reportId=report_id)
            json_data = request.execute()
            if json_data['isReportReady']:
                pprint.pprint('The report is ready.')

                # For large reports, DS automatically fragments the report into multiple
                # files. The 'files' property in the JSON object that DS returns contains
                # the list of URLs for file fragment. To download a report, DS needs to
                # know the report ID and the index of a file fragment.
                for i in range(len(json_data['files'])):
                    pprint.pprint('Downloading fragment ' + str(i) + ' for report ' + report_id)
                    download_files(service, report_id, str(i),filepath) # See Download the report.
                return

            else:
                pprint.pprint('Report is not ready. I will try again.')
                time.sleep(t)
        except HttpError as e:
            error = simplejson.loads(e.content)['error']['errors'][0]

            # See Response Codes
            pprint.pprint('HTTP code %d, reason %s' % (e.resp.status, error['reason']))
            break
            
            
def download_files(service, report_id, report_fragment, filepath = ''):
    """Generate and print sample report.

    Args:
        service: An authorized Doubleclicksearch service.
        report_id: The ID DS has assigned to a report.
        report_fragment: The 0-based index of the file fragment from the files array.
    """
    filename = '{}{}-report-{}-{}-{}-{}.csv'.format(filepath,lobReport,start_date,end_date,report_id,report_fragment)
    print(filename)
    f = open(filename, 'wb')
    request = service.reports().getFile(reportId=report_id, reportFragment=report_fragment)
    f.write(request.execute())
    f.close()
    
def get_conversion(service):
    """Request the first 10 conversions in a specific campaign
     and print the list.

    Args:
    service: An authorized Doubleclicksearch service. See Set Up Your Application.
    """
    request = service.conversion().get(
      agencyId='20700000001328135', #// Replace with your ID
      advertiserId='21700000001745077',# // Replace with your ID
      engineAccountId='700000002106615',# // Replace with your ID
#       campaignId='71700000002044839', // Replace with your ID
      startDate=20131115,
      endDate=20211231,
      startRow=0,
      rowCount=100
    )

    pprint.pprint(request.execute())
    return request.execute()


# # Loading Credentials

# In[4]:


j_client = {'installed': 
            {'code': '4/1AY0e-g7YpeFKiPc5Uok0yMaXyYZ3kOBLYhAm_yyONelmqSFqtVWHzYwbxkQ', 
             'client_id': b'gAAAAABhuMe-fC2FFKG6CwWnB5viSXe_KzuAahnuG6A1zI59UsEZ8D6_E5tQeeiM9qQ6ADuT3-J1qtwBwuSd9PfkltfuIhnx8B7mWnkJTaFM4x5XzRvbST33dEtNOZt_VdI1OivdAPXr1M_i5MTN00weqXU0pWxauTnPzx_q3vZgiOgwwvb_bLM=', 
             'project_id': 'b2b-better-way-api', 
             'auth_uri': 'https://accounts.google.com/o/oauth2/auth', 
             'token_uri': 'https://oauth2.googleapis.com/token', 
             'auth_provider_x509_cert_url': 'https://www.googleapis.com/oauth2/v1/certs', 
             'client_secret': b'gAAAAABhuMfjQWwEw_WLWcCC8Ii5DwLpGtDmkXm2dBxgXTVoltZIhLK2kM0n-6_NY1QLtwpTfK30p3VqxnP_ipMLg7_FWkAr12aaJsb1veuQBo9AUw6TgqA='}, 
            'redirect_uris': ['urn:ietf:wg:oauth:2.0:oob', 'http://localhost']}

j_token = {'access_token': 'ya29.a0AfH6SMCbXOICEP6lyxYZipJ_b09wOMgWxF40VSXHYtTuPMMYFgv7yUqdaAw-9B1LtlXtonyDfT-7LsBH-VsDRvcmaEDDsWtgDmHeecnN97xeszTXziJNsje5SYT-kFLwVpNuTo6C3tVuXN9FCR9CES8IM1Pm', 
           'expires_in': 3599, 
           'refresh_token': b'gAAAAABhuMeIb02ziBcbWWG3Upkh8F7W34R2W5vbYM5ARFhdBn9XI7L5pXhmRIMtf-hXn8p97_s-GY5OeebYR5Dbaysfp2aaqIy1qUQIO8iCauSgfxFByIiuZQfJmrUMY9NYmFTHbBU4ufys6UndYwEW1Yh2fYngBucRZ4L5YtenLLkNDoI9xvOs1vbAjqigzRJ4wz-U97AB2WZwwGm_0BJveG4GqLJBZA==', 
           'scope': 'https://www.googleapis.com/auth/analytics.readonly https://www.googleapis.com/auth/doubleclicksearch', 
           'token_type': 'Bearer',
           'encode':b'Jc407WC2MZNWyP1tuDsL90WVdwJGJCQl4xLGIKcPEGE='
          }

fernet = Fernet(j_token['encode'])

client_id = j_client['installed']['client_id']
client_secret = j_client['installed']['client_secret']
refresh_token = j_token['refresh_token']

creds = create_credentials(fernet.decrypt(client_id).decode(),
                            fernet.decrypt(client_secret).decode(),
                            fernet.decrypt(refresh_token).decode())

try:
    service = get_service(creds)
    print('Successfully loaded credentials.')
except HttpAccessTokenRefreshError:
    print('Error: Unable to get credentials. Please ensure that the '
           'credentials are correct. '
           'https://developers.google.com/search-ads/v2/authorizing'
          )


# In[8]:


#start_date = '05/23/2022'
#end_date = '05/29/2022'
# today = datetime.strptime(date, "%m/%d/%Y")
today = datetime.today()

start_date = str((today-timedelta(days=today.weekday())-timedelta(days=7)).date())

#today = datetime.today()

end_date = str((today-timedelta(days=today.weekday())-timedelta(days=1)).date())

print(start_date,end_date)


# # Medicare

# In[33]:


# Business CalPERS EL FEDS KPIF MDCR Medicaid Thrive Tricare VivaBien
lobReport = 'MDCR'

# Business=21700000001745077;
# CalPERS=21700000001745080;
# EL=21700000001719683;
# FEDs=21700000001745071;
# KPIF=21700000001739091;
# MDCR=21700000001745674;
# Medicaid=21700000001747385;
# Thrive=21700000001745083;
# Tricare=21700000001745086;
# VivaBien=21700000001745089;

if lobReport == 'Business':
    av_id = '21700000001745077'
elif lobReport == 'CalPERS':
    av_id = '21700000001745080'
elif lobReport == 'EL':
    av_id = '21700000001719683'
elif lobReport == 'FEDS':
    av_id = '21700000001745071'
elif lobReport == 'KPIF':
    av_id = '21700000001739091'
elif lobReport == 'MDCR':
    av_id = '21700000001745674'
elif lobReport == 'Medicaid':    
    av_id = '21700000001747385'
elif lobReport == 'Thrive':    
    av_id = '21700000001745083'
elif lobReport == 'Tricare':    
    av_id = '21700000001745086'
elif lobReport == 'VivaBien':    
    av_id = '21700000001745089'
    
print('{}: {}'.format(lobReport,av_id))

# Building report request

body={
    "reportScope": {
        "agencyId": "20700000001328135", #// Replace with your ID
        "advertiserId": av_id, #// Replace with your ID
#             "engineAccountId": "700000000073991" // Replace with your ID
        },
    "reportType": "keyword",
    "columns": [
        
        { "columnName": "date" },
        { "columnName": "account" },
        { "columnName": "campaign" },
#         { "columnName": "deviceSegment" },
        { "columnName": "adGroup" },
        { "columnName": "keywordText" },
        { "columnName": "keywordMatchType" },
        { "columnName": "keywordMaxCpc" },
        { "columnName": "impr" },
        { "columnName": "clicks" },
        { "columnName": "cost" },
        { "columnName": "qualityScoreAvg" },
        { "savedColumnName": "MDCR Applications", "platformSource": "floodlight" },
        
#         # b2b
#         { "columnName": "keywordText" },
#         { "columnName": "adGroup" },
#         { "columnName": "campaign" },
#         { "columnName": "keywordMatchType" },
#         { "columnName": "date" },
#         { "columnName": "cost" },
#         { "columnName": "impr" },
#         { "columnName": "clicks" },
#         { "columnName": "qualityScoreAvg" },
        
#         { "savedColumnName": "Business Actions (New)", "platformSource": "floodlight" },
#         { "savedColumnName": "Business Leads", "platformSource": "floodlight" },
#         { "savedColumnName": "Shop", "platformSource": "floodlight" },
#         { "savedColumnName": "Learn", "platformSource": "floodlight" },
#         { "savedColumnName": "B2B Contact Us Thank You Page", "platformSource": "floodlight" },
#         { "savedColumnName": "Get a Quote Thank You Page", "platformSource": "floodlight" },
#         { "savedColumnName": "SSQ Start Button Clicks", "platformSource": "floodlight" },
#         { "savedColumnName": "Web Lead", "platformSource": "floodlight" },
#         { "savedColumnName": "Download ebook [First Timer] TY Page", "platformSource": "floodlight" },
        
        
        
        { "columnName": "keywordLandingPage" },
        
        
      ],
      "timeRange" : {
        "startDate" : start_date,
        "endDate" : end_date
      },
          "filters": [
            {
              "column" : { "columnName": "impr" },
              "operator" : "greaterThan",
              "values" : [
                0
              ]
            },
              {
              "column" : { "columnName": "clicks" },
              "operator" : "greaterThan",
              "values" : [
                0
              ]
            }
          ],
      "downloadFormat": "csv",
      "maxRowsPerFile": 6000000,
      "statisticsCurrency": "agency",
      "verifySingleTimeZone": "false",
      "includeRemovedEntities": "false"
    }
# print(body)


# In[34]:


request = service.reports().request(body = body)
request.execute()

request = generate_report(service, body)
with open(r'log\report-{}.json'.format(request['id']),'w') as f:
    f.write(str(request))
print('The id for the request is: {}'.format(request['id']))
print('Is Report Ready?: {}'.format(request['isReportReady']))
print

request_id = request['id']

filepath = ''
poll_report(service,request_id ,filepath = filepath) # with custom metrics


# In[35]:


import glob
filename = glob.glob('MDCR*')
print(filename)
for file in filename:
    df = pd.read_csv(file)
    df.rename(columns={
        'keywordText':'Keyword',
        'account':'Account',
        'adGroup':'Ad group',
        'campaign':'Campaign',
        'keywordMatchType':'Match Type',
        'date':'Date',
        'cost':'Cost',
        'impr':'Impr',
        'clicks':'Clicks',
        'qualityScoreAvg':'Quality score (avg)',
        'keywordLandingPage':'Keyword landing page'},
        inplace=True)
    project.save_data(file_name = file,data = df.to_csv(index=False))


# In[36]:


df.sum()


# # B2B

# In[37]:


# Business CalPERS EL FEDS KPIF MDCR Medicaid Thrive Tricare VivaBien
lobReport = 'Business'

# Business=21700000001745077;
# CalPERS=21700000001745080;
# EL=21700000001719683;
# FEDs=21700000001745071;
# KPIF=21700000001739091;
# MDCR=21700000001745674;
# Medicaid=21700000001747385;
# Thrive=21700000001745083;
# Tricare=21700000001745086;
# VivaBien=21700000001745089;

if lobReport == 'Business':
    av_id = '21700000001745077'
elif lobReport == 'CalPERS':
    av_id = '21700000001745080'
elif lobReport == 'EL':
    av_id = '21700000001719683'
elif lobReport == 'FEDS':
    av_id = '21700000001745071'
elif lobReport == 'KPIF':
    av_id = '21700000001739091'
elif lobReport == 'MDCR':
    av_id = '21700000001745674'
elif lobReport == 'Medicaid':    
    av_id = '21700000001747385'
elif lobReport == 'Thrive':    
    av_id = '21700000001745083'
elif lobReport == 'Tricare':    
    av_id = '21700000001745086'
elif lobReport == 'VivaBien':    
    av_id = '21700000001745089'
    
print('{}: {}'.format(lobReport,av_id))

# Building report request

body={
    "reportScope": {
        "agencyId": "20700000001328135", #// Replace with your ID
        "advertiserId": av_id, #// Replace with your ID
#             "engineAccountId": "700000000073991" // Replace with your ID
        },
    "reportType": "keyword",
    "columns": [
        
        { "columnName": "keywordText" },
        { "columnName": "adGroup" },
        { "columnName": "campaign" },
        { "columnName": "keywordMatchType" },
        { "columnName": "date" },
        { "columnName": "cost" },
        { "columnName": "impr" },
        { "columnName": "clicks" },
        { "columnName": "qualityScoreAvg" },
        
#         { "savedColumnName": "Business Actions (New)", "platformSource": "floodlight" },
        { "savedColumnName": "B2B Actions - GA View Update", "platformSource": "floodlight" },
#         { "savedColumnName": "Business Leads", "platformSource": "floodlight" },
        { "savedColumnName": "Connex B2B Leads - Updated GA View", "platformSource": "floodlight" },
#         { "savedColumnName": "Shop", "platformSource": "floodlight" },
#         { "savedColumnName": "Learn", "platformSource": "floodlight" },
        { "savedColumnName": "Convert Submit Contact", "platformSource": "floodlight" },
        { "savedColumnName": "Convert Submit Quote", "platformSource": "floodlight" },
        { "savedColumnName": "Convert Non Submit SSQ", "platformSource": "floodlight" },
#         { "savedColumnName": "Web Lead", "platformSource": "floodlight" },
        { "savedColumnName": "SB MAS Leads - GA View Update", "platformSource": "floodlight" },
        { "columnName": "keywordLandingPage" },
        
#         { "savedColumnName": "SB MAS Web Leads (New)", "platformSource": "floodlight" },
#         { "savedColumnName": "Business Leads (New)", "platformSource": "floodlight" },
#         { "savedColumnName": "B2B Backfill", "platformSource": "floodlight" },
#         { "savedColumnName": "GAQ Pageview", "platformSource": "floodlight" },
#         { "savedColumnName": "Get a Quote - Button Click", "platformSource": "floodlight" },
#         { "savedColumnName": "SBU_Nurture_eBookDownloadSwitcher [Switcher] TY Page", "platformSource": "floodlight" },
        
      ],
      "timeRange" : {
        "startDate" : start_date,
        "endDate" : end_date
      },
          "filters": [
            {
              "column" : { "columnName": "impr" },
              "operator" : "greaterThan",
              "values" : [
                0
              ]
            }
          ],
      "downloadFormat": "csv",
      "maxRowsPerFile": 6000000,
      "statisticsCurrency": "agency",
      "verifySingleTimeZone": "false",
      "includeRemovedEntities": "false"
    }
# print(body)


# In[38]:


request = service.reports().request(body = body)
request.execute()

request = generate_report(service, body)
with open(r'log\report-{}.json'.format(request['id']),'w') as f:
    f.write(str(request))
print('The id for the request is: {}'.format(request['id']))
print('Is Report Ready?: {}'.format(request['isReportReady']))
print

request_id = request['id']

filepath = ''
poll_report(service,request_id ,filepath = filepath) # with custom metrics


# In[39]:


import glob
filename = glob.glob('Business*')
# print(filename)
for file in filename:
    print(file)
    df = pd.read_csv(file)
    df.rename(columns={
        'keywordText':'Keyword',
        'adGroup':'Ad group',
        'campaign':'Campaign',
        'keywordMatchType':'Match Type',
        'date':'Date',
        'cost':'Cost',
        'impr':'Impr',
        'clicks':'Clicks',
        'qualityScoreAvg':'Quality score (avg)',
        'keywordLandingPage':'Keyword landing page'},
        inplace=True)
    project.save_data(file_name = file,data = df.to_csv(index=False))
print('done')


# In[40]:


df.sum()


# # KPIF

# In[41]:


# Business CalPERS EL FEDS KPIF MDCR Medicaid Thrive Tricare VivaBien
lobReport = 'KPIF'

# Business=21700000001745077;
# CalPERS=21700000001745080;
# EL=21700000001719683;
# FEDs=21700000001745071;
# KPIF=21700000001739091;
# MDCR=21700000001745674;
# Medicaid=21700000001747385;
# Thrive=21700000001745083;
# Tricare=21700000001745086;
# VivaBien=21700000001745089;

if lobReport == 'Business':
    av_id = '21700000001745077'
elif lobReport == 'CalPERS':
    av_id = '21700000001745080'
elif lobReport == 'EL':
    av_id = '21700000001719683'
elif lobReport == 'FEDS':
    av_id = '21700000001745071'
elif lobReport == 'KPIF':
    av_id = '21700000001739091'
elif lobReport == 'MDCR':
    av_id = '21700000001745674'
elif lobReport == 'Medicaid':    
    av_id = '21700000001747385'
elif lobReport == 'Thrive':    
    av_id = '21700000001745083'
elif lobReport == 'Tricare':    
    av_id = '21700000001745086'
elif lobReport == 'VivaBien':    
    av_id = '21700000001745089'
    
print('{}: {}'.format(lobReport,av_id))

# Building report request

body={
    "reportScope": {
        "agencyId": "20700000001328135", #// Replace with your ID
        "advertiserId": av_id, #// Replace with your ID
#             "engineAccountId": "700000000073991" // Replace with your ID
        },
    "reportType": "keyword",
    "columns": [
        
        { "columnName": "date" },
        { "columnName": "account" },
        { "columnName": "campaign" },
        { "columnName": "adGroup" },
        { "columnName": "keywordText" },
        { "columnName": "keywordMatchType" },
        { "columnName": "keywordMaxCpc" },
        { "columnName": "impr" },
        { "columnName": "clicks" },
        { "columnName": "cost" },
        { "columnName": "qualityScoreAvg" },
        
        # KPIF SMU: app complete (event464) Conv.
        { "savedColumnName": "KP_KPIF_HistoricBackfill_smuappcomplete(event464)Conv_Counter_Standard", "platformSource": "floodlight" },
        { "savedColumnName": "KP_KPIF_AdobeAnalytics_SMUApplications_Counter_Standard", "platformSource": "floodlight" },
        
        # KPIF Weighted Apply on HIX (event369)
    
        { "savedColumnName": "KP_KPIF_AdobeAnalytics_ClickstoHIX_Counter_Standard", "platformSource": "floodlight" },
        { "savedColumnName": "KP_KPIF_HistoricBackfill_KPIFDSTClicktoHIXConvWeightedRevenue_.2_Counter_Standard", "platformSource": "floodlight" },
        { "savedColumnName": "KP_KPIF_HistoricBackfill_KPIFDSTClicktoHIXConvWeightedRevenue_.3_Counter_Standard", "platformSource": "floodlight" },
        { "savedColumnName": "KP_KPIF_HistoricBackfill_KPIFDSTClicktoHIXConvWeightedRevenue_.4_Counter_Standard", "platformSource": "floodlight" },
        { "savedColumnName": "KP_KPIF_HistoricBackfill_KPIFDSTClicktoHIXConvWeightedRevenue_.5_Counter_Standard", "platformSource": "floodlight" },
        
        # KPIF Quotes Completed (event 290)
        { "savedColumnName": "KP_KPIF_AdobeAnalytics_QuotesCompleted_Counter_Standard - Inno", "platformSource": "floodlight" },
        { "savedColumnName": "KP_KPIF_HistoricBackfill_QuotesCompleted(event290)Conv_Counter_Standard", "platformSource": "floodlight" },
        
        #KPIF Apply on KP (event368)
        { "savedColumnName": "KP_KPIF_AdobeAnalytics_ApplyonKP_Counter_Standard - Inno", "platformSource": "floodlight" },
        
        
        # KPIF Application
#         { "savedColumnName": "KP_KPIF_HistoricBackfill_smuappcomplete(event464)Conv_Counter_Standard", "platformSource": "floodlight" },
        { "savedColumnName": "KP_KPIF_HistoricBackfill_2014ApplyNowCompletedNon-SAConv_Counter_Standard - MOps", "platformSource": "floodlight" },
#         { "savedColumnName": "KP_KPIF_HistoricBackfill_KPIFDSTClicktoHIXConvWeightedRevenue_.2_Counter_Standard", "platformSource": "floodlight" },
#         { "savedColumnName": "KP_KPIF_HistoricBackfill_KPIFDSTClicktoHIXConvWeightedRevenue_.3_Counter_Standard", "platformSource": "floodlight" },
#         { "savedColumnName": "KP_KPIF_HistoricBackfill_KPIFDSTClicktoHIXConvWeightedRevenue_.4_Counter_Standard", "platformSource": "floodlight" },
#         { "savedColumnName": "KP_KPIF_HistoricBackfill_KPIFDSTClicktoHIXConvWeightedRevenue_.5_Counter_Standard", "platformSource": "floodlight" },
        { "savedColumnName": "KP_KPIF_HistoricBackfill_KPIFDSTClickstoSMUConv_NBPK.1_Counter_Standard", "platformSource": "floodlight" },
        { "savedColumnName": "KP_KPIF_HistoricBackfill_KPIFDSTClickstoSMUConv_RLSA.2_Counter_Standard", "platformSource": "floodlight" },
        { "savedColumnName": "KP_KPIF_HistoricBackfill_KPIFDSTClickstoSMUConv_BPK.3_Counter_Standard", "platformSource": "floodlight" },
        { "savedColumnName": "KP_KPIF_HistoricBackfill_KPIFDSTClickstoSMUConv_NBPK.2_Counter_Standard", "platformSource": "floodlight" },
        { "savedColumnName": "KP_KPIF_HistoricBackfill_KPIFDSTClickstoSMUConv_RLSA.3_Counter_Standard", "platformSource": "floodlight" },
        { "savedColumnName": "KP_KPIF_HistoricBackfill_KPIFDSTClickstoSMUConv_BPK.4_Counter_Standard", "platformSource": "floodlight" },
        { "savedColumnName": "KP_KPIF_HistoricBackfill_KPIFDSTClickstoSMUConv_NBPK.3_Counter_Standard", "platformSource": "floodlight" },
        { "savedColumnName": "KP_KPIF_HistoricBackfill_KPIFDSTClickstoSMUConv_RLSA.4_Counter_Standard", "platformSource": "floodlight" },
        { "savedColumnName": "KP_KPIF_HistoricBackfill_KPIFDSTClickstoSMUConv_BPK.3_11/1/19 - 11/30/19_Counter_Standard", "platformSource": "floodlight" },
#         { "savedColumnName": "KP_KPIF_AdobeAnalytics_ClickstoHIX_Counter_Standard", "platformSource": "floodlight" },
#         { "savedColumnName": "KP_KPIF_AdobeAnalytics_SMUApplications_Counter_Standard", "platformSource": "floodlight" },
        { "savedColumnName": "KP_KPIF_AdobeAnalytics_SMUApplications-NoPayment_Counter_Standard - Inno", "platformSource": "floodlight" },

        


#         # b2b
#         { "columnName": "keywordText" },
#         { "columnName": "adGroup" },
#         { "columnName": "campaign" },
#         { "columnName": "keywordMatchType" },
#         { "columnName": "date" },
#         { "columnName": "cost" },
#         { "columnName": "impr" },
#         { "columnName": "clicks" },
#         { "columnName": "qualityScoreAvg" },
        
#         { "savedColumnName": "Business Actions (New)", "platformSource": "floodlight" },
#         { "savedColumnName": "Business Leads", "platformSource": "floodlight" },
#         { "savedColumnName": "Shop", "platformSource": "floodlight" },
#         { "savedColumnName": "Learn", "platformSource": "floodlight" },
#         { "savedColumnName": "B2B Contact Us Thank You Page", "platformSource": "floodlight" },
#         { "savedColumnName": "Get a Quote Thank You Page", "platformSource": "floodlight" },
#         { "savedColumnName": "SSQ Start Button Clicks", "platformSource": "floodlight" },
#         { "savedColumnName": "Web Lead", "platformSource": "floodlight" },
#         { "savedColumnName": "Download ebook [First Timer] TY Page", "platformSource": "floodlight" },
        
        
        
        { "columnName": "keywordLandingPage" },
        
        
      ],
      "timeRange" : {
        "startDate" : start_date,
        "endDate" : end_date
      },
          "filters": [
            {
              "column" : { "columnName": "impr" },
              "operator" : "greaterThan",
              "values" : [
                0
              ]
            }
          ],
      "downloadFormat": "csv",
      "maxRowsPerFile": 6000000,
      "statisticsCurrency": "agency",
      "verifySingleTimeZone": "false",
      "includeRemovedEntities": "false"
    }
# print(body)

request = service.reports().request(body = body)
request.execute()

request = generate_report(service, body)
with open(r'log\report-{}.json'.format(request['id']),'w') as f:
    f.write(str(request))
print('The id for the request is: {}'.format(request['id']))
print('Is Report Ready?: {}'.format(request['isReportReady']))
print

request_id = request['id']

filepath = ''
poll_report(service,request_id ,filepath = filepath) # with custom metrics


# In[42]:


import glob
filename = glob.glob('{}*'.format(lobReport))
print(filename)
for file in filename:
    df = pd.read_csv(file)
    df.rename(columns={
        'keywordText':'Keyword',
        'adGroup':'Ad group',
        'campaign':'Campaign',
        'keywordMatchType':'Match Type',
        'date':'Date',
        'cost':'Cost',
        'impr':'Impr',
        'clicks':'Clicks',
        'qualityScoreAvg':'Quality score (avg)',
        'keywordLandingPage':'Keyword landing page'},
        inplace=True)

    
    df['KPIF SMU: app complete (event464) Conv.']= \
    df['KP_KPIF_HistoricBackfill_smuappcomplete(event464)Conv_Counter_Standard'] + \
    df['KP_KPIF_AdobeAnalytics_SMUApplications_Counter_Standard']

    df['KPIF Weighted Apply on HIX (event369)']= \
    df['KP_KPIF_AdobeAnalytics_ClickstoHIX_Counter_Standard'] + \
    (df['KP_KPIF_HistoricBackfill_KPIFDSTClicktoHIXConvWeightedRevenue_.2_Counter_Standard'] *0.2) + \
    (df['KP_KPIF_HistoricBackfill_KPIFDSTClicktoHIXConvWeightedRevenue_.3_Counter_Standard'] *0.3) + \
    (df['KP_KPIF_HistoricBackfill_KPIFDSTClicktoHIXConvWeightedRevenue_.4_Counter_Standard'] *0.4) + \
    (df['KP_KPIF_HistoricBackfill_KPIFDSTClicktoHIXConvWeightedRevenue_.5_Counter_Standard'] *0.5)

    df['KPIF Quotes Completed (event 290)']= \
    df['KP_KPIF_AdobeAnalytics_QuotesCompleted_Counter_Standard - Inno'] + \
    df['KP_KPIF_HistoricBackfill_QuotesCompleted(event290)Conv_Counter_Standard']

    df['KPIF Apply on KP (event368)']= \
    df['KP_KPIF_AdobeAnalytics_ApplyonKP_Counter_Standard - Inno']

    df['KPIF Applications']= \
    df['KP_KPIF_HistoricBackfill_smuappcomplete(event464)Conv_Counter_Standard'] + \
    df['KP_KPIF_HistoricBackfill_2014ApplyNowCompletedNon-SAConv_Counter_Standard - MOps'] + \
    (df['KP_KPIF_HistoricBackfill_KPIFDSTClicktoHIXConvWeightedRevenue_.2_Counter_Standard'] *0.2) + \
    (df['KP_KPIF_HistoricBackfill_KPIFDSTClicktoHIXConvWeightedRevenue_.3_Counter_Standard'] *0.3) + \
    (df['KP_KPIF_HistoricBackfill_KPIFDSTClicktoHIXConvWeightedRevenue_.4_Counter_Standard'] *0.4) + \
    (df['KP_KPIF_HistoricBackfill_KPIFDSTClicktoHIXConvWeightedRevenue_.5_Counter_Standard'] *0.5) + \
    (df['KP_KPIF_HistoricBackfill_KPIFDSTClickstoSMUConv_NBPK.1_Counter_Standard'] *0.1) + \
    (df['KP_KPIF_HistoricBackfill_KPIFDSTClickstoSMUConv_RLSA.2_Counter_Standard'] *0.2) + \
    (df['KP_KPIF_HistoricBackfill_KPIFDSTClickstoSMUConv_BPK.3_Counter_Standard'] *0.3) + \
    (df['KP_KPIF_HistoricBackfill_KPIFDSTClickstoSMUConv_NBPK.2_Counter_Standard'] *0.2) + \
    (df['KP_KPIF_HistoricBackfill_KPIFDSTClickstoSMUConv_RLSA.3_Counter_Standard'] *0.3) + \
    (df['KP_KPIF_HistoricBackfill_KPIFDSTClickstoSMUConv_BPK.4_Counter_Standard'] *0.4) + \
    (df['KP_KPIF_HistoricBackfill_KPIFDSTClickstoSMUConv_NBPK.3_Counter_Standard'] *0.3) + \
    (df['KP_KPIF_HistoricBackfill_KPIFDSTClickstoSMUConv_RLSA.4_Counter_Standard'] *0.4) + \
    (df['KP_KPIF_HistoricBackfill_KPIFDSTClickstoSMUConv_BPK.3_11/1/19 - 11/30/19_Counter_Standard'] *0.3) + \
    (df['KP_KPIF_AdobeAnalytics_ClickstoHIX_Counter_Standard'] *0.2) + \
    df['KP_KPIF_AdobeAnalytics_SMUApplications_Counter_Standard'] + \
    df['KP_KPIF_AdobeAnalytics_SMUApplications-NoPayment_Counter_Standard - Inno']
    
    df = df[['Date', 'account', 'Campaign', 'Ad group', 'Keyword', 'Match Type',
               'keywordMaxCpc', 'Impr', 'Clicks', 'Cost', 'Quality score (avg)',
               'Keyword landing page', 'KPIF SMU: app complete (event464) Conv.',
               'KPIF Weighted Apply on HIX (event369)',
               'KPIF Quotes Completed (event 290)', 'KPIF Apply on KP (event368)',
               'KPIF Applications']]
    project.save_data(file_name = file,data = df.to_csv(index=False))
    
    


# In[43]:


df.sum()


# # EL

# In[44]:


# Business CalPERS EL FEDS KPIF MDCR Medicaid Thrive Tricare VivaBien
lobReport = 'EL'

# Business=21700000001745077;
# CalPERS=21700000001745080;
# EL=21700000001719683;
# FEDs=21700000001745071;
# KPIF=21700000001739091;
# MDCR=21700000001745674;
# Medicaid=21700000001747385;
# Thrive=21700000001745083;
# Tricare=21700000001745086;
# VivaBien=21700000001745089;

if lobReport == 'Business':
    av_id = '21700000001745077'
elif lobReport == 'CalPERS':
    av_id = '21700000001745080'
elif lobReport == 'EL':
    av_id = '21700000001719683'
elif lobReport == 'FEDS':
    av_id = '21700000001745071'
elif lobReport == 'KPIF':
    av_id = '21700000001739091'
elif lobReport == 'MDCR':
    av_id = '21700000001745674'
elif lobReport == 'Medicaid':    
    av_id = '21700000001747385'
elif lobReport == 'Thrive':    
    av_id = '21700000001745083'
elif lobReport == 'Tricare':    
    av_id = '21700000001745086'
elif lobReport == 'VivaBien':    
    av_id = '21700000001745089'
    
print('{}: {}'.format(lobReport,av_id))

# Building report request

body={
    "reportScope": {
        "agencyId": "20700000001328135", #// Replace with your ID
        "advertiserId": av_id, #// Replace with your ID
#             "engineAccountId": "700000000073991" // Replace with your ID
        },
    "reportType": "keyword",
    "columns": [
        
        { "columnName": "date" },
        { "columnName": "account" },
        { "columnName": "campaign" },
        { "columnName": "adGroup" },
        { "columnName": "keywordText" },
        { "columnName": "keywordMatchType" },
        { "columnName": "keywordMaxCpc" },
        { "columnName": "impr" },
        { "columnName": "clicks" },
        { "columnName": "cost" },
        { "columnName": "qualityScoreAvg" },
        
        {"savedColumnName": "KP_EL_HistoricBackfill_smuappcomplete(event464)Conv_Counter_Standard", "platformSource": "floodlight"},
        {"savedColumnName": "KP_EL_AdobeAnalytics_SMUApplications_Counter_Standard", "platformSource": "floodlight"},
        
#         {"savedColumnName": "KPIF Weighted Apply on HIX (event369)", "platformSource": "floodlight"},
        {"savedColumnName": "KP_EL_AdobeAnalytics_ClickstoHIX_Counter_Standard", "platformSource": "floodlight"},
        {"savedColumnName": "KP_EL_HistoricBackfill_KPIFDSTClicktoHIXConvWeightedRevenue_.2_Counter_Standard", "platformSource": "floodlight"},
        {"savedColumnName": "KP_EL_HistoricBackfill_KPIFDSTClicktoHIXConvWeightedRevenue_.3_Counter_Standard", "platformSource": "floodlight"},
        {"savedColumnName": "KP_EL_HistoricBackfill_KPIFDSTClicktoHIXConvWeightedRevenue_.4_Counter_Standard", "platformSource": "floodlight"},
        {"savedColumnName": "KP_EL_HistoricBackfill_KPIFDSTClicktoHIXConvWeightedRevenue_.5_Counter_Standard", "platformSource": "floodlight"},
        
#         {"savedColumnName": "KPIF Quotes Completed (event 290)", "platformSource": "floodlight"},
        {"savedColumnName": "KP_EL_HistoricBackfill_QuotesCompleted(event290)Conv_Counter_Standard", "platformSource": "floodlight"},
        {"savedColumnName": "KP_EL_AdobeAnalytics_QuotesCompleted_Counter_Standard - Inno", "platformSource": "floodlight"},
        
#         {"savedColumnName": "KPIF Apply on KP (event368)", "platformSource": "floodlight"},
        {"savedColumnName": "KP_EL_AdobeAnalytics_ApplyonKP_Counter_Standard - Inno", "platformSource": "floodlight"},
        
#         {"savedColumnName": "Medicare Applications", "platformSource": "floodlight"},
        {"savedColumnName": "KP_EL_HistoricBackfill_MedicareEnrollmentCompletionConv_Counter_Standard (elmecost)", "platformSource": "floodlight"},
        {"savedColumnName": "KP_EL_MDCR_MNET-Enrollments_Counter_Standard - Inno", "platformSource": "floodlight"},
        {"savedColumnName": "KP_EL_MDCR_MNET-MICROSITE-Aggregation_Counter_Standard (elmdagcs)", "platformSource": "floodlight"},
        
#         {"savedColumnName": "KPIF Applications", "platformSource": "floodlight"},
#         {"savedColumnName": "KP_EL_HistoricBackfill_smuappcomplete(event464)Conv_Counter_Standard", "platformSource": "floodlight"},
#         {"savedColumnName": "KP_EL_HistoricBackfill_KPIFDSTClicktoHIXConvWeightedRevenue_.2_Counter_Standard", "platformSource": "floodlight"},
#         {"savedColumnName": "KP_EL_HistoricBackfill_KPIFDSTClicktoHIXConvWeightedRevenue_.3_Counter_Standard", "platformSource": "floodlight"},
#         {"savedColumnName": "KP_EL_HistoricBackfill_KPIFDSTClicktoHIXConvWeightedRevenue_.4_Counter_Standard", "platformSource": "floodlight"},
#         {"savedColumnName": "KP_EL_HistoricBackfill_KPIFDSTClicktoHIXConvWeightedRevenue_.5_Counter_Standard", "platformSource": "floodlight"},
        {"savedColumnName": "KP_EL_HistoricBackfill_KPIFDSTClickstoSMUConv_BPU.16_Counter_Standard", "platformSource": "floodlight"},
        {"savedColumnName": "KP_EL_HistoricBackfill_KPIFDSTClickstoSMUConv_NBPU.11_Counter_Standard", "platformSource": "floodlight"},
        {"savedColumnName": "KP_EL_HistoricBackfill_KPIFDSTClickstoSMUConv_BPU.3_Counter_Standard", "platformSource": "floodlight"},
        {"savedColumnName": "KP_EL_HistoricBackfill_KPIFDSTClickstoSMUConv_NBPU.2_Counter_Standard", "platformSource": "floodlight"},
        {"savedColumnName": "KP_EL_HistoricBackfill_KPIFDSTClickstoSMUConv_BPU.4_Counter_Standard", "platformSource": "floodlight"},
        {"savedColumnName": "KP_EL_HistoricBackfill_KPIFDSTClickstoSMUConv_NBPU.3_Counter_Standard", "platformSource": "floodlight"},
        {"savedColumnName": "KP_EL_HistoricBackfill_KPIFApplicationCompletionConv_Counter_Standard", "platformSource": "floodlight"},
#         {"savedColumnName": "KP_EL_AdobeAnalytics_ClickstoHIX_Counter_Standard", "platformSource": "floodlight"},
#         {"savedColumnName": "KP_EL_AdobeAnalytics_SMUApplications_Counter_Standard", "platformSource": "floodlight"},
        {"savedColumnName": "KP_EL_AdobeAnalytics_SMUApplications-NoPayment_Counter_Standard", "platformSource": "floodlight"},
#         {"savedColumnName": "Thrive Actions", "platformSource": "floodlight"},
        {"savedColumnName": "KP_EL_HistoricBackfill_ThriveShoppingActions_Counter_Standard-Inno", "platformSource": "floodlight"},
        {"savedColumnName": "KP_EL_HistoricBackfill_ThriveLearningActions_Counter_Standard-Inno", "platformSource": "floodlight"},
        {"savedColumnName": "KP_EL_BrandConversions_Counter_Standard", "platformSource": "floodlight"},
        
        

        {"savedColumnName": "B2B Actions - GA View Update", "platformSource": "floodlight"},
        
        { "savedColumnName": "CA B2B Leads - GA View Update", "platformSource": "floodlight" },
        
        {"savedColumnName": "Convert Submit Contact - GA View Update", "platformSource": "floodlight"}, 
                
        {"savedColumnName": "Convert Submit Quote - GA View Update", "platformSource": "floodlight"},     
        {"savedColumnName": "Convert Non Submit SSQ - GA  View Update", "platformSource": "floodlight"},
#         {"savedColumnName": "B2BL MAS Leads - GA View Update", "platformSource": "floodlight"},       
        


        
        { "savedColumnName": "SB MAS Leads - GA View Update", "platformSource": "floodlight" },
        
#         {"savedColumnName": "B2B Actions", "platformSource": "floodlight"},
#         {"savedColumnName": "B2B Actions - Historic", "platformSource": "floodlight"},
        
#         {"savedColumnName": "B2B Leads", "platformSource": "floodlight"},
#         {"savedColumnName": "B2B Leads - Historic", "platformSource": "floodlight"},

        


#         # b2b
#         { "columnName": "keywordText" },
#         { "columnName": "adGroup" },
#         { "columnName": "campaign" },
#         { "columnName": "keywordMatchType" },
#         { "columnName": "date" },
#         { "columnName": "cost" },
#         { "columnName": "impr" },
#         { "columnName": "clicks" },
#         { "columnName": "qualityScoreAvg" },
        
#         { "savedColumnName": "Business Actions (New)", "platformSource": "floodlight" },
#         { "savedColumnName": "Business Leads", "platformSource": "floodlight" },
#         { "savedColumnName": "Shop", "platformSource": "floodlight" },
#         { "savedColumnName": "Learn", "platformSource": "floodlight" },
#         { "savedColumnName": "B2B Contact Us Thank You Page", "platformSource": "floodlight" },
#         { "savedColumnName": "Get a Quote Thank You Page", "platformSource": "floodlight" },
#         { "savedColumnName": "SSQ Start Button Clicks", "platformSource": "floodlight" },
#         { "savedColumnName": "Web Lead", "platformSource": "floodlight" },
#         { "savedColumnName": "Download ebook [First Timer] TY Page", "platformSource": "floodlight" },
        
        
        
        { "columnName": "keywordLandingPage" },
        
        
      ],
      "timeRange" : {
        "startDate" : start_date,
        "endDate" : end_date
      },
          "filters": [
            {
              "column" : { "columnName": "impr" },
              "operator" : "greaterThan",
              "values" : [
                0
              ]
            }
          ],
      "downloadFormat": "csv",
      "maxRowsPerFile": 6000000,
      "statisticsCurrency": "agency",
      "verifySingleTimeZone": "false",
      "includeRemovedEntities": "false"
    }
# print(body)

request = service.reports().request(body = body)
request.execute()

request = generate_report(service, body)
with open(r'log\report-{}.json'.format(request['id']),'w') as f:
    f.write(str(request))
print('The id for the request is: {}'.format(request['id']))
print('Is Report Ready?: {}'.format(request['isReportReady']))
print

request_id = request['id']

filepath = ''
poll_report(service,request_id ,filepath = filepath) # with custom metrics


# In[45]:


import glob
filename = glob.glob('{}*'.format(lobReport))
print(filename)
for file in filename:
    df = pd.read_csv(file)
    df.rename(columns={
        'keywordText':'Keyword',
        'adGroup':'Ad group',
        'campaign':'Campaign',
        'keywordMatchType':'Match Type',
        'date':'Date',
        'cost':'Cost',
        'impr':'Impr',
        'clicks':'Clicks',
        'qualityScoreAvg':'Quality score (avg)',
        'keywordLandingPage':'Keyword landing page'},
        inplace=True)

    
    df['KPIF SMU: app complete (event464) Conv.']= \
    df['KP_EL_HistoricBackfill_smuappcomplete(event464)Conv_Counter_Standard'] + \
    df['KP_EL_AdobeAnalytics_SMUApplications_Counter_Standard']

    df['KPIF Weighted Apply on HIX (event369)']= \
    df['KP_EL_AdobeAnalytics_ClickstoHIX_Counter_Standard'] + \
    (df['KP_EL_HistoricBackfill_KPIFDSTClicktoHIXConvWeightedRevenue_.2_Counter_Standard'] *0.2) + \
    (df['KP_EL_HistoricBackfill_KPIFDSTClicktoHIXConvWeightedRevenue_.3_Counter_Standard'] * 0.3) + \
    (df['KP_EL_HistoricBackfill_KPIFDSTClicktoHIXConvWeightedRevenue_.4_Counter_Standard'] *0.4) + \
    (df['KP_EL_HistoricBackfill_KPIFDSTClicktoHIXConvWeightedRevenue_.5_Counter_Standard'] *0.5)


    df['KPIF Quotes Completed (event 290)']= \
    df['KP_EL_HistoricBackfill_QuotesCompleted(event290)Conv_Counter_Standard'] + \
    df['KP_EL_AdobeAnalytics_QuotesCompleted_Counter_Standard - Inno']

    df['KPIF Apply on KP (event368)']= \
    df['KP_EL_AdobeAnalytics_ApplyonKP_Counter_Standard - Inno']

    df['Medicare Applications']= \
    df['KP_EL_HistoricBackfill_MedicareEnrollmentCompletionConv_Counter_Standard (elmecost)']  + \
    df['KP_EL_MDCR_MNET-Enrollments_Counter_Standard - Inno'] + \
    df['KP_EL_MDCR_MNET-MICROSITE-Aggregation_Counter_Standard (elmdagcs)']

    df['KPIF Applications']= \
    df['KP_EL_HistoricBackfill_smuappcomplete(event464)Conv_Counter_Standard'] + \
    (df['KP_EL_HistoricBackfill_KPIFDSTClicktoHIXConvWeightedRevenue_.2_Counter_Standard'] *0.2) + \
    (df['KP_EL_HistoricBackfill_KPIFDSTClicktoHIXConvWeightedRevenue_.3_Counter_Standard'] * 0.3) + \
    (df['KP_EL_HistoricBackfill_KPIFDSTClicktoHIXConvWeightedRevenue_.4_Counter_Standard'] *0.4) + \
    (df['KP_EL_HistoricBackfill_KPIFDSTClicktoHIXConvWeightedRevenue_.5_Counter_Standard'] *0.5) + \
    (df['KP_EL_HistoricBackfill_KPIFDSTClickstoSMUConv_BPU.16_Counter_Standard'] *0.16) + \
    (df['KP_EL_HistoricBackfill_KPIFDSTClickstoSMUConv_NBPU.11_Counter_Standard'] *0.11) + \
    (df['KP_EL_HistoricBackfill_KPIFDSTClickstoSMUConv_BPU.3_Counter_Standard'] *0.3) + \
    (df['KP_EL_HistoricBackfill_KPIFDSTClickstoSMUConv_NBPU.2_Counter_Standard'] *0.2) + \
    (df['KP_EL_HistoricBackfill_KPIFDSTClickstoSMUConv_BPU.4_Counter_Standard'] *0.4) + \
    (df['KP_EL_HistoricBackfill_KPIFDSTClickstoSMUConv_NBPU.3_Counter_Standard'] *0.3) + \
    df['KP_EL_HistoricBackfill_KPIFApplicationCompletionConv_Counter_Standard'] + \
    (df['KP_EL_AdobeAnalytics_ClickstoHIX_Counter_Standard'] * 0.2) + \
    df['KP_EL_AdobeAnalytics_SMUApplications_Counter_Standard'] + \
    df['KP_EL_AdobeAnalytics_SMUApplications-NoPayment_Counter_Standard']

    df['Thrive Actions']= \
    df['KP_EL_HistoricBackfill_ThriveShoppingActions_Counter_Standard-Inno'] + \
    df['KP_EL_HistoricBackfill_ThriveLearningActions_Counter_Standard-Inno'] + \
    df['KP_EL_BrandConversions_Counter_Standard']

#     df['B2B Actions'] = \
#     df['B2B Actions'] + \
#     df['B2B Actions - Historic']

    # df['KP_EL_HistoricBackfill_B2BShoppingActionsConv_Counter_Standard'] + \
    # df['KP_EL_HistoricBackfill_B2BLearningActionsConv_Counter_Standard'] + \
    # GA Goal ID 7: Learn + \
    # GA Goal ID 8: Shop"

#     df['B2B Leads'] = \
#     df['B2B Leads']+ \
#     df['B2B Leads - Historic']


    # [KP_EL_HistoricBackfill_GetaQuoteThankYouPageConv_Counter_Standard] + \
    # [KP_EL_HistoricBackfill_B2BContactUsConv_Counter_Standard] + \
    # Goal 11: Download ebook [First Timer] TY Page + \
    # Goal ID 13: Get a Quote Thank You Page + \
    # Goal 12: SBU_Nurture_eBookDownloadSwitcher [Switcher] TY Page + \
    # Goal ID 1: B2B Contact Us Thank You Page"

    df.drop(columns=['KP_EL_HistoricBackfill_smuappcomplete(event464)Conv_Counter_Standard',
       'KP_EL_AdobeAnalytics_SMUApplications_Counter_Standard',
       'KP_EL_AdobeAnalytics_ClickstoHIX_Counter_Standard',
       'KP_EL_HistoricBackfill_KPIFDSTClicktoHIXConvWeightedRevenue_.2_Counter_Standard',
       'KP_EL_HistoricBackfill_KPIFDSTClicktoHIXConvWeightedRevenue_.3_Counter_Standard',
       'KP_EL_HistoricBackfill_KPIFDSTClicktoHIXConvWeightedRevenue_.4_Counter_Standard',
       'KP_EL_HistoricBackfill_KPIFDSTClicktoHIXConvWeightedRevenue_.5_Counter_Standard',
       'KP_EL_HistoricBackfill_QuotesCompleted(event290)Conv_Counter_Standard',
       'KP_EL_AdobeAnalytics_QuotesCompleted_Counter_Standard - Inno',
       'KP_EL_AdobeAnalytics_ApplyonKP_Counter_Standard - Inno',
       'KP_EL_HistoricBackfill_MedicareEnrollmentCompletionConv_Counter_Standard (elmecost)',
       'KP_EL_MDCR_MNET-Enrollments_Counter_Standard - Inno',
       'KP_EL_MDCR_MNET-MICROSITE-Aggregation_Counter_Standard (elmdagcs)',
       'KP_EL_HistoricBackfill_KPIFDSTClickstoSMUConv_BPU.16_Counter_Standard',
       'KP_EL_HistoricBackfill_KPIFDSTClickstoSMUConv_NBPU.11_Counter_Standard',
       'KP_EL_HistoricBackfill_KPIFDSTClickstoSMUConv_BPU.3_Counter_Standard',
       'KP_EL_HistoricBackfill_KPIFDSTClickstoSMUConv_NBPU.2_Counter_Standard',
       'KP_EL_HistoricBackfill_KPIFDSTClickstoSMUConv_BPU.4_Counter_Standard',
       'KP_EL_HistoricBackfill_KPIFDSTClickstoSMUConv_NBPU.3_Counter_Standard',
       'KP_EL_HistoricBackfill_KPIFApplicationCompletionConv_Counter_Standard',
       'KP_EL_AdobeAnalytics_SMUApplications-NoPayment_Counter_Standard',
       'KP_EL_HistoricBackfill_ThriveShoppingActions_Counter_Standard-Inno',
       'KP_EL_HistoricBackfill_ThriveLearningActions_Counter_Standard-Inno',
       'KP_EL_BrandConversions_Counter_Standard', 
#        'B2B Actions - Historic',  'B2B Leads - Historic',
                    ],inplace=True)
#     df = df[['from', 'account', 'Campaign', 'Ad group', 'Keyword', 'Match Type',
#                'keywordMaxCpc', 'Impr', 'Clicks', 'Cost', 'Quality score (avg)',
#                'Keyword landing page', 'KPIF SMU: app complete (event464) Conv.',
#                'KPIF Weighted Apply on HIX (event369)',
#                'KPIF Quotes Completed (event 290)', 'KPIF Apply on KP (event368)',
#                'KPIF Applications']]
    project.save_data(file_name = file,data = df.to_csv(index=False))
    
    


# In[ ]:





# In[46]:


sorted(df['Date'].unique())


# # FEDS

# In[47]:


# Business CalPERS EL FEDS KPIF MDCR Medicaid Thrive Tricare VivaBien
lobReport = 'FEDS'

# Business=21700000001745077;
# CalPERS=21700000001745080;
# EL=21700000001719683;
# FEDs=21700000001745071;
# KPIF=21700000001739091;
# MDCR=21700000001745674;
# Medicaid=21700000001747385;
# Thrive=21700000001745083;
# Tricare=21700000001745086;
# VivaBien=21700000001745089;

if lobReport == 'Business':
    av_id = '21700000001745077'
elif lobReport == 'CalPERS':
    av_id = '21700000001745080'
elif lobReport == 'EL':
    av_id = '21700000001719683'
elif lobReport == 'FEDS':
    av_id = '21700000001745071'
elif lobReport == 'KPIF':
    av_id = '21700000001739091'
elif lobReport == 'MDCR':
    av_id = '21700000001745674'
elif lobReport == 'Medicaid':    
    av_id = '21700000001747385'
elif lobReport == 'Thrive':    
    av_id = '21700000001745083'
elif lobReport == 'Tricare':    
    av_id = '21700000001745086'
elif lobReport == 'VivaBien':    
    av_id = '21700000001745089'
    
print('{}: {}'.format(lobReport,av_id))

# Building report request

body={
    "reportScope": {
        "agencyId": "20700000001328135", #// Replace with your ID
        "advertiserId": av_id, #// Replace with your ID
#             "engineAccountId": "700000000073991" // Replace with your ID
        },
    "reportType": "keyword",
    "columns": [
        
        { "columnName": "date" },
        { "columnName": "account" },
        { "columnName": "campaign" },
        { "columnName": "adGroup" },
        { "columnName": "keywordText" },
        { "columnName": "keywordMatchType" },
        { "columnName": "keywordMaxCpc" },
        { "columnName": "impr" },
        { "columnName": "clicks" },
        { "columnName": "cost" },
        { "columnName": "qualityScoreAvg" },
        
        {"savedColumnName": "Aggregate FEDs GA Conversions", "platformSource": "floodlight"},
        


#         # b2b
#         { "columnName": "keywordText" },
#         { "columnName": "adGroup" },
#         { "columnName": "campaign" },
#         { "columnName": "keywordMatchType" },
#         { "columnName": "date" },
#         { "columnName": "cost" },
#         { "columnName": "impr" },
#         { "columnName": "clicks" },
#         { "columnName": "qualityScoreAvg" },
        
#         { "savedColumnName": "Business Actions (New)", "platformSource": "floodlight" },
#         { "savedColumnName": "Business Leads", "platformSource": "floodlight" },
#         { "savedColumnName": "Shop", "platformSource": "floodlight" },
#         { "savedColumnName": "Learn", "platformSource": "floodlight" },
#         { "savedColumnName": "B2B Contact Us Thank You Page", "platformSource": "floodlight" },
#         { "savedColumnName": "Get a Quote Thank You Page", "platformSource": "floodlight" },
#         { "savedColumnName": "SSQ Start Button Clicks", "platformSource": "floodlight" },
#         { "savedColumnName": "Web Lead", "platformSource": "floodlight" },
#         { "savedColumnName": "Download ebook [First Timer] TY Page", "platformSource": "floodlight" },
        
        
        
        { "columnName": "keywordLandingPage" },
        
        
      ],
      "timeRange" : {
        "startDate" : start_date,
        "endDate" : end_date
      },
          "filters": [
            {
              "column" : { "columnName": "impr" },
              "operator" : "greaterThan",
              "values" : [
                0
              ]
            }
          ],
      "downloadFormat": "csv",
      "maxRowsPerFile": 6000000,
      "statisticsCurrency": "agency",
      "verifySingleTimeZone": "false",
      "includeRemovedEntities": "false"
    }
# print(body)

request = service.reports().request(body = body)
request.execute()

request = generate_report(service, body)
with open(r'log\report-{}.json'.format(request['id']),'w') as f:
    f.write(str(request))
print('The id for the request is: {}'.format(request['id']))
print('Is Report Ready?: {}'.format(request['isReportReady']))

request_id = request['id']

filepath = ''
poll_report(service,request_id ,filepath = filepath) # with custom metrics

import glob
filename = glob.glob('{}*'.format(lobReport))
print(filename)
for file in filename:
    df = pd.read_csv(file)
    df.rename(columns={
        'keywordText':'Keyword',
        'adGroup':'Ad group',
        'campaign':'Campaign',
        'keywordMatchType':'Match Type',
        'date':'Date',
        'cost':'Cost',
        'impr':'Impr',
        'clicks':'Clicks',
        'qualityScoreAvg':'Quality score (avg)',
        'keywordLandingPage':'Keyword landing page',
        'Aggregate FEDs GA Conversions':'Feds Actions'},inplace=True)


    project.save_data(file_name = file,data = df.to_csv(index=False))


# In[48]:


df.sum()


# # Brand

# In[49]:


lobReport = 'Thrive'

if lobReport == 'Business':
    av_id = '21700000001745077'
elif lobReport == 'CalPERS':
    av_id = '21700000001745080'
elif lobReport == 'EL':
    av_id = '21700000001719683'
elif lobReport == 'FEDS':
    av_id = '21700000001745071'
elif lobReport == 'KPIF':
    av_id = '21700000001739091'
elif lobReport == 'MDCR':
    av_id = '21700000001745674'
elif lobReport == 'Medicaid':    
    av_id = '21700000001747385'
elif lobReport == 'Thrive':    
    av_id = '21700000001745083'
elif lobReport == 'Tricare':    
    av_id = '21700000001745086'
elif lobReport == 'VivaBien':    
    av_id = '21700000001745089'
    
print('{}: {}'.format(lobReport,av_id))

# Building report request

body={
    "reportScope": {
        "agencyId": "20700000001328135", #// Replace with your ID
        "advertiserId": av_id, #// Replace with your ID
#             "engineAccountId": "700000000073991" // Replace with your ID
        },
    "reportType": "keyword",
    "columns": [
        
        { "columnName": "date" },
        { "columnName": "account" },
        { "columnName": "campaign" },
        { "columnName": "adGroup" },
        { "columnName": "keywordText" },
        { "columnName": "keywordMatchType" },
        { "columnName": "keywordMaxCpc" },
        { "columnName": "impr" },
        { "columnName": "clicks" },
        { "columnName": "cost" },
        { "columnName": "qualityScoreAvg" },
        
        {"savedColumnName": "THRV Total Actions", "platformSource": "floodlight"},
        
#         {}"savedColumnName": "VVBN Total Actions", "platformSource": "floodlight"},
            
        { "columnName": "keywordLandingPage" },
        
        
      ],
      "timeRange" : {
        "startDate" : start_date,
        "endDate" : end_date
      },
          "filters": [
            {
              "column" : { "columnName": "impr" },
              "operator" : "greaterThan",
              "values" : [
                0
              ]
            }
          ],
      "downloadFormat": "csv",
      "maxRowsPerFile": 6000000,
      "statisticsCurrency": "agency",
      "verifySingleTimeZone": "false",
      "includeRemovedEntities": "false"
    }
# print(body)

request = service.reports().request(body = body)
request.execute()

request = generate_report(service, body)
with open(r'log\report-{}.json'.format(request['id']),'w') as f:
    f.write(str(request))
print('The id for the request is: {}'.format(request['id']))
print('Is Report Ready?: {}'.format(request['isReportReady']))

request_id = request['id']

filepath = ''
poll_report(service,request_id ,filepath = filepath) # with custom metrics

# FEDS


# Business CalPERS EL FEDS KPIF MDCR Medicaid Thrive Tricare VivaBien
lobReport = 'VivaBien'

if lobReport == 'Business':
    av_id = '21700000001745077'
elif lobReport == 'CalPERS':
    av_id = '21700000001745080'
elif lobReport == 'EL':
    av_id = '21700000001719683'
elif lobReport == 'FEDS':
    av_id = '21700000001745071'
elif lobReport == 'KPIF':
    av_id = '21700000001739091'
elif lobReport == 'MDCR':
    av_id = '21700000001745674'
elif lobReport == 'Medicaid':    
    av_id = '21700000001747385'
elif lobReport == 'Thrive':    
    av_id = '21700000001745083'
elif lobReport == 'Tricare':    
    av_id = '21700000001745086'
elif lobReport == 'VivaBien':    
    av_id = '21700000001745089'
    
print('{}: {}'.format(lobReport,av_id))

# Building report request

body={
    "reportScope": {
        "agencyId": "20700000001328135", #// Replace with your ID
        "advertiserId": av_id, #// Replace with your ID
#             "engineAccountId": "700000000073991" // Replace with your ID
        },
    "reportType": "keyword",
    "columns": [
        
        { "columnName": "date" },
        { "columnName": "account" },
        { "columnName": "campaign" },
        { "columnName": "adGroup" },
        { "columnName": "keywordText" },
        { "columnName": "keywordMatchType" },
        { "columnName": "keywordMaxCpc" },
        { "columnName": "impr" },
        { "columnName": "clicks" },
        { "columnName": "cost" },
        { "columnName": "qualityScoreAvg" },
        
#         {"savedColumnName": "THRV Total Actions", "platformSource": "floodlight"},
        
        {"savedColumnName": "VVBN Total Actions", "platformSource": "floodlight"},
           
        { "columnName": "keywordLandingPage" },
        
        
      ],
      "timeRange" : {
        "startDate" : start_date,
        "endDate" : end_date
      },
          "filters": [
            {
              "column" : { "columnName": "impr" },
              "operator" : "greaterThan",
              "values" : [
                0
              ]
            }
          ],
      "downloadFormat": "csv",
      "maxRowsPerFile": 6000000,
      "statisticsCurrency": "agency",
      "verifySingleTimeZone": "false",
      "includeRemovedEntities": "false"
    }
# print(body)

request = service.reports().request(body = body)
request.execute()

request = generate_report(service, body)
with open(r'log\report-{}.json'.format(request['id']),'w') as f:
    f.write(str(request))
print('The id for the request is: {}'.format(request['id']))
print('Is Report Ready?: {}'.format(request['isReportReady']))

request_id = request['id']

filepath = ''
poll_report(service,request_id ,filepath = filepath) # with custom metrics


# In[50]:


import glob
filename = [file for file in glob.glob('*') if 'Thrive' in file or 'VivaBien' in file]
print(filename)

df_list=[]

for file in filename:
    df = pd.read_csv(file)
    df.rename(columns={
        'keywordText':'Keyword',
        'adGroup':'Ad group',
        'campaign':'Campaign',
        'keywordMatchType':'Match Type',
        'date':'Date',
        'cost':'Cost',
        'impr':'Impr',
        'clicks':'Clicks',
        'qualityScoreAvg':'Quality score (avg)',
        'keywordLandingPage':'Keyword landing page',
        'Aggregate FEDs GA Conversions':'Feds Actions'},inplace=True)
    df_list.append(df)
    

df = pd.concat(df_list)

    
#     df = df[['from', 'account', 'Campaign', 'Ad group', 'Keyword', 'Match Type',
#                'keywordMaxCpc', 'Impr', 'Clicks', 'Cost', 'Quality score (avg)',
#                'Keyword landing page', 'KPIF SMU: app complete (event464) Conv.',
#                'KPIF Weighted Apply on HIX (event369)',
#                'KPIF Quotes Completed (event 290)', 'KPIF Apply on KP (event368)',
#                'KPIF Applications']]
project.save_data(file_name = 'Brand-report{}-{}-{}.csv'.format(start_date,end_date,request_id),data = df.to_csv(index=False))


# In[51]:


df.sum()


# In[ ]:





# In[ ]:




