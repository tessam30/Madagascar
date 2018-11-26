*********************************************************
* Title: Madagascar Data Analysis for FFP Design Team
* Purpose: Condcut analysis on project data 
* Author:
* Date: 2018_06_04
*********************************************************

capture log close
clear


* Install .ado files needed for the analysis (Only need to run these next two lines once)
ssc install coefplot
ssc install estout


* Create a global macro to mapto the directory with the final data sets
pwd
global datain "/Users/timessam/Documents/USAID/2018_Madagascar_FFP/f. Final data files/3. Combined"
dir


* Load the children's data to start the analysis
	use "$datain/MAD_Children_Anthro_Combined_STATA12.dta", clear
	
	* Check what combination of variables create a unique identifier
	* B/c Stata did not bark at us, we know this combo of variables is unique
	isid hhea hhnum d67

* Merge the children's data to the household level data to look at correlates of stunting
	merge m:1 hhea hhnum using "$datain/ffp_mad_poverty_combined_data_STATA12.dta", gen(_pov_merge)
	tab _pov_merge

	merge m:1 hhea hhnum using "$datain/MAD_Household_Combined_STATA12.dta", gen(_hhchar_merge)

* Clone the WASH and some of the indices and give them names a commoner can understand
	clonevar improved_h20 = iflg19
	clonevar improved_sanit = iflg22
	clonevar HDDS = iflg01
	clonevar stunt_Zscore = _zlen
	histogram stunt_Zscore
	
	
* FLAG: WHAT IS UP THE iflg02? DOES NOT SEEM TO BE CORRECT.
* It appears that the Household Hunger Scale has not ben created? The variable appears to be binary
	tab iflg02, mi

* Set sampling weights to account for the complex sampling design and get appropriate variance caluclations
	svyset [pw=sw], psu (hhea) strata (project) 
	svydescribe

* Report summary statistics of stunting by region and gender
	svy:mean stunting, over(region gender)
	svy:mean stunting, over(improved_h20)
	svy:mean stunting, over(improved_sanit)
	svy:mean stunting, over(region)

* Create an age squared to test whether or not age has a quadratic relationship with z-scores
	gen age_mos_squared = agemos^2
	
	
* Run a few basic regressions to see relationships 
	* Use the global macro to set a list of covariates for each regression
	global hhdemog "hh_head_sex hhsize poverty_gap_index adult_mf"
	global child "agemos age_mos_squared i.gender"
	global hhchar "improved_h20 improved_sanit HDDS"
	global geo "ib(4).region"

* Clear out any prior estimates that are stored under the estout command
	est clear

********************************************************************************
* Stunting (binary) regressions
********************************************************************************	
	
* Estimate a series of models incrementally adding in relevant covariates
	eststo logit1: logit stunting $child, cluster(hhea)
	eststo logit2: logit stunting $child $hhdemog, cluster(hhea)
	eststo logit3: logit stunting $child $hhdemog $hhchar $geo, cluster(hhea)
	
	* Specification test for the last model
	linktest

* Combine all the results into a single table and summarize it -- check stability of coefficients
	esttab logit*, star(* 0.10 ** 0.05 *** 0.01) label not


********************************************************************************
* Stunting Z-scores regressions*
******************************************************************************** 

	capture est drop reg* 
	eststo reg1: reg stunt_Zscore $child, cluster(hhea)
	eststo reg2: reg stunt_Zscore $child $hhdemog, cluster(hhea)
	eststo reg3: reg stunt_Zscore $child $hhdemog $hhchar $geo, cluster(hhea)
	* Check for variation inflation
	vif
	esttab reg*, star(* 0.10 ** 0.05 *** 0.01) label not

* Loop over the regions and check how stable the coeficients are
* Using the levelsof command to create a tokenized list of the values for each region
	cap est drop georeg*
	levelsof region, local(region)

* Now, let's loop over each region storing the regression results in a table to view
	foreach x of local region {
	
		* Store each iteration of the loop in a estout file, while running a regression over z-scores
		* Note that the geo macro is removed b/c of nature of filter
		eststo georeg`x': reg stunt_Zscore $child $hhdemog $hhchar if region == `x', cluster(hhea) 

	}

* Print the summary table to the Stata prompt (the * is a wildcard); Then print the cross walk for regions
	esttab georeg*, star(* 0.10 ** 0.05 *** 0.01) label not
	label list a03a

	* In case you would like to save any of the regression results to a csv
	esttab georeg* using "MAD_stunting_regressions.csv", star(* 0.10 ** 0.05 *** 0.01) label not replace

