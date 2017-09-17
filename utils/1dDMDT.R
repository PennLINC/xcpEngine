#! /usr/bin/env Rscript

###################################################################
#  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  #
###################################################################

###################################################################
# generalised function for demeaning and detrending 1D time series
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
              help="Path to the 1D timeseries to be detrended"),
   make_option(c("-d", "--detrend"), action="store", default=0, type='numeric',
              help="The order of polynomial detrend to be applied to the
                  timeseries:
                  0 : demean only [default]
                  1 : linear detrend
                  2 : quadratic detrend
                  3 : cubic detrend
                  etc."),
   make_option(c("-o", "--out"), action="store", default=NA, type='character',
              help="Output path"),
   make_option(c("-t", "--tmask"), action="store", default='ones', type='character',
              help="Temporal mask indicating the volumes that should be
                  taken under consideration when the linear model is
                  computed. [default]: Use all volumes.")
)
opt = parse_args(OptionParser(option_list=option_list))

if (is.na(opt$input)) {
   cat('User did not specify an input timeseries.\n')
   cat('Use 1Ddmdt.R -h for an expanded usage menu.\n')
   quit()
}
if (is.na(opt$out)) {
   cat('User did not specify an output path.\n')
   cat('Use 1Ddmdt.R -h for an expanded usage menu.\n')
   quit()
}

order                   <- opt$detrend
matpath                 <- opt$input
tmaskpath               <- opt$tmask
out                     <- opt$out
###################################################################
# 1. Load in the matrix to determine time series dimensions
###################################################################
inmat                   <- unname(as.matrix(read.table(matpath,header=F)))
nobs                    <- dim(inmat)[1]
nvar                    <- dim(inmat)[2]
###################################################################
# 2. Build a matrix of regressors
###################################################################
#    demean
###################################################################
curreg                  <- rep(1,nobs)
regmat                  <- matrix(curreg,nrow=nobs,ncol=1)
###################################################################
#    polynomial detrend
###################################################################
if (order > 0) {
   linreg               <- seq(0,1,length=nobs)
   curreg               <- stats::poly(1:(nobs*2),degree=order)
   curreg               <- curreg[(nobs+1):(nobs*2),]
   regmat               <- cbind(regmat,curreg)
}

###################################################################
# 3. Determine temporal mask
###################################################################
if (tmaskpath=='ones'){
   tmask                <- rep(1,nobs)
} else {
   tmask                <- unname(as.numeric(unlist(read.table(tmaskpath))))
}
tmask                   <- as.logical(tmask)
###################################################################
# Censored regressor matrix
###################################################################
regmat_censored         <- regmat[tmask,]


###################################################################
# Iterate through all time series
###################################################################
mat_dmdt <- matrix(nrow=nobs,ncol=nvar)
for (vidx in 1:nvar) {
   ts                   <- inmat[,vidx]
  
   ################################################################
   # 3. Solve for parameter estimates
   #    using left division
   ################################################################
   betas                <- mldivide(regmat_censored,ts[tmask])
   dmdt                 <- t(betas) %*% t(regmat)
   
   ################################################################
   # 4. Detrend timeseries with respect to regressors
   ################################################################
   ts_dmdt              <- ts - dmdt
   mat_dmdt[,vidx]      <- ts_dmdt
}

###################################################################
# 5. Write out the matrix
###################################################################
write.table(mat_dmdt, file = out, col.names = F, row.names = F)
