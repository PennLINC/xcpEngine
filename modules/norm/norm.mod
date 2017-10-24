#!/usr/bin/env bash

###################################################################
#  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  #
###################################################################

###################################################################
# SPECIFIC MODULE HEADER
# This module normalises images and derivatives to an atlas.
###################################################################
mod_name_short=norm
mod_name='IMAGE NORMALISATION MODULE'
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
   set_space         ${standard}
   
   source ${XCPEDIR}/core/auditComplete
   source ${XCPEDIR}/core/updateQuality
   source ${XCPEDIR}/core/moduleEnd
}





###################################################################
# OUTPUTS
###################################################################
output      e2smask                 ${prefix}_seq2stdMask.nii.gz
qc norm_cross_corr normCrossCorr    ${prefix}_normCrossCorr.txt
qc norm_coverage   normCoverage     ${prefix}_normCoverage.txt
qc norm_jaccard    normJaccard      ${prefix}_normJaccard.txt
qc norm_dice       normDice         ${prefix}_normDice.txt

process     std                     ${prefix}_std

<< DICTIONARY

norm_coverage
   The percentage of the template image that is covered by the
   normalised analyte image.
norm_cross_corr
   The spatial cross-correlation between the template image mask
   and the normalised analyte mask.
norm_dice
   The Dice coefficient between template and analyte.
norm_jaccard
   The Jaccard coefficient between template and analyte.
std
   The analyte image, normalised to template space.

DICTIONARY










###################################################################
# Determine what program the user has specified for normalisation.
#  * At this point in time, only ANTs-based normalisation has been
#    tested, and the remaining options are no longer supported.
###################################################################
add_reference        template       template

routine                    @1    Normalising using ANTs
subroutine                 @1.1  [Selecting transforms to apply]
if ! is_image ${std[cxt]}  \
|| rerun
   then
   subroutine              @1.3  [Applying composite diffeomorphism to primary dataset]
   warpspace               \
      ${img}               \
      ${std[cxt]}          \
      ${space[sub]}:${standard}
fi
###################################################################
# Iterate through all derivative images, and apply the computed
# transforms to each.
###################################################################
load_derivatives
subroutine                 @1.4  [Applying composite diffeomorphism to derivative images:]
mv    ${aux_imgs[sub]}     \
      ${out}/${prefix}_derivatives-${space[sub]}.json
echo  '{}'     >>        ${aux_imgs[sub]}
for derivative in ${derivatives[@]}
   do
   derivative_parse        ${derivative}
   subroutine              @1.5  [${d[Name]}]
   d_call=${d[Name]}'['${cxt}']'
   ################################################################
   # If the image is a mask, apply nearest neighbour interpolation
   # to prevent introduction of intermediate values
   ################################################################
   unset interpol
   if contains ${d[Name]} '[Mm]ask'
      then
      subroutine           @1.6
      interpol=NearestNeighbor
   fi
   output                  ${d[Name]}     ${prefix}_${d[Name]}Std.nii.gz
   if ! is_image ${!d_call} \
      || rerun
      then
      subroutine           @1.7
      warpspace                  \
         ${d[Map]}               \
         ${outdir}/${prefix}_${d[Name]}Std.nii.gz \
         ${d[Space]}:${standard} \
         ${interpol}
   fi
   derivative_set       ${d[Name]} Map       ${outdir}/${prefix}_${d[Name]}Std.nii.gz
   derivative_set       ${d[Name]} Space     ${standard}
   write_derivative     ${d[Name]}
done
routine_end
###################################################################
# Prepare quality variables and a cross-sectional view for the
# reference volume
###################################################################
if is_image ${referenceVolumeBrain[cxt]} \
|| rerun
then
subroutine                 @2.0
if [[ ! -e ${outdir}/${prefix}_seq2std.png ]] \
|| rerun
   then
   routine                 @2    Quality assessment
   seq2std_mask=${intermediate}-seq2std_mask.nii.gz
   exec_fsl fslmaths ${referenceVolumeBrain[cxt]} -bin ${seq2std_mask}
   subroutine              @2.1  [Computing registration quality metrics]
   registration_quality=( $(exec_xcp \
      maskOverlap.R                  \
      -m ${seq2std_mask}             \
      -r ${template}) )
   echo  ${registration_quality[0]} > ${norm_cross_corr[cxt]}
   echo  ${registration_quality[1]} > ${norm_coverage[cxt]}
   echo  ${registration_quality[2]} > ${norm_jaccard[cxt]}
   echo  ${registration_quality[3]} > ${norm_dice[cxt]}
   subroutine              @2.2  [Preparing slicewise rendering]
   exec_xcp regslicer            \
      -s    ${referenceVolumeBrain[cxt]} \
      -t    ${template}          \
      -i    ${intermediate}      \
      -o    ${outdir}/${prefix}_seq2std
   routine_end
fi
fi





completion
