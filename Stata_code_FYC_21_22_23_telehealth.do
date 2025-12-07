/********************************************************************************************
   PROJECT:   Youth Telehealth Utilization, MEPS 2021–2023
   AUTHOR:    pYare
   Version:   version 1
   PURPOSE:   Examine socioeconomic and insurance-related disparities in telehealth vs. 
              in-person outpatient care among U.S. children and adolescents.

   RESEARCH QUESTION:
      Among children and adolescents in the United States, do socioeconomic and insurance
      characteristics predict whether telehealth is used as a supplement to—or a substitute
      for—traditional in-person outpatient visits during the post-pandemic period (2021–2023)?

   STUDY MOTIVATION:
      Telehealth expanded rapidly during COVID-19, but it is unclear whether these changes
      persisted and whether all families benefited equally. Higher-income families may have
      used telehealth in addition to in-person visits (supplementation), while lower-income
      families may rely on telehealth in place of traditional encounters (substitution).
      Understanding these patterns is essential for evaluating digital-access and payment-parity
      policies aimed at reducing inequities in pediatric outpatient care.

   DATA:
      Pooled cross-sectional data from MEPS Full-Year Consolidated (FYC) files for 2021–2023
      merged with Office-Based (OB) and Outpatient (OP) event files. Telehealth encounters are
      identified using TELEHEALTHFLAG and aggregated to the person-year level.

   OUTCOMES:
      - any_tele: indicator for any telehealth visit
      - tele_visits: number of telehealth visits
      - inperson_visits: number of in-person OB/OP visits
      - tele_share: telehealth visits / total visits

   ANALYTIC STRATEGY:
      1. Create unified pooled analytic dataset (2021–2023).
      2. Apply MEPS survey design (PSU, strata, person-level weights).
      3. Estimate four main models:
            Model 1: Logistic regression predicting any telehealth use.
            Model 2: Count model (nbreg) predicting number of telehealth visits.
            Model 3: Count model predicting number of in-person visits.
            Model 4: Fractional logit predicting share of visits delivered via telehealth.
      4. Interpret patterns to assess whether telehealth supplements or substitutes for
         in-person care across income and insurance groups.

   EXPECTED CONTRIBUTION:
      Provides nationally representative evidence on whether post-pandemic telehealth
      reduced or reinforced socioeconomic disparities in pediatric outpatient care.

*********************************************************************************************/


**# Step 1. Initialize paths and log
*-- 1. Directory setup  --* 
global projroot "INSERT YOURS"
global datadir   "$projroot/DATA"
global codedir   "$projroot/CODE"
global logdir    "$projroot/LOG"
global outdir    "$projroot/OUTPUT"

*-- 2. Open a dated log file  --*
capture log close
local today = c(current_date)
local logfname = "$logdir/MEPS_merge_setup_2021_" + subinstr("`today'", " ", "_", .) + ".log"
log using "`logfname'", text replace


set more off


**# Step 2 - Merge Plan 
*-- 3. Begin data merging steps  --* 
/*
h233, h243, h251.dta: Full-year consolidated files for 2021, 2022, 2023 (person-level core).
h231, h241, h249.dta: Medical Conditions files for 2021, 2022, 2023.
h229g, h239g, h248g.dta: Office-Based Provider Visits files (2021–2023 event files).
h229f, h239f, h248f.dta: Outpatient Department Visits files (2021–2023 event files).
h229e, h239e, h248e.dta: Emergency Room Visits files (2021–2023 event files).
*/





*******************************
**#  2021 MEPS
/******************************
  MEPS 2021 File Merge
  This code block merges 2021 full-year consolidated file (h233.dta)
  with event-level files: office-based (h229g), outpatient (h229f), 
  emergency (h229e), and sets up for merging with the conditions file (h231).
  All files are assumed to be in your $datadir directory.
  
- h233.dta	Main consolidated person-level file (2021)
- h231.dta	Medical conditions file (2021)
- h229g.dta	Office-based provider visits (2021)
- h229f.dta	Outpatient department visits (2021)
- h229e.dta	Emergency room visits (2021)
***********************************************************************/


**# --> Step 2 h233 - FYC
use "$datadir/xxx.dta", clear

describe DUPERSID DUID // Check format
tostring DUID, replace
sort DUPERSID // Sort 
count // 

describe DUPERSID PERWT21F VARSTR VARPSU AGE21X SEX RACEV2X REGION21 ///
     POVCAT  INSCOV EDUCYR  MARRY21X

foreach v of varlist AGE21X SEX RACEV2X INSCOV ///
                     EDUCYR MARRY21X POVCAT ///
                     REGION21 {
    replace `v' = . if `v' < 0
}	 
	 
* Age continous
gen age  = AGE21X
	 
* Age categories (optional but helpful for models)
gen age_cat = .
replace age_cat = 1 if AGE21X < 6
replace age_cat = 2 if AGE21X >= 6 & AGE21X <= 11
replace age_cat = 3 if AGE21X >= 12 & AGE21X <= 17
replace age_cat = 4 if AGE21X >= 18

label define agecatlbl 1 "<6" 2 "6–11" 3 "12–17" 4 "18+"
label values age_cat agecatlbl

* Gender
gen female = (SEX == 2)
label define femlbl 0 "Male" 1 "Female"
label values female femlbl


* Race
capture drop race_eth
gen race_eth = .
replace race_eth = 1 if HISPANX == 1 // * 1. Hispanic (Any Race)
replace race_eth = 2 if HISPANX == 2 & RACEV2X == 1 // * 2. Non-Hispanic White
replace race_eth = 3 if HISPANX == 2 & RACEV2X == 2 // * 3. Non-Hispanic Black
replace race_eth = 4 if HISPANX == 2 & inlist(RACEV2X, 4, 5, 6, 10)
replace race_eth = 5 if HISPANX == 2 & inlist(RACEV2X, 3, 12)
label define race5lbl 1 "Hispanic" 2 "NH White" 3 "NH Black" 4 "NH Asian" 5 "NH Other/Multiple"
label values race_eth race5lbl

* QC Check
tab race_eth, missing


* Insurance
gen insurance = INSCOV
label define inslbl 1 "Private" 2 "Public only" 3 "Uninsured"
label values insurance inslbl


* Poverty
capture drop povcat
gen povcat = .
replace povcat = 1 if POVCAT == 1
replace povcat = 2 if POVCAT == 2 | POVCAT == 3
replace povcat = 3 if POVCAT == 4
replace povcat = 4 if POVCAT == 5
label define povclean_lbl 1 "<100% (Poor)" 2 "100–199% (Low Income)" 3 "200–399% (Middle)" 4 "400%+ (High)"
label values povcat povclean_lbl
tab POVCAT povcat, missing


* Education 
gen education_years  = EDUCYR  // continuous years


* Family Size
gen family_size_cat = .
replace family_size_cat = 1 if FAMSZEYR == 1
replace family_size_cat = 2 if FAMSZEYR == 2
replace family_size_cat = 3 if FAMSZEYR == 3
replace family_size_cat = 4 if FAMSZEYR >= 4

label define fsize_lbl 1 "1-person" 2 "2-person" 3 "3-person" 4 "4+ persons"
label values family_size_cat fsize_lbl


* Convert region indicators to single REGION variable
gen region = .
replace region = 1 if REGION21 == 1      // Northeast
replace region = 2 if REGION21 == 2      // Midwest
replace region = 3 if REGION21 == 3      // South
replace region = 4 if REGION21 == 4      // West

label define reg 1 "Northeast" 2 "Midwest" 3 "South" 4 "West"
label values region reg


gen year = 2021

**# --> [NEW] ADDITIONAL Covariates
********************************************************
* 1. General Health Status (Parent Reported)
* Variable: RTHLTH42 (1=Ex, 2=VG, 3=G, 4=Fair, 5=Poor)
* We create a binary flag for "Fair/Poor Health" (High Need)
gen health_status = .
replace health_status = 1 if RTHLTH42 <= 3  // Excellent/VG/Good
replace health_status = 2 if RTHLTH42 == 4 | RTHLTH42 == 5 // Fair/Poor
label define hlthlbl 1 "Excellent/VG/Good" 2 "Fair/Poor"
label values health_status hlthlbl

* 2. Mental Health Status (Parent Reported)
* Variable: MNHLTH42 (1=Ex, 2=VG, 3=G, 4=Fair, 5=Poor)
gen mental_health = .
replace mental_health = 1 if MNHLTH42 <= 3 // Excellent/VG/Good
replace mental_health = 2 if MNHLTH42 == 4 | MNHLTH42 == 5 // Fair/Poor
label define mhlthlbl 1 "Excellent/VG/Good" 2 "Fair/Poor"
label values mental_health mhlthlbl

* 3. CSHCN: Children with Special Health Care Needs (Composite)
* CSHCN implies chronic need. Defined by "Yes" to any of the 5 screeners.
* Variables: CHCOUN42, CHEMPB42, CHPMHB42, CHLIMI42, CHSERV42
gen cshcn = 0
foreach v in CHCOUN42 CHEMPB42 CHPMHB42 CHLIMI42 CHSERV42 {
    * In MEPS: 1=YES, 2=NO. We flag if ANY are 1.
    replace cshcn = 1 if `v' == 1
}
label variable cshcn "Child with Special Health Care Needs (CSHCN)"
label define yesno 0 "No" 1 "Yes"
label values cshcn yesno

* 4. Language of Interview (Access Barrier)
* Variable: INTVLANG (1=English, 2=Spanish, etc.)
gen language_barrier = 0
replace language_barrier = 1 if INTVLANG != 1 & !missing(INTVLANG)
label variable language_barrier "Interview not in English"

tab language_barrier
tab cshcn
tab mental_health
tab health_status

* Save cleaned 2021 person-level dataset
save "$outdir/person_2021_clean.dta", replace



**# --> Step 3 h229g h229f h229E - Visit Type

* OFFICE
**************************************************************
** Cleaning DUID str7 vs long type
use "$datadir/h229g.dta", clear
* Inspect variables
describe DUPERSID EVNTIDX TELEHEALTHFLAG VISITTYPE
gen year = 2021
* Create telehealth indicator
gen tele = TELEHEALTHFLAG == 1
* Create in-person indicator
gen inperson = 1 - tele
save "$outdir/ob_2021_clean.dta", replace

* OUTPATIENT
**************************************************************
use "$datadir/h229f.dta", clear
describe DUPERSID EVNTIDX TELEHEALTHFLAG VISITTYPE
gen year = 2021
* Telehealth indicator
gen tele = TELEHEALTHFLAG == 1
* In-person indicator
gen inperson = 1 - tele
save "$outdir/op_2021_clean.dta", replace

* COMBINE
**************************************************************
use "$outdir/ob_2021_clean.dta", clear
append using "$outdir/op_2021_clean.dta"

* Check
tab tele
tab inperson

save "$outdir/events_2021_all.dta", replace



**# --> Step 4: Collapse 2021 events to person-year
use "$outdir/events_2021_all.dta", clear

* Numeric placeholder for counting events
gen evnum = 1

collapse ///
    (sum) tele tele_visits=tele ///
    (sum) inperson inperson_visits=inperson ///
    (count) total_visits=evnum ///
    (max) any_tele=tele, by(DUPERSID year)

gen tele_share = tele_visits / total_visits
replace tele_share = 0 if total_visits == 0

save "$outdir/event_summary_2021.dta", replace

// QC 
summarize tele_visits inperson_visits total_visits tele_share 
tab any_tele



**# --> Step 5 - Merge Back
* Merge person-level 2021 file with event-derived outcomes
use "$outdir/person_2021_clean.dta", clear
merge 1:1 DUPERSID using "$outdir/event_summary_2021.dta"

* FIX: Drop event-summary rows that have no matching person
drop if _merge == 2

* Set zeros for those with no visits
replace tele_visits = 0 if missing(tele_visits)
replace inperson_visits = 0 if missing(inperson_visits)
replace total_visits = 0 if missing(total_visits)
replace any_tele = 0 if missing(any_tele)
replace tele_share = 0 if missing(tele_share)

drop _merge

save "$outdir/analytic_2021.dta", replace


// QC 
count
summarize age tele_visits inperson_visits total_visits tele_share
tab age_cat 
tab any_tele

tab age_cat any_tele


**# --> Step 6: SAVE ONLY
use "$outdir/analytic_2021.dta", clear

keep ///
    DUPERSID year PERWT21F VARSTR VARPSU /// survey design
    age age_cat female race_eth insurance povcat education_years ///
    family_size_cat region /// demographics & SES
    tele_visits inperson_visits total_visits tele_share any_tele  /// outcomes
	health_status mental_health cshcn language_barrier

order DUPERSID year age age_cat female race_eth insurance povcat ///
      tele_visits inperson_visits total_visits tele_share any_tele

save "$outdir/analytic_2021_cleanvars.dta", replace
count





*******************************
**#  2022 MEPS
/******************************
  FILE REFERENCES (2022)
  - h243.dta : Full-year consolidated (person-level)
  - h241.dta : Medical conditions
  - h239g.dta: Office-based provider visits
  - h239f.dta: Outpatient visits
  - h239e.dta: Emergency room visits
  - h239if1.dta: Condition–event link file
***********************************************************************/

*******************************************************************************
**# --> STEP 1: Prepare 2022 person-level dataset (h243.dta)
*******************************************************************************

use "$datadir/xxx.dta", clear
count
* Clean negative values
foreach v of varlist AGE22X SEX RACEV2X INSCOV POVCAT EDUCYR MARRY22X REGION22 {
    replace `v' = . if `v' < 0
}

* Age
gen age  = AGE22X

gen age_cat = .
replace age_cat = 1 if AGE22X < 6
replace age_cat = 2 if AGE22X >= 6 & AGE22X <= 11
replace age_cat = 3 if AGE22X >= 12 & AGE22X <= 17
replace age_cat = 4 if AGE22X >= 18
label define agecatlbl 1 "<6" 2 "6–11" 3 "12–17" 4 "18+"
label values age_cat agecatlbl
tab age_cat

* Female
gen female = (SEX == 2)
label define femlbl 0 "Male" 1 "Female"
label values female femlbl
tab female

* Race/Ethnicity
capture drop race_eth
gen race_eth = .
replace race_eth = 1 if HISPANX == 1 // * 1. Hispanic (Any Race)
replace race_eth = 2 if HISPANX == 2 & RACEV2X == 1 // * 2. Non-Hispanic White
replace race_eth = 3 if HISPANX == 2 & RACEV2X == 2 // * 3. Non-Hispanic Black
replace race_eth = 4 if HISPANX == 2 & inlist(RACEV2X, 4, 5, 6, 10)
replace race_eth = 5 if HISPANX == 2 & inlist(RACEV2X, 3, 12)
label define race5lbl 1 "Hispanic" 2 "NH White" 3 "NH Black" 4 "NH Asian" 5 "NH Other/Multiple"
label values race_eth race5lbl

* QC Check
tab race_eth, missing


* Insurance
gen insurance = INSCOV
label define inslbl 1 "Private" 2 "Public only" 3 "Uninsured"
label values insurance inslbl

* Poverty
capture drop povcat
gen povcat = .
replace povcat = 1 if POVCAT == 1
replace povcat = 2 if POVCAT == 2 | POVCAT == 3
replace povcat = 3 if POVCAT == 4
replace povcat = 4 if POVCAT == 5
label define povclean_lbl 1 "<100% (Poor)" 2 "100–199% (Low Income)" 3 "200–399% (Middle)" 4 "400%+ (High)"
label values povcat povclean_lbl
tab POVCAT povcat, missing

* Education
gen education_years = EDUCYR

* Family size
gen family_size_cat = .
replace family_size_cat = 1 if FAMSZEYR == 1
replace family_size_cat = 2 if FAMSZEYR == 2
replace family_size_cat = 3 if FAMSZEYR == 3
replace family_size_cat = 4 if FAMSZEYR >= 4
label define fsize_lbl 1 "1-person" 2 "2-person" 3 "3-person" 4 "4+ persons"
label values family_size_cat fsize_lbl

* Region
gen region = .
replace region = 1 if REGION22 == 1
replace region = 2 if REGION22 == 2
replace region = 3 if REGION22 == 3
replace region = 4 if REGION22 == 4
label define regionlbl 1 "Northeast" 2 "Midwest" 3 "South" 4 "West"
label values region regionlbl

gen year = 2022

**# --> [NEW] ADDITIONAL Covariates
********************************************************
* 1. General Health Status (Parent Reported)
* Variable: RTHLTH42 (1=Ex, 2=VG, 3=G, 4=Fair, 5=Poor)
* We create a binary flag for "Fair/Poor Health" (High Need)
gen health_status = .
replace health_status = 1 if RTHLTH42 <= 3  // Excellent/VG/Good
replace health_status = 2 if RTHLTH42 == 4 | RTHLTH42 == 5 // Fair/Poor
label define hlthlbl 1 "Excellent/VG/Good" 2 "Fair/Poor"
label values health_status hlthlbl

* 2. Mental Health Status (Parent Reported)
* Variable: MNHLTH42 (1=Ex, 2=VG, 3=G, 4=Fair, 5=Poor)
gen mental_health = .
replace mental_health = 1 if MNHLTH42 <= 3 // Excellent/VG/Good
replace mental_health = 2 if MNHLTH42 == 4 | MNHLTH42 == 5 // Fair/Poor
label define mhlthlbl 1 "Excellent/VG/Good" 2 "Fair/Poor"
label values mental_health mhlthlbl

* 3. CSHCN: Children with Special Health Care Needs (Composite)
* CSHCN implies chronic need. Defined by "Yes" to any of the 5 screeners.
* Variables: CHCOUN42, CHEMPB42, CHPMHB42, CHLIMI42, CHSERV42
gen cshcn = 0
foreach v in CHCOUN42 CHEMPB42 CHPMHB42 CHLIMI42 CHSERV42 {
    * In MEPS: 1=YES, 2=NO. We flag if ANY are 1.
    replace cshcn = 1 if `v' == 1
}
label variable cshcn "Child with Special Health Care Needs (CSHCN)"
label define yesno 0 "No" 1 "Yes"
label values cshcn yesno

* 4. Language of Interview (Access Barrier)
* Variable: INTVLANG (1=English, 2=Spanish, etc.)
gen language_barrier = 0
replace language_barrier = 1 if INTVLANG != 1 & !missing(INTVLANG)
label variable language_barrier "Interview not in English"

tab language_barrier
tab cshcn
tab mental_health
tab health_status


save "$outdir/person_2022_clean.dta", replace

count // 




**# --> STEP 2: Office, Outpatient

* Office-based visits 2022 (h239g.dta)
*****************************************************
use "$datadir/h239g.dta", clear
describe DUPERSID EVNTIDX TELEHEALTHFLAG VISITTYPE
gen year = 2022
gen tele = TELEHEALTHFLAG == 1
gen inperson = 1 - tele
save "$outdir/ob_2022_clean.dta", replace

* Outpatient visits 2022 (h239f.dta)
*******************************************************************************/
use "$datadir/h239f.dta", clear
describe DUPERSID EVNTIDX TELEHEALTHFLAG VISITTYPE
gen year = 2022
gen tele = TELEHEALTHFLAG == 1
gen inperson = 1 - tele
save "$outdir/op_2022_clean.dta", replace

* Combine OB and OP (2022)
*******************************************************************************/
use "$outdir/ob_2022_clean.dta", clear
append using "$outdir/op_2022_clean.dta"
save "$outdir/events_2022_all.dta", replace




*******************************************************************************
**# --> STEP 3: Collapse event data → person-year summaries (2022)
use "$outdir/events_2022_all.dta", clear
gen evnum = 1   // numeric placeholder for count

collapse ///
    (sum) tele tele_visits=tele ///
    (sum) inperson inperson_visits=inperson ///
    (count) total_visits=evnum ///
    (max) any_tele=tele, ///
    by(DUPERSID year)

gen tele_share = tele_visits / total_visits
replace tele_share = 0 if total_visits == 0

save "$outdir/event_summary_2022.dta", replace




**# --> STEP 4: Merge person-level dataset with event data (2022)
*******************************************************************************/

use "$outdir/person_2022_clean.dta", clear
merge 1:1 DUPERSID using "$outdir/event_summary_2022.dta"

replace tele_visits = 0 if missing(tele_visits)
replace inperson_visits = 0 if missing(inperson_visits)
replace total_visits = 0 if missing(total_visits)
replace any_tele = 0 if missing(any_tele)
replace tele_share = 0 if missing(tele_share)

drop _merge

save "$outdir/analytic_2022.dta", replace


**# --> Step 5: SAVE ONLY
*******************************************************************************/
use "$outdir/analytic_2022.dta", clear

keep ///
    DUPERSID year PERWT22F VARSTR VARPSU ///
    age age_cat female race_eth insurance povcat education_years ///
    family_size_cat region ///
    tele_visits inperson_visits total_visits tele_share any_tele ///
	health_status mental_health cshcn language_barrier

	
save "$outdir/analytic_2022_cleanvars.dta", replace
count //

	
	
	
*******************************
**#  2023 MEPS
/******************************
  FILE REFERENCES (2023)
  h251.dta   Full-Year Consolidated (FYC) 2023 person-level file
  h249.dta   Medical Conditions file (2023)
  h248g.dta  Office-Based Provider Visits
  h248f.dta  Outpatient Department Visits
  h248e.dta  Emergency Room Visits
  h248i.dta  Condition-Event Link File
***********************************************************************/	

**# --> STEP 1: Clean 2023 person-level file (h251.dta)
use "$datadir/xxx.dta", clear
count // 18,919

* Clean negative values
foreach v of varlist AGE23X SEX RACEV2X INSCOV POVCAT EDUCYR MARRY23X REGION23 {
    replace `v' = . if `v' < 0
}

* Age
gen age = AGE23X

gen age_cat = .
replace age_cat = 1 if AGE23X < 6
replace age_cat = 2 if AGE23X >= 6 & AGE23X <= 11
replace age_cat = 3 if AGE23X >= 12 & AGE23X <= 17
replace age_cat = 4 if AGE23X >= 18
label define agecatlbl 1 "<6" 2 "6–11" 3 "12–17" 4 "18+"
label values age_cat agecatlbl

* Sex
gen female = (SEX == 2)
label define femlbl 0 "Male" 1 "Female"
label values female femlbl

* Race/Ethnicity
capture drop race_eth
gen race_eth = .
replace race_eth = 1 if HISPANX == 1 // * 1. Hispanic (Any Race)
replace race_eth = 2 if HISPANX == 2 & RACEV2X == 1 // * 2. Non-Hispanic White
replace race_eth = 3 if HISPANX == 2 & RACEV2X == 2 // * 3. Non-Hispanic Black
replace race_eth = 4 if HISPANX == 2 & inlist(RACEV2X, 4, 5, 6, 10)
replace race_eth = 5 if HISPANX == 2 & inlist(RACEV2X, 3, 12)
label define race5lbl 1 "Hispanic" 2 "NH White" 3 "NH Black" 4 "NH Asian" 5 "NH Other/Multiple"
label values race_eth race5lbl
tab race_eth, missing

* Insurance
gen insurance = INSCOV
label define inslbl 1 "Private" 2 "Public only" 3 "Uninsured"
label values insurance inslbl

* Poverty
capture drop povcat
gen povcat = .
replace povcat = 1 if POVCAT == 1
replace povcat = 2 if POVCAT == 2 | POVCAT == 3
replace povcat = 3 if POVCAT == 4
replace povcat = 4 if POVCAT == 5
label define povclean_lbl 1 "<100% (Poor)" 2 "100–199% (Low Income)" 3 "200–399% (Middle)" 4 "400%+ (High)"
label values povcat povclean_lbl
tab POVCAT povcat, missing

* Education
gen education_years = EDUCYR

* Family size
gen family_size_cat = .
replace family_size_cat = 1 if FAMSZEYR == 1
replace family_size_cat = 2 if FAMSZEYR == 2
replace family_size_cat = 3 if FAMSZEYR == 3
replace family_size_cat = 4 if FAMSZEYR >= 4
label define fsize_lbl 1 "1-person" 2 "2-person" 3 "3-person" 4 "4+ persons"
label values family_size_cat fsize_lbl

* Region
gen region = .
replace region = 1 if REGION23 == 1
replace region = 2 if REGION23 == 2
replace region = 3 if REGION23 == 3
replace region = 4 if REGION23 == 4
label define regionlbl 1 "Northeast" 2 "Midwest" 3 "South" 4 "West"
label values region regionlbl


gen year = 2023

**# --> [NEW] ADDITIONAL Covariates
********************************************************
* 1. General Health Status (Parent Reported)
* Variable: RTHLTH42 (1=Ex, 2=VG, 3=G, 4=Fair, 5=Poor)
* We create a binary flag for "Fair/Poor Health" (High Need)
gen health_status = .
replace health_status = 1 if RTHLTH42 <= 3  // Excellent/VG/Good
replace health_status = 2 if RTHLTH42 == 4 | RTHLTH42 == 5 // Fair/Poor
label define hlthlbl 1 "Excellent/VG/Good" 2 "Fair/Poor"
label values health_status hlthlbl

* 2. Mental Health Status (Parent Reported)
* Variable: MNHLTH42 (1=Ex, 2=VG, 3=G, 4=Fair, 5=Poor)
gen mental_health = .
replace mental_health = 1 if MNHLTH42 <= 3 // Excellent/VG/Good
replace mental_health = 2 if MNHLTH42 == 4 | MNHLTH42 == 5 // Fair/Poor
label define mhlthlbl 1 "Excellent/VG/Good" 2 "Fair/Poor"
label values mental_health mhlthlbl

* 3. CSHCN: Children with Special Health Care Needs (Composite)
* CSHCN implies chronic need. Defined by "Yes" to any of the 5 screeners.
* Variables: CHCOUN42, CHEMPB42, CHPMHB42, CHLIMI42, CHSERV42
gen cshcn = 0
foreach v in CHCOUN42 CHEMPB42 CHPMHB42 CHLIMI42 CHSERV42 {
    * In MEPS: 1=YES, 2=NO. We flag if ANY are 1.
    replace cshcn = 1 if `v' == 1
}
label variable cshcn "Child with Special Health Care Needs (CSHCN)"
label define yesno 0 "No" 1 "Yes"
label values cshcn yesno

* 4. Language of Interview (Access Barrier)
* Variable: INTVLANG (1=English, 2=Spanish, etc.)
gen language_barrier = 0
replace language_barrier = 1 if INTVLANG != 1 & !missing(INTVLANG)
label variable language_barrier "Interview not in English"

tab language_barrier
tab cshcn
tab mental_health
tab health_status

save "$outdir/person_2023_clean.dta", replace



**# --> STEP 2: Prepare 2023 Event Files (OB + OP)

* Clean 2023 Office-Based Visit File (h248g.dta)
use "$datadir/h248g.dta", clear
keep DUPERSID EVNTIDX TELEHEALTHFLAG VISITTYPE
gen year = 2023
gen tele = TELEHEALTHFLAG == 1
gen inperson = 1 - tele
save "$outdir/ob_2023_clean.dta", replace


* Clean 2023 Outpatient Visit File (h248f.dta)
use "$datadir/h248f.dta", clear
keep DUPERSID EVNTIDX TELEHEALTHFLAG VISITTYPE
gen year = 2023
gen tele = TELEHEALTHFLAG == 1
gen inperson = 1 - tele
save "$outdir/op_2023_clean.dta", replace

* Append 2023 OB + OP events
use "$outdir/ob_2023_clean.dta", clear
append using "$outdir/op_2023_clean.dta"
save "$outdir/events_2023_all.dta", replace




**# --> STEP 3: Collapse 2023 event-level data to person-year totals
use "$outdir/events_2023_all.dta", clear
gen evnum = 1

collapse ///
    (sum) tele tele_visits=tele ///
    (sum) inperson inperson_visits=inperson ///
    (count) total_visits=evnum ///
    (max) any_tele=tele, ///
    by(DUPERSID year)

gen tele_share = tele_visits / total_visits
replace tele_share = 0 if total_visits == 0

save "$outdir/event_summary_2023.dta", replace




**# --> STEP 4: Merge 2023 person-level data with visit summaries
use "$outdir/person_2023_clean.dta", clear
merge 1:1 DUPERSID using "$outdir/event_summary_2023.dta"

replace tele_visits = 0 if missing(tele_visits)
replace inperson_visits = 0 if missing(inperson_visits)
replace total_visits = 0 if missing(total_visits)
replace any_tele = 0 if missing(any_tele)
replace tele_share = 0 if missing(tele_share)

drop _merge

save "$outdir/analytic_2023.dta", replace
count 



**# --> STEP 5: SAVE ONLY
use "$outdir/analytic_2023.dta", clear


codebook ADHOPE ADPRS ADREST ADWRTH ADNERV // variables do NOT apply to the pediatric sample
codebook CHCOUN CHEMPB CHPMHB CHLIMI CHSERV


keep ///
    DUPERSID year PERWT23F VARSTR VARPSU ///
    age age_cat female race_eth insurance povcat education_years ///
    family_size_cat region ///
    tele_visits inperson_visits total_visits tele_share any_tele ///
	health_status mental_health cshcn language_barrier
	

save "$outdir/analytic_2023_cleanvars.dta", replace





**# Step 3 - Append 2021, 2022, 2023
/*******************************************************************************
   STEP 7: APPEND 2021 + 2022 + 2023 ANALYTIC DATASETS
   RESULT: analytic_2021_2023_pooled.dta
*******************************************************************************/

clear

* Load 2021
use "$outdir/analytic_2021_cleanvars.dta", clear
count // 28,336

* Append 2022
append using "$outdir/analytic_2022_cleanvars.dta"
count // 50,767

* Append 2023
append using "$outdir/analytic_2023_cleanvars.dta"
count // 69,686


*-------------------------------------------------------------*
* 3. Create unified MEPS survey weight across years
*-------------------------------------------------------------*
gen weight = .
replace weight = PERWT21F if year == 2021
replace weight = PERWT22F if year == 2022
replace weight = PERWT23F if year == 2023
label variable weight "Unified MEPS Person Weight"

drop  PERWT21F PERWT22F PERWT23F

*-------------------------------------------------------------*
* 4. QC Checks
*-------------------------------------------------------------*

* Check year distributions
tab year

* Check unified weight
summ weight

* Check outcomes
summ tele_visits inperson_visits total_visits tele_share any_tele
tab any_tele year if age_cat == 2 | 3


* Check structure
describe

*-------------------------------------------------------------*
* 5. Sort for clean structure
*-------------------------------------------------------------*
sort year DUPERSID

*-------------------------------------------------------------*
* 6. Save pooled dataset
*-------------------------------------------------------------*
save "$outdir/analytic_pooled_2021_2023.dta", replace








**# Step 4 - Statistics
*------------------------------------------------------------------*
* Statistics + Analytic Sample Construction
*------------------------------------------------------------------*
use "$outdir/analytic_pooled_2021_2023.dta", clear

* Basic descriptive check
summ tele_visits inperson_visits total_visits tele_share any_tele

count
describe
tab year, missing





**# Exclusion Table
*------------------------------------------------------------------*
* Exclusion Table Logic  (DO NOT DROP ANY OBSERVATIONS)
*------------------------------------------------------------------*

gen exclusion = 0

* Exclusion 1: Age outside 6–17
replace exclusion = 1 if age < 6 | age > 17

* Exclusion 2: Missing or invalid survey weights
replace exclusion = 2 if missing(weight) & exclusion==0

* Exclusion 3: Missing key socioeconomic variables
local keyvars female race_eth insurance povcat region age
foreach v of local keyvars {
    replace exclusion = 3 if missing(`v') & exclusion==0
}

* Exclusion 4 (NOT used for sample removal)
* Flag individuals with zero outpatient visits (for sensitivity analyses)
gen exclusion_visit = (total_visits == 0)

* Exclusion 5: Merge failures (likely none)
capture replace exclusion = 5 if _merge_event == 2 & exclusion==0

* Label exclusion categories
label define exclbl 0 "Included in analytic sample" ///
                    1 "Age not 6–17" ///
                    2 "Missing survey weight" ///
                    3 "Missing key variables" ///
                    4 "Zero outpatient visits (sensitivity only)" ///
                    5 "Event merge failure"

label values exclusion exclbl
tab exclusion
tab exclusion_visit if exclusion==0


*------------------------------------------------------------------*
* Create Analysis Flags (NO DROPS)
*------------------------------------------------------------------*

* Primary analytic sample: children 6–17 with full SES + weight
gen keep_child = (exclusion == 0)
label define keeplbl 0 "Not kept" 1 "Kept: child analytic sample"
label values keep_child keeplbl

* Secondary analytic sample: children with ≥1 outpatient visit
gen keep_nonzero = (total_visits > 0)
label define nzlbl 0 "Zero visits" 1 "Has ≥1 visit"
label values keep_nonzero nzlbl

* Telehealth share cleaned for sensitivity Tobit
gen tele_share_nonzero = tele_share if keep_nonzero == 1

*------------------------------------------------------------------*
* IMPORTANT: Final QC Checks
*------------------------------------------------------------------*

* Check for missing key outcomes in analytic sample
foreach v in tele_visits inperson_visits total_visits tele_share any_tele {
    di "Checking `v'..."
    count if missing(`v') & keep_child==1
}

* Check distribution of the analytic sample
tab keep_child keep_nonzero


/********************************************************************************************
Sample Flow Summary
-------------------
The pooled 2021–2023 MEPS dataset includes 69,686 individuals. After restricting to 
children ages 6–17, 9,722 individuals (14%) met inclusion criteria; no cases were 
excluded for missing weights, missing covariates, or merge failures.

Within this analytic cohort, 6,729 children (69%) had at least one outpatient visit, 
while 2,993 (31%) had zero visits. Zero-visit cases are retained for models of any 
telehealth use and visit counts but are flagged for sensitivity analyses involving 
telehealth share.
********************************************************************************************/




**# Descriptive Statistics


**# Table 1 - Unweighted Descriptive
**# --> by Year 
/********************************************************************************************
Unweighted Descriptive Statistics by Year (Children Ages 6–17)
********************************************************************************************/
tab year if keep_child==1
by year, sort: summarize age tele_visits inperson_visits total_visits tele_share if keep_child==1

* Loop through categorical variables and show year-by-year percentages
* ADDED: cshcn health_status mental_health language_barrier
foreach v in age_cat female race_eth insurance povcat region cshcn health_status mental_health language_barrier {
    di " "
    di "----- `v' (%) by Year -----"
    tab `v' year if keep_child==1, col nofreq
}


**# --> by Telehealth Use
/********************************************************************************************
TABLE 2: UNWEIGHTED CHARACTERISTICS OF CHILDREN (6–17) 
BY TELEHEALTH USE (any_tele)
- any_tele = 0 → No telehealth use
- any_tele = 1 → Used telehealth
No observations dropped; restrict with keep_child==1
********************************************************************************************/
tab any_tele if keep_child==1
by any_tele, sort: summarize age tele_visits inperson_visits total_visits tele_share if keep_child==1

di "----------------------------------------------------"
di "Categorical Variables by Telehealth Use (Column % = 100%)"
di "----------------------------------------------------"

foreach v in age_cat female race_eth insurance povcat region year {
    di " "
    di "----- `v' (%) by Telehealth Use (any_tele) -----"
    tab `v' any_tele if keep_child==1, col nofreq
}







**# Table 2 - Weighted Descriptive Statistics

*------------------------------------------------------------------*
* 1. Set Survey Design
*------------------------------------------------------------------*
svyset VARPSU [pweight=weight], strata(VARSTR) vce(linearized)

/********************************************************************************************
WEIGHTED TABLE: Characteristics of Children Ages 6–17 (MEPS 2021–2023)
********************************************************************************************/

/* Panel A: Weighted Demographics by Year */
di "----------------------"
di "Panel A: Weighted Demographics"
di "----------------------"

* Updated loop to include: cshcn, health_status, mental_health, language_barrier
foreach v in age_cat female race_eth insurance povcat region cshcn health_status mental_health language_barrier {
    di " "
    di "Weighted distribution of `v' by year"
    svy: tab `v' year if keep_child==1, col percent format(%5.2f)
}


/* Panel B: Weighted Means for Utilization Outcomes by Year */
di " "
di "----------------------"
di "Panel B: Weighted Means for Utilization"
di "----------------------"

foreach y in 2021 2022 2023 {
    di "Year = `y'"
    svy, subpop(if keep_child==1 & year==`y'): mean ///
        any_tele tele_visits inperson_visits tele_share
}


/* Panel C: Weighted Telehealth Use by SES, Demographics, and Need */
di " "
di "----------------------"
di "Panel C: Telehealth Use by SES and Need Factors"
di "----------------------"

* Expanded loop to check utilization across ALL key predictors
foreach factor in povcat insurance race_eth cshcn health_status mental_health language_barrier {
    di " "
    di "Factor = `factor'"
    svy: mean any_tele tele_visits inperson_visits if keep_child==1, over(`factor')
}







**# Inferential Statistics

*------------------------------------------------------------------*
* 1. Define Global Covariates List
*------------------------------------------------------------------*
/* Predictors:
   - SES:          i.povcat i.insurance
   - Demographics: age i.female i.race_eth i.region
   - Time:         i.year
   - Need/Health:  i.cshcn i.health_status i.mental_health
   - Access:       i.language_barrier
*/

global covariates "i.povcat i.insurance age i.female i.race_eth i.region i.year i.cshcn i.health_status i.mental_health i.language_barrier"

* Verify the list
display "$covariates"


**# --> Model 1
/********************************************************************************************
MODEL 1: Logistic Regression
Outcome: any_tele (0/1)
Purpose: Estimate barriers to accessing *any* telehealth.
********************************************************************************************/
svy: logit any_tele $covariates if keep_child==1

* Margins: Prob. of use by Poverty & Insurance, averaged over other covariates
margins i.povcat i.insurance, at(year=(2021 2022 2023)) post

* Plot
marginsplot, ///
    title("Predicted Probability of Any Telehealth Use") ///
    ytitle("Pr(Any Telehealth)") ///
    xtitle("SES Groups") ///
    name(model1_logit_plot, replace)
	
	
	


**# --> Model 2
/********************************************************************************************
MODEL 2: Telehealth Visit Counts (Negative Binomial Regression)
Outcome: tele_visits
Goal: Estimate SES/Insurance differences in the *intensity* of telehealth use.
********************************************************************************************/

* Ensure survey design is set
svyset VARPSU [pweight = weight], strata(VARSTR) vce(linearized)

*---------------------------------------------------------------*
* MODEL 2: Survey-weighted NBREG with IRRs
*---------------------------------------------------------------*
svy: nbreg tele_visits $covariates if keep_child==1, irr

*---------------------------------------------------------------*
* Marginal predictions: expected telehealth visits
*---------------------------------------------------------------*
margins i.povcat i.insurance, ///
    at(year=(2021 2022 2023)) ///
    post

*---------------------------------------------------------------*
* Plot predicted visit counts
*---------------------------------------------------------------*
marginsplot, ///
    title("Predicted Telehealth Visit Counts by SES and Year") ///
    ytitle("Expected Telehealth Visits") ///
    xtitle("SES / Insurance Groups") ///
    name(model2_nbreg_plot, replace)


**# --> Model 3
/********************************************************************************************
MODEL 3: In-Person Visit Counts (Negative Binomial Regression)
Outcome: inperson_visits
Goal: Assess whether SES/Insurance groups supplement or substitute care.
      (High Tele + High In-Person = Supplementation)
      (High Tele + Low In-Person  = Substitution)
********************************************************************************************/

svy: nbreg inperson_visits $covariates if keep_child==1, irr

*---------------------------------------------------------------*
* Marginal predictions: expected in-person visits
*---------------------------------------------------------------*
margins i.povcat i.insurance, ///
    at(year=(2021 2022 2023)) ///
    post

*---------------------------------------------------------------*
* Plot predicted visit counts
*---------------------------------------------------------------*
marginsplot, ///
    title("Predicted In-Person Visit Counts by SES and Year") ///
    ytitle("Expected In-Person Visits") ///
    xtitle("SES / Insurance Groups") ///
    name(model3_nbreg_inperson, replace)


**# --> Model 4
/********************************************************************************************
    MODEL 4: Survey-Weighted Tobit Regression
    Outcome: tele_share (bounded 0–1)
    Purpose: Test whether SES predicts the *proportion* of care delivered via telehealth.
    
    Notes:
    - tele_share includes zeros (common) and ones (rare).
    - Tobit handles the censoring at 0 and 1 correctly.
********************************************************************************************/

*---------------------------------------------------------------*
* 2.   Tobit Model (censored at 0 and 1)
*---------------------------------------------------------------*
svy: tobit tele_share $covariates if keep_child==1, ll(0) ul(1)


*---------------------------------------------------------------*
* 3.   Marginal Effects: Expected Telehealth Share (bounded 0–1)
* Note: predict(ystar(0,1)) calculates E(y|x) accounting for censoring
*---------------------------------------------------------------*
margins i.povcat i.insurance, at(year=(2021 2022 2023)) predict(ystar(0,1)) post


*---------------------------------------------------------------*
* 5.   Plot predicted telehealth share
*---------------------------------------------------------------*
marginsplot, ///
    title("Predicted Telehealthx Share by SES and Year") ///
    ytitle("Expected Telehealth Share (0–1)") ///
    xtitle("SES / Insurance Groups") ///
    name(model4_tobit_plot, replace)


**# --> [NEW] Model 5: Interaction Analysis
/********************************************************************************************
    MODEL 5: Is the Poverty Gap Closing Over Time?
    Interaction: Poverty * Year
********************************************************************************************/
* We remove i.povcat and i.year from the global for this specific command 
* to avoid collinearity/double entry when typing the interaction manually.

svy: nbreg tele_visits i.povcat##i.year i.insurance age i.female i.race_eth i.region i.cshcn i.health_status i.mental_health i.language_barrier if keep_child==1, irr

* Check the predictive margins of the interaction
margins i.povcat#i.year
marginsplot, ///
    title("Telehealth Trends by Poverty Level (2021–2023)") ///
    ytitle("Predicted Visits") ///
    xtitle("Year") ///
    legend(order(1 "Poor" 2 "Low Inc" 3 "Middle" 4 "High Inc")) ///
    name(interaction_plot, replace)




//
log close
