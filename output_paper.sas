*********************************************************************************;
* program name: output_paper.sas;
* project: hac and lvc;
* description: create counts and output for values reported in text;
*********************************************************************************;
data tab__outpatient;
	set kch315sl.res__otp_2016
		kch315sl.res__otp_2017
		kch315sl.res__otp_2018;
	where lowvalue = 1 and exc_coverage = 0 and exc_days7 = 0 and 
		service not in ('ivcf') and 
		((service in ('perc','caro') and exc_lookback = 0) or service not in ('perc','caro')) and 
		exc_age = 0 and exc_usa = 0;
run;

proc sql; 
	select COUNT(DISTINCT(CAT(bene_id,service_dt,service))) as service_count 
		from tab__outpatient; 
quit; 

/* Unplanned admissions after an outpatient low-value procedure */
proc sort data=tab__outpatient(keep=bene_id clm_id service) nodupkey out=cnt__outpatient;
	by bene_id clm_id service;
run;

proc freq data=tab__outpatient;
	table out_7days_unplanned_no/out=cnt__unplnnd;
run;

proc sql; 
	select count (distinct cat(bene_id,service,service_dt))  
	from tab__outpatient 
	where out_7days_unplanned_no > 0; 
quit; 

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

%let adm_data = tab2__test;
%let hac_data = tab3__test;
%let psi_data = tab4__test;

*  We observed XXX HAC events in XXX admissions (XX%);
proc sql;
	create table adm__den as 
		select a.bene_id,a.medpar_id 
			from (select * from &adm_data where out_7days_unplanned >0) as a 
				inner join tab__outpatient as b 
					on a.bene_id = b.bene_id and a.service_dt = b.service_dt;
quit;

proc sql;
	select sum(out_hac_numerator)
		from (select * from &hac_data as a 
			inner join adm__den as b 
				on a.bene_id = b.bene_id and a.medpar_id = b.medpar_id)
			where out_hac_denominator = 1 or missing(out_hac_denominator);
quit;

*  We observed XXX PSI events in XXX admissions (XX%);
proc sql;
	select sum(out_psi_numerator)
		from (select * from &psi_data as a 
			inner join adm__den as b 
				on a.bene_id = b.bene_id and a.medpar_id = b.medpar_id)
			where out_psi_denominator = 1;
quit;

/*************************************************************************************/
* INPATIENT RESULTS ; 

data tab__inpatient; 
	set kch315sl.res__inp_2016
		kch315sl.res__inp_2017
		kch315sl.res__inp_2018; 
	where lowvalue = 1 and exc_coverage = 0 and 
		service not in ('ivcf') and 
		((service in ('perc','caro') and exc_lookback = 0) or service not in ('perc','caro')) and 
		exc_age = 0 and exc_usa = 0  
		and service = primary;
run; 

* Of the XXXX low-value inpatient procedures ; 
proc sql; 
	select COUNT(DISTINCT(CAT(bene_id,service_dt,service))) as service_count 
		from tab__inpatient; 
quit; 

* XXX (XXX%) had at least one HAC ; 
data tab__hac;
	set kch315sl.res__inp_hac_2016 
		kch315sl.res__inp_hac_2017
		kch315sl.res__inp_hac_2018;
run; 

proc sql; 
	create table temp__hac as 
		select bene_id,medpar_id,sum(out_hac_numerator) as HAC
			from tab__hac 
				where (out_hac_denominator = 1 or missing(out_hac_denominator))
	group by bene_id,medpar_id; 
quit; 

proc sql; 
	create table temp__inp as 
	select a.bene_id,a.service_dt,service,b.HAC 
	from tab__inpatient as a 
	inner join temp__hac as b 
	on a.bene_id = b.bene_id and a.medpar_id = b.medpar_id;
quit; 

data temp__inp;
	set temp__inp; 
	HAC_atl1 = 0; 
	if HAC > 0 then HAC_atl1 = 1; 
run; 

proc sql; 
	select COUNT(DISTINCT(CAT(bene_id,service_dt,service))) as HAC_count 
		from temp__inp
		where HAC_atl1 = 1; 
quit; 

* The procedure with the most HACs was XXXX,; 
proc sql; 
	select service,COUNT(DISTINCT(CAT(bene_id,service_dt))) as HAC_count 
		from temp__inp
		where HAC_atl1 = 1 
		group by service; 
quit; 

* The most frequent HAC was XXX (XX); 
proc sql; 
	create table temp__hac as 
		select bene_id,medpar_id,hac_name,sum(out_hac_numerator) as HAC
			from tab__hac 
				where (out_hac_denominator = 1 or missing(out_hac_denominator))
	group by bene_id,medpar_id,hac_name; 
quit; 

proc sql; 
	create table temp__inp as 
	select a.bene_id,a.service_dt,service,b.hac_name,b.HAC 
	from tab__inpatient as a 
	inner join temp__hac as b 
	on a.bene_id = b.bene_id and a.medpar_id = b.medpar_id;
quit; 

data temp__inp;
	set temp__inp; 
	HAC_atl1 = 0; 
	if HAC > 0 then HAC_atl1 = 1; 
run; 

proc sql; 
	select hac_name,COUNT(DISTINCT(CAT(bene_id,service_dt,service))) as HAC_count 
		from temp__inp
		where HAC_atl1 = 1
		group by hac_name;  
quit; 


* XXX (XXX%) had at least one PSI. ; 
data tab__psi;
	set kch315sl.res__inp_psi_2016 
		kch315sl.res__inp_psi_2017
		kch315sl.res__inp_psi_2018;
run; 

proc sql; 
	create table temp__psi as 
		select bene_id,medpar_id,sum(out_psi_numerator) as psi
			from tab__psi 
				where (out_psi_denominator = 1)
	group by bene_id,medpar_id; 
quit; 

proc sql; 
	create table temp__inp as 
	select a.bene_id,a.service_dt,service,b.psi 
	from tab__inpatient as a 
	inner join temp__psi as b 
	on a.bene_id = b.bene_id and a.medpar_id = b.medpar_id;
quit; 

data temp__inp;
	set temp__inp; 
	psi_atl1 = 0; 
	if psi > 0 then psi_atl1 = 1; 
run; 

proc sql; 
	select COUNT(DISTINCT(CAT(bene_id,service_dt,service))) as psi_count 
		from temp__inp
		where psi_atl1 = 1; 
quit; 

*and the service with the most PSIs was XXXX; 
proc sql; 
	select service,COUNT(DISTINCT(CAT(bene_id,service_dt))) as psi_count 
		from temp__inp
		where psi_atl1 = 1 
		group by service; 
quit; 

* and the most frequent PSI event was XXX (XX). ; 
proc sql; 
	create table temp__psi as 
		select bene_id,medpar_id,psi_name,sum(out_psi_numerator) as psi
			from tab__psi 
				where (out_psi_denominator = 1)
	group by bene_id,medpar_id,psi_name; 
quit; 

proc sql; 
	create table temp__inp as 
	select a.bene_id,a.service_dt,service,b.psi_name,b.psi 
	from tab__inpatient as a 
	inner join temp__psi as b 
	on a.bene_id = b.bene_id and a.medpar_id = b.medpar_id;
quit; 

data temp__inp;
	set temp__inp; 
	psi_atl1 = 0; 
	if psi > 0 then psi_atl1 = 1; 
run; 

proc sql; 
	select psi_name,COUNT(DISTINCT(CAT(bene_id,service_dt,service))) as psi_count 
		from temp__inp
		where psi_atl1 = 1
		group by psi_name;  
quit; 

/* total counts */ 
proc sql; 
	create table temp__total as 
	select a.*,b.* 
	from tab__inpatient as a
	left join temp__hac as b
	on a.bene_id =b.bene_id and a.medpar_id = b.medpar_id; 
quit; 

proc sql; 
	create table temp__total2 as 
	select a.*,b.*
	from temp__total as a 
	left join temp__psi as b
	on a.bene_id=b.bene_id and a.medpar_id=b.medpar_id; 
quit; 

data temp__total2; 
	set temp__total2; 
	event = 0; 
	if hac > 0 or psi > 0 then event = 1; 
run; 

proc sql; 
	create table event_counts as 
	select service,count(distinct(cat(bene_id,service_dt))) as events
	from temp__total2 
	where event = 1
	group by service;
quit; 

proc sql; 
	create table total_counts as 
	select service,count(distinct(cat(bene_id,service_dt))) as N
	from temp__total2 
	group by service;
quit; 

data total_counts; 
	merge total_counts event_counts; 
run; 

data total_counts; 
	set total_counts; 
	R = events/N*100; 
run; 


/**************************************************************/ 
* Across all inpatient admissions with a low-value procedure, HACs resulted in a 
 total additional XXX (XXX, XXX) days in hospital (or XXX per year) ; 

/* run table_4_costs_los.sas */ 

data tab4__den_ccr; 
  set tab4__den_ccr; 
  where service not in ('ivcf'); 
run; 

proc glm data = tab4__den_ccr; 
	class sex_ident_cd drg_cd HAC_record service; 
	model los = age sex_ident_cd drg_cd HAC_record service;
	store losModel; 
quit; 

data NewData; 
	set tab4__den_ccr(where=(HAC_record=1));
run; 

title 'Total LOS for HACs'; 
proc sql; 
	select sum(los) from NewData; quit; 

data NewData; 
	set NewData; 
	HAC_record = 0; 
run; 

proc plm restore=losModel; 
	score data=NewData out=ScoreNew ; 
run; 

title 'Total LOS - adjusted for HACs'; 
proc sql; 
	select sum(Predicted) from ScoreNew; quit; 

/* hacs results in XXX total costs */ 
proc glm data = tab4__den_ccr; 
	class sex_ident_cd drg_cd HAC_record service; 
	model cost = age sex_ident_cd drg_cd HAC_record service;
	store costModel; 
quit; 

data NewData; 
	set tab4__den_ccr(where=(HAC_record=1));
run; 

title 'Total cost for HACs'; 
proc sql; 
	select sum(cost) from NewData; quit; 

data NewData; 
	set NewData; 
	HAC_record = 0; 
run; 

proc plm restore=costModel; 
	score data=NewData out=ScoreNew ; 
run; 

title 'Total cost - adjusted for HACs'; 
proc sql; 
	select sum(Predicted) from ScoreNew; quit; 


/*********** PSI ***************/
	
proc glm data = tab4__den_ccr; 
	class sex_ident_cd drg_cd PSI_record service; 
	model los = age sex_ident_cd drg_cd PSI_record service;
	store losModel; 
quit; 

data NewData; 
	set tab4__den_ccr(where=(PSI_record=1));
run; 

title 'Total LOS for PSIs'; 
proc sql; 
	select sum(los) from NewData; quit; 

data NewData; 
	set NewData; 
	PSI_record = 0; 
run; 

proc plm restore=losModel; 
	score data=NewData out=ScoreNew ; 
run; 

title 'Total LOS - adjusted for PSIs'; 
proc sql; 
	select sum(Predicted) from ScoreNew; quit; 

/* psis results in XXX total costs */ 
proc glm data = tab4__den_ccr; 
	class sex_ident_cd drg_cd PSI_record service; 
	model cost = age sex_ident_cd drg_cd PSI_record service;
	store costModel; 
quit; 

data NewData; 
	set tab4__den_ccr(where=(PSI_record=1));
run; 

title 'Total cost for PSIs'; 
proc sql; 
	select sum(cost) from NewData; quit; 

data NewData; 
	set NewData; 
	PSI_record = 0; 
run; 

proc plm restore=costModel; 
	score data=NewData out=ScoreNew ; 
run; 

title 'Total cost - adjusted for PSIs'; 
proc sql; 
	select sum(Predicted) from ScoreNew; quit; 

/*********************************************************************************/
/* DEMOGRAPHICS */
/*********************************************************************************/
%macro get_age(input,id_var,year_input,output);

	data temp(keep=bene_id &id_var service service_dt);
		set &input;

		%if &id_var eq medpar_id %then
			%do;
				where lowvalue = 1 and exc_coverage = 0 and 
					service not in ('ivcf') and 
					((service in ('perc','caro') and exc_lookback = 0) or service not in ('perc','caro')) and 
					exc_age = 0 and exc_usa = 0  
					and service = primary;
			%end;
		%else
			%do;
				where lowvalue = 1 and exc_coverage = 0 and exc_days7 = 0 and 
					service not in ('ivcf') and 
					((service in ('perc','caro') and exc_lookback = 0) or service not in ('perc','caro')) and 
					exc_age = 0 and exc_usa = 0;
			%end;
	run;

	proc sort data=temp out=temp_bene;
		by bene_id;
	run;

	data temp_bene;
		if 0 then
			set temp_bene;

		if _n_ = 1 then
			do;
				declare hash dim1 (dataset:"temp", ordered: "a");
				dim1.definekey ('bene_id');
				dim1.definedata (all:"yes");
				dim1.definedone();
			end;

		do until(eof);
			set mbsf.mbsf_abcd_&year_input(keep = bene_id bene_birth_dt sex_ident_cd bene_race_cd) end=eof;

			if dim1.find()=0 then
				output;
		end;

		stop;
	run;

	proc sort data=temp;
		by bene_id;
	run;

	proc sort data=temp_bene nodupkey;
		by bene_id;
	run;

	data &output;
		merge temp temp_bene;
		by bene_id;
	run;

	data &output;
		set &output;
		bene_age = %age(bene_birth_dt,service_dt);
	run;

%mend get_age;

%get_age(&mylib..res__inp_2016,medpar_id,2016,res__age_inp_2016);
%get_age(&mylib..res__inp_2017,medpar_id,2017,res__age_inp_2017); 
%get_age(&mylib..res__inp_2018,medpar_id,2018,res__age_inp_2018); 

%get_age(&mylib..res__otp_2016,clm_id,2016,res__age_otp_2016); 
%get_age(&mylib..res__otp_2017,clm_id,2016,res__age_otp_2017); 
%get_age(&mylib..res__otp_2018,clm_id,2016,res__age_otp_2018); 

data total_inp; 
	set res__age_inp_2016
		res__age_inp_2017
		res__age_inp_2018;
run; 

data total_otp;
	set res__age_otp_2016
		res__age_otp_2017
		res__age_otp_2018; 
run; 

proc sort data=total_inp out=total_inp nodupkey; 
	by bene_id service_dt service; 
run; 

proc sort data=total_otp out=total_otp nodupkey; 
	by bene_id service_dt service; 
run; 

data total_age; 
	set total_inp total_otp; 
run; 

/* age statistics */ 
proc means data=total_age; 
	var bene_age;
run; 

/* sex and race */
proc freq data=total_age;
	table sex_ident_cd bene_race_cd / missing; 
run; 
