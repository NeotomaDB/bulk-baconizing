
#' @title make matrix of posterior samples from bacon and pollen counts from dataset_list
#' @param pollen_v1 is the dataset_list from main RMD file
#' @param n.samps number of postier samples you want
#' @param list.name arguement goes into compile_taxa
#' @author Ann Raiho and Simon Goring
#' @return pol_hold is a matrix with all pollen samples and bacon posterior draws
#'

make_posts_counts <- function(pollen_v1, n.samps, list.name = 'WhitmoreSmall') {
    comp.tax <- neotoma::compile_taxa(pollen_v1, list.name)
    pol_count <- neotoma::compile_downloads(comp.tax)
    
    bacon_df <- matrix(NA, nrow = nrow(pol_count), ncol = n.samps)
    
    handles <-
      sapply(pollen_v1, function(x) {
        x$dataset$dataset.meta$collection.handle
      })
    ids <- names(pollen_v1)
    
    for (i in seq_along(handles)) {
      dir_path <- file.path('bulk-baconizing', 'Cores', handles[i])
      files_get <- list.files(dir_path)
      pick_file <- grep(files_get, pattern = 'posteriorout.csv')
      
      if (any(pick_file)) {
        posts <- read.csv(file.path(dir_path, files_get[pick_file]))
        bacon_df[which(pol_count$dataset == ids[i]), ] <-
          as.matrix(posts[, sample(x = 1:ncol(posts), size = n.samps)])
      } else{
        print(paste(handles[i], 'not run in bacon'))
      }
    }
    
    colnames(bacon_df) <- paste('bacon_draw', 1:n.samps)
    pol_hold <- cbind(pol_count, bacon_df, rowMeans(bacon_df))
    colnames(pol_hold)[ncol(pol_hold)] <- 'baconMean'
    
    return(pol_hold)
  }
