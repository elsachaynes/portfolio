/****************************************************************************************************/
/*  Program Name:       DNB Visitor Intelligence SalesConnect Data.sas                              */
/*                                                                                                  */
/*  Date Created:       June 16, 2022                                                               */
/*                                                                                                  */
/*  Created By:         Elle Haynes                                                                 */
/*                                                                                                  */
/*  Purpose:            Compiles data from SalesConnect for the D&B Visitor Intelligence Analysis.  */
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

	* Working folder;
	%let output_file_path= /gpfsFS2/sasdata/nfs/ndc_grid/po_imca_digital/EHaynes/B2B DNB Visitor Intelligence Data Append;
	libname vi "&output_file_path"; 

	* SalesConnect SQL Server;
	%include '/gpfsFS2/home/c156934/password.sas';
	libname sc1 sqlsvr datasrc='SQLSVR0800' SCHEMA='dbo' user="CS\C156934" password="&winpwd"
	qualifier='SALESFORCE_BACKUP';

/* -------------------------------------------------------------------------------------------------*/
/*  Data Pull.                                                                                      */
/* -------------------------------------------------------------------------------------------------*/

	proc sql;
		create table vi.VI_SalesConnect as

		/* Accounts */
		select distinct
			a.id as ID
		,	a.id as AccountID
		,	'' as LeadID
		,	'' as BrokerID
		,	strip(upcase(a.Name)) as CompanyName
		,	strip(upcase(a.DBA_Name__c)) as CompanyDBAName
		,	strip(upcase(catx(' ',a.Mailing_Street__c, 
					 a.Mailing_City__c, 
					 a.Mailing_State__c, 
					 substr(a.Mailing_Zip_Code__c,1,5)))) 
					 as CompanyAddr_1
		,	strip(upcase(catx(' ',a.BillingStreet, 
					 a.BillingCity, 
					 a.BillingState, 
					 substr(a.BillingPostalCode,1,5)))) 
					 as CompanyAddr_2
		,	strip(upcase(catx(' ',a.Physical_Street__c, 
					 a.Physical_City__c, 
					 a.Physical_State__c, 
					 substr(a.Physical_Zip_Code__c,1,5)))) 
					 as CompanyAddr_3
		,	compress(a.Phone,,'kd') as CompanyPhone
		,	a.Business_segment__c as BusinessSegment
		,	a.Region__c as Region
		,	a.Account_Status__c as Status
		,	'' as LeadSource
		,	case when length(compress(a.DUNS__c,,'kd'))=9 then strip(a.DUNS__c) end as DUNS_Number
		,	coalesce(o.Num_of_Eligibles__c,0) as OpenOpportunityEligibles
		,	datepart(a.LastModifiedDate) as Rec_Updt_Dt format mmddyy10.
		from sc1.Account a
		left join 
			(select distinct
				AccountId 
			,	sum(Num_of_Eligibles__c) as Num_of_Eligibles__c
			from sc1.Opportunity
			where IsClosed = 0 /* open opportunities */
			group by AccountId
			) o
			on a.id=o.AccountId

			union

		/* Leads */
		select distinct
			l.id as ID
		,	'' as AccountID
		,	l.id as LeadID
		,	'' as BrokerID
		, 	strip(upcase(l.Company)) as CompanyName
		,	strip(upcase(l.DBA_Name__c)) as CompanyDBAName
		,	strip(upcase(catx(' ',l.Mailing_Street__c, 
					 l.Mailing_City__c, 
					 l.Mailing_State__c, 
					 substr(l.Mailing_Zip_Code__c,1,5))))
					 as CompanyAddr_1
		,	strip(upcase(catx(' ',l.Street, 
					 l.City, 
					 l.State, 
					 substr(l.PostalCode,1,5)))) 
					 as CompanyAddr_2
		,	strip(upcase(catx(' ',l.Physical_Street__c, 
					 l.Physical_City__c, 
					 l.Physical_State__c, 
					 substr(l.Physical_Zip_Code__c,1,5)))) 
					 as CompanyAddr_3
		,	compress(l.Phone,,'kd') as CompanyPhone
		,	l.Business_segment__c as BusinessSegment
		,	l.Region__c as Region
		,	cat('Lead - ',l.Status) as Status
		,	l.LeadSource /*?*/
		,	case when length(compress(l.DUNS__c,,'kd'))=9 then strip(l.DUNS__c) end as DUNS_Number
		,	0 as OpenOpportunityEligibles
		,	datepart(l.LastModifiedDate) as Rec_Updt_Dt format mmddyy10.
		from sc1.Lead l
		where l.ConvertedAccountId = ''
			and l.Status ne 'Remove From List'

			union

		/* Brokers */
		select distinct
			b.id as ID
		,	'' as AccountID
		,	'' as LeadID
		,	b.id as BrokerID
		,	strip(upcase(coalescec(b.name,bl.name))) as CompanyName
		,	strip(upcase(coalescec(b.DBA_Name__c,bl.DBA_Name__c))) as CompanyDBAName
		,	strip(upcase(catx(' ',bl.Mailing_Street__c, 
					 bl.Mailing_City__c, 
					 bl.Mailing_State__c, 
					 substr(bl.Mailing_Postal_Code__c,1,5)))) 
					 as CompanyAddr_1
		,	strip(upcase(catx(' ',bl.Compensation_Street__c, 
					 bl.Compensation_City__c, 
					 bl.Compensation_State__c, 
					 substr(bl.Compensation_Postal_Code__c,1,5)))) 
					 as CompanyAddr_2
		,	strip(upcase(catx(' ',bl.Business_Street__c, 
					 bl.Business_City__c, 
					 bl.Business_State__c, 
					 substr(bl.Business_Postal_Code__c,1,5)))) 
					 as CompanyAddr_3
		,	compress(coalescec(ba.Firm_Location_s_Phone__c,bl.Phone__c),,'kd') as CompanyPhone
		,	'' as BusinessSegment
		,	'' as Region
		,	cat('Broker - ',bl.Status__c) as Status				
		,	'' as LeadSource
		,	'' as DUNS_Number
		,	coalesce(o.Num_of_Eligibles__c,0) as OpenOpportunityEligibles
		,	datepart(b.LastModifiedDate) as Rec_Updt_Dt format mmddyy10.
		from sc1.Brokerage__c b
		left join sc1.Broker_Assignment__c ba
			on b.id=ba.Brokerage__c
		left join sc1.Brokerage_Location__c bl
			on b.id=bl.Brokerage__c
		left join 
			(select distinct
				Brokerage__c 
			,	sum(Num_of_Eligibles__c) as Num_of_Eligibles__c
			from sc1.Opportunity
			where Brokerage__c is not null
				and IsClosed = 0 /* open opportunities */
			group by Brokerage__c
			) o
			on b.id=o.Brokerage__c
		where b.Active__c = 1;
	
	quit;

	data vi.VI_SalesConnect;
		set vi.VI_SalesConnect;

		* Only keep unique populated;
		if CompanyDBAName = CompanyName then CompanyDBAName = '';
		if CompanyName = '' then CompanyName = CompanyDBAName;
		if CompanyAddr_1 = '' then CompanyAddr_1 = coalescec(CompanyAddr_2,CompanyAddr_3);
		if CompanyAddr_1 = CompanyAddr_2 then CompanyAddr_2 = '';
		if CompanyAddr_1 = CompanyAddr_3 then CompanyAddr_3 = '';
		if CompanyAddr_2 = '' then CompanyAddr_2 = CompanyAddr_3;
		if CompanyAddr_2 = CompanyAddr_3 then CompanyAddr_3 = '';

		* Flag records without enough data for a match;
		* Matches: (1) Name+Phone, (2) Name+Address, (3) Name+DUNS;
		Missing_Data_NoMatch = 0;
		if CompanyName = '' and CompanyPhone = '' then Missing_Data_NoMatch = 1;
		if CompanyName = '' and CompanyAddr_1 = '' then Missing_Data_NoMatch = 1;
		if CompanyName = '' and DUNS_Number = '' then Missing_Data_NoMatch = 1;

		CompanyName = compress(CompanyName,"ABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890!@#$%&*()-_=+;:'? " , "ki");
		CompanyDBAName = compress(CompanyDBAName,"ABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890!@#$%&*()-_=+;:'? " , "ki");
		CompanyAddr_1 = compress(CompanyAddr_1,"ABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890!@#$%&*()-_=+;:'? " , "ki");
		CompanyAddr_2 = compress(CompanyAddr_2,"ABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890!@#$%&*()-_=+;:'? " , "ki");
		CompanyAddr_3 = compress(CompanyAddr_3,"ABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890!@#$%&*()-_=+;:'? " , "ki");
		
	run;

	proc export 
		data=vi.vi_salesconnect
		outfile="&output_file_path/VI_SalesConnect.csv"
		dbms=CSV replace;
	run;

