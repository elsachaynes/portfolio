/****************************************************************************************************/
/*  Program Name:       Get_GA_ContentPerformance_Data_Monthly.sas                                  */
/*                                                                                                  */
/*  Date Created:       June 1, 2021                                                                */
/*                                                                                                  */
/*  Created By:         Elle Haynes                                                                 */
/*                                                                                                  */
/*  Purpose:            Refreshes the data for the B2B Better Way Content Performance Dashboard.    */
/*                                                                                                  */
/*  Inputs:             User must provide start and end date for current month/reporting period.    */
/*                                                                                                  */
/* -------------------------------------------------------------------------------------------------*/	
/*  Notes:                                                                                          */
/* -------------------------------------------------------------------------------------------------*/
/*  Date Modified:      March 31, 2022                                                              */
/*  Modified by:        Elle Haynes                                                                 */
/*  Description:        Standardized in alignment with Get_GA_Data_Weekly (and same schedule).      */
/****************************************************************************************************/

/* -------------------------------------------------------------------------------------------------*/
/*  Run libraries                                                                                   */
/* -------------------------------------------------------------------------------------------------*/

	Options mlogic mprint symbolgen;

	filename old_log "/gpfsFS2/sasdata/nfs/ndc_grid/po_imca_digital/EHaynes/B2B Better Way Monthly Report/LOG Get_GA_ContentPerformance_Data_Monthly.txt";
	data _null_; rc=fdelete("old_log"); put rc=; run;
	proc printto log="/gpfsFS2/sasdata/nfs/ndc_grid/po_imca_digital/EHaynes/B2B Better Way Monthly Report/LOG Get_GA_ContentPerformance_Data_Monthly.txt"; run;

/* -------------------------------------------------------------------------------------------------*/
/*  SET-UP: GA Data Pull.                                                                           */
/* -------------------------------------------------------------------------------------------------*/

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
	        addl_filters;          
	%let errorCode=;
	%let errorCounter=;
	%let N=;
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
	*%include "/gpfsFS2/sasdata/adhoc/po/imca/digital/code/Access/SAS_Macro_Email.sas"; 

	/* -------------------------------------------------------------------------------------------------*/
	/*  Refresh the access-token, which is valid for 60 minutes.                                        */
	/* -------------------------------------------------------------------------------------------------*/

		%refreshToken;

	/* -------------------------------------------------------------------------------------------------*/
	/*  Audience segments.                                                                              */
	/* -------------------------------------------------------------------------------------------------*/

		%let defaultSegment=		%sysfunc(urlencode(%str(gaid::vG24CfSeQWq_8QOX9uwCqg)));

	/* -------------------------------------------------------------------------------------------------*/
	/*  Libraries.                                                                                      */
	/* -------------------------------------------------------------------------------------------------*/

		%let error_rsn=Error in libraries statements.;

		%let output_file_path = /gpfsFS2/sasdata/nfs/ndc_grid/po_imca_digital/EHaynes/B2B Better Way Monthly Report;
		libname prod "&output_file_path"; run;

		%let archive = /Archive;
		libname archive "&output_file_path&archive"; run;
	

	/* -------------------------------------------------------------------------------------------------*/
	/*  Get last date of last master file.                                                              */
	/* -------------------------------------------------------------------------------------------------*/

		proc sql;
			select distinct 
				max(Date) format mmddyy6.,
				max(Date)+1 format date9.,
				today()-1 format date9.
			into
				:LastDate_Previous, 
				:FirstDate_Current, 
				:LastDate_Current
			from prod.b2b_content_metrics_master;
		quit;

		%if &FirstDate_Current= %then %do;
			%put ERROR: FirstDate_Current not found.;
			endsas;
		%end;

/* -------------------------------------------------------------------------------------------------*/
/*  EXECUTE: GA Data Pull.                                                                          */
/* -------------------------------------------------------------------------------------------------*/

	/* -------------------------------------------------------------------------------------------------*/
	/*  Run PageMetrics report.                                                                         */
	/* -------------------------------------------------------------------------------------------------*/

	/* -------------------------------------------------------------------------------------------------*/
	/*  User input: Dimensions                                                                          */
	/* -------------------------------------------------------------------------------------------------*/

	%let i=1;
	%let var&i=          PagePath;
	%let informat_var&i= $500.;
	%let format_var&i=   $500.;

	%let i=%eval(&i+1);
	%let var&i=          SourceMedium;
	%let informat_var&i= $100.;
	%let format_var&i=   $100.;

	%let i=%eval(&i+1);
	%let var&i=          Campaign;
	%let informat_var&i= $500.;
	%let format_var&i=   $500.;

	%let i=%eval(&i+1);
	%let var&i=          adContent;
	%let informat_var&i= $100.;
	%let format_var&i=   $100.;

	%let i=%eval(&i+1);
	%let var&i=          keyword;
	%let informat_var&i= $200.;
	%let format_var&i=   $200.;

	/* copy/paste the block above to add more dimensions. Change name, format, and informat as necessary */

	%let number_of_dimensions=&i;

	/* -------------------------------------------------------------------------------------------------*/
	/*  User input: Metrics                                                                             */
	/* -------------------------------------------------------------------------------------------------*/

	%let i=%eval(&i+1);
	%let var&i=          uniquePageviews;
	%let informat_var&i= 8.;
	%let format_var&i=   8.;

	%let i=%eval(&i+1);
	%let var&i=          timeOnPage;
	%let informat_var&i= 8.;
	%let format_var&i=   8.;	

	%let i=%eval(&i+1);
	%let var&i=          Bounces;
	%let informat_var&i= 8.;
	%let format_var&i=   8.;

	%let i=%eval(&i+1);
	%let var&i=          Entrances;
	%let informat_var&i= 8.;
	%let format_var&i=   8.;

	%let i=%eval(&i+1);
	%let var&i=          Sessions;
	%let informat_var&i= 8.;
	%let format_var&i=   8.;

	%let i=%eval(&i+1);
	%let var&i=          sessionDuration;
	%let informat_var&i= 8.;
	%let format_var&i=   8.;

	%let i=%eval(&i+1);
	%let var&i=          Users;
	%let informat_var&i= 8.;
	%let format_var&i=   8.;	

	/* copy/paste the block above to add more metrics. Change name, format, and informat as necessary */

	%let number_of_metrics=%eval(&i-&number_of_dimensions);

	/* -------------------------------------------------------------------------------------------------*/
	/*  Execute.                                                                                        */
	/* -------------------------------------------------------------------------------------------------*/

	  %GetGAData(chooseSegment=&defaultSegment
				   ,addl_filters=
				   ,level=day
				   ,StartDate=&FirstDate_Current
				   ,EndDate=&LastDate_Current
				   ,output_file_path=&output_file_path
				   ,output_file_name=B2B_Content_Raw_Metrics
					);

	/* -------------------------------------------------------------------------------------------------*/
	/*  Run PageActions report.                                                                         */
	/* -------------------------------------------------------------------------------------------------*/

	/* -------------------------------------------------------------------------------------------------*/
	/*  User input: Dimensions                                                                          */
	/* -------------------------------------------------------------------------------------------------*/

	%let i=1;
	%let var&i=          PagePath;
	%let informat_var&i= $500.;
	%let format_var&i=   $500.;

	%let i=%eval(&i+1);
	%let var&i=          SourceMedium;
	%let informat_var&i= $100.;
	%let format_var&i=   $100.;

	%let i=%eval(&i+1);
	%let var&i=          Campaign;
	%let informat_var&i= $500.;
	%let format_var&i=   $500.;

	%let i=%eval(&i+1);
	%let var&i=          adContent;
	%let informat_var&i= $100.;
	%let format_var&i=   $100.;

	%let i=%eval(&i+1);
	%let var&i=          keyword;
	%let informat_var&i= $200.;
	%let format_var&i=   $200.;

	%let i=%eval(&i+1);
	%let var&i=          eventAction;
	%let informat_var&i= $50.;
	%let format_var&i=   $50.;

	%let i=%eval(&i+1);
	%let var&i=          eventLabel;
	%let informat_var&i= $200.;
	%let format_var&i=   $200.;

	/* copy/paste the block above to add more dimensions. Change name, format, and informat as necessary */

	%let number_of_dimensions=&i;

	/* -------------------------------------------------------------------------------------------------*/
	/*  User input: Metrics                                                                             */
	/* -------------------------------------------------------------------------------------------------*/

	%let i=%eval(&i+1);
	%let var&i=          uniqueEvents;
	%let informat_var&i= 8.;
	%let format_var&i=   8.;	

	/* copy/paste the block above to add more metrics. Change name, format, and informat as necessary */

	%let number_of_metrics=%eval(&i-&number_of_dimensions);

	/* -------------------------------------------------------------------------------------------------*/
	/*  Execute.                                                                                        */
	/* -------------------------------------------------------------------------------------------------*/

	/* -------------------------------------------------------------------------------------------------*/
	/*  User Input: Filters                                                                             */
	/* -------------------------------------------------------------------------------------------------*/

	  /*%let addl_filters=%sysfunc(urlencode(...your additional filters here...));
	  		if you need multiple AND or OR filters, each should be in a separate &filter1, &filter2, etc
			for AND criteria use %nrstr(;). for OR criteria use comma. OR filters will be resolved before AND filters.
			veriables follow the format ga:[variablename]. equals ==, regex =~, contains =@. for NOT, use !=, !~, !@.
	  		ex: for filter1 AND (filter2 OR filter3) addl_filters = &filter1%nrstr(;)&filter2,&filter3 */ 

		* Filter by eventCategory;
		%let filter1=%sysfunc(urlencode(ga:eventCategory==Shop)); 
		%let filter2=%sysfunc(urlencode(ga:eventCategory==Learn)); 
		%let filter3=%sysfunc(urlencode(ga:eventCategory==Convert)); 
		%let filter4=%sysfunc(urlencode(ga:eventCategory==Share)); 
		%let filter5=%sysfunc(urlencode(ga:eventCategory==Form Abandonment)); 
		%let filter6=%sysfunc(urlencode(ga:eventCategory==web_lead)); 

	%macro exec(exec_filter,
				exec_output_file_name,
				exec_eventCategory);

				%GetGAData(chooseSegment=&defaultSegment,
						chooseView=Default,
						addl_filters=&&exec_filter,
						level=day,
						StartDate=&FirstDate_Current,
						EndDate=&LastDate_Current,
						output_file_path=&output_file_path,
						output_file_name=&&exec_output_file_name);
				%if(%sysfunc(exist(ga.&&exec_output_file_name.))) %then %do;
					data ga.&&exec_output_file_name.; 
						set ga.&&exec_output_file_name.; 
						eventCategory = "&exec_eventCategory.";
					run;
				%end;
				%else %do;
					data ga.&&exec_output_file_name.; 
						eventCategory = "&exec_eventCategory.";
					run;
				%end;

	%mend;

	%exec(%bquote(&filter1),B2B_Content_Raw_Actions_1,Shop);
	%exec(%bquote(&filter2),B2B_Content_Raw_Actions_2,Learn);
	%exec(%bquote(&filter3),B2B_Content_Raw_Actions_3,Convert);
	%exec(%bquote(&filter4),B2B_Content_Raw_Actions_4,Share);
	%exec(%bquote(&filter5),B2B_Content_Raw_Actions_5,Form Abandonment);
	%exec(%bquote(&filter6),B2B_Content_Raw_Actions_6,web_lead);

	data prod.B2B_Content_Raw_Actions;
		format eventCategory $25.;
		set prod.B2B_Content_Raw_Actions_:;
	run;

	proc delete data=prod.B2B_Content_Raw_Actions_1; run;
	proc delete data=prod.B2B_Content_Raw_Actions_2; run;
	proc delete data=prod.B2B_Content_Raw_Actions_3; run;
	proc delete data=prod.B2B_Content_Raw_Actions_4; run;
	proc delete data=prod.B2B_Content_Raw_Actions_5; run;
	proc delete data=prod.B2B_Content_Raw_Actions_6; run;
	
/* -------------------------------------------------------------------------------------------------*/
/*  Clean and transform raw data.                                                                   */
/* -------------------------------------------------------------------------------------------------*/

	data prod.B2B_Content_Raw_Metrics_new; 
		format WeekStart mmddyy8.  Date mmddyy8.     
			   Channel $20.        Campaign $200.   Source $50.   Medium $50.
			   Referral_Other $50. Page $200.       SiteSection $50.
			   uniquePageviews 8.  timeOnPage 8.    Bounces 8.    Entrances 8.   
			   Sessions 8.         sessionDuration 8. Users 8.;
		set prod.B2B_Content_Raw_Metrics;

		/* -------------------------------------------------------------------------------------------------*/
		/*  Clean Source / Medium.                                                                          */
		/* -------------------------------------------------------------------------------------------------*/

		Source = strip(scan(sourceMedium,1,'/'));
		Medium = strip(scan(sourceMedium,2,'/'));
		drop sourceMedium;

		/* -------------------------------------------------------------------------------------------------*/
		/*  Remove testing sources.                                                                         */
		/* -------------------------------------------------------------------------------------------------*/

			if Source in ('wrike.com', 
		 				   'wiki.kp.org',
						   'sp-cloud.kp.org',
						   'kp.my.salesforce.com',
						   'basecamp.com',
						   'app.crazyegg.com',
						   'account-preview.kp.org',
						   'app.marinsoftware.com',
						   'author-sanbox-afd.kp.org',
						   'bconnected.connextion.co',
						   'comms01.kp.org',
						   'googleweblight.com',
						   'kpnationalconsumersales--kpdev1--c.documentforce.c',
						   'dnserrorassist.att.net',
						   'loweproferotech.atlassian',
						   'previewcampaign.infousa.c',
						   'adspreview.simpli.fi',
						   'word-edit.officeapps.live') 
			or find(Source,'kpwanl') > 0 
			or find(Source,'preview.dpaprod') > 0
			or find(Source,'optimizely') > 0
			or find(Source,'kp-aws-cloud.org') > 0
			or find(Source,'sp.kp.org') > 0
			or find(Source,'admintool.kp.org') > 0
			or find(Source,'localhost') > 0 
			or find(Source,'pathroutes') > 0
			or find(Source,'addotnet') > 0
			or find(Source,'searchiq') > 0
			or find(PagePath,'googleweblight') > 0
			or find(PagePath,'snap-test-qa') > 0
			or find(PagePath,'aws-cloud') > 0
			or prxmatch("/\d\d\d\.\d\.\d\.\d:\d{4}/",Source) > 0 
			or find(Source,'c5c-') > 0
			or Source = 'tagassistant.google.com'
			or Source = 'test-source'
			or Source = 'test_source'
			or Medium = 'test'
			then delete;
		if find(PagePath,'?gtm_debug=x','i') > 0 then delete;
		if find(PagePath,'kaiserfh1-cos-mp','i')>0 then delete;
				
		/* -------------------------------------------------------------------------------------------------*/
		/*  Add WeekStart (Sun-Sat).                                                                        */
		/* -------------------------------------------------------------------------------------------------*/

		WeekStart=intnx('week',Date,0,'b');

		/* -------------------------------------------------------------------------------------------------*/
		/*  Trim off query strings and domain from PagePath.                                                */
		/* -------------------------------------------------------------------------------------------------*/

			Page = lowcase(compress(tranwrd(PagePath,'business.kaiserpermanente.org/',''),''));

			if find(Page,'?') > 0
				then Page = substr(Page,1,index(Page,'?')-1);

			if find(Page,'WT.mc_id') > 0 
				then Page = substr(Page,1,index(Page,'WT.mc_id')-1);

			if find(Page,'#') > 0 
				then Page = substr(Page,1,index(Page,'#')-1);

			if substr(reverse(strip(Page)),1,1) = '/' then 
				Page = substr(strip(Page),1,length(strip(Page))-1);
		
			SiteSection = scan(Page,1,'/');

			if Page = '' or find(Page,'?') > 0 or SiteSection = 'page' then 
				Page = 'homepage';

			SiteSection = scan(Page,1,'/');

			/* Manual cleaning */
			if Page in ('assets/documents/1_2014JanBronzeMetalTier.pdf',
						'contactcalifornia','contactus','headoffice',
						'heagolth-plan/small-business-plans/california',
						'health/plans/co/plans/smallbusiness',
						'controlling-drug-costs','enrollmentsupport',
						'health-plan/occupational-healthkaiser',
						'health-plan/small-business-plans/b3JlZ29uLX',
						'health-plan/occupational-healthkaiseroccupational.health',
						'health-plan/occupational-healthlocations',
						'health-plan/small-business-plans/hawaii{ignore}',
						'health-plan/small-business-plans/small-busineamass-offerings',
						'health-plan/small-business-plans/georgia{ignore}',
						'health-plan/small-business-plans/california/renewal',
						'health-plans','health-plan{ignore}','healthplans',
						'how-integrated-health-care-helps-keep-your-employees-healthier',
						'insights/mental-health-workplace/covid-19-stress-anxiety-isolation__',
						'insights/covid-19https:/fam.kp.org/idp/startSSO.ping',
						'insights/mental-health-workplace/mental-health-apps-workforce-wellness.com',
						'insightsutm_source=b2b-co-employer&utm_medium=email&utm_campaign=cmamentalhealth&utm_term=656150978',
						'kp-difference/coronavirus-support-for-employers/bWVudGFsLW',
						'kp-difference/cost-managementadministrativeandfunctionalstructureofentitiesthatdeliverhealthcareforboththeinpatientandtheoutpatientsystems',
						'kp-difference/coronavirus-support-for-employers/covid-19-vaccine-employer-info5d',
						'kp-difference/coronavirus-support-for-employers/covid-19-vaccineemployer-info',
						'kp-difference/coronavirus-support-for-employersmyhrkaiser',
						'kp-difference/coronavirus-support-for-employers/covid-19-vaccine-employer-info]',
						'manage-accountwww.CignaClientResources.com',
						'payonline','register','resources',
						'self-service-quoting-tool-link-test',
						'self-service-quoting-tool-link-test-qa2',
						'site,ap','sitemap','small-business',
						'thrive/leadership-training-mental-health-awarenesshttps:/login.microsoftonline.com/common/oauth2/authorize',
						'translate.googleusercontent.com/translate_c',
						'wp-content/uploads','xmlrpc.php',
						'thrive/leadership-training-mental-health-awareness-contactus',
						'thrive/leadership-training-mental-health-awareness-contact',
						'thrive/leadership-training-mental-health-awareness-contac-tus'
						'thrive/resourcecovid19','thrive/resourcecovid-19','virtualcomplete',
						'wp-content/uploads/2016/10/www.kp.org/nourish',
						'wp-content/uploads/2020/10/edd.ca.gov/about_edd/coronavirus-2019.htm',
						'wp-content/uploads/2021/04/group-12@2x.jpeg',
						'wp-content/uploads/2',
						'wp-content/uploads/2020/09'
						'wp-content/uploads/2015/08/kaiser-permanente-build-your-meal.pdf"target=_blank'
						) then delete;
			if SiteSection in ('mental-health-wellness-video','menshealth',
							   'large-business-plans','northern-california',
							   'small-business',
								'thirve') 
						then delete;
			if Page = 'mange-account' then
				Page = 'manage-account';
			if Page = 'kp-difference/y29yb25hdm' then 
				Page = 'kp-difference';
			if Page = 'wp-content/uploads/2020/04/Kaiser-Permanente-COVID-19-Work-Home-Wellness-Employees-Flyer.pdf&hl=en_US' then
				Page = 'wp-content/uploads/2020/04/Kaiser-Permanente-COVID-19-Work-Home-Wellness-Employees-Flyer.pdf';
			if Page = 'thrive/flu-prevention-covid-19>' then
				Page = 'thrive/flu-prevention-covid-19';
			if Page = 'thrive/resource-center/covid-19-return-to-work-playbook>' then
				Page = 'thrive/resource-center/covid-19-return-to-work-playbook';
			if Page in ('thrive/bgvhzgvyc2','thrive/agvhbhroeS','thrive/c2xlzxatbw',
						'thrive/c3ryzxnzlw') then
				Page = 'thrive';
			if Page = 'health-plan/small-business-plans/b3jlz29ulx' then
				Page = 'health-plan/small-business-plans';
			if Page = 'kp-difference/locate-services/bwfyewxhbm' then 
				Page = 'kp-difference/locate-services';
			if Page in ('thrive/resource-center/y292awqtmt','thrive/resource-center/chn5Y2hvbG',
						'thrive/resource-center/cmvzdc1hbm','thrive/resource-center/zmluzgluzy') then 
				Page = 'thrive/resource-center';
			if Page = 'kp-difference/coronavirus-support-for-employers/bwvudgfslw' then 
				Page = 'kp-difference/coronavirus-support-for-employers';
			if Page = 'telehealth-supports-employees-health-and-benefits-' then
				Page = 'telehealth-supports-employees-health-and-benefits-business';
			if Page in ('kp.kaiserpermanente.org/small-business/ca-nbrd',
						'kp.kaiserpermanente.org/small-business/ca-brd')
					then do;
						Page = 'Small Business CA Paid Search LP';
						SiteSection = 'Landing Pages';
					end;
			if Page in ('kp.kaiserpermanente.org/small-business/nl-nbrd',
						'kp.kaiserpermanente.org/small-business/nl-brd')
					then do;
						Page = 'Small Business National Paid Search LP';
						SiteSection = 'Landing Pages';
					end;
			if Page = 'kp.kaiserpermanente.org/small-business/ca-da-healthplans'
					then do;
						Page = 'Small Business CA Data Axel LP';
						SiteSection = 'Landing Pages';
					end;
			if Page = 'respond.kaiserpermanente.org/coloradosmallbiz'
					then do;
						Page = 'Small Business CO Paid Search LP';
						SiteSection = 'Landing Pages';
					end;
			if Page = 'respond.kaiserpermanente.org/nwsmallbusiness'
					then do;
						Page = 'Small Business NW Paid Search LP';
						SiteSection = 'Landing Pages';
					end;

			/* New */
			if find(Page,'success.kaiserpermanente.org')>0 
					then SiteSection = 'Landing Pages';
			if find(Page,'success.kaiserpermanente.org/exec','i') > 0
					then Page = 'B2B Landing Pages for Executives - RTW';
			if find(Page,'success.kaiserpermanente.org/hbo','i') > 0
					then Page = 'B2B Landing Pages for HR & Benefits - RTW';
			if find(Page,'success.kaiserpermanente.org/mhw-exec','i') > 0
					then Page = 'B2B Landing Pages for Executives - MHW';
			if find(Page,'success.kaiserpermanente.org/mhw-hbo','i') > 0
					then Page = 'B2B Landing Pages for HR & Benefits - MHW';
			if find(Page,'success.kaiserpermanente.org/vc-exec','i') > 0
					then Page = 'B2B Landing Pages for Executives - VC';
			if find(Page,'success.kaiserpermanente.org/vc-hbo','i') > 0
					then Page = 'B2B Landing Pages for HR & Benefits - VC';

			if find(Page,'virtualproducts.kaiserpermanente.org','i')>0 
					then SiteSection = 'Landing Pages';

			if Page in ('oregon-southwest-washington-cardiac-care',
						'planning-for-next-normal-at-work',
						'small-business-health-coverage-download',
						'telehealth-supports-employees-health-and-benefits-business'
						'washington-care-access','washington-mental-health-wellness')
					then SiteSection = 'Landing Pages';
			if Page = 'respond.kaiserpermanente.org/emp_acq_sbu_nurture_co_ebookdownload'
				then Page = 'E-Book Download';
			if Page = 'respond.kaiserpermanente.org/emp_acq_sbu_nurture_co_ebookdownload_ty'
				then Page = 'E-Book Download Thank You';
			if find(Page,'thrive/resource-center') > 0 or SiteSection = 'wp-content' then 
				SiteSection = 'Thrive At Work: Resource Center';
			if SiteSection = 'thrive' 
				then SiteSection = 'Thrive At Work';
			if SiteSection = 'health-plan' 
				then SiteSection = 'Health Plans';
			if SiteSection = 'kp-difference'
				then SiteSection = 'The KP Difference';
			if SiteSection = 'insights' 
				then SiteSection = 'Insights';
			if SiteSection in ('contact','faqs','homepage',
								'manage-account','saved-items',
								'site-map')
				then SiteSection = 'Other';
							
		*drop pagePath;

		/* -------------------------------------------------------------------------------------------------*/
		/*  Create a clean Channel variable.                                                                */
		/* -------------------------------------------------------------------------------------------------*/

		if Medium = '(none)' then Channel = 'Direct'; 
				/* Organic Search */
				else if lowcase(Medium) = 'organic' then Channel = 'Organic Search';
				else if lowcase(Medium) = 'referral' 
					and Source in ('duckduckgo.com','us.search.yahoo.com',
									'r.search.aol.com','us.search.yahoo.com',
									'search.aol.com','search.google.com')
					then Channel = 'Organic Search';
				/* Paid Search */
				else if lowcase(Medium) = 'cpc' then do;
	/*				if find(campaign,'KP_B2B_LG') > 0 then Channel = 'Paid Search-LG';*/
	/*				else if find(campaign,'KP_B2B_SB') > 0 then Channel = 'Paid Search-SB';*/
	/*				else if find(campaign,'KP_EL_NON') > 0 then Channel = 'Paid Search-EL';*/
					Channel = 'Paid Search';
				end;
				/* Other Paid Search */
				else if lowcase(source) = 'sem'
						or lowcase(source) = 'ttd'
						then Channel = 'Paid Search';
				else if find(PagePath,'utm_medium=cpc','i') > 0 
					then Channel = 'Paid Search';
				/* (OLD) Display - Regional */
				else if (lowcase(Medium) = 'display' and find(campaign,'Phase_3') > 0)
							or (lowcase(Medium) = '(not set)' and find(campaign,'Phase_3') > 0 and adContent='NW')
							or (lowcase(Medium) = 'banner' and Source = 'localiq')
					then Channel = 'Display NW';
				else if lowcase(Medium) = 'display' and find(campaign,'kp-b2b-choosebetter') > 0
					then Channel = 'Display MAS';
				/* (CURRENT) Display - Regional */
				else if lowcase(Medium) = 'display' and find(Source,'-nw-') > 0 and
					(find(Campaign,'pbj') > 0 or
					 find(Campaign,'LaneCounty') > 0)
					 then Channel = 'Display NW';
				else if lowcase(Medium) in ('eblast','interscroller')
					and find(Source,'-nw-')>0
					then Channel = 'Other NW';
				else if lowcase(Medium) = 'display' and find(Source,'-hi-') > 0 
					and find(Campaign,'pbn') > 0
					then Channel = 'Display HI';
				else if lowcase(Medium) in ('native') or find(Medium,'text ad','i')>0
					and find(Source,'-hi-')>0
					then Channel = 'Other HI';
				else if lowcase(Medium) = 'display' and find(Source,'-co-') > 0
					and Campaign = '[CMA]' then Channel = 'Display CO';

					/* Display - SB */
					else if lowcase(Medium) = 'display' and find(lowcase(Source),'sb-')>0
						then Channel = 'Display SB';
	
					/* Display - B2B */
					else if lowcase(Medium) = 'display' and find(lowcase(Source),'lg-')>0 /* 2021 */ 
							or (lowcase(Source) = 'display' and lowcase(Medium) in ('ncal','scal','nw','was')) /* 2020 */
							or find(lowcase(Campaign),'_vd_nat_','i') > 0 /* Value Demonstration */
						then Channel = 'Display B2B';

				/* Email */
				else if find(Medium,'email','i') > 0 
					then Channel = 'Email';
				/* Direct Mail */
				else if find(Medium,'direct mail','i') > 0
					 or find(Medium,'direct-mail','i') > 0
					then Channel = 'Direct Mail';
				/* LinkedIn */
				else if lowcase(Medium) = 'linkedin' then do;
					/* LinkedIn - SBU */
					if (lowcase(Source) = 'sbu' or find(lowcase(source),'sb-')>0) 
						then Channel = 'Social-LinkedIn SB';
					/* (OLD) LinkedIn - B2B */
					else if lowcase(Campaign) = 'b2b' then Channel = 'Social-LinkedIn LG';
					/* LinkedIn - B2B */
					else if medium = 'linkedin' and find(Source,'lg-') > 0
						then Channel = 'Social-LinkedIn LG';
					/* LinkedIn - NW */
					else if find(Source,'social','i') > 0 and find(Campaign,'NW ','i') > 0
						then Channel = 'Social-LinkedIn NW';
					else if find(Source,'InMail','i') > 0 and Campaign = 'KPNW' 
						then Channel = 'Social-LinkedIn NW';
					/* PR-Comms */
					else if source = 'pr-comms' 
						then Channel='Social-LinkedIn PR'; 
					/* Organic Posts */
					else if lowcase(Campaign) = 'virtual_care_msk'
						then Channel = 'Social-Organic Posts';
					else if find(lowcase(keyword),'organic')>0 
						then Channel = 'Social-Organic Posts';
				end;
				/* Misc - old LinkedIn variants */
				else if find(Source,'linkedin','i') > 0 or Medium = 'sam-social-post' or find(lowcase(keyword),'organic')>0 then do;
					if prxmatch("/(\w+|\d+)-\d{4}/",Campaign) > 0 then Channel = 'Social-LinkedIn LG';
					else if Medium = 'sponsored-content' and Campaign not in ('b2b-reduce-stress','b2b-value-dem')
						then Channel = 'Social-LinkedIn NW';
					else if Campaign in ('b2b-reduce-stress','b2b-value-dem')
						then Channel = 'Social-LinkedIn LG';
/*					else if Medium = 'linkedin'*/
/*						then Channel = 'Social-LinkedIn LG';*/
					else if find(Campaign,'va medical plans 2020 broker','i')>0
						then Channel = 'Social-LinkedIn MAS';	
					/* Organic Posts */
					else if find(lowcase(keyword),'organic')>0 
						then Channel = 'Social-Organic Posts';
					else if lowcase(Campaign) = 'virtual_care_msk'
						then Channel = 'Social-Organic Posts';
					else if Medium = 'sam-social-post'
						then Channel = 'Social-Organic Posts';
					else Channel = 'Social-Other';
				end;
				/* Facebook/Twitter */
				else if lowcase(medium) = 'facebook' and lowcase(source)='sb-ca-prospect'
					then Channel = 'Social-Facebook SB';
				else if lowcase(medium) = 'twitter'
					then Channel = 'Social-Twitter LG';
				/* Social - Other */
				else if find(Source,'facebook','i') > 0
						or find(Source,'social','i') > 0 
						or Source in ('twitter_ads','t.co','web.wechat.com','ws.sharethis.com','youtube.com','insatgram')
					then Channel = 'Social-Other'; /* Facebook, Twitter, Youtube, Other */
				/* Referral & Other */
				else Channel = 'Referral & Other';

		/* -------------------------------------------------------------------------------------------------*/
		/*  Clean the campaign variable. Create a Referral_Other variable.                                  */
		/* -------------------------------------------------------------------------------------------------*/

		if source in ('internal','internal-kp') or source = 'intranet' then do;
			if find(campaign,'comm-flash') > 0 then Campaign = 'comm-flash';
			Channel = 'Internal KP';
		end;
		if Channel in ('Direct Mail','Email') then do;
			if Source='broker-briefing' then campaign='broker-briefing';
				else if Source='localiq' then campaign=campaign;
				else if find(campaign,'broke') > 0 then campaign = 'broker';
				else if find(campaign,'employe') > 0 then campaign = 'employer';
		end;
		if Channel in ('Direct Mail','Email') and Source in ('SBU','sb-ca','sb-ca-prospect') and find(campaign,'direct')=0 then campaign = 'SBU';

		if Channel = 'Referral & Other' then do;
			if Source = 'account.kp.org' then Referral_Other = 'Account.kp.org';
			else if medium = 'account.kp.org' then Referral_Other = catx(" / ","Account.kp.org",campaign);
			else if medium in ('toolkit','playbook','infographic','guide') then Referral_Other = catx(" / ","Playbooks and Toolkits",campaign);
			else if Medium = 'referral' then Referral_Other = catx(" / ","Referral",Source);
			else Referral_Other = catx(" / ",Source,Medium);
			end;
		else Referral_Other = '';

		adContent = upcase(adContent);

	run;

	*Troubleshooting;

	* Check if pagePath is correctly mapped to Page;
		proc sql;
		create table Pvs_per_page as
			select distinct
				SiteSection
			,	Page
			,	sum(uniquePageviews) as Pageviews
			from prod.B2B_Content_Raw_Metrics_new
			group by 
				SiteSection
			,	Page
			order by 
				SiteSection
			,	Pageviews desc;
		quit;
	* Check if channelGrouping and source are correctly mapped to Channel;
		proc sql;
		create table look as
			select distinct
				sum(uniquePageviews) as pageviews
			,	Channel
			,	Referral_Other
			,	Source
			,	Medium
			,	Campaign
			,	adContent
			,	keyword
			from prod.B2B_Content_Raw_Metrics_new
			group by 
				Channel
			,	Referral_Other
			,	Source
			,	Medium
			,	Campaign
			,	adContent
			,	keyword
			order by 
				Channel
			,	Referral_Other
			,	Source;
		quit;

		proc sort data=prod.B2B_Content_Raw_Metrics_new; by Page; run;
		proc sort data=pvs_per_page; by page; run;
	
		data drop prod.B2B_Content_Raw_Metrics_new(drop=Flag_Drop); *prod.B2B_Content_Raw_Metrics_new;
			drop pagePath; 
			merge prod.B2B_Content_Raw_Metrics_new(in=a)
				  pvs_per_page(in=b);
			by Page;
			Flag_Drop = 0;
			if find(Page,'success.kaiserpermanente.org')>0 
				or (SiteSection not in ('respond.kaiserpermanente.org',
									'kpbiz.org',
									'Thrive At Work: Resource Center',
									'Thrive At Work',
									'The KP Difference',
									'Other',
									'Landing Pages',
									'Insights',
									'Health Plans') 
						and Page not in ('manage-account','your-health-care-abcs')
						and find(Page,'resource-center')=0)
				then Flag_Drop = 1;
			if a and Pageviews > 1 and Flag_Drop = 0 then output prod.B2B_Content_Raw_Metrics_new;
			else output drop;
		run;

		proc sql;
		create table Pvs_per_page_keep as
			select distinct
				SiteSection
			,	Page
			,	sum(uniquePageviews) as Pageviews
			from prod.B2B_Content_Raw_Metrics_new
			group by 
				SiteSection
			,	Page
			order by 
				SiteSection
			,	Pageviews desc;

		create table Pvs_per_page_drop as
			select distinct
				SiteSection
			,	Page
			,	sum(uniquePageviews) as Pageviews
			from drop
			group by 
				SiteSection
			,	Page
			order by 
				SiteSection
			,	Pageviews desc;
		quit;

	/* -------------------------------------------------------------------------------------------------*/
	/*  Merge new with historical data.                                                                 */
	/* -------------------------------------------------------------------------------------------------*/

	/* master */
	data prod.B2B_Content_Metrics_Master;
		retain Date WeekStart Channel Page PageType SiteSection
				uniquePageviews timeOnPage Bounces Entrances Sessions sessionDuration Users
				referral_other source medium campaign adContent keyword;
		set prod.B2B_Content_Raw_Metrics_new
		    prod.B2B_Content_Metrics_Master;
	run;

	proc delete data=prod.B2B_Content_Raw_Metrics_new;

	/* -------------------------------------------------------------------------------------------------*/
	/*  Get first date/last date of the current raw data.                                               */
	/* -------------------------------------------------------------------------------------------------*/

	proc sql noprint;
	select distinct 
		min(Date) format mmddyy6.,
		max(Date) format mmddyy6.
		into
		:FirstData,
		:LastData
		from prod.B2B_Content_Metrics_Master;
	quit;

	/* -------------------------------------------------------------------------------------------------*/
	/*  Save master file(s) --> zip archive.                                                            */
	/* -------------------------------------------------------------------------------------------------*/

	/* master */
	data archive.b2b_content_m_&FirstData._&LastData;
		set prod.B2B_Content_Metrics_Master;
	run;

	ods package(archived) open nopf;
	ods package(archived) add file="&output_file_path&archive/b2b_content_m_&FirstData._&LastData..sas7bdat";
	ods package(archived) publish archive properties (
		archive_name="b2b_content_m_&FirstData._&LastData..zip"
		archive_path="&output_file_path&archive/");
	ods package(archived) close;

	proc delete data=archive.b2b_content_m_&FirstData._&LastData; run;

	filename old_arch "&output_file_path&archive/b2b_content_m_&FirstData._&LastDate_Previous..zip";
	data _null_;
		rc=fdelete("old_arch");
		put rc=;
	run;

	proc delete data=prod.b2b_content_raw_metrics; run;

	/* ACTIONS */

	data prod.B2B_Content_Raw_Actions_new; 
		format WeekStart mmddyy8.  Date mmddyy8.     
			   Channel $20.        Campaign $200.   Source $50.   Medium $50.
			   Referral_Other $50. Page $200.       SiteSection $50.
			   eventCategory $25.  eventAction $50. eventLabel $200. 
			   uniqueEvents 8.  ;
		set prod.B2B_Content_Raw_Actions;

		/* -------------------------------------------------------------------------------------------------*/
		/*  Clean Source / Medium.                                                                          */
		/* -------------------------------------------------------------------------------------------------*/

		Source = strip(scan(sourceMedium,1,'/'));
		Medium = strip(scan(sourceMedium,2,'/'));
		drop sourceMedium;

		/* -------------------------------------------------------------------------------------------------*/
		/*  Remove testing sources.                                                                         */
		/* -------------------------------------------------------------------------------------------------*/

			if Source in ('wrike.com', 
		 				   'wiki.kp.org',
						   'sp-cloud.kp.org',
						   'kp.my.salesforce.com',
						   'basecamp.com',
						   'app.crazyegg.com',
						   'account-preview.kp.org',
						   'app.marinsoftware.com',
						   'author-sanbox-afd.kp.org',
						   'bconnected.connextion.co',
						   'comms01.kp.org',
						   'googleweblight.com',
						   'kpnationalconsumersales--kpdev1--c.documentforce.c',
						   'dnserrorassist.att.net',
						   'loweproferotech.atlassian',
						   'previewcampaign.infousa.c',
						   'adspreview.simpli.fi',
						   'word-edit.officeapps.live') 
			or find(Source,'kpwanl') > 0 
			or find(Source,'preview.dpaprod') > 0
			or find(Source,'optimizely') > 0
			or find(Source,'kp-aws-cloud.org') > 0
			or find(Source,'sp.kp.org') > 0
			or find(Source,'admintool.kp.org') > 0
			or find(Source,'localhost') > 0 
			or find(Source,'pathroutes') > 0
			or find(Source,'addotnet') > 0
			or find(Source,'searchiq') > 0
			or find(PagePath,'googleweblight') > 0
			or find(PagePath,'snap-test-qa') > 0
			or find(PagePath,'aws-cloud') > 0
			or prxmatch("/\d\d\d\.\d\.\d\.\d:\d{4}/",Source) > 0 
			or find(Source,'c5c-') > 0
			or Source = 'tagassistant.google.com'
			or Source = 'test-source'
			or Source = 'test_source'
			or Medium = 'test'
			then delete;
		if find(PagePath,'?gtm_debug=x') > 0 then delete;
		if find(PagePath,'kaiserfh1-cos-mp','i')>0 then delete;
	
		/* -------------------------------------------------------------------------------------------------*/
		/*  Add WeekStart (Sun-Sat).                                                                        */
		/* -------------------------------------------------------------------------------------------------*/

		WeekStart=intnx('week',Date,0,'b');

		/* -------------------------------------------------------------------------------------------------*/
		/*  Trim off query strings and domain from PagePath.                                                */
		/* -------------------------------------------------------------------------------------------------*/

		Page = lowcase(compress(tranwrd(PagePath,'business.kaiserpermanente.org/',''),''));

			if find(Page,'?') > 0 
				then Page = substr(Page,1,index(Page,'?')-1);

			if find(Page,'WT.mc_id') > 0 
				then Page = substr(Page,1,index(Page,'WT.mc_id')-1);

			if find(Page,'#') > 0 
				then Page = substr(Page,1,index(Page,'#')-1);

			if substr(reverse(strip(Page)),1,1) = '/' then 
				Page = substr(strip(Page),1,length(strip(Page))-1);
		
			SiteSection = scan(Page,1,'/');

			if Page = '' or find(Page,'?') > 0 or SiteSection = 'page' then 
				Page = 'homepage';

			SiteSection = scan(Page,1,'/');

			/* Manual cleaning */
			if Page in ('assets/documents/1_2014JanBronzeMetalTier.pdf',
						'contactcalifornia','contactus','headoffice',
						'heagolth-plan/small-business-plans/california',
						'health/plans/co/plans/smallbusiness',
						'controlling-drug-costs','enrollmentsupport',
						'health-plan/occupational-healthkaiser',
						'health-plan/small-business-plans/b3JlZ29uLX',
						'health-plan/occupational-healthkaiseroccupational.health',
						'health-plan/occupational-healthlocations',
						'health-plan/small-business-plans/hawaii{ignore}',
						'health-plan/small-business-plans/small-busineamass-offerings',
						'health-plan/small-business-plans/georgia{ignore}',
						'health-plan/small-business-plans/california/renewal',
						'health-plans','health-plan{ignore}','healthplans',
						'how-integrated-health-care-helps-keep-your-employees-healthier',
						'insights/mental-health-workplace/covid-19-stress-anxiety-isolation__',
						'insights/covid-19https:/fam.kp.org/idp/startSSO.ping',
						'insights/mental-health-workplace/mental-health-apps-workforce-wellness.com',
						'insightsutm_source=b2b-co-employer&utm_medium=email&utm_campaign=cmamentalhealth&utm_term=656150978',
						'kp-difference/coronavirus-support-for-employers/bWVudGFsLW',
						'kp-difference/cost-managementadministrativeandfunctionalstructureofentitiesthatdeliverhealthcareforboththeinpatientandtheoutpatientsystems',
						'kp-difference/coronavirus-support-for-employers/covid-19-vaccine-employer-info5d',
						'kp-difference/coronavirus-support-for-employers/covid-19-vaccineemployer-info',
						'kp-difference/coronavirus-support-for-employersmyhrkaiser',
						'kp-difference/coronavirus-support-for-employers/covid-19-vaccine-employer-info]',
						'manage-accountwww.CignaClientResources.com',
						'payonline','register','resources',
						'self-service-quoting-tool-link-test',
						'self-service-quoting-tool-link-test-qa2',
						'site,ap','sitemap','small-business',
						'thrive/leadership-training-mental-health-awarenesshttps:/login.microsoftonline.com/common/oauth2/authorize',
						'translate.googleusercontent.com/translate_c',
						'wp-content/uploads','xmlrpc.php',
						'thrive/leadership-training-mental-health-awareness-contactus',
						'thrive/leadership-training-mental-health-awareness-contact',
						'thrive/leadership-training-mental-health-awareness-contac-tus'
						'thrive/resourcecovid19','thrive/resourcecovid-19','virtualcomplete',
						'wp-content/uploads/2016/10/www.kp.org/nourish',
						'wp-content/uploads/2020/10/edd.ca.gov/about_edd/coronavirus-2019.htm',
						'wp-content/uploads/2021/04/group-12@2x.jpeg',
						'wp-content/uploads/2',
						'wp-content/uploads/2020/09'
						'wp-content/uploads/2015/08/kaiser-permanente-build-your-meal.pdf"target=_blank'
						) then delete;
			if SiteSection in ('mental-health-wellness-video','menshealth',
							   'large-business-plans','northern-california',
							   'small-business',
								'thirve') 
						then delete;
			if Page = 'mange-account' then
				Page = 'manage-account';
			if Page = 'kp-difference/y29yb25hdm' then 
				Page = 'kp-difference';
			if Page = 'wp-content/uploads/2020/04/Kaiser-Permanente-COVID-19-Work-Home-Wellness-Employees-Flyer.pdf&hl=en_US' then
				Page = 'wp-content/uploads/2020/04/Kaiser-Permanente-COVID-19-Work-Home-Wellness-Employees-Flyer.pdf';
			if Page = 'thrive/flu-prevention-covid-19>' then
				Page = 'thrive/flu-prevention-covid-19';
			if Page = 'thrive/resource-center/covid-19-return-to-work-playbook>' then
				Page = 'thrive/resource-center/covid-19-return-to-work-playbook';
			if Page in ('thrive/bgvhzgvyc2','thrive/agvhbhroeS','thrive/c2xlzxatbw',
						'thrive/c3ryzxnzlw') then
				Page = 'thrive';
			if Page = 'health-plan/small-business-plans/b3jlz29ulx' then
				Page = 'health-plan/small-business-plans';
			if Page = 'kp-difference/locate-services/bwfyewxhbm' then 
				Page = 'kp-difference/locate-services';
			if Page in ('thrive/resource-center/y292awqtmt','thrive/resource-center/chn5Y2hvbG',
						'thrive/resource-center/cmvzdc1hbm','thrive/resource-center/zmluzgluzy') then 
				Page = 'thrive/resource-center';
			if Page = 'kp-difference/coronavirus-support-for-employers/bwvudgfslw' then 
				Page = 'kp-difference/coronavirus-support-for-employers';
			if Page = 'telehealth-supports-employees-health-and-benefits-' then
				Page = 'telehealth-supports-employees-health-and-benefits-business';
			if Page in ('kp.kaiserpermanente.org/small-business/ca-nbrd',
						'kp.kaiserpermanente.org/small-business/ca-brd')
					then do;
						Page = 'Small Business CA Paid Search LP';
						SiteSection = 'Landing Pages';
					end;
			if Page in ('kp.kaiserpermanente.org/small-business/nl-nbrd',
						'kp.kaiserpermanente.org/small-business/nl-brd')
					then do;
						Page = 'Small Business National Paid Search LP';
						SiteSection = 'Landing Pages';
					end;
			if Page = 'kp.kaiserpermanente.org/small-business/ca-da-healthplans'
					then do;
						Page = 'Small Business CA Data Axel LP';
						SiteSection = 'Landing Pages';
					end;
			if Page = 'respond.kaiserpermanente.org/coloradosmallbiz'
					then do;
						Page = 'Small Business CO Paid Search LP';
						SiteSection = 'Landing Pages';
					end;
			if Page = 'respond.kaiserpermanente.org/nwsmallbusiness'
					then do;
						Page = 'Small Business NW Paid Search LP';
						SiteSection = 'Landing Pages';
					end;

			/* New */
			if find(Page,'success.kaiserpermanente.org')>0 
					then SiteSection = 'Landing Pages';
			if find(Page,'success.kaiserpermanente.org/exec','i') > 0
					then Page = 'B2B Landing Pages for Executives - RTW';
			if find(Page,'success.kaiserpermanente.org/hbo','i') > 0
					then Page = 'B2B Landing Pages for HR & Benefits - RTW';
			if find(Page,'success.kaiserpermanente.org/mhw-exec','i') > 0
					then Page = 'B2B Landing Pages for Executives - MHW';
			if find(Page,'success.kaiserpermanente.org/mhw-hbo','i') > 0
					then Page = 'B2B Landing Pages for HR & Benefits - MHW';
			if find(Page,'success.kaiserpermanente.org/vc-exec','i') > 0
					then Page = 'B2B Landing Pages for Executives - VC';
			if find(Page,'success.kaiserpermanente.org/vc-hbo','i') > 0
					then Page = 'B2B Landing Pages for HR & Benefits - VC';

			if find(Page,'virtualproducts.kaiserpermanente.org','i')>0 
					then SiteSection = 'Landing Pages';

			if Page in ('oregon-southwest-washington-cardiac-care',
						'planning-for-next-normal-at-work',
						'small-business-health-coverage-download',
						'telehealth-supports-employees-health-and-benefits-business'
						'washington-care-access','washington-mental-health-wellness')
					then SiteSection = 'Landing Pages';
			if Page = 'respond.kaiserpermanente.org/emp_acq_sbu_nurture_co_ebookdownload'
				then Page = 'E-Book Download';
			if Page = 'respond.kaiserpermanente.org/emp_acq_sbu_nurture_co_ebookdownload_ty'
				then Page = 'E-Book Download Thank You';
			if find(Page,'thrive/resource-center') > 0 or SiteSection = 'wp-content' then 
				SiteSection = 'Thrive At Work: Resource Center';
			if SiteSection = 'thrive' 
				then SiteSection = 'Thrive At Work';
			if SiteSection = 'health-plan' 
				then SiteSection = 'Health Plans';
			if SiteSection = 'kp-difference'
				then SiteSection = 'The KP Difference';
			if SiteSection = 'insights' 
				then SiteSection = 'Insights';
			if SiteSection in ('contact','faqs','homepage',
								'manage-account','saved-items',
								'site-map')
				then SiteSection = 'Other';

		*drop pagePath;

		/* -------------------------------------------------------------------------------------------------*/
		/*  Create a clean Channel variable.                                                                */
		/* -------------------------------------------------------------------------------------------------*/
	
		if Medium = '(none)' then Channel = 'Direct'; 
				/* Organic Search */
				else if lowcase(Medium) = 'organic' then Channel = 'Organic Search';
				else if lowcase(Medium) = 'referral' 
					and Source in ('duckduckgo.com','us.search.yahoo.com',
									'r.search.aol.com','us.search.yahoo.com',
									'search.aol.com','search.google.com')
					then Channel = 'Organic Search';
				/* Paid Search */
				else if lowcase(Medium) = 'cpc' then do;
	/*				if find(campaign,'KP_B2B_LG') > 0 then Channel = 'Paid Search-LG';*/
	/*				else if find(campaign,'KP_B2B_SB') > 0 then Channel = 'Paid Search-SB';*/
	/*				else if find(campaign,'KP_EL_NON') > 0 then Channel = 'Paid Search-EL';*/
					Channel = 'Paid Search';
				end;
				/* Other Paid Search */
				else if lowcase(source) = 'sem'
						or lowcase(source) = 'ttd'
						then Channel = 'Paid Search';
				else if find(PagePath,'utm_medium=cpc','i') > 0 
					then Channel = 'Paid Search';
				/* (OLD) Display - Regional */
				else if (lowcase(Medium) = 'display' and find(campaign,'Phase_3') > 0)
							or (lowcase(Medium) = '(not set)' and find(campaign,'Phase_3') > 0 and adContent='NW')
							or (lowcase(Medium) = 'banner' and Source = 'localiq')
					then Channel = 'Display NW';
				else if lowcase(Medium) = 'display' and find(campaign,'kp-b2b-choosebetter') > 0
					then Channel = 'Display MAS';
				/* (CURRENT) Display - Regional */
				else if lowcase(Medium) = 'display' and find(Source,'-nw-') > 0 and
					(find(Campaign,'pbj') > 0 or
					 find(Campaign,'LaneCounty') > 0)
					 then Channel = 'Display NW';
				else if lowcase(Medium) in ('eblast','interscroller')
					and find(Source,'-nw-')>0
					then Channel = 'Other NW';
				else if lowcase(Medium) = 'display' and find(Source,'-hi-') > 0 
					and find(Campaign,'pbn') > 0
					then Channel = 'Display HI';
				else if lowcase(Medium) in ('native') or find(Medium,'text ad','i')>0
					and find(Source,'-hi-')>0
					then Channel = 'Other HI';
				else if Medium = 'display' and find(Source,'-co-') > 0
					and Campaign = '[CMA]' then Channel = 'Display CO';

					/* Display - SB */
					else if lowcase(Medium) = 'display' and find(lowcase(Source),'sb-')>0
						then Channel = 'Display SB';
	
					/* Display - B2B */
					else if lowcase(Medium) = 'display' and find(lowcase(Source),'lg-')>0 /* 2021 */ 
							or (lowcase(Source) = 'display' and lowcase(Medium) in ('ncal','scal','nw','was')) /* 2020 */
							or find(lowcase(Campaign),'_vd_nat_','i') > 0 /* Value Demonstration */
						then Channel = 'Display B2B';

				/* Email */
				else if find(Medium,'email','i') > 0 
					then Channel = 'Email';
				/* Direct Mail */
				else if find(Medium,'direct mail','i') > 0
					 or find(Medium,'direct-mail','i') > 0
					then Channel = 'Direct Mail';
				/* LinkedIn */
				else if lowcase(Medium) = 'linkedin' then do;
					/* LinkedIn - SBU */
					if (lowcase(Source) = 'sbu' or find(lowcase(source),'sb-')>0) 
						then Channel = 'Social-LinkedIn SB';
					/* (OLD) LinkedIn - B2B */
					else if lowcase(Campaign) = 'b2b' then Channel = 'Social-LinkedIn LG';
					/* LinkedIn - B2B */
					else if medium = 'linkedin' and find(Source,'lg-') > 0
						then Channel = 'Social-LinkedIn LG';
					/* LinkedIn - NW */
					else if find(Source,'social','i') > 0 and find(Campaign,'NW ','i') > 0
						then Channel = 'Social-LinkedIn NW';
					else if find(Source,'InMail','i') > 0 and Campaign = 'KPNW' 
						then Channel = 'Social-LinkedIn NW';
					/* PR-Comms */
					else if source = 'pr-comms' 
						then Channel='Social-LinkedIn PR'; 
					/* Organic Posts */
					else if lowcase(Campaign) = 'virtual_care_msk'
						then Channel = 'Social-Organic Posts';
					else if find(lowcase(keyword),'organic')>0 
						then Channel = 'Social-Organic Posts';
				end;
				/* Misc - old LinkedIn variants */
				else if find(Source,'linkedin','i') > 0 or Medium = 'sam-social-post' or find(lowcase(keyword),'organic')>0 then do;
					if prxmatch("/(\w+|\d+)-\d{4}/",Campaign) > 0 then Channel = 'Social-LinkedIn LG';
					else if Medium = 'sponsored-content' and Campaign not in ('b2b-reduce-stress','b2b-value-dem')
						then Channel = 'Social-LinkedIn NW';
					else if Campaign in ('b2b-reduce-stress','b2b-value-dem')
						then Channel = 'Social-LinkedIn LG';
/*					else if Medium = 'linkedin'*/
/*						then Channel = 'Social-LinkedIn LG';*/
					else if find(Campaign,'va medical plans 2020 broker','i')>0
						then Channel = 'Social-LinkedIn MAS';	
					/* Organic Posts */
					else if find(lowcase(keyword),'organic')>0 
						then Channel = 'Social-Organic Posts';
					else if lowcase(Campaign) = 'virtual_care_msk'
						then Channel = 'Social-Organic Posts';
					else if Medium = 'sam-social-post'
						then Channel = 'Social-Organic Posts';
					else Channel = 'Social-Other';
				end;
				/* Facebook/Twitter */
				else if lowcase(medium) = 'facebook' and lowcase(source)='sb-ca-prospect'
					then Channel = 'Social-Facebook SB';
				else if lowcase(medium) = 'twitter'
					then Channel = 'Social-Twitter LG';
				/* Social - Other */
				else if find(Source,'facebook','i') > 0
						or find(Source,'social','i') > 0 
						or Source in ('twitter_ads','t.co','web.wechat.com','ws.sharethis.com','youtube.com','insatgram')
					then Channel = 'Social-Other'; /* Facebook, Twitter, Youtube, Other */
				/* Referral & Other */
				else Channel = 'Referral & Other';

		/* -------------------------------------------------------------------------------------------------*/
		/*  Clean the campaign variable. Create a Referral_Other variable.                                  */
		/* -------------------------------------------------------------------------------------------------*/

		if source in ('internal','internal-kp') or source = 'intranet' then do;
			if find(campaign,'comm-flash') > 0 then Campaign = 'comm-flash';
			Channel = 'Internal KP';
		end;
		if Channel in ('Direct Mail','Email') then do;
			if Source='broker-briefing' then campaign='broker-briefing';
				else if Source='localiq' then campaign=campaign;
				else if find(campaign,'broke') > 0 then campaign = 'broker';
				else if find(campaign,'employe') > 0 then campaign = 'employer';
		end;
		if Channel in ('Direct Mail','Email') and Source in ('SBU','sb-ca','sb-ca-prospect') and find(campaign,'direct')=0 then campaign = 'SBU';

		if Channel = 'Referral & Other' then do;
			if Source = 'account.kp.org' then Referral_Other = 'Account.kp.org';
			else if medium in ('playbook','toolkit','infographic','guide') then Referral_Other = catx(" / ","Playbooks and Toolkits",campaign);
			else if medium = 'account.kp.org' then Referral_Other = catx(" / ","Account.kp.org",campaign);
			else if Medium = 'referral' then Referral_Other = catx(" / ","Referral",Source);
			else Referral_Other = catx(" / ",Source,Medium);
			end;
		else Referral_Other = '';

		adContent = upcase(adContent);

		if 
/*			eventCategory = 'Get Started Click' */
			eventLabel = "https://account.kp.org/broker-employer/resources/employer/floating/register?WT.mc_id=1234&getquote="
			then delete;
		eventLabel = tranwrd(eventLabel,'download/resource-center/https://business.kaiserpermanente.org/download.php?doc=','');

	run;

	proc sort data=prod.B2B_Content_Raw_Actions_New; by Page; run;
	proc sort data=pvs_per_page; by page; run;
	
	data drop_actions prod.B2B_Content_Actions_New(drop=Flag_Drop Pageviews pagePath); 
		drop pagePath; 
		merge prod.B2B_Content_Raw_Actions_New(in=a)
			  pvs_per_page(in=b);
		by Page;
		Flag_Drop = 0;
		if find(Page,'success.kaiserpermanente.org')>0 
				or (SiteSection not in ('respond.kaiserpermanente.org',
									'kpbiz.org',
									'Thrive At Work: Resource Center',
									'Thrive At Work',
									'The KP Difference',
									'Other',
									'Landing Pages',
									'Insights',
									'Health Plans') 
						and Page not in ('manage-account','your-health-care-abcs')
						and find(Page,'resource-center')=0)
				then Flag_Drop = 1;
		if a and Pageviews > 1 and Flag_Drop = 0 then output prod.B2B_Content_Actions_New; 
		else if a then output drop_actions;
	run;

	proc sql;
	create table Pvs_per_page_keep as
		select distinct
			SiteSection
		,	Page
		,	sum(uniqueEvents) as Events
		from prod.B2B_Content_Actions_New
		group by 
			SiteSection
		,	Page
		order by 
			SiteSection;

	create table Pvs_per_page_drop as
		select distinct
			SiteSection
		,	Page
		,	sum(uniqueEvents) as Events
		from drop_actions
		group by 
			SiteSection
		,	Page
		order by 
			SiteSection;
	quit;

	/* -------------------------------------------------------------------------------------------------*/
	/*  Merge new with historical data.                                                                 */
	/* -------------------------------------------------------------------------------------------------*/

	/* master */
	data prod.B2B_Content_Actions_Master;
		retain Date WeekStart Channel SiteSection Page PageType 
				EventCategory EventAction EventLabel uniqueEvents
				referral_other source medium campaign adContent keyword;
		format Page $200. Campaign $200.;
		set prod.B2B_Content_Actions_New
		    prod.B2B_Content_Actions_Master;
	run;

	proc delete data=prod.B2B_Content_Raw_Actions_New;

	/* -------------------------------------------------------------------------------------------------*/
	/*  Get first date/last date of the current raw data.                                               */
	/* -------------------------------------------------------------------------------------------------*/

	proc sql;
	select distinct 
		min(Date) format mmddyy6.,
		max(Date) format mmddyy6.
		into
		:FirstData,
		:LastData
		from prod.B2B_Content_Actions_Master;
	quit;

	/* -------------------------------------------------------------------------------------------------*/
	/*  Save master file(s) --> zip archive.                                                            */
	/* -------------------------------------------------------------------------------------------------*/

	/* master */
	data archive.b2b_content_a_&FirstData._&LastData;
		set prod.B2B_Content_Actions_Master;
	run;

	ods package(archived) open nopf;
	ods package(archived) add file="&output_file_path&archive/b2b_content_a_&FirstData._&LastData..sas7bdat";
	ods package(archived) publish archive properties (
		archive_name="b2b_content_a_&FirstData._&LastData..zip"
		archive_path="&output_file_path&archive/");
	ods package(archived) close;

	proc delete data=archive.b2b_content_a_&FirstData._&LastData; run;

	filename old_arch "&output_file_path&archive/b2b_content_a_&FirstData._&LastDate_Previous..zip";
	data _null_;
		rc=fdelete("old_arch");
		put rc=;
	run;

	proc delete data=prod.b2b_content_raw_actions; run;
	proc delete data=prod.B2B_Content_Actions_New; run;
/* -------------------------------------------------------------------------------------------------*/
/*  Email.                                                                                          */
/* -------------------------------------------------------------------------------------------------*/

	%let input_files = &output_file_path;

	/* you may change the default sentFrom and sentTo */
	%emailB2Bdashboard(Get_GA_ContentPerformance_Data_Monthly,
			attachFreqTableFlag=1,
			attachLogFlag=1 /*,
			sentFrom=,
			sentTo=*/
			);

	proc printto; run; /* Turn off log export to .txt */