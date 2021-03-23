*********************************************************************************;
* program name: hac_label.sas;
* project: hac and lvc;
* description: input from claim_prep.sas and creates table of medpar_id for each study hac;
*********************************************************************************;

* 
HAC files: 
hac_01_foreignobject
hac_02_airembolism
hac_03_bloodinc
hac_04_pressureulc
hac_05_falls
hac_06_cauti 
hac_07_vcai
hac_09_glycemic
hac_12_ssi_ortho    (has denominator)
hac_13_ssi_cardio   (has denominator)
hac_14_pneumothorax (has denominator)

TODO check whether we can include hac 13 SSI cardio based on lvc procedures;

* 
TODO figure out procedure non-operating room meaning for 12 and 13;

/*********************************************************************************
 * macro: create_list_hac;
 * description: this creates lists from the input files for the relevant diagnosis/procedure flags
 * input: 
hac_name : hac_xx_description. Needs to match csv file with codes.
hac_fmtname : name to save hac format as (with labels numer and denom).
* output: 
create formats in mylib
*********************************************************************************/
%macro create_list_hac(hac_name, hac_fmtname);

	proc import out= work.&hac_name.
		datafile= "&code_files/&hac_name" 
		dbms=xlsx replace;
		getnames=yes;
	run;

	data &hac_name.;
		set &hac_name.;
		length label $5;

		if type = 'denominator' then
			label = 'denom';
		else label = 'numer';
	run;

	data &hac_name.;
		set &hac_name. (drop= type rename=(code = start)) end=last;
		retain fmtname "$&hac_fmtname." type 'C';
		output;

		if last then
			do;
				hlo = 'O';
				label = '';
				output;
			end;

		keep fmtname type start label hlo;
	run;

	proc format lib = &mylib. cntlin=&hac_name.;
	run;

%mend create_list_hac;

%create_list_hac(hac_01_foreignobject,hac_01_);
%create_list_hac(hac_02_airembolism,hac_02_);
%create_list_hac(hac_03_bloodinc,hac_03_);
%create_list_hac(hac_04_pressureulc,hac_04_);
%create_list_hac(hac_05_falls,hac_05_);
%create_list_hac(hac_06_cauti,hac_06_);
%create_list_hac(hac_07_vcai,hac_07_);
%create_list_hac(hac_09_glycemic,hac_09_);
%create_list_hac(hac_12_ssi_ortho,hac_12_);
%create_list_hac(hac_13_ssi_cardio,hac_13_);
%create_list_hac(hac_14_pneumothorax,hac_14_);

/*********************************************************************************
/*macro to determine if measure format diagnosis is included in any secondary discharge 
diagnosis code as present on admission. */

/*********************************************************************************/
%let ndx = 25;
%let npr = 25;

%macro hac_numer(fmt);
	1 = 1 then
		do;
			result = 0;

			do i = 2 to &npr.;
				if put(diagnoses{i},&fmt.) = 'numer' then if poa{i} in ('N','U',' ','E','1','X') then
					result = 1;

				if result = 1 then
					leave;
			end;
		end;

	if result = 1 %mend;

	/*********************************************************************************
	/* macro to determine if procedures are in the denominator */

	/*********************************************************************************/
%macro hac_denom(fmt);
	(%do i = 1 %to &npr.-1; put(SRGCL_PRCDR_&i._CD,&fmt.) = 'denom' or
	%end;

	put(SRGCL_PRCDR_&npr._CD,&fmt.) = 'denom' 
		)
%mend;

/*********************************************************************************
 * macro: hac_table
 * description: creates dataset for medpar_ids with hac denominator flag and hac event flag ;
 * input: 
input_data : medpar ids
year_input
* output: 
output_data : data set with medpar_id, hac_dem [1], hac_num [0 or 1];
*********************************************************************************/
%macro hac_table(input_data,year_input,output_data);

	proc sort data=&input_data(keep=bene_id medpar_id) nodupkey out=temp_;
		by bene_id medpar_id;
	run;

	%let next_year = %sysevalf(&year_input+1);

	/*1------------ get medpar records */
	%IF &next_year ne 2019 %THEN
		%DO;

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
						dgns_1_cd--dgns_25_cd 
						poa_dgns_1_ind_cd--poa_dgns_25_ind_cd 
						srgcl_prcdr_1_cd--srgcl_prcdr_25_cd) 
						medpar.medpar_&next_year(keep = bene_id medpar_id 
						dgns_1_cd--dgns_25_cd 
						poa_dgns_1_ind_cd--poa_dgns_25_ind_cd 
						srgcl_prcdr_1_cd--srgcl_prcdr_25_cd) end=eof;

					if dim1.find()=0 then
						output;
				end;

				stop;
			run;

		%END;
	%ELSE
		%DO;

			data temp_;
				if 0 then
					set temp_;

				if _n_ = 1 then
					do;
						declare hash dim1 (dataset:"temp_", ordered: "a");
						dim1.definekey ('bene_id','medpar_id');
						dim1.definedata (all:'yes');
						dim1.definedone();
					end;

				do until(eof);
					set medpar.medpar_&year_input(keep = bene_id medpar_id 
						dgns_1_cd--dgns_25_cd 
						poa_dgns_1_ind_cd--poa_dgns_25_ind_cd 
						srgcl_prcdr_1_cd--srgcl_prcdr_25_cd) 
						end=eof;

					if dim1.find()=0 then
						output;
				end;

				stop;
			run;

		%END;

	/*2------------ run hac rules over table */
	data temp_;
		set temp_;
		array diagnoses DGNS_1_CD--DGNS_25_CD;
		array poa POA_DGNS_1_IND_CD--POA_DGNS_25_IND_CD;

		/* hac 01 - foreign object */
		hac_num_1 = 0;

		if %hac_numer($hac_01_.) then
			hac_num_1 = 1;

		/* hac 02 - air embolism */
		hac_num_2 = 0;

		if %hac_numer($hac_02_.) then
			hac_num_2 = 1;

		/* hac 03 - blood inc */
		hac_num_3 = 0;

		if %hac_numer($hac_03_.) then
			hac_num_3 = 1;

		/* hac 04 - pressure ulcer */
		hac_num_4 = 0;

		if %hac_numer($hac_04_.) then
			hac_num_4 = 1;

		/* hac 05 - fall */
		hac_num_5 = 0;

		if %hac_numer($hac_05_.) then
			hac_num_5 = 1;

		/* hac 06 - cauti */
		hac_num_6 = 0;

		if %hac_numer($hac_06_.) then
			hac_num_6 = 1;

		/* hac 07 - vcai */
		hac_num_7 = 0;

		if %hac_numer($hac_07_.) then
			hac_num_7 = 1;

		/* hac 09 - glycemic cntrl */
		hac_num_9 = 0;

		if %hac_numer($hac_09_.) then
			hac_num_9 = 1;

		/* hac 12 - ssi ortho */
		hac_num_12 = .;
		hac_den_12 = 0;

		if %hac_denom($hac_12_.) then
			do;
				hac_num_12 = 0;
				hac_den_12 = 1;
			end;

		if hac_den_12 = 1 and %hac_numer($hac_12_.) then
			hac_num_12 = 1;

		/* hac 13 - ssi cardio */
		hac_num_13 = .;
		hac_den_13 = 0;

		if %hac_denom($hac_13_.) then
			do;
				hac_num_13 = 0;
				hac_den_13 = 1;
			end;

		if hac_den_13 = 1 and %hac_numer($hac_13_.) then
			hac_num_13 = 1;

		/* hac 14 - pneumothorax */
		hac_num_14 = .;
		hac_den_14 = 0;

		if %hac_denom($hac_14_.) then
			do;
				hac_num_14 = 0;
				hac_den_14 = 1;
			end;

		if hac_den_14 = 1 and %hac_numer($hac_14_.) then
			hac_num_14 = 1;
	run;

	proc sort data=temp_;
		by bene_id medpar_id;
	run;

	proc transpose data=temp_(keep=bene_id medpar_id hac_num:) out=temp_num;
		by bene_id medpar_id;
	run;

	data temp_num(drop=_name_);
		set temp_num;
		rename col1 = out_hac_numerator;
		hac_name = compress(_name_,,'kd');
	run;

	proc transpose data=temp_(keep=bene_id medpar_id hac_den:) out=temp_den;
		by bene_id medpar_id;
	run;

	data temp_den(drop=_name_);
		set temp_den;
		rename col1 = out_hac_denominator;
		hac_name = compress(_name_,,'kd');
	run;

	proc sort data=temp_num;
		by bene_id medpar_id hac_name;
	run;

	proc sort data=temp_den;
		by bene_id medpar_id hac_name;
	run;

	data temp_;
		merge temp_num temp_den;
		by bene_id medpar_id hac_name;
	run;

	data &output_data;
		set temp_;
	run;

%mend hac_table;
