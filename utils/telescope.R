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
suppressMessages(require(RNifti))

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

inpath                  <- opt$img
outpath                 <-opt$out

###################################################################
# Read in the input volume.
###################################################################
img                     <- readNifti(inpath)


###################################################################
# Obtain labels
###################################################################
labs                    <- sort(unique(img[img > 0]))
out                     <- array(0,dim=c(dim(img)[1:3],length(labs)))
c(dim(img)[1:3],length(labs))


###################################################################
# Telescope
###################################################################
for (l in labs) {
   cat(l,' ')
   logmask              <- (img == labs[l])
   out[,,,l][logmask]   <- 1
}
   cat('\n')

###################################################################
# To NIfTI
###################################################################
writeNifti(out,outpath,template=inpath,datatype='int16')
