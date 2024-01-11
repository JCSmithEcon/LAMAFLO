/*
********************************************************************************
UKHLS INITIAL SPELL.DO
	
	THIS FILE CREATES A DATASET OF JOB START DATES FROM FIRST UKHLS INTERVIEW.

	UPDATES:
	* CODE ALTERED TO INCLUDE FURLOUGH STATUSES AND END REASON VARIABLES.
	* STATUSES 12 AND 13 ARE RETAINED HERE AND ADJUSTED AFTER THIS DATASET IS MERGED IN "UKHLS Annual History_JCS.do".
	* jbstat AMD jbsemp ARE NOT DROPPED SO THAT THEY CAN BE USED AFTER THAT MERGE TO CONVERT FURLOUGH STATUS INTO UNDERLYING EMPLOYMENT STATUS.
	
	* LW VERSION USES THE SAME CODE.
		
********************************************************************************
*/

/*
1. Dataset Preparation.
	A. Collate raw data.
*/
forval i=1/$ukhls_waves{
	local j: word `i' of `c(alpha)'
	use pidp `j'_jb* `j'_ivfio using /*
		*/ "${fld}/${ukhls_path}_w`i'/`j'_indresp${file_type}" /*
		*/ if (`j'_jbhas==1 | `j'_jboff==1) & `j'_ivfio==1, clear
	gen Wave=`i'+18
	gen Source="`j'_indresp"
	rename `j'_* *
	tempfile Temp`i'
	save "`Temp`i''", replace
	}
forval i=1/`=$ukhls_waves-1'{
	append using "`Temp`i''"
	}
keep pidp Wave Source jbstat jbsemp jbbgm jbbgy jbft_dv
merge 1:1 pidp Wave using "${dta_fld}/Interview Grid", /*
	*/ nogen keep(match) keepusing(IntDate_MY Birth_MY Next_*)
drop if missing(IntDate_MY) | missing(Birth_MY)
drop if jbbgm==-8														// DROP CASES WHERE JOB START DATE INAPPLICABLE.
by pidp (Wave), sort: keep if _n==1


/*
2. Dataset Cleaning.
	A. Create Start and End Dates and Flags.
*/
gen Start_M=jbbgm /*													// Start_M, Start_Y, Start_MY FOR CASES WITH NON-MISSING JOB START INFO.
	*/ if jbbgm>0 & jbbgy>0 & !missing(jbbgm, jbbgy)
gen Start_Y=jbbgy if jbbgy>0 & !missing(jbbgy)
drop jbbg*

gen Start_MY=ym(Start_Y,Start_M)
gen Start_Flag=0

gen XX=1 if missing(Start_MY) & Start_Y<year(dofm(IntDate_MY))			// IMPUTE START MONTH AS DECEMBER OF Start_Y IF YEAR BUT NOT MONTH OBSERVED, START YEAR BEFORE INTERVIEW YEAR (START FLAG 4).
replace Start_MY=ym(Start_Y,12) if XX==1
replace Start_Flag=4 if XX==1
drop XX
	
gen XX=1 if missing(Start_MY) & Start_Y==year(dofm(IntDate_MY)) /*
	*/ & month(dofm(IntDate_MY))>1										// IMPUTE START MONTH AS MONTH BEFORE INTERVIEW IF YEAR BUT NOT MONTH OBSERVED, START YEAR = INTERVIEW YEAR (START FLAG 4).
replace Start_MY=IntDate_MY-1 if XX==1
replace Start_Flag=4 if XX==1
drop XX

gen XX=1 if missing(Start_M) & missing(Start_Y)							// IMPUTE START MONTH AND YEAR AS MONTH BEFORE INTERVIEW (START FLAG 5).
replace Start_MY=IntDate_MY-1 if XX==1
replace Start_Flag=5 if XX==1
drop XX

gen End_MY=IntDate_MY													// JOB SPELL CANNOT END AFTER INTERVIEW DATE (END FLAG 1).
gen End_Flag=1


//	DROP IMPLAUSIBLE DATES
qui prog_makeage Start_MY												// CALCULATE AGE AT Start_MY.
drop if Start_MY_Age<=$noneducstatus_minage | Start_MY>=End_MY			// DROP IF AGE AT JOB START <= $noneducstatus_minage (SET IN "Launch Programme JCS.do", WITH A DEFAULT OF 0, OR JOB STARTS AFTER INTERVIEW DATE.	// ORIGINAL CODE: drop if Start_MY_Age<=10 | Start_MY>=End_MY							// DROP IF AGE AT JOB START <=10 OR JOB STARTS AFTER INTERVIEW DATE.
drop Start_? *Age Birth_MY												// ? DIFFERS FROM * IN REQUIRING THERE TO BE A CHARACTER IN THAT POSITION. E.G. drop temp? would drop temp1 and temp2 but not temp, whereas drop temp* would drop all these.


// CREATE JOB CHARACTERISTICS
gen Status=Next_ff_jbstat if inlist(Next_ff_jbstat,1,2,12,13)			// ADD "On furlough" AND "Temporarily laid off/short time working".	// ORIGINAL CODE: gen Status=Next_ff_jbstat if inlist(Next_ff_jbstat,1,2)
replace Status=3-Next_ff_jbsemp /*
	*/ if inlist(Next_ff_jbsemp,1,2) & missing(Status) & missing(Next_ff_jbstat)
replace Status=jbstat /*
	*/ if inlist(jbstat,1,2,12,13) & missing(Status)					// ADD "On furlough" AND "Temporarily laid off/short time working".	// ORIGINAL CODE: replace Status=jbstat /* */ if inlist(jbstat,1,2) & missing(Status)
replace Status=3-jbsemp /*
	*/ if inlist(jbsemp,1,2) & missing(Status) & jbstat<0
drop if missing(Status)

gen Source_Variable="ff_jbstat_w"+strofreal(Next_Wave) /*
	*/ if inlist(Next_ff_jbstat,1,2,12,13)								// ADD "On furlough" AND "Temporarily laid off/short time working".	// ORIGINAL CODE: gen Source_Variable="ff_jbstat_w"+strofreal(Next_Wave) /* */ if inlist(Next_ff_jbstat,1,2)
replace Source_Variable="ff_jbsemp"+strofreal(Next_Wave) /*
	*/ if inlist(Next_ff_jbsemp,1,2) & missing(Source_Variable) & missing(Next_ff_jbstat)
replace Source_Variable="jbstat"+strofreal(Wave) /*
	*/ if inlist(jbstat,1,2,12,13) & missing(Source_Variable)			// ADD "On furlough" AND "Temporarily laid off/short time working".	// ORIGINAL CODE: replace Source_Variable="jbstat"+strofreal(Wave) /* */ if inlist(jbstat,1,2) & missing(Source_Variable)
replace Source_Variable="jbsemp"+strofreal(Wave) /*
	*/ if inlist(jbsemp,1,2) & missing(Source_Variable) & jbstat<0
gen Spell=0
gen Status_Spells=1
gen End_Ind=0

gen Job_Hours=cond(inlist(jbft_dv,1,2),jbft_dv,.m)
gen Job_Change=.m
foreach i of numlist 1/15 97{
	if !inrange(`i',13,15){												// End_Reason12 INTRODUCED VIA STENDREAS12 IN WAVE 12 "Furloughed"	// ORIGINAL CODE: if !inrange(`i',12,15){
		gen End_Reason`i'=.m											// SET End_Reason TO .m FOR INITIAL JOB.
		}
	gen Job_Attraction`i'=.m											// SET Job_Attraction TO .m FOR INITIAL JOB.
	}

drop jbft_dv Next*														// ALTERED CODE TO RETAIN jbstat AND jbsemp, TO CREATE Status VARIABLES FOR UNSUFFIXED AND _F VARIANTS OF UKHLS Annual History.
format *MY %tm
order pidp Wave Status Job* Start_MY End_MY *Flag
sort pidp Wave

save "${dta_fld}/UKHLS Initial Job", replace
