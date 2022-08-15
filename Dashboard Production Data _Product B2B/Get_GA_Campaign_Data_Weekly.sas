/****************************************************************************************************/
/*  Program Name:       Get_GA_Campaign_Data_Weekly.sas                                             */
/*                                                                                                  */
/*  Date Created:       April 8, 2021                                                               */
/*                                                                                                  */
/*  Created By:         Elle Haynes                                                                 */
/*                                                                                                  */
/*  Purpose:            Compiles daily data from Better Way for the B2B Dashboard.                  */
/*                                                                                                  */
/*  Inputs:             This script can run on schedule without input.                              */
/*                                                                                                  */
/* -------------------------------------------------------------------------------------------------*/	
/*  Notes:              Based on template "Exec Get_GA_Data API Macro.sas"                          */
/* -------------------------------------------------------------------------------------------------*/
/*  Date Modified:      April 8, 2021                                                               */
/*  Modified by:        Elle Haynes                                                                 */
/*  Description:        Added 41 new metrics. goal18 from the B2B Copied KP View, and goal1-20 and  */
/*                      goalvalue1-20 from the B2B Copied KP View - Unique Goals View.              */
/*                                                                                                  */
/*  Date Modified:      October 11, 2021                                                            */
/*  Modified by:        Elle Haynes                                                                 */
/*  Description:        Removed goalvalue1-20 and replaced with the totaled version, goalValueAll.  */
/*                      Added the Virtual Complete and KP Difference on-page contact form clicks.   */
/*                                                                                                  */
/*  Date Modified:      January 12, 2022                                                            */
/*  Modified by:        Elle Haynes                                                                 */
/*  Description:        Replaced the segment to only filter to Session Duration ne 0 (User). The    */
/*                      original segment filter was excluding new subdomains.                       */
/****************************************************************************************************/

%global 
		client_id              access_token 
		time_token_refreshed   time_token_expires
		retry                  retryToken             errorCode
		counter                errorCounter           errorCounter_sleep
		dimensions             metrics                names
		formats                informats                               
		number_of_dimensions   number_of_metrics
		rollup_dimensions      rollup_metrics
		output_file_path       output_file_name
		startdate              enddate
        addl_filters		   firstdata              lastdata;          
%let errorCode=;
%let N=;
%let Nnew=0;
%let col_master=0;
%let col_final=0;

%let yesterday=%sysfunc(putn(%eval(%sysfunc(today())-1),date9.));

%let cancel=;
%macro check_for_data(dataset,cond,err_msg);
	%if &cancel= and %sysfunc(exist(&dataset.)) %then %do;
		proc sql noprint; select distinct count(*) into :N from &dataset.; quit;
		%if %eval(&N.&cond.) %then %do;
			%put ERROR: &err_msg..;
			%let cancel=cancel;
		%end;
		%else %do;
			%put &dataset. is OK! Continuing...;
			%let cancel=&cancel.;
		%end;
	%end;
	%else %do;
		%put ERROR: &err_msg..;
		%let cancel=cancel;
	%end;
%mend;

/* -------------------------------------------------------------------------------------------------*/
/*  Load stored macros.                                                                             */
/* -------------------------------------------------------------------------------------------------*/

options source2 orientation=portrait;
%include "/gpfsFS2/sasdata/adhoc/po/imca/digital/code/Access/SAS_Macro_RefreshToken.sas"; *%refreshToken;
%include "/gpfsFS2/sasdata/adhoc/po/imca/digital/code/Access/SAS_Macro_CheckToken.sas"; *%checkToken;
%include "/gpfsFS2/sasdata/adhoc/po/imca/digital/code/Access/SAS_Macro_APIvariablePrep.sas"; *%APIvariablePrep;
%include "/gpfsFS2/sasdata/adhoc/po/imca/digital/code/Access/SAS_Macro_Email.sas"; 
%include "/gpfsFS2/sasdata/nfs/ndc_grid/po_imca_digital/EHaynes/B2B Dashboard Data Processing/_GitHub Repository B2B/SAS_Macro_GetGAData.sas"; *%GetGAData;

/* -------------------------------------------------------------------------------------------------*/
/*  Refresh the access-token, which is valid for 60 minutes.                                        */
/* -------------------------------------------------------------------------------------------------*/

	%refreshToken;

/* -------------------------------------------------------------------------------------------------*/
/*  Audience segments.                                                                              */
/* -------------------------------------------------------------------------------------------------*/

%let allCampaign=		%sysfunc(urlencode(%str(gaid::vG24CfSeQWq_8QOX9uwCqg))); /* session duration not 0 */

/* -------------------------------------------------------------------------------------------------*/
/*  Libraries.                                                                                      */
/* -------------------------------------------------------------------------------------------------*/

%let output_file_path= /gpfsFS2/sasdata/nfs/ndc_grid/po_imca_digital/EHaynes/B2B Dashboard Data Processing/Google Analytics;
libname ga "&output_file_path"; 

%let final_file_path= /gpfsFS2/sasdata/adhoc/po/imca/product/B2B;
libname final "&final_file_path";
libname archive "&final_file_path/Archive"; 

%let production_path= /gpfsFS2/sasdata/nfs/ndc_grid/po_imca_product/B2B;
libname prod "&production_path";

filename old_log "&output_file_path/LOG Get_GA_Campaign_Data_Weekly.txt";
data _null_; rc=fdelete("old_log"); put rc=; run;
proc printto log="&output_file_path/LOG Get_GA_Campaign_Data_Weekly.txt"; run;

/* -------------------------------------------------------------------------------------------------*/
/*                                                                                                  */
/*                                                                                                  */
/*                                    Update B2B_campaign_GAdata                                    */
/*                                Used to update B2B_campaign_master                                */
/*                                                                                                  */
/*                                                                                                  */
/* -------------------------------------------------------------------------------------------------*/

%let error_rsn=Error getting last date from B2B_campaign_GAdata;

	proc sql noprint;
		select distinct 
			max(Date) format date9.
		,	max(Date)+1 format date9.
		into
			:LastDate_OldNum,
			:StartDate_Num
		from archive.b2b_campaign_GAdata;
	quit;

	%put Last data in b2b_campaign_GAdata &LastDate_OldNum;

/* -------------------------------------------------------------------------------------------------*/
/*                                                                                                  */
/*                                                                                                  */
/*                                   Pull m1: First set of metrics                                  */
/*                                                                                                  */
/*                                                                                                  */
/* -------------------------------------------------------------------------------------------------*/

%let error_rsn=Error during pull m1;

/* -------------------------------------------------------------------------------------------------*/
/*  Dimensions                                                                                      */
/* -------------------------------------------------------------------------------------------------*/

	%let i=1;
	%let var&i=          SourceMedium;
	%let informat_var&i= $100.;
	%let format_var&i=   $100.;

	%let i=%eval(&i+1);
	%let var&i=          Campaign;
	%let informat_var&i= $250.;
	%let format_var&i=   $250.;

	%let i=%eval(&i+1);
	%let var&i=          adContent;
	%let informat_var&i= $200.;
	%let format_var&i=   $200.;

	%let i=%eval(&i+1);
	%let var&i=          keyword;
	%let informat_var&i= $250.;
	%let format_var&i=   $250.;

	%let number_of_dimensions=&i;

/* -------------------------------------------------------------------------------------------------*/
/*  Metrics                                                                                         */
/* -------------------------------------------------------------------------------------------------*/

	%let i=%eval(&i+1);
	%let var&i=          Users;
	%let informat_var&i= 8.;
	%let format_var&i=   8.;

	%let i=%eval(&i+1);
	%let var&i=          newUsers;
	%let informat_var&i= 8.;
	%let format_var&i=   8.;	

	%let i=%eval(&i+1);
	%let var&i=          sessions;
	%let informat_var&i= 8.;
	%let format_var&i=   8.;	

	%let i=%eval(&i+1);
	%let var&i=          sessionDuration;
	%let informat_var&i= 8.;
	%let format_var&i=   mmss.;	

	%let i=%eval(&i+1);
	%let var&i=          bounces;
	%let informat_var&i= 8.;
	%let format_var&i=   8.;	

	%let i=%eval(&i+1);
	%let var&i=          uniquePageviews;
	%let informat_var&i= 8.;
	%let format_var&i=   8.;		

	%let number_of_metrics=%eval(&i-&number_of_dimensions);

/* -------------------------------------------------------------------------------------------------*/
/*  Execute.                                                                                        */
/* -------------------------------------------------------------------------------------------------*/

	%GetGAData(chooseSegment=&allCampaign,
				chooseView=Default,
				addl_filters=,
				level=day,
				StartDate=&StartDate_Num,
				EndDate=&yesterday,
				output_file_path=&output_file_path,
				output_file_name=b2b_campaign_GAdata_m1);

/* -------------------------------------------------------------------------------------------------*/
/*                                                                                                  */
/*                                                                                                  */
/*                                  Pull m2: Second set of metrics                                  */
/*                                                                                                  */
/*                                                                                                  */
/* -------------------------------------------------------------------------------------------------*/

%let error_rsn=Error during pull m2;

/* -------------------------------------------------------------------------------------------------*/
/*  Dimensions                                                                                      */
/* -------------------------------------------------------------------------------------------------*/

	%let i=1;
	%let var&i=          SourceMedium;
	%let informat_var&i= $100.;
	%let format_var&i=   $100.;

	%let i=%eval(&i+1);
	%let var&i=          Campaign;
	%let informat_var&i= $250.;
	%let format_var&i=   $250.;

	%let i=%eval(&i+1);
	%let var&i=          adContent;
	%let informat_var&i= $200.;
	%let format_var&i=   $200.;

	%let i=%eval(&i+1);
	%let var&i=          keyword;
	%let informat_var&i= $250.;
	%let format_var&i=   $250.;

	%let number_of_dimensions=&i;

/* -------------------------------------------------------------------------------------------------*/
/*  Metrics                                                                                         */
/* -------------------------------------------------------------------------------------------------*/

	%let i=%eval(&i+1);
	%let var&i=          goal7Completions; 
	%let informat_var&i= 8.;
	%let format_var&i=   8.;

	%let i=%eval(&i+1);
	%let var&i=          goal8Completions;
	%let informat_var&i= 8.;
	%let format_var&i=   8.;

	%let number_of_metrics=%eval(&i-&number_of_dimensions);

/* -------------------------------------------------------------------------------------------------*/
/*  Execute.                                                                                        */
/* -------------------------------------------------------------------------------------------------*/

	%GetGAData(chooseSegment=&allCampaign,
	    	    chooseView=OldGoals,
				addl_filters=,
				level=day,
				StartDate=&StartDate_Num,
				EndDate=&yesterday,
				output_file_path=&output_file_path,
				output_file_name=b2b_campaign_GAdata_m2);

/* -------------------------------------------------------------------------------------------------*/
/*                                                                                                  */
/*                                                                                                  */
/*                                  Pull m3: Third set of metrics                                   */
/*                                                                                                  */
/*                                                                                                  */
/* -------------------------------------------------------------------------------------------------*/

%let error_rsn=Error during pull m3;

/* -------------------------------------------------------------------------------------------------*/
/*  Dimensions                                                                                      */
/* -------------------------------------------------------------------------------------------------*/

	%let i=1;
	%let var&i=          SourceMedium;
	%let informat_var&i= $100.;
	%let format_var&i=   $100.;

	%let i=%eval(&i+1);
	%let var&i=          Campaign;
	%let informat_var&i= $250.;
	%let format_var&i=   $250.;

	%let i=%eval(&i+1);
	%let var&i=          adContent;
	%let informat_var&i= $200.;
	%let format_var&i=   $200.;

	%let i=%eval(&i+1);
	%let var&i=          keyword;
	%let informat_var&i= $250.;
	%let format_var&i=   $250.;

	%let number_of_dimensions=&i;

/* -------------------------------------------------------------------------------------------------*/
/*  Metrics                                                                                         */
/* -------------------------------------------------------------------------------------------------*/

	%let i=%eval(&i+1);
	%let var&i=          goal1Completions;
	%let informat_var&i= 8.;
	%let format_var&i=   8.;

	%let i=%eval(&i+1);
	%let var&i=          goal2Completions;
	%let informat_var&i= 8.;
	%let format_var&i=   8.;

	%let i=%eval(&i+1);
	%let var&i=          goal3Completions;
	%let informat_var&i= 8.;
	%let format_var&i=   8.;

	%let i=%eval(&i+1);
	%let var&i=          goal4Completions;
	%let informat_var&i= 8.;
	%let format_var&i=   8.;

	%let i=%eval(&i+1);
	%let var&i=          goal5Completions;
	%let informat_var&i= 8.;
	%let format_var&i=   8.;

	%let i=%eval(&i+1);
	%let var&i=          goal6Completions;
	%let informat_var&i= 8.;
	%let format_var&i=   8.;	

	%let number_of_metrics=%eval(&i-&number_of_dimensions);

/* -------------------------------------------------------------------------------------------------*/
/*  Execute.                                                                                        */
/* -------------------------------------------------------------------------------------------------*/

	%GetGAData(chooseSegment=&allCampaign,
				chooseView=Default,
				addl_filters=,
				level=day,
				StartDate=&StartDate_Num,
				EndDate=&yesterday,
				output_file_path=&output_file_path,
				output_file_name=b2b_campaign_GAdata_m3);

/* -------------------------------------------------------------------------------------------------*/
/*                                                                                                  */
/*                                                                                                  */
/*                                  Pull m4: Fourth set of metrics                                  */
/*                                                                                                  */
/*                                                                                                  */
/* -------------------------------------------------------------------------------------------------*/

%let error_rsn=Error during pull m4;

/* -------------------------------------------------------------------------------------------------*/
/*  Dimensions                                                                                      */
/* -------------------------------------------------------------------------------------------------*/

	%let i=1;
	%let var&i=          SourceMedium;
	%let informat_var&i= $100.;
	%let format_var&i=   $100.;

	%let i=%eval(&i+1);
	%let var&i=          Campaign;
	%let informat_var&i= $250.;
	%let format_var&i=   $250.;

	%let i=%eval(&i+1);
	%let var&i=          adContent;
	%let informat_var&i= $200.;
	%let format_var&i=   $200.;

	%let i=%eval(&i+1);
	%let var&i=          keyword;
	%let informat_var&i= $250.;
	%let format_var&i=   $250.;

	%let number_of_dimensions=&i;

/* -------------------------------------------------------------------------------------------------*/
/*  Metrics                                                                                         */
/* -------------------------------------------------------------------------------------------------*/

	%let i=%eval(&i+1);
	%let var&i=          goal7Completions;
	%let informat_var&i= 8.;
	%let format_var&i=   8.;

	%let i=%eval(&i+1);
	%let var&i=          goal8Completions;
	%let informat_var&i= 8.;
	%let format_var&i=   8.;

	%let i=%eval(&i+1);
	%let var&i=          goal9Completions;
	%let informat_var&i= 8.;
	%let format_var&i=   8.;

	%let i=%eval(&i+1);
	%let var&i=          goal10Completions;
	%let informat_var&i= 8.;
	%let format_var&i=   8.;

	%let i=%eval(&i+1);
	%let var&i=          goal11Completions;
	%let informat_var&i= 8.;
	%let format_var&i=   8.;

	%let i=%eval(&i+1);
	%let var&i=          goal12Completions;
	%let informat_var&i= 8.;
	%let format_var&i=   8.;	

	%let number_of_metrics=%eval(&i-&number_of_dimensions);

/* -------------------------------------------------------------------------------------------------*/
/*  Execute.                                                                                        */
/* -------------------------------------------------------------------------------------------------*/

	%GetGAData(chooseSegment=&allCampaign,
				chooseView=Default,
				addl_filters=,
				level=day,
				StartDate=&StartDate_Num,
				EndDate=&yesterday,
				output_file_path=&output_file_path,
				output_file_name=b2b_campaign_GAdata_m4);

/* -------------------------------------------------------------------------------------------------*/
/*                                                                                                  */
/*                                                                                                  */
/*                                  Pull m5: Fifth set of metrics                                   */
/*                                                                                                  */
/*                                                                                                  */
/* -------------------------------------------------------------------------------------------------*/

%let error_rsn=Error during pull m5;

/* -------------------------------------------------------------------------------------------------*/
/*  Dimensions                                                                                      */
/* -------------------------------------------------------------------------------------------------*/

	%let i=1;
	%let var&i=          SourceMedium;
	%let informat_var&i= $100.;
	%let format_var&i=   $100.;

	%let i=%eval(&i+1);
	%let var&i=          Campaign;
	%let informat_var&i= $250.;
	%let format_var&i=   $250.;

	%let i=%eval(&i+1);
	%let var&i=          adContent;
	%let informat_var&i= $200.;
	%let format_var&i=   $200.;

	%let i=%eval(&i+1);
	%let var&i=          keyword;
	%let informat_var&i= $250.;
	%let format_var&i=   $250.;

	%let number_of_dimensions=&i;

/* -------------------------------------------------------------------------------------------------*/
/*  Metrics                                                                                         */
/* -------------------------------------------------------------------------------------------------*/

	%let i=%eval(&i+1);
	%let var&i=          goal13Completions;
	%let informat_var&i= 8.;
	%let format_var&i=   8.;

	%let i=%eval(&i+1);
	%let var&i=          goal14Completions;
	%let informat_var&i= 8.;
	%let format_var&i=   8.;

	%let i=%eval(&i+1);
	%let var&i=          goal15Completions;
	%let informat_var&i= 8.;
	%let format_var&i=   8.;

	%let i=%eval(&i+1);
	%let var&i=          goal16Completions;
	%let informat_var&i= 8.;
	%let format_var&i=   8.;

	%let i=%eval(&i+1);
	%let var&i=          goal17Completions;
	%let informat_var&i= 8.;
	%let format_var&i=   8.;

	%let i=%eval(&i+1);
	%let var&i=          goal18Completions;
	%let informat_var&i= 8.;
	%let format_var&i=   8.;	

	%let number_of_metrics=%eval(&i-&number_of_dimensions);

/* -------------------------------------------------------------------------------------------------*/
/*  Execute.                                                                                        */
/* -------------------------------------------------------------------------------------------------*/

	%GetGAData(chooseSegment=&allCampaign,
				chooseView=Default,
				addl_filters=,
				level=day,
				StartDate=&StartDate_Num,
				EndDate=&yesterday,
				output_file_path=&output_file_path,
				output_file_name=b2b_campaign_GAdata_m5);

/* -------------------------------------------------------------------------------------------------*/
/*                                                                                                  */
/*                                                                                                  */
/*                                  Pull m6: Sixth set of metrics                                   */
/*                                                                                                  */
/*                                                                                                  */
/* -------------------------------------------------------------------------------------------------*/

%let error_rsn=Error during pull m6;

/* -------------------------------------------------------------------------------------------------*/
/*  Dimensions                                                                                      */
/* -------------------------------------------------------------------------------------------------*/

	%let i=1;
	%let var&i=          SourceMedium;
	%let informat_var&i= $100.;
	%let format_var&i=   $100.;

	%let i=%eval(&i+1);
	%let var&i=          Campaign;
	%let informat_var&i= $250.;
	%let format_var&i=   $250.;

	%let i=%eval(&i+1);
	%let var&i=          adContent;
	%let informat_var&i= $200.;
	%let format_var&i=   $200.;

	%let i=%eval(&i+1);
	%let var&i=          keyword;
	%let informat_var&i= $250.;
	%let format_var&i=   $250.;

	%let number_of_dimensions=&i;

/* -------------------------------------------------------------------------------------------------*/
/*  Metrics                                                                                         */
/* -------------------------------------------------------------------------------------------------*/

	%let i=%eval(&i+1);
	%let var&i=          goal19Completions;
	%let informat_var&i= 8.;
	%let format_var&i=   8.;

	%let i=%eval(&i+1);
	%let var&i=          goal20Completions;
	%let informat_var&i= 8.;
	%let format_var&i=   8.;

	%let i=%eval(&i+1);
	%let var&i=          goalValueAll;
	%let informat_var&i= comma8.2;
	%let format_var&i=   comma8.2;

	%let number_of_metrics=%eval(&i-&number_of_dimensions);

/* -------------------------------------------------------------------------------------------------*/
/*  Execute.                                                                                        */
/* -------------------------------------------------------------------------------------------------*/

	%GetGAData(chooseSegment=&allCampaign,
				chooseView=Default,
				addl_filters=,
				level=day,
				StartDate=&StartDate_Num,
				EndDate=&yesterday,
				output_file_path=&output_file_path,
				output_file_name=b2b_campaign_GAdata_m6);

/* -------------------------------------------------------------------------------------------------*/
/*                                                                                                  */
/*                                                                                                  */
/*                                    Clean and re-name goals.                                      */
/*                                                                                                  */
/*                                                                                                  */
/* -------------------------------------------------------------------------------------------------*/

	* Merge;
	data ga.m3_m6_combined;

		merge ga.b2b_campaign_GAdata_m3
		 	  ga.b2b_campaign_GAdata_m4 
			  ga.b2b_campaign_GAdata_m5 
			  ga.b2b_campaign_GAdata_m6
			  ;
		by Date SourceMedium Campaign adContent keyword;

	run;

	* Re-name goals depending on which view they're from;
	data ga.b2b_campaign_GAdata_m3_m6;

		set ga.m3_m6_combined;

		* Replace missing numeric w/ 0;
		 array change _numeric_;
	        do over change;
	            if change=. then change=0;
	        end;

		rename
			
			/* Goal Completions (Unweighted)*/
			goal2completions=Shop_Download
			goal16completions=ConvertNonSubmit_SSQ 
			goal9completions=SB_MAS_Leads 
			goal1completions=Shop_Explore
			goal4completions=Shop_Interact
			goal7completions=Shop_Read

			goal3completions=ConvertNonSubmit_Quote
			goal5completions=ConvertSubmit_Quote
			goal6completions=ConvertNonSubmit_Contact
			goal8completions=ConvertSubmit_Contact
			goal13completions=Convert_Call
			
			goal12completions=Learn_Download
/*			goal10completions=Exit */
			goal14completions=Learn_Explore
			goal20completions=ManageAccount_BCSSP 
			goal15completions=Learn_Interact
			goal11completions=Learn_Read
			goal17completions=Learn_Save
			goal18completions=Learn_Watch
			
			goal19completions=Share_All
			
			/* Goal Value (Weighted) */
			goalValueAll=goalValue
			;

		drop goal10completions;

	run;

	%check_for_data(ga.b2b_campaign_GAdata_m3_m6,=0,No records found in b2b_campaign_GAdata_m3_m6);

	proc delete data=ga.b2b_campaign_GAdata_m3; run &cancel.;
	proc delete data=ga.b2b_campaign_GAdata_m4; run &cancel.;
	proc delete data=ga.b2b_campaign_GAdata_m5; run &cancel.;
	proc delete data=ga.b2b_campaign_GAdata_m6; run &cancel.;
	proc delete data=ga.m3_m6_combined; run &cancel.;

%if &cancel= %then %do; /* (1) Conditionally execute the next steps. End process here if condition not met */

/* -------------------------------------------------------------------------------------------------*/
/*                                                                                                  */
/*                                                                                                  */
/*                                        Pull a1: Event pull                                       */
/*                                                                                                  */
/*                                                                                                  */
/* -------------------------------------------------------------------------------------------------*/

%let error_rsn=Error during pull a1;

/* -------------------------------------------------------------------------------------------------*/
/*  Dimensions                                                                                      */
/* -------------------------------------------------------------------------------------------------*/

	%let i=1;
	%let var&i=          SourceMedium;
	%let informat_var&i= $100.;
	%let format_var&i=   $100.;

	%let i=%eval(&i+1);
	%let var&i=          Campaign;
	%let informat_var&i= $250.;
	%let format_var&i=   $250.;

	%let i=%eval(&i+1);
	%let var&i=          adContent;
	%let informat_var&i= $200.;
	%let format_var&i=   $200.;

	%let i=%eval(&i+1);
	%let var&i=          keyword;
	%let informat_var&i= $250.;
	%let format_var&i=   $250.;

	%let i=%eval(&i+1);
	%let var&i=          eventCategory;
	%let informat_var&i= $50.;
	%let format_var&i=   $50.;

	%let i=%eval(&i+1);
	%let var&i=          eventAction;
	%let informat_var&i= $50.;
	%let format_var&i=   $50.;

	%let i=%eval(&i+1);
	%let var&i=          eventLabel;
	%let informat_var&i= $200.;
	%let format_var&i=   $200.;

	%let number_of_dimensions=&i;

/* -------------------------------------------------------------------------------------------------*/
/*  Metrics                                                                                         */
/* -------------------------------------------------------------------------------------------------*/

	%let i=%eval(&i+1);
	%let var&i=          uniqueEvents;
	%let informat_var&i= 8.;
	%let format_var&i=   8.;

	%let number_of_metrics=%eval(&i-&number_of_dimensions);

/* -------------------------------------------------------------------------------------------------*/
/*  Execute.                                                                                        */
/* -------------------------------------------------------------------------------------------------*/

	%GetGAData(chooseSegment=&allCampaign,
				chooseView=Default,
				addl_filters=,
				level=day,
				StartDate=&StartDate_Num,
				EndDate=&yesterday,
				output_file_path=&output_file_path,
				output_file_name=b2b_campaign_GAdata_a1);

	%check_for_data(ga.b2b_campaign_GAdata_a1,=0,No records found in b2b_campaign_GAdata_a1);

%end;
%if &cancel= %then %do; /* (2) */

	proc sql;
	create table ga.b2b_campaign_GAdata_a1_r as
		select distinct
			Date
		,	SourceMedium
		,	Campaign
		,	adContent
		,	keyword
		/* add convert and share? add form abandonment? add engaged visit flag? */
		/* exclude exits. Just learn? also shop? */
		,	sum(case when eventCategory="Shop" then uniqueEvents else 0 end) as ShopActions_Unique
		,	sum(case when eventCategory="Learn" then uniqueEvents else 0 end) as LearnActions_Unique
/*		,	sum(case when eventCategory="Convert" then uniqueEvents else 0 end) as ConvertActions_Unique*/
/*		,	sum(case when eventCategory="Share" then uniqueEvents else 0 end) as ShareActions_Unique*/
		,	sum(case when eventLabel="VirtualComplete-OnPageQuoteForm" then uniqueEvents else 0 end) as ConvertNonSubmit_QuoteVC
		,	sum(case when eventLabel="KPDifference-OnPageQuoteForm" then uniqueEvents else 0 end) as ConvertNonSubmit_ContKPDiff
/*		,	sum(case when eventLabel="ContactFormSubmission" then uniqueEvents else 0 end) as ConvertSubmit_Contact_ev*/
/*		,	sum(case when eventAction="Call" then uniqueEvents else 0 end) as Convert_Call*/
		from ga.b2b_campaign_GAdata_a1
		group by
			Date
		,	SourceMedium
		,	Campaign
		,	adContent
		,	keyword;
	quit;

/*	proc delete data=ga.b2b_campaign_GAdata_a1; run &cancel.; */ /* Needed for new tag lookup */

/* -------------------------------------------------------------------------------------------------*/
/*                                                                                                  */
/*                                                                                                  */
/*                                   Pull a2: PromoID from Wt.mc_id                                 */
/*                                                                                                  */
/*                                                                                                  */
/* -------------------------------------------------------------------------------------------------*/

%let error_rsn=Error during pull a2;

/* -------------------------------------------------------------------------------------------------*/
/*  Dimensions                                                                                      */
/* -------------------------------------------------------------------------------------------------*/

	%let i=1;
	%let var&i=          SourceMedium;
	%let informat_var&i= $100.;
	%let format_var&i=   $100.;

	%let i=%eval(&i+1);
	%let var&i=          Campaign;
	%let informat_var&i= $250.;
	%let format_var&i=   $250.;

	%let i=%eval(&i+1);
	%let var&i=          adContent;
	%let informat_var&i= $200.;
	%let format_var&i=   $200.;

	%let i=%eval(&i+1);
	%let var&i=          keyword;
	%let informat_var&i= $250.;
	%let format_var&i=   $250.;

	%let i=%eval(&i+1);
	%let var&i=          LandingPagePath;
	%let informat_var&i= $500.;
	%let format_var&i=   $500.;

	%let number_of_dimensions=&i;

/* -------------------------------------------------------------------------------------------------*/
/*  Metrics                                                                                         */
/* -------------------------------------------------------------------------------------------------*/

	%let i=%eval(&i+1);
	%let var&i=          sessions;
	%let informat_var&i= 8.;
	%let format_var&i=   8.;

	%let number_of_metrics=%eval(&i-&number_of_dimensions);

/* -------------------------------------------------------------------------------------------------*/
/*  Execute.                                                                                        */
/* -------------------------------------------------------------------------------------------------*/

	%GetGAData(chooseSegment=&allCampaign,
				chooseView=Default,
				addl_filters=,
				level=day,
				StartDate=&StartDate_Num,
				EndDate=&yesterday,
				output_file_path=&output_file_path,
				output_file_name=b2b_campaign_GAdata_a2);

	%check_for_data(ga.b2b_campaign_GAdata_a2,=0,No records found in b2b_campaign_GAdata_a2);

%end;
%if &cancel= %then %do; /* (3) */

	proc sql;
	create table ga.b2b_campaign_GAdata_a2_r as
		select distinct
			Date
		,	SourceMedium
		,	Campaign
		,	adContent
		,	keyword
		,	max(case when find(landingPagePath,'WT.mc_id') > 0 
					and SourceMedium not in ('(direct) / (none)','organic / bing','organic / google')
				then substr(landingPagePath,index(landingPagePath,'WT.mc_id=')+9,6)
			     end) as WTmc_id format $6.
/*		,	max(case when find(landingPagePath,'kp.org') > 0 */
/*				then substr(landingPagePath,index(landingPagePath,'kp.org'))*/
/*			     end) as VanityURLReferrer format $25.*/
		from ga.b2b_campaign_GAdata_a2
		group by
			Date
		,	SourceMedium
		,	Campaign
		,	adContent
		,	keyword;
	quit;

	proc delete data=ga.b2b_campaign_GAdata_a2; run &cancel.; 

/* -------------------------------------------------------------------------------------------------*/
/*                                                                                                  */
/*                                                                                                  */
/*                                      Final table creation.                                       */
/*                                                                                                  */
/*                                                                                                  */
/* -------------------------------------------------------------------------------------------------*/

%let error_rsn=Error during raw table append.;

	proc sort data=ga.b2b_campaign_GAdata_m3_m6; by Date SourceMedium Campaign adContent keyword; run;
/*	proc sort data=ga.b2b_campaign_GAdata_a1_r; by Date SourceMedium Campaign adContent keyword; run;*/
/*	proc sort data=ga.b2b_campaign_GAdata_a2_r; by Date SourceMedium Campaign adContent keyword; run;*/

	data ga.b2b_campaign_GAdata_append;

		merge ga.b2b_campaign_GAdata_m1
		      ga.b2b_campaign_GAdata_m2(rename=(goal7Completions=goal7_Learn 
												goal8Completions=goal8_Shop
/*												goal1Completions=ConvertSubmit_Contact*/
/*												goal13Completions=ConvertSubmit_Quote*/
/*												goal17Completions=SB_MAS_Leads*/
/*												goal18Completions=ConvertNonSubmit_SSQ*/
												))
			  ga.b2b_campaign_GAdata_m3_m6
			  ga.b2b_campaign_GAdata_a1_r
			  ga.b2b_campaign_GAdata_a2_r;
		by Date SourceMedium Campaign adContent keyword;

		* Only keep data with sessions;
		if sessions=0 then delete;

	run;

	data ga.b2b_campaign_GAdata_final;

		retain
			Date
			UTM_Source
			UTM_Medium
			UTM_Campaign
			UTM_Content
			UTM_Term
			PromoId
			Users
			newUsers
			sessions
			sessionDuration
			bounces
			uniquePageviews
			goal7_Learn
			goal8_Shop
			LearnActions_Unique
			ShopActions_Unique
/*			ConvertActions_Unique*/
/*			ShareActions_Unique*/
			Learn_Explore
			Learn_Download
			Learn_Interact
			Learn_Read
			Learn_Watch
			Learn_Save
			Shop_Explore
			Shop_Download
			Shop_Interact
			Shop_Read
			ConvertNonSubmit_Contact
			ConvertNonSubmit_Quote 
			ConvertNonSubmit_QuoteVC /* new */
			ConvertNonSubmit_ContKPDiff /* new */
			ConvertNonSubmit_SSQ
			ConvertSubmit_Contact
			ConvertSubmit_Quote
			Convert_Call
			SB_MAS_Leads
			ManageAccount_BCSSP
			Share_All
			GoalValue /* new */
			;

		format goalValue comma8.2;

		set ga.b2b_campaign_GAdata_append
			(rename=(Campaign=UTM_campaign
					adContent=UTM_content
					keyword=UTM_term)
			);

		format Date mmddyy10.;

		* Supplemented missing Contact submissions with events (clicks);
		*if date <= "30JUN2020"d then ConvertSubmit_Contact = coalesce(ConvertSubmit_Contact_ev,0);
		*drop ConvertSubmit_Contact_ev;

		* Add VC on-page quote starts to other quote starts; 
		* Decided not to combine, so that we have a good comparison vs. SA360/Connex/Google Analytics;
		*ConvertNonSubmit_Quote = coalesce(ConvertNonSubmit_Quote,0)+coalesce(ConvertNonSubmit_QuoteVC,0);
		*ConvertNonSubmit_Quote_v = coalesce(ConvertNonSubmit_Quote_v,0)+(coalesce(ConvertNonSubmit_QuoteVC,0)*0.86;
		*drop ConvertNonSubmit_QuoteVC;

		* Split Source/Medium;
		UTM_Source = strip(substr(SourceMedium,1,index(SourceMedium,'/')-1));
		UTM_Medium = strip(substr(SourceMedium,index(SourceMedium,'/')+1,length(SourceMedium)));
		drop SourceMedium;

		* Standardize lowcase;
		UTM_Campaign = strip(lowcase(UTM_Campaign));
		UTM_Term = strip(lowcase(UTM_Term));

		* Parse out promo ID;
			* Paid Search;
			if find(UTM_content,'|') > 0 then PromoId = strip(put(substr(UTM_content,length(UTM_content)-5,6),8.));
			* PromoId is 6 digits;
			else if length(UTM_content) = 6 or length(UTM_campaign) = 6 or length(UTM_term) = 6 then do;
				* PromoId should be in UTM_content;
				if prxmatch('/\d{6}/',UTM_content) then PromoId = UTM_content; 
				* Other places;
				else if prxmatch('/\d{6}/',UTM_campaign) then PromoId = UTM_campaign;
				else if prxmatch('/\d{6}/',UTM_term) then PromoId = UTM_term;
			end;
			* Only Keep Digits;
			else PromoID = '';
			if PromoID = '' and WTmc_id ne '' then PromoID = WTmc_Id;
			PromoId = compress(PromoId,,'kd'); 
			if length(PromoId) ne 6 then PromoId = '';
			drop WTmc_id;

		* Replace (not set);
		if UTM_content = '(not set)' then UTM_content = '';
		if UTM_campaign = '(not set)' then UTM_campaign = '';
		if UTM_term = '(not set)' then UTM_term = '';

		* Replace missing numeric w/ 0;
		 array change _numeric_;
	        do over change;
	            if change=. then change=0;
	        end;

	run;
	%check_for_data(ga.b2b_campaign_GAdata_final,=0,No records found in b2b_campaign_GAdata_final);

	proc delete data=ga.b2b_campaign_GAdata_m1; run &cancel.;
	proc delete data=ga.b2b_campaign_GAdata_m2; run &cancel.;
	proc delete data=ga.b2b_campaign_GAdata_m3_m6; run &cancel.;
	proc delete data=ga.b2b_campaign_GAdata_a1_r; run &cancel.;
	proc delete data=ga.b2b_campaign_GAdata_a2_r; run &cancel.;
	proc delete data=ga.b2b_campaign_GAdata_append; run &cancel.;

%end;

* Check to make sure the final table has same number of columns as master;

	proc sql ;
	select nvar into :col_master from sashelp.vtable where libname = 'ARCHIVE' and memname = 'B2B_CAMPAIGN_GADATA';
	select nvar into :col_final from sashelp.vtable where libname = 'GA' and memname = 'B2B_CAMPAIGN_GADATA_FINAL';
	quit;

	%let error_rsn = Different master and final table layout;

%if &cancel= and &col_master=&col_final %then %do; /* (4) Conditionally execute the next steps. End process here if condition not met */

/* -------------------------------------------------------------------------------------------------*/
/*                                                                                                  */
/*                                                                                                  */
/*                                   Final append with historical.                                  */
/*                                                                                                  */
/*                                                                                                  */
/* -------------------------------------------------------------------------------------------------*/

%let error_rsn=Error during final table append.;

	data ga.b2b_campaign_GAdata_Temp;
		set archive.b2b_campaign_GAdata;
	run;

	proc sql;
	insert into archive.b2b_campaign_GAdata
		select distinct * from ga.b2b_campaign_GAdata_final;
	quit;

	* If you added/removed/reordered, or changed the formatting of a variable, run this instead;

/*	proc delete data=archive.b2b_campaign_GAdata; run; */
/*	data archive.b2b_campaign_GAdata;*/
/*		set ga.b2b_campaign_GAdata_final */
/*			ga.b2b_campaign_GAdata_Temp*/
/*			; */
/*	run;*/

/* -------------------------------------------------------------------------------------------------*/
/*                                                                                                  */
/*                                                                                                  */
/*                                              Archive.                                            */
/*                                                                                                  */
/*                                                                                                  */
/* -------------------------------------------------------------------------------------------------*/

	proc sql;
		select distinct count(*) into :Nnew from ga.b2b_campaign_GAdata_final;
	quit;

/* -------------------------------------------------------------------------------------------------*/
/*  Get first date/last date of the new master file.                                                */
/* -------------------------------------------------------------------------------------------------*/

	proc sql noprint;
	select distinct 
		min(Date) format mmddyy6.,
		max(Date) format mmddyy6.
		into
		:FirstData,
		:LastData
		from archive.b2b_campaign_GAdata;
	quit;

/* -------------------------------------------------------------------------------------------------*/
/*  Get last date of last master file.                                                              */
/* -------------------------------------------------------------------------------------------------*/

	proc sql noprint;
	select distinct 
		max(Date) format mmddyy6.,
		max(Date) format date9.
		into
		:LastData_Old,
		:LastDate_OldNum
		from ga.b2b_campaign_GAdata_Temp;
	quit;

/* -------------------------------------------------------------------------------------------------*/
/*  Save master file(s) --> zip archive.                                                            */
/* -------------------------------------------------------------------------------------------------*/

	data archive.Campaign_GAdata_&FirstData._&LastData;
		set archive.b2b_campaign_GAdata;
	run;

	ods package(archived) open nopf;
	ods package(archived) add file="&final_file_path/Archive/campaign_gadata_&FirstData._&LastData..sas7bdat";
	ods package(archived) publish archive properties (
		archive_name="campaign_gadata_&FirstData._&LastData..zip"
		archive_path="&final_file_path/Archive/");
	ods package(archived) close;
	proc delete data=archive.Campaign_GAdata_&FirstData._&LastData; run;

	filename old_arch "&final_file_path/Archive/campaign_gadata_&FirstData._&LastData_Old..zip";
	data _null_;
		rc=fdelete("old_arch");
		put rc=;
	run;

/* -------------------------------------------------------------------------------------------------*/
/*  Frequency Tables.                                                                               */
/* -------------------------------------------------------------------------------------------------*/ 

	options dlcreatedir;
	libname freq xlsx "&output_file_path/Frequency Tables - Get_GA_Campaign_Data_Weekly.xlsx"; run;

/* -------------------------------------------------------------------------------------------------*/
/*  Create lookup - All sources last 90 days.                                                       */
/* -------------------------------------------------------------------------------------------------*/

	* Sources from this current update;
	proc sql;
	create table lookup_sources_thisrun as
		select distinct
			case when UTM_Medium = 'cpc' then catx('-',UTM_Source,UTM_medium,substr(UTM_Term,1,75))
				else catx('-',UTM_Source,UTM_Medium,substr(UTM_Campaign,1,75),substr(UTM_Content,1,75),substr(UTM_Term,1,75)) 
				end as Source_String
		,	sum(sessions) as Visits
		from ga.b2b_campaign_gadata_final
		where UTM_Source not in ('',' ')
		group by 
			case when UTM_Medium = 'cpc' then catx('-',UTM_Source,UTM_medium,substr(UTM_Term,1,75))
				else catx('-',UTM_Source,UTM_Medium,substr(UTM_Campaign,1,75),substr(UTM_Content,1,75),substr(UTM_Term,1,75)) 
				end;
	quit;
	* Net new Sources in this update;
	proc sql;
	create table freq.'New UTM Sources'n as
		select distinct
			*
		from lookup_sources_thisrun
		where Source_String not in (select Source_String from ga.lookup_sources)
		order by Visits desc, Source_String;
	quit;
	* Update lookup;
	proc sql;
	create table ga.lookup_sources as
		select distinct
			case when UTM_Medium = 'cpc' then catx('-',UTM_Source,UTM_medium,substr(UTM_Term,1,75))
				else catx('-',UTM_Source,UTM_Medium,substr(UTM_Campaign,1,75),substr(UTM_Content,1,75),substr(UTM_Term,1,75)) 
				end as Source_String
		from archive.b2b_campaign_GAdata
		where Date > (today()-90) /* last 90 days */
			and UTM_Source not in ('',' '); 
	quit;

/* -------------------------------------------------------------------------------------------------*/
/*  Create lookup - All Better Way tags last 90 days.                                               */
/* -------------------------------------------------------------------------------------------------*/

	* Tags from this current update;
	proc sql;
	create table lookup_tag_thisrun as
		select distinct
			catx('-',eventCategory,eventAction,substr(eventLabel,1,200)) as Tag_String
		,	sum(uniqueEvents) as Actions
		from ga.b2b_campaign_gadata_a1
		group by 
			catx('-',eventCategory,eventAction,substr(eventLabel,1,200));
	quit;
	* Net new Tags in this update;
	proc sql;
	create table freq.'New BW Tags'n as
		select distinct
			*
		from lookup_tag_thisrun
		where Tag_String not in (select Tag_String from ga.lookup_tags)
		order by Actions desc, Tag_String;
	quit;
	* Lost Tags in this update;
	proc sql;
	create table freq.'Dropped BW Tags'n as
		select distinct
			*
		from ga.lookup_tags
		where Tag_String not in (select Tag_String from lookup_tag_thisrun)
			and Last_Date >= today()-90
			/* and clicks last period > 10? */
		order by Actions desc, Tag_String;
	quit;
	* Update lookup;
	proc sql;
	create table ga.lookup_tags as
		select distinct
			x.Tag_String
		,	x.Actions
		,	(x.Actions/y.Actions)-1 as Pct_Chg_Actions_WoW format percent7.2
		,	x.Last_Date
		from (
			select distinct
				Tag_String
			,	sum(Actions) as Actions
			,	max(Last_Date) as Last_Date format mmddyy10. /* update the last date seen */
			from (
				/* Older, still within 90 days */
				select distinct Tag_String,	0 as Actions, Last_Date from ga.lookup_tags where Last_Date >= today()-90
					union
				/* This update */
				select distinct Tag_String,	Actions, today() as Last_Date from lookup_tag_thisrun
				)
			group by Tag_String
			) x
		left join ga.lookup_tags y
			on x.Tag_String=y.Tag_String
		order by Actions Desc, Tag_String
		;
	quit;
	* Tags with significant action changes in this update;
	proc sql;
	create table freq.'Inspect BW Tags'n as
		select distinct
			*
		from ga.lookup_tags
		where Tag_String in (select Tag_String from lookup_tag_thisrun)
			and Actions > 10
			and (Pct_Chg_Actions_Wow >= 0.25 or Pct_Chg_Actions_Wow <= -0.25)
		order by abs(Pct_Chg_Actions_Wow) desc, Tag_String;
	quit;

	proc sql; 
		select distinct 
			count(distinct date) 
		into :days 
		from archive.b2b_campaign_GAdata
		where Date > "&LastDate_OldNum"d;
	quit;

	proc sql;
	create table freq.Date as
		select distinct
			Date
		,	case when Date>"&LastDate_OldNum"d then 1 else 0 end as New_Data
		,	sum(sessions) as Sessions
		,	sum(uniquePageviews) as uniquePageviews
		,	sum(ShopActions_Unique+LearnActions_Unique) as UniqueActions
		,	sum(uniquePageviews)/sum(sessions) as Pages_Per_Session
		,	sum(ShopActions_Unique+LearnActions_Unique)/sum(sessions) as Actions_Per_Session
		from archive.b2b_campaign_GAdata
		where Date>intnx('day',"&LastDate_OldNum"d,-&days.,'s')
		group by 
			Date
		order by 
			Date;
	quit;

	* Clean up po_imca_digital;
	* Second backup of b2b_campaign_gadata;
	ods package(archived) open nopf;
	ods package(archived) add file="&output_file_path/b2b_campaign_gadata_temp.sas7bdat";
	ods package(archived) publish archive properties (
		archive_name="b2b_campaign_gadata_temp.zip"
		archive_path="&output_file_path/");
	ods package(archived) close;
	proc delete data=ga.b2b_campaign_gadata_temp; run &cancel.;
	* Delete files from most recent update;
	proc delete data=ga.b2b_campaign_gadata_final; run &cancel.;
	proc delete data=ga.b2b_campaign_gadata_a1; run &cancel.;

%end; /* (4) No records found in b2b_campaign_GAdata_final */

/* -------------------------------------------------------------------------------------------------*/
/*  Email.                                                                                          */
/* -------------------------------------------------------------------------------------------------*/

	%let input_files = &output_file_path;
	%let Campaign_StartDate = &StartDate_Num;
	%let Campaign_EndDate = &yesterday;

	%emailB2Bdashboard(Get_GA_Campaign_Data_Weekly,
		attachFreqTableFlag=1,
		attachLogFlag=1 /*,
		sentFrom=,
		sentTo=*/
		);

	proc printto; run; /* Turn off log export to .txt */