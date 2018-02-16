#!/usr/bin/env Rscript

################################################################### 
#  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  #
###################################################################

###################################################################
# Function for transforming CBF motion realignment parameters to 
# control images only or averages of the tag-control pair
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
   make_option(c("-m", "--mat"), action="store", default=NA, type='character',
              help="Path to the realignment.1D file."),
   make_option(c("-t", "--type"), action="store", default=NA, type='character',
              help="Type of transform: 'control' or 'mean.'"),
   make_option(c("-o", "--out"), action="store", default=NA, type='character',
              help="Base path for outputs of the transformed realignment.")
)
opt = parse_args(OptionParser(option_list=option_list))

if (is.na(opt$mat)) {
   cat('User did not specify a realignment file.\n')
   quit()
}
if (is.na(opt$type)) {
   cat('User did not specify the type of transform.\n')
   quit()
}
if (opt$type!="control" && opt$type!="mean") {
   cat('User did not specify a valid transform -t: "control" or "mean."')
   quit()
}
if (is.na(opt$out)) {
   opt$out <- paste(getwd(),"/",sep='')
}

matpath <- opt$mat
typechar <- opt$type
outbase <- opt$out

###################################################################
# 1. Load in the realignment file.
###################################################################
relmat <- read.table(matpath,header=F,sep="",skip=0)

###################################################################
# 2. Extract only odd (tag images) or even (control images) rows
###################################################################
odd <- relmat
odd <- odd[seq(1, nrow(odd), 2), ]
  
even <- relmat
even <- even[seq(2, nrow(even), 2), ]
 
###################################################################
# 3. Calculate mean
###################################################################
mean <- (odd + even)/2

###################################################################
# 4. Write output
###################################################################  
out <- paste(outbase,'realignment_transform.1D',sep='_')

if (typechar == "control") {
write.table(even,out,sep="  ",col.names=FALSE,row.names=FALSE)
}
if (typechar == "mean") {
write.table(mean,out,sep="  ",col.names=FALSE,row.names=FALSE)
}