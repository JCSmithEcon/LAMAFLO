/*
********************************************************************************
DYNAMICS LAUNCH PROGRAMME.DO

	NOTE: "Dynamics_Flows.do" REQUIRES USER-WRITTEN PROGRAM tolong. THIS CODE UNINSTALLS/INSTALLS THAT PROGRAM FROM SSC; STATA DOES NOT ALWAYS LOCATE THE PACKAGE UNLESS RECENTLY INSTALLED.

	YOUR DATA MUST CONTAIN THE FOLLOWING VARIABLES:
		STATUS
		SPELL NUMBER
		START DATE (OF SPELL)
		END DATE (OF SPELL)
		INTERVIEW DATE
	BIRTH DATE IS REQUIRED IF YOU WISH TO RESTRICT THE SAMPLE BY AGE (BUT THIS STEP CAN BE OMITTED, IN WHICH CASE BIRTH DATE IS NOT REQUIRED).

	THIS DO FILE MAKES CHOICES AND SETS GLOBAL MACRO VALUES USED ACROSS THE DYNAMICS DO FILES.
	SECTION 1: PLEASE CHANGE THE GLOBAL MACRO VALUES TO FIT WITH YOUR FOLDERS.
	SECTION 2: PLEASE CHANGE THE GLOBAL MACRO VALUES TO FIT WITH YOUR FILES AND VARIABLES.
	SECTION 3: PLEASE NAME AND DEFINE THE STATES YOU WISH TO ANALYSE IN TERMS OF THE VALUES OF THE RAW STATUS VARIABLE IN YOUR DATA. 
	SECTION 4: CHOOSE:
		- ANY AGE RESTRICTIONS YOU WISH IMPOSED. DEFAULTS WILL RETAIN INFORMATION FOR LABOUR MARKET ACTIVITY OF INDIVIDUALS AGED BETWEEN 16 AND 70. A BIRTH DATE VARIABLE IS REQUIRED TO IMPOSE AGE RESTRICTIONS.
		- IF FLOWS ARE REQUESTED: WHEN YOU WISH MONTHLY FLOWS AND FLOW RATES DATA TO START. THE DEFAULT IS JANUARY 1990, REFLECTING THE START OF BHPS INTERVIEWING. RECALLED INFORMATION MEAN LABOUR MARKET HISTORY DATA STARTS IN //HEREHEREHERE (THOUGH THERE ARE VERY FEW OBSERVATIONS THAT FAR BACK).
		- WHETHER THE CODE SHOULD RUN QUIETLY OR NOISILY.
	SECTION 5: SPECIFY WHICH COMPONENTS OF DYNAMIC ANALYSIS YOU WISH TO RUN AND WHICH DATASETS YOU WISH TO OUTPUT.
	SECTION 6: NO USER CHANGES REQUIRED.
	
********************************************************************************
*/
clear all
macro drop all
set more off


/*
SECTION 1. Change file locations. Select appropriate file suffix (stub) if using Special License files. 
*/
* Top-level directory.
cd "C:/Users/ecscd/OneDrive - University of Warwick/"
* Folder containing data to be analysed.
global input_fld					"LAMAFLO JCS Datasets on OneDrive/Dynamics/23Jan EUNM QUI"
* Folder dynamic data outputs will be saved in.
global output_fld					"LAMAFLO JCS Datasets on OneDrive/Dynamics/23Jan EUNM QUI"
* Folder do files are kept in.
global do_fld						"LAMAFLO Stata code on OneDrive - JCS"
* Set Personal ado folder
sysdir set PLUS 					"${do_fld}/ado/"


/*
SECTION 2. Specify name of data file and variables. NOTE: GLOBAL VALUES "Merged Dataset", "Status", "Spell", "Start_MY" and "End_MY" WILL BE THE CORRECT NAMES WHEN ANALYSING WORK-LIFE HISTORIES USING LIAM-WRIGHT(2020)-BASED CODE.
*/
* Name of data file.
global data							"Merged Dataset"							
* Name of Status (State, Activity) variable. For work-life histories, this is a variable containing codes for employment, unemployment, full-time student, etc.
global status						"Status"
* Name of spell number variable.
global spell						"Spell"
* Name of Start Date variable.
global start						"Start_MY"
* Name of End Date variable.
global end							"End_MY"
* Name of Interview Date variable.
global intdate						"IntDate_MY"

* Name of log file. NOTE: LOG FILE WILL BE SAVED IN THE FOLDER DO FILES ARE KEPT IN. COMMENT OUT USING THE LOG FILE NAME USING // OR LEAVE BLANK "" FOR NO LOG FILE.
global logfile						"Dynamics_${data}_23Jan_EUNM_QUI.log"							


/*
SECTION 3. Define statuses you wish to analyse dynamically.
*/
* Number of states. NOTE: UP TO 20 STATES CAN BE SPECIFIED.
global numberofstates				"3"

* Which values of your Status variable relate to each state? !! NOTE: SEPARATE VALUES WITH COMMAS OR SPACES. COPY LINES TO DEFINE UP TO 20 STATES. DEFAULT VALUES RELATE TO CONVENTIONAL ALLOCATIONS IN A 3-STATE LABOUR-MARET MODEL (employment, unemployment, inactivity/nonparticipation).
global state1_values				"1 2 5 9 10 11 100 103"
global state2_values				"3"
global state3_values				"4 6 7 8 97 101"
global state4_values				""
global state5_values				""

* Names of states. !! NOTE: PLEASE CHOOSE SINGLE LETTER NAMES. COPY LINES TO DEFINE UP TO 20 STATES. DEFAULT VALUES ARE E (employment), U (unemployment), N (inactivity/nonparticipation).
global state1_name					"E"
global state2_name					"U"
global state3_name					"N"
global state4_name					""
global state5_name					""


/*
SECTION 4. Choose optional parameters.
*/
* Drop spells starting below a particular age.
global minage						"16"										// LEAVE BLANK "" OR USE "0" TO USE ALL DATA WITH NO AGE RESTRICTION.
* Drop spells starting above a particular age.
global maxage						"70"										// LEAVE BLANK "" OR USE "0" TO USE ALL DATA WITH NO AGE RESTRICTION.
* Name of Birth Date variable. !! NOTE: BIRTH DATE IS REQUIRED TO DROP BY AGE. If no Birth Date variable is available or specified, all data will be used.
global birth						"Birth_MY"

* When do you want flows data to start?
global flows_start					1990jan										// 4-DIGIT YEAR FOLLOWED BY FIRST 3 LETTERS OF MONTH, WITH NO SPACES. 

* Choose whether the code should run quietly or nosily. The code takes some time to run (more than 20 minutes, depending on your setup).
* Default choice for quietly_noisily: "QUIETLY": The default choice of "QUIETLY" runs the code quietly. Leave blank or choose any other value to run noisily.
global quietly_noisily				"QUIETLY"


/*
SECTION 5. Select required outputs in terms of variables and separate datasets. NOTE: "Labour force" status (LFS) and transitions (LFS2), generated according to your choices above, are always created.
*/
* When requested, Transitions, Durations and Counts will be recorded in a single dataset "Dynamics_${data}.dta" organised by pidp and Spell, where "${data}" is the user-selected `raw' dataset. NOTE: The other variables in the dataset are pidp, $spell, $status, $start, $end.
global Transitions					"Y"
global Durations					"Y"
global Counts						"Y"

* Choose "Y" to request datasets of work-life activity in the form of sequences of statuses, organised by month (rather than spell). 
	* - The (panel) data can be requested in wide form: ordered by pidp, with each month's activities listed `horizontally' and identified by Stata month number. Any Stata month number can be shown in normal date format by typing "di %tm [Stata month number]" (e.g. "di %tm 360" reveals that Stata month 360 is 1990m1).
	* - And/or the (panel) data can be requested in long form: ordered by pidp-month. The provided dataset lists all months (vertically) for each pidp. 
global Monthly_Wide					"Y"
global Monthly_Long					"Y"

* If "Y" is selected, flows (sums of moves between your chosen statuses) and flow rates (flows divided by stock in the initial status) will be provided in a dataset organised by date. Separate files are provided for each requested time interval.
global Monthly_Flows_Unweighted		"Y"
global Quarterly_Flows_Unweighted	"Y"
global Annual_Flows_Unweighted		"Y"
global Monthly_Flows_Weighted		"Y"
global Quarterly_Flows_Weighted		"Y"
global Annual_Flows_Weighted		"Y"
* NOTE: If you want weighted flows, this requires accessing BHPS/UKHLS data to obtain weights. The following macro values were set in "Launch Programme.do". If necessary (e.g. if you have started a new Stata session), please re-specify these details relating to raw BHPS and UKHLS data:
	* Directory in which UKHLS and BHPS files are kept.
	global fld						"LAMAFLO UKHLS BHPS Data on OneDrive"	
	* BHPS Folder Prefix for Stata Files
	global bhps_path				bhps
	* UKHLS Folder Prefix for Stata Files
	global ukhls_path				ukhls
	* Common stub which is affixed on end of original Stata files (e.g. "_protect" where using Special Licence files; blank for End User Licence files)
	global file_type					
	* Number of BHPS Waves to be collected
	global bhps_waves				18
	* Number of Understanding Society Waves to be collected
	global ukhls_waves				12		

* If "Y" is selected, information organised by pidp-Wave (more specifically, pidp-interview date) will be provided in ${output_fld}/Dynamics_All_AtInt.dta"	on dynamic features of work-life history: duration in each of the statuse chosen above, up to and including interview date; time spent in spell current at interview date (and its start and end date); counts of spells in each of the statuses chosen above up to interview date; counts of transitions between those statuses up to interview date.
global Interview_Date				"Y"


	
********************************************************************************
/*
SECTION 6. NO USER CHANGES OR CHOICES ARE REQUIRED IN THIS SECTION. Run Do files.
*/

if "$quietly_noisily"!="QUIETLY" {
	
	cls
	global start_time_full "$S_TIME"

	if "${logfile}"!=""{
		capture log close
		log using "${do_fld}/${logfile}", replace
		}

	do "${do_fld}/Dynamics_Create Programs"

	di in red "Dynamic data creation Started: $start_time_full"
		
	prog_reopenfile "${input_fld}/${data}.dta"
	keep pidp $status $spell $start $end $birth $intdate

	* Drop spells starting before and ending after specified ages, if requested and if birth date variable is specified. Default age range is 16 to 70. If minage=="0" or minage=="" and maxage=="0" or maxage=="", all data are retained.
	if "$birth"!="" & ${minage}>0{
		prog_makeage ${start}												// CREATES AGE AT START OF SPELL = AGE AT TRANSITION, GIVEN DEFINITION OF TRANSITION AS t-(t-1).
		drop if ${start}_Age<$minage
		by pidp (${spell}), sort: replace ${spell}=_n	
		}
	if "$birth"!="" & ${maxage}>0{
		prog_makeage ${start}
		drop if ${start}_Age>$maxage
		by pidp (${spell}), sort: replace ${spell}=_n	
		}
	cap rename ${start}_Age Age_SpellStart
	cap confirm variable Age_SpellStart
	if _rc==0 {
		qui su Age_SpellStart
		di in red "Age at start of spell ranges from `r(min)' to `r(max)'."
		}

	* List of state names
	global statenames ""
	foreach i in $state1_name $state2_name $state3_name $state4_name $state5_name $state6_name $state7_name $state8_name $state9_name $state11_name $state12_name $state13_name $state14_name $state15_name $state16_name $state17_name $state18_name $state19_name $state20_name {
		if "`i'"==""{
			continue, break
			}
		global statenames $statenames `i'
		}
	di in red "State names are $statenames"

	* Define required statuses
	local i=0
	while `i'<$numberofstates{
		local i=`i'+1
		di in red "Dealing with state `i'"
		global S`i'_count : word count ${state`i'_values}					// NUMBER OF VALUES.
		di "Number of values used for state `i': ${S`i'_count}"
		local j=1
		while `j'<${S`i'_count}+1{
			global S`i'_`j' : word `j' of ${state`i'_values}				// EXTRACT EACH VALUE.
			di "Value `j' for state `i' is ${S`i'_`j'}"
			local j=`j'+1
			}
		}

	* Generate status variable
	gen LFS=""
	forvalues i=1/$numberofstates{
		forvalues j=1/${S`i'_count}{
			replace LFS="${state`i'_name}" if inlist(${status},${S`i'_`j'})
			}
		}
	replace LFS="M" if missing(${status})
	di in red "Table of states (M captures missing status):"
	noisily tab LFS, missing

	* Generate previous spell labour force status string variable			// LFS AND LFS2 ARE NEEDED FOR "Dynamics_Transitions.do" AND "Dynamics_Counts.do". 
	by pidp (${spell}), sort: gen LFS_1=LFS[_n-1]
	replace LFS_1="B" if LFS_1=="" & ${spell}==1 							// LFS B INDICATES PREVIOUSLY UNOBSERVED ("BORN" INTO THE DATASET).

	* Generate spell transition variable
	gen LFS2=LFS_1+LFS if LFS_1!="B"
	levelsof LFS2, clean local(levelsLFS2)									// LIST OF TRANSITIONS OUT OF DEFINED STATES.
	global LFS2levels `levelsLFS2'
	di in red "Transitions between chosen states are $LFS2levels"
	di in red "Table of transitions (including flows into/out of missing):"
	noisily tab LFS2, missing

	* Generate spell transition variable including "transition" ("birth") into first status
	gen LFS2_B=LFS_1+LFS

	* Generate spell transition dates
	by pidp (${spell}), sort: gen TransitionDate_MY=${start}				// TRANSITION LFS2 HAPPENED AT CURRENT SPELL START DATE.


	* Generate durations
	if "$Durations"=="Y" | "$Durations"=="YES" {
		di in red "Calculating durations"
		do "${do_fld}/Dynamics_Durations.do"
		}


	* Generate counts
	if "$Counts"=="Y" | "$Counts"=="YES" {
		di in red "Calculating counts"
		do "${do_fld}/Dynamics_Counts.do"
		}

		
	do "${do_fld}/Dynamics_Labels.do"
	do "${do_fld}/Dynamics_Apply Labels.do"

	prog_format
	
	save "${output_fld}/Dynamics_Merged Dataset.dta", replace

	di in red "Dynamic data creation Started: $start_time_full"
	di in red "Statuses-Transitions-Durations-Counts Completed: $S_TIME"	


	* Generate flows
	if "$Monthly_Flows_Weighted"=="Y" | "$Quarterly_Flows_Weighted"=="Y" | "$Annual_Flows_Weighted"=="Y" | "$Monthly_Flows_Weighted"=="YES" | "$Quarterly_Flows_Weighted"=="YES" | "$Annual_Flows_Weighted"=="YES" | "$Monthly_Flows_Unweighted"=="Y" | "$Quarterly_Flows_Unweighted"=="Y" | "$Annual_Flows_Unweighted"=="Y" | "$Monthly_Flows_Unweighted"=="YES" | "$Quarterly_Flows_Unweighted"=="YES" | "$Annual_Flows_Unweighted"=="YES"{
		di in red "Calculating flows and flow rates"
		do "${do_fld}/Dynamics_Flows.do"
		}

	* Generate information by wave (interview date)
	if "$Interview_Date"=="Y"{
		di in red "Calculating dynamic information for each pidp at each interview date (wave)"
		do "${do_fld}/Dynamics_byInterviewDate.do"

	}
		

if "$quietly_noisily"=="QUIETLY" {

	qui {
		
		cls
		global start_time_full "$S_TIME"

		if "${logfile}"!=""{
			capture log close
			log using "${do_fld}/${logfile}", replace
			}

		do "${do_fld}/Dynamics_Create Programs"

		di in red "Dynamic data creation Started: $start_time_full"
			
		prog_reopenfile "${input_fld}/${data}.dta"
		keep pidp $status $spell $start $end $birth $intdate

		* Drop spells starting before and ending after specified ages, if requested and if birth date variable is specified. Default age range is 16 to 70. If minage=="0" or minage=="" and maxage=="0" or maxage=="", all data are retained.
		if "$birth"!="" & ${minage}>0{
			prog_makeage ${start}												// CREATES AGE AT START OF SPELL = AGE AT TRANSITION, GIVEN DEFINITION OF TRANSITION AS t-(t-1).
			drop if ${start}_Age<$minage
			by pidp (${spell}), sort: replace ${spell}=_n	
			}
		if "$birth"!="" & ${maxage}>0{
			prog_makeage ${start}
			drop if ${start}_Age>$maxage
			by pidp (${spell}), sort: replace ${spell}=_n	
			}
		cap rename ${start}_Age Age_SpellStart
		cap confirm variable Age_SpellStart
		if _rc==0 {
			qui su Age_SpellStart
			di in red "Age at start of spell ranges from `r(min)' to `r(max)'."
			}

		* List of state names
		global statenames ""
		foreach i in $state1_name $state2_name $state3_name $state4_name $state5_name $state6_name $state7_name $state8_name $state9_name $state11_name $state12_name $state13_name $state14_name $state15_name $state16_name $state17_name $state18_name $state19_name $state20_name {
			if "`i'"==""{
				continue, break
				}
			global statenames $statenames `i'
			}
		di in red "State names are $statenames"

		* Define required statuses
		local i=0
		while `i'<$numberofstates{
			local i=`i'+1
			di in red "Dealing with state `i'"
			global S`i'_count : word count ${state`i'_values}					// NUMBER OF VALUES.
			di "Number of values used for state `i': ${S`i'_count}"
			local j=1
			while `j'<${S`i'_count}+1{
				global S`i'_`j' : word `j' of ${state`i'_values}				// EXTRACT EACH VALUE.
				di "Value `j' for state `i' is ${S`i'_`j'}"
				local j=`j'+1
				}
			}

		* Generate status variable
		gen LFS=""
		forvalues i=1/$numberofstates{
			forvalues j=1/${S`i'_count}{
				replace LFS="${state`i'_name}" if inlist(${status},${S`i'_`j'})
				}
			}
		replace LFS="M" if missing(${status})
		di in red "Table of states (M captures missing status):"
		noisily tab LFS, missing

		* Generate previous spell labour force status string variable			// LFS AND LFS2 ARE NEEDED FOR "Dynamics_Transitions.do" AND "Dynamics_Counts.do". 
		by pidp (${spell}), sort: gen LFS_1=LFS[_n-1]
		replace LFS_1="B" if LFS_1=="" & ${spell}==1 							// LFS B INDICATES PREVIOUSLY UNOBSERVED ("BORN" INTO THE DATASET).

		* Generate spell transition variable
		gen LFS2=LFS_1+LFS if LFS_1!="B"
		levelsof LFS2, clean local(levelsLFS2)									// LIST OF TRANSITIONS OUT OF DEFINED STATES.
		global LFS2levels `levelsLFS2'
		di in red "Transitions between chosen states are $LFS2levels"
		di in red "Table of transitions (including flows into/out of missing):"
		noisily tab LFS2, missing

		* Generate spell transition variable including "transition" ("birth") into first status
		gen LFS2_B=LFS_1+LFS

		* Generate spell transition dates
		by pidp (${spell}), sort: gen TransitionDate_MY=${start}				// TRANSITION LFS2 HAPPENED AT CURRENT SPELL START DATE.


		* Generate durations
		if "$Durations"=="Y" | "$Durations"=="YES" {
			di in red "Calculating durations"
			do "${do_fld}/Dynamics_Durations.do"
			}


		* Generate counts
		if "$Counts"=="Y" | "$Counts"=="YES" {
			di in red "Calculating counts"
			do "${do_fld}/Dynamics_Counts.do"
			}

			
		do "${do_fld}/Dynamics_Labels.do"
		do "${do_fld}/Dynamics_Apply Labels.do"

		prog_format
		
		save "${output_fld}/Dynamics_Merged Dataset.dta", replace

		di in red "Dynamic data creation Started: $start_time_full"
		di in red "Statuses-Transitions-Durations-Counts Completed: $S_TIME"	


		* Generate flows
		if "$Monthly_Flows_Weighted"=="Y" | "$Quarterly_Flows_Weighted"=="Y" | "$Annual_Flows_Weighted"=="Y" | "$Monthly_Flows_Weighted"=="YES" | "$Quarterly_Flows_Weighted"=="YES" | "$Annual_Flows_Weighted"=="YES" | "$Monthly_Flows_Unweighted"=="Y" | "$Quarterly_Flows_Unweighted"=="Y" | "$Annual_Flows_Unweighted"=="Y" | "$Monthly_Flows_Unweighted"=="YES" | "$Quarterly_Flows_Unweighted"=="YES" | "$Annual_Flows_Unweighted"=="YES"{
			di in red "Calculating flows and flow rates"
			do "${do_fld}/Dynamics_Flows.do"
			}

		* Generate information by wave (interview date)
		if "$Interview_Date"=="Y"{
			di in red "Calculating dynamic information for each pidp at each interview date (wave)"
			do "${do_fld}/Dynamics_byInterviewDate.do"

		}
	}

	di in red " "
	di in red "Dynamic data creation Started: $start_time_full"
	di in red "Dynamic data creation Completed: $S_TIME"

	log close
