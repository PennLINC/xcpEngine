#! /usr/bin/env Rscript

################################################################### 
#  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  #
###################################################################

###################################################################
# THE FUNCTIONALITY OF mbind.R IS CRUDE AND LIKELY TO CHANGE IN
# THE FUTURE.
# You are advised to avoid excessive dependency on this script
# for the time being.
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
# Simple R script to merge two text files/matrices
# together or potentially perform operations.
# In the input matrices, variables must be columns and
# observations rows
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
   make_option(c("-x", "--mat1"), action="store", default='null', type='character',
              help="Path to the first matrix to be merged or operated upon"),
   make_option(c("-y", "--mat2"), action="store", default='null', type='character',
              help="Path to the second matrix to be merged or operated upon
                  
                  This utility function is designed to facilitate assembly
                  of a confound matrix from a number of input timeseries.
                  Inputs -x and -y may also take any of the following values:
                  'null'     : returns an unmodified matrix identical to
                               the argument that is not assigned a value 
                               of null
                  'OPdx2'    : returns a matrix consisting of the first
                               argument concatenated horizontally to its
                               first and second temporal derivatives
                  'OPprev1'  : returns a matrix consisting of the first
                               argument concatenated horizontally to the
                               same matrix shifted forward in time, so
                               that the value of the shifted timeseries at
                               t is equal to the value of the timeseries at
                               t - 1
                  'OPpower3' : returns a matrix consisting of the first
                               argument concatenated horizontally to the
                               same matrix raised to the second and third
                               powers
                  etc."),
   make_option(c("-o", "--out"), action="store", default=NA, type='character',
              help="Output path")
)
opt = parse_args(OptionParser(option_list=option_list))

if (is.na(opt$out)) {
   cat('User did not specify an output path.\n')
   cat('Use mbind.R -h for an expanded usage menu.\n')
   quit()
}

in1 <- opt$mat1
in2 <- opt$mat2
out <- opt$out

###################################################################
###################################################################
outmat=0

if ( in1 == in2 ) {
  cat('Matrix merge aborted:')
  cat('The inputs must not be identical')
  quit
  
} else if (in1=='null') {
  outmat <- unname(as.matrix(read.table(in2)))
  
} else if (in2=='null') {
  outmat <- unname(as.matrix(read.table(in1)))
  
} else if (grepl('OPdx',in2)) {
  order <- as.numeric(gsub('^OPdx','',in2))
  inmat <- unname(as.matrix(read.table(in1)))
  nobs <- dim(inmat)[1]
  nvar <- dim(inmat)[2]
  outmat <- matrix(nrow=nobs,ncol=0)
  for (ord in 1:order){
    out.deriv <- diff(inmat,lag=1,differences=ord)
    out.pad <- matrix(0,ord,nvar)
    out.deriv.padded<-rbind(out.pad,out.deriv)
    outmat <- cbind(outmat,out.deriv.padded)
  }
  outmat <- cbind(inmat,outmat)
  
} else if (grepl('OPprev',in2)) {
  orders <- as.numeric(unlist(strsplit(gsub('^OPprev','',in2),',')))
  inmat <- unname(as.matrix(read.table(in1)))
  nobs <- dim(inmat)[1]
  nvar <- dim(inmat)[2]
  outmat <- matrix(nrow=nobs,ncol=0)
  for (order in orders) {
     if (sign(order) == 1){
        for (ord in 1:order) {
          out.prev <- circshift(inmat,c(1*ord,0))
          out.prev[1:ord,] <- 0
          outmat <- cbind(outmat,out.prev)
        }
     } else if (sign(order) == -1){
        order=-1*order
        for (ord in 1:order) {
          out.prev <- circshift(inmat,c(-1*ord,0))
          bgn <- dim(inmat)[1]-ord+1
          fin <- dim(inmat)[1]
          out.prev[bgn:fin,] <- 0
          outmat <- cbind(outmat,out.prev)
        }
     }
  }
  outmat <- cbind(inmat,outmat)
  
} else if (grepl('OPpower',in2)) {
  order <- as.numeric(gsub('^OPpower','',in2))
  inmat <- unname(as.matrix(read.table(in1)))
  nobs <- dim(inmat)[1]
  nvar <- dim(inmat)[2]
  outmat <- matrix(nrow=nobs,ncol=0)
  for (ord in 1:order) {
    out.power <- inmat ^ ord
    outmat <- cbind(outmat,out.power)
  }
  
} else {
  inmat1 <- unname(as.matrix(read.table(in1)))
  inmat2 <- unname(as.matrix(read.table(in2)))
  outmat <- cbind(inmat1,inmat2)
}

outmat <- outmat[,!duplicated(t(outmat))]

write.table(outmat,file=out, col.names = F, row.names = F)
