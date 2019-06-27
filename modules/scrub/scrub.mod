#!/usr/bin/env bash

###################################################################
#  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  #
###################################################################

###################################################################
# SPECIFIC MODULE HEADER
# This module aligns the analyte image to a high-resolution target.
###################################################################
mod_name_short=scrub
mod_name='CBF scrubbing'
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
derivative            cbfscrub                 ${prefix}_cbfscrub.nii.gz


output                cbfscorets      ${prefix}_cbfscorets.nii.gz   
output                cbfscore        ${prefix}_cbfscore.nii.gz
output                cbfscrub        ${prefix}_cbfscrub.nii.gz
 


derivative_set       cbfscrub     Statistic         mean



    subroutine  @1.2 computing cbf score
  # obtain the score 
        exec_xcp score.R                 \
             -i     ${perfusion[sub]}       \
             -y     ${gm2seq[sub]}          \
             -w     ${wm2seq[sub]}           \
             -c     ${csf2seq[sub]}          \
             -t     ${scrub_thresh[cxt]} \
             -o     ${out}/scrub/${prefix}

    subroutine  @1.3 computing cbf scrubbing
 # compute the scrub 
        exec_xcp  scrub_cbf.R           \
            -i     ${cbfscorets[cxt]} \
            -y     ${gm2seq[sub]}           \
            -w     ${wm2seq[sub]}         \
            -c     ${csf2seq[sub]}          \
            -m     ${mask[sub]} \
            -t     ${scrub_thresh[cxt]} \
            -o     ${out}/scrub/${prefix}

  exec_sys rm -rf ${cbfscorets[cxt]} ${cbfscore[cxt]}  ${nvoldel[cxt]}
  
routine_end  

completion