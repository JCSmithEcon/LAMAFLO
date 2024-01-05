/*
********************************************************************************
LAUNCH PROGRAMME.DO
	
	THIS DO FILE SETS GLOBAL MACRO VALUES USED ACROSS THE DO FILES.
	SECTION 1: PLEASE CHANGE THE GLOBAL MACRO VALUES TO FIT WITH YOUR FOLDERS.
	SECTION 2: CHECK AND ALTER IF REQUIRED:
		STUB IF USING SPECIAL LICENSE DATA
		NUMBER OF WAVES
		CHOICES FOR DATA CLEANING AND DATA IMPUTATION
		WHETHER TO NOISILY SHOW THE CODE RUNNING OR RUN EVERYTHING QUIETLY
	SECTION 3: THE FULL CODE CAN BE RUN WITHIN THIS DO FILE BY CHANGING run_full TO YES. OTHERWISE, EACH DO FILE SHOULD BE RUN SEPARATELY.
	SECTION 4: NO USER CHANGES REQUIRED.
	
	UPDATES: OPTIONS IN SECTION 2 TO CHOOSE:
	- HOW TO TREAT FURLOUGH STATUS.
	- MINIMUM ACCEPTABLE AGE TO START A NON-EDUCATION SPELL.
	- INDIVIDUAL OBSERVATION OR CASE-BY-CASE CORRECTION OF IMPLAUSIBLE DATES, RATHER THAN DELETION OF ALL pidp-Wave OR pidp INFORMATION.
	- FOR BHPS DATA, CASE-BY-CASE CORRECTION OF NON-CHRONOLOGICAL START DATES. THIS OPTION USES THE NEW FILE prog_nonchron_BHPS.do.
	- WHETHER THE CODE SHOULD RUN QUIETLY OR NOISILY.

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
log using "C:/Users/user/myfolder/logfile.log", replace
* Top-level directory which original and constructed data files will be located under
cd "C:/Users/user/"
* Directory in which UKHLS and BHPS files are kept.
global fld					"UKHS and BHPS data"
* Folder activity histories will be saved in.
global dta_fld				"data"
* Folder do files are kept in.
global do_fld				"do files"
* Set Personal ado folder
sysdir set PLUS 			"${do_fld}/ado/"

* BHPS Folder Prefix for Stata Files
global bhps_path			bhps
* UKHLS Folder Prefix for Stata Files
global ukhls_path			ukhls

* Common stub which is affixed on end of original Stata files (e.g. "_protect" where using Special Licence files; blank for End User Licence files)
global file_type					


/*
SECTION 2. Choose the following values:
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


* You can choose between three options in relation to furlough. You can choose to:
	* 'ignore' furlough, focusing on the underlying employment spell, 
	* treat furlough as a separate spell, or 
	* treat furlough as another non-employment status, which is what would happen if you were to run the LW code as it was written prior to furlough.
* Default value of furlough_choice: The default of "nofurlough" means furlough spells will be subsubmed into the underlying employment spell. Furlough will not appear as a separate status. This option will also be selected if furlough_status does not take either of the other two values.
* Alternative choices for furlough_choice: 
	* Choose value "furlough" to retain furlough statuses. For those on furlough, Status coding will be unusual: the last 2 digits represent the usual UKHLS furlough status (12 or 13). The other digits represent the identifiable simultaneously-held employment status (1,2,100 - self-employed, employed, in work with no information about self empl/empl). So when option "furlough" is chosen, status values when furloughed are provided as 112,113,212,213,10012,10013.
	* Choose value "noadjust" to treat jbstat values 12 and 13 as the original LW code (developed prior to Covid) would: any status other than inlist(jbstat,1,2,100) is treated as non-employment. Statuses 12 and 13 will appear but no account of these representing furlough is taken.
global furlough_choice 			"nofurlough"


* You can select a value for the minimum age at which you choose to believe that the individual has a status that is not full-time education, i.e. the earliest age at which a non-education status such as employment will not be treated as an error and discarded.
* Detail for noneducstatus_minage (Minimum age for non-education status): All observations for a pidp in the relevant Wave will be dropped if that pidp has a non-education spell starting or ending at an age below this value. 
* Which data are affected by choice of noneducstatus_minage? The value is used to select data from lifemst files !!! PLUS POSSIBLY OTHERS !!! and will impact all datasets using those data.
* Default value of noneducstatus_minage: The default value of 0 means the resulting dataset includes all spells starting or ending after birth. Note that spells starting or ending before a particular age can be dropped outside of dataset creation stage of your research.
* Suggested alternative values for noneducstatus_minage: 10 (which will replicate Liam Wright's code in this respect), or 16, or other values depending on research needs.  
* Comparison with Liam Wright's (2020) code: LW code dropped pidp-Waves (all data for an individual within an affected wave) where the raw data record that the individual started or ended a non-education spell before age 12. 
global noneducstatus_minage		0


* You can select the extent to which data will be dropped in response to implausible dates.
* Detail for implausibledates_drop: 
* Default choice for implausibledates_drop: The default choice of "obs" retains the most data: only spells ("obs"ervations) with implausible dates will be dropped, and other spells in that pidp-Wave will be retained and renumbered.
* Alternative choices for implausibledates_drop: Any other value than "obs" will lead to all data for that pidp-Wave being dropped.
* Comparison with Liam Wright's (2020) code: LW code dropped the whole pidp-Wave (all data for an individual within an affected wave) if there was an implausible date for that individual in that Wave. Any other value than "obs" will replicate this. 
global implausibledates_drop	"obs"	


* You can choose whether to correct, or drop, pidp_Waves with non-chronological year, season-year or month-year spell start dates.
* The affected dataset derives from BHPS lifemst files.
* Default choice for nonchron_correct: "Y" (note that the "" are essential): The default choice of "Y" makes corrections and retains data. 
* Alternative choices for nonchron_correct: Leave blank or choose any other value to drop all observations for a pidp-Wave (for year and season-year) or all observations for a pidp (for month-year) where there is a non-chronological spell start date.
global nonchron_correct			"Y"


* Set maximum length of gap imputed by halving space between two adjacent spells.
global gap_length				12


* Choose whether the code should run quietly or nosily. The code takes some time to run (more than 20 minutes, depending on your setup.
* Default choice for quietly_noisily: "QUIETLY": The default choice of "QUIETLY" runs the code quietly. Leave blank or choose any other value to run noisily.
global quietly_noisily			//"QUIETLY"


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

if "$quietly_noisily"=="QUIETLY" {
	qui {
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

			}
		}
	}

if "$quietly_noisily"!="QUIETLY" {
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

		}
	}
	
di in red "Program Started: $start_time"
di in red "Program Completed: $S_TIME"	

capture log close
	