/* Connected to 3778 */


/* -------------------------------------------------------------------------------------------------*/
/*  Promo IDs                                                                                       */
/* -------------------------------------------------------------------------------------------------*/

/* Medicare Direct Mail Prospect Targeting Model for SEP 2021 (##MASKED##) + AEP 2022 (##MASKED##) */
	SELECT DISTINCT
		Inhome_Date
	,	Region
	,	Segment
	,	Campaign
	,	Channel
	,	Promotionid AS PROMO_ID
	,	_00_Number
	,	Creative
	,	Offer
	,	Media_Detail
	,	Segments
	INTO WS_EHAYNES.dbo.MED_DM_22_Targeting_PromoIDs
	FROM [p4685].MARS.dbo.c_campaign_matrix
	WHERE Inhome_Date BETWEEN '2020-12-08' AND '2021-12-07'   
		AND Channel = 'DM'
		AND Campaign IN ('AEP','SEP')
		AND Media_Detail IN ('DM-EXP','DM-KBM')

/* -------------------------------------------------------------------------------------------------*/
/*  Promotion History                                                                               */
/* -------------------------------------------------------------------------------------------------*/
	
	SELECT /*DISTINCT*/
		AGLTY_INDIV_ID
	,	PROMO_ID
	INTO #temp
	FROM [p4685].[MARS].[dbo].[INDIVIDUAL_PROMOTION_HISTORY]
	WHERE PROMO_ID in (SELECT PROMO_ID FROM WS_EHAYNES.dbo.MED_DM_22_Targeting_PromoIDs); /* Change to name of your promo ID table */

	SELECT DISTINCT
		ph.*
	,	p.*
	INTO WS_EHAYNES.dbo.MED_DM_22_Targeting_AgilityIDs /* Change to name of your agility ID table */
	FROM #temp ph
	LEFT JOIN WS_EHAYNES.dbo.MED_DM_22_Targeting_PromoIDs p /* Change to name of your promo ID table */
		on ph.PROMO_ID=p.PROMO_ID

	DROP TABLE #temp

	CREATE INDEX AGLTY_INDIV_ID
	ON WS_EHAYNES.dbo.MED_DM_22_Targeting_AgilityIDs(AGLTY_INDIV_ID) /* Change to name of your agility ID table */

	SELECT DISTINCT
		MONTH(Inhome_date) AS MONTH_INHOME
	,	Campaign
	,	COUNT(AGLTY_INDIV_ID) AS LETTERS_MAILED
	FROM WS_EHAYNES.dbo.MED_DM_22_Targeting_AgilityIDs /* Change to name of your agility ID table */
	GROUP BY 
		MONTH(Inhome_date) 
	,	Campaign;

	SELECT DISTINCT
		COUNT(DISTINCT AGLTY_INDIV_ID) AS UNIQ_AGILITY_CNT
	FROM WS_EHAYNES.dbo.MED_DM_22_Targeting_AgilityIDs /* Change to name of your agility ID table */

/* -------------------------------------------------------------------------------------------------*/
/*  KBM                                                                                             */
/* -------------------------------------------------------------------------------------------------*/

	SELECT
		*
	INTO WS_EHAYNES.dbo.MED_DM_22_Targeting_KBM /* Change to name of your KBM table */
	FROM [p4685].[MARS].[dbo].[INDIVIDUAL_KBM_PROSPECT]
	WHERE AGLTY_INDIV_ID in (SELECT AGLTY_INDIV_ID FROM WS_EHAYNES.dbo.MED_DM_22_Targeting_AgilityIDs); /* Change to name of your agility ID table */

			/* Match % on KBM: 71.2% */
			SELECT DISTINCT
				COUNT(DISTINCT kbm.AGLTY_INDIV_ID)/
					COUNT(DISTINCT ph.AGLTY_INDIV_ID) AS PCT_MATCH_KBM
			FROM WS_EHAYNES.dbo.MED_DM_22_Targeting_AgilityIDs ph
			LEFT JOIN WS_EHAYNES.dbo.MED_DM_22_Targeting_KBM kbm
				on ph.AGLTY_INDIV_ID=kbm.AGLTY_INDIV_ID;

/* -------------------------------------------------------------------------------------------------*/
/*  Membership                                                                                      */
/* -------------------------------------------------------------------------------------------------*/

	SELECT 
		*
	INTO WS_EHAYNES.dbo.MED_DM_22_Targeting_Member /* Change to name of your Member table */
	FROM [p4685].[MARS].[dbo].[MEMBER]
	WHERE AGLTY_INDIV_ID IN (SELECT AGLTY_INDIV_ID FROM WS_EHAYNES.dbo.MED_DM_22_Targeting_AgilityIDs); /* Change to name of your agility ID table */

/* -------------------------------------------------------------------------------------------------*/
/*  Response                                                                                        */
/* -------------------------------------------------------------------------------------------------*/

	SELECT 
		*
	INTO WS_EHAYNES.dbo.MED_DM_22_Targeting_RespILR /* Change to name of your Response table */
	FROM [p4685].[MARS].[dbo].[INDIVIDUAL_LEAD_RESPONSE]
	WHERE AGLTY_INDIV_ID IN (SELECT AGLTY_INDIV_ID FROM WS_EHAYNES.dbo.MED_DM_22_Targeting_AgilityIDs); /* Change to name of your agility ID table */

	SELECT 
		*
	INTO WS_EHAYNES.dbo.MED_DM_22_Targeting_RespILMR /* Change to name of your Response table */
	FROM [p4685].[MARS].[dbo].[INDIVIDUAL_LEAD_MED_RESPONSE]
	WHERE AGLTY_INDIV_ID IN (SELECT AGLTY_INDIV_ID FROM WS_EHAYNES.dbo.MED_DM_22_Targeting_AgilityIDs); /* Change to name of your agility ID table */

/* -------------------------------------------------------------------------------------------------*/
/*  Geocode                                                                                         */
/* -------------------------------------------------------------------------------------------------*/

	SELECT DISTINCT
		ph.AGLTY_INDIV_ID
	,	adr.AGLTY_ADDR_ID
	INTO WS_EHAYNES.dbo.MED_DM_22_Targeting_Geo1 /* Change to name of your Geocode table */
	FROM WS_EHAYNES.dbo.MED_DM_22_Targeting_AgilityIDs ph /* Change to name of your agility ID table */
	INNER JOIN [p4685].[MARS].[dbo].[INDIVIDUAL_ADDRESS] adr
		ON ph.AGLTY_INDIV_ID=adr.AGLTY_INDIV_ID
		AND (adr.ADDR_TYPE_CD='PR' OR (adr.ADDR_TYPE_CD != 'PR' AND adr.PRIM_ADDR_IND = 'Y')

	SELECT
		AGLTY_INDIV_ID, AGLTY_ADDR_ID, CAST(AGLTY_ADDR_ID AS CHAR(32)) AS AGLTY_ADDR_ID_CHAR
	INTO WS_EHAYNES.dbo.MED_DM_22_Targeting_Geo1_Char
	FROM WS_EHAYNES.dbo.MED_DM_22_Targeting_Geo1

	/* Send to SAS, match Geocode, send back to SQL Server */

	/* Match % on geocode: 99.8% */
	SELECT DISTINCT
		COUNT(DISTINCT geo.AGLTY_INDIV_ID)/
			COUNT(DISTINCT ph.AGLTY_INDIV_ID) AS PCT_MATCH_GEO
	FROM WS_EHAYNES.dbo.MED_DM_22_Targeting_AgilityIDs ph
	LEFT JOIN WS_EHAYNES.dbo.MED_DM_22_Targeting_Geocode geo /* Change to name of your Geocode table */
		ON ph.AGLTY_INDIV_ID=geo.AGLTY_INDIV_ID

/* -------------------------------------------------------------------------------------------------*/
/*  Address                                                                                         */
/* -------------------------------------------------------------------------------------------------*/

		SELECT 
			ph.AGLTY_INDIV_ID
		,	CAST(adr.AGLTY_ADDR_ID AS VARCHAR(32)) AS AGLTY_ADDR_ID_VCHAR
		,	adr.ZIP_CD
		,	adr.ZIP4_CD
		INTO WS_EHAYNES.dbo.MED_DM_22_Targeting_Zip /* Change to name of your Address table */
		FROM [WS_EHAYNES].[dbo].[MED_DM_22_Targeting_Geo1_Char] ph /* Change to name of your agility ID table */
		INNER JOIN [p4685].[MARS].[dbo].[ADDRESS] adr
			ON ph.AGLTY_ADDR_ID=adr.AGLTY_ADDR_ID

		SELECT 
			ph.*
		,	zip.CNTY_NM
		,	zip.ST_CD
		,	zip.REGN_CD
		,	zip.SUB_REGN_CD
		,	zip.SVC_AREA_NM
		INTO WS_EHAYNES.dbo.MED_DM_22_Targeting_ZipLevelInfo /* Change to name of your Address table */
		FROM WS_EHAYNES.dbo.MED_DM_22_Targeting_Zip ph /* Change to name of your agility ID table */
		LEFT JOIN [p4685].[MARS].[dbo].[ZIP_LEVEL_INFO] zip
			ON ph.ZIP_CD=zip.ZIP_CD
			AND ph.ZIP4_CD BETWEEN zip.ZIP4_START_CD AND zip.ZIP4_END_CD
			AND zip.YR_NBR=2022

		DROP TABLE WS_EHAYNES.dbo.MED_DM_22_Targeting_Zip

		SELECT 
			ph.*
		,	adr.PRSN_IND
		,	adr.DWELL_TYPE_CD
		,	adr.HOSP_FCLTY_ID
		,	adr.HOSP_DIST_MSR
		,	adr.MOB_FCLTY_ID
		,	adr.MOB_DIST_MSR
		,	adr.CARR_RTE_CD
		INTO WS_EHAYNES.dbo.MED_DM_22_Targeting_Addr2 /* Change to name of your Address table */
		FROM [WS_EHAYNES].[dbo].[MED_DM_22_Targeting_Geo1_Char] ph /* Change to name of your agility ID table */
		LEFT JOIN [p4685].[MARS].[dbo].[ADDRESS] adr
			ON ph.AGLTY_ADDR_ID=adr.AGLTY_ADDR_ID

		SELECT
			zip.AGLTY_ADDR_ID_VCHAR
		,	geo.COUNTYFIPS
		INTO WS_EHAYNES.dbo.MED_DM_22_Targeting_FIPS
		FROM WS_EHAYNES.dbo.MED_DM_22_Targeting_ZipLevelInfo zip
		LEFT JOIN [p4685].MARS.dbo.GEOCODE_LKUP geo
			ON zip.AGLTY_ADDR_ID_VCHAR=geo.AGLTY_ADDR_ID_VCHAR

		SELECT
			zip.AGLTY_INDIV_ID
		,	zip.AGLTY_ADDR_ID_VCHAR
		,	zip.ZIP_CD
		,	zip.ZIP4_CD
		,	zip.CNTY_NM
		,	zip.ST_CD
		,	zip.REGN_CD
		,	zip.SUB_REGN_CD
		,	zip.SVC_AREA_NM
		,	adr.PRSN_IND
		,	adr.DWELL_TYPE_CD
		,	adr.HOSP_FCLTY_ID
		,	adr.HOSP_DIST_MSR
		,	adr.MOB_FCLTY_ID
		,	adr.MOB_DIST_MSR
		,	adr.CARR_RTE_CD
		INTO WS_EHAYNES.dbo.MED_DM_22_Targeting_Address
		FROM WS_EHAYNES.dbo.MED_DM_22_Targeting_ZipLevelInfo zip
		LEFT JOIN WS_EHAYNES.dbo.MED_DM_22_Targeting_Addr2 adr
			ON zip.AGLTY_ADDR_ID_VCHAR=adr.AGLTY_ADDR_ID_CHAR

		/* copy into SAS */
		/* remove dupes */
		/* add county fips */

/* -------------------------------------------------------------------------------------------------*/
/*  Sample                                                                                          */
/* -------------------------------------------------------------------------------------------------*/

	SELECT DISTINCT 
		ph.AGLTY_INDIV_ID 
	,	CASE WHEN geo.AGLTY_INDIV_ID IS NOT NULL THEN 1 ELSE 0 END AS GEO
	,	CASE WHEN aep.AGLTY_INDIV_ID IS NOT NULL THEN 1 ELSE 0 END AS AEP
	,	CASE WHEN sep.AGLTY_INDIV_ID IS NOT NULL THEN 1 ELSE 0 END AS SEP
	,	CASE WHEN resp.AGLTY_INDIV_ID IS NOT NULL THEN 1 ELSE 0 END AS RESP
	,	CASE WHEN mem.AGLTY_INDIV_ID IS NOT NULL THEN 1 ELSE 0 END AS MEM
	,	CASE WHEN kbm.AGLTY_INDIV_ID IS NOT NULL THEN 1 ELSE 0 END AS KBM
	INTO #unique_ids 
	FROM WS_EHAYNES.dbo.MED_DM_22_Targeting_AgilityIDs ph /* Change to name of your agility ID table */
	LEFT JOIN (SELECT DISTINCT AGLTY_INDIV_ID FROM WS_EHAYNES.dbo.MED_DM_22_Targeting_AgilityIDs WHERE Campaign = 'AEP') aep
		ON ph.AGLTY_INDIV_ID=aep.AGLTY_INDIV_ID
	LEFT JOIN (SELECT DISTINCT AGLTY_INDIV_ID FROM WS_EHAYNES.dbo.MED_DM_22_Targeting_AgilityIDs WHERE Campaign = 'SEP') sep
		ON ph.AGLTY_INDIV_ID=sep.AGLTY_INDIV_ID
	LEFT JOIN (SELECT DISTINCT AGLTY_INDIV_ID FROM WS_EHAYNES.dbo.MED_DM_22_Targeting_RespILMR 
					UNION
			   SELECT DISTINCT AGLTY_INDIV_ID FROM WS_EHAYNES.dbo.MED_DM_22_Targeting_RespILR) resp
		ON ph.AGLTY_INDIV_ID=resp.AGLTY_INDIV_ID
	LEFT JOIN (SELECT DISTINCT AGLTY_INDIV_ID FROM WS_EHAYNES.dbo.MED_DM_22_Targeting_Member) mem
		ON ph.AGLTY_INDIV_ID=mem.AGLTY_INDIV_ID
	LEFT JOIN (SELECT DISTINCT AGLTY_INDIV_ID FROM WS_EHAYNES.dbo.MED_DM_22_Targeting_Geocode WHERE GEOCODE != '') geo
		ON ph.AGLTY_INDIV_ID=geo.AGLTY_INDIV_ID
		LEFT JOIN (SELECT DISTINCT AGLTY_INDIV_ID FROM WS_EHAYNES.dbo.MED_DM_22_Targeting_KBM) kbm
		ON ph.AGLTY_INDIV_ID=kbm.AGLTY_INDIV_ID
	
	SELECT DISTINCT
		* 
	INTO WS_EHAYNES.dbo.MED_DM_22_Targeting_Sample
	FROM #unique_ids /* Change to name of your sample table */
	WHERE 0.1 >= CAST(CHECKSUM(NEWID(), AGLTY_INDIV_ID) & 0x7fffffff AS FLOAT) /* Returns 10% random sample */
	/ CAST (0x7fffffff AS INT)

/* -------------------------------------------------------------------------------------------------*/
/*  Tapestry - Sample                                                                               */
/* -------------------------------------------------------------------------------------------------*/

	SELECT DISTINCT
		s.*

		/*	2020 population metrics */
	,	tap1.TOTPOP_CY AS POP_TOTAL
	,	tap1.POP60_CY AS POP_AGE_60_64
	,	tap1.POP65_CY AS POP_AGE_65_69
	,	tap1.POP70_CY AS POP_AGE_70_74
	,	tap1.POP75_CY AS POP_AGE_75_79
	,	tap1.POP80_CY AS POP_AGE_80_84
	,	tap1.POP85_CY AS POP_AGE_85_up
	,	tap1.MALE60_CY AS POP_AGE_60_64_M
	,	tap1.MALE65_CY AS POP_AGE_65_69_M
	,	tap1.FEM60_CY AS POP_AGE_60_64_F
	,	tap1.FEM65_CY AS POP_AGE_65_69_F
	,	tap1.BABYBOOMCY AS POP_BOOMER_1946_1964
	,	tap1.OLDRGENSCY AS POP_SILENT_pre_1945
	,	tap1.TOTHH_CY AS TOTAL_NUM_HOUSEHOLDS
	,	tap1.AVGHHSZ_CY AS POP_AVG_HH_SIZE
	,	tap1.POPDENS_CY AS POP_PER_SQ_MILE
	,	tap1.SENIOR_CY AS POP_65_up
	,	tap1.SENRDEP_CY AS POP_65_up_DEP_RATIO
	,	tap5.NEVMARR_CY AS POP_NEVER_MARRIED
	,	tap5.MARRIED_CY AS POP_MARRIED
	,	tap5.WIDOWED_CY AS POP_WIDOWED
	,	tap5.DIVORCD_CY AS POP_DIVORCED
		/*	2025 forecast population metrics */
	,	tap7.POPGRWCYFY AS POP_CMPD_ANNUAL_GRWTH_RT
	,	tap7.POP60_FY AS POP_AGE_60_64_FY
	,	tap7.POP65_FY AS POP_AGE_65_69_FY
	,	tap7.POP70_FY AS POP_AGE_70_74_FY
	,	tap7.POP75_FY AS POP_AGE_75_79_FY
	,	tap7.POP80_FY AS POP_AGE_80_84_FY
	,	tap7.POP85_FY AS POP_AGE_85_up_FY
	,	tap7.MALE60_FY AS POP_AGE_60_64_M_FY
	,	tap7.MALE65_FY AS POP_AGE_65_69_M_FY
	,	tap7.FEM60_FY AS POP_AGE_60_64_F_FY
	,	tap7.FEM65_FY AS POP_AGE_65_69_F_FY
	,	tap7.BABYBOOMFY AS POP_BOOMER_1946_1964_FY
	,	tap7.OLDRGENSFY AS POP_SILENT_pre_1945_FY
	,	tap7.TOTHH_FY AS TOTAL_NUM_HOUSEHOLDS_FY
	,	tap7.AVGHHSZ_FY AS POP_AVG_HH_SIZE_FY
	,	tap7.POPDENS_FY AS POP_PER_SQ_MILE_FY
	,	tap7.SENIOR_FY AS POP_65_up_FY
	,	tap7.SENRDEP_FY AS POP_65_up_DEP_RATIO_FY

		/*	2020 housing metrics */
	,	tap1.GQPOP_CY AS POP_GROUP_LIVING
	,	tap1.TOTHU_CY AS TOTAL_HOUSING_UNITS
	,	tap1.OWNER_CY AS OWNER_OCCUPIED_UNITS
	,	tap1.RENTER_CY AS RENTER_OCCUPIED_UNITS
	,	tap6.MEDVAL_CY AS MEDIAN_HOME_VALUE
	,	tap1.HAI_CY AS HOUSING_AFFORDAB_INDEX
	,	tap1.INCMORT_CY AS PCT_OF_INCOME_MORTGAGE
		/*	2025 forecast housing metrics */
	,	tap7.GQPOP_FY AS POP_GROUP_LIVING_FY
	,	tap7.TOTHU_FY AS TOTAL_HOUSING_UNITS_FY
	,	tap7.OWNER_FY AS OWNER_OCCUPIED_UNITS_FY
	,	tap7.RENTER_FY AS RENTER_OCCUPIED_UNITS_FY
	,	tap11.MEDVAL_FY AS MEDIAN_HOME_VALUE_FY
	,	tap7.OWNGRWCYFY AS OWNER_OCCUPIED_GRWTH_RT

		/* 2020 diversity metrics */
	,	tap5.DIVINDX_CY AS DIVERSITY_INDEX
	,	tap3.MEDWAGE_CY AS MEDIAN_WHITE_AGE
	,	tap3.MEDWMAGECY AS MEDIAN_WHITE_MALE_AGE
	,	tap3.WHTM60_CY AS POP_AGE_60_64_M_WHITE
	,	tap3.WHTM65_CY AS POP_AGE_65_69_M_WHITE
	,	tap3.MEDWFAGECY AS MEDIAN_WHITE_FEMALE_AGE
	,	tap3.WHTF60_CY AS POP_AGE_60_64_F_WHITE
	,	tap3.WHTF65_CY AS POP_AGE_65_69_F_WHITE
	,	tap3.MEDBAGE_CY AS MEDIAN_BLACK_AGE
	,	tap3.MEDBMAGECY AS MEDIAN_BLACK_MALE_AGE
	,	tap3.MEDBFAGECY AS MEDIAN_BLACK_FEMALE_AGE
	,	tap3.MEDAAGE_CY AS MEDIAN_ASIAN_AGE
	,	tap3.MEDAMAGECY AS MEDIAN_ASIAN_MALE_AGE
	,	tap3.MEDAFAGECY AS MEDIAN_ASIAN_FEMALE_AGE
	,	tap4.MEDPAGE_CY AS MEDIAN_ISLANDER_AGE
	,	tap4.MEDPMAGECY AS MEDIAN_ISLANDER_MALE_AGE
	,	tap4.MEDPFAGECY AS MEDIAN_ISLANDER_FEMALE_AGE
	,	tap4.MEDHAGE_CY AS MEDIAN_HISP_AGE
	,	tap4.MEDHMAGECY AS MEDIAN_HISP_MALE_AGE
	,	tap4.MEDHFAGECY AS MEDIAN_HISP_FEMALE_AGE
	,	tap3.WHT60_CY AS POP_WHITE_60_64
	,	tap3.WHT65_CY AS POP_WHITE_65_69
	,	tap3.BLK60_CY AS POP_BLACK_60_64
	,	tap3.BLK65_CY AS POP_BLACK_65_69
	,	tap3.ASN60_CY AS POP_ASIAN_60_64
	,	tap3.ASN65_CY AS POP_ASIAN_65_69
	,	tap4.PIM60_CY AS POP_ISLANDER_60_64
	,	tap4.PIM65_CY AS POP_ISLANDER_65_69
	,	tap4.HSP60_CY AS POP_HISP_60_64
	,	tap4.HSP65_CY AS POP_HISP_65_69
	,	tap5.WHITE_CY AS POP_WHITE
	,	tap5.BLACK_CY AS POP_BLACK
	,	tap5.ASIAN_CY AS POP_ASIAN
	,	tap5.PACIFIC_CY AS POP_PACIFIC
	,	tap5.HISPPOP_CY AS POP_HISPANIC
		/* 2025 diversity metrics */
	,	tap11.DIVINDX_FY AS DIVERSITY_INDEX_FY
	,	tap9.MEDWAGE_FY AS MEDIAN_WHITE_AGE_FY
	,	tap9.MEDWMAGEFY AS MEDIAN_WHITE_MALE_AGE_FY
	,	tap9.WHTM60_FY AS POP_AGE_60_64_M_WHITE_FY
	,	tap9.WHTM65_FY AS POP_AGE_65_69_M_WHITE_FY
	,	tap9.MEDWFAGEFY AS MEDIAN_WHITE_FEMALE_AGE_FY
	,	tap9.WHTF60_FY AS POP_AGE_60_64_F_WHITE_FY
	,	tap9.WHTF65_FY AS POP_AGE_65_69_F_WHITE_FY
	,	tap9.MEDBAGE_FY AS MEDIAN_BLACK_AGE_FY
	,	tap9.MEDBMAGEFY AS MEDIAN_BLACK_MALE_AGE_FY
	,	tap9.MEDBFAGEFY AS MEDIAN_BLACK_FEMALE_AGE_FY
	,	tap9.MEDAAGE_FY AS MEDIAN_ASIAN_AGE_FY
	,	tap9.MEDAMAGEFY AS MEDIAN_ASIAN_MALE_AGE_FY
	,	tap9.MEDAFAGEFY AS MEDIAN_ASIAN_FEMALE_AGE_FY
	,	tap10.MEDPAGE_FY AS MEDIAN_ISLANDER_AGE_FY
	,	tap10.MEDPMAGEFY AS MEDIAN_ISLANDER_MALE_AGE_FY
	,	tap10.MEDPFAGEFY AS MEDIAN_ISLANDER_FEMALE_AGE_FY
	,	tap10.MEDHAGE_FY AS MEDIAN_HISP_AGE_FY
	,	tap10.MEDHMAGEFY AS MEDIAN_HISP_MALE_AGE_FY
	,	tap10.MEDHFAGEFY AS MEDIAN_HISP_FEMALE_AGE_FY
	,	tap9.WHT60_FY AS POP_WHITE_60_64_FY
	,	tap9.WHT65_FY AS POP_WHITE_65_69_FY
	,	tap9.BLK60_FY AS POP_BLACK_60_64_FY
	,	tap9.BLK65_FY AS POP_BLACK_65_69_FY
	,	tap9.ASN60_FY AS POP_ASIAN_60_64_FY
	,	tap9.ASN65_FY AS POP_ASIAN_65_69_FY
	,	tap10.PIM60_FY AS POP_ISLANDER_60_64_FY
	,	tap10.PIM65_FY AS POP_ISLANDER_65_69_FY
	,	tap10.HSP60_FY AS POP_HISP_60_64_FY
	,	tap10.HSP65_FY AS POP_HISP_65_69_FY
	,	tap11.WHITE_FY AS POP_WHITE_FY
	,	tap11.BLACK_FY AS POP_BLACK_FY
	,	tap11.ASIAN_FY AS POP_ASIAN_FY
	,	tap11.PACIFIC_FY AS POP_PACIFIC_FY
	,	tap11.HISPPOP_FY AS POP_HISPANIC_FY

		/* 2020 financial metrics */
	,	tap5.MEDHINC_CY AS MEDIAN_HH_INCOME
	,	tap5.PCI_CY AS PER_CAPITA_INCOME
	,	tap2.WLTHINDXCY AS WEALTH_INDEX
	,	tap5.HINC0_CY AS HH_INCOME_0k_15k
	,	tap5.HINC15_CY AS HH_INCOME_15_25k
	,	tap5.HINC25_CY AS HH_INCOME_25_35k
	,	tap5.HINC35_CY AS HH_INCOME_35_50k
	,	tap5.HINC50_CY AS HH_INCOME_50_75k
	,	tap5.HINC75_CY AS HH_INCOME_75_100k
	,	tap5.HINC100_CY AS HH_INCOME_100_150k
	,	tap5.HINC150_CY AS HH_INCOME_150_200k
	,	tap5.HINC200_CY AS HH_INCOME_200k
	,	tap5.MEDIA55_CY AS MEDIAN_HH_INCOME_AGE_55_64
	,	tap5.MEDIA55UCY AS MEDIAN_HH_INCOME_AGE_55up
	,	tap5.IA55UBASCY AS HOUSEHOLDS_INCOME_AGE_55up
	,	tap5.MEDIA65_CY AS MEDIAN_HH_INCOME_AGE_65_74
	,	tap5.MEDIA65UCY AS MEDIAN_HH_INCOME_AGE_65up
	,	tap5.IA65UBASCY AS HOUSEHOLDS_INCOME_AGE_65up
	,	tap5.MEDIA75_CY AS MEDIAN_HH_INCOME_AGE_75up
	,	tap5.IA75BASECY AS HOUSEHOLDS_INCOME_AGE_75up
	,	tap6.MEDDI_CY AS MEDIAN_DISPOSABLE_INCOME
	,	tap6.MEDDIA55CY AS MEDIAN_DISP_INCOME_AGE_55_64
	,	tap6.MEDDIA65CY AS MEDIAN_DISP_INCOME_AGE_65_74
	,	tap6.MEDDIA75CY AS MEDIAN_DISP_INCOME_AGE_75up
	,	tap6.MEDNW_CY AS MEDIAN_NET_WORTH
	,	tap6.MEDNWA55CY AS MEDIAN_NET_WORTH_55_64
	,	tap6.MEDNWA65CY AS MEDIAN_NET_WORTH_65_74
	,	tap6.MEDNWA75CY AS MEDIAN_NET_WORTH_75up
		/* 2025 financial metrics */
	,	tap11.MEDHINC_FY AS MEDIAN_HH_INCOME_FY
	,	tap7.MHIGRWCYFY AS MEDIAN_HH_INCOME_GRWTH_RT
	,	tap7.PCIGRWCYFY AS PER_CAPITA_INCOME_GRWTH_RT
	,	tap11.HINC0_FY AS HH_INCOME_0k_15k_FY
	,	tap11.HINC15_FY AS HH_INCOME_15_25k_FY
	,	tap11.HINC25_FY AS HH_INCOME_25_35k_FY
	,	tap11.HINC35_FY AS HH_INCOME_35_50k_FY
	,	tap11.HINC50_FY AS HH_INCOME_50_75k_FY
	,	tap11.HINC75_FY AS HH_INCOME_75_100k_FY
	,	tap11.HINC100_FY AS HH_INCOME_100_150k_FY
	,	tap11.HINC150_FY AS HH_INCOME_150_200k_FY
	,	tap11.HINC200_FY AS HH_INCOME_200k_FY
	,	tap11.MEDIA55_FY AS MEDIAN_HH_INCOME_AGE_55_64_FY
	,	tap11.MEDIA55UFY AS MEDIAN_HH_INCOME_AGE_55up_FY
	,	tap11.IA55UBASFY AS HOUSEHOLDS_INCOME_AGE_55up_FY
	,	tap11.MEDIA65_FY AS MEDIAN_HH_INCOME_AGE_65_74_FY
	,	tap11.MEDIA65UFY AS MEDIAN_HH_INCOME_AGE_65up_FY
	,	tap11.MEDIA75_FY AS MEDIAN_HH_INCOME_AGE_75up_FY
	,	tap11.IA75BASEFY AS HOUSEHOLDS_INCOME_AGE_75up_FY

		/*	2020 labor metrics */
	,	tap5.CIVLBFR_CY AS POP_IN_LABOR_FORCE
	,	tap5.EMP_CY AS POP_EMPLOYED
	,	tap5.UNEMP_CY AS POP_UNEMPLOYED
	,	tap5.UNEMPRT_CY AS UNEMPLOYMENT_RT
	,	tap5.CIVLF65_CY AS POP_65_up_IN_LABOR_FORCE
	,	tap5.EMPAGE65CY AS POP_65_up_EMPLOYED

		/*	2020 education metrics */
	,	tap5.NOHS_CY AS EDUC_NO_HS
	,	tap5.SOMEHS_CY AS EDUC_SOME_HS
	,	tap5.HSGRAD_CY AS EDUC_HS
	,	tap5.GED_CY AS EDUC_GED
	,	tap5.SMCOLL_CY AS EDUC_SOME_COLLEGE
	,	tap5.ASSCDEG_CY AS EDUC_ASSOCIATE_DEGREE
	,	tap5.BACHDEG_CY AS EDUC_BACHELOR_DEGREE
	,	tap5.GRADDEG_CY AS EDUC_GRAD_DEGREE

	,	taphh.TSEGNAME AS TAPESTRY_SEGMENT
	,	taphh.TSEGCODE AS TAPESTRY_SEGMENT_CD
	,	taphh.TLIFENAME AS TAPESTRY_LIFESTYLE
	,	taphh.TURBZNAME AS TAPESTRY_URBAN

	INTO WS_EHAYNES.dbo.MED_DM_22_Targeting_TapSample /* Change to name of your Tapestry Sample table */
	FROM WS_EHAYNES.dbo.MED_DM_22_Targeting_Sample s /* Change to name of your sample table */
	LEFT JOIN [ESRI_TAPESTRY].[dbo].[CFY20_01] tap1
		ON s.GEOCODE=tap1.GEOCODE
	LEFT JOIN [ESRI_TAPESTRY].[dbo].[CFY20_02] tap2
		ON s.GEOCODE=tap2.GEOCODE
	LEFT JOIN [ESRI_TAPESTRY].[dbo].[CFY20_03] tap3
		ON s.GEOCODE=tap3.GEOCODE
	LEFT JOIN [ESRI_TAPESTRY].[dbo].[CFY20_04] tap4
		ON s.GEOCODE=tap4.GEOCODE
	LEFT JOIN [ESRI_TAPESTRY].[dbo].[CFY20_05] tap5
		ON s.GEOCODE=tap5.GEOCODE
	LEFT JOIN [ESRI_TAPESTRY].[dbo].[CFY20_06] tap6
		ON s.GEOCODE=tap6.GEOCODE
	LEFT JOIN [ESRI_TAPESTRY].[dbo].[CFY20_07] tap7
		ON s.GEOCODE=tap7.GEOCODE
	LEFT JOIN [ESRI_TAPESTRY].[dbo].[CFY20_08] tap8
		ON s.GEOCODE=tap8.GEOCODE
	LEFT JOIN [ESRI_TAPESTRY].[dbo].[CFY20_09] tap9
		ON s.GEOCODE=tap9.GEOCODE
	LEFT JOIN [ESRI_TAPESTRY].[dbo].[CFY20_10] tap10
		ON s.GEOCODE=tap10.GEOCODE
	LEFT JOIN [ESRI_TAPESTRY].[dbo].[CFY20_11] tap11
		ON s.GEOCODE=tap11.GEOCODE
	LEFT JOIN [ESRI_TAPESTRY].[dbo].[TAP20_ADULT] tapad
		ON s.GEOCODE=tapad.GEOCODE
	LEFT JOIN [ESRI_TAPESTRY].[dbo].[TAP20_HH] taphh
		ON s.GEOCODE=taphh.GEOCODE

/* -------------------------------------------------------------------------------------------------*/
/*  Tenure                                                                                          */
/* -------------------------------------------------------------------------------------------------*/
SELECT COUNT(*) FROM WS_EHAYNES.dbo.MED_DM_22_Targeting_TenInpAEP 
--CREATE #INPUT
SELECT 
*
INTO #INPUT
FROM WS_EHAYNES.dbo.MED_DM_22_Targeting_TenInpAEP T1 
--FROM WS_EHAYNES.dbo.MED_DM_22_Targeting_TenInpSEP T1 

--TENURE CODE START
SELECT DISTINCT A.AGLTY_INDIV_ID, A.MBR_STAT_CD, A.ELGB_START_DT, 
	(SELECT CASE WHEN ELGB_END_DT = CONVERT(DATE, '4000-12-31') THEN SYSDATETIME() ELSE ELGB_END_DT END) AS ELGB_END_DT
	INTO #TEMP1
	FROM #INPUT A		
	
DELETE FROM #TEMP1 WHERE ELGB_START_DT = CONVERT(DATE,'1900-01-01') OR ELGB_END_DT = CONVERT(DATE,'1900-01-01')
DELETE FROM #TEMP1 WHERE ELGB_START_DT >= ELGB_END_DT
--
CREATE TABLE #TEMPDATES (AGLTY_INDIV_ID NVARCHAR(20), 
T01_START DATETIME, T01_END DATETIME, 
T02_START DATETIME, T02_END DATETIME, 
T03_START DATETIME, T03_END DATETIME,
T04_START DATETIME, T04_END DATETIME,
T05_START DATETIME, T05_END DATETIME,
T06_START DATETIME, T06_END DATETIME,
T07_START DATETIME, T07_END DATETIME,
T08_START DATETIME, T08_END DATETIME,
T09_START DATETIME, T09_END DATETIME,
T10_START DATETIME, T10_END DATETIME,
T11_START DATETIME, T11_END DATETIME,
T12_START DATETIME, T12_END DATETIME,
T13_START DATETIME, T13_END DATETIME,
T14_START DATETIME, T14_END DATETIME,
T15_START DATETIME, T15_END DATETIME,
T16_START DATETIME, T16_END DATETIME,
T17_START DATETIME, T17_END DATETIME,
T18_START DATETIME, T18_END DATETIME,
T19_START DATETIME, T19_END DATETIME,
T20_START DATETIME, T20_END DATETIME
)
	INSERT INTO #TEMPDATES (AGLTY_INDIV_ID)
	SELECT DISTINCT AGLTY_INDIV_ID FROM #TEMP1

	UPDATE #TEMPDATES SET T01_START = (SELECT MIN(ELGB_START_DT) FROM #TEMP1 T 
		WHERE #TEMPDATES.AGLTY_INDIV_ID = T.AGLTY_INDIV_ID)
	UPDATE #TEMPDATES SET T01_END = (SELECT MIN(ELGB_END_DT) FROM #TEMP1 T 
		WHERE #TEMPDATES.AGLTY_INDIV_ID = T.AGLTY_INDIV_ID)
	DELETE FROM #TEMP1 
		WHERE ELGB_START_DT IN (SELECT T01_START FROM #TEMPDATES 
		WHERE #TEMP1.AGLTY_INDIV_ID = #TEMPDATES.AGLTY_INDIV_ID)
	
	UPDATE #TEMPDATES SET T02_START = (SELECT MIN(ELGB_START_DT) FROM #TEMP1 T 
		WHERE #TEMPDATES.AGLTY_INDIV_ID = T.AGLTY_INDIV_ID)
	UPDATE #TEMPDATES SET T02_END = (SELECT MIN(ELGB_END_DT) FROM #TEMP1 T 
		WHERE #TEMPDATES.AGLTY_INDIV_ID = T.AGLTY_INDIV_ID)
	DELETE FROM #TEMP1 
		WHERE ELGB_START_DT IN (SELECT T02_START FROM #TEMPDATES 
		WHERE #TEMP1.AGLTY_INDIV_ID = #TEMPDATES.AGLTY_INDIV_ID)
	
	UPDATE #TEMPDATES SET T03_START = (SELECT MIN(ELGB_START_DT) FROM #TEMP1 T 
		WHERE #TEMPDATES.AGLTY_INDIV_ID = T.AGLTY_INDIV_ID)
	UPDATE #TEMPDATES SET T03_END = (SELECT MIN(ELGB_END_DT) FROM #TEMP1 T 
		WHERE #TEMPDATES.AGLTY_INDIV_ID = T.AGLTY_INDIV_ID)
	DELETE FROM #TEMP1 
		WHERE ELGB_START_DT IN (SELECT T03_START FROM #TEMPDATES 
		WHERE #TEMP1.AGLTY_INDIV_ID = #TEMPDATES.AGLTY_INDIV_ID)
	
	UPDATE #TEMPDATES SET T04_START = (SELECT MIN(ELGB_START_DT) FROM #TEMP1 T 
		WHERE #TEMPDATES.AGLTY_INDIV_ID = T.AGLTY_INDIV_ID)
	UPDATE #TEMPDATES SET T04_END = (SELECT MIN(ELGB_END_DT) FROM #TEMP1 T 
		WHERE #TEMPDATES.AGLTY_INDIV_ID = T.AGLTY_INDIV_ID)
	DELETE FROM #TEMP1 
		WHERE ELGB_START_DT IN (SELECT T04_START FROM #TEMPDATES 
		WHERE #TEMP1.AGLTY_INDIV_ID = #TEMPDATES.AGLTY_INDIV_ID)
		
	UPDATE #TEMPDATES SET T05_START = (SELECT MIN(ELGB_START_DT) FROM #TEMP1 T 
		WHERE #TEMPDATES.AGLTY_INDIV_ID = T.AGLTY_INDIV_ID)
	UPDATE #TEMPDATES SET T05_END = (SELECT MIN(ELGB_END_DT) FROM #TEMP1 T 
		WHERE #TEMPDATES.AGLTY_INDIV_ID = T.AGLTY_INDIV_ID)
	DELETE FROM #TEMP1 
		WHERE ELGB_START_DT IN (SELECT T05_START FROM #TEMPDATES 
		WHERE #TEMP1.AGLTY_INDIV_ID = #TEMPDATES.AGLTY_INDIV_ID)
		
	UPDATE #TEMPDATES SET T06_START = (SELECT MIN(ELGB_START_DT) FROM #TEMP1 T 
		WHERE #TEMPDATES.AGLTY_INDIV_ID = T.AGLTY_INDIV_ID)
	UPDATE #TEMPDATES SET T06_END = (SELECT MIN(ELGB_END_DT) FROM #TEMP1 T 
		WHERE #TEMPDATES.AGLTY_INDIV_ID = T.AGLTY_INDIV_ID)
	DELETE FROM #TEMP1 
		WHERE ELGB_START_DT IN (SELECT T06_START FROM #TEMPDATES 
		WHERE #TEMP1.AGLTY_INDIV_ID = #TEMPDATES.AGLTY_INDIV_ID)
		
	UPDATE #TEMPDATES SET T07_START = (SELECT MIN(ELGB_START_DT) FROM #TEMP1 T 
		WHERE #TEMPDATES.AGLTY_INDIV_ID = T.AGLTY_INDIV_ID)
	UPDATE #TEMPDATES SET T07_END = (SELECT MIN(ELGB_END_DT) FROM #TEMP1 T 
		WHERE #TEMPDATES.AGLTY_INDIV_ID = T.AGLTY_INDIV_ID)
	DELETE FROM #TEMP1 
		WHERE ELGB_START_DT IN (SELECT T07_START FROM #TEMPDATES 
		WHERE #TEMP1.AGLTY_INDIV_ID = #TEMPDATES.AGLTY_INDIV_ID)

	UPDATE #TEMPDATES SET T08_START = (SELECT MIN(ELGB_START_DT) FROM #TEMP1 T 
		WHERE #TEMPDATES.AGLTY_INDIV_ID = T.AGLTY_INDIV_ID)
	UPDATE #TEMPDATES SET T08_END = (SELECT MIN(ELGB_END_DT) FROM #TEMP1 T 
		WHERE #TEMPDATES.AGLTY_INDIV_ID = T.AGLTY_INDIV_ID)
	DELETE FROM #TEMP1 
		WHERE ELGB_START_DT IN (SELECT T08_START FROM #TEMPDATES 
		WHERE #TEMP1.AGLTY_INDIV_ID = #TEMPDATES.AGLTY_INDIV_ID)

	UPDATE #TEMPDATES SET T09_START = (SELECT MIN(ELGB_START_DT) FROM #TEMP1 T 
		WHERE #TEMPDATES.AGLTY_INDIV_ID = T.AGLTY_INDIV_ID)
	UPDATE #TEMPDATES SET T09_END = (SELECT MIN(ELGB_END_DT) FROM #TEMP1 T 
		WHERE #TEMPDATES.AGLTY_INDIV_ID = T.AGLTY_INDIV_ID)
	DELETE FROM #TEMP1 
		WHERE ELGB_START_DT IN (SELECT T09_START FROM #TEMPDATES 
		WHERE #TEMP1.AGLTY_INDIV_ID = #TEMPDATES.AGLTY_INDIV_ID)

	UPDATE #TEMPDATES SET T10_START = (SELECT MIN(ELGB_START_DT) FROM #TEMP1 T 
		WHERE #TEMPDATES.AGLTY_INDIV_ID = T.AGLTY_INDIV_ID)
	UPDATE #TEMPDATES SET T10_END = (SELECT MIN(ELGB_END_DT) FROM #TEMP1 T 
		WHERE #TEMPDATES.AGLTY_INDIV_ID = T.AGLTY_INDIV_ID)
	DELETE FROM #TEMP1 
		WHERE ELGB_START_DT IN (SELECT T10_START FROM #TEMPDATES 
		WHERE #TEMP1.AGLTY_INDIV_ID = #TEMPDATES.AGLTY_INDIV_ID)

	UPDATE #TEMPDATES SET T11_START = (SELECT MIN(ELGB_START_DT) FROM #TEMP1 T 
		WHERE #TEMPDATES.AGLTY_INDIV_ID = T.AGLTY_INDIV_ID)
	UPDATE #TEMPDATES SET T11_END = (SELECT MIN(ELGB_END_DT) FROM #TEMP1 T 
		WHERE #TEMPDATES.AGLTY_INDIV_ID = T.AGLTY_INDIV_ID)
	DELETE FROM #TEMP1 
		WHERE ELGB_START_DT IN (SELECT T11_START FROM #TEMPDATES 
		WHERE #TEMP1.AGLTY_INDIV_ID = #TEMPDATES.AGLTY_INDIV_ID)

	UPDATE #TEMPDATES SET T12_START = (SELECT MIN(ELGB_START_DT) FROM #TEMP1 T 
		WHERE #TEMPDATES.AGLTY_INDIV_ID = T.AGLTY_INDIV_ID)
	UPDATE #TEMPDATES SET T12_END = (SELECT MIN(ELGB_END_DT) FROM #TEMP1 T 
		WHERE #TEMPDATES.AGLTY_INDIV_ID = T.AGLTY_INDIV_ID)
	DELETE FROM #TEMP1 
		WHERE ELGB_START_DT IN (SELECT T12_START FROM #TEMPDATES 
		WHERE #TEMP1.AGLTY_INDIV_ID = #TEMPDATES.AGLTY_INDIV_ID)

	UPDATE #TEMPDATES SET T13_START = (SELECT MIN(ELGB_START_DT) FROM #TEMP1 T 
		WHERE #TEMPDATES.AGLTY_INDIV_ID = T.AGLTY_INDIV_ID)
	UPDATE #TEMPDATES SET T13_END = (SELECT MIN(ELGB_END_DT) FROM #TEMP1 T 
		WHERE #TEMPDATES.AGLTY_INDIV_ID = T.AGLTY_INDIV_ID)
	DELETE FROM #TEMP1 
		WHERE ELGB_START_DT IN (SELECT T13_START FROM #TEMPDATES 
		WHERE #TEMP1.AGLTY_INDIV_ID = #TEMPDATES.AGLTY_INDIV_ID)

	UPDATE #TEMPDATES SET T14_START = (SELECT MIN(ELGB_START_DT) FROM #TEMP1 T 
		WHERE #TEMPDATES.AGLTY_INDIV_ID = T.AGLTY_INDIV_ID)
	UPDATE #TEMPDATES SET T14_END = (SELECT MIN(ELGB_END_DT) FROM #TEMP1 T 
		WHERE #TEMPDATES.AGLTY_INDIV_ID = T.AGLTY_INDIV_ID)
	DELETE FROM #TEMP1 
		WHERE ELGB_START_DT IN (SELECT T14_START FROM #TEMPDATES 
		WHERE #TEMP1.AGLTY_INDIV_ID = #TEMPDATES.AGLTY_INDIV_ID)

	UPDATE #TEMPDATES SET T15_START = (SELECT MIN(ELGB_START_DT) FROM #TEMP1 T 
		WHERE #TEMPDATES.AGLTY_INDIV_ID = T.AGLTY_INDIV_ID)
	UPDATE #TEMPDATES SET T15_END = (SELECT MIN(ELGB_END_DT) FROM #TEMP1 T 
		WHERE #TEMPDATES.AGLTY_INDIV_ID = T.AGLTY_INDIV_ID)
	DELETE FROM #TEMP1 
		WHERE ELGB_START_DT IN (SELECT T15_START FROM #TEMPDATES 
		WHERE #TEMP1.AGLTY_INDIV_ID = #TEMPDATES.AGLTY_INDIV_ID)

	UPDATE #TEMPDATES SET T16_START = (SELECT MIN(ELGB_START_DT) FROM #TEMP1 T 
		WHERE #TEMPDATES.AGLTY_INDIV_ID = T.AGLTY_INDIV_ID)
	UPDATE #TEMPDATES SET T16_END = (SELECT MIN(ELGB_END_DT) FROM #TEMP1 T 
		WHERE #TEMPDATES.AGLTY_INDIV_ID = T.AGLTY_INDIV_ID)
	DELETE FROM #TEMP1 
		WHERE ELGB_START_DT IN (SELECT T16_START FROM #TEMPDATES 
		WHERE #TEMP1.AGLTY_INDIV_ID = #TEMPDATES.AGLTY_INDIV_ID)

	UPDATE #TEMPDATES SET T17_START = (SELECT MIN(ELGB_START_DT) FROM #TEMP1 T 
		WHERE #TEMPDATES.AGLTY_INDIV_ID = T.AGLTY_INDIV_ID)
	UPDATE #TEMPDATES SET T17_END = (SELECT MIN(ELGB_END_DT) FROM #TEMP1 T 
		WHERE #TEMPDATES.AGLTY_INDIV_ID = T.AGLTY_INDIV_ID)
	DELETE FROM #TEMP1 
		WHERE ELGB_START_DT IN (SELECT T17_START FROM #TEMPDATES 
		WHERE #TEMP1.AGLTY_INDIV_ID = #TEMPDATES.AGLTY_INDIV_ID)

	UPDATE #TEMPDATES SET T18_START = (SELECT MIN(ELGB_START_DT) FROM #TEMP1 T 
		WHERE #TEMPDATES.AGLTY_INDIV_ID = T.AGLTY_INDIV_ID)
	UPDATE #TEMPDATES SET T18_END = (SELECT MIN(ELGB_END_DT) FROM #TEMP1 T 
		WHERE #TEMPDATES.AGLTY_INDIV_ID = T.AGLTY_INDIV_ID)
	DELETE FROM #TEMP1 
		WHERE ELGB_START_DT IN (SELECT T18_START FROM #TEMPDATES 
		WHERE #TEMP1.AGLTY_INDIV_ID = #TEMPDATES.AGLTY_INDIV_ID)

	UPDATE #TEMPDATES SET T19_START = (SELECT MIN(ELGB_START_DT) FROM #TEMP1 T 
		WHERE #TEMPDATES.AGLTY_INDIV_ID = T.AGLTY_INDIV_ID)
	UPDATE #TEMPDATES SET T19_END = (SELECT MIN(ELGB_END_DT) FROM #TEMP1 T 
		WHERE #TEMPDATES.AGLTY_INDIV_ID = T.AGLTY_INDIV_ID)
	DELETE FROM #TEMP1 
		WHERE ELGB_START_DT IN (SELECT T19_START FROM #TEMPDATES 
		WHERE #TEMP1.AGLTY_INDIV_ID = #TEMPDATES.AGLTY_INDIV_ID)

	UPDATE #TEMPDATES SET T20_START = (SELECT MIN(ELGB_START_DT) FROM #TEMP1 T 
		WHERE #TEMPDATES.AGLTY_INDIV_ID = T.AGLTY_INDIV_ID)
	UPDATE #TEMPDATES SET T20_END = (SELECT MIN(ELGB_END_DT) FROM #TEMP1 T 
		WHERE #TEMPDATES.AGLTY_INDIV_ID = T.AGLTY_INDIV_ID)
	DELETE FROM #TEMP1 
		WHERE ELGB_START_DT IN (SELECT T20_START FROM #TEMPDATES 
		WHERE #TEMP1.AGLTY_INDIV_ID = #TEMPDATES.AGLTY_INDIV_ID)


CREATE TABLE #TENURE (AGLTY_INDIV_ID NVARCHAR(20), 
L1 INT,
L2 INT,
L3 INT,
L4 INT,
L5 INT,
L6 INT,
L7 INT,
L8 INT,
L9 INT,
L10 INT,
L11 INT,
L12 INT,
L13 INT,
L14 INT,
L15 INT,
L16 INT,
L17 INT,
L18 INT,
L19 INT,
L20 INT,
)
INSERT INTO #TENURE
SELECT AGLTY_INDIV_ID, 
(SELECT CASE 
WHEN T01_END > T02_START THEN DATEDIFF(DAY,T01_START,T02_START)
ELSE DATEDIFF(DAY,T01_START,T01_END) 
END) AS L1,
(SELECT CASE 
WHEN T02_END < T03_START OR T03_START IS NULL THEN DATEDIFF(DAY,T02_START,T02_END) 
WHEN T02_END > T03_START AND T03_START IS NOT NULL THEN DATEDIFF(DAY,T02_START,T03_START)
END) AS L2,
(SELECT CASE 
WHEN T03_END < T04_START OR T04_START IS NULL THEN DATEDIFF(DAY,T03_START,T03_END) 
WHEN T03_END > T04_START AND T04_START IS NOT NULL THEN DATEDIFF(DAY,T03_START,T04_START)
END) AS L3,
(SELECT CASE 
WHEN T04_END < T05_START OR T05_START IS NULL THEN DATEDIFF(DAY,T04_START,T04_END) 
WHEN T04_END > T05_START AND T05_START IS NOT NULL THEN DATEDIFF(DAY,T04_START,T05_START)
END) AS L4,
(SELECT CASE 
WHEN T05_END < T06_START OR T06_START IS NULL THEN DATEDIFF(DAY,T05_START,T05_END) 
WHEN T05_END > T06_START AND T06_START IS NOT NULL THEN DATEDIFF(DAY,T05_START,T06_START)
END) AS L5,
(SELECT CASE 
WHEN T06_END < T07_START OR T07_START IS NULL THEN DATEDIFF(DAY,T06_START,T06_END) 
WHEN T06_END > T07_START AND T07_START IS NOT NULL THEN DATEDIFF(DAY,T06_START,T07_START)
END) AS L6,
(SELECT CASE 
WHEN T07_END < T08_START OR T08_START IS NULL THEN DATEDIFF(DAY,T07_START,T07_END) 
WHEN T07_END > T08_START AND T08_START IS NOT NULL THEN DATEDIFF(DAY,T07_START,T08_START)
END) AS L7,
(SELECT CASE 
WHEN T08_END < T09_START OR T09_START IS NULL THEN DATEDIFF(DAY,T08_START,T08_END) 
WHEN T08_END > T09_START AND T09_START IS NOT NULL THEN DATEDIFF(DAY,T08_START,T09_START)
END) AS L8,
(SELECT CASE 
WHEN T09_END < T10_START OR T10_START IS NULL THEN DATEDIFF(DAY,T09_START,T09_END) 
WHEN T09_END > T10_START AND T10_START IS NOT NULL THEN DATEDIFF(DAY,T09_START,T10_START)
END) AS L9,
(SELECT CASE 
WHEN T10_END < T11_START OR T11_START IS NULL THEN DATEDIFF(DAY,T10_START,T10_END) 
WHEN T10_END > T11_START AND T11_START IS NOT NULL THEN DATEDIFF(DAY,T10_START,T11_START)
END) AS L10,
(SELECT CASE 
WHEN T11_END < T12_START OR T12_START IS NULL THEN DATEDIFF(DAY,T11_START,T11_END) 
WHEN T11_END > T12_START AND T12_START IS NOT NULL THEN DATEDIFF(DAY,T11_START,T12_START)
END) AS L11,
(SELECT CASE 
WHEN T12_END < T13_START OR T13_START IS NULL THEN DATEDIFF(DAY,T12_START,T12_END) 
WHEN T12_END > T13_START AND T13_START IS NOT NULL THEN DATEDIFF(DAY,T12_START,T13_START)
END) AS L12,
(SELECT CASE 
WHEN T13_END < T14_START OR T14_START IS NULL THEN DATEDIFF(DAY,T13_START,T13_END) 
WHEN T13_END > T14_START AND T14_START IS NOT NULL THEN DATEDIFF(DAY,T13_START,T14_START)
END) AS L13,
(SELECT CASE 
WHEN T14_END < T15_START OR T15_START IS NULL THEN DATEDIFF(DAY,T14_START,T14_END) 
WHEN T14_END > T15_START AND T15_START IS NOT NULL THEN DATEDIFF(DAY,T14_START,T15_START)
END) AS L14,
(SELECT CASE 
WHEN T15_END < T16_START OR T16_START IS NULL THEN DATEDIFF(DAY,T15_START,T15_END) 
WHEN T15_END > T16_START AND T16_START IS NOT NULL THEN DATEDIFF(DAY,T15_START,T16_START)
END) AS L15,
(SELECT CASE 
WHEN T16_END < T17_START OR T17_START IS NULL THEN DATEDIFF(DAY,T16_START,T16_END) 
WHEN T16_END > T17_START AND T17_START IS NOT NULL THEN DATEDIFF(DAY,T16_START,T17_START)
END) AS L16,
(SELECT CASE 
WHEN T17_END < T18_START OR T18_START IS NULL THEN DATEDIFF(DAY,T17_START,T17_END) 
WHEN T17_END > T18_START AND T18_START IS NOT NULL THEN DATEDIFF(DAY,T17_START,T18_START)
END) AS L17,
(SELECT CASE 
WHEN T18_END < T19_START OR T19_START IS NULL THEN DATEDIFF(DAY,T18_START,T18_END) 
WHEN T18_END > T19_START AND T19_START IS NOT NULL THEN DATEDIFF(DAY,T18_START,T19_START)
END) AS L18,
(SELECT CASE 
WHEN T19_END < T20_START OR T20_START IS NULL THEN DATEDIFF(DAY,T19_START,T19_END) 
WHEN T19_END > T20_START AND T20_START IS NOT NULL THEN DATEDIFF(DAY,T19_START,T20_START)
END) AS L19,
DATEDIFF(DAY,T20_START,T20_END) AS L20
FROM #TEMPDATES


CREATE TABLE #SUM (AGLTY_INDIV_ID NVARCHAR(20), CNT INT)
INSERT #SUM SELECT AGLTY_INDIV_ID, L1 FROM #TENURE
INSERT #SUM SELECT AGLTY_INDIV_ID, L2 FROM #TENURE
INSERT #SUM SELECT AGLTY_INDIV_ID, L3 FROM #TENURE
INSERT #SUM SELECT AGLTY_INDIV_ID, L4 FROM #TENURE
INSERT #SUM SELECT AGLTY_INDIV_ID, L5 FROM #TENURE
INSERT #SUM SELECT AGLTY_INDIV_ID, L6 FROM #TENURE
INSERT #SUM SELECT AGLTY_INDIV_ID, L7 FROM #TENURE
INSERT #SUM SELECT AGLTY_INDIV_ID, L8 FROM #TENURE
INSERT #SUM SELECT AGLTY_INDIV_ID, L9 FROM #TENURE
INSERT #SUM SELECT AGLTY_INDIV_ID, L10 FROM #TENURE
INSERT #SUM SELECT AGLTY_INDIV_ID, L11 FROM #TENURE
INSERT #SUM SELECT AGLTY_INDIV_ID, L12 FROM #TENURE
INSERT #SUM SELECT AGLTY_INDIV_ID, L13 FROM #TENURE
INSERT #SUM SELECT AGLTY_INDIV_ID, L14 FROM #TENURE
INSERT #SUM SELECT AGLTY_INDIV_ID, L15 FROM #TENURE
INSERT #SUM SELECT AGLTY_INDIV_ID, L16 FROM #TENURE
INSERT #SUM SELECT AGLTY_INDIV_ID, L17 FROM #TENURE
INSERT #SUM SELECT AGLTY_INDIV_ID, L18 FROM #TENURE
INSERT #SUM SELECT AGLTY_INDIV_ID, L19 FROM #TENURE
INSERT #SUM SELECT AGLTY_INDIV_ID, L20 FROM #TENURE



SELECT  DISTINCT T1.AGLTY_INDIV_ID, 
		SUM(CNT)/365.242 AS TENURE_YEARS, --TENURE IN YEARS (USING AVG OF 365.242 DAYS)
		SUM(CNT)/30 AS TENURE_MONTHS, -- TENURE IN MONTHS (USING AVG OF 30 DAYS)
		SUM(CNT) AS TENURE_DAYS --TENURE IN DAYS
INTO #TENURE_FINAL --FILE OUTPUT
FROM #SUM T1
GROUP BY T1.AGLTY_INDIV_ID

DROP TABLE #INPUT
DROP TABLE #TEMP1
DROP TABLE #TENURE
DROP TABLE #SUM
DROP TABLE #TEMPDATES

--TENURE CODE END

SELECT * 
INTO WS_EHAYNES.dbo.MED_DM_22_Targeting_TenureAEP 
--INTO WS_EHAYNES.dbo.MED_DM_22_Targeting_TenureSEP 
FROM #TENURE_FINAL /*SAVE YOUR OUTPUT*/

DROP TABLE #TENURE_FINAL
