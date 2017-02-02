#!/usr/bin/env Rscript

###################################################################
#  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  #
###################################################################

###################################################################
# Function for obtaining spatial cross correlation and fractional
# coverage indices from a pair of single volumes divided into
# discrete regions of interest.
#
# If your ROIs are diffuse and/or contained in multiple volumes,
# and unless you absolutely have to use this function, use fslcc
# or 3dROIstats
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
   make_option(c("-i", "--in"), action="store", default=NA, type='character',
              help="A path to the first map of regions of interest"),
   make_option(c("-r", "--ref"), action="store", default=NA, type='character',
              help="A path to the second map of regions of interest.")
)
opt = parse_args(OptionParser(option_list=option_list))

if (is.na(opt$in) | is.na(opt$ref)) {
   cat('User did not specify two input maps.\n')
   cat('Use roicc.R -h for an expanded usage menu.\n')
   quit()
}

###################################################################
# 
###################################################################
