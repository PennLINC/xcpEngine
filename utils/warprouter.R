#!/usr/bin/env Rscript

################################################################### 
#  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  #
###################################################################

###################################################################
# Compute the shortest route between two nodes in an unweighted
# network
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
   make_option(c("-n", "--nodes"), action="store", default=NA, type='character',
              help="A comma-separated list of node names."),
   make_option(c("-e", "--edges"), action="store", default=NA, type='character',
              help="A comma-separated list of edge names. Separate layers
                     with the hash delimiter (#)"),
   make_option(c("-s", "--source"), action="store", default=NA, type='character',
              help="The name of the node of origin."),
   make_option(c("-t", "--target"), action="store", default=NA, type='character',
              help="The name of the target node.")
)
opt = parse_args(OptionParser(option_list=option_list))

if (is.na(opt$nodes)) {
   cat('User did not specify any nodes.\n')
   cat('Use pathfinder.R -h for an expanded usage menu.\n')
   quit()
}
if (is.na(opt$edges)) {
   cat('User did not specify any edges.\n')
   cat('Use pathfinder.R -h for an expanded usage menu.\n')
   quit()
}

###################################################################
# Parse the input arguments.
###################################################################
n <- unlist(strsplit(opt$nodes,','))
e <- unlist(strsplit(opt$edges,','))
s <- which(n %in% opt$source)
t <- which(n %in% opt$target)

###################################################################
# Build a matrix of available paths.
###################################################################
adjacency <- matrix(0,nrow=length(n),ncol=length(n))
for (q in e) {
   q <- unlist(strsplit(q,':'))
   adjacency[which(n %in% q[1]),which(n %in% q[2])] <- 1
}
distance <- 1/adjacency

###################################################################
# Compute the shortest path.
###################################################################
c              <-    s
visited        <-    matrix(0,   nrow=length(n), ncol=1)
dist           <-    matrix(Inf, nrow=length(n), ncol=1)
prev           <-    matrix(NaN, nrow=length(n), ncol=1)
dist[c]        <-    0
while (TRUE) {
   nhood       <-    which(distance[c,] != Inf)
   odist       <-    dist[c] + distance[c,]
   kdist       <-    dist
   for (v in nhood) {
      if (odist[v] < kdist[v]) {
         dist[v] <-  odist[v]
         prev[v] <-  c
      }
   }
   visited[c]  <-    1
   if (visited[t] == 1){
      break
   } else if (min(dist[!visited]) == Inf) {
      cat('[No valid route ',n[s],':',n[t],']\n', sep='', file=stderr())
      q()
   }
   c           <- which(dist[!visited] == min(dist[!visited]))[1]
   realign     <- seq(length(visited)) - cumsum(visited)
   c           <- which(realign==c)[1]
}
reconstruct    <- c(prev[t],t)
r              <- t
while (prev[r] != s) {
   r           <- reconstruct[1]
   reconstruct <- c(prev[r],reconstruct)
}

cat(1,'\n')
for (i in 1:(length(reconstruct)-1)){
   cat(n[reconstruct[i]],':',n[reconstruct[i+1]],'\n',sep='')
}
