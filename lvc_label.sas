*********************************************************************************;
* program name: lvc_label.sas;
* project: hac and lvc;

* kelsey chalmers 2020

* description: creates table with claim (outpatient) or medpar (inpatient) ids for each 
low value service where this was the principal procedure. 
*********************************************************************************;

/*********************************************************************************/

* macro: create_list
* description: this creates lists from the input files for the relevant diagnosis/procedure flags
* input: 
* output: 
service: list of icd10 service codes
icd_include: list of icd10 diagnosis codes to include in lv cases
icd_exclude: list of icd10 diagnosis codes to exclude from lv cases
drg_exclude: list of drg codes to exclude from lv cases
*********************************************************************************/;
%macro create_list;
	/* possible to run this only once, but want to update it if these definitions are edited */
	proc import out = &mylib..gref__lvc_defs 
		datafile = "&code_files/lvc_definitions" 
		dbms =xlsx replace;
		getnames=yes;
	run;

	/* remove empty rows - in case imported from excel */
	data &mylib..gref__lvc_defs;
		set &mylib..gref__lvc_defs;

		if compress(cats(of _all_),'.')=' ' then
			delete;
	run;

	data &mylib..gref__lvc_defs;
		set &mylib..gref__lvc_defs;
		length pre_fmtname $20;
		pre_fmtname = service || '_' || type;
		label = 1;
	run;

	proc sort data =  &mylib..gref__lvc_defs;
		by pre_fmtname;
	run;

	data &mylib..gref__lvc_defs;
		set &mylib..gref__lvc_defs (drop= type rename=(code = start)) end=last;
		fmtname = "$" || pre_fmtname;
		type = 'C';
		output;
		by pre_fmtname;

		if last.pre_fmtname then
			do;
				hlo = 'O';
				label = '';
				output;
			end;

		keep fmtname type start label hlo;
	run;

	proc sort data=&mylib..gref__lvc_defs;
		by fmtname start;
	run;

	proc format lib = &mylib. cntlin=&mylib..gref__lvc_defs;
	run;

%mend create_list;

/*********************************************************************************/
/* age calculation */
* from https://www.lexjansen.com/nesug/nesug01/cc/cc4022.pdf;
/*********************************************************************************/
%macro age (birthday, someday);
	floor( (intck('month', &birthday,
		&someday) - (day(&someday) < min (
		day(&birthday), day (intnx ('month',
		&someday, 1) - 1) ) ) ) /12 )
%mend age;

/*********************************************************************************
 * macro: apply_bene_exclusions
 * description: remove beneficiaries that did not have part a and b coverage in 
the months of a particular time range;
* input: 
input_data: the beneficiary table;: the variable name in the beneficiary table);
*********************************************************************************/
%macro apply_bene_exclusions(input_data,year_input);
	%let previous_year = %sysevalf(&year_input-1);
	%let next_year = %sysevalf(&year_input+1);

	proc sort data = &input_data(keep=bene_id) nodupkey out = bene_record;
		by bene_id;
	run;

	data bene_record_year;
		if 0 then
			set bene_record;

		if _n_ = 1 then
			do;
				declare hash dim1 (dataset:"bene_record", ordered: "a");
				dim1.definekey ('bene_id');
				dim1.definedata (all:"yes");
				dim1.definedone();
			end;

		do until(eof);
			set mbsf.mbsf_abcd_&year_input(keep = bene_id state_code bene_birth_dt bene_death_dt
				mdcr_status_code_01--mdcr_status_code_12 BENE_HI_CVRAGE_TOT_MONS BENE_SMI_CVRAGE_TOT_MONS) end=eof;

			if dim1.find()=0 then
				output;
		end;

		stop;
	run;

	data bene_record_prev;
		if 0 then
			set bene_record;

		if _n_ = 1 then
			do;
				declare hash dim1 (dataset:"bene_record", ordered: "a");
				dim1.definekey ('bene_id');
				dim1.definedata (all:"yes");
				dim1.definedone();
			end;

		do until(eof);
			set mbsf.mbsf_abcd_&previous_year(keep = bene_id mdcr_status_code_12 BENE_HI_CVRAGE_TOT_MONS BENE_SMI_CVRAGE_TOT_MONS) end=eof;

			if dim1.find()=0 then
				output;
		end;

		stop;
	run;

	proc sort data = bene_record_year;
		by bene_id;
	run;

	proc sort data = bene_record_prev;
		by bene_id;
	run;

	%IF &next_year le 2018 %THEN
		%DO;

			data bene_record_next;
				if 0 then
					set bene_record;

				if _n_ = 1 then
					do;
						declare hash dim1 (dataset:"bene_record", ordered: "a");
						dim1.definekey ('bene_id');
						dim1.definedata (all:"yes");
						dim1.definedone();
					end;

				do until(eof);
					set mbsf.mbsf_abcd_&next_year(keep = bene_id bene_death_dt mdcr_status_code_01) end=eof;

					if dim1.find()=0 then
						output;
				end;

				stop;
			run;

			proc sort data = bene_record_next;
				by bene_id;
			run;

			/* join previous december results on */
			data bene_record;
				merge bene_record_year bene_record_prev(rename=(mdcr_status_code_12=prev_dec
					BENE_HI_CVRAGE_TOT_MONS=prev_year_hi_cvrage BENE_SMI_CVRAGE_TOT_MONS=prev_year_smi_cvrage))
					bene_record_next(rename=(bene_death_dt = next_year_death_dt mdcr_status_code_01=next_jan));
				by bene_id;
			run;

		%END;
	%ELSE
		%DO;

			data bene_record;
				merge bene_record_year bene_record_prev(rename=(mdcr_status_code_12=prev_dec
					BENE_HI_CVRAGE_TOT_MONS=prev_year_hi_cvrage BENE_SMI_CVRAGE_TOT_MONS=prev_year_smi_cvrage))
				;
				by bene_id;
			run;

			data bene_record;
				set bene_record;
				next_year_death_dt = .;
				next_jan = .;
			run;

		%END;

	data bene_record;
		set bene_record;

		if not missing(next_year_death_dt) then
			bene_death_dt = next_year_death_dt;
	run;

	/* join to input data */
	data temp_;
		merge &input_data(keep=bene_id service_dt) bene_record;
		by bene_id;
	run;

	data temp_(keep=bene_id service_dt exc:);
		set temp_;

		/* coverage at service date */
		exc_coverage = 0;
		service_mnth = month(service_dt);
		service_yr = year(service_dt);
		array coverage $ mdcr_status_code_01--mdcr_status_code_12;
		service_cvrg = coverage{service_mnth};

		if service_cvrg = '00' then
			exc_coverage = 1;

		/* coverage in next seven days */
		exc_days7 = 0;
		days7_dt = service_dt + 7;
		days7_mnth = month(days7_dt);
		days7_yr = year(days7_dt);

		if days7_yr = &year_input then
			days7_cvrg = coverage{days7_mnth};
		else if days7_yr = &next_year then
			days7_cvrg = next_jan;

		if days7_cvrg = '00' then
			exc_days7 = 1;

		if not missing(bene_death_dt) and bene_death_dt < days7_dt then
			exc_days7 = 1;

		/* for pci and caro - must have had coverage in previous year */
		exc_lookback = 0;

		if prev_year_hi_cvrage ne 12 or prev_year_smi_cvrage ne 12 then
			exc_lookback = 1;

		/* check age at start date */
		exc_age = 0;
		bene_age = %age(bene_birth_dt, service_dt);

		if bene_age < 65 then
			exc_age = 1;

		/* check location */
		exc_usa = 0;

		if state_code in ('40','48','54','55','56','57','58','59','60','61','62','63','97','98','99') then
			exc_usa = 1;
	run;

	proc freq data = temp_;
		table exc:;
	run;

	proc sort data=&input_data;
		by bene_id service_dt;
	run;

	proc sort data=temp_;
		by bene_id service_dt;
	run;

	data &input_data;
		merge &input_data temp_;
		by bene_id service_dt;
	run;

%mend apply_bene_exclusions;

*********************************************************************************;
* emergency codes from previous 14 days of the service date;
* also use icd10 pci codes 14 days from the service date;
* also use icd10 codes for spinal fusion exclusion (+/- 30 days from the service date);
* input: bene_ids and service dates and claim id (column names);
*********************************************************************************;
%macro emergency_lookback(input_data,year_input);
	%let previous_year = %sysevalf(&year_input-1);

	/* do not add vertebroplasty to this lookback. it was only necessary for the three other procedures */ 
	data temp_1(keep=bene_id service_dt);
		set &input_data; 
		where service not in ('vert');
	run; 

	proc sort data = temp_1 out = temp_ nodupkey;
		by bene_id service_dt;
	run;

	/* outpatient revenue table */
	* required for the er revenue centre flags within 14 days;
	data temp_otp_rev;
		if 0 then
			set temp_;

		if _n_ = 1 then
			do;
				declare hash dim1 (dataset:"temp_",ordered: "a",multidata: "yes");
				dim1.definekey ('bene_id');
				dim1.definedata (all:'yes');
				dim1.definedone();
			end;

		do until(eof);
			set %DO_OVER(VALUES=01 02 03 04 05 06 07 08 09 10 11 12,
				PHRASE = rif&year_input..outpatient_revenue_?(keep=bene_id hcpcs_cd rev_cntr rev_cntr_dt) )
				rif&previous_year..outpatient_revenue_12(keep=bene_id hcpcs_cd rev_cntr rev_cntr_dt)
				end=eof;
			rc_prevclm = dim1.find();

			if rc_prevclm = 0 and (rev_cntr in ('0450','0451','0452','0456','0459','0981') or 
				hcpcs_cd in ('99281', '99282', '99283', '99284', '99285')) and 
				0 <= intck('day',rev_cntr_dt,service_dt) <= 14 then
				output;

			do while(rc_prevclm=0);
				rc_prevclm = dim1.find_next();

				if rc_prevclm = 0 and (rev_cntr in ('0450','0451','0452','0456','0459','0981') or 
					hcpcs_cd in ('99281', '99282', '99283', '99284', '99285')) and 
					0 <= intck('day',rev_cntr_dt,service_dt) <= 14 then
					output;
			end;
		end;

		stop;
	run;

	data temp_otp_rev;
		set temp_otp_rev;
		flag_emergency_otp = 1;
	run;

	proc sort data=temp_otp_rev(keep=bene_id service_dt flag_emergency_otp) nodupkey;
		by bene_id service_dt;
	run;

	/* outpatient main table */
	data temp_otp_2;
		if 0 then
			set temp_;

		if _n_ = 1 then
			do;
				declare hash dim1 (dataset:"temp_",ordered: "a",multidata: "yes");
				dim1.definekey ('bene_id');
				dim1.definedata (all:'yes');
				dim1.definedone();
			end;

		do until(eof);
			set %DO_OVER(VALUES=01 02 03 04 05 06 07 08 09 10 11 12,
				PHRASE = rif&year_input..outpatient_claims_?(keep=bene_id clm_from_dt prncpal_dgns_cd icd_dgns_cd1--icd_dgns_cd25 rsn_visit_cd1--rsn_visit_cd3) )
				rif&previous_year..outpatient_claims_12(keep=bene_id clm_from_dt prncpal_dgns_cd icd_dgns_cd1--icd_dgns_cd25 rsn_visit_cd1--rsn_visit_cd3)
				end=eof;
			rc_prevclm = dim1.find();

			if rc_prevclm = 0 and 0 <= intck('day',clm_from_dt,service_dt) <= 30 then
				output;

			do while(rc_prevclm=0);
				rc_prevclm = dim1.find_next();

				if rc_prevclm = 0 and 0 <= intck('day',clm_from_dt,service_dt) <= 30 then
					output;
			end;
		end;
	run;

	data temp_otp_2;
		set temp_otp_2;
		unstable_angina_otp = 0;
		comb_spin_otp = 0;
		day_from_service = intck('day',clm_from_dt,service_dt);
		array diagnoses $ prncpal_dgns_cd icd_dgns_cd1--icd_dgns_cd25 rsn_visit_cd1--rsn_visit_cd3;

		/* look for pci codes within 14 days */
		if 0 <= day_from_service <= 14 then
			do;
				do over diagnoses;
					if put(diagnoses,$perc_icd_exclude.) = 1 then
						unstable_angina_otp = 1;

					if unstable_angina_otp = 1 then
						leave;
				end;
			end;

		/* look for spin exclusions within 30 days */
		do over diagnoses;
			/* count one diagnosis per claim */
			if put(diagnoses,$spin_icd_exclude_cmb.) = 1 then
				comb_spin_otp = 1;
		end;
	run;

	proc sql;
		create table temp_otp_2a as 
			select bene_id, service_dt, max(unstable_angina_otp) as unstable_angina_otp, 
				sum(comb_spin_otp) as comb_spin_otp
			from temp_otp_2 
				group by bene_id, service_dt;
	quit;

	proc sort data=temp_otp_2a;
		by bene_id service_dt;
	run;

	/* carrier table */
	/* get dates within 30 days - hcpcs cd and icd codes */
	data temp_car;
		if 0 then
			set temp_;

		if _n_ = 1 then
			do;
				declare hash dim1 (dataset:"temp_",ordered: "a",multidata:"yes");
				dim1.definekey ('bene_id');
				dim1.definedata (all:'yes');
				dim1.definedone();
			end;

		do until(eof);
			set %DO_OVER(VALUES=01 02 03 04 05 06 07 08 09 10 11 12,
				PHRASE = rif&year_input..bcarrier_line_?(keep=bene_id hcpcs_cd line_1st_expns_dt LINE_ICD_DGNS_CD) )
				rif&previous_year..bcarrier_line_12(keep=bene_id hcpcs_cd line_1st_expns_dt LINE_ICD_DGNS_CD)
				end=eof;
			rc = dim1.find();

			if rc = 0 and 0 <= intck('day',line_1st_expns_dt,service_dt) <= 30 then
				output;

			do while(rc=0);
				rc = dim1.find_next();

				if rc = 0 and 0 <= intck('day',line_1st_expns_dt,service_dt) <= 30 then
					output;
			end;
		end;

		stop;
	run;

	data temp_car;
		set temp_car;
		unstable_angina_car = 0;
		comb_spin_car = 0;
		day_from_service = intck('day',line_1st_expns_dt,service_dt);
		flag_emergency_car = 0;

		if 0 <= day_from_service <= 14 then
			do;
				if hcpsc_cd in ('99281', '99282', '99283', '99284', '99285') then
					flag_emergency_car = 1;

				if put(LINE_ICD_DGNS_CD,$perc_icd_exclude.) = 1 then
					unstable_angina_car = 1;
			end;

		if put(LINE_ICD_DGNS_CD,$spin_icd_exclude_cmb.) = 1 then
			comb_spin_car = 1;

		if flag_emergency_car = 1 or unstable_angina_car = 1 or comb_spin_car = 1 then
			output;
	run;

	proc sql;
		create table temp_car_2 as 
			select bene_id,service_dt,max(flag_emergency_car) as flag_emergency_car, 
				max(unstable_angina_car) as unstable_angina_car, max(comb_spin_car) as comb_spin_car 
			from temp_car 
				group by bene_id, service_dt;
	quit;

	proc sort data=temp_car_2;
		by bene_id service_dt;
	run;

	/* check medpar table */
	data temp_med;
		if 0 then
			set temp_;

		if _n_ = 1 then
			do;
				declare hash dim1 (dataset:"temp_",ordered: "a",multidata:"yes");
				dim1.definekey ('bene_id');
				dim1.definedata (all:"yes");
				dim1.definedone();
			end;

		do until(eof);
			set medpar.medpar_&year_input(keep=bene_id IP_ADMSN_TYPE_CD SRC_IP_ADMSN_CD ER_CHRG_AMT admsn_dt admtg_dgns_cd dgns_1_cd--dgns_25_cd)
				medpar.medpar_&previous_year(keep=bene_id IP_ADMSN_TYPE_CD SRC_IP_ADMSN_CD ER_CHRG_AMT admsn_dt admtg_dgns_cd dgns_1_cd--dgns_25_cd) end=eof;
			rc = dim1.find();

			if rc = 0 and 0 <= intck('day',admsn_dt,service_dt) <= 30 then
				output;

			do while(rc=0);
				rc = dim1.find_next();

				if rc = 0 and 0 <= intck('day',admsn_dt,service_dt) <= 30 then
					output;
			end;
		end;

		stop;
	run;

	data temp_med;
		set temp_med;
		flag_emergency_medpar = 0;
		unstable_angina_medpar = 0;
		comb_spin_medpar = 0;
		day_from_service = intck('day',admsn_dt,service_dt);
		array diagnoses $ admtg_dgns_cd dgns_1_cd--dgns_25_cd;

		if 0 <= day_from_service <= 14 then
			do;
				if (IP_ADMSN_TYPE_CD = '1' or SRC_IP_ADMSN_CD = '7' or ER_CHRG_AMT > 0) then
					flag_emergency_medpar = 1;

				do over diagnoses;
					if put(diagnoses,$perc_icd_exclude.) = 1 then
						unstable_angina_medpar = 1;

					if unstable_angina_medpar = 1 then
						leave;
				end;
			end;

		do over diagnoses;
			if put(diagnoses,$spin_icd_exclude_cmb.) = 1 then
				comb_spin_medpar = 1;

			if comb_spin_medpar = 1 then
				leave;
		end;

		if flag_emergency_medpar = 1 or unstable_angina_medpar = 1 or comb_spin_medpar = 1 then
			output;
	run;

	proc sql;
		create table temp_med_2 as 
			select bene_id, service_dt, max(flag_emergency_medpar) as flag_emergency_medpar, max(unstable_angina_medpar) as unstable_angina_medpar,
				sum(comb_spin_medpar) as comb_spin_medpar 
			from temp_med 
				group by bene_id, service_dt;
	quit;

	proc sort data=temp_med_2;
		by bene_id service_dt;
	run;

	/* join claims together */
	data temp_;
		merge temp_otp_rev temp_otp_2a temp_car_2 temp_med_2;
		by bene_id service_dt;
	run;

	data temp_(keep=bene_id service_dt flag_emergency unstable_angina comb_spin);
		set temp_;
		unstable_angina = 0;
		flag_emergency = 0;
		comb_spin = 0;

		if flag_emergency_medpar = 1 or flag_emergency_otp = 1 or flag_emergency_car = 1 then
			flag_emergency = 1;

		if unstable_angina_medpar = 1 or unstable_angina_otp = 1 or unstable_angina_car = 1 then
			unstable_angina = 1;

		/*if cmiss(of comb_spin:) eq 0; */
		comb_spin_sum = sum(comb_spin_medpar,comb_spin_otp,comb_spin_car);

		if comb_spin_sum ge 2 then
			comb_spin = 1;

		if flag_emergency = 1 or unstable_angina = 1 or comb_spin = 1 then
			output;
	run;

	/* join output on original input table */
	proc sort data=&input_data;
		by bene_id service_dt;
	run;

	data &input_data;
		merge &input_data temp_;
		by bene_id service_dt;
	run;

	data &input_data;
		set &input_data;

		if missing(flag_emergency) then
			flag_emergency = 0;

		if missing(unstable_angina) then
			unstable_angina = 0;

		if missing(comb_spin) then
			comb_spin = 0;
	run;

	/* delete temp datasets */
	proc datasets lib=work nolist;
		delete temp_:;
	run;

%mend emergency_lookback;

*********************************************************************************;
* ccw lookback;
* required for pci and carotid endarterectomy;
*********************************************************************************;
%macro ccw_lookback(input_data,year_input);

	proc sort data= &input_data out=temp_ nodupkey;
		by bene_id;
	run;

	data temp_;
		if 0 then
			set temp_;

		if _n_ = 1 then
			do;
				declare hash dim1(dataset:"temp_", ordered: "a");
				dim1.definekey ('bene_id');
				dim1.definedata (all:"yes");
				dim1.definedone();
			end;

		do until(eof);
			set mbsf.mbsf_cc_&year_input(keep=bene_id ischemicheart_ever stroke_tia_ever OSTEOPOROSIS_EVER) end=eof;

			if dim1.find()=0 then
				output;
		end;

		stop;
	run;

	/* join back on to outpatient codes */
	proc sort data= &input_data;
		by bene_id;
	run;

	data &input_data;
		merge &input_data temp_;
		by bene_id;
	run;

%mend ccw_lookback;

*********************************************************************************;
* macro: service_outpatient;
* find service and low-value codes from outpatient claims;
** note each year has claims split across 12 months;

** the following services have cpt codes: caro hyst ivcf knee perc rena spin vert
*********************************************************************************;
%macro service_outpatient(year_input);
	%DO i=1 %TO 12;
		%let month = %sysfunc(putn(&i,z2.));

		/* 1-------- get visits with service recorded in icd data */
		data res__service_out(drop=icd_prcdr_cd1-icd_prcdr_cd25);
			set rif&year_input..outpatient_claims_&month(
				keep = bene_id clm_id clm_from_dt 
				icd_prcdr_cd1-icd_prcdr_cd25
				clm_from_dt);

			%DO_OVER(VALUES = caro hyst ivcf knee perc rena spin vert,
				PHRASE = ? = 0;)

				array procedures $ icd_prcdr_cd1-icd_prcdr_cd25;

			do over procedures;
				%DO_OVER(VALUES = caro hyst ivcf knee perc rena spin vert,
					PHRASE = if put(procedures,$?_icd_service.) = 1  then ? = 1; )
			end;

			if %DO_OVER(VALUES = caro hyst ivcf knee perc rena spin, PHRASE = ? = 1 or ) vert = 1 then
				output;
		run;

		proc sort data = res__service_out;
			by bene_id clm_id clm_from_dt;
		run;

		proc transpose data = res__service_out out = res__service_out(where=(col1=1)) name = service;
			by bene_id clm_id clm_from_dt;
		run;

		/* 1a-------- get outpatient claims with service recorded in hcpcs codes */
		data res__service_out_rev (drop=hcpcs_cd);
			set rif&year_input..outpatient_revenue_&month(keep=
				bene_id clm_id rev_cntr_dt hcpcs_cd);

			/* cpt code */
			%DO_OVER(values = caro hyst ivcf knee perc rena spin vert, PHRASE = ? = 0;)
			%DO_OVER(values = caro hyst ivcf knee perc rena spin vert, PHRASE = if put(hcpcs_cd,$?_cpt_service.) = 1  then ? = 1;)

			if %DO_OVER(values = caro hyst ivcf knee perc rena spin, PHRASE = ? = 1 or ) vert = 1 then output;
		run;

		proc sort data = res__service_out_rev nodupkey;
			by _all_;
		run;

		proc transpose data = res__service_out_rev out = res__service_out_rev(where=(col1=1)) name = service;
			by bene_id clm_id rev_cntr_dt;
		run;

		/* join outpatient claims with hcpcs code and original outpatient claims */
		proc sort data = res__service_out_rev(drop=col1);
			by bene_id clm_id service;
		run;

		proc sort data = res__service_out(drop=col1);
			by bene_id clm_id service;
		run;

		data res__otp_&month;
			merge res__service_out
				res__service_out_rev;
			by bene_id clm_id service;
		run;

		/* set service_date */
		data res__otp_&month;
			set res__otp_&month;
			format service_dt date9.;

			if missing(rev_cntr_dt) then
				service_dt = clm_from_dt;
			else service_dt = rev_cntr_dt;
		run;

		/* remove clm variables */
		proc sort data=res__otp_&month(drop=clm_from_dt rev_cntr_dt) out= res__otp_&month nodupkey;
			by bene_id clm_id service service_dt;
		run;

		proc datasets library= work nolist;
			delete res__service_out res__service_out_rev;
		run;

		/* get diagnosis codes */
		data res__otp_&month;
			set res__otp_&month;

			if _n_ = 1 then
				do;
					declare hash dim1 (dataset:"res__otp_&month", ordered: "a");
					dim1.definekey ('bene_id','clm_id');
					dim1.definedata (all:'yes');
					dim1.definedone();
				end;

			do until(eof);
				set rif&year_input..outpatient_claims_&month(keep = bene_id clm_id prvdr_num
					prncpal_dgns_cd icd_dgns_cd1--icd_dgns_cd25 rsn_visit_cd1--rsn_visit_cd3) end=eof;

				* inner join - only keep if there is a matching value;
				if dim1.find()=0 then
					output;
			end;
		run;

	%END;

	/* combine all months into one table */
	data res__otp;
		set %DO_OVER(VALUES = 01 02 03 04 05 06 07 08 09 10 11 12, PHRASE = res__otp_?);
	run;

	proc datasets lib= work nolist;
		delete %DO_OVER(VALUES = 01 02 03 04 05 06 07 08 09 10 11 12, PHRASE = res__otp_?);
	run;

	/* 2a ------------ PCI and CEA and SPIN specific labels */
	data input_pci (keep=bene_id clm_id service_dt service);
		set res__otp;
		where service in ('perc','caro','spin','vert');
	run;

	/* get CCW values */
	%ccw_lookback(input_pci,&year_input);

	/* find er lookback - 14 days */
	%emergency_lookback(input_pci,&year_input);

	proc sort data=res__otp;
		by bene_id service_dt service;
	run;

	data res__otp;
		merge res__otp input_pci;
		by bene_id service_dt service;
	run;

	/* 2-------- apply diagnosis rules */
	data res__otp;
		set res__otp;
		lowvalue = 0;

		%DO_OVER(VALUES = caro hyst ivcf knee perc rena spin vert,
			PHRASE = ?_incl_lowvalue = 0; ?_excl_lowvalue = 0;)
			vert_include_ccw = 0; 

			array diagnoses $ prncpal_dgns_cd icd_dgns_cd1-icd_dgns_cd25 rsn_visit_cd1-rsn_visit_cd3;

		do over diagnoses;
			%DO_OVER(VALUES = knee vert rena,
				PHRASE = 
				if put(diagnoses,$?_icd_include.) = 1 then ?_incl_lowvalue = 1;
					)

				%DO_OVER(VALUES = hyst spin caro rena vert,
				PHRASE = 
				if put(diagnoses,$?_icd_exclude.) = 1 then ?_excl_lowvalue = 1;
					)

			if put(diagnoses,$vert_icd_include_ccw.) = 1 then vert_include_ccw = 1; 

		end;

		/* ~~~~~~~~~~ Vertebroplasty ~~~~~~~~~~~~~~~~~ */
		prior_osteo = intck('day',OSTEOPOROSIS_EVER,service_dt);
		
		* update to include vertebroplasty IF there is an osteoporosis flag and a fracture not specific to osteo; 
		if prior_osteo >= 0 and not missing(OSTEOPOROSIS_EVER) and vert_include_ccw = 1 then 
			vert_incl_lowvalue = 1; 
		
		/* ~~~~~~~~~~ PCI ~~~~~~~~~~~~~~~~~ */
		/* ischemic heart disease is at least 6 months before the admission date */
		prior_ischemic = intck('day',ischemicheart_ever,service_dt);

		if prior_ischemic >= 180 and not missing(ischemicheart_ever) then
			perc_incl_lowvalue = 1;

		/* unstable angina in previous 2 weeks */
		if unstable_angina = 1 then
			perc_excl_lowvalue = 1;

		/* emergency department */
		if flag_emergency = 1 then
			perc_excl_lowvalue = 1;

		/* ~~~~~~~~~~ CEA ~~~~~~~~~~~~~~~~~ */
		prior_stroke = intck('day',stroke_tia_ever,service_dt);

		if prior_stroke >= 0 then
			caro_excl_lowvalue = 1;

		/* emergency department */
		if flag_emergency = 1 then
			caro_excl_lowvalue = 1;

		/* ~~~~~~~~~~ SPIN ~~~~~~~~~~~~~~~~~ */
		if comb_spin = 1 then
			spin_excl_lowvalue = 1;

		/************************************************************/
		/* label low value cases */
		/************************************************************/
		/* hysterectomy */
		if service = 'hyst' and hyst_excl_lowvalue = 0 then
			lowvalue = 1;

		/* spinal fusion */
		if service = 'spin' and spin_excl_lowvalue = 0 then
			lowvalue = 1;

		/* carotid endarterectomy */
		if service = 'caro' and caro_excl_lowvalue = 0 then
			lowvalue = 1;

		/* knee arthroscopy */
		if service = 'knee' and knee_incl_lowvalue = 1 then
			lowvalue = 1;

		/* vertebroplasty */
		if service = 'vert' and vert_incl_lowvalue = 1 and vert_excl_lowvalue = 0 then
			lowvalue = 1;

		/* inferior vena caval filter */
		if service = 'ivcf' then
			lowvalue = 1;

		/* renal stenting */
		if service = 'rena' and rena_incl_lowvalue = 1 and rena_excl_lowvalue = 0 then
			lowvalue = 1;

		/* percutaneous coronary interventions */
		if service = 'perc' and perc_incl_lowvalue = 1 and perc_excl_lowvalue = 0 then
			lowvalue = 1;
	run;

	proc sql;
		select service as Service, lowvalue, count(distinct bene_id) as Beneficiaries, count(distinct clm_id) as Claims
			from res__otp 
				group by service, lowvalue;
	quit;

	data &mylib..res__otp_&year_input(keep=bene_id clm_id prvdr_num service_dt service lowvalue);
		set res__otp;
	run;

%MEND service_outpatient;

*********************************************************************************;
* macro: service_medpar;

* find service and low-value codes from medpar inpatient
*********************************************************************************;
%macro service_medpar(year_input=);
	/* 1-------- get admissions with service recorded */
	data res__inp(drop=srgcl_prcdr_1_cd--srgcl_prcdr_25_cd 
		srgcl_prcdr_prfrm_1_dt--srgcl_prcdr_prfrm_25_dt 
		nch_clm_type_cd dschrg_dt);
		set medpar.medpar_&year_input(
			keep = bene_id medpar_id prvdr_num admsn_dt dschrg_dt
			srgcl_prcdr_1_cd--srgcl_prcdr_25_cd 
			srgcl_prcdr_prfrm_1_dt--srgcl_prcdr_prfrm_25_dt 
			nch_clm_type_cd pps_ind_cd
			where = (dschrg_dt <= "31dec2018"d and 
			nch_clm_type_cd in ('60','61') and 
			pps_ind_cd in ('2'))
			);

		%DO_OVER(VALUES = caro hyst ivcf knee perc rena spin vert,
			PHRASE = ? = 0;)

			%DO_OVER(values = caro hyst ivcf knee perc rena spin vert, 
			PHRASE = format service_dt_? date9.;)

			array procedures {25} $ srgcl_prcdr_1_cd--srgcl_prcdr_25_cd;
		array procedure_dt {25} srgcl_prcdr_prfrm_1_dt--srgcl_prcdr_prfrm_25_dt;

		do i = 1 to 25;
			%DO_OVER(VALUES = caro hyst ivcf knee perc rena spin vert,
				PHRASE = if put(procedures[i],$?_icd_service.) = 1  then do;
				? = 1;
				if missing(service_dt_?) then service_dt_? = procedure_dt[i];
		end;
				)
				end;

		/* if the service date is missing then replace with the admission date */
		%DO_OVER(VALUES = caro hyst ivcf knee perc rena spin vert,
			PHRASE = if ? = 1 and missing(service_dt_?) then service_dt_? = admsn_dt;)

			if %DO_OVER(VALUES = caro hyst ivcf knee perc rena spin, PHRASE = ? = 1 or ) vert = 1 then
				output;
	run;

	proc sort data = res__inp nodupkey;
		by _all_;
	run;

	proc transpose data = res__inp(drop= service_dt:) out = res__inp_service(where=(col1=1)) name = service;
		by bene_id medpar_id;
	run;

	proc sort data =  res__inp_service(drop=_label_ col1) nodupkey;
		by bene_id medpar_id service;
	run;

	proc transpose data = res__inp out = res__inp_dates(where=(not missing(col1))) name = service_dt;
		by bene_id medpar_id;
		var service_dt:;
	run;

	data res__inp_dates;
		set res__inp_dates;
		format service $4.;
		service = substr(service_dt,length(service_dt)-3,4);
	run;

	data res__inp_dates;
		set res__inp_dates(drop=service_dt);
		rename col1=service_dt;
	run;

	proc sort data =  res__inp_dates nodupkey;
		by bene_id medpar_id service;
	run;

	data res__inp;
		merge res__inp_service res__inp_dates;
		by bene_id medpar_id service;
	run;

	/* 2 -------- get previous history info for PCI and CEA and SPIN */
	data input_pci;
		set res__inp;
		where service in ('perc','caro','spin','vert');
	run;

	%ccw_lookback(input_pci,&year_input);

	/* 2a ------- get er for PCI and CEA */
	%emergency_lookback(input_pci,&year_input);

	proc sort data=input_pci;
		by bene_id medpar_id service;
	run;

	data res__inp;
		merge res__inp input_pci;
		by bene_id medpar_id service;
	run;

	/* 3 -------- apply diagnosis rules */
	/* 3a -------- get diagnoses */
	proc sort data=res__inp(keep=bene_id medpar_id) out=temp_ nodupkey;
		by bene_id medpar_id;
	run;

	data res__claims;
		set temp_;

		if _n_ = 1 then
			do;
				declare hash dim1 (dataset:"temp_", ordered: "a");
				dim1.definekey ('bene_id','medpar_id');
				dim1.definedata (all:'yes');
				dim1.definedone();
			end;

		do until(eof);
			set medpar.medpar_&year_input(keep = bene_id medpar_id prvdr_num
				admtg_dgns_cd dgns_1_cd--dgns_25_cd drg_cd ) end=eof;

			if dim1.find()=0 then
				output;
		end;
	run;

	data res__claims(drop=admtg_dgns_cd dgns_1_cd--dgns_25_cd drg_cd);
		set res__claims;

		%DO_OVER(VALUES = caro hyst ivcf knee perc rena spin vert,
			PHRASE = ?_incl_lowvalue = 0; ?_excl_lowvalue = 0;)

			vert_include_ccw = 0; 

			array diagnoses $ admtg_dgns_cd dgns_1_cd--dgns_25_cd;

		do over diagnoses;
			%DO_OVER(VALUES = knee vert rena,
				PHRASE = 
				if put(diagnoses,$?_icd_include.) = 1 then ?_incl_lowvalue = 1;
					)
				%DO_OVER(VALUES = hyst spin caro rena vert,
				PHRASE = 
				if put(diagnoses,$?_icd_exclude.) = 1 then ?_excl_lowvalue = 1;
					)

				if put(diagnoses,$vert_icd_include_ccw.) = 1 then vert_include_ccw = 1; 
		end;

		/* ~~~~~~~~~~ hyst ~~~~~~~~~~~~~~~~~ */
		if put(drg_cd,$hyst_drg_exclude.) = 1 then
			hyst_excl_lowvalue = 1;

		/* ~~~~~~~~~~ spin ~~~~~~~~~~~~~~~~~ */
		if put(drg_cd,$spin_drg_service.) = 1 then
			spin_incl_lowvalue = 1;
	run;

	data res__inp;
		merge res__inp res__claims;
		by bene_id medpar_id;
	run;

	data res__inp;
		*(keep= bene_id medpar_id prvdr_num service_dt service lowvalue);
		set res__inp;
		lowvalue = 0;

		/* ~~~~~~~~~~ Vertebroplasty ~~~~~~~~~~~~~~~~~ */
		prior_osteo = intck('day',OSTEOPOROSIS_EVER,service_dt);
		
		* update to include vertebroplasty IF there is an osteoporosis flag and a fracture not specific to osteo; 
		if prior_osteo >= 0 and not missing(OSTEOPOROSIS_EVER) and vert_include_ccw = 1 then 
			vert_incl_lowvalue = 1; 

		/* ~~~~~~~~~~ PCI ~~~~~~~~~~~~~~~~~ */
		/* ischemic heart disease is at least 6 months before the admission date */
		prior_ischemic = intck('day',ischemicheart_ever,service_dt);

		if prior_ischemic >= 180 and not missing(ischemicheart_ever) then
			perc_incl_lowvalue = 1;

		/* unstable angina in previous 2 weeks */
		if unstable_angina = 1 then
			perc_excl_lowvalue = 1;

		/* ~~~~~~~~~~ CEA ~~~~~~~~~~~~~~~~~ */
		prior_stroke = intck('day',stroke_tia_ever,service_dt);

		if prior_stroke >= 0 then
			caro_excl_lowvalue = 1;

		/* emergency department */
		if flag_emergency = 1 then
			do;
				caro_excl_lowvalue = 1;
				perc_excl_lowvalue = 1;
			end;

		/* ~~~~~~~~~~ spin ~~~~~~~~~~~~~~~~~ */
		if comb_spin = 1 then
			spin_excl_lowvalue = 1;

		/************************************************************/
		/* label low value cases */
		/************************************************************/
		/* hysterectomy */
		if service = 'hyst' and hyst_excl_lowvalue = 0 then
			lowvalue = 1;

		/* spinal fusion */
		if service = 'spin' and spin_incl_lowvalue = 1 and spin_excl_lowvalue = 0 then
			lowvalue = 1;

		/* carotid endarterectomy */
		if service = 'caro' and caro_excl_lowvalue = 0 then
			lowvalue = 1;

		/* knee arthroscopy */
		if service = 'knee' and knee_incl_lowvalue = 1 then
			lowvalue = 1;

		/* vertebroplasty */
		if service = 'vert' and vert_incl_lowvalue = 1 and vert_excl_lowvalue = 0 then
			lowvalue = 1;

		/* inferior vena caval filter */
		if service = 'ivcf' then
			lowvalue = 1;

		/* renal stenting */
		if service = 'rena' and rena_incl_lowvalue = 1 and rena_excl_lowvalue = 0 then
			lowvalue = 1;

		/* percutaneous coronary interventions */
		if service = 'perc' and perc_incl_lowvalue = 1 and perc_excl_lowvalue = 0 then
			lowvalue = 1;
	run;

	proc sql;
		select service as Service, lowvalue, count(distinct bene_id) as Beneficiaries, count(distinct medpar_id) as Claims
			from res__inp 
				group by service, lowvalue;
	quit;

	data &mylib..res__inp_&year_input;
		set res__inp;
	run;

%mend service_medpar;
