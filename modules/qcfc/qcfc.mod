#!/usr/bin/env bash

###################################################################
#  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  #
###################################################################

###################################################################
# SPECIFIC MODULE HEADER
# This module assesses quality of functional connectivity data
###################################################################
mod_name_short=qcfc
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
   source ${XCPEDIR}/core/auditComplete
   source ${XCPEDIR}/core/updateQuality
   source ${XCPEDIR}/core/moduleEnd
}





###################################################################
# OUTPUTS
###################################################################
define      voxts                   ${outdir}/${prefix}_voxts.png
output      depthMap                ${prefix}_depthMap.nii.gz
qc t_dof  estimatedLostTemporalDOF  ${prefix}_tdof.txt

input       depthMap
input       residualised       \
   or       icaDenoised        \
   as       denoised
input       residualised_space \
   or       icaDenoised_space  \
   as       dn_space

if [[ -s ${voxts[cxt]} ]] \
&& ! rerun
   then
   subroutine                 @0.1  qcfc has already run to completion
   completion
fi

<<DICTIONARY

depthMap
   A layered segmentation, wherein each voxel has a value equal to
   its depth in its assigned tissue class.
voxts
   A graphical summary of quality assessment measures for
   functional connectivity processing.

DICTIONARY










###################################################################
# Generate a tissue-wise depth map in anatomical space.
###################################################################
routine                       @1    Preparing depth map
subroutine                    @1.1  Segmentation: ${segmentation[sub]}
subroutine                    @1.2  Output: ${depthMap[cxt]}
seg_class=( $(
exec_xcp    unique.R                \
   -i       ${segmentation[sub]}
) )
exec_xcp    layerLabels             \
   -l       ${segmentation[sub]}    \
   -i       ${intermediate}         \
   -o       ${depthMap[cxt]}
routine_end





###################################################################
# Align all images to downsampled sequence space. The linear
# downsampling should be somewhat similar to the spatial smoothing
# that Power applies, with the additional benefit of improving
# plotting speed.
###################################################################
routine                       @2    Aligning depth map

subroutine                    @2.1  Resampling to 6mm isotropic: minimally preprocessed
exec_afni   3dresample              \
   -dxyz    6 6 6                   \
   -prefix  ${intermediate}-pp-rs.nii.gz \
   -inset   ${preprocessed[sub]}    \
   -rmode   Li

if is_image ${denoised[cxt]}
   then
   subroutine                 @2.2  Resampling to 6mm isotropic: denoised
   warpspace   ${residualised[sub]}       \
               ${intermediate}-dn.nii.gz  \
               ${dn_space[cxt]}:${preprocessed_space[sub]}
   exec_afni   3dresample                 \
      -dxyz    6 6 6                      \
      -prefix  ${intermediate}-dn-rs.nii.gz \
      -inset   ${intermediate}-dn.nii.gz  \
      -rmode   Li
   ################################################################
   # The existence of the uncensored variable indicates that the
   # time series has been censored. In this case, it will be
   # necessary to reinsert the censored volumes in order to
   # ensure proper alignment.
   ################################################################
   if is_image ${uncensored[sub]}
      then
      subroutine              @2.3  Realigning censored volumes
      exec_xcp censor.R \
         -i    ${intermediate}-dn-rs.nii.gz \
         -t    ${tmask[sub]} \
         -u    TRUE \
         -o    ${intermediate}-dn-rs.nii.gz
   fi
fi

subroutine                    @2.4  Aligning depth map to sequence space
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
is_1D ${dvars[sub]}           &&  ts_1d="${ts_1d}DV:${dvars[sub]}:1.5,"
is_1D ${rel_rms[sub]}         &&  ts_1d="${ts_1d}RMS:${rel_rms[sub]}:0.5,"
is_1D ${fd[sub]}              &&  ts_1d="${ts_1d}FD:${fd[sub]}:1,"

[[ -n ${qcfc_custom[cxt]} ]]  &&  ts_1d="${ts_1d}${qcfc_custom[cxt]},"

[[ -n ${ts_1d} ]]             &&  ts_1d="-t ${ts_1d%,}"

subroutine                    @3.2  Generating visuals
[[ ${#seg_class[@]} == 3 ]]   &&    class_names="-n ${BRAINATLAS}/segmentation3/segmentation3NodeNames.txt"
[[ ${#seg_class[@]} == 6 ]]   &&    class_names="-n ${BRAINATLAS}/segmentation6/segmentation6NodeNames.txt"
exec_xcp voxts.R                    \
   -i    ${intermediate}-pp-rs.nii.gz${dn_arg} \
   -r    ${intermediate}-onion-rs.nii.gz \
   -o    ${voxts[cxt]}              \
   ${ts_1d}                         \
   ${class_names}

routine_end





routine                       @4    Estimating loss of temporal degrees of freedom
unset    v  q
declare -A  q
for v in "${!qvars[@]}"
   do
   vn=${qvars[v]}
   q[${vn}]=${qvals[${v}]}
done
tDOF=0
if [[ -n ${q[nNuisanceParameters]}  ]]
   then
   subroutine                 @4.1  ${q[nNuisanceParameters]} nuisance parameters regressed
   tDOF=$(( ${tDOF}           +     ${q[nNuisanceParameters]}  ))
fi
if [[ -n ${q[nICsNoise]}            ]]
   then
   subroutine                 @4.2  ${q[nICsNoise]} IC time series flagged as noise
   tDOF=$(( ${tDOF}           +     ${q[nICsNoise]}            ))
fi
if [[ -n ${q[nVolCensored]}         ]]
   then
   subroutine                 @4.3  ${q[nVolCensored]} volumes censored
   tDOF=$(( ${tDOF}           +     ${q[nVolCensored]}         ))
fi
subroutine                    @4.4  Total lost tDOF: ${tDOF}
echo ${tDOF}                  >>    ${t_dof[cxt]}
routine_end





completion
