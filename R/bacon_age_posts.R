#' @title Get age posteriors
#' @description Using the output files from Bacon get the full posterior at depths.
#' @param handle The site handle.

bacon_age_posts <- function(handle, settings) {

  depth_file <- paste0(settings$core_path, "/",
                       handle, "/", handle, "_depths.txt")

  settings_file <- paste0(settings$core_path, "/",
     handle, "/", handle, "_settings.txt")

  out_files <- list.files(paste0(settings$core_path, "/", handle),
                          pattern = ".out$",
                          full.names = TRUE)

  assertthat::assert_that(length(out_files) > 0,
    msg = list.files(paste0(settings$core_path, "/", handle)))

  depth <- suppressMessages(readr::read_csv(depth_file,
                                            col_names = FALSE)) %>%
    as.data.frame()

  bacon_settings <- suppressMessages(readr::read_csv(settings_file,
                                    col_names = FALSE, comment = "#")) %>%
    as.data.frame()

  if (length(out_files) > 1) {
    message("Multiple Bacon output files exist.")
  }

  for (k in 1:length(out_files)) {

    outer <- suppressMessages(readr::read_delim(out_files[k],
                               col_names = FALSE, delim = " ")) %>%
      as.data.frame

    # We can do this match because we know how Bacon writes out files.
    sections <- stringr::str_match(out_files[k], "(?:_)([0-9]*)\\.")[2] %>%
      as.numeric()

    if (ncol(outer) == (sections + 3)) {
      posteriors <- matrix(NA, nrow = nrow(depth), ncol = nrow(outer))

      for (j in 1:nrow(outer)) {
        x <- seq(from = bacon_settings[1, 1],
                 to = bacon_settings[2, 1],
                 length.out = sections + 1)
        y <- c(outer[j, 1],
               outer[j, 1] +
                 cumsum( ( diff(x) * outer[j, 2:(ncol(outer) - 2)]) %>%
                                                 as.numeric))
        posteriors[, j] <- bacon_extrap(x,
                                        y = y,
                                        xout = depth %>% unlist())
      }

      posterior_file <- paste0(settings$core_path, "/",
         handle, "/", handle, "_", sections, "_posteriorout.csv")

      readr::write_csv(posterior_file,
                       x = as.data.frame(posteriors))
    }

  }
  if (length(out_files) == 1) {
    return(as.data.frame(posteriors))
  }

}
