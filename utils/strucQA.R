#!/usr/bin/env Rscript

###################################################################
#  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  #
###################################################################

###################################################################
# Utility function that will create quality metrics
# similar to work the QAP pipeline as created by Cameron Craddock
# see here: https://github.com/preprocessed-connectomes-project/quality-assessment-protocol
###################################################################

###################################################################
# Load required libraries
###################################################################
suppressMessages(require(optparse))
suppressMessages(require(pracma))

###################################################################
# Parse arguments to script, and ensure that the required arguments
# have been passed.
###################################################################
option_list = list(
   make_option(c("-i", "--img"), action="store", default=NA, type='character',
              help="Path to the raw structural image"),
   make_option(c("-c", "--cortical"), action="store", default=NA, type='character',
              help="Path to the cortical binary mask."),
   make_option(c("-w", "--whitemask"), action="store", default=NA, type='character',
              help="Path to the white matter binary mask."),
   make_option(c("-g", "--graymask"), action="store", default=NA, type='character',
              help="Path to the gray matter binary mask."),
   make_option(c("-f", "--foreground"), action="store", default=NA, type='character',
              help="Path to the foreground binary mask.")
)
opt = parse_args(OptionParser(option_list=option_list))

if (is.na(opt$img)) {
   cat('User did not specify an input structural image.\n')
   cat('Use strucQA.R -h for an expanded usage menu.\n')
   quit()
}
if (is.na(opt$whitemask)) {
   cat('User did not specify an input white matter binary mask.\n')
   cat('Use strucQA.R -h for an expanded usage menu.\n')
   quit()
}
if (is.na(opt$graymask)) {
   cat('User did not specify an input gray matter binary mask.\n')
   cat('Use strucQA.R -h for an expanded usage menu.\n')
   quit()
}
if (is.na(opt$foreground)) {
   cat('User did not specify an input foreground binary mask.\n')
   cat('Use strucQA.R -h for an expanded usage menu.\n')
   quit()
}


imgpath <- opt$img
gmpath <- opt$graymask
wmpath <- opt$whitemask
fgmaskpath <- opt$foreground
if(!is.na(opt$cortical)) {
  copath <- optcortical
  cimg <- antsImageRead(copath,3)
}


###################################################################
# Load all of our images
###################################################################
suppressMessages(require(ANTsR))
img <- antsImageRead(imgpath,3)
fgimg <- antsImageRead(fgmaskpath,3)
gimg <- antsImageRead(gmpath,3)
wimg <- antsImageRead(wmpath,3)


###################################################################
# Now create all of our variables
###################################################################
fgvals <- img[fgimg==1]
bgvals <- img[fgimg==0]
gmvals <- img[gimg==1]
wmvals <- img[wimg==1]
if(!is.na(opt$cortical)){
  cvals <- img[cimg==1]
}

###################################################################
# Now calculate FBER
###################################################################
FBER <- (sum(fgvals^2) / sum(bgvals^2))

###################################################################
# Now calculate SNR
###################################################################
SNR <- mean(gmvals) / sd(bgvals)

###################################################################
# Now calculate CNR
###################################################################
CNR <- abs(mean(gmvals) - mean(wmvals)) / sd(bgvals)

###################################################################
# Now calculate Cortical Contrasts
###################################################################
if(!is.na(opt$cortical)){
  CORTCON <- (mean(wmvals) - mean(gmvals)) / ((mean(gmvals) + mean(wmvals)) / 2)
}
###################################################################
# Now calculate QI1
###################################################################
all.vals <- append(fgvals, bgvals)
allLength <- length(all.vals)
# Calcaulate efc max
efc.max <- allLength * (1 / sqrt(allLength)) * (log(1/sqrt(allLength)))
# calculate total image entropy
b.max <- sqrt(sum(all.vals^2))
# Now calculate EFC
EFC <- (1.0 / efc.max) * sum((all.vals / b.max) * log((all.vals / b.max)), na.rm=T)

###################################################################
# Now calculate Kurtosis & Skewness values
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
GMKURT <- kurtosis(gmvals)
GMSKEW <- skewness(gmvals)
WMKURT <- kurtosis(wmvals)
WMSKEW <- skewness(wmvals)
BGKURT <- kurtosis(bgvals)
BGSKEW <- skewness(bgvals)
###################################################################
# Now write output values
###################################################################
output <- NULL
output <- rbind(FBER, SNR, CNR, CORTCON, EFC, GMKURT, GMSKEW, WMKURT, WMSKEW, BGKURT, BGSKEW)
write(paste(output, sep=','), stdout())
