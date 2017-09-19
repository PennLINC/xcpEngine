#!/usr/bin/env Rscript

################################################################### 
#  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  #
###################################################################

###################################################################
# ts2adjmat reads in node-specific timeseries and uses them to
# construct an adjacency matrix
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
   make_option(c("-t", "--ts"), action="store", default=NA, type='character',
              help="Path to the timeseries from which the adjacency matrix
                  will be constructed."),
   make_option(c("-m", "--mask"), action="store", default=NA, type='character',
              help="Path to a binary-valued  temporal mask specifying time
                  points to include in the correlation.")
)
opt = parse_args(OptionParser(option_list=option_list))

if (is.na(opt$ts)) {
   cat('User did not specify an input timeseries.\n')
   cat('Use ts2adjmat.R -h for an expanded usage menu.\n')
   quit()
}
tsPath <- opt$ts
tmPath <- opt$mask

###################################################################
# 1. Read in the node timecourses
###################################################################
tc <- as.matrix(unname(read.table(tsPath,header=F)))
if (! is.na(tmPath)) {
   tm <- as.logical(unname(unlist(read.table(tmPath,header=F))))
   tc <- tc[tm,]
}

###################################################################
# 2. Compute the adjacency matrix
###################################################################
adjmat <- cor(tc)
adjmat[is.na(adjmat)] <- NaN
adjmat <- squareform(adjmat*(matrix(!diag(dim(adjmat)[1]),nrow=dim(adjmat)[1])))

###################################################################
# 3. Print the adjacency matrix
###################################################################
for (i in 1:length(adjmat)) {
   cat(adjmat[i],'\n')
}
