/****************************************************************************************************/
/*  Program Name:       2_4 Data cleaning for model build _External Sources.sas                     */
/*                                                                                                  */
/*  Date Created:       August 1, 2022                                                              */
/*                                                                                                  */
/*  Created By:         Elle Haynes                                                                 */
/*                                                                                                  */
/*  Purpose:            Compiles data from external sources for the KPIF EM OE23 Targeting Model.   */
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
	%let input_files = ##MASKED##;
	libname input "&input_files";

	* Output;
	%let output_files = ##MASKED##;
	libname output "&output_files";


/* -------------------------------------------------------------------------------------------------*/
/*  Market Size                                                                                     */
/* -------------------------------------------------------------------------------------------------*/

	proc import
		datafile="&input_files\Market Size Flat File - 1-7-22.xlsx"
		out=Market_Size
		dbms=xlsx replace;
	run;

	data Market_Size;
		set Market_Size;

		where Year in ('2016','2017','2018','2019','2020','2021','2022','2023','2024'); * this year, 1 year ago, 5 years ago, 1 year ahead;

		Year_num = input(Year,8.);
		Year_num = Year_num+1;
		drop Year;
		rename Year_num = Year;

		COUNTYFIPS = strip(put('FIPS Code'n,8.));
		if length(COUNTYFIPS)=4 then COUNTYFIPS = cats('0',put('FIPS Code'n,8.));
		if 'FIPS Code'n = . then delete;

		if state = 'California' then state = 'CA';
			else if state = 'Washington' then state = 'WA';
			else if state = 'Oregon' then state = 'OR';
			else if state = 'Hawaii' then state = 'HI';
			else if state = 'Georgia' then state = 'GA';
			else if state = 'Colorado' then state = 'CO';
			else if state = 'Maryland' then state = 'MD';
			else if state = 'Virginia' then state = 'VA';
			else if state = 'Distric of Columbia' then state = 'DC';

		drop 'FIPS Code'n;

	run;

		* Use lookup to update raw address data;
		/* Use COUNTYFIPS to fill in missing county name and state code */
		proc sql; *68% of those missing county name and state can have data populated using COUNTYFIPS;
		select distinct
			count(distinct case when CNTY_NM = '' and ST_CD = '' then AGLTY_INDIV_ID end)/count(distinct AGLTY_INDIV_ID) as Pct_Missing_Cnty_Nm format percent7.2
		,	count(distinct case when (CNTY_NM = '' or ST_CD = '') and COUNTYFIPS ne '' then AGLTY_INDIV_ID end)/count(distinct case when CNTY_NM = '' and ST_CD = '' then AGLTY_INDIV_ID end) as Pct_Have_Fips_Cnty_Miss format percent7.2
		from output.t2_address;
		quit;
		proc sql;
		create table output.Lookup_COUNTYFIPS as
		select distinct
			State as ST_CD
		,	upcase(County) as CNTY_NM
		,	COUNTYFIPS
		from Market_Size 
		order by State, County;
		quit;
		proc sort data=output.Lookup_COUNTYFIPS; by COUNTYFIPS; run;
		proc sort data=output.t2_address; by COUNTYFIPS; run;
		data output.t2_address;
			merge output.t2_address(in=a)
				  output.Lookup_COUNTYFIPS(in=b rename=(ST_CD=ST_CD_LOOKUP 
														CNTY_NM=CNTY_NM_LOOKUP));
			by COUNTYFIPS;

			if ST_CD = '' and CNTY_NM = ''
				and COUNTYFIPS ne '' then do;
				ST_CD = ST_CD_LOOKUP;
				CNTY_NM = CNTY_NM_LOOKUP;
				end;
			
			if a;
		run;
		proc sql; *30k individual's county and st cd were populated. 2.4% are still missing county name and state.;
		select distinct
			count(distinct case when CNTY_NM = '' and ST_CD = '' and COUNTYFIPS ne '' then AGLTY_INDIV_ID end) as Cnt_Miss_Cnty_Before
		,	count(distinct case when CNTY_NM = '' and ST_CD = '' then AGLTY_INDIV_ID end)/count(distinct AGLTY_INDIV_ID) as Pct_Missing_Cnty_Nm format percent7.2
		from output.t2_address;
		select distinct
			count(distinct case when CNTY_NM = '' and ST_CD = '' and COUNTYFIPS ne '' then AGLTY_INDIV_ID end) as Cnt_Miss_Cnty_After
		,	count(distinct case when CNTY_NM = '' and ST_CD = '' then AGLTY_INDIV_ID end)/count(distinct AGLTY_INDIV_ID) as Pct_Missing_Cnty_Nm format percent7.2
		from look;
		quit;
	
	proc sql;
	create table Market_Size as
	select distinct
		COUNTYFIPS
	,	Year
	,	'Major Segment'n as Major_Segment
	,	sum('Covered Lives'n) as Covered_Lives
	from Market_Size
	group by 
		COUNTYFIPS
	,	Year
	,	'Major Segment'n
	order by 
		COUNTYFIPS;
	quit;

	proc sql;
	create table Market_Size as
	select distinct
		x.COUNTYFIPS
	,	x.Year
	,	x.Major_Segment
	,	x.Covered_Lives
	,	y.Covered_Lives as Population
	from Market_Size x
	left join Market_Size y
		on x.COUNTYFIPS=y.COUNTYFIPS
		and x.Year=y.Year
		and y.Major_Segment='Population';
	quit;

	proc sql;
	create table Market_Size_Rollup as
	select distinct
		x.COUNTYFIPS
	,	x.Year
	,	sum(case when x.Major_Segment = 'Individual' then x.Covered_Lives else 0 end)/sum(Population) as Market_Share_Ind
	,	sum(case when x.Major_Segment = 'Large Group' then x.Covered_Lives else 0 end)/sum(Population) as Market_Share_B2B
	,	sum(case when x.Major_Segment = 'Small Group' then x.Covered_Lives else 0 end)/sum(Population) as Market_Share_SBU
	,	sum(case when x.Major_Segment = 'Medicaid' then x.Covered_Lives else 0 end)/sum(Population) as Market_Share_Medi
	,	sum(case when x.Major_Segment = 'Medicare' then x.Covered_Lives else 0 end)/sum(Population) as Market_Share_MA
	,	sum(case when x.Major_Segment ne 'Uninsured' then x.Covered_Lives else 0 end)/sum(Population) as Market_Share_KPTot
	,	sum(case when x.Major_Segment = 'Uninsured' then x.Covered_Lives else 0 end)/sum(Population) as Market_Share_Unins
	from Market_Size x
	group by 
		x.COUNTYFIPS
	,	x.Year;
	quit;

	proc sql;
	create table Market_Size_Final as
	select distinct
		x.COUNTYFIPS
	,	x.Year as OE_Season
	,	x.Market_Share_Ind*100 as Market_Share_Ind
	,	x.Market_Share_B2B*100 as Market_Share_B2B
	,	x.Market_Share_SBU*100 as Market_Share_SBU
	,	x.Market_Share_Medi*100 as Market_Share_Medi
	,	x.Market_Share_MA*100 as Market_Share_MA
	,	x.Market_Share_KPTot*100 as Market_Share_KPTot
	,	x.Market_Share_Unins*100 as Market_Share_Unins

	/* YoY */
	,	(y.Market_Share_Ind/x.Market_Share_Ind)-1 as Market_Share_Ind_YOYchg
	,	(y.Market_Share_B2B/x.Market_Share_B2B)-1 as Market_Share_B2B_YOYchg
	,	(y.Market_Share_SBU/x.Market_Share_SBU)-1 as Market_Share_SBU_YOYchg
	,	(y.Market_Share_Medi/x.Market_Share_Medi)-1 as Market_Share_Medi_YOYchg
	,	(y.Market_Share_MA/x.Market_Share_MA)-1 as Market_Share_MA_YOYchg
	,	(y.Market_Share_KPTot/x.Market_Share_KPTot)-1 as Market_Share_KPTot_YOYchg
	,	(y.Market_Share_Unins/x.Market_Share_Unins)-1 as Market_Share_Unins_YOYchg

	/* 3 years ago */
	,	(z.Market_Share_Ind/x.Market_Share_Ind)-1 as Market_Share_Ind_5YRchg
	,	(z.Market_Share_B2B/x.Market_Share_B2B)-1 as Market_Share_B2B_5YRchg
	,	(z.Market_Share_SBU/x.Market_Share_SBU)-1 as Market_Share_SBU_5YRchg
	,	(z.Market_Share_Medi/x.Market_Share_Medi)-1 as Market_Share_Medi_5YRchg
	,	(z.Market_Share_MA/x.Market_Share_MA)-1 as Market_Share_MA_5YRchg
	,	(z.Market_Share_KPTot/x.Market_Share_KPTot)-1 as Market_Share_KPTot_5YRchg
	,	(z.Market_Share_Unins/x.Market_Share_Unins)-1 as Market_Share_Unins_5YRchg

	/* 1 year forecast */
	,	(zz.Market_Share_Ind/x.Market_Share_Ind)-1 as Market_Share_Ind_FYchg
	,	(zz.Market_Share_B2B/x.Market_Share_B2B)-1 as Market_Share_B2B_FYchg
	,	(zz.Market_Share_SBU/x.Market_Share_SBU)-1 as Market_Share_SBU_FYchg
	,	(zz.Market_Share_Medi/x.Market_Share_Medi)-1 as Market_Share_Medi_FYchg
	,	(zz.Market_Share_MA/x.Market_Share_MA)-1 as Market_Share_MA_FYchg
	,	(zz.Market_Share_KPTot/x.Market_Share_KPTot)-1 as Market_Share_KPTot_FYchg
	,	(zz.Market_Share_Unins/x.Market_Share_Unins)-1 as Market_Share_Unins_FYchg
	from Market_Size_Rollup x
	left join Market_Size_Rollup y
		on x.COUNTYFIPS=y.COUNTYFIPS
		and x.Year-y.Year=1 /* 1 year earlier */
	left join Market_Size_Rollup z
		on x.COUNTYFIPS=z.COUNTYFIPS
		and x.Year-z.Year=3 /* 3 years earlier */
	left join Market_Size_Rollup zz
		on x.COUNTYFIPS=zz.COUNTYFIPS
		and x.Year-zz.Year=-1 /* 1 year forecast */
	where x.year in (2020,2021,2022)
	order by 
		x.COUNTYFIPS
	,	x.Year;
	quit;

	* Export;
	proc export 
		data=Market_Size_Final
		outfile="&output_files/T7_Market_Share_by_County.csv"
		dbms=CSV replace;
	run;

/* -------------------------------------------------------------------------------------------------*/
/*  Rate Position by Service Area                                                                   */
/* -------------------------------------------------------------------------------------------------*/

	* need a lookup for each year;

	proc import
		datafile="&input_files\Rate Position by Service Area 2014_2022.xlsx"
		out=Rates_2014_2022
		dbms=xlsx replace;
		sheet="Overall RP Flat File";
	run;
	proc import
		datafile="&input_files\Rate Position by Service Area 2014_2022.xlsx"
		out=lookup_Area
		dbms=xlsx replace;
		sheet="Rate Area";
	run;
	proc import
		datafile="&input_files\Rate Position by Service Area _Lookup for LA County.xlsx"
		out=lookup_LAcounty
		dbms=xlsx replace;
	run;

	data Rates_2014_2022;
		set Rates_2014_2022;

		rename 'Lowest RP'n = RP_Lowest
				'Lowest Relevant RP'n = RP_LowestRel
				'Average RP'n = RP_Avg
				'Average Relevant RP'n = RP_AvgRel
				'Weighted Average RP'n = RP_WeightedAvg
				'Lowest Increase'n = RP_LowestIncr
				'Average Increase'n = RP_AvgIncr;

		where 'Rating Area ID'n ne 'Overall'
			and Year in (2019,2020,2021,2022); *Worried to go back further since areas may have changes;

		format Exchange $7.;
		if 'On/Off Exchange'n = 'On' then Exchange = 'ONHIX_';
			else if 'On/Off Exchange'n = 'Off' then Exchange = 'OFFHIX_';

		if 'Metal Tier'n = 'Bronze' then Metal = 'BRZ';
			else if 'Metal Tier'n = 'Silver' then Metal = 'SLV';
			else if 'Metal Tier'n = 'Gold' then Metal = 'GOL';
			else if 'Metal Tier'n = 'Platinum' then Metal = 'PLA';
			else if 'Metal Tier'n = 'Overall' then Metal = 'ALL';
			else if 'Metal Tier'n = 'Catastrophic' then Metal = 'CAT';

		drop ID 'Carrier-Network'n 'Short Carrier'n 'Metal Tier'n 'On/Off Exchange'n Network 'CY Rates Analysis Status'n;

	run;

	/* transpose by metal tier */
	proc sql; create table Rates_2014_2022 as select distinct * from Rates_2014_2022; quit; *dupes;
	proc sort data=rates_2014_2022; by Year 'Rating Area ID'n Region Exchange Metal; run;
	proc transpose 
		data=rates_2014_2022
		out=rates_Lowest(drop=_LABEL_ _NAME_)
		prefix=RP_Lowest_;
		by Year 'Rating Area ID'n Region;
		id Exchange Metal;
		var RP_Lowest;
	run;
	proc transpose 
		data=rates_2014_2022
		out=rates_LowestRel(drop=_LABEL_ _NAME_)
		prefix=RP_LowestRel_;
		by Year 'Rating Area ID'n Region;
		id Exchange Metal;
		var RP_LowestRel;
	run;
	proc transpose 
		data=rates_2014_2022
		out=rates_Avg(drop=_LABEL_ _NAME_)
		prefix=RP_Avg_;
		by Year 'Rating Area ID'n Region;
		id Exchange Metal;
		var RP_Avg;
	run;
	proc transpose 
		data=rates_2014_2022
		out=rates_AvgRel(drop=_LABEL_ _NAME_)
		prefix=RP_AvgRel_;
		by Year 'Rating Area ID'n Region;
		id Exchange Metal;
		var RP_AvgRel;
	run;
	proc transpose 
		data=rates_2014_2022
		out=rates_WeightedAvg(drop=_LABEL_ _NAME_)
		prefix=RP_WeightedAvg_;
		by Year 'Rating Area ID'n Region;
		id Exchange Metal;
		var RP_WeightedAvg;
	run;
	proc transpose 
		data=rates_2014_2022
		out=rates_LowestIncr(drop=_LABEL_ _NAME_)
		prefix=RP_LowestIncr_;
		by Year 'Rating Area ID'n Region;
		id Exchange Metal;
		var RP_LowestIncr;
	run;
	proc transpose 
		data=rates_2014_2022
		out=rates_AvgIncr(drop=_LABEL_ _NAME_)
		prefix=RP_AvgIncr_;
		by Year 'Rating Area ID'n Region;
		id Exchange Metal;
		var RP_AvgIncr;
	run;
	data rates_transpose;
		merge rates_Lowest
			  rates_LowestRel
			  rates_Avg
			  rates_AvgRel
			  rates_WeightedAvg
			  rates_LowestIncr
			  rates_AvgIncr;
		by Year 'Rating Area ID'n Region;
	run;

	* Rating Area --> County and Zip;
	proc sort data=rates_transpose; by 'Rating Area ID'n Region; run;
	proc sort data=lookup_Area; by 'Rating Area'n Jurisdiction; run;

	data Rates_2014_2022;
		merge rates_transpose(in=a)
			  lookup_Area(in=b drop=State rename=('Rating Area'n='Rating Area ID'n 
													Jurisdiction = Region));
		by 'Rating Area ID'n Region;
		rename 'Rating Area ID'n = Rate_Area
				County = CNTY_NM;
		'County'n = upcase('County'n);
		if 'County'n = '' then 'County'n = 'LOS ANGELES';
		if Region in ('NCAL','SCAL') then Region_Join = 'CA';
			else if Region in ('MD','VA','DC') then Region_Join = 'MR';
			else if Region in ('WA','KPWA') then Region_Join = 'WA';
			else Region_Join = Region;
		if a;
	run;

	* add zip;

	data lookup_LAcounty;
		set lookup_LAcounty;
		where Area in (15,16);
		rename County = CNTY_NM;
		if Area=15 then Rate_Area = 'Area 15';
			else if Area=16 then Rate_Area = 'Area 16';
		ZIP_CD = input(ZIP,8.);
		County = upcase(County);
		drop A Area 'FIPS COUNTY CODE'n 'Zip Code Split Across Counties'n G Zip;
	run;

	proc sql;
	create table Rate_Area_All as
	select distinct
		x.Year as OE_Season /* join key */
	,	x.Region /* join key */
	,	x.CNTY_NM /* join key */
	,	y.ZIP_CD /* join key */
	,	RP_Lowest_OFFHIX_ALL
	,	RP_Lowest_OFFHIX_BRZ
	,	RP_Lowest_OFFHIX_CAT
	,	RP_Lowest_OFFHIX_GOL
	,	RP_Lowest_OFFHIX_SLV
	,	RP_Lowest_OFFHIX_PLA
	,	RP_Lowest_ONHIX_ALL
	,	RP_Lowest_ONHIX_BRZ
	,	RP_Lowest_ONHIX_CAT
	,	RP_Lowest_ONHIX_GOL
	,	RP_Lowest_ONHIX_SLV
	,	RP_Lowest_ONHIX_PLA
	,	RP_LowestRel_OFFHIX_ALL
	,	RP_LowestRel_OFFHIX_BRZ
	,	RP_LowestRel_OFFHIX_CAT
	,	RP_LowestRel_OFFHIX_GOL
	,	RP_LowestRel_OFFHIX_SLV
	,	RP_LowestRel_OFFHIX_PLA
	,	RP_LowestRel_ONHIX_ALL
	,	RP_LowestRel_ONHIX_BRZ
	,	RP_LowestRel_ONHIX_CAT
	,	RP_LowestRel_ONHIX_GOL
	,	RP_LowestRel_ONHIX_SLV
	,	RP_LowestRel_ONHIX_PLA
	,	RP_Avg_OFFHIX_ALL
	,	RP_Avg_OFFHIX_BRZ
	,	RP_Avg_OFFHIX_CAT
	,	RP_Avg_OFFHIX_GOL
	,	RP_Avg_OFFHIX_SLV
	,	RP_Avg_OFFHIX_PLA
	,	RP_Avg_ONHIX_ALL
	,	RP_Avg_ONHIX_BRZ
	,	RP_Avg_ONHIX_CAT
	,	RP_Avg_ONHIX_GOL
	,	RP_Avg_ONHIX_SLV
	,	RP_Avg_ONHIX_PLA
	,	RP_AvgRel_OFFHIX_ALL
	,	RP_AvgRel_OFFHIX_BRZ
	,	RP_AvgRel_OFFHIX_CAT
	,	RP_AvgRel_OFFHIX_GOL
	,	RP_AvgRel_OFFHIX_SLV
	,	RP_AvgRel_OFFHIX_PLA
	,	RP_AvgRel_ONHIX_ALL
	,	RP_AvgRel_ONHIX_BRZ
	,	RP_AvgRel_ONHIX_CAT
	,	RP_AvgRel_ONHIX_GOL
	,	RP_AvgRel_ONHIX_SLV
	,	RP_AvgRel_ONHIX_PLA
	,	RP_WeightedAvg_OFFHIX_ALL
	,	RP_WeightedAvg_OFFHIX_BRZ
	,	RP_WeightedAvg_OFFHIX_CAT
	,	RP_WeightedAvg_OFFHIX_GOL
	,	RP_WeightedAvg_OFFHIX_SLV
	,	RP_WeightedAvg_OFFHIX_PLA
	,	RP_WeightedAvg_ONHIX_ALL
	,	RP_WeightedAvg_ONHIX_BRZ
	,	RP_WeightedAvg_ONHIX_CAT
	,	RP_WeightedAvg_ONHIX_GOL
	,	RP_WeightedAvg_ONHIX_SLV
	,	RP_WeightedAvg_ONHIX_PLA
	,	RP_LowestIncr_OFFHIX_ALL
	,	RP_LowestIncr_OFFHIX_BRZ
	,	RP_LowestIncr_OFFHIX_CAT
	,	RP_LowestIncr_OFFHIX_GOL
	,	RP_LowestIncr_OFFHIX_SLV
	,	RP_LowestIncr_OFFHIX_PLA
	,	RP_LowestIncr_ONHIX_ALL
	,	RP_LowestIncr_ONHIX_BRZ
	,	RP_LowestIncr_ONHIX_CAT
	,	RP_LowestIncr_ONHIX_GOL
	,	RP_LowestIncr_ONHIX_SLV
	,	RP_LowestIncr_ONHIX_PLA
	,	RP_AvgIncr_OFFHIX_ALL
	,	RP_AvgIncr_OFFHIX_BRZ
	,	RP_AvgIncr_OFFHIX_CAT
	,	RP_AvgIncr_OFFHIX_GOL
	,	RP_AvgIncr_OFFHIX_SLV
	,	RP_AvgIncr_OFFHIX_PLA
	,	RP_AvgIncr_ONHIX_ALL
	,	RP_AvgIncr_ONHIX_BRZ
	,	RP_AvgIncr_ONHIX_CAT
	,	RP_AvgIncr_ONHIX_GOL
	,	RP_AvgIncr_ONHIX_SLV
	,	RP_AvgIncr_ONHIX_PLA

	from Rates_2014_2022 x
	left join lookup_LAcounty y
		on x.Rate_Area=y.Rate_Area
		and x.CNTY_NM=y.CNTY_NM
	where year in (2022,2021,2020,2019);

	quit;

	proc sql;
	create table Rate_Area_Final as
	select distinct
		x.*
	,	(x.RP_Lowest_ONHIX_SLV/y.RP_Lowest_ONHIX_SLV)-1 as RP_Lowest_ONHIX_SLV_YoY
	,	(x.RP_LowestRel_ONHIX_SLV/y.RP_LowestRel_ONHIX_SLV)-1 as RP_LowestRel_ONHIX_SLV_YoY
	,	(x.RP_Avg_ONHIX_SLV/y.RP_Avg_ONHIX_SLV)-1 as RP_Avg_ONHIX_SLV_YoY
	,	(x.RP_AvgRel_ONHIX_SLV/y.RP_AvgRel_ONHIX_SLV)-1 as RP_AvgRel_ONHIX_SLV_YoY
	,	(x.RP_WeightedAvg_ONHIX_SLV/y.RP_WeightedAvg_ONHIX_SLV)-1 as RP_WeightedAvg_ONHIX_SLV_YoY
	,	(x.RP_LowestIncr_ONHIX_SLV/y.RP_LowestIncr_ONHIX_SLV)-1 as RP_LowestIncr_ONHIX_SLV_YoY
	,	(x.RP_AvgIncr_ONHIX_SLV/y.RP_AvgIncr_ONHIX_SLV)-1 as RP_AvgIncr_ONHIX_SLV_YoY
	from Rate_Area_All x
	left join Rate_Area_All y
		on x.Region=y.Region
		and x.CNTY_NM=y.CNTY_NM
		and x.ZIP_CD=y.ZIP_CD
		and x.OE_Season-y.OE_Season=1 /* 1 year prior */
	where x.OE_Season in (2022,2021,2020);
	quit;

	* Export;
	proc export 
		data=Rate_Area_All
		outfile="&output_files/T7_Rate_Position_by_County.csv"
		dbms=CSV replace;
	run;


/* -------------------------------------------------------------------------------------------------*/
/*  COVID Cases & Deaths by County                                                                  */
/* -------------------------------------------------------------------------------------------------*/

	proc import
		datafile="&input_files/COVID Cases and Deaths 2020-2022.csv"
		out=COVID
		dbms=csv replace;
		guessingrows=5000;
	run;

	data COVID;
		set COVID;

		where state in ('California','Oregon','Washington',
						'Georgia','Hawaii','Colorado','Maryland',
						'Virginia','District of Columbia');

		COUNTYFIPS = strip(put(fips,8.));
		if length(COUNTYFIPS)=4 then COUNTYFIPS = cats('0',put(fips,8.));
		if fips = . then delete;

		if state = 'California' then state = 'CA';
			else if state = 'Washington' then state = 'WA';
			else if state = 'Oregon' then state = 'OR';
			else if state = 'Hawaii' then state = 'HI';
			else if state = 'Georgia' then state = 'GA';
			else if state = 'Colorado' then state = 'CO';
			else if state = 'Maryland' then state = 'MD';
			else if state = 'Virginia' then state = 'VA';
			else if state = 'Distric of Columbia' then state = 'DC';

		County = upcase(County);
	
		drop fips var1;
	run;
	proc sort data=COVID; by COUNTYFIPS Date; run;

	proc freq data=covid; tables date; run;
	proc sql;
	create table COVID_Final as
	select distinct
		x.COUNTYFIPS
	,	x.County
	,	x.State
	,	case when x.Date = "01NOV2020"d then 2021
		     when x.Date = "01NOV2021"d then 2022
			 end as OE_Season
	,	(x.cases/mo1.cases)-1 as Cases_OE1_vs_1mo_ago
	,	(x.cases/mo3.cases)-1 as Cases_OE1_vs_3mo_ago
	,	(x.cases/mo6.cases)-1 as Cases_OE1_vs_6mo_ago
	,	(x.deaths/mo1.deaths)-1 as Deaths_OE1_vs_1mo_ago
	,	(x.deaths/mo3.deaths)-1 as Deaths_OE1_vs_3mo_ago
	,	(x.deaths/mo6.deaths)-1 as Deaths_OE1_vs_6mo_ago
	from COVID x
	left join COVID mo1
		on x.date-mo1.date=7*4
		and x.COUNTYFIPS=mo1.COUNTYFIPS
	left join COVID mo3
		on x.date-mo3.date=7*4*3
		and x.COUNTYFIPS=mo3.COUNTYFIPS
	left join COVID mo6
		on x.date-mo6.date=7*4*6
		and x.COUNTYFIPS=mo6.COUNTYFIPS
	where x.Date in ("01NOV2020"d,"01NOV2021"d);
	quit;
	proc sql;
	create table COVID_Final2 as
	select distinct
		x.COUNTYFIPS
	,	x.County
	,	x.State
	,	case when x.Date = "01DEC2020"d then 2021
		     when x.Date = "01DEC2021"d then 2022
			 end as OE_Season
	,	(x.cases/mo1.cases)-1 as Cases_OE2_vs_1mo_ago
	,	(x.deaths/mo1.deaths)-1 as Deaths_OE2_vs_1mo_ago
	from COVID x
	left join COVID mo1
		on x.date-mo1.date=7*4
		and x.COUNTYFIPS=mo1.COUNTYFIPS
	where x.Date in ("01DEC2020"d,"01DEC2021"d);
	quit;

	data COVID_Final;
		merge COVID_Final(in=a)
				COVID_Final2(in=b);
		by COUNTYFIPS County State OE_Season;
	run;

	* Export;
	proc export 
		data=COVID_Final
		outfile="&output_files/T7_COVID_CasesDeaths_by_County.csv"
		dbms=CSV replace;
	run;

/* -------------------------------------------------------------------------------------------------*/
/*  Movers by County                                                                                */
/* -------------------------------------------------------------------------------------------------*/

	%macro import_movers(out_table,sheet);
		proc import
			datafile="&input_files/county-to-county-2015-2019-ins-outs-nets-gross.xlsx"
			out=&out_table.
			dbms=xlsx replace;
			sheet="&sheet.";
		run;
	%mend;
	%import_movers(movers_ca,California);
	%import_movers(movers_co,Colorado);
	%import_movers(movers_or,Oregon);
	%import_movers(movers_wa,Washington);
	%import_movers(movers_ga,Georgia);
	%import_movers(movers_hi,Hawaii);
	%import_movers(movers_md,Maryland);
	%import_movers(movers_va,Virginia);
	%import_movers(movers_dc,District of Columbia);

	data movers;
		set movers_ca
			movers_co
			movers_or
			movers_wa
			movers_ga
			movers_hi
			movers_md
			movers_va
			movers_dc;

		rename 'Flow from Geography B to Geograp'n = Movers_In
				'Counterflow from Geography A to'n = Movers_Out			
				;

		if 'State Name of Geography A'n = '' then delete;	

		if 'State Name of Geography A'n  = 'California' then State = 'CA';
			else if 'State Name of Geography A'n  = 'Colorado' then State = 'CO';
			else if 'State Name of Geography A'n  = 'Oregon' then State = 'OR';
			else if 'State Name of Geography A'n  = 'Washington' then State = 'WA';
			else if 'State Name of Geography A'n  = 'Georgia' then State = 'GA';
			else if 'State Name of Geography A'n  = 'Hawaii' then State = 'HI';
			else if 'State Name of Geography A'n  = 'Maryland' then State = 'MD';
			else if 'State Name of Geography A'n  = 'Virginia' then State = 'VA';
			else if 'State Name of Geography A'n  = 'District of Columbia' then State = 'DC';

			if State = '' then State = 'DC';

		County = upcase(tranwrd('County Name of Geography A'n,' County',''));

		COUNTYFIPS = catt(substr('State Code of Geography A'n,2,2),'fips county code of geography a'n);

		drop 'State Code of Geography A'n
			'fips county code of geography a'n
			'State/U.S. Island Area/Foreign R'n
			'fips county code of geography b'n 
			'State/U.S. Island Area/Foreign 1'n
			'County Name of Geography B'n
			'Flow from Geography B to Geogra1'n
			'Counterflow from Geography A to1'n
			'Gross Migration between Geograph'n
			'Gross Migration between Geograp1'n
			'Net Migration from Geography B 1'n
			'Net Migration from Geography B t'n
			'County Name of Geography A'n
			'State Name of Geography A'n 
			;
	run;

	proc sql;
	create table Movers_Final as
	select distinct
		COUNTYFIPS
	,	State
	,	County
	,	sum(Movers_In) as Movers_In
	,	sum(Movers_Out) as Movers_Out
	,	sum(Movers_In)-sum(Movers_Out) as Movers_Net
	from Movers
	group by 
		COUNTYFIPS
	,	State
	,	County
	order by 
		COUNTYFIPS
	,	State
	,	County;
	quit;

	* Export;
	proc export 
		data=Movers_Final
		outfile="&output_files/T7_Movers_by_County_2015_2019.csv"
		dbms=CSV replace;
	run;

/* -------------------------------------------------------------------------------------------------*/
/*  Students by County                                                                              */
/* -------------------------------------------------------------------------------------------------*/

	proc import
		datafile="&input_files/ACSDT5Y2018.B14004_data_with_overlays_2022-07-15T124522.csv"
		out=students_2018
		dbms=csv replace;
		guessingrows=5000;
	run;
	proc import
		datafile="&input_files/ACSDT5Y2019.B14004_data_with_overlays_2022-07-15T124522.csv"
		out=students_2019
		dbms=csv replace;
		guessingrows=5000;
	run;
	proc import
		datafile="&input_files/ACSDT5Y2020.B14004_data_with_overlays_2022-07-15T124522.csv"
		out=students_2020
		dbms=csv replace;
		guessingrows=5000;
	run;

	data students_2018; set students_2018; OE_Season = 2020; run;
	data students_2019; set students_2019; OE_Season = 2021; run;
	data students_2020; set students_2020; OE_Season = 2022; run;

	data students;
		set students_2018
			students_2019
			students_2020;

		where NAME ne 'Geographic Area Name';

		keep OE_Season
			 State
		     County
		     STUDENTS_PUB_PCT_POP
			 STUDENTS_PRI_PCT_POP
			 STUDENTS_PUB_PCT_ALL;

		State = strip(scan(NAME,2,','));
		if State = 'California' then State = 'CA';
			else if State = 'Oregon' then State = 'OR';
			else if State = 'Washington' then State = 'WA';
			else if State = 'Colorado' then State = 'CO';
			else if State = 'Hawaii' then State = 'HI';
			else if State = 'Georgia' then State = 'GA';
			else if State = 'Maryland' then State = 'MD';
			else if State = 'Virginia' then State = 'VA';
			else if State = 'District of Columbia' then State = 'DC';
		County = upcase(strip(tranwrd(scan(NAME,1,','),'County','')));
		Population = input(B14004_001E,$18.)*1;
		Enrolled_Public_Univ = input(B14004_003E,$17.)+input(B14004_019E,$72.);
		Enrolled_Private_Univ = input(B14004_008E,$71.)+input(B14004_024E,$73.);

		STUDENTS_PUB_PCT_POP = 100*(Enrolled_Public_Univ/Population);
		STUDENTS_PRI_PCT_POP = 100*(Enrolled_Private_Univ/Population);
		STUDENTS_PUB_PCT_ALL = 100*(Enrolled_Public_Univ/(Enrolled_Private_Univ+Enrolled_Public_Univ));

		if State in ('CA','OR','WA','CO','HI',
				'GA','MD','VA','DC')
				then output;

	run;

	* Export;
	proc export 
		data=students
		outfile="&output_files/T7_Students_by_County_2020_2022.csv"
		dbms=CSV replace;
	run;
 
/* -------------------------------------------------------------------------------------------------*/
/*  External Data by Agility ID                                                                     */
/* -------------------------------------------------------------------------------------------------*/

	* Data Set 1;
	proc import 
		datafile="&output_files/T7_Market_Share_by_County.csv"
		out=market_share
		dbms=CSV replace;
		guessingrows=1000;
	run;
	proc means data=market_share min max;
		var _ALL_;
	run;
	data market_share;
		set market_share;
		COUNTYFIPS2 = strip(put(COUNTYFIPS,8.));
		if length(COUNTYFIPS2)=4 then COUNTYFIPS2 = cats('0',put(COUNTYFIPS,8.));
		drop COUNTYFIPS;
		rename COUNTYFIPS2 = COUNTYFIPS;	
	run;
	
	proc sql;
	create table external_data_all as
	select distinct
		x.AGLTY_INDIV_ID
	,	x.OE_Season
	,	a.Region
	,	a.CNTY_NM
	,	a.COUNTYFIPS
	,	y.*
	from output.t9_rollup_treatment x
	left join output.t2_address a
		on x.AGLTY_INDIV_ID=a.AGLTY_INDIV_ID
	left join market_share y
		on a.COUNTYFIPS=y.COUNTYFIPS
		and x.OE_Season=y.OE_Season;
	quit;
	proc sql; select distinct count(*) from output.t9_rollup_treatment; quit; *match, no dupes;
	data external_data_all; set external_data_all; drop Region; run;

	proc sql; *2.6% of records are missing data;
	create table missing_by_county as
	select distinct
		CNTY_NM
	,	count(*) as Count_Rec
	,	sum(case when Market_Share_KPTot = . then 1 else 0 end) as Missing_Market_Sh
	,	sum(case when Market_Share_KPTot = . then 1 else 0 end)/count(*) as Pct_Missing_Market_Sh format percent7.2
	from external_data_all
	group by CNTY_NM
		union
	select distinct
		'Overall'
	,	count(*) as Count_Rec
	,	sum(case when Market_Share_KPTot = . then 1 else 0 end) as Missing_Market_Sh
	,	sum(case when Market_Share_KPTot = . then 1 else 0 end)/count(*) as Pct_Missing_Market_Sh format percent7.2
	from external_data_all
	order by Count_Rec desc;
	quit;

	* Data Set 2;
	proc import
		datafile="&output_files/T7_COVID_CasesDeaths_by_County.csv" 
		out=covid_cases
		dbms=CSV replace;
		guessingrows=1000;
	run;
	data covid_cases;
		set covid_cases;
		COUNTYFIPS2 = strip(put(COUNTYFIPS,8.));
		if length(COUNTYFIPS2)=4 then COUNTYFIPS2 = cats('0',put(COUNTYFIPS,8.));
		drop COUNTYFIPS;
		rename COUNTYFIPS2 = COUNTYFIPS;
	run;

	proc sql;
	create table external_data_all as
	select distinct
		x.*
	,	y.*
	from external_data_all x
	left join output.t2_address a
		on x.AGLTY_INDIV_ID=a.AGLTY_INDIV_ID
	left join covid_cases y
		on a.COUNTYFIPS=y.COUNTYFIPS
		and x.OE_Season=y.OE_Season;
	quit;
	data external_data_all; set external_data_all; drop COUNTYFIPS County State Mo_ago_1 Mo_ago_3 Mo_ago_6; run;
	data external_data_all; set external_data_all; if OE_Season = 2020 then do;
		Cases_OE1_vs_1mo_ago = 0;
		Cases_OE1_vs_3mo_ago = 0;
		Cases_OE1_vs_6mo_ago = 0;
		Deaths_OE1_vs_1mo_ago = 0;
		Deaths_OE1_vs_3mo_ago = 0;
		Deaths_OE1_vs_6mo_ago = 0;
		Cases_OE2_vs_1mo_ago = 0;
		Deaths_OE2_vs_1mo_ago = 0;
		end;
	run;

	* 1-2% of the data is missing;
	proc freq data=external_data_all;
		tables Deaths_OE2_vs_1mo_ago 
				Cases_OE1_vs_6mo_ago
				/ missing; 
	run;

	* Data Set 3;
	proc import 
		datafile="&output_files/T7_Movers_by_County_2015_2019.csv"
		out=movers
		dbms=CSV replace;
		guessingrows=1000;
	run;
	data movers;
		set movers;
		COUNTYFIPS2 = strip(put(COUNTYFIPS,8.));
		if length(COUNTYFIPS2)=4 then COUNTYFIPS2 = cats('0',put(COUNTYFIPS,8.));
		drop COUNTYFIPS;
		rename COUNTYFIPS2 = COUNTYFIPS;
	run;

	proc sql;
	create table external_data_all as
	select distinct
		x.*
	,	y.*
	from external_data_all x
	left join output.t2_address a
		on x.AGLTY_INDIV_ID=a.AGLTY_INDIV_ID
	left join movers y
		on a.COUNTYFIPS=y.COUNTYFIPS;
	quit;
	data external_data_all; set external_data_all; drop COUNTYFIPS County State; run;

	* 2-3% of the data is missing;
	proc freq data=external_data_all;
		tables movers_in 
				/ missing; 
	run;

	* Data Set 4;
	proc import 
		datafile="&output_files/T7_Students_by_County_2020_2022.csv"
		out=students
		dbms=CSV replace;
		guessingrows=1000;
	run;

	proc sql;
	create table external_data_all as
	select distinct
		x.*
	,	y.*
	from external_data_all x
	left join output.t2_address a
		on x.AGLTY_INDIV_ID=a.AGLTY_INDIV_ID
	left join students y
		on a.CNTY_NM=y.County
		and a.ST_CD=y.State
		and x.OE_Season=y.OE_Season;
	quit;
	data external_data_all; set external_data_all; drop County State; run;

	* 2-3% of the data is missing;
	proc freq data=external_data_all;
		tables students_pub_pct_pop 
				/ missing; 
	run;

	* Data Set 5;
	proc import 
		datafile="&output_files/T7_Rate_Position_by_County.csv"
		out=rate_position
		dbms=CSV replace;
		guessingrows=1000;
	run;

/*	data rate_position;*/
/*		set rate_position;*/
/*		if Region = 'KPWA' then State = 'WA';*/
/*			else if Region in ('NCAL','SCAL') then State = 'CA';*/
/*			else State = Region;*/
/*	run;*/
/*	proc export */
/*		data=rate_position*/
/*		outfile="&output_files/T7_Rate_Position_by_County.csv"*/
/*		dbms=CSV replace;*/
/*	run;*/

	proc sql;
	create table external_data_all as
	select distinct
		x.*
	,	y.*
	from external_data_all x
	left join output.t2_address a
		on x.AGLTY_INDIV_ID=a.AGLTY_INDIV_ID
	left join rate_position y
		on a.CNTY_NM=y.CNTY_NM
		and ((y.ZIP_CD ne . and a.ZIP_CD=y.ZIP_CD)
				or y.ZIP_CD = . and a.ST_CD=y.State)
		and x.OE_Season=y.OE_Season;
	quit;
	data external_data_all; set external_data_all; drop Region CNTY_NM ZIP_CD State; run;

	* 39% missing;
	proc freq data=external_data_all;
		tables rp_lowestrel_onhix_slv
				/ missing; 
	run;

	* Export;
	proc export 
		data=external_data_all
		outfile="&output_files/T12_Rollup_External.csv"
		dbms=CSV replace;
	run;


