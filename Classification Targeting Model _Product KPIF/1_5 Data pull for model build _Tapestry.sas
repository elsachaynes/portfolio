/****************************************************************************************************/
/*  Program Name:       1_5 Data pull for model build _Tapestry.sas                                 */
/*                                                                                                  */
/*  Date Created:       July 14, 2022                                                               */
/*                                                                                                  */
/*  Created By:         Elle Haynes                                                                 */
/*                                                                                                  */
/*  Purpose:            Compiles data from ESRI_TAPESTRY for the KPIF EM OE 2023 Targeting model.   */
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
	%let nuid = /* enter  nuid here */;
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

			CREATE TABLE output.Tapestry_Batch_&batchNumPull AS
			SELECT DISTINCT
				s.*,

				/* Population, Households, and Density - 2020 */
				tap1.TOTPOP_CY AS ESRI_TOT_POP,
				tap1.HHPOP_CY AS ESRI_HH_POP,
				tap1.FAMPOP_CY AS ESRI_FAM_POP,
				tap1.POPDENS_CY AS ESRI_POP_DENS,
				tap1.TOTHH_CY AS ESRI_TOT_HH,
				tap1.AVGHHSZ_CY AS ESRI_AVG_HH_SIZE,
				tap1.FAMHH_CY AS ESR_FAM_HH,
				tap1.AVGFMSZ_CY AS ESRI_AVG_FAM_SIZE,

				/* Population by Age - 2020 */
				tap1.GENALPHACY AS ESRI_GEN_A,	
				tap1.GENZ_CY AS ESRI_GEN_Z,	
				tap1.MILLENN_CY AS ESRI_GEN_MIL,
				tap1.WORKAGE_CY AS ESRI_AGE_18_64,
				tap1.POP20_CY AS ESRI_AGE_20_24,
				tap1.POP25_CY AS ESRI_AGE_25_29,
				tap1.POP30_CY AS ESRI_AGE_30_34,
				tap1.POP50_CY AS ESRI_AGE_50_54,
				tap1.POP55_CY AS ESRI_AGE_55_60,
				tap1.POP60_CY AS ESRI_AGE_60_64,
				tap3.WHT20_CY AS ESRI_AGE_20_24_W,
				tap3.WHT25_CY AS ESRI_AGE_25_29_W,
				tap3.WHT30_CY AS ESRI_AGE_30_34_W,
				tap3.WHT50_CY AS ESRI_AGE_50_54_W,
				tap3.WHT55_CY AS ESRI_AGE_55_60_W,
				tap3.WHT60_CY AS ESRI_AGE_60_64_W,
				tap3.BLK20_CY AS ESRI_AGE_20_24_B,
				tap3.BLK25_CY AS ESRI_AGE_25_29_B,
				tap3.BLK30_CY AS ESRI_AGE_30_34_B,
				tap3.BLK50_CY AS ESRI_AGE_50_54_B,
				tap3.BLK55_CY AS ESRI_AGE_55_60_B,
				tap3.BLK60_CY AS ESRI_AGE_60_64_B,
				tap3.ASN20_CY AS ESRI_AGE_20_24_A,
				tap3.ASN25_CY AS ESRI_AGE_25_29_A,
				tap3.ASN30_CY AS ESRI_AGE_30_34_A,
				tap3.ASN50_CY AS ESRI_AGE_50_54_A,
				tap3.ASN55_CY AS ESRI_AGE_55_60_A,
				tap3.ASN60_CY AS ESRI_AGE_60_64_A,
				tap4.PI20_CY AS ESRI_AGE_20_24_PI,
				tap4.PI25_CY AS ESRI_AGE_25_29_PI,
				tap4.PI30_CY AS ESRI_AGE_30_34_PI,
				tap4.PI50_CY AS ESRI_AGE_50_54_PI,
				tap4.PI55_CY AS ESRI_AGE_55_60_PI,
				tap4.PI60_CY AS ESRI_AGE_60_64_PI,

				/* Race & Diversity - 2020 */
				tap5.RACEBASECY AS ESRI_RACE_BASE,
				tap5.WHITE_CY AS ESRI_RACE_WHITE,
				tap5.BLACK_CY AS ESRI_RACE_BLACK,
				tap5.AMERIND_CY AS ESRI_RACE_AM_IND,
				tap5.ASIAN_CY AS ESRI_RACE_ASIAN,
				tap5.PACIFIC_CY AS ESRI_RACE_PAC_ISL,
				tap5.HISPPOP_CY AS ESRI_RACE_HISPANIC,
				tap5.MINORITYCY AS ESRI_RACE_MINORITY,
				tap5.DIVINDX_CY AS ESRI_DIVERSITY_INDEX,

				/* Race & Diversity - 2025 */
				tap11.RACEBASEFY AS ESRI_RACE_BASE_FY,
				tap11.WHITE_FY AS ESRI_RACE_WHITE_FY,
				tap11.BLACK_FY AS ESRI_RACE_BLACK_FY,
				tap11.AMERIND_FY AS ESRI_RACE_AM_IND_FY,
				tap11.ASIAN_FY AS ESRI_RACE_ASIAN_FY,
				tap11.PACIFIC_FY AS ESRI_RACE_PAC_ISL_FY,
				tap11.HISPPOP_FY AS ESRI_RACE_HISPANIC_FY,
				tap11.MINORITYFY AS ESRI_RACE_MINORITY_FY,
				tap11.DIVINDX_FY AS ESRI_DIVERSITY_INDEX_FY,
				
				/* Employment - 2020 */
				tap5.UNEMPRT_CY AS ESRI_UNEMPL_RATE,
				tap5.UNEMRT16CY AS ESRI_UNEMPL_RATE_16_24,
				tap5.UNEMRT25CY AS ESRI_UNEMPL_RATE_25_54,
				tap5.UNEMRT55CY AS ESRI_UNEMPL_RATE_55_64,
				tap5.INDBASE_CY AS ESRI_INDUSTRY_BASE,
				tap5.INDAGRI_CY AS ESRI_INDUSTRY_AGRICU,
				tap5.INDMIN_CY AS ESRI_INDUSTRY_MINING,
				tap5.INDCONS_CY AS ESRI_INDUSTRY_CONSTR,
				tap5.INDMANU_CY AS ESRI_INDUSTRY_MANUFA,
				tap5.INDWHTR_CY AS ESRI_INDUSTRY_WHOLES,
				tap5.INDRTTR_CY AS ESRI_INDUSTRY_RETAIL,
				tap5.INDTRAN_CY AS ESRI_INDUSTRY_TRANSP,
				tap5.INDUTIL_CY AS ESRI_INDUSTRY_UTILIT,
				tap5.INDINFO_CY AS ESRI_INDUSTRY_INFORM,
				tap5.INDFIN_CY AS ESRI_INDUSTRY_FINANC,
				tap5.INDRE_CY AS ESRI_INDUSTRY_REAL,
				tap5.INDTECH_CY AS ESRI_INDUSTRY_PROFES,
				tap5.INDMGMT_CY AS ESRI_INDUSTRY_MGMT,
				tap5.INDADMN_CY AS ESRI_INDUSTRY_WASTE,
				tap5.INDEDUC_CY AS ESRI_INDUSTRY_EDUCAT,
				tap5.INDHLTH_CY AS ESRI_INDUSTRY_HEALTH,
				tap5.INDARTS_CY AS ESRI_INDUSTRY_ENTERT,
				tap5.INDFOOD_CY AS ESRI_INDUSTRY_FOOD,
				tap5.INDOTSV_CY AS ESRI_INDUSTRY_OTHER,
				tap5.INDPUBL_CY AS ESRI_INDUSTRY_PUBLIC,
				tap5.OCCBASE_CY AS ESRI_OCCU_BASE,
				tap5.OCCMGMT_CY AS ESRI_OCCU_MGMT,
				tap5.OCCBUS_CY AS ESRI_OCCU_BIZ_FIN,
				tap5.OCCCOMP_CY AS ESRI_OCCU_COMP_MATH,
				tap5.OCCARCH_CY AS ESRI_OCCU_ARCH_ENGI,
				tap5.OCCSSCI_CY AS ESRI_OCCU_LIFE_SCI,
				tap5.OCCSSRV_CY AS ESRI_OCCU_SOC_SERVICE,
				tap5.OCCLEGL_CY AS ESRI_OCCU_LEGAL,
				tap5.OCCEDUC_CY AS ESRI_OCCU_EDUCATION,
				tap5.OCCENT_CY AS ESRI_OCCU_ENTERTAIN,
				tap5.OCCHTCH_CY AS ESRI_OCCU_HEALTH,
				tap5.OCCHLTH_CY AS ESRI_OCCU_HEALTH_SUPP,
				tap5.OCCPROT_CY AS ESRI_OCCU_PROTECT,
				tap5.OCCFOOD_CY AS ESRI_OCCU_FOOD,
				tap5.OCCBLDG_CY AS ESRI_OCCU_BLDG_MAINT,
				tap5.OCCPERS_CY AS ESRI_OCCU_PERS_CARE,
				tap5.OCCSALE_CY AS ESRI_OCCU_SALES,
				tap5.OCCADMN_CY AS ESRI_OCCU_ADMIN,
				tap5.OCCFARM_CY AS ESRI_OCCU_FARM,
				tap5.OCCCONS_CY AS ESRI_OCCU_CONSTR,
				tap5.OCCMAIN_CY AS ESRI_OCCU_MAINT,
				tap5.OCCPROD_CY AS ESRI_OCCU_PROD,
				tap5.OCCTRAN_CY AS ESRI_OCCU_TRANSPORT,

				/* Education - 2020 */
				tap5.EDUCBASECY AS ESRI_EDUC_BASE,
				tap5.NOHS_CY AS ESRI_EDUC_NO_HS,
				tap5.SOMEHS_CY AS ESRI_EDUC_NO_HS,
				tap5.HSGRAD_CY AS ESRI_EDUC_HS,
				tap5.GED_CY AS ESRI_EDUC_GED,
				tap5.ASSCDEG_CY AS ESRI_EDUC_ASSO_DEG,
				tap5.BACHDEG_CY AS ESRI_EDUC_BACH_DEG,
				tap5.GRADDEG_CY AS ESRI_EDUC_GRAD_DEG,

				/* Marital status - 2020 */
				tap5.MARBASE_CY AS ESRI_MARITAL_BASE,
				tap5.MARRIED_CY AS ESRI_MARRIED,
				tap5.WIDOWED_CY AS ESRI_WIDOWED,
				tap5.DIVORCD_CY AS ESRI_DIVORCED,
				tap5.NEVMARR_CY AS ESRI_NEVER_MARRIED,

				/* Income - 2020 */
				tap5.HINCBASECY AS ESRI_HHINCOME_BASE,
				tap5.HINC0_CY AS ESRI_HHINCOME_0_14k,
				tap5.HINC15_CY AS ESRI_HHINCOME_15_24k,
				tap5.HINC25_CY AS ESRI_HHINCOME_25_34k,
				tap5.HINC35_CY AS ESRI_HHINCOME_35_49k,
				tap5.HINC50_CY AS ESRI_HHINCOME_50_74k,
				tap5.HINC75_CY AS ESRI_HHINCOME_75_99k,
				tap5.MEDHINC_CY AS ESRI_HHINCOME_MEDIAN,
				tap5.PCI_CY AS ESRI_PER_CAPITA_INCOME,
				tap5.AVGHINC_CY AS ESRI_HHINCOME_AVG,
				tap1.WLTHINDXCY AS ESRI_WEALTH_INDEX,
				tap5.MEDIA15_CY AS ESRI_HHINCOME_AGE_15_24,
				tap5.MEDIA25_CY AS ESRI_HHINCOME_AGE_25_34,
				tap5.MEDIA35_CY AS ESRI_HHINCOME_AGE_35_44,
				tap5.MEDIA45_CY AS ESRI_HHINCOME_AGE_45_54,
				tap6.MEDDI_CY AS ESRI_DISP_INCOME_MEDIAN,
				tap6.MEDNW_CY AS ESRI_NET_WORTH_MEDIAN,

				/* Income - 2025 */
				tap11.HINCBASEFY AS ESRI_HHINCOME_BASE_FY,
				tap11.HINC0_FY AS ESRI_HHINCOME_0_14k_FY,
				tap11.HINC15_FY AS ESRI_HHINCOME_15_24k_FY,
				tap11.HINC25_FY AS ESRI_HHINCOME_25_34k_FY,
				tap11.HINC35_FY AS ESRI_HHINCOME_35_49k_FY,
				tap11.HINC50_FY AS ESRI_HHINCOME_50_74k_FY,
				tap11.HINC75_FY AS ESRI_HHINCOME_75_99k_FY,
				tap11.MEDHINC_FY AS ESRI_HHINCOME_MEDIAN_FY,

				/* Housing & Affordability - 2020 */
				tap1.TOTHU_CY AS ESRI_HOUSING_UNITS,
				tap1.INCMORT_CY AS ESRI_PCT_INCOME_MORTG,
				tap1.OWNER_CY AS ESRI_HOUSING_OWNER,
				tap1.RENTER_CY AS ESRI_HOUSING_RENTER,
				tap1.VACANT_CY AS ESRI_HOUSING_VACANT,
				tap1.HAI_CY AS ESRI_HOUSING_AFFORD_INDEX,
				tap6.MEDVAL_CY AS ESRI_HOME_VALUE_MEDIAN,
				tap11.MEDVAL_FY AS ESRI_HOME_VALUE_MEDIAN_FY,

				/* Tapestry segments */
				taphh.TSEGNAME AS TAPESTRY_SEGMENT, /* too many bins (68) for modeling */
				taphh.TLIFENAME AS TAPESTRY_LIFESTYLE,
				taphh.TURBZNAME AS TAPESTRY_URBAN

			FROM output.Tapestry_Batch_&batchNumPull s /* Change to name of your sample table */
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
/*			LEFT JOIN ESRI.CFY20_07 tap7*/
/*				ON s.GEOCODE=tap7.ID*/
/*			LEFT JOIN ESRI.CFY20_08 tap8*/
/*				ON s.GEOCODE=tap8.ID*/
/*			LEFT JOIN ESRI.CFY20_09 tap9*/
/*				ON s.GEOCODE=tap9.ID*/
/*			LEFT JOIN ESRI.CFY20_10 tap10*/
/*				ON s.GEOCODE=tap10.ID*/
			LEFT JOIN ESRI.CFY20_11 tap11
				ON s.GEOCODE=tap11.ID
/*			LEFT JOIN ESRI.TAP20_ADULT tapad*/
/*				ON s.GEOCODE=tapad.ID*/
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

	* Export;
	proc export data=output.t5_Tapestry
	    outfile="&output_files/T5_Tapestry.csv"
	    dbms=csv replace;
	run;