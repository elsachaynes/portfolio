/****************************************************************************************************/
/*	Program Name: 		Get Google API Access Token.sas												*/
/*																									*/
/*	Date Created: 		Sept 22, 2020																*/
/*																									*/
/*  Created By:         Nydia Lopez & Elle Haynes, based on a SAS Dummy Blog article:               */
/*  https://blogs.sas.com/content/sasdummy/2017/04/14/using-sas-to-access-google-analytics-apis/    */
/*                                                                                                  */
/* 	Purpose:            Run this script either as a first-time set-up for the Google Analytics      */
/*                      Reporting API "b2b-better-way-api" or when the refresh-token expires.       */
/*                      Refresh-tokens also expire after 14 days of inactivity. After getting a new */
/*                      authorization code, run this script to save a new access-token/refresh-     */
/*                      token pair as token.json.                                                   */
/*                                                                                                  */
/* 	Inputs:             OAuth 2.0 clientid credentials have been saved (one-time) as                */
/*                      client_secret.json. You will also need to refresh the authorization code    */
/*                      using Step 1 instructions in the link above. Save the code given by         */
/*                      overwriting the "code" in client_secret.json.                               */
/* -------------------------------------------------------------------------------------------------*/	
/* 	Notes: 				The last time refreshed (3/30) needed to also refresh client secret.        */
/* -------------------------------------------------------------------------------------------------*/
/*  Date Modified:                                                                                  */
/*  Modified by: 																					*/
/*  Description: 																					*/
/****************************************************************************************************/

/* -------------------------------------------------------------------------------------------------*/
/* 	ALERT: THIS PROGRAM MUST BE RUN MANUALLY. NEVER RUN THE ENTIRE SCRIPT AT ONCE.					*/
/* -------------------------------------------------------------------------------------------------*/

/* -------------------------------------------------------------------------------------------------*/
/* 	Step 1: Get inputs from client_secret.json                                                      */
/* -------------------------------------------------------------------------------------------------*/

options noserror;

filename secret "/gpfsFS2/sasdata/adhoc/po/imca/digital/code/Access/client_secret.json";
libname secret json;
proc sql noprint;
   select client_id, client_secret into :client_id, :client_secret from secret.installed;
   select redirect_uris1 into :redirect_uri from secret.redirect_uris;
quit;

/* -------------------------------------------------------------------------------------------------*/
/* 	Step 2: Get authorization code by logging into Google with link in output						*/
/* -------------------------------------------------------------------------------------------------*/

***************Copy/paste the value of location into your browser**************;
%put https://accounts.google.com/o/oauth2/v2/auth?scope=https://www.googleapis.com/auth/doubleclicksearch https://www.googleapis.com/auth/analytics.readonly%str(&)redirect_uri=&redirect_uri.%str(&)response_type=code%str(&)client_id=&client_id.;

/* -------------------------------------------------------------------------------------------------*/
/*************************************** See instructions below *************************************/
/* -------------------------------------------------------------------------------------------------*/

%let new_code_given=; ********copy/paste the value given into new_code_given*********;

/* -------------------------------------------------------------------------------------------------*/
/* 	Step 3: Update access token in token.json with refreshed authorization code						*/
/* -------------------------------------------------------------------------------------------------*/

%let oauth2=https://www.googleapis.com/oauth2/v4/token;
filename token "/gpfsFS2/sasdata/adhoc/po/imca/digital/code/Access/token.json"; 
proc http
 	url="&oauth2.?client_id=&client_id.%str(&)code=&new_code_given.%str(&)client_secret=&client_secret.%str(&)redirect_uri=&redirect_uri.%str(&)grant_type=authorization_code%str(&)response_type=token"
 	method="POST"
 	out=token;
run;

/* NOTE: the refresh token and client-id/secret should be PROTECTED. */
/* Anyone who has access to these can get your GA data as if they    */
/* were you.     													 */


