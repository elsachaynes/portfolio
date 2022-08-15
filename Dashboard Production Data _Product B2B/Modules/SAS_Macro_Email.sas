/****************************************************************************************************/
/*  Program Name:       SAS_Macro_Email.sas                                                         */
/*                                                                                                  */
/*  Date Created:       Jan 19, 2021                                                                */
/*                                                                                                  */
/*  Created By:         Elle Haynes                                                                 */
/*                                                                                                  */
/*  Purpose:            Sends an email for B2B dashboard data processing steps.                     */
/*                                                                                                  */
/*  Inputs:             Dataset name, condition, and error message.                                 */
/*                                                                                                  */
/* -------------------------------------------------------------------------------------------------*/	
/*  Notes:                                                                                          */
/* -------------------------------------------------------------------------------------------------*/
/*  Date Modified:                                                                                  */
/*  Modified by:                                                                                    */
/*  Description:                                                                                    */
/****************************************************************************************************/

%macro emailB2Bdashboard(scriptName,
			attachFreqTableFlag=0,
			attachLogFlag=0,
			sentFrom='elsa.c.haynes@kp.org',
			sentTo=('elsa.c.haynes@kp.org','smriti.malla@kp.org','niki.z.petrakos@kp.org')
			);

	%if &attachFreqTableFlag = 1 %then %do;
		%let attach1=%str(&input_files/Frequency Tables - &scriptName..xlsx);
		%let attachFreqTable = %str("&attach1." CT="APPLICATION/MSEXCEL" EXT="xlsx");
	%end;
	%if &attachLogFlag = 1 %then %do;
		%let attach2=%str(&input_files/LOG &scriptName..txt);
		%let attachLog = %str("&attach2." CT="text/plain" EXT="txt");
	%end;

	%if &Nnew>0 and &cancel= %then %do; /* New records added to file */

		%if %eval(&scriptName = Get_LinkedIn_Data_Weekly) %then %do;
			proc sql noprint;
				select count(*) into :nRaw trimmed from final.B2B_LinkedIn_Raw where Date >= "&Campaign_StartDate"d;
				select count(*) into :nCam trimmed from prod.B2B_Campaign_Master where find(ChannelDetail,'Social-LinkedIn')>0 and Date >= "&Campaign_StartDate"d;
			quit;
			%let emailBody1 = %str(Between &Campaign_StartDate and &Campaign_EndDate.: &nRaw rows added to b2b_linkedin_raw and &nCam rows added to b2b_campaign_master.);
			%let emailBody2 = %str(Raw data source: LinkedIn Campaign Master manual extracts.);
		%end;
		%else %if %eval(&scriptName = Get_Display_Data_Weekly) %then %do;
			proc sql noprint;
				select count(*) into :nRaw trimmed from final.B2B_Display_Raw where Date >= "&Campaign_StartDate"d;
				select count(*) into :nCam trimmed from prod.B2B_Campaign_Master where Channel = 'Display' and Date >= "&Campaign_StartDate"d;
			quit;
			%let emailBody1 = %str(Between &Campaign_StartDate and &Campaign_EndDate.: &nRaw rows added to b2b_display_raw and &nCam rows added to b2b_campaign_master.);
			%let emailBody2 = %str(Raw data source: &raw_data_source.);
		%end;
		%else %if %eval(&scriptName = Get_EL_Data_Weekly) %then %do;
			proc sql noprint;
				select count(*) into :nRaw trimmed from final.B2B_PaidSearch_EL_Raw where Date >= "&Campaign_StartDate"d;
				select count(*) into :nCam trimmed from prod.B2B_Campaign_Master where ChannelDetail='Paid Search-EL' and Date >= "&Campaign_StartDate"d;
			quit;
			%let emailBody1 = %str(Between &Campaign_StartDate and &Campaign_EndDate.: &nRaw rows added to b2b_paidsearch_EL_raw and &nCam rows added to b2b_campaign_master.);
			%let emailBody2 = %str(Raw data source: &raw_data_source.);
		%end;
		%else %if %eval(&scriptName = Get_PaidSearch_Data_Weekly) %then %do;
			proc sql noprint;
				select count(*) into :nRaw trimmed from final.b2b_paidsearch_raw where Date >= "&Campaign_StartDate"d; 
				select count(*) into :nCamLG trimmed from prod.B2B_Campaign_Master where Date >= "&Campaign_StartDate"d and ChannelDetail='Paid Search-LG'; 
				select count(*) into :nCamSB trimmed from prod.B2B_Campaign_Master where Date >= "&Campaign_StartDate"d and ChannelDetail='Paid Search-SB'; 
				select count(*) into :nCamOT trimmed from prod.B2B_Campaign_Master where Date >= "&Campaign_StartDate"d and Channel='Paid Search' and ChannelDetail not in ('Paid Search-LG','Paid Search-SB','Paid Search-EL'); 
			quit;
			%let emailBody1 = %str(Between &Campaign_StartDate and &Campaign_EndDate.: &nRaw rows added to b2b_paidsearch_raw. Added &nCamLG Paid Search-LG rows, &nCamSB Paid Search-SB rows, and &nCamOT other Paid Search rows to b2b_campaign_master.);
			%let emailBody2 = %str(Raw data source: &the_name weekly extract from SA360 API);
		%end;
		%else %if %eval(&scriptName = Get_GA_Data_Weekly) %then %do;
			proc sql noprint;
				select distinct count(*) into :nRaw trimmed from prod.b2b_betterway_master where Date >= "&Campaign_StartDate"d; 
			quit;
			%let emailBody1 = %str(Between &Campaign_StartDate and &Campaign_EndDate.: &nRaw rows added to b2b_betterway_master.);
			%let emailBody2 = %str(Raw data source: Google Analytics API);
		%end;
		%else %if %eval(&scriptName = Get_GA_Campaign_Data_Weekly) %then %do;
			proc sql noprint;
				select distinct count(*) into :nRaw trimmed from archive.b2b_campaign_GAdata where Date >= "&Campaign_StartDate"d; /* Date > "&LastDate_OldNum"d*/
			quit;
			%let emailBody1 = %str(Between &Campaign_StartDate and &Campaign_EndDate.: &nRaw rows added to archive.b2b_campaign_GAdata.); /* &StartDate_Num and &yesterday. */
			%let emailBody2 = %str(Raw data source: Google Analytics API. New UTM Tags not seen in last 90 days in attached file.);
		%end;

		filename outbox email &sentFrom.;
		data _null_;
			file outbox
			to=&sentTo.
			subject=" SUCCESSFUL: Exec &scriptName."
			attach=(&attachFreqTable.
					&attachLog.);
			put " ";
			put "&emailBody1.";
			put " ";
			put "&emailBody2.";
			put " ";
			run;

	%end;

	%else %if &Nnew=0 or &cancel=cancel %then %do; /* No new records added to file */
		filename outbox email &sentFrom.;
		data _null_;
			file outbox
			to=&sentTo.
			subject=" FAILURE: Exec &scriptName."
			attach=(&attachLog.);
			put " ";
			put "&error_rsn.";
			put " ";
		run;
	%end;

	%else %do;
			filename outbox email &sentFrom.;
			data _null_;
				file outbox
				to=&sentTo.
				subject=" FAILURE: Exec &scriptName."
				attach=(&attachLog.);
				put " ";
				put "Unknown reason.";
				put " ";
			run;
	%end;

%mend;

 
