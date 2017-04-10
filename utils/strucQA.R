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
              help="Path to the structural image"),
   make_option(c("-m", "--mask"), action="store", default=NA, type='character',
              help="Path to the foreground mask to be used, inverse will be used as the BG mask."),
   make_option(c("-s", "--seg"), action="store", default=NA, type='character',
              help="Path to the three class segmentation mask")
)
opt = parse_args(OptionParser(option_list=option_list))

if (is.na(opt$img)) {
   cat('User did not specify an input timeseries.\n')
   cat('Use strucQA.R -h for an expanded usage menu.\n')
   quit()
}

imgpath <- opt$img
fgmaskpath <- opt$mask
segmaskpath <- opt$seg

###################################################################
# Load all of our images
###################################################################
suppressMessages(require(ANTsR))
img <- antsImageRead(imgpath,3)
fgimg <- antsImageRead(fgmaskpath,3)
segimg <- antsImageRead(segmaskpath,3)

###################################################################
# Now create all of our variables
###################################################################
fgvals <- img[fgimg==2]
bgvals <- img[fgimg==1]
csfvals <- img[segimg==1]
gmvals <- img[segimg==2]
wmvals <- img[segimg==3]

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
CORTCON <- (mean(wmvals) - mean(gmvals)) / ((mean(gmvals) + mean(wmvals)) / 2)

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
