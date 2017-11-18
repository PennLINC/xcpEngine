#!/usr/bin/env Rscript

###################################################################
#  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  #
###################################################################

###################################################################
# This utility collates all subject-level output values into a
# group-level table.
###################################################################

###################################################################
# Load required libraries
###################################################################
suppressMessages(suppressWarnings(library(optparse)))

###################################################################
# Parse arguments to script, and ensure that the required arguments
# have been passed.
###################################################################
option_list = list(
   make_option(c("-i", "--inputs"), action="store", default=NA, type='character',
              help="A comma-separated list of paths to the files to
                  be collated."),
   make_option(c("-o", "--out"), action="store", default=NA, type='character',
              help="Output path for group-level table.")
)
opt = parse_args(OptionParser(option_list=option_list))

if (is.na(opt$inputs) && is.na(opt$timeseries) && is.na(opt$derivatives)) {
   cat('User did not specify any input paths.\n')
   cat('Use combineOutput.R -h for an expanded usage menu.\n')
   quit()
}
if (is.na(opt$out)) {
   cat('User did not specify an output path.\n')
   cat('Use combineOutput.R -h for an expanded usage menu.\n')
   quit()
}

input             <- opt$inputs
outpath           <- opt$out

###################################################################
# Read in and merge all inputs.
###################################################################
input <- unlist(strsplit(input,split=','))
output <- read.table(input[1],header=TRUE,stringsAsFactors=FALSE,sep=',')
for (i in 2:length(input)) {
   tmp <- read.table(input[i],header=TRUE,stringsAsFactors=FALSE,sep=',')
   output[setdiff(names(tmp),names(output))] <- NA
   tmp[setdiff(names(output),names(tmp))] <- NA
   output <- rbind(output,tmp)
}

###################################################################
# Write the output.
###################################################################
write.table(output,outpath,quote=FALSE,row.names=FALSE,sep=',')
