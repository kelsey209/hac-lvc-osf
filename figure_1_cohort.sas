*********************************************************************************;
* program name: figure_1_cohort.sas;
* project: hac and lvc;
* description: create cohort counts for services;
*********************************************************************************;
data outpatient_all;
	set kch315sl.res__otp_2016 
		kch315sl.res__otp_2017 
		kch315sl.res__otp_2018; 
run; 

data outpatient_medpar; 
	set kch315sl.res__otp_medpar7_2016
		kch315sl.res__otp_medpar7_2017
		kch315sl.res__otp_medpar7_2018;
run; 

%let outpatient_data = outpatient_all;
%let adm_data = outpatient_medpar;

data temp__data;
	set &outpatient_data;
	where lowvalue = 1 and service not in ('ivcf');
run;

* all patients;
proc sql;
	create table cohort__1 as 
		select count(distinct cat(bene_id,service,service_dt)) as Services 
			from temp__data;
quit;

data cohort__1; 
	set cohort__1; 
	format description $50.;
	description = 'All services'; 
run; 

* 65 and older and usa;
proc sql;
	create table cohort__2 as 
		select count(distinct cat(bene_id,service,service_dt)) as Services 
			from temp__data 
				where exc_age = 0 and exc_usa = 0;
quit;

data cohort__2; 
	set cohort__2; 
	format description $50.;
	description = '65 and older in the US'; 
run; 

* coverage for next 7 days;
proc sql;
	create table cohort__3 as 
		select count(distinct cat(bene_id,service,service_dt)) as Services 
			from temp__data
				where exc_age = 0 and exc_usa = 0 and exc_coverage = 0 and exc_days7 = 0;
quit;

data cohort__3; 
	set cohort__3; 
	format description $50.;
	description = 'Coverage in next 7 days'; 
run; 

* for patients with perc and cea, need exc_lookback = 0;
proc sql;
	create table cohort__4 as 
		select count(distinct cat(bene_id,service,service_dt)) as Services 
			from temp__data 
				where exc_age = 0 and exc_usa = 0 and exc_coverage = 0 and exc_days7 = 0 and ((service in ('perc','caro') and exc_lookback = 0) or service not in ('perc','caro'));
quit;

data cohort__4; 
	set cohort__4; 
	format description $50.;
	description = 'Lookback one year'; 
run; 

* patients with any inpatient admission in 7 days;
data temp__included;
	set temp__data;
	where exc_age = 0 and exc_usa = 0 and exc_coverage = 0 and exc_days7 = 0 and ((service in ('perc','caro') and exc_lookback = 0) or service not in ('perc','caro'));
run;

proc sql;
	create table temp__adm as 
		select a.bene_id, a.service, a.service_dt, b.* 
			from temp__included as a 
				left join &adm_data as b 
					on a.bene_id = b.bene_id and a.service_dt = b.service_dt;
quit;

data temp__adm;
	set temp__adm;
	where not missing(medpar_id);
run;

proc sql;
	create table cohort__5 as 
		select count(distinct cat(bene_id,service,service_dt)) as Services 
			from temp__adm;
quit;

data cohort__5; 
	set cohort__5; 
	format description $50.;
	description = 'Admission within 7 days'; 
run; 

* patients with medpar adm exclusions applied;
proc sql;
	create table cohort__6 as 
		select count(distinct cat(bene_id,service,service_dt)) as Services 
			from temp__adm
				where exc_medpar_overlap = 0 and exc_medpar_admsntype = 0 and exc_medpar_pps = 0;
quit;

data cohort__6; 
	set cohort__6; 
	format description $50.;
	description = 'Allowed admissions'; 
run; 

* patients with unplanned inpatient admissions;
proc sql;
	create table cohort__7 as 
		select count(distinct cat(bene_id,service,service_dt)) as Services 
			from temp__adm
				where exc_medpar_overlap = 0 and exc_medpar_admsntype = 0 and exc_medpar_pps = 0 and out_7days_unplanned = 1;
quit;

data cohort__7; 
	set cohort__7; 
	format description $50.;
	description = 'Unplanned 7 days'; 
run; 

/* full cohort table */
data res__out_cohort; 
	set cohort__1-cohort__7; 
run; 

title 'Outpatient cohort' ;
proc print data=res__out_cohort; 
run; 


/********************************** inpatient ******************************/
data inpatient_data; 
	set kch315sl.res__inp_2016
		kch315sl.res__inp_2017
		kch315sl.res__inp_2018; 
run; 

%let inp_data = inpatient_data; 

data temp__data; 
	set &inp_data; 
	where lowvalue = 1 and service not in ('ivcf'); 
run; 

proc sql; 
	create table cohort__inp_1 as 
	select count(distinct cat(bene_id,service_dt,service)) as Services 
	from temp__data; 
	quit; 

data cohort__inp_1;
	set cohort__inp_1; 
	format description $50.;
	description = 'All services'; 
run; 

/* patients that are 65 and older and residing in the US */ 
proc sql; 
	create table cohort__inp_2 as 
	select count(distinct cat(bene_id,service_dt,service)) as Services 
	from temp__data 
	where exc_age = 0 and exc_usa = 0; 
quit; 

data cohort__inp_2;
	set cohort__inp_2; 
	format description $50.;
	description = '65 and older in the US'; 
run;

/* Lookback for PCI and caro patients */ 
proc sql; 
	create table cohort__inp_3 as 
	select count(distinct cat(bene_id,service_dt,service)) as Services 
	from temp__data 
	where exc_age = 0 and exc_usa = 0 and exc_coverage = 0 and ((service in ('perc','caro') and exc_lookback = 0) or service not in ('perc','caro')); 
quit; 

data cohort__inp_3; 
	set cohort__inp_3; 
	format description $50.; 
	description = 'Lookback one year';
run; 

/* Where the service was the principal procedure */ 
proc sql; 
	create table cohort__inp_4 as 
	select count(distinct cat(bene_id,service_dt,service)) as Services 
	from temp__data 
	where exc_age = 0 and exc_usa = 0 and exc_coverage = 0 and ((service in ('perc','caro') and exc_lookback = 0) or service not in ('perc','caro')) and 
		service = primary; 
quit;

data cohort__inp_4; 
	set cohort__inp_4; 
	format description $50.; 
	description = 'Service is primary procedure'; 
run; 

/* full cohort table */
data res__inp_cohort; 
	set cohort__inp_1-cohort__inp_4; 
run; 


title 'Inpatient cohort'; 
proc print data=res__inp_cohort; 
run; 
