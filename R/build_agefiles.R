#' @title Build Bacon age-files
#' @description

build_agefiles <- function(param,
                           datasets,
                           downloads,
                           ageorder = NULL,
                           settings,
                           verbose = TRUE) {

  parm <- param

  age_file <- paste0(settings$core_path, "/", param$handle,
    "/", param$handle, ".csv")
  depth_file <- paste0(settings$core_path, "/", param$handle,
    "/", param$handle, "_depths.txt")

  if (!(is.na(param$suitable) | param$suitable == 1) &
     param$suitable == 1 &
     file.exists(age_file) &
     file.exists(depth_file)) {
    if (verbose == TRUE) {
      message(paste0("Bacon core and depths files have already ",
       "been written.  Set `suitable` to NA to rewrite files."))
    }
    return(param)
  }

  if (is.null(ageorder)) {
    ageorder <- neotoma::get_table("agetypes")
  }

  url <- paste0("http://api-dev.neotomadb.org/v2.0/data/datasets/",
    param$datasetid, "/chronology")

  chrons <- jsonlite::fromJSON(url, simplifyVector = FALSE)$data[[1]]

  modeldefault <- chrons$chronologies %>%
    purrr::map(function (x) {
      data.frame(agetype = x$agetype,
                 default = x$isdefault,
                 stringsAsFactors = FALSE)
               }) %>%
    bind_rows()

  type_match <- match(modeldefault$agetype, ageorder$AgeType)

  modeldefault$order <- ageorder$Precedence[type_match]

  if (sum(modeldefault$order == min(modeldefault$order) &
      modeldefault$default) == 1) {
    # This is the case that everything is good.
    # The precendence is the lowest and it has only one defined
    #  default for that low model.
  } else {
    if (sum(modeldefault$order == min(modeldefault$order) &
        modeldefault$default) > 1) {
      # There are multiple default models in the best age class:

      message("There are multiple default models defined for the best age type.")

      most_recent <- sapply(chrons$chronologies, function(x) {
        ifelse(is.null(x$dateprepared), 0, lubridate::as_date(x$dateprepared))
      })

      new_default <- most_recent == max(most_recent) &
        modeldefault$default &
        modeldefault$order == min(modeldefault$order)

      if (sum(new_default) == 1) {
        # Date of model preparation differs:
        param$notes <- add_msg(param$notes,
          paste0("There are multiple default models defined for the ",
            "best age type: Default assigned to most recent model"))
        modeldefault$default <- new_default
      } else {
        # Date is the same, differentiate by chronology ID:
        chronid <- sapply(chrons$chronologies, function(x) x$chronologyid)

        modeldefault$default <- new_default &
          max_chron == max(chronid)

        param$notes <- add_msg(param$notes,
          paste0("There are multiple default models defined for the ",
            "best age type: Default assigned to most model with ",
            "highest chronologyid"))
      }
    } else {
      # Here there is no default defined:
      if (sum(modeldefault$order == min(modeldefault$order)) == 1) {
        # No default defined, but only one best age scale:
        modeldefault$default <- modeldefault$order == min(modeldefault$order)
        param$notes <- add_msg(param$notes, "There are no default models defined for the best age type: Default assigned to best age-type by precedence.")
      } else {
        # There is no default and multple age models for the "best" type:
        most_recent <- sapply(chrons$chronologies, function(x) {
          ifelse(is.null(x$dateprepared), 0, lubridate::as_date(x$dateprepared))})

        new_default <- most_recent == max(most_recent) &
          modeldefault$order == min(modeldefault$order)

        if (sum(new_default) == 1) {
          modeldefault$default <- new_default
          param$notes <- add_msg(param$notes, "There are no default models defined for the best age type: Most recently generated model chosen")
        } else {

          # You are the default if you have the highest chronology id.
          chronid <- sapply(chrons$chronologies, function(x) x$chronologyid)

          new_default <- most_recent == max(most_recent) &
            modeldefault$order == min(modeldefault$order) &
            chronid == max(chronid)

          modeldefault$default <- new_default
          param$notes <- add_msg(param$notes, "There are no default models defined for the best age type: Age models have same preparation date.  Model with highest chron ID was selected")
        }
      }
    }
  }

  good_row <- (1:nrow(modeldefault))[modeldefault$order == min(modeldefault$order) & modeldefault$default]

  param$age.type <- modeldefault$agetype[good_row]

  did_char <- as.character(param$datasetid)

  handle   <- datasets[[did_char]]$dataset.meta$collection.handle
  depths   <- data.frame(depths = downloads[[did_char]]$sample.meta$depth)
  ages     <- data.frame(ages = downloads[[did_char]]$sample.meta$age)

  agetypes <- sapply(chrons[[2]], function(x) x$agetype)

  ## Here we check to see if we're dealing with varved data:

  if ("Varve years BP" %in% agetypes) {

    if (length(list.files(settings$core_path)) == 0 |
        !handle %in% list.files(settings$core_path)) {
      works <- dir.create(path = paste0(settings$core_path, "/", handle))
      assertthat::assert_that(works, msg = "Could not create the directory.")
    }

    if (all(depths == ages)) {
      #  It's not clear what's happening here,
      #  but we identify the records for further investigation.
      ages <- data.frame(labid = "Annual laminations",
                           age = ages,
                         error = 0,
                         depth = depths,
                            cc = 0,
              stringsAsFactors = FALSE)
      if (verbose == TRUE) {
        message("Annual laminations defined in the age models.")
      }

      param$notes <- add_msg(param$notes, "Annual laminations defined in the age models.")
      param$suitable <- 1

      readr::write_csv(x = ages,
        path = paste0("Cores/", handle, "/", handle, ".csv"),
        col_names = TRUE)
      readr::write_csv(x = depths,
        path = paste0("Cores/", handle, "/", handle, "_depths.txt"),
        col_names = FALSE)

    } else {

      if (verbose == TRUE) {
        message("Annual laminations defined in the age models but ages and depths not aligned.")
      }
      param$notes <- add_msg(param$notes,
        "Annual laminations defined as an age model but ages and depths not aligned.")
      param$suitable <- 0
    }

  } else {
    co_depths <- sapply(chrons[[2]][[good_row]]$controls, function(x) x$depth)
    ages <-   sapply(chrons[[2]][[good_row]]$controls, function(x) x$age)
    types <-  sapply(chrons[[2]][[good_row]]$controls, function(x) x$chroncontroltype)

    if("list" %in% class(co_depths)) { co_depths <- unlist(co_depths) }

    if (any(types == "Core top")) {
      age_top <- ages[which(types == "Core top")]
      if (length(age_top) == 0) {
          param$core_top <- NA
      } else {
          param$core_top <- age_top
      }
    } else {
      if (!is.na(param$core_top)){
        age_top <- param$core_top
      } else if (any(co_depths < 2)) {
        min_depth <- min(co_depths[co_depths >= 0 & co_depths < 2])
        age_top <- ages[which(co_depths == min_depth)]
        if (any(types == "Lead-210")) {
          param$notes <- add_msg(param$notes, paste0("No core top assigned in core but lead210 used. Core top assigned to sample at depth ", min_depth))
        } else {
          param$notes <- add_msg(param$notes, paste0("No core top assigned in core but a depth/age seems to relate. Core top assigned to sample at depth ", min_depth))
        }
        param$core_top <- ages[which(co_depths == min_depth)]
      } else {
        age_top <- NA
        param$core_top <- NA
      }
    }
    cat(param$handle, '\n')
    cat("  *\t", unlist(age_top), "\n")
    out <- try(make_coredf(x = chrons[[2]][[good_row]],
                           core_param = param,
                           settings = settings,
                           core_top = age_top))

    if (!"try-error" %in% class(out)) {
      ages <- out[[1]]
      param <- out[[2]]

      param$ndates <- nrow(ages)

      if (file.exists(age_file)) {
        param$notes <- add_msg(param$notes, "Overwrote prior chronology file.")
      }

      readr::write_csv(x = ages, path = age_file, col_names = TRUE)
      readr::write_csv(x = as.data.frame(depths), path = depth_file, col_names = FALSE)

    } else {
      param$notes <- add_msg(param$notes, "Error processing the age file.")
    }
  }

  if (is.null(unlist(param$core_top))) { param$core_top <- NA }

  if(all(unlist(apply(param, 2, class)) == "list")) {
    param <- unlist(param)
  }

  return(param)
}
