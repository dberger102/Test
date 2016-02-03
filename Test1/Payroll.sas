*Testing this branch, fixing this branch, other tests; 
OPTIONS NODATE;

PROC FORMAT;


*CASH INCOME LEVEL BREAKS;
	            VALUE ECILvl(multilabel notsorted) 
								LOW        -     -0.0001 =  'Less than 0' 
								0    -       10000 =  'Less than 10'
	                             10000   -       20000 =  '10K - 20K'
	                		     20000      -       30000 =  '20K - 30K'
				                 30000      -       40000 =  '30K - 40K'
				                 40000      -       50000 =  '40K - 50K'
				                 50000      -       75000 =  '50K - 75K'
				                 75000      -      100000 =  '75K - 100K'
				                100000      -      200000 =  '100K - 200K'
				                200000      -      500000 =  '200K-500K'
				                500000      -     1000000 =  '500K-1,000K'
				               1000000      -       high  =  'Over 1,000K';



* Quintile breaks;
	VALUE ECIPCT(MULTILABEL NOTSORTED)
	0 = 'Below 0'
	1 = 'Lowest Quintile'
	2 = 'Second Quintile'
	3 = 'Third Quintile'
 	4 = 'Fourth Quintile'
	5-10 = 'Top Quintile'
	5 = '80% - 90%'
	6 = '90% - 95%'
	7 = '95% - 99%'
	8-10 = 'Top 1%'
	10 = 'Top 0.1%';

 RUN;

*%let CPI14= 0.9892;
%let CPI15=1;
%let CPI16=1.0216;
%let CPI17=1.0453;
%let CPI18=1.0699;
%let CPI25= 1.2644;




%macro EMTR(year);
proc import datafile = "D:\TM15\Data\Stubs files\stubs_TM15_v3.csv"
      out=stubs
      dbms=csv
      replace;
      getnames=no;
run;

data stubs;
set stubs;
id = _N_;
year = int((id-1)/4 + 11);
if mod(id,4) = 1 then cash = 'a';
if mod(id,4) = 2 then cash = 'b';
if mod(id,4) = 3 then cash = 'c'; 
if mod(id,4) = 0 then cash = 'd';  /*Note that cash is specified as follows: a = agi, b = eci, c = eciadj, d = ci*/
cashyear = cats(of year cash);
drop id;
run;

data test&Year;
set stubs;
if year ~= &year | cash ~= 'b' then delete;
rename var1=q1 var2=q2 var3=q3 var4=q4 var5=q5 var6=q6 var7=q7 var8=q8 var9=q9 var10=q10;
drop cashyear cash year;
run;

DATA TM&year;
INFILE "D:\TM15\Projects\Payroll\Output\Payroll&year..rb8" LRECL=104 RECFM=F;
INPUT (DEPIND AGI DEFICIT Payroll Employee EmpAddition AGI_PR DEFICIT_PR Payroll_PR Employee_PR EmpAddition_PR WEIGHT ECI) (RB8.);
if _N_ = 1 THEN SET test&year;

ECI_REAL=ECI/&&CPI&YEAR;


ECIQ = 10;
%DO I = 10 %TO 1 %BY -1;
	IF (ECI < q&i) THEN ECIQ = &I-1;
%END;
IF (AGI < 0) THEN ECIQ = 0;

IF (AGI < 0) THEN DO;
	ECI=-1;
	ECI_REAL=-1;

END;

EmployeeTotal = Employee + EmpAddition;

*Positive Employee Dummy;
IF (Payroll >= 5) then Payroll_Dummy = 1;
else Payroll_Dummy = 0;  

*Positive Income Tax Dummy;
IF (DEFICIT >= 5) then Def_Dummy =1;
else Def_Dummy = 0;

*Total Tax Units;
IF (DEFICIT=1) then Total=1;
else Total=1;

*Payroll (Total) greater than Income Tax;
If (Payroll > 5) then Payroll2 = Payroll;
else Payroll2 = 0;
If (Deficit > 5) then Deficit2 = Deficit;
else Deficit2 = 0;
 
If (Payroll2 - Deficit2 >= 5) then Payroll_Greater = 1;
else Payroll_Greater = 0; 

*Employee Share greater than Income Tax;
If (EmployeeTotal > 5) then EmployeeTotal2 = EmployeeTotal;
else EmployeeTotal2 = 0;

If ((EmployeeTotal2 - Deficit2) >= 5) then Employee_Greater = 1;
else Employee_Greater = 0;

*Positive Income or Payroll Tax; 
IF (Payroll >= 5 | Deficit >=5) then OR_Dummy = 1;
else OR_Dummy = 0;

run;

PROC TABULATE DATA=TM&year out=TMlvlout&year FORMAT=COMMA20. NOSEPS FORMCHAR='           ';
WEIGHT WEIGHT;
CLASS ECI_REAL / ORDER=DATA PRELOADFMT MLF;
VAR Def_Dummy Total Payroll_Dummy Payroll_Greater Employee_Greater OR_Dummy; 
FORMAT ECI_REAL ECILvl.;
WHERE (DEPIND ~= 1);
TABLE (ECI_REAL ALL) ,  		 ((Total) * (SUMWGT SUM) 
								 (Def_Dummy) * (SUMWGT SUM)
								 (Payroll_Dummy) * (SUMWGT SUM)
								 (OR_Dummy) * (SUMWGT SUM)
								 (Payroll_Greater) * (SUMWGT SUM)
 						 		 (Employee_Greater) * (SUMWGT SUM));
						
TITLE;
TITLE1 'Payroll and Income Tax Payers, BY LEVELS';
RUN;


PROC TABULATE DATA=TM&year out=TMout&year FORMAT=COMMA20. NOSEPS FORMCHAR='           ';
WEIGHT WEIGHT;
CLASS ECIQ /ORDER=DATA PRELOADFMT ML;
VAR Def_Dummy Total Payroll_Dummy Payroll_Greater Employee_Greater OR_Dummy;
FORMAT ECIQ ECIPCT.;
WHERE (DEPIND ~= 1);
TABLE (ECIQ ALL) ,   			 ((Total) * (SUMWGT SUM) 
								 (Def_Dummy) * (SUMWGT SUM)
								 (Payroll_Dummy) * (SUMWGT SUM)
								 (OR_Dummy) * (SUMWGT SUM)
								 (Payroll_Greater) * (SUMWGT SUM)
 						 		 (Employee_Greater) * (SUMWGT SUM));
						
TITLE;
TITLE1 'Payroll and Income Tax Payers, BY PERCENTILES';

RUN;

%MEND;

*%EMTR(year=14);
%EMTR(year=15);
%EMTR(year=16);
%EMTR(year=17);
%EMTR(year=18);
%EMTR(year=25);

