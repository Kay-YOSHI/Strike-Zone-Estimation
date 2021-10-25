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
temp1 = subset(mlb2019, !(is.na(mlb2019$plate_x)))
temp2 = subset(temp1, !(is.na(temp1$plate_z)))
temp3 = subset(temp2, !(is.na(temp2$sz_bot)))
mlb = subset(temp3, !(is.na(temp3$sz_top)))

#----------------------------------------------------------
# Pitch distribution conditional on not swinging
#----------------------------------------------------------

# Seed
set.seed(1)

# Preparation & Random sampling
dist = 
  mlb %>% 
  mutate(px = as.numeric(plate_x)) %>% 
  mutate(pz = as.numeric(plate_z)) %>% 
  filter(description == "called_strike" | description == "ball" | description == "blocked_ball" | description == "pitchout") %>% 
  mutate(code = ifelse(description == "called_strike", "Called Strike", "Ball")) %>% 
  sample_n(10000)

# Strike zone 
# ※Upper and lower bound of strike zone are average across hitters.
plate_width = (17 + 2 * (9 / pi)) / 12 # Home plate: 17 inches, ball: 9 inches (1 inch = 1/12 feet)
xm = c(-(plate_width / 2), plate_width / 2, plate_width / 2, -(plate_width / 2), -(plate_width / 2))
zm = c(mean(dist$sz_bot), mean(dist$sz_bot), mean(dist$sz_top), mean(dist$sz_top), mean(dist$sz_bot))
sz_mlb = tibble(xm, zm)

# Visualization
ggplot(dist, aes(x = plate_x, y = plate_z)) + 
  geom_point(aes(color = code)) + 
  geom_path(data = sz_mlb, aes(x = xm, y = zm), linejoin = "round", size = 1) + 
  coord_equal() + 
  scale_x_continuous("Horizontal location (ft.)", limits = c(-2.0, 2.0)) + 
  scale_y_continuous("Vertical location (ft.)", limits = c(0.0, 5.0)) + 
  labs(title = "Pitch distribution conditional on not swinging", caption = "*Randomly sampled 10,000 observations. Catcher's perspective.") + 
  theme_bw() + 
  theme(title = element_text(size = 12)) + 
  theme(axis.title.x = element_text(size = 15, colour = "black")) + 
  theme(axis.title.y = element_text(size = 15, colour = "black")) + 
  theme(axis.text.x = element_text(size = 10, colour = "black")) + 
  theme(axis.text.y = element_text(size = 10, colour = "black")) + 
  theme(legend.title=element_blank()) + 
  theme(legend.position = "bottom") + 
  theme(legend.text=element_text(size = 15))

# PART1: Estimate called strike probability
#----------------------------------------------------------

# Seed
set.seed(1)

# Call libraries
library(mgcv)
library(directlabels)

# Data for estimation
stprob = 
  mlb %>% 
  mutate(px = as.numeric(plate_x)) %>% 
  mutate(pz = as.numeric(plate_z)) %>% 
  filter(description == "called_strike" | description == "ball" | description == "blocked_ball" | description == "pitchout") %>% 
  mutate(code = ifelse(description == "called_strike", "Called Strike", "Ball")) %>% 
  sample_n(10000)

# Fit a smooth polynomial surface
# CAUTION: It takes too much time to estimate using whole observations.
strike_mod = loess(code == "Called Strike" ~ plate_x + plate_z, data = stprob, control = loess.control(surface = "direct"))

# Construct a grid
pred_area = expand.grid(plate_x = seq(-2.0, 2.0, by = 0.1), 
	                    plate_z = seq(0, 5, by = 0.1))

# Called strike probability predictions across the entire grid
pred_area_fit = 
  pred_area %>% 
  mutate(fit = as.numeric(predict(strike_mod, newdata = .))) %>% 
  filter(0 <= fit & fit <= 1) # For logical consistency

# Visualization
temp_plot = 
  # Contour plot
  ggplot(pred_area_fit, aes(x = plate_x, y = plate_z)) + 
  stat_contour(aes(z = fit, colour = ..level..), binwidth = 0.25) + 
  scale_color_gradient(low = "black", high = "red") + 
  # Strike zone
  geom_path(data = sz_mlb, aes(x = xm, y = zm), linejoin = "round", size = 1) + 
  coord_equal() + 
  scale_x_continuous("Horizontal location (ft.)", limits = c(-2.0, 2.0)) + 
  scale_y_continuous("Vertical location (ft.)", limits = c(0.0, 5.0)) + 
  labs(title = "Strike zone estimates", caption = "*Catcher's perspective.") + 
  theme_bw() + 
  theme(title = element_text(size = 15)) + 
  theme(axis.title.x = element_text(size = 15, colour = "black")) + 
  theme(axis.title.y = element_text(size = 15, colour = "black")) + 
  theme(axis.text.x = element_text(size = 10, colour = "black")) + 
  theme(axis.text.y = element_text(size = 10, colour = "black")) + 
  theme(legend.title=element_blank()) + 
  theme(legend.position = "bottom") + 
  theme(legend.text=element_text(size = 15))

# Labeling
cont_plot = 
  temp_plot %>%
  directlabels::direct.label(method = "bottom.pieces") 
cont_plot

# PART2: Estimate called strike probability by B-S count
#----------------------------------------------------------
# Comparing 50% contours between 0-2 and 3-0

# Data for estimation
stprob2 = 
  mlb %>% 
  mutate(px = as.numeric(plate_x)) %>% 
  mutate(pz = as.numeric(plate_z)) %>% 
  filter(description == "called_strike" | description == "ball" | description == "blocked_ball" | description == "pitchout") %>% 
  mutate(code = ifelse(description == "called_strike", "Called Strike", "Ball"))

# Consider 0-2 and 3-0 counts here
counts = c("0-2", "3-0")

# Split the data into data frames for each count specified above
count_dfs = 
  stprob2 %>% 
  mutate(count = paste(balls, strikes, sep = "-")) %>% 
  filter(count %in% counts) %>% 
  split(pull(., count)) 

# Iterate the process in PART1 (estimation & prediction) for each count
count_fits = 
  count_dfs %>% 
  map(~loess(code == "Called Strike" ~ plate_x + plate_z, data = ., control = loess.control(surface = "direct"))) %>% 
  map(predict, newdata = pred_area) %>% 
  map(~data.frame(fit = as.numeric(.))) %>% 
  map_df(bind_cols, pred_area, .id = "count") %>% 
  filter(0 <= fit & fit <= 1)

# Visualize 50% contour lines for count 0-2 and 3-0
pred_area_fit = pred_area_fit %>% mutate(count = "All") %>% select(count, fit, plate_x, plate_z)
comp = bind_rows(list(count_fits, pred_area_fit))
ggplot(comp) + 
  stat_contour(aes(x = plate_x, y = plate_z, z = fit, colour = count), binwidth = 0.5) + 
  #stat_contour(data = pred_area_fit, aes(x = plate_x, y = plate_z, z = fit), binwidth = 0.5, linetype = "dashed") + 
  geom_path(data = sz_mlb, aes(x = xm, y = zm), linejoin = "round", size = 1) + 
  coord_equal() + 
  scale_x_continuous("Horizontal location (ft.)", limits = c(-2.0, 2.0)) + 
  scale_y_continuous("Vertical location (ft.)", limits = c(0.0, 5.0)) + 
  labs(title = "Strike zone estimates", subtitle = "Comparison b/w count 0-2 and 3-0", caption = "*Catcher's perspective.") + 
  theme_bw() + 
  theme(title = element_text(size = 15)) + 
  theme(axis.title.x = element_text(size = 15, colour = "black")) + 
  theme(axis.title.y = element_text(size = 15, colour = "black")) + 
  theme(axis.text.x = element_text(size = 10, colour = "black")) + 
  theme(axis.text.y = element_text(size = 10, colour = "black")) + 
  theme(legend.title = element_blank()) + 
  theme(legend.position = "bottom") + 
  theme(legend.text = element_text(size = 15))

  

