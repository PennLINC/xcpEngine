#! /usr/bin/env Rscript

###################################################################
#  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  #
###################################################################

###################################################################
# adjmat2pajek inputs an adjacency matrix and outputs Pajek format
###################################################################
suppressMessages(require(optparse))
suppressMessages(require(pracma))

###################################################################
# Parse arguments to script, and ensure that the required arguments
# have been passed.
###################################################################
option_list = list(
   make_option(c("-a", "--adjmat"), action="store", default=NA, type='character',
              help="Path to the adjacency matrix from which the Pajek-formatted 
                  output will be constructed."),
   make_option(c("-t", "--threshold"), action="store", default='0', type='character',
              help="The minimum weight that an edge in the network must possess
                  in order to survive thresholding. Any edges weaker than the
                  specified value will be set to zero. A higher value will
                  result in a sparser graph. Use a numeric value followed by
                  the percent symbol (%) to specify a percentile instead of a
                  numeric value.")
)
opt = parse_args(OptionParser(option_list=option_list))

if (is.na(opt$adjmat)) {
   cat('User did not specify an input adjacency matrix.\n')
   cat('Use adjmat2pajek.R -h for an expanded usage menu.\n')
   quit()
}
amatPath <- opt$adjmat
thr <- opt$threshold

###################################################################
# 1. Read in the adjacency matrix
###################################################################
adjmat <- as.matrix(read.table(amatPath,header=F))
if (dim(adjmat)[1] == 1 || dim(adjmat)[2] == 1) {
   adjmat <- squareform(as.vector(adjmat))
}

###################################################################
# 2. Determine whether the threshold is a numeric value or a
#    percentage. If it is a percentage, then compute the numeric
#    value corresponding to that percentage.
###################################################################
sink(file="/dev/null")
if (strcmp(thr,'N')){
   thr <- -Inf
} else if (is.na(as.numeric(thr))) {
   thr <- as.numeric(gsub('.{1}$', '', thr))
   thr <- thr * .01
   adjvec <- adjmat
   dim(adjvec) <- NULL
   adjvec <- unlist(adjvec)
   cat(adjvec)
   thr <- quantile(adjvec,thr)
} else {
   thr <- as.numeric(thr)
}

###################################################################
# 3. Determine the total number of edges in the adjacency matrix.
###################################################################
num_edges <- ((dim(adjmat)[1] * (dim(adjmat)[1] - dim(adjmat[1])))/2)[2]
sink(file=NULL)

###################################################################
# 4. Write out the edge weight information in Pajek format.
###################################################################
cat('*Vertices',dim(adjmat)[1],'\n')
cat('*Edges',toString(num_edges),'\n')
for (i in 1:(dim(adjmat)[1] - 1)) {
   begin <- i + 1
   for (j in begin:dim(adjmat)[2]) {
      if ( i == j) {
         next
      }
      wt <- as.numeric(adjmat[i,j])
      if (is.na(wt)) {
         next
      } else if ( wt > thr ){
         cat(toString(i),toString(j),toString(wt),'\n')
      } else {
         next
      }
   }
}
