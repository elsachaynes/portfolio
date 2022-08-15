/****************************************************************************************************/
/*  Program Name:       1_1 Data pull for model build _Promo and PH.sas                             */
/*                                                                                                  */
/*  Date Created:       July 6, 2022                                                                */
/*                                                                                                  */
/*  Created By:         Elle Haynes                                                                 */
/*                                                                                                  */
/*  Purpose:            Compiles data from MARS Promotion and Promotion History for the KPIF EM     */
/*                      OE 2023 Targeting model.                                                    */
/*                                                                                                  */
/*  Inputs:             Alex D. provided excel campaign files with promo ids for OE 2021-2022.      */
/*                                                                                                  */
/* -------------------------------------------------------------------------------------------------*/	
/*  Notes:              Targeting model will use 3 years of historical data from OE 2020-2022.      */
/* -------------------------------------------------------------------------------------------------*/
/*  Date Modified:      July 28, 2022                                                               */
/*  Modified by:        Elle Haynes                                                                 */
/*  Description:        Added 1 year prior to OE2020 to full KPIF promotion history.                */
/****************************************************************************************************/

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
	libname ELARA sqlsvr DSN='SQLSVR4656' SCHEMA='dbo' user='CS\C156934' password="&winpwd"
     qualifier='ELARA' readbuff=5000 insertbuff=5000 dbcommit=1000; run;

	* Output;
	%let output_files = /gpfsFS2/sasdata/nfs/ndc_grid/po_imca_digital/EHaynes/__Models/KPIF_EmailTargeting_2022;
	libname output "&output_files";

/* -------------------------------------------------------------------------------------------------*/
/*  Promo IDs                                                                                       */
/* -------------------------------------------------------------------------------------------------*/

	proc import
		datafile="&output_files/LOOKUP _Promo IDs.csv"
		out=promoid_lookup
		dbms=CSV replace;
	run;
	
	proc sql; *236 Promo IDs;

	CREATE TABLE output.t1_Promo_IDs AS
	SELECT DISTINCT
		*
	FROM MARS.PROMOTION
	WHERE Promo_ID IN (SELECT strip(put(Promo_ID,8.)) FROM promoid_lookup);

	quit;

				* Tabulations;
				proc freq data=output.t1_Promo_IDs;
				tables Promo_NM
						REGN_CD
						PROMO_START_DT
						PROMO_END_DT
						/ nocol norow nopercent;
				run;

/* -------------------------------------------------------------------------------------------------*/
/*  Promotion History                                                                               */
/* -------------------------------------------------------------------------------------------------*/

	proc sql; *9,654,869 rows (emails sent OE 2020-OE2022);

	CREATE TABLE output.t1_Promotion_History AS
	SELECT /*DISTINCT*/
		AGLTY_INDIV_ID
	,	PROMO_ID
	FROM MARS.INDIVIDUAL_PROMOTION_HISTORY
	WHERE PROMO_ID in (SELECT PROMO_ID FROM output.t1_Promo_IDs);

	quit;

				* Cleaning/Confirming data quality;

				* Force char;
				data output.t1_Promotion_History;
					set output.t1_Promotion_History;
					AGLTY_INDIV_ID_CHAR = strip(put(AGLTY_INDIV_ID,32.));
				run;

	* Final Set;
	proc sql;

	CREATE TABLE output.t1_Promotion_History AS
	SELECT DISTINCT
		x.*
	,	y.*
	FROM output.t1_Promotion_History x
	LEFT JOIN output.t1_Promo_IDs y
		on x.PROMO_ID=y.PROMO_ID;

	quit;

	proc sql;

	CREATE INDEX AGLTY_INDIV_ID_CHAR
		on output.t1_Promotion_History(AGLTY_INDIV_ID_CHAR);

	quit;

	* Tabulate;
	proc sql;

	CREATE TABLE tabulation AS
	SELECT DISTINCT
		PROMO_START_DT
	,	COUNT(CASE WHEN find(PROMO_NM,'_HO')=0 AND find(PROMO_NM,'_CHO')=0 THEN AGLTY_INDIV_ID_CHAR END) AS Emails_Sent
	,	COUNT(CASE WHEN find(PROMO_NM,'_HO')>0 or find(PROMO_NM,'_CHO')>0 THEN AGLTY_INDIV_ID_CHAR END) as Holdout
	,	COUNT(CASE WHEN find(PROMO_NM,'_HO')>0 or find(PROMO_NM,'_CHO')>0 THEN AGLTY_INDIV_ID_CHAR END)/COUNT(*) as Pct_Holdout format percent7.2
	FROM output.t1_Promotion_History 
	GROUP BY 
		PROMO_START_DT;

	quit;

	/*
	PROMO_START_DT	Emails_Sent	Holdout	Pct_Holdout
	24OCT2019		1940278		620980	24.2%
	29OCT2020		1705119		519197	23.3%
	29DEC2020		1068729		267191	20.0%
	27OCT2021		1250082		1215235	49.3%
	29DEC2021		854412		213604	20.0%
	*/

	* Export;
	data WS.KPIF_EM_22_Targeting_AgilityIDs;
		set output.t1_Promotion_History;
	run;

	* Export;
	proc export data=output.t1_Promotion_History
	    outfile="&output_files/T1_PromotionHistory.csv"
	    dbms=csv replace;
	run;

/* -------------------------------------------------------------------------------------------------*/
/*  Promotion History  - ALL KPIF                                                                   */
/* -------------------------------------------------------------------------------------------------*/

	proc sql; 
		CREATE TABLE output.t1_Promo_Hist_ALL AS
		SELECT DISTINCT
			PH.AGLTY_INDIV_ID,
			strip(put(PH.AGLTY_INDIV_ID,32.)) as AGLTY_INDIV_ID_CHAR,
			p1.PROMO_ID,
			p1.EVENT_ID,
			p1.PROMO_CD,
			p1.PROMO_NM,
			p1.PROMO_DSC,
			p1.REGN_CD,
			p1.SUB_REGN_CD,
			p1.PROMO_START_DT,
			p1.PROMO_END_DT,
			p1.SEG_CD,
			p1.FLOWCHART_ID,
			p1.LETTER_ID,
			o.offr_id, o.offr_dsc, o.offr_nm, o.offr_cd,
			md.MEDIA_CHNL_CD, md.MEDIA_DTL_CD, md.MEDIA_DTL_DSC, md.MEDIA_DTL_ID,
			e.EVENT_CD, e.EVENT_NM, e.EVENT_DSC
		FROM MARS.PROMOTION p1
		inner join mars.offer o on o.OFFR_ID=p1.OFFR_ID
		inner join mars.media_detail md on o.MEDIA_DTL_ID=md.MEDIA_DTL_ID
		inner join mars.event e on e.EVENT_ID=p1.EVENT_ID
		left join mars.individual_promotion_history ph on p1.PROMO_ID=ph.PROMO_ID
		where e.EVENT_CD like 'KPIF%' /* KPIF promotions */
			and AGLTY_INDIV_ID in (SELECT AGLTY_INDIV_ID FROM output.t1_Promotion_History) /* for OE2020-OE2022 KPIF EM pop */
			and (p1.PROMO_START_DT >= "01OCT2018"d AND p1.PROMO_START_DT <= "29DEC2021"d); /* between OE2020-OE2022, with 1 year lead-time */
	run;

	* Export;
	proc export data=output.t1_Promo_Hist_ALL
	    outfile="&output_files/T1_PromotionHistory_ALL.csv"
	    dbms=csv replace;
	run;

	
