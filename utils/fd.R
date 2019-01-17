#! /usr/bin/env Rscript

###################################################################
#  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  #
###################################################################

###################################################################
# R script to compute framewise displacement from a .par file
# output by MCFLIRT
###################################################################

###################################################################
# Load required libraries
###################################################################
suppressMessages(suppressWarnings(library(optparse)))

###################################################################
# Parse arguments to script, and ensure that the required arguments
# have been passed.
###################################################################
option_list = list(
   make_option(c("-r", "--rps"), action="store", default=NA, type='character',
              help="Path to a file containing realignment parameters"),
   make_option(c("-o", "--out"), action="store", default=NA, type='character',
              help="Output path. If none is specified, output will be printed to the terminal instead."),
   make_option(c("-c", "--convert"), action="store", default=1/50, type='numeric',
              help="Conversion factor from radians to millimeters [default 0.02].")
)
opt = parse_args(OptionParser(option_list=option_list))
rps <- opt$rps
out <- opt$out
rad2mm <- opt$convert

if (is.na(rps)) {
   cat('User did not specify path to realignment parameters.\n')
   cat('Use fd.R -h for an expanded usage menu.\n')
   quit()
}

###################################################################
# 1. Load in RPs
###################################################################
rps <- unname(as.matrix(read.table(rps)))
nobs <- dim(rps)[1]
nvar <- dim(rps)[2]

###################################################################
# 2. Compute the derivative
###################################################################
rps.deriv <- diff(rps,lag=1,differences=1)
rps.pad <- matrix(0,1,nvar)
rps.deriv <- rbind(rps.pad,rps.deriv)

###################################################################
# 3. Convert radians to mm
###################################################################
rps.deriv[,1:3] <- rps.deriv[,1:3]/rad2mm

###################################################################
# 4. Compute absolute value
###################################################################
rps.deriv.abs <- abs(rps.deriv)

###################################################################
# 5. Sum over components
###################################################################
fd <- apply(rps.deriv.abs,1,sum)

###################################################################
# 6. Write output
###################################################################
if (!is.na(out)) {
   write.table(fd,file=out, col.names = F, row.names = F)
} else {
   cat(fd)
   cat('\n')
}
