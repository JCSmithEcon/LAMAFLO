/*
********************************************************************************
FTE VARIABLES - COLLECT.DO
	
	THIS FILE COLLECTS VARIABLES FROM BHPS AND UKHLS RELATED TO DATES OF
	ATTENDING/FINISHING FULL-TIME EDUCATION
	
	UPDATES APPLIED WHEN PRIORITY IS GIVEN TO WORK HISTORIES:
	* scend_dv AND feend_dv ARE USED.
	* EDUCATION END MONTH IS SET TO JUNE IF MISSING.
	
	* LW VERSION USES "$work_educ"=="educ" OPTION AND LW ORIGINAL "FTE Variables - Collect.do" (SEE BOTTOM HALF OF THIS FILE).
	
********************************************************************************
*/

if "$work_educ"=="work" | "$work_educ"=="WORK" {						// THIS CODE IN {} IS USED IF WORK HISTORIES ARE PRIORITISED. IN THE BOTTOM HALF OF THIS FILE, LW ORIGINAL CODE IS USED BELOW IF EDUCATION HISTORIES ARE PRIORITISED. THE DIFFERENCE IS ONLY THAT LW LIMITS USE OF DERIVED VARIABLES scend_dv AND feend_dv AND IN DIFFERENT PLACES SETS EDUCATION END MONTH TO JUNE, JULY OR SEPTEMBER IF MISSING.

	/*
	1. Collect Variables from indresp and cross-wave files
	*/

	#delim ;
	global schoolvars 	" school scend scnow sctype fetype fenow fenow_bh
						feend hiqual qfhas fachi hiqual_dv
						qfhigh_dv edtypev j1none lgaped lednow
						ledendm ledendy ledeny4 edtype edlyr jbstat
						jbstat_bh edendm edendy4 qfachi qfedhi ivfio";
	#delim cr
	local a=0
	foreach survey in bhps ukhls{
		
		if "`survey'"=="bhps"	local b="b"
		else	local b=""

		forval i=1/$`survey'_waves{
		
			local a=`a'+1
			local j: word `i' of `c(alpha)'
			prog_addprefix schoolvars `b'`j' /*
				*/ "${fld}/${`survey'_path}_w`i'/`b'`j'_indresp${file_type}"
			rename `b'`j'_* *
			if "`survey'"=="bhps"{
				rename school school_bh
				capture rename edtype edtype_bh
				}
			gen Wave=`a'
			if `a'==1	replace jbstat=8 if jbstat_bh==7		// jbstat incorrect in Wave 1 (as of 31/03/2023)
			tempfile Temp`a'
			save "`Temp`a''", replace
			}
		}
	forval i=`=`a'-1'(-1)1{
		append using "`Temp`i''"
		}
	merge m:1 pidp using "${fld}/${ukhls_path}_wx/xwavedat${file_type}", /*
			*/ nogen keepusing(scend_dv feend_dv school_dv)	keep(match master)
	merge 1:1 pidp Wave using "${dta_fld}/Interview Grid", /*
			*/ nogen keepusing(IntDate_MY Birth_MY)	
	merge 1:1 pidp Wave using "${dta_fld}/BHPS Education Dates", /*
			*/ nogen

	gen Age_Y=floor((IntDate_MY-Birth_MY)/12)
	save "${dta_fld}/Education Variables", replace	


	/*
	2. Collect FTE finish data from UKHLS empstat files
	*/
	local k=0
	foreach i of global ukhls_lifehistwaves{
		local k=`k'+1
		local j: word `i' of `c(alpha)'
		use pidp *lesh* `j'_spellno using /*
			*/ "${fld}/${ukhls_path}_w`i'/`j'_empstat${file_type}", clear
		rename `j'_* *
		gen Wave=`i'+18
		tempfile Temp2_`k'
		save "`Temp2_`k''", replace
		}
	append using `Temp2_1'
	merge m:1 pidp Wave using "${dta_fld}/Interview Grid", /*
			*/ nogen keep(match master) keepusing(Birth_MY)	
	gen Start_M=	cond(leshsy4<0,.m, /*
				*/	cond(leshem<0,7, /*
				*/	cond(inrange(leshem,1,12),leshem, /*
				*/	cond(leshem==13,12, /*
				*/	cond(inrange(leshem,14,17),(leshem-14)*3+1,.m)))))
	gen Start_Y=cond(leshsy4>0,leshsy4,.m)
	gen Start_MY=ym(Start_Y,Start_M)
	gen Spell=spellno
	drop leshem leshsy4 Start_? spellno

	by pidp Wave (Spell), sort: gen N=(_n==_N)
	tab leshst N
	gen XX=Spell if !inlist(leshst,-2,-1,0,8)		// GET FIRST NON-MISSING STATUS WHICH IS NOT EDUCATION OR CURRENT STATUS REACHED. PEOPLE WITH MISSING FIRST SPELL ARE NOT FOLLOWED BY OTHER SPELLS.
	by pidp Wave (Spell), sort: egen YY=min(XX)
	by pidp Wave (Spell), sort: gen UKHLS_LH_FIN_MY=Start_MY[YY]
	keep if Spell==1 & !missing(UKHLS_LH_FIN_MY)
	keep pidp Wave UKHLS_LH_FIN_MY
	merge 1:1 pidp Wave using "${dta_fld}/Education Variables", nogen

	/*
	3. Clean Combined Data
		* Assumes academic year ends in June.
	*/
	order pidp Wave
	quietly labelbook
	label drop `r(notused)'
	numlabel _all, add
	format *MY %tm
	compress

	by pidp (Wave), sort: gen tag= (_n==1)
	prog_sort
	by pidp (Wave), sort: egen XX=max(Age_Y<15)		// DROP IF AGE IS TOO LOW (SHOULDN'T HAVE ADULT INTERVIEW BEFORE AGE 15)
	drop if XX==1 | missing(Age_Y)
	drop XX

	* i. BHPS NEW PARTICIPANTS (1)
	cls
	tab1 school_bh scend scnow fetype fenow_bh feend if Wave<=18, m	

	table scend Age_Y if scend>Age_Y & Wave<=18
	/*
	// S_1_FIN_MY
	*/
	gen S_1_FIN_MY=ym(year(dofm(Birth_MY))+scend,6) /*
		*/ if month(dofm(Birth_MY))<9 & Wave<=18 /*
		*/ & scend>0 & scend<=Age_Y								// CALCULATES SCHOOL END DATE BASED ON Birth_MY AND scend ASSUMING June, BHPS Waves, BIRTH MONTH Jan-Aug.
	replace S_1_FIN_MY=ym(year(dofm(Birth_MY))+scend+1,6) /*
		*/ if month(dofm(Birth_MY))>=9 & Wave<=18 /*
		*/ & scend>0 & scend<=Age_Y								// CALCULATES SCHOOL END DATE BASED ON Birth_MY AND scend ASSUMING June, BHPS Waves, BIRTH MONTH Sep-Dec.
	prog_monthsafterint S_1_FIN_MY								// CHECKS WHETHER SCHOOL END DATE IS AFTER INTERVIEW DATE.

	replace S_1_FIN_MY=floor((IntDate_MY/2)+(Birth_MY+scend*12)/2) if $if	
																// global if IS "`var'>IntDate_MY & !missing(`var',IntDate_MY)"
																// FOR THIS TYPE OF IMPLAUSIBLE DATE, THIS IMPUTES SCHOOL END DATE AS MIDWAY BETWEEN INTERVIEW AND SCHOOL END DATE.
	/*
	// S_1_IN_MY
	*/
	gen S_1_IN_MY=IntDate_MY if (school_bh==2 | scnow==1) & Wave<=18	// SCHOOL END DATE IS IMPUTED AS INTERVIEW DATE IF STILL AT SCHOOL.
	replace S_1_IN_MY=IntDate_MY /*
		*/ if Wave<=18 & scend>0 & scend>Age_Y & !missing(scend)	// SCHOOL END DATE IS IMPUTED AS INTERVIEW DATE IF REPORTED AGE FINISHED SCHOOL EXCEEDS AGE.
	/*
	// S_1_NO_MY. NOTE: ALTERED TO USE scend_dv HERE.
	*/
	//gen S_1_NO_MY=IntDate_MY if school_bh==1 & Wave<=18			// school_bh==1 "Never went to school". SET SCHOOL END DATE = INTERVIEW DATE. COMMENT: scend_dv IS AVAILABLE FOR SOME OF THESE CASES. scend_dv IS USED FOR S/F_10_FIN_MY BELOW (SECTION vi, WHERE IT IS NOTED THAT IT IS UNCLEAR HOW THE INFORMATION IN scend_dv IS ELICITED). UNLIKE LW'S ORIGINAL CODE, scend_dv INFORMATION IS ALSO USED HERE AS IT SEEMS PREFERABLE TO ANY OTHER ALTERNATIVE.
	gen S_1_NO_MY=ym(year(dofm(Birth_MY))+scend_dv,6) /*
		*/ if month(dofm(Birth_MY))<9 & Wave<=18 /*
		*/ & scend_dv>0 & school_bh==1 & scend_dv<=Age_Y
	replace S_1_NO_MY=ym(year(dofm(Birth_MY))+scend_dv+1,6) /*
		*/ if month(dofm(Birth_MY))>=9 & Wave<=18 /*
		*/ & scend_dv>0 & school_bh==1 & scend_dv<=Age_Y
	replace S_1_NO_MY=IntDate_MY if missing(S_1_NO_MY) & school_bh==1 & Wave<=18
	/*
	. tab scend_dv scend if school_bh==1
						  |   School
						  |  leaving
						  |    age
	   School leaving age | -8. inapp |     Total
	----------------------+-----------+----------
			  -9. missing |        67 |        67 
		 -8. inapplicable |        72 |        72 
						8 |         9 |         9 
					   12 |         1 |         1 
					   15 |         3 |         3 
					   16 |        13 |        13 
					   17 |         2 |         2 
					   18 |         1 |         1 
					   19 |         3 |         3 
					   20 |         1 |         1 
					   22 |         1 |         1 
	----------------------+-----------+----------
					Total |       173 |       173 
	*/

	table feend Age_Y if feend>Age_Y & Wave<=18
	/*
	// F_1_FIN_MY
	*/
	gen F_1_FIN_MY=ym(year(dofm(Birth_MY))+feend,6) /*
		*/ if month(dofm(Birth_MY))<9 & Wave<=18 /*
		*/ & feend>0 & feend<=Age_Y								// CALCULATES FE END DATE BASED ON Birth_MY AND feend ASSUMING June, BHPS Waves, BIRTH MONTH Jan-Aug.
	replace F_1_FIN_MY=ym(year(dofm(Birth_MY))+feend+1,6) /*
		*/ if month(dofm(Birth_MY))>=9 & Wave<=18 /*
		*/ & feend>0 & feend<=Age_Y								// CALCULATES FE END DATE BASED ON Birth_MY AND feend ASSUMING June, BHPS Waves, BIRTH MONTH Sep-Dec.
	prog_monthsafterint F_1_FIN_MY								// CHECKS WHETHER FE END DATE IS AFTER INTERVIEW DATE.
	replace F_1_FIN_MY=floor((IntDate_MY/2)+(Birth_MY+feend*12)/2) if $if
																// global if IS "`var'>IntDate_MY & !missing(`var',IntDate_MY)"
																// FOR THIS TYPE OF IMPLAUSIBLE DATE, THIS IMPUTES FE END DATE AS MIDWAY BETWEEN INTERVIEW AND SCHOOL END DATE
	/*
	// F_1_IN_MY
	*/
	gen F_1_IN_MY=IntDate_MY if fenow_bh==1 & Wave<=18			// SETS FE END DATE = INTERVIEW DATE IF STILL IN FE.
	replace F_1_IN_MY=IntDate_MY /*
		*/ if Wave<=18 & feend>0 & feend>Age_Y & !missing(feend)	// SETS FE END DATE = INTERVIEW DATE IF AGE FINISHED FE EXCEEDS AGE.
	/*
	// F_1_NO_MY. NOTE: ALTERED TO USE feend_dv HERE.				
	*/
	//gen F_1_NO_MY=IntDate_MY if fetype==7 & Wave<=18			// fetype==7 "None of the above". IGNORES UNUSUAL FE TYPE; SETS FE END DATE = INTERVIEW DATE.
	gen F_1_NO_MY=ym(year(dofm(Birth_MY))+feend_dv,6) /*
		*/ if month(dofm(Birth_MY))<9 & Wave<=18 /*
		*/ & feend_dv>0 & fetype==7 & feend_dv<=Age_Y
	replace F_1_NO_MY=ym(year(dofm(Birth_MY))+feend_dv+1,6) /*
		*/ if month(dofm(Birth_MY))>=9 & Wave<=18 /*
		*/ & feend_dv>0 & fetype==7 & feend_dv<=Age_Y
	replace F_1_NO_MY=IntDate_MY if missing(F_1_NO_MY) & fetype==7 & Wave<=18
	/*
	. tab feend_dv if fetype==7
			 Further |
		   education |
		 leaving age |      Freq.     Percent        Cum.
	-----------------+-----------------------------------
		 -9. missing |     17,569       98.50       98.50
				  14 |          4        0.02       98.52
				  15 |          2        0.01       98.53
				  16 |         25        0.14       98.67
				  17 |         22        0.12       98.79
				  18 |         60        0.34       99.13
				  19 |         27        0.15       99.28
				  20 |         26        0.15       99.43
				  21 |         22        0.12       99.55
				  22 |         11        0.06       99.61
				  23 |          7        0.04       99.65
				  24 |          4        0.02       99.67
				  25 |          4        0.02       99.70
				  26 |          1        0.01       99.70
				  27 |          3        0.02       99.72
				  28 |          5        0.03       99.75
				  29 |          1        0.01       99.75
				  30 |          1        0.01       99.76
				  31 |          2        0.01       99.77
				  32 |          3        0.02       99.79
				  33 |          1        0.01       99.79
				  34 |          1        0.01       99.80
				  35 |          1        0.01       99.80
				  39 |          2        0.01       99.81
				  40 |          2        0.01       99.83
				  41 |          2        0.01       99.84
				  42 |         17        0.10       99.93
				  43 |          2        0.01       99.94
				  44 |          4        0.02       99.97
				  45 |          2        0.01       99.98
				  46 |          2        0.01       99.99
				  53 |          1        0.01       99.99
				  56 |          1        0.01      100.00
	-----------------+-----------------------------------
			   Total |     17,837      100.00
	*/


	foreach i in S F{
		prog_makevars `i'_1_FIN `i'_1_IN `i'_1_NO
		}
	prog_sort
	drop school_bh scnow fenow_bh fetype

	* ii. BHPS RETURNING PARTICIPANTS [WAVE,2,7] (2)
	cls
	tab1 jbstat edlyr edendm edendy4 edtype if inrange(Wave,2,7), m		// NOTE: WAVES 2-7.
	gen XX=edendm if inrange(edendm,1,12)								// EDUC END MONTH.
	//replace XX=9 if missing(edendm) & inrange(edendy4,1991,1996)		// SETS FT EDUC END MONTH TO SEPTEMBER IF MISSING
	replace XX=6 if missing(edendm) & inrange(edendy4,1991,1996)		// NOTE ALTERATION: SETS FT EDUC END MONTH TO JUNE IF MISSING
	gen YY=edendy4 if inrange(edendy4,1991,1996)

	gen S_2_FIN_MY=ym(YY,XX) if inrange(edtype_bh,1,2) & inrange(Wave,2,7)	// CALCULATES SCHOOL END YEAR-MONTH. edtype_bh==1,2 "at school" "at sixth form college"
	gen S_2_IN_MY=IntDate_MY if inrange(edtype_bh,1,2) & inrange(Wave,2,7) /*
		*/ & (jbstat==7 | edendm==-3 | edendy4==-3)						// SETS SCHOOL END DATE = INTERVIEW DATE IF STILL AT SCHOOL. jbstat==7 "ft studt, school"; edendm==-3 "Not Left"
	prog_monthsafterint S_2_FIN_MY										// CHECKS WHETHER EDUC END DATE IS AFTER INTERVIEW DATE. HERE NOTHING IS DONE IF THE EDUC END DATE IS AFTER INTERVIEW DATE.

	gen F_2_FIN_MY=ym(YY,XX) if inrange(edtype_bh,3,5) & inrange(Wave,2,7)	//  CALCULATES FE END YEAR-MONTH. edtype_bh==3,5 "at fe college" "at university"
	gen F_2_IN_MY=IntDate_MY if inrange(edtype_bh,3,5) & inrange(Wave,2,7) /*
		*/ & (jbstat==7 | edendm==-3 | edendy4==-3)						// SETS FE END DATE = INTERVIEW DATE IF STILL IN FT EDUC.
	prog_monthsafterint F_2_FIN_MY										// CHECKS WHETHER EDUC END DATE IS AFTER INTERVIEW DATE. HERE NOTHING IS DONE IF THE EDUC END DATE IS AFTER INTERVIEW DATE.

	foreach i in S F{
		prog_makevars `i'_2_FIN `i'_2_IN								// GENERATES Source, Wave, Qual[IFICATIONS] (LABELLED) FOR EDUCATION START/END DATES.
		}
	prog_sort															// SORTS THE DATA pidp Wave *MY AND FORMATS *MY AS MONTHLY DATE VARIABLES.
	drop edendm edendy4 XX YY

	* iii. UKHLS NEW PARTICIPANTS (5)									// AS ABOVE. NOTE: S_5_NO_MY AND S_5_NO_MY ARE ALTERED TO USE scend_dv AND feend_dv HERE.
	cls								
	tab1 school scend fenow feend if Wave>18, m

	table scend Age_Y if scend>Age_Y & Wave>18
	gen S_5_FIN_MY=ym(year(dofm(Birth_MY))+scend,6) /*
		*/ if month(dofm(Birth_MY))<9 & Wave>18 /*
		*/ & scend>0 & scend<=Age_Y
	replace S_5_FIN_MY=ym(year(dofm(Birth_MY))+scend+1,6) /*
		*/ if month(dofm(Birth_MY))>=9 & Wave>18 /*
		*/ & scend>0 & scend<=Age_Y	
	gen S_5_IN_MY=IntDate_MY if school==3 & Wave>18
	replace S_5_IN_MY=IntDate_MY /*
		*/ if Wave>18 & scend>0 & scend>Age_Y & !missing(feend)
	//gen S_5_NO_MY=IntDate_MY if school==2 & Wave>18					// school==2 "Never went to school". SET SCHOOL END DATE = INTERVIEW DATE. COMMENT: scend_dv IS AVAILABLE FOR SOME OF THESE CASES. scend_dv IS USED FOR S/F_10_FIN_MY BELOW (SECTION vi, WHERE IT IS NOTED THAT IT IS UNCLEAR HOW THE INFORMATION IN scend_dv IS ELICITED). UNLIKE LW'S ORIGINAL CODE, scend_dv INFORMATION IS ALSO USED HERE AS IT SEEMS PREFERABLE TO ANY OTHER ALTERNATIVE.
	gen S_5_NO_MY=ym(year(dofm(Birth_MY))+scend_dv,6) /*
		*/ if month(dofm(Birth_MY))<9 & Wave>18 /*
		*/ & scend_dv>0 & school==2 & scend_dv<=Age_Y
	replace S_5_NO_MY=ym(year(dofm(Birth_MY))+scend_dv+1,6) /*
		*/ if month(dofm(Birth_MY))>=9 & Wave>18 /*
		*/ & scend_dv>0 & school==2 & scend_dv<=Age_Y
	replace S_5_NO_MY=IntDate_MY if missing(S_5_NO_MY) & school==2 & Wave>18
	/*
	. tab scend_dv if school==2
			 School leaving age |      Freq.     Percent        Cum.
	----------------------------+-----------------------------------
			   -8. inapplicable |        619       83.09       83.09
	0. left school, age missing |          3        0.40       83.49
							 10 |          7        0.94       84.43
							 11 |          1        0.13       84.56
							 12 |         10        1.34       85.91
							 13 |          3        0.40       86.31
							 14 |         18        2.42       88.72
							 15 |         14        1.88       90.60
							 16 |         42        5.64       96.24
							 17 |          6        0.81       97.05
							 18 |         13        1.74       98.79
							 19 |          4        0.54       99.33
							 20 |          5        0.67      100.00
	----------------------------+-----------------------------------
						  Total |        745      100.00
	*/
	prog_monthsafterint S_5_FIN_MY
	replace S_5_FIN_MY=floor((IntDate_MY/2)+(Birth_MY+scend*12)/2) if $if

	table feend Age_Y if feend>Age_Y & Wave>18
	gen F_5_FIN_MY=ym(year(dofm(Birth_MY))+feend,6) /*
		*/ if month(dofm(Birth_MY))<9 & Wave>18 /*
		*/ & feend>0 & feend<=Age_Y
	replace F_5_FIN_MY=ym(year(dofm(Birth_MY))+feend+1,6) /*
		*/ if month(dofm(Birth_MY))>=9 & Wave>18 /*
		*/ & feend>0 & feend<=Age_Y
	gen F_5_IN_MY=IntDate_MY if fenow==3 & Wave>18
	replace F_5_IN_MY=IntDate_MY /*
		*/ if Wave>18 & feend>0 & feend>Age_Y & !missing(scend)
	//gen F_5_NO_MY=IntDate_MY if fenow==2 & Wave>18					// NOTE: ALTERED TO USE feend_dv HERE.
	gen F_5_NO_MY=ym(year(dofm(Birth_MY))+feend_dv,6) /*
		*/ if month(dofm(Birth_MY))<9 & Wave>18 /*
		*/ & feend_dv>0 & fenow==2 & feend_dv<=Age_Y
	replace F_5_NO_MY=ym(year(dofm(Birth_MY))+feend_dv+1,6) /*
		*/ if month(dofm(Birth_MY))>=9 & Wave>18 /*
		*/ & feend_dv>0 & fenow==2 & feend_dv<=Age_Y
	replace F_5_NO_MY=IntDate_MY if missing(F_5_NO_MY) & fenow==2 & Wave>18
	/*
	. tab feend_dv if fenow==2
			 Further |
		   education |
		 leaving age |      Freq.     Percent        Cum.
	-----------------+-----------------------------------
		 -9. missing |     30,533       94.78       94.78
				  12 |          2        0.01       94.78
				  14 |          5        0.02       94.80
				  15 |         22        0.07       94.87
				  16 |         99        0.31       95.17
				  17 |        264        0.82       95.99
				  18 |        467        1.45       97.44
				  19 |        172        0.53       97.98
				  20 |        142        0.44       98.42
				  21 |        138        0.43       98.85
				  22 |         84        0.26       99.11
				  23 |         48        0.15       99.26
				  24 |         37        0.11       99.37
				  25 |         31        0.10       99.47
				  26 |         10        0.03       99.50
				  27 |          9        0.03       99.53
				  28 |         16        0.05       99.57
				  29 |         10        0.03       99.61
				  30 |         13        0.04       99.65
				  31 |          7        0.02       99.67
				  32 |         14        0.04       99.71
				  33 |          3        0.01       99.72
				  34 |          9        0.03       99.75
				  35 |          9        0.03       99.78
				  36 |          7        0.02       99.80
				  37 |          5        0.02       99.81
				  38 |          7        0.02       99.84
				  39 |          5        0.02       99.85
				  40 |          9        0.03       99.88
				  41 |          3        0.01       99.89
				  42 |          2        0.01       99.89
				  43 |          6        0.02       99.91
				  44 |          3        0.01       99.92
				  45 |          3        0.01       99.93
				  46 |          6        0.02       99.95
				  47 |          1        0.00       99.95
				  48 |          3        0.01       99.96
				  49 |          2        0.01       99.97
				  51 |          1        0.00       99.97
				  52 |          2        0.01       99.98
				  53 |          1        0.00       99.98
				  57 |          1        0.00       99.98
				  59 |          1        0.00       99.99
				  61 |          2        0.01       99.99
				  65 |          1        0.00      100.00
				  67 |          1        0.00      100.00
	-----------------+-----------------------------------
			   Total |     32,216      100.00
	*/
	prog_monthsafterint F_5_FIN_MY
	replace F_5_FIN_MY=floor((IntDate_MY/2)+(Birth_MY+feend*12)/2) if $if

	foreach i in S F{
		prog_makevars `i'_5_FIN `i'_5_IN `i'_5_NO
		}
	prog_sort
	drop school scend fenow feend

	* iv. UKHLS ALL PARTICIPANTS (6)									// AS ABOVE.
	cls								
	tab1 jbstat edtype if Wave>18, m
	gen S_6_IN_MY=IntDate_MY if inrange(edtype,1,2) & Wave>18
	gen F_6_IN_MY=IntDate_MY if inrange(edtype,3,5) & Wave>18

	prog_makevars S_6_IN F_6_IN
	prog_sort
	drop jbstat edtype

	* v. LIFE HISTORY (LH)												// NOTE ALTERATION IN IMPUTED END MONTH AND USE OF scend_dv AND feend_dv.
	cls
	tab1 ledendm ledendy ledeny4 lgaped lednow /*
		*/ if inlist(Wave,2,11,12,19,23), m
	//gen XX=		cond(ledeny4<0,.m, /*
			*/	cond(ledendm<0,7, /*									// SETS EDUC END MONTH TO JULY IF MISSING.
			*/	cond(inrange(ledendm,1,12),ledendm, /*
			*/	cond(ledendm==13,7, /*
			*/	cond(inrange(ledendm,14,16),(ledendm-13)*3+1,.m)))))
	gen XX=		cond(ledeny4<0,.m, /*									// NOTE ALTERATION: SETS EDUC END MONTH TO JUNE IF MISSING.
			*/	cond(ledendm<0,6, /*
			*/	cond(inrange(ledendm,1,12),ledendm, /*
			*/	cond(ledendm==13,6, /*
			*/	cond(inrange(ledendm,14,16),(ledendm-13)*3+1,.m)))))
	gen YY=cond(inrange(ledeny4,1890,2009),ledeny4,.m)
	gen LH_FIN_MY=ym(YY,XX)
	replace LH_FIN_MY=UKHLS_LH_FIN_MY if !missing(UKHLS_LH_FIN_MY)
	//gen LH_IN_MY=IntDate_MY if lgaped==2 | lednow==0					// lgaped=2 "Left FTE before start FE" ; lednow=0 "Still in FTE".
	gen LH_IN_MY=ym(year(dofm(Birth_MY))+scend_dv,6) /*					// NOTE ALTERATION: scend_dv AND feend_dv ARE USED WHERE AVAILABLE.
		*/ if month(dofm(Birth_MY))<9 /*
		*/ & (lgaped==2 | lednow==0) & scend_dv>0 & scend_dv<=Age_Y
	replace LH_IN_MY=ym(year(dofm(Birth_MY))+scend_dv+1,6) /*
		*/ if month(dofm(Birth_MY))>=9 /*
		*/ & (lgaped==2 | lednow==0) & scend_dv>0 & scend_dv<=Age_Y
	replace LH_IN_MY=ym(year(dofm(Birth_MY))+feend_dv,6) /*
		*/ if month(dofm(Birth_MY))<9 /*
		*/ & lednow==0 & feend_dv>0 & feend_dv<=Age_Y & feend_dv>scend_dv
	replace LH_IN_MY=ym(year(dofm(Birth_MY))+feend_dv+1,6) /*
		*/ if month(dofm(Birth_MY))>=9 /*
		*/ & lednow==0 & feend_dv>0 & feend_dv<=Age_Y & feend_dv>scend_dv
	replace LH_IN_MY=ym(year(dofm(Birth_MY))+feend_dv,6) /*				// AGE LEFT FTE (FE) RESTRICTED TO <=28 IF lgaped==2 ("LEFT FTE BEFORE STARTING FE").
		*/ if month(dofm(Birth_MY))<9 /*
		*/ & lgaped==2 & feend_dv>0 & feend_dv<=28 & feend_dv>scend_dv	
	replace LH_IN_MY=ym(year(dofm(Birth_MY))+feend_dv+1,6) /*
		*/ if month(dofm(Birth_MY))>=9 /*
		*/ & lgaped==2 & feend_dv>0 & feend_dv<=28 & feend_dv>scend_dv
	replace LH_IN_MY=IntDate_MY if missing(LH_IN_MY) & (lgaped==2 | lednow==0)
	/*
	. tab scend_dv if lednow==0 | lgaped==2
			 School leaving age |      Freq.     Percent        Cum.
	----------------------------+-----------------------------------
					-9. missing |         13        0.54        0.54
			   -8. inapplicable |        551       22.98       23.52
	0. left school, age missing |         88        3.67       27.19
							 10 |          1        0.04       27.23
							 11 |          2        0.08       27.31
							 12 |          1        0.04       27.36
							 13 |          2        0.08       27.44
							 14 |         18        0.75       28.19
							 15 |        128        5.34       33.53
							 16 |        674       28.11       61.63
							 17 |        209        8.72       70.35
							 18 |        464       19.35       89.70
							 19 |        164        6.84       96.54
							 20 |         67        2.79       99.33
							 21 |         12        0.50       99.83
							 22 |          4        0.17      100.00
	----------------------------+-----------------------------------
						  Total |      2,398      100.00

	. tab feend_dv if lednow==0 | lgaped==2
			 Further |
		   education |
		 leaving age |      Freq.     Percent        Cum.
	-----------------+-----------------------------------
		 -9. missing |      1,672       69.72       69.72
				  16 |          4        0.17       69.89
				  17 |         22        0.92       70.81
				  18 |        107        4.46       75.27
				  19 |         85        3.54       78.82
				  20 |         53        2.21       81.03
				  21 |        120        5.00       86.03
				  22 |        141        5.88       91.91
				  23 |         79        3.29       95.20
				  24 |         33        1.38       96.58
				  25 |         26        1.08       97.66
				  26 |         15        0.63       98.29
				  27 |         12        0.50       98.79
				  28 |          5        0.21       99.00
				  29 |          4        0.17       99.17
				  31 |          2        0.08       99.25
				  32 |          4        0.17       99.42
				  33 |          2        0.08       99.50
				  34 |          1        0.04       99.54
				  35 |          2        0.08       99.62
				  37 |          1        0.04       99.67
				  38 |          1        0.04       99.71
				  39 |          1        0.04       99.75
				  40 |          2        0.08       99.83
				  45 |          1        0.04       99.87
				  48 |          1        0.04       99.92
				  50 |          1        0.04       99.96
				  59 |          1        0.04      100.00
	-----------------+-----------------------------------
			   Total |      2,398      100.00

	*/
	//gen LH_NO_MY=IntDate_MY if lednow==1								// lednow==1 "Never went to school"
	gen LH_NO_MY=ym(year(dofm(Birth_MY))+scend_dv,6) /*					// NOTE ALTERATION: scend_dv AND feend_dv ARE USED
		*/ if month(dofm(Birth_MY))<9 /*
		*/ & lednow==1 & scend_dv>0 & scend_dv<=Age_Y
	replace LH_NO_MY=ym(year(dofm(Birth_MY))+scend_dv+1,6) /*
		*/ if month(dofm(Birth_MY))>=9 /*
		*/ & lednow==1 & scend_dv>0 & scend_dv<=Age_Y
	replace LH_NO_MY=ym(year(dofm(Birth_MY))+feend_dv,6) /*
		*/ if month(dofm(Birth_MY))<9 /*
		*/ & lednow==1 & feend_dv>0 & feend_dv<=18 & feend_dv>scend_dv
	replace LH_NO_MY=ym(year(dofm(Birth_MY))+feend_dv+1,6) /*
		*/ if month(dofm(Birth_MY))>=9 /*
		*/ & lednow==1 & feend_dv>0 & feend_dv<=18 & feend_dv>scend_dv	// AGE LEFT FTE (FE) RESTRICTED TO <=18 IF lednow==1 ("NEVER WENT TO SCHOOL") (SEE TABULATION).
	replace LH_NO_MY=IntDate_MY if missing(LH_NO_MY) & lednow==1
	/*
	. tab scend_dv feend_dv if lednow==1, missing
						  |        Further education leaving age
	   School leaving age | -9. missi         18         24         35 |     Total
	----------------------+--------------------------------------------+----------
		 -8. inapplicable |         3          0          0          1 |         4 
					   15 |         0          1          1          0 |         2 
	----------------------+--------------------------------------------+----------
					Total |         3          1          1          1 |         6 
	*/

	prog_makevars LH_IN LH_FIN LH_NO
	prog_sort
	drop ledendm ledendy ledeny4 lgaped lednow XX YY UKHLS_LH_FIN_MY

	* vi. CROSS-WAVE (10) (UNCLEAR HOW THIS IS ELICITED)				// USES scend_dv AND feend_dv PLUS AGE TO CALCULATE FTE END DATES.
	gen S_10_FIN_MY=ym(year(dofm(Birth_MY))+scend_dv,6) /*
		*/ if month(dofm(Birth_MY))<9 & scend_dv>0
	replace S_10_FIN_MY=ym(year(dofm(Birth_MY))+scend_dv+1,6) /*		// CORRECTED ERROR (MISSING "_dv": SHOULD BE scend_dv RATHER THAN scend)
		*/ if month(dofm(Birth_MY))>=9 & scend_dv>0
	//replace S_10_FIN_MY=ym(year(dofm(Birth_MY))+scend+1,6) /*
		*/ if month(dofm(Birth_MY))>=9 & scend_dv>0
	gen F_10_FIN_MY=ym(year(dofm(Birth_MY))+feend_dv,6) /*
		*/ if month(dofm(Birth_MY))<9 & feend_dv>0
	replace F_10_FIN_MY=ym(year(dofm(Birth_MY))+feend_dv+1,6) /*
		*/ if month(dofm(Birth_MY))>=9 & feend_dv>0
		
	prog_makevars S_10_FIN F_10_FIN
	prog_sort
	drop scend_dv feend_dv school_dv

	* vi. MISCELLANEOUS QUESTION										// j1none "Still in full-time education / never had a job" IS ASKED IN UKHLS WAVES 2 ONWARDS.
	gen M_IN_MY=IntDate_MY if j1none==1
	prog_sort
	drop j1none

	drop edlyr sctype qfhas edtype_bh jbstat_bh *edtype
	compress
		
	save "${dta_fld}/Education Variables - Formatted" , replace

	}


else if "$work_educ"=="educ" | "$work_educ"=="EDUC" {						// IF EDUCATION HISTORIES ARE PRIORITISED, USES LW ORIGINAL CODE WITH MINOR ERROR CORRECTED (VERY SIMILAR TO THE ABOVE APART FROM NON-USE OF scend_dv AND feend_dv IN MORE PLACES, AND SOMETIMES SETTING SCHOOL END MONTH TO JULY OR SEPTEMBER RATHER THAN JUNE).

	/*
	********************************************************************************
	FTE VARIABLES - COLLECT.DO
		
		THIS FILE COLLECTS VARIABLES FROM BHPS AND UKHLS RELATED TO DATES OF
		ATTENDING/FINISHING FULL-TIME EDUCATION

	********************************************************************************
	*/


	/*
	1. Collect Variables from indresp and cross-wave files
	*/
	/**/
	#delim ;
	global schoolvars 	" school scend scnow sctype fetype fenow fenow_bh
						feend hiqual qfhas fachi hiqual_dv
						qfhigh_dv edtypev j1none lgaped lednow
						ledendm ledendy ledeny4 edtype edlyr jbstat
						jbstat_bh edendm edendy4 qfachi qfedhi ivfio";
	#delim cr
	local a=0
	foreach survey in bhps ukhls{
		
		if "`survey'"=="bhps"	local b="b"
		else	local b=""

		forval i=1/$`survey'_waves{
		
			local a=`a'+1
			local j: word `i' of `c(alpha)'
			prog_addprefix schoolvars `b'`j' /*
				*/ "${fld}/${`survey'_path}_w`i'/`b'`j'_indresp${file_type}"
			rename `b'`j'_* *
			if "`survey'"=="bhps"{
				rename school school_bh
				capture rename edtype edtype_bh
				}
			gen Wave=`a'
			if `a'==1	replace jbstat=8 if jbstat_bh==7		// jbstat incorrect in Wave 1 (as of 02/10/2019)
			tempfile Temp`a'
			save "`Temp`a''", replace
			}
		}
	forval i=`=`a'-1'(-1)1{
		append using "`Temp`i''"
		}
	merge m:1 pidp using "${fld}/${ukhls_path}_wx/xwavedat${file_type}", /*
			*/ nogen keepusing(scend_dv feend_dv school_dv)	keep(match master)
	merge 1:1 pidp Wave using "${dta_fld}/Interview Grid", /*
			*/ nogen keepusing(IntDate_MY Birth_MY)	
	merge 1:1 pidp Wave using "${dta_fld}/BHPS Education Dates", /*
			*/ nogen
	gen Age_Y=floor((IntDate_MY-Birth_MY)/12)
	save "${dta_fld}/Education Variables", replace	
	*/

	/*
	2. Collect FTE finish data from UKHSL empstat files
	*/
	local k=0
	foreach i of global ukhls_lifehistwaves{
		local k=`k'+1
		local j: word `i' of `c(alpha)'
		use pidp *lesh* `j'_spellno using /*
			*/ "${fld}/${ukhls_path}_w`i'/`j'_empstat${file_type}", clear
		rename `j'_* *
		gen Wave=`i'+18
		tempfile Temp2_`k'
		save "`Temp2_`k''", replace
		}
	append using `Temp2_1'
	merge m:1 pidp Wave using "${dta_fld}/Interview Grid", /*
			*/ nogen keep(match master) keepusing(Birth_MY)	
	gen Start_M=	cond(leshsy4<0,.m, /*
				*/	cond(leshem<0,7, /*
				*/	cond(inrange(leshem,1,12),leshem, /*
				*/	cond(leshem==13,12, /*
				*/	cond(inrange(leshem,14,17),(leshem-14)*3+1,.m)))))
	gen Start_Y=cond(leshsy4>0,leshsy4,.m)
	gen Start_MY=ym(Start_Y,Start_M)
	gen Spell=spellno
	drop leshem leshsy4 Start_? spellno

	by pidp Wave (Spell), sort: gen N=(_n==_N)
	tab leshst N
	gen XX=Spell if !inlist(leshst,-2,-1,0,8)		// GET FIRST NON-MISSING STATUS WHICH IS NOT EDUCATION OR CURRENT STATUS REACHED. PEOPLE WITH MISSING FIRST SPELL ARE NOT FOLLOWED BY OTHER SPELLS.
	by pidp Wave (Spell), sort: egen YY=min(XX)
	by pidp Wave (Spell), sort: gen UKHLS_LH_FIN_MY=Start_MY[YY]
	keep if Spell==1 & !missing(UKHLS_LH_FIN_MY)
	keep pidp Wave UKHLS_LH_FIN_MY
	merge 1:1 pidp Wave using "${dta_fld}/Education Variables", nogen

	/*
	3. Clean Combined Data
		* Assumes academic year ends in June.
	*/
	order pidp Wave
	quietly labelbook
	label drop `r(notused)'
	numlabel _all, add
	format *MY %tm
	compress

	by pidp (Wave), sort: gen tag= (_n==1)
	prog_sort
	by pidp (Wave), sort: egen XX=max(Age_Y<15)		// DROP IF HAS AGE IS TOO LOW (SHOULDN'T HAVE ADULT INTERVIEW BEFORE AGE 15)
	drop if XX==1 | missing(Age_Y)
	drop XX

	* i. BHPS NEW PARTICIPANTS (1)
	cls
	tab1 school_bh scend scnow fetype fenow_bh feend if Wave<=18, m

	table scend Age_Y if scend>Age_Y & Wave<=18
	gen S_1_FIN_MY=ym(year(dofm(Birth_MY))+scend,6) /*
		*/ if month(dofm(Birth_MY))<9 & Wave<=18 /*
		*/ & scend>0 & scend<=Age_Y
	replace S_1_FIN_MY=ym(year(dofm(Birth_MY))+scend+1,6) /*
		*/ if month(dofm(Birth_MY))>=9 & Wave<=18 /*
		*/ & scend>0 & scend<=Age_Y	
	prog_monthsafterint S_1_FIN_MY
	replace S_1_FIN_MY=floor((IntDate_MY/2)+(Birth_MY+scend*12)/2) if $if
	gen S_1_IN_MY=IntDate_MY if (school_bh==2 | scnow==1) & Wave<=18
	replace S_1_IN_MY=IntDate_MY /*
		*/ if Wave<=18 & scend>0 & scend>Age_Y & !missing(scend)
	gen S_1_NO_MY=IntDate_MY if school_bh==1 & Wave<=18

	table feend Age_Y if feend>Age_Y & Wave<=18
	gen F_1_FIN_MY=ym(year(dofm(Birth_MY))+feend,6) /*
		*/ if month(dofm(Birth_MY))<9 & Wave<=18 /*
		*/ & feend>0 & feend<=Age_Y
	replace F_1_FIN_MY=ym(year(dofm(Birth_MY))+feend+1,6) /*
		*/ if month(dofm(Birth_MY))>=9 & Wave<=18 /*
		*/ & feend>0 & feend<=Age_Y
	prog_monthsafterint F_1_FIN_MY
	replace F_1_FIN_MY=floor((IntDate_MY/2)+(Birth_MY+feend*12)/2) if $if
	gen F_1_IN_MY=IntDate_MY if fenow_bh==1 & Wave<=18
	replace F_1_IN_MY=IntDate_MY /*
		*/ if Wave<=18 & feend>0 & feend>Age_Y & !missing(feend)
	gen F_1_NO_MY=IntDate_MY if fetype==7 & Wave<=18

	foreach i in S F{
		prog_makevars `i'_1_FIN `i'_1_IN `i'_1_NO
		}
	prog_sort
	drop school_bh scnow fenow_bh fetype

	* ii. BHPS RETURNING PARTICIPANTS [WAVE,2,7] (2)
	cls
	tab1 jbstat edlyr edendm edendy4 edtype if inrange(Wave,2,7), m
	gen XX=edendm if inrange(edendm,1,12)
	replace XX=9 if missing(edendm) & inrange(edendy4,1991,1996)
	gen YY=edendy4 if inrange(edendy4,1991,1996)

	gen S_2_FIN_MY=ym(YY,XX) if inrange(edtype_bh,1,2) & inrange(Wave,2,7)
	gen S_2_IN_MY=IntDate_MY if inrange(edtype_bh,1,2) & inrange(Wave,2,7) /*
		*/ & (jbstat==7 | edendm==-3 | edendy4==-3)
	prog_monthsafterint S_2_FIN_MY

	gen F_2_FIN_MY=ym(YY,XX) if inrange(edtype_bh,3,5) & inrange(Wave,2,7)
	gen F_2_IN_MY=IntDate_MY if inrange(edtype_bh,3,5) & inrange(Wave,2,7) /*
		*/ & (jbstat==7 | edendm==-3 | edendy4==-3)
	prog_monthsafterint F_2_FIN_MY

	foreach i in S F{
		prog_makevars `i'_2_FIN `i'_2_IN
		}
	prog_sort
	drop edendm edendy4 XX YY

	* iii. UKHLS NEW PARTICIPANTS (5)
	cls
	tab1 school scend fenow feend if Wave>18, m

	table scend Age_Y if scend>Age_Y & Wave>18
	gen S_5_FIN_MY=ym(year(dofm(Birth_MY))+scend,6) /*
		*/ if month(dofm(Birth_MY))<9 & Wave>18 /*
		*/ & scend>0 & scend<=Age_Y
	replace S_5_FIN_MY=ym(year(dofm(Birth_MY))+scend+1,6) /*
		*/ if month(dofm(Birth_MY))>=9 & Wave>18 /*
		*/ & scend>0 & scend<=Age_Y	
	gen S_5_IN_MY=IntDate_MY if school==3 & Wave>18
	replace S_5_IN_MY=IntDate_MY /*
		*/ if Wave>18 & scend>0 & scend>Age_Y & !missing(feend)
	gen S_5_NO_MY=IntDate_MY if school==2 & Wave>18
	prog_monthsafterint S_5_FIN_MY
	replace S_5_FIN_MY=floor((IntDate_MY/2)+(Birth_MY+scend*12)/2) if $if

	table feend Age_Y if feend>Age_Y & Wave>18
	gen F_5_FIN_MY=ym(year(dofm(Birth_MY))+feend,6) /*
		*/ if month(dofm(Birth_MY))<9 & Wave>18 /*
		*/ & feend>0 & feend<=Age_Y
	replace F_5_FIN_MY=ym(year(dofm(Birth_MY))+feend+1,6) /*
		*/ if month(dofm(Birth_MY))>=9 & Wave>18 /*
		*/ & feend>0 & feend<=Age_Y
	gen F_5_IN_MY=IntDate_MY if fenow==3 & Wave>18
	replace F_5_IN_MY=IntDate_MY /*
		*/ if Wave>18 & feend>0 & feend>Age_Y & !missing(scend)
	gen F_5_NO_MY=IntDate_MY if fenow==2 & Wave>18
	prog_monthsafterint F_5_FIN_MY
	replace F_5_FIN_MY=floor((IntDate_MY/2)+(Birth_MY+feend*12)/2) if $if

	foreach i in S F{
		prog_makevars `i'_5_FIN `i'_5_IN `i'_5_NO
		}
	prog_sort
	drop school scend fenow feend

	* iv. UKHLS ALL PARTICIPANTS (6)
	cls
	tab1 jbstat edtype if Wave>18, m
	gen S_6_IN_MY=IntDate_MY if inrange(edtype,1,2) & Wave>18
	gen F_6_IN_MY=IntDate_MY if inrange(edtype,3,5) & Wave>18

	prog_makevars S_6_IN F_6_IN
	prog_sort
	drop jbstat edtype

	* v. LIFE HISTORY (7,8,9)
	cls
	tab1 ledendm ledendy ledeny4 lgaped lednow /*
		*/ if inlist(Wave,2,11,12,19,23), m
	gen XX=		cond(ledeny4<0,.m, /*
			*/	cond(ledendm<0,7, /*
			*/	cond(inrange(ledendm,1,12),ledendm, /*
			*/	cond(ledendm==13,7, /*
			*/	cond(inrange(ledendm,14,16),(ledendm-13)*3+1,.m)))))
	gen YY=cond(inrange(ledeny4,1890,2009),ledeny4,.m)
	gen LH_FIN_MY=ym(YY,XX)
	replace LH_FIN_MY=UKHLS_LH_FIN_MY if !missing(UKHLS_LH_FIN_MY)
	gen LH_IN_MY=IntDate_MY if lgaped==2 | lednow==0
	gen LH_NO_MY=IntDate_MY if lednow==1

	prog_makevars LH_IN LH_FIN LH_NO
	prog_sort
	drop ledendm ledendy ledeny4 lgaped lednow XX YY UKHLS_LH_FIN_MY

	* vi. CROSS-WAVE (10) (UNCLEAR HOW THIS IS ELICITED)
	gen S_10_FIN_MY=ym(year(dofm(Birth_MY))+scend_dv,6) /*
		*/ if month(dofm(Birth_MY))<9 & scend_dv>0
	replace S_10_FIN_MY=ym(year(dofm(Birth_MY))+scend+1,6) /*
		*/ if month(dofm(Birth_MY))>=9 & scend_dv>0
	gen F_10_FIN_MY=ym(year(dofm(Birth_MY))+feend_dv,6) /*
		*/ if month(dofm(Birth_MY))<9 & feend_dv>0
	replace F_10_FIN_MY=ym(year(dofm(Birth_MY))+feend_dv+1,6) /*
		*/ if month(dofm(Birth_MY))>=9 & feend_dv>0
		
	prog_makevars S_10_FIN F_10_FIN
	prog_sort
	drop scend_dv feend_dv school_dv

	* vi. MISCELLANEOUS QUESTION
	gen M_IN_MY=IntDate_MY if j1none==1
	prog_sort
	drop j1none

	drop edlyr sctype qfhas edtype_bh jbstat_bh *edtype
	compress
		
	save "${dta_fld}/Education Variables - Formatted" , replace
	*/

	}

