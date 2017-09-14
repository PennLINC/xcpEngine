#!/usr/bin/env bash

###################################################################
#  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  #
###################################################################

###################################################################
# Load the functional preprocessing bash function library.
###################################################################
LIBRARY=${XCPEDIR}/core/functions

source ${LIBRARY}/smooth_spatial
source ${LIBRARY}/filter_temporal
source ${LIBRARY}/demean_detrend
source ${LIBRARY}/remove_outliers
