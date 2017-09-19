#!/usr/bin/env Rscript

###################################################################
#  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  #
###################################################################

###################################################################
# This script outputs information pertaining to the total number
# of edges whose connectivity is significantly related to motion.
#
# This script accepts a list of subjects that includes identifiers
# as well as paths to:
# (1) the connectivity matrix
# (2) a motion metric for the subject
# It also has the option of accepting an option for multiple-
# comparisons adjustment and confounds.
###################################################################

###################################################################
# Load required libraries
###################################################################
suppressMessages(suppressWarnings(library(optparse)))
suppressMessages(suppressWarnings(library(pracma)))
suppressMessages(suppressWarnings(library(ppcor)))

###################################################################
# Parse arguments to script, and ensure that the required arguments
# have been passed.
###################################################################
option_list = list(
   make_option(c("-c", "--cohort"), action="store", default=NA, type='character',
              help="Path to the file containing subject identifiers as well
                  as paths to the connectivity matrix and a scalar-valued
                  motion metric."),
   make_option(c("-s", "--significance"), action="store", default='fdr', type='character',
              help="Mode of establishing significance (multiple-comparisons
                  correction: either fdr [default], bonferroni, or none)."),
   make_option(c("-t", "--threshold"), action="store", default=0.05, type='numeric',
              help="Threshold for establishing significance [default 0.05]."),
   make_option(c("-n", "--name"), action="store", default=NA, type='character',
              help="The name of the network or parcellation for which this
                  computation is being run."),
   make_option(c("-a", "--confound"), action="store", default=NA, type='character',
              help="Path to a file containing subject identifiers as well
                  as variables that should be controlled for in the model."),
   make_option(c("-o", "--out"), action="store", default=NA, type='character',
              help="Base path where the matrix of edgewise correlations
                  should be written."),
   make_option(c("-r", "--threshmat"), action="store", default=NA, type='character',
              help="Base path where the thresholded matrix of edgewise
                  correlations should be written."),
   make_option(c("-q", "--quality"), action="store", default=NA, type='character',
              help="Base path where the overall quality of the pipeline
                  (number of significant edges) should be written."),
   make_option(c("-f", "--outfig"), action="store", default='mocor', type='character',
              help="The root path where the distribution plots for empirical
                  and permuted edge correlations and for connectivity indices
                  should be saved. This output will only be produced if 
                  ggplot2 is installed.")
)
opt = parse_args(OptionParser(option_list=option_list))

if (is.na(opt$cohort)) {
   cat('User did not specify an appropriate input.\n')
   cat('Use mocor.R -h for an expanded usage menu.\n')
   quit()
}
if (is.na(opt$quality)) {
   cat('User did not specify an appropriate output.\n')
   cat('Use mocor.R -h for an expanded usage menu.\n')
   quit()
}

cohort <- read.csv(opt$cohort,header=FALSE)
sig <- opt$significance
thr <- opt$threshold
name <- opt$name
out <- opt$out
out_thr <- opt$threshmat
out_q <- opt$quality
outfig <- opt$outfig
confound <- opt$confound
if (!is.na(confound)) {confound <- read.csv(opt$confound,header=FALSE)}

###################################################################
# Determine the columns in the cohort file that correspond to
# motion, specificity, and quality.
###################################################################
nSubj <- dim(cohort)[1]
exs <- cohort[1,]
moIdx <- which(exs %in% rev(exs)[3])
specIdx <- which(exs %in% rev(exs)[2])
qIdx <- which(exs %in% rev(exs)[1])

###################################################################
# Determine the column in the cohort file that corresponds to
# the adjacency matrix. Determine the number of edges.
###################################################################
matIdx <- which(apply(exs,1,file.exists))
net <- as.matrix(read.table(as.character(cohort[1,matIdx])))
net <- squareform(net - diag(diag(net)))
nEdges <- length(net)

###################################################################
# Iterate across all subjects and assemble a matrix of adjacency
# matrices.
###################################################################
metamat <- zeros(nSubj,nEdges)
for (i in 1:dim(cohort)[1]) {
   if (file.exists(as.character(cohort[i,matIdx]))){
      net <- as.matrix(read.table(as.character(cohort[i,matIdx])))
      net <- squareform(net - diag(diag(net)))
      metamat[i,] <- net
   }
}

###################################################################
# Read in confounds, if they exist, and merge the confound matrix
# with the motion vector.
###################################################################
ids <- cohort[1,c(-1*moIdx, -1*matIdx)]
numIds <- dim(ids)[2]
idIdxConf <- c()
if (any(!is.na(confound))) {
   for (j in 1:numIds) {
      idIdxConf <- c(idIdxConf,which(confound[1,] %in% ids[j]))
   }
}
confound_reduced <- confound[,-1*idIdxConf]
model <- cbind(cohort[,moIdx],confound_reduced)
permorder <- sample(1:length(cohort[,moIdx]))
permodel <- cbind(cohort[,moIdx],confound_reduced)[permorder,]

modelSpec <- cbind(cohort[,specIdx],model)
modelQ <- cbind(cohort[,qIdx],model)

###################################################################
# Fit the edgewise model.
###################################################################
rvec <- zeros(nEdges,1)
pvec <- zeros(nEdges,1)
rvecperm <-  zeros(nEdges,1)
for (i in 1:nEdges) {
   cmodel <- cbind(metamat[,i],model)
   cmodel <- cmodel[complete.cases(cmodel),]
   cout <- pcor(cmodel)
   rvec[i] <- cout$estimate[1,2]
   pvec[i] <- cout$p.value[1,2]
   
   cpermodel <- cbind(metamat[,i],permodel)
   cpermodel <- cpermodel[complete.cases(cpermodel),]
   cpermout <- pcor(cpermodel)
   rvecperm[i] <- cpermout$estimate[1,2]
}

###################################################################
# Fit the community models.
###################################################################
cmodel <- cmodel[complete.cases(modelSpec),]
cout <- pcor(cmodel)
rSpec <- cout$estimate[1,2]
pSpec <- cout$p.value[1,2]
cmodel <- cmodel[complete.cases(modelQ),]
cout <- pcor(cmodel)
rQ <- cout$estimate[1,2]
pQ <- cout$p.value[1,2]

###################################################################
# Obtain the absolute median correlation with motion.
###################################################################
absMedCorr <- median(abs(rvec))

###################################################################
# Obtain the number of significant connections, and compute the
# remaining outputs.
###################################################################
pvecAdj <- p.adjust(pvec,method=sig)
pvecThr <- (pvecAdj < thr)
rvecThr <- rvec
rvecThr[!pvecThr] <- 0
nSigEdges <- sum(pvecThr)
rMat <- squareform(as.vector(rvec))
rMatThr <- squareform(as.vector(rvecThr))
qual <- c()
qual$absMedCorr <- absMedCorr
qual$nSigEdges <- nSigEdges
qual$modQMean <- mean(cohort[,qIdx],na.rm=T)
qual$modQStd <- sd(cohort[,qIdx],na.rm=T)
qual$modQMotionCor <- rQ
qual$specMean <- mean(cohort[,specIdx],na.rm=T)
qual$specStd <- sd(cohort[,specIdx],na.rm=T)
qual$specMotionCor <- rSpec

###################################################################
# Plot the empirical and null distributions.
# Plot the community statistics.
# (Requires ggplot2)
###################################################################
if ("ggplot2" %in% rownames(installed.packages())){
   distribs <- data.frame(cbind(rvec,rvecperm))
   names(distribs)[1] <- 'Empirical'
   names(distribs)[2] <- 'Permuted'
   distribs <- stack(distribs)
   names(distribs)[2] <- 'Distribution'
   
   opath <- paste(outfig,'DistPlot.svg',sep='')
   suppressMessages(require(ggplot2))
   i <- ggplot(distribs, aes(values, fill=Distribution)) + 
      geom_hline(aes(x=mat1,y=mat2),yintercept=0,size=2) + 
      geom_vline(aes(x=mat1,y=mat2),xintercept=0,size=2) + 
      geom_density(alpha=0.2) + 
      theme_classic() + 
      theme(panel.border = element_rect(colour = "black", fill=NA, size=2),
         axis.line = element_line(color = 'black', size = 2)) + 
      labs(x = 'FC-motion correlation (r)', y = 'Density') + 
      scale_x_continuous(breaks=round(seq(quantile(distribs$values,.0001),quantile(distribs$values,.9999),quantile(distribs$values,.9999) - quantile(distribs$values,.0001)),2)) + 
      scale_y_continuous(breaks=NULL)
   d <- ggplot_build(i)
   ymax <- d$panel$ranges[[1]]$y.range[2]
   yrsc <- (ymax - (ymax / 1.1) ) / 2
   i <- i + coord_cartesian(ylim=c(yrsc,ymax - yrsc),xlim=c(-0.3,0.45))
   ggsave(file=opath, plot=i, width=8, height=8)
   
   opath <- paste(outfig,'ModQ.svg',sep='')
   i <- ggplot() + 
      geom_violin(data = data.frame(a = 1, b = as.vector(unlist(cohort[,qIdx]))),
         scale = 'area',
         draw_quantiles = 0.5,
         aes(x = a, y = b, fill = 1)) + 
      theme_classic() + 
      theme(panel.border = element_rect(colour = "black", fill=NA, size=2),
         axis.line = element_line(color = 'black', size = 2)) + 
      labs(x = '', y = 'Modularity quality (Q)') + 
      coord_cartesian(ylim = c(0,0.25), xlim = c(0.2,1.8))
   ggsave(file=opath, plot=i, width=3, height=15)
   
   opath <- paste(outfig,'conSpec.svg',sep='')
   i <- ggplot() + 
      geom_violin(data = data.frame(a = 1, b = as.vector(unlist(cohort[,specIdx]))),
         scale = 'area',
         draw_quantiles = 0.5,
         aes(x = a, y = b, fill = 1)) + 
      theme_classic() + 
      theme(panel.border = element_rect(colour = "black", fill=NA, size=2),
         axis.line = element_line(color = 'black', size = 2)) + 
      labs(x = '', y = 'Connection specificity') + 
      coord_cartesian(ylim = c(0,0.5), xlim = c(0.2,1.8))
   ggsave(file=opath, plot=i, width=3, height=15)
}

###################################################################
# Write the outputs.
###################################################################
write.table(rMat,file=out,sep='\t',col.names=FALSE,row.names=FALSE)
write.table(rMatThr,file=out_thr,sep='\t',col.names=FALSE,row.names=FALSE)
write.table(qual,file=out_q,sep='\t',row.names=FALSE)
