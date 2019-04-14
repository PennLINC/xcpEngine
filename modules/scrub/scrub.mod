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
derivative            cbf_score_ts         ${prefix}_cbfscore_ts.nii.gz    
derivative            cbf_score_mean       ${prefix}_cbfscore_mean.nii.gz
derivative            cbf_scrub_mean       ${prefix}_cbf_scrub.nii.gz

output                cbf_score_ts         ${prefix}_cbfscore_ts.nii.gz   
output                cbf_score_mean       ${prefix}_cbfscore_mean.nii.gz
output                cbf_scrub_mean       ${prefix}_cbf_scrub.nii.gz





derivative_set       cbf_score_mean     Statistic         mean
derivative_set       cbf_scrub_mean     Statistic         mean


process               cbf_scrub       ${prefix}_scrub.nii.gz

# register the perfusion to struct 
perf=${out}/scrub/${prefix}_perfusion.nii.gz 
mask1=${out}/scrub/${prefix}_mask.nii.gz
   routine  @1.0 score and scrubbing
if ! is_image ${cbf_scrub_mean[cxt]} \
|| rerun
   then
    subroutine  @1.1 perfusiion image to struct space
    if is_image ${struct[sub]}
    exec_ants antsApplyTransforms -r ${struct[sub]} \
        -i ${perfusion[sub]} -t ${seq2struct[sub]} \
        -o ${perf} -n NearestNeighbor

    exec_ants antsApplyTransforms -r ${struct[sub]} \
        -i ${mask[sub]} -t ${seq2struct[sub]} \
        -o ${mask1} -n NearestNeighbor
    output MASK ${out}/scrub/${prefix}_mask.nii.gz
    fi

    subroutine  @1.2 computing cbf score
  # obtain the score 
        exec_xcp score.R                 \
             -i     ${perf}              \
             -g     ${gm[sub]}           \
             -w     ${wm[sub]}           \
             -c     ${csf[sub]}          \
             -t     ${scrub_thresh[cxt]} \
             -o     ${out}/scrub/${prefix}
    subroutine  @1.3 computing cbf scrubbing
 # compute the scrub 
        exec_xcp  scrub_cbf.R           \
            -i     ${cbf_score_ts[cxt]} \
            -g     ${gm[sub]}           \
            -w     ${wm[sub]}           \
            -m     ${MASK[cxt]}         \
            -c     ${csf[sub]}          \
            -t     ${scrub_thresh[cxt]} \
            -o    ${out}/scrub/${prefix}
fi

exec_sys ln -sf ${prefix}_cbf_scrub.nii.gz $out/${prefix}.nii.gz 
routine_end  

completion