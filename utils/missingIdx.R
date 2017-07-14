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

input <- read.table(opt$input,header=F)

###################################################################
# Identify the number of missing items in each row.
###################################################################
missing_ct <- apply(input, 2, function(x) sum(is.nan(x)))
if (sum(missing_ct)==0) { return() }

idx_max <- which(missing_ct==max(missing_ct))

###################################################################
# Determine whether removing the worst rows results in a matrix
# without missing values.
###################################################################
input_new <- input[-idx_max,-idx_max]
missing_ct_new <- apply(input_new, 2, function(x) sum(is.nan(x)))
if (sum(missing_ct_new)==0) {
   cat(idx_max,'\n')
}
