*********************************************************************************;
* program name: table_3_psi.sas;
* project: hac and lvc;
* description: get individual counts for psi rates and confidence intervals;
*********************************************************************************;
/***************************************************************************/
* macro: bootie_psi;
* Ren et al 2010;
* http://biostat.mc.vanderbilt.edu/wiki/Main/HowToBootstrapCorrelatedData;

* create bootstrap samples (sample with replacement) on highest level (prvdr_num)
* then sample without replacement at lower levels;

/***************************************************************************/
%macro bootie_psi(service);

	data boot__temp;
		set temp__psi;
		where service in ("&service.");
	run;

	* 1: unique top level IDs;
	proc sort data=boot__temp(keep=prvdr_num) nodupkey out=boot__prvdr_unique;
		by prvdr_num;
	run;

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
			select a.replicate,a.prvdr_num,a.hit,b.bene_id,b.service_dt,b.medpar_id 
				from boot__sam_prvdr as a 
					left join boot__temp as b 
						on a.prvdr_num = b.prvdr_num;
	quit;

	* 4: 'sample' lower levels (bene_id);
	* this will be sampling *without replacement* on unique patient IDs;
	proc sort data=boot__sam_prvdr_pts nodupkey;
		by replicate prvdr_num hit bene_id ;
	run;

	* 5: subset on sampled clustering factors;
	proc sql;
		create table boot__sam_prvdr_pts_obs as 
			select a.replicate,a.prvdr_num,a.hit,a.bene_id,
				b.service_dt,b.psi_name,b.out_psi_denominator,b.out_psi_numerator
			from boot__sam_prvdr_pts as a 
				left join boot__temp as b 
					on a.prvdr_num = b.prvdr_num and a.bene_id = b.bene_id;
	quit;

	* 6: get estimate by replicate;
	proc sql;
		create table boot__output as 
			select replicate,psi_name,count(distinct(cat(bene_id,service_dt))) as PSI_den
				from boot__sam_prvdr_pts_obs 
					where out_psi_denominator = 1
						group by replicate,psi_name;
	quit;

	proc sql;
		create table boot__output2 as 
			select replicate,psi_name,count(distinct(cat(bene_id,service_dt))) as PSI_num
				from boot__sam_prvdr_pts_obs 
					where out_psi_denominator = 1 and out_psi_numerator = 1
						group by replicate,psi_name;
	quit;

	data boot__output;
		merge boot__output boot__output2;
		by replicate psi_name;
	run;

	data boot__output;
		set boot__output;

		if missing(psi_num) then
			psi_num = 0;
	run;

	data boot__output;
		set boot__output;
		psi_rate = psi_num/psi_den*100;
	run;

	proc sort data=boot__output;
		by psi_name;
	run;

	proc univariate data=boot__output noprint;
		var psi_rate;
		by psi_name;
		output out=CIs__&service pctlpts=2.5 97.5 pctlpre= pp abspp;
	run;

	data CIs__&service;
		set CIs__&service;
		service = "&service.";
	run;

	proc datasets lib=work nolist;
		delete boot:;
	run;

%mend bootie_psi;

%macro bootie_hac(service);

	data boot__temp;
		set temp__hac;
		where service in ("&service.");
	run;

	* 1: unique top level IDs;
	proc sort data=boot__temp(keep=prvdr_num) nodupkey out=boot__prvdr_unique;
		by prvdr_num;
	run;

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
		by replicate prvdr_num hit bene_id ;
	run;

	* 5: subset on sampled clustering factors;
	proc sql;
		create table boot__sam_prvdr_pts_obs as 
			select a.replicate,a.prvdr_num,a.hit,a.bene_id,b.service_dt,
				b.hac_name,b.out_hac_denominator,b.out_hac_numerator
			from boot__sam_prvdr_pts as a 
				left join boot__temp as b 
					on a.prvdr_num = b.prvdr_num and a.bene_id = b.bene_id;
	quit;

	* 6: get estimate by replicate;
	proc sql;
		create table boot__output as 
			select replicate,hac_name,count(distinct(cat(bene_id,service_dt))) as HAC_den
				from boot__sam_prvdr_pts_obs 
					where (out_hac_denominator = 1 or missing(out_hac_denominator))
						group by replicate,hac_name;
	quit;

	proc sql;
		create table boot__output2 as 
			select replicate,hac_name,count(distinct(cat(bene_id,service_dt))) as HAC_num
				from boot__sam_prvdr_pts_obs 
					where (out_hac_denominator = 1 or missing(out_hac_denominator)) and out_hac_numerator = 1
						group by replicate,hac_name;
	quit;

	data boot__output;
		merge boot__output boot__output2;
		by replicate hac_name;
	run;

	data boot__output;
		set boot__output;

		if missing(hac_num) then
			hac_num = 0;
	run;

	data boot__output;
		set boot__output;
		hac_rate = hac_num/hac_den*100;
	run;

	proc sort data=boot__output;
		by hac_name;
	run;

	proc univariate data=boot__output noprint;
		var hac_rate;
		by hac_name;
		output out=HAC_CIs__&service pctlpts=2.5 97.5 pctlpre= pp abspp;
	run;

	data HAC_CIs__&service;
		set HAC_CIs__&service;
		service = "&service.";
	run;

	proc datasets lib=work nolist;
		delete boot:;
	run;

%mend bootie_hac;

/****************************************************************/
data tab1__test;
	set kch315sl.res__inp_2016
		kch315sl.res__inp_2017 
		kch315sl.res__inp_2018;
run;

data tab2__test;
	set kch315sl.res__inp_psi_2016
		kch315sl.res__inp_psi_2017 
		kch315sl.res__inp_psi_2018;
run;

data tab3__test; 
	set kch315sl.res__inp_hac_2016
		kch315sl.res__inp_hac_2017 
		kch315sl.res__inp_hac_2018;
run; 

%let input_data = tab1__test;
%let psi_data = tab2__test;
%let hac_data = tab3__test; 

/* denominator counts - remove excluded cases */
data tab3__den;
	set &input_data;
	where lowvalue = 1 and exc_coverage = 0 and
		((service in ('perc','caro') and exc_lookback = 0) or service not in ('perc','caro')) and 
		exc_age = 0 and exc_usa = 0 
		and service = primary;
run;

proc sort data=tab3__den out=tab3__den nodupkey; 
	by service bene_id service_dt; 
run; 

/* psi data */
proc sql;
	create table temp__psi as 
		select a.service,a.bene_id,a.service_dt,a.medpar_id,a.prvdr_num,b.psi_name,
			b.out_psi_denominator,b.out_psi_numerator
		from tab3__den as a 
			left join &psi_data as b
				on a.bene_id = b.bene_id and a.medpar_id = b.medpar_id;
quit;

/* hac data */ 
proc sql;
	create table temp__hac as 
		select a.service,a.bene_id,a.service_dt,a.medpar_id,a.prvdr_num,b.hac_name,
			b.out_hac_denominator,b.out_hac_numerator
		from tab3__den as a 
			left join &hac_data as b
				on a.bene_id = b.bene_id and a.medpar_id = b.medpar_id;
quit;

/* count all services */
proc sql;
	create table res__all as 
		select service,count(distinct(cat(bene_id,service_dt))) as Eps_all
			from tab3__den 
				group by service;
quit;

/* count denominators by service */
proc sql;
	create table res__psi_denom as 
		select service,psi_name,count(distinct(cat(bene_id,service_dt))) as Eps_psi_den
			from temp__psi 
				where out_psi_denominator = 1
					group by service,psi_name;
quit;

proc sql; 
	create table res__hac_denom as 
		select service,hac_name,count(distinct(cat(bene_id,service_dt))) as Eps_hac_den
			from temp__hac 
				where out_hac_denominator = 1 or missing(out_hac_denominator)
					group by service,hac_name;
quit;

data res__table;
	merge res__all res__psi_denom;
	by service;
run;

data res__table_hac; 
	merge res__all res__hac_denom; 
	by service; 
run; 

/* count numerators by service */
proc sql;
	create table res__psi_numer as 
		select service,psi_name,count(distinct(cat(bene_id,service_dt))) as Eps_psi_num
			from temp__psi 
				where out_psi_denominator = 1 and out_psi_numerator = 1
					group by service,psi_name;
quit;

proc sql;
	create table res__hac_numer as 
		select service,hac_name,count(distinct(cat(bene_id,service_dt))) as Eps_hac_num
			from temp__hac 
				where (out_hac_denominator = 1 or missing(out_hac_denominator)) and out_hac_numerator = 1
					group by service,hac_name;
quit;

data res__table;
	merge res__table res__psi_numer;
	by service psi_name;
run;

data res__table_hac; 
	merge res__table_hac res__hac_numer; 
	by service hac_name; 
run; 

data res__table;
	set res__table;

	if missing(Eps_psi_num) then
		Eps_psi_num = 0;
run;

data res__table_hac; 
	set res__table_hac; 
	if missing(Eps_hac_num) then 
		Eps_hac_num = 0; 
run; 

data res__table;
	set res__table;
	psi_rate = Eps_psi_num/Eps_psi_den*100;
run;

data res__table_hac; 
	set res__table_hac; 
	hac_rate = Eps_hac_num/Eps_hac_den*100; 
run; 

/* confidence intervals */
%bootie_psi(caro);
%bootie_psi(hyst);
%bootie_psi(ivcf);
%bootie_psi(knee);
%bootie_psi(perc);
%bootie_psi(rena);
%bootie_psi(spin);
%bootie_psi(vert);

%bootie_hac(caro);
%bootie_hac(hyst);
%bootie_hac(ivcf);
%bootie_hac(knee);
%bootie_hac(perc);
%bootie_hac(rena);
%bootie_hac(spin);
%bootie_hac(vert);

data res__table_cis;
	set cis__:;
run;

data res__table_hac_cis; 
	set HAC_cis__:; 
run; 

data res__table;
	merge res__table res__table_cis;
	by service psi_name;
run;

data res__table_hac; 
	merge res__table_hac res__table_hac_cis; 
	by service hac_name; 
run; 

data res__table;
	set res__table(rename=(pp2_5=lwr_rt pp97_5=upr_rt));
run;

data res__table_hac; 
	set res__table_hac(rename=(pp2_5=lwr_rt pp97_5=upr_rt));
run; 

