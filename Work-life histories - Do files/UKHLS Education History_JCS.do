/*
********************************************************************************
UKHLS EDUCATION HISTORY.DO
	
	THIS FILE CREATES HISTORIES OF FULL-TIME EDUCATION USING THE ANNUAL HISTORY
	MODULE FROM UNDERSTANDING SOCIETY.

	UPDATES:
	* DATA NOT DROPPED WHERE Start_MY>End_MY OR Start_MY==End_MY.
	* SMALL APPARENT CODING ERROR CORRECTED.
	COMMENT: 
	* prog_cleaneduhist IS USED WHEN EITHER WORK OR EDUCATION HISTORIES ARE PRIORITISED; IT CALLS THE REVISED prog_implausibledates THAT REACTS TO CHOICE OF $noneducstatus_minage BUT, AS IN THE ORIGINAL LW CODE, DROPS EDUCATION SPELLS STARTING BEFORE BIRTH.
	
	"$work_educ"=="educ" OPTION:
	* DROPS DATA WHERE Start_MY>End_MY OR Start_MY==End_MY.
	
	* LW VERSION USES "$work_educ"=="educ" OPTION.

********************************************************************************
*/

if "$work_educ"=="work" | "$work_educ"=="WORK" {						// THIS CODE IN {} IS USED IF WORK HISTORIES ARE PRIORITISED. LW CODE IS USED BELOW IF EDUCATION HISTORIES ARE PRIORITISED.

	/*
	2. Dataset Preparation.
		* Annual Education History Modules asked from Wave 2 onwards.
	*/
	forval i=2/$ukhls_waves{	
		local j: word `i' of `c(alpha)'
		use pidp `j'_contft `j'_ftend* `j'_fted* `j'_ft2* /*
			*/ using "${fld}/${ukhls_path}_w`i'/`j'_indresp${file_type}", clear
		merge 1:1 pidp using "${fld}/${ukhls_path}_w`i'/`j'_indall${file_type}", /*
			*/ keepusing(`j'_ff_everint `j'_ff_ivlolw `j'_ivfio) /*
			*/ keep(match) nogenerate
		prog_recodemissing *
		compress
		rename `j'_* *
		gen Wave=`i'+18
		keep if ivfio==1 & (ff_ivlolw==1 | ff_everint==1)
		tempfile Temp`i'
		save "`Temp`i''", replace		
		}
	forval i=`=$ukhls_waves-1'(-1)2{
		append using "`Temp`i''"
		}
	save "${dta_fld}/UKHLS Education History - Raw", replace

	/*
	3. Format and clean annual education history dataset
		* GETS START AND END DATES FOR EACH EDUCATION SPELL.
	*/
	*i. Open dataset
	prog_reopenfile "${dta_fld}/UKHLS Education History - Raw"		// PROG_REOPENFILE OPENS UP A DATASET IF IT ISN'T ALREADY IN MEMORY UNCHANGED.
	prog_labels														// CREATES LABELS.
	order *, alphabetic
	order pidp Wave ff_*

	*ii. Index Spell
	gen Has_Activity0=1 if contft!=.i
	// contft_w: From https://www.understandingsociety.ac.uk/documentation/mainstage/dataset-documentation/variable/contft: Continuous FT education. Text: Last time we interviewed you, you were in full-time education. Have you been in continuous full-time education since ff_IntDate? Being on holiday from school or between school and University counts as being in full-time education even if you had a job at that time. Universe: if ff_ivlolw = 1 | ff_everint = 1 (interviewed at prior wave or has been interviewed previously) and if ff_JBSTAT = 7 (Full-time student at last interview).

	gen Source_Variable0="contft_w"+strofreal(Wave) if Has_Activity0==1

	gen End_Ind0=.m if Has_Activity0==1
	replace End_Ind0=0 if contft==1
	replace End_Ind0=1 if contft==2

	gen Start_M0=.i
	gen Start_Y0=.i

	gen End_M0=cond(End_Ind0==1,ftendm,.i)
	gen End_Y0=cond(End_Ind0==1,ftendy4,.i)

	*iii. Spells 1+*
	ds ftedmor*
	local spells: word count `r(varlist)'
	forval i=1/`spells'{
		if `i'==1{
			gen Has_Activity`i'=1 if ftedany==1
			gen Source_Variable`i'="ftedany_w"+strofreal(Wave) if Has_Activity`i'==1
			}
		else if `i'>1{
			local j=`i'-1
			gen Has_Activity`i'=1 if ftedmor`j'==1		
			gen Source_Variable`i'="ftedmor`j'_w"+strofreal(Wave) if Has_Activity`i'==1
			}
		
		gen End_Ind`i'=.m if Has_Activity`i'==1
		replace End_Ind`i'=0 if ftedend`i'==2
		replace End_Ind`i'=1 if ftedend`i'==1
		
		gen Start_M`i'=ftedstartm`i'
		gen Start_Y`i'=ftedstarty4`i'
		
		gen End_M`i'=cond(End_Ind`i'==1,ft2endm`i',.i)
		gen End_Y`i'=cond(End_Ind`i'==1,ft2endy4`i',.i)
		}	
		
	*iv. Reshape into long format
	keep pidp Wave Start* End* Has* Source*
	egen XX=rownonmiss(Has_Activity*)
	drop if XX==0
	drop XX

	reshape long Has_Activity Source_Variable End_Ind /*
		*/ Start_M Start_Y End_M End_Y, /*
		*/ i(pidp Wave) j(Spell)
	keep if Has_Activity==1
	drop Has_Activity

	*v. Merge with Interview Grid and delete observations with missing interview dates
	merge m:1 pidp Wave using "${dta_fld}/Interview Grid", /*
		*/ keepusing(LB_MY IntDate_MY jbstat) keep(match) nogenerate
	drop if missing(IntDate_MY, LB_MY)

	*vi. Replace missing end indicator
		/// Assumes no stops in FTE where end indicator is missing and participant gives FTE as current jbstat
	// COMMENT: THIS MIGHT APPEAR A CONTENTIOUS ASSUMPTION WHEN ONE IS INTERESTED IN LABOUR MARKET HISTORY - IN CASE THIS IS A SECOND, LATER, EPISODE OF FTE. HOWEVER (SEE BELOW), IN THESE DATA THERE IS NO CASE WHERE THERE IS ANY EVIDENCE THAT THERE IS PREVIOUS COMPLETED FT EDUCATION.
	// DATA CHECK: THE FOLLOWING CODE CHECKS THE FULL DATA OF THOSE WITH jbstat==7 & End_Ind==.m:
		/*
		gen XX=(jbstat==7 & End_Ind==.m)
		by pidp Wave (Spell), sort: egen YY=max(XX)
		browse if YY==1
		drop XX YY
		*/
	// DATA CHECK CONCLUSION: THERE IS NO CASE WHERE THERE IS ANY EVIDENCE THAT THERE IS PREVIOUS COMPLETED FT EDUCATION.
	replace End_Ind=0 if jbstat==7 & End_Ind==.m
	drop jbstat

	*vii .Generate month-year variables
		* Continuing activities are given interview date as end date
		* Index // ONGOING AT INTERVIEW DATE // spells are given start date at time of previous interview.
		* Missing end or start years are set equal start or end year where these are the same as the interview or previous interview year
		* Start or end dates outside interview date range set to be coterminuous with these, except:
				* Observations dropped where this leads to negative duration spells.
				* Observations dropped where corresponding end and start dates are missing (without this wouldn't know if the event occured completely before or after period between interviews).
			* Start and end dates set equal where one but not the other is equal
			/// Only using data from events taking place between interviews:
				/// 1. To ensure observations from closest point in time to the event are used.
				/// 2. To stop overlap between observations.
	/*
	. label list flag
			   0 0. No imputation
			   1 1. Truncated: Seam Spell
			   2 2. Imputed: Equal division across status spell
			   3 3. Imputed: Equal division across gap
			   4 4. Truncated: Missing month
			   5 5. Truncated: Missing month and year
			   6 6. Imputed: Month in Season
			   7 7. Imputed: scend missing
			   8 8. Truncated, by BHPS Education History
			   9 9. Truncated, by BHPS Annual History
			  10 11. Truncated, by BHPS Life History
			  11 11. Truncated, by Education History spell
			  12 12. Truncated, Life History
			  13 13. School Date
			  .m .m. Missing/Refused/Don't Know
	*/
	foreach i in Start End{
		gen `i'_MY=ym(`i'_Y,`i'_M)
		replace `i'_MY=.m if missing(`i'_MY)
		}
	prog_missingdate Start End					// prog_missingdate [FOR UKHLS WHERE DATE COMPONENTS ARE YEAR AND MONTH (NOT SEASON)] GENERATES Missing_Start/EndDate 0: YEAR AND MONTH OBSERVED; 2: YEAR AVAILABLE BUT MISSING MONTH; 3: MISSING BOTH DATE COMPONENTS.
	gen Start_Flag=0 if Missing_StartDate==0	// Start/End_Flag "0. NO IMPUTATION" WHERE YEAR AND MONTH OBSERVED
	gen End_Flag=0 if Missing_EndDate==0
	label values Start_Flag End_Flag flag	

	replace Start_MY=LB_MY if Spell==0			// START DATE FOR INDEX (ONGOING) SPELL IS IMPUTED=LOWER BOUND; Start_Flag SET AS "1. Truncated: Seam Spell".
	replace End_MY=IntDate_MY if End_Ind==0		// END DATE IS IMPUTED=INTERVIEW DATE FOR INCOMPLETE (ONGOING) SPELL; End_Flag SET AS "1. Truncated: Seam Spell".
	replace Start_Flag=1 if Spell==0
	replace End_Flag=1 if End_Ind==0
	prog_missingdate Start End					// RUN prog_missingdate AGAIN.
	drop LB_MY

	// NOTE: THE CODING IN THE NEXT 8 LINES IN LIAM WRIGHT'S ORIGINAL VERSION SEEMS ODD BECAUSE THE 'if' CONDITION REQUIRES "Missing_Start/EndDate==1" WHICH RENDERS THOSE 8 LINES EFFECTIVELY REDUNDANT, SINCE Missing_Start/EndDate ARE NEVER==1 FOR UKHLS DATA, AS THAT VALUE APPLIES ONLY WHEN SEASON IS OBSERVED. THAT VALUE "1" APPEARS TO BE AN ERROR. IT APPEARS THAT THE CODE SHOULD INSTEAD SHOULD REFER TO Missing_Start/EndDate==2, SINCE IT SHOULD APPLY TO CASES WHERE YEAR BUT NOT MONTH IS OBSERVED.
	replace Start_MY=ym(Start_Y,12) if Start_Y<End_Y & Missing_StartDate==2	// IMPUTE START MONTH AS DECEMBER IF MISSING.
	replace Start_Flag=3 if Start_Y<End_Y & Missing_StartDate==2			// "3. Imputed: Equal division across gap"
	replace Start_MY=ym(Start_Y,1) if Start_Y==End_Y & Missing_StartDate==2 & month(dofm(End_MY))==1	// Spell ENDS IN JANUARY, MISSING Start_M, START AND YEAR SAME: CAN INFER SPELL STARTS IN JANUARY; Start_Flag SET AS "0. No imputation".
	replace Start_Flag=0 if Start_Y==End_Y & Missing_StartDate==2 & month(dofm(End_MY))==1

	replace End_MY=ym(End_MY,12) if Start_Y==End_Y & Missing_EndDate==2 & month(dofm(Start_MY))==12		// Spell STARTS IN DECEMBER, MISSING End_M, START AND YEAR SAME: CAN INFER SPELL ENDS IN DECEMBER; End_Flag SET AS "0. No imputation".
	replace End_Flag=0 if Start_Y==End_Y & Missing_EndDate==2 & month(dofm(Start_MY))==12
	replace End_MY=ym(End_Y,1) if Start_Y<End_Y & Missing_EndDate==2		// IMPUTE END MONTH AS JANUARY IF MISSING.
	replace End_Flag=3 if Start_Y<End_Y & Missing_EndDate==2				//  "3. Imputed: Equal division across gap"
	prog_missingdate Start End					// RUN prog_missingdate AGAIN.

	replace Start_Flag=4 if Missing_StartDate!=0 & Missing_EndDate==0
	replace Start_MY=End_MY-1 if Missing_StartDate!=0 & Missing_EndDate==0
	replace End_Flag=4 if Missing_StartDate==0 & Missing_EndDate!=0
	replace End_MY=Start_MY+1 if Missing_StartDate==0 & Missing_EndDate!=0
	prog_missingdate Start End	

	replace End_Flag=1 if End_MY>IntDate_MY & Missing_EndDate!=0
	replace End_MY=IntDate_MY if End_MY>IntDate_MY & Missing_EndDate!=0

	drop if Missing_StartDate!=0 | Missing_EndDate!=0						// CASES OF MISSING START/END DATES OCCUR FOR SAME pidp-Waves (FOR UKHLS UP TO WAVE 12 [30])
	//drop if Start_MY>End_MY												// DROPPED IN LW ORIGINAL CODE. NOT DROPPED HERE WHERE FOCUS IS ON END DATES, APART FROM A MINORITY OF CASES INVOLVING IMPUTED END DATES; IN THOSE CASES, Start_MY>End_MY BECAUSE Start_MY>IntDate_MY, WHICH RENDERS Start_MY IMPLAUSIBLE AND THE EDUCATION DATES OF LITTLE EMPIRICAL VALUE.
	drop if Start_MY>End_MY & End_Flag!=0 & Start_MY>IntDate_MY
	//drop if Start_MY==End_MY
	drop *_M *_Y Missing_*Date


	*viii. Combine overlapping spells and save dataset.
		* If end date is after start date of next spell but before its end date, replaces end date with end date[_n+1] 
		* If end date is after start date of next spell and after its end date, next spell dropped as it is subsumed entirely.
	prog_cleaneduhist
	prog_format	

	save "${dta_fld}/UKHLS Education History", replace
	rm "${dta_fld}/UKHLS Education History - Raw.dta"
	}


else if "$work_educ"=="educ" | "$work_educ"=="EDUC" {						// USE LW ORIGINAL UKHLS EDUCATION HISTORY.DO APART FROM CORRECTION OF MINOR ERROR. COMMENT: prog_cleaneduhist CALLS THE REVISED prog_implausibledates THAT REACTS TO CHOICE OF $noneducstatus_minage BUT AS IN THE ORIGINAL LW CODE IT DROPS EDUCATION SPELLS STARTING BEFORE BIRTH.
	
	/*
	********************************************************************************
	UKHLS EDUCATION HISTORY.DO
		
		THIS FILE CREATES HISTORIES OF FULL-TIME EDUCATION USING THE ANNUAL HISTORY
		MODULE FROM UNDERSTANDING SOCIETY.


	********************************************************************************
	*/

	/*
	2. Dataset Preparation.
		* Annual Education History Modules asked from Wave 2 onwards.
	*/
	/**/
	qui{
		forval i=2/$ukhls_waves{	
			local j: word `i' of `c(alpha)'
			use pidp `j'_contft `j'_ftend* `j'_fted* `j'_ft2* /*
				*/ using "${fld}/${ukhls_path}_w`i'/`j'_indresp${file_type}", clear
			merge 1:1 pidp using "${fld}/${ukhls_path}_w`i'/`j'_indall${file_type}", /*
				*/ keepusing(`j'_ff_everint `j'_ff_ivlolw `j'_ivfio) /*
				*/ keep(match) nogenerate
			prog_recodemissing *
			compress
			rename `j'_* *
			gen Wave=`i'+18
			keep if ivfio==1 & (ff_ivlolw==1 | ff_everint==1)
			tempfile Temp`i'
			save "`Temp`i''", replace		
			}
		forval i=`=$ukhls_waves-1'(-1)2{
			append using "`Temp`i''"
			}
		save "${dta_fld}/UKHLS Education History - Raw", replace
		}
	*/

	/*
	3. Format and clean annual education history dataset
		* GETS START AND END DATES FOR EACH SPELL.
	*/
	/**/
	*i. Open dataset
	prog_reopenfile "${dta_fld}/UKHLS Education History - Raw"		// PROG_REOPENFILE OPENS UP A DATASET IF IT ISN'T ALREADY IN MEMORY UNCHANGED.
	prog_labels		// CREATES LABELS
	order *, alphabetic
	order pidp Wave ff_*

	*ii. Index Spell
	gen Has_Activity0=1 if contft!=.i

	gen Source_Variable0="contft_w"+strofreal(Wave) if Has_Activity0==1

	gen End_Ind0=.m if Has_Activity0==1
	replace End_Ind0=0 if contft==1
	replace End_Ind0=1 if contft==2

	gen Start_M0=.i
	gen Start_Y0=.i

	gen End_M0=cond(End_Ind0==1,ftendm,.i)
	gen End_Y0=cond(End_Ind0==1,ftendy4,.i)

	*iii. Spells 1+*
	ds ftedmor*
	local spells: word count `r(varlist)'
	forval i=1/`spells'{
		if `i'==1{
			gen Has_Activity`i'=1 if ftedany==1
			gen Source_Variable`i'="ftedany_w"+strofreal(Wave) if Has_Activity`i'==1
			}
		else if `i'>1{
			local j=`i'-1
			gen Has_Activity`i'=1 if ftedmor`j'==1		
			gen Source_Variable`i'="ftedmor`j'_w"+strofreal(Wave) if Has_Activity`i'==1
			}
		
		gen End_Ind`i'=.m if Has_Activity`i'==1
		replace End_Ind`i'=0 if ftedend`i'==2
		replace End_Ind`i'=1 if ftedend`i'==1
		
		gen Start_M`i'=ftedstartm`i'
		gen Start_Y`i'=ftedstarty4`i'
		
		gen End_M`i'=cond(End_Ind`i'==1,ft2endm`i',.i)
		gen End_Y`i'=cond(End_Ind`i'==1,ft2endy4`i',.i)
		}	
		
	*iv. Reshape into long format
	keep pidp Wave Start* End* Has* Source*
	egen XX=rownonmiss(Has_Activity*)
	drop if XX==0
	drop XX

	reshape long Has_Activity Source_Variable End_Ind /*
		*/ Start_M Start_Y End_M End_Y, /*
		*/ i(pidp Wave) j(Spell)
	keep if Has_Activity==1
	drop Has_Activity

	*v. Merge with Interview Grid and delete observations with missing interview dates
	merge m:1 pidp Wave using "${dta_fld}/Interview Grid", /*
		*/ keepusing(LB_MY IntDate_MY jbstat) keep(match) nogenerate
	drop if missing(IntDate_MY, LB_MY)

	*vi. Replace missing end indicator
		/// Assumes no stops in FTE where end indicator is missing and participant gives FTE as current jbstat
	replace End_Ind=0 if jbstat==7 & End_Ind==.m
	drop jbstat

	*vii .Generate month-year variables
		* Continuing activities are given interview date as end date
		* Index spells are given start date at time of previous interview.
		* Missing end or start years are set equal start or end year where these are the same as the interview or previous interview year
		* Start or end dates outside interview date range set to be coterminuous with these, except:
				* Observations dropped where this leads to negative duration spells.
				* Observations dropped where corresponding end and start dates are missing (without this wouldn't know if the event occured completely before or after period between interviews).
			* Start and end dates set equal where one but not the other is equal
			/// Only using data from events taking place between interviews:
				/// 1. To ensure observations from closest point in time to the event are used.
				/// 2. To stop overlap between observations.
	foreach i in Start End{
		gen `i'_MY=ym(`i'_Y,`i'_M)
		replace `i'_MY=.m if missing(`i'_MY)
		}
	prog_missingdate Start End
	gen Start_Flag=0 if Missing_StartDate==0
	gen End_Flag=0 if Missing_EndDate==0
	label values Start_Flag End_Flag flag	

	replace Start_MY=LB_MY if Spell==0	
	replace End_MY=IntDate_MY if End_Ind==0
	replace Start_Flag=1 if Spell==0
	replace End_Flag=1 if End_Ind==0
	prog_missingdate Start End
	drop LB_MY

	replace Start_Flag=3 if Start_Y<End_Y & Missing_StartDate==1
	replace Start_Flag=0 if Start_Y==End_Y & Missing_StartDate==1 & month(dofm(End_MY))==1
	replace Start_MY=ym(Start_Y,12) if Start_Y<End_Y & Missing_StartDate==1
	replace Start_MY=ym(Start_Y,1) if Start_Y==End_Y & Missing_StartDate==1 & month(dofm(End_MY))==1
	replace End_Flag=3 if Start_Y<End_Y & Missing_EndDate==1
	replace End_Flag=0 if Start_Y==End_Y & Missing_EndDate==1 & month(dofm(Start_MY))==12
	replace End_MY=ym(End_Y,1) if Start_Y<End_Y & Missing_EndDate==1
	replace End_MY=ym(End_MY,12) if Start_Y==End_Y & Missing_EndDate==1 & month(dofm(Start_MY))==12
	prog_missingdate Start End	

	replace Start_Flag=4 if Missing_StartDate!=0 & Missing_EndDate==0
	replace Start_MY=End_MY-1 if Missing_StartDate!=0 & Missing_EndDate==0
	replace End_Flag=4 if Missing_StartDate==0 & Missing_EndDate!=0
	replace End_MY=Start_MY+1 if Missing_StartDate==0 & Missing_EndDate!=0
	prog_missingdate Start End	

	replace End_Flag=1 if End_MY>IntDate_MY & Missing_EndDate!=0
	replace End_MY=IntDate_MY if End_MY>IntDate_MY & Missing_EndDate!=0

	drop if Missing_StartDate!=0 | Missing_EndDate!=0	
	drop if Start_MY>End_MY
	drop if Start_MY==End_MY
	drop *_M *_Y Missing_*Date

	*viii. Combine overlapping spells and save dataset.
		* If end date is after start date of next spell but before its end date, replaces end date with end date[_n+1] 
		* If end date is after start date of next spell and after its end date, next spell dropped as it is subsumed entirely.
	prog_cleaneduhist
	prog_format

	save "${dta_fld}/UKHLS Education History", replace
	rm "${dta_fld}/UKHLS Education History - Raw.dta"
	*/

	}
