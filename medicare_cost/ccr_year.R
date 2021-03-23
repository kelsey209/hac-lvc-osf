# annualise CCR from cost reports
# kelsey chalmers 2020
# project: HAC and LVC

library(here)
setwd(here())
library(tidyverse)
library(magrittr)
library(DescTools)

year_input = 2018

#----------------------------------------------------------------------#
# data #

cost_report_files <- "G:/Shared drives/AV Med Overuse/1_HACS and LVC/cms downloads/cost reports"

prvdr_2015 <- read_tsv(file=file.path(cost_report_files,"table_2015.txt"))
prvdr_2016 <- read_tsv(file=file.path(cost_report_files,"table_2016.txt"))
prvdr_2017 <- read_tsv(file=file.path(cost_report_files,"table_2017.txt"))
prvdr_2018 <- read_tsv(file=file.path(cost_report_files,"table_2018.txt"))
prvdr_2019 <- read_tsv(file=file.path(cost_report_files,"table_2019.txt"))

#----------------------------------------------------------------------#
# get any overlap for year_input #

overlap_year_filter <- function(provider_table,year_input){
  start_year = as.Date(paste0(year_input,"-01-01"))
  end_year = as.Date(paste0(year_input,"-12-31"))
  
  provider_table %<>%
    rowwise() %>%
    mutate(overlap_year = Overlap(c(fy_bgn_dt,fy_end_dt),c(start_year,end_year))) %>%
    ungroup() %>%
    filter(overlap_year != 0)
  
  return(provider_table)
}

prvdr_2015 %<>% overlap_year_filter(year_input = year_input)
prvdr_2016 %<>% overlap_year_filter(year_input = year_input)
prvdr_2017 %<>% overlap_year_filter(year_input = year_input)
prvdr_2018 %<>% overlap_year_filter(year_input = year_input)
prvdr_2019 %<>% overlap_year_filter(year_input = year_input)

#----------------------------------------------------------------------#
# get unique sums by providers within tables  #

provider_grouped <- function(provider_table){
  provider_table %<>% 
    group_by(prvdr_num) %>% 
    summarise(overlap_year = sum(overlap_year),
              capitalCharge = sum(capitalCharge,na.rm=T),
              capitalCost = sum(capitalCost,na.rm=T),
              InpOperatingCharge = sum(InpOperatingCharge,na.rm=T),
              InpOperatingCost = sum(InpOperatingCost,na.rm=T))
  return(provider_table)
}

prvdr_2015 %<>% provider_grouped()
prvdr_2016 %<>% provider_grouped()
prvdr_2017 %<>% provider_grouped()
prvdr_2018 %<>% provider_grouped()
prvdr_2019 %<>% provider_grouped()

#----------------------------------------------------------------------#
# get values by overlap in year_input #

# 2016 was a leap year
total_days = ifelse(year_input==2016,365,364)

adj_year_cal <- function(provider_table){
  provider_table %<>% 
    mutate(adj_year = round(overlap_year/total_days,2)) %>% 
    rowwise() %>%
    mutate_at(vars(capitalCharge,capitalCost,InpOperatingCharge,InpOperatingCost),
              list(adj=~.*adj_year)) %>%
    ungroup()
  return(provider_table)
}

prvdr_2015 %<>% adj_year_cal()
prvdr_2016 %<>% adj_year_cal()
prvdr_2017 %<>% adj_year_cal()
prvdr_2018 %<>% adj_year_cal()
prvdr_2019 %<>% adj_year_cal()

#----------------------------------------------------------------------#
# join by providers #

provider_table <- full_join(prvdr_2015,prvdr_2016,by="prvdr_num",suffix=c("","_16")) %>%
  full_join(prvdr_2017,by="prvdr_num",suffix=c("","_17")) %>% 
  full_join(prvdr_2018,by="prvdr_num",suffix=c("","_18")) %>% 
  full_join(prvdr_2019,by="prvdr_num",suffix=c("","_19"))

# period covered in total 

provider_table %<>% 
  rowwise() %>%
  mutate(cvrd_ttl = rowSums(across(contains("adj_year")),na.rm = T)) %>% 
  ungroup()

## check if anything is greater than one
print("fraction of year covered")
print(summary(provider_table$cvrd_ttl))

#----------------------------------------------------------------------#
# add totals #

output_table <- provider_table %>%
  mutate(output_OperatingCost = rowSums(across(contains("InpOperatingCost_adj")),na.rm = T),
         output_OperatingCharge = rowSums(across(contains("InpOperatingCharge_adj")),na.rm = T),
         output_CapitalCost = rowSums(across(contains("capitalCost_adj")),na.rm=T),
         output_CapitalCharge = rowSums(across(contains('capitalCharge_adj')),na.rm=T)) %>%
  mutate_at(vars(contains("output_")),list(~if_else(.==0,as.double(NA),.))) %>% 
  select(contains("prvdr_num") | contains("output_") | contains("cvrd_ttl")) %>% 
  # cost to charge ratios: 
  rowwise() %>% 
  mutate(Operating_CCR = output_OperatingCost/output_OperatingCharge,
         Capital_CCR = output_CapitalCost/output_OperatingCharge) %>% 
  mutate(Medicare_CCR = Operating_CCR + Capital_CCR) %>% ungroup()


write_tsv(output_table,path=file.path("G:/Shared drives/AV Med Overuse/1_HACS and LVC/cms downloads/cost reports",
                                      paste0("provider_table_",year_input,".txt")))
