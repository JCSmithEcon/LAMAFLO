* UPDATED PROGRAMS THAT MUST BE RUN INSTEAD OF ORIGINAL LW CODE TO DEAL WITH FURLOUGH: prog_labels, prog_lastspellmissing, prog_format, prog_attrend.
* UPDATED PROGRAMS THAT DEFAULT TO LW ORIGINAL CODE IF DEFAULT OPTIONS FOR GLOBALS ARE NOT CHOSEN: prog_implausibledates, prog_nonchron, prog_assignwinter.

// prog_recodemissing RECODES MISSING VALUES TO STATA MISSING VALUE CODES.
capture program drop prog_recodemissing
program prog_recodemissing
	syntax varlist
	qui{
	foreach var of varlist `varlist'{
		if strpos("`var'","_MY")==0 {
			local lbl: value label `var'
			if "`lbl'"!=""{
				capture numlabel `lbl', add
				capture label define `lbl' .m ".m. Missing/Refused/Don't Know" /*
					*/ .i ".i. IEMB/Innapplicable/Proxy", add
				}
			capture confirm string variable `var'
			if _rc>0{
				replace `var'=.m if inlist(`var',-20,-9,-2,-1)
				replace `var'=.i if inlist(`var',-10,-8,-7)
				}
			}
		}
	}
end

// prog_reopenfile USES NEW DATA FILE IF IT'S SAFE TO DO SO.
capture program drop prog_reopenfile
program prog_reopenfile
	args filename
	if "`c(filename)'"!="`filename'" | `c(changed)'==1{
		use "`filename'", clear
		}
end

// "Labels.do" UPDATED TO INCLUDE status values 12 Furlough AND 13 Temporarily laid off/short term working.
// "Apply Labels.do" UPDATED TO ADD EndReason12 "Furloughed" TO INCORPORATE stendreas12 "Furloughed".
capture program drop prog_labels
program prog_labels
	qui do "${do_fld}/Labels_JCS.do"
	qui do "${do_fld}/Apply Labels_JCS.do"
end

// prog_missingdate CODES REASONS FOR MISSING DATES INTO NEW VARIABLE Missing_`var'Date.
// 0: YEAR AND MONTH OBSERVED; 1: YEAR AND SEASON AVAILABLE BUT MISSING MONTH; 2: YEAR AVAILABLE BUT MISSING [SEASON AND] MONTH; 3: MISSING ALL AVAILABLE DATE COMPONENTS.
capture program drop prog_missingdate
program prog_missingdate
	syntax namelist
	foreach var in `namelist'{
		if "`var'"!="Start" & "`var'"!="End"{
			di in red "Invalid: possible parameters 'Start' or 'End'"
			continue, break
			}
		
		capture drop Missing_`var'Date
		gen Missing_`var'Date=0 if !missing(`var'_MY)		
		capture confirm variable `var'_SY
		if _rc==0{
			replace Missing_`var'Date=1 if /*
				*/ !missing(`var'_Y) & !missing(`var'_SY) & missing(`var'_MY)
			replace Missing_`var'Date=2 if /*
				*/ !missing(`var'_Y) & missing(`var'_SY) & missing(`var'_MY)
			replace Missing_`var'Date=3 if /*
				*/ missing(`var'_Y) & missing(`var'_SY) & missing(`var'_MY)
			}
		else{
			replace Missing_`var'Date=2 if /*
				*/ !missing(`var'_Y) & missing(`var'_MY)
			replace Missing_`var'Date=3 if /*
				*/ missing(`var'_Y) & missing(`var'_MY)
			}			
		}
end

capture program drop prog_statusspells
program prog_statusspells
	syntax varlist
	local i ""
	foreach var of varlist `varlist' {
		local i "`i' | `var'!=`var'[_n-1]"
		}
	local i=subinstr("`i'"," | ","",1)
	capture drop Status_Spell*
	by pidp Wave (Spell), sort: gen XX=(`i')
	by pidp Wave (Spell), sort: gen YY=sum(XX)
	by pidp Wave (YY Spell), sort: gen ZZ=1 if /*
			*/ YY!=YY[_n-1] | !missing(Start_Y)
	by pidp Wave (Spell), sort: gen Status_Spell=sum(ZZ)
	by pidp Wave Status_Spell (Spell), sort: gen Status_Spells=_N
	drop XX YY ZZ
end

// prog_afterint DROPS OBSERVATIONS FOR A pid-Wave AT & AFTER THE EARLIEST SPELL THAT Wave WHERE START DATE IS AFTER INTERVIEW DATE. IT DROPS ONLY SPELLS THAT HAVE THAT START DATE PROBLEM. 
capture program drop prog_afterint
program prog_afterint
	args xx
	gen XX=.
	foreach i in Y SY MY{
		replace XX=Spell if IntDate_`i'<`xx'_`i' & !missing(IntDate_`i', `xx'_`i')
		}
	by pidp Wave (Spell), sort: egen YY=min(XX)
	drop if Spell>=YY & !missing(YY)
	by pidp Wave (Spell), sort: replace End_Ind=End_Type if _n==_N
	drop XX YY
end

// prog_assignwinter IS USED IN "BHPS Life History.do". IT ASSIGNS LATE(Dec)/EARLY(Jan-Feb) WINTER WHERE THAT SPLIT IS NOT IN THE DATA. LIAM WRIGHT'S ORIGINAL CODE LEADS TO THE DROPPING OF OBSERVATIONS WHERE THERE IS NO INFORMATION ON PREVIOUS OR LATER SPELLS TO BE ABLE TO LOGICALLY ASSIGN EARLY/LATE WINTER. THIS REVISED CODE RETAINS THOSE OBSERVATIONS USING THE CONVENTION THAT WINTER IS ASSIGNED TO JANUARY, CODED HERE AS EARLY WINTER (Jan-Feb) (WHERE THERE IS NO INFORMATION TO INDICATE WHETHER IT IS EARLY OR LATE FEBRUARY).
capture program drop prog_assignwinter
program prog_assignwinter
	gen Reverse=-Spell
	by pidp Wave Start_Y (Spell), sort: gen XX=Start_SY[_n-1]
	by pidp Wave Start_Y (Spell), sort: replace XX=XX[_n-1] if missing(XX)
	by pidp Wave Start_Y (Reverse), sort: gen YY=Start_SY[_n-1]
	by pidp Wave Start_Y (Reverse), sort: replace YY=YY[_n-1] if missing(YY)
	replace YY=month(dofm(IntDate_SY)) if Start_Y==IntDate_Y & missing(YY)
	replace Start_SY=ym(Start_Y,5) if Winter==1 & /*
		*/ !missing(XX) & missing(YY)
	replace Start_SY=ym(Start_Y,1) if Winter==1 & /*
		*/ missing(XX) & !missing(YY)
	replace Start_SY=ym(Start_Y,1) if Winter==1 & /*
		*/ missing(XX) & missing(YY)		// THIS ADDED LINE ASSIGNS JAN_FEB (AS [JANUARY] IS CONVENTIONAL) IN CASES WHERE SEASON IS KNOWN TO BE WINTER BUT THERE IS NO INFORMATION FROM PREVIOUS OR LATER SPELLS TO BE ABLE TO ASSIGN EARLY OR LATE WINTER. THIS ADDS MANY (640 USING WAVES 2, 11 AND 12 bb/bk/bl_lifemst) SEASONAL SPELL START DATES.
	drop XX YY Winter Reverse
end
//
// LIAM WRIGHT ORIGINAL prog_assignwinter:
//
capture program drop prog_assignwinter_orig
program prog_assignwinter_orig
	gen Reverse=-Spell
	by pidp Wave Start_Y (Spell), sort: gen XX=Start_SY[_n-1]
	by pidp Wave Start_Y (Spell), sort: replace XX=XX[_n-1] if missing(XX)
	by pidp Wave Start_Y (Reverse), sort: gen YY=Start_SY[_n-1]
	by pidp Wave Start_Y (Reverse), sort: replace YY=YY[_n-1] if missing(YY)
	replace YY=month(dofm(IntDate_SY)) if Start_Y==IntDate_Y & missing(YY)
	replace Start_SY=ym(Start_Y,5) if Winter==1 & /*
		*/ !missing(XX) & missing(YY)
	replace Start_SY=ym(Start_Y,1) if Winter==1 & /*
		*/ missing(XX) & !missing(YY)
	drop XX YY Winter Reverse
end

// prog_implausibledates IS REVISED TO GIVE THE OPTION OF DROPPING JUST THE IMPLAUSIBLE OBSERVATIONS _OR_ ALL pidp-Wave OBSERVATIONS WHERE START/END DATE IS BEFORE BIRTH. LIAM WRIGHT'S ORIGINAL CODE DROPS ALL pidp-Wave OBSERVATIONS WHERE NON-EDUCATION START/END DATE IS BEFORE AGE 12. THIS REVISED CODE ALLOWS RESEARCHERS TO SPECIFY THEIR LOWEST ACCEPTABLE AGE FOR NON-EDUCATION SPELL START/END DATES, WITH A DEFAULT VALUE OF 0 RETAINING ALL NON-EDUCATION SPELLS STARTING AFTER BIRTH. SEE "${do_fld}/prog_nonchron BHPS.do".
capture program drop prog_implausibledates
program prog_implausibledates
	args xx
	gen XX=cond(`xx'_Y-Birth_Y<0 & !missing(`xx'_Y, Birth_Y),1,0)									// IDENTIFIES START/END DATES PRIOR TO BIRTH.
	replace XX=1 if `xx'_Y<Birth_Y+$noneducstatus_minage & !missing(`xx'_Y, Birth_Y) & Status!=7	// IDENTIFIES NON-EDUCATION SPELL WITH START/END DATE PRIOR TO AGE $noneducstatus_minage. $noneducstatus_minage DEFAULT IS 0, WHICH RETAINS ALL SPELLS WITH START/END DATES AFTER BIRTH.
//	replace XX=1 if `xx'_Y-Birth_Y<12 & !missing(`xx'_Y, Birth_Y) & Status!=7						// LIAM WRIGHT ORIGINAL CODE WHICH DROPS pidp-Wave IF ANY NON-EDUCATION SPELL STARTS/ENDS BEFORE AGE 12.
	qui count if XX==1
	local countXX = r(N)
//	di in red "`r(N)' cases of implausible start dates (earlier than birth or non education statuses before 12th year). Drop history where implausible."
	qui by pidp Wave (Spell), sort: egen YY=max(XX)
	local countYY = r(N)
	if "$implausibledates_drop"=="obs" {
		di in red "`countXX' cases of implausible start dates (earlier than birth). You have chosen to just drop the implausible-date spells (`countXX' observations) (rather than dropping the whole pidp-Wave history (`countYY' observations)). You have chosen to retain non education statuses after age $noneducstatus_minage."
		drop if XX==1									// DROPS JUST THE IMPLAUSIBLE SPELLS WITH START/END DATE PRIOR TO BIRTH OR NON-EDUCATION SPELL WITH START/END DATE PRIOR TO AGE $noneducstatus_minage.
		by pidp Wave (Spell), sort: replace Spell=_n	// RENUMBER SPELLS.
		}
	else if "$implausibledates_drop"!="obs" {
		di in red "`r(N)' cases of implausible start dates (earlier than birth). You have chosen to drop the whole pidp-Wave history (`countYY' observations) where at least one date is implausible (rather than just dropping the `countXX' implausible-date spells). You have chosen to retain non education statuses after age $noneducstatus_minage."
		drop if YY==1									// DROPS pidp-WAVE IF ANY START/END DATE IS PRIOR TO BIRTH OR THERE IS A NON-EDUCATION SPELL WITH START/END DATE PRIOR TO AGE $noneducstatus_minage. NO NEED TO RENUMBER SPELLS BECAUSE ALL SPELLS FOR THAT pidp-Wave ARE DROPPED.
		}
	drop XX YY
end
//
// LIAM WRIGHT ORIGINAL prog_implausibledates:
//
/*
capture program drop prog_implausibledates
program prog_implausibledates
	args xx
	gen XX=cond(`xx'_Y-Birth_Y<0 & !missing(`xx'_Y, Birth_Y),1,0)
	replace XX=1 if `xx'_Y-Birth_Y<12 & !missing(`xx'_Y, Birth_Y) & Status!=7
	count if XX==1
	di in red "`r(N)' cases of implausible start dates (earlier than birth or non education statuses before 12th year). Drop history where implausible"
	by pidp Wave (Spell), sort: egen YY=max(XX)
	drop if YY==1
	drop XX YY	
end
*/

// prog_nonchron - THIS IS LW ORIGINAL CODE. A DIFFERENT VARIANT IS USED FOR BHPS LIFE HISTORY (RUN VIA DO FILE prog_nonchron_BHPS.do).
capture program drop prog_nonchron
program prog_nonchron
	syntax namelist
	local i: word 1 of `namelist'
	local namelist: list namelist - i
	if strpos("`namelist'","SY")>0{
		local k="`i'_S" 
		}
	else{
		local k ""
		}
	if "`i'"!="Start" & "`i'"!="End"{
		di in red "Need to specify Start or End dates on which to base NonChron"
		STOP
		}
	capture drop XX
	gen XX=0
	foreach j in `namelist'{
		gen YY=cond(missing(`i'_`j'),1,0)
		by pidp Wave YY (Spell), sort: replace XX=1 if /*
			*/ `i'_`j'>`i'_`j'[_n+1] & !missing(`i'_`j', `i'_`j'[_n+1])
		drop YY
		}
	by pidp Wave (Spell), sort: egen NonChron_Wave=max(XX)
	drop XX	
	by pidp Wave (Spell), sort: egen XX=max(missing(`i'_Y))
	drop if NonChron_Wave==1 & XX==1
	drop XX
	if strpos("`namelist'","SY")>0{
		gen XX=(missing(`i'_SY))
		by pidp Wave `i'_Y (`i'_SY `i'_MY), sort: egen YY=total(XX)
		by pidp Wave `i'_Y (`i'_SY `i'_MY), sort: gen ZZ=_N
		by pidp Wave (`i'_Y `i'_SY `i'_MY), sort: egen AA=max(NonChron_Wave==1 & YY>=1 & ZZ>=2)
		drop if AA==1
		drop XX YY ZZ AA 
		
		gen XX=(missing(`i'_MY))
		by pidp Wave `i'_Y `i'_SY (`i'_MY), sort: egen YY=total(XX)
		by pidp Wave `i'_Y `i'_SY (`i'_MY), sort: gen ZZ=_N
		by pidp Wave (`i'_Y `i'_SY `i'_MY), sort: egen AA=max(NonChron_Wave==1 & YY>=1 & ZZ>=2)
		drop if AA==1
		drop XX YY ZZ AA 
		}
	else{
		gen XX=(missing(`i'_MY))
		by pidp Wave `i'_Y (`i'_MY), sort: egen YY=total(XX)
		by pidp Wave `i'_Y(`i'_MY), sort: gen ZZ=_N
		by pidp Wave (`i'_Y `i'_MY), sort: egen AA=max(NonChron_Wave==1 & YY>=1 & ZZ>=2)
		drop if AA==1
		drop XX YY ZZ AA
		}
	drop if NonChron==1 & End_Type==.m
end

// prog_daterange SETS MinAbove and MaxBelow, WITHIN pidp-Wave, AS NEAREST START/END DATE ABOVE/BELOW, OR INTERVIEW DATE IF MinAbove FROM  NEXT SPELL START/END DATE IN THAT pidp-Wave IS MISSINGcapture program drop prog_daterange.
// (NEEDED FOR prog_monthfromseason VIA prog_imputeequaldates)
capture program drop prog_daterange
program prog_daterange
	args j
	qui{
	gen Reverse=-Spell
	foreach i in Start End{	
		tempvar `i'
		capture confirm variable `i'_`j'
		if _rc==0 	gen ``i''=`i'_`j'
		else		gen ``i''=.
		}
	foreach i in MaxBelow MinAbove{
		if "`i'"=="MaxBelow"{
			local sort "Spell"
			local function "max"
			capture gen `i'=Start_`j'
			capture gen `i'=End_`j'
			}
		else{
			local sort "Reverse"
			local function "min"
			capture gen `i'=End_`j'
			capture gen `i'=Start_`j'
			}
		tempvar XX
		gen `XX'=`function'(`Start',`End')
		by pidp Wave (`sort'), sort: replace `i'=`XX'[_n-1] /*
			*/ if missing(`i')
		by pidp Wave (`sort'), sort: replace `i'=`i'[_n-1] /*
			*/ if missing(`i')
		drop `XX'
		}
	drop `Start' `End' Reverse
	capture replace MinAbove=IntDate_`j' if missing(MinAbove)
	sort pidp Wave Spell
	}
end

//prog_imputeequaldates IMPUTES START/END DATE AS MaxBelow/MinAbove IF MaxBelow==MinAbove, AND CALLS prog_daterange WHICH SETS MinAbove and MaxBelow, WITHIN pidp-Wave, AS NEAREST START/END DATE ABOVE/BELOW, OR INTERVIEW DATE IF MinAbove FROM  NEXT SPELL START/END DATE IN THAT pidp-Wave IS MISSING.
capture program drop prog_imputeequaldates
program prog_imputeequaldates
	syntax namelist
	foreach n in `namelist'{
		prog_daterange `n'		// prog_daterange SETS MinAbove and MaxBelow, WITHIN pidp-Wave, AS NEAREST START/END DATE ABOVE/BELOW, OR INTERVIEW DATE IF MinAbove FROM  NEXT SPELL START/END DATE IN THAT pidp-Wave IS MISSING.
		capture replace Start_`n'=MaxBelow if /*
			*/ MaxBelow==MinAbove & missing(Start_`n') & !missing(MaxBelow,MinAbove)
		capture replace End_`n'=MinAbove if /*
			*/ MaxBelow==MinAbove & missing(End_`n') & !missing(MaxBelow,MinAbove)
		drop MaxBelow MinAbove
		}
end 

capture program drop prog_mytosytoy
program prog_mytosytoy
	syntax namelist
	qui{
		foreach n in `namelist'{
			replace `n'_Y=year(dofm(`n'_MY)) if missing(`n'_Y) & !missing(`n'_MY)
			capture confirm variable `n'_SY
			if _rc==0{
				replace `n'_SY=ym(year(dofm(`n'_MY)),		cond(inrange(month(dofm(`n'_MY)),1,2),1, /*
													*/		cond(inrange(month(dofm(`n'_MY)),3,5),2, /*
													*/		cond(inrange(month(dofm(`n'_MY)),6,8),3, /*
													*/		cond(inrange(month(dofm(`n'_MY)),9,11),4,5))))) /*
						*/ if missing(`n'_SY) & !missing(`n'_MY)
				replace `n'_Y=year(dofm(`n'_SY)) if missing(`n'_Y) & !missing(`n'_SY)
				replace `n'_MY=ym(`n'_Y,12) if !missing(`n'_Y) & missing(`n'_MY) & month(dofm(`n'_SY))==5
				}
			}
		}
end		

// prog_sytomy TRANSLATES SY CODES 1,2,3,4,5 INTO MONTHS: 5=LATE WINTER(Dec)=12 ALWAYS; 1=EARLY WINTER(Jan-Feb)=1 OR 2; 2=SPRING(Mar-May)=3/4/5; 3=SUMMER(Jun-Aug)=6,7,8; 4=AUTUMN(Sep-Nov)=9,10,11. ARGUMENT IN prog_sytomy AFTER MY SY DETERMINES THE CHOICE AMONG THESE ALTERNATIVES, USING WORD "Lower","Middle","Upper" RESPECTIVELY (EARLY WINTER BEING Jan=1 UNLESS "Upper").  
// (NEEDED FOR prog_monthfromseason)
capture program drop prog_sytomy
program define prog_sytomy
	args MY SY Bound
	if "`Bound'"=="Lower"{
		replace `MY'=ym(year(dofm(`SY')), /*
			*/ cond(month(dofm(`SY'))==1,1, /*
			*/ cond(month(dofm(`SY'))==2,3, /*
			*/ cond(month(dofm(`SY'))==3,6, /*
			*/ cond(month(dofm(`SY'))==4,9,12)))))
			}
	if "`Bound'"=="Middle"{
		replace `MY'=ym(year(dofm(`SY')), /*
			*/ cond(month(dofm(`SY'))==1,1, /*
			*/ cond(month(dofm(`SY'))==2,4, /*
			*/ cond(month(dofm(`SY'))==3,7, /*
			*/ cond(month(dofm(`SY'))==4,10,12)))))
			}
	if "`Bound'"=="Upper"{
		replace `MY'=ym(year(dofm(`SY')), /*
			*/ cond(month(dofm(`SY'))==1,2, /*
			*/ cond(month(dofm(`SY'))==2,5, /*
			*/ cond(month(dofm(`SY'))==3,8, /*
			*/ cond(month(dofm(`SY'))==4,11,12)))))
			}
end

// prog_lastspellmissing CREATES A SPELL BASED ON AVAILABLE DATE AND SPELL INFORMATION IF THE LAST SPELL IN A WAVE IS KNOWN TO HAVE OCCURRED FROM LATER INFO BUT IS MISSING IN THE WAVE IT OCCURRED. THE ORIGINAL (_orig) AND 2 OTHER VERSIONS ARE USED: THE NON-SUFFIXED VERSION FOCUSES ONLY ON UNDERLYING EMPLOYMENT SPELLS AND ADJUSTS RAW DATA TO REMOVE FURLOUGH STATUS; THE _F VERSION ALLOWS FURLOUGH AND UNDERLYING EMPLOYMENT STATUS TO BE SIMULTANEOUSLY EXAMINED. 
capture program drop prog_lastspellmissing_orig
program prog_lastspellmissing_orig
	merge m:1 pidp Wave using "${dta_fld}/Interview Grid", /*
		*/ nogen keep(match master) keepusing(jbstat Next_ff_jbstat Job_Hours_IG)
	by pidp Wave (Spell), sort: gen XX=1 if _n==_N & End_Type==.m & End_MY<IntDate_MY
	expand 2 if XX==1 & !missing(jbstat), gen(YY)
	replace Spell=Spell+1 if YY==1
	by pidp Wave (Spell), sort: replace Start_MY=IntDate_MY-1 if /*
		*/ YY==1 & End_MY[_n-1]<IntDate_MY
	by pidp Wave (Spell), sort: replace Start_MY=IntDate_MY if /*
		*/ YY==1 & End_MY[_n-1]==IntDate_MY
	replace End_MY=IntDate_MY if YY==1
	replace Start_Flag=5 if YY==1
	replace End_Flag=1 if YY==1
	replace Status=Next_ff_jbstat if YY==1 & !missing(Next_ff_jbstat)
	replace Status=jbstat if YY==1 & missing(Next_ff_jbstat) & !missing(jbstat)
	replace Status=.m if YY==1 & missing(Next_ff_jbstat) & missing(jbstat)
	replace Job_Hours=Job_Hours_IG if YY==1 & !missing(Job_Hours_IG) & inlist(Status,1,2)
	replace Job_Hours=.m if YY==1 & missing(Job_Hours_IG) & inlist(Status,1,2)
	replace Job_Hours=.i if YY==1 & !inlist(Status,1,2,100)
	replace Job_Change=.i if YY==1 & !inlist(Status,1,2,100)	// Job_Change IS SET TO .i FOR FURLOUGH/TEMP LAYOFF/S-T WORKING.
	replace Job_Change=.m if YY==1 & inlist(Status,1,2,100)
	replace Status_Spells=1 if YY==1
	capture replace Job_Attraction=.m if YY==1
	capture confirm variable End_Reasons_1
	if _rc==0{
		replace End_Reasons_1="0 0 0 0 0 0 0 0 0 0 0 0" if YY==1
		replace End_Reasons_i="1 1 1 1 1 1 1 1 1 1 1 1" if YY==1
		replace End_Reasons_m="0 0 0 0 0 0 0 0 0 0 0 0" if YY==1
		}
	capture replace Source_Variable="jbstat_w"+strofreal(Wave) if YY==1
	drop if YY==1 & Status==.m
	drop jbstat Job_Hours_IG Next_ff_jbstat XX YY
end
//
// prog_lastspellmissing IS ALTERED TO EXTRACT THE UNDERLYING EMPLOYMENT STATUS OF FURLOUGH SPELLS.
capture program drop prog_lastspellmissing
program prog_lastspellmissing
	merge m:1 pidp Wave using "${dta_fld}/Interview Grid", /*
		*/ nogen keep(match master) keepusing(jbstat Next_ff_jbstat Next_ff_jbsemp Job_Hours_IG)
	by pidp Wave (Spell), sort: gen XX=1 if _n==_N & End_Type==.m & End_MY<IntDate_MY
	expand 2 if XX==1 & !missing(jbstat), gen(YY)
	replace Spell=Spell+1 if YY==1
	by pidp Wave (Spell), sort: replace Start_MY=IntDate_MY-1 if /*
		*/ YY==1 & End_MY[_n-1]<IntDate_MY
	by pidp Wave (Spell), sort: replace Start_MY=IntDate_MY if /*
		*/ YY==1 & End_MY[_n-1]==IntDate_MY
	replace End_MY=IntDate_MY if YY==1
	replace Start_Flag=5 if YY==1
	replace End_Flag=1 if YY==1
	replace Status=Next_ff_jbstat if YY==1 & !missing(Next_ff_jbstat) /*			// ALTERED CODE.
		*/ & (inrange(Next_ff_jbstat,1,11) | inrange(Next_ff_jbstat,14,97))
	replace Status=1 if YY==1 & inlist(Next_ff_jbstat,12,13) & Next_ff_jbsemp==2	// REPLACES FURLOUGH WITH UNDERLYING STATUS.
	replace Status=2 if YY==1 & inlist(Next_ff_jbstat,12,13) & Next_ff_jbsemp==1
	replace Status=100 if YY==1 & inlist(Next_ff_jbstat,12,13) & missing(Next_ff_jbsemp)
	replace Status=jbstat if YY==1 & missing(Next_ff_jbstat) & !missing(jbstat) /*
		*/ & (inrange(jbstat,1,11) | inrange(jbstat,14,97))
	replace Status=100 if YY==1 & missing(Next_ff_jbstat) & inlist(jbstat,12,13)	// jbsemp NOT AVAILABLE.
	replace Status=.m if YY==1 & missing(Next_ff_jbstat) & missing(jbstat)
	replace Job_Hours=Job_Hours_IG if YY==1 & !missing(Job_Hours_IG) & inlist(Status,1,2)
	replace Job_Hours=.m if YY==1 & missing(Job_Hours_IG) & inlist(Status,1,2)
	replace Job_Hours=.i if YY==1 & !inlist(Status,1,2,100)
	replace Job_Change=.i if YY==1 & !inlist(Status,1,2,100)
	replace Job_Change=.m if YY==1 & inlist(Status,1,2,100)
	replace Status_Spells=1 if YY==1
	capture replace Job_Attraction=.m if YY==1
	capture confirm variable End_Reasons_1
	if _rc==0{
		replace End_Reasons_1="0 0 0 0 0 0 0 0 0 0 0 0" if YY==1 
		replace End_Reasons_i="1 1 1 1 1 1 1 1 1 1 1 1" if YY==1
		replace End_Reasons_m="0 0 0 0 0 0 0 0 0 0 0 0" if YY==1
		}
	capture replace Source_Variable="jbstat_w"+strofreal(Wave) if YY==1
	drop if YY==1 & Status==.m
	drop jbstat Job_Hours_IG Next_ff_jbstat XX YY
end
//
// prog_lastspellmissing_F IS ALTERED TO SUIT THE _F VARIANT OF UKHLS Annual History THAT RECORDS FURLOUGH SPELLS IN ADDITION TO UNDERLYING EMPLOYMENT STATUS.
capture program drop prog_lastspellmissing_F 
program prog_lastspellmissing_F
	merge m:1 pidp Wave using "${dta_fld}/Interview Grid", /*
		*/ nogen keep(match master) keepusing(jbstat Next_ff_jbstat Next_ff_jbsemp Job_Hours_IG)		// ALTERED TO KEEP Next_ff_jbsemp, NEEDED FOR Status FOR FURLOUGH DATASET VARIANT.
	by pidp Wave (Spell), sort: gen XX=1 if _n==_N & End_Type==.m & End_MY<IntDate_MY
	expand 2 if XX==1 & !missing(jbstat), gen(YY)
	replace Spell=Spell+1 if YY==1
	by pidp Wave (Spell), sort: replace Start_MY=IntDate_MY-1 if /*
		*/ YY==1 & End_MY[_n-1]<IntDate_MY
	by pidp Wave (Spell), sort: replace Start_MY=IntDate_MY if /*
		*/ YY==1 & End_MY[_n-1]==IntDate_MY
	
	replace End_MY=IntDate_MY if YY==1
	replace Start_Flag=5 if YY==1
	replace End_Flag=1 if YY==1
// THE FOLLOWING LINES OF CODE ARE CHANGED SO THAT FURLOUGH STATUS IS NOT DRAGGED FORWARD BEYOND PLAUSIBLE FIRST START DATE OF 1/3/2020, AND TO CREATE FURLOUGH STATUS CODES COMPARABLE WITH THOSE CREATED IN UKHLS ANNUAL HISTORY. Status OF MISSING LAST SPELL IS IMPUTED AS NEXT STATUS, WITH FURLOUGH STATUSES ONLY IMPUTED IF (IMPUTED) START DATE IS PLAUSIBLE (I.E. BETWEEN MARCH 2020 AND SEPTEMBER 2021), AND FURLOUGH STATUSES CALCULATED AS IN "UKHLS Annual History.do" TO SHOW UNDERLYING EMPLOYMENT STATUS AS WELL AS FURLOUGH STATUS. 
	replace Status=Next_ff_jbstat if YY==1 & !missing(Next_ff_jbstat) & !inlist(Next_ff_jbstat,12,13)	// STANDARD CODE IS FINE FOR NON-FURLOUGH STATUS.
	replace Status=jbstat if YY==1 & missing(Next_ff_jbstat) & !missing(jbstat)	& !inlist(jbstat,12,13)	

	replace Status=100+Next_ff_jbstat if YY==1 & inlist(Next_ff_jbstat,12,13) /*
		*/ & inrange(Start_MY,tm(2020mar),tm(2021sep)) & Next_ff_jbsemp==2								// THIS IS A SIMPLIFIED VERSION OF CODE USED TO CREATE Status_F IN UKHLS ANNUAL HISTORY (SIMPIFIED BECAUSE VARIABLES SUCH AS samejob ARE NOT PRESENT). FURLOUGH SCHEME CJRS closed on 30 September 2021; LIMIT USE OF FURLOUGH STATUS TO DURING THE SCHEME.
	replace Status=200+Next_ff_jbstat if YY==1 & inlist(Next_ff_jbstat,12,13) /*
		*/ & inrange(Start_MY,tm(2020mar),tm(2021sep)) & Next_ff_jbsemp==1
	replace Status=10000+Next_ff_jbstat if YY==1 & inlist(Next_ff_jbstat,12,13) /*
		*/ & inrange(Start_MY,tm(2020mar),tm(2021sep)) & missing(Next_ff_jbsemp)
	replace Status=100+jbstat if YY==1 & missing(Next_ff_jbstat) & inlist(jbstat,12,13) /*
		*/ & inrange(Start_MY,tm(2020mar),tm(2021sep)) & Next_ff_jbsemp==2
	replace Status=200+jbstat if YY==1 & missing(Next_ff_jbstat) & inlist(jbstat,12,13) /*
		*/ & inrange(Start_MY,tm(2020mar),tm(2021sep)) & Next_ff_jbsemp==1
	replace Status=10000+jbstat if YY==1 & missing(Next_ff_jbstat) & inlist(jbstat,12,13) /*
		*/ & inrange(Start_MY,tm(2020mar),tm(2021sep)) & missing(Next_ff_jbsemp)
	replace Status=.m if YY==1 & missing(Next_ff_jbstat) & missing(jbstat)
	replace Status=.m if YY==1 & (inlist(Next_ff_jbstat,12,13) | (missing(Next_ff_jbstat) & inlist(jbstat,12,13))) /*
		*/ & !inrange(Start_MY,tm(2020mar),tm(2021sep))
	replace Job_Hours=Job_Hours_IG if YY==1 & !missing(Job_Hours_IG) & inlist(Status,1,2)
	replace Job_Hours=.m if YY==1 & missing(Job_Hours_IG) & inlist(Status,1,2,100,112,113,212,213,10012,10013)
	replace Job_Hours=.i if YY==1 & !inlist(Status,1,2,100,112,113,212,213,10012,10013)
	replace Job_Change=.i if YY==1 & !inlist(Status,1,2,100,112,113,212,213,10012,10013)				// Job_Change IS SET TO .i FOR FURLOUGH/TEMP LAYOFF/S-T WORKING.
	replace Job_Change=.m if YY==1 & inlist(Status,1,2,100,112,113,212,213,10012,10013)
	replace Status_Spells=1 if YY==1
	capture replace Job_Attraction=.m if YY==1
	capture confirm variable End_Reasons_1
	if _rc==0{
		replace End_Reasons_1="0 0 0 0 0 0 0 0 0 0 0 0" if YY==1
		replace End_Reasons_i="1 1 1 1 1 1 1 1 1 1 1 1" if YY==1
		replace End_Reasons_m="0 0 0 0 0 0 0 0 0 0 0 0" if YY==1
		}
	capture replace Source_Variable="jbstat_w"+strofreal(Wave) if YY==1
	drop if YY==1 & Status==.m
	drop jbstat Job_Hours_IG Next_ff_jbstat XX YY
end

// prog_imputemissingspells CREATES AN ADDITIONAL SPELL WITH MISSING DATA APART FROM DATES, TO FILL ANY GAP BETWEEN A SPELL End Date AND THE NEXT SPELL Start Date.
capture program drop prog_imputemissingspells 	
program prog_imputemissingspells
	capture confirm variable Wave
	if _rc==0{
		local i="Wave"
		capture by pidp `i' (Spell), sort: gen XX=cond(_n==_N & End_MY<IntDate_MY,1,0)
		}
	else{
		local i=""
		gen XX=.
		}
	by pidp (`i' Spell), sort: gen YY=cond(End_MY<Start_MY[_n+1] & _n<_N,1,0)
	
	expand 2 if XX==1 | YY==1, gen(ZZ)
	by pidp (`i' Spell ZZ), sort: replace Spell=_n
	capture by pidp (`i' Spell ZZ), sort: replace IntDate_MY=IntDate_MY[_n+1] if ZZ==1 & _n<_N
	capture by pidp (`i' Spell ZZ), sort: replace Wave=Wave[_n+1] if ZZ==1 & _n<_N
	replace Status=.m if ZZ==1
	replace Job_Hours=.m if ZZ==1

	capture confirm variable End_Reason1
	if _rc==0{
		foreach var of varlist End_Reason* Job_Attraction* {
			replace `var'=.i if ZZ==1
			}
		}
	capture replace Source_Variable=".m" if ZZ==1
	capture replace Source="Gap" if ZZ==1
	replace Start_MY=End_MY if ZZ==1
	by pidp (`i' Spell), sort: replace End_MY=Start_MY[_n+1] if ZZ==1 & _n<_N
	capture by pidp (`i' Spell), sort: replace End_MY=IntDate_MY if ZZ==1 & _n==_N
	by pidp (`i' Spell), sort: replace Start_Flag=End_Flag[_n-1] if ZZ==1 & _n>1
	by pidp (`i' Spell), sort: replace End_Flag=Start_Flag[_n+1] if ZZ==1 & _n<_N
	by pidp (`i' Spell), sort: replace End_Flag=1 if ZZ==1 & _n==_N
	drop XX YY ZZ
end	

// prog_checkoverlap CHECKS FOR/WARNS OF OVERLAPPING START/END DATES, AFTER RUNNING prog_daterange.
capture program drop prog_checkoverlap 											
program prog_checkoverlap
	prog_daterange MY
	count if Start_MY>End_MY & !missing(Start_MY,End_MY)
	local i=`r(N)'
	count if floor(End_MY)>IntDate_MY & !missing(End_MY)
	local j=`r(N)'
	count if End_MY>MinAbove & !missing(MinAbove) & !missing(End_MY)
	local k=`r(N)'
	count if Start_MY<MaxBelow & !missing(MaxBelow) & !missing(Start_MY)
	local l=`r(N)'
	if `i'!=0 | `j'!=0 | `k'!=0 | `l'!=0{
		di in red "There are multiple cases of overlap. This should not be the case."
		STOP
		}
	drop MaxBelow MinAbove
end

// prog_overlap FLAGS VARIOUS OVERLAPS AFFECTING START AND END DATES. THESE OVERLAPS ARISE ACROSS DATASETS (ANNUAL(BHPS,UKHLS), LIFE(BHPS,UKHLS), EDUCATION(BHPS,UKHLS)): CLEANING HAS REMOVED ALL OVERLAPS WITHIN DATASETS.
capture program drop prog_overlap
program prog_overlap
	capture drop F_* 
	capture drop L_*
	qui{
		gen F_Overlap=0
		by pidp (Spell), sort: replace F_Overlap=1 if _n<_N & Start_MY>=Start_MY[_n+1] & End_MY<=End_MY[_n+1]	// START PROBLEM F_OVERLAP=1
		by pidp (Spell), sort: replace F_Overlap=2 if _n<_N & Start_MY<Start_MY[_n+1] & End_MY>End_MY[_n+1]		// End>End(t+1). F_OVERLAP=2 CONCERNS END DATES
		by pidp (Spell), sort: replace F_Overlap=3 if _n<_N & Start_MY<Start_MY[_n+1] & End_MY<=End_MY[_n+1] & End_MY>Start_MY[_n+1] // End>Start(t+1)
		by pidp (Spell), sort: replace F_Overlap=4 if _n<_N & Start_MY>=Start_MY[_n+1] & End_MY>End_MY[_n+1] & Start_MY<End_MY[_n+1] // END AND START PROBLEMS
		noisily tab1 F_Overlap, missing
		by pidp (Spell), sort: gen F_Start_MY=cond(_n<_N,Start_MY[_n+1],.i)
		by pidp (Spell), sort: gen F_End_MY=cond(_n<_N,End_MY[_n+1],.i)
		by pidp (Spell), sort: gen F_Dataset=cond(_n<_N,Dataset[_n+1],.i)
		label values Dataset dataset
		noisily by F_Overlap, sort: tab2 Dataset F_Dataset, missing
		
		gen L_Overlap=0
		by pidp (Spell), sort: replace L_Overlap=1 if _n>1 & Start_MY>=Start_MY[_n-1] & End_MY<=End_MY[_n-1]	// End<=End(t-1). L_OVERLAP=1 CONCERNS END DATES.
		by pidp (Spell), sort: replace L_Overlap=2 if _n>1 & Start_MY<Start_MY[_n-1] & End_MY>End_MY[_n-1]		// START PROBLEM.
		by pidp (Spell), sort: replace L_Overlap=3 if _n>1 & Start_MY<Start_MY[_n-1] & End_MY<=End_MY[_n-1] & End_MY>Start_MY[_n-1]	// End<=End(t-1) AND START PROBLEM.
		by pidp (Spell), sort: replace L_Overlap=4 if _n>1 & Start_MY>=Start_MY[_n-1] & End_MY>End_MY[_n-1] & Start_MY<End_MY[_n-1]	// End(t-1)>Start.
		noisily tab1 L_Overlap if inlist(L_Overlap,1,3), missing
		by pidp (Spell), sort: gen L_Start_MY=cond(_n>1,Start_MY[_n-1],.i)
		by pidp (Spell), sort: gen L_End_MY=cond(_n>1,End_MY[_n-1],.i)
		by pidp (Spell), sort: gen L_Dataset=cond(_n>1,Dataset[_n-1],.i)
		label values Dataset dataset
		noisily by L_Overlap, sort: tab2 Dataset L_Dataset, missing
		
		count if (inrange(F_Overlap,1,4) & Dataset==F_Dataset) | (inrange(L_Overlap,1,4) & Dataset==L_Dataset)
		if `r(N)'>0{
			di in red "`r(N)' case where overlaps between spells are from same datasets. Should be zero"
			STOP
			}
		}
end

// prog_getvars IS A NEAT WAY OF GETTING VARIABLES FROM DIFFERENT DATA SOURCES BY ADDING RELEVANT PREFIXES TO A VARLIST OF JUST THE CORE PARTS OF VARIABLE NAMES.
capture program drop prog_getvars
program define prog_getvars
	args macro prefix file
	quietly describe using "`file'", varlist
	local varlist `r(varlist)'
	foreach v of global `macro'{
		local prefixlist "`prefixlist' `prefix'_`v' "
		}
	foreach v1 of local prefixlist{
		foreach v2 of local varlist{
			if "`v1'"=="`v2'"{
				local inlist "`inlist' `v1'"	
				}
			}
		}
	use pidp `inlist' using "`file'", clear
end

// prog_waveoverlap RESOLVES DATE OVERLAPS ACROSS SPELLS.
capture program drop prog_waveoverlap
program define prog_waveoverlap
	drop if Status==.m
	capture gen Wave=1
	if _rc==0 local drop "Wave"
	capture drop Spell
	by pidp (Start_MY End_MY), sort: gen Spell=_n
	by pidp (Wave Spell), sort: gen XX=max(Start_MY,End_MY[_n-1])
	by pidp (Wave Spell), sort: replace XX=XX[_n-1] if XX<XX[_n-1] & _n>1
	replace Start_MY=XX if XX>Start_MY
	drop if Start_MY>=End_MY
	by pidp (Start_MY End_MY), sort: replace Spell=_n
	drop XX `drop'
end

// prog_collapsespells COLLAPSES SPELLS.
// COMMENT: RECORDS A "New employer" FOR TRANSITIONS BETWEEN EMPLOYMENT AND NON-EMPLOYMENT OR BETWEEN EMPLOYMENT AND SELF-EMPLOYMENT. IT RECODES Status=100 AS Status=1/2 IF THE LATTER IS THE NEXT/PREVIOUS RECORDED STATUS AND EITHER SAME JOB OR NEW JOB, SAME EMPLOYER.
capture program drop prog_collapsespells
program prog_collapsespells
	by pidp (Spell), sort: replace Job_Change=3 /*	
		*/ if _n>1 & inlist(Status,1,2,100) & !inlist(Status[_n-1],1,2,100) /*
		*/ & Start_MY==End_MY[_n-1]													// 3. "New employer" IF EMPLOYED (t) AND NOT (t-1) AND End(t-1)==Start(t).
	by pidp (Spell), sort: replace Job_Change=3 /*	
		*/ if inlist(Status[_n+1],1,2) & inlist(Status,1,2) & Status!=Status[_n+1]	// 3. "New employer" IF EMPLOYED (t) AND (t+1) BUT Status CHANGED BETWEEN EMPLOYMENT AND SELF-EMPLOYMENT.
	by pidp (Spell), sort: replace Status=Status[_n+1] /*
		*/ if Status==100 & inlist(Status[_n+1],1,2) & inlist(Job_Change[_n+1],0,2)	// Status copied (Status(t) 100 CHANGED TO 1 OR 2 TO MATCH Status(t+1)) IF Job_Change(t+1) INDICATES EITHER SAME JOB OR NEW JOB, SAME EMPLOYER.
		
	gen Reverse=-Spell
	by pidp (Spell), sort: gen XX=1 /*
		*/ if Status==Status[_n+1] & Job_Hours==Job_Hours[_n+1] /*					// COMMENT: USE OF FT/PT JOB HOURS RENDERS prog_collapsespells RELATIVELY CONSERVATIVE, IN THAT IT ONLY COLLAPSES SPELLS WHERE THERE IS NO CHANGE IN RECORDED FT/PT STATUS.
		*/ & End_MY>=Start_MY[_n+1] & (inlist(Job_Change[_n+1],.i,0) | /*
		*/ (Job_Change==Job_Change[_n+1] & inlist(Job_Change,.m,4)) | /*
		*/ (Job_Change[_n+1]==.m & End_Ind==0)) 
	by pidp (Reverse), sort: replace XX=0 if XX[_n+1]==1
	replace XX=1 if XX==.

	by pidp (Spell), sort: gen YY=sum(XX)
	capture gen Wave=1
	if _rc==0 local Wave "Wave"
	foreach var of varlist End_Ind End_Flag End_MY `Wave' IntDate_MY{
		by pidp YY (Spell), sort: replace `var'=`var'[_N]
		}
	foreach var of varlist Source*{
		by pidp YY (Reverse), sort: /*
			*/ replace `var'=`var'+"; "+`var'[_n-1] /*
			*/ if _n>1 & strpos(`var'[_n-1],`var')==0
			}
	by pidp YY (Spell), sort: keep if _n==1
	
	sort pidp Spell
	order Source*, last
	format Source* %10s
	drop XX YY Reverse `Wave'
	by pidp (Spell), sort: replace Spell=_n
end

// prog_sort SORTS THE DATA pidp Wave *MY AND FORMATS *MY AS MONTHLY DATE VARIABLES.
capture program drop prog_sort
program define prog_sort
	order pidp Wave *MY
	format *MY %tm
end

// prog_makeage CREATES VARIABLE WHICH IS AGE AT RELEVANT DATE (E.G. OF START/END OF EDUCATION SPELL).
capture program drop prog_makeage
program define prog_makeage
	syntax varlist
	foreach var of varlist `varlist'{			
		capture drop `var'_Age
		gen `var'_Age=floor((`var'-Birth_MY)/12)
		label variable `var'_Age "Age(`var')"
		di char(10) "`var'_Age"
		tab `var'_Age
		}
end

capture program drop prog_sumedu
program define prog_sumedu
	qui{
	cls
	args var
	count if tag==1
	local N=`r(N)'
	
	gen AA=`var' if inlist(ivfio,1,3) 
	gen BB=floor((AA-Birth_MY)/12)
	gen CC=(!missing(BB))
	by pidp (Wave), sort: egen DD=sum(CC)
	by pidp CC (Wave), sort: gen EE=AA if CC==1 & _n==1
	by pidp CC (Wave), sort: gen FF=BB if CC==1 & _n==1
	by pidp (Wave), sort: egen GG=max(EE)
	by pidp (Wave), sort: egen HH=max(FF)
	gen II=floor((AA-GG)/12)
	by pidp (Wave), sort: egen JJ=max(abs(II))
	gen KK=`var' if inlist(ivfio,2) 
	gen LL=floor((KK-Birth_MY)/12)
	gen MM=(!missing(LL))
	by pidp (Wave), sort: egen NN=sum(MM)
	by pidp MM (Wave), sort: gen OO=KK if MM==1 & _n==1
	by pidp MM (Wave), sort: gen PP=LL if MM==1 & _n==1
	by pidp (Wave), sort: egen QQ=max(OO)
	by pidp (Wave), sort: egen RR=max(PP)
	gen SS=floor((KK-GG)/12)
	gen TT=floor((KK-QQ)/12)
	
	di in red ""
	di in red "Question 1: "
	count if DD==0 & NN==0  & tag==1
	local no1 `r(N)'
	di in red "`no1' of `N' pidps with 0 full interview or proxy observation for `var' (`=round(`no1'*100/`N',.01)'%)"
	di in red "Question 2: "
	count if DD==1 & tag==1
	local has1 `r(N)'
	di in red "`has1' of `N' pidps with 1 full interview observation for `var' (`=round(`has1'*100/`N',.01)'%)"
	di in red "Question 3: "
	count if DD>1 & tag==1
	local over1 `r(N)'
	di in red "`over1' of `N' pidps with 2+ full interview observation for `var' (`=round(`over1'*100/`N',.01)'%)"
	di in red "Question 4: "
	count if JJ>0 & !missing(JJ) & tag==1
	local diffans `r(N)'
	di in red "`diffans' of `over1' pidps with different answers for `var' (`=round(`diffans'*100/`over1',.01)'%)"
	di in red "HH: Age(`var') in first spell. II: Years difference from this in other waves."
	capture noisily tab HH II if DD>1  & II!=0
	if _rc!=0{
		noisily table HH II if DD>1  & II!=0
		}
	histogram II if II!=0, width(1)
	di in red "Question 5: "
	count if DD>=1 & NN>=1 & tag==1
	di in red "`r(N)' of `N' pidps have proxy and full-interview (`=round(`r(N)'*100/`N',.01)'%)"
	di in red "Question 6: "
	count if  DD>=1 & SS!=0
	local incon `r(N)'
	count if  DD>=1
	di in red "`incon' of `r(N)' observations with difference from original full-interview (`=round(`incon'*100/`r(N)',.01)'%)."
	di in red "HH: Age(`var') in first spell. OO: Years difference from this in proxy responses."
	capture noisily tab HH SS if DD>=1 & SS!=0
	if _rc!=0{
		noisily table HH SS if DD>=1 & SS!=0
		}
	di in red "Question 7: "
	count if DD==0 & NN>=1 & tag==1
	di in red "`r(N)' of `N' pidps have proxy only (`=round(`r(N)'*100/`N',.01)'%)"
	capture noisily tab RR SS if NN>=1 & DD==0 & SS!=0
	if _rc!=0{
		noisily table RR SS if NN>=1 & DD==0 & SS!=0
		}	
	
	drop AA-TT
	}
end

// prog_countsf COUNTS AND DISPLAYS THE NUMBERS OF OBSERVATIONS WHERE FTE IS MISSING AND WHETHER OTHER EDUCATION DATE VARIABLES ARE MISSING OR OBSERVED. 
capture program drop prog_countsf
program define prog_countsf
	qui{
	
	foreach i in FTE F S{
		global `i'_Missing /*
			*/ "missing(`i'_IN_MY) & missing(`i'_FIN_MY) & missing(`i'_NO_MY)"
		}	
		
	count if $FTE_Missing
	local N=`r(N)'
	di in red "FTE Missing: `r(N)' (`=round(100*`r(N)'/`N',.01)'%)"	
	count if $FTE_Missing & $F_Missing & $S_Missing
//	di in red "     S and F Missing: `r(N)' (`=round(100*`r(N)'/`N',.01)'%)"
	di in red "     WITH ALL S and ALL F Missing: `r(N)' (`=round(100*`r(N)'/`N',.01)'%)"
	di in red ""
	
	foreach i in IN FIN NO{
		count if !missing(S_`i'_MY) & $FTE_Missing & $F_Missing
//		di in red "     S_`i'_MY with F Missing: `r(N)' (`=round(100*`r(N)'/`N',.01)')%"
		di in red "     WITH S_`i'_MY PRESENT BUT ALL F Missing: `r(N)' (`=round(100*`r(N)'/`N',.01)')%"
		count if !missing(F_`i'_MY) & $FTE_Missing & $S_Missing
//		di in red "     F_`i'_MY with S Missing: `r(N)' (`=round(100*`r(N)'/`N',.01)'%)"
		di in red "     WITH F_`i'_MY PRESENT BUT ALL S Missing: `r(N)' (`=round(100*`r(N)'/`N',.01)'%)"
		}
	di in red ""
		
	foreach i in IN FIN NO{		
		foreach j in IN FIN NO{
			count if !missing(S_`i'_MY,F_`j'_MY) & $FTE_Missing
//			di in red "     S_`i'_MY & F_`j'_MY: `r(N)' (`=round(100*`r(N)'/`N',.01)'%)"
			di in red "     WITH S_`i'_MY & F_`j'_MY PRESENT: `r(N)' (`=round(100*`r(N)'/`N',.01)'%)"
			}
		}
	}
end

// prog_makecombos CREATES GLOBALS (EDUC DATES, IF CLAUSE), AGE AT EDUCATION DATE, TABULATES EDUCATION DATES AND RELEVANT AGES, AND COUNTS OBS, IF FTE DATES ARE MISSING.
capture program drop prog_makecombos
program define prog_makecombos
	args i j
	global i "`i'"
	global j "`j'"
	global if "!missing($i,$j) & (missing(FTE_IN_MY) & missing(FTE_FIN_MY) & missing(FTE_NO_MY))"
	quietly prog_makeage $i $j
	capture noisily tab ${i}_Age ${j}_Age if $if
	if _rc>0{
		table  ${i}_Age ${j}_Age if $if
		}
	count if $if
	capture drop XX
	gen XX=($if)
end

// prog_lhcombos DIFFERS FROM prog_makecombos IN PART IN FOCUSING ON OBSERVED FTE DATES (RATHER THAN CASES WHERE FTE DATES ARE MISSING). USING LIFE HISTORY EDUCATION DATES AND COMPARING WITH CALCULATED-SO-FAR FTE DATES, IT CREATES GLOBALS (EDUC DATES, IF CLAUSE), AGE AT EDUCATION DATE, TABULATES LH AGE AGAINST FTE AGE AND AGAINST DIFFERENCE BETWEEN LH AND FTE AGE, AND COUNTS OBS WHERE BOTH LH AND FTE DATES ARE OBSERVED.
capture program drop prog_lhcombos
program define prog_lhcombos
	args i j
	global i "`i'"
	global j "`j'"
	global if "!missing(LH_${i}_MY) & !missing(FTE_${j}_MY)"	
	
	capture drop YY
	capture drop *Age
	quietly prog_makeage LH_${i}_MY FTE_${j}_MY
	quietly gen YY=LH_${i}_MY_Age-FTE_${j}_MY_Age
	label variable YY "Difference between LH_${i} & FTE_${j}"
	capture drop XX
	gen XX=($if)
	
	table LH_${i}_MY_Age FTE_${j}_MY_Age if $if & strpos(FTE_${j}_Source,"LH")==0
	table LH_${i}_MY_Age YY
	count if $if
end

// prog_ageremain GENERATES EDUCATION-RELATED AGE INCLUDING AGE LEFT FTE.
capture program drop prog_ageremain
program define prog_ageremain
	args i
	local j=substr("`i'",1,1)
	if "`j'"=="S"	local j "F"
	else local j "S"
	global i "`i'"
	global if "$FTE_Missing & ${`j'_Missing}"
	quietly prog_makeage $i
	capture noisily tab ${i}_Age if $if
	capture drop XX
	gen XX=($if)
end

// prog_addprefix IS USED TO COLLECT VARIABLES FROM DIFFERENT RAW DATA FILES THAT REQUIRE DIFFERENT PREFIXES. THIS PROGRAM ATTACHES THE RELEVANT PREFIX TO THE BASIC VARIABLE NAME.
capture program drop prog_addprefix
program define prog_addprefix
	args macro prefix file
	local prelist: subinstr global `macro' " " " `prefix'_", all
	qui des using "`file'", varlist
	local vlist `r(varlist)'
	local inlist: list prelist & vlist
	use pidp `inlist' using "`file'", clear
end

// prog_monthsafterint CALCULATES MONTHS AFTER INTERVIEW AND DISPLAYS TABULATED DATA.
capture program drop prog_monthsafterint
program define prog_monthsafterint
	args var
	tempvar XX
	quietly gen `XX'=`var'-IntDate_MY
	label variable `XX' "Months After Interview"
	di in red ""
	di in red "`var':"
	noisily tab `XX' if `XX'>0
	global if "`var'>IntDate_MY & !missing(`var',IntDate_MY)"	
	macro list if
end

// prog_chooseob REPORTS THE % OF CASES WHERE SCHOOL/FE FINISH DATES VARY ACROSS WAVES/SOURCES. SELECTS MIN (EARLIEST) EDUCATION END DATE. SELECTS MAX (LATEST) DATE OF CONTINUING OR NO EDUCATION.
capture program drop prog_chooseob
program define prog_chooseob
	args stub
	qui{
	tempfile Temp
	
	foreach i in FIN IN NO{
	
	capture confirm variable `stub'_`i'_MY
	if _rc==0{
	preserve
		keep if !missing(`stub'_`i'_MY)		
		capture drop `stub'_`i'_MY_Age
		
		gen `i'=.
		tempvar Wave
		gen `Wave'=`stub'_`i'_Wave
		
		if "`i'"=="FIN"{
			local function "min"
			local if "& inrange(BB-CC,0,12)==1"
			local drop "AA BB CC"
			}
		else{
			local function "max"
			local if ""
			local drop ""
			}
			
		forval j=1/2{

			if `j'==1 & "`i'"=="FIN"{		
				local source "Full Interview"
				}
			else if `j'==2 & "`i'"=="FIN"{
				local source "Proxy Interview"
				}
			else if `j'==1 & "`i'"!="FIN"{
				local source "Interview"
				}
			else if `j'==2 & "`i'"!="FIN"{
				continue
				}
				
			by pidp (`Wave'), sort: gen XX=_n /*
				*/ if !missing(`stub'_`i'_MY) /*
				*/ & strpos(`stub'_`i'_Source,"`source'")>0
			by pidp (`Wave'), sort: egen YY=`function'(XX)							// BY pidp Wave THIS SELECTS *min* `stub'_`i'_Wave AT WHICH EDUC FINISHED. SELECTS *max* `stub'_`i'_Wave AT WHICH STILL IN EDUC OR WITH "NO EDUC".
			by pidp (`Wave'), sort: gen ZZ=`stub'_`i'_MY[YY]
			
			if "`i'"=="FIN"{
				
				gen AA=`stub'_`i'_MY if strpos(`stub'_`i'_Source,"`source'")>0
				by pidp (`Wave'), sort: egen BB=max(AA)								// THIS SELECTS MAX FIN DATE by pidp Wave.
				by pidp (`Wave'), sort: egen CC=min(AA)								// THIS SELECTS MIN FIN DATE by pidp Wave.
				
				count if tag==1
				local N=`r(N)'
				count if tag==1 & inrange(BB-CC,0,12)!=1 & !missing(ZZ)
				local n=`r(N)'
				local p=round((`n'*100)/`N',.01)
				di in red "`source': `r(N)' pidps with varying FIN dates (`p'%)"	// THIS ANALYSES HOW MANY (AND %) pidpS WITH MULTIPLE/VARYING FIN DATES, USING ALL DATA.
				}
			
			replace `stub'_`i'_Source="`source'" /*
				*/ if missing(`i') & !missing(ZZ) `if'
			by pidp (`Wave'), sort: replace `stub'_`i'_Wave=`stub'_`i'_Wave[YY] /*
				*/ if missing(`i') & !missing(ZZ) `if'
			by pidp (`Wave'), sort: replace `stub'_`i'_Qual=`stub'_`i'_Qual[YY] /*
				*/ if missing(`i') & !missing(ZZ) `if'
			replace `i'=ZZ if missing(`i') & !missing(ZZ) `if'
			
			drop XX YY ZZ `drop'
			}
			
		replace `stub'_`i'_MY=`i'
		prog_scrubvars `stub'_`i'
		
		keep pidp `stub'_`i'_*
		duplicates drop
		save "`Temp'", replace
		
	restore
	drop `stub'_`i'_*
	merge m:1 pidp using "`Temp'", nogen
	
		}
		}
		}
end

// prog_scrubvars CREATES MISSING Source, Wave, Qual RELATED TO DATES (E.G. EDUCATION DATES).
capture program drop prog_scrubvars
program define prog_scrubvars
	args stub
	ds `stub'*MY
	local vlist `r(varlist)'
	foreach i of local vlist{
		local j=subinstr("`i'","_MY","",.)
		capture replace `j'_Source="" if missing(`i')
		capture replace `j'_Wave=. if missing(`i')
		capture replace `j'_Qual=. if missing(`i')
		}
end

// prog_makevars GENERATES Source, Wave, Qual[IFICATIONS] (LABELLED) FOR EDUCATION START/END DATES.
// USED IN "FTE Variables - Collect.do" AN EXAMPLE OF ITS USE (S=SCHOOL, F=FE, 1=INDICATOR OF THE SOURCE VARIABLE(S) I.E. THE RELEVANT SAMPLE) IS:
//foreach i in S F{
//	prog_makevars `i'_1_FIN `i'_1_IN `i'_1_NO
//	}
capture program drop prog_makevars
program define prog_makevars
	while "`*'"!=""{
		local stub "`1'"
		macro shift 1	
		local if "if !missing(`stub'_MY)"
		gen `stub'_Source=/*
				*/ cond(inlist(ivfio,1,3),"Full Interview","Proxy Interview") `if' 
		gen `stub'_Wave=Wave `if'
		gen `stub'_Qual=hiqual_dv `if'
		local lab: value label hiqual_dv
		label values `stub'_Qual `lab'
		}
end

capture program drop prog_ftetables
program define prog_ftetables
	args stub
	quietly{
	foreach j in S F{		
		local k="`j'`stub'"		
		capture confirm variable `k'_FIN_MY
		if _rc>0{
			continue
			}
		
		if "`j'"=="S"{
			local if "& missing(F`stub'_FIN_MY_Age)"
			}
		else{
			local if ""
			}	
		
		gen PropWithinYear=inrange(LH_FIN_MY_Age-`k'_FIN_MY_Age,-1,1) /*
			*/ if !missing(LH_FIN_MY_Age,`k'_FIN_MY_Age) `if'
		gen MeanAbsDiff=abs(LH_FIN_MY_Age-`k'_FIN_MY_Age) /*
			*/ if !missing(LH_FIN_MY_Age,`k'_FIN_MY_Age) `if'
		noisily table `k'_FIN_MY_Age if `k'_FIN_MY_Age<30 `if', /*
			*/ contents(n PropWithinYear mean PropWithinYear mean MeanAbsDiff) /*
			*/ center format(%9.2f)
		foreach l in "n PropWithinYear" "mean PropWithinYear" /*
			*/ "mean MeanAbsDiff"{
			capture noisily table `k'_FIN_Qual `k'_FIN_MY_Age /*
				*/ if `k'_FIN_MY_Age<30 & `k'_FIN_Qual>0 `if', /*
				*/ contents(`l') /*
				*/ center format(%9.2f)
			}
		drop PropWithinYear MeanAbsDiff
		}
	}
end

capture program drop prog_spellbounds
program define prog_spellbounds
	args LB UB Start End
	capture drop Start End Interval FullPeriod
	gen Start=max(`Start',`LB') if !missing(`Start') & !missing(`LB')
	gen End=min(`End',`UB') if !missing(`End') & !missing(`UB')
	tempvar v1 v2 v3
	by pidp (Spell), sort: egen `v1'=min(Start)
	by pidp (Spell), sort: egen `v2'=max(End)
	gen `v3'=1 if Start>=End | `v1'>`LB' | `v2'<`UB'
	replace Start=. if `v3'==1
	replace End=. if `v3'==1
	gen Interval=End-Start
	gen FullPeriod=(`v1'<=`LB' & `v2'>=`UB' & !missing(`LB',`UB'))
end

// prog_cleaneduhist DOES NOT DROP CASES WITH IMPLAUSIBLE START DATES.
capture program drop prog_cleaneduhist				// CLEAN EDUCATION HISTORY.
program define prog_cleaneduhist
	gen Status=7
	gen Source="eduhist_w"+strofreal(Wave)
	gen Job_Hours=.i
	gen Job_Change=.i
	capture drop Spell
	by pidp (Start_MY End_MY), sort: gen Spell=_n
	gen Dataset=Spell								// Dataset IS USED IN prog_overlap: THE IDEA IS THAT SPELLS SHOULD NOT OVERLAP WITHIN A Dataset. USING Spell AS A DATASET JUST ALLOWS CHECKING OF CONTEMPORANEOUS AND CONTIGUOUS SPELL START AND END DATES.
	prog_overlap
	drop if L_Overlap==1							// L_Overlap=1 if _n>1 & Start_MY>=Start_MY[_n-1] & End_MY<=End_MY[_n-1] THIS LINE DROPS SUBSUMED SPELLS, WHICH IS OK AS NONE INVOLVE OVERWRITING A COMPLETED FTE END DATE.
	drop F_* L_* Dataset
	prog_collapsespells
	
	foreach var in Start End{
		gen `var'_Y=year(dofm(`var'_MY))
		}
	merge m:1 pidp Wave using "${dta_fld}/Interview Grid", /*
		*/ nogenerate keep(match master) keepusing(Birth_Y)
	prog_implausibledates Start						// THIS LINE APPLIES prog_implausibledates TO START DATES. THAT PROGRAM DROPS EDUCATION DATES STARTING BEFORE BIRTH.
	by pidp Wave (Spell), sort: replace Spell=_n
	gen Status_Spells=1
	drop *_Y
	
	prog_attrend									// prog_attrend RELATES TO Job_Attraction AND End_Reason. 
end


capture program drop prog_overwritespell
program define prog_overwritespell
	args if Spell Start_MY End_MY Start_Flag End_Flag Source Status
	
	replace Source_Variable="N/A" if `if'
	replace Job_Hours=.i if `if'
	replace Job_Change=.i if `if'
	replace Status_Spells=1 if `if'	
	replace IntDate_MY=.i if `if'
	foreach i of varlist End_Reason* Job_Attraction*{
		replace `i'=.i if `if'
		}
	
	foreach i of varlist Spell Start_MY End_MY Start_Flag End_Flag Source Status{
		replace `i'=``i'' if `if'
		}
end

// prog_sytomy (NEEDED FOR prog_monthfromseason) TRANSLATES SY CODES 1,2,3,4,5 INTO MONTHS: 5=LATE WINTER(Dec)=12 ALWAYS; 1=EARLY WINTER(Jan-Feb)=1 OR 2; 2=SPRING(Mar-May)=3/4/5; 3=SUMMER(Jun-Aug)=6,7,8; 4=AUTUMN(Sep-Nov)=9,10,11. ARGUMENT IN prog_sytomy AFTER MY SY DETERMINES THE CHOICE AMONG THESE ALTERNATIVES, USING WORD "Lower","Middle","Upper" RESPECTIVELY (EARLY WINTER BEING Jan=1 UNLESS "Upper").  
capture program drop prog_sytomy
program define prog_sytomy
	args MY SY Bound
	if "`Bound'"=="Lower"{
		replace `MY'=ym(year(dofm(`SY')), /*
			*/ cond(month(dofm(`SY'))==1,1, /*
			*/ cond(month(dofm(`SY'))==2,3, /*
			*/ cond(month(dofm(`SY'))==3,6, /*
			*/ cond(month(dofm(`SY'))==4,9,12)))))
			}
	if "`Bound'"=="Middle"{
		replace `MY'=ym(year(dofm(`SY')), /*
			*/ cond(month(dofm(`SY'))==1,1, /*
			*/ cond(month(dofm(`SY'))==2,4, /*
			*/ cond(month(dofm(`SY'))==3,7, /*
			*/ cond(month(dofm(`SY'))==4,10,12)))))
			}
	if "`Bound'"=="Upper"{
		replace `MY'=ym(year(dofm(`SY')), /*
			*/ cond(month(dofm(`SY'))==1,2, /*
			*/ cond(month(dofm(`SY'))==2,5, /*
			*/ cond(month(dofm(`SY'))==3,8, /*
			*/ cond(month(dofm(`SY'))==4,11,12)))))
			}
end

// prog_range CREATES MaxBelow AND MinAbove LOWER AND UPPER BOUNDS, AND Gap (THE DISTANCE BETWEEN THEM).
capture program drop prog_range
program define prog_range
	capture drop Gap
	capture drop Reverse
	capture drop MaxBelow* MinAbove*
	gen Reverse=-Spell
	foreach i in Y MY{
		foreach j in MaxBelow_`i' MinAbove_`i'{
			local sort=cond("`j'"=="MaxBelow_`i'","Spell","Reverse")
		
			gen `j'=Start_`i'
			by pidp Wave (`sort'), sort: replace `j'=`j'[_n-1] /*
				*/ if missing(`j')
			}
		
		replace MinAbove_`i'=IntDate_`i' if missing(MinAbove_`i')
		if "`i'"=="MY"{
			replace MaxBelow_MY=max(MaxBelow_MY,ym(MaxBelow_Y,1))
			replace MinAbove_MY=min(MinAbove_MY,ym(MinAbove_Y,12))
			}
		
		if "`i'"=="Y"	local missingdates=1
		if "`i'"=="MY"	local missingdates=0
		gen XX=1 if MinAbove_`i'==MaxBelow_`i' & missing(Start_`i')
		replace Start_`i'=MinAbove_`i' if XX==1
		replace MissingDates=`missingdates' if XX==1
		drop XX	
		}	
	gen Gap=MinAbove_MY-MaxBelow_MY
	format *MY %tm
	sort pidp Wave Spell
	drop Reverse
end

// prog_missingdates GENERATES VARIABLE MissingDates WHICH FLAGS MISSING 1 MONTH & YEAR, 2 YEAR, OR 0 NEITHER MONTH OR YEAR.
capture program drop prog_missingdates
program define prog_missingdates
	capture drop MissingDates
	gen MissingDates=0
	replace MissingDates=1 if missing(Start_MY)
	replace MissingDates=2 if missing(Start_Y)
end

// prog_format MAKES VARIABLES LOOK NICE AND DOES VARIABLE LABELLING THAT IS USEFUL AS ONE GOES ALONG. BHPS DATA DOES NOT CONTAIN Status VALUES 12,13 BUT THEY ARE INCLUDED IN THIS PROGRAM AS IT IS THEN USABLE FOR BOTH BHPS AND UKHLS DATA.
capture program drop prog_format
	program define prog_format
	
	labelbook
	if "`r(names)'"!=""	label drop `r(names)'
	compress

	#delimit ;
	local vlist "pidp Wave Spell Status Start_MY End_MY Job_Hours
				Job_Change *Flag IntDate_MY End_Ind Status_Spells End_Reason*
				Job_Attraction* Source*";
	#delimit cr
	keep `vlist'
	order `vlist'

//	do "${do_fld}/Labels.do"
//	do "${do_fld}/Apply Labels"
	do "${do_fld}/Labels_JCS.do"
	do "${do_fld}/Apply Labels_JCS"
	foreach var of varlist Status *Flag Job_Hours Job_Change{
		label values `var' `=lower("`var'")'
		}
	ds pidp Source*, not							// ds [varlist], not  :  lists variables NOT specified in varlist
	format `r(varlist)' %9.0g
	format *MY %tm
	format Source* %12s

//	foreach var of varlist Job_* End_Reason* {		// THIS SEEMS TO REPEAT prog_attrend SO IS NOT USED. IF IT WERE, USE (Status,1,2,12,13,100). SECOND LINE IS CONFUSING: HOW Status CAN BOTH HAVE A VALUE AND BE MISSING?
//		replace `var'=.i if !inlist(Status,1,2,100)
//		replace `var'=.m if inlist(Status,1,2,100) & missing(Status)
// COMMENT (REPEATED IN prog_attrend): IN EDUCATION HISTORY FILES, prog_attrend DEFINES End_Reason AND Job_Attraction IN CIRCUMSTANCES WHERE IT IS NOT RELEVANT (BECAUSE EMPLOYED) AS .m, AND OTHERWISE AS .i, WHICH IS CORRECT IN EDUCATION-RELATED .do FILES WHERE STATUS==7 (FTE).

*/
	label data ""
end
//
// LIAM WRIGHT ORIGINAL prog_format
// 
/*
capture program drop prog_format
	program define prog_format
	
	labelbook
	if "`r(names)'"!=""	label drop `r(names)'
	compress

	#delimit ;
	local vlist "pidp Wave Spell Status Start_MY End_MY Job_Hours
				Job_Change *Flag IntDate_MY End_Ind Status_Spells End_Reason*
				Job_Attraction* Source*";
	#delimit cr
	keep `vlist'
	order `vlist'

	do "${do_fld}/Labels.do"
	do "${do_fld}/Apply Labels"
	foreach var of varlist Status *Flag Job_Hours Job_Change{
		label values `var' `=lower("`var'")'
		}
	ds pidp Source*, not
	format `r(varlist)' %9.0g
	format *MY %tm
	format Source* %10s

	foreach var of varlist Job_* End_Reason*{
		replace `var'=.i if !inlist(Status,1,2,100)
		replace `var'=.m if inlist(Status,1,2,100) & missing(Status)
		}
	label data ""
end
*/

// prog_attrend DEFINES End_Reason AND Job_Attraction IN CIRCUMSTANCES WHERE IT IS NOT RELEVANT (BECAUSE EMPLOYED) AS .m, AND OTHERWISE AS .i, WHICH IS CORRECT IN EDUCATION-RELATED .do FILES WHERE STATUS==7 (FTE).
capture program drop prog_attrend
program define prog_attrend
	foreach i of numlist 1/15 97{
		if !inrange(`i',12,15){
//			gen End_Reason`i'=cond(inlist(Status,1,2,100),.m,.i)
			gen End_Reason`i'=cond(inlist(Status,1,2,12,13,100,112,113,212,213,10012,10013),.m,.i)
			}
//		gen Job_Attraction`i'=cond(inlist(Status,1,2,100),.m,.i)
		gen Job_Attraction`i'=cond(inlist(Status,1,2,12,13,100,112,113,212,213,10012,10013),.m,.i)
		}

end

// prog_monthfromseason. USES prog_sytomy WHICH CHOOSES BETWEEN MONTHS OF A SEASON TO GENERATE MONTHLY DATES.
capture program drop prog_monthfromseason
program define prog_monthfromseason
	prog_imputeequaldates Y SY MY			// prog_imputeequaldates IMPUTES START/END DATE AS MaxBelow/MinAbove IF MaxBelow==MinAbove, AND CALLS prog_daterange WHICH SETS MinAbove and MaxBelow, WITHIN pidp-Wave, AS NEAREST START/END DATE ABOVE/BELOW, OR INTERVIEW DATE IF MinAbove FROM  NEXT SPELL START/END DATE IN THAT pidp-Wave IS MISSING

	gen Reverse=-Spell

	foreach i in MinAbove MaxBelow{
		local sortby=cond("`i'"=="MinAbove","Reverse","Spell")		// `sortby' IS `sort' IN LIAM WRIGHT CODE.
		local bound=cond("`i'"=="MinAbove","Upper","Lower")
		local function=cond("`i'"=="MinAbove","min","max")
		local list=cond("`i'"=="MinAbove",",IntDate_MY","")

		gen `i'=Start_MY
		by pidp Wave (`sortby'), sort: replace `i'=`i'[_n-1] if missing(`i')
		gen XX=.
		prog_sytomy XX Start_SY `bound'		// prog_sytomy TRANSLATES SY CODES 1,2,3,4,5 INTO MONTHS AS FOLLOWS: 5=LATE WINTER(Dec)=12 ALWAYS; 1=EARLY WINTER(Jan-Feb)=1/2; 2=SPRING(Mar-May)=3/4/5; 3=SUMMER(Jun-Aug)=6/7/8; 4=AUTUMN(Sep-Nov)=9/10/11. ARGUMENT IN prog_sytomy AFTER MY SY DETERMINES THE CHOICE AMONG THESE ALTERNATIVES, USING WORD "Lower","Middle","Upper" RESPECTIVELY (EARLY WINTER BEING Jan=1 UNLESS "Upper"). 
		replace `i'=`function'(`i',XX`list')
		drop XX
		}

	by pidp Wave MaxBelow MinAbove (Spell), sort: /*
		*/ gen XX=floor(MaxBelow+((MinAbove-MaxBelow)*_n/(_N+1)))
	replace Start_Flag=6 if missing(Start_MY) & !missing(Start_SY) & !missing(XX)	
	replace Start_MY=XX if missing(Start_MY) & !missing(Start_SY) & !missing(XX)	
	drop XX	Reverse
end
