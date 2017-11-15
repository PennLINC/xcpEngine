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
suppressMessages(suppressWarnings(library(optparse)))
suppressMessages(suppressWarnings(library(pracma)))

###################################################################
# Parse arguments to script, and ensure that the required arguments
# have been passed.
###################################################################
option_list = list(
   make_option(c("-c", "--cohort"), action="store", default=NA, type='character',
              help="Path to the initial cohort file, which may contain 
                  duplicated entries.")
)
opt = parse_args(OptionParser(option_list=option_list))

if (is.na(opt$cohort)) {
   cat('User did not specify a cohort file.\n')
   cat('Use removeDuplicates.R -h for an expanded usage menu.\n')
   quit()
}

cohortpath <- opt$cohort


###################################################################
# Remove any duplicate entries.
###################################################################
cohort <- read.csv(cohortpath,header=T)
oidx <- grep('id',names(cohort))
if (length(oidx) == 0) { q() }
cohort <- cohort[!duplicated(cohort[,oidx]),]
write.table(cohort,cohortpath,row.names=F,quote=F,sep=',')
