/*
********************************************************************************
UKHLS ANNUAL HISTORY.DO
	
	THIS FILE CREATES A DATASET OF JOB HISTORY AND INTERVIEW DATE VARIABLES FROM
	CURRENT AND PRECEEDING FULL OR TELPHONE INTERVIEWS.
	
	UPDATES:
	* 3 VARIANTS ARE CREATED THAT DIFFER IN THEIR TREATMENT OF FURLOUGH SPELLS (Status "12. Furlough" AND "13. Temporarily laid off/short time working").
	* _orig IS THE ORIGINAL CODING. THIS TREATS A FURLOUGH SPELL AS A NEW SPELL, AND TREATS FURLOUGH SPELLS LIKE ANY OTHER NON-EMPLOYMENT SPELL.
	* THE NEW UNSUFFIXED CODING FOCUSES ON THE UNDERLYING EMPLOYMENT STATUS, EFFECTIVELY IGNORING FURLOUGH STATUS.
	* _F TREATS A FURLOUGH SPELL AS A NEW SPELL BUT USES NEW Status CODING THAT REFLECTS BOTH THE UNDERLYING EMPLOYMENT SPELL AND FURLOUGH STATUS. 
		
	THERE ARE CHANGES TO VARIOUS VARIABLES RELATING TO NEW Statuses FURLOUGHED / TEMPORARY LAYOFF OR SHORT-TIME WORKING:
	* STENDREASX Waves 11 [29] onward add STENDREAS12 =1 if Furloughed
	* JBSTAT UKHLS Waves 11 [29] onward add options for JBSTAT: Added new response option codes 12 Furloughed and 13 Temporarily laid off/short time working
	* JBOFF Waves 11 [29] onward add text to JBOFF Help text: Updated Help text: Added 'furlough' and 'unpaid leave' to reasons for temporary absence from work. "Include any persons who were absent because of holiday, strike, sickness, maternity leave, furlough, unpaid leave, lay-off or similar reason, provided they have a job to return to with the same employer."
	* JBOFFY: Added new response option code 8 Furloughed
	* JBHAD: Compute statement updated to include JBSTAT codes 12 Furloughed and 13 Temporarily laid off/short time working
	* self-employment JSSEISSAP etc added new questions
	* Comment: Code referring to reasend and reasend97 does not have to be altered.

	* CODE TO COLLECT VARIABLES IS ALTERED IN ORDER TO PICK UP stendreas12.

	* From Wave 7 [25] onwards, each reason is recorded in separate variables. (ORIGINAL LW CODE: From Wave 4 [22] onwards, each reason recorded in separate variables.)

	* A SMALL AMOUNT OF CODE FROM THE END OF "Clean Dependent Annual History_JCS.do" IS TRANSFERRED INTO LOOPS AT THE END OF THIS FILE.
	
********************************************************************************
*/

/*
1. Dataset Preparation.
	A. Collate raw data and create routing flags.
*/

*i. Bring together UKHLS annual employment history variables and variables upon which routing depends from indresp and indall files (Wave 2 onwards)
// The Annual Event History module was included in the adult interview from Wave 2 [20] onwards, to be completed by returning full participants. 
	* Replace missing values with .m or .i.
forval i=2/$ukhls_waves{	
	local j: word `i' of `c(alpha)'
	use pidp `j'_notempchk-`j'_jbhas `j'_jbft_dv `j'_ff_jbstat /*
		*/ `j'_jbstat `j'_jbsemp /*
		*/ `j'_stend* /*
		*/ `j'_ff_emplw `j'_ff_jbsemp /*
		*/ using "${fld}/${ukhls_path}_w`i'/`j'_indresp${file_type}", clear
	merge 1:1 pidp using "${fld}/${ukhls_path}_w`i'/`j'_indall${file_type}", /*
		*/ keepusing(`j'_ff_everint `j'_ff_ivlolw `j'_ivfio) /*
		*/ keep(match) nogenerate

	prog_recodemissing *

	compress
	rename `j'_* *
	gen Wave=`i'+18
	tempfile Temp`i'
	save "`Temp`i''", replace		
	}
forval i=`=$ukhls_waves-1'(-1)2{
	append using "`Temp`i''"
	}
save "${dta_fld}/UKHLS Annual History - Raw", replace

// stendreas12 IS OUT OF ORDER, AND ONLY AVAILABLE, IN W12 SO stend* IS NAMED SEPARATELY, OUTSIDE THE INITIAL LIST.
// USING stend* ALSO COLLECTS stendoth_code, AVAILABLE IN WAVE 8 ONWARDS, WHICH CAN BE USED IN A SIMILAR WAY TO stendreas AS IT IS CODED LIKE stendreas FOR stendoth_code VALUES 1-11. ALL stendoth_code VALUES ABOVE 11 CAN BE RECODED 97 "Other reason" EXCEPT FOR THE FOLLOWING: IN WAVE 12, l_stendoth_code==24 is "End of contract" WHICH COULD BE RECODED =5 "Temporary job ended". THIS VALUE DOES NOT APPEAR IN ANY PRIOR WAVES. WHEN stendoth_code IS USED TO RECODE stendreas97, THOSE CASES ARE EXTRACTED FROM AND NOT ALSO INCLUDED IN stendreas97.

 	
*ii. Drop participants who do not have annual employment histories in a given wave.
	* Create flags for how individuals are routed through annual history modules.

prog_reopenfile "${dta_fld}/UKHLS Annual History - Raw.dta"

prog_labels											// prog_labels NOW REFERS TO "Labels_JCS.do" and "Apply Labels_JCS.do"

keep if ivfio==1 & (ff_ivlolw==1 | ff_everint==1)	// Keep full interviews & (interviewed at prior wave | has been interviewed previously) 
drop if notempchk==.i & empchk==.i					// Drop if both notempchk and empchk are IEMB/inapplicable/proxy 

foreach var of varlist nextstat* nextelse* currstat* nextjob* currjob* /*	// Recode missing values
	*/jobhours* statend* jbatt*{
	capture replace `var'=.i if `var'==.
	}

gen AnnualHistory_Routing=cond(notempchk!=.i,cond(empchk==.i,1,3),2)	// 1 if NOTEMPCHK only, 2 if EMPCHK only, 3 if both NOTEMPCHK and EMPCHK - cond(x,a,b) Description: a if x is true and nonmissing, b if x is false

label values AnnualHistory_Routing annualhistory_routing

gen Route3_Type=.i
replace Route3_Type=1 if notempchk==.m & empchk==.m
replace Route3_Type=2 if notempchk==.m & empchk==1	// 1 = yes, 2 = no
replace Route3_Type=3 if notempchk==.m & empchk==2
replace Route3_Type=4 if notempchk==1 & empchk==.m	
replace Route3_Type=5 if notempchk==1 & empchk==1
replace Route3_Type=6 if notempchk==1 & empchk==2
replace Route3_Type=7 if notempchk==2 & empchk==.m
replace Route3_Type=8 if notempchk==2 & empchk==1
replace Route3_Type=9 if notempchk==2 & empchk==2
label values Route3_Type route3_type

save "${dta_fld}/UKHLS Annual History - Raw", replace


********************************************************************************

/*
2A. Harmonise and save spell end reason data.
	// Main reason for job end recorded only in a single variable in Waves 1-6. (LW 2020 VERSION: Main reason for job end recorded only in a single variable in Waves 1-3.)
	// From Wave 7 onwards, each reason recorded in separate variables. (LW 2020 VERSION: From Wave 4 onwards, each reason recorded in separate variables.)
	// FROM WAVE 7, MULTIPLE REASONS CAN BE GIVEN IN nxtendreasX, jbendreasX AND stendreasX. Understanding Society NOTES FOR nxtendreasX AND stendreasX: "Type: multichoice; Interviewer Instruction: CODE ALL. PROBE "Any other reasons?". Understanding Society NOTES FOR jbendreasX "The question which asks the reason why the most recent job ended - 'jbendreas' - changed from 'code one option' to 'code all that apply' in Wave 7. As a result of this change, from Wave 7 onward, instead of one variable w_jbendreas, there are 11 variables (0-1 not mentioned-mentioned)." ALL OTHER VARIABLES RECORDING REASON FOR JOB END ALLOW ONLY ONE MAIN REASON. (LW COMMENT IN LW 2020 VERSION: "Given only one answer possible in main reason, not stating other reasons does not imply these were not factors for leaving job (hence missing).")
*/
*i. Creates variables for each reason and replaces with 1 if stated as main reason for leaving job, otherwise missing.
	// Creation of variables works using fact that variable ==. if not previously present when waves are appended to one another.
	// NXTENDREAS ASKED WAVES 5-6 [23-24], NXTENDREASi ASKED WAVE 7 [25] ONWARDS. (LW 2020 VERSION: "NXTENDREASi QUESTIONS NOT ASKED IN WAVE 3 AND EARLIER.")
	// STENDREAS ASKED WAVES 2-6 [20-24], STENDREASi ASKED WAVE 7 [25] ONWARDS APART FROM STENDREAS12 ASKED/AVAILABLE IN WAVE 12 [AND ...].
	// REASENDi ASKED WAVES 2-6 [20-24].

prog_reopenfile "${dta_fld}/UKHLS Annual History - Raw.dta"

ds nextstat*
local spells: word count `r(varlist)'

* nxtendreas, jbendreas
replace nxtendreas=cond(cjob==2,.m,.i) if nxtendreas==. & nxtendreas1==.	// REPLACE nxtendreas AS .m IF nxtendreas and nxtendreas1 are missing if next job is not current job [cjob==2] or i. if not [cjob!=2]
foreach var of varlist jbendreas nxtendreas{
	foreach i of numlist 1/11 97{
		replace `var'`i'=cond(`var'==`i',1,cond(`var'==.i,.i,.m)) if `var'!=.
		}
	drop `var'
	}
	
* stendreas
// Wave 12 adds STENDREAS12 =1 if Furloughed.
// STENDREAS12 (reason most recent job ended) universe: if ff_ivlolw = 1 | ff_everint = 1 (interviewed at prior wave or has been interviewed previously) and if EmpChk = 2 & (ff_JBSTAT <> 12|13) (Has not been continuously employed since last interview).
// USING DATA UP TO AND INCLUDING UKHLS WAVE 12, End_Reason12 IS ONLY NON-MISSING FOR SPELL 0 (End_Reason12_0) SINCE "Furloughed" WAS ONLY AN OPTION TO ANSWER "Can you tell me why you stopped doing that job" IN Wave 12, AND THE ANSWER RELATES TO THE EMPLOYMENT SPELL AT THE PREVIOUS INTERVIEW.
// UKHLS WAVES 8 ONWARDS INCLUDE W_stendoth_code. LABEL W_stendoth_code INDICATES THAT VALUE 24 CORRESPONDS TO "End of contract". THE SYNTAX BELOW RECODES VALUE 24 AS 5 "Temporary job ended". VALUES X OF W_stendoth_code BETWEEN 1 AND 11 CORRESPOND TO THE EQUIVALENT stendreasX, AND THOSE VALUES OF W_stendoth_code ARE RECODED INTO THE RELEVANT stendreasX. THOSE OBSERVATIONS ARE ALSO RECORDED IN W_stendreas97, SO THOSE VALUES OF W_stendreas97 ARE SET TO MISSING.
capture confirm variable stendoth_code
if _rc==0 {
	foreach i of numlist 1/12{			// WHEN stendoth_code VALUES ARE RECODED AS stendreasX, OMIT stendreas==97 CASES FROM stendreas97 TO AVOID DUPLICATION (SINCE THOSE CASES ARE RECORDED IN BOTH stendreas==97 AND stendoth_code).
		replace stendreas`i'=cond(stendreas==`i',1,cond(stendreas==.i,.i,.m)) if stendreas!=.
		}
	}
else if _rc==1 {
	foreach i of numlist 1/12 97{		// WHEN stendoth_code VALUES ARE NOT AVAILABLE, CREATE stendreas==97 CASES FROM stendreas97.
		replace stendreas`i'=cond(stendreas==`i',1,cond(stendreas==.i,.i,.m)) if stendreas!=.
		}
	}
drop stendreas
foreach i of numlist 1/11 {
	replace stendreas`i'=cond(stendoth_code==`i',1,cond(stendoth_code==.i,.i,.m)) if stendoth_code!=.
	}
foreach i of numlist 12/23 97 {
	replace stendreas97=cond(stendoth_code==`i',1,cond(stendoth_code==.i,.i,.m)) if stendoth_code!=.
	}
replace stendreas5=cond(stendoth_code==24,1,cond(stendoth_code==.i,.i,.m)) if stendoth_code==24
drop stendoth_code

* reasend
// rename reasend97* reasend97_*		// THIS LINE FROM LW 2020 VERSION IS NO LONGER REQUIRED.
forval i=1/`spells'{
	capture gen reasend`i'=.i
	foreach j of numlist 1/11 97{
		capture gen reasend`j'_`i'=.i
		replace reasend`j'_`i'=cond(reasend`i'==`j',1,cond(reasend`i'==.i,.i,.m)) if reasend`i'!=.
		}
	drop reasend`i'
	}
	
gen jbendreas12=.m
gen nxtendreas12=.m
foreach i of numlist 1/12 97{
	gen reasend12_`i'=.m
	}									// jbendreasX AND nxtendreasX ARE AVAILABLE FOR X==1-11. THIS CREATES jbendreas12 AND nxtendreasX SO jbendreasX AND nxtendreasX CAN BE USED IN THE SAME LOOP AS stendreasX TO CREATE End_ReasonX. reasend12_`i'=.m CREATES APPROPRIATE MISSING VALUES TO COMPLETE End_ReasonX.
foreach i of numlist 1/12 97{			// LW 2020 VERSION: foreach i of numlist 1/11 97{
	gen End_Reason`i'_0=cond(empchk==2 & (ff_jbstat!=12 | ff_jbstat!=13),stendreas`i',cond(jbsamr==2,jbendreas`i',.i))	// LW 2020 VERSION: gen End_Reason`i'_0=cond(empchk==2,stendreas`i',cond(jbsamr==2,jbendreas`i',.i))
	gen End_Reason`i'_1=cond(cjob==2,nxtendreas`i',.i) 
	}
qui ds nextstat*
local spells: word count `r(varlist)'
forval i=1/`spells'{
	local j=`i'+1
	foreach k of numlist 1/12 97{		// LW 2020 VERSION: foreach k of numlist 1/11 97{
		gen End_Reason`k'_`j'=cond(currjob`i'==2,reasend`k'_`i',.i)
		}
	}	
	

keep pidp Wave End_Reason*
compress
ds End_Reason*_1
local vlist=subinstr("`r(varlist)'","_1","_",.)
di "`vlist'"
reshape long `vlist', i(pidp Wave) j(Spell)
rename *_ *
drop if End_Reason1==.i
save "${dta_fld}/UKHLS Annual History End Reasons", replace


********************************************************************************

/*
2B. Format annual history dataset - All Routes
	/// Logic of Route 3 is that only spells via notempchk can be relied upon. 
	* Left hand notempchk routing takes precedence where both sides route into a question (UKHLS Forum Issue #957).
*/

prog_reopenfile "${dta_fld}/UKHLS Annual History - Raw.dta"

drop stend* jbendreas* nxtendreas* reasend*				// ORIGINAL CODE: drop stendreas* jbendreas* nxtendreas* reasend*
merge 1:1 pidp Wave using "${dta_fld}/Interview Grid", /*
	*/ nogenerate keepusing(Prev_Job_Hours Next_ff_jbstat Next_ff_jbsemp) /*
	*/ keep(match master)
replace Prev_Job_Hours=.m if Prev_Job_Hours==.

/*
Index Spell Exists indicator
*/	
			gen Has_Activity_orig0=1

gen Has_Activity0=1

gen Has_Activity_F0=1

/*
Index Spell Status
*/	
			gen Status_orig0=ff_jbstat												// LIAM WRIGHT (2020) [LW] ORIGINAL CODE, THOUGH VARIABLE RENAMED WITH SUFFIX _orig.

gen Status0=ff_jbstat if inrange(ff_jbstat,1,11) /*									// THE REMAINDER OF THIS Index Spell Status SECTION IS ADDITIONAL TO LW ORIGINAL CODE.
	*/ | inrange(ff_jbstat,14,97)													// NOTE: TAKES ACCOUNT OF WAVES 12 AND 13 [30 AND 31] jbstat CODING.
replace Status0=1 if inlist(ff_jbstat,12,13) & /*
	*/ (ff_jbsemp==2 | /*
	*/ (missing(ff_jbsemp) & (samejob==1 & cjob==1 & jbsemp==2)))
replace Status0=2 if inlist(ff_jbstat,12,13) & /*
	*/ (ff_jbsemp==1 | /*
	*/ (missing(ff_jbsemp) & (samejob==1 & cjob==1 & jbsemp==1)))
replace Status0=100 if inlist(ff_jbstat,12,13) & /*
	*/ missing(Status0) & /*
	*/ (missing(ff_jbsemp) | (samejob==1 & cjob==1 & missing(jbsemp)))	// SEE NOTE 1.
/*
// NOTES TO Status0:
Status0 does not treat jbstat=12,13 as a separate status, aiming to record (available information about) the underlying employment status. The introduction of jbstat=12,13 means it is necessary to use other variables to ascertain the underlying employment status (employed or self-employed).
1. The value 100 is used where an individual must be in employment or self-employment, according to their furlough status, but no additional information is available to allocate between those.
*/

gen Status_F0=ff_jbstat if inrange(ff_jbstat,1,11) | /*
	*/ inrange(ff_jbstat,14,97)
replace Status_F0=100+ff_jbstat if inlist(ff_jbstat,12,13) & /*
	*/ (ff_jbsemp==2 | /*
	*/ (missing(ff_jbsemp) & (samejob==1 & cjob==1 & jbsemp==2)))
replace Status_F0=200+ff_jbstat if inlist(ff_jbstat,12,13) & /*
	*/ (ff_jbsemp==1 | /*
	*/ (missing(ff_jbsemp) & (samejob==1 & cjob==1 & jbsemp==1)))
replace Status_F0=10000+ff_jbstat if inlist(ff_jbstat,12,13) & /*
	*/ missing(Status_F0) & /*
	*/ (missing(ff_jbsemp) | (samejob==1 & cjob==1 & missing(jbsemp)))
/*
// NOTES TO Status_F0:
The construction of Status_F0 matches that of Status0, but the values differ. The values of Status_F0 combine furlough/temp layoff and available information about underlying employment status, to enable analysis at either level, allowing the start/end of furlough to be treated as a transition or a focus on the underlying employment status. Values of Status_F0 are jbstat values but with 12 and 13 replaced by 112/113 if sef-employed on furlough/temp layoff, 212/213 if employed on furlough/temp layoff, 10012/10013 if on furlough/temp layoff without information to distinguish whether employed or self-employed. 
*/

/*
// TABULATIONS OF THE 3 Status*0 VARIABLES:	
tab Status_orig0 Status0, mis
Status_ori |                                                                          Status0
        g0 |         1          2          3          4          5          6          7          8          9         10         11         97        100          . |     Total
-----------+----------------------------------------------------------------------------------------------------------------------------------------------------------+----------
         1 |    30,239          0          0          0          0          0          0          0          0          0          0          0          0          0 |    30,239 
         2 |         0    190,793          0          0          0          0          0          0          0          0          0          0          0          0 |   190,793 
         3 |         0          0     18,070          0          0          0          0          0          0          0          0          0          0          0 |    18,070 
         4 |         0          0          0     97,531          0          0          0          0          0          0          0          0          0          0 |    97,531 
         5 |         0          0          0          0      2,382          0          0          0          0          0          0          0          0          0 |     2,382 
         6 |         0          0          0          0          0     22,131          0          0          0          0          0          0          0          0 |    22,131 
         7 |         0          0          0          0          0          0     24,119          0          0          0          0          0          0          0 |    24,119 
         8 |         0          0          0          0          0          0          0     13,906          0          0          0          0          0          0 |    13,906 
         9 |         0          0          0          0          0          0          0          0        297          0          0          0          0          0 |       297 
        10 |         0          0          0          0          0          0          0          0          0        268          0          0          0          0 |       268 
        11 |         0          0          0          0          0          0          0          0          0          0        459          0          0          0 |       459 
        12 |         5         87          0          0          0          0          0          0          0          0          0          0         17          0 |       109 
        13 |         3         12          0          0          0          0          0          0          0          0          0          0          6          0 |        21 
        97 |         0          0          0          0          0          0          0          0          0          0          0      2,125          0          0 |     2,125 
        .m |         0          0          0          0          0          0          0          0          0          0          0          0          0         93 |        93 
-----------+----------------------------------------------------------------------------------------------------------------------------------------------------------+----------
     Total |    30,247    190,892     18,070     97,531      2,382     22,131     24,119     13,906        297        268        459      2,125         23         93 |   402,543 

tab Status_F0 Status0, mis
           |                                                                          Status0
 Status_F0 |         1          2          3          4          5          6          7          8          9         10         11         97        100          . |     Total
-----------+----------------------------------------------------------------------------------------------------------------------------------------------------------+----------
         1 |    30,239          0          0          0          0          0          0          0          0          0          0          0          0          0 |    30,239 
         2 |         0    190,793          0          0          0          0          0          0          0          0          0          0          0          0 |   190,793 
         3 |         0          0     18,070          0          0          0          0          0          0          0          0          0          0          0 |    18,070 
         4 |         0          0          0     97,531          0          0          0          0          0          0          0          0          0          0 |    97,531 
         5 |         0          0          0          0      2,382          0          0          0          0          0          0          0          0          0 |     2,382 
         6 |         0          0          0          0          0     22,131          0          0          0          0          0          0          0          0 |    22,131 
         7 |         0          0          0          0          0          0     24,119          0          0          0          0          0          0          0 |    24,119 
         8 |         0          0          0          0          0          0          0     13,906          0          0          0          0          0          0 |    13,906 
         9 |         0          0          0          0          0          0          0          0        297          0          0          0          0          0 |       297 
        10 |         0          0          0          0          0          0          0          0          0        268          0          0          0          0 |       268 
        11 |         0          0          0          0          0          0          0          0          0          0        459          0          0          0 |       459 
        97 |         0          0          0          0          0          0          0          0          0          0          0      2,125          0          0 |     2,125 
       112 |         5          0          0          0          0          0          0          0          0          0          0          0          0          0 |         5 
       113 |         3          0          0          0          0          0          0          0          0          0          0          0          0          0 |         3 
       212 |         0         87          0          0          0          0          0          0          0          0          0          0          0          0 |        87 
       213 |         0         12          0          0          0          0          0          0          0          0          0          0          0          0 |        12 
     10012 |         0          0          0          0          0          0          0          0          0          0          0          0         17          0 |        17 
     10013 |         0          0          0          0          0          0          0          0          0          0          0          0          6          0 |         6 
         . |         0          0          0          0          0          0          0          0          0          0          0          0          0         93 |        93 
-----------+----------------------------------------------------------------------------------------------------------------------------------------------------------+----------
     Total |    30,247    190,892     18,070     97,531      2,382     22,131     24,119     13,906        297        268        459      2,125         23         93 |   402,543 
*/


/*
Index Spell Status Source Variables
*/	

			gen Source_Variable_orig0="ff_jbstat_w"+strofreal(Wave)

gen Source_Variable0="ff_jbstat_w"+strofreal(Wave) if inrange(ff_jbstat,1,11) | inrange(ff_jbstat,14,97) | (inlist(ff_jbstat,12,13) & (missing(ff_jbsemp) | ((samejob==1 | (empchk==1  & ff_jbstat==1)) & missing(jbsemp))))											// THE REMAINDER OF THIS Index Spell Status SECTION IS ADDITIONAL TO LW ORIGINAL CODE.
replace Source_Variable0="ff_jbsemp_w"+strofreal(Wave) if inlist(ff_jbstat,12,13) & !missing(ff_jbsemp)
replace Source_Variable0="jbsemp_w"+strofreal(Wave) if inlist(ff_jbstat,12,13) & missing(ff_jbsemp) & ((samejob==1 & cjob==1) | (empchk==1 & ff_jbstat==1)) & !missing(jbsemp)

gen Source_Variable_F0="ff_jbstat_w"+strofreal(Wave) if inrange(ff_jbstat,1,11) | inrange(ff_jbstat,14,97) | (inlist(ff_jbstat,12,13) & (missing(ff_jbsemp) | ((samejob==1 | (empchk==1  & ff_jbstat==1)) & missing(jbsemp))))
replace Source_Variable_F0="ff_jbsemp_w"+strofreal(Wave)+","+"ff_jbstat_w"+strofreal(Wave) if inlist(ff_jbstat,12,13) & !missing(ff_jbsemp)
replace Source_Variable_F0="jbsemp_w"+strofreal(Wave)+","+"ff_jbstat_w"+strofreal(Wave) if inlist(ff_jbstat,12,13) & missing(ff_jbsemp) & ((samejob==1 & cjob==1) | (empchk==1 & ff_jbstat==1)) & !missing(jbsemp)

			
/*
Index Spell End indicator
*/	
gen empstend=ym(empstendy4,empstendm)		// ADDED LINE. emptend is created because in one case, End_Ind_F0 uses a criterion based on empstend (see Notes to End_Ind_F0 below for more information).	

			gen End_Ind_orig0=.m													// LW ORIGINAL CODE, THOUGH VARIABLE RENAMED WITH SUFFIX _orig.
			replace End_Ind_orig0=0 if (notempchk==1 | samejob==1 | (empchk==1  & ff_jbstat==1)) /*
				*/ & inlist(AnnualHistory_Routing,1,2)
			replace End_Ind_orig0=1 if (notempchk==2 | empchk==2 | jbsamr==2 | samejob==2) /*
				*/ & inlist(AnnualHistory_Routing,1,2)
			replace End_Ind_orig0=0 if notempchk==1 & AnnualHistory_Routing==3
			replace End_Ind_orig0=1 if notempchk==2 & AnnualHistory_Routing==3
			
gen End_Ind0=.m																		// THE REMAINDER OF THIS Index Spell End Indicator SECTION IS ADDITIONAL TO LW ORIGINAL CODE.
replace End_Ind0=0 if (notempchk==1 | samejob==1 | (empchk==1 & ff_jbstat==1)) /*
	*/ & inlist(AnnualHistory_Routing,1,2)
replace End_Ind0=0 if empchk==2 & inlist(ff_jbstat,12,13) & (ff_jbstat==jbstat & samejob==1) /*
	*/ & inlist(AnnualHistory_Routing,1,2)																		// SEE NOTE 1. 
replace End_Ind0=0 if empchk==2 & inlist(ff_jbstat,12,13) & samejob==1 & cjob==1 & inlist(jbstat,1,2,12,13)  	// SEE NOTE 2.
replace End_Ind0=1 if empchk==2 & inlist(ff_jbstat,12,13) & samejob==1 & cjob==1 & !inlist(jbstat,1,2,12,13)	// SEE NOTE 3.
replace End_Ind0=1 if (notempchk==2 | (empchk==2 & !inlist(ff_jbstat,12,13)) | jbsamr==2 | samejob==2 | (empchk==2 & inlist(ff_jbstat,12,13) & (nxtst==2 | cjob==2))) /*
	*/ & inlist(AnnualHistory_Routing,1,2)
replace End_Ind0=0 if notempchk==1 & AnnualHistory_Routing==3
replace End_Ind0=1 if notempchk==2 & AnnualHistory_Routing==3
/*
// NOTES TO End_Ind0:
End_Ind0 has relatively few status changes: it ignores furlough/temp layoff as a status and deals only with underlying employment status.
1. This line says there has been no status change (despite empchk=2) because same status and same job, treating these fairly small number of cases of  empchk=2 as if they were empchk=1, and ignoring empstend* dates.
2. By using inlist(jbstat,1,2,12,13), this line says that non-spell-end applies to changes between furlough and temp layoff (and vice versa), as well as furlough-furlough and furlough-employment/self-employment.
3. This line states that moving from furlough to any non-employment state entails a status end (even if it involves maternity leave/apprenticeship).
*/ 

gen End_Ind_F0=.m
replace End_Ind_F0=0 if (notempchk==1 | samejob==1 | (empchk==1 & ff_jbstat==1)) /*
	*/ & inlist(AnnualHistory_Routing,1,2)
replace End_Ind_F0=0 if empchk==1 & inlist(ff_jbstat,12,13) & samejob==1 & inlist(jbstat,12,13)
replace End_Ind_F0=1 if (notempchk==2 | (empchk==2 & !inlist(ff_jbstat,12,13)) | jbsamr==2 | samejob==2) /*
	*/ & inlist(AnnualHistory_Routing,1,2)
replace End_Ind_F0=1 if empchk==2 & inlist(ff_jbstat,12,13) & nxtst==2
replace End_Ind_F0=1 if empchk==2 & inlist(ff_jbstat,12,13) & samejob==1 & ff_jbstat!=jbstat				// SEE NOTE 1.
replace End_Ind_F0=1 if empchk==2 & inlist(ff_jbstat,12,13) & samejob==1 & inlist(jbstat,12,13)			// SEE NOTE 2.
replace End_Ind_F0=1 if empchk==2 & inlist(ff_jbstat,12,13) & !missing(empstend) & !inlist(jbstat,12,13)	// SEE NOTE 3.
replace End_Ind_F0=0 if notempchk==1 & AnnualHistory_Routing==3
replace End_Ind_F0=1 if notempchk==2 & AnnualHistory_Routing==3
/*
// NOTES TO End_Ind_F0:
1. This line is necessary to capture furlough end when it involves the same job but a different status: it states that moving from a furlough status to any different status entails a status end. The condition samejob==1 is necessary to prevent the criterion becoing a more general comparison of ff_jbstat AND jbstat. Incorporating end of furlough in this criterion requires only that someone remaining in the same job but coming off furlough/temp layoff is included in the status change group.
2. This set of variable values implies that the individual remained in the same job and was furloughed/temp layoff at each interview but empchk==2 implies a status change/end (which is backed up in practice by the presence of empstendd/m/y4 dates).
3. This line captures a single case where the presence of empstend and next wave status not furlough entails that furlough status has ended.
*/

// ANALYSIS: COMPARISON OF THE 3 End_Ind*0 VARIABLES:
/*
// COMPARE End_Ind_orig0, End_Ind0
End_Ind0 and End_Ind_orig0 differ in (57) cases where empchk==2 & inlist(ff_jbstat,12,13). For these cases, End_Ind_orig0 computes a spell end whereas End_Ind0 infers a continuing spell. For these cases, End_Ind0_F computes a new spell due to (same job but) end of furlough. There are 3 cases where End_Ind0==.m when End_Ind_orig0==1, which are due to missing nxtst and hence no information about samejob.

tab End_Ind_orig0 End_Ind0, mis
End_Ind_or |             End_Ind0
       ig0 |         0          1         .m |     Total
-----------+---------------------------------+----------
         0 |   343,372          0          0 |   343,372 
         1 |        57     58,042          3 |    58,102 
        .m |         0          0      1,069 |     1,069 
-----------+---------------------------------+----------
     Total |   343,429     58,042      1,072 |   402,543
. browse if End_Ind_orig0!=End_Ind0
	 
tab End_Ind_F0 End_Ind0
           |       End_Ind0
End_Ind_F0 |         0          1 |     Total
-----------+----------------------+----------
         0 |   343,372          0 |   343,372 
         1 |        57     58,042 |    58,099 
-----------+----------------------+----------
     Total |   343,429     58,042 |   401,471 

// FOR INFO: The following code can be used to browse to visually explore the variables:
sort ff_jbstat jbstat
order pidp Wave Has_Activity0 Status_orig0 Status0 End_Ind_orig0 End_Ind0 End_Ind_F0 AnnualHistory_Routing ff_jbstat ff_jbsemp jbstat jbsemp empchk notempchk empstendd empstendm empstendy4 nxtst jbsamr samejob jbendm jbendy4 cjob nxtjbes nxtjbendm nxtjbendy4 nxtstelse cstat nxtstendm nxtstendy4 nextstat1 nextstat1 nextjob1 currjob1 nextelse1 currstat1 statendm1 statendy41		
browse pidp Wave Has_Activity0 Status_orig0 Status0 End_Ind_orig0 End_Ind0 End_Ind_F0 AnnualHistory_Routing ff_jbstat ff_jbsemp jbstat jbsemp empchk notempchk empstendd empstendm empstendy4 nxtst jbsamr samejob jbendm jbendy4 cjob nxtjbes nxtjbendm nxtjbendy4 nxtstelse cstat nxtstendm nxtstendy4 nextstat1 nextstat1 nextjob1 currjob1 nextelse1 currstat1 statendm1 statendy41 if empchk==2 & inlist(ff_jbstat,12,13)
*/
	
	
/*
Index Spell End Dates
*/	

/*
empstend, jbend and nxtjbend month-year dates using available data
*/
// NOTE: These formatted dates are useful for comparison with generated (conditional) date variables. ADDITIONAL TO LW ORIGINAL CODE.
gen jbend=ym(jbendy4,jbendm)
gen nxtjbend=ym(nxtjbendy4,nxtjbendm)
gen nxtstend=ym(nxtstendy4,nxtstendm)
format empstend %tm
format jbend %tm
format nxtjbend %tm
format nxtstend %tm
label var empstend "Month-year end date of status held last wave"
label var jbend "Month-year end date of job held last wave"
label var nxtjbend "Month-year end date of next job"
label var nxtjbend "Month-year end date of next non-employment spell"

			gen End_D_orig0=cond(notempchk==2 | empchk==2,empstendd,cond(jbsamr==2 | samejob==2,jbendd,.)) /*
				*/ if inlist(AnnualHistory_Routing,1,2)							// LW ORIGINAL CODE, THOUGH VARIABLE RENAMED WITH SUFFIX _orig.
			gen End_M_orig0=cond(notempchk==2 | empchk==2,empstendm,cond(jbsamr==2 | samejob==2,jbendm,.)) /* 
				*/ if inlist(AnnualHistory_Routing,1,2)
			gen End_Y_orig0=cond(notempchk==2 | empchk==2,empstendy4,cond(jbsamr==2 | samejob==2,jbendy4,.)) /*
				*/ if inlist(AnnualHistory_Routing,1,2)
			replace End_D_orig0=empstendd if notempchk==2 & AnnualHistory_Routing==3
			replace End_M_orig0=empstendm if notempchk==2 & AnnualHistory_Routing==3
			replace End_Y_orig0=empstendy4 if notempchk==2 & AnnualHistory_Routing==3	
			
gen End_D0=.																		// THE REMAINDER OF THIS Index Spell End Dates SECTION IS ADDITIONAL TO LW ORIGINAL CODE.
gen End_M0=.
gen End_Y0=.
replace End_D0=empstendd if notempchk==2 | (empchk==2 & (!inlist(ff_jbstat,12,13) | (inlist(ff_jbstat,12,13) & nxtst==2)) & inlist(AnnualHistory_Routing,1,2))
replace End_D0=jbendd if (jbsamr==2 | samejob==2) & inlist(AnnualHistory_Routing,1,2)
replace End_M0=empstendm if notempchk==2 | ((empchk==2 & (!inlist(ff_jbstat,12,13)) | (inlist(ff_jbstat,12,13) & nxtst==2)) & inlist(AnnualHistory_Routing,1,2))
replace End_M0=jbendm if (jbsamr==2 | samejob==2) & inlist(AnnualHistory_Routing,1,2)
replace End_Y0=empstendy4 if notempchk==2 | ((empchk==2 & (!inlist(ff_jbstat,12,13)) | (inlist(ff_jbstat,12,13) & nxtst==2)) & inlist(AnnualHistory_Routing,1,2))
replace End_Y0=jbendy4 if (jbsamr==2 | samejob==2) & inlist(AnnualHistory_Routing,1,2)
replace End_D0=empstendd if notempchk==2 & AnnualHistory_Routing==3
replace End_M0=empstendm if notempchk==2 & AnnualHistory_Routing==3
replace End_Y0=empstendy4 if notempchk==2 & AnnualHistory_Routing==3	
/*
// NOTES TO End_D/M/Y0:
End_D/M/Y0 ignores furlough/temp layoff as a status and deals only with underlying employment status. Furlough/temp layoff end dates are ignored. 
When inlist(ff_jbstat,12,13), dates are only calculated if the underlying employment status ends. An end to the underlying employment Status0 is indicated by:
(a) nxtst==2, date empstend*, Status1 nxtstelse. [If also cstat==1, this indicates End_Ind1=1, date nxtstend*.]
(b) (jbsamr==2 | samejob==2), date jbend*, Status1 nxtjbes. [If also cjob==2, this indicates End_Ind1=1, date nxtjbend*.] Note that this condition relates to the use of jbend* dates for all ff_jbstat, not just inlist(ff_jbstat,12,13).
When inlist(ff_jbstat,12,13) & samejob==1, End_D/M/Y0 ignores empstend* dates on the grounds that they relate to the end of furlough/temp layoff rather than underlying employment status.
*/

gen End_D_F0=.
gen End_M_F0=.
gen End_Y_F0=.
replace End_D_F0=empstendd if notempchk==2 /*
	*/ & inlist(AnnualHistory_Routing,1,2)
replace End_D_F0=empstendd if !inlist(ff_jbstat,12,13) /*
	*/ & (inlist(AnnualHistory_Routing,1,2) | AnnualHistory_Routing==3)	// SEE NOTES 1 AND 2.
replace End_D_F0=empstendd if empchk==2 & inlist(ff_jbstat,12,13) /*
	*/ & inlist(AnnualHistory_Routing,1,2)
replace End_D_F0=jbendd if empchk==2 & inlist(ff_jbstat,12,13) & (jbsamr==2 | samejob==2) & missing(empstend) /*
	*/ & inlist(AnnualHistory_Routing,1,2)									// SEE NOTE 3.
replace End_D_F0=jbendd if !inlist(ff_jbstat,12,13) & (jbsamr==2 | samejob==2) /*
	*/ & (inlist(AnnualHistory_Routing,1,2) | AnnualHistory_Routing==3)	// SEE NOTE 2.
replace End_D_F0=jbendd if empchk==1 & inlist(ff_jbstat,12,13) & (jbsamr==2 | samejob==2) /*
	*/ & (inlist(AnnualHistory_Routing,1,2) | AnnualHistory_Routing==3)	// SEE NOTE 4. 
replace End_M_F0=empstendm if notempchk==2 /*
	*/ & inlist(AnnualHistory_Routing,1,2)
replace End_M_F0=empstendm if !inlist(ff_jbstat,12,13) /*
	*/ & (inlist(AnnualHistory_Routing,1,2) | AnnualHistory_Routing==3)	// SEE NOTES 1 AND 2.
replace End_M_F0=empstendm if empchk==2 & inlist(ff_jbstat,12,13) /*
	*/ & inlist(AnnualHistory_Routing,1,2)
replace End_M_F0=jbendm if empchk==2 & inlist(ff_jbstat,12,13) & (jbsamr==2 | samejob==2) & missing(empstend) /*
	*/ & inlist(AnnualHistory_Routing,1,2)									// SEE NOTE 3.
replace End_M_F0=jbendm if !inlist(ff_jbstat,12,13) & (jbsamr==2 | samejob==2) /*
	*/ & (inlist(AnnualHistory_Routing,1,2) | AnnualHistory_Routing==3)	// SEE NOTE 2.
replace End_M_F0=jbendm if empchk==1 & inlist(ff_jbstat,12,13) & (jbsamr==2 | samejob==2) /*
	*/ & (inlist(AnnualHistory_Routing,1,2) | AnnualHistory_Routing==3)	// SEE NOTE 4. 
replace End_Y_F0=empstendy4 if notempchk==2 /*
	*/ & inlist(AnnualHistory_Routing,1,2)
replace End_Y_F0=empstendy4 if !inlist(ff_jbstat,12,13) /*
	*/ & (inlist(AnnualHistory_Routing,1,2) | AnnualHistory_Routing==3)	// SEE NOTES 1 AND 2.
replace End_Y_F0=empstendy4 if empchk==2 & inlist(ff_jbstat,12,13) /*
	*/ & inlist(AnnualHistory_Routing,1,2)
replace End_Y_F0=jbendy4 if empchk==2 & inlist(ff_jbstat,12,13) & (jbsamr==2 | samejob==2) & missing(empstend) /*
	*/ & inlist(AnnualHistory_Routing,1,2)									// SEE NOTE 3.
replace End_Y_F0=jbendy4 if !inlist(ff_jbstat,12,13) & (jbsamr==2 | samejob==2) /*
	*/ & (inlist(AnnualHistory_Routing,1,2) | AnnualHistory_Routing==3)	// SEE NOTE 2.
replace End_Y_F0=jbendy4 if empchk==1 & inlist(ff_jbstat,12,13) & (jbsamr==2 | samejob==2) /*
	*/ & (inlist(AnnualHistory_Routing,1,2) | AnnualHistory_Routing==3)	// SEE NOTE 4. 
replace End_D_F0=empstendd if notempchk==2 & AnnualHistory_Routing==3
replace End_M_F0=empstendm if notempchk==2 & AnnualHistory_Routing==3
replace End_Y_F0=empstendy4 if notempchk==2 & AnnualHistory_Routing==3	
/*
// NOTES TO End_D/M/Y_F0:
1. All cases where empchk==2 & !missing(samejob), apart from 1, relate to inlist(ff_jbstat,12,13). That 1 inconsistently reports nxtst==2, samejob==1, so is ignored.
2. The requirement that notempchk dominates if AnnualHistory_Routing==3 is relaxed for _F variables: to match the extra status changes arising from comparing ff_jbstat and jbstat, it is necessary to also consider reported spell ends when empchk==2 and notempchk==1.
3. jbend* is used in 3 cases where empstend==.m and jbend* is available. This implies a simultaneous end of furlough and job spell, which is treated as described in (iii) below.
4. A small number of cases report empchk==1, so no empstend* dates, but report job change (jbsamr==2 | samejob==2). This implies a simultaneous end of furlough and job spell, which is treated as described in (iii) below.
End_D/M/Y_F0 captures status changes including furlough, like End_Ind_F0. 
When inlist(ff_jbstat,12,13), empstend* dates [are taken to] relate to the end of the inlist(ff_jbstat,12,13) Status0.
(a) nxtst==2: If furlough/temp layoff end coincides with end of employment status (indicated by nxtst==2 - next spell non-employment), the empstend* dates also apply to end of employment status. 
(b) nxtst==1: If employment continues after furlough/temp layoff ends, nxtst==1. The underlying employment status ends if (jbsamr==2 | samejob==2), date jbend*.
compare empstend jbend if inlist(ff_jbstat,12,13) & nxtst==1 & (jbsamr==2 | samejob==2)	// NOTE: The condition nxtst==1 is unnecessary as it is implied by (jbsamr==2 | samejob==2).
                                        ---------- Difference ----------
                            Count       Minimum      Average     Maximum
------------------------------------------------------------------------
empstend<jbend                  5            -5         -3.2          -1
empstend=jbend                  5
empstend>jbend                  4             1         3.25           6
                       ----------
Jointly defined                14            -5    -.2142857           6
empstend missing only           3
Jointly missing                 3
                       ----------
Total                          20

// COMMENTS ON _F VARIABLES:
(i) The data construction focuses on a single main status but in the case of furlough deals with 2 simultaneously held statuses. 
(ii) When furlough is one of the states considered, the start of furlough supersedes/overwrites the (ongoing) employment spell. 
(iii) Furlough and employment status simultaneously end when nxtst==1 & (jbsamr==2 | samejob==2) & jbend*==empstend* - the furlough spell ended at the time the individual changed to a different job. 
(iv) When a furlough Status0 ends (End_Ind_F0=1, End_D/M/Y_F0=empstend*), the simultaneous end of the employment spell is not separately recorded in End_Ind0_F or End_D/M/Y0_F, and Status 1 is whatever comes after. Information about whether or not the employment spell has ended at the same time as the furlough spell cannot be inferred from the single spell end indicator End_Ind_F0 or single spell end date variable End_D/M/Y_F0, but is provided in the Furl_Change_F1 indicator. Alternatively, the non-_F version of the data can be examined as non-_F variables relate only to underlying employment spells.
[Comment: The individual experiences 2 simultaneous transitions. It would be possible to embody these differently - for example with transitions from furlough Status0, End_Ind0=1, End_D/M/Y0, and to next status Status 1, End_Ind1=1, End_D/M/Y1, in consecutive time intervals; in the final monthly dataset, the events would be in consecutive months. This illustrates the difficulty of presenting simultaneously held statuses.]
(v) If the employment spell ends after the ended furlough spell (nxtst==1 & (jbsamr==2 | samejob==2) & jbend*==empstend*) Status0 is furlough (End_Ind_F0=1, End_M_F0=empstend*), Status 1 is the (continued) employment spell (End_Ind_F1=1, End_M_F1=jbend*), Status2 is whatever comes after.
[Durations of active employment will be accurately calculated from the start of employment spell to the end of employment spell - Furl_Change_F1 could be used to ascertain when the employment spell relates to the same job. NOTE: A simple addition of employment spells will exaggerate the true employment spell count, as some employment spells are split into 2 by a spell of furlough/temp layoff.] 
(vi) nxtst==.i: Furloughed respondents last wave who remain in the same furloughed employment spell respond empchk==1. Status0 is furlough, End_Ind_F0=0.
*/


/*
Index Spell Job Change Dummy
*/	
			gen Job_Change_orig0=.i													// LW ORIGINAL CODE, THOUGH VARIABLE RENAMED WITH SUFFIX _orig.
			replace Job_Change_orig0=0 if inlist(Status_orig0,1,2,100)

gen Job_Change0=.i	
replace Job_Change0=0 if inlist(Status0,1,2,100)

gen Job_Change_F0=.i
replace Job_Change_F0=0 if inlist(Status_F0,1,2,112,113,212,213,10012,10013)


/*
Index Spell Furlough Change Dummy													// ADDITIONAL SECTION.
*/	
// NOTE: Only applies to _F: base case (un-suffixed) does not treat furlough as a separate status and considers only underlying employment spell; _orig treats inlist(jbstat,12,13) like another non-employment status.

gen Furl_Change_F0=.i
replace Furl_Change_F0=0 if inlist(Status_F0,12,13)

/*
Description of furlough end situation
*/	
gen Furl_Change_F1=.i
replace Furl_Change_F1=0 if inlist(ff_jbstat,12,13) & empchk==1 & samejob==1 & ff_jbstat==jbstat
replace Furl_Change_F1=1 if inlist(ff_jbstat,12,13) & nxtst==1 & ((samejob==1 & cjob!=2 & !inlist(jbstat,12,13)) | (jbend>empstend & !missing(jbend,empstend)))
replace Furl_Change_F1=2 if inlist(ff_jbstat,12,13) & nxtst==1 & (jbsamr==2 | samejob==2) & jbend==empstend & !missing(jbend,empstend)
replace Furl_Change_F1=3 if inlist(ff_jbstat,12,13) & nxtst==1 & (jbsamr==2 | samejob==2) & jbend<empstend & !missing(jbend,empstend)
replace Furl_Change_F1=4 if inlist(ff_jbstat,12,13) & empchk==1 & jbsamr==2 
replace Furl_Change_F1=4 if inlist(ff_jbstat,12,13) & empchk==2 & (jbsamr==2 | samejob==2) & missing(empstend)
replace Furl_Change_F1=5 if inlist(ff_jbstat,12,13) & nxtst==1 & samejob==1 & cjob==1 & inlist(jbstat,12,13)
replace Furl_Change_F1=6 if inlist(ff_jbstat,12,13) & nxtst==2
replace Furl_Change_F1=7 if inlist(ff_jbstat,12,13) & !inlist(jbstat,12,13) & empchk==1 & samejob==1
replace Furl_Change_F1=8 if inlist(ff_jbstat,12,13) & nxtst==1 & samejob==1 & !inlist(jbstat,12,13) & cjob==2
label define furl_change /*
	*/ 0 "0. Still furloughed" /*
	*/ 1 "1. Furlough ends, job continues" /*		// A single employment spell is split into 2 by a furlough spell.
	*/ 2 "2. Furlough & job end, same end date" /*
	*/ 3 "3. Furlough & job end, End_*0=furlough end date though job ends first" /*	// Dataset records main activity which was stated to be Furlough/Temp layoff at last wave, so that activity lasts until its end, despite a simultaneously-held employment spell ending first and a new job starting prior to the end of the furlough spell.
	*/ 4 "4. Job end info only" /*
	*/ 5 "5. Furlough ends, followed by further furlough spell in same job" /*
	*/ 6 "6. Furlough ends to non-employment" /*
	*/ 7 "7. No info on furlough end, same job, next wave status not furlough" /*
	*/ 8 "8. Furlough ends, job continues"			// Same as Furl_Change_F1==1 in that samejob==1, but inconsistently report cjob==2. SEE NOTE 1.
label values Furl_Change_F1 furl_change
/*
// NOTES: Description of furlough end situation:
Spell 0 is furlough. The statement nxtst==1 is interpreted as "furlough ends". Most (52) Furl_Change_F1 state empstendd/m/y4, which is interpreted as furlough end date; 2 just state empstendy4; for the remaining 11, empstendd/m/y4 is missing. In 5 cases, the Spell 1 job, that continues after furlough, ends at jbendd/m/y4, and Spell 2 starts. In 4 of these cases, cjob==1: Spell 2 does not end before the next interview. In 1 of these cases, cjob==2, indicating that the Spell 2 job ends at nxtjbendd/m/y4 (and Status 2 employment status is given by nxtjbes and nxtjbhrs).
1. Surprisingly/inconsistently, there are 2 other cases of samejob==1 where cjob==2; the inconsistency arises because these 2 cases state jbsamr==1 and samejob==1, which is not consistent with cjob==2 and lead to a path through the questionnaire that results in missing (inapplicable) jbendd/m/y4 whereas nxtendd/m/y4 are present. It is assumed in these 2 cases that nxtjbendd/m/y4 dates relate to the end of Spell 1 (the previously-furloughed job). This assumption prevents a gap in spell data that would arise if (as is assumed if jbsamr==2 or samejob==2 leading to jbendd/m/y4 being present) nxtjbendd/m/y4 dates for these 2 cases were taken to relate to the end of Spell 2. The 2 rogue cases are identified by Furl_Change_F1==8 & samejob==1 & cjob==2.

// TABULATION:
tab Furl_Change_F1 End_Ind_F0
                      |      End_Ind_F0
       Furl_Change_F1 |         0          1 |     Total
----------------------+----------------------+----------
  0. Still furloughed |         6          0 |         6 
1. Furlough ends, job |         0         63 |        63 
2. Furlough & job end |         0          5 |         5 
3. Furlough & job end |         0          4 |         4 
 4. Job end info only |         0          8 |         8 
5. Furlough ends, fol |         0          3 |         3 
6. Furlough ends to n |         0         19 |        19 
7. No info on furloug |         9          0 |         9 
8. Furlough ends, job |         0          2 |         2 
----------------------+----------------------+----------
                Total |        15        104 |       119 
*/


	*Spell 1*
/*
Spell 1 Exists?
*/
			gen Has_Activity_orig1=1 if End_Ind_orig0==1							// LW ORIGINAL CODE, THOUGH VARIABLE RENAMED WITH SUFFIX _orig.

gen Has_Activity1=1 if End_Ind0==1

gen Has_Activity_F1=1 if End_Ind_F0==1


/*
Spell 1 Status
*/	
			gen Status_orig1=.m if Has_Activity_orig1==1							// LW ORIGINAL CODE, THOUGH VARIABLE RENAMED WITH SUFFIX _orig.
			replace Status_orig1=1 if (inlist(AnnualHistory_Routing,1,2) | (AnnualHistory_Routing==3 & nxtst==1)) & /*
				*/ (nxtjbes==2 | /*
				*/ (cjob==1 & Next_ff_jbstat==1) | /*
				*/ (cjob==1 & !inlist(Next_ff_jbstat,1,2) & jbstat==1) | /*
				*/ (cjob==1 & !inlist(Next_ff_jbstat,1,2) & !inlist(jbstat,1,2) & Next_ff_jbsemp==2) | /*
				*/ (cjob==1 & !inlist(Next_ff_jbstat,1,2) & !inlist(jbstat,1,2) & !inlist(Next_ff_jbsemp,1,2) & jbsemp==2))
			replace Status_orig1=2 if (inlist(AnnualHistory_Routing,1,2) | (AnnualHistory_Routing==3 & nxtst==1)) & /*
				*/ (nxtjbes==1 | /*
				*/ (cjob==1 & Next_ff_jbstat==2) | /*
				*/ (cjob==1 & !inlist(Next_ff_jbstat,1,2) & jbstat==2) | /*
				*/ (cjob==1 & !inlist(Next_ff_jbstat,1,2) & !inlist(jbstat,1,2) & Next_ff_jbsemp==1) | /*
				*/ (cjob==1 & !inlist(Next_ff_jbstat,1,2) & !inlist(jbstat,1,2) & !inlist(Next_ff_jbsemp,1,2) & jbsemp==1))
			replace Status_orig1=nxtstelse+2 if inrange(nxtstelse,1,7)
			replace Status_orig1=97 if nxtstelse==8
			replace Status_orig1=100 if !inlist(Status_orig1,1,2) & /*
				*/ (nxtst==1 | (inlist(AnnualHistory_Routing,1,2) & (jbsamr==2 | samejob==2)))
			replace Status_orig1=101 if nxtst==2 & missing(nxtstelse)

gen Status1=.m if Has_Activity1==1
replace Status1=1 if (inlist(AnnualHistory_Routing,1,2) | (AnnualHistory_Routing==3 & nxtst==1)) & /*
	*/ (nxtjbes==2 | /*
	*/ (cjob==1 & Next_ff_jbstat==1) | /*
	*/ (cjob==1 & !inlist(Next_ff_jbstat,1,2) & jbstat==1) | /*
	*/ (cjob==1 & !inlist(Next_ff_jbstat,1,2) & !inlist(jbstat,1,2) & Next_ff_jbsemp==2) | /*
	*/ (cjob==1 & !inlist(Next_ff_jbstat,1,2) & !inlist(jbstat,1,2) & !inlist(Next_ff_jbsemp,1,2) & jbsemp==2))
replace Status1=2 if (inlist(AnnualHistory_Routing,1,2) | (AnnualHistory_Routing==3 & nxtst==1)) & /*
	*/ (nxtjbes==1 | /*
	*/ (cjob==1 & Next_ff_jbstat==2) | /*
	*/ (cjob==1 & !inlist(Next_ff_jbstat,1,2) & jbstat==2) | /*
	*/ (cjob==1 & !inlist(Next_ff_jbstat,1,2) & !inlist(jbstat,1,2) & Next_ff_jbsemp==1) | /*
	*/ (cjob==1 & !inlist(Next_ff_jbstat,1,2) & !inlist(jbstat,1,2) & !inlist(Next_ff_jbsemp,1,2) & jbsemp==1))
replace Status1=nxtstelse+2 if inrange(nxtstelse,1,7)
replace Status1=97 if nxtstelse==8
replace Status1=100 if !inlist(Status1,1,2) & /*
	*/ (nxtst==1 | (inlist(AnnualHistory_Routing,1,2) & (jbsamr==2 | samejob==2)))
replace Status1=101 if nxtst==2 & missing(nxtstelse)
			
gen Status_F1=.m if Has_Activity_F1==1												// ADDITIONAL CODE.
// For inlist(ff_jbstat,12,13):
replace Status_F1=1 if inlist(Status_F0,112,113) & inlist(AnnualHistory_Routing,1,2) & /*	// SEE NOTE 1.
	*/ ((samejob==1 & nxtst==1) |  /*	//  !!! nxtst==1 UNNECESSARY						// SEE NOTE 2.
	*/ (jbend>empstend & !missing(jbend,empstend)))											// SEE NOTE 3. 
replace Status_F1=1 if inlist(AnnualHistory_Routing,1,2) & inlist(ff_jbstat,12,13) & /*
	*/ jbend<=empstend & /*																	// SEE NOTE 4.
	*/ (nxtjbend>empstend | missing(nxtjbend)) & /* 										// SEE NOTE 5.
	*/ nxtst==1 & /*	//  !!! nxtst==1 UNNECESSARY
	*/ (jbsamr==2 | samejob==2) & /*
	*/ (nxtjbes==2 | /*
	*/ ((cjob==1 & Next_ff_jbstat==1) | /*				
	*/ (cjob==1 & !inlist(Next_ff_jbstat,1,2) & jbstat==1) | /*
	*/ (cjob==1 & !inlist(Next_ff_jbstat,1,2) & !inlist(jbstat,1,2) & Next_ff_jbsemp==2) | /*		
	*/ (cjob==1 & !inlist(Next_ff_jbstat,1,2) & !inlist(jbstat,1,2) & !inlist(Next_ff_jbsemp,1,2) & jbsemp==2)))
// For !inlist(ff_jbstat,12,13):
replace Status_F1=1 if ((inlist(AnnualHistory_Routing,1,2) & !inlist(ff_jbstat,12,13)) | (AnnualHistory_Routing==3 & nxtst==1)) & /*
	*/ (nxtjbes==2 | /*
	*/ (cjob==1 & Next_ff_jbstat==1) | /*
	*/ (cjob==1 & !inlist(Next_ff_jbstat,1,2) & jbstat==1) | /*
	*/ (cjob==1 & !inlist(Next_ff_jbstat,1,2) & !inlist(jbstat,1,2) & Next_ff_jbsemp==2) | /*
	*/ (cjob==1 & !inlist(Next_ff_jbstat,1,2) & !inlist(jbstat,1,2) & !inlist(Next_ff_jbsemp,1,2) & jbsemp==2))
// For all:
replace Status_F1=112 if Status_F1==1 & cjob==1 & jbstat==12
replace Status_F1=113 if Status_F1==1 & cjob==1 & jbstat==13
// For inlist(ff_jbstat,12,13):
replace Status_F1=2 if inlist(Status_F0,212,213) & inlist(AnnualHistory_Routing,1,2) & /*	// SEE NOTE 6.
	*/ ((samejob==1 & nxtst==1) |  /*														// SEE NOTE 2.
	*/ (jbend>empstend & !missing(jbend,empstend)))											// SEE NOTE 3. 
replace Status_F1=2 if inlist(AnnualHistory_Routing,1,2) & inlist(ff_jbstat,12,13) & /*
	*/ jbend<=empstend & /*																	// SEE NOTE 4.
	*/ (nxtjbend>empstend | missing(nxtjbend)) & /* 										// SEE NOTE 5.
	*/ nxtst==1 & /*
	*/ (jbsamr==2 | samejob==2) & /*
	*/ (nxtjbes==1 | /*
	*/ ((cjob==1 & Next_ff_jbstat==2) | /*				
	*/ (cjob==1 & !inlist(Next_ff_jbstat,1,2) & jbstat==2) | /*
	*/ (cjob==1 & !inlist(Next_ff_jbstat,1,2) & !inlist(jbstat,1,2) & Next_ff_jbsemp==1) | /*		
	*/ (cjob==1 & !inlist(Next_ff_jbstat,1,2) & !inlist(jbstat,1,2) & !inlist(Next_ff_jbsemp,1,2) & jbsemp==1)))
// For !inlist(ff_jbstat,12,13):
replace Status_F1=2 if ((inlist(AnnualHistory_Routing,1,2) & !inlist(ff_jbstat,12,13)) | (AnnualHistory_Routing==3 & nxtst==1)) & /*
	*/ (nxtjbes==1 | /*
	*/ (cjob==1 & Next_ff_jbstat==2) | /*
	*/ (cjob==1 & !inlist(Next_ff_jbstat,1,2) & jbstat==2) | /*
	*/ (cjob==1 & !inlist(Next_ff_jbstat,1,2) & !inlist(jbstat,1,2) & Next_ff_jbsemp==1) | /*
	*/ (cjob==1 & !inlist(Next_ff_jbstat,1,2) & !inlist(jbstat,1,2) & !inlist(Next_ff_jbsemp,1,2) & jbsemp==1))
// For all:
replace Status_F1=212 if Status_F1==2 & cjob==1 & jbstat==12
replace Status_F1=213 if Status_F1==2 & cjob==1 & jbstat==13
replace Status_F1=nxtstelse+2 if inrange(nxtstelse,1,7) 									// SEE NOTE 7.
replace Status_F1=97 if nxtstelse==8														// SEE NOTE 7.
replace Status_F1=100 if !inlist(Status_F1,1,2,112,113,212,213,10012,10013) & /*
	*/ (nxtst==1 | (inlist(AnnualHistory_Routing,1,2) & (jbsamr==2 | samejob==2)))	// 100. Paid work
replace Status_F1=101 if nxtst==2 & missing(nxtstelse)								// 101. Something else
/*
// NOTES TO Status_F1:
1. This criterion applies to self employed Status_F1.
2. Same job continues after furlough ends.
3. New job starts after furlough ends. Status_F1 therefore relates to the same job held last wave which continues after furlough ends until new job starts.
4. New job starts/is treated as starting at empstend.
5. If new job ends, new job end date is after empstend.
6. This criterion applies to employed Status_F1.
7. nxtst==2 entails end of furlough at start of non-employment spell.
*/


/*
* Spell 1 Status Source Variable
*/
			gen Source_Variable_orig1=""												// LW ORIGINAL CODE, THOUGH VARIABLE RENAMED WITH SUFFIX _orig.
			replace Source_Variable_orig1="nxtjbes_w"+strofreal(Wave) /*
				*/ if inlist(Status_orig1,1,2) & inlist(nxtjbes,1,2)
			replace Source_Variable_orig1="ff_jbstat_w"+strofreal(Wave+1) /*
				*/  if inlist(Status_orig1,1,2) & Source_Variable_orig1=="" & inlist(Next_ff_jbstat,1,2)
			replace Source_Variable_orig1="jbstat_w"+strofreal(Wave) /*
				*/  if inlist(Status_orig1,1,2) & Source_Variable_orig1=="" & inlist(jbstat,1,2)
			replace Source_Variable_orig1="ff_jbsemp_w"+strofreal(Wave+1) /*
				*/  if inlist(Status_orig1,1,2) & Source_Variable_orig1=="" & inlist(Next_ff_jbsemp,1,2)
			replace Source_Variable_orig1="jbsemp_w"+strofreal(Wave) /*
				*/  if inlist(Status_orig1,1,2) & Source_Variable_orig1=="" & inlist(jbsemp,1,2)
			replace Source_Variable_orig1="nxtstelse_w"+strofreal(Wave) /*
				*/  if inrange(Status_orig1,3,97)
			replace Source_Variable_orig1="nxtst_w"+strofreal(Wave) /*
				*/  if Status_orig1==100 & nxtst==1
			replace Source_Variable_orig1="jbsamr_w"+strofreal(Wave) /*
				*/  if Status_orig1==100 & jbsamr==2
			replace Source_Variable_orig1="samejob_w"+strofreal(Wave) /*
				*/  if Status_orig1==100 & samejob==2
			replace Source_Variable_orig1="nxtst_w"+strofreal(Wave) if Status_orig1==101
			replace Source_Variable_orig1="nxtst_w"+strofreal(Wave) /*
				*/  if inlist(Status_orig1,100,101) & AnnualHistory_Routing==3
				
gen Source_Variable1=""
replace Source_Variable1="nxtjbes_w"+strofreal(Wave) /*
	*/ if inlist(Status1,1,2) & inlist(nxtjbes,1,2)
replace Source_Variable1="ff_jbstat_w"+strofreal(Wave+1) /*
	*/  if inlist(Status1,1,2) & Source_Variable1=="" & inlist(Next_ff_jbstat,1,2)
replace Source_Variable1="jbstat_w"+strofreal(Wave) /*
	*/  if inlist(Status1,1,2) & Source_Variable1=="" & inlist(jbstat,1,2)
replace Source_Variable1="ff_jbsemp_w"+strofreal(Wave+1) /*
	*/  if inlist(Status1,1,2) & Source_Variable1=="" & inlist(Next_ff_jbsemp,1,2)
replace Source_Variable1="jbsemp_w"+strofreal(Wave) /*
	*/  if inlist(Status1,1,2) & Source_Variable1=="" & inlist(jbsemp,1,2)
replace Source_Variable1="nxtstelse_w"+strofreal(Wave) /*
	*/  if inrange(Status1,3,97)
replace Source_Variable1="nxtst_w"+strofreal(Wave) /*
	*/  if Status1==100 & nxtst==1
replace Source_Variable1="jbsamr_w"+strofreal(Wave) /*
	*/  if Status1==100 & jbsamr==2
replace Source_Variable1="samejob_w"+strofreal(Wave) /*
	*/  if Status1==100 & samejob==2
replace Source_Variable1="nxtst_w"+strofreal(Wave) if Status1==101
replace Source_Variable1="nxtst_w"+strofreal(Wave) /*
	*/  if inlist(Status1,100,101) & AnnualHistory_Routing==3
				
gen Source_Variable_F1=""																// ADDITIONAL CODE.
gen Source_Variable_Fa1="ff_jbstat_w"+strofreal(Wave) /*
	*/ if inlist(Status_F0,112,113,212,213,10012,10013) & ((samejob==1 & nxtst==1 & cjob!=2) | (jbend>empstend & !missing(jbend,empstend)))		// SEE NOTE 1.
replace Source_Variable_F1=Source_Variable_Fa1
gen Source_Variable_Fb1="nxtjbes_w"+strofreal(Wave) /*
	*/ if inlist(Status_F0,112,113,212,213,10012,10013) & samejob==1 & nxtst==1 & cjob==2					// SEE NOTE 2.
replace Source_Variable_F1=Source_Variable_Fb1 if Source_Variable_F1==""
gen Source_Variable_Fc1="nxtjbes_w"+strofreal(Wave) /*
	*/ if ((inlist(AnnualHistory_Routing,1,2) & !inlist(ff_jbstat,12,13) & inlist(Status_F1,1,2)) /*
	*/ | (AnnualHistory_Routing==3 & nxtst==1 & Status_F1!=100)) /*
	*/ & Source_Variable_F1=="" & inlist(nxtjbes,1,2)
replace Source_Variable_F1=Source_Variable_Fc1 if Source_Variable_F1==""
gen Source_Variable_Fd1="ff_jbstat_w"+strofreal(Wave+1) /*
	*/ if ((inlist(ff_jbstat,12,13) & (nxtjbend>empstend | missing(nxtjbend)) & nxtst==1 & (jbsamr==2 | samejob==2)) /*
	*/ | (inlist(AnnualHistory_Routing,1,2) & !inlist(ff_jbstat,12,13) & inlist(Status_F1,1,2)) /*
	*/ | (AnnualHistory_Routing==3 & nxtst==1 & Status_F1!=100)) /*
	*/ & Source_Variable_F1=="" & inlist(Next_ff_jbstat,1,2)
replace Source_Variable_F1=Source_Variable_Fd1 if Source_Variable_F1==""
gen Source_Variable_Fe1="jbstat_w"+strofreal(Wave) /*
	*/ if ((inlist(ff_jbstat,12,13) & (nxtjbend>empstend | missing(nxtjbend)) & nxtst==1 & (jbsamr==2 | samejob==2)) /*
	*/ | (inlist(AnnualHistory_Routing,1,2) & !inlist(ff_jbstat,12,13) & inlist(Status_F1,1,2)) /*
	*/ | (AnnualHistory_Routing==3 & nxtst==1 & Status_F1!=100)) /*
	*/ & Source_Variable_F1=="" & inlist(jbstat,1,2)
replace Source_Variable_F1=Source_Variable_Fe1 if Source_Variable_F1==""
gen Source_Variable_Ff1="ff_jbsemp_w"+strofreal(Wave+1) /*
	*/ if ((inlist(ff_jbstat,12,13) & (nxtjbend>empstend | missing(nxtjbend)) & nxtst==1 & (jbsamr==2 | samejob==2)) /*
	*/ | (inlist(AnnualHistory_Routing,1,2) & !inlist(ff_jbstat,12,13) & inlist(Status_F1,1,2)) /*
	*/ | (AnnualHistory_Routing==3 & nxtst==1 & Status_F1!=100)) /*
	*/ & Source_Variable_F1=="" & inlist(Next_ff_jbsemp,1,2)
replace Source_Variable_F1=Source_Variable_Ff1 if Source_Variable_F1==""
gen Source_Variable_Fg1="jbsemp_w"+strofreal(Wave) /*
	*/ if ((inlist(ff_jbstat,12,13) & (nxtjbend>empstend | missing(nxtjbend)) & nxtst==1 & (jbsamr==2 | samejob==2)) /*
	*/ | (inlist(AnnualHistory_Routing,1,2) & !inlist(ff_jbstat,12,13) & inlist(Status_F1,1,2,112,113,212,213)) /*
	*/ | (AnnualHistory_Routing==3 & nxtst==1 & Status_F1!=100)) /*
	*/ & Source_Variable_F1=="" & inlist(jbsemp,1,2)
replace Source_Variable_F1=Source_Variable_Fg1 if Source_Variable_F1==""
gen Source_Variable_Fh1="nxtstelse_w"+strofreal(Wave) /*
	*/  if (inrange(Status_F1,3,11) | inlist(Status_F1,14,15) | Status_F1==97)
replace Source_Variable_F1=Source_Variable_Fh1 if Source_Variable_F1==""
gen Source_Variable_Fi1="nxtst_w"+strofreal(Wave) /*
	*/  if Status_F1==100 & nxtst==1 & !inlist(ff_jbstat,12,13)								// SEE NOTE 3.
replace Source_Variable_F1=Source_Variable_Fi1 if Source_Variable_F1==""
gen Source_Variable_Fj1="jbsamr_w"+strofreal(Wave) /*
	*/  if Status_F1==100 & jbsamr==2
replace Source_Variable_F1=Source_Variable_Fj1 if Source_Variable_F1==""
gen Source_Variable_Fk1="samejob_w"+strofreal(Wave) /*
	*/  if Status_F1==100 & samejob==2
replace Source_Variable_F1=Source_Variable_Fk1 if Source_Variable_F1==""
gen Source_Variable_Fl1="nxtst_w"+strofreal(Wave) if Status_F1==101
replace Source_Variable_F1=Source_Variable_Fl1 if Source_Variable_F1==""
gen Source_Variable_Fm1="nxtst_w"+strofreal(Wave) /*
	*/  if inlist(Status_F1,100,101) & AnnualHistory_Routing==3	
replace Source_Variable_F1=Source_Variable_Fm1 if Source_Variable_F1==""
gen Source_Variable_Fn1=Source_Variable_F1+","+"jbstat_w"+strofreal(Wave) if cjob==1 & inlist(jbstat,12,13) & inlist(Status_F1,112,113,212,213)
replace Source_Variable_F1=Source_Variable_Fn1 if Source_Variable_Fn1!=""
/*
// NOTES TO Spell 1 Source
1. The criterion "& cjob!=2" is included to distinguish Furl_Change_F1==1 from Furl_Change_F1==8.
2. This line, including condition "& cjob==2", relates to Furl_Change_F1==8 (2 cases).
3. & !inlist(ff_jbstat,12,13) is included because nxtst==1 for all inlist(ff_jbstat,12,13) who answer empchk==2 (which is the case for most furloughed individuals).
*/
drop Source_Variable_Fa1 Source_Variable_Fb1 Source_Variable_Fc1 Source_Variable_Fd1 Source_Variable_Fe1 Source_Variable_Ff1 Source_Variable_Fg1 Source_Variable_Fh1 Source_Variable_Fi1 Source_Variable_Fj1 Source_Variable_Fk1 Source_Variable_Fl1 Source_Variable_Fm1 Source_Variable_Fn1

/*
Spell 1 End indicator
*/	
			gen End_Ind_orig1=.m if Has_Activity_orig1==1							// LW ORIGINAL CODE, THOUGH VARIABLE RENAMED WITH SUFFIX _orig.
			replace End_Ind_orig1=0 if (cstat==2 | cjob==1) & inlist(AnnualHistory_Routing,1,2)
			replace End_Ind_orig1=1 if (cstat==1 | cjob==2) & inlist(AnnualHistory_Routing,1,2)
			replace End_Ind_orig1=0 if (cstat==2 | (cjob==1 & nxtst==1)) & Has_Activity_orig1==1 & AnnualHistory_Routing==3
			replace End_Ind_orig1=1 if (cstat==1 | (cjob==2 & nxtst==1)) & Has_Activity_orig1==1 & AnnualHistory_Routing==3

gen End_Ind1=.m if Has_Activity1==1
replace End_Ind1=0 if (cstat==2 | cjob==1) & inlist(AnnualHistory_Routing,1,2)
replace End_Ind1=1 if (cstat==1 | cjob==2) & inlist(AnnualHistory_Routing,1,2)
replace End_Ind1=0 if (cstat==2 | (cjob==1 & nxtst==1)) & Has_Activity1==1 & AnnualHistory_Routing==3
replace End_Ind1=1 if (cstat==1 | (cjob==2 & nxtst==1)) & Has_Activity1==1 & AnnualHistory_Routing==3

gen End_Ind_F1=.m if Has_Activity_F1==1
replace End_Ind_F1=0 if !inlist(ff_jbstat,12,13) & (cstat==2 | cjob==1) & inlist(AnnualHistory_Routing,1,2)	// SEE NOTES 1 AND 2. Non-furlough Status 0, Status 1 non-employment/employment, Status 1 is current status.
replace End_Ind_F1=0 if inlist(ff_jbstat,12,13) & /*
	*/ (cstat==2 | /* 													// SEE NOTE 3. Status0 furlough, Status1 non-employment, not ended. [nxtst==2]
	*/ (jbend<=empstend & !missing(jbend,empstend) & cjob==1) |	/*		// SEE NOTE 4. Status0 furlough, Status1 new job starts before/simultaneously with furlough end, not ended. [nxtst==1]
	*/ (samejob==1 & cjob==1 & !inlist(jbstat,12,13)) | /*				// SEE NOTE 5. Status0 furlough, Status1 pre-furlough job, not ended. !inlist(jbstat,12,13) rules out a further furlough spell. A single employment spell, current job, is split into 2 by a furlough spell. [nxtst==1]
	*/ (samejob==1 & cjob==1 & inlist(jbstat,12,13)))					// SEE NOTE 6. Status 0 furlough, furlough ends, same job, current wave status is furlough/temp layoff. This is interpreted as 2 furlough spells in the same job. SEE NOTE 3. [nxtst==1]
replace End_Ind_F1=0 if inlist(ff_jbstat,12,13) & (jbsamr==2 | samejob==2) & missing(empstend) & cjob==1 // SEE NOTE 7. Status0 furlough, Status1 new job, not ended. Job end info only. THESE CASES ARE TREATED AS THOUGH THEY HAVE SIMULTANEOUS FURLOUGH AND JOB END.
replace End_Ind_F1=1 if !inlist(ff_jbstat,12,13) & (cstat==1 | cjob==2) & inlist(AnnualHistory_Routing,1,2)	// SEE NOTE 1. Non-furlough Status0, Status 1 non-employment/employment, Status 1 has ended.
replace End_Ind_F1=1 if inlist(ff_jbstat,12,13) & /*
	*/ (cstat==1 | /*													// SEE NOTE 8. Status0 furlough, Status1 non-employment, ended. [nxtst==2]
	*/ (jbend<=empstend & !missing(jbend,empstend) & cjob==2) | /*		// SEE NOTE 9. Status0 furlough, Status 1 new job, ended. [nxtst==1]
	*/ (jbend>empstend & !missing(jbend,empstend)) | /*					// SEE NOTE 10. Status 0 furlough, Status 1 pre-furlough job, ended at jbend>empstend. [nxtst==1]
	*/ (samejob==1 & cjob==2))											// SEE NOTE 11. Status 0 furlough, (despite samejob==1) next job is not current job. [nxtst==1]
replace End_Ind_F1=1 if inlist(ff_jbstat,12,13) & (jbsamr==2 | samejob==2) & missing(empstend) & cjob==2 // SEE NOTE 12. Status0 furlough, Status1 new job, ended. Job end info only. THESE CASES ARE TREATED AS THOUGH THEY HAVE SIMULTANEOUS FURLOUGH AND JOB END.
replace End_Ind_F1=0 if (cstat==2 | (cjob==1 & nxtst==1)) & Has_Activity_F1==1 & AnnualHistory_Routing==3	// SEE NOTE 1.
replace End_Ind_F1=1 if (cstat==1 | (cjob==2 & nxtst==1)) & Has_Activity_F1==1 & AnnualHistory_Routing==3	// SEE NOTE 1.
/*
// NOTES TO End_Ind_F1
1. End_Ind_F1 for these cases is defined as for End_Ind_orig1.
2. Non-furlough Status 0, Status 1 non-employment/employment, Status 1 is current status.
3. Status0 furlough, Status1 non-employment, not ended.
4. Status0 furlough, Status1 new job starts before/simultaneously with furlough end, not ended. 
5. Status0 furlough, Status1 pre-furlough job, not ended. !inlist(jbstat,12,13) rules out a further furlough spell. A single employment spell, current job, is split into 2 by a furlough spell.
6. Status0 furlough, furlough ends, same job, current wave status is furlough/temp layoff. These cases are characterised by [!missing(empstend) and] remaining in the same job, which is current at the next interview, where furlough is again the reported status. This is interpreted as 2 consecutive furlough spells in the same job. There is no information (and no information about dates relating to) any non-furlough employment spell between the two furlough spells, so no such spell is imputed/used to calculate End_Ind_F1, and Status_F1 is furlough.fs
7. Status0 furlough, Status1 new job, not ended.
8. Status0 furlough, Status1 non-employment, ended.
9. Status0 furlough, Status1 new job, ended.
10. Status0 furlough, Status1 pre-furlough job, ended at jbend>empstend.
11. Status0 furlough, (despite samejob==1) next job is not current job.
12. Status0 furlough, Status1 new job, ended.
*/


/*
* Status 1 End Dates 
*/
			gen End_D_orig1=cond(cstat==1,nxtstendd,cond(cjob==2,nxtjbendd,.)) if End_Ind_orig1==1	// LW ORIGINAL CODE, THOUGH VARIABLE RENAMED WITH SUFFIX _orig.
			gen End_M_orig1=cond(cstat==1,nxtstendm,cond(cjob==2,nxtjbendm,.)) if End_Ind_orig1==1
			gen End_Y_orig1=cond(cstat==1,nxtstendy4,cond(cjob==2,nxtjbendy4,.)) if End_Ind_orig1==1

gen End_D1=cond(cstat==1,nxtstendd,cond(cjob==2,nxtjbendd,.)) if End_Ind1==1
gen End_M1=cond(cstat==1,nxtstendm,cond(cjob==2,nxtjbendm,.)) if End_Ind1==1
gen End_Y1=cond(cstat==1,nxtstendy4,cond(cjob==2,nxtjbendy4,.)) if End_Ind1==1
			
gen End_D_F1=.																		// ADDITIONAL CODE.
gen End_M_F1=.
gen End_Y_F1=.
replace End_D_F1=cond(cstat==1,nxtstendd,cond(cjob==2,nxtjbendd,.)) if End_Ind_F1==1 & /*
	*/ ((notempchk==2 & (inlist(AnnualHistory_Routing,1,2) | AnnualHistory_Routing==3)) | /*								// CASE 1.
	*/ !inlist(ff_jbstat,12,13) | /*																						// CASE 2.
	*/ (empchk==2 & inlist(ff_jbstat,12,13) & (jbsamr==2 | samejob==2) & missing(empstend)) | /*							// CASE 3.
	*/ (empchk==1 & inlist(ff_jbstat,12,13) & (jbsamr==2 | samejob==2)) | /*												// CASE 4.
	*/ (empchk==2 & inlist(ff_jbstat,12,13) & (jbsamr==2 | samejob==2) & jbend<empstend & !missing(jbend,empstend)) | /*	// CASE 5.
	*/ (empchk==2 & inlist(ff_jbstat,12,13) & cstat==1)) 																	// CASE 6.
replace End_D_F1=nxtjbendd if Furl_Change_F1==8																				// CASE 7.
replace End_D_F1=jbendd if Furl_Change_F1==1 & (jbsamr==2 | samejob==2)														// CASE 8.
replace End_M_F1=cond(cstat==1,nxtstendm,cond(cjob==2,nxtjbendm,.)) if End_Ind_F1==1 & /*
	*/ ((notempchk==2 & (inlist(AnnualHistory_Routing,1,2) | AnnualHistory_Routing==3)) | /*
	*/ !inlist(ff_jbstat,12,13) | /*
	*/ (empchk==2 & inlist(ff_jbstat,12,13) & (jbsamr==2 | samejob==2) & missing(empstend)) | /*
	*/ (empchk==1 & inlist(ff_jbstat,12,13) & (jbsamr==2 | samejob==2)) | /*
	*/ (empchk==2 & inlist(ff_jbstat,12,13) & (jbsamr==2 | samejob==2) & jbend<empstend & !missing(jbend,empstend)) | /*
	*/ (empchk==2 & inlist(ff_jbstat,12,13) & cstat==1))
replace End_M_F1=nxtjbendm if Furl_Change_F1==8
replace End_M_F1=jbendm if Furl_Change_F1==1 & (jbsamr==2 | samejob==2)
replace End_Y_F1=cond(cstat==1,nxtstendy4,cond(cjob==2,nxtjbendy4,.)) if End_Ind_F1==1 & /*
	*/ ((notempchk==2 & (inlist(AnnualHistory_Routing,1,2) | AnnualHistory_Routing==3)) | /*
	*/ !inlist(ff_jbstat,12,13) | /*
	*/ (empchk==2 & inlist(ff_jbstat,12,13) & (jbsamr==2 | samejob==2) & missing(empstend)) | /*
	*/ (empchk==1 & inlist(ff_jbstat,12,13) & (jbsamr==2 | samejob==2)) | /*
	*/ (empchk==2 & inlist(ff_jbstat,12,13) & (jbsamr==2 | samejob==2) & jbend<empstend & !missing(jbend,empstend)) | /*
	*/ (empchk==2 & inlist(ff_jbstat,12,13) & cstat==1))
replace End_Y_F1=nxtjbendy4 if Furl_Change_F1==8
replace End_Y_F1=jbendy4 if Furl_Change_F1==1 & (jbsamr==2 | samejob==2)
/*
// NOTES TO End_D/M/Y_F1:
* These cases are the same as End_*_orig1:
1 if notempchk==2
2 if !inlist(ff_jbstat,12,13)
3 if empchk==2 & inlist(ff_jbstat,12,13) & (jbsamr==2 | samejob==2) & missing(empstend)
4 if empchk==1 & inlist(ff_jbstat,12,13) & (jbsamr==2 | samejob==2)
5 if empchk==2 & inlist(ff_jbstat,12,13) & (jbsamr==2 | samejob==2) & jbend<empstend & !missing(jbend,empstend)	// Furl_Change_F1==3
6 if empchk==2 & inlist(ff_jbstat,12,13) & cstat==1	// Furl_Change_F1==6. 
7 Furl_Change_F1==8 are similar to Furl_Change_F1==1 but state cjob==2 as well as samejob==1 (2 cases). In these 2 cases, wkplsam==2 (different workplace). jbendd/m/y4 is missing (questions not asked due to samejob==1). nxtjbendd/m/y4 are assumed to relate to the end of Spell1/Status1. Status0 furlough, Status1 job is assumed to continue until nxtjbendd/m/y4.
* These cases are different from End_*_orig1:
8 if empchk==2 & inlist(ff_jbstat,12,13) & inlist(AnnualHistory_Routing,1,2)	// (Note !missing(empstend).) Furl_Change_F1==1: jbendd if (jbsamr==2 | samejob==2)	// Status0 furlough, Status1 job continues until jbend. !missing(jbend) implies Status 2 exists. Status2 continues if cjob==1; Status2 ends if cjob==2, at nxtjbend.
*/


/*
Spell 1 Job Change Indicator
*/
			gen Job_Change_orig1=.i if Has_Activity_orig1==1						// LW ORIGINAL CODE, THOUGH VARIABLE RENAMED WITH SUFFIX _orig.
			replace Job_Change_orig1=2 if samejob==2 & inlist(Status_orig1,1,2,100)
			replace Job_Change_orig1=3 if jbsamr==2 & inlist(Status_orig1,1,2,100)
			replace Job_Change_orig1=3 if nxtst==1

gen Job_Change1=.i if Has_Activity1==1
replace Job_Change1=2 if samejob==2 & inlist(Status1,1,2,100)
replace Job_Change1=3 if jbsamr==2 & inlist(Status1,1,2,100)
replace Job_Change1=3 if nxtst==1

gen Job_Change_F1=.i if Has_Activity_F1==1											// ADDITIONAL CODE.
replace Job_Change_F1=1 if inlist(Furl_Change_F1,1,5,7)
replace Job_Change_F1=2 if samejob==2 & /*
	*/ missing(Job_Change_F1) & /*
	*/ inlist(Status_F1,1,2,12,13,100,112,113,212,213) & /*
	*/ (!inlist(ff_jbstat,12,13) | /*
	*/ inlist(Furl_Change_F1,2,3,4,6,8))
replace Job_Change_F1=3 if jbsamr==2 & /*
	*/ missing(Job_Change_F1) & /*
	*/ inlist(Status_F1,1,2,12,13,100,112,113,212,213) & /*
	*/ (!inlist(ff_jbstat,12,13) | /*
	*/ inlist(Furl_Change_F1,2,3,4,6,8))
replace Job_Change_F1=3 if nxtst==1 & /*
	*/ missing(Job_Change_F1) & /*
	*/ (!inlist(ff_jbstat,12,13) | /*
	*/ inlist(Furl_Change_F1,2,3,4,6,8))
/*
// NOTES TO Job_Change_F1:
For inlist(ff_jbstat,12,13) and _F:
- Furlough does not end if Furl_Change_F1==0)
- Return to the same job if inlist(Furl_Change_F1,1,5,7)
- Job ends if inlist(Furl_Change_F1,2,3,4,6,8) 

tab Furl_Change_F1 Job_Change_F1
                      |          Job_Change_F1
       Furl_Change_F1 |         1          2          3 |     Total
----------------------+---------------------------------+----------
1. Furlough ends, job |        63          0          0 |        63 
2. Furlough & job end |         0          0          5 |         5 
3. Furlough & job end |         0          1          3 |         4 
 4. Job end info only |         0          1          7 |         8 
5. Furlough ends, fol |         3          0          0 |         3 
7. No info on furloug |         9          0          0 |         9 
8. Furlough ends, job |         0          0          2 |         2 
----------------------+---------------------------------+----------
                Total |        75          2         17 |        94

// Job_Change_orig1 RECORDS INDIVIDUALS COMING OFF FURLOUGH AS "3. New employer" BECAUSE nxtst==1.
tab Furl_Change_F1 Job_Change_orig1, mis
                      |              Job_Change_orig1
       Furl_Change_F1 |         2          3          .         .i |     Total
----------------------+--------------------------------------------+----------
  0. Still furloughed |         0          0          6          0 |         6 
1. Furlough ends, job |         0         63          0          0 |        63 
2. Furlough & job end |         0          5          0          0 |         5 
3. Furlough & job end |         0          4          0          0 |         4 
 4. Job end info only |         0          8          0          0 |         8 
5. Furlough ends, fol |         0          3          0          0 |         3 
6. Furlough ends to n |         0          0          0         19 |        19 
7. No info on furloug |         0          0          9          0 |         9 
8. Furlough ends, job |         0          2          0          0 |         2 
                   .i |     6,514     30,928    344,281     20,701 |   402,424 
----------------------+--------------------------------------------+----------
                Total |     6,514     31,013    344,296     20,720 |   402,543 
*/


	*Spell 2*
/*
Spell 2 Exists?
*/
				gen Has_Activity_orig2=1 if End_Ind_orig1==1						// LW ORIGINAL CODE, THOUGH VARIABLE RENAMED WITH SUFFIX _orig.

gen Has_Activity2=1 if End_Ind1==1
				
gen Has_Activity_F2=1 if End_Ind_F1==1												// ADDITIONAL CODE.


/*
Spell 2 Status
*/
				gen Status_orig2=.m if Has_Activity_orig2==1						// LW ORIGINAL CODE, THOUGH VARIABLE RENAMED WITH SUFFIX _orig.
				replace Status_orig2=1 if nextjob1==3
				replace Status_orig2=2 if inlist(nextjob1,1,2,4)
				replace Status_orig2=nextelse1+2 if inrange(nextelse1,1,7)
				replace Status_orig2=97 if nextelse1==8
				replace Status_orig2=100 if nextstat1==1 & missing(nextjob1)
				replace Status_orig2=101 if nextstat1==2 & missing(nextelse1)
		
gen Status2=.m if Has_Activity2==1
replace Status2=1 if nextjob1==3
replace Status2=2 if inlist(nextjob1,1,2,4)
replace Status2=nextelse1+2 if inrange(nextelse1,1,7)
replace Status2=97 if nextelse1==8
replace Status2=100 if nextstat1==1 & missing(nextjob1)
replace Status2=101 if nextstat1==2 & missing(nextelse1)

gen Status_F2=.m if Has_Activity_F2==1												// ADDITIONAL CODE.
* Same as Status_orig2 if: !inlist(ff_jbstat,12,13) and inlist(Furl_Change_F1,2,3,4,6,8). If inlist(Furl_Change_F1,2,3,4,6,8): Status0 furlough, Status1 nxtjbes/nxtstelse/nxtst, Status2 nextjob1/nextelse1/nextstat1. (Memo: If Furl_Change_F1==5, Status1 does not end (End_Ind_F1=0).)
replace Status_F2=1 if nextjob1==3 & /*
	*/ (!inlist(ff_jbstat,12,13) | /*
	*/ inlist(Furl_Change_F1,2,3,4,6,8))
replace Status_F2=2 if inlist(nextjob1,1,2,4) & /*
	*/ (!inlist(ff_jbstat,12,13) | /*
	*/ inlist(Furl_Change_F1,2,3,4,6,8))
replace Status_F2=nextelse1+2 if inrange(nextelse1,1,7) & /*
	*/ (!inlist(ff_jbstat,12,13) | /*
	*/ inlist(Furl_Change_F1,2,3,4,6,8))
replace Status_F2=97 if nextelse1==8 & /*
	*/ (!inlist(ff_jbstat,12,13) | /*
	*/ inlist(Furl_Change_F1,2,3,4,6,8))
replace Status_F2=100 if nextstat1==1 & missing(nextjob1) & /*
	*/ (!inlist(ff_jbstat,12,13) | /*
	*/ inlist(Furl_Change_F1,2,3,4,6,8))
replace Status_F2=101 if nextstat1==2 & missing(nextelse1) & /*
	*/ (!inlist(ff_jbstat,12,13) | /*
	*/ inlist(Furl_Change_F1,2,3,4,6,8))
* If Furl_Change_F1==1: Status0 furlough, Status1 pre-furlough job, Status2 nxtjbes/nxtstelse/nxtst.
replace Status_F2=1 if nxtjbes==2 & /*
	*/ Furl_Change_F1==1 & End_Ind_F1==1
replace Status_F2=2 if nxtjbes==1 & /*
	*/ Furl_Change_F1==1 & End_Ind_F1==1
replace Status_F2=nxtstelse+2 if inrange(nxtstelse,1,7) & /*
	*/ Furl_Change_F1==1 & End_Ind_F1==1
replace Status_F2=97 if nxtstelse==8 & /*
	*/ Furl_Change_F1==1 & End_Ind_F1==1
replace Status_F2=100 if (nxtjbes==.m | (jbsamr==2 | samejob==2)) & /*
	*/ Furl_Change_F1==1 & End_Ind_F1==1 /*
	*/ & !inlist(Status_F2,1,2,112,113,212,213)


/*
Spell 2 Status Source Variable
*/
		gen Source_Variable_orig2=""													// LW ORIGINAL CODE, THOUGH VARIABLE RENAMED WITH SUFFIX _orig.
		replace Source_Variable_orig2="nxtjob`i'_w"+strofreal(Wave) if Status_orig2==1 | Status_orig2==2
		replace Source_Variable_orig2="nxtstelse`i'_w"+strofreal(Wave) if inrange(Status_orig2,3,97)
		replace Source_Variable_orig2="nxtst`i'_w"+strofreal(Wave) if Status_orig2==100 | Status_orig2==101
			
gen Source_Variable2=""
replace Source_Variable2="nxtjob`i'_w"+strofreal(Wave) if Status2==1 | Status2==2
replace Source_Variable2="nxtstelse`i'_w"+strofreal(Wave) if inrange(Status2,3,97)
replace Source_Variable2="nxtst`i'_w"+strofreal(Wave) if Status2==100 | Status2==101

gen Source_Variable_F2=""																// ADDITIONAL CODE.
replace Source_Variable_F2="nxtjob`i'_w"+strofreal(Wave) if /*
	*/ (!inlist(ff_jbstat,12,13) | inlist(Furl_Change_F1,2,3,4,6,8)) & /*
	*/ (Status_F2==1 | Status_F2==2)
replace Source_Variable_F2="nxtstelse`i'_w"+strofreal(Wave) if /*
	*/ (!inlist(ff_jbstat,12,13) | inlist(Furl_Change_F1,2,3,4,6,8)) & /*
	*/ inrange(Status_F2,3,97)
replace Source_Variable_F2="nxtst`i'_w"+strofreal(Wave) if /*
	*/ (!inlist(ff_jbstat,12,13) | inlist(Furl_Change_F1,2,3,4,6,8)) & /*
	*/ (Status_F2==100 | Status_F2==101)
replace Source_Variable_F2="nxtjbes_w"+strofreal(Wave) if /*
	*/ Furl_Change_F1==1 & inlist(nxtjbes,1,2)
replace Source_Variable_F2="nxtstelse_w"+strofreal(Wave) /*
	*/ if Furl_Change_F1==1 & inrange(Status_F2,3,97)
replace Source_Variable_F2="nxtst_w"+strofreal(Wave) /*
	*/ if Furl_Change_F1==1 & Status_F2==100 & nxtst==1
replace Source_Variable_F2="jbsamr_w"+strofreal(Wave) /*
	*/ if Furl_Change_F1==1 & Status_F2==100 & jbsamr==2
replace Source_Variable_F2="samejob_w"+strofreal(Wave) /*
	*/ if Furl_Change_F1==1 & Status_F2==100 & samejob==2


/*
Spell 2 End Indicator
*/
				gen End_Ind_orig2=.m if Has_Activity_orig2==1						// LW ORIGINAL CODE, THOUGH VARIABLE RENAMED WITH SUFFIX _orig.
				replace End_Ind_orig2=0 if Has_Activity_orig2==1 & (currstat1==2 | currjob1==1)
				replace End_Ind_orig2=1 if Has_Activity_orig2==1 & (currstat1==1 | currjob1==2)

gen End_Ind2=.m if Has_Activity2==1
replace End_Ind2=0 if Has_Activity2==1 & (currstat1==2 | currjob1==1)
replace End_Ind2=1 if Has_Activity2==1 & (currstat1==1 | currjob1==2)

gen End_Ind_F2=.m if Has_Activity_F2==1												// ADDITIONAL CODE.
replace End_Ind_F2=0 if Has_Activity_F2==1 & (currstat1==2 | currjob1==1) & /*
	*/ (!inlist(ff_jbstat,12,13) | inlist(Furl_Change_F1,2,3,4,5,6,7,8))
replace End_Ind_F2=1 if Has_Activity_F2==1 & (currstat1==1 | currjob1==2) & /*
	*/ (!inlist(ff_jbstat,12,13) | inlist(Furl_Change_F1,2,3,4,5,6,7,8))
replace End_Ind_F2=0 if (cstat==2 | cjob==1) & Furl_Change_F1==1 & End_Ind_F1==1
replace End_Ind_F2=1 if (cstat==1 | cjob==2) & Furl_Change_F1==1 & End_Ind_F1==1
/*
// NOTES TO Spell 2 End Indicator 
browse if Furl_Change_F1==1
sort empstendm jbendm
- Spell 0 is furlough. The statement nxtst==1 is interpreted as "furlough ends". Most (50/63) Furl_Change_F1==1 state empstendd/m/y4, which is interpreted as furlough end date; 2 just state empstendy4; for the remaining 11, empstendd/m/y4 is missing. In 5 cases, the Spell 1 job, that continues after furlough, ends at jbendd/m/y4, and Spell 2 starts. In 4 of these cases, cjob==1: Spell 2 does not end before the next interview. In 1 of these cases, cjob==2, indicating that the Spell 2 job ends at nxtjbendd/m/y4 (and Status 2 employment status is given by nxtjbes and nxtjbhrs).
- Apparently inconsistently (though noting the wkplsam value), there are 2 other cases where cjob==2 and jbsamr==1 and samejob==1 - and wkplsam==2 - which leads to a path through the questionnaire that results in missing (inapplicable) jbendd/m/y4 whereas nxtendd/m/y4 are present. It is assumed in these 2 cases that nxtjbendd/m/y4 dates relate to the end of Spell 1 (the previously-furloughed job, which dates indicate continued after furlough ended). This assumption prevents a gap in spell data that would arise if (as is assumed if jbsamr==2 or samejob==2 leading to jbendd/m/y4 being present) nxtjbendd/m/y4 dates for these 2 cases were taken to relate to the end of Spell 2. These 2 rogue cases are identified by Furl_Change_F1==8. For these cases, HasActivity_F2==1, but End_Ind_F2=.m due to lack of currjob1/currstat1 and beyond data.
*/


/*
Spell 2 Job Change
*/
				gen Job_Change_orig2=.i if Has_Activity_orig2==1					// LW ORIGINAL CODE, THOUGH VARIABLE RENAMED WITH SUFFIX _orig.
				replace Job_Change_orig2=.m if nextjob1==.m
				replace Job_Change_orig2=1 if nextjob1==4
				replace Job_Change_orig2=2 if nextjob1==1
				replace Job_Change_orig2=3 if nextjob1==2
				replace Job_Change_orig2=3 /*
					*/ if (!inlist(Status_orig1,1,2,100) & nextstat1==1 & nextjob1!=4) /*
					*/ | nextjob1==3

gen Job_Change2=.i if Has_Activity2==1
replace Job_Change2=.m if nextjob1==.m
replace Job_Change2=1 if nextjob1==4
replace Job_Change2=2 if nextjob1==1
replace Job_Change2=3 if nextjob1==2
replace Job_Change2=3 /*
	*/ if (!inlist(Status1,1,2,100) & nextstat1==1 & nextjob1!=4) /*
	*/ | nextjob1==3

gen Job_Change_F2=.i if Has_Activity_F2==1											// ADDITIONAL CODE.
replace Job_Change_orig2=.m if nextjob1==.m & /*
	*/ (!inlist(ff_jbstat,12,13) | inlist(Furl_Change_F1,2,3,4,6,7,8))											// SEE NOTES 1., 2., 3. AND 4.
replace Job_Change_F2=1 if nextjob1==4 & /*
	*/ (!inlist(ff_jbstat,12,13) | inlist(Furl_Change_F1,2,3,4,6,7,8))
replace Job_Change_F2=2 if nextjob1==1 & /*
	*/ (!inlist(ff_jbstat,12,13) | inlist(Furl_Change_F1,2,3,4,6,8))
replace Job_Change_F2=3 if nextjob1==2 & /*
	*/ (!inlist(ff_jbstat,12,13) | inlist(Furl_Change_F1,2,3,4,6,8))
replace Job_Change_F2=3 /*
	*/ if (!inlist(Status_F1,2,12,13,100,112,113,212,213) & nextstat1==1 & nextjob1!=4) /*
	*/ | nextjob1==3
replace Job_Change_F2=2 if Furl_Change_F1==1 & samejob==2 & inlist(Status_F1,1,2,12,13,100,112,113,212,213)
replace Job_Change_F2=3 if Furl_Change_F1==1 & jbsamr==2 & inlist(Status_F1,1,2,12,13,100,112,113,212,213)		// SEE NOTE 5.
/* 
// NOTES TO Job_Change_F2:
1. Possible Job_Change2 based on nextjob1 if inlist(Furl_Change_F1,2,3,4,6,8).
2. There should be no job change this wave if Furl_Change==7 since empchk==1 (MEMO: empchk==1 also for Furl_Change_F1==0, but jbstat=furlough).
3. No job change this wave if Furl_Change_F1==0: still furloughed.
4. No job change this wave if Furl_Change_F1==5: The furlough spell held at the time of the last interview ends, same job, is current job, jbstat indicates still furloughed.
5. Possible Job_Change2 based on jbsamr,samejob if Furl_Change_F1==1. Generally, Furl_Change_F1==1 cases use code relating to previous _orig spell. But "replace Job_Change_F2=3 if Furl_Change_F1==1 & nxtst==1" cannot be used because nxtst==1 when furlough ends to an employment status but for those coming off furlough this does not imply a change to a new job.
*/


/*
Spell 2 End Date
*/
				gen End_D_orig2=statendd1 if End_Ind_orig2==1						// LW ORIGINAL CODE, THOUGH VARIABLE RENAMED WITH SUFFIX _orig.
				gen End_M_orig2=statendm1 if End_Ind_orig2==1
				gen End_Y_orig2=statendy41 if End_Ind_orig2==1

gen End_D2=statendd1 if End_Ind2==1
gen End_M2=statendm1 if End_Ind2==1
gen End_Y2=statendy41 if End_Ind2==1

gen End_D_F2=statendd1 if End_Ind_F2==1 & (!inlist(ff_jbstat,12,13) | inlist(Furl_Change_F1,2,3,4,6,8))	// ADDITIONAL CODE.
replace End_D_F2=nxtjbendd if End_Ind_F2==1 & Furl_Change_F1==1
gen End_M_F2=statendm1 if End_Ind_F2==1 & (!inlist(ff_jbstat,12,13) | inlist(Furl_Change_F1,2,3,4,6,8))
replace End_M_F2=nxtjbendm if End_Ind_F2==1 & Furl_Change_F1==1
gen End_Y_F2=statendy41 if End_Ind_F2==1 & (!inlist(ff_jbstat,12,13) | inlist(Furl_Change_F1,2,3,4,6,8))
replace End_Y_F2=nxtjbendy4 if End_Ind_F2==1 & Furl_Change_F1==1



	*Spells 3+*

/*
Spell 3+ Exists?
and
Spell 3+ End Indicators
*/
ds nextstat*																		// MODIFIED CODE.
local spells: word count `r(varlist)'
forval i=2/`spells'{
	local j=`i'+1
	local k=`i'-1

				gen Has_Activity_orig`j'=1 if End_Ind_orig`i'==1					// LW ORIGINAL CODE, THOUGH VARIABLE RENAMED WITH SUFFIX _orig.

	gen Has_Activity`j'=1 if End_Ind`i'==1

	gen Has_Activity_F`j'=1 if End_Ind_F`i'==1										// ADDITIONAL CODE.
		
				gen End_Ind_orig`j'=.m if Has_Activity_orig`j'==1					// LW ORIGINAL CODE, THOUGH VARIABLE RENAMED WITH SUFFIX _orig.
				replace End_Ind_orig`j'=0 if Has_Activity_orig`j'==1 & (currstat`i'==2 | currjob`i'==1)
				replace End_Ind_orig`j'=1 if Has_Activity_orig`j'==1 & (currstat`i'==1 | currjob`i'==2)				

	gen End_Ind`j'=.m if Has_Activity`j'==1
	replace End_Ind`j'=0 if Has_Activity`j'==1 & (currstat`i'==2 | currjob`i'==1)
	replace End_Ind`j'=1 if Has_Activity`j'==1 & (currstat`i'==1 | currjob`i'==2)				

	gen End_Ind_F`j'=.m if Has_Activity_F`j'==1										// ADDITIONAL CODE.
	replace End_Ind_F`j'=0 if Has_Activity_F`j'==1 & (currstat`i'==2 | currjob`i'==1) & /*
		*/ (!inlist(ff_jbstat,12,13) | inlist(Furl_Change_F1,2,3,4,6,7,8))						// SEE NOTES 1., 2., 3. AND 4.
	replace End_Ind_F`j'=1 if Has_Activity_F`j'==1 & (currstat`i'==1 | currjob`i'==2) & /*
		*/ (!inlist(ff_jbstat,12,13) | inlist(Furl_Change_F1,2,3,4,6,7,8))
	replace End_Ind_F`j'=0 if Has_Activity_F`j'==1 & (currstat`k'==2 | currjob`k'==1) & /*
		*/ Furl_Change_F1==1																	// SEE NOTE 5.
	replace End_Ind_F`j'=1 if Has_Activity_F`j'==1 & (currstat`k'==1 | currjob`k'==2) & /*
		*/ Furl_Change_F1==1
	}
/*
// NOTES TO End_Ind_F*:
1. inlist(Furl_Change_F1,2,3,4,6) implies spell 1 involves furlough end at empstend* and possibly a new employment/non-employment spell which might end at jbend*.
2. Furl_Change_F1==5: between initial and subsequent waves there is no change in job but an end of furlough spell and the next wave status is furlough, indicating a second furlough spell in the same job. Thus no Spell 3+ End Indicator is relevant.
3. Furl_Change_F1==7: No info on furlough end, same job, next wave status not furlough. There is no information for these cases on subsequent within-wave spells. In practice, no Spell 3+ End Indicator will be calculated, but these cases are included in principle.
4. Job continues post-furlough for Furl_Change_F1==8 cases, but due to their answers and route through the questionnaire, the variables relating to their spells are the same as inlist(Furl_Change_F1,2,3,4,6).
5. Furl_Change_F1==1 cases effectively have an extra spell due to furlough (Spell 0) and continuation of same job post-furlough (Spell 1) being treated as 2 separate spells in _F variables.
*/


/* 
Spell 3+ Status
*/
ds nextstat*																		// MODIFIED CODE.
local spells: word count `r(varlist)'
forval i=2/`spells'{
	local j=`i'+1
	local k=`i'-1
	
				gen Status_orig`j'=.m if Has_Activity_orig`j'==1					// LW ORIGINAL CODE, THOUGH VARIABLE RENAMED WITH SUFFIX _orig.
				replace Status_orig`j'=1 if nextjob`i'==3
				replace Status_orig`j'=2 if inlist(nextjob`i',1,2,4)
				replace Status_orig`j'=nextelse`i'+2 if inrange(nextelse`i',1,7)
				replace Status_orig`j'=97 if nextelse`i'==8
				replace Status_orig`j'=100 if nextstat`i'==1 & missing(nextjob`i')
				replace Status_orig`j'=101 if nextstat`i'==2 & missing(nextelse`i')
				
	gen Status`j'=.m if Has_Activity`j'==1
	replace Status`j'=1 if nextjob`i'==3
	replace Status`j'=2 if inlist(nextjob`i',1,2,4)
	replace Status`j'=nextelse`i'+2 if inrange(nextelse`i',1,7)
	replace Status`j'=97 if nextelse`i'==8
	replace Status`j'=100 if nextstat`i'==1 & missing(nextjob`i')
	replace Status`j'=101 if nextstat`i'==2 & missing(nextelse`i')
	
	gen Status_F`j'=.m if Has_Activity_F`j'==1										// ADDITIONAL CODE.
	replace Status_F`j'=1 if nextjob`i'==3 & /*
		*/ (!inlist(ff_jbstat,12,13) | inlist(Furl_Change_F1,2,3,4,6,7,8))					// SEE NOTES 1. 2. AND 3.
	replace Status_F`j'=2 if inlist(nextjob`i',1,2,4) & /*
		*/ (!inlist(ff_jbstat,12,13) | inlist(Furl_Change_F1,2,3,4,6,7,8))
	replace Status_F`j'=nextelse`i'+2 if inrange(nextelse`i',1,7) & /*
		*/ (!inlist(ff_jbstat,12,13) | inlist(Furl_Change_F1,2,3,4,6,7,8))
	replace Status_F`j'=97 if nextelse`i'==8 & /*
		*/ (!inlist(ff_jbstat,12,13) | inlist(Furl_Change_F1,2,3,4,6,7,8))
	replace Status_F`j'=100 if nextstat`i'==1 & missing(nextjob`i') & /*
		*/ (!inlist(ff_jbstat,12,13) | inlist(Furl_Change_F1,2,3,4,6,7,8))
	replace Status_F`j'=101 if nextstat`i'==2 & missing(nextelse`i') & /*
		*/ (!inlist(ff_jbstat,12,13) | inlist(Furl_Change_F1,2,3,4,6,7,8))
	replace Status_F`j'=1 if nextjob`i'==3 & /*
		*/ Furl_Change_F1==1																// SEE NOTE 4.
	replace Status_F`j'=2 if inlist(nextjob`k',1,2,4) & /*
		*/ Furl_Change_F1==1
	replace Status_F`j'=nextelse`k'+2 if inrange(nextelse`k',1,7) & /*
		*/ Furl_Change_F1==1
	replace Status_F`j'=97 if nextelse`k'==8 & /*
		*/ Furl_Change_F1==1
	replace Status_F`j'=100 if nextstat`k'==1 & missing(nextjob`k') & /*
		*/ Furl_Change_F1==1
	replace Status_F`j'=101 if nextstat`k'==2 & missing(nextelse`k') & /*
		*/ Furl_Change_F1==1
	}
/*
// NOTES TO Status_F*:
1. inlist(Furl_Change_F1,2,3,4,6) implies spell 1 involves furlough end and possibly a new employment/non-employment spell. These cases can be treated the same as those where Index Spell Status/Status0/ff_jbstat is not furlough.
2. Furl_Change_F1==7: No info on furlough end, same job, next wave status not furlough. There is no information for these cases on subsequent within-wave spells. In practice, no Spell 3+ Status will be calculated, but these cases are included in principle.
3. Job continues post-furlough for Furl_Change_F1==8 cases, but due to their answers and route through the questionnaire, the variables relating to their spells are the same as inlist(Furl_Change_F1,2,3,4,6).
4. Furl_Change_F1==1 cases effectively have an extra spell due to furlough (Spell 0) and continuation of same job post-furlough (Spell 1) being treated as 2 separate spells in _F variables.
Furl_Change_F1==5: between initial and subsequent waves there is no change in job but an end of furlough spell and the next wave status is furlough, indicating a second furlough spell in the same job. Thus there is no Status 3+.
*/
	

/*
Spell 3+ * Status Source Variable
*/
ds nextstat*																		// MODIFIED CODE.
local spells: word count `r(varlist)'
forval i=2/`spells'{
	local j=`i'+1
	local k=`i'-1

				gen Source_Variable_orig`j'=""										// LW ORIGINAL CODE, THOUGH VARIABLE RENAMED WITH SUFFIX _orig.
				replace Source_Variable_orig`j'="nxtjob`i'_w"+strofreal(Wave) if Status_orig`j'==1 | Status_orig`j'==2
				replace Source_Variable_orig`j'="nxtstelse`i'_w"+strofreal(Wave) if inrange(Status_orig`j',3,97)
				replace Source_Variable_orig`j'="nxtst`i'_w"+strofreal(Wave) if Status_orig`j'==100 | Status_orig`j'==101	
				
	gen Source_Variable`j'=""
	replace Source_Variable`j'="nxtjob`i'_w"+strofreal(Wave) if Status`j'==1 | Status`j'==2
	replace Source_Variable`j'="nxtstelse`i'_w"+strofreal(Wave) if inrange(Status`j',3,97)
	replace Source_Variable`j'="nxtst`i'_w"+strofreal(Wave) if Status`j'==100 | Status`j'==101	
	
	gen Source_Variable_F`j'=""														// ADDITIONAL CODE.
	replace Source_Variable_F`j'="nxtjob`i'_w"+strofreal(Wave) if (Status_F`j'==1 | Status_F`j'==2) & /*
		*/ (!inlist(ff_jbstat,12,13) | inlist(Furl_Change_F1,2,3,4,6,7,8))
	replace Source_Variable_F`j'="nxtstelse`i'_w"+strofreal(Wave) if inrange(Status_F`j',3,97) & /*
		*/ (!inlist(ff_jbstat,12,13) | inlist(Furl_Change_F1,2,3,4,6,7,8))
	replace Source_Variable_F`j'="nxtst`i'_w"+strofreal(Wave) if (Status_F`j'==100 | Status_F`j'==101) & /*
		*/ (!inlist(ff_jbstat,12,13) | inlist(Furl_Change_F1,2,3,4,6,7,8))				
	replace Source_Variable_F`j'="nxtjob`k'_w"+strofreal(Wave) if (Status_F`j'==1 | Status_F`j'==2) & /*
		*/ Furl_Change_F1==1
	replace Source_Variable_F`j'="nxtstelse`k'_w"+strofreal(Wave) if inrange(Status_F`j',3,97) & /*
		*/ Furl_Change_F1==1
	replace Source_Variable_F`j'="nxtst`k'_w"+strofreal(Wave) if (Status_F`j'==100 | Status_F`j'==101) & /*
		*/ Furl_Change_F1==1	
	}
	
	
/*
Spell 3+ Job Change
*/
ds nextstat*																		// MODIFIED CODE.
local spells: word count `r(varlist)'
forval i=2/`spells'{
	local j=`i'+1
	local k=`i'-1
	
				gen Job_Change_orig`j'=.i if Has_Activity_orig`j'==1				// LW ORIGINAL CODE, THOUGH VARIABLE RENAMED WITH SUFFIX _orig.
				replace Job_Change_orig`j'=.m if nextjob`i'==.m
				replace Job_Change_orig`j'=1 if nextjob`i'==4
				replace Job_Change_orig`j'=2 if nextjob`i'==1
				replace Job_Change_orig`j'=3 if nextjob`i'==2
				replace Job_Change_orig`j'=3 /*
					*/ if (!inlist(Status_orig`i',1,2,100) & nextstat`i'==1 & nextjob`i'!=4) /*
					*/ | nextjob`i'==3

	gen Job_Change`j'=.i if Has_Activity`j'==1
	replace Job_Change`j'=.m if nextjob`i'==.m
	replace Job_Change`j'=1 if nextjob`i'==4
	replace Job_Change`j'=2 if nextjob`i'==1
	replace Job_Change`j'=3 if nextjob`i'==2
	replace Job_Change`j'=3 /*
		*/ if (!inlist(Status`i',1,2,100) & nextstat`i'==1 & nextjob`i'!=4) /*
		*/ | nextjob`i'==3

	gen Job_Change_F`j'=.i if Has_Activity_F`j'==1									// ADDITIONAL CODE.
	replace Job_Change_F`j'=.m if nextjob`i'==.m & /*						
		*/ (!inlist(ff_jbstat,12,13) | inlist(Furl_Change_F1,2,3,4,6,7,8))								// SEE NOTES 1., 2. AND 3.
	replace Job_Change_F`j'=1 if nextjob`i'==4 & /*
		*/ (!inlist(ff_jbstat,12,13) | inlist(Furl_Change_F1,2,3,4,6,7,8))
	replace Job_Change_F`j'=2 if nextjob`i'==1 & /*
		*/  (!inlist(ff_jbstat,12,13) | inlist(Furl_Change_F1,2,3,4,6,7,8))
	replace Job_Change_F`j'=3 if nextjob`i'==2 /*
		*/  & (!inlist(ff_jbstat,12,13) | inlist(Furl_Change_F1,2,3,4,6,7,8))
	replace Job_Change_F`j'=3 /*
		*/ if ((!inlist(Status_F`i',1,2,100) & nextstat`i'==1 & nextjob`i'!=4) /*
		*/ | nextjob`i'==3) & /*
		*/  (!inlist(ff_jbstat,12,13) | inlist(Furl_Change_F1,2,3,4,6,7,8))
	replace Job_Change_F`j'=.m if nextjob`k'==.m & /*
		*/ Furl_Change_F1==1																			// SEE NOTE 4.
	replace Job_Change_F`j'=1 if nextjob`k'==4 & /*
		*/  Furl_Change_F1==1
	replace Job_Change_F`j'=2 if nextjob`k'==1 & /*
		*/  Furl_Change_F1==1
	replace Job_Change_F`j'=3 if nextjob`k'==2 & /*
		*/ Furl_Change_F1==1
	replace Job_Change_F`j'=3 if ((!inlist(Status_F`k',1,2,100) & nextstat`k'==1 & nextjob`k'!=4) /*
		*/ | nextjob`k'==3) & /*
		*/ Furl_Change_F1==1																			// SEE NOTE 5.
	}
/*
// NOTES TO Job_Change_F*:
1. inlist(Furl_Change_F1,2,3,4,6) implies spell 1 involves furlough end and possibly a new employment/non-employment spell. These cases can be treated the same as those where Index Spell Status/Status0/ff_jbstat is not furlough.
2. Furl_Change_F1==7: No info on furlough end, same job, next wave status not furlough. There is no information for these cases on subsequent within-wave spells. In practice, no Spell 3+ End Indicator will be calculated, but these cases are included in principle.
3. Job continues post-furlough for Furl_Change_F1==8 cases, but due to their answers and route through the questionnaire, the variables relating to their spells are the same as inlist(Furl_Change_F1,2,3,4,6).
4. Furl_Change_F1==1 cases effectively have an extra spell due to furlough (Spell 0) and continuation of same job post-furlough (Spell 1) being treated as 2 separate spells in _F variables. 
5. Note that there are no within-wave furlough spells recorded, so there is no need/relevance for status values other than 1,2,100.
*/


/*
Spell 3+ Dates
*/		
ds nextstat*																		// MODIFIED CODE.
local spells: word count `r(varlist)'
forval i=2/`spells'{
	local j=`i'+1
	local k=`i'-1
	
			gen End_D_orig`j'=statendd`i' if End_Ind_orig`j'==1						// LW ORIGINAL CODE, THOUGH VARIABLE RENAMED WITH SUFFIX _orig.
			gen End_M_orig`j'=statendm`i' if End_Ind_orig`j'==1
			gen End_Y_orig`j'=statendy4`i' if End_Ind_orig`j'==1
			
	gen End_D`j'=statendd`i' if End_Ind`j'==1
	gen End_M`j'=statendm`i' if End_Ind`j'==1
	gen End_Y`j'=statendy4`i' if End_Ind`j'==1
	
	gen End_D_F`j'=statendd`i' if End_Ind_F`j'==1 & (!inlist(ff_jbstat,12,13) | inlist(Furl_Change_F1,2,3,4,6,7,8))	// SEE NOTES 1., 2. AND 3. ADDITIONAL CODE.
	gen End_M_F`j'=statendm`i' if End_Ind_F`j'==1 & (!inlist(ff_jbstat,12,13) | inlist(Furl_Change_F1,2,3,4,6,7,8))
	gen End_Y_F`j'=statendy4`i' if End_Ind_F`j'==1 & (!inlist(ff_jbstat,12,13) | inlist(Furl_Change_F1,2,3,4,6,7,8))
	replace End_D_F`j'=statendd`k' if End_Ind_F`j'==1 & Furl_Change_F1==1												// SEE NOTE 4.
	replace End_M_F`j'=statendm`k' if End_Ind_F`j'==1 & Furl_Change_F1==1
	replace End_Y_F`j'=statendy4`k' if End_Ind_F`j'==1 & Furl_Change_F1==1
	}
// NOTES TO Spell 3+ EndD/M/Y _F Dates:
/*
1. inlist(Furl_Change_F1,2,3,4,6) implies spell 1 involves furlough end and possibly a new employment/non-employment spell. These cases can be treated the same as those where Index Spell Status/Status0/ff_jbstat is not furlough.
2. Furl_Change_F1==7: No info on furlough end, same job, next wave status not furlough. There is no information for these cases on subsequent within-wave spells. In practice, no Spell 3+ end dates will be calculated, but these cases are included in principle.
3. Job continues post-furlough for Furl_Change_F1==8 cases, but due to their answers and route through the questionnaire, the variables relating to their spells are the same as inlist(Furl_Change_F1,2,3,4,6).
4. Furl_Change_F1==1 cases effectively have an extra spell due to furlough and continuation of same job post-furlough being treated as 2 separate spells in _F variables. 
*/
/* FOR INFO: To check dates: 
sort ff_jbstat Furl_Change_F1
order pidp Wave ff_jbstat jbstat Status_orig0 Status_F0 Status_orig1 Status_F1 Status_orig2 Status_F2 Status_orig3 Status_F3 Furl_Change_F1 Job_Change_orig1 Job_Change_F1 Job_Change_orig2 Job_Change_F2 Job_Change_orig3 Job_Change_F3 End_Ind_orig0 End_Ind_F0 End_Ind_orig1 End_Ind_F1 End_Ind_orig2 End_Ind_F2 End_Ind_orig3 End_Ind_F2 End_M_orig0 End_Y_orig0 End_M_F0 End_Y_F0 End_M_orig1 End_Y_orig1 End_M_F1 End_Y_F1 End_M_orig2 End_Y_orig2 End_M_F2 End_Y_F2 End_M_orig3 End_Y_orig3 End_M_F3 End_Y_F3 jbsamr samejob empstendm empstendy4 jbendm jbendy4 cjob nxtjbes nxtjbhrs nxtjbendm nxtjbendy4 nxtst nxtstelse cstat nxtstendm nxtstendy4 nextstat1 nextjob1 currjob1 nextelse1 currstat1
browse pidp Wave ff_jbstat jbstat Status_orig0 Status_F0 Status_orig1 Status_F1 Status_orig2 Status_F2 Status_orig3 Status_F3 Furl_Change_F1 Job_Change_orig1 Job_Change_F1 Job_Change_orig2 Job_Change_F2 Job_Change_orig3 Job_Change_F3 End_Ind_orig0 End_Ind_F0 End_Ind_orig1 End_Ind_F1 End_Ind_orig2 End_Ind_F2 End_Ind_orig3 End_Ind_F3 End_M_orig0 End_Y_orig0 End_M_F0 End_Y_F0 End_M_orig1 End_Y_orig1 End_M_F1 End_Y_F1 End_M_orig2 End_Y_orig2 End_M_F2 End_Y_F2 End_M_orig3 End_Y_orig3 End_M_F3 End_Y_F3 jbsamr samejob empstendm empstendy4 jbendm jbendy4 cjob nxtjbes nxtjbhrs nxtjbendm nxtjbendy4 nxtst nxtstelse cstat nxtstendm nxtstendy4 nextstat1 nextjob1 currjob1 nextelse1 currstat1 if inlist(ff_jbstat,12,13)
*/


/*
Job Hours FT/PT
*/	
*Index Spell Job Hours
			gen Job_Hours_orig0=Prev_Job_Hours if notempchk==.i & /*				// LW ORIGINAL CODE, THOUGH VARIABLE RENAMED WITH SUFFIX _orig.
				*/ (End_Ind_orig0==.m | (End_Ind0==0 & missing(jbft_dv)) | End_Ind_orig0==1) /*
				*/ & inlist(AnnualHistory_Routing,1,2)
			replace Job_Hours_orig0=jbft_dv if notempchk==.i & End_Ind_orig0==0 & !missing(jbft_dv) /*
				*/ & inlist(AnnualHistory_Routing,1,2)
			replace Job_Hours_orig0=. if missing(Job_Hours_orig0)

gen Job_Hours0=Prev_Job_Hours if notempchk==.i & /*
	*/ (End_Ind0==.m | (End_Ind0==0 & missing(jbft_dv)) | End_Ind0==1) /*
	*/ & inlist(AnnualHistory_Routing,1,2)
replace Job_Hours0=jbft_dv if notempchk==.i & End_Ind0==0 & !missing(jbft_dv) /*
	*/ & inlist(AnnualHistory_Routing,1,2)
replace Job_Hours0=. if missing(Job_Hours0)

gen Job_Hours_F0=Prev_Job_Hours if notempchk==.i & /*
	*/ (End_Ind_F0==.m | (End_Ind_F0==0 & missing(jbft_dv)) | End_Ind_F0==1) /*
	*/ & inlist(AnnualHistory_Routing,1,2)
replace Job_Hours_F0=jbft_dv if notempchk==.i & /*
	*/ End_Ind_F0==0 & !missing(jbft_dv) /*
	*/ & inlist(AnnualHistory_Routing,1,2)
replace Job_Hours_F0=. if missing(Job_Hours_F0)			
			
*Spell 1 Job Hours
			gen Job_Hours_orig1=nxtjbhrs if cjob==2 & (inlist(AnnualHistory_Routing,1,2) | (nxtst==1 & AnnualHistory_Routing==3))	// LW ORIGINAL CODE, THOUGH VARIABLE RENAMED WITH SUFFIX _orig.
			replace Job_Hours_orig1=jbft_dv if cjob==1 & (inlist(AnnualHistory_Routing,1,2) | (nxtst==1 & AnnualHistory_Routing==3))
			replace Job_Hours_orig1=. if missing(Job_Hours_orig1)
	
gen Job_Hours1=nxtjbhrs if cjob==2 & (inlist(AnnualHistory_Routing,1,2) | (nxtst==1 & AnnualHistory_Routing==3))
replace Job_Hours1=jbft_dv if cjob==1 & (inlist(AnnualHistory_Routing,1,2) | (nxtst==1 & AnnualHistory_Routing==3))
replace Job_Hours1=. if missing(Job_Hours1)

gen Job_Hours_F1=nxtjbhrs if cjob==2 & /*											// ADDITIONAL CODE.
	*/ (((!inlist(ff_jbstat,12,13) | inlist(Furl_Change_F1,2,3,4,6,7,8)) & inlist(AnnualHistory_Routing,1,2)) | /*
	*/ (nxtst==1 & AnnualHistory_Routing==3))												// SEE NOTES 1., 2., 3. AND 4. 
replace Job_Hours_F1=jbft_dv if cjob==1 & /*
	*/ (((!inlist(ff_jbstat,12,13) | inlist(Furl_Change_F1,2,3,4,6,7,8)) & inlist(AnnualHistory_Routing,1,2)) | /*
	*/ (nxtst==1 & AnnualHistory_Routing==3))
replace Job_Hours_F1=Prev_Job_Hours if notempchk==.i & /*
	*/ (End_Ind_F0==.m | (End_Ind_F0==0 & missing(jbft_dv)) | End_Ind_F0==1) & /*
	*/ inlist(Furl_Change_F1,1,5)																	// SEE NOTES 5. AND 6.
replace Job_Hours_F1=jbft_dv if notempchk==.i & End_Ind_F0==0 & !missing(jbft_dv) & /*
	*/ inlist(Furl_Change_F1,1,5)
replace Job_Hours_F1=. if missing(Job_Hours_F1)

*Spell 2 Job Hours
				gen Job_Hours_orig2=jobhours1 if currjob1==2						// LW ORIGINAL CODE, THOUGH VARIABLE RENAMED WITH SUFFIX _orig.
				replace Job_Hours_orig2=jbft_dv if currjob1==1
				replace Job_Hours_orig2=. if missing(Job_Hours_orig2)

gen Job_Hours2=jobhours1 if currjob1==2	
replace Job_Hours2=jbft_dv if currjob1==1
replace Job_Hours2=. if missing(Job_Hours2)

gen Job_Hours_F2=jobhours1 if currjob1==2 & /*										// ADDITIONAL CODE.
	*/ (!inlist(ff_jbstat,12,13) | inlist(Furl_Change_F1,2,3,4,6,7,8))
replace Job_Hours_F2=jbft_dv if currjob1==1 & /*
	*/ (!inlist(ff_jbstat,12,13) | inlist(Furl_Change_F1,2,3,4,6,7,8))
replace Job_Hours_F2=nxtjbhrs if cjob==2 & /*
	*/ Furl_Change_F1==1 & Has_Activity_F2==1		 										// SEE NOTE 7.
replace Job_Hours_F2=jbft_dv if cjob==1 & /*
	*/ Furl_Change_F1==1 & Has_Activity_F2==1
replace Job_Hours_F2=. if missing(Job_Hours_F2)

*Spells 3+ Job Hours
ds nextstat*																		// MODIFIED CODE.
local spells: word count `r(varlist)'
forval i=2/`spells'{
	local j=`i'+1
	local k=`i'-1
	
				gen Job_Hours_orig`j'=jobhours`i' if currjob`i'==2					// LW ORIGINAL CODE, THOUGH VARIABLE RENAMED WITH SUFFIX _orig.
				replace Job_Hours_orig`j'=jbft_dv if currjob`i'==1
				replace Job_Hours_orig`j'=. if missing(Job_Hours_orig`j')
				
	gen Job_Hours`j'=jobhours`i' if currjob`i'==2
	replace Job_Hours`j'=jbft_dv if currjob`i'==1
	replace Job_Hours`j'=. if missing(Job_Hours`j')
	
	gen Job_Hours_F`j'=jobhours`i' if currjob`i'==2 & /*							// ADDITIONAL CODE.
		*/ (!inlist(ff_jbstat,12,13) | inlist(Furl_Change_F1,2,3,4,6,7,8))
	replace Job_Hours_F`j'=jbft_dv if currjob`i'==1 & /*
		*/ (!inlist(ff_jbstat,12,13) | inlist(Furl_Change_F1,2,3,4,6,7,8))
	replace Job_Hours_F`j'=jobhours`k' if currjob`k'==2 & /*
			*/ Furl_Change_F1==1 & Has_Activity_F`j'==1										// SEE NOTE 8. 		
		replace Job_Hours_F`j'=jbft_dv if currjob`k'==1 & /*
		*/ Furl_Change_F1==1 & Has_Activity_F`j'==1
	replace Job_Hours_F`j'=. if missing(Job_Hours_F`j')
	}
/*
// NOTES TO Job_Hours_F*:
1. inlist(Furl_Change_F1,2,3,4) implies spell 1 follows furlough end and possibly involves a new job, so these cases are treated the same as cases with non-furlough Index Status/Status0/ff_jbstat !inlist(ff_jbstat,12,13).
2. Furl_Change_F1==6 cases are excluded from Job_Hours_F1 because Spell 1 status is non-employment, but these cases might have employment Spells 2 onwards so they should be included alongside inlist(Furl_Change_F1,2,3,4) cases from Spell 2 onwards.
3. For Furl_Change_F1==7, the data indicates "same job", but there is no information on furlough end date. The next wave status is not furlough. These cases are treated the same as inlist(Furl_Change_F1,2,3,4,6), where furlough did not end before job end. 
4. Job continues post-furlough for Furl_Change_F1==8 cases, but due to their answers and route through the questionnaire, the variables relating to their spells are the same as inlist(Furl_Change_F1,2,3,4,6).
5. The definitions of inlist(Furl_Change_F1,1,5) imply that Status1 was the same job (as furloughed in the Index Spell 0). For these cases, spell 1 hours are the same as the furloughed job (Status0). For Furl_Change_F1==1, the individual is no longer furloughed.
6. For Furl_Change_F1==5, the next observed spell is the same job furloughed.
7. For Furl_Change_F1==1, Spell 2 might involve a different job. 
8. Furl_Change_F1==1 cases effectively have an extra spell due to furlough and continuation of same job post-furlough being treated as 2 separate spells in _F variables.
*/


/*
Job Attraction (Main attraction of current job - asked if job spell has not ended by the time of the next interview)
*/
// NOTE: Job_Attraction is collected separately in this file, rather than alongside other variables as in LW.
// HEREHEREHERE WOULD BE GOOD TO EXPLAIN (TO SELF AND/OR OTHERS) THE RATIONALE FOR THE SIMPLIFIED CODING HERE - WHY DOES THIS WORK?
*Index Spell Job Attraction
				gen Job_Attraction_orig0=.											// LW ORIGINAL CODE, THOUGH VARIABLE RENAMED WITH SUFFIX _orig.
gen Job_Attraction0=.
gen Job_Attraction_F0=.

*Spell 1 Job Attraction
				gen Job_Attraction_orig1=cjbatt if cjob==1 & (inlist(AnnualHistory_Routing,1,2) | (nxtst==1 & AnnualHistory_Routing==3))	// LW ORIGINAL CODE, THOUGH VARIABLE RENAMED WITH SUFFIX _orig.
gen Job_Attraction1=cjbatt if cjob==1 & (inlist(AnnualHistory_Routing,1,2) | (nxtst==1 & AnnualHistory_Routing==3))
gen Job_Attraction_F1=cjbatt if cjob==1 & (inlist(AnnualHistory_Routing,1,2) | (nxtst==1 & AnnualHistory_Routing==3))	// NOTE Spell 1 is current job. ADDITIONAL CODE.
				
*Spell 2 Job Attraction
				gen Job_Attraction_orig2=jbatt1 if currjob1==1						// LW ORIGINAL CODE, THOUGH VARIABLE RENAMED WITH SUFFIX _orig.
gen Job_Attraction2=jbatt1 if currjob1==1
gen Job_Attraction_F2=jbatt1 if currjob1==1
//  gen Job_Attraction_F2=jbatt1 if currjob1==1 & (!inlist(ff_jbstat,12,13) | inlist(Furl_Change_F1,2,3,4,6,8))		// SEE NOTES 1., 2. AND 3.
//  replace Job_Attraction_F2=cjbatt if cjob==1 & inlist(Furl_Change_F1,1,5,7)											// SEE NOTES 4., 5. AND 6.

*Spells 3+ Job Attraction
ds nextstat*																		// MODIFIED CODE.
local spells: word count `r(varlist)'
forval i=2/`spells'{
	local j=`i'+1
	local k=`i'-1
				gen Job_Attraction_orig`j'=jbatt`i' if currjob`i'==1				// LW ORIGINAL CODE, THOUGH VARIABLE RENAMED WITH SUFFIX _orig.
	gen Job_Attraction`j'=jbatt`i' if currjob`i'==1
	gen Job_Attraction_F`j'=jbatt`i' if currjob`i'==1
//	gen Job_Attraction_F`j'=jbatt`i' if currjob`i'==1 & (!inlist(ff_jbstat,12,13) | inlist(Furl_Change_F1,2,3,4,6,8))
//	replace Job_Attraction_F`j'=jbatt`k' if currjob`k'==1 & Furl_Change_F1==1
	}
/*
// NOTES TO Job_Attraction_F*:
HEREHEREHERE NOTES NEED MODIFICATION IF SIMPLIFIED CODING ABOVE IS RETAINED (AND OLD CODING NEEDS DELETION).
1. Care is required in the use of Job_Attraction_F*: The same Job_Attraction value is replicated across spells of furlough and same job after the end of the initial furlough spell. This is to allow researchers flexibility in whether to apply the job attraction value to the furlough spell or the post-furlough spell in the same job. inlist(Furl_Change_F1,1,5,7) indicates same job. inlist(Furl_Change_F1,2,3,4,8) indicates the possibility of a different job. See label furl_change, copied below, and see code defining Furl_Change_F1 above.
2. inlist(Furl_Change_F1,2,3,4,6) implies spell 1 involves furlough end and possibly a new employment/non-employment status, so these cases are treated the same as cases with non-furlough Index Status/Status0/ff_jbstat.
3. Job continues post-furlough for Furl_Change_F1==8 cases, but due to their answers and route through the questionnaire, the variables relating to their spells are the same as inlist(Furl_Change_F1,2,3,4,6).
4. inlist(Furl_Change_F1,1,5,7) indicates the individual reports the same job.
5. inlist(Furl_Change_F1,5,7) definitions reflect a lack of intra-wave information, so these cases are excluded from Spells 3+ Job Attraction calculation.
6. Furl_Change_F1==1 cases effectively have an extra spell due to furlough and continuation of same job post-furlough being treated as 2 separate spells in _F variables.
MEMO:
. label list furl_change
furl_change:
           0 0. Still furloughed
           1 1. Furlough ends, job continues
           2 2. Furlough & job end, same end date
           3 3. Furlough & job end, End_*0=furlough end date though job ends first
           4 4. Job end info only
           5 5. Furlough ends, followed by further furlough spell in same job
           6 6. Furlough ends to non-employment
           7 7. No info on furlough end, same job, next wave status not furlough
           8 8. Furlough ends, job continues
// browse pidp Wave Status0* Status1* Status2* cjbatt jbatt* Furl_Change_F1 Job_Change* if !missing(cjbatt) & (inlist(ff_jbstat,12,13) | inlist(jbstat,12,13))				
*/

keep pidp Has_Activity* Status* Source_Variable* End* Furl* Job* /*						// Furl* ADDED.
	*/ Wave Route3_Type

reshape long /*																			// CODE ALTERED.
	*/ Has_Activity_orig Has_Activity Has_Activity_F /*
	*/ End_Ind_orig End_Ind End_Ind_F /*
	*/ Job_Change_orig Job_Change Job_Change_F /*
	*/ End_D_orig End_M_orig End_Y_orig End_D End_M End_Y End_D_F End_M_F End_Y_F /*
	*/ Furl_Change_F /*
	*/ Status_orig Status Status_F /* 
	*/ Source_Variable_orig Source_Variable Source_Variable_F /*
	*/ Job_Hours_orig Job_Hours Job_Hours_F /*
	*/ Job_Attraction_orig Job_Attraction Job_Attraction_F /*
	*/ , i(pidp Wave) j(Spell)	
label var Spell "Spell"

keep if Has_Activity_orig==1 | Has_Activity==1 | Has_Activity_F==1   
drop Has_Activity*
replace Job_Hours_orig=.m if missing(Job_Hours_orig) & inlist(Status_orig,1,2,100)
replace Job_Hours_orig=.i if !inlist(Status_orig,1,2,100)
replace Job_Hours=.m if missing(Job_Hours) & inlist(Status_F,1,2,100)
replace Job_Hours=.i if !inlist(Status,1,2,100)
replace Job_Hours_F=.m if missing(Job_Hours_F) & inlist(Status_F,1,2,100,112,113,212,213,10012,10013)
replace Job_Hours_F=.i if !inlist(Status_F,1,2,100,112,113,212,213,10012,10013)

/* NOTE: CODE USED IN LW BUT NOT HERE.
gen XX=ym(End_Y,End_M)
gen YY=XX if Spell==1
by pidp Wave, sort: egen ZZ=max(YY)
gen AA=1 if ZZ>XX & !missing(ZZ,XX) & Spell>1 & Route3_Type==8							// MEMO: Route3_Type==8 INVOLVES NOTEMPCHK==2, EMPCHK==1
browse if AA==1
drop if AA==1	// IF IT WERE USED: (0 observations deleted)
drop XX YY ZZ AA
*/
drop Route3_Type

save "${dta_fld}/UKHLS Annual History - Collected", replace								// NOTE: THIS SAVE OCCURS EARLIER THAN IN LW ORIGINAL CODE.

do "${do_fld}/UKHLS Initial Job_JCS.do" 												// NOTE: THIS .do FILE IS RUN EARLIER THAN IN LW ORIGINAL CODE.


/*
// NOTE: THE 3 STATUS/SPELL MEASURES ARE DEALT WITH SEPARATELY FROM HERE ONWARDS.
*/

foreach X in "_orig" "" "_F" {

	prog_reopenfile "${dta_fld}/UKHLS Annual History - Collected.dta"
	drop End_D*

	if "`X'"=="_orig" {
		drop End_Ind Status Source_Variable Job_Change End_M End_Y Job_Hours Job_Attraction 
		drop *_F
		rename *_orig *
		}

	if "`X'"=="" {
		drop *_orig *_F
		}
	if "`X'"=="_F" {
		drop *_orig
		drop End_Ind Status Source_Variable Job_Change End_M End_Y Job_Hours Job_Attraction
		rename *_F *
		}
	
	merge 1:1 pidp Wave Spell using "${dta_fld}/UKHLS Annual History End Reasons", keep(match master) nogen
	recode End_Reason* (missing=.i) if End_Ind==0
	recode End_Reason* (missing=.m) /*
		*/ if (End_Ind==1 | End_Ind==.m) & inlist(Status,1,2,100)
	recode End_Reason* (*=.i) if !inlist(Status,1,2,100)

	replace Job_Attraction=.m if inlist(Status,1,2,100) & missing(Job_Attraction)
	replace Job_Attraction=.i if !inlist(Status,1,2,100)
	foreach i of numlist 1/15 97{
		gen Job_Attraction`i'=cond(Job_Attraction==.i,.i,cond(Job_Attraction==`i',1,.m))
		}
	drop Job_Attraction

	gen Source=substr(subinstr("`c(alpha)'"," ","",.),Wave-18,1)+"_indresp"

	by pidp Wave (Spell), sort: replace Spell=_n
	
	/*
	3. Clean annual history dataset
	*/
	
	if "`X'"=="_orig" {
		do "${do_fld}/Clean Dependent Annual History_JCS.do"							// ALTERED .DO FILE.
		*11. Run Common Code															// THIS CODE MOVED HERE FROM THE END OF "Clean Dependent Annual History_JCS.do".
		do "${do_fld}/Clean Work History_JCS.do"										// ALTERED .DO FILE.
	}
	if "`X'"=="_F" {
		gen F_Ind=1																		// CREATE VARIABLE TO DISTINGUISH _F VARIANT DURING DATA CLEANING.
		do "${do_fld}/Clean Dependent Annual History_JCS.do"							// BOTH FILES ALTERED TO ENSURE CORRECT TREATMENT OF FURLOUGH SPELLS IF THESE ARE CONSIDERED.
		*11. Run Common Code
		do "${do_fld}/Clean Work History_JCS.do"		
		drop F_Ind
		}
	if "`X'"=="" {
		do "${do_fld}/Clean Dependent Annual History_JCS.do"
		*11. Run Common Code
		do "${do_fld}/Clean Work History_JCS.do"										
	}
	prog_imputemissingspells


	save "${dta_fld}/UKHLS Annual History`X'", replace
	

	/*
	4. Merge with Initial Job Information
	*/
	prog_reopenfile "${dta_fld}/UKHLS Initial Job"										// OPENS "UKHLS Initial Job.dta", THE OUTPUT OF "UKHLS Initial Job_JCS.do".

	// ADDED CODE FOR UKHLS Annual History RECORDING FURLOUGH AND UNDERLYING EMPLOYMENT STATUSES.
	if "`X'"=="" {
		replace Status=1 if inlist(jbstat,12,13) & jbsemp==2							// REPLACES FURLOUGH WITH UNDERLYING STATUS.
		replace Status=2 if inlist(jbstat,12,13) & jbsemp==1
		replace Status=100 if inlist(jbstat,12,13) & missing(jbsemp)
		}
	if "`X'"=="_F" {
		replace Start_MY=tm(2020mar) if Start_MY<tm(2020mar) & inlist(Status,12,13)		// IMPUTE PLAUSIBLE FURLOUGH START AND END DATES.
		replace End_MY=tm(2021sep) if End_MY>tm(2021sep) & inlist(Status,12,13)
		replace Status=100+Status if inlist(Status,12,13) & jbsemp==2						// CODE Status AS UKHLS Annual History
		replace Status=200+Status if inlist(Status,12,13) & jbsemp==1	
		replace Status=10000+Status if inlist(Status,12,13) & missing(jbsemp)
		}
		
	append using "${dta_fld}/UKHLS Annual History`X'", gen(XX)
	by pidp Wave, sort: gen YY=_N
	drop if XX==0 & YY>1
	by pidp (Wave), sort: egen ZZ=min(Wave)
	drop if XX==0 & Wave>ZZ		// DROP IF INITIAL JOB IS AFTER UKHLS ANNUAL HISTORY.
	drop XX YY ZZ

	prog_waveoverlap			// TRUNCATES SPELLS WHICH OVERLAP WITH RESPONSES FROM A PREVIOUS WAVE
	prog_collapsespells			// COLLAPSES SIMILAR NON-EMPLOYMENT SPELLS INTO CONTINUOUS SPELL

	prog_format
	save "${dta_fld}/UKHLS Annual History`X'", replace

	}

/*
5.	Delete Unused Files
*/
rm "${dta_fld}/UKHLS Initial Job.dta" 
rm "${dta_fld}/UKHLS Annual History - Collected.dta"
rm "${dta_fld}/UKHLS Annual History - Raw.dta"
rm "${dta_fld}/UKHLS Annual History End Reasons.dta"
