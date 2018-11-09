run.bacon <- function(site.params){
  
  # check for suitability
  if (site.params$suitable == 1){
    
    thick <- site.params$thick
    
    # find hiatus depth
    geochron <- readr::read_csv(paste0('Cores/', site.params$handle, 
                                       '/', site.params$handle, '.csv'))  
    
    
    if (any(stringr::str_detect(geochron$labid, "sett")) & nrow(geochron) > 2){
      
      # determine which bacon parameters to input
      if (which(stringr::str_detect(geochron$labid, "sett")) == nrow(geochron)){ # if preset is the last sample
        hiatus.depth       = NA
        acc.mean.val       = site.params$acc.mean.mod
        acc.shape.val      = site.params$acc.shape.mod      
        site.params$hiatus = 0
      } else if (which(stringr::str_detect(geochron$labid, "sett")) == 1){ # if preset is the first sample
        hiatus.depth       = NA
        acc.mean.val       = site.params$acc.mean.old
        acc.shape.val      = site.params$acc.shape.old      
        site.params$hiatus = 0
      } else {    
        hiatus.depth = geochron$depth[stringr::str_detect(geochron$labid, "sett")] #- 1
        acc.mean.val     = c(site.params$acc.mean.mod, site.params$acc.mean.old)
        acc.shape.val    = c(site.params$acc.shape.mod, site.params$acc.shape.old)
        site.params$hiatus = 1
      }
      
    } else if (any(stringr::str_detect(geochron$labid, "sett")) & nrow(geochron) == 2) { # if preset and only two geochron samples, use modern priors
      hiatus.depth       = NA
      acc.mean.val       = site.params$acc.mean.mod
      acc.shape.val      = site.params$acc.shape.mod
      site.params$hiatus = 0
    } else if (!any(stringr::str_detect(geochron$labid, "sett"))) { # if no preset then use historical priors 
      hiatus.depth       = NA
      acc.mean.val       = site.params$acc.mean.old
      acc.shape.val      = site.params$acc.shape.old
      site.params$hiatus = 0
    } 
    
    out <- try(
      with(site.params, 
           Bacon(core          = handle,
                 coredir       = 'Cores',
                 acc.mean      = acc.mean.val, 
                 acc.shape     = acc.shape.val,
                 mem.strength  = mem.strength,
                 mem.mean      = mem.mean,
                 thick         = thick,
                 ask           = FALSE,
                 suggest       = FALSE,
                 depths.file   = TRUE, # i want to pass one, but bacon sometimes barfs if i do and i can't figure out why
                 hiatus.max    = 10,
                 hiatus.depths = hiatus.depth)
      )
    )
    if (!(class(out) == 'try-error')){
      
      site.params$success = 1
      
    } else {
      
      site.params$success = 0
      
    }
    
  }
  return(site.params)
}
