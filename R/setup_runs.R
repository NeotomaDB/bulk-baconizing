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

source('R/make_coredf.R')
source('R/load_pollen.R')
source('R/add_msg.R')
source('R/call_bacon.R')
source('R/run_batch.R')
source('R/helpers.R')
source('R/bacon_age_posts.R')

settings <- yaml::read_yaml('settings.yaml')

if (settings$date == 'today') {
  settings$date <- lubridate::round_date(lubridate::now("UTC"), unit="day")
} else {
  settings$date <- lubridate::as_date(settings$date)
}
