/****************************************************************************************************/
/*  Program Name:       Get_LinkedIn_Data_Weekly.sas                                                */
/*                                                                                                  */
/*  Date Created:       Jun 9, 2020                                                                 */
/*                                                                                                  */
/*  Created By:         Elle Haynes                                                                 */
/*                                                                                                  */
/*  Purpose:            Compiles daily data from LinkedIn for the B2B Dashboard.                    */
/*                                                                                                  */
/*  Inputs:             Manual extracts from Campaign Manager downloaded to folder.                 */
/*                                                                                                  */
/* -------------------------------------------------------------------------------------------------*/	
/*  Notes:              Update to run on API.                                                       */
/* -------------------------------------------------------------------------------------------------*/
/*  Date Modified:                                                                                  */
/*  Modified by:                                                                                    */
/*  Description:                                                                                    */
/****************************************************************************************************/
	options mprint mlogic symbolgen;
	filename old_log "/gpfsFS2/sasdata/nfs/ndc_grid/po_imca_digital/EHaynes/B2B Dashboard Data Processing/LinkedIn/LOG Get_LinkedIn_Data_Weekly.txt";
	data _null_; rc=fdelete("old_log"); put rc=; run;
	proc printto log="/gpfsFS2/sasdata/nfs/ndc_grid/po_imca_digital/EHaynes/B2B Dashboard Data Processing/LinkedIn/LOG Get_LinkedIn_Data_Weekly.txt"; run;

	* Raw Data Download Folder;
	%let raw_file_path = /gpfsFS2/sasdata/nfs/ndc_grid/po_imca_digital/EHaynes/B2B Dashboard Data Processing/_Raw Data Downloads;
	libname import "&raw_file_path";

	%let input_files = /gpfsFS2/sasdata/nfs/ndc_grid/po_imca_digital/EHaynes/B2B Dashboard Data Processing/LinkedIn;
	libname linkedin "&input_files";

	%let output_files = /gpfsFS2/sasdata/adhoc/po/imca/product/B2B;
	libname final "&output_files";
	libname archive "&output_files/Archive"; 

	%let production_path= /gpfsFS2/sasdata/nfs/ndc_grid/po_imca_product/B2B;
	libname prod "&production_path";

	%let dt=.; *"11jan2021"d; *leave empty unless running manually;
	%let N=0; *initialize, number of new observations from imported (value dem) dataset;
	%let nfiles=0; *initialize, the number of xlsx files in the input_files directory;
	%let Nnew=0; *initialize, the number of new records to be processed.;
	%let cancel=; *initialize, the flag to cancel the process.;
	%let validate1=1; %let validate2=0;
	%let valid_spend=1; %let spend=0;
	%let valid_end=1; %let eng=0;
	%let valid_visit=1; %let visit=0;

/* -------------------------------------------------------------------------------------------------*/
/*  Load stored macros.                                                                             */
/* -------------------------------------------------------------------------------------------------*/

	%include "/gpfsFS2/sasdata/adhoc/po/imca/digital/code/Access/SAS_Macro_ListFiles.sas"; 
	%include "/gpfsFS2/sasdata/adhoc/po/imca/digital/code/Access/SAS_Macro_CheckForData.sas"; 
	%include "/gpfsFS2/sasdata/adhoc/po/imca/digital/code/Access/SAS_Macro_Email.sas"; 

/* -------------------------------------------------------------------------------------------------*/
/*                                                                                                  */
/*                                                                                                  */
/*                                         Check for new file                                       */
/*                                                                                                  */
/*                                                                                                  */
/* -------------------------------------------------------------------------------------------------*/

	*Create the list of files, in this case all XLSX files;
	%list_files(&raw_file_path.,ext=xlsx);

	%let nfiles_default=0; %let nfiles_conver=0; *initialize;
	%let filename_default=0; %let filename_conver=0; *initialize;

	proc sql ;

		title 'Default metrics';
		select 
			count(*)
		,	the_name 
		into :nfiles_default,
		     :filename_default separated by '|'
		from list
		where find(the_name,"creative_performance_report")>0;

		title 'Conversion metrics';
		select 
			count(*)
		,	the_name 
		into :nfiles_conver,
		     :filename_conver separated by '|'
		from list
		where find(the_name,"creative_conversion_performance")>0;
		title;

	quit;
	proc delete data=list; run;

	%if &nfiles_default = 0 %then %do;
		%let error_rsn = No new XLSX files found in input folder.;
		%let cancel=cancel;
	%end;

%if &cancel= and &nfiles_default > 0 %then %do; /* (1) */

/* -------------------------------------------------------------------------------------------------*/
/*                                                                                                  */
/*                                                                                                  */
/*                                         Ingest Raw Data                                          */
/*                                                                                                  */
/*                                                                                                  */
/* -------------------------------------------------------------------------------------------------*/

	%let error_rsn = No new records found in raw (default metrics) dataset.;

	/* -------------------------------------------------------------------------------------------------*/
	/*  Ad Performance (Default Metrics): Large Group & Small Group.                                    */
	/* -------------------------------------------------------------------------------------------------*/

		proc sql ;
			title 'Last LG data';
			select
				max(Date) format mmddyy6.
			,	max(Date) format date9.
			into :LastData_Old_LG trimmed,
				 :LastData_OldNum_LG trimmed
			from final.B2B_LinkedIn_Raw
			where Business_Size = 'LG'
				and Impressions > 0;

			title 'Last SB data';
			select
				max(coalesce(Date,End_Date)) format mmddyy6.
			,	max(coalesce(Date,End_Date)) format date9.
			into :LastData_Old_SB trimmed,
				 :LastData_OldNum_SB trimmed
			from final.B2B_LinkedIn_Raw
			where Business_Size = 'SB'
				and Impressions > 0;
			title; 

			title 'Last Archive data';
			select
				max(Date) format mmddyy6.
			into :LastData_Old trimmed
			from final.B2B_LinkedIn_Raw;
			title;
		quit;
	

	/* -------------------------------------------------------------------------------------------------*/
	/*  Import and clean new data.                                                                      */
	/* -------------------------------------------------------------------------------------------------*/

		%let i = 1;

		%macro Append_Import_LI_1();

			/* social actions = reactions, comments, shares, and follow clicks */
			/* total engagements = The sum of all social actions, clicks to Landing Page, and clicks to LinkedIn Page */

			%do %while (&i <= &nfiles_default);

				%let filename_loop = %sysfunc(scan(&filename_default,&i,'|'));
				%put &filename_loop;

				/* saved as xlsx and removed header */
				proc import 
					datafile="&raw_file_path./&filename_loop..xlsx"
					dbms=xlsx
					out=raw replace;
				run;

				data linkedin.linkedin_clean_default_&i.; 
					format  'Start Date (in UTC)'n mmddyy10.    'Account Name'n $100.            
   						    'Campaign Name'n $100.				'Campaign Type'n $19.
							'Campaign Objective'n $100. 
							'Campaign Start Date'n mmddyy10.	'Campaign End Date'n mmddyy10.
						   	'Creative Name'n $100.    					   
							'Ad Introduction Text'n	$500.       'Ad Headline'n $150.                   
						    'Total Spent'n dollar8.2			Reach 8.
							Impressions 8.						Clicks 8.
						   	'Clicks to Landing Page'n 8.		'Clicks to LinkedIn Page'n 8.	
                            'Total Social Actions'n 8. 			Reactions 8.    
							Comments 8.							Shares 8.
						    Follows 8.         					'Other Clicks'n 8.           
							'Event Registrations'n 8.			'Total Engagements'n 8.
                            'Viral Impressions'n 8.	  			'Viral Clicks'n 8.
						   	Leads 8.							'Lead Forms Opened'n 8.	  
                           	Carousel_Card $1.    				'Card Impressions'n 8.       
                           	'Card Clicks'n 8.					'Click URL'n $300.;

					keep 'Start Date (in UTC)'n
						 'Account Name'n
						 'Campaign Name'n
						 'Campaign Type'n
						 'Creative Name'n
						 'Ad Introduction Text'n
						 'Ad Headline'n
						 'Click URL'n
						 Carousel_Card
						 'Total Spent'n
						 Impressions
						 Clicks
						 'Card Impressions'n
						 'Card Clicks'n
						 Reactions
						 Comments
						 Shares
						 Follows
						 'Other Clicks'n
						 'Total Social Actions'n
						 'Total Engagements'n
						 'Viral Impressions'n
						 'Viral Clicks'n
						 Leads
						 'Lead Forms Opened'n
						 Reach
						 'Event Registrations'n
						 'Campaign Objective'n
						 'Campaign Start Date'n
						 'Campaign End Date'n
						 'Clicks to Landing Page'n
						 'Clicks to LinkedIn Page'n
						 ;

					set raw /*(firstobs=6)*/;

					rename
						 'Start Date (in UTC)'n = Date
						 'Account Name'n = Account
						 'Campaign Name'n = Campaign
						 'Campaign Type'n = Campaign_Type
						 'Creative Name'n = Creative
						 'Ad Introduction Text'n = Ad_Text
						 'Ad Headline'n = Ad_Headline
						 'Click URL'n = Click_URL
						 /* 'Carousel Card'n */
						 'Total Spent'n = Cost
						 'Card Impressions'n = Card_Impressions
						 'Card Clicks'n = Card_Clicks
						 'Other Clicks'n = Other_Social_Actions
						 'Total Social Actions'n = Total_Social_Actions
						 'Total Engagements'n = Total_Engagements
						 'Viral Impressions'n = Viral_Impressions
						 'Viral Clicks'n = Viral_Clicks
						 'Lead Forms Opened'n = Lead_Forms_Opened
						 'Event Registrations'n = Event_Registrations
						 'Campaign Objective'n = Campaign_Objective
						 'Campaign Start Date'n = Start_Date
						 'Campaign End Date'n = End_Date
						 'Clicks to Landing Page'n = Clicks_to_LP
						 'Clicks to LinkedIn Page'n = Clicks_to_LI
						 ;

					Carousel_Card=        put('Carousel Card'n,1.);
					
				run;

				%if &i=1 %then %do;
					data linkedin.linkedin_clean_default;
						set linkedin.linkedin_clean_default_&i.;
					run; 
				%end;
				%else %do;
					data linkedin.linkedin_clean_default;
						set linkedin.linkedin_clean_default_&i.
							linkedin.linkedin_clean_default;
					run;
				%end;

				/* -------------------------------------------------------------------------------------------------*/
				/*  Save input file --> zip archive.                                                                */
				/* -------------------------------------------------------------------------------------------------*/
				
				proc sql; select distinct count(*) into :cnt from linkedin.linkedin_clean_default_&i.; quit;

				%if &cnt > 0 %then %do;
					ods package(archived) open nopf;
					ods package(archived) add file="&raw_file_path./&filename_loop..xlsx";
					ods package(archived) publish archive properties (
						archive_name="&filename_loop..zip"
						archive_path="&input_files/Raw Campaign Manager Extracts/Archive/");
					ods package(archived) close;

					filename import "&raw_file_path./&filename_loop..xlsx";
					data _null_;
						rc=fdelete("import");
						put rc=;
					run;
					proc delete data=linkedin.linkedin_clean_default_&i.; run;
					proc delete data=raw; run;
				%end;
				%else %do;
					%put ERROR: No records found in raw file &filename_loop.;
				%end;

				/* -------------------------------------------------------------------------------------------------*/
				/*  Loop.                                                                                           */
				/* -------------------------------------------------------------------------------------------------*/

				%let i=%eval(&i+1);
				%put &i;

			%end; /* end loop through input files */
		%mend;
		%Append_Import_LI_1;

	%check_for_data(linkedin.linkedin_clean_default,=0,No records in linkedin_clean_default);

%end; /* (1) */

%if &cancel= and &nfiles_default > 0 and &nfiles_conver > 0 %then %do; /* (2) */

	/* -------------------------------------------------------------------------------------------------*/
	/*  Ad Performance (Conversion Metrics): Large Group & Small Group.                                 */
	/* -------------------------------------------------------------------------------------------------*/

	/* -------------------------------------------------------------------------------------------------*/
	/*  Import and clean new data.                                                                      */
	/* -------------------------------------------------------------------------------------------------*/

		%let i = 1;

		%macro Append_Import_LI_2();

			/* social actions = reactions, comments, shares, and follow clicks */
			/* total engagements = The sum of all social actions, clicks to Landing Page, and clicks to LinkedIn Page */

			%do %while (&i <= &nfiles_default);

				%let filename_loop = %sysfunc(scan(&filename_conver,&i,'|'));
				%put &filename_loop;

					/* saved as xlsx and removed header */
				proc import 
					datafile="&raw_file_path./&filename_loop..xlsx"
					dbms=xlsx
					out=raw replace;
				run;

				data linkedin.linkedin_clean_conver_&i.; 
					format  'Start Date (in UTC)'n mmddyy10.    'Account Name'n $100.            
   						    'Campaign Name'n $100.				'Campaign Type'n $19.
							'Campaign Objective'n $100. 
							'Campaign Start Date'n mmddyy10.	'Campaign End Date'n mmddyy10.
						   	'Creative Name'n $100.    					   
							'Conversion Name'n	$25.       		'Conversion Type'n $25.                   
						    Conversions 8.						 
							'Post-Click Conversions'n 8.		'View-Through Conversions'n 8.
						   	'Click URL'n $300.;

					keep 'Start Date (in UTC)'n
						 'Account Name'n
						 'Campaign Name'n
						 'Campaign Type'n
						 'Creative Name'n
						 'Click URL'n
						 'Campaign Objective'n
						 'Campaign Start Date'n
						 'Campaign End Date'n
						 'Conversion Name'n
						 'Conversion Type'n
						 Conversions
						 'Post-Click Conversions'n
						 'View-Through Conversions'n
						 ;

					set raw /*(firstobs=6)*/;

					rename
						 'Start Date (in UTC)'n = Date
						 'Account Name'n = Account
						 'Campaign Name'n = Campaign
						 'Campaign Type'n = Campaign_Type
						 'Creative Name'n = Creative
						 'Click URL'n = Click_URL
						 'Campaign Objective'n = Campaign_Objective
						 'Campaign Start Date'n = Start_Date
						 'Campaign End Date'n = End_Date
						 'Conversion Name'n = Conversion_Name
						 'Conversion Type'n = Conversion_Type
						 'Post-Click Conversions'n = Conversions_PC
						 'View-Through Conversions'n = Conversions_VT
						 ;
					
				run;

				%if &i=1 %then %do;
					data linkedin.linkedin_clean_conver;
						set linkedin.linkedin_clean_conver_&i.;
					run; 
				%end;
				%else %do;
					data linkedin.linkedin_clean_conver;
						set linkedin.linkedin_clean_conver_&i.
							linkedin.linkedin_clean_conver;
					run;
				%end;

				/* -------------------------------------------------------------------------------------------------*/
				/*  Save input file --> zip archive.                                                                */
				/* -------------------------------------------------------------------------------------------------*/
				
				proc sql; select distinct count(*) into :cnt from linkedin.linkedin_clean_conver_&i.; quit;

				%if &cnt > 0 %then %do;
					ods package(archived) open nopf;
					ods package(archived) add file="&raw_file_path./&filename_loop..xlsx";
					ods package(archived) publish archive properties (
						archive_name="&filename_loop..zip"
						archive_path="&input_files/Raw Campaign Manager Extracts/Archive/");
					ods package(archived) close;

					filename import "&raw_file_path./&filename_loop..xlsx";
					data _null_;
						rc=fdelete("import");
						put rc=;
					run;
					proc delete data=linkedin.linkedin_clean_conver_&i.; run;
					proc delete data=raw; run;
				%end;
				%else %do;
					%put ERROR: No records found in raw file &filename_loop.;
				%end;

				/* -------------------------------------------------------------------------------------------------*/
				/*  Loop.                                                                                           */
				/* -------------------------------------------------------------------------------------------------*/

				%let i=%eval(&i+1);
				%put &i;

			%end; /* end loop through input files */
		%mend;
		%Append_Import_LI_2;

	%check_for_data(linkedin.linkedin_clean_conver,=0,No records in linkedin_clean_conver);

%end; /* (2) */

%if &cancel= and &nfiles_default > 0 and &nfiles_conver > 0 %then %do; /* (3) */

	/* -------------------------------------------------------------------------------------------------*/
	/*                                                                                                  */
	/*                                                                                                  */
	/*                        Merge default-metrics & conversion-metrics datasets                       */
	/*                                                                                                  */
	/*                                                                                                  */
	/* -------------------------------------------------------------------------------------------------*/

	/* -------------------------------------------------------------------------------------------------*/
	/*  Prepare conversion-metrics for merge: Transpose.                                                */
	/* -------------------------------------------------------------------------------------------------*/

	data linkedin.linkedin_clean_conver;
	set linkedin.linkedin_clean_conver;

	if Conversion_Name='YMHW- Video Views' then Conversion_Name='YMHW-Video Views'; run;	

	proc sort data=linkedin.linkedin_clean_conver; by date account campaign 
			campaign_type creative click_url;
	run;

	proc transpose
		data=linkedin.linkedin_clean_conver
		out=linkedin.linkedin_clean_conver_c(drop=_NAME_ _LABEL_);
		by date account campaign 
			campaign_type creative click_url;
		id conversion_name;
		var conversions;
	run;
	proc transpose
		data=linkedin.linkedin_clean_conver
		out=linkedin.linkedin_clean_conver_pc(drop=_NAME_ _LABEL_);
		by date account campaign 
			campaign_type creative click_url;
		id conversion_name;
		var conversions_pc;
	run;
	proc transpose
		data=linkedin.linkedin_clean_conver
		out=linkedin.linkedin_clean_conver_vt(drop=_NAME_ _LABEL_);
		by date account campaign 
			campaign_type creative click_url;
		id conversion_name;
		var conversions_vt;
	run;

	/* -------------------------------------------------------------------------------------------------*/
	/*  Prepare conversion-metrics for merge: Rename.                                                   */
	/* -------------------------------------------------------------------------------------------------*/

	data linkedin.linkedin_clean_conver_c_final;
		set linkedin.linkedin_clean_conver_c;
		rename 'Primary - Download'n = Pri_Downloads_All
               'Secondary - Download'n = Sec_Downloads_All
			   "Let's Talk"n = Pri_Contacts_All
			   'YMHW-Link Clicks'n = Pri_Webinar_Link_All
			   'YMHW-Video Views'n = Sec_Documentary_Link_All
			   'YMHW-Podcast'n = Sec_Podcast_Link_All;

		* Replace missing numeric w/ 0;
		 array change _numeric_;
	        do over change;
	            if change=. then change=0;
	        end;
	run;
	data linkedin.linkedin_clean_conver_pc_final;
		set linkedin.linkedin_clean_conver_pc;
		rename 'Primary - Download'n = Pri_Downloads_PC
			   'Secondary - Download'n = Sec_Downloads_PC
			   "Let's Talk"n = Pri_Contacts_PC
			   'YMHW-Link Clicks'n = Pri_Webinar_Link_PC
			   'YMHW-Video Views'n = Sec_Documentary_Link_PC
			   'YMHW-Podcast'n = Sec_Podcast_Link_PC;

		* Replace missing numeric w/ 0;
		 array change _numeric_;
	        do over change;
	            if change=. then change=0;
	        end;
	run;
	data linkedin.linkedin_clean_conver_vt_final;
		set linkedin.linkedin_clean_conver_vt;
		rename 'Primary - Download'n = Pri_Downloads_VT
			   'Secondary - Download'n = Sec_Downloads_VT
			   "Let's Talk"n = Pri_Contacts_VT
			   'YMHW-Link Clicks'n = Pri_Webinar_Link_VT
			   'YMHW-Video Views'n = Sec_Documentary_Link_VT
			   'YMHW-Podcast'n = Sec_Podcast_Link_VT;

		* Replace missing numeric w/ 0;
		 array change _numeric_;
	        do over change;
	            if change=. then change=0;
	        end;
	run;

	/* -------------------------------------------------------------------------------------------------*/
	/*  Prepare conversion-metrics for merge: Combine.                                                  */
	/* -------------------------------------------------------------------------------------------------*/

	data linkedin.linkedin_clean_conver_final;
		format
			Pri_Downloads_all 8.	Sec_Downloads_All 8.		Pri_Contacts_All 8.
			Pri_Webinar_Link_All 8. Sec_Documentary_Link_All 8. Sec_Podcast_Link_All 8.

			Pri_Downloads_PC 8.		Sec_Downloads_PC 8.		    Pri_Contacts_PC 8.
			Pri_Webinar_Link_PC 8.  Sec_Documentary_Link_PC 8. 	Sec_Podcast_Link_PC 8.

			Pri_Downloads_VT 8.		Sec_Downloads_VT 8.			Pri_Contacts_VT 8.
			Pri_Webinar_Link_VT 8.  Sec_Documentary_Link_VT 8. 	Sec_Podcast_Link_VT 8.;

		merge linkedin.linkedin_clean_conver_c_final(in=a)
				linkedin.linkedin_clean_conver_pc_final(in=b)
				linkedin.linkedin_clean_conver_vt_final(in=c);
		by date account campaign 
			campaign_type creative click_url;
		if a or b or c;
	run;

	proc sql;
		create table check_dups as
		select 
			t1.* , t2.ndups
		from linkedin.linkedin_clean_conver_final t1
			, (select 
					date, account, campaign, campaign_type, creative, click_url, count(*) as ndups
			   from linkedin.linkedin_clean_conver_final
			   group by date, account, campaign, campaign_type, creative, click_url
			   ) t2
		where t2.ndups>1 
			and t1.date=t2.date 
			and t1.account=t2.account 
			and t1.campaign=t2.campaign
			and t1.campaign_type=t2.campaign_type
			and t1.creative=t2.creative
			and t1.click_url=t2.click_url
			order by t1.date, t1.account, t1.campaign, t1.campaign_type, t1.creative, t1.click_url;
	quit;	
	%check_for_data(check_dups,>0,Dupes in linkedin_clean_conver_final);
/*
	proc delete data=linkedin.linkedin_clean_conver_c; run &cancel.;
	proc delete data=linkedin.linkedin_clean_conver_pc; run &cancel.;
	proc delete data=linkedin.linkedin_clean_conver_vt; run &cancel.;
	proc delete data=linkedin.linkedin_clean_conver_c_final; run &cancel.;
	proc delete data=linkedin.linkedin_clean_conver_pc_final; run &cancel.;
	proc delete data=linkedin.linkedin_clean_conver_vt_final; run &cancel.;
	proc delete data=linkedin.linkedin_clean_conver; run &cancel.;
*/
%end; /* (3) */

%if &cancel= and &nfiles_default > 0 and &nfiles_conver > 0 %then %do; /* (4) */

	/* -------------------------------------------------------------------------------------------------*/
	/*  Prepare default-metrics for merge: De-dupe.                                                     */
	/* -------------------------------------------------------------------------------------------------*/

	proc sql;
	create table linkedin.linkedin_clean_default_rollup as
	select distinct
		Date, Account, Campaign, Campaign_Type, Campaign_Objective
	,	min(Start_Date) as Start_Date format mmddyy10.
	, 	max(End_Date) as End_Date format mmddyy10.
	, 	Creative, Ad_Text, Ad_Headline
	,	sum(Cost) as Cost format dollar18.2
	,	sum(Reach) as Reach format comma8.
	,	sum(Impressions) as Impressions format comma8.
	,	sum(Clicks) as Clicks format comma8.
	,	sum(Clicks_to_LP) as Clicks_to_LP format comma8.
	,	sum(Clicks_to_LI) as Clicks_to_LI format comma8.
	,	sum(Total_Social_Actions) as Total_Social_Actions format comma8.
	,	sum(Reactions) as Reactions format comma8.
	,	sum(Comments) as Comments format comma8.
	,	sum(Shares) as Shares format comma8.
	,	sum(Follows) as Follows format comma8.
	,	sum(Other_Social_Actions) as Other_Social_Actions format comma8.
	,	sum(Event_Registrations) as Event_Registrations format comma8.
	,	sum(Total_Engagements) as Total_Engagements format comma8.
	,	sum(Viral_Impressions) as Viral_Impressions format comma8.
	,	sum(Viral_Clicks) as Viral_Clicks format comma8.
	,	sum(Leads) as Leads format comma8.
	,	sum(Lead_Forms_Opened) as Lead_Forms_Opened format comma8.
	,	Carousel_Card 
	,	sum(Card_Impressions) as Card_Impressions format comma8.
	,	sum(Card_Clicks) as Card_Clicks format comma8.
	,	Click_URL
	from linkedin.linkedin_clean_default
	group by Date, Account, Campaign, Campaign_Type, Campaign_Objective,
		Creative, Ad_Text, Ad_Headline,
		Carousel_Card, Click_URL
	order by Date, Account, Campaign, Campaign_Type, Creative, Click_URL;
	quit;

	%check_for_data(linkedin.linkedin_clean_default_rollup,=0,No records in linkedin_clean_default_rollup);

	proc sql;
		create table check_dups as
		select 
			t1.* , t2.ndups
		from linkedin.linkedin_clean_default_rollup t1
			, (select 
					date, account, campaign, campaign_type, creative, click_url, carousel_card, count(*) as ndups
			   from linkedin.linkedin_clean_default_rollup
			   group by date, account, campaign, campaign_type, creative, click_url, carousel_card
			   ) t2
		where t2.ndups>1 
			and t1.date=t2.date 
			and t1.account=t2.account 
			and t1.campaign=t2.campaign
			and t1.campaign_type=t2.campaign_type
			and t1.creative=t2.creative
			and t1.click_url=t2.click_url
			and t1.carousel_card=t2.carousel_card
			order by t1.date, t1.account, t1.campaign, t1.campaign_type, t1.creative, t1.click_url, t1.carousel_card;
	quit;	
	%check_for_data(check_dups,>0,Dupes in linkedin_clean_default_rollup);

	proc delete data=linkedin.linkedin_clean_default; run &cancel.;

%end; /* (4) */

%if &cancel= and &nfiles_default > 0 and &nfiles_conver > 0 %then %do; /* (5) */

	/* -------------------------------------------------------------------------------------------------*/
	/*  Prepare default-metrics for merge: Split off Cards.                                             */
	/* -------------------------------------------------------------------------------------------------*/

	data linkedin.linkedin_clean_default_main
		 linkedin.linkedin_clean_default_cards;
		set linkedin.linkedin_clean_default_rollup;
		if Carousel_Card ne "." then output linkedin.linkedin_clean_default_cards;
			else output linkedin.linkedin_clean_default_main;
	run;

	/* -------------------------------------------------------------------------------------------------*/
	/*  Merge.                                                                                          */
	/* -------------------------------------------------------------------------------------------------*/

	data linkedin.linkedin_clean_combined_pre;
		merge linkedin.linkedin_clean_default_main(in=a) /* don't join conversion to cards */
			  linkedin.linkedin_clean_conver_final(in=b);
		by date account campaign 
			campaign_type creative click_url;
		if a;
		* Replace missing numeric w/ 0;
		 array change _numeric_;
	        do over change;
	            if change=. then change=0;
	        end;
	run;
	data linkedin.linkedin_clean_combined;
		set linkedin.linkedin_clean_combined_pre
			linkedin.linkedin_clean_default_cards; /* Append the card records to the merged records */
		* Replace missing numeric w/ 0;
		 array change _numeric_;
	        do over change;
	            if change=. then change=0;
	        end;
	run;
	proc sql ;
		select distinct
			sum(coalesce(pri_downloads_all,0)+
				coalesce(pri_contacts_all,0)+
				coalesce(sec_downloads_all,0)) as Conversions
		into :validate1 trimmed
		from linkedin.linkedin_clean_conver_final;

		select distinct
			sum(pri_downloads_all+pri_contacts_all+sec_downloads_all) as Conversions
		,	count(*)
		into :validate2 trimmed, :Nnew trimmed
		from linkedin.linkedin_clean_combined;
	quit;

%end; /* (5) */

%if %eval(&validate1 ne &validate2) or %eval(&Nnew=0) %then %do;
	%let cancel=cancel;
	%put Error: Conversions not properly appended.
%end;	

%if &cancel= and &nfiles_default > 0 and &nfiles_conver > 0 %then %do; /* (6) */

	proc delete data=linkedin.linkedin_clean_default_cards; run &cancel.;
	proc delete data=linkedin.linkedin_clean_default_main; run &cancel.;
	proc delete data=linkedin.linkedin_clean_combined_pre; run &cancel.;
	proc delete data=linkedin.linkedin_clean_conver; run &cancel.;
	proc delete data=linkedin.linkedin_clean_conver_final; run &cancel.;
	proc delete data=linkedin.linkedin_clean_default_rollup; run &cancel.;

	/* -------------------------------------------------------------------------------------------------*/
	/*  Clean raw LinkedIn data.                                                                        */
	/* -------------------------------------------------------------------------------------------------*/

		data linkedin.linkedin_clean_final
			 zero_values;

			retain	
				Date
				Month
				WeekStart
				Quarter
				Start_Date
				End_Date	
				Business_Size
				Campaign_Type
				Campaign_Objective
				Ad_Format
				/* New */ Theme
				Audience
				Region
				SubRegion
				Campaign
				Creative
				Image
				Cost
				Reach
				Impressions
				Clicks
				Clicks_to_LP
				Clicks_to_LI
				Total_Engagements
				Total_Social_Actions
				/* New */ Reactions
				/* New */ Shares
				/* New */ Follows
				/* New */ Comments
				/* New */ Other_Social_Actions
				/* New */ Event_Registrations
				/* New */ Pri_Downloads_All 
				/* New */ Pri_Contacts_All
				/* New */ Sec_Downloads_All
				/* New */ Pri_Webinar_Link_All
				/* New */ Sec_Documentary_Link_All
				/* New */ Sec_Podcast_Link_All

				/*
				Retired   Sec_Article_All 
				Retired   Sec_Infographic_All 
				Retired   Sec_Playbook_All
				Retired   Sec_Guide_All
				*/
				/* New */ Pri_Downloads_PC
				/* New */ Sec_Downloads_PC
				/* New */ Pri_Contacts_PC
				/* New */ Pri_Webinar_Link_PC
				/* New */ Sec_Documentary_Link_PC
				/* New */ Sec_Podcast_Link_PC

				/* New */ Pri_Downloads_VT
				/* New */ Sec_Downloads_VT
				/* New */ Pri_Contacts_VT
				/* New */ Pri_Webinar_Link_VT
				/* New */ Sec_Documentary_Link_VT
				/* New */ Sec_Podcast_Link_VT

				Leads
				Lead_Forms_Opened	
				Viral_Impressions
				Viral_Clicks
				Account
				Ad_Headline
				Ad_Text
				/* New */ Carousel_Card
				/* New */ Card_Impressions
				/* New */ Card_Clicks
				Click_URL
				Utm_Source
				Utm_Medium
				Utm_Campaign
				Utm_Content
				Utm_Term
				Do_Not_Join_to_GA_Flag;

			format  Month monyy7.
					WeekStart mmddyy10.
					Audience $50.
					Impressions comma12.
					Clicks comma12.
					Region $4.
					Ad_Format $12.
					Image $12.
					Theme $25.;

			set linkedin.linkedin_clean_combined;

			Do_Not_Join_to_GA_Flag = 0;

			* Cleaning;
			if Carousel_Card = "." then do;
				Carousel_Card = "";
				Card_Impressions = 0;
				Card_Clicks = 0;
				end;
			if Carousel_Card ne "" then Do_Not_Join_to_GA_Flag = 1;
			Ad_Text=Compress(Ad_Text,'0D0A'x);
			Ad_Text=tranwrd(Ad_Text,'0D0A'x,'');
			if find(Creative,'DNU')>0 then delete;

			* Month;
			WeekStart=intnx('week',Date,0,'b');
			Month=intnx('month',Date,0,'b');
			Quarter=catt('Q',qtr(date));

			* Business Size;
			if find(Account,'B2B_Extension_2022','i')>0 then Business_Size = 'LG';
				else Business_Size = 'SB';

			* Only keep new data;
			if (Business_Size = 'LG' and Date <= '31MAR2022'd /*"&LastData_OldNum_LG"d*/)
				or (Business_Size = 'SB' and Date <= '31MAR2022'd /*"&LastData_OldNum_SB"d*/)
				then delete;

			* Region / SubRegion;
			Region_temp = upcase(scan(Campaign,1,'_'));
			if Region_temp = 'SCAL' then Region = 'SCAL';
				else if Region_temp = 'NCAL' then Region = 'NCAL';
				else if Region_temp = 'WA' then Region = 'KPWA';
				else if Region_temp = 'NW' then Region = 'PCNW';
				else if Region_temp = 'GA' then Region = 'GRGA';
				else if Region_temp = 'CO' then Region = 'CLRD';
				else if Region_temp = 'MAS' then Region = 'MAS';

				drop Region_temp;
				* Other options: HWAI, MAS, UN;
			SubRegion = 'NON';
				*Other options: MRLD, VRGA, DC, ORE, WAS;

			* Parse Click_URL to UTMs;
			Click_URL = lowcase(tranwrd(Click_URL,'%7C','|'));
				Utm_Source = substr(Click_URL,index(Click_URL,'utm_source=')+11);
				Utm_Medium = substr(Click_URL,index(Click_URL,'utm_medium=')+11);
				Utm_Campaign = substr(Click_URL,index(Click_URL,'utm_campaign=')+13);
				Utm_Content = substr(Click_URL,index(Click_URL,'utm_content=')+12);
				Utm_Term = substr(Click_URL,index(Click_URL,'utm_term=')+9);

				Utm_Source = substr(Utm_Source,1,index(Utm_Source,'&')-1);
				Utm_Medium = substr(Utm_Medium,1,index(Utm_Medium,'&')-1);
				Utm_Campaign = substr(Utm_Campaign,1,index(Utm_Campaign,'&')-1);
				Utm_Content = substr(Utm_Content,1,index(Utm_Content,'&')-1);
				Utm_Term = substr(Utm_Term,1,index(Utm_Term,'&')-1); *Sometimes contains errors;
			Click_URL = substr(Click_URL,1,index(Click_URL,'?')-1);

			* Audience;
			if find(Campaign,'_exec_','i')>0 then Audience = 'Executives';
				else if find(Campaign,'_hr_','i')>0 then Audience = 'HR';
			if find(Campaign,'ABM')>0 then Audience = catt(Audience,'-ABM');

			* Ad_Format;
			if find(Campaign,'carousel','i')>0 then Ad_Format = 'Carousel';
				else Ad_Format = 'Single Image';

			* Theme;
			Campaign_orig = Campaign;
			Creative_orig = Creative;
			if find(UTM_Campaign,'rtw|','i')>0 then Theme = 'Return to Work';
				else if find(UTM_Campaign,'vc|','i')>0 then Theme = 'Virtual Care';
				else if find(UTM_Campaign,'mhw|','i')>0 then Theme = 'Mental Health & Wellness';

			* Creative & Image;
			Creative = propcase(scan(UTM_Campaign,3,'|'));
			if Theme = 'Return to Work' then do;
				if find(Campaign,'_hr_','i')>0 then do;
					Creative = 'Return to Work';
					Image = 'Apple';
					end;
				else do; 
					Creative = 'Return to Work';
					Image = 'Hallway';
					end;
				end;
			else if Theme = 'Virtual Care' then do;
				if find(Campaign,'_hr_','i')>0 then do;
					if Creative = 'Statistic' then Image = 'Woman1';
					else Image = 'Man1';
					end;
				else do;
					if Creative = 'Statistic' then Image = 'Woman2';
					else Image = 'Man2';
					end;
				end;
			else if Theme = 'Mental Health & Wellness' then do;
				if find(Campaign,'_hr_','i')>0 then do;
					if Creative = 'Absenteeism' then Image = 'Earrings';
					else Image = 'Stretch';
					end;
				else do;
					if Creative = 'Bandwagon' then Image = 'Tree';
					else if Creative = 'Bandwagon2' then Image = 'Headphones'; *Added 1/13 for new images;
					else if Creative = 'Depression' then Image = 'Blanket'; 
					else if Creative = 'Depression2' then Image = 'Studio'; *Added 1/13 for new images;
					end;
				end;	

			* Campaign;
			Campaign = catx('_','LinkedIn',Business_size,Compress(Theme),Audience);

			* Cleaning;
			if UTM_Campaign='mhw|exec|bandwagon2' and date < "07FEB2022"d then delete; *testing new image;
			if UTM_Campaign='mhw|exec|depression2' and date < "07FEB2022"d then delete; *testing new image;
				
			* Remove empty rows;
			if (Cost > 0 or Impressions > 0 
					or Pri_Downloads_all>0 or Pri_Contacts_All>0 or Sec_Downloads_All>0
					or Viral_Impressions>0
					or Carousel_Card ne "") then output linkedin.linkedin_clean_final;
				else output zero_values;

		run;

		proc sql ;
			select distinct count(*) as ZeroValRecs
			into :Nmiss
			from zero_values;

			select distinct count(*) as NewRecs
			into :Nnew
			from linkedin.linkedin_clean_final;
		quit;

		%check_for_data(linkedin.linkedin_clean_final,=0,No records in linkedin_clean_final);

		proc sql noprint;
			create table check_dups as
			select 
				t1.* , t2.ndups
			from linkedin.linkedin_clean_final t1
				, (select 
						date, campaign, utm_source, utm_medium, utm_campaign, utm_content, utm_term, count(*) as ndups
				   from linkedin.linkedin_clean_final
				   where Do_Not_Join_to_GA_Flag = 0 /* IMPORTANT */
				   group by date, campaign, utm_source, utm_medium, utm_campaign, utm_content, utm_term
				   ) t2
			where t2.ndups>1 
				and t1.date=t2.date 
				and t1.Campaign=t2.Campaign /* LinkedIn campaign name */
				and t1.utm_source=t2.utm_source 
				and t1.utm_medium=t2.utm_medium
				and t1.utm_campaign=t2.utm_campaign 
				and t1.utm_content=t2.utm_content 
				and t1.utm_term=t2.utm_term
				and t1.Do_Not_Join_to_GA_Flag = 0 /* IMPORTANT */
			order by t1.date, t1.campaign, t1.utm_source, t1.utm_medium, t1.utm_campaign, t1.utm_content, t1.utm_term;
		quit;
/**/
/*		proc sql;*/
/*		create table linkedin.linkedin_clean_final_rollup as*/
/*		select distinct*/
/*			Date, Month, WeekStart, Quarter*/
/*		,	min(Start_Date) as Start_Date format mmddyy10.*/
/*		, 	max(End_Date) as End_Date format mmddyy10.*/
/*		, 	Business_Size, Campaign_Type, Campaign_Objective, Ad_Format, Theme*/
/*		,	Audience, Region, SubRegion*/
/*		,	Campaign, Creative, Image*/
/*		,	sum(Cost) as Cost format dollar18.2*/
/*		,	sum(Reach) as Reach format comma8.*/
/*		,	sum(Impressions) as Impressions format comma8.*/
/*		,	sum(Clicks) as Clicks format comma8.*/
/*		,	sum(Clicks_to_LP) as Clicks_to_LP format comma8.*/
/*		,	sum(Clicks_to_LI) as Clicks_to_LI format comma8.*/
/*		,	sum(Total_Engagements) as Total_Engagements format comma8.*/
/*		,	sum(Total_Social_Actions) as Total_Social_Actions format comma8.*/
/*		,	sum(Reactions) as Reactions format comma8.*/
/*		,	sum(Shares) as Shares format comma8.*/
/*		,	sum(Follows) as Follows format comma8.*/
/*		,	sum(Comments) as Comments format comma8.*/
/*		,	sum(Other_Social_Actions) as Other_Social_Actions format comma8.*/
/*		,	sum(Event_Registrations) as Event_Registrations format comma8.*/
/*		, 	sum(Pri_Downloads_All) as Pri_Downloads_All*/
/*		, 	sum(Pri_Contacts_All) as Pri_Contacts_All*/
/*		,	sum(Sec_Downloads_All) as Sec_Downloads_All*/
/*		,	sum(Sec_Article_All) as Sec_Article_All*/
/*		,	sum(Sec_Infographic_All) as Sec_Infographic_All*/
/*		,	sum(Sec_Playbook_All) as Sec_Playbook_All*/
/*		,	sum(Sec_Guide_All) as Sec_Guide_All*/
/*		,	sum(Pri_Downloads_PC) as Pri_Downloads_PC*/
/*		,	sum(Pri_Downloads_VT) as Pri_Downloads_VT*/
/*		,	sum(Pri_Contacts_PC) as Pri_Contacts_PC*/
/*		,	sum(Pri_ContactS_VT) as Pri_Contacts_VT*/
/*		,	sum(Sec_Downloads_PC) as Sec_Downloads_PC*/
/*		,	sum(Sec_Downloads_VT) as Sec_Downloads_VT*/
/*		,	sum(Leads) as Leads format comma8.*/
/*		,	sum(Lead_Forms_Opened) as Lead_Forms_Opened format comma8.*/
/*		,	sum(Viral_Impressions) as Viral_Impressions format comma8.*/
/*		,	sum(Viral_Clicks) as Viral_Clicks format comma8.*/
/*		,	Account, Ad_Headline, Ad_Text, Carousel_Card */
/*		,	sum(Card_Impressions) as Card_Impressions format comma8.*/
/*		,	sum(Card_Clicks) as Card_Clicks format comma8.*/
/*		,	Click_URL, UTM_Source, UTM_Medium, UTM_Campaign, UTM_Content, UTM_Term*/
/*		,	Do_Not_Join_to_GA_Flag*/
/*		from linkedin.linkedin_clean_final*/
/*		group by Date, Month, WeekStart, Quarter*/
/*			, 	Business_Size, Campaign_Type, Campaign_Objective, Ad_Format, Theme*/
/*			,	Audience, Region, SubRegion*/
/*			,	Campaign, Creative, Image*/
/*			,	Account, Ad_Headline, Ad_Text, Carousel_Card */
/*			,	Click_URL, UTM_Source, UTM_Medium, UTM_Campaign, UTM_Content, UTM_Term*/
/*			,	Do_Not_Join_to_GA_Flag*/
/*		order by Date, Account, Campaign, Campaign_Type, Creative, Click_URL;*/
/*		quit;*/
/**/
/*		proc sql noprint;*/
/*			create table check_dups as*/
/*			select */
/*				t1.* , t2.ndups*/
/*			from linkedin.linkedin_clean_final_rollup t1*/
/*				, (select */
/*						date, utm_source, utm_medium, utm_campaign, utm_content, utm_term, count(*) as ndups*/
/*				   from linkedin.linkedin_clean_final_rollup*/
/*				   where Do_Not_Join_to_GA_Flag = 0 */
/*				   group by date, utm_source, utm_medium, utm_campaign, utm_content, utm_term*/
/*				   ) t2*/
/*			where t2.ndups>1 */
/*				and t1.date=t2.date */
/*				and t1.utm_source=t2.utm_source */
/*				and t1.utm_medium=t2.utm_medium*/
/*				and t1.utm_campaign=t2.utm_campaign */
/*				and t1.utm_content=t2.utm_content */
/*				and t1.utm_term=t2.utm_term*/
/*				and t1.Do_Not_Join_to_GA_Flag = 0 */
/*			order by t1.date, t1.utm_source, t1.utm_medium, t1.utm_campaign, t1.utm_content, t1.utm_term;*/
/*		quit;*/
/**/
/*	data linkedin.linkedin_clean_final;*/
/*		set linkedin.linkedin_clean_final_rollup;*/
/*	run;*/
/**/
/*	proc delete data=linkedin.linkedin_clean_final_rollup; run &cancel.;*/

		%check_for_data(check_dups,>0,Dupes in linkedin_clean_final);

		proc freq data=linkedin.linkedin_clean_final; 
		tables date 
				month 
				WeekStart
				quarter
				start_date*end_date 
				account
				ad_format
				theme
				campaign
				campaign_type
				campaign_objective
				creative
				image
				creative*image
				ad_text
				ad_headline
				business_size		
				region*subregion
				audience
				carousel_card
				Do_Not_Join_to_GA_Flag
				utm_source
				utm_medium
				utm_campaign
				utm_content
				utm_term
				utm_source*region
				utm_campaign*audience
				utm_campaign*creative
				utm_term*campaign_type
				utm_campaign*ad_text
				 / nocol norow nopercent;
		run;

%end; /* (6) */

%if &cancel= and &Nnew > 0 %then %do; /* (7) */

	proc delete data=linkedin.linkedin_clean_combined; run &cancel.;

	/* -------------------------------------------------------------------------------------------------*/
	/*  Export and archive raw display.                                                                 */
	/* -------------------------------------------------------------------------------------------------*/

		data linkedin.B2B_LinkedIn_Raw_Temp;
			set final.B2B_LinkedIn_Raw;
		run;

/*	
		proc sql;
		alter table final.B2B_LinkedIn_Raw
		add  
				 Pri_Webinar_Link_All NUM (8),
				 Sec_Documentary_Link_All  NUM (8),
				 Sec_Podcast_Link_All  NUM (8),

				 Pri_Webinar_Link_PC NUM (8),
				 Sec_Documentary_Link_PC NUM (8),
				 Sec_Podcast_Link_PC NUM (8),

				 Pri_Webinar_Link_VT NUM (8),
				 Sec_Documentary_Link_VT NUM (8),
				 Sec_Podcast_Link_VT NUM (8);
		quit;
*/
		proc sql;
		insert into final.B2B_LinkedIn_Raw
			select distinct 
				* 
			/* Archived Fields */
		
			,	. /* Sec_Article_All - Article conversion clicks to BW 2021 Q4 */
			,	. /* Sec_Infographic_All - VC Infographic conversion downloads 2021 Q4 */
			,	. /* Sec_Playbook_All - RTW Playbook conversion downloads 2021 Q4 */
			,	. /* Sec_Guide_All - MHW Guide conversion downloads 2021 Q4 */
			,	. /* Sends - InMail sends 2019 Q4 */
			,	. /* Opens - InMail opens 2019 Q4 */
			,	. /* Button_Clicks - InMail button clicks 2019 Q4 */
			,	. /* Banner_Clicks - InMail banner clicks 2019 Q4 */
			,	. /* Link_Clicks - InMail link clicks 2019 Q4 */
		from linkedin.linkedin_clean_final;
		quit;


	* If you added/removed or changed the formatting of a variable, run this instead;

/*		proc delete data=final.B2B_LinkedIn_Raw; run;*/
		data final.B2B_LinkedIn_Raw;
			set linkedin.B2B_LinkedIn_Raw_temp
			linkedin.linkedin_clean_final; 
		run;

	/* -------------------------------------------------------------------------------------------------*/
	/*  Save master file --> zip archive.                                                               */
	/* -------------------------------------------------------------------------------------------------*/

		proc sql noprint;
			select
				min(month) format mmddyy6.,
				max(Date) format mmddyy6.,
				max(Date) format date9.
			into :FirstData_Raw,
				 :LastData,
				 :LastDate_ThisUpdate
			from final.B2B_LinkedIn_Raw;
		quit;

		data archive.B2B_LinkedIn_Raw_&FirstData_Raw._&LastData;
			set final.B2B_LinkedIn_Raw;
		run;

		ods package(archived) open nopf;
		ods package(archived) add file="&output_files/Archive/b2b_linkedin_raw_&FirstData_Raw._&LastData..sas7bdat";
		ods package(archived) publish archive properties (
			archive_name="b2b_linkedin_raw_&FirstData_Raw._&LastData..zip"
			archive_path="&output_files/Archive/");
		ods package(archived) close;

		filename old_arch "&output_files/Archive/b2b_linkedin_raw_&FirstData_Raw._&LastData_Old..zip";
		data _null_;
			rc=fdelete("old_arch");
			put rc=;
		run;

%end; /* (7) */

%if &cancel= and &Nnew > 0 %then %do; /* (8) */

/* -------------------------------------------------------------------------------------------------*/
/*                                                                                                  */
/*                                                                                                  */
/*                                    Prepare for Campaign Dataset                                  */
/*                                                                                                  */
/*                                                                                                  */
/* -------------------------------------------------------------------------------------------------*/

/* -------------------------------------------------------------------------------------------------*/
/*  Engine metrics from newly-added b2b_linkedin_raw.                                               */
/* -------------------------------------------------------------------------------------------------*/

	%let error_rsn=Error compiling engine metrics.;

	proc sql;
		create table linkedin as
			select distinct
				Date format mmddyy10.
			,	WeekStart format mmddyy10.
			,	Month format monyy7. 
			,	Quarter format $2.
			,	'Social' as Channel format $25.
			,	case when Business_Size = 'LG' then 'Social-LinkedIn B2B' 
				     when Business_Size = 'SB' then 'Social-LinkedIn SBU'
					end as ChannelDetail format $25.
			,	sum(Impressions) as Impressions format comma18.
			,	sum(Clicks_to_LP) as Clicks format comma8.
			,	sum(Cost) as Spend format dollar18.2
			, 	sum(Total_Engagements) as Total_Engagements format comma8.
			,	sum(Total_Social_Actions) as Total_Social_Actions format comma8. /* NEW */
			,	sum(Pri_Downloads_All) as Primary_Downloads format comma8. /* NEW */
			,	sum(Pri_Contacts_All) as Primary_Contacts format comma8. /* NEW */
			,	sum(Sec_Downloads_All) as Secondary_Downloads format comma8. /* NEW */

			,	sum(Pri_Webinar_Link_All) as Primary_Webinar format comma8. /* NEW */
			,	sum(Sec_Documentary_Link_All) as Secondary_Documentary format comma8. /* NEW */
			,	sum(Sec_Podcast_Link_All) as Secondary_Podcast format comma8. /* NEW */

			,	sum(Lead_Forms_Opened) as Lead_Forms_Opened format comma8.
			,	sum(Leads) as Leads format comma8.
			,	tranwrd(Campaign,'-ABM','') as Campaign format $250. /* UTM tags are not at the ABM level */
			,	'LinkedIn' as Network format $25.
			,	Region format $5.
			,	SubRegion format $5.
			,	'Value Demonstration' as Program_Campaign format $30.
			,	Theme format $50.
			,	Creative format $200.
			,	Image format $30.
			,	Ad_Format format $15. /* rename "BannerSize" */
			,	tranwrd(Audience,'-ABM','') as Audience format $50.
				/* Join Metrics */
			,	UTM_Source
			,	UTM_Medium
			,	UTM_Campaign
			,	UTM_Content
			,	UTM_Term 
			,	Do_Not_Join_to_GA_Flag
			from linkedin.linkedin_clean_final
			where Carousel_Card = '' /* Carousels have both a rollup record (Card="") and individual card records */
			group by 
				Date 
			,	case when Business_Size = 'LG' then 'Social-LinkedIn B2B' 
				     when Business_Size = 'SB' then 'Social-LinkedIn SBU'
					end 			
			,	tranwrd(Campaign,'-ABM','') 
			,	Region 
			,	SubRegion
			,	Theme 
			,	Creative 
			,	Image 
			,	Ad_Format 
			,	tranwrd(Audience,'-ABM','') 
			,	UTM_Source
			,	UTM_Medium
			,	UTM_Campaign
			,	UTM_Content
			,	UTM_Term 
			,	Do_Not_Join_to_GA_Flag
			; 
	quit;
	data linkedin_ready_to_join(drop=Do_Not_Join_to_GA_Flag)
		 linkedin_do_not_join(drop=Do_Not_Join_to_GA_Flag rename=(UTM_Content=PromoID));
		set linkedin;

		* Q4 2021 mistakenly tagged SB creatives as having an issue when it's only LG;
		*if Do_Not_Join_to_GA_Flag=1 and ChannelDetail='Social-LinkedIn SBU' then Do_Not_Join_to_GA_Flag=0;

		if Do_Not_Join_to_GA_Flag=1 then output linkedin_do_not_join;
			else output linkedin_ready_to_join;
	run;

	%check_for_data(linkedin_ready_to_join,=0,No records in linkedin_ready_to_join);
	
	proc sql;
		create table check_dups as
		select 
			t1.* , t2.ndups
		from linkedin_ready_to_join t1
			, (select 
					date, utm_source, utm_medium, utm_campaign, utm_content, utm_term, count(*) as ndups
			   from linkedin_ready_to_join
			   group by date, utm_source, utm_medium, utm_campaign, utm_content, utm_term
			   ) t2
		where t2.ndups>1 
			and t1.date=t2.date 
			and t1.utm_source=t2.utm_source 
			and t1.utm_medium=t2.utm_medium
			and t1.utm_campaign=t2.utm_campaign 
			and t1.utm_content=t2.utm_content 
			and t1.utm_term=t2.utm_term
			order by t1.date, t1.utm_source, t1.utm_medium, t1.utm_campaign, t1.utm_content, t1.utm_term;
	quit;

	%check_for_data(check_dups,>0,Dupes in linkedin_ready_to_join);
	
%end; /* (8) */

%if &cancel= and &Nnew > 0 %then %do; /* (9) */
	
	/* -------------------------------------------------------------------------------------------------*/
	/*  Google Analytics metrics for the same period from b2b_campaign_gadata.                          */
	/* -------------------------------------------------------------------------------------------------*/

		%let error_rsn=Error compiling Google Analytics metrics.;

		proc sql noprint;
		select distinct
			min(Date) format date9.,
			max(Date) format date9.
		into	
			:Campaign_StartDate,
			:Campaign_EndDate
		from linkedin_ready_to_join;
		quit;

		
		proc sql;
		create table better_way as
			select distinct
				Date
			,	lowcase(UTM_Source) as UTM_Source
			,	lowcase(UTM_Medium) as UTM_Medium
			,	case when UTM_Campaign in ('(notset)','(not set)','{dscampaign}','{_dscampaign}','')
					then '_error_' /* Prevent joining on bad data */
					else lowcase(UTM_Campaign)
					end as UTM_Campaign format $250.
			,	lowcase(UTM_Content) as UTM_Content
			,	case when UTM_Term in ('(not set)','{keyword}','')
					then '_error_' /* Prevent joining on bad data */
					else lowcase(UTM_Term)
					end as UTM_Term format $250.
			,	PromoID
			,	sum(users) as Users
			,	sum(newusers) as newUsers
			,	sum(Sessions) as Sessions
			,	sum(Bounces) as Bounces
			,	sum(SessionDuration) as SessionDuration format 8.
			,	sum(uniquePageviews) as UniquePageviews
			,	sum(ShopActions_Unique) as ShopActions_Unique
			,	sum(LearnActions_Unique) as LearnActions_Unique
/*			,	sum(ConvertActions_Unique) as ConvertActions_Unique*/
/*			,	sum(ShareActions_Unique) as ShareActions_Unique*/
			,	sum(goal7_Learn) as goal7_Learn /* old measurement plan */
			,	sum(goal8_Shop) as goal8_Shop /* old measurement plan */

			,	sum(Shop_Download) as Shop_Download 
			,	sum(ConvertNonSubmit_SSQ) as ConvertNonSubmit_SSQ 
			,	sum(SB_MAS_Leads) as SB_MAS_Leads
			,	sum(Shop_Explore) as Shop_Explore
			,	sum(Shop_Interact) as Shop_Interact
			,	sum(Shop_Read) as Shop_Read 
			,	sum(ConvertNonSubmit_Quote) as ConvertNonSubmit_Quote 
			,	sum(ConvertSubmit_Quote) as ConvertSubmit_Quote
			,	sum(ConvertNonSubmit_Contact) as ConvertNonSubmit_Contact 
			,	sum(ConvertSubmit_Contact) as ConvertSubmit_Contact
			,	sum(Convert_Call) as Convert_Call 
			,	sum(Learn_Download) as Learn_Download 
/*			,	sum(Exit) as Exit */
			,	sum(Learn_Explore) as Learn_Explore 
			,	sum(ManageAccount_BCSSP) as ManageAccount_BCSSP
			,	sum(Learn_Interact) as Learn_Interact
			,	sum(Learn_Read) as Learn_Read 	
			,	sum(Learn_Save) as Learn_Save
			,	sum(Learn_Watch) as Learn_Watch 		
			,	sum(Share_All) as Share_All 
				/* new */
			,	sum(goalValue) as Weighted_Actions
			,	sum(ConvertNonSubmit_QuoteVC) as ConvertNonSubmit_QuoteVC
			,	sum(ConvertNonSubmit_ContKPDiff) as ConvertNonSubmit_ContKPDiff
			from archive.b2b_campaign_gadata
			where lowcase(UTM_Medium) = 'linkedin'
				and Date >= "&Campaign_StartDate"d
				and Date <= "&Campaign_EndDate"d
			group by
				Date
			,	UTM_Source
			,	UTM_Medium
			,	case when UTM_Campaign in ('(notset)','(not set)','{dscampaign}','{_dscampaign}','')
				then '_error_' /* Prevent joining on bad data */
				else UTM_Campaign
				end
			,	UTM_Content
			,	case when UTM_Term in ('(not set)','{keyword}','')
				then '_error_' /* Prevent joining on bad data */
				else UTM_Term 
				end
			,	PromoID;
		quit;

		data better_way;
			set better_way;

			/* Organic Social Posts */
			if UTM_Source = 'pr-comms' then delete; 
			if UTM_Campaign = 'virtual_care_msk' then delete;
			if find(UTM_Medium,'organic','i')>0 then delete;
			if find(UTM_Term,'organic-post','i')>0 then delete;
			/* 2022 testing */
			if find(UTM_Campaign,'bandwagon2')>0 and Date<"07FEB2022"d then delete;
			if find(UTM_Campaign,'depression2')>0 and Date<"07FEB2022"d then delete;
			/* 2021 testing */
			if find(UTM_Campaign,'rtw')>0 and Date<"04NOV2021"d then delete;
			if find(UTM_Campaign,'rtw')>0 and find(UTM_Term,'carousel')>0 and Date<"16NOV2021"d then delete;
			if find(UTM_Campaign,'vc')>0 and Date<"15NOV2021"d then delete;
			if find(UTM_Campaign,'vc')>0 and find(UTM_Term,'carousel')>0 and Date<"18NOV2021"d then delete;
			if find(UTM_Campaign,'mhw')>0 and Date<"14DEC2021"d then delete;
		run;
		data better_way_ready_to_join
			 better_way_do_not_join;
			set better_way;

			* 2022 (present);
			if date ne . then output better_way_ready_to_join; /* all, no errors */
			* Q4 2021;
/*			if year(date)=2021 */
/*				and UTM_Source in ('lg-ncal-prospect','lg-kpwa-prospect')*/
/*				and UTM_Campaign in ('mhw|hr|absenteeism','mhw|hr|productivity') */
/*				and UTM_Term = 'sponsored-content|single-image'*/
/*				then output better_way_do_not_join;*/
/*			else output better_way_ready_to_join;*/
		run;

		%check_for_data(better_way_ready_to_join,=0,No records in better_way_ready_to_join);

		proc sql noprint;
			create table check_dups as
			select 
				t1.* , t2.ndups
			from better_way_ready_to_join t1
				, (select 
						date, utm_source, utm_medium, utm_campaign, utm_content, utm_term, count(*) as ndups
				   from better_way_ready_to_join
				   group by date, utm_source, utm_medium, utm_campaign, utm_content, utm_term
				   ) t2
			where t2.ndups>1 
				and t1.date=t2.date 
				and t1.utm_source=t2.utm_source 
				and t1.utm_medium=t2.utm_medium
				and t1.utm_campaign=t2.utm_campaign 
				and t1.utm_content=t2.utm_content 
				and t1.utm_term=t2.utm_term
				order by t1.date, t1.utm_source, t1.utm_medium, t1.utm_campaign, t1.utm_content, t1.utm_term;
		quit;

		%check_for_data(check_dups,>0,Dupes in better_way_ready_to_join);
	
%end; /* (9) */

%if &cancel= and &Nnew > 0 %then %do; /* (10) */

	/* -------------------------------------------------------------------------------------------------*/
	/*  Merge engine metrics with Google Analytics metrics                                              */
	/* -------------------------------------------------------------------------------------------------*/

		%let error_rsn=Error merging tables.;

		proc sort data=better_way_ready_to_join; by date utm_source utm_medium utm_campaign utm_content utm_term; run;
		proc sort data=linkedin_ready_to_join; by date utm_source utm_medium utm_campaign utm_content utm_term; run;

		data linkedin.campaign_merged
			 missing
			 otherlob; 

			merge linkedin_ready_to_join (in=a)
				  better_way_ready_to_join (in=b);
			by date utm_source utm_medium utm_campaign utm_content utm_term;

			* Halo flag initialize;
			Halo_Actions = 0;

			if PromoID = '' then PromoId = UTM_Content;

			if a then output linkedin.campaign_merged;

				else do;

				WeekStart=intnx('week',Date,0,'b');
				Month=intnx('month',date,0,'b');
				Quarter=catt('Q',qtr(date));

				* Halo Action Flag;
				Halo_Actions = 1;

				* Channel;
				Channel='Social';

				* ChannelDetail;
				LOB_temp = upcase(scan(UTM_Source,1,'-'));
				if LOB_temp = 'LG' then ChannelDetail = 'Social-LinkedIn B2B';
					else if LOB_temp = 'SB' then ChannelDetail = 'Social-LinkedIn SBU';
				drop LOB_temp;

				* Program_Campaign;
				Program_Campaign='Value Demonstration';

				* Network;
				Network='LinkedIn';

				* Region;
				Region_temp=upcase(scan(UTM_Source,2,'-'));
				if Region_temp in ('CLRD','CO') then Region = 'CLRD';
					else if Region_temp in ('SCAL','CASC') then Region = 'SCAL';
					else if Region_temp in ('NCAL','CANC') then Region = 'NCAL';
					else if Region_temp in ('GRGA','GA') then Region = 'GRGA';
					else if Region_temp in ('PCNW','NW') then Region = 'PCNW';
					else if Region_temp in ('KPWA','WA') then Region = 'KPWA';
				SubRegion='NON';
				drop Region_temp;

			if find(UTM_Campaign,'vc|')>0 or find(UTM_Campaign,'mhw|')>0 or find(UTM_Campaign,'rtw|')>0 then do; * First campaign with ID;
				* Theme;
				if find(UTM_Campaign,'rtw|','i')>0 then Theme = 'Return to Work';
					else if find(UTM_Campaign,'vc|','i')>0 then Theme = 'Virtual Care';
					else if find(UTM_Campaign,'mhw|','i')>0 then Theme = 'Mental Health & Wellness';
				* Audience;
				if find(UTM_Campaign,'|exec','i')>0 then Audience = 'Executives';
					else if find(UTM_Campaign,'|hr','i')>0 then Audience = 'HR';
				* Creative & Image;
				Creative = propcase(scan(UTM_Campaign,3,'|'));
				if Creative = 'Positivity' then Creative = 'Productivity';
				if Theme = 'Return to Work' then do;
					if Audience = 'HR' then do;
						Creative = 'Return to Work';
						Image = 'Apple';
						end;
					else do; 
						Creative = 'Return to Work';
						Image = 'Hallway';
						end;
					end;
				else if Theme = 'Virtual Care' then do;
					if Audience = 'HR' then do;
						if Creative = 'Statistic' then Image = 'Woman1';
						else Image = 'Man1';
						end;
					else do;
						if Creative = 'Statistic' then Image = 'Woman2';
						else Image = 'Man2';
						end;
					end;
				else if Theme = 'Mental Health & Wellness' then do;
					if Audience = 'HR' then do;
						if Creative = 'Absenteeism' then Image = 'Earrings';
						else Image = 'Stretch';
						end;
					else do;
						if Creative = 'Bandwagon' then Image = 'Tree';
						else if Creative = 'Bandwagon2' then Image = 'Headphones';
						else if Creative = 'Depression' then Image = 'Blanket';
						else if Creative = 'Depression2' then Image = 'Studio';
						end;
					end;	
				* Ad_Format;
				if find(UTM_Term,'|carousel','i')>0 then Ad_Format = 'Carousel';
					else Ad_Format = 'Single Image';
				* Campaign;
				Campaign = catx('_','LinkedIn',upcase(scan(UTM_Source,1,'-')),Compress(Theme),Audience);
			output missing;
			end;

				else if UTM_Term='sponsored-content' then do; /* Halo Wave 1 2021 activity & non-joinable CO, NCAL, SCAL Wave 1 data in better_way dataset only */
					* Theme; 
					Theme_temp=scan(UTM_Campaign,2,'|');
					* Error;
					if UTM_Source = 'lg-co-prospect' and UTM_Campaign ='other-influencers|acceleratedtele' then Theme='UN';
					else if Theme_temp='webinar' then Theme='Employee Health';
						else if Theme_temp in ('acceleratedtele','telereducecost') then Theme='Telehealth';
						else if Theme_temp in ('mindfulness','resiliencekey','strongmhw') then Theme='Mental Health and Wellness / Stress Management';
					drop Theme_temp;	
					* Creative;
					Creative=scan(UTM_Campaign,2,'|');
					* Error;
					if UTM_Source ='lg-co-prospect' and UTM_Campaign in ('c-suite-leaders|mindfulness','other-influencers|acceleratedtele')
						then Creative = 'UN';
					* Ad_Format;
					Ad_Format='Single Image';
					* Campaign;
					Campaign = 'Sponsored Update';
					* Image;
					Image='Lookup'; 
					* Error;
					Image = 'UN';
					* Audience;
					Audience_temp=scan(UTM_Campaign,1,'|');
						if Audience_temp = 'c-suite-leaders' then Audience = 'C-Suite Leaders';
						else if Audience_temp = 'hr-decision-makers' then Audience = 'HR Decision Makers';
						else if Audience_temp = 'other-influencers' then Audience = 'Other Influencers';
						else if Audience_temp = 'site-visitors-lal' then Audience = 'SiteVisitorsLAL';
					drop Audience_temp;
					output missing;
				end; /* end of halo Wave 1 activity and non-joinable CO, NCAL, SCAL data */
				else if UTM_source = 'social' and utm_campaign = 'b2b' then do;
					* ChannelDetail;
					ChannelDetail='Social-LinkedIn B2B';
					* Region;
					Region='UN';
					SubRegion='NON';
					* Campaign;
					Campaign='UN';
					* Theme;
					Theme='UN';	
					* Ad_Format;
					Ad_Format='UN';
					* Creative;
					Creative='UN'; 
					* Image;
					Image='UN'; 
					* Audience;
					Audience='UN';
					* PromoID;
					PromoID = '';
					output missing;
				end; 

				else do; /* ?? */

					output otherlob;
	
				end;

			end;

		run;

		%let error_rsn=Error appending tables.;

		data linkedin.b2b_campaign_master_linkedin;

				format 
					Date mmddyy10.
					WeekStart mmddyy10.
					Month monyy7.
					Quarter $2.
					Channel $25.
					ChannelDetail $25.
					Impressions comma18.
					Clicks comma8.
					Spend dollar18.2
					Keyword $250.
					Campaign $250.
					Network $25.
					Region $25.
					SubRegion $5.
					Program_Campaign $30.
					Theme $50.
					Creative $200.
					Image $30.
					Ad_Format $40. /* RENAMED FROM BANNERSIZE */
					Audience $50. /* MOVED */
					Match_Type $6.
					Remarketing $8.
					Keyword_Category $7.
					PromoID $6.
					
					Users comma8.
					newUsers comma8.
					Sessions comma8.
					Bounces comma8.
					sessionDuration 8.
	/*				Pageviews comma8.*/
					uniquePageviews comma8.
					ShopActions_Unique comma8.
					LearnActions_Unique comma8.
/*					ConvertActions_Unique comma8.*/
/*					ShareActions_Unique comma8.*/
					goal7_Learn comma8.
					goal8_Shop comma8.

					Shop_Download comma8.
					ConvertNonSubmit_SSQ comma8.
					SB_MAS_Leads comma8.
					Shop_Explore comma8.
					Shop_Interact comma8.
					Shop_Read comma8.
					ConvertNonSubmit_Quote comma8.
					ConvertSubmit_Quote comma8.
					ConvertNonSubmit_Contact comma8.
					ConvertSubmit_Contact comma8.
					Convert_Call comma8.
					Learn_Download comma8.
	/*				Exit comma8.*/
					Learn_Explore comma8.
					ManageAccount_BCSSP comma8.
					Learn_Interact comma8.
					Learn_Read comma8.	
					Learn_Save comma8.
					Learn_Watch comma8.		
					Share_All comma8.

					/* new */
					Weighted_Actions comma8.2
					ConvertNonSubmit_QuoteVC comma8.
					ConvertNonSubmit_ContKPDiff comma8.

					/* MOVED */
					Business_Actions comma8.
					Business_Leads comma8.
					VideoStarts comma8.
					VideoCompletions comma8.
					Total_Engagements comma8. /* RENAMED from Engagements */
					Total_Social_Actions comma8. /* NEW */
					Leads comma8.
					Lead_Forms_Opened comma8.
					Primary_Downloads comma8. /* NEW */
					Primary_Contacts comma8. /* NEW */
					Secondary_Downloads comma8. /* NEW */

					Pri_Webinar comma8. /* NEW */
					Sec_Documentary comma8. /* NEW */
					Sec_Podcast comma8. /* NEW */

					Halo_Actions comma8.
			
				;
		 	set linkedin.campaign_merged(in=a)
				missing(in=b)
				otherlob(in=c)
				linkedin_do_not_join(in=d)
				better_way_do_not_join(in=e);

			VideoStarts=.;
			VideoCompletions=.;
			Keyword='N/A';
			Match_Type='N/A';
			Remarketing='N/A';
			Keyword_Category='N/A';
			Business_Actions=.;
			Business_Leads=.;

			* Replace missing numeric w/ 0;
			 array change _numeric_;
		        do over change;
		            if change=. then change=0;
		        end;

			if d or e then do; /* cleaning for the "do_not_join" tables */

				WeekStart=intnx('week',Date,0,'b');
				Month=intnx('month',date,0,'b');
				Quarter=catt('Q',qtr(date));

				* Channel;
				Channel='Social';

				* ChannelDetail;
				LOB_temp = upcase(scan(UTM_Source,1,'-'));
				if LOB_temp = 'LG' then ChannelDetail = 'Social-LinkedIn B2B';
					else if LOB_temp = 'SB' then ChannelDetail = 'Social-LinkedIn SBU';
				drop LOB_temp;

				* Program_Campaign;
				Program_Campaign='Value Demonstration';

				* Network;
				Network='LinkedIn';

				* Region;
				Region_temp=upcase(scan(UTM_Source,2,'-'));
				if Region_temp in ('CLRD','CO') then Region = 'CLRD';
					else if Region_temp in ('SCAL','CASC') then Region = 'SCAL';
					else if Region_temp in ('NCAL','CANC') then Region = 'NCAL';
					else if Region_temp in ('GRGA','GA') then Region = 'GRGA';
					else if Region_temp in ('PCNW','NW') then Region = 'PCNW';
					else if Region_temp in ('KPWA','WA') then Region = 'KPWA';
				SubRegion='NON';
				drop Region_temp;

				if find(UTM_Campaign,'vc|')>0 or find(UTM_Campaign,'mhw|')>0 or find(UTM_Campaign,'rtw|')>0 then do; * First campaign with ID;
					* Theme;
					if find(UTM_Campaign,'rtw|','i')>0 then Theme = 'Return to Work';
						else if find(UTM_Campaign,'vc|','i')>0 then Theme = 'Virtual Care';
						else if find(UTM_Campaign,'mhw|','i')>0 then Theme = 'Mental Health & Wellness';
					* Audience;
					if find(UTM_Campaign,'|exec','i')>0 then Audience = 'Executives';
						else if find(UTM_Campaign,'|hr','i')>0 then Audience = 'HR';
					* Creative & Image;
					Creative = propcase(scan(UTM_Campaign,3,'|'));
					if Creative = 'Positivity' then Creative = 'Productivity';
					if Theme = 'Return to Work' then do;
						if Audience = 'HR' then do;
							Creative = 'Return to Work';
							Image = 'Apple';
							end;
						else do; 
							Creative = 'Return to Work';
							Image = 'Hallway';
							end;
						end;
					else if Theme = 'Virtual Care' then do;
						if Audience = 'HR' then do;
							if Creative = 'Statistic' then Image = 'Woman1';
							else Image = 'Man1';
							end;
						else do;
							if Creative = 'Statistic' then Image = 'Woman2';
							else Image = 'Man2';
							end;
						end;
					else if Theme = 'Mental Health & Wellness' then do;
						if Audience = 'HR' then do;
							if Creative = 'Absenteeism' then Image = 'Earrings';
							else Image = 'Stretch';
							end;
						else do;
							if Creative = 'Bandwagon' then Image = 'Tree';
							else if Creative = 'Bandwagon2' then Image = 'Headphones';
							else if Creative = 'Depression' then Image = 'Blanket';
							else if Creative = 'Depression2' then Image = 'Studio';
							end;
						end;	
					* Ad_Format;
					if find(UTM_Term,'|carousel','i')>0 then Ad_Format = 'Carousel';
						else Ad_Format = 'Single Image';
					* Campaign;
					Campaign = catx('_','LinkedIn',upcase(scan(UTM_Source,1,'-')),Compress(Theme),Audience);

				end;
				else if UTM_Term='sponsored-content' then do; /* Halo Wave 1 2021 activity & non-joinable CO, NCAL, SCAL Wave 1 data in better_way dataset only */
					* Theme; 
					Theme_temp=scan(UTM_Campaign,2,'|');
					* Error;
					if UTM_Source = 'lg-co-prospect' and UTM_Campaign ='other-influencers|acceleratedtele' then Theme='UN';
					else if Theme_temp='webinar' then Theme='Employee Health';
						else if Theme_temp in ('acceleratedtele','telereducecost') then Theme='Telehealth';
						else if Theme_temp in ('mindfulness','resiliencekey','strongmhw') then Theme='Mental Health and Wellness / Stress Management';
					drop Theme_temp;	
					* Creative;
					Creative=scan(UTM_Campaign,2,'|');
					* Error;
					if UTM_Source ='lg-co-prospect' and UTM_Campaign in ('c-suite-leaders|mindfulness','other-influencers|acceleratedtele')
						then Creative = 'UN';
					* Ad_Format;
					Ad_Format='Single Image';
					* Campaign;
					Campaign = 'Sponsored Update';
					* Image;
					Image='Lookup'; 
					* Error;
					Image = 'UN';
					* Audience;
					Audience_temp=scan(UTM_Campaign,1,'|');
						if Audience_temp = 'c-suite-leaders' then Audience = 'C-Suite Leaders';
						else if Audience_temp = 'hr-decision-makers' then Audience = 'HR Decision Makers';
						else if Audience_temp = 'other-influencers' then Audience = 'Other Influencers';
						else if Audience_temp = 'site-visitors-lal' then Audience = 'SiteVisitorsLAL';
					drop Audience_temp;
				end;

			end;

		run;
			
		/* Validation */
		proc sql;
			select distinct
	 			WeekStart
			,	Halo_Actions
			,	sum(spend) as spend format dollar18.2
			,	sum(impressions) as impressions format comma18.
			,	sum(clicks) as clicks format comma18.
			,	sum(goal7_learn+goal8_shop) as ga_actions format comma8.
			,	sum(convertsubmit_contact+convertsubmit_quote) as ga_leads format comma8.
			,	sum(sessions) As sessions format comma8.
			from linkedin.b2b_campaign_master_linkedin
			group by 
				WeekStart
			,	Halo_Actions
			order by	
				Halo_Actions
			,	WeekStart;
		quit;	

		proc freq data=linkedin.b2b_campaign_master_linkedin; 
			tables  
					month 
					channel*channeldetail
					keyword
					campaign
					network
					region*SubRegion
					program_campaign
					theme
					creative
					image
					ad_format
					Match_Type
					Remarketing
					Keyword_Category
					Audience
					PromoID
					 / nocol norow nopercent;
			run;

		/* Validation */
		proc sql;
			title 'Dataset about to be pushed to b2b_campaign_master';
			select distinct
				sum(spend) as spend format dollar18.2
			,	sum(impressions) as impressions format comma18.
			,	sum(clicks) as clicks format comma18.
			,	sum(total_engagements) as total_engagements format comma18.
			,	sum(goal7_learn+goal8_shop) as ga_actions_old format comma8.
			,	sum(convertsubmit_contact+convertsubmit_quote) as ga_leads format comma8.
			,	sum(sessions) As sessions format comma8.
			into :valid_spend, :valid_impr, :valid_clicks, :valid_eng,
				 :valid_act, :valid_lead, :valid_visit
			from linkedin.b2b_campaign_master_linkedin;

			title 'Original set from LinkedIn';
			select distinct
				sum(spend) as spend format dollar18.2
			,	sum(impressions) as impressions format comma18.
			,	sum(clicks) as clicks format comma18.
			,	sum(total_engagements) as total_engagements format comma18.
			into :spend, :impr, :clicks, :eng
			from linkedin;

			title 'Original set from Better Way';
			select distinct
				sum(goal7_learn+goal8_shop) as ga_actions_old format comma8.
			,	sum(convertsubmit_contact+convertsubmit_quote) as ga_leads format comma8.
			,	sum(sessions) As sessions format comma8.
			into :act, :lead, :visit
			from better_way;
			title;
		quit;

		%check_for_data(linkedin.b2b_campaign_master_linkedin,=0,No records in linkedin.b2b_campaign_master_linkedin);

%end; /* (10) */

%if %eval(&valid_spend ne &spend) 
		or %eval(&valid_eng ne &eng)
		or %eval(&valid_visit ne &visit)
		%then %do;
			%let cancel=cancel;
			%put Error: Raw data not properly appended to campaign master.
%end;

%if &cancel= and &Nnew > 0 %then %do; /* (11) */

	/* -------------------------------------------------------------------------------------------------*/
	/*  Export and archive.                                                                             */
	/* -------------------------------------------------------------------------------------------------*/

		data linkedin.B2B_Campaign_Master_Temp;
			set prod.B2B_Campaign_Master;
		run;


		proc sql;
		insert into prod.B2B_Campaign_Master
			select 
				*
			,	.
			, 	.
			,	.
			,	.
			, 	.
			,	.
			,	.
			, 	.
			,	.
			,	.
			, 	.
			,	.
			,	.
			, 	.
			,	.
			,	.
			, 	.
			,	.
			,	.
			,	.
			,	.
			,	.
			,	.
			,	.
			,	.
			,	.
			,	.
			,	.
			,	.
			,	.
			,	.
			,	.
			,	.
			,	.
			,	datetime()
			from linkedin.b2b_campaign_master_linkedin;
		quit;


	* If you added/removed or changed the formatting of a variable, run this instead;
/**/
/*		proc delete data=prod.B2B_Campaign_Master; run;*/
/*		data prod.B2B_Campaign_Master;*/
/*			set linkedin.b2b_campaign_master_linkedin(in=a) */
/*				linkedin.B2B_Campaign_Master_Temp(in=b);*/
/*			if a then Rec_Update_Date = datetime(); */
/*		run;*/

	/* -------------------------------------------------------------------------------------------------*/
	/*  Save master file --> zip archive.                                                               */
	/* -------------------------------------------------------------------------------------------------*/

		proc sql ;
			select distinct
				min(date) format mmddyy6.,
				max(Date) format mmddyy6.
			into :FirstData,
				 :LastData
			from prod.B2B_Campaign_Master;
		quit;

		data archive.B2B_Campaign_&FirstData._&LastData;
			set prod.B2B_Campaign_Master;
		run;

		ods package(archived) open nopf;
		ods package(archived) add file="&output_files/Archive/b2b_campaign_&FirstData._&LastData..sas7bdat";
		ods package(archived) publish archive properties (
			archive_name="b2b_campaign_&FirstData._&LastData..zip"
			archive_path="&output_files/Archive/");
		ods package(archived) close;

		*Create the list of files, in this case all ZIP files;
		%list_files(&output_files./Archive,ext=zip);

		%let filename_oldarchive=DNE; *Initialize;
		proc sql ;
			select distinct
				the_name
			into :filename_oldarchive trimmed
			from list 
			where find(the_name,'b2b_campaign')>0 
				and the_name ne "b2b_campaign_&FirstData._&LastData.";
		quit;
		proc delete data=list; run;

		%macro old_arch;
			%if &filename_oldarchive ne DNE %then %do;
				filename old_arch "&output_files/Archive/&filename_oldarchive..zip";	
				data _null_;
					rc=fdelete("old_arch");
					put rc=;
				run;
			%end;
		%mend;
		%old_arch;

		* Clean up po_imca_digital;
		* Second backup of b2b_campaign_master;
		ods package(archived) open nopf;
		ods package(archived) add file="&input_files/b2b_campaign_master_temp.sas7bdat";
		ods package(archived) publish archive properties (
			archive_name="b2b_campaign_master_temp.zip"
			archive_path="&input_files/");
		ods package(archived) close;
		proc delete data=linkedin.b2b_campaign_master_temp; run;
		* Second backup of b2b_linkedin_raw;
		ods package(archived) open nopf;
		ods package(archived) add file="&input_files/b2b_linkedin_raw_temp.sas7bdat";
		ods package(archived) publish archive properties (
			archive_name="b2b_linkedin_raw_temp.zip"
			archive_path="&input_files/");
		ods package(archived) close;
		proc delete data=linkedin.b2b_linkedin_raw_temp; run;
		* Delete files from most recent update;
		proc delete data=linkedin.linkedin_clean_final; run;
		proc delete data=linkedin.campaign_merged; run;
		proc delete data=linkedin.b2b_campaign_master_linkedin; run;

	/* -------------------------------------------------------------------------------------------------*/
	/*  Frequency Tables.                                                                               */
	/* -------------------------------------------------------------------------------------------------*/ 

		proc sql; select distinct count(distinct date) into :days trimmed from prod.B2B_Campaign_Master where find(ChannelDetail,'Social-LinkedIn')>0 and Date >= "&Campaign_StartDate"d; quit;
		%put Days in newly added data: &days.;

		options dlcreatedir;
		libname freq xlsx "&input_files/Frequency Tables - Get_LinkedIn_Data_Weekly.xlsx"; run;
		proc sql;
		create table freq.'Final Append by Date'n as
			select distinct
				Date
			,	case when Date>="&Campaign_StartDate"d then 1 else 0 end as New_Data
			,	sum(impressions) as Impressions
			,	sum(clicks) as Clicks
			,	sum(sessions) as Sessions
			,	sum(clicks)/sum(impressions) as CTR
			,	sum(sessions)/sum(impressions) as Visit_Rt
			,	sum(weighted_actions) as GA_actions format comma8.
			,	sum(ConvertSubmit_Contact+ConvertSubmit_Quote+SB_MAS_Leads+ConvertNonSubmit_SSQ*0.43) as GA_leads format comma8.
			,	sum(weighted_actions)/sum(sessions) as Actions_Per_Visit			
			from prod.B2B_Campaign_Master
			where find(ChannelDetail,'Social-LinkedIn')>0
				and Date>=intnx('day',"&Campaign_StartDate"d,-&days.,'s')
			group by 
				Date
			order by 
				Date;
		quit;
		proc sql;
		create table freq.'Final Append by Program'n as
			select distinct
				ChannelDetail
			,	case when Date>="&Campaign_StartDate"d then 1 else 0 end as New_Data
			,	sum(impressions) as Impressions
			,	sum(clicks) as Clicks
			,	sum(sessions) as Sessions
			,	sum(clicks)/sum(impressions) as CTR
			,	sum(sessions)/sum(impressions) as Visit_Rt
			,	sum(weighted_actions) as GA_actions format comma8.
			,	sum(ConvertSubmit_Contact+ConvertSubmit_Quote+SB_MAS_Leads+ConvertNonSubmit_SSQ*0.43) as GA_leads format comma8.
			,	sum(weighted_actions)/sum(sessions) as Actions_Per_Visit
			from prod.B2B_Campaign_Master
			where find(ChannelDetail,'Social-LinkedIn')>0
				and Date>=intnx('day',"&Campaign_StartDate"d,-&days.,'s')
			group by 
				ChannelDetail
			,	case when Date>="&Campaign_StartDate"d then 1 else 0 end
			order by 
				ChannelDetail
			,	case when Date>="&Campaign_StartDate"d then 1 else 0 end;
		quit;
		proc sql;
		create table freq.'Final Append by Region'n as
			select distinct
				Region
			,	case when Date>="&Campaign_StartDate"d then 1 else 0 end as New_Data
			,	sum(impressions) as Impressions
			,	sum(clicks) as Clicks
			,	sum(sessions) as Sessions
			,	sum(clicks)/sum(impressions) as CTR
			,	sum(sessions)/sum(impressions) as Visit_Rt
			,	sum(weighted_actions) as GA_actions format comma8.
			,	sum(ConvertSubmit_Contact+ConvertSubmit_Quote+SB_MAS_Leads+ConvertNonSubmit_SSQ*0.43) as GA_leads format comma8.
			,	sum(weighted_actions)/sum(sessions) as Actions_Per_Visit
			from prod.B2B_Campaign_Master
			where find(ChannelDetail,'Social-LinkedIn')>0
				and Date>=intnx('day',"&Campaign_StartDate"d,-&days.,'s')
			group by 
				Region
			,	case when Date>="&Campaign_StartDate"d then 1 else 0 end 
			order by 
				Region
			,	case when Date>="&Campaign_StartDate"d then 1 else 0 end;
		quit;

%end; /* if &Nnew > 0 */

/* -------------------------------------------------------------------------------------------------*/
/*  Email log.                                                                                      */
/* -------------------------------------------------------------------------------------------------*/ 

	/* you may change the default sentFrom and sentTo */
	%emailB2Bdashboard(Get_LinkedIn_Data_Weekly,
			attachFreqTableFlag=1,
			attachLogFlag=1 /*,
			sentFrom=,
			sentTo= */
			);	

	proc printto; run; /* Turn off log export to .txt */
