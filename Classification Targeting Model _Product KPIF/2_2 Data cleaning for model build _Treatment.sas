/****************************************************************************************************/
/*  Program Name:       2_2 Data cleaning for model build _Treatment.sas                            */
/*                                                                                                  */
/*  Date Created:       July 26, 2022                                                               */
/*                                                                                                  */
/*  Created By:         Elle Haynes                                                                 */
/*                                                                                                  */
/*  Purpose:            Roll up PH and Elara info for the KPIF EM OE23 Targeting Model.             */
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
/*  Roll-up Promotion History                                                                       */
/* -------------------------------------------------------------------------------------------------*/

/* -------------------------------------------------------------------------------------------------*/
/*  Current Year                                                                                    */
/* -------------------------------------------------------------------------------------------------*/

/*	data look;*/
/*		set output.t1_promotion_history;*/
/**/
/*		promo_1 = scan(promo_nm,1,'_');*/
/*		promo_2 = scan(promo_nm,2,'_');*/
/*		promo_3 = scan(promo_nm,3,'_');*/
/*		promo_4 = scan(promo_nm,4,'_');*/
/*		promo_5 = scan(promo_nm,5,'_');*/
/*	run;*/
/**/
/*	proc sql;*/
/*	create table look2 as*/
/*	select distinct*/
/*		promo_start_dt*/
/*	,	promo_1*/
/*	,	promo_2*/
/*	,	promo_3*/
/*	,	promo_4*/
/*	,	promo_5*/
/*	,	count(*) as cnt*/
/*	from look*/
/*	group by */
/*		promo_start_dt*/
/*	,	promo_1*/
/*	,	promo_2*/
/*	,	promo_3*/
/*	,	promo_4*/
/*	,	promo_5*/
/*	order by */
/*		promo_start_dt*/
/*	,	promo_1*/
/*	,	promo_2*/
/*	,	promo_3*/
/*	,	promo_4*/
/*	,	promo_5;*/
/*	quit;			*/

	proc sql;
	create table rollup_ph_cy as
	select distinct
		AGLTY_INDIV_ID
	,	case when scan(PROMO_NM,1,'_') in ('OE2022','OE9') then 2022
			 when scan(PROMO_NM,1,'_') = 'OE8' then 2021
			 when scan(PROMO_NM,1,'_') = 'OE7' then 2020
			 end as OE_Season
	,	case when scan(PROMO_NM,3,'_') = 'FM' then 'FM'
			 when scan(PROMO_NM,3,'_') in ('RNC','WPL','RW') then 'RNC/WPL'
			 end as Audience_CY
	,	case when scan(PROMO_NM,3,'_') = 'FM' then 1 else 0 end as FM_Flag
	/* Holdout v. Treatment */
	,	max(case when scan(PROMO_NM,4,'_') in ('HO','CHO') then 0 else 1 end) as Treatment_Flag 
	/* October (Main) vs. December (Late) email timing */
	,	max(case when scan(PROMO_NM,2,'_') = 'EM' then 1 else 0 end) as Timing_Main_Flag
	,	max(case when scan(PROMO_NM,2,'_') = 'EM2' then 1 else 0 end) as Timing_Late_Flag
	/* Creative testing flags OE7: Different vs. Same (aka Control) creative and Subject Line 1 vs 2 */
	,	max(case when scan(PROMO_NM,4,'_') = 'CDIFF' and scan(PROMO_NM,5,'_') in ('SSAME1','SDIFF1','SDIFF2') then 1 else 0 end) as OE7_Test_MainHIOrd1_Flag
	,	max(case when scan(PROMO_NM,4,'_') = 'CDIFF' and scan(PROMO_NM,5,'_') in ('SDIFF3','SDIFF4') then 1 else 0 end) as OE7_Test_MainHIOrd2_Flag
	,	max(case when scan(PROMO_NM,4,'_') = 'CDIFF' and scan(PROMO_NM,5,'_') in ('SDIFF5','SDIFF6') then 1 else 0 end) as OE7_Test_MainHIOrd3_Flag
	,	max(case when scan(PROMO_NM,4,'_') = 'CDIFF' and scan(PROMO_NM,5,'_') in ('SSAME2','SDIFF7','SDIFF8') then 1 else 0 end) as OE7_Test_MainHIOrd4_Flag
	,	max(case when scan(PROMO_NM,5,'_') in ('SDIFF1','SDIFF3','SDIFF5','SDIFF7') then 1 else 0 end) as OE7_Test_MainSL1_Flag
	/* Creative testing flags OE8 Main: Control vs. Test Creative Order 1 - 4 */
	,	max(case when scan(PROMO_NM,4,'_') = 'ORD1' then 1 else 0 end) as OE8_Test_MainHIOrd1_Flag
	,	max(case when scan(PROMO_NM,4,'_') = 'ORD2' then 1 else 0 end) as OE8_Test_MainHIOrd2_Flag
	,	max(case when scan(PROMO_NM,4,'_') = 'ORD3' then 1 else 0 end) as OE8_Test_MainHIOrd3_Flag
	,	max(case when scan(PROMO_NM,4,'_') = 'ORD4' then 1 else 0 end) as OE8_Test_MainHIOrd4_Flag
	/* Creative testing flags OE9 Main: Subject line 1 vs. 2 and Creative Order 1-4 */
	,	max(case when substr(scan(PROMO_NM,4,'_'),1,2) = 'S1' then 1 else 0 end) as OE9_Test_MainSL1_Flag
	,	max(case when substr(scan(PROMO_NM,4,'_'),3,4) = 'ORD1' then 1 else 0 end) as OE9_Test_MainHIOrd1_Flag
	,	max(case when substr(scan(PROMO_NM,4,'_'),3,4) = 'ORD2' then 1 else 0 end) as OE9_Test_MainHIOrd2_Flag
	,	max(case when substr(scan(PROMO_NM,4,'_'),3,4) = 'ORD3' then 1 else 0 end) as OE9_Test_MainHIOrd3_Flag
	,	max(case when substr(scan(PROMO_NM,4,'_'),3,4) = 'ORD4' then 1 else 0 end) as OE9_Test_MainHIOrd4_Flag
	/* Creative testing flags OE9 Late: Clock vs. Telehealth Creative */
	,	max(case when scan(PROMO_NM,4,'_') = 'CLOCK' then 1 else 0 end) as OE9_Test_LateClock_Flag
	from output.t1_promotion_history
	group by 
		AGLTY_INDIV_ID
	,	case when scan(PROMO_NM,1,'_') in ('OE2022','OE9') then 2022
			 when scan(PROMO_NM,1,'_') = 'OE8' then 2021
			 when scan(PROMO_NM,1,'_') = 'OE7' then 2020
			 end 
	,	case when scan(PROMO_NM,3,'_') = 'FM' then 'FM'
			 when scan(PROMO_NM,3,'_') in ('RNC','WPL','RW') then 'RNC/WPL'
			 end
	order by AGLTY_INDIV_ID, OE_Season;
	quit;

	data rollup_ph_cy;
		set rollup_ph_cy;

		if Treatment_Flag = 0 then do;
			Timing_Main_Flag = 0;
			Timing_Late_Flag = 0;
			OE7_Test_MainHIOrd1_Flag = 0;
			OE7_Test_MainHIOrd2_Flag = 0;
			OE7_Test_MainHIOrd3_Flag = 0;
			OE7_Test_MainHIOrd4_Flag = 0;
			OE7_Test_MainSL1_Flag = 0;
			OE8_Test_MainHIOrd1_Flag = 0;
			OE8_Test_MainHIOrd2_Flag = 0;
			OE8_Test_MainHIOrd3_Flag = 0;
			OE8_Test_MainHIOrd4_Flag = 0;
			OE9_Test_MainSL1_Flag = 0;
			OE9_Test_MainHIOrd1_Flag = 0;
			OE9_Test_MainHIOrd2_Flag = 0;
			OE9_Test_MainHIOrd3_Flag = 0;
			OE9_Test_MainHIOrd4_Flag = 0;
			OE9_Test_LateClock_Flag = 0;
			end;

		run;
			
	* There are duplicates by Audience. Prioritize the FM designation;
	proc sql;
		select OE_Season, count(aglty_indiv_id) from rollup_ph_cy group by OE_Season;
		select OE_Season, count(distinct aglty_indiv_id) from rollup_ph_cy group by OE_Season;
		select distinct
			year(promo_start_dt) as oe_season
		,	count(distinct aglty_indiv_id) as emails
		from output.t1_promotion_history
		group by year(promo_start_dt);
	quit;


	proc sort data=rollup_ph_cy; by aglty_indiv_id OE_Season descending FM_Flag; run;
	data rollup_ph_cy(drop=FM_Flag);
		set rollup_ph_cy;
		by Aglty_indiv_id OE_Season descending FM_Flag;
		if first.OE_Season then output;
	run;

	proc sql;
		select OE_Season, count(aglty_indiv_id) from rollup_ph_cy group by OE_Season;
		select OE_Season, count(distinct aglty_indiv_id) from rollup_ph_cy group by OE_Season;
		select distinct
			year(promo_start_dt) as oe_season
		,	count(distinct aglty_indiv_id) as emails
		from output.t1_promotion_history
		group by year(promo_start_dt);
	quit;

	proc freq data=rollup_ph_cy;
		tables 
			OE_Season
			OE_Season*Audience_CY
			OE_Season*Treatment_Flag
			OE_Season*Timing_Main_Flag
			OE_Season*Timing_Late_Flag
			OE_Season*OE7_Test_MainHIOrd1_Flag
			OE_Season*OE7_Test_MainHIOrd2_Flag
			OE_Season*OE7_Test_MainHIOrd3_Flag
			OE_Season*OE7_Test_MainHIOrd4_Flag
			OE_Season*OE7_Test_MainSL1_Flag
			OE_Season*OE8_Test_MainHIOrd1_Flag
			OE_Season*OE8_Test_MainHIOrd2_Flag
			OE_Season*OE8_Test_MainHIOrd3_Flag
			OE_Season*OE8_Test_MainHIOrd4_Flag
			OE_Season*OE9_Test_MainSL1_Flag
			OE_Season*OE9_Test_MainHIOrd1_Flag
			OE_Season*OE9_Test_MainHIOrd2_Flag
			OE_Season*OE9_Test_MainHIOrd3_Flag
			OE_Season*OE9_Test_MainHIOrd4_Flag
			OE_Season*OE9_Test_LateClock_Flag
			/ nocum 
			;
	run;

/* -------------------------------------------------------------------------------------------------*/
/*  Prior Year                                                                                      */
/* -------------------------------------------------------------------------------------------------*/	

		proc freq data=output.t1_promo_hist_all; 
			tables offr_nm
					offr_nm*media_dtl_dsc
					media_chnl_cd
					media_dtl_dsc
					media_chnl_cd*media_dtl_dsc;
		run;
		proc sql; select distinct min(promo_start_dt) format mmddyy10. from output.t1_promo_hist_all; quit;
		proc sql;
		create table explore_timing as
		select distinct
			media_chnl_cd
		,	OFFR_NM
		,	year(promo_start_dt) as year
		,	month(promo_start_dt) as month
		,	count(*)
		from output.t1_promo_hist_all
		group by 
			media_chnl_cd
		,	OFFR_NM
		,	year(promo_start_dt)
		,	month(promo_start_dt);
		quit;

		data look; set output.t1_promo_hist_all;
		where OFFR_NM = 'OPEN ENROLLMENT';
		run;

	/* DM OE -- Sept/Nov 2018 (for py OE 2020) NOT AVAILABLE IN MARS
		DM OE -- Sept/Nov 2019 (for py OE 2021) OFFR_NM = OE DIRECT MAIL and month(PROMO_START_DT) in (9,10,11,12)
		DM OE -- Sept 2020 (for py OE 2022) OFFR_NM = OE DIRECT MAIL in (9,10,11,12)
			>>> DM OE -- Oct 2021 (for py OE 2023) OFFR_NM = OPEN ENROLMENT w/ 1 'L' 

		EM OE -- Nov/Dec 2018 (for py OE 2020) NOT AVAILABLE IN MARS
		EM OE -- Oct 2019 (for py OE 2021) OFFR_NM = OE EMAIL 
		EM OE -- Oct/Dec 2020 (for py OE 2022) OFFR_NM = KPIF EMAIL and MONTH(PROMO_START_DT) in (10,12)
			>>> EM OE -- Dec 2021 (for py OE 2023) OFFR_NM = OE EMAIL or OPEN ENROLLMENT w/ 2 'L's

		EM SEP -- April-Sept 2019 (for py OE 2020) OFFR_NM = KPIF EMAIL and month(promo_start_dt) ne (10,12)
		EM SEP -- Mar-Sept 2020 (for py OE 2021) OFFR_NM = KPIF EMAIL and month(promo_start_dt) ne (10,12)
		EM SEP -- Feb-Sept 2021 (for py OE 2022) OFFR_NM = KPIF_SEP_EM
			>>> EM SEP -- Feb-Sept 2022 (for py OE 2023) 
	*/

/*	,'SMU OE NOTICE','WBL_DAILY'*/

	proc sql;
	create table rollup_ph_py as
	select distinct
		AGLTY_INDIV_ID
	,	2020 as OE_Season
/*	,	count(distinct PROMO_ID) as KPIF_Tot_Promo_Cnt_PY */
/*	,	count(distinct case when OFFR_NM = 'OE DIRECT MAIL' and month(PROMO_START_DT) in (9,10,11,12) then PROMO_ID end) as KPIF_OE_DM_Cnt_PY */
/*	,	count(distinct case when OFFR_NM = 'OE EMAIL' or (OFFR_NM = 'KPIF EMAIL' and month(PROMO_START_DT) in (10,11,12)) as KPIF_OE_EM_Cnt_PY  */
	,	count(distinct case when OFFR_NM = 'KPIF_SEP_EM' or (OFFR_NM = 'KPIF EMAIL' and month(PROMO_START_DT) not in (10,11,12)) then PROMO_ID end) as KPIF_SEP_EM_Cnt_PY  /* email promotions */
	from output.t1_promo_hist_all
	where PROMO_START_DT-"24OCT2019"d between -1 and -365 /* within 1 year prior to OE2020 email */
		and OFFR_NM in ('KPIF MSCC REFERRAL','KPIF_SEP_EM','KPIF EMAIL','OE EMAIL','OE DIRECT MAIL','OPEN ENROLMENT','OPEN ENROLLMENT')
	group by 
		AGLTY_INDIV_ID
			
			union

	select distinct
		AGLTY_INDIV_ID
	,	2021 as OE_Season
/*	,	count(distinct PROMO_ID) as KPIF_Tot_Promo_Cnt_PY */
/*	,	count(distinct case when OFFR_NM = 'OE DIRECT MAIL' and month(PROMO_START_DT) in (9,10,11,12) then PROMO_ID end) as KPIF_OE_DM_Cnt_PY */
/*	,	count(distinct case when OFFR_NM = 'OE EMAIL' or (OFFR_NM = 'KPIF EMAIL' and month(PROMO_START_DT) in (10,11,12)) as KPIF_OE_EM_Cnt_PY  */
	,	count(distinct case when OFFR_NM = 'KPIF_SEP_EM' or (OFFR_NM = 'KPIF EMAIL' and month(PROMO_START_DT) not in (10,11,12)) then PROMO_ID end) as KPIF_SEP_EM_Cnt_PY  /* email promotions */
	from output.t1_promo_hist_all
	where PROMO_START_DT-"24OCT2020"d between -1 and -365 /* within 1 year prior to OE2020 email */
		and OFFR_NM in ('KPIF MSCC REFERRAL','KPIF_SEP_EM','KPIF EMAIL','OE EMAIL','OE DIRECT MAIL','OPEN ENROLMENT','OPEN ENROLLMENT')
	group by 
		AGLTY_INDIV_ID

			union

	select distinct
		AGLTY_INDIV_ID
	,	2022 as OE_Season
/*	,	count(distinct PROMO_ID) as KPIF_Tot_Promo_Cnt_PY */
/*	,	count(distinct case when OFFR_NM = 'OE DIRECT MAIL' and month(PROMO_START_DT) in (9,10,11,12) then PROMO_ID end) as KPIF_OE_DM_Cnt_PY */
/*	,	count(distinct case when OFFR_NM = 'OE EMAIL' or (OFFR_NM = 'KPIF EMAIL' and month(PROMO_START_DT) in (10,11,12)) as KPIF_OE_EM_Cnt_PY  */
	,	count(distinct case when OFFR_NM = 'KPIF_SEP_EM' or (OFFR_NM = 'KPIF EMAIL' and month(PROMO_START_DT) not in (10,11,12)) then PROMO_ID end) as KPIF_SEP_EM_Cnt_PY  /* email promotions */
	from output.t1_promo_hist_all
	where PROMO_START_DT-"24OCT2021"d between -1 and -365 /* within 1 year prior to OE2020 email */
		and OFFR_NM in ('KPIF MSCC REFERRAL','KPIF_SEP_EM','KPIF EMAIL','OE EMAIL','OE DIRECT MAIL','OPEN ENROLMENT','OPEN ENROLLMENT')
	group by 
		AGLTY_INDIV_ID;
	quit;
	
	data rollup_ph_py;
		set rollup_ph_py;
		if KPIF_SEP_EM_Cnt_PY > 0 then KPIF_SEP_EM_Flag_PY = 1;
			else KPIF_SEP_EM_Flag_PY = 0;
		drop KPIF_SEP_EM_Cnt_PY;
	run;

	proc freq data=rollup_ph_py;
		tables OE_Season*KPIF_SEP_EM_Flag_PY;
	run;

/* -------------------------------------------------------------------------------------------------*/
/*  DM promotion current year                                                                       */
/* -------------------------------------------------------------------------------------------------*/

	/* DM OE -- Sept/Nov 2019 (for cy OE 2020) OFFR_NM = OE DIRECT MAIL
		DM OE -- Sept 2020 (for cy OE 2021) OFFR_NM = OE DIRECT MAIL
		DM OE -- Oct 2021 (for cy OE 2022) OFFR_NM = OPEN ENROLMENT w/ 1 'L'
	*/

	proc sql;
	create table rollup_ph_cy_dm as
	select distinct
		AGLTY_INDIV_ID
	,	2020 as OE_Season
	,	1 as KPIF_OE_DM_Flag
	from output.t1_promo_hist_all 
	where PROMO_START_DT >= "01SEP2019"d and PROMO_START_DT <= "31DEC2019"d /* OE 2020 */
		and OFFR_NM = 'OE DIRECT MAIL'
	group by 
		AGLTY_INDIV_ID
			
			union

	select distinct
		AGLTY_INDIV_ID
	,	2021 as OE_Season
	,	1 as KPIF_OE_DM_Flag
	from output.t1_promo_hist_all
	where PROMO_START_DT >= "01SEP2020"d and PROMO_START_DT <= "31DEC2020"d /* OE 2021 */
		and OFFR_NM = 'OE DIRECT MAIL'
	group by 
		AGLTY_INDIV_ID

			union

	select distinct
		AGLTY_INDIV_ID
	,	2022 as OE_Season
	,	1 as KPIF_OE_DM_Flag
	from output.t1_promo_hist_all
	where PROMO_START_DT >= "01SEP2021"d and PROMO_START_DT <= "31DEC2021"d /* OE 2021 */
		and OFFR_NM = 'OPEN ENROLMENT' /* w/ 1 'L' */
	group by 
		AGLTY_INDIV_ID;
	quit;

	proc freq data=rollup_ph_cy_dm;
		tables OE_Season*KPIF_OE_DM_Flag;
	run;

/* -------------------------------------------------------------------------------------------------*/
/*  Roll-up Elara                                                                                   */
/* -------------------------------------------------------------------------------------------------*/

	data clean_elara;
		set output.t4_emails_elara;
		if OE_Season = 'OE2022' then OE_Season_Clean = 2022;
			else if OE_Season = 'OE2021' then OE_Season_Clean = 2021;
			else if OE_Season = 'OE2020' then OE_Season_Clean = 2020;
			else if OE_Season = 'OE2019' then OE_Season_Clean = 2019;
	run;

	proc sql;
	create table rollup_elara_py as
	select distinct
		x.AGLTY_INDIV_ID
	,	x.OE_Season_Clean as OE_Season
	,	max(case when y.Email_Open_Cnt > 0 then 1 else 0 end) as Email_Open_Flag_PY
	,	max(case when y.Email_Click_Cnt > 0 then 1 else 0 end) as Email_Click_Flag_PY
	,	sum(y.Email_Open_Cnt)/sum(y.Email_Send_Cnt) as Email_Open_Rt_PY
	,	sum(y.Email_Click_Cnt)/sum(y.Email_Send_Cnt) as Email_Click_Rt_PY
	/* top 3 email clients */
	, 	max(y.Email_Gmail_Flag) as Email_Gmail_Flag
	,	max(y.Email_Yahoo_Flag) as Email_Yahoo_Flag
	,	max(y.Email_Hotmail_Flag) as Email_Hotmail_Flag
	/* top 2 email domains */
	,	max(y.Email_COM_Flag) as Email_COM_Flag
	,	max(y.Email_NET_Flag) as Email_NET_Flag
	from clean_elara x
	left join clean_elara y
		on x.AGLTY_INDIV_ID=y.AGLTY_INDIV_ID
		and x.OE_Season_Clean-y.OE_Season_Clean=1
	group by 
		x.AGLTY_INDIV_ID
	,	x.OE_Season_Clean
	order by AGLTY_INDIV_ID, OE_Season;
	quit;

/* -------------------------------------------------------------------------------------------------*/
/*  Combine & Output                                                                                */
/* -------------------------------------------------------------------------------------------------*/

	proc sort data=rollup_ph_cy; by AGLTY_INDIV_ID OE_Season; run;
	proc sort data=rollup_ph_py; by AGLTY_INDIV_ID OE_Season; run;
	proc sort data=rollup_ph_cy_dm; by AGLTY_INDIV_ID OE_Season; run;
	proc sort data=rollup_elara_py; by AGLTY_INDIV_ID OE_Season; run;
	data output.t9_Rollup_Treatment;
		merge rollup_ph_cy(in=a)
			  rollup_ph_py(in=b)
			  rollup_ph_cy_dm(in=c)
			  rollup_elara_py(in=d);
		by AGLTY_INDIV_ID OE_Season;

		if a;

		* Replace missing numeric w/ 0;
		 array change _numeric_;
	        do over change;
	            if change=. then change=0;
	        end;

		drop Email_Click_Flag_PY Email_Click_Rt_PY Email_Open_Rt_PY; *too small;

	run;

	proc freq data=output.t9_Rollup_Treatment;
		tables OE_Season
				OE_Season*Audience_CY
				OE_Season*Treatment_Flag
				OE_Season*Timing_Main_Flag
				OE_Season*Timing_Late_Flag
				OE7_Test_MainHIOrd1_Flag
				OE7_Test_MainHIOrd2_Flag
				OE7_Test_MainHIOrd3_Flag
				OE7_Test_MainHIOrd4_Flag
				OE7_Test_MainSL1_Flag
				OE8_Test_MainHIOrd1_Flag
				OE8_Test_MainHIOrd2_Flag
				OE8_Test_MainHIOrd3_Flag
				OE8_Test_MainHIOrd4_Flag
				OE9_Test_MainSL1_Flag
				OE9_Test_MainHIOrd1_Flag
				OE9_Test_MainHIOrd2_Flag
				OE9_Test_MainHIOrd3_Flag
				OE9_Test_MainHIOrd4_Flag
				OE9_Test_LateClock_Flag
				OE_Season*KPIF_SEP_EM_Flag_PY
				OE_Season*KPIF_OE_DM_Flag
				OE_Season*Email_Open_Flag_PY
/*				OE_Season*Email_Click_Flag_PY*/
/*				OE_Season*Email_Open_Rt_PY*/
/*				OE_Season*Email_Click_Rt_PY*/
				OE_Season*Email_Gmail_Flag
				OE_Season*Email_Yahoo_Flag
				OE_Season*Email_Hotmail_Flag /* possibly too small */
				OE_Season*Email_COM_Flag
				OE_Season*Email_NET_Flag /* possibly too small */
				;
	run;

	* Export;
	proc export 
		data=output.t9_Rollup_Treatment
		outfile="&output_files/t9_Rollup_Treatment.csv"
		dbms=CSV replace;
	run;			

	proc delete data=output.t1_promo_ids; run;
	proc delete data=output.t1_promo_hist_all; run;
/*	proc delete data=output.t1_promotion_history; run;*/
/*	output.t4_emails_elara*/