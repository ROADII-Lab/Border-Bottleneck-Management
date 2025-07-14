library(data.table)
library(ggplot2)

in_dt <- fread("./code/Border-Bottleneck-Management/support_scripts/captured_coords/data_download_export_07112025_1200.csv")

# remove the nonnumeric characters from the confidence
in_dt[, confidence := as.numeric(gsub("tensor\\(", "", gsub("\\)", "", confidence)))]

# these got much better with persist = True on
plot(in_dt$id, in_dt$confidence)
plot(in_dt$timestamp, in_dt$confidence)

head(in_dt)

ggplot(in_dt, aes(x = timestamp, y = 1000-cy, color = id)) +
  geom_point()

# ok i need help with this frame skipping thing
# but generally the math I would want to do is...

#classify lane
in_dt[, lane := ifelse(cx < 400, "out_of_bounds", 
                       ifelse(cx < 940, "left_two", 
                              ifelse(cx < 1100, "middle",
                                     ifelse(cx < 1450, "right", "out_of_bounds"))))]

# classify movement forward
in_dt[, forward := ifelse(cy > 960, "early", 
                          ifelse(cy > 590, "in_zone", "past_25m_segment"))]

# what's the current run length I pulled
print(paste0(in_dt[, max(timestamp)/1000], " seconds"))

# let's take a peek at that
ggplot(in_dt, aes(x = cx, y = 1000-cy, color = forward)) +
  geom_point()

# let's visualize the first id location of all vehicles in this pull
in_dt[, first_id := min(timestamp), .(id)] # dropped class for sample rate
first_ids_dt <- in_dt[timestamp == first_id]
# ids are first recognized at almost any point in the frame
ggplot(first_ids_dt, aes(x = cx, y = 1080-cy, color = forward)) +
  labs(x = "X Pixel Location", y = "Y Pixel Location", color = "Position relative to benchmark") +
  geom_point() +
  theme_light() +
  theme(legend.position = "bottom")

# # lane identifications are consistent...
# dcast.data.table(in_dt, id ~ lane)
# # this video chunk didn't have much forward movement, but seems to like... work
# dcast.data.table(in_dt, id ~ forward)

# get earliest timestamp in zone
in_dt[, earliest_in_subsection := min(timestamp), .(id, forward)] # dropped class for sample rate
highlights_dt <- in_dt[timestamp == earliest_in_subsection]

# maybe we would also want to keep a count of how many times that object was identified as a sort 
# of sanity check, have some kind of threshold for the confidence levels...
wide_vehicle_timestamps <- dcast.data.table(highlights_dt, id + lane + first_id ~ forward, value.var = "earliest_in_subsection") #dropped class for sample rate

# it would have to be a vehicle that: started out in "early", wasn't out of bounds, made it eventually to "past 25 meter segment"
# then just scale this time to the length of the bridge which is about 400 meters
wide_vehicle_timestamps[!is.na(early) & lane != "out_of_bounds", sec_to_span_25m := (past_25m_segment - in_zone) / 1000 ]
wide_vehicle_timestamps[, time_to_cross := sec_to_span_25m* 400/25] #400 meter long crossing, 25 meter measurement

# ids are first recognized at almost any point in the frame
ggplot(first_ids_dt[id %in% wide_vehicle_timestamps[!is.na(time_to_cross)]$id], aes(x = cx, y = 1080-cy, color = forward)) +
  labs(x = "X Pixel Location", y = "Y Pixel Location", color = "Position relative to benchmark") +
  geom_point()

# our sample rate in the end: 3.4% with class included, 5% with class excluded
wide_vehicle_timestamps[!is.na(time_to_cross), .N]/wide_vehicle_timestamps[, .N]
wide_vehicle_timestamps[, mean(time_to_cross, na.rm = T), lane]
wide_vehicle_timestamps[, sum(!is.na(time_to_cross)), lane]


# let's visualize the functional sample -- just the earlier times
ggplot(in_dt[timestamp < 2200000 & id %in% wide_vehicle_timestamps[!is.na(time_to_cross)]$id], aes(x = timestamp, y = 1080-cy, color = lane)) +
  geom_point()
# to see how the lane classification is working
ggplot(in_dt[id %in% wide_vehicle_timestamps[!is.na(time_to_cross)]$id], aes(x = cx, y = 1080-cy, color = lane)) +
  geom_point()

# colored by individual ids
ggplot(in_dt[id %in% wide_vehicle_timestamps[!is.na(time_to_cross) & past_25m_segment < 1200000]$id], aes(x = cx, y = 1080-cy, color = as.factor(id))) +
  geom_point() +
  theme(
    legend.position = "none"
  ) +
  labs(x = "X Pixel Location", y = "Y Pixel Location", color = "Position relative to benchmark") +
  geom_point() +
  theme_light() +
  theme(legend.position = "none")

# and non functional sample
ggplot(in_dt[timestamp < 100000 & lane != "out_of_bounds" &! id %in% wide_vehicle_timestamps[!is.na(time_to_cross)]$id], aes(x = cx, y = 1080-cy, color = as.factor(id))) +
  geom_point() +
  theme(
    legend.position = "none"
  )
