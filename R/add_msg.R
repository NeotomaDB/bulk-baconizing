add_msg <- function(x, msg) {
  
  if(stringr::str_detect(string = x, pattern = msg)) {
    out <- x
  } else {
    if (nchar(x) == 1) {
      x <- ''
      pre <- ''
    } else {
      pre <- '; '
    }
    out <- paste0(x, pre, msg)
  }
  
  return(out)
}