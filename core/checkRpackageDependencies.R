#!/usr/bin/env Rscript

###################################################################
#  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  #
###################################################################

###################################################################
# Check all R package dependencies
###################################################################
failed=FALSE
if(!is.element('RNifti', installed.packages()[,1])) {
   cat(' :::Dependencies check failed: RNifti\n :::Please add RNifti to your R installation\n')
   failed=TRUE
}
if(!is.element('optparse', installed.packages()[,1])) {
   cat(' :::Dependencies check failed: optparse\n :::Please add optparse to your R installation\n')
   failed=TRUE
}
if(!is.element('pracma', installed.packages()[,1])) {
   cat(' :::Dependencies check failed: pracma\n :::Please add pracma to your R installation\n')
   failed=TRUE
}
if(!is.element('signal', installed.packages()[,1])) {
   cat(' :::Dependencies check failed: signal\n :::Please add signal to your R installation\n')
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
ver_RNIFTI <- packageVersion("RNifti")
ver_OPTPARSE <- packageVersion("optparse")
ver_PRACMA <- packageVersion("pracma")
ver_SIGNAL <- packageVersion("signal")

cat(as.character(ver_RNIFTI),' ')
cat(as.character(ver_OPTPARSE),' ')
cat(as.character(ver_PRACMA),' ')
cat(as.character(ver_SIGNAL),' ')
