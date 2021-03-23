*********************************************************************************;
* program name: table_1_outpatient.sas;
* project: hac and lvc;
* description: create counts for outpatient services;
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
			select a.replicate,a.prvdr_num,a.hit,a.bene_id,b.&OutVar
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
/* create outpatient table */
/***************************************************************************/
data tab1__test;
	set kch315sl.res__otp_2016
		kch315sl.res__otp_2017
		kch315sl.res__otp_2018;
run;

data tab2__test;
	set kch315sl.res__otp_medpar7_2016
		kch315sl.res__otp_medpar7_2017
		kch315sl.res__otp_medpar7_2018;
run;

data tab3__test;
	set kch315sl.res__otp_med_hac_2016
		kch315sl.res__otp_med_hac_2017
		kch315sl.res__otp_med_hac_2018;
run;

data tab4__test;
	set kch315sl.res__otp_med_psi_2016
		kch315sl.res__otp_med_psi_2017
		kch315sl.res__otp_med_psi_2018;
run;

%let input_data = tab1__test;
%let adm_data = tab2__test;
%let hac_data = tab3__test;
%let psi_data = tab4__test;

/* denominator counts - remove excluded cases */
data tab1__den;
	set &input_data;
	where lowvalue = 1 and exc_coverage = 0 and exc_days7 = 0 and 
		((service in ('perc','caro') and exc_lookback = 0) or service not in ('perc','caro'))and 
		exc_age = 0 and exc_usa = 0;
run;

proc sort data=tab1__den out=tab1__den nodupkey; 
	by service bene_id service_dt;
run; 

/* column: counts of lowvalue services */
proc sql;
	create table tab1__col1 as 
		select service as Service, count(distinct cat(bene_id,service_dt)) as LowValueCounts
			from tab1__den 
				group by service;
quit;

/* column: counts of unplanned admissions in 7 days */
proc sql;
	create table tab1__col2 as 
		select service as Service, sum(out_7days_unplanned_no) as Unplanned7days
			from tab1__den 
				group by service;
quit;

data tab1__col2;
	merge tab1__col1 tab1__col2;
	by service;
run;

data tab1__col2(drop=LowValueCounts);
	set tab1__col2;
	Unplanned7days_100 = Unplanned7days/LowValueCounts*100;
run;

* get bootstrap counts and CI of unplanned admissions in 7 days;
%bootie_hospital(tab1__den,out_7days_unplanned_no,caro,'false');
%bootie_hospital(tab1__den,out_7days_unplanned_no,hyst,'false');
%bootie_hospital(tab1__den,out_7days_unplanned_no,ivcf,'false');
%bootie_hospital(tab1__den,out_7days_unplanned_no,knee,'false');
%bootie_hospital(tab1__den,out_7days_unplanned_no,perc,'false');
%bootie_hospital(tab1__den,out_7days_unplanned_no,rena,'false');
%bootie_hospital(tab1__den,out_7days_unplanned_no,spin,'false');
%bootie_hospital(tab1__den,out_7days_unplanned_no,vert,'false');

data tab1__col2_cis;
	set cis__:;
run;

data tab1__col2;
	merge tab1__col2 tab1__col2_cis;
	by service;
run;

data tab1__col2;
	set tab1__col2(rename=(pp2_5=lwr_unp pp97_5=upr_unp));
run;

proc datasets library=work nolist; 
	delete cis__:; 
run; 

* -------------------------------------------------------------------------------------;
/* column: total extra bed days per 100 services */
* 1 ----- find length of stay for allowed, unplanned admitted stays;
data &adm_data;
	set &adm_data;
	beddays = dschrg_dt - admsn_dt;

	if beddays = 0 then
		beddays = 1;
run;

data temp__beddays;
	set &adm_data;
	where out_7days_unplanned = 1 and exc_medpar_overlap = 0 and exc_medpar_admsntype = 0 and exc_medpar_pps = 0;
run;

* table for boostrap CI;
proc sql;
	create table temp__service_beddays as 
		select a.prvdr_num,a.bene_id,a.service,a.service_dt,a.out_7days_unplanned_no,sum(b.beddays) as BedDays
			from tab1__den as a 
				left join temp__beddays as b 
					on a.bene_id = b.bene_id and a.service_dt = b.service_dt 
				group by a.bene_id,a.service,a.service_dt,a.out_7days_unplanned_no;
quit;

* column table;
proc sql;
	create table tab1__col3 as 
		select service,sum(BedDays) as BedDays 
			from temp__service_beddays 
				group by service;
quit;

data tab1__col3; 
	merge tab1__col3 tab1__col1;
	by service; 
run; 

data tab1__col3(drop=LowValueCounts); 
	set tab1__col3; 
	BedDays_100 = BedDays/LowValueCounts*100; 
run; 

* get bootstrap counts and CI of unplanned admissions in 7 days;
%bootie_hospital(temp__service_beddays,BedDays,caro,'false');
%bootie_hospital(temp__service_beddays,BedDays,hyst,'false');
%bootie_hospital(temp__service_beddays,BedDays,ivcf,'false');
%bootie_hospital(temp__service_beddays,BedDays,knee,'false');
%bootie_hospital(temp__service_beddays,BedDays,perc,'false');
%bootie_hospital(temp__service_beddays,BedDays,rena,'false');
%bootie_hospital(temp__service_beddays,BedDays,spin,'false');
%bootie_hospital(temp__service_beddays,BedDays,vert,'false');

data tab1__col3_cis;
	set cis__:;
run;

data tab1__col3;
	merge tab1__col3 tab1__col3_cis;
	by service;
run;

data tab1__col3;
	set tab1__col3(rename=(pp2_5=lwr_bd pp97_5=upr_bd));
run;

proc datasets lib=work nolist; 
	delete cis__:;
run; 

* -------------------------------------------------------------------------------------;
/* column: total HACs per 100 services */
proc sql;
	create table temp__hac as 
		select bene_id,medpar_id,sum(out_hac_numerator) as HACs 
			from &hac_data
				where out_hac_denominator = 1 or missing(out_hac_denominator)
					group by bene_id,medpar_id;
quit;

* join to allowed admissions table;
proc sql;
	create table temp__adm_hac as 
		select a.*, b.HACs 
			from temp__beddays as a 
				left join temp__hac as b 
					on a.bene_id=b.bene_id and a.medpar_id=b.medpar_id;
quit;

* join to allowed denominator table;
* bootstrap table;
proc sql;
	create table temp__service_HACs as 
		select a.bene_id,a.prvdr_num,a.service,a.service_dt,sum(b.HACs) as HACs
			from tab1__den as a 
				left join temp__adm_hac as b 
					on a.bene_id = b.bene_id and a.service_dt = b.service_dt 
				group by a.bene_id,a.prvdr_num,a.service,a.service_dt,a.out_7days_unplanned_no;
quit;

proc sql;
	create table tab1__col4 as 
		select service,sum(HACs) as HACs
			from temp__service_HACs 
				group by service;
quit;

data tab1__col4; 
	merge tab1__col4 tab1__col1; 
	by service; 
run; 

data tab1__col4(drop=LowValueCounts); 
	set tab1__col4; 
	HACs_100 = HACs/LowValueCounts*100; 
run; 

%bootie_hospital(temp__service_HACs,HACs,caro,'false');
%bootie_hospital(temp__service_HACs,HACs,hyst,'false');
%bootie_hospital(temp__service_HACs,HACs,ivcf,'false');
%bootie_hospital(temp__service_HACs,HACs,knee,'false');
%bootie_hospital(temp__service_HACs,HACs,perc,'false');
%bootie_hospital(temp__service_HACs,HACs,rena,'false');
%bootie_hospital(temp__service_HACs,HACs,spin,'false');
%bootie_hospital(temp__service_HACs,HACs,vert,'false');

data tab1__col4_cis;
	set cis__:;
run;

data tab1__col4;
	merge tab1__col4 tab1__col4_cis;
	by service;
run;

data tab1__col4;
	set tab1__col4(rename=(pp2_5=lwr_hac pp97_5=upr_hac));
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

* join to allowed admissions table;
proc sql;
	create table temp__adm_psi as 
		select a.*, b.PSIs
			from temp__beddays as a 
				left join temp__psi as b 
					on a.bene_id=b.bene_id and a.medpar_id=b.medpar_id;
quit;

* join to allowed denominator table;
* bootstrap table;
proc sql;
	create table temp__service_psis as 
		select a.bene_id,a.prvdr_num,a.service,a.service_dt,sum(b.PSIs) as PSIs
			from tab1__den as a 
				left join temp__adm_psi as b 
					on a.bene_id = b.bene_id and a.service_dt = b.service_dt 
				group by a.bene_id,a.prvdr_num,a.service,a.service_dt,a.out_7days_unplanned_no;
quit;

proc sql;
	create table tab1__col5 as 
		select service,sum(PSIs) as PSIs
			from temp__service_PSIs 
				group by service;
quit;

data tab1__col5; 
	merge tab1__col5 tab1__col1; 
	by service; 
run; 

data tab1__col5(drop=LowValueCounts); 
	set tab1__col5; 
	PSIs_100 = PSIs/LowValueCounts*100; 
run; 

%bootie_hospital(temp__service_psis,PSIs,caro,'false');
%bootie_hospital(temp__service_psis,PSIs,hyst,'false');
%bootie_hospital(temp__service_psis,PSIs,ivcf,'false');
%bootie_hospital(temp__service_psis,PSIs,knee,'false');
%bootie_hospital(temp__service_psis,PSIs,perc,'false');
%bootie_hospital(temp__service_psis,PSIs,rena,'false');
%bootie_hospital(temp__service_psis,PSIs,spin,'false');
%bootie_hospital(temp__service_psis,PSIs,vert,'false');

data tab1__col5_cis;
	set cis__:;
run;

data tab1__col5;
	merge tab1__col5 tab1__col5_cis;
	by service;
run;

data tab1__col5;
	set tab1__col5(rename=(pp2_5=lwr_psi pp97_5=upr_psi));
run;

* -------------------------------------------------------------------------------------;
/* join table for output */
data out_tab1;
	merge tab1__col1-tab1__col5;
	by service;
run;
