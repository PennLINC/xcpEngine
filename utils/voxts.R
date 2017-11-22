#!/usr/bin/env Rscript

################################################################### 
#  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  #
###################################################################

###################################################################
# Utility script to compute a voxelwise time series plot following
#
# Power JD (2017) A simple but useful way to assess fMRI scan
#                 qualities. NeuroImage 154:150-8.
#
###################################################################

###################################################################
# Load required libraries
###################################################################
suppressMessages(suppressWarnings(library(optparse)))
suppressMessages(suppressWarnings(library(pracma)))
suppressMessages(suppressWarnings(library(RNifti)))
suppressMessages(suppressWarnings(library(ggplot2)))
suppressMessages(suppressWarnings(library(reshape2)))
suppressMessages(suppressWarnings(library(grid)))

###################################################################
# Parse arguments to script, and ensure that the required arguments
# have been passed.
###################################################################
option_list = list(
   make_option(c("-i", "--img"), action="store", default=NA, type='character',
              help="Path to the denoised 4d BOLD timeseries from which 
                  the voxelwise timeseries will be extracted. To include
                  multiple images, pass them as a comma-separated list."),
   make_option(c("-r", "--roi"), action="store", default=NA, type='character',
              help="A 3D image specifying the labels or regions of interest
                  according to which extracted timeseries should be sorted
                  This should be a depth map, which can be obtained using
                  layerLabels."),
   make_option(c("-t", "--ts"), action="store", default=NA, type='character',
              help="A list of paths to additional 1D timeseries to include as a
                  line plot. Format as
                           
                   ts1_name:ts1_path:ts1_thresh,ts2_name:ts2_path:ts2_thresh,...
                  "),
   make_option(c("-n", "--names"), action="store", default=NA, type='character',
              help="The path to a vector of label names."),
   make_option(c("-o", "--outfig"), action="store", default='fcqa.png', type='character',
              help="The path where the voxelwise timeseries plot between
                     should be printed. This output will only be produced
                     if ggplot2 is installed. Otherwise, this script will
                     do nothing.")
)
opt = parse_args(OptionParser(option_list=option_list))

if (is.na(opt$img)) {
   cat('User did not specify an input timeseries.\n')
   cat('Use voxts.R -h for an expanded usage menu.\n')
   quit()
}
if (is.na(opt$roi)) {
   cat('User did not specify an input label map.\n')
   cat('Use voxts.R -h for an expanded usage menu.\n')
   quit()
}

impath               <- opt$img
maskpath             <- opt$roi
tspath               <- opt$ts
outfig               <- opt$outfig
names                <- opt$names

if (! "ggplot2" %in% rownames(installed.packages())){
   warning('The R package ggplot2 is not installed. A voxelwise\n')
   warning('timeseries plot will not be created. If this message\n')
   warning('occurs in the context of a larger analysis, it most\n')
   warning('likely will not affect the processing.\n')
   quit()
}





###################################################################
# 1. Determine figure parameters.
###################################################################
tslist               <- unlist(strsplit(tspath,','))
imlist               <- unlist(strsplit(impath,','))
tsct                 <- length(tslist)
imct                 <- length(imlist)
TSHT                 <- 1
IMHT                 <- 5
LGHT                 <- 1
DIMX                 <- 18
DIMY                 <- TSHT * tsct + IMHT * imct + LGHT
DIMSC                <- 100
IMX                  <- DIMX * DIMSC
IMY                  <- DIMY * DIMSC
LNSZ                 <- DIMSC/50
TEXTHT               <- DIMSC/10
LIMTP                <- 0.4
cy                   <- 1

png(filename=outfig,width=IMX,height=IMY)
pushViewport(viewport(layout = grid.layout(DIMY, DIMX)))

dummy                <- suppressMessages(melt(data.frame(1)))





###################################################################
# 2. Iterate over 1D time series.
###################################################################
for (ts in tslist) {
   ################################################################
   # Parse
   ################################################################
   ts                <- unlist(strsplit(ts,':'))
   ts_name           <- ts[1]
   ts_path           <- ts[2]
   ts_lim            <- as.numeric(ts[3])
   ################################################################
   # Load
   ################################################################
   ts                <- as.numeric(unlist(read.table(ts_path,header=F)))
   if (is.na(ts_lim)) { ts_lim <- max(ts) }
   dim(ts)           <- c(length(ts),1)
   ts                <- melt(ts)
   ################################################################
   # Label
   ################################################################
   molab <- ggplot(dummy) + 
            geom_rect(xmin=0,xmax=1,ymin=0,ymax=1,color='#EEEEEE',fill='#EEEEEE') + 
            geom_text(aes(x=0.5,y=0.5,label=ts_name),colour='black',size=TEXTHT) + 
            scale_x_continuous(expand=c(0,0)) + 
            scale_y_continuous(expand=c(0,0)) +
            theme(axis.text.x=element_blank(),
                axis.text.y=element_blank(),
                axis.ticks=element_blank(),
                axis.title.x=element_blank(),
                axis.title.y=element_blank(),
                legend.position="none",
                panel.background=element_blank(),panel.border=element_blank(),panel.grid.major=element_blank(),
                panel.grid.minor=element_blank(),plot.background=element_blank())
   ################################################################
   # Plot
   ################################################################
   moplt <- ggplot(ts) + 
            geom_rect(aes(xmin=Var1-0.5,xmax=Var1+0.5,ymin=min(ts$value,ts_lim),ymax=max(ts$value,ts_lim),fill=value)) + 
            annotate('rect',xmin=min(ts$Var1)-0.5,xmax=max(ts$Var1)+0.5,ymin=ts_lim,ymax=max(ts$value,ts_lim),alpha=LIMTP,fill='black') +
            geom_line(aes(x=Var1,y=value),colour='red',size=LNSZ) +
            scale_x_continuous(expand=c(0,0)) + 
            scale_y_continuous(expand=c(0,0)) +
            theme(axis.text.x=element_blank(),
                axis.text.y=element_blank(),
                axis.ticks=element_blank(),
                axis.title.x=element_blank(),
                axis.title.y=element_blank(),
                legend.position="none",
                panel.background=element_blank(),panel.border=element_blank(),panel.grid.major=element_blank(),
                panel.grid.minor=element_blank(),plot.background=element_blank())
   ################################################################
   # Print
   ################################################################
   fy                <- cy + TSHT - 1
   print(molab, vp = viewport(layout.pos.row = cy:fy, layout.pos.col = 1))
   print(moplt, vp = viewport(layout.pos.row = cy:fy, layout.pos.col = 2:DIMX))
   cy                <- cy + TSHT
}





###################################################################
# 3. Prepare the regional mask.
###################################################################
mask                 <- readNifti(maskpath)
logmask              <- (mask != 0)
voxrank              <- order(mask[logmask])
nclass               <- length(unique(mask[logmask]))
classes              <- unique(mask[logmask])
for (c in 1:length(classes)) { if (! is.integer(classes[c])) {break} }
if (c != nclass) {
   class             <- sort(floor(mask[logmask]/100))
   nclass            <- length(unique(class))
} else {
   class             <- sort(mask[logmask])
}
dim(class)           <- c(1,length(class))
class                <- melt(class)
classes              <- sort(unique(class$value))





###################################################################
# 4. Iterate over images.
###################################################################
for (im in imlist) {
   ################################################################
   # Load
   ################################################################
   img               <- readNifti(im)
   hdr               <- dumpNifti(im)
   ################################################################
   # Mask
   ################################################################
   img               <- img[logmask]
   dim(img)          <- c(sum(logmask),hdr$dim[5])
   img               <- scale(t(img))
   img               <- img[,voxrank]
   img               <- melt(img)
   ################################################################
   # Label
   ################################################################
   imlab <- ggplot(class,aes(Var1,Var2)) + 
            geom_raster(aes(fill=value)) + 
            scale_x_continuous(expand=c(0,0)) + 
            scale_y_continuous(expand=c(0,0)) +
            theme(axis.text.x=element_blank(),
                   axis.text.y=element_blank(),
                   axis.ticks=element_blank(),
                   axis.title.x=element_blank(),
                   axis.title.y=element_blank(),
                   legend.position="none",
                   panel.background=element_blank(),panel.border=element_blank(),panel.grid.major=element_blank(),
                   panel.grid.minor=element_blank(),plot.background=element_blank())
   ################################################################
   # Plot
   ################################################################
   implt <- ggplot(img,aes(Var1,Var2)) + 
            geom_raster(aes(fill=value)) + 
            scale_x_continuous(expand=c(0,0)) + 
            scale_y_continuous(expand=c(0,0)) +
            theme(axis.text.x=element_blank(),
                   axis.text.y=element_blank(),
                   axis.ticks=element_blank(),
                   axis.title.x=element_blank(),
                   axis.title.y=element_blank(),
                   legend.position="none",
                   panel.background=element_blank(),panel.border=element_blank(),panel.grid.major=element_blank(),
                   panel.grid.minor=element_blank(),plot.background=element_blank())
   ################################################################
   # Print
   ################################################################
   fy                <- cy + IMHT - 1
   print(imlab, vp = viewport(layout.pos.row = cy:fy, layout.pos.col = 1))
   print(implt, vp = viewport(layout.pos.row = cy:fy, layout.pos.col = 2:DIMX))
   cy                <- cy + IMHT
}





###################################################################
# 5. Produce ROI legend
###################################################################
dim(classes)         <- c(length(classes),1)
classes              <- melt(classes)
if (!is.na(names)) {
   roilabs           <- as.vector(unlist(read.table(names,header=F)))
} else {
   roilabs           <- rep(NA,nclass)
}
lgnd  <- ggplot(classes,aes(Var1,Var2)) + 
         geom_raster(aes(fill=value)) + 
         annotate("text", x = 1:nclass, y = 1, label = roilabs, colour = "white", size = TEXTHT) +
         scale_x_continuous(expand=c(0,0)) + 
         scale_y_continuous(expand=c(0,0)) +
         theme(axis.text.x=element_blank(),
                axis.text.y=element_blank(),
                axis.ticks=element_blank(),
                axis.title.x=element_blank(),
                axis.title.y=element_blank(),
                legend.position="none",
                panel.background=element_blank(),panel.border=element_blank(),panel.grid.major=element_blank(),
                panel.grid.minor=element_blank(),plot.background=element_blank())
fy                   <- cy + LGHT - 1
suppressWarnings(print(lgnd, vp = viewport(layout.pos.row = cy:fy, layout.pos.col = 2:DIMX)))
dummy                <- dev.off()
