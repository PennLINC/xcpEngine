#!/usr/bin/env Rscript

###################################################################
#  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  #
###################################################################

###################################################################
# Function for generating a volumetric coverage criterion for all
# subjects in a cohort
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
   make_option(c("-i", "--imcsv"), action="store", default=NA, type='character',
              help="Path to the .csv specifying paths to all subject-level
                     masks registered to a standard space"),
   make_option(c("-m", "--mask"), action="store", default=NA, type='character',
              help="Spatial mask indicating the standard-space voxels that
                     should be treated as 'control points'; any subjects whose
                     normalised masks fail to include at least some number
                     of these control points will be flagged for exclusion"),
   make_option(c("-p", "--points"), action="store", default=1, type='numeric',
              help="The minimum fraction of control points that a mask
                     must include in order to pass the coverage criterion
                     [default 1, or all control points]"),
   make_option(c("-o", "--omask"), action="store", default=NA, type='character',
              help="Path where a probabilistic spatial mask of voxelwise
                     coverage in standard space will be written")
)

opt = parse_args(OptionParser(option_list=option_list))

if (is.na(opt$imcsv)) {
   cat('User did not specify an input cohort of standard-space masks.\n')
   cat('Use coverMask.R -h for an expanded usage menu.\n')
   quit()
}
if (is.na(opt$mask)) {
   cat('User did not specify an input mask of control points.\n')
   cat('Use coverMask.R -h for an expanded usage menu.\n')
   quit()
}

impaths <- read.csv(opt$imcsv,header=FALSE)
mpath <- opt$mask
thr <- opt$points
opath <- opt$omask

###################################################################
# 1. Load in the control points.
###################################################################
suppressMessages(require(ANTsR))
ctrl <- as.array(antsImageRead(mpath,3))
ctrlog <- as.logical(ctrl)
ctrl <- ctrl[ctrlog]
sdim <- length(ctrl)

###################################################################
# 2. Iterate through all standardised subject masks.
###################################################################
maskscol <- dim(impaths)[2]
nmasks <- dim(impaths)[1]
sdim <- c(sdim,nmasks)
masks <- array(dim=sdim)
fail <- 0
pass <- 0
for (i in 1:nmasks) {
   tmp <- as.array(antsImageRead(as.character(impaths[i,maskscol]),3))
   masks[,i] <- tmp[ctrlog]
   if (mean(masks[,i]) < thr) {
      for (j in 1:maskscol) { cat(as.character(impaths[i,j]),',',sep='') }
      cat(mean(masks[,i]),'0\n',sep=',')
      fail <- fail + 1
   } else {
      for (j in 1:maskscol) { cat(as.character(impaths[i,j]),',',sep='') }
      cat(mean(masks[,i]),'1\n',sep=',')
      pass <- pass + 1
   }
}
warning(as.character(pass),' subjects passed coverage criteria\n')
warning(as.character(fail),' subjects failed coverage criteria\n')
