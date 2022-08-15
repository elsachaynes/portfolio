/****************************************************************************************************/
/*  Program Name:       SAS_Macro_RefreshToken.sas                                                  */
/*                                                                                                  */
/*  Date Created:       Sept 29, 2020                                                               */
/*																									*/
/*  Created By:         Nydia Lopez & Elle Haynes, based on a SAS Dummy Blog article:               */
/*  https://blogs.sas.com/content/sasdummy/2017/04/14/using-sas-to-access-google-analytics-apis/    */
/*                                                                                                  */
/*  Purpose:            This macro exchanges inputs to gain temporary access to Google Analytics    */
/*                      and SA 360 data via API.                                                    */
/*                                                                                                  */
/*  Inputs:             This script exchanges OAuth 2.0 clientid credentials and refresh-token      */
/*                      for an access-token that lasts for 60 minutes. Credentials are stored in    */   			
/*                      client_secret.json and updated with "Get Google API Access.sas."            */
/*                                                                                                  */
/* -------------------------------------------------------------------------------------------------*/	
/*  Notes:              Add functionality to run "Get Google API Access.sas" when necessary.        */
/*                      Move to v4? See -->                                                         */
/*  https://developers.google.com/analytics/devguides/reporting/core/v4/rest/v4/reports/batchGet    */
/* -------------------------------------------------------------------------------------------------*/
/*  Date Modified:                                                                                  */
/*  Modified by:                                                                                    */
/*  Description:                                                                                    */
/****************************************************************************************************/

%macro refreshToken;

	/* -------------------------------------------------------------------------------------------------*/
	/*  Get inputs from client_secret.json                                                              */
	/* -------------------------------------------------------------------------------------------------*/	

	filename secret "/gpfsFS2/sasdata/adhoc/po/imca/digital/code/Access/client_secret.json";
	libname secret json;
	proc sql noprint;
	   select client_id, client_secret into :client_id, :client_secret from secret.installed;
	quit;

	/* -------------------------------------------------------------------------------------------------*/
	/*  Get inputs from token.json                                                                      */
	/* -------------------------------------------------------------------------------------------------*/

	filename atok "/gpfsFS2/sasdata/adhoc/po/imca/digital/code/Access/token.json";
	libname atok json;
	proc sql noprint;
	   select refresh_token into :refresh_token from atok.root;
	quit;

	/* -------------------------------------------------------------------------------------------------*/
	/*  Retrieve 60-minute access-token.                                                                */
	/* -------------------------------------------------------------------------------------------------*/

	%let oauth2=https://www.googleapis.com/oauth2/v4/token;

	filename rtoken temp;
	proc http
		method="POST"
		url="&oauth2.?client_id=&client_id.%str(&)client_secret=&client_secret.%str(&)grant_type=refresh_token%str(&)refresh_token=&refresh_token."
		out=rtoken;
	run;

	libname rtok json fileref=rtoken;
	data _null_;
		set rtok.root;
		call symputx('access_token',access_token);
	run;
	options nodate;
	data _null_;
		call symputx('time_token_refreshed',put(time(),time.));
		call symputx('time_token_expires',put(time()+3599,time.));
	run;

	data _null_;
		put 30*'-' / ' Token refresh SUCCESS!' / " Token refreshed at &time_token_refreshed" / " Token expires at &time_token_expires" / 30*'-';
	run;

%mend;
