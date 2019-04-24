#!/usr/bin/env Rscript

################################################################### 
#  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  #
###################################################################

###################################################################
# distmat reads in a spatial coordinates library and outputs a
# matrix of the pairwise distance between all points in the
# library
###################################################################

###################################################################
# Load required libraries
###################################################################
suppressMessages(suppressWarnings(library(optparse)))

###################################################################
# Parse arguments to script, and ensure that the required arguments
# have been passed.
###################################################################
option_list = list(
   make_option(c("-i", "--input"), action="store", default=NA, type='character',
              help="Path to the spatial coordinates library or csv to be
                     converted"),
   make_option(c("-c", "--conversion"), action="store", default='sclib2csv', type='character',
              help="The conversion to perform -- either sclib2csv [default],
                     csv2sclib, sclib2tsv, tsv2sclib, csv2tsv, or tsv2csv."),
   make_option(c("-o", "--output"), action="store", default=NA, type='character',
              help="The path where the converted file is to be written.")
)
opt = parse_args(OptionParser(option_list=option_list))

if (is.na(opt$input)) {
   cat('User did not specify an input file for conversion.\n')
   cat('Use sclib2csv.R -h for an expanded usage menu.\n')
   quit()
}
if (is.na(opt$output)) {
   cat('User did not specify an output path for the converted.\n')
   cat('file. Use sclib2csv.R -h for an expanded usage menu.\n')
   quit()
}
input             <- opt$input
convert           <- opt$conversion
output            <- opt$output

###################################################################
# Perform the conversion.
###################################################################
if          (convert == 'sclib2csv') {
   sink(output)
   cat('x,y,z,t,label,comment\n')
   coor           <- readLines(input)[grep('^#',readLines(input))]
   coor           <- lapply(coor, function(x) unlist(strsplit(x,'#')))
   coor.coors     <- lapply(coor, function(x) as.numeric(unlist(strsplit(x[3],','))))
   coor.rad       <- lapply(coor, function(x) as.numeric(x[4]))
   for (i in 1:length(coor)) {
      cat(cat(c(coor.coors[[i]],0,i,coor.rad[[i]]),sep=','),'\n',sep='')
   }
   sink(NULL)
} else if   (convert == 'csv2sclib') {
   sink(output)
   coor           <- read.csv(input,header=T)
   coor.coors     <- cbind(coor$x,coor$y,coor$z)
   coor.rad       <- coor$comment
   coor.label     <- coor$label
   for (i in 1:dim(coor)[1]) {
      cat(paste('',paste('Node',coor.label[i],sep=''),paste(coor.coors[i,],collapse=','),coor.rad[i],sep='#'),'\n')
   }
   sink(NULL)
} else if   (convert == 'sclib2tsv') {
   cat('Operation not yet supported: ',convert,'\n',sep='')

} else if   (convert == 'tsv2sclib') {
   cat('Operation not yet supported: ',convert,'\n',sep='')

} else if   (convert == 'csv2tsv') {
   cat('Operation not yet supported: ',convert,'\n',sep='')

} else if   (convert == 'tsv2csv') {
   cat('Operation not yet supported: ',convert,'\n',sep='')

} else {
   cat('Operation not supported: ',convert,'\n',sep='')
}
