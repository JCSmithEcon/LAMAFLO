/*
********************************************************************************
CLEAN LIFE HISTORY.DO
	
	THIS FILE CREATES LIFETIME EMPLOYMENT STATUS HISTORIES USING UKHLS OR BHPS
	CLEANED FILES.
	
	UPDATE: 
	* FOR BHPS DATA, OPTION TO CHOOSE CASE-BY-CASE CORRECTION OF NON-CHRONOLOGICAL START DATES. IF CHOSEN, THIS USES THE NEW FILE prog_nonchron_BHPS.do.

********************************************************************************
*/
compress

*0. Generate dates for first leaving full time education 	
merge m:1 pidp using "${dta_fld}/Left Full Time Education", /*
	*/ keep(match) keepusing(FTE*MY) nogen
gen LeftFTE_MY=FTE_FIN_MY
gen LeftFTE_Y=.
gen LeftFTE_SY=.
prog_mytosytoy LeftFTE

gen XX=(Spell==1 & Status==7 & missing(LeftFTE_MY) & missing(Start_Y))
foreach i in Y MY SY{
	replace Start_`i'=Birth_`i' if XX==1
		}
drop XX

expand 2 /*
	*/ if Spell==1 & missing(Start_Y) /*
	*/  & missing(LeftFTE_MY) & !missing(FTE_IN_MY), gen(XX)
replace Spell=0 if XX==1
replace Status=.m if XX==1
replace Job_Hours=.i if XX==1
replace End_Ind=1 if XX==1
replace Start_MY=FTE_IN_MY if XX==1
prog_mytosytoy Start
expand 2 if XX==1, gen(YY)
replace Spell=-1 if YY==1
replace Status=7 if YY==1
foreach i in Y MY SY{
	replace Start_`i'=Birth_`i' if YY==1
	}
by pidp Wave (Spell), sort: replace Spell=_n
drop XX YY FTE*


qui su Wave
*1. Deal with non-chronological dates. Either:
if "$nonchron_correct"=="Y" & r(min)<18 {
	* (a) Deal with participants with non-chronological dates by retaining data where possible through plausible corrections to dates
	di in red "BHPS Life History: You have chosen to deal with non-chronological dates by retaining data where possible through plausible date corrections (nonchron_correct=Y)"
//	prog_nonchron_lifemst Start Y SY MY	
	do "${do_fld}/prog_nonchron_BHPS"
	by pidp Wave (Spell), sort: replace End_Ind=cond(_n==_N,End_Type,1)	
	drop NonChron_Wave*
	}
*	Or:
else if "$nonchron_correct"!="Y" | r(min)>18 {
	* (b) Drop participants with non-chronological dates
	if r(min)<18 {
		di in red "BHPS Life History: You have chosen to deal with non-chronological dates by deleting all data for that pidp in the affected Wave (nonchron_correct!=Y)"
		}
	prog_nonchron Start Y SY MY	
	by pidp Wave (Start_Y Start_SY Start_MY), sort: replace Spell=_n if NonChron_Wave==1
	by pidp Wave (Spell), sort: replace End_Ind=cond(_n==_N,End_Type,1)	
	drop NonChron_Wave*
	}	
	
*2. Drop observations starting after interview dates
	* Drop participant with implausible values
prog_afterint Start
prog_implausibledates Start
	
*3. Impute start month from season if preceded or followed by missing season.
	* Set equal to middle of month, unless MaxBelow is from same season. In which case,
		* set month equal to end of season.
prog_monthfromseason
drop Start_SY


*4. Impute Start Dates for First Spell where missing.
	*NOT SURE IF THIS IS GOOD. 
	*ALTERNATIVELY, DROP ALL SPELLS BEFORE LEFT_FTE AND TRUNCATE FIRST ONE THERE.
prog_daterange Y
gen XX=1 if Spell==1 & missing(Start_Y) & LeftFTE_Y<MinAbove
foreach i in Y MY{
	replace Start_`i'=LeftFTE_`i' if XX==1
	}
drop XX LeftFTE*

	
*5. Create Index Spell for FTE
expand 2 if Spell==1, gen(XX)
replace Spell=0 if XX==1
replace Status=7 if XX==1
replace Job_Hours=.i if XX==1
replace Start_Y=.m if XX==1
replace Start_MY=Birth_MY if XX==1
replace Start_Flag=0 if XX==1
replace End_Ind=1 if XX==1
prog_mytosytoy Start

by pidp Wave (Spell), sort: /*
	*/ drop if Spell==0 & Start_MY==Start_MY[_n+1] & !missing(Start_MY)
by pidp Wave (Spell), sort: replace Spell=_n
drop *SY XX MaxBelow MinAbove* Birth*


*6. Clean Work History and Append FTE
prog_attrend
do "${do_fld}/Clean Work History_JCS.do"
append using "$notleft_fte"

prog_waveoverlap
prog_collapsespells
prog_format
