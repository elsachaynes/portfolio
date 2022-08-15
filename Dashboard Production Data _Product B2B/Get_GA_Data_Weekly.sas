/****************************************************************************************************/
/*  Program Name:       Get_GA_Data_Weekly.sas                                                      */
/*                                                                                                  */
/*  Date Created:       Oct 27, 2020                                                                */
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
/*  Date Modified:      March 17, 2021                                                              */
/*  Modified by:        Elle Haynes                                                                 */
/*  Description:        Replaced "UsersByChannel" wih "B2B_campaign_GAdata," which adds 2           */
/*                      dimensions (adContent, keyword) for better matching to engine data, and     */
/*                      adds 10 metrics (newUsesr, sessions, sessionDuration, bounces, pageviews,   */
/*                      uniquePageviews, goal1, goal7, goal8, goal13, uniqueEvents) so that all     */
/*                      metrics for b2b_campaign_master can be sourced from a single table.         */
/*                      NOTE: "page-level" metrics and "session-level" metrics are included in a    */
/*                      single pull since we're interested in all activity that relates to engine   */
/*                      spend by tag by day.                                                        */
/*                                                                                                  */
/*  Date Modified:      April 12, 2021                                                              */
/*  Modified by:        Elle Haynes                                                                 */
/*  Description:        Added 41 new metrics. goal18 from the B2B Copied KP View, and goal1-20 and  */
/*                      goalvalue1-20 from the B2B Copied KP View - Unique Goals View.              */
/*                                                                                                  */
/*  Date Modified:      July 21, 2021                                                               */
/*  Modified by:        Elle Haynes                                                                 */
/*  Description:        Complete overhaul from one table: b2b_betterway_master to 2 tables. One for */
/*                      page/hit level metrics: b2b_betterway_pagelevel_master, and one for session */
/*                      level metrics: b2b_betterway_sesslevel_master.                              */
/*                                                                                                  */
/*  Date Modified:      January 17, 2022                                                            */
/*  Modified by:        Elle Haynes                                                                 */
/*  Description:        Added weighted_actions.                                                     */
/*                                                                                                  */
/*  Date Modified:      April 21, 2022                                                              */
/*  Modified by:        Elle Haynes                                                                 */
/*  Description:        Changed email output to use new email macro: SAS_Macro_Email.               */
/****************************************************************************************************/

	Options mlogic mprint symbolgen;

	filename old_log "/gpfsFS2/sasdata/nfs/ndc_grid/po_imca_digital/EHaynes/B2B Dashboard Data Processing/Google Analytics/LOG Get_GA_Data_Weekly.txt";
	data _null_; rc=fdelete("old_log"); put rc=; run;
	proc printto log="/gpfsFS2/sasdata/nfs/ndc_grid/po_imca_digital/EHaynes/B2B Dashboard Data Processing/Google Analytics/LOG Get_GA_Data_Weekly.txt"; run;

	%global 
			client_id              access_token 
			time_token_refreshed   time_token_expires     totalErrors
			retry                  retryToken             errorCode
			counter                errorCounter           errorCounter_sleep
			dimensions             metrics                names
			formats                informats                               
			number_of_dimensions   number_of_metrics
			rollup_dimensions      rollup_metrics
			output_file_path       output_file_name
			startdate              enddate
	        addl_filters		   firstdata              lastdata
			loopdates;   
	%let errorCode=;
	%let dt=.; *"31dec2020"d; *leave empty unless running manually;
	%let N=;
	%let Nnew=0;
	%let cancel=;
	%let Nraw=;

/* -------------------------------------------------------------------------------------------------*/
/*  Load stored macros.                                                                             */
/* -------------------------------------------------------------------------------------------------*/

	options source2 orientation=portrait;
	%include "/gpfsFS2/sasdata/adhoc/po/imca/digital/code/Access/SAS_Macro_RefreshToken.sas"; *%refreshToken;
	%include "/gpfsFS2/sasdata/adhoc/po/imca/digital/code/Access/SAS_Macro_CheckToken.sas"; *%checkToken;
	%include "/gpfsFS2/sasdata/adhoc/po/imca/digital/code/Access/SAS_Macro_APIvariablePrep.sas"; *%APIvariablePrep;
	%include "/gpfsFS2/sasdata/nfs/ndc_grid/po_imca_digital/EHaynes/B2B Dashboard Data Processing/_GitHub Repository B2B/SAS_Macro_GetGAData.sas"; *%GetGAData;

	%include "/gpfsFS2/sasdata/adhoc/po/imca/digital/code/Access/SAS_Macro_ListFiles.sas"; 
	%include "/gpfsFS2/sasdata/adhoc/po/imca/digital/code/Access/SAS_Macro_CheckForData.sas"; 
	%include "/gpfsFS2/sasdata/adhoc/po/imca/digital/code/Access/SAS_Macro_Email.sas"; 

/* -------------------------------------------------------------------------------------------------*/
/*  Refresh the access-token, which is valid for 60 minutes.                                        */
/* -------------------------------------------------------------------------------------------------*/

	%refreshToken;

/* -------------------------------------------------------------------------------------------------*/
/*  Audience segments.                                                                              */
/* -------------------------------------------------------------------------------------------------*/

	%let SM_DES=				%sysfunc(urlencode(%str(gaid::9qdyLUyrTKyXB3Gldn4P8Q)));
	%let SM_MOB=				%sysfunc(urlencode(%str(gaid::OpVPFUTBRqOIhE7TqS0VwA)));
	%let LG_DES=				%sysfunc(urlencode(%str(gaid::H0db5kJ5TcCIXif-JY9Z6A)));
	%let LG_MOB=				%sysfunc(urlencode(%str(gaid::NFCyR4x4SnOK4OzuY8s24Q)));
	%let UN_DES=				%sysfunc(urlencode(%str(gaid::PYFbWlvMTnmefEcP8bUdXA)));
	%let UN_MOB=				%sysfunc(urlencode(%str(gaid::wkpBgqS5SLGSXCwxLqbY2A)));

	%let smallBiz=				%sysfunc(urlencode(%str(gaid::XyAfpal8TumtCb2hmlUr5g))); /* bw */
	%let largeBiz=				%sysfunc(urlencode(%str(gaid::RgUuNZK9TNaoJ7xOsaHjTQ))); /* bw */ 
	%let unkSize=				%sysfunc(urlencode(%str(gaid::CmnUVnPtQIC0264FA6r7ZQ))); /* bw */ 

	%let SM_HP=                 %sysfunc(urlencode(%str(gaid::U9EIH-GEQ6-YP6yggI4Ugw))); /* health-plan site section */
	%let LG_HP=                 %sysfunc(urlencode(%str(gaid::j-yyU6qbSIOq78nWcinOUg))); /* health-plan site section */ 
	%let UN_HP=                 %sysfunc(urlencode(%str(gaid::_AWO-HYXRwup9C8mF-qCBQ))); /* health-plan site section */ 

	%let SM_SBHP=			    %sysfunc(urlencode(%str(gaid::Ow49mbdESom0cNf6KtOLXg))); /* small biz health plans site section */
	%let LG_SBHP=			    %sysfunc(urlencode(%str(gaid::WGXvv5aORCuVxAW0H4HVwg))); /* small biz health plans site section */

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

/* -------------------------------------------------------------------------------------------------*/
/*                                                                                                  */
/*                                                                                                  */
/*                                    Update B2B_betterway_master                                   */
/*                                                                                                  */
/*                                                                                                  */
/* -------------------------------------------------------------------------------------------------*/

	proc sql ;
		select distinct
			max(Date) format mmddyy6.
		,	max(Date)+1 format date9.
		,	today()-1 format date9.
		into :LastData_Old trimmed,
			 :Campaign_StartDate trimmed,
			 :Campaign_EndDate trimmed
		from prod.B2B_BetterWay_Master
		where year(today()) - year(Date) < 1; *Limit to current year & last year;
	quit;

	%if &Campaign_StartDate= %then %do;
		%put ERROR: Campaign_StartDate not found.;
		endsas;
	%end;

/* -------------------------------------------------------------------------------------------------*/
/*                                                                                                  */
/*                                                                                                  */
/*                                            Event table                                           */
/*                                          Page-level call                                         */
/*                                                                                                  */
/*                                                                                                  */
/* -------------------------------------------------------------------------------------------------*/

%let error_rsn=Error during pull e1;

/* -------------------------------------------------------------------------------------------------*/
/*  Dimensions                                                                                      */
/* -------------------------------------------------------------------------------------------------*/

	%let i=1;
	%let var&i=          SourceMedium; /* need this for determining channel */
	%let informat_var&i= $100.;
	%let format_var&i=   $100.;

	%let i=%eval(&i+1);
	%let var&i=          Campaign; /* need this for determining channel and identifying specific campaign */
	%let informat_var&i= $250.;
	%let format_var&i=   $250.;

	%let i=%eval(&i+1);
	%let var&i=          adContent; /* needed to join to SalesConnect for funnel report */
	%let informat_var&i= $200.;
	%let format_var&i=   $200.;

	%let i=%eval(&i+1);
	%let var&i=          pagePath; /* needed for funnel report */
	%let informat_var&i= $300.;
	%let format_var&i=   $300.;	

	%let i=%eval(&i+1);
	%let var&i=          landingPagePath; /* need this for joining to session data */
	%let informat_var&i= $300.;
	%let format_var&i=   $300.;	

	%let i=%eval(&i+1);
	%let var&i=          Metro; /* requested filter */
	%let informat_var&i= $200.;
	%let format_var&i=   $200.;

	%let i=%eval(&i+1);
	%let var&i=          userType; /* requested filter */
	%let informat_var&i= $17.;
	%let format_var&i=   $17.;

	%let number_of_dimensions=&i;

/* -------------------------------------------------------------------------------------------------*/
/*  Metrics                                                                                         */
/* -------------------------------------------------------------------------------------------------*/

	%let i=%eval(&i+1);
	%let var&i=          uniqueEvents; /* count of unique actions by Shop, Learn, Convert, Share */
	%let informat_var&i= 8.;
	%let format_var&i=   8.;	

	%let number_of_metrics=%eval(&i-&number_of_dimensions);

/* -------------------------------------------------------------------------------------------------*/
/*  Execute.                                                                                        */
/* -------------------------------------------------------------------------------------------------*/

	* Filter by eventCategory;
	%let e1filter1=%sysfunc(urlencode(ga:eventCategory==Shop)); 
	%let e1filter2=%sysfunc(urlencode(ga:eventCategory==Learn)); 
	%let e1filter3=%sysfunc(urlencode(ga:eventCategory==Convert)); 
	%let e1filter4=%sysfunc(urlencode(ga:eventCategory==Share)); 
	/* add eventCategory==Form Abandonment? */
	/* add eventAction==Engaged Visit Flag? */

	* Filter by eventLabel;
	%let e1filter5=%sysfunc(urlencode(ga:eventLabel==VirtualComplete-OnPageQuoteForm)); 
	%let e1filter6=%sysfunc(urlencode(ga:eventLabel==KPDifference-OnPageContactForm));

	%macro exec(exec_segment,
				exec_filter,
				exec_output_file_name,
				exec_business_size,
				exec_device,
				exec_rename);

		%GetGAData(chooseSegment=&&exec_segment,
						chooseView=Default,
						addl_filters=&&exec_filter,
						level=day,
						StartDate=&Campaign_StartDate,
						EndDate=&Campaign_EndDate,
						output_file_path=&output_file_path,
						output_file_name=&&exec_output_file_name);
					%if(%sysfunc(exist(ga.&&exec_output_file_name.))) %then %do;
						data ga.&&exec_output_file_name.; 
							set ga.&&exec_output_file_name.; 
							Business_Size = "&exec_business_size."; 
							DeviceType = "&exec_device"; 
							rename uniqueEvents = &exec_rename;
						run;
					%end;
					%else %do;
						data ga.&&exec_output_file_name.; 
							Business_Size = "&exec_business_size."; 
							DeviceType = "&exec_device"; 
							rename uniqueEvents = &exec_rename;
						run;
					%end;

	%mend;

* Small Business;
	* Desktop;
	%exec(&SM_DES,%bquote(&e1filter1),b2b_bw_SM_DES_e1_1,SB,Desktop,ShopActions_Unique);
	%exec(&SM_DES,%bquote(&e1filter2),b2b_bw_SM_DES_e1_2,SB,Desktop,LearnActions_Unique);
	%exec(&SM_DES,%bquote(&e1filter3),b2b_bw_SM_DES_e1_3,SB,Desktop,ConvertActions_Unique);
	%exec(&SM_DES,%bquote(&e1filter4),b2b_bw_SM_DES_e1_4,SB,Desktop,ShareActions_Unique);
	%exec(&SM_DES,%bquote(&e1filter5),b2b_bw_SM_DES_e1_5,SB,Desktop,ConvertNonSubmit_QuoteVC);
	%exec(&SM_DES,%bquote(&e1filter6),b2b_bw_SM_DES_e1_6,SB,Desktop,ConvertNonSubmit_ContKPDiff);
	* Mobile & Tablet;
	%exec(&SM_MOB,%bquote(&e1filter1),b2b_bw_SM_MOB_e1_1,SB,Mobile & Tablet,ShopActions_Unique);
	%exec(&SM_MOB,%bquote(&e1filter2),b2b_bw_SM_MOB_e1_2,SB,Mobile & Tablet,LearnActions_Unique);
	%exec(&SM_MOB,%bquote(&e1filter3),b2b_bw_SM_MOB_e1_3,SB,Mobile & Tablet,ConvertActions_Unique);
	%exec(&SM_MOB,%bquote(&e1filter4),b2b_bw_SM_MOB_e1_4,SB,Mobile & Tablet,ShareActions_Unique);
	%exec(&SM_MOB,%bquote(&e1filter5),b2b_bw_SM_MOB_e1_5,SB,Mobile & Tablet,ConvertNonSubmit_QuoteVC);
	%exec(&SM_MOB,%bquote(&e1filter6),b2b_bw_SM_MOB_e1_6,SB,Mobile & Tablet,ConvertNonSubmit_ContKPDiff);

* Large Business;
	* Desktop;
	%exec(&LG_DES,%bquote(&e1filter1),b2b_bw_LG_DES_e1_1,LG,Desktop,ShopActions_Unique);
	%exec(&LG_DES,%bquote(&e1filter2),b2b_bw_LG_DES_e1_2,LG,Desktop,LearnActions_Unique);
	%exec(&LG_DES,%bquote(&e1filter3),b2b_bw_LG_DES_e1_3,LG,Desktop,ConvertActions_Unique);
	%exec(&LG_DES,%bquote(&e1filter4),b2b_bw_LG_DES_e1_4,LG,Desktop,ShareActions_Unique);
	%exec(&LG_DES,%bquote(&e1filter5),b2b_bw_LG_DES_e1_5,LG,Desktop,ConvertNonSubmit_QuoteVC);
	%exec(&LG_DES,%bquote(&e1filter6),b2b_bw_LG_DES_e1_6,LG,Desktop,ConvertNonSubmit_ContKPDiff);
	* Mobile & Tablet;
	%exec(&LG_MOB,%bquote(&e1filter1),b2b_bw_LG_MOB_e1_1,LG,Mobile & Tablet,ShopActions_Unique);
	%exec(&LG_MOB,%bquote(&e1filter2),b2b_bw_LG_MOB_e1_2,LG,Mobile & Tablet,LearnActions_Unique);
	%exec(&LG_MOB,%bquote(&e1filter3),b2b_bw_LG_MOB_e1_3,LG,Mobile & Tablet,ConvertActions_Unique);
	%exec(&LG_MOB,%bquote(&e1filter4),b2b_bw_LG_MOB_e1_4,LG,Mobile & Tablet,ShareActions_Unique);
	%exec(&LG_MOB,%bquote(&e1filter5),b2b_bw_LG_MOB_e1_5,LG,Mobile & Tablet,ConvertNonSubmit_QuoteVC);
	%exec(&LG_MOB,%bquote(&e1filter6),b2b_bw_LG_MOB_e1_6,LG,Mobile & Tablet,ConvertNonSubmit_ContKPDiff);

* Unknown Business Size;
	* Desktop;
	%exec(&UN_DES,%bquote(&e1filter1),b2b_bw_UN_DES_e1_1,UN,Desktop,ShopActions_Unique);
	%exec(&UN_DES,%bquote(&e1filter2),b2b_bw_UN_DES_e1_2,UN,Desktop,LearnActions_Unique);
	%exec(&UN_DES,%bquote(&e1filter3),b2b_bw_UN_DES_e1_3,UN,Desktop,ConvertActions_Unique);
	%exec(&UN_DES,%bquote(&e1filter4),b2b_bw_UN_DES_e1_4,UN,Desktop,ShareActions_Unique);
	%exec(&UN_DES,%bquote(&e1filter5),b2b_bw_UN_DES_e1_5,UN,Desktop,ConvertNonSubmit_QuoteVC);
	%exec(&UN_DES,%bquote(&e1filter6),b2b_bw_UN_DES_e1_6,UN,Desktop,ConvertNonSubmit_ContKPDiff);

	* Mobile & Tablet;
	%exec(&UN_MOB,%bquote(&e1filter1),b2b_bw_UN_MOB_e1_1,UN,Mobile & Tablet,ShopActions_Unique);
	%exec(&UN_MOB,%bquote(&e1filter2),b2b_bw_UN_MOB_e1_2,UN,Mobile & Tablet,LearnActions_Unique);
	%exec(&UN_MOB,%bquote(&e1filter3),b2b_bw_UN_MOB_e1_3,UN,Mobile & Tablet,ConvertActions_Unique);
	%exec(&UN_MOB,%bquote(&e1filter4),b2b_bw_UN_MOB_e1_4,UN,Mobile & Tablet,ShareActions_Unique);
	%exec(&UN_MOB,%bquote(&e1filter5),b2b_bw_UN_MOB_e1_5,UN,Mobile & Tablet,ConvertNonSubmit_QuoteVC);
	%exec(&UN_MOB,%bquote(&e1filter6),b2b_bw_UN_MOB_e1_6,UN,Mobile & Tablet,ConvertNonSubmit_ContKPDiff);

	* Append ShopActions_Unique;
	data ga.b2b_bw_e1_1;
		format DeviceType $16.;
		set /* SM */
			ga.b2b_bw_SM_DES_e1_1
			ga.b2b_bw_SM_MOB_e1_1
			/* LG */
			ga.b2b_bw_LG_DES_e1_1
			ga.b2b_bw_LG_MOB_e1_1
			/* UN */
			ga.b2b_bw_UN_DES_e1_1
			ga.b2b_bw_UN_MOB_e1_1;
		if date ne .;
	run;
	* Append LearnActions_Unique;
	data ga.b2b_bw_e1_2;
		format DeviceType $16.;
		set /* SM */
			ga.b2b_bw_SM_DES_e1_2
			ga.b2b_bw_SM_MOB_e1_2
			/* LG */
			ga.b2b_bw_LG_DES_e1_2
			ga.b2b_bw_LG_MOB_e1_2
			/* UN */
			ga.b2b_bw_UN_DES_e1_2
			ga.b2b_bw_UN_MOB_e1_2;
		if date ne .;
	run;
	* Append ConvertActions_Unique;
	data ga.b2b_bw_e1_3;
		format DeviceType $16.;
		set /* SM */
			ga.b2b_bw_SM_DES_e1_3
			ga.b2b_bw_SM_MOB_e1_3
			/* LG */
			ga.b2b_bw_LG_DES_e1_3
			ga.b2b_bw_LG_MOB_e1_3
			/* UN */
			ga.b2b_bw_UN_DES_e1_3
			ga.b2b_bw_UN_MOB_e1_3;
		if date ne .;
	run;
	* Append ShareActions_Unique;
	data ga.b2b_bw_e1_4;
		format DeviceType $16.;
		set /* SM */
			ga.b2b_bw_SM_DES_e1_4
			ga.b2b_bw_SM_MOB_e1_4
			/* LG */
			ga.b2b_bw_LG_DES_e1_4
			ga.b2b_bw_LG_MOB_e1_4
			/* UN */
			ga.b2b_bw_UN_DES_e1_4
			ga.b2b_bw_UN_MOB_e1_4;
		if date ne .;
	run;
	* Append ConvertNonSubmit_QuoteVC;
	data ga.b2b_bw_e1_5;
		format DeviceType $16.;
		set /* SM */
			ga.b2b_bw_SM_DES_e1_5
			ga.b2b_bw_SM_MOB_e1_5
			/* LG */
			ga.b2b_bw_LG_DES_e1_5
			ga.b2b_bw_LG_MOB_e1_5
			/* UN */
			ga.b2b_bw_UN_DES_e1_5
			ga.b2b_bw_UN_MOB_e1_5
			;
		if date ne .;
		if ConvertNonSubmit_QuoteVC ne .;
	run;
	* Append ConvertNonSubmit_ContKPDiff;
	data ga.b2b_bw_e1_6;
		format DeviceType $16.;
		set /* SM */
			ga.b2b_bw_SM_DES_e1_6
			ga.b2b_bw_SM_MOB_e1_6
			/* LG */
			ga.b2b_bw_LG_DES_e1_6
			ga.b2b_bw_LG_MOB_e1_6
			/* UN */
			ga.b2b_bw_UN_DES_e1_6
			ga.b2b_bw_UN_MOB_e1_6
			;
		if date ne .;
	run;

	* Merge All Actions;
	proc sort data=ga.b2b_bw_e1_1; 	by date sourceMedium Campaign adContent pagePath landingPagePath Metro userType deviceType Business_Size; run;
	proc sort data=ga.b2b_bw_e1_2; 	by date sourceMedium Campaign adContent pagePath landingPagePath Metro userType deviceType Business_Size; run;
	proc sort data=ga.b2b_bw_e1_3; 	by date sourceMedium Campaign adContent pagePath landingPagePath Metro userType deviceType Business_Size; run;
	data ga.b2b_bw_e1;
		merge 
			ga.b2b_bw_e1_1
			ga.b2b_bw_e1_2
			ga.b2b_bw_e1_3;
		by date sourceMedium Campaign adContent 
			pagePath landingPagePath Metro userType deviceType Business_Size;
	run;

	* Conditionally append e1_4, e1_5, and e1_6;
	proc sql ;
		select distinct sum(coalesce(ShareActions_Unique,0)) as ShareActions into :cnt_e1_4 from ga.b2b_bw_e1_4 where date ne .;
		select distinct sum(coalesce(ConvertNonSubmit_QuoteVC,0)) as QuoteVCStarts into :cnt_e1_5 from ga.b2b_bw_e1_5 where date ne .;
		select distinct sum(coalesce(ConvertNonSubmit_ContKPDiff,0)) as ContKPDiffStarts into :cnt_e1_6 from ga.b2b_bw_e1_6 where date ne .;
	quit;
	%if &cnt_e1_4 > 0 %then %do;
		proc sort data=ga.b2b_bw_e1_4; 	by date sourceMedium Campaign adContent pagePath landingPagePath Metro userType deviceType Business_Size; run;
		data ga.b2b_bw_e1;
			merge 
				ga.b2b_bw_e1
				ga.b2b_bw_e1_4;
			by date sourceMedium Campaign adContent 
				pagePath landingPagePath Metro userType deviceType Business_Size;
		run;
	%end;
	%if &cnt_e1_5 > 0 %then %do;
		proc sort data=ga.b2b_bw_e1_5; 	by date sourceMedium Campaign adContent pagePath landingPagePath Metro userType deviceType Business_Size; run;
		data ga.b2b_bw_e1;
			merge 
				ga.b2b_bw_e1
				ga.b2b_bw_e1_5;
			by date sourceMedium Campaign adContent 
				pagePath landingPagePath Metro userType deviceType Business_Size;
		run;
	%end;
	%if &cnt_e1_6 > 0 %then %do;
		proc sort data=ga.b2b_bw_e1_6; 	by date sourceMedium Campaign adContent pagePath landingPagePath Metro userType deviceType Business_Size; run;
		data ga.b2b_bw_e1;
			merge 
				ga.b2b_bw_e1
				ga.b2b_bw_e1_6;
			by date sourceMedium Campaign adContent 
				pagePath landingPagePath Metro userType deviceType Business_Size;
		run;
	%end;

	%check_for_data(ga.b2b_bw_e1,=0,No records in b2b_bw_e1);

	proc delete data=ga.b2b_bw_SM_DES_e1_1; run &cancel.;
	proc delete data=ga.b2b_bw_SM_MOB_e1_1; run &cancel.;
	proc delete data=ga.b2b_bw_LG_DES_e1_1; run &cancel.;
	proc delete data=ga.b2b_bw_LG_MOB_e1_1; run &cancel.;
	proc delete data=ga.b2b_bw_UN_DES_e1_1; run &cancel.;
	proc delete data=ga.b2b_bw_UN_MOB_e1_1; run &cancel.;
	proc delete data=ga.b2b_bw_SM_DES_e1_2; run &cancel.;
	proc delete data=ga.b2b_bw_SM_MOB_e1_2; run &cancel.;
	proc delete data=ga.b2b_bw_LG_DES_e1_2; run &cancel.;
	proc delete data=ga.b2b_bw_LG_MOB_e1_2; run &cancel.;
	proc delete data=ga.b2b_bw_UN_DES_e1_2; run &cancel.;
	proc delete data=ga.b2b_bw_UN_MOB_e1_2; run &cancel.;
	proc delete data=ga.b2b_bw_SM_DES_e1_3; run &cancel.;
	proc delete data=ga.b2b_bw_SM_MOB_e1_3; run &cancel.;
	proc delete data=ga.b2b_bw_LG_DES_e1_3; run &cancel.;
	proc delete data=ga.b2b_bw_LG_MOB_e1_3; run &cancel.;
	proc delete data=ga.b2b_bw_UN_DES_e1_3; run &cancel.;
	proc delete data=ga.b2b_bw_UN_MOB_e1_3; run &cancel.;
	proc delete data=ga.b2b_bw_SM_DES_e1_4; run &cancel.;
	proc delete data=ga.b2b_bw_SM_MOB_e1_4; run &cancel.;
	proc delete data=ga.b2b_bw_LG_DES_e1_4; run &cancel.;
	proc delete data=ga.b2b_bw_LG_MOB_e1_4; run &cancel.;
	proc delete data=ga.b2b_bw_UN_DES_e1_4; run &cancel.;
	proc delete data=ga.b2b_bw_UN_MOB_e1_4; run &cancel.;
	proc delete data=ga.b2b_bw_SM_DES_e1_5; run &cancel.;
	proc delete data=ga.b2b_bw_SM_MOB_e1_5; run &cancel.;
	proc delete data=ga.b2b_bw_LG_DES_e1_5; run &cancel.;
	proc delete data=ga.b2b_bw_LG_MOB_e1_5; run &cancel.;
	proc delete data=ga.b2b_bw_UN_DES_e1_5; run &cancel.;
	proc delete data=ga.b2b_bw_UN_MOB_e1_5; run &cancel.;
	proc delete data=ga.b2b_bw_SM_DES_e1_6; run &cancel.;
	proc delete data=ga.b2b_bw_SM_MOB_e1_6; run &cancel.;
	proc delete data=ga.b2b_bw_LG_DES_e1_6; run &cancel.;
	proc delete data=ga.b2b_bw_LG_MOB_e1_6; run &cancel.;
	proc delete data=ga.b2b_bw_UN_DES_e1_6; run &cancel.;
	proc delete data=ga.b2b_bw_UN_MOB_e1_6; run &cancel.;

	proc delete data=ga.b2b_bw_e1_1; run &cancel.;
	proc delete data=ga.b2b_bw_e1_2; run &cancel.;
	proc delete data=ga.b2b_bw_e1_3; run &cancel.;
	proc delete data=ga.b2b_bw_e1_4; run &cancel.;
	proc delete data=ga.b2b_bw_e1_5; run &cancel.;
	proc delete data=ga.b2b_bw_e1_6; run &cancel.;

%if &cancel= %then %do; /* (2) */

/* -------------------------------------------------------------------------------------------------*/
/*                                                                                                  */
/*                                                                                                  */
/*                                            Page table                                            */
/*                                          Page-level call                                         */
/*                                                                                                  */
/*                                                                                                  */
/* -------------------------------------------------------------------------------------------------*/

%let error_rsn=Error during pull p1;

/* -------------------------------------------------------------------------------------------------*/
/*  Dimensions                                                                                      */
/* -------------------------------------------------------------------------------------------------*/

	%let i=1;
	%let var&i=          SourceMedium; /* need this for determining channel */
	%let informat_var&i= $100.;
	%let format_var&i=   $100.;

	%let i=%eval(&i+1);
	%let var&i=          Campaign; /* need this for determining channel and identifying specific campaign */
	%let informat_var&i= $250.;
	%let format_var&i=   $250.;

	%let i=%eval(&i+1);
	%let var&i=          adContent; /* needed to join to SalesConnect for funnel report */
	%let informat_var&i= $200.;
	%let format_var&i=   $200.;

	%let i=%eval(&i+1);
	%let var&i=          pagePath; /* needed for funnel report */
	%let informat_var&i= $300.;
	%let format_var&i=   $300.;	

	%let i=%eval(&i+1);
	%let var&i=          landingPagePath; /* need this for joining to session data */
	%let informat_var&i= $300.;
	%let format_var&i=   $300.;	

	%let i=%eval(&i+1);
	%let var&i=          Metro; /* requested filter */
	%let informat_var&i= $200.;
	%let format_var&i=   $200.;

	%let i=%eval(&i+1);
	%let var&i=          userType; /* requested filter */
	%let informat_var&i= $17.;
	%let format_var&i=   $17.;

	%let number_of_dimensions=&i;

/* -------------------------------------------------------------------------------------------------*/
/*  Metrics                                                                                         */
/* -------------------------------------------------------------------------------------------------*/	

	%let i=%eval(&i+1);
	%let var&i=          uniquePageviews;
	%let informat_var&i= 8.;
	%let format_var&i=   8.;

	%let i=%eval(&i+1);
	%let var&i=          exits;
	%let informat_var&i= 8.;
	%let format_var&i=   8.;

	%let i=%eval(&i+1);
	%let var&i=          timeOnPage;
	%let informat_var&i= 8.;
	%let format_var&i=   8.;	

	%let number_of_metrics=%eval(&i-&number_of_dimensions);

/* -------------------------------------------------------------------------------------------------*/
/*  Execute.                                                                                        */
/* -------------------------------------------------------------------------------------------------*/

	%macro exec(exec_segment,
/*				exec_filter,*/
				exec_output_file_name,
				exec_business_size,
				exec_device
	/*			,exec_rename*/
				);

		%GetGAData(chooseSegment=&&exec_segment,
						chooseView=Default,
	/*					addl_filters=&&exec_filter,*/
						level=day,
						StartDate=&Campaign_StartDate,
						EndDate=&Campaign_EndDate,
						output_file_path=&output_file_path,
						output_file_name=&&exec_output_file_name);
					%if(%sysfunc(exist(ga.&&exec_output_file_name.))) %then %do;
						data ga.&&exec_output_file_name.; 
							set ga.&&exec_output_file_name.; 
							Business_Size = "&exec_business_size."; 
							DeviceType = "&exec_device"; 
							*rename uniqueEvents = &exec_rename;
						run;
					%end; 
					%else %do;
						data ga.&&exec_output_file_name.; 
							Business_Size = "&exec_business_size."; 
							DeviceType = "&exec_device"; 
							*rename uniqueEvents = &exec_rename;
						run;
					%end;
	%mend;

* Small Business;
	%exec(&SM_DES,b2b_bw_SM_DES_p1_1,SB,Desktop); * Desktop;
	%exec(&SM_MOB,b2b_bw_SM_MOB_p1_1,SB,Mobile & Tablet); * Mobile & Tablet;
		
* Large Business;
	%exec(&LG_DES,b2b_bw_LG_DES_p1_1,LG,Desktop); * Desktop; /*5838 actual: 3981*/
	%exec(&LG_MOB,b2b_bw_LG_MOB_p1_1,LG,Mobile & Tablet); * Mobile & Tablet;/*935 actual: 910*/

* Unknown Business Size;
	%exec(&UN_DES,b2b_bw_UN_DES_p1_1,UN,Desktop); * Desktop; /*57213 actual: 52305*/
	%exec(&UN_MOB,b2b_bw_UN_MOB_p1_1,UN,Mobile & Tablet); * Mobile & Tablet; /*63948 actual: 49012*/
	
	* Append All;
	data ga.b2b_bw_p1;
		format deviceType $16.;
		set /* SM */
			ga.b2b_bw_SM_DES_p1_1
			ga.b2b_bw_SM_MOB_p1_1
			/* LG */
			ga.b2b_bw_LG_DES_p1_1
			ga.b2b_bw_LG_MOB_p1_1
			/* UN */
			ga.b2b_bw_UN_DES_p1_1
			ga.b2b_bw_UN_MOB_p1_1;
		if date ne .;
	run;
	%check_for_data(ga.b2b_bw_p1,=0,No records in b2b_bw_p1);

	proc delete data=ga.b2b_bw_SM_DES_p1_1; run &cancel.;
	proc delete data=ga.b2b_bw_SM_MOB_p1_1; run &cancel.;
	proc delete data=ga.b2b_bw_LG_DES_p1_1; run &cancel.;
	proc delete data=ga.b2b_bw_LG_MOB_p1_1; run &cancel.;
	proc delete data=ga.b2b_bw_UN_DES_p1_1; run &cancel.;
	proc delete data=ga.b2b_bw_UN_MOB_p1_1; run &cancel.;

%end; /* (2) */
%if &cancel= %then %do; /* (3) */

/* -------------------------------------------------------------------------------------------------*/
/*  Merge all page-level data.                                                                      */
/* -------------------------------------------------------------------------------------------------*/

	proc sort data=ga.b2b_bw_e1; by Date SourceMedium Campaign adContent pagePath landingPagePath Metro DeviceType UserType Business_Size; run;
	proc sort data=ga.b2b_bw_p1; by Date SourceMedium Campaign adContent pagePath landingPagePath Metro DeviceType UserType Business_Size; run;

	data ga.b2b_bw_plvl;
		merge ga.b2b_bw_e1(in=a) /* shop, learn, convert, share, convertnonsubmit_quoteVC, and ConvertNonSubmit_ContKPDiff unique actions*/
			  ga.b2b_bw_p1(in=d) /* pageviews, exits, time on site */
			  ;
		by Date SourceMedium Campaign adContent 
		   pagePath landingPagePath Metro
		   DeviceType UserType Business_Size;

		if uniquePageviews=. then delete; /* these are likely events after 30 minutes of inactivity. Difficult to join */
	run;
	%check_for_data(ga.b2b_bw_plvl,=0,No records in b2b_bw_plvl);

%end; /* (3) */
%if &cancel= %then %do; /* (4) */

	proc sql;
		create table check_dups as
		select 
			t1.* , t2.ndups
		from ga.b2b_bw_plvl t1
			, (select 
					Date, SourceMedium, Campaign, adContent,
					pagePath, landingPagePath, Metro, DeviceType,
					UserType, Business_Size,
					count(*) as ndups
			   from ga.b2b_bw_plvl
			   group by 
			   		Date, SourceMedium, Campaign, adContent,
					pagePath, landingPagePath, Metro, DeviceType,
					UserType, Business_Size
			   ) t2
		where t2.ndups>1 
			and t1.Date=t2.Date 
			and t1.SourceMedium=t2.SourceMedium 
			and t1.Campaign=t2.Campaign
			and t1.adContent=t2.adContent 
			and t1.pagePath=t2.pagePath 
			and t1.landingPagePath=t2.landingPagePath
			and t1.Metro=t2.Metro 
			and t1.DeviceType=t2.DeviceType 
			and t1.UserType=t2.UserType
			and t1.Business_Size=t2.Business_Size
			order by t1.Date, t1.SourceMedium, t1.Campaign;
	quit;
	%check_for_data(check_dups,>0,Dupes in ga.b2b_bw_plvl);

	proc delete data=ga.b2b_bw_e1; run &cancel.;
	proc delete data=ga.b2b_bw_p1; run &cancel.;

%end; /* (4) */
%if &cancel= %then %do; /* (5) */

/* -------------------------------------------------------------------------------------------------*/
/*                                                                                                  */
/*                                                                                                  */
/*                                          Session table 1                                         */
/*                                         Session-level call                                       */
/*                                                                                                  */
/*                                                                                                  */
/* -------------------------------------------------------------------------------------------------*/

%let error_rsn=Error during pull s1;

/* -------------------------------------------------------------------------------------------------*/
/*  Dimensions                                                                                      */
/* -------------------------------------------------------------------------------------------------*/

	%let i=1;
	%let var&i=          SourceMedium; /* need this for determining channel */
	%let informat_var&i= $100.;
	%let format_var&i=   $100.;

	%let i=%eval(&i+1);
	%let var&i=          Campaign; /* need this for determining channel and identifying specific campaign */
	%let informat_var&i= $250.;
	%let format_var&i=   $250.;

	%let i=%eval(&i+1);
	%let var&i=          adContent; /* needed to join to SalesConnect for funnel report */
	%let informat_var&i= $200.;
	%let format_var&i=   $200.;

	%let i=%eval(&i+1);
	%let var&i=          landingPagePath; /* need this for joining to session data */
	%let informat_var&i= $300.;
	%let format_var&i=   $300.;	

	%let i=%eval(&i+1);
	%let var&i=          Metro; /* requested filter */
	%let informat_var&i= $200.;
	%let format_var&i=   $200.;

	%let i=%eval(&i+1);
	%let var&i=          userType; /* requested filter */
	%let informat_var&i= $17.;
	%let format_var&i=   $17.;

	%let number_of_dimensions=&i;

/* -------------------------------------------------------------------------------------------------*/
/*  Metrics                                                                                         */
/* -------------------------------------------------------------------------------------------------*/	

	%let i=%eval(&i+1);
	%let var&i=          users;
	%let informat_var&i= 8.;
	%let format_var&i=   8.;

	%let i=%eval(&i+1);
	%let var&i=          sessions;
	%let informat_var&i= 8.;
	%let format_var&i=   8.;

	%let i=%eval(&i+1);
	%let var&i=          sessionDuration;
	%let informat_var&i= 8.;
	%let format_var&i=   8.;

	%let i=%eval(&i+1);
	%let var&i=          bounces;
	%let informat_var&i= 8.;
	%let format_var&i=   8.;

	%let number_of_metrics=%eval(&i-&number_of_dimensions);

/* -------------------------------------------------------------------------------------------------*/
/*  Execute.                                                                                        */
/* -------------------------------------------------------------------------------------------------*/

* Small Business;
	%exec(&SM_DES,b2b_bw_SM_DES_s1_1,SB,Desktop); * Desktop;	
	%exec(&SM_MOB,b2b_bw_SM_MOB_s1_1,SB,Mobile & Tablet); * Mobile & Tablet;
	
* Large Business;
	%exec(&LG_DES,b2b_bw_LG_DES_s1_1,LG,Desktop); * Desktop;
	%exec(&LG_MOB,b2b_bw_LG_MOB_s1_1,LG,Mobile & Tablet); * Mobile & Tablet;

* Unknown Business Size;
	%exec(&UN_DES,b2b_bw_UN_DES_s1_1,UN,Desktop); * Desktop;
	%exec(&UN_MOB,b2b_bw_UN_MOB_s1_1,UN,Mobile & Tablet); * Mobile & Tablet;

	* Append All;
	data ga.b2b_bw_s1;
		format deviceType $16.;
		set /* SM */
			ga.b2b_bw_SM_DES_s1_1
			ga.b2b_bw_SM_MOB_s1_1
			/* LG */
			ga.b2b_bw_LG_DES_s1_1
			ga.b2b_bw_LG_MOB_s1_1
			/* UN */
			ga.b2b_bw_UN_DES_s1_1
			ga.b2b_bw_UN_MOB_s1_1
		;
		if date ne .;
	run;

	proc sql;
		create table ga.b2b_bw_s1_r as
			select distinct
				Date
			,	SourceMedium
			,	Campaign
			,	adContent
			,	landingPagePath
			,	Metro
			,	UserType
			,	DeviceType
			,	Business_Size
			,	Users
			,	Sessions
			,	SessionDuration
			,	Bounces
			,	max(case when find(landingPagePath,'WT.mc_id') > 0 
						and SourceMedium not in ('organic / bing','organic / google')
					then substr(landingPagePath,index(landingPagePath,'WT.mc_id=')+9,6)
				     end) as WTmc_id format $6.
			from ga.b2b_bw_s1
			group by
				Date
			,	SourceMedium
			,	Campaign
			,	adContent
			,	landingPagePath
			,	Metro
			,	UserType
			,	DeviceType
			,	Business_Size;
	quit;
	%check_for_data(ga.b2b_bw_s1_r,=0,No records in b2b_bw_s1_r);

%end; /* (5) */
%if &cancel= %then %do; /* (6) */

	proc sql;
		create table check_dups as
		select 
			t1.* , t2.ndups
		from ga.b2b_bw_s1_r t1
			, (select 
					date, sourcemedium, campaign, adcontent, 
					landingpagepath, metro, usertype, 
					devicetype, business_size, count(*) as ndups
			   from ga.b2b_bw_s1_r
			   group by date, sourcemedium, campaign, adcontent, 
					landingpagepath, metro, usertype, 
					devicetype, business_size
			   ) t2
		where t2.ndups>1 
			and t1.date=t2.date 
			and t1.sourcemedium=t2.sourcemedium 
			and t1.campaign=t2.campaign
			and t1.adcontent=t2.adcontent
			and t1.landingpagepath=t2.landingpagepath
			and t1.metro=t2.metro
			and t1.usertype=t2.usertype
			and t1.devicetype=t2.devicetype
			and t1.business_size=t2.business_size
		order by t1.date, t1.sourcemedium, t1.campaign;
	quit;
	%check_for_data(check_dups,>0,Dupes in b2b_bw_s1_r);

	proc delete data=ga.b2b_bw_SM_DES_s1_1; run &cancel.;
	proc delete data=ga.b2b_bw_SM_MOB_s1_1; run &cancel.;
	proc delete data=ga.b2b_bw_LG_DES_s1_1; run &cancel.;
	proc delete data=ga.b2b_bw_LG_MOB_s1_1; run &cancel.;
	proc delete data=ga.b2b_bw_UN_DES_s1_1; run &cancel.;
	proc delete data=ga.b2b_bw_UN_MOB_s1_1; run &cancel.;
	proc delete data=ga.b2b_bw_s1; run &cancel.;

%end; /* (6) */
%if &cancel= %then %do; /* (7) */

/* -------------------------------------------------------------------------------------------------*/
/*                                                                                                  */
/*                                                                                                  */
/*                                          Session table 2                                         */
/*                                         Session-level call                                       */
/*                                                                                                  */
/*                                                                                                  */
/* -------------------------------------------------------------------------------------------------*/

%let error_rsn=Error during pull s2;

/* -------------------------------------------------------------------------------------------------*/
/*  Dimensions                                                                                      */
/* -------------------------------------------------------------------------------------------------*/

	%let i=1;
	%let var&i=          SourceMedium; /* need this for determining channel */
	%let informat_var&i= $100.;
	%let format_var&i=   $100.;

	%let i=%eval(&i+1);
	%let var&i=          Campaign; /* need this for determining channel and identifying specific campaign */
	%let informat_var&i= $250.;
	%let format_var&i=   $250.;

	%let i=%eval(&i+1);
	%let var&i=          adContent; /* needed to join to SalesConnect for funnel report */
	%let informat_var&i= $200.;
	%let format_var&i=   $200.;

	%let i=%eval(&i+1);
	%let var&i=          landingPagePath; /* need this for joining to session data */
	%let informat_var&i= $300.;
	%let format_var&i=   $300.;	

	%let i=%eval(&i+1);
	%let var&i=          Metro; /* requested filter */
	%let informat_var&i= $200.;
	%let format_var&i=   $200.;

	%let i=%eval(&i+1);
	%let var&i=          userType; /* requested filter */
	%let informat_var&i= $17.;
	%let format_var&i=   $17.;

	%let number_of_dimensions=&i;

/* -------------------------------------------------------------------------------------------------*/
/*  Metrics                                                                                         */
/* -------------------------------------------------------------------------------------------------*/	

	%let i=%eval(&i+1);
	%let var&i=          goal5Completions; /* goal13Completions ConvertSubmit_Quote */
	%let informat_var&i= 8.;
	%let format_var&i=   8.;

	%let i=%eval(&i+1);
	%let var&i=          goal8Completions; /* goal1Completions ConvertSubmit_Contact */
	%let informat_var&i= 8.;
	%let format_var&i=   8.;

	%let i=%eval(&i+1);
	%let var&i=          goal9Completions; /* goal17Completions SB_MAS_Leads */
	%let informat_var&i= 8.;
	%let format_var&i=   8.;

	%let i=%eval(&i+1);
	%let var&i=          goalValueAll; /* added 1/17/2022 */
	%let informat_var&i= comma8.2;
	%let format_var&i=   comma8.2;

	%let number_of_metrics=%eval(&i-&number_of_dimensions);

/* -------------------------------------------------------------------------------------------------*/
/*  Execute.                                                                                        */
/* -------------------------------------------------------------------------------------------------*/

	* Small Business;
		%exec(&SM_DES,b2b_bw_SM_DES_s2_1,SB,Desktop); 	* Desktop;
		%exec(&SM_MOB,b2b_bw_SM_MOB_s2_1,SB,Mobile & Tablet); 	* Mobile & Tablet;
		
	* Large Business;
		%exec(&LG_DES,b2b_bw_LG_DES_s2_1,LG,Desktop); * Desktop;
		%exec(&LG_MOB,b2b_bw_LG_MOB_s2_1,LG,Mobile & Tablet); * Mobile & Tablet;

	* Unknown Business Size;
		%exec(&UN_DES,b2b_bw_UN_DES_s2_1,UN,Desktop); * Desktop;
		%exec(&UN_MOB,b2b_bw_UN_MOB_s2_1,UN,Mobile & Tablet); * Mobile & Tablet;

	* Append All;
	data ga.b2b_bw_s2;
		format deviceType $16.;
		set /* SM */
			ga.b2b_bw_SM_DES_s2_1
			ga.b2b_bw_SM_MOB_s2_1
			/* LG */
			ga.b2b_bw_LG_DES_s2_1
			ga.b2b_bw_LG_MOB_s2_1
			/* UN */
			ga.b2b_bw_UN_DES_s2_1
			ga.b2b_bw_UN_MOB_s2_1
		;
		if goal5Completions=0 and goal8Completions=0 and goal9Completions=0 and goalValueAll=0 then delete;
		if date =. then delete;
	run;
	%check_for_data(ga.b2b_bw_s2,=0,No records in b2b_bw_s2);

	proc delete data=ga.b2b_bw_SM_DES_s2_1; run &cancel.;
	proc delete data=ga.b2b_bw_SM_MOB_s2_1; run &cancel.;
	proc delete data=ga.b2b_bw_LG_DES_s2_1; run &cancel.;
	proc delete data=ga.b2b_bw_LG_MOB_s2_1; run &cancel.;
	proc delete data=ga.b2b_bw_UN_DES_s2_1; run &cancel.;
	proc delete data=ga.b2b_bw_UN_MOB_s2_1; run &cancel.;

%end; /* (7) */
%if &cancel= %then %do; /* (8) */

/* -------------------------------------------------------------------------------------------------*/
/*                                                                                                  */
/*                                                                                                  */
/*                                          Session table 3                                         */
/*                                         Session-level call                                       */
/*                                                                                                  */
/*                                                                                                  */
/* -------------------------------------------------------------------------------------------------*/

%let error_rsn=Error during pull s3;

/* -------------------------------------------------------------------------------------------------*/
/*  Dimensions                                                                                      */
/* -------------------------------------------------------------------------------------------------*/

	%let i=1;
	%let var&i=          SourceMedium; /* need this for determining channel */
	%let informat_var&i= $100.;
	%let format_var&i=   $100.;

	%let i=%eval(&i+1);
	%let var&i=          Campaign; /* need this for determining channel and identifying specific campaign */
	%let informat_var&i= $250.;
	%let format_var&i=   $250.;

	%let i=%eval(&i+1);
	%let var&i=          adContent; /* needed to join to SalesConnect for funnel report */
	%let informat_var&i= $200.;
	%let format_var&i=   $200.;

	%let i=%eval(&i+1);
	%let var&i=          landingPagePath; /* need this for joining to session data */
	%let informat_var&i= $300.;
	%let format_var&i=   $300.;	

	%let i=%eval(&i+1);
	%let var&i=          Metro; /* requested filter */
	%let informat_var&i= $200.;
	%let format_var&i=   $200.;

	%let i=%eval(&i+1);
	%let var&i=          userType; /* requested filter */
	%let informat_var&i= $17.;
	%let format_var&i=   $17.;

	%let number_of_dimensions=&i;

/* -------------------------------------------------------------------------------------------------*/
/*  Metrics                                                                                         */
/* -------------------------------------------------------------------------------------------------*/	

	%let i=%eval(&i+1);
	%let var&i=          goal3Completions; /* ConvertNonSubmit_Quote */
	%let informat_var&i= 8.;
	%let format_var&i=   8.;

	%let i=%eval(&i+1);
	%let var&i=          goal6Completions; /* ConvertNonSubmit_Contact */
	%let informat_var&i= 8.;
	%let format_var&i=   8.;

	%let i=%eval(&i+1);
	%let var&i=          goal16Completions; /* ConvertNonSubmit_SSQ */
	%let informat_var&i= 8.;
	%let format_var&i=   8.;

	%let i=%eval(&i+1);
	%let var&i=          goal13Completions; /* Convert_Call */
	%let informat_var&i= 8.;
	%let format_var&i=   8.;

	%let number_of_metrics=%eval(&i-&number_of_dimensions);

/* -------------------------------------------------------------------------------------------------*/
/*  Execute.                                                                                        */
/* -------------------------------------------------------------------------------------------------*/

	* Small Business;
		%exec(&SM_DES,b2b_bw_SM_DES_s3_1,SB,Desktop); 	* Desktop;
		%exec(&SM_MOB,b2b_bw_SM_MOB_s3_1,SB,Mobile & Tablet); 	* Mobile & Tablet;
		
	* Large Business;
		%exec(&LG_DES,b2b_bw_LG_DES_s3_1,LG,Desktop); * Desktop;
		%exec(&LG_MOB,b2b_bw_LG_MOB_s3_1,LG,Mobile & Tablet); * Mobile & Tablet;

	* Unknown Business Size;
		%exec(&UN_DES,b2b_bw_UN_DES_s3_1,UN,Desktop); * Desktop;
		%exec(&UN_MOB,b2b_bw_UN_MOB_s3_1,UN,Mobile & Tablet); * Mobile & Tablet;

	* Append All;
	data ga.b2b_bw_s3;
		format deviceType $16.;
		set /* SM */
			ga.b2b_bw_SM_DES_s3_1
			ga.b2b_bw_SM_MOB_s3_1
			/* LG */
			ga.b2b_bw_LG_DES_s3_1
			ga.b2b_bw_LG_MOB_s3_1
			/* UN */
			ga.b2b_bw_UN_DES_s3_1
			ga.b2b_bw_UN_MOB_s3_1
		;
		if goal3Completions=0 and goal6Completions=0 and goal16Completions=0 then delete;
		if date = . then delete;
	run;
	%check_for_data(ga.b2b_bw_s3,=0,No records in b2b_bw_s3);

	proc delete data=ga.b2b_bw_SM_DES_s3_1; run &cancel.;
	proc delete data=ga.b2b_bw_SM_MOB_s3_1; run &cancel.;
	proc delete data=ga.b2b_bw_LG_DES_s3_1; run &cancel.;
	proc delete data=ga.b2b_bw_LG_MOB_s3_1; run &cancel.;
	proc delete data=ga.b2b_bw_UN_DES_s3_1; run &cancel.;
	proc delete data=ga.b2b_bw_UN_MOB_s3_1; run &cancel.;

%end; /* (8) */
%if &cancel= %then %do; /* (9) */
		
/* -------------------------------------------------------------------------------------------------*/
/*  Merge session-level data (part1).                                                               */
/* -------------------------------------------------------------------------------------------------*/
		
	proc sort data=ga.b2b_bw_s1_r; by Date SourceMedium Campaign adContent landingPagePath Metro DeviceType UserType Business_Size; run;
	proc sort data=ga.b2b_bw_s2; by Date SourceMedium Campaign adContent landingPagePath Metro DeviceType UserType Business_Size; run;
	proc sort data=ga.b2b_bw_s3; by Date SourceMedium Campaign adContent landingPagePath Metro DeviceType UserType Business_Size; run;

	data ga.b2b_bw_slvl_tbl1;
		merge ga.b2b_bw_s1_r(in=a) /* users, session, sessiondur, bounces, entrances, WTmcid */
		      ga.b2b_bw_s2(in=b) /* goals (5,8,9) and weighted actions */
			  ga.b2b_bw_s3(in=c) /* goals (3,6,16) */
			  ;
		by Date SourceMedium Campaign adContent 
		   landingPagePath Metro
		   DeviceType UserType Business_Size;

		rename goal8Completions=ConvertSubmit_Contact
			   goal5Completions=ConvertSubmit_Quote
			   goal9Completions=SB_MAS_Leads
			   goalValueAll=Weighted_Actions
			   goal6Completions=ConvertNonSubmit_Contact
			   goal3Completions=ConvertNonSubmit_Quote
			   goal16Completions=ConvertNonSubmit_SSQ
			   goal13Completions=Convert_Call
			   sessions=sessions_all;

		if sessions = . then delete;

	run;

	%check_for_data(ga.b2b_bw_slvl_tbl1,=0,No records in b2b_bw_slvl_tbl1);

	proc delete data=ga.b2b_bw_s1_r; run &cancel.;
	proc delete data=ga.b2b_bw_s2; run &cancel.;
	proc delete data=ga.b2b_bw_s3; run &cancel.;

%end; /* (9) */
%if &cancel= %then %do; /* (10) */

/* -------------------------------------------------------------------------------------------------*/
/*                                                                                                  */
/*                                                                                                  */
/*                                          Session table 4                                         */
/*                                         Session-level call                                       */
/*                                                                                                  */
/*                                                                                                  */
/* -------------------------------------------------------------------------------------------------*/

%let error_rsn=Error during pull s4;

/* -------------------------------------------------------------------------------------------------*/
/*  Dimensions                                                                                      */
/* -------------------------------------------------------------------------------------------------*/

	%let i=1;
	%let var&i=          SourceMedium; /* need this for determining channel */
	%let informat_var&i= $100.;
	%let format_var&i=   $100.;

	%let i=%eval(&i+1);
	%let var&i=          Campaign; /* need this for determining channel and identifying specific campaign */
	%let informat_var&i= $250.;
	%let format_var&i=   $250.;

	%let i=%eval(&i+1);
	%let var&i=          adContent; /* needed to join to SalesConnect for funnel report */
	%let informat_var&i= $200.;
	%let format_var&i=   $200.;

	%let i=%eval(&i+1);
	%let var&i=          landingPagePath; /* need this for joining to session data */
	%let informat_var&i= $300.;
	%let format_var&i=   $300.;	

	%let i=%eval(&i+1);
	%let var&i=          Metro; /* requested filter */
	%let informat_var&i= $200.;
	%let format_var&i=   $200.;

	%let i=%eval(&i+1);
	%let var&i=          userType; /* requested filter */
	%let informat_var&i= $17.;
	%let format_var&i=   $17.;

	%let i=%eval(&i+1);
	%let var&i=          deviceCategory; /* requested filter */
	%let informat_var&i= $16.;
	%let format_var&i=   $16.;

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

	%macro exec(exec_segment,
/*				exec_filter,*/
				exec_output_file_name,
				exec_business_size,
	/*			exec_device,*/
				exec_rename
				);

		%GetGAData(chooseSegment=&&exec_segment,
						chooseView=Default,
/*						addl_filters=&&exec_filter,*/
						level=day,
						StartDate=&Campaign_StartDate,
						EndDate=&Campaign_EndDate,
						output_file_path=&output_file_path,
						output_file_name=&&exec_output_file_name);
					%if %sysfunc(exist(ga.&&exec_output_file_name.)) %then %do;
						data ga.&&exec_output_file_name.; 
							set ga.&&exec_output_file_name.; 
							Business_Size = "&exec_business_size."; 
							*DeviceType = "&exec_device"; 
							rename sessions = &exec_rename;
						run;
					%end;
					%else %do;
						data ga.&&exec_output_file_name.; 
							Business_Size = "&exec_business_size."; 
							*DeviceType = "&exec_device"; 
							rename sessions = &exec_rename;
						run;
					%end;

	%mend;

* Small Business;
	%exec(&smallBiz,b2b_bw_SM_s4_1,SB,sessions_BW);
	%exec(&SM_HP,b2b_bw_SM_s4_2,SB,sessions_HP);
	%exec(&SM_SBHP,b2b_bw_SM_s4_3,SB,sessions_SBHP);
	
* Large Business;
	%exec(&largeBiz,b2b_bw_LG_s4_1,LG,sessions_BW);
	%exec(&LG_HP,b2b_bw_LG_s4_2,LG,sessions_HP);
	%exec(&LG_SBHP,b2b_bw_LG_s4_3,LG,sessions_SBHP);

* Unknown Business Size;
	%exec(&unkSize,b2b_bw_UN_s4_1,UN,sessions_BW);
	%exec(&UN_HP,b2b_bw_UN_s4_2,UN,sessions_HP);

	* Append sessions_BW;
	data ga.b2b_bw_s4_1;
		set ga.b2b_bw_SM_s4_1
			ga.b2b_bw_LG_s4_1
			ga.b2b_bw_UN_s4_1;
		if date ne .;
	run;
	* Append sessions_HP;
	data ga.b2b_bw_s4_2;
		set ga.b2b_bw_SM_s4_2
			ga.b2b_bw_LG_s4_2
			ga.b2b_bw_UN_s4_2;
		if date ne .;
	run;
	* Append sessions_SBHP;
	data ga.b2b_bw_s4_3;
		set ga.b2b_bw_SM_s4_3
			ga.b2b_bw_LG_s4_3;
		if date ne .;
	run;

	proc sort data=ga.b2b_bw_s4_1; 	by date sourceMedium Campaign adContent landingPagePath Metro userType deviceCategory Business_Size; run;
	proc sort data=ga.b2b_bw_s4_2; 	by date sourceMedium Campaign adContent landingPagePath Metro userType deviceCategory Business_Size; run;
	proc sort data=ga.b2b_bw_s4_3; 	by date sourceMedium Campaign adContent landingPagePath Metro userType deviceCategory Business_Size; run;
	* Merge All Sessions;
	data ga.b2b_bw_s4;
		format deviceType $16.;
		merge 
			ga.b2b_bw_s4_1
			ga.b2b_bw_s4_2
			ga.b2b_bw_s4_3;
		by date sourceMedium Campaign adContent 
			landingPagePath Metro userType deviceCategory Business_Size;

		if deviceCategory = 'desktop' 
			then deviceType = 'Desktop';
		else if deviceCategory in ('mobile','tablet') 
			then deviceType = 'Mobile & Tablet';
		drop deviceCategory;

		if sessions_bw=. then delete;

	run;
	%check_for_data(ga.b2b_bw_s4,=0,No records in b2b_bw_s4);

%end; /* (10) */
%if &cancel= %then %do; /* (11) */

	proc sql;
		create table ga.b2b_bw_slvl_tbl2 as
			select distinct
				Date
			,	SourceMedium
			,	Campaign
			,	adContent
			,	landingPagePath
			,	Metro
			,	UserType
			,	DeviceType
			,	Business_Size
			,	sum(Sessions_BW) as Sessions_BW
			,	sum(Sessions_HP) as Sessions_HP
			,	sum(Sessions_SBHP) as Sessions_SBHP
			from ga.b2b_bw_s4
			group by
				Date
			,	SourceMedium
			,	Campaign
			,	adContent
			,	landingPagePath
			,	Metro
			,	UserType
			,	DeviceType
			,	Business_Size;
	quit;

	proc sql;
		create table check_dups as
		select 
			t1.* , t2.ndups
		from ga.b2b_bw_slvl_tbl2 t1
			, (select 
					date, sourcemedium, campaign, adcontent, 
					landingpagepath, metro, usertype, 
					devicetype, business_size, count(*) as ndups 
			   from ga.b2b_bw_slvl_tbl2
			   group by date, sourcemedium, campaign, adcontent, 
					landingpagepath, metro, usertype, 
					devicetype, business_size
			   ) t2
		where t2.ndups>1 
			and t1.date=t2.date 
			and t1.sourcemedium=t2.sourcemedium 
			and t1.campaign=t2.campaign
			and t1.adcontent=t2.adcontent
			and t1.landingpagepath=t2.landingpagepath
			and t1.metro=t2.metro
			and t1.usertype=t2.usertype
			and t1.devicetype=t2.devicetype
			and t1.business_size=t2.business_size
		order by t1.date, t1.sourcemedium, t1.campaign;
	quit;
	%check_for_data(check_dups,>0,Dupes in b2b_bw_slvl_tbl2);

	proc delete data=ga.b2b_bw_SM_s4_1; run &cancel.;
	proc delete data=ga.b2b_bw_SM_s4_2; run &cancel.;
	proc delete data=ga.b2b_bw_SM_s4_3; run &cancel.;
	proc delete data=ga.b2b_bw_LG_s4_1; run &cancel.;
	proc delete data=ga.b2b_bw_LG_s4_2; run &cancel.;
	proc delete data=ga.b2b_bw_LG_s4_3; run &cancel.;
	proc delete data=ga.b2b_bw_UN_s4_1; run &cancel.;
	proc delete data=ga.b2b_bw_UN_s4_2; run &cancel.;

	proc delete data=ga.b2b_bw_s4_1; run &cancel.;
	proc delete data=ga.b2b_bw_s4_2; run &cancel.;
	proc delete data=ga.b2b_bw_s4_3; run &cancel.;

	proc delete data=ga.b2b_bw_s4; run &cancel.;

%end; /* (11) */
%if &cancel= %then %do; /* (12) */

	%let error_rsn = Errors in final appends.;

/* -------------------------------------------------------------------------------------------------*/
/*                                                                                                  */
/*                                                                                                  */
/*                                            Final appends                                         */
/*                                         Cleaning and Lookups                                     */
/*                                                                                                  */
/*                                                                                                  */
/* -------------------------------------------------------------------------------------------------*/

	* Merge slvl_1 and slvl_2;

	proc sort data=ga.b2b_bw_slvl_tbl1; by date sourceMedium Campaign adContent landingPagePath Metro userType deviceType Business_Size; run;
	proc sort data=ga.b2b_bw_slvl_tbl2; by date sourceMedium Campaign adContent landingPagePath Metro userType deviceType Business_Size; run;
	data ga.b2b_bw_slvl;
		format Date mmddyy10.;
		merge ga.b2b_bw_slvl_tbl1
			  ga.b2b_bw_slvl_tbl2;
		by date sourceMedium Campaign adContent landingPagePath Metro userType deviceType Business_Size;
		if sessions_all=. then delete;

		rename Campaign=UTM_Campaign
			   adContent=UTM_Content;

	run;
	%check_for_data(ga.b2b_bw_slvl,=0,No records in b2b_bw_slvl);

	proc delete data=ga.b2b_bw_slvl_tbl1; run &cancel.;
	proc delete data=ga.b2b_bw_slvl_tbl2; run &cancel.;

%end; /* (12) */
%if &cancel= %then %do; /* (13) */

/* -------------------------------------------------------------------------------------------------*/
/*  Lookup: Channel & ChannelDetail.                                                                */
/* -------------------------------------------------------------------------------------------------*/

/*	options dlcreatedir;*/
/*	libname source xlsx "&output_file_path/B2B Channel Lookup.xlsx"; run;*/
/*	data lookup_sources; set source.'INPUT Sources MASTER'n; run;*/
/*	proc sql;*/
/*	create table source.'OUTPUT Sources'n as*/
/*		select distinct*/
/*			max(Date) as LastDate format mmddyy10.*/
/*		,	UTM_Source*/
/*		,	UTM_Medium*/
/*		,	UTM_Campaign*/
/*		,	UTM_Content*/
/*		from (select distinct Date, UTM_Source, UTM_Medium, UTM_Campaign, UTM_Content from ga.b2b_bw_slvl /* current session sources */*/
/*				  union*/
/*			  select distinct Date, UTM_Source, UTM_Medium, UTM_Campaign, UTM_Content from ga.b2b_bw_plvl /* current pageview sources */*/
/*/*			  	  union*/*/
/*/*			  select distinct LastDate, UTM_Source, UTM_Medium, UTM_Campaign, UTM_Content from lookup_sources /* existing sources */*/
/*			) x*/
/*		group by */
/*			UTM_Source*/
/*		,	UTM_Medium*/
/*		,	UTM_Campaign*/
/*		,	UTM_Content*/
/*		order by*/
/*			UTM_Medium*/
/*		,	UTM_Source*/
/*		,	UTM_Campaign*/
/*		,	UTM_Content;*/
/*	quit;*/
	/* STOP HERE -- email the Campaign lookup and work on it each week. Then have a separate process run the rest */

/* -------------------------------------------------------------------------------------------------*/
/*                                                                                                  */
/*                                                                                                  */
/*                                            Final appends                                         */
/*                                         Cleaning and Lookups                                     */
/*                                                                                                  */
/*                                                                                                  */
/* -------------------------------------------------------------------------------------------------*/

/* -------------------------------------------------------------------------------------------------*/
/*  Lookup: Channel & ChannelDetail.                                                                */
/* -------------------------------------------------------------------------------------------------*/

	options dlcreatedir;
/*	libname source xlsx "&output_file_path/B2B Channel Lookup.xlsx"; run;*/
/*	data lookup_sources; */
/*		set source.'INPUT Sources MASTER'n; */
/*	run;*/

/* -------------------------------------------------------------------------------------------------*/
/*  Lookup: Region & SubRegion.                                                                     */
/* -------------------------------------------------------------------------------------------------*/

/*	%include '/gpfsFS2/home/c156934/password.sas';*/
/*	libname mars sqlsvr DSN='SQLSVR4685' SCHEMA='dbo' user="CS\C156934" password="&winpwd"*/
/*	     qualifier='MARS' readbuff=5000 insertbuff=5000 dbcommit=1000; run;*/
/*	proc import*/
/*		datafile="&output_file_path/LOOKUP DMA Code_DMA Name.xlsx"*/
/*		out=lookup_dma*/
/*		dbms=xlsx replace;*/
/*	run;*/
/*	data kp_zips;*/
/*		set mars.zip_level_info */
/*				(keep= yr_nbr zip_cd zip4_start_cd zip4_end_cd*/
/*			 	regn_cd sub_regn_cd svc_area_nm */
/*			 	small_busn_mkt_ind large_busn_mkt_ind rec_updt_dt*/
/*				where=((small_busn_mkt_ind='Y' or large_busn_mkt_ind='Y') and yr_nbr=2021));*/
/*	run;*/
/*	proc sql;*/
/*	create table lookup_zip_dma as*/
/*		select distinct*/
/*			zip_cd*/
/*		,	zip4_cd*/
/*		,	dma_cd*/
/*		from mars.individual_kbm_prospect*/
/*		where zip_cd in (select zip_cd from kp_zips);*/
/*	quit;*/
/*	proc sort data=lookup_zip_dma; by dma_cd; run;*/
/*	proc sort data=lookup_dma; by dma_cd; run;*/
/*	data lookup_zip_dma;*/
/*		merge lookup_zip_dma(in=a)*/
/*			  lookup_dma(in=b);*/
/*		by dma_cd;*/
/*		if a then output;*/
/*	run;*/
/*	proc sql;*/
/*	create table lookup_dma_kpregn as*/
/*		select distinct*/
/*			y.dma_cd*/
/*		,	y.dma_nm*/
/*		,	x.regn_cd*/
/*		,	x.sub_regn_cd*/
/*		,	x.svc_area_nm*/
/*		from kp_zips x*/
/*		left join lookup_zip_dma y*/
/*			on x.zip_cd=y.zip_cd*/
/*			and y.zip4_cd between x.zip4_start_cd and x.zip4_end_cd*/
/*			;*/
/*	quit;*/
	proc import
		datafile="&output_file_path/LOOKUP Metro_KP Region.xlsx"
		out=lookup_kpregion
		dbms=xlsx replace;
	run;
	data lookup_kpregion;
		format Region $4. SubRegion $4.;
		set lookup_kpregion(drop=State);
		* Standardize region abbr;
		if Region='CA' and SubRegion='NCAL' then Region='NCAL';
		else if Region='CA' and SubRegion='SCAL' then Region='SCAL';		
		else if Region = 'CO' then Region = 'CLRD';
		else if Region = 'GA' then Region = 'GRGA';
		else if Region = 'HI' then Region = 'HWAI';
		else if Region = 'NW' then Region = 'PCNW';
		*else if Region = 'KPWA' then Region = 'KPWA';
		if Region in ('NCAL','SCAL','CLRD','GRGA','HWAI','KPWA') then SubRegion='NON';
		else if Region in ('PCNW','MAS') then do;
			if SubRegion = 'MRMD' then SubRegion = 'MRLD';
			else if SubRegion = 'MRVA' then SubRegion = 'VRGA';
			else if SubRegion = 'MRDC' then SubRegion = 'DC';
			else if SubRegion = 'NWOR' then SubRegion = 'ORE';
			else if SubRegion = 'NWWA' then SubRegion = 'WAS';
			end;
	run;
/*	proc freq data=lookup_kpregion; tables Region*Subregion /norow nocol nopercent; run;*/
	proc sort data=lookup_kpregion; by Metro; run;
	proc sort data=ga.b2b_bw_plvl; by Metro; run;
	proc sort data=ga.b2b_bw_slvl; by Metro; run;

/* -------------------------------------------------------------------------------------------------*/
/*  Final processing of page-level data.                                                            */
/* -------------------------------------------------------------------------------------------------*/

	data ga.b2b_bw_plvl_tbl1;

		format 	Date mmddyy10.
				WeekStart mmddyy10.
				Month monyy7.
				Quarter yyq7.
				Metro $75.
				Metro_clean $75.
				UTM_Source $50.
				UTM_Medium $50.
				Hostname_pagePath $50.
				SiteSection $40.
				Region $4.
				SubRegion $4.
				Business_Size $21.
				Channel $25.
				ChannelDetail $50.
				;

		merge ga.b2b_bw_plvl(in=a 
							 rename=(Campaign=UTM_Campaign
					                 adContent=UTM_Content))
			  lookup_kpregion(in=b);
		by Metro;

	/* -------------------------------------------------------------------------------------------------*/
	/*  UTM cleaning.                                                                                   */
	/* -------------------------------------------------------------------------------------------------*/

		UTM_Source = lowcase(strip(substr(SourceMedium,1,index(SourceMedium,'/')-1)));
		UTM_Medium = lowcase(strip(substr(SourceMedium,index(SourceMedium,'/')+1,length(SourceMedium))));
			drop SourceMedium;
		UTM_Campaign = strip(lowcase(UTM_Campaign));
		UTM_Content = strip(lowcase(UTM_Content));
		if UTM_content = '(not set)' then UTM_content = '';
		if UTM_campaign = '(not set)' then UTM_campaign = '';

	/* -------------------------------------------------------------------------------------------------*/
	/*  Clean pagePath.                                                                                 */
	/* -------------------------------------------------------------------------------------------------*/

		* Remove internal testing;
		if find(PagePath,'?gtm_debug=x','i') > 0 then delete;
		if find(PagePath,'snap-test-qa','i') > 0 then delete;
		if find(PagePath,'optimizely','i') > 0 then delete;
		if find(PagePath,'www.translatoruser-int.com','i') > 0 then delete;
		if find(PagePath,'googleweblight.com','i') > 0 then delete;
		if find(PagePath,'self-service-quoting-tool-link-test','i') > 0 then delete;
		if find(PagePath,'translate.googleusercontent.com','i') > 0 then delete;
		if find(PagePath,'business.preview.dpaprod.kpwpce.kp-aws-cloud.org','i') > 0 then delete;
		if find(PagePath,'web.archive.org','i') > 0 then delete;
		if find(PagePath,'gtm_debug=x','i') > 0 then delete;
		if find(UTM_Source,'jira.kp-aws-cloud.org','i') > 0 then delete;
		if find(UTM_Source,'preview.dpaprod.kpwpce.kp-aws-cloud.org','i') > 0 then delete;
		if find(UTM_Source,'tagassistant.google.com','i') > 0 then delete;
		if length(UTM_Source) > 50 then delete;
		if UTM_Medium = 'test' then delete;
		if find(UTM_Source,'c5c') > 0 then delete;
		if UTM_Source = 'ybdbyvd' then delete;
		if find(UTM_Source,'test','i') > 0 then delete;
		if UTM_Source = 'preview.pixel.ad' then delete;
		if UTM_Source = 'leadboldly.crosbydev.net' then delete;
		if UTM_Source = 'usc-word-edit.officeapps.live.com' then delete;
		if UTM_Source = 'usc.pods.officeapps.live.com' then delete;
		if UTM_Source = 'wabusinessdev.wpengine.com' then delete;
		if find(PagePath,'kaiserfh1-cos-mp','i')>0 then delete;
		if find(PagePath,'dev.kpbiz.org','i')>0 then delete;
		if find(landingPagePath,'dev.kpbiz.org','i')>0 then delete;

		* Hostname;
		Hostname_pagePath = substr(pagePath,1,find(pagePath,'/')-1);
		Hostname_LP = substr(landingPagePath,1,find(landingPagePath,'/')-1);

		* pagePath;
		Page_clean = lowcase(compress(tranwrd(PagePath,'business.kaiserpermanente.org/',''),''));
		*Page_clean = lowcase(compress(tranwrd(Page_clean,'kpbiz.org/',''),''));
		*Page_clean = lowcase(compress(tranwrd(Page_clean,'shopplans.kp.org/',''),''));
		*Page_clean = lowcase(compress(tranwrd(Page_clean,'kp.kaiserpermanente.org/',''),''));
		Page_clean = lowcase(compress(tranwrd(Page_clean,'.php',''),''));
		if find(Page_clean,'wt.mc_id','i') > 0 
			then Page_clean = substr(Page_clean,1,index(Page_clean,'wt.mc_id')-1);
		if find(Page_clean,'#') > 0 
			then Page_clean = substr(Page_clean,1,index(Page_clean,'#')-1);
		if find(Page_clean,'&') > 0 
			then Page_clean = substr(Page_clean,1,index(Page_clean,'&')-1);
		if substr(reverse(strip(Page_clean)),1,1) = '/' 
			then Page_clean = substr(strip(Page_clean),1,length(strip(Page_clean))-1);
		if find(Page_clean,'?') > 0 
			then Page_clean = substr(Page_clean,1,index(Page_clean,'?')-1); 

		* landingPagePath;
		EntrancePage = lowcase(compress(tranwrd(landingPagePath,'business.kaiserpermanente.org/',''),''));
		*EntrancePage = lowcase(compress(tranwrd(EntrancePage,'kpbiz.org/',''),''));
		*EntrancePage = lowcase(compress(tranwrd(EntrancePage,'shopplans.kp.org/',''),''));
		*EntrancePage = lowcase(compress(tranwrd(EntrancePage,'kp.kaiserpermanente.org/',''),''));
		EntrancePage = lowcase(compress(tranwrd(EntrancePage,'.php',''),''));
		if find(EntrancePage,'wt.mc_id','i') > 0 
			then EntrancePage = substr(EntrancePage,1,index(EntrancePage,'wt.mc_id')-1);
		if find(EntrancePage,'#') > 0 
			then EntrancePage = substr(EntrancePage,1,index(EntrancePage,'#')-1);
		if find(EntrancePage,'&') > 0 
			then EntrancePage = substr(EntrancePage,1,index(EntrancePage,'&')-1);
		if substr(reverse(strip(EntrancePage)),1,1) = '/' 
			then EntrancePage = substr(strip(EntrancePage),1,length(strip(EntrancePage))-1);
		if find(EntrancePage,'kp.kaiserpermanente.org/small-business/ca-nbrd','i') > 0
			or find(EntrancePage,'kp.kaiserpermanente.org/small-business/ca-brd','i') > 0
				then EntrancePage = 'Small Business CA Paid Search LP';
		else if find(EntrancePage,'respond.kaiserpermanente.org/coloradosmallbiz','i') > 0
				then EntrancePage = 'Small Business CO Paid Search LP';
		else if find(EntrancePage,'respond.kaiserpermanente.org/nwsmallbusiness','i') > 0
				then EntrancePage = 'Small Business NW Paid Search LP';
		else if find(EntrancePage,'kp.kaiserpermanente.org/brand','i') > 0
				and find(pagePath,'kp_b2b_lg','i') > 0
				then EntrancePage = 'B2B Business Size Unknown LP';
		else if find(EntrancePage,'kp.kaiserpermanente.org/brand','i') > 0
				then EntrancePage = 'Enterprise Listing LP';
		else if find(EntrancePage,'kp.kaiserpermanente.org/small-business/nl-brd','i') > 0
				or find(EntrancePage,'kp.kaiserpermanente.org/small-business/nl-nbrd','i') > 0
				then EntrancePage = 'Small Business National Paid Search LP';
		else if find(EntrancePage,'kp.kaiserpermanente.org/small-business/ca-da-healthplans','i') > 0
				then EntrancePage = 'Small Business CA Data Axle LP';
		/* New */
		else if find(EntrancePage,'success.kaiserpermanente.org/exec','i') > 0
				then EntrancePage = 'B2B Landing Pages for Executives - RTW';
		else if find(EntrancePage,'success.kaiserpermanente.org/hbo','i') > 0
				then EntrancePage = 'B2B Landing Pages for HR & Benefits - RTW';
		else if find(EntrancePage,'success.kaiserpermanente.org/mhw-exec','i') > 0
				then EntrancePage = 'B2B Landing Pages for Executives - MHW';
		else if find(EntrancePage,'success.kaiserpermanente.org/mhw-hbo','i') > 0
				then EntrancePage = 'B2B Landing Pages for HR & Benefits - MHW';
		else if find(EntrancePage,'success.kaiserpermanente.org/vc-exec','i') > 0
				then EntrancePage = 'B2B Landing Pages for Executives - VC';
		else if find(EntrancePage,'success.kaiserpermanente.org/vc-hbo','i') > 0
				then EntrancePage = 'B2B Landing Pages for HR & Benefits - VC';

		else if find(EntrancePage,'respond.kaiserpermanente.org/emp_acq_sbu_nurture_co_ebookdownload','i') > 0
			then EntrancePage = 'E-Book Download';
		else if find(EntrancePage,'respond.kaiserpermanente.org/emp_acq_sbu_nurture_co_ebookdownload_ty','i') > 0
			then EntrancePage = 'E-Book Download Thank You';
		if substr(strip(EntrancePage),1,1) = '?' or EntrancePage = '' then do;
			if Hostname_LP = 'business.kaiserpermanente.org'
				then EntrancePage = 'homepage';
			else EntrancePage = Hostname_LP;
		end;

		* Initialize SiteSection;
		if find(Page_clean,'/') > 0 
			then SiteSection = scan(Page_clean,1,'/');
			else SiteSection = Page_clean;
		if Page_clean = '' and Hostname_pagePath = 'business.kaiserpermanente.org'
				then Page_clean = 'homepage';
		SiteSection = scan(Page_clean,1,'/');
		/* Modified */
		if Hostname_pagePath in ('respond.kaiserpermanente.org','kp.kaiserpermanente.org',
								'success.kaiserpermanente.org','virtualproducts.kaiserpermanente.org') 
				then SiteSection = 'Landing Pages';	
		if find(Page_clean,'kp.kaiserpermanente.org/small-business/ca-nbrd','i') > 0
		 or find(Page_clean,'kp.kaiserpermanente.org/small-business/ca-brd','i') > 0
				then Page_clean = 'Small Business CA Paid Search LP';
		else if find(Page_clean,'respond.kaiserpermanente.org/coloradosmallbiz','i') > 0
				then Page_clean = 'Small Business CO Paid Search LP';
		else if find(Page_clean,'respond.kaiserpermanente.org/nwsmallbusiness','i') > 0
				then Page_clean = 'Small Business NW Paid Search LP';
		else if find(Page_clean,'kp.kaiserpermanente.org/brand','i') > 0
				then Page_clean = 'Enterprise Listing LP';
		else if find(Page_clean,'kp.kaiserpermanente.org/small-business/nl-brd','i') > 0
				or find(Page_clean,'kp.kaiserpermanente.org/small-business/nl-nbrd','i') > 0
				then Page_clean = 'Small Business National Paid Search LP';
		else if find(Page_clean,'kp.kaiserpermanente.org/small-business/ca-da-healthplans','i') > 0
				then Page_clean = 'Small Business CA Data Axle LP';
		/* New */
		else if find(Page_clean,'success.kaiserpermanente.org/exec','i') > 0
				then Page_clean = 'B2B Landing Pages for Executives - RTW';
		else if find(Page_clean,'success.kaiserpermanente.org/hbo','i') > 0
				then Page_clean = 'B2B Landing Pages for HR & Benefits - RTW';
		else if find(Page_clean,'success.kaiserpermanente.org/mhw-exec','i') > 0
				then Page_clean = 'B2B Landing Pages for Executives - MHW';
		else if find(Page_clean,'success.kaiserpermanente.org/mhw-hbo','i') > 0
				then Page_clean = 'B2B Landing Pages for HR & Benefits - MHW';
		else if find(Page_clean,'success.kaiserpermanente.org/vc-exec','i') > 0
				then Page_clean = 'B2B Landing Pages for Executives - VC';
		else if find(Page_clean,'success.kaiserpermanente.org/vc-hbo','i') > 0
				then Page_clean = 'B2B Landing Pages for HR & Benefits - VC';
		else if find(Page_clean,'success.kaiserpermanente.org')>0 then delete; /* staging */

		else if find(Page_clean,'kpbiz.org','i') > 0 then SiteSection = 'Landing Pages';
		else if find(Page_clean,'shopplans.kp.org','i') > 0 then SiteSection = 'Landing Pages';
		else if find(Page_clean,'respond.kaiserpermanente.org/emp_acq_sbu_nurture_co_ebookdownload','i') > 0
			then Page_clean = 'E-Book Download';
		else if find(Page_clean,'respond.kaiserpermanente.org/emp_acq_sbu_nurture_co_ebookdownload_ty','i') > 0
			then Page_clean = 'E-Book Download Thank You';
		else if find(Page_clean,'thrive/resource-center','i') > 0 and find(Page_clean,'topic=covid-19','i') > 0 then
			SiteSection = 'Thrive At Work: COVID-19 Resource Center';
		else if find(Page_clean,'thrive/resource-center','i') > 0 or SiteSection = 'wp-content' then 
			SiteSection = 'Thrive At Work: Resource Center';
		else if SiteSection = 'thrive' 
			then SiteSection = 'Thrive At Work';
		else if SiteSection = 'health-plan' 
			then SiteSection = 'Health Plans';
		else if SiteSection = 'kp-difference'
			then SiteSection = 'The KP Difference';
		else if SiteSection = 'insights' 
			then SiteSection = 'Insights';
		else if SiteSection = 'homepage' 
			then SiteSection = 'Homepage';
		else if SiteSection in ('contact','faqs',
							'manage-account','saved-items','site-map')
			then SiteSection = 'Other';

		if find(Page_clean,'E-Book Download','i') > 0 then SiteSection = 'Health Plans';

		if EntrancePage='(notset)' then EntrancePage='(not set)';
		if substr(Page_clean,1,1) = '?' 
			and Hostname_PagePath = 'business.kaiserpermanente.org'
			then do;
				Page_clean = 'homepage';
				SiteSection = 'Homepage';
			end;
		if substr(reverse(strip(Page_clean)),1,1) = '/' 
			then Page_clean = substr(strip(Page_clean),1,length(strip(Page_clean))-1);
		if find(Page_clean,'?') > 0 
			then Page_clean = substr(Page_clean,1,index(Page_clean,'?')-1); 
		if substr(reverse(strip(Page_clean)),1,1) = '/' 
			then Page_clean = substr(strip(Page_clean),1,length(strip(Page_clean))-1);

		else if Page_clean in ('oregon-southwest-washington-cardiac-care',
					'planning-for-next-normal-at-work',
					'small-business-health-coverage-download',
					'telehealth-supports-employees-health-and-benefits-business'
					'washington-care-access','washington-mental-health-wellness',
					'controlling-drug-costs','finding-balance-in-a-stressful-time',
					'choose-a-better-way-to-manage-costs','experience-kaiser-permanente-anywhere',
					'how-integrated-health-care-helps-keep-your-employees-healthier',
					'linkedin-contact-thank-you','mental-health-wellness-video',
					'minimizing-disruption-when-switching-health-plans',
					'reporting-that-measures-quality-and-value',
					'understand-health-care-quality-ratings',
					'what-your-employees-expect-from-health-care-today',
					'your-health-care-abcs')
				then SiteSection = 'Landing Pages';
		if SiteSection not in ('Health Plans','Insights','Thrive At Work: COVID-19 Resource Center',
								'Thrive At Work: Resource Center','Thrive At Work',
								'The KP Difference','Other','Landing Pages','Homepage')
				then SiteSection = 'Unknown';

		if EntrancePage='(notset)' then EntrancePage='(not set)';
		if find(EntrancePage,'?') > 0 
			then EntrancePage = substr(EntrancePage,1,index(EntrancePage,'?')-1); 

	/* -------------------------------------------------------------------------------------------------*/
	/*  Add WeekStart (Sun-Sat), Month, and Quarter.                                                    */
	/* -------------------------------------------------------------------------------------------------*/

		WeekStart=intnx('week',Date,0,'b');
		Month=intnx('month',Date,0,'b');
		Quarter=intnx('quarter',Date,0,'b');

	/* -------------------------------------------------------------------------------------------------*/
	/*  Add Region & SubRegion.                                                                         */
	/* -------------------------------------------------------------------------------------------------*/

		if a;
		Metro_clean=Metro;
		if Metro='(not set)' or not b then do;
			Region='NA';
			SubRegion='NA';
			Metro_clean='Other'; * Clean up MSA for non-KP region;
		end;
		if Region='NA' then Metro_clean='Other';

	/* -------------------------------------------------------------------------------------------------*/
	/*  Clean business size.                                                                         */
	/* -------------------------------------------------------------------------------------------------*/
		
		if Business_Size = 'UN' then Business_Size = 'Unknown Business Size';
			else if Business_Size = 'SB' then Business_Size = 'Small Business';
			else if Business_Size = 'LG' then Business_Size = 'Large Business';

	/* -------------------------------------------------------------------------------------------------*/
	/*  Add Channel & ChannelDetail.                                                                    */
	/* -------------------------------------------------------------------------------------------------*/

		if UTM_Medium = '(none)' then Channel = 'Direct'; 
			/* Organic Search */
			else if UTM_Medium = 'organic' then Channel = 'Organic Search';
			else if UTM_Medium = 'referral' 
				and UTM_Source in ('duckduckgo.com','us.search.yahoo.com','r.search.aol.com','us.search.yahoo.com',
								'search.aol.com','search.google.com')
				then Channel = 'Organic Search';
			/* Paid Search */
			else if UTM_Medium = 'cpc' or UTM_Source = 'sem' then do;
				Channel = 'Paid Search';
				if find(UTM_Campaign,'kp_b2b_lg') > 0 then ChannelDetail = 'Paid Search-LG';
				else if find(UTM_Campaign,'kp_b2b_sb') > 0 then ChannelDetail = 'Paid Search-SB';
				else if find(UTM_Campaign,'kp_el_non') > 0 then ChannelDetail = 'Paid Search-EL';
				else if UTM_Medium = 'sem' then ChannelDetail = 'Paid Search-MAS';
				/* (OLD) Paid Search */
				else if find(UTM_Campaign,'kp_bnd','i') > 0
					 or find(UTM_Campaign,'kp_kpif','i') > 0
					 or find(UTM_Campaign,'kp_b2b_abm','i') > 0
					 or find(UTM_Campaign,'kp_mdcr','i') > 0 
					 or find(UTM_Campaign,'kp_thrv','i') > 0 
					 then ChannelDetail = 'Paid Search-OTH';
				else if find(UTM_Campaign,'gdn','i') > 0 
					 or find(UTM_Campaign,'msan','i') > 0
					 or find(UTM_Campaign,'stream ads','i') > 0
					 then ChannelDetail = 'Paid Search-DSP';
				else if find(UTM_Campaign,'kp_sb') > 0 then ChannelDetail = 'Paid Search-SB';
				else if find(UTM_Campaign,'kp mas','i') > 0 
						or find(UTM_Campaign,'bizkp.org','i') > 0
						then ChannelDetail = 'Paid Search-MAS';
				else if find(UTM_Campaign,'el_branded product unknown','i') > 0
						or find(UTM_Campaign,'brand product unknown','i') > 0
						or find(UTM_Campaign,'kp_elst','i') > 0
						then ChannelDetail = 'Paid Search-EL';
				else if find(UTM_Campaign,'b2b','i') > 0 
						or find(UTM_Campaign,'kp_b2bl','i') > 0
						then ChannelDetail = 'Paid Search-LG';	
				else ChannelDetail = 'Paid Search-UN';
			end;
			/* (OLD) Display - Regional */
			else if (UTM_Medium = 'display' and find(UTM_Campaign,'phase_3') > 0) /* NW */
						or (UTM_Medium = '(not set)' and find(UTM_Campaign,'phase_3') > 0 and UTM_Content='NW') /* NW */
						or (UTM_Medium = 'banner' and UTM_Source = 'localiq') /* NW */
						or (UTM_Medium = 'display' and find(UTM_Campaign,'kp-b2b-choosebetter') > 0) /* MAS */
						or (UTM_Medium = 'animated banners' and UTM_Source = 'crow creative')
						or (UTM_Medium = 'display' and UTM_Source = 'crow creative') /* MAS */
				then do;
					Channel = 'Display';
					ChannelDetail = 'Display REG';
			end;
			/* (CURRENT) Display - Regional */
			else if find(UTM_Campaign,'_vd_nat_','i') = 0 and find(UTM_Campaign,'|hr')=0 and find(UTM_Campaign,'|exec')=0
					and (
					   (UTM_Medium = 'display' and find(UTM_Source,'-nw-') > 0 and (find(UTM_Campaign,'pbj') > 0 or find(UTM_Campaign,'LaneCounty') > 0)) /* NW */
					or (UTM_Medium in ('eblast','interscroller') and find(UTM_Source,'-nw-') > 0) /* NW */
					or (UTM_Medium = 'display' and find(UTM_Source,'-hi-') > 0 and find(UTM_Campaign,'pbn') > 0) /* HI */
					or (UTM_Medium in ('native','April Text Ad') and find(UTM_Source,'-hi-') > 0) /* HI */
/*					or (UTM_Medium = 'display' and find(UTM_Source,'-co-') > 0 ) /* CO */
					or (UTM_Medium = 'display' and UTM_Source = 'crow creative')
					or (UTM_Medium = 'display' and (find(UTM_Campaign,'display_md') > 0 or find(UTM_Campaign,'display_va') > 0)) /* MAS */
					or (find(UTM_Campaign,'na_b2b_2020_lc') > 0) /* NW */
					or (UTM_Medium = 'display' and UTM_Campaign = '[cma]')
					or (UTM_Medium = 'display' and find(UTM_Campaign,'b2b_lanecounty') > 0)
						)
				then do;
					Channel = 'Display';
					ChannelDetail = 'Display REG';
			end;
			/* Display - SB */
			else if UTM_Medium = 'display' and find(UTM_Source,'sb-')>0
				then do;
				Channel = 'Display';
				ChannelDetail = 'Display SB';
			end;
			/* Display - B2B */
			else if UTM_Medium = 'display' and find(UTM_Source,'lg-')>0 /* 2021 */ 
					or (UTM_Source = 'display' and UTM_Medium in ('ncal','scal','nw','was')) /* 2020 */
					or find(UTM_Campaign,'_vd_nat_','i') > 0 /* Value Demonstration */
				then do;
					Channel = 'Display';
					ChannelDetail = 'Display B2B';
			end;
			/* Email */
			else if find(UTM_Medium,'email','i') > 0 then Channel = 'Email';
			/* Direct Mail */
			else if find(UTM_Medium,'direct mail','i') > 0
				 or find(UTM_Medium,'direct-mail','i') > 0
				then Channel = 'Direct Mail';
			/* LinkedIn - SBU */
			else if UTM_Medium = 'linkedin' and (UTM_Source = 'sbu' or find(UTM_Source,'sb-')>0) then do;
					Channel = 'Social';
					ChannelDetail = 'LinkedIn SB';
			end;
			else if UTM_Medium = 'linkedin' and UTM_Source = 'pr-comms' then do;
					Channel = 'Social';
					ChannelDetail = 'LinkedIn PR Comms';
			end;
			/* Facebook/Twitter */
			else if UTM_Medium = 'facebook' and UTM_Source='sb-ca-prospect'
				then do;
					Channel = 'Social';
					ChannelDetail = 'Facebook SB';
				end;
			else if UTM_Medium = 'twitter' and (find(UTM_Campaign,'|hr')>0 or find(UTM_Campaign,'|exec')>0)
				then do;
					Channel = 'Social';
					ChannelDetail = 'Twitter LG';
				end;
			/* (OLD) LinkedIn - B2B */
			else if UTM_Campaign = 'b2b' 
					or (UTM_Medium = 'linkedin' and find(UTM_Source,'lg-') > 0)
					or (find(UTM_Source,'linkedin','i') > 0 and prxmatch("/(\w+|\d+)-\d{4}/",UTM_Campaign) > 0)
					or (find(UTM_Source,'linkedin','i') > 0 and UTM_Campaign in ('b2b-reduce-stress','b2b-value-dem'))
					or (UTM_Medium = 'linkedin' and find(UTM_Source,'linkedin','i') > 0)
					then do;
					Channel = 'Social';
					ChannelDetail = 'LinkedIn LG';
			end;
			/* LinkedIn - NW */
			else if find(UTM_Source,'social','i') > 0 and find(UTM_Campaign,'nw ','i') > 0 /* NW */
					or (find(UTM_Source,'inmail','i') > 0 and UTM_Campaign = 'kpnw') /* NW */
					or (find(UTM_Source,'linkedin','i') > 0 and UTM_Medium = 'sponsored-content' and UTM_Campaign not in ('b2b-reduce-stress','b2b-value-dem')) /* NW */
					or (UTM_Medium = 'paid social' and find(UTM_Campaign,'va') > 0)
				then do;
					Channel = 'Social';
					ChannelDetail = 'LinkedIn REG';
			end;
			/* Social - Other */
			else if find(UTM_Source,'facebook','i') > 0
					or find(UTM_Source,'social','i') > 0 
					or UTM_Source in ('lnkd.in','linkedin.com','instagram','twitter_ads','t.co','web.wechat.com','ws.sharethis.com','youtube.com','insatgram')
				then Channel = 'Organic Social'; /* Facebook, Twitter, Youtube, Other */
			/* Referral & Other */
			else Channel = 'Referral & Other';

			if UTM_Source = 'internal-kp' or find(UTM_Campaign,'comm-flash') > 0 then do;
				if find(UTM_Campaign,'comm-flash') > 0 then UTM_Campaign = 'comm-flash';
				Channel = 'Internal KP';
				ChannelDetail = 'Comm Flash';
			end;
			if Channel='Email' then do;
				if UTM_Source='broker-briefing' then UTM_Campaign='broker-briefing';
				else if UTM_Source='localiq' then UTM_Campaign=UTM_Campaign;
				else if find(UTM_Campaign,'broke') > 0 then UTM_Campaign = 'broker';
				else if find(UTM_Campaign,'employe') > 0 then UTM_Campaign = 'employer';
			end;
			*if Channel in ('Direct Mail','Email') and UTM_Source in ('sbu','sb-ca','sb-ca-prospect') and find(UTM_Campaign,'direct')=0 then UTM_Campaign = 'sbu';
	
			if Channel = 'Referral & Other' then do;
				if UTM_Source = 'account.kp.org' or UTM_Medium = 'account.kp.org' then Referral_Other = 'Account.kp.org';
				else if UTM_Source = 'sbu' and UTM_Medium = 'sales' then Referral_Other = 'Hawaii Vanity URL';
				else if (UTM_Source = 'pdf' and UTM_Medium = 'flyer') then do;
					Referral_Other = 'InfoSource';
					ChannelDetail = 'InfoSource';
				end;
				else if find(UTM_Source,'kp.showpad') > 0 then do;
					Referral_Other = 'ShowPad';
					ChannelDetail = 'ShowPad';
				end;
				else if lowcase(UTM_Medium) in ('playbook','toolkit','guide','infographic') then do;
					Referral_Other = cats("Playbooks and Toolkits / ",UTM_Campaign);
					ChannelDetail = 'Playbooks and Toolkits';
				end;
				else if lowcase(UTM_Medium) = 'referral' then Referral_Other = catx(" / ","Referral",UTM_Source);
				else Referral_Other = cats(UTM_Source," / ",UTM_Medium);
				end;
			else Referral_Other = '';
			if lowcase(UTM_Source) = 'account.kp.org' or lowcase(UTM_Medium) = 'account.kp.org'
				then ChannelDetail = 'Account.kp.org';
			if ChannelDetail = '' then ChannelDetail = Channel;

	run;

	%check_for_data(ga.b2b_bw_plvl_tbl1,=0,No records in b2b_bw_plvl_tbl1);

%end; /* (13) */
%if &cancel= %then %do; /* (14) */

	data ga.b2b_bw_plvl_tbl2;
		retain Date
					WeekStart
					Month
					Quarter
					Business_Size
					DeviceType
					userType
					Channel
					ChannelDetail
					Referral_Other
					UTM_Source
					UTM_Medium
					UTM_Campaign
					UTM_Content
					SiteSection
					Hostname_pagePath
					Page_clean
					pagePath
					Hostname_LP
					EntrancePage
					landingPagePath
					Region
					SubRegion
					Metro
					Metro_clean
					uniquePageviews
					exits
					timeOnPage
					ShopActions_Unique
					LearnActions_Unique
					ConvertActions_Unique
					ShareActions_Unique
					ConvertNonSubmit_Contact
					ConvertNonSubmit_Quote
					ConvertNonSubmit_QuoteVC
					ConvertNonSubmit_ContKPDiff /* new */
					ConvertNonSubmit_SSQ
					Convert_Call
					Rec_Update_Date
				;

		format Rec_Update_Date datetime18.;

		set ga.b2b_bw_plvl_tbl1;

		Rec_Update_Date=datetime();

		* Replace missing numeric w/ 0;
		 array change _numeric_;
	        do over change;
	            if change=. then change=0;
	        end;

		ConvertNonSubmit_Contact=.;
		ConvertNonSubmit_Quote=.;
		ConvertNonSubmit_SSQ=.;
		Convert_Call=.;

	run;

	proc sql;
	create table look1 as
	select distinct
		channel, channeldetail, utm_source, utm_medium, utm_campaign, sum(uniquePageviews) as pg
	from ga.b2b_bw_plvl_tbl2
	group by channel, channeldetail, utm_source, utm_medium, utm_campaign
	order by channel, channeldetail, utm_source, utm_medium, utm_campaign;

	create table look2 as
	select distinct
		SiteSection, Page_clean
	from ga.b2b_bw_plvl_tbl2
	order by SiteSection, Page_clean;
	quit;

	proc freq data=ga.b2b_bw_plvl_tbl2;
		tables 
				metro_clean
				hostname_pagepath
				hostname_lp
				entrancepage
				sitesection
				/ nocol norow nopercent;
	run;

	proc sql;
		create table check_dups as
		select 
			t1.* , t2.ndups
		from ga.b2b_bw_plvl_tbl2 t1
			, (select 
					date, UTM_Source, UTM_Medium, UTM_Campaign, UTM_Content, 
					landingpagepath, pagepath, metro, usertype, 
					devicetype, business_size, count(*) as ndups
			   from ga.b2b_bw_plvl_tbl2
			   group by date, UTM_Source, UTM_Medium, UTM_Campaign, UTM_Content, 
					landingpagepath, pagepath, metro, usertype, 
					devicetype, business_size
			   ) t2
		where t2.ndups>1 
			and t1.date=t2.date 
			and t1.UTM_Source=t2.UTM_Source 
			and t1.UTM_Medium=t2.UTM_Medium 
			and t1.UTM_Campaign=t2.UTM_Campaign
			and t1.UTM_Content=t2.UTM_Content
			and t1.landingpagepath=t2.landingpagepath
			and t1.metro=t2.metro
			and t1.usertype=t2.usertype
			and t1.devicetype=t2.devicetype
			and t1.business_size=t2.business_size
			and t1.pagepath=t2.pagepath
		order by t1.date, t1.business_size, t1.devicetype, t1.usertype,
			t1.UTM_Source, t1.UTM_Medium, t1.UTM_Campaign, t1.UTM_content, 
			t1.landingpagepath, t1.pagepath, t1.metro;
	quit;
	%check_for_data(check_dups,>0,Dupes in ga.b2b_bw_plvl_tbl2);

%end; /* (14) */
%if &cancel= %then %do; /* (15) */
	%check_for_data(ga.b2b_bw_plvl_tbl2,=0,No records in b2b_bw_plvl_tbl2);

	proc delete data=ga.b2b_bw_plvl; run &cancel.;
	proc delete data=ga.b2b_bw_plvl_tbl1; run &cancel.;

%end; /* (15) */
%if &cancel= %then %do; /* (16) */

	/* -------------------------------------------------------------------------------------------------*/
	/*  Add Channel & ChannelDetail.                                                                    */
	/* -------------------------------------------------------------------------------------------------*/

/*	proc sort data=lookup_sources; by UTM_Source UTM_Medium UTM_Campaign UTM_Content; run;*/
/*	proc sort data=ga.b2b_bw_plvl_tbl2; by UTM_Source UTM_Medium UTM_Campaign UTM_Content; run;*/
/*	data ga.b2b_bw_plvl_tbl3;*/
/*		format 	Channel $50.*/
/*				ChannelDetail $50.;*/
/*		merge ga.b2b_bw_plvl_tbl2(in=a)*/
/*			  lookup_sources(in=b keep=Channel ChannelDetail);*/
/*		by UTM_Source UTM_Medium UTM_Campaign UTM_Content;*/
/*	run;*/

	/* -------------------------------------------------------------------------------------------------*/
	/*  Save data to master.                                                                    */
	/* -------------------------------------------------------------------------------------------------*/

		proc sql;
		insert into ga.b2b_betterway_pagelevel_master
			select distinct * from ga.b2b_bw_plvl_tbl2;
		quit;

		* Use only when adding/deleting/changing format of columns;
/*		data ga.b2b_betterway_pagelevel_temp;*/
/*			set ga.b2b_betterway_pagelevel_master;*/
/*		run;*/
/*		proc delete data=ga.b2b_betterway_pagelevel_master; run;*/
/*		data ga.b2b_betterway_pagelevel_master;*/
/*			set ga.b2b_bw_plvl_tbl2(in=a)*/
/*				ga.b2b_betterway_pagelevel_temp(in=b);*/
/*			if a then Rec_Update_Date = datetime();*/
/*		run;*/

/* -------------------------------------------------------------------------------------------------*/
/*  Final processing of session-level data.                                                            */
/* -------------------------------------------------------------------------------------------------*/

	data ga.b2b_bw_slvl_tbl1;

		format 	Date mmddyy10.
				WeekStart mmddyy10.
				Month monyy7.
				Quarter yyq7.
				Metro $75.
				Metro_clean $75.
				UTM_Source $50.
				UTM_Medium $50.
				Hostname_LP $50.
				EntrancePage $200.
				SiteSection $40.
				Region $4.
				SubRegion $4.
				Business_Size $21.
				Channel $25.
				ChannelDetail $50.
				;

		merge ga.b2b_bw_slvl(in=a)
			  lookup_kpregion(in=b);
		by Metro;

	/* -------------------------------------------------------------------------------------------------*/
	/*  UTM & Promo ID Cleaning.                                                                        */
	/* -------------------------------------------------------------------------------------------------*/

		* UTM cleaning;
		UTM_Source = lowcase(strip(substr(SourceMedium,1,index(SourceMedium,'/')-1)));
		UTM_Medium = lowcase(strip(substr(SourceMedium,index(SourceMedium,'/')+1,length(SourceMedium))));
			drop SourceMedium;
		UTM_Campaign = strip(lowcase(UTM_Campaign));
		UTM_Content = strip(lowcase(UTM_Content));
		if UTM_content = '(not set)' then UTM_content = '';
		if UTM_campaign = '(not set)' then UTM_campaign = '';

		* Promo ID;
		* Paid Search;
		if find(UTM_content,'|') > 0 then PromoId = strip(put(substr(UTM_content,length(UTM_content)-5,6),8.));
		* PromoId is 6 digits;
		else if length(UTM_content) = 6 or length(UTM_campaign) = 6 then do;
			* PromoId should be in UTM_content;
			if prxmatch('/\d{6}/',UTM_content) then PromoId = UTM_content; 
			* Other places;
			else if prxmatch('/\d{6}/',UTM_campaign) then PromoId = UTM_campaign;
		end;
		* Only Keep Digits;
		else PromoID = '';
		if PromoID = '' and WTmc_id ne '' then PromoID = WTmc_Id;
		if PromoID ne '' then PromoId = compress(PromoId,,'kd'); /* did this fix the error? */
		if length(PromoId) ne 6 then PromoId = '';
		drop WTmc_id;

	/* -------------------------------------------------------------------------------------------------*/
	/*  Clean landingPagePath.                                                                                 */
	/* -------------------------------------------------------------------------------------------------*/

		* Remove internal testing;
		if find(landingPagePath,'?gtm_debug=x','i') > 0 then delete;
		if find(landingPagePath,'snap-test-qa','i') > 0 then delete;
		if find(landingPagePath,'optimizely','i') > 0 then delete;
		if find(landingPagePath,'www.translatoruser-int.com','i') > 0 then delete;
		if find(landingPagePath,'googleweblight.com','i') > 0 then delete;
		if find(landingPagePath,'self-service-quoting-tool-link-test','i') > 0 then delete;
		if find(landingPagePath,'translate.googleusercontent.com','i') > 0 then delete;
		if find(landingPagePath,'business.preview.dpaprod.kpwpce.kp-aws-cloud.org','i') > 0 then delete;
		if find(landingPagePath,'web.archive.org','i') > 0 then delete;
		if find(landingPagePath,'gtm_debug=x','i') > 0 then delete;
		if find(UTM_Source,'jira.kp-aws-cloud.org','i') > 0 then delete;
		if find(UTM_Source,'preview.dpaprod.kpwpce.kp-aws-cloud.org','i') > 0 then delete;
		if find(UTM_Source,'tagassistant.google.com','i') > 0 then delete;
		if length(UTM_Source) > 50 then delete;
		if UTM_Medium = 'test' then delete;
		if find(UTM_Source,'c5c') > 0 then delete;
		if UTM_Source = 'ybdbyvd' then delete;
		if find(UTM_Source,'test','i') > 0 then delete;
		if UTM_Source = 'preview.pixel.ad' then delete;
		if UTM_Source = 'leadboldly.crosbydev.net' then delete;
		if UTM_Source = 'usc-word-edit.officeapps.live.com' then delete;
		if UTM_Source = 'usc.pods.officeapps.live.com' then delete;
		if UTM_Source = 'wabusinessdev.wpengine.com' then delete;
		if find(landingPagePath,'kaiserfh1-cos-mp','i')>0 then delete;	
		if find(landingPagePath,'dev.kpbiz.org','i')>0 then delete;
		if find(landingPagePath,'dev.kpbiz.org','i')>0 then delete;

		
		* Hostname;
		Hostname_LP = substr(landingPagePath,1,find(landingPagePath,'/')-1);

		* landingPagePath;
		EntrancePage = lowcase(compress(tranwrd(landingPagePath,'business.kaiserpermanente.org/',''),''));
		*EntrancePage = lowcase(compress(tranwrd(EntrancePage,'kpbiz.org/',''),''));
		*EntrancePage = lowcase(compress(tranwrd(EntrancePage,'shopplans.kp.org/',''),''));
		*EntrancePage = lowcase(compress(tranwrd(EntrancePage,'kp.kaiserpermanente.org/',''),''));
		EntrancePage = lowcase(compress(tranwrd(EntrancePage,'.php',''),''));
		if find(EntrancePage,'wt.mc_id','i') > 0 
			then EntrancePage = substr(EntrancePage,1,index(EntrancePage,'wt.mc_id')-1);
		if find(EntrancePage,'#') > 0 
			then EntrancePage = substr(EntrancePage,1,index(EntrancePage,'#')-1);
		if find(EntrancePage,'&') > 0 
			then EntrancePage = substr(EntrancePage,1,index(EntrancePage,'&')-1);
		if substr(reverse(strip(EntrancePage)),1,1) = '/' 
			then EntrancePage = substr(strip(EntrancePage),1,length(strip(EntrancePage))-1);
		if find(EntrancePage,'?') > 0 
			then EntrancePage = substr(EntrancePage,1,index(EntrancePage,'?')-1); 

		* SiteSection;
		if find(EntrancePage,'/') > 0 
			then SiteSection = scan(EntrancePage,1,'/');
			else SiteSection = EntrancePage;
		if EntrancePage = '' and Hostname_LP = 'business.kaiserpermanente.org'
			then EntrancePage = 'homepage';
		SiteSection = scan(EntrancePage,1,'/');
		/* Modified */
		if Hostname_LP in ('respond.kaiserpermanente.org','kp.kaiserpermanente.org',
							'success.kaiserpermanente.org','virtualproducts.kaiserpermanente.org') 
				then SiteSection = 'Landing Pages';
		if find(EntrancePage,'kp.kaiserpermanente.org/small-business/ca-nbrd','i') > 0
			or find(EntrancePage,'kp.kaiserpermanente.org/small-business/ca-brd','i') > 0
				then EntrancePage = 'Small Business CA Paid Search LP';
		else if find(EntrancePage,'respond.kaiserpermanente.org/coloradosmallbiz','i') > 0
				then EntrancePage = 'Small Business CO Paid Search LP';
		else if find(EntrancePage,'respond.kaiserpermanente.org/nwsmallbusiness','i') > 0
				then EntrancePage = 'Small Business NW Paid Search LP';
		else if find(EntrancePage,'kp.kaiserpermanente.org/brand','i') > 0
				and find(landingPagePath,'kp_b2b_lg','i') > 0
				then EntrancePage = 'B2B Business Size Unknown LP';
		else if find(EntrancePage,'kp.kaiserpermanente.org/brand','i') > 0
				then EntrancePage = 'Enterprise Listing LP';
		else if find(EntrancePage,'kp.kaiserpermanente.org/small-business/nl-brd','i') > 0
				or find(EntrancePage,'kp.kaiserpermanente.org/small-business/nl-nbrd','i') > 0
				then EntrancePage = 'Small Business National Paid Search LP';
		else if find(EntrancePage,'kp.kaiserpermanente.org/small-business/ca-da-healthplans','i') > 0
				then EntrancePage = 'Small Business CA Data Axle LP';
		/* New */
		else if find(EntrancePage,'success.kaiserpermanente.org/exec','i') > 0
				then EntrancePage = 'B2B Landing Pages for Executives - RTW';
		else if find(EntrancePage,'success.kaiserpermanente.org/hbo','i') > 0
				then EntrancePage = 'B2B Landing Pages for HR & Benefits - RTW';
		else if find(EntrancePage,'success.kaiserpermanente.org/mhw-exec','i') > 0
				then EntrancePage = 'B2B Landing Pages for Executives - MHW';
		else if find(EntrancePage,'success.kaiserpermanente.org/mhw-hbo','i') > 0
				then EntrancePage = 'B2B Landing Pages for HR & Benefits - MHW';
		else if find(EntrancePage,'success.kaiserpermanente.org/vc-exec','i') > 0
				then EntrancePage = 'B2B Landing Pages for Executives - VC';
		else if find(EntrancePage,'success.kaiserpermanente.org/vc-hbo','i') > 0
				then EntrancePage = 'B2B Landing Pages for HR & Benefits - VC';
		else if find(EntrancePage,'success.kaiserpermanente.org')>0 then delete; /* staging */

		else if find(EntrancePage,'kpbiz.org','i') > 0 then SiteSection = 'Landing Pages';
		else if find(EntrancePage,'shopplans.kp.org','i') > 0 then SiteSection = 'Landing Pages';
		else if find(EntrancePage,'respond.kaiserpermanente.org/emp_acq_sbu_nurture_co_ebookdownload','i') > 0
			then EntrancePage = 'E-Book Download';
		else if find(EntrancePage,'respond.kaiserpermanente.org/emp_acq_sbu_nurture_co_ebookdownload_ty','i') > 0
			then EntrancePage = 'E-Book Download Thank You';
		else if find(EntrancePage,'thrive/resource-center','i') > 0 and find(EntrancePage,'topic=covid-19','i') > 0 then
			SiteSection = 'Thrive At Work: COVID-19 Resource Center';
		else if find(EntrancePage,'thrive/resource-center','i') > 0 or SiteSection = 'wp-content' then 
			SiteSection = 'Thrive At Work: Resource Center';
		else if SiteSection = 'thrive' 
			then SiteSection = 'Thrive At Work';
		else if SiteSection = 'health-plan' 
			then SiteSection = 'Health Plans';
		else if SiteSection = 'kp-difference'
			then SiteSection = 'The KP Difference';
		else if SiteSection = 'insights' 
			then SiteSection = 'Insights';
		else if SiteSection = 'homepage' 
			then SiteSection = 'Homepage';
		else if SiteSection in ('contact','faqs',
							'manage-account','saved-items','site-map')
			then SiteSection = 'Other';

		if find(EntrancePage,'E-Book Download','i') > 0 then SiteSection = 'Health Plans';

		if EntrancePage='(notset)' then EntrancePage='(not set)';
		if find(EntrancePage,'?') > 0 
			then EntrancePage = substr(EntrancePage,1,index(EntrancePage,'?')-1); 
		if substr(EntrancePage,1,1) = '?' 
			and Hostname_LP = 'business.kaiserpermanente.org'
			then do;
				EntrancePage = 'homepage';
				SiteSection = 'Homepage';
			end;
		if substr(reverse(strip(EntrancePage)),1,1) = '/' 
			then EntrancePage = substr(strip(EntrancePage),1,length(strip(EntrancePage))-1);

		else if EntrancePage in ('oregon-southwest-washington-cardiac-care',
					'planning-for-next-normal-at-work',
					'small-business-health-coverage-download',
					'telehealth-supports-employees-health-and-benefits-business'
					'washington-care-access','washington-mental-health-wellness',
					'controlling-drug-costs','finding-balance-in-a-stressful-time',
					'choose-a-better-way-to-manage-costs','experience-kaiser-permanente-anywhere',
					'how-integrated-health-care-helps-keep-your-employees-healthier',
					'linkedin-contact-thank-you','mental-health-wellness-video',
					'minimizing-disruption-when-switching-health-plans',
					'reporting-that-measures-quality-and-value',
					'understand-health-care-quality-ratings',
					'what-your-employees-expect-from-health-care-today',
					'your-health-care-abcs')
				then SiteSection = 'Landing Pages';
		if SiteSection not in ('Health Plans','Insights','Thrive At Work: COVID-19 Resource Center',
								'Thrive At Work: Resource Center','Thrive At Work',
								'The KP Difference','Other','Landing Pages','Homepage')
				then SiteSection = 'Unknown';
	
	/* -------------------------------------------------------------------------------------------------*/
	/*  Add WeekStart (Sun-Sat), Month, and Quarter.                                                    */
	/* -------------------------------------------------------------------------------------------------*/

		WeekStart=intnx('week',Date,0,'b');
		Month=intnx('month',Date,0,'b');
		Quarter=intnx('quarter',Date,0,'b');

	/* -------------------------------------------------------------------------------------------------*/
	/*  Add Region & SubRegion.                                                                         */
	/* -------------------------------------------------------------------------------------------------*/

		if a;
		Metro_clean=Metro;
		if Metro='(not set)' or not b then do;
			Region='NA';
			SubRegion='NA';
			Metro_clean='Other'; * Clean up MSA for non-KP region;
		end;
		if Region='NA' then Metro_clean='Other';

	/* -------------------------------------------------------------------------------------------------*/
	/*  Clean business size.                                                                         */
	/* -------------------------------------------------------------------------------------------------*/
		
		if Business_Size = 'UN' then Business_Size = 'Unknown Business Size';
			else if Business_Size = 'SB' then Business_Size = 'Small Business';
			else if Business_Size = 'LG' then Business_Size = 'Large Business';

	/* -------------------------------------------------------------------------------------------------*/
	/*  Add Channel & ChannelDetail.                                                                    */
	/* -------------------------------------------------------------------------------------------------*/

			if UTM_Medium = '(none)' then Channel = 'Direct'; 
			/* Organic Search */
			else if UTM_Medium = 'organic' then Channel = 'Organic Search';
			else if UTM_Medium = 'referral' 
				and UTM_Source in ('duckduckgo.com','us.search.yahoo.com','r.search.aol.com','us.search.yahoo.com',
								'search.aol.com','search.google.com')
				then Channel = 'Organic Search';
			/* Paid Search */
			else if UTM_Medium = 'cpc' or UTM_Source = 'sem' then do;
				Channel = 'Paid Search';
				if find(UTM_Campaign,'kp_b2b_lg') > 0 then ChannelDetail = 'Paid Search-LG';
				else if find(UTM_Campaign,'kp_b2b_sb') > 0 then ChannelDetail = 'Paid Search-SB';
				else if find(UTM_Campaign,'kp_el_non') > 0 then ChannelDetail = 'Paid Search-EL';
				else if UTM_Medium = 'sem' then ChannelDetail = 'Paid Search-MAS';
				/* (OLD) Paid Search */
				else if find(UTM_Campaign,'kp_bnd','i') > 0
					 or find(UTM_Campaign,'kp_kpif','i') > 0
					 or find(UTM_Campaign,'kp_b2b_abm','i') > 0
					 or find(UTM_Campaign,'kp_mdcr','i') > 0 
					 or find(UTM_Campaign,'kp_thrv','i') > 0 
					 then ChannelDetail = 'Paid Search-OTH';
				else if find(UTM_Campaign,'gdn','i') > 0 
					 or find(UTM_Campaign,'msan','i') > 0
					 or find(UTM_Campaign,'stream ads','i') > 0
					 then ChannelDetail = 'Paid Search-DSP';
				else if find(UTM_Campaign,'kp_sb') > 0 then ChannelDetail = 'Paid Search-SB';
				else if find(UTM_Campaign,'kp mas','i') > 0 
						or find(UTM_Campaign,'bizkp.org','i') > 0
						then ChannelDetail = 'Paid Search-MAS';
				else if find(UTM_Campaign,'el_branded product unknown','i') > 0
						or find(UTM_Campaign,'brand product unknown','i') > 0
						or find(UTM_Campaign,'kp_elst','i') > 0
						then ChannelDetail = 'Paid Search-EL';
				else if find(UTM_Campaign,'b2b','i') > 0 
						or find(UTM_Campaign,'kp_b2bl','i') > 0
						then ChannelDetail = 'Paid Search-LG';	
				else ChannelDetail = 'Paid Search-UN';
			end;
			/* (OLD) Display - Regional */
			else if (UTM_Medium = 'display' and find(UTM_Campaign,'phase_3') > 0) /* NW */
						or (UTM_Medium = '(not set)' and find(UTM_Campaign,'phase_3') > 0 and UTM_Content='NW') /* NW */
						or (UTM_Medium = 'banner' and UTM_Source = 'localiq') /* NW */
						or (UTM_Medium = 'display' and find(UTM_Campaign,'kp-b2b-choosebetter') > 0) /* MAS */
						or (UTM_Medium = 'animated banners' and UTM_Source = 'crow creative')
						or (UTM_Medium = 'display' and UTM_Source = 'crow creative') /* MAS */
				then do;
					Channel = 'Display';
					ChannelDetail = 'Display REG';
			end;
				/* (CURRENT) Display - Regional */
			else if find(UTM_Campaign,'_vd_nat_','i') = 0 and find(UTM_Campaign,'|hr')=0 and find(UTM_Campaign,'|exec')=0
					and (
					   (UTM_Medium = 'display' and find(UTM_Source,'-nw-') > 0 and (find(UTM_Campaign,'pbj') > 0 or find(UTM_Campaign,'LaneCounty') > 0)) /* NW */
					or (UTM_Medium in ('eblast','interscroller') and find(UTM_Source,'-nw-') > 0) /* NW */
					or (UTM_Medium = 'display' and find(UTM_Source,'-hi-') > 0 and find(UTM_Campaign,'pbn') > 0) /* HI */
					or (UTM_Medium in ('native','April Text Ad') and find(UTM_Source,'-hi-') > 0) /* HI */
/*					or (UTM_Medium = 'display' and find(UTM_Source,'-co-') > 0 ) /* CO */
					or (UTM_Medium = 'display' and UTM_Source = 'crow creative')
					or (UTM_Medium = 'display' and (find(UTM_Campaign,'display_md') > 0 or find(UTM_Campaign,'display_va') > 0)) /* MAS */
					or (find(UTM_Campaign,'na_b2b_2020_lc') > 0) /* NW */
					or (UTM_Medium = 'display' and UTM_Campaign = '[cma]')
					or (UTM_Medium = 'display' and find(UTM_Campaign,'b2b_lanecounty') > 0)
						)
				then do;
					Channel = 'Display';
					ChannelDetail = 'Display REG';
			end;
			/* Display - SB */
			else if UTM_Medium = 'display' and find(UTM_Source,'sb-')>0
				then do;
				Channel = 'Display';
				ChannelDetail = 'Display SB';
			end;
			/* Display - B2B */
			else if UTM_Medium = 'display' and find(UTM_Source,'lg-')>0 /* 2021 */ 
					or (UTM_Source = 'display' and UTM_Medium in ('ncal','scal','nw','was')) /* 2020 */
					or find(UTM_Campaign,'_vd_nat_','i') > 0 /* Value Demonstration */
				then do;
					Channel = 'Display';
					ChannelDetail = 'Display B2B';
			end;
			/* Email */
			else if find(UTM_Medium,'email','i') > 0 then Channel = 'Email';
			/* Direct Mail */
			else if find(UTM_Medium,'direct mail','i') > 0
				 or find(UTM_Medium,'direct-mail','i') > 0
				then Channel = 'Direct Mail';
			/* LinkedIn - SBU */
			else if UTM_Medium = 'linkedin' and (UTM_Source = 'sbu' or find(UTM_Source,'sb-')>0) then do;
					Channel = 'Social';
					ChannelDetail = 'LinkedIn SB';
			end;
			/* Organic */
			else if UTM_Medium = 'linkedin' and UTM_Source = 'pr-comms' then do;
					Channel = 'Social';
					ChannelDetail = 'LinkedIn PR Comms';
			end;
			else if find(UTM_Medium,'linkedin') then do;
				if lowcase(Campaign) = 'virtual_care_msk'
				or Medium = 'sam-social-post'
					then do;
						Channel = 'Social';
						ChannelDetail = 'Organic LinkedIn Posts';
			        end;
			end;
			/* Facebook/Twitter */
			else if UTM_Medium = 'facebook' and UTM_Source='sb-ca-prospect'
				then do;
					Channel = 'Social';
					ChannelDetail = 'Facebook SB';
				end;
			else if UTM_Medium = 'twitter' and (find(UTM_Campaign,'|hr')>0 or find(UTM_Campaign,'|exec')>0)
				then do;
					Channel = 'Social';
					ChannelDetail = 'Twitter LG';
				end;
			/* (OLD) LinkedIn - B2B */
			else if UTM_Campaign = 'b2b' 
					or (UTM_Medium = 'linkedin' and find(UTM_Source,'lg-') > 0)
					or (find(UTM_Source,'linkedin','i') > 0 and prxmatch("/(\w+|\d+)-\d{4}/",UTM_Campaign) > 0)
					or (find(UTM_Source,'linkedin','i') > 0 and UTM_Campaign in ('b2b-reduce-stress','b2b-value-dem'))
					or (UTM_Medium = 'linkedin' and find(UTM_Source,'linkedin','i') > 0)
					then do;
					Channel = 'Social';
					ChannelDetail = 'LinkedIn LG';
			end;
			/* LinkedIn - NW */
			else if find(UTM_Source,'social','i') > 0 and find(UTM_Campaign,'nw ','i') > 0 /* NW */
					or (find(UTM_Source,'inmail','i') > 0 and UTM_Campaign = 'kpnw') /* NW */
					or (find(UTM_Source,'linkedin','i') > 0 and UTM_Medium = 'sponsored-content' and UTM_Campaign not in ('b2b-reduce-stress','b2b-value-dem')) /* NW */
					or (UTM_Medium = 'paid social' and find(UTM_Campaign,'va') > 0)
				then do;
					Channel = 'Social';
					ChannelDetail = 'LinkedIn REG';
			end;
			/* Social - Other */
			else if find(UTM_Source,'facebook','i') > 0
					or find(UTM_Source,'social','i') > 0 
					or UTM_Source in ('lnkd.in','linkedin.com','instagram','twitter_ads','t.co','web.wechat.com','ws.sharethis.com','youtube.com','insatgram')
				then Channel = 'Organic Social'; /* Facebook, Twitter, Youtube, Other */
			/* Referral & Other */
			else Channel = 'Referral & Other';

			if UTM_Source = 'internal-kp' or find(UTM_Campaign,'comm-flash') > 0 then do;
				if find(UTM_Campaign,'comm-flash') > 0 then UTM_Campaign = 'comm-flash';
				Channel = 'Internal KP';
				ChannelDetail = 'Comm Flash';
			end;
			if Channel='Email' then do;
				if UTM_Source='broker-briefing' then UTM_Campaign='broker-briefing';
				else if UTM_Source='localiq' then UTM_Campaign=UTM_Campaign;
				else if find(UTM_Campaign,'broke') > 0 then UTM_Campaign = 'broker';
				else if find(UTM_Campaign,'employe') > 0 then UTM_Campaign = 'employer';
			end;
			*if Channel in ('Direct Mail','Email') and UTM_Source in ('sbu','sb-ca','sb-ca-prospect') and find(UTM_Campaign,'direct')=0 then UTM_Campaign = 'sbu';
	
			if Channel = 'Referral & Other' then do;
				if UTM_Source = 'account.kp.org' or UTM_Medium = 'account.kp.org' then Referral_Other = 'Account.kp.org';
				else if UTM_Source = 'sbu' and UTM_Medium = 'sales' then Referral_Other = 'Hawaii Vanity URL';
				else if (UTM_Source = 'pdf' and UTM_Medium = 'flyer') then do;
					Referral_Other = 'InfoSource';
					ChannelDetail = 'InfoSource';
				end;
				else if find(UTM_Source,'kp.showpad') > 0 then do;
					Referral_Other = 'ShowPad';
					ChannelDetail = 'ShowPad';
				end;
				else if lowcase(UTM_Medium) in ('playbook','toolkit','guide','infographic') then do;
					Referral_Other = cats("Playbooks and Toolkits / ",UTM_Campaign);
					ChannelDetail = 'Playbooks and Toolkits';
				end;
				else if lowcase(UTM_Medium) = 'referral' then Referral_Other = catx(" / ","Referral",UTM_Source);
				else Referral_Other = cats(UTM_Source," / ",UTM_Medium);
				end;
			else Referral_Other = '';
			if lowcase(UTM_Source) = 'account.kp.org' or lowcase(UTM_Medium) = 'account.kp.org'
				then ChannelDetail = 'Account.kp.org';
			if ChannelDetail = '' then ChannelDetail = Channel;

		
	run;

	%check_for_data(ga.b2b_bw_slvl_tbl1,=0,No records in b2b_bw_slvl_tbl1);

%end; /* (16) */
%if &cancel= %then %do; /* (17) */

	data ga.b2b_bw_slvl_tbl2;
		retain Date
				WeekStart
				Month
				Quarter
				Business_Size
				DeviceType
				userType
				Channel
				ChannelDetail
				Referral_Other
				UTM_Source
				UTM_Medium
				UTM_Campaign
				UTM_Content
				SiteSection
				Hostname_LP
				EntrancePage
				landingPagePath
				PromoID
				Region
				SubRegion
				Metro
				Metro_clean
				users
				sessions_all
				sessions_bw
				sessions_hp
				sessions_sbhp
				sessionDuration
				bounces
				ConvertNonSubmit_Contact
				ConvertNonSubmit_Quote
				ConvertNonSubmit_SSQ
				ConvertSubmit_Contact
				ConvertSubmit_Quote
				Convert_Call
				SB_MAS_Leads
				Weighted_Actions /* new */
				Rec_Update_Date
				;

		format Rec_Update_Date datetime18.;

		set ga.b2b_bw_slvl_tbl1;

		Rec_Update_Date=datetime();

		* Replace missing numeric w/ 0;
		 array change _numeric_;
	        do over change;
	            if change=. then change=0;
	        end;

	run;

	proc freq data=ga.b2b_bw_slvl_tbl2;
		tables 
/*				metro*/
				metro_clean
/*				utm_source*/
/*				utm_medium*/
				hostname_LP
				entrancepage
				sitesection
				region*subregion
				business_size
/*				promoId*/
				/ nocol norow nopercent list missing;
	run;

	proc sql;
	create table frequency_channels as
	select distinct
		channel, channeldetail, utm_source, utm_medium, utm_campaign
	from ga.b2b_bw_slvl_tbl2
	order by channel, channeldetail, utm_medium, utm_campaign;

	create table frequency_pages as
	select distinct
		Hostname_LP, SiteSection, EntrancePage
	from ga.b2b_bw_slvl_tbl2
	order by Hostname_LP, SiteSection, EntrancePage;
	quit;

	proc sql;
		create table check_dups as
		select 
			t1.* , t2.ndups
		from ga.b2b_bw_slvl_tbl2 t1
			, (select 
					date, UTM_Source, UTM_Medium, UTM_Campaign, UTM_Content, 
					landingpagepath, metro, usertype, 
					devicetype, business_size, count(*) as ndups
			   from ga.b2b_bw_slvl_tbl2
			   group by date, UTM_Source, UTM_Medium, UTM_Campaign, UTM_Content, 
					landingpagepath, metro, usertype, 
					devicetype, business_size
			   ) t2
		where t2.ndups>1 
			and t1.date=t2.date 
			and t1.UTM_Source=t2.UTM_Source 
			and t1.UTM_Medium=t2.UTM_Medium 
			and t1.UTM_Campaign=t2.UTM_Campaign
			and t1.UTM_Content=t2.UTM_Content
			and t1.landingpagepath=t2.landingpagepath
			and t1.metro=t2.metro
			and t1.usertype=t2.usertype
			and t1.devicetype=t2.devicetype
			and t1.business_size=t2.business_size
		order by t1.date, t1.business_size, t1.devicetype, t1.usertype,
			t1.UTM_Source, t1.UTM_Medium, t1.UTM_Campaign, t1.UTM_content, 
			t1.landingpagepath, t1.metro;
	quit;
	%check_for_data(check_dups,>0,Dupes in ga.b2b_bw_slvl_tbl2!);

%end; /* (17) */
%if &cancel= %then %do; /* (18) */
	%check_for_data(ga.b2b_bw_slvl_tbl2,=0,No records in b2b_bw_slvl_tbl2);

	proc delete data=ga.b2b_bw_slvl; run &cancel.;
	proc delete data=ga.b2b_bw_slvl_tbl1; run &cancel.;
%end; /* (18) */
%if &cancel= %then %do; /* (19) */

	/* -------------------------------------------------------------------------------------------------*/
	/*  Add Channel & ChannelDetail.                                                                    */
	/* -------------------------------------------------------------------------------------------------*/

/*	proc sort data=lookup_sources; by UTM_Source UTM_Medium UTM_Campaign UTM_Content; run;*/
/*	proc sort data=ga.b2b_bw_slvl_tbl3_&per; by UTM_Source UTM_Medium UTM_Campaign UTM_Content; run;*/
/*	data ga.b2b_bw_slvl_tbl4_&per;*/
/*		format 	Channel $50.*/
/*				ChannelDetail $50.;*/
/*		merge ga.b2b_bw_slvl_tbl3_&per(in=a)*/
/*			  lookup_sources(in=b keep=Channel ChannelDetail);*/
/*		by UTM_Source UTM_Medium UTM_Campaign UTM_Content;*/
/*	run;*/

	/* -------------------------------------------------------------------------------------------------*/
	/*  Save data to master.                                                                    */
	/* -------------------------------------------------------------------------------------------------*/

		proc sql;
		insert into ga.b2b_betterway_sesslevel_master
			select distinct * from ga.b2b_bw_slvl_tbl2;
		quit;

		/* Use only when adding/deleting/changing format of columns */
/*		data ga.b2b_betterway_sesslevel_temp;*/
/*			set ga.b2b_betterway_sesslevel_master;*/
/*		run;*/
/*		proc delete data=ga.b2b_betterway_sesslevel_master; run;*/
/*		data ga.b2b_betterway_sesslevel_master;*/
/*			set ga.b2b_bw_slvl_tbl2(in=a)*/
/*				ga.b2b_betterway_sesslevel_temp(in=b);*/
/*			if a then Rec_Update_Date = datetime();*/
/*		run;*/

/* merge? */

/* Need to backfill contact submissions for 2020 (all months when 0) */
			/* check to see the date range?? */
/* Need to create macros */
/* Need to remove exits from shop and learn unique */
/* need to add ELLP, need to remove total ELLP */
/* need to add in bots with flag */

	proc sql;
	create table b2b_betterway_master as
	select 
		coalesce(a.Date,b.Date) as Date format mmddyy10.
	,	coalesce(a.WeekStart,b.WeekStart) as WeekStart format mmddyy10.
	,	coalesce(a.Month,b.Month) as Month format monyy7.
	,	coalesce(a.Quarter,b.Quarter) as Quarter format yyq7.
	, 	coalescec(a.Business_Size,b.Business_Size) as Business_Size
	, 	coalescec(a.DeviceType,b.DeviceType) as DeviceType
	, 	coalescec(a.UserType,b.UserType) as UserType
	, 	coalescec(a.Channel,b.Channel) as Channel
	, 	coalescec(a.ChannelDetail,b.ChannelDetail) as ChannelDetail
	, 	coalescec(a.Referral_Other,b.Referral_Other) as Referral_Other
	,	coalescec(a.UTM_Source,b.UTM_Source) as UTM_Source
	, 	coalescec(a.UTM_Medium,b.UTM_Medium) as UTM_Medium
	, 	coalescec(a.UTM_Campaign,b.UTM_Campaign) as UTM_Campaign
	, 	coalescec(a.UTM_Content,b.UTM_Content) as UTM_Content
	,	coalescec(a.SiteSection,b.SiteSection) as SiteSection
	,	coalescec(a.Hostname_LP,b.Hostname_pagePath) as Hostname
	,	coalescec(a.EntrancePage,b.EntrancePage) as EntrancePage
		/* raw ,*/  /* coalescec(a.LandingPagePath,b.LandingPagePath) as LandingPagePath */
	,	b.Page_clean as Page
		/* raw ,*/	/* b.pagePath */
	,	a.PromoID
	,	coalescec(a.Region,b.Region) as Region
	,	coalescec(a.SubRegion,b.SubRegion) as SubRegion
		/* raw ,*/ 	/* coalescec(a.Metro,b.Metro) as Metro */
	, 	coalescec(a.Metro_clean,b.Metro_clean) as Metro

	,	coalesce(a.Users,0) as Users
	,	coalesce(a.Sessions_all,0) as Sessions_all
	,	coalesce(a.Sessions_BW,0) as Sessions_BW
	,	coalesce(a.Sessions_HP,0) as Sessions_HP
	,	coalesce(a.Sessions_SBHP,0) as Sessions_SBHP
	,	coalesce(a.sessionDuration,0) as sessionDuration
	,	b.timeOnPage
	,	b.uniquePageviews
	,	coalesce(a.Bounces,0) as Bounces
	,	b.Exits
	,	b.ShopActions_Unique
	,	b.LearnActions_Unique
	,	b.ConvertActions_Unique
	,	b.ShareActions_Unique
	,	coalesce(a.ConvertNonSubmit_Contact,0)+coalesce(b.ConvertNonSubmit_Contact,0)+coalesce(b.ConvertNonSubmit_ContKPDiff,0) as ConvertNonSubmit_Contact
	,	coalesce(a.ConvertNonSubmit_Quote,0)+coalesce(b.ConvertNonSubmit_Quote,0)+coalesce(b.ConvertNonSubmit_QuoteVC,0) as ConvertNonSubmit_Quote
	,	coalesce(a.ConvertNonSubmit_SSQ,0)+coalesce(b.ConvertNonSubmit_SSQ,0) as ConvertNonSubmit_SSQ 
	,	coalesce(a.ConvertSubmit_Contact,0) as ConvertSubmit_Contact
	,	coalesce(a.ConvertSubmit_Quote,0) as ConvertSubmit_Quote
	,	coalesce(a.Convert_Call,0)+coalesce(b.Convert_Call,0) as Convert_Call
	,	coalesce(a.SB_MAS_Leads,0) as SB_MAS_Leads
	,	coalesce(a.Weighted_Actions,0) as Weighted_Actions format comma8.2
	,	coalesce(a.Rec_Update_Date,b.Rec_Update_Date) as Rec_Update_Date format datetime12.
	from ga.b2b_bw_slvl_tbl2 a
	full outer join ga.b2b_bw_plvl_tbl2 b
		on a.Date=b.Date
		   and a.Business_Size=b.Business_Size
		   and a.DeviceType=b.DeviceType
		   and a.UserType=b.UserType
		   and a.UTM_Source=b.UTM_Source
		   and a.UTM_Medium=b.UTM_Medium
		   and a.UTM_Campaign=b.UTM_Campaign
		   and a.UTM_Content=b.UTM_Content
		   and a.LandingPagePath=b.LandingPagePath
		   and a.Metro=b.Metro
		   and a.LandingPagePath=b.PagePath
	;
	quit;

	/* this data WILL have dupes. That is ok */

	proc delete data=ga.b2b_bw_slvl_tbl2; run &cancel.;
	proc delete data=ga.b2b_bw_plvl_tbl2; run &cancel.;

	/* -------------------------------------------------------------------------------------------------*/
	/*  Get last date of last master file.                                                              */
	/* -------------------------------------------------------------------------------------------------*/

	proc sql;
	select distinct count(*) into :Nnew from b2b_betterway_master;
	quit;

	proc sql noprint;
	select distinct 
		max(Date) format mmddyy6.,
		max(Date) format date9.
		into
		:LastData_Old,
		:LastDate_OldNum
		from prod.b2b_betterway_master;
	quit;

	proc sql;
	insert into prod.b2b_betterway_master
		select distinct * from b2b_betterway_master;
	quit;

	/* Use only when adding/deleting/changing format of columns */
/*		data ga.b2b_betterway_master_temp;*/
/*			set prod.b2b_betterway_master;*/
/*		run;*/
/*		proc delete data=prod.b2b_betterway_master; run;*/
/*		data prod.b2b_betterway_master;*/
/*			set b2b_betterway_master(in=a)*/
/*				ga.b2b_betterway_master_temp(in=b);*/
/*			if a then Rec_Update_Date = datetime();*/
/*		run;*/

%end; /* (19) */
%if &cancel= %then %do; /* (20) */
/* -------------------------------------------------------------------------------------------------*/
/*                                                                                                  */
/*                                                                                                  */
/*                                              Archive.                                            */
/*                                                                                                  */
/*                                                                                                  */
/* -------------------------------------------------------------------------------------------------*/

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
		from prod.b2b_betterway_master;
	quit;

/* -------------------------------------------------------------------------------------------------*/
/*  Save master file(s) --> zip archive.                                                            */
/* -------------------------------------------------------------------------------------------------*/

	* b2b_betterway_master;
	data archive.b2b_betterway_&FirstData._&LastData;
		set prod.b2b_betterway_master;
	run;

	ods package(archived) open nopf;
	ods package(archived) add file="&final_file_path/Archive/b2b_betterway_&FirstData._&LastData..sas7bdat";
	ods package(archived) publish archive properties (
		archive_name="b2b_betterway_&FirstData._&LastData..zip"
		archive_path="&final_file_path/Archive/");
	ods package(archived) close;
	proc delete data=archive.b2b_betterway_&FirstData._&LastData; run;

	filename old_arch "&final_file_path/Archive/b2b_betterway_&FirstData._&LastData_Old..zip";
	data _null_;
		rc=fdelete("old_arch");
		put rc=;
	run;

	/* -------------------------------------------------------------------------------------------------*/
	/*  Frequency Tables.                                                                               */
	/* -------------------------------------------------------------------------------------------------*/ 

	/* list of site section "other" and "landing pages" page paths */
	/* add new pages output */

	proc sql; 
		select distinct 
			count(distinct date) 
		into :days 
		from prod.b2b_betterway_master
		where Date >= "&Campaign_StartDate"d;
	quit;

	options dlcreatedir;
	libname freq xlsx "&output_file_path/Frequency Tables - Get_GA_Data_Weekly.xlsx"; run;
	proc sql;

	create table freq.Date as
		select distinct
			Date
		,	case when Date>="&Campaign_StartDate"d then 1 else 0 end as New_Data
		,	sum(sessions_all) as Sessions
		,	sum(uniquePageviews) as uniquePageviews
		,	sum(ShopActions_Unique
				+LearnActions_Unique
				+ShareActions_Unique
				+ConvertActions_Unique) as UniqueActions
		,	sum(uniquePageviews)/sum(sessions_all) as Pages_Per_Session
		,	sum(ShopActions_Unique
				+LearnActions_Unique
				+ShareActions_Unique
				+ConvertActions_Unique)/sum(sessions_all) as Actions_Per_Session
		from prod.b2b_betterway_master
		where Date>=intnx('day',"&Campaign_StartDate"d,-&days.,'s')
		group by 
			Date
		order by 
			Date;

	create table freq.Business_Size as
		select distinct
			Business_Size
		,	sum(case when Date>="&Campaign_StartDate"d then sessions_all end) as Sessions_All
		,	sum(case when Date>="&Campaign_StartDate"d then sessions_all end)/
			sum(case when Date<"&Campaign_StartDate"d then sessions_all end)-1 as Pct_Diff_Sessions_All format percent7.2
		,	sum(sessions_BW) as Sessions_BW
		,	sum(case when Date>="&Campaign_StartDate"d then sessions_BW end)/
			sum(case when Date<"&Campaign_StartDate"d then sessions_BW end)-1 as Pct_Diff_Sessions_BW format percent7.2
		from prod.b2b_betterway_master
		where Date>=intnx('day',"&Campaign_StartDate"d,-&days.,'s')
		group by 
			Business_Size
		order by 
			Business_Size;

	create table freq.LP_Hostname as
		select distinct
			Hostname
		,	sum(case when Date>="&Campaign_StartDate"d then sessions_all end) as Sessions
		,	sum(case when Date>="&Campaign_StartDate"d then sessions_all end)/
			sum(case when Date<"&Campaign_StartDate"d then sessions_all end)-1 as Pct_Diff_Sessions format percent7.2
		,	sum(case when Date>="&Campaign_StartDate"d then uniquePageviews end)/
			sum(case when Date<"&Campaign_StartDate"d then uniquePageviews end)-1 as Pct_Diff_Pvs format percent7.2
		,	sum(case when Date>="&Campaign_StartDate"d then ShopActions_Unique
															+LearnActions_Unique
															+ShareActions_Unique
															+ConvertActions_Unique end)/
				sum(case when Date<"&Campaign_StartDate"d then ShopActions_Unique
																+LearnActions_Unique
																+ShareActions_Unique
																+ConvertActions_Unique end)-1 
						as Pct_Diff_Actions format percent7.2
		,	sum(case when Date>="&Campaign_StartDate"d then uniquePageviews end)/
				sum(case when Date<"&Campaign_StartDate"d then sessions_all end)-1 
						as Pct_Diff_PvsPerSession format percent7.2
		,	(sum(case when Date>="&Campaign_StartDate"d then ShopActions_Unique
															+LearnActions_Unique
															+ShareActions_Unique
															+ConvertActions_Unique end)/
				sum(case when Date>="&Campaign_StartDate"d then sessions_all end))/
			(sum(case when Date<"&Campaign_StartDate"d then ShopActions_Unique
															+LearnActions_Unique
															+ShareActions_Unique
															+ConvertActions_Unique end)/
				sum(case when Date<"&Campaign_StartDate"d then sessions_all end))-1 
			as Pct_Diff_ActionsPerSession format percent7.2
		from prod.b2b_betterway_master
		where Date>=intnx('day',"&Campaign_StartDate"d,-&days.,'s')
		group by 
			Hostname
		order by 
			Hostname;

	create table freq.List_Pages as
		select distinct
			Hostname
		,	SiteSection
		,	Page
		,	sum(case when Date>="&Campaign_StartDate"d then uniquePageviews end) as uniquePageviews
		,	sum(case when Date>="&Campaign_StartDate"d then uniquePageviews end)/
			sum(case when Date<"&Campaign_StartDate"d then uniquePageviews end)-1 as Pct_Diff_Pvs format percent7.2
		from prod.b2b_betterway_master
		where Date>=intnx('day',"&Campaign_StartDate"d,-&days.,'s')
		group by 
			Hostname
		,	SiteSection
		,	Page
		order by 
			Hostname
		,	SiteSection
		,	Page;

	create table freq.List_Channels as
		select distinct
			Channel
		,	ChannelDetail
		,	Referral_Other
		,	UTM_Source
		,	UTM_Medium
		,	UTM_Campaign
		,	UTM_Content
		,	sum(case when Date>="&Campaign_StartDate"d then sessions_all end) as Sessions
		,	sum(case when Date>="&Campaign_StartDate"d then sessions_all end)/
			sum(case when Date<"&Campaign_StartDate"d then sessions_all end)-1 as Pct_Diff_Sessions format percent7.2
		from prod.b2b_betterway_master
		where Date>=intnx('day',"&Campaign_StartDate"d,-&days.,'s')
		group by 
			Channel
		,	ChannelDetail
		,	Referral_Other
		,	UTM_Source
		,	UTM_Medium
		,	UTM_Campaign
		,	UTM_Content
		order by 
			Channel
		,	ChannelDetail
		,	Referral_Other
		,	UTM_Source
		,	UTM_Medium
		,	UTM_Campaign
		,	UTM_Content;

	quit;

	* b2b_betterway_sesslevel_master;
	ods package(archived) open nopf;
	ods package(archived) add file="&output_file_path/b2b_betterway_sesslevel_master.sas7bdat";
	ods package(archived) publish archive properties (
		archive_name="b2b_betterway_sesslevel_master.zip"
		archive_path="&output_file_path");
	ods package(archived) close;
	* b2b_betterway_pagelevel_master;
	ods package(archived) open nopf;
	ods package(archived) add file="&output_file_path/b2b_betterway_pagelevel_master.sas7bdat";
	ods package(archived) publish archive properties (
		archive_name="b2b_betterway_pagelevel_master.zip"
		archive_path="&output_file_path");
	ods package(archived) close;

/*	proc delete data=ga.b2b_betterway_pagelevel_temp; run;*/

%end; /* (20) */

/* -------------------------------------------------------------------------------------------------*/
/*  Email.                                                                                          */
/* -------------------------------------------------------------------------------------------------*/

	%let input_files = &output_file_path;

	/* you may change the default sentFrom and sentTo */
	%emailB2Bdashboard(Get_GA_Data_Weekly,
			attachFreqTableFlag=1,
			attachLogFlag=1 /*,
			sentFrom=,
			sentTo=*/
			);

	proc printto; run; /* Turn off log export to .txt */