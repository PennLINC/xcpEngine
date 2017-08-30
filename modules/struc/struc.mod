#!/usr/bin/env bash

###################################################################
#   ✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡   #
###################################################################

###################################################################
# SPECIFIC MODULE HEADER
# This module performs basic structural data processing.
###################################################################
mod_name_short=struc
mod_name='STRUCTURAL PROCESSING MODULE'
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
   processed         struct
   
   write_derivative  mask
   write_derivative  segmentation
   write_derivative  biasCorrected
   write_derivative  corticalThickness
   write_derivative  corticalContrast
   
   write_output      meanIntensity
   write_output      meanIntensityBrain
   write_output      referenceVolume
   write_output      referenceVolumeBrain
   
   if is_image ${referenceVolumeBrain[cxt]}
      then
      space_config   ${spaces[sub]}   ${space[sub]} \
               Map   ${referenceVolumeBrain[cxt]}
   fi
   
   exec_xcp spaceMetadata \
      -o    ${spaces[sub]} \
      -f    ${standard}:${template} \
      -m    ${space[sub]}:${struct[cxt]} \
      -x    ${xfm_affine[cxt]},${xfm_warp[cxt]} \
      -i    ${ixfm_warp[cxt]},${ixfm_affine[cxt]} \
      -s    ${spaces[sub]}
   
   quality_metric    regCoverage            reg_coverage
   quality_metric    regCrossCorr           reg_cross_corr
   quality_metric    regJaccard             reg_jaccard
   quality_metric    regDice                reg_dice
   
   source ${XCPEDIR}/core/auditComplete
   source ${XCPEDIR}/core/updateQuality
   source ${XCPEDIR}/core/moduleEnd
}





###################################################################
# OUTPUTS
###################################################################
derivative  biasCorrected           ${prefix}_BrainSegmentation0N4
derivative  corticalThickness       ${prefix}_CorticalThickness
derivative  corticalContrast        ${prefix}_CorticalContrast
derivative  mask                    ${prefix}_BrainExtractionMask
derivative  segmentation            ${prefix}_BrainSegmentation
for i in {1..6}
   do
   derivative  segmentationPosteriors  ${prefix}_BrainSegmentationPosteriors${i}
done

derivative_config    corticalThickness        Statistic        mean
derivative_config    corticalContrast         Statistic        mean

output      brain_std               ${prefix}_BrainNormalizedToTemplate.nii.gz
output      corticalThickness_std   ${prefix}_CorticalThicknessNormalizedToTemplate.nii.gz
output      ctroot                  ${prefix}_
output      referenceVolume         ${prefix}_BrainSegmentation0N4.nii.gz
output      referenceVolumeBrain    ${prefix}_ExtractedBrain0N4.nii.gz
output      meanIntensity           ${prefix}_BrainSegmentation0N4.nii.gz
output      meanIntensityBrain      ${prefix}_ExtractedBrain0N4.nii.gz
output      reg_cross_corr          ${prefix}_regCrossCorr.txt
output      reg_coverage            ${prefix}_regCoverage.txt
output      reg_jaccard             ${prefix}_regJaccard.txt
output      reg_dice                ${prefix}_regDice.txt

output      xfm_affine              ${prefix}_SubjectToTemplate0GenericAffine.mat
output      xfm_warp                ${prefix}_SubjectToTemplate1Warp.nii.gz
output      ixfm_affine             ${prefix}_TemplateToSubject1GenericAffine.mat
output      ixfm_warp               ${prefix}_TemplateToSubject0Warp.nii.gz

final       struct                  ${prefix}_ExtractedBrain0N4

<< DICTIONARY

biasCorrected
   The bias field-corrected image, used for segmentation into
   tissue classes.
corticalContrast
   The voxelwise map of cortical contrast values.
corticalThickness
   The voxelwise map of cortical thickness values.
corticalThickness_std
   The voxelwise map of cortical thickness values following
   normalisation.
ctroot
   The base name of the path for all outputs of the ANTs Cortical
   Thickness pipeline.
ixfm_affine
   A matrix that defines an affine transformation from standard
   space to anatomical space.
ixfm_warp
   A distortion field that defines a nonlinear diffeomorphic warp
   from standard space to anatomical space.
mask
   A spatial mask of binary values, indicating whether a voxel
   should be analysed as part of the brain. This is the output of
   the skull-strip/brain extraction procedure.
meanIntensity,meanIntensityBrain
   For compatibility exporting to other modules.
referenceVolume,referenceVolumeBrain
   For compatibility exporting to other modules.
reg_coverage
   The percentage of the template image that is covered by the
   normalised anatomical image.
reg_cross_corr
   The spatial cross-correlation between the template image mask
   and the normalised anatomical mask.
reg_dice
   The Dice coefficient between the template and anatomical image.
reg_jaccard
   The Jaccard coefficient between the template and anatomical
   image.
segmentation
   The deterministic (hard) segmentation of the brain into tissue
   classes.
segmentationPosteriors
   Probabilistic (soft) maps specifying for each voxel the
   estimated probability that the voxel belongs to each tissue
   class.
struct
   The fully processed (bias-field corrected and skull-stripped)
   brain in native anatomical space.
struct_std
   The subject's brain following normalisation to a standard or
   template space. This should not be processed as a derivative.
xfm_affine
   A matrix that defines an affine transformation from anatomical
   space to standard space.
xfm_warp
   A distortion field that defines a nonlinear diffeomorphic warp
   from anatomical space to standard space.
   
DICTIONARY










###################################################################
# The variable 'buffer' stores the processing steps that are
# already complete; it becomes the expected ending for the final
# image name and is used to verify that prestats has completed
# successfully.
###################################################################
unset buffer

subroutine                    @0.1

###################################################################
# Parse the control sequence to determine what routine to run next.
# Available routines include:
#  * ACT: ANTs CT pipeline. This routine subsumes all others.
#  * ABF: ANTs N4 bias field correction
#  * ABE: ANTs Brain Extraction
#  * SEG: ANTs prior-driven brain segmentation
#  * REG: ANTs registration
#  * FBE: FSL Brain Extraction using BET
###################################################################
rem=${struc_process[cxt]}
while (( ${#rem} > 0 ))
   do
   ################################################################
   # * Extract the three-letter routine code from the user-
   #   specified control sequence.
   # * This three-letter code determines what routine is run next.
   # * Remove the code from the remaining control sequence.
   ################################################################
   cur=${rem:0:3}
   rem=${rem:4:${#rem}}
   buffer=${buffer}_${cur}
   case ${cur} in





   ACT)
      #############################################################
      # ACT runs the complete ANTs cortical thickness pipeline.
      #############################################################
      routine                 @1    ANTs cortical thickness pipeline
      subroutine              @1.1a Input: ${intermediate}.nii.gz
      subroutine              @1.1b Template: ${template}
      subroutine              @1.1c Output root: ${ctroot[cxt]}
      subroutine              @1.x  Delegating control to ANTsCT
      exec_ants   antsCorticalThickness.sh \
         -d       3 \
         -a       ${intermediate}.nii.gz \
         -e       ${struc_templateHead[cxt]} \
         -m       ${struc_templateMask[cxt]} \
         -f       ${struc_templateMaskDil[cxt]} \
         -p       ${struc_templatePriors[cxt]} \
         -w       ${struc_extractionPrior[cxt]} \
         -t       ${template} \
         -o       ${ctroot[cxt]}
      exec_sys ln -sf ${struct[cxt]} ${intermediate}_${cur}.nii.gz
      intermediate=${intermediate}_${cur}
      routine_end
      ;;





   ABF)
      #############################################################
      # ABF runs ANTs bias field correction.
      #############################################################
      routine                 @2    ANTs N4 bias field correction
      exec_ants   N4BiasFieldCorrection \
         -d       3 \
         -i       ${intermediate}.nii.gz \
         -c       ${struc_N4convergence[cxt]} \
         -s       ${struc_N4shrinkFactor[cxt]} \
         -b       ${struc_N4bsplineParams[cxt]} \
         -o       ${biasCorrected[cxt]} \
         --verbose 1
      exec_sys ln -sf ${biasCorrected[cxt]} ${intermediate}_${cur}.nii.gz
      intermediate=${intermediate}_${cur}
      routine_end
      ;;





   ABE)
      #############################################################
      # ABE runs ANTs brain extraction
      #############################################################
      routine                 @3    ANTs brain extraction
      exec_ants   antsBrainExtraction.sh \
         -d       3 \
         -a       ${intermediate}.nii.gz \
         -e       ${template} \
         ${struc_extractionPrior[cxt]} \
         ${struc_keepBEImages[cxt]} \
         ${struc_useBEFloat[cxt]} \
         ${struc_useBERandomSeed[cxt]} \
         -o ${ctroot[cxt]}
      exec_sys ln -s ${outdir}/${prefix}_BrainExtractionBrain.nii.gz \
                     ${intermediate}_${cur}.nii.gz
      intermediate=${intermediate}_${cur}
      routine_end
      ;;





   FBE)
      #############################################################
      # FBE runs FSL brain extraction via BET
      #############################################################
      exec_fsl bet \
         ${intermediate}.nii.gz \
         ${intermediate}_${cur}.nii.gz \
         -f    ${struc_fit[${cxt}]} \
         -m
	   exec_fsl immv  ${intermediate}_${cur}.nii.gz \
	                  ${outdir}/${prefix}_BrainExtractionBrain.nii.gz
	   exec_fsl immv  ${intermediate}_${cur}_mask.nii.gz \
	                  ${outdir}/${prefix}_BrainExtractionMask.nii.gz
      exec_sys ln -s ${outdir}/${prefix}_BrainExtractionBrain.nii.gz \
                     ${intermediate}_${cur}.nii.gz
      intermediate=${intermediate}_${cur}
      routine_end
      ;;





   CCC)
      #############################################################
      # CCC runs cortical contrast analysis
      #############################################################
      
      #############################################################
      # First, prepare the binarised mask indicating the GM-WM
      # interface.
      #############################################################
      exec_afni   3dresample \
         -dxyz    .25 .25 .25 \
         -inset   ${segmentation[cxt]}.nii.gz \
         -prefix  ${intermediate}-upsample.nii.gz
      exec_fsl    fslmaths ${intermediate}_${cur}-upsample.nii.gz \
         -thr     3 \
         -uthr    3 \
         -edge \
         -uthr    1 \
         -bin \
         ${intermediate}_${cur}-upsample-edge.nii.gz
      exec_ants   ImageMath 3 ${intermediate}_${cur}-dist-from-edge.nii.gz \
         MaurerDistance ${intermediate}_${cur}-upsample-edge.nii.gz 1
      exec_fsl    fslmaths ${intermediate}_${cur}-dist-from-edge.nii.gz \
         -thr     .75 \
         -uthr    1.25 \
         -bin \
         ${intermediate}_${cur}-dist-from-edge-bin.nii.gz
      #############################################################
      # Next, prepare the WM and GM masks.
      #############################################################
      declare           -A tissue_classes
      tissue_classes=(  [gm]="grey matter"
                        [wm]="white matter" )
      for class in "${!tissue_classes[@]}"
         do
         class_val='struc_'${class}'_val['${cxt}']'
         exec_fsl    fslmaths ${intermediate}-upsample.nii.gz \
            -thr     ${!class_val} \
            -uthr    ${!class_val} \
            -mul     ${intermediate}_${cur}-dist-from-edge-bin.nii.gz \
            -bin \
            ${intermediate}_${cur}-dist-from-edge-${class}.nii.gz
         exec_ants   antsApplyTransforms -e 3 -d 3 \
            -i       ${intermediate}_${cur}-dist-from-edge-${class}.nii.gz \
		      -o       ${intermediate}_${cur}-ds-dist-from-edge-${class}.nii.gz \
		      -r       ${brainSegmentation[${cxt}]}.nii.gz \
		      -n       Gaussian
		   exec_fsl    fslmaths ${intermediate}_${cur}-ds-dist-from-edge-${class}.nii.gz \
		      -thr     .05 \
		      -bin \
		      ${intermediate}_${cur}-ds-dist-from-edge-${class}-bin.nii.gz
		done
      #############################################################
      # Compute cortical contrast.
      #############################################################
      exec_xcp cortCon.R \
         -w    ${intermediate}_${cur}-ds-dist-from-edge-gm-bin.nii.gz \
         -g    ${intermediate}_${cur}-ds-dist-from-edge-wm-bin.nii.gz \
         -T    ${struct[cxt]} \
         -o    ${cortConVals[${cxt}]}
      exec_sys ln -s ${intermediate}.nii.gz \
                     ${intermediate}_${cur}.nii.gz
      intermediate=${intermediate}_${cur}
      routine_end
      ;;
         
   esac
done





###################################################################
# Prepare quality variables and a cross-sectional view for the
# normalised brain
###################################################################
if [[ ! -e ${outdir}/${prefix}_str2std.png ]] \
|| rerun
   then
   routine                 @2    Quality assessment
   exec_fsl fslmaths ${struct_std[cxt]} -bin ${str2stdmask[cxt]}
   subroutine              @2.1  [Computing registration quality metrics]
   registration_quality=( $(exec_xcp \
      maskOverlap.R \
      -m ${mask[cxt]} \
      -r ${template}) )
   echo  ${registration_quality[0]} > ${struc_cross_corr[cxt]}
   echo  ${registration_quality[1]} > ${struc_coverage[cxt]}
   echo  ${registration_quality[2]} > ${struc_jaccard[cxt]}
   echo  ${registration_quality[3]} > ${struc_dice[cxt]}
   subroutine              @2.2  [Preparing slicewise rendering]
   exec_xcp regslicer \
      -s ${struct_std[cxt]} \
      -t ${template} \
      -i ${intermediate_root} \
      -o ${outdir}/${prefix}_str2std
   routine_end
fi





###################################################################
# CLEANUP
#  * Add the space definitions.
#  * Test for the expected output. This should be the initial
#    image name with any routine suffixes appended.
#  * If the expected output is present, move it to the target path.
#  * If the expected output is absent, notify the user.
###################################################################
if is_image ${intermediate_root}${buffer}.nii.gz
   then
   subroutine                 @0.2
   processed=$(readlink -f    ${intermediate}.nii.gz)
   exec_fsl immv ${processed} ${preprocessed[cxt]}
   completion
else
   subroutine                 @0.3
   echo \
   "


XCP-ERROR: Expected output not present.
Expected: ${prefix}${buffer}
Check the log to verify that processing
completed as intended.
"
   exit 1
fi





completion
