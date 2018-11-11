#' @title Get age posteriors
#' @description Using the output files from Bacon get the full posterior at depths.
#' @param handle The site handle.
#'

bacon_age_posts <- function(handle)
{
  
  out_files <- list.files(paste0('Cores/', handle),
                          pattern = ".out$",
                          full.names = TRUE)

  assertthat::assert_that(length(out_files) > 0, msg = list.files(paste0('Cores/', handle)))
  
  depth <- readr::read_csv(paste0('Cores/', handle, '/', handle, '_depths.txt'),
                           col_names = FALSE) %>%
    as.data.frame()

  bacon_settings <- readr::read_csv(paste0('Cores/', handle, '/', handle, '_settings.txt'),
                                    col_names = FALSE, comment = '#') %>% as.data.frame


  if (length(out_files) > 1) {
    message('Multiple Bacon output files exist.')
  }

  for (k in 1:length(out_files)) {
    cat(paste0(out_files, '\n'))
    cat(k)
    outer <- readr::read_delim(out_files[k], col_names = FALSE,delim = ' ') %>% as.data.frame

    # We can do this match because we know how Bacon writes out files.
    sections <- stringr::str_match(out_files[k], '(?:_)([0-9]*)\\.')[2] %>%
      as.numeric()

    if (ncol(outer) == (sections + 3)) {
      priors <- matrix(NA, nrow = nrow(depth), ncol = nrow(outer))

      for(j in 1:nrow(outer)) {
        x <- seq(bacon_settings[1,1], bacon_settings[2,1], length.out = sections + 1)
        y <- c(outer[j,1], outer[j,1] + cumsum((diff(x) * outer[j,2:(ncol(outer) - 2)]) %>% 
                                                 as.numeric))
        priors[,j] <- approx(x, y, xout = depth %>% unlist())$y
      }
      readr::write_csv(paste0('Cores/', handle, '/', handle, '_', sections, '_priorout.csv'), 
                       x = as.data.frame(priors))
    }

  }
}
