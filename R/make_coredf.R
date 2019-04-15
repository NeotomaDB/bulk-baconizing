make_coredf <- function(x, settings, core_param, core_top = NULL) {

  corepath <- settings$core_path

  assertthat::assert_that(file.exists(corepath),
    msg = "Core directory must exist.")

  if (length(list.files(corepath)) == 0 | !core_param$handle %in% list.files(corepath)) {
    works <- dir.create(path = paste0(corepath, "/", core_param$handle))
    assertthat::assert_that(works, msg = "Could not create the directory.")
  }

  uncal <- c("Radiocarbon", "Radiocarbon, reservoir correction",
             "Radiocarbon, average of two or more dates", "Carbon-14")

  assertthat::assert_that(length(x$controls) > 1,
    msg = "Core has fewer than two chron controls.")

  test_empty <- function(x) ifelse(is.null(x), NA, x)

  build_row <- function(z) {
    if (is.null(unlist(z$geochron))) {
      # There is no 'geochron' data:
      if (is.null(z$depth)) {
        out <- data.frame(labid = stringr::str_replace_all(z$chroncontroltype,
          ",", "_"),
          age = test_empty(z$age),
          error = abs(test_empty(z$age) - test_empty(z$agelimityounger)),
          depth = NA, cc = ifelse(z$chroncontroltype %in% uncal, 1,
          0), stringsAsFactors = FALSE)
        core_param$notes <- add_msg(core_param$notes,
                                    "A  (non-geochronological) chronological control was missing a depth.  Assigned NA")

          return(out)
      }
      if (is.null(z$age) & z$chroncontroltype == "Core top") {
        core_param$notes <- add_msg(core_param$notes,
          "The core top was missing a reported age.  Assigned -40.")
        z$age <- -40
      }
      if (is.null(z$agelimityounger) & z$chroncontroltype == "Core top") {
        core_param$notes <- add_msg(core_param$notes,
                                    paste0("Assigned uncertainty for core-top."))

        z$agelimityounger <- settings$core_top_err
        z$agelimitolder <- settings$core_top_err
      }
      if (is.null(z$agelimityounger)) {
        core_param$notes <- add_msg(core_param$notes,
          paste0("A (non-geochronological) chroncontrol was missing an age range ",
          " (ageyounger, ageolder).  Assigned 0."))

        z$agelimityounger <- 0
        z$agelimitolder <- 0
      }
      # Lead210 data is dealt with in our paper:
      if (z$chroncontroltype == "Lead-210" & z$age > 500) {
        z$age <- 1950 - z$age
        core_param$notes <- add_msg(core_param$notes,
                                    "A 210Pb age had an assigned age greater than 500ybp: Assumed age scale incorrect.")
      }
      # Lead210 data is dealt with in our paper:
      if (z$chroncontroltype == "Lead-210" & (is.null(z$agelimitolder) | (z$agelimityounger == z$age))) {
        age <- c(10, 100, 150)
        error <- log10(c(1.5, 15, 85))
        model <- lm(error ~ age)

        age_err <- z$age - core_top

        z$agelimitolder <-   ceiling(z$agelimitolder   + 10^predict(model, newdata = data.frame(age = age_err))) %>% unlist
        z$agelimityounger <- floor(z$agelimityounger - 10^predict(model, newdata = data.frame(age = age_err))) %>% unlist

        core_param$notes <- add_msg(core_param$notes,
                                    "A 210Pb age had no error assigned.  Used the Binford estimator to assign uncertainty.")

      }
      if (z$chroncontroltype %in% c("Deglaciation", "Interpolated",
            "Core bottom", "Extrapolated", "Guess")) {
        out <- data.frame(labid = NA, age = NA, error = NA, depth = NA, cc = NA,
          stringsAsFactors = FALSE)

        core_param$notes <- add_msg(core_param$notes,
          "Estimated age chroncontrol was dropped from the table of geochrons.")
      } else {
        out <- data.frame(labid = stringr::str_replace_all(z$chroncontroltype,
          ",", "_"), age = z$age, error = abs(z$age - z$agelimityounger),
          depth = z$depth, cc = ifelse(z$chroncontroltype %in% uncal, 1,
          0), stringsAsFactors = FALSE)
      }
    } else {
      # We're dealing with geochronological data:
      if (is.null(z$geochron$labnumber)) {
        core_param$notes <- add_msg(core_param$notes,
          "A geochronological element was missing a lab number.  Assigned: unassigned")
        z$geochron$labnumber <- "unassigned"
      }
      if (z$chroncontroltype == "Radiocarbon, average of two or more dates") {
        core_param$notes <- add_msg(core_param$notes,
          "A chroncontrol using several geochrons was used, but only one chroncontrol was reported.")
      }
      if (stringr::str_detect(z$chroncontroltype, "reservoir")) {
        if (x$agetype == "Radiocarbon years BP") {
          core_param$notes <- add_msg(core_param$notes,
            "A chroncontrol uses a reservoir correction, returning reservoir correction in 14C years.")
          out <- data.frame(labid = stringr::str_replace_all(z$chroncontroltype,
          ",", "_"), age = z$age, error = abs(z$age - z$agelimityounger),
          depth = z$depth, cc = 1, stringsAsFactors = FALSE)
          return(out)
        } else {
          core_param$notes <- add_msg(core_param$notes,
            paste0("A chroncontrol uses a reservoir correction, ",
                   "returning uncorrected 14C age (corrected age is also calibrated)."))
          core_param$suitable <- 0
        }
      }

      # There's no age element?
      if (is.null(z$geochron$age)) {
        z$geochron$age <- (z$agelimitolder + z$agelimityounger)/2
        core_param$notes <- add_msg(core_param$notes, "Geochronological age was NULL.  Assigned the midpoint of ages.")
      }


      if (is.null(z$geochron$errorolder)) {
        z$geochron$errorolder <- 0
        core_param$notes <- add_msg(core_param$notes,
          "No uncertainty assigned to the geochronological element. Assigned 0.")
      }

      # Made a decision here to modify the lead210 errors to 0.
      out <- data.frame(labid = stringr::str_replace_all(z$geochron$labnumber,
        ",", "_"), age = z$geochron$age, error = z$geochron$errorolder, depth = z$depth,
        cc = ifelse(z$geochron$geochrontype %in% uncal, 1, 0), stringsAsFactors = FALSE)
    }
    return(out)
  }

  output <- x$controls %>% purrr::map(build_row) %>% bind_rows() %>% na.omit()

  if (nrow(output) < 2) {
    core_param$notes <- add_msg(core_param$notes,
      "Only one age constraint exists for the record.")
  } else {

    too_fast <- diff(range(output$age))/diff(range(output$depth))

    if (too_fast > 50) {
      core_param$acc.mean.old <- 100
      core_param$notes <- add_msg(core_param$notes,
        "High accumulation rates for the core detected: Assigning default accumulation rate to 100.")
    }
  }

  if (!is.null(settings$settlement) & !file.exists(settings$settlement)) {
    stop("The user is requesting a settlement file that does not exist. Check your settings.yaml file.")
  }
  
  if (!is.null(settings$settlement) & file.exists(settings$settlement)) {
    # Reassign settlement ages if they are present:
    sett <- suppressMessages(readr::read_csv(settings$settlement)) %>%
      filter(!is.na(pre1.d))

    if (core_param$handle %in% sett$handle) {

      sett_row <- which(sett$handle == core_param$handle)
      depth <- as.numeric(stringr::str_extract(sett$pre1.d[sett_row], "[0-9]*"))

      coord <- sett %>%
        filter(sett$handle == core_param$handle) %>%
        dplyr::select(long, lat)

      state <- sett %>%
        filter(sett$handle == core_param$handle) %>%
        dplyr::select(state)

      horizons <- c("Pre-EuroAmerican settlement horizon",
                    "European settlement horizon",
                    "Ambrosia rise")

      if (any(output$labid %in% horizons)) {

        geo_row <- which(output$labid %in% horizons)

        output$depth[geo_row] <- depth
        output$labid[geo_row] <- "Expert assigned settlement horizon"

        output$age[geo_row] <- 1950 - as.numeric(get_survey_year(coord, state))
        output$error[geo_row] <- 50
        core_param$hiatus <- depth
        core_param$hiatus_age <- 1950 - get_survey_year(coord, state)
        core_param$notes <- add_msg(core_param$notes,
          "Adjusted settlement horizon based on expert elicitation.")

      } else {
        new_row <- data.frame(labid = "Expert assigned settlement horizon",
                              age = 1950 - get_survey_year(coord, state),
                              error = 50,
                              depth = depth,
                              cc = 0)
        output <- rbind(output, new_row)
        output <- output[order(output$depth), ]
        core_param$hiatus <- depth
        core_param$hiatus_age <- 1950 - get_survey_year(coord, state)
        core_param$notes <- add_msg(core_param$notes,
          "Added settlement horizon based on expert elicitation.")
      }
    }
  }

  if (nrow(output) > 1 & is.na(core_param$suitable)) {
    core_param$suitable <- 1
  }

  return(list(output, core_param))

}
