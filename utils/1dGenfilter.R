#! /usr/bin/env Rscript

###################################################################
#  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  #
###################################################################

###################################################################
# * Generalised filter function for FC processing
# * Filters an input matrix rather than an image:
#   for instance, a matrix of RPs
# * Utility function for xcpEngine
###################################################################

###################################################################
# Load required libraries
###################################################################
suppressMessages(suppressWarnings(library(optparse)))
suppressMessages(suppressWarnings(library(signal)))

###################################################################
# Parse arguments to script, and ensure that the required arguments
# have been passed.
###################################################################
option_list = list(
   make_option(c("-i", "--input"), action="store", default=NA, type='character',
              help="Path to the timeseries matrix to be filtered"),
   make_option(c("-o", "--out"), action="store", default=NA, type='character',
              help="Output path"),
   make_option(c("-t", "--trep"), action="store", default=NA, type='numeric',
              help="Repetition time or sampling interval for the input
                  matrix"),
   make_option(c("-f", "--filter"), action="store", default='butterworth', type='character',
              help="The class of filter to be applied to the timeseries.
                  Valid options include:
                   * butterworth [default]
                   * chebyshev1
                   * chebyshev2
                   * elliptic"),
   make_option(c("-c", "--hipass"), action="store", default=0.01, type='numeric',
              help="The lower bound on frequencies permitted by the filter.
                  Any frequencies below the highpass cutoff will be
                  attenuated. [default 0.01]"),
   make_option(c("-l", "--lopass"), action="store", default="nyquist", type='character',
              help="The upper bound on frequencies permitted by the filter.
                  Any frequencies above the lowpass cutoff will be
                  attenuated. [default Nyquist]"),
   make_option(c("-r", "--order"), action="store", default=1, type='numeric',
              help="The filter order indicates the number of input samples
                  taken under consideration when generating an output
                  signal. In general, using a higher-order filter will
                  result in a sharper cutoff between accepted and
                  attenuated frequencies. For a gentler filter, use a
                  lower order."),
   make_option(c("-d", "--direction"), action="store", default=2, type='numeric',
              help="The filter direction indicates whether the input signal
                  should be processed in the forward direction only [-d 1]
                  or in both forward and reverse directions [-d 2]."),
   make_option(c("-p", "--rpass"), action="store", default=1, type='numeric',
              help="Chebyshev I and elliptic filters allow for sharper
                  discrimination between accepted and attenuated
                  frequencies at the cost of a 'ripple' in the pass band.
                  This ripple results in somewhat uneven retention of
                  pass-band frequencies."),
   make_option(c("-s", "--rstop"), action="store", default=1, type='numeric',
              help="Chebyshev II and elliptic filters allow for sharper
                  discrimination between accepted and attenuated
                  frequencies at the cost of a 'ripple' in the stop band.
                  This ripple results in somewhat uneven removal of
                  stop-band frequencies.")
)
opt = parse_args(OptionParser(option_list=option_list))

if (is.na(opt$input)) {
   cat('User did not specify an input timeseries.\n')
   cat('Use dmdt.R -h for an expanded usage menu.\n')
   quit()
}
if (is.na(opt$out)) {
   cat('User did not specify an output path.\n')
   cat('Use dmdt.R -h for an expanded usage menu.\n')
   quit()
}
if (is.na(opt$trep)) {
   cat('User did not specify a sampling interval.\n')
   cat('Use dmdt.R -h for an expanded usage menu.\n')
   quit()
}

matpath <- opt$input
out <- opt$out
type <- opt$filter
tr <- opt$trep
order <- opt$order
direction <- opt$direction
hpf <- opt$hipass
lpf <- opt$lopass
ripple <- opt$rpass
ripple2 <- opt$rstop


################################################################### 
# 1. Construct the filter
# a. Compute Nyquist
################################################################### 
nyquist <- 1/(2*tr)
################################################################### 
# b. Convert input frequencies to percent Nyquist
# low pass
################################################################### 
if (lpf=='nyquist'){
  lpnorm <- 1
} else {
  lpf <- as.numeric(lpf)
  lpnorm <- lpf/nyquist
}
if (lpnorm > 1){
  lpnorm <- 1
}
################################################################### 
# high pass
################################################################### 
hpnorm <- hpf/nyquist
if (hpnorm < 0){
  hpnorm <- 0
}
################################################################### 
# c. Generate the filter
################################################################### 
if (type=='butterworth'){
  filt <- signal::butter(order, c(hpnorm,lpnorm), "pass", "z")
} else if (type=='chebyshev1'){
  filt <- signal::cheby1(order, ripple, 
                         c(hpnorm,lpnorm), "pass", "z")
} else if (type=='chebyshev2'){
  filt <- signal::cheby2(order, ripple2,
                         c(hpnorm,lpnorm), "pass", "z")
} else if (type=='elliptic') {
  filt <- signal::ellip(order, ripple, ripple2,
                        c(hpnorm,lpnorm), "pass", "z")
}

################################################################### 
# 2. Load in the matrix
################################################################### 
tss <- unname(as.matrix(read.table(matpath)))
nobs <- dim(tss)[1]
nvar <- dim(tss)[2]

################################################################### 
# 3. Apply the filter
################################################################### 
mat_filt <- matrix(nrow=nobs,ncol=nvar)
for (var in 1:nvar){
  ts <- tss[,var]
  if (direction==1){
    ts_filt <- signal::filter(filt,ts)
  } else if (direction==2){
    ts_filt <- signal::filtfilt(filt,ts)
  }
  mat_filt[,var] <- ts_filt
}

################################################################### 
# 4. Write out the matrix
################################################################### 
write.table(mat_filt, file = out, col.names = F, row.names = F)
