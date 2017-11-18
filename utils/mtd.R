#! /usr/bin/env Rscript

###################################################################
#  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  #
###################################################################

###################################################################
# R script to compute dynamic (or static) functional connectivity
# using the multiplication of temporal derivatives (MTD) approach
#
# Citation:
# Shine et al. (2015) Estimation of dynamic functional connectivity
# using Multiplication of Temporal Derivatives
###################################################################

###################################################################
# Load required libraries
###################################################################
suppressMessages(suppressWarnings(library(optparse)))
suppressMessages(suppressWarnings(library(pracma)))

###################################################################
# Parse arguments to script, and ensure that the required arguments
# have been passed.
###################################################################
option_list = list(
   make_option(c("-t", "--ts"), action="store", default=NA, type='character',
              help="Path to a file containing the nodewise timeseries"),
   make_option(c("-w", "--window"), action="store", default=50, type='numeric',
              help="The duration of the window, in TRs (NOT seconds) [default 50]"),
   make_option(c("-p", "--pad"), action="store", default=FALSE, type='logical',
              help="Should the data be padded to return n - 1 observations [TRUE]
                     or should connectivity only be computed in complete windows
                     [FALSE, default]?"),
   make_option(c("-s", "--shape"), action="store", default='box', type='character',
              help="The shape of the window. Currently this does nothing.")
)
opt = parse_args(OptionParser(option_list=option_list))
ts             <- opt$ts
window.shape   <- opt$shape
window.length  <- opt$window
pad            <- opt$pad

if (is.na(ts)) {
   cat('User did not specify path to input timeseries.\n')
   cat('Use mtd.R -h for an expanded usage menu.\n')
   quit()
}

###################################################################
# 1. Load in nodewise timeseries
###################################################################
ts <- unname(as.matrix(read.table(ts)))
nobs <- dim(ts)[1] - 1
nvar <- dim(ts)[2]
if (window.length > nobs) {
   window.length <- nobs
}

###################################################################
# 2. Compute the derivative
###################################################################
ts.deriv <- diff(ts,lag=1,differences=1)

###################################################################
# 3. Variance-normalise each nodewise timeseries
###################################################################
ts.deriv.sd <- apply(ts.deriv,2,sd)
ts.deriv.vn <- t((t(ts.deriv) / ts.deriv.sd))

###################################################################
# 4. Perform the multiplication of temporal derivatives
###################################################################
mtd <- combn(seq(1,nvar), 2, FUN = function (x) ts.deriv.vn[,x[1]] * ts.deriv.vn[,x[2]])
nvar <- dim(mtd)[2]

###################################################################
# 5. Create the window
###################################################################
if (window.shape == 'box') {
   window <- rep(1/window.length, length = window.length)
} else if (window.shape == 'gaussian') {
   window <- dnorm(seq(-floor(nobs/2), floor(nobs/2))/window.length)
   window <- window/sum(window)
   window.length <- nobs
} else {
   window <- rep(1/window.length, length = window.length)
}

###################################################################
# 6. Smooth the timeseries by applying a window kernel
###################################################################
if (pad) {
   samples <- seq(1, nobs)
   padding <- repmat(NaN,floor(window.length/2),nvar)
   mtd <- rbind(padding,mtd,padding)
} else {
   samples <- seq(1, nobs - window.length + 1)
}
mtd.smo <- matrix(nrow = length(samples), ncol = nvar)
for(i in 1:length(samples)){
   mtd.smo[i,] <- apply(window * (mtd[samples[i]:(samples[i] + window.length - 1),]),2,sum,na.rm=T)
}

###################################################################
# 7. Print connectivity values
###################################################################
for (row in seq(1,dim(mtd.smo)[1])) {
   cat(mtd.smo[row,])
   cat('\n')
}
