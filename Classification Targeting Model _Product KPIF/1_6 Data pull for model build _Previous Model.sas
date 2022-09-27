/****************************************************************************************************/
/*  Program Name:       1_6 Data pull for model build _Previous Model.sas                           */
/*                                                                                                  */
/*  Date Created:       July 14, 2022                                                               */
/*                                                                                                  */
/*  Created By:         Elle Haynes                                                                 */
/*                                                                                                  */
/*  Purpose:            Compiles data from MARS Individual Model Score for the KPIF EM OE 2023      */
/*                      Targeting model.                                                            */
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


	* Input;
	%let nuid = /* insert nuid here*/;
	%include '/gpfsFS2/home/&nuid/password.sas';
	libname MARS sqlsvr DSN='SQLSVR4685' SCHEMA='dbo' user="CS\&nuid" password="&winpwd"
	     qualifier='MARS' readbuff=5000 insertbuff=5000 dbcommit=1000; run;
	libname WS sqlsvr datasrc='WS_NYDIA' SCHEMA='dbo' user="CS\&nuid" password="&winpwd"
	     qualifier='WS_EHAYNES' readbuff=5000 insertbuff=5000 dbcommit=1000; run;
	libname ESRI sqlsvr DSN='WS_NYDIA' SCHEMA='dbo' user="CS\&nuid" password="&winpwd"
	     qualifier='ESRI_TAPESTRY' readbuff=5000 insertbuff=5000 dbcommit=1000; run;
	libname ELARA sqlsvr DSN='SQLSVR4656' SCHEMA='dbo' user="CS\&nuid" password="&winpwd"
     qualifier='ELARA' readbuff=5000 insertbuff=5000 dbcommit=1000; run;

	* Output;
	%let output_files = ##MASKED##;
	libname output "&output_files";

/* -------------------------------------------------------------------------------------------------*/
/*  Prior Model Scores                                                                              */
/* -------------------------------------------------------------------------------------------------*/
	
	* minimum/best;
	proc sql;
	create table output.t6_PriorModelScore as
		SELECT DISTINCT
			AGLTY_INDIV_ID
		,	2022 AS OE_Season
		,	MIN(MODL_DCL_VAL) as MODL_DCL_VAL
		FROM MARS.INDIVIDUAL_MODEL_SCORE
		WHERE MODL_VRSN_NBR=193 /* KPIF 2022 OE EM RESPONSE MODEL */
		GROUP BY AGLTY_INDIV_ID

	 		UNION

		SELECT DISTINCT
			AGLTY_INDIV_ID
		,	2021
		,	MIN(MODL_DCL_VAL) 
		FROM MARS.INDIVIDUAL_MODEL_SCORE
		WHERE MODL_VRSN_NBR=185 /* KPIF OE8 EM RESPONSE MODEL */
		GROUP BY AGLTY_INDIV_ID
		 
			UNION

		SELECT DISTINCT
			AGLTY_INDIV_ID
		,	2020
		,	MIN(MODL_DCL_VAL) 
		FROM MARS.INDIVIDUAL_MODEL_SCORE
		WHERE MODL_VRSN_NBR=174 /* KPIF OE7 EM RESPONSE MODEL */
		GROUP BY AGLTY_INDIV_ID

		;
	quit;

			* Match % on old model decile: 100%;
			proc sql;

			title 'Old model match rate';
			SELECT DISTINCT
			CAMPAIGN, 
				COUNT(DISTINCT y.AGLTY_INDIV_ID)/
					COUNT(DISTINCT x.AGLTY_INDIV_ID) AS PCT_MATCH_OldModel format percent7.2
			FROM output.t1_Promotion_History x
			LEFT JOIN output.t6_PriorModelScore y
				on x.AGLTY_INDIV_ID=y.AGLTY_INDIV_ID
				GROUP BY CAMPAIGN;

			quit;

	* Export;
	proc export data=output.t6_PriorModelScore
	    outfile="&output_files/T6_PriorModelScore.csv"
	    dbms=csv replace;
	run;