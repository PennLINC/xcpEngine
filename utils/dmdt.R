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
suppressMessages(require(optparse))
suppressMessages(require(pracma))
#suppressMessages(require(ANTsR))

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

impath <- opt$img
order <- opt$detrend
maskpath <- opt$mask
out <- opt$out
tmaskpath <- opt$tmask
sink("/dev/null")

###################################################################
# 1. Load in the image to determine timeseries dimensions
###################################################################
suppressMessages(require(ANTsR))
img <- antsImageRead(impath,4)
if (!is.na(maskpath)){
   mask <- antsImageRead(maskpath,4)
   imgmat <- timeseries2matrix(img,mask)
} else {
   imgmat <- as.array(img)
   dim(imgmat) <- c(prod(dim(img)[c(1,2,3)]),dim(img)[4])
   imgmat <- t(imgmat)
}
nvol <- dim(imgmat)[1]
nvox <- dim(imgmat)[2]

###################################################################
# 2. Build a matrix of regressors
###################################################################
# demean
###################################################################
curreg <- rep(1,nvol)
regmat <- matrix(curreg,nrow=nvol,ncol=1)
###################################################################
# linear detrend
###################################################################
if ( order > 0 ){
  linreg <- seq(0,1,length=nvol)
  curreg <- linreg
  regmat <- cbind(regmat,curreg)
}
ordin <- 1
###################################################################
# higher-order polynomial detrend
###################################################################
while ( ordin < order ) {
  curreg <- curreg * linreg
  regmat <- cbind(regmat,curreg)
  ordin <- ordin + 1
}

###################################################################
# 3. Determine temporal mask
###################################################################
if (tmaskpath=='ones'){
  tmask <- rep(1,nvol)
} else {
  tmask <- unname(as.numeric(unlist(read.table(tmaskpath))))
}
tmask <- as.logical(tmask)
###################################################################
# number of retained volumes after censoring
###################################################################
nret <- sum(tmask, na.rm=TRUE)
###################################################################
# Censored regressor matrix
###################################################################
regmat_censored <- regmat[tmask,]

###################################################################
# Iterate through all voxels
###################################################################
imgmat_dmdt <- matrix(nrow=nvol,ncol=nvox)
for (vox in 1:nvox) {
  ts <- imgmat[,vox]
  
  #################################################################
  # 4. Solve for parameter estimates
  #    using left division
  #################################################################
  betas <- mldivide(regmat_censored,ts[tmask])
  dmdt <- t(betas) %*% t(regmat)
  
  #################################################################
  # 5. Detrend timeseries with respect to regressors
  #################################################################
  ts_dmdt <- ts - dmdt
  imgmat_dmdt[,vox] <- ts_dmdt
}

###################################################################
# 6. Write out the image
###################################################################
if (!is.na(maskpath)){
   img_dmdt <- matrix2timeseries(img,mask,imgmat_dmdt)
} else {
   img_dmdt <- img
   imgmat_dmdt <- t(imgmat_dmdt)
   dim(imgmat_dmdt) <- NULL
   img_dmdt[img > -Inf] <- imgmat_dmdt
}
antsImageWrite(img_dmdt,out)
sink(NULL)
