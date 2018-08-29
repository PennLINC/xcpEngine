#!/usr/bin/env Rscript

###################################################################
#  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  #
###################################################################

###################################################################
# Utility function that interpolates over censored volumes
# so that they do not influence the temporal filter in
# adjacent volumes
#
# based on work by Anish Mitra and Jonathan Power
###################################################################

###################################################################
# Load required libraries
###################################################################
suppressMessages(suppressWarnings(library(optparse)))
suppressMessages(suppressWarnings(library(pracma)))
suppressMessages(suppressWarnings(library(RNifti)))

###################################################################
# Parse arguments to script, and ensure that the required arguments
# have been passed.
###################################################################
option_list = list(
   make_option(c("-i", "--img"), action="store", default=NA, type='character',
              help="Path to the BOLD timeseries to be masked and interpolated"),
   make_option(c("-o", "--out"), action="store", default=NA, type='character',
              help="Output path"),
   make_option(c("-m", "--mask"), action="store", default=NA, type='character',
              help="Spatial mask indicating the voxels of the input image
                  for which the linear model should be computed."),
   make_option(c("-t", "--tmask"), action="store", default='ones', type='character',
              help="Temporal mask indicating the volumes that should be
                  taken under consideration when the linear model is
                  computed. [default]: Use all volumes."),
   make_option(c("-s", "--ofreq"), action="store", default=8, type='numeric',
              help="Oversampling frequency; a value of at least 4 is
                  recommended [default 8]"),
   make_option(c("-f", "--hifreq"), action="store", default=1, type='numeric',
              help="The maximum frequency permitted, as a fraction of the
                  Nyquist ferquency [default 1 : Nyquist]"),
   make_option(c("-b", "--voxbin"), action="store", default=3000, type='numeric',
              help="Number of voxels to transform at one time; a higher
                  number increases the transform speed but increases
                  computational demand [default 3000]")
)
opt = parse_args(OptionParser(option_list=option_list))

if (is.na(opt$img)) {
   cat('User did not specify an input timeseries.\n')
   cat('Use dmdt.R -h for an expanded usage menu.\n')
   quit()
}
if (is.na(opt$out)) {
   cat('User did not specify an output path.\n')
   cat('Use dmdt.R -h for an expanded usage menu.\n')
   quit()
}

impath                  <- opt$img
outpath                 <- opt$out
maskpath                <- opt$mask
tmaskpath               <- opt$tmask
OFREQ                   <- opt$ofreq
HIFREQ                  <- opt$hifreq
VOXBIN                  <- opt$voxbin

###################################################################
# Compute the sequence's repetition time
###################################################################
hdr                     <- dumpNifti(impath)
trep                    <- hdr$pixdim[5]
sink("/dev/null")

###################################################################
# 1. Load in the image to determine timeseries dimensions
###################################################################
img                     <- readNifti(impath)
out                     <- img
if (!is.na(maskpath)){
   mask                 <- readNifti(maskpath)
   logmask              <- (mask == 1)
   img                  <- img[logmask]
   dim(img)             <- c(sum(logmask),hdr$dim[5])
   img                  <- t(img)
} else {
   img                  <- as.array(img)
   dim(img)             <- c(prod(hdr$dim[2:4]),hdr$dim[5])
   img                  <- t(img)
}
nvol_total              <- dim(img)[1]
nvox                    <- dim(img)[2]
sink(NULL)

###################################################################
# 2. Determine temporal mask
###################################################################
if (tmaskpath=='ones'){
  tmask                 <- rep(1,nvol)
} else {
  tmask                 <- unname(as.numeric(unlist(read.table(tmaskpath,header=FALSE))))
}
tmask                   <- as.logical(tmask)
###################################################################
# number of retained volumes after censoring
###################################################################
nret                    <- sum(tmask, na.rm=TRUE)
###################################################################
# Total timespan of seen observations, in seconds
###################################################################
t_obs                   <- which(tmask)*trep
nvol                    <- length(t_obs)
timespan                <- max(t_obs) - min(t_obs)
###################################################################
# Temoral indices of all observations, seen and unseen
###################################################################
t_obs_all               <- seq(from=trep,by=trep,to=trep*nvol_total)

###################################################################
# 3. Calculate sampling frequencies
###################################################################
freq                    <- seq(from=1/(timespan*OFREQ),
                           by=1/(timespan*OFREQ),
                           to=HIFREQ*nvol/(2*timespan))
###################################################################
# Angular frequencies
###################################################################
freqang                 <- 2 * pi * freq
###################################################################
# Constant offsets
###################################################################
offsets                 <- (atan2(apply(sin(2*freqang %*% t(t_obs)),1,sum),
                           apply(cos(2*freqang %*% t(t_obs)),1,sum))/
                           (2*freqang))

###################################################################
# 4. Compute spectral power for sin and cos terms
###################################################################
costerm                 <- cos(freqang %*% t(t_obs) -
                           repmat(as.matrix(freqang*offsets),
                           1,length(t_obs)))
sinterm                 <- sin(freqang %*% t(t_obs) -
                           repmat(as.matrix(freqang*offsets),
                           1,length(t_obs)))

###################################################################
# 5. Determine the number of bins, and iterate through
# all of them
###################################################################
nbins                   <- ceil(dim(img)[2] / VOXBIN)
img_interpol            <- img

for (curbin in 1:nbins){

  cat('bin ')
  cat(curbin)
  cat(' out of ')
  cat(nbins)
  cat('\n')
  #################################################################
  # 6. Extract the relevant segments of the image matrix
  # for the current bin
  #################################################################
  binincl               <- seq(from=(curbin-1)*VOXBIN+1,
                           by=1,
                           to=curbin*VOXBIN)
  binincl               <- intersect(binincl,seq(1,nvox))
  active                <- img[tmask,binincl]

  #################################################################
  # 7. Compute the transform from good data as follows
  # for sin and cos terms
  # termfinal = sum(termmult,2)./sum(term.^2,2)
  # Compute the numerators and denominators first,
  # then divide
  #################################################################
  cosmult               <- array(0, dim=c(length(freq),nvol,length(binincl)))
  for (tpt in 1:nvol){
    cosmult[,tpt,]      <- costerm[,tpt] %*% t(active[tpt,])
  }
  numerator             <- apply(cosmult,c(1,3),sum)
  denominator           <- apply(costerm^2,1,sum)
  cosine                <- array(0, dim=c(length(freq),length(binincl)))
  for (frq in 1:length(freq)) {
    cosine[frq,]        <- numerator[frq,]/denominator[frq]
  }
  rm(numerator,
     denominator,
     cosmult)
  #################################################################
  # Repeat for sine
  #################################################################
  sinmult               <- array(0, dim=c(length(freq),nvol,length(binincl)))
  for (tpt in 1:nvol){
    sinmult[,tpt,]      <- sinterm[,tpt] %*% t(active[tpt,])
  }
  numerator             <- apply(sinmult,c(1,3),sum)
  denominator           <- apply(sinterm^2,1,sum)
  sine                  <- array(0, dim=c(length(freq),length(binincl)))
  for (frq in 1:length(freq)) {
    sine[frq,]          <- numerator[frq,]/denominator[frq]
  }
  rm(numerator,
     denominator,
     sinmult)

  #################################################################
  # 8. Interpolate over motion-corrupted epochs
  # and reconstruct the original timeseries
  # I have no idea what is going on; I'm only the translator
  #################################################################
  reptime               <- repmat(t_obs_all,1,length(freq)*dim(active)[2])
  dim(reptime)          <- c(nvol_total,length(freq),length(binincl))
  reptime               <- aperm(reptime,c(2,1,3))
  repang                <- repmat(freqang,1,length(binincl)*nvol_total)
  dim(repang)           <- c(length(freq),nvol_total,length(binincl))
  prod                  <- reptime * repang
  rm(reptime,
     repang)
  sin_t                 <- sin(prod)
  cos_t                 <- cos(prod)
  rm(prod)
  sine                  <- rep(sine,nvol_total)
  dim(sine)             <- c(length(freq),length(binincl),nvol_total)
  sine                  <- aperm(sine,c(1,3,2))
  sw_p                  <- sin_t * sine
  rm(sine,
     sin_t)
  cosine                <- rep(cosine,nvol_total)
  dim(cosine)           <- c(length(freq),length(binincl),nvol_total)
  cosine                <- aperm(cosine,c(1,3,2))
  cw_p                  <- cos_t * cosine
  rm(cosine,
     cos_t)
  S                     <- apply(sw_p,c(2,3),sum)
  C                     <- apply(cw_p,c(2,3),sum)
  recon                 <- C + S
  rm(cw_p,
     sw_p,
     C,
     S)

  #################################################################
  # 9. Normalise the reconstructed spectrum
  # This is necessary when the oversampling
  # frequency exceeds 1
  #################################################################
  Std_recon             <- apply(recon,2,std)
  Std_active            <- apply(active,2,std)
  norm_fac              <- Std_recon/Std_active
  norm_fac              <- repmat(norm_fac,nvol_total,1)
  recon                 <- recon / norm_fac

  #################################################################
  # 10. Write the current bin into the image matrix
  #################################################################
  img_interpol[!tmask,binincl] <- recon[!tmask,]

  rm(recon,
     norm_fac,
     Std_recon,
     Std_active)
}

###################################################################
# 11. Save out image
###################################################################
if (!is.na(maskpath)){
   for (i in 1:nvol_total) {
      out[,,,i][logmask]<- img_interpol[i,]
   }
} else {
   for (i in 1:nvol_total) {
      out[out > -Inf]   <- t(img_interpol)
   }
}
sink("/dev/null")
writeNifti(out,outpath,template=hdr)
sink(NULL)
