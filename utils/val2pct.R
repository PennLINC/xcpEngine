#!/usr/bin/env Rscript

################################################################### 
#  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  #
###################################################################

###################################################################
# Utility script to scale raw image values to percentiles
###################################################################

###################################################################
# Load required libraries
###################################################################
suppressMessages(suppressWarnings(library(optparse)))
suppressMessages(suppressWarnings(library(RNifti)))

###################################################################
# Parse arguments to script, and ensure that the required arguments
# have been passed.
###################################################################
option_list = list(
   make_option(c("-i", "--img"), action="store", default=NA, type='character',
              help="Path to the 3d image whose values are to be converted
                  to percentiles."),
   make_option(c("-m", "--mask"), action="store", default=NA, type='character',
              help="A 3D mask specifying the region of the input image
                  to convert to percentiles."),
   make_option(c("-o", "--out"), action="store", default=NA, type='character',
              help="The output path for the percentile map.")
)
opt = parse_args(OptionParser(option_list=option_list))

if (is.na(opt$img)) {
   cat('User did not specify an input image.\n')
   cat('Use val2pct.R -h for an expanded usage menu.\n')
   quit()
}
if (is.na(opt$mask)) {
   cat('User did not specify a mask.\n')
   cat('Use val2pct.R -h for an expanded usage menu.\n')
   quit()
}
if (is.na(opt$out)) {
   cat('User did not specify an output path.\n')
   cat('Use val2pct.R -h for an expanded usage menu.\n')
   quit()
}

impath                  <- opt$img
maskpath                <- opt$mask
outpath                 <- opt$out

###################################################################
# Convert values to percentiles
###################################################################
img                     <- readNifti(impath)
mask                    <- readNifti(maskpath)
logmask                 <- (mask!=0)
imvec                   <- img[logmask]
pct                     <- ecdf(imvec)(imvec)
img[logmask]            <- pct

###################################################################
# Write out the image
###################################################################
sink("/dev/null")
writeNifti(img,outpath,template=impath,datatype='float')
sink(NULL)
