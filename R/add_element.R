#' @title Add thickness parameters from an existing file.
#' @param x
#' @param id_col
#' @param elem_col
#' @param parameters
#' 
add_element <- function(file, id_col = 1, elem_col = 2, modifier, parameters, verbose = TRUE) {
  
  element_list <- readr::read_csv(file) %>% as.data.frame
  element <- data.frame(ids = element_list[,id_col],
                        element = element_list[,thick_col])
  
  col_modified <- which(colnames(parameters) == modifier)
  
  assertthat::assert_that(is.numeric(element$ids),
                          msg = "The dataset ID column for the element file is not numeric.")
  assertthat::assert_that(is.numeric(element$element),
                          msg = "The element column for the element file is not numeric.")
  
  assertthat::assert_that(any(element$ids %in% parameters$datasetid),
                          msg = "None of the dataset ids in the element file are in the parameter file.")
  
  element <- element %>% 
    filter(ids %in% parameters$datasetid & thick %in% parameters$thick)
  
  if (verbose) {
    message(paste0("Modifying ", nrow(element), " records to update element."))
  }
  
  param_rows <- match(element$ids, params$datasetid)
  
  parameters$thick[param_rows] <- element$thick
  
  parameters$notes[param_rows] <- add_msg(parameters$notes[param_rows], 
                                          'Thickness adjusted based on prior work.')
  
  return(parameters)
  
}