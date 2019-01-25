#!/usr/bin/env Rscript
###################################################################
#  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  #
###################################################################

###################################################################
# script for converting a temporal mask into a set of spike
# regressors
###################################################################

###################################################################
# Load required libraries
###################################################################
suppressMessages(suppressWarnings(library(optparse)))
suppressMessages(suppressWarnings(library(pracma)))
suppressMessages(suppressWarnings(library(MASS)))

###################################################################
# Parse arguments to script, and ensure that the required arguments
# have been passed.
###################################################################
option_list = list(
   make_option(c("-m", "--mask"), action="store", default=NA, type='character',
              help="Path to a binary temporal mask"),
   make_option(c("-o", "--out"), action="store", default=NA, type='character',
              help="Path to outputh"),
   make_option(c("-i", "--input"), action="store", default=NA, type='character',
              help="input and is compulsory. If 
                     specified, the output will combine the spike
                     regressors with this matrix.")
)
opt = parse_args(OptionParser(option_list=option_list))

if (is.na(opt$mask)) {
   cat('User did not specify an input timeseries.\n')
   cat('Use 1mask.R -h for an expanded usage menu.\n')
   quit()
}

tmask <- as.matrix(read.table(opt$mask,header=FALSE))
file <- as.matrix(read.table(opt$input,header=FALSE))

###################################################################
# Identify time points marked for exclusion in the mask.
###################################################################
exc <- which(tmask==0)
if (length(exc) == 0){
   quit()
}

###################################################################
# remove the mask with 0
###################################################################
inputs=file[-exc]


###################################################################
# write out the output
###################################################################
write.matrix(inputs,opt$out)

