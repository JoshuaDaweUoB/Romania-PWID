## load packages
pacman::p_load(dplyr, tidyr, withr, lubridate, writexl, readxl)

## set wd
setwd("C:/Users/vl22683/OneDrive - University of Bristol/Documents/Publications/Romania PWID/data")

## load data
romania_pwid_raw <- read_excel("ARAS DATA IDU 2013-2022.xlsx") 

## baseline HCV cohort

# remove rows where hiv test result is missing
romania_pwid_hcv <- romania_pwid_raw[!is.na(romania_pwid_raw$hcv_test_rslt), ]

# remove rows where hiv test result is indeterminate 
romania_pwid_hcv <- romania_pwid_hcv %>%
  filter(!hcv_test_rslt == 3)

# create sequence of visits by ID
romania_pwid_hcv <- romania_pwid_hcv %>%
  group_by(id) %>%
  arrange(id, appointment_dte) %>%
  mutate(appointment_seq = row_number())

romania_pwid_hcv <- ungroup(romania_pwid_hcv)

# HCV test results by visit
romania_pwid_hcv_summary <- table(romania_pwid_hcv$hcv_test_rslt)
print(romania_pwid_hcv_summary) 

# remove IDs where hcv positive at baseline
ids_to_remove <- romania_pwid_hcv %>%
  filter(appointment_seq == 1 & hcv_test_rslt == 2) %>%
  pull(id)

romania_pwid_hcv <- romania_pwid_hcv %>%
  filter(!(id %in% ids_to_remove))

# HCV test results by visit
romania_pwid_hcv_summary <- table(romania_pwid_hcv$appointment_seq, romania_pwid_hcv$hcv_test_rslt)
print(romania_pwid_hcv_summary) 

# restrict to participants with multiple tests
romania_pwid_hcv <- romania_pwid_hcv %>%
  group_by(id) %>%
  arrange(id) %>%
  mutate(hcv_test_seq = row_number())

# HCV test results by visit
romania_pwid_hcv_summary <- table(romania_pwid_hcv$hcv_test_seq, romania_pwid_hcv$hcv_test_rslt)
print(romania_pwid_hcv_summary) 

# remove participants with only one test
romania_pwid_hcv <- romania_pwid_hcv %>%
  group_by(id) %>%
  filter(!(max(hcv_test_seq, na.rm = TRUE) == 1)) %>%
  ungroup()

# HCV test results by visit
romania_pwid_hcv_summary <- table(romania_pwid_hcv$hcv_test_seq, romania_pwid_hcv$hcv_test_rslt)
print(romania_pwid_hcv_summary) 

# remove hcv tests after first positive
romania_pwid_hcv <- romania_pwid_hcv %>%
  group_by(id) %>%
  mutate(first_hcv_positive_dte = ifelse(hcv_test_rslt == 2, appointment_dte, NA)) %>%
  mutate(first_hcv_positive_dte = min(first_hcv_positive_dte, na.rm = TRUE)) %>%
  ungroup()

romania_pwid_hcv <- romania_pwid_hcv %>%
  filter(is.na(first_hcv_positive_dte) | appointment_dte <= first_hcv_positive_dte)

# HCV test results by visit
romania_pwid_hcv_summary <- table(romania_pwid_hcv$hcv_test_seq, romania_pwid_hcv$hcv_test_rslt)
print(romania_pwid_hcv_summary) 

# create hcv testing dataframe 
romania_pwid_hcv_test <- subset(romania_pwid_hcv, select = c(id, appointment_dte, hcv_test_seq, hcv_test_rslt)) 

# create lag of appointment dates and hcv tests
romania_pwid_hcv_test <- romania_pwid_hcv_test %>%
  arrange(id, hcv_test_seq) %>%  
  group_by(id) %>%
  mutate(appointment_dte_lag = lead(appointment_dte),
         hcv_test_rslt_lag = lead(hcv_test_rslt)) 

# remove empty rows
romania_pwid_hcv_test <- romania_pwid_hcv_test[!is.na(romania_pwid_hcv_test$hcv_test_rslt_lag), ]

# convert to dates
romania_pwid_hcv_test <- romania_pwid_hcv_test %>%
  mutate(appointment_dte = as.Date(appointment_dte, format = "%d-%m-%Y")) %>%
  mutate(appointment_dte_lag = as.Date(appointment_dte_lag, format = "%d-%m-%Y"))

# days at risk
romania_pwid_hcv_test <- romania_pwid_hcv_test %>%
  mutate(days_risk = appointment_dte_lag-appointment_dte)

#romania_pwid_hcv_test <- romania_pwid_hcv_test %>%
#  mutate(days_risk = ifelse(hcv_test_rslt_lag == 2, days_risk / 2, days_risk))

# time of infection

set.seed(123) # Setting a seed for reproducibility

romania_pwid_hcv_test_rand <- romania_pwid_hcv_test %>%
  mutate(
    appointment_dte = as.Date(appointment_dte),
    appointment_dte_lag = as.Date(appointment_dte_lag)
  )

# Update days_risk with random infection date logic
romania_pwid_hcv_test_rand <- romania_pwid_hcv_test_rand %>%
  rowwise() %>%
  mutate(
    # Debugging: Check if condition is met
    condition_met = hcv_test_rslt == 1 & hcv_test_rslt_lag == 2,
    
    # Generate random infection date if condition is met
    random_infection_date = if (condition_met) {
      as.Date(runif(1, as.numeric(appointment_dte), as.numeric(appointment_dte_lag)), origin = "1970-01-01")
    } else {
      NA
    },
    
    # Calculate days at risk based on random infection date
    days_risk = if (condition_met) {
      as.numeric(random_infection_date - appointment_dte)
    } else {
      as.numeric(appointment_dte_lag - appointment_dte)
    }
  ) %>%
  ungroup()

# change test results to 0 and 1
romania_pwid_hcv_test <- romania_pwid_hcv_test %>%
  mutate(hcv_test_rslt_lag = case_when(
  hcv_test_rslt_lag == 1 ~ 0,
  hcv_test_rslt_lag == 2 ~ 1,
  TRUE ~ hcv_test_rslt_lag
))

# calculate midpoint year
romania_pwid_hcv_test <- romania_pwid_hcv_test %>%
  mutate(midpoint_year = appointment_dte_lag + (appointment_dte - appointment_dte_lag) / 2) %>%
  mutate(midpoint_year = year(midpoint_year))

# rename hcv_test_rslt_lag
romania_pwid_hcv_test <- romania_pwid_hcv_test %>%
  select(-hcv_test_rslt) %>%
  rename(hcv_test_rslt = hcv_test_rslt_lag)

# save testing data
write_xlsx(romania_pwid_hcv_test,"hcv_test_data.xlsx")

## exposure data

# keep columns of interest
romania_pwid_hcv_exposure <- subset(romania_pwid_hcv, select = c(id, gender, dob, drug_type, sex_work_current, msm_current, homeless_current, ethnic_roma, hiv, pres_distributed, syringes_distributed_1ml, syringes_distributed_2ml, syringes_recovered)) 

# replace NA with 0
romania_pwid_hcv_exposure <- romania_pwid_hcv_exposure %>%
  mutate(across(c(sex_work_current, msm_current, homeless_current, ethnic_roma, hiv), ~ replace_na(., 0)))

# remove last row per id 
romania_pwid_hcv_exposure <- romania_pwid_hcv_exposure %>%
  arrange(id) %>%
  group_by(id) %>%
  slice(-n())  

# save exposure data
write_xlsx(romania_pwid_hcv_exposure,"hcv_exposure_data.xlsx")

# create analysis df

# sequence by id for merge
romania_pwid_hcv_exposure <- romania_pwid_hcv_exposure %>%
  arrange(id) %>%
  mutate(id_seq = row_number())

romania_pwid_hcv_test <- romania_pwid_hcv_test %>%
  arrange(id) %>%
  mutate(id_seq = row_number())

# merge
romania_pwid_hcv_analysis <- left_join(romania_pwid_hcv_exposure, romania_pwid_hcv_test, by = c("id", "id_seq"))

# remove rows where days at risk is less than 30
romania_pwid_hcv_analysis <- romania_pwid_hcv_analysis %>%
  filter(!days_risk < 30)

# remove rows where days at risk is greater than 730
romania_pwid_hcv_analysis <- romania_pwid_hcv_analysis %>%
  filter(!days_risk > 730)

# make time variables numeric
romania_pwid_hcv_analysis$days_risk <- as.numeric(romania_pwid_hcv_analysis$days_risk)
romania_pwid_hcv_analysis$appointment_dte <- as.numeric(romania_pwid_hcv_analysis$appointment_dte)
romania_pwid_hcv_analysis$appointment_dte_lag <- as.numeric(romania_pwid_hcv_analysis$appointment_dte_lag)

# make exposure variables categorical
romania_pwid_hcv_analysis$midpoint_year <- factor(romania_pwid_hcv_analysis$midpoint_year)

# save data
write_xlsx(romania_pwid_hcv_analysis,"hcv_data_analysis.xlsx")






