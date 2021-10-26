# Strike-Zone-Estimation

This repository contains R code for estimating strike zone in Major League Baseball (MLB). 
I used the statcast pitch-by-pitch data on all regular season games in 2019, collected by using the R package "mlbr" (https://github.com/pontsuyu/mlbr). 

In Strike_Zone.R, 
I estimated called strike probability by fitting a smooth polynomial surface to dummy variable indicating called strike or ball 
as a function of the horizontal and vertical locations. 
Then, I visualized it by contour plot. 
In addition, 
I estimated the strike zone by Support Vector Machine and compared the result with the one from local polynomial regression.

## References

Marchi, M., Albert, J. and Baumer, B. S.: "Analyzing Baseball Data with R (2nd ed.)," Chapman and Hall/CRC (2018)

James, G., Witten, D., Hastie, T. and Tibshirani, R.: "An Introduction to Statistical Learning with Applications in R," Springer Science+Business Media, New York (2013)

Green, E. and Daniels, D.: "Bayesian Instinct," Available at SSRN: https://ssrn.com/abstract=2916929 (2021)

Mills, B.: "Expert Workers, Performance Standards, and On-the-Job Training: Evaluating Major League Baseball Umpires," Available at SSRN: https://ssrn.com/abstract=2478447 (2014)
