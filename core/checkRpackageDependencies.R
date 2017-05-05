#!/usr/bin/env Rscript

###################################################################
#  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  #
###################################################################

###################################################################
# Check all R package dependencies
###################################################################
failed=FALSE
if(!is.element('ANTsR', installed.packages()[,1])) {
   cat(' :::Dependencies check failed: ANTsR\n :::Please add ANTsR to your R installation\n')
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
ver_ANTSR <- packageVersion("ANTsR")
ver_OPTPARSE <- packageVersion("optparse")
ver_PRACMA <- packageVersion("pracma")
ver_SIGNAL <- packageVersion("signal")

cat(' ** ANTsR version     ',as.character(ver_ANTSR),'\n')
cat('       ** optparse version  ',as.character(ver_OPTPARSE),'\n')
cat('       ** pracma version    ',as.character(ver_PRACMA),'\n')
cat('       ** signal version    ',as.character(ver_SIGNAL),'\n')
