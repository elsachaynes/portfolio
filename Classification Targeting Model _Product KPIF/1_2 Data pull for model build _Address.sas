/****************************************************************************************************/
/*  Program Name:       1_2 Data pull for model build _Address.sas                                  */
/*                                                                                                  */
/*  Date Created:       July 7, 2022                                                                */
/*                                                                                                  */
/*  Created By:         Elle Haynes                                                                 */
/*                                                                                                  */
/*  Purpose:            Compiles data from MARS Individual Address, Address, Zip Level Info, and    */
/*                      Geocode Lookup tables for the KPIF EM OE 2023 Targeting model.              */
/*                                                                                                  */
/*  Inputs:                                                                                         */
/*                                                                                                  */
/* -------------------------------------------------------------------------------------------------*/	
/*  Notes:              Targeting model will use 3 years of historical data from OE 2020-2022.      */
/* -------------------------------------------------------------------------------------------------*/
/*  Date Modified:      July 14, 2022                                                               */
/*  Modified by:        Elle Haynes                                                                 */
/*  Description:        Re-pulled data because it was updated July 10, 2022                         */
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
/*  Address                                                                                         */
/* -------------------------------------------------------------------------------------------------*/

	proc sql;
	CREATE TABLE output.Address1 AS
	SELECT DISTINCT
		ia.AGLTY_INDIV_ID
	,	strip(put(ia.AGLTY_INDIV_ID,32.)) as AGLTY_INDIV_ID_CHAR
	,	CASE WHEN ia.ADDR_TYPE_CD='PR' AND ia.PRIM_ADDR_IND='Y' THEN 1 ELSE 0 END AS Prim_Addr_Flag
	,	a.ZIP_CD
	,	a.ZIP4_CD
	,	a.HOSP_DIST_MSR
	,	a.MOB_DIST_MSR
	,	CASE WHEN a.ADDR_LN2_TXT IS NOT NULL THEN 1 ELSE 0 END AS APT_FLAG
	,	a.MAILABILITY_SCR_CD
	,	a.DWELL_TYPE_CD as ADDR_DWELL_TYPE_CD
	,	a.REC_INS_DT as ADDR_REC_INS_DT
	,	a.REC_UPDT_DT as ADDR_REC_UPDT_DT
	,	a.ACE_DPV_STAT_CD
	,	a.CARR_RTE_CD as ADDR_CARR_RTE_CD
	,	g.GEOCODE
	,	g.COUNTYFIPS
	FROM MARS.INDIVIDUAL_ADDRESS ia
	LEFT JOIN MARS.ADDRESS a
		ON ia.AGLTY_ADDR_ID=a.AGLTY_ADDR_ID
	LEFT JOIN MARS.GEOCODE_LKUP g
		ON a.AGLTY_ADDR_ID=g.AGLTY_ADDR_ID
	WHERE ia.AGLTY_INDIV_ID IN (SELECT AGLTY_INDIV_ID FROM output.t1_Promotion_History);
	quit;

	* De-dupe to 1 address per individual;
	proc sort data=output.Address1; 
		by AGLTY_INDIV_ID 
			descending Prim_Addr_Flag 
			descending geocode 
			hosp_dist_msr; 
	run;
	data output.Address1(drop=Prim_Addr_Flag);
		set output.Address1;
		by AGLTY_INDIV_ID 
			descending Prim_Addr_Flag 
			descending geocode 
			hosp_dist_msr; 

		ZIP_CD_NUM = input(ZIP_CD,8.);
		ZIP4_NUM = input(ZIP4_CD,8.);
		drop ZIP_CD ZIP4_CD;
		rename ZIP_CD_NUM = ZIP_CD
			   ZIP4_NUM = ZIP4_CD;

		if first.AGLTY_INDIV_ID then output;
	run;

	proc sql;
	CREATE TABLE output.Address2 AS
	SELECT DISTINCT
		x.*
	,	zip.CNTY_NM
	,	zip.CITY_NM
	,	zip.ST_CD
	,	zip.REGN_CD
	,	zip.SUB_REGN_CD
	,	zip.SVC_AREA_NM 
	FROM output.Address1 x
	LEFT JOIN MARS.ZIP_LEVEL_INFO zip
		ON x.ZIP_CD=input(zip.ZIP_CD,8.)
		AND x.ZIP4_CD BETWEEN input(zip.ZIP4_START_CD,8.) AND input(zip.ZIP4_END_CD,8.)
		AND zip.YR_NBR=2022;
	quit;

	/* need to fill in missing zip code information. */

	data output.t2_Address;
		format Region $4.;
		set output.Address2;
		* Clean;
		if CNTY_NM = 'PRINCE GEORGES' then CNTY_NM = "PRINCE GEORGE'S";
		Region = REGN_CD;
		if REGN_CD = 'MR' then Region = 'MAS';
		else if REGN_CD = 'CA' then Region = SUB_REGN_CD;
	run;

			* Match % on Geocode: 99.3%;
			proc sql;

			title 'Geocode match rate';
			SELECT DISTINCT
				COUNT(DISTINCT CASE WHEN GEOCODE IS NOT MISSING THEN y.AGLTY_INDIV_ID END)/
					COUNT(DISTINCT x.AGLTY_INDIV_ID) AS PCT_MATCH_Geocode format percent7.2
			FROM output.t1_Promotion_History x
			LEFT JOIN output.t2_Address y
				on x.AGLTY_INDIV_ID=y.AGLTY_INDIV_ID;

			quit;

	* Export;
	data ws.KPIF_EM_22_Targeting_Address;
		set output.t2_address;
	run;

	* Export;
	proc export data=output.t2_address
	    outfile="&output_files/T2_Address.csv"
	    dbms=csv replace;
	run;

	proc delete data=output.Address1; run;
	proc delete data=output.Address2; run;