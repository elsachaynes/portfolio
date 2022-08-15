
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

	* Output;
	%let output_files = /gpfsFS2/sasdata/nfs/ndc_grid/po_imca_digital/EHaynes/__Models/MED_ProspectTargeting_2022;
	libname output "&output_files";

/* -------------------------------------------------------------------------------------------------*/
/*  Promo IDs                                                                                       */
/* -------------------------------------------------------------------------------------------------*/

	* These were not coded correctly. Includes some FM and RNC. Will need to manually exclude
	them based on membership and response history;
	proc sql; *455 Promo IDs - 62 KPWA Promo IDs missing promotion history = 393;

	CREATE TABLE output.Promo_IDs AS
	SELECT DISTINCT
		Inhome_Date
	,	Region /* NL only? */
	,	Segment
	,	Campaign
	,	Channel
	,	strip(put(Promotionid,8.)) as PROMO_ID
	,	_00_Number
	,	Creative
	,	Offer
	,	Media_Detail
	,	Segments
	FROM MARS.c_campaign_matrix
	WHERE Inhome_Date >= "08DEC2020"d and Inhome_Date <= "07DEC2021"d /* SEP 2021 (12/8/2020-9/30/2021) + AEP 2022 (10/1/2021-12/7/2021) */
		AND Channel = 'DM'
		AND Campaign IN ('AEP','SEP')
		AND Region = 'NL'
		AND Segment = 'All non-mbrs'
		AND Media_Detail IN ('DM-EXP','DM-KBM');

	quit;

				* Tabulations;
				proc freq data=output.Promo_Ids;
				tables Inhome_Date
						Region
						Segment
						Campaign
						Channel
						Creative
						Offer
						Media_Detail
						Segments
						/ nocol norow nopercent;
				run;

	* Export;
	proc export data=output.Promo_IDs
	    outfile="&output_files/Promo_IDs.csv"
	    dbms=csv;
	run;
	data WS.MED_DM_22_Targeting_PromoIDs;
		set output.Promo_IDs;
	run;

/* -------------------------------------------------------------------------------------------------*/
/*  Promotion History                                                                               */
/* -------------------------------------------------------------------------------------------------*/

	proc sql; *36M;

	CREATE TABLE output.Promotion_History AS
	SELECT /*DISTINCT*/
		AGLTY_INDIV_ID
	,	PROMO_ID
	FROM MARS.INDIVIDUAL_PROMOTION_HISTORY
	WHERE PROMO_ID in (SELECT PROMO_ID FROM output.Promo_IDs);

	quit;

				* Cleaning/Confirming data quality;

				* Force char;
				data output.Promotion_History;
					set output.Promotion_History;
					AGLTY_INDIV_ID_CHAR = strip(put(AGLTY_INDIV_ID,32.));
				run;

	* Final Set;
	proc sql;

	CREATE TABLE output.Promotion_History AS
	SELECT DISTINCT
		x.*
	,	y.*
	FROM output.Promotion_History x
	LEFT JOIN output.promo_ids y
		on x.PROMO_ID=y.PROMO_ID;

	quit;

	proc sql;

	CREATE INDEX AGLTY_INDIV_ID_CHAR
		on output.Promotion_History(AGLTY_INDIV_ID_CHAR);

	quit;

	* Tabulate;
	proc sql;

	CREATE TABLE tabulation AS
	SELECT DISTINCT
		MONTH(Inhome_date) AS Month
	,	Campaign
	,	COUNT(AGLTY_INDIV_ID_CHAR) AS Letters_Mailed
	FROM output.Promotion_History 
	GROUP BY MONTH(Inhome_date) 
	,	Campaign;

	quit;

	/*
	1	SEP	1,685,236
	2	SEP	1,112,088
	3	SEP	1,083,100
	4	SEP	1,117,299
	5	SEP	1,565,893
	6	SEP	860,481
	7	SEP	1,772,751
	8	SEP	2,064,837
	9	SEP	1,807,749
	10	AEP	10,543,064
	11	AEP	10,184,115
	11	AEP	1,820,038
	12	AEP	199,851
	*/

	/* Unique Individuals: 5,480,517 */

	* Export;
	data WS.MED_DM_22_Targeting_AgilityIDs;
		set output.Promotion_History;
	run;
	
/* -------------------------------------------------------------------------------------------------*/
/*  KBM                                                                                             */
/* -------------------------------------------------------------------------------------------------*/

	proc sql;

	CREATE TABLE output.Demog_KBM AS
	SELECT DISTINCT
		*
	FROM MARS.INDIVIDUAL_KBM_PROSPECT
	WHERE strip(put(AGLTY_INDIV_ID,32.)) in (SELECT AGLTY_INDIV_ID_CHAR FROM output.Promotion_History);

	quit;

			* Cleaning/Confirming data quality;

			* Force char;
			data output.Demog_KBM;
				set output.Demog_KBM;
				AGLTY_INDIV_ID_CHAR = strip(put(AGLTY_INDIV_ID,32.));
			run;

			* Match % on KBM: 71.2%;
			proc sql;

			title 'KBM match rate';
			SELECT DISTINCT
				COUNT(DISTINCT y.AGLTY_INDIV_ID_CHAR)/
					COUNT(DISTINCT x.AGLTY_INDIV_ID_CHAR) AS PCT_MATCH_KBM format percent7.2
			FROM output.Promotion_History x
			LEFT JOIN output.Demog_KBM y
				on x.AGLTY_INDIV_ID_CHAR=y.AGLTY_INDIV_ID_CHAR;

			quit;

	* Export;
	data WS.MED_DM_22_Targeting_KBM;
		set output.Demog_KBM;
	run;

/* -------------------------------------------------------------------------------------------------*/
/*  Membership                                                                                      */
/* -------------------------------------------------------------------------------------------------*/

	proc sql;

	CREATE TABLE output.Membership AS
	SELECT 
		*
	FROM MARS.Member
	WHERE strip(put(AGLTY_INDIV_ID,32.)) IN (SELECT AGLTY_INDIV_ID_CHAR FROM output.Promotion_History);

	quit;

				* Cleaning/Confirming data quality;

				* Force char;
				data output.Membership;
					set output.Membership;
					AGLTY_INDIV_ID_CHAR = strip(put(AGLTY_INDIV_ID,32.));
				run;

	* Export;
	data WS.MED_DM_22_Targeting_Member;
		set output.Membership;
	run;

/* -------------------------------------------------------------------------------------------------*/
/*  Response                                                                                        */
/* -------------------------------------------------------------------------------------------------*/

	proc sql;

	CREATE TABLE output.Response_ILR AS
	SELECT 
		*
	FROM MARS.INDIVIDUAL_LEAD_RESPONSE
	WHERE strip(put(AGLTY_INDIV_ID,32.)) IN (SELECT AGLTY_INDIV_ID_CHAR FROM output.Promotion_History);

	quit;

				* Cleaning/Confirming data quality;

				* Force char;
				data output.Response_ILR;
					set output.Response_ILR;
					AGLTY_INDIV_ID_CHAR = strip(put(AGLTY_INDIV_ID,32.));
				run;

	* Export;
	data WS.MED_DM_22_Targeting_RespILR;
		set output.Response_ILR;
	run;

	proc sql;

	CREATE TABLE output.Response_ILMR AS
	SELECT 
		*
	FROM MARS.INDIVIDUAL_LEAD_MED_RESPONSE
	WHERE strip(put(AGLTY_INDIV_ID,32.)) IN (SELECT AGLTY_INDIV_ID_CHAR FROM output.Promotion_History);

	quit;

				* Cleaning/Confirming data quality;

				* Force char;
				data output.Response_ILMR;
					set output.Response_ILMR;
					AGLTY_INDIV_ID_CHAR = strip(put(AGLTY_INDIV_ID,32.));
				run;

	* Export;
	data WS.MED_DM_22_Targeting_RespILMR;
		set output.Response_ILMR;
	run;

	proc sql;

	CREATE TABLE output.Response_ILKR AS
	SELECT 
		*
	FROM MARS.INDIVIDUAL_LEAD_KPIF_RESPONSE
	WHERE strip(put(AGLTY_INDIV_ID,32.)) IN (SELECT AGLTY_INDIV_ID_CHAR FROM WS.MED_DM_22_Targeting_AgilityIDs /* output.Promotion_History*/);

	quit;

				* Cleaning/Confirming data quality;

				* Force char;
				data output.Response_ILKR;
					set output.Response_ILKR;
					AGLTY_INDIV_ID_CHAR = strip(put(AGLTY_INDIV_ID,32.));
				run;

	* Export;
	data WS.MED_DM_22_Targeting_RespILKR;
		set output.Response_ILKR;
	run;

/* -------------------------------------------------------------------------------------------------*/
/*  Address                                                                                         */
/* -------------------------------------------------------------------------------------------------*/

	* ----> append AGLTY_ADDR_ID in SQL Server (saved as WS.MED_DM_22_Targeting_Geo1_Char);
	* Geocode here and export back as WS.MED_DM_22_Targeting_Geocode1;

	proc sql;
	create table clean_up_geocode as
	select distinct
		aglty_indiv_id, aglty_addr_id_char
	from WS.MED_DM_22_Targeting_Geo1_Char;
	quit;
	data clean_up_geocode;
		set clean_up_geocode;
		if aglty_indiv_id = 5000042382961 and aglty_addr_id_char = '97386703323019131600100000859369' then delete;
		if aglty_indiv_id = 5500063392291 and aglty_addr_id_char = '56399046037789681500100000106173' then delete;
		if aglty_indiv_id = 5600032573493 and aglty_addr_id_char = '65638829236009411000100000000000' then delete;
		if aglty_indiv_id = 5000013058229 and aglty_addr_id_char = '12195388659078207000100000000000' then delete;
		if aglty_indiv_id = 5000038854472 and aglty_addr_id_char = '54970120364759670800100000000000' then delete;
		if aglty_indiv_id = 5000052297656 and aglty_addr_id_char = '45131897471209006500100000000000' then delete;
		if aglty_indiv_id = 5000052803855 and aglty_addr_id_char = '19868159655919574100100000000000' then delete;
		if aglty_indiv_id = 5000066627352 and aglty_addr_id_char = '31139463410009563900100000000000' then delete;
		if aglty_indiv_id = 5000067643001 and aglty_addr_id_char = '12760070911149266200100000000000' then delete;
		if aglty_indiv_id = 5000068142945 and aglty_addr_id_char = '40116573446149674400100000000000' then delete;
		if aglty_indiv_id = 5000529617195 and aglty_addr_id_char = '93156049614119284100100000000000' then delete;
		if aglty_indiv_id = 5600018393114 and aglty_addr_id_char = '35155305415829512900100000000000' then delete;
		if aglty_indiv_id = 5600031229714 and aglty_addr_id_char = '45871120797229565000100000000000' then delete;
		if aglty_indiv_id = 5600043407684 and aglty_addr_id_char = '85656024393719240400100000015835' then delete;
		if aglty_indiv_id = 5600046153998 and aglty_addr_id_char = '49266558463209452000100000465723' then delete;
		if aglty_indiv_id = 5600073605956 and aglty_addr_id_char = '40078525342059288600100000000000' then delete;
		if aglty_indiv_id = 5000024806658 and aglty_addr_id_char = '38001326244759215400100000282118' then delete;
		if aglty_indiv_id = 5000043487998 and aglty_addr_id_char = '12784487985359006600100000221378' then delete;
		if aglty_indiv_id = 5600069354507 and aglty_addr_id_char = '94328069835559203700100000891566' then delete;
		if aglty_indiv_id = 5000522444714 and aglty_addr_id_char = '74791886761489173300100000000000' then delete;
		if aglty_indiv_id = 5600032523032 and aglty_addr_id_char = '45580599589469142300100000000000' then delete;
		if aglty_indiv_id = 5600045585835 and aglty_addr_id_char = '55017297818853007500100000341248' then delete;
		if aglty_indiv_id = 5000038215491 and aglty_addr_id_char = '19494591856869582100100000595585' then delete;
		if aglty_indiv_id = 5000042683113 and aglty_addr_id_char = '67371961721019511200100000639810' then delete;
		if aglty_indiv_id = 5500016608685 and aglty_addr_id_char = '618034887519081000100000000000' then delete;
		run;
				proc sql;
					create table check_dups as
					select 
						t1.* , t2.ndups
					from clean_up_geocode t1
						, (select 
								AGLTY_INDIV_ID, count(*) as ndups
						   from clean_up_geocode
						   group by AGLTY_INDIV_ID
						   ) t2
					where t2.ndups>1 
						and t1.AGLTY_INDIV_ID=t2.AGLTY_INDIV_ID 
						order by t1.AGLTY_INDIV_ID;
				quit;
	
	proc sql;

	CREATE TABLE output.Geocode AS
	SELECT 
		ph.*
	,	geo.GEOCODE
	FROM clean_up_geocode ph
	LEFT JOIN MARS.GEOCODE_LKUP geo
		ON ph.AGLTY_ADDR_ID_CHAR=geo.AGLTY_ADDR_ID_VCHAR;

	quit;
	data WS.MED_DM_22_Targeting_Geocode;
		set output.Geocode;
	run;

				* Cleaning/Confirming data quality;

				* Force char;
				data output.Geocode;
					set output.Geocode;
					AGLTY_INDIV_ID_CHAR = strip(put(AGLTY_INDIV_ID,32.));
					WHERE Geocode ne '';
				run;

				* Match % on geocode: 99.8%;
				proc sql;

				title 'Geocode match rate';
				SELECT DISTINCT
					COUNT(DISTINCT geo.AGLTY_INDIV_ID)/
						COUNT(DISTINCT ph.AGLTY_INDIV_ID) AS PCT_MATCH_GEO format percent7.2
				FROM output.Promotion_History ph
				LEFT JOIN output.Geocode geo
					ON ph.AGLTY_INDIV_ID=geo.AGLTY_INDIV_ID;

				quit;


/* -------------------------------------------------------------------------------------------------*/
/*  Sample Subset                                                                                   */
/* -------------------------------------------------------------------------------------------------*/

	proc sql;

	CREATE TABLE output.Summary_Population AS
	SELECT DISTINCT 
		ph.AGLTY_INDIV_ID_CHAR 
	,	CASE WHEN geo.AGLTY_INDIV_ID_CHAR ne '' THEN 1 ELSE 0 END AS GEO
	,	CASE WHEN aep.AGLTY_INDIV_ID_CHAR ne '' THEN 1 ELSE 0 END AS AEP
	,	CASE WHEN sep.AGLTY_INDIV_ID_CHAR ne '' THEN 1 ELSE 0 END AS SEP
	,	CASE WHEN resp.AGLTY_INDIV_ID_CHAR ne '' THEN 1 ELSE 0 END AS RESP
	,	CASE WHEN mem.AGLTY_INDIV_ID_CHAR ne '' THEN 1 ELSE 0 END AS MEM
	FROM output.Promotion_History ph 
	LEFT JOIN (SELECT DISTINCT AGLTY_INDIV_ID_CHAR FROM output.Promotion_History WHERE Campaign = 'AEP') aep
		ON ph.AGLTY_INDIV_ID_CHAR=aep.AGLTY_INDIV_ID_CHAR
	LEFT JOIN (SELECT DISTINCT AGLTY_INDIV_ID_CHAR FROM output.Promotion_History WHERE Campaign = 'SEP') sep
		ON ph.AGLTY_INDIV_ID_CHAR=sep.AGLTY_INDIV_ID_CHAR
	LEFT JOIN (SELECT DISTINCT AGLTY_INDIV_ID_CHAR FROM output.Response_ILMR
					UNION
			   SELECT DISTINCT AGLTY_INDIV_ID_CHAR FROM output.Response_ILR) resp
		ON ph.AGLTY_INDIV_ID_CHAR=resp.AGLTY_INDIV_ID_CHAR
	LEFT JOIN (SELECT DISTINCT AGLTY_INDIV_ID_CHAR FROM output.Membership) mem
		ON ph.AGLTY_INDIV_ID_CHAR=mem.AGLTY_INDIV_ID_CHAR
	LEFT JOIN (SELECT DISTINCT AGLTY_INDIV_ID_CHAR FROM output.Geocode WHERE GEOCODE ne '') geo
		ON ph.AGLTY_INDIV_ID_CHAR=geo.AGLTY_INDIV_ID_CHAR
	;
	quit;

	proc sql;
	CREATE TABLE Summary AS
	SELECT DISTINCT
		SUM(GEO)/COUNT(AGLTY_INDIV_ID_CHAR) AS Pct_Geocoded format percent7.2
	,	SUM(AEP)/COUNT(AGLTY_INDIV_ID_CHAR) AS Pct_AEP format percent7.2
	,	SUM(SEP)/COUNT(AGLTY_INDIV_ID_CHAR) AS Pct_SEP format percent7.2
	,	SUM(RESP)/COUNT(AGLTY_INDIV_ID_CHAR) AS Pct_RESP format percent7.2
	,	SUM(MEM)/COUNT(AGLTY_INDIV_ID_CHAR) AS Pct_MEM format percent7.2
	FROM output.Summary_Population;
	quit;

	/*  71.8% received an AEP letter
		73.1% received an SEP letter
		3.16% responded this year or in years prior
		7.14% became members or had former member history
		88.0% were successfully geocoded
	*/

	proc sql; create table output.Unique_IDs as select distinct AGLTY_INDIV_ID_CHAR FROM output.Promotion_History; quit;

	proc surveyselect 
		data=output.Unique_IDs 
		method=srs 
		n=500000
        out=output.Sample;
	run;

				* Validate the sample has the same statuses;
				proc sql;

				CREATE TABLE output.Sample_Population AS
				SELECT DISTINCT 
					s.AGLTY_INDIV_ID_CHAR 
				,	CASE WHEN geo.AGLTY_INDIV_ID_CHAR ne '' THEN 1 ELSE 0 END AS GEO
				,	CASE WHEN aep.AGLTY_INDIV_ID_CHAR ne '' THEN 1 ELSE 0 END AS AEP
				,	CASE WHEN sep.AGLTY_INDIV_ID_CHAR ne '' THEN 1 ELSE 0 END AS SEP
				,	CASE WHEN resp.AGLTY_INDIV_ID_CHAR ne '' THEN 1 ELSE 0 END AS RESP
				,	CASE WHEN mem.AGLTY_INDIV_ID_CHAR ne '' THEN 1 ELSE 0 END AS MEM
				FROM output.Sample s 
				LEFT JOIN (SELECT DISTINCT AGLTY_INDIV_ID_CHAR FROM output.Promotion_History WHERE Campaign = 'AEP') aep
					ON s.AGLTY_INDIV_ID_CHAR=aep.AGLTY_INDIV_ID_CHAR
				LEFT JOIN (SELECT DISTINCT AGLTY_INDIV_ID_CHAR FROM output.Promotion_History WHERE Campaign = 'SEP') sep
					ON s.AGLTY_INDIV_ID_CHAR=sep.AGLTY_INDIV_ID_CHAR
				LEFT JOIN (SELECT DISTINCT AGLTY_INDIV_ID_CHAR FROM output.Response_ILMR
								UNION
						   SELECT DISTINCT AGLTY_INDIV_ID_CHAR FROM output.Response_ILR) resp
					ON s.AGLTY_INDIV_ID_CHAR=resp.AGLTY_INDIV_ID_CHAR
				LEFT JOIN (SELECT DISTINCT AGLTY_INDIV_ID_CHAR FROM output.Membership) mem
					ON s.AGLTY_INDIV_ID_CHAR=mem.AGLTY_INDIV_ID_CHAR
				LEFT JOIN (SELECT DISTINCT AGLTY_INDIV_ID_CHAR FROM output.Geocode WHERE GEOCODE ne '') geo
					ON s.AGLTY_INDIV_ID_CHAR=geo.AGLTY_INDIV_ID_CHAR
				;
				quit;

				proc sql;
				CREATE TABLE Summary AS
				SELECT DISTINCT
					SUM(GEO)/COUNT(AGLTY_INDIV_ID_CHAR) AS Pct_Geocoded format percent7.2
				,	SUM(AEP)/COUNT(AGLTY_INDIV_ID_CHAR) AS Pct_AEP format percent7.2
				,	SUM(SEP)/COUNT(AGLTY_INDIV_ID_CHAR) AS Pct_SEP format percent7.2
				,	SUM(RESP)/COUNT(AGLTY_INDIV_ID_CHAR) AS Pct_RESP format percent7.2
				,	SUM(MEM)/COUNT(AGLTY_INDIV_ID_CHAR) AS Pct_MEM format percent7.2
				FROM output.Sample_Population;
				quit;

			/*  71.7% received an AEP letter
				73.1% received an SEP letter
				3.16% responded this year or in years prior
				7.16% became members or had former member history
				88.1% were successfully geocoded
			*/

	* Export;
	data WS.MED_DM_22_Targeting_Sample;
		set output.Sample;
	run;

/* -------------------------------------------------------------------------------------------------*/
/*  Tapestry - Sample                                                                                        */
/* -------------------------------------------------------------------------------------------------*/

	proc sql;
		create table output.geocode_sample as
		select distinct
			*
		from output.Geocode
		where AGLTY_INDIV_ID_CHAR IN (SELECT AGLTY_INDIV_ID_CHAR FROM output.Sample);
	quit;

/*	inputTable = output.Sample or output.Geocode;*/
	options mprint;
	%macro split_into_batches(inputTable);
		%let i = 1;
		%let batchNum = 1;
		proc sql; select distinct count(*) into :nRows from &inputTable; quit;
		%do %while (&i < &nRows);
			data output.Tapestry_Batch_&batchNum;
				set &inputTable;
				if _N_ >= &i and _N_ < %eval(&i+100000);
			run;
			%let i = %eval(&i+100000);
			%let batchNum = %eval(&batchNum+1);
		%end;
		%let batchNumPull = 1;
		%do %while (&batchNumPull <= &batchNum);
			proc sql;

			CREATE TABLE output.Tapestry_Batch_&batchNumPull AS
			SELECT DISTINCT
				s.*

				/*	2020 population metrics */
			,	tap1.TOTPOP_CY AS POP_TOTAL
			,	tap1.POP60_CY AS POP_AGE_60_64
			,	tap1.POP65_CY AS POP_AGE_65_69
			,	tap1.POP70_CY AS POP_AGE_70_74
			,	tap1.POP75_CY AS POP_AGE_75_79
			,	tap1.POP80_CY AS POP_AGE_80_84
			,	tap1.POP85_CY AS POP_AGE_85_up
			,	tap1.MALE60_CY AS POP_AGE_60_64_M
			,	tap1.MALE65_CY AS POP_AGE_65_69_M
			,	tap1.FEM60_CY AS POP_AGE_60_64_F
			,	tap1.FEM65_CY AS POP_AGE_65_69_F
			,	tap1.BABYBOOMCY AS POP_BOOMER_1946_1964
			,	tap1.OLDRGENSCY AS POP_SILENT_pre_1945
			,	tap1.TOTHH_CY AS TOTAL_NUM_HOUSEHOLDS
			,	tap1.AVGHHSZ_CY AS POP_AVG_HH_SIZE
			,	tap1.POPDENS_CY AS POP_PER_SQ_MILE
			,	tap1.SENIOR_CY AS POP_65_up
			,	tap1.SENRDEP_CY AS POP_65_up_DEP_RATIO
			,	tap5.NEVMARR_CY AS POP_NEVER_MARRIED
			,	tap5.MARRIED_CY AS POP_MARRIED
			,	tap5.WIDOWED_CY AS POP_WIDOWED
			,	tap5.DIVORCD_CY AS POP_DIVORCED
				/*	2025 forecast population metrics */
			,	tap7.POPGRWCYFY AS POP_CMPD_ANNUAL_GRWTH_RT
			,	tap7.POP60_FY AS POP_AGE_60_64_FY
			,	tap7.POP65_FY AS POP_AGE_65_69_FY
			,	tap7.POP70_FY AS POP_AGE_70_74_FY
			,	tap7.POP75_FY AS POP_AGE_75_79_FY
			,	tap7.POP80_FY AS POP_AGE_80_84_FY
			,	tap7.POP85_FY AS POP_AGE_85_up_FY
			,	tap7.MALE60_FY AS POP_AGE_60_64_M_FY
			,	tap7.MALE65_FY AS POP_AGE_65_69_M_FY
			,	tap7.FEM60_FY AS POP_AGE_60_64_F_FY
			,	tap7.FEM65_FY AS POP_AGE_65_69_F_FY
			,	tap7.BABYBOOMFY AS POP_BOOMER_1946_1964_FY
			,	tap7.OLDRGENSFY AS POP_SILENT_pre_1945_FY
			,	tap7.TOTHH_FY AS TOTAL_NUM_HOUSEHOLDS_FY
			,	tap7.AVGHHSZ_FY AS POP_AVG_HH_SIZE_FY
			,	tap7.POPDENS_FY AS POP_PER_SQ_MILE_FY
			,	tap7.SENIOR_FY AS POP_65_up_FY
			,	tap7.SENRDEP_FY AS POP_65_up_DEP_RATIO_FY

				/*	2020 housing metrics */
			,	tap1.GQPOP_CY AS POP_GROUP_LIVING
			,	tap1.TOTHU_CY AS TOTAL_HOUSING_UNITS
			,	tap1.OWNER_CY AS OWNER_OCCUPIED_UNITS
			,	tap1.RENTER_CY AS RENTER_OCCUPIED_UNITS
			,	tap6.MEDVAL_CY AS MEDIAN_HOME_VALUE
			,	tap1.HAI_CY AS HOUSING_AFFORDAB_INDEX
			,	tap1.INCMORT_CY AS PCT_OF_INCOME_MORTGAGE
				/*	2025 forecast housing metrics */
			,	tap7.GQPOP_FY AS POP_GROUP_LIVING_FY
			,	tap7.TOTHU_FY AS TOTAL_HOUSING_UNITS_FY
			,	tap7.OWNER_FY AS OWNER_OCCUPIED_UNITS_FY
			,	tap7.RENTER_FY AS RENTER_OCCUPIED_UNITS_FY
			,	tap11.MEDVAL_FY AS MEDIAN_HOME_VALUE_FY
			,	tap7.OWNGRWCYFY AS OWNER_OCCUPIED_GRWTH_RT

				/* 2020 diversity metrics */
			,	tap5.DIVINDX_CY AS DIVERSITY_INDEX
			,	tap3.MEDWAGE_CY AS MEDIAN_WHITE_AGE
			,	tap3.MEDWMAGECY AS MEDIAN_WHITE_MALE_AGE
			,	tap3.WHTM60_CY AS POP_AGE_60_64_M_WHITE
			,	tap3.WHTM65_CY AS POP_AGE_65_69_M_WHITE
			,	tap3.MEDWFAGECY AS MEDIAN_WHITE_FEMALE_AGE
			,	tap3.WHTF60_CY AS POP_AGE_60_64_F_WHITE
			,	tap3.WHTF65_CY AS POP_AGE_65_69_F_WHITE
			,	tap3.MEDBAGE_CY AS MEDIAN_BLACK_AGE
			,	tap3.MEDBMAGECY AS MEDIAN_BLACK_MALE_AGE
			,	tap3.MEDBFAGECY AS MEDIAN_BLACK_FEMALE_AGE
			,	tap3.MEDAAGE_CY AS MEDIAN_ASIAN_AGE
			,	tap3.MEDAMAGECY AS MEDIAN_ASIAN_MALE_AGE
			,	tap3.MEDAFAGECY AS MEDIAN_ASIAN_FEMALE_AGE
			,	tap4.MEDPAGE_CY AS MEDIAN_ISLANDER_AGE
			,	tap4.MEDPMAGECY AS MEDIAN_ISLANDER_MALE_AGE
			,	tap4.MEDPFAGECY AS MEDIAN_ISLANDER_FEMALE_AGE
			,	tap4.MEDHAGE_CY AS MEDIAN_HISP_AGE
			,	tap4.MEDHMAGECY AS MEDIAN_HISP_MALE_AGE
			,	tap4.MEDHFAGECY AS MEDIAN_HISP_FEMALE_AGE
			,	tap3.WHT60_CY AS POP_WHITE_60_64
			,	tap3.WHT65_CY AS POP_WHITE_65_69
			,	tap3.BLK60_CY AS POP_BLACK_60_64
			,	tap3.BLK65_CY AS POP_BLACK_65_69
			,	tap3.ASN60_CY AS POP_ASIAN_60_64
			,	tap3.ASN65_CY AS POP_ASIAN_65_69
			,	tap4.PIM60_CY AS POP_ISLANDER_60_64
			,	tap4.PIM65_CY AS POP_ISLANDER_65_69
			,	tap4.HSP60_CY AS POP_HISP_60_64
			,	tap4.HSP65_CY AS POP_HISP_65_69
			,	tap5.WHITE_CY AS POP_WHITE
			,	tap5.BLACK_CY AS POP_BLACK
			,	tap5.ASIAN_CY AS POP_ASIAN
			,	tap5.PACIFIC_CY AS POP_PACIFIC
			,	tap5.HISPPOP_CY AS POP_HISPANIC
				/* 2025 diversity metrics */
			,	tap11.DIVINDX_FY AS DIVERSITY_INDEX_FY
			,	tap9.MEDWAGE_FY AS MEDIAN_WHITE_AGE_FY
			,	tap9.MEDWMAGEFY AS MEDIAN_WHITE_MALE_AGE_FY
			,	tap9.WHTM60_FY AS POP_AGE_60_64_M_WHITE_FY
			,	tap9.WHTM65_FY AS POP_AGE_65_69_M_WHITE_FY
			,	tap9.MEDWFAGEFY AS MEDIAN_WHITE_FEMALE_AGE_FY
			,	tap9.WHTF60_FY AS POP_AGE_60_64_F_WHITE_FY
			,	tap9.WHTF65_FY AS POP_AGE_65_69_F_WHITE_FY
			,	tap9.MEDBAGE_FY AS MEDIAN_BLACK_AGE_FY
			,	tap9.MEDBMAGEFY AS MEDIAN_BLACK_MALE_AGE_FY
			,	tap9.MEDBFAGEFY AS MEDIAN_BLACK_FEMALE_AGE_FY
			,	tap9.MEDAAGE_FY AS MEDIAN_ASIAN_AGE_FY
			,	tap9.MEDAMAGEFY AS MEDIAN_ASIAN_MALE_AGE_FY
			,	tap9.MEDAFAGEFY AS MEDIAN_ASIAN_FEMALE_AGE_FY
			,	tap10.MEDPAGE_FY AS MEDIAN_ISLANDER_AGE_FY
			,	tap10.MEDPMAGEFY AS MEDIAN_ISLANDER_MALE_AGE_FY
			,	tap10.MEDPFAGEFY AS MEDIAN_ISLANDER_FEMALE_AGE_FY
			,	tap10.MEDHAGE_FY AS MEDIAN_HISP_AGE_FY
			,	tap10.MEDHMAGEFY AS MEDIAN_HISP_MALE_AGE_FY
			,	tap10.MEDHFAGEFY AS MEDIAN_HISP_FEMALE_AGE_FY
			,	tap9.WHT60_FY AS POP_WHITE_60_64_FY
			,	tap9.WHT65_FY AS POP_WHITE_65_69_FY
			,	tap9.BLK60_FY AS POP_BLACK_60_64_FY
			,	tap9.BLK65_FY AS POP_BLACK_65_69_FY
			,	tap9.ASN60_FY AS POP_ASIAN_60_64_FY
			,	tap9.ASN65_FY AS POP_ASIAN_65_69_FY
			,	tap10.PIM60_FY AS POP_ISLANDER_60_64_FY
			,	tap10.PIM65_FY AS POP_ISLANDER_65_69_FY
			,	tap10.HSP60_FY AS POP_HISP_60_64_FY
			,	tap10.HSP65_FY AS POP_HISP_65_69_FY
			,	tap11.WHITE_FY AS POP_WHITE_FY
			,	tap11.BLACK_FY AS POP_BLACK_FY
			,	tap11.ASIAN_FY AS POP_ASIAN_FY
			,	tap11.PACIFIC_FY AS POP_PACIFIC_FY
			,	tap11.HISPPOP_FY AS POP_HISPANIC_FY

				/* 2020 financial metrics */
			,	tap5.MEDHINC_CY AS MEDIAN_HH_INCOME
			,	tap5.PCI_CY AS PER_CAPITA_INCOME
			,	tap2.WLTHINDXCY AS WEALTH_INDEX
			,	tap5.HINC0_CY AS HH_INCOME_0k_15k
			,	tap5.HINC15_CY AS HH_INCOME_15_25k
			,	tap5.HINC25_CY AS HH_INCOME_25_35k
			,	tap5.HINC35_CY AS HH_INCOME_35_50k
			,	tap5.HINC50_CY AS HH_INCOME_50_75k
			,	tap5.HINC75_CY AS HH_INCOME_75_100k
			,	tap5.HINC100_CY AS HH_INCOME_100_150k
			,	tap5.HINC150_CY AS HH_INCOME_150_200k
			,	tap5.HINC200_CY AS HH_INCOME_200k
			,	tap5.MEDIA55_CY AS MEDIAN_HH_INCOME_AGE_55_64
			,	tap5.MEDIA55UCY AS MEDIAN_HH_INCOME_AGE_55up
			,	tap5.IA55UBASCY AS HOUSEHOLDS_INCOME_AGE_55up
			,	tap5.MEDIA65_CY AS MEDIAN_HH_INCOME_AGE_65_74
			,	tap5.MEDIA65UCY AS MEDIAN_HH_INCOME_AGE_65up
			,	tap5.IA65UBASCY AS HOUSEHOLDS_INCOME_AGE_65up
			,	tap5.MEDIA75_CY AS MEDIAN_HH_INCOME_AGE_75up
			,	tap5.IA75BASECY AS HOUSEHOLDS_INCOME_AGE_75up
			,	tap6.MEDDI_CY AS MEDIAN_DISPOSABLE_INCOME
			,	tap6.MEDDIA55CY AS MEDIAN_DISP_INCOME_AGE_55_64
			,	tap6.MEDDIA65CY AS MEDIAN_DISP_INCOME_AGE_65_74
			,	tap6.MEDDIA75CY AS MEDIAN_DISP_INCOME_AGE_75up
			,	tap6.MEDNW_CY AS MEDIAN_NET_WORTH
			,	tap6.MEDNWA55CY AS MEDIAN_NET_WORTH_55_64
			,	tap6.MEDNWA65CY AS MEDIAN_NET_WORTH_65_74
			,	tap6.MEDNWA75CY AS MEDIAN_NET_WORTH_75up
				/* 2025 financial metrics */
			,	tap11.MEDHINC_FY AS MEDIAN_HH_INCOME_FY
			,	tap7.MHIGRWCYFY AS MEDIAN_HH_INCOME_GRWTH_RT
			,	tap7.PCIGRWCYFY AS PER_CAPITA_INCOME_GRWTH_RT
			,	tap11.HINC0_FY AS HH_INCOME_0k_15k_FY
			,	tap11.HINC15_FY AS HH_INCOME_15_25k_FY
			,	tap11.HINC25_FY AS HH_INCOME_25_35k_FY
			,	tap11.HINC35_FY AS HH_INCOME_35_50k_FY
			,	tap11.HINC50_FY AS HH_INCOME_50_75k_FY
			,	tap11.HINC75_FY AS HH_INCOME_75_100k_FY
			,	tap11.HINC100_FY AS HH_INCOME_100_150k_FY
			,	tap11.HINC150_FY AS HH_INCOME_150_200k_FY
			,	tap11.HINC200_FY AS HH_INCOME_200k_FY
			,	tap11.MEDIA55_FY AS MEDIAN_HH_INCOME_AGE_55_64_FY
			,	tap11.MEDIA55UFY AS MEDIAN_HH_INCOME_AGE_55up_FY
			,	tap11.IA55UBASFY AS HOUSEHOLDS_INCOME_AGE_55up_FY
			,	tap11.MEDIA65_FY AS MEDIAN_HH_INCOME_AGE_65_74_FY
			,	tap11.MEDIA65UFY AS MEDIAN_HH_INCOME_AGE_65up_FY
			,	tap11.MEDIA75_FY AS MEDIAN_HH_INCOME_AGE_75up_FY
			,	tap11.IA75BASEFY AS HOUSEHOLDS_INCOME_AGE_75up_FY

				/*	2020 labor metrics */
			,	tap5.CIVLBFR_CY AS POP_IN_LABOR_FORCE
			,	tap5.EMP_CY AS POP_EMPLOYED
			,	tap5.UNEMP_CY AS POP_UNEMPLOYED
			,	tap5.UNEMPRT_CY AS UNEMPLOYMENT_RT
			,	tap5.CIVLF65_CY AS POP_65_up_IN_LABOR_FORCE
			,	tap5.EMPAGE65CY AS POP_65_up_EMPLOYED

				/*	2020 education metrics */
			,	tap5.NOHS_CY AS EDUC_NO_HS
			,	tap5.SOMEHS_CY AS EDUC_SOME_HS
			,	tap5.HSGRAD_CY AS EDUC_HS
			,	tap5.GED_CY AS EDUC_GED
			,	tap5.SMCOLL_CY AS EDUC_SOME_COLLEGE
			,	tap5.ASSCDEG_CY AS EDUC_ASSOCIATE_DEGREE
			,	tap5.BACHDEG_CY AS EDUC_BACHELOR_DEGREE
			,	tap5.GRADDEG_CY AS EDUC_GRAD_DEGREE

			,	taphh.TSEGNAME AS TAPESTRY_SEGMENT
			,	taphh.TSEGCODE AS TAPESTRY_SEGMENT_CD
			,	taphh.TLIFENAME AS TAPESTRY_LIFESTYLE
			,	taphh.TURBZNAME AS TAPESTRY_URBAN

			FROM output.Tapestry_Batch_&batchNumPull s /* Change to name of your sample table */
			LEFT JOIN ESRI.CFY20_01 tap1
				ON s.GEOCODE=tap1.ID
			LEFT JOIN ESRI.CFY20_02 tap2
				ON s.GEOCODE=tap2.ID
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
			LEFT JOIN ESRI.CFY20_09 tap9
				ON s.GEOCODE=tap9.ID
			LEFT JOIN ESRI.CFY20_10 tap10
				ON s.GEOCODE=tap10.ID
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

	%split_into_batches(output.geocode_sample);	

	* Export;
	data WS.MED_DM_22_Targeting_TapestrySamp;
		set output.tapestry_batch_:;
	run;

/* -------------------------------------------------------------------------------------------------*/
/*  Full Tapestry                                                                                   */
/* -------------------------------------------------------------------------------------------------*/

	options mprint;
	%macro split_into_batches(inputTable);
		%let i = 1;
		%let batchNum = 1;
		proc sql; select distinct count(*) into :nRows from &inputTable; quit;
		%do %while (&i < &nRows);
			data output.Tapestry_Batch_&batchNum;
				set &inputTable;
				if _N_ >= &i and _N_ < %eval(&i+100000);
			run;
			%let i = %eval(&i+100000);
			%let batchNum = %eval(&batchNum+1);
		%end;
		%let batchNumPull = 1;
		%do %while (&batchNumPull <= &batchNum);
			proc sql;

			CREATE TABLE output.Tapestry_Batch_&batchNumPull AS
			SELECT DISTINCT
				s.*

				/*	2020 population metrics */
			,	tap1.TOTPOP_CY AS POP_TOTAL
			,	tap1.POP60_CY AS POP_AGE_60_64
			,	tap1.POP65_CY AS POP_AGE_65_69
			,	tap1.POP70_CY AS POP_AGE_70_74
			,	tap1.POP75_CY AS POP_AGE_75_79
			,	tap1.POP80_CY AS POP_AGE_80_84
			,	tap1.POP85_CY AS POP_AGE_85_up
			,	tap1.MALE60_CY AS POP_AGE_60_64_M
			,	tap1.MALE65_CY AS POP_AGE_65_69_M
			,	tap1.FEM60_CY AS POP_AGE_60_64_F
			,	tap1.FEM65_CY AS POP_AGE_65_69_F
			,	tap1.BABYBOOMCY AS POP_BOOMER_1946_1964
			,	tap1.OLDRGENSCY AS POP_SILENT_pre_1945
			,	tap1.TOTHH_CY AS TOTAL_NUM_HOUSEHOLDS
			,	tap1.AVGHHSZ_CY AS POP_AVG_HH_SIZE
			,	tap1.POPDENS_CY AS POP_PER_SQ_MILE
			,	tap1.SENIOR_CY AS POP_65_up
			,	tap1.SENRDEP_CY AS POP_65_up_DEP_RATIO
			,	tap5.NEVMARR_CY AS POP_NEVER_MARRIED
			,	tap5.MARRIED_CY AS POP_MARRIED
			,	tap5.WIDOWED_CY AS POP_WIDOWED
			,	tap5.DIVORCD_CY AS POP_DIVORCED
				/*	2025 forecast population metrics */
			,	tap7.POPGRWCYFY AS POP_CMPD_ANNUAL_GRWTH_RT
			,	tap7.POP60_FY AS POP_AGE_60_64_FY
			,	tap7.POP65_FY AS POP_AGE_65_69_FY
			,	tap7.POP70_FY AS POP_AGE_70_74_FY
			,	tap7.POP75_FY AS POP_AGE_75_79_FY
			,	tap7.POP80_FY AS POP_AGE_80_84_FY
			,	tap7.POP85_FY AS POP_AGE_85_up_FY
			,	tap7.MALE60_FY AS POP_AGE_60_64_M_FY
			,	tap7.MALE65_FY AS POP_AGE_65_69_M_FY
			,	tap7.FEM60_FY AS POP_AGE_60_64_F_FY
			,	tap7.FEM65_FY AS POP_AGE_65_69_F_FY
			,	tap7.BABYBOOMFY AS POP_BOOMER_1946_1964_FY
			,	tap7.OLDRGENSFY AS POP_SILENT_pre_1945_FY
			,	tap7.TOTHH_FY AS TOTAL_NUM_HOUSEHOLDS_FY
			,	tap7.AVGHHSZ_FY AS POP_AVG_HH_SIZE_FY
			,	tap7.POPDENS_FY AS POP_PER_SQ_MILE_FY
			,	tap7.SENIOR_FY AS POP_65_up_FY
			,	tap7.SENRDEP_FY AS POP_65_up_DEP_RATIO_FY

				/*	2020 housing metrics */
			,	tap1.GQPOP_CY AS POP_GROUP_LIVING
			,	tap1.TOTHU_CY AS TOTAL_HOUSING_UNITS
			,	tap1.OWNER_CY AS OWNER_OCCUPIED_UNITS
			,	tap1.RENTER_CY AS RENTER_OCCUPIED_UNITS
			,	tap6.MEDVAL_CY AS MEDIAN_HOME_VALUE
			,	tap1.HAI_CY AS HOUSING_AFFORDAB_INDEX
			,	tap1.INCMORT_CY AS PCT_OF_INCOME_MORTGAGE
				/*	2025 forecast housing metrics */
			,	tap7.GQPOP_FY AS POP_GROUP_LIVING_FY
			,	tap7.TOTHU_FY AS TOTAL_HOUSING_UNITS_FY
			,	tap7.OWNER_FY AS OWNER_OCCUPIED_UNITS_FY
			,	tap7.RENTER_FY AS RENTER_OCCUPIED_UNITS_FY
			,	tap11.MEDVAL_FY AS MEDIAN_HOME_VALUE_FY
			,	tap7.OWNGRWCYFY AS OWNER_OCCUPIED_GRWTH_RT

				/* 2020 diversity metrics */
			,	tap5.DIVINDX_CY AS DIVERSITY_INDEX
			,	tap3.MEDWAGE_CY AS MEDIAN_WHITE_AGE
			,	tap3.MEDWMAGECY AS MEDIAN_WHITE_MALE_AGE
			,	tap3.WHTM60_CY AS POP_AGE_60_64_M_WHITE
			,	tap3.WHTM65_CY AS POP_AGE_65_69_M_WHITE
			,	tap3.MEDWFAGECY AS MEDIAN_WHITE_FEMALE_AGE
			,	tap3.WHTF60_CY AS POP_AGE_60_64_F_WHITE
			,	tap3.WHTF65_CY AS POP_AGE_65_69_F_WHITE
			,	tap3.MEDBAGE_CY AS MEDIAN_BLACK_AGE
			,	tap3.MEDBMAGECY AS MEDIAN_BLACK_MALE_AGE
			,	tap3.MEDBFAGECY AS MEDIAN_BLACK_FEMALE_AGE
			,	tap3.MEDAAGE_CY AS MEDIAN_ASIAN_AGE
			,	tap3.MEDAMAGECY AS MEDIAN_ASIAN_MALE_AGE
			,	tap3.MEDAFAGECY AS MEDIAN_ASIAN_FEMALE_AGE
			,	tap4.MEDPAGE_CY AS MEDIAN_ISLANDER_AGE
			,	tap4.MEDPMAGECY AS MEDIAN_ISLANDER_MALE_AGE
			,	tap4.MEDPFAGECY AS MEDIAN_ISLANDER_FEMALE_AGE
			,	tap4.MEDHAGE_CY AS MEDIAN_HISP_AGE
			,	tap4.MEDHMAGECY AS MEDIAN_HISP_MALE_AGE
			,	tap4.MEDHFAGECY AS MEDIAN_HISP_FEMALE_AGE
			,	tap3.WHT60_CY AS POP_WHITE_60_64
			,	tap3.WHT65_CY AS POP_WHITE_65_69
			,	tap3.BLK60_CY AS POP_BLACK_60_64
			,	tap3.BLK65_CY AS POP_BLACK_65_69
			,	tap3.ASN60_CY AS POP_ASIAN_60_64
			,	tap3.ASN65_CY AS POP_ASIAN_65_69
			,	tap4.PIM60_CY AS POP_ISLANDER_60_64
			,	tap4.PIM65_CY AS POP_ISLANDER_65_69
			,	tap4.HSP60_CY AS POP_HISP_60_64
			,	tap4.HSP65_CY AS POP_HISP_65_69
			,	tap5.WHITE_CY AS POP_WHITE
			,	tap5.BLACK_CY AS POP_BLACK
			,	tap5.ASIAN_CY AS POP_ASIAN
			,	tap5.PACIFIC_CY AS POP_PACIFIC
			,	tap5.HISPPOP_CY AS POP_HISPANIC
				/* 2025 diversity metrics */
			,	tap11.DIVINDX_FY AS DIVERSITY_INDEX_FY
			,	tap9.MEDWAGE_FY AS MEDIAN_WHITE_AGE_FY
			,	tap9.MEDWMAGEFY AS MEDIAN_WHITE_MALE_AGE_FY
			,	tap9.WHTM60_FY AS POP_AGE_60_64_M_WHITE_FY
			,	tap9.WHTM65_FY AS POP_AGE_65_69_M_WHITE_FY
			,	tap9.MEDWFAGEFY AS MEDIAN_WHITE_FEMALE_AGE_FY
			,	tap9.WHTF60_FY AS POP_AGE_60_64_F_WHITE_FY
			,	tap9.WHTF65_FY AS POP_AGE_65_69_F_WHITE_FY
			,	tap9.MEDBAGE_FY AS MEDIAN_BLACK_AGE_FY
			,	tap9.MEDBMAGEFY AS MEDIAN_BLACK_MALE_AGE_FY
			,	tap9.MEDBFAGEFY AS MEDIAN_BLACK_FEMALE_AGE_FY
			,	tap9.MEDAAGE_FY AS MEDIAN_ASIAN_AGE_FY
			,	tap9.MEDAMAGEFY AS MEDIAN_ASIAN_MALE_AGE_FY
			,	tap9.MEDAFAGEFY AS MEDIAN_ASIAN_FEMALE_AGE_FY
			,	tap10.MEDPAGE_FY AS MEDIAN_ISLANDER_AGE_FY
			,	tap10.MEDPMAGEFY AS MEDIAN_ISLANDER_MALE_AGE_FY
			,	tap10.MEDPFAGEFY AS MEDIAN_ISLANDER_FEMALE_AGE_FY
			,	tap10.MEDHAGE_FY AS MEDIAN_HISP_AGE_FY
			,	tap10.MEDHMAGEFY AS MEDIAN_HISP_MALE_AGE_FY
			,	tap10.MEDHFAGEFY AS MEDIAN_HISP_FEMALE_AGE_FY
			,	tap9.WHT60_FY AS POP_WHITE_60_64_FY
			,	tap9.WHT65_FY AS POP_WHITE_65_69_FY
			,	tap9.BLK60_FY AS POP_BLACK_60_64_FY
			,	tap9.BLK65_FY AS POP_BLACK_65_69_FY
			,	tap9.ASN60_FY AS POP_ASIAN_60_64_FY
			,	tap9.ASN65_FY AS POP_ASIAN_65_69_FY
			,	tap10.PIM60_FY AS POP_ISLANDER_60_64_FY
			,	tap10.PIM65_FY AS POP_ISLANDER_65_69_FY
			,	tap10.HSP60_FY AS POP_HISP_60_64_FY
			,	tap10.HSP65_FY AS POP_HISP_65_69_FY
			,	tap11.WHITE_FY AS POP_WHITE_FY
			,	tap11.BLACK_FY AS POP_BLACK_FY
			,	tap11.ASIAN_FY AS POP_ASIAN_FY
			,	tap11.PACIFIC_FY AS POP_PACIFIC_FY
			,	tap11.HISPPOP_FY AS POP_HISPANIC_FY

				/* 2020 financial metrics */
			,	tap5.MEDHINC_CY AS MEDIAN_HH_INCOME
			,	tap5.PCI_CY AS PER_CAPITA_INCOME
			,	tap2.WLTHINDXCY AS WEALTH_INDEX
			,	tap5.HINC0_CY AS HH_INCOME_0k_15k
			,	tap5.HINC15_CY AS HH_INCOME_15_25k
			,	tap5.HINC25_CY AS HH_INCOME_25_35k
			,	tap5.HINC35_CY AS HH_INCOME_35_50k
			,	tap5.HINC50_CY AS HH_INCOME_50_75k
			,	tap5.HINC75_CY AS HH_INCOME_75_100k
			,	tap5.HINC100_CY AS HH_INCOME_100_150k
			,	tap5.HINC150_CY AS HH_INCOME_150_200k
			,	tap5.HINC200_CY AS HH_INCOME_200k
			,	tap5.MEDIA55_CY AS MEDIAN_HH_INCOME_AGE_55_64
			,	tap5.MEDIA55UCY AS MEDIAN_HH_INCOME_AGE_55up
			,	tap5.IA55UBASCY AS HOUSEHOLDS_INCOME_AGE_55up
			,	tap5.MEDIA65_CY AS MEDIAN_HH_INCOME_AGE_65_74
			,	tap5.MEDIA65UCY AS MEDIAN_HH_INCOME_AGE_65up
			,	tap5.IA65UBASCY AS HOUSEHOLDS_INCOME_AGE_65up
			,	tap5.MEDIA75_CY AS MEDIAN_HH_INCOME_AGE_75up
			,	tap5.IA75BASECY AS HOUSEHOLDS_INCOME_AGE_75up
			,	tap6.MEDDI_CY AS MEDIAN_DISPOSABLE_INCOME
			,	tap6.MEDDIA55CY AS MEDIAN_DISP_INCOME_AGE_55_64
			,	tap6.MEDDIA65CY AS MEDIAN_DISP_INCOME_AGE_65_74
			,	tap6.MEDDIA75CY AS MEDIAN_DISP_INCOME_AGE_75up
			,	tap6.MEDNW_CY AS MEDIAN_NET_WORTH
			,	tap6.MEDNWA55CY AS MEDIAN_NET_WORTH_55_64
			,	tap6.MEDNWA65CY AS MEDIAN_NET_WORTH_65_74
			,	tap6.MEDNWA75CY AS MEDIAN_NET_WORTH_75up
				/* 2025 financial metrics */
			,	tap11.MEDHINC_FY AS MEDIAN_HH_INCOME_FY
			,	tap7.MHIGRWCYFY AS MEDIAN_HH_INCOME_GRWTH_RT
			,	tap7.PCIGRWCYFY AS PER_CAPITA_INCOME_GRWTH_RT
			,	tap11.HINC0_FY AS HH_INCOME_0k_15k_FY
			,	tap11.HINC15_FY AS HH_INCOME_15_25k_FY
			,	tap11.HINC25_FY AS HH_INCOME_25_35k_FY
			,	tap11.HINC35_FY AS HH_INCOME_35_50k_FY
			,	tap11.HINC50_FY AS HH_INCOME_50_75k_FY
			,	tap11.HINC75_FY AS HH_INCOME_75_100k_FY
			,	tap11.HINC100_FY AS HH_INCOME_100_150k_FY
			,	tap11.HINC150_FY AS HH_INCOME_150_200k_FY
			,	tap11.HINC200_FY AS HH_INCOME_200k_FY
			,	tap11.MEDIA55_FY AS MEDIAN_HH_INCOME_AGE_55_64_FY
			,	tap11.MEDIA55UFY AS MEDIAN_HH_INCOME_AGE_55up_FY
			,	tap11.IA55UBASFY AS HOUSEHOLDS_INCOME_AGE_55up_FY
			,	tap11.MEDIA65_FY AS MEDIAN_HH_INCOME_AGE_65_74_FY
			,	tap11.MEDIA65UFY AS MEDIAN_HH_INCOME_AGE_65up_FY
			,	tap11.MEDIA75_FY AS MEDIAN_HH_INCOME_AGE_75up_FY
			,	tap11.IA75BASEFY AS HOUSEHOLDS_INCOME_AGE_75up_FY

				/*	2020 labor metrics */
			,	tap5.CIVLBFR_CY AS POP_IN_LABOR_FORCE
			,	tap5.EMP_CY AS POP_EMPLOYED
			,	tap5.UNEMP_CY AS POP_UNEMPLOYED
			,	tap5.UNEMPRT_CY AS UNEMPLOYMENT_RT
			,	tap5.CIVLF65_CY AS POP_65_up_IN_LABOR_FORCE
			,	tap5.EMPAGE65CY AS POP_65_up_EMPLOYED

				/*	2020 education metrics */
			,	tap5.NOHS_CY AS EDUC_NO_HS
			,	tap5.SOMEHS_CY AS EDUC_SOME_HS
			,	tap5.HSGRAD_CY AS EDUC_HS
			,	tap5.GED_CY AS EDUC_GED
			,	tap5.SMCOLL_CY AS EDUC_SOME_COLLEGE
			,	tap5.ASSCDEG_CY AS EDUC_ASSOCIATE_DEGREE
			,	tap5.BACHDEG_CY AS EDUC_BACHELOR_DEGREE
			,	tap5.GRADDEG_CY AS EDUC_GRAD_DEGREE

			,	taphh.TSEGNAME AS TAPESTRY_SEGMENT
			,	taphh.TSEGCODE AS TAPESTRY_SEGMENT_CD
			,	taphh.TLIFENAME AS TAPESTRY_LIFESTYLE
			,	taphh.TURBZNAME AS TAPESTRY_URBAN

			FROM output.Tapestry_Batch_&batchNumPull s /* Change to name of your sample table */
			LEFT JOIN ESRI.CFY20_01 tap1
				ON s.GEOCODE=tap1.ID
			LEFT JOIN ESRI.CFY20_02 tap2
				ON s.GEOCODE=tap2.ID
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
			LEFT JOIN ESRI.CFY20_09 tap9
				ON s.GEOCODE=tap9.ID
			LEFT JOIN ESRI.CFY20_10 tap10
				ON s.GEOCODE=tap10.ID
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

	%split_into_batches(output.geocode);

	* Export;
	data WS.MED_DM_22_Targeting_Tapestry;
		set output.tapestry_batch_:;
	run;


/* -------------------------------------------------------------------------------------------------*/
/*  Address                                                                                         */
/* -------------------------------------------------------------------------------------------------*/

	/* ---> pull Address data from SQL server */
	/* Append County FIPS */
	proc sql;
	CREATE TABLE output.Address1 AS
		SELECT
			ph.*
		,	geo.COUNTYFIPS
	FROM WS.MED_DM_22_Targeting_Address ph /* Change to name of your agility ID table */
	LEFT JOIN MARS.GEOCODE_LKUP geo
		ON ph.AGLTY_ADDR_ID_VCHAR=geo.AGLTY_ADDR_ID_VCHAR;
	quit;
	proc sql;
	CREATE TABLE output.Address1 AS
	SELECT DISTINCT * FROM output.Address1 adr
	INNER JOIN output.Geocode geo
		ON adr.AGLTY_INDIV_ID=geo.AGLTY_INDIV_ID
		AND adr.AGLTY_ADDR_ID_VCHAR=geo.AGLTY_ADDR_ID_CHAR;
	quit;
	
				* Cleaning/Confirming data quality;
				proc sql;
					create table check_dups as
					select 
						t1.* , t2.ndups
					from output.Address1 t1
						, (select 
								AGLTY_INDIV_ID, count(*) as ndups
						   from output.Address1
						   group by AGLTY_INDIV_ID
						   ) t2
					where t2.ndups>1 
						and t1.AGLTY_INDIV_ID=t2.AGLTY_INDIV_ID 
						order by t1.AGLTY_INDIV_ID;
				quit;

				* Force char;
				data output.Address;
					set output.Address1;
					AGLTY_INDIV_ID_CHAR = strip(put(AGLTY_INDIV_ID,32.));
				run;

				* Clean up address for joining;
				data output.Address;
					format KP_Region $4.;
					set output.Address;
					* Field for joining by Region;
					if REGN_CD = 'CA' then KP_Region = SUB_REGN_CD;
						else KP_Region = REGN_CD;
					if REGN_CD = '' then REGN_CD = 'OOA';
					if SUB_REGN_CD = '' then SUB_REGN_CD = 'OOA';
					if CNTY_NM = '' then CNTY_NM = 'OOA';
						if CNTY_NM = 'PRINCE GEORGES' then CNTY_NM = "PRINCE GEORGE'S";
					if ST_CD = '' then ST_CD = 'OOA';
					if SVC_AREA_NM = '' then SVC_AREA_NM = 'OOA';

				run;

	* Export;
	proc export data=output.Address
	    outfile="&output_files/Address.csv"
	    dbms=csv replace;
	run;
	data WS.MED_DM_22_Targeting_Address;
		set output.Address;
	run;

/* -------------------------------------------------------------------------------------------------*/
/*  Medicare Penetration                                                                                        */
/* -------------------------------------------------------------------------------------------------*/

	proc import
		datafile="&output_files/Medicare Penetration CMS/State_County_Penetration_MA_2020_11.csv"
		out=output.MAPenetration_2020_11
		dbms=csv replace;
	run;
	proc import
		file="&output_files/Medicare Penetration CMS/State_County_Penetration_MA_2021_05.csv"
		out=output.MAPenetration_2021_05
		dbms=csv replace;
	run;

	data output.MAPenetration_2020_11;
		set output.MAPenetration_2020_11;
		keep Season fipsst fipscnty SEP_Eligibles SEP_Enrolled SEP_Penetration_Rt;
		SEP_Eligibles = input(Eligibles,comma8.);
		SEP_Enrolled = input(Enrolled,comma8.);
		SEP_Penetration_Rt = input(Penetration,percent7.2);
	run;
	data output.MAPenetration_2021_05;
		set output.MAPenetration_2021_05;
		keep Season fipsst fipscnty AEP_Eligibles AEP_Enrolled AEP_Penetration_Rt;
		AEP_Eligibles = input(Eligibles,comma8.);
		AEP_Enrolled = input(Enrolled,comma8.);
		AEP_Penetration_Rt = input(Penetration,percent7.2);
	run;

	proc sort data=output.MAPenetration_2021_05; by FIPSST FIPSCNTY; run;
	proc sort data=output.MAPenetration_2020_11; by FIPSST FIPSCNTY; run;
	data output.MAPenetration;
		merge output.MAPenetration_2021_05(in=a)
			output.MAPenetration_2020_11(in=b);
		by FIPSST FIPSCNTY;
	run;

	proc sql;
	create table output.MAPenetration as
	select
		ph.AGLTY_INDIV_ID_CHAR
	,	ph.Campaign
	,	adr.COUNTYFIPS
	,	case when ph.Campaign = 'AEP' then ma.AEP_Eligibles else ma.SEP_Eligibles end as MA_Eligibles 
	,	case when ph.Campaign = 'AEP' then ma.AEP_Enrolled else ma.SEP_Enrolled end as MA_Enrolled 
	,	case when ph.Campaign = 'AEP' then ma.AEP_Penetration_Rt else ma.SEP_Penetration_Rt end as MA_Penetration_Rt 
	from output.Promotion_History ph
	left join output.Address adr
		on ph.AGLTY_INDIV_ID_CHAR=adr.AGLTY_INDIV_ID_CHAR
	left join output.MAPENETRATION ma
		on adr.COUNTYFIPS=catt(ma.FIPSST,ma.FIPSCNTY);
	quit;
	
				* Match % on MA penetration: 99.3%;
				proc sql;

				title 'MA Penetration match rate';
				SELECT DISTINCT
					COUNT(DISTINCT CASE WHEN ma.MA_Eligibles ne . THEN AGLTY_INDIV_ID END)/
						COUNT(DISTINCT ph.AGLTY_INDIV_ID_CHAR) AS PCT_MATCH format percent7.2
				FROM output.Promotion_History ph
				LEFT JOIN output.MAPenetration ma
					ON ph.AGLTY_INDIV_ID_CHAR=ma.AGLTY_INDIV_ID_CHAR;
				title;

				quit;

	* Export;
	proc export data=output.MAPenetration
	    outfile="&output_files/MAPenetration.csv"
	    dbms=csv replace;
	run;
	data WS.MED_DM_22_Targeting_MAPen;
		set output.MAPenetration;
	run;

/* -------------------------------------------------------------------------------------------------*/
/*  Benefits (highest value plan)                                                                   */
/* -------------------------------------------------------------------------------------------------*/

	proc import
		datafile="&output_files/Medicare KP Benefits/Medicare_KP_Benefit_By_County_2021.csv"
		out=output.Benefits_2021
		dbms=csv replace;
		guessingrows=max;
	run;
	proc import
		file="&output_files/Medicare KP Benefits/Medicare_KP_Benefit_By_County_2022.csv"
		out=output.Benefits_2022
		dbms=csv replace;
		guessingrows=max;
	run;
	data output.Benefits;
		set output.Benefits_2021
			output.Benefits_2022;
	run;
	proc delete data=output.Benefits_2021; run;
	proc delete data=output.Benefits_2022; run;

	data output.Benefits;
		retain Campaign KP_Region County 'Measure Names'n 'Measure Values'n;
		set output.Benefits;
		keep Campaign KP_Region County 'Measure Names'n 'Measure Values'n;

		if 'Plan Value'n = 'Highest Value Plan'; * There are also 1-2 lesser value plans;

		if 'Plan Year'n = 2021 then Campaign = 'SEP';
			else if 'Plan Year'n = 2022 then Campaign = 'AEP';

		if strip('KP Region'n) = 'NCAL' then KP_Region = 'CANC';
			else if strip('KP Region'n) = 'SCAL' then KP_Region = 'CASC' ;
			else if strip('KP Region'n) = 'CO' then KP_Region = 'CO';
			else if strip('KP Region'n) = 'GA' then KP_Region = 'GA';
			else if strip('KP Region'n) = 'HI' then KP_Region = 'HI';
			else if strip('KP Region'n) = 'WA' then KP_Region = 'WA';
			else if strip('KP Region'n) = 'NW' then KP_Region = 'NW';
			else if strip('KP Region'n) = 'MAS' then KP_Region = 'MR';
			else KP_Region = strip('KP Region'n);

		County = upcase(County);

		drop 'Plan Value'n 'KP Region'n 'Plan Year'n 'Contract - Plan'n 'Parent Carrier'n 'Part C / Part D Coverage'n 
			'Plan Crosswalk'n 'ssa plan'n;

	run;

	proc sort data=output.Benefits; by Campaign KP_Region County; run;
	proc transpose
		data=output.Benefits
		out=output.Benefits(drop=_Name_) prefix=BENE_ ;
		by Campaign KP_Region County;
		id 'Measure Names'n;
		var 'Measure Values'n;
	run;
/*	PROC UNIVARIATE DATA = output.Benefits;*/
/*		VAR 'BENE_Total Value Added'n BENE_Enrollment*/
/*			BENE_MOOP 'BENE_Retail Tier 3'n*/
/*			'BENE_Retail Tier 2'n 'BENE_Retail Tier 1'n*/
/*			'BENE_Emergency Room'n 'BENE_x-ray'n*/
/*			BENE_Lab 'BENE_Inpatient Copay'n BENE_Specialist*/
/*			BENE_pcp 'BENE_Part B Premium Buy-Down'n BENE_Premium*/
/*			'BENE_aep growth'n;*/
/*		HISTOGRAM;*/
/*	RUN;*/
	data output.Benefits;
		format Campaign $3. KP_Region $4. County $50.
				'BENE_Total Value Added'n dollar18.2
				'BENE_Inpatient Copay'n dollar18.
				BENE_Specialist dollar18.
				BENE_Premium dollar18.
				'BENE_AEP GROWTH'N dollar18.
				BENE_MOOP dollar18.;
		set output.Benefits;
		keep Campaign KP_Region County 'BENE_Total Value Added'n 'BENE_Inpatient Copay'n BENE_MOOP
			 BENE_Specialist BENE_Premium 'BENE_AEP GROWTH'N;
		rename 'BENE_Total Value Added'n = BENE_TotalValAdd
			   'BENE_Inpatient Copay'n = BENE_InpatientCopay 
			   BENE_Specialist = BENE_SpecialistCopay
			   'BENE_AEP GROWTH'N = BENE_AEPGrowth
				;
	run;

	proc sql;
	create table output.benefits as
	select distinct
		ph.AGLTY_INDIV_ID_CHAR
	,	ph.Campaign
	/* Benefits */
	,	b.BENE_TotalValAdd
	,	b.BENE_InpatientCopay
	,	b.BENE_SpecialistCopay
	,	b.BENE_AEPGrowth
	/* Address */
	,	case when adr.CNTY_NM = '' then 1 else 0 end as COUNTY_OOA
	,	adr.CNTY_NM
	,	adr.KP_Region
	from output.promotion_history ph
	left join output.Address adr
		on ph.AGLTY_INDIV_ID_CHAR=adr.AGLTY_INDIV_ID_CHAR
	left join output.Benefits b
		on adr.KP_Region=b.KP_Region
		and adr.CNTY_NM=b.County
		and ph.Campaign=b.Campaign;
	quit;

				* Match % on benefits: 98.7%;
				proc sql;

				title 'Benefits match rate';
				SELECT DISTINCT
					COUNT(DISTINCT CASE WHEN b.BENE_TotalValAdd ne . THEN AGLTY_INDIV_ID END)/
						COUNT(DISTINCT ph.AGLTY_INDIV_ID_CHAR) AS PCT_MATCH format percent7.2
				FROM output.Promotion_History ph
				LEFT JOIN output.Benefits b
					ON ph.AGLTY_INDIV_ID_CHAR=b.AGLTY_INDIV_ID_CHAR;
				title;

				quit;

	* Export;
	data WS.MED_DM_22_Targeting_Benefits;
		set output.Benefits;
	run;

/* -------------------------------------------------------------------------------------------------*/
/*  Market Share and Position                                                                       */
/* -------------------------------------------------------------------------------------------------*/

	proc import
		datafile="&output_files/Medicare Market Share and Position/KP_2022_Market_Position_PMPM_By_Benefit_By_KPRegion.csv"
		out=output.Position_2022
		dbms=csv replace;
		guessingrows=max;
	run;
			data output.Position_2022;
				set output.Position_2022;

				Campaign = 'AEP';
				
				if strip('KP Region'n) = 'NCAL' then KP_Region = 'CANC';
					else if strip('KP Region'n) = 'SCAL' then KP_Region = 'CASC' ;
					else if strip('KP Region'n) = 'CO' then KP_Region = 'CO';
					else if strip('KP Region'n) = 'GA' then KP_Region = 'GA';
					else if strip('KP Region'n) = 'HI' then KP_Region = 'HI';
					else if strip('KP Region'n) = 'WA' then KP_Region = 'WA';
					else if strip('KP Region'n) = 'NW' then KP_Region = 'NW';
					else if strip('KP Region'n) = 'MAS' then KP_Region = 'MR';
					else KP_Region = strip('KP Region'n);
				drop 'KP Region'n;

				rename Premium = POS_Premium
						'Part B Premium Buy-Down'n = POS_PartBBuyDown
						'Inpatient Benefit'n = POS_Inpatient
						'Outpatient Benefit'n = POS_Outpatient
						'Professional Benefit'n = POS_Professional
						'omc benefit'n = POS_OMC
						'Supplemental Benefit'n = POS_Supplemental
						'Drug Benefit'n = POS_Drug
						'Market Position'n = Market_Position;

			run;
	proc import
		file="&output_files/Medicare Market Share and Position/KP_2022_Market_Share_By_County.csv"
		out=output.Share_2022
		dbms=csv replace;
		guessingrows=max;
	run;
			data output.Share_2022;

				format Campaign $3. ST_CD $2. County $50.
						Market_Share percent7. 'Avg. Total PMPM Value Add Curr Y'n dollar18.
						'pmpm change yoy'n dollar18.;
				set output.Share_2022;

				Campaign = 'AEP';
				
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

				Market_Share = input('Avg. KP MA Market Share Curr Yea'n,percent7.);
				drop 'Avg. KP MA Market Share Curr Yea'n;

				rename 'Avg. Total PMPM Value Add Curr Y'n = PMPM_ValueAdd
						'pmpm change yoy'n = PMPM_ValueAdd_YoY;

			run;
	proc import
		file="&output_files/Medicare Market Share and Position/KP_Historical_Total_Value_Added_By_KPRegion.csv"
		out=output.ValueAdd_Historical
		dbms=csv replace;
		guessingrows=max;
	run;
			data output.Valueadd_historical1;

				set output.Valueadd_historical;

				Campaign = 'AEP';

				if strip('KP Region'n) = 'NCAL' then KP_Region = 'CANC';
					else if strip('KP Region'n) = 'SCAL' then KP_Region = 'CASC' ;
					else if strip('KP Region'n) = 'CO' then KP_Region = 'CO';
					else if strip('KP Region'n) = 'GA' then KP_Region = 'GA';
					else if strip('KP Region'n) = 'HI' then KP_Region = 'HI';
					else if strip('KP Region'n) = 'WA' then KP_Region = 'WA';
					else if strip('KP Region'n) = 'NW' then KP_Region = 'NW';
					else if strip('KP Region'n) = 'MAS' then KP_Region = 'MR';
					else KP_Region = strip('KP Region'n);
				drop 'KP Region'n;

				PMPM_ValueAdd_Lag1Yr_Cum = sum('2022'n,'2021'n); 
				PMPM_ValueAdd_Lag2Yr_Cum = sum('2022'n,'2021'n,'2020'n); 
				PMPM_ValueAdd_Lag3Yr_Cum = sum('2022'n,'2021'n,'2020'n,'2019'n);
				PMPM_ValueAdd_Lag4Yr_Cum = sum('2022'n,'2021'n,'2020'n,'2019'n,'2018'n);
				PMPM_ValueAdd_Lag5Yr_Cum = sum('2022'n,'2021'n,'2020'n,'2019'n,'2018'n,'2017'n);

				drop '2017'N '2018'N '2019'N '2020'N '2021'N '2022'N;
				drop 'Value Add Category'n;

			run;
			data output.Valueadd_historical2;

				set output.Valueadd_historical;

				Campaign = 'SEP';

				if strip('KP Region'n) = 'NCAL' then KP_Region = 'CANC';
					else if strip('KP Region'n) = 'SCAL' then KP_Region = 'CASC' ;
					else if strip('KP Region'n) = 'CO' then KP_Region = 'CO';
					else if strip('KP Region'n) = 'GA' then KP_Region = 'GA';
					else if strip('KP Region'n) = 'HI' then KP_Region = 'HI';
					else if strip('KP Region'n) = 'WA' then KP_Region = 'WA';
					else if strip('KP Region'n) = 'NW' then KP_Region = 'NW';
					else if strip('KP Region'n) = 'MAS' then KP_Region = 'MR';
					else KP_Region = strip('KP Region'n);
				drop 'KP Region'n;

				PMPM_ValueAdd_Lag1Yr_Cum = sum('2021'n,'2020'n); 
				PMPM_ValueAdd_Lag2Yr_Cum = sum('2021'n,'2020'n,'2019'n); 
				PMPM_ValueAdd_Lag3Yr_Cum = sum('2021'n,'2020'n,'2019'n,'2018'n);
				PMPM_ValueAdd_Lag4Yr_Cum = sum('2021'n,'2020'n,'2019'n,'2018'n,'2017'n);

				drop '2017'N '2018'N '2019'N '2020'N '2021'N '2022'N;
				drop 'Value Add Category'n;

			run;

			data output.ValueAdd_Historical;
				set output.Valueadd_historical1
					output.Valueadd_historical2;
			run;

			proc delete data=output.Valueadd_historical1; run;
			proc delete data=output.valueadd_historical2; run;

	proc sql;
	create table output.Position_Share as
	select distinct
		ph.AGLTY_INDIV_ID_CHAR
	,	ph.Campaign
	,	adr.KP_Region
	,	adr.ST_CD
	,	adr.CNTY_NM
	/* Position 2022 */
	,	b.Market_Position
	,	b.POS_Premium
	,	b.POS_PartBBuyDown
	,	b.POS_Inpatient
	,	b.POS_Outpatient
	,	b.POS_Professional
	,	b.POS_OMC
	,	b.POS_Supplemental
	,	b.POS_Drug
	/* Value Add 2022 */
	,	s.Market_Share
	,	s.PMPM_ValueAdd
	,	s.PMPM_ValueAdd_YoY
	/* Historical */
	,	v.PMPM_ValueAdd_Lag1YR_Cum
	,	v.PMPM_ValueAdd_Lag2YR_Cum
	,	v.PMPM_ValueAdd_Lag3YR_Cum
	,	v.PMPM_ValueAdd_Lag4YR_Cum
	,	v.PMPM_ValueAdd_Lag5YR_Cum
	from output.promotion_history ph
	left join output.Address adr
		on ph.AGLTY_INDIV_ID_CHAR=adr.AGLTY_INDIV_ID_CHAR
	left join output.Position_2022 b
		on adr.KP_Region=b.KP_Region
		and ph.Campaign=b.Campaign
	left join output.Share_2022 s
		on adr.ST_CD=s.ST_CD
		and adr.CNTY_NM=s.County
		and ph.Campaign=s.Campaign
	left join output.ValueAdd_Historical v
		on adr.KP_Region=v.KP_Region
		and ph.Campaign=v.Campaign;
	quit;

				* Match % on Position: ~71% for AEP & ~98.8% for SEP;
				proc sql;

				title 'Position match rate';
				SELECT DISTINCT
					COUNT(DISTINCT CASE WHEN b.POS_Premium ne . THEN AGLTY_INDIV_ID END)/
						COUNT(DISTINCT ph.AGLTY_INDIV_ID_CHAR) AS PCT_MATCH_POS format percent7.2
				,	COUNT(DISTINCT CASE WHEN b.PMPM_ValueAdd ne . THEN AGLTY_INDIV_ID END)/
						COUNT(DISTINCT ph.AGLTY_INDIV_ID_CHAR) AS PCT_MATCH_VALADD format percent7.2
				,	COUNT(DISTINCT CASE WHEN b.PMPM_ValueAdd_Lag1YR_Cum ne . THEN AGLTY_INDIV_ID END)/
						COUNT(DISTINCT ph.AGLTY_INDIV_ID_CHAR) AS PCT_MATCH_HIST format percent7.2
				FROM output.Promotion_History ph
				LEFT JOIN output.Position_Share b
					ON ph.AGLTY_INDIV_ID_CHAR=b.AGLTY_INDIV_ID_CHAR;
				title;

				quit;

	* Export;
	data WS.MED_DM_22_Targeting_Share;
		set output.Position_Share;
	run;
	
/* -------------------------------------------------------------------------------------------------*/
/*  Tenure                                                                                          */
/* -------------------------------------------------------------------------------------------------*/

	* Create the input set and send to SQL Server;
	proc sql;
	create table WS.MED_DM_22_Targeting_TenInpAEP as

		SELECT 
		T1.AGLTY_INDIV_ID,
		ph.Campaign,
		ph.Inhome_Date,
		T1.MBR_STAT_CD,
		T1.ELGB_START_DT,
		T1.ELGB_END_DT,
		T1.REGN_MBR_ID AS MRN,
		T1.SUB_REGN_CD,
		T1.MBR_ID
		FROM MARS.MEMBER T1 
		INNER JOIN (
				SELECT DISTINCT
					AGLTY_INDIV_ID
				,	Campaign
				,	Inhome_Date
				FROM WS.MED_DM_22_Targeting_AgilityIDs 
				WHERE CAMPAIGN = "AEP"
					) ph
			ON t1.AGLTY_INDIV_ID=ph.AGLTY_INDIV_ID
			AND t1.ELGB_START_DT < ph.Inhome_Date;

		create table WS.MED_DM_22_Targeting_TenInpSEP as

		SELECT 
		T1.AGLTY_INDIV_ID,
		ph.Campaign,
		ph.Inhome_Date,
		T1.MBR_STAT_CD,
		T1.ELGB_START_DT,
		T1.ELGB_END_DT,
		T1.REGN_MBR_ID AS MRN,
		T1.SUB_REGN_CD,
		T1.MBR_ID
		FROM MARS.MEMBER T1 
		INNER JOIN (
				SELECT DISTINCT
					AGLTY_INDIV_ID
				,	Campaign
				,	Inhome_Date
				FROM WS.MED_DM_22_Targeting_AgilityIDs 
				WHERE CAMPAIGN = "SEP"
					) ph
			ON t1.AGLTY_INDIV_ID=ph.AGLTY_INDIV_ID
			AND t1.ELGB_START_DT < ph.Inhome_Date;

	quit;

	* Run Tenure code in SQL Server;
	data TenureAEP;
		set WS.MED_DM_22_Targeting_Tenure;
		Campaign = "AEP";
	run;
	data TenureSEP;
		set WS.MED_DM_22_Targeting_Tenure;
		Campaign = "SEP";
	run;
	data output.Tenure;
		set TenureAEP
			TenureSEP;
	run;

				* Force char;
				data output.Tenure;
					set output.Tenure;
					AGLTY_INDIV_ID_CHAR = strip(put(AGLTY_INDIV_ID,32.));
				run;

		* Export;
	proc export data=output.Tenure
	    outfile="&output_files/Tenure.csv"
	    dbms=csv replace;
	run;
