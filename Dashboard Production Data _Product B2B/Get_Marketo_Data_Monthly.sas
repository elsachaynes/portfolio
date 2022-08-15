/****************************************************************************************************/
/*  Program Name:       Get_Marketo_Data_Monthly.sas                                                */
/*                                                                                                  */
/*  Date Created:       Oct 28, 2021                                                                */
/*                                                                                                  */
/*  Created By:         Elle Haynes                                                                 */
/*                                                                                                  */
/*  Purpose:            Compiles daily data from Marketo Emails for the B2B Nurture Dashboard.      */
/*                                                                                                  */
/*  Inputs:             Marketo activity code lookup table.                                         */
/*                                                                                                  */
/* -------------------------------------------------------------------------------------------------*/	
/*  Notes:              Input files pulled via API in 4MB batches and saved manually.               */
/* -------------------------------------------------------------------------------------------------*/
/*  Date Modified:                                                                                  */
/*  Modified by:                                                                                    */
/*  Description:                                                                                    */
/****************************************************************************************************/

/*	filename old_log "/gpfsFS2/sasdata/nfs/ndc_grid/po_imca_digital/EHaynes/B2B Dashboard Data Processing/Adform Display Weekly Extracts/LOG Get_Display_Data_Weekly.txt";*/
/*	data _null_; rc=fdelete("old_log"); put rc=; run;*/
/*	proc printto log="/gpfsFS2/sasdata/nfs/ndc_grid/po_imca_digital/EHaynes/B2B Dashboard Data Processing/Adform Display Weekly Extracts/LOG Get_Display_Data_Weekly.txt"; run;*/

	* Folder path;
	%let input_files = /gpfsFS2/sasdata/nfs/ndc_grid/po_imca_digital/EHaynes/B2B Mid-Large Nurture Email;
	libname raw "&input_files/_Raw Marketo Data";
	libname input "&input_files";

	* Activity Type Lookup;
	libname lookup xlsx "&input_files/Marketo Activity Type Codes.xlsx"; run;

	%let output_files = /gpfsFS2/sasdata/adhoc/po/imca/product/B2B;
	libname final "&output_files";
	libname archive "&output_files/Archive"; 

	%let production_path= /gpfsFS2/sasdata/nfs/ndc_grid/po_imca_product/B2B;
	libname prod "&production_path";

	%let dt=.; *"11jan2021"d; *leave empty unless running manually;
	%let nfiles=0; *initialize, the number of xlsx files in the input_files directory;
	%let N=0; *initialize, number of new observations from imported (value dem) dataset;
	%let FirstData=;

/* -------------------------------------------------------------------------------------------------*/
/*  Load stored macros.                                                                             */
/* -------------------------------------------------------------------------------------------------*/

	%include "/gpfsFS2/sasdata/adhoc/po/imca/digital/code/Access/SAS_Macro_ListFiles.sas"; 
	%include "/gpfsFS2/sasdata/adhoc/po/imca/digital/code/Access/SAS_Macro_CheckForData.sas"; 
	*%include "/gpfsFS2/sasdata/adhoc/po/imca/digital/code/Access/SAS_Macro_Email.sas"; 

/* -------------------------------------------------------------------------------------------------*/
/*                                                                                                  */
/*                                                                                                  */
/*                                         Check for new file                                       */
/*                                                                                                  */
/*                                                                                                  */
/* -------------------------------------------------------------------------------------------------*/

	*Create the list of Activity files;
	%list_files(&input_files./_Raw Marketo Data/Activity);

	proc sql /*noprint*/;
		select 
			count(*) 
		,	the_name
		into :nfiles,
			 :filename separated by ','
		from list 
		where find(the_name,'90day_activity')>0
		order by the_name;	
	quit;
	proc delete data=list; run;

	*Create the list of Lead files;
	%list_files(&input_files./_Raw Marketo Data/MidLarge Lead);
	proc sql /*noprint*/;
			select 
			count(*) 
		,	the_name
		into :nfiles_lead,
			 :filename_lead separated by ','
		from list 
		where find(the_name,'MidLarge Lead')>0
		order by the_name;	
	quit;	
	proc delete data=list; run;

	%let error_rsn = New exports not found in directory.;

/* -------------------------------------------------------------------------------------------------*/
/*                                                                                                  */
/*                                                                                                  */
/*                                         Ingest Raw Data                                          */
/*                                                                                                  */
/*                                                                                                  */
/* -------------------------------------------------------------------------------------------------*/

	%if &nfiles > 0 %then %do;

		proc sql /*noprint*/;
			select
				max(datepart(ActivityDatetime)) format mmddyy6.
			,	max(datepart(ActivityDatetime)) format date9.
			into :LastData_Old trimmed,
				 :LastData_OldNum trimmed
			from final.B2B_Marketo_Raw
			where ActivityTypeId = 6; /* last sent email */
		quit;

	/* -------------------------------------------------------------------------------------------------*/
	/*  Import and clean new data.                                                                      */
	/* -------------------------------------------------------------------------------------------------*/

		data lookup; set lookup.sheet1; run;
	
		data raw;

	        infile "&input_files/_Raw Marketo Data/Activity/*"
			delimiter = "," missover dsd lrecl=32767 firstobs=2 ;

			informat MarketoGUID $10. ;
			informat MarketoLeadID $10. ;
			informat ActivityDatetime ANYDTDTM. ;
			informat ActivityTypeId 8. ;
			informat CampaignID $5. ;
			informat PrimaryID $5. ;
			informat PrimaryValue $100. ;
			informat Attributes $250. ;

			format MarketoGUID $10. ;
			format MarketoLeadID $10. ;
			format ActivityDatetime datetime18. ;
			format ActivityTypeId 8. ;
			format CampaignID $5. ;
			format PrimaryID $5. ;
			format PrimaryValue $100. ;
			format Attributes $250. ;
			
			input
				 MarketoGUID	$
				 MarketoLeadID	$ 
				 ActivityDatetime 
				 ActivityTypeId  
				 CampaignID		$ 
				 PrimaryID 		$
				 PrimaryValue   $
				 Attributes		$  
				 ;
			
			if ActivityDatetime = . then delete;

		run;
		data raw_filtered; set raw; where datepart(activityDateTime)>"&LastData_OldNum"d; run;
		proc sql ;
			select 
				count(*) 
				, case when month(max(datepart(activityDateTime))) < 10 
						then cats("0",strip(put(month(max(datepart(activityDateTime))),8.)))
						else strip(put(month(max(datepart(activityDateTime))),8.)) end
				, year(min(datepart(activityDateTime))) 
			into :N,
				 :mm,
				 :yyyy
			from raw_filtered;
		quit;
		%let arch_file=%bquote(%sysfunc(strip(&yyyy.)))_%bquote(%sysfunc(strip(&mm.)))_90day_activity.txt;
		%put &arch_file;

		/* to update an existing .txt archive, uncomment below */

/*		data raw_arch;*/
/**/
/*	        infile "&input_files/_Raw Marketo Data Archive/&arch_file."*/
/*			delimiter = "|" missover dsd lrecl=32767 firstobs=2 ;*/
/**/
/*			informat MarketoGUID $10. ;*/
/*			informat MarketoLeadID $10. ;*/
/*			informat ActivityDatetime ANYDTDTM. ;*/
/*			informat ActivityTypeId 8. ;*/
/*			informat CampaignID $5. ;*/
/*			informat PrimaryID $5. ;*/
/*			informat PrimaryValue $100. ;*/
/*			informat Attributes $200. ;*/
/**/
/*			format MarketoGUID $10. ;*/
/*			format MarketoLeadID $10. ;*/
/*			format ActivityDatetime datetime18. ;*/
/*			format ActivityTypeId 8. ;*/
/*			format CampaignID $5. ;*/
/*			format PrimaryID $5. ;*/
/*			format PrimaryValue $100. ;*/
/*			format Attributes $200. ;*/
/*			*/
/*			input*/
/*				 MarketoGUID	$*/
/*				 MarketoLeadID	$ */
/*				 ActivityDatetime */
/*				 ActivityTypeId  */
/*				 CampaignID		$ */
/*				 PrimaryID 		$*/
/*				 PrimaryValue   $*/
/*				 Attributes		$  */
/*				 ;*/
/**/
/*		run;*/
/**/
/*		proc sql;*/
/*		insert into raw_arch*/
/*		select * from raw_filtered;*/
/*		quit;*/

/*		proc export data=raw_arch replace*/
/*		    outfile="&input_files/_Raw Marketo Data Archive/&arch_file."*/
/*		    dbms=dlm;*/
/*			delimiter="|";*/
/*		run;*/
/**/
/*		proc delete data=raw_arch; run;*/

		/* end update archive */

	/* -------------------------------------------------------------------------------------------------*/
	/*  Save input file --> zip archive.                                                                */
	/* -------------------------------------------------------------------------------------------------*/

		proc export data=raw_filtered replace
		    outfile="&input_files/_Raw Marketo Data Archive/&arch_file."
		    dbms=dlm;
			delimiter="|";
		run;
		ods package(archived) open nopf;
		ods package(archived) add file="&input_files/_Raw Marketo Data Archive/&arch_file.";
		ods package(archived) publish archive properties (
			archive_name="&arch_file..zip"
			archive_path="&input_files/_Raw Marketo Data Archive/");
		ods package(archived) close;
		filename import "&input_files/_Raw Marketo Data Archive/&arch_file.";
		data _null_;
			rc=fdelete("import");
			put rc=;
		run;

		data marketob2b;

	        infile "&input_files/_Raw Marketo Data/MidLarge Lead/*"
			delimiter = "," missover dsd lrecl=32767 firstobs=2 ;

			informat MarketoLeadID $10. ;
			informat Id $18. ;
			informat PHI_FirstName $25. ;
			informat PHI_LastName $25. ;
			informat AccountId $18. ;
			informat RecordTypeId $18. ;
			informat LeadEffectiveDate datetime20. ;
			informat Company $100. ;

			format MarketoLeadID $10. ;
			format Id $18. ;
			format PHI_FirstName $25. ;
			format PHI_LastName $25. ;
			format AccountId $18. ;
			format RecordTypeId $18. ;
			format LeadEffectiveDate datetime20. ;
			format Company $100. ;
			
			input
				 MarketoLeadID			$
				 Id						$ 
				 PHI_FirstName 			$
				 PHI_LastName 			$ 
				 AccountId				$ 
				 RecordTypeId 			$
				 LeadEffectiveDate   
				 Company				$ 
				 ;

		run;

	%end; /* %if &nfiles > 0 %then %do; */

	%if &N > 0 %then %do;

	/* -------------------------------------------------------------------------------------------------*/
	/*  Filter to B2B Mid/Large Email.                                                                  */
	/* -------------------------------------------------------------------------------------------------*/

		proc sql; 
		create table ids as
		select distinct 
			MarketoLeadID
		from raw_filtered
		where find(PrimaryValue,'MidLarge_A_EP_LGRP_NUR_NATL')>0 /* IDs in activity export */
			or MarketoLeadId in (select MarketoLeadId from marketob2b where MarketoLeadId ne 'Lead ID'); /* IDs in lead export */
		quit;
		proc sql; /* Now, restrict the newly imported marketo file to these ids */
		create table raw_filter1 as
		select 
			*
		from raw_filtered
		where MarketoLeadId in (select MarketoLeadId from ids) 
			and MarketoLeadId not in ('963','6625006','1303956','7979512') /* Test accts */
		order by MarketoLeadId, ActivityDateTime;
		quit;
		proc sql; /* Now, add SC Account ID */
		create table raw_filter2 as
		select distinct
			x.*
		,	coalescec(y.Id,z.Id) as Id
		,	coalescec(y.AccountId,z.AccountId) as AccountId
		from raw_filter1 x
		left join marketob2b y
			on x.MarketoLeadId=y.MarketoLeadId
		left join final.B2B_Marketo_Raw z
			on x.MarketoLeadId=z.MarketoLeadId
		order by x.MarketoLeadId, x.ActivityDateTime;
		quit;
		proc sql; 
		select distinct count(distinct MarketoLeadId)
		from raw_filter2
		where AccountId = '';
		quit;

		/* -------------------------------------------------------------------------------------------------*/
		/*  Filter Activity Codes.                                                                          */
		/* -------------------------------------------------------------------------------------------------*/

		proc sql;
		create table raw_filter3 as
		select
			*
		from raw_filter2
		where activityTypeId in (select 'Activity ID'n from Lookup where 'Use for MidLarge'n = 'Y')
		order by MarketoLeadId, ActivityDateTime;
		quit;
	
	/* -------------------------------------------------------------------------------------------------*/
	/*  Export and archive raw display.                                                                 */
	/* -------------------------------------------------------------------------------------------------*/

		data input.B2B_Marketo_Raw_Temp;
			set final.B2B_Marketo_Raw;
		run;

		proc sql;
		insert into final.B2B_Marketo_Raw
			select distinct * from raw_filter3;
		quit;

	* If you added/removed or changed the formatting of a variable, run this instead;
	
/*		proc delete data=final.B2B_Marketo_Raw; run;*/
/*		data final.B2B_Marketo_Raw;*/
/*			set raw_filter3 */
/*				input.B2B_Marketo_Raw_Temp; */
/*		run;*/

	/* -------------------------------------------------------------------------------------------------*/
	/*  Save master file --> zip archive.                                                               */
	/* -------------------------------------------------------------------------------------------------*/

		proc sql noprint;
			select
				min(datepart(ActivityDatetime)) format mmddyy6.,
				max(datepart(ActivityDatetime)) format mmddyy6.,
				max(datepart(ActivityDatetime)) format date9.
			into :FirstData_Raw,
				 :LastData,
				 :LastDate_ThisUpdate
			from final.B2B_Marketo_Raw
			where ActivityTypeId = 6;
		quit;

		data archive.B2B_Marketo_Raw_&FirstData_Raw._&LastData;
			set final.B2B_Marketo_Raw;
		run;

		ods package(archived) open nopf;
		ods package(archived) add file="&output_files/Archive/b2b_marketo_raw_&FirstData_Raw._&LastData..sas7bdat";
		ods package(archived) publish archive properties (
			archive_name="b2b_marketo_raw_&FirstData_Raw._&LastData..zip"
			archive_path="&output_files/Archive/");
		ods package(archived) close;

		filename old_arch "&output_files/Archive/b2b_marketo_raw_&FirstData_Raw._&LastData_Old..zip" ;
		data _null_;
			rc=fdelete("old_arch");
			put rc=;
		run;

	%end; /*%if &N > 0 %then %do;*/
	%if &N=0 %then %do; 
		%put No new B2B records found in Marketo extract.;
	%end;

	/* need to schedule all files moved from MARKETO to sas grid */
	/* what about all updates? */
	/* make sure to move the DB export to the right folder */
	/* need to schedule to move the zipped backup back to the MARKETO folder */

	/* only clear the folders below if successfully imported the new data */

/*    %macro clear_folder(filepath);*/
/*       filename filelist "&filepath";*/
/*       data _null_;*/
/*          dir_id = dopen('filelist');*/
/*          total_members = dnum(dir_id);*/
/*          do i = 1 to total_members;  */
/*             member_name = dread(dir_id,i);*/
/*              file_id = mopen(dir_id,member_name,'i',0);*/
/*              if file_id > 0 then do; */
/*                freadrc = fread(file_id);*/
/*                rc = fclose(file_id);*/
/*                rc = filename('delete',member_name,,,'filelist');*/
/*                rc = fdelete('delete');*/
/*             rc = fclose(file_id);*/
/*          end;*/
/*          end;*/
/*          rc = dclose(dir_id);*/
/*       run;*/
/*    %mend;*/
/**/
/*    %clear_folder(&input_files./_Raw Marketo Data/Activity);*/
/*	%clear_folder(&input_files./_Raw Marketo Data/MidLarge Lead);*/


