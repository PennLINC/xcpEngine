#! /usr/bin/env Rscript

###################################################################
#  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  #
###################################################################

###################################################################
# R script to create a temporal mask based on a
# timeseries and a threshold
###################################################################

###################################################################
# Load required libraries
###################################################################
suppressMessages(require(optparse))
suppressMessages(require(pracma))

###################################################################
# Parse arguments to script, and ensure that the required arguments
# have been passed.
###################################################################
option_list = list(
   make_option(c("-s", "--ts"), action="store", default=NA, type='character',
              help="Path to a file containing a timeseries to be thresholded"),
   make_option(c("-t", "--thr"), action="store", default=0.2, type='numeric',
              help="Threshold value; values in the timeseries below the 
                  threshold will be assigned 0, and those above will be 
                  assigned 1"),
   make_option(c("-o", "--out"), action="store", default=NA, type='character',
              help="Output path. If none is specified, output will be printed 
                  to the terminal instead."),
   make_option(c("-m", "--mincontig"), action="store", default=0, type='numeric',
              help="Minimum number of contiguous threshold-surviving time 
                  points required for those time points to survive 
                  masking. [default 0]"),
   make_option(c("-i", "--invert"), action="store", default=FALSE, type='logical',
              help="For -i FALSE [default], superthreshold is assigned 0
                  and subthreshold is assigned 1. For -i TRUE, subthreshold
                  is assigned 0 and superthreshold is assigned 1."),
   make_option(c("-p", "--persist"), action="store", default=0, type='numeric',
              help="If a numeric argument is passed with this flag, 
                  perseveration of timepoint flagging will be imposed.
                  For instance, -p 5 will result in the 5 points that
                  follow any flagged point being flagged.")
)
opt = parse_args(OptionParser(option_list=option_list))

if (is.na(opt$ts)) {
   cat('User did not specify an input timeseries.\n')
   cat('Use tmask.R -h for an expanded usage menu.\n')
   quit()
}

ts <- unname(as.matrix(read.table(opt$ts)))
thr <- opt$thr
mincontig <- opt$mincontig
out <- opt$out
persist <- opt$persist
invert <- opt$invert
rad2mm <- opt$convert

###################################################################
# 1. Directly censor any superthreshold/subthreshold volumes
###################################################################
nobs <- dim(ts)[1]
tmask <- matrix(nrow=nobs,ncol=1)
if (!invert) {
   for (obs in 1:nobs){
      if (ts[obs,] < thr){
         tmask[obs,] <- 1
      } else {
         tmask[obs,] <- 0
      }
   }
} else {
   for (obs in 1:nobs){
      if (ts[obs,] > thr){
         tmask[obs,] <- 1
      } else {
         tmask[obs,] <- 0
      }
   }
}

###################################################################
# Censor following volumes if requested.
###################################################################
if (persist != 0){
   tmaskp <- tmask
   for (obs in 1:nobs){
      if (tmask[obs] == 0){
         tmaskp[obs:(obs+persist)] <- 0
      }
   }
   tmask <- tmaskp
}

###################################################################
# 2. Censor any intervening volumes if the number of
#    contiguous volumes is insufficient
###################################################################
marker <- 0
contig <- 0
for (obs in 1:nobs){
  if ((tmask[obs] == 1) & (marker == 0)) {
    marker <- obs
  } else if (tmask[obs] == 0) {
    contig <- obs - 1 - marker
    if (contig < mincontig) {
      tmask[marker:obs] <- 0
    }
    marker <- 0
  }
}

###################################################################
# 4. Write output.
###################################################################
if (!is.na(out)) {
   write.table(tmask,file=out, col.names = F, row.names = F)
} else {
   cat(tmask)
   cat('\n')
}
