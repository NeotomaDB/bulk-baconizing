#' @title Run Bacon on a set of sites
#' @param x A data frame of parameters.

run_batch <- function(x, settings){

  check_params(x)

  if(!settings$parallel == FALSE) {

    cores <- parallel::detectCores()
    max_cores <- min(settings$parallel, cores, na.rm=TRUE)

  }

  x_out <- lapply(1:nrow(x), function(i, x, settings){

    if ((!is.na(x$success[i])) & x$success[i] == 1) {
      message(paste0(x$handle, ' has already been run. Skipping.\n'))
      return(x[i,])
    }
    if (is.na(x$thick[i])) { return(x[i,]) }

    # This fails in linux if libgsl.so.0 cannot be found.  To fix this I ran:
    # > sudo find . -name "libgsl.so"
    # This provided the path to libgsl.so
    # Then, I created a simlink:
    # sudo ln ./usr/lib/x86_64-linux-gnu/libgsl.so ./usr/lib/x86_64-linux-gnu/libgsl.so.0
    # This allows things to work.

    if (!is.na(x$suitable[i]) & x$suitable[i] == 1) {
      run_out <- try(call_bacon(x[i,]))

      if (!'try-error' %in% class(run_out)) {
        x[i,] <- run_out

      } else {
        x$success[i] <- 0
        x$run[i] <- 1
        x$notes[i] <- add_msg(x$notes[i], "Bacon run attempted and failed.")
      }

      readr::write_csv(x = x,
                       path = paste0('data/params/bacon_params_v', settings$version, '.csv'))
    }
    return(x[i,])
  }, x = x, settings = settings)

  x_out <- do.call(rbind.data.frame, x_out)

  x[match(x_out$datasetid), ] <- x_out

  return(x)
}
