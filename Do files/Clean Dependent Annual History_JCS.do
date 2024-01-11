/*
********************************************************************************
CLEAN DEPENDENT ANNUAL HISTORY ANNUAL HISTORY.DO

	THIS FILE CREATES A DATASET OF JOB HISTORY AND INTERVIEW DATE VARIABLES FROM
	CURRENT AND PRECEEDING FULL OR TELPHONE INTERVIEWS.

	UPDATES: 
	* WHERE AN EMPLOYED/SELF-EMPLOYED INDIVIDUAL IS FURLOUGHED, THE UNDERLYING EMPLOYMENT SPELL IS NOT FINISHED, SO THE DATA RECORD AN UNFINISHED SPELL THAT IS NOT THE END SPELL. UPDATED CODE DROPS THE DUPLICATE EMPLOYMENT SPELL WHEN FURLOUGH SPELLS HAVE A CONTINUING UNDERLYING EMPLOYMENT SPELL. 
	* A SMALL AMOUNT OF CODE FROM THE END OF THIS FILE IS TRANSFERRED TO OTHER FILES (UKHLS AND BHPS DEPENDENT Annual History FILES) SO THAT THIS FILE CAN BE USED TO CLEAN BOTH UKHLS AND BHPS DATA (UKHLS Annual History_JCS.do REQUIRES VARIANTS OF THAT CODE WITHIN A LOOP). 
	* CREATES LOWER BOUND FOR START OF FURLOUGH SPELLS OF 1 MARCH 2020
	
	* LW VERSION USES THIS CODE.
	
********************************************************************************
*/	

compress

*1. Merge with interview grid
merge m:1 pidp Wave using "${dta_fld}/Interview Grid", /*
	*/ nogenerate keep(match) /*
	*/ keepusing(IntDate_Y IntDate_MY LB_Y LB_MY Birth_Y)
qui prog_labels
drop if missing(IntDate_MY, LB_MY)

*2. Generate variables for identifying seams.	
by pidp Wave (Spell), sort: gen Spells_Wave=_N
count if (End_Ind==1 & Spells_Wave==Spell) | (End_Ind!=1 & Spell<Spells_Wave)			// NEW CODE TO DROP A SMALL NUMBER OF ERRONEOUS END SPELLS WITH NO INFORMATION.
gen XX=1 if (End_Ind==1 & Spells_Wave==Spell) | (End_Ind!=1 & Spell<Spells_Wave)
by pidp Wave, sort: egen YY=max(XX)
drop if YY==1 & missing(End_Ind) & Spell==Spells_Wave
drop XX YY
by pidp Wave (Spell), sort: replace Spells_Wave=_N
di in red "The following number should be zero:"
count if (End_Ind==1 & Spells_Wave==Spell) | (End_Ind!=1 & Spell<Spells_Wave)
gen XX=1 if End_Ind!=1 & Spell<Spells_Wave	
by pidp Wave, sort: egen YY=max(XX)
drop if YY==1 & Spell==2 & Spell==Spells_Wave											// EFFECTIVE FOR UKHLS DATA: BECAUSE FURLOUGH SPELLS ARE RECODED AS EMPLOYMENT SPELLS IN UNSUFFIXED DATA, THERE WILL BE 2 (DUPLICATE) NON-ENDED EMPLOYMENT SPELLS RECORDED. THIS CODE DROPS ONE OF THE DUPLICATE EMPLOYMENT SPELLS WHEN FURLOUGH SPELLS HAVE A CONTINUING UNDERLYING EMPLOYMENT SPELL. // FOR OTHER UKHLS VARIANTS AND FOR BHPS Annual History - Waves 16-18, THERE ARE NO DUPLICATE OBSERVATIONS (SINCE NO FURLOUGH ISSUE) SO NO DELETIONS HERE.
drop XX YY
by pidp Wave (Spell), sort: replace Spells_Wave=_N
di in red "The following number should be zero:"
count if (End_Ind==1 & Spells_Wave==Spell) | (End_Ind!=1 & Spell<Spells_Wave)
gen Spell_Type=0 if Spell!=1 & Spell!=Spells_Wave
replace Spell_Type=1 if Spell==1 & Spell==Spells_Wave
replace Spell_Type=2 if Spell==1 & Spell!=Spells_Wave
replace Spell_Type=3 if Spell!=1 & Spell==Spells_Wave
replace Spell_Type=4 if End_Ind==.m
label values Spell_Type spell_type	
drop Spells_Wave	

*3. Generate activity end dates & imputation flags
	* If year is missing, assume month should be missing too.
	* If month missing but next spell ends in January of same year, end date must be January.
	* If month missing but previous spend ends in December of same year, end date must be December
replace End_M=month(dofm(IntDate_MY)) if End_Ind==0
replace End_Y=year(dofm(IntDate_MY)) if End_Ind==0

gen End_MY=ym(End_Y,End_M) if inlist(End_Ind,0,1)	
by pidp Wave (Spell), sort: replace End_MY=End_MY[_n-1] if /*
	*/ missing(End_MY) & End_MY[_n-1]==ym(End_Y,12)
by pidp Wave (Spell), sort: replace End_MY=End_MY[_n+1] if /*
	*/ missing(End_MY) & End_MY[_n+1]==ym(End_Y,1)
	
recode End_*Y (missing=.m)
drop End_M

*4. End Type
	* Drop where last spell is Status=.m and End_Ind==.m
by pidp Wave (Spell), sort: egen XX=max(cond(End_Ind==0,1,0))
gen End_Type=cond(XX==1,0,.m)
drop XX
drop if Status==.m & End_Ind==.m

*5. Fix incomplete statuses.
	* Looks across Waves. If spell is incomplete, takes first Status in next spell if two are compatible.
		*NOTE, THIS COULD SPAN MORE THAN 2 WAVES.
by pidp (Wave Spell), sort: gen Status_NextSpell=cond(_n<_N,Status[_n+1],.i)
replace Status=Status_NextSpell if Status==100 & inlist(Spell_Type,1,3) & End_Ind==0 & inlist(Status_NextSpell,1,2)	// inlist(Status_NextSpell,12,13) NOT USED BECAUSE THIS LEADS TO IMPUTED FURLOUGH SPELLS STARTING BEFORE THE BEGINNING OF THE FURLOUGH SCHEME IN MARCH 2020.
replace Status=Status_NextSpell if Status==101 & inlist(Spell_Type,1,3) & End_Ind==0 & (inrange(Status_NextSpell,3,11) | inrange(Status_NextSpell,14,97))	// ORIGINAL LW CODE: replace Status=Status_NextSpell if Status==101 & inlist(Spell_Type,1,3) & End_Ind==0 & inrange(Status_NextSpell,3,97)
drop Status_NextSpell Spell_Type

*6. Drop participants with non-chronological dates, who also:
prog_nonchron End Y MY
by pidp Wave (End_Y End_MY Spell), sort: replace Spell=_n if NonChron_Wave==1
by pidp Wave (Spell), sort: replace Spell=_n
by pidp Wave (Spell), sort: replace End_Ind=cond(_n==_N,End_Type,1)
sort pidp Wave Spell
drop NonChron_Wave

*7. Drop spells after first spell ending after interview date.
	* Truncate first spell after interview date to IntDate_MY
	* Drop implausible spells.
gen XX=.
foreach i in Y MY{
	replace XX=Spell if End_`i'>IntDate_`i' & !missing(End_`i',IntDate_`i')
	replace End_`i'=IntDate_`i' if !missing(XX)
	}
replace End_Ind=0 if !missing(XX)
by pidp Wave (Spell), sort: egen YY=min(XX)
drop if Spell>YY & !missing(YY)
drop XX YY	


prog_implausibledates End
drop Birth_Y


*8. Impute equal dates
prog_imputeequaldates Y MY


capture confirm var F_Ind																// CHECK WHETHER FURLOUGH VARIANT OF UKHLS Annual History IS BEING CLEANED.
if !_rc {
	// GENERATE LOWER BOUND DATES FOR FURLOUGH SPELLS.
	local if "if inlist(Status,12,13,112,113,212,213,10012,10013) & LB_MY<mofd(dmy(1,3,2020))"
	by pidp (Wave), sort: replace LB_MY=mofd(dmy(1,3,2020)) `if'						// LOWER BOUND MONTH IS March FOR FURLOUGH/TEMP LAYOFF [USING WAVE 12[30] DATA: (30 real changes made)]
	local if "if inlist(Status,12,13,112,113,212,213,10012,10013) & LB_Y<2020"
	by pidp (Wave), sort: replace LB_Y=2020 `if'										// LOWER BOUND YEAR IS 2020 FOR FURLOUGH/TEMP LAYOFF [USING WAVE 12[30] DATA: (25 real changes made)]
	}


*9. Create indicator for if has dates before Prev_IntDate	
gen XX=.
foreach i in Y MY{
	replace XX=1 if End_`i'<LB_`i' & !missing(End_`i',LB_`i')
		}
by pidp Wave (Spell), sort: egen PrePrev_Wave=max(XX)
replace PrePrev_Wave=cond(missing(PrePrev_Wave),0,1)
drop XX


*10. Convert End Dates into Start Dates
	* Create Start Flag
foreach i in Y MY{
	by pidp Wave (Spell), sort: gen Start_`i'=LB_`i' if _n==1 & PrePrev_Wave==0
	by pidp Wave (Spell), sort: replace Start_`i'=End_`i'[_n-1] if _n>1
	}
recode Start*Y (missing=.m)
by pidp Wave (Spell), sort: gen Start_Flag=cond(_n>1 | PrePrev_Wave==1,0,1)
drop End_Y End_MY LB* PrePrev_Wave

format *MY %tm


*11. Run Common Code																	// CODE TRANSFERRED TO "UKHLS Annual History_JCS.do"
//do "${do_fld}/Clean Work History_JCS.do"	
//prog_imputemissingspells
