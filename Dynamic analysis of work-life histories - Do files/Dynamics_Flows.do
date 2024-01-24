/*
********************************************************************************
DYNAMICS_FLOWS.DO
	
	THIS FILE CREATES OPTIONAL OUTPUT FILES CONTAINING THE FOLLOWING VARIABLES. THE FINAL PRODUCTS ARE FLOWS AND FLOW RATES, BUT IN "Dynamics_Launch Programme.do" USERS CAN CHOOSE TO OUTPUT SEPARATE FILES CONTAINING `INTERMEDIATE' WIDE- AND LONG-FORMAT VARIABLES THAT MIGHT BE OF INTEREST IN THEIR OWN RIGHT:

	- IN "Dynamics_lfs_wide_pidp_m.dta" (OPTIONAL OUTPUT, WIDE FORMAT, ALL MONTHS FOR EACH INDIVIDUAL):
		* lfsM: INDIVIDUAL'S STATE IN MONTH M.
		* ${status}M, ${start}M, ${end}M: INDIVIDUAL'S ${status}, SPELL START DATE AND SPELL END DATE [ALL RAW DATA] IN MONTH M.
		* pidpstart, pidpend: START AND END DATES OF INDIVIDUAL'S RECORDED HISTORY.
	- IN "Dynamics_lfs_long_pidp_m.dta" (OPTIONAL OUTPUT, LONG FORMAT, ALL MONTHS FOR EACH INDIVIDUAL):
		* lfs: INDIVIDUAL-MONTH STATE.
	- IN "Dynamics_weight_wide_pidp_m.dta" (OPTIONAL OUTPUT, WIDE FORMAT, ALL MONTHS FOR EACH INDIVIDUAL):
		* weightM: CROSS-SECTION WEIGHT APPLICABLE TO INDIVIDUAL'S SPELL AT MONTH M, BASED ON INTERVIEW DATE WHEN SPELL INFORMATION WAS GIVEN.
		* ${start}M, ${end}M: INDIVIDUAL'S SPELL START DATE AND SPELL END DATE [ALL RAW DATA] IN MONTH M.
		* pidpstart, pidpend: START AND END DATES OF INDIVIDUAL'S RECORDED HISTORY.
	- IN "Dynamics_weight_long_pidp_m.dta" (OPTIONAL OUTPUT, LONG FORMAT, ALL MONTHS FOR EACH INDIVIDUAL):
		* weight: INDIVIDUAL-MONTH WEIGHT, BASED ON INTERVIEW DATE WHEN SPELL INFORMATION WAS GIVEN.
	- IN "Dynamics_Merged Dataset_Flows_M.dta" (OPTIONAL OUTPUT):
		* Flows_M_XY: UNWEIGHTED MONTHLY FLOWS BETWEEN STATES X and Y (STATES ARE DEFINED BY THE USER AT THE TOP OF "Dynamics_Launch Programme.do".
		* Flow_M_XY: UNWEIGHTED MONTHLY FLOW RATE BETWEEN STATES X and Y.
	- IN "Dynamics_Merged Dataset_Flows_Q.dta" (OPTIONAL OUTPUT):
		* Flows_Q_XY: UNWEIGHTED QUARTERLY FLOWS.
		* Flow_Q_XY: UNWEIGHTED QUARTERLY FLOW RATE.
	- IN "Dynamics_Merged Dataset_Flows_Y.dta" (OPTIONAL OUTPUT):
		* Flows_Y_XY: UNWEIGHTED ANNUAL FLOWS.
		* Flow_Y_XY: UNWEIGHTED ANNUAL FLOW RATE.
	- IN "Dynamics_Merged Dataset_Flows_M_W.dta" (OPTIONAL OUTPUT):
		* Flows_M_W_XY: WEIGHTED MONTHLY FLOWS BETWEEN STATES X and Y.
		* Flow_M_W_XY: WEIGHTED MONTHLY FLOW RATE BETWEEN STATES X and Y.
	- IN "Dynamics_Merged Dataset_Flows_Q.dta" (OPTIONAL OUTPUT):
		* Flows_Q_W_XY: WEIGHTED QUARTERLY FLOWS.
		* Flow_Q_W_XY: WEIGHTED QUARTERLY FLOW RATE.
	- IN "Dynamics_Merged Dataset_Flows_Y.dta" (OPTIONAL OUTPUT):
		* Flows_Y_W_XY: WEIGHTED ANNUAL FLOWS.
		* Flow_Y_W_XY: WEIGHTED ANNUAL FLOW RATE.
	
********************************************************************************
*/

if "Monthly_Flows_Unweighted"=="Y" | "Quarterly_Flows_Unweighted"=="Y" | "$Annual_Flows_Unweighted"=="Y" | "Monthly_Flows_Unweighted"=="YES" | "Quarterly_Flows_Unweighted"=="YES" | "$Annual_Flows_Unweighted"=="YES"{

	prog_reopenfile "${output_fld}/Dynamics_Merged Dataset.dta", replace
	keep pidp ${spell} ${start} ${end} ${status}
	global start_time_flows "$S_TIME"
	di in red "Status Spell-Monthly Conversion Started: $start_time_flows"
	* Convert pidp-spell data to wide pidp-month data.
	drop if ${start}<monthly("${flows_start}","YM")-1						// DEFAULT IS TO OBTAIN FLOWS FROM JANUARY 1990 ONWARDS. 
	local startdate : di monthly("${flows_start}","YM")-1
	local startdate_tm: di %tm `startdate'
	di in red "Calculation of flows will start with month `startdate_tm' (`startdate'), in order to generate flows starting at $flows_start."
	by pidp (${spell}), sort: replace ${spell}=_n	
	qui su $start
	global minsdate=r(min)
	global maxsdate=r(max)
	qui su ${spell}
	global maxspells=r(max)
	by pidp ($spell), sort: egen pidpstart=min(${start})					// RANGE OF SPELL DATES FOR EACH INDIVIDUAL, TO ENABLE DROPPING REDUNDANT DATA.
	by pidp ($spell), sort: egen pidpend=max(${end})
	format pidpstart pidpend %tm
	reshape wide ${status} ${start} ${end}, i(pidp) j(${spell})
	tempfile Temp
	local m=${minsdate}-1													// LOOP AROUND MONTHS AND SPELLS.
	while `m'<=($maxsdate-1) {
		local m=`m'+1
		local mcur=`m'-$minsdate+1
		local mmax=$maxsdate-$minsdate+1
		local month : di %tm `m'
		noisily display as text "Started month `m' (`mcur'/`mmax'): `month'"
			preserve
			qui drop if `m'<pidpstart-1 | `m'>pidpend						// DROP pidps WHOSE SPELL DATES DO NOT ENCOMPASS MONTH OF INTEREST.
			gen lfs`m'="O"
			local i=0 
			while `i'<=($maxspells-1) {										// LOOP OVER MONTHS, ALLOCATING STATUS TO MONTH IF MONTH IS BETWEEN SPELL START AND END DATES.
				local i=`i'+1
				forvalues j=1/$numberofstates{
					forvalues k=1/${S`j'_count}{
						qui replace lfs`m'="${state`j'_name}" if inlist(${status}`i',${S`j'_`k'}) & inrange(`m',${start}`i',${end}`i'-1) & !missing(${start}`i',${end}`i')
						}
					}
				qui replace lfs`m'="M" if missing(${status}`i') & inrange(`m',${start}`i',${end}`i'-1) & !missing(${start}`i',${end}`i')
				}
			keep pidp lfs`m'
			qui save "`Temp'", replace
			restore
		qui merge 1:1 pidp using "`Temp'", nogen
		noisily display as text "Finished month `m': $S_TIME""
		}
	if "$Monthly_Wide"=="Y" {
		save  "${output_fld}/Dynamics_lfs_wide_pidp_m.dta", replace
		}
	di in red "Spell-Monthly Wide Started: $start_time_flows"
	di in red "Spell-Monthly Wide Completed: $S_TIME"	
	* Convert wide pidp-month data to long pidp-month data.
	ssc uninstall tolong													// UNINSTALL USER-WRITTEN STATA PACKAGE tolong. PROGRAM IS SOMETIMES NOT FOUND UNLESS RECENTLY INSTALLED.
	ssc install tolong														// INSTALL tolong FASTER RESHAPE LONG PACKAGE FROM SSC.
	prog_reopenfile  "${output_fld}/Dynamics_lfs_wide_pidp_m.dta"
	keep lfs* pidp
	tolong lfs#, i(pidp) j(month)											// RESHAPE THE MONTHLY DATA FROM WIDE FORMAT INTO LONG FORMAT.
	sort pidp month
	if "$Monthly_Long"=="Y" {
		save  "${output_fld}/Dynamics_lfs_long_pidp_m.dta", replace
		}
	di in red "Spell-Monthly Long Completed: $S_TIME"

	* Create unweighted flows (monthly, quarterly, annual)
	prog_reopenfile "${output_fld}/Dynamics_lfs_long_pidp_m.dta"
	encode lfs, gen(temp)													// TO LAG, A NON-STRING VARIABLE IS REQUIRED. E.G. VALUES 1,2,3,4, WHICH ARE LABELLED ACCORDING TO THE ORIGINAL ALPHABETIC VARIABLE (E.G. E,N,M,U) (THE LABEL NAME IS temp).
	compress
	tab lfs if lfs!="O"
	xtset pidp month
	gen byte temp_1=l1.temp
	label values temp_1 temp
	drop temp
	decode temp_1, gen(lfs_1)
	tab lfs_1 if lfs_1!="O"
	drop temp_1
	gen lfs2=lfs_1+lfs														// CREATE TRANSITION.
	drop lfs_1 lfs
	drop if strpos(lfs2,"O")!=0 | strlen(lfs2)!=2							// THIS LINE CAN BE APPLIED IF STATE NAMES ALL CONSIST OF 1 LETTER.
	sort month lfs2
	gen day=dofm(month)
	format day %td
	gen quarter=qofd(day)
	format quarter %tq
	gen year=yofd(day)
	save "${output_fld}/flows.dta", replace
	* Monthly unweighted flows and flow rates
	if "$Monthly_Flows_Unweighted"=="Y" | "$Monthly_Flows_Unweighted"=="YES"{
		prog_reopenfile "${output_fld}/flows.dta"
		prog_flows M
		}
	* Quarterly unweighted flows and flow rates
	if "$Quarterly_Flows_Unweighted"=="Y" | "$Quarterly_Flows_Unweighted"=="YES"{
		prog_reopenfile "${output_fld}/flows.dta"
		prog_flows Q
		}
	* Annual unweighted flows and flow rates
	if "$Annual_Flows_Unweighted"=="Y" | "$Annual_Flows_Unweighted"=="YES"{
		prog_reopenfile "${output_fld}/flows.dta"
		prog_flows Y
		}
	}


* Weighted flows and flow rates	
if "Monthly_Flows_Weighted"=="Y" | "Quarterly_Flows_Weighted"=="Y" | "$Annual_Flows_Weighted"=="Y" | "Monthly_Flows_Weighted"=="YES" | "Quarterly_Flows_Weighted"=="YES" | "$Annual_Flows_Weighted"=="YES"{
	di in red "Calculating weights"
	prog_reopenfile "${output_fld}/Dynamics_Merged Dataset.dta", replace
	* Merge in weights by pidp $intdate (the $intdate that is (should be in principle, and is in most cases) the source of the spell information)
	do "${do_fld}/Dynamics_Weights.do"
	keep pidp ${spell} ${start} ${end} Weight
	qui su Weight
	local obsWeight=r(N)
	replace Weight=0 if missing(Weight)
	qui su Weight
	local obsAll=r(N)
	local propWeight=100*(`obsWeight'/`obsAll')
	di in red "Weights are available for `propWeight'% of the sample"

	global start_time_weight "$S_TIME"
	di in red "Weight Spell-Monthly Conversion Started: $start_time_weight"
	* Convert pidp-spell weight data to wide pidp-month weight data.
	drop if ${start}<monthly("${flows_start}","YM")							// DEFAULT IS TO OBTAIN FLOWS FROM JANUARY 1990 ONWARDS. 
	by pidp (${spell}), sort: replace ${spell}=_n	
	qui su $start
	global minsdate=r(min)
	global maxsdate=r(max)
	qui su ${spell}
	global maxspells=r(max)
	by pidp ($spell), sort: egen pidpstart=min(${start})					// RANGE OF SPELL DATES FOR EACH INDIVIDUAL, TO ENABLE DROPPING REDUNDANT DATA.
	by pidp ($spell), sort: egen pidpend=max(${end})
	format pidpstart pidpend %tm
	reshape wide Weight ${start} ${end}, i(pidp) j(${spell})				// WEIGHT IS ALREADY ALLOCATED (VIA {intdate}) TO EACH SPELL. THE BELOW CODE ALLOCATES WEIGHT TO MONTH USING SPELL START AND END MONTHS.
	tempfile Temp
	local m=${minsdate}-1													// LOOP AROUND MONTHS AND SPELLS.
	while `m'<=($maxsdate-1) {
		local m=`m'+1
		local mcur=`m'-$minsdate+1
		local mmax=$maxsdate-$minsdate+1
		local month : di %tm `m'
		noisily display as text "Monthly weights: Month `mcur'/`mmax': `month'"
			preserve
			qui drop if `m'<pidpstart-1 | `m'>pidpend						// DROP pidps WHOSE SPELL DATES DO NOT ENCOMPASS MONTH OF INTEREST.
			gen weight`m'=0
			local i=0 
			while `i'<=($maxspells-1) {										// LOOP OVER MONTHS, ALLOCATING WEIGHT TO MONTH IF MONTH IS BETWEEN SPELL START AND END DATES.
				local i=`i'+1
				qui replace weight`m'=Weight`i' if inrange(`m',${start}`i',${end}`i'-1) & !missing(${start}`i',${end}`i')
				qui replace weight`m'=0 if missing(Weight`i') & inrange(`m',${start}`i',${end}`i'-1) & !missing(${start}`i',${end}`i')
				}			
			keep pidp weight`m'
			qui save "`Temp'", replace
			restore
		qui merge 1:1 pidp using "`Temp'", nogen
		noisily display as text "Finished month `mcur': $S_TIME""
		}
	if "$Monthly_Wide"=="Y" {
		save  "${output_fld}/Dynamics_weight_wide_pidp_m.dta", replace
		}
	di in red "Weights Spell-Monthly Wide Started: $start_time_weight"
	di in red "Weights Spell-Monthly Wide Completed: $S_TIME"	
	* Convert wide pidp-month data to long pidp-month data.
	ssc uninstall tolong													// UNINSTALL USER-WRITTEN STATA PACKAGE tolong. PROGRAM IS SOMETIMES NOT FOUND UNLESS RECENTLY INSTALLED.
	ssc install tolong														// INSTALL tolong FASTER RESHAPE LONG PACKAGE FROM SSC.
	prog_reopenfile  "${output_fld}/Dynamics_weight_wide_pidp_m.dta"
	keep weight* pidp
	tolong weight#, i(pidp) j(month)										// RESHAPE THE MONTHLY DATA FROM WIDE FORMAT INTO LONG FORMAT.
	sort pidp month
	if "$Monthly_Long"=="Y" {
		save  "${output_fld}/Dynamics_weight_long_pidp_m.dta", replace
		}
	di in red "Weights Spell-Monthly Long Completed: $S_TIME"

	* Create weighted flows (monthly, quarterly, annual)
	prog_reopenfile "${output_fld}/Dynamics_lfs_long_pidp_m.dta"
	merge 1:1 pidp month using "${output_fld}/Dynamics_weight_long_pidp_m.dta", keep(match) nogen
	encode lfs, gen(temp)													// TO LAG, A NON-STRING VARIABLE IS REQUIRED. E.G. VALUES 1,2,3,4, WHICH ARE LABELLED ACCORDING TO THE ORIGINAL ALPHABETIC VARIABLE (E.G. E,N,M,U) (THE LABEL NAME IS temp).
	compress
	xtset pidp month
	gen byte temp_1=l1.temp
	label values temp_1 temp
	drop temp
	decode temp_1, gen(lfs_1)
	drop temp_1
	gen lfs2=lfs_1+lfs														// CREATE TRANSITION.
	drop lfs_1 lfs
	drop if strpos(lfs2,"O")!=0 | strlen(lfs2)!=2							// THIS LINE CAN BE APPLIED IF STATE NAMES ALL CONSIST OF 1 LETTER.
	sort month lfs2
	gen day=dofm(month)
	format day %td
	gen quarter=qofd(day)
	format quarter %tq
	gen year=yofd(day)
	save "${output_fld}/flows.dta", replace
	* Monthly weighted flows and flow rates
	if "$Monthly_Flows_Weighted"=="Y" | "$Monthly_Flows_Weighted"=="YES"{
		prog_reopenfile "${output_fld}/flows.dta"
		prog_flows M W
		save "${output_fld}/Dynamics_Flows_M_W.dta", replace
		}
	* Quarterly weighted flows and flow rates
	if "$Quarterly_Flows_Weighted"=="Y" | "$Quarterly_Flows_Weighted"=="YES"{
		prog_reopenfile "${output_fld}/flows.dta"
		prog_flows Q W
		save "${output_fld}/Dynamics_Flows_Q_W.dta", replace
		}
	* Annual weighted flows and flow rates
	if "$Annual_Flows_Weighted"=="Y" | "$Annual_Flows_Weighted"=="YES"{
		prog_reopenfile "${output_fld}/flows.dta"
		prog_flows Y W
		save "${output_fld}/Dynamics_Flows_Y_W.dta", replace
		}
	}

rm "${output_fld}/flows.dta"
di in red "Flows/Flow Rates Calculation Completed: $S_TIME"
	
di in red "Your chosen flows and flow rates data can be found in your output folder (e.g. Dynamics_Flows_M.dta, Dynamics_Flows_Y_W.dta)"
di in red "Transitions data and chosen durations and counts data can be found in Dynamics_${data}.dta in your output folder"
