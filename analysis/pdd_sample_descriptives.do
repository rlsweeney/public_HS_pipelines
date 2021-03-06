global fname pdd_sample_descriptives
 
set more off
pause on
set matsize 10000
set seed 123456

cap ssc install reghdfe
cap ssc install estout
cap ssc install binscatter
cap ssc install parmest

global ddir "/home/sweeneri/Projects/Pipelines/DraftFiles"

capture log close
log using "$ddir/output/logs/${fname}.txt", replace text
set linesize 255

global hedonics "lnsqft _X*"
 
use if insample == 1 & random_id < 1.01 using $ddir/generated_data/dd_regdata, clear
	replace km_to_ng =  km_to_ng_nodistr
	replace km_to_anyPGEng = km_to_ng_nodistr_pge
	replace ft_to_ng =  ft_to_ng_nodistr
	replace ft_to_anyPGEng = ft_to_ng_nodistr_pge
    keep if gasutility == "PGE"
    keep if ft_to_ng <= 4000
    
 
capture drop _T* PGE
do $ddir/analysis/pdd_prep_distance_defs.do
gen _T2k__2k = (bin1k == 1000 | bin1k == 2000)

/* Show covariate support of sample */

summ price rbaths bedrooms pool garage ft_to_roads n_foreclose_pre6 

twoway (histogram bedrooms if _T2k__2k ==1, start(0) width(1) color(gray)) ///
       (histogram bedrooms if _T2k__2k ==0, start(0) width(1) ///
	   fcolor(none) lcolor(black)), legend(order(1 "0-2000 ft." 2 "> 2000 ft." )) name(bedrooms, replace) xlabel(0(1)5) xtitle("Bedrooms", height(4)) title("Number of Bedrooms") scheme(s1mono)

twoway (histogram rbaths if _T2k__2k ==1, start(0) width(1) color(gray)) ///
       (histogram rbaths if _T2k__2k ==0, start(0) width(1) ///
	   fcolor(none) lcolor(black)), legend(order(1 "0-2000 ft." 2 "> 2000 ft." )) name(rbaths, replace) xlabel(0(1)5) xtitle("Bedrooms", height(4)) title("Number of Bathrooms") scheme(s1mono)

twoway (histogram lnsqft if _T2k__2k ==1, start(5) width(0.25) color(gray)) ///
       (histogram lnsqft if _T2k__2k ==0, start(5) width(0.25) ///
	   fcolor(none) lcolor(black)), legend(order(1 "0-2000 ft." 2 "> 2000 ft." )) name(lnsqft, replace) xlabel(5(1)9) xtitle("Log Square Footage", height(4)) title("Log Square Footage") scheme(s1mono)

gen sa_yr_blt_1920 = max(sa_yr_blt,1920)
twoway (histogram sa_yr_blt_1920 if _T2k__2k ==1, start(1920) width(10) color(gray)) ///
       (histogram sa_yr_blt_1920 if _T2k__2k ==0, start(1920) width(10) ///
	   fcolor(none) lcolor(black)), legend(order(1 "0-2000 ft." 2 "> 2000 ft." )) name(sa_yr_blt, replace) xlabel(1920(20)2010) xtitle("Year Built", height(4)) title("Year Built") scheme(s1mono)

/*
gen ft_to_roads_10k = min(ft_to_roads,10000)
twoway (histogram ft_to_roads_10k if _T2k__2k ==1, start(0) width(2000) color(gray)) ///
       (histogram ft_to_roads_10k if _T2k__2k ==0, start(0) width(2000) ///
	   fcolor(none) lcolor(black)), legend(order(1 "0-2000 ft." 2 "> 2000 ft." )) name(ft_to_roads, replace) xlabel(0(1000)10) xtitle("Distance in feet", height(4)) title("Nearest highway") scheme(s1mono)

gen n_foreclose_pre6_100 = min(n_foreclose_pre6,100)
twoway (histogram n_foreclose_pre6_100 if _T2k__2k ==1, start(0) width(5) color(gray)) ///
       (histogram n_foreclose_pre6_100 if _T2k__2k ==0, start(0) width(5) ///
	   fcolor(none) lcolor(black)), legend(order(1 "0-2000 ft." 2 "> 2000 ft." )) name(n_foreclose_pre6, replace) xlabel(0(20)100) xtitle("Foreclosures", height(4)) title("Nearby foreclosures last 6 mo.") scheme(s1mono)
*/

graph combine bedrooms rbaths lnsqft sa_yr_blt,  scheme(s1mono)
graph export "$ddir/output/overlap_bw.eps", as(eps) replace
graph export "$ddir/output/overlap_bw.png", as(png) replace

gr close _all

* Covariate tables
label var _T2k__2k "Within 2000 ft."
label var rbaths "Bathrooms"
label var _Xpool "Pool"
label var _Xgarage "Garage"
label var sa_sqft "Square feet"
label var sa_yr_blt "Year built"

estimates clear
eststo clear

local i = `i' + 1
foreach v of varlist bedrooms rbaths _Xpool _Xgarage sa_sqft sa_yr_blt {
	summ `v'
	sca def mean`v' = r(mean)
	areg `v' _T2k__2k, absorb(census_tract)
		estimates store m`i'
		estadd scalar mean = mean`v'
	local i = `i' + 1
	}
	
esttab m*, label se starlevels(* 0.10 ** 0.05 *** 0.01)  ///
b(a2) keep(_T2k__2k) ///
nonotes addnotes("All models contain census tract FE") ///
mtitles("Beds" "Baths" "Pool" "Garage" "Sq. Ft." "Yr. Blt.") ///
stats(mean, label("Dep. var. mean"))

esttab  m* using "$ddir/output/pdd_sample_diffs_2k.tex", replace se starlevels(* 0.10 ** 0.05 *** 0.01)  ///
keep(_T2k__2k) label ///
b(a2) nonotes booktabs ///
mtitles("Beds" "Baths" "Pool" "Garage" "Sq. Ft." "Yr. Blt.") ///
stats(mean, label("Mean"))

estimates clear
eststo clear

local i = `i' + 1
foreach v of varlist bedrooms rbaths _Xpool _Xgarage sa_sqft sa_yr_blt {
	summ `v'
	sca def mean`v' = r(mean)
	areg `v' _T1k_bin_1000 _T1k_bin_2000, absorb(census_tract)
		estimates store m`i'
		estadd scalar mean = mean`v'
	local i = `i' + 1
	}

esttab m*, label se starlevels(* 0.10 ** 0.05 *** 0.01)  ///
b(a2) keep(_T1k_bin_1000 _T1k_bin_2000) ///
nonotes addnotes("All models contain census tract FE") ///
mtitles("Beds" "Baths" "Pool" "Garage" "Sq. Ft." "Yr. Blt.") ///
stats(mean, label("Dep. var. mean"))

esttab  m* using "$ddir/output/pdd_sample_diffs_1k.tex", replace se starlevels(* 0.10 ** 0.05 *** 0.01)  ///
keep(_T1k_bin_1000 _T1k_bin_2000)  label ///
b(a2) nonotes booktabs stats(mean, label("Mean")) ///
mtitles("Beds" "Baths" "Pool" "Garage" "Sq. Ft." "Yr. Blt.")

* Counts by bin
label def binlbl 1000 "0-1000" 2000 "1000-2000" 9999 "2000-4000", replace
label val bin1k binlbl

replace period = "Post-crash" if period == "PostCrash"
replace period = "Post-exp." if period == "PostExp"
replace period = "Post-letter" if period == "PostLetter"

tabout period bin1k using "$ddir/output/pdd_sample_freq.tex", ///
	cells(freq) format(0c) clab(_ _ _) replace ///
	style(tex) bt font(bold) topstr(10cm) ///
	topf($adir/code/top.tex) botf($adir/code/bot.tex)

* T-test
/* COMPARISON OF PROJECT CHARACTERISTICS */
global vlist price bedrooms rbaths _Xpool _Xgarage sa_sqft distress_dummy
global rnames "Sale Price" "Bedrooms" "Baths" "Pool" "Garage" "Sq. Ft." "Distress"

*COMPARE 1000k to 2000k to 2000-4000k using t-test and Todd's table code
quietly{
gen tgroup = bin1k

local I : list sizeof global(vlist)
mat T = J(`I',7,.)

local i = 0
foreach v of varlist $vlist {
	local i = `i' + 1
	ttest `v' if tgroup != 2000, by(tgroup)
	mat T[`i',1] = r(mu_2)
	mat T[`i',2] = r(mu_1)
	mat T[`i',3] = r(mu_1) - r(mu_2)
	mat T[`i',4] = r(p)
	ttest `v' if tgroup != 1000, by(tgroup)
	mat T[`i',5] = r(mu_1)
	mat T[`i',6] = r(mu_1) - r(mu_2)
	mat T[`i',7] = r(p)
}

mat rownames T = "$rnames"
}

frmttable using "$ddir/output/pdd_ttests.tex", statmat(T) varlabels replace ///
	ctitle("", "> 2000" , 0-1000 , Diff., "(p-val)",1000-2000, Diff., "(p-val)") ///
    hlines(11{0}1) spacebef(1{0}1) frag tex ///
	sdec(0,0,0,3,0,0,3 \ 1,1,1,3,1,1,3 \ 1,1,1,3,1,1,3 \ 2,2,2,3,2,2,3 \ 2,2,2,3,2,2,3 \ 0,0,0,3,0,0,3 \ ///
         2,2,2,3,2,2,3)


capture log close
exit


