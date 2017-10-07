#! /usr/bin/env Rscript

###################################################################
#  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  #
###################################################################

###################################################################
# R script to compute DVARS
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
              help="Path to the BOLD timeseries"),
   make_option(c("-m", "--mask"), action="store", default=NA, type='character',
              help="Path to a whole-brain mask.")
)

opt = parse_args(OptionParser(option_list=option_list))
impath               <- opt$img
maskpath             <- opt$mask
rad2mm               <- opt$convert

if (is.na(opt$img)) {
   cat('User did not specify path to the BOLD timeseries.\n')
   cat('Use dvars.R -h for an expanded usage menu.\n')
   quit()
}

###################################################################
# Read in the image and mask files, and construct derivative
# timeseries.
###################################################################
img                  <- readNifti(impath)
hdr                  <- dumpNifti(impath)
mask                 <- readNifti(maskpath)
logmask              <- (mask == 1)
img                  <- img[logmask]
dim(img)             <- c(sum(logmask),hdr$dim[5])
img                  <- t(img)
ts1                  <- img[1:(size(img,1)-1),]
ts2                  <- img[2:size(img,1),]
tsderiv              <- ts2 - ts1

###################################################################
# Compute the square of the derivative.
###################################################################
tdsq                 <- tsderiv^2

###################################################################
# Compute the mean over space.
###################################################################
tdmeansq             <- apply(tdsq,1,mean)

###################################################################
# Compute the RMS, and prepend a 0 to obtain DVARS.
###################################################################
tdrms                <- sqrt(tdmeansq)
dvars                <- c(0,tdrms)

###################################################################
# Write output
###################################################################
for (i in 1:length(dvars)){
   cat(dvars[i])
   cat('\n')
}
