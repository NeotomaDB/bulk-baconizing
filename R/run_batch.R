
run_batch <- function(bacon_params){
  
  for(i in 1:nrow(bacon_params)){
    #for(i in ids_rerun){
    
    print(i)
    site.params <- bacon_params[i,]
    if (is.na(site.params$thick)) {next}

    # This fails in linux if libgsl.so.0 cannot be found.  To fix this I ran:
    # > sudo find . -name "libgsl.so"
    # This provided the path to libgsl.so
    # Then, I created a simlink:
    # sudo ln ./usr/lib/x86_64-linux-gnu/libgsl.so ./usr/lib/x86_64-linux-gnu/libgsl.so.0
    # This allows things to work.
    
    if (!is.na(site.params$suitable)) {
      site.params <- run.bacon(site.params)
    }
  }
}
