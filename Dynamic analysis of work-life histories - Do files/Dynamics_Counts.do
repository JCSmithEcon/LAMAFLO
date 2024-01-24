/*
********************************************************************************
DYNAMICS_COUNTS.DO
	
	THIS FILE CREATES 2 VARIABLES:
	- CountSpell`i': COUNT OF EACH INDIVIDUAL'S EXPERIENCE OF PARTICULAR SPELL TYPES, INCLUDING THE CURRENT SPELL.
	- CountTransition`i': COUNT OF EACH INDIVIDUAL'S EXPERIENCE OF PARTICULAR TRANSITION TYPES, UP TO AND INCLUDING THE TRANSITION THAT RESULTED IN THE CURRENT STATE (SPELL).

********************************************************************************
*/

* Count of particular spell types
foreach i in $statenames {
	gen temp=1 if LFS=="`i'"
	qui su temp
	if r(N)==0 {
		drop temp
		continue, break
		}
	by pidp: gen CountSpell_`i'=sum(temp) if LFS=="`i'"
	by pidp ($spell), sort: replace CountSpell_`i'=CountSpell_`i'[_n-1] if missing(CountSpell_`i')
	replace CountSpell_`i'=0 if missing(CountSpell_`i')
	label var CountSpell_`i' "Count of spells of `i', up to and including current spell"
	drop temp
	}
	
* Count of particular transition types
foreach i in $LFS2levels {
	gen temp=1 if LFS2=="`i'"
	qui su temp
	if r(N)==0 {
		drop temp
		continue, break
		}
	by pidp: gen CountTransition_`i'=sum(temp) if LFS2=="`i'"
	by pidp ($spell), sort: replace CountTransition_`i'=CountTransition_`i'[_n-1] if missing(CountTransition_`i')
	replace CountTransition_`i'=0 if missing(CountTransition_`i')
	label var CountTransition_`i' "Count of transitions `i', up to current spell"
	drop temp
	}
