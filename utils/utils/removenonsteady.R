#! /usr/bin/env Rscript

################################################################### 
#  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  #
###################################################################

###################################################################
# You are advised to avoid excessive dependency on this script
# for the time being.
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#

###################################################################

###################################################################
# Load required libraries
###################################################################
suppressMessages(suppressWarnings(library(optparse)))
suppressMessages(suppressWarnings(library(pracma)))
suppressMessages(suppressWarnings(library(RNifti)))

###################################################################
# Parse arguments to script, and ensure that the required arguments
# have been passed.
###################################################################
option_list = list(
   make_option(c("-i", "--img"), action="store", default='null', type='character',
              help="Image to check if there is volume"),
   make_option(c("-t", "--tab"), action="store", default='null', type='character',
              help=" regresssor from fmriprep to check if there any steady volume             
                  etc."),
   make_option(c("-o", "--out"), action="store", default=NA, type='character',
              help="Output path of image"),
    make_option(c("-p", "--put"), action="store", default=NA, type='character',
              help="print out the table")
)
opt = parse_args(OptionParser(option_list=option_list))

if (is.na(opt$out)) {
   cat('User did not specify an output path.\n')
   cat('Use removenonsteady.R -h for an expanded usage menu.\n')
   quit()
}


img <- opt$img
tab1 <- opt$tab
out1 <- opt$out
out2 <- opt$put

rr=read.table(tab1, sep='\t',header=TRUE)
outmat = rr[ , grepl( 'non_steady', names(rr))] 
outmat=as.matrix(outmat)
outmat=rowSums(outmat)
b=which(outmat>=1)

if (length(b) == 0 ) { img1=readNifti(img); writeNifti(img1,out1,template=img1,datatype = "float32"); write.table(rr,file=out2, sep='\t',col.names = T, row.names=F,quote=F) ; print('No non-steady volumes')
    } else  {
        bb=readNifti(img) 
        img2=bb[,,,-b] 
        mat1=rr[-b,]
        writeNifti(img2,out1,template=bb,datatype = "float32")
        print(paste0("Non-steady volumes deleted: ", length(b)))
        write.table(mat1,file=out2, sep='\t',col.names = T, row.names=F,quote=F)} 




