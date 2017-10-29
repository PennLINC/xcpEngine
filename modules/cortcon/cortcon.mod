#!/usr/bin/env bash

###################################################################
#   ✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡   #
###################################################################

###################################################################
# SPECIFIC MODULE HEADER
# This module computes a voxelwise cortical contrast map for input
# to regional quantification.
###################################################################
mod_name_short=cortcon
mod_name='CORTICAL CONTRAST MODULE'
mod_head=${XCPEDIR}/core/CONSOLE_MODULE_AFGR

###################################################################
# GENERAL MODULE HEADER
###################################################################
source ${XCPEDIR}/core/constants
source ${XCPEDIR}/core/functions/library.sh
source ${XCPEDIR}/core/parseArgsMod

###################################################################
# MODULE COMPLETION
###################################################################
completion() {
   source ${XCPEDIR}/core/auditComplete
   source ${XCPEDIR}/core/updateQuality
   source ${XCPEDIR}/core/moduleEnd
}





###################################################################
# OUTPUTS
###################################################################
derivative     corticalContrast     ${prefix}_CorticalContrast

derivative_set corticalContrast     Statistic        mean

input   image mask
require image segmentation       \
     or       segmentation3class \
     as       segmentation

<<DICTIONARY

corticalContrast
   The voxelwise map of cortical contrast values.

DICTIONARY










if ! is_image ${corticalContrast[${cxt}]} \
|| rerun
   then
   routine                    @1    Preparing masks
   subroutine                 @1.1  Resampling segmentation to high-resolution space
   exec_afni   3dresample              \
      -dxyz    .25 .25 .25             \
      -inset   ${segmentation[cxt]}    \
      -prefix  ${intermediate}-upsample.nii.gz
   subroutine                 @1.2  Mapping GM-WM boundary
   exec_fsl    fslmaths ${intermediate}-upsample.nii.gz \
      -thr     ${cortcon_wm_val[cxt]}  \
      -uthr    ${cortcon_wm_val[cxt]}  \
      -edge                            \
      -uthr    1                       \
      -bin                             \
   ${intermediate}-upsample-edge.nii.gz
   subroutine                 @1.3  Determining voxelwise distance from boundary
   exec_ants   ImageMath 3    ${intermediate}-dist-from-edge.nii.gz \
               MaurerDistance ${intermediate}-upsample-edge.nii.gz 1
   exec_fsl    fslmaths ${intermediate}-dist-from-edge.nii.gz \
      -thr     .75                     \
      -uthr    1.25                    \
      -bin                             \
      ${intermediate}-dist-from-edge-bin.nii.gz
   ################################################################
   # Next, prepare the WM and GM masks.
   ################################################################
   subroutine                 @1.4  Preparing tissue masks
   declare           -A tissue_classes
   tissue_classes=(  [gm]="grey matter"
                     [wm]="white matter" )
   for class in "${!tissue_classes[@]}"
      do
      subroutine              @1.5  Extracting ${tissue_classes[$class]} distance maps
      class_val='cortcon_'${class}'_val['${cxt}']'
      exec_fsl    fslmaths ${intermediate}-upsample.nii.gz \
         -thr     ${!class_val}        \
         -uthr    ${!class_val}        \
         -mul     ${intermediate}-dist-from-edge-bin.nii.gz \
         -bin                          \
          ${intermediate}-dist-from-edge-${class}.nii.gz
      subroutine              @1.6  Downsampling to original space
      exec_ants   antsApplyTransforms -e 3 -d 3 \
         -i       ${intermediate}-dist-from-edge-${class}.nii.gz \
         -o       ${intermediate}-ds-dist-from-edge-${class}.nii.gz \
         -r       ${segmentation[${cxt}]} \
         -n       Gaussian
      subroutine              @1.7  Binarising
      exec_fsl    fslmaths ${intermediate}-ds-dist-from-edge-${class}.nii.gz \
         -thr     .05                  \
         -bin                          \
      ${intermediate}-ds-dist-from-edge-${class}-bin.nii.gz
   done
   routine_end
   ################################################################
   # Compute cortical contrast -- original
   ################################################################
   if [[ ${cortcon_formulation[cxt]} == orig ]]
      then
      routine                 @2    Cortical contrast -- original formulation
      date
      subroutine              @2.1  Computing cortical contrast
      exec_xcp cortCon.R               \
         -W    ${intermediate}-ds-dist-from-edge-wm-bin.nii.gz \
         -G    ${intermediate}-ds-dist-from-edge-gm-bin.nii.gz \
         -T    ${struct[sub]}          \
         -o    ${corticalContrast[${cxt}]}
      subroutine              @2.2  Cortical contrast computed
      date
   routine_end
   ################################################################
   # Compute cortical contrast -- fast
   ################################################################
   elif [[ ${cortcon_formulation[cxt]} == fast ]]
      then
      routine                 @3    Cortical contrast -- fast formulation
      date
      gmMask=${intermediate}-ds-dist-from-edge-gm-bin.nii.gz
      for i in {1..8}
         do
         subroutine           @3.1  Circling the WM boundary at ${i} mm
         exec_afni   3dLocalstat -overwrite \
            -prefix  ${intermediate}-nearestWM${i}.nii.gz \
            -nbhd    'SPHERE('${i}')' \
            -stat    mean \
            -mask    ${intermediate}-ds-dist-from-edge-wm-bin.nii.gz \
            -use_nonmask ${struct[sub]}
         exec_fsl    fslmaths ${intermediate}-nearestWM${i}.nii.gz \
            -div     ${struct[sub]} \
            -mul     ${gmMask} \
                     ${intermediate}-cortcon${i}.nii.gz
         exec_fsl    fslmaths ${intermediate}-cortcon${i}.nii.gz \
            -bin     ${intermediate}-exclusion.nii.gz
         exec_fsl    fslmaths ${gmMask} \
            -sub     ${intermediate}-exclusion.nii.gz \
                     ${intermediate}-gmMask.nii.gz
         gmMask=${intermediate}-gmMask.nii.gz
         ccvox=( "${ccvox[@]}" ${intermediate}-cortcon${i}.nii.gz )
      done
      subroutine              @3.2  Collating across all sampled distances
      exec_fsl fslmaths $(join_by ' -add ' "${ccvox[@]}") \
         -mul  ${intermediate}-ds-dist-from-edge-gm-bin.nii.gz \
               ${corticalContrast[${cxt}]}
      subroutine              @3.3  Cortical contrast computed
      date
      routine_end
   fi
else
   subroutine                 @0.1  Cortical contrast has already run to completion
fi





completion
