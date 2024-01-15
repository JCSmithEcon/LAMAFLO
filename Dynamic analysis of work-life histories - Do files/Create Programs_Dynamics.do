// prog_reopenfile USES NEW DATA FILE IF IT'S SAFE TO DO SO.
capture program drop prog_reopenfile
program prog_reopenfile
	args filename
	if "`c(filename)'"!="`filename'" | `c(changed)'==1{
		use "`filename'", clear
		}
end

// prog_labels_dynamics
capture program drop prog_labels_dynamics
program prog_labels_dynamics
	qui do "${do_fld}/Labels_Dynamics.do"
	qui do "${do_fld}/Apply Labels_Dynamics.do"
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

// prog_makeage
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
