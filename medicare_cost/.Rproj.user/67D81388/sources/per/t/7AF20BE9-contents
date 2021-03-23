# compare CCR across years
# kelsey chalmers 2020
# project: HAC and LVC

library(here)
setwd(here())
library(tidyverse)
library(magrittr)

#----------------------------------------------------------------------#
# data #

cost_report_files <- "G:/Shared drives/AV Med Overuse/1_HACS and LVC/cms downloads/cost reports"

prvdr_2016 <- read_tsv(file=file.path(cost_report_files,"provider_table_2016.txt"))
prvdr_2017 <- read_tsv(file=file.path(cost_report_files,"provider_table_2017.txt"))
prvdr_2018 <- read_tsv(file=file.path(cost_report_files,"provider_table_2018.txt"))

prvdr_full <- prvdr_2016 %>% 
  full_join(prvdr_2017,by="prvdr_num",suffix=c("","_17")) %>%  
  full_join(prvdr_2018,by="prvdr_num",suffix=c("","_18"))

prvdr_CCR <- prvdr_full %>% 
  pivot_longer(cols = contains("Medicare_CCR"),names_to = "year",values_to = "CCR")  %>% 
  select(prvdr_num,year,CCR)

# clean up year column
prvdr_CCR %<>% 
  rowwise() %>% 
  mutate(year = case_when(grepl("17",year)==1 ~ "2017",
                          grepl("18",year)==1 ~ "2018",
                          grepl("18",year)==0 & grepl("17",year)==0 ~ "2016")) %>% 
  ungroup()

#----------------------------------------------------------------------#
# replace values #
acceptable_range <- with(prvdr_CCR,quantile(CCR,probs=c(.05,0.95),na.rm=T))

print("acceptable range")
print(acceptable_range)

prvdr_CCR %<>% 
  rowwise() %>% 
  mutate(CCR_rm_extrm = if_else(between(CCR,acceptable_range[1],acceptable_range[2]),
                                      CCR,as.double(NA))) %>% 
  ungroup()

# replace some missing values by the average CCR over the three years
prvdr_CCR %<>% 
  group_by(prvdr_num) %>%
  mutate(ave_CCR = mean(CCR_rm_extrm,na.rm = T)) %>% 
  ungroup() %>% 
  mutate(CCR_r = if_else(is.na(CCR),ave_CCR,CCR))

print("Provider-years with replaced values:")
print(with(prvdr_CCR,sum(is.na(CCR)))-with(prvdr_CCR,sum(is.na(CCR_r))))

prvdr_CCR %<>%
  mutate(CCR_r = if_else(is.nan(CCR_r),as.double(NA),CCR_r))


#----------------------------------------------------------------------#
# replace missing values by the state average #

ref_state <- read_csv(file = file.path(cost_report_files,"HCRIS_STATE_CODES.csv"))

prvdr_CCR %<>% 
  mutate(state_cd = substr(prvdr_num,1,2))

prvdr_CCR %<>%
  left_join(ref_state,by=c("state_cd"="Ssa_State_Cd"))

prvdr_CCR %<>%
  group_by(State_Name,year) %>% 
  mutate(ave_state = mean(CCR,na.rm=T)) %>% 
  ungroup()

prvdr_CCR %<>%
  rowwise() %>% 
  mutate(CCR_s = if_else(is.na(CCR_r),ave_state,CCR_r)) %>%
  ungroup()

prvdr_CCR %<>%
  mutate_if(is.numeric,list(~if_else(is.nan(.),as.double(NA),.)))

write_csv(prvdr_CCR,na="",path = file.path(cost_report_files,"output__CCR.csv"))
  