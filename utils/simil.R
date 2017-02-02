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
suppressMessages(require(optparse))
suppressMessages(require(pracma))

###################################################################
# Parse arguments to script, and ensure that the required arguments
# have been passed.
###################################################################
option_list = list(
   make_option(c("-i", "--inmat"), action="store", default=NA, type='character',
              help="A comma-separated list of matrices to compare."),
   make_option(c("-f", "--outfig"), action="store", default='similPlot.svg', type='character',
              help="The path where the correlation plot between the most
                     correlated variables should be saved. This output will
                     only be produced if ggplot2 is installed."),
   make_option(c("-l", "--axisnames"), action="store", default='abscissa,ordinate', type='character',
              help="The labels of the abscissa and ordinate to be displayed
                     on the plot, input as a comma-separated pair.")
)
opt = parse_args(OptionParser(option_list=option_list))

if (is.na(opt$inmat)) {
   cat('User did not specify an input matrix.\n')
   cat('Use simil.R -h for an expanded usage menu.\n')
   quit()
}
inmat <- opt$inmat
outfig <- opt$outfig
axisnames <- opt$axisnames

###################################################################
# 1. Verify that all inputs exist.
###################################################################
inmat <- strsplit(inmat,',')
existChk <- lapply(inmat, file.exists)
if (sum(unlist(existChk))!=length(unlist(inmat))){
   cat('ERROR: Not all input arguments exist.\n')
   quit(save='no')
}

###################################################################
# 2. Read in all inputs
###################################################################
mats <- sapply(unlist(inmat),read.table)
nnodes <- dim(mats)[1]
numft <- dim(mats)[1] * (dim(mats)[1]-1) / 2
ftvecs <- zeros(numft,dim(mats)[2])
for (i in 1:dim(mats)[2]){
   matTmp <- Reshape(as.matrix(unlist(mats[,i])),nnodes,)
   ftvecs[,i] <- squareform(matTmp - diag(diag(matTmp)))
}

###################################################################
# 3. Compute featurewise similarity.
###################################################################
similmat <- cor(ftvecs)

###################################################################
# 4. Print the similarity matrix
###################################################################
for (row in seq(1,dim(similmat)[1])) {
   cat(similmat[row,])
   cat('\n')
}

###################################################################
# 5. Plot the featurewise similarity.
#    (Requires ggplot2)
###################################################################
if ("ggplot2" %in% rownames(installed.packages())){
   ftvecs <- data.frame(ftvecs)
   pkcoor <- abs(triu(similmat,1))
   pkcoor <- which(pkcoor==max(pkcoor),arr.ind=TRUE)
   pkr <- similmat[pkcoor]
   axlabs <- unlist(strsplit(axisnames,','))
   names(ftvecs)[pkcoor[1]] <- 'mat1'
   names(ftvecs)[pkcoor[2]] <- 'mat2'

   suppressMessages(require(ggplot2))
   i <- ggplot(ftvecs, aes(x=mat1,y=mat2)) + 
      geom_hline(aes(x=mat1,y=mat2),yintercept=0,size=2) + 
      geom_vline(aes(x=mat1,y=mat2),xintercept=0,size=2) + 
      geom_polygon(aes(x=mat1,y=mat2,fill= ..level..,alpha=0.05),stat='density2d') + 
      geom_smooth(method='lm',color='red',size=2) + 
      annotate('text',label = paste('r =',round(pkr,3)), x=Inf, y=-Inf,hjust=1.1,vjust=-1.1) + 
      theme_classic() + 
      theme(legend.position="none", 
         panel.border = element_rect(colour = "black", fill=NA, size=2),
         axis.line = element_line(color = 'black', size = 2)) + 
      labs(x = axlabs[1], y = axlabs[2]) + 
      coord_cartesian(xlim=c(quantile(ftvecs$mat1,.001), 
         quantile(ftvecs$mat1,.999)), 
         ylim=c(quantile(ftvecs$mat2,.001), 
         quantile(ftvecs$mat2,.999))) +
#      coord_cartesian(xlim=c(quantile(ftvecs$mat1,.001), 
#         quantile(ftvecs$mat1,.999)), 
#         ylim=c(-0.25, 
#         0.40)) +
      scale_x_continuous(breaks=round(seq(quantile(ftvecs$mat1,.001),quantile(ftvecs$mat1,.999),quantile(ftvecs$mat1,.999) - quantile(ftvecs$mat1,.001)),2)) +
      scale_y_continuous(breaks=round(seq(quantile(ftvecs$mat2,.001),quantile(ftvecs$mat2,.999),quantile(ftvecs$mat2,.999) - quantile(ftvecs$mat2,.001)),2))
   ggsave(file=outfig, plot=i, width=8, height=8)
}
