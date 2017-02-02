#!/usr/bin/env Rscript

###################################################################
#  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  #
###################################################################

###################################################################
# This script outputs a spatial coordinates library (.sclib)
# where each coordinate represents the centre of mass of one node
# of the input network.
###################################################################

###################################################################
# Load required libraries
###################################################################
suppressMessages(require(optparse))
suppressMessages(require(pracma))
#suppressMessages(require(ANTsR))

###################################################################
# Parse arguments to script, and ensure that the required arguments
# have been passed.
###################################################################
option_list = list(
   make_option(c("-r", "--roi"), action="store", default=NA, type='character',
              help="A 3D image specifying the nodes or regions of interest
                  from which timeseries are to be extracted.")
)
opt = parse_args(OptionParser(option_list=option_list))

if (is.na(opt$roi)) {
   cat('User did not specify an input RoI map.\n')
   cat('Use cmass.R -h for an expanded usage menu.\n')
   quit()
}
sink(file = '/dev/null')
roipath <- opt$roi

###################################################################
# 1. Load in the network map
###################################################################
suppressMessages(require(ANTsR))
net <- as.array(antsImageRead(roipath,3))

###################################################################
# 2. First, obtain all values corresponding to unique RoIs.
###################################################################
labs <- sort(unique(net[net > 0]))

###################################################################
# 3. Then, compute a centre of mass for each.
###################################################################
sink(file = NULL)
syscom <- paste('fslval',roipath,'pixdim1')  
xdim <- as.numeric(system(syscom,intern=TRUE))
syscom <- paste('fslval',roipath,'pixdim2')  
ydim <- as.numeric(system(syscom,intern=TRUE))
syscom <- paste('fslval',roipath,'pixdim3')  
zdim <- as.numeric(system(syscom,intern=TRUE))
cat('SPACE::VOXEL::')
cat(paste(xdim,ydim,zdim,sep=','))
cat('::')
cat(roipath,'\n')
for (i in 1:length(labs)) {
   voxelwise <- which(net==labs[i], arr.ind=TRUE)
   cmass <- apply(voxelwise,2,mean) - c(1,1,1)
   outln <- paste(paste('#node',i,sep=''),paste(as.vector(cmass),collapse=','),5,sep='#')
   cat(outln,'\n')
}
