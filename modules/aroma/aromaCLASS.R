#! /usr/bin/env Rscript

################################################################### 
#  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  #
###################################################################

###################################################################
# aromaCLASS.R is a specialised script for classifying components
# on the basis of four features: fraction of component mass
# in cerebrospinal fluid, fraction of component mass in edge or
# background, high-frequency content of the component, and maximum
# robust correlation with motion parameters.
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
   make_option(c("-m", "--matrix"), action="store", default=NA, type='character',
              help="Path to the Fourier-transformed IC timeseries"),
   make_option(c("-c", "--thr_csf"), action="store", default=0.1, type='numeric',
              help="[optional] The maximum fraction of a component's mass
                     that can be in the CSF before it is classified as 
                     motion-related [default 0.1]"),
   make_option(c("-f", "--thr_hfc"), action="store", default=0.35, type='numeric',
              help="[optional] If at least half of a component's power 
                     spectrum lies above this threshold, then it is
                     classified as motion [default 0.35]"),
   make_option(c("-l", "--hyp_lda"), action="store", default=c(-19.9751070082159, 9.95127547670627, 24.8333160239175), type='numeric',
              help="THIS ARGUMENT IS NONFUNCTIONAL. USE DEFAULTS OR EDIT
                     THE SCRIPT.
                     
                     [optional] 3 Parameters defining the linear discriminant
                     hyperplane (i,j,k) that determines whether a component
                     is motion on the basis of edge fraction (E) and maximum
                     RP correlation (R). First, the two dimensions are 
                     projected into a 1-dimensional space as follows:
                     
                     P = i + dot([R E],[j k])
                     P = i + jR + kE
                     
                     If the projection P is greater than 0, then the
                     component is classified as motion.
                     [default i = -19.9751070082159]
                     [default j = 9.95127547670627]
                     [default k = 24.8333160239175]
                     
                     This argument should be passed as a vector (e.g.,
                     c(-20,10,25)).
                THIS ARGUMENT IS NONFUNCTIONAL.")
)

options(warn=-1)
opt = parse_args(OptionParser(option_list=option_list))
options(warn=0)

if (is.na(opt$matrix)) {
   cat('User did not specify the ICA-AROMA feature matrix.\n')
   cat('Use aromaCLASS.R -h for an expanded usage menu.\n')
   quit()
}

if (length(opt$hyp_lda) != 3) {
   cat('The specified hyperplane has incorrect dimensions.\n')
   cat('Use aromaCLASS.R -h for an expanded usage menu.\n')
   quit()
}

classmat <- read.csv(opt$matrix)
thr_csf <- opt$thr_csf
thr_hfc <- opt$thr_hfc
hyp <- opt$hyp_lda

###################################################################
# Project the edge fraction and maximal RP correlation features
# into a 1-dimensional space.
###################################################################
proj <- hyp[1] + classmat$RPCOR*hyp[2] + classmat$FEDGE*hyp[3]

###################################################################
# Classify all ICs.
###################################################################
noiseIdx <- union(which(proj > 0),which(classmat$FCSF > thr_csf))
noiseIdx <- union(noiseIdx,which(classmat$HFC > thr_hfc))
noiseIdx <- sort(noiseIdx)

###################################################################
# Add a column corresponding to classification.
###################################################################
classmat$NOISE <- zeros(dim(classmat)[1],1)
classmat$NOISE[noiseIdx] <- 1

###################################################################
# Overwrite the input .csv
###################################################################
write.csv(classmat,file=opt$matrix,quote=FALSE,row.names=FALSE)

###################################################################
# Print thw identities of the noise components.
###################################################################
cat(noiseIdx)
