make_coredf <- function(x, settings, core_param) {

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

  build_row <- function(z) {
    if (is.null(unlist(z$geochron))) {
      # There is no 'geochron' data:
      if (is.null(z$depth)) {
        out <- data.frame(labid = stringr::str_replace_all(z$chroncontroltype,
          ",", "_"), age = z$age, error = abs(z$age - z$agelimityounger),
          depth = NA, cc = ifelse(z$chroncontroltype %in% uncal, 1,
          0), stringsAsFactors = FALSE)

          return(out)
      }
      if (is.null(z$age) & z$chroncontroltype == "Core top") {
        core_param$notes <- add_msg(core_param$notes,
          "A chroncontrol was missing an age.  Assigned -60.")
        z$age <- -60
      }
      if (is.null(z$ageyounger)) {
        core_param$notes <- add_msg(core_param$notes,
          paste0("A chroncontrol was missing an age range ",
          " (ageyounger, ageolder).  Assigned 0."))

        z$agelimityounger <- 0
        z$agelimitolder <- 0
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

      # Lead210 data is dealt with in our paper:
      if (z$geochron$geochrontype == "Lead-210" & z$geochron$age > 500) {
        z$geochron$age <- 1950 - z$geochron$age
        core_param$notes <- add_msg(core_param$notes,
          "A 210Pb age had an assigned age greater than 500ybp: Assumed age scale incorrect.")
      }

      # Lead210 data is dealt with in our paper:
      if (z$geochron$geochrontype == "Lead-210" & is.null(z$geochron$errorolder)) {
        age <- c(10, 100, 150)
        error <- c(1.5, 15, 85)
        model <- lm(log(error) ~ age)

        z$geochron$errorolder <- predict(model, newdata = data.frame(age = z$geochron$age)) %>%
          exp
        core_param$notes <- add_msg(core_param$notes,
          "A 210Pb age had no error assigned.  Used the Binford estimator to assign uncertainty.")

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

  if (!is.null(settings$settlement) & exists(settings$settlement)) {
    # Reassign settlement ages if they are present:
    sett <- suppressMessages(readr::read_csv("data/expert_assessment.csv")) %>%
      filter(!is.na(pre1.d))

    if (core_param$handle %in% sett$handle) {

      sett_row <- which(sett$handle == core_param$handle)
      depth <- as.numeric(stringr::str_extract(sett$pre1.d[sett_row], "[0-9]*"))

      coord <- sett %>%
        filter(sett$handle == core_param$handle) %>%
        select(long, lat)

      state <- sett %>%
        filter(sett$handle == core_param$handle) %>%
        select(state)

      horizons <- c("Pre-EuroAmerican settlement horizon",
                    "European settlement horizon",
                     "Ambrosia rise")

      if (any(output$labid %in% horizons)) {

        geo_row <- which(output$labid %in% horizons)

        output$depth[geo_row] <- depth
        output$labid[geo_row] <- "Expert assigned settlement horizon"

        output$age[geo_row] <- 1950 - as.numeric(get_survey_year(coord, state))
        output$error[geo_row] <- 50
        core_param$notes <- add_msg(core_param$notes,
          "Adjusted settlement horizon based on expert elicitation.")

      } else {
        new_row <- data.frame(labid = "Expert assigned settlement horizon",
          age = 1950 - get_survey_year(coord, state), error = 50, depth = depth,
          cc = 0)
        output <- rbind(output, new_row)
        output <- output[order(output$depth), ]
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
