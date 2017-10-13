#!/usr/bin/env Rscript

###################################################################
#  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  #
###################################################################

###################################################################
# This script outputs information pertaining to the edgewise
# relationship between connectivity and subject motion.
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

###################################################################
# Parse arguments to script, and ensure that the required arguments
# have been passed.
###################################################################
option_list = list(
   make_option(c("-c", "--cohort"), action="store", default=NA, type='character',
              help="Path to the file containing subject identifiers as well
                  as paths to the connectivity matrix and a scalar-valued
                  motion metric. Subject identifiers should be marked
                  with column headers id0,id1,... matched to any confound
                  matrix"),
   make_option(c("-s", "--significance"), action="store", default='fdr', type='character',
              help="Mode of establishing significance (multiple-comparisons
                  correction: either fdr [default], bonferroni, or none)."),
   make_option(c("-t", "--threshold"), action="store", default=0.05, type='numeric',
              help="Threshold for establishing significance [default 0.05]."),
   make_option(c("-n", "--name"), action="store", default=NA, type='character',
              help="The name of the network or parcellation for which this
                  computation is being run."),
   make_option(c("-n", "--confound"), action="store", default=NA, type='character',
              help="Path to a file containing subject identifiers as well
                  as variables that should be controlled for in the model.
                  Subject identifiers should be marked with column headers
                  id0,id1,... matched to the cohort."),
   make_option(c("-o", "--out"), action="store", default=NA, type='character',
              help="The base output path."),
   make_option(c("-r", "--threshmat"), action="store", default=TRUE, type='logical',
              help="Logical indicating whether a thresholded version of the
                  QC-FC matrix should be saved to disc [default TRUE]."),
   make_option(c("-q", "--quality"), action="store", default=TRUE, type='logical',
              help="Logical indicating whether overall quality indices
                  (number of significant relationships, median absolute
                  correlation) should be saved to disc [default TRUE]."),
   make_option(c("-f", "--outfig"), action="store", default=TRUE, type='logical',
              help="Logical indicating whether plots should be produced
                  (requires ggplot2 and reshape2) [default true].")
)
opt = parse_args(OptionParser(option_list=option_list))

if (is.na(opt$cohort)) {
   cat('User did not specify an appropriate input.\n')
   cat('Use qcfc.R -h for an expanded usage menu.\n')
   quit()
}
if (is.na(opt$out)) {
   cat('User did not specify an appropriate output.\n')
   cat('Use qcfc.R -h for an expanded usage menu.\n')
   quit()
}

cohort                  <- read.csv(opt$cohort,header=TRUE,stringsAsFactors=FALSE)
sig                     <- opt$significance
thr                     <- opt$threshold
name                    <- opt$name
out                     <- paste(opt$out,'.txt',sep='')
if (opt$threshmat) {
   out_thr              <- paste(opt$out,'_thr.txt',sep='')
}
if (opt$quality) {
   out_pse              <- paste(opt$out,'_pctSigEdges.txt',sep='')
   out_nse              <- paste(opt$out,'_nSigEdges.txt',sep='')
   out_amc              <- paste(opt$out,'_absMedCor.txt',sep='')
}
if (opt$outfig) {
   outfig               <- paste(opt$out,'.svg',sep='')
}
if (!is.na(opt$confound)) {
   confound             <- read.csv(opt$confound,header=TRUE)
} else { confound       <- NA }





###################################################################
# Determine the number of subjects, number of identifiers, and
# number of edges
###################################################################
idVars                  <- names(cohort)[grep('motion|connectivity',names(cohort),invert=TRUE)]
nSubj                   <- dim(cohort)[1]
net                     <- as.matrix(read.table(cohort$connectivity[1],
                                                header=FALSE,
                                                stringsAsFactors=FALSE))
if (dim(net)[1] != 1 && dim(net)[2] != 1) {
   net                  <- squareform(net - diag(diag(net)))
}
nEdges                  <- length(net)





###################################################################
# Iterate across all subjects and assemble a matrix of adjacency
# matrices.
###################################################################
edges                   <- matrix(0,nrow=nSubj,ncol=nEdges)
for (i in 1:dim(cohort)[1]) {
   if (file.exists(cohort$connectivity[i])){
      net               <- as.matrix(read.table(cohort$connectivity[i],
                                                header=FALSE,
                                                stringsAsFactors=FALSE))
      if (dim(net)[1] != 1 && dim(net)[2] != 1) {
         net            <- squareform(net - diag(diag(net)))
      }
      if (length(net) == nEdges) {
         edges[i,]      <- net
      } else {
         cat('[Missing or extra edges in:',cohort$connectivity[i],']\n')
         quit()
      }
   } else {
      cat('[File not found:',cohort$connectivity[i],']\n')
      quit()
   }
}
edges                   <- data.frame(edges)
for (i in 1:dim(edges)[2]) {
   names(edges)[i]      <- paste('qcfcEdgeFeature',i,sep='')
}
cohort                  <- cbind(cohort,edges)





###################################################################
# Read in confounds, if they exist, and merge the confound matrix
# with the motion vector.
###################################################################
lmform                  <- ' ~ motion'
residuals               <- FALSE
if (any(!is.na(confound)) && !is.na(conformula)) {
   cohort               <- merge(x=cohort,y=confound,all.x=TRUE)
   parform              <- as.formula(paste('motion ~',conformula))
   cohort$motion        <- lm(parform, data=cohort)$residuals
   residuals            <- TRUE
}





###################################################################
# Fit the edgewise model.
###################################################################
rvec                    <- vector(length=nEdges)
pvec                    <- vector(length=nEdges)
for (i in 1:nEdges) {
   edge                 <- names(edges)[i]
   if (residuals) {
      parform           <- as.formula(paste(edge,'~',conformula))
      cohort[edge]      <- lm(parform, data=cohort)$residuals
   }
   c                    <- cor.test(cohort$motion, unlist(unname(cohort[edge])))
   rvec[i]              <- c$estimate
   pvec[i]              <- c$p.value
}





###################################################################
# Obtain the absolute median correlation with motion.
###################################################################
absMedCorr              <- median(abs(rvec))

###################################################################
# Obtain the number of significant connections, and compute the
# remaining outputs.
###################################################################
pvecAdj                 <- p.adjust(pvec,method=sig)
pvecThr                 <- (pvecAdj < thr)
rvecThr                 <- rvec
rvecThr[!pvecThr]       <- 0
nSigEdges               <- sum(pvecThr)
pctSigEdges             <- nSigEdges/nEdges*100





###################################################################
# Write the outputs.
###################################################################
write.table(rvec,file=out,sep='\t',col.names=FALSE,row.names=FALSE)
if (opt$threshmat) {
   write.table(rvecThr,file=out_thr,sep='\t',col.names=FALSE,row.names=FALSE)
}
if (opt$quality) {
   sink(out_amc)
   cat(absMedCorr)
   sink(out_nse)
   cat(nSigEdges)
   sink(out_pse)
   cat(pctSigEdges)
   sink(NULL)
}





###################################################################
# Plot the empirical and null distributions.
# Plot the community statistics.
# (Requires ggplot2)
###################################################################
if (opt$outfig) {
   suppressMessages(suppressWarnings(library(ggplot2)))
   distribs             <- data.frame(cbind(rvec,rvecperm))
   names(distribs)[1]   <- 'Empirical'
   names(distribs)[2]   <- 'Permuted'
   distribs             <- stack(distribs)
   names(distribs)[2]   <- 'Distribution'
   
   labels               <- data.frame(
      xcoor             =  c(-0.3,0.45),
      ycoor             =  c(0,0),
      lab               =  c('-0.3','0.45'),
      hj                =  c(-0.25,1.25),
      variable          =  c('dummy','dummy')
   )
   
   opath                <- paste(outfig,'DistPlot.svg',sep='')
   i <-  ggplot(data=distribs, aes(value, fill=variable)) + 
         geom_density(colour='#42B6F4',fill='#42B6F4') + 
         geom_hline(yintercept=0,size=2) + 
         geom_vline(xintercept=0,size=2) + 
         scale_x_continuous(expand=c(0,0)) + 
         scale_y_continuous(expand=c(0,0)) + 
         coord_cartesian(xlim=c(-0.3,0.45)) +
         geom_text(data=labels,aes(x=xcoor,y=ycoor,hjust=hj,label=lab),vjust=-1,color='black',size=5) +
         theme(axis.ticks=element_blank(),
               axis.title.x=element_blank(),
               axis.title.y=element_blank(),
               axis.text.x=element_blank(),
               axis.text.y=element_blank(),
               legend.position="none",
               panel.background=element_blank(),panel.grid.major=element_blank(),
               panel.grid.minor=element_blank(),plot.background=element_blank())
   ggsave(file=opath, plot=i, width=8, height=8)
}
