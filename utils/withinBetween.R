#!/usr/bin/env Rscript

################################################################### 
#  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  #
###################################################################

###################################################################
# Function for coverage computation and removal of values that
# fail some threshold
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
   make_option(c("-m", "--mat"), action="store", default=NA, type='character',
              help="Path to the adjacency matrix."),
   make_option(c("-c", "--com"), action="store", default=NA, type='character',
              help="Path to the community affiliation vector."),
   make_option(c("-o", "--out"), action="store", default=NA, type='character',
              help="Base path for outputs of the within-/between-system
                     connectivity computations.")
)
opt = parse_args(OptionParser(option_list=option_list))

if (is.na(opt$mat)) {
   cat('User did not specify an adjacency matrix.\n')
   cat('Use quality.R -h for an expanded usage menu.\n')
   quit()
}
if (is.na(opt$com)) {
   cat('User did not specify a community affiliation vector.\n')
   cat('Use quality.R -h for an expanded usage menu.\n')
   quit()
}
if (is.na(opt$out)) {
   opt$out <- getwd()
}

matpath <- opt$mat
compath <- opt$com
outbase <- opt$out

###################################################################
# 1. Load in the adjacency matrix and community partition.
###################################################################
adjmat <- as.matrix(read.table(matpath,header=F))
adjmat <- adjmat - diag(as.vector(repmat(NaN,1,dim(adjmat)[1])))
community <- as.vector(unlist(read.table(compath,header=F)))
comidx <- sort(unique(community))

###################################################################
# 2. Z-score using the Fisher transform.
###################################################################
zadjmat <- 0.5 * log((1 + adjmat)/(1 - adjmat))

###################################################################
# 3. Network-by-network within/between
###################################################################
wbmat <- zeros(length(comidx))
cur <- 1
for (c in comidx){
   tgt <- 1
   cidx <- which(community==c)
   for (r in comidx) {
      submat <- zadjmat[cidx,which(community==r)]
      wbmat[cur,tgt] <- mean(submat,na.rm=T)
      tgt <- tgt + 1
   }
   cur <- cur + 1
}
wbmat <- (exp(2 * wbmat) - 1)/(exp(2 * wbmat) + 1)
rownames(wbmat) <- comidx
colnames(wbmat) <- comidx

###################################################################
# 4. Network-wise within/between
###################################################################
wbvec <- matrix(nrow=length(comidx),ncol=2)
cur <- 1
for (c in comidx){
   cidx <- which(community==c)
   cnot <- which(community!=c)
   submat <- zadjmat[cidx,cidx]
   wbvec[cur,1] <- mean(submat,na.rm=T)
   submat <- zadjmat[cidx,cnot]
   wbvec[cur,2] <- mean(submat,na.rm=T)
   cur <- cur + 1
}
wbvec <- (exp(2 * wbvec) - 1)/(exp(2 * wbvec) + 1)
rownames(wbvec) <- comidx
colnames(wbvec) <- c('within','between')

###################################################################
# 5. Overall within/between
###################################################################
within <- zeros(dim(adjmat)[1])
wboverall <- vector(length=2)
for (c in comidx){
   cidx <- which(community==c)
   within[cidx,cidx] <- 1
}
wboverall[1] <- mean(zadjmat[as.logical(within)],na.rm=T)
wboverall[2] <- mean(zadjmat[!as.logical(within)],na.rm=T)
wboverall <- (exp(2 * wboverall) - 1)/(exp(2 * wboverall) + 1)

###################################################################
# 6. Specificity
###################################################################
ztadjmat <- zadjmat
ztadjmat[which(ztadjmat<=0)] <- 0
wbspec <- matrix(nrow=length(comidx),ncol=2)
cur <- 1
for (c in comidx){
   cidx <- which(community==c)
   cnot <- which(community!=c)
   submat <- ztadjmat[cidx,cidx]
   wbspec[cur,1] <- mean(submat,na.rm=T)
   submat <- ztadjmat[cidx,cnot]
   wbspec[cur,2] <- mean(submat,na.rm=T)
   cur <- cur + 1
}
wbspec <- (exp(2 * wbspec) - 1)/(exp(2 * wbspec) + 1)
wbvabs <- abs(wbspec)
wbspec <- (wbvabs[,1] - wbvabs[,2])/(wbvabs[,1] + wbvabs[,2])
wbspec <- cbind(comidx,wbspec)

wbtoverall <- vector(length=2)
wbtoverall[1] <- mean(ztadjmat[as.logical(within)],na.rm=T)
wbtoverall[2] <- mean(ztadjmat[!as.logical(within)],na.rm=T)
wbtoverall <- (exp(2 * wbtoverall) - 1)/(exp(2 * wbtoverall) + 1)
wboabs <- abs(wbtoverall)
wbspeco <- (wboabs[1] - wboabs[2])/(wboabs[1] + wboabs[2])

###################################################################
# 7. Write output
###################################################################
out <- paste(outbase,'wbNetByNet.csv',sep='_')
write.csv(wbmat,out)
out <- paste(outbase,'wbNetWB.csv',sep='_')
write.csv(wbvec,out)
out <- paste(outbase,'wbOverall.csv',sep='_')
write.table(wboverall,out,row.names=F,col.names=F,sep=',')
out <- paste(outbase,'specNet.csv',sep='_')
write.table(wbspec,out,row.names=F,col.names=F,sep=',')
out <- paste(outbase,'specOverall.txt',sep='_')
write.table(wbspeco,out,row.names=F,col.names=F)
