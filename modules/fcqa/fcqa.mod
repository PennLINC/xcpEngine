#!/usr/bin/env bash

###################################################################
#  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  #
###################################################################

###################################################################
# SPECIFIC MODULE HEADER
# This module assesses quality of functional connectivity data
###################################################################
mod_name_short=fcqa
mod_name='FUNCTIONAL QUALITY ASSESSMENT MODULE'
mod_head=${XCPEDIR}/core/CONSOLE_MODULE_RC

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
   write_output      depthMap
   
   source ${XCPEDIR}/core/auditComplete
   source ${XCPEDIR}/core/updateQuality
   source ${XCPEDIR}/core/moduleEnd
}





###################################################################
# OUTPUTS
###################################################################
output      fcqa                    ${prefix}_fcqa.png
derivative  depthMap                ${prefix}_depthMap

input       depthMap
input       residualised \
   or       icaDenoised  \
   as       denoised
input       residualised_space \
   or       icaDenoised_space  \
   as       dn_space

if [[ -s ${fcqa[cxt]} ]] \
&& ! rerun
   then
   subroutine                 @0.1  fcqa has already run to completion
   completion
fi

<<DICTIONARY

depthMap
   A layered segmentation, wherein each voxel has a value equal to
   its depth in its assigned tissue class.
fcqa
   A graphical summary of quality assessment measures for
   functional connectivity processing.

DICTIONARY










routine                       @1    Preparing depth map
subroutine                    @1.1  Segmentation: ${segmentation[sub]}
subroutine                    @1.2  Output: ${depthMap[cxt]}
exec_xcp    layerLabels             \
   -l       ${segmentation[sub]}    \
   -i       ${intermediate}         \
   -o       ${depthMap[cxt]}
routine_end





routine                       @2    Aligning depth map

subroutine                    @2.1  Resampling to 6mm isotropic: minimally preprocessed
exec_afni   3dresample              \
   -dxyz    6 6 6                   \
   -prefix  ${intermediate}-pp-rs.nii.gz \
   -inset   ${preprocessed[sub]}    \
   -rmode   NN

if is_image ${denoised[cxt]}
   then
   subroutine                 @2.2  Resampling to 6mm isotropic: denoised
   warpspace   ${residualised[sub]}       \
               ${intermediate}-dn.nii.gz  \
               ${dn_space[cxt]}:${preprocessed_space[sub]}
   exec_afni   3dresample                 \
      -dxyz    6 6 6                      \
      -prefix  ${intermediate}-dn-rs.nii.gz \
      -inset   ${intermediate}-dn.nii.gz \
      -rmode   NN
fi

subroutine                    @2.3  Aligning depth map to functional space
warpspace   ${depthMap[cxt]}              \
            ${intermediate}-onion.nii.gz  \
            ${structural[sub]}:${preprocessed_space[sub]} \
            NearestNeighbor
exec_afni   3dresample                    \
   -dxyz    6 6 6                         \
   -prefix  ${intermediate}-onion-rs.nii.gz \
   -inset   ${intermediate}-onion.nii.gz  \
   -rmode   NN

routine_end





routine                       @3    Preparing summary graphics

subroutine                    @3.1  Acquiring arguments
is_image ${intermediate}-dn-rs.nii.gz \
                              && dn_arg=",${intermediate}-dn-rs.nii.gz"
is_1D ${dvars[sub]}           &&  ts_1d="${ts_1d}DV:${dvars[sub]}:0-50,"
is_1D ${rel_rms[sub]}         &&  ts_1d="${ts_1d}RMS:${rel_rms[sub]}:0-0.5,"
is_1D ${fd[sub]}              &&  ts_1d="${ts_1d}FD:${fd[sub]}:0-1,"

[[ -n ${ts_1d} ]]             &&  ts_1d="-t ${ts_1d%,}"

subroutine                    @3.2  Generating visuals
exec_xcp voxts.R                    \
   -i    ${intermediate}-pp-rs.nii.gz${dn_arg} \
   -r    ${intermediate}-onion-rs.nii.gz \
   -o    ${fcqa[cxt]}               \
   ${ts_1d}

routine_end





completion
