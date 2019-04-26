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
derivative            cbf_scrub_mean       ${prefix}_cbfscrub.nii.gz

output                cbf_score_ts         ${prefix}_cbfscore_ts.nii.gz   
output                cbf_score_mean       ${prefix}_cbfscore_mean.nii.gz
output                cbf_scrub_mean       ${prefix}_cbfscrub.nii.gz

qc nvoldel  nvoldel  ${prefix}_nvoldel.txt




derivative_set       cbf_score_mean     Statistic         mean
derivative_set       cbf_scrub_mean     Statistic         mean




gm_seq=${out}/scrub/${prefix}_gm2seq.nii.gz 
wm_seq=${out}/scrub/${prefix}_wm2seq.nii.gz 
csf_seq=${out}/scrub/${prefix}_csf2seq.nii.gz
mask1=${intermediate}_mask_seq.nii.gz 
mask_asl=${out}/scrub/${prefix}_mask_asl.nii.gz 
struct_asl=${out}/scrub/${prefix}_struct_seq.nii.gz 

if is_image ${struct[sub]}
  then
   exec_ants antsApplyTransforms -e 3 -d 3 -r ${referenceVolume[sub]} \
        -i ${gm[sub]} -t ${struct2seq[sub]} \
        -o ${gm_seq} -n NearestNeighbor
   exec_ants antsApplyTransforms -e 3 -d 3 -r ${referenceVolume[sub]} \
        -i ${wm[sub]} -t ${struct2seq[sub]} \
        -o ${wm_seq} -n NearestNeighbor
   exec_ants antsApplyTransforms -e 3 -d 3 -r ${referenceVolume[sub]} \
        -i ${csf[sub]} -t ${struct2seq[sub]} \
        -o ${csf_seq} -n NearestNeighbor
    
  
   exec_ants antsApplyTransforms -e 3 -d 3 -r ${referenceVolume[sub]} \
        -i ${structmask[sub]} -t ${struct2seq[sub]} \
        -o ${mask1} -n NearestNeighbor  

   exec_fsl  fslmaths ${referenceVolume[sub]} -mul ${mask1} \
         -bin ${mask_asl} 
  output mask ${out}/scrub/${prefix}_mask_asl.nii.gz 

  exec_ants antsApplyTransforms -e 3 -d 3 -r ${referenceVolume[sub]} \
        -i ${struct[sub]} -t ${struct2seq[sub]} \
        -o ${struct_asl} -n NearestNeighbor 
  exec_fsl fslmaths ${referenceVolume[sub]} -mul \
      ${mask1} ${out}/scrub/${prefix}_referenceVolumeBrain.nii.gz
  output referenceVolumeBrain ${out}/scrub/${prefix}_referenceVolumeBrain.nii.gz
fi

    subroutine  @1.2 computing cbf score
  # obtain the score 
        exec_xcp score.R                 \
             -i     ${perfusion[sub]}              \
             -g     ${gm_seq}           \
             -w     ${wm_seq}           \
             -c     ${csf_seq}          \
             -t     ${scrub_thresh[cxt]} \
             -o     ${out}/scrub/${prefix}
    subroutine  @1.3 computing cbf scrubbing
 # compute the scrub 
        exec_xcp  scrub_cbf.R           \
            -i     ${cbf_score_ts[cxt]} \
            -g     ${gm_seq}           \
            -w     ${wm_seq}          \
            -m     ${mask[cxt]}         \
            -c     ${csf_seq}          \
            -t     ${scrub_thresh[cxt]} \
            -o    ${out}/scrub/${prefix}



routine_end  

completion
