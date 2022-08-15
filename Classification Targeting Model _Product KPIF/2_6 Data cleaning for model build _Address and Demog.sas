/****************************************************************************************************/
/*  Program Name:       2_6 Data cleaning for model build _Address and Demog.sas                    */
/*                                                                                                  */
/*  Date Created:       August 2, 2022                                                              */
/*                                                                                                  */
/*  Created By:         Elle Haynes                                                                 */
/*                                                                                                  */
/*  Purpose:            Rolls up data from Address and Demographics tables for the KPIF EM OE23     */
/*                      Targeting Model.                                                            */
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
	%let output_files = /gpfsFS2/sasdata/nfs/ndc_grid/po_imca_digital/EHaynes/__Models/KPIF_EmailTargeting_2022;
	libname output "&output_files";

/* -------------------------------------------------------------------------------------------------*/
/*  Address and Demographics                                                                        */
/* -------------------------------------------------------------------------------------------------*/

	proc sql;
	create table t13_Rollup_Demog as
	select distinct
		z.AGLTY_INDIV_ID
	,	z.OE_SEASON

	/* prior model score */
	,	case when m.MODL_DCL_VAL = . then 'U' 
			 else strip(put(m.MODL_DCL_VAL,8.))
			 end as PRIOR_MODEL_SCORE

	/* FM Tenure */
	,	coalesce(t.TENURE_DAYS,0) as FM_TENURE_DY
	,	coalesce(t.TENURE_MONTHS,0) as FM_TENURE_MO
	,	coalesce(t.TENURE_YEARS,0) as FM_TENURE_YR

	/* individual */
	,	case when floor(datdif(i.BIRTH_DT,z.FIRST_PROMO_DT,'ACT/ACT')/365) between 18 and 64
			 then floor(datdif(i.BIRTH_DT,z.FIRST_PROMO_DT,'ACT/ACT')/365)
			 else .
			 end as AGE
	,	case when floor(datdif(i.REC_INS_DT,z.FIRST_PROMO_DT,'ACT/ACT')/365)>=0
			 then floor(datdif(i.REC_INS_DT,z.FIRST_PROMO_DT,'ACT/ACT')/365)
			 else .
			 end as DATA_AGE_YEARS
	,	case when i.DO_NOT_CALL_IND = 'Y' then 1
			 else 0 end as DO_NOT_CALL_FLAG
	,	case when i.DO_NOT_MAIL_IND = 'Y' then 1
			 else 0 end as DO_NOT_MAIL_FLAG
	,	case when i.GNDR_CD = 'F' then 1 else 0 end as FEMALE_FLAG
	,	case when i.HH_HEAD_IND = 'Y' then 1 else 0 end as HH_HEAD_FLAG
	,	case when i.MRTL_STAT_CD in ('M','Y','D') then 1 else 0 end as INDIV_MARRIED_FLAG

	/* address */
	,	case when a.Region = '' then 1 else 0 end as NO_ZIP_FLAG
	,	a.HOSP_DIST_MSR
	,	a.MOB_DIST_MSR
	,	coalesce(a.APT_FLAG,0) as ADDR_APT_FLAG
	,	case when a.MAILABILITY_SCR_CD = '1' then 'EXACT DPV MATCH'
			 when a.MAILABILITY_SCR_CD = '9' then 'OTHER DPV SCORE'
			 else 'UNKNOWN'
			 end as MAILABILITY_SCR_CD
	,	case when a.ADDR_DWELL_TYPE_CD = 'S' then 'SINGLE FAMILY'
			 when a.ADDR_DWELL_TYPE_CD = 'M' then 'MULTI-FAMILY'
			 else 'UNKNOWN'
			 end as ADDR_DWELL_TYPE_CD
	,	case when a.ACE_DPV_STAT_CD = 'Y' then 1 else 0 end as DPV_VALIDATED_FLAG
	,	case when substr(a.ADDR_CARR_RTE_CD,1,1) = 'B' then 'PO BOX'
			 when substr(a.ADDR_CARR_RTE_CD,1,1) = 'R' then 'RURAL'
			 when substr(a.ADDR_CARR_RTE_CD,1,1) = 'C' then 'STANDARD'
			 when substr(a.ADDR_CARR_RTE_CD,1,1) in ('G','H') then 'OTHER'
			 else 'UNKNOWN'
			 end as ADDR_CARR_RTE
	,	coalescec(a.Region,'U') as Region
	,	coalescec(a.ST_CD,'U') as ST_CD
	,	coalescec(a.CNTY_NM,'UNKNOWN') as CNTY_NM
	,	coalescec(a.SVC_AREA_NM,'UNKNOWN') as SVC_AREA_NM
	,	coalescec(a.CITY_NM,'UNKNOWN') as CITY_NM
	from (
		select distinct
			AGLTY_INDIV_ID
		,	case when year(PROMO_START_DT) = 2019 then 2020
				 when year(PROMO_START_DT) = 2020 then 2021
				 when year(PROMO_START_DT) = 2021 then 2022
				 end as OE_Season
		,	min(PROMO_START_DT) as FIRST_PROMO_DT format mmddyy10.
		from output.t1_promotion_history
		group by 
			AGLTY_INDIV_ID
		,	case when year(PROMO_START_DT) = 2019 then 2020
				 when year(PROMO_START_DT) = 2020 then 2021
				 when year(PROMO_START_DT) = 2021 then 2022
				 end
		) z
	left join output.t2_address a /* 2,806,294 */
		on Z.AGLTY_INDIV_ID=a.AGLTY_INDIV_ID
	left join output.t3_demog_indiv i /* 2,806,290 */
		on Z.AGLTY_INDIV_ID=i.AGLTY_INDIV_ID
	left join output.t6_priormodelscore m /* 15,149,679*/
		on Z.AGLTY_INDIV_ID=m.AGLTY_INDIV_ID
		and Z.OE_Season=m.OE_Season
	left join output.t3_tenure t /* 7,160,916 */
		on i.AGLTY_INDIV_ID_CHAR=t.AGLTY_INDIV_ID
		and Z.OE_Season=t.OE_Season
	;
	quit;

	proc sql;
	create table output.t13_rollup_demog as
	select distinct
		x.*
		/* kbm */
	,	case when k.AGLTY_INDIV_ID ne . then 1 else 0 end as KBM_FLAG
	,	case when k.MARRIED_IND = 'Y' then 1 else 0 end as KBM_MARRIED_FLAG
	,	case when k.MID_INIT_TXT ne '' then 1 else 0 end as KBM_MID_INIT_FLAG
	,	case when k.UNIT_NBR_PRSN_IND = 'Y' then 1 else 0 end as KBM_APT_FLAG
	,	case when k.BANK_CARD_CD = 'M' then 1 else 0 end as BANK_CARD_M_FLAG 
	,	case when k.BANK_CARD_CD in ('M','Y') then 1 else 0 end as BANK_CARD_FLAG
	,	case when k.PC_IND = 'Y' then 1 else 0 end as PC_FLAG
	,	case when k.PC_OWN_IND = 'Y' then 1 else 0 end as PC_OWN_FLAG
	,	case when k.CRDT_ACTV_IND = 'Y' then 1 else 0 end as CREDIT_CD_FLAG
	,	case when k.HOME_IMPMNT_IND = 'Y' then 1 else 0 end as CREDIT_CD_LOWES_FLAG
	, 	case when k.LOW_END_DEPT_STOR_IND = 'Y' then 1 else 0 end as CREDIT_CD_WALMART_FLAG
	,	case when k.MAIN_STR_RTL_IND = 'Y' then 1 else 0 end as CREDIT_CD_DRUG_FLAG
	,	case when k.SPLTY_IND = 'Y' then 1 else 0 end as CREDIT_CD_SPECIALTY_FLAG
	,	case when k.SPLTY_APRL_IND = 'Y' then 1 else 0 end as CREDIT_CD_APPAREL_FLAG
	,	case when k.STD_RTL_IND = 'Y' then 1 else 0 end as CREDIT_CD_RETAIL_FLAG
	,	case when k.TRVL_PERSNL_SVCS_IND = 'Y' then 1 else 0 end as CREDIT_CD_AIRLINE_FLAG
	,	case when k.UPSCL_RTL_IND = 'Y' then 1 else 0 end as CREDIT_CD_DEPT_FLAG
	,	case when k.RTL_CARD_IND in ('M','Y') then 1 else 0 end as REWARDS_CD_RETAIL_FLAG
	,	case when k.DONOR_CD in ('P','Y') then 1 else 0 end as CHARITY_DONOR_FLAG
	,	case when k.FINC_SVCS_BNKG_IND = 'Y' then 1 else 0 end as FINC_SVCS_BNKG_FLAG
	,	case when k.FINC_SVCS_INSTL_IND = 'Y' then 1 else 0 end as FINC_SVCS_INSTL_FLAG
	,	case when k.HH_LVL_MATCH_IND = 'Y' then 1 else 0 end as HH_LVL_MATCH_FLAG
	,	case when k.ETHN_CD = 'H' then 1 else 0 end as HISPANIC_FLAG
	,	case when k.HH_LVL_MATCH_IND = 'Y' then 1 else 0 end as SURVEY_HH_RSP_FLAG
	,	case when k.HH_ONLN_IND = 'Y' then 1 else 0 end as INTERNET_ACCESS_FLAG
	,	case when k.IMAGE_MAIL_ORD_BYR_CD = 'M' then 1 else 0 end as MAIL_ORDER_BUYER_M_FLAG
	,	case when k.IMAGE_MAIL_ORD_BYR_CD in ('M','P','Y') then 1 else 0 end as MAIL_ORDER_BUYER_FLAG
	,	case when k.MAIL_ORD_RSPDR_CD = 'M' then 1 else 0 end as MAIL_ORDER_RSP_M_FLAG 
	,	case when k.MAIL_ORD_RSPDR_CD in ('M','Y') then 1 else 0 end as MAIL_ORDER_RSP_FLAG
	,	case when k.ONE_PER_ADDR_IND = 'Y' then 1 else 0 end as KBM_HH_VRFN_FLAG
	,	case when k.ADDR_VRFN_CD = '12' then '<12 mo'
			 when k.ADDR_VRFN_CD = '24' then '12-24 mo'
			 when k.ADDR_VRFN_CD = '99' then '25+ mo'
			 else 'U'
			 end as KBM_ADDR_VRFN_CD
	,	case when k.PRSN_CHILD_IND in ('P','Y') then 1 else 0 end as CHILDREN_HH_FLAG
	,	case when k.PRSN_ELDER_IND = 'Y' then 1 else 0 end as ELDER_HH_FLAG
	,	case when k.SOHO_HH_IND = 'Y' then 1 else 0 end as HOMEOFC_BIZ_HH_FLAG
	,	k.CENS_AVG_AUTO_CNT
	,	k.CENS_BLACK_PCT
	,	k.CENS_HISPANIC_PCT
	,	k.CENS_WHITE_PCT
	,	k.CENS_BLUE_CLLR_PCT
	,	k.CENS_WHITE_CLLR_PCT
	,	k.CENS_HH_CHILD_PCT
	,	k.CENS_MARRIED_PCT
	,	k.CENS_HMOWN_PCT
	,	k.CENS_MOBL_HOME_PCT
	,	k.CENS_SINGLE_HOME_PCT
	,	input(k.CENS_INCM_PCTL_CD,8.) as CENS_INCM_PCTL
	,	input(k.CENS_MED_AGE_HHER_VAL,8.) as CENS_MED_AGE
	,	input(k.CENS_MED_HH_INCM_CD,8.) as CENS_MED_HH_INCM_1k
	,	input(k.CENS_MED_HOME_VAL_CD,8.) as CENS_MED_HOME_VAL_1k
	,	case when input(k.HH_ADULTS_CNT,8.)>5
			 then 5
			 else input(k.HH_ADULTS_CNT,8.)
			 end as HH_ADULTS_CNT
	,	case when input(k.HH_CHILD_CNT,8.)>4
			 then 4
			 else input(k.HH_CHILD_CNT,8.)
			 end as HH_CHILD_CNT
	,	case when input(k.HH_PERSS_CNT,8.)>8
			 then 8
			 else input(k.HH_PERSS_CNT,8.)
			 end as HH_PERSS_CNT
	,	input(k.HOUSE_VAL_CD,8.) as HOUSE_VALUE
	,	input(k.DLVR_PT_CD,8.) as DLVR_PCT
	,	case when k.KBM_Education in ('Less than HS','HSGrad/SomeCollege/AssDeg')
				then 'NoHS/HS/SomeCollege'
				else coalescec(k.KBM_Education,'Unknown')
				end as KBM_CENS_Education
	,	case when k.DWELL_TYPE_CD = 'S' then 'SINGLE FAMILY'
			 when k.DWELL_TYPE_CD in ('A','B','C','M','P','T','W') then 'MULTI-FAMILY/OTHER'
  			 else 'UNKNOWN'
			 end as KBM_DWELL_TYPE_CD
	,	case when k.FMLY_POS_CD in ('G','P','C') then 'CHILD/GRANDPARENT'
			 when k.FMLY_POS_CD in ('F','M') then 'SINGLE HOH'
			 when k.FMLY_POS_CD in ('W','H') then 'SHARED HOH'
			 when k.FMLY_POS_CD = 'O' then 'OTHER'
			 else 'UNKNOWN'
			 end as FMLY_POS_CD
	,	input(k.HLTH_INSR_RSPDR_CD,8.)+1 as HEALTH_INS_RSPDR_SCORE
	,	case when k.HMOWN_STAT_CD in ('P','Y') then 'OWN'
			 when k.HMOWN_STAT_CD in ('R','T') then 'RENT'
			 else 'UNKNOWN'
			 end as MODEL_OWN_RENT
	,	case when input(k.LEN_RES_CD,8.)=99 then .
			 else input(k.LEN_RES_CD,8.)
			 end as LENGTH_OF_RESIDENCY
	,	case when k.NIELSEN_CNTY_SZ_CD = 'A' then 'SIZE 1-LARGEST'
			 when k.NIELSEN_CNTY_SZ_CD in ('B','C','D') then 'SIZE 2-4'
			 else 'UNKNOWN'
			 end as NIELSEN_COUNTY_SIZE_CD
	,	case when substr(k.OCCU_CD,1,1) = 'A' then 'SELF-EMPLOYED'
			 when substr(k.OCCU_CD,1,1) in ('B','E','H','L','N','F','G','M','K','O') then 'ALL OTHER'
			 when substr(k.OCCU_CD,1,1) in ('C','D') then 'EXEC/MANAGER'
			 when substr(k.OCCU_CD,1,1) in ('I','J','Q') then 'HOMEMAKER/RETIRED/STUDENT'
			 else 'UNKNOWN'
			 end as OCCUPATION
	,	coalesce(k.SUBSIDY_ELGB,0) as SUBSIDY_ELGB_OLD_FLAG
	,	input(k.ZIP_LVL_INCM_DCL_CD,8.)+1 as ZIP_LVL_INCM_DCL
	,	k.KBM_Income
	,	k.KBM_Income_Bin
	,	case when k.KBM_Ethnicity in ('MIDDLE-EASTERN','OTHER','AFRICAN','AFRICAN AM') then 'OTHER'
			 when k.KBM_Ethnicity in ('','U') then 'UNKNOWN'
			 else k.KBM_Ethnicity 
			 end as KBM_Ethnicity_S1
	,	case when k.SCORE_2 = 'C' then 'CATHOLIC'
			 when k.SCORE_2 = 'P' then 'PROTESTANT'
			 when k.SCORE_2 in ('B','E','H','I','J','K','L','M','O','S') then 'OTHER'
			 else 'UNKNOWN'
			 end as KBM_Religion_S2
	,	case when k.KBM_Language = 'Spanish' then 1 else 0 end as SPANISH_LANG_FLAG_S3
	,	case when k.SCORE_4 = '01' then 1 else 0 end as ORIGIN_MEXICO_FLAG_S4
	,	case when k.KBM_Assimilation in ('Assimilated','Bilingual English') then 'ASSIMIL/BILINGUAL ENG'
			 when k.KBM_Assimilation in ('Bilingual Native Tongue','Unassimilated') then 'UNASSIMIL/BILINGUAL NATIVE'
			 else 'UNKNOWN'
			 end as KBM_Assimilation_S5 
	,	case when k.DGTL_INVMNT_CD in ('','99') then 'UNKNOWN'
			 else cat('GROUP ',input(k.DGTL_INVMNT_CD,8.)) 
			 end as DIGITAL_INVMT_CD
	,	case when k.DGTL_SEG_CD in ('','99') then 'UNKNOWN'
			 else cat('GROUP ',input(k.DGTL_SEG_CD,8.)) 
			 end as DIGITAL_SEG_CD
	,	case when k.SCORE_9 in ('','99') then 'UNKNOWN'
			 else cat('GROUP ',input(k.SCORE_9,8.))
			 end as DIGITAL_DEVICES_S9
	from t13_rollup_demog x
	left join output.t3_demog_kbm k /* 1,837,337 */
		on x.AGLTY_INDIV_ID=k.AGLTY_INDIV_ID;
	quit;

	* Export;
	proc export
		data=output.t13_rollup_demog
		outfile="&output_files/T13_Rollup_Demog.csv"
		dbms=CSV replace;
	run;