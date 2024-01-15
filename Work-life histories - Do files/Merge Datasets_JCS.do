/*
********************************************************************************
MERGE DATASETS.DO
	
	MERGES THE VARIOUS CLEANED FILES TOGETHER. PRECEDENCE IS ANNUAL>LIFE>EDUCATION,	
	WITH BHPS TAKING PRECEDENCE OVER UKHLS AS COLLECTED MORE PROXIMATELY TO SPELL.	
	
	UPDATES:
	* PRECEDENCE CHANGED FROM EDUCATION>LIFE>ANNUAL TO WORK>EDUCATION.
	* FULL-TIME EDUCATION SPELLS PRIOR TO FIRST NON-EDUCATION SPELLS ARE COMBINED.
	* FTE END DATE IS RETAINED IN THE DATA.
	* FTE END DATE IS NOT IMPOSED ON THE DATA (DOES NOT OVERWRITE OTHER SPELL START OR END DATES).
	* FURLOUGH STATUS VALUES ARE INCORPORATED WHERE RELEVANT.
			
	* CHOOSING TO PRIORITISE EDUCATION OR USING THE LW VERSION USES EDUCATION>ANNUAL>LIFE. THESE USE ORIGINAL LW CODE IN THE BOTTOM HALF OF THIS FILE.
	* USING THE LW VERSION OMITS THE OTHER ABOVE UPDATES APART FROM (IF REQUESTED ON LAUNCH) UPDATING FOR FURLOUGH. 
	
********************************************************************************
*/

if "$LW"!="LW" & "LW"!="lw" & "$work_educ"!="educ" & "$work_educ"!="EDUC" {										// THIS CODE IN {} IS USED IF WORK HISTORIES ARE PRIORITISED. LW CODE IS USED BELOW IF EDUCATION HISTORIES ARE PRIORITISED.

	/*
	1. Merge datasets together.
	*/

	local j=0
	foreach i in Annual Life Education{									// ORDER CHANGED. COMMENT: IF INTERESTED IN JUST WORK HISTORIES, IT WOULD BE POSSIBLE TO OMIT (THE MERGE WITH) EDUCATION HISTORIES. HOWEVER, ADDING EDUCATION HISTORIES DOES NOT AFFECT LABOUR MARKET HISTORIES. IT ADDS <900 TO STATUS 7 Full-Time Student (SEE TABLES BELOW THIS LOOP).
		local j=`j'+1
		local files: dir "${dta_fld}" files "*`i' History.dta", respectcase
		local k=0
		foreach file of local files{
			local k=`k'+1
			if `k'==1	use "${dta_fld}/`file'", clear
			else		append using "${dta_fld}/`file'"
			}
		prog_waveoverlap
		prog_collapsespells
		tempfile Merge`j'
		save "`Merge`j''", replace										// 1 Annual, 2 Life, 3 Education.
		}
	forval mrg=4/5{
		local tmp=0

		if `mrg'==4{
			use "`Merge1'", clear
			append using "`Merge2'", gen(Dataset)
			di in red ""
			di in red "Merging Annual and Life Histories"
			}
		if `mrg'==5{
			use "`Merge4'", clear
			append using "`Merge3'", gen(Dataset)
			di in red ""
			di in red "Merging with Education Histories"
			}		
		
		local l=cond(`mrg'==0,9,7+`mrg')
		
		drop if Status==.m
		capture drop Wave
		by pidp (Start_MY End_MY Dataset Spell), sort: replace Spell=_n	
		
		local overlap "(inrange(F_Overlap,1,4) & Dataset==1 & F_Dataset==0) | (inrange(L_Overlap,1,4) & Dataset==1 & L_Dataset==0)"

		prog_overlap														// prog_overlap FLAGS START/END DATE ISSUES ACROSS DATASETS.
		count if `overlap'
		local i=`r(N)'
		if `i'>0{					
			by pidp (Spell), sort: egen Overlap=max(`overlap')
			preserve
				drop if Overlap==1
				drop Overlap F_* L_*
				local tmp=`tmp'+1
				tempfile Temp`tmp'
				save "`Temp`tmp''", replace
			restore		
			keep if Overlap==1
			drop Overlap
			}
		local j=0
		di in red "     Iteration `j'"
		di in red "          `i' spells with overlaps remaining"
		drop F_* L_*
		
		while `i'>0{
			local j=`j'+1
			di in red "     Iteration `j'"
			foreach k in F L{
				prog_overlap
				
				drop if `k'_Overlap==1 & Dataset==1 & `k'_Dataset==0

				expand 2 if `k'_Overlap==2 & Dataset==1 & `k'_Dataset==0, gen(XX)
				replace End_MY=`k'_Start_MY if `k'_Overlap==2 & Dataset==1 & `k'_Dataset==0 & XX==0
				replace End_Flag=`l' if `k'_Overlap==2 & Dataset==1 & `k'_Dataset==0 & XX==0
				replace Start_MY=`k'_End_MY if `k'_Overlap==2 & Dataset==1 & `k'_Dataset==0 & XX==1
				replace Start_Flag=`l' if `k'_Overlap==2 & Dataset==1 & `k'_Dataset==0 & XX==1
				drop XX

				replace End_MY=`k'_Start_MY if `k'_Overlap==3 & Dataset==1 & `k'_Dataset==0
				replace End_Flag=`l' if `k'_Overlap==3 & Dataset==1 & `k'_Dataset==0
				
				replace Start_MY=`k'_End_MY if `k'_Overlap==4 & Dataset==1 & `k'_Dataset==0
				replace Start_Flag=`l' if `k'_Overlap==3 & Dataset==1 & `k'_Dataset==0

				by pidp (Start_MY End_MY Dataset Spell), sort: replace Spell=_n
				drop F_* L_*
				}			
			
			prog_overlap
			count if `overlap'
			local i=`r(N)'
			if `i'>0{					
				by pidp (Spell), sort: egen Overlap=max(`overlap')
				preserve
					drop if Overlap==1
					drop Overlap F_* L_*
					local tmp=`tmp'+1
					tempfile Temp`tmp'
					save "`Temp`tmp''", replace
				restore		
				keep if Overlap==1
				drop Overlap
				}
			di in red "          `i' spells with overlaps remaining"
			drop F_* L_*
			}
		
		forval i=1/`tmp'{
			append using "`Temp`i''"
			}
		drop Dataset
		tempfile Merge`mrg'
		save "`Merge`mrg''", replace
		}

	/*
	// USING nofurlough DATA WITH DEFAULT GLOBAL SETTINGS.
	* STATUS TABULATION USING just merge 4 DATA (ANNUAL AND LIFE HISTORIES):
						  Economic activity |      Freq.     Percent        Cum.
	----------------------------------------+-----------------------------------
						   1. Self-Employed |     30,759        6.23        6.23
						 2. Paid Employment |    241,010       48.81       55.04
							  3. Unemployed |     40,787        8.26       63.30
								 4. Retired |     34,344        6.96       70.26
						 5. Maternity Leave |      8,947        1.81       72.07
			   6. Family Carer or Homemaker |     34,536        6.99       79.06
					   7. Full-Time Student |     75,253       15.24       94.30
						8. Sick or Disabled |     12,358        2.50       96.81
					9. Govt Training Scheme |      3,371        0.68       97.49
				10. Unpaid, Family Business |        216        0.04       97.53
						 11. Apprenticeship |        378        0.08       97.61
				   97. Doing Something Else |      9,321        1.89       99.50
			100. Paid Work (Annual History) |        774        0.16       99.65
	   101. Something Else (Annual History) |         24        0.00       99.66
	103. National Service/War Service (Life |      1,686        0.34      100.00
	----------------------------------------+-----------------------------------
									  Total |    493,764      100.00

	* STATUS TABULATION BASED ON merge 4 and 5 DATA (EDUCATION HISTORIES ADDED):
						  Economic activity |      Freq.     Percent        Cum.
	----------------------------------------+-----------------------------------
						   1. Self-Employed |     30,759        6.22        6.22
						 2. Paid Employment |    241,010       48.73       54.94
							  3. Unemployed |     40,787        8.25       63.19
								 4. Retired |     34,344        6.94       70.13
						 5. Maternity Leave |      8,947        1.81       71.94
			   6. Family Carer or Homemaker |     34,536        6.98       78.92
					   7. Full-Time Student |     76,122       15.39       94.31
						8. Sick or Disabled |     12,358        2.50       96.81
					9. Govt Training Scheme |      3,371        0.68       97.49
				10. Unpaid, Family Business |        216        0.04       97.54
						 11. Apprenticeship |        378        0.08       97.61
				   97. Doing Something Else |      9,321        1.88       99.50
			100. Paid Work (Annual History) |        774        0.16       99.65
	   101. Something Else (Annual History) |         24        0.00       99.66
	103. National Service/War Service (Life |      1,686        0.34      100.00
	----------------------------------------+-----------------------------------
									  Total |    494,633      100.00
									  
	// COMPARISON: merge 4 and 5 USING THE MERGE ORDERING Education Annual Life:

						  Economic activity |      Freq.     Percent        Cum.
	----------------------------------------+-----------------------------------
						   1. Self-Employed |     30,788        6.11        6.11
						 2. Paid Employment |    241,003       47.85       53.97
							  3. Unemployed |     40,789        8.10       62.07
								 4. Retired |     34,371        6.82       68.89
						 5. Maternity Leave |      8,938        1.77       70.67
			   6. Family Carer or Homemaker |     34,650        6.88       77.55
					   7. Full-Time Student |     85,092       16.90       94.44
						8. Sick or Disabled |     12,422        2.47       96.91
					9. Govt Training Scheme |      3,325        0.66       97.57
				10. Unpaid, Family Business |        216        0.04       97.61
						 11. Apprenticeship |        372        0.07       97.69
				   97. Doing Something Else |      9,196        1.83       99.51
			100. Paid Work (Annual History) |        745        0.15       99.66
	   101. Something Else (Annual History) |         21        0.00       99.67
	103. National Service/War Service (Life |      1,686        0.33      100.00
	----------------------------------------+-----------------------------------
									  Total |    503,614      100.00
	*/	

	replace Job_Hours=.m if Job_Hours==. & inlist(Status,1,2,12,13,100,112,113,10012,10013)
	replace Job_Hours=.i if Job_Hours==. & !inlist(Status,1,2,12,13,100,112,113,10012,10013)
	sort pidp Spell
	compress
	save "${dta_fld}/Merged Dataset - Raw", replace


	prog_reopenfile "${dta_fld}/Merged Dataset - Raw"
	merge m:1 pidp using "${dta_fld}/Left Full Time Education", gen(fte_merge)	
	preserve
		use "${dta_fld}/Interview Grid", clear
		gen XX=IntDate_MY if ivfio!=2
		by pidp (Wave), sort: egen Last_IntDate_MY=max(XX)
		keep pidp Last_IntDate_MY
		duplicates drop
		drop if missing(Last_IntDate_MY)
		tempfile Temp
		save "`Temp'", replace
	restore	
	merge m:1 pidp using "`Temp'", keep(match using) gen(int_merge)
	format *MY %tm	
	order pidp Spell Start_MY End_MY Status Start_Flag End_Flag Source
	noisily table Start_Flag End_Flag, missing	

	/*
	// USING nofurlough DATA WITH DEFAULT GLOBAL SETTINGS.
	tab fte_merge	// master=data , using=fte
	   Matching result from |
					  merge |      Freq.     Percent        Cum.
	------------------------+-----------------------------------
			Master only (1) |          8        0.00        0.00
			 Using only (2) |      9,058        1.80        1.80
				Matched (3) |    494,716       98.20      100.00
	------------------------+-----------------------------------
					  Total |    503,782      100.00
					  

	tab int_merge	// master=data, using=int
	   Matching result from |
					  merge |      Freq.     Percent        Cum.
	------------------------+-----------------------------------
			 Using only (2) |         28        0.01        0.01
				Matched (3) |    503,782       99.99      100.00
	------------------------+-----------------------------------
					  Total |    503,810      100.00
					  
	*/

	drop if fte_merge==2 | int_merge==2										// NEW LINE: DROP CASES NOT IN ANNUAL/LIFE/EDUCATION HISTORIES. THIS IS DONE BECAUSE THOSE pidps HAVE NO INFORMATION USEFUL FOR WORK-LIFE HISTORIES - THOUGH THEY DO HAVE EDUCATION DATES. NOTE: LW ORIGINAL CODE RETAINED THESE CASES AND CREATED BLANK DATA FOR THEM. 
	// THE 9,058 CASES FROM FTE-ONLY HAVE THE FOLLOWING INFO: Birth_MY FTE_IN_MY FTE_IN_Source FTE_FIN_MY FTE_FIN_Source FTE_NO_MY FTE_NO_Source FTE_Source Last_IntDate_MY.
	// THE 28 CASES FROM Interview Grid-ONLY HAVE THE FOLLOWING INFO: Last_IntDate_MY.
	drop fte_merge int_merge


	* Create a blank last spell, if last recorded spell ends before last interview.
	by pidp (Spell), sort: gen XX=1 if _n==_N & End_MY<Last_IntDate_MY
	expand 2 if XX==1, gen(YY)												// THIS CREATES AN ADDITIONAL SPELL (WITH BLANK DATA APART FROM DATES) BETWEEN LAST RECORDED SPELL END DATE AND LAST INTERVIEW DATE (LAST SPELL RECORDED CAN BE BEFORE OR SAME AS INTERVIEW DATE). NOTE: End_Ind IS NOT ADJUSTED AND FOR THE NEW BLANK SPELL (STATUS .m). End_Ind WILL TAKE THE VALUE OF End_Ind[_n-1].
	/*
	// INVESTIGATION:
	order pidp Spell Start_MY End_MY IntDate_MY Last_IntDate_MY Birth_MY Last_IntDate_MY Status Source_Variable Source Start_Flag End_Flag Job_Hours Job_Change End_Ind Status_Spells
	browse if YY==1
	*/
	prog_overwritespell /*	
		*/ "YY==1" Spell+1 End_MY Last_IntDate_MY End_Flag 1 `""Gap""' .m	// THIS FILLS THE GAP AFTER THE LAST SPELL, BEFORE THE LAST INTERVIEW, WITH MISSING DATA. IT SETS Spell==Spell+1 Start_MY==End_MY End_MY==Last_IntDate_MY Start_Flag==End_Flag Source=="Gap" Status==.m. IF End_MY<Last_IntDate_MY (I.E IF LAST _N by pidp (Spell) ENDS BEFORE LAST INTERVIEW DATE).
	drop XX YY

	prog_imputemissingspells												// prog_imputemissingspells CREATES AN ADDITIONAL SPELL WITH MISSING DATA APART FROM DATES, TO FILL ANY GAP BETWEEN A SPELL End Date AND THE NEXT SPELL Start Date.


	* Create a blank first spell, if first recorded spell starts after birth.
	gen XX=(Spell==1 & Birth_MY<Start_MY)
	expand 2 if XX==1, gen(YY)												// THIS CREATES AN ADDITIONAL SPELL (WITH BLANK DATA APART FROM DATES) BETWEEN BIRTH AND FIRST RECORDED SPELL START DATE. NOTE: End_Ind IS NOT ADJUSTED AND FOR THE NEW BLANK SPELL (STATUS .m) End_Ind WILL TAKE THE VALUE OF End_Ind[_n+1].
	prog_overwritespell /*
		*/ "YY==1" 0 Birth_MY Start_MY 0 Start_Flag  `""Gap""' .m	// THIS FILLS IN A GAP BETWEEN BIRTH AND START OF FIRST SPELL. IT SETS Spell==Spell+1 Start_MY==Birth_MY End_MY==Start_MY Start_Flag==0 End_Flag==Start_Flag Source=="Gap" Status==.m. if IT'S THE FIRST SPELL AND THAT FIRST SPELL STARTS AFTER BIRTH.
	drop XX YY
	by pidp (Start_MY End_MY Spell), sort: replace Spell=_n					// RENUMBER SPELLS FOR AFFECTED pidps.


	* Create full-time education end date.
	gen FTE_MY=	cond(!missing(FTE_FIN_MY),FTE_FIN_MY,FTE_IN_MY)				// CREATES FT EDUCATION END DATE.
	format FTE_MY %tm														// ADDED LINE.


	/*
	* Collapse education spells prior to first non-education spell.			// NEW CODE. LW ORIGINAL CODE RETAINED ALL SEPARATE EDUCATION SPELLS.
	*/
	by pidp (Spell), sort: gen XX=(Status==7 & Status[_n+1]==7 & Spell==1)
	count if XX==1															// 3,006 HAVE MORE THAN ONE EDUCATION SPELL AT THE START OF THEIR HISTORIES.
	by pidp (Spell), sort: egen YY=max(XX)
	by pidp (Spell), sort: gen ZZ=(Status==7 & Status[_n+1]==7)
	by pidp, sort: gen AA=sum(ZZ)
	/*
	order pidp Spell Start_MY End_MY FTE_MY Birth_MY Status XX YY ZZ AA Start_Flag End_Flag Source
	browse if YY==1
	tab AA
			 AA |      Freq.     Percent        Cum.
	------------+-----------------------------------
			  0 |    526,124       95.53       95.53
			  1 |     23,740        4.31       99.84
			  2 |        809        0.15       99.99
			  3 |         66        0.01      100.00
			  4 |         11        0.00      100.00
	------------+-----------------------------------
		  Total |    550,750      100.00
	*/
	su AA, meanonly
	local maxXX = r(max)													// maxXX IS THE MAXIMUM NUMBER OF EDUCATION SPELLS PRIOR TO FIRST NON-EDUCATION SPELL. THESE ARE ITERATIVELY COLLAPSED INTO A SINGLE EDUCATION SPELL BY THE FOLLOWING LOOP.
	local i=1
	while `i'<`maxXX'{
		count if XX==1
		if r(N)>0{
			by pidp (Spell), sort: replace Start_MY=Start_MY[_n-1] if XX[_n-1]==1
			by pidp (Spell), sort: replace Start_Flag=Start_Flag[_n-1] if XX[_n-1]==1
			drop if XX==1																
			drop XX
			by pidp (Spell), sort: replace Spell=_n if YY==1				// RENUMBER SPELLS FOR AFFECTED pidps.
			by pidp (Spell), sort: gen XX=(Status==7 & Status[_n+1]==7 & Spell==1)
			}
		else{
			continue, break
			}
		local i=`i'+1
		}
	drop XX YY ZZ AA


	/*
	* Create an initial first spell of education, if missing.				// NEW CODE. THIS CREATES AN INITIAL EDUCATION SPELL USING FTE_MY. THERE'S NO GAIN IN _WORK_ HISTORY. THE END DATE OF THE EDUCATION SPELL IS NEVER ABOVE (SOMETIMES FTE_MY REMAINS BELOW FIRST START_MY I.E. SOMETIMES THERE IS A GAP BETWEEN FTE END DATE AND FIRST NON-EDUCATION SPELL START.
	*/
	capture program drop prog_overwritespell2
	program define prog_overwritespell2
		args if Spell Start_MY End_MY Start_Flag End_Flag Source Status
		foreach i of varlist Spell Start_MY End_MY Start_Flag End_Flag Source Status{
			replace `i'=``i'' if `if'
			}
	end
	gen XX=(Spell==1 & missing(Status) & Start_MY==End_MY & Start_MY==Birth_MY & FTE_MY<=Start_MY[_n+1])
	expand 2 if XX==1, gen(YY)
	by pid (Spell), sort: egen ZZ=max(XX)
	/*
	order pidp Spell Start_MY End_MY FTE_MY Birth_MY Status XX YY ZZ Start_Flag End_Flag Source
	browse if ZZ==1
	*/
	prog_overwritespell2 /*
		*/ "YY==1" 0 Birth_MY FTE_MY 0 13 FTE_Source 7						// THIS USES FTE_MY TO DEFINE AN EDUCATION SPELL WHEN NONE IS ALREADY DEFINED, AS LONG AS THE RECORDED FTE END DATE IS BEFORE THE START OF THE NEXT SPELL (WHICH IS A NON-EDUCATION SPELL). IT SETS Spell==0 Start_MY==Birth_MY End_MY==FTE_MY Start_Flag==0 End_Flag==FTE_Flag Source==13 Status==7.
	drop if YY==0 & XX==1	 												// THIS DROPS THE DUPLICATE SPELL WHERE AN EDUCATION SPELL HAS NOT BEEN CREATED SO START_MY STILL = BIRTH_MY.
	by pidp (Spell), sort: replace Spell=_n if ZZ==1						// RENUMBER SPELLS FOR AFFECTED pidps.
	drop XX YY ZZ

	prog_imputemissingspells												// prog_imputemissingspells CREATES AN ADDITIONAL SPELL WITH MISSING DATA APART FROM DATES, TO FILL ANY GAP BETWEEN A SPELL End Date AND THE NEXT SPELL Start Date.


	gen XX=1 if Start_MY==End_MY											// THIS SECTION OF CODE DROPS OBSERVATIONS WITH EQUAL START AND END DATES, AFTER CHECKING (THESE ARE ALL CASES WITH MISSING STATUS AND Start_MY==End_MY WHEN THE NEXT SPELL ALSO HAS Start_MY==End_MY, SO THESE CASES CONTAIN NO INFORMATION AND ARE REDUNDANT).
	by pidp (Spell), sort: egen YY=max(XX)
	tab Status if XX==1, mis
	drop if Start_MY==End_MY
	by pidp (Spell), sort: replace Spell=_n									// RENUMBER SPELLS FOR AFFECTED pidps.
	drop XX YY


	/*
	* Recode Status to 7 Full-Time Student for missing spells ending prior to stated FTE end date.
	*/
	gen XX=1 if missing(Status) & End_MY<FTE_MY & !missing(FTE_MY)			// 11,306 CASES HAVE MISSING STATUS AND END DATE PRIOR TO FTE END DATE.
	/*
	by pidp (Spell), sort: egen YY=max(XX)
	order pidp Spell Start_MY End_MY FTE_MY Birth_MY Status XX YY Start_Flag End_Flag Source
	browse if YY==1
	*/
	replace Status=7 if XX==1
	drop XX
	* The above Status change generates further consecutive education spells. Collapse these education spells (prior to first non-education spell).
	by pidp (Spell), sort: gen XX=(Status==7 & Status[_n+1]==7 & Spell==1)
	count if XX==1															// 10,772 HAVE MORE THAN ONE EDUCATION SPELL AT THE START OF THEIR HISTORIES.
	by pidp (Spell), sort: egen YY=max(XX)
	by pidp (Spell), sort: gen ZZ=(Status==7 & Status[_n+1]==7)
	by pidp, sort: gen AA=sum(ZZ)
	/*
	order pidp Spell Start_MY End_MY FTE_MY Birth_MY Status XX YY ZZ AA Start_Flag End_Flag Source
	browse if YY==1
	tab AA
			 AA |      Freq.     Percent        Cum.
	------------+-----------------------------------
			  0 |    523,589       90.64       90.64
			  1 |     51,452        8.91       99.55
			  2 |      1,686        0.29       99.84
			  3 |        781        0.14       99.98
			  4 |        114        0.02      100.00
			  5 |         13        0.00      100.00
			  6 |         11        0.00      100.00
	------------+-----------------------------------
		  Total |    577,646      100.00
	*/
	su AA, meanonly
	local maxXX = r(max)	// MAX NUMBER OF EDUCATION SPELLS PRIOR TO FIRST NON-EDUCATION SPELL. THESE ARE ITERATIVELY COLLAPSED BY THE FOLLOWING LOOP.
	local i=1
	while `i'<`maxXX'{
		count if XX==1
		if r(N)>0{
			by pidp (Spell), sort: replace Start_MY=Start_MY[_n-1] if XX[_n-1]==1
			by pidp (Spell), sort: replace Start_Flag=Start_Flag[_n-1] if XX[_n-1]==1
			drop if XX==1																
			drop XX
			by pidp (Spell), sort: replace Spell=_n if YY==1				// RENUMBER SPELLS FOR AFFECTED pidps.
			by pidp (Spell), sort: gen XX=(Status==7 & Status[_n+1]==7 & Spell==1)
			}
		else{
			continue, break
			}
		local i=`i'+1
		}
	drop XX YY ZZ AA


	/*
	expand 2 if Spell==1 & !missing(FTE_MY), gen(XX)
	prog_overwritespell /*
		*/ "XX==1" 0 Birth_MY FTE_MY 0 13  FTE_Source 7
	by pidp (Spell), sort: egen YY=max(XX)
	//replace Start_MY=FTE_MY if Start_MY<FTE_MY & YY==1 & XX!=1
	//drop if Start_MY>=End_MY												// THIS SECTION OF CODE IS NOT DONE NOT DONE: THIS WOULD TRUNCATE/ELIMINATE SPELLS BY RAISING EARLIER START DATES TO FTE DATE. THESE TWO // LINES ARE EMPHASISED TO INDICATE THAT THESE ARE THE LINES ENACTING THE KEY PART OF WHAT IS NOT DONE. THIS IS AN IMPORTANT CHANGE COMPARED TO LW: IT MEANS THAT, HERE, WORK HISTORIES ARE PRIORITISED OVER EDUCATION, IN THAT FTE END DATE IS NOT IMPOSED ON THE DATA AND ANY SPELLS STARTING BEFORE REPORTED FTE END DATE ARE NOT DROPPED.
	
	// USING nofurlough STATUS AND LW ORIGINAL "Merge Datasets.do"
	. tab Status if Start_MY>=End_MY	// USING THE ABOVE raw DATASET

						  Economic activity |      Freq.     Percent        Cum.
	----------------------------------------+-----------------------------------
						   1. Self-Employed |         77        0.12        0.12
						 2. Paid Employment |      3,215        5.18        5.30
							  3. Unemployed |        933        1.50        6.81
								 4. Retired |          1        0.00        6.81
						 5. Maternity Leave |         24        0.04        6.85
			   6. Family Carer or Homemaker |         71        0.11        6.96
					   7. Full-Time Student |     57,040       91.91       98.87
						8. Sick or Disabled |         32        0.05       98.92
					9. Govt Training Scheme |        181        0.29       99.21
				10. Unpaid, Family Business |          5        0.01       99.22
						 11. Apprenticeship |         16        0.03       99.24
				   97. Doing Something Else |        424        0.68       99.93
			100. Paid Work (Annual History) |         34        0.05       99.98
	103. National Service/War Service (Life |         11        0.02      100.00
	----------------------------------------+-----------------------------------
									  Total |     62,064      100.00
									  
	// USING LW ORIGINAL CODE TO GENERATE raw DATASET
						  Economic activity |      Freq.     Percent        Cum.
	----------------------------------------+-----------------------------------
						   1. Self-Employed |         72        0.11        0.11
						 2. Paid Employment |      3,137        4.83        4.94
							  3. Unemployed |        916        1.41        6.35
								 4. Retired |          1        0.00        6.36
						 5. Maternity Leave |         23        0.04        6.39
			   6. Family Carer or Homemaker |         68        0.10        6.50
					   7. Full-Time Student |     60,042       92.48       98.98
						8. Sick or Disabled |         33        0.05       99.03
					9. Govt Training Scheme |        176        0.27       99.30
				10. Unpaid, Family Business |          5        0.01       99.31
						 11. Apprenticeship |         15        0.02       99.33
				   97. Doing Something Else |        396        0.61       99.94
			100. Paid Work (Annual History) |         26        0.04       99.98
	103. National Service/War Service (Life |         11        0.02      100.00
	----------------------------------------+-----------------------------------
									  Total |     64,921      100.00

	// educ & furlough
	                      Economic activity |      Freq.     Percent        Cum.
----------------------------------------+-----------------------------------
                       1. Self-Employed |     30,710        5.68        5.68
                     2. Paid Employment |    237,772       44.01       49.69
                          3. Unemployed |     39,866        7.38       57.07
                             4. Retired |     34,369        6.36       63.43
                     5. Maternity Leave |      8,909        1.65       65.08
           6. Family Carer or Homemaker |     34,575        6.40       71.48
                   7. Full-Time Student |    126,649       23.44       94.92
                    8. Sick or Disabled |     12,388        2.29       97.21
                9. Govt Training Scheme |      3,149        0.58       97.79
            10. Unpaid, Family Business |        211        0.04       97.83
                     11. Apprenticeship |        357        0.07       97.90
               97. Doing Something Else |      8,793        1.63       99.52
        100. Paid Work (Annual History) |        691        0.13       99.65
   101. Something Else (Annual History) |         21        0.00       99.66
103. National Service/War Service (Life |      1,674        0.31       99.97
         112. Self-Employed on Furlough |          4        0.00       99.97
113. Self-Employed Temporarily laid off |          4        0.00       99.97
       212. Paid Employment on Furlough |        119        0.02       99.99
213. Paid Employment Temporarily laid o |         14        0.00       99.99
     10012. Empl/Self-empl and Furlough |         29        0.01      100.00
10013. Empl/Self-empl and Temporarily l |         12        0.00      100.00
----------------------------------------+-----------------------------------
                                  Total |    540,316      100.00


									  */


	count if Start_MY>=End_MY												// 0.
	//drop if Start_MY>=End_MY												// THIS DROPS ANY SPELLS FOR WHICH END DATE IS NOW EARLIER THAN START DATE.


	by pidp (Start_MY End_MY), sort: replace Spell=_n						// RENUMBER SPELLS. (0 real changes made): SPELLS ALREADY CORRECTLY NUMBERED.


	drop FTE_IN_MY FTE_IN_Source FTE_FIN_MY FTE_FIN_Source FTE_NO_MY FTE_NO_Source 	// KEEP FTE_MY FTE_Source
	rename FTE_Source Source_FTE											// ADDED LINE. RENAMES TO MATCH OTHER Source VARIABLES.


	prog_imputemissingspells												// RUN AS A CHECK. 0 CHANGES MADE: HISTORIES ARE COMPLETE.


	gen Source_Type=0
	replace Source_Type=1 if strpos(Source,"indresp")>0 | strpos(Source,"jobhist")>0
	replace Source_Type=2 if strpos(Source,"eduhist")>0
	replace Source_Type=3 if strpos(Source,"LH")>0
	replace Source_Type=3 if strpos(Source,"lifehist")>0
	replace Source_Type=4 if strpos(Source,"FTE_")>0 & strpos(Source,"LH")==0
	label values Source_Type source_type

	prog_labels
	ds pidp Source*, not
	format `r(varlist)' %9.0g
	format *MY %tm
	format Source Source_Variable Source_FTE %10s							// ALTERED FROM: format Source Source_Variable %10s
	order pidp Spell Start_MY End_MY Status *Flag Birth_MY FTE_MY IntDate_MY /*	// ALTERED FROM: order pidp Spell Start_MY End_MY Status *Flag Birth_MY IntDate_MY
		*/ Job_Hours Job_Change End_Ind Status_Spells Last_IntDate_MY /*
		*/ End_Reason* Job_Attraction* Source*


	count if Start_MY<Birth_MY & !missing(Start_MY,Birth_MY)				// THERE ARE A SMALL NUMBER OF (APPROX 10) CASES IN EUL DATA WHERE HISTORY STARTS A FEW MONTHS BEFORE BIRTH, WHICH IN EUL DATA RESULT FROM IMPUTATION OF BIRTH MONTH AS JUNE.


	compress
	label data "Activity Histories, BHPS and UKHLS"

	save "${dta_fld}/Merged Dataset", replace								//save "${dta_fld}/Merged Dataset", replace
	//rm "${dta_fld}/Merged Dataset - Raw.dta"

	}


else if "$LW"=="LW" | "$LW"=="lw" | "$work_educ"=="educ" | "$work_educ"=="EDUC" {						//  USE LW ORIGINAL CODE IF EDUCATION HISTORIES ARE PRIORITISED.

	/*
	********************************************************************************
	MERGE DATASETS.DO
		
		MERGES THE VARIOUS CLEANED FILS TOGETHER. PRECEDENCE IS EDUCATION>ANNUAL>
		LIFE, WITH BHPS TAKING PRECEDENCE OVER UKHLS AS COLLECTED MORE PROXIMATELY
		TO SPELL.	

	********************************************************************************
	*/

	/*
	1. Merge datasets together.
	*/
	/**/
	qui{
	local j=0
	foreach i in Education Annual Life{
		local j=`j'+1
		local files: dir "${dta_fld}" files "*`i' History.dta", respectcase
		local k=0
		foreach file of local files{
			local k=`k'+1
			if `k'==1	use "${dta_fld}/`file'", clear
			else		append using "${dta_fld}/`file'"
			}
		prog_waveoverlap
		prog_collapsespells
		tempfile Merge`j'
		save "`Merge`j''", replace
		}
	forval mrg=4/5{
		local tmp=0

		if `mrg'==4{
			use "`Merge1'", clear
			append using "`Merge2'", gen(Dataset)
			di in red ""
			di in red "Merging Education and Annual Histories"
			}
		if `mrg'==5{
			use "`Merge4'", clear
			append using "`Merge3'", gen(Dataset)
			di in red ""
			di in red "Merging with Life Histories"
			}		
		
		local l=cond(`mrg'==0,9,7+`mrg')
		
		drop if Status==.m
		capture drop Wave
		by pidp (Start_MY End_MY Dataset Spell), sort: replace Spell=_n	
		
		local overlap "(inrange(F_Overlap,1,4) & Dataset==1 & F_Dataset==0) | (inrange(L_Overlap,1,4) & Dataset==1 & L_Dataset==0)"

		prog_overlap
		count if `overlap'
		local i=`r(N)'
		if `i'>0{					
			by pidp (Spell), sort: egen Overlap=max(`overlap')
			preserve
				drop if Overlap==1
				drop Overlap F_* L_*
				local tmp=`tmp'+1
				tempfile Temp`tmp'
				save "`Temp`tmp''", replace
			restore		
			keep if Overlap==1
			drop Overlap
			}
		local j=0
		di in red "     Iteration `j'"
		di in red "          `i' spells with overlaps remaining"
		drop F_* L_*
		
		while `i'>0{
			local j=`j'+1
			di in red "     Iteration `j'"
			foreach k in F L{
				prog_overlap
				
				drop if `k'_Overlap==1 & Dataset==1 & `k'_Dataset==0

				expand 2 if `k'_Overlap==2 & Dataset==1 & `k'_Dataset==0, gen(XX)
				replace End_MY=`k'_Start_MY if `k'_Overlap==2 & Dataset==1 & `k'_Dataset==0 & XX==0
				replace End_Flag=`l' if `k'_Overlap==2 & Dataset==1 & `k'_Dataset==0 & XX==0
				replace Start_MY=`k'_End_MY if `k'_Overlap==2 & Dataset==1 & `k'_Dataset==0 & XX==1
				replace Start_Flag=`l' if `k'_Overlap==2 & Dataset==1 & `k'_Dataset==0 & XX==1
				drop XX

				replace End_MY=`k'_Start_MY if `k'_Overlap==3 & Dataset==1 & `k'_Dataset==0
				replace End_Flag=`l' if `k'_Overlap==3 & Dataset==1 & `k'_Dataset==0
				
				replace Start_MY=`k'_End_MY if `k'_Overlap==4 & Dataset==1 & `k'_Dataset==0
				replace Start_Flag=`l' if `k'_Overlap==3 & Dataset==1 & `k'_Dataset==0

				by pidp (Start_MY End_MY Dataset Spell), sort: replace Spell=_n
				drop F_* L_*
				}			
			
			prog_overlap
			count if `overlap'
			local i=`r(N)'
			if `i'>0{					
				by pidp (Spell), sort: egen Overlap=max(`overlap')
				preserve
					drop if Overlap==1
					drop Overlap F_* L_*
					local tmp=`tmp'+1
					tempfile Temp`tmp'
					save "`Temp`tmp''", replace
				restore		
				keep if Overlap==1
				drop Overlap
				}
			di in red "          `i' spells with overlaps remaining"
			drop F_* L_*
			}
		
		forval i=1/`tmp'{
			append using "`Temp`i''"
			}
		drop Dataset
		tempfile Merge`mrg'
		save "`Merge`mrg''", replace
		}
		

	replace Job_Hours=.m if Job_Hours==. & inlist(Status,1,2,100)
	replace Job_Hours=.i if Job_Hours==. & !inlist(Status,1,2,100)
	sort pidp Spell
	compress
	save "${dta_fld}/Merged Dataset - Raw", replace
	}
	*/


	/**/
	qui{
	prog_reopenfile "${dta_fld}/Merged Dataset - Raw"
	merge m:1 pidp using "${dta_fld}/Left Full Time Education", gen(fte_merge)	
	preserve
		use "${dta_fld}/Interview Grid", clear
		gen XX=IntDate_MY if ivfio!=2
		by pidp (Wave), sort: egen Last_IntDate_MY=max(XX)
		keep pidp Last_IntDate_MY
		duplicates drop
		drop if missing(Last_IntDate_MY)
		tempfile Temp
		save "`Temp'", replace
	restore	
	merge m:1 pidp using "`Temp'", keep(match using) gen(int_merge)
	format *MY %tm	
	order pidp Spell Start_MY End_MY Status Start_Flag End_Flag Source
	noisily table Start_Flag End_Flag, missing	

	prog_overwritespell /*
		*/ "fte_merge==2 | int_merge==2" 1 Birth_MY Last_IntDate_MY 0 1 `""Gap""' .m
	drop fte_merge int_merge

	by pidp (Spell), sort: gen XX=1 if _n==_N & End_MY<Last_IntDate_MY
	expand 2 if XX==1, gen(YY)
	prog_overwritespell /*
		*/ "YY==1" Spell+1 End_MY Last_IntDate_MY End_Flag 1 `""Gap""' .m
	drop XX YY

	prog_imputemissingspells
	gen XX=(Birth_MY<Start_MY & Spell==1)
	expand 2 if XX==1, gen(YY)
	prog_overwritespell /*
		*/ "YY==1" 0 Birth_MY Start_MY 0 Start_Flag  `""Gap""' .m
	drop XX YY

	by pidp (Start_MY End_MY Spell), sort: replace Spell=_n
	drop FTE_Source
	gen FTE_MY=	cond(!missing(FTE_FIN_MY),FTE_FIN_MY, FTE_IN_MY)
	gen FTE_Source=	cond(!missing(FTE_FIN_MY),"FTE_FIN: "+FTE_FIN_Source, /*
				*/	cond(!missing(FTE_IN_MY),"FTE_IN: "+FTE_IN_Source,""))

	expand 2 if Spell==1 & !missing(FTE_MY), gen(XX)
	prog_overwritespell /*
		*/ "XX==1" 0 Birth_MY FTE_MY 0 13  FTE_Source 7
	drop if Start_MY==End_MY
	by pidp (Spell), sort: egen YY=max(XX)
	replace Start_MY=FTE_MY if Start_MY<FTE_MY & YY==1 & XX!=1
	drop if Start_MY>=End_MY
	by pidp (Start_MY End_MY), sort: replace Spell=_n
	drop XX YY FTE*

	by pidp (Spell), sort: gen XX=1 if Status==7 & Spell==2 /*
		*/ & floor((Start_MY-Birth_MY)/12)<=19 & Status[_n-1]==.m
	replace Start_MY=Birth_MY if XX==1
	replace Start_Flag=0 if XX==1
	by pidp (Spell), sort: drop if XX[_n+1]==1
	drop XX	

	by pidp (Spell), sort: gen XX=1 if Spell==1 & End_MY-Start_MY==1 /*
	*/ & Start_MY==Birth_MY & Status[_n+1]==.m
	by pidp (Spell), sort: replace Start_MY=Start_MY-1 if XX[_n-1]==1
	drop if XX==1
	drop XX

	prog_imputemissingspells

	gen Source_Type=0
	replace Source_Type=1 if strpos(Source,"indresp")>0 | strpos(Source,"jobhist")>0
	replace Source_Type=2 if strpos(Source,"eduhist")>0
	replace Source_Type=3 if strpos(Source,"LH")>0
	replace Source_Type=3 if strpos(Source,"lifehist")>0
	replace Source_Type=4 if strpos(Source,"FTE_")>0 & strpos(Source,"LH")==0
	label values Source_Type source_type

	prog_labels
	ds pidp Source*, not
	format `r(varlist)' %9.0g
	format *MY %tm
	format Source Source_Variable %10s
	order pidp Spell Start_MY End_MY Status *Flag Birth_MY IntDate_MY /*
		*/ Job_Hours Job_Change End_Ind Status_Spells Last_IntDate_MY /*
		*/ End_Reason* Job_Attraction* Source*
	// END_IND & STATUS SPELLS NEEDS SORTING!!

	compress
	label data "Activity Histories, BHPS and UKHLS"
	save "${dta_fld}/Merged Dataset", replace
	// rm "${dta_fld}/Merged Dataset - Raw.dta"
	}
	*/
	}
