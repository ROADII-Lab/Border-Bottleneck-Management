library(data.table)
library(ggplot2)

in_dt <- fread("./code/Border-Bottleneck-Management/support_scripts/captured_coords/data_download_export_07112025_1017.csv")

# remove the nonnumeric characters from the confidence
in_dt[, confidence := as.numeric(gsub("tensor\\(", "", gsub("\\)", "", confidence)))]

# these got much better with persist = True on
plot(in_dt$id, in_dt$confidence)
plot(in_dt$timestamp, in_dt$confidence)

head(in_dt)

ggplot(in_dt, aes(x = timestamp, y = 1000-cy, color = id)) +
  geom_point()

# ok i need help with this frame skipping thing
# but generally the math I would want to do

#classify lane
in_dt[, lane := ifelse(cx < 400, "out_of_bounds", 
                       ifelse(cx < 940, "left_two", 
                              ifelse(cx < 1100, "middle",
                                     ifelse(cx < 1450, "right", "out_of_bounds"))))]

# classify movement forward
in_dt[, forward := ifelse(cy > 960, "early", 
                          ifelse(cy > 590, "in_zone", "past_25m_segment"))]

# what's the current run length
in_dt[, max(timestamp)/1000]

# let's take a peek at that
ggplot(in_dt[timestamp < 50000], aes(x = cx, y = cy, color = forward)) +
  geom_point()
# lane identifications are consistent...
dcast.data.table(in_dt, id ~ lane)
# this video chunk didn't have much forward movement, but seems to like... work
dcast.data.table(in_dt, id ~ forward)

# get earliest timestamp in zone
in_dt[, earliest_in_subsection := min(timestamp), .(id, class, forward)]
highlights_dt <- in_dt[timestamp == earliest_in_subsection]

# maybe we would also want to keep a count of how many times that object was identified as a sort 
# of sanity check, have some kind of threshold for the confidence levels...
wide_vehicle_timestamps <- dcast.data.table(highlights_dt, id + class + lane ~ forward, value.var = "earliest_in_subsection")
wide_vehicle_timestamps[, sec_to_span_25m := (past_25m_segment - in_zone) / 1000 ]

# it would have to be a vehicle that: started out in "early", wasn't out of bounds, made it eventually to "past 25 meter segment"
# then just scale this time to the length of the bridge which is about 400 meters