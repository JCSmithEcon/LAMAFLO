/*
********************************************************************************
DYNAMICS LAUNCH PROGRAMME.DO

	!! NOTE !! THIS REQUIRES PACKAGE tolong.
	IF NOT ALREADY INSTALLED, PLEASE INSTALL USER-WRITTEN PACKAGE tolong TO ENABLE A FASTER CONVERSION FROM WIDE TO LONG: IN THE STATA COMMAND WINDOW, TYPE "ssc install tolong".

	YOUR DATA MUST CONTAIN THE FOLLOWING VARIABLES:
		STATUS
		SPELL NUMBER
		START DATE (OF SPELL)
		END DATE (OF SPELL)
	YOUR DATA CAN ALSO CONTAIN OTHER VARIABLES. IN THE CODE BELOW, ONLY THE ABOVE ARE USED AS THE FOCUS IS LABOUR MARKET DYNAMICS VIA STATUS CHANGES. MODIFIED CODE COULD ENCOMPASS OTHER VARIABLES.

	THIS DO FILE MAKES CHOICES AND SETS GLOBAL MACRO VALUES USED ACROSS THE DYNAMICS DO FILES.
	SECTION 1: PLEASE CHANGE THE GLOBAL MACRO VALUES TO FIT WITH YOUR FOLDERS.
	SECTION 2: PLEASE CHANGE THE GLOBAL MACRO VALUES TO FIT WITH YOUR FILES AND VARIABLES.
	SECTION 3: PLEASE NAME AND DEFINE THE STATES YOU WISH TO ANALYSE IN TERMS OF THE VALUES OF THE RAW STATUS VARIABLE IN YOUR DATA. 
	SECTION 4: CHOOSE:
		- ANY AGE RESTRICTIONS YOU WISH IMPOSED. DEFAULTS WILL RETAIN INFORMATION FOR LABOUR MARKET ACTIVITY OF INDIVIDUALS AGED BETWEEN 16 AND 70.
		- WHEN YOU WISH MONTHLY FLOWS AND FLOW RATES DATA TO START. THE DEFAULT IS JANUARY 1990, REFLECTING THE START OF BHPS INTERVIEWING. RECALLED INFORMATION MEAN LABOUR MARKET HISTORY DATA STARTS IN //HEREHEREHERE (THOUGH THERE ARE VERY FEW OBSERVATIONS THAT FAR BACK).
		- WHETHER THE CODE SHOULD RUN QUIETLY OR NOISILY.
	SECTION 5: SPECIFY WHICH COMPONENTS OF DYNAMIC ANALYSIS YOU WISH TO RUN AND WHICH DATASETS YOU WISH TO OUTPUT.
	SECTION 6: THE FULL CODE CAN BE RUN WITHIN THIS DO FILE BY CHANGING run_full TO YES. OTHERWISE, EACH DO FILE SHOULD BE RUN SEPARATELY.
	SECTION 7: NO USER CHANGES REQUIRED.
	
********************************************************************************
*/
clear all
macro drop _all
set more off


/*
SECTION 1. Change file locations. Select appropriate file suffix (stub) if using Special License files. 
*/
* Top-level directory.
cd "C:/Users/user/"
* Folder containing data to be analysed.
global input_fld			"raw data"
* Folder dynamic data outputs will be saved in.
global output_fld			"dynamic data"
* Folder do files are kept in.
global do_fld				"do files"
* Set Personal ado folder
sysdir set PLUS 			"${do_fld}/ado/"


/*
SECTION 2. Specify name of data file and variables. !! NOTE: GLOBAL VALUES "Merged Dataset", "Status", "Spell", "Start_MY" and "End_MY" WILL BE THE CORRECT NAMES WHEN ANALYSING WORK-LIFE HISTORIES USING LIAM-WRIGHT(2020)-BASED CODE.
*/
* Name of data file.
global data					"Merged Dataset"							
* Name of Status (State, Activity) variable. For work-life histories, this is a variable containing codes for employment, unemployment, full-time student, etc.
global status				"Status"
* Name of spell number variable.
global spell				"Spell"
* Name of Start Date variable.
global start				"Start_MY"
* Name of End Date variable.
global end					"End_MY"
* Name of log file. !! NOTE: LOG FILE WILL BE SAVED IN THE FOLDER DO FILES ARE KEPT IN. COMMENT OUT USING THE LOG FILE NAME USING // OR LEAVE BLANK "" FOR NO LOG FILE.
global logfile				"${data}_Dynamics.log"						


/*
SECTION 3. Define statuses you wish to analyse dynamically.
*/
* Number of states. !! NOTE: UP TO 20 STATES CAN BE SPECIFIED.
global numberofstates		"3"

* Which values of your Status variable relate to each state? !! NOTE: SEPARATE VALUES WITH COMMAS OR SPACES. COPY LINES TO DEFINE UP TO 20 STATES. DEFAULT VALUES RELATE TO CONVENTIONAL ALLOCATIONS IN A 3-STATE LABOUR-MARET MODEL (employment, unemployment, inactivity/nonparticipation).
global state1_values		"1 2 5 9 10 11 100 103"
global state2_values		"3"
global state3_values		"4 6 7 8 97 101"
global state4_values		""
global state5_values		""

* Names of states. !! NOTE: PLEASE CHOOSE SINGLE LETTER NAMES. COPY LINES TO DEFINE UP TO 20 STATES. DEFAULT VALUES ARE E (employment), U (unemployment), N (inactivity/nonparticipation).
global state1_name			"E"
global state2_name			"U"
global state3_name			"N"
global state4_name			""
global state5_name			""


/*
SECTION 4. Choose optional parameters.
*/
* Drop spells starting below a particular age.
global minage				"16"										// LEAVE BLANK "" OR USE "0" TO USE ALL DATA WITH NO AGE RESTRICTION.
* Drop spells starting above a particular age.
global maxage				"70"										// LEAVE BLANK "" OR USE "0" TO USE ALL DATA WITH NO AGE RESTRICTION.

* When do you want flows data to start?
global flows_start			1990jan										// 4-DIGIT YEAR FOLLOWED BY FIRST 3 LETTERS OF MONTH, WITH NO SPACES. 

* Choose whether the code should run quietly or nosily. The code takes some time to run (more than 20 minutes, depending on your setup).
* Default choice for quietly_noisily: "QUIETLY": The default choice of "QUIETLY" runs the code quietly. Leave blank or choose any other value to run noisily.
global quietly_noisily		//"QUIETLY"



/*
SECTION 5. Select required outputs in terms of variables and separate datasets. NOTE: Labour force status (LFS), generated according to your choices above, is always created.
*/
* The following will be recorded in a single dataset "Dynamics_${data}.dta" organised by pidp and Spell (where "${data}" is the user-selected `raw' dataset. NOTE: The ordering of the data means Transitions/Durations/Counts appear in the final columns):
global Transitions			"Y"
global Durations			"Y"
global Counts				"Y"

* Datasets of work-life activity organised by month, rather than spell. 
	* - The (panel) data can be requested in wide form: ordered by pidp, with each month's activities listed `horizontally' and identified by Stata month number.
	* - And/or the (panel) data can be requested in long form: ordered by pidp-month. The provided dataset lists all months (vertically) for each pidp. 
global Monthly_Wide			"Y"
global Monthly_Long			"Y"

* If "Y" is selected, labour market flows will be provided in a dataset organised by quarterly date.
global Quarterly Flows		"Y"


/*
SECTION 6. Choice whether to run the full code.
*/
* Decide whether to run full code (set equal to "YES" TO RUN FULL CODE, NOTING THAT THE "" ARE ESSENTIAL)
global run_full				"YES"


********************************************************************************
/*
SECTION 7. NO USER CHANGES OR CHOICES ARE REQUIRED IN THIS SECTION. Run Do files.
*/

if "${logfile}"!=""{
	capture log close
	log using "${do_fld}/${logfile}", replace
	}

do "${do_fld}/Create Programs_Dynamics"

if "$run_full"=="YES"{
	cls
	global start_time "$S_TIME"
	di in red "Dynamic data creation Started: $start_time"
	
	
prog_reopenfile "${input_fld}/${data}.dta"

prog_labels_dynamics

* List of state names
global statenames = " ${state1_name} ${state2_name} ${state3_name} ${state4_name} ${state5_name} ${state6_name} ${state7_name} ${state8_name} ${state9_name} ${state11_name} ${state12_name} ${state13_name} ${state14_name} ${state15_name} ${state16_name} ${state17_name} ${state18_name} ${state19_name} ${state20_name} "
display in red "List of state names: $statenames"


* Drop spells starting before and ending after specified ages. Default age range is 16 to 70. If minage=="0" or minage=="" and maxage=="0" or maxage=="", all data are retained
if ${minage}>0{
	prog_makeage ${start}												// CREATES AGE AT START OF SPELL = AGE AT TRANSITION, GIVEN DEFINITION OF TRANSITION AS t-(t-1).
	drop if ${start}_Age<$minage
	by pidp (${spell}), sort: replace ${spell}=_n	
	}
if ${maxage}>0{
	prog_makeage ${start}
	drop if ${start}_Age>$maxage
	by pidp (${spell}), sort: replace ${spell}=_n	
	}
qui su ${start}_Age
display in red "Age at start of spell ranges from `r(min)' to `r(max)'."


//do LFS.do

* Define required statuses
local i=0
while `i'<$numberofstates{
	local i=`i'+1
	display in red "Dealing with state `i'"
	global S`i'_count : word count ${state`i'_values}					// NUMBER OF VALUES.
	display "Number of values used for state `i': ${S`i'_count}"
	local j=1
	while `j'<${S`i'_count}+1{
		global S`i'_`j' : word `j' of ${state`i'_values}				// EXTRACT EACH VALUE.
		display "Value `j' for state `i' is ${S`i'_`j'}"
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
label var LFS "Status, ${numberofstates} states"

* Generate previous spell labour force status string variable
by pidp ($spell), sort: gen LFS_1=LFS[_n-1]
replace LFS_1="B" if LFS_1=="" & ${spell}==1 							// LFS B INDICATES PREVIOUSLY UNOBSERVED ("BORN" INTO THE DATASET).
label var LFS_1 "Previous spell labour force status"					// label var LFS_1 "Previous spell labour force status (EUNMB)"


//do Transition.do

* Generate spell transition variable
gen LFS2=LFS_1+LFS
label var LFS2 "Transition (across labour force spells)"

* Generate spell transition dates
by pidp ($spell), sort: gen TransitionDate=${start}						// TRANSITION LFS2 HAPPENED AT CURRENT SPELL START DATE.
format TransitionDate %tmmonCCYY
label var TransitionDate "Date transition occurred (current spell start date)"


//do SpellDurations.do

* Spell durations at spell end date
gen DurSpell=datediff(dofm(${start}), dofm(${end}), "month")
label var DurSpell "Duration (months) of spell at spell end date"


//do SpellTypeDurations.do

* Durations of particular spell types at spell end date 
foreach X in "${state1_name}" "${state2_name}" "${state3_name}" "${state4_name}" "${state5_name}" "${state6_name}" "${state7_name}" "${state8_name}" "${state9_name}" "${state11_name}" "${state12_name}" "${state13_name}" "${state14_name}" "${state15_name}" "${state16_name}" "${state17_name}" "${state18_name}" "${state19_name}" "${state20_name}" {
	by pidp: gen Dur`X'=sum(DurSpell) if LFS=="`X'"
	capture confirm variable Dur
	if _rc==0 {
		drop Dur
		continue, break
	}
	by pidp (${spell}), sort: replace Dur`X'=Dur`X'[_n-1] if missing(Dur`X')
	replace Dur`X'=0 if missing(Dur`X')
	label var Dur`X' "Duration (months) in state `X' at spell end date"
	}


//do SpellTypeCounts.do
	
* Count of particular spell types
foreach X in "${state1_name}" "${state2_name}" "${state3_name}" "${state4_name}" "${state5_name}" "${state6_name}" "${state7_name}" "${state8_name}" "${state9_name}" "${state11_name}" "${state12_name}" "${state13_name}" "${state14_name}" "${state15_name}" "${state16_name}" "${state17_name}" "${state18_name}" "${state19_name}" "${state20_name}" {
	gen temp=1 if LFS=="`X'"
	qui su temp
	if r(N)==0 {
		drop temp
		continue, break
		}
	by pidp: gen CountSpell`X'=sum(temp) if LFS=="`X'"
	by pidp ($spell), sort: replace CountSpell`X'=CountSpell`X'[_n-1] if missing(CountSpell`X')
	replace CountSpell`X'=0 if missing(CountSpell`X')
	label var CountSpell`X' "Count of spells of `X' to date"
	drop temp
	}
	

//do TransitionTypeCounts.do

* Count of particular transition types
levelsof LFS2, local(LFS2levels)
foreach X in `LFS2levels' {
	gen temp=1 if LFS2=="`X'"
	qui su temp
	if r(N)==0 {
		drop temp
		continue, break
		}
	by pidp: gen CountTransition`X'=sum(temp) if LFS2=="`X'"
	by pidp ($spell), sort: replace CountTransition`X'=CountTransition`X'[_n-1] if missing(CountTransition`X')
	replace CountTransition`X'=0 if missing(CountTransition`X')
	label var CountTransition`X' "Count of transitions `X' to date"
	drop temp
	}


sort pidp ${spell}

save "${output_fld}/Dynamics_Merged Dataset.dta", replace

di in red "Dynamic data creation Started: $start_time"
di in red "Program Started: $start_time"
di in red "Statuses-Transitions-Durations-Counts Completed: $S_TIME"	


//do Flows.do

global start_time "$S_TIME"
di in red "Spell-Monthly Conversion Started: $start_time"

prog_reopenfile "${output_fld}/Dynamics_Merged Dataset.dta"


* Convert pidp-spell data to wide pidp-month data.

drop if ${start}<monthly("${flows_start}","YM")-1						// DEFAULT IS TO OBTAIN FLOWS FROM JANUARY 1990 ONWARDS. 

qui su $start
global minsdate=r(min)
global maxsdate=r(max)
qui su ${spell}
global maxspells=r(max)

by pidp ($spell), sort: egen pidpstart=min(${start})					// RANGE OF SPELL DATES FOR EACH INDIVIDUAL, TO ENABLE DROPPING REDUNDANT DATA.
by pidp ($spell), sort: egen pidpend=max($end)
format pidpstart pidpend %tm

keep pidp ${spell} ${status} ${start} ${end} pidpstart pidpend

reshape wide ${status} ${start} ${end}, i(pidp) j(${spell})

tempfile Temp

local m=${minsdate}-1													// LOOP AROUND MONTHS AND SPELLS.
while `m'<=($maxsdate-1) {
	local m=`m'+1
	local mcur=`m'-$minsdate+1
	local mmax=$maxsdate-$minsdate+1
	local month : di %tm `m'
	display "Started month `m' (`mcur'/`mmax'): `month'"
	
		preserve

		drop if `m'<pidpstart-1 | `m'>pidpend+1							// DROP pidps WHOSE SPELL DATES DO NOT ENCOMPASS MONTH OF INTEREST.
		
		gen lfs`m'="O"
		local i=0 
		while `i'<=($maxspells-1) {
			local i=`i'+1
			forvalues j=1/$numberofstates{
				forvalues k=1/${S`j'_count}{
					qui replace lfs`m'="${state`j'_name}" if inlist(Status`i',${S`j'_`k'}) & ${start}`i'<=`m' & ${end}`i'>`m' & !missing(${start}`i',${end}`i')
					}
				}
			qui replace lfs`m'="M" if missing(Status`i') & ${start}`i'<=`m' & ${end}`i'>`m' & !missing(${start}`i',${end}`i')
			}
			
		keep pidp lfs`m'
		qui save "`Temp'", replace
		restore

	qui merge 1:1 pidp using "`Temp'", nogen
	
	display "Finished month `m'"
	}
	
//$Monthly_Wide
save  "${output_fld}/Dynamics_Merged Dataset_wide_m.dta", replace

di in red "Spell-Monthly Wide Started: $start_time"
di in red "Spell-Monthly Wide Completed: $S_TIME"	


* Convert wide pidp-month data to long pidp-month data.
//ssc uninstall tolong													// UNINSTALL USER-WRITTEN STATA PACKAGE tolong
//ssc install tolong													// INSTALL tolong FASTER RESHAPE LONG PACKAGE FROM SSC.

prog_reopenfile  "${output_fld}/Dynamics_Merged Dataset_wide_m.dta"

keep lfs* pidp
tolong lfs#, i(pidp) j(month)											// tolong IS IMPLEMENTED AS A PROGRAM. CREDIT: Author	Rafal Raciborski  rraciborski@gmail.com								
sort pidp month

//$Monthly_Long
save  "${output_fld}/Dynamics_Merged Dataset_long_m.dta", replace

di in red "Spell-Monthly Long Completed: $S_TIME"


* Create quarterly flows.

prog_reopenfile "${output_fld}/Dynamics_Merged Dataset_long_m.dta"
encode lfs, gen(temp)													// TO LAG, A NON-STRING VARIABLE IS REQUIRED. E.G. VALUES 1,2,3,4, WHICH ARE LABELLED ACCORDING TO THE ORIGINAL ALPHABETIC VARIABLE (E.G. E,I,M,U) (THE LABEL NAME IS temp).
compress
tab lfs
tab temp
label list temp
tsset pidp month
gen byte temp_1=l1.temp
label values temp_1 temp
drop temp
decode temp_1, gen(lfs_1)
tab temp_1
tab lfs_1
drop temp_1
gen lfs2=lfs_1 + lfs
drop lfs_1 lfs
gen lfs2_len=strlen(lfs2)
drop if lfs2=="OO" | lfs2_len!=2										// THIS LINE CAN BE APPLIED IF STATE NAMES ALL CONSIST OF 1 LETTER.
drop lfs2_len
sort month lfs2
egen double flows=count(pidp), by(month lfs2)
label var lfs2 "Transition: 2-digit alphabetical code"
label var flows "Sum of the gross flows, by month and flow"

drop pidp
drop if strpos(lfs2,"O")>0
quietly by month lfs2: gen duplic = cond(_N==1,0,_n)
drop if duplic > 1
drop duplic

reshape wide flows, i(month) j(lfs2) string

drop flowsMM

gen day=dofm(month)
format day %td
gen quarter=qofd(day)
format quarter %tq

collapse /*
	*/ (sum) flowsEE (sum) flowsEU (sum) flowsEN (sum) flowsEM (sum) flowsUE (sum) flowsUU (sum) flowsUN (sum) flowsUM (sum) flowsNE (sum) flowsNU (sum) flowsNN (sum) flowsNM (sum) flowsME (sum) flowsMU (sum) flowsMN /*
	*/ , by(quarter)

compress

save "${output_fld}/Dynamics_Merged Dataset_flows_q.dta", replace


log close
	
