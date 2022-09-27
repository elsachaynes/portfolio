/****************************************************************************************************/
/*  Program Name:       2_1 Data pull for model build _Sample.sas                                   */
/*                                                                                                  */
/*  Date Created:       July 25, 2022                                                               */
/*                                                                                                  */
/*  Created By:         Elle Haynes                                                                 */
/*                                                                                                  */
/*  Purpose:            Randomly samples 500k individuals for the KPIF EM OE23 Targeting Model.     */
/*                                                                                                  */
/*  Inputs:                                                                                         */
/*                                                                                                  */
/* -------------------------------------------------------------------------------------------------*/	
/*  Notes:              Targeting model will use 3 years of historical data from OE 2020-2022.      */
/* -------------------------------------------------------------------------------------------------*/
/*  Date Modified:                                                                                  */
/*  Modified by:                                                                                    */
/*  Description:                                                                                    */
/****************************************************************************************************/

/* -------------------------------------------------------------------------------------------------*/
/*  Libraries                                                                                       */
/* -------------------------------------------------------------------------------------------------*/

	* Output;
	%let output_files = ##MASKED##;
	libname output "&output_files";

/* -------------------------------------------------------------------------------------------------*/
/*  Sample                                                                                          */
/* -------------------------------------------------------------------------------------------------*/

	proc sql; create table Unique_IDs as select distinct AGLTY_INDIV_ID FROM output.t1_Promotion_History; quit;

	proc surveyselect 
		data=Unique_IDs 
		method=srs 
		n=500000
        out=output.t8_Sample_Agilities;
	run;

	* Export;
	proc export 
		data=output.t8_Sample_Agilities
		outfile="&output_files/T8_Sample_Agilities.csv"
		dbms=CSV replace;
	run;			

/* -------------------------------------------------------------------------------------------------*/
/*  Validation                                                                                      */
/* -------------------------------------------------------------------------------------------------*/

	proc sql;

	CREATE TABLE Summary_Population AS
	SELECT DISTINCT 
		ph.AGLTY_INDIV_ID
	,	CASE WHEN t1.AGLTY_INDIV_ID ne . THEN 1 ELSE 0 END AS Promo_Hist_All
	,	CASE WHEN t2.AGLTY_INDIV_ID ne . THEN 1 ELSE 0 END AS Address_Region
	,	CASE WHEN t3.AGLTY_INDIV_ID ne . THEN 1 ELSE 0 END AS Individual
	,	CASE WHEN t3_2.AGLTY_INDIV_ID ne . THEN 1 ELSE 0 END AS KBM
	,	CASE WHEN t4.AGLTY_INDIV_ID ne . THEN 1 ELSE 0 END AS Membership
	,	CASE WHEN t4_2.AGLTY_INDIV_ID ne . THEN 1 ELSE 0 END AS Response
	,	CASE WHEN t5.AGLTY_INDIV_ID ne . THEN 1 ELSE 0 END AS Tapestry
	,	CASE WHEN t6.AGLTY_INDIV_ID ne . THEN 1 ELSE 0 END AS PriorModelScore
	FROM output.t1_Promotion_History ph 
	LEFT JOIN (SELECT DISTINCT AGLTY_INDIV_ID FROM output.t1_promo_hist_all) t1
		ON ph.AGLTY_INDIV_ID=t1.AGLTY_INDIV_ID
	LEFT JOIN (SELECT DISTINCT AGLTY_INDIV_ID FROM output.t2_address WHERE Region ne '') t2
		ON ph.AGLTY_INDIV_ID=t2.AGLTY_INDIV_ID
	LEFT JOIN (SELECT DISTINCT AGLTY_INDIV_ID FROM output.t3_demog_indiv) t3
		ON ph.AGLTY_INDIV_ID=t3.AGLTY_INDIV_ID
	LEFT JOIN (SELECT DISTINCT AGLTY_INDIV_ID FROM output.t3_demog_kbm) t3_2
		ON ph.AGLTY_INDIV_ID=t3_2.AGLTY_INDIV_ID
	LEFT JOIN (SELECT DISTINCT AGLTY_INDIV_ID FROM output.t4_membership) t4
		ON ph.AGLTY_INDIV_ID=t4.AGLTY_INDIV_ID
	LEFT JOIN (SELECT DISTINCT AGLTY_INDIV_ID FROM output.t4_Response_ILKR
					UNION
			   SELECT DISTINCT AGLTY_INDIV_ID FROM output.t4_Response_ILR) t4_2
		ON ph.AGLTY_INDIV_ID=t4_2.AGLTY_INDIV_ID
	LEFT JOIN (SELECT DISTINCT AGLTY_INDIV_ID FROM output.t5_tapestry) t5
		ON ph.AGLTY_INDIV_ID=t5.AGLTY_INDIV_ID
	LEFT JOIN (SELECT DISTINCT AGLTY_INDIV_ID FROM output.t6_priormodelscore) t6
		ON ph.AGLTY_INDIV_ID=t6.AGLTY_INDIV_ID
	;
	quit;

	proc sql;
	CREATE TABLE Summary_Population AS
	SELECT DISTINCT
		SUM(Promo_Hist_All)/COUNT(AGLTY_INDIV_ID) AS Pct_Promo_Hist_All format percent7.2
	,	SUM(Address_Region)/COUNT(AGLTY_INDIV_ID) AS Pct_Address_Region format percent7.2
	,	SUM(Individual)/COUNT(AGLTY_INDIV_ID) AS Pct_Individual format percent7.2
	,	SUM(KBM)/COUNT(AGLTY_INDIV_ID) AS Pct_KBM format percent7.2
	,	SUM(Membership)/COUNT(AGLTY_INDIV_ID) AS Pct_Membership format percent7.2
	,	SUM(Response)/COUNT(AGLTY_INDIV_ID) AS Pct_Response format percent7.2
	,	SUM(Tapestry)/COUNT(AGLTY_INDIV_ID) AS Pct_Tapestry format percent7.2
	,	SUM(PriorModelScore)/COUNT(AGLTY_INDIV_ID) AS Pct_PriorModelScore format percent7.2
	FROM Summary_Population;
	quit;

	* Validate the sample has the same statuses;
	proc sql;

	CREATE TABLE Sample_Population AS
	SELECT DISTINCT 
		ph.AGLTY_INDIV_ID
	,	CASE WHEN t1.AGLTY_INDIV_ID ne . THEN 1 ELSE 0 END AS Promo_Hist_All
	,	CASE WHEN t2.AGLTY_INDIV_ID ne . THEN 1 ELSE 0 END AS Address_Region
	,	CASE WHEN t3.AGLTY_INDIV_ID ne . THEN 1 ELSE 0 END AS Individual
	,	CASE WHEN t3_2.AGLTY_INDIV_ID ne . THEN 1 ELSE 0 END AS KBM
	,	CASE WHEN t4.AGLTY_INDIV_ID ne . THEN 1 ELSE 0 END AS Membership
	,	CASE WHEN t4_2.AGLTY_INDIV_ID ne . THEN 1 ELSE 0 END AS Response
	,	CASE WHEN t5.AGLTY_INDIV_ID ne . THEN 1 ELSE 0 END AS Tapestry
	,	CASE WHEN t6.AGLTY_INDIV_ID ne . THEN 1 ELSE 0 END AS PriorModelScore
	FROM output.t8_Sample_Agilities ph 
	LEFT JOIN (SELECT DISTINCT AGLTY_INDIV_ID FROM output.t1_promo_hist_all) t1
		ON ph.AGLTY_INDIV_ID=t1.AGLTY_INDIV_ID
	LEFT JOIN (SELECT DISTINCT AGLTY_INDIV_ID FROM output.t2_address WHERE Region ne '') t2
		ON ph.AGLTY_INDIV_ID=t2.AGLTY_INDIV_ID
	LEFT JOIN (SELECT DISTINCT AGLTY_INDIV_ID FROM output.t3_demog_indiv) t3
		ON ph.AGLTY_INDIV_ID=t3.AGLTY_INDIV_ID
	LEFT JOIN (SELECT DISTINCT AGLTY_INDIV_ID FROM output.t3_demog_kbm) t3_2
		ON ph.AGLTY_INDIV_ID=t3_2.AGLTY_INDIV_ID
	LEFT JOIN (SELECT DISTINCT AGLTY_INDIV_ID FROM output.t4_membership) t4
		ON ph.AGLTY_INDIV_ID=t4.AGLTY_INDIV_ID
	LEFT JOIN (SELECT DISTINCT AGLTY_INDIV_ID FROM output.t4_Response_ILKR
					UNION
			   SELECT DISTINCT AGLTY_INDIV_ID FROM output.t4_Response_ILR) t4_2
		ON ph.AGLTY_INDIV_ID=t4_2.AGLTY_INDIV_ID
	LEFT JOIN (SELECT DISTINCT AGLTY_INDIV_ID FROM output.t5_tapestry) t5
		ON ph.AGLTY_INDIV_ID=t5.AGLTY_INDIV_ID
	LEFT JOIN (SELECT DISTINCT AGLTY_INDIV_ID FROM output.t6_priormodelscore) t6
		ON ph.AGLTY_INDIV_ID=t6.AGLTY_INDIV_ID
	;
	quit;

	proc sql;
	CREATE TABLE Sample_Population AS
	SELECT DISTINCT
		SUM(Promo_Hist_All)/COUNT(AGLTY_INDIV_ID) AS Pct_Promo_Hist_All format percent7.2
	,	SUM(Address_Region)/COUNT(AGLTY_INDIV_ID) AS Pct_Address_Region format percent7.2
	,	SUM(Individual)/COUNT(AGLTY_INDIV_ID) AS Pct_Individual format percent7.2
	,	SUM(KBM)/COUNT(AGLTY_INDIV_ID) AS Pct_KBM format percent7.2
	,	SUM(Membership)/COUNT(AGLTY_INDIV_ID) AS Pct_Membership format percent7.2
	,	SUM(Response)/COUNT(AGLTY_INDIV_ID) AS Pct_Response format percent7.2
	,	SUM(Tapestry)/COUNT(AGLTY_INDIV_ID) AS Pct_Tapestry format percent7.2
	,	SUM(PriorModelScore)/COUNT(AGLTY_INDIV_ID) AS Pct_PriorModelScore format percent7.2
	FROM Sample_Population;
	quit;

	data Compare;
		set Summary_Population
			Sample_Population;
	run;

/*
		Pct_Promo_Hist_All	Pct_Address_Region	Pct_Individual	Pct_KBM		Pct_Membership	Pct_Response	Pct_Tapestry	Pct_PriorModelScore
Overall	97.80%				97.00%				100%			38.20%		75.30%			39.80%			100%			98.00%
Sample	97.70%				97.00%				100%			38.30%		75.30%			39.70%			100%			98.00%
Diff	-0.1%				0.0%				0.0%			0.3%		0.0%			-0.3%			0.0%			0.0%
*/