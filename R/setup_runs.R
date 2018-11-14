### Clean Bacon Run:

library(yaml, quietly = TRUE)
library(rbacon, quietly = TRUE)
library(neotoma, quietly = TRUE)
library(maps, quietly = TRUE)
library(fields, quietly = TRUE)
library(raster, quietly = TRUE)
library(rgdal, quietly = TRUE)
library(dplyr, quietly = TRUE)
library(lubridate, quietly = TRUE)
library(httr, quietly = TRUE)
library(jsonlite, quietly = TRUE)
library(rgdal, quietly = TRUE)
library(lubridate, quietly = TRUE)

run_files <- list.files('R', pattern = '.R$', full.names = TRUE)

run_all <- sapply(run_files, function(x) if(!x == 'R/setup_runs.R') source(file = x))

settings <- yaml::read_yaml('settings.yaml')

if (settings$date == 'today') {
  settings$date <- lubridate::round_date(lubridate::now("UTC"), unit="day")
} else {
  settings$date <- lubridate::as_date(settings$date)
}
