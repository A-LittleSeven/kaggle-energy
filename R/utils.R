##################
#Utility functions
##################

require(plyr)

plotLoad = function(rawLoadData, year, month, day) {
    indices = which(rawLoadData$year == year & rawLoadData$month == month & rawLoadData$day %in% day)
    x = rawLoadData[indices,]
    x.melt = melt(x, id.vars = 1:4)
    x.melt$zone_id = as.factor(x.melt$zone_id)
    ggplot(x.melt, aes(x=variable, y=value, group=zone_id, color=zone_id)) + geom_line()
}

#Transform raw data into fastVAR format
transform.fastVAR = function(rawLoadData, rawTempData) {
    load = data.frame(dlply(rawLoadData, .variables="zone_id", .fun = function(zone) {
        as.vector(t(zone[,-(1:4)]))
    }))
    temp = data.frame(dlply(rawTempData, .variables="station_id", .fun = function(station) {
        as.vector(t(station[,-(1:4)]))
    }))
    return (list(load = as.matrix(load), temp = as.matrix(temp)))
  }

deseason = function(mts) {
    if (!is.data.frame(mts) & !is.matrix(mts)) {
        y = stl(ts(mts, frequency=24), na.action=na.omit, s.window="periodic")
        seasonal = y$time.series[,1]
        remaining = apply(y$time.series[,-1], 1, sum)
        return (list(seasonal=seasonal, remaining=remaining))
    }
    else {
        decomp = apply(mts, 2, function(j) {
            j.ts = ts(j, frequency=24)
            y = stl(j.ts, na.action=na.omit, s.window="periodic")
            seasonal = y$time.series[,1]
            remaining = apply(y$time.series[,-1], 1, sum)
            return (list(seasonal=seasonal, remaining=remaining))
        })
        seasonal = do.call('rbind', lapply(decomp, function(i) i$seasonal))
        remaining = do.call('rbind', lapply(decomp, function(i) i$remaining))
        return (list(seasonal=seasonal, remaining=remaining))
    }
}

delete.weeks = function(data, k=4, delete.dates=NULL){
  # Remove weeks from raw data
  #
  # Either remove k random weeks or remove prespecified dates from
  # data formatted [station * date] x hour.
  #
  # Args:
  #   data: The raw data on which we will remove random weeks. Must
  #         have columns for year, month, and day.
  #   k: The number of weeks to be randomly removed. Defaults to 4.
  #   delete.dates: If the user specifies a vector of POSIXct dates
  #                 to be removed, these dates will be removed from
  #                 the data rather than any randomly selected weeks.
  #
  # Returns:
  #    data: The data with values for certain days / weeks turned into NA.
  random.weeks = function(start, end, k){
      # Randomly draw k Monday -> Sunday weeks between start and end.
    if(!is.POSIXct(start) || !is.POSIXct(end)){
      Error("Start and end dates must be in POSIXct format")
    }
    dates = seq(start, end, by='DSTday')
    days.of.week = format(dates, '%A')
    monday.indices <- which(days.of.week == 'Monday')
    sampled.mondays.ix <- sample(monday.indices, k)
    sampled.dates.ix <- sapply(sampled.mondays.ix, function(x){seq(x, x + 6)})
    sampled.dates <- dates[intersect(sampled.dates.ix, c(1:length(dates)))]
    return(list(dates=sampled.dates, ix=sampled.dates.ix))
  }

  require(lubridate)
  if(is.null(delete.dates)){
    dates = ymd(paste(data$year, data$month, data$day, sep='-'))
    start = min(dates)
    end = max(dates)
    weeks.dates = random.weeks(start, end, k)$dates
    data[dates %in% weeks.dates, -c(1, 2, 3, 4)] = NA
  } else {
    if(!is.POSIXct(delete.dates)){
      stop("Dates to delete must be in POSIXct format")
    }
    dates = ymd(paste(data$year, data$month, data$day, sep='-'),
      tz=tz(delete.dates))
    data[dates %in% delete.dates, -c(1, 2, 3, 4)] = NA
  }
  return(data)
}
