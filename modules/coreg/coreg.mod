#!/usr/bin/env bash

###################################################################
#  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  #
###################################################################

###################################################################
# SPECIFIC MODULE HEADER
# This module aligns the analyte image to a high-resolution target.
###################################################################
mod_name_short=coreg
mod_name='IMAGE COREGISTRATION MODULE'
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
   write_derivative  referenceVolume
   write_derivative  referenceVolumeBrain
   
   write_output      seq2struct
   write_output      struct2seq
   write_output      e2smat
   write_output      s2emat
   
   quality_metric    coregCoverage           coreg_coverage
   quality_metric    coregCrossCorr          coreg_cross_corr
   quality_metric    coregJaccard            coreg_jaccard
   quality_metric    coregDice               coreg_dice
   
   source ${XCPEDIR}/core/auditComplete
   source ${XCPEDIR}/core/updateQuality
   source ${XCPEDIR}/core/moduleEnd
}





###################################################################
# OUTPUTS
###################################################################
configure   fit                     0.3
configure   altreg1                 corratio
configure   altreg2                 mutualinfo
configure   qa_decide               1

derivative  referenceVolume         ${prefix}_referenceVolume
derivative  referenceVolumeBrain    ${prefix}_referenceVolumeBrain
derivative  e2simg                  ${prefix}_seq2struct
derivative  s2eimg                  ${prefix}_struct2seq
derivative  e2smask                 ${prefix}_seq2structMask
derivative  s2emask                 ${prefix}_struct2seqMask

output      seq2struct              ${prefix}_seq2struct.txt
output      struct2seq              ${prefix}_struct2seq.txt
output      e2smat                  ${prefix}_seq2struct.mat
output      s2emat                  ${prefix}_struct2seq.mat
output      coreg_cross_corr        ${prefix}_coregCrossCorr.txt
output      coreg_coverage          ${prefix}_coregCoverage.txt
output      coreg_jaccard           ${prefix}_coregJaccard.txt
output      coreg_dice              ${prefix}_coregDice.txt

<< DICTIONARY

altreg1
   First alternative cost function. If coregistration under the
   user-specified cost function fails to meet user quality
   criteria, then coregistration will be re-executed using this
   cost function.
altreg2
   Second alternative cost function. This will only be used
   instead of altreg1 if the user-specified cost function is the
   same as altreg1.
coreg_coverage
   The percentage of the structural image that is covered by
   the aligned analyte image.
coreg_cross_corr
   The spatial cross-correlation between the structural image
   mask and the aligned analyte mask.
coreg_dice
   The Dice coefficient between structural and aligned analyte.
coreg_jaccard
   The Jaccard coefficient between structural and aligned analyte.
e2simg
   The reference volume from the analyte sequence, aligned into
   structural space.
e2smask
   A binarised version of e2simg. Used to estimate the quality
   of coregistration.
e2smat
   The FSL-formatted affine transformation matrix containing a
   map from analyte space to structural space.
fit
   The fractional intensity threshold. Used only in the unlikely
   event that brain extraction has not already been run.
qa_decide
   In the event that the first round of coregistration fails to
   satisfy the user criteria, a second round will be performed.
   Only the coregistration that scores better according to the
   metric defined in this variable will be retained.
   (0 = cross-correlation, 1 = coverage, 2 = jaccard, 3 = dice)
referenceVolume
   An exemplar volume from the subject's 4D timeseries that is
   used to compute the coregistration. If this has already been
   defined by a previous module, it will instead be symbolically
   linked.
referenceVolumeBrain
   The brain-extracted version of the subject's reference volume;
   this will probably already have been obtained in prestats.
s2eimg
   The subject's structural image, aligned into analyte space.
s2emask
   A binarised version of s2eimg. Used to estimate the quality
   of coregistration.
s2emat
   The FSL-formatted affine transformation matrix containing a
   map from structural space to analyte space.
seq2struct
   Affine coregistration whose application to the subject's
   reference volume will output a reference volume that is
   aligned with the subject's structural acquisition.
struct2seq
   Affine coregistration whose application to the subject's
   structural image will output a structural image that is
   aligned with the subject's reference acquisition.
   
DICTIONARY










###################################################################
# Coregistration is computed using a source reference volume
# and using the subject's structural scan as a target. Here,
# the source reference volume is an example volume,
# typically selected as the reference during the motion
# realignment phase of analysis.
#
# Before coregistration can be performed, the coregistration
# module must obtain a pointer to this source volume.
###################################################################
routine                       @1    Identifying reference volume
###################################################################
# Determine whether a brain-extracted version of the source
# reference volume already exists.
###################################################################
if is_image ${referenceVolumeBrain[${subjidx}]}
   then
   subroutine                 @1.1  [Existing reference image recognised]
   configure  referenceVolumeBrain  ${referenceVolumeBrain[${subjidx}]}
else
   if ! is_image ${referenceVolume[${subjidx}]}
      then
      #############################################################
      # * If the source volume does not exist, this reflects an
      #   unconventional decision in the pipeline, since motion
      #   realignment should always create a source volume.
      # * If this is the case, the coregistration module will
      #   generate a new source volume. Be advised that this
      #   might lead to unexpected or catastrophic results if, for
      #   instance, the primary BOLD timeseries has been demeaned.
      #############################################################
      subroutine              @1.2a XCP-WARNING: No reference volume detected. This
      subroutine              @1.2b probably means that you are doing something
      subroutine              @1.2c unconventional, like computing coregistration prior
      subroutine              @1.2d to alignment of volumes. You are advised to inspect
      subroutine              @1.2e your pipeline to ensure that this is intentional.
      subroutine              @1.2f Preparing reference volume
      nvol=$(exec_fsl fslnvols ${img})
      midpt=$(arithmetic ${nvol}/2)
      exec_fsl \
         fslroi ${out}/${prefix}.nii.gz \
         ${referenceVolume[${cxt}]} ${midpt} 1
   fi
   if ! is_image ${referenceVolumeBrain[${cxt}]} \
   || rerun
      then
      #############################################################
      # * If the source volume exists but brain extraction has
      #   not yet been performed, then the coregistration module
      #   will automatically identify and isolate brain tissue in
      #   the reference volume using BET.
      #############################################################
      subroutine              @1.3a No brain-extracted reference volume detected.
      subroutine              @1.3b Extracting brain from reference volume
      exec_fsl bet ${referenceVolume[${subjidx}]} \
         ${referenceVolumeBrain[${cxt}]} \
         -f $fit[${cxt}]
   fi
fi
routine_end





###################################################################
# If BBR is the cost function being used, a white matter mask
# must be extracted from the user-specified tissue segmentation.
###################################################################
if [[ ${coreg_cfunc[${cxt}]} == bbr ]]; then
if [[ ! -e ${e2smat[${cxt}]} ]] \
|| rerun
   then
   wm_mask=${intermediate}_t1wm.nii.gz
   if ! is_image ${wm_mask} \
   || rerun
      then
      routine                 @2    Preparing white matter mask
      case ${coreg_wm[${cxt}]} in
      all)
         subroutine           @2.1a All nonzero voxels correspond to white matter.
         subroutine           @2.1b Binarising image
         exec_fsl fslmaths ${coreg_seg[${cxt}]} -bin ${wm_mask}
         ;;
      *)
         subroutine           @2.2a [Voxels with value ${coreg_wm[${cxt}]} correspond to white matter]
         subroutine           @2.2b [Thresholding out all other voxels and binarising image]
         exec_xcp \
            val2mask.R \
            -i ${coreg_seg[${cxt}]} \
            -v ${coreg_wm[${cxt}]} \
            -o ${wm_mask}
         ;;
      esac
      routine_end
   fi
   ################################################################
   # Prime an additional input argument to FLIRT, containing
   # the path to the new mask.
   ################################################################
   wm_mask_cmd="-wmseg ${wm_mask}"
fi; fi





###################################################################
# Determine whether the user has specified weights for the cost
# function, and set up the coregistration to factor them into its
# optimisiation if they are specified.
#
# * refwt : weights in the reference/target/structural space
# * inwt : weights in the input/registrand/analyte space
###################################################################
routine                       @3    Obtaining voxelwise weights
if is_image ${coreg_refwt[${cxt}]}
   then
   subroutine                 @3.1  Reading structural weights
   refwt="-refweight ${coreg_refwt[${cxt}]}"
else
   subroutine                 @3.2  [Structural: all voxels weighted uniformly]
   unset refwt
fi
if is_image ${coreg_inwt[${cxt}]}
   then
   subroutine                 @3.3  Reading input weights
   inwt="-inweight ${coreg_inwt[${cxt}]}"
else
   subroutine                 @3.4  [Input: all voxels weighted uniformly]
   unset inwt
fi
routine_end





###################################################################
# Perform the affine coregistration using FLIRT and user
# specifications.
###################################################################
routine                       @4    Executing affine coregistration
if [[ ! -e ${e2smat[${cxt}]} ]] \
|| rerun
   then
   subroutine                 @4.1a [Cost function]
   subroutine                 @4.1b [${coreg_cfunc[${cxt}]}]
   subroutine                 @4.1c [Input volume]
   subroutine                 @4.1d [${referenceVolumeBrain[${cxt}]}]
   subroutine                 @4.1e [Reference volume]
   subroutine                 @4.1f [${struct[${subjidx}]}]
   subroutine                 @4.1g [Output volume]
   subroutine                 @4.1h [${e2simg[${cxt}]}]
   exec_fsl flirt -in ${referenceVolumeBrain[${cxt}]} \
      -ref  ${struct[${subjidx}]} \
      -dof  6 \
      -out  ${e2simg[${cxt}]} \
      -omat ${e2smat[${cxt}]} \
      -cost ${coreg_cfunc[${cxt}]} \
      ${refwt} \
      ${inwt} \
      ${wm_mask_cmd}
else
   subroutine                 @4.2  [Coregistration already run]
fi
routine_end





###################################################################
# Compute metrics of coregistration quality.
###################################################################
flag=0
if [[ ! -e ${quality[${cxt}]} ]] \
|| rerun \
|| [[ $(tail -n1 ${quality[${cxt}]}) == ',' ]]
   then
   routine                    @5    Quality assessment
   subroutine                 @5.1
   exec_fsl fslmaths ${e2simg[${cxt}]} -bin ${e2smask[${cxt}]}
   registration_quality=( $(exec_xcp \
      maskOverlap.R \
      -m ${e2smask[${cxt}]} \
      -r ${struct[${subjidx}]}) )
   echo  ${registration_quality[0]} > ${coreg_cross_corr[${cxt}]}
   echo  ${registration_quality[1]} > ${coreg_coverage[${cxt}]}
   echo  ${registration_quality[2]} > ${coreg_jaccard[${cxt}]}
   echo  ${registration_quality[3]} > ${coreg_dice[${cxt}]}
   ################################################################
   # If the subject fails quality control, then repeat
   # coregistration using an alternative metric: crosscorrelation.
   # Unless crosscorrelation has been specified and failed, in
   # which case mutual information is used instead.
   #
   # Determine whether each quality index warrants flagging the
   # coregistration for poor quality.
   ################################################################
   cc_min=$(strslice   ${coreg_qacut[${cxt}]} 1)
   co_min=$(strslice   ${coreg_qacut[${cxt}]} 2)
   cc_flag=$(arithmetic ${registration_quality[0]}'<'${cc_min})
   co_flag=$(arithmetic ${registration_quality[1]}'<'${co_min})
   if (( ${cc_flag} == 1 )) \
   && is+numeric ${cc_min}
      then
      subroutine              @5.2  [Cross-correlation flagged]
      flag=1
   fi
   if (( ${co_flag} == 1 )) \
   && is+numeric ${co_min}
      then
      subroutine              @5.3  [Coverage flagged]
      flag=1
   fi
   if (( ${flag} != 1 ))
      then
      subroutine              @5.4  [Coregistration quality meets standards]
   fi
   routine_end
fi





###################################################################
# If coregistration was flagged for poor quality, repeat it.
###################################################################
if (( ${flag} == 1 ))
   then
   routine                    @6    Retrying flagged coregistration
   subroutine                 @6.1  [Coregistration was flagged using previous cost function]
   ################################################################
   # First, determine what cost function to use.
   ################################################################
   if [[ ${coreg_cfunc[${cxt}]} == ${altreg1[${cxt}]} ]]
      then
      subroutine              @6.2
      configure               coreg_cfunc  ${altreg2[${cxt}]}
   else
      subroutine              @6.3
      configure               coreg_cfunc  ${altreg1[${cxt}]}
   fi
   subroutine                 @6.4a [Coregistration will be repeated using cost ${coreg_cfunc[${cxt}]}]
   subroutine                 @6.4 
   ################################################################
   # Re-compute coregistration.
   ################################################################
   exec_fsl \
      flirt -in ${referenceVolumeBrain[${cxt}]} \
      -ref ${struct[${subjidx}]} \
      -dof 6 \
      -out ${intermediate}_seq2struct_alt \
      -omat ${intermediate}_seq2struct_alt.mat \
      -cost ${coreg_cfunc[${cxt}]} \
      ${refwt} \
      ${inwt}
   ################################################################
   # Compute the quality metrics for the new registration.
   ################################################################
   exec_fsl \
      fslmaths ${intermediate}_seq2struct_alt.nii.gz \
      -bin ${intermediate}_seq2struct_alt_mask.nii.gz
   registration_quality_alt=( $(exec_xcp \
      maskOverlap.R \
      -m ${intermediate}_seq2struct_alt_mask.nii.gz \
      -r ${struct[${subjidx}]}) )
   ################################################################
   # Compare the metrics to the old ones. The decision is made
   # based on the QADECIDE constant if coregistration is repeated
   # due to failing quality control.
   ################################################################
   decision=$(arithmetic ${registration_quality_alt[${qa_decide}]}'>'${registration_quality[${qa_decide}]})
   if (( ${decision} == 1 ))
      then
      subroutine              @6.5a [The coregistration result improved. However, you]
      subroutine              @6.5b [are encouraged to verify the results]
      exec_sys mv ${intermediate}_seq2struct_alt.mat ${e2smat[${cxt}]}
      exec_fsl immv ${intermediate}_seq2struct_alt ${e2simg[${cxt}]}
      exec_fsl immv ${intermediate}_seq2struct_alt_mask ${e2smask[${cxt}]}
      exec_sys rm -f ${s2emat[${cxt}]}
      exec_sys rm -f ${seq2struct[${cxt}]}
      exec_sys rm -f ${struct2seq[${cxt}]}
      exec_sys rm -f ${s2eimg[${cxt}]}
      exec_sys rm -f ${coreg_cross_corr[${cxt}]}
      exec_sys rm -f ${coreg_coverage[${cxt}]}
      exec_sys rm -f ${coreg_jaccard[${cxt}]}
      exec_sys rm -f ${coreg_dice[${cxt}]}
      echo     ${registration_quality_alt[0]} >> ${coreg_cross_corr[${cxt}]}
      echo     ${registration_quality_alt[1]} >> ${coreg_coverage[${cxt}]}
      echo     ${registration_quality_alt[2]} >> ${coreg_jaccard[${cxt}]}
      echo     ${registration_quality_alt[3]} >> ${coreg_dice[${cxt}]}
      write_config            coreg_cfunc
   else
      subroutine              @6.6a [Coregistration failed to improve. This may be]
      subroutine              @6.6b [attributable to incomplete acquisition coverage]
   fi
   routine_end
fi





###################################################################
# Prepare slice graphics as an additional assessor of
# coregistration quality.
###################################################################
routine                       @7    Coregistration visual aids
subroutine                    @7.1  [Slicewise rendering]
add_reference   struct[${subjidx}]  ${prefix}_targetVolume
exec_xcp \
   regslicer \
   -s ${e2simg[${cxt}]} \
   -t ${struct[${subjidx}]} \
   -i ${intermediate} \
   -o ${outdir}/${prefix}_seq2struct
routine_end





###################################################################
# Use the forward transformation to compute the reverse
# transformation. This is critical for moving (inter alia)
# standard-space network maps and RoI coordinates into
# the subject's native analyte space, allowing for accelerated
# pipelines and reduced disk usage.
###################################################################
routine                       @8    Derivative transformations
if [[ ! -e ${s2emat[${cxt}]} ]] \
|| rerun
   then
   subroutine                 @8.1  [Computing inverse transformation]
   exec_fsl \
      convert_xfm \
      -omat ${s2emat[${cxt}]} \
      -inverse ${e2smat[${cxt}]}
fi
###################################################################
# The XCP Engine uses ANTs-based registration; the
# coregistration module uses an ITK-based helper script to 
# convert the FSL output into a format that can be read by ANTs.
###################################################################
if [[ ! -e ${seq2struct[${cxt}]} ]] \
|| rerun
   then
   subroutine                 @8.2  [Converting coregistration .mat to ANTs format]
   exec_c3d \
      c3d_affine_tool \
      -src ${referenceVolumeBrain[${cxt}]} \
      -ref ${struct[${subjidx}]} \
      ${e2smat[${cxt}]} \
      -fsl2ras \
      -oitk ${seq2struct[${cxt}]}
fi
###################################################################
# The XCP Engine uses ANTs-based registration; the
# coregistration module uses an ITK-based helper script to 
# convert the FSL output into a format that can be read by ANTs.
###################################################################
if [[ ! -e ${struct2seq[${cxt}]} ]] \
|| rerun
   then
   subroutine                 @8.3  [Converting inverse coregistration .mat to ANTs format]
   exec_c3d \
      c3d_affine_tool \
      -src ${struct[${subjidx}]} \
      -ref ${referenceVolumeBrain[${cxt}]} \
      ${s2emat[${cxt}]} \
      -fsl2ras \
      -oitk ${struct2seq[${cxt}]}
fi
###################################################################
# Compute the structural image in analytic space, and generate
# a mask for that image.
###################################################################
if [[ ! -e ${s2emask[${cxt}]} ]] \
|| rerun
   then
   subroutine                 @8.4  [Preparing inverse mask]
   exec_ants \
      antsApplyTransforms \
      -e 3 -d 3 \
      -r ${referenceVolumeBrain[${subjidx}]} \
      -o ${s2eimg[${cxt}]} \
      -i ${struct[${subjidx}]} \
      -t ${struct2seq[${cxt}]}
   exec_fsl fslmaths ${s2eimg[${cxt}]} -bin ${s2emask[${cxt}]}
fi
routine_end





subroutine                    @0.1
completion
