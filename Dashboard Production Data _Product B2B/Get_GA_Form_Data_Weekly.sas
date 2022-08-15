/****************************************************************************************************/
/*  Program Name:       Get_GA_Form_Data_Weekly.sas                                                 */
/*                                                                                                  */
/*  Date Created:       October 25, 2021                                                            */
/*                                                                                                  */
/*  Created By:         Elle Haynes                                                                 */
/*                                                                                                  */
/*  Purpose:            Compiles daily form abandonment data from Better Way for the SBU Digital    */
/*                      Funnel.                                                                     */
/*                                                                                                  */
/*  Inputs:             This script can run on schedule without input.                              */
/*                                                                                                  */
/* -------------------------------------------------------------------------------------------------*/	
/*  Notes:                                                                                          */
/* -------------------------------------------------------------------------------------------------*/
/*  Date Modified:                                                                                  */
/*  Modified by:                                                                                    */
/*  Description:                                                                                    */
/****************************************************************************************************/

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
        addl_filters		   firstdata              lastdata;   
%let errorCode=;
%let dt=.; *"31dec2020"d; *leave empty unless running manually;
%let N=; %let Nnew = 0;

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

%let yesterday=%sysfunc(putn(%eval(%sysfunc(today())-1),date9.));

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

filename old_log "&output_file_path/LOG Get_GA_Form_Data_Weekly.txt";
data _null_; rc=fdelete("old_log"); put rc=; run;
proc printto log="&output_file_path/LOG Get_GA_Form_Data_Weekly.txt"; run;

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

%let DES=					%sysfunc(urlencode(%str(gaid::Pc0z44L_S4OW0UYhSFkN9g)));
%let MOB=					%sysfunc(urlencode(%str(gaid::pOQfYKRUQG2nhNAil8xfEA)));

/* -------------------------------------------------------------------------------------------------*/
/*                                                                                                  */
/*                                                                                                  */
/*                                    Update B2B_form_master                                        */
/*                                                                                                  */
/*                                                                                                  */
/* -------------------------------------------------------------------------------------------------*/

	proc sql noprint;
		select
			coalesce(&dt,max(Date)) format mmddyy6.
		,	coalesce(&dt,max(Date))+1 format date9.
		into :LastData_Old trimmed,
			 :LastData_OldNum trimmed
		from prod.B2B_Form_Master;
	quit;

/* -------------------------------------------------------------------------------------------------*/
/*                                                                                                  */
/*                                                                                                  */
/*                                            Event table                                           */
/*                                          Page-level call                                         */
/*                                                                                                  */
/*                                                                                                  */
/* -------------------------------------------------------------------------------------------------*/

%let error_rsn=Error during pull;

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
	%let var&i=          userType; 
	%let informat_var&i= $17.;
	%let format_var&i=   $17.;

	%let i=%eval(&i+1);
	%let var&i=          eventLabel; 
	%let informat_var&i= $200.;
	%let format_var&i=   $200.;

	%let number_of_dimensions=&i;

/* -------------------------------------------------------------------------------------------------*/
/*  Metrics                                                                                         */
/* -------------------------------------------------------------------------------------------------*/

	%let i=%eval(&i+1);
	%let var&i=          uniqueEvents; /* count of unique actions */
	%let informat_var&i= 8.;
	%let format_var&i=   8.;	

	%let number_of_metrics=%eval(&i-&number_of_dimensions);

/* -------------------------------------------------------------------------------------------------*/
/*  Execute.                                                                                        */
/* -------------------------------------------------------------------------------------------------*/

* Form Abandonments;
	* Filter by eventCategory;
	%let e1filter1=%sysfunc(urlencode(ga:eventCategory==Form Abandonment)); 
	* Filter by eventAction;
	%let e1filter2=%sysfunc(urlencode(ga:eventAction==Quote)); 
	%let e1filter3=%sysfunc(urlencode(ga:eventAction==Contact)); 

* Form Submits;
	* Filter by eventLabel;
	%let e1filter4=%sysfunc(urlencode(ga:eventLabel=~FormSubmission)); 

* Form Starts;
	* Filter by eventLabel;
	%let e1filter5=%sysfunc(urlencode(ga:eventLabel=~OnPage)); 

	%macro exec(exec_segment,
				exec_filter,
				exec_output_file_name,
/*				exec_business_size,*/
				exec_device
/*				,exec_rename*/
				);

		%GetGAData(chooseSegment=&&exec_segment,
						chooseView=Default,
						addl_filters=&&exec_filter,
						level=day,
						StartDate=&LastData_OldNum,
						EndDate=&yesterday,
						output_file_path=&output_file_path,
						output_file_name=&&exec_output_file_name);
					data ga.&&exec_output_file_name.; 
						set ga.&&exec_output_file_name.; 
/*						Business_Size = "&exec_business_size."; */
						DeviceType = "&exec_device"; 
/*						rename uniqueEvents = &exec_rename;*/
					run;

	%mend;

	* Desktop;
		* Form Abandonment;
		%exec(&DES,%bquote(&e1filter1%nrstr(;)&e1filter2),b2b_form_DES_Quote,Desktop);
		%exec(&DES,%bquote(&e1filter1%nrstr(;)&e1filter3),b2b_form_DES_Contact,Desktop);
		* Submits;
		%exec(&DES,%bquote(&e1filter4%nrstr(;)&e1filter2),b2b_form_DES_Quote_s,Desktop);
		%exec(&DES,%bquote(&e1filter4%nrstr(;)&e1filter3),b2b_form_DES_Contact_s,Desktop);
		* On-Page Quote Form Starts;
		%exec(&DES,%bquote(&e1filter5%nrstr(;)&e1filter2),b2b_form_DES_Quote_o,Desktop);
		%exec(&DES,%bquote(&e1filter5%nrstr(;)&e1filter3),b2b_form_DES_Contact_o,Desktop);

	* Mobile & Tablet;
		* Form Abandonment;
		%exec(&MOB,%bquote(&e1filter1%nrstr(;)&e1filter2),b2b_form_MOB_Quote,Mobile & Tablet);
		%exec(&MOB,%bquote(&e1filter1%nrstr(;)&e1filter3),b2b_form_MOB_Contact,Mobile & Tablet);
		* Submits;
		%exec(&MOB,%bquote(&e1filter4%nrstr(;)&e1filter2),b2b_form_MOB_Quote_s,Mobile & Tablet);
		%exec(&MOB,%bquote(&e1filter4%nrstr(;)&e1filter3),b2b_form_MOB_Contact_s,Mobile & Tablet);
		* On-Page Quote Form Starts;
		%exec(&MOB,%bquote(&e1filter5%nrstr(;)&e1filter2),b2b_form_MOB_Quote_o,Mobile & Tablet);
		%exec(&MOB,%bquote(&e1filter5%nrstr(;)&e1filter3),b2b_form_MOB_Contact_o,Mobile & Tablet);

	* Append ShopActions_Unique;
	data ga.b2b_form_raw;
		format DeviceType $16. eventAction $7. eventCategory $16.;
		set /* Quote */
			ga.b2b_form_MOB_Quote(in=qm)
			ga.b2b_form_DES_Quote(in=qd)
			ga.b2b_form_MOB_Quote_s(in=qms)
			ga.b2b_form_DES_Quote_s(in=qds)
			ga.b2b_form_MOB_Quote_o(in=qmo)
			ga.b2b_form_DES_Quote_o(in=qdo)
			/* Contact */
			ga.b2b_form_MOB_Contact(in=cm)
			ga.b2b_form_DES_Contact(in=cd)
			ga.b2b_form_MOB_Contact_s(in=cms)
			ga.b2b_form_DES_Contact_s(in=cds)
			ga.b2b_form_MOB_Contact_o(in=cmo)
			ga.b2b_form_DES_Contact_o(in=cdo)
			;

		if qm or qd or qms or qds or qmo or qdo then eventAction = 'Quote';
		else eventAction = 'Contact'; 

		if qm or qd or cm or cd then eventCategory = 'Form Abandonment';
		else eventCategory = 'Convert';
	run;

	%check_for_data(ga.b2b_form_raw,=0,No records in b2b_form_raw);

	proc delete data=ga.b2b_form_MOB_Quote; run &cancel.;
	proc delete data=ga.b2b_form_DES_Quote; run &cancel.;
	proc delete data=ga.b2b_form_MOB_Quote_s; run &cancel.;
	proc delete data=ga.b2b_form_DES_Quote_s; run &cancel.;
	proc delete data=ga.b2b_form_MOB_Quote_o; run &cancel.;
	proc delete data=ga.b2b_form_DES_Quote_o; run &cancel.;
	proc delete data=ga.b2b_form_MOB_Contact; run &cancel.;
	proc delete data=ga.b2b_form_DES_Contact; run &cancel.;
	proc delete data=ga.b2b_form_MOB_Contact_s; run &cancel.;
	proc delete data=ga.b2b_form_DES_Contact_s; run &cancel.;
	proc delete data=ga.b2b_form_MOB_Contact_o; run &cancel.;
	proc delete data=ga.b2b_form_DES_Contact_o; run &cancel.;

/* -------------------------------------------------------------------------------------------------*/
/*  Final processing of page-level data.                                                            */
/* -------------------------------------------------------------------------------------------------*/

	data ga.b2b_form_raw_v2;

		format 	Date mmddyy10.
				WeekStart mmddyy10.
				Month monyy7.
				Quarter yyq7.
				UTM_Source $50.
				UTM_Medium $50.
				Hostname_pagePath $50.
				SiteSection $40.
				Region $4.
				SubRegion $4.
				Channel $25.
				ChannelDetail $50.
				;

		set ga.b2b_form_raw;

	/* -------------------------------------------------------------------------------------------------*/
	/*  UTM cleaning.                                                                                   */
	/* -------------------------------------------------------------------------------------------------*/

		UTM_Source = lowcase(strip(substr(SourceMedium,1,index(SourceMedium,'/')-1)));
		UTM_Medium = lowcase(strip(substr(SourceMedium,index(SourceMedium,'/')+1,length(SourceMedium))));
			drop SourceMedium;
		UTM_Campaign = strip(lowcase(Campaign));
		UTM_Content = strip(lowcase(adContent));
			drop Campaign adContent;
		if UTM_content = '(not set)' then UTM_content = '';
		if UTM_campaign = '(not set)' then UTM_campaign = '';

	/* -------------------------------------------------------------------------------------------------*/
	/*  Region.                                                                                   */
	/* -------------------------------------------------------------------------------------------------*/

		region_parse = scan(UTM_Source,2,'-');
		if UTM_Medium = 'cpc' then region_parse = lowcase(scan(UTM_Campaign,5,'_'));
		if region_parse in ('canc','ncal') then Region = 'NCAL';
			else if region_parse in ('casc','scal') then Region = 'SCAL';
			else if region_parse = 'ca' then Region = 'CA';
			else if region_parse in ('clrd','co') then Region = 'CLRD';
			else if region_parse in ('pcnw','nw') then Region = 'PCNW';
			else if region_parse in ('kpwa','wa','kpwas') then Region = 'KPWA';
			else if region_parse in ('grga','ga') then Region = 'GRGA';
			else if region_parse in ('hwai','hi') then Region = 'HWAI';
			else if region_parse in ('mas','mr') then Region = 'MAS';
			else if UTM_Source = 'lanekp.org' then Region = 'PCNW';
			else Region = 'NA';
		SubRegion = 'NA';
		drop region_parse;

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
								'success.kaiserpermanente.org') 
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
			else if find(UTM_Campaign,'_vd_nat_','i') = 0
					and (
					   (UTM_Medium = 'display' and find(UTM_Source,'-nw-') > 0 and (find(UTM_Campaign,'pbj') > 0 or find(UTM_Campaign,'LaneCounty') > 0)) /* NW */
					or (UTM_Medium in ('eblast','interscroller') and find(UTM_Source,'-nw-') > 0) /* NW */
					or (UTM_Medium = 'display' and find(UTM_Source,'-hi-') > 0 and find(UTM_Campaign,'pbn') > 0) /* HI */
					or (UTM_Medium in ('native','April Text Ad') and find(UTM_Source,'-hi-') > 0) /* HI */
					or (UTM_Medium = 'display' and find(UTM_Source,'-co-') > 0 ) /* CO */
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
			else if UTM_Medium = 'display' /* 2021 */
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
				else if UTM_Medium in ('playbook','toolkit') then do;
					Referral_Other = catx(" / ","Playbooks and Toolkits",UTM_Campaign);
					ChannelDetail = 'Playbooks and Toolkits';
				end;
				else if UTM_Medium = 'referral' then Referral_Other = catx(" / ","Referral",UTM_Source);
				else Referral_Other = catx(" / ",UTM_Source,UTM_Medium);
				end;
			else Referral_Other = '';
			if UTM_Source = 'account.kp.org' or UTM_Medium = 'account.kp.org'
				then ChannelDetail = 'Account.kp.org';
			if ChannelDetail = '' then ChannelDetail = Channel;

	run;

	data ga.b2b_form_raw_v3;
		retain Date
					WeekStart
					Month
					Quarter
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
					eventCategory
					eventAction
					eventLabel
					uniqueEvents
					Rec_Update_Date
				;

		format Rec_Update_Date datetime18.;

		set ga.b2b_form_raw_v2;

		Rec_Update_Date=datetime();

		* Replace missing numeric w/ 0;
		 array change _numeric_;
	        do over change;
	            if change=. then change=0;
	        end;

	run;

	proc sql;
	insert into prod.b2b_form_master
		select * from ga.b2b_form_raw_v3;
	quit;

	proc sql;
		select distinct count(*) into :Nnew from ga.b2b_form_raw_v3;
	quit;

/*	data prod.b2b_form_master;*/
/*		set ga.b2b_form_raw_v3;*/
/*		drop region_parse;*/
/*	run;*/

	proc delete data=ga.b2b_form_raw_v3; run;
	proc delete data=ga.b2b_form_raw_v2; run;
	proc delete data=ga.b2b_form_raw; run;

	/* drop tables */
	/* archive */
	/* freq tables */

/* -------------------------------------------------------------------------------------------------*/
/*  Email.                                                                                          */
/* -------------------------------------------------------------------------------------------------*/

	%let input_files = &output_file_path;
	%let Campaign_StartDate = &LastData_OldNum;
	%let Campaign_EndDate = &yesterday;

	%emailB2Bdashboard(Get_GA_Form_Data_Weekly,
		attachFreqTableFlag=0,
		attachLogFlag=1 /*,
		sentFrom=,
		sentTo= */
		);




