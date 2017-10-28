#!/usr/bin/env Rscript

###################################################################
#  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  #
###################################################################

###################################################################
# This script converts each voxel in a mask into a unique value
# corresponding to its index and then outputs the uniquified
# labels.
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
help="The input image to be uniquified"),
make_option(c("-o", "--out"), action="store", default=NA, type='character',
help="The path where the uniquified image is to be written")
)
opt = parse_args(OptionParser(option_list=option_list))

impath                     <- opt$img
out                        <- opt$out

if (is.na(opt$img)) {
    cat('User did not specify an input image.\n')
    cat('Use uniquifyVoxels.R -h for an expanded usage menu.\n')
    quit()
}
if (is.na(opt$out)) {
    cat('User did not specify an output path.\n')
    cat('Use uniquifyVoxels.R -h for an expanded usage menu.\n')
    quit()
}


img                        <- readNifti(impath)
imguniq                    <- which(img!=0)
img[imguniq]               <- seq(length(imguniq))
writeNifti(img,out)
