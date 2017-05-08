#!/usr/bin/env Rscript

###################################################################
#  ✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡ #
###################################################################

###################################################################
# Utility function that can be used to remove negative voxels and 
# impute the now removed voxels based on local patterns. 
# This functionality will be explored in R but due to CPU processing times
# may be moved into c++ 
###################################################################

###################################################################
# Load required libraries
###################################################################
suppressMessages(require(optparse))

###################################################################
# Parse arguments to script, and ensure that the required arguments
# have been passed.
###################################################################
option_list = list(
   make_option(c("-i", "--img"), action="store", default=NA, type='character',
              help="Path to the input mask to have inferior extension performed to"),
   make_option(c("-o", "--out"), action="store", default=NA, type='character',
              help="Output path"),
   make_option(c("-s", "--allMask"), action="store", default=0, type='character',
              help="Binary mask encompassing entire inut image dimensions")
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
allMask <- opt$allMask

###################################################################
# Declare any functions specific to this script
###################################################################
multi.which <- function(A){
    if ( is.vector(A) ) return(which(A))
    d <- dim(A)
    T <- which(as.logical(A)) - 1
    nd <- length(d)
    t( sapply(T, function(t){
        I <- integer(nd)
        I[1] <- t %% d[1]
        sapply(2:nd, function(j){
            I[j] <<- (t %/% prod(d[1:(j-1)])) %% d[j]
        })
        I
    }) + 1 )
}

###################################################################
# 1. Load in the image and create our matrix to work with
###################################################################
suppressMessages(require(ANTsR))
img <- antsImageRead(impath, 3)
logmask <- antsImageRead(allMask, 3)

###################################################################
# 2. Now create our matrix to work with
###################################################################
mat <- img[logmask==1]
dim(mat) <- dim(img)

###################################################################
# 3. Now all of our 1 voxels
# this is where the script should be sped up 
# as this multi.which command is very slow
###################################################################
halfZ <- floor(dim(mat)[3]/2)
onValues <- multi.which(mat[,,1:halfZ])

###################################################################
# 4. Now extend the image mask in the inferior direction
###################################################################
newMat <- mat
for(i in unique(onValues[,2])){
  lowZ <- min(onValues[which(onValues[,2]==i),3])+5
  for(i in newMat[,i,1:lowZ]){
  
  }  
}

###################################################################
# 5. Now write the new image
###################################################################
img[logmask==1] <- newMat
antsImageWrite(image=img, filename=out)
