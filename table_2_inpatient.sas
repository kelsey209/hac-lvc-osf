*********************************************************************************;
* program name: table_2_inpatient.sas;
* project: hac and lvc;
* description: create counts for inpatient services;
*********************************************************************************;
/***************************************************************************/
* macro: bootie_hospital;
* Ren et al 2010;
* http://biostat.mc.vanderbilt.edu/wiki/Main/HowToBootstrapCorrelatedData;

* create bootstrap samples (sample with replacement) on highest level (prvdr_num)
* then sample without replacement at lower levels;

/***************************************************************************/
%macro bootie_hospital(input_boot,OutVar,service,beddays);

	data boot__temp;
		set &input_boot;
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
		outhits;
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
			select a.replicate,a.prvdr_num,a.hit,a.bene_id,b.los,b.&OutVar
				from boot__sam_prvdr_pts as a 
					left join boot__temp as b 
						on a.prvdr_num = b.prvdr_num and a.bene_id = b.bene_id;
	quit;

	%IF &beddays eq 'true' %THEN
		%DO;
			* 6: get estimate by replicate;
			proc sql;
				create table boot__output as 
					select replicate,prvdr_num,hit,bene_id,sum(los) as LOS,sum(&OutVar) as OutVar
						from boot__sam_prvdr_pts_obs 
							group by replicate,prvdr_num,hit,bene_id;
			quit;

			proc sql;
				create table boot__output2 as 
					select replicate,sum(OutVar)/sum(los)*100 as OutVar
						from boot__output
							group by replicate;
			quit;

			data boot__output2; 
				set boot__output2; 
				if missing(OutVar) then OutVar = 0; 
			run; 

		%END;
	%ELSE
		%DO;
			* 6: get estimate by replicate;
			proc sql;  
				create table boot__output2 as 
				select replicate,count(Replicate) as TotCounts, sum(&OutVar) as OutVar
				from boot__sam_prvdr_pts_obs
				group by replicate; 
			quit; 

			data boot__output2;
				set boot__output2;
				OutVar = OutVar/TotCounts*100;
			run;

			data boot__output2; 
				set boot__output2; 
				if missing(OutVar) then OutVar = 0; 
			run; 

		%END;

	proc univariate data=boot__output2 noprint;
		var OutVar;
		output out= CIs__&service pctlpts=2.5 97.5 pctlpre= pp abspp;
	run;

	data CIs__&service;
		set CIs__&service;
		service = "&service.";
	run;

	proc datasets lib=work nolist;
		delete boot:;
	run;

%mend bootie_hospital;

/***************************************************************************/
/* create inpatient table */
/***************************************************************************/
data tab1__test;
	set kch315sl.res__inp_2016
		kch315sl.res__inp_2017
		kch315sl.res__inp_2018;
run;

data tab2__test;
	set kch315sl.res__inp_hac_2016
		kch315sl.res__inp_hac_2017
		kch315sl.res__inp_hac_2018;
run;

data tab3__test;
	set kch315sl.res__inp_psi_2016
		kch315sl.res__inp_psi_2017
		kch315sl.res__inp_psi_2018;
run;

%let input_data = tab1__test;
%let hac_data = tab2__test;
%let psi_data = tab3__test;

/* denominator counts - remove excluded cases */
data tab2__den;
	set &input_data;
	where lowvalue = 1 and exc_coverage = 0 and 
		((service in ('perc','caro') and exc_lookback = 0) or service not in ('perc','caro')) and 
		exc_age = 0 and exc_usa = 0 
		and service = primary;
run;

proc sort data=tab2__den out=tab2__den nodupkey; 
	by service bene_id service_dt;
run; 

/* column: counts of lowvalue services */
proc sql;
	create table tab2__col1 as 
		select service as Service, sum(lowvalue) as LowValueCounts
			from tab2__den 
				group by service;
quit;

/* get LOS */
proc sort data = tab2__den(keep=bene_id medpar_id) nodupkey out=temp__medpar_unique;
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
			admsn_dt dschrg_dt) 
			medpar.medpar_2017(keep = bene_id medpar_id 
			admsn_dt dschrg_dt)
			medpar.medpar_2018(keep = bene_id medpar_id 
			admsn_dt dschrg_dt) end=eof;

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

proc sort data=tab2__den; 
	by bene_id medpar_id; 
run; 

proc sort data=temp__medpar_unique; 
	by bene_id medpar_id; 
run; 

data tab2__den;
	merge tab2__den temp__medpar_unique;
	by bene_id medpar_id;
run;

* -------------------------------------------------------------------------------------;
/* HACs */
proc sql;
	create table temp__hac as 
		select bene_id,medpar_id,sum(out_hac_numerator) as HACs 
			from &hac_data
				where out_hac_denominator = 1 or missing(out_hac_denominator)
					group by bene_id,medpar_id;
quit;

* join to allowed admissions table;
* bootstrap table;
proc sql;
	create table temp__adm_hac as 
		select a.*, b.HACs 
			from tab2__den as a 
				left join temp__hac as b 
					on a.bene_id=b.bene_id and a.medpar_id=b.medpar_id;
quit;

proc sql;
	create table tab2__col2 as 
		select service,sum(HACs) as HACs_100
			from temp__adm_hac 
				group by service;
quit;

data tab2__col2;
	merge tab2__col2 tab2__col1;
	by service;
run;

data tab2__col2(drop=LowValueCounts);
	set tab2__col2;
	HACs_100 = HACs_100/LowValueCounts*100;
run;

%bootie_hospital(temp__adm_hac,HACs,caro,'false');
%bootie_hospital(temp__adm_hac,HACs,hyst,'false');
%bootie_hospital(temp__adm_hac,HACs,ivcf,'false');
%bootie_hospital(temp__adm_hac,HACs,knee,'false');
%bootie_hospital(temp__adm_hac,HACs,perc,'false');
%bootie_hospital(temp__adm_hac,HACs,rena,'false');
%bootie_hospital(temp__adm_hac,HACs,spin,'false');
%bootie_hospital(temp__adm_hac,HACs,vert,'false');

data tab2__col2_cis;
	set cis__:;
run;

data tab2__col2;
	merge tab2__col2 tab2__col2_cis;
	by service;
run;

data tab2__col2;
	set tab2__col2(rename=(pp2_5=lwr_hac pp97_5=upr_hac));
run;

proc datasets lib=work nolist;
	delete cis__:;
run;

* -------------------------------------------------------------------------------------;
/* column: total HACs per 100 bed days */
proc sql;
	create table tab2__col3 as 
		select service,sum(HACs)/sum(los)*100 as HACs_100_beddays
			from temp__adm_hac 
				group by service;
quit;

%bootie_hospital(temp__adm_hac,HACs,caro,'true');
%bootie_hospital(temp__adm_hac,HACs,hyst,'true');
%bootie_hospital(temp__adm_hac,HACs,ivcf,'true');
%bootie_hospital(temp__adm_hac,HACs,knee,'true');
%bootie_hospital(temp__adm_hac,HACs,perc,'true');
%bootie_hospital(temp__adm_hac,HACs,rena,'true');
%bootie_hospital(temp__adm_hac,HACs,spin,'true');
%bootie_hospital(temp__adm_hac,HACs,vert,'true');

data tab2__col3_cis;
	set cis__:;
run;

data tab2__col3;
	merge tab2__col3 tab2__col3_cis;
	by service;
run;

data tab2__col3;
	set tab2__col3(rename=(pp2_5=lwr_hac_bd pp97_5=upr_hac_bd));
run;

proc datasets lib=work nolist;
	delete cis__:;
run;

* -------------------------------------------------------------------------------------;
/* column: total PSIs per 100 services */
proc sql;
	create table temp__psi as 
		select bene_id,medpar_id,sum(out_psi_numerator) as PSIs 
			from &psi_data
				where out_psi_denominator = 1 
					group by bene_id,medpar_id;
quit;

* join to allowed denominator table;
* bootstrap table;
* inner join: only admissions with at least one psi denominator;
proc sql;
	create table temp__adm_psi as 
		select a.*, b.PSIs
			from tab2__den as a 
				inner join temp__psi as b 
					on a.bene_id=b.bene_id and a.medpar_id=b.medpar_id;
quit;

proc sql;
	create table tab2__col4 as 
		select service,count(distinct(cat(bene_id,service_dt))) as LowValueC, sum(PSIs) as PSIs_100
			from temp__adm_psi 
				group by service;
quit;

data tab2__col4(drop=LowValueC);
	set tab2__col4;
	PSIs_100 = PSIs_100/LowValueC*100;
run;

%bootie_hospital(temp__adm_psi,PSIs,caro,'false');
%bootie_hospital(temp__adm_psi,PSIs,hyst,'false');
%bootie_hospital(temp__adm_psi,PSIs,ivcf,'false');
%bootie_hospital(temp__adm_psi,PSIs,knee,'false');
%bootie_hospital(temp__adm_psi,PSIs,perc,'false');
%bootie_hospital(temp__adm_psi,PSIs,rena,'false');
%bootie_hospital(temp__adm_psi,PSIs,spin,'false');
%bootie_hospital(temp__adm_psi,PSIs,vert,'false');

data tab2__col4_cis;
	set cis__:;
run;

data tab2__col4;
	merge tab2__col4 tab2__col4_cis;
	by service;
run;

data tab2__col4;
	set tab2__col4(rename=(pp2_5=lwr_psi pp97_5=upr_psi));
run;

proc datasets lib=work nolist;
	delete cis__:;
run;

* -------------------------------------------------------------------------------------;
/* column: total PSIs per 100 bed days */
proc sql;
	create table tab2__col5 as 
		select service,sum(PSIs)/sum(los)*100 as PSIs_100_beddays
			from temp__adm_psi 
				group by service;
quit;

%bootie_hospital(temp__adm_psi,PSIs,caro,'true');
%bootie_hospital(temp__adm_psi,PSIs,hyst,'true');
%bootie_hospital(temp__adm_psi,PSIs,ivcf,'true');
%bootie_hospital(temp__adm_psi,PSIs,knee,'true');
%bootie_hospital(temp__adm_psi,PSIs,perc,'true');
%bootie_hospital(temp__adm_psi,PSIs,rena,'true');
%bootie_hospital(temp__adm_psi,PSIs,spin,'true');
%bootie_hospital(temp__adm_psi,PSIs,vert,'true');

data tab2__col5_cis;
	set cis__:;
run;

data tab2__col5;
	merge tab2__col5 tab2__col5_cis;
	by service;
run;

data tab2__col5;
	set tab2__col5(rename=(pp2_5=lwr_psi_bd pp97_5=upr_psi_bd));
run;

proc datasets lib=work nolist;
	delete cis__:;
run;

* -------------------------------------------------------------------------------------;
/* join table for output */
data out_tab2;
	merge tab2__col1-tab2__col5;
	by service;
run;
