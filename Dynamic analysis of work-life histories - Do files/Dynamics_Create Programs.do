// prog_reopenfile
capture program drop prog_reopenfile
program prog_reopenfile
	args filename
	if "`c(filename)'"!="`filename'" | `c(changed)'==1{
		use "`filename'", clear
		}
end

// prog_makeage
capture program drop prog_makeage
program define prog_makeage
	syntax varlist
	foreach var of varlist `varlist'{			
		capture drop `var'_Age
		gen `var'_Age=floor((`var'-${birth})/12)
		label variable `var'_Age "Age(`var')"
		di char(10) "`var'_Age"
		tab `var'_Age
		}
end

// prog_format
capture program drop prog_format
	program define prog_format
	qui labelbook
	if "`r(names)'"!=""	label drop `r(names)'
	qui compress
	local vlist "pidp $spell $status $start $end $intdate $birth Age_SpellStart LFS LFS_1 LFS2 LFS2_B TransitionDate_MY Dur_Spell Dur_* DurAtStart_* CountSpell_* CountTransition_*"
	keep `vlist'
	order `vlist'
	qui do "${do_fld}/Dynamics_Labels.do"
	qui do "${do_fld}/Dynamics_Apply Labels.do"
	format *MY %tm
	format Status %25.0g
	label data ""
end

// prog_getvars
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

/*
// prog_addprefix
capture program drop prog_addprefix
program define prog_addprefix
	args macro prefix file
	local prelist: subinstr global `macro' " " " `prefix'_", all
	qui des using "`file'", varlist
	local vlist `r(varlist)'
	local inlist: list prelist & vlist
	use pidp `inlist' using "`file'", clear
end
*/

// prog_prepflows
capture program drop prog_prepflows
program define prog_prepflows
	args var
	by `var' lfs, sort: gen duplic=cond(_N==1,0,_n)
	drop if duplic>1
	drop duplic
end

// prog_flows
capture program drop prog_flows
program define prog_flows
	args var weighted
	if "`var'"=="M"{
		local time month
		}
	else if "`var'"=="Q"{
		local time quarter
		}
	else if "`var'"=="Y"{
		local time year
		}
	if "`weighted'"!=""{
		local sumover sum(weight)
		local wt _W
		local wtd weighted
		local Wtd Weighted
		}
	else if "`weighted'"==""{
		local sumover count(pidp)
		local wt ""
		local wtd unweighted
		local Wtd Unweighted
		}
	* Flows. UNWEIGHTED FLOWS ARE CALCULATED AS COUNTS OF WEIGHTS, FOR EACH TYPE OF TRANSITION.
	egen double Flows_`var'`wt'_=`sumover', by(`time' lfs2)
	keep `time' lfs2 Flows_`var'`wt'_
	prog_prepflows `time'
	reshape wide Flows_`var'`wt'_, i(`time') j(lfs2) string
	drop Flows_`var'`wt'_MM
	desc, varlist	
	local temp `r(varlist)'
	local temp2 "`time'"
	local touse : list temp- temp2	
	display "`touse'"
	collapse /*
		*/ (sum) `touse' /*
		*/ , by(`time')
	compress
	foreach i in $LFS2levels{	
		capture label variable Flows_`var'`wt'_`i' "`Wtd' sum of the `i' gross flows, by `time' and flow"
		}
	* Flow rate
	foreach j in $statenames{
		capture drop denom`j'
		desc *_`j'`j', varlist	
		local temp3 `r(varlist)'
		display "`temp3'"
		desc *_`j'?, varlist
		local temp4 `r(varlist)'
		display "`temp4'"
		local touse : list temp4- temp3	
		gen denom`j'=`temp3'
		su denom`j'
		foreach i in `touse'{
			su `i'
			replace denom`j'=denom`j'+`i'
			su denom`j'
			}
		}		
	foreach i in $LFS2levels{
		foreach j in $statenames{
			if strpos("`i'","`j'")==1{
				display "`i'"
				gen Flow_`var'`wt'_`i'=Flows_`var'`wt'_`i'/denom`j'
				su Flow_`var'`wt'_`i'
				}
			}
		}
	foreach j in $statenames{
		foreach i in $LFS2levels{
			if strpos("`i'","`j'")==1{
				capture label variable Flow_`var'`wt'_`i' "`i' `wtd' flow rate Flows_`var'`wt'_`i'/(Stock of `j')"
				}
			}
			capture drop denom`j'
		}
end
