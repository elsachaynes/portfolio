/****************************************************************************************************/
/*  Program Name:       Get_PaidSearch_Data_Weekly.sas                                              */
/*                                                                                                  */
/*  Date Created:       Mar 12, 2021                                                                */
/*                                                                                                  */
/*  Created By:         Elle Haynes                                                                 */
/*                                                                                                  */
/*  Purpose:            Compiles daily LG and SB Paid Seach data.                                   */
/*                                                                                                  */
/*  Inputs:             SA360 Paid Search "Business" engine data.                                   */
/*                                                                                                  */
/* -------------------------------------------------------------------------------------------------*/	
/*  Notes:                                                                                          */
/* -------------------------------------------------------------------------------------------------*/
/*  Date Modified:      Apr 19, 2021                                                                */
/*  Modified by:        Elle Haynes                                                                 */
/*  Description:        Changed output file path /gpfsFS2/sasdata/nfs/ndc_grid/po_imca_product/B2B  */
/*                                                                                                  */
/*  Date Modified:      Jun 15, 2021                                                                */
/*  Modified by:        Elle Haynes                                                                 */
/*  Description:        Changed input file to come from SA360 (API call) in external program        */
/*                      instead of Connex extracts.                                                 */
/*                                                                                                  */
/*  Date Modified:      Oct 27, 2021                                                                */
/*  Modified by:        Elle Haynes                                                                 */
/*  Description:        Campaign naming standaridzation updated. Modified UTM_Campaign parsing.     */
/*                      Changed raw data input path.                                                */
/*                                                                                                  */
/*  Date Modified:      April 21, 2022                                                              */
/*  Modified by:        Elle Haynes                                                                 */
/*  Description:        Changed email output to use new email macro: SAS_Macro_Email.               */
/****************************************************************************************************/

/* -------------------------------------------------------------------------------------------------*/
/*  Run libraries                                                                                   */
/* -------------------------------------------------------------------------------------------------*/
    Options mlogic mprint symbolgen;
	filename old_log "/gpfsFS2/sasdata/nfs/ndc_grid/po_imca_digital/EHaynes/B2B Dashboard Data Processing/Paid Search/B2B and SB/LOG Get_PaidSearch_Data_Weekly.txt";
	data _null_; rc=fdelete("old_log"); put rc=; run;
	proc printto log="/gpfsFS2/sasdata/nfs/ndc_grid/po_imca_digital/EHaynes/B2B Dashboard Data Processing/Paid Search/B2B and SB/LOG Get_PaidSearch_Data_Weekly.txt"; run;

	%let error_rsn=Error in libraries statements.;

	* Raw Data Download Folder;
	%let raw_file_path = /gpfsFS2/sasdata/nfs/ndc_grid/po_imca_digital/EHaynes/B2B Dashboard Data Processing/_Raw Data Downloads;
	libname import "&raw_file_path";

	* Paid Search Working Folder;
	%let input_files = /gpfsFS2/sasdata/nfs/ndc_grid/po_imca_digital/EHaynes/B2B Dashboard Data Processing/Paid Search/B2B and SB;
	libname ps "&input_files";

	* Output;
	%let final_file_path = /gpfsFS2/sasdata/adhoc/po/imca/product/B2B;
	libname final "&final_file_path";
	libname archive "&final_file_path/Archive";

	%let production_path= /gpfsFS2/sasdata/nfs/ndc_grid/po_imca_product/B2B;
	libname prod "&production_path";

	%let dt=.; *"31dec2020"d; *leave empty unless running manually;
	%let nfiles=0; *initialize, the number of xlsx files in the input_files directory;
	%let Nnew=0; *initialize, the number of new records to be processed.;
	%let N=; *initialize;
	%let cancel=; *initialize, the flag to cancel the process.;
	%let Campaign_StartDate=Start; %let Campaign_EndDate=End; %let nRaw=0; %let nCamLG=0; %let nCamSB=0; %let nCamOT=0; %let the_name=File;

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

	options mprint;
	%list_files(&raw_file_path,ext=csv);

	proc sql ;
		select 
			count(*)
		,	count(*)
		,	the_name
		into :nfiles,
			 :nfiles_orig,
			 :the_name separated by '|' 
		from list
		where find(the_name,'Business-report-')>0;
	quit;

	%let error_rsn = CSV not found in directory.;

/* -------------------------------------------------------------------------------------------------*/
/*                                                                                                  */
/*                                                                                                  */
/*                                         Ingest Raw Data                                          */
/*                                                                                                  */
/*                                                                                                  */
/* -------------------------------------------------------------------------------------------------*/

	%if &nfiles_orig>0 %then %do; /* (1) */

		proc sql ;
			select distinct
				max(Date) format mmddyy6.
			,	max(Date) format date9.
			into :LastData_Old trimmed,
				 :LastData_OldNum trimmed
			from final.B2B_PaidSearch_Raw
			where year(today())-year(date)<2;
		quit;

		/* -------------------------------------------------------------------------------------------------*/
		/*  Import Raw Paid Search data from SA360 (manually downloaded)                                    */
		/* -------------------------------------------------------------------------------------------------*/

		%let error_rsn=Error pulling raw data from CSV;

		%macro import_raw();
		%let i = 1;
		%let nfiles_orig = &nfiles;
		%do %while (&nfiles > 0);
			
			%let the_name_import = %sysfunc(scan(&the_name,&i,%quote(|)));

			data raw_import_&i.;

		        infile "&raw_file_path/&the_name_import..csv"
				delimiter = "," missover dsd lrecl=32767 firstobs=2 ;

				informat Keyword $250. ;
				informat Ad_Group $50. ;
				informat Campaign $250. ;
				informat Match_Type $7. ;
				informat Date ANYDTDTE. ;
				informat SA360_Cost 8. ;
				informat Impressions comma18. ;
				informat Clicks 8. ;
				informat Quality_Score 8. ;
				informat Business_Actions 8.2 ;
				informat Business_Leads 8. ;
				informat ConvertSubmit_Contact 8. ;
				informat ConvertSubmit_Quote 8. ;
				informat ConvertNonSubmit_SSQ 8. ;
				informat SB_MAS_Leads 8. ;
				informat LandingPage $250. ;

				format Keyword $250. ;
				format Ad_Group $50. ;
				format Campaign $250. ;
				format Match_Type $7. ;
				format Date mmddyy10. ;
				format SA360_Cost dollar18.2 ;
				format Impressions comma18. ;
				format Clicks comma8. ;
				format Quality_Score 8. ;
				format Business_Actions 8.2 ;
				format Business_Leads 8. ;
				format ConvertSubmit_Contact 8. ;
				format ConvertSubmit_Quote 8. ;
				format ConvertNonSubmit_SSQ 8. ;
				format SB_MAS_Leads 8. ;
				format LandingPage $250. ;
				
				input
					 Keyword	$
					 Ad_Group	$ 
					 Campaign	$ 
					 Match_Type $ 
					 Date 
					 SA360_Cost 
					 Impressions  
					 Clicks 
					 Quality_Score 
					 Business_Actions  
					 Business_Leads  
					 ConvertSubmit_Contact  
					 ConvertSubmit_Quote  
					 ConvertNonSubmit_SSQ  
					 SB_MAS_Leads 
					 LandingPage  
					 ;

			run;

			%let nfiles = %eval(&nfiles-1);
			%let i = %eval(&i+1);
			%put &nfiles &i;

		%end;

		%mend;
		%import_raw;

		data raw;
			set raw_import_:;
		run;
		%check_for_data(raw,=0,No data in raw paid search dataset);

	%end; /* &nfiles>0 */ /* (1) */
	%if &cancel= and &nfiles_orig>0 %then %do; /* (2) */

	/* -------------------------------------------------------------------------------------------------*/
	/*  Clean Raw Paid Search data                                                                      */
	/* -------------------------------------------------------------------------------------------------*/

		%let error_rsn=Error cleaning raw data step 1.;
	
		proc delete data=ps.ps_clean; run;
		data ps.ps_clean
			 Flagged_For_Review ;

			format Business_Size $3.
				   Keyword_Theme $50.
				   Keyword_Category $10.
				   Remarketing $2.
				   Ad_Group_1 $50.
				   Audience $50.
				   Engine $25.;

			set raw
				(rename=(Ad_Group = Ad_Group_2
						SA360_Cost = Cost)
				);

			* Filter to new data only;
			where Date > "&LastData_OldNum"d;

			* Flag display campaigns and bad Ad Groups for fixing in a subsequent step;
			if find(campaign,'MSAN','i') > 0 then Flag_Examine = 1;
			else if find(campaign,'GDN','i') > 0 then Flag_Examine = 1;
			else if find(ad_group_2,'pcrid','i') > 0 or find(ad_group_2,'|','i') > 0 then Flag_Examine = 1;
		
			* Parse the Campaign;
			campaign_2 = strip(upcase(compress(scan(campaign,2,'_')))); /* lob */
			campaign_3 = strip(upcase(compress(scan(campaign,3,'_')))); /* business_size */
			campaign_4 = strip(upcase(compress(scan(campaign,4,'_')))); /* channel */
			campaign_5 = strip(upcase(compress(scan(campaign,5,'_')))); /* publisher */
			campaign_6 = strip(upcase(compress(scan(campaign,6,'_')))); /* region */
			campaign_7 = strip(upcase(compress(scan(campaign,7,'_')))); /* subregion */
			campaign_8 = strip(upcase(compress(scan(campaign,8,'_')))); /* dma */
			campaign_9 = strip(upcase(compress(scan(campaign,9,'_')))); /* initiative/keyword theme */
			campaign_10 = strip(upcase(compress(scan(campaign,10,'_')))); /* audience/theme */
			campaign_11 = strip(upcase(compress(scan(campaign,11,'_')))); /* sub-theme */
			campaign_12 = strip(upcase(compress(scan(campaign,12,'_')))); /* keyword_category */
			campaign_13 = strip(upcase(compress(scan(campaign,13,'_')))); /* remarketing/tactic */
			campaign_14 = strip(compress(scan(campaign,14,'_'))); /* audience */
			campaign_15 = strip(compress(scan(campaign,15,'_'))); /* match_type */
			campaign_16 = strip(compress(scan(campaign,16,'_'))); /* language */
			campaign_17 = strip(compress(scan(campaign,17,'_'))); /* creative name */
			campaign_18 = strip(compress(scan(campaign,18,'_'))); /* creative size */

			* Standardize campaign to lowercase;
			Campaign = strip(lowcase(compress(Campaign,' ')));

			* Business_Size;	
			if campaign_2 = 'B2B' then Business_Size = campaign_3; 
				else Flag_Examine = 1;

			* Keyword_Theme;
			if campaign_9 = 'CON' then Keyword_Theme = 'Content';
				else if campaign_9 = 'EVG' then Keyword_Theme = 'Evergreen';
				else if campaign_9 = 'B2BEL' then Keyword_Theme = 'B2BEL';

			* Keyword_Category;
			Keyword_Category = tranwrd(campaign_12,'NBC','NBPK');
			Keyword_Category = tranwrd(Keyword_Category,'BRDC','BPK');
			Keyword_Category = tranwrd(Keyword_Category,'BRDEL','BPU-EL');
			Keyword_Category = tranwrd(Keyword_Category,'NBEL','NBPU-EL');

			* Remarketing;
			if find(campaign_13,'RTG')>0 then Remarketing = 'Y';
					else Remarketing = 'N';

			* Match Type;
			Match_Type = propcase(campaign_15);

			* Engine;
			if campaign_5 = 'BING' then Engine = 'Bing';
				else if campaign_5 = 'GGL' then Engine = 'Google';

			* Region & SubRegion;
			Region = campaign_6;
			SubRegion = campaign_7;	

			* Ad_Group;
			Ad_Group_1 = campaign_17;
				*Grouping;
				if Keyword_Theme = 'B2BEL' or Keyword_Category in ('BPU-EL','NBPU-EL') then Ad_Group_1 = 'EL-Terms';
				if Ad_Group_1 = 'Content' then do;
					if find(Ad_Group_2,'MHW-')>0 then Ad_Group_1 = 'Mental-Health-Wellness';
					else if find(Ad_Group_2,'SM-')>0 then Ad_Group_1 = 'Stress-Management';
					else if find(Ad_Group_2,'WP-')>0 then Ad_Group_1 = 'Wellness-Program';
				end;

				*Cleaning;
				Ad_Group_2 = tranwrd(tranwrd(tranwrd(Ad_Group_2,'MH&W','MHW'),'MW&H','MHW'),'MHW - ','MHW-');
				Ad_Group_2 = tranwrd(Ad_Group_2,'Return to Work','RTW');
				if Ad_Group_1 = 'RTW-1' then Ad_Group_1 = 'RTW';
				if find(Ad_Group_1,'OTJ')>0 then Ad_Group_1 = 'OTJ'; /* Includes "OTJ-1" and "OTJ-2" */
				if find(Ad_Group_2,'Virtual Care')>0 then Ad_Group_2 = 'VirtualCare';

				*Initiative Distinction;
				if Audience = 'INTV' or Ad_Group_1 in ('RTW','RTW-1','MentalHealth&Wellness','VirtualCare')
					then Keyword_Theme = 'Initiative-PO';
				if Ad_Group_1 in ('OTJ','VirtualForward') then Keyword_Theme = 'Initiative-Regional';
				if Ad_Group_1 in ('MentalHealth&Wellness','OTJ','RTW','VirtualCare','VirtualForward')
					then Ad_Group_1 = catt('Initiative-',Ad_Group_1);
				Ad_Group_1 = tranwrd(Ad_Group_1,'MentalHealth&Wellness','MHW');

			* Channel;
			Channel = catt('Paid Search-',Business_Size);

			* Audience;
			if campaign_10 = 'BSU' or campaign_11 = 'BSU' or Ad_Group_1 in ('Mental-Health-Wellness',
				'Stress-Management','Wellness-Prograrm') 
					then Audience = 'Business Size Unknown';
				else if Keyword_Theme = 'B2BEL' then Audience = 'EL';
				else Audience = Business_Size;

			* Replace missing numeric w/ 0;
			 array change _numeric_;
		        do over change;
		            if change=. then change=0;
		        end;

			* If display network stats;
			if lowcase(strip(Keyword)) = 'display network stats' then delete;

			if Flag_Examine = 1 then output Flagged_For_Review;
				else output ps.ps_clean;

		run;

		proc sql; select distinct count(*) into :Nnew from ps.ps_clean; quit;

/*		proc freq data=ps.ps_clean;*/
/*			tables */
/*					ad_group_1*keyword_theme*/
/*					ad_group_1*/
/*					Ad_Group_2*/
/*					keyword_category*/
/*					remarketing*/
/*					engine*/
/*					match_type*/
/*					audience*/
/*					region*subregion*/
/*					channel*business_size*/
/*					Quality_Score*/
/*					landingpage*/
/*					landingpage*audience*/
/*			/ norow nocol nopercent missing;*/
/*		run;*/

		%check_for_data(ps.ps_clean,=0,No data in ps_clean);
		proc delete data=raw; run &cancel.;
	%end; /* (2) */

	%let error_rsn = No new records found in raw dataset.;

	%if &cancel= and &Nnew>0 %then %do; *execute only if data found; /* (3) */

		%let error_rsn=Error cleaning raw data step 2.;

		data flagged_for_review_clean; 
			set flagged_for_review; 

			* Missing Campaign;
			if campaign in ('(notset)','{dscampaign}') then do;
				/* Delete if likely other LOB */
				if cost = 0 
					and impressions = 0 
					and clicks = 0 
					then delete;
				Business_Size = 'UN';
				Channel = 'Paid Search-UN';
				Region = 'UN';
				SubRegion = 'UN';
				Remarketing = 'UN';
				Engine = 'UN';
				Match_Type = 'UN';
				Keyword_Category = 'UN';
				Keyword_Theme = 'UN';
				Ad_Group_1 = 'UN';
				Ad_Group_2 = 'UN';
				Audience = 'UN';
				if Campaign = '(notset)' then Campaign = '(not set)';
				Flag_Examine = 0;
			end;

			* Small Business Display Remarketing - MSAN;
			else if find(campaign,'MSAN','i') > 0 then do;
				Business_Size = campaign_2;
				Channel = 'Display SB';
				Region = campaign_3;
				SubRegion = 'NON';
				Remarketing = 'Y';
				Engine = 'MSAN';
				Match_Type = 'N/A';
				Keyword_Category = 'N/A';
				Keyword_Theme = 'N/A';
				Ad_Group_1 = 'N/A';
				Ad_Group_2 = 'N/A';
				Audience = 'SB';
				Flag_Examine = 0;
			end;

			* Small Business Display Remarketing - GDN;
			else if find(campaign,'GDN','i') > 0 then do;
				Business_Size = campaign_3;
				Channel = 'Display SB';
				Region = campaign_5;
				SubRegion = campaign_6;
				Remarketing = 'Y';
				Engine = 'GDN';
				Match_Type = 'N/A';
				Keyword_Category = 'N/A';
				keyword_Theme = 'N/A';
				Ad_Group_1 = 'N/A';
				Ad_Group_2 = 'N/A';
				Audience = 'SB';
				Flag_Examine = 0;
			end;

			* Delete Enterprise Listing;
			else if campaign_2 = 'EL' then delete;

			* Old Campaign Naming Convention;
			else if campaign_2 ne 'B2B' then do;
				if campaign_2 in ('SBCA','SBCO','SBHI','SBNW') then Business_Size = 'SB';
				Channel = catt('Paid Search-',Business_Size);
				Region = campaign_3;
				SubRegion = 'NON';
				if campaign_12 = 'RLSAY' then Remarketing = 'Y'; 
					else Remarketing = 'N';
				*if campaign_5 = 'BNG' then Engine = 'Bing';
					*else if campaign_5 = 'GGL' then Engine = 'Google';
				Match_Type = propcase(campaign_8);
				Keyword_Category = 'UN';
				Keyword_Theme = 'UN';
				Ad_Group_1 = 'UN';
				Ad_Group_2 = 'UN';
				Audience = 'UN';
				Flag_Examine = 0;
			end;

			* Ad Group Error;
			if find(ad_group_2,'pcrid','i') > 0 or find(ad_group_2,'|','i') > 0 then do;
				Ad_Group_2 = 'UN';
				Flag_Examine = 0;
			end;

		run;
		proc delete data=flagged_for_review; run;
		 
	/* -------------------------------------------------------------------------------------------------*/
	/*  Final Raw Paid Search File                                                                      */
	/* -------------------------------------------------------------------------------------------------*/

		%let error_rsn=Error cleaning raw data step 4.;

		proc sql;
		create table ps.ps_clean_final as
		select distinct
				Date format mmddyy10.
			,	strip(put(Year(Date),8.)) as Year
			,	catt('Q',qtr(date)) as Quarter format $2.
			,	strip(lowcase(Keyword)) as Keyword format $250.
			,	Campaign
			,	sum(Cost) as Cost format dollar18.2
			,	sum(Impressions) as Impressions format comma18.
			,	sum(Clicks) as Clicks format comma18.
			,	Ad_Group_1 as Ad_Group
			,	max(Ad_Group_2) as Ad_Group_Detail /* Dupes */
			,	Business_Size
			,	Channel
			,	Engine
			,	Match_Type
			,	Keyword_Theme
			,	Keyword_Category
			,	Audience
			,	Remarketing
			,	Region
			,	SubRegion 
			,	max(Quality_Score) as Quality_Score /* Dupes */
			,	LandingPage
			,	sum(Business_Actions) as Business_Actions format comma8.2
			,	sum(Business_Leads) as Business_Leads format comma8.
			,	sum(ConvertSubmit_Contact) as ConvertSubmit_Contact format comma8.
			,	sum(ConvertSubmit_Quote) as ConvertSubmit_Quote format comma8.
			,	sum(ConvertNonSubmit_SSQ) as ConvertNonSubmit_SSQ format comma8.
			,	sum(SB_MAS_Leads) as SB_MAS_Leads format comma8.
			,	0 as Hist_Goal_7_Learn format comma8.
			,	0 as Hist_Goal_8_Shop format comma8.
			,	0 as Hist_Goal_11_Ebook_FT format comma8.
			from (select * from ps.ps_clean
						union
				  select * from flagged_for_review_clean)
			group by 
				Date 
			,	strip(put(Year(Date),8.))
			,	catt('Q',qtr(date)) 
			,	Keyword
			,	Campaign
			,	Ad_Group_1 
/*			,	Ad_Group_2 */
			,	Business_Size
			,	Channel
			,	Engine
			,	Match_Type
			,	Keyword_Theme
			,	Keyword_Category
			,	Audience
			,	Remarketing
			,	Region
			,	SubRegion 
/*			,	Quality_Score*/
			,	LandingPage;
		quit; 
		%check_for_data(ps.ps_clean_final,=0,No data in final raw paid search dataset);

	%end; /* (3) */
	%if &cancel= and &Nnew>0 %then %do; /* (4) */

		proc sql;
			create table check_dups as
			select 
				t1.* , t2.ndups
			from ps.ps_clean_final t1
				, (select 
						date, campaign, keyword, count(*) as ndups
				   from ps.ps_clean_final
				   group by date, campaign, keyword
				   ) t2
			where t2.ndups>1 
				and t1.date=t2.date  
				and t1.campaign=t2.campaign
				and t1.keyword=t2.keyword
			order by t1.date, t1.keyword, t1.campaign;
		quit;

		proc sort data=ps.ps_clean_final; by date campaign keyword engine descending cost descending clicks; run;
		data ps.ps_clean_final;
			set ps.ps_clean_final;
			by date campaign keyword engine descending cost descending clicks; 
			if first.keyword then output;
		run;
	
		proc sql;
			create table check_dups as
			select 
				t1.* , t2.ndups
			from ps.ps_clean_final t1
				, (select 
						date, engine, campaign, keyword, count(*) as ndups
				   from ps.ps_clean_final
				   group by date, engine, campaign, keyword
				   ) t2
			where t2.ndups>1 
				and t1.date=t2.date 
				and t1.engine=t2.engine 
				and t1.campaign=t2.campaign
				and t1.keyword=t2.keyword
			order by t1.date, t1.engine, t1.campaign, t1.keyword;
		quit;
		%check_for_data(check_dups,>0,Dupes in final raw paid search);
	%end; /* (4) */	 
	%if &cancel= and &Nnew>0 %then %do; /* (5) */

		/* Validation */
/*		proc freq data=ps.ps_clean_final;*/
/*			tables */
/*					ad_group*keyword_theme*/
/*					ad_group*/
/*					keyword_category*/
/*					remarketing*/
/*					engine*/
/*					match_type*/
/*					audience*/
/*					region*subregion*/
/*					channel*business_size*/
/*					Quality_Score*/
/*					landingpage*/
/*					landingpage*audience*/
/*			/ norow nocol nopercent missing;*/
/*		run;*/
		proc sql;
		select distinct 
			intnx('week',Date,0,'b') as WeekStart format mmddyy10.
		,	sum(cost) as cost format dollar18.2
		,	sum(impressions) as impressions format comma18.
		,	sum(clicks) as clicks format comma18.
		,	sum(clicks)/sum(impressions) as CTR format percent7.2
		,	sum(cost)/sum(clicks) as CPC format dollar18.2
		,	sum(business_actions) as Actions_Weighted format comma8.2
		,	sum(business_leads) as Leads format comma8. 
/*		,	sum(ConvertSubmit_Quote+ConvertSubmit_Contact+SB_MAS_Leads+ConvertNonSubmit_SSQ*0.43) as Leads2 format comma8.*/
		from ps.ps_clean_final
		group by 
			intnx('week',Date,0,'b');
		quit;

	/* -------------------------------------------------------------------------------------------------*/
	/*  Export and archive raw paid search.                                                                 */
	/* -------------------------------------------------------------------------------------------------*/

		data ps.B2B_PaidSearch_Raw_Temp;
			set final.B2B_PaidSearch_Raw;
		run;

		proc sql;
		insert into final.B2B_PaidSearch_Raw
			select 
				* 
			from ps.ps_clean_final;
		quit;

	* If you added/removed or changed the formatting of a variable, run this instead;		

/*		proc delete data=final.B2B_PaidSearch_Raw; run;*/
/*		data final.B2B_PaidSearch_Raw;*/
/*			set ps.ps_clean_final*/
/*				ps.B2B_PaidSearch_Raw_Temp; */
/*		run;*/

	/* -------------------------------------------------------------------------------------------------*/
	/*  Save master file --> zip archive.                                                               */
	/* -------------------------------------------------------------------------------------------------*/

		proc sql noprint;
			select distinct
				min(Date) format mmddyy6.,
				max(Date) format mmddyy6.
			into :FirstData_Raw,
				 :LastData_Raw
			from final.B2B_PaidSearch_Raw;
		quit;

		proc sql noprint;
			select
				min(Date) format YYMMDDd10.,
				max(Date) format YYMMDDd10.,
				min(Date) format date9.,
				max(Date) format date9.
			into :FirstData_input,
				 :LastData_input,
				 :FirstDate_ThisUpdate,
				 :LastDate_ThisUpdate
			from ps.ps_clean_final;
		quit;

		data archive.B2B_PaidSearch_Raw_&FirstData_Raw._&LastData_Raw;
			set final.B2B_PaidSearch_Raw;
		run;

		ods package(archived) open nopf;
		ods package(archived) add file="&final_file_path/Archive/b2b_paidsearch_raw_&FirstData_Raw._&LastData_Raw..sas7bdat";
		ods package(archived) publish archive properties (
			archive_name="b2b_paidsearch_raw_&FirstData_Raw._&LastData_Raw..zip"
			archive_path="&final_file_path/Archive/");
		ods package(archived) close;
		proc delete data=archive.b2b_paidsearch_raw_&FirstData_Raw._&LastData_Raw; run;

		filename old_arch "&final_file_path/Archive/b2b_paidsearch_raw_&FirstData_Raw._&LastData_Old..zip";
		data _null_;
			rc=fdelete("old_arch");
			put rc=;
		run; 

	/* -------------------------------------------------------------------------------------------------*/
	/*  Save input file(s) --> zip archive.                                                                */
	/* -------------------------------------------------------------------------------------------------*/

	%macro zip();
		%let i = 1;
		%do %while (&nfiles_orig > 0);
			
			%let the_name_arch = %sysfunc(scan(&the_name,&i,%quote(|)));

			ods package(archived) open nopf;
			ods package(archived) add file="&raw_file_path/&the_name_arch..csv";
			ods package(archived) publish archive properties (
				archive_name="&the_name_arch..zip"
				archive_path="&input_files/Raw SA360 Archive/");
			ods package(archived) close;

			filename import "&raw_file_path/&the_name_arch..csv";
			data _null_;
				rc=fdelete("import");
				put rc=;
			run;
			
			proc delete data=raw_import_&i.; run;

			%let nfiles_orig = %eval(&nfiles_orig-1);
			%let i = %eval(&i+1);
			%put &nfiles_orig &i;
		%end;
	%mend;
	%zip;

	%end;
	%if &cancel= and &Nnew>0 %then %do;
			
/* -------------------------------------------------------------------------------------------------*/
/*                                                                                                  */
/*                                                                                                  */
/*                                    Prepare for Campaign Dataset                                  */
/*                                                                                                  */
/*                                                                                                  */
/* -------------------------------------------------------------------------------------------------*/

* Jan 1, 2021 data and forward;

/* -------------------------------------------------------------------------------------------------*/
/*  Engine metrics from newly-added b2b_paidsearch_raw.                                             */
/* -------------------------------------------------------------------------------------------------*/
	
	%let error_rsn=Error compiling engine metrics.;

	proc sql;
		create table paid_search_lg as
			select distinct
				Date format mmddyy10.
			,	intnx('week',Date,0,'b') as WeekStart format mmddyy10.
			,	intnx('month',Date,0,'b') as Month format monyy7. 
			,	Quarter format $2.
			,	'Paid Search' as Channel format $25.
			,	Channel as ChannelDetail format $25.
			,	Impressions format comma18.
			,	Clicks format comma8.
			,	Cost as Spend format dollar18.2
			,	Keyword format $250.
			,	Campaign format $250.
			,	Engine as Network format $25.
			,	Region format $5.
			,	SubRegion format $5.
			,	case when Keyword_Theme = 'Initiative-PO' then 'Value Demonstration'
					 when Keyword_Theme = 'Initiative-Regional' then 'Regional Initiatives'
					 else 'Always On' 
					 end as Program_Campaign format $30.
			,	case when Keyword_Theme in ('Initiative-PO','Initiative-Regional')
					then Ad_Group 
					else Keyword_Theme 
					end as Theme format $50.
			,	Ad_Group_Detail as Creative format $200.
			,	Match_Type format $6.
			,	Remarketing format $3.
			,	Keyword_Category format $7.
			,	Audience format $50.
			,	Business_Actions format comma8.2
			,	Business_Leads format comma8.
				/* Join Metrics */
			,	lowcase(Engine) as UTM_Source
			,	'cpc' as UTM_Medium
			,	Campaign as UTM_Campaign
			,	'' as UTM_Content /* not applicable */
			,	Keyword as UTM_Term 
			from ps.ps_clean_final
			order by 
				Date
			,	Channel;
		quit;
		%check_for_data(paid_search_lg,=0,No data in paid search dataset for merge);

	%end;
	%if &cancel= and &Nnew>0 %then %do;
		proc sql;
			create table check_dups as
			select 
				t1.* , t2.ndups
			from paid_search_lg t1
				, (select 
						date, utm_source, utm_medium, utm_campaign, utm_content, utm_term, count(*) as ndups
				   from paid_search_lg
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
		%check_for_data(check_dups,>0,Dupes in display paid search for merge);
	%end;
	%if &cancel= and &Nnew>0 %then %do;

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
		from paid_search_lg;
		quit;

		proc sql;
		create table better_way_lg as
			select distinct
				Date
			,	UTM_Source
			,	UTM_Medium
			,	case when UTM_Campaign in ('(notset)','(not set)','{dscampaign}','{_dscampaign}','')
					then '_error_' /* Prevent joining on bad data */
					else UTM_Campaign
					end as UTM_Campaign format $250.
			,	'' as UTM_Content /* not applicable */
			,	case when UTM_Term in ('(not set)','{keyword}','')
					then '_error_' /* Prevent joining on bad data */
					else UTM_Term 
					end as UTM_Term format $250.
			,	max(PromoID) as PromoID format $6. /* dupes */
			,	sum(users) as Users
			,	sum(newusers) as newUsers
			,	sum(Sessions) as Sessions
			,	sum(Bounces) as Bounces
			,	sum(SessionDuration) as SessionDuration
			,	sum(uniquePageviews) as UniquePageviews
			,	sum(ShopActions_Unique) as ShopActions_Unique
			,	sum(LearnActions_Unique) as LearnActions_Unique
/*			,	sum(ConvertActions_Unique) as ConvertActions_Unique*/
/*			,	sum(ShareActions_Unique) as ShareActions_Unique*/
			,	sum(goal7_Learn) as goal7_Learn /* redundant to sum of Learn */
			,	sum(goal8_Shop) as goal8_Shop /* redundant to sum of Shop */

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
			where lowcase(UTM_Medium) = 'cpc'
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
			,	case when UTM_Term in ('(not set)','{keyword}','')
				then '_error_' /* Prevent joining on bad data */
				else UTM_Term 
				end;
		quit;
		%check_for_data(better_way_lg,=0,No data in better way dataset for merge);
	%end;
	%if &cancel= and &Nnew>0 %then %do;
		proc sql;
			create table check_dups as
			select 
				t1.* , t2.ndups
			from better_way_lg t1
				, (select 
						date, utm_source, utm_medium, utm_campaign, utm_content, utm_term, count(*) as ndups
				   from better_way_lg
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
		%check_for_data(check_dups,>0,Dupes in display paid search for merge);
	%end;
	%if &cancel= and &Nnew>0 %then %do;

	/* -------------------------------------------------------------------------------------------------*/
	/*  Merge engine metrics with Google Analytics metrics                                              */
	/* -------------------------------------------------------------------------------------------------*/
		
		%let error_rsn=Error merging tables.;

		proc sort data=better_way_lg; by date utm_source utm_medium utm_campaign utm_content utm_term; run;
		proc sort data=paid_search_lg; by date utm_source utm_medium utm_campaign utm_content utm_term; run;

		data paidsearch_lg_merged
			 missing
			 otherlob; 

			 length UTM_Source $12. 
					Network $12.
					Program_Campaign $25.;

			merge paid_search_lg (in=a)
				  better_way_lg (in=b);
			by date utm_source utm_medium utm_campaign utm_content utm_term;

			* Halo flag initialize;
			Halo_Actions = 0;

			if find(UTM_Campaign,'test_kp') > 0 then delete;

			if a then output paidsearch_lg_merged;

				else do;

				WeekStart=intnx('week',Date,0,'b');
				Month=intnx('month',Date,0,'b');
				Quarter=catt('Q',qtr(date));
	
				* Halo LG/SB in current campaign format;
				if find(UTM_campaign,'kp_b2b_lg') > 0 
							or find(UTM_campaign,'kp_b2b_sb') > 0
							or find(UTM_campaign,'kp_b2b_abm') > 0 then do;
					Channel='Paid Search';
					if upcase(scan(UTM_Campaign,2,'_')) = 'B2B' then ChannelDetail = catt('Paid Search-',upcase(scan(UTM_Campaign,3,'_'))); 
					Keyword=UTM_Term;
					Campaign=UTM_Campaign;
					Network=propcase(UTM_Source);
					if find(Campaign,'_ps_','i')=0 then do;
						Region=upcase(scan(campaign,5,'_'));
							if Region = 'KPWAS' then Region = 'KPWA';
						SubRegion=upcase(scan(campaign,6,'_'));
							if SubRegion = 'MRLD' then SubRegion = 'MD';
							else if SubRegion = 'VRGA' then SubRegion = 'VA';
							else if SubRegion = 'ORE' then SubRegion = 'OR';
							else if SubRegion = 'NA' then SubRegion = 'NON';
						if upcase(scan(campaign,8,'_')) = 'CON' then Theme = 'Content';
							else if upcase(scan(campaign,8,'_')) in ('EVG','COR') then Theme = 'Evergreen';
							if scan(campaign,14,'_') = 'mentalhealth' then Theme = 'Initiative-MHW';
								else if scan(campaign,14,'_') = 'otj' then Theme = 'Initiative-OTJ';
								else if scan(campaign,14,'_') = 'rtw' then Theme = 'Initiative-RTW';
								else if scan(campaign,14,'_') = 'virtualcare' then Theme = 'Initiative-VirtualCare';
								else if scan(campaign,14,'_') = 'virtualforward' then Theme = 'Initiative-VirtualForward';
								else if scan(campaign,3,'_') = 'abm' then Theme = 'Initiative-ABM';
								else if scan(campaign,9,'_') = 'phc' then Theme = 'Initiative-PHC';
								else if scan(campaign,8,'_') = 'tld' then Theme = 'Initiative-TLD';
						Creative=propcase(scan(campaign,14,'_'));
							if Creative='' then Creative = 'UN';
						if upcase(scan(campaign,12,'_')) = 'EXT' then Match_Type = 'Exact';
							else if upcase(scan(campaign,12,'_')) = 'BMM' then Match_Type = 'Broad';
							else if upcase(scan(campaign,12,'_')) = 'PHR' then Match_Type = 'Phrase';
							else Match_Type = 'UN';
						if upcase(scan(campaign,11,'_')) = 'RMK' then Remarketing = 'Y';
							else Remarketing = 'N';
						Keyword_Category=upcase(scan(campaign,10,'_'));
							if upcase(scan(campaign,9,'_'))='EL' then Keyword_Category = catt(Keyword_Category,'-EL');
						if upcase(scan(campaign,9,'_'))='BSU' or (Theme='Content' and upcase(scan(UTM_Campaign,3,'_'))='LG') then Audience = 'Business Size Unknown';
							else Audience=upcase(scan(campaign,9,'_'));
							if Audience='PHC' then Audience='LG';
							if Audience in ('NA','NON') then Audience=upcase(scan(UTM_Campaign,3,'_'));
						if Theme in ('Initiative-PHC','Initiative-TLD','Initiative-MHW','Initiative-VirtualCare','Initiative-RTW','Initiative-ABM') then Program_Campaign = 'Value Demonstration';
						 	else if Theme in ('Initiative-VirtualForward','Initiative-OTJ') then Program_Campaign = 'Regional Initiatives';
					 		else Program_Campaign = 'Always On';
					end;
					else if find(Campaign,'_ps_','i')>0 then do;
						Region=upcase(scan(campaign,6,'_'));
						SubRegion=upcase(scan(campaign,7,'_'));
						if upcase(scan(campaign,9,'_')) = 'CON' then Theme = 'Content';
							else if upcase(scan(campaign,9,'_')) = 'EVG' then Theme = 'Evergreen';
							else Theme = upcase(scan(campaign,9,'_'));
						if scan(campaign,17,'_') = 'mentalhealth' then Theme = 'Initiative-MHW';
							else if scan(campaign,17,'_') = 'otj' then Theme = 'Initiative-OTJ';
							else if scan(campaign,17,'_') = 'rtw' then Theme = 'Initiative-RTW';
							else if scan(campaign,17,'_') = 'virtualcare' then Theme = 'Initiative-VirtualCare';
							else if scan(campaign,17,'_') = 'virtualforward' then Theme = 'Initiative-VirtualForward';
						Creative=propcase(scan(campaign,17,'_'));
						Match_Type=propcase(scan(campaign,15,'_'));
						if find(scan(campaign,13,'_'),'RTG','i') then Remarketing = 'Y';
							else Remarketing = 'N';
						Keyword_Category=upcase(scan(campaign,12,'_'));
							Keyword_Category = tranwrd(Keyword_Category,'NBC','NBPK');
							Keyword_Category = tranwrd(Keyword_Category,'BRDC','BPK');
							Keyword_Category = tranwrd(Keyword_Category,'BRDEL','BPU-EL');
							Keyword_Category = tranwrd(Keyword_Category,'NBEL','NBPU-EL');	
						if upcase(scan(campaign,10,'_'))='BSU' or upcase(scan(campaign,11,'_'))='BSU' or (Creative='Content' and upcase(scan(UTM_Campaign,3,'_'))='LG') then Audience = 'Business Size Unknown';
							else if Theme = 'B2BEL' then Audience = 'EL';
							else Audience=upcase(scan(campaign,3,'_'));
						if Theme in ('Initiative-MHW','Initiative-VirtualCare','Initiative-RTW') then Program_Campaign = 'Value Demonstration';
						 	else if Theme in ('Initiative-VirtualForward','Initiative-OTJ') then Program_Campaign = 'Regional Initiatives';
					 		else Program_Campaign = 'Always On';
					end;
					/* Halo Action Flag */
					Halo_Actions = 1;
					output missing;
				end;

				else if find(UTM_Campaign,'kp_el_non') > 0 then output otherlob;
				else if find(UTM_Campaign,'kp_bnd_') > 0 then output otherlob;

				* Halo LG/SB in old campaign formats;
				* SB MSAN;
				else if find(UTM_Campaign,'msan','i') > 0 then do;
					Channel='Display';
					ChannelDetail='Display SB';
					Keyword='UN';
					Campaign=UTM_Campaign;
					Network='MSAN';
					Region=upcase(scan(campaign,3,'_'));
						if Region = 'IMA' then Region = 'UN';
					SubRegion='NON';
					Program_Campaign='Value Demonstration';
					Theme='UN';
					Creative='UN';
					Match_Type='UN';
					Remarketing='Y';
					Keyword_Category='UN';
					Audience='SB';
					/* Halo Action Flag */
					Halo_Actions = 1;
					output missing;
				end;

				* SB MAS GDN;
				else if find(UTM_Campaign,'small business_mas_gdn_remarketing','i') > 0 then do;
					Channel='Display';
					ChannelDetail='Display SB';
					Keyword='UN';
					Campaign=UTM_Campaign;
					Network='GDN';
					Region='MAS';
					SubRegion=upcase(scan(campaign,5,'_'));
					Program_Campaign='Regional Initiatives';
					Theme='UN';
					Creative='UN';
					Match_Type='UN';
					Remarketing='Y';
					Keyword_Category='UN';
					Audience='SB';
					/* Halo Action Flag */
					Halo_Actions = 0;
					output missing;
				end;

				* Halo LG/SB in old campaign formats;
				else if find(UTM_campaign,'kp_b2bl') > 0 
					 or (find(UTM_Campaign,'kp_sb') > 0 
						and find(UTM_Campaign,'mm0') > 0)
					 /* SB GDN */
					 or (find(UTM_Campaign,'kp_sb') > 0 
						and find(UTM_Campaign,'gnd_rmk') > 0)
					 /* SB Yahoo Gemini */
					 or find(UTM_Campaign,'smallbusinessowners') 
					 or find(UTM_campaign,'kp_bnd') > 0 then do;

					 Channel='Paid Search';
					 if find(UTM_campaign,'kp_b2bl')>0 then ChannelDetail='Paid Search-LG';
					 	else if find(UTM_campaign,'kp_sb')>0 then ChannelDetail='Paid Search-SB';
					 Keyword=UTM_Term;
					 Campaign=UTM_Campaign;
					 Network=propcase(UTM_Source);
					 	if Network='Yahoo_gemini' then Network='Yahoo';
					 Region=upcase(scan(campaign,3,'_'));
					 	if Region='MAST' then Region = 'MAS';
						if region not in ('CLRD','GRGA','HWAI','KPWA','MAS','NCAL','PCNW','SCAL','UN') then Region='HWAI';
					 if find(UTM_campaign,'kp_sb')>0 then SubRegion=upcase(scan(campaign,15,'_'));
					 	if SubRegion='WASHINGTON' then SubRegion = 'WAS';
							else if SubRegion = 'OREGON' then SubRegion = 'OR';
						else SubRegion='NON';
					 if find(UTM_campaign,'kp_b2bl')>0 then Theme=propcase(scan(campaign,14,'_'));
					 	else if find(UTM_campaign,'kp_sb')>0 then Theme='Evergreen';
					 if find(UTM_campaign,'kp_b2bl')>0 then Creative=propcase(scan(campaign,15,'_'));
					 	else if find(UTM_campaign,'kp_sb')>0 then Creative=propcase(scan(campaign,13,'_'));
						if Creative='' then Creative='UN';
					 if upcase(scan(campaign,9,'_')) = 'EXACT' or upcase(scan(campaign,8,'_')) = 'EXACT' then Match_Type = 'Exact';
							else if upcase(scan(campaign,9,'_')) = 'BROAD' or upcase(scan(campaign,8,'_')) = 'BROAD' then Match_Type = 'Broad';
							else Match_Type='UN';
					 if upcase(scan(campaign,12,'_')) = 'RLSAY' or upcase(scan(campaign,13,'_')) = 'RLSAY' then Remarketing = 'Y';
							else Remarketing = 'N';
					 if find(UTM_campaign,'kp_b2bl')>0 then Keyword_Category=upcase(catx('_',scan(campaign,7,'_'),scan(campaign,8,'_')));
					 	else if find(UTM_campaign,'kp_sb')>0 then Keyword_Category=upcase(catx('_',scan(campaign,6,'_'),scan(campaign,7,'_')));
						if Keyword_Category = 'NBD_PK' then Keyword_Category = 'BPK';
							else if Keyword_Category = 'BND_PK' then Keyword_Category = 'NBPK';
						else Keyword_Category='UN';
					*if upcase(scan(campaign,9,'_'))='EL' then Keyword_Category = catt(Keyword_Category,'-EL');
					if Theme = 'Content' then Audience = 'Business Size Unknown';
						else Audience=scan(ChannelDetail,2,'-');
					Program_Campaign = 'Always On';

					Halo_Actions = 1;
					output missing;
				end;

				* Bad data;
				else if UTM_Campaign = '_error_' then do;
					Channel='Paid Search';
					ChannelDetail='Paid Search-UN';
					Keyword=UTM_Term;
					Campaign=UTM_Campaign;
					Network=propcase(UTM_Source);
						if Network='(Not Set)' then Network = 'UN';
					Region='UN';
					SubRegion='UN';
					Program_Campaign='UN';
					Theme='UN';
					Creative='UN';
					Match_Type='UN';
					Remarketing='UN';
					Keyword_Category='UN';
					Audience='UN';
					/* Halo Action Flag */
					Halo_Actions = 0;
					output missing;
				end;

				else output otherlob;
		end;

		run;
		%check_for_data(paidsearch_lg_merged,=0,No data in merged dataset);

	%end;
	%if &cancel= and &Nnew>0 %then %do;

		* Data not processed & added to b2b_campaign_master;
		options dlcreatedir;
		libname miss xlsx "&input_files/Not added to b2b_campaign_master - Paid Search.xlsx"; run;
		proc sql;
		create table miss.'Data Error - PS'n as
			select distinct
				*
			from otherlob;
		quit;
		proc sql noprint;
			select count(*) into :nmiss trimmed from otherlob;
		quit;

		%let error_rsn=Error appending tables.;

		data ps.b2b_campaign_master_lg;

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

					Halo_Actions comma8.

					UTM_Source
					UTM_Medium
					UTM_Campaign
					UTM_Content
					UTM_Term
				;
		 	set paidsearch_lg_merged
				missing;

			VideoStarts=.;
			VideoCompletions=.;
			Total_Engagements=.;
			Total_Social_Actions=.;
			Primary_Downloads=.;
			Primary_Contacts=.;
			Secondary_Downloads=.;
			Leads=.;
			Lead_Forms_Opened=.;
			Image='N/A';
			Ad_Format='N/A';

			* Replace missing numeric w/ 0;
			 array change _numeric_;
		        do over change;
		            if change=. then change=0;
		        end;
		run;
		%check_for_data(ps.b2b_campaign_master_lg,=0,No data in final campaign dataset);

	%end;
	%if &cancel= and &Nnew>0 %then %do;

		proc freq data=ps.b2b_campaign_master_lg;
			tables date WeekStart Month Quarter
				Channel ChannelDetail Campaign Network
				Region SubRegion Program_Campaign Theme Creative
				Image Ad_Format Audience Match_Type
				Remarketing Keyword_category; 
		run;

	/* Validation */
		proc sql;
		select distinct 
			WeekStart
		,	Halo_Actions
		,	sum(spend) as spend format dollar18.2
		,	sum(impressions) as impressions format comma18.
		,	sum(clicks) as clicks format comma18.
		,	sum(clicks)/sum(impressions) as CTR format percent7.2
		,	sum(business_actions) as sa360_actions format comma8.2
		,	sum(weighted_actions) as ga_actions format comma8.2
		,	sum(business_leads) as sa360_leads format comma8.
		,	sum(convertsubmit_contact+convertsubmit_quote+sb_mas_leads+(convertnonsubmit_ssq*0.43)) as ga_leads format comma8.
		,	sum(sessions) As sessions format comma8.
		,	sum(weighted_actions)/sum(sessions) as action_rate format comma8.2
		from ps.b2b_campaign_master_lg
		group by 
			WeekStart
		,	Halo_Actions
		order by	
			Halo_Actions
		,	WeekStart;
		quit;	

	/* -------------------------------------------------------------------------------------------------*/
	/*  Export and archive raw LG/SB paid search.                                                       */
	/* -------------------------------------------------------------------------------------------------*/
		
		%let error_rsn=Error updating B2B_Campaign_Master.;

		data ps.B2B_Campaign_Master_Temp;
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
			from ps.B2B_Campaign_Master_lg;
		quit;

	* If you added/removed or changed the formatting of a variable, run this instead;		

/*		proc delete data=prod.B2B_Campaign_Master; run;*/
/*		data prod.B2B_Campaign_Master;*/
/*			set ps.B2B_Campaign_Master_lg(in=a)*/
/*				ps.B2B_Campaign_Master_Temp(in=b); */
/*			if a then Rec_Update_Date = datetime();*/
/*		run;*/

		* Do not re-run;
/*		proc datasets library=prod nolist;*/
/*		modify B2B_Campaign_Master;*/
/*		index create Date;*/
/*		quit;*/

	/* -------------------------------------------------------------------------------------------------*/
	/*  Save master file --> zip archive.                                                               */
	/* -------------------------------------------------------------------------------------------------*/
		
		%let error_rsn=Error writing to archive.;

		proc sql noprint;
			select distinct
				min(Date) format mmddyy6.,
				max(Date) format mmddyy6.
			into :FirstData,
				 :LastData
			from prod.B2B_Campaign_Master;
		quit;

		data archive.B2B_Campaign_&FirstData._&LastData;
			set prod.B2B_Campaign_Master;
		run;

		ods package(archived) open nopf;
		ods package(archived) add file="&final_file_path/Archive/b2b_campaign_&FirstData._&LastData..sas7bdat";
		ods package(archived) publish archive properties (
			archive_name="b2b_campaign_&FirstData._&LastData..zip"
			archive_path="&final_file_path/Archive/");
		ods package(archived) close;
		proc delete data=archive.B2B_Campaign_&FirstData._&LastData; run;

		*Create the list of files, in this case all ZIP files;
		%list_files(&final_file_path./Archive,ext=zip);

		%let filename_oldarchive=DNE;
		proc sql ;
			select 
				the_name
			into :filename_oldarchive trimmed
			from list 
			where find(the_name,'b2b_campaign')>0 
				and the_name ne "b2b_campaign_&FirstData._&LastData.";
		quit;
		proc delete data=list; run;

		%macro old_arch;
			%if &filename_oldarchive ne DNE %then %do;
				filename old_arch "&final_file_path/Archive/&filename_oldarchive..zip";	
				data _null_;
					rc=fdelete("old_arch");
					put rc=;
				run;
			%end;
		%mend;
		%old_arch;

	/* -------------------------------------------------------------------------------------------------*/
	/*  Frequency Tables.                                                                               */
	/* -------------------------------------------------------------------------------------------------*/ 

		proc sql; 
		select distinct 
			count(distinct date) 
		into :days 
		from final.B2B_PaidSearch_Raw
		where Date >= "&Campaign_StartDate"d;
		quit;

		options dlcreatedir;
		libname freq xlsx "&input_files/Frequency Tables - Get_PaidSearch_Data_Weekly.xlsx"; run;
		proc sql;
		create table freq.'Raw Data Append by Date'n as
			select distinct
				Date
			,	case when Date>="&Campaign_StartDate"d then 1 else 0 end as New_Data
			,	sum(cost) as Spend format dollar18.2
			,	sum(impressions) as Impressions format comma18.
			,	sum(clicks) as Clicks format comma18.
			,	sum(business_actions) as SA360_actions format comma8.2
			,	sum(business_leads) as SA360_leads format comma8.
			,	sum(clicks)/sum(impressions) as CTR
			,	sum(cost)/sum(clicks) as CPC
			from final.B2B_PaidSearch_Raw
			where Date>=intnx('day',"&Campaign_StartDate"d,-&days.,'s')
			group by 
				Date;
		quit;
		proc sql;
		create table freq.'Final Append by Date'n as
			select distinct
				Date
			,	case when Date>="&Campaign_StartDate"d then 1 else 0 end as New_Data
			,	sum(spend) as Spend format dollar18.2
			,	sum(impressions) as Impressions format comma18.
			,	sum(clicks) as Clicks format comma18.
			,	sum(business_actions) as SA360_actions format comma8.2
			,	sum(weighted_actions) as GA_actions format comma8.2
			,	sum(business_actions)/sum(weighted_actions)-1 as Pct_Diff_Actions format percent7.2
			,	sum(business_leads) as SA360_leads format comma8.
			,	sum(ConvertSubmit_Contact+ConvertSubmit_Quote+SB_MAS_Leads+ConvertNonSubmit_SSQ*0.43) as GA_leads format comma8.
			,	sum(business_leads)/sum(ConvertSubmit_Contact+ConvertSubmit_Quote+SB_MAS_Leads+ConvertNonSubmit_SSQ*0.43)-1 as Pct_Diff_Leads format percent7.2
			,	sum(sessions) As Sessions format comma8.
			,	sum(clicks)/sum(impressions) as CTR
			,	sum(sessions)/sum(impressions) as VR
			,	sum(weighted_actions)/sum(sessions) as Actions_Per_Visit format comma8.2
			from prod.B2B_Campaign_Master
			where ChannelDetail in ('Paid Search-LG','Paid Search-SB')
				and Date>=intnx('day',"&Campaign_StartDate"d,-&days,'s')
			group by 
				Date
			,	case when Date>="&Campaign_StartDate"d then 1 else 0 end;
		quit;
		proc sql;
		create table freq.'Final Append by LOB'n as
			select distinct
				ChannelDetail
			,	case when Date>="&Campaign_StartDate"d then 1 else 0 end as New_Data
			,	sum(spend) as Spend format dollar18.2
			,	sum(impressions) as Impressions format comma18.
			,	sum(clicks) as Clicks format comma18.
			,	sum(business_actions) as SA360_actions format comma8.2
			,	sum(weighted_actions) as GA_actions format comma8.2
			,	sum(business_actions)/sum(weighted_actions)-1 as Pct_Diff_Actions format percent7.2
			,	sum(business_leads) as SA360_leads format comma8.
			,	sum(ConvertSubmit_Contact+ConvertSubmit_Quote+SB_MAS_Leads+ConvertNonSubmit_SSQ*0.43) as GA_leads format comma8.
			,	sum(business_leads)/sum(ConvertSubmit_Contact+ConvertSubmit_Quote+SB_MAS_Leads+ConvertNonSubmit_SSQ*0.43)-1 as Pct_Diff_Leads format percent7.2
			,	sum(sessions) As Sessions format comma8.
			,	sum(clicks)/sum(impressions) as CTR
			,	sum(sessions)/sum(impressions) as VR
			,	sum(weighted_actions)/sum(sessions) as Actions_Per_Visit format comma8.2
			from prod.B2B_Campaign_Master
			where ChannelDetail in ('Paid Search-LG','Paid Search-SB')
				and Date>=intnx('day',"&Campaign_StartDate"d,-&days,'s')
			group by 
				ChannelDetail
			,	case when Date>="&Campaign_StartDate"d then 1 else 0 end;
		quit;
		proc sql;
		create table freq.'Final Append by Region'n as
			select distinct
				Region
			,	case when Date>="&Campaign_StartDate"d then 1 else 0 end as New_Data
			,	sum(spend) as Spend format dollar18.2
			,	sum(impressions) as Impressions format comma18.
			,	sum(clicks) as Clicks format comma18.
			,	sum(business_actions) as SA360_actions format comma8.2
			,	sum(weighted_actions) as GA_actions format comma8.2
			,	sum(business_actions)/sum(weighted_actions)-1 as Pct_Diff_Actions format percent7.2
			,	sum(business_leads) as SA360_leads format comma8.
			,	sum(ConvertSubmit_Contact+ConvertSubmit_Quote+SB_MAS_Leads+ConvertNonSubmit_SSQ*0.43) as GA_leads format comma8.
			,	sum(business_leads)/sum(ConvertSubmit_Contact+ConvertSubmit_Quote+SB_MAS_Leads+ConvertNonSubmit_SSQ*0.43)-1 as Pct_Diff_Leads format percent7.2
			,	sum(sessions) As Sessions format comma8.
			,	sum(clicks)/sum(impressions) as CTR
			,	sum(sessions)/sum(impressions) as VR
			,	sum(weighted_actions)/sum(sessions) as Actions_Per_Visit format comma8.2
			from prod.B2B_Campaign_Master
			where ChannelDetail in ('Paid Search-LG','Paid Search-SB')
				and Date>=intnx('day',"&Campaign_StartDate"d,-&days,'s')
			group by 
				Region
			,	case when Date>="&Campaign_StartDate"d then 1 else 0 end;
		quit;

	* Clean up po_imca_digital;
		* Second backup of b2b_campaign_master;
		ods package(archived) open nopf;
		ods package(archived) add file="&input_files/b2b_campaign_master_temp.sas7bdat";
		ods package(archived) publish archive properties (
			archive_name="b2b_campaign_master_temp.zip"
			archive_path="&input_files/");
		ods package(archived) close;
		proc delete data=ps.b2b_campaign_master_temp; run;
		* Second backup of b2b_paidsearch_raw;
		ods package(archived) open nopf;
		ods package(archived) add file="&input_files/b2b_paidsearch_raw_temp.sas7bdat";
		ods package(archived) publish archive properties (
			archive_name="b2b_paidsearch_raw_temp.zip"
			archive_path="&input_files/");
		ods package(archived) close;
		proc delete data=ps.b2b_paidsearch_raw_temp; run;
		* Delete files from most recent update;
		proc delete data=ps.b2b_campaign_master_lg; run;
		proc delete data=flagged_for_review_clean; run;
		proc delete data=ps.ps_clean; run;
		proc delete data=ps.ps_clean_final; run;

	%end; 

/* -------------------------------------------------------------------------------------------------*/
/*  Email log.                                                                                      */
/* -------------------------------------------------------------------------------------------------*/ 

	/* you may change the default sentFrom and sentTo */
	%emailB2Bdashboard(Get_PaidSearch_Data_Weekly,
			attachFreqTableFlag=1,
			attachLogFlag=1 /*,
			sentFrom=,
			sentTo= */
			);	

	proc printto; run; /* Turn off log export to .txt */
