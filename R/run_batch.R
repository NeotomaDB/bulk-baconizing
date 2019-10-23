#' @title Run Bacon on a set of sites
#' @param x A data frame of parameters.
#' @param settings The global settings for the analysis.

run_batch <- function(x, settings, limit = nrow(x), offset = 1){

  check_params(x)

  x_out <- x

  if (!settings$parallel == FALSE) {
    # Currently not implemented
    cores <- parallel::detectCores()
    max_cores <- min(settings$parallel, cores, na.rm = TRUE)
  }

  for (i in offset:limit) {

    done_run <- (!is.na(x$success[i])  & x$success[i] == TRUE) &
                (!is.na(x$run[i])  & x$run[i] == TRUE)
    is_okay  <- !is.na(x$suitable[i]) & x$suitable[i] == TRUE

    if (done_run) {
      message(paste0(x$handle[i], " has already been run. Skipping.\n"))
      next
    }

    if (!is_okay) {
      message(paste0(x$handle[i], " is not suitable for reconstruction. Skipping.\n"))
      next
    }

    if (is.na(x$thick[i])) {
      message(paste0(x$handle[i], " has no preferred thickness in the parameter file. Skipping.\n"))
      next
    }

    # This fails in linux if libgsl.so.0 cannot be found.  To fix this I ran:
    # > sudo find . -name "libgsl.so"
    # This provided the path to libgsl.so
    # Then, I created a simlink:
    # sudo ln ./usr/lib/x86_64-linux-gnu/libgsl.so
    # ./usr/lib/x86_64-linux-gnu/libgsl.so.0
    # This allows things to work.

    if (is_okay) {
      run_out <- try(call_bacon(x[i, ], settings))

      if (!"try-error" %in% class(run_out)) {
        x_out[i, ] <- run_out

      } else {
        x_out$success[i] <- FALSE
        x_out$run[i] <- TRUE
        x_out$notes[i] <- add_msg(x_out$notes[i], "Bacon run attempted and failed.")
      }

      readr::write_csv(x = data.frame(notes = strsplit(x_out$notes[i], split = ";")),
        path = paste0(settings$core_path, "/", x_out$handle[i],
                             "/", x_out$handle[i], "_notes.csv"))
      readr::write_csv(x = x_out,
                    path = paste0("data/params/bacon_params_v",
                                   settings$version, "_temp.csv"))
      cat("...\n")
    }
  }

  return(x_out)
}
