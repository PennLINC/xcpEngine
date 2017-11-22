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
suppressMessages(suppressWarnings(library(optparse)))
suppressMessages(suppressWarnings(library(pracma)))
suppressMessages(suppressWarnings(library(RNifti)))

###################################################################
# Parse arguments to script, and ensure that the required arguments
# have been passed.
###################################################################
option_list = list(
   make_option(c("-r", "--roi"), action="store", default=NA, type='character',
              help="A 3D image specifying the nodes or regions of interest
                  for which centres of mass are to be computed.")
)
opt = parse_args(OptionParser(option_list=option_list))

if (is.na(opt$roi)) {
   cat('User did not specify an input RoI map.\n')
   cat('Use cmass.R -h for an expanded usage menu.\n')
   quit()
}
sink(file = '/dev/null')
roipath        <- opt$roi

###################################################################
# 1. Load in the network map
###################################################################
net            <- readNifti(roipath)

###################################################################
# 2. First, obtain all values corresponding to unique RoIs.
###################################################################
labs           <- sort(unique(net[net > 0]))

###################################################################
# 3. Then, compute a centre of mass for each.
###################################################################
sink(file = NULL)
hdr            <- dumpNifti(roipath)
xdim           <- hdr$pixdim[2]
ydim           <- hdr$pixdim[3]
zdim           <- hdr$pixdim[4]
cat('SPACE::',roipath,'\n',sep='')
for (i in 1:length(labs)) {
   voxelwise   <- which(net==labs[i], arr.ind=TRUE)
   cmass       <- apply(voxelwise,2,mean) - c(1,1,1)
   outln       <- paste(paste('#node',i,sep=''),paste(as.vector(cmass),collapse=','),5,sep='#')
   cat(outln,'\n')
}
