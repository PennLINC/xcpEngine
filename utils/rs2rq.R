#!/usr/bin/env Rscript

################################################################### 
#  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  #
###################################################################

###################################################################
# Utility for converting AFNI 3dROIstats output into pipeline
# conformation
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
              help="The output of 3dROIstats."),
   make_option(c("-a", "--pname"), action="store", default=NA, type='character',
              help="String to prepend to all ROI names."),
   make_option(c("-n", "--rname"), action="store", default=NA, type='character',
              help="The names of atlas regions."),
   make_option(c("-o", "--opath"), action="store", default=NA, type='character',
              help="The output path."),
   make_option(c("-p", "--prpnd"), action="store", default=NA, type='character',
              help="A comma-separated list of values to prepend to ROI-wise
                     values, for instance subject identifiers."),
   make_option(c("-s", "--scale"), action="store", default=1, type='numeric',
              help="A scaling factor by which all inputs should be multiplied.")
)
opt = parse_args(OptionParser(option_list=option_list))

if (is.na(opt$input) | is.na(opt$pname) | is.na(opt$rname) | is.na(opt$opath) | is.na(opt$scale)) {
   cat('Missing argument.\n')
   cat('Use rs2rq.R -h for an expanded usage menu.\n')
   quit()
}

input <- opt$input
pname <- opt$pname
prpnd <- opt$prpnd
rname <- opt$rname
opath <- opt$opath
scale <- opt$scale

###################################################################
# Load in the ROIstats input.
###################################################################
input <- read.table(input,header=T)
rname <- as.vector(unlist(read.table(rname,header=F)))
prpnd <- unlist(strsplit(prpnd,','))

###################################################################
# Replace the brick information with the prefix
###################################################################
input <- input[,-1]
data <- matrix(nrow=1,ncol=(length(prpnd)+length(input)))
name <- matrix(nrow=1,ncol=(length(prpnd)+length(input)))
for (i in 1:length(prpnd)) {
   data[i]        <- prpnd[i]
   name[i]        <- paste('subject',i,sep='_')
}
offset <- i

###################################################################
# Populate the regional values
###################################################################
for (i in 1:length(input)) {
   data[i+offset]          <- input[,i] * scale
   name[i+offset]          <- paste(pname,rname[i],sep='_')
}

###################################################################
# Write the output
###################################################################
data           <- as.data.frame(data)
colnames(data) <- name
write.table(data,file=opath,quote=FALSE,sep=',',row.names=F)
