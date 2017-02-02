#!/usr/bin/env Rscript

################################################################### 
#  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  #
###################################################################

###################################################################
# Search through a cohort file and remove any duplicated entries.
#
# This function was formally centralised in the XCP Engine;
# however, its implementation was highly inefficient and led to
# frequent interruptions of the pipeline due to excess load.
#
# The XCP Engine will automatically call this script for each
# analysis that is run.
###################################################################

###################################################################
# Load required libraries
###################################################################
suppressMessages(require(optparse))
suppressMessages(require(pracma))

###################################################################
# Parse arguments to script, and ensure that the required arguments
# have been passed.
###################################################################
option_list = list(
   make_option(c("-c", "--cohort"), action="store", default=NA, type='character',
              help="Path to the initial cohort file, which may contain 
                  duplicated entries."),
   make_option(c("-o", "--oidx"), action="store", default=NA, type='character',
              help="General form of the output path for a subject.")
)
opt = parse_args(OptionParser(option_list=option_list))

if (is.na(opt$cohort)) {
   cat('User did not specify a cohort file.\n')
   cat('Use removeDuplicates.R -h for an expanded usage menu.\n')
   quit()
}

oidx <- opt$oidx
oidx <- as.numeric(unlist(strsplit(oidx,split=',')))
cohortpath <- opt$cohort
cohort <- read.csv(cohortpath,header=F)

###################################################################
# Remove any duplicate entries.
###################################################################
cohort <- cohort[!duplicated(cohort[,oidx]),]
write.csv(cohort,cohortpath,header=F,row.names=F,quote=F)
