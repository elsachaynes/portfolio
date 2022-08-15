/****************************************************************************************************/
/*  Program Name:       Get_Display_Data_Weekly.sas                                                 */
/*                                                                                                  */
/*  Date Created:       Oct 29, 2020                                                                */
/*                                                                                                  */
/*  Created By:         Elle Haynes                                                                 */
/*                                                                                                  */
/*  Purpose:            Compiles daily data from Adform B2B Display Ads for the B2B Dashboard.      */
/*                                                                                                  */
/*  Inputs:             This script can run on schedule without input.                              */
/*                                                                                                  */
/* -------------------------------------------------------------------------------------------------*/	
/*  Notes:              Input .xlsx file emailed Mondays ~3PM and automatically saved via VBA.      */
/* -------------------------------------------------------------------------------------------------*/
/*  Date Modified:      Nov 17, 2020                                                                */
/*  Modified by:        Elle Haynes                                                                 */
/*  Description:        Added logic to delete records outside the newest 7 day range during import. */
/*                                                                                                  */
/*  Date Modified:      Jan 5, 2021                                                                 */
/*  Modified by:        Elle Haynes                                                                 */
/*  Description:        Adjust the import process to 1) look for XLSX file types in the directory,  */
/*                      and then only if >0 are found, 2) import (all) XLSX files, checking for new */
/*                      data based on date > last date in the master file.                          */
/*                                                                                                  */
/*  Date Modified:      Apr 20, 2021                                                                */
/*  Modified by:        Elle Haynes                                                                 */
/*  Description:        Changed output file path /gpfsFS2/sasdata/nfs/ndc_grid/po_imca_product/B2B  */
/*                                                                                                  */
/*  Date Modified:      May 18, 2021                                                                */
/*  Modified by:        Elle Haynes                                                                 */
/*  Description:        Print log to intput file path.                                              */
/*                                                                                                  */
/*  Date Modified:      May 25, 2021                                                                */
/*  Modified by:        Elle Haynes                                                                 */
/*  Description:        Added regional initiative processing (Lane County).                         */
/*                                                                                                  */
/*  Date Modified:      Jun 11, 2021                                                                */
/*  Modified by:        Elle Haynes                                                                 */
/*  Description:        Standardized Region and SubRegion to match PS/LI channel abbreviations.     */
/*                                                                                                  */
/*  Date Modified:      April 21, 2022                                                              */
/*  Modified by:        Elle Haynes                                                                 */
/*  Description:        Changed email output to use new email macro: SAS_Macro_Email.               */
/****************************************************************************************************/

	filename old_log "/gpfsFS2/sasdata/nfs/ndc_grid/po_imca_digital/EHaynes/B2B Dashboard Data Processing/Display/LOG Get_Display_Data_Weekly.txt";
	data _null_; rc=fdelete("old_log"); put rc=; run;
	proc printto log="/gpfsFS2/sasdata/nfs/ndc_grid/po_imca_digital/EHaynes/B2B Dashboard Data Processing/Display/LOG Get_Display_Data_Weekly.txt"; run;

	* Raw Data Download Folder;
	%let raw_file_path = /gpfsFS2/sasdata/nfs/ndc_grid/po_imca_digital/EHaynes/B2B Dashboard Data Processing/_Raw Data Downloads;
	libname import "&raw_file_path";

	%let input_files = /gpfsFS2/sasdata/nfs/ndc_grid/po_imca_digital/EHaynes/B2B Dashboard Data Processing/Display;
	libname display "&input_files";

	%let output_files = /gpfsFS2/sasdata/adhoc/po/imca/product/B2B;
	libname final "&output_files";
	libname archive "&output_files/Archive"; 

	%let production_path= /gpfsFS2/sasdata/nfs/ndc_grid/po_imca_product/B2B;
	libname prod "&production_path";

	%let dt=.; *"11jan2021"d; *leave empty unless running manually;
	%let N=0; *initialize, number of new observations from imported (value dem) dataset;
	%let Cnt_Creative=0; *initialize, creative names found in raw data not already cleaned;
	%let FirstData=;
	%let Cancel=;
	%let combined_file=;
	%let valid_spend=1; %let spend=0;
	%let valid_conv=1; %let conv=0;
	%let valid_visit=1; %let visit=0;
	%let nRaw=0; %let nCam=0; %let Nnew=0;

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

	%list_files(&raw_file_path);

	* initialize;
	%let nfiles_b=0; %let nfiles_cs=0; %let nfiles_iw=0; %let nfiles_em=0; %let nfiles_da=0;
	%let filename_b=0; %let filename_cs=0; %let filename_iw=0; %let filename_em=0; %let filename_da=0;
	%let N_b=0; %let N_iw=0; %let N_cs=0; %let N_em=0; %let N_da=0;

	proc sql ;

		title "Basis Display & Native";
		select 
			count(*) 
		,	strip(the_name)
		into :nfiles_b,
			 :filename_b separated by '|'
		from list 
		where find(the_name,'Basis KAIS101','i')>0
				and find(the_name,'~')=0;

		title "Intentsify Content Syndication";
		select 
			count(*) 
		,	strip(the_name)
		into :nfiles_cs,
			 :filename_cs separated by '|'
		from list 
		where find(the_name,'Intentsify KAIS101','i')>0
				and find(the_name,'~')=0;
	
		title "Industry Week Display";
		select 
			count(*) 
		,	strip(the_name)
		into :nfiles_iw,
			 :filename_iw separated by '|'
		from list 
		where find(the_name,'IW KAIS101','i')>0
				and find(the_name,'~')=0;

		title "Industry Week Email Newsletter";
		select 
			count(*) 
		,	strip(the_name)
		into :nfiles_em,
			 :filename_em separated by '|'
		from list 
		where find(the_name,'Kasier Email Newsletter Results','i')>0
				and find(the_name,'~')=0;

		title "Data Axle Display";
		select 
			count(*) 
		,	strip(the_name)
		into :nfiles_da,
			 :filename_da separated by '|'
		from list 
		where find(the_name,'Kaiser_Display Raw Data','i')>0
				and find(the_name,'~')=0;

	quit;
	proc delete data=list; run;

	%let raw_data_source=&filename_b, &filename_cs, &filename_iw, &filename_em, &filename_da;
	%let raw_data_source=%sysfunc(tranwrd(%quote(&raw_data_source),%str(, ,),%str()));
	%put &raw_data_source.;

	%if &nfiles_b=0 and &nfiles_cs=0 and &nfiles_iw=0 and &nfiles_em=0 and &nfiles_da=0 %then %do;
		%let error_rsn = No new files found in input folder.;
		%let cancel=cancel;
	%end;

	proc sql ;
		title 'Last Basis data';
		select distinct
			max(Date) format mmddyy6.
		,	max(Date) format date9.
		into :LastData_Old_B trimmed,
			 :LastData_OldNum_B trimmed
		from final.B2B_Display_Raw
		where Network = 'Basis DSP'
			and Impressions > 0;

		title 'Last CS data';
		select distinct
			max(Date) format mmddyy6.
		,	max(Date) format date9.
		into :LastData_Old_CS trimmed,
			 :LastData_OldNum_CS trimmed
		from final.B2B_Display_Raw
		where PurchaseType = 'Content Syndication';

		title 'Last Industry Week display data';
		select distinct
			max(Date) format mmddyy6.
		,	max(Date) format date9.
		into :LastData_Old_IW trimmed,
			 :LastData_OldNum_IW trimmed
		from final.B2B_Display_Raw
		where Network = 'IndustryWeek' 
			and PurchaseType = 'Direct Buy'
			and Impressions > 0;

		title 'Last Industry Week email data';
		select distinct
			max(Date) format mmddyy6.
		,	max(Date) format date9.
		into :LastData_Old_EM trimmed,
			 :LastData_OldNum_EM trimmed
		from final.B2B_Display_Raw
		where Network = 'IndustryWeek' 
			and PurchaseType = 'Email Newsletter';

		title 'Last Archive data';
		select distinct
			max(Date) format mmddyy6.
		into :LastData_Old trimmed
		from final.B2B_Display_Raw;
		title;
	quit;

/* -------------------------------------------------------------------------------------------------*/
/*                                                                                                  */
/*                                                                                                  */
/*                                         Ingest Raw Data                                          */
/*                                                                                                  */
/*                                                                                                  */
/* -------------------------------------------------------------------------------------------------*/

	/* -------------------------------------------------------------------------------------------------*/
	/*  Basis.                                                                                          */
	/* -------------------------------------------------------------------------------------------------*/

	%put Importing &nfiles_b. raw Basis files.;

	%if &cancel= and &nfiles_b>0 %then %do; /* (1) */

		%let i = 1;

		%macro Append_Import_B();

		%do %while (&i <= &nfiles_b);

				%let filename_loop = %sysfunc(scan(&filename_b,&i,'|'));
				%put &filename_loop;

				proc import 
					datafile="&raw_file_path./&filename_loop..xlsx"
					dbms=xlsx
					out=raw_&i. replace;
					range="'KAIS101'$A14:U100000";
					getnames=yes;
				run;

				data display.display_clean_basis_&i.; 
					format AdDate mmddyy10.
						   Campaign_StartDate mmddyy10.
						   Campaign_EndDate mmddyy10.
						   'Brand Name'n $75.
						   'Campaign Name'n $50.
						   'Line Item Name'n $100.
						   'Group Name'n $50.
						   'Tactic Name'n $75.
						   'Ad Label'n $75.
						   Size $10.
						   'Imps. Won'n comma12.
						   Clicks comma12.
						   Spend dollar18.2
						   'Net eCPM'n dollar18.2;

					keep AdDate 
						 Campaign_StartDate
						 Campaign_EndDate
						 'Brand Name'n
						 'Campaign Name'n
						 'Line Item Name'n
						 'Group Name'n
						 'Tactic Name'n
						 'Ad Label'n
						 Size
						 'Imps. Won'n
						 Clicks
						 Spend
						 'Net eCPM'n;
						 
					set raw_&i.;

					rename
						 'Brand Name'n = Brand
						 'Campaign Name'n = Campaign
						 'Line Item Name'n = LineItem
						 'Group Name'n = Group
						 'Tactic Name'n = Tactic
						 'Ad Label'n = AdLabel
						 'Imps. Won'n = Impressions
						 'Net eCPM'n = eCPM
						 ;

					* AdDate;
					AdDate1=input(Date,mmddyy10.);
					AdDate2=input(Date,yymmdd10.);
					AdDate3=Date;*Already numeric;
					AdDate=coalesce(AdDate1,AdDate2,AdDate3);

					* Campaign_StartDate;
					Campaign_StartDate1=input('Start Date'n,mmddyy10.);
					Campaign_StartDate2=input('Start Date'n,yymmdd10.);
					Campaign_StartDate3='Start Date'n;
					Campaign_StartDate=coalesce(Campaign_StartDate1,Campaign_StartDate2,Campaign_StartDate3);

					* Campaign_EndDate;
					Campaign_EndDate1=input('End Date'n,mmddyy10.);
					Campaign_EndDate2=input('End Date'n,yymmdd10.);
					Campaign_EndDate3='End Date'n;
					Campaign_EndDate=coalesce(Campaign_EndDate1,Campaign_EndDate2,Campaign_EndDate3);

					* Spend;
					Spend='Net eCPM'n*('Imps. Won'n/1000);
					*Spend=coalesce('Net Spend'n,SpendCalc);

					* Size;
					if Size = '0' then Size = '0x0';

					* Drop records already processed;
					if AdDate <= "&LastData_OldNum_B"d then delete;

					* Drop records on the date the data was pulled (partial date);
					*if AdDate >= "&filedate"d then delete;
					
				run;

				%if &i=1 %then %do;
					data display.display_clean_basis;
						set display.display_clean_basis_&i.;
					run; 
				%end;
				%else %do;
					data display.display_clean_basis;
						set display.display_clean_basis_&i.
							display.display_clean_basis;
					run;
				%end;

				/* -------------------------------------------------------------------------------------------------*/
				/*  Save input file --> zip archive.                                                                */
				/* -------------------------------------------------------------------------------------------------*/
				
				proc sql; select distinct count(*) into :cnt trimmed from display.display_clean_basis_&i.; quit;

				%if &cnt > 0 %then %do;
					ods package(archived) open nopf;
					ods package(archived) add file="&raw_file_path./&filename_loop..xlsx";
					ods package(archived) publish archive properties (
						archive_name="&filename_loop..zip"
						archive_path="&input_files/Archive/");
					ods package(archived) close;

					filename import "&raw_file_path./&filename_loop..xlsx";
					data _null_;
						rc=fdelete("import");
						put rc=;
					run;
					proc delete data=display.display_clean_basis_&i.; run;
					proc delete data=raw_&i.; run;
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
		%Append_Import_B;

	%check_for_data(display.display_clean_basis,=0,No records in display_clean_basis);

	%end; /* (1) */

	/* -------------------------------------------------------------------------------------------------*/
	/*  Content Syndication.                                                                            */
	/* -------------------------------------------------------------------------------------------------*/

	%put Importing %trim(&nfiles_cs.) raw CS files.;

	%if &cancel= and &nfiles_cs > 0 %then %do; /* (2) */	

	%let i = 1;

		%macro Append_Import_CS();

		%do %while (&i <= &nfiles_cs);

				%let filename_loop = %sysfunc(scan(&filename_cs,&i,'|'));
				%put &filename_loop;

				proc import 
					datafile="&raw_file_path./&filename_loop..xlsx"
					dbms=xlsx
					out=raw_&i.(where=(Company_Name ne '')) replace;
					sheet="CS Leads to Date";
					getnames=yes;
				run;

				data display.display_clean_cs_&i.; 
					format Date mmddyy10.
					       Asset_Downloaded $50.
						   Spend dollar18.2
						   Company_Name $100.
						   Company_Size $10.
						   Region $4.
						   'First Name'n $25.
						   'Last Name'n $25.
						   Address $100.
						   City $50.
						   State $25.
						   ZipCode $10.
						   Email $50.
						   Telephone $15.
						   Job_Title $75.
						   Job_Level $25.
						   Job_Function $25.
						   Industry $50.
						   'Lead Upload Date'n mmddyy10.
							Rejected $1.
							;

					keep Rejected
						 'Lead Upload Date'n
						 'First Name'n
						 'Last Name'n
						 Company_Name
						 Email
						 Telephone
						 Address
						 City
						 State
						 ZipCode
						 Job_Title
						 Job_Level
						 Job_Function
						 Industry
						 Company_Size
						 Asset_Downloaded
						 Region
						 Date
						 Spend
						 ;
						 
					set raw_&i.;

					rename
						 Rejected = RejectedStatus
						 'Lead Upload Date'n = BatchDateStatus
						 'First Name'n = FirstName
						 'Last Name'n = LastName
						 Company_Name = CompanyName
						 Email = EmailAddress
						 Telephone = PhoneNumber
						 Job_Title = JobTitle
						 Job_Level = JobLevel
						 Job_Function = JobFunction
						 Company_Size = CompanySize
						 Asset_Downloaded = DownloadName
						 ;

					* Zip Code;
					ZipCode=strip(put(Postal_Code,$10.));

					* Date;
					if datepart('Content Download Date'n)="01JAN1960"d 
						then Date='Content Download Date'n;
						else Date=datepart('Content Download Date'n);

					* Spend;
					Spend=41.67;

					* Drop records already processed;
					if Date <= "&LastData_OldNum_CS"d and Rejected = '' then delete;

					* Drop records on the date the data was pulled (partial date);
					*if Date >= "&filedate_cs"d then delete;
					
				run;

				%if &i=1 %then %do;
					data display.display_clean_cs;
						set display.display_clean_cs_&i.;
					run; 
				%end;
				%else %do;
					data display.display_clean_cs;
						set display.display_clean_cs_&i.
							display.display_clean_cs;
					run;
				%end;

				/* -------------------------------------------------------------------------------------------------*/
				/*  Save input file --> zip archive.                                                                */
				/* -------------------------------------------------------------------------------------------------*/
				
				proc sql; select distinct count(*) into :cnt trimmed from display.display_clean_cs_&i.; quit;

				%if &cnt > 0 %then %do;
					ods package(archived) open nopf;
					ods package(archived) add file="&raw_file_path./&filename_loop..xlsx";
					ods package(archived) publish archive properties (
						archive_name="&filename_loop..zip"
						archive_path="&input_files/Archive/");
					ods package(archived) close;

					filename import "&raw_file_path./&filename_loop..xlsx";
					data _null_;
						rc=fdelete("import");
						put rc=;
					run;
					proc delete data=display.display_clean_cs_&i.; run;
					proc delete data=raw_&i.; run;
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
		%Append_Import_CS;

	%check_for_data(display.display_clean_cs,=0,No records in display_clean_cs);

	%end; /* (2) */

	/* -------------------------------------------------------------------------------------------------*/
	/*  Industry Week (display).                                                                        */
	/* -------------------------------------------------------------------------------------------------*/

	%put Importing %trim(&nfiles_iw.) raw IW display files.;

	%if &cancel= and &nfiles_iw>0 %then %do; /* (3) */

	%let i = 1;

		%macro Append_Import_IW();

		%do %while (&i <= &nfiles_iw);

				%let filename_loop = %sysfunc(scan(&filename_iw,&i,'|'));
				%put &filename_loop;

				proc import 
					datafile="&raw_file_path./&filename_loop..xlsx"
					dbms=xlsx
					out=raw_&i. replace;
					sheet="Report data";
					getnames=yes;
				run;

				data display.display_clean_iw_&i.; 
					format Date mmddyy10.
						   'Line Item'n $200.
						   'Creative Size'n $20.
						   Creative $200.
						   'Total impressions'n comma10.
						   'Total clicks'n comma10.
						   Spend dollar18.2
						   eCPM dollar18.2
							;

					keep Date
						 'Line Item'n
						 eCPM
						 'Total impressions'n
						 'Total clicks'n
						 Spend
						 'Creative Size'n
						 Creative
						 ;
						 
					set raw_&i.;

					rename
						 'Line Item'n = LineItem
						 'Total impressions'n = Impressions
						 'Total clicks'n = Clicks
						 'Creative Size'n = CreativeSize
						 'Rate ($)'n = eCPM
						 ;


					* Spend;
					eCPM=input('Rate ($)'n,dollar18.2);
					Spend=eCPM*('Total impressions'n/1000);

					* Drop records already processed;
					*if Date <= "&LastData_OldNum_IW"d then delete;

					* Drop records on the date the data was pulled (partial date);
					*if Date >= "&filedate_iw"d then delete;
					
				run;

				%if &i=1 %then %do;
					data display.display_clean_iw;
						set display.display_clean_iw_&i.;
					run; 
				%end;
				%else %do;
					data display.display_clean_iw;
						set display.display_clean_iw_&i.
							display.display_clean_iw;
					run;
				%end;

				/* -------------------------------------------------------------------------------------------------*/
				/*  Save input file --> zip archive.                                                                */
				/* -------------------------------------------------------------------------------------------------*/
				
				proc sql; select distinct count(*) into :cnt trimmed from display.display_clean_iw_&i.; quit;

				%if &cnt > 0 %then %do;
					ods package(archived) open nopf;
					ods package(archived) add file="&raw_file_path./&filename_loop..xlsx";
					ods package(archived) publish archive properties (
						archive_name="&filename_loop..zip"
						archive_path="&input_files/Archive/");
					ods package(archived) close;

					filename import "&raw_file_path./&filename_loop..xlsx";
					data _null_;
						rc=fdelete("import");
						put rc=;
					run;
					proc delete data=display.display_clean_iw_&i.; run;
					proc delete data=raw_&i.; run;
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
		%Append_Import_IW;

	%check_for_data(display.display_clean_iw,=0,No records in display_clean_iw);

	%end; /* (3) */

	/* -------------------------------------------------------------------------------------------------*/
	/*  Industry Week (email newsletter).                                                               */
	/* -------------------------------------------------------------------------------------------------*/

	%put Importing &nfiles_em. raw IW email files.;
	%if &cancel= and &nfiles_em>0 %then %do; /* (4) */

		proc import 
			datafile="&raw_file_path./&filename_em..xlsx"
			dbms=xlsx
			out=display.display_clean_em replace;
			sheet="DATA";
			getnames=yes;
		run;

		/* -------------------------------------------------------------------------------------------------*/
		/*  Save input file --> zip archive.                                                                */
		/* -------------------------------------------------------------------------------------------------*/
		
		ods package(archived) open nopf;
		ods package(archived) add file="&raw_file_path./&filename_em..xlsx";
		ods package(archived) publish archive properties (
			archive_name="&filename_em..zip"
			archive_path="&input_files/Archive/");
		ods package(archived) close;

		filename import "&raw_file_path./&filename_em..xlsx";
		data _null_;
			rc=fdelete("import");
			put rc=;
		run;

		%check_for_data(display.display_clean_em,=0,No records in display_clean_em);

	%end; /* (3) */

	/* -------------------------------------------------------------------------------------------------*/
	/*  Data Axle.                                                                                      */
	/* -------------------------------------------------------------------------------------------------*/

	%put Importing &nfiles_da. raw Data Axle files.;
	%if &cancel= and &nfiles_da>0 %then %do; /* (4) */

	%let i = 1;

		%macro Append_Import_DA();

		%do %while (&i <= &nfiles_da);

				%let filename_loop = %sysfunc(scan(&filename_da,&i,'|'));
				%put &filename_loop;

				proc import 
					datafile="&raw_file_path./&filename_loop..xlsx"
					dbms=xlsx
					out=raw_&i. replace;
					getnames=yes;
				run;

				data display.display_clean_da_&i.; 
					format Start_Date mmddyy10.
						   Campaign_Name $100.
						   Strategy_Name $100.
						   Concept_Name $100.
						   Creative_Size $20.
						   Impressions comma10.
						   Clicks_Num comma10.
						   Total_Spend dollar18.2
						   Conversions_Num comma10.
							;

					keep Start_Date
/*						 End_Date*/
						 Campaign_Name
						 Strategy_Name
						 Concept_Name
						 Creative_Size
						 Impressions
						 Clicks_Num
						 Total_Spend
						 Conversions_Num
						 ;
						 
					set raw_&i.;

					rename
						 Start_Date = Date
						 Total_Spend = Spend
						 Total_Conversions = Conversions
						 ;

					* Numeric;
					Clicks_Num = coalesce(input(Clicks,8.),Clicks);
					Rename Clicks_Num = Clicks;
					Conversions_Num = coalesce(input(Total_Conversions,8.),Total_Conversions);
					Rename Conversions_Num = Conversions;

					* Drop records already processed;
					*if Date <= "&LastData_OldNum_DA"d then delete;

					* Drop records on the date the data was pulled (partial date);
					*if Date >= "&filedate_da"d then delete;
					
				run;

				%if &i=1 %then %do;
					data display.display_clean_da;
						set display.display_clean_da_&i.;
					run; 
				%end;
				%else %do;
					data display.display_clean_da;
						set display.display_clean_da_&i.
							display.display_clean_da;
					run;
				%end;

				/* -------------------------------------------------------------------------------------------------*/
				/*  Save input file --> zip archive.                                                                */
				/* -------------------------------------------------------------------------------------------------*/
				
				proc sql; select distinct count(*) into :cnt trimmed from display.display_clean_iw_&i.; quit;

				%if &cnt > 0 %then %do;
					ods package(archived) open nopf;
					ods package(archived) add file="&raw_file_path./&filename_loop..xlsx";
					ods package(archived) publish archive properties (
						archive_name="&filename_loop..zip"
						archive_path="&input_files/Archive/");
					ods package(archived) close;

					filename import "&raw_file_path./&filename_loop..xlsx";
					data _null_;
						rc=fdelete("import");
						put rc=;
					run;
					proc delete data=display.display_clean_da_&i.; run;
					proc delete data=raw_&i.; run;
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
		%Append_Import_DA;

	%check_for_data(display.display_clean_da,=0,No records in display_clean_da);

	%end; /* (4) */

/* -------------------------------------------------------------------------------------------------*/
/*                                                                                                  */
/*                                                                                                  */
/*                                         Clean Raw Data                                           */
/*                                                                                                  */
/*                                                                                                  */
/* -------------------------------------------------------------------------------------------------*/

	/* -------------------------------------------------------------------------------------------------*/
	/*  Basis.                                                                                          */
	/* -------------------------------------------------------------------------------------------------*/

	%put Cleaning %trim(&nfiles_b.) imported Basis files.;

	%check_for_data(display.display_clean_basis,=0,No records in display_clean_basis);

	%if &cancel= and &nfiles_b>0 %then %do; /* (5) */

		data display.display_clean_b2
			 zero_values;

			retain	
				AdDate
				WeekStart
				Month
				Quarter
				Campaign_StartDate
				Campaign_EndDate
				Campaign	
				Business_Size
				Theme
				Audience
				Region
				SubRegion
				Network
				PurchaseType
				PlacementType
				Creative 
				Image 
				BannerType
				Size
				Targeting
				Spend
				Impressions
				Clicks
				Utm_Source
				Utm_Medium
				Utm_Campaign
				Utm_Content
				Utm_Term
				Group
				AdLabel
				Tactic
				Do_Not_Join_to_GA_Flag;

			format  Month monyy7.
					WeekStart mmddyy10.
					Audience $50.
					Region $4.
/*					Ad_Format $40.*/
					Size $40.
					Image $20.
					Theme $25.
					Network $15.
					Campaign $100.
					PlacementType $25.
					PurchaseType $25.	
				    Targeting $20.;

			set display.display_clean_basis
				(drop=Campaign
					  LineItem
					  Brand
					  eCPM /* causes dupes */
				where=(AdDate ne . ));

			rename AdDate = Date
				   Campaign_StartDate = Start_Date
				   Campaign_EndDate = End_Date
				   Size = Ad_Format
				   AdLabel = ID_AdLabel
				   Tactic = ID_Tactic
				   Group = AdGroup;

			* Initialize;
			Do_Not_Join_to_GA_Flag = 0;

			* Month;
			WeekStart=intnx('week',AdDate,0,'b');
			Month=intnx('month',AdDate,0,'b');
			Quarter=catt('Q',qtr(AdDate));

			* Cleaning;
			if Quarter = 'Q4' and Campaign_StartDate = '' then do;
				Campaign_StartDate = "04NOV2021"d;
				Campaign_EndDate = "31DEC2021"d;
				end;

			* Business Size;
			Business_Size = 'LG';

			* Network;
			Network = 'Basis DSP';

			* BannerType;
			BannerType = 'HTML';

			* Cleaning;
			AdLabel=Tranwrd(AdLabel,'Exc','Exec');

			* PurchaseType;
			if find(AdLabel,'_Prog')>0 then PurchaseType = 'Programmatic';
			else if find(AdLabel,'_PMP')>0 then PurchaseType = 'PMP';
			else if find(Group,'PROGRAMMATIC')>0 then PurchaseType = 'Programmatic';

			* PlacementType;
			if PurchaseType = 'Programmatic' then do;
				if find(AdLabel,'native','i')>0 then PlacementType = 'Native';
				else PlacementType = 'Display';
				end;
			else if PurchaseType = 'PMP' then do;
				PlacementType_temp = strip(substr(Tactic,find(Tactic,'-')+1));
				PlacementType = strip(substr(PlacementType_temp,1,find(PlacementType_temp,'(')-1));
			end;
			drop PlacementType_temp;

			* Targeting;
			Targeting='UN';
			if PurchaseType = 'Programmatic' and Tactic ne '' then do;
				Targeting = strip(substr(scan(Tactic,5,'_'),1,find(scan(Tactic,5,'_'),'+')-1));
			end;
			if Targeting = 'CSL' then Targeting = 'Client Site List';
			if find(Tactic,'RTG','i')>0 then Targeting = 'Retargeting';
			if find(Tactic,'Persona')>0 then Targeting = 'Persona';
			if Targeting = '' then Targeting = 'UN';
			drop PlacementType_temp;

			* Ad_Format;
			if Size = '0x0' then Size = '1200x627';

			* Cleaning;
			Group = tranwrd(Group,' | ','_');
			Group = tranwrd(Group,'PMP Display','PMP');
			if Group = '' then Group = catx('_','ID_KAIS',upcase(PurchaseType),Quarter,year(AdDate));

			* Region / SubRegion;
			Region = upcase(scan(Group,5,'_'));
				* Other options: HWAI, MAS, UN;
			SubRegion = 'NON';
				*Other options: MRLD, VRGA, DC, ORE, WAS;

			* Audience;
			if find(AdLabel,'exec','i')>0 then Audience = 'Executives';
				else if find(AdLabel,'hr','i')>0 then Audience = 'HR';

			* Theme;
			if find(AdLabel,'RTW_')>0 then do; 
					Theme = 'Return to Work';
					Theme_temp = 'RTW';
					end;
				else if find(AdLabel,'VC_')>0 then do;
					Theme = 'Virtual Care';
					Theme_temp = 'VC';
					end;
				else if find(AdLabel,'MHW_')>0 then do;
					Theme = 'Mental Health & Wellness';
					Theme_temp = 'MHW';
					end;

			* Creative & Image;
			if find(AdLabel,'ID_KAIS')>0 then Creative_temp=scan(AdLabel,4,'_');
				else if find(AdLabel,'A2')>0 or find(AdLabel,'B2')>0 then Creative_temp=scan(AdLabel,4,'-');
				else if find(AdLabel,'KAIS101-')>0 then Creative_temp=scan(tranwrd(AdLabel,'--','-'),3,'-');
				if Creative_temp='Native' then Creative_temp=scan(tranwrd(AdLabel,'--','-'),4,'-');
				if Creative_temp in ('EXEC','HR') then Creative_temp=scan(AdLabel,5,'_');
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
					if Creative_temp in ('HR1') then do; 
						Creative = 'Statistic';
						Image = 'Woman1';
					end;
					else do;
						Creative = 'Trends';
						Image = 'Man1';
					end;
				end;
				else do;
					if Creative_temp in ('Exec1') then do;
						Creative = 'Statistic';
						Image = 'Woman2';
					end;
					else do;
						Creative = 'Trends';
						Image = 'Man2';
					end;
				end;
			end;
			else if Theme = 'Mental Health & Wellness' then do;
				if Audience = 'HR' then do;
					if Creative_temp in ('HR_A','HR1') then do;
						Creative = 'Absenteeism';
						Image = 'Earrings';
					end;
					else if upcase(Creative_temp) = 'PRIORITY' then do; *Animated;
						Creative = 'Priority';
						Image = 'GreySweater';
						Size = catx('-',Size,'Animated');
					end;
					else do;
						Creative = 'Productivity';
						Image = 'Stretch';
					end;
				end;
				else do;
					if Creative_temp = 'BANDWAGON' then do;
						Creative = 'Bandwagon';
						Image = 'Tree';
					end;
					else if Creative_temp = 'DEPRESSION' then do;
						Creative = 'Depression';
						Image = 'Blanket'; 
					end;
					else if Creative_temp = 'BANDWAGON2' then do; *Added 1/13 for new images;
						Creative = 'Bandwagon2';
						Image = 'Headphones'; 
					end;
					else if Creative_temp = 'DEPRESSION2' then do; *Added 1/13 for new images;
						Creative = 'Depression2';
						Image = 'Studio'; 
					end;
					else if upcase(Creative_temp) = 'UNTREATED' then do; *Animated;
						Creative = 'Untreated';
						Image = 'BlueShirt';
						Size = catx('-',Size,'Animated');
					end;

				end;
			end;	

			* UTMs;
			UTM_Source = lowcase(catx('-',Business_Size,Region,'Prospect'));
			UTM_Medium = 'display';
			UTM_Campaign = lowcase(catx('|',Theme_temp,substr(Audience,1,4),Creative));
				if Theme = 'Return to Work' then UTM_Campaign = lowcase(catx('|',Theme_temp,substr(Audience,1,4)));
			if Audience = 'Executives' then UTM_Content = '245974';
				else if Audience = 'HR' then UTM_Content = '245973';
			if PlacementType = 'Native' then UTM_Term = lowcase(catx('|','basisdsp',PlacementType));
				else if PlacementType = 'Display' then UTM_Term = lowcase(catx('|','basisdsp',PlacementType,Size));
				else if PurchaseType = 'PMP' then UTM_Term = lowcase(catx('|','basisdsp',PurchaseType,Size));
			if find(Size,'animated','i')>0 then UTM_Term = lowcase(catx('|','basisdsp','animated',tranwrd(Size,'-Animated','')));
			drop Theme_temp;
	
			* Campaign;
			Campaign = catx('_',catt('Display-',substr(upcase(PurchaseType),1,4)),Business_size,Compress(Theme),Audience);
				
			* Remove empty rows;
			if (Spend > 0 or Impressions > 0) then output display.display_clean_b2;
				else output zero_values;

		run;
		proc freq data=display.display_clean_b2;
			tables date campaign Business_Size theme Audience
					region*SubRegion Network PurchaseType
					PlacementType Creative Image
					BannerType Ad_Format Targeting
					Utm_Source*region Utm_Medium
					Utm_Campaign utm_content*Audience
					Utm_Term
					AdGroup ID_AdLabel ID_Tactic
					Creative*Creative_temp
					/ nocol norow nopercent;
		run;

		%check_for_data(display.display_clean_b2,=0,No records in display_clean_b2);

		* Basis data includes dupes;
		proc sql;
		create table display.display_clean_b_final as
		select distinct
			Date, WeekStart, Month, Quarter
		,	Start_Date, End_Date, Campaign, Business_Size, Theme
		,	Audience, Region, SubRegion, Network, PurchaseType, PlacementType
		,	Image, Creative, BannerType, Ad_Format, Targeting
		,	sum(Spend) as Spend format dollar18.2
		,	sum(Impressions) as Impressions format comma12.
		,	sum(Clicks) as Clicks format comma12.
		,	UTM_Source, UTM_Medium, UTM_Campaign, UTM_Content, UTM_Term
		,	AdGroup, ID_AdLabel, ID_Tactic
		,	Do_Not_Join_to_GA_Flag
		from display.display_clean_b2
		group by 
			Date, WeekStart, Month, Quarter
		,	Start_Date, End_Date, Campaign, Business_Size, Theme
		,	Audience, Region, SubRegion, Network, PurchaseType, PlacementType
		,	Image, Creative, BannerType, Ad_Format, Targeting
		,	UTM_Source, UTM_Medium, UTM_Campaign, UTM_Content, UTM_Term
		,	AdGroup, ID_AdLabel, ID_Tactic
		,	Do_Not_Join_to_GA_Flag;
		quit;
			
		proc sql ;
			select distinct count(*)
			into :Nmiss_b
			from zero_values;

			select distinct count(*)
			into :N_b
			from display.display_clean_b_final;
		quit;

		proc sql noprint;
			create table check_dups as
			select 
				t1.* , t2.ndups
			from display.display_clean_b_final t1
				, (select 
						date, Targeting, PlacementType, utm_source, utm_medium, utm_campaign, utm_content, utm_term, count(*) as ndups
				   from display.display_clean_b_final
				   where Do_Not_Join_to_GA_Flag = 0 /* IMPORTANT */
				   group by date, Targeting, PlacementType, utm_source, utm_medium, utm_campaign, utm_content, utm_term
				   ) t2
			where t2.ndups>1 
				and t1.date=t2.date 
				and t1.Targeting=t2.Targeting /* Not included in tagging */
				and t1.PlacementType=t2.PlacementType /* Not included in tagging */
				and t1.utm_source=t2.utm_source 
				and t1.utm_medium=t2.utm_medium
				and t1.utm_campaign=t2.utm_campaign 
				and t1.utm_content=t2.utm_content 
				and t1.utm_term=t2.utm_term
				and t1.Do_Not_Join_to_GA_Flag = 0 /* IMPORTANT */
			order by t1.date, t1.Targeting, t1.PlacementType, t1.utm_source, t1.utm_medium, t1.utm_campaign, t1.utm_content, t1.utm_term;
		quit;	

		%check_for_data(check_dups,>0,Dupes in display_clean_iw2);

	%end; /* (5) */

	%if &cancel= and &nfiles_b>0 and %sysfunc(exist(display.Display_Clean_Combined_final))
		%then %do; 
			%let combined_file=display.display_clean_combined_final;
			%put Appending to Display_Clean_Combined_final.;
		%end;
	%if &cancel= and &nfiles_b>0 and %sysfunc(exist(display.Display_Clean_Combined_final))=0 %then %do;
		%put Creating Display_Clean_Combined_final;
	%end;

	%if &cancel= and &nfiles_b>0 %then %do; /* (6) */

		data display.Display_Clean_Combined_final;

			retain 	
				Date 		WeekStart 		Month 			Quarter 	Start_Date 	End_Date
				Campaign	Business_Size	Theme			Audience	Region		SubRegion
				Network		PurchaseType	PlacementType	Creative 	Image 		BannerType
				Ad_Format	Targeting
				Spend		Impressions		Clicks			Conversions Downloads
				Utm_Source	Utm_Medium		Utm_Campaign	Utm_Content	Utm_Term
				AdGroup		Id_AdLabel		ID_Tactic		ID_Creative	DA_AdLabel
				Do_Not_Join_to_GA_Flag;

			format Network $15.
				   PurchaseType $25.
				   Ad_Format $40.
				   Image $20.
				   Targeting $20.
				   Campaign $100.
				   ID_Creative $100.
				   DA_AdLabel $200.;

			set &combined_file.
				display.display_clean_b_final
				;
	
			keep 	
				Date 		WeekStart 		Month 			Quarter 	Start_Date 	End_Date
				Campaign	Business_Size	Theme			Audience	Region		SubRegion
				Network		PurchaseType	PlacementType	Creative 	Image 		BannerType
				Ad_Format	Targeting
				Spend		Impressions		Clicks			Downloads
				Utm_Source	Utm_Medium		Utm_Campaign	Utm_Content	Utm_Term
				AdGroup		Id_AdLabel		ID_Tactic		ID_Creative	DA_AdLabel
				Do_Not_Join_to_GA_Flag;

		run;

	%end; /* (6) */

	/* -------------------------------------------------------------------------------------------------*/
	/*  Intenstify Content Syndication.                                                                 */
	/* -------------------------------------------------------------------------------------------------*/

	%put Cleaning %trim(&nfiles_cs.) imported CS files.;

	%if &cancel= and &nfiles_cs>0 %then %do; /* (7) */

		%check_for_data(display.display_clean_cs,=0,No records in display_clean_cs);

		proc sql; select distinct max(BatchDateStatus) format date9. into :max_date from display.display_clean_cs; quit;

		data display.display_clean_cs2;

			retain	
				Date
				WeekStart
				Month
				Quarter
/*				Campaign_StartDate */
/*				Campaign_EndDate*/
				Campaign	
				Business_Size
				Theme
				Audience
				Region
				SubRegion
				Network
				PurchaseType
				PlacementType
				Creative 
				Image 
				BannerType
				Ad_Format
				Targeting
				Spend
				Downloads
				Utm_Source
				Utm_Medium
				Utm_Campaign
				Utm_Content
				Utm_Term
				CompanyName
				CompanySize
				FirstName
				LastName
				Address
				City
				State
				ZipCode
				EmailAddress
				PhoneNumber
				JobTitle
				JobLevel
				Industry
				BatchDateStatus
				RejectedStatus
				Do_Not_Join_to_GA_Flag;

			format  Month monyy7.
					WeekStart mmddyy10.
					Start_Date mmddyy10.
					End_Date mmddyy10.
					Audience $50.
					Region $4.
					Ad_Format $12.
					Image $20.
					Theme $25.
					Network $15.
					Campaign $100.
					PlacementType $25.
					PurchaseType $25.	
				    Targeting $20.;

			set display.display_clean_cs
				(drop=Region /* based on state not zip */
				where=(Date ne . ));

			* Initialize;
			Do_Not_Join_to_GA_Flag = 1;
			Downloads = 1;

			* Month;
			WeekStart=intnx('week',Date,0,'b');
			Month=intnx('month',Date,0,'b');
			Quarter=catt('Q',qtr(Date));

			* Business Size;
			Business_Size = 'LG';

			* Network;
			Network = 'Intentsify';

			* BannerType;
			BannerType = 'N/A';

			* PurchaseType;
			PurchaseType = 'Content Syndication';

			* PlacementType;
			PlacementType = 'Content';

			* Targeting;
			Targeting='UN';

			* Ad_Format; 
			Ad_Format = 'Content';

			* Audience;
			if find(scan(DownloadName,2,'-'),'HR')>0 then Audience = 'HR';
				else if find(scan(DownloadName,2,'-'),'Exec')>0 then Audience = 'Executives';
	
			* Theme;
			Theme_Temp = strip(scan(DownloadName,1,'-'));
				if Theme_temp = 'Create a safe, flexible workplace' then Theme = 'Return to Work';
				else Theme = Theme_temp;
			if Theme = 'Return to Work' then Theme_temp = 'RTW';
				else if Theme = 'Virtual Care' then Theme_temp = 'VC';
				else if Theme = 'Mental Health & Wellness' then Theme_temp = 'MHW';

			* Start/End Campaign Dates;
			if Theme = 'Return to Work' then do;
				Start_Date="25NOV2021"d;
				End_Date="20DEC2021"d; 
				end;
			else do;
				Start_Date="24JAN2022"d;
				End_Date="31MAR2022"d; 
				end;

			* Creative & Image;
			if Theme = 'Return to Work' then do;
				Creative = 'Return to Work';
				if Audience = 'HR' then Image = 'Apple';
				else Image = 'Hallway';
				end;
			else if Theme = 'Virtual Care' then do;
				Creative = 'Trends';
				if Audience = 'HR' then Image = 'Woman2';
					else Image = 'Man2';
				end;
			else if Theme = 'Mental Health & Wellness' then do;
				Creative = 'PublicHealth';
				if Audience = 'HR' then Image = 'Earrings';
					else do;
					Image = 'Headphones'; 
					Start_Date="03FEB2022"d; /* Update */
					end;
				end;

			* UTMs;
			UTM_Source = '';
			UTM_Medium = '';
			UTM_Campaign = '';
			UTM_Content = '';
			UTM_Term = '';
	
			* Campaign;
			Campaign = catx('_',catt('Display-','CS'),Business_size,Compress(Theme),Audience);
				
			* Region / SubRegion;
			* Use ZipCode to fix "State" and get "Region";
			ZipCode=substr(strip(ZipCode),1,5);
			Region='UN';
			SubRegion='NON';

			* Cleaning BatchDateStatus;
			if BatchDateStatus = . then BatchDateStatus = "&max_date"d;
			if BatchDateStatus > today() then BatchDateStatus = "&max_date"d;

			* Cleaning;
			PhoneNumber=compress(PhoneNumber,'kd');
			if JobLevel='Yes' then do;
				JobLevel=CompanySize;
				CompanySize=JobFunction;
				JobTitle_temp=CompanyName;
				CompanyName=JobTitle;
					JobTitle=JobTitle_temp;
				end;
			drop JobTitle_temp
			 	 JobFunction;
		run;

		proc freq data=display.display_clean_cs2;
			tables date weekstart month quarter 
					campaign Business_Size Theme
					audience region SubRegion Network
					PurchaseType PlacementType
					Creative
					image BannerType Ad_Format
					Targeting
					industry
					batchdatestatus
					joblevel
					companysize region state RejectedStatus;
				run;

		%include '/gpfsFS2/home/c156934/password.sas';
		libname mars sqlsvr DSN='SQLSVR4685' SCHEMA='dbo' user="CS\C156934" password="&winpwd"
		     qualifier='MARS' readbuff=5000 insertbuff=5000 dbcommit=1000; run;

		data kp_zips;
			set mars.zip_level_info 
					(keep= yr_nbr zip_cd st_cd regn_cd sub_regn_cd svc_area_nm 
				 	small_busn_mkt_ind large_busn_mkt_ind rec_updt_dt
					where=((small_busn_mkt_ind='Y' or large_busn_mkt_ind='Y') and yr_nbr=2021));
		run;
		proc sql; /* KPWA not in this table */
		create table kp_zips2 as
		select distinct
			Zip_cd as ZipCode
		,	St_Cd 
		,	case when sub_regn_cd = 'CASC' then 'SCAL'
				 when sub_regn_cd = 'CANC' then 'NCAL'
				 when Regn_cd = 'CO' then 'CLRD'
				 when Regn_cd = 'GA' then 'GRGA'
				 When Regn_cd = 'HI' then 'HWAI'
				 when Regn_cd = 'MR' then 'MAS'
				 when Regn_cd = 'NW' then 'PCNW'
				 end as Regn_cd
		,	case when sub_regn_cd = 'NWWA' then 'WAS'
				 when sub_regn_cd = 'NWOR' then 'OR'
				 when sub_regn_cd = 'MRDC' then 'DC'
				 when sub_regn_cd = 'MRMD' then 'MD'
				 when sub_regn_cd = 'MRVA' then 'VA'
				 end as Sub_Regn_Cd
		from kp_zips
		order by Zip_Cd;
		quit;

		* Use ZipCode to fix "State" and get "Region";
		proc sort data=display.display_clean_cs2; by ZipCode; run;
		data display.display_clean_cs_final;
			merge display.display_clean_cs2(in=a)
				  kp_zips2(in=b);
			by ZipCode;

			if a;

			if b then do;
					State = St_Cd;
					Region = Regn_Cd;
					*SubRegion = 'NON';
				end;
			else do;
				if State = 'Colorado' then do;
					State = 'CO';
					Region = 'CLRD';
					end;
				else if State = 'Georgia' then do;
					State = 'GA';
					Region = 'GRGA';
					end;
				else if State = 'Northern California' then do;
					State = 'CA';
					Region = 'NCAL';
					end;
				else if State = 'Southern California' then do;
					State = 'CA';
					Region = 'SCAL';
					end;
				else if State = 'Oregon' then do;
					State = 'OR';
					Region = 'PCNW';
					end;
				else if State = 'Washington' then do;
					State = 'WA';
					Region = 'KPWA';
					end;
			end;

		run;
		proc freq data=display.display_clean_cs_final;
			tables region SubRegion state;
		run;

		%check_for_data(display.display_clean_cs_final,=0,No records in display_clean_cs_final);
	
		proc sql ;
			select distinct count(*)
			into :N_cs
			from display.display_clean_cs_final;
		quit;

		proc sql noprint;
			create table check_dups as
			select 
				t1.* , t2.ndups
			from display.display_clean_cs_final t1
				, (select 
						date, Campaign, CompanyName, EmailAddress, count(*) as ndups
				   from display.display_clean_cs_final
				   group by date, Campaign, CompanyName, EmailAddress
				   ) t2
			where t2.ndups>1 
				and t1.date=t2.date 
				and t1.Campaign=t2.Campaign 
				and t1.CompanyName=t2.CompanyName 
				and t1.EmailAddress=t2.EmailAddress
			order by t1.date, t1.Campaign, t1.CompanyName, t1.EmailAddress;
		quit;	

		/* Since ID is charging from this list there should NOT be dupes!
		proc sql; create table display.display_clean_cs_final as
		select distinct * from display.display_clean_cs_final;
		quit; 
		*/

		%check_for_data(check_dups,>0,Dupes in display_clean_cs_final);

		* Lead info in separate table;
		data display.Content_Syndication_Master_Temp;
			retain 
				BatchDateStatus
				Rec_Updt_Dt
				RejectedStatus
				Date
				Audience
				Theme
				CompanyName
				FirstName
				LastName
				Address
				City
				State
				ZipCode
				EmailAddress
				PhoneNumber
				JobTitle
				JobLevel
				Industry
				CompanySize;
			format Rec_Updt_Dt datetime18.;
			set display.display_clean_cs_final;
			keep
				BatchDateStatus
				Rec_Updt_Dt
				Date
				RejectedStatus
				Audience
				Theme
				CompanyName
				FirstName
				LastName
				Address
				City
				State
				ZipCode
				EmailAddress
				PhoneNumber
				JobTitle
				JobLevel
				Industry
				CompanySize;

				Rec_Updt_Dt = datetime();

			run;

	%end; /* (7) */

	%if &cancel= and &nfiles_cs>0 and %sysfunc(exist(display.Display_Clean_Combined_final))
		%then %do; 
			%let combined_file=display.display_clean_combined_final;
			%put Appending to Display_Clean_Combined_final.;
	%end;
	%if &cancel= and &nfiles_cs>0 and %sysfunc(exist(display.Display_Clean_Combined_final))=0 %then %do;
			%put Creating Display_Clean_Combined_final;
	%end;

	%if &cancel= and &nfiles_cs>0 %then %do; /* (8) */

		data display.Display_Clean_Combined_final;

			retain 	
				Date 		WeekStart 		Month 			Quarter 	Start_Date 	End_Date
				Campaign	Business_Size	Theme			Audience	Region		SubRegion
				Network		PurchaseType	PlacementType	Creative 	Image 		BannerType
				Ad_Format	Targeting
				Spend		Impressions		Clicks			Conversions Downloads
				Utm_Source	Utm_Medium		Utm_Campaign	Utm_Content	Utm_Term
				AdGroup		Id_AdLabel		ID_Tactic		ID_Creative	DA_AdLabel
				Do_Not_Join_to_GA_Flag;

			format Network $15.
				   PurchaseType $25.
				   Image $20.
				   Ad_Format $40.
				   Targeting $20.
				   Campaign $100.
				   ID_Creative $100.
				   DA_AdLabel $200.;

			set &combined_file.
				display.display_clean_cs_final(where=(RejectedStatus=''))
				;
	
			keep 	
				Date 		WeekStart 		Month 			Quarter 	Start_Date 	End_Date
				Campaign	Business_Size	Theme			Audience	Region		SubRegion
				Network		PurchaseType	PlacementType	Creative 	Image 		BannerType
				Ad_Format	Targeting
				Spend		Impressions		Clicks			Downloads
				Utm_Source	Utm_Medium		Utm_Campaign	Utm_Content	Utm_Term
				AdGroup		Id_AdLabel		ID_Tactic		ID_Creative	DA_AdLabel
				Do_Not_Join_to_GA_Flag;

		run;

	%end; /* (8) */

	/* -------------------------------------------------------------------------------------------------*/
	/*  Industry Week (Display & Native).                                                               */
	/* -------------------------------------------------------------------------------------------------*/

	%put Cleaning %trim(&nfiles_iw.) imported IW files.;

	%if &cancel= and &nfiles_iw>0 %then %do; /* (9) */

		%check_for_data(display.display_clean_iw,=0,No records in display_clean_iw);

		data display.display_clean_iw2
			 zero_values;

			retain	
				Date
				WeekStart
				Month
				Quarter
				Start_Date
				End_Date
				Campaign	
				Business_Size
				Theme
				Audience
				Region
				SubRegion
				Network
				PurchaseType
				PlacementType
				Creative 
				Image 
				BannerType
				Ad_Format
				Targeting
				Spend
				Impressions
				Clicks
				Utm_Source
				Utm_Medium
				Utm_Campaign
				Utm_Content
				Utm_Term
				AdGroup
				LineItem
				ID_Creative
				Do_Not_Join_to_GA_Flag;

			format  Month monyy7.
					WeekStart mmddyy10.
					Start_Date mmddyy10.
					End_Date mmddyy10.
					Audience $50.
					Region $4.
					Ad_Format $12.
					Image $20.
					Theme $25.
					Network $15.
					Campaign $100.
					PlacementType $25.
					PurchaseType $25.	
				    Targeting $20.;

			set display.display_clean_iw
				(drop=eCPM /* causes dupes */
				rename=(Creative=ID_Creative)
				where=(Date ne . ));

			rename LineItem = ID_AdLabel;

			* Initialize;
			Do_Not_Join_to_GA_Flag = 0;

			* Month;
			WeekStart=intnx('week',Date,0,'b');
			Month=intnx('month',Date,0,'b');
			Quarter=catt('Q',qtr(Date));

			* Hard-code missing data from data refresh;
			Start_Date = "06NOV2021"d;
			End_Date = "31DEC2021"d;
			AdGroup = '2021 IndustryWeek';

			* Business Size;
			Business_Size = 'LG';

			* Network;
			Network = 'IndustryWeek';

			* BannerType;
			BannerType = 'HTML';

			* PurchaseType;
			PurchaseType = 'Direct Buy';

			* PlacementType;
			PlacementType = 'Display';

			* Targeting;
			Targeting = 'UN';

			* Audience;
			Audience = 'Executives';

			* Ad_Format; 
			Ad_Format = compress(CreativeSize);
				drop CreativeSize;

			* Region / SubRegion;
			if find(ID_Creative,'NCAL')>0 then Region = 'NCAL';
				else if find(ID_Creative,'SCAL')>0 then Region = 'SCAL';
				else if find(ID_Creative,'KPWA')>0 then Region = 'KPWA';
				else if find(ID_Creative,'PCNW')>0 then Region = 'PCNW';
				else if find(ID_Creative,'GRGA')>0 then Region = 'GRGA';
				else if find(ID_Creative,'CLRD')>0 then Region = 'CLRD';
				else if find(LineItem,'_CO')>0 then Region = 'CLRD';
				else if find(LineItem,'_NoCA')>0 then Region = 'NCAL';
				else if find(LineItem,'_SoCA')>0 then Region = 'SCAL';
				else if find(LineItem,'_GA')>0 then Region = 'GRGA';
				else Region = 'SCAL'; * After digging through data, learned it's SCAL;
				* Other options: HWAI, MAS, UN;
			SubRegion = 'NON';
				*Other options: MRLD, VRGA, DC, ORE, WAS;
				
			* Theme;
			if find(ID_Creative,'_RTW_')>0 then do;
				Theme = 'Return to Work';
				Theme_temp = 'RTW';
				end;
			else if find(ID_Creative,'_VC_')>0 then do;
				Theme = 'Virtual Care';
				Theme_temp = 'VC';
				end;
			else if find(ID_Creative,'MHW_')>0 then do;
				Theme = 'Mental Health & Wellness'; 
				Theme_temp = 'MHW';
				end;
	
			* Creative & Image;
			ID_Creative = tranwrd(ID_Creative,'Bandwagaon','Bandwagon');
			if Theme = 'Return to Work' then do;
				Creative = 'Return to Work';
				Image = 'Hallway';
				end;
			else if Theme = 'Virtual Care' then do;
				if find(ID_Creative,'_Trends_')>0 then do;
					Creative = 'Trends';
					Image = 'Man2';
					end;
				else do;
					Creative = 'Statistic';
					Image = 'Woman2';
					end;
				end;
			else if Theme = 'Mental Health & Wellness' then do;
				if find(ID_Creative,'_Bandwagon_')>0 then do;
					Creative = 'Bandwagon';
					Image = 'Tree';
					end;
				else do;
					Creative = 'Depression';
					Image = 'Blanket'; 
					end;
				end;

			* UTMs;
			UTM_Source = lowcase(catx('-',Business_Size,Region,'Prospect'));
			UTM_Medium = 'display';
			UTM_Campaign = lowcase(catx('|',Theme_temp,substr(Audience,1,4),Creative));
				if Theme = 'Return to Work' then UTM_Campaign = lowcase(catx('|',Theme_temp,substr(Audience,1,4)));
			if Audience = 'Executives' then UTM_Content = '245974';
				else if Audience = 'HR' then UTM_Content = '245973';
			UTM_Term = lowcase(catx('|','industryw',scan(PurchaseType,1,' '),Ad_Format));
			drop Theme_temp;
	
			* Campaign;
			Campaign = catx('_',catt('Display-',substr(upcase(PurchaseType),1,6)),Business_size,Compress(Theme),Audience);
				
			* Remove empty rows;
			if (Spend > 0 or Impressions > 0) then output display.display_clean_iw2;
				else output zero_values;

		run;

		%check_for_data(display.display_clean_iw2,=0,No records in display_clean_iw2);

		* No dupes in IW raw;
		proc sql;
		create table display.display_clean_iw_final as
		select distinct
			Date, WeekStart, Month, Quarter
		,	Start_Date, End_Date, Campaign, Business_Size, Theme
		,	Audience, Region, SubRegion, Network, PurchaseType, PlacementType
		,	Image, Creative, BannerType, Ad_Format, Targeting
		,	sum(Spend) as Spend format dollar18.2
		,	sum(Impressions) as Impressions format comma12.
		,	sum(Clicks) as Clicks format comma12.
		,	UTM_Source, UTM_Medium, UTM_Campaign, UTM_Content, UTM_Term
		,	AdGroup, ID_AdLabel, ID_Creative
		,	Do_Not_Join_to_GA_Flag
		from display.display_clean_iw2
		group by 
			Date, WeekStart, Month, Quarter
		,	Start_Date, End_Date, Campaign, Business_Size, Theme
		,	Audience, Region, SubRegion, Network, PurchaseType, PlacementType
		,	Image, Creative, BannerType, Ad_Format, Targeting
		,	UTM_Source, UTM_Medium, UTM_Campaign, UTM_Content, UTM_Term
		,	AdGroup, ID_AdLabel, ID_Creative
		,	Do_Not_Join_to_GA_Flag;
		quit;
	
		proc sql ;
			select distinct count(*)
			into :Nmiss_iw
			from zero_values;

			select distinct count(*)
			into :N_iw
			from display.display_clean_iw_final;
		quit;

		proc sql noprint;
			create table check_dups as
			select 
				t1.* , t2.ndups
			from display.display_clean_iw_final t1
				, (select 
						date, Targeting, PlacementType, utm_source, utm_medium, utm_campaign, utm_content, utm_term, count(*) as ndups
				   from display.display_clean_iw_final
				   where Do_Not_Join_to_GA_Flag = 0 /* IMPORTANT */
				   group by date, Targeting, PlacementType, utm_source, utm_medium, utm_campaign, utm_content, utm_term
				   ) t2
			where t2.ndups>1 
				and t1.date=t2.date 
				and t1.Targeting=t2.Targeting /* Not included in tagging */
				and t1.PlacementType=t2.PlacementType /* Not included in tagging */
				and t1.utm_source=t2.utm_source 
				and t1.utm_medium=t2.utm_medium
				and t1.utm_campaign=t2.utm_campaign 
				and t1.utm_content=t2.utm_content 
				and t1.utm_term=t2.utm_term
				and t1.Do_Not_Join_to_GA_Flag = 0 /* IMPORTANT */
			order by t1.date, t1.Targeting, t1.PlacementType, t1.utm_source, t1.utm_medium, t1.utm_campaign, t1.utm_content, t1.utm_term;
		quit;	

		%check_for_data(check_dups,>0,Dupes in display_clean_iw_final);

	%end; /* (9) */

	%if &cancel= and &nfiles_iw>0 and %sysfunc(exist(display.Display_Clean_Combined_final))
		%then %do; 
			%let combined_file=display.display_clean_combined_final;
			%put Appending to Display_Clean_Combined_final.;
		%end;
	%if &cancel= and &nfiles_iw>0 and %sysfunc(exist(display.Display_Clean_Combined_final))=0 %then %do;
		%put Creating Display_Clean_Combined_final;
	%end;

	%if &cancel= and &nfiles_iw>0 %then %do; /* (10) */

		data display.Display_Clean_Combined_final;

			retain 	
				Date 		WeekStart 		Month 			Quarter 	Start_Date 	End_Date
				Campaign	Business_Size	Theme			Audience	Region		SubRegion
				Network		PurchaseType	PlacementType	Creative 	Image 		BannerType
				Ad_Format	Targeting
				Spend		Impressions		Clicks			Conversions Downloads
				Utm_Source	Utm_Medium		Utm_Campaign	Utm_Content	Utm_Term
				AdGroup		Id_AdLabel		ID_Tactic		ID_Creative	DA_AdLabel
				Do_Not_Join_to_GA_Flag;

			format Network $15.
				   PurchaseType $25.
				   Image $20.
				   Ad_Format $40.
				   Targeting $20.
				   Campaign $100.
				   ID_Creative $100.
				   DA_AdLabel $200.;

			set &combined_file.
				display.display_clean_iw_final
				;
	
			keep 	
				Date 		WeekStart 		Month 			Quarter 	Start_Date 	End_Date
				Campaign	Business_Size	Theme			Audience	Region		SubRegion
				Network		PurchaseType	PlacementType	Creative 	Image 		BannerType
				Ad_Format	Targeting
				Spend		Impressions		Clicks			Downloads
				Utm_Source	Utm_Medium		Utm_Campaign	Utm_Content	Utm_Term
				AdGroup		Id_AdLabel		ID_Tactic		ID_Creative	DA_AdLabel
				Do_Not_Join_to_GA_Flag;

		run;

	%end; /* (10) */

	/* -------------------------------------------------------------------------------------------------*/
	/*  Data Axle.                                                                                      */
	/* -------------------------------------------------------------------------------------------------*/

	%put Cleaning &nfiles_da. imported Data Axle files.;

	%if &cancel= and &nfiles_da>0 %then %do; /* (11) */

		%check_for_data(display.display_clean_da,=0,No records in display_clean_da);

		data display.display_clean_da2
			 zero_values;

			retain	
				Date
				WeekStart
				Month
				Quarter
				Campaign	
				Business_Size
				Theme
				Audience
				Region
				SubRegion
				Network
				PurchaseType
				PlacementType
				Creative 
				Image 
				BannerType
				Ad_Format
				Targeting
				Spend
				Impressions
				Clicks
				Conversions
				Utm_Source
				Utm_Medium
				Utm_Campaign
				Utm_Content
				Utm_Term
				Campaign_Name
				Concept_Name
				Do_Not_Join_to_GA_Flag;

			format  Month monyy7.
					WeekStart mmddyy10.
					Audience $50.
					Region $4.
					Ad_Format $12.
					Image $20.
					Theme $25.
					Network $15.
					Campaign $100.
					PlacementType $25.
					PurchaseType $25.	
				    Targeting $20.;

			set display.display_clean_da;

			rename AdDate = Date
				   Campaign_Name = AdGroup
				   Concept_Name = DA_AdLabel;

			* Initialize;
			Do_Not_Join_to_GA_Flag = 0;

			* Month;
			WeekStart=intnx('week',Date,0,'b');
			Month=intnx('month',Date,0,'b');
			Quarter=catt('Q',qtr(Date));

			* Business Size;
			Business_Size = 'SB';

			* Network;
			Network = 'MediaMath';

			* BannerType;
			BannerType = 'HTML';

			* PurchaseType;
			PurchaseType = 'Programmatic';

			* PlacementType;
			PlacementType = 'Display';

			* Targeting;
			if find(Strategy_Name,'Adaptive Segment')>0 then Targeting='Retargeting';
				else if find(Strategy_Name,'DM Universe')>0 then Targeting='Custom List';
			drop Strategy_Name;

			* Audience;
			Audience = 'SBCA Direct Mail Universe';

			* Ad_Format; 
			if find(Creative_Size,'0006')>0 then Ad_Format = scan(Creative_Size,2,'_');
				else Ad_Format = Creative_Size;
			drop Creative_Size;

			* Region / SubRegion;
			Region = 'CACA'; * They did not break it down by NCAL/SCAL;
			SubRegion = 'NON';
				
			* Theme;
			Theme = 'SB Health Plans';
	
			* Creative & Image;
			format Test $5.;
			if find(Concept_Name,'Concept1')>0 then do;
				Creative = 'CTA Learn More';
				Image = 'Woman Sewing';
				Test='';
				end;
			if find(Concept_Name,'Concept2')>0 then do;
				Creative = 'CTA Learn More';
				Image = 'Men at a Coffee Shop';
				Test='';
				end;
			if find(Concept_Name,'Concept 3_Get Quote')>0 then do;
				Creative = 'CTA Get Quote';
				Image = 'Woman Sewing';
				Test='test|';
				end;
			if find(Concept_Name,'Concept 4_Get Quote')>0 then do;
				Creative = 'CTA Get Quote';
				Image = 'Men at a Coffee Shop';
				Test='test|';
				end;

			* UTMs;
			UTM_Source = lowcase(catx('-',Business_Size,'ca','prospect'));
			UTM_Medium = 'display';
			UTM_Campaign = 'sbca-dataaxle';
			UTM_Content = '246390';
			UTM_Term = lowcase(catt(Test,catx('|',tranwrd(strip(Image),' ','-'),Ad_Format)));
				UTM_Term = tranwrd(UTM_Term,'--------','');
			drop Test;
	
			* Campaign;
			Campaign = catx('_','Display',Business_size,Compress(Theme),compress(Audience));
				
			* Remove empty rows;
			if (Spend > 0 or Impressions > 0) then output display.display_clean_da2;
				else output zero_values;

		run;

		%check_for_data(display.display_clean_da2,=0,No records in display_clean_da2);

		proc sql;
		create table display.display_clean_da_final as
		select distinct
			Date, WeekStart, Month, Quarter
		,	Campaign, Business_Size, Theme
		,	Audience, Region, SubRegion, Network, PurchaseType, PlacementType
		,	Image, Creative, BannerType, Ad_Format, Targeting
		,	sum(Spend) as Spend format dollar18.2
		,	sum(Impressions) as Impressions format comma12.
		,	sum(Clicks) as Clicks format comma12.
		,	sum(Conversions) as Conversions format comma12.
		,	UTM_Source, UTM_Medium, UTM_Campaign, UTM_Content, UTM_Term
		,	AdGroup, DA_AdLabel
		,	Do_Not_Join_to_GA_Flag
		from display.display_clean_da2
		group by 
			Date, WeekStart, Month, Quarter
		,	Campaign, Business_Size, Theme
		,	Audience, Region, SubRegion, Network, PurchaseType, PlacementType
		,	Image, Creative, BannerType, Ad_Format, Targeting
		,	UTM_Source, UTM_Medium, UTM_Campaign, UTM_Content, UTM_Term
		,	AdGroup, DA_AdLabel
		,	Do_Not_Join_to_GA_Flag;
		quit;
	
		proc sql ;
			select distinct count(*)
			into :Nmiss_da
			from zero_values;

			select distinct count(*)
			into :N_da
			from display.display_clean_da_final;
		quit;

		proc sql noprint;
			create table check_dups as
			select 
				t1.* , t2.ndups
			from display.display_clean_da_final t1
				, (select 
						date, Targeting, PlacementType, utm_source, utm_medium, utm_campaign, utm_content, utm_term, count(*) as ndups
				   from display.display_clean_da_final
				   where Do_Not_Join_to_GA_Flag = 0 /* IMPORTANT */
				   group by date, Targeting, PlacementType, utm_source, utm_medium, utm_campaign, utm_content, utm_term
				   ) t2
			where t2.ndups>1 
				and t1.date=t2.date 
				and t1.Targeting=t2.Targeting /* Not included in tagging */
				and t1.PlacementType=t2.PlacementType /* Not included in tagging */
				and t1.utm_source=t2.utm_source 
				and t1.utm_medium=t2.utm_medium
				and t1.utm_campaign=t2.utm_campaign 
				and t1.utm_content=t2.utm_content 
				and t1.utm_term=t2.utm_term
				and t1.Do_Not_Join_to_GA_Flag = 0 /* IMPORTANT */
			order by t1.date, t1.Targeting, t1.PlacementType, t1.utm_source, t1.utm_medium, t1.utm_campaign, t1.utm_content, t1.utm_term;
		quit;	

		%check_for_data(check_dups,>0,Dupes in display_clean_da_final);

	%end; /* (11) */

	%if &cancel= and &nfiles_da>0 and %sysfunc(exist(display.Display_Clean_Combined_final))
		%then %do; 
			%let combined_file=display.display_clean_combined_final;
			%put Appending to Display_Clean_Combined_final.;
		%end;
	%if &cancel= and &nfiles_da>0 and %sysfunc(exist(display.Display_Clean_Combined_final))=0 %then %do;
		%put Creating Display_Clean_Combined_final;
	%end;

	%if &cancel= and &nfiles_da>0 %then %do; /* (12) */

		data display.Display_Clean_Combined_final;

			retain 	
				Date 		WeekStart 		Month 			Quarter 	Start_Date 	End_Date
				Campaign	Business_Size	Theme			Audience	Region		SubRegion
				Network		PurchaseType	PlacementType	Creative 	Image 		BannerType
				Ad_Format	Targeting
				Spend		Impressions		Clicks			Conversions Downloads
				Utm_Source	Utm_Medium		Utm_Campaign	Utm_Content	Utm_Term
				AdGroup		Id_AdLabel		ID_Tactic		ID_Creative	DA_AdLabel
				Do_Not_Join_to_GA_Flag;

			format Network $15.
				   PurchaseType $25.
				   Image $20.
				   Ad_Format $40.
				   Targeting $20.
				   Campaign $100.
				   ID_Creative $100.
				   DA_AdLabel $200.;

			set &combined_file.
				display.display_clean_da_final
				;
	
			keep 	
				Date 		WeekStart 		Month 			Quarter 	Start_Date 	End_Date
				Campaign	Business_Size	Theme			Audience	Region		SubRegion
				Network		PurchaseType	PlacementType	Creative 	Image 		BannerType
				Ad_Format	Targeting
				Spend		Impressions		Clicks			Downloads
				Utm_Source	Utm_Medium		Utm_Campaign	Utm_Content	Utm_Term
				AdGroup		Id_AdLabel		ID_Tactic		ID_Creative	DA_AdLabel
				Do_Not_Join_to_GA_Flag;

		run;

	%end; /* (12) */

	/* -------------------------------------------------------------------------------------------------*/
	/*  Industry Week Newsletter.                                                                       */
	/* -------------------------------------------------------------------------------------------------*/

	%put Cleaning &nfiles_em. imported IW email files.;

	%if &cancel= and &nfiles_em>0 %then %do; /* (13) */

		%check_for_data(display.display_clean_em,=0,No records in display_clean_em);

		data display.display_clean_em2;

			retain	
				Date
				WeekStart
				Month
				Quarter
				Campaign	
				Business_Size
				Theme
				Audience
				Region
				SubRegion
				Network
				PurchaseType
				PlacementType
				Creative 
				Image 
				BannerType
				Ad_Format
				Targeting
				Spend
				Impressions
				Clicks
				Conversions
				Utm_Source
				Utm_Medium
				Utm_Campaign
				Utm_Content
				Utm_Term
				Do_Not_Join_to_GA_Flag;

			format  Month monyy7.
					WeekStart mmddyy10.
					Audience $50.
					Region $4.
					Ad_Format $12.
					Image $20.
					Theme $25.
					Network $15.
					Campaign $100.
					PlacementType $25.
					PurchaseType $25.	
				    Targeting $20.;

			set display.display_clean_em;

			* Initialize;
			Do_Not_Join_to_GA_Flag = 0;

			* Month;
			WeekStart=intnx('week',Date,0,'b');
			Month=intnx('month',Date,0,'b');
			Quarter=catt('Q',qtr(Date));

			* Business Size;
			Business_Size = 'LG';

			* Network;
			Network = 'IndustryWeek';

			* BannerType;
			BannerType = 'N/A';

			* PurchaseType;
			PurchaseType = 'Email Newsletter';

			* PlacementType;
			PlacementType = 'Email';

			* Targeting;
			Targeting = 'UN';

			* Audience;
			Audience = 'Executives';

			* Ad_Format; 
			Ad_Format = 'Email';

			* Region / SubRegion;
			Region = 'NA'; 
			SubRegion = 'NON';
				
			* Theme;
			Theme = 'Return to Work';
			Theme_temp = 'RTW';
	
			* Creative & Image;
			Creative = 'Return to Work';
			Image = 'Hallway';

			* UTMs;
			UTM_Source = lowcase(catx('-',Business_Size,Region,'prospect'));
			UTM_Medium = 'display';
			UTM_Campaign = lowcase(catx('|',Theme_temp,substr(Audience,1,4)));
			if Audience = 'Executives' then UTM_Content = '245974';
				else if Audience = 'HR' then UTM_Content = '245973';
			UTM_Term = lowcase(catx('|',substr(Network,1,8),Ad_Format));
			drop Theme_temp;
	
			* Campaign;
			Campaign = catx('_',catt('Display','-EM'),Business_size,Compress(Theme),compress(Audience));

		run;

		%check_for_data(display.display_clean_da2,=0,No records in display_clean_da2);

		proc sql;
		create table display.display_clean_em_final as
		select distinct
			Date, WeekStart, Month, Quarter
		,	Campaign, Business_Size, Theme
		,	Audience, Region, SubRegion, Network, PurchaseType, PlacementType
		,	Image, Creative, BannerType, Ad_Format, Targeting
		,	sum(Spend) as Spend format dollar18.2
/*		,	sum(Impressions) as Impressions format comma12.*/
		,	sum(Clicks) as Clicks format comma12.
/*		,	sum(Conversions) as Conversions format comma12.*/
		,	UTM_Source, UTM_Medium, UTM_Campaign, UTM_Content, UTM_Term
		,	Do_Not_Join_to_GA_Flag
		from display.display_clean_em2
		group by 
			Date, WeekStart, Month, Quarter
		,	Campaign, Business_Size, Theme
		,	Audience, Region, SubRegion, Network, PurchaseType, PlacementType
		,	Image, Creative, BannerType, Ad_Format, Targeting
		,	UTM_Source, UTM_Medium, UTM_Campaign, UTM_Content, UTM_Term
		,	Do_Not_Join_to_GA_Flag;
		quit;
	
		proc sql ;
			select distinct count(*)
			into :N_em
			from display.display_clean_em_final;
		quit;

		proc sql noprint;
			create table check_dups as
			select 
				t1.* , t2.ndups
			from display.display_clean_em_final t1
				, (select 
						date, Targeting, PlacementType, utm_source, utm_medium, utm_campaign, utm_content, utm_term, count(*) as ndups
				   from display.display_clean_em_final
				   where Do_Not_Join_to_GA_Flag = 0 /* IMPORTANT */
				   group by date, Targeting, PlacementType, utm_source, utm_medium, utm_campaign, utm_content, utm_term
				   ) t2
			where t2.ndups>1 
				and t1.date=t2.date 
				and t1.Targeting=t2.Targeting /* Not included in tagging */
				and t1.PlacementType=t2.PlacementType /* Not included in tagging */
				and t1.utm_source=t2.utm_source 
				and t1.utm_medium=t2.utm_medium
				and t1.utm_campaign=t2.utm_campaign 
				and t1.utm_content=t2.utm_content 
				and t1.utm_term=t2.utm_term
				and t1.Do_Not_Join_to_GA_Flag = 0 /* IMPORTANT */
			order by t1.date, t1.Targeting, t1.PlacementType, t1.utm_source, t1.utm_medium, t1.utm_campaign, t1.utm_content, t1.utm_term;
		quit;	

		%check_for_data(check_dups,>0,Dupes in display_clean_em_final);

	%end; /* (13) */

	%if &cancel= and &nfiles_em>0 and %sysfunc(exist(display.Display_Clean_Combined_final))
		%then %do; 
			%let combined_file=display.display_clean_combined_final;
			%put Appending to Display_Clean_Combined_final.;
		%end;
	%if &cancel= and &nfiles_em>0 and %sysfunc(exist(display.Display_Clean_Combined_final))=0 %then %do;
		%put Creating Display_Clean_Combined_final;
	%end;

	%if &cancel= and &nfiles_em>0 %then %do; /* (14) */

		data display.Display_Clean_Combined_final;

			retain 	
				Date 		WeekStart 		Month 			Quarter 	Start_Date 	End_Date
				Campaign	Business_Size	Theme			Audience	Region		SubRegion
				Network		PurchaseType	PlacementType	Creative 	Image 		BannerType
				Ad_Format	Targeting
				Spend		Impressions		Clicks			Conversions Downloads
				Utm_Source	Utm_Medium		Utm_Campaign	Utm_Content	Utm_Term
				AdGroup		Id_AdLabel		ID_Tactic		ID_Creative	DA_AdLabel
				Do_Not_Join_to_GA_Flag;

			format Network $15.
				   PurchaseType $25.
				   Image $20.
				   Targeting $20.
				   Campaign $100.
				   ID_Creative $100.
				   DA_AdLabel $200.;

			set &combined_file.
				display.display_clean_em_final
				;
	
			keep 	
				Date 		WeekStart 		Month 			Quarter 	Start_Date 	End_Date
				Campaign	Business_Size	Theme			Audience	Region		SubRegion
				Network		PurchaseType	PlacementType	Creative 	Image 		BannerType
				Ad_Format	Targeting
				Spend		Impressions		Clicks			Downloads
				Utm_Source	Utm_Medium		Utm_Campaign	Utm_Content	Utm_Term
				AdGroup		Id_AdLabel		ID_Tactic		ID_Creative	DA_AdLabel
				Do_Not_Join_to_GA_Flag;

		run;

	%end; /* (14) */

	/* -------------------------------------------------------------------------------------------------*/
	/*  Export and archive raw display.                                                                 */
	/* -------------------------------------------------------------------------------------------------*/

	%if &cancel= and (&N_b>0 or &N_iw>0 or &N_cs>0 or &N_em>0 or &N_da>0) %then %do; /* (10) */

		proc freq data=display.Display_Clean_Combined_final;
			tables 
				date 		WeekStart 		month 			quarter 	Start_Date 	End_Date 
				Campaign	Business_Size	Theme			Audience	Region		SubRegion
				Network		PurchaseType	PlacementType	Creative 	Image 		BannerType
				Ad_Format	Targeting
				Utm_Source	Utm_Medium		Utm_Campaign	Utm_Content	Utm_Term
				AdGroup		
				Do_Not_Join_to_GA_Flag
			/ list missing ;
		run;

		options dlcreatedir;
		libname content xlsx "&input_files/Content Syndication List _MASTER.xlsx"; run;
		data display.content_syndication_update;
			set content.'NEW - Need Approval'n;
		run;
		data display.content_syndication_master;
			set content.'MASTER - Approved'n;
		run;

		proc sql;
		/* newly imported downloads */
		create table content.'NEW - Need Approval'n as
			select distinct
				*
			from display.content_syndication_master_temp 
			where RejectedStatus='';
		/* only approved downloads */
		create table content.'MASTER - Approved'n as
			/* hitorical confirmed approved */
			select distinct * from display.content_syndication_master x 
				union
			/* newly confirmed approved */
			select distinct * from display.content_syndication_update where RejectedStatus ne 'Y';
/*		update content.'MASTER - Approved'n x*/
/*			set RejectedStatus=(select */
/*									RejectedStatus */
/*								from display.content_syndication_master_temp y*/
/*								where x.emailAddress=y.emailAddress*/
/*									 and x.Theme=y.Theme*/
/*									 and x.Audience=y.Audience*/
/*									 and x.BatchDateStatus=Y.BatchDateStatus*/
/*									 and RejectedStatus ne '') */
/*			where RejectedStatus = ''*/
/*				and exists (select */
/*								1 */
/*							from display.content_syndication_master_temp y*/
/*							where x.emailAddress=y.emailAddress*/
/*								 and x.Theme=y.Theme*/
/*								 and x.Audience=y.Audience*/
/*								 and x.BatchDateStatus=Y.BatchDateStatus*/
/*								 and RejectedStatus ne '');*/
		quit;

/*		data display.B2B_Display_Raw_Temp;*/
/*			retain*/
/*				Date WeekStart Month Quarter*/
/*				Campaign Business_Size Network BannerType Ad_Format AdGroup*/
/*				CE_AdLabel CE_BannerAdGroup CE_DynamicAdVersion*/
/*				Spend Impressions Clicks VideoStarts VideoCompletions*/
/*				VisitConv_Total VisitConv_VT VisitConv_CT UniqueImpr_Pct;*/
/*			format WeekStart mmddyy10. Month mmddyy10.;*/
/*			set final.B2B_Display_Raw*/
/*			(rename=(BannerAdgroups = CE_BannerAdGroup*/
/*					BannerSize = Ad_Format*/
/*					Campaign = AdGroup*/
/*					Cost = Spend*/
/*					LineItem = CE_AdLabel*/
/*					DynamicAdVersion = CE_DynamicAdVersion*/
/*					TrackedAds = Impressions));*/
/*			if AdGroup in ('2123_KP2021_NWB2B_LaneCounty','1929_KP_2019_B2B_NWEugene')*/
/*					then Campaign = 'Display_LG_LaneCounty';*/
/*					else Campaign='Display_LG_ValueDem';*/
/*		 	Network = strip(tranwrd(Network,'(Media)',''));*/
/*			Ad_Format = lowcase(compress(Ad_Format));*/
/*				if find(Ad_Format,'_')>0 then Ad_Format=scan(Ad_Format,2,'_');*/
/*				Ad_Format=tranwrd(tranwrd(Ad_Format,'defa',''),'def','');*/
/*			WeekStart=intnx('week',Date,0,'b');*/
/*			Month=intnx('month',Date,0,'b');*/
/*			Quarter=catt('Q',qtr(Date));*/
/*			Business_Size = 'LG';*/
/*		run;*/

		data display.B2B_Display_Raw_Temp;
			set final.B2B_Display_Raw;
		run;

		proc sql;
		insert into final.B2B_Display_Raw
			select distinct 
				* 
			/* Archived Fields */
			,	'' /* HISTORICAL: CE_AdLabel - Campbell Ewald's AdLabel */
			,	'' /* HISTORICAL: CE_BannerAdGroup - Campbell Ewald's BannerAdGroup label */
			,	'' /* HISTORICAL: CE_DynamicAdVersion - Campbell Ewald's DynamicAdVersion label*/
			,	.  /* HISTORICAL: VideoStarts - Campbell Ewald's video-type display starts */
			,	.  /* HISTORICAL: VideoCompletions - Campbell Ewald's video-type display completions */
			,	.  /* HISTORICAL: VisitConv_Total - Campbell Ewald's total landing page visits */
			,	.  /* HISTORICAL: VisitConv_VT - Campbell Ewald's landing page visits in-directly via ad */
			,	.  /* HISTORICAL: VisitConv_CT - Campbell Ewald's landing page visits directly via ad */
			,	.  /* HISTORICAL: UniqueImpr_Pct - Campbell Ewald's ??? */
			from display.Display_Clean_Combined_final;
		quit;
/**/
/*		data look; set final.B2B_Display_Raw;*/
/*			length Ad_Format $40.;*/
/*			if find(UTM_Term,'Animated','i')>0 then */
/*				Ad_Format1 = catt(scan(Ad_Format,1,'-'),'-Animated');*/
/**/
/*		run;*/
/*		proc freq data=look;*/
/*			tables Ad_Format;*/
/*		run;*/
	* If you added/removed or changed the formatting of a variable, run this instead;
	
/*		proc delete data=final.B2B_Display_Raw; run;*/
/*		data final.B2B_Display_Raw;*/
/*			set display.Display_Clean_Combined_final*/
/*				display.B2B_Display_Raw_Temp; */
/*		run;*/

	/* -------------------------------------------------------------------------------------------------*/
	/*  Save master file --> zip archive.                                                               */
	/* -------------------------------------------------------------------------------------------------*/

		proc sql noprint;
			select distinct
				min(Date) format mmddyy6.,
				max(Date) format mmddyy6.,
				max(Date) format date9.
			into :FirstData_Raw,
				 :LastData,
				 :LastDate_ThisUpdate
			from final.B2B_Display_Raw;
		quit;

		data archive.B2B_Display_Raw_&FirstData_Raw._&LastData;
			set final.B2B_Display_Raw;
		run;

		ods package(archived) open nopf;
		ods package(archived) add file="&output_files/Archive/b2b_display_raw_&FirstData_Raw._&LastData..sas7bdat";
		ods package(archived) publish archive properties (
			archive_name="b2b_display_raw_&FirstData_Raw._&LastData..zip"
			archive_path="&output_files/Archive/");
		ods package(archived) close;
		proc delete data=archive.B2B_Display_Raw_&FirstData_Raw._&LastData; run;

		filename old_arch "&output_files/Archive/b2b_display_raw_&FirstData_Raw._&LastData_Old..zip" ;
		data _null_;
			rc=fdelete("old_arch");
			put rc=;
		run;

	%end; /*%if &N > 0 %then %do;*/
	%if &N_b=0 and &N_cs=0 and &N_iw=0 and &N_em=0 and &N_da %then %do; 
		%put No new records found.;
	%end;

/* -------------------------------------------------------------------------------------------------*/
/*                                                                                                  */
/*                                                                                                  */
/*                                    Prepare for Campaign Dataset                                  */
/*                                                                                                  */
/*                                                                                                  */
/* -------------------------------------------------------------------------------------------------*/

	%if &cancel= and (&N_b>0 or &N_iw>0 or &N_cs>0 or &N_em>0 or &N_da) %then %do; *execute only if new data found;

	/* -------------------------------------------------------------------------------------------------*/
	/*  Add transformed variables.                                                                      */
	/* -------------------------------------------------------------------------------------------------*/

		proc sql;
		create table display as
			select distinct
				Date format mmddyy10.
			,	WeekStart format mmddyy10.
			,	Month format monyy7. 
			,	Quarter format $2.
			,	'Display' as Channel format $25.
			,	case when Business_Size = 'LG' then 'Display B2B' 
				     when Business_Size = 'SB' then 'Display SBU'
					end as ChannelDetail format $25.
			,	sum(Impressions) as Impressions format comma18.
			,	sum(Clicks) as Clicks format comma8.
			,	sum(Spend) as Spend format dollar18.2
			,	sum(Downloads) as Primary_Downloads format comma8. /* NEW */
			,	Campaign format $250.
			,	Network format $25.
			,	Region format $5.
			,	SubRegion format $5.
			,	case when Business_Size = 'LG' then 'Value Demonstration' 
					 when Business_Size = 'SB' then 'Lead Generation'
					 end as Program_Campaign format $30.
			,	Theme format $50.
			,	Creative format $200.
			,	Image format $30.
			,	case when PurchaseType = 'Programmatic' then catx('_',PurchaseType,PlacementType,Ad_Format)  
					 when PurchaseType = 'Content Syndication' then 'Content Syndication'
					 when PurchaseType = 'Email Newsletter' then 'Email Newsletter'
					else catx('_',PurchaseType,Ad_Format) /* PMP tags would need to be at the placement level */
					end as Ad_Format format $40.
			,	Audience format $50.
				/* Join Metrics */
			,	UTM_Source
			,	UTM_Medium
			,	UTM_Campaign
			,	UTM_Content
			,	UTM_Term 
			,	Do_Not_Join_to_GA_Flag
			from display.display_clean_combined_final
			group by 
				Date 
			,	Campaign
			,	case when Business_Size = 'LG' then 'Display B2B' 
				     when Business_Size = 'SB' then 'Display SBU'
					end 
			,	Network 
			,	Region
			,	SubRegion
			,	case when Business_Size = 'LG' then 'Value Demonstration' 
					 when Business_Size = 'SB' then 'Lead Generation'
					 end
			,	Theme 
			,	Creative
			,	Image 
			,	case when PurchaseType = 'Programmatic' then catx('_',PurchaseType,PlacementType,Ad_Format)  
					else catx('_',PurchaseType,PurchaseType,Ad_Format) /* PMP tags would need to be at the placement level */
					end 
			,	Audience 
			,	UTM_Source
			,	UTM_Medium
			,	UTM_Campaign
			,	UTM_Content
			,	UTM_Term 
			,	Do_Not_Join_to_GA_Flag
			; 
		quit;

		proc sql;
			create table check_dups as
			select 
				t1.* , t2.ndups
			from display t1
				, (select 
						date, utm_source, utm_medium, utm_campaign, utm_content, utm_term, count(*) as ndups
				   from display
				   group by date, utm_source, utm_medium, utm_campaign, utm_content, utm_term
				   ) t2
			where t2.ndups>1 
				and t1.Ad_Format ne 'Content Syndication'
				and t1.date=t2.date 
				and t1.utm_source=t2.utm_source 
				and t1.utm_medium=t2.utm_medium
				and t1.utm_content=t2.utm_content
				and t1.utm_campaign=t2.utm_campaign 
				and t1.utm_term=t2.utm_term
				order by t1.date, t1.utm_source, t1.utm_medium, t1.utm_content, t1.utm_campaign, t1.utm_term;
		quit;	
	
		* Manually de-dupe - drop second record;
/*		proc sort data=display.display_clean_final; by date utm_campaign utm_term descending spend descending clicks; run;*/
/*		data display.display_clean_final;*/
/*			set display.display_clean_final;*/
/*			by date utm_campaign utm_term descending spend descending clicks; */
/*			if first.utm_term then output;*/
/*		run;*/

		%check_for_data(check_dups,>0,Dupes in final display);
	%end;

	%if &cancel= and (&N_b>0 or &N_iw>0 or &N_cs>0 or &N_em>0) %then %do;
		
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
		from display.display_clean_combined_final
		where Do_Not_Join_to_GA_Flag = 0;
		quit;

		proc sql;
		create table better_way as
			select distinct
				Date
			,	UTM_Source
			,	UTM_Medium
			,	case when UTM_Campaign in ('(notset)','(not set)','{dscampaign}','{_dscampaign}','')
					then '_error_' /* Prevent joining on bad data */
					else UTM_Campaign
					end as UTM_Campaign format $250.
			,	UTM_Content
			,	case when UTM_Term in ('(not set)','{keyword}','')
					then '_error_' /* Prevent joining on bad data */
					else UTM_Term 
					end as UTM_Term format $250.
			,	PromoId
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
			where lowcase(UTM_Medium) = 'display'
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

			* 2021 Q4;
			*if UTM_campaign = 'sbca-dataaxle' then delete; * Not ready to process yet;
			*if find(UTM_Campaign,'industryw|direct')>0 then delete; * Not ready to process yet;
			*if find(UTM_Campaign,'industryw|email')>0 then delete; * Not ready to process yet;

			/* 2022 testing */
			if find(UTM_Campaign,'bandwagon2')>0 and Date<"16FEB2022"d then delete; * date not final;
			if find(UTM_Campaign,'depression2')>0 and Date<"16FEB2022"d then delete; * date not final;
			/* 2021 testing */
			if find(UTM_Term,'industryw|email')>0 and Date<"01DEC2021"d then delete;
			else if find(UTM_Campaign,'rtw')>0 then do;
				if (find(UTM_Term,'basisdsp|pmp')>0 or find(UTM_Term,'basisdsp|display')>0) and Date<"04NOV2021"d then delete;
				else if find(UTM_Term,'basisdsp|native')>0 and Date<"29NOV2021"d then delete;
				else if find(UTM_Term,'industryw|direct')>0 and Date<"09NOV2021"d then delete;
				end;
			else if find(UTM_Campaign,'vc')>0 then do;
				if (find(UTM_Term,'basisdsp|pmp')>0 or find(UTM_Term,'basisdsp|display')>0) and Date<"18NOV2021"d then delete;
				else if find(UTM_Term,'basisdsp|native')>0 and Date<"29NOV2021"d then delete;
				end; 
			else if find(UTM_Campaign,'mhw')>0 then do;
				if (find(UTM_Term,'basisdsp|pmp')>0 or find(UTM_Term,'basisdsp|display')>0) and Date<"18NOV2021"d then delete;
				else if find(UTM_Term,'basisdsp|native')>0 and Date<"29NOV2021"d then delete;
				else if find(UTM_Term,'industryw|direct')>0 and Date<"17DEC2021"d then delete;
				end; 
			if UTM_Term = '{adlabel}' then delete;
			if UTM_Term = 'intensify|content' then delete;

		run;
		%check_for_data(better_way,=0,No data in better way during time period);

		proc sql;
			create table check_dups as
			select 
				t1.* , t2.ndups
			from better_way t1
				, (select 
						date, utm_source, utm_medium, utm_campaign, utm_content, utm_term, count(*) as ndups
				   from better_way
				   group by date, utm_source, utm_medium, utm_campaign, utm_content, utm_term
				   ) t2
			where t2.ndups>1 
				and t1.date=t2.date 
				and t1.utm_source=t2.utm_source 
				and t1.utm_medium=t2.utm_medium
				and t1.utm_content=t2.utm_content
				and t1.utm_campaign=t2.utm_campaign 
				and t1.utm_term=t2.utm_term
				order by t1.date, t1.utm_source, t1.utm_medium, t1.utm_content, t1.utm_campaign, t1.utm_term;
		quit;	
		%check_for_data(check_dups,>0,Dupes in better way);

	%end;
	%if &cancel= and (&N_b>0 or &N_iw>0 or &N_cs>0 or &N_em>0) %then %do;

	/* -------------------------------------------------------------------------------------------------*/
	/*  Merge engine metrics with Google Analytics metrics                                              */
	/* -------------------------------------------------------------------------------------------------*/

		%let error_rsn=Error merging tables.;

		proc sort data=better_way; by date utm_source utm_medium utm_campaign utm_content utm_term; run;
		proc sort data=display; by date utm_source utm_medium utm_campaign utm_content utm_term; run;

		data display.campaign_merged
			 missing; 

			 format Network $25.
					ChannelDetail $25.
					Creative $200.
					PurchaseTemp $25.;

			merge display (in=a)
				  better_way (in=b);
			by date utm_source utm_medium utm_campaign utm_content utm_term;

			* Halo flag initialize;
			Halo_Actions = 0;

			* Set Promo ID;
			if PromoID = '' then PromoId = UTM_Content;

			* Set Remarketing;
			Remarketing = 'UN';

			if a then output display.campaign_merged;

			else do;

				WeekStart=intnx('week',Date,0,'b');
				Month=intnx('month',date,0,'b');
				Quarter=catt('Q',qtr(date));

				* Halo Action Flag;
				Halo_Actions = 1;

				* Channel;
				Channel='Display';

				* 2021 Q4 - 2022;
				if scan(UTM_Campaign,1,'|') in ('rtw','vc','mhw') then do;
					ChannelDetail = 'Display B2B';
					Program_Campaign = 'Value Demonstration';
					* Network;
					if scan(UTM_Term,1,'|') = 'basisdsp' then Network = 'Basis DSP';
						else if scan(UTM_Term,1,'|') = 'industryw' then Network = 'IndustryWeek';
					* Region';
					Region = upcase(scan(UTM_Source,2,'-'));
					SubRegion = 'NON';
					* Theme;
					Theme_temp = scan(UTM_Campaign,1,'|');
					if find(UTM_Term,'industryw|email')>0 then Theme_temp = 'rtw'; *Force all to be RTW;
					if Theme_temp = 'rtw' then Theme = 'Return to Work';
						else if Theme_temp = 'vc' then Theme = 'Virtual Care';
						else if Theme_temp = 'mhw' then Theme = 'Mental Health & Wellness';
					* Audience;
					if scan(UTM_Campaign,2,'|') = 'hr' then Audience = 'HR';
						else if scan(UTM_Campaign,2,'|') = 'exec' then Audience = 'Executives';
					* Creative;
					Creative_temp = scan(UTM_Campaign,3,'|');
					if Theme = 'Return to Work' then do;
						if Audience = 'HR' then do;
							Creative = 'Return to Work'; Image = 'Apple'; end;
						else do; 
							Creative = 'Return to Work'; Image = 'Hallway'; end;
					end;
					else if Theme = 'Virtual Care' then do;
						if Audience = 'HR' then do;
							if Creative_temp = 'statistic' then do; 
								Creative = propcase(Creative_temp);
								Image = 'Woman1';
							end;
							else do;
								Creative = propcase(Creative_temp);
								Image = 'Man1';
							end;
						end;
						else do;
							if Creative_temp = 'statistic' then do;
								Creative = propcase(Creative_temp);
								Image = 'Woman2';
							end;
							else do;
								Creative = propcase(Creative_temp);
								Image = 'Man2';
							end;
						end;
					end;
					else if Theme = 'Mental Health & Wellness' then do;
						if Audience = 'HR' then do;
							if Creative_temp = 'absenteeism' then do;
								Creative = propcase(Creative_temp);
								Image = 'Earrings';
							end;
							else if Creative_temp = 'priority' then do;
								Creative = propcase(Creative_temp);
								Image = 'BlueShirt';
							end;
							else do;
								Creative = propcase(Creative_temp);
								Image = 'Stretch';
							end;
						end;
						else do;
							if Creative_temp = 'bandwagon' then do;
								Creative = propcase(Creative_temp);
								Image = 'Tree';
							end;
							else if Creative_temp = 'depression' then do;
								Creative = propcase(Creative_temp);
								Image = 'Blanket'; 
							end;
							else if Creative_temp = 'depression2' then do; *Added 1/13 for new images;
								Creative = propcase(Creative_temp);
								Image = 'Studio'; 
							end;
							else if Creative_temp = 'bandwagon2' then do; *Added 1/13 for new images;
								Creative = propcase(Creative_temp);
								Image = 'Headphones'; 
							end;
							else if Creative_temp = 'untreated' then do;
								Creative = propcase(Creative_temp);
								Image = 'GreySweater';
							end;
						end;
					end;	
					* Campaign; 
					if find(UTM_Term,'pmp')>0 then PurchaseTemp = 'PMP'; 
						else if find(UTM_Term,'basisdsp')>0 then PurchaseTemp = 'PROG';
						else if find(UTM_Term,'industryw|direct')>0 then PurchaseTemp = 'DIRECT BUY';
						else if find(UTM_Term,'industryw|email')>0 then PurchaseTemp = 'EM';
					Campaign = catx('_',catt('Display-',substr(strip(PurchaseTemp),1,6)),'LG',Compress(Theme),Audience);
					* Ad_Format;
					if PurchaseTemp = 'PROG' then Ad_Format = catx('_','Programmatic',propcase(scan(UTM_Term,2,'|')),scan(UTM_Term,3,'|'));  
						else Ad_Format = catx('_',propcase(scan(UTM_Term,2,'|')),scan(UTM_Term,3,'|')); /* PMP tags would need to be at the placement level */
						if PurchaseTemp = 'EM' then Ad_Format = 'Email Newsletter';
							Ad_Format = tranwrd(Ad_Format,'Pmp','PMP');
							Ad_Format = tranwrd(Ad_Format,'Direct_','Direct Buy_');
							if Ad_Format = 'Programmatic_Native' then Ad_Format = 'Programmatic_Native_1200x627';
						if find(UTM_Term,'animated','i')>0 then Ad_Format = catx('-',Ad_Format,'Animated');
					drop Theme_temp PurchaseTemp Creative_temp;
					output missing;
				end;

				* 2021 Q1-Q3;
				else if scan(UTM_Term,2,'_') in ('2021b2bvd','2021lcb2b') then do;
					* ChannelDetail;
					if scan(UTM_Term,2,'_') = '2021b2bvd' then ChannelDetail = 'Display B2B';
						else if scan(UTM_Term,2,'_') = '2021lcb2b' then ChannelDetail = 'Display NW';
					* Program_Campaign;
					if scan(UTM_Term,2,'_') = '2021b2bvd' then Program_Campaign = 'Value Demonstration';
						else if scan(UTM_Term,2,'_') = '2021lcb2b' then Program_Campaign = 'Regional Initiatives';
					* Campaign;
					Campaign='Display_LG_LaneCounty';		
					* Network;
					if scan(UTM_Term,2,'_') = '2021b2bvd' then Network = 'Simpli.fi';
						else if scan(UTM_Term,2,'_') = '2021lcb2b' then Network = 'Real Time Bidding';
					* Region;
					Region_temp=upcase(scan(UTM_Term,3,'_'));
					if Region_temp='CO' then Region='CLRD';
						else if Region_temp='GA' then Region='GRGA';
						else if Region_temp='NW' then Region='PCNW';
						else if Region_temp='WAS' then Region='KPWA';
						else Region=Region_temp;
						/* NCAL and SCAL already standardized */
					drop Region_temp;
					SubRegion='NON';
					* Theme;
					if scan(UTM_Term,2,'_') = '2021b2bvd' then do;
						Theme=upcase(scan(UTM_Term,14,'_')); 
						if Theme='PHR' then Theme='Employee Health';
						else if Theme='THGS' then Theme='Telehealth';
						else if Theme='MHS' then Theme='Mental Health and Wellness / Stress Management';
						end;
					else if scan(UTM_Term,2,'_') = '2021lcb2b' then do;
						Theme=upcase(scan(scan(UTM_Campaign,3,'-'),7,'_'));
						if Theme='COVD' then Theme='COVID-19';
						else if Theme='GB2B' then Theme='General B2B';
						end;
					* Creative;
					UTM_Campaign = tranwrd(UTM_Campaign,'new_07_','');
					if find(UTM_Campaign,'b2b_2020_lc_nw_b2b_non') > 0 then Creative_Temp = strip(lowcase(scan(UTM_Campaign,8,'_')));
					else Creative_temp = strip(scan(scan(UTM_Campaign,3,'-'),8,'_'));
					* MHW/Stress;
					if find(Creative_temp,"worriedaboutyour") > 0 then Creative = "Worried about your team's well-being";
					else if find(Creative_temp,"areyouremployees") > 0 then Creative = "Are your employees stressed";
					else if find(Creative_temp,"3in4") > 0 then Creative = "3 in 4 employees struggle with";
					else if find(Creative_temp,"isstressrising") > 0 then Creative = "Is stress rising among your team";
					else if find(Creative_temp,"putselfcare") > 0 then Creative = "Put self-care at their fingertips";
					* Telehealth;	
					else if find(Creative_temp,"telehealthisnta") > 0 then Creative = "Telehealth isn't a nice-to-have";
					else if find(Creative_temp,"workdaysgetlonger") > 0 then Creative = "Workdays get longer at home";
					else if find(Creative_temp,"covid19haschanged") > 0 then Creative = "Covid-19 has changed telehealth";
					else if find(Creative_temp,"telehealthisnow") > 0 then Creative = "Telehealth is now a must-have";
					else if find(Creative_temp,"helpyourteam") > 0 then Creative = "Help your team avoid burnout";
					* Employee Health;
					else if find(Creative_temp,"wearamask") > 0 then Creative = "Wear a mask. Wash your hands";
					else if find(Creative_temp,"keepyouremployees") > 0 then Creative = "Keep your employees healthy";
					else if find(Creative_temp,"keepemployeessafe") > 0 then Creative = "Keep employees safe and healthy";
					else if find(Creative_temp,"toolsfora") > 0 then Creative = "Tools for a safe return to work";
					* COVID-19;
					else if find(Creative_Temp,"easingworryabout") > 0 then Creative="Easing worry about COVID-19"; 
					else if find(Creative_Temp,"getcovid19support") > 0 then Creative="Get COVID-19 support"; 
					else if find(Creative_Temp,"managingstressover") > 0 then Creative="Managing stress over COVID-19"; 
					else if find(Creative_Temp,"planforwhats") > 0 then Creative="Plan for what's next at work"; 
					else if find(Creative_Temp,"returntothe") > 0 then Creative="Return to the workplace";
					* General B2B;
					else if find(Creative_Temp,"cultivateresilience") > 0 then Creative="Cultivate resilience"; 
					else if find(Creative_Temp,"discoverhealthyways") > 0 then Creative="Discover healthy ways employees"; 
					else if find(Creative_Temp,"healthywaysto") > 0 then Creative="Healthy ways to fight stress"; 
					else if find(Creative_Temp,"managestressnow") > 0 then Creative="Manage stress now"; 
					else if find(Creative_Temp,"resilientemployeesturn") > 0 then Creative="Resilient employees turn"; 
					else if find(Creative_Temp,"solutionsforstress") > 0 then Creative="Solutions for stress"; 
					else if find(Creative_Temp,"toolstoease") > 0 then Creative="Tools to ease stress on the job"; 
					drop Creative_temp;
					* Image;
					Image=catx(' ',strip(scan(scan(UTM_Campaign,3,'-'),12,'_')),strip(scan(scan(UTM_Campaign,3,'-'),13,'_')));
						if find(Image,'html','i') > 0 then Image=catt('Animated',substr(Image,length(Image)-1));
						else if Image in ('Image non','image non','STAT NON') then Image='Static';
						else if find(UTM_Campaign,'b2b_2020_lc_nw_b2b_non') > 0 then Image=catx(' ','In-Stream',strip(scan(UTM_Campaign,9,'_')));
					* Ad_Format;
					if find(UTM_Campaign,'b2b_2020_lc_nw_b2b_non') > 0 then Ad_Format='1920x1080';
					else if scan(UTM_Term,2,'_') = '2021lcb2b' then Ad_Format=scan(scan(UTM_Campaign,1,'-'),4,'_');
					else if scan(UTM_Term,2,'_') = '2021b2bvd' then Ad_Format=scan(UTM_Term,10,'_');
					* Remarketing;
					if lowcase(scan(UTM_Term,7,'_'))='rtg' then Remarketing='Y';
						else Remarketing = 'N';
					* Audience;
					Audience_temp=lowcase(scan(UTM_Term,7,'_'));
						if Audience_temp = 'prosp' then Audience = 'Prospecting';
						else if Audience_temp = 'geo' then Audience = 'Geofencing';
						else if Audience_temp = 'kyw' then Audience = 'Keyword';
						else if Audience_temp = 'cntx' then Audience = 'Contextual';
						else if Audience_temp = 'rtg' then Audience = 'Retargeting';
					drop Audience_temp;
					output missing;
				end;

				* 2020 Display B2B;
				else if compress(UTM_source,'.')='simplifi' and UTM_medium='display' then do;
						ChannelDetail='Display B2B';
						Program_Campaign='Value Demonstration';
						Campaign='Display_LG_ValueDem';
						Network='Simpli.fi';
						Region='UN';
						SubRegion='UN';
						Theme = 'UN';
						Creative = UTM_Campaign;
						Image = 'Unknown';
						Ad_Format = UTM_Term;
						Remarketing='UN';
						Audience = 'Unknown';
						output missing;
				end;

				* Data Axle SB;
				else if UTM_Campaign='sbca-dataaxle' and UTM_medium='display' then do;
						ChannelDetail = 'Display SBU';
						Program_Campaign = 'Lead Generation';
						Network = 'MediaMath';
						Region = 'CACA';
						SubRegion='NON';
						Theme = 'SB Health Plans';
						if find(UTM_Term,'test|')>0 then Creative = 'CTA Get Quote';
							else Creative = 'CTA Learn More';
						Image = strip(propcase(tranwrd(scan(tranwrd(UTM_Term,'test|',''),1,'|'),'-',' ')));
							Image = tranwrd(Image,'At A','at a');
						Ad_Format = scan(tranwrd(UTM_Term,'test|',''),2,'|');
						Remarketing = 'UN';
						Audience = 'SBCA Direct Mail Universe';						
						Campaign = catx('_','Display',upcase(scan(UTM_Source,1,'-')),Compress(Theme),compress(Audience));;
						output missing;
				end;

				* EL display;
				else if UTM_Source = 'ttd' then do;
						Program_Campaign='Regional Initiative';
						Campaign=UTM_Campaign;
						Network='The Trade Desk';
						Region=upcase(scan(UTM_Campaign,6,'_'));
						SubRegion=upcase(scan(UTM_Campaign,7,'_'));
						Theme='UN';
						Creative='UN';
						Image='UN';
						Ad_Format='UN';
						Remarketing='UN';
						Audience='UN';
						ChannelDetail=catx(' ','Display',Region);
						output missing;
				end;

				* Current regional display campaigns;
				else do;
						Program_Campaign='Regional Initiative';
						Campaign=UTM_Campaign;
						Network='UN';
						Region=upcase(scan(utm_source,2,'-'));
							ChannelDetail=catx(' ','Display',Region);
							if Region = 'HI' then Region = 'HWAI';
						SubRegion='NON';
						Theme='UN'; Creative='UN'; Image='UN'; Ad_Format=UTM_Term;
						Remarketing='UN';
						Audience='UN';
						output missing;
				end;

			end;

		run;

	%let error_rsn=Error appending tables.;

		data display.b2b_campaign_master_display;

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
					Ad_Format $40. /* new length */
					Audience $50. 
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
			
				;
		 	set display.campaign_merged(drop=Do_Not_Join_to_GA_Flag)
				missing(drop=UTM:);

			Total_Engagements=.;
			Total_Social_Actions=.;
			Primary_Contacts=.;
			Secondary_Downloads=.;
			Lead_Forms_Opened=.;
			Leads=.;
			Keyword='N/A';
			Match_Type='N/A';
			Keyword_Category='N/A';
			Business_Actions=.;
			Business_Leads=.;

			* Replace missing numeric w/ 0;
				 array change _numeric_;
			        do over change;
			            if change=. then change=0;
			        end;

		run;
		%check_for_data(display.b2b_campaign_master_display,=0,No data in display campaign master);

	%end;
	%if &cancel= and (&N_b>0 or &N_iw>0 or &N_cs>0 or &N_em>0 or &N_da>0) %then %do;

	/* Validation */
		proc sql;
			title 'Dataset about to be pushed to b2b_campaign_master';
			select distinct
				sum(spend) as spend format dollar18.2
			,	sum(impressions) as impressions format comma18.
			,	sum(clicks) as clicks format comma18.
			,	sum(primary_downloads) as primary_downloads format comma18.
			,	sum(goal7_learn+goal8_shop) as ga_actions_old format comma8.
			,	sum(convertsubmit_contact+convertsubmit_quote) as ga_leads format comma8.
			,	sum(sessions) As sessions format comma8.
			into :valid_spend, :valid_impr, :valid_clicks, :valid_conv,
				 :valid_act, :valid_lead, :valid_visit
			from display.b2b_campaign_master_display;

			title 'Original set from Display';
			select distinct
				sum(spend) as spend format dollar18.2
			,	sum(impressions) as impressions format comma18.
			,	sum(clicks) as clicks format comma18.
			,	sum(primary_downloads) as primary_downloads format comma18.
			into :spend, :impr, :clicks, :conv
			from display;

			title 'Original set from Better Way';
			select distinct
				sum(goal7_learn+goal8_shop) as ga_actions_old format comma8.
			,	sum(convertsubmit_contact+convertsubmit_quote) as ga_leads format comma8.
			,	sum(sessions) As sessions format comma8.
			into :act, :lead, :visit
			from better_way;
			title;
		quit;

		proc sql;
			select distinct
				Campaign
			,	sum(impressions) as Impressions
			,	sum(clicks) as Clicks
			,	sum(clicks)/sum(impressions) as CTR
			,	sum(sessions) as Sessions
			,	sum(sessions)/sum(impressions) as Visit_Rt
			,	sum(weighted_actions) as GA_actions format comma8.
			,	sum(ConvertSubmit_Contact+ConvertSubmit_Quote+SB_MAS_Leads+ConvertNonSubmit_SSQ*0.43) as GA_leads format comma8.
			,	sum(weighted_actions)/sum(sessions) as Actions_Per_Visit
			from display.b2b_campaign_master_display
			group by 
				Campaign
			order by 
				Campaign;
		quit;

		%check_for_data(display.b2b_campaign_master_display,=0,No records in display.b2b_campaign_master_display);

%end; 

%if %eval(&valid_spend ne &spend) 
		or %eval(&valid_conv ne &conv)
		or %eval(&valid_visit ne &visit)
		%then %do;
			%let cancel=cancel;
			%put Error: Raw data not properly appended to campaign master.
%end;
	
%if &cancel= and (&N_b>0 or &N_iw>0 or &N_cs>0 or &N_em>0 or &N_da>0) %then %do;

	/* -------------------------------------------------------------------------------------------------*/
	/*  Export and archive.                                                                             */
	/* -------------------------------------------------------------------------------------------------*/

		data display.B2B_Campaign_Master_Temp;
			set prod.B2B_Campaign_Master;
		run;

		proc sql;
		insert into prod.B2B_Campaign_Master
			select 
				*
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
			from display.b2b_campaign_master_display;
		quit;

	* If you added/removed or changed the formatting of a variable, run this instead;

/*		proc delete data=prod.B2B_Campaign_Master; run;*/
/*		data prod.B2B_Campaign_Master;*/
/*			set display.b2b_campaign_master_display(in=a) */
/*				display.B2B_Campaign_Master_Temp(in=b);*/
/*			if a then Rec_Update_Date = datetime(); */
/*		run;*/

	/* -------------------------------------------------------------------------------------------------*/
	/*  Save master file --> zip archive.                                                               */
	/* -------------------------------------------------------------------------------------------------*/

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
		ods package(archived) add file="&output_files/Archive/b2b_campaign_&FirstData._&LastData..sas7bdat";
		ods package(archived) publish archive properties (
			archive_name="b2b_campaign_&FirstData._&LastData..zip"
			archive_path="&output_files/Archive/");
		ods package(archived) close;
		proc delete data=archive.B2B_Campaign_&FirstData._&LastData; run;

		*Create the list of files, in this case all ZIP files;
		%list_files(&output_files./Archive,ext=zip);

		%let filename_oldarchive=DNE; *Initialize;
		proc sql noprint;
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
		proc delete data=display.b2b_campaign_master_temp; run;
		* Second backup of b2b_paidsearch_el_raw;
		ods package(archived) open nopf;
		ods package(archived) add file="&input_files/b2b_display_raw_temp.sas7bdat";
		ods package(archived) publish archive properties (
			archive_name="b2b_display_raw_temp.zip"
			archive_path="&input_files/");
		ods package(archived) close;
		proc delete data=display.b2b_display_raw_temp; run;
		* Delete files from most recent update;
		proc delete data=display.display_clean_combined_final; run;
		proc delete data=display.campaign_merged; run;
		proc delete data=display.b2b_campaign_master_display; run;
		proc delete data=display.display_clean_basis; run;
		proc delete data=display.display_clean_b2; run;
		proc delete data=display.display_clean_b_final; run;
		proc delete data=display.display_clean_cs; run;
		proc delete data=display.display_clean_cs2; run;
		proc delete data=display.display_clean_cs_final; run;
		proc delete data=display.display_clean_iw; run;
		proc delete data=display.display_clean_iw2; run;
		proc delete data=display.display_clean_iw_final; run;
		proc delete data=display.display_clean_da; run;
		proc delete data=display.display_clean_da2; run;
		proc delete data=display.display_clean_da_final; run;
		proc delete data=display.display_clean_em; run;
		proc delete data=display.display_clean_em2; run;
		proc delete data=display.display_clean_em_final; run;
/*		proc delete data=display.review_table; run;*/ /* save for review */

	/* -------------------------------------------------------------------------------------------------*/
	/*  Frequency Tables.                                                                               */
	/* -------------------------------------------------------------------------------------------------*/ 
		
		proc sql; 
		select distinct 
			count(distinct date) 
		into :days 
		from prod.B2B_Campaign_Master
		where Date >= "&Campaign_StartDate"d
			and Channel='Display';
		quit;

		options dlcreatedir;
		libname freq xlsx "&input_files/Frequency Tables - Get_Display_Data_Weekly.xlsx"; run;
		proc sql;
		create table freq.'Final Append by Date'n as
			select distinct
				Date
			,	case when Date>="&Campaign_StartDate"d then 1 else 0 end as New_Data
			,	sum(impressions) as Impressions
			,	sum(clicks) as Clicks
			,	sum(primary_downloads) as CS_Downloads
			,	sum(sessions) as Sessions
			,	sum(clicks)/sum(impressions) as CTR
			,	sum(sessions)/sum(impressions) as Visit_Rt
			,	sum(weighted_actions) as GA_actions format comma8.
			,	sum(ConvertSubmit_Contact+ConvertSubmit_Quote+SB_MAS_Leads+ConvertNonSubmit_SSQ*0.43) as GA_leads format comma8.
			,	sum(weighted_actions)/sum(sessions) as Actions_Per_Visit
			from prod.B2B_Campaign_Master
			where Channel='Display'
				and Date>=intnx('day',"&Campaign_StartDate"d,-&days.,'s')
				and Ad_Format ne 'Content Syndication'
			group by 
				Date, case when Date>="&Campaign_StartDate"d then 1 else 0 end
			order by 
				Date, case when Date>="&Campaign_StartDate"d then 1 else 0 end;
		quit;
		proc sql;
		create table freq.'Final Append by Program'n as
			select distinct
				Program_campaign
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
			where Channel='Display'
				and Date>=intnx('day',"&Campaign_StartDate"d,-&days.,'s')
			group by 
				Program_campaign
			,	case when Date>="&Campaign_StartDate"d then 1 else 0 end
			order by 
				Program_campaign
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
			where Channel='Display'
				and Date>=intnx('day',"&Campaign_StartDate"d,-&days.,'s')
			group by 
				Region
			,	case when Date>="&Campaign_StartDate"d then 1 else 0 end 
			order by 
				Region
			,	case when Date>="&Campaign_StartDate"d then 1 else 0 end ;
		quit;

	%end;

/* -------------------------------------------------------------------------------------------------*/
/*  Email log.                                                                                      */
/* -------------------------------------------------------------------------------------------------*/ 	

	%let Nnew = %eval(&N_b+&N_iw+&N_cs+&N_em+&N_da);

	/* you may change the default sentFrom and sentTo */
	%emailB2Bdashboard(Get_Display_Data_Weekly,
			attachFreqTableFlag=1,
			attachLogFlag=1
			/*sentFrom=,
			sentTo=*/
			);

	proc printto; run; /* Turn off log export to .txt */