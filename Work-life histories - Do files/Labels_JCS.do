capture label drop annualhistory_routing
label define annualhistory_routing /*
				*/ 1 "1. NOTEMPCHK Only" /*
				*/ 2 "2. EMPCHK Only" /*
				*/ 3 "3. NOTEMPCHK and EMPCHK"

				
capture label drop route3_type
label define route3_type /*
				*/ .i "N/A. AnnualHistory_Routing == 1|2" /*
				*/ 1 "1. NOTEMPCHK == .m, EMPCHK == .m" /*
				*/ 2 "2. NOTEMPCHK == .m, EMPCHK == 1" /*
				*/ 3 "3. NOTEMPCHK == .m, EMPCHK == 2" /*
				*/ 4 "4. NOTEMPCHK == 1, EMPCHK == .m" /*
				*/ 5 "5. NOTEMPCHK == 1, EMPCHK == 1" /*
				*/ 6 "6. NOTEMPCHK == 1, EMPCHK == 2" /*
				*/ 7 "7. NOTEMPCHK == 2, EMPCHK == .m" /*
				*/ 8 "8. NOTEMPCHK == 2, EMPCHK == 1" /*
				*/ 9 "9. NOTEMPCHK == 2, EMPCHK == 2"


// status label: Statuses 12 AND 13 ARE ADDED ("Furlough" AND "Temporarily laid off/short time working"). "Short term working" IS ALTERED TO "Short time working". Statuses 112,113,10012,10013 ARE CREATED IN A VERSION (_F) OF UKHLS Annual History THAT TREATS FURLOUGH AND SHORT TIME WORKING AS SEPARATE STATUSES. (THESE CHANGES REFLECT UKHLS DATA AND ARE NOT RELEVANT FOR BHPS DATA.)
capture label drop status
label define status /*
		*/ .m "-m. Missing/Refused/Don't Know" /*
		*/ 1 "1. Self-Employed" /*
		*/ 2 "2. Paid Employment" /*
		*/ 3 "3. Unemployed" /*
		*/ 4 "4. Retired" /*
		*/ 5 "5. Maternity Leave" /*
		*/ 6 "6. Family Carer or Homemaker" /*
		*/ 7 "7. Full-Time Student" /*
		*/ 8 "8. Sick or Disabled" /*
		*/ 9 "9. Govt Training Scheme" /*
		*/ 10 "10. Unpaid, Family Business" /*
		*/ 11 "11. Apprenticeship" /*
		*/ 12 "12. Furlough" /*
		*/ 13 "13. Temporarily laid off/short time working" /* 		//	NOTE THAT jbstat USES "short term working"
		*/ 97 "97. Doing Something Else" /*
		*/ 100 "100. Paid Work (Annual History)" /*
		*/ 101 "101. Something Else (Annual History)" /*
		*/ 102 "102. Maternity Leave (Annual History)" /*
		*/ 103 "103. National Service/War Service (Life History)" /*
		*/ 104 "104. Current Status Reached (Life History)" /*
		*/ 112 "112. Self-Employed on Furlough" /*
		*/ 113 "113. Self-Employed Temporarily laid off/short-time working" /*
		*/ 212 "212. Paid Employment on Furlough" /*
		*/ 213 "213. Paid Employment Temporarily laid off/short-time working" /*
		*/ 10012 "10012. Empl/Self-empl and Furlough" /*
		*/ 10013 "10013. Empl/Self-empl and Temporarily laid off/short time working"		

			
capture label drop emplw
label define emplw /*
        */  .m ".m. Missing/Refused/Don't Know" /*
        */ .i ".i. IEMB/Innapplicable/Proxy" /*
        */  1 "1. In paid employment" /*
        */  2 "2. Not in paid employment"

		
capture label drop activity_ended_indicator
label define activity_ended_indicator /*
		*/ .m ".m. Missing/Refused/Don't Know" /*
		*/ .i ".i. IEMB/Innapplicable/Proxy" /*
		*/ 0 "0. Actitivity not ended" /*
		*/ 1 "1. Activity ended"
		
capture label drop job_hours
label define job_hours /*
		*/ .m ".m. Missing/Refused/Don't Know" /*
		*/ 1 "1. Full-Time" /*
		*/ 2 "2. Part-Time"
		
capture label drop employer_workplace
label define employer_workplace /*
		*/ 1 "1. New job with new employer" /*
		*/ 2 "2. New job with old employer, same workplace" /*
		*/ 3 "3. New job with old employer, new workplace" /*
		*/ 4 "4. New job with old employer, unknown workplace"

		
capture label drop maternityleave
label define maternityleave /*
		*/ .m ".m. Missing/Refused/Don't Know" /*
		*/ .i ".i. IEMB/Innapplicable/Proxy" /*
		*/ 1 "1. No maternity leave (matlv==2)" /*
		*/ 2 "2. Finished maternity leave (matlvend<istrtdat)" /*
		*/ 3 "3. On maternity leave (matlv==3)" /*
		*/ 4 "4. On maternity leave (matlvend>istrtdat)" /*
		*/ 5 "5. Had maternity leave, end but not start missing" /*
		*/ 6 "6. Had maternity leave, end and start missing"

		
capture label drop spell_type
label define spell_type /*
		*/ 0 "0. Interior spell" /*
		*/ 1 "1. Wave spanning spell" /*
		*/ 2 "2. Seam at wave start" /*
		*/ 3 "3. Seam at wave end" /*
		*/ 4 "4. Unknown: End Indicator Missing" /*
		*/ 5 "5. Imputed spell"

		
capture label drop flag
label define flag /*
		*/ .m ".m. Missing/Refused/Don't Know" /*
		*/ 0 "0. No imputation" /*
		*/ 1 "1. Truncated: Seam Spell" /* 
		*/ 2 "2. Imputed: Equal division across status spell" /*
		*/ 3 "3. Imputed: Equal division across gap" /*
		*/ 4 "4. Truncated: Missing month" /*
		*/ 5 "5. Truncated: Missing month and year" /*
		*/ 6 "6. Imputed: Month in Season" /*
		*/ 7 "7. Imputed: scend missing" /*
		*/ 8 "8. Truncated, by BHPS Education History" /*
		*/ 9 "9. Truncated, by BHPS Annual History" /*
		*/ 10 "11. Truncated, by BHPS Life History" /*
		*/ 11 "11. Truncated, by Education History spell" /*
		*/ 12 "12. Truncated, Life History" /*
		*/ 13 "13. School Date"

		
capture label drop datasets
label define datasets /*
		*/ 1 "1. UKHLS Only" /* 
		*/ 2 "2. UKHLS and BHPS"
	
	
capture label drop jobhisthas
label define jobhisthas /*
        */  .m ".m. Missing/Refused/Don't Know" /*
        */ .i ".i. IEMB/Innapplicable/Proxy" /*
        */  1 "1. On or before September 1 of JobHistDate" /*
        */  2 "2. After September 1 of JobHistDate"

		
capture label drop intdates_ind
label define intdates_ind /*
				*/ 1 "1. New Entrant" /*
				*/ 2 "2. Previous Interview Earlier" /*
				*/ 3 "3. Job History Date Earlier"

				
capture label drop dataset
label define dataset /*
				*/ 0 "0. UKHLS Annual History" /*
				*/ 1 "1. UKHLS Education History" /*
				*/ 2 "2. UKHLS Life History" /*
				*/ 3 "3. BHPS Annual History" /*
				*/ 4 "4. BHPS Education History" /*
				*/ 5 "5. BHPS Life History"	

				
capture label drop source_type
label define source_type /*
				*/ 0 "0. Gap" /*
				*/ 1 "1. Annual History" /*
				*/ 2 "2. Education History" /*
				*/ 3 "3. Life History" /*
				*/ 4 "4. School Dates"

				
capture label drop job_change
label define job_change /*
				*/  .m ".m. Missing/Refused/Don't Know" /*
				*/ .i ".i. IEMB/Innapplicable/Proxy" /*
				*/ 0 "0. Same job" /*
				*/ 1 "1. Return to same job" /*
				*/ 2 "2. New job, same employer" /*
				*/ 3 "3. New employer" /*
				*/ 4 "4. (Possible) multiple jobs"
