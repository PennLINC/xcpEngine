#! /usr/bin/env Rscript

################################################################### 
#  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  #
###################################################################

###################################################################
# aromaRPCOR.R is a specialised script for extracting the maximal
# realignment-parameter correlation feature for the ICA-AROMA
# procedure. It accepts as inputs timeseries matrices derived
# from ICs and from RPs, then performs a robust correlation
# analysis to compute the maximal correlation feature.
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
   make_option(c("-i", "--icts"), action="store", default=NA, type='character',
              help="Path to the matrix derived from IC timeseries"),
   make_option(c("-r", "--rpts"), action="store", default=NA, type='character',
              help="Path to the matrix derived from RP timeseries"),
   make_option(c("-n", "--nsplit"), action="store", default=1000, type='numeric',
              help="Number of repetitions for robust correlation
                     [default 1000]"),
   make_option(c("-p", "--pct"), action="store", default=0.9, type='numeric',
              help="Percentage to include in the bootstrap for
                     robust correlation [default 0.9]"),
   make_option(c("-s", "--squares"), action="store", default=TRUE, type='logical',
              help="Denotes whether the input matrices include square
                     terms that should be treated separately. (These
                     terms should constitute the right-hand half of
                     each input matrix.) [default TRUE]")
)
opt = parse_args(OptionParser(option_list=option_list))

if (is.na(opt$icts)) {
   cat('User did not specify IC timeseries.\n')
   cat('Use aromaRPCOR.R -h for an expanded usage menu.\n')
   quit()
}

if (is.na(opt$rpts)) {
   cat('User did not specify RP timeseries.\n')
   cat('Use aromaRPCOR.R -h for an expanded usage menu.\n')
   quit()
}

icts <- read.table(opt$icts,header=FALSE)
rpts <- read.table(opt$rpts,header=FALSE)
nsplit <- opt$nsplit
pct <- opt$pct
sq <- opt$squares

###################################################################
# If square terms are included and should be handled separately,
# then separate them here.
###################################################################
if (sq){
   icd <- dim(icts)[2]/2
   nic <- dim(icts)[2]
   rpd <- dim(rpts)[2]/2
   nrp <- dim(rpts)[2]
   ictsSq <- icts[,(icd+1):nic]
   rptsSq <- rpts[,(rpd+1):nrp]
   icts <- icts[,1:icd]
   rpts <- rpts[,1:rpd]
}

###################################################################
# Perform nsplit correlations.
###################################################################
maxTC <- zeros(nsplit,dim(icts)[2])
nret <- round(dim(icts)[1] * pct)
for (i in seq(0,nsplit)){
   ################################################################
   # Draw pct timepoints at random and select them from the
   # RP and IC matrices.
   ################################################################
   idx <- sort(randperm(seq(1,dim(icts)[1]))[1:nret])
   rptsCur <- rpts[idx,]
   ictsCur <- icts[idx,]
   if (sq){
      rptsCurSq <- rptsSq[idx,]
      ictsCurSq <- ictsSq[idx,]
   }
   ################################################################
   # Compute the correlations.
   ################################################################
   rpCor <- cor(ictsCur,rptsCur)
   if (sq){
      rpCorSq <- cor(ictsCurSq,rptsCurSq)
      rpCor <- cbind(rpCor,rpCorSq)
   }
   ################################################################
   # Identify the absolute maximum.
   ################################################################
   rpCor <- abs(rpCor)
   maxTC[i,] <- apply(rpCor,1,max)
}
###################################################################
# Compute the mean absolute maximum over all bootstraps.
###################################################################
maxRPcor <- apply(maxTC,2,mean)
###################################################################
# Print the mean absolute maxima.
###################################################################
cat(maxRPcor)
