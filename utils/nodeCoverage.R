#!/usr/bin/env Rscript

################################################################### 
#  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  #
###################################################################

###################################################################
# Function for coverage computation and removal of values that
# fail some threshold
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
              help="A 3D image specifying the extent of the brain."),
   make_option(c("-r", "--roi"), action="store", default=NA, type='character',
              help="A 3D image specifying the nodes or regions of interest
                  for which coverage is to be assessed."),
   make_option(c("-t", "--thr"), action="store", default=0.5, type='numeric',
              help="The minimum coverage required for an RoI-wise value
                  to be included."),
   make_option(c("-x", "--idx"), action="store", default=NA, type='character',
              help="A list of indices corresponding to relevant regions
                  in the r argument."),
   make_option(c("-n", "--names"), action="store", default=NA, type='character',
              help="A list of names corresponding to the regions passed to
                  argument i.")
)
opt = parse_args(OptionParser(option_list=option_list))

if (is.na(opt$img)) {
   cat('User did not specify an input timeseries.\n')
   cat('Use coverage.R -h for an expanded usage menu.\n')
   quit()
}
if (is.na(opt$roi)) {
   cat('User did not specify an input RoI map.\n')
   cat('Use coverage.R -h for an expanded usage menu.\n')
   quit()
}

impath                  <- opt$img
roipath                 <- opt$roi
thr                     <- opt$thr
if (!is.na(opt$idx)) {
   labs                 <- as.vector(unlist(read.table(opt$idx,header=F)))
} else {
   labs                 <- NaN
}
if (!is.na(opt$names)) {
   name                 <- as.vector(unlist(read.table(opt$names,header=F)))
} else {
   name                 <- NaN
}
###################################################################
# 1. Load in the image.
###################################################################
img                     <- readNifti(impath)

###################################################################
# 2. Load in the network map
###################################################################
net                     <- readNifti(roipath)

###################################################################
# 3. Compute the RoI-wise coverage. This functionality is based
#    on the matrix2timeseries function from ANTsR, written by
#    Shrinidhi KL.
#
# First, obtain all unique nonzero values in the mask.
###################################################################
options(warn=-1)
if (is.nan(labs)) {
   labs                 <- sort(unique(net[net > 0]))
}
options(warn=0)
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
dim(mat)                <- c(sum(logmask), 1)
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
   mmat                 <- 1 - sum(mat==0)/length(mat)
} else {
   mmat                 <- zeros(dim(mat)[1],length(labs))
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
   if (length(voxelwise) == 1) {
      warning(paste("Warning: node ", labs[1], " contains one voxel\n"))
   }
   mmat[,1]             <- 1 - sum(voxelwise==0)/length(voxelwise)
   ################################################################
   # Repeat for all remaining RoIs.
   ################################################################
   for (i in 2:length(labs)) {
      voxelwise         <- mat[, nodevec == labs[i]]
      if (length(voxelwise) == 1) {
         warning(paste("Warning: node ", labs[i], " contains one voxel\n"))
      }
      mmat[,i]          <- 1 - sum(voxelwise==0)/length(voxelwise)
   }
}
mthr                    <- labs[which(mmat > thr)]
name                    <- name[which(mmat > thr)]

###################################################################
# 4. Write the output.
###################################################################

cat(mthr,sep=',')
cat('\n')
cat(name,sep=',')
