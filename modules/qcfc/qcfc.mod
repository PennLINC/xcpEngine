#!/usr/bin/env bash

##################################################################
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
define      dvars_root              ${outdir}/${prefix}_dvars
output      depthMap                ${prefix}_depthMap.nii.gz
output      dvars_post              ${dvars_root[cxt]}-std.1D
qc t_dof  estimatedLostTemporalDOF  ${prefix}_tdof.txt
qc dv_mo_cor_post motionDVCorrFinal ${prefix}_motionDVCorr.txt

input       depthMap
input       denoised_space \
   as       dn_space

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
if ! is_image ${depthMap[cxt]} \
|| rerun
   then
   routine                    @1    Preparing depth map
   subroutine                 @1.1  Segmentation: ${segmentation[sub]}
   subroutine                 @1.2  Output: ${depthMap[cxt]}
   seg_class=( $(
   exec_xcp    unique.R                \
      -i       ${segmentation[sub]}
   ) )
   exec_xcp    layerLabels             \
      -l       ${segmentation[sub]}    \
      -i       ${intermediate}         \
      -o       ${depthMap[cxt]}
   routine_end
fi





###################################################################
# Align all images to downsampled sequence space. The linear
# downsampling should be somewhat similar to the spatial smoothing
# that Power applies, with the additional benefit of improving
# plotting speed.
###################################################################
if [[ ! -s ${voxts[cxt]} ]] \
|| rerun
   then
   routine                    @2    Aligning depth map

   subroutine                 @2.1  Resampling to 6mm isotropic: minimally preprocessed
   exec_afni   3dresample              \
      -dxyz    6 6 6                   \
      -prefix  ${intermediate}-pp-rs.nii.gz \
      -inset   ${preprocessed[sub]}    \
      -rmode   Li

   if is_image ${denoised[sub]}
      then
      subroutine              @2.2  Resampling to 6mm isotropic: denoised
      warpspace   ${denoised[sub]}           \
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
         subroutine           @2.3  Realigning censored volumes
         exec_xcp censor.R \
            -i    ${intermediate}-dn-rs.nii.gz \
            -t    ${tmask[sub]} \
            -u    TRUE \
            -o    ${intermediate}-dn-rs.nii.gz
      fi
   fi

   subroutine                 @2.4  Aligning depth map to sequence space
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


   routine                    @3    Preparing summary graphics

   subroutine                 @3.1  Acquiring arguments

   ###################################################################
   # Assign default thresholds for DVARS, FD, and RMS.
   ###################################################################
   trep=$(exec_fsl fslval ${img} pixdim4)
   dv_thresh=1.5
   fd_thresh=$( arithmetic "0.167*${trep}")
   rms_thresh=$(arithmetic "0.083*${trep}")

   ###################################################################
   # Import thresholds from the processing stream.
   ###################################################################
   assign   dv_threshold[sub] \
       or   dv_thresh         \
       as   dv_thresh
   assign   fd_threshold[sub] \
       or   fd_thresh         \
       as   fd_thresh
   assign  rms_threshold[sub] \
       or  rms_thresh         \
       as  rms_thresh

   ###################################################################
   # Assemble the remaining arguments.
   ###################################################################
     if (( ${censor[sub]} == 1 )) 
      then
      subroutine                    @5.21  correct the rms and fd
      exec_xcp 1mask.R -i ${rel_rms[sub]} -m  ${tmask[sub]} -o ${intermediate}_rms1.1D
      exec_xcp 1mask.R -i ${fd[sub]} -m  ${tmask[sub]} -o ${intermediate}_fd.1D
      exec_xcp 1mask.R -i ${dvars[sub]} -m  ${tmask[sub]} -o ${intermediate}_dvar.1D

     else 
      exec_sys cp ${dvars[sub]} ${intermediate}_dvar.1D
      exec_sys cp ${fd[sub]} ${intermediate}_fd.1D
      exec_sys cp ${rel_rms[sub]} ${intermediate}_rms1.1D
    fi
   
    
   is_image ${intermediate}-dn-rs.nii.gz \
                                 && dn_arg=",${intermediate}-dn-rs.nii.gz"
   is_1D ${dvars[sub]}           &&  ts_1d="${ts_1d}DV:${intermediate}_dvar.1D:${dv_thresh},"
   is_1D ${rel_rms[sub]}         &&  ts_1d="${ts_1d}RMS:${intermediate}_rms1.1D:${rms_thresh},"
   is_1D ${fd[sub]}              &&  ts_1d="${ts_1d}FD:${intermediate}_fd.1D:${fd_thresh},"

   [[ -n ${qcfc_custom[cxt]} ]]  &&  ts_1d="${ts_1d}${qcfc_custom[cxt]},"

   [[ -n ${ts_1d} ]]             &&  ts_1d="-t ${ts_1d%,}"

   ###################################################################
   # . . . and create the plot.
   ###################################################################
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
fi




###################################################################
# Loss of temporal DOF
###################################################################

routine                       @4    Estimating loss of temporal degrees of freedom
unset    v  q
declare -A  q
for v in "${!qvars[@]}"
   do
   vn=${qvars[v]}
   q[${vn}]=${qvals[${v}]}
done
tDOF=0
exec_sys rm -f ${t_dof[cxt]}
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




###################################################################
# DVARS for denoised time series
###################################################################
if ! is_1D ${dvars_post[cxt]} \
|| rerun
   then
   routine                       @5    Estimating post-processing DVARS
   subroutine                    @5.1  [Computing DVARS]
   warpspace   ${referenceVolumeBrain[sub]}                \
               ${intermediate}-referenceVolumeBrain.nii.gz \
               ${space[sub]}:${dn_space[cxt]}
   (( ${demeaned[sub]} == 1 )) && dm="-d 1"

   exec_xcp dvars                \
      -i    ${denoised[sub]}     \
      -o    ${dvars_root[cxt]}   \
      -s    ${intermediate}      \
      ${dm}                      \
      -b    ${intermediate}-referenceVolumeBrain.nii.gz
    if (( ${censor[sub]} != 0 )) 
      then
      subroutine                    @5.21  correct the rms
      exec_xcp 1mask.R -i ${rel_rms[sub]} -m  ${tmask[sub]} -o ${intermediate}_rms.1D 
   else 
      exec_sys cp ${rel_rms[sub]} ${intermediate}_rms.1D
   fi

    exec_xcp featureCorrelation.R -i "${dvars_post[cxt]},${intermediate}_rms.1D" \
                                 >>  ${dv_mo_cor_post[cxt]}
   routine_end
fi





completion