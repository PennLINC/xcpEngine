#!/usr/bin/env Rscript

###################################################################
#  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  #
###################################################################

###################################################################
# This script inputs an image and a range of values and outputs a
# binary mask covering the voxels in which the input image is equal
# to those values.
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
              help="Path to the reference image from which the mask is
                  to be created"),
   make_option(c("-v", "--values"), action="store", default=0, type='character',
              help="A string of comma-delimited numeric ranges that
                  represent the intensity values of the reference image
                  that should be included in the mask.
                  
                  Examples:
                  -v 1      : Create a binary mask including all voxels
                              where the reference has a value of 1
                  -v -1.2:3 : Create a binary mask including all voxels
                              where the reference has a value between
                              -1.2 and 3
                  -v 1:5,6:8: Create a binary mask including all voxels
                              where the reference has a value between 1
                              and 5 OR between 6 and 8
                  etc."),
   make_option(c("-o", "--out"), action="store", default=NA, type='character',
              help="Output path")
)
opt = parse_args(OptionParser(option_list=option_list))

if (is.na(opt$img)) {
   cat('User did not specify an input image.\n')
   cat('Use val2mask.R -h for an expanded usage menu.\n')
   quit()
}
if (is.na(opt$out)) {
   cat('User did not specify an output path.\n')
   cat('Use val2mask.R -h for an expanded usage menu.\n')
   quit()
}

refImgPath              <- opt$img
valStr                  <- opt$values
outPath                 <- opt$out
f <- file()
sink(tempfile())


###################################################################
# Parse value string
###################################################################
maskVals                <- unlist(strsplit(valStr,','))


###################################################################
# Read input image
###################################################################
refImg                  <- readNifti(refImgPath)
out                     <- refImg


###################################################################
# Subset image vector
###################################################################
outImgVec               <- refImg[refImg<Inf] * 0
valIdx                  <- c()
for (maskVal in maskVals) {
   bounds               <- as.numeric(unlist(strsplit(maskVal,':')))
   valIdx               <- refImg >= bounds[1] & refImg <= bounds[length(bounds)]
   outImgVec[valIdx]    <- 1
}


###################################################################
# Write output
###################################################################
out[out > -Inf]         <- outImgVec
sink("/dev/null")
writeNifti(out,outPath,template=refImgPath,datatype='float')
sink(NULL)
