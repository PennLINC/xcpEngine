#!/usr/bin/env bash

###################################################################
#  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  #
###################################################################

###################################################################
# SPECIFIC MODULE HEADER
# This module aligns the analyte image to a high-resolution target.
###################################################################
mod_name_short=score
mod_name='CBF score'
mod_head=${XCPEDIR}/core/CONSOLE_MODULE_RC

###################################################################
# GENERAL MODULE HEADER
###################################################################
source ${XCPEDIR}/core/constants
source ${XCPEDIR}/core/functions/library.sh
source ${XCPEDIR}/core/parseArgsMod

###################################################################
# MODULE COMPLETIO
###################################################################
completion() {
   source ${XCPEDIR}/core/auditComplete
   source ${XCPEDIR}/core/updateQuality
   source ${XCPEDIR}/core/moduleEnd
}

##################################################################
# OUTPUTS
###################################################################
derivative                cbfscorets      ${prefix}_cbfscorets.nii.gz   
derivative                cbfscore        ${prefix}_cbfscore.nii.gz


output                cbfscorets      ${prefix}_cbfscorets.nii.gz   
output                cbfscore        ${prefix}_cbfscore.nii.gz


qc nvoldel  nvoldel  ${prefix}_nvoldel.txt 


derivative_set       cbfscore     Statistic         mean


process               cbfscorets        ${prefix}_cbfscorets


    subroutine  @1.2 computing cbf score
  # obtain the score 
        exec_xcp score.R                 \
             -i     ${perfusion[sub]}       \
             -g     ${gm2seq[sub]}           \
             -w     ${wm2seq[sub]}           \
             -c     ${csf2seq[sub]}          \
             -t     ${score_thresh[cxt]} \
             -o     ${out}/score/${prefix}

  
routine_end  

completion
