#' @title Run Bacon on a set of sites
#' @param x A data frame of parameters.

run_batch <- function(x, settings){
  
  check_params(x)
  
  for(i in 1:nrow(x)){
    #for(i in ids_rerun){

    if ((!is.na(x$success[i])) & x$success[i] == 1) {
      message(paste0(x$handle, ' has already been run. Skipping.\n'))
      next
    }
    if (is.na(x$thick[i])) {next}
    
    # This fails in linux if libgsl.so.0 cannot be found.  To fix this I ran:
    # > sudo find . -name "libgsl.so"
    # This provided the path to libgsl.so
    # Then, I created a simlink:
    # sudo ln ./usr/lib/x86_64-linux-gnu/libgsl.so ./usr/lib/x86_64-linux-gnu/libgsl.so.0
    # This allows things to work.
    
    if (!is.na(x$suitable[i]) & x$suitable[i] == 1) {
      x[i,] <- call_bacon(x[i,])
      
      readr::write_csv(x = x,
                       path = paste0('data/params/bacon_params_v', settings$version, '.csv'))
      
    } 
  }
  
  return(x)
}
