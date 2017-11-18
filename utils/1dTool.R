#! /usr/bin/env Rscript

###################################################################
#  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  #
###################################################################

###################################################################
# Operations on 1D files. Currently this is very simplistic, but
# functionality will be added as needed.
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
   make_option(c("-i", "--input"), action="store", default=NA, type='character',
              help="Path to the input 1D file"),
   make_option(c("-r", "--header"), action="store", default=FALSE, type='logical',
              help="Does the input file contain a header?"),
   make_option(c("-z", "--zeros"), action="store", default=FALSE, type='logical',
              help="Ignore zero values in computation?"),
   make_option(c("-f", "--file"), action="store", default=NA, type='character',
              help="Write output to file"),
   make_option(c("-t", "--title"), action="store", default=NA, type='character',
              help="Optional output header"),
   make_option(c("-o", "--operation"), action="store", default='none', type='character',
              help="What operation should be performed?
                     min         : return minimum value
                     max         : return maximum value
                     which_min   : return index of minimum value
                     which_max   : return index of maximum value
                     length      : return length of 1D file
                     mean        : return mean of 1D file")
)
opt = parse_args(OptionParser(option_list=option_list))

if (is.na(opt$input)) {
   cat('User did not specify an input.\n')
   cat('Use 1dTool.R -h for an expanded usage menu.\n')
   quit()
}

input <- opt$input
header <- opt$header
zeros <- opt$zeros
file <- opt$file
title <- opt$title
operation <- opt$operation

###################################################################
# Read input.
###################################################################
if (header) {
   input <- read.table(input, header=T)
} else {
   input <- read.table(input, header=F)
}

###################################################################
# Remove zeros or other irrelevant values if necessary.
###################################################################
if (zeros) {
   input[input==0] <- NA
}

###################################################################
# Redirect output to file if requested.
###################################################################
if (!is.na(file)) {
   sink(file = file)
}

###################################################################
# Operations -- wish R had case switch
###################################################################
if (operation == 'min') {
   out <- min(input, na.rm=TRUE)
} else if (operation == 'max') {
   out <- max(input, na.rm=TRUE)
} else if (operation == 'which_min') {
   out <- which(input==min(input, na.rm=TRUE))
} else if (operation == 'which_max') {
   out <- which(input==max(input, na.rm=TRUE))
} else if (operation == 'length') {
   out <- nrow(input)
} else if (operation == 'mean') {
   out <- apply(input,2,mean,na.rm=TRUE)
}

if (!is.na(title)) {
   cat(title,'\n',sep='')
}
cat(out,sep=' ')
cat('\n')

if (!is.na(file)) {
   sink(NULL)
}
