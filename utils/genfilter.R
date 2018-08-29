#! /usr/bin/env Rscript

###################################################################
#  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  #
###################################################################

###################################################################
# * Generalised filter function for FC processing
# * Utility function for xcpEngine
###################################################################

###################################################################
# Load required libraries
###################################################################
suppressMessages(suppressWarnings(library(optparse)))
suppressMessages(suppressWarnings(library(signal)))
suppressMessages(suppressWarnings(library(RNifti)))

###################################################################
# Parse arguments to script, and ensure that the required arguments
# have been passed.
###################################################################
option_list = list(
   make_option(c("-i", "--img"), action="store", default=NA, type='character',
              help="Path to the BOLD timeseries to be filtered"),
   make_option(c("-o", "--out"), action="store", default=NA, type='character',
              help="Output path"),
   make_option(c("-f", "--filter"), action="store", default='butterworth', type='character',
              help="The class of filter to be applied to the timeseries.
                  Valid options include:
                   * butterworth [default]
                   * chebyshev1
                   * chebyshev2
                   * elliptic"),
   make_option(c("-m", "--mask"), action="store", default=NA, type='character',
              help="Spatial mask indicating the voxels of the input image
                  to which the filter should be applied."),
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

if (is.na(opt$img)) {
   cat('User did not specify an input timeseries.\n')
   cat('Use genfilter.R -h for an expanded usage menu.\n')
   quit()
}
if (is.na(opt$out)) {
   cat('User did not specify an output path.\n')
   cat('Use genfilter.R -h for an expanded usage menu.\n')
   quit()
}

impath                  <- opt$img
outpath                 <- opt$out
type                    <- opt$filter
maskpath                <- opt$mask
order                   <- opt$order
direction               <- opt$direction
hpf                     <- opt$hipass
lpf                     <- opt$lopass
ripple                  <- opt$rpass
ripple2                 <- opt$rstop


###################################################################
# Compute the sequence's repetition time
###################################################################
hdr                     <- dumpNifti(impath)
tr                      <- hdr$pixdim[5]


###################################################################
# 1. Construct the filter
# a. Compute Nyquist
###################################################################
nyquist                 <- 1/(2*tr)
###################################################################
# b. Convert input frequencies to percent Nyquist
# low pass
###################################################################
if (lpf=="nyquist"){
  lpnorm                <- 1
} else {
  lpf                   <- as.numeric(lpf)
  lpnorm                <- lpf/nyquist
}
if (lpnorm > 1){
  lpnorm                <- 1
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
if          (type=='butterworth'){
  filt                  <- signal::butter(order, c(hpnorm,lpnorm),
                           "pass", "z")
} else if   (type=='chebyshev1'){
  filt                  <- signal::cheby1(order, ripple,
                           c(hpnorm,lpnorm), "pass", "z")
} else if   (type=='chebyshev2'){
  filt                  <- signal::cheby2(order, ripple2,
                           c(hpnorm,lpnorm), "pass", "z")
} else if   (type=='elliptic') {
  filt                  <- signal::ellip(order, ripple, ripple2,
                           c(hpnorm,lpnorm), "pass", "z")
}
sink("/dev/null")

###################################################################
# 2. Load in the image
###################################################################
img                     <- readNifti(impath)
out                     <- img
if (!is.na(maskpath)){
   mask                 <- readNifti(maskpath)
   logmask              <- (mask == 1)
   img                  <- img[logmask]
   dim(img)             <- c(sum(logmask),hdr$dim[5])
   img                  <- t(img)
} else {
   img                  <- as.array(img)
   dim(img)             <- c(prod(hdr$dim[2:4]),hdr$dim[5])
   img                  <- t(img)
}
nvol                    <- dim(img)[1]
nvox                    <- dim(img)[2]
sink(NULL)

###################################################################
# 3. Apply the filter
###################################################################
img_filt                <- matrix(nrow=nvol,ncol=nvox)
for (vox in 1:nvox){
  if (direction==1){
    img_filt[,vox]      <- signal::filter(filt,img[,vox])
  } else if (direction==2){
    img_filt[,vox]      <- signal::filtfilt(filt,img[,vox])
  }
}

###################################################################
# 4. Write out the image
###################################################################
if (!is.na(maskpath)){
   for (i in 1:nvol) {
      out[,,,i][logmask]<- img_filt[i,]
   }
} else {
   for (i in 1:nvol) {
      out[out > -Inf]   <- t(img_filt)
   }
}
sink("/dev/null")
rm(img, img_filt)
gc()
hdr$datatype <- 32
hdr$bitp
writeNifti(out,outpath,template=impath)
sink(NULL)
