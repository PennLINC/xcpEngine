#!/usr/bin/env Rscript

###################################################################
#  ⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗ #
###################################################################

###################################################################
# This script finds the closest WM voxel to each GM voxel 1mm from
# the WM-GM edge. It will then find the cortical contrast value (WM/GM)
# for each voxel and write out a voxel wise map for these values.
###################################################################

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
make_option(c("-G", "--gmimg"), action="store", default=NA, type='character',
help="Path to the GM border 1mm mask"),
make_option(c("-W", "--wmimg"), action="store", default=NA, type='character',
help="Path to the WM 1mm border mask"),
make_option(c("-T", "--t1"), action="store", default=NA, type='character',
help="Path to the T1 structural image to compute CortCon on"),
make_option(c("-o", "--outimg"), action="store", default=NA, type='character',
help="Path to write voxelwise CortCon mask to")
)
opt = parse_args(OptionParser(option_list=option_list))
if (is.na(opt$gmimg)) {
    cat('User did not specify an input GM image.\n')
    cat('Use cortCon.R -h for an expanded usage menu.\n')
    quit()
}
if (is.na(opt$wmimg)) {
    cat('User did not specify an input WM image.\n')
    cat('Use cortCon.R -h for an expanded usage menu.\n')
    quit()
}
if (is.na(opt$outimg)) {
    cat('User did not specify an output path.\n')
    cat('Use cortCon.R -h for an expanded usage menu.\n')
    quit()
}
if (is.na(opt$t1)) {
    cat('User did not specify an input T1 image.\n')
    cat('Use cortCon.R -h for an expanded usage menu.\n')
    quit()
}

gmpath               <- opt$gmimg
wmpath               <- opt$wmimg
strucpath            <- opt$t1
out                  <- opt$outimg

###################################################################
# Declare any functions specific to this script
###################################################################

euc.dist3            <- function(data, point) {
   # Find minimum kernel val
   seqVal            <- seq(5, 50, 5)
   for(s in seqVal){
      key            <-    which(data[,1] > point[1] - s & 
                                 data[,1] < point[1] + s &
                                 data[,2] > point[2] - s &
                                 data[,2] < point[2] + s &
                                 data[,3] > point[3] - s &
                                 data[,3] < point[3] + s)
      if(length(key) > 1) {
         break
      }
   }
   newData           <- data[key,]
   vals              <- apply(newData, 1, function (row) sqrt(sum((point - row) ^ 2)))
   val               <- min(vals)
   return(key[which(vals==val)[1]])
}

apply_pb             <- function(X, MARGIN, FUN, ...) {
    env              <- environment()
    pb_Total         <- sum(dim(X)[MARGIN])
    counter          <- 0
    pb               <- txtProgressBar(min = 0, max = pb_Total,
    style = 3)
    
    wrapper          <- function(...) {
        curVal       <- get("counter", envir = env)
        assign("counter", curVal +1 ,envir= env)
        setTxtProgressBar(get("pb", envir= env),
        curVal +1)
        FUN(...)
    }
    res <- apply(X, MARGIN, wrapper, ...)
    close(pb)
    res
}
###################################################################
# 1. Load images
###################################################################
gmVal                <- readNifti(gmpath)
gmVal                <- as.array(gmVal)
wmVal                <- readNifti(wmpath)
wmVal                <- as.array(wmVal)
strVal               <- readNifti(strucpath)
strVal               <- as.array(strVal)

###################################################################
# 2. Create our Voxel values
###################################################################
gmBoo                <- (gmVal==1)
gmVoxIndex           <- which(gmBoo,arr.ind=TRUE)
wmBoo                <- (wmVal==1)
wmVoxIndex           <- which(wmBoo,arr.ind=TRUE)

###################################################################
# 3. Convert voxel indices to mm coordinates
###################################################################
dims                 <- dumpNifti(gmpath)$pixdim[2:4]

gmMMIndex            <- sweep(gmVoxIndex, MARGIN=2, dims, '*')
wmMMIndex            <- sweep(wmVoxIndex, MARGIN=2, dims, '*')

###################################################################
# 4. Now find the closest WM voxel for each GM voxel
###################################################################
closVal              <- apply_pb(gmMMIndex, 1, function(x) euc.dist3(wmMMIndex, x))

###################################################################
# 5. Replace each value in the GM mask with the contrast value
###################################################################
wmClosIndex          <- wmVoxIndex[closVal,]
newVals              <- strVal[wmClosIndex]/strVal[gmVoxIndex]

###################################################################
# 6. Now write the output file
###################################################################
outputImage          <- readNifti(gmpath)
outputImage[gmBoo]   <- newVals
outputImage[!gmBoo]  <- 0
writeNifti(outputImage, out, template=gmpath)
