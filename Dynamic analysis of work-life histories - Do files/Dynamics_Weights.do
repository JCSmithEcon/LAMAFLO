//prog_reopenfile "${output_fld}/Dynamics_${data}.dta"					// IF RUN VIA "Dynamics_Launch Programme.do" THESE LINES ARE NOT REQUIRED.
//keep pidp ${spell} ${intdate}

tempfile Temp
save "`Temp'", replace

* Get BHPS weights, Wave and IntDate.
* Waves 1-15.
#delim ;
global vlist 	"indin91_xw indin99_xw indin01_xw" ;					// OBTAIN RAW WEIGHT DATA. LONGITUDINAL WEIGHTS: [lrwght] indin91_lw indin99_lw indin01_lw.
#delim cr
forval i=1/`=min(15,$bhps_waves)'{
	local j: word `i' of `c(alpha)'	
	prog_getvars vlist b`j' "${fld}/${bhps_path}_w`i'/b`j'_indresp${file_type}"
	rename b`j'_* *
	gen Wave=`i'
	tempfile Temp`i'
	save "`Temp`i''", replace	
	}
forval i=`=min(15,$bhps_waves)-1'(-1)1{
	append using "`Temp`i''"
	}
merge 1:1 pidp Wave using "${input_fld}/Interview Grid", /*				// MERGE WITH INTERVIEW DATE (AT WHICH SPELL INFORMATION WAS OBTAINED), USING "Interview Grid.dta" CREATED BY "Interview Grid.do", NORMALLY RUN VIA "Launch Programmes.do".
	*/ keep(match master) keepusing(IntDate_MY) nogen
order pidp Wave IntDate_MY indin01_xw indin99_xw indin91_xw 
//save "${output_fld}/BHPS 1-15 Weights", replace
merge 1:m pidp $intdate using "`Temp'", /*
	*/ keep(match using) nogen
save "`Temp'", replace

* Waves 16-18.
#delim ;
//global vlist 	" indin*" ;
#delim cr
forval i=16/$bhps_waves{
	local j: word `i' of `c(alpha)'	
	prog_getvars vlist b`j' "${fld}/${bhps_path}_w`i'/b`j'_indresp${file_type}"
	rename b`j'_* *
	gen Wave=`i'
	tempfile Temp`i'
	save "`Temp`i''", replace	
	}
if $bhps_waves>16{
	forval i=`=$bhps_waves-1'(-1)16{
		append using "`Temp`i''"
		}
	}
merge 1:1 pidp Wave using "${input_fld}/Interview Grid", /*
	*/ keep(match master) keepusing(IntDate_MY) nogen
macro drop vlist
//save "${output_fld}/BHPS 16-18 Weights", replace
merge 1:m pidp $intdate using "`Temp'", /*
	*/ keep(match using) nogen
save "`Temp'", replace

* Get UKHLS weights, Wave and IntDate.
#delim ;
global vlist 	"indinus_xw indinub_xw indinui_xw" ;					// OBTAIN RAW WEIGHT DATA. LONGITUDINAL WEIGHTS: indinus_lw indinub_lw indinui_lw. COMMMENT: indinus_xw IS AVAILABLE IN WAVE 1, ACCORDING TO https://www.understandingsociety.ac.uk/documentation/mainstage/variables/indinus_xw/
#delim cr
forval i=1/$ukhls_waves{	
	local j: word `i' of `c(alpha)'
	prog_getvars vlist `j' "${fld}/${ukhls_path}_w`i'/`j'_indresp${file_type}"
	rename `j'_* *
	gen Wave=`i'+18
	tempfile Temp`i'
	save "`Temp`i''", replace		
	}
forval i=`=$ukhls_waves-1'(-1)2{
	append using "`Temp`i''"
	}
merge 1:1 pidp Wave using "${input_fld}/Interview Grid", /*
	*/ keep(match master) keepusing(IntDate_MY) nogen
drop if missing(IntDate_MY)
order pidp Wave IntDate_MY indinub_xw indinui_xw
macro drop vlist
//save "${output_fld}/UKHLS Weights", replace
merge 1:m pidp $intdate using "`Temp'", /*
	*/ keep(match using) nogen

* (If initially obtained) Drop longitudinal weights	
capture drop indin*_lw	
	
* Use cross-section weights
gen Weight=indin91_xw
replace Weight=indin99_xw if missing(Weight)
replace Weight=indin01_xw if missing(Weight)
replace Weight=indinui_xw if missing(Weight)
replace Weight=indinub_xw if missing(Weight)

save "${output_fld}/Dynamics_Weights.dta", replace
