#! /usr/bin/env Rscript

# generalised function for demeaning and detrending
# timeseries

suppressMessages(library('pracma'))

# read in arguments
args <- commandArgs(trailingOnly = TRUE)
# first argument should be detrend order
# 0-order represents demeaning only
# 1-order is linear, 2-order square, etc.
order <- as.numeric(args[1])
# second argument should be path to matrix to be detrended
matpath <- args[2]
# third argument should be output name
out <- args[3]

# 1. Load in the matrix to determine timeseries dimensions
inmat <- unname(as.matrix(read.table(matpath)))
nobs <- dim(inmat)[1]
nvar <- dim(inmat)[2]

# 2. Build a matrix of regressors
# demean
curreg <- rep(1,nobs)
regmat <- matrix(curreg,nrow=nobs,ncol=1)
# linear detrend
if ( order > 0 ){
  linreg <- seq(0,1,length=nobs)
  curreg <- linreg
  regmat <- cbind(regmat,curreg)
}
ordin <- 1
# higher-order polynomial detrend
while ( ordin < order ) {
  curreg <- curreg * linreg
  regmat <- cbind(regmat,curreg)
  ordin <- ordin + 1
}

# Iterate through all voxels
mat_dmdt <- matrix(nrow=nobs,ncol=nvar)
for (vidx in 1:nvar) {
  ts <- inmat[,vidx]
  
  # 3. Solve for parameter estimates
  #    using left division
  betas <- mldivide(regmat,ts)
  dmdt <- t(betas) %*% t(regmat)
  
  # 4. Detrend timeseries with respect to regressors
  ts_dmdt <- ts - dmdt
  mat_dmdt[,vidx] <- ts_dmdt
}

# 5. Write out the matrix
write.table(mat_dmdt, file = out, col.names = F, row.names = F)