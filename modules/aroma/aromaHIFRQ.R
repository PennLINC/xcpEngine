#! /usr/bin/env Rscript

################################################################### 
#  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  #
###################################################################

###################################################################
# aromaHIFRQ.R is a specialised script for extracting the high-
# frequency content feature from the Fourier transform of the
# IC timeseries for use in ICA-AROMA classification.
###################################################################

###################################################################
# Load required libraries
###################################################################
suppressMessages(suppressWarnings(require(optparse)))
suppressMessages(suppressWarnings(require(pracma)))

###################################################################
# Parse arguments to script, and ensure that the required arguments
# have been passed.
###################################################################
option_list = list(
   make_option(c("-i", "--icft"), action="store", default=NA, type='character',
              help="Path to the Fourier-transformed IC timeseries"),
   make_option(c("-t", "--trep"), action="store", default=NA, type='numeric',
              help="The repetition time of the timeseries of origin")
)
opt = parse_args(OptionParser(option_list=option_list))

if (is.na(opt$icft)) {
   cat('User did not specify Fourier-transformed ICs.\n')
   cat('Use aromaHIFRQ.R -h for an expanded usage menu.\n')
   quit()
}

if (is.na(opt$trep)) {
   cat('User did not specify the repetition time.\n')
   cat('Use aromaHIFRQ.R -h for an expanded usage menu.\n')
   quit()
}

icft <- read.table(opt$icft,header=FALSE)
trep <- opt$trep

###################################################################
# Determine the Nyquist frequency.
###################################################################
nyquist <- 0.5/trep

###################################################################
# Determine what frequency corresponds to each row in the FTd ICs.
###################################################################
f <- (nyquist * seq(1,dim(icft)[1]))/dim(icft)[1]

###################################################################
# Include only frequencies greater than 0.01
###################################################################
idx <- which(f > 0.01)
f <- f[idx]
icft <- icft[idx,]

###################################################################
# Normalise frequency values so that they range from 0 to 1
###################################################################
fnorm <- (f - 0.01)/(nyquist - 0.01)

###################################################################
# Determine the cumulative fraction of the power spectrum
# that corresponds to each frequency and all lower frequencies.
###################################################################
ftcs <- apply(icft,2,cumsum)
ftcs_frac <- apply(ftcs, 1, function(x) x/colSums(icft))

###################################################################
# Identify the frequency that most closely partitions each
# frequency domain into halves.
###################################################################
idx_cutoff <- apply(abs(ftcs_frac -0.5),1, function(x) which(x==min(x)))

###################################################################
# Obtain the fractional frequency associated with these indices.
###################################################################
hfc <- fnorm[idx_cutoff]

###################################################################
# Print the feature scores.
###################################################################
cat(hfc)
