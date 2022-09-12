/****************************************************************************************************/
/*  Program Name:       DNB Visitor Intelligence Google Analytics API Pull.sas                      */
/*                                                                                                  */
/*  Date Created:       June 10, 2022                                                               */
/*                                                                                                  */
/*  Created By:         Elle Haynes                                                                 */
/*                                                                                                  */
/*  Purpose:            Compiles data from Better Way for the D&B Visitor Intelligence Analysis.    */
/*                                                                                                  */
/*  Inputs:             This script is meant to run manually.                                       */
/*                                                                                                  */
/* -------------------------------------------------------------------------------------------------*/	
/*  Notes:              Based on template "Exec Get_GA_Data API Macro.sas"                          */
/* -------------------------------------------------------------------------------------------------*/
/*  Date Modified:                                                                                  */
/*  Modified by:                                                                                    */
/*  Description:                                                                                    */
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

/* -------------------------------------------------------------------------------------------------*/
/*  Load stored macros.                                                                             */
/* -------------------------------------------------------------------------------------------------*/

options source2 orientation=portrait;
%include "/gpfsFS2/sasdata/adhoc/po/imca/digital/code/Access/SAS_Macro_RefreshToken.sas"; *%refreshToken;
%include "/gpfsFS2/sasdata/adhoc/po/imca/digital/code/Access/SAS_Macro_CheckToken.sas"; *%checkToken;
%include "/gpfsFS2/sasdata/adhoc/po/imca/digital/code/Access/SAS_Macro_APIvariablePrep.sas"; *%APIvariablePrep;
%include "/gpfsFS2/sasdata/nfs/ndc_grid/po_imca_digital/EHaynes/B2B Dashboard Data Processing/_GitHub Repository B2B/SAS_Macro_GetGAData.sas"; *%GetGAData;

/* -------------------------------------------------------------------------------------------------*/
/*  Refresh the access-token, which is valid for 60 minutes.                                        */
/* -------------------------------------------------------------------------------------------------*/

%refreshToken;

/* -------------------------------------------------------------------------------------------------*/
/*  Segment & filters.                                                                                        */
/* -------------------------------------------------------------------------------------------------*/

%let BWSessions = %sysfunc(urlencode(%str(gaid::Db6uItiETke3vEysmk_yOw)));

/* -------------------------------------------------------------------------------------------------*/
/*  Libraries.                                                                                      */
/* -------------------------------------------------------------------------------------------------*/

%let output_file_path= /gpfsFS2/sasdata/nfs/ndc_grid/po_imca_digital/EHaynes/B2B DNB Visitor Intelligence Data Append;
libname ga "&output_file_path"; 

/* -------------------------------------------------------------------------------------------------*/
/*                                                                                                  */
/*                                                                                                  */
/*                                   Pull 1: Campaign Information                                   */
/*                                                                                                  */
/*                                                                                                  */
/* -------------------------------------------------------------------------------------------------*/

/* -------------------------------------------------------------------------------------------------*/
/*  Dimensions                                                                                      */
/* -------------------------------------------------------------------------------------------------*/

	%let i=1;
	%let var&i=          SourceMedium;
	%let informat_var&i= $100.;
	%let format_var&i=   $100.;

	%let i=%eval(&i+1);
	%let var&i=          Campaign;
	%let informat_var&i= $200.;
	%let format_var&i=   $200.;

	%let i=%eval(&i+1);
	%let var&i=          dimension2; *SessionId;
	%let informat_var&i= $50.; 
	%let format_var&i=   $50.; 

	%let number_of_dimensions=&i;

/* -------------------------------------------------------------------------------------------------*/
/*  Metrics                                                                                         */
/* -------------------------------------------------------------------------------------------------*/

	%let i=%eval(&i+1);
	%let var&i=          Users;
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

	%let i=%eval(&i+1);
	%let var&i=          goal5Completions; *ConvertSubmit_Quote;
	%let informat_var&i= 8.;
	%let format_var&i=   8.;

	%let i=%eval(&i+1);
	%let var&i=          goal8Completions; *ConvertSubmit_Contact;
	%let informat_var&i= 8.;
	%let format_var&i=   8.;	

	%let i=%eval(&i+1);
	%let var&i=          goal16Completions; *ConvertNonSubmit_SSQ;
	%let informat_var&i= 8.;
	%let format_var&i=   8.;

	%let i=%eval(&i+1);
	%let var&i=          goal13Completions; *Convert_Call;
	%let informat_var&i= 8.;
	%let format_var&i=   8.;	

	%let number_of_metrics=%eval(&i-&number_of_dimensions);

/* -------------------------------------------------------------------------------------------------*/
/*  Execute.                                                                                        */
/* -------------------------------------------------------------------------------------------------*/

	%GetGAData(chooseSegment=&BWSessions,
				chooseView=Default,
				addl_filters=,
				level=day,
				StartDate=06APR2022,
				EndDate=09JUN2022,
				output_file_path=&output_file_path,
				output_file_name=vi_campaign);

	data ga.vi_campaign_final;

		set ga.vi_campaign;

		rename dimension2 = Session_ID
				goal5Completions = ConvertSubmit_Quote
				goal8Completions = ConvertSubmit_Contact
/*				goal16Completions = ConvertNonSubmit_SSQ*/
				goal13Completions = Convert_Call
				sessionDuration = sessionDuration_sec;

		ConvertSubmit_SSQ = goal16Completions*0.43;
		drop goal16Completions;

		* Remove test sources;
		if find(SourceMedium,'wrike.com')>0 
		or find(SourceMedium,'kpnationalconsumersales--kpdev1--c.documentforce.c')>0 
		or find(SourceMedium,'wiki.kp.org')>0 
		or find(SourceMedium,'sp-cloud.kp.org')>0 
		or find(SourceMedium,'kp.my.salesforce.com')>0 
		or find(SourceMedium,'basecamp.com')>0 
		or find(SourceMedium,'app.crazyegg.com')>0 
		or find(SourceMedium,'account-preview.kp.org')>0 
		or find(SourceMedium,'app.marinsoftware.com')>0 
		or find(SourceMedium,'author-sanbox-afd.kp.org')>0 
		or find(SourceMedium,'bconnected.connextion.co')>0 
		or find(SourceMedium,'comms01.kp.org')>0
		or find(SourceMedium,'kp-aws-cloud.org','i') > 0
		or find(SourceMedium,'tagassistant.google.com','i') > 0 
		or length(SourceMedium) > 50 
		or find(SourceMedium,'c5c') > 0 
		or find(SourceMedium,'test','i') > 0 
	    or find(SourceMedium,'preview.pixel.ad','i') > 0 
		or find(SourceMedium,'leadboldly.crosbydev.net','i') > 0 
		or find(SourceMedium,'officeapps.live.com','i') > 0  
	    or find(SourceMedium,'wabusinessdev.wpengine.com','i') > 0 
		or find(SourceMedium,'dev-','i')>0 
		or find(SourceMedium,'kpwanl') > 0 
		or find(SourceMedium,'preview.dpaprod') > 0
		or find(SourceMedium,'optimizely') > 0
		or find(SourceMedium,'sp.kp.org') > 0
		or find(SourceMedium,'localhost') > 0 
		or find(SourceMedium,'pathroutes') > 0
		or find(SourceMedium,'addotnet') > 0
		or find(SourceMedium,'searchiq') > 0
		or prxmatch("/\d\d\d\.\d\.\d\.\d:\d{4}/",SourceMedium) > 0 
		then delete;

		* Channel;
		format Channel $50. ChannelDetail $50.;
		if SourceMedium = '(direct) / (none)' then Channel = 'Direct';
		else if find(SourceMedium,'internal-kp')>0 then Channel = 'Internal KP';
		else if find(SourceMedium,'cpc')>0 then Channel = 'Paid Search';
		else if find(SourceMedium,' / organic')>0 then Channel = 'Organic Search';

		else if find(SourceMedium,'pbj')>0 
				or find(Campaign,'pbj')>0
				or (find(SourceMedium,'nw-prospect-b2b')>0 and find(SourceMedium,'social')=0)
				or Campaign='kp-b2b-choosebetter-test-mentalhealth'
				then do;
					Channel = 'Display';
					ChannelDetail = 'Display B2B-REG';
				end;
		else if campaign='DMG-portland' then do;
				Channel = 'Paid Social';
				ChannelDetail = 'Paid Social B2B-REG';
				end;
		else if find(SourceMedium,'2020_VD_NAT','i')>0 then do;
				Channel = 'Display';
				ChannelDetail = 'Display B2B-PO';
				end;
		else if find(SourceMedium,'twitter')>0
				or find(SourceMedium,'sponsored-content')>0
				then do;
				Channel = 'Paid Social';
				ChannelDetail = 'Paid Social B2B-PO';
				end;
		else if find(SourceMedium,'prospect / display')>0 then do;
				Channel = 'Display';
				ChannelDetail = 'Display B2B-PO';
				end;
		else if find(SourceMedium,'prospect / linkedin')>0 then do;
				Channel = 'Paid Social';
				Channel = 'Paid Social B2B-PO';
				end;

		else if find(Campaign,'webinar')>0 
				or find(SourceMedium,'on24.com')> 0
				then Channel = 'Webinar';
		else if find(SourceMedium,'email')>0 then Channel = 'Email';
		else if find(SourceMedium,'toolkit')>0 
				or find(SourceMedium,'playbook')>0 
				or find(SourceMedium,'guide')>0 
				or find(SourceMedium,'infographic')>0 
				then Channel = 'Toolkits & Playbooks';
		else if lowcase(strip(substr(SourceMedium,1,index(SourceMedium,'/')-1))) in ('t.co','m.facebook.com','facebook.com','youtube.com')
				or find(SourceMedium,'sam-social-post')>0 
				then Channel = 'Organic Social';
		else if find(SourceMedium,'referral','i')>0 
				or find(SourceMedium,'account.kp.org')>0 
				or Campaign='lead_boldly_referral'
				then Channel = 'Referral';
		else if Campaign='160294' then Channel = 'SBCA DM Vanity URL';
		else Channel = 'Other & Unknown';

		* ChannelDetail;
		if Channel = 'Paid Search' then do;
			if find(Campaign,'KP_B2B_SB','i')>0 then ChannelDetail = 'Paid Search-SB';
			else if find(Campaign,'KP_B2B_LG','i')>0 then ChannelDetail = 'Paid Search-LG';
			else if find(Campaign,'KP_EL_NON','i')>0 then ChannelDetail = 'Paid Search-EL';
			else ChannelDetail = 'Paid Search-OTH';
			end;
		else if Channel = 'Referral' then do;
			if find(SourceMedium,'account.kp.org')>0 then ChannelDetail='Referral: Account.KP.org';
			else if Campaign='lead_boldly_referral' then ChannelDetail='Referral: MAS Lead Boldly';
			else ChannelDetail=catx(' ','Referral:',lowcase(strip(substr(SourceMedium,1,index(SourceMedium,'/')-1))));
			end;
		else if Channel = 'Email' then do;
			if find(Campaign,'push')>0 then ChannelDetail = 'Email-Push Ready';
			else if find(Campaign,'sb-retention')>0 then ChannelDetail = 'Email-SB Retention';
			else if find(Campaign,'monthly-acquisition')>0 then ChannelDetail = 'Email-SB Acquisition';
			else if find(Campaign,'sb-sales-nurture')>0 then ChannelDetail = 'Email-SB Sales Nurture';
			else if find(Campaign,'incremental')>0 then ChannelDetail = 'Email-Incremental Outreach';
			else ChannelDetail = 'Email-Other';
			end;
		else if Channel in ('Display','Paid Social') then ChannelDetail = ChannelDetail;
		else ChannelDetail = Channel;

		* Replace missing numeric w/ 0;
		 array change _numeric_;
	        do over change;
	            if change=. then change=0;
	        end;

		drop SourceMedium Campaign;

		if Sessions ne 1 then delete; * A few rows with 0 or 2 sessions... looks like errors;

	run;

	proc export 
		data=ga.vi_campaign_final
		outfile="&output_file_path/VI_Channel.csv"
		dbms=CSV replace;
	run;

	proc delete data=ga.vi_campaign; run;
	proc delete data=ga.vi_campaign_final; run;

/* -------------------------------------------------------------------------------------------------*/
/*                                                                                                  */
/*                                                                                                  */
/*                                  Pull 2.1: Page Information                                      */
/*                                                                                                  */
/*                                                                                                  */
/* -------------------------------------------------------------------------------------------------*/

/* -------------------------------------------------------------------------------------------------*/
/*  Dimensions                                                                                      */
/* -------------------------------------------------------------------------------------------------*/

	%let i=1;
	%let var&i=          dimension2; *SessionId;
	%let informat_var&i= $50.; 
	%let format_var&i=   $50.; 

	%let i=%eval(&i+1);
	%let var&i=          landingPagePath; 
	%let informat_var&i= $200.; 
	%let format_var&i=   $200.; 

	%let i=%eval(&i+1);
	%let var&i=          PagePath; 
	%let informat_var&i= $200.; 
	%let format_var&i=   $200.; 

	%let i=%eval(&i+1);
	%let var&i=          SourceMedium;
	%let informat_var&i= $200.;
	%let format_var&i=   $200.;

	%let number_of_dimensions=&i;

/* -------------------------------------------------------------------------------------------------*/
/*  Metrics                                                                                         */
/* -------------------------------------------------------------------------------------------------*/

	%let i=%eval(&i+1);
	%let var&i=          uniquePageviews; 
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

	%GetGAData(chooseSegment=&BWSessions,
	    	    chooseView=Default,
				addl_filters=,
				level=day,
				StartDate=06APR2022,
				EndDate=09JUN2022,
				output_file_path=&output_file_path,
				output_file_name=VI_page_1of2);

	data ga.vi_page_1of2_clean;
		set ga.vi_page_1of2;

		rename dimension2 = Session_ID
				timeOnPage = timeOnPage_sec;

		* Remove records that are not on better way;
		if find(PagePath,'business.kaiserpermanente.org')=0 and find(PagePath,'respond.kaiserpermanente.org')=0
			then delete;

		* Remove test sources;
		if find(SourceMedium,'wrike.com')>0 
		or find(SourceMedium,'kpnationalconsumersales--kpdev1--c.documentforce.c')>0 
		or find(SourceMedium,'wiki.kp.org')>0 
		or find(SourceMedium,'sp-cloud.kp.org')>0 
		or find(SourceMedium,'kp.my.salesforce.com')>0 
		or find(SourceMedium,'basecamp.com')>0 
		or find(SourceMedium,'app.crazyegg.com')>0 
		or find(SourceMedium,'account-preview.kp.org')>0 
		or find(SourceMedium,'app.marinsoftware.com')>0 
		or find(SourceMedium,'author-sanbox-afd.kp.org')>0 
		or find(SourceMedium,'bconnected.connextion.co')>0 
		or find(SourceMedium,'comms01.kp.org')>0
		or find(SourceMedium,'kp-aws-cloud.org','i') > 0
		or find(SourceMedium,'tagassistant.google.com','i') > 0 
		or length(SourceMedium) > 50 
		or find(SourceMedium,'c5c') > 0 
		or find(SourceMedium,'test','i') > 0 
	    or find(SourceMedium,'preview.pixel.ad','i') > 0 
		or find(SourceMedium,'leadboldly.crosbydev.net','i') > 0 
		or find(SourceMedium,'officeapps.live.com','i') > 0  
	    or find(SourceMedium,'wabusinessdev.wpengine.com','i') > 0 
		or find(SourceMedium,'dev-','i')>0 
		or find(SourceMedium,'kpwanl') > 0 
		or find(SourceMedium,'preview.dpaprod') > 0
		or find(SourceMedium,'optimizely') > 0
		or find(SourceMedium,'sp.kp.org') > 0
		or find(SourceMedium,'localhost') > 0 
		or find(SourceMedium,'pathroutes') > 0
		or find(SourceMedium,'addotnet') > 0
		or find(SourceMedium,'searchiq') > 0
		or prxmatch("/\d\d\d\.\d\.\d\.\d:\d{4}/",SourceMedium) > 0 
		then delete;

		drop SourceMedium;

		/* -------------------------------------------------------------------------------------------------*/
		/*  PagePath cleaning.                                                                              */
		/* -------------------------------------------------------------------------------------------------*/

		PagePath = lowcase(compress(tranwrd(PagePath,'business.kaiserpermanente.org/',''),''));
		if find(PagePath,'?') > 0 then PagePath = substr(PagePath,1,index(PagePath,'?')-1);
		if find(PagePath,'WT.mc_id') > 0 then PagePath = substr(PagePath,1,index(PagePath,'WT.mc_id')-1);
		if find(PagePath,'#') > 0 then PagePath = substr(PagePath,1,index(PagePath,'#')-1);
		if substr(reverse(strip(PagePath)),1,1) = '/' then PagePath = substr(strip(PagePath),1,length(strip(PagePath))-1);
	
		SiteSection_PagePath = scan(PagePath,1,'/');

		if PagePath = '' or find(PagePath,'?') > 0 or SiteSection_PagePath = 'page' then PagePath = 'homepage';

		SiteSection_PagePath = scan(PagePath,1,'/');

		if find(PagePath,'thrive/resource-center') > 0 or SiteSection_PagePath = 'wp-content' then SiteSection_PagePath = 'Thrive At Work: Resource Center';
		if SiteSection_PagePath = 'thrive' then SiteSection_PagePath = 'Thrive At Work';
		if SiteSection_PagePath = 'health-plan' then SiteSection_PagePath = 'Health Plans';
		if SiteSection_PagePath = 'kp-difference' then SiteSection_PagePath = 'The KP Difference';
		if SiteSection_PagePath = 'insights' then SiteSection_PagePath = 'Insights';
		if SiteSection_PagePath in ('contact','faqs','homepage',
							'manage-account','saved-items',
							'site-map')
			then SiteSection_PagePath = 'Other';

		if PagePath in ('oregon-southwest-washington-cardiac-care',
			'planning-for-next-normal-at-work',
			'choose-a-better-way-to-manage-costs',
			'controlling-drug-costs',
			'group-size',
			'understand-health-care-quality-ratings',
			'your-health-care-abcs',
			'reporting-that-measures-quality-and-value',
			'how-integrated-health-care-helps-keep-your-employees-healthier',
			'experience-kaiser-permanente-anywhere',
			'small-business-health-coverage-download',
			'telehealth-supports-employees-health-and-benefits-business'
			'washington-care-access','washington-mental-health-wellness')
		then SiteSection_PagePath = 'Landing Pages';

		if PagePath = 'respond.kaiserpermanente.org/emp_acq_sbu_nurture_co_ebookdownload'
			then PagePath = 'E-Book Download';
		if PagePath = 'respond.kaiserpermanente.org/emp_acq_sbu_nurture_co_ebookdownload_ty'
			then PagePath = 'E-Book Download Thank You';
		if find(PagePath,'respond.kaiserpermanente.org') 
			then SiteSection_PagePath = 'E-Book Download';

		if SiteSection_PagePath = PagePath then SiteSection_PagePath = 'Other';

		/* -------------------------------------------------------------------------------------------------*/
		/*  landingPagePath cleaning.                                                                       */
		/* -------------------------------------------------------------------------------------------------*/

		landingPagePath = lowcase(compress(tranwrd(landingPagePath,'business.kaiserpermanente.org/',''),''));
		if find(landingPagePath,'?') > 0 then landingPagePath = substr(landingPagePath,1,index(landingPagePath,'?')-1);
		if find(landingPagePath,'WT.mc_id') > 0 then landingPagePath = substr(landingPagePath,1,index(landingPagePath,'WT.mc_id')-1);
		if find(landingPagePath,'#') > 0 then landingPagePath = substr(landingPagePath,1,index(landingPagePath,'#')-1);
		if substr(reverse(strip(landingPagePath)),1,1) = '/' then landingPagePath = substr(strip(landingPagePath),1,length(strip(landingPagePath))-1);
	
		SiteSection_Entrance = scan(landingPagePath,1,'/');

		if landingPagePath = '' or find(landingPagePath,'?') > 0 or SiteSection_Entrance = 'page' then landingPagePath = 'homepage';

		SiteSection_Entrance = scan(landingPagePath,1,'/');

		if find(landingPagePath,'thrive/resource-center') > 0 or SiteSection_Entrance = 'wp-content' then SiteSection_Entrance = 'Thrive At Work: Resource Center';
		if SiteSection_Entrance = 'thrive' then SiteSection_Entrance = 'Thrive At Work';
		if SiteSection_Entrance = 'health-plan' then SiteSection_Entrance = 'Health Plans';
		if SiteSection_Entrance = 'kp-difference' then SiteSection_Entrance = 'The KP Difference';
		if SiteSection_Entrance = 'insights' then SiteSection_Entrance = 'Insights';
		if SiteSection_Entrance in ('contact','faqs','homepage',
							'manage-account','saved-items',
							'site-map')
			then SiteSection_Entrance = 'Other';

		if landingPagePath in ('oregon-southwest-washington-cardiac-care',
			'planning-for-next-normal-at-work',
			'choose-a-better-way-to-manage-costs',
			'controlling-drug-costs',
			'group-size',
			'understand-health-care-quality-ratings',
			'your-health-care-abcs',
			'reporting-that-measures-quality-and-value',
			'how-integrated-health-care-helps-keep-your-employees-healthier',
			'experience-kaiser-permanente-anywhere',
			'small-business-health-coverage-download',
			'telehealth-supports-employees-health-and-benefits-business'
			'washington-care-access','washington-mental-health-wellness')
		then SiteSection_Entrance = 'Landing Pages';

		if landingPagePath = 'respond.kaiserpermanente.org/emp_acq_sbu_nurture_co_ebookdownload'
			then landingPagePath = 'E-Book Download';
		if landingPagePath = 'respond.kaiserpermanente.org/emp_acq_sbu_nurture_co_ebookdownload_ty'
			then landingPagePath = 'E-Book Download Thank You';
		if find(landingPagePath,'respond.kaiserpermanente.org') 
			then SiteSection_Entrance = 'E-Book Download';

		if find(landingPagePath,'kp.kaiserpermanente.org/small-business/ca-da')>0
			then do;
				landingPagePath = 'Small Business CA Data Axel LP';
				SiteSection_Entrance = 'Landing Pages';
			end;
		if find(landingPagePath,'kp.kaiserpermanente.org/small-business/ca','i')>0 
			then do;
				landingPagePath = 'Small Business CA Paid Search LP';
				SiteSection_Entrance = 'Landing Pages';
			end;
		if find(landingPagePath,'kp.kaiserpermanente.org/small-business/nl','i')>0 
			then do;
				landingPagePath = 'Small Business National Paid Search LP';
				SiteSection_Entrance = 'Landing Pages';
			end;

		if find(landingPagePath,'success.kaiserpermanente.org')>0 
			then SiteSection_Entrance = 'Landing Pages';
		if find(landingPagePath,'virtualproducts.kaiserpermanente.org','i')>0 
			then SiteSection_Entrance = 'Landing Pages';
		if find(landingPagePath,'success.kaiserpermanente.org/exec','i') > 0
			then landingPagePath = 'B2B Landing Pages for Executives - RTW';
		if find(landingPagePath,'success.kaiserpermanente.org/hbo','i') > 0
			then landingPagePath = 'B2B Landing Pages for HR & Benefits - RTW';
		if find(landingPagePath,'success.kaiserpermanente.org/mhw-exec','i') > 0
			then landingPagePath = 'B2B Landing Pages for Executives - MHW';
		if find(landingPagePath,'success.kaiserpermanente.org/mhw-hbo','i') > 0
			then landingPagePath = 'B2B Landing Pages for HR & Benefits - MHW';
		if find(landingPagePath,'success.kaiserpermanente.org/vc-exec','i') > 0
			then landingPagePath = 'B2B Landing Pages for Executives - VC';
		if find(landingPagePath,'success.kaiserpermanente.org/vc-hbo','i') > 0
			then landingPagePath = 'B2B Landing Pages for HR & Benefits - VC';

		* Replace missing numeric w/ 0;
		 array change _numeric_;
	        do over change;
	            if change=. then change=0;
	        end;

	run;

	* check to make sure the page-level data overlaps with session-level data;
	proc import 
		datafile="&output_file_path/VI_Channel.csv"
		out=vi_campaign dbms=CSV;
	run;
	proc sort data=vi_campaign; by Session_ID; run;
	proc sort data=ga.vi_page_1of2_clean; by Session_ID; run;
	data ga.vi_page_1of2_clean pageonly sessiononly;
		merge ga.vi_page_1of2_clean(in=a)
			  vi_campaign(in=b);
		by Session_ID;
		where Date <= "09JUN2022"d;
		if a and b then output ga.vi_page_1of2_clean;
		else if a and not b then output pageonly;
		else if b and not a then output sessiononly;
	run;
	proc sql;
	select distinct sum(uniquePageviews) as pv, sum(sessions) as sess from ga.vi_page_1of2_clean;
	select distinct sum(uniquePageviews) as pv from pageonly;
	select distinct sum(sessions) as sess from sessiononly;
	quit;

	* Remove junk;
	data ga.vi_page_1of2_clean;
		set ga.vi_page_1of2_clean;
		if SiteSection_PagePath in ('admin','healthy.kaiserpermanente.org',
								'high-quality-care','search','v1') then delete;
		if SiteSection_Entrance in ('salesforce-testing','search') then delete;
	run;

	proc sql;
	create table ga.vi_page_1of2_clean as
		select distinct
			Date
		,	Session_ID
		,	SiteSection_Entrance
		,	landingPagePath
		,	SiteSection_PagePath
		,	PagePath
		,	sum(uniquePageviews) as uniquePageviews
		,	sum(timeOnPage_sec) as timeOnPage_sec
		from ga.vi_page_1of2_clean
		group by
			Date
		,	Session_ID
		,	SiteSection_Entrance
		,	landingPagePath
		,	SiteSection_PagePath
		,	PagePath;
	quit;

	proc delete data=ga.vi_page_1of2; run;

/* -------------------------------------------------------------------------------------------------*/
/*                                                                                                  */
/*                                                                                                  */
/*                                  Pull 2.2: Event Information                                     */
/*                                                                                                  */
/*                                                                                                  */
/* -------------------------------------------------------------------------------------------------*/

/* -------------------------------------------------------------------------------------------------*/
/*  Dimensions                                                                                      */
/* -------------------------------------------------------------------------------------------------*/

	%let i=1;
	%let var&i=          dimension2; *SessionId;
	%let informat_var&i= $50.; 
	%let format_var&i=   $50.; 

	%let i=%eval(&i+1);
	%let var&i=          landingPagePath; 
	%let informat_var&i= $200.; 
	%let format_var&i=   $200.; 

	%let i=%eval(&i+1);
	%let var&i=          PagePath; 
	%let informat_var&i= $200.; 
	%let format_var&i=   $200.; 

	%let i=%eval(&i+1);
	%let var&i=          SourceMedium;
	%let informat_var&i= $100.;
	%let format_var&i=   $100.;

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

	%GetGAData(chooseSegment=&BWSessions,
	    	    chooseView=Default,
				addl_filters=,
				level=day,
				StartDate=06APR2022,
				EndDate=09JUN2022,
				output_file_path=&output_file_path,
				output_file_name=VI_page_2of2);

	data ga.vi_page_2of2_clean;
		set ga.vi_page_2of2;

		rename dimension2 = Session_ID;

		* Remove Optimizely tag and VI tag;
		if eventCategory in ('Visitor Intelligence','Optimizely','undefined') then delete;

		* Remove records that are not on better way;
		if find(PagePath,'business.kaiserpermanente.org')=0 and find(PagePath,'respond.kaiserpermanente.org')=0
			then delete;

		* Remove test sources;
		if find(SourceMedium,'wrike.com')>0 
		or find(SourceMedium,'kpnationalconsumersales--kpdev1--c.documentforce.c')>0 
		or find(SourceMedium,'wiki.kp.org')>0 
		or find(SourceMedium,'sp-cloud.kp.org')>0 
		or find(SourceMedium,'kp.my.salesforce.com')>0 
		or find(SourceMedium,'basecamp.com')>0 
		or find(SourceMedium,'app.crazyegg.com')>0 
		or find(SourceMedium,'account-preview.kp.org')>0 
		or find(SourceMedium,'app.marinsoftware.com')>0 
		or find(SourceMedium,'author-sanbox-afd.kp.org')>0 
		or find(SourceMedium,'bconnected.connextion.co')>0 
		or find(SourceMedium,'comms01.kp.org')>0
		or find(SourceMedium,'kp-aws-cloud.org','i') > 0
		or find(SourceMedium,'tagassistant.google.com','i') > 0 
		or length(SourceMedium) > 50 
		or find(SourceMedium,'c5c') > 0 
		or find(SourceMedium,'test','i') > 0 
	    or find(SourceMedium,'preview.pixel.ad','i') > 0 
		or find(SourceMedium,'leadboldly.crosbydev.net','i') > 0 
		or find(SourceMedium,'officeapps.live.com','i') > 0  
	    or find(SourceMedium,'wabusinessdev.wpengine.com','i') > 0 
		or find(SourceMedium,'dev-','i')>0 
		or find(SourceMedium,'kpwanl') > 0 
		or find(SourceMedium,'preview.dpaprod') > 0
		or find(SourceMedium,'optimizely') > 0
		or find(SourceMedium,'sp.kp.org') > 0
		or find(SourceMedium,'localhost') > 0 
		or find(SourceMedium,'pathroutes') > 0
		or find(SourceMedium,'addotnet') > 0
		or find(SourceMedium,'searchiq') > 0
		or prxmatch("/\d\d\d\.\d\.\d\.\d:\d{4}/",SourceMedium) > 0 
		then delete;

		drop SourceMedium;

		/* -------------------------------------------------------------------------------------------------*/
		/*  PagePath cleaning.                                                                              */
		/* -------------------------------------------------------------------------------------------------*/

		PagePath = lowcase(compress(tranwrd(PagePath,'business.kaiserpermanente.org/',''),''));
		if find(PagePath,'?') > 0 then PagePath = substr(PagePath,1,index(PagePath,'?')-1);
		if find(PagePath,'WT.mc_id') > 0 then PagePath = substr(PagePath,1,index(PagePath,'WT.mc_id')-1);
		if find(PagePath,'#') > 0 then PagePath = substr(PagePath,1,index(PagePath,'#')-1);
		if substr(reverse(strip(PagePath)),1,1) = '/' then PagePath = substr(strip(PagePath),1,length(strip(PagePath))-1);
	
		SiteSection_PagePath = scan(PagePath,1,'/');

		if PagePath = '' or find(PagePath,'?') > 0 or SiteSection_PagePath = 'page' then PagePath = 'homepage';

		SiteSection_PagePath = scan(PagePath,1,'/');

		if find(PagePath,'thrive/resource-center') > 0 or SiteSection_PagePath = 'wp-content' then SiteSection_PagePath = 'Thrive At Work: Resource Center';
		if SiteSection_PagePath = 'thrive' then SiteSection_PagePath = 'Thrive At Work';
		if SiteSection_PagePath = 'health-plan' then SiteSection_PagePath = 'Health Plans';
		if SiteSection_PagePath = 'kp-difference' then SiteSection_PagePath = 'The KP Difference';
		if SiteSection_PagePath = 'insights' then SiteSection_PagePath = 'Insights';
		if SiteSection_PagePath in ('contact','faqs','homepage',
							'manage-account','saved-items',
							'site-map')
			then SiteSection_PagePath = 'Other';

		if PagePath in ('oregon-southwest-washington-cardiac-care',
			'planning-for-next-normal-at-work',
			'choose-a-better-way-to-manage-costs',
			'controlling-drug-costs',
			'group-size',
			'understand-health-care-quality-ratings',
			'your-health-care-abcs',
			'reporting-that-measures-quality-and-value',
			'how-integrated-health-care-helps-keep-your-employees-healthier',
			'experience-kaiser-permanente-anywhere',
			'small-business-health-coverage-download',
			'telehealth-supports-employees-health-and-benefits-business'
			'washington-care-access','washington-mental-health-wellness')
		then SiteSection_PagePath = 'Landing Pages';

		if PagePath = 'respond.kaiserpermanente.org/emp_acq_sbu_nurture_co_ebookdownload'
			then PagePath = 'E-Book Download';
		if PagePath = 'respond.kaiserpermanente.org/emp_acq_sbu_nurture_co_ebookdownload_ty'
			then PagePath = 'E-Book Download Thank You';
		if find(PagePath,'respond.kaiserpermanente.org') 
			then SiteSection_PagePath = 'E-Book Download';

		if SiteSection_PagePath = PagePath then SiteSection_PagePath = 'Other';

		/* -------------------------------------------------------------------------------------------------*/
		/*  landingPagePath cleaning.                                                                       */
		/* -------------------------------------------------------------------------------------------------*/

		landingPagePath = lowcase(compress(tranwrd(landingPagePath,'business.kaiserpermanente.org/',''),''));
		if find(landingPagePath,'?') > 0 then landingPagePath = substr(landingPagePath,1,index(landingPagePath,'?')-1);
		if find(landingPagePath,'WT.mc_id') > 0 then landingPagePath = substr(landingPagePath,1,index(landingPagePath,'WT.mc_id')-1);
		if find(landingPagePath,'#') > 0 then landingPagePath = substr(landingPagePath,1,index(landingPagePath,'#')-1);
		if substr(reverse(strip(landingPagePath)),1,1) = '/' then landingPagePath = substr(strip(landingPagePath),1,length(strip(landingPagePath))-1);
	
		SiteSection_Entrance = scan(landingPagePath,1,'/');

		if landingPagePath = '' or find(landingPagePath,'?') > 0 or SiteSection_Entrance = 'page' then landingPagePath = 'homepage';

		SiteSection_Entrance = scan(landingPagePath,1,'/');

		if find(landingPagePath,'thrive/resource-center') > 0 or SiteSection_Entrance = 'wp-content' then SiteSection_Entrance = 'Thrive At Work: Resource Center';
		if SiteSection_Entrance = 'thrive' then SiteSection_Entrance = 'Thrive At Work';
		if SiteSection_Entrance = 'health-plan' then SiteSection_Entrance = 'Health Plans';
		if SiteSection_Entrance = 'kp-difference' then SiteSection_Entrance = 'The KP Difference';
		if SiteSection_Entrance = 'insights' then SiteSection_Entrance = 'Insights';
		if SiteSection_Entrance in ('contact','faqs','homepage',
							'manage-account','saved-items',
							'site-map')
			then SiteSection_Entrance = 'Other';

		if landingPagePath in ('oregon-southwest-washington-cardiac-care',
			'planning-for-next-normal-at-work',
			'choose-a-better-way-to-manage-costs',
			'controlling-drug-costs',
			'group-size',
			'understand-health-care-quality-ratings',
			'your-health-care-abcs',
			'reporting-that-measures-quality-and-value',
			'how-integrated-health-care-helps-keep-your-employees-healthier',
			'experience-kaiser-permanente-anywhere',
			'small-business-health-coverage-download',
			'telehealth-supports-employees-health-and-benefits-business'
			'washington-care-access','washington-mental-health-wellness')
		then SiteSection_Entrance = 'Landing Pages';

		if landingPagePath = 'respond.kaiserpermanente.org/emp_acq_sbu_nurture_co_ebookdownload'
			then landingPagePath = 'E-Book Download';
		if landingPagePath = 'respond.kaiserpermanente.org/emp_acq_sbu_nurture_co_ebookdownload_ty'
			then landingPagePath = 'E-Book Download Thank You';
		if find(landingPagePath,'respond.kaiserpermanente.org') 
			then SiteSection_Entrance = 'E-Book Download';

		if find(landingPagePath,'kp.kaiserpermanente.org/small-business/ca-da')>0
			then do;
				landingPagePath = 'Small Business CA Data Axel LP';
				SiteSection_Entrance = 'Landing Pages';
			end;
		if find(landingPagePath,'kp.kaiserpermanente.org/small-business/ca','i')>0 
			then do;
				landingPagePath = 'Small Business CA Paid Search LP';
				SiteSection_Entrance = 'Landing Pages';
			end;
		if find(landingPagePath,'kp.kaiserpermanente.org/small-business/nl','i')>0 
			then do;
				landingPagePath = 'Small Business National Paid Search LP';
				SiteSection_Entrance = 'Landing Pages';
			end;

		if find(landingPagePath,'success.kaiserpermanente.org')>0 
			then SiteSection_Entrance = 'Landing Pages';
		if find(landingPagePath,'virtualproducts.kaiserpermanente.org','i')>0 
			then SiteSection_Entrance = 'Landing Pages';
		if find(landingPagePath,'success.kaiserpermanente.org/exec','i') > 0
			then landingPagePath = 'B2B Landing Pages for Executives - RTW';
		if find(landingPagePath,'success.kaiserpermanente.org/hbo','i') > 0
			then landingPagePath = 'B2B Landing Pages for HR & Benefits - RTW';
		if find(landingPagePath,'success.kaiserpermanente.org/mhw-exec','i') > 0
			then landingPagePath = 'B2B Landing Pages for Executives - MHW';
		if find(landingPagePath,'success.kaiserpermanente.org/mhw-hbo','i') > 0
			then landingPagePath = 'B2B Landing Pages for HR & Benefits - MHW';
		if find(landingPagePath,'success.kaiserpermanente.org/vc-exec','i') > 0
			then landingPagePath = 'B2B Landing Pages for Executives - VC';
		if find(landingPagePath,'success.kaiserpermanente.org/vc-hbo','i') > 0
			then landingPagePath = 'B2B Landing Pages for HR & Benefits - VC';

		* Replace missing numeric w/ 0;
		 array change _numeric_;
	        do over change;
	            if change=. then change=0;
	        end;

	run;

	* Remove junk;
	data ga.vi_page_2of2_clean;
		set ga.vi_page_2of2_clean;
		if SiteSection_PagePath in ('admin','healthy.kaiserpermanente.org',
								'high-quality-care','search','v1') then delete;
		if SiteSection_Entrance in ('salesforce-testing','search') then delete;
	run;

	proc sql;
	create table ga.vi_page_2of2_clean as
		select distinct
			*
		from ga.vi_page_2of2_clean
		where Session_Id in (select Session_ID from ga.vi_page_1of2_clean);
	quit;

	proc sql;
	create table ga.vi_page_2of2_rollup as
		select distinct
			Date
		,	Session_ID
		,	landingPagePath
		,	PagePath
		,	sum(case when eventCategory="Shop" then uniqueEvents else 0 end) as ShopActions_Unique
		,	sum(case when eventCategory="Learn" then uniqueEvents else 0 end) as LearnActions_Unique
		,	sum(case when eventCategory="Convert" then uniqueEvents else 0 end) as ConvertActions_Unique
		,	sum(case when eventCategory="Share" then uniqueEvents else 0 end) as ShareActions_Unique
		,	sum(case when eventCategory="Form Abandonment" then uniqueEvents else 0 end) as LeadStarts_Unique
		from ga.vi_page_2of2_clean
		group by
			Date
		,	Session_ID
		,	landingPagePath
		,	PagePath;
	quit;

	proc sort data=ga.vi_page_1of2_clean; by Date Session_ID landingPagePath PagePath; run;
	proc sort data=ga.vi_page_2of2_rollup; by Date Session_ID landingPagePath PagePath; run;
	data ga.vi_page_final;
		merge ga.vi_page_1of2_clean(in=a)
			  ga.vi_page_2of2_rollup(in=b);
		by Date Session_ID landingPagePath PagePath;
		if a then output;
	run;

	proc export 
		data=ga.vi_page_final
		outfile="&output_file_path/VI_Pages.csv"
		dbms=CSV replace;
	run;
	proc export 
		data=ga.vi_page_2of2_clean
		outfile="&output_file_path/VI_Clicks.csv"
		dbms=CSV replace;
	run;

	proc delete data=ga.vi_page_1of2_clean; run;
	proc delete data=ga.vi_page_2of2; run;
	proc delete data=ga.vi_page_2of2_clean; run;
	proc delete data=ga.vi_page_2of2_rollup; run;
	proc delete data=ga.vi_page_final; run;

/* -------------------------------------------------------------------------------------------------*/
/*                                                                                                  */
/*                                                                                                  */
/*                                      Pull 3.1: Visit Information                                 */
/*                                                                                                  */
/*                                                                                                  */
/* -------------------------------------------------------------------------------------------------*/

/* -------------------------------------------------------------------------------------------------*/
/*  Dimensions                                                                                      */
/* -------------------------------------------------------------------------------------------------*/

	%let i=1;
	%let var&i=          dimension5; *Duns ID;
	%let informat_var&i= $50.;
	%let format_var&i=   $50.;

	%let i=%eval(&i+1);
	%let var&i=          dimension1; *UserId;
	%let informat_var&i= $50.; 
	%let format_var&i=   $50.; 

	%let i=%eval(&i+1);
	%let var&i=          dimension2; *SessionId;
	%let informat_var&i= $50.; 
	%let format_var&i=   $50.; 

	%let i=%eval(&i+1);
	%let var&i=          userType; 
	%let informat_var&i= $25.; 
	%let format_var&i=   $25.; 

	%let i=%eval(&i+1);
	%let var&i=          deviceCategory; 
	%let informat_var&i= $25.; 
	%let format_var&i=   $25.; 

	%let i=%eval(&i+1);
	%let var&i=          Metro; 
	%let informat_var&i= $150.; 
	%let format_var&i=   $150.; 

	%let i=%eval(&i+1);
	%let var&i=          Source; 
	%let informat_var&i= $50.; 
	%let format_var&i=   $50.; 

	%let number_of_dimensions=&i;

/* -------------------------------------------------------------------------------------------------*/
/*  Metrics                                                                                         */
/* -------------------------------------------------------------------------------------------------*/

	%let i=%eval(&i+1);
	%let var&i=          sessions;
	%let informat_var&i= 8.;
	%let format_var&i=   8.;

	%let i=%eval(&i+1);
	%let var&i=          Users;
	%let informat_var&i= 8.;
	%let format_var&i=   8.;

	%let number_of_metrics=%eval(&i-&number_of_dimensions);

/* -------------------------------------------------------------------------------------------------*/
/*  Execute.                                                                                        */
/* -------------------------------------------------------------------------------------------------*/

	%GetGAData(chooseSegment=&BWSessions,
				chooseView=Default,
				addl_filters=,
				level=day,
				StartDate=06APR2022,
				EndDate=09JUN2022,
				output_file_path=&output_file_path,
				output_file_name=VI_Visit);

/* -------------------------------------------------------------------------------------------------*/
/*                                                                                                  */
/*                                                                                                  */
/*                                    Pull 3.2: Visit Information                                   */
/*                                                                                                  */
/*                                                                                                  */
/* -------------------------------------------------------------------------------------------------*/

/* -------------------------------------------------------------------------------------------------*/
/*  Dimensions                                                                                      */
/* -------------------------------------------------------------------------------------------------*/

	%let i=1;
	%let var&i=          dimension1; *UserId;
	%let informat_var&i= $50.; 
	%let format_var&i=   $50.; 

	%let i=%eval(&i+1);
	%let var&i=          dimension2; *SessionId;
	%let informat_var&i= $50.; 
	%let format_var&i=   $50.; 

	%let i=%eval(&i+1);
	%let var&i=          userType; 
	%let informat_var&i= $25.; 
	%let format_var&i=   $25.; 

	%let i=%eval(&i+1);
	%let var&i=          deviceCategory; 
	%let informat_var&i= $25.; 
	%let format_var&i=   $25.; 

	%let i=%eval(&i+1);
	%let var&i=          Metro; 
	%let informat_var&i= $150.; 
	%let format_var&i=   $150.; 

	%let i=%eval(&i+1);
	%let var&i=          Source; 
	%let informat_var&i= $50.; 
	%let format_var&i=   $50.; 

	%let number_of_dimensions=&i;

/* -------------------------------------------------------------------------------------------------*/
/*  Metrics                                                                                         */
/* -------------------------------------------------------------------------------------------------*/

	%let i=%eval(&i+1);
	%let var&i=          sessions;
	%let informat_var&i= 8.;
	%let format_var&i=   8.;

	%let i=%eval(&i+1);
	%let var&i=          Users;
	%let informat_var&i= 8.;
	%let format_var&i=   8.;

	%let number_of_metrics=%eval(&i-&number_of_dimensions);

/* -------------------------------------------------------------------------------------------------*/
/*  Execute.                                                                                        */
/* -------------------------------------------------------------------------------------------------*/

	%GetGAData(chooseSegment=&BWSessions,
				chooseView=Default,
				addl_filters=,
				level=day,
				StartDate=06APR2022,
				EndDate=09JUN2022,
				output_file_path=&output_file_path,
				output_file_name=VI_Visit_all);

/* -------------------------------------------------------------------------------------------------*/
/*                                                                                                  */
/*                                                                                                  */
/*                                 Pull 3.3: Duns User Information                                  */
/*                                                                                                  */
/*                                                                                                  */
/* -------------------------------------------------------------------------------------------------*/

/* -------------------------------------------------------------------------------------------------*/
/*  Dimensions                                                                                      */
/* -------------------------------------------------------------------------------------------------*/

	%let i=1;
	%let var&i=          dimension5; *Duns ID;
	%let informat_var&i= $50.;
	%let format_var&i=   $50.;

	%let i=%eval(&i+1);
	%let var&i=          dimension1; *userID;
	%let informat_var&i= $50.; 
	%let format_var&i=   $50.; 

	%let i=%eval(&i+1);
	%let var&i=          dimension19; *job_concat;
	%let informat_var&i= $100.; 
	%let format_var&i=   $100.; 

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

	%GetGAData(chooseSegment=&BWSessions,
				chooseView=Default,
				addl_filters=,
				level=day,
				StartDate=06APR2022,
				EndDate=09JUN2022,
				output_file_path=&output_file_path,
				output_file_name=VI_Visit_duns);

	proc import 
		datafile="&output_file_path/VI_Channel.csv"
		out=vi_campaign dbms=CSV;
	run;

	proc import
		datafile="&output_file_path/LOOKUP Metro_KP Region.xlsx"
		out=lookup_kpregion
		dbms=xlsx replace;
	run;

	proc sql;
		create table ga.vi_visit_clean as
		select distinct
			x.Date
		,	x.dimension5 as DUNS_Number
		,	x.dimension1 as User_ID
		,	x.dimension2 as Session_ID
		,	x.UserType
		,	x.deviceCategory
		,	l.State
		,	l.Region
		,	l.SubRegion
		,	case when scan(x.Source,2,'-') in 
						('ca','ga','co','hi','mas','nw','wa',
						'canc','casc','ncal','scal','clrd','grga','pcnw','kpwa')
						then scan(x.Source,2,'-') else '' end as Source_Region
		,	strip(scan(tranwrd(y.dimension19,'undefined',''),1,'|')) as DUNS_JobFunction length 75
		,	strip(scan(tranwrd(y.dimension19,'undefined',''),2,'|')) as DUNS_JobSeniority length 75
		,	1 as VI_Flag
		,	x.Sessions
		,	x.Users
		from ga.vi_visit x
		left join ga.vi_visit_duns y
			on x.dimension1 = y.dimension1
		left join lookup_kpregion l
			on x.Metro=l.Metro

			union

		select distinct
			Date
		,	''
		,	dimension1
		,	dimension2
		,	UserType
		,	deviceCategory
		,	l.State
		,	l.Region
		,	l.SubRegion
		,	case when scan(Source,2,'-') in 
				('na','ca','ga','co','hi','mas','nw','wa',
				'canc','casc','ncal','scal','clrd','grga','pcnw','kpwa')
				then scan(Source,2,'-') else '' end as Source_Region
		,	''
		,	''
		,	0
		,	sessions
		,	Users
		from ga.vi_visit_all v
		left join lookup_kpregion l
			on v.Metro=l.Metro
		where dimension2 not in (select dimension2 from ga.vi_visit);
	quit;

	proc sql;
	create table ga.vi_visit_clean as
		select distinct
			*
		from ga.vi_visit_clean
		where Session_Id in (select Session_ID from vi_campaign);
	quit;

	data ga.vi_visit_clean;
		set ga.vi_visit_clean;

		Source_Region = upcase(Source_Region);
		if Source_Region = 'CLRD' then Source_Region = 'CO';
		else if Source_Region = 'GRGA' then Source_Region = 'GA';
		else if Source_Region in ('CANC','CASC','NCAL','SCAL') then Source_Region = 'CA';
		else if Source_Region = 'NW' then Source_Region = 'PCNW';
		else if Source_Region = 'WA' then Source_Region = 'KPWA';
		
		if Region = 'NW' then Region = 'PCNW';
		else if Region = 'WA' then Region = 'KPWA';

		if Source_Region in ('CA','CO','GA','HI','KPWA','MAS','PCNW') 
			and Source_Region ne Region then do;
			Region = Source_Region;
			if Source_Region in ('CA','CO','GA','HI','KPWA') then State = Source_Region;
				else State = 'UN';
			if State = 'KPWA' then State = 'WA';
			end;

		if Region = 'NA' then Region = 'UN';
		if State = 'NA' then State = 'UN';
		if Region = '' then do;
			State = 'UN';
			Region = 'UN';
			end;

		drop Source_Region SubRegion;

	run;

	proc export 
		data=ga.vi_visit_clean
		outfile="&output_file_path/VI_Visit.csv"
		dbms=CSV replace;
	run;

	proc delete data=ga.vi_visit; run;
	proc delete data=ga.vi_visit_all; run;
	proc delete data=ga.vi_visit_duns; run;
	proc delete data=ga.vi_visit_clean; run;
	proc delete data=ga.vi_visit_final; run;

/* -------------------------------------------------------------------------------------------------*/
/*                                                                                                  */
/*                                                                                                  */
/*                                   Pull 4.1: Duns Information                                     */
/*                                                                                                  */
/*                                                                                                  */
/* -------------------------------------------------------------------------------------------------*/

/* -------------------------------------------------------------------------------------------------*/
/*  Dimensions                                                                                      */
/* -------------------------------------------------------------------------------------------------*/

	%let i=1;
	%let var&i=          dimension5; *Duns ID;
	%let informat_var&i= $50.;
	%let format_var&i=   $50.;

	%let i=%eval(&i+1);
	%let var&i=          dimension6; *Parent Duns ID;
	%let informat_var&i= $50.; 
	%let format_var&i=   $50.; 

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

	%GetGAData(chooseSegment=&BWSessions,
				chooseView=Default,
				addl_filters=,
				level=day,
				StartDate=06APR2022,
				EndDate=09JUN2022,
				output_file_path=&output_file_path,
				output_file_name=VI_DunsInfo_1of3);

/* -------------------------------------------------------------------------------------------------*/
/*                                                                                                  */
/*                                                                                                  */
/*                                   Pull 4.2: Duns Information                                     */
/*                                                                                                  */
/*                                                                                                  */
/* -------------------------------------------------------------------------------------------------*/

/* -------------------------------------------------------------------------------------------------*/
/*  Dimensions                                                                                      */
/* -------------------------------------------------------------------------------------------------*/

	%let i=1;
	%let var&i=          dimension5; *Duns ID;
	%let informat_var&i= $50.;
	%let format_var&i=   $50.;

	%let i=%eval(&i+1);
	%let var&i=          dimension13; *Annual sales|Bin;
	%let informat_var&i= $100.; 
	%let format_var&i=   $100.; 

	%let i=%eval(&i+1);
	%let var&i=          dimension14; *Site Employees;
	%let informat_var&i= $200.; 
	%let format_var&i=   $200.; 

	%let i=%eval(&i+1);
	%let var&i=          dimension15; *Total employees;
	%let informat_var&i= $200.; 
	%let format_var&i=   $200.; 

	%let i=%eval(&i+1);
	%let var&i=          dimension16; *wallet_credit_concat;
	%let informat_var&i= $100.; 
	%let format_var&i=   $100.; 

	%let i=%eval(&i+1);
	%let var&i=          dimension17; *propensity_concat;
	%let informat_var&i= $500.; 
	%let format_var&i=   $500.; 

	%let i=%eval(&i+1);
	%let var&i=          dimension18; *delinquency_marketability_concat;
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

	%GetGAData(chooseSegment=&BWSessions,
				chooseView=Default,
				addl_filters=,
				level=day,
				StartDate=06APR2022,
				EndDate=09JUN2022,
				output_file_path=&output_file_path,
				output_file_name=VI_DunsInfo_2of3);

/* -------------------------------------------------------------------------------------------------*/
/*                                                                                                  */
/*                                                                                                  */
/*                                   Pull 4.3: Duns Information                                     */
/*                                                                                                  */
/*                                                                                                  */
/* -------------------------------------------------------------------------------------------------*/

/* -------------------------------------------------------------------------------------------------*/
/*  Dimensions                                                                                      */
/* -------------------------------------------------------------------------------------------------*/

	%let i=1;
	%let var&i=          dimension5; *Duns ID;
	%let informat_var&i= $50.;
	%let format_var&i=   $50.;

	%let i=%eval(&i+1);
	%let var&i=          dimension7; *CompanyName;
	%let informat_var&i= $100.; 
	%let format_var&i=   $100.; 

	%let i=%eval(&i+1);
	%let var&i=          dimension11; *NAICS;
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

	%GetGAData(chooseSegment=&BWSessions,
				chooseView=Default,
				addl_filters=,
				level=day,
				StartDate=06APR2022,
				EndDate=09JUN2022,
				output_file_path=&output_file_path,
				output_file_name=VI_DunsInfo_4of3);

/* -------------------------------------------------------------------------------------------------*/
/*                                                                                                  */
/*                                                                                                  */
/*                                   Pull 4.4: Duns Information                                     */
/*                                                                                                  */
/*                                                                                                  */
/* -------------------------------------------------------------------------------------------------*/

/* -------------------------------------------------------------------------------------------------*/
/*  Dimensions                                                                                      */
/* -------------------------------------------------------------------------------------------------*/

	%let i=1;
	%let var&i=          dimension5; *Duns ID;
	%let informat_var&i= $50.;
	%let format_var&i=   $50.;

	%let i=%eval(&i+1);
	%let var&i=          dimension8; *CompanyAddr;
	%let informat_var&i= $200.; 
	%let format_var&i=   $200.; 

	%let i=%eval(&i+1);
	%let var&i=          dimension9; *CompanyCityStateZip;
	%let informat_var&i= $200.; 
	%let format_var&i=   $200.; 

	%let i=%eval(&i+1);
	%let var&i=          dimension10; *MSA;
	%let informat_var&i= $100.; 
	%let format_var&i=   $100.; 

	%let i=%eval(&i+1);
	%let var&i=          dimension20; *phone;
	%let informat_var&i= $200.; 
	%let format_var&i=   $200.; 

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

	%GetGAData(chooseSegment=&BWSessions,
				chooseView=Default,
				addl_filters=,
				level=day,
				StartDate=06APR2022,
				EndDate=09JUN2022,
				output_file_path=&output_file_path,
				output_file_name=VI_DunsInfo_4of3);

* remove date, roll up sessions, rename;
	* clean all fields;
	* combine into 1 set by dunsID;

	proc sort data=ga.vi_dunsinfo_1of3; by dimension5 date; run;
	proc sort data=ga.vi_dunsinfo_2of3; by dimension5 date; run;
	proc sort data=ga.vi_dunsinfo_3of3; by dimension5 date; run;
	proc sort data=ga.vi_dunsinfo_4of3; by dimension5 date; run;
	data ga.vi_duns_combined;
		merge ga.vi_dunsinfo_1of3(in=a)
			  ga.vi_dunsinfo_2of3(in=b)
			  ga.vi_dunsinfo_3of3(in=c)
			  ga.vi_dunsinfo_4of3(in=d)
			  ga.vi_dunsinfo_5of3(in=e)
				;
		by dimension5 date;

		where Date >= "06APR2022"d;
		drop dimension19;

		dimension13 = tranwrd(dimension13,'0 | 0',' | ');
		dimension13 = tranwrd(dimension13,'gtr','More than ');
		dimension13 = tranwrd(dimension13,'ltreq','Less than ');
		if find(dimension14,'Micro')>0 then dimension14 = catx(' | ',scan(dimension14,1,' '),scan(dimension14,2,'|'));
		if find(dimension15,'Micro')>0 then dimension15 = catx(' | ',scan(dimension15,1,' '),scan(dimension15,2,'|'));
		dimension14 = tranwrd(dimension14,'0 | 0',' | ');
		dimension15 = tranwrd(dimension15,'0 | 0',' | ');
		dimension16 = tranwrd(dimension16,'null | null',' | ');
		dimension17 = tranwrd(dimension17,'null','');
		dimension17 = tranwrd(dimension17,'undefined','');
		dimension18 = tranwrd(dimension18,'NULL','');
		dimension18 = tranwrd(dimension18,'null','');
	run;

	proc sql;
	create table ga.vi_dunsinfo_final as
	select distinct
		dimension5 as DUNS_Number length 20
	,	dimension6 as DUNS_Parent_Number length 20
	,	dimension7 as DUNS_CompanyName length 200
	,	dimension8 as DUNS_AddrLine1 length 200
	,	strip(scan(dimension9,1,'|')) as DUNS_AddrCity length 75
	,	strip(scan(dimension9,2,'|')) as DUNS_AddrState length 5
	,	strip(scan(dimension9,3,'|')) as DUNS_AddrZip length 5
	,	tranwrd(dimension10,',',' ') as DUNS_MSA length 200
	,	strip(scan(dimension11,1,'|')) as DUNS_NAICS_Num length 6
	,	strip(scan(dimension11,2,'|')) as DUNS_NAICS_Desc length 300
	,	strip(scan(dimension13,1,'|')) as DUNS_AnnaulSales_Bin length 20
	,	input(strip(scan(dimension13,2,'|')),int15.) as DUNS_AnnaulSales_Num
	,	strip(scan(dimension14,1,'|')) as DUNS_EmployeesSite_Bin length 20
	,	input(strip(scan(dimension14,2,'|')),int15.) as DUNS_EmployeesSite_Num
	,	strip(scan(dimension15,1,'|')) as DUNS_EmployeesTotal_Bin length 20
	,	input(strip(scan(dimension15,2,'|')),int15.) as DUNS_EmployeesTotal_Num
	,	strip(scan(dimension16,1,'|')) as DUNS_WalletSize length 2
	,	strip(scan(dimension16,1,'|')) as DUNS_CreditOfferRspnsve length 2
	,	strip(scan(dimension17,1,'|')) as DUNS_PropensityLoan 
	,	strip(scan(dimension17,2,'|')) as DUNS_PropensityLease
	,	strip(scan(dimension17,3,'|')) as DUNS_PropensityLOC
	,	input(strip(scan(dimension18,1,'|')),percent6.1) as DUNS_Delinquency format percent6.1
	,	strip(scan(dimension18,2,'|')) as DUNS_Marketability length 25
	,	dimension20 as DUNS_CompanyPhone length 10
	,	sum(sessions) as Sessions
	,	max(Date) as Data_Update_Date format mmddyy10.
	from ga.vi_duns_combined
	group by 
		dimension5
	,	dimension6
	,	dimension7
	,	dimension8
	,	strip(scan(dimension9,1,'|'))
	,	strip(scan(dimension9,2,'|'))
	,	strip(scan(dimension9,3,'|'))
	,	tranwrd(dimension10,',',' ')
	,	strip(scan(dimension11,1,'|'))
	,	strip(scan(dimension11,2,'|'))
	,	strip(scan(dimension13,1,'|'))
	,	strip(scan(dimension13,2,'|'))
	,	strip(scan(dimension14,1,'|'))
	,	strip(scan(dimension14,2,'|'))
	,	strip(scan(dimension15,1,'|'))
	,	strip(scan(dimension15,2,'|'))
	,	strip(scan(dimension16,1,'|'))
	,	strip(scan(dimension16,1,'|'))
	,	strip(scan(dimension17,1,'|'))
	,	strip(scan(dimension17,2,'|'))
	,	strip(scan(dimension17,3,'|'))
	,	strip(scan(dimension18,1,'|'))
	,	strip(scan(dimension18,2,'|'))
	,	dimension20
	order by DUNS_Number, Data_Update_Date desc;
	quit;

	* Only keep most up-to-date information;
	data ga.vi_dunsinfo_final(drop=Record Data_Update_Date);
		set ga.vi_dunsinfo_final;
		by DUNS_Number descending Data_Update_Date;

		if first.DUNS_Number then Record = 1;
			else Record+1;

		if Record=1 then output;
	run;

	proc export 
		data=ga.vi_dunsinfo_final
		outfile="&output_file_path/VI_Demographics.csv"
		dbms=CSV replace; 
	run;
	proc export 
		data=ga.vi_dunsinfo_final
		outfile="&output_file_path/VI_Demographics.txt"
		dbms=dlm replace; delimiter="|";
	run;

	proc delete data=ga.vi_dunsinfo_1of3; run;
	proc delete data=ga.vi_dunsinfo_2of3; run;
	proc delete data=ga.vi_dunsinfo_3of3; run;
	proc delete data=ga.vi_dunsinfo_4of3; run;
	proc delete data=ga.vi_duns_combined; run;
	proc delete data=ga.vi_dunsinfo_final; run;