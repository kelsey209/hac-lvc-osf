/******************************************************************/
/* Title:       CREATION OF COMORBIDITY VARIABLES                 */
/*              ICD-10-CM COMORBIDITY SOFTWARE,                   */
/*                       VERSION 2021.1                           */
/*                                                                */
/* PROGRAM:     Comorb_ICD10CM_Analy_v2021-1.sas                  */
/*                                                                */
/* Description: Creates comorbidity variables based on the        */
/*              secondary diagnoses. Identification of some       */
/*              comorbidities is dependent on the diagnosis being */
/*              present on admission. Valid through FY2021        */
/*              (09/30/21).                                       */
/*                                                                */
/* Note:        Please specify below if diagnosis present on      */
/*              admission (POA) indicators are available in your  */
/*              data. If POA is not available, comorbidity flags  */
/*              that require POA will be set to missing.          */
/******************************************************************/
/*******************************************************************/
/*      THE SAS MACRO FLAGS BELOW MUST BE UPDATED BY THE USER      */
/*  These macro variables must be set to define the locations,     */
/*  names, and characteristics of your input and output SAS        */
/*  formatted data.                                                */
/*******************************************************************/
/**************************************/
/*          FILE LOCATIONS            */
/**************************************/
*LIBNAME IN1     'C:\DATA\';
*<===USER MUST MODIFY;
*LIBNAME OUT1    'C:\DATA\';
*<===USER MUST MODIFY;
*LIBNAME LIBRARY 'C:\COMORB\FMTLIB\';
*<===USER MUST MODIFY;
/**************************************/
/*            FILE NAMES              */
/**************************************/
* Input SAS file member name;
*%Let CORE = YOUR_SAS_INPUT_FILE_HERE;
*<===USER MUST MODIFY;
* Output SAS file member name;
*%Let OUT  = YOUR_SAS_OUTPUT_FILE_HERE;
*<===USER MUST MODIFY;
/**************************************/
/*   INPUT FILE CHARACTERISTICS       */
/**************************************/
* Maximum number of diagnoses on any record;
%LET NUMDX = 25;

*<===USER MUST MODIFY;
* Diagnosis Present on Admission Indicators available? (1=yes,0=no);
%LET POA   = 1;

*<===USER MUST MODIFY;
/* edit - include YEAR and DQTR in file */
data &input;
	set &input;
	YEAR = year(dschrg_dt);
	DQTR = qtr(dschrg_dt);
run;

TITLE1 'CREATION OF THE ELIXHAUSER COMORBIDITY MEASURES';
TITLE2 'FOR ICD-10-CM';

%macro comorbidity;

	DATA &output;
		SET  &input;
		DROP    I J  DXVALUE A1-A20 %if &POA.=1 %then

			%do;
				B1-B19 K
			%end;

		CBVD_SQLA CBVD_POA CBVD_NPOA;

		/*****************************************/
		/*    Establish the ICD-10-CM Version    */
		/* This will default to the last version */
		/* for discharges outside of coding      */
		/* updates.                              */
		/*****************************************/
		attrib ICDVER length=3 label='ICD-10-CM VERSION';
		ICDVER = 0;

		if      (YEAR in (2015) and DQTR in (4)) then
			ICDVER = 33;
		else if (YEAR in (2016) and DQTR in (1,2,3)) then
			ICDVER = 33;
		else if (YEAR in (2016) and DQTR in (4))     then
			ICDVER = 34;
		else if (YEAR in (2017) and DQTR in (1,2,3)) then
			ICDVER = 34;
		else if (YEAR in (2017) and DQTR in (4))     then
			ICDVER = 35;
		else if (YEAR in (2018) and DQTR in (1,2,3)) then
			ICDVER = 35;
		else if (YEAR in (2018) and DQTR in (4))     then
			ICDVER = 36;
		else if (YEAR in (2019) and DQTR in (1,2,3)) then
			ICDVER = 36;
		else if (YEAR in (2019) and DQTR in (4))     then
			ICDVER = 37;
		else if (YEAR in (2020) and DQTR in (1,2,3)) then
			ICDVER = 37;
		else if (YEAR in (2020) and DQTR in (4))     then
			ICDVER = 38;
		else if (YEAR in (2021) and DQTR in (1,2,3)) then
			ICDVER = 38;
		else                                              ICDVER = 38;

		/********************************************/
		/* Establish lengths for all comorbidity    */
		/* flags.                                   */
		/********************************************/
		LENGTH   DXVALUE $20

			AIDS ALCOHOL ANEMDEF ARTH BLDLOSS CANCER_LYMPH CANCER_LEUK CANCER_METS CANCER_NSITU 
			CANCER_SOLID CBVD_SQLA CBVD_POA CBVD_NPOA CBVD CHF COAG DEMENTIA DEPRESS DIAB_UNCX 
			DIAB_CX DRUG_ABUSE HTN_CX HTN_UNCX  LIVER_MLD LIVER_SEV LUNG_CHRONIC NEURO_MOVT 
			NEURO_OTH NEURO_SEIZ OBESE PARALYSIS PERIVASC PSYCHOSES PULMCIRC RENLFL_MOD RENLFL_SEV
			THYROID_HYPO THYROID_OTH ULCER_PEPTIC VALVE WGHTLOSS  3.
		;

		/********************************************/
		/* Create diagnosis and comorbidity arrays  */
		/* for all comorbidity flags.               */
		/********************************************/
		ARRAY DX        (&NUMDX) $  dgns_1_cd--dgns_&NUMDX._cd; /*I10_DX1 - I10_DX&NUMDX;*/
		ARRAY COMANYPOA  (20) AIDS ALCOHOL ARTH LUNG_CHRONIC DEMENTIA DEPRESS DIAB_UNCX DIAB_CX DRUG_ABUSE HTN_UNCX 
			HTN_CX THYROID_HYPO THYROID_OTH CANCER_LYMPH CANCER_LEUK CANCER_METS OBESE 
			PERIVASC CANCER_SOLID CANCER_NSITU;
		ARRAY COMPOA     (19) ANEMDEF BLDLOSS CHF COAG LIVER_MLD LIVER_SEV NEURO_MOVT NEURO_SEIZ
			NEURO_OTH PARALYSIS PSYCHOSES PULMCIRC RENLFL_MOD RENLFL_SEV ULCER_PEPTIC 
			WGHTLOSS CBVD_POA CBVD_SQLA VALVE;
		ARRAY VALANYPOA  (20) $13 A1-A20 
			("AIDS"        "ALCOHOL"   "ARTH"     "LUNG_CHRONIC"  "DEMENTIA"      "DEPRESS"       "DIAB_UNCX"     "DIAB_CX" 
			"DRUG_ABUSE"  "HTN_UNCX"  "HTN_CX"   "THYROID_HYPO"  "THYROID_OTH"   "CANCER_LYMPH"  "CANCER_LEUK"  
			"CANCER_METS" "OBESE"     "PERIVASC" "CANCER_SOLID"  "CANCER_NSITU"  );

		/****************************************************/
		/* If POA flags are available, create POA, exempt,  */
		/* and value arrays.                                */
		/****************************************************/
		%if &POA. = 1 %then
			%do;
				ARRAY EXEMPTPOA (&NUMDX)  EXEMPTPOA1 - EXEMPTPOA&NUMDX;
				ARRAY DXPOA     (&NUMDX) $  poa_dgns_1_ind_cd--poa_dgns_&NUMDX._ind_cd;/*DXPOA1 - DXPOA&NUMDX;*/
				ARRAY VALPOA    (19) $13 B1-B19
					("ANEMDEF"     "BLDLOSS"      "CHF"        "COAG"       "LIVER_MLD"  "LIVER_SEV"  
					"NEURO_MOVT"  "NEURO_SEIZ"   "NEURO_OTH"  "PARALYSIS"  "PSYCHOSES"  "PULMCIRC"   "RENLFL_MOD" 
					"RENLFL_SEV"  "ULCER_PEPTIC" "WGHTLOSS"   "CBVD_POA"   "CBVD_SQLA"  "VALVE");
			%end;

		/****************************************************/
		/* Initialize POA independent comorbidity flags to  */
		/* zero.                                            */
		/****************************************************/
		DO I = 1 TO 20;
			COMANYPOA(I) = 0;
		END;

		/****************************************************/
		/* IF POA flags are available, initialize POA       */
		/* dependent comorbidiy flags to zero. If POA flags */
		/* are not available, these fields will be default  */
		/* to missing.                                      */
		/****************************************************/
		%if &POA. = 1 %then
			%do;
				DO I = 1 TO 19;
					COMPOA(I) = 0;
				END;

				CBVD_NPOA   = 0;
				CBVD        = 0;
				EXEMPTPOA1  = 0;
			%end;
		%else
			%do;
				CBVD_NPOA   = .;
				CBVD        = .;
			%end;

		/****************************************************/
		/* Examine each secondary diagnosis on a record and */
		/* assign comorbidity flags.                        */
		/* 1) Assign comorbidities which are neutral to POA */
		/*    reporting.                                    */
		/* 2) IF POA flags are available, assign            */
		/*    comorbidities that require a diagnosis be     */
		/*    present on admission and are not exempt from  */
		/*    POA reporting.                                */
		/* 3) IF POA flags are available, assign one        */
		/*    comorbidity that requires that the diagnosis  */
		/*    NOT be present admission.                     */
		/****************************************************/
		DO I = 2 TO &NUMDX;/*MIN(I10_NDX, &NUMDX);*/
			IF DX(I) NE " " THEN
				DO;
					DXVALUE = PUT(DX(I),COMFMT.);

					/****************************************************/
					/*   Assign Comorbidities that are neutral to POA   */
					/****************************************************/
					DO J = 1 TO 20;
						IF DXVALUE = VALANYPOA(J) THEN
							COMANYPOA(J) = 1;
					END;

					IF DXVALUE = "DRUG_ABUSEPSYCHOSES" THEN
						DRUG_ABUSE= 1;

					IF DXVALUE = "CHFHTN_CX" THEN
						HTN_CX    = 1;

					IF DXVALUE = "HTN_CXRENLFL_SEV" THEN
						HTN_CX    = 1;

					IF DXVALUE = "CHFHTN_CXRENLFL_SEV" THEN
						HTN_CX    = 1;

					IF DXVALUE = "ALCOHOLLIVER_MLD" THEN
						ALCOHOL   = 1;

					%if &POA. = 1 %then
						%do;
							/****************************************************/
							/* IF POA flags are available, assign comorbidities */
							/* requiring POA that are also not exempt from POA  */
							/* reporting.                                       */
							/****************************************************/
							EXEMPTPOA(I) = 0;

							IF (ICDVER = 38 AND PUT(DX(I),$poaxmpt_v38fmt.)='1') OR
								(ICDVER = 37 AND PUT(DX(I),$poaxmpt_v37fmt.)='1') OR
								(ICDVER = 36 AND PUT(DX(I),$poaxmpt_v36fmt.)='1') OR
								(ICDVER = 35 AND PUT(DX(I),$poaxmpt_v35fmt.)='1') OR
								(ICDVER = 34 AND PUT(DX(I),$poaxmpt_v34fmt.)='1') OR
								(ICDVER = 33 AND PUT(DX(I),$poaxmpt_v33fmt.)='1') THEN
								EXEMPTPOA(I) = 1;

							/**** Flag record if diagnosis is POA exempt or requires POA and POA indicates present on admission (Y or W) ****/
							IF (EXEMPTPOA(I) = 1)  or (EXEMPTPOA(I) = 0 AND DXPOA(I) IN ("Y","W")) THEN
								DO;
									DO K = 1 TO 19;
										IF DXVALUE = VALPOA(K) THEN
											COMPOA(K) = 1;
									END;

									IF DXVALUE = "DRUG_ABUSEPSYCHOSES" THEN
										PSYCHOSES  = 1;

									IF DXVALUE = "CHFHTN_CX" THEN
										CHF        = 1;

									IF DXVALUE = "HTN_CXRENLFL_SEV" THEN
										RENLFL_SEV = 1;

									IF DXVALUE = "CHFHTN_CXRENLFL_SEV" THEN
										DO;
											CHF        = 1;
											RENLFL_SEV = 1;
										END;

									IF DXVALUE = "CBVD_SQLAPARALYSIS" THEN
										DO;
											PARALYSIS = 1;
											CBVD_SQLA = 1;
										END;

									IF DXVALUE = "ALCOHOLLIVER_MLD" THEN
										LIVER_MLD = 1;
								END;

							/****************************************************/
							/* IF POA flags are available, assign comorbidities */
							/* requiring that the diagnosis is not POA          */
							/****************************************************/
							IF (EXEMPTPOA(I) = 0 AND DXPOA(I) IN ("N","U")) THEN
								DO;
									IF DXVALUE = "CBVD_POA" THEN
										CBVD_NPOA = 1;
								END;
						%end;
				END;
		END;

		/****************************************************/
		/* Implement exclusions for comorbidities that are  */
		/* neutral to POA.                                  */
		/****************************************************/
		IF DIAB_CX      = 1 then
			DIAB_UNCX   = 0;

		IF HTN_CX       = 1 then
			HTN_UNCX    = 0;

		IF CANCER_METS  = 1 THEN
			DO;
				CANCER_SOLID = 0;
				CANCER_NSITU = 0;
			END;

		IF CANCER_SOLID = 1 then
			CANCER_NSITU = 0;

		/****************************************************/
		/* IF POA flags are available, implement exclusions */
		/* for comorbidities requiring POA.                 */
		/****************************************************/
		%if &POA. = 1 %then
			%do;
				IF LIVER_SEV    = 1 then
					LIVER_MLD   = 0;

				IF RENLFL_SEV   = 1 then
					RENLFL_MOD  = 0;

				IF (CBVD_POA=1) or (CBVD_POA=0 and CBVD_NPOA=0 and CBVD_SQLA=1) then
					CBVD = 1;
			%end;

		LABEL
			AIDS         = 'Acquired immune deficiency syndrome' 
			ALCOHOL      = 'Alcohol abuse'    
			ANEMDEF      = 'Deficiency anemias'      
			ARTH         = 'Arthropathies'
			BLDLOSS      = 'Chronic blood loss anemia'   
			CANCER_LEUK  = 'Leukemia'
			CANCER_LYMPH = 'Lymphoma'
			CANCER_METS  = 'Metastatic cancer'
			CANCER_NSITU = 'Solid tumor without metastasis, in situ'
			CANCER_SOLID = 'Solid tumor without metastasis, malignant' 
			CBVD         = 'Cerebrovascular disease'
			CBVD_NPOA    = 'Cerebrovascular disease, not on admission'
			CBVD_POA     = 'Cerebrovascular disease, on admission'
			CBVD_SQLA    = 'Cerebrovascular disease, sequela'
			CHF          = 'Congestive heart failure'
			COAG         = 'Coagulopthy' 
			DEMENTIA     = 'Dementia'
			DEPRESS      = 'Depression'
			DIAB_CX      = 'Diabetes with chronic complications'
			DIAB_UNCX    = 'Diabetes without chronic complications'
			DRUG_ABUSE   = 'Drug abuse'
			HTN_CX       = 'Hypertension, complicated' 
			HTN_UNCX     = 'Hypertension, uncomplicated'
			LIVER_MLD    = 'Liver disease, mild'
			LIVER_SEV    = 'Liver disease, moderate to severe'
			LUNG_CHRONIC = 'Chronic pulmonary disease'
			NEURO_MOVT   = 'Neurological disorders affecting movement'
			NEURO_OTH    = 'Other neurological disorders' 
			NEURO_SEIZ   = 'Seizures and epilepsy'            
			OBESE        = 'Obesity'    
			PARALYSIS    = 'Paralysis'
			PERIVASC     = 'Peripheral vascular disease'
			PSYCHOSES    = 'Psychoses'
			PULMCIRC     = 'Pulmonary circulation disease'    
			RENLFL_MOD   = 'Renal failure, moderate'
			RENLFL_SEV   = 'Renal failure, severe' 
			THYROID_HYPO = 'Hypothyroidism'
			THYROID_OTH  = 'Other thyroid disorders'
			ULCER_PEPTIC = 'Peptic ulcer disease x bleeding'     
			VALVE        = 'Valvular disease'
			WGHTLOSS     = 'Weight loss'         
		;
	RUN;

%mend comorbidity;

%comorbidity;

/***********************************/
/*  Means on comorbidity variables */
/***********************************/
PROC MEANS DATA=&output  N NMISS MEAN STD MIN MAX;
	VAR    
		AIDS ALCOHOL ANEMDEF ARTH BLDLOSS CANCER_LYMPH CANCER_LEUK CANCER_METS CANCER_NSITU 
		CANCER_SOLID CBVD CHF COAG DEMENTIA DEPRESS DIAB_UNCX 
		DIAB_CX DRUG_ABUSE HTN_CX HTN_UNCX  LIVER_MLD LIVER_SEV LUNG_CHRONIC NEURO_MOVT 
		NEURO_OTH NEURO_SEIZ OBESE PARALYSIS PERIVASC PSYCHOSES PULMCIRC RENLFL_MOD RENLFL_SEV
		THYROID_HYPO THYROID_OTH ULCER_PEPTIC VALVE WGHTLOSS;
	TITLE3 'Means of Comorbidity Variables';
RUN;

/* edit: comorbidity score */
%let nv_ = 29;

%macro get_cmscore(
			aids_    =AIDS, 
			alcohol_ =ALCOHOL,       
			anemdef_ =ANEMDEF,       
			arth_    =ARTH,          
			bldloss_ =BLDLOSS,       
			chf_     =CHF,           
			chrnlung_=CHRNLUNG,      
			coag_    =COAG,          
			depress_ =DEPRESS,       
			dm_      =DM,            
			dmcx_    =DMCX,          
			drug_    =DRUG,          
			htn_c_   =HTN_C,         
			hypothy_ =HYPOTHY,       
			liver_   =LIVER,         
			lymth_   =LYMPH,         
			lytes_   =LYTES,         
			mets_    =METS,         
			neuro_   =NEURO,         
			obese_   =OBESE,         
			para_    =PARA,          
			perivasc_=PERIVASC,      
			psych_   =PSYCH,         
			pulmcirc_=PULMCIRC,      
			renlfail_=RENLFAIL,      
			tumor_   =TUMOR,         
			ulcer_   =ULCER,         
			valve_   =VALVE,         
			wghtloss_=WGHTLOSS,      
			mscore_=mortal_score
			);
	/***********************************************************/
	/*  Mortality Weights for calculating scores               */
	/***********************************************************/
	mwAIDS      =    0;
	mwALCOHOL   =   -1;
	mwANEMDEF   =   -2;
	mwARTH      =    0;
	mwBLDLOSS   =   -3;
	mwCHF       =    9;
	mwCHRNLUNG  =    3;
	mwCOAG      =   11;
	mwDEPRESS   =   -5;
	mwDM        =    0;
	mwDMCX      =   -3;
	mwDRUG      =   -7;
	mwHTN_C     =   -1;
	mwHYPOTHY   =    0;
	mwLIVER     =    4;
	mwLYMPH     =    6;
	mwLYTES     =   11;
	mwMETS      =   14;
	mwNEURO     =    5;
	mwOBESE     =   -5;
	mwPARA      =    5;
	mwPERIVASC  =    3;
	mwPSYCH     =   -5;
	mwPULMCIRC  =    6;
	mwRENLFAIL  =    6;
	mwTUMOR     =    7;
	mwULCER     =    0;
	mwVALVE     =    0;
	mwWGHTLOSS  =    9;
	array cmvars(&nv_) 	&aids_    &alcohol_  &anemdef_ &arth_     &bldloss_  &chf_     &chrnlung_ &coag_    &depress_ &dm_      
		&dmcx_    &drug_     &htn_c_   &hypothy_  &liver_    &lymth_   &lytes_    &mets_    &neuro_   &obese_   
		&para_    &perivasc_ &psych_   &pulmcirc_ &renlfail_ &tumor_   &ulcer_    &valve_   &wghtloss_
	;
		array mwcms(&nv_) 	mwAIDS    mwALCOHOL  mwANEMDEF mwARTH     mwBLDLOSS   mwCHF    mwCHRNLUNG  mwCOAG    mwDEPRESS  mwDM            
		mwDMCX    mwDRUG     mwHTN_C   mwHYPOTHY  mwLIVER     mwLYMPH  mwLYTES     mwMETS    mwNEURO    mwOBESE         
		mwPARA    mwPERIVASC mwPSYCH   mwPULMCIRC mwRENLFAIL  mwTUMOR  mwULCER     mwVALVE   mwWGHTLOSS      
	;
	array ocms(&nv_)  	oAIDS     oALCOHOL   oANEMDEF  oARTH      oBLDLOSS    oCHF     oCHRNLUNG   oCOAG     oDEPRESS   oDM            
		oDMCX     oDRUG      oHTN_C    oHYPOTHY   oLIVER      oLYMPH   oLYTES      oMETS     oNEURO     oOBESE         
		oPARA     oPERIVASC  oPSYCH    oPULMCIRC  oRENLFAIL   oTUMOR   oULCER      oVALVE    oWGHTLOSS      
	;

	*****Calculate mortality score;
	do i = 1 to &nv_;
		ocms[i]=cmvars[i]*mwcms[i];
	end;

	&mscore_ = sum(of ocms[*]);

	***drop all intermediate variables;
	drop mw: o: i;
%mend;

data &output; 
	set &output; 
	%get_cmscore; 
run; 

/****************************************/
/*  Frequency of comorbidity variables  */
/****************************************/ 
PROC FREQ DATA=&output;
  TABLE  mortal_score
       / LIST MISSING;
  TITLE3 'Frequency of comorbidity variables';
RUN;

