/****************************************************************************************************/
/*  Program Name:       SAS_Macro_CheckToken.sas                                                    */
/*                                                                                                  */
/*  Date Created:       Sept 29, 2020                                                               */
/*																									*/
/*  Created By:         Nydia Lopez & Elle Haynes, based on a SAS Dummy Blog article:               */
/*  https://blogs.sas.com/content/sasdummy/2017/04/14/using-sas-to-access-google-analytics-apis/    */
/*                                                                                                  */
/*  Purpose:            This macro checks to see if the access-token is still valid or has any      */
/*                      error messages (from a recent GA API call .json output). It prints the      */
/*                      time remaining on the valid token or refrshes the token if needed.          */
/*                                                                                                  */
/*  Inputs:             If a recent GA API call returned error messages, they will be stored in     */
/*                      garesp.error. Otherwise, the token is valid, and the timestamp when the     */   			
/*                      access-token expires is saved to &time_token_expires.                       */
/*                                                                                                  */
/* -------------------------------------------------------------------------------------------------*/	
/*  Notes:              Add functionality to run "Get Google API Access.sas" when necessary.        */
/* -------------------------------------------------------------------------------------------------*/
/*  Date Modified:      Oct 8, 2020                                                                 */
/*  Modified by:        Elle Haynes                                                                 */
/*  Description:        Set retry=1 (run %refreshToken and call API again) for error codes 401,     */
/*                      403, 500, or 503, but not for 400. Also now prints the code and reason in   */
/*                      addition to error message.                                                  */
/*                                                                                                  */
/*  Date Modified:      Oct 8, 2020                                                                 */
/*  Modified by:        Elle Haynes                                                                 */
/*  Description:        Add condition to only print remaining time every 10 API calls.              */
/*                                                                                                  */
/*  Date Modified:      Oct 9, 2020                                                                 */
/*  Modified by:        Elle Haynes                                                                 */
/*  Description:        Change condition to run %refreshToken to <= 180 seconds from <=60 seconds.  */
/*                                                                                                  */
/*  Date Modified:      Oct 12, 2020                                                                */
/*  Modified by:        Elle Haynes                                                                 */
/*  Description:        Add 5 error limit. Ends process at the 6th error.                           */
/*                                                                                                  */
/*  Date Modified:      Jun 17, 2021                                                                */
/*  Modified by:        Elle Haynes                                                                 */
/*  Description:        Allow just 2 errors after sleeping instead of 5.                            */
/*                                                                                                  */
/*  Date Modified:      Jun 17, 2021                                                                */
/*  Modified by:        Elle Haynes                                                                 */
/*  Description:        Carry over errorCounter after process is terminated in case another block   */
/*                      of code is executed.                                                        */
/****************************************************************************************************/

%macro checkToken;

	%let counter=%eval(&counter+1);

	/* -------------------------------------------------------------------------------------------------*/
	/*  Conditions if access token returns an error: print error messages and refresh the token.        */
	/* -------------------------------------------------------------------------------------------------*/

   	%if %sysfunc(exist(garesp.error)) %then %do;
	
		data _null_;
			set garesp.error;
			call symputx('error_message',message);
			call symputx('error_status',status);
			call symputx('code',code);
		run;
		data _null_;
			set garesp.error_errors;
			call symputx('reason',reason);
		run;
		data _null_;
			put 80*'-' / ' WARN' 'ING: '"Code &code.: &reason. &error_message." / 80*'-';
		run;
	
		%let errorCode=&code; *Save to global var;
		%let errorCounter=%eval(&errorCounter+1);
		%let totalErrors=%eval(&totalErrors+1);

		%if &code=400 %then %do;
			/* Invalid Parameter or Bad Request. Examine the proc http url. */
			%put Error: API call query has errors.;
			%let retry=-1; * Terminate the process;
			%let errorCounter=0;
		%end;

		%else%if &code=401 %then %do; 
			/* Indicates that the auth token is invalid or has expired. */
			%let retry=1; * Will retry the API call;
			%let retryToken=1; * Will refresh the token, first;
		%end;

		%else %if &code=403 %then %do;
			/* Exceeded daily quota or Exceeded 100 queries per second or Insufficient Permissions */
			%put Error: Quota limits reached. Try again tomorrow.;
			%let retry=-1; * Terminate the process;
			%let errorCounter=0;
		%end;

		%else %if &code=500 or &code=503 %then %do;
			/* Unexpected internal server error occurred or Server returned an error. */
			%let retry=1; * Will retry the API call;
			%let retryToken=1; * Will refresh the token, first;
			%if &errorCounter>4 and &errorCounter_sleep<6 %then %do; * On the 5th error (500/503 codes only), sleep for 15, 30, 45, 60, 75, and up to 90 minutes before retrying;
				%let errorCounter_sleep=%eval(&errorCounter_sleep+1);
				data _null_;
					format minutes_sleep best8. error_time_resume time13.2;
					minutes_sleep=5*&errorCounter_sleep;
					error_time_resume = intnx('minutes',time(),minutes_sleep,'same');
					put 45*'-' / " Sleeping for " minutes_sleep +(-1)" minutes. Resuming at " error_time_resume +(-1) / 45*'-';
					rc=sleep(60*minutes_sleep,1); 
					put 30*'-' / " Resuming now." / 30*'-';
				run;
				%let errorCounter=3; * Allows 2 more errors after sleeping;
			%end;
		%end;
		
		%if &errorCounter>5 %then %do;
			data _null_;
				dur = datetime() - &_timer_start;
				put 60*'-' / ' ERR' 'OR: 5 error limit reached. Ending process. Data is still available in Temp library.';
				put 30*'-' / ' TOTAL DURATION:' dur time13.2 / 30*'-';
			run;
			%let retry=-1; * Terminate the process;
			*%let errorCounter=0;
		%end;

   	%end;

	/* -------------------------------------------------------------------------------------------------*/
	/*  Conditions if access token is still valid: print time remaining or refresh if < 1 min remains.  */
	/* -------------------------------------------------------------------------------------------------*/

   	%else %if %sysfunc(mod(&counter,10))=0 %then %do;

		data _null_;
			put 30*'-' / " Running token check." / 30*'-';
			diff = intck('seconds',time(),"&time_token_expires"t);
			call symputx('diff',diff);
		run;

		%if &diff > 180 %then %do;
			data _null_;
				format diff_min best8.;
				diff_min = round(&diff/60,1);
				put 30*'-' / " Token expires in " diff_min +(-1) " minutes." / 30*'-';
			run;
		%end;

		%else %do;
			data _null_;
				put 60*'-' / "WARN" "ING: Token expires in &diff seconds. Refreshing token..." / 60*'-';
			run;
			%let retry=1;
			%let retryToken=1;
		%end;

	%end;

	%else %do;
		%let retry=0;
	%end;

%mend;
