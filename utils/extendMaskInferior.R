#!/usr/bin/env Rscript

###################################################################
#  ⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗ #
###################################################################

###################################################################
# Utility function that will be used to draw a plane from the back of the neck
# through the nose of a subject, given the corresponding MNI points
# trnasformed into subject space.
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
   make_option(c("-i", "--img"), action="store", default=NA, type='character',
              help="Path to the input mask to have inferior extension performed to"),
   make_option(c("-o", "--out"), action="store", default=NA, type='character',
              help="Output path"),
   make_option(c("-c", "--csv"), action="store", default=NA, type='character',
              help="Input coordinate CSV")
)
opt = parse_args(OptionParser(option_list=option_list))
if (is.na(opt$img)) {
   cat('User did not specify an input image.\n')
   cat('Use extendMaskInferior.R -h for an expanded usage menu.\n')
   quit()
}
if (is.na(opt$out)) {
   cat('User did not specify an output path.\n')
   cat('Use extendMaskInferior.R -h for an expanded usage menu.\n')
   quit()
}

impath <- opt$img
out <- opt$out
inputCsv <- opt$csv

###################################################################
# Declare any functions specific to this script
###################################################################
mm2vox <- function(inputVoxel, inputImagePath){
    # This function will wrap around the FSL std2imgcoord
    # function and return a voxel coordinate
    systemCall <- paste("echo ", inputVoxel[1], " ", inputVoxel[2], " ", inputVoxel[3], " | std2imgcoord -img ", inputImagePath, " -std ", inputImagePath, " -vox", sep='')
    output <- system(systemCall, intern=T)
    output <- gsub(x=output, pattern='  ', replacement=',')
    output <- unlist(strsplit(output, ','))
    output <- as.numeric(output)
    # Now make sure all of our points are within the image
    tmp <- readNifti(inputImagePath)
    newOutput <- NULL
    for(z in seq(1,3)){
      tmpVal <- output[z]
      tmpRange <- dim(tmp)[z]
      if(tmpVal > tmpRange){
        tmpVal <- tmpRange
      } else if(tmpVal < 0){
        tmpVal <- 0
      }
      newOutput <- c(newOutput, tmpVal)
    }
    return(newOutput)
}

###################################################################
# 1. Load in the image and create our matrix to work with
###################################################################
suppressMessages(suppressWarnings(library(RNifti)))
suppressMessages(suppressWarnings(library(pracma)))
img <- readNifti(impath)

###################################################################
# 2. Load in the registered points
###################################################################
pointVals <- read.csv(inputCsv, header=T)

###################################################################
# 3. Now create our matrix to work with
###################################################################
mat <- as.array(img)
dim(mat) <- dim(img)

###################################################################
# 4. Now find the formula for our plane
###################################################################
u <- mm2vox(pointVals[1,1:3], impath) - mm2vox(pointVals[3,1:3], impath)
v <- mm2vox(pointVals[2,1:3], impath) - mm2vox(pointVals[3,1:3], impath)
n <- cross(u,v)
n1 <- n / max(abs(n))
constant <- v %*% n1

###################################################################
# 5. Now draw our plane, and turn anything below our Z value to a 1
###################################################################
newMat <- mat
for(yVox in 1:dim(mat)[2]){
    for(xVox in 1:dim(mat)[1]){
    zVox <-  (constant - (n1[1] * xVox + n1[2] * yVox)) / n1[3]
    zVox <- floor(zVox)
    if(zVox < 0){
      zVox <- 0
    }
    newMat[xVox, yVox, 1:zVox] <- 1
    }
}

###################################################################
# 6. Now write the new image
###################################################################
img[img>-Inf] <- newMat
writeNifti(image=img, file=out, template=impath)
