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
   make_option(c("-o", "--opath"), action="store", default=NA, type='character',
              help="General form of the output path for a subject.")
)
opt = parse_args(OptionParser(option_list=option_list))

if (is.na(opt$cohort)) {
   cat('User did not specify a cohort file.\n')
   cat('Use removeDuplicates.R -h for an expanded usage menu.\n')
   quit()
}

opath <- opt$opath
cohortpath <- opt$cohort


###################################################################
# Identify the columns in the cohort file that are used to
# produce the output path. These are the columns in which
# duplications are not permissible.
###################################################################
testing <- TRUE
sidx <- 0
oidx <- c()
while (testing) {
   testexp <- paste('subject\\[',sidx,'\\]',sep='')
   match <- gregexpr(testexp,opath)
   if (match[[1]][1] != -1) {
      oidx <- c(oidx,sidx)
      sidx <- sidx + 1
   } else {
      testing <- FALSE
   }
}
oidx <- oidx + 1

###################################################################
# Remove any duplicate entries.
###################################################################
cohort <- read.csv(cohortpath,header=F)
cohort <- cohort[!duplicated(cohort[,oidx]),]
write.table(cohort,cohortpath,col.names=F,row.names=F,quote=F,sep=',')
