/****************************************************************************************************/
/*  Program Name:       SAS_Macro_APIvariablePrep.sas                                               */
/*                                                                                                  */
/*  Date Created:       Sept 29, 2020                                                               */
/*                                                                                                  */
/*  Created By:         Nydia Lopez & Elle Haynes, based on a SAS Dummy Blog article:               */
/*  https://blogs.sas.com/content/sasdummy/2017/04/14/using-sas-to-access-google-analytics-apis/    */
/*                                                                                                  */
/*  Purpose:            This macro prepares variables (metrics and dimensions) for use in the       */
/*                      GA API call. It creates 4 macro variables: informats, formats, dimensions,  */
/*                      and metrics that are used in subsequent code.                               */
/*                                                                                                  */
/*  Inputs:             The user provides the variable names (in GA format) and the expected SAS    */
/*                      format.                                                                     */
/*                                                                                                  */
/* -------------------------------------------------------------------------------------------------*/	
/*  Notes:              Add functionality to lookup whether a variable is a dimension or metric.    */
/* -------------------------------------------------------------------------------------------------*/
/*  Date Modified:      Oct 5, 2020                                                                 */
/*  Modified by:        Elle Haynes                                                                 */
/*  Description:        Add rollup_dimensions and rollup_metrics.                                   */
/****************************************************************************************************/

%macro APIvariablePrep(number_of_dimensions,number_of_metrics);

	%let number_of_variables=%eval(&number_of_dimensions+&number_of_metrics);

	/* -------------------------------------------------------------------------------------------------*/
	/*  Set up data step formats.                                                                       */
	/* -------------------------------------------------------------------------------------------------*/

	%let formats=;
	%let ga_formats=;
	%let i=1;	
	%do i=1 %to &number_of_variables; 
		%let ga_formats=%nrbquote(&&var&i &&format_var&i );
		%let formats=&formats&ga_formats;
	%end;
	%let formats=%sysfunc(strip(&formats));

	/* -------------------------------------------------------------------------------------------------*/
	/*  Set up data step rename/informat.                                                               */
	/* -------------------------------------------------------------------------------------------------*/

	%let informats=;
	%let ga_informats=;
	%let i=1;	
	%do i=1 %to &number_of_variables; 
		%let ga_informats=%nrbquote(&&var&i=input(element&i,&&informat_var&i))%nrstr(; );
		%let informats=&informats&ga_informats;
	%end;

	/* -------------------------------------------------------------------------------------------------*/
	/*  Set up API call for dimensions.                                                                 */
	/* -------------------------------------------------------------------------------------------------*/

	%let dimensions=;
	%let i=1;
	%let ga_var=%sysfunc(catt(%nrquote(ga:),&&var&i)); *no leading comma;
	%let dimensions=&dimensions&ga_var;
	%do i=2 %to &number_of_dimensions;
		%let ga_var=%sysfunc(catt(%quote(,),%nrquote(ga:),&&var&i));
		%let dimensions=&dimensions&ga_var;
	%end;	
	%let dimensions=%sysfunc(urlencode(%nrbquote(&dimensions.)));

	/* -------------------------------------------------------------------------------------------------*/
	/*  Set up API call for metrics.                                                                    */
	/* -------------------------------------------------------------------------------------------------*/

	%let metrics=;
	%let i=%eval(&number_of_dimensions+1);
	%let ga_var=%sysfunc(catt(%nrquote(ga:),&&var&i)); *no leading comma;
	%let metrics=&metrics&ga_var;
	%do i=%eval(&number_of_dimensions+2) %to &number_of_variables;
		%let ga_var=%sysfunc(catt(%quote(,),%nrquote(ga:),&&var&i));
		%let metrics=&metrics&ga_var;
	%end;	
	%let metrics=%sysfunc(urlencode(%nrbquote(&metrics.)));

	/* -------------------------------------------------------------------------------------------------*/
	/*  Set up data rollup for multiple views.                                                          */
	/* -------------------------------------------------------------------------------------------------*/
	
		%let rollup_metrics=;
		%do i=%eval(&number_of_dimensions+1) %to &number_of_variables;
			%let roll_var=%quote(, )%nrbquote( sum(&&var&i) as &&var&i format &&format_var&i);
			%let rollup_metrics=&rollup_metrics%nrbquote(&roll_var);
		%end;	

		%let rollup_dimensions=;
		%let i=1;
		%let roll_var=&&var&i; *no leading comma;
		%let rollup_dimensions=&rollup_dimensions&roll_var;
		%do i=2 %to &number_of_dimensions;
			%let roll_var=%sysfunc(catt(%quote(,),&&var&i));
			%let rollup_dimensions=&rollup_dimensions&roll_var;
		%end;	

/*		%put ROLLUP DIMENSIONS INPUT: &rollup_dimensions;*/
/*		%put ROLLUP METRICS INPUT: "&rollup_metrics";*/


	/* -------------------------------------------------------------------------------------------------*/
	/*  Output for troubleshooting.                                                                     */
	/* -------------------------------------------------------------------------------------------------*/

/*	%put DIMENSIONS INPUT: &dimensions;*/
/*	%put METRICS INPUT: &metrics;*/
/*	%put FORMAT INPUT: &formats;*/
/*	%put INFORMAT INPUT: "&informats";*/
/*	%put WARNING: Variable cleaning SUCCESS!;*/
	
%mend;
