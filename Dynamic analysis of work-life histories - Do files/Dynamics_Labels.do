// status label: Statuses 12 AND 13 ARE ADDED ("Furlough" AND "Temporarily laid off/short time working"). "Short term working" IS ALTERED TO "Short time working". Statuses 112,113,10012,10013 ARE CREATED IN A VERSION ("furlough") OF UKHLS Annual History THAT TREATS FURLOUGH AND SHORT TIME WORKING AS SEPARATE STATUSES. (THESE CHANGES REFLECT UKHLS DATA AND ARE NOT RELEVANT FOR BHPS DATA.)
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

