
add_msg <- function(x, msg) {
  post_message <- function(x, msg) {
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
    out <- sapply(x, function(x) post_message(x, msg))
  } else if (length(x) == 1) {
    out <- post_message(x, msg)
  } else {
    out <- msg
  }

  return(out)
}
