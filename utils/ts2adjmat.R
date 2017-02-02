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
suppressMessages(require(optparse))

###################################################################
# Parse arguments to script, and ensure that the required arguments
# have been passed.
###################################################################
option_list = list(
   make_option(c("-t", "--ts"), action="store", default=NA, type='character',
              help="Path to the timeseries from which the adjacency matrix
                  will be constructed.")
)
opt = parse_args(OptionParser(option_list=option_list))

if (is.na(opt$ts)) {
   cat('User did not specify an input timeseries.\n')
   cat('Use ts2adjmat.R -h for an expanded usage menu.\n')
   quit()
}
tsPath <- opt$ts

###################################################################
# 1. Read in the node timecourses
###################################################################
tc <- as.array(unname(read.table(tsPath)))

###################################################################
# 2. Compute the adjacency matrix
###################################################################
adjmat <- cor(tc)

###################################################################
# 3. Print the adjacency matrix
###################################################################
for (row in seq(1,dim(adjmat)[1])) {
   cat(adjmat[row,])
   cat('\n')
}
