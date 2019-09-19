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
              help="Path to the 4D ASL time series from which perfusionwill be computed."),
   make_option(c("-y", "--grey"), action="store", default=NA, type='character',
              help="Grey matter."),
   make_option(c("-w", "--white"), action="store", default=NA, type='character',
              help="white matter"),
   make_option(c("-c", "--csf"), action="store", default=NA, type='character',
              help="cerebrospinal fluid"),
   make_option(c("-o", "--out"), action="store", default=NA, type='character',
              help="The root output path for all voxelwise perfusion maps."),
   make_option(c("-t", "--thresh"), action="store", default=0.7, type='numeric',
              help="threshold the segmentation tissues")
)
opt = parse_args(OptionParser(option_list=option_list))

if (is.na(opt$img)) {
   cat('User did not specify an input ASL time series.\n')
   cat('Use score.R -h for an expanded usage menu.\n')
   quit()
}




# get the input data

cbf_ts   <-         opt$img
wm       <-         opt$white
gm       <-         opt$grey
csf      <-         opt$csf
outpath  <-         opt$out
thresh   <-         opt$thresh

#read the maps and cbf time series  
wm       <-         readNifti(wm)
gm       <-         readNifti(gm)
csf      <-         readNifti(csf)
cbfts    <-         readNifti(cbf_ts)



# threshold the probability maps
gm[gm<thresh]=0;             gm[gm>0]=1
wm[wm<thresh]=0;             wm[wm>0]=1
csf[csf<thresh]=0;           csf[csf>0]=1

gc       <-        gm 
wmc      <-        wm; 
csfc     <-        csf;

# get the total number of voxle within csf,gm and wm 
nogm <- sum(gm>0)-1;  nowm  <- sum(wm>0)-1;  nocf  <- sum(csf>0)-1;  
mask <- (gm+wm+csf);  msk   <- sum(mask>0)

# mean  of times series cbf within greymatter
cbfdim  <- dim(cbfts);            mgmts  <-  rep(0,cbfdim[4])
    for (i in 1:cbfdim[4]) {
       tmp         <- cbfts[,,,i]; 
       tmp         <- tmp[gc==1]; 
       mgmts[i]    <- mean(tmp)
       }

# robiust mean and meadian
medmngm    <-    median(mgmts)
sdmngm     <-    mad(mgmts)/0.675

#find volume outside 2.5 SD?updateNifti
indx    <-  as.numeric(abs(mgmts-medmngm)>2.5*sdmngm)

R       <-  apply(cbfts[,,,indx==0],c(1,2,3),mean)
V <- nogm*var(R[gm==1]) + nowm*var(R[wm==1]) + nocf*var(R[csf==1])
V1  <- V+1
while (V < V1) {
    V1 <- V; R1 <- R; indx1 <- indx; CC <- -2*rep(1,cbfdim[4])
       for (s in 1:cbfdim[4]) {
              if (indx[s] != 0 ) { break }
              else {
              tmp1 <- cbfts[,,,s]; CC[s] <- cor(R[mask>0],tmp1[mask>0]) }
    
        }
    inx <-  which.max(CC); indx[inx] <- 2;
    R <- apply(cbfts[,,,indx==0],c(1,2,3),mean)
    V <- nogm*var(R[gm==1]) + nowm*var(R[wm==1]) + nocf*var(R[csf==1])
}

#writeout the output 

cbfts_recon   <-    cbfts[,,,indx==0]
meancbf       <-    apply(cbfts_recon,c(1,2,3),mean)
b             <-    updateNifti(meancbf,template = cbfts,datatype = 'auto')
bb            <-    updateNifti(cbfts_recon,template = cbfts,datatype = 'auto')
outpath_mean  <-    paste(outpath,'_cbfscore.nii.gz',sep='')
outpath_tts   <-    paste(outpath,'_cbfscore_ts.nii.gz',sep='')
ng            <- dim(cbfts_recon) 
df=cbfdim[4]-ng[4]
deletvol <-    paste(outpath,'_nvoldel.txt',sep='')
 write.table(df,deletvol,quote=FALSE, row.names=FALSE,col.names=FALSE)
writeNifti(b,outpath_mean)
writeNifti(bb,outpath_tts)
