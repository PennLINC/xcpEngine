#!/usr/bin/env Rscript

###################################################################
#  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  #
###################################################################

###################################################################
# Function for converting ROI indices in a single volume to
# binary-weighted masks in multiple volumes
###################################################################

###################################################################
# Load required libraries
###################################################################
suppressMessages(require(optparse))
suppressMessages(require(pracma))
#suppressMessages(require(ANTsR))

###################################################################
# Parse arguments to script, and ensure that the required arguments
# have been passed.
###################################################################
option_list = list(
   make_option(c("-i", "--img"), action="store", default=NA, type='character',
              help="A path to the input parcellation"),
   make_option(c("-o", "--out"), action="store", default=NA, type='character',
              help="The path where the ROI-wise masks should be written.")
)
opt = parse_args(OptionParser(option_list=option_list))

if (is.na(opt$img)) {
   cat('User did not specify a valid input.\n')
   cat('Use roicc.R -h for an expanded usage menu.\n')
   quit()
}

if (is.na(opt$out)) {
   cat('User did not specify a valid output.\n')
   cat('Use roicc.R -h for an expanded usage menu.\n')
   quit()
}

inpath <- opt$img
outpath <-opt$out

sink('/dev/null')

###################################################################
# Read in the input volume.
###################################################################
suppressMessages(require(ANTsR))
img <- antsImageRead(inpath,3)


###################################################################
# Obtain labels
###################################################################
labs <- sort(unique(img[img>0]))
out <- array(0,dim=c(dim(img)[1:3],numel(labs)))


###################################################################
# Telescope
###################################################################
for (l in labs) {
   logmask <- (img == labs[l])
   dim(logmask) <- dim(img)[1:3]
   out[cbind(which(logmask==1,arr.ind=T),l)] <- 1
}

###################################################################
# To NIfTI
###################################################################
out <- as.antsImage(out)
antsCopyImageInfo(img,out)
antsImageWrite(out,outpath)
