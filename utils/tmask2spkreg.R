#!/usr/bin/env Rscript

###################################################################
#  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  #
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

###################################################################
# Parse arguments to script, and ensure that the required arguments
# have been passed.
###################################################################
option_list = list(
   make_option(c("-t", "--tmask"), action="store", default=NA, type='character',
              help="Path to a binary temporal mask"),
   make_option(c("-r", "--regmat"), action="store", default=NA, type='character',
              help="[optional] Path to a matrix of regressors. If 
                     specified, the output will combine the spike
                     regressors with this matrix.")
)
opt = parse_args(OptionParser(option_list=option_list))

if (is.na(opt$tmask)) {
   cat('User did not specify an input timeseries.\n')
   cat('Use tmask2spkreg.R -h for an expanded usage menu.\n')
   quit()
}

tmask <- as.matrix(read.table(opt$tmask,header=FALSE))

###################################################################
# Identify time points marked for exclusion in the mask.
###################################################################
exc <- which(tmask==0)
if (length(exc) == 0){
   quit()
}

###################################################################
# Generate a matrix of spike regressors.
###################################################################
spkreg <- zeros(length(tmask),length(exc))
for (i in 1:length(exc)){
   spkreg[exc[i],i] <- 1
}

###################################################################
# Bind it to any matrix of regressors passed as an argument
###################################################################
if(!is.na(opt$regmat)){
   regmat <- as.matrix(read.table(opt$regmat,header=FALSE))
   spkreg <- cbind(regmat,spkreg)
}

###################################################################
# Print the matrix.
###################################################################
for (i in 1:length(tmask)){
   cat(spkreg[i,], sep='\t')
   cat('\n')
}
