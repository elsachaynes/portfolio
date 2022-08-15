/****************************************************************************************************/
/*  Program Name:       Get_EL_Data_Weekly.sas                                                      */
/*                                                                                                  */
/*  Date Created:       Mar 11, 2021                                                                */
/*                                                                                                  */
/*  Created By:         Elle Haynes                                                                 */
/*                                                                                                  */
/*  Purpose:            Compiles daily data from Paid Seach Enterprise Listing. Outputs append to   */
/*                      B2B_PaidSearch_EL_Raw and B2B_Campaign_Master.                              */
/*                                                                                                  */
/*  Inputs:             RDM Paid Search EL engine data and a B2B Spend Contribution lookup.         */
/*                                                                                                  */
/* -------------------------------------------------------------------------------------------------*/	
/*  Notes:              Lookup is manually updated from Budgeted % to Actual.                       */
/*                      Learn, Shop, GAQ, and Contact actions are missing starting 2020. See if     */
/*                           they can be found/appended in the Connex B2B PS data.                  */
/* -------------------------------------------------------------------------------------------------*/
/*  Date Modified:      Sep 8, 2021                                                                 */
/*  Modified by:        Elle Haynes                                                                 */
/*  Description:        Add process to ingest data from SA360 extracts instead of RDM.              */
/*                                                                                                  */
/*  Date Modified:      Jan 18, 2021                                                                */
/*  Modified by:        Elle Haynes                                                                 */
/*  Description:        Refreshed all 2020-2021 data due to EL backfill (RISE).                     */
/*                                                                                                  */
/*  Date Modified:      April 21, 2022                                                              */
/*  Modified by:        Elle Haynes                                                                 */
/*  Description:        Changed email output to use new email macro: SAS_Macro_Email.               */
/****************************************************************************************************/

/* -------------------------------------------------------------------------------------------------*/
/*  Run libraries                                                                                   */
/* -------------------------------------------------------------------------------------------------*/

	filename old_log "/gpfsFS2/sasdata/nfs/ndc_grid/po_imca_digital/EHaynes/B2B Dashboard Data Processing/Paid Search/EL/LOG Get_EL_Data_Weekly.txt";
	data _null_; rc=fdelete("old_log"); put rc=; run;
	proc printto log="/gpfsFS2/sasdata/nfs/ndc_grid/po_imca_digital/EHaynes/B2B Dashboard Data Processing/Paid Search/EL/LOG Get_EL_Data_Weekly.txt"; run;

	%let error_rsn=Error in libraries statements.;

	* EL Folder;
	%let input_files = /gpfsFS2/sasdata/nfs/ndc_grid/po_imca_digital/EHaynes/B2B Dashboard Data Processing/Paid Search/EL;
	libname ps_el "&input_files";

	* EL Contribution Lookup;
	libname el_cont xlsx "&input_files/Lookups/EL Contribution.xlsx"; run;

	* Raw Data Download Folder;
	%let raw_file_path = /gpfsFS2/sasdata/nfs/ndc_grid/po_imca_digital/EHaynes/B2B Dashboard Data Processing/_Raw Data Downloads;
	libname import "&raw_file_path";

	* Output;
	%let final_file_path = /gpfsFS2/sasdata/adhoc/po/imca/product/B2B;
	libname final "&final_file_path";
	libname archive "&final_file_path/Archive";

	%let production_path= /gpfsFS2/sasdata/nfs/ndc_grid/po_imca_product/B2B;
	libname prod "&production_path";

	* Raw RDM source;
	%include '/gpfsFS2/home/c156934/password.sas';
	libname RDM sqlsvr DSN='SQLSVR6211' SCHEMA='dbo' user="CS\C156934" password="&winpwd"
	     qualifier='RDM_RPT' readbuff=5000 insertbuff=5000 dbcommit=1000; run;
	%let raw_data_source = SQLSVR6211 RDM_RPT.dbo.VW_PAID_SRCH_EL_ACTVTY_RPT;

	* TABLEAU extract;
	libname mer_qc sqlsvr datasrc='WS_NYDIA' SCHEMA='dbo' user="CS\C156934" password="&winpwd" 
		qualifier='TABLEAU_RPT' readbuff=5000 insertbuff=5000 dbcommit=1000; run;

	* Initialize;
	%let N=;
	%let Nnew=0;
	%let N_update=0;
	%let nfiles_orig=0;
	%let dt=.;
	%let Campaign_StartDate=;
	%let nCam=0;
	%let cancel=;
	%let dupes=0;

/* -------------------------------------------------------------------------------------------------*/
/*  Load stored macros.                                                                             */
/* -------------------------------------------------------------------------------------------------*/

	%include "/gpfsFS2/sasdata/adhoc/po/imca/digital/code/Access/SAS_Macro_ListFiles.sas"; 
	%include "/gpfsFS2/sasdata/adhoc/po/imca/digital/code/Access/SAS_Macro_CheckForData.sas"; 
	%include "/gpfsFS2/sasdata/adhoc/po/imca/digital/code/Access/SAS_Macro_Email.sas"; 

/* -------------------------------------------------------------------------------------------------*/
/*  Import B2B EL Contribution Lookup                                                               */
/* -------------------------------------------------------------------------------------------------*/

	%let error_rsn=Error in EL contribution lookups.;

	data el_contribution_22;
			   
		retain Year Lookup_Month WeekStart WeekEnd Region B2B_Contrib_Budget B2B_Contrib_Actual;
		set el_cont.'2022'n;

		rename Year = Lookup_Year
			   Region = Lookup_Region
			   WeekStart = Lookup_WeekStart
			   WeekEnd = Lookup_WeekEnd
				;

		if Month = 'January' then Lookup_Month = 1;
			else if Month = 'February' then Lookup_Month = 2;
			else if Month = 'March' then Lookup_Month = 3;
			else if Month = 'April' then Lookup_Month = 4;
			else if Month = 'May' then Lookup_Month = 5;
			else if Month = 'June' then Lookup_Month = 6;
			else if Month = 'July' then Lookup_Month = 7;
			else if Month = 'August' then Lookup_Month = 8;
			else if Month = 'September' then Lookup_Month = 9;
			else if Month = 'October' then Lookup_Month = 10;
			else if Month = 'November' then Lookup_Month = 11;
			else if Month = 'December' then Lookup_Month = 12;
			else if Month = '' then Lookup_Month = .;
		drop Month;

		keep Year Lookup_Month WeekStart WeekEnd 
			Region B2B_Contrib_Budget 
			B2B_Contrib_Actual
			;

		if Year = . then delete;
		if B2B_Contrib_Budget = . then delete;

	run;
	
	data el_contribution_21;
		retain Year Lookup_Month WeekStart WeekEnd Region B2B_Contrib_Budget B2B_Contrib_Actual;
		set el_cont.'2021'n;

		rename Year = Lookup_Year
			   Region = Lookup_Region
			   WeekStart = Lookup_WeekStart
			   WeekEnd = Lookup_WeekEnd;

		if Month = 'January' then Lookup_Month = 1;
			else if Month = 'February' then Lookup_Month = 2;
			else if Month = 'March' then Lookup_Month = 3;
			else if Month = 'April' then Lookup_Month = 4;
			else if Month = 'May' then Lookup_Month = 5;
			else if Month = 'June' then Lookup_Month = 6;
			else if Month = 'July' then Lookup_Month = 7;
			else if Month = 'August' then Lookup_Month = 8;
			else if Month = 'September' then Lookup_Month = 9;
			else if Month = 'October' then Lookup_Month = 10;
			else if Month = 'November' then Lookup_Month = 11;
			else if Month = 'December' then Lookup_Month = 12;
			else if Month = '' then Lookup_Month = .;
		drop Month;

		keep Year Lookup_Month WeekStart WeekEnd 
			Region B2B_Contrib_Budget B2B_Contrib_Actual;

		if year = . then delete;

	run;

	data el_contribution_20;
		retain Year Lookup_Month WeekStart WeekEnd Region B2B_Contrib_Actual;
		set el_cont.'2020'n;

		rename Year = Lookup_Year
			   Region = Lookup_Region
			   WeekStart = Lookup_WeekStart
			   WeekEnd = Lookup_WeekEnd;

		if Month = 'January' then Lookup_Month = 1;
			else if Month = 'February' then Lookup_Month = 2;
			else if Month = 'March' then Lookup_Month = 3;
			else if Month = 'April' then Lookup_Month = 4;
			else if Month = 'May' then Lookup_Month = 5;
			else if Month = 'June' then Lookup_Month = 6;
			else if Month = 'July' then Lookup_Month = 7;
			else if Month = 'August' then Lookup_Month = 8;
			else if Month = 'September' then Lookup_Month = 9;
			else if Month = 'October' then Lookup_Month = 10;
			else if Month = 'November' then Lookup_Month = 11;
			else if Month = 'December' then Lookup_Month = 12;
			else if Month = '' then Lookup_Month = .;
		drop Month;
		if WeekStart ne . then Lookup_Month = .;

		if year = . then delete;
		
		keep Year Lookup_Month WeekStart WeekEnd	
			Region B2B_Contrib_Actual;
		
	run;

	data ps_el.el_contribution;
		set el_contribution_21
			el_contribution_20
			el_contribution_22(drop=B2B_Contrib_Actual Lookup_WeekStart Lookup_Weekend);
	run;
	%check_for_data(ps_el.el_contribution,=0,Error loading el_contribution);

	proc delete data=work.el_contribution_22; run &cancel.;
	proc delete data=work.el_contribution_21; run &cancel.;
	proc delete data=work.el_contribution_20; run &cancel.;

/* -------------------------------------------------------------------------------------------------*/
/*                                                                                                  */
/*                                                                                                  */
/*                                         Check for new file                                       */
/*                                                                                                  */
/*                                                                                                  */
/* -------------------------------------------------------------------------------------------------*/

/*	%list_files(&raw_file_path,ext=csv);

	proc sql ;
		select 
			count(*)
		,	count(*)
		,	the_name
		into :nfiles,
			 :nfiles_orig,
			 :the_name separated by '|' 
		from list
		where find(the_name,'EL-report-')>0;
	quit;

	%let error_rsn = CSV not found in directory.;

/* -------------------------------------------------------------------------------------------------*/
/*                                                                                                  */
/*                                                                                                  */
/*                                         Ingest Raw Data                                          */
/*                                                                                                  */
/*                                                                                                  */
/* -------------------------------------------------------------------------------------------------*/

/*	%if &nfiles_orig > 0 %then %do; 

		%put Updating SQL Server EL Table;

	/*		proc sql noprint;*/
	/*			select*/
	/*				coalesce(&dt,max(Date)) format mmddyy6.*/
	/*			,	coalesce(&dt,max(Date)) format date9.*/
	/*			,	coalesce(&dt,today())-max(Date)*/
	/*			into :LastData_Old trimmed,*/
	/*				 :LastData_OldNum trimmed,*/
	/*				 :Days_Since_Last_Data trimmed*/
	/*			from final.B2B_PaidSearch_EL_Raw;*/
	/*		quit;*/
	/*		%put Last data in B2B_PaidSearch_EL_Raw &LastData_OldNum;*/

			/* -------------------------------------------------------------------------------------------------*/
			/*  Import Raw Paid Search data from SA360 (manually downloaded)                                    */
			/* -------------------------------------------------------------------------------------------------*/

/*			%macro import_raw();
			%let i = 1;
			%do %while (&nfiles > 0);
			
			%let the_name_import = %sysfunc(scan(&the_name,&i,%quote(|)));
			%let error_rsn=Error pulling raw data from CSV;

			data raw_import_&i.;

		        infile "&raw_file_path/&the_name_import..csv"
				delimiter = "," missover dsd lrecl=32767 firstobs=2 ;

				informat Date ANYDTDTE. ;
				informat Account $50. ;
				informat Campaign $100. ;
				informat Ad_Group $50. ;
				informat Keyword $100. ;
				informat Match_Type $7. ;
				informat Max_CPC 8.2 ;
				informat Impressions comma18. ;
				informat Clicks 8. ;
				informat SA360_Cost 8.2 ;
				informat Quality_Score 8. ;
				informat Business_Actions 8.2 ;
				informat Business_Leads 8. ;
				informat ConvertSubmit_Contact 8. ;
				informat ConvertSubmit_Quote 8. ;
				informat ConvertNonSubmit_SSQ 8. ;
				informat SB_MAS_Leads 8. ;
				informat LandingPage $100. ;
				informat KPIF_SMUAppCompl_e464 8. ;
				informat KPIF_WeightedApplOnHIX_e369 8. ;
				informat KPIF_QuotesCompl_e290 8. ;
				informat KPIF_ApplOnKP_e368 8. ;
				informat Medicare_Appl 8. ;
				informat KPIF_Appl 8. ;
				informat Thrive_Actions 8. ;

				format Date mmddyy10. ;
				format Account $50. ;
				format Campaign $100. ;
				format Ad_Group $50. ;
				format Keyword $100. ;
				format Match_Type $7. ;
				format Max_CPC dollar18.2 ;
				format Impressions comma18. ;
				format Clicks comma8. ;
				format SA360_Cost dollar18.2 ;
				format Quality_Score 8. ;
				format Business_Actions 8.2 ;
				format Business_Leads 8. ;
				format ConvertSubmit_Contact 8. ;
				format ConvertSubmit_Quote 8. ;
				format ConvertNonSubmit_SSQ 8. ;
				format SB_MAS_Leads 8. ;
				format LandingPage $100. ;
				format KPIF_SMUAppCompl_e464 8. ;
				format KPIF_WeightedApplOnHIX_e369 8. ;
				format KPIF_QuotesCompl_e290 8. ;
				format KPIF_ApplOnKP_e368 8. ;
				format Medicare_Appl 8. ;
				format KPIF_Appl 8. ;
				format Thrive_Actions 8. ;
				
				input
					 Date
					 Account	$
					 Campaign	$
					 Ad_Group	$
					 Keyword	$
					 Match_Type $
					 Max_CPC
					 Impressions
					 Clicks
					 SA360_Cost
					 Quality_Score
					 Business_Actions
					 Business_Leads
					 ConvertSubmit_Contact 
					 ConvertSubmit_Quote
					 ConvertNonSubmit_SSQ
					 SB_MAS_Leads
					 LandingPage
					 KPIF_SMUAppCompl_e464
					 KPIF_WeightedApplOnHIX_e369
					 KPIF_QuotesCompl_e290
					 KPIF_ApplOnKP_e368
					 Medicare_Appl
					 KPIF_Appl
					 Thrive_Actions
					 ;

				if Account='account' then delete;

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

		* Roll-up new data;
		proc sql;
		create table PaidSearch_EL_Raw_Rollup as
		select distinct
			intnx('month',date,0,'b') as Month_dt format mmddyy10.
		,	Account
		,	case when find(LandingPage,'nbpu','i')>0 
				then 'Non Brand' else 'Brand'
				end as Brand_NonBrand
		,	sum(Impressions) as Impr_New format comma18.
		,	sum(Clicks) as Clicks_New format comma18.
		,	sum(SA360_Cost) as SA360_Cost_New format dollar18.2
		,	sum(Business_Actions) as Business_Actions_New format comma18.2
		,	sum(Business_Leads) as Business_Leads_New format comma18.
		,	sum(KPIF_SMUAppCompl_e464) as KPIF_SMUAppCompl_e464_New format comma18.
		,	sum(KPIF_ApplOnKP_e368) as KPIF_ApplOnKP_e368_New format comma18.
		,	sum(KPIF_WeightedApplOnHIX_e369) as KPIF_WeightedApplOnHIX_e369_New format comma18.
		,	sum(KPIF_QuotesCompl_e290) as KPIF_QuotesCompl_e290_New format comma18.
		,	sum(Medicare_Appl) as Medicare_Appl_New format comma18.
		,	sum(KPIF_Appl) as KPIF_Appl_New format comma18.
		,	sum(Thrive_Actions) as Thrive_Actions_New format comma18.
		from raw
		group by 
			intnx('month',date,0,'b')
		,	Account
		,	case when find(LandingPage,'nbpu','i')>0 
				then 'Non Brand' else 'Brand'
				end
		order by 
			intnx('month',date,0,'b')
		,	Account
		,	case when find(LandingPage,'nbpu','i')>0 
				then 'Non Brand' else 'Brand'
				end;
		quit;

		proc sql ;
			select distinct
				month_dt format date9.
			,	count(distinct month_dt)
			into :update_month separated by '|'
				,:update_month_N
			from PaidSearch_EL_Raw_Rollup;
		quit;

		%let m2= %quote(%sysfunc(scan(&update_month,2,"|")));
		%put &m2;

		* Update the table locally;
		data PaidSearch_EL_Raw_Rollup_final;
			merge mer_qc.PaidSearch_EL_Raw_Rollup(in=a)
				  PaidSearch_EL_Raw_Rollup(in=b);
			by Month_dt Account Brand_NonBrand;

			if Month_dt = "&update_month"d then do;
				Impr=							coalesce(Impr,0)+Impr_New;
				Clicks=							coalesce(Clicks,0)+Clicks_New;
				SA360_Cost=						coalesce(SA360_Cost,0)+SA360_Cost_New;
				Business_Actions=				coalesce(Business_Actions,0)+Business_Actions_New;
				Business_Leads=					coalesce(Business_Leads,0)+Business_Leads_New;
				KPIF_SMUAppCompl_e464=			coalesce(KPIF_SMUAppCompl_e464,0)+KPIF_SMUAppCompl_e464_New;
				KPIF_ApplOnKP_e368=				coalesce(KPIF_ApplOnKP_e368,0)+KPIF_ApplOnKP_e368_New;
				KPIF_WeightedApplOnHIX_e369=	coalesce(KPIF_WeightedApplOnHIX_e369,0)+KPIF_WeightedApplOnHIX_e369_New;
				KPIF_QuotesCompl_e290=			coalesce(KPIF_QuotesCompl_e290,0)+KPIF_QuotesCompl_e290_New;
				Medicare_Appl=					coalesce(Medicare_Appl,0)+Medicare_Appl_New;
				KPIF_Appl=						coalesce(KPIF_Appl,0)+KPIF_Appl_New;
				Thrive_Actions=					coalesce(Thrive_Actions,0)+Thrive_Actions_New;
				Rec_Updt_Dt=					datetime();
			end;

			if &update_month_N>1 and Month_dt = "&m2"d then do;
				Impr=							coalesce(Impr,0)+Impr_New;
				Clicks=							coalesce(Clicks,0)+Clicks_New;
				SA360_Cost=						coalesce(SA360_Cost,0)+SA360_Cost_New;
				Business_Actions=				coalesce(Business_Actions,0)+Business_Actions_New;
				Business_Leads=					coalesce(Business_Leads,0)+Business_Leads_New;
				KPIF_SMUAppCompl_e464=			coalesce(KPIF_SMUAppCompl_e464,0)+KPIF_SMUAppCompl_e464_New;
				KPIF_ApplOnKP_e368=				coalesce(KPIF_ApplOnKP_e368,0)+KPIF_ApplOnKP_e368_New;
				KPIF_WeightedApplOnHIX_e369=	coalesce(KPIF_WeightedApplOnHIX_e369,0)+KPIF_WeightedApplOnHIX_e369_New;
				KPIF_QuotesCompl_e290=			coalesce(KPIF_QuotesCompl_e290,0)+KPIF_QuotesCompl_e290_New;
				Medicare_Appl=					coalesce(Medicare_Appl,0)+Medicare_Appl_New;
				KPIF_Appl=						coalesce(KPIF_Appl,0)+KPIF_Appl_New;
				Thrive_Actions=					coalesce(Thrive_Actions,0)+Thrive_Actions_New;
				Rec_Updt_Dt=					datetime();
			end;

			drop Impr_New Clicks_New SA360_Cost_New Business_Actions_New Business_Leads_New
				KPIF_SMUAppCompl_e464_New KPIF_ApplOnKP_e368_New KPIF_WeightedApplOnHIX_e369_New
				KPIF_QuotesCompl_e290_New Medicare_Appl_New KPIF_Appl_New Thrive_Actions_New;
			
		run;

		* Export to TABLEAU_RPT for the EL Dashboard;
		proc delete data=mer_qc.PaidSearch_EL_Raw_Rollup; run;
		data mer_qc.PaidSearch_EL_Raw_Rollup;
			set PaidSearch_EL_Raw_Rollup_final;
		run;

		/* -------------------------------------------------------------------------------------------------*/
		/*  Save input file(s) --> zip archive.                                                                */
		/* -------------------------------------------------------------------------------------------------*/

/*		%macro zip();
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

	%end; /* &nfiles_orig>0 */

/* -------------------------------------------------------------------------------------------------*/
/*                                                                                                  */
/*                                                                                                  */
/*                                         Ingest Raw Data                                          */
/*                                                                                                  */
/*                                                                                                  */
/* -------------------------------------------------------------------------------------------------*/

	proc sql ;
		select
			coalesce(&dt,max(Date)) format mmddyy6.
		,	coalesce(&dt,max(Date)) format date9.
		into :LastData_Old trimmed,
			 :LastData_OldNum trimmed
		from final.B2B_PaidSearch_EL_Raw;
	quit;

	%put Last data in B2B_PaidSearch_EL_Raw &LastData_OldNum;

	data ps_el.el_tbl1;
		set rdm.vw_paid_srch_EL_actvty_rpt;
		where LOB = 'EL'
			and actvty_dt > coalesce(&dt,"&LastData_OldNum"d); 
 	run;
		
	proc sql; select distinct count(*) into :Nnew from ps_el.el_tbl1; quit;
	%check_for_data(ps_el.el_tbl1,=0,No new records found in raw dataset);

	%if &cancel= and &Nnew>0 %then %do;

	/* -------------------------------------------------------------------------------------------------*/
	/*  Clean Raw Paid Search EL data                                                                   */
	/* -------------------------------------------------------------------------------------------------*/

		%let error_rsn=Error cleaning raw data step 1.;

		data ps_el.el_tbl2;
			retain actvty_dt
				 cmpgn_nm
				 Cost
				 imprs
				 Clcks
				 publ_nm
				 term_type
				 keyword_theme
				 mtch_type
				 keyword_category
				 region
				 market
				 impr_share
				 b2b_actns
				 b2b_leads
				 geo_area_non_rgnl
				 lookup_year
				 lookup_month
				 week
				 ;

			set ps_el.el_tbl1;

			keep actvty_dt
				 cmpgn_nm
				 Cost
				 imprs
				 Clcks
				 publ_nm
				 term_type
				 keyword_theme
				 mtch_type
				 keyword_category
				 region
				 market
				 impr_share
				 b2b_actns
				 b2b_leads

				 geo_area_non_rgnl
				 lookup_year
				 lookup_month
				 ;

			format 
				actvty_dt mmddyy10.
				cost dollar18.2
				imprs comma18.
				clcks comma18.
				impr_share percent7.2
				keyword_category $10.
				;

			rename 
				actvty_dt = Date
				cmpgn_nm = campaign
				geo_area_non_rgnl = Lookup_Region
				market = SubRegion
				cost = EL_Cost
				imprs = EL_Impressions
				clcks = EL_Clicks
				publ_nm = Engine
				term_type = Ad_Group
				mtch_type = Match_Type
				keyword_category = Keyword_Category
				b2b_actns = Business_Actions
				b2b_leads = Business_Leads
			;

			/* Lookup Variables */
			Lookup_Month = month(actvty_dt);
			Lookup_Year = year(actvty_dt);

			/* Clean impression share */
			impr_share = imprs_shr/100;
			drop imprs_shr;

			if scan(cmpgn_nm,2,'_') ne "EL" then delete;

			/* Parsing */
			if scan(cmpgn_nm,4,'_') = 'PS' then do;
				Region = scan(cmpgn_nm,6,'_');
				market = scan(cmpgn_nm,7,'_');
				Keyword_Theme = term_type;
				Keyword_Category = scan(cmpgn_nm,12,'_');
				term_type = scan(cmpgn_nm,17,'_');
			end;
			else if scan(cmpgn_nm,4,'_') ne 'PS' then do;
				Keyword_Theme = scan(cmpgn_nm,9,'_');
			end;

			if Region = 'KPWAS' then Region = 'KPWA';
			if market = 'MRLD' then market = 'MD';
			else if market = 'VRGA' then market = 'VA';
			else if market = 'ORE' then market = 'OR';

			/* Cleaning */
			if Keyword_Category = 'BRDEL' then Keyword_Category = 'BPU';
				else if Keyword_Category = 'NBEL' then Keyword_Category = 'NBPU';

			if Keyword_Theme = 'JLC' then Keyword_Theme = 'Job Loss Campaign';
			else if Keyword_Theme = 'MEM' then do;
				Keyword_Theme = 'Member';
				Keyword_Category = 'BPU-MEM';
				end;
			else if Keyword_Theme in ('N3','NA','NON') then Keyword_Theme = 'N/A';

			/* Replace missing numeric w/ 0 */
			 array change _numeric_;
		        do over change;
		            if change=. then change=0;
		        end;

			/* Lowcase */
			cmpgn_nm = strip(lowcase(cmpgn_nm));

		run;

		* 2020-2021 cleaning;
/*		data ps_el.el_tbl2;*/
/*			set ps_el.el_tbl2;*/
/*			if keyword_theme = 'broad' then delete;*/
/*			if el_clicks > 0 or el_impressions > 0 or el_cost > 0 or business_actions > 0 or business_leads > 0;*/
/*			if campaign="b2b_southern california_ps_b product known_bmm_general" then delete;*/
/*			if region = 'KPWAS' then region = 'KPWA';*/
/*			if keyword_category in ('BPK','NBPK') then delete;*/
/*		run;*/

		/* Validation */
		proc freq data=ps_el.el_tbl2;
			tables engine
					keyword_theme*ad_group
					Match_Type
					keyword_category
					region*SubRegion
					lookup_region
					lookup_year*lookup_month					
			/ norow nocol nopercent;
		run;

		proc sql;
		select distinct 
			date
		,	sum(el_cost) as el_cost format dollar18.2
		,	sum(el_impressions) as el_impressions format comma18.
		,	sum(el_clicks) as el_clicks format comma18.
		,	sum(business_actions) as business_actions format comma8.2
		,	sum(business_leads) as business_leads format comma8.
		from ps_el.el_tbl2
		group by 
			date;
		quit;
		%check_for_data(ps_el.el_tbl2,=0,No data in el_tbl2);

		proc delete data=ps_el.el_tbl1; run &cancel.;

	%end;
	%if &cancel= and &Nnew>0 %then %do;

		proc sql;
			create table check_dups as
			select 
				t1.* , t2.ndups
			from ps_el.el_tbl2 t1
				, (select 
						date, engine, campaign, count(*) as ndups
				   from ps_el.el_tbl2 
				   group by date, engine, campaign
				   ) t2
			where t2.ndups>1 
				and t1.date=t2.date 
				and t1.engine=t2.engine 
				and t1.campaign=t2.campaign
				order by t1.date, t1.engine, t1.campaign;
		
		select distinct count(*) into :dupes from check_dups;

		quit;
		*%check_for_data(check_dups,>0,Dupes in raw data from RDM);

	%end;
	%if &cancel= and &Nnew>0 and &dupes>0 %then %do;

		proc sql;

		select distinct count(*) into :cnt_before from ps_el.el_tbl2;

		create table ps_el.el_tbl2 as
			select distinct
				Date
			,	Campaign
			,	sum(EL_Cost) as EL_Cost format dollar18.2
			,	sum(EL_Impressions) as EL_Impressions format comma8.
			,	sum(EL_Clicks) as EL_Clicks format comma8.
			,	Engine
			,	Ad_Group
			,	Keyword_Theme
			,	Match_Type
			,	Keyword_Category
			,	Region
			,	SubRegion
			,	max(Impr_share) as Impr_Share format percent7.2
			,	sum(Business_Actions) as Business_Actions format comma8.2
			,	sum(Business_Leads) as Business_Leads format comma8.2
			,	Lookup_Region
			,	Lookup_Year
			,	Lookup_Month
			from ps_el.el_tbl2
			group by 
				Date
			,	Campaign
			,	Engine
			,	Ad_Group
			,	Keyword_Theme
			,	Match_Type
			,	Keyword_Category
			,	Region
			,	SubRegion
			,	Lookup_Region
			,	Lookup_Year
			,	Lookup_Month;

			select distinct count(*) into :cnt_after from ps_el.el_tbl2;

			quit;

/*		proc sort data=ps_el.el_tbl2; */
/*			by date engine campaign descending EL_Cost Descending Business_Actions;*/
/*		run;*/
/*		data ps_el.el_tbl2;*/
/*			set ps_el.el_tbl2;*/
/*			by date engine campaign descending EL_Cost Descending Business_Actions;*/
/*			if first.campaign then output;*/
/*		run;*/

		proc sql;
			create table check_dups as
			select 
				t1.* , t2.ndups
			from ps_el.el_tbl2 t1
				, (select 
						date, engine, campaign, count(*) as ndups
				   from ps_el.el_tbl2 
				   group by date, engine, campaign
				   ) t2
			where t2.ndups>1 
				and t1.date=t2.date 
				and t1.engine=t2.engine 
				and t1.campaign=t2.campaign
				order by t1.date, t1.engine, t1.campaign;
		
		select distinct count(*) into :dupes from check_dups;

		quit;

		%put WARNING: %eval(&cnt_before-&cnt_after) dupe(s) removed.;

	%end;
	%if &cancel= and &Nnew>0 and &dupes=0 %then %do;

	/* -------------------------------------------------------------------------------------------------*/
	/*  Join Lookup B2B EL Contribution                                                                 */
	/* -------------------------------------------------------------------------------------------------*/

		%let error_rsn=Error cleaning raw data step 2.;

		proc sql;
		create table ps_el.el_tbl3 as
			select distinct
				x.*
			,	coalesce(y.B2B_Contrib_Actual,y.B2B_Contrib_Budget) as B2B_Contrib
			,	case when y.B2B_Contrib_Actual = . then 0 else 1 end as Flag_Final
			from ps_el.el_tbl2 x
			left join ps_el.el_contribution y
				on x.lookup_region = y.lookup_region
				and x.lookup_year = y.lookup_year
				and ((y.lookup_month ne . and x.lookup_month = y.lookup_month) /* non-AEP */
						or (y.lookup_month = . and x.Date >= y.Lookup_WeekStart and x.Date <= y.Lookup_Weekend)) /* AEP */
		;
		quit;

		data ps_el.el_tbl4;

			set ps_el.el_tbl3;

			format 
				B2B_Cost dollar18.2
				B2B_Impressions comma18.
				B2B_Clicks comma18.;

			B2B_Cost = round(EL_Cost*B2B_Contrib,0.01);
			B2B_Impressions = round(EL_Impressions*B2B_Contrib,1);
			B2B_Clicks = round(EL_Clicks*B2B_Contrib,1);

		run;

		%check_for_data(ps_el.el_tbl4,=0,No data in el_tbl4);
		proc delete data=ps_el.el_tbl2; run &cancel.;

	%end;
	%if &cancel= and &Nnew>0 and &dupes=0 %then %do;

	/* -------------------------------------------------------------------------------------------------*/
	/*  Update Budgeted B2B EL Contribution --> Final                                                   */
	/* -------------------------------------------------------------------------------------------------*/

		%let error_rsn=Error updating budgeted contribution step 1.;

		proc sql;
		create table ps_el.campaign_master_budgeted as
			select distinct
				x.*
			,	y.B2B_Contrib_Actual as B2B_Contrib_new
			,	1 as Flag_Final_new
			from final.b2b_paidsearch_el_raw x
			inner join ps_el.el_contribution y 
				on x.lookup_region = y.lookup_region
				and x.lookup_year = y.lookup_year
				and ((y.lookup_month ne . and x.lookup_month = y.lookup_month) /* non-AEP */
					or (y.lookup_month = . and x.Date >= y.Lookup_WeekStart and x.Date <= y.Lookup_Weekend)) /* AEP */
				and y.B2B_Contrib_Actual ne .
			where x.Flag_Final = 0 /* Updated "Budget" to "Actual" */
				/* manual update */
/*				or (x.lookup_region='Colorado' and x.lookup_month=5 and x.lookup_year=2021)*/
				;
		quit;
		data ps_el.campaign_master_budgeted;
			keep date campaign region
				cost impressions clicks
				cost_new impressions_new clicks_new flag_final_new;

			set ps_el.campaign_master_budgeted;

			format 
				Cost_new dollar18.2
				Impressions_new comma18.
				Clicks_new comma18.;

			Cost_new = round(EL_Cost*B2B_Contrib_new,0.01);
			Impressions_new = round(EL_Impressions*B2B_Contrib_new,1);
			Clicks_new = round(EL_Clicks*B2B_Contrib_new,1);
		run;
		proc sql ; select distinct count(*) into :N_update from ps_el.campaign_master_budgeted; quit;

	%end;
	%if &cancel= and &N_update>0 %then %do; *Only update if there are updates available;

		proc sort data=final.b2b_paidsearch_el_raw; by Date Campaign; run;
		proc sort data=ps_el.campaign_master_budgeted; by Date Campaign; run;

		* Update b2b_paidsearch_el_raw; 
		data final.b2b_paidsearch_el_raw;
		
			merge final.b2b_paidsearch_el_raw(in=a)
				  ps_el.campaign_master_budgeted(in=b);
			by Date Campaign;

			if a and b then do;
				Cost = Cost_New;
				Impressions_new = Impressions_new;
				Clicks = Clicks_new;
				Flag_Final = Flag_Final_new;
				Lookup_Region = '';
				Lookup_Year = .;
				Lookup_Month = .;
				Lookup_Week = .;
			end;
			drop Flag_Final_new
				 Cost_new
				 Impressions_new
				 Clicks_new;
		run;
		proc sql;
			select distinct
				year(Date) as Year
			,	month(Date) as Month
			,	Region
			,	sum(Cost) as Cost_Old format dollar18.2
			,	sum(Cost_new) as Cost_New format dollar18.2
			,	sum(impressions) as Impr_Old format comma8.
			,	sum(Impressions_new) as Impr_New format comma8.
			,	sum(Clicks) as Clicks_Old format comma8.
			,	sum(Clicks_New) as Clicks_New format comma8.
			from ps_el.campaign_master_budgeted
			group by 
				year(Date)
			,	month(Date)
			,	Region;

			select distinct
				year(Date) as Year
			,	month(Date) as Month
			,	Region
			,	sum(Cost) as Cost_New format dollar18.2
			,	sum(impressions) as Impr_New format comma8.
			,	sum(Clicks) as Clicks_New format comma8.
			from final.b2b_paidsearch_el_raw
			where year(date) in (select distinct year(date) from ps_el.campaign_master_budgeted)
				and month(date) in (select distinct month(date) from ps_el.campaign_master_budgeted)
			group by 
				year(Date)
			,	month(Date)
			,	Region;

		quit;

		* Update b2b_campaign_master;
		proc sort data=prod.B2B_Campaign_Master out=b2b_campaign_master; by date campaign; run;
		proc sort data=final.b2b_paidsearch_el_raw; by date campaign; run;

/*		proc sort data=b2b_campaign_master; by date campaign; run;*/ /* temporary remove */

		data B2B_Campaign_Master;
			merge B2B_Campaign_Master(in=a where=(ChannelDetail='Paid Search-EL'))
				  final.b2b_paidsearch_el_raw(in=b where=(date >= intnx('month',today(),-8,'b'))
						 rename=(Cost=Spend_New Impressions=Impressions_New Clicks=Clicks_New)
						 keep=date campaign cost impressions clicks);
			by date campaign;

			Spend = coalesce(Spend_New,Spend,0);
			Impressions = coalesce(Impressions_New,Impressions,0);
			Clicks = coalesce(Clicks_New,Clicks,0);

			drop Spend_New Impressions_New Clicks_New;

			if b and not a then delete;

		run;	
		proc sql;
		select distinct
			year(date) as Year
		,	month(date) as Month
		,	sum(spend) as cost format dollar18.2
		,	sum(impressions) as impr
		,	sum(clicks) as clicks
		,	count(*) as rec
		from B2B_Campaign_Master
		where ChannelDetail='Paid Search-EL' and date >= intnx('month',today(),-12,'b')
		group by year(date),month(date);

		select distinct
			year(date) as Year
		,	month(date) as Month
		,	sum(spend) as cost format dollar18.2
		,	sum(impressions) as impr
		,	sum(clicks) as clicks
		,	count(*) as rec
		from prod.B2B_Campaign_Master x
		where ChannelDetail='Paid Search-EL' and date >= intnx('month',today(),-12,'b')
		group by year(date),month(date);
		quit;
		proc sql;
			create table check_dups as
			select 
				t1.* , t2.ndups
			from B2B_Campaign_Master t1
				, (select 
						date, campaign, count(*) as ndups
				   from B2B_Campaign_Master 
				   where channeldetail='Paid Search-EL'
				   group by date, campaign
				   ) t2
			where t2.ndups>1 
				and t1.date=t2.date 
				and t1.campaign=t2.campaign
				and t1.channeldetail='Paid Search-EL'
				order by t1.date, t1.campaign;
		quit;

		data prod.b2b_campaign_master;
			set B2B_Campaign_Master /* only EL */
				prod.B2B_Campaign_Master (where=(ChannelDetail ne 'Paid Search-EL'));
		run;
	
	%end; *End updating actual budget;

	%if &cancel= and &Nnew>0 and &dupes=0 %then %do;

		proc delete data=ps_el.el_tbl3; run &cancel.;
		proc delete data=ps_el.el_contribution; run &cancel.;

	/* -------------------------------------------------------------------------------------------------*/
	/*  Final Raw EL File                                                                               */
	/* -------------------------------------------------------------------------------------------------*/

		%let error_rsn=Error cleaning raw data step 3.;

		proc sql;
		create table ps_el.el_rawfinal as
		select distinct
				Date format mmddyy10.
			,	strip(put(Year(Date),8.)) as Year
			,	catt('Q',qtr(date)) as Quarter format $2.
			,	Campaign
			,	B2B_Cost as Cost format dollar18.2
			,	B2B_Impressions as Impressions format comma18.
			,	B2B_Clicks as Clicks format comma18.
			,	Ad_Group
			,	'EL' as Business_Size
			,	Engine
			,	Match_Type
			,	Keyword_Theme
			,	Keyword_Category
			,	'N' as Remarketing
			,	Region
			,	SubRegion 
			,	Impr_Share format percent7.2
			,	Business_Actions 
			,	Business_Leads 
			,	Flag_Final
			,	case when Flag_Final = 0 then Lookup_Region end as Lookup_Region
			,	case when Flag_Final = 0 then Lookup_Year end as Lookup_Year
			,	case when Flag_Final = 0 then Lookup_Month end as Lookup_Month
			,	EL_Cost format dollar18.2
			,	EL_Impressions format comma18.
			,	EL_Clicks format comma18.
			from ps_el.el_tbl4;
		quit; 
		%check_for_data(ps_el.el_rawfinal,=0,No data in final raw data);

	%end;
	%if &cancel= and &Nnew>0 and &dupes=0 %then %do;

		proc sql;
			create table check_dups as
			select 
				t1.* , t2.ndups
			from ps_el.el_rawfinal t1
				, (select 
						date, engine, campaign, count(*) as ndups
				   from ps_el.el_rawfinal 
				   group by date, engine, campaign
				   ) t2
			where t2.ndups>1 
				and t1.date=t2.date 
				and t1.engine=t2.engine 
				and t1.campaign=t2.campaign
				order by t1.date, t1.engine, t1.campaign;
		quit;
		%check_for_data(check_dups,>0,Dupes in final raw data);

		proc delete data=ps_el.el_tbl4; run &cancel.;

	%end;
	%if &cancel= and &Nnew>0 and &dupes=0 %then %do;

	/* -------------------------------------------------------------------------------------------------*/
	/*  Export and archive raw enterprise listing search.                                                                 */
	/* -------------------------------------------------------------------------------------------------*/
		
		%let error_rsn=Error updating B2B_PaidSearch_EL_Raw.;

		data ps_el.B2B_PaidSearch_EL_Raw_Temp;
			set final.B2B_PaidSearch_EL_Raw;
		run;
		
		proc sql;
		insert into final.B2B_PaidSearch_EL_Raw
			select * from ps_el.el_rawfinal;
		quit;

	* If you added/removed or changed the formatting of a variable, run this instead;

/*		proc delete data=final.B2B_PaidSearch_EL_Raw; run;*/
/*		data final.B2B_PaidSearch_EL_Raw;*/
/*			set ps_el.el_rawfinal*/
/*				ps_el.B2B_PaidSearch_EL_Raw_Temp; */
/*		run;*/
		
	/* -------------------------------------------------------------------------------------------------*/
	/*  Save master file --> zip archive.                                                               */
	/* -------------------------------------------------------------------------------------------------*/

		%let error_rsn=Error writing to Archive.;

		proc sql noprint;
			select
				min(Date) format mmddyy6.,
				max(Date) format mmddyy6.,
				max(Date) format date9.
			into :FirstData,
				 :LastData,
				 :LastDate_ThisUpdate
			from final.B2B_PaidSearch_EL_Raw;
		quit;

		data archive.B2B_PS_EL_Raw_&FirstData._&LastData;
			set final.B2B_PaidSearch_EL_Raw;
		run;

		ods package(archived) open nopf;
		ods package(archived) add file="&final_file_path/Archive/b2b_ps_el_raw_&FirstData._&LastData..sas7bdat";
		ods package(archived) publish archive properties (
			archive_name="b2b_ps_el_raw_&FirstData._&LastData..zip"
			archive_path="&final_file_path/Archive/");
		ods package(archived) close;
		proc delete data=archive.B2B_PS_EL_Raw_&FirstData._&LastData; run;

		filename old_arch "&final_file_path/Archive/b2b_ps_el_raw_&FirstData._&LastData_Old..zip";
		data _null_;
			rc=fdelete("old_arch");
			put rc=;
		run;

/* -------------------------------------------------------------------------------------------------*/
/*                                                                                                  */
/*                                                                                                  */
/*                                    Prepare for Campaign Dataset                                  */
/*                                                                                                  */
/*                                                                                                  */
/* -------------------------------------------------------------------------------------------------*/

* Jan 1, 2021 data and forward;

/* -------------------------------------------------------------------------------------------------*/
/*  Engine metrics from newly-added b2b_paidsearch_el_raw.                                          */
/* -------------------------------------------------------------------------------------------------*/

	%let error_rsn=Error compiling engine metrics.;

	proc sql;
		create table ps_el.paid_search_el as
			select distinct
				Date format mmddyy10.
			,	intnx('week',Date,0,'b') as WeekStart format mmddyy10.
			,	intnx('month',Date,0,'b') as Month format monyy7. 
			,	Quarter format $2.
			,	'Paid Search' as Channel format $25.
			,	'Paid Search-EL' as ChannelDetail format $25.
			,	Impressions format comma18.
			,	Clicks format comma8.
			,	Cost as Spend format dollar18.2
			,	Campaign format $250.
			,	Engine as Network format $25.
			,	Region format $5.
			,	SubRegion format $5.
			,	'Always On' as Program_Campaign format $30.
			,	Keyword_Theme as Theme format $50.
			,	Ad_Group as Creative format $200.
			,	Match_Type format $6.
			,	Remarketing format $3.
			,	Keyword_Category format $7.
			,	Business_Actions format comma8.2 /* rollup */
			,	Business_Leads as Business_Leads format comma8. /* rollup */
				/* Join Metrics */
			,	lowcase(Engine) as UTM_Source
			,	'cpc' as UTM_Medium
			,	Campaign as UTM_Campaign
			,	'' as UTM_Content /* not applicable */
			,	'' as UTM_Term /* not applicable */
			from ps_el.el_rawfinal 
			where Cost > 0 or Clicks > 0 or Impressions > 0 or Business_Actions > 0 or Business_Leads > 0
			order by 
				Date
			,	Keyword_Theme
			,	Region;
		quit;

/* -------------------------------------------------------------------------------------------------*/
/*  Google Analytics metrics for the same period from b2b_campaign_gadata.                          */
/* -------------------------------------------------------------------------------------------------*/

		%let error_rsn=Error compiling Google Analytics metrics.;

		proc sql ;
		select distinct
			min(Date) format date9.,
			max(Date) format date9.
		into	
			:Campaign_StartDate,
			:Campaign_EndDate
		from ps_el.paid_search_el;
		quit;

		proc sql;
		create table ps_el.better_way_el as
			select distinct
				Date
			,	UTM_Source
			,	UTM_Medium
			,	case when UTM_Campaign in ('(notset)','(not set)','{dscampaign}','')
					then '_error_' /* Prevent joining on bad data */
					else UTM_Campaign
					end as UTM_Campaign format $500.
			,	'' as UTM_Content /* not applicable */
			,	'' as UTM_Term /* not applicable */
			,	max(PromoID) as PromoID format $6. /* dupes */
			,	sum(coalesce(users,0)) as Users
			,	sum(coalesce(newusers,0)) as newUsers
			,	sum(coalesce(Sessions,0)) as Sessions
			,	sum(coalesce(Bounces,0)) as Bounces
			,	sum(coalesce(SessionDuration,0)) as SessionDuration format mmss.
			,	sum(coalesce(uniquePageviews,0)) as UniquePageviews
			,	sum(coalesce(ShopActions_Unique,0)) as ShopActions_Unique /* total clicks - not equivalent to goals */
			,	sum(coalesce(LearnActions_Unique,0)) as LearnActions_Unique /* total clicks - not equivalent to goals */
/*			,	sum(coalesce(ConvertActions_Unique,0)) as ConvertActions_Unique*/
/*			,	sum(coalesce(ShareActions_Unique,0)) as ShareActions_Unique*/
			,	sum(coalesce(goal7_Learn,0)) as goal7_Learn /* old goals */
			,	sum(coalesce(goal8_Shop,0)) as goal8_Shop /* old goals */

			,	sum(coalesce(Shop_Download,0)) as Shop_Download 
			,	sum(coalesce(ConvertNonSubmit_SSQ,0)) as ConvertNonSubmit_SSQ /* make this global */
			,	sum(coalesce(SB_MAS_Leads,0)) as SB_MAS_Leads
			,	sum(coalesce(Shop_Explore,0)) as Shop_Explore
			,	sum(coalesce(Shop_Interact,0)) as Shop_Interact
			,	sum(coalesce(Shop_Read,0)) as Shop_Read 
			,	sum(coalesce(ConvertNonSubmit_Quote,0)) as ConvertNonSubmit_Quote /* make this global */
			,	sum(coalesce(ConvertSubmit_Quote,0)) as ConvertSubmit_Quote /* make this global */
			,	sum(coalesce(ConvertNonSubmit_Contact,0)) as ConvertNonSubmit_Contact /* make this global */
			,	sum(coalesce(ConvertSubmit_Contact,0)) as ConvertSubmit_Contact /* make this global */
			,	sum(coalesce(Convert_Call,0)) as Convert_Call /* make this global */
			,	sum(coalesce(Learn_Download,0)) as Learn_Download 
/*			,	sum(Exit) as Exit */
			,	sum(coalesce(Learn_Explore,0)) as Learn_Explore 
			,	sum(coalesce(ManageAccount_BCSSP,0)) as ManageAccount_BCSSP
			,	sum(coalesce(Learn_Interact,0)) as Learn_Interact
			,	sum(coalesce(Learn_Read,0)) as Learn_Read 	
			,	sum(coalesce(Learn_Save,0)) as Learn_Save
			,	sum(coalesce(Learn_Watch,0)) as Learn_Watch 		
			,	sum(coalesce(Share_All,0)) as Share_All 
			/* new */
			,	sum(coalesce(goalValue,0)) as Weighted_Actions
			,	sum(coalesce(ConvertNonSubmit_QuoteVC,0)) as ConvertNonSubmit_QuoteVC
			,	sum(coalesce(ConvertNonSubmit_ContKPDiff,0)) as ConvertNonSubmit_ContKPDiff

			from archive.b2b_campaign_gadata
			where lowcase(UTM_Medium) = 'cpc'
				and Date >= "&Campaign_StartDate"d
				and Date <= "&Campaign_EndDate"d
			group by
				Date
			,	UTM_Source
			,	UTM_Medium
			,	case when UTM_Campaign in ('(notset)','(not set)','{dscampaign}','')
				then '_error_' /* Prevent joining on bad data */
				else UTM_Campaign
				end;
		quit;
		%check_for_data(ps_el.better_way_el,=0,No data found in Better Way for dates requested);

	%end;
	%if &cancel= and &Nnew>0 and &dupes=0 %then %do;

		proc sql;
			create table check_dups as
			select 
				t1.* , t2.ndups
			from ps_el.better_way_el t1
				, (select 
						date, utm_source, utm_medium, utm_campaign, utm_content, utm_term, count(*) as ndups
				   from ps_el.better_way_el
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
		%check_for_data(check_dups,>0,Dupes in better_way);

	%end;
	%if &cancel= and &Nnew>0 and &dupes=0 %then %do;

/* -------------------------------------------------------------------------------------------------*/
/*  Merge engine metrics with Google Analytics metrics                                              */
/* -------------------------------------------------------------------------------------------------*/
		
		%let error_rsn=Error merging tables.;

		proc sort data=ps_el.better_way_el; by date utm_source utm_medium utm_campaign utm_content utm_term; run;
		proc sort data=ps_el.paid_search_el; by date utm_source utm_medium utm_campaign utm_content utm_term; run;

		data ps_el.paidsearch_el_merged
			 ps_el.missing; 

			merge ps_el.paid_search_el (in=a)
				  ps_el.better_way_el (in=b);
			by date utm_source utm_medium utm_campaign utm_content utm_term;

			* Halo flag initialize;
			Halo_Actions = 0;

			if a then output ps_el.paidsearch_el_merged;
				else if find(utm_campaign,'kp_el_non') > 0 then do;

					Clean_Campaign = tranwrd(UTM_Campaign,'old_kp_el_non','kp_el_non');
	
					WeekStart=intnx('week',Date,0,'b');
					Month=intnx('month',Date,0,'b');
					Quarter=catt('Q',qtr(date));
					Channel='Paid Search';
					ChannelDetail='Paid Search-EL';
					Campaign=UTM_Campaign;
					Network=propcase(UTM_Source);
					Region=upcase(scan(Clean_Campaign,5,'_'));
						if Region = 'KPWAS' then Region = 'KPWA';
					SubRegion=upcase(scan(Clean_Campaign,6,'_'));
					Program_Campaign='Always On';
					if upcase(scan(Clean_Campaign,9,'_')) in ('NA','N3')
						then Theme = 'N/A';
						else Theme=upcase(scan(Clean_Campaign,9,'_'));
					Creative=propcase(scan(Clean_Campaign,14,'_'));
					if upcase(scan(Clean_Campaign,12,'_')) = 'EXT' then Match_Type = 'Exact';
						else if upcase(scan(Clean_Campaign,12,'_')) = 'BMM' then Match_Type = 'Broad';
						else if upcase(scan(Clean_Campaign,12,'_')) = 'PHR' then Match_Type = 'Phrase';
					Remarketing='N';
					Keyword_Category=upcase(scan(Clean_Campaign,10,'_'));
						if Theme = 'MEM' then Keyword_Category=catt(Keyword_Category,'-MEM');
					PromoID=''; /* need to work on this! */
					/* Halo Action Flag */
					Halo_Actions = 1;
					drop Clean_Campaign;
					output ps_el.missing;
				end;
			
		run;

	%let error_rsn=Error appending tables.;

		data ps_el.b2b_campaign_master_el;

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
	/*					Pageviews comma8.*/
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
	/*					Exit comma8.*/
						Learn_Explore comma8.
						ManageAccount_BCSSP comma8.
						Learn_Interact comma8.
						Learn_Read comma8.	
						Learn_Save comma8.
						Learn_Watch comma8.		
						Share_All comma8.

						Weighted_Actions comma8.2
						ConvertNonSubmit_QuoteVC comma8.
						ConvertNonSubmit_ContKPDiff comma8.

						Business_Actions comma8.
						Business_Leads comma8.
						VideoStarts comma8.
						VideoCompletions comma8.
						Total_Engagements comma8.
						Total_Social_Actions comma8. 
						Leads comma8.
						Lead_Forms_Opened comma8.
						Primary_Downloads comma8. 
						Primary_Contacts comma8. 
						Secondary_Downloads comma8. 

						Halo_Actions comma8.

						UTM_Source /* NEW */
						UTM_Medium /* NEW */
						UTM_Campaign /* NEW */
						UTM_Content /* NEW */
						UTM_Term /* NEW */
				;
		 	set ps_el.paidsearch_el_merged
				ps_el.missing;

			Keyword='N/A';
			Image='N/A';
			Ad_Format='N/A';
			Audience='N/A'; /* = Enterprise Listing */
			VideoStarts=.;
			VideoCompletions=.;
			Lead_Forms_Opened=.;
			Leads=.;
			Total_Engagements=.;
			Total_Social_Actions=.;
			Primary_Downloads=.;
			Primary_Contacts=.;
			Secondary_Downloads=.;

			* Replace missing numeric w/ 0;
			 array change _numeric_;
		        do over change;
		            if change=. then change=0;
		        end;

		run;
		%check_for_data(ps_el.B2B_Campaign_Master_el,=0,No data found in final EL campaign table);

	%end;
	%if &cancel= and &Nnew>0 and &dupes=0 %then %do;
	
	/* -------------------------------------------------------------------------------------------------*/
	/*  Export and archive raw enterprise listing search.                                                                 */
	/* -------------------------------------------------------------------------------------------------*/

	%let error_rsn=Error updating B2B_Campaign_Master.;

		data ps_el.B2B_Campaign_Master_Temp;
			set prod.B2B_Campaign_Master;
		run;

		proc sql;
		insert into prod.B2B_Campaign_Master
			select  
				*
			,   .
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
			, 	.
			,	.
			,	.
			, 	.
			,	.
			,	.
			,	datetime() 
			from ps_el.B2B_Campaign_Master_el;
		quit;

	* If you added/removed or changed the formatting of a variable, run this instead;		

/*		proc delete data=prod.B2B_Campaign_Master; run;*/
/*		data prod.B2B_Campaign_Master;*/
/*			set ps_el.B2B_Campaign_Master_el(in=a)*/
/*				ps_el.B2B_Campaign_Master_Temp(in=b); */
/*			if a then Rec_Update_Date = datetime();*/
/*		run;*/
	
	/* -------------------------------------------------------------------------------------------------*/
	/*  Save master file --> zip archive.                                                               */
	/* -------------------------------------------------------------------------------------------------*/
		
		%let error_rsn=Error writing to archive.;

		proc sql noprint;
			select
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

		%let filename_oldarchive=DNE; *Initialize;
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
		from final.B2B_PaidSearch_EL_Raw
		where Date >= "&Campaign_StartDate"d;
		quit;

		options dlcreatedir;
		libname freq xlsx "&input_files/Frequency Tables - Get_EL_Data_Weekly.xlsx"; run;
		proc sql;
		create table freq.'Raw Data Append by Date'n as
			select distinct
				Date
			,	case when Date>="&Campaign_StartDate"d then 1 else 0 end as New_Data
			,	sum(cost) as Spend format dollar18.2
			,	sum(impressions) as Impressions format comma18.
			,	sum(clicks) as Clicks format comma18.
			,	sum(business_actions) as Connex_actions format comma8.2
			,	sum(business_leads) as Connex_leads format comma8.
			,	sum(clicks)/sum(impressions) as CTR
			,	sum(cost)/sum(clicks) as CPC
			from final.B2B_PaidSearch_EL_Raw
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
			,	sum(business_actions) as Connex_actions format comma8.2
			,	sum(weighted_actions) as GA_actions format comma8.2
			,	sum(business_actions)/sum(weighted_actions)-1 as Pct_Diff_Actions format percent7.2
			,	sum(business_leads) as Connex_leads format comma8.
			,	sum(ConvertSubmit_Contact+ConvertSubmit_Quote+SB_MAS_Leads+ConvertNonSubmit_SSQ*0.43) as GA_leads format comma8.
			,	sum(business_leads)/sum(ConvertSubmit_Contact+ConvertSubmit_Quote+SB_MAS_Leads+ConvertNonSubmit_SSQ*0.43)-1 as Pct_Diff_Leads format percent7.2
			,	sum(sessions) As Sessions format comma8.
			,	sum(clicks)/sum(impressions) as CTR
			,	sum(sessions)/sum(impressions) as VR
			,	sum(weighted_actions)/sum(sessions) as Actions_Per_Visit
			from prod.B2B_Campaign_Master
			where ChannelDetail='Paid Search-EL'
				and Date>=intnx('day',"&Campaign_StartDate"d,-&days.,'s')
			group by 
				Date;
		quit;
		proc sql;
		create table freq.'Final Append by LOB'n as
			select distinct
				ChannelDetail
			,	case when Date>="&Campaign_StartDate"d then 1 else 0 end as New_Data
			,	sum(spend) as Spend format dollar18.2
			,	sum(impressions) as Impressions format comma18.
			,	sum(clicks) as Clicks format comma18.
			,	sum(business_actions) as Connex_actions format comma8.2
			,	sum(weighted_actions) as GA_actions format comma8.2
			,	sum(business_actions)/sum(weighted_actions)-1 as Pct_Diff_Actions format percent7.2
			,	sum(business_leads) as Connex_leads format comma8.
			,	sum(ConvertSubmit_Contact+ConvertSubmit_Quote+SB_MAS_Leads+ConvertNonSubmit_SSQ*0.43) as GA_leads format comma8.
			,	sum(business_leads)/sum(ConvertSubmit_Contact+ConvertSubmit_Quote+SB_MAS_Leads+ConvertNonSubmit_SSQ*0.43)-1 as Pct_Diff_Leads format percent7.2
			,	sum(sessions) As Sessions format comma8.
			,	sum(clicks)/sum(impressions) as CTR
			,	sum(sessions)/sum(impressions) as VR
			,	sum(weighted_actions)/sum(sessions) as Actions_Per_Visit
			from prod.B2B_Campaign_Master
			where ChannelDetail='Paid Search-EL'
				and Date>=intnx('day',"&Campaign_StartDate"d,-&days.,'s')
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
			,	sum(business_actions) as Connex_actions format comma8.2
			,	sum(weighted_actions) as GA_actions format comma8.2
			,	sum(business_actions)/sum(weighted_actions)-1 as Pct_Diff_Actions format percent7.2
			,	sum(business_leads) as Connex_leads format comma8.
			,	sum(ConvertSubmit_Contact+ConvertSubmit_Quote+SB_MAS_Leads+ConvertNonSubmit_SSQ*0.43) as GA_leads format comma8.
			,	sum(business_leads)/sum(ConvertSubmit_Contact+ConvertSubmit_Quote+SB_MAS_Leads+ConvertNonSubmit_SSQ*0.43)-1 as Pct_Diff_Leads format percent7.2
			,	sum(sessions) As Sessions format comma8.
			,	sum(clicks)/sum(impressions) as CTR
			,	sum(sessions)/sum(impressions) as VR
			,	sum(weighted_actions)/sum(sessions) as Actions_Per_Visit
			from prod.B2B_Campaign_Master
			where ChannelDetail='Paid Search-EL'
				and Date>=intnx('day',"&Campaign_StartDate"d,-&days.,'s')
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
		proc delete data=ps_el.b2b_campaign_master_temp; run;
		* Second backup of b2b_paidsearch_el_raw;
		ods package(archived) open nopf;
		ods package(archived) add file="&input_files/b2b_paidsearch_el_raw_temp.sas7bdat";
		ods package(archived) publish archive properties (
			archive_name="b2b_paidsearch_el_raw_temp.zip"
			archive_path="&input_files/");
		ods package(archived) close;
		proc delete data=ps_el.b2b_paidsearch_el_raw_temp; run &cancel.;
		* Delete files from most recent update;
		proc delete data=ps_el.better_way_el; run &cancel.;
		proc delete data=ps_el.paid_search_el; run &cancel.;
		proc delete data=ps_el.paidsearch_el_merged; run &cancel.;
		proc delete data=ps_el.missing; run;
		proc delete data=ps_el.b2b_campaign_master_el; run &cancel.;
		proc delete data=ps_el.el_rawfinal; run &cancel.;
		proc delete data=ps_el.campaign_master_budgeted; run &cancel.;

	%end;

/* -------------------------------------------------------------------------------------------------*/
/*  Email log.                                                                                      */
/* -------------------------------------------------------------------------------------------------*/ 		

	/* you may change the default sentFrom and sentTo */
	%emailB2Bdashboard(Get_EL_Data_Weekly,
			attachFreqTableFlag=1,
			attachLogFlag=1
			/*sentFrom=,
			sentTo=*/
			);	

	proc printto; run; /* Turn off log export to .txt */



