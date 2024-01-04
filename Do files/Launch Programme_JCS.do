/*
********************************************************************************
LAUNCH PROGRAMME.DO
	
	THIS DO FILE SETS GLOBAL MACRO VALUES USED ACROSS THE DO FILES.
	SECTION 1: PLEASE CHANGE THE GLOBAL MACRO VALUES IN  TO FIT WITH YOUR FOLDERS.
	SECTION 2: CHECK AND ALTER IF REQUIRED:
		STUB IF USING SPECIAL LICENSE DATA
		NUMBER OF WAVES
		CHOICES FOR DATA CLEANING AND DATA IMPUTATION
	SECTION 3: THE FULL CODE CAN BE RUN WITHIN THIS DO FILE BY CHANGING run_full TO YES. OTHERWISE, EACH DO FILE SHOULD BE RUN SEPARATELY.
	SECTION 4: NO USER CHANGES REQUIRED.

********************************************************************************
*/
clear all
macro drop _all
set more off


/*
SECTION 1. Change file locations. Select appropriate file suffix (stub) if using Special License files. 
*/
* Log file (if desired)
capture log close
log using "C:/Users/ecscd/OneDrive - University of Warwick/LAMAFLO Stata code on OneDrive - JCS/imputation_12m", replace
* Top-level directory which original and constructed data files will be located under
cd "C:/Users/ecscd/OneDrive - University of Warwick/"
* Directory in which UKHLS and BHPS files are kept.
global fld					"LAMAFLO UKHLS BHPS Data on OneDrive"
* Folder activity histories will be saved in.
global dta_fld				"LAMAFLO JCS Datasets on OneDrive"
* Folder do files are kept in.
global do_fld				"LAMAFLO Stata code on OneDrive - JCS"
* Set Personal ado folder
sysdir set PLUS 			"${do_fld}/ado/"

* BHPS Folder Prefix for Stata Files
global bhps_path			bhps
* UKHLS Folder Prefix for Stata Files
global ukhls_path			ukhls

* Common stub which is affixed on end of original Stata files (e.g. "_protect" where using Special Licence files; blank for End User Licence files)
global file_type					


/*
SECTION 2. Choose the following parameters: number of waves, data cleaning, data imputation.
*/

* Number of BHPS Waves to be collected
global bhps_waves			18
* Number of Understanding Society Waves to be collected
global ukhls_waves			12		
* List BHPS Life History Waves (lifemst files)
global bhps_lifehistwaves 	2 11 12
* Use BHPS Wave 3 Life Job History  (lifejob file)					// NOTE: ADDITIONAL USE OF BHPS WAVE 3 LIFE JOB HISTORY DATA (lifejob FILE)
global bhps_lifejob			3
* Waves Employment Status History collected in (empstat files)
global ukhls_lifehistwaves 	1 5


* You can select a value for the minimum age at which you choose to believe that the individual has a status that is not full-time education, i.e. the earliest age at which a non-education status such as employment will not be treated as an error and discarded.
* Detail for noneducstatus_minage (Minimum age for non-education status): All observations for a pidp in the relevant Wave will be dropped if that pidp has a non-education spell starting or ending at an age below this value. 
* Which data are affected by choice of noneducstatus_minage? The value is used to select data from lifemst files !!! PLUS POSSIBLY OTHERS !!! and will impact all datasets using those data.
* Default value of noneducstatus_minage: The default value of 0 means the resulting dataset includes all spells starting or ending after birth. Note that spells starting or ending before a particular age can be dropped outside of dataset creation stage of your research.
* Suggested alternative values for noneducstatus_minage: 12 (which will replicate Liam Wright's code in this respect), or 16, or other values depending on research needs.  
* Comparison with Liam Wright's (2020) code: LW code dropped pidp-Waves (all data for an individual within an affected wave) where the raw data record that the individual started or ended a non-education spell before age 12. 
global noneducstatus_minage		0


* You can select the extent to which data will be dropped in response to implausible dates.
* Detail for implausibledates_drop: 
* Default choice for implausibledates_drop: The default choice of "obs" retains the most data: only spells ("obs"ervations) with implausible dates will be dropped, and other spells in that pidp-Wave will be retained and renumbered.
* Alternative choices for implausibledates_drop: Any other value than "obs" will lead to all data for that pidp-Wave being dropped.
* Comparison with Liam Wright's (2020) code: LW code dropped the whole pidp-Wave (all data for an individual within an affected wave) if there was an implausible date for that individual in that Wave. Any other value than "obs" will replicate this. 
global implausibledates_drop	"obs"	


* You can choose whether to correct, or drop, pidp_Waves with non-chronological year, season-year spell start dates. The affected datasets are lifemst files.
* Default choice for nonchron_correct: "Y" (note that the "" are essential): The default choice of "Y" makes corrections and retains data. 
* Alternative choices for nonchron_correct: Leave blank or choose any other value to drop all observations for a pidp-Wave where there is a non-chronological spell start date.
global nonchron_correct			"Y"


* Set maximum length of gap imputed by halving space between two adjacent spells.
global gap_length				12


/*
SECTION 3. Choice whether to run the full code.
*/
* Decide whether to run full code (set equal to "YES" TO RUN FULL CODE, NOTING THAT THE "" ARE ESSENTIAL)
global run_full					"YES"


/*
SECTION 4. NO USER CHANGES OR CHOICES ARE REQUIRED IN THIS SECTION.
*/
*  Macros to be used across do files.
global total_waves=${ukhls_waves}+${bhps_waves}
global max_waves=max(${bhps_waves},${ukhls_waves})
global first_bhps_eh_wave=8
global last_bhps_eh_wave=18

* Create Reusable Programs.
do "${do_fld}/Create Programs_JCS.do"

* Run do files
if "$run_full"=="YES"{
	cls
	global start_time "$S_TIME"
	di in red "Program Started: $start_time"
	
	*i. Prepare basis data.
	do "${do_fld}/Interview Grid_JCS.do"	
	
	*ii. Education data
	do "${do_fld}/UKHLS Education History_JCS.do"
	do "${do_fld}/BHPS Education History_JCS.do"
	do "${do_fld}/FTE Variables - Collect_JCS.do"
	do "${do_fld}/FTE Variables - Clean_JCS.do"
	
	*ii. Work Histories
	do "${do_fld}/UKHLS Annual History_JCS.do"
	do "${do_fld}/UKHLS Life History_JCS.do"
	
	do "${do_fld}/BHPS Annual History - Waves 1-15_JCS.do"
	do "${do_fld}/BHPS Annual History - Waves 16-18_JCS.do"
	do "${do_fld}/BHPS Life History_JCS.do"


	*ii. Merge datasets
	do "${do_fld}/Merge Datasets_JCS.do"

	di in red "Program Started: $start_time"
	di in red "Program Completed: $S_TIME"
	}
