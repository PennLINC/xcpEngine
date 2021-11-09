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

###################################################################
# Parse arguments to script, and ensure that the required arguments
# have been passed.
###################################################################
option_list = list(
   make_option(c("-t", "--tab"), action="store", default='null', type='character',
              help=" regresssor from fmriprep to check if there any steady volume             
                  etc."),
   make_option(c("-n", "--nvd"), action="store", default=0, type='integer',
              help="number of columns to remove "),
    make_option(c("-p", "--put"), action="store", default=NA, type='character',
              help="print out the table")
)
opt = parse_args(OptionParser(option_list=option_list))

if (is.na(opt$put)) {
   cat('User did not specify an output path.\n')
   cat('Use removenonsteady.R -h for an expanded usage menu.\n')
   quit()
}


nvd <- opt$nvd
tab1 <- opt$tab
out2 <- opt$put

rr=read.table(tab1, sep='\t',header=TRUE)
mat1 = rr[-c(1:nvd),] 
write.table(mat1,file=out2, sep='\t',col.names = colnames(rr), row.names=F,quote=F)



