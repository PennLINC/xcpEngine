#!/usr/bin/env Rscript

################################################################### 
#  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  #
###################################################################

###################################################################
# Utility script to compute cerebral blood flow. This utility uses
# the following model for PCASL:
#
#        6000 * lambda * (SI_control - SI_label) * e^(PLD/T1_blood)
# CBF = -----------------------------------------------------------
#          2 * alpha * T1_blood * SI_PD * (1 - e^(tau/T1_blood))
#
###################################################################

###################################################################
# Load required libraries
###################################################################
suppressMessages(suppressWarnings(library(optparse)))
suppressMessages(suppressWarnings(library(pracma)))
suppressMessages(suppressWarnings(library(RNifti)))

###################################################################
# Parse arguments to script, and ensure that the required arguments
# have been passed.
###################################################################
option_list = list(
   make_option(c("-i", "--img"), action="store", default=NA, type='character',
              help="Path to the 4D ASL time series from which perfusion
                  will be computed."),
   make_option(c("-m", "--m0"), action="store", default=NA, type='character',
              help="A map of the voxelwise proton density in the ASL
                  time series (M0)."),
   make_option(c("-v", "--volumes"), action="store", default=NA, type='character',
              help="A temporal mask indicating whether each volume is
                  tagged (1) or untagged (0)."),
   make_option(c("-o", "--out"), action="store", default=NA, type='character',
              help="The root output path for all voxelwise perfusion maps."),
   make_option(c("-s", "--scalem0"), action="store", default=10, type='numeric',
              help="A scale factor to convert the voxelwise M0 values
                  to  [default 10]."),
   make_option(c("-l", "--lambda"), action="store", default=0.9, type='numeric',
              help="The blood-brain partition coefficient for grey
                  matter in mL/g (lambda) [default 0.9]"),
   make_option(c("-d", "--delay"), action="store", default=1.5, type='numeric',
              help="The post-labelling delay (PLD) in ms
                  [default 1.5]."),
   make_option(c("-r", "--duration"), action="store", default=1.5, type='numeric',
              help="The label duration (tau) in ms
                  [default 1.5]."),
   make_option(c("-t", "--t1blood"), action="store", default=1.65, type='numeric',
              help="The longitudinal relaxation time of arterial blood
                  (T1_blood) in s [default 1.65]."),
   make_option(c("-a", "--alpha"), action="store", default=0.72, type='numeric',
              help="The labelling efficiency, which corrects for
                  background suppression pulses.")
)
opt = parse_args(OptionParser(option_list=option_list))

if (is.na(opt$img)) {
   cat('User did not specify an input ASL time series.\n')
   cat('Use perfusion.R -h for an expanded usage menu.\n')
   quit()
}
if (is.na(opt$m0)) {
   cat('User did not specify an input M0 map.\n')
   cat('Use perfusion.R -h for an expanded usage menu.\n')
   quit()
}
if (is.na(opt$volumes)) {
   cat('User did not specify whether volumes are tagged or untagged.\n')
   cat('Use perfusion.R -h for an expanded usage menu.\n')
   quit()
}

impath                  <- opt$img
m0path                  <- opt$m0
volpath                 <- opt$volumes
outpath                 <- opt$out
m0scale                 <- opt$scalem0
lambda                  <- opt$lambda
pld                     <- opt$delay
t1b                     <- opt$t1blood
alpha                   <- opt$alpha
tau                     <- opt$duration

###################################################################
# 1. Compute the scalar CBF factor to scale the images.
###################################################################
cbf                     <- (6000 * lambda * exp(pld / t1b)) /
                           (2 * alpha * m0scale * t1b * 
                           (1 - exp(-tau / t1b)))

###################################################################
# 2. Load in the images and volume labels.
###################################################################
img                     <- readNifti(impath)
m0                      <- readNifti(m0path)
tmask                   <- unname(as.numeric(unlist(read.table(volpath))))

###################################################################
# 3. Determine label-control pairs and compute the difference
#    between each.
###################################################################
con                     <- which(tmask==0)
lab                     <- which(tmask==1)
npairs                  <- min(length(lab),length(con))
con                     <- con[1:npairs]
lab                     <- lab[1:npairs]
perfusion               <- img[,,,lab] - img[,,,con]

###################################################################
# 4. Compute CBF time series and mean CBF image.
###################################################################
cbf_ts                  <- perfusion * cbf / rep(m0,40)
cbf_ts[which(is.na(cbf_ts))]     <- 0
cbf_ts[which(abs(cbf_ts)==Inf)]  <- 0
pixdim(cbf_ts)          <- pixdim(img)
pixdim(cbf_ts)[4]       <- pixdim(img)[4]*2
cbf_mean                <- apply(cbf_ts,c(1,2,3),mean)

###################################################################
# 5. Write outputs.
###################################################################
outpath_ts              <- paste(outpath,'_ts.nii.gz',sep='')
outpath_mean            <- paste(outpath,'_mean.nii.gz',sep='')
writeNifti(cbf_ts,  outpath_ts,  template=impath,datatype='float')
writeNifti(cbf_mean,outpath_mean,template=impath,datatype='float')
