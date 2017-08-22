#!/usr/bin/env Rscript

###################################################################
#  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  #
###################################################################

###################################################################
# function for converting stick functions into curves to include
# in a linear model
#
# This is not to be used.
###################################################################
cat('THIS UTILITY IS NO LONGER SUPPORTED\n')
cat('EXITING\n')
quit()

###################################################################
# Load required libraries
###################################################################
suppressMessages(require(optparse))
suppressMessages(require(pracma))
#suppressMessages(require(ANTsR))

###################################################################
# Parse arguments to script, and ensure that the required arguments
# have been passed.
###################################################################
option_list = list(
   make_option(c("-i", "--img"), action="store", default=NA, type='character',
              help="Path to the BOLD timeseries that will be modelled"),
   make_option(c("-s", "--stick"), action="store", default=NA, type='character',
              help="Path to a directory containing files with onset,
                  duration, and amplitude information for the ideal
                  activation model to be fit, for instance as stick 
                  functions"),
   make_option(c("-d", "--deriv"), action="store", default=TRUE, type='logical',
              help="Specify whether you wish to include the first
                  temporal derivatives of each ideal timeseries in 
                  the linear model."),
   make_option(c("-n", "--interval"), action="store", default='seconds', type='character',
              help="Specify whether the timescale in the stick 
                  functions is in units of seconds or repetition 
                  times. Accepted options include:
                  'seconds' [default]
                  'trep'"),
   make_option(c("-c", "--custom"), action="store", default=NA, type='character',
              help="Comma-separated list of paths to files 
                  containing nuisance regressors or other custom
                  timeseries to be included in the model. Columns 
                  in the file should correspond to timeseries and 
                  should be equal in length to the analyte BOLD 
                  timeseries.")
   make_option(c("-m", "--mat"), action="store", default=NA, type='character',
              help="Use this option to write output in FSL .mat format.")
)
opt = parse_args(OptionParser(option_list=option_list))

if (is.na(opt$img)) {
   cat('User did not specify an input timeseries.\n')
   cat('Use stick2lm.R -h for an expanded usage menu.\n')
   quit()
}
if (is.na(opt$stick)) {
   cat('User did not specify a model.\n')
   cat('Use stick2lm.R -h for an expanded usage menu.\n')
   quit()
}

impath <- opt$img
modeldir <- opt$stick
derivs <- opt$deriv
interval <- opt$interval
custom <- opt$custom
sink("/dev/null")

###################################################################
# 1. Determine the repetition time and number of volumes from
#    the analyte timeseries.
###################################################################
suppressMessages(require(ANTsR))
syscom <- paste("fslval",impath,"pixdim4")
trep <- as.numeric(system(syscom,intern=TRUE))
syscom <- paste("fslval",impath,"dim4")
nvol <- as.numeric(system(syscom,intern=TRUE))

###################################################################
# 2. Obtain a list of stick function files.
###################################################################
syscom <- paste0("ls -d1 ",modeldir,"/*")
models <- system(syscom,intern=TRUE)

###################################################################
# Iterate through the stick function files.
###################################################################
lmmat <- c()
for (mfile in models) {
   ################################################################
   # 3. Load the stick function from the file.
   #
   #  * The first column must represent the onset time for each
   #    stimulus, in seconds.
   #  * The second column must represent the duration of each
   #    stimulus, in seconds.
   #  * The third column must represent the magnitude of each
   #    stimulus, in seconds.
   ################################################################
   model <- read.table(mfile)
   ncol <- dim(model)[2]
   nrow <- dim(model)[1]
   onset <- c()
   duration <- c()
   magnitude <- c()
   if (ncol >= 1) { onset <- model[,1] }
   if (ncol >= 2) { duration <- model[,2] }
   if (ncol >= 3) { magnitude <- model[,3] }
   if (interval == 'seconds') {
      times <- onset
   } else {
      times <- NULL
   }
   ################################################################
   # 4. Convolve each stick function with a modelled HRF.
   ################################################################
   if (isempty(magnitude) || numel(unique(magnitude)) <= 1) {
      convmodel <- hemodynamicRF(scans = nvol, 
                     onsets = onset, 
                     durations = duration, 
                     rt = trep, 
                     times = times, 
                     a1 = 8)
   ################################################################
   #    The HRF convolution that is built into ANTsR does not
   #    support stimuli of different magnitudes. Because
   #    convolution is distributive, it is possible to model this
   #    as a weighted sum of convolutions.
   ################################################################
   } else {
      cmodels <- zeros(nvol,nrow)
      for (i in seq(1,nrow)) {
         cmodels[,i] <- hemodynamicRF(scans = nvol, 
                        onsets = onset[i], 
                        durations = duration[i], 
                        rt = trep, 
                        times = times, 
                        a1 = 8)
      }
      convmodel <- apply(cmodels,1,sum)
   }
   ################################################################
   # 5. Compute the temporal derivative of the convolved model if
   #    that should be included in the design matrix.
   ################################################################
   dconv1 <- c()
   dconv <- c()
   if (derivs) {
      dconv <- zeros(nvol,1)
      dconv1 <- zeros(nvol + 1,1)
      dconv1[2:nvol,] <- diff(convmodel,lag = 1)
      #############################################################
      # FSL uses the mean of signal differences before and after
      # the time point to determine the temporal derivative at
      # that time point.
      #
      # This behaviour is overriden for now.
      #############################################################
      #for (i in seq(1,nvol)) {
      #   dconv[i,] <- mean(dconv1[i:i+1,])
      #}
      dconv <- dconv1[1:nvol,]
      
      convmodel <- cbind(convmodel,dconv)
   }
   lmmat <- cbind(lmmat,convmodel)
}

###################################################################
# 6. Read in any requested motion parameters or nuisance
#    regressors.
###################################################################
if (!is.na(custom)) {
   custom <- unlist(strsplit(custom,split=','))
   for (i in custom) {
      curreg <- read.table(i)
      lmmat <- cbind(lmmat,curreg)
   }
}

###################################################################
# 7. Compute the maximal amplitude of each ideal timeseries.
###################################################################
amplitude <- apply(lmmat,2,max) - apply(lmmat,2,min)

###################################################################
# 8. Print the design matrix.
###################################################################
sink(NULL)
nvar <- dim(lmmat)[2]
cat('/NumWaves\t',nvar,'\n')
cat('/NumPoints\t',nvol,'\n')
cat('/PPheights\t',amplitude,'\n\n')
cat('/Matrix\n')
for (i in 1:nvol){
   cat(unlist(lmmat[i,]), sep='\t')
   cat('\n')
}
