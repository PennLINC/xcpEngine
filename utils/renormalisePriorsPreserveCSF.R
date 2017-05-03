#!/usr/bin/env Rscript

###################################################################
# This is a wrapper around functionality that was originally
# implemented by the ANTs team. It is intended to reweight all
# priors created in the JLF/JIF stage of the template construction
# procedure in order to produce a CSF prior that includes
# peripheral CSF in addition to ventricular CSF.
###################################################################

###################################################################
# Load required libraries
###################################################################
suppressMessages(require(optparse))
#suppressMessages(require(ANTsR))

###################################################################
# Parse arguments to script, and ensure that the required arguments
# have been passed.
###################################################################
option_list = list(
   make_option(c("-m", "--mask"), action="store", default=NA, type='character',
              help="Binary mask image."),
   make_option(c("-c", "--csf"), action="store", default=NA, type='character',
              help="Probabilistic CSF prior."),
   make_option(c("-i", "--img"), action="store", default=NA, type='character',
              help="Comma-separated paths to remaining priors."),
   make_option(c("-o", "--out"), action="store", default=NA, type='character',
              help="Root output path.")
)
opt = parse_args(OptionParser(option_list=option_list))

if (is.na(opt$csf)) {
   cat('User did not specify the CSF prior.\n')
   cat('Use ~.R -h for an expanded usage menu.\n')
   quit()
}
if (is.na(opt$img)) {
   cat('User did not specify sufficient priors.\n')
   cat('Use ~.R -h for an expanded usage menu.\n')
   quit()
}
if (is.na(opt$out)) {
   cat('User did not specify the output path.\n')
   cat('Use ~.R -h for an expanded usage menu.\n')
   quit()
}
if (is.na(opt$mask)) {
   cat('User did not specify the mask.\n')
   cat('Use ~.R -h for an expanded usage menu.\n')
   quit()
}

impaths <- opt$img
csfpath <- opt$csf
maskpath <- opt$mask
outputRoot <- opt$out

###################################################################
# Define a helper function to write outputs. Written by the ANTs
# team, like nearly everything in this utility.
###################################################################
suppressMessages(require(ANTsR))
writeImages <- function(images, outputRoot) {

   for (i in 1:length(images)) {
      antsImageWrite(images[[i]], paste(outputRoot, sprintf("%03d", i), ".nii.gz", sep=""))
   }

}

###################################################################
# Change comma-separated input paths to a list of antsImages.
###################################################################
impaths <- unlist(strsplit(impaths,','))
priorImages <- list(NULL)
priorImages[1] <- antsImageRead(csfpath,3)
for (i in 2:(length(impaths)+1)) {
   priorImages[i] <- antsImageRead(impaths[i-1],3)
}

###################################################################
# Read in the mask and determine the total number of voxels under
# consideration.
###################################################################
mask <- antsImageRead(maskpath,3)

###################################################################
# Determine the total probability of each voxel being non-CSF.
###################################################################
csfPrior <- priorImages[[1]][mask > 0]
nonCSF_Total <- 1 - csfPrior

###################################################################
# Preallocate the voxelwise probability matrix.
###################################################################
numClasses <- length(priorImages)
numVoxels <- length(which(mask > 0))
labelProbs <- vector("list", numClasses)
priors <- matrix(nrow = numClasses, ncol = numVoxels)

###################################################################
# Load the pre-normalised values into the probability matrix.
###################################################################
priors[1, ] <- csfPrior
for (c in 2:numClasses) {
   priors[c, ] <- priorImages[[c]][mask > 0]
}

###################################################################
# Determine the total voxelwise probability of all non-CSF tissue.
###################################################################
sumNonCSF <- colSums(priors[2:numClasses,])

###################################################################
# If there's 0 probability of anything else, set CSF prior to 1
###################################################################
priors[1,which(sumNonCSF == 0)] = 1

###################################################################
# Avoid divide by zero below
###################################################################
sumNonCSF[which(sumNonCSF == 0)] <- 1

###################################################################
# Renormalize
###################################################################
for (c in 2:numClasses) {
   priors[c,] <- nonCSF_Total * priors[c,] / sumNonCSF
}

###################################################################
# Output renormalised priors.
###################################################################
writeImages(matrixToImages(priors, mask),  outputRoot)
