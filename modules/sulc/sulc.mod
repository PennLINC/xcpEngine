#!/usr/bin/env bash

###################################################################
#   ✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡   #
###################################################################

###################################################################
# SPECIFIC MODULE HEADER
# This module computes a basic sulcal depth estimate.
###################################################################
mod_name_short=sulc
mod_name='SULCAL DEPTH MODULE'
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
derivative     sulcalDepth          ${prefix}_sulcalDepth

derivative_set sulcalDepth          Statistic        mean

require image mask
require image segmentation       \
     or       segmentation3class \
     as       segmentation

<<DICTIONARY

sulcalDepth
   The voxelwise map of sulcal depth values.

DICTIONARY










if ! is_image ${sulcalDepth[cxt]}
   then
   ################################################################
   # Compute mean distance from the convex hull / dural surface. In
   # this prototype, we approximate the convex hull as the brain
   # mask.
   ################################################################
   exec_fsl    fslmaths ${mask[cxt]} \
      -mul     -1 \
      -add      1 \
      ${intermediate}-mask-inverse.nii.gz
   exec_ants   ImageMath 3 ${intermediate}-dist-from-hull.nii.gz \
               MaurerDistance ${intermediate}-mask-inverse.nii.gz
   ################################################################
   # Intersect mean distance with the GM from the segmentation.
   ################################################################
   exec_xcp    val2mask.R \
      -i       ${segmentation[cxt]} \
      -v       ${sulc_gm_val[cxt]} \
      -o       ${intermediate}-gm-mask.nii.gz
   exec_fsl    fslmaths ${intermediate}-dist-from-hull.nii.gz \
      -mul     ${intermediate}-gm-mask.nii.gz \
      ${sulcalDepth[cxt]}
fi





completion
