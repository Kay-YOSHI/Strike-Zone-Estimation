#--------------------------------------------------------------------------------#
# Strike Zone Estimation
#--------------------------------------------------------------------------------#

#----------------------------------------------------------
# Data Acquisition
#----------------------------------------------------------

# Call packages
library(mlbr)
library(stringr)

# Statcast pitch-by-pitch data on all regular season games in 2019
# - 731,784 obs.
mlb2019 = sc_pbp(start_date = "2019-03-28", end_date = "2019-09-29") 

# Remove missing values for plate_x, plate_z, sz_bot, and sz_top
mlb = 
  mlb2019 %>% 
  subset(!(is.na(plate_x))) %>% 
  subset(!(is.na(plate_z))) %>% 
  subset(!(is.na(sz_bot))) %>% 
  subset(!(is.na(sz_top)))

#----------------------------------------------------------
# 0. Pitch distribution conditional on not swinging
#----------------------------------------------------------

# Random seed
set.seed(1)

# Preparation & Random sampling
dist = 
  mlb %>% 
  filter(pitch_type == "FF") %>% 
  filter(description == "called_strike" | description == "ball" | description == "blocked_ball" | description == "pitchout") %>% 
  mutate(code = ifelse(description == "called_strike", "Called Strike", "Ball")) %>% 
  mutate(code2 = as.factor(ifelse(description == "called_strike", 1, -1))) %>% 
  sample_n(10000) 

# Rulebook strike zone 
# ※Upper and lower bound of strike zone are average across hitters.
plate_width = (17 + 2 * (9 / pi)) / 12 # Home plate: 17 inches, ball: 9 inches (1 inch = 1/12 feet)
xm = c(-(plate_width / 2), plate_width / 2, plate_width / 2, -(plate_width / 2), -(plate_width / 2))
zm = c(mean(dist$sz_bot), mean(dist$sz_bot), mean(dist$sz_top), mean(dist$sz_top), mean(dist$sz_bot))
sz_mlb = tibble(xm, zm)

# Visualization
pdist = 
  ggplot(dist, aes(x = plate_x, y = plate_z)) + 
  geom_point(aes(color = code), alpha = 1.0) + 
  geom_path(data = sz_mlb, aes(x = xm, y = zm), linejoin = "round", size = 2) + 
  coord_equal() + 
  scale_x_continuous("Horizontal location (ft.)", limits = c(-2.0, 2.0)) + 
  scale_y_continuous("Vertical location (ft.)", limits = c(0.0, 5.0)) + 
  scale_color_manual(values = c("green", "red")) + 
  labs(title = "Pitch distribution conditional on not swinging", subtitle = "(Randomly sampled 10,000 observations)", caption = "*Catcher's perspective.") + 
  theme_bw() + 
  theme(title = element_text(size = 15)) + 
  theme(axis.title.x = element_text(size = 15, colour = "black")) + 
  theme(axis.title.y = element_text(size = 15, colour = "black")) + 
  theme(axis.text.x = element_text(size = 10, colour = "black")) + 
  theme(axis.text.y = element_text(size = 10, colour = "black")) + 
  theme(legend.title=element_blank()) + 
  theme(legend.position = "bottom") + 
  theme(legend.text=element_text(size = 15))

#----------------------------------------------------------
# 1. Estimating strike zone by local polynomial regression
#----------------------------------------------------------

# Call libraries
library(mgcv)
library(splancs)

# Fit a smooth polynomial surface
# CAUTION: It takes too much time to estimate using whole observations.
strike_mod = loess(code == "Called Strike" ~ plate_x + plate_z, data = dist, control = loess.control(surface = "direct"))

# Construct a grid
mx = seq(-2.0, 2.0, by = 0.01)
my = seq(0, 5, by = 0.01)
pred_area = expand.grid(plate_x = mx, plate_z = my)

# Called strike probability predictions across the entire grid
pred_area_fit_lpr = 
  pred_area %>% 
  mutate(fit_lpr = as.numeric(predict(strike_mod, newdata = .))) 

# Visualization
pred_area_fit_lpr2 = pred_area_fit_lpr %>% filter(0 <= fit_lpr & fit_lpr <= 1) # For logical consistency
Szone_lpr = 
  # Contour plot
  ggplot(pred_area_fit_lpr2, aes(x = plate_x, y = plate_z)) + 
  stat_contour(aes(z = fit_lpr), color = "black", size = 1.0, breaks = 0.5) + 
  scale_color_gradient(low = "black", high = "black") + 
  # Strike zone
  geom_path(data = sz_mlb, aes(x = xm, y = zm), linejoin = "round", linetype = "dashed") + 
  coord_equal() + 
  scale_x_continuous("Horizontal location (ft.)", limits = c(-2.0, 2.0)) + 
  scale_y_continuous("Vertical location (ft.)", limits = c(0.0, 5.0)) + 
  labs(title = "Estimated strike zone", subtitle = "(By local polynomial regression)", caption = "*Catcher's perspective.") + 
  theme_bw() + 
  theme(title = element_text(size = 15)) + 
  theme(axis.title.x = element_text(size = 15, colour = "black")) + 
  theme(axis.title.y = element_text(size = 15, colour = "black")) + 
  theme(axis.text.x = element_text(size = 10, colour = "black")) + 
  theme(axis.text.y = element_text(size = 10, colour = "black")) + 
  theme(legend.position = "none") 

# Compute the contour areas
#----------------------------------------------------------

# Obtain x and y coordinates of 50% contour line
clines.lpr = contourLines(x = mx, y = my, array(pred_area_fit_lpr$fit_lpr, dim = c(length(mx), length(my))), nlevels = 1, levels = 0.5)

# Compute the area (sq. in.) inside 50% contour line
area50.lpr = round(with(clines.lpr[[1]], areapl(cbind(12 * x, 12 * y))), 3)

#----------------------------------------------------------
# 2. Estimating strike zone by Support Vector Machine
#----------------------------------------------------------

# Call libraries
library(kernlab)

# SVM
ksvmfit = ksvm(code2 ~ plate_x + plate_z, data = dist, kernel = "rbfdot", type = "C-svc", C = 1, cross = 10)

# Predictions across the entire grid
fit_svm = as.numeric(predict(ksvmfit, pred_area)) - 1
pred_area_fit_svm = cbind(pred_area, fit_svm)

# Plot decision boundary
Szone_svm = 
  ggplot(pred_area_fit_svm, aes(x = plate_x, y = plate_z)) + 
  stat_contour(aes(z = fit_svm), color = "black", size = 1.0, breaks = 0.5) + 
  geom_path(data = sz_mlb, aes(x = xm, y = zm), linejoin = "round", linetype = "dashed") + 
  coord_equal() + 
  scale_x_continuous("Horizontal location (ft.)", limits = c(-2.0, 2.0)) + 
  scale_y_continuous("Vertical location (ft.)", limits = c(0.0, 5.0)) + 
  labs(title = "Estimated strike zone", subtitle = "(By Support Vector Machine)", caption = "*Catcher's perspective.") + 
  theme_bw() + 
  theme(title = element_text(size = 15)) + 
  theme(axis.title.x = element_text(size = 15, colour = "black")) + 
  theme(axis.title.y = element_text(size = 15, colour = "black")) + 
  theme(axis.text.x = element_text(size = 10, colour = "black")) + 
  theme(axis.text.y = element_text(size = 10, colour = "black")) + 
  theme(legend.title=element_blank()) + 
  theme(legend.position = "bottom") + 
  theme(legend.text=element_text(size = 15))

# Compute the contour areas
#----------------------------------------------------------

# Obtain x and y coordinates of 50% contour line
clines.svm = contourLines(x = mx, y = my, array(pred_area_fit_svm$fit_svm, dim = c(length(mx), length(my))), nlevels = 1, levels = 0.5)

# Compute the area (sq. in.) inside 50% contour line
area50.svm = round(with(clines.svm[[1]], areapl(cbind(12 * x, 12 * y))), 3)

#----------------------------------------------------------
# Estimated strike zone 
#----------------------------------------------------------

# Call libraries
library(patchwork)

# Visualization
pdist + Szone_lpr + Szone_svm

#----------------------------------------------------------
# 3. Strike zone by B-S count
#----------------------------------------------------------

# Preparation
dat = 
  mlb %>% 
  filter(pitch_type == "FF") %>% 
  filter(description == "called_strike" | description == "ball" | description == "blocked_ball" | description == "pitchout") %>% 
  mutate(code = as.factor(ifelse(description == "called_strike", 1, -1))) %>% 
  mutate(count = paste(balls, strikes, sep = "-"))

# Observation when B-S count is 0-0
count00 = dat %>% filter(count == "0-0") %>% sample_n(10000) 
count02 = dat %>% filter(count == "0-2") 
count30 = dat %>% filter(count == "3-0") 

# Height of the rulebook strike zone (averaged across counts)
sz_bots = c(count00$sz_bot, count02$sz_bot, count30$sz_bot)
sz_tops = c(count00$sz_top, count02$sz_top, count30$sz_top)
zm2 = c(mean(sz_bots), mean(sz_bots), mean(sz_tops), mean(sz_tops), mean(sz_bots))
sz_mlb2 = tibble(xm, zm2)

# SVM
ksvmfit00 = ksvm(code ~ plate_x + plate_z, data = count00, kernel = "rbfdot", type = "C-svc", C = 1, cross = 10)
ksvmfit02 = ksvm(code ~ plate_x + plate_z, data = count02, kernel = "rbfdot", type = "C-svc", C = 1, cross = 10)
ksvmfit30 = ksvm(code ~ plate_x + plate_z, data = count30, kernel = "rbfdot", type = "C-svc", C = 1, cross = 10)

# Predictions across the entire grid
fit00 = as.numeric(predict(ksvmfit00, pred_area)) - 1
fit02 = as.numeric(predict(ksvmfit02, pred_area)) - 1
fit30 = as.numeric(predict(ksvmfit30, pred_area)) - 1
predictions = cbind(pred_area, fit00, fit02, fit30) 
predictions2 = predictions %>% gather(count, value, -plate_x, -plate_z)

# Plot decision boundaries
ggplot(predictions2) + 
  stat_contour(aes(x = plate_x, y = plate_z, z = value, colour = count), size = 1.0, breaks = 0.5) + 
  geom_path(data = sz_mlb2, aes(x = xm, y = zm2), linejoin = "round", linetype = "dashed") + 
  coord_equal() + 
  scale_x_continuous("Horizontal location (ft.)", limits = c(-2.0, 2.0)) + 
  scale_y_continuous("Vertical location (ft.)", limits = c(0.0, 5.0)) + 
  labs(title = "Estimated strike zone by B-S count", subtitle = "(By Support Vector Machine)", caption = "*Catcher's perspective.") + 
  theme_bw() + 
  theme(title = element_text(size = 15)) + 
  theme(axis.title.x = element_text(size = 15, colour = "black")) + 
  theme(axis.title.y = element_text(size = 15, colour = "black")) + 
  theme(axis.text.x = element_text(size = 10, colour = "black")) + 
  theme(axis.text.y = element_text(size = 10, colour = "black")) + 
  theme(legend.position = "bottom") + 
  theme(legend.text=element_text(size = 15)) + 
  scale_color_discrete(name = "Count", labels = c("0-0", "0-2", "3-0"))

# Compute the contour areas
#----------------------------------------------------------

# Obtain x and y coordinates of 50% contour line
clines00 = contourLines(x = mx, y = my, array(predictions$fit00, dim = c(length(mx), length(my))), nlevels = 1, levels = 0.5)
clines02 = contourLines(x = mx, y = my, array(predictions$fit02, dim = c(length(mx), length(my))), nlevels = 1, levels = 0.5)
clines30 = contourLines(x = mx, y = my, array(predictions$fit30, dim = c(length(mx), length(my))), nlevels = 1, levels = 0.5)

# Compute the area (sq. in.) inside 50% contour line
area00 = round(with(clines00[[1]], areapl(cbind(12 * x, 12 * y))), 3)
area02 = round(with(clines02[[1]], areapl(cbind(12 * x, 12 * y))), 3)
area30 = round(with(clines30[[1]], areapl(cbind(12 * x, 12 * y))), 3)
