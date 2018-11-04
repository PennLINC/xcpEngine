#! /usr/bin/env Rscript

################################################################### 
#  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  #
###################################################################

###################################################################
# THE FUNCTIONALITY OF generate matrices.R IS CRUDE AND LIKELY TO CHANGE IN
# THE FUTURE.
# You are advised to avoid excessive dependency on this script
# for the time being.
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#

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
   make_option(c("-i", "--mat"), action="store", default='null', type='character',
              help="Path to the first matrix to be merged or operated upon"),
   make_option(c("-j", "--js"), action="store", default='null', type='character',
              help=" Specify the confound require  to pull out  from frmriprep ouput
                  
   
                  'CSF'         : returns an unmodified matrix identical to
                                  the argument that is not assigned a value 
                                  of null
                  'WhiteMatter'  : returns a matrix consisting of the first
                                   argument concatenated horizontally to its
                                   first and second temporal derivatives
                  
                  etc."),
   make_option(c("-o", "--out"), action="store", default=NA, type='character',
              help="Output path")
)
opt = parse_args(OptionParser(option_list=option_list))

if (is.na(opt$out)) {
   cat('User did not specify an output path.\n')
   cat('Use generate_confmat.R -h for an expanded usage menu.\n')
   quit()
}

in1 <- opt$mat
in2 <- opt$js
out <- opt$out

###################################################################
###################################################################
outmat=0

## read the confoundmatrix
mat1 <- read.table(in1,sep = '\t', header =TRUE)


if (in2 == 'csf') {
   outmat=mat1$CSF
}  else if (in2 == 'wm' ) {
   outmat=mat1$WhiteMatter
}  else if (in2 == 'gsr' ) {
   outmat=mat1$GlobalSignal
} else if ( in2 == 'tCompCor' ) {
   outmat <- mat1[ , grepl('tCompCor',names(mat1))]
} else if ( in2 == 'aCompCor' ) {
  outmat <- mat1[ , grepl('aCompCor', names(mat1))]
} else if ( in2 == 'Cosine') { 
  outmat = mat1[ , grepl( 'Cosine', names(mat1))]
} else if ( in2 == 'rps' ) {
   outmat=cbind(mat1$X,mat1$Y,mat1$Z,mat1$RotX,mat1$RotY,mat1$RotZ)
} else if (in2 == 'stdVARS') { 
  outmat=mat1$stdVARS
} else if (in2 == 'allVARS') {
  outmat=mat1[ , grepl( 'VARS' , names(mat1) ) ]
} else if ( in2 == 'rms' ) {
   mat2=cbind(mat1$X,mat1$Y,mat1$Z)
   rms=sqrt(mat2^2)
   outmat=rowMeans(rms)   
} else  {
 sprintf("the input is not available yet") 
}

write.table(outmat,file=out, col.names = F, row.names=F,quote=F)
