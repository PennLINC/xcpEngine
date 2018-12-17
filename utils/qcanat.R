#!/usr/bin/env Rscript

###################################################################
#  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  #
###################################################################

###################################################################
# Utility function that will create quality metrics
# similar to the QAP pipeline as created by Cameron Craddock
# see here: https://github.com/preprocessed-connectomes-project/quality-assessment-protocol
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
              help="Path to the raw structural image"),
   make_option(c("-c", "--cortical"), action="store", default=NA, type='character',
              help="Path to the cortical binary mask."),
make_option(c("-d", "--dgm"), action="store", default=NA, type='character',
              help="Path to the dgm binary mask."),
   make_option(c("-w", "--whitemask"), action="store", default=NA, type='character',
              help="Path to the white matter binary mask."),
   make_option(c("-m", "--graymask"), action="store", default=NA, type='character',
              help="Path to the gray matter binary mask."),
   make_option(c("-o", "--output"), action="store", default=NA, type='character',
              help="Output CSV."),
   make_option(c("-f", "--foreground"), action="store", default=NA, type='character',
              help="Path to the foreground binary mask.")
)
opt = parse_args(OptionParser(option_list=option_list))

if (is.na(opt$img)) {
   cat('User did not specify an input structural image.\n')
   cat('Use strucQA.R -h for an expanded usage menu.\n')
   quit()
}

imgpath <- opt$img
gmpath <- opt$graymask
wmpath <- opt$whitemask
fgmaskpath <- opt$foreground
corticalpath <- opt$cortical
dgmpath <- opt$dgm
outPath <- opt$output

###################################################################
# Load all of our provided images
###################################################################
gCheck <- 0
wCheck <- 0
fgCheck <- 0
cCheck <- 0
img <- readNifti(imgpath)
if(!is.na(gmpath)){
  gimg <- readNifti(gmpath)
  gmvals <- img[gimg==1] 
  gCheck <- 1 
}
if(!is.na(wmpath)){
  wimg <- readNifti(wmpath)
  wmvals <- img[wimg==1]  
  wCheck <- 1
}
if(!is.na(fgmaskpath)){
  fgimg <- readNifti(fgmaskpath)
  fgvals <- img[fgimg==1]
  bgvals <- img[fgimg==0] 
  fgCheck <- 1 
}
if(!is.na(corticalpath)){
  cimg <- readNifti(corticalpath)
  cvals <- img[cimg==1]
  cCheck <- 1
}
if(!is.na(dgmpath)){
    dimg <- readNifti(corticalpath)
    dvals <- img[dimg==1]
    dCheck <- 1
}

###################################################################
# Declare any functions
###################################################################
skewness <- function(x) {
    n <- length(x)
    v <- var(x)
    m <- mean(x)
    third.moment <- (1/(n - 2)) * sum((x - m)^3)
    third.moment/(var(x)^(3/2))
}
kurtosis <- function (x, na.rm = FALSE) {
    if (is.matrix(x)) 
        apply(x, 2, kurtosis, na.rm = na.rm)
    else if (is.vector(x)) {
        if (na.rm) 
            x <- x[!is.na(x)]
        n <- length(x)
        n * sum((x - mean(x))^4)/(sum((x - mean(x))^2)^2)
    }
    else if (is.data.frame(x)) 
        sapply(x, kurtosis, na.rm = na.rm)
    else kurtosis(as.vector(x), na.rm = na.rm)
}

###################################################################
# Produce our output variable
###################################################################
outputVals <- NULL

###################################################################
# Now calculate FBER
###################################################################
if(fgCheck > 0){
  meanFG <- abs(sum(fgvals^2) / sum(fgvals))
  meanBG <- abs(sum(bgvals^2) / sum(bgvals))
  FBER <- meanFG / meanBG
  outputVals <- cbind(outputVals, FBER)
}
###################################################################
# Now calculate SNR
###################################################################
if((gCheck > 0) & (fgCheck > 0)){
  SNR <- mean(gmvals) / sd(bgvals)
  outputVals <- cbind(outputVals, SNR)
}
###################################################################
# Now calculate CNR
###################################################################
if((gCheck > 0) & (fgCheck > 0) & (wCheck > 0)){
  CNR <- abs(mean(gmvals) - mean(wmvals)) / sd(bgvals)
  outputVals <- cbind(outputVals, CNR)
}
###################################################################
# Now calculate Cortical Contrasts
###################################################################
if(cCheck > 0){
  CORTCON <- (mean(wmvals) - mean(cvals)) / ((mean(cvals) + mean(wmvals)) / 2)
  outputVals <- cbind(outputVals, CORTCON)
}
###################################################################
# Now calculate DGM Contrasts
###################################################################
if(dCheck > 0){
    DCON <- (mean(wmvals) - mean(dvals)) / ((mean(cvals) + mean(wmvals)) / 2)
    outputVals <- cbind(outputVals, DCON)
}
###################################################################
# Now calculate QI1
###################################################################
if(fgCheck > 0){
  all.vals <- append(fgvals, bgvals)
  allLength <- dim(img)[1] * dim(img)[2] * dim(img)[3]
  # Calcaulate efc max
  efc.max <- allLength * (1 / sqrt(allLength)) * (log(1/sqrt(allLength)))
  # calculate total image entropy
  b.max <- sqrt(sum(all.vals^2))
  # Now calculate EFC
  EFC <- (1.0 / efc.max) * sum((all.vals / b.max) * log((all.vals / b.max)), na.rm=T)
  outputVals <- cbind(outputVals, EFC)
}
###################################################################
# Now calculate Kurtosis & Skewness values
###################################################################
if(gCheck > 0){
  GMKURT <- kurtosis(gmvals)
  GMSKEW <- skewness(gmvals)
  outputVals <- cbind(outputVals, GMKURT, GMSKEW)
}
if(wCheck > 0){
  WMKURT <- kurtosis(wmvals)
  WMSKEW <- skewness(wmvals)
  outputVals <- cbind(outputVals, WMKURT, WMSKEW)
}
if(fgCheck > 0){
  BGKURT <- kurtosis(bgvals)
  BGSKEW <- skewness(bgvals)
  outputVals <- cbind(outputVals, BGKURT, BGSKEW)
}
###################################################################
# Now write output values
###################################################################
if (!is.na(outPath)) {
   write.csv(outputVals, file=outPath, quote=F, row.names=F)
} else {
cat('· [Foreground-background energy ratio:  ',FBER,']\n', file=stderr())
cat('FBER:',FBER, '\n', sep='')
cat('· [Signal-to-noise ratio:               ',SNR,']\n', file=stderr())
cat('SNR:',SNR, '\n', sep='')
cat('· [Contrast-to-noise ratio:             ',CNR,']\n', file=stderr())
cat('CNR:',CNR, '\n', sep='')
cat('· [Cortical contrasts:                  ',CORTCON,']\n', file=stderr())
cat('CORTCON:',CORTCON, '\n', sep='')
cat('· [DGM contrasts:                  ',DCON,']\n', file=stderr())
cat('DGMCONTRAST:',DCON, '\n', sep='')
cat('· [Entropy focus criterion:             ',EFC,']\n', file=stderr())
cat('EFC:',EFC, '\n', sep='')
cat('· [Grey matter kurtosis:                ',GMKURT,']\n', file=stderr())
cat('GMKURT:',GMKURT, '\n', sep='')
cat('· [Grey matter skewness:                ',GMSKEW,']\n', file=stderr())
cat('GMSKEW:',GMSKEW, '\n', sep='')
cat('· [White matter kurtosis:               ',WMKURT,']\n', file=stderr())
cat('WMKURT:',WMKURT, '\n', sep='')
cat('· [White matter skewness:               ',WMSKEW,']\n', file=stderr())
cat('WMSKEW:',WMSKEW, '\n', sep='')
cat('· [Background kurtosis:                 ',BGKURT,']\n', file=stderr())
cat('BGKURT:',BGKURT, '\n', sep='')
cat('· [Background skewness:                 ',BGSKEW,']\n', file=stderr())
cat('BGSKEW:',BGSKEW, '\n', sep='')
}
