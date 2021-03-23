*********************************************************************************;
* program name: psi_label.sas;
* project: hac and lvc;

* description: input from claim_prep.sas and creates table of medpar_id for each 
     study psi;

*********************************************************************************;

/* this is built from the 2019 ARHQ PSI program, in particular the 
-   PSI_HOSP_Dx_Pr_Macros_v2019.sas: macros, particularly the mdx1/mdx2 macros
-   PSI_HOSP_FORMATS and PSI_HOSP_Comorb_Format_v2019.sas: these files include all 
the diagnosis and procedure codes (in ICD10). Have not been edited.
TODO see if we need comorbidity, otherwise exclude
-   PSI_HOSP_MEASURES.sas: this creates flags for the numerator and denominators of 
the PSIs. 
*/

* 
TODO create exclusions for missing values (sex, age, age limit (18));

/*********************************************************************************
 * macro: run_psi
 * description: takes the claims_prep output and creates the psi flags
 * input: 
- input_data: distinct medpar ids for investigated cases (like identified overuse)
- year_input: medpar year
* output: 
- output_data: distinct psi flags (denominator and numerator) for 
           each medpar id
*********************************************************************************/
%macro run_psi(input_data,year_input,output_data);
	/* create 
	   - mdc based on drg code - using formats and logic from ARHQ 
	   - medical drg flag
	   - surgical drg flag
	   - length of stay (days) */

	proc sort data = &input_data(keep=bene_id medpar_id) nodupkey out=temp_;
		by bene_id medpar_id;
	run;

	/*1------------ get medpar records */
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
						srgcl_prcdr_1_cd--srgcl_prcdr_25_cd 
						srgcl_prcdr_prfrm_1_dt--srgcl_prcdr_prfrm_25_dt
						drg_cd dschrg_dt admsn_dt ip_admsn_type_cd) 
						medpar.medpar_&next_year(keep = bene_id medpar_id 
						dgns_1_cd--dgns_25_cd 
						poa_dgns_1_ind_cd--poa_dgns_25_ind_cd 
						srgcl_prcdr_1_cd--srgcl_prcdr_25_cd 
						srgcl_prcdr_prfrm_1_dt--srgcl_prcdr_prfrm_25_dt
						drg_cd dschrg_dt admsn_dt ip_admsn_type_cd) end=eof;

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
						srgcl_prcdr_1_cd--srgcl_prcdr_25_cd 
						srgcl_prcdr_prfrm_1_dt--srgcl_prcdr_prfrm_25_dt
						drg_cd dschrg_dt admsn_dt ip_admsn_type_cd) 
						end=eof;

					if dim1.find()=0 then
						output;
				end;

				stop;
			run;

		%END;

	/*2 ------------ add mdc code based on drg conversion */
	data temp_;
		set temp_;
		length mdc $3;
		drg_medical = 0;
		drg_surgical = 0;

		/* drg is character - requires numeric */
		drg_cd_n = input(drg_cd,3.);
		mdc = put(drg_cd_n,MDCF2T.);

		if (put(put(drg_cd_n,z3.),$MEDIC2R.) = '1') then
			drg_medical = 1;

		if (put(put(drg_cd_n,z3.),$SURGI2R.) = '1') then
			drg_surgical = 1;
		los = dschrg_dt - admsn_dt;

		if missing(los) then
			los = 0;
	run;

	data temp_;
		set temp_;
		format orday date9.;
		format mprday date9.;
		array diagnoses DGNS_1_CD--DGNS_25_CD;
		array poa POA_DGNS_1_IND_CD--POA_DGNS_25_IND_CD;

		/* psi 03 - pressure ulcer rate -------------------------------------------------- */
		psi_num_03 = .;
		psi_03_excl_flag = .;

		if (drg_medical = 1 or drg_surgical = 1) then
			do;
				psi_num_03 = 0;
				psi_03_excl_flag = 0;

				if %mdx2($DECUBVD.) then
					psi_num_03 = 1;

				*** Exclude principal diagnosis or numerator event without at least one DECUBVD not POA;
				if %mdx1($DECUBVD.) then
					psi_num_03 = .;

				if %mdx2q2($DECUBVD.) then psi_03_excl_flag = 1; /* at least one POA */

	
					if %mdx2q1($DECUBVD.) then psi_03_excl_flag = 0; /* at least one not POA */

						*** Exclude severe burns;
						if %mdx($BURNDX.) then
							psi_num_03 = .;

						*** Exclude exfoliation;
						if %mdx($EXFOLIATXD.) then
							psi_num_03 = .;

						*** Exclude MDC 14;
						if mdc in (14) then
							psi_num_03 = .;

						*** Exclude LOS < 3;
						if los < 3 then
							psi_num_03 = .;

						*** Determine numerator exclusion for secondary Dx POA;
						if psi_num_03 = . then
							psi_03_excl_flag = .;

						if psi_num_03 = 0 and psi_03_excl_flag = 1 then
							psi_03_excl_flag = 0;
			end;

		if psi_03_excl_flag in (.,1) then
			psi_num_03 = .;
		
		/* psi 06 - iatrogenic pneumothorax ------------------------------------------------ */
		psi_num_06 = .;
		psi_06_excl_flag = .;

		if (drg_medical = 1 or drg_surgical = 1) then
			do;
				psi_num_06 = 0;
				psi_06_excl_flag = 0;

				if %mdx2($IATROID.) then
					psi_num_06 = 1;

				*** Exclude principal diagnosis;
				if %mdx1($IATROID.) then
					psi_num_06 = .;

				*** Exclude any secondary diagnosis present on admission;
				if %mdx2q2($IATROID.) then
					psi_06_excl_flag = 1;

				*** Exclude Chest Trauma, Pleural effusion or MDC 14;
				if %mdx($CTRAUMD.) or %mdx($PLEURAD.) or mdc in (14) then
					psi_num_06 = .;

				*** Exclude Thoracic surgery or Cardiac surgery;
				if %mpr($THORAIP.) or %mpr($CARDSIP.) then
					psi_num_06 = .;

				*** Determine numerator exclusion for secondary Dx POA;
				if psi_num_06 = . then
					psi_06_excl_flag = .;

				if psi_num_06 = 0 and psi_06_excl_flag = 1 then
					psi_06_excl_flag = 0;
			end;

		if psi_06_excl_flag in (.,1) then
			psi_num_06 = .;

		/* psi 09 - Perioperative Hemorrhage or Hematoma ----------------------------------- */
		psi_num_09 = .;
		psi_09_excl_flag = .;

		** run macro for number of operating room procedures;
		%orcnt;

		if (drg_surgical = 1 and orcnt > 0) then
			do;
				psi_num_09 = 0;
				psi_09_excl_flag = 0;

				if %mdx2($POHMRI2D.) and (%mpr($HEMOTH2P.)) then
					psi_num_09 = 1;

				*** Exclude principal diagnosis;
				if %mdx1($POHMRI2D.) then
					psi_num_09 = .;

				*** secondary Dx POA;
				if %mdx2q2($POHMRI2D.) then
					psi_09_excl_flag = 1;

				*** Exclude if control of post-operative hemorrhage or Miscellaneous hemorrhage
																  hematoma-related procedure are the only OR procedures;
				%mprcnt($HEMOTH2P.);

				if orcnt = mprcnt then
					psi_num_09 = .;

				*** Exclude if control of post-operative hemorrhage or Miscellaneous Hemorrhage or
																   hematoma-related procedure occurs before the first OR procedure;
				%orday($HEMOTH2P.);
				%mprday($HEMOTH2P.);

				if (orday ne . and mprday ne .) then
					do;
						if %mdx2($POHMRI2D.) and mprday < orday then
							psi_num_09 = .;
					end;

				*** Exclude MDC 14;
				if mdc in (14) then
					psi_num_09 = .;

				*** Exclude Coagulation Disorders;
				if %mdx($COAGDID.) then
					psi_num_09 = .;

				*** Determine numerator exclusion for secondary Dx POA;
				if psi_num_09 = . then
					psi_09_excl_flag = .;

				if psi_num_09 = 0 and psi_09_excl_flag = 1 then
					psi_09_excl_flag = 0;
			end;

		if psi_09_excl_flag in (.,1) then
			psi_num_09 = .;

		/* psi 11 - Postoperative Respiratory Failure ----------------------------------- */
		psi_num_11 = .;
		psi_11_excl_flag = .;

		if drg_surgical = 1 and ip_admsn_type_cd in (3) and orcnt > 0 then
			do;
				psi_num_11 = 0;
				psi_11_excl_flag = 0;

				if %mdx2($ACURF2D.) then
					psi_num_11 = 1;

				*** Include in numerator if reintubation procedure occurs on the same day or
																   # days after the first OR procedure;
				%orday($BLANK.);
				%psi11n($PR9604P.,1);
				%psi11n($PR9671P.,2);
				%psi11n($PR9672P.,3);

				*** Exclude principal diagnosis;
				if %mdx1($ACURF3D.) then
					psi_num_11 = .;

				if %mdx2q2($ACURF3D.) then
					psi_11_excl_flag = 1;

				*** Exclude if tracheostomy procedure is the only OR procedure;
				%mprcnt($TRACHIP.);

				if orcnt = mprcnt then
					psi_num_11 = .;

				*** Exclude if tracheostomy procedure occurs before the first or procedure;
				%orday($TRACHIP.);
				%mprday($TRACHIP.);

				if (orday ne . and mprday ne .) then
					do;
						if mprday < orday then
							psi_num_11 = .;
					end;

				*** Exclude Neuromuscular disorders;
				if %mdx($NEUROMD.) then
					psi_num_11 = .;

				*** Exclude Craniofacial anomalies;
				if %mpr($NUCRANP.) then
					psi_num_11 = .;

				*** Exclude Esophageal resection procedure;
				if %mpr($PRESOPP.) then
					psi_num_11 = .;

				*** Exclude Lung Cancer Procedure;
				if %mpr($LUNGCIP.) then
					psi_num_11 = .;

				*** Exclude diagnosis of degenerative neurological disorder;
				if %mdx($DGNEUID.) then
					psi_num_11 = .;

				*** Exclude Hospitalizations involving lung transplantations;
				if %mpr($LUNGTRANSP.) then
					psi_num_11 = .;

				*** Exclude MDC 4, 5, 14;
				if mdc in (4,5,14) then
					psi_num_11 = .;

				*** Determine numerator exclusion for secondary Dx POA;
				if psi_num_11 = . then
					psi_11_excl_flag = .;

				if psi_num_11 = 0 and psi_11_excl_flag = 1 then
					psi_11_excl_flag = 0;
			end;

		if psi_11_excl_flag in (.,1) then
			psi_num_11 = .;

		/* psi 12 - Perioperative Pulmonary Embolism or Deep Vein Thrombosis ----------- */
		psi_num_12 = .;
		psi_12_excl_flag = .;

		if drg_surgical = 1 and orcnt > 0 then
			do;
				psi_num_12 = 0;
				psi_12_excl_flag = 0;

				if %mdx2($DEEPVIB.) or %mdx2($PULMOID.) then
					psi_num_12 = 1;

				*** Exclude principal diagnosis;
				if %mdx1($DEEPVIB.) or %mdx1($PULMOID.) then
					psi_num_12 = .;

				if %mdx2q2($DEEPVIB.) then
					DEEPVIB_cd = 1;

				if %mdx2q2($PULMOID.) then
					PULMOID_cd = 1;

				if DEEPVIB_cd or PULMOID_cd then
					psi_12_excl_flag = 1;

				*** Exclude if interruption of vena cava occurs before or on the
																   same day as the first OR procedure;
				%orday($VENACIP.);
				%mprday($VENACIP.);

				if (orday ne . and mprday ne .) then
					do;
						if mprday <= orday then
							psi_num_12 = .;
					end;

				*** Exclude if pulmonary arterial thrombectomy before or on the
																   same day as the first OR procedure;
				%orday($THROMP.);
				%mprday($THROMP.);

				if (orday ne . and mprday ne .) then
					do;
						if mprday <= orday then
							psi_num_12 = .;
					end;

				*** Exclude if only operating room procedure was for interruption of vena cava or 
																 pulmonary arterial thrombectomy;
				%mprcnt($VENACIP.);

				if orcnt = mprcnt then
					psi_num_12 = .;
				mprcntv = mprcnt;

				%mprcnt($THROMP.);

				if orcnt = mprcnt then
					psi_num_12 = .;

				*** Exclude if the combined count equals ORCNT - although unlikely;
				if orcnt = mprcnt + mprcntv then
					psi_num_12 = .;

				*** Exclude hospitalizations with neurotrauma POA;
				if %mdxaq2($NEURTRAD.) then
					psi_num_12 = .;

				*** Exclude any extracorporeal membrane oxygenation procedure;
				if %mpr($ECMOP.) then
					psi_num_12 = .;

				*** Exclude MDC 14;
				if mdc in (14) then
					psi_num_12 = .;

				*** Determine numerator exclusion for secondary Dx POA;
				if psi_num_12 = . then
					psi_12_excl_flag = .;

				if psi_num_12 = 0 and psi_12_excl_flag = 1 then
					psi_12_excl_flag = 0;
			end;

		if psi_12_excl_flag in (.,1) then
			psi_num_12 = .;

		/* psi 13 - Postoperative sepsis ----------------------------------------------- */
		psi_num_13 = .;
		psi_13_excl_flag = .;

		if drg_surgical =1 and orcnt > 0 and ip_admsn_type_cd in (3) then
			do;
				psi_num_13 = 0;
				psi_13_excl_flag = 0;

				if (%mdx2($SEPTI2D.)) then
					psi_num_13 = 1;

				*** Exclude principal diagnosis;
				if (%mdx1($SEPTI2D.)) then
					psi_num_13 = .;

				if %mdx2q2($SEPTI2D.) then
					psi_13_excl_flag = 1;

				*** Exclude Infection;
				if %mdx1($INFECID.) then
					psi_num_13 = .;

				if %mdx2q2($INFECID.) then
					psi_13_excl_flag = 1;

				*** Exclude MDC 14;
				if mdc in (14) then
					psi_num_13 = .;

				*** Determine numerator exclusion for secondary Dx POA;
				if psi_num_13 = . then
					psi_13_excl_flag = .;

				if psi_num_13 = 0 and psi_13_excl_flag = 1 then
					psi_13_excl_flag = 0;
			end;

		if psi_13_excl_flag in (.,1) then
			psi_num_13 = .;

		/* assign denominators for psis */
		array psi_num psi_num_03 psi_num_06 psi_num_09 psi_num_11 psi_num_12 psi_num_13;
		array psi_den psi_den_03 psi_den_06 psi_den_09 psi_den_11 psi_den_12 psi_den_13;

		do over psi_num;
			if psi_num ge 0 then
				psi_den = 1;
			else psi_den = .;
		end;
	run;

	proc sort data=temp_;
		by bene_id medpar_id;
	run;

	proc transpose data=temp_(keep=bene_id medpar_id psi_num:) out=temp_num;
		by bene_id medpar_id;
	run;

	data temp_num(drop=_name_);
		set temp_num;
		rename col1 = out_psi_numerator;
		psi_name = compress(_name_,,'kd');
	run;

	proc transpose data=temp_(keep=bene_id medpar_id psi_den:) out=temp_den;
		by bene_id medpar_id;
	run;

	data temp_den(drop=_name_);
		set temp_den;
		rename col1 = out_psi_denominator;
		psi_name = compress(_name_,,'kd');
	run;

	proc sort data=temp_num;
		by bene_id medpar_id psi_name;
	run;

	proc sort data=temp_den;
		by bene_id medpar_id psi_name;
	run;

	data temp_;
		merge temp_num temp_den;
		by bene_id medpar_id psi_name;
	run;

	data &output_data;
		set temp_;
	run;

%mend run_psi;
