/*
********************************************************************************
DYNAMICS_BYINTERVIEWDATE.DO
	
	THIS FILE CREATES 1 FILE, Dynamics_All_AtInt.dta, ORGANISED BY pidp AND WAVE, CONTAINING:
	- EACH INDIVIDUAL'S DURATION OVER WORK-LIFE HISTORY IN STATE `k' UP TO EACH INTERVIEW DATE.
	- EACH INDIVIDUAL'S DURATION IN ANY SPELL UP TO EACH INTERVIEW DATE.
	- EACH INDIVIDUAL'S START AND END DATE OF SPELL THAT IS CURRENT AT EACH INTERVIEW DATE.
	- EACH INDIVIDAL'S COUNT OF SPELLS OF EACH TYPE (STATUS) UP TO INTERVIEW DATE (INCLUDING SPELL CURRENT AT INTERVIEW).
	- EACH INDIVIDUAL'S COUNT OF TRANSITIONS OF EACH TYPE UP TO INTERVIEW DATE (INCLUDING TRANSITION LEADING TO CURRENT STATUS).
	- EACH INDIVIDUAL'S INTERVIEW DATE EACH WAVE, FIRST AND LATEST INTERVIEW DATES, FIRST AND LATEST WAVES IN WHICH THEY WERE INTERVIEWED.
	
********************************************************************************
*/

global start_time_atint "$S_TIME"

* Prepare data
prog_reopenfile "${output_fld}/Dynamics_Merged Dataset"
keep pidp LFS $spell $start $end DurAtStart_* Dur_Spell Count*
qui su ${spell}
global maxspells=r(max)													// (MAX) NUMBER OF SPELLS IN THE DATASET.
//by pidp (${spell}), sort: replace Spell=_n							// COMMENT: NOT REQUIRED: SPELL NUMBER IS ALREADY CONSECUTIVE.
by pidp ($spell), sort: egen maxspellpidp=max(${spell})				// LAST SPELL FOR EACH pidp.
reshape wide DurAtStart_* Dur_Spell Count* ${start} ${end} LFS maxspellpidp, i(pidp) j(${spell})			// REORGANISE DATA INTO WIDE FORM, ORGANISHED BY pidp. NOTE: DurAtStart_${status}1 IS 0 EVERYWHERE BECAUSE THERE IS 0 DURATION AT THE START OF THE FIRST SPELL. NOTE: lastspellpidp IS IDENTICAL FOR ALL SPELLS.
gen lastspellpidp=maxspellpidp1											// ONLY NEED ONE COPY OF THE LAST SPELL NUMBER FOR EACH PIDP.
drop maxspellpidp*
tempfile Temp
preserve
	prog_reopenfile "${input_fld}/Interview Grid.dta"					// MERGE BY pidp WITH INTERVIEW DATES FOR ALL WAVES. NOTE: THIS ASSUMES THAT INTERVIEW DATE IN "${input_fld}/Interview Grid.dta" IS NAMED IntDate_MY, AS IT WILL BE IF UNALTERED "Launch Programmes.do" IS USED.
	keep pidp Wave IntDate_MY ivfio
	qui su Wave
	global maxWave=r(max)
	gen XX=IntDate_MY
	by pidp (Wave), sort: egen First_IntDate_MY=min(XX)					// THESE 2 LINES CREATE FIRST AND LAST INTERVIEW DATES FOR EACH INDIVIDUAL. NOTE: NOT RESTRICTED TO ivfio!=2 (INCLUDES PROXY INTERVIEWS).
	by pidp (Wave), sort: egen Last_IntDate_MY=max(XX)
	gen YY=Wave if IntDate_MY==First_IntDate_MY & !missing(First_IntDate_MY)	// THESE 2 LINES CREATE WAVE AT WHICH FIRST INTERVIEW OCCURRED.
	by pidp (Wave), sort: egen First_IntWave=min(YY)
	gen ZZ=Wave if IntDate_MY==Last_IntDate_MY & !missing(Last_IntDate_MY)		// THESE 2 LINES CREATE WAVE AT WHICH LAST INTERVIEW OCCURRED.
	by pidp (Wave), sort: egen Last_IntWave=max(ZZ)
	keep pidp Wave IntDate_MY First_IntDate_MY Last_IntDate_MY First_IntWave Last_IntWave
	reshape wide IntDate_MY, i(pidp) j(Wave)
	forvalues i=1/$maxWave{												// THIS LOOP REPLACES MISSING VALUES OF INTDATE WITH .m IF BETWEEN THE INDIVIDUAL'S FIRST AND LAST INTERVIEW DATES.
		replace IntDate_MY`i'=.m if missing(IntDate_MY`i') & inrange(`i',First_IntWave,Last_IntWave)
		}
	save "`Temp'", replace
restore
merge 1:1 pidp using "`Temp'", keep(match master) nogen
//merge 1:1 pidp using temp1
order pidp  	
format *MY %tm
format *_MY* %10.0f
save "${output_fld}/PrepByIntDate.dta", replace


* Duration in particular status at interview date
prog_reopenfile "${output_fld}/PrepByIntDate.dta"
forvalues j=1/$maxWave{  
	foreach k in $statenames{
		qui gen Dur_`k'_AtInt`j'=.i
		}
	}
local i=0  																// LOOP OVER SPELLS, CALCULATING DURATIONS IN EACH STATE, FOR INTERVIEWS BETWEEN SPELL START AND END DATES, AS DURATION AT SPELL START IF SPELL STATUS IS NOT THE STATUS IN QUESTION, OR DURATION AT SPELL START PLUS DURATION BETWEEN SPELL START AND INTERVIEW DATE IF SPELL STATUS IS THE STATUS IN QUESTION OR SPELL IS THE LAST RECORDED SPELL FOR THAT INDIVIDUAL (NOTING THAT LAST SPELLS WERE CONSTRUCTED FOR ALL INDIVIDUALS AND CAN INVOLVE MISSING STATUS AND NO END DATE).
while `i'<=$maxspells-1{
	local i=`i'+1
	noisily display in text "Calculating values at interview dates based on spell `i'/$maxspells data"
	forvalues j=1/$maxWave{  
		foreach k in $statenames{
			qui replace Dur_`k'_AtInt`j'=DurAtStart_`k'`i' if inrange(${intdate}`j',${start}`i',${end}`i'-1) & !missing(${start}`i',${end}`i',${intdate}`j') & LFS`i'!="`k'"
			qui replace Dur_`k'_AtInt`j'=DurAtStart_`k'`i'+${intdate}`j'-${start}`i' if inrange(${intdate}`j',${start}`i',${end}`i'-1) & !missing(${start}`i',${end}`i',${intdate}`j') & LFS`i'=="`k'"
			qui replace Dur_`k'_AtInt`j'=DurAtStart_`k'`i'+${intdate}`j'-${start}`i' if ${intdate}`j'>${start}`i' & lastspellpidp==`i' & !missing(${start}`i',${intdate}`j') & LFS`i'=="`k'"
			}
		}
	}
ssc uninstall tolong													// UNINSTALL USER-WRITTEN STATA PACKAGE tolong. PROGRAM IS SOMETIMES NOT FOUND UNLESS RECENTLY INSTALLED.
ssc install tolong														// INSTALL tolong FASTER RESHAPE LONG PACKAGE FROM SSC.
local allstates $statenames
local firststate $state1_name
local otherstates : list allstates- firststate
preserve
	keep pidp ${intdate}* First_IntDate_MY Last_IntDate_MY First_IntWave Last_IntWave
	tolong ${intdate}#, i(pidp) j(Wave)									// RESHAPE MONTHLY DATA FOR INTERVIEW DATE FROM WIDE FORMAT INTO LONG FORMAT.
	tempfile Temp
	save "`Temp'", replace
restore
foreach k in $statenames{
	preserve
		di in red "Calculating duration at interview for status `k'"
		keep pidp Dur_`k'_AtInt*
		tolong Dur_`k'_AtInt#, i(pidp) j(Wave)							// RESHAPE THE MONTHLY DURATION IN EACH STATUS AT INTERVIEW DATE DATA FROM WIDE FORMAT INTO LONG FORMAT.
		merge 1:1 pidp Wave using "`Temp'", keep(match) nogen			// MERGE INFORMATION FOR EACH STATUS.
		save "`Temp'", replace
	restore
	}
prog_reopenfile "`Temp'"
foreach k in $statenames{
	by pidp (Wave), sort: replace Dur_`k'_AtInt=Dur_`k'_AtInt[_n-1] if missing(Dur_`k'_AtInt) & !missing(Dur_`k'_AtInt[_n-1]) & !missing($intdate) & Wave<=Last_IntWave
	replace Dur_`k'_AtInt=.m if missing(Dur_`k'_AtInt) & missing($intdate) & inrange(Wave,First_IntWave,Last_IntWave) 
	replace Dur_`k'_AtInt=0 if Dur_`k'_AtInt==.i & !missing($intdate) 
	capture label variable Dur_`k'_AtInt "Duration in status `k' at interview date"	
	}
capture label variable Wave "Wave (= 18 + Wave for UKHLS)"
capture label variable $intdate "Interview date in month years"
capture label variable First_IntDate_MY "First interview date, by pidp"
capture label variable Last_IntDate_MY "Last interview date, by pidp"
capture label variable First_IntWave "First interview Wave, by pidp"
capture label variable Last_IntWave "Last interview Wave, by pidp"
compress
xtset pidp Wave
save "${output_fld}/Dynamics_Dur_byStatus_AtInt.dta",replace
/*
Some individuals do not have information for some Waves because no interview was conducted. Work-life histories can nevertheless be constructed over those Waves using information given at later Waves. Because interview date is not available for non-interview waves, information about status, durations and counts at interview date cannot be constructed. Information about status, duration and counts at later waves is still valid in relation to constructed work-life histories. Information about interview-date status, duration and counts where no interview took place is recorded as .i (inapplicable).
*/


* Duration of current spell at interview date
prog_reopenfile "${output_fld}/PrepByIntDate.dta"
forvalues j=1/$maxWave{
	gen Dur_Spell_AtInt`j'=.i
	}
local i=0  																// LOOP OVER SPELLS, CALCULATING DURATION IN CURRENT SPELL, FOR INTERVIEWS BETWEEN SPELL START AND END DATES, 
while `i'<=$maxspells-1{
	local i=`i'+1
	noisily display in text "Calculating spell duration at interview dates based on spell `i'/$maxspells data"
	forvalues j=1/$maxWave{  
		qui replace Dur_Spell_AtInt`j'=datediff(dofm(${start}`i'), dofm(${intdate}`j'), "month") if missing(Dur_Spell_AtInt`j') & inrange(${intdate}`j',${start}`i',${end}`i'-1) & !missing(${intdate}`j',${start}`i',${end}`i')
		qui replace Dur_Spell_AtInt`j'=datediff(dofm(${start}`i'), dofm(${intdate}`j'), "month") if missing(Dur_Spell_AtInt`j') & ${intdate}`j'>${start}`i' & lastspellpidp==`i' & !missing(${start}`i',${intdate}`j')
		}
	}
keep pidp $intdate* Dur_Spell_AtInt* First_IntWave Last_IntWave
ssc uninstall tolong													// UNINSTALL USER-WRITTEN STATA PACKAGE tolong. PROGRAM IS SOMETIMES NOT FOUND UNLESS RECENTLY INSTALLED.
ssc install tolong														// INSTALL tolong FASTER RESHAPE LONG PACKAGE FROM SSC.
tolong $intdate# Dur_Spell_AtInt#, i(pidp) j(Wave)	
replace Dur_Spell_AtInt=.m if missing(Dur_Spell_AtInt) & missing($intdate) & inrange(Wave,First_IntWave,Last_IntWave) 
drop First_IntWave Last_IntWave
capture label variable Wave "Wave (= 18 + Wave for UKHLS)"
capture label variable $intdate "Interview date in month years"
capture label variable Dur_Spell_AtInt "Duration of current spell at interview date"	
xtset pidp Wave
save "${output_fld}/Dynamics_Dur_Spell_AtInt.dta",replace
		
	
* Spell start and end dates of current spell at interview date
prog_reopenfile "${output_fld}/PrepByIntDate.dta"
forvalues j=1/$maxWave{
	gen Start_Spell_AtInt`j'=.i
	gen End_Spell_AtInt`j'=.i
	}
local i=0  																// LOOP OVER SPELLS, CALCULATING DURATION IN CURRENT SPELL, FOR INTERVIEWS BETWEEN SPELL START AND END DATES, 
while `i'<=$maxspells-1{
	local i=`i'+1
	noisily display in text "Calculating spell start and end dates relating to spell current at interview date, based on spell `i'/$maxspells data"
	forvalues j=1/$maxWave{  
		qui replace Start_Spell_AtInt`j'=${start}`i' if missing(Start_Spell_AtInt`j') & inrange(${intdate}`j',${start}`i',${end}`i'-1) & !missing(${intdate}`j',${start}`i',${end}`i')
		qui replace Start_Spell_AtInt`j'=${start}`i' if missing(Start_Spell_AtInt`j') & ${intdate}`j'>${start}`i' & lastspellpidp==`i' & !missing(${start}`i',${intdate}`j')
		qui replace End_Spell_AtInt`j'=${end}`i' if missing(End_Spell_AtInt`j') & inrange(${intdate}`j',${start}`i',${end}`i'-1) & !missing(${intdate}`j',${start}`i',${end}`i')
		qui replace End_Spell_AtInt`j'=${intdate}`j' if missing(End_Spell_AtInt`j') & ${intdate}`j'>${start}`i' & lastspellpidp==`i' & !missing(${start}`i',${intdate}`j')
		}
	}
keep pidp $intdate* Start_Spell_AtInt* End_Spell_AtInt* First_IntWave Last_IntWave
ssc uninstall tolong													// UNINSTALL USER-WRITTEN STATA PACKAGE tolong. PROGRAM IS SOMETIMES NOT FOUND UNLESS RECENTLY INSTALLED.
ssc install tolong														// INSTALL tolong FASTER RESHAPE LONG PACKAGE FROM SSC.
tolong $intdate# Start_Spell_AtInt# End_Spell_AtInt#, i(pidp) j(Wave)	
replace Start_Spell_AtInt=.m if missing(Start_Spell_AtInt) & missing($intdate) & inrange(Wave,First_IntWave,Last_IntWave) 
replace End_Spell_AtInt=.m if missing(End_Spell_AtInt) & missing($intdate) & inrange(Wave,First_IntWave,Last_IntWave) 
drop First_IntWave Last_IntWave
capture label variable Wave "Wave (= 18 + Wave for UKHLS)"
capture label variable $intdate "Interview date in month years"
capture label variable Start_Spell_AtInt "Start date of current spell at interview date (should be same or before interview date)"
capture label variable End_Spell_AtInt "End date of current spell at interview date (should be same or later than interview date)"	
xtset pidp Wave
save "${output_fld}/Dynamics_StartEnd_Spell_AtInt.dta",replace
	
	
* Count of number of spells in each state to date, at each interview date
prog_reopenfile "${output_fld}/PrepByIntDate.dta"
forvalues j=1/$maxWave{
	foreach k in $statenames {
		gen CountSpell_`k'_AtInt`j'=.i
		}
	}
local i=0  																// LOOP OVER SPELLS, CALCULATING COUNTS OF SPELLS IN EACH STATE UP TO INTERVIEW DATE, FOR INTERVIEWS BETWEEN SPELL START AND END DATES
while `i'<=$maxspells-1{
	local i=`i'+1
	noisily display in text "Calculating counts to date of life history spells in each state at interview date, based on spell `i'/$maxspells data"
	forvalues j=1/$maxWave{  
		foreach k in $statenames {
			qui replace CountSpell_`k'_AtInt`j'=CountSpell_`k'`i' if missing(CountSpell_`k'_AtInt`j') & inrange(${intdate}`j',${start}`i',${end}`i'-1) & !missing(CountSpell_`k'`i',${intdate}`j',${start}`i',${end}`i')
			qui replace CountSpell_`k'_AtInt`j'=CountSpell_`k'`i' if missing(CountSpell_`k'_AtInt`j') & ${intdate}`j'>${start}`i' & lastspellpidp==`i' & !missing(CountSpell_`k'`i',${intdate}`j',${start}`i')
			}
		}
	}
keep pidp $intdate* CountSpell_?_AtInt* First_IntWave Last_IntWave
ssc uninstall tolong													// UNINSTALL USER-WRITTEN STATA PACKAGE tolong. PROGRAM IS SOMETIMES NOT FOUND UNLESS RECENTLY INSTALLED.
ssc install tolong														// INSTALL tolong FASTER RESHAPE LONG PACKAGE FROM SSC.
preserve
	keep pidp $intdate* First_IntWave Last_IntWave
	tolong ${intdate}#, i(pidp) j(Wave)									// RESHAPE MONTHLY DATA FOR INTERVIEW DATE FROM WIDE FORMAT INTO LONG FORMAT.
	tempfile Temp
	save "`Temp'", replace
restore
foreach k in $statenames{
	preserve
		keep pidp CountSpell_`k'_AtInt*
		di in red "Calculating counts to date of spells of status `k' up to interview date"
		tolong CountSpell_`k'_AtInt#, i(pidp) j(Wave)					// RESHAPE THE MONTHLY DURATION IN EACH STATUS AT INTERVIEW DATE DATA FROM WIDE FORMAT INTO LONG FORMAT.
		merge 1:1 pidp Wave using "`Temp'", keep(match) nogen			// MERGE INFORMATION FOR EACH STATUS.
		save "`Temp'", replace
	restore
	}
prog_reopenfile "`Temp'"
foreach k in $statenames {
	replace CountSpell_`k'_AtInt=.m if missing(CountSpell_`k'_AtInt) & missing($intdate) & inrange(Wave,First_IntWave,Last_IntWave)	// COUNT AT INTERVIEW DATE OF SPELLS, INCLUDING CURRENT SPELL.
	capture label variable CountSpell_`k'_AtInt "Count of spells of `k' up to interview date, including current spell"
	}
drop $intdate First_IntWave Last_IntWave
capture label variable Wave "Wave (= 18 + Wave for UKHLS)"
capture label variable $intdate "Interview date in month years"
xtset pidp Wave
save "${output_fld}/Dynamics_CountSpell_byStatus_AtInt.dta",replace	

	
* Count of number of transitions of each type to date, at each interview date
prog_reopenfile "${output_fld}/PrepByIntDate.dta"
forvalues j=1/$maxWave{
	foreach t in $LFS2levels {											// $LFS2levels IS levelsof(LFS2).
		qui gen CountTransition_`t'_AtInt`j'=.i
		}
	}
local i=0  																// LOOP OVER SPELLS, CALCULATING COUNTS OF SPELLS IN EACH STATE UP TO INTERVIEW DATE, FOR INTERVIEWS BETWEEN SPELL START AND END DATES
while `i'<=$maxspells-1{
	local i=`i'+1
	noisily display in text "Calculating counts to date of work-life history transitions of each type up to interview date, based on spell `i'/$maxspells data"
	forvalues j=1/$maxWave{  
		foreach t in $LFS2levels {
			qui replace CountTransition_`t'_AtInt`j'=CountTransition_`t'`i' if missing(CountTransition_`t'_AtInt`j') & inrange(${intdate}`j',${start}`i',${end}`i'-1) & !missing(CountTransition_`t'`i',${intdate}`j',${start}`i',${end}`i')			// COUNT AT INTERVIEW DATE OF TRANSITIONS (INCLUDING TRANSITION INTO CURRENT STATUS).
			qui replace CountTransition_`t'_AtInt`j'=CountTransition_`t'`i' if missing(CountTransition_`t'_AtInt`j') & ${intdate}`j'>${start}`i' & lastspellpidp==`i' & !missing(CountTransition_`t'`i',${intdate}`j',${start}`i')
			}
		}
	}
keep pidp $intdate* CountTransition_??_AtInt* First_IntWave Last_IntWave
ssc uninstall tolong													// UNINSTALL USER-WRITTEN STATA PACKAGE tolong. PROGRAM IS SOMETIMES NOT FOUND UNLESS RECENTLY INSTALLED.
ssc install tolong														// INSTALL tolong FASTER RESHAPE LONG PACKAGE FROM SSC.
preserve
	keep pidp $intdate* First_IntWave Last_IntWave
	tolong ${intdate}#, i(pidp) j(Wave)									// RESHAPE MONTHLY DATA FOR INTERVIEW DATE FROM WIDE FORMAT INTO LONG FORMAT.
	tempfile Temp
	save "`Temp'", replace
restore
foreach t in $LFS2levels{
	preserve
		keep pidp CountTransition_`t'_AtInt*
		di in red "Calculating counts to date of transitions `t' up to interview date"
		tolong CountTransition_`t'_AtInt#, i(pidp) j(Wave)					// RESHAPE THE MONTHLY DURATION IN EACH STATUS AT INTERVIEW DATE DATA FROM WIDE FORMAT INTO LONG FORMAT.
		merge 1:1 pidp Wave using "`Temp'", keep(match) nogen			// MERGE INFORMATION FOR EACH STATUS.
		save "`Temp'", replace
	restore
	}
prog_reopenfile "`Temp'"
foreach t in $LFS2levels {
	replace CountTransition_`t'_AtInt=.m if missing(CountTransition_`t'_AtInt) & missing($intdate) & inrange(Wave,First_IntWave,Last_IntWave)	// COUNT AT INTERVIEW DATE OF SPELLS, INCLUDING CURRENT SPELL.
	capture label variable CountTransition_`t'_AtInt "Count of transitions of `t' up to interview date, including transition leading to current spell"
	}
drop $intdate First_IntWave Last_IntWave
capture label variable Wave "Wave (= 18 + Wave for UKHLS)"
capture label variable $intdate "Interview date in month years"
xtset pidp Wave
save "${output_fld}/Dynamics_CountTransition_byTransition_AtInt.dta",replace	


* Merge "by interview date" variables
prog_reopenfile "${output_fld}/Dynamics_Dur_byStatus_AtInt.dta"
merge 1:1 pidp Wave using "${output_fld}/Dynamics_Dur_Spell_AtInt.dta", nogen
merge 1:1 pidp Wave using "${output_fld}/Dynamics_StartEnd_Spell_AtInt.dta", nogen
merge 1:1 pidp Wave using "${output_fld}/Dynamics_CountSpell_byStatus_AtInt.dta", nogen
merge 1:1 pidp Wave using "${output_fld}/Dynamics_CountTransition_byTransition_AtInt.dta", nogen
order pidp Wave ${intdate}
order First_IntWave Last_IntWave First_IntDate Last_IntDate, last
save "${output_fld}/Dynamics_All_AtInt.dta",replace


di in red "Dynamic data at interview date Data creation Started: $start_time_atint"
di in red "Dynamic data at interview date Completed: $S_TIME"	


rm "${output_fld}/PrepByIntDate.dta"
rm "${output_fld}/Dynamics_Dur_byStatus_AtInt.dta"
rm "${output_fld}/Dynamics_Dur_Spell_AtInt.dta"
rm "${output_fld}/Dynamics_StartEnd_Spell_AtInt.dta"
rm "${output_fld}/Dynamics_CountSpell_byStatus_AtInt.dta"
rm "${output_fld}/Dynamics_CountTransition_byTransition_AtInt.dta"
