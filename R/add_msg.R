add_msg <- function(x, msg) {
  message <- function(x, msg) {
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
  
  if (length(x) > 1) {
    out <- sapply(x, function(x) add_msg(x, msg))
  } else {
    out <- message(x, msg)
  }
    
  return(out)
}