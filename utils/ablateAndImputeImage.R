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
suppressMessages(require(pracma))
suppressMessages(require(tools))

###################################################################
# Parse arguments to script, and ensure that the required arguments
# have been passed.
###################################################################
option_list = list(
   make_option(c("-i", "--img"), action="store", default=NA, type='character',
              help="Path to the BOLD timeseries to be masked and interpolated"),
   make_option(c("-o", "--out"), action="store", default=NA, type='character',
              help="Output path"),
   make_option(c("-s", "--floor"), action="store", default=0, type='numeric',
              help="Floor value to set any values below to N/A
                  recommended [default 0]")
)
opt = parse_args(OptionParser(option_list=option_list))
if (is.na(opt$img)) {
   cat('User did not specify an input image.\n')
   cat('Use ablateAndImputeImage.R -h for an expanded usage menu.\n')
   quit()
}
if (is.na(opt$out)) {
   cat('User did not specify an output path.\n')
   cat('Use ablateAndImputeImages.R -h for an expanded usage menu.\n')
   quit()
}

impath <- opt$img
out <- opt$out
floor <- opt$floor

###################################################################
# Declare any functions specific to this script
###################################################################
# First create a binary sphere image
drawSphereBinary <- function(x,y,z,niftiImage, radius=5){
  # First thing we need to do is create an output matrix with 
  # the proper image dimensions and all 0's
  dimValues <- dim(niftiImage)

  # Now create a blank matrix with the dimension of the niftiImage
  output <- rep(0, dimValues[1]*dimValues[2]*dimValues[3])
  output <- array(output, c(dimValues[1],dimValues[2],dimValues[3]))

  # Now draw our sphere centered on our center, with defined radius
  for(i in 1:dimValues[1]){
    for(j in 1:dimValues[2]){
      for(k in 1:dimValues[3]){
        output[i,j,k] <- (i - x)^2 + (j - y)^2 + (k - z)^2
      }
    }  
  }  
  # Now subset all values greater then the radius^2 to 0
  tmp.values <- output
  output[tmp.values <= radius^2] <- 'TRUE'
  output[tmp.values > radius^2] <- 'FALSE'
  
  # Now return the output
  return(output)
}

# Now create an image with a weighted sphere - closer to the center of the sphere will be weighted towards 1
# farther from the sphere will be weighted closer to 0
drawSphereWeighted <- function(x,y,z,niftiImage, radius=5){
  # First create a function to scale things between 0 and 1
  range01 <- function(x)abs((x-max(x)))/diff(range(x))
  #range01 <- function(x)(x-min(x))/diff(range(x))
  # First thing we need to do is create an output matrix with 
  # the proper image dimensions and all 0's
  dimValues <- dim(niftiImage)

  # Now create a blank matrix with the dimension of the niftiImage
  output <- rep(0, dimValues[1]*dimValues[2]*dimValues[3])
  output <- array(output, c(dimValues[1],dimValues[2],dimValues[3]))

  # Now draw our sphere centered on our center, with defined radius
  for(i in 1:dimValues[1]){
    for(j in 1:dimValues[2]){
      for(k in 1:dimValues[3]){
        output[i,j,k] <- (i - x)^2 + (j - y)^2 + (k - z)^2
      }
    }  
  }  
  # Now subset all values greater then the radius^2 to 0
  output[output <= radius^2] <- range01(output[output<=radius^2])  
  output[output > radius^2] <- 0  

  # Now return the sphere
  return(output)
}

## Now decalre a function which will compute the wiehgted mean for a voxel
compute3dWeightedMean <- function(x,y,z,imageMatrix, radiusValue=5){
  # First thing we need to do is set all 0 values to NA so they are not included in the mean computation
  matToWorkWith <- imageMatrix
  matToWorkWith[matToWorkWith < floor] <- 'NA'
  matToWorkWith[matToWorkWith == 0 ] <- 'NA'

  # Now we need to create a binary and a weighted sphere for our image
  binarySphere <- drawSphereBinary(x,y,z,img, radius=radiusValue)
  weightedSphere <- drawSphereWeighted(x,y,z,img, radius=radiusValue)

  # Now we need to get our voxel values, and attach their corresponding weight
  tmpValues <- suppressMessages(as.numeric(matToWorkWith[binarySphere=='TRUE']))
  tmpWeights <- suppressMessages(as.numeric(weightedSphere[binarySphere=='TRUE']))
  
  # Now rm any NA's that made it this far 
  na.index <- which(is.na(tmpValues)=='TRUE')
  tmpValues <- tmpValues[-na.index]
  tmpWeights <- tmpWeights[-na.index]

  # Now compute the weighted mean
  newValue <- weighted.mean(x=tmpValues, w=tmpWeights, na.rm=T)
  
  # Now return the new value
  return(newValue)
}

# Now create a function which will attempt to vectorize this process
vectorizeFunction <- Vectorize(function(x,y,z) compute3dWeightedMean(x,y,z,matrixToImpute, radius=5), vectorize.args=c("x","y","z"))

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
###################################################################
# 1. Load in the image and create our matrix to work with
###################################################################
suppressMessages(require(ANTsR))
img <- antsImageRead(impath,3)
matrixToImpute <- as.array(img)

###################################################################
# 2. Now find our values to ablate
###################################################################
matrixLogical <- rep('FALSE', dim(matrixToImpute)[1]*dim(matrixToImpute)[2]*dim(matrixToImpute)[3])
matrixLogical <- array(matrixLogical, c(dim(matrixToImpute)[1],dim(matrixToImpute)[2],dim(matrixToImpute)[3]))
matrixLogical[matrixToImpute < floor] <- 'TRUE'
coordinates <- multi.which(matrixLogical)

###################################################################
# 3. Now we need to iterate through each coordinate and compute the mean around it
# this will be done in a for loop, using apply for each z slice 
###################################################################
pb <- txtProgressBar(min = 0, max = dim(coordinates)[1] %/% 20, style = 3)
newValues <- NULL
allValues <- seq(1, dim(coordinates)[1])
minVal <- 1
for(l in seq(1, dim(coordinates)[1] %/% 20)){
  arrayVals <- seq(minVal, minVal+19)
  tmpVals <- vectorizeFunction(x=coordinates[arrayVals,1], y=coordinates[arrayVals,2], z=coordinates[arrayVals,3])
  newValues <- append(newValues, tmpVals)
  setTxtProgressBar(pb, l)
  minVal <- max(arrayVals) + 1
}
close(pb)

## Now quickly run the remaing values
remainder <- dim(coordinates)[1] %% max(arrayVals)
arrayVals <- seq(minVal, (minVal+remainder)-1)
tmpVals <- vectorizeFunction(x=coordinates[arrayVals,1], y=coordinates[arrayVals,2], z=coordinates[arrayVals,3])
newValues <- append(newValues, tmpVals)

###################################################################
# 4. now write the new values to the image
###################################################################
matrixToImpute[coordinates] <- newValues
outputImage <- img
matrixLogical <- rep('TRUE', dim(matrixToImpute)[1]*dim(matrixToImpute)[2]*dim(matrixToImpute)[3])
matrixLogical <- as.logical(array(matrixLogical, c(dim(matrixToImpute)[1],dim(matrixToImpute)[2],dim(matrixToImpute)[3])))
outputImage[matrixLogical] <- matrixToImpute
antsImageWrite(outputImage, out)
