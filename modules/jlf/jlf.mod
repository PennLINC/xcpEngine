#!/usr/bin/env bash

###################################################################
#   ⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗   #
###################################################################

###################################################################
# SPECIFIC MODULE HEADER
# This module uses joint label fusion (JLF) to generate an
# anatomical parcellation based on the openly available set of
# OASIS challenge labels (or a subset thereof).
###################################################################
mod_name_short=jlf
mod_name='JOINT LABEL FUSION MODULE'
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
   atlas             miccai

   assign image      labelsGMIntersect[cxt] \
       or            labels[cxt] \
       as            jlfLabels

   atlas_set         miccai Map        ${jlfLabels}
   atlas_set         miccai Space      ${structural[sub]}
   atlas_set         miccai Type       Map
   atlas_set         miccai NodeIndex  ${BRAINATLAS}/miccai/miccaiNodeIndex.1D
   atlas_set         miccai NodeNames  ${BRAINATLAS}/miccai/miccaiNodeNames.txt
   atlas_set         miccai Citation   ${BRAINATLAS}/miccai/miccaiReference.bib

   write_atlas

   source ${XCPEDIR}/core/auditComplete
   source ${XCPEDIR}/core/updateQuality
   source ${XCPEDIR}/core/moduleEnd
}





###################################################################
# OUTPUTS
###################################################################
derivative  intensity               ${prefix}_Intensity

output      labels                  ${prefix}_Labels.nii.gz
output      labelsGMIntersect       ${prefix}_LabelsGMIntersect.nii.gz

load_atlas  ${atlas[sub]}

<<DICTIONARY

intensity
   The weighted, fused intensity map of all images registered to
   the target space.
labels
   The anatomical parcellation directly produced as the output
   of the joint label fusion procedure.
labelsGMIntersect
   The JLF-derived parcellation after postprocessing, in the form
   of excising non-ventricular CSF fron the brain periphery.

DICTIONARY










###################################################################
# * Run ANTs JLF w/ OASIS label set
###################################################################
if ! is_image ${labels[cxt]} \
|| rerun
   then
   routine                    @1    ANTs Joint Label Fusion
   ################################################################
   # Now create and declare the call to run the JLF pipeline
   ################################################################
   subroutine                 @1.1  Cohort: ${jlf_cohort[cxt]}
   mapfile     oasis             < ${XCPEDIR}/thirdparty/oasis30/Cohorts/${jlf_cohort[cxt]}
   labelDir=${XCPEDIR}/thirdparty/oasis30/MICCAI2012ChallengeLabels/
   if (( ${jlf_extract[cxt]} == 1 ))
      then
      subroutine              @1.2  Using brains only
      brainDir=$XCPEDIR/thirdparty/oasis30/Brains/
   else
      subroutine              @1.3  Using whole heads
      brainDir=${XCPEDIR}/thirdparty/oasis30/Heads/
   fi

   subroutine                 @1.4  Assembling cohort
   unset jlfReg
   for o in ${oasis[@]}
     do
     jlfReg="${jlfReg} -g ${brainDir}${o}.nii.gz"
     jlfReg="${jlfReg} -l ${labelDir}${o}.nii.gz"
   done

   subroutine                 @1.5  Configuring parallelisation
   case ${jlf_parallel[cxt]} in
   sge)
      define jlf_parallel  1
      ;;
   pbs)
      define jlf_parallel  4
      ;;
   *)
      define jlf_parallel  0
   esac

   subroutine                 @1.6a Executing joint label fusion routine
   subroutine                 @1.6b Delegating control to antsJointLabelFusion
   export ANTSPATH=${ANTSPATH}/
   exec_ants   antsJointLabelFusion.sh \
      -d       3                       \
      -q       ${jlf_quick[cxt]}       \
      -f       0                       \
      -j       2                       \
      -k       ${jlf_keep_warps[cxt]}  \
      -t       ${img}                  \
      -o       ${outdir}/${prefix}_    \
      -c       ${jlf_parallel[cxt]}    \
      -x       or \
      ${jlfReg}

   routine_end
fi





###################################################################
# Now apply the intersection between the ANTsCT segmentation
# and the output of JLF if a brain segmentation image exists
###################################################################
if ! is_image ${labelsGMIntersect[cxt]}\
|| rerun
   then
   if is_image ${segmentation[sub]}
      then
      routine                 @2    Preparing grey matter intersection
      valsToBin='2:6'
      csfValsToBin='4,11,46,51,52'
      vdcValsToBin="61,62"
      subroutine              @2.1  Generating non-CSF mask
      exec_xcp val2mask.R                                \
         -i    ${segmentation[sub]}                      \
         -v    ${valsToBin}                              \
         -o    ${intermediate}-thresholdedImage.nii.gz
      subroutine              @2.2  Generating ventricular CSF mask
      exec_xcp val2mask.R                                \
         -i    ${labels[cxt]}                            \
         -v    ${csfValsToBin}                           \
         -o    ${intermediate}-binMaskCSF.nii.gz
      subroutine              @2.3  Generating ventral diencephalon mask
      exec_xcp val2mask.R                                \
         -i    ${labels[cxt]}                            \
         -v    ${vdcValsToBin}                           \
         -o    ${intermediate}-binMaskVD.nii.gz
      subroutine              @2.4  Dilating ventricular CSF mask
      exec_afni   3dmask_tool                            \
         -input   ${intermediate}-binMaskCSF.nii.gz      \
         -prefix  ${intermediate}-binMaskCSF_dil.nii.gz  \
         -dilate_input 2
      subroutine              @2.5  Union of vCSF, VDC, and non-CSF masks
      exec_fsl fslmaths ${intermediate}-thresholdedImage.nii.gz \
         -add  ${intermediate}-binMaskCSF_dil.nii.gz     \
         -add  ${intermediate}-binMaskVD.nii.gz          \
         -bin  ${intermediate}-thresholdedImage.nii.gz
      subroutine              @2.6  Excising extraventricular CSF from labels
      exec_fsl fslmaths ${intermediate}-thresholdedImage.nii.gz \
         -mul  ${labels[cxt]}                            \
         ${labelsGMIntersect[cxt]}
      routine_end
   fi
fi





completion
