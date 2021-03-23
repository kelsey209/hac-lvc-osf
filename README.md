# Analysis code: measuring hospital acquired harms associated with low-value care

Kelsey Chalmers, Lown Institute. 2020-2021. 

# Create cohorts and outcomes
`top_run.sas`: top level file to set up the SAS environment, run the cohort selection and outcomes. Calls the following files and macros they create.

## Low-value care
`lvc_label.sas`: applies criteria for overuse cases in outpatient and inpatient.

This program requires `lvc_definitions.xslx`, the definition code list of the included low-value services.

## Criteria: principal procedure label
`pri_procedure.sas`: Creates the label for the principal procedure for each admission. 

## Harms: HACs
`hac_label.sas`: applies HAC codes/criteria on admissions.

This program requires `hac_{xx}_{name}.xlsx` The HAC codes from CMS. Includes: 
- hac_01_foreignobject.xlsx
- hac_02_airembolism.xlsx
- hac_03_bloodinc.xlsx
- hac_04_pressureulc.xlsx
- hac_05_falls.xlsx
- hac_06_cauti.xlsx 
- hac_07_vcai.xlsx
- hac_09_glycemic.xlsx
- hac_12_ssi_ortho.xlsx  
- hac_13_ssi_cardio.xlsx
- hac_14_pneumothorax.xlsx

## Harms: PSIs
`psi_label.sas`: applies the PSI codes/criteria on admissions. 

This is from the AHRQ PSI Safety Indicators SAS software. 

It requires the formats created by `psi_hosp_formats.sas`, as well as the macros created in `psi_macros.sas`.

## Outpatient 7-day hospital admissions
`hospitalvisit_outpatient_lavel.sas`: finds the unplanned inpatient hospital admissions within 7-days from a low-value outpatient procedure. 

This program requires the CCS codes, which are created as a format from `ccs_dx_icd10cm_2019_1.csv` (diagnoses) and `ccs_pr_icd10pcs_2019_2.csv` (procedures). 

These codes are combined based on the Yale New Haven measures, which are recorded in the table `unplanned_admissions.xslx`. This is converted to formats in `css_formats.sas`.

# Create outputs for paper
These functions create the required output from the CMS Virtual Research Data Center. 

## Cohort description
`figure_1_cohort.sas`: creates cohort counts used in figure 1. 

## Outpatient procedure counts and outcomes
`table_1_outpatient.sas`: creates counts by service for the unplanned admissions, HACs and PSIs for the included outpatient admissions. Creates confidence intervals based on bootstrapped random samples.  

## Inpatient procedure counts and outcomes
`table_2_inpatient.sas`: creates counts by service for the HACs and PSIs for the included inpatient admissions. Creates confidence intervals based on bootstrapped random samples. 

## Individual PSI counts by inpatient procedures
`table_3_psi.sas`: creates counts by PSI and service for included inpatient admissions. Creates confidence intervals based on bootstrapped random samples. 

## Costs and LOS for inpatient procedures
`table_4_costs_los.sas`: creates the estimated length of stay (LOS) and costs for admissions with and without a HAC.  

Uses AHRQ programs to create Elixhauser comorbidity labels: 
- `comorb_icd_10cm_analy_v20211.sas`
- `comorb_icd10cm_format_v20211.sas`

Uses the cost to charge ratio file for providers, `output__CCR.csv` (can be created using the R functions in the `medicare_cost` folder).

### Medicare cost to charge ratios
Within `medicare_cost` folder, there are three R functions. 
- `medicare_cost.R` takes the downloaded cost reports for each year and finds the relevant information to calculate cost to charge ratio.
- `ccr_year.R` creates the annualised CCRs.
- `ccr_threeyears.R` outputs the provider tables with full CCRs for 2016 to 2018, the study period. 


## Other outputs
`output_paper.sas`: creates other counts reported in main text.


# Miscellaneous
- `do_over.sas`: Very handy macro from Ted Clay and David Katz that makes SAS coding over different variables much easier. 




