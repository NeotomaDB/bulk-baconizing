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
# 
# 
# pdf('figures/early_sample_year.pdf')
# pls <- raster('data/age_raster.tif')
# plot(pls, xlim=c(0,1000000), ylim=c(600000, 1500000))
# dev.off()

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


lead_error_binford <- function(chron, types){
  
  x = c(10, 100, 150)
  y = c(1.5, 15, 85)
  model <- lm(log(y)~x)
  
  lead.cond <- types == 'Lead-210'
  
  ages = data.frame(x = chron[lead.cond & (chron[lead.cond, 'error'] == 0), 'age'])
  chron[lead.cond & (chron[lead.cond, 'error'] == 0), 'error'] = ceiling(exp(as.vector(predict(model, ages)))/2)
  
  print(paste0("Some or all of the lead-210 dates in core ", corename, " have zero error. Adjusting."))
  
  return(chron)
}

bacon_age_posts <- function(d, b.depths, out, thick)
{ 
  its=out[,1:(ncol(out)-1)]
  
  elbows <- cbind(its[,1])
  accs <- its[,2:(ncol(its)-1)]
  for(i in 2:ncol(accs))
    elbows <- cbind(elbows, elbows[,ncol(elbows)] + (thick * accs[,i-1]))
  
  if (d %in% b.depths)
    ages <- elbows[,which(b.depths == d)] 
  else
    {
      maxd <- max(which(b.depths < d))
      ages <- elbows[,maxd] + ((d-b.depths[maxd]) * accs[,maxd])
    }
  ages
}


run.bacon <- function(site.params){
  
  source('Bacon.R')
  
  # check for suitability
  if (site.params$suit==1){
    
    thick = site.params$thick
    
    # find hiatus depth
    geochron = read.table(sprintf('Cores/%s/%s.csv', site.params$handle, site.params$handle), sep=',', header=TRUE)  
      
    if (any(substr(geochron$labid, 1, 4) == 'Pres') & nrow(geochron) > 2){
      
      # determine which bacon parameters to input
      if (which(substr(geochron$labid, 1, 4) == 'Pres') == nrow(geochron)){ # if preset is the last sample
        hiatus.depth       = NA
        acc.mean.val       = site.params$acc.mean.mod
        acc.shape.val      = site.params$acc.shape.mod      
        site.params$hiatus = 0
      } else if (which(substr(geochron$labid, 1, 4) == 'Pres') == 1){ # if preset is the first sample
        hiatus.depth       = NA
        acc.mean.val       = site.params$acc.mean.old
        acc.shape.val      = site.params$acc.shape.old      
        site.params$hiatus = 0
      } else {    
        hiatus.depth = geochron$depth[substr(geochron$labid, 1, 4) == 'Pres'] #- 1
        acc.mean.val     = c(site.params$acc.mean.mod, site.params$acc.mean.old)
        acc.shape.val    = c(site.params$acc.shape.mod, site.params$acc.shape.old)
        site.params$hiatus = 1
      }
      
    } else if (any(substr(geochron$labid, 1, 4) == 'Pres') & nrow(geochron) == 2) { # if preset and only two geochron samples, use modern priors
      hiatus.depth       = NA
      acc.mean.val       = site.params$acc.mean.mod
      acc.shape.val      = site.params$acc.shape.mod      
      site.params$hiatus = 0
    } else if (!any(substr(geochron$labid, 1, 4) == 'Pres')) { # if no preset then use historical priors 
      hiatus.depth       = NA
      acc.mean.val       = site.params$acc.mean.old
      acc.shape.val      = site.params$acc.shape.old      
      site.params$hiatus = 0
    } 
        
    out <- try(
      with(site.params, 
           Bacon(handle, 
                 acc.mean      = acc.mean.val, 
                 acc.shape     = acc.shape.val,
                 #                  acc.shape     = acc.shape.val,
                 mem.strength  = mem.strength,
                 mem.mean      = mem.mean,
                 thick         = thick,
                 ask           = FALSE,
                 suggest       = FALSE,
                 depths.file   = FALSE, # i want to pass one, but bacon sometimes barfs if i do and i can't figure out why
                 hiatus.shape  = 0.1,#1,
                 hiatus.mean   = 1/100,#1/10
                 hiatus.depths = hiatus.depth)
      )
    )
    if (!(class(out) == 'try-error')){
      
      depths       = scan(sprintf('Cores/%s/%s_depths.txt', site.params$handle, site.params$handle))
      depths.bacon = scan(sprintf('Cores/%s/%s_%s_bacon_depths.csv', site.params$handle, site.params$handle, thick))
      
      ndepths = length(depths.bacon)
      
      core.path = sprintf('Cores/%s', site.params$handle)
      #       outfile  = Sys.glob(paste0(core.path, '_*.out')) 
      outfile = paste0(core.path, '/', site.params$handle, '_', thick, '.out')
      output = read.table(outfile)
      
      #       # build depths.bacon using thick and upper and lower depths from 
      #       marker.depths = read.table(sprintf('Cores/%s/%s.csv', site.params$handle, site.params$handle), sep=',', header=TRUE)$depth
      #       depths.bacon = seq(min(marker.depths), max(marker.depths), by=thickness)
      #       if (!is.null(hiatus.depth)) ndepths = ndepths + 1
      
      #       # loses connection when in a loop for some reason...
      #       core_files = list.files(sprintf('Cores/%s/', site.params$handle))
      #       out_file   = core_files[grep("*.out", core_files)]
      #       output     = read.table(sprintf('Cores/%s/%s', site.params$handle, out_file))
      
      #       output = read.table(sprintf('Cores/%s/%s_%d.out', site.params$handle, site.params$handle, length(depths.bacon)))
      
      if ( (min(depths) < min(depths.bacon)) | (max(depths) > max(depths.bacon)) ){
        depths = depths[depths > min(depths.bacon)]
        # depths = depths[(depths - max(depths.bacon)) < 100]
      }
      
      iters   = nrow(output)
      samples = matrix(0, nrow = length(depths), ncol = iters)
      colnames(samples) = paste0('iter', rep(1:iters))
      
      for (j in 1:length(depths)){    
        #         samples[j,] = Bacon.Age.d(depths[j]) 
        samples[j,] = bacon_age_posts(d=depths[j], b.depths=depths.bacon, out=output, thick=site.params$thick)
      }
      
      post = data.frame(depths=depths, samples)
      
      write.table(post, paste0('.', "/Cores/", site.params$handle, "/", 
                               site.params$handle, "_", site.params$thick, "_samples.csv"), sep=',', col.names = TRUE, row.names = FALSE)
      
      samples = matrix(0, nrow = length(geochron$depth), ncol = iters)
      colnames(samples) = paste0('iter', rep(1:iters))
      for (j in 1:length(geochron$depth)){    
        #         samples[j,] = Bacon.Age.d(depths[j]) 
        samples[j,] = bacon_age_posts(d=geochron$depth[j], b.depths=depths.bacon, out=output, thick=site.params$thick)
      }
      
      post = data.frame(labid=geochron$labid, depths=geochron$depth, samples)
      
      write.table(post, paste0('.', "/Cores/", site.params$handle, "/", 
                               site.params$handle, "_", site.params$thick, "_geo_samples.csv"), sep=',', col.names = TRUE, row.names = FALSE)
      
      site.params$success = 1
      
    } else {
      
      site.params$success = 0
    
    }
    
  }
  return(site.params)
}


# build pollen counts
build_core_locs <- function(tmin, tmax, int, pollen_ts){
  
  if (int > 0){
    #   breaks = seq(0,2500,by=int)
    breaks = seq(tmin,tmax,by=int)
    
    meta_pol  = pollen_ts[which((pollen_ts[, 'ages'] >= tmin) & 
                                  (pollen_ts[, 'ages'] <= tmax)),]
    
    meta_agg = matrix(NA, nrow=0, ncol=ncol(meta_pol))
    colnames(meta_agg) = colnames(meta_pol)
    
    ids = unique(meta_pol$id)
    ncores = length(ids)
    
    for (i in 1:ncores){
      
      #print(i)
      core_rows = which(meta_pol$id == ids[i])
      #     core_counts = counts[core_rows,]
      
      for (j in 1:(length(breaks)-1)){
        
        #print(j)
        age = breaks[j] + int/2
        
        age_rows = core_rows[(meta_pol[core_rows, 'ages'] >= breaks[j]) & 
                               (meta_pol[core_rows, 'ages'] < breaks[j+1])]
        
        if (length(age_rows)>=1){
          
          meta_agg      = rbind(meta_agg, meta_pol[core_rows[1],])
          meta_agg$ages[nrow(meta_agg)] = age/100
          
        }
        #         } else if (length(age_rows) == 0){
        #           
        #           meta_agg      = rbind(meta_agg, meta_pol[core_rows[1],])
        #           meta_agg$ages[nrow(meta_agg)] = age/100
        #         }
        
      }
    }
  }
  
  return( meta_agg )
}


# pollen_to_albers <- function(pollen_ts){
#   
#   centers_pol = data.frame(x=pollen_ts$long, y=pollen_ts$lat)
#   
#   coordinates(centers_pol) <- ~ x + y
#   proj4string(centers_pol) <- CRS('+proj=longlat +ellps=WGS84')
#   
#   centers_polA <- spTransform(centers_pol, CRS('+init=epsg:3175'))
#   centers_polA <- as.matrix(data.frame(centers_polA))/1000000
#   
#   pollen_ts$long = centers_polA[,'x']
#   pollen_ts$lat = centers_polA[,'y']
#   
#   colnames(pollen_ts)[grep("lat", colnames(pollen_ts))] = 'y'
#   colnames(pollen_ts)[grep("long", colnames(pollen_ts))] = 'x'
#   
#   return(pollen_ts)
# }

add_map_albers <- function(plot_obj, map_data=us.fort, limits){
  p <- plot_obj + geom_path(data=map_data, aes(x=long, y=lat, group=group),  colour='grey55') + 
    scale_x_continuous(limits = limits$xlims) +
    scale_y_continuous(limits = limits$ylims) #+ coord_map("albers")
  return(p)
  
}

get_limits <- function(centers, buffer){
  xlo = min(centers[,1]) - buffer - 50000
  xhi = max(centers[,1]) + buffer
  
  ylo = min(centers[,2]) - buffer
  yhi = max(centers[,2]) + buffer + 50000
  
  return(list(xlims=c(xlo,xhi),ylims=c(ylo, yhi)))
}  

theme_clean <- function(plot_obj){
  plot_obj <- plot_obj + theme(axis.ticks = element_blank(), 
                               axis.text.y = element_blank(), 
                               axis.text.x = element_blank(),
                               axis.title.x = element_blank(),
                               axis.title.y = element_blank(),
                               plot.background = element_rect(fill = "transparent",colour = NA))
  
  return(plot_obj)
}

split_mi <- function(meta, longlat){
  
  #   meta=veg_meta
  if (any(colnames(meta)=='region')){
    meta$state = meta$region
  } 
  
  if (longlat){
    centers_ll = data.frame(x=meta$long, y=meta$lat)
  } else {
    centers = data.frame(x=meta$x, y=meta$y)
    
    coordinates(centers) <- ~x + y
    proj4string(centers) <- CRS('+init=epsg:3175')
    
    centers_ll <- spTransform(centers, CRS('+proj=longlat +ellps=WGS84'))
    centers_ll <- as.matrix(data.frame(centers_ll))
  }
  
  meta$state[meta$state == 'michigan:north'] = 'michigan_north'
  idx.mi = which(meta$state=='michigan_north')
  meta$state2 = as.vector(meta$state)
  meta$state2[idx.mi] = map.where(database="state", centers_ll[idx.mi,1], centers_ll[idx.mi,2])
  idx.na = which(is.na(meta$state2))
  idx.not.na = which(!is.na(meta$state2))
  
  #   plot(meta$x, meta$y)
  #   points(meta$x[meta$state2=='michigan:north'], meta$y[meta$state2=='michigan:north'], col='red', pch=19)
  
  meta$state[meta$state == 'michigan:south'] = 'michigan_south'
  idx.mi.s = which(meta$state=='michigan_south')
  meta$state2[idx.mi.s] = 'michigan:south'#map.where(database="state", centers_ll[idx.mi.s,1], centers_ll[idx.mi.s,2])
  #   points(meta$x[meta$state2=='michigan:south'], meta$y[meta$state2=='michigan:south'], col='blue', pch=19)
  
  #   points(meta$x[meta$state2=='michigan:north'], meta$y[meta$state2=='michigan:north'])
  #   plot(meta$x, meta$y)
  if (length(idx.na)>0){
    
    centers = centers_ll[idx.not.na,]
    
    for (i in 1:length(idx.na)){
      print(i)
      idx = idx.na[i]
      dmat = fields::rdist(as.matrix(centers_ll[idx,], nrow=1) , as.matrix(centers, ncol=2))
      min.val = dmat[1,which.min(dmat[which(dmat>1e-10)])]
      idx_close = which(dmat == min.val)
      #     print(as.vector(meta$state[idx]))
      #     print(meta$state2[idx])
      state  = map.where(database="state", centers[idx_close,1], centers[idx_close,2])
      #     print(map.where(database="state", centers[idx_close,1], centers[idx_close,2]))
      meta$state2[idx] = state
      #     points(meta$x[idx], meta$y[idx], col='green', pch=19)
    }
  }
  
  meta$state2[which(meta$state2[idx.mi]=='minnesota')] = 'michigan:north'
  
  idx.bad = which((meta$state2=='michigan:north') & (meta$y<8e5))
  meta$state2[idx.bad] = 'michigan:south'
  #   points(meta$x[idx.bad], meta$y[idx.bad], col='pink', pch=19)
  
  return(meta)
  
}

whitmore2stepps <- function(x, taxa){
  x = compile_taxa_stepps(x, list.name='must_have', alt.table=pollen.equiv.stepps, cf = TRUE, type = TRUE)
  
  #if ('Other' %in% )
  x$counts = x$counts[,!(colnames(x$counts)=='Other')]
  
  zero_taxa = taxa[!(taxa %in% colnames(x$counts))]
  add_back   = matrix(0, nrow=nrow(x$counts), ncol=length(zero_taxa))
  colnames(add_back) = zero_taxa
  
  tmp      = cbind(x$counts, add_back)
  x$counts = tmp[, sort(colnames(tmp))]
  
  return(x)
}
