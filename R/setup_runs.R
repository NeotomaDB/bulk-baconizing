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
library(parallel, quietly = TRUE)
library(evaluate, quietly = TRUE)
library(htmltools, quietly = TRUE)
library(DT, quietly = TRUE)

run_files <- list.files("R", pattern = ".R$", full.names = TRUE)

run_all <- sapply(run_files, function(x) {
    if (!x == "R/setup_runs.R") source(file = x)
  })

settings <- yaml::read_yaml("settings.yaml")

if (!settings$core_path %in% list.dirs()) {
  dir.create(settings$core_path)
  message("User defined core directory did not exist.  Generating directory.")
}

if (settings$clean_run == TRUE) {
  if (length(list.files(settings$core_path)) > 1) {
    message("A clean run is expected but files for older runs exist
      in your core path.") %>% strwrap()
  }
}

if (settings$date == "today") {
  settings$date <- lubridate::round_date(lubridate::now("UTC"), unit = "day")
} else {
  settings$date <- lubridate::as_date(settings$date)
}
