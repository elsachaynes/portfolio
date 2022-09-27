/****************************************************************************************************/
/*  Program Name:       Get_Twitter_Data_Weekly.sas                                                 */
/*                                                                                                  */
/*  Date Created:       Jan 27, 2022                                                                */
/*                                                                                                  */
/*  Created By:         Elle Haynes                                                                 */
/*                                                                                                  */
/*  Purpose:            Compiles daily data from Twitter for the B2B Dashboard.                     */
/*                                                                                                  */
/*  Inputs:             Manual extracts from Twitter Ads Manager downloaded to folder.              */
/*                                                                                                  */
/* -------------------------------------------------------------------------------------------------*/	
/*  Notes:              Update to run on API.                                                       */
/* -------------------------------------------------------------------------------------------------*/
/*  Date Modified:                                                                                  */
/*  Modified by:                                                                                    */
/*  Description:                                                                                    */
/****************************************************************************************************/

	filename old_log "/gpfsFS2/sasdata/nfs/ndc_grid/po_imca_digital/EHaynes/B2B Dashboard Data Processing/Twitter/LOG Get_Twitter_Data_Weekly.txt";
	data _null_; rc=fdelete("old_log"); put rc=; run;
	proc printto log="/gpfsFS2/sasdata/nfs/ndc_grid/po_imca_digital/EHaynes/B2B Dashboard Data Processing/Twitter/LOG Get_Twitter_Data_Weekly.txt"; run;
	
	* Raw Data Download Folder;
	%let raw_file_path = /gpfsFS2/sasdata/nfs/ndc_grid/po_imca_digital/EHaynes/B2B Dashboard Data Processing/_Raw Data Downloads;
	libname import "&raw_file_path";

	%let input_files = /gpfsFS2/sasdata/nfs/ndc_grid/po_imca_digital/EHaynes/B2B Dashboard Data Processing/Twitter;
	libname Twitter "&input_files";

	%let output_files = /gpfsFS2/sasdata/adhoc/po/imca/product/B2B;
	libname final "&output_files";
	libname archive "&output_files/Archive"; 

	%let production_path= /gpfsFS2/sasdata/nfs/ndc_grid/po_imca_product/B2B;
	libname prod "&production_path";

	%let dt=.; *"11jan2021"d; *leave empty unless running manually;
	%let N=0; *initialize, number of new observations from imported (value dem) dataset;
	%let cancel=;

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

*Create the list of files, in this case all XLSX files;
	options mlogic;
	%list_files(&raw_file_path.,ext=xlsx);

	%let nfiles=0; *initialize;

	proc sql ;
		select 
			count(*)
		,	count(*)
		,	the_name
		into :nfiles,
			 :nfiles_orig,
			 :filename separated by '|' 
		from list
		where find(the_name,'-daily-')>0;
	quit;
	proc delete data=list; run;

	%if &nfiles = 0 %then %do;
		%let error_rsn = No new XLSX files found in input folder.;
		%let cancel=cancel;
	%end;

%if &cancel= and &nfiles > 0 %then %do; /* (1) */

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
			from final.B2B_Twitter_Raw;
		quit;

	/* -------------------------------------------------------------------------------------------------*/
	/*  Import and clean new data.                                                                      */
	/* -------------------------------------------------------------------------------------------------*/

		%let i = 1;

		%macro Append_Import();

			/* social actions = reactions, comments, shares, and follow clicks */
			/* Tweet Engagements: Total number of times a user interacted with a Tweet including 
					Retweets, replies, follows, likes, links, cards, hashtags, embedded media, 
					username, profile photo, or Tweet expansion */

			%do %while (&i <= &nfiles);

				%let filename_loop = %sysfunc(scan(&filename,&i,'|'));
				%put &filename_loop;

				/* saved as xlsx and removed header */
				proc import 
					datafile="&raw_file_path./&filename_loop..xlsx"
					dbms=xlsx
					out=raw replace;
				run;

				data twitter.twitter_clean_&i.; 
					format  'Time period'n mmddyy10.    		'Funding source name'n $100.            
   						    'Campaign name'n $100.				Objective $25.
							'Ad name'n $100.					'Ad Group name'n $50.
							'Tweet publish date'n mmddyy10.		'Tweet status'n $50.
						   	'Card name'n $100.   				'Tweet Text'n	$500.	                  
						    Spend dollar8.2						Impressions comma10.
							'Link clicks'n 8.					'Tweet engagements'n 8. 
							Likes 8.							Retweets_Num 8.
						    Replies_Num 8.         				Votes 8.           
							Follows_Num 8.						Unfollows 8.
                            Downloads 8.						'Sign ups'n 8.	  					       
                           	'Card website URL'n $300.;

					keep 'Time period'n
						 'Funding source name'n
						 'Campaign name'n
						 Objective
						 'Ad name'n
						 'Ad Group name'n
						 'Tweet publish date'n
						 'Tweet status'n
						 'Card name'n
						 'Tweet Text'n
						 Spend
						 Impressions
						 'Link clicks'n
						 'Tweet engagements'n
						 Likes
						 Retweets_Num
						 Replies_Num
						 Votes
						 Follows_Num
						 Unfollows
						 Downloads
						 'Sign ups'n
						 'Card website URL'n
/*						 Placement*/
/*						 'Campaign ID'n*/
/*						 'Ad Group ID'n*/
/*						 'Display creative'n*/
/*						 'Display creative status'n*/
/*						 'Video creative'n*/
/*						 'In-stream video status'n*/
/*						 'In-stream video duration'n*/
/*						 'Ad preview'n*/
/*						 'Ad type'n*/
/*						 'In-stream video type'n*/
						 ;

					set raw;

					Retweets_Num=input(Retweets,8.);
					Replies_Num=input(Replies,8.);
					Follows_Num=input(Follows,8.);
					Drop Retweets 
						 Replies
						 Follows;

					rename
						 'Time period'n = Date
						 'Tweet Text'n = Ad_Text
						 'Ad name'n = Ad_Name
						 'Tweet status'n = Tweet_Status
						 'Tweet publish date'n = Tweet_Publish_Date
						 'Funding source name'n = Funding_Source_Name
						 'Campaign name'n = Campaign_Name
						 Objective = Campaign_Objective
						 'Card name'n = Card_Name
						 'Ad Group name'n = Audience
						 'Link clicks'n = Clicks
						 'Tweet engagements'n = Total_Engagements
						 Retweets_Num = Retweets
						 Replies_Num = Replies
						 Follows_Num = Follows
						 'Sign ups'n = Pri_Contacts_All
						 Downloads = Pri_Downloads_All
						 'Card website URL'n = Click_URL
						 ;
					
				run;

				%if &i=1 %then %do;
					data twitter.twitter_clean;
						set twitter.twitter_clean_&i.;
					run; 
				%end;
				%else %do;
					data twitter.twitter_clean;
						set twitter.twitter_clean_&i.
							twitter.twitter_clean;
					run;
				%end;

				/* -------------------------------------------------------------------------------------------------*/
				/*  Save input file --> zip archive.                                                                */
				/* -------------------------------------------------------------------------------------------------*/
				
				ods package(archived) open nopf;
				ods package(archived) add file="&raw_file_path./&filename_loop..xlsx";
				ods package(archived) publish archive properties (
					archive_name="&filename_loop..zip"
					archive_path="&input_files/Raw Twitter Ads Extracts/Archive/");
				ods package(archived) close;

				filename import "&raw_file_path./&filename_loop..xlsx";
				data _null_;
					rc=fdelete("import");
					put rc=;
				run;
				proc delete data=twitter.twitter_clean_&i.; run;
				proc delete data=raw; run;

				/* -------------------------------------------------------------------------------------------------*/
				/*  Loop.                                                                                           */
				/* -------------------------------------------------------------------------------------------------*/

				%let i=%eval(&i+1);
				%put &i;

			%end; /* end loop through input files */
		%mend;
		%Append_Import;

	%check_for_data(twitter.twitter_clean,=0,No records in twitter_clean);

%end; /* (1) */
%if &cancel= %then %do; /* (2) */

	/* -------------------------------------------------------------------------------------------------*/
	/*  Clean raw Twitter data.                                                                         */
	/* -------------------------------------------------------------------------------------------------*/

		data twitter.twitter_clean_final
			 zero_values;

			retain	
				Date
				WeekStart
				Month
				Quarter
				Funding_Source_Name
				Campaign_Objective
				Tweet_Publish_Date
				Business_Size
				Theme
				Audience
				Ad_Format
				Region
				SubRegion
				Campaign
				Creative
				Image
				Spend
				Impressions
				Clicks
				Total_Engagements 
				Total_Social_Actions
				Likes
				Retweets
				Replies
				Votes
				Follows
				Unfollows
				Pri_Downloads_All 
				Pri_Contacts_All
/*				Sec_Downloads_All*/ /* "Custom" */
/*				Pri_Downloads_PC*/ /* "Downloads" "engage" */
/*				Pri_Downloads_VT*/ /* "Downloads" "view" */
/*				Pri_Contacts_PC*/ /* "Sign ups" "engage" */
/*				Pri_Contacts_VT*/ /* "Sign ups" "view" */
/*				Sec_Downloads_PC*/ /* "Custom" "engage" */
/*				Sec_Downloads_VT*/ /* "Custom" "view" */
				Ad_Text
				Click_URL
				Ad_Name_Orig
				Tweet_Status
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

			set look;
			*twitter.twitter_clean;

			Do_Not_Join_to_GA_Flag = 0;

			* Cleaning;
			Ad_Text=Compress(Ad_Text,'0D0A'x);
			Ad_Text=tranwrd(Ad_Text,'0D0A'x,'');
			if Tweet_Status in ('Deleted','Paused') then delete;

			* Derived;
			Total_Social_Actions = sum(coalesce(Likes,0)+
										coalesce(Retweets,0)+
										coalesce(Replies,0)+
										coalesce(Votes,0)+
										coalesce(Follows,0)+
										coalesce(Unfollows,0));

			* Month;
			WeekStart=intnx('week',Date,0,'b');
			Month=intnx('month',Date,0,'b');
			Quarter=catt('Q',qtr(date));

			* Business Size;
			Business_Size = 'LG';

			* Only keep new data;
/*			if (Business_Size = 'LG' and Date <= "&LastData_OldNum"d)*/
/*				or (Business_Size = 'SB' and Date <= "&LastData_OldNum_SB"d*/
/*				)*/
/*				then delete;*/

			* Region / SubRegion;
			Region_temp = upcase(scan(Campaign_Name,2,'_'));
			if Region_temp = 'SCAL' then Region = 'SCAL';
				else if Region_temp = 'NCAL' then Region = 'NCAL';
				else if Region_temp = 'WA' then Region = 'KPWA';
				else if Region_temp = 'NW' then Region = 'PCNW';
				else if Region_temp = 'GA' then Region = 'GRGA';
				else if Region_temp = 'CO' then Region = 'CLRD';
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
				*Utm_Term = substr(Utm_Term,1,index(Utm_Term,'&')-1);
			Click_URL = substr(Click_URL,1,index(Click_URL,'?')-1);

			* Audience;
			Audience_orig = Audience;
			if find(Ad_Name,'_Exec_','i')>0 then Audience = 'Executives';
				else if find(Ad_Name,'_HR_','i')>0 then Audience = 'HR';
			if Audience_orig = 'MySocialDatabase' then Audience = catt(Audience,'-MSD');
			drop Audience_orig;

			* Ad_Format;
			Ad_Format = scan(Ad_Name,-1,'_');

			* Theme;
			rename Ad_Name = Ad_Name_Orig;
			drop Campaign_Name /* has dupes */
				 Card_Name /* identical to Ad_Name */;
			if find(UTM_Campaign,'rtw|','i')>0 then Theme = 'Return to Work';
				else if find(UTM_Campaign,'vc|','i')>0 then Theme = 'Virtual Care';
				else if find(UTM_Campaign,'mhw|','i')>0 then Theme = 'Mental Health & Wellness';

			* Creative & Image;
			Creative = propcase(scan(UTM_Campaign,3,'|'));
			if Theme = 'Return to Work' then do;
				if find(Audience,'HR','i')>0 then do;
					Creative = 'Return to Work';
					Image = 'Apple';
					end;
				else do; 
					Creative = 'Return to Work';
					Image = 'Hallway';
					end;
				end;
			else if Theme = 'Virtual Care' then do;
				if find(Audience,'HR','i')>0 then do;
					if Creative = 'Statistic' then Image = 'Woman1';
					else Image = 'Man1';
					end;
				else do;
					if Creative = 'Statistic' then Image = 'Woman2';
					else Image = 'Man2';
					end;
				end;
			else if Theme = 'Mental Health & Wellness' then do;
				if find(Audience,'HR','i')>0 then do;
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
			Campaign = catx('_','Twitter',Business_size,Compress(Theme),Audience);

			* Flag non-joinable (GA) records due to tagging errors;
				* Some SCAL ads were tagged as NCAL;
				if Funding_Source_Name = 'KP_SCal_B2B campaign (T2082372)'
					and UTM_Source = 'lg-ncal-prospect'
					then Do_Not_Join_to_GA_Flag = 1;
				
			* Remove empty rows;
			if (Spend > 0 or Impressions > 0 
					or Pri_Downloads_all>0 or Pri_Contacts_All>0 /*or Sec_Downloads_All>0*/) 
				then output twitter.twitter_clean_final;
				else output zero_values;

		run;

		proc sql ;
			select distinct count(*)
			into :Nmiss
			from zero_values;

			select distinct count(*)
			into :N
			from twitter.twitter_clean_final;
		quit;

		%check_for_data(twitter.twitter_clean_final,=0,No records in twitter_clean_final);

		proc sql noprint;
			create table check_dups as
			select 
				t1.* , t2.ndups
			from twitter.twitter_clean_final t1
				, (select 
						date, campaign, utm_source, utm_medium, utm_campaign, utm_content, utm_term, count(*) as ndups
				   from twitter.twitter_clean_final
				   where Do_Not_Join_to_GA_Flag = 0 /* IMPORTANT */
				   group by date, campaign, utm_source, utm_medium, utm_campaign, utm_content, utm_term
				   ) t2
			where t2.ndups>1 
				and t1.date=t2.date 
				and t1.Campaign=t2.Campaign /* Twitter campaign */
				and t1.utm_source=t2.utm_source 
				and t1.utm_medium=t2.utm_medium
				and t1.utm_campaign=t2.utm_campaign 
				and t1.utm_content=t2.utm_content 
				and t1.utm_term=t2.utm_term
				and t1.Do_Not_Join_to_GA_Flag = 0 /* IMPORTANT */
			order by t1.date, t1.campaign, t1.utm_source, t1.utm_medium, t1.utm_campaign, t1.utm_content, t1.utm_term;
		quit;

	%check_for_data(check_dups,>0,Dupes in twitter_clean_final);

		proc freq data=twitter.twitter_clean_final; 
		tables date 
				month 
				WeekStart
				quarter
				Tweet_Publish_Date
				Funding_Source_Name
				ad_format
				theme
				campaign
				campaign_objective
				creative
				image
				creative*image
				ad_text
				business_size		
				region*subregion
				audience
				Do_Not_Join_to_GA_Flag
				utm_source
				utm_medium
				utm_campaign
				utm_content
				utm_term
				utm_source*region
				utm_campaign*audience
				utm_campaign*creative
				utm_term*Ad_Format
				utm_campaign*ad_text

				Ad_Name_Orig*theme
				Ad_Name_Orig*creative
				Ad_Name_Orig*image
				 / nocol norow nopercent;
		run;

		proc delete data=twitter.twitter_clean; run &cancel.;

%end; /* (2) */
%if &cancel= %then %do; /* (3) */

	/* -------------------------------------------------------------------------------------------------*/
	/*  Export and archive raw twitter.                                                                 */
	/* -------------------------------------------------------------------------------------------------*/

		data twitter.B2B_Twitter_Raw_Temp;
			set final.B2B_Twitter_Raw;
		run;
		
		proc sql;
		insert into final.B2B_Twitter_Raw
			select distinct 
				* 
			/* Archived Fields */
			from twitter.twitter_clean_final;
		quit;

	* If you added/removed or changed the formatting of a variable, run this instead;

/*		proc delete data=final.B2B_Twitter_Raw; run;*/
/*		data final.B2B_Twitter_Raw;*/
/*			set twitter.twitter_clean_final*/
/*				twitter.B2B_Twitter_Raw_Temp; */
/*		run;*/

	/* -------------------------------------------------------------------------------------------------*/
	/*  Save master file --> zip archive.                                                               */
	/* -------------------------------------------------------------------------------------------------*/

		proc sql ;
			select
				min(month) format mmddyy6.,
				max(Date) format mmddyy6.,
				max(Date) format date9.
			into :FirstData_Raw,
				 :LastData,
				 :LastDate_ThisUpdate
			from final.B2B_Twitter_Raw;
		quit;

		data archive.B2B_Twitter_Raw_&FirstData_Raw._&LastData;
			set final.B2B_Twitter_Raw;
		run;

		ods package(archived) open nopf;
		ods package(archived) add file="&output_files/Archive/b2b_twitter_raw_&FirstData_Raw._&LastData..sas7bdat";
		ods package(archived) publish archive properties (
			archive_name="b2b_twitter_raw_&FirstData_Raw._&LastData..zip"
			archive_path="&output_files/Archive/");
		ods package(archived) close;

		filename old_arch "&output_files/Archive/b2b_twitter_raw_&FirstData_Raw._&LastData_Old..zip";
		data _null_;
			rc=fdelete("old_arch");
			put rc=;
		run;
%end; /* (3) */
%if &cancel= %then %do; /* (4) */

/* -------------------------------------------------------------------------------------------------*/
/*                                                                                                  */
/*                                                                                                  */
/*                                    Prepare for Campaign Dataset                                  */
/*                                                                                                  */
/*                                                                                                  */
/* -------------------------------------------------------------------------------------------------*/

/* -------------------------------------------------------------------------------------------------*/
/*  Engine metrics from newly-added b2b_twitter_raw.                                                */
/* -------------------------------------------------------------------------------------------------*/

	%let error_rsn=Error compiling engine metrics.;

	proc sql;
		create table twitter as
			select distinct
				Date format mmddyy10.
			,	WeekStart format mmddyy10.
			,	Month format monyy7. 
			,	Quarter format $2.
			,	'Social' as Channel format $25.
			,	case when Business_Size = 'LG' then 'Social-Twitter B2B' 
				     when Business_Size = 'SB' then 'Social-Twitter SBU'
					end as ChannelDetail format $25.
			,	sum(Impressions) as Impressions format comma18.
			,	sum(Clicks) as Clicks format comma8.
			,	sum(Spend) as Spend format dollar18.2
			, 	sum(Total_Engagements) as Total_Engagements format comma8.
			,	sum(Total_Social_Actions) as Total_Social_Actions format comma8. 
			,	sum(Pri_Downloads_All) as Primary_Downloads format comma8. 
			,	sum(Pri_Contacts_All) as Primary_Contacts format comma8. 
			,	0 as Secondary_Downloads format comma8. 
			,	tranwrd(Campaign,'-MSD','') as Campaign format $250. /* UTM tags are not at the ABM level */
			,	'Twitter' as Network format $25.
			,	Region format $5.
			,	SubRegion format $5.
			,	'Value Demonstration' as Program_Campaign format $30.
			,	Theme format $50.
			,	Creative format $200.
			,	Image format $30.
			,	Ad_Format format $15.
			,	tranwrd(Audience,'-MSD','') as Audience format $50.
				/* Join Metrics */
			,	UTM_Source
			,	UTM_Medium
			,	UTM_Campaign
			,	UTM_Content
			,	UTM_Term 
			,	Do_Not_Join_to_GA_Flag
			from twitter.twitter_clean_final
			group by 
				Date 
			,	case when Business_Size = 'LG' then 'Social-LinkedIn B2B' 
				     when Business_Size = 'SB' then 'Social-LinkedIn SBU'
					end 			
			,	tranwrd(Campaign,'-MSD','') 
			,	Region 
			,	SubRegion
			,	Theme 
			,	Creative 
			,	Image 
			,	Ad_Format 
			,	tranwrd(Audience,'-MSD','') 
			,	UTM_Source
			,	UTM_Medium
			,	UTM_Campaign
			,	UTM_Content
			,	UTM_Term 
			,	Do_Not_Join_to_GA_Flag
			; 
	quit;

	data twitter_ready_to_join(drop=Do_Not_Join_to_GA_Flag)
		 twitter_do_not_join(drop=Do_Not_Join_to_GA_Flag rename=(UTM_Content=PromoID));
		set twitter;

		if Do_Not_Join_to_GA_Flag=1 then output twitter_do_not_join;
			else output twitter_ready_to_join;
	run;

	%check_for_data(twitter_ready_to_join,=0,No records in twitter_ready_to_join);
	
	proc sql;
		create table check_dups as
		select 
			t1.* , t2.ndups
		from twitter_ready_to_join t1
			, (select 
					date, utm_source, utm_medium, utm_campaign, utm_content, utm_term, count(*) as ndups
			   from twitter_ready_to_join
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

	%check_for_data(check_dups,>0,Dupes in twitter_ready_to_join);
	
%end; /* (4) */
%if &cancel= %then %do; /* (5) */
	
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
		from twitter_ready_to_join;
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
			where lowcase(UTM_Medium) = 'twitter'
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

		data better_way_ready_to_join
			 better_way_do_not_join;
			set better_way;

			*if UTM_Source = 'pr-comms' then delete; 

			/* 2021 Q4 some SCAL ads were tagged as NCAL */
			if utm_source ne 'lg-ncal-prospect' then output better_way_ready_to_join; 
				else output better_way_do_not_join;

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
%end; /* (5) */
%if &cancel= %then %do; /* (6) */

	/* -------------------------------------------------------------------------------------------------*/
	/*  Merge engine metrics with Google Analytics metrics                                              */
	/* -------------------------------------------------------------------------------------------------*/

		%let error_rsn=Error merging tables.;

		proc sort data=better_way_ready_to_join; by date utm_source utm_medium utm_campaign utm_content utm_term; run;
		proc sort data=twitter_ready_to_join; by date utm_source utm_medium utm_campaign utm_content utm_term; run;

		data twitter.campaign_merged(drop=UTM: Lookup)
			 missing
			 otherlob(drop=Lookup); 

			merge twitter_ready_to_join (in=a)
				  better_way_ready_to_join (in=b);
			by date utm_source utm_medium utm_campaign utm_content utm_term;

			* Halo flag initialize;
			Halo_Actions = 0;

			if PromoID = '' then PromoId = UTM_Content;

			if a then output twitter.campaign_merged;

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
				if LOB_temp = 'LG' then ChannelDetail = 'Social-Twitter B2B';
					else if LOB_temp = 'SB' then ChannelDetail = 'Social-Twitter SBU';
				drop LOB_temp;

				* Program_Campaign;
				Program_Campaign='Value Demonstration';

				* Network;
				Network='Twitter';

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
				Ad_Format = Utm_term;

				* Campaign;
				Campaign = catx('_','Twitter',upcase(scan(UTM_Source,1,'-')),Compress(Theme),Audience);

				output missing;
			end;

				else do; /* ?? */

					output otherlob;
	
				end;

			end;

		run;	

		%let error_rsn=Error appending tables.;

		data twitter.b2b_campaign_master_twitter(drop=UTM:);

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
					Ad_Format $15. 
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
			
				;
		 	set twitter.campaign_merged(in=a)
				missing(in=b)
				otherlob(in=c)
				twitter_do_not_join(in=d)
				better_way_do_not_join(in=e);

			VideoStarts=.;
			VideoCompletions=.;
			Keyword='N/A';
			Match_Type='N/A';
			Remarketing='N/A';
			Keyword_Category='N/A';
			Leads=.;
			Lead_Forms_Opened=.;
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
				if LOB_temp = 'LG' then ChannelDetail = 'Social-Twitter B2B';
					else if LOB_temp = 'SB' then ChannelDetail = 'Social-Twitter SBU';
				drop LOB_temp;

				* Program_Campaign;
				Program_Campaign='Value Demonstration';

				* Network;
				Network='Twitter';

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
					Ad_Format = Utm_term;

					* Campaign;
					Campaign = catx('_','Twitter',upcase(scan(UTM_Source,1,'-')),Compress(Theme),Audience);

				end;

			end;

		run;

		proc sql;
			select distinct
				sum(spend) as spend format dollar18.2
			,	sum(impressions) as impressions format comma18.
			,	sum(clicks) as clicks format comma18.
			,	sum(total_engagements) as total_engagements format comma18.
			,	sum(goal7_learn+goal8_shop) as ga_actions_old format comma8.
			,	sum(convertsubmit_contact+convertsubmit_quote) as ga_leads format comma8.
			,	sum(sessions) As sessions format comma8.
			into :spend_final trimmed,
				 :impr_final trimmed,
				 :clicks_final trimmed,
				 :engagements_final trimmed,
				 :actions_old_final trimmed,
				 :leads_final trimmed,
				 :sessions_final trimmed
			from twitter.b2b_campaign_master_twitter;

			select distinct
				sum(spend) as spend format dollar18.2
			,	sum(impressions) as impressions format comma18.
			,	sum(clicks) as clicks format comma18.
			,	sum(total_engagements) as total_engagements format comma18.
			into :spend_orig trimmed,
				 :impr_orig trimmed,
				 :clicks_orig trimmed,
				 :engagements_orig trimmed
			from twitter.twitter_clean_final;

			select distinct
				sum(goal7_learn+goal8_shop) as ga_actions_old format comma8.
			,	sum(convertsubmit_contact+convertsubmit_quote) as ga_leads format comma8.
			,	sum(sessions) As sessions format comma8.
			into :actions_old_orig trimmed,
				 :leads_orig trimmed,
				 :sessions_orig trimmed
			from better_way;
		quit;
/*		%if %eval(:spend_final ne :spend_orig)*/
/*			or %eval(:impr_final ne :impr_orig)*/
/*			or %eval(:clicks_final ne :clicks_orig)*/
/*			%then %do;*/
/*				%put ERROR: Data missing in B2B_campaign_master_twitter;*/
/*				%let cancel=cancel;*/
/*			%end;*/

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
			from twitter.b2b_campaign_master_twitter
			group by 
				WeekStart
			,	Halo_Actions
			order by	
				Halo_Actions
			,	WeekStart;
		quit;	

		proc freq data=twitter.b2b_campaign_master_twitter; 
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

		%check_for_data(linkedin.b2b_campaign_master_linkedin,=0,No records in linkedin.b2b_campaign_master_linkedin);

%end; /* (6) */
%if &cancel= %then %do; /* (7) */

	/* -------------------------------------------------------------------------------------------------*/
	/*  Export and archive.                                                                             */
	/* -------------------------------------------------------------------------------------------------*/

		data twitter.B2B_Campaign_Master_Temp;
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
			from twitter.b2b_campaign_master_twitter;
		quit;

	* If you added/removed or changed the formatting of a variable, run this instead;

/*		proc delete data=prod.B2B_Campaign_Master; run;*/
/*		data prod.B2B_Campaign_Master;*/
/*			set twitter.b2b_campaign_master_twitter */
/*				twitter.B2B_Campaign_Master_Temp;*/
/*			Rec_Update_Date = datetime(); */
/*		run;*/

	/* -------------------------------------------------------------------------------------------------*/
	/*  Save master file --> zip archive.                                                               */
	/* -------------------------------------------------------------------------------------------------*/

		proc sql ;
			select
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
		proc delete data=twitter.b2b_campaign_master_temp; run;
		* Second backup of b2b_linkedin_raw;
		ods package(archived) open nopf;
		ods package(archived) add file="&input_files/b2b_linkedin_raw_temp.sas7bdat";
		ods package(archived) publish archive properties (
			archive_name="b2b_twitter_raw_temp.zip"
			archive_path="&input_files/");
		ods package(archived) close;
		proc delete data=twitter.b2b_twitter_raw_temp; run;
		* Delete files from most recent update;
		proc delete data=twitter.twitter_clean_final; run;
		proc delete data=twitter.campaign_merged; run;
		proc delete data=twitter.b2b_campaign_master_twitter; run;

/*			proc delete data=archive.B2B_Twitter_Raw_&FirstData_Raw._&LastData; run;*/
/*			proc delete data=archive.B2B_Campaign_&FirstData._&LastData; run;*/
	/* -------------------------------------------------------------------------------------------------*/
	/*  Frequency Tables.                                                                               */
	/* -------------------------------------------------------------------------------------------------*/ 

		options dlcreatedir;
		libname freq xlsx "&input_files/Frequency Tables - Get_Twitter_Data_Weekly.xlsx"; run;
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
			where find(ChannelDetail,'Social-Twitter')>0
				and Date>=intnx('day',"&Campaign_StartDate"d,-7,'s')
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
			where find(ChannelDetail,'Social-Twitter')>0
				and Date>=intnx('day',"&Campaign_StartDate"d,-7,'s')
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
			where find(ChannelDetail,'Social-Twitter')>0
				and Date>=intnx('day',"&Campaign_StartDate"d,-7,'s')
			group by 
				Region
			,	case when Date>="&Campaign_StartDate"d then 1 else 0 end 
			order by 
				Region
			,	case when Date>="&Campaign_StartDate"d then 1 else 0 end;
		quit;

%end; /* if &N > 0 */

/* -------------------------------------------------------------------------------------------------*/
/*  Email log.                                                                                      */
/* -------------------------------------------------------------------------------------------------*/ 
%let sentTo = ('elsa.c.haynes@kp.org','chad.x.hollingsworth@kp.org','andem.x.likitha@kp.org','praveen.x.thummidi@kp.org',
				'smriti.malla@kp.org', 'niki.z.petrakos@kp.org');

%macro ab2;

	%if &N>0 %then %do;

		proc sql noprint;
		select count(*) into :n trimmed from final.B2B_Twitter_Raw where Date >= "&Campaign_StartDate"d;
		select count(*) into :n2 trimmed from prod.B2B_Campaign_Master where find(ChannelDetail,'Social-Twitter')>0 and Date >= "&Campaign_StartDate"d;
		quit;

		%let attach1=%str(&input_files/Frequency Tables - Get_Twitter_Data_Weekly.xlsx);
/*		%let attach2=%str(&input_files/LOG Get_LinkedIn_Data_Weekly.txt);*/

		%if &n>0 %then %do;

			filename outbox email 'elsa.c.haynes@kp.org';

			data _null_;
			file outbox

			 /* Overrides value in filename statement */
			to=(##MASKED##)
			subject=" SUCCESSFUL: Exec Get_Twitter_Data_Weekly Manual Process"
			attach=("&attach1." CT="APPLICATION/MSEXCEL" EXT="xlsx"
/*					"&attach2." CT="text/plain" EXT="txt"*/
					)
			;
			put "Between &Campaign_StartDate and &Campaign_EndDate.: &n rows were added to b2b_twitter_raw and &n2 rows were added to b2b_campaign_master.";
			put " ";

			run;

		%end;

	%end;

	%else %if &N=0 %then %do;

			filename outbox email 'elsa.c.haynes@kp.org';

			data _null_;
			file outbox
			 /* Overrides value in filename statement */
			to=(##MASKED##)
			subject=" FAILURE: Exec Get_Twitter_Data_Weekly Manual Process"
/*			attach=("&attach2." CT="text/plain" EXT="txt")*/
			;
			put "&error_rsn.";
			put " ";

			run;

	%end;

	%else %do;

			filename outbox email 'elsa.c.haynes@kp.org';

			data _null_;
			file outbox

			 /* Overrides value in filename statement */
			to=(##MASKED##)
			subject=" FAILURE: Exec Get_LinkedIn_Data_Weekly Monday 11:00PM"
/*			attach = ("&attach2." CT="text/plain" EXT="txt")*/
			;
			put "Unknown reason.";
			put " ";

			run;

	%end;

%mend;
%ab2;

proc printto; run; /* Turn off log export to .txt */