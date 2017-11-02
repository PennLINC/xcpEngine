#!/usr/bin/env Rscript

###################################################################
#  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  #
###################################################################

###################################################################
# This script reads in any number of matrices and computes a
# similarity metric between them
###################################################################

###################################################################
# Load required libraries
###################################################################
suppressMessages(suppressWarnings(library(optparse)))
suppressMessages(suppressWarnings(library(pracma)))
suppressMessages(suppressWarnings(library(methods)))

###################################################################
# Parse arguments to script, and ensure that the required arguments
# have been passed.
###################################################################
option_list = list(
   make_option(c("-i", "--inmat"), action="store", default=NA, type='character',
              help="A comma-separated list of feature vectors to compare."),
   make_option(c("-f", "--outfig"), action="store", default=NA, type='character',
              help="The path where the correlation plot between the most
                     correlated variables should be saved. This output will
                     only be produced if ggplot2 is installed.")
)
opt = parse_args(OptionParser(option_list=option_list))

if (is.na(opt$inmat)) {
   cat('User did not specify an input matrix.\n')
   cat('Use featureCorrelation.R -h for an expanded usage menu.\n')
   quit()
}
inmatpaths              <- opt$inmat
outfig                  <- opt$outfig

if (! "ggplot2"  %in% rownames(installed.packages())){
   outfig               <- NA
}
if (! "reshape2" %in% rownames(installed.packages())){
   outfig               <- NA
}
if (! "svglite"  %in% rownames(installed.packages())){
   outfig               <- NA
}

###################################################################
# 1. Verify that all inputs exist.
###################################################################
inmat                   <- strsplit(inmatpaths,',')
nMat                    <- length(inmat[[1]])
existChk                <- lapply(inmat, file.exists)
if (sum(unlist(existChk))!=length(unlist(inmat))){
   cat('ERROR: Not all input arguments exist.\n')
   quit(save='no')
}

###################################################################
# 2. Read in all inputs
###################################################################
mats                    <- list()
for (i in 1:nMat) {
   mats[[i]]            <- read.table(inmat[[1]][i],header=FALSE,stringsAsFactors=FALSE)
   if (dim(mats[[i]])[1] != 1 && dim(mats[[i]])[2] != 1) {
      mats[[i]]         <- squareform(mats[[i]] - diag(diag(mats[[i]])))
   }
}
nEdges                  <- dim(mats[[1]])[1]
ftvecs                  <- matrix(0,nEdges,length(mats))
for (i in 1:length(mats)){
   ftvecs[,i]           <- mats[[i]][,1]
}

###################################################################
# 3. Compute featurewise similarity.
###################################################################
similmat                <- cor(ftvecs,use="complete")
similmat                <- similmat - diag(diag(similmat))

###################################################################
# 4. Print the similarity matrix
###################################################################
similmat                <- squareform(similmat)
for (i in seq(1,length(similmat))) {
   cat(similmat[i])
   cat('\n')
}

###################################################################
# 5. Plot the featurewise similarity.
#    (Requires ggplot2)
###################################################################
if (!is.na(opt$outfig)) {
   suppressMessages(suppressWarnings(library(ggplot2)))
   suppressMessages(suppressWarnings(library(reshape2)))
   suppressMessages(suppressWarnings(library(svglite)))
   similmat             <- squareform(similmat)
   ftvecs               <- data.frame(ftvecs)
   ftvecs               <- ftvecs[complete.cases(ftvecs),]
   pkcoor               <- abs(similmat)
   pkcoor               <- which(pkcoor==max(pkcoor),arr.ind=TRUE)[1,]
   pkr                  <- similmat[pkcoor[1],pkcoor[2]]
   names(ftvecs)[pkcoor[2]] <- 'mat1'
   names(ftvecs)[pkcoor[1]] <- 'mat2'

   i <- ggplot(ftvecs, aes(x=mat1,y=mat2)) + 
      geom_hline(aes(x=mat1,y=mat2),yintercept=0,size=2) + 
      geom_vline(aes(x=mat1,y=mat2),xintercept=0,size=2) + 
      geom_polygon(aes(x=mat1,y=mat2,fill= ..level..,alpha=0.05),stat='density2d') + 
      geom_smooth(method='lm',color='red',size=2) + 
      annotate('text',label = paste('r =',round(pkr,3)), x=Inf, y=-Inf,hjust=1.1,vjust=-1.1,size=5) + 
      theme(axis.ticks=element_blank(),
            axis.title.x=element_blank(),
            axis.title.y=element_blank(),
            axis.text.x=element_blank(),
            axis.text.y=element_blank(),
            legend.position="none",
            panel.border=element_rect(colour='black', fill=NA),
            panel.background=element_blank(),panel.grid.major=element_blank(),
            panel.grid.minor=element_blank(),plot.background=element_blank()) +
            scale_x_continuous(expand=c(0,0)) + 
            scale_y_continuous(expand=c(0,0)) + 
      coord_cartesian(xlim=c(quantile(ftvecs$mat1,.001), 
            quantile(ftvecs$mat1,.999)), 
            ylim=c(quantile(ftvecs$mat2,.001), 
            quantile(ftvecs$mat2,.999)))
   ggsave(file=outfig, plot=i, width=4, height=4)
}
