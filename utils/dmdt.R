#!/usr/bin/env Rscript

###################################################################
#  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  #
###################################################################

###################################################################
# generalised function for demeaning and detrending timeseries
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
              help="Path to the BOLD timeseries to be detrended"),
   make_option(c("-d", "--detrend"), action="store", default=0, type='numeric',
              help="The order of polynomial detrend to be applied to the
                  timeseries:
                  0 : demean only [default]
                  1 : linear detrend
                  2 : quadratic detrend
                  3 : cubic detrend
                  etc."),
   make_option(c("-o", "--out"), action="store", default=NA, type='character',
              help="Output path"),
   make_option(c("-x", "--mean"), action="store", default=NA, type='character',
              help="Output mean image: If this option is set to a valid
                  path, then the demeaning procedure will output the
                  voxelwise fit of the constant term as the mean
                  image."),
   make_option(c("-m", "--mask"), action="store", default=NA, type='character',
              help="Spatial mask indicating the voxels of the input image
                  for which the linear model should be computed."),
   make_option(c("-t", "--tmask"), action="store", default='ones', type='character',
              help="Temporal mask indicating the volumes that should be
                  taken under consideration when the linear model is
                  computed. [default]: Use all volumes.")
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
order                   <- opt$detrend
maskpath                <- opt$mask
outpath                 <- opt$out
outmean                 <- opt$mean
tmaskpath               <- opt$tmask
sink("/dev/null")

###################################################################
# 1. Load in the image to determine timeseries dimensions
###################################################################
img                     <- readNifti(impath)
hdr                     <- dumpNifti(impath)
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
sink(NULL)
nvol <- dim(img)[1]
nvox <- dim(img)[2]

###################################################################
# 2. Build a matrix of regressors
###################################################################
# demean
###################################################################
curreg                  <- rep(1,nvol)
regmat                  <- matrix(curreg,nrow=nvol,ncol=1)
###################################################################
# polynomial detrend
###################################################################
if (order > 0) {
   linreg               <- seq(0,1,length=nvol)
   curreg               <- stats::poly(1:(nvol*2),degree=order)
   curreg               <- curreg[(nvol+1):(nvol*2),]
   regmat               <- cbind(regmat,curreg)
}

###################################################################
# 3. Determine temporal mask
###################################################################
if (tmaskpath=='ones'){
  tmask                 <- rep(1,nvol)
} else {
  tmask                 <- unname(as.numeric(unlist(read.table(tmaskpath))))
}
tmask                   <- as.logical(tmask)
###################################################################
# Censored regressor matrix
###################################################################
regmat_censored         <- regmat[tmask,]

###################################################################
# Iterate through all voxels
###################################################################
img_dmdt                <- matrix(nrow=nvol,ncol=nvox)
img_mean                <- matrix(nrow=1,   ncol=nvox)
for (vox in 1:nvox) {
  ts                    <- img[,vox]
  
  #################################################################
  # 4. Solve for parameter estimates
  #    using left division
  #################################################################
  betas                 <- mldivide(regmat_censored,ts[tmask])
  dmdt                  <- t(betas) %*% t(regmat)
  img_mean[,vox]        <- betas[1]
  
  #################################################################
  # 5. Detrend timeseries with respect to regressors
  #################################################################
  ts_dmdt               <- ts - dmdt
  img_dmdt[,vox]        <- ts_dmdt
}

###################################################################
# 6. Write out the image
###################################################################
if (!is.na(maskpath)){
   for (i in 1:nvol) {
      out[,,,i][logmask]<- img_dmdt[i,]
   }
   if (!is.na(outmean)){
      omean             <- array(0,dim=dim(out)[1:3])
      omean[logmask]    <- img_mean
   }
} else {
   for (i in 1:nvol) {
      out[out > -Inf]   <- t(img_dmdt)
   }
   if (!is.na(outmean)){
      omean             <- array(0,dim=dim(out)[1:3])
      omean[omean>-Inf] <- img_mean
   }
}
sink("/dev/null")
writeNifti(out,outpath,template=impath,datatype='float')
if(!is.na(outmean)) { writeNifti(omean,outmean,template=impath,datatype='float') }
sink(NULL)
