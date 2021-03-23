*********************************************************************************;
* program name: ccs_formats.sas ;
* project: hac and lvc ;
* description: this is required for the unplanned hospital admission label 
(in hospitalvisit_outpatient_label.sas). this has been modified from the clinical classifications software
for icd-10-pcs (from hcup ahrq): https://www.hcup-us.ahrq.gov/toolssoftware/ccs10/ccs10.jsp#download;
** note using latest version: 2019.2
for icd-10-cm: arhq has updated to using ccsr, but the op-36 file still uses the 
ccs, which can be downloaded (as of today) here: https://www.hcup-us.ahrq.gov/toolssoftware/ccs10/ccs_dx_icd10cm_2019_1.zip; 
*********************************************************************************;

* Path & name for the ICD-10-CM/PCS CCS tool ;
FILENAME INRAW1  "&code_files/ccs_dx_icd10cm_2019_1.csv" 			LRECL=300;
FILENAME INRAW2  "&code_files/ccs_pr_icd10pcs_2019_2.csv" 		LRECL=300; 

/* Diagnoses CCS */
DATA DXCCS (keep=fmtname start label type hlo);
    INFILE INRAW1 DSD DLM=',' END = EOF FIRSTOBS=2;
    INPUT
       START            : $CHAR7.
       LABEL            : $CHAR4.
       ICD10CM_label    : $CHAR100.
       CCS_Label        : $CHAR100.
       Multi_lvl1       : $CHAR2.
       Multi_lvl1_label : $CHAR100.
       Multi_lvl2       : $CHAR5.
       Multi_lvl2_label : $CHAR100.
    ;
	*format label $char4.;
	RETAIN HLO " ";
   FMTNAME = "$I10DXCCS" ;
   TYPE    = "C" ;
   OUTPUT;

   IF EOF THEN DO ;
      START = " " ;
      LABEL = "0" ;
      HLO   = "O";
      OUTPUT ;
   END ;
RUN;

PROC FORMAT LIB=&mylib. CNTLIN = DXCCS;
RUN;

/* Procedures CCS */
DATA PRCCS (keep=fmtname start label type hlo); ;
    INFILE INRAW2 DSD DLM=',' END = EOF FIRSTOBS=2;
    INPUT
       START            : $CHAR7.
       LABEL            : $CHAR4.
       ICD10PCS_label   : $CHAR100.
       CCS_Label        : $CHAR100.
       Multi_lvl1       : $CHAR2.
       Multi_lvl1_label : $CHAR100.
       Multi_lvl2       : $CHAR5.
       Multi_lvl2_label : $CHAR100.
    ;
	*format label $char4.;
   RETAIN HLO " ";
   FMTNAME = "$I10PRCCS" ;
   TYPE    = "C" ;
   OUTPUT;

   IF EOF THEN DO ;
      START = " " ;
      LABEL = "0";
      HLO   = "O";
      OUTPUT ;
   END ;
RUN;

PROC FORMAT LIB= &mylib. CNTLIN = PRCCS ;
RUN;

/**************************************************************************/
/* Procedures CCS */

* create lists for ccs and diagnosis codes ; 
proc import out = gref__pa_defs
    datafile = "&code_files/unplanned_admissions"
    dbms = xlsx replace;
    getnames = yes; 
run; 

data gref__pa_defs;
	set gref__pa_defs;
	label = 1; 
	code = compress(code,'.'); 
	rename type = code_type; 
run;

data fmt__pa3_icd_defs;
	set gref__pa_defs (where=(table eq 'pa3' and code_type in: ('ICD-10'))
		rename=(code = start)) end=last; 
	retain fmtname '$pa3_icd' type 'C'; 
	output; 
	if last then do; 
		hlo = 'O'; 
		label = 0;
		output; 
	end; 
	keep fmtname type start label hlo; 
run; 

proc format lib = &mylib. cntlin=fmt__pa3_icd_defs;
run; 

data fmt__pa3_ccs_defs;
	set gref__pa_defs (where=(table eq 'pa3' and code_type in: ('CCS'))
		rename=(code = start)) end=last; 
	retain fmtname '$pa3_ccs' type 'C'; 
	output; 
	if last then do; 
		hlo = 'O'; 
		label = 0;
		output; 
	end; 
	keep fmtname type start label hlo; 
run; 

proc format lib = &mylib. cntlin=fmt__pa3_ccs_defs;
run; 

data fmt__pa4_icd_defs;
	set gref__pa_defs (where=(table eq 'pa4' and code_type in: ('ICD-10'))
		rename=(code = start)) end=last; 
	retain fmtname '$pa4_icd' type 'C'; 
	output; 
	if last then do; 
		hlo = 'O'; 
		label = 0;
		output; 
	end; 
	keep fmtname type start label hlo; 
run; 

proc format lib = &mylib. cntlin=fmt__pa4_icd_defs;
run; 

data fmt__pa4_ccs_defs;
	set gref__pa_defs (where=(table eq 'pa4' and code_type in: ('CCS'))
		rename=(code = start)) end=last; 
	retain fmtname '$pa4_ccs' type 'C'; 
	output; 
	if last then do; 
		hlo = 'O'; 
		label = 0;
		output; 
	end; 
	keep fmtname type start label hlo; 
run; 

proc format lib = &mylib. cntlin=fmt__pa4_ccs_defs;
run; 

