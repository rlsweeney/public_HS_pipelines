global fname tabs_n_figs_qtr

set more off
pause on
set matsize 10000
set seed 123456
set scheme s1color

*cap ssc install reghdfe
*cap ssc install estout
cap ssc install binscatter
cap ssc install parmest

global bdir "/home/sweeneri/Projects/Pipelines/build"
global adir "/home/sweeneri/Projects/Pipelines/analysis"
global Edir "${adir}/output/cross_section/estimates"
global ddir "/home/sweeneri/Projects/Pipelines/DraftFiles"

capture log close
log using "$ddir/output/logs/${fname}.txt", replace text
set linesize 255


cd "$adir/temp"

/*COMBINE ESTIMATES FROM DIFFERENT FILES TO CREATE TABLES */

*%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
* COMPARE DIFFERENT TIME FE'S WITH 2K BIN

use if random_id < 0.01 using $ddir/generated_data/dd_regdata, clear
*NEED TO REASSIGN LABELS FOR ESTOUT
capture drop _T* PGE
do $ddir/analysis/pdd_prep_distance_defs_qtr.do

summ qtr_group_exp if qtr_post_exp == 0
global eventm = r(mean)
global eventminus2 = $eventm - 2

*MAKE SAME FIGURE WITH 1k BINS

local files: dir "$Edir" files "pdd_PGE_xs_1k_qtr*.ster"

foreach file of local files {
    local model = subinstr("`file'","pdd_PGE_xs_1k_qtr_","",.)
    local model = subinstr("`model'",".ster","",.)
    di "`model'"

    eststo clear
    estimates clear
    estimates use "$Edir/`file'"
        parmest, saving(est_`model', replace)
}


foreach file of local files {
    local model = subinstr("`file'","pdd_PGE_xs_1k_qtr_","",.)
    local model = subinstr("`model'",".ster","",.)
	use est_`model', clear
	keep if regexm(parm,"_T1k_qtr_[0-9]+_[0-9]+")
	gen qtr = regexs(1) if regexm(parm,"_T1k_qtr_([0-9]+)_[0-9]+")
	gen bin = regexs(1) if regexm(parm,"_T1k_qtr_[0-9]+_([0-9]*)")
	destring qtr bin, replace

    replace qtr = qtr - $eventm
    expand 2 if qtr == 0, gen(minus1)
    replace qtr = -1 if minus1 == 1
	replace estimate = 0 if minus1 == 1
	replace stderr = 0 if minus1 == 1
    replace min95 = 0 if minus1 == 1
	replace max95 = 0 if minus1 == 1
	
	drop minus1
	gen days = (qtr + 0.5)*90

	summ min95
	local grmin = floor(r(min)/0.01)*0.01
	summ max95
	local grmax = ceil(r(max)/0.01)*0.01
	keep estimate stderr qtr days bin max95 min95
	
	reshape wide estimate max95 min95 stderr, i(qtr days) j(bin)
	
twoway (connected estimate1000 days, sort lcolor(green) ///
		xline(0, lcolor(gs8) lpattern(solid)) yline(0, lcolor(black)) ///
		xline(223 315, lcolor(black) lpattern(dash))) ///
		(connected estimate2000 days, sort lcolor(orange)) ///
		(line min951000 days, sort lcolor(green) lpattern(dash)) ///
		(line max951000 days, sort lcolor(green) lpattern(dash)) ///
		(line min952000 days, sort lcolor(orange) lpattern(dash)) ///
		(line max952000 days, sort lcolor(orange) lpattern(dash)), ///
		text(0.05 0 "San Bruno {&rarr}", place(w)) ///		
		text(0.05 269 "Letters mailed", place(c) box bcolor(white)) ///		
		xtitle("Midpoint of qtr, days since explosion") ///
		ytitle("Treatment effect, by 90-day windows") ///
		ylabel(-0.06(0.02)0.06) ///
		legend(label(1 "0-1000" ) label(2 "1000-2000") order(1 2))

	gr export "$ddir/output/PGE_xs_qtr_`model'.eps", as(eps) replace
*	gr export "$ddir/output/PGE_xs_qtr_`model'.png", as(png) replace

serrbar estimate1000 stderr1000 days, scale(1.96) yline(0, lcolor(gs8)) ///
		xline(0, lcolor(black) lpattern(solid)) xline(223 315, lcolor(black) lpattern(dash)) ///
		ylabel(`grmin'(0.02)`grmax') ///
		xtitle("Midpoint of qtr, days since explosion") ///
		ytitle("Treatment effect, by 30-day windows")
gr export "$ddir/output/PGE_xs_qtr_1000_`model'.eps", as(eps) replace
*gr export "$ddir/output/PGE_xs_qtr_1000_`model'.png", as(png) replace

serrbar estimate2000 stderr2000 days, scale(1.96) yline(0, lcolor(gs8)) ///
		xline(0, lcolor(black) lpattern(solid)) xline(223 315, lcolor(black) lpattern(dash)) ///
		ylabel(`grmin'(0.02)`grmax') ///
		xtitle("Midpoint of qtr, days since explosion") ///
		ytitle("Treatment effect, by 30-day windows")
gr export "$ddir/output/PGE_xs_qtr_2000_`model'.eps", as(eps) replace
*gr export "$ddir/output/PGE_xs_qtr_2000_`model'.png", as(png) replace		
	
}

exit, clear
