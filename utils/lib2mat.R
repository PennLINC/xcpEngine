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
                     minkowski")
)
opt = parse_args(OptionParser(option_list=option_list))

if (is.na(opt$coors)) {
   cat('User did not specify an input coordinates library.\n')
   cat('Use lib2mat.R -h for an expanded usage menu.\n')
   quit()
}
coorPath <- opt$coors
metric <- opt$metric
rescale <- NA

###################################################################
# 1. Obtain the library's scaling factor if it is in voxel space.
###################################################################
space <- readLines(coorPath)[grep('SPACE::',readLines(coorPath))]
spaceType <- unlist(strsplit(space,':'))[3]
if (spaceType == 'VOXEL') {
   rescale <- strsplit(unlist(strsplit(space,':'))[5],',')
   rescale <- as.numeric(unlist(rescale))
}

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
