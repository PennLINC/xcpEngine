#!/usr/bin/env Rscript

###################################################################
#  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  #
###################################################################

###################################################################
# function for censoring BOLD timeseries
###################################################################

###################################################################
# Load required libraries
###################################################################
suppressMessages(require(optparse))
#suppressMessages(require(ANTsR))

###################################################################
# Parse arguments to script, and ensure that the required arguments
# have been passed.
###################################################################
option_list = list(
   make_option(c("-t", "--tmask"), action="store", default=NA, type='character',
              help="Temporal mask that determines which volumes are
                  to be censored."),
   make_option(c("-i", "--img"), action="store", default=NA, type='character',
              help="Path to the BOLD timeseries to be censored"),
   make_option(c("-s", "--timeseries"), action="store", default=NA, type='character',
              help="1D timeseries to which the censoring regime should
                  also be applied."),
   make_option(c("-o", "--out"), action="store", default=NA, type='character',
              help="Output path")
)
opt = parse_args(OptionParser(option_list=option_list))

if (is.na(opt$img) && is.na(opt$timeseries) && is.na(opt$derivatives)) {
   cat('User did not specify an input timeseries.\n')
   cat('Use censor.R -h for an expanded usage menu.\n')
   quit()
}
if (is.na(opt$tmask)) {
   cat('User did not specify a temporal mask.\n')
   cat('Use censor.R -h for an expanded usage menu.\n')
   quit()
}
if (is.na(opt$out)) {
   cat('User did not specify an output path.\n')
   cat('Use censor.R -h for an expanded usage menu.\n')
   quit()
}

impath <- opt$img
tspath <- opt$timeseries
derivspath <- opt$derivatives
tmaskpath <- opt$tmask
out <- opt$out

###################################################################
# 1. Load in the temporal mask
###################################################################
sink("/dev/null")
tmask <- as.logical(unlist(read.table(tmaskpath)))
###################################################################
# 2. Load in any BOLD timeseries to be censored
###################################################################
if (!is.na(impath)) {
   suppressMessages(require(ANTsR))
   img <- antsImageRead(impath,4)
   imgarray <- as.array(img)
   ################################################################
   # Censor the image using the temporal mask
   ################################################################
   imgarray_censored <- imgarray[,,,tmask]
   ################################################################
   # Write the censored image
   ################################################################
   img_censored <- as.antsImage(imgarray_censored)
   antsCopyImageInfo(img,img_censored)
   antsImageWrite(img_censored,out)
}
rm(img)
rm(img_censored)
rm(imgarray)
rm(imgarray_censored)

###################################################################
# 3. Iterate through all 1D timeseries, then excise time points
#    corresponding to censored volumes
###################################################################
if (!is.na(tspath)) {
   tspaths <- strsplit(tspath,split=',')
   outbase <- sub('[.].*$','',out)
   for (path in tspaths) {
      tscur <- unlist(as.matrix(read.table(path)))
      tsname <- basename(path)
      if (is.null(dim(tscur)) && !is.null(length(tscur))) {
         dim(tscur)<-c(length(tscur),1)
      }
      tsrev <- tscur[tmask,]
      tsname <- paste(outbase,tsname,sep='_')
      write.table(tsrev, file = tsname, quote=FALSE, col.names = F, row.names = F)
   }
}
