/****************************************************************************************************/
/*  Program Name:       2_3 Data cleaning for model build _Conversion.sas                           */
/*                                                                                                  */
/*  Date Created:       July 27, 2022                                                               */
/*                                                                                                  */
/*  Created By:         Elle Haynes                                                                 */
/*                                                                                                  */
/*  Purpose:            Roll up Response and Member info for the KPIF EM OE23 Targeting Model.      */
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
/*  Roll-up Response                                                                                */
/* -------------------------------------------------------------------------------------------------*/

/*	proc freq data=output.t4_response_ilkr order=freq; */
/*		tables tp_actvy_type_cd*/
/*				rsltn_dsc*tp_clsfn_cd*/
/*			/ nopercent nocum nocol norow;*/
/*	run;*/
/**/
/*	proc freq data=output.t4_response_ilr; */
/*		tables tp_clsfn_cd*/
/*				busn_ln_ind*/
/*				tp_actvy_type_cd*tp_clsfn_cd*/
/*				busn_ln_ind*tp_clsfn_cd*/
/*				rsltn_dsc*tp_clsfn_cd;*/
/*	run;*/

	proc sql;
	create table combined_response as
	select distinct
		AGLTY_INDIV_ID
	,	coalesce(datepart(TP_START_DT),datepart(REC_RECV_DT)) as Response_Date format mmddyy10.
	,	case when TP_CLSFN_CD in ('IC','CC') then 1 else 0 end as Inbound_Call_Flag
	,	case when TP_CLSFN_CD = 'KI' then 1 else 0 end as System_Resp_Flag
	from output.t4_response_ilkr
	where TP_CLSFN_CD ne 'OC'
		and RSLTN_DSC ne 'REAL TIME LEAD' /* not available in ILR */
		and find(RSLTN_DSC,'REFERRAL')=0
		and find(RSLTN_DSC,'DO NOT ')=0
		and find(RSLTN_DSC,'COVID PREVENTION:')=0
		and find(RSLTN_DSC,'INELIGIBLE')=0
		and find(RSLTN_DSC,'MEDICAID')=0
		and find(RSLTN_DSC,'NOT INTERESTED')=0
		and find(RSLTN_DSC,'OTHER-')=0
		and RSLTN_DSC not in ('TRANSFER TO LICENSED AGENT','TRANSFER OTHER',
							  'TRANSFER','TRANSITION TO CALL','SUPERVISOR ENGAGED','SUPERVISOR CALL',
							  'TRANSFER TO ANOTHER SALES AGENT / PBE','ESCALATION')
		and RSLTN_DSC not in ('AHOD-SCHEDULE CALLBACK','ANSWERING DEVICE - LEFT MESSAGE',
							  'NO ANSWER CALLBACK NEEDED')
		and RSLTN_DSC not in ('INCORRECT / WRONG NUMBER','BAD / INCORRECT CONTACT',
							 'GHOST CALLS','CHAT ABANDONED','CALL INTERRUPTED',
							 'INCORRECT RECORD','NO ANSWER / NO MESSAGE','LEFT MESSAGE')
		and RSLTN_DSC not in ('TEST OPPORTUNITY','TEST CALL','TEST CHAT')

		union

	select distinct
		AGLTY_INDIV_ID
	,	coalesce(datepart(TP_START_DT),datepart(REC_RECV_DT)) as Response_Date format mmddyy10.
	,	case when TP_CLSFN_CD in ('IB','U') then 1 else 0 end as Inbound_Call_Flag
	,	case when TP_CLSFN_CD not in ('IB','U') then 1 else 0 end as System_Resp_Flag
	from output.t4_response_ilr
	where BUSN_LN_IND in ('KPIF','KPIF SALES','KPIF SAVE')
			and TP_CLSFN_CD ne 'OB'
			and RSLTN_DSC in ('APPLICATION_STARTED','PAPER_APPLICATION',
							  'APPLY PAGE','APPLY_DIRECT','APPLY_ONHIX',
							  'CONSUMER SHOPPING FOR PLAN OPTIONS',
							  'CONSUMER SHOPPING FOR PLANS / ELIGIBILITY FOR SUBSIDY INQUIRY',
							  'MICROSITE_VISIT','PAGE_VIEW'
							  'OE','QUOTED_MEDICAID_ELIGIBLE','QUOTED_NO_SUBSIDY',
							  'QUOTED_SUBSIDY_ELIGIBLE','SUBMIT QUOTE',
							  'SE','SUCCESS','');
	quit;

	proc sql;
	create table rollup_response as
	select distinct
		x.AGLTY_INDIV_ID
	,	2020 as OE_Season
	,	min(case when Inbound_Call_Flag = 1 then datdif(x.PROMO_START_DT,Response_Date,'ACT/ACT') end) as Days_To_Resp
	,	max(coalesce(Inbound_Call_Flag,0)) as Conv_Resp_InboundCall
/*	,	coalesce(System_Resp_Flag,0) as Conv_Resp_SystemResp*/
	from output.t1_promotion_history x
	left join combined_response y
		on x.AGLTY_INDIV_ID=y.AGLTY_INDIV_ID
		and y.Response_Date > x.PROMO_START_DT
		and y.Response_Date <= "31JAN2020"d
	where year(x.PROMO_START_DT) = 2019
	group by 
		x.AGLTY_INDIV_ID

		union

	select distinct
		x.AGLTY_INDIV_ID
	,	2021 as OE_Season
	,	min(case when Inbound_Call_Flag = 1 then datdif(x.PROMO_START_DT,Response_Date,'ACT/ACT') end) as Days_To_Resp
	,	max(coalesce(Inbound_Call_Flag,0)) as Conv_Resp_InboundCall
/*	,	coalesce(System_Resp_Flag,0) as Conv_Resp_SystemResp*/
	from output.t1_promotion_history x
	left join combined_response y
		on x.AGLTY_INDIV_ID=y.AGLTY_INDIV_ID
		and y.Response_Date > x.PROMO_START_DT
		and y.Response_Date <= "31JAN2021"d
	where year(x.PROMO_START_DT) = 2020
	group by 
		x.AGLTY_INDIV_ID

		union

	select distinct
		x.AGLTY_INDIV_ID
	,	2022 as OE_Season
	,	min(case when Inbound_Call_Flag = 1 then datdif(x.PROMO_START_DT,Response_Date,'ACT/ACT') end) as Days_To_Resp
	,	max(coalesce(Inbound_Call_Flag,0)) as Conv_Resp_InboundCall
/*	,	coalesce(System_Resp_Flag,0) as Conv_Resp_SystemResp*/
	from output.t1_promotion_history x
	left join combined_response y
		on x.AGLTY_INDIV_ID=y.AGLTY_INDIV_ID
		and y.Response_Date > x.PROMO_START_DT
		and y.Response_Date <= "31JAN2022"d
	where year(x.PROMO_START_DT) = 2021
	group by 
		x.AGLTY_INDIV_ID
	;

	quit;
		
	proc freq data=rollup_response;
		tables
			OE_Season*Conv_Resp_InboundCall
/*			OE_Season*Conv_Resp_SystemResp*/
			OE_Season*Days_To_Resp

			/nocol 
		;
	run;

	proc sort data=rollup_response; by OE_Season; run;
	proc univariate data=rollup_response;
	   by OE_Season;
	   var Days_To_Resp;
	   histogram;
	run;

/* -------------------------------------------------------------------------------------------------*/
/*  Roll-up Member                                                                                  */
/* -------------------------------------------------------------------------------------------------*/

/*	proc freq data=output.t4_membership;*/
/*		tables mjr_lob dtl_lob;*/
/*	run;*/

	proc sql;
	create table rollup_enroll as
	select distinct
		x.AGLTY_INDIV_ID
	,	2020 as OE_Season
	,	max(ELGB_START_DT) as Start_Dt format mmddyy10.
	,	max(ELGB_END_DT) as End_Dt format mmddyy10.
	,	max(case when DTL_LOB in ('INDIVIDUAL - ON EXCHANGE','INDIVIDUAL - ON HIE') then 1 else 0 end) as Conv_Enroll_OnHIX_Flag
	,	max(case when DTL_LOB in ('INDIVIDUAL - OFF EXCHANGE','INDIVIDUAL - OFF HIE') then 1 else 0 end) as Conv_Enroll_OffHIX_Flag
	from output.t1_promotion_history x
	left join output.t4_membership y
		on x.AGLTY_INDIV_ID=y.AGLTY_INDIV_ID
		and y.ELGB_START_DT >= "01JAN2020"d 
		and y.ELGB_START_DT <= "31JAN2020"d
		and y.MJR_LOB = 'INDIVIDUAL'
	where year(x.PROMO_START_DT) = 2019
	group by 
		x.AGLTY_INDIV_ID

		union

	select distinct
		x.AGLTY_INDIV_ID
	,	2021 as OE_Season
	,	max(ELGB_START_DT) as Start_Dt format mmddyy10.
	,	max(ELGB_END_DT) as End_Dt format mmddyy10.
	,	max(case when DTL_LOB in ('INDIVIDUAL - ON EXCHANGE','INDIVIDUAL - ON HIE') then 1 else 0 end) as Conv_Enroll_OnHIX_Flag
	,	max(case when DTL_LOB in ('INDIVIDUAL - OFF EXCHANGE','INDIVIDUAL - OFF HIE') then 1 else 0 end) as Conv_Enroll_OffHIX_Flag
	from output.t1_promotion_history x
	left join output.t4_membership y
		on x.AGLTY_INDIV_ID=y.AGLTY_INDIV_ID
		and y.ELGB_START_DT >= "01JAN2021"d 
		and y.ELGB_START_DT <= "31JAN2021"d
	where year(x.PROMO_START_DT) = 2020
	group by 
		x.AGLTY_INDIV_ID

		union

	select distinct
		x.AGLTY_INDIV_ID
	,	2022 as OE_Season
	,	max(ELGB_START_DT) as Start_Dt format mmddyy10.
	,	max(ELGB_END_DT) as End_Dt format mmddyy10.
	,	max(case when DTL_LOB in ('INDIVIDUAL - ON EXCHANGE','INDIVIDUAL - ON HIE') then 1 else 0 end) as Conv_Enroll_OnHIX_Flag
	,	max(case when DTL_LOB in ('INDIVIDUAL - OFF EXCHANGE','INDIVIDUAL - OFF HIE') then 1 else 0 end) as Conv_Enroll_OffHIX_Flag
	from output.t1_promotion_history x
	left join output.t4_membership y
		on x.AGLTY_INDIV_ID=y.AGLTY_INDIV_ID
		and y.ELGB_START_DT >= "01JAN2022"d 
		and y.ELGB_START_DT <= "31JAN2022"d
	where year(x.PROMO_START_DT) = 2021
	group by 
		x.AGLTY_INDIV_ID;

	quit;
		
	proc freq data=rollup_enroll;
		tables
			OE_Season*Conv_Enroll_OnHIX_Flag
			OE_Season*Conv_Enroll_OffHIX_Flag
			Start_Dt*OE_Season
		;
	run;

/* -------------------------------------------------------------------------------------------------*/
/*  Combine & Output                                                                                */
/* -------------------------------------------------------------------------------------------------*/
	
	proc sort data=rollup_response; by AGLTY_INDIV_ID OE_Season; run;
	proc sort data=rollup_enroll; by AGLTY_INDIV_ID OE_Season; run;
	data output.t10_Rollup_Conversion;
		merge rollup_response(in=a drop=Days_To_Resp)
			  rollup_enroll(in=b drop=Start_Dt End_Dt);
		by AGLTY_INDIV_ID OE_Season;
	run;

	* Export;
	proc export 
		data=output.t10_Rollup_Conversion
		outfile="&output_files/t10_Rollup_Conversion.csv"
		dbms=CSV replace;
	run;			

/*	output.t4_membership */
/*	output.t4_response_ilkr */
/*	output.t4_response_ilr */