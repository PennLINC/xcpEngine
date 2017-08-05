#!/usr/bin/env Rscript

###################################################################
#  ✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡ #
###################################################################

###################################################################
# This script finds the closest WM voxel to each GM voxel 1mm from
# the WM-GM edge. It will then finx the cortical contrast value (WM/GM)
# for each voxel and write out a voxel wise map for these values.
###################################################################

###################################################################
# Load required libraries
###################################################################
suppressMessages(require(optparse))
suppressMessages(require(pracma))
suppressMessages(require(tools))

###################################################################
# Parse arguments to script, and ensure that the required arguments
# have been passed.
###################################################################
option_list = list(
make_option(c("-g", "--gmimg"), action="store", default=NA, type='character',
help="Path to the GM border 1mm mask"),
make_option(c("-w", "--wmimg"), action="store", default=NA, type='character',
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

gmpath <- opt$gmimg
wmpath <- opt$wmimg
strucpath <- opt$t1
out <- opt$outimg

###################################################################
# Declare any functions specific to this script
###################################################################
# Declare a function which wil return the 3d coordinate of all TRUE logical values
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

euc.dist3 <- function(data, point) {
    # Find mimum kernal val
    seqVal <- seq(5, 50, 5)
    for(s in seqVal){
      key <- which(data[,1]>point[1]-s&data[,1]<point[1]+s&data[,2]>point[2]-s&data[,2]<point[2]+s&data[,3]>point[3]-s&data[,3]<point[3]+s)
      if(length(key) > 1){
        break
      }
    }
    newData <- data[key,]
    vals <- apply(newData, 1, function (row) sqrt(sum((point - row) ^ 2)))
    val <- min(vals)
    key[which(vals==val)[1]]
}

apply_pb <- function(X, MARGIN, FUN, ...) {
    env <- environment()
    pb_Total <- sum(dim(X)[MARGIN])
    counter <- 0
    pb <- txtProgressBar(min = 0, max = pb_Total,
    style = 3)
    
    wrapper <- function(...) {
        curVal <- get("counter", envir = env)
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
suppressMessages(require(ANTsR))
gmVal <- antsImageRead(gmpath, 3)
gmVal <- as.array(gmVal)
wmVal <- antsImageRead(wmpath, 3)
wmVal <- as.array(wmVal)
strVal <- antsImageRead(strucpath, 3)
strVal <- as.array(strVal)

###################################################################
# 2. Cretae our Voxel values
###################################################################
gmBoo <- gmVal
gmBoo[gmBoo==1] <- TRUE
gmBoo[gmBoo==0] <- FALSE
gmVoxIndex <- multi.which(gmBoo)
wmBoo <- wmVal
wmBoo[wmBoo==1] <- TRUE
wmBoo[wmBoo==0] <- FALSE
wmVoxIndex <- multi.which(wmBoo)

###################################################################
# 3. Convert voxel indices to mm coordinates
###################################################################
syscom <- paste('fslval',gmpath,'pixdim1')
xdim <- as.numeric(system(syscom,intern=TRUE))
syscom <- paste('fslval',gmpath,'pixdim2')
ydim <- as.numeric(system(syscom,intern=TRUE))
syscom <- paste('fslval',gmpath,'pixdim3')
zdim <- as.numeric(system(syscom,intern=TRUE))

gmMMIndex <- gmVoxIndex
gmMMIndex[,1] <- gmMMIndex[,1]*xdim
gmMMIndex[,2] <- gmMMIndex[,2]*ydim
gmMMIndex[,3] <- gmMMIndex[,3]*zdim

wmMMIndex <- wmVoxIndex
wmMMIndex[,1] <- wmMMIndex[,1]*xdim
wmMMIndex[,2] <- wmMMIndex[,2]*ydim
wmMMIndex[,3] <- wmMMIndex[,3]*zdim

###################################################################
# 4. Now find the closest WM voxel for each GM voxel
###################################################################
closVal <- apply_pb(gmMMIndex, 1, function(x) euc.dist3(wmMMIndex, x))

###################################################################
# 5. Replace each value in the GM mask with the contrast value
###################################################################
wmClosIndex <- wmVoxIndex[closVal,]
newVals <- strVal[wmClosIndex]/strVal[gmVoxIndex]
outputVals <- gmVal
outputVals[gmVoxIndex] <- newVals

###################################################################
# 6. Now write the output file
###################################################################
outputImage <- antsImageRead(gmpath, 3)
outputImage[gmBoo==TRUE] <- outputVals
outputImage[gmBoo==FALSE] <- 0
antsImageWrite(outputImage, out)
