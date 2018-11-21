library(dplyr)

call_bacon <- function(site_params, settings) {

  bacon_chrons <- paste0(settings$core_path, '/', site_params$handle,
                         "/", site_params$handle, ".csv")
  bacon_depths <- paste0(settings$core_path, '/', site_params$handle,
                        "/", site_params$handle, "_depths.txt")

  # check for suitability
  if (site_params$suitable == 1) {
    if (is.na(site_params$success) | (!site_params$success == 1)) {

      if (!(file.exists(bacon_chrons) &  file.exists(bacon_depths))) {
        message("Files needed for Bacon do not exist.")
        site_params$run <- 0
        site_params$success <- 0
        return(site_params)
      }

      # find hiatus depth
      geochron <- suppressMessages(readr::read_csv(bacon_chrons))

      sett_layer <- stringr::str_detect(geochron$labid, "sett")

      if (any(sett_layer) & nrow(geochron) >
        2) {

        # determine which bacon parameters to input if preset is the last sample
        if (which(sett_layer) == nrow(geochron)) {
          hiatus.depth <- NA
          acc.mean.val <- site_params$acc.mean.mod
          acc.shape.val <- site_params$acc.shape.mod
          site_params$hiatus <- 0
        } else if (which(sett_layer) == 1) {
          # if preset is the first sample
          hiatus.depth <- NA
          acc.mean.val <- site_params$acc.mean.old
          acc.shape.val <- site_params$acc.shape.old
          site_params$hiatus <- 0
        } else {
          hiatus.depth <- geochron$depth[sett_layer]
          acc.mean.val <- c(site_params$acc.mean.mod, site_params$acc.mean.old)
          acc.shape.val <- c(site_params$acc.shape.mod, site_params$acc.shape.old)
          site_params$hiatus <- 1
        }

      } else if (any(sett_layer) & nrow(geochron) ==
        2) {
        # if preset and only two geochron samples, use modern priors
        hiatus.depth <- NA
        acc.mean.val <- site_params$acc.mean.mod
        acc.shape.val <- site_params$acc.shape.mod
        site_params$hiatus <- 0
      } else if (!any(sett_layer)) {
        # if no preset then use historical priors
        hiatus.depth <- NA
        acc.mean.val <- site_params$acc.mean.old
        acc.shape.val <- site_params$acc.shape.old
        site_params$hiatus <- 0
      }

      out <- try(Bacon(core = site_params$handle, coredir = settings$core_path,
        acc.mean = acc.mean.val, acc.shape = acc.shape.val,
        mem.strength = site_params$mem.strength,
        mem.mean = site_params$mem.mean,
        thick = site_params$thick, ask = FALSE,
        suggest = FALSE, depths.file = TRUE,
        hiatus.max = 10, hiatus.depths = hiatus.depth))

      if (!(class(out) == "try-error")) {
        site_params$run <- 1
        agetest <- try(agedepth(set = out))

        if ("try-error" %in% class(agetest)) {

          site_params$success <- 0
          site_params$notes <- add_msg(site_params$notes,
            "Core failed in Bacon plotting.")
        } else {
          # This function generates the posterior estimates for the record.
          outputs <- bacon_age_posts(site_params$handle)
          site_params$success <- 1
          test_outs <- outputs %>% na.omit()
          site_params$reliableold <- quantile(test_outs[nrow(test_outs),
          ], 0.33, na.rm = TRUE)
          site_params$reliableyoung <- quantile(test_outs[1, ],
            0.66, na.rm = TRUE)
        }

      } else {
        site_params$notes <- add_msg(site_params$notes,
          "Core failed in Bacon run.")
        site_params$run <- 1
        site_params$success <- 0

      }
    }
  } else {
    site_params$success = 0
  }

  return(site_params)
}
