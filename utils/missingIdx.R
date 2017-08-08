#!/usr/bin/env Rscript

###################################################################
#  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  #
###################################################################

###################################################################
# Function for identifying rows and columns consisting of missing
# values.
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
   make_option(c("-i", "--input"), action="store", default=NA, type='character',
              help="Path to the input to be checked for missing rows
                     and columns. Any header is treated as a row.
                     
                     DO NOT USE THIS UTILITY OUTSIDE OF THE MODULE
                     CONTEXT AT THIS TIME.")
)

opt = parse_args(OptionParser(option_list=option_list))

if (is.na(opt$input)) {
   cat('User did not specify an input.\n')
   cat('Use missing.R -h for an expanded usage menu.\n')
   quit()
}

input <- as.matrix(read.table(opt$input,header=F))
if (dim(input)[1] == 1 || dim(input)[2] == 1) {
   input <- squareform(as.vector(input))
}

###################################################################
# Create a missing-values mask
###################################################################
missing_mask <- function(adjmat) {
   missing_idx       <- c()
   missing_ct        <- apply(adjmat, 2, function(x) sum(is.na(x)))
   while (sum(missing_ct)!=0) {
      idx_max        <- which(missing_ct==max(missing_ct))
      missing_idx    <- c(missing_idx,idx_max)
      adjmat         <- adjmat[-missing_idx,-missing_idx]
      missing_ct     <- apply(adjmat, 2, function(x) sum(is.nan(x)))
   }
   return(as.vector(unname(missing_idx)))
}

missing_idx <- missing_mask(input)
for (i in missing_idx) {
   cat(i,'\n')
}
