
/* -------------------------------------------------------------------------------------------------*/
/*  Libraries                                                                                       */
/* -------------------------------------------------------------------------------------------------*/

	* Input;
	%include '/gpfsFS2/home/c156934/password.sas';
	libname MARS sqlsvr DSN='SQLSVR4685' SCHEMA='dbo' user="CS\C156934" password="&winpwd"
	     qualifier='MARS' readbuff=5000 insertbuff=5000 dbcommit=1000; run;
	libname WS sqlsvr datasrc='WS_NYDIA' SCHEMA='dbo' user="CS\C156934" password="&winpwd"
	     qualifier='WS_EHAYNES' readbuff=5000 insertbuff=5000 dbcommit=1000; run;
	libname ESRI sqlsvr DSN='WS_NYDIA' SCHEMA='dbo' user="CS\C156934" password="&winpwd"
	     qualifier='ESRI_TAPESTRY' readbuff=5000 insertbuff=5000 dbcommit=1000; run;
	libname ELARA sqlsvr DSN='SQLSVR4656' SCHEMA='dbo' user="CS\C156934" password="&winpwd"
     	qualifier='ELARA' readbuff=5000 insertbuff=5000 dbcommit=1000; run;

/* -------------------------------------------------------------------------------------------------*/
/*  Set variables specific to this scoring                                                          */
/* -------------------------------------------------------------------------------------------------*/

	%let Campaign_year = 2023;
	%let SQL_TblNm_Agilities = KPIF_EM_23_Scoring_Pop;
	%let Scoring_Folder_Nm = Scoring_092022;
	%let Model_Number = 200; 
	%let Model_Name = NATIONAL KPIF OE EM ENROLLMENT MODEL;

	* Output;
	%let output_files = /gpfsFS2/sasdata/nfs/ndc_grid/po_imca_digital/EHaynes/__Models/KPIF_EmailTargeting_2022;
	%let output_files = &output_files./&Scoring_Folder_Nm.;
	libname output "&output_files";

/* -------------------------------------------------------------------------------------------------*/
/*  Marketable Individuals                                                                          */
/* -------------------------------------------------------------------------------------------------*/

	* Processed by Sang on 9/8/22 and uploaded to SQL Server;

	data output.t1_marketable_pop;
		set WS.&SQL_TblNm_Agilities.;
	run;

	proc sql;
		create index aglty_indiv_id on output.t1_marketable_pop;
	quit;

/* -------------------------------------------------------------------------------------------------*/
/*  Address                                                                                         */
/* -------------------------------------------------------------------------------------------------*/

	proc sql;
	CREATE TABLE output.t2_Address AS
	SELECT DISTINCT
		ia.AGLTY_INDIV_ID
	,	CASE WHEN ia.ADDR_TYPE_CD='PR' AND ia.PRIM_ADDR_IND='Y' THEN 1 ELSE 0 END AS Prim_Addr_Flag
	,	a.ZIP_CD
	,	a.ZIP4_CD
	,	g.GEOCODE
	,	g.COUNTYFIPS
	FROM MARS.INDIVIDUAL_ADDRESS ia
	LEFT JOIN MARS.ADDRESS a
		ON ia.AGLTY_ADDR_ID=a.AGLTY_ADDR_ID
	LEFT JOIN MARS.GEOCODE_LKUP g
		ON a.AGLTY_ADDR_ID=g.AGLTY_ADDR_ID
	WHERE ia.AGLTY_INDIV_ID IN (SELECT AGLTY_INDIV_ID FROM output.t1_marketable_pop);
	quit;

	* De-dupe to 1 address per individual;
	proc sort data=output.t2_Address; 
		by AGLTY_INDIV_ID 
			descending Prim_Addr_Flag 
			descending geocode; 
	run;
	data output.t2_Address(drop=Prim_Addr_Flag);
		set output.t2_Address;
		by AGLTY_INDIV_ID 
			descending Prim_Addr_Flag 
			descending geocode; 

		ZIP_CD_NUM = input(ZIP_CD,8.);
		ZIP4_NUM = input(ZIP4_CD,8.);
		drop ZIP_CD ZIP4_CD;
		rename ZIP_CD_NUM = ZIP_CD
			   ZIP4_NUM = ZIP4_CD;

		if first.AGLTY_INDIV_ID then output;
	run;

	proc sql;
	CREATE TABLE output.t2_Address AS
	SELECT DISTINCT
		x.*
	,	zip.CNTY_NM
	,	zip.CITY_NM
	,	zip.ST_CD
	,	zip.REGN_CD
	,	zip.SUB_REGN_CD
	,	zip.SVC_AREA_NM 
	FROM output.t2_Address x
	LEFT JOIN MARS.ZIP_LEVEL_INFO zip
		ON x.ZIP_CD=input(zip.ZIP_CD,8.)
		AND x.ZIP4_CD BETWEEN input(zip.ZIP4_START_CD,8.) AND input(zip.ZIP4_END_CD,8.)
		AND zip.YR_NBR=&Campaign_year.;
	quit;

	/* need to fill in missing zip code information. */

	data output.t2_Address;
		format Region $4.;
		set output.t2_Address;
		* Clean;
		if CNTY_NM = 'PRINCE GEORGES' then CNTY_NM = "PRINCE GEORGE'S";
		Region = REGN_CD;
		if REGN_CD = 'MR' then Region = 'MAS';
		else if REGN_CD = 'CA' then Region = SUB_REGN_CD;
	run;

			* Match % on Geocode: 99.9%;
			proc sql;

			title 'Geocode match rate';
			SELECT DISTINCT
				COUNT(DISTINCT CASE WHEN GEOCODE IS NOT MISSING THEN y.AGLTY_INDIV_ID END)/
					COUNT(DISTINCT x.AGLTY_INDIV_ID) AS PCT_MATCH_Geocode format percent7.2
			FROM output.t1_marketable_pop x
			LEFT JOIN output.t2_Address y
				on x.AGLTY_INDIV_ID=y.AGLTY_INDIV_ID;

			quit;

/* -------------------------------------------------------------------------------------------------*/
/*  Demographics                                                                                    */
/* -------------------------------------------------------------------------------------------------*/

	proc sql;

	CREATE TABLE kbm AS
	SELECT DISTINCT
		AGLTY_INDIV_ID
	,	CENS_BLUE_CLLR_PCT
	,	CENS_INCM_PCTL_CD
	,	CENS_MED_HH_INCM_CD
	,	CENS_MED_HOME_VAL_CD
	,	HMOWN_STAT_CD
	,	case when AGLTY_INDIV_ID is not missing then 1 else 0 end as KBM_Flag
	FROM MARS.INDIVIDUAL_KBM_PROSPECT
	WHERE AGLTY_INDIV_ID IN (SELECT AGLTY_INDIV_ID FROM output.t1_marketable_pop);

	CREATE TABLE indiv AS
	SELECT DISTINCT
		AGLTY_INDIV_ID
	,	HH_HEAD_IND
	,	REC_INS_DT
	FROM MARS.INDIVIDUAL
	WHERE AGLTY_INDIV_ID IN (SELECT AGLTY_INDIV_ID FROM output.t1_marketable_pop);

	quit;

	proc sql;

	CREATE TABLE output.t3_Demog AS
	SELECT DISTINCT
		i.AGLTY_INDIV_ID
	,	case when HH_HEAD_IND = 'Y' then 1 else 0 end as HH_HEAD_FLAG
	,	case when floor(datdif(REC_INS_DT,'22OCT2022'd,'ACT/ACT')/365)>=0
			 then floor(datdif(REC_INS_DT,'22OCT2022'd,'ACT/ACT')/365)
			 else .
			 end as DATA_AGE_YEARS
	,	CENS_BLUE_CLLR_PCT	
	,	input(CENS_INCM_PCTL_CD,8.) as CENS_INCM_PCTL
	,	input(CENS_MED_HH_INCM_CD,8.)/10 as CENS_MED_HH_INCM_10k
	,	input(CENS_MED_HOME_VAL_CD,8.)/10 as CENS_MED_HOME_VAL_10k
	,	case when HMOWN_STAT_CD in ('P','Y') then 'OWN'
			 when HMOWN_STAT_CD in ('R','T') then 'RENT'
			 else 'UNKNOWN'
			 end as MODEL_OWN_RENT
	,	coalesce(KBM_Flag,0) as KBM_Flag
	FROM indiv i
	LEFT JOIN kbm k
		ON i.AGLTY_INDIV_ID=k.AGLTY_INDIV_ID;

	quit;

			* Match % on KBM: 31.9%;
			proc sql;

			title 'KBM match rate';
			SELECT DISTINCT
				SUM(KBM_Flag)/
				COUNT(DISTINCT x.AGLTY_INDIV_ID) AS PCT_MATCH_KBM format percent7.2
			FROM output.t1_marketable_pop x
			LEFT JOIN output.t3_Demog y
				on x.AGLTY_INDIV_ID=y.AGLTY_INDIV_ID;
			title;

			quit;

/* -------------------------------------------------------------------------------------------------*/
/*  Elara                                                                                           */
/* -------------------------------------------------------------------------------------------------*/

	* Get email address for each agility;
	proc sql;
	create table output.appended_emails as 
	select distinct
		AGLTY_INDIV_ID
	,	lowcase(EMAIL_ADDR_TXT) as EMAIL_ADDR_TXT
	from MARS.INDIVIDUAL
	where AGLTY_INDIV_ID in (select AGLTY_INDIV_ID from output.t1_marketable_pop); 
	quit;

	proc sql;
	create table asset_names as
	select distinct
		ASSET_NAME
	from ELARA.ELOQUA_CONTACT_ACTIVITY
	where find(ASSET_NAME,'Cnsmr_Acq_KPIF_OE')>0;
	quit;
	proc sql;
	create table asset_name_date as
	select distinct
		ASSET_NAME
	,	year(datepart(ACTIVITY_DATE)) as year
	,	month(datepart(ACTIVITY_DATE)) as month
	from ELARA.ELOQUA_CONTACT_ACTIVITY
	where ASSET_NAME in (select ASSET_NAME from asset_names)
		and activity_type = 'EmailSend'
		and year(datepart(ACTIVITY_DATE))>=2021;
	quit;
	data asset_names;
		set asset_names;
		where find(ASSET_NAME,'Cnsmr_Acq_KPIF_OE9')>0;
	run;

	proc sql;
	create table output.email_activity1 as
	select distinct
		EMAIL_ADDRESS
	,	ASSET_NAME
	,	ACTIVITY_DATE as ACTIVITY_DATE_TIME format datetime18.
	,	ACTIVITY_TYPE
	from ELARA.ELOQUA_CONTACT_ACTIVITY
	where ACTIVITY_TYPE in ('EmailOpen','EmailSend') /*'Bounceback','EmailClickthrough','Unsubscribe'*/
		and ASSET_NAME in (select ASSET_NAME from asset_names);
	quit;

	proc sql;
	create table output.email_activity2 as
	select distinct
		EMAIL_ADDR as EMAIL_ADDRESS
	,	MAILING_NAME
	,	ACTIVITY_DATE as ACTIVITY_DATE_TIME format datetime18.
	,	ACTIVITY_TYPE
	from ELARA.SF_CNTCT_ACTVTY
	where ACTIVITY_TYPE in ('EmailOpen','EmailSend') /*'Bounceback','EmailClickthrough','Unsubscribe'*/
		and MAILING_NAME in (select ASSET_NAME from asset_names);
	quit;

	data email_history;
		set output.email_activity1
			output.email_activity2;
	run;

	proc sql;
	create table email_history as
	select distinct
		x.*
	,   y.*
	from EMAIL_HISTORY y 
	inner join OUTPUT.APPENDED_EMAILS x
		on x.EMAIL_ADDR_TXT = y.EMAIL_ADDRESS; 
	quit;

	proc sql;
	create table output.t4_email as
	select distinct
		AGLTY_INDIV_ID
	,	max(case when ACTIVITY_TYPE = "EmailOpen" then 1 ELSE 0 END) AS Email_Open_Flag_PY 
	from email_history
	group by
		AGLTY_INDIV_ID;
	quit;

			proc sql;  /* % of agilities with email history: 21.3% */
			select distinct 
				count(distinct t4.AGLTY_INDIV_ID)/count(distinct t1.AGLTY_INDIV_ID) 
				as Pct_Email FORMAT percent7.2 
			from output.t1_marketable_pop t1
			left join output.t4_email t4
				on t1.AGLTY_INDIV_ID=t4.AGLTY_INDIV_ID;
			quit;

/* -------------------------------------------------------------------------------------------------*/
/*  Tapestry                                                                                        */
/* -------------------------------------------------------------------------------------------------*/

	options mprint;
	%macro split_into_batches(inputTable);
		%let i = 1;
		%let batchNum = 1;
		proc sql; select distinct count(*) into :nRows from &inputTable; quit;
		proc sql; create table InputsCleanTable as select distinct AGLTY_INDIV_ID, GEOCODE from &inputTable; quit;
		%do %while (&i < &nRows);
			data output.Tapestry_Batch_&batchNum;
				set InputsCleanTable;
				if _N_ >= &i and _N_ < %eval(&i+100000);
			run;
			%let i = %eval(&i+100000);
			%let batchNum = %eval(&batchNum+1);
		%end;
		%let batchNumPull = 1;
		%do %while (&batchNumPull <= &batchNum);
			proc sql;

			CREATE TABLE output.tapestry_Batch_&batchNumPull AS
			SELECT DISTINCT
				s.*

			,	100*(tap3.BLK30_CY/tap1.POP30_CY) AS ESRI_Pct_AGE_30_34_B
			,	100*(tap5.ASIAN_CY/tap5.RACEBASECY) AS ESRI_Pct_Tot_ASIAN
			,	100*(tap5.HISPPOP_CY/tap5.RACEBASECY) AS ESRI_Pct_Tot_HISPANIC
			,	100*(tap5.PACIFIC_CY/tap5.RACEBASECY) AS ESRI_Pct_Tot_PAC_ISL
			,	100*(tap11.WHITE_FY/tap11.RACEBASEFY) AS ESRI_Pct_Tot_WHITE_FY
			,	100*(tap11.HISPPOP_FY/tap11.RACEBASEFY) AS ESRI_Pct_Tot_HISPANIC_FY
			,	tap5.AVGHINC_CY/1000 AS ESRI_HHINCOME_AVG_1k
			,	tap5.PCI_CY/1000 AS ESRI_PER_CAPITA_INCOME_1k
			,	taphh.TLIFENAME AS TAPESTRY_LIFESTYLE
			,	taphh.TURBZNAME AS TAPESTRY_URBAN

			FROM output.Tapestry_Batch_&batchNumPull s 
			LEFT JOIN ESRI.CFY20_01 tap1
				ON s.GEOCODE=tap1.ID
			LEFT JOIN ESRI.CFY20_03 tap3
				ON s.GEOCODE=tap3.ID
			LEFT JOIN ESRI.CFY20_05 tap5
				ON s.GEOCODE=tap5.ID
			LEFT JOIN ESRI.CFY20_11 tap11
				ON s.GEOCODE=tap11.ID
			LEFT JOIN ESRI.TAP20_HH taphh
				ON s.GEOCODE=taphh.ID
			;
			quit;

			%let batchNumPull = %eval(&batchNumPull+1);

		%end;
	%mend;

	%split_into_batches(output.t2_address);

	* Export;
	data output.t5_Tapestry;
		set output.tapestry_batch_:;
	run;

/* -------------------------------------------------------------------------------------------------*/
/*  Market Size                                                                                     */
/* -------------------------------------------------------------------------------------------------*/

	proc import
		datafile="&output_files/Scoring Inputs/Market Size Flat File - 1-7-22.xlsx"
		out=Market_Size
		dbms=xlsx replace;
	run;

	data Market_Size;
		set Market_Size;

		where Year in ('2019','2021','2022','2023'); * this year, 1 year ago, 3 years ago, 1 year ahead; *CY = 2023;

		Year_num = input(Year,8.);
		Year_num = Year_num+1;
		drop Year;
		rename Year_num = Year;

		COUNTYFIPS = strip(put('FIPS Code'n,8.));
		if length(COUNTYFIPS)=4 then COUNTYFIPS = cats('0',put('FIPS Code'n,8.));
		if 'FIPS Code'n = . then delete;

		if state = 'California' then state = 'CA';
			else if state = 'Washington' then state = 'WA';
			else if state = 'Oregon' then state = 'OR';
			else if state = 'Hawaii' then state = 'HI';
			else if state = 'Georgia' then state = 'GA';
			else if state = 'Colorado' then state = 'CO';
			else if state = 'Maryland' then state = 'MD';
			else if state = 'Virginia' then state = 'VA';
			else if state = 'Distric of Columbia' then state = 'DC';

		drop 'FIPS Code'n;

	run;
	
	proc sql;
	create table Market_Size as
	select distinct
		COUNTYFIPS
	,	Year
	,	'Major Segment'n as Major_Segment
	,	sum('Covered Lives'n) as Covered_Lives
	from Market_Size
	group by 
		COUNTYFIPS
	,	Year
	,	'Major Segment'n
	order by 
		COUNTYFIPS;
	quit;

	proc sql;
	create table Market_Size_Rollup as
	select distinct
		x.COUNTYFIPS
	,	x.Year
	,	sum(case when x.Major_Segment = 'Individual' then x.Covered_Lives else 0 end)/y.Population as Market_Size_Ind
	,	sum(case when x.Major_Segment = 'Large Group' then x.Covered_Lives else 0 end)/y.Population as Market_Size_B2B
	,	sum(case when x.Major_Segment = 'Small Group' then x.Covered_Lives else 0 end)/y.Population as Market_Size_SBU
	,	sum(case when x.Major_Segment = 'Medicaid' then x.Covered_Lives else 0 end)/y.Population as Market_Size_Medi
	,	sum(case when x.Major_Segment = 'Medicare' then x.Covered_Lives else 0 end)/y.Population as Market_Size_MA
	,	sum(case when x.Major_Segment = 'Uninsured' then x.Covered_Lives else 0 end)/y.Population as Market_Size_Unins
	from Market_Size x
	left join 
		(
		select distinct
			COUNTYFIPS
		,	Year
		,	Covered_Lives as Population
		from Market_Size
		where Major_Segment = 'Population'
		) y
		on x.COUNTYFIPS=y.COUNTYFIPS
		and x.Year=y.Year
	group by 
		x.COUNTYFIPS
	,	x.Year;
	quit;

	* I originally did this wrong, so the modeled magnitude is actually 0.14286*the original/correct magnitude;
	proc sql;
	create table Market_Size_Final as
	select distinct
		x.COUNTYFIPS

	/* CY */
	,	0.14286*x.Market_Size_Ind*100 as Market_Size_Ind
	,	0.14286*x.Market_Size_SBU*100 as Market_Size_SBU
	,	0.14286*x.Market_Size_Medi*100 as Market_Size_Medi

	/* YoY */
	,	0.14286*((y.Market_Size_Ind/x.Market_Size_Ind)-1)*100 as Market_Size_Ind_YOYchg
	,	0.14286*((y.Market_Size_Medi/x.Market_Size_Medi)-1)*100 as Market_Size_Medi_YOYchg
	,	0.14286*((y.Market_Size_Unins/x.Market_Size_Unins)-1)*100 as Market_Size_Unins_YOYchg

	/* 3 years ago */
	,	0.14286*((z.Market_Size_Medi/x.Market_Size_Medi)-1)*100 as Market_Size_Medi_3YRchg
	,	0.14286*((z.Market_Size_Unins/x.Market_Size_Unins)-1)*100 as Market_Size_Unins_3YRchg

	/* 1 year forecast */
	,	0.14286*((zz.Market_Size_B2B/x.Market_Size_B2B)-1)*100 as Market_Size_B2B_FYchg
	,	0.14286*((zz.Market_Size_Unins/x.Market_Size_Unins)-1)*100 as Market_Size_Unins_FYchg
	from Market_Size_Rollup x
	left join Market_Size_Rollup y
		on x.COUNTYFIPS=y.COUNTYFIPS
		and x.Year-y.Year=1 /* 1 year earlier */
	left join Market_Size_Rollup z
		on x.COUNTYFIPS=z.COUNTYFIPS
		and x.Year-z.Year=3 /* 3 years earlier */
	left join Market_Size_Rollup zz
		on x.COUNTYFIPS=zz.COUNTYFIPS
		and x.Year-zz.Year=-1 /* 1 year forecast */
	where x.year = 2023
	order by 
		x.COUNTYFIPS;
	quit;

	proc sql;
	create table output.t6_external_data as
	select distinct
		x.AGLTY_INDIV_ID
	,	y.*
	from output.t1_marketable_pop x
	left join output.t2_address a
		on x.AGLTY_INDIV_ID=a.AGLTY_INDIV_ID
	left join Market_Size_Final y
		on a.COUNTYFIPS=y.COUNTYFIPS;
	quit;

/* -------------------------------------------------------------------------------------------------*/
/*  Rate Position by Service Area                                                                   */
/* -------------------------------------------------------------------------------------------------*/

	proc import /* replace N/As with missing to import correctly */
		datafile="&output_files/Scoring Inputs/Rate Position by Service Area 2014_2023.xlsx"
		out=Rates_Raw
		dbms=xlsx replace;
		sheet="Overall RP Flat File";
	run;
	proc import
		datafile="&output_files/Scoring Inputs/Rate Position by Service Area 2014_2023.xlsx"
		out=lookup_Area
		dbms=xlsx replace;
		sheet="Rate Area";
	run;
	proc import
		datafile="&output_files/Scoring Inputs/Rate Position by Service Area _Lookup for LA County.xlsx"
		out=lookup_LAcounty
		dbms=xlsx replace;
	run;
	data Rates;
		set Rates_Raw;

		rename 'Lowest RP'n = RP_Lowest
				'Lowest Relevant RP'n = RP_LowestRel
				'Average RP'n = RP_Avg
				'Average Relevant RP'n = RP_AvgRel
				'Weighted Average RP'n = RP_WeightedAvg
				'Lowest Increase'n = RP_LowestIncr
				'Average Increase'n = RP_AvgIncr;

		/* OFF HIX not yet available for 2023 as of 9/9/22 */
		where 'Rating Area ID'n ne 'Overall' and Year in (&Campaign_year.,%eval(&Campaign_year.-1)); 

		format Exchange $7.;
		if 'On/Off Exchange'n = 'On' then Exchange = 'ONHIX_';
			else if 'On/Off Exchange'n = 'Off' then Exchange = 'OFFHIX_';

		if 'Metal Tier'n = 'Bronze' then Metal = 'BRZ';
			else if 'Metal Tier'n = 'Silver' then Metal = 'SLV';
			else if 'Metal Tier'n = 'Gold' then Metal = 'GOL';
			else if 'Metal Tier'n = 'Platinum' then Metal = 'PLA';
			else if 'Metal Tier'n = 'Overall' then Metal = 'ALL';
			else if 'Metal Tier'n = 'Catastrophic' then Metal = 'CAT';

		drop ID 'Carrier-Network'n 'Short Carrier'n 'Metal Tier'n 'On/Off Exchange'n Network 'CY Rates Analysis Status'n;

		if (Year = &Campaign_year. and Exchange = 'ONHIX_') 
			or (Year = %eval(&Campaign_year.-1) and Exchange = 'OFFHIX_')
			then output;

	run;

	/* transpose by metal tier */
	proc sql; create table Rates as select distinct * from Rates; quit; *dupes;
	proc sort data=Rates; by 'Rating Area ID'n Region Exchange Metal; run;
	proc transpose 
		data=Rates
		out=rates_Lowest(drop=_LABEL_ _NAME_)
		prefix=RP_Lowest_;
		by 'Rating Area ID'n Region;
		id Exchange Metal;
		var RP_Lowest;
	run;
	proc transpose 
		data=Rates
		out=rates_LowestRel(drop=_LABEL_ _NAME_)
		prefix=RP_LowestRel_;
		by 'Rating Area ID'n Region;
		id Exchange Metal;
		var RP_LowestRel;
	run;
	proc transpose 
		data=Rates
		out=rates_WeightedAvg(drop=_LABEL_ _NAME_)
		prefix=RP_WeightedAvg_;
		by 'Rating Area ID'n Region;
		id Exchange Metal;
		var RP_WeightedAvg;
	run;
	proc transpose 
		data=Rates
		out=rates_LowestIncr(drop=_LABEL_ _NAME_)
		prefix=RP_LowestIncr_;
		by 'Rating Area ID'n Region;
		id Exchange Metal;
		var RP_LowestIncr;
	run;
	data rates_transpose;
		merge rates_Lowest
			  rates_LowestRel
			  rates_WeightedAvg
			  rates_LowestIncr;
		by 'Rating Area ID'n Region;
	run;

	* Rating Area --> County and Zip;
	proc sort data=rates_transpose; by 'Rating Area ID'n Region; run;
	proc sort data=lookup_Area; by 'Rating Area'n Jurisdiction; run;

	data Rates;
		merge rates_transpose(in=a)
			  lookup_Area(in=b drop=State rename=('Rating Area'n='Rating Area ID'n 
													Jurisdiction = Region));
		by 'Rating Area ID'n Region;
		rename 'Rating Area ID'n = Rate_Area
				County = CNTY_NM;
		'County'n = upcase('County'n);
		if 'County'n = '' then 'County'n = 'LOS ANGELES';
		if Region = 'KPWA' then State = 'WA';
			else if Region in ('NCAL','SCAL') then State = 'CA';
			else State = Region;
		if a;
	run;

	* add zip;
	data lookup_LAcounty;
		set lookup_LAcounty;
		where Area in (15,16);
		rename County = CNTY_NM;
		if Area=15 then Rate_Area = 'Area 15';
			else if Area=16 then Rate_Area = 'Area 16';
		ZIP_CD = input(ZIP,8.);
		County = upcase(County);
		drop A Area 'FIPS COUNTY CODE'n 'Zip Code Split Across Counties'n G Zip;
	run;

	proc sql;
	create table Rate_Area_Final as
	select distinct
		x.State /* join key */
	,	x.CNTY_NM /* join key */
	,	y.ZIP_CD /* join key */
	,	RP_Lowest_ONHIX_ALL /* 2023 */
	,	RP_LowestRel_ONHIX_SLV /* 2023 */
	,	RP_LowestIncr_ONHIX_ALL /* 2023 */
	,	RP_WeightedAvg_ONHIX_BRZ as RP_WeightedAvg_OFFHIX_BRZ /* Use 2023 On-HIX instead, since Off-HIX not yet available */
	,	RP_LowestIncr_ONHIX_ALL as RP_LowestIncr_OFFHIX_ALL /* Use 2023 On-HIX instead, since Off-HIX not yet available */
	from Rates x
	left join lookup_LAcounty y
		on x.Rate_Area=y.Rate_Area
		and x.CNTY_NM=y.CNTY_NM;
	quit;

	proc sql;
	create table output.t6_external_data as
	select distinct
		x.*
	,	y.RP_Lowest_ONHIX_ALL
	,	y.RP_LowestRel_ONHIX_SLV
	,	y.RP_LowestIncr_ONHIX_ALL
	,	y.RP_WeightedAvg_OFFHIX_BRZ
	,	y.RP_LowestIncr_OFFHIX_ALL
	from output.t6_external_data x
	left join output.t2_address a
		on x.AGLTY_INDIV_ID=a.AGLTY_INDIV_ID
	left join Rate_Area_Final y
		on a.CNTY_NM=y.CNTY_NM
		and ((y.ZIP_CD ne . and a.ZIP_CD=y.ZIP_CD)
				or y.ZIP_CD = . and a.ST_CD=y.State);
	quit;

/* -------------------------------------------------------------------------------------------------*/
/*  Treatment                                                                                       */
/* -------------------------------------------------------------------------------------------------*/

	proc sql; 
		CREATE TABLE output.t1_promo_hist_all AS
		SELECT DISTINCT
			PH.AGLTY_INDIV_ID,
			p1.PROMO_ID,
			p1.PROMO_NM,
			p1.PROMO_DSC,
			p1.REGN_CD,
			p1.SUB_REGN_CD,
			p1.PROMO_START_DT,
			p1.PROMO_END_DT,
			o.offr_dsc, o.offr_nm, 
			md.MEDIA_CHNL_CD, md.MEDIA_DTL_CD, md.MEDIA_DTL_DSC, 
			e.EVENT_NM, e.EVENT_DSC
		FROM MARS.PROMOTION p1
		inner join mars.offer o on o.OFFR_ID=p1.OFFR_ID
		inner join mars.media_detail md on o.MEDIA_DTL_ID=md.MEDIA_DTL_ID
		inner join mars.event e on e.EVENT_ID=p1.EVENT_ID
		left join mars.individual_promotion_history ph on p1.PROMO_ID=ph.PROMO_ID
		where e.EVENT_CD like 'KPIF%' /* KPIF promotions */
			and AGLTY_INDIV_ID in (SELECT AGLTY_INDIV_ID FROM output.t1_marketable_pop) /* OE2023 KPIF EM pop */
			and datdif(p1.PROMO_START_DT,today(),'ACT/ACT') between -365 and 365;
	quit;

	data OEDM; /* not yet loaded into MARS */
		set WS.KPIF_DM_23_Pop;
		keep AGLTY_INDIV_ID;
	run;

/*		proc freq data=output.t1_promo_hist_all; */
/*			tables offr_nm*/
/*					offr_nm*media_dtl_dsc*/
/*					media_chnl_cd*/
/*					media_dtl_dsc*/
/*					media_chnl_cd*media_dtl_dsc;*/
/*		run;*/
/*		proc sql;*/
/*		create table explore_timing as*/
/*		select distinct*/
/*			media_chnl_cd*/
/*		,	OFFR_NM*/
/*		,	year(promo_start_dt) as year*/
/*		,	month(promo_start_dt) as month*/
/*		,	count(*)*/
/*		from output.t1_promo_hist_all*/
/*		group by */
/*			media_chnl_cd*/
/*		,	OFFR_NM*/
/*		,	year(promo_start_dt)*/
/*		,	month(promo_start_dt);*/
/*		quit;*/

	proc sql;
	create table output.t7_treatment as
	select distinct
		x.AGLTY_INDIV_ID
	,	max(case when y.OFFR_NM = 'KPIF_SEP_EM' and year(y.PROMO_START_DT) = %eval(&Campaign_year.-1)
				then 1 else 0 end) as KPIF_SEP_EM_Flag_PY  
	,	max(case when (y.MEDIA_CHNL_CD = 'DM' and y.OFFR_NM in ('OE DIRECT MAIL','OPEN ENROLMENT') and y.PROMO_START_DT >= "01SEP2022"d and PROMO_START_DT <= "31DEC2022"d)
						or z.AGLTY_INDIV_ID is not missing
				then 1 else 0 end) as KPIF_OE_DM_Flag 
	from output.t1_marketable_pop x
	left join output.t1_promo_hist_all y 
		on x.AGLTY_INDIV_ID=y.AGLTY_INDIV_ID
	left join OEDM z
		on x.AGLTY_INDIV_ID=z.AGLTY_INDIV_ID
	group by 
		x.AGLTY_INDIV_ID;
	quit;

/* -------------------------------------------------------------------------------------------------*/
/*  Final Appended                                                                                  */
/* -------------------------------------------------------------------------------------------------*/

	proc sql;

	CREATE TABLE WS.KPIF_EM_23_Scoring_Final AS
	SELECT DISTINCT
		t1.AGLTY_INDIV_ID
	,	"&Model_Name." as MODEL_NAME
	,	&Model_Number. as MODEL_NUMBER
	,   case when t1.Population='FM' then t1.Population else 'RNC/WPL' end as Audience
	,	coalescec(t2.Region,'UN') as Region
	,	coalescec(t2.CNTY_NM,'UN') as CNTY_NM
	,	coalescec(t2.CITY_NM,'UN') as CITY_NM
	,	coalescec(t2.ST_CD,'UN') as ST_CD
	,	coalescec(t2.REGN_CD,'UN') as REGN_CD
	,	coalescec(t2.SUB_REGN_CD,'UN') as SUB_REGN_CD
	,	coalescec(t2.SVC_AREA_NM ,'UN') as SVC_AREA_NM

	,	coalesce(t3.HH_HEAD_FLAG,0) as HH_HEAD_FLAG
	,	t3.DATA_AGE_YEARS
	,	t3.CENS_BLUE_CLLR_PCT	
	,	t3.CENS_INCM_PCTL
	,	t3.CENS_MED_HH_INCM_10k
	,	t3.CENS_MED_HOME_VAL_10k
	,	coalescec(t3.MODEL_OWN_RENT,'UNKNOWN') as MODEL_OWN_RENT
	,	coalesce(t3.KBM_Flag,0) as KBM_Flag

	,	coalesce(t4.Email_Open_Flag_PY,0) as Email_Open_Flag_PY

	,	t5.ESRI_Pct_AGE_30_34_B
	,	t5.ESRI_Pct_Tot_ASIAN
	,	t5.ESRI_Pct_Tot_HISPANIC
	,	t5.ESRI_Pct_Tot_PAC_ISL
	,	t5.ESRI_Pct_Tot_WHITE_FY
	,	t5.ESRI_Pct_Tot_HISPANIC_FY
	,	t5.ESRI_HHINCOME_AVG_1k
	,	t5.ESRI_PER_CAPITA_INCOME_1k
	,	coalescec(t5.TAPESTRY_LIFESTYLE,'UN') as TAPESTRY_LIFESTYLE
	,	coalescec(t5.TAPESTRY_URBAN,'UN') as TAPESTRY_URBAN

	,	t6.RP_Lowest_ONHIX_ALL
	,	t6.RP_LowestRel_ONHIX_SLV
	,	t6.RP_LowestIncr_ONHIX_ALL
	,	t6.RP_WeightedAvg_OFFHIX_BRZ
	,	t6.RP_LowestIncr_OFFHIX_ALL
	,	t6.Market_Size_Ind
	,	t6.Market_Size_SBU
	,	t6.Market_Size_Medi
	,	t6.Market_Size_Ind_YOYchg
	,	t6.Market_Size_Medi_YOYchg
	,	t6.Market_Size_Unins_YOYchg
	,	t6.Market_Size_Medi_3YRchg
	,	t6.Market_Size_Unins_3YRchg
	,	t6.Market_Size_B2B_FYchg
	,	t6.Market_Size_Unins_FYchg

	,	1 as Treatment_Flag
	,	0 as OE_Season_Flag_2022
	,	0 as OE_Season_Flag_2021
	,	0 as OE_Season_Flag_2020
	,	0 as Cases_OE1_vs_1mo_ago
	,	coalesce(t7.KPIF_SEP_EM_Flag_PY,0) as KPIF_SEP_EM_Flag_PY
	,	coalesce(t7.KPIF_OE_DM_Flag,0) as KPIF_OE_DM_Flag
	,	t8.FM_TENURE_MO

	,	CASE WHEN t9.MODL_DCL_VAL = . THEN 'U' ELSE strip(put(t9.MODL_DCL_VAL,8.)) END as Old_Model_Decile

	FROM output.t1_marketable_pop t1
	LEFT JOIN output.t2_address t2
		ON t1.AGLTY_INDIV_ID=t2.AGLTY_INDIV_ID
	LEFT JOIN output.t3_demog t3
		ON t1.AGLTY_INDIV_ID=t3.AGLTY_INDIV_ID
	LEFT JOIN output.t4_email t4
		ON t1.AGLTY_INDIV_ID=t4.AGLTY_INDIV_ID
	LEFT JOIN output.t5_Tapestry t5
		ON t1.AGLTY_INDIV_ID=t5.AGLTY_INDIV_ID
	LEFT JOIN output.t6_external_data t6
		ON t1.AGLTY_INDIV_ID=t6.AGLTY_INDIV_ID
	LEFT JOIN output.t7_treatment t7
		ON t1.AGLTY_INDIV_ID=t7.AGLTY_INDIV_ID
	LEFT JOIN ws.KPIF_EM_23_Scoring_Tenure t8
		ON t1.AGLTY_INDIV_ID=t8.AGLTY_INDIV_ID_NUM
	LEFT JOIN 
		(SELECT DISTINCT
			AGLTY_INDIV_ID
		,	MIN(MODL_DCL_VAL) as MODL_DCL_VAL
		FROM MARS.INDIVIDUAL_MODEL_SCORE
		WHERE MODL_VRSN_NBR=193 /* J's last model score from 2021-09-20 */
		GROUP BY 
			AGLTY_INDIV_ID
		) t9
		ON t1.AGLTY_INDIV_ID=t9.AGLTY_INDIV_ID;

	quit;

	proc means data=WS.KPIF_EM_23_Scoring_Final min q1 median q3 max;
	var DATA_AGE_YEARS
		CENS_BLUE_CLLR_PCT
		CENS_INCM_PCTL
		CENS_MED_HH_INCM_10k
		CENS_MED_HOME_VAL_10k
		ESRI_Pct_AGE_30_34_B
		ESRI_Pct_Tot_ASIAN
		ESRI_Pct_Tot_HISPANIC
		ESRI_Pct_Tot_PAC_ISL
		ESRI_Pct_Tot_WHITE_FY
		ESRI_Pct_Tot_HISPANIC_FY
		ESRI_HHINCOME_AVG_1k
		ESRI_PER_CAPITA_INCOME_1k
		RP_Lowest_ONHIX_ALL
		RP_LowestRel_ONHIX_SLV
		RP_LowestIncr_ONHIX_ALL
		RP_WeightedAvg_OFFHIX_BRZ
		RP_LowestIncr_OFFHIX_ALL
		Market_Size_Ind
		Market_Size_SBU
		Market_Size_Medi
		Market_Size_Ind_YOYchg
		Market_Size_Medi_YOYchg
		Market_Size_Unins_YOYchg
		Market_Size_Medi_3YRchg
		Market_Size_Unins_3YRchg
		Market_Size_B2B_FYchg
		Market_Size_Unins_FYchg
		FM_TENURE_MO
		;
		run;

	proc freq data=WS.KPIF_EM_23_Scoring_Final;
		tables
		Model_Name
		Model_Number
		Audience
		Region
		CNTY_NM
		ST_CD
		REGN_CD
		SUB_REGN_CD
		SVC_AREA_NM
		HH_HEAD_FLAG
		DATA_AGE_YEARS
		MODEL_OWN_RENT
		KBM_FLAG
		Email_Open_Flag_PY
		TAPESTRY_LIFESTYLE
		TAPESTRY_URBAN
		Treatment_Flag
		OE_Season_Flag_2022
		OE_Season_Flag_2021
		OE_Season_Flag_2020
		Cases_OE1_vs_1mo_ago
		KPIF_SEP_EM_Flag_PY
		KPIF_OE_DM_Flag
		Old_Model_Decile
		/ norow nocol list missing;
	run;




	
