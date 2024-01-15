/*
********************************************************************************
CLEAN WORK HISTORY.DO
	
	THIS FILE MODIFIES WORK HISTORIES WHICH HAVE START AND END Y, SY, AND MY AND END
	INDICATORS.

	UPDATES: 
	* APPLIES TO BHPS LIFE HISTORY DATA ONLY: CORRECTION OF NON-CHRONOLOGICAL DATES TO RETAIN DATA WHERE POSSIBLE, IF nonchron_correct "Y" OPTION IS CHOSEN. 
	* APPLIES TO UKHLS DATA AND IF nonchron_correct "Y" OPTION IS NOT CHOSEN: DROPS ALL DATA FOR ANY pidp AFFECTED BY NON-CHRONOLOGICAL DATES.
	* NEW CODE APPLYING ONLY TO A VARIANT OF UKHLS DATA THAT FOCUSES ON FURLOUGH SPELLS CORRECT START DATES IN A SMALL NUMBER OF CASES WHERE AN IMPUTED FURLOUGH START DATE IS IMPLAUSIBLE.
	* A SPECIFIC PROGRAM TO DEAL WITH MISSING LAST SPELLS IS CALLED HERE FOR THE FURLOUGH VARIANT OF UKHLS ANNUAL HISTORY DATA. 
	
	* LW VERSION USES THE OPTION "$nonchron_correct"!="Y".
	
********************************************************************************
*/


*1. Collapse into single spell
prog_missingdates
gen XX=0
replace XX=1 if MissingDates==0										// MissingDates FLAGS MISSING 0 NEITHER MONTH OR YEAR, 1 MONTH & YEAR, 2 YEAR.
by pidp Wave (Spell), sort: replace XX=1 /*
  */ if _n==1
by pidp Wave (Spell), sort: replace XX=1 /*
  */ if Status!=Status[_n-1] | Job_Hours!=Job_Hours[_n-1]			// NOTE: Job_Hours!=Job_Hours[_n-1] WILL DEFINE A NEW Status_Spell IF THERE IS A CHANGE BETWEEN FT AND PT.
by pidp Wave (Spell), sort: gen Status_Spell=sum(XX)

by pidp Wave Status_Spell (Spell), sort: gen YY=_n if MissingDates==1
by pidp Wave Status_Spell (Spell), sort: egen ZZ=min(YY)
by pidp Wave Status_Spell (Spell), sort: replace XX=1 if ZZ==_n & MissingDates[1]==2
by pidp Wave (Spell), sort: replace Status_Spell=sum(XX)

by pidp Wave Status_Spell (Spell), sort: gen Status_Spells=_N
drop XX YY ZZ

prog_range
count if Status_Spells>1
if `r(N)'>0{		
preserve
	keep if Status_Spells>1

	by pidp Wave Status_Spell (Spell), sort: replace End_Ind=End_Ind[_N]
	by pidp Wave Status_Spell (Spell), sort: /*
		*/ replace Job_Change=cond(inlist(Status,1,2,100),4,.i)		// COMMENT: Status 12, 13 NOT INCLUDED HERE ON THE GROUNDS THAT Job_Change "4. (Possible) multiple jobs" IS NOT APPLICABLE TO FURLOUGH/TEMPORARY LAYOFF/SHORT-TIME WORKING.
	by pidp Wave Status_Spell (Spell), sort: /*
		*/ gen XX=max(ym(Start_Y,1),Start_MY)
	by pidp Wave Status_Spell (Spell), sort: /*
		*/ egen MinEnd_MY=max(XX)
	by pidp Wave Status_Spell (Spell), sort: /*
		*/ replace MinEnd_MY=max(MinEnd,MaxBelow_MY,ym(MaxBelow_Y,1))	
	drop XX

	gen Reverse=-Spell
	foreach var of varlist Source*{
		by pidp Wave Status_Spell (Reverse), sort: /*
			*/ replace `var'=`var'+"; "+`var'[_n-1] /*
			*/ if _n>1 & strpos(`var'[_n-1],`var')==0
		}	
	foreach var of varlist End_Reason* Job_Attraction*{
		by pidp Wave Status_Spell (Spell), sort: egen XX=sum(`var')
		by pidp Wave Status_Spell (Spell), sort: egen YY=sum(missing(`var'))
		replace `var'=XX if YY<Status_Spells
		replace `var'=.i if !inlist(Status,1,2,100) & `var'!=.i		// COMMENT: NO End_Reason OR Job_Attraction FOR Status 12,13, SO IT IS CORRECT THAT THESE VARIABLES ARE SET TO .i FOR THOSE StatusES.
		replace `var'=.m if inlist(Status,1,2,100) & missing(`var')
		drop XX YY		
		}
	by pidp Wave Status_Spell (Spell), sort: drop if _n>1
	drop Reverse
	tempfile Temp
	save "`Temp'", replace
restore
}
	
drop if Status_Spells>1
if "`Temp'"!=""{
	append using "`Temp'"
	recode MinEnd_MY (missing=.m)
	}
by pidp Wave (Spell), sort: replace Spell=_n
drop Status_Spell MinAbove* MaxBelow* Gap


* 2. Impute dates if less than tolerated gap length
prog_imputeequaldates Y MY
prog_missingdates
forval i=1/2{
	prog_range
	if `i'==1{
		gen XX=1 if inrange(Gap,1,$gap_length) & MissingDates==1
		}
	else if `i'==2{
		by pidp Wave (Spell), sort: gen XX=1 /*
			*/ if inrange(Gap,1,$gap_length) & MissingDates==2 /*
			*/ & MinAbove_MY[_n-1]<=MaxBelow_MY
		by pidp Wave MinAbove_MY MaxBelow_MY (Spell), sort: replace XX=XX[1]
		}

	by pidp Wave MinAbove_MY MaxBelow_MY (Spell), sort: gen YY=sum(Status_Spells)
	by pidp Wave MinAbove_MY MaxBelow_MY (Spell), sort: gen n=cond(_n==1,1,YY[_n-1]+1)
	by pidp Wave MinAbove_MY MaxBelow_MY (Spell), sort: gen N=(YY[_N])

	replace Start_Flag=3 if XX==1 
	by pidp Wave MinAbove_MY MaxBelow_MY (Spell), sort: replace Start_MY=floor( /*
		*/ MaxBelow_MY+(n*(MinAbove_MY-MaxBelow_MY)/(N+1))) /*
		*/ if XX==1
	drop XX YY n N
	}

replace Start_Y=year(dofm(Start_MY)) if !missing(Start_MY)
prog_range
prog_missingdates

* NEW CODE APPLYING ONLY TO A VARIANT OF UKHLS DATA THAT FOCUSES ON FURLOUGH SPELLS (INDIDATED BY CODING THAT REFLECTS BOTH UNDERLYING EMPLOYMENT STATUS AND FURLOUGH STATUS) 
* THESE 2 LINES OF CODE CORRECT START DATES FOR A SMALL NUMBER OF CASES WHERE AN IMPUTED FURLOUGH START DATE IS IMPLAUSIBLE.
replace Start_MY = tm(2020mar) if inlist(Status,112,113,212,213,10012,10013) & Start_MY<tm(2020mar) & IntDate_MY>=tm(2020mar)
replace Start_Y = 2020 if inlist(Status,112,113,212,213,10012,10013) & Start_Y<2020 & IntDate_Y>=2020


* 3. Create Indicator to Drop Spell after Truncation
gen DropSpell=0
by pidp Wave (Spell), sort: replace DropSpell=1 /*
	*/ if MissingDates==1 & MissingDates[_n+1]==1 /*
	*/ & Start_Y==Start_Y[_n+1]
by pidp Wave (Spell), sort: replace DropSpell=1 /*
	*/ if MissingDates==1 & MissingDates[_n+1]==2
by pidp Wave (Spell), sort: replace DropSpell=1 /*
	*/ if MissingDates==2 & MissingDates[_n+1]>0 /*
	*/ & _n<_N
by pidp Wave (Spell), sort: replace DropSpell=1 /*
	*/ if MissingDates==2 & _n==_N & End_Ind!=0
by pidp Wave (Spell), sort: replace DropSpell=1 /*
	*/ if MissingDates==1 & _n==_N & End_Ind!=0

	
* 4. Truncate Start Dates where gap greater than tolerance
	*a. Set Start_MY=Start_MY[_n+1]-1
by pidp Wave (Spell), sort: gen XX=Start_MY[_n+1]-1 /*
	*/ if MissingDates==2 & MissingDates[_n+1]==0 /*
	*/ & (Start_MY[_n+1]-1>=MaxBelow_MY | _n==1)
replace Start_MY=XX if !missing(XX)
replace Start_Flag=5 if !missing(XX)
drop XX	

by pidp Wave (Spell), sort: replace Start_MY=Start_MY[_n+1]-1 /*
	*/ if MissingDates==1 & MissingDates[_n+1]==0 /*
	*/ & Start_MY[_n+1]-1>=MaxBelow_MY /*
	*/ & Start_Y==Start_Y[_n+1] & month(dofm(Start_MY[_n+1]))>1

	*b. Set Start_MY=Start_MY[_n+1]
by pidp Wave (Spell), sort: replace Start_MY=Start_MY[_n+1] /*
	*/ if MissingDates==2 & MissingDates[_n+1]==0 /*
	*/ & Start_MY[_n+1]==MaxBelow_MY
by pidp Wave (Spell), sort: replace Start_MY=Start_MY[_n+1] /*
	*/ if MissingDates==1 & MissingDates[_n+1]==0 /*
	*/ & Start_MY[_n+1]==MaxBelow_MY
by pidp Wave (Spell), sort: replace Start_MY=Start_MY[_n+1] /*
	*/ if MissingDates==1 & MissingDates[_n+1]==0 /*
	*/ & Start_Y==Start_Y[_n+1] & month(dofm(Start_MY[_n+1]))==1
	
	*c. Set Start_MY=IntDate_MY-1
by pidp Wave (Spell), sort: gen XX=IntDate_MY-1 /*
	*/ if MissingDates==2 & _n==_N & End_Ind==0 /*
	*/ & IntDate_MY-1>=MaxBelow_MY
replace Start_MY=XX if !missing(XX)
replace Start_Flag=5 if !missing(XX)
drop XX		

by pidp Wave (Spell), sort: replace Start_MY=IntDate_MY-1 /*
	*/ if MissingDates==1 & _n==_N & End_Ind==0 /*
	*/ & IntDate_MY-1>=MaxBelow_MY /*
	*/ & Start_Y==IntDate_Y & month(dofm(IntDate_MY))>1

	*d. Set Start_MY=IntDate_MY
by pidp Wave (Spell), sort: replace Start_MY=IntDate_MY /*
  */ if MissingDates==2 & _n==_N & End_Ind==0 /*
  */ & IntDate_MY==MaxBelow_MY
by pidp Wave (Spell), sort: replace Start_MY=IntDate_MY /*
  */ if MissingDates==1 & _n==_N & End_Ind==0 /*
  */ & IntDate_MY==MaxBelow_MY
by pidp Wave (Spell), sort: replace Start_MY=IntDate_MY /*
  */ if MissingDates==1 & _n==_N & End_Ind==0 /*
  */ & Start_Y==IntDate_Y & month(dofm(IntDate_MY))==1

	*e. Set Start_MY=ym(Start_Y,12)
by pidp Wave (Spell), sort: gen XX=ym(Start_Y,12) /*
  */ if MissingDates==1 & MissingDates[_n+1]<2 /*
  */ & Start_Y<Start_Y[_n+1]
replace Start_MY=XX if !missing(XX)
replace Start_Flag=4 if !missing(XX)
drop XX			
	
by pidp Wave (Spell), sort: gen XX=ym(Start_Y,12) /*
  */ if MissingDates==1 & _n==_N & End_Ind==0 /*
  */ & Start_Y<IntDate_Y
replace Start_MY=XX if !missing(XX)
replace Start_Flag=4 if !missing(XX)
drop XX	

replace Start_Y=year(dofm(Start_MY)) if !missing(Start_MY)


* 5. Create End Dates
gen End_MY=.m
gen End_Flag=0
format *MY %tm
order pidp Wave Spell Start_MY End_MY End_Ind
	
	*a. Set End_MY=IntDate_MY
by pidp Wave (Spell), sort: gen XX=IntDate_MY /*
  */ if _n==_N & End_Ind==0
replace End_MY=XX if !missing(XX)
replace End_Flag=1 if !missing(XX)
drop XX

	*b. Set End_MY=Start_MY[_n+1]
by pidp Wave (Spell), sort: replace End_MY=Start_MY[_n+1] /*
  */ if _n<_N & MissingDates[_n+1]==0

	*c. Set End_MY=Start_MY+1
by pidp Wave (Spell), sort: gen XX=Start_MY+1 /*
  */ if _n==_N & End_Ind!=0 & Start_MY+1<=IntDate_MY
replace End_MY=XX if !missing(XX)
replace End_Flag=5 if !missing(XX)
drop XX	

by pidp Wave (Spell), sort: gen XX=Start_MY+1 /*
  */ if MissingDates[_n+1]==2 & Start_MY+1<=MinAbove_MY[_n+1]
replace End_MY=XX if !missing(XX)
replace End_Flag=5 if !missing(XX)
drop XX

by pidp Wave (Spell), sort: gen XX=Start_MY+1 /*
  */ if MissingDates[_n+1]==1 & Start_MY+1<=MinAbove_MY[_n+1] /*
  */ & Start_Y==Start_Y[_n+1] & month(dofm(Start_MY))<12
replace End_MY=XX if !missing(XX)
replace End_Flag=4 if !missing(XX)
drop XX

	*d.Set End_MY=Start_MY
by pidp Wave (Spell), sort: replace End_MY=Start_MY /*
  */ if _n==_N & Start_MY==IntDate_MY
by pidp Wave (Spell), sort: replace End_MY=Start_MY /*
  */ if MissingDates==0 & inlist(MissingDates[_n+1],1,2) /* 
  */ & Start_MY==MinAbove_MY[_n+1]
by pidp Wave (Spell), sort: replace End_MY=Start_MY /*
  */ if MissingDates==1 & Start_MY==Start_MY[_n+1]

	*e. Set End_MY=ym(Start_Y[_n+1],1)
by pidp Wave (Spell), sort: gen XX=ym(Start_Y[_n+1],1) /*
  */ if MissingDates<2 & MissingDates[_n+1]==1 /*
  */ & Start_Y<Start_Y[_n+1]
replace End_MY=XX if !missing(XX)
replace End_Flag=4 if !missing(XX)
drop XX	

by pidp Wave (Spell), sort: gen XX=ym(Start_Y[_n+1],1) /*
  */ if MissingDates==1 & MissingDates[_n+1]==0 /*
  */ & Start_Y<Start_Y[_n+1]
replace End_MY=XX if !missing(XX)
replace End_Flag=4 if !missing(XX)
drop XX

	*f. Set End_MY=MinEnd_MY
drop if DropSpell==1
by pidp Wave (Spell), sort: replace Spell=_n

capture confirm variable MinEnd_MY
if _rc==0{
	by pidp Wave (Spell), sort: gen XX=MinEnd_MY /*
		*/ if !missing(MinEnd_MY)  & MinEnd_MY>End_MY & MinEnd_MY<=Start_MY[_n+1]
	replace End_MY=XX if !missing(XX)
	replace End_Flag=4 if !missing(XX)
	drop XX MinEnd_MY
	}
drop DropSpell MissingDates* MinAbove* MaxBelow*  /*
	*/ Start_Y Gap IntDate_Y
	
	
*6. Overlap Check
capture variable confirm leshem
if _rc==0 & "$nonchron_correct"=="Y" {					// FOR BHPS LIFE HISTORY DATA, CORRECT NON-CHRONOLOGICAL DATES WHERE INSPECTION REVEALS A PROBABLE ERROR. (MANY INVOLVE SEASONAL DATES.)
	replace End_MY=ym(1987,4) if pidp==293213969 & leshem==14 & leshey4==1986
	replace Start_MY=ym(1987,4) if pidp==293213969 & leshsm==14 & leshsy4==1986
	replace End_MY=ym(1967,12) if pidp==32687682 & leshem==17 & leshey4==1968
	replace Start_MY=ym(1967,12) if pidp==32687682 & leshsm==17 & leshsy4==1968
	replace End_MY=ym(1990,10) if pidp==632645485 & leshem==17 & leshey4==1990
	replace Start_MY=ym(1990,10) if pidp==632645485 & leshsm==17 & leshsy4==1990
	replace End_MY=ym(1964,12) if pidp==632497925 & leshem==17 & leshey4==1965
	replace Start_MY=ym(1964,12) if pidp==632497925 & leshsm==17 & leshsy4==1965
	replace End_MY=ym(1983,6) if pidp==429005889 & leshem==6 & leshey4==1984
	replace Start_MY=ym(1983,6) if pidp==429005889 & leshsm==6 & leshsy4==1984
	replace End_MY=ym(1998,12) if pidp==26866962 & leshem==17 & leshey4==1999
	replace Start_MY=ym(1998,12) if pidp==26866962 & leshsm==17 & leshsy4==1999
	replace End_MY=ym(1978,4) if pidp==354183445 & leshem==14 & leshey4==1977
	replace Start_MY=ym(1978,4) if pidp==354183445 & leshsm==14 & leshsy4==1977
	replace End_MY=ym(1994,9) if pidp==81982845 & leshem==9 & leshey4==1995
	replace Start_MY=ym(1994,9) if pidp==81982845 & leshsm==9 & leshsy4==1995
	replace End_MY=ym(1988,4) if pidp==53856082 & leshem==14 & leshey4==1987
	replace Start_MY=ym(1988,4) if pidp==53856082 & leshsm==14 & leshsy4==1987
	gen XX=1 if Start_MY>End_MY & !missing(Start_MY,End_MY)
	by pidp, sort: egen YY=max(XX)
	drop if YY==1											//	DROPS ONE pidp, 27404042: CORRECTION OF IMPLAUSIBLE DATES WOULD IMPLY IMPUTING SEVERAL EQUAL SPELL DATES
	by pidp (Wave Spell), sort: replace Spell=_n if YY==1
	by pidp (Wave Spell), sort: replace End_Ind=cond(_n==_N,End_Type,1)	if YY==1
	drop XX YY	
	}
else if _rc!=0 | "$nonchron_correct"!="Y" {					// DROPS WHOLE pidp IF IMPLAUSIBLE DATES. NOT POSSIBLE TO JUST DROP pidp-Wave AS CLEARNING PROCESS IS NEARLY COMPLETE.
	gen XX=1 if Start_MY>End_MY & !missing(Start_MY,End_MY)
	by pidp, sort: egen YY=max(XX)
	drop if YY==1
	by pidp (Wave Spell), sort: replace Spell=_n if YY==1
	by pidp (Wave Spell), sort: replace End_Ind=cond(_n==_N,End_Type,1)	if YY==1
	drop XX YY
}
di in red "Overlap Check 1"
prog_checkoverlap


*7. Create spells in End_Type=.m equal to jbstat.
capture confirm var F_Ind																// CHECK WHETHER FURLOUGH VARIANT OF UKHLS Annual History IS BEING CLEANED.
if !_rc {
	prog_lastspellmissing_F																// THIS CALLS AN ALTERED PROGRAM THAT CORRECTLY ALLOWS FURLOUGH AND UNDERLYING EMPLOYMENT STATUS TO BE RETAINED.
	}
else if _rc {
	prog_lastspellmissing
	}	
drop End_Type


*8. Replace start/end dates that are overlapping across Waves
	*Count number of pidps observed in multiple waves.
	*First drop if Status=.m because don't want this to change dates for spell where status is known.
	*Drop spells which are encompassed.
egen IDxWave_Tag=tag(pidp Wave)
by pidp (Wave Spell), sort: egen XX=min(Wave)
count if XX<Wave & IDxWave_Tag==1
di in red "`r(N)' pidps with life histories collected in more than 1 waves."
drop XX IDxWave_Tag				

drop if Status==.m		
by pidp (Wave Spell), sort: gen XX=_n
gen YY=.
qui sum XX
forval i=1/`r(max)'{
	by pidp (Wave Spell), sort: replace Start_Flag=1 if Start_MY<End_MY[_n-1] & _n>1
	by pidp (Wave Spell), sort: replace Start_MY=End_MY[_n-1] if Start_MY<End_MY[_n-1] & _n>1
	by pidp (Wave Spell), sort: replace YY=1 if /*
		*/ Start_MY==End_MY & Start_MY==Start_MY[_n+1] & Wave!=Wave[_n+1] & _n<_N
	drop if YY==1
	count if Start_MY > End_MY
	local to_drop = `r(N)'
	drop if Start_MY>End_MY
	if `to_drop' == 0{
		continue, break
		}		
	}
drop XX YY
	
	
*9. Drop spells of no duration.
	* Previously, split into fractional months where multiple spells begin in same MY.
drop if Start_MY==End_MY
by pidp (Wave Spell), sort: replace Spell=_n	


*10. Make Checks 
di in red "Overlap Check 2"
prog_checkoverlap
count if missing(End_MY,Start_MY)
if `r(N)'>0{
	di in red "`r(N)' cases of missing dates. Should be zero"
	STOP
	}
compress

