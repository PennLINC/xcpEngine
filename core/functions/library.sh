#!/usr/bin/env bash

###################################################################
#  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  #
###################################################################

###################################################################
# Load the complete XCP bash function library.
###################################################################
LIBRARY=${XCPEDIR}/core/functions

source ${LIBRARY}/arithmetic
source ${LIBRARY}/cleanup
source ${LIBRARY}/complete_already
source ${LIBRARY}/configure
source ${LIBRARY}/derivative
source ${LIBRARY}/derivative_parse
source ${LIBRARY}/derivative_typeof
source ${LIBRARY}/exec_afni
source ${LIBRARY}/exec_ants
source ${LIBRARY}/exec_c3d
source ${LIBRARY}/exec_fsl
source ${LIBRARY}/exec_log_open
source ${LIBRARY}/exec_log_close
source ${LIBRARY}/exec_sys
source ${LIBRARY}/exec_xcp
source ${LIBRARY}/is_1D
source ${LIBRARY}/is_image
source ${LIBRARY}/is_integer
source ${LIBRARY}/is+integer
source ${LIBRARY}/is_numeric
source ${LIBRARY}/is+numeric
source ${LIBRARY}/load_derivatives
source ${LIBRARY}/output
source ${LIBRARY}/processed
source ${LIBRARY}/quality_metric
source ${LIBRARY}/rerun
source ${LIBRARY}/return_field
source ${LIBRARY}/routine
source ${LIBRARY}/routine_end
source ${LIBRARY}/subroutine
source ${LIBRARY}/verbose
source ${LIBRARY}/write_derivative
source ${LIBRARY}/write_output
source ${LIBRARY}/write_output_safe
