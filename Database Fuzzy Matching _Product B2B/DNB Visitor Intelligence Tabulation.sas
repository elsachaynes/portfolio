/****************************************************************************************************/
/*  Program Name:       DNB Visitor Intelligence Tabulation.sas                                     */
/*                                                                                                  */
/*  Date Created:       July 6, 2022                                                                */
/*                                                                                                  */
/*  Created By:         Elle Haynes                                                                 */
/*                                                                                                  */
/*  Purpose:            Tabulates VI-SC match-back for the D&B Visitor Intelligence Analysis.       */
/*                                                                                                  */
/*  Inputs:             This script is meant to run manually.                                       */
/*                                                                                                  */
/* -------------------------------------------------------------------------------------------------*/	
/*  Notes:                                                                                          */
/* -------------------------------------------------------------------------------------------------*/
/*  Date Modified:                                                                                  */
/*  Modified by:                                                                                    */
/*  Description:                                                                                    */
/****************************************************************************************************/

/* -------------------------------------------------------------------------------------------------*/
/*  Libraries.                                                                                      */
/* -------------------------------------------------------------------------------------------------*/

	%let vi_file_path= /gpfsFS2/sasdata/nfs/ndc_grid/po_imca_digital/EHaynes/B2B DNB Visitor Intelligence Data Append;
	libname vi "&vi_file_path"; 

	* SalesConnect SQL Server;
	%include '/gpfsFS2/home/c156934/password.sas';
	libname sc1 sqlsvr datasrc='SQLSVR0800' SCHEMA='dbo' user="CS\C156934" password="&winpwd"
	qualifier='SALESFORCE_BACKUP';

/* -------------------------------------------------------------------------------------------------*/
/*  Import.                                                                                         */
/* -------------------------------------------------------------------------------------------------*/

	data sc;
		set vi.vi_salesconnect;
	run;

	proc import
		datafile="&vi_file_path/DNB_Matched_Final.csv"
		out=matches(drop=VAR1)
		dbms=CSV replace;
		guessingrows=MAX;
	run;

	proc import
		datafile="&vi_file_path/VI_Channel.csv"
		out=channel
		dbms=CSV replace;
		guessingrows=MAX;
	run;
	proc import
		datafile="&vi_file_path/VI_Clicks.csv"
		out=clicks
		dbms=CSV replace;
		guessingrows=MAX;
	run;
	proc import
		datafile="&vi_file_path/VI_Visit.csv"
		out=visit
		dbms=CSV replace;
		guessingrows=MAX;
	run;
	proc import
		datafile="&vi_file_path/VI_Pages.csv"
		out=pages
		dbms=CSV replace;
		guessingrows=MAX;
	run;
	proc import
		datafile="&vi_file_path/VI_Demographics.csv"
		out=demog
		dbms=CSV replace;
		guessingrows=MAX;
	run;
	proc import
		datafile="&vi_file_path/VI_Visit_Extra.csv"
		out=vi_demog
		dbms=CSV replace;
		guessingrows=MAX;
	run;

/* -------------------------------------------------------------------------------------------------*/
/*  Clean.                                                                                          */
/* -------------------------------------------------------------------------------------------------*/

	proc sql;
	create table account_matches as
	select distinct
		m.DUNS_Number
	,	m.DUNS_CompanyName
	,	s.AccountID as AccountID
	,	'' as LeadID
	,	'' as BrokerID
	,	case when s.Status = 'Active' then 1 else 0
			end as Account_Active_Flag
	,	case when s.Status = 'Terminated' then 1 else 0 
			end as Account_Termed_Flag
	,	0 as Lead_Flag
	,	0 as Broker_Flag
	,	0 as Lead_OpenOpp_Flag
	,	0 as Lead_InacOpp_Flag
	,	s.BusinessSegment
	,	s.Region
	,	'' as LeadSource
	,	. as DaysDiff format date9.
	from matches m
	left join sc s on m.AccountID_1=s.AccountID 
	where m.AccountID_1 is not missing
		and sc.AccountID is not missing
		and s.Status in ('Active','Terminated')
			
		union

	select distinct
		m.DUNS_Number
	,	m.DUNS_CompanyName
	,	s.AccountID as AccountID
	,	'' as LeadID
	,	'' as BrokerID
	,	case when s.Status = 'Active' then 1 else 0
			end as Account_Active_Flag
	,	case when s.Status = 'Terminated' then 1 else 0 
			end as Account_Termed_Flag
	,	0 as Lead_Flag
	,	0 as Broker_Flag
	,	0 as Lead_OpenOpp_Flag
	,	0 as Lead_InacOpp_Flag
	,	s.BusinessSegment
	,	s.Region
	,	'' as LeadSource
	,	. as DaysDiff format date9.
	from matches m
	left join sc s on m.AccountID_2=s.AccountID 
	where m.AccountID_2 is not missing
		and sc.AccountID is not missing
		and s.Status in ('Active','Terminated')

		union

	select distinct
		m.DUNS_Number
	,	m.DUNS_CompanyName
	,	s.AccountID as AccountID
	,	'' as LeadID
	,	'' as BrokerID
	,	case when s.Status = 'Active' then 1 else 0
			end as Account_Active_Flag
	,	case when s.Status = 'Terminated' then 1 else 0 
			end as Account_Termed_Flag
	,	0 as Lead_Flag
	,	0 as Broker_Flag
	,	0 as Lead_OpenOpp_Flag
	,	0 as Lead_InacOpp_Flag
	,	s.BusinessSegment
	,	s.Region
	,	'' as LeadSource
	,	. as DaysDiff format date9.
	from matches m
	left join sc s on m.AccountID_3=s.AccountID 
	where m.AccountID_3 is not missing
		and sc.AccountID is not missing
		and s.Status in ('Active','Terminated');
	quit;

	proc sql;
	create table account_matches_final as
	select distinct
		x.*
	from account_matches x
	where DUNS_Number in (select DUNS_Number from account_matches where Account_Active_Flag = 1)
		union
	select distinct
		y.*
	from account_matches y
	where DUNS_Number in (select DUNS_Number from account_matches where Account_Termed_Flag = 1)
		and DUNS_Number not in (select DUNS_Number from account_matches where Account_Active_Flag = 1);
	quit;

	proc sql;
	create table broker_matches as
	select distinct
		m.DUNS_Number
	,	m.DUNS_CompanyName
	,	'' as AccountID
	,	'' as LeadID
	,	s.BrokerID
	,	0 as Account_Active_Flag
	,	0 as Account_Termed_Flag
	,	0 as Lead_Flag
	,	1 as Broker_Flag
	,	0 as Lead_OpenOpp_Flag
	,	0 as Lead_InacOpp_Flag
	,	'' as BusinessSegment
	,	'' as Region
	,	'' as LeadSource
	,	. as DaysDiff format date9.
	from matches m
	left join sc s on m.BrokerID_1=s.BrokerID
	where m.BrokerID_1 is not missing
		and sc.BrokerID is not missing
			
		union

	select distinct
		m.DUNS_Number
	,	m.DUNS_CompanyName
	,	'' as AccountID
	,	'' as LeadID
	,	s.BrokerID
	,	0 as Account_Active_Flag
	,	0 as Account_Termed_Flag
	,	0 as Lead_Flag
	,	1 as Broker_Flag
	,	0 as Lead_OpenOpp_Flag
	,	0 as Lead_InacOpp_Flag
	,	'' as BusinessSegment
	,	'' as Region
	,	'' as LeadSource
	,	. as DaysDiff format date9.
	from matches m
	left join sc s on m.BrokerID_2=s.BrokerID 
	where m.BrokerID_2 is not missing
		and sc.BrokerID is not missing

		union

	select distinct
		m.DUNS_Number
	,	m.DUNS_CompanyName
	,	'' as AccountID
	,	'' as LeadID
	,	s.BrokerID
	,	0 as Account_Active_Flag
	,	0 as Account_Termed_Flag
	,	0 as Lead_Flag
	,	1 as Broker_Flag
	,	0 as Lead_OpenOpp_Flag
	,	0 as Lead_InacOpp_Flag
	,	'' as BusinessSegment
	,	'' as Region
	,	'' as LeadSource
	,	. as DaysDiff format date9.
	from matches m
	left join sc s on m.BrokerID_3=s.BrokerID 
	where m.BrokerID_3 is not missing
		and sc.BrokerID is not missing;
	quit;

	proc sql;
	create table opp_matches as
	select distinct
		m.DUNS_Number
	,	m.DUNS_CompanyName
	,	s.AccountID as AccountID
	,	'' as LeadID
	,	'' as BrokerID
	,	0 as Account_Active_Flag
	,	0 as Account_Termed_Flag
	,	1 as Lead_Flag
	,	0 as Broker_Flag
	,	1 as Lead_OpenOpp_Flag
	,	0 as Lead_InacOpp_Flag
	,	s.BusinessSegment
	,	s.Region
	,	'' as LeadSource
	,	. as DaysDiff format date9.
	from matches m
	left join sc s on m.AccountID_1=s.AccountID 
	where m.AccountID_1 is not missing
		and sc.AccountID is not missing
		and s.Status = 'Prospect - Active'
			
		union

	select distinct
		m.DUNS_Number
	,	m.DUNS_CompanyName
	,	s.AccountID as AccountID
	,	'' as LeadID
	,	'' as BrokerID
	,	0 as Account_Active_Flag
	,	0 as Account_Termed_Flag
	,	1 as Lead_Flag
	,	0 as Broker_Flag
	,	1 as Lead_OpenOpp_Flag
	,	0 as Lead_InacOpp_Flag
	,	s.BusinessSegment
	,	s.Region
	,	'' as LeadSource
	,	. as DaysDiff format date9.
	from matches m
	left join sc s on m.AccountID_2=s.AccountID 
	where m.AccountID_2 is not missing
		and sc.AccountID is not missing
		and s.Status = 'Prospect - Active'

		union

	select distinct
		m.DUNS_Number
	,	m.DUNS_CompanyName
	,	s.AccountID as AccountID
	,	'' as LeadID
	,	'' as BrokerID
	,	0 as Account_Active_Flag
	,	0 as Account_Termed_Flag
	,	1 as Lead_Flag
	,	0 as Broker_Flag
	,	1 as Lead_OpenOpp_Flag
	,	0 as Lead_InacOpp_Flag
	,	s.BusinessSegment
	,	s.Region
	,	'' as LeadSource
	,	. as DaysDiff format date9.
	from matches m
	left join sc s on m.AccountID_3=s.AccountID 
	where m.AccountID_3 is not missing
		and sc.AccountID is not missing
		and s.Status = 'Prospect - Active';
	quit;

	proc sql;
	create table inopp_matches as
	select distinct
		m.DUNS_Number
	,	m.DUNS_CompanyName
	,	s.AccountID as AccountID
	,	'' as LeadID
	,	'' as BrokerID
	,	0 as Account_Active_Flag
	,	0 as Account_Termed_Flag
	,	1 as Lead_Flag
	,	0 as Broker_Flag
	,	0 as Lead_OpenOpp_Flag
	,	1 as Lead_InacOpp_Flag
	,	s.BusinessSegment
	,	s.Region
	,	'' as LeadSource
	,	. as DaysDiff format date9.
	from matches m
	left join sc s on m.AccountID_1=s.AccountID 
	where m.AccountID_1 is not missing
		and sc.AccountID is not missing
		and s.Status = 'Prospect - Inactive'
			
		union

	select distinct
		m.DUNS_Number
	,	m.DUNS_CompanyName
	,	s.AccountID as AccountID
	,	'' as LeadID
	,	'' as BrokerID
	,	0 as Account_Active_Flag
	,	0 as Account_Termed_Flag
	,	1 as Lead_Flag
	,	0 as Broker_Flag
	,	0 as Lead_OpenOpp_Flag
	,	1 as Lead_InacOpp_Flag
	,	s.BusinessSegment
	,	s.Region
	,	'' as LeadSource
	,	. as DaysDiff format date9.
	from matches m
	left join sc s on m.AccountID_2=s.AccountID 
	where m.AccountID_2 is not missing
		and sc.AccountID is not missing
		and s.Status = 'Prospect - Inactive'

		union

	select distinct
		m.DUNS_Number
	,	m.DUNS_CompanyName
	,	s.AccountID as AccountID
	,	'' as LeadID
	,	'' as BrokerID
	,	0 as Account_Active_Flag
	,	0 as Account_Termed_Flag
	,	1 as Lead_Flag
	,	0 as Broker_Flag
	,	0 as Lead_OpenOpp_Flag
	,	1 as Lead_InacOpp_Flag
	,	s.BusinessSegment
	,	s.Region
	,	'' as LeadSource
	,	. as DaysDiff format date9.
	from matches m
	left join sc s on m.AccountID_3=s.AccountID 
	where m.AccountID_3 is not missing
		and sc.AccountID is not missing
		and s.Status = 'Prospect - Inactive';
	quit;

	proc sql;
	create table lead_matches as
	select distinct
		m.DUNS_Number
	,	m.DUNS_CompanyName
	,	'' as AccountID
	,	s.LeadId as LeadID
	,	'' as BrokerID
	,	0 as Account_Active_Flag
	,	0 as Account_Termed_Flag
	,	1 as Lead_Flag
	,	0 as Broker_Flag
	,	0 as Lead_OpenOpp_Flag
	,	0 as Lead_InacOpp_Flag
	,	s.BusinessSegment
	,	s.Region
	,	s.LeadSource
	,	datdif(s.Rec_Updt_dt,"09JUN2022"d,'ACT/ACT') as DaysDiff
	from matches m
	left join sc s on m.LeadID_1=s.LeadID 
	left join sc1.Lead l on s.LeadID=l.ID
	where m.LeadID_1 is not missing
		and sc.LeadID is not missing
		and s.LeadSource ne 'Purchased List'
			
		union

	select distinct
		m.DUNS_Number
	,	m.DUNS_CompanyName
	,	'' as AccountID
	,	s.LeadId as LeadID
	,	'' as BrokerID
	,	0 as Account_Active_Flag
	,	0 as Account_Termed_Flag
	,	1 as Lead_Flag
	,	0 as Broker_Flag
	,	0 as Lead_OpenOpp_Flag
	,	0 as Lead_InacOpp_Flag
	,	s.BusinessSegment
	,	s.Region
	,	s.LeadSource
	,	datdif(s.Rec_Updt_dt,"09JUN2022"d,'ACT/ACT') as DaysDiff
	from matches m
	left join sc s on m.LeadID_2=s.LeadID 
	left join sc1.Lead l on s.LeadID=l.ID
	where m.LeadID_2 is not missing
		and sc.LeadID is not missing
		and s.LeadSource ne 'Purchased List'

		union

	select distinct
		m.DUNS_Number
	,	m.DUNS_CompanyName
	,	'' as AccountID
	,	s.LeadId as LeadID
	,	'' as BrokerID
	,	0 as Account_Active_Flag
	,	0 as Account_Termed_Flag
	,	1 as Lead_Flag
	,	0 as Broker_Flag
	,	0 as Lead_OpenOpp_Flag
	,	0 as Lead_InacOpp_Flag
	,	s.BusinessSegment
	,	s.Region
	,	s.LeadSource
	,	datdif(s.Rec_Updt_dt,"09JUN2022"d,'ACT/ACT') as DaysDiff
	from matches m
	left join sc s on m.LeadID_3=s.LeadID
	left join sc1.Lead l on s.LeadID=l.ID 
	where m.LeadID_3 is not missing
		and sc.LeadID is not missing
		and s.LeadSource ne 'Purchased List';
	quit;

	data matches_final;
		set account_matches_final
			lead_matches
			opp_matches
			inopp_matches
			broker_matches;
	run;

	proc sql;
	create table non_matches as
	select distinct
		DUNS_Number
	,	DUNS_CompanyName
	,	'' as AccountID
	,	'' as LeadID
	,	'' as BrokerID
	,	0 as Account_Active_Flag
	,	0 as Account_Termed_Flag
	,	0 as Lead_Flag
	,	0 as Broker_Flag
	,	0 as Lead_OpenOpp_Flag
	,	0 as Lead_InacOpp_Flag
	,	'' as BusinessSegment
	,	'' as Region
	,	'' as LeadSource
	,	. as DaysDiff format date9.
	from matches
	where match = 0
		or DUNS_Number not in (select DUNS_Number from matches_final);
	quit;

	data matches_final;
		set matches_final
			non_matches;
	run;
	proc sql; select distinct count(distinct DUNS_Number) from matches_final; quit; *4250;

	proc sort data=matches_final; by DUNS_Number; run;
	proc sort data=account_matches; by DUNS_Number; run;
	data matches_final;
		merge matches_final(in=a)
			  account_matches(in=b);
		by DUNS_Number;

		Lead_Renewal_Flag = 0;
		if a and b /* active account */ 
			and (Lead_OpenOpp_Flag = 1 or Lead_InacOpp_Flag = 1)
			then do;
				Lead_Renewal_Flag = 1;
				Lead_OpenOpp_Flag = 0;
				Lead_InacOpp_Flag = 0;
			end;
	run;

		proc sort data=visit; by DUNS_Number; run;
		proc sort data=matches_final; by DUNS_Number; run;
		data matches_final;
			merge matches_final(in=a)
				  visit(in=b);
			by DUNS_Number;

			if VI_Flag = 1 then output;
		run;
		proc sql; select distinct count(distinct DUNS_Number) from matches_final; quit; *4232;


	/* COUNTS! */
	proc sql;
	select distinct
	count(distinct DUNS_Number) as Matches
	,count(distinct DUNS_Number)/4232 as Pct_Matches format percent7.2
	from matches_final
	where Account_Active_Flag=1
		or Account_Termed_Flag=1
		or Lead_Flag=1
		or Broker_Flag=1
		or Lead_OpenOpp_Flag=1
		or Lead_InacOpp_Flag=1
		or Lead_Renewal_Flag=1;

	select distinct
	count(distinct DUNS_Number) as Matches
	,Account_Active_Flag
	,Account_Termed_Flag
	,Lead_Flag
	,Broker_Flag
	,Lead_OpenOpp_Flag
	,Lead_InacOpp_Flag
	,Lead_Renewal_Flag
	from matches_final
	group by 
	Account_Active_Flag
	,Account_Termed_Flag
	,Lead_Flag
	,Broker_Flag
	,Lead_OpenOpp_Flag
	,Lead_InacOpp_Flag
	,Lead_Renewal_Flag;

	select distinct
	/* Accounts */
	count(distinct case when Account_Active_Flag=1 then DUNS_Number end) as Active
	,count(distinct case when Account_Termed_Flag=1 then DUNS_Number end) as Termed
	,count(distinct case when Account_Active_Flag=1 then DUNS_Number end)/4232 as Pct_Active format percent7.2
	,count(distinct case when Account_Termed_Flag=1 then DUNS_Number end)/4232 as Pct_Terminated format percent7.2
	/* Brokers */
	,count(distinct case when Broker_Flag=1 then DUNS_Number end) as Brokers
	,count(distinct case when Broker_Flag=1 then DUNS_Number end)/4232 as Pct_Brokers format percent7.2
	/* Leads & Opps */
	,count(distinct case when Lead_Flag=1 then DUNS_Number end) as LeadsAndOpps
	,count(distinct case when Lead_Flag=1 then DUNS_Number end)/4232 as Pct_Leads format percent7.2
	/* Open Opps */
	,count(distinct case when Lead_OpenOpp_Flag=1 then DUNS_Number end) as Open_Opp
	,count(distinct case when Lead_OpenOpp_Flag=1 then DUNS_Number end)/4232 as Pct_OpenOpp format percent7.2
	/* Inactive Opps */
	,count(distinct case when Lead_InacOpp_Flag=1 then DUNS_Number end) as Inactive_Opp
	,count(distinct case when Lead_InacOpp_Flag=1 then DUNS_Number end)/4232 as Pct_InactiveOpp format percent7.2
	/* Renewal Opps */
	,count(distinct case when Lead_Renewal_Flag=1 then DUNS_Number end) as Opp_Renewal
	,count(distinct case when Lead_Renewal_Flag=1 then DUNS_Number end)/4232 as Pct_RenewalOpp format percent7.2
	from matches_final;

	select distinct
	count(distinct DUNS_Number) as Leads
	,count(distinct DUNS_Number)/4232 as Pct_Leads format percent7.2
	,case when DaysDiff <= 30 then '0-30'
		 when DaysDiff <= 90 then '31-90'
		 when DaysDiff <= 120 then '91-120'
		 when DaysDiff <= 365 then '<1 yr'
		 else '>1 yr'
		 end as days_since
	from matches_final
	where Lead_Flag=1 and Lead_OpenOpp_Flag=0 and Lead_InacOpp_Flag=0 and Lead_Renewal_Flag=0
	group by 
	case when DaysDiff <= 30 then '0-30'
		 when DaysDiff <= 90 then '31-90'
		 when DaysDiff <= 120 then '91-120'
		 when DaysDiff <= 365 then '<1 yr'
		 else '>1 yr'
		 end;

	quit;

	/* BW metrics */
	proc sql;
	title 'Companies';
	select distinct
		count(distinct v.DUNS_Number) as visits
	,	case when Account_Active_Flag=1 then 'Account-Active'
			 when Account_Termed_Flag=1 then 'Account-Termed'
			 when Broker_Flag=1 then 'Broker'
			 when Lead_OpenOpp_Flag=1 or Lead_InacOpp_Flag=1 or Lead_Renewal_Flag=1 then 'Opportunity'
			 when Lead_Flag=1 and Lead_OpenOpp_Flag=0 and Lead_InacOpp_Flag=0 and Lead_Renewal_Flag=0 then 'Lead'
			 else 'Non-Match'
			 end as Match_Status
	from visit v
	inner join matches_final m
		on v.DUNS_Number=m.DUNS_Number
		and m.DUNS_Number is not missing
	group by 
	case when Account_Active_Flag=1 then 'Account-Active'
			 when Account_Termed_Flag=1 then 'Account-Termed'
			 when Broker_Flag=1 then 'Broker'
			 when Lead_OpenOpp_Flag=1 or Lead_InacOpp_Flag=1 or Lead_Renewal_Flag=1 then 'Opportunity'
			 when Lead_Flag=1 and Lead_OpenOpp_Flag=0 and Lead_InacOpp_Flag=0 and Lead_Renewal_Flag=0 then 'Lead'
			 else 'Non-Match'
			 end
		union
	select distinct
		count(distinct v.DUNS_Number) as visits
	,	'Overall' as Match_Status
	from visit v
	inner join matches_final m
		on v.DUNS_Number=m.DUNS_Number
		and m.DUNS_Number is not missing;

	title 'Visits & % mobile & % returning';
	select distinct
		count(distinct v.session_id) as visits
	,	count(distinct case when v.deviceCategory ne 'desktop' then v.session_id end)/count(distinct v.session_id) as pct_mobile format percent7.2
	,	count(distinct case when v.userType = 'Returning Visitor' then v.session_id end)/count(distinct v.session_id) as pct_returning format percent7.2
	,	case when Account_Active_Flag=1 then 'Account-Active'
			 when Account_Termed_Flag=1 then 'Account-Termed'
			 when Broker_Flag=1 then 'Broker'
			 when Lead_OpenOpp_Flag=1 or Lead_InacOpp_Flag=1 or Lead_Renewal_Flag=1 then 'Opportunity'
			 when Lead_Flag=1 and Lead_OpenOpp_Flag=0 and Lead_InacOpp_Flag=0 and Lead_Renewal_Flag=0 then 'Lead'
			 else 'Non-Match'
			 end as Match_Status
	from visit v
	inner join matches_final m
		on v.DUNS_Number=m.DUNS_Number
		and m.DUNS_Number is not missing
	group by 
	case when Account_Active_Flag=1 then 'Account-Active'
			 when Account_Termed_Flag=1 then 'Account-Termed'
			 when Broker_Flag=1 then 'Broker'
			 when Lead_OpenOpp_Flag=1 or Lead_InacOpp_Flag=1 or Lead_Renewal_Flag=1 then 'Opportunity'
			 when Lead_Flag=1 and Lead_OpenOpp_Flag=0 and Lead_InacOpp_Flag=0 and Lead_Renewal_Flag=0 then 'Lead'
			 else 'Non-Match'
			 end
		union
	select distinct
		count(distinct v.session_id) as visits
	,	count(distinct case when v.deviceCategory ne 'desktop' then v.session_id end)/count(distinct v.session_id) as pct_mobile format percent7.2
	,	count(distinct case when v.userType = 'Returning Visitor' then v.session_id end)/count(distinct v.session_id) as pct_returning format percent7.2
	,	'Overall' as Match_Status
	from visit v
	inner join matches_final m
		on v.DUNS_Number=m.DUNS_Number
		and m.DUNS_Number is not missing;

	create table input1 as
	select distinct
		v.*
	,	c.uniqueEvents
	,	case when Account_Active_Flag=1 then 'Account-Active'
			 when Account_Termed_Flag=1 then 'Account-Termed'
			 when Broker_Flag=1 then 'Broker'
			 when Lead_OpenOpp_Flag=1 or Lead_InacOpp_Flag=1 or Lead_Renewal_Flag=1 then 'Opportunity'
			 when Lead_Flag=1 and Lead_OpenOpp_Flag=0 and Lead_InacOpp_Flag=0 and Lead_Renewal_Flag=0 then 'Lead'
			 else 'Non-Match'
			 end as Match_Status
	from visit v
	inner join matches_final m
		on v.DUNS_Number=m.DUNS_Number
		and m.DUNS_Number is not missing
	left join clicks c
		on v.session_id=c.session_id
		and v.VI_Flag = 1;

	create table input2 as
	select distinct
		v.*
	,	case when Account_Active_Flag=1 then 'Account-Active'
			 when Account_Termed_Flag=1 then 'Account-Termed'
			 when Broker_Flag=1 then 'Broker'
			 when Lead_OpenOpp_Flag=1 or Lead_InacOpp_Flag=1 or Lead_Renewal_Flag=1 then 'Opportunity'
			 when Lead_Flag=1 and Lead_OpenOpp_Flag=0 and Lead_InacOpp_Flag=0 and Lead_Renewal_Flag=0 then 'Lead'
			 else 'Non-Match'
			 end as Match_Status
	,	c.sessionduration_sec
	,	c.bounces
	from visit v
	inner join matches_final m
		on v.DUNS_Number=m.DUNS_Number
		and m.DUNS_Number is not missing
	left join channel c
		on v.session_id=c.session_id
		and v.VI_Flag = 1
	order by v.session_id;

	create table input3 as
	select distinct
		v.*
	,	p.uniquePageviews
	,	case when Account_Active_Flag=1 then 'Account-Active'
			 when Account_Termed_Flag=1 then 'Account-Termed'
			 when Broker_Flag=1 then 'Broker'
			 when Lead_OpenOpp_Flag=1 or Lead_InacOpp_Flag=1 or Lead_Renewal_Flag=1 then 'Opportunity'
			 when Lead_Flag=1 and Lead_OpenOpp_Flag=0 and Lead_InacOpp_Flag=0 and Lead_Renewal_Flag=0 then 'Lead'
			 else 'Non-Match'
			 end as Match_Status
	from visit v
	inner join matches_final m
		on v.DUNS_Number=m.DUNS_Number
		and m.DUNS_Number is not missing
	left join pages p
		on v.session_id=p.session_id
		and v.VI_Flag = 1;
	quit;

	proc sql;
	title 'Action/Visit';
	select distinct
		sum(uniqueEvents)/count(distinct session_id) as actions_per_visit format comma8.2
	,	Match_Status
	from input1
	group by Match_Status
		union
	select distinct
		sum(uniqueEvents)/count(distinct session_id) as actions_per_visit format comma8.2
	,	'Overall' as Match_Status
	from input1;

	title 'Avg Time on Site & Bounce Rate';
	select distinct
		sum(sessionDuration_sec)/count(distinct session_id) as avg_session_dur format mmss.
	,	sum(bounces)/count(distinct session_id) as bounce_rt format percent7.2
	,	Match_Status
	from input2
	group by Match_Status
		union
	select distinct
		sum(sessionDuration_sec)/count(distinct session_id) as avg_session_dur format mmss.
	,	sum(bounces)/count(distinct session_id) as bounce_rt format percent7.2
	,	'Overall' as Match_Status
	from input2;

	title 'Pages Per Visit';
	select distinct
		count(distinct session_id) as visits
	,	sum(uniquePageviews)/count(distinct session_id) as pages_per_visits format comma8.2
	,	Match_Status
	from input3
	group by Match_Status
		union
	select distinct
		count(distinct session_id) as visits
	,	sum(uniquePageviews)/count(distinct session_id) as pages_per_visits format comma8.2
	,	'Overall' as Match_Status
	from input3;
	quit;

	proc sql;

	create table input4 as
		select distinct
		v.session_id
	,	channel
	,	channeldetail
	,	case when Account_Active_Flag=1 then 'Account-Active'
			 when Account_Termed_Flag=1 then 'Account-Termed'
			 when Broker_Flag=1 then 'Broker'
			 when Lead_OpenOpp_Flag=1 or Lead_InacOpp_Flag=1 or Lead_Renewal_Flag=1 then 'Opportunity'
			 when Lead_Flag=1 and Lead_OpenOpp_Flag=0 and Lead_InacOpp_Flag=0 and Lead_Renewal_Flag=0 then 'Lead'
			 else 'Non-Match'
			 end as Match_Status
	from visit v
	inner join matches_final m
		on v.DUNS_Number=m.DUNS_Number
		and m.DUNS_Number is not missing
	left join channel c
		on v.session_id=c.session_id
	where v.VI_Flag = 1;

	title 'Visits Channel';
	select distinct
		count(distinct session_id) as visits
	,	count(distinct session_id)/y.channel_visit as pct_visits format percent7.2
	,	channel
	,	channeldetail
	,	x.Match_Status
	from input4 x
	left join (
				select distinct 
				count(distinct session_id) as channel_visit, match_status
				from input4
				group by match_status
			  ) y on x.match_status=y.match_status
	group by x.Match_Status
		,	channel
		,	channeldetail
		union
	select distinct
		count(distinct session_id) as visits
	,	count(distinct session_id)/6080 as pct_visits format percent7.2
	,	channel
	,	channeldetail
	,	'Overall' as Match_Status
	from input4
	group by 
		channel
	,	channeldetail
	order by Match_Status, visits descending;
	quit;

	proc sql;
	create table input5 as 
	select distinct
		v.session_id
	,	sitesection_pagepath
	,	case when Account_Active_Flag=1 then 'Account-Active'
			 when Account_Termed_Flag=1 then 'Account-Termed'
			 when Broker_Flag=1 then 'Broker'
			 when Lead_OpenOpp_Flag=1 or Lead_InacOpp_Flag=1 or Lead_Renewal_Flag=1 then 'Opportunity'
			 when Lead_Flag=1 and Lead_OpenOpp_Flag=0 and Lead_InacOpp_Flag=0 and Lead_Renewal_Flag=0 then 'Lead'
			 else 'Non-Match'
			 end as Match_Status
	from visit v
	inner join matches_final m
		on v.DUNS_Number=m.DUNS_Number
		and m.DUNS_Number is not missing
	left join pages c
		on v.session_id=c.session_id
	where v.VI_Flag = 1;

	title 'Visits Site Section';
	select distinct
		count(distinct session_id)/y.match_visits as visits format percent7.2
	,	sitesection_pagepath
	,	x.Match_Status
	from input5 x
	left join (
				select distinct 
				count(distinct session_id) as match_visits, match_status
				from input4
				group by match_status
			  ) y on x.match_status=y.match_status
	group by 
		x.Match_Status
	,	sitesection_pagepath
		union
	select distinct
		count(distinct session_id)/6080 as visits
	,	sitesection_pagepath
	,	'Overall' as Match_Status
	from input5
	group by 
		sitesection_pagepath
	order by Match_Status, visits descending;
	quit;

	proc sql;

	create table input6 as
	select distinct
		v.session_id
	,	pagepath
	,	case when Account_Active_Flag=1 then 'Account-Active'
			 when Account_Termed_Flag=1 then 'Account-Termed'
			 when Broker_Flag=1 then 'Broker'
			 when Lead_OpenOpp_Flag=1 or Lead_InacOpp_Flag=1 or Lead_Renewal_Flag=1 then 'Opportunity'
			 when Lead_Flag=1 and Lead_OpenOpp_Flag=0 and Lead_InacOpp_Flag=0 and Lead_Renewal_Flag=0 then 'Lead'
			 else 'Non-Match'
			 end as Match_Status
	from visit v
	inner join matches_final m
		on v.DUNS_Number=m.DUNS_Number
		and m.DUNS_Number is not missing
	left join pages c
		on v.session_id=c.session_id
	where v.VI_Flag = 1;

	create table toppages as
	select distinct
		count(distinct session_id)/y.match_visits as visits format percent7.2
	,	pagepath
	,	x.Match_Status
	from input6 x
	left join (
				select distinct 
				count(distinct session_id) as match_visits, match_status
				from input6
				group by match_status
			  ) y on x.match_status=y.match_status
	group by 
		x.Match_status
	,	pagepath
		union
	select distinct
		count(distinct session_id)/6080 as visits
	,	pagepath
	,	'Overall' as Match_Status
	from input6
	group by 
		pagepath
	order by Match_Status, visits descending;
	quit;
	
/* -------------------------------------------------------------------------------------------------*/
/*  Slides.                                                                                         */
/* -------------------------------------------------------------------------------------------------*/

	proc sql;
	create table visits_by_company as
	select distinct
		DUNS_Number
	,	count(distinct session_id) as Visits
	from visit
	group by DUNS_Number
	order by visits desc;
	quit;
	data visits_by_company;
		set visits_by_company;
		ISP_Flag = 0;
		if DUNS_Number ne . then do;
			if Visits > 100 then ISP_Flag = 1;
		end;
	run;
	proc sort data=visit; by DUNS_Number; run;
	proc sort data=visits_by_company; by DUNS_Number; run;
	data visit;
		merge visit(in=a drop=ISP_Flag)
			  visits_by_company(in=b drop=Visits);
		by DUNS_Number;
	run;
	proc sql;
	create table visits_by_company as
	select distinct
		DUNS_Number
	,	count(distinct session_id) as Visits
	,	ISP_Flag
	from visit
	group by DUNS_Number, ISP_Flag
	order by visits desc;
	quit;	
	data visit;
		set visit;
		if ISP_Flag = 1 then VI_Flag = 0;
		if ISP_Flag = 1 then DUNS_Number = .;
	run;
	proc export
		data=visit
		outfile="&vi_file_path/VI_Visit.csv"
		dbms=csv replace;
	run;

	proc sql;
	create table slide1_matchrate as
	select distinct
		count(distinct DUNS_Number) as Companies
	,	count(distinct session_id) as Visits
	,	VI_Flag
	from visit v
	group by VI_Flag
		union
	select distinct
		.
	,	count(distinct session_id) as Visits
	,	.
	from visit v;


	create table slide1_percompany as
	select distinct
		count(distinct session_id)/count(distinct DUNS_Number) as Visits_per_Company
	,	count(distinct user_id)/count(distinct DUNS_Number) as Users_per_company
	from visit v
	where vi_flag = 1;
	quit;

	proc freq data=demog(where=(duns_addrstate in ('OR','WA')));
		tables duns_msa duns;
	run;
/*	Portland OR-WA*/

	proc freq data=visit;
		tables state
				region;
	run;

	proc sort data=visit; by DUNS_Number; run;
	proc sort data=demog; by DUNS_Number; run;
	data vi_demog;
		merge visit(in=a)
			  demog(in=b keep=DUNS_Number DUNS_MSA DUNS_AddrState DUNS_EmployeesSite_Num DUNS_CompanyName DUNS_NAICS_Num);
		by DUNS_Number;

		format KP_Region2 $4.;
		KP_Region2 = Region;
		if DUNS_AddrState = 'CA' then KP_Region2 = 'CA';
		else if DUNS_AddrState = 'CO' then KP_Region2 = 'CO';
		else if DUNS_AddrState = 'GA' then KP_Region2 = 'GA';
		else if DUNS_AddrState = 'HI' then KP_Region2 = 'HI';
		else if DUNS_AddrState in ('DC','MD','VA') then KP_Region2 = 'MAS';
		else if DUNS_AddrState = 'WA' and DUNS_MSA ne 'Portland OR-WA'  then KP_Region2 = 'WA';
		else if DUNS_AddrState = 'OR' or DUNS_MSA = 'Portland OR-WA' then KP_Region2 = 'PCNW';
		else if DUNS_AddrState not in ('CA','CO','CA','HI','DC','MD','VA','WA','OR','') or (Region = 'UN' and State ne 'UN') then KP_Region2 = 'OOA';
		else if DUNS_AddrState = '' and Region ne 'UN' then KP_Region2 = Region;
		else if DUNS_AddrState = '' and Region = 'UN' then KP_Region2 = 'UN';
		else KP_Region2 = Region;
		if KP_Region2 = 'WA' then KP_Region2 = 'KPWA';

		if DUNS_EmployeesSite_Num = 1 then Employee_Bin = 'Sole Prop';
			else if DUNS_EmployeesSite_Num >= 2 and DUNS_EmployeesSite_Num <=9 then Employee_Bin = '2-9';
			else if DUNS_EmployeesSite_Num >= 10 and DUNS_EmployeesSite_Num <= 50 then Employee_Bin = '10-50';
			else if DUNS_EmployeesSite_Num >= 51 and DUNS_EmployeesSite_Num <= 100 then Employee_Bin = '51-100';
			else if DUNS_EmployeesSite_Num >= 101 and DUNS_EmployeesSite_Num <= 999 then Employee_Bin = '101-999';
			else if DUNS_EmployeesSite_Num >= 1000 and DUNS_EmployeesSite_Num <= 9999 then Employee_Bin = '1k-9999';
			else if DUNS_EmployeesSite_Num >= 10000 then Employee_Bin = '10k+';

		if Employee_Bin in ('2-9','10-50') or (Employee_Bin = '51-100' and KP_Region2 in ('CA','CO')) then Biz_Size = 'Small';
			else if Employee_Bin not in ('','Sole Prop') then Biz_Size = 'Large';

		format NAICS_DESC $50.;
		NAICS_CD = substr(strip(put(DUNS_Naics_Num,8.)),1,2);
		if NAICS_CD = '11' then NAICS_DESC = 'Agri., Forestry, Fishing, and Hunting';
			else if NAICS_CD = '21' then NAICS_DESC = 'Mining, Quarrying, and Oil & Gas Extraction';
			else if NAICS_CD = '22' then NAICS_DESC = 'Utilities';
			else if NAICS_CD = '23' then NAICS_DESC = 'Construction';
			else if NAICS_CD in ('31','32','33') then NAICS_DESC = 'Manufacturing';
			else if NAICS_CD = '42' then NAICS_DESC = 'Wholesale Trade';
			else if NAICS_CD in ('44','45') then NAICS_DESC = 'Retail Trade';
			else if NAICS_CD in ('48','49') then NAICS_DESC = 'Transportation and Warehousing';
			else if NAICS_CD = '51' then NAICS_DESC = 'Information';
			else if NAICS_CD = '52' then NAICS_DESC = 'Finance and Insurance';
			else if NAICS_CD = '53' then NAICS_DESC = 'Real Estate and Rental & Leasing';
			else if NAICS_CD = '54' then NAICS_DESC = 'Prof., Scientific, and Tech. Svcs';
			else if NAICS_CD = '55' then NAICS_DESC = 'Mgmt of Companies and Enterprises';
			else if NAICS_CD = '56' then NAICS_DESC = 'Admin. & Support and Waste Mgmt & Remediation Svcs';
			else if NAICS_CD = '61' then NAICS_DESC = 'Educational Svcs';
			else if NAICS_CD = '62' then NAICS_DESC = 'Health Care and Social Assistance';
			else if NAICS_CD = '71' then NAICS_DESC = 'Arts, Entertainment, and Recreation';
			else if NAICS_CD = '72' then NAICS_DESC = 'Accomodation and Food Svcs';
			else if NAICS_CD = '81' then NAICS_DESC = 'Other Svcs';
			else if NAICS_CD = '92' then NAICS_DESC = 'Public Administration';
			else NAICS_DESC = 'Unknown';

		if a;
	run;

	proc sort data=vi_demog; by session_id; run;
	proc sort data=channel; by session_id; run;
	data vi_demog;
		merge vi_demog(in=a)
			  channel(in=b keep=session_id convert_call convertsubmit_contact convertsubmit_quote convertsubmit_ssq);
		by session_id;

		if a;
	run;

	proc export
		data=vi_demog(drop=State Region)
		outfile="&vi_file_path/VI_Visit_Extra.csv"
		dbms=csv replace;
	run;

	proc sql;
	create table slide2_region as
	select distinct
		KP_Region2
	,	count(distinct session_id) as visits
	,	count(distinct case when vi_flag = 1 then session_id end) as matched_visits
	,	count(distinct case when vi_flag = 1 then session_id end)/count(distinct session_id) as pct_matched_visits format percent7.2
	from vi_demog
	group by KP_Region2
		union
	select distinct
		'Tot'
	,	count(distinct session_id) as visits
	,	count(distinct case when vi_flag = 1 then session_id end) as matched_visits
	,	count(distinct case when vi_flag = 1 then session_id end)/count(distinct session_id) as matched_visits format percent7.2
	from vi_demog;

	create table slide2_ooastate as
	select distinct
		coalescec(DUNS_AddrState,State) as State
	,	count(distinct session_id) as visits
	from vi_demog
	where kp_region2 = 'OOA'
	group by coalescec(DUNS_AddrState,State)
	order by visits desc;

	create table slide2_company as
	select distinct
		DUNS_CompanyName
	,	count(distinct session_id) as visits
	from vi_demog
	where kp_region2 = 'OOA'
	group by DUNS_CompanyName
	order by visits desc;
	quit;
		
	proc sql;
	create table slide3_employees as
	select distinct
		Employee_bin
	,	count(distinct session_id) as visits
	,	count(distinct session_id)/6080 as pct_visits format percent7.2
	,	count(distinct duns_number) as companies
	,	count(distinct duns_number)/4232 as pct_comp format percent7.2
	,	sum(coalesce(Convert_call,0)+coalesce(ConvertSubmit_Quote,0)
			+coalesce(ConvertSubmit_Contact,0)+coalesce(ConvertSubmit_SSQ,0)) as Leads
	,	sum(coalesce(Convert_call,0)+coalesce(ConvertSubmit_Quote,0)
			+coalesce(ConvertSubmit_Contact,0)+coalesce(ConvertSubmit_SSQ,0))/count(distinct session_id)
			as Lead_Sub_Rate format percent7.2
	from vi_demog
	where vi_flag = 1
	group by Employee_bin
		union 
	select distinct
		'Total'
	,	count(distinct session_id) as visits
	,	count(distinct session_id)/6080 as pct_visits format percent7.2
	,	count(distinct duns_number) as companies
	,	count(distinct duns_number)/4232 as pct_comp format percent7.2
	,	sum(coalesce(Convert_call,0)+coalesce(ConvertSubmit_Quote,0)
			+coalesce(ConvertSubmit_Contact,0)+coalesce(ConvertSubmit_SSQ,0)) as Leads
	,	sum(coalesce(Convert_call,0)+coalesce(ConvertSubmit_Quote,0)
			+coalesce(ConvertSubmit_Contact,0)+coalesce(ConvertSubmit_SSQ,0))/count(distinct session_id)
			as Lead_Sub_Rate format percent7.2
	from vi_demog
	where vi_flag = 1;
	quit;

	proc sql;
	create table slide3_employees_region as
	select distinct
		'CA & CO'
	,	count(distinct session_id) as visits
	,	count(distinct session_id)/6080 as pct_visits format percent7.2
	,	count(distinct duns_number) as companies
	,	count(distinct duns_number)/4232 as pct_comp format percent7.2
	,	sum(coalesce(Convert_call,0)+coalesce(ConvertSubmit_Quote,0)
			+coalesce(ConvertSubmit_Contact,0)+coalesce(ConvertSubmit_SSQ,0)) as Leads
	,	sum(coalesce(Convert_call,0)+coalesce(ConvertSubmit_Quote,0)
			+coalesce(ConvertSubmit_Contact,0)+coalesce(ConvertSubmit_SSQ,0))/count(distinct session_id)
			as Lead_Sub_Rate format percent7.2
	from vi_demog
	where vi_flag = 1 and KP_Region2 in ('CA','CO')
		and Employee_Bin = '51-100'
	group by Employee_bin
		union 
	select distinct
		'All Other'
	,	count(distinct session_id) as visits
	,	count(distinct session_id)/6080 as pct_visits format percent7.2
	,	count(distinct duns_number) as companies
	,	count(distinct duns_number)/4232 as pct_comp format percent7.2
	,	sum(coalesce(Convert_call,0)+coalesce(ConvertSubmit_Quote,0)
			+coalesce(ConvertSubmit_Contact,0)+coalesce(ConvertSubmit_SSQ,0)) as Leads
	,	sum(coalesce(Convert_call,0)+coalesce(ConvertSubmit_Quote,0)
			+coalesce(ConvertSubmit_Contact,0)+coalesce(ConvertSubmit_SSQ,0))/count(distinct session_id)
			as Lead_Sub_Rate format percent7.2
	from vi_demog
	where vi_flag = 1 and KP_Region2 not in ('CA','CO')
		and Employee_Bin = '51-100';
	quit;

	proc freq data=vi_demog; tables Employee_Bin*Biz_Size; run;

	proc sql;
	create table visits_by_region as
	select distinct
		KP_Region2
	, 	count(distinct session_id) as state_visits
	from vi_demog
	where vi_flag = 1
	group by KP_Region2;
	quit;

	proc sql;
	create table slide4_bizdistrib as
	select distinct
		x.KP_Region2
	,	count(distinct case when Biz_Size = 'Small' then session_id end)/y.state_visits as pct_small format percent7.2
	,	count(distinct case when BIz_Size = 'Large' then session_id end)/y.state_visits as pct_large format percent7.2
	,	count(distinct case when Employee_Bin = 'Sole Prop' then session_id end)/y.state_visits as pct_sole format percent7.2
	from vi_demog x
	left join visits_by_region y
		on x.KP_Region2=y.KP_Region2
	where vi_flag = 1
	group by x.KP_Region2;
	quit;

	proc sql;
	create table slide16_industry as
	select distinct
		x.NAICS_DESC
	,	count(distinct session_id) as visits
	,	count(distinct session_id)/6080 as pct_visits format percent7.2
	from vi_demog x
	where vi_flag = 1
	group by x.NAICS_DESC
	order by visits desc;

	create table companies_industry as
	select distinct
		NAICS_DESC
	,	DUNS_CompanyName
	,	Employee_Bin
	,	KP_Region2
	,	count(distinct session_id) as visits
	from vi_demog
	where vi_flag = 1
	group by NAICS_DESC, DUNS_CompanyName, KP_Region2
	order by NAICS_DESC, visits desc;

	create table slide17_industrybiz as
	select distinct
		x.Biz_Size
	,	x.NAICS_DESC
	,	count(distinct session_id) as visits
	,	count(distinct session_id)/y.visits_biz as pct_visits format percent7.2
	from vi_demog x
	left join (
			select distinct
				count(distinct session_id) as visits_biz, Biz_Size
			from vi_demog
			where vi_flag = 1
			group by Biz_Size
			) y
			on x.Biz_Size=y.Biz_Size
	where vi_flag = 1
	group by x.Biz_Size, x.NAICS_DESC
	order by x.Biz_Size, visits desc;

	create table slide18_industrybizlead as
	select distinct
		x.Biz_Size
	,	x.NAICS_DESC
	,	count(distinct session_id) as visits
	,	sum(coalesce(Convert_call,0)+coalesce(ConvertSubmit_Quote,0)
			+coalesce(ConvertSubmit_Contact,0)+coalesce(ConvertSubmit_SSQ,0)) as Leads	
	,	sum(coalesce(Convert_call,0)+coalesce(ConvertSubmit_Quote,0)
			+coalesce(ConvertSubmit_Contact,0)+coalesce(ConvertSubmit_SSQ,0))/count(distinct session_id)
			as Lead_Sub_Rate format percent7.2
	from vi_demog x
	where vi_flag = 1
	group by x.Biz_Size, x.NAICS_DESC
	order by x.Biz_Size, lead_sub_rate desc;
	quit;
