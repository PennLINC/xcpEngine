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










routine                       @1    Cortical contrast
if ! is_image ${corticalContrast[${cxt}]} \
|| rerun
   then
   subroutine                 @1.1  Resampling segmentation to high-resolution space
   exec_afni   3dresample \
      -dxyz    .25 .25 .25 \
      -inset   ${segmentation[cxt]} \
      -prefix  ${intermediate}_${cur}-upsample.nii.gz
   subroutine                 @1.2  Mapping GM-WM boundary
   exec_fsl    fslmaths ${intermediate}_${cur}-upsample.nii.gz \
      -thr     3  \
      -uthr    3  \
      -edge       \
      -uthr    1  \
      -bin        \
   ${intermediate}_${cur}-upsample-edge.nii.gz
   subroutine                 @1.3  Determining voxelwise distance from boundary
   exec_ants   ImageMath 3    ${intermediate}_${cur}-dist-from-edge.nii.gz \
               MaurerDistance ${intermediate}_${cur}-upsample-edge.nii.gz 1
   exec_fsl    fslmaths ${intermediate}_${cur}-dist-from-edge.nii.gz \
      -thr     .75   \
      -uthr    1.25  \
      -bin           \
      ${intermediate}_${cur}-dist-from-edge-bin.nii.gz
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
      exec_fsl    fslmaths ${intermediate}_${cur}-upsample.nii.gz \
         -thr     ${!class_val}  \
         -uthr    ${!class_val}  \
         -mul     ${intermediate}_${cur}-dist-from-edge-bin.nii.gz \
         -bin                    \
          ${intermediate}_${cur}-dist-from-edge-${class}.nii.gz
      subroutine              @1.6  Downsampling to original space
      exec_ants   antsApplyTransforms -e 3 -d 3 \
         -i       ${intermediate}_${cur}-dist-from-edge-${class}.nii.gz \
         -o       ${intermediate}_${cur}-ds-dist-from-edge-${class}.nii.gz \
         -r       ${segmentation[${cxt}]}       \
         -n       Gaussian
      subroutine              @1.7  Binarising
      exec_fsl    fslmaths ${intermediate}_${cur}-ds-dist-from-edge-${class}.nii.gz \
         -thr     .05            \
         -bin                    \
      ${intermediate}_${cur}-ds-dist-from-edge-${class}-bin.nii.gz
   done
   ################################################################
   # Compute cortical contrast.
   ################################################################
   subroutine                 @1.8  Computing cortical contrast
   exec_xcp cortCon.R \
      -W    ${intermediate}_${cur}-ds-dist-from-edge-wm-bin.nii.gz \
      -G    ${intermediate}_${cur}-ds-dist-from-edge-gm-bin.nii.gz \
      -T    ${struct[sub]} \
      -o    ${corticalContrast[${cxt}]}
   subroutine                 @1.9  Cortical contrast computed
else
   subroutine                 @1.10 Cortical contrast computed
fi
routine_end





completion
