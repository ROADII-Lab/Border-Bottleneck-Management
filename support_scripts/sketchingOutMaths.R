library(data.table)
library(ggplot2)

in_dt <- fread("./code/Border-Bottleneck-Management/support_scripts/captured_coords/data_download_export_07102025_1648.csv")

# remove the nonnumeric characters from the confidence
in_dt[, confidence := as.numeric(gsub("tensor\\(", "", gsub("\\)", "", confidence)))]

# these got much better with persist = True on
plot(in_dt$id, in_dt$confidence)
plot(in_dt$timestamp, in_dt$confidence)

head(in_dt)

#anyway... ok yeah, so we can see that no one identification of a vehicle ever got that far
# remember, we're trying to track from 590 to 980 on the y scale to cover those 25 meters
single_id <- 3
ggplot(in_dt[id == single_id], aes(x = timestamp, y = cy)) +
  geom_point()

ggplot(in_dt[timestamp < 50000], aes(x = timestamp, y = cy, color = id)) +
  geom_point()

# ok i need help with this frame skipping thing
# but generally the math I would want to do

#classify lane
in_dt[, lane := ifelse(cx < 400, "out of bounds", 
                       ifelse(cx < 940, "left two", 
                              ifelse(cx < 1100, "middle",
                                     ifelse(cx < 1450, "right", "out of bounds"))))]
# classify movement forward
in_dt[, forward := ifelse(cy > 960, "early", 
                          ifelse(cy > 590, "in zone", "past 25m segment"))]

# let's take a peek at that
ggplot(in_dt[timestamp < 50000], aes(x = cx, y = cy, color = forward)) +
  geom_point()
# lane identifications are consistent...
dcast.data.table(in_dt, id ~ lane)
# this video chunk didn't have much forward movement, but seems to like... work
dcast.data.table(in_dt, id ~ forward)

