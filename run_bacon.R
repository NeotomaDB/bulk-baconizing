### Clean Bacon Run:

library(rbacon)
library(neotoma)
library(maps)
library(fields)
library(raster)
library(rgdal)
library(dplyr)
library(lubridate)
library(httr)
library(jsonlite)
library(rgdal)

source('R/make_coredf.R')
source('R/load_pollen.R')
source('R/add_msg.R')
source('R/call_bacon.R')
source('R/run_batch.R')
source('R/helpers.R')
source('R/bacon_age_posts.R')




#  This set of code is to assist with versioning locally.
setup <- FALSE     # Set to TRUE if you want to download all new sites.
params <- TRUE    # Set to TRUE if you want to regenerate the params file.
version <- 7
my_date <- lubridate::round_date(lubridate::now("UTC"), unit="day")
corepath <- 'Cores'

# Define using state names here, but basically can be a change in the
# parameters passed to get_dataset.
domain = c('Minnesota', 'Wisconsin', 'Michigan')

# Some cores have varves, but I think I fix that elsewhere.
varves = read.csv('data/varves.csv', stringsAsFactors=FALSE)

dl <- get_dataset(datasettype='pollen',
                  gpid = domain,
                  ageyoung=0)

pol <- load_pollen(dl, version = version, setup = setup)

if (!file.exists(paste0('data/params/bacon_params_v', version, '.csv')) | params == TRUE) {
  params <- data.frame(handle = sapply(dl, function(x) { x$dataset.meta$collection.handle }),
                       datasetid = as.integer(sapply(dl, function(x) { x$dataset.meta$dataset.id })),
                       acc.mean.mod = 3.02,
                       acc.mean.old = 15.,
                       acc.shape.mod = 0.53,
                       acc.shape.old = 0.9,
                       mem.strength = 2.,
                       mem.mean = 0.5,
                       hiatus = as.numeric(NA),
                       thick = 5.,
                       age.type = as.character(NA),
                       run = FALSE,
                       suitable = NA,
                       ndates = as.integer(NA),
                       success = NA,
                       notes = ".",
                       stringsAsFactors = FALSE)

  readr::write_csv(x = params,
                   path = paste0('data/params/bacon_params_v', version, '.csv'))
} else {
  params <- readr::read_csv(paste0('data/params/bacon_params_v', version, '.csv'),
                            col_types = paste0(c('c','i', rep('n',8),'c', 'l','l','i','l','c'), collapse=''))
}

sites <- sapply(dl, function(x) { x$dataset.meta$dataset.id })

#  Check that the parameters table is up to date.
assertthat::assert_that(all(sites %in% params$datasetid),
                        msg = "Not all of the downloaded sites are in your parameters table.  Make sure your parameters table is up to date.")

assertthat::assert_that(all(params$datasetid %in% sites),
                        msg = "Not all of the sites in your parameters table are in your existing site list.  Make sure your site query reflects your site list.")

ageorder <- get_table('agetypes')

for (i in 1:length(sites)) {

  # Write each age file:

  url <- paste0('http://api-dev.neotomadb.org/v2.0/data/datasets/', sites[i], '/chronology')
  chrons <- jsonlite::fromJSON(url, simplifyVector=FALSE)$data[[1]]

  modeldefault <- chrons$chronologies %>%
    purrr::map(function(x){ data.frame(agetype = x$agetype, default = x$isdefault, stringsAsFactors = FALSE) }) %>%
    bind_rows()

  modeldefault$order <- ageorder$Precedence[match(modeldefault$agetype, ageorder$AgeType)]

  if (sum(modeldefault$order == min(modeldefault$order) & modeldefault$default) == 1) {
    # This is the case that everything is good.
    # The precendene is the lowest and it has only one defined default for that low model.
  } else {
    if (sum(modeldefault$order == min(modeldefault$order) & modeldefault$default) > 1) {
      # There are multiple default models in the best age class:

      message('There are multiple default models defined for the "best" age type.')

      most_recent <- sapply(chrons$chronologies, function(x) {
        ifelse(is.null(x$dateprepared), 0, lubridate::as_date(x$dateprepared))
      })

      new_default <- most_recent == max(most_recent) &
        modeldefault$default &
        modeldefault$order == min(modeldefault$order)

      if (sum(new_default) == 1) {
        # Date of model preparation differs:
        params$notes[i] <- add_msg(params$notes[i], 'There are multiple default models defined for the best age type: Default assigned to most recent model')
        modeldefault$default <- new_default
      } else {
        # Date is the same, differentiate by chronology ID:
        chronid <- sapply(chrons$chronologies, function(x) x$chronologyid)

        modeldefault$default <- new_default &
          max_chron == max(chronid)

        params$notes[i] <- add_msg(params$notes[i], 'There are multiple default models defined for the best age type: Default assigned to most model with highest chronologyid')
      }
    } else {
      # Here there is no default defined:
      if (sum(modeldefault$order == min(modeldefault$order)) == 1) {
        # No default defined, but only one best age scale:
        modeldefault$default <- modeldefault$order == min(modeldefault$order)
        params$notes[i] <- add_msg(params$notes[i], 'There are no default models defined for the best age type: Default assigned to best age-type by precedence.')
      } else {
        # There is no default and multple age models for the "best" type:
        most_recent <- sapply(chrons$chronologies, function(x) {
          ifelse(is.null(x$dateprepared), 0, lubridate::as_date(x$dateprepared))})

        new_default <- most_recent == max(most_recent) &
          modeldefault$order == min(modeldefault$order)

        if (sum(new_default) == 1) {
          modeldefault$default <- new_default
          params$notes[i] <- add_msg(params$notes[i], 'There are no default models defined for the best age type: Most recently generated model chosen')
        } else {
          chronid <- sapply(chrons$chronologies, function(x) x$chronologyid)
          new_default <- most_recent == max(most_recent) &
            modeldefault$order == min(modeldefault$order) &
            chronid == max(chronid)
          modeldefault$default <- new_default
          params$notes[i] <- add_msg(params$notes[i], 'There are no default models defined for the best age type: Age models have same preparation date.  Model with highest chron ID was selected')
        }
      }
    }
  }


  # Back into analysis:

  good_row <- (1:nrow(modeldefault))[modeldefault$order == min(modeldefault$order) & modeldefault$default]

  params$age.type[i] <- modeldefault$agetype[good_row]

  handle <- dl[[as.character(sites[i])]]$dataset.meta$collection.handle
  depths <- data.frame(depths = pol[[as.character(sites[i])]]$sample.meta$depth)
  ages <- data.frame(ages = pol[[as.character(sites[i])]]$sample.meta$age)

  agetypes <- sapply(chrons[[2]], function(x) x$agetype)

  if ('Varve years BP' %in% agetypes) {
    if (length(list.files(corepath)) == 0 | !handle %in% list.files(corepath)) {
      works <- dir.create(path = paste0(corepath, '/', handle))
      assertthat::assert_that(works, msg = 'Could not create the directory.')
    }

    if (all(depths == ages)) {
      ages <- data.frame( labid = "Annual laminations",
                         age = ages,
                         error = 0,
                         depth = depths,
                         cc = 0,
                         stringsAsFactors = FALSE)
      message('Annual laminations defined in the age models.')
      params$notes[i] <- add_msg(params$notes[i], 'Annual laminations defined in the age models.')
    } else {
      message('Annual laminations defined in the age models but ages and depths not aligned.')
      params$notes[i] <- add_msg(params$notes[i], 'Annual laminations defined as an age model but ages and depths not aligned.')
    }

  } else {
    out <- try(make_coredf(chrons[[2]][[good_row]],
                            corename = handle,
                            params = params))

    if (!'try-error' %in% class(ages)) {
      ages <- out[[1]]
      params <- out[[2]]

      params$ndates[i] <- nrow(ages)

      readr::write_csv(x = params,
                       path = paste0('data/params/bacon_params_v', version, '.csv'))

      readr::write_csv(x = ages, path = paste0('Cores/', handle, '/', handle, '.csv'), col_names = TRUE)
      readr::write_csv(x = depths, path = paste0('Cores/', handle, '/', handle, '_depths.txt'), col_names = FALSE)
    } else {
      params$notes[i] <- add_msg(params$notes[i], 'Error processing the age file.')
    }
  }
}

readr::write_csv(x = params, path = paste0('data/params/bacon_params_v', version, '.csv'))

run_batch(params)
