#!/usr/bin/env bash

###################################################################
#  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  #
###################################################################

###################################################################
# Load the complete XCP bash function library.
###################################################################
LIBRARY=${XCPEDIR}/core/functions

source ${LIBRARY}/configure
source ${LIBRARY}/derivative
source ${LIBRARY}/is_image
source ${LIBRARY}/output
source ${LIBRARY}/processed
source ${LIBRARY}/quality_metric
source ${LIBRARY}/write_derivative
source ${LIBRARY}/write_output
source ${LIBRARY}/write_output_safe
