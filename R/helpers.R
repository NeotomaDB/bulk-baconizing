pollen_to_albers <- function(coord, proj4 = '+proj=longlat +ellps=WGS84', rescale=1e6){
  #' Convert latlong coordinates to Albers Gt Lakes St Lawrence
  #' 
  #' @param coord A set of coordinates as either a \code{matrix} or \code{data.frame}.
  #' @param proj4 The \code{proj4} projection string for the original coordinates.
  #' @param rescale Rescales coordinate values to different units (default is 1000 km).
  #' @return A matrix with dimensions equal to \code{coord}.

  sp::coordinates(coord) <- ~ long + lat
  sp::proj4string(coord) <- sp::CRS(proj4)
  
  output <- sp::spTransform(coord, sp::CRS('+init=epsg:3175')) %>% 
    sp::coordinates()/rescale

  colnames(output) <- c('x', 'y')
  
  return(output)
}

get_survey_year <- function(coords, state){
  #' Pull year of survey from the PLS data
  #' 
  #' @param coords a data frame or matrix with columns `lat` and `long`.
  #' @param state A character
  #' @return The date of sampling for records in the upper Midwest.

  pls <- raster::raster('data/input/age_of_sample.tif')

  set_year <- raster::extract(pls, pollen_to_albers(coords, rescale=1))
  
  set_year[is.na(set_year) & state == 'michigan:north'] = 1860
  set_year[is.na(set_year) & state == 'michigan:south'] = 1840
  
  return(set_year)
}

lead_error_paleon <- function(chron, types){

  lead.cond <- types == 'Lead-210'
  
  ages = data.frame(age = chron[lead.cond & (chron[lead.cond, 'error'] == 0), 'age'])
  # chron[lead.cond & (chron[lead.cond, 'error'] == 0), 'error'] = ceiling(exp(as.vector(predict(model, ages)))/2)
  
    
  geochron_tables <- readRDS('data/output/all_geochron_tables.rds')
  
  widen <- function(x) {
    data.frame(x$dataset$site.data[,1:5], x$geochron)
  }
  
  wide_table <- do.call(rbind.data.frame, lapply(geochron_tables, widen))
  
  library(dplyr)
  
  leads <- wide_table %>% filter(geo.chron.type %in% "Lead-210")
  
  # There are some ages with improperly named age types.
  leads$age[leads$age.type %in% "Calendar years AD/BC" & leads$age > 500] <- 1950 - 
    leads$age[leads$age.type %in% "Calendar years AD/BC" & leads$age > 500]
  
  leads = leads[leads$e.older > 0, ]
  
  # # None of the ages reported as Calendar years BP are wrong.
  # library(ggplot2)
  
  lead_model <- glm(log(e.older)~age, data=leads)
  data_ages=data.frame(age=ages)
  p_ages = predict(lead_model, data_ages)
  
  chron[lead.cond & (chron[lead.cond, 'error'] == 0), 'error'] = ceiling(exp(p_ages))
  
  # plot(ages$age, exp(p), type='l')
  # points(leads$age, leads$e.older)
  # # points(leads$age[which(leads$site.id==10429)], leads$e.older[which(leads$site.id==10429)], col='blue', pch=19)

  return(chron)
}

