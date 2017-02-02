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
sink("/dev/null")
suppressMessages(require(optparse))
#suppressMessages(require(ANTsR))

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
impath <- opt$img
out <- opt$out
roipath <- opt$roi

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
suppressMessages(require(ANTsR))
roiImg <- antsImageRead(roipath,3)
roi <- as.array(roiImg)
refImg <- antsImageRead(impath,4)

###################################################################
# 2. Create a mask from the Roi; use this to extract voxelwise
#    timeseries and weights
###################################################################

roiMask <- as.logical(roi)
dim(roiMask) <- dim(roi)
roiImg2 <- as.antsImage(roiMask)
antsCopyImageInfo(roiImg,roiImg2)
roiImg <- roiImg2
rm(roiImg2)
imgVals <- timeseries2matrix(refImg,roiImg)
roiVals <- roi[roiMask]

###################################################################
# 3. Compute the weighted mean
###################################################################

wmeants <- apply(imgVals,1,weighted.mean,w=roiVals)

################################################################### 
# 4. Write output
###################################################################
sink(NULL)
for (row in 1:length(wmeants)) {
   cat(wmeants[row],'\n')
}
