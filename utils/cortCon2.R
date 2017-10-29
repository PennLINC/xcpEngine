#!/usr/bin/env Rscript

###################################################################
#  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  #
###################################################################

###################################################################
# This script is an alternative to cortCon.R. It runs considerably
# faster but might give less accurate results. It also requires
# the nearest WM voxel already be computed, for instance by
# propagating unique WM voxel labels from the WM edge into the GM
# edge using ImageMaths dilation.
#
# It finds the closest WM voxel to each GM voxel 1mm from the
# WM-GM edge. It will then find the cortical contrast value (WM/GM)
# for each voxel and write out a voxel wise map for these values.
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
make_option(c("-G", "--gmimg"), action="store", default=NA, type='character',
help="A map of the grey matter boundary wherein each voxel encodes
      the nearest WM voxel"),
make_option(c("-W", "--wmimg"), action="store", default=NA, type='character',
help="A map of the white matter boundary wherein each voxel is 
      assigned a unique value"),
make_option(c("-T", "--t1"), action="store", default=NA, type='character',
help="Path to the T1 structural image on which CortCon is to be 
      computed"),
make_option(c("-o", "--outimg"), action="store", default=NA, type='character',
help="Output path for voxelwise CortCon")
)

opt = parse_args(OptionParser(option_list=option_list))
if (is.na(opt$gmimg)) {
    cat('User did not specify an input GM image.\n')
    cat('Use cortCon.R -h for an expanded usage menu.\n')
    quit()
}
if (is.na(opt$wmimg)) {
    cat('User did not specify an input WM image.\n')
    cat('Use cortCon.R -h for an expanded usage menu.\n')
    quit()
}
if (is.na(opt$outimg)) {
    cat('User did not specify an output path.\n')
    cat('Use cortCon.R -h for an expanded usage menu.\n')
    quit()
}
if (is.na(opt$t1)) {
    cat('User did not specify an input T1 image.\n')
    cat('Use cortCon.R -h for an expanded usage menu.\n')
    quit()
}

gmpath               <- opt$gmimg
wmpath               <- opt$wmimg
strucpath            <- opt$t1
out                  <- opt$outimg





###################################################################
# 1. Load images
###################################################################
gmVal                <- readNifti(gmpath)
wmVal                <- readNifti(wmpath)
strVal               <- readNifti(strucpath)

###################################################################
# 2. Identify valid voxel values
###################################################################
gmBoo                <- (gmVal!=0)
gmVox                <- gmVal[gmBoo]
gmVal                <- strVal[gmBoo]
wmBoo                <- (wmVal!=0)
wmVox                <- wmVal[wmBoo]
wmVal                <- strVal[wmBoo]
ccVal                <- gmVal - gmVal

###################################################################
# 3. Compute the WM counterpart for each GM voxel.
###################################################################
gmVals               <- sort(unique(gmVox))
for (i in gmVals) {
   idx               <- which(gmVox==i)
   closest_wm        <- which(wmVox==i)
   ccVal[idx]        <- wmVal[closest_wm]/gmVal[idx]
}

###################################################################
# 4. Write output
###################################################################
cc                   <- readNifti(gmpath)
cc[gmBoo]            <- ccVal
writeNifti(cc, out, template=gmpath)
