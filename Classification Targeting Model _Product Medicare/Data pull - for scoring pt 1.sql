/* Connected to 3778 */

/* -------------------------------------------------------------------------------------------------*/
/*  Marketable Medicare Prospect Population                                                         */
/* -------------------------------------------------------------------------------------------------*/

	-- Imported the file "NIS_SCORING_4_ELSA.txt" to WS_EHAYNES.dbo.MED_DM_22_Scoring_Pop

	SELECT DISTINCT
		AGLTY_INDIV_ID
	,	AGLTY_ADDR_ID AS AGLTY_ADDR_ID_VCHAR
	,	CAST(AGLTY_ADDR_ID AS NUMERIC(35)) AS AGLTY_ADDR_ID
	,	Segment_Name
	,	Region
	INTO #temp
	FROM WS_EHAYNES.dbo.MED_DM_22_Scoring_Pop

	--SELECT TOP 1000 * FROM #temp
	DROP TABLE WS_EHAYNES.dbo.MED_DM_22_Scoring_Pop
	SELECT * INTO WS_EHAYNES.dbo.MED_DM_22_Scoring_Pop FROM #temp

	CREATE INDEX AGLTY_INDIV_ID
	ON WS_EHAYNES.dbo.MED_DM_22_Scoring_Pop(AGLTY_INDIV_ID)

	CREATE INDEX AGLTY_ADDR_ID
	ON WS_EHAYNES.dbo.MED_DM_22_Scoring_Pop(AGLTY_ADDR_ID)

/* -------------------------------------------------------------------------------------------------*/
/*  Address                                                                                         */
/* -------------------------------------------------------------------------------------------------*/

	SELECT DISTINCT
		x.*
	,	a.ZIP_CD
	,	a.ZIP4_CD
	,	a.HOSP_DIST_MSR
	,	a.MOB_DIST_MSR
	INTO WS_EHAYNES.dbo.MED_DM_22_Scoring_Addr1
	FROM WS_EHAYNES.dbo.MED_DM_22_Scoring_PoP x 
	LEFT JOIN [p4685].MARS.dbo.ADDRESS a
		ON x.AGLTY_ADDR_ID=a.AGLTY_ADDR_ID

	-- 28 minute runtime. 4,742,862 records.

	DECLARE @ZIPYR AS INT 
	SET @ZIPYR = (SELECT DISTINCT MAX(YR_NBR) FROM [p4685].[MARS].[dbo].[ZIP_LEVEL_INFO]) -- 2022
	SELECT DISTINCT
		x.*
	,	g.GEOCODE
	,	g.COUNTYFIPS
	,	zip.CNTY_NM
	,	zip.ST_CD
	,	zip.REGN_CD
	,	zip.SUB_REGN_CD
	,	zip.SVC_AREA_NM 
	INTO WS_EHAYNES.dbo.MED_DM_22_Scoring_Addr
	FROM WS_EHAYNES.dbo.MED_DM_22_Scoring_Addr1 x
	LEFT JOIN [p4685].MARS.dbo.GEOCODE_LKUP g
		ON x.AGLTY_ADDR_ID = g.AGLTY_ADDR_ID_VCHAR
	LEFT JOIN [p4685].[MARS].[dbo].[ZIP_LEVEL_INFO] zip
		ON x.ZIP_CD=zip.ZIP_CD
		AND x.ZIP4_CD BETWEEN zip.ZIP4_START_CD AND zip.ZIP4_END_CD
		AND zip.YR_NBR=@ZIPYR

	-- 1:24 min run time: 4,742,862 records

	/* Match % on geocode: 99.99% */
	SELECT DISTINCT
		CAST(SUM(CASE WHEN a.GEOCODE IS NOT NULL THEN 1 ELSE 0 END) AS FLOAT)/CAST(COUNT(p.AGLTY_INDIV_ID) AS FLOAT)*100 AS PCT_MATCH_GEO
	FROM WS_EHAYNES.dbo.MED_DM_22_Scoring_Pop p
	LEFT JOIN WS_EHAYNES.dbo.MED_DM_22_Scoring_Addr a 
		ON p.AGLTY_INDIV_ID=a.AGLTY_INDIV_ID

	DROP TABLE WS_EHAYNES.dbo.MED_DM_22_Scoring_Addr1
