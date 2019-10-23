#' @title Add accumulation parameters from an existing file.
#' @param x
#' @param id_col
#' @param accum_col
#' @param parameters

add_accumulation <- function(file, id_col = 1, accum_col = 2, parameters, verbose = TRUE) {

  accum_list <- readr::read_csv(file) %>% as.data.frame
  accumulations <- data.frame(ids = accum_list[,id_col],
                            accum = accum_list[,accum_col])

  assertthat::assert_that(is.numeric(accumulations$ids),
                          msg = "The dataset ID column for the thickness file is not numeric.")
  assertthat::assert_that(is.numeric(accumulations$accum),
                          msg = "The accumulation column for the accumulation file is not numeric.")

  assertthat::assert_that(any(accumulations$ids %in% parameters$datasetid),
                          msg = "None of the dataset ids in the accumulation file are in the parameter file.")

  accumulations <- accumulations %>%
    filter(ids %in% parameters$datasetid &
           accum %in% parameters$acc.shape.old)
  updates <- accumulations %>%
    filter(ids %in% parameters$datasetid)

  if (verbose) {

    message(paste0("Modifying ",
                   nrow(changed),
                   " records to update thicknesses. ",
                   nrow(updates), " records already changed."))
  }

  param_rows <- match(accumulations$ids, params$datasetid)

  parameters$acc.shape.old[param_rows] <- accumulations$accum

  parameters$notes[param_rows] <- add_msg(parameters$notes[param_rows],
                                          'Accumulation adjusted based on prior work.')

  return(parameters)

}
