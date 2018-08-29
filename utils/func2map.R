#! /usr/bin/env Rscript

###################################################################
#  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  #
###################################################################

###################################################################
# * Function for performing simple mathematical operations in R
# * Utility function for xcpEngine
###################################################################
cat('THIS UTILITY IS NO LONGER SUPPORTED\n')
cat('EXITING\n')
quit()

###################################################################
# Load required libraries
###################################################################
suppressMessages(suppressWarnings(library(optparse)))
suppressMessages(suppressWarnings(library(pracma)))
suppressMessages(suppressWarnings(library(RNifti)))

###################################################################
# Parse arguments to script, and ensure that the required arguments
# have been passed.
###################################################################
option_list = list(
   make_option(c("-i", "--imlist"), action="store", default=NA, type='character',
              help="A list of paths to the images to be operated upon"),
   make_option(c("-o", "--out"), action="store", default=NA, type='character',
              help="Output path"),
   make_option(c("-f", "--func"), action="store", default=NA, type='character',
              help="The function to be applied to input images; the
                  output value will be equal to whatever the function
                  evaluates to in R.")
)
opt = parse_args(OptionParser(option_list=option_list))

if (is.na(opt$imlist)) {
   cat('User did not specify an input timeseries.\n')
   cat('Use func2map.R -h for an expanded usage menu.\n')
   quit()
}
if (is.na(opt$out)) {
   cat('User did not specify an output path.\n')
   cat('Use func2map.R -h for an expanded usage menu.\n')
   quit()
}
if (is.na(opt$func)) {
   cat('User did not specify a function.\n')
   cat('Use func2map.R -h for an expanded usage menu.\n')
   quit()
}

imlist            <- opt$imlist
out               <- opt$out
func              <- opt$func

###################################################################
# Parse the image list.
###################################################################
imlist            <- unlist(strsplit(imlist,split=','))

###################################################################
# Load in the first image to use its header information.
###################################################################
imorig            <- imlist[1]

###################################################################
# Load in all reference images.
#
# Substitute image references in the function with explicit
# coordinate calls.
###################################################################
idx <- 1
for (impath in imlist) {
   imcur          <- paste('i', idx, sep='')
   assign(imcur,     readNifti(impath))
   func           <- gsub(imcur,paste(imcur,'[x,y,z]',sep=''),func)
   idx            <- idx + 1
}

###################################################################
# Iterate through all voxels and evaluate the function at each.
###################################################################
dims              <- dim(refImg)
outArray          <- array(dim=dims)
for ( x in 1:dims[1] ) {
   for ( y in 1:dims[2] ) {
      for ( z in 1:dims[3] ) {
         outArray[x,y,z] <- eval(parse(text=func))
      }
   }
}

###################################################################
# Write output.
###################################################################
writeNifti(outArray,out,template=imorig)
