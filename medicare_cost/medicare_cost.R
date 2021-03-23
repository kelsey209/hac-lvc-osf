# get medicare cost to charge ratio from cost reports
# kelsey chalmers 2020
# project: HAC and LVC

# cost table rules: 
# https://www.cms.gov/Regulations-and-Guidance/Guidance/Manuals/downloads/clm104c03.pdf

# https://www.resdac.org/articles/medicare-cost-report-data-structure

# have to convert from 2552-96 rules to 2552-10


library(here)
setwd(here())
library(medicare)
# good resource: https://robertgambrel.com/blog/2016/12/01/medicare-cost-report-demo 
library(tidyverse)
library(magrittr)
library(DescTools)
library(lubridate)

# year_input = 2019
# year_input = 2018
# year_input = 2017
# year_input = 2016
year_input = 2015

#----------------------------------------------------------------------#
# data #

alpha_ <- read_csv(paste0("G:/Shared drives/AV Med Overuse/1_HACS and LVC/cms downloads/cost reports/cost report ",
                          year_input,"/hosp10_",year_input,"_ALPHA.csv"),
                   col_names = F)
nmrc_ <- read_csv(paste0("G:/Shared drives/AV Med Overuse/1_HACS and LVC/cms downloads/cost reports/cost report ",
                         year_input,"/hosp10_",year_input,"_NMRC.csv"),
                  col_names = F)
rpt_ <- read_csv(paste0("G:/Shared drives/AV Med Overuse/1_HACS and LVC/cms downloads/cost reports/cost report ",
                        year_input,"/hosp10_",year_input,"_RPT.csv"),
                 col_names = F)

names(alpha_) <- cr_alpha_names()
names(nmrc_) <- cr_nmrc_names()
names(rpt_) <- cr_rpt_names()

#----------------------------------------------------------------------#
# extract provider IDs # 

# The file convention is that the worksheet is always 7 characters, with no 
# punctuation, with trailing 0’s. Rows and columns are always multiplied by 100.

#----------------------------------------------------------------------#
# PPS operating CCR # 

# 1) Identify total Medicare inpatient operating costs from the Medicare cost report, from
# Worksheet D-1, Part II, line 53. (If a positive amount is reported on line 42 for nursery
#                                   costs, subtract this amount on line 42 from the amount on line 53).

# use D10A181 = Title XVIII (from 2552-96 form)
# crosswalk to 2552-10:
# - columns are the same
# - line 53 the same
# - line 42 the same

hosp_operatingCosts <- nmrc_ %>% 
  filter(wksht_cd %in% "D10A181" & line_num %in% c("05300","04200") )
hosp_operatingCosts %<>%
  pivot_wider(id_cols = c("rpt_rec_num","wksht_cd"),names_from="line_num",values_from="itm_val_num")

if(ncol(hosp_operatingCosts) > 3){
  hosp_operatingCosts$`05300` = hosp_operatingCosts$`05300` - hosp_operatingCosts$`04200`
}

hosp_operatingCosts %<>%
  rename(InpOperatingCost = `05300`)

# 2) Identify total Medicare inpatient operating charges (the sum of routine and 
# ancillary charges), from Worksheet D-4, column 2, the sum of lines 25 through 30 and line 103.

# use 96 D40A180 for Title XVIII
# crosswalk: 
# - columns are the same
# - worksheet is D30A180
# - lines 02500 --> 03000 to 03000 --> 03500
# - lines 10300 --> 20200

hosp_operatingCharges <- nmrc_ %>% 
  filter(wksht_cd %in% c("D30A180") & line_num %in% c("03000","03100","03200","03300","03400","03500","20200") & 
           clmn_num %in% c("00200"))

hosp_operatingCharges %<>%
  group_by(rpt_rec_num) %>% 
  summarise(InpOperatingCharge = sum(itm_val_num))

# 3) Determine the Inpatient PPS operating CCR by dividing the amount in step 1 by the
# amount in step 2.

hosp_operatingCCR <- full_join(hosp_operatingCosts,hosp_operatingCharges,by="rpt_rec_num")

### save this step for full provider table 

#----------------------------------------------------------------------#
# Inpatient capital CCR # 

# 1) Identify total Medicare inpatient capital cost from Worksheet D Part 1, column 10,
# sum of lines 25 through 30, plus column 12, sum of lines 25 through 30 plus Medicare
# inpatient ancillary capital costs from Worksheet D Part II, column 6, line 101 plus column 8
# line 101.


# worksheet d part 1 column 10 25--30 

# worksheet d part 1 column 12 25--30

# worksheet d part II column 6 101 + column 8 101

# crosswalk: 
# - worksheet D00A181 --> stays the same
# -- column 1000 --> NOT IN NEW FORM
# --- looking at calculations from table: there is a difference between new capital 
#     and old capital in the old version and the new version. J
# Just use column 00700 (which maps from column 12) - inpatient program capital costs
# -- lines 25:30 --> 03000:03500

# - worksheet D00A182 --> stays the same
# -- column 6 & 8 --> ??? In table, looks like column 5 
# --- line 101: total sum of lines 37-68 --> line 20000

hosp_capitalCost <- nmrc_ %>% 
  filter(wksht_cd %in% c("D00A181") & clmn_num %in% c("00700") & 
           line_num %in% c("03000","03100","03200","03300","03400","03500"))
hosp_capitalCost %<>% 
  group_by(rpt_rec_num) %>%
  summarise(capitalCost1 = sum(itm_val_num))

hosp_capitalCost2 <- nmrc_ %>%
  filter(wksht_cd %in% c("D00A182") & clmn_num %in% c("00500") & 
           line_num %in% c("20000"))
hosp_capitalCost2 %<>% 
  group_by(rpt_rec_num) %>%
  summarise(capitalCost2 = sum(itm_val_num))

hosp_capitalCost <- full_join(hosp_capitalCost,hosp_capitalCost2,by="rpt_rec_num")
hosp_capitalCost %<>% 
  mutate(capitalCost = capitalCost1 + capitalCost2)


# 2) Identify total Medicare inpatient capital charges (the sum of routine and ancillary
# charges), from Worksheet D-4, column 2, the sum of lines 25 through 30 and line 103.

# crosswalk: 
# Worksheet D-4: D40A180 --> Worksheet D-3: D30A180
# columns are the same
# line 02500 - 03000 --> 03000 - 03500

hosp_capitalCharge <- nmrc_ %>% 
  filter(wksht_cd %in% c("D30A180") & clmn_num %in% c("00200") & 
           line_num %in% c("03000","03100","03200","03300","03400","03500"))
hosp_capitalCharge %<>%
  group_by(rpt_rec_num) %>% 
  summarise(capitalCharge = sum(itm_val_num))

# 3) Determine the Inpatient PPS capital CCR by dividing the amount in step 1 by the
# amount in step 2.

hosp_capitalCCR <- full_join(hosp_capitalCharge,hosp_capitalCost %>% select(rpt_rec_num,capitalCost),
                             by="rpt_rec_num")

#----------------------------------------------------------------------#

# full provider table

provider_table <- full_join(rpt_,hosp_capitalCCR,by="rpt_rec_num") %>%
  full_join(hosp_operatingCCR,by="rpt_rec_num")

provider_table %<>%  
  mutate_at(vars(contains("dt")),list(~lubridate::mdy(.))) 

# filter out records that did not overlap in actual year
start_year = as.Date(paste0(year_input,"-01-01"))
end_year = as.Date(paste0(year_input,"-12-31"))

# provider_table %<>%
#   rowwise() %>% 
#   mutate(overlap_year = Overlap(c(fy_bgn_dt,fy_end_dt),c(start_year,end_year))) %>% 
#   ungroup() %>% 
#   filter(overlap_year != 0)

# check for duplication 

provider_table %<>%
  mutate(duplicate_prv = duplicated(prvdr_num))

dup_prvdr <- provider_table %>% filter(duplicate_prv == TRUE) %>% 
  select(prvdr_num) %>% unique() %>% unlist()
  
dup_prvdr_tbl <- provider_table %>% 
  filter(prvdr_num %in% dup_prvdr) 

# are there any overlapping dates? 
dup_prvdr_tbl %>% 
  arrange(prvdr_num,fy_bgn_dt) %>% 
  group_by(prvdr_num) %>% 
  mutate(lag_bgn_dt = lag(fy_bgn_dt),
         lag_end_dt = lag(fy_end_dt)) %>% 
  ungroup() %>%
  rowwise() %>% 
  mutate(overlap_fy = c(fy_bgn_dt,fy_end_dt) %overlaps% c(lag_bgn_dt,lag_end_dt)) %>% 
  ungroup() %>%
  summarise(AnyOverlap = sum(overlap_fy,na.rm=T)) %>% 
  print()

# save table : input for full year values 
write_tsv(provider_table,
          path = file.path("G:/Shared drives/AV Med Overuse/1_HACS and LVC/cms downloads/cost reports",
                           paste0("table_",year_input,".txt")))
                     

  



