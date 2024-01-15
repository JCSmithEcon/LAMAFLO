
/*
*************************************************************************************************************************************************
*** prog_nonchron_BHPS ***

	THIS IS A NEW DO FILE THAT REPLACES PROGRAM prog_nonchron FOR BHPS DATA WHEN THE OPTION "Y" IS CHOSEN FOR global nonchron_correct.
	IT MAKES CASE-BY-CASE CORRECTION OF NON-CHRONOLOGICAL START DATES.
	
	THE FOLLOWING REFLECTS A DETAILED CHECK MADE DURING THE CHECK/RUN THROUGH OF Clean Life History_JCS.do USING BHPS DATA:
	THE BELOW CODE GOES THROUGH prog_nonchron SLOWLY AND CAREFULLY BY YEAR, SEASON AND MONTHLY DATES TO CHECK FOR NON-CHRONOLOGICAL ISSUES AND SUGGESTS CORRECTIONS THAT RETAIN DATA WHERE POSSIBLE.

*************************************************************************************************************************************************
*/

capture drop XXY
capture drop YYY
capture drop XXS
capture drop YYS
capture drop XXM
capture drop YYM

gen XXY=0
gen YYY=cond(missing(Start_Y),1,0)
by pidp Wave YYY (Spell), sort: replace XXY=1 if /*
	*/ Start_Y>Start_Y[_n+1] & !missing(Start_Y, Start_Y[_n+1])			// XXY IS 1 IF START DATE IS LATER THAN NEXT START DATE. THIS AFFECTS 1 pidp-Wave IN lifemst.
by pidp Wave (Spell), sort: egen NonChron_WaveY=max(XXY)
gen AA=Start_Y if XXY==1
gen BB=Start_Y[_n+1] if XXY==1
replace Start_Y=BB if XXY==1
replace Start_Y=AA[_n-1] if XXY[_n-1]==1
drop AA BB
replace Source_Variable="lednow_w"+strofreal(Wave)+","+"Non-Chron Start_Y corr" if XXY==1 | XXY[_n-1]==1	// ALTER Source_Variable TO REFLECT CORRECTION TO NON-CHRONOLOGICAL START YEARS
replace Start_SY = ym(Start_Y,5) if XXY==1 | XXY[_n-1]==1 & !missing(Start_S)	// RECALCULATE SEASON START DATE
replace Start_MY = ym(Start_Y,Start_M) if XXY==1 | XXY[_n-1]==1 & !missing(Start_M)

gen XXS=0
gen YYS=cond(missing(Start_SY),1,0)
by pidp Wave YYS (Spell), sort: replace XXS=1 if /*
	*/ Start_SY>Start_SY[_n+1] & !missing(Start_SY, Start_SY[_n+1])		// XXS IS 1 IF SEASON START DATE IS LATER THAN NEXT SEASON START DATE. THIS AFFECTS 12 pidp-WaveS IN lifemst.
by pidp Wave (Spell), sort: egen NonChron_WaveS=max(XXS)
//browse pidp Wave Spell XXS Start_Y Start_MY Start_SY Status leshem leshey4 Source_Variable if NonChron_WaveS==1	
su pidp if NonChron_WaveS==1

gen XXM=0
gen YYM=cond(missing(Start_MY),1,0)
by pidp Wave YYM (Spell), sort: replace XXM=1 if /*
	*/ Start_MY>Start_MY[_n+1] & !missing(Start_MY, Start_MY[_n+1])		// XXM IS 1 IF MONTHLY START DATE IS LATER THAN NEXT MONTHLY START DATE. NO CASES IN lifemst.
by pidp Wave (Spell), sort: egen NonChron_WaveM=max(XXM)
//browse pidp Wave Spell XXM Start_Y Start_MY Start_SY Status leshem leshey4 Source_Variable if NonChron_WaveM==1	

by pidp Wave (Spell), sort: egen ZZY=max(missing(Start_Y))				// NO MISSING Start_Y OBSERVATIONS FOR lifemst
//browse pidp Wave Spell XXY Start_Y Start_MY Start_SY Status leshsm leshsy4 leshem leshey4 Source_Variable if NonChron_WaveY==1 & ZZY==1
	
capture drop XXSY
capture drop YYSY
capture drop ZZSY
capture drop AASY    
gen XXSY=(missing(Start_SY))
by pidp Wave Start_Y (Start_SY Start_MY), sort: egen YYSY=total(XXSY)
by pidp Wave Start_Y (Start_SY Start_MY), sort: gen ZZSY=_N
by pidp Wave (Start_Y Start_SY Start_MY), sort: egen AASY=max(NonChron_WaveS==1 & YYSY>=1 & ZZSY>=2)
tab AASY
order pidp Wave Spell XXSY Start_Y Start_MY Start_SY Status leshsm leshsy4 leshem leshey4 XXSY YYSY ZZSY Source_Variable
//browse if AASY==1
gen FLAG_Start_Y_CHANGED = 1 if XXS==1 /*	// XXS==1 if Start_SY>Start_SY[_n+1] & !missing(Start_SY, Start_SY[_n+1])	
	*/ & ym(Start_Y-1,5)<=Start_SY[_n+1] & (leshsm==12 | leshsm==17)	// WHEN SEASON = DEC, FLAG A CHANGE OF START YEAR TO START YEAR-1 IF SEASON START DATE IS LATER THAN NEXT SEASON START DATE AND IF THE CORRECTED START YEAR RESULTS IN A CHRONOLOGICAL ORDERING (IN RELATION TO THE NEXT SEASON START DATE) THAT MATCHES SPELL NUMBER [MEMO: NON-CHRONOLOGICAL PROBLEM WAS THAT ym(Start_Y-1,5)>Start_SY[_n+1]. 
label define flag_start_y_changed 1 "NonChron -1"
label values FLAG_Start_Y_CHANGED flag_start_y_changed
//browse if !missing(FLAG_Start_Y_CHANGED)
replace Start_Y = Start_Y-1 if XXS==1 /* 	// XXS==1 if Start_SY>Start_SY[_n+1] & !missing(Start_SY, Start_SY[_n+1])	
	*/ & ym(Start_Y-1,5)<=Start_SY[_n+1] & (leshsm==12 | leshsm==17)	
replace Start_SY = ym(Start_Y,5) if XXS==1 /*	// XXS==1 if Start_SY>Start_SY[_n+1] & !missing(Start_SY, Start_SY[_n+1])	
	*/ & ym(Start_Y-1,5)<=Start_SY[_n+1] & (leshsm==12 | leshsm==17)
//replace Start_SY = ym(Start_Y,5) if XXS==1 /*	// XXS==1 if Start_SY>Start_SY[_n+1] & !missing(Start_SY, Start_SY[_n+1])	
	*/ & ym(Start_Y-1,5)<=Start_SY[_n+1] & (FLAG_Winter==1 | leshsm==17)
replace Start_MY = ym(Start_Y,Start_M) if XXS==1 & !missing(Start_M)

// CHECK PROBLEM IS RESOLVED
gen XXS2=0
gen YYS2=cond(missing(Start_SY),1,0)
by pidp Wave YYS2 (Spell), sort: replace XXS2=1 if /*
	*/ Start_SY>Start_SY[_n+1] & !missing(Start_SY, Start_SY[_n+1])		// XXS2 IS 1 IF START DATE IS LATER THAN NEXT START DATE
by pidp Wave (Spell), sort: egen NonChron_WaveS2=max(XXS2)
capture drop XXSY2
capture drop YYSY2
capture drop ZZSY2
capture drop AASY2    
		gen XXSY2=(missing(Start_SY))
		by pidp Wave Start_Y (Start_SY Start_MY), sort: egen YYSY2=total(XXSY2)
		by pidp Wave Start_Y (Start_SY Start_MY), sort: gen ZZSY2=_N
		by pidp Wave (Start_Y Start_SY Start_MY), sort: egen AASY2=max(NonChron_WaveS2==1 & YYSY2>=1 & ZZSY2>=2)
tab AASY2
//browse pidp Wave Spell XXSY2 Start_Y Start_S Start_MY Start_SY Status leshsm leshsy4 leshem leshey4 XXSY2 YYSY2 ZZSY2 Source_Variable if AASY2==1
//browse pidp Wave Spell XXSY Start_Y Start_MY Start_SY Status leshsm leshsy4 leshem leshey4 XXSY YYSY ZZSY Source_Variable if AASY==1

capture drop XXSMY
capture drop YYSMY
capture drop ZZSMY    
capture drop AASMY    
		gen XXSMY=(missing(Start_MY))
		by pidp Wave Start_Y Start_SY (Start_MY), sort: egen YYSMY=total(XXSMY)
		by pidp Wave Start_Y Start_SY (Start_MY), sort: gen ZZSMY=_N
		by pidp Wave (Start_Y Start_SY Start_MY), sort: egen AASMY=max(NonChron_WaveS==1 & YYSMY>=1 & ZZSMY>=2)
tab AASMY
//browse pidp Wave Spell XXSMY Start_Y Start_MY Start_SY Status leshsm leshsy4 leshem leshey4 XXSMY YYSMY ZZSMY Source_Variable if AASMY==1

// MANUALLY RESOLVE PROBLEMS
replace Start_Y = 1978 if pidp==354183445 & Spell==4
drop if pidp==830080085 & Spell==1
recode Spell (2=1) (3=2) (4=3) if pidp==830080085

// CHECK PROBLEM IS RESOLVED
//browse pidp Wave Spell XXSMY Start_Y Start_MY Start_SY Status leshsm leshsy4 leshem leshey4 XXSMY YYSMY ZZSMY Source_Variable if AASMY==1

capture drop XXMY
capture drop YYMY
capture drop ZZMY    
capture drop AAMY    
		gen XXMY=(missing(Start_MY))
		by pidp Wave Start_Y (Start_MY), sort: egen YYMY=total(XXMY)
		by pidp Wave Start_Y (Start_MY), sort: gen ZZMY=_N
		by pidp Wave (Start_Y Start_MY), sort: egen AAMY=max(NonChron_WaveM==1 & YYMY>=1 & ZZMY>=2)
// NO OBSERVATIONS WHERE AAMY==1
		
drop XX* YY* ZZ* AA*
drop NonChron_WaveY NonChron_WaveS NonChron_WaveS2 NonChron_WaveM

// repeat to check
gen XXY=0
gen YYY=cond(missing(Start_Y),1,0)
by pidp Wave YYY (Spell), sort: replace XXY=1 if /*
	*/ Start_Y>Start_Y[_n+1] & !missing(Start_Y, Start_Y[_n+1])			// XXY IS 1 IF START DATE IS LATER THAN NEXT START DATE
by pidp Wave (Spell), sort: egen NonChron_WaveY=max(XXY)

gen XXS=0
gen YYS=cond(missing(Start_SY),1,0)
by pidp Wave YYS (Spell), sort: replace XXS=1 if /*
	*/ Start_SY>Start_SY[_n+1] & !missing(Start_SY, Start_SY[_n+1])		// XXS IS 1 IF START DATE IS LATER THAN NEXT START DATE
by pidp Wave (Spell), sort: egen NonChron_WaveS=max(XXS)

gen XXM=0
gen YYM=cond(missing(Start_MY),1,0)
by pidp Wave YYM (Spell), sort: replace XXM=1 if /*
	*/ Start_MY>Start_MY[_n+1] & !missing(Start_MY, Start_MY[_n+1])		// XXM IS 1 IF START DATE IS LATER THAN NEXT START DATE
by pidp Wave (Spell), sort: egen NonChron_WaveM=max(XXM)

capture drop XXSY
capture drop YYSY
capture drop ZZSY
capture drop AASY    
		gen XXSY=(missing(Start_SY))
		by pidp Wave Start_Y (Start_SY Start_MY), sort: egen YYSY=total(XXSY)
		by pidp Wave Start_Y (Start_SY Start_MY), sort: gen ZZSY=_N
		by pidp Wave (Start_Y Start_SY Start_MY), sort: egen AASY=max(NonChron_WaveS==1 & YYSY>=1 & ZZSY>=2)
tab AASY
	
capture drop XXSMY
capture drop YYSMY
capture drop ZZSMY    
capture drop AASMY    
		gen XXSMY=(missing(Start_MY))
		by pidp Wave Start_Y Start_SY (Start_MY), sort: egen YYSMY=total(XXSMY)
		by pidp Wave Start_Y Start_SY (Start_MY), sort: gen ZZSMY=_N
		by pidp Wave (Start_Y Start_SY Start_MY), sort: egen AASMY=max(NonChron_WaveS==1 & YYSMY>=1 & ZZSMY>=2)
tab AASMY

capture drop XXMY
capture drop YYMY
capture drop ZZMY    
capture drop AAMY    
		gen XXMY=(missing(Start_MY))
		by pidp Wave Start_Y (Start_MY), sort: egen YYMY=total(XXMY)
		by pidp Wave Start_Y (Start_MY), sort: gen ZZMY=_N
		by pidp Wave (Start_Y Start_MY), sort: egen AAMY=max(NonChron_WaveM==1 & YYMY>=1 & ZZMY>=2)
tab AAMY


*** IN THE CASE OF lifemst AND THE CHANGES MADE ABOVE, End_Type IS 0 EVERYWHERE
// GENERATE NonChron as it is generated in prog_nonchron
	capture drop XX
	gen XX=0
	foreach j in `namelist'{
		gen YY=cond(missing(`i'_`j'),1,0)
		by pidp Wave YY (Spell), sort: replace XX=1 if /*
			*/ `i'_`j'>`i'_`j'[_n+1] & !missing(`i'_`j', `i'_`j'[_n+1])
		drop YY
		}
	by pidp Wave (Spell), sort: egen NonChron_Wave=max(XX)		// NonChron_Wave is 1 for all Spells in a Wave if Spells are non-chronological
	drop XX		

drop NonChron_WaveY NonChron_WaveS NonChron_WaveM 
drop XX* YY* ZZ* AA*
