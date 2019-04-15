#' @title Extrapolation for Bacon posterior estimation.
#' @description When sample depths are below the last chronological control in a Bacon 
#' record we get NAs in the interpolation.  This function attempts to manage that issue.
#' It gets called in the \code{bacon_age_posts()} function.
#' @return A numeric vector.
bacon_extrap <- function(x, y, xout) {
  
  out_depth <- xout %>% unlist
  
  if (max(out_depth) > max(x)) {
    
    slope <- diff(tail(y, n = 2)) / diff(tail(x, n=2))
    x <- c(x, max(out_depth))
    y <- c(y, tail(y, n = 1) + tail(diff(x), n = 1) * slope)
  }
  outputs <- round(approx(x = x, y = y,
               xout = xout %>% unlist())$y, 0)
  
  return(outputs)

}
