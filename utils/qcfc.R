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
suppressMessages(suppressWarnings(library(methods)))

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
   make_option(c("-n", "--confound"), action="store", default=NA, type='character',
              help="Path to a file containing subject identifiers as well
                  as variables that should be controlled for in the model.
                  Subject identifiers should be marked with column headers
                  id0,id1,... matched to the cohort. Must also supply
                  -y / --conformula flag."),
   make_option(c("-y", "--conformula"), action="store", default=NA, type='character',
              help="Right-hand side of the formula expressing variables
                  from the confound matrix that should be controlled for
                  in the model. Categorical variables should be specified
                  using 'factor(var_name)'. For example,
                  
                     -y 'age+factor(sex)+factor(diagnosis)'
                     
                  This argument uses standard R formula syntax."),
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
   conformula           <- opt$conformula
   if (is.na(conformula)) {
      write(paste('[Warning: A confound matrix was provided, but the   ]','\n',
          '[         model formula was not specified. Variables]','\n',
          '[         from the confound matrix will not be      ]','\n',
          '[         controlled for in the model.              ]','\n',
          sep=''),stderr())
      confound          <- NA
   }
} else { confound       <- NA }

if (! "ggplot2"   %in% rownames(installed.packages())){
   outfig               <- NA
}
if (! "reshape2"  %in% rownames(installed.packages())){
   outfig               <- NA
}
if (! "svglite"  %in% rownames(installed.packages())){
   outfig               <- NA
}





PLOTXMIN                <- -0.30
PLOTXMAX                <- 0.45





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
residuals               <- FALSE
if (any(!is.na(confound)) && !is.na(conformula)) {
   cohort               <- merge(x=cohort,y=confound,all.x=TRUE)
   parform              <- as.formula(paste('motion ~',conformula))
   cohort$motion        <- lm(parform, data=cohort)$residuals
   residuals            <- TRUE
}
cohort$moperm           <- randperm(cohort$motion)





###################################################################
# Fit the edgewise model.
###################################################################
rvecperm                <- vector(length=nEdges)
rvec                    <- vector(length=nEdges)
pvec                    <- vector(length=nEdges)
for (i in 1:nEdges) {
   edge                 <- names(edges)[i]
   if (residuals) {
      parform           <- as.formula(paste(edge,'~',conformula))
      cohort[edge]      <- lm(parform, data=cohort)$residuals
   }
   c                    <- cor.test(cohort$motion, unlist(unname(cohort[edge])))
   cperm                <- cor.test(cohort$moperm, unlist(unname(cohort[edge])))
   rvecperm[i]          <- cperm$estimate
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
   suppressMessages(suppressWarnings(library(reshape2)))
   suppressMessages(suppressWarnings(library(svglite)))
#   distribs             <- data.frame(Empirical=rvec,Permuted=rvecperm)
#   names(distribs)[1]   <- 'Empirical'
#   names(distribs)[2]   <- 'Permuted'
#   distribs             <- melt(distribs)
   distribs             <- melt(rvec)
#   distribs$col[which(distribs$variable=='Empirical')] <- '#42B6F4'
#   distribs$col[which(distribs$variable=='Permuted')]  <- '#CCCCCC'
   
   labels               <- data.frame(
      xcoor             =  c(PLOTXMIN,PLOTXMAX),
      ycoor             =  c(0,0),
      lab               =  c('-0.30','0.45'),
      hj                =  c(-0.25,1.25),
      variable          =  c('dummy','dummy')
   )
   
   i <-  ggplot(data=distribs, aes(value, fill=variable)) + 
         geom_density(fill='#42B6F4', colour='#42B6F4') + 
         geom_vline(xintercept=0,size=2) + 
         scale_x_continuous(expand=c(0,0)) + 
         scale_y_continuous(expand=c(0,0)) + 
         coord_cartesian(xlim=c(PLOTXMIN,PLOTXMAX)) +
         geom_text(data=labels,aes(x=xcoor,y=ycoor,hjust=hj,label=lab),vjust=-1,color='black',size=5) +
         theme(axis.ticks=element_blank(),
               axis.title.x=element_blank(),
               axis.title.y=element_blank(),
               axis.text.x=element_blank(),
               axis.text.y=element_blank(),
               legend.position="none",
               panel.border=element_rect(colour='black', fill=NA),
               panel.background=element_blank(),panel.grid.major=element_blank(),
               panel.grid.minor=element_blank(),plot.background=element_blank())
   ggsave(file=outfig, plot=i, width=4, height=4)
}
