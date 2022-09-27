/****************************************************************************************************/
/*  Program Name:       1_4 Data pull for model build _Resp Mem and Elara.sas                       */
/*                                                                                                  */
/*  Date Created:       July 11, 2022                                                               */
/*                                                                                                  */
/*  Created By:         Elle Haynes                                                                 */
/*                                                                                                  */
/*  Purpose:            Compiles data from MARS Individual Lead Response, Individual Lead KPIF      */
/*                      Reponse (historical), Member, and JSkelly's cleaned ELARA tables for the    */
/*                      KPIF EM OE 2023 Targeting model.                                            */
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

	%let nuid =  ##MASKED##;

	* Input;
	%include "/gpfsFS2/home/&nuid./password.sas";
	libname MARS sqlsvr DSN='SQLSVR4685' SCHEMA='dbo' user="CS\&nuid" password="&winpwd"
	     qualifier='MARS' readbuff=5000 insertbuff=5000 dbcommit=1000; run;
	libname WS sqlsvr datasrc='WS_NYDIA' SCHEMA='dbo' user="CS\&nuid" password="&winpwd"
	     qualifier='WS_EHAYNES' readbuff=5000 insertbuff=5000 dbcommit=1000; run;
	libname ESRI sqlsvr DSN='WS_NYDIA' SCHEMA='dbo' user="CS\&nuid" password="&winpwd"
	     qualifier='ESRI_TAPESTRY' readbuff=5000 insertbuff=5000 dbcommit=1000; run;
	libname ELARA sqlsvr DSN='SQLSVR4656' SCHEMA='dbo' user="CS\&nuid" password="&winpwd"
     	qualifier='ELARA' readbuff=5000 insertbuff=5000 dbcommit=1000; run;
	libname OE6 sqlsvr DSN='WS_NYDIA' SCHEMA='OE6' user="CS\&nuid" password="&winpwd"
	    qualifier='WS_JSKELLY' readbuff=5000 insertbuff=5000 dbcommit=1000; run;

	* Output;
	%let output_files = ##MASKED##;
	libname output "&output_files";

/* -------------------------------------------------------------------------------------------------*/
/*  Response                                                                                        */
/* -------------------------------------------------------------------------------------------------*/

	proc sql;

	CREATE TABLE output.t4_Response_ILR AS
	SELECT 
		*
	FROM MARS.INDIVIDUAL_LEAD_RESPONSE
	WHERE AGLTY_INDIV_ID IN (SELECT AGLTY_INDIV_ID FROM output.t1_Promotion_History);

	quit;

	* Export;
	proc export data=output.t4_Response_ILR
	    outfile="&output_files/T4_Response_ILR.csv"
	    dbms=csv replace;
	run;

	proc sql;

	CREATE TABLE output.t4_Response_ILKR AS
	SELECT 
		*
	FROM MARS.INDIVIDUAL_LEAD_KPIF_RESPONSE
	WHERE AGLTY_INDIV_ID IN (SELECT AGLTY_INDIV_ID FROM output.t1_Promotion_History);

	quit;

	* Export;
	proc export data=output.t4_Response_ILKR
	    outfile="&output_files/T4_Response_ILKR.csv"
	    dbms=csv replace;
	run;

/* -------------------------------------------------------------------------------------------------*/
/*  Membership                                                                                      */
/* -------------------------------------------------------------------------------------------------*/

	/*
	Elgb_start_date should be Jan 1st and Feb 1st since open enrollment goes until Jan 31st. 
	*/

	proc sql;

	CREATE TABLE output.t4_Membership AS
	SELECT 
		m.*
	,	l.MJR_LOB
	,	l.DTL_LOB
	FROM MARS.Member m
	LEFT JOIN MARS.MMSA_LOB l
		on m.ENRL_UNIT_ID=l.ENRL_UNIT_ID
		AND m.ELGB_START_DT=l.ELGB_START_DT
		and m.MBR_ID=l.MBR_ID
	WHERE m.AGLTY_INDIV_ID IN (SELECT AGLTY_INDIV_ID FROM output.t1_Promotion_History);

	quit;

	* Export;
	proc export data=output.t4_Membership
	    outfile="&output_files/T4_Member.csv"
	    dbms=csv replace;
	run;

/* -------------------------------------------------------------------------------------------------*/
/*  Elara                                                                                           */
/* -------------------------------------------------------------------------------------------------*/

	* Get email address for each agility;
	proc sql;
	create table APPENDED_EMAILS as 
	select distinct
		x.AGLTY_INDIV_ID
	,	y.EMAIL_ADDR_TXT
	from output.t1_Promotion_History x 
	left join MARS.INDIVIDUAL y
		on x.AGLTY_INDIV_ID = y.AGLTY_INDIV_ID; 
	quit;

		proc sql;  /* Agilities with email addresses: 98.7% */
		select distinct 
		 	count(distinct case when EMAIL_ADDR_TXT is not missing then EMAIL_ADDR_TXT end)
			/count(distinct AGLTY_INDIV_ID) 
			as PERCENT_EMAIL FORMAT percent7.2 
		from APPENDED_EMAILS;
		quit;

		proc sql;  /* Find out which JSkelly table has more matches for OE2019 */
		select distinct /* 36% */
		 	count(distinct y.AGLTY_INDIV_ID)/count(distinct x.AGLTY_INDIV_ID) as Pct_Match_4b FORMAT percent7.2 
		from APPENDED_EMAILS x
		left join OE6.EM4B y
			ON lowcase(x.EMAIL_ADDR_TXT) = y.EMAIL;

		select distinct /* 34% */
		 	count(distinct y.AGLTY_INDIV_ID)/count(distinct x.AGLTY_INDIV_ID) as Pct_Match_4c FORMAT percent7.2 
		from APPENDED_EMAILS x
		left join OE6.EM4C y
			ON lowcase(x.EMAIL_ADDR_TXT) = y.EMAIL;

		select distinct /* 36% */
		 	count(distinct y.AGLTY_INDIV_ID)/count(distinct x.AGLTY_INDIV_ID) as Pct_Match_4c1 FORMAT percent7.2 
		from APPENDED_EMAILS x
		left join OE6.EM4C1 y
			ON lowcase(x.EMAIL_ADDR_TXT) = y.EMAIL;
		quit;

	/* pull email history older than 2 years ago */
	proc sql;
	create table email_oe2019 AS
	select distinct
		x.*
	,	"OE2019" AS OE_Season
	,	substr(x.EMAIL_ADDR_TXT, find(x.EMAIL_ADDR_TXT, '@') + 1) AS Email_Domain
	,	"ELOQUA" AS EMAIL_SERVER
	,	sum(coalesce(Y.CSEND1,0)) AS Email_Send_Cnt
	,	sum(coalesce(Y.COPEN1,0)) AS Email_Open_Cnt
	,	sum(coalesce(Y.CCLICK1,0)) AS Email_Click_Cnt
	,	sum(coalesce(Y.CBB1,0)) AS Email_Bounce_Cnt
	,	sum(coalesce(Y.CSUB1,0)) AS Email_Unsub_Cnt
	from APPENDED_EMAILS x
	left join OE6.EM4B y
		ON lowcase(x.EMAIL_ADDR_TXT) = y.EMAIL
	group by pby 
		x.AGLTY_INDIV_ID
	,	x.EMAIL_ADDR_TXT
	,	substr(x.EMAIL_ADDR_TXT, FIND(x.EMAIL_ADDR_TXT, '@') + 1);
	quit;

	data email_oe2019;
		retain AGLTY_INDIV_ID
			   Email_Gmail_Flag
			   Email_Yahoo_Flag
			   Email_Hotmail_Flag
			   Email_COM_Flag
			   Email_NET_Flag
			   OE_Season
			   Email_Send_Cnt
			   Email_Open_Cnt
			   Email_Click_Cnt
			   Email_Bounce_Cnt
			   Email_Unsub_Cnt;

		set email_oe2019;

		where Email_Send_Cnt > 0; /* ~65% of rows :( */

		* Limit to 1 per email (flags);
		if Email_Open_Cnt > Email_Send_Cnt then Email_Open_Cnt = Email_Send_Cnt;
		if Email_Click_Cnt > Email_Open_Cnt then Email_Click_Cnt = Email_Open_Cnt;

		* Client flags;
		Email_Gmail_Flag = 0; *#1 by emails sent;
		Email_Yahoo_Flag = 0; *#2 by emails sent;
		Email_Hotmail_Flag = 0; *#3 by emails_sent;
		if Email_Domain = 'GMAIL.COM' then Email_Gmail_Flag = 1;
		else if Email_Domain = 'YAHOO.COM' then Email_Yahoo_Flag = 1;
		else if Email_Domain = 'HOTMAIL.COM' then Email_Hotmail_Flag = 1;

		*Domain flags;
		Domain = substr(email_domain, find(email_domain, '.') +1);
		Email_COM_Flag = 0; *#1 by emails sent;
		Email_NET_Flag = 0; *#2 by emails sent;
		if Domain = 'COM' then Email_COM_Flag = 1;
		else if Domain = 'NET' then Email_NET_Flag = 1;
		drop Domain;

		drop Email_Addr_txt Email_Domain Email_Server;

	run;

	proc freq data=email_oe2019;
		tables Email_Send_Cnt
				Email_Open_Cnt
				Email_Click_Cnt
				Email_Bounce_Cnt
				Email_Unsub_Cnt
				Email_Gmail_Flag
				Email_Yahoo_Flag
				Email_Hotmail_Flag
				Email_COM_Flag
				Email_NET_Flag
				/ norow nocum;
	run;

	/* pull all the email history (last 2 years, all lob) */
	proc sql;
	create table output.t4_emails_elara as
	select distinct
		x.*
	,	y.ASSET_NAME
	,	y.ACTIVITY_DATE as ACTIVITY_DATE_TIME format datetime18.
	,	y.ACTIVITY_TYPE
	,	"ELOQUA" as EMAIL_SERVER 
	from APPENDED_EMAILS x
	left join ELARA.ELOQUA_CONTACT_ACTIVITY y
		on lowcase(x.EMAIL_ADDR_TXT) = y.EMAIL_ADDRESS 
	where y.ACTIVITY_TYPE in ('Bounceback','EmailClickthrough',
								'EmailOpen','EmailSend','Unsubscribe') 

	union 

	select distinct /* was only used for SEP campaigns */
		x.*
	,	y.MAILING_NAME
	,	y.ACTIVITY_DATE as ACTIVITY_DATE_TIME format datetime18.
	,	y.ACTIVITY_TYPE 
	,	"SOURCE_FLOW" as EMAIL_SERVER
	from APPENDED_EMAILS x
	left join ELARA.SF_CNTCT_ACTVTY y
		on lowcase(x.EMAIL_ADDR_TXT) = y.EMAIL_ADDR 
	where y.ACTIVITY_TYPE in ('Bounceback','EmailClickthrough',
								'EmailOpen','EmailSend','Unsubscribe');
	QUIT;

			/* find relevant email campaigns by asset_name */
/*			data look;*/
/*				set output.t4_emails_elara;*/
/*				where ACTIVITY_TYPE = 'EmailSend';*/
/*				if find(asset_name,'_SBU_')>0 then delete;*/
/*				if find(asset_name,'_Med_')>0 then delete;*/
/*				if find(asset_name,'_MED_')>0 then delete;*/
/*				if find(asset_name,'MAI')>0 then delete;*/
/*				if find(asset_name,'_FEDS_')>0 then delete;*/
/*				if find(asset_name,'_Ret_')>0 then delete;*/
/*				if find(asset_name,'_SEP_')>0 then delete;*/
/*			run;*/
/*			proc sql;*/
/*			create table asset_freq as*/
/*				select distinct*/
/*					asset_name*/
/*				,	email_server*/
/*				,	count(distinct EMAIL_ADDR_TXT) as Count*/
/*				,	datepart(ACTIVITY_DATE_TIME) as Activity_Date format mmddyy10.*/
/*				from look*/
/*				group by asset_name, email_server*/
/*				order by Activity_Date, count desc;*/
/*			quit;*/

	/* restrict to relevant email campaigns */
	data subset;
		set output.t4_emails_elara;
			
		where find(asset_name,'Cnsmr_Acq_KPIF_OE_')>0
			or find(asset_name,'Cnsmr_Acq_KPIF_OE8')>0
			or find(asset_name,'Cnsmr_Acq_KPIF_OE9')>0;

	run;

	proc sql;
	create table rollup_by_email as
	select distinct
		AGLTY_INDIV_ID
	,	substr(EMAIL_ADDR_TXT, find(EMAIL_ADDR_TXT, '@') + 1) as Email_Domain
/*	,	max(case when EMAIL_SERVER = "SOURCE_FLOW" then 1 else 0 end) as EmailClient_SF_Flag*/
	,	asset_name
	,	sum(case when ACTIVITY_TYPE = "EmailSend" then 1 ELSE 0 END) AS Email_Send_Cnt 
	,	sum(case when ACTIVITY_TYPE = "EmailOpen" then 1 ELSE 0 END) AS Email_Open_Cnt 
	,	sum(case when ACTIVITY_TYPE = "EmailClickthrough" then 1 ELSE 0 END) AS Email_Click_Cnt 
	,	sum(case when ACTIVITY_TYPE = "Bounceback" then 1 ELSE 0 END) AS Email_Bounce_Cnt 
	,	sum(case when ACTIVITY_TYPE = "Unsubscribe" then 1 ELSE 0 END) AS Email_Unsub_Cnt 
	from subset
	group by
		AGLTY_INDIV_ID
	,	substr(EMAIL_ADDR_TXT, find(EMAIL_ADDR_TXT, '@') + 1)
	,	asset_name;
	quit;

		proc sql;
		create table clients as
		select distinct
			email_domain, count(*) as cnt
		from rollup_by_email
		group by email_domain
		order by cnt desc;

		create table domains as
		select distinct
			substr(email_domain, find(email_domain, '.') +1) as domain, count(*) as cnt
		from rollup_by_email
		group by substr(email_domain, find(email_domain, '.') +1)
		order by cnt desc;
		quit;

	data rollup_by_email;	
		set rollup_by_email;
		where Email_Send_Cnt > 0; /* 4,195 rows (0.02%) */

		* Limit to 1 per email (flags);
		if Email_Send_Cnt > 0 then Email_Send_Cnt = 1;
		if Email_Open_Cnt > 0 then Email_Open_Cnt = 1;
		if Email_Click_Cnt > 0 then Email_Click_Cnt = 1;
		if Email_Bounce_Cnt > 0 then Email_Bounce_Cnt = 1;
		if Email_Unsub_Cnt > 0 then Email_Unsub_Cnt = 1;

		* Client flags;
		Email_Gmail_Flag = 0; *#1 by emails sent;
		Email_Yahoo_Flag = 0; *#2 by emails sent;
		Email_Hotmail_Flag = 0; *#3 by emails_sent;
		if Email_Domain = 'GMAIL.COM' then Email_Gmail_Flag = 1;
		else if Email_Domain = 'YAHOO.COM' then Email_Yahoo_Flag = 1;
		else if Email_Domain = 'HOTMAIL.COM' then Email_Hotmail_Flag = 1;

		*Domain flags;
		Domain = substr(email_domain, find(email_domain, '.') +1);
		Email_COM_Flag = 0; *#1 by emails sent;
		Email_NET_Flag = 0; *#2 by emails sent;
		if Domain = 'COM' then Email_COM_Flag = 1;
		else if Domain = 'NET' then Email_NET_Flag = 1;
		drop Domain;
	run;

	proc freq data=rollup_by_email;
		tables Email_Send_Cnt
				Email_Open_Cnt
				Email_Click_Cnt
				Email_Bounce_Cnt
				Email_Unsub_Cnt
				Email_Gmail_Flag
				Email_Yahoo_Flag
				Email_Hotmail_Flag
				Email_COM_Flag
				Email_NET_Flag
				/ norow nocum;
	run;

	proc sql;
	create table output.t4_emails_elara as
	select distinct
		AGLTY_INDIV_ID
	,	max(Email_Gmail_Flag) as Email_Gmail_Flag
	,	max(Email_Yahoo_Flag) as Email_Yahoo_Flag
	,	max(Email_Hotmail_Flag) as Email_Hotmail_Flag
	,	max(Email_COM_Flag) as Email_COM_Flag
	,	max(Email_NET_Flag) as Email_NET_Flag
/*	,	max(EmailClient_SF_Flag) as  EmailClient_SF_Flag*/
	,	case when find(asset_name,'Cnsmr_Acq_KPIF_OE_')>0 then "OE2020"
			 when find(asset_name,'Cnsmr_Acq_KPIF_OE8')>0 then "OE2021"
			 when find(asset_name,'Cnsmr_Acq_KPIF_OE9')>0 then "OE2022"
			 else "EXCLUDE" end
			 as OE_Season
	,	sum(Email_Send_Cnt) AS Email_Send_Cnt 
	,	sum(Email_Open_Cnt) AS Email_Open_Cnt 
	,	sum(Email_Click_Cnt) AS Email_Click_Cnt 
	,	sum(Email_Bounce_Cnt) AS Email_Bounce_Cnt 
	,	sum(Email_Unsub_Cnt) AS Email_Unsub_Cnt 
	from rollup_by_email
	group by
		AGLTY_INDIV_ID
	,	case when find(asset_name,'Cnsmr_Acq_KPIF_OE_')>0 then "OE2020"
			 when find(asset_name,'Cnsmr_Acq_KPIF_OE8')>0 then "OE2021"
			 when find(asset_name,'Cnsmr_Acq_KPIF_OE9')>0 then "OE2022"
			 else "EXCLUDE" end;
	quit;

	data output.t4_emails_elara;
		set output.t4_emails_elara
			email_oe2019;
	run;

	proc freq data=output.t4_emails_elara; 
		tables
		OE_Season
		Email_Send_Cnt*OE_Season
		Email_Open_Cnt*OE_Season
		Email_Click_Cnt*OE_Season
		Email_Unsub_Cnt*OE_Season
		Email_Bounce_Cnt*OE_Season
		Email_Gmail_Flag*OE_Season
		Email_Yahoo_Flag*OE_Season
		Email_Hotmail_Flag*OE_Season
		Email_COM_Flag*OE_Season
		Email_NET_Flag*OE_Season
			/ norow nopercent;
	run;

			proc sql;  /* % of agilities with email history: 79.5% */
			select distinct 
				count(distinct t4.AGLTY_INDIV_ID)/count(distinct t1.AGLTY_INDIV_ID) 
				as Pct_Email FORMAT percent7.2 
			from output.t1_promotion_history t1
			left join output.t4_emails_elara t4
				on t1.AGLTY_INDIV_ID=t4.AGLTY_INDIV_ID;
			quit;










	* Export;
	proc export data=output.t4_Elara
	    outfile="&output_files/T4_Elara.csv"
	    dbms=csv replace;
	run;
