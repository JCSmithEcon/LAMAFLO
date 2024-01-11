/*
********************************************************************************
BHPS LIFE HISTORY.DO
	
	THIS FILE CREATES LIFETIME EMPLOYMENT STATUS HISTORIES USING THE LIFEMST 
	FILES FROM WAVES 2, 11, AND 12 OF THE BHPS (WAVES B, K AND L)
	
	UPDATES:
	* CHECKS, FLAGS AND CORRECTS DISCREPANCIES IN SPELL ORDERING AND END SPELL.
	* NOTE THE SUBSTANTIAL CHANGE TO Clean Life History_JCS.do, CALLED BY THIS FILE (DESCRIBED IN THAT FILE).
	
	* LW VERSION USES ORIGINAL LW "BHPS Life History.do" (IN THE LOWER HALF OF THIS FILE). A CALLED PROGRAM NAME IS CHANGED TO prog_assignwinter_orig SO THAT THE ORIGINAL RATHER THAN THE ALTERED PROGRAM IS CALLED.

********************************************************************************
*/

if "$LW"!="LW" & "LW"!="lw" { 

	/*
	1. Create Life Histories for FTE never leavers		
	*/

	tempfile notleft_fte
	global notleft_fte `notleft_fte'
	foreach i of numlist $bhps_lifehistwaves{								// CREATES A FILE CONTAINING JUST pidp AND Wave FOR PARTICIPANTS WHO HAD NOT LEFT FTE
		local j: word `i' of `c(alpha)'
		use pidp b`j'_lednow /*
			*/ using "${fld}/${bhps_path}_w`i'/b`j'_indresp${file_type}" /*
			*/ if b`j'_lednow==0, clear
		gen Wave=`i'
		order pidp Wave
		keep pidp Wave
		capture append using "`notleft_fte'"
		save "`notleft_fte'", replace
		}
	merge m:1 pidp Wave using "${dta_fld}/Interview Grid", /*
		*/ nogen keep(match) keepusing(IntDate_MY Birth_MY)
	gen Spell=1																// CREATES SINGLE SPELL		
	gen Start_MY=Birth_MY													// SPELL START DATE CODED AS DATE OF BIRTH (Start_Flag==0 IS SET BELOW)
	gen End_MY=IntDate_MY													// SPELL END DATE CODED AS INTERVIEW DATE (End_Flag==1 IS SET BELOW)
	gen Status=7															// Status CODED AS F/T EDUCATION
	gen Source_Variable="lednow_w"+strofreal(Wave)							// Source_Variable CODED AS lednow FROM RELEVANT WAVE
	gen Job_Hours=.i														// Hours AND Job_Change SET AS inapplicable
	gen Job_Change=.i
	gen Start_Flag=0
	gen End_Flag=1
	gen Status_Spells=1														// Status_Spells CODED AS 1. INTERPRETATION: THE INFORMATION ABOUT THIS STATUS SPELL IS DERIVED FROM ONE SPELL
	gen Source="b"+substr(subinstr("`c(alpha)'"," ","",.),Wave,1)+"_indresp" // substr(subinstr...,Wave,1) PICKS OUT THE LETTER FROM THE ALPHABET CORRESPONDING TO Wave. subinstr(s1,s2,s3,n) Description: s1, where the first n occurrences in s1 of s2 have been replaced with s3. substr(s,n1,n2) Description: the substring of s, starting at n1, for a length of n2.
	drop Birth_MY
	save "`notleft_fte'", replace


	/*
	2. Collect Lifemst Data
		* bb_lifemst_bh
		* bk_lifemst_bh 
		* bl_lifemst_bh
	*/
	capture rm "${dta_fld}/BHPS Life History - Raw.dta"
	foreach i of numlist $bhps_lifehistwaves{
		local j: word `i' of `c(alpha)'
		use "${fld}/${bhps_path}_w`i'/b`j'_lifemst${file_type}", clear
		merge m:1 pidp using "${fld}/${bhps_path}_w`i'/b`j'_indresp${file_type}", /*
			*/ keep(match) nogenerate keepusing(b`j'_led*) 		// COLLECT INDICATOR OF STILL IN F/T EDUCATION (lednow), MONTH AND YEAR LEFT FULL TIME EDUCATION (ledendm, ledendy4 - ALSO ledendy). KEEP ONLY CASES MATCHED TO THE RELEVANT WAVE'S indresp FILE (BEFORE ANY CLEANING)
		rename b`j'_* *
		capture rename *_bh *
		keep pidp *lesh* *led*							
		capture drop leshey ledendy leshsy						// DROP 2-DIGIT YEAR VARIABLES; 4-DIGIT YEAR VARIABLES ARE KEPT.
		gen Wave=`i'
		gen Spell = leshno										// DEFINE SPELL AS lifetime employment history spell number, RETAINING THE ORIGINAL leshno VARIABLE FOR COMPARISON
	//		rename leshno Spell										
		order pidp Wave Spell
		capture append using "${dta_fld}/BHPS Life History - Raw"
		save "${dta_fld}/BHPS Life History - Raw", replace
		}


	/*
	3. Clean Lifemst Data
	*/
		*i. Open raw dataset
	prog_reopenfile "${dta_fld}/BHPS Life History - Raw"
	merge m:1 pidp Wave using "${dta_fld}/Interview Grid", /*
		*/ nogen keep(match master) keepusing(IntDate_*Y Birth_*Y)
	drop if missing(Birth_MY) | missing(IntDate_MY)	 
	prog_labels
	prog_recodemissing *
	foreach var of varlist leshsy4 leshey4 ledeny4{
		su `var'
		replace `var'=.m if `var'==9998 & !missing(`var')					// RECODE YEAR FIRST LEFT F/T EDUCATION TO MISSING IF IT TAKES VALUE 9998 (29 OBSERVATIONS) (MISCODING PROBABLY RESULTING FROM QUESTIONNAIRE ASKING THAT IF MONTH CAN'T BE REMEMBERED, MONTH SHOULD BE CODED AS 98 AND YEAR OBTAINED)
		su `var'
		}


		*ii. Correct 5 instances of non-consecutive Spell numbers			// NEW SECTION.
		// The correction should enable imputation of spell start month and year from the end month and year of the preceding spell, for 4 spells where start month-year are missing, and just year imputation in 1 case. 
	sort pid Spell
	gen COUNT=1
	bysort pidp Wave: gen CONSECUTIVE=sum(COUNT)
	compare Spell CONSECUTIVE
	/*
											---------- Difference ----------
								Count       Minimum      Average     Maximum
	------------------------------------------------------------------------
	Spell=CONSECUT~E            59375
	Spell>CONSECUT~E                8             1            1           1
						   ----------
	Jointly defined             59383             0     .0001347           1
						   ----------
	Total                       59383
	*/
	order pidp Spell CONSECUTIVE leshsm leshsy4 leshem leshey4 Wave
	//browse if Spell>CONSECUTIVE
	gen XX = 1 if Spell>CONSECUTIVE
	egen YY = mean(XX), by(pidp)
	order pidp XX Spell CONSECUTIVE leshsm leshsy4 leshem leshey4 Wave
	//browse if YY==1
	replace Spell=CONSECUTIVE if XX==1
	replace leshsm=leshem[_n-1] if XX==1
	replace leshsy4=leshey4[_n-1] if XX==1
	sort pid Spell
	gen COUNT2=1
	bysort pidp Wave: gen CONSECUTIVE2=sum(COUNT2)
	compare Spell CONSECUTIVE2
	/*
											---------- Difference ----------
								Count       Minimum      Average     Maximum
	------------------------------------------------------------------------
	Spell=CONSECUT~2            59383
						   ----------
	Jointly defined             59383             0            0           0
						   ----------
	Total                       59383
	*/
	drop COUNT* CONSECUTIVE* XX YY

			
		*iii. See whether start and end cells in adjacent spells are consistent

			/// Only 5 [WAS 4 IN LW] inconsistencies, and the inconsistencies are small, so ignore.
	by pidp Wave (Spell), sort: gen XX=leshsm[_n+1]
	by pidp Wave (Spell), sort: gen YY=leshsy4[_n+1]
	gen ZZ=(XX!=leshem | YY!=leshey4) & !missing(XX,YY)
	count if ZZ==1
	//	di in red "`r(N)' cases where start and ends do not match up in adjacent spells. Ignore as so few."
	di in red "`r(N)' cases where start and ends do not match up in adjacent spells. In all `r(N)' cases, the problem arises in end month/year. There are no problems with start month/year."
	bysort pidp: egen DISCREPANCY = mean(ZZ)
	order pidp Wave Spell leshsm leshem XX leshsy4 leshey4 YY 
	//browse if DISCREPANCY!=0
	gen AA = 1 if XX!=leshem & !missing(XX)			// AA = 1 IF END MONTH MISSING BUT NEXT START MONTH IS RECORDED
	replace AA = 2 if YY!=leshey4 & !missing(YY)	// AA = 2 IF END YEAR MISSING BUT NEXT START YEAR IS RECORDED
	replace leshem=XX if AA==1						// CORRECT MISSING END MONTH (NOTING THAT END DATES MIGHT NOT BE USED IN FUTURE)
	replace leshey4=YY if AA==2						// CORRECT MISSING END YEAR (NOTING THAT END DATES MIGHT NOT BE USED IN FUTURE)
	order pidp Wave Spell AA leshsm leshem XX leshsy4 leshey4 YY 
	//browse if DISCREPANCY!=0
	drop XX YY ZZ AA DISCREPANCY
	count if Spell==1 & (leshsy4!=ledeny4 | leshsm!=ledendm)
	di in red "`r(N)' cases, including missing values, where end FTE and start first spell are inconsistent. Most involve inapplicable school end dates because never went to school."
	order pidp Wave Spell leshsm ledendm leshsy4 ledeny4 
	//browse if Spell==1 & (leshsy4!=ledeny4 | leshsm!=ledendm)
	count if Spell==1 & (leshsy4!=ledeny4 | leshsm!=ledendm) & !missing(leshsy4,ledeny4,leshsm,ledendm) & lednow!=1
	di in red "`r(N)' cases where end FTE and start first spell are inconsistent. All involve long gaps between end of FTE and first spell start."
	//browse if Spell==1 & (leshsy4!=ledeny4 | leshsm!=ledendm) & !missing(leshsy4,ledeny4,leshsm,ledendm) & lednow!=1
	//	drop leshe*	XX YY ZZ	

		
		*iii. Clean Status data
	/*
	   lifetime employment history |
						  status   |      Freq.     Percent        Cum.
	-------------------------------+-----------------------------------
				1. self-employed   |      2,440        4.11        4.11
		2. f/t paid employment     |     24,448       41.18       45.29
		3. p/t paid employment     |      7,250       12.21       57.51
				4. unemployed      |      6,520       10.98       68.49
						5. retired |      3,060        5.15       73.64
				6. maternity leave |      1,617        2.72       76.37
				7. family care     |      7,868       13.25       89.62
		8. ft studt, school        |      1,374        2.31       91.93
		9. lt sick, disabld        |      1,331        2.24       94.18
			   10. gvt trng scheme |      1,256        2.12       96.29
	   11. national/war service    |      1,083        1.82       98.12
			   12. something else  |      1,118        1.88      100.00
	-------------------------------+-----------------------------------
							 Total |     59,365      100.00
	*/
	gen Status=.m
	replace Status=1 if leshst==1					// 1. self-employed
	replace Status=2 if inrange(leshst,2,3)			// 2. employed (FT/PT)
	replace Status=leshst-1 if inrange(leshst,4,10) // 3. unemployed, 4. retired, 5. maternity leave, 6. family care, 7. FTE, 8. LT sick/disabled, 9. gov't training scheme
	replace Status=103 if leshst==11				// 103. national/war service
	replace Status=97 if leshst==12					// 97. something else
	label values Status status
	gen Job_Hours=cond(inrange(leshst,2,3),leshst-1,cond(leshst==1,.m,.i))	// Job_Hours: 1. FT, 2. PT, .m if self-employed, .i if neither employed or self-employed
	gen Job_Change=cond(inlist(Status,1,2,100),4,.i)						// Job_Change CATEGORISES EMPLOYMENT/SELF-EMPLOYMENT FROM lifetime employment history files AS "4. POSSIBLY INVOLVING MULTIPLE JOBS". MULTIPLE JOBS CANNOT BE EXCLUDED BECAUSE RESPONDENT WAS ASKED "When did your situation change?". FOR FURTHER INFO SEE E.G. DAVID MARE (2006), P.13.
	gen Source_Variable="lesht"+strofreal(Spell)+"_w"+strofreal(Wave)
	//	drop leshst

		
		*iv. Check if sequences end with current activities					// MODIFIED SECTION.
	//		* DROP THOSE WITH STATUS==.M WHERE NOT FINAL SPELL (ONLY FIVE PEOPLE)
	by pidp Wave (Spell), sort: gen XX=cond(_n==_N,1,0)
	gen End_Ind=.m
	replace End_Ind=0 if leshne==1							// End_Ind=0 if bb/bk/bl_lifemst lifetime employment history status = "1. not ended"
	replace End_Ind=1 if leshne==.i | (leshne==.m & XX==0)	// End_Ind=1 if bb/bk/bl_lifemst lifetime employment history status "inapplicable" (because not last spell in Wave) or missing and not last spell in Wave
	by pidp Wave (Spell), sort: gen End_Type=End_Ind[_N]	// End_Type = End_Ind AS RECORDED IN THE LAST SPELL OF A WAVE, COPIED TO ALL pidp-Wave OBSERVATIONS
	//browse if Status==.m & XX==1
	gen FLAGSpell_LASTStatus_MISS=(Status==.m & XX==1)					// FLAGSpell_LASTStatus_MISS = 1 WHERE LAST Status IN THAT WAVE IS MISSING. THIS IS A Spell-LEVEL FLAG (RATHER THAN A pidp-Wave-LEVEL FLAG).
	label variable FLAGSpell_LASTStatus_MISS "Spell-level FLAG with value 1 = missing last Status in Wave (for last Spell)"
	bysort pidp Wave (Spell): egen FLAGpidpWave_LASTStatus_MISS = max(FLAGSpell_LASTStatus_MISS) 
	label define flagpidpwave_laststatus_miss 0 "0. pidp-Wave with observed last Status in Wave" 1 "1. pidp-Wave with missing last Status in Wave"
	label values FLAGpidpWave_LASTStatus_MISS flagpidpwave_laststatus_miss  
	label variable FLAGpidpWave_LASTStatus_MISS "pidp-Wave-level FLAG with value 1 = pidp with missing last Status in Wave"
	replace FLAGSpell_LASTStatus_MISS=2 if Status!=.m & XX==1			// VALUE 2 CODED HERE RATHER THAN ABOVE SO THAT THE pidp_Wave LEVEL VARIABLE IS JUST CODED (1,0) WHERE 1 = LAST STATUS THAT WAVE IS MISSING
	label define flagspell_laststatus_miss 0 "0. Not last Spell in Wave" 1 "1. Status missing for last Spell in Wave" 2 "2. Status observed for last Spell in Wave"
	label values FLAGSpell_LASTStatus_MISS flagspell_laststatus_miss
	/*
			  Spell-level FLAG with value 1 |
		indicating a missing last Status in |
									   Wave |      Freq.     Percent        Cum.
	----------------------------------------+-----------------------------------
				  0. Not last Spell in Wave |     43,212       72.77       72.77
	1. Status is missing for last Spell in  |         13        0.02       72.79
	2. Status is observed for last Spell in |     16,158       27.21      100.00
	----------------------------------------+-----------------------------------
									  Total |     59,383      100.00
	*/
	order pidp Status Wave Spell FLAGSpell_LASTStatus_MISS leshsm leshsy4 leshem leshey4 leshne
	//browse if FLAGpidpWave_LASTStatus_MISS==1								// FLAGpidpWave_LASTStatus_MISS = 1 FOR THE pidp-Wave IF LAST Status FOR THAT pidp AT THAT Wave IS MISSING. THIS IS A pidp-Wave-LEVEL FLAG (RATHER THAN A Spell-LEVEL FLAG).
	drop if Status==.m & XX==1 & leshsy4==.m								// DROP END-Spell IF MISSING Status AND SPELL START YEAR IS MISSING (10 observations deleted)
	by pidp Wave: egen FLAGpidpWave_ANYStatus_MISS=max(Status==.m)			// FLAGpidpWave_ANYStatus_MISS INDICATES FULL SETS OF pidp-Wave OBSERVATIONS WITH A MISSING Status SOMEWHERE
	label define flagpidpwave_anystatus_miss 0 "0. pidp-Wave with no missing Status" 1 "1. pidp-Wave with missing Status somewhere in Wave"
	label values FLAGpidpWave_ANYStatus_MISS flagpidpwave_anystatus_miss  
	label variable FLAGpidpWave_ANYStatus_MISS "pidp-Wave-level FLAG with value 1 indicating pidp has a missing Status anywhere in Wave"

	gen ZZ = (Status==.m & leshsy4==.m)						// ZZ INDICATES Spell WHERE BOTH Status AND START YEAR ARE MISSING
	by pidp Wave (Spell), sort: egen ZZZZ = max(ZZ)			// ZZZZ INDICATES pidp_Waves WITH AT LEAST ONE Spell WHERE BOTH Status AND START YEAR ARE MISSING
	drop if Status==.m & leshsy4==.m						// DROPS Spell IF BOTH Status AND START YEAR ARE MISSING (5 observations deleted)
	by pidp Wave (Spell), sort: replace Spell=_n if ZZZZ==1	// RENUMBERS Spell ONCE 8 Spells WITH MISSING Status AND START YEAR HAVE BEEN DELETED (8 real changes made)
	drop XX ZZ*


		*v. Create start dates.
			// Winter is not split into two for bb_lifemst. Next section deals with this.
	/*
	. tab leshsm
		 month lifetime emp. hist. |
					status started |      Freq.     Percent        Cum.
	-------------------------------+-----------------------------------
						1. january |      2,890        5.22        5.22
				2. february        |      2,177        3.93        9.16
						3. march   |      2,789        5.04       14.19
						4. april   |      3,350        6.05       20.25
						5. may     |      3,197        5.78       26.02
						6. june    |      8,656       15.64       41.66
						7. july    |      7,667       13.85       55.52
						8. august  |      3,075        5.56       61.07
				9. september       |      4,903        8.86       69.93
					   10. october |      2,932        5.30       75.23
			   11. november        |      2,185        3.95       79.18
			   12. december        |      3,288        5.94       85.12
	   13. winter (jan,feb)        |      1,170        2.11       87.23
					   14. spring  |      2,147        3.88       91.11
					   15. summer  |      2,937        5.31       96.42
					   16. autumn  |      1,608        2.91       99.32
	   17. winter (nov,dec)        |        374        0.68      100.00
	-------------------------------+-----------------------------------
							 Total |     55,345      100.00
	*/
	replace leshsm=.m if leshsy4==.m
	gen Winter=cond(Wave==2 & leshsm==13,1,0)
	gen Start_Y=leshsy4
	gen Start_M=cond(leshsm>=1 & leshsm<=12,leshsm,.m)
	gen Start_S=.m
	replace Start_S=1 if inlist(leshsm,1,2) | (leshsm==13 & Wave!=2)
	replace Start_S=2 if inlist(leshsm,3,4,5,14)
	replace Start_S=3 if inlist(leshsm,6,7,8,15)
	replace Start_S=4 if inlist(leshsm,9,10,11,16)
	replace Start_S=5 if inlist(leshsm,12,17)
	gen Start_MY=ym(Start_Y,Start_M)
	gen Start_SY=ym(Start_Y,Start_S)
	gen Start_Flag=0
	//	drop leshsm leshsy4 Start_M *_S led*
	//	drop leshsm leshsy4 Start_M *_S
	//	drop Start_M *_S 
	//	drop led*
		
		
		*vi. Impute correct season where Wave==2 & Season is Winter	
	if "$assignwinter_correct"=="January" | "$assignwinter_correct"=="JANUARY" | "$assignwinter_correct"=="january" | "$assignwinter_correct"=="Jan" | "$assignwinter_correct"=="JAN" | "$assignwinter_correct"=="jan" {								// ASSIGNS Winter TO JANUARY IF THERE IS NO DATASET INFORMATION TO AID ALLOCATION BETWEEN DECEMBER AND JAN/FEB.
		prog_assignwinter
		}
	else {															// DROPS CASES WHERE THERE IS NO DATASET INFORMATION TO AID ALLOCATION BETWEEN DECEMBER AND JAN/FEB.
		prog_assignwinter_orig
		}
		
		*vii. Run Common Life History Do File.
	gen Source="b"+substr(subinstr("`c(alpha)'"," ","",.),Wave,1)+"_lifehist"
	do "${do_fld}/Clean Life History_JCS.do"


	save "${dta_fld}/BHPS Life History", replace
	rm "${dta_fld}/BHPS Life History - Raw.dta"

	}

	
else if "$LW"=="LW" | "$LW"=="lw" {
	
	/*
	1. Create Life Histories for FTE never leavers
	*/
	/**/
	qui{
		tempfile notleft_fte
		global notleft_fte `notleft_fte'
		foreach i of numlist $bhps_lifehistwaves{
			local j: word `i' of `c(alpha)'
			use pidp b`j'_lednow /*
				*/ using "${fld}/${bhps_path}_w`i'/b`j'_indresp${file_type}" /*
				*/ if b`j'_lednow==0, clear
			gen Wave=`i'
			order pidp Wave
			keep pidp Wave
			capture append using "`notleft_fte'"
			save "`notleft_fte'", replace
			}
		merge m:1 pidp Wave using "${dta_fld}/Interview Grid", /*
			*/ nogen keep(match) keepusing(IntDate_MY Birth_MY)
		gen Spell=1
		gen Start_MY=Birth_MY
		gen End_MY=IntDate_MY
		gen Status=7
		gen Source_Variable="lednow_w"+strofreal(Wave)
		gen Job_Hours=.i
		gen Job_Change=.i
		gen Start_Flag=0
		gen End_Flag=1
		gen Status_Spells=1
		gen Source="b"+substr(subinstr("`c(alpha)'"," ","",.),Wave,1)+"_indresp"
		drop Birth_MY
		save "`notleft_fte'", replace
		}
	*/	


	/*
	2. Collect Lifemst Data
		* bb_lifemst_bh
		* bk_lifemst_bh 
		* bl_lifemst_bh
	*/
	/**/
	qui{
		capture rm "${dta_fld}/BHPS Life History - Raw.dta"
		foreach i of numlist $bhps_lifehistwaves{
			local j: word `i' of `c(alpha)'
			use "${fld}/${bhps_path}_w`i'/b`j'_lifemst${file_type}", clear
			merge m:1 pidp using "${fld}/${bhps_path}_w`i'/b`j'_indresp${file_type}", /*
				*/ keep(match) nogenerate keepusing(b`j'_led*) 
			rename b`j'_* *
			capture rename *_bh *
			keep pidp *lesh* *led*
			capture drop leshey ledendy leshsy
			gen Wave=`i'
			rename leshno Spell
			order pidp Wave Spell
			capture append using "${dta_fld}/BHPS Life History - Raw"
			save "${dta_fld}/BHPS Life History - Raw", replace
			}
		}
	*/
		
	/*
	3. Clean Lifemst Data
	*/
	/**/
	qui{
		*i. Open raw dataset
		prog_reopenfile "${dta_fld}/BHPS Life History - Raw"
		merge m:1 pidp Wave using "${dta_fld}/Interview Grid", /*
			*/ nogen keep(match master) keepusing(IntDate_*Y Birth_*Y)
		drop if missing(Birth_MY) | missing(IntDate_MY)	 
		prog_labels
		prog_recodemissing *
		foreach var of varlist leshsy4 leshey4 ledeny4{
			replace `var'=.m if `var'>2018 & !missing(`var')
			}
		
		*ii. See whether start and end cells in adjacent spells are consistent
			/// Only 4 inconsistencies, and the inconsistencies are small, so ignore.
		by pidp Wave (Spell), sort: gen XX=leshsm[_n+1]
		by pidp Wave (Spell), sort: gen YY=leshsy4[_n+1]
		gen ZZ=(XX!=leshem | YY!=leshey4) & !missing(XX,YY)
		count if ZZ==1
		di in red "`r(N)' cases where start and ends do not match up in adjacent spells. Ignore as so few."
		count if Spell==1 & (leshsy4!=ledeny4 | leshsm!=ledendm)
		di in red "`r(N)' cases where end FTE and start first spell are inconsistent."
		drop leshe*	XX YY ZZ	
		
		*iii. Clean Status data
		gen Status=.m
		replace Status=1 if leshst==1
		replace Status=2 if inrange(leshst,2,3)
		replace Status=leshst-1 if inrange(leshst,4,10)
		replace Status=103 if leshst==11
		replace Status=97 if leshst==12
		label values Status status
		gen Job_Hours=cond(inrange(leshst,2,3),leshst-1,cond(leshst==1,.m,.i))
		gen Job_Change=cond(inlist(Status,1,2,100),4,.i)
		gen Source_Variable="lesht"+strofreal(Spell)+"_w"+strofreal(Wave)
		drop leshst
		
		*iv. Check if sequences end with current activities
			* DROP THOSE WITH STATUS==.M WHERE NOT FINAL SPELL (ONLY FIVE PEOPLE)
		by pidp Wave (Spell), sort: gen XX=cond(_n==_N,1,0)
		gen End_Ind=.m
		replace End_Ind=0 if leshne==1
		replace End_Ind=1 if leshne==.i | (leshne==.m & XX==0)
		by pidp Wave (Spell), sort: gen End_Type=End_Ind[_N]
		drop if Status==.m & XX==1
		by pidp Wave: egen YY=max(Status==.m)
		drop if YY==1
		drop leshne XX YY
		
		*v. Create start dates.
			// Winter is not split into two for bb_lifemst. Next section deals with this.
		replace leshsm=.m if leshsy4==.m
		gen Winter=cond(Wave==2 & leshsm==13,1,0)
		gen Start_Y=leshsy4
		gen Start_M=cond(leshsm>=1 & leshsm<=12,leshsm,.m)
		gen Start_S=.m
		replace Start_S=1 if inlist(leshsm,1,2) | (leshsm==13 & Wave!=2)
		replace Start_S=2 if inlist(leshsm,3,4,5,14)
		replace Start_S=3 if inlist(leshsm,6,7,8,15)
		replace Start_S=4 if inlist(leshsm,9,10,11,16)
		replace Start_S=5 if inlist(leshsm,12,17)
		gen Start_MY=ym(Start_Y,Start_M)
		gen Start_SY=ym(Start_Y,Start_S)
		gen Start_Flag=0
		drop leshsm leshsy4 Start_M *_S led*
		
		*vi. Impute correct season where Wave==2 & Season is Winter.
		prog_assignwinter_orig


		*ix. Run Common Life History Do File.
		gen Source="b"+substr(subinstr("`c(alpha)'"," ","",.),Wave,1)+"_lifehist"
		qui do "${do_fld}/Clean Life History.do"	

		
		save "${dta_fld}/BHPS Life History", replace
		rm "${dta_fld}/BHPS Life History - Raw.dta"
		}

	}
