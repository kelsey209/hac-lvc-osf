*********************************************************************************;
* program name: top_run.sas;
* project: hac and lvc;
* description: top level file to get cohorts for services;
*********************************************************************************;
%let mylib = kch315sl;
%let code_files = /sas/vrdc/users/kch315/files/dua_052606/AV/HACS;
%let year_input = 2016;

%let output_files = /sas/vrdc/users/kch315/files/dua_052606/AV/HACS/output;

/*********************************************************************************/
/* 0 --------- create/update macros */
/*********************************************************************************/
%include "&code_files/do_over.sas";
%include "&code_files/lvc_label.sas";
%include "&code_files/hac_label.sas";
%include "&code_files/hospitalvisit_outpatient_label.sas";
%include "&code_files/psi_label.sas";
%include "&code_files/psi_hosp_formats.sas";
%include "&code_files/psi_macros.sas";
%include "&code_files/ccs_formats.sas";
%include "&code_files/pri_procedure.sas";

/* create lvc formats (codes) */
%create_list;

/* create arhq elixhauser comorbidity formats */ 
%include "&code_files/comorb_icd10cm_format_v20211.sas";

options fmtsearch=(&mylib..formats);

/*********************************************************************************/
/* 1 --------- outpatient cohort and results */
/*********************************************************************************/
%service_outpatient(year_input=&year_input);

/* exclusions */ 
data &mylib..res__otp_&year_input; 
	set &mylib..res__otp_&year_input; 
	exc_missing = 0;
	if missing(service_dt) then exc_missing = 1; 
run; 

proc freq data=&mylib..res__otp_&year_input; 
	table exc_missing; 
run; 

data &mylib..res__otp_&year_input(drop=exc_missing);
	set &mylib..res__otp_&year_input;
	where exc_missing = 0; 
run; 

%apply_bene_exclusions(&mylib..res__otp_&year_input,&year_input);

/*********************************************************************************/
/* 1b --------- hospital admissions: 7-day */
/*********************************************************************************/
%outpatient_7days(&mylib..res__otp_&year_input,&year_input);

/*********************************************************************************/
/* 1c --------- inpatient admissions: HACs */
/*********************************************************************************/
/* create hac labels for each admission */
data temp_input; 
	set &mylib..res__otp_medpar7_&year_input;
	where out_7days_unplanned = 1 and exc_medpar_overlap = 0 and exc_medpar_admsntype = 0 and exc_medpar_pps = 0; 
run; 

%hac_table(temp_input,&year_input,temp_hac);

data &mylib..res__otp_med_hac_&year_input; 
	set temp_hac;
run; 

/*********************************************************************************/
/* 1d --------- inpatient admissions: PSIs */
/*********************************************************************************/
%run_psi(temp_input,&year_input,temp_psi);

proc freq data=temp_psi; 
	table out_psi_numerator; 
run; 

data &mylib..res__otp_med_psi_&year_input;
	set temp_psi; 
run; 

/*********************************************************************************/
/*********************************************************************************/
/*********************************************************************************/

/*********************************************************************************/
/* 2 --------- find service claims in medpar */
/*********************************************************************************/

%service_medpar(year_input=&year_input);

/*********************************************************************************/
/* 2a --------- exclusions */
/*********************************************************************************/

%apply_bene_exclusions(&mylib..res__inp_&year_input,&year_input);

/*********************************************************************************/
/* 2b --------- hacs */
/*********************************************************************************/

%hac_table(&mylib..res__inp_&year_input,&year_input,&mylib..res__inp_hac_&year_input);

proc freq data=&mylib..res__inp_hac_&year_input;
	table out_hac_numerator; 
run; 

/*********************************************************************************/
/* 2c --------- psis */
/*********************************************************************************/

%run_psi(&mylib..res__inp_&year_input,&year_input,&mylib..res__inp_psi_&year_input);

proc freq data=&mylib..res__inp_psi_&year_input;
	table out_psi_numerator; 
run; 

/*********************************************************************************/
/* 2d --------- label procedure code */
/*********************************************************************************/

%run_pri(&mylib..res__inp_&year_input,&year_input);






