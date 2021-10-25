# Strike-Zone-Estimation

This repository contains R code for estimating strike zone in Major League Baseball (MLB). 
I used the statcast pitch-by-pitch data on all regular season games in 2019, collected by using the R package "mlbr" (https://github.com/pontsuyu/mlbr). 

In Strike_Zone_Poly.R, 
I estimated called strike probability by fitting a smooth polynomial surface to dummy variable indicating called strike or ball 
as a function of the horizontal and vertical locations. 
Then, I visualized it by contour plot.
I also estimated the called strike probability by B-S count and compare the 50% contour lines between count 0-2 and 3-0. 
The resulting figure shows that the strike zone drastically shrinks in 0-2 count and expands in 3-0 count.

## References

Marchi, M., Albert, J. and Baumer, B. S.: "Analyzing Baseball Data with R (2nd ed.)," Chapman and Hall/CRC (2018)

James, G., Witten, D., Hastie, T. and Tibshirani, R.: "An Introduction to Statistical Learning with Applications in R," Springer Science+Business Media, New York (2013)

Green, E. and Daniels, D.: "Bayesian Instinct," Available at SSRN: https://ssrn.com/abstract=2916929 (2021)
