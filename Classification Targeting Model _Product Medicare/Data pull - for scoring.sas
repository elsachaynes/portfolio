
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

/* -------------------------------------------------------------------------------------------------*/
/*  Set variables specific to this scoring                                                          */
/* -------------------------------------------------------------------------------------------------*/

	%let Campaign_year = 2023;
	%let SQL_TblNm_Agilities = MED_DM_22_Scoring_Pop;
	%let SQL_TblNm_Addresses = MED_DM_22_Scoring_Addr;
	%let Scoring_Folder_Nm = Scoring_062022;
	%let CMS_AEP_File = State_County_Penetration_MA_2022_05;
	%let CMS_SEP_File = State_County_Penetration_MA_2022_11; /* not available yet */
	%let AEP_Model_Number = 196;
	%let AEP_Model_Name = NATIONAL MEDICARE AEP DM PROSPECT RESPONSE MODEL;
	%let SEP_Model_Number = 197;
	%let SEP_Model_Name = NATIONAL MEDICARE SEP DM PROSPECT RESPONSE MODEL;

	* Output;
	%let output_files = /gpfsFS2/sasdata/nfs/ndc_grid/po_imca_digital/EHaynes/__Models/MED_ProspectTargeting_2022;
	%let output_files = &output_files./&Scoring_Folder_Nm.;
	libname output "&output_files";

/* -------------------------------------------------------------------------------------------------*/
/*  Marketable Individuals                                                                          */
/* -------------------------------------------------------------------------------------------------*/

	* Processed by Ron Sunga on 5/25 and uploaded to SQL Server;

/*	data output.t1_marketable_pop;*/
/*		set WS.&SQL_TblNm_Agilities.;*/
/*		Campaign = 'AEP';*/
/*	run;*/

/* -------------------------------------------------------------------------------------------------*/
/*  Addresses                                                                                       */
/* -------------------------------------------------------------------------------------------------*/

	* Processed in SQL Server under "Data pull - for scoring pt1.sql";

	data output.t1_addresses;
		set WS.&SQL_TblNm_Addresses.;
		Campaign = 'AEP';
		if CNTY_NM = 'PRINCE GEORGES' then CNTY_NM = "PRINCE GEORGE'S";
	run;

/* -------------------------------------------------------------------------------------------------*/
/*  Promo IDs & Promotion History                                                                   */
/* -------------------------------------------------------------------------------------------------*/

	proc sql; 

	CREATE TABLE Promo_IDs AS
	SELECT DISTINCT
		c.Inhome_Date
	,	c.Campaign
	,	c.Promotionid
	,	c.Creative
	,	c.Media_Detail
	,	c.Segments
	,	c.Region
	,	c.Segment
	FROM MARS.c_campaign_matrix c
	WHERE year(Inhome_Date) = (&Campaign_year-1)
		AND Campaign = 'SEP'
		AND Channel = 'DM'
		AND Region not in ('NWWA','KPWA')
		AND Segment = 'All non-mbrs'
		AND Segments not in ('Lane County (NW)','New Movers')
		AND Media_Detail IN ('DM-EXP','DM-KBM','DM-OTH')
		AND find(Segments,'Past Leads')=0
		AND find(Segments,'Former Member')=0;

	quit;
	data Promo_IDs;	
		set Promo_IDs;
		PROMO_ID = strip(put(Promotionid,8.));
	run;
		
	proc sql;

	CREATE TABLE output.Promotion_History AS
	SELECT DISTINCT
		ph.AGLTY_INDIV_ID
	,	ph.PROMO_ID
	FROM MARS.INDIVIDUAL_PROMOTION_HISTORY ph
	WHERE PROMO_ID IN (SELECT DISTINCT PROMO_ID FROM Promo_ids);

	quit;

	proc sql;

	CREATE TABLE output.t2_Promotion_Flags AS
	SELECT DISTINCT
		ph.AGLTY_INDIV_ID
	,	1 as PROMOTED_SEP_FLAG
	,	MAX(CASE WHEN find(Creative,'Latino','i')>0 THEN 1 ELSE 0 END) AS SEP_LATINO_DM_FLAG
	, 	0 AS LIST_SOURCE_EXPERIAN_FLAG /* since Experian wasn't purchased for AEP 2023, all mailed prospects will be KBM */
	,	MAX(CASE WHEN find(Creative,'SEP Direct Mail D1','i')>0 THEN 1 ELSE 0 END) AS SEP_DROP_1_FLAG
	,	MAX(CASE WHEN find(Creative,'SEP Direct Mail D2','i')>0 THEN 1 ELSE 0 END) AS SEP_DROP_2_FLAG
	,	MAX(CASE WHEN find(Creative,'SEP Direct Mail D3','i')>0 THEN 1 ELSE 0 END) AS SEP_DROP_3_FLAG
	,	MAX(CASE WHEN find(Creative,'SEP Direct Mail D4','i')>0 THEN 1 ELSE 0 END) AS SEP_DROP_4_FLAG
	,	MAX(CASE WHEN find(Creative,'SEP Direct Mail D5','i')>0 THEN 1 ELSE 0 END) AS SEP_DROP_5_FLAG
	,	MAX(CASE WHEN find(Creative,'SEP Direct Mail D6','i')>0 THEN 1 ELSE 0 END) AS SEP_DROP_6_FLAG
	/* For later tabulation */
	,	CASE WHEN find(Segments,'Decile','i')>0 or Segments = 'Unscored' THEN compress(Segments,'Decile ') ELSE '' END AS Decile
	FROM output.Promotion_History ph
	LEFT JOIN Promo_IDs p
		on ph.PROMO_ID=p.PROMO_ID
	GROUP BY ph.AGLTY_INDIV_ID;
	quit;

	proc delete data=Promo_ids;
	proc delete data=output.Promotion_History;

/* -------------------------------------------------------------------------------------------------*/
/*  KBM                                                                                             */
/* -------------------------------------------------------------------------------------------------*/

	proc sql;

	CREATE TABLE output.t3_KBM AS
	SELECT DISTINCT
		AGLTY_INDIV_ID
	,	ADDR_VRFN_CD
	,	AGE_VAL
	,	CENS_HH_CHILD_PCT
	,	CENS_HISPANIC_PCT
	,	CENS_MARRIED_PCT
	,	CENS_SINGLE_HOME_PCT
	,	CENS_WHITE_PCT
	,	HH_PERSS_CNT
	,	HH_CHILD_CNT
	,	HMOWN_STAT_CD
	,	LEN_RES_CD
	,	IMAGE_MAIL_ORD_BYR_CD
	,	MAIL_ORD_RSPDR_CD
	,	SCORE_4
	,	ONE_PER_ADDR_IND
	,	PRSN_CHILD_IND
	,	UNIT_NBR_PRSN_IND
	,	1 as KBM_Flag
	FROM MARS.INDIVIDUAL_KBM_PROSPECT
	WHERE AGLTY_INDIV_ID in (SELECT AGLTY_INDIV_ID FROM output.t1_marketable_pop);

	quit;

			* Match % on KBM: 100%;
			proc sql;

			title 'KBM match rate';
			SELECT DISTINCT
				COUNT(DISTINCT y.AGLTY_INDIV_ID)/
					COUNT(DISTINCT x.AGLTY_INDIV_ID) AS PCT_MATCH_KBM format percent7.2
			FROM output.t1_marketable_pop x
			LEFT JOIN output.t3_KBM y
				on x.AGLTY_INDIV_ID=y.AGLTY_INDIV_ID;
			title;

			quit;

/* -------------------------------------------------------------------------------------------------*/
/*  Membership                                                                                      */
/* -------------------------------------------------------------------------------------------------*/

	proc sql;

	CREATE TABLE Membership AS
	SELECT 
		*
	FROM MARS.Member
	WHERE AGLTY_INDIV_ID IN (SELECT AGLTY_INDIV_ID FROM output.t1_marketable_pop);

	quit;

	proc sort data=Membership; by AGLTY_INDIV_ID; run;
	proc sort data=output.t1_marketable_pop; by AGLTY_INDIV_ID; run;
	data output.t1_marketable_pop;
		merge output.t1_marketable_pop(in=a)
			  Membership(in=b);
		by AGLTY_INDIV_ID;
		if a and not b; * Remove former/active members;
	run;

	proc delete data=Membership; run;

/* -------------------------------------------------------------------------------------------------*/
/*  Response                                                                                        */
/* -------------------------------------------------------------------------------------------------*/

	proc sql;

	CREATE TABLE Response AS
	SELECT DISTINCT
		AGLTY_INDIV_ID
	FROM MARS.INDIVIDUAL_LEAD_RESPONSE
	WHERE AGLTY_INDIV_ID IN (SELECT AGLTY_INDIV_ID FROM output.t1_marketable_pop)
		UNION
	SELECT DISTINCT
		AGLTY_INDIV_ID
	FROM MARS.INDIVIDUAL_LEAD_MED_RESPONSE
	WHERE AGLTY_INDIV_ID IN (SELECT AGLTY_INDIV_ID FROM output.t1_marketable_pop)
		UNION
	SELECT DISTINCT
		AGLTY_INDIV_ID
	FROM MARS.INDIVIDUAL_LEAD_KPIF_RESPONSE
	WHERE AGLTY_INDIV_ID IN (SELECT AGLTY_INDIV_ID FROM output.t1_marketable_pop);

	quit;

	proc sort data=Response; by AGLTY_INDIV_ID; run;
	proc sort data=output.t1_marketable_pop; by AGLTY_INDIV_ID; run;
	data output.t1_marketable_pop;
		merge output.t1_marketable_pop(in=a)
			  Response(in=b);
		by AGLTY_INDIV_ID;
		if a and not b; * Remove RNC;
	run;

	proc delete data=Response; run;

/* -------------------------------------------------------------------------------------------------*/
/*  Tapestry                                                                                        */
/* -------------------------------------------------------------------------------------------------*/

	options mprint;
	%macro split_into_batches(inputTable);
		%let i = 1;
		%let batchNum = 1;
		proc sql; select distinct count(*) into :nRows from &inputTable; quit;
		%do %while (&i < &nRows);
			data output.t4_Tapestry_&batchNum;
				set &inputTable;
				if _N_ >= &i and _N_ < %eval(&i+500000);
			run;
			%let i = %eval(&i+500000);
			%let batchNum = %eval(&batchNum+1);
		%end;
		%let batchNumPull = 1;
		%do %while (&batchNumPull <= &batchNum);
			proc sql;

			CREATE TABLE output.t4_Tapestry_&batchNumPull AS
			SELECT DISTINCT
				s.*
				/*	2020 population metrics */
			,	tap1.POP85_CY AS POP_AGE_85_up
			,	tap1.AVGHHSZ_CY AS POP_AVG_HH_SIZE
				/*	2025 forecast population metrics */
			,	tap7.POPDENS_FY AS POP_PER_SQ_MILE_FY
				/*	2020 housing metrics */
			,	tap1.HAI_CY AS HOUSING_AFFORDAB_INDEX
				/* 2020 diversity metrics */
			,	tap5.DIVINDX_CY AS DIVERSITY_INDEX
			,	tap3.MEDWFAGECY AS MEDIAN_WHITE_FEMALE_AGE
			,	tap4.MEDHMAGECY AS MEDIAN_HISP_MALE_AGE
				/* 2025 diversity metrics */
			,	tap11.HISPPOP_FY AS POP_HISPANIC_FY
				/* 2020 financial metrics */
			,	tap5.HINC0_CY AS HH_INCOME_0k_15k
			,	tap5.HINC200_CY AS HH_INCOME_200k
			,	tap6.MEDNWA65CY AS MEDIAN_NET_WORTH_65_74
				/* 2025 financial metrics */
			,	tap11.HINC15_FY AS HH_INCOME_15_25k_FY
				/*	2020 labor metrics */
			,	tap5.UNEMPRT_CY AS UNEMPLOYMENT_RT
			,	tap5.CIVLF65_CY AS POP_65_up_IN_LABOR_FORCE

				/*	2020 education metrics */
			,	tap5.NOHS_CY AS EDUC_NO_HS
			,	tap5.HSGRAD_CY AS EDUC_HS
			,	taphh.TSEGNAME AS TAPESTRY_SEGMENT
			,	taphh.TLIFENAME AS TAPESTRY_LIFESTYLE
			,	taphh.TURBZNAME AS TAPESTRY_URBAN

			FROM output.t4_Tapestry_&batchNumPull s /* Change to name of your sample table */
			LEFT JOIN ESRI.CFY20_01 tap1
				ON s.GEOCODE=tap1.ID
/*			LEFT JOIN ESRI.CFY20_02 tap2*/
/*				ON s.GEOCODE=tap2.ID*/
			LEFT JOIN ESRI.CFY20_03 tap3
				ON s.GEOCODE=tap3.ID
			LEFT JOIN ESRI.CFY20_04 tap4
				ON s.GEOCODE=tap4.ID
			LEFT JOIN ESRI.CFY20_05 tap5
				ON s.GEOCODE=tap5.ID
			LEFT JOIN ESRI.CFY20_06 tap6
				ON s.GEOCODE=tap6.ID
			LEFT JOIN ESRI.CFY20_07 tap7
				ON s.GEOCODE=tap7.ID
		/*	LEFT JOIN ESRI.CFY20_08 tap8*/
		/*		ON s.GEOCODE=tap8.ID*/
/*			LEFT JOIN ESRI.CFY20_09 tap9*/
/*				ON s.GEOCODE=tap9.ID*/
/*			LEFT JOIN ESRI.CFY20_10 tap10*/
/*				ON s.GEOCODE=tap10.ID*/
			LEFT JOIN ESRI.CFY20_11 tap11
				ON s.GEOCODE=tap11.ID
		/*	LEFT JOIN ESRI.TAP20_ADULT tapad*/
		/*		ON s.GEOCODE=tapad.ID*/
			LEFT JOIN ESRI.TAP20_HH taphh
				ON s.GEOCODE=taphh.ID
			;
			quit;

			%let batchNumPull = %eval(&batchNumPull+1);

		%end;
	%mend;

	%split_into_batches(output.t1_addresses);

	data output.t4_Tapestry;
		set output.t4_Tapestry_:;
		drop AGLTY_ADDR_ID_VCHAR AGLTY_ADDR_ID Segment_Name Region ZIP_CD
			 ZIP4_CD HOSP_DIST_MSR MOB_DIST_MSR COUNTYFIPS CNTY_NM ST_CD 
			 REGN_CD SUB_REGN_CD SVC_AREA_NM Campaign;
	run;

/* -------------------------------------------------------------------------------------------------*/
/*  Medicare Penetration                                                                            */
/* -------------------------------------------------------------------------------------------------*/

	proc import
		file="&output_files/Medicare Penetration CMS/&CMS_AEP_File..csv"
		out=MAPenetration_AEP
		dbms=csv replace;
	run;
/*	proc import*/
/*		file="&output_files/Medicare Penetration CMS/&CMS_SEP_File..csv"*/
/*		out=MAPenetration_SEP*/
/*		dbms=csv replace;*/
/*	run;*/

	data MAPenetration;
		set MAPenetration_AEP(in=a)
/*			MAPenetration_SEP(in=b)*/
			;
		keep COUNTYFIPS MA_Penetration_Rt Campaign;
		if a then Campaign = 'AEP'; else Campaign = 'SEP';
		MA_Penetration_Rt = input(Penetration,percent7.2)*100;
		COUNTYFIPS = catt(FIPSST,FIPSCNTY);
	run;

	proc sql;
	create table output.t5_CMS as
	select
		adr.AGLTY_INDIV_ID
	,	ma.Campaign
	,	ma.MA_Penetration_Rt 
	from output.t1_addresses adr
	left join MAPenetration ma
		on adr.COUNTYFIPS=ma.COUNTYFIPS
		and adr.Campaign=ma.Campaign
	where adr.Campaign = 'AEP'

		union

	select
		adr.AGLTY_INDIV_ID
	,	ma.Campaign
	,	ma.MA_Penetration_Rt 
	from output.t1_addresses adr
	left join MAPenetration ma 
		on adr.COUNTYFIPS=ma.COUNTYFIPS
		and adr.Campaign=ma.Campaign
	where adr.Campaign = 'SEP'
	;
	quit;
	
				* Match % on MA penetration: 99.9%;
				proc sql;

				title 'MA Penetration match rate';
				SELECT DISTINCT
					COUNT(DISTINCT CASE WHEN ma.MA_Penetration_Rt ne . THEN ma.AGLTY_INDIV_ID END)/
						COUNT(DISTINCT p.AGLTY_INDIV_ID) AS PCT_MATCH format percent7.2
				FROM output.t1_marketable_pop p
				LEFT JOIN output.t5_CMS ma
					ON p.AGLTY_INDIV_ID=ma.AGLTY_INDIV_ID;
				title;

				quit;

/* -------------------------------------------------------------------------------------------------*/
/*  Benefits (highest value plan)                                                                   */
/* -------------------------------------------------------------------------------------------------*/

	proc import
		file="&output_files/Medicare KP Benefits/*.csv"
		out=Benefits
		dbms=csv replace;
		guessingrows=max;
	run;

	data Benefits;
		retain Campaign Region County 'Total Value Added'n;
		set Benefits;
		keep Campaign Region County 'Total Value Added'n;
		format Campaign $3. Region $4. County $50. 'Total Value Added'n dollar18.2;

		if 'Plan Year' = &Campaign_year and year(today()) < &Campaign_year. and month(today()) < 11 then Campaign = 'AEP';
			else Campaign = 'SEP';

		if 'Plan Value'n = 'Highest Value Plan'; * There are also 1-2 lesser value plans;
		if 'Parent Carrier'n = 'KP';

		if strip('KP Region'n) = 'NCAL' then Region = 'CANC';
			else if strip('KP Region'n) = 'SCAL' then Region = 'CASC' ;
			else if strip('KP Region'n) = 'CO' then Region = 'CO';
			else if strip('KP Region'n) = 'GA' then Region = 'GA';
			else if strip('KP Region'n) = 'HI' then Region = 'HI';
			else if strip('KP Region'n) = 'WA' then Region = 'WA';
			else if strip('KP Region'n) = 'NW' then Region = 'NW';
			else if strip('KP Region'n) = 'MAS' then Region = 'MAS';
			else Region = strip('KP Region'n);

		County = upcase(County);

		rename 'Total Value Added'n = BENE_TotalValAdd;

	run;

	proc sql;
	create table output.t6_benefits as
	select distinct
		adr.AGLTY_INDIV_ID
	/* Benefits */
	,	'AEP' as Campaign /* have to use 2022 SEP values and hardcode for AEP */
	,	b.BENE_TotalValAdd
	from output.t1_addresses adr
	left join Benefits b
		on adr.Region=b.Region
		and adr.CNTY_NM=b.County
/*		and adr.Campaign=b.Campaign*/ /* have to use 2022 SEP values and hardcode for AEP */
	where adr.Campaign='AEP'

		union

	select distinct
		adr.AGLTY_INDIV_ID
	/* Benefits */
	,	b.Campaign 
	,	b.BENE_TotalValAdd
	from output.t1_addresses adr
	left join Benefits b
		on adr.Region=b.Region
		and adr.CNTY_NM=b.County
		and adr.Campaign=b.Campaign
	where adr.Campaign='SEP'
		;
	quit;

				* Match % on benefits: 100%;
				proc sql;

				title 'Benefits match rate';
				SELECT DISTINCT
					COUNT(DISTINCT CASE WHEN b.BENE_TotalValAdd ne . THEN b.AGLTY_INDIV_ID END)/
						COUNT(DISTINCT p.AGLTY_INDIV_ID) AS PCT_MATCH format percent7.2
				FROM output.t1_marketable_pop p
				LEFT JOIN output.t6_benefits b
					ON p.AGLTY_INDIV_ID=b.AGLTY_INDIV_ID;
				title;

				quit;

/* -------------------------------------------------------------------------------------------------*/
/*  Market Share and Position                                                                       */
/* -------------------------------------------------------------------------------------------------*/

	data Position;
		%let _EFIERR_ = 0;
		infile "&output_files/Medicare Market Share and Position/7.*.csv"
		delimiter=',' MISSOVER DSD lrecl=32767;
		informat VAR1 $10. ;
		informat VAR2 $10. ;
		informat VAR3 $10. ;
		informat VAR4 $10. ;
		informat VAR5 $10. ;
		informat VAR6 $10. ;
		informat VAR7 $10. ;
		informat VAR8 $10. ;
		informat VAR9 $10. ;
		informat VAR10 $10. ;

		format VAR1 $10. ;
		format VAR2 $10. ;
		format VAR3 $10. ;
		format VAR4 $10. ;
		format VAR5 $10. ;
		format VAR6 $10. ;
		format VAR7 $10. ;
		format VAR8 $10. ;
		format VAR9 $10. ;
		format VAR10 $10. ;

		input VAR1 $
				VAR2 $
				VAR3 $
				VAR4 $
				VAR5 $
				VAR6 $
				VAR7 $
				VAR8 $
				VAR9 $
				VAR10 $;

		if VAR1 = '' then VAR1 = 'Year';
		*if VAR1 = '' then delete;
		run;
		proc transpose data=Position(where=(Var1='Year')) out=Year(drop=var1 _NAME_); by var1; var _ALL_; run;
		data Position;
			merge Position(where=(VAR1 ne 'Year')) 
				  Year;
			if VAR1 in ('KP Region','') then delete;
			rename VAR1 = Region
				   COL1 = Year;
			POS_Premium = input(VAR2,dollar18.2);
			POS_Inpatient = input(VAR4,dollar18.2);
			POS_Professional = input(VAR6,dollar18.2);
			Year = input(COL1,8.);
			
			format POS_: dollar18.2;

			if Year = &Campaign_year. and year(today()) < &Campaign_year. and month(today()) < 11 then Campaign = 'AEP';
				else Campaign = 'SEP';

			if strip(VAR1) = 'NCAL' then Region = 'CANC';
				else if strip(VAR1) = 'SCAL' then Region = 'CASC' ;
				else if strip(VAR1) = 'CO' then Region = 'CO';
				else if strip(VAR1) = 'GA' then Region = 'GA';
				else if strip(VAR1) = 'HI' then Region = 'HI';
				else if strip(VAR1) = 'WA' then Region = 'WA';
				else if strip(VAR1) = 'NW' then Region = 'NW';
				else if strip(VAR1) = 'MAS' then Region = 'MAS'; 
				else Region = strip(VAR1);

			keep Region Campaign POS_:;

		run;
	proc delete data=Year; run;
	
	proc import
		file="&output_files/Medicare Market Share and Position/10.*.csv"
		out=Share
		dbms=csv replace;
		guessingrows=max;
	run;
	data Share;

		format Campaign $3. ST_CD $2. County $50. 'pmpm change yoy'n dollar18.;
		set Share;
		keep Campaign ST_CD County 'pmpm change yoy'n;

		Campaign = 'SEP'; /* hard-coded, not sure how to dynamically note the date of data */
		
		if State = 'California' then ST_CD = 'CA';
			else if State = 'Colorado' then ST_CD = 'CO';
			else if State = 'Georgia' then ST_CD = 'GA';
			else if State = 'Hawaii' then ST_CD = 'HI';
			else if State = 'Washington' then ST_CD = 'WA';
			else if State = 'Oregon' then ST_CD = 'OR';
			else if State = 'Maryland' then ST_CD = 'MD';
			else if State = 'District Of Columbia' then ST_CD = 'DC';
			else if State = 'Virginia' then ST_CD = 'VA';
			else ST_CD = State;
		drop State;

		County = upcase(County);

		rename 'pmpm change yoy'n = PMPM_ValueAdd_YoY;

	run;

	proc sql;
	create table output.t7_position as
	select distinct
		adr.AGLTY_INDIV_ID
	/* Position */
	,	'AEP' as Campaign /* hard-coded since AEP data isn't available */
	,	b.POS_Premium
	,	b.POS_Inpatient
	,	b.POS_Professional
	/* Value Add */
	,	s.PMPM_ValueAdd_YoY
	from output.t1_addresses adr
	left join Position b
		on adr.Region=b.Region
/*		and adr.Campaign=b.Campaign*/
	left join Share s
		on adr.ST_CD=s.ST_CD
		and adr.CNTY_NM=s.County
/*		and adr.Campaign=s.Campaign*/
	where adr.Campaign='AEP'

		union

	select distinct
		adr.AGLTY_INDIV_ID
	/* Position */
	,	b.Campaign
	,	b.POS_Premium
	,	b.POS_Inpatient
	,	b.POS_Professional
	/* Value Add */
	,	s.PMPM_ValueAdd_YoY
	from output.t1_addresses adr
	left join Position b
		on adr.Region=b.Region
		and adr.Campaign=b.Campaign
	left join Share s
		on adr.ST_CD=s.ST_CD
		and adr.CNTY_NM=s.County
		and adr.Campaign=s.Campaign
	where adr.Campaign='SEP';
	quit;

				* Match % on Position: 100%;
				* Match % on Share: 98.1%;
				proc sql;

				title 'Position match rate';
				SELECT DISTINCT
					COUNT(DISTINCT CASE WHEN b.POS_Premium ne . THEN b.AGLTY_INDIV_ID END)/
						COUNT(DISTINCT p.AGLTY_INDIV_ID) AS PCT_MATCH_POS format percent7.2
				,	COUNT(DISTINCT CASE WHEN b.PMPM_ValueAdd_YoY ne . THEN b.AGLTY_INDIV_ID END)/
						COUNT(DISTINCT p.AGLTY_INDIV_ID) AS PCT_MATCH_VALADD format percent7.2
				FROM output.t1_marketable_pop p
				LEFT JOIN output.t7_position b
					ON p.AGLTY_INDIV_ID=b.AGLTY_INDIV_ID;
				title;

				quit;

/* -------------------------------------------------------------------------------------------------*/
/*  Final Appended                                                                                  */
/* -------------------------------------------------------------------------------------------------*/

	proc sql;

	CREATE TABLE WS.MED_DM_22_Scoring_Final AS
	SELECT DISTINCT
		t1.AGLTY_INDIV_ID
	,	t1.Campaign
	,	"&AEP_Model_Name." as MODEL_NAME
	,	&AEP_Model_Number. as MODEL_NUMBER
	,	t1.Region
	,	t1_a.SUB_REGN_CD
	,	t1_a.SVC_AREA_NM
	,	t1_a.HOSP_DIST_MSR
	,	t1_a.MOB_DIST_MSR
	,	coalesce(t2.LIST_SOURCE_EXPERIAN_FLAG,0) as LIST_SOURCE_EXPERIAN_FLAG
	,	coalesce(t2.SEP_LATINO_DM_FLAG,0) as SEP_LATINO_DM_FLAG
	,	coalesce(t2.SEP_DROP_1_FLAG,0) as SEP_DROP_1_FLAG
	,	coalesce(t2.SEP_DROP_2_FLAG,0) as SEP_DROP_2_FLAG
	,	coalesce(t2.SEP_DROP_3_FLAG,0) as SEP_DROP_3_FLAG
	,	coalesce(t2.SEP_DROP_4_FLAG,0) as SEP_DROP_4_FLAG
	,	coalesce(t2.SEP_DROP_5_FLAG,0) as SEP_DROP_5_FLAG
	,	coalesce(t2.SEP_DROP_6_FLAG,0) as SEP_DROP_6_FLAG
	,	coalesce(t2.PROMOTED_SEP_FLAG,0) as PROMOTED_SEP_FLAG
	,	CASE WHEN t8.MODL_DCL_VAL = . THEN 'U' ELSE strip(put(t8.MODL_DCL_VAL,8.)) END as Old_Model_Decile
	,	t3.ADDR_VRFN_CD
	,	input(t3.AGE_VAL,8.) as AGE_VAL
	,	CASE WHEN t3.CENS_HH_CHILD_PCT = 0 THEN . ELSE t3.CENS_HH_CHILD_PCT END as CENS_HH_CHILD_PCT
	,	CASE WHEN t3.CENS_HISPANIC_PCT = 0 THEN . ELSE t3.CENS_HISPANIC_PCT END as CENS_HISPANIC_PCT
	,	CASE WHEN t3.CENS_MARRIED_PCT = 0 THEN . ELSE t3.CENS_MARRIED_PCT END as CENS_MARRIED_PCT
	,	CASE WHEN t3.CENS_SINGLE_HOME_PCT = 0 THEN . ELSE t3.CENS_SINGLE_HOME_PCT END as CENS_SINGLE_HOME_PCT
	,	CASE WHEN t3.CENS_WHITE_PCT = 0 THEN . ELSE t3.CENS_WHITE_PCT END as CENS_WHITE_PCT
	,	input(t3.HH_PERSS_CNT,8.) as HH_PERSS_CNT
	,	input(t3.HH_CHILD_CNT,8.) as HH_CHILD_CNT
	,	t3.HMOWN_STAT_CD
	,	input(t3.LEN_RES_CD,8.) as LEN_RES_CD
	,	t3.IMAGE_MAIL_ORD_BYR_CD
	,	t3.MAIL_ORD_RSPDR_CD
	,	t3.SCORE_4
	,	t3.ONE_PER_ADDR_IND
	,	t3.PRSN_CHILD_IND
	,	t3.UNIT_NBR_PRSN_IND
	,	coalesce(t3.KBM_Flag,0) as KBM_Flag
	,	t4.POP_AGE_85_up
	,	t4.POP_AVG_HH_SIZE
	,	t4.POP_PER_SQ_MILE_FY
	,	t4.HOUSING_AFFORDAB_INDEX
	,	t4.DIVERSITY_INDEX
	,	t4.MEDIAN_WHITE_FEMALE_AGE
	,	t4.MEDIAN_HISP_MALE_AGE
	,	t4.POP_HISPANIC_FY
	,	t4.HH_INCOME_0k_15k
	,	t4.HH_INCOME_200k
	,	t4.MEDIAN_NET_WORTH_65_74
	,	t4.HH_INCOME_15_25k_FY
	,	t4.UNEMPLOYMENT_RT
	,	t4.POP_65_up_IN_LABOR_FORCE
	,	t4.EDUC_NO_HS
	,	t4.EDUC_HS
	,	t4.TAPESTRY_SEGMENT
	,	t4.TAPESTRY_LIFESTYLE
	,	t4.TAPESTRY_URBAN
	,	t5.MA_Penetration_Rt
	,	t6.BENE_TotalValAdd
	,	t7.POS_Premium
	,	t7.POS_Inpatient
	,	t7.POS_Professional
	,	t7.PMPM_ValueAdd_YoY
	FROM output.t1_marketable_pop t1
	LEFT JOIN output.t1_addresses t1_a
		ON t1.AGLTY_INDIV_ID=t1_a.AGLTY_INDIV_ID
	LEFT JOIN output.t2_promotion_flags t2
		ON t1.AGLTY_INDIV_ID=t2.AGLTY_INDIV_ID
	LEFT JOIN output.t3_kbm t3
		ON t1.AGLTY_INDIV_ID=t3.AGLTY_INDIV_ID
	LEFT JOIN output.t4_tapestry t4
		ON t1.AGLTY_INDIV_ID=t4.AGLTY_INDIV_ID
	LEFT JOIN output.t5_cms t5
		ON t1.AGLTY_INDIV_ID=t5.AGLTY_INDIV_ID
		AND t1.Campaign=t5.Campaign
	LEFT JOIN output.t6_benefits t6
		ON t1.AGLTY_INDIV_ID=t6.AGLTY_INDIV_ID
		AND t1.Campaign=t6.Campaign
	LEFT JOIN output.t7_position t7
		ON t1.AGLTY_INDIV_ID=t7.AGLTY_INDIV_ID
		AND t1.Campaign=t7.Campaign
	LEFT JOIN MARS.INDIVIDUAL_MODEL_SCORE t8
		ON t1.AGLTY_INDIV_ID=t8.AGLTY_INDIV_ID
		AND t8.MODL_VRSN_NBR=191 /* Rachel J's last model score from 2021-07-13 */
	WHERE t1.Campaign='AEP';

	quit;

	proc means data=WS.MED_DM_22_Scoring_Final min q1 median q3 max;
	var HOSP_DIST_MSR
		MOB_DIST_MSR	
		AGE_VAL
		CENS_HH_CHILD_PCT
		CENS_HISPANIC_PCT
		CENS_MARRIED_PCT
		CENS_SINGLE_HOME_PCT
		CENS_WHITE_PCT
		HH_PERSS_CNT
		HH_CHILD_CNT
		LEN_RES_CD
		POP_AGE_85_up
		POP_AVG_HH_SIZE
		POP_PER_SQ_MILE_FY
		HOUSING_AFFORDAB_INDEX
		DIVERSITY_INDEX
		MEDIAN_WHITE_FEMALE_AGE
		MEDIAN_HISP_MALE_AGE
		POP_HISPANIC_FY
		HH_INCOME_0k_15k
		HH_INCOME_200k
		MEDIAN_NET_WORTH_65_74
		HH_INCOME_15_25k_FY
		UNEMPLOYMENT_RT
		POP_65_up_IN_LABOR_FORCE
		EDUC_NO_HS
		EDUC_HS
		MA_Penetration_Rt
		BENE_TotalValAdd
		POS_Premium
		POS_Inpatient
		POS_Professional
		PMPM_ValueAdd_YoY;
		run;



	
