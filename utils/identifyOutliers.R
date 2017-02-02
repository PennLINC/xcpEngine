#!/usr/bin/env Rscript

###################################################################
# ✡✡ ✡✡✡✡ ✡✡✡✡✡✡✡✡✡ ✡✡✡✡✡✡✡✡✡✡✡✡✡ ✡✡✡✡✡✡✡✡✡✡✡✡✡ ✡✡✡✡✡✡✡✡ ✡✡✡✡ ✡✡  #
###################################################################

###################################################################
# generalised function for identifing outliers from quality csv
###################################################################

###################################################################
# To Do for this Script:
#	1.) Figure best way to handle NA data
#	2.) Figure out system to match headers across quality files 
#	in order to fix repeated measures in quality files 
#	3.) Figure out a system to flag images uni directionally w/o
#	having a hard cutoff
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
   make_option(c("-f","--fileInput"), action="store", default=NA, type='character',
              help="Path to quality CSV"),
   make_option(c("-S","--numSD"), action="store", default=0, type='numeric',
              help="# of Standard deviations to apply a cutoff"),
   make_option(c("-o","--outputFile"), action="store", default=0, type='character',
              help="Output file to store number of flagged values"),
   make_option(c("-m","--manualValueCsv"), action="store", default=0, type='character',
              help="CSV which contains the manual values")
)

opt = parse_args(OptionParser(option_list=option_list))

if (is.na(opt$fileInput)) {
   cat('User did not specify an input file.\n')
   cat('Use identifyOutliers.R -h for an expanded usage menu.\n')
   quit()
}
if (is.na(opt$numSD)) {
   cat('User did not specify a value for SD cutoff.\n')
   cat('Use identifyOutliers.R -h for an expanded usage menu.\n')
   quit()
}
if (is.na(opt$outputFile)) {
   cat('User did not specify a output file.\n')
   cat('Use identifyOutliers.R -h for an expanded usage menu.\n')
   quit()
}

inputFile <- opt$fileInput
sdNum <- opt$numSD
outputFile <- opt$outputFile
manualValueCsv <- opt$manualValueCsv
sink("/dev/null")


###################################################################
# 1. Declare all functions required
###################################################################
identifyOutliers <- function(inputVector, numSdVal){
  # First make sure our input vecotr is a numeric
  inputVector <- as.numeric(as.character(inputVector))
  # Find the mean of the data
  meanVal <- mean(inputVector, na.rm=T)
  # Find the SD of the data
  sdVal <- sd(inputVector, na.rm=T)
  # Find the range of values to include
  upperVal <- (meanVal + (sdVal * numSdVal)) 
  lowerVal <- (meanVal - (sdVal * numSdVal))
  # Now prep the output
  outputRow <- rep(0, length(inputVector))
  # Now find subjects outside of the interval and turn their output values to 1
  outputRow[which(findInterval(inputVector, c(lowerVal, upperVal)) !=1)] <- 1
  # now return the output
  return(outputRow)
 }


###################################################################
# 2. Read the input quality file
###################################################################
qualityMeasures <- read.csv(inputFile)

###################################################################
# 4. Now limit data to complete cases
###################################################################
qualityMeasures <- qualityMeasures[complete.cases(qualityMeasures),]

###################################################################
# 4. Now create the output
###################################################################
flagStatus <- apply(qualityMeasures[,3:dim(qualityMeasures)[2]], 2, function(x) identifyOutliers(x, sdNum))
flagStatus <- as.data.frame(cbind(qualityMeasures[,1], qualityMeasures[,2], flagStatus, rowSums(flagStatus)))
colnames(flagStatus)[1:2] <- names(qualityMeasures[1:2])
colnames(flagStatus)[dim(flagStatus)[2]] <- 'flagSums'

###################################################################
# 5. Now create the output
###################################################################
manualValues <- read.csv(manualValueCsv, header=T)
manualValues$colName <- as.character(manualValues$colName)
manualValues$colName <- gsub(pattern='-', replacement = '.', x = manualValues$colName, fixed = TRUE)
if(dim(manualValues)[1] > 0){
  for(rowIndex in seq(1,dim(manualValues)[1])){
    colName <- as.character(manualValues$colName[rowIndex])
    coVal <- manualValues$cutOffValue[rowIndex]
    flipVal <- manualValues$flipIndex[rowIndex]
    if(flipVal == 0){
      flagStatus[,colName] <- rep(0, length(flagStatus[,colName]))
      flagStatus[,colName][which(qualityMeasures[,colName] < coVal)] <- 1     
    }
    if(flipVal == 1){
      flagStatus[,colName] <- rep(0, length(flagStatus[,colName]))
      flagStatus[,colName][which(qualityMeasures[,colName] > coVal)] <- 1     
    }
  }
}

###################################################################
# 6. Now recalculate the row sums
###################################################################
flagStatus$flagSums <- rowSums(flagStatus[,3:(dim(flagStatus)[2]-1)])

###################################################################
# 7. Now write the output
###################################################################
write.csv(flagStatus, file=outputFile, row.names=F, quote=F)
write.csv(qualityMeasures, file=inputFile, row.names=F, quote=F)
