/****************************************************************************************************/
/*  Program Name:       SAS_Macro_CheckForData.sas                                                  */
/*                                                                                                  */
/*  Date Created:       Jan 18, 2021                                                                */
/*                                                                                                  */
/*  Created By:         Elle Haynes                                                                 */
/*                                                                                                  */
/*  Purpose:            Checks for data in a table and sets the variable cancel=cancel at error.    */
/*                                                                                                  */
/*  Inputs:             Dataset name, condition, and error message.                                 */
/*                                                                                                  */
/* -------------------------------------------------------------------------------------------------*/	
/*  Notes:                                                                                          */
/* -------------------------------------------------------------------------------------------------*/
/*  Date Modified:                                                                                  */
/*  Modified by:                                                                                    */
/*  Description:                                                                                    */
/****************************************************************************************************/

	%macro check_for_data(dataset,cond,err_msg);
		%if &cancel= and %sysfunc(exist(&dataset.)) %then %do;
			proc sql noprint; select distinct count(*) into :N from &dataset.; quit;
			%if %eval(&N.&cond.) %then %do;
				%put ERROR: &err_msg..;
				%let cancel=cancel;
			%end;
			%else %do;
				%put &dataset. is OK! Continuing...;
				%let cancel=&cancel.;
			%end;
		%end;
		%else %do;
			%put ERROR: &err_msg..;
			%let cancel=cancel;
		%end;
	%mend;
