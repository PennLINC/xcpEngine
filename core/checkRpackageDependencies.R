#!/usr/bin/env Rscript

###################################################################
#  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  #
###################################################################

###################################################################
# Check all R package dependencies
###################################################################
failed=FALSE
pkg <- installed.packages()[,1]
if(!is.element('RNifti', pkg)) {
   write('· [Dependencies check failed: RNifti\n :::Please add RNifti to your R installation]', stderr())
   failed=TRUE
}
if(!is.element('optparse', pkg)) {
   write('· [Dependencies check failed: optparse\n :::Please add optparse to your R installation]', stderr())
   failed=TRUE
}
if(!is.element('pracma', pkg)) {
   write('· [Dependencies check failed: pracma\n :::Please add pracma to your R installation]', stderr())
   failed=TRUE
}
if(!is.element('signal', pkg)) {
   write('· [Dependencies check failed: signal\n :::Please add signal to your R installation]', stderr())
   failed=TRUE
}

###################################################################
# Exit if any dependency is unsatisfied.
###################################################################
if (failed==TRUE) {
   quit()
}

###################################################################
# Obtain and print versions of all package dependencies.
###################################################################
ver_RNIFTI     <- packageVersion("RNifti")
ver_OPTPARSE   <- packageVersion("optparse")
ver_PRACMA     <- packageVersion("pracma")
ver_SIGNAL     <- packageVersion("signal")

cat(as.character(ver_RNIFTI),' ')
cat(as.character(ver_OPTPARSE),' ')
cat(as.character(ver_PRACMA),' ')
cat(as.character(ver_SIGNAL),' ')
