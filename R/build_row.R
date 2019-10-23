#' @title build_row
#' @description Takes a chronology element from Neotoma and returns a single row for the Bacon chronology.
#' @param z A \code{list} element from a Neotoma chronology object.

build_row <- function(z) {

  test_empty <- function(x) {
    # Make sure that NULLs in JSON are returned as NA.
    ifelse(is.null(x) | (length(x) == 0), NA, x)
  }

  uncal <- c("Radiocarbon", "Radiocarbon, reservoir correction",
             "Radiocarbon, average of two or more dates", "Carbon-14")

  z$age <- test_empty(z$age)
  z$thickness <- test_empty(z$thickness)
  z$agelimityounger <- test_empty(z$agelimityounger)
  z$agelimitolder <- test_empty(z$agelimitolder)

  if (is.null(unlist(z$geochron))) {
    # There is no 'geochron' data, then there is only a non-radiometric date.

    if (is.null(z$depth)) {
      # No geochronological data and there's no depth.  Weird. . .
      out <- data.frame(labid = stringr::str_replace_all(z$chroncontroltype,
        ",", "_"),
                        age = test_empty(z$age),
                        error = abs(test_empty(z$age) - test_empty(z$agelimityounger)),
                        depth = NA,
                        cc = ifelse(z$chroncontroltype %in% uncal,
                                    1, 0),
                        stringsAsFactors = FALSE)
      core_param$notes <- add_msg(core_param$notes,
                                  "A (non-geochronological) chronological control was missing a depth.  Assigned NA")

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

    # Lead210 data is dealt with in our paper.  There are a set of records
    # where we seem to have 210-Pb records, but they don't have geochron records.
    # For these we need to make sure the ages are in the appropriate time scale.
    if (z$chroncontroltype == "Lead-210" & z$age > 500) {
      z$age <- 1950 - z$age
      core_param$notes <- add_msg(core_param$notes,
                                  "A 210Pb age had an assigned age greater than 500ybp: Assumed age scale incorrect.")
    }

    if (z$chroncontroltype == "Lead-210" &
        (is.na(z$agelimitolder) |
         (z$agelimityounger == z$age))
       ) {
      age <- c(10, 100, 150)
      error <- log10(c(1.5, 15, 85))
      model <- lm(error ~ age)

      age_err <- z$age - core_param$core_top

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

    # Make sure everything is in the right time scale.
    if (z$geochron$agetype == "Calendar years AD/BC") {
      z$geochron$age <- 1950 - z$geochron$age
    }

    # Do the age error regression for the Lead-210 ages.
    if (z$geochron$geochrontype == "Lead-210" &
        (is.na(test_empty(z$geochron$errorolder)) |
         (test_empty(z$geochron$erroryounger) == z$age))
       ) {
      age <- c(10, 100, 150)
      error <- log10(c(1.5, 15, 85))
      model <- lm(error ~ age)

      age_err <- z$geochron$age - as.numeric(param$core_top)

      z$geochron$errorolder <-   ceiling(10^predict(model, newdata = data.frame(age = age_err))) %>% unlist
      z$geochron$erroryounger <- ceiling(10^predict(model, newdata = data.frame(age = age_err))) %>% unlist

      core_param$notes <- add_msg(core_param$notes,
                                  "A 210Pb age had no error assigned.  Used the Binford estimator to assign uncertainty.")

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
      ",", "_"),
                      age = z$geochron$age,
                      error = z$geochron$errorolder,
                      depth = ifelse(is.null(z$depth),
                                     NA,
                                     z$depth),
                      cc = ifelse(z$geochron$geochrontype %in% uncal, 1, 0),
                      stringsAsFactors = FALSE)
  }
  return(out)
}
