#' @title Add thickness parameters from an existing file.
#' @param x
#' @param id_col
#' @param thick_col
#' @param parameters
#'
add_thickness <- function(file, id_col = 1, thick_col = 2, parameters, verbose = TRUE) {

  thick_list <- readr::read_csv(file) %>% as.data.frame
  thicknesses <- data.frame(ids = thick_list[,id_col],
                            thick = thick_list[,thick_col])

  assertthat::assert_that(is.numeric(thicknesses$ids),
                          msg = "The dataset ID column for the thickness file is not numeric.")
  assertthat::assert_that(is.numeric(thicknesses$thick),
                          msg = "The thickness column for the thickness file is not numeric.")

  if(!any(thicknesses$ids %in% parameters$datasetid)) {
    message('None of the dataset ids in the thickness file are in the parameter file.')
  }

  thicknesses <- thicknesses %>%
    filter(ids %in% parameters$datasetid & thick %in% parameters$thick)

  if (verbose) {
    message(paste0("Modifying ", nrow(thicknesses), " records to update thicknesses."))
  }

  param_rows <- match(thicknesses$ids, params$datasetid)

  parameters$thick[param_rows] <- thicknesses$thick

  parameters$notes[param_rows] <- add_msg(parameters$notes[param_rows],
                                          'Thickness adjusted based on prior work.')

  return(parameters)

}
