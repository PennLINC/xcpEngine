#!/usr/bin/env Rscript

###################################################################
#  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  #
###################################################################

###################################################################
# Function for converting a voxelwise map of regions of interest
# and a community assignment vector into a voxelwise map of
# communities
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
   make_option(c("-c", "--com"), action="store", default=NA, type='character',
              help="A vector representing the community assignments of
                  all regions of interest."),
   make_option(c("-r", "--roi"), action="store", default=NA, type='character',
              help="A 3D image specifying the nodes or regions of interest
                  that are assigned to communities."),
   make_option(c("-o", "--out"), action="store", default=NA, type='character',
              help="Path where the voxelwise map of communities will be
                  written.")
)
opt = parse_args(OptionParser(option_list=option_list))

if (is.na(opt$com)) {
   cat('User did not specify a community assignment vector.\n')
   cat('Use com2map.R -h for an expanded usage menu.\n')
   quit()
}
if (is.na(opt$roi)) {
   cat('User did not specify an input RoI map.\n')
   cat('Use com2map.R -h for an expanded usage menu.\n')
   quit()
}
if (is.na(opt$out)) {
   cat('User did not specify an output path.\n')
   cat('Use com2map.R -h for an expanded usage menu.\n')
   quit()
}

roipath <- opt$roi
com               <- as.numeric(unname(unlist(read.table(opt$com,header=FALSE))))
outpath           <- opt$out

###################################################################
# 1. Load in the map of regions of interest.
###################################################################
roi               <- readNifti(roipath)
out               <- roi

###################################################################
# 2. Replace all ROI labels with community labels.
###################################################################
labs              <- sort(unique(roi[roi > 0]))
coms              <- sort(unique(com))
for (c in coms) {
   com_rois       <- which(com==c)
   logmask        <- which(roi %in% com_rois)
   out[logmask]   <- c
}

###################################################################
# 3. Write out the image
###################################################################
writeNifti(out,outpath,template=roipath)
