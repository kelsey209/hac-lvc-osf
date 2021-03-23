*********************************************************************************;
* program name: pri_procedure.sas;
* project: hac and lvc;
* description: input from identified lvc - add label if primary procedure was the service;
*********************************************************************************;

/*********************************************************************************
 * macro: run_pri
 * description: takes the claims (inpatient) ids and service labels and checks if
this was the main reason for admission or not;
* input: 
- input_data: distinct medpar ids for investigated cases (like identified overuse)

*********************************************************************************/

%macro run_pri(input_data,year_input);
proc sort data = &input_data(keep=bene_id medpar_id) nodupkey out=temp_;
	by bene_id medpar_id;
run;

data temp_;
	if 0 then
		set temp_;

	if _n_ = 1 then
		do;
			declare hash dim1 (dataset:"temp_", ordered: "a",multidata:'yes');
			dim1.definekey ('bene_id','medpar_id');
			dim1.definedata (all:'yes');
			dim1.definedone();
		end;

	do until(eof);
		set medpar.medpar_&year_input(keep = bene_id medpar_id  
			srgcl_prcdr_1_cd) end=eof;

		if dim1.find()=0 then
			output;
	end;

	stop;
run;

/*1------------ create the principal procedure flag*/
data temp_;
	set temp_;
	format primary $char4.;
	primary = "";

	%DO_OVER(VALUES = hyst spin caro knee vert ivcf rena perc,
		PHRASE = if put(srgcl_prcdr_1_cd,$?_icd_service.) = 1 then primary = "?"; )

		/* edit for kyphoplasties - vertebroplasty */

	if put(srgcl_prcdr_1_cd,$KYPH_ICD_SERVICE.) = 1 then
		primary = 'kyph';
run;

proc sort data=&input_data;
	by bene_id medpar_id;
run;

proc sort data=temp_;
	by bene_id medpar_id;
run;

data &input_data;
	merge &input_data temp_;
	by bene_id medpar_id;
run;

/* cnt edit for kyphoplasties */
data &input_data;
	set &input_data;

	if primary = 'kyph' then
		do;
			if service = 'vert' then
				primary = 'vert';
			else primary = '';
		end;
run;

%mend run_pri;
