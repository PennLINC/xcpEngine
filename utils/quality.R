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
   make_option(c("-o", "--ofunc"), action="store", default='ngsign', type='character',
              help="Type of objective function for modularity. Don't use
                     this option as of now."),
   make_option(c("-g", "--gamma"), action="store", default=1, type='numeric',
              help="Value of the resolution parameter.")
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

matpath <- opt$mat
compath <- opt$com
ofunc <- opt$ofunc
gamma <- opt$gamma

###################################################################
# 1. Load in the adjacency matrix.
###################################################################
adjmat <- as.matrix(read.table(matpath,header=F))
if (dim(adjmat)[1] == 1 || dim(adjmat)[2] == 1) {
   adjmat <- squareform(as.vector(adjmat))
}
#adjmat <- adjmat - diag(diag(adjmat))
Apos <- adjmat
Aneg <- -1 * adjmat
Apos[which(adjmat<0)] = 0
Aneg[which(adjmat>0)] = 0

###################################################################
# 2. Load in the community affiliation vector
###################################################################
S <- as.vector(unlist(read.csv(compath,header=F)))

###################################################################
# Prepare a preliminary matrix of predicted edge weights P
# predicted under an appropriate null model.
###################################################################
if (length(gamma) == 1){
   gpos = gamma[1]
   gneg = gamma[1]
} else if (length(gamma) == 2) {
   gpos = gamma(1)
   gneg = gamma(2)
} else {
   Q=NaN;
   return
}
kpos = apply(Apos,1,sum)
kneg = apply(Aneg,1,sum)
twompos = sum(kpos);
twomneg = sum(kneg);
P = gpos*(kpos %*% t(kpos))/twompos-gneg*(kneg %*% t(kneg))/twomneg;
A = adjmat# Apos + Aneg

###################################################################
# Compute the modularity quality Q.
###################################################################
B = A - P;
delta <- zeros(dim(P)[1])
for (i in 1:dim(P)[1]) {
   for (j in 1:dim(P)[1]) {
      if (S[i] == S[j]) {
         delta[i,j] = 1
      }
   }
}
degnorm = twompos + abs(twomneg)
Q = sum(B*delta) / degnorm
cat(Q)
