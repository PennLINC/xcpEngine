#!/usr/bin/env Rscript

###################################################################
#  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  #
###################################################################

###################################################################
# Utility script to compute score from detre lab This utility uses
#
###################################################################

###################################################################
# Load required libraries
###################################################################
suppressMessages(suppressWarnings(library(optparse)))
suppressMessages(suppressWarnings(library(pracma)))
suppressMessages(suppressWarnings(library(RNifti)))
suppressMessages(suppressWarnings(library(MASS)))
###################################################################
# Parse arguments to script, and ensure that the required arguments
# have been passed.
###################################################################
option_list = list(
   make_option(c("-i", "--img"), action="store", default=NA, type='character',
              help="Path to the 4D ASL time series from which perfusion will be computed."),
   make_option(c("-y", "--grey"), action="store", default=NA, type='character',
              help="Grey matter."),
   make_option(c("-w", "--white"), action="store", default=NA, type='character',
              help="white matter"),
   make_option(c("-c", "--csf"), action="store", default=NA, type='character',
              help="cerebrospinal fluid"),
   make_option(c("-m", "--mask"), action="store", default=NA, type='character',
              help="brain mask"), 
   make_option(c("-f", "--wfun"), action="store", default='huber', type='character',
              help="the wave fun. see the code for other types"),
   make_option(c("-o", "--out"), action="store", default=NA, type='character',
              help="The root output path for all voxelwise perfusion maps."),
   make_option(c("-t", "--thresh"), action="store", default=0.9, type='numeric',
              help="threshold the segmentation tissues")
)
opt = parse_args(OptionParser(option_list=option_list))

if (is.na(opt$img)) {
   cat('User did not specify an input ASL time series.\n')
   cat('Use scrub_cbf.R -h for an expanded usage menu.\n')
   quit()
}

# get the input data

cbf_ts   <-         opt$img
wm       <-         opt$white
gm       <-         opt$grey
csf      <-         opt$csf
mask     <-         opt$mask
wfun     <-         opt$wfun
outpath  <-         opt$out
thresh   <-         opt$thresh




## set the default values

flagprior      <-      1
flagmodrobust  <-      1
flagstd        <-      1


  
#read the volume
#read the maps and cbf time series  
wm       <-         readNifti(wm)
gm       <-         readNifti(gm)
csf      <-         readNifti(csf)
cbfts    <-         readNifti(cbf_ts) 
mask     <-         readNifti(mask)

if ( length(dim(gm)) == 4 ) { gm=gm[,,,1]; wm=wm[,,,1]; csf=csf[,,,1] }
if ( length(dim(mask)) == 4 ) { mask=mask[,,,1] }

# threhdoling the prb. maps and obtain the idx
gm1 <- gm*mask; gmidx <- gm1[mask==1]; 
gmidx[gmidx<thresh] <- 0;   gmidx[gmidx>0] <- 1
wm1 <- wm*mask;  wmidx <- wm1[mask==1]; 
wmidx[wmidx<thresh] <- 0; wmidx[wmidx>0] <- 1
csf1<- csf*mask;  csfidx <- csf1[mask==1];
 csfidx[csfidx<thresh] <- 0; csfidx[csfidx>0] <- 1
midx <- mask[mask==1];

# get the the tune value. 
tune <- 1.345
if ( wfun == 'andrews') { tune <- 1.339 }
if (wfun == 'bisquare') { tune <- 4.685}
if (wfun == 'cauchy') { tune <- 2.385}
if (wfun == 'fair') { tune <- 1.4}
    #else if (wfun == 'huber') { tune <- 1.345}
if (wfun == 'logistic') { tune <- 1.205}
if (wfun == 'ols') {  tune <- 1}
if (wfun == 'talwar') {  tune <- 2.795 }
if (wfun == 'welsch') {  tune <- 2.985}


weightwfun=function(wfun,r) {
         if ( wfun == 'andrews') { w <- (abs(r)<pi )* sin(r) / r; return(w) }
            else if (wfun == 'bisquare') {w <- ( abs(r)<1) * (1 - r^2)^2; return(w)}
            else if (wfun == 'cauchy') {w <- 1 / (1 + r^2); return(w) }
            else if (wfun == 'fair') {w <- 1 / (1 + abs(r)); return(w)}
            #else if (wfun == 'huber') {w <- 1 /abs(r); return(w) }
            else if (wfun == 'logistic') { w <- tanh(r) / r; return(w) }
            else if (wfun == 'ols') { w <- rep(1,length(r)); return(w)}
            else if (wfun == 'talwar') { w <-  1 * (abs(r)<1); return(w) }
            else if (wfun == 'welsch') { w <- exp(-(r^2)); return(w)}
            else  { w <- 1 /abs(r); return(w) }
        }  

getchisquare=function(n) 
{
  a=c(0.000000, 15.484663, 8.886835, 7.224733, 5.901333, 5.126189, 4.683238, 4.272937, 4.079918, 
      3.731612, 3.515615, 3.459711, 3.280471, 3.078046, 3.037280, 2.990761, 2.837119, 2.795526, 2.785189, 
      2.649955, 2.637642, 2.532700, 2.505253, 2.469810, 2.496135, 2.342210, 2.384975, 2.275019, 2.244482, 
      2.249109, 2.271968, 2.210340, 2.179537, 2.133762, 2.174928, 2.150072, 2.142526, 2.071512, 2.091061, 
      2.039329, 2.053183, 2.066396, 1.998564, 1.993568, 1.991905, 1.981837, 1.950225, 1.938580, 1.937753, 
      1.882911, 1.892665, 1.960767, 1.915530, 1.847124, 1.947374, 1.872383, 1.852023, 1.861169, 1.843109, 
      1.823870, 1.809643, 1.815038, 1.848064, 1.791687, 1.768343, 1.778231, 1.779046, 1.759597, 1.774383, 
      1.774876, 1.751232, 1.755293, 1.757028, 1.751388, 1.739384, 1.716395, 1.730631, 1.718389, 1.693839, 
      1.696862, 1.691245, 1.682541, 1.702515, 1.700991, 1.674607, 1.669986, 1.688864, 1.653713, 1.641309, 
      1.648462, 1.630380, 1.634156, 1.660821, 1.625298, 1.643779, 1.631554, 1.643987, 1.624604, 1.606314, 
      1.609462);
  b=c(NaN, 2.177715, 1.446966, 1.272340, 1.190646, 1.151953, 1.122953, 1.103451, 1.089395, 1.079783, 
      1.071751, 1.063096, 1.058524, 1.054137, 1.049783, 1.046265, 1.043192, 1.039536, 1.038500, 1.037296, 
      1.033765, 1.032317, 1.031334, 1.029551, 1.028829, 1.027734, 1.024896, 1.024860, 1.025207, 1.024154, 
      1.022032, 1.021962, 1.021514, 1.020388, 1.019238, 1.020381, 1.019068, 1.018729, 1.018395, 1.017134, 
      1.016539, 1.015676, 1.015641, 1.015398, 1.015481, 1.015566, 1.014620, 1.014342, 1.013901, 1.013867, 
      1.013838, 1.013602, 1.013322, 1.012083, 1.013168, 1.012667, 1.011087, 1.011959, 1.011670, 1.011494, 
      1.010463, 1.010269, 1.010393, 1.010004, 1.010775, 1.009399, 1.011000, 1.010364, 1.009831, 1.009563, 
      1.010085, 1.009149, 1.008444, 1.009455, 1.009705, 1.008597, 1.008644, 1.008051, 1.008085, 1.008550, 
      1.008265, 1.009141, 1.008235, 1.008002, 1.008007, 1.007660, 1.007993, 1.007184, 1.008093, 1.007816, 
      1.007770, 1.007932, 1.007819, 1.007063, 1.006712, 1.006752, 1.006703, 1.006650, 1.006743, 1.007087);
  thresh1 <- a[n]; thresh2 <- 10*a[n]; meanmedianr <- b[n];
  list(thresh1 <- thresh1, thresh2 <- thresh2, meanmedianr <- meanmedianr)
  }



myrobustfit=function(Y,mu,Globalprior,lmd,localprior,wfun='huber',tune=1.345,flagstd,
                     flagmodrobust,modrobprior) {

        dimcbf  <-  dim(Y)
        priow   <-  ones(dimcbf[1],dimcbf[2]); sw=1;
  
        X       <-  ones(dimcbf[1],dimcbf[2])
        b       <-  (apply(X*Y,2,sum)+mu*Globalprior+lmd*localprior)/(apply(X*X,2,sum)+mu+lmd)
  
  
        b0       <-  rep(0,length(b))
        h1       <-  X/((repmat(sqrt(apply(X^2,2,sum)),dimcbf[1],1))^2)
        h0       <-  0.9999*ones(dimcbf[1],dimcbf[2])
        h        <-  pmin(h0,h1) 
        adjfactor <- 1/sqrt(1-h/priow)
  
  
        tiny_s    <-  (1e-6)*(apply(h,2,sd));tiny_s[tiny_s==0]=1
        D         <-  sqrt(eps((X)))
        iter <- 0; interlim <- 100
  
         while (iter<interlim) {
               #sprintf("iteration %i",iter)
               cat('iteration  ', iter,"\n")
               iter <- iter + 1
               if ( any(  abs(b-b0) < D*pmax( abs(b),abs(b0) ) ) ) { 
                   cat(' \n converged after ', iter,"iterations\n"); break  }
                r    <-    Y - X*(repmat(b,dimcbf[1],1)); 
                radj <-    r * adjfactor/sw
    
                 if ( flagstd == 1 ) 
                     { s <- sqrt(apply(radj^2,2,mean) ) 
                    } else { 
                       rs <- apply(abs(radj),2,sort); s <- apply(rs,2,median)/0.6745 }
    
              r1 <- radj*(1-flagmodrobust*exp(-repmat(modrobprior,dimcbf[1],1)))/repmat(pmax(s,tiny_s)*tune,dimcbf[1],1)
              w  <- weightwfun(wfun,r1)
              b0 <- b;
              z <- sqrt(w); x <- X*z; yz <- Y*z;
              b  <- (apply(x*yz,2,sum)+mu*Globalprior+lmd*localprior)/(apply(x*x,2,sum)+mu+lmd)
            }      
    return(b)
}

# Get the mean cbf
meancbf <- apply(cbfts,c(1,2,3),mean)

# get the cbf in matrix for robust fitting
cbfdim  <- dim(cbfts)
y <- matrix(0, nrow <- cbfdim[4],ncol<-sum(mask==1) )
ydim  <- dim(y)
   for (i in 1:cbfdim[4]) {tmp <- cbfts[,,,i]; y[i,] <- tmp[mask==1]}

#if (flagprior == 0) { mu=0; Globalprior = 0; modrobprior=0 
#}else {
  VV  <- apply(y,2,var); thres1 <- getchisquare (ydim[1])
  mu1 <-  VV/(median(VV[gmidx==1])*thres1[[3]]);
  mu  <- ((mu1>thres1[[1]])&(mu1<thres1[[2]]))*(mu1-thres1[[1]]) +
    (mu1 >=thres1[[2]])*(1/(2*thres1[[2]])*mu1^2)+(thres1[[2]]/2 - thres1[[1]])
  M  <- meancbf; M <- M*mask; M[mask==1] <- mu; modrobprior <- mu/10;
  gmidx2 <- as.numeric((gm1>thresh) & (M==0) & (wm1 > csf1))
  wmidx2 <- as.numeric((wm1>thresh) & (M==0) & (gm1 > csf1))
  if (sum(gmidx2)==0 | sum(wmidx2)==0) { 
      gmidx2 <- as.numeric(gm>thresh); wmidx2 <- as.numeric(wm>thresh)}
  idxx <- as.numeric(gmidx2 | wmidx2)
  X    <- zeros(length(idxx),2)
  X[,1] <- gm1[gm1>-1]*idxx; 
  X[,2] <- wm1[wm1>-1]*idxx
  A     <- (meancbf[idxx>=0])*idxx; 
  c     <- mldivide(X, A);
  Globalpriorfull <- c[1]*gm1 +c[2]*wm1
  Globalprior     <- Globalpriorfull[mask==1];
#}

localprior <-  0 
lmd        <-  0


bb <- myrobustfit(Y=y,mu = mu, Globalprior = Globalprior, lmd = lmd, localprior = localprior, wfun = wfun,tune = tune,flagstd = flagstd,flagmodrobust =flagmodrobust, modrobprior = modrobprior)

newcbf            <- meancbf;
newcbf            <- newcbf*mask
newcbf[mask==1]   <- bb
outpath_cbf       <- paste(outpath,'_cbfscrub.nii.gz',sep='')

writeNifti(newcbf,template = cbfts,outpath_cbf)