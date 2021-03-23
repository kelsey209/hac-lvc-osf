*********************************************************************************;
* program name: hospitalvist_outpatient_label.sas;
* project: hac and lvc;
* description: creates cohort of inpatient admissions within 7 days of an outpatient lv procedure;

** numerator: all-cause unplanned hospital visits: 
 1) inpatient admission directly following surgery
 2) ED visit, observation stay or unplanned inpatient admission occurring after discharge from 
     HOPD and within 7 days of the outpatient surgery;

** denominator: 
 eligible same-day surgeries or cystoscopy procedures with interventions performed
 at HOPDs for Medicare FFS patients (except for eye surgeries and same day surgeries performed
 at the same time as high-risk procedures)
*********************************************************************************;

* 
TODO Change these to one year (all years) and cut-off for admissions: 
- 7 days before 1 Jan 2019
- hospital admissions that are discharged before 1 Jan 2019
mylib.res__outpatient_&service_label_&year_input_&month;

*
TODO apply facility exclusions;

/*********************************************************************************
 * macro: medpar_7days
 * input: 
input_data, year_input
* output: 
table with inpatient (medpar) records that were unplanned and within 7 days
*********************************************************************************/
%macro medpar_7days(input_data,year_input);

	proc sort data=&input_data(keep=bene_id service_dt) nodupkey out=temp_;
		by bene_id service_dt; 
	run;  

	%LET next_year = %sysevalf(&year_input+1);

	%IF &next_year ne 2019 %THEN %DO;
	data temp_;
		if 0 then
			set temp_;

		if _n_ = 1 then
			do;
				declare hash dim1 (dataset:"temp_", ordered: "a", multidata:"yes");
				dim1.definekey ('bene_id');
				dim1.definedata (all:"yes");
				dim1.definedone();
			end;

		do until(eof);
			set medpar.medpar_&year_input(keep = bene_id medpar_id admsn_dt dschrg_dt nch_clm_type_cd pps_ind_cd) 
				medpar.medpar_&next_year(keep = bene_id medpar_id admsn_dt dschrg_dt nch_clm_type_cd pps_ind_cd) end=eof;

			rc = dim1.find();
			if rc = 0 and 0 <= intck('day',service_dt,admsn_dt) <= 7 then
				output;
			* check for multiple admissions ; 
			do while(rc=0);
				rc = dim1.find_next();
				if rc = 0 and 0<=intck('day',service_dt,admsn_dt) <= 7 then 
					output; 
			end;
		end;

		stop;
	run;
	%END;
	%ELSE %DO;
	data temp_;
		if 0 then
			set temp_;

		if _n_ = 1 then
			do;
				declare hash dim1 (dataset:"temp_", ordered: "a", multidata:"yes");
				dim1.definekey ('bene_id');
				dim1.definedata (all:"yes");
				dim1.definedone();
			end;

		do until(eof);
			set medpar.medpar_&year_input(keep = bene_id medpar_id admsn_dt dschrg_dt nch_clm_type_cd pps_ind_cd) 
			 end=eof;

			rc = dim1.find(); 
			if rc = 0 and 0 <= intck('day',service_dt,admsn_dt) <= 7 then
				output;
			* check for multiple admissions ; 
			do while(rc=0);
				rc = dim1.find_next();
				if rc = 0 and 0<=intck('day',service_dt,admsn_dt) <= 7 then 
					output; 
			end;
		end;

		stop;
	run;
	%END;

	* check if there is overlap (after admission date); 
	* may occur if there is a claim from both inpatient and outpatient ; 
	* not including same day - in case discharge happened ; 
	data temp_;
		set temp_;
		exc_medpar_overlap = 0; 
		exc_medpar_admsntype = 0; 
		exc_medpar_pps = 0; 
		if admsn_dt < service_dt then exc_medpar_overlap = 1; 
		if nch_clm_type_cd not in ('60','61') then exc_medpar_admsntype = 1; 
		if pps_ind_cd not in ('2') then exc_medpar_pps = 1; 
	run; 

	data res__medpar7days;
		set temp_;
	run; 

	proc datasets lib=work nolist; 
		delete temp_;
	run; 

%mend medpar_7days;

/*********************************************************************************
 * macro: outpatient_7days
 * input: 
input data, year_input
* output: 
flag (and medpar record) for inpatient 7-day admission
*********************************************************************************/
%macro outpatient_7days(input_data,year_input);

	/*1 ------------ find medpar admissions within 7 days */
	%medpar_7days(&input_data,&year_input);

	/*2 ------------ get unique medpar info */ 
	proc sort data = res__medpar7days(keep=bene_id medpar_id) nodupkey out=res__medpar_un; 
		by bene_id medpar_id; 
	run; 

	%LET next_year = %SYSEVALF(&year_input+1);

	%IF &next_year ne 2019 %THEN %DO; 
	data res__medpar_un; 
		set res__medpar_un;
		if _n_ = 1 then
			do;
				declare hash dim1 (dataset:"res__medpar_un", ordered: "a", multidata:"yes");
				dim1.definekey ('bene_id','medpar_id');
				dim1.definedata (all:"yes");
				dim1.definedone();
			end;

		do until(eof);
			set medpar.medpar_&year_input(keep = bene_id medpar_id srgcl_prcdr_1_cd--srgcl_prcdr_25_cd admtg_dgns_cd dgns_1_cd) 
				medpar.medpar_&next_year(keep = bene_id medpar_id srgcl_prcdr_1_cd--srgcl_prcdr_25_cd admtg_dgns_cd dgns_1_cd)
			 end=eof;

			if dim1.find() = 0 then output; 
		end;
		stop;
	run; 
	%END; 
	%ELSE %DO; 
	data res__medpar_un; 
		set res__medpar_un;
		if _n_ = 1 then
			do;
				declare hash dim1 (dataset:"res__medpar_un", ordered: "a");
				dim1.definekey ('bene_id','medpar_id');
				dim1.definedata (all:"yes");
				dim1.definedone();
			end;

		do until(eof);
			set medpar.medpar_&year_input(keep = bene_id medpar_id srgcl_prcdr_1_cd--srgcl_prcdr_25_cd admtg_dgns_cd dgns_1_cd) 
			 end=eof;

			if dim1.find() = 0 then output; 
		end;
		stop;
	run; 
	%END;

	/*3 ------------ classify unplanned versus planned admissions */
	data res__medpar_un;
		set res__medpar_un;  

		out_7days_unplanned = 0; 
		planned = 0;
		potentially_planned = 0;

		/* admission is for bone marrow, kidney or other organ transplant (64,105,176) - any procedure code*/
		* combined this step with the other ccs code search (for any procedure position);

		array procedures $ srgcl_prcdr_1_cd--srgcl_prcdr_25_cd;

		do over procedures;
			if not missing(procedures) then
				do;
					if put(procedures,$I10PRCCS.) in ('64','105','176') then
						planned = 1;
					else if put(procedures,$pa3_icd.) eq '1' then
						potentially_planned = 1;
					else if put(put(procedures,$I10PRCCS.),$pa3_ccs.) eq '1' then
						potentially_planned = 1;
				end;
		end;

		/* admission is maintenance chemotherapy or rehabilitation - principal diagnosis code (also check admitting) */
		if not missing(admtg_dgns_cd) and put(admtg_dgns_cd,$I10DXCCS.) in ('45','254') then
			planned = 1;

		if not missing(dgns_1_cd) and put(dgns_1_cd,$I10DXCCS.) in ('45','254') then
			planned = 1;

		/* if planned = 0 and there was a potentially planned procedure, then check principal diagnosis code for acute diagnoses */
		if planned = 0 and potentially_planned = 1 and not missing(dgns_1_cd) then
			do;
				if put(dgns_1_cd,$pa4_icd.) in ('1') or 
					put(put(dgns_1_cd,$I10DXCCS.),$pa4_ccs.) in ('1') then 
					planned = 0; 
				else planned = 1; 
			end;

		if planned = 0 then out_7days_unplanned = 1; 
	run;

	/*4------------ join back to original outpatient table - flag for 7-day unplanned admissions */
	proc sort data=res__medpar7days; 
		by bene_id medpar_id; 
	run; 

	proc sort data=res__medpar_un; 
		by bene_id medpar_id; 
	run; 

	data res__medpar7days; 
		merge res__medpar7days res__medpar_un(keep=bene_id medpar_id out_7days_unplanned);  
		by bene_id medpar_id; 
	run; 
	
	proc sql; 
		create table temp_ as 
		select bene_id, service_dt, sum(out_7days_unplanned) as out_7days_unplanned_no 
		from res__medpar7days 
		where exc_medpar_overlap = 0 and exc_medpar_admsntype = 0 and exc_medpar_pps = 0
		group by bene_id, service_dt ;
	quit; 

	proc sort data=&input_data; 
		by bene_id service_dt; 
	run; 

	data &input_data; 
		merge &input_data temp_;
		by bene_id service_dt; 
	run; 

	data &mylib..res__otp_medpar7_&year_input;
		set res__medpar7days(drop=rc);
	run; 

%mend outpatient_7days;
