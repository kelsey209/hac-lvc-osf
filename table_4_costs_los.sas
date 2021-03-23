*********************************************************************************;
* program name: table_4_costs_los.sas;
* project: hac and lvc;
* description: get comparison of mean los and cost - with and without HAC/PSI;

* covariates: age, sex, Charlson score, and DRG
*********************************************************************************;

/********************************************************************************/

* macro bootie_results
* get bootstrap samples on data;

* service = .;
/********************************************************************************/
%macro bootie_results(service,input_data);

	data boot__temp;
		set &input_data;
		where service in ("&service.");
	run;

	* 1: unique top level IDs;
	proc sort data=boot__temp(keep=prvdr_num) nodupkey out=boot__prvdr_unique;
		by prvdr_num;
	run;

	* 2: sample the clustering factor;
	proc surveyselect data=boot__prvdr_unique 
		seed=28011990
		method=urs 
		samprate=1
		reps=1000
		out=boot__sam_prvdr 
		outhits noprint;
	run;

	proc sort data=BOOT__SAM_PRVDR;
		by replicate prvdr_num;
	run;

	data boot__sam_prvdr;
		set boot__sam_prvdr;
		retain hit;
		by replicate prvdr_num;

		if first.prvdr_num then
			hit = 1;
		else hit = hit+1;
	run;

	* 3: subset on the sampled clustering factors;
	proc sql;
		create table boot__sam_prvdr_pts as 
			select a.replicate,a.prvdr_num,a.hit,b.bene_id
				from boot__sam_prvdr as a 
					left join boot__temp as b 
						on a.prvdr_num = b.prvdr_num;
	quit;

	* 4: 'sample' lower levels (bene_id);
	* this will be sampling *without replacement* on unique patient IDs;
	proc sort data=boot__sam_prvdr_pts nodupkey;
		by replicate prvdr_num hit bene_id;
	run;

	* 5: subset on sampled clustering factors;
	proc sql;
		create table boot__sam_prvdr_pts_obs as 
			select a.replicate,a.prvdr_num,a.hit,a.bene_id,b.service_dt,b.HAC_record,b.PSI_record,b.los,
				b.cost,b.age, b.sex_ident_cd, b.drg_cd
			from boot__sam_prvdr_pts as a 
				left join boot__temp as b 
					on a.prvdr_num = b.prvdr_num and a.bene_id = b.bene_id;
	quit;

	* 6: get result for each variable;
	proc sort data=boot__sam_prvdr_pts_obs;
		by replicate;
	run;

	%results_adjusted(&service,HAC,los);
	%results_adjusted(&service,PSI,los);
	%results_adjusted(&service,HAC,cost);
	%results_adjusted(&service,PSI,cost);

	proc datasets lib=work nolist; 
		delete boot:;
	run; 

%mend bootie_results;

/********************************************************************************/

* macro results_adjusted
* get mean unadjusted and adjusted differences based on bootstrap replicates;

* expl_type = HAC, PSI
* var = los, cost;

/********************************************************************************/
%macro results_adjusted(service,expl_type,var);
	
	proc glm data=boot__sam_prvdr_pts_obs;
	ods output LSMeans=temp__adjusted_&expl_type Means=temp__unadjusted_&expl_type(keep=Replicate Effect &expl_type._record mean_&var);
		class sex_ident_cd drg_cd &expl_type._record;
		model &var = age sex_ident_cd drg_cd &expl_type._record;
		means &expl_type._record;
		lsmeans &expl_type._record;
		by replicate;
	quit;

	** adjusted mean - variable;
	proc transpose data=temp__adjusted_&expl_type(keep=replicate &expl_type._record &var.LSMean) prefix=&expl_type._ out=temp__var;
		by replicate;
		var &var.LSMean;
		id &expl_type._record;
	run;

	data temp__var;
		set temp__var;
		diff_ = &expl_type._1 - &expl_type._0;
	run;

	proc univariate data=temp__var noprint;
		var diff_;
		output out= adj__&var._&expl_type._CI_&service pctlpts=2.5 97.5 pctlpre= pp abspp;
	run;

	data adj__&var._&expl_type._CI_&service; 
		set adj__&var._&expl_type._CI_&service; 
		service = "&service.";
	run;

	** unadjusted mean - variable;
	proc transpose data=temp__unadjusted_&expl_type(keep=replicate &expl_type._record mean_&var) prefix=&expl_type._ out=temp__var;
		by replicate;
		var mean_&var;
		id &expl_type._record;
	run;
	quit;

	data temp__var;
		set temp__var;
		diff_ = &expl_type._1 - &expl_type._0;
	run;

	proc univariate data=temp__var noprint;
		var diff_;
		output out= unadj__&var._&expl_type._CI_&service pctlpts=2.5 97.5 pctlpre= pp abspp;
	run;

	data unadj__&var._&expl_type._CI_&service; 
		set unadj__&var._&expl_type._CI_&service; 
		service = "&service.";
	run;

	proc datasets lib= work nolist; 
		delete temp:;
	run; 

%mend results_adjusted;

/********************************************************************************/
/********************************************************************************/
* macro results_fulltable;
* get adjusted and unadjusted values on full data set (no bootstrapping);
* expl_type = HAC, PSI;
* var = los, cost;
* input_var = tab4__den_xx;
/********************************************************************************/
%macro results_fulltable(expl_type,var,input_data);

	proc glm data=&input_data;
	ods output LSMeans=adjusted_&expl_type Means=unadjusted_&expl_type(keep=service Effect &expl_type._record mean_&var);
		class sex_ident_cd drg_cd &expl_type._record;
		model &var = age sex_ident_cd drg_cd &expl_type._record;
		means &expl_type._record;
		lsmeans &expl_type._record;
		by service;
	quit;

	proc transpose data=adjusted_&expl_type(keep=service &expl_type._record &var.LSMean) prefix=&expl_type._ out=temp__var;
		by service;
		var &var.LSMean;
		id &expl_type._record;
	run;

	data res__adj_&var._&expl_type(keep=service diff_&var.);
		set temp__var;
		diff_&var. = &expl_type._1 - &expl_type._0;
	run;

	** unadjusted mean - variable;
	proc transpose data=unadjusted_&expl_type(keep=service &expl_type._record mean_&var) prefix=&expl_type._ out=temp__var;
		by service;
		var mean_&var;
		id &expl_type._record;
	run;

	data res__unadj_&var._&expl_type(keep=service diff_&var._un);
		set temp__var;
		diff_&var._un = &expl_type._1 - &expl_type._0;
	run;

%mend results_fulltable;

/********************************************************************************/
data input_all; 
	set kch315sl.res__inp_2016
		kch315sl.res__inp_2017
		kch315sl.res__inp_2018;
run; 

data hac_all; 
	set kch315sl.res__inp_hac_2016
		kch315sl.res__inp_hac_2017
		kch315sl.res__inp_hac_2018; 
run; 

data psi_all; 
	set kch315sl.res__inp_psi_2016
		kch315sl.res__inp_hac_2017
		kch315sl.res__inp_hac_2018;
run; 

%let input_data = input_all;
%let hac_data = hac_all;
%let psi_data = psi_all;

/* denominator counts - remove excluded cases */
data tab4__den;
	set &input_data;
	where lowvalue = 1 and exc_coverage = 0 and 
		((service in ('perc','caro') and exc_lookback = 0) or service not in ('perc','caro')) and 
		exc_age = 0 and exc_usa = 0 
		and service = primary;
run;

proc sort data= tab4__den nodupkey out= tab4__den; 
	by service bene_id service_dt; 
run; 

/* select output: length of stay and costs */
proc sort data = tab4__den(keep=bene_id medpar_id) nodupkey out=temp__medpar_unique;
	by bene_id medpar_id;
run;

data temp__medpar_unique;
	if 0 then
		set temp__medpar_unique;

	if _n_ = 1 then
		do;
			declare hash dim1 (dataset:"temp__medpar_unique", ordered: "a",multidata:'yes');
			dim1.definekey ('bene_id','medpar_id');
			dim1.definedata (all:'yes');
			dim1.definedone();
		end;

	do until(eof);
		set medpar.medpar_2016(keep = bene_id medpar_id 
			drg_cd admsn_dt dschrg_dt tot_chrg_amt mdcr_pmt_amt 
			dgns_1_cd--dgns_25_cd poa_dgns_1_ind_cd--poa_dgns_25_ind_cd) 
			medpar.medpar_2017(keep = bene_id medpar_id 
			drg_cd admsn_dt dschrg_dt tot_chrg_amt mdcr_pmt_amt
			dgns_1_cd--dgns_25_cd poa_dgns_1_ind_cd--poa_dgns_25_ind_cd)
			medpar.medpar_2018(keep = bene_id medpar_id 
			drg_cd admsn_dt dschrg_dt tot_chrg_amt mdcr_pmt_amt
			dgns_1_cd--dgns_25_cd poa_dgns_1_ind_cd--poa_dgns_25_ind_cd) end=eof;

		if dim1.find()=0 then
			output;
	end;

	stop;
run;

data temp__medpar_unique;
	set temp__medpar_unique;
	los = dschrg_dt - admsn_dt;

	if los = 0 then
		los = 1;
run;

/* create comorbidity list */
%let input = temp__medpar_unique;
%let output = temp__medpar_unique;

%include "&code_files/comorb_icd10cm_analy_v20211.sas";

/* save mortal_score only */
data temp__medpar_unique;
	set temp__medpar_unique(keep=bene_id medpar_id 
		los drg_cd admsn_dt dschrg_dt tot_chrg_amt mdcr_pmt_amt mortal_score);
run;

proc sort data=tab4__den;
	by bene_id medpar_id;
run;

proc sort data=temp__medpar_unique; 
	by bene_id medpar_id; 
run; 

data tab4__den;
	merge tab4__den temp__medpar_unique;
	by bene_id medpar_id;
run;

proc sort data=tab4__den;
	by service;
run;

/* inspect data */
proc univariate data=tab4__den;
	var los tot_chrg_amt mdcr_pmt_amt;
	by service;
	histogram;
run;

/**********************************************************************************/
* covariates: age and sex;
proc sort data = tab4__den(keep=bene_id) nodupkey out=temp__bene;
	by bene_id;
run;

data temp__bene;
	if 0 then
		set temp__bene;

	if _n_ = 1 then
		do;
			declare hash dim1 (dataset:"temp__bene", ordered: "a");
			dim1.definekey ('bene_id');
			dim1.definedata (all:"yes");
			dim1.definedone();
		end;

	do until(eof);
		set mbsf.mbsf_abcd_2018(keep = bene_id bene_birth_dt sex_ident_cd )
			mbsf.mbsf_abcd_2017(keep = bene_id bene_birth_dt sex_ident_cd )
			mbsf.mbsf_abcd_2016(keep = bene_id bene_birth_dt sex_ident_cd )end=eof;

		if dim1.find()=0 then
			output;
	end;

	stop;
run;

proc sort data=temp__bene nodupkey;
	by bene_id;
run;

proc sort data=tab4__den;
	by bene_id;
run;

data tab4__den;
	merge tab4__den temp__bene;
	by bene_id;
run;

data tab4__den;
	set tab4__den;
	age = %age(bene_birth_dt, service_dt);
run;

/********************************************************************************/
* comparison groups: no hac/psi, psi , hac;
proc sql;
	create table temp__hac as 
		select bene_id,medpar_id,sum(out_hac_numerator) as HACs 
			from &hac_data
				where (out_hac_denominator = 1 or missing(out_hac_denominator)) and medpar_id in (select medpar_id from tab4__den)
					group by bene_id,medpar_id;
quit;

proc sql;
	create table temp__psi as 
		select bene_id,medpar_id,sum(out_psi_numerator) as PSIs 
			from &psi_data
				where out_psi_denominator = 1 and medpar_id in (select medpar_id from tab4__den)
					group by bene_id,medpar_id;
quit;

proc sort data=tab4__den;
	by bene_id medpar_id;
run;

data tab4__den;
	merge tab4__den temp__hac temp__psi;
	by bene_id medpar_id;
run;

data tab4__den;
	set tab4__den;

	if missing(HACs) then
		HACs = 0;

	if missing(PSIs) then
		PSIs = 0;
run;

data tab4__den;
	set tab4__den;
	HAC_record = 0;
	PSI_record = 0;

	if HACs > 0 then
		HAC_record = 1;

	if PSIs > 0 then
		PSI_record = 1;
run;

data tab4__den;
	set tab4__den;

	if los le 0 then
		los = 1;
	log_los = log(los);
run;

/********************************************************************************/
* adjust hospital costs to charges;
data tab4__den;
	set tab4__den;
	dschrg_year = YEAR(dschrg_dt);
run;

data &mylib..gref__ccr;
	set &mylib..gref__ccr(rename=(prvdr_num=prvdr_num_old));
	prvdr_num = put(prvdr_num_old,z6.);
run;

proc sql;
	create table tab4__den_ccr as 
		select a.*, b.CCR, b.CCR_r, b.CCR_s 
			from tab4__den as a 
				left join &mylib..gref__ccr as b 
					on a.prvdr_num = b.prvdr_num and a.dschrg_year = b.year;
quit;

/* number of hospitals with missing CCRs */
proc sort data=tab4__den_ccr(keep=prvdr_num dschrg_year CCR:) nodupkey out=prvdr_table;
	by prvdr_num dschrg_year;
run;

data prvdr_table;
	set prvdr_table;
	missing_CCR = 0;
	missing_CCR_r = 0;

	if missing(CCR) then
		missing_CCR = 1;

	if missing(CCR_r) then
		missing_CCR_r = 1;
run;

title 'Number of providers'; 
proc sql; 
	select count(distinct(prvdr_num)) 
	from prvdr_table; 
quit; 

title 'Number at least one missing CCR'; 
proc sql; 
	select count(distinct(prvdr_num)) 
	from prvdr_table
	where missing(CCR); 
quit; 

title 'Number missing across all years'; 
proc sql noprint; 
	create table prvdr_chk as 
	select prvdr_num, sum(missing(CCR)) as missing, count(distinct(dschrg_year)) as years
	from prvdr_table
	group by prvdr_num; 
quit; 

proc sql; 
	select count(distinct(prvdr_num))
	from prvdr_chk 
	where missing eq years; 
run; 


proc sort data=prvdr_table(keep=prvdr_num) nodupkey out=prvdr_table2; 
	by prvdr_num; 
run; 

data prvdr_table2; 
	set prvdr_table2; 
	type = substr(prvdr_num,3,2);
run; 

proc freq data=prvdr_table2;
	table type; 
run; 


title "Medicare Cost to Charge ratios";

proc freq data=prvdr_table;
	table missing_CCR missing_CCR_r;
run;

data tab4__den_ccr;
	set tab4__den_ccr;
	cost = tot_chrg_amt*CCR_s;
run;

proc sort data=tab4__den_ccr;
	by service;
run;

proc univariate data=tab4__den_ccr;
	class PSI_record;
	var cost;
	histogram cost /nrows=2;
	by service;
run;

proc means data=tab4__den_ccr mean median;
	class PSI_record;
	var cost;
	by service;
run;

/********************************************************************************/
* results;

%results_fulltable(HAC,los,tab4__den_ccr);
%results_fulltable(PSI,los,tab4__den_ccr);

%results_fulltable(HAC,cost,tab4__den_ccr);
%results_fulltable(PSI,cost,tab4__den_ccr);

ods graphics off; 
ods exclude all; 
ods noresults; 

* get confidence intervals for table ; 
%bootie_results(caro,tab4__den_ccr);
%bootie_results(hyst,tab4__den_ccr);
%bootie_results(ivcf,tab4__den_ccr);
%bootie_results(knee,tab4__den_ccr);
%bootie_results(perc,tab4__den_ccr);
%bootie_results(rena,tab4__den_ccr);
%bootie_results(spin,tab4__den_ccr);
%bootie_results(vert,tab4__den_ccr);

ods graphics on; 
ods exclude none; 
ods results; 

** los ; 
data adj__los_hac_ci;
	set adj__los_hac_ci:;
	rename pp2_5=lwr_adj pp97_5=upr_adj;
run; 

data unadj__los_hac_ci;
	set unadj__los_hac_ci:;
	rename pp2_5=lwr pp97_5=upr;
run; 

data res__los_hac; 
	merge res__unadj_los_hac unadj__los_hac_ci res__adj_los_hac adj__los_hac_ci;
	by service; 
run; 

data adj__los_psi_ci;
	set adj__los_psi_ci:;
	rename pp2_5=lwr_adj pp97_5=upr_adj;
run; 

data unadj__los_psi_ci;
	set unadj__los_psi_ci:;
	rename pp2_5=lwr pp97_5=upr;
run; 

data res__los_psi; 
	merge res__unadj_los_psi unadj__los_psi_ci res__adj_los_psi adj__los_psi_ci;
	by service; 
run; 

** cost ; 
data adj__cost_hac_ci;
	set adj__cost_hac_ci:;
	rename pp2_5=lwr_adj pp97_5=upr_adj;
run; 

data unadj__cost_hac_ci;
	set unadj__cost_hac_ci:;
	rename pp2_5=lwr pp97_5=upr;
run; 

data res__cost_hac; 
	merge res__unadj_cost_hac unadj__cost_hac_ci res__adj_cost_hac adj__cost_hac_ci;
	by service; 
run; 

data adj__cost_psi_ci;
	set adj__cost_psi_ci:;
	rename pp2_5=lwr_adj pp97_5=upr_adj;
run; 

data unadj__cost_psi_ci;
	set unadj__cost_psi_ci:;
	rename pp2_5=lwr pp97_5=upr;
run; 

data res__cost_psi; 
	merge res__unadj_cost_psi unadj__cost_psi_ci res__adj_cost_psi adj__cost_psi_ci;
	by service; 
run; 
