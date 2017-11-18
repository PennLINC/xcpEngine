#!/usr/bin/env Rscript

###################################################################
#  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  #
###################################################################

###################################################################
# Function for computing similarity indices between a pair of
# binary images (masks).
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
   make_option(c("-m", "--mask"), action="store", default=NA, type='character',
              help="A path to the first mask."),
   make_option(c("-r", "--reference"), action="store", default=NA, type='character',
              help="A path to the second mask.")
)
opt = parse_args(OptionParser(option_list=option_list))

if (is.na(opt$mask)) {
   cat('User did not specify two input masks.\n')
   cat('Use maskOverlap.R -h for an expanded usage menu.\n')
   quit()
}
if (is.na(opt$reference)) {
   cat('User did not specify two input masks.\n')
   cat('Use maskOverlap.R -h for an expanded usage menu.\n')
   quit()
}

mask1path <- opt$mask
mask2path <- opt$reference

###################################################################
# 1. Load in the masks
###################################################################
mask1                <- as.logical(readNifti(mask1path))
mask2                <- as.logical(readNifti(mask2path))
###################################################################
# Compute some preliminary values.
###################################################################
mask_intersect       <- mask1 * mask2
vol1                 <- sum(mask1)
vol2                 <- sum(mask2)
vol_intersect        <- sum(mask_intersect)
vol_union            <- vol1 + vol2 - vol_intersect
if(vol1 <= vol2) {
   vol_small         <- vol1
} else {
   vol_small         <- vol2
}

###################################################################
# 2. Cross-correlation
###################################################################
cc <- cor(mask1,mask2)
cat('· [Cross-correlation:   ',cc,']\n', file=stderr())
cat(cc, '\n')

###################################################################
# 3. Coverage
###################################################################
cov <- vol_intersect/vol_small
cat('· [Coverage:            ',cov,']\n', file=stderr())
cat(cov, '\n')

###################################################################
# 4. Jaccard
###################################################################
jacc <- vol_intersect/vol_union
cat('· [Jaccard coefficient: ',jacc,']\n', file=stderr())
cat(jacc, '\n')

###################################################################
# 5. Dice
###################################################################
dice <- 2 * vol_intersect / (vol1 + vol2)
cat('· [Dice coefficient:    ',dice,']\n', file=stderr())
cat(dice, '\n')
