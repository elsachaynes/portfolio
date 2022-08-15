/****************************************************************************************************/
/*  Program Name:       SAS_Macro_ListFiles.sas                                                     */
/*                                                                                                  */
/*  Date Created:       Jan 18, 2021                                                                */
/*                                                                                                  */
/*  Created By:         Elle Haynes                                                                 */
/*                                                                                                  */
/*  Purpose:            Lists all files in a particular folder of a particular extension.           */
/*                                                                                                  */
/*  Inputs:             File path and extension name, like "csv".                                   */
/*                                                                                                  */
/* -------------------------------------------------------------------------------------------------*/	
/*  Notes:              %list_files(&raw_file_path,ext=csv), or                                     */
/*                      New Default: %list_files(&raw_file_path)                                    */
/* -------------------------------------------------------------------------------------------------*/
/*  Date Modified:      Jan 26, 2021                                                                */
/*  Modified by:        Elle Haynes                                                                 */
/*  Description:        Added default to EXT=0, which does not require an extension input.          */
/****************************************************************************************************/

	*Creates a list of all files in the DIR directory with the specified extension (EXT);
	%macro list_files(dir,ext=0);

		*Clear "list" if already exists;
		data _null_; if exist ("WORK.LIST") then call execute("proc datasets library=work nolist; delete LIST;run;quit;") ; run;

		%local filrf rc did memcnt name i;
		%let rc=%sysfunc(filename(filrf,&dir));
		%let did=%sysfunc(dopen(&filrf));

		%if &did eq 0 %then
			%do;
				%put Directory &dir cannot be open or does not exist;

				%return;
			%end;

		%do i = 1 %to %sysfunc(dnum(&did));
			%let name=%qsysfunc(dread(&did,&i));

			%if %qupcase(%qscan(&name,-1,.)) = %upcase(&ext) %then
				%do;
					%put &dir\&name;
					%let file_name =  %qscan(&name,1,.);
					%put &file_name;

					data _tmp;
						length dir $512 name $100;
						dir=symget("dir");
						name=symget("name");
						path = catx('\',dir,name);
						the_name = substr(name,1,find(name,'.')-1);
					run;

					proc append base=list data=_tmp force;
					run;

					quit;

					proc sql;
						drop table _tmp;
					quit;

				%end;
			%else %if %eval(&ext = 0)=1 %then
				%do;
					%put &dir\&name;
					%let file_name =  %qscan(&name,1,.);
					%put &file_name;

					data _tmp;
						length dir $512 name $100;
						dir=symget("dir");
						name=symget("name");
						path = catx('\',dir,name);
						the_name = substr(name,1,find(name,'.')-1);
					run;

					proc append base=list data=_tmp force;
					run;

					quit;

					proc sql;
						drop table _tmp;
					quit;
				%end;
/*			%else %if %qscan(&name,2,.) = %then*/
/*				%do;*/
/*					%list_files(&dir\&name,&ext)*/
/*				%end;*/
		%end;

		%let rc=%sysfunc(dclose(&did));
		%let rc=%sysfunc(filename(filrf));
		* Wait in-between runs;
		%let sleep_time = 60;
		data _null_;
			put 30*'-' / " Waiting &sleep_time. seconds." / 30*'-';
			rc=sleep(&sleep_time,1);
		run;
	%mend list_files;