#!/usr/bin/env Rscript

################################################################### 
#  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  #
###################################################################

###################################################################
# Utility script adaptation of Srinidhi KL's timeseries2matrix
#
# roi2ts uses an input network map or mask and a BOLD timeseries
# to generate node-specific timeseries for all network elements
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
              help="Path to the 4d BOLD timeseries from which the timeseries
                  will be extracted."),
   make_option(c("-r", "--roi"), action="store", default=NA, type='character',
              help="A 3D image specifying the nodes or regions of interest
                  according to which extracted timeseries should be sorted."),
   make_option(c("-t", "--ts"), action="store", default=NA, type='character',
              help="A path to an additional 1D timeseries to include as a
                  line plot."),
   make_option(c("-f", "--outfig"), action="store", default='similPlot.svg', type='character',
              help="The path where the voxelwise timeseries plot between
                     should be printed. This output will only be produced
                     if ggplot2 is installed. Otherwise, this script will
                     do nothing.")
)
opt = parse_args(OptionParser(option_list=option_list))

if (is.na(opt$img)) {
   cat('User did not specify an input timeseries.\n')
   cat('Use roi2ts.R -h for an expanded usage menu.\n')
   quit()
}
if (is.na(opt$roi)) {
   cat('User did not specify an input RoI map.\n')
   cat('Use roi2ts.R -h for an expanded usage menu.\n')
   quit()
}

impath <- opt$img
roipath <- opt$roi
tspath <- opt$ts
outfig <- opt$outfig

if (! "ggplot2" %in% rownames(installed.packages())){
   warning('The R package ggplot2 is not installed. A voxelwise\n')
   warning('timeseries plot will not be created. If this message\n')
   warning('occurs in the context of a larger analysis, it most\n')
   warning('likely will not affect the processing.\n')
   quit()
}

###################################################################
# 1. Load in the image.
###################################################################
suppressMessages(require(ggplot2))
img <- readNifti(impath)
tp <- dim(img)[length(dim(img))]

###################################################################
# 2. Load in the regional mask
###################################################################
net <- readNifti(roipath)

###################################################################
# 3. (as in roi2ts or Shrinidhi KL's timeseries2matrix)
#    Obtain all unique nonzero values in the mask.
###################################################################
labs <- sort(unique(net[net > 0]))
length(labs)

###################################################################
# 4. Iterate through all labels. Extract the voxelwise timeseries
#    matrix from each, and bind it to the extant voxelwise
#    timeseries matrix.
###################################################################
logmask <- (net == labs[1])


tp
sum(logmask)
mat <- img[logmask]
dim(mat) <- c(sum(logmask), tp)
indvec <- ones(sum(logmask),1)
if (length(labs) > 1) {
   for (i in 2:length(labs)) {
      logmask <- (net == labs[i])
      cmat <- img[logmask]
      dim(cmat) <- c(sum(logmask), tp)
      cindvec <- ones(sum(logmask),1) * i
      mat <- rbind(mat,cmat)
      indvec <- rbind(indvec,cindvec)
   }
}
mat <- t(scale(t(mat)))

###################################################################
# 5. Prepare the plot.
###################################################################
rm(img)
rm(net)
png(filename=outfig,width=2000,height=700)
par(fig=c(0.1,1,0,0.8),mar=c(0.5,0.5,0.5,0.5),new=TRUE)
image(t(mat),zlim=c(quantile(mat,0.1,na.rm=TRUE),quantile(mat,0.9,na.rm=TRUE)),col=grey(c(seq(0,0.1,0.001),seq(0.1,0.9,0.01),seq(0.9,1,0.01))),xaxt='n',yaxt='n',ann=FALSE)
par(fig=c(0,0.1,0,0.8),mar=c(0.5,0.5,0.5,0.5),new=TRUE)
image(t(indvec),col=rainbow(length(labs)*1.5)[1:length(labs)],xaxt='n',yaxt='n',ann=FALSE)
if (!is.na(tspath)){
   par(fig=c(0.1,1,0.8,1),mar=c(0.5,0.5,0.5,0.5),new=TRUE)
   ts <- as.matrix(read.table(tspath,header=FALSE))
   matplot(scale(ts),type='l',lwd=5,xaxs='i',xaxt='n',yaxt='n',ann=FALSE)
}
dev.off()

