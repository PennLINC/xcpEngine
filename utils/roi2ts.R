#!/usr/bin/env Rscript

################################################################### 
#  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  #
###################################################################

###################################################################
# Utility script adaptation of Srinidhi KL's timeseries2matrix
#
# roi2ts uses an input network map or mask and a BOLD timeseries
# to generate node-specific timeseries for all network elements
###################################################################

###################################################################
# Load required libraries
###################################################################
suppressMessages(require(optparse))
suppressMessages(require(pracma))
suppressMessages(require(RNifti))

###################################################################
# Parse arguments to script, and ensure that the required arguments
# have been passed.
###################################################################
option_list = list(
   make_option(c("-i", "--img"), action="store", default=NA, type='character',
              help="Path to the 4d BOLD timeseries from which the timeseries
                  will be extracted."),
   make_option(c("-r", "--roi"), action="store", default=NA, type='character',
              help="A 3D image specifying the nodes or regions of interest
                  from which timeseries are to be extracted.")
)
opt = parse_args(OptionParser(option_list=option_list))

if (is.na(opt$img)) {
   cat('User did not specify an input timeseries.\n')
   cat('Use roi2ts.R -h for an expanded usage menu.\n')
   quit()
}
if (is.na(opt$roi)) {
   cat('User did not specify an input RoI map.\n')
   cat('Use roi2ts.R -h for an expanded usage menu.\n')
   quit()
}

impath                  <- opt$img
roipath                 <- opt$roi

###################################################################
# 1. Load in the image.
###################################################################
img                     <- readNifti(impath)

###################################################################
# 2. Load in the network map
###################################################################
net                     <- readNifti(roipath)

###################################################################
# 3. Compute the network timeseries. This functionality is based
#    on the matrix2timeseries function from ANTsR, written by
#    Shrinidhi KL.
#
# First, obtain all unique nonzero values in the mask.
###################################################################
labs                    <- sort(unique(net[net > 0]))
###################################################################
# Create a logical over all voxels, indicating whether each
# voxel has a nonzero mask value.
###################################################################
logmask                 <- (net > 0)
###################################################################
# Use the logical mask to subset the 4D data. Determine the
# dimensions of the timeseries matrix: they should equal
# the number of voxels in the mask by the number of time points.
###################################################################
mat                     <- img[logmask]
dim(mat)                <- c(sum(logmask), dim(img)[length(dim(img))])
mat                     <- t(mat)
###################################################################
# Determine how many unique values are present in the RoI map.
#  * If only one unique value is present, then the desired
#    output is a voxelwise timeseries matrix, which has already
#    been computed.
#  * If multiple unique values are present in the map, then
#    the map represents a network, and the desired output is
#    a set of mean node timeseries.
###################################################################
if (length(labs) == 1) {
   mmat                 <- mat
} else {
   mmat                 <- zeros(dim(mat)[1],max(labs))
   ################################################################
   # If the script enters this statement, then there are multiple
   # unique values in the map, indicating multiple mask RoIs: a
   # network timeseries analysis should be prepared.
   #
   # Prime the modified matrix. Extract the timeseries of all
   # voxels in the first RoI submask. If only one voxel is in the
   # RoI, then the extracted timeseries will lack dimension
   # according to R; it must be made into a column vector so that
   # it can be appended to the modified matrix. The user is warned,
   # as singleton voxels are more susceptible to artefactual
   # influence. If multiple voxels are in the RoI, then the mean
   # RoI timeseries is computed and added to the model.
   ################################################################
   nodevec              <- net[logmask]
   voxelwise            <- mat[, nodevec == labs[1]]
   if (is.null(dim(voxelwise)) && !is.null(length(voxelwise))) {
      warning("Warning: node 1 contains one voxel\n")
      dim(voxelwise)    <-c(length(voxelwise),1)
   }
   mmat[,labs[1]]       <- matrix(apply(voxelwise, FUN = mean, MARGIN = 1), ncol = 1)
   ################################################################
   # Repeat for all remaining RoIs.
   ################################################################
   for (i in 2:length(labs)) {
      voxelwise         <-mat[, nodevec == labs[i]]
      if (is.null(dim(voxelwise)) && !is.null(length(voxelwise))) {
         warning(paste("Warning: node ", labs[i], " contains one voxel\n"))
         dim(voxelwise) <-c(length(voxelwise),1)
      }
      mmat[,labs[i]]    <- matrix(apply(voxelwise, FUN = mean, MARGIN = 1), ncol = 1)
   }
   colnames(mmat)       <- paste("L", 1:max(labs))
}

################################################################### 
# 4. Write the output.
###################################################################

for (row in seq(1,dim(mmat)[1])) {
   cat(mmat[row,])
   cat('\n')
}
