#! /usr/bin/env Rscript

###################################################################
#  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  #
###################################################################

###################################################################
# R script to compute the weighted mean timeseries within an RoI
# given the RoI map and a 4D voxelwise BOLD timeseries
###################################################################

###################################################################
# Load required libraries
###################################################################
suppressMessages(suppressWarnings(library(optparse)))
suppressMessages(suppressWarnings(library(RNifti)))

###################################################################
# Parse arguments to script, and ensure that the required arguments
# have been passed.
###################################################################
option_list = list(
   make_option(c("-i", "--img"), action="store", default=NA, type='character',
              help="Path to the 4D voxelwise timeseries from which
                  the RoI timeseries is to be extracted."),
   make_option(c("-r", "--roi"), action="store", default=NA, type='character',
              help="Spatial map of the region of interest.")
)
opt = parse_args(OptionParser(option_list=option_list))
impath               <- opt$img
out                  <- opt$out
roipath              <- opt$roi

if (is.na(opt$roi)) {
   cat('User did not specify a region of interest.\n')
   cat('Use tswmean.R -h for an expanded usage menu.\n')
   quit()
}
if (is.na(opt$img)) {
   cat('User did not specify an input timeseries.\n')
   cat('Use tswmean.R -h for an expanded usage menu.\n')
   quit()
}

###################################################################
# 1. Load in the image and RoI
###################################################################
hdr                  <- dumpNifti(impath)
roiImg               <- readNifti(roipath)
refImg               <- readNifti(impath)

###################################################################
# 2. Create a mask from the Roi; use this to extract voxelwise
#    timeseries and weights
###################################################################
roiMask              <- (roiImg!=0)
imgVals              <- refImg[roiMask]
dim(imgVals)         <- c(sum(roiMask),hdr$dim[5])
imgVals              <- t(imgVals)
roiVals              <- roiImg[roiMask]

###################################################################
# 3. Compute the weighted mean
###################################################################
wmeants              <- apply(imgVals,1,weighted.mean,w=roiVals)

################################################################### 
# 4. Write output
###################################################################
for (row in 1:length(wmeants)) {
   cat(wmeants[row],'\n')
}
