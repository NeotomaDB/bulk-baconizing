#" @title Load download records to from/file
#" @description Checks for an existing pollen file with the right version number and loads it in.  If the file does not exist it will create it.
#" @param dl A \code{neotoma} dataset or dataset_list object.
#" @param path The path to check, defaults to the current directory.
#" @param version A version number.  Default is NULL.
#" @param setup Can automatically re-run.
#" @returns A \code{neotoma} \code{download_list} object.

load_downloads <- function(dl, path = "./", version = NULL, setup = FALSE) {

  if (file.exists(paste0(path, "data/pollen_v", version, ".rds"))) {
    if (setup == TRUE) {
      pol <- suppressMessages(neotoma::get_download(dl))
      saveRDS(pol, paste0(path, "data/pollen_v", version, ".rds"))
    }
    pol <- readRDS(paste0(path, "data/pollen_v", version, ".rds"))
  } else {
    pol <- suppressMessages(neotoma::get_download(dl))
    saveRDS(pol, paste0(path, "data/pollen_v", version, ".rds"))
  }

  return(pol)
}
