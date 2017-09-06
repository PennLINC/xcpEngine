#!/usr/bin/env Rscript

################################################################### 
#  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  #
###################################################################

###################################################################
# sclib2mat reads in a spatial coordinates library and outputs
# a matrix of the pairwise distance between all points in the
# library
###################################################################

###################################################################
# Load required libraries
###################################################################
suppressMessages(require(optparse))
suppressMessages(require(pracma))

###################################################################
# Parse arguments to script, and ensure that the required arguments
# have been passed.
###################################################################
option_list = list(
   make_option(c("-c", "--coors"), action="store", default=NA, type='character',
              help="Path to the spatial coordinates library from which the 
                     distance matrix will be constructed."),
   make_option(c("-m", "--metric"), action="store", default='euclidean', type='character',
              help="Distance metric. Available options include: manhattan, 
                     euclidean [default], maximum, canberra, binary, 
                     minkowski"),
   make_option(c("-r", "--rescale"), action="store", default='1,1,1', type='character',
              help="Rescale values. This argument should be used if the seed
                     library is declared in voxel space that is not 1mm
                     isotropic. It should consist of three comma-separated
                     numbers corresponding to the voxel dimensions in the
                     x, y, and z directions. For instance, '-r 1,1,4' will
                     result in rescaling of distances by 1 in the x and
                     y directions and 4 in the z direction.")
)
opt = parse_args(OptionParser(option_list=option_list))

if (is.na(opt$coors)) {
   cat('User did not specify an input coordinates library.\n')
   cat('Use lib2mat.R -h for an expanded usage menu.\n')
   quit()
}
coorPath          <- opt$coors
metric            <- opt$metric
rescale           <- opt$rescale

###################################################################
# 1. Obtain the library's scaling factor if it is in voxel space.
###################################################################
rescale <- as.numeric(unlist(strsplit(rescale,',')))

###################################################################
# 2. Read in all coordinates, and rescale them if necessary.
###################################################################
coor <- readLines(coorPath)[grep('^#',readLines(coorPath))]
coor <- lapply(coor, function(x) unlist(strsplit(x,'#'))[3])
coor <- lapply(coor, function(x) as.numeric(unlist(strsplit(x,','))))
if (!is.na(rescale[1])){
   coor <- lapply(coor, function(x) x*rescale)
}

###################################################################
# 3. Compute the pairwise distance.
###################################################################
coor <- t(Reshape(unlist(coor),3,))
distmat <- as.matrix(dist(coor,upper = TRUE,method=metric))

###################################################################
# 4. Print the distance matrix
###################################################################
for (row in seq(1,dim(distmat)[1])) {
   cat(distmat[row,])
   cat('\n')
}
