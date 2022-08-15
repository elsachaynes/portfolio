/****************************************************************************************************/
/*  Program Name:       SAS_Macro_GetGAData.sas                                                     */
/*                                                                                                  */
/*  Date Created:       Sept 28, 2020                                                               */
/*                                                                                                  */
/*  Created By:         Nydia Lopez & Elle Haynes, based on a SAS Dummy Blog article:               */
/*  https://blogs.sas.com/content/sasdummy/2017/04/14/using-sas-to-access-google-analytics-apis/    */
/*                                                                                                  */
/*  Purpose:            Run this script to pull data from the Google Analytics Reporting API        */
/*                      "b2b-better-way-api." Input your dates, dimensions, and metrics.            */
/*                                                                                                  */
/*  Inputs:             This script exchanges OAuth 2.0 clientid credentials and refresh-token      */
/*                      for an access-token that lasts for 60 minutes. Credentials are stored in    */   			
/*                      client_secret.json and updated with "Get Google API Access.sas."            */
/*                      The user must also specify dates, metrics, dimensions, segments, and        */ 
/*                      filters for their report.                                                   */
/*                                                                                                  */
/* -------------------------------------------------------------------------------------------------*/	
/*  Notes:              Add functionality to run "Get Google API Access.sas" when necessary.        */
/*                      Move to v4? See -->                                                         */
/*  https://developers.google.com/analytics/devguides/reporting/core/v4/rest/v4/reports/batchGet    */
/* -------------------------------------------------------------------------------------------------*/
/*  Date Modified:      Oct 2, 2020                                                                 */
/*  Modified by:        Elle Haynes                                                                 */
/*  Description:        Add logic to only proceed with saving daily data to gadaily_ when API       */
/*                      finds at least 1 obs (garesp.rows exists).                                  */
/*                                                                                                  */
/*  Date Modified:      Oct 8, 2020                                                                 */
/*  Modified by:        Elle Haynes                                                                 */
/*  Description:        Add functionality for rollup of June 8 data (combining 2 API calls/2 data   */
/*                      sources seamlessly.                                                         */
/*                                                                                                  */
/*  Date Modified:      Oct 9, 2020                                                                 */
/*  Modified by:        Elle Haynes                                                                 */
/*  Description:        (1) Slow down the pace of calls by doubling sleep_time each 50 calls to     */
/*                      prevent latency and errors (ranges from 0.25-32 seconds for 0-400 calls).   */
/*                      (2) Check to see if data exists in TEMP library to prevent re-running.      */
/*                      (3) Filters out GA data with unicode char in pagePath that causes errors.   */
/*                      (4) Add condition to only clear the TEMP library when the final dataset     */
/*                      contains more than 0 records.                                               */
/*                                                                                                  */
/*  Date Modified:      Oct 23, 2020                                                                */
/*  Modified by:        Elle Haynes                                                                 */
/*  Description:        (1) Add the ability to change to level of data from daily to weekly/monthly */
/*                      or anything else available in intnx().                                      */
/*                      (2) Prevented sequential API calls from running if the previous API call    */
/*                      ended on a 403 error (surpassed daily quota).                               */
/*                                                                                                  */
/*  Date Modified:      Apr 7, 2021                                                                 */
/*  Modified by:        Elle Haynes                                                                 */
/*  Description:        Added the new view ga:237115833 (Unique Goals) and the ability to switch    */
/*                      between views in the macro call.                                            */
/*                                                                                                  */
/*  Date Modified:      June 3, 2021                                                                */
/*  Modified by:        Elle Haynes                                                                 */
/*  Description:        (1) Require data July 1, 2021 and later to be pulled from the new view      */
/*                      (KP Copied View - Unique Goals), since data between views differs slightly. */
/*                      (2) Prevent download of data from the new profile prior to July 1, 2021.    */
/****************************************************************************************************/

%macro GetGAData(chooseSegment=&defaultSegment,
 				    chooseView=Default,
					addl_filters=%str(),
					level=day,
					StartDate=,
					EndDate=,
					output_file_path=,
					output_file_name=defaultGAOutputName);

	/* Start timer */
	%let _timer_start = %sysfunc(datetime());

	%let sleep_time = 0.25;
	%let counter = 1; *Increments + 1 each API call;
	%let errorCounter = %sysfunc(coalescec(&errorCounter,0)); *Carry over errorCounter if exists;
	%let errorCounter_sleep = %sysfunc(coalescec(&errorCounter_sleep,0)); *Carry over errorCounter_sleep if exists;
	%let totalErrors = 0;

	/* -------------------------------------------------------------------------------------------------*/
	/*  Refresh the access-token, which is valid for 60 minutes.                                        */
	/* -------------------------------------------------------------------------------------------------*/

	%refreshToken;

	/* -------------------------------------------------------------------------------------------------*/
	/*  Check for error code from previous run.                                                         */
	/* -------------------------------------------------------------------------------------------------*/

	%if &errorCode=403 %then %do;
		%put ERROR: Error quota surpassed.;
		endsas;
	%end;

	/* -------------------------------------------------------------------------------------------------*/
	/*  Set output file path.                                                                           */
	/* -------------------------------------------------------------------------------------------------*/

	/* Working */
	libname ga "&output_file_path";
	%if %sysfunc(libref(temp)) ne 0 %then %do; /* only run if temp does not exist */
		libname temp "&output_file_path/Temp";
		%if %sysfunc(libref(temp)) ne 0 %then %do;
			%put ERROR: Please create a folder "Temp" in &output_file_path;
			*endsas;
		%end;
	%end;
	%put OK;

	/* -------------------------------------------------------------------------------------------------*/
	/*  Set B2B GA Profile/Views.                                                                       */
	/* -------------------------------------------------------------------------------------------------*/

	%let view=					&chooseView; *user input;

	%if &view=Default %then %do;
		%let id_pre_8Jun20=     %sysfunc(urlencode(%str(ga:77908607))); *For June 8, 2020 and earlier "B2B (Unfiltered View)".;
		%let id_post_8Jun20=    %sysfunc(urlencode(%str(ga:219887332))); *For June 8, 2020 and later "KP Copied View";
		%let id_post_1Jul21=    %sysfunc(urlencode(%str(ga:237115833))); *For April 1, 2021 and later "KP Copied View - Unique Goals";
	%end;
	%else %if &view=Goals %then %do;
		%let id_post_1Jul21=    %sysfunc(urlencode(%str(ga:237115833))); *For April 1, 2021 and later "KP Copied View - Unique Goals";
		%if &StartDate < "01JUL2021"d %then %do;
			%put ERROR: Data from KP Copied View - Unique Goals before July 1, 2021 is not recommended to use.;
			endsas;
			%end;
	%end;
	%else %if &view=Master %then %do;
		%let id_pre_8Jun20=     %sysfunc(urlencode(%str(ga:74831202))); *"Kaiser Permanente - Master Rollup (Unfiltered View)";
		%let id_post_8Jun20=    %sysfunc(urlencode(%str(ga:74831202))); *"Kaiser Permanente - Master Rollup (Unfiltered View)";
		%let id_post_1Jul21=    %sysfunc(urlencode(%str(ga:74831202))); *"Kaiser Permanente - Master Rollup (Unfiltered View)";
	%end;
	%else %if &view=OldGoals %then %do;
		%let id_pre_8Jun20=     %sysfunc(urlencode(%str(ga:77908607))); *For June 8, 2020 and earlier "B2B (Unfiltered View)".;
		%let id_post_8Jun20=    %sysfunc(urlencode(%str(ga:219887332))); *For June 8, 2020 and later "KP Copied View";
		%let id_post_1Jul21=    %sysfunc(urlencode(%str(ga:219887332))); *For June 8, 2020 and later "KP Copied View";
	%end;

	/* -------------------------------------------------------------------------------------------------*/
	/*  Apply segment.                                                                                  */
	/* -------------------------------------------------------------------------------------------------*/

	%let segment=       		&chooseSegment; *user input;

	/* -------------------------------------------------------------------------------------------------*/
	/*  Filters (must be less than 100 characters or returns error).                                    */
	/* -------------------------------------------------------------------------------------------------*/

	%let filters=       		&addl_filters; *user input;

	/* -------------------------------------------------------------------------------------------------*/
	/*  Prep the variables from user input into API call format.                                        */
	/* -------------------------------------------------------------------------------------------------*/

	%APIvariablePrep(&number_of_dimensions,&number_of_metrics);

	/* -------------------------------------------------------------------------------------------------*/
	/*  Loop through each day/week/month/year.                                                          */
	/* -------------------------------------------------------------------------------------------------*/

	data _null_;
	    put 60*'-' / " Begin the loop from &StartDate to &EndDate by &level.." / 60*'-';
	run;

	data all_dates;
		date = "&startdate"d;
		do while (date<="&enddate"d);
			date_end=intnx("&level", date, 0, 'end');
			if date_end > "&enddate"d then date_end="&enddate"d;
			output;
			date=intnx("&level", date, 1, 'beginning');
		end;
		format Date yymmdd10. Date_end yymmdd10.;
	run;

	%if %sysevalf("&StartDate"d <= "08jun2020"d) %then %do; /* if need data from old profile, must pull daily to avoid sampling */
		proc sql noprint;
		select distinct 
			min(Date) format date9.
			into :StartDate_OldProfile
			from all_dates
		quit;
		proc sql noprint;
		select distinct 
			max(Date_End) format date9.
			into :EndDate_OldProfile
			from all_dates
			where (month(Date_End)=6 and year(Date_End)=2020)
				or (month(Date)=6 and year(Date)=2020); /* daily through the entire June 2020 */
		quit;
		data _null_;
			put 60*'-' / " And loop from &StartDate_OldProfile to &EndDate_OldProfile by day." / 60*'-';
		run;
		data all_dates_new;
			date = "&StartDate_OldProfile"d;
			do while (date<="&EndDate_OldProfile"d);
				date_end=intnx("day", date, 0, "s");
				output;
				date=intnx("day", date, 1, "s");
			end;
			format Date yymmdd10. Date_end yymmdd10.;
		run;
		data all_dates;
			set all_dates(where=(date>"&EndDate_OldProfile"d))
				all_dates_new;
		run;
		proc sort data=all_dates; by Date; run;
	%end;

	proc sql noprint;
		select date into :loopdates separated by ',' from all_dates;
		select date_end into :loopdates_end separated by ',' from all_dates;
	quit;

	%let i=1;

	%do %while(%scan(%bquote(&loopdates.),&i.,%str(,)) ne %str()); 

		%let repeat=0; *initialize to 0 (no repeat);
		%let retry=0; *initialize to 0 (no retry);
		%let retries=0; *initialize to 0 (no retries completed yet);

		%let urldate=%scan(%bquote(&loopdates.),&i.,%str(,));
		%let urldate_end=%scan(%bquote(&loopdates_end.),&i.,%str(,));
		%let workdate=%sysfunc(inputn(&urldate,yymmdd10.));
		
		%if %sysfunc(exist(temp.ga_daily%sysfunc(compress(&urldate.,'-'))))=0 %then %do;

			/* -------------------------------------------------------------------------------------------------*/
			/*  Set GA view ID based on date.                                                                   */
			/* -------------------------------------------------------------------------------------------------*/

			/* Prior to June 8, 2020 */
			%if &workdate < %sysfunc(putn('08jun2020'd,5.)) %then %do;
				%let id=&id_pre_8Jun20;
				%if &chooseView=Default %then %let id_name=B2B (Unfiltered View) Excluding Internal Traffic;
				%else %if &chooseView=Goals %then %do;
					%put ERROR: Data from KP Copied View - Unique Goals before July 1, 2021 is not recommended to use.;
					endsas;
					%end;
				%else %if &chooseView=OldGoals %then %let id_name=Kaiser Permanente - Master Rollup (Unfiltered View);
				%else %if &chooseView=Master %then %let id_name=Kaiser Permanente - Master Rollup (Unfiltered View);
			%end;

			/* June 8, 2020 to June 30, 2021 */
			%else %if &workdate > %sysfunc(putn('08jun2020'd,5.)) and &workdate < %sysfunc(putn('01jul2021'd,5.)) %then %do;
				%let id=&id_post_8Jun20;
				%if &chooseView=Default %then %let id_name=KP Copied View;
				%else %if &chooseView=Goals %then %do;
					%put ERROR: Data from KP Copied View - Unique Goals before July 1, 2021 is not recommended to use.;
					endsas;
					%end;
				%else %if &chooseView=OldGoals %then %let id_name=KP Copied View;
				%else %if &chooseView=Master %then %let id_name=Kaiser Permanente - Master Rollup (Unfiltered View);
			%end;

				%else %if &chooseView=Goals %then %let id_name=KP Copied View - Unique Goals;

			/* June 8, 2020 -- 2 views */
			%else %if &workdate = %sysfunc(putn('08jun2020'd,5.)) %then %do;
				%let id=&id_post_8Jun20;
				%let repeat=1;
				%if &chooseView=Default %then %let id_name=KP Copied View;
				%else %if &chooseView=Goals %then %do;
					%put ERROR: Data from KP Copied View - Unique Goals before July 1, 2021 is not recommended to use.;
					endsas;
					%end;
				%else %if &chooseView=OldGoals %then %let id_name=KP Copied View;
				%else %if &chooseView=Master %then %let id_name=Kaiser Permanente - Master Rollup (Unfiltered View);
			%end;

			/* July 1, 2021 and later */
			%else %if &workdate >= %sysfunc(putn('01jul2021'd,5.)) %then %do;
				%let id=&id_post_1Jul21;
				%if &chooseView=Default %then %let id_name=KP Copied View - Unique Goals;
				%else %if &chooseView=Goals %then %let id_name=KP Copied View - Unique Goals;
				%else %if &chooseView=OldGoals %then %let id_name=KP Copied View;
				%else %if &chooseView=Master %then %let id_name=Kaiser Permanente - Master Rollup (Unfiltered View);
			%end;

			data _null_;
				put 84*'-' / " Pulling data for &urldate from &id_name.." / 84*'-';
			run;

			/* -------------------------------------------------------------------------------------------------*/
			/*  Excute API call.                                                                                */
			/* -------------------------------------------------------------------------------------------------*/

			filename ga_resp temp encoding="utf-8";

			%if %eval(&addl_filters=%str())=1 %then %do; *No filters; 
				proc http
			 		url="https://www.googleapis.com/analytics/v3/data/ga?ids=&id.%str(&)start-date=&urldate.%str(&)end-date=&urldate_end.%str(&)metrics=&metrics.%str(&)dimensions=&dimensions.%str(&)segment=&segment.%str(&)samplingLevel=HIGHER_PRECISION%str(&)max-results=10000"
				 	method="GET" out=ga_resp;
				 	headers 
				   		"Authorization"="Bearer &access_token."
				   		"client-id:"="&client_id.";
				run;
			%end;

			%else %do; *Has filters;
				proc http
			 		url="https://www.googleapis.com/analytics/v3/data/ga?ids=&id.%str(&)start-date=&urldate.%str(&)end-date=&urldate.%str(&)metrics=&metrics.%str(&)dimensions=&dimensions.%str(&)filters=&filters.%str(&)segment=&segment.%str(&)samplingLevel=HIGHER_PRECISION%str(&)max-results=10000"
				 	method="GET" out=ga_resp;
				 	headers 
				   		"Authorization"="Bearer &access_token."
				   		"client-id:"="&client_id.";
				run;
			%end;

			libname garesp json fileref=ga_resp;

			/* -------------------------------------------------------------------------------------------------*/
			/*  Check the data, retry the API call if necessary.                                                */
			/* -------------------------------------------------------------------------------------------------*/

			%checkToken;

			%do %while(&retry=1); *%checkToken process sets retry=1 if garesp.error exists;

				%let retries=%eval(&retries+1);

				data _null_;
					put 45*'-' / " Retrying API call for &urldate. - Retry #&retries." / 45*'-';
				run;

				/* exponential backoff */
				data _null_;
					call symputx('random_number_millisec',rand('UNIFORM',0,1));
					call symputx('maximum_backoff',30);
					call symputx('backoff_seconds',2**&errorCounter);
				run;

				%let sleep_time_error=%sysfunc(min(%sysevalf(&backoff_seconds+&random_number_millisec),&maximum_backoff));
				data _null_;
					put 30*'-' / " Waiting &sleep_time_error. seconds." / 30*'-';
					rc=sleep(&sleep_time_error,1);
				run;

				%if &retryToken=1 %then %do; *%checkToken process sets retryToken=1 for error codes 401, 500, and 503;

					data _null_;
						put 30*'-' / " Refreshing token now." / 30*'-';
					run;

					%refreshToken;

					data _null_;
						rc=sleep(5,1); *Pause 5 seconds after refreshing token;
					run;

				%end;

				filename ga_resp temp encoding="utf-8"; 
					
				%if %eval(&addl_filters=%str())=1 %then %do; *No filters; 
					proc http
				 		url="https://www.googleapis.com/analytics/v3/data/ga?ids=&id.%str(&)start-date=&urldate.%str(&)end-date=&urldate_end.%str(&)metrics=&metrics.%str(&)dimensions=&dimensions.%str(&)segment=&segment.%str(&)samplingLevel=HIGHER_PRECISION%str(&)max-results=10000"
					 	method="GET" out=ga_resp;
					 	headers 
					   		"Authorization"="Bearer &access_token."
					   		"client-id:"="&client_id.";
					run;
				%end;

				%else %do; *Has filters;
					proc http
				 		url="https://www.googleapis.com/analytics/v3/data/ga?ids=&id.%str(&)start-date=&urldate.%str(&)end-date=&urldate_end.%str(&)metrics=&metrics.%str(&)dimensions=&dimensions.%str(&)filters=&filters.%str(&)segment=&segment.%str(&)samplingLevel=HIGHER_PRECISION%str(&)max-results=10000"
					 	method="GET" out=ga_resp;
					 	headers 
					   		"Authorization"="Bearer &access_token."
					   		"client-id:"="&client_id.";
					run;
				%end;

				libname garesp json fileref=ga_resp;

				%checkToken; *Reassigns retry to -1, 0, or 1;

			%end;

			%if &retry=-1 %then endsas; *%checkToken process sets retry=-1 for error codes 400 and 403, or when the 10 error limit is reached; 

			/* -------------------------------------------------------------------------------------------------*/
			/*  Format as SAS data.                                                                             */
			/* -------------------------------------------------------------------------------------------------*/

			%if %sysfunc(exist(garesp.rows)) %then %do;

				data temp.ga_daily%sysfunc(compress(&urldate.,'-')); 
					retain 	date 
							element:;
					format 	date yymmdd10.
						   	&formats.; 
					set 	garesp.rows;	
					drop 	ordinal_root 
							ordinal_rows 
							element:;
					date=&workdate.;
					&informats.
				run;

				proc sql noprint;
			    	select count(*)
			    	into :rowCount trimmed
			    	from temp.ga_daily%sysfunc(compress(&urldate.,'-'));
			  	quit;

				data _null_;
					put 45*'-' / " &rowCount rows written to temp.ga_daily%sysfunc(compress(&urldate.,'-'))." / 45*'-';
				run;

				data all_dates;
					set all_dates;
					if date=&workdate then delete;
				run;

			%end;

			%else %if %sysfunc(exist(garesp.alldata)) %then %do;

				%put WARNING: No data found for &urldate in the query.;
				data all_dates;
					set all_dates;
					if date=&workdate then delete;
				run;
					
			%end;

			/* -------------------------------------------------------------------------------------------------*/
			/*  For June 8, 2020 data only - pull from both GA views and aggregate.                             */
			/* -------------------------------------------------------------------------------------------------*/

			%if &repeat=1 %then %do;

					%let id=&id_pre_8Jun20;
					data _null_;
						put 60*'-' / " Pulling June 8, 2020 data from second view (B2B (Unfiltered View) Excluding Internal Traffic)." / 60*'-';
					run;

					filename ga_resp temp encoding="utf-8"; 

					%if %eval(&addl_filters=%str())=1 %then %do; *No filters; 
						proc http
					 		url="https://www.googleapis.com/analytics/v3/data/ga?ids=&id.%str(&)start-date=&urldate.%str(&)end-date=&urldate_end.%str(&)metrics=&metrics.%str(&)dimensions=&dimensions.%str(&)segment=&segment.%str(&)samplingLevel=HIGHER_PRECISION%str(&)max-results=10000"
						 	method="GET" out=ga_resp;
						 	headers 
						   		"Authorization"="Bearer &access_token."
						   		"client-id:"="&client_id.";
						run;
					%end;

					%else %do; *Has filters;
					proc http
				 		url="https://www.googleapis.com/analytics/v3/data/ga?ids=&id.%str(&)start-date=&urldate.%str(&)end-date=&urldate_end.%str(&)metrics=&metrics.%str(&)dimensions=&dimensions.%str(&)filters=&filters.%str(&)segment=&segment.%str(&)samplingLevel=HIGHER_PRECISION%str(&)max-results=10000"
					 	method="GET" out=ga_resp;
					 	headers 
					   		"Authorization"="Bearer &access_token."
					   		"client-id:"="&client_id.";
					run;
					%end;

					libname garesp json fileref=ga_resp;

					%checkToken;

					%if %sysfunc(exist(garesp.rows)) %then %do;

						data temp.ga_daily%sysfunc(compress(&urldate.,'-'))_2; 
							retain 	date 
									element:;
							format 	date yymmdd10.
								   	&formats.; 
							set 	garesp.rows;	
							drop 	ordinal_root 
									ordinal_rows 
									element:;
							date=&workdate.;
							&informats.
						run;

						data temp.ga_daily%sysfunc(compress(&urldate.,'-'));
							set temp.ga_daily%sysfunc(compress(&urldate.,'-')):;
						run;

						proc sql;
							create table temp.ga_daily%sysfunc(compress(&urldate.,'-'))_temp as
							select distinct
								date
							,	&rollup_dimensions.&rollup_metrics.
							from temp.ga_daily%sysfunc(compress(&urldate.,'-'))
							group by 
								&rollup_dimensions.;
						quit;

					 	proc delete data=temp.ga_daily%sysfunc(compress(&urldate.,'-'))_2; 
						proc delete data=temp.ga_daily%sysfunc(compress(&urldate.,'-')); 

						data temp.ga_daily%sysfunc(compress(&urldate.,'-'));
							set temp.ga_daily%sysfunc(compress(&urldate.,'-'))_temp;
						run;

						proc delete data=temp.ga_daily%sysfunc(compress(&urldate.,'-'))_temp; 

					%end;

					%let repeat=0;

			%end;

			/* -------------------------------------------------------------------------------------------------*/
			/*  Pause before looping.                                                                           */
			/* -------------------------------------------------------------------------------------------------*/

			%if %sysfunc(mod(&counter,50))=0 %then %do;

				%if &counter < 200 %then %do;
					%let sleep_time=%sysevalf(&sleep_time*2); /* double sleep_time each addl 50 API calls */
				%end;
				%else %do;
					%let sleep_time=%sysevalf(&sleep_time/2); /* from 250th onward, halve sleep_time each 50 API calls */
				%end;

				data _null_;
					put 60*'-' / " Now running API calls every &sleep_time seconds." / 60*'-';
				run;

			%end;

			data _null_;
				put 30*'-' / " Sleeping for &sleep_time seconds." / 30*'-';
				rc=sleep(&sleep_time,1);
			run;

		%end;

		%else %do;
			%put temp.ga_daily%sysfunc(compress(&urldate.,'-')) already exists.;
			data all_dates;
				set all_dates;
				if date=&workdate then delete;
			run;
		%end;

		%let i = %eval(&i+1);

	%end;

	data _null_;
		put 30*'-' / ' End of API calls - Pass 1' / 30*'-' ;
	run;

	/* -------------------------------------------------------------------------------------------------*/
	/*  Pass 2 with filter.                                                                             */
	/* -------------------------------------------------------------------------------------------------*/

	%let doNotRemove=			%str(ga:pagePath!~\pC); *pagePath does not match regEx invisible control characters and unused control points;
	%if %eval(&addl_filters=%str())=1 %then %do; *No filters;
		%let filters=       	%sysfunc(urlencode(&doNotRemove));
	%end;
	%else %do;
		%let filters=       	%sysfunc(urlencode(&doNotRemove))%nrstr(;)&addl_filters; *only for pass2;
	%end;

	%let loopdates=;
	%let loopdates_end=;
	proc sql noprint;
		select date into :loopdates separated by ',' from all_dates;
		select date_end into :loopdates_end separated by ',' from all_dates;
	quit;

	%let i=1;

	%do %while(%scan(%bquote(&loopdates.),&i.,%str(,)) ne %str()); 

		data _null_;
			put 30*'-' / ' Beginning Pass 2' / 30*'-' ;
		run;

		%let repeat=0; *initialize to 0 (no repeat);
		%let retry=0; *initialize to 0 (no retry);
		%let retries=0; *initialize to 0 (no retries completed yet);

		%let urldate=%scan(%bquote(&loopdates.),&i.,%str(,));
		%let urldate_end=%scan(%bquote(&loopdates_end.),&i.,%str(,));
		%let workdate=%sysfunc(inputn(&urldate,yymmdd10.));

		%if %sysfunc(exist(temp.ga_daily%sysfunc(compress(&urldate.,'-'))))=0 %then %do;

			/* -------------------------------------------------------------------------------------------------*/
			/*  Set GA view ID based on date.                                                                   */
			/* -------------------------------------------------------------------------------------------------*/

			/* Prior to June 8, 2020 */
			%if &workdate < %sysfunc(putn('08jun2020'd,5.)) %then %do;
				%let id=&id_pre_8Jun20;
				%if &chooseView=Default %then %let id_name=B2B (Unfiltered View) Excluding Internal Traffic;
				%else %if &chooseView=Goals %then %do;
					%put ERROR: Data from KP Copied View - Unique Goals before July 1, 2021 is not recommended to use.;
					endsas;
					%end;
				%else %if &chooseView=OldGoals %then %let id_name=Kaiser Permanente - Master Rollup (Unfiltered View);
				%else %if &chooseView=Master %then %let id_name=Kaiser Permanente - Master Rollup (Unfiltered View);
			%end;

			/* June 8, 2020 to June 30, 2021 */
			%else %if &workdate > %sysfunc(putn('08jun2020'd,5.)) and &workdate < %sysfunc(putn('01jul2021'd,5.)) %then %do;
				%let id=&id_post_8Jun20;
				%if &chooseView=Default %then %let id_name=KP Copied View;
				%else %if &chooseView=Goals %then %do;
					%put ERROR: Data from KP Copied View - Unique Goals before July 1, 2021 is not recommended to use.;
					endsas;
					%end;
				%else %if &chooseView=OldGoals %then %let id_name=KP Copied View;
				%else %if &chooseView=Master %then %let id_name=Kaiser Permanente - Master Rollup (Unfiltered View);
			%end;

				%else %if &chooseView=Goals %then %let id_name=KP Copied View - Unique Goals;

			/* June 8, 2020 -- 2 views */
			%else %if &workdate = %sysfunc(putn('08jun2020'd,5.)) %then %do;
				%let id=&id_post_8Jun20;
				%let repeat=1;
				%if &chooseView=Default %then %let id_name=KP Copied View;
				%else %if &chooseView=Goals %then %do;
					%put ERROR: Data from KP Copied View - Unique Goals before July 1, 2021 is not recommended to use.;
					endsas;
					%end;
				%else %if &chooseView=OldGoals %then %let id_name=KP Copied View;
				%else %if &chooseView=Master %then %let id_name=Kaiser Permanente - Master Rollup (Unfiltered View);
			%end;

			/* July 1, 2021 and later */
			%else %if &workdate >= %sysfunc(putn('01jul2021'd,5.)) %then %do;
				%let id=&id_post_1Jul21;
				%if &chooseView=Default %then %let id_name=KP Copied View - Unique Goals;
				%else %if &chooseView=Goals %then %let id_name=KP Copied View - Unique Goals;
				%else %if &chooseView=OldGoals %then %let id_name=KP Copied View;
				%else %if &chooseView=Master %then %let id_name=Kaiser Permanente - Master Rollup (Unfiltered View);
			%end;

			data _null_;
				put 84*'-' / " Pulling data for &urldate from &id_name.." / 84*'-';
			run;

			/* -------------------------------------------------------------------------------------------------*/
			/*  Excute API call.                                                                                */
			/* -------------------------------------------------------------------------------------------------*/

			filename ga_resp temp encoding="utf-8";
			proc http
		 		url="https://www.googleapis.com/analytics/v3/data/ga?ids=&id.%str(&)start-date=&urldate.%str(&)end-date=&urldate_end.%str(&)metrics=&metrics.%str(&)dimensions=&dimensions.%str(&)filters=&filters.%str(&)segment=&segment.%str(&)samplingLevel=HIGHER_PRECISION%str(&)max-results=10000"
			 	method="GET" out=ga_resp;
			 	headers 
			   		"Authorization"="Bearer &access_token."
			   		"client-id:"="&client_id.";
			run;
			libname garesp json fileref=ga_resp;

			/* -------------------------------------------------------------------------------------------------*/
			/*  Check the data, retry the API call if necessary.                                                */
			/* -------------------------------------------------------------------------------------------------*/

			%checkToken;

			%do %while(&retry=1); *%checkToken process sets retry=1 if garesp.error exists;

				%let retries=%eval(&retries+1);

				data _null_;
					put 45*'-' / " Retrying API call for &urldate. - Retry #&retries." / 45*'-';
				run;

				/* exponential backoff */
				data _null_;
					call symputx('random_number_millisec',rand('UNIFORM',0,1));
					call symputx('maximum_backoff',30);
					call symputx('backoff_seconds',2**&errorCounter);
				run;

				%let sleep_time_error=%sysfunc(min(%sysevalf(&backoff_seconds+&random_number_millisec),&maximum_backoff));
				data _null_;
					put 30*'-' / " Waiting &sleep_time_error. seconds." / 30*'-';
					rc=sleep(&sleep_time_error,1);
				run;

				%if &retryToken=1 %then %do; *%checkToken process sets retryToken=1 for error codes 401, 500, and 503;

					data _null_;
						put 30*'-' / " Refreshing token now." / 30*'-';
					run;

					%refreshToken;

					data _null_;
						rc=sleep(5,1); *Pause 5 seconds after refreshing token;
					run;

				%end;

				filename ga_resp temp encoding="utf-8"; 
				proc http
			 		url="https://www.googleapis.com/analytics/v3/data/ga?ids=&id.%str(&)start-date=&urldate.%str(&)end-date=&urldate_end.%str(&)metrics=&metrics.%str(&)dimensions=&dimensions.%str(&)filters=&filters.%str(&)segment=&segment.%str(&)samplingLevel=HIGHER_PRECISION%str(&)max-results=10000"
				 	method="GET" out=ga_resp;
				 	headers 
				   		"Authorization"="Bearer &access_token."
				   		"client-id:"="&client_id.";
				run;
				libname garesp json fileref=ga_resp;

				%checkToken; *Reassigns retry to -1, 0, or 1;

			%end;

			%if &retry=-1 %then endsas; *%checkToken process sets retry=-1 for error codes 400 and 403, or when the 10 error limit is reached; 

			/* -------------------------------------------------------------------------------------------------*/
			/*  Format as SAS data.                                                                             */
			/* -------------------------------------------------------------------------------------------------*/

			%if %sysfunc(exist(garesp.rows)) %then %do;

				data temp.ga_daily%sysfunc(compress(&urldate.,'-')); 
					retain 	date 
							element:;
					format 	date yymmdd10.
						   	&formats.; 
					set 	garesp.rows;	
					drop 	ordinal_root 
							ordinal_rows 
							element:;
					date=&workdate.;
					&informats.
				run;

				proc sql noprint;
			    	select count(*)
			    	into :rowCount trimmed
			    	from temp.ga_daily%sysfunc(compress(&urldate.,'-'));
			  	quit;

				data _null_;
					put 45*'-' / " &rowCount rows written to temp.ga_daily%sysfunc(compress(&urldate.,'-'))." / 45*'-';
				run;

				data all_dates;
					set all_dates;
					if date=&workdate then delete;
				run;

			%end;

			%else %if %sysfunc(exist(garesp.alldata)) %then %do;

				%put WARNING: No data found for &urldate in the query.
				data all_dates;
					set all_dates;
					if date=&workdate then delete;
				run;
					
			%end;

			/* -------------------------------------------------------------------------------------------------*/
			/*  For June 8, 2020 data only - pull from both GA views and aggregate.                             */
			/* -------------------------------------------------------------------------------------------------*/

			%if &repeat=1 %then %do;

					%let id=&id_pre_8Jun20;
					data _null_;
						put 60*'-' / " Pulling June 8, 2020 data from second view (B2B (Unfiltered View) Excluding Internal Traffic)." / 60*'-';
					run;

					filename ga_resp temp encoding="utf-8"; 
					proc http
				 		url="https://www.googleapis.com/analytics/v3/data/ga?ids=&id.%str(&)start-date=&urldate.%str(&)end-date=&urldate_end.%str(&)metrics=&metrics.%str(&)dimensions=&dimensions.%str(&)filters=&filters.%str(&)segment=&segment.%str(&)samplingLevel=HIGHER_PRECISION%str(&)max-results=10000"
					 	method="GET" out=ga_resp;
					 	headers 
					   		"Authorization"="Bearer &access_token."
					   		"client-id:"="&client_id.";
					run;
					libname garesp json fileref=ga_resp;

					%checkToken;

					%if %sysfunc(exist(garesp.rows)) %then %do;

						data temp.ga_daily%sysfunc(compress(&urldate.,'-'))_2; 
							retain 	date 
									element:;
							format 	date yymmdd10.
								   	&formats.; 
							set 	garesp.rows;	
							drop 	ordinal_root 
									ordinal_rows 
									element:;
							date=&workdate.;
							&informats.
						run;

						data temp.ga_daily%sysfunc(compress(&urldate.,'-'));
							set temp.ga_daily%sysfunc(compress(&urldate.,'-')):;
						run;

						proc sql;
							create table temp.ga_daily%sysfunc(compress(&urldate.,'-'))_temp as
							select distinct
								date
							,	&rollup_dimensions.&rollup_metrics.
							from temp.ga_daily%sysfunc(compress(&urldate.,'-'))
							group by 
								&rollup_dimensions.;
						quit;

					 	proc delete data=temp.ga_daily%sysfunc(compress(&urldate.,'-'))_2; 
						proc delete data=temp.ga_daily%sysfunc(compress(&urldate.,'-')); 

						data temp.ga_daily%sysfunc(compress(&urldate.,'-'));
							set temp.ga_daily%sysfunc(compress(&urldate.,'-'))_temp;
						run;

						proc delete data=temp.ga_daily%sysfunc(compress(&urldate.,'-'))_temp; 
					%end;

					%let repeat=0;

			%end;

			/* -------------------------------------------------------------------------------------------------*/
			/*  Pause before looping.                                                                           */
			/* -------------------------------------------------------------------------------------------------*/

			%if %sysfunc(mod(&counter,50))=0 %then %do;

				%if &counter < 200 %then %do;
					%let sleep_time=%sysevalf(&sleep_time*2); /* double sleep_time each addl 50 API calls */
				%end;
				%else %do;
					%let sleep_time=%sysevalf(&sleep_time/2); /* from 250th onward, halve sleep_time each 50 API calls */
				%end;
				data _null_;
					put 60*'-' / " Now running API calls every &sleep_time seconds." / 60*'-';
				run;

			%end;

			data _null_;
				put 30*'-' / " Sleeping for &sleep_time seconds." / 30*'-';
				rc=sleep(&sleep_time,1);
			run;

		%end;

		%let i = %eval(&i+1);
		data _null_;
			put 30*'-' / ' End of API calls - Pass 2' / 30*'-' ;
		run;

	%end;

	data _NULL_;
		if 0 then set all_dates nobs=n;
		call symputx('N',n);
		stop;
	run;

	%if &N>0 %then %do;
		title 'Dates missing data';
		proc sql;
			select distinct date, date_end from all_dates;
		quit;
		title;
		proc sql noprint;
			select distinct date into :missing_dates separated by ',' from all_dates;
		quit;
	%end;
	%else %do;
		%let missing_dates = None;
	%end;
	proc delete data=all_dates; run;

/*-------------------------------------------------------------------------------------------------*/
/*  Append all daily/weekly/monthly datasets.                                                      */
/*-------------------------------------------------------------------------------------------------*/
	
	proc sql noprint;
	   select count(memname) into :memcount
	   from dictionary.members
	   where libname='TEMP' and memtype='DATA';
	quit;

	%if &memcount>0 %then %do;
		data ga.&output_file_name._Temp;
	  		set temp.ga_daily:;
		run;
	%end;

	%if %sysfunc(exist(ga.&output_file_name._Temp)) %then %do;
		proc sql;
		create table ga.&output_file_name. as
			select distinct
				intnx("&level",Date,0,'beginning') as Date format yymmdd10.
			,	&rollup_dimensions.&rollup_metrics.
			from ga.&output_file_name._Temp
			group by 
				intnx("&level",Date,0,'beginning')
			,	&rollup_dimensions.;
		quit;

		proc delete data=ga.&output_file_name._Temp; run;

	/*-------------------------------------------------------------------------------------------------*/
	/*  Clear temp variables and library.                                                              */
	/*-------------------------------------------------------------------------------------------------*/

		data _NULL_;
			if 0 then set ga.&output_file_name. nobs=n;
			call symputx('rowCount',n);
			stop;
		run;

		data _null_;
			put 50*'-' / " &rowCount rows written to ga.&output_file_name." / 50*'-';
		run;

	%end;
	%else %do;
		%let rowCount=0;
	%end;

  	%if &rowCount=0 %then %do;

		%put WARNING: No rows written to ga.&output_file_name.;

		/* Stop timer */
		data _null_;
	  		dur = datetime() - &_timer_start;
	  		put 30*'-' / ' TOTAL DURATION:' dur time13.2 / 30*'-';
			put 30*'-' / " TOTAL ERRORS: &totalErrors" / 30*'-';
			put 30*'-' / " DATES MISSING (by &level): &missing_dates." / 30*'-';
		run;

		%return;

	%end;
	%else %do;

		proc datasets nolist nodetails lib=temp kill;

		/* Stop timer */
		data _null_;
			put 30*'-' / ' Clear temp folder SUCCESS!' / 30*'-' ;
	  		dur = datetime() - &_timer_start;
	  		put 30*'-' / ' TOTAL DURATION:' dur time13.2 +(-1) / 30*'-';
			put 30*'-' / " TOTAL ERRORS: &totalErrors" / 30*'-';
			put 30*'-' / " DATES MISSING (by &level): &missing_dates." / 30*'-';
		run;
	%end;

%mend;
