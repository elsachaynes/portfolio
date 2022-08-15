/****************************************************************************************************/
/*  Program Name:       1_3 Data pull for model build _Demog.sas                                    */
/*                                                                                                  */
/*  Date Created:       July 8, 2022                                                                */
/*                                                                                                  */
/*  Created By:         Elle Haynes                                                                 */
/*                                                                                                  */
/*  Purpose:            Compiles data from MARS Individual KBM Prospect and Individual tables plus  */
/*                      tenure calculations for the KPIF EM OE 2023 Targeting model.                */
/*                                                                                                  */
/*  Inputs:                                                                                         */
/*                                                                                                  */
/* -------------------------------------------------------------------------------------------------*/	
/*  Notes:              Targeting model will use 3 years of historical data from OE 2020-2022.      */
/* -------------------------------------------------------------------------------------------------*/
/*  Date Modified:      July 14, 2022                                                               */
/*  Modified by:        Elle Haynes                                                                 */
/*  Description:        Re-pull INDIVIDUAL table data because MARS updated July 10, 2022            */
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
/*  KBM                                                                                             */
/* -------------------------------------------------------------------------------------------------*/

	proc sql;

	CREATE TABLE output.t3_Demog_KBM AS
	SELECT DISTINCT
		*
		,CASE
			when SCORE_1 in ('77','79','7N','81','82','83','84','86','87',
							 '88','89','8A','8B','8C','8F','8M','8N','8S',
							 '8T','8V','8X','8Y','93','95','96','97','98',
							 '99','9C','9D','9E','9K','9L','9P','9W') then 'AFRICAN'
			when SCORE_1 in ('85') 
				or substr(SCORE_1,1,1) in ('A','D','E','F','I','S','U','W') then 'AFRICAN AM'
			when SCORE_1 in ('48','49','50','51','52','53','55','56','57',
							 '58','59','60','61','62','63','7E','94','9N',
							 '9Q') then 'ASIAN'
			when SCORE_1 in ('01','02','03','04','05','06','07','08','09',
							 '10','11','12','13','14','15','16','17','18',
							 '19','21','22','23','24','25','26','33','35',
							 '36','37','38','40','41','42','43','66','9F',
							 '9M') then 'EUROPEAN'
			when SCORE_1 in ('20','71') then 'LATINO'
			when SCORE_1 in ('34','44','45','46','47','64','70','72','73',
							 '74','75','76','77','78','9T','9Z') then 'MIDDLE-EASTERN'
			when SCORE_1 in ('27','28','29','30','31','32','39','67','68',
							 '7F','7M','80','8U','8W','ZZ') then 'OTHER'
			else 'U'
			END as KBM_Ethnicity format=$CHAR14.
		,case 
			when SCORE_3='01' then 'English'
			when SCORE_3='20' then 'Spanish'
			when SCORE_3 is missing then 'U'
			else 'Other'
			end as KBM_Language format=$CHAR7. 
		,case 
			when EST_HH_INCM_CD='A' then 7500 
			when EST_HH_INCM_CD='B' then 17500 
			when EST_HH_INCM_CD='C' then 25000 
			when EST_HH_INCM_CD='D' then 35000 
			when EST_HH_INCM_CD='E' then 45000 
			when EST_HH_INCM_CD='F' then 55000 
			when EST_HH_INCM_CD='G' then 67500 
			when EST_HH_INCM_CD='H' then 87500 
			when EST_HH_INCM_CD='I' then 112500 
			when EST_HH_INCM_CD='J' then 137500 
			when EST_HH_INCM_CD='K' then 175000 
			when EST_HH_INCM_CD='L' then 225000 
			when EST_HH_INCM_CD='M' then 325000 
			when EST_HH_INCM_CD='N' then 450000 
			when EST_HH_INCM_CD='O' then 550000
			end as KBM_Income
		,case 
			when EST_HH_INCM_CD in ('A','B','C') then '$0 - $29,999'
			when EST_HH_INCM_CD in ('D','E','F') then '$30,000 - $59,999'
			when EST_HH_INCM_CD in ('G','H') then '$60,000 - $99,999'
			when EST_HH_INCM_CD in ('I','J','K','L','M','N','O') then '$100,000+'
			else 'U'
			end as KBM_Income_Bin
		,case 
			when SCORE_5='0' then "Unknown"
			when SCORE_5='1' then "Assimilated"
			when SCORE_5='2' then "Bilingual English"
			when SCORE_5='3' then "Bilingual Native Tongue"
			when SCORE_5='4' then "Unassimilated"
			when SCORE_5 is missing then 'U'
			else 'Other'
			end as KBM_Assimilation format=$CHAR25.
		,case 
			when CENS_EDU_LVL_CD='0' then 'Unknown'
			when CENS_EDU_LVL_CD in ('1','2') then 'Less than HS'
			when CENS_EDU_LVL_CD in ('3','4','5') then 'HSGrad/SomeCollege/AssDeg'
			when CENS_EDU_LVL_CD in ('6','7','8','9') then 'CollGrad/PostGrad'
			when CENS_EDU_LVL_CD is missing then 'U'
			else 'Other' 
			end as KBM_Education format=$CHAR27.
		, case 
			when (HH_PERSS_CNT = '001' and EST_HH_INCM_CD in ('B','C','D','E') and ST_CD <> 'HI')
			or (HH_PERSS_CNT = '002' and EST_HH_INCM_CD in ('C','D','E','F') and ST_CD <> 'HI')
			or (HH_PERSS_CNT = '003' and EST_HH_INCM_CD in ('D','E','F','G') and ST_CD <> 'HI')
			or (HH_PERSS_CNT = '004' and EST_HH_INCM_CD in ('D','E','F','G','H') and ST_CD <> 'HI')
			or (HH_PERSS_CNT = '005' and EST_HH_INCM_CD in ('E','F','G','H') and ST_CD <> 'HI')
			or (HH_PERSS_CNT = '006' and EST_HH_INCM_CD in ('E','F','G','H','I') and ST_CD <> 'HI')
			or (HH_PERSS_CNT = '007' and EST_HH_INCM_CD in ('F','G','H','I','J') and ST_CD <> 'HI')
			or (HH_PERSS_CNT = '008' and EST_HH_INCM_CD in ('G','H','I','J') and ST_CD <> 'HI')
			or (HH_PERSS_CNT = '009' and EST_HH_INCM_CD in ('G','H','I','J') and ST_CD <> 'HI')
			or (HH_PERSS_CNT = '010' and EST_HH_INCM_CD in ('G','H','I','J','K') and ST_CD <> 'HI')
			or (HH_PERSS_CNT = '011' and EST_HH_INCM_CD in ('H','I','J','K') and ST_CD <> 'HI')
			or (HH_PERSS_CNT = '012' and EST_HH_INCM_CD in ('H','I','J','K','L') and ST_CD <> 'HI')
			or (HH_PERSS_CNT = '013' and EST_HH_INCM_CD in ('H','I','J','K','L') and ST_CD <> 'HI')
			or (HH_PERSS_CNT = '014' and EST_HH_INCM_CD in ('I','J','K','L') and ST_CD <> 'HI')
			or (HH_PERSS_CNT = '001' and EST_HH_INCM_CD in ('C','D','E') and ST_CD = 'HI')
			or (HH_PERSS_CNT = '002' and EST_HH_INCM_CD in ('C','D','E','F','G') and ST_CD = 'HI')
			or (HH_PERSS_CNT = '003' and EST_HH_INCM_CD in ('D','E','F','G','H') and ST_CD = 'HI')
			or (HH_PERSS_CNT = '004' and EST_HH_INCM_CD in ('E','F','G','H') and ST_CD = 'HI')
			or (HH_PERSS_CNT = '005' and EST_HH_INCM_CD in ('E','F','G','H','I') and ST_CD = 'HI')
			or (HH_PERSS_CNT = '006' and EST_HH_INCM_CD in ('F','G','H','I','J') and ST_CD = 'HI')
			or (HH_PERSS_CNT = '007' and EST_HH_INCM_CD in ('G','H','I','J') and ST_CD = 'HI')
			or (HH_PERSS_CNT = '008' and EST_HH_INCM_CD in ('G','H','I','J','K') and ST_CD = 'HI')
			then 1 else 0 end as SUBSIDY_ELGB
	FROM MARS.INDIVIDUAL_KBM_PROSPECT
	WHERE AGLTY_INDIV_ID in (SELECT AGLTY_INDIV_ID FROM output.t1_Promotion_History);

	quit;

			* Match % on KBM: 38.2%;
			* KBM updated quarterly. Last update 5/27/22;
			proc sql;

			title 'KBM match rate';
			SELECT DISTINCT
				COUNT(DISTINCT y.AGLTY_INDIV_ID)/
					COUNT(DISTINCT x.AGLTY_INDIV_ID) AS PCT_MATCH_KBM format percent7.2
			FROM output.t1_Promotion_History x
			LEFT JOIN output.t3_Demog_KBM y
				on x.AGLTY_INDIV_ID=y.AGLTY_INDIV_ID;

			quit;

	* Export;
	proc export data=output.t3_Demog_KBM
	    outfile="&output_files/T3_Demographics_KBM.csv"
	    dbms=csv replace;
	run;

/* -------------------------------------------------------------------------------------------------*/
/*  Individual                                                                                      */
/* -------------------------------------------------------------------------------------------------*/

	proc sql;
	create table output.t3_Demog_Indiv as
	SELECT DISTINCT
		AGLTY_INDIV_ID
	,	BIRTH_DT
	,	DO_NOT_CALL_IND
	,	DO_NOT_MAIL_IND
/*	,	ETHN_CD*/
	,	GNDR_CD
	,	HH_HEAD_IND
/*	,	LAST_SRC_CD*/
/*	,	ORIG_SRC_CD*/
	,	MRTL_STAT_CD
	,	REC_INS_DT
/*	,	REC_UPDT_DT*/
	FROM MARS.INDIVIDUAL
	WHERE AGLTY_INDIV_ID IN (SELECT AGLTY_INDIV_ID FROM output.t1_Promotion_History);
	quit;

	* Export;
	proc export data=output.t3_Demog_Indiv
	    outfile="&output_files/T3_Demographics_Indiv.csv"
	    dbms=csv replace;
	run;

/* -------------------------------------------------------------------------------------------------*/
/*  Tenure                                                                                          */
/* -------------------------------------------------------------------------------------------------*/

	/* STOP */
	/* STOP */
	/* STOP */
	/* Run "SQL Server_ TENURE_CODE OE2020.sql" which is found in "Y:\Elsa\KPIF_ Targeting Model 2023 OE\01 Raw Data" */
	/* Run "SQL Server_ TENURE_CODE OE2021.sql" which is found in "Y:\Elsa\KPIF_ Targeting Model 2023 OE\01 Raw Data" */
	/* Run "SQL Server_ TENURE_CODE OE2022.sql" which is found in "Y:\Elsa\KPIF_ Targeting Model 2023 OE\01 Raw Data" */
	/* "Sql Server_ TENURE_CODE OE2022.sql" will create the table WS.KPIF_EM_22_Targeting_Tenure */ 
	/* STOP */
	/* STOP */
	/* STOP */

	* Export;
	proc export data=WS.KPIF_EM_22_Targeting_Tenure
	    outfile="&output_files/T3_Tenure.csv"
	    dbms=csv replace;
	run;