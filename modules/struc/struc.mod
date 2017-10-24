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
   if is_image ${referenceVolumeBrain[cxt]}
      then
      space_set   ${spaces[sub]}   ${space[sub]} \
            Map   ${referenceVolumeBrain[cxt]}
   fi
   
   exec_xcp spaceMetadata \
      -o    ${spaces[sub]} \
      -f    ${standard}:${template} \
      -m    ${space[sub]}:${struct[cxt]} \
      -x    ${xfm_affine[cxt]},${xfm_warp[cxt]} \
      -i    ${ixfm_warp[cxt]},${ixfm_affine[cxt]} \
      -s    ${spaces[sub]}
   
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

derivative_set corticalThickness    Statistic        mean
derivative_set corticalContrast     Statistic        mean

output      struct_std              ${prefix}_BrainNormalizedToTemplate.nii.gz
output      corticalThickness_std   ${prefix}_CorticalThicknessNormalizedToTemplate.nii.gz
output      ctroot                  ${prefix}_
output      referenceVolume         ${prefix}_BrainSegmentation0N4.nii.gz
output      referenceVolumeBrain    ${prefix}_ExtractedBrain0N4.nii.gz
output      meanIntensity           ${prefix}_BrainSegmentation0N4.nii.gz
output      meanIntensityBrain      ${prefix}_ExtractedBrain0N4.nii.gz
output      str2stdmask             ${prefix}_str2stdmask.nii.gz

qc reg_cross_corr regCrossCorr      ${prefix}_regCrossCorr.txt
qc reg_coverage   regCoverage       ${prefix}_regCoverage.txt
qc reg_jaccard    regJaccard        ${prefix}_regJaccard.txt
qc reg_dice       regDice           ${prefix}_regDice.txt

output      xfm_affine              ${prefix}_SubjectToTemplate0GenericAffine.mat
output      xfm_warp                ${prefix}_SubjectToTemplate1Warp.nii.gz
output      ixfm_affine             ${prefix}_TemplateToSubject1GenericAffine.mat
output      ixfm_warp               ${prefix}_TemplateToSubject0Warp.nii.gz

input image mask
input image segmentation

add_reference                       template template

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










priors_format=${struc_template_priors[cxt]#*\%}
priors_format=${priors_format%%d*}
#(( ${trace} > 1 )) && ants_verbose=1 || ants_verbose=0
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
#  * N4B: ANTs N4 bias field correction
#  * ABE: ANTs Brain Extraction (subsumes N4)
#  * DCT: DireCT cortical thickness computation
#  * SEG: ANTs prior-driven brain segmentation implemented in
#         Atropos (subsumes a round of N4)
#  * FST: FSL 3-class brain segmentation using FAST
#  * REG: ANTs registration
#  * FBE: FSL brain extraction using BET
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
      exec_ants   antsCorticalThickness.sh         \
         -d       3                                \
         -a       ${intermediate}.nii.gz           \
         -e       ${struc_template_head[cxt]}      \
         -m       ${struc_template_mask[cxt]}      \
         -p       ${struc_template_priors[cxt]}    \
         -o       ${ctroot[cxt]}                   \
         -s       'nii.gz'                         \
         -t       ${template}                      \
         -f       ${struc_template_mask_dil[cxt]}  \
         -g       ${struc_denoise_anat[cxt]}       \
         -w       ${struc_prior_weight[cxt]}       \
         -b       ${struc_posterior_formulation[cxt]} \
         -j       ${struc_floating_point[cxt]}     \
         -u       ${struc_random_seed[cxt]}        \
         -v       ${struc_bspline[cxt]}            \
         ${additional_images} \
         ${label_propagation}
      exec_sys ln -sf ${struct[cxt]} ${intermediate}_${cur}.nii.gz
      intermediate=${intermediate}_${cur}
      routine_end
      ;;





   BFC)
      #############################################################
      # BFC runs ANTs bias field correction.
      #############################################################
      routine                 @2    ANTs N4 bias field correction
      if ! is_image ${biasCorrected[cxt]} \
      || rerun
         then
         subroutine           @2.1a Correcting inhomogeneities
         subroutine           @2.1b Delegating control to N4BiasFieldCorrection
         exec_ants   N4BiasFieldCorrection            \
            -d       3                                \
            -i       ${intermediate}.nii.gz           \
            -o       ${biasCorrected[cxt]}            \
            --verbose 1
      else
         subroutine           @2.2  Bias field correction already complete
      fi
      exec_sys ln -sf ${biasCorrected[cxt]} ${intermediate}_${cur}.nii.gz
      intermediate=${intermediate}_${cur}
      routine_end
      ;;





   ABE)
      #############################################################
      # ABE runs ANTs brain extraction
      #############################################################
      routine                 @3    ANTs brain extraction
      if ! is_image ${mask[cxt]}
         then
         [[ -d ${scratch} ]]  && pushd ${scratch} >/dev/null
         subroutine           @3.1a Computing brain boundaries
         subroutine           @3.1b Input: ${intermediate}.nii.gz
         subroutine           @3.1c Output: ${intermediate}_${cur}
         subroutine           @3.1d Delegating control to antsBrainExtraction
         exec_ants   antsBrainExtraction.sh           \
            -d       3                                \
            -a       ${intermediate}.nii.gz           \
            -e       ${template}                      \
            -f       ${struc_template_mask_dil[cxt]}  \
            -m       ${struc_extraction_prior[cxt]}   \
            -q       ${struc_floating_point[cxt]}     \
            -u       ${struc_random_seed[cxt]}        \
            -s       'nii.gz'                         \
            -o       ${intermediate}_${cur}_
         [[ -d ${scratch} ]]  && popd >/dev/null
         exec_fsl immv  ${intermediate}_${cur}_BrainExtractionMask.nii.gz \
                        ${mask[cxt]}
         exec_sys mv -f ${intermediate}_${cur}_BrainExtractionPrior0GenericAffine.mat \
                        ${outdir}/${prefix}_BrainExtractionPrior0GenericAffine.mat
         exec_fsl immv  ${intermediate}_${cur}_BrainExtractionBrain.nii.gz \
                        ${outdir}/${prefix}_BrainExtractionBrain.nii.gz
      fi
      if ! is_image     ${outdir}/${prefix}_BrainExtractionBrain.nii.gz
         then
         subroutine           @3.2  Executing brain extraction
         exec_fsl fslmaths ${intermediate}.nii.gz \
            -mul  ${mask[cxt]} \
            ${outdir}/${prefix}_BrainExtractionBrain.nii.gz
      fi
      subroutine              @3.3  Reorganising output
      exec_sys ln -sf ${outdir}/${prefix}_BrainExtractionBrain.nii.gz \
                      ${intermediate}_${cur}.nii.gz
      intermediate=${intermediate}_${cur}
      routine_end
      ;;





   FBE)
      #############################################################
      # FBE runs FSL brain extraction via BET
      #############################################################
      routine                 @4    FSL brain extraction
      subroutine              @4.1  Computing brain boundary
      exec_fsl bet                                 \
         ${intermediate}.nii.gz                    \
         ${intermediate}_${cur}.nii.gz             \
         -f    ${struc_fit[${cxt}]}                \
         -m
	   subroutine              @4.2  Reorganising output
	   exec_fsl immv   ${intermediate}_${cur}.nii.gz \
	                   ${outdir}/${prefix}_BrainExtractionBrain.nii.gz
	   exec_fsl immv   ${intermediate}_${cur}_mask.nii.gz \
	                   ${outdir}/${prefix}_BrainExtractionMask.nii.gz
      exec_sys ln -sf ${outdir}/${prefix}_BrainExtractionBrain.nii.gz \
                      ${intermediate}_${cur}.nii.gz
      intermediate=${intermediate}_${cur}
      routine_end
      ;;





   SEG)
      subroutine              @E.1     Invalid option detected: ${cur}
      continue
<<NOT_FUNCTIONAL_CODE
      #############################################################
      # SEG runs ANTs tissue-class segmentation via antsAtroposN4
      #############################################################
      if ! is_image ${segmentation[cxt]}
         then
         for i in ${!priors[@]}
            do
            (( i != 1 )) && priors_include="${priors_include} -y ${i}"
         done
         exec_ants   antsAtroposN4.sh                    \
            -d       3                                   \
            -b       ${struc_posterior_formulation[cxt]} \
            -a       ${intermediate}.nii.gz              \
            -x       ${mask[cxt]}                        \
            -m       3                                   \
            -n       5                                   \
            -c       ${#priors[cxt]}                     \
            -p       ${ctroot[cxt]}BrainSegmentationPriorWarped${priors_format} \
            -w       ${struc_prior_weight[cxt]}          \
            -u       ${struc_random_seed[cxt]}           \
            -g       ${struc_denoise_anat[cxt]}          \
            -s       'nii.gz'                            \
            ${additional_images}                         \
            ${label_propagation}                         \
            ${priors_include}                            \
            -o       ${intermediate}_${cur}_
         unset additional_images
         for (( i=1; i<=${#anat[@]}; i++ ))
            do
            anat[i]=${intermediate}_${cur}_Segmentation${i}N4.nii.gz
            additional_images="${additional_images} ${anat[i]}"
         done
         exec_ants   antsAtroposN4.sh                    \
            -d       3                                   \
            -b       ${struc_posterior_formulation[cxt]} \
            -a       ${intermediate}_${cur}_Segmentation0N4.nii.gz \
            -x       ${mask[cxt]}                        \
            -m       2                                   \
            -n       5                                   \
            -c       ${#priors[cxt]}                     \
            -p       ${ctroot[cxt]}BrainSegmentationPriorWarped${priors_format} \
            -w       ${struc_prior_weight[cxt]}          \
            -u       ${struc_random_seed[cxt]}           \
            -g       ${struc_denoise_anat[cxt]}          \
            -s       'nii.gz'                            \
            ${additional_images} \
            ${label_propagation} \
            ${priors_include}    \
            -o       ${intermediate}_${cur}_
         unset additional_images
         for (( i=1; i<=${#anat[@]}; i++ ))
            do
            exec_fsl immv  ${intermediate}_${cur}_Segmentation${i}N4.nii.gz \
                           ${outdir}/${prefix}_BrainSegmentation${i}N4.nii.gz
            anat[i]=${outdir}/${prefix}_BrainSegmentation${i}N4.nii.gz
            additional_images="${additional_images} ${anat[i]}"
         done
         for i in ${!priors[@]}
            do
            exec_fsl immv  ${intermediate}_${cur}_SegmentationPosteriors${i}.nii.gz \
                           ${outdir}/${prefix}_BrainSegmentationPosteriors${i}.nii.gz
         done
         exec_sys    mv -f ${intermediate}_${cur}_SegmentationTiledMosaic.png \
                           ${outdir}/${prefix}_BrainSegmentationTiledMosaic.png
         exec_sys    mv -f ${intermediate}_${cur}_SegmentationConvergence.txt \
                           ${outdir}/${prefix}_BrainSegmentationConvergence.txt
         exec_fsl    immv  ${intermediate}_${cur}_Segmentation0N4.nii.gz \
                           ${biasCorrected[cxt]}
         exec_fsl    immv  ${intermediate}_${cur}_Segmentation.nii.gz \
                           ${segmentation[cxt]}
      fi
NOT_FUNCTIONAL_CODE
      ;;





   REG)
      #############################################################
      # REG registers the input brain to the target template.
      #############################################################
      routine                 @6    Normalisation to template
      if (( ${struc_quick[cxt]} == 1 ))
         then
         subroutine           @6.1.1 Using quick SyN registration
         registration_prog=antsRegistrationSyNQuick.sh
      else
         subroutine           @6.1.2 Using SyN registration
         registration_prog=antsRegistrationSyN.sh
      fi
      if (( ${struc_bspline[cxt]} == 1 ))
         then
         subroutine           @6.2.1 SyN registration: b-spline
         registration_mode=b
      else
         subroutine           @6.2.2 SyN registration: default settings
         registration_mode=s
      fi
      if ! is_image ${struct_std[cxt]} \
      || rerun
         then
         subroutine           @6.3a Input: ${intermediate}.nii.gz
         subroutine           @6.3b Output root: ${intermediate}_${cur}.nii.gz
         subroutine           @6.3c Template: ${template}
         exec_ants   ${registration_prog}                   \
            -d       3                                      \
            -f       ${template}                            \
            -m       ${intermediate}.nii.gz                 \
            -o       ${intermediate}_${cur}                 \
            -t       ${registration_mode}
         subroutine           @6.4  Reorganising output
         exec_sys mv -f ${intermediate}_${cur}0GenericAffine.mat \
                        ${xfm_affine[cxt]}
         exec_fsl immv  ${intermediate}_${cur}1Warp.nii.gz \
                        ${xfm_warp[cxt]}
         exec_fsl immv  ${intermediate}_${cur}1InverseWarp.nii.gz \
                        ${ixfm_warp[cxt]}
         exec_fsl immv  ${intermediate}_${cur}Warped.nii.gz \
                        ${struct_std[cxt]}
      else
         subroutine           @6.5  Registration already completed
      fi
      if [[ ! -s ${ixfm_affine[cxt]} ]] \
      || rerun
         then
         subroutine           @6.6  Inverting affine transform
         exec_ants   antsApplyTransforms  \
            -d       3                    \
            -o       Linear[${ixfm_affine[cxt]},1] \
            -t       ${xfm_affine[cxt]}
      fi
      exec_sys ln -sf ${intermediate}.nii.gz      \
                      ${intermediate}_${cur}.nii.gz
      intermediate=${intermediate}_${cur}
      routine_end
      ;;





   CCC)
      #############################################################
      # CCC runs cortical contrast analysis
      #------------------------------------------------------------
      # First, prepare the binarised mask indicating the GM-WM
      # interface.
      #############################################################
      exec_afni   3dresample \
         -dxyz    .25 .25 .25 \
         -inset   ${segmentation[cxt]}.nii.gz \
         -prefix  ${intermediate}-upsample.nii.gz
      exec_fsl    fslmaths ${intermediate}_${cur}-upsample.nii.gz \
         -thr     3  \
         -uthr    3  \
         -edge       \
         -uthr    1  \
         -bin        \
         ${intermediate}_${cur}-upsample-edge.nii.gz
      exec_ants   ImageMath 3    ${intermediate}_${cur}-dist-from-edge.nii.gz \
                  MaurerDistance ${intermediate}_${cur}-upsample-edge.nii.gz 1
      exec_fsl    fslmaths ${intermediate}_${cur}-dist-from-edge.nii.gz \
         -thr     .75   \
         -uthr    1.25  \
         -bin           \
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
      
      
      
      
      
   *)
      subroutine           @E.1     Invalid option detected: ${cur}
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
   routine                 @8    Quality assessment
   exec_fsl fslmaths ${struct_std[cxt]} -bin ${str2stdmask[cxt]}
   subroutine              @8.1  [Computing registration quality metrics]
   registration_quality=( $(exec_xcp \
      maskOverlap.R \
      -m ${str2stdmask[cxt]} \
      -r ${template}) )
   echo  ${registration_quality[0]} > ${reg_cross_corr[cxt]}
   echo  ${registration_quality[1]} > ${reg_coverage[cxt]}
   echo  ${registration_quality[2]} > ${reg_jaccard[cxt]}
   echo  ${registration_quality[3]} > ${reg_dice[cxt]}
   subroutine              @8.2  [Preparing slicewise rendering]
   exec_xcp regslicer \
      -s ${struct_std[cxt]} \
      -t ${template} \
      -i ${intermediate_root} \
      -o ${outdir}/${prefix}_str2std
   routine_end
fi





###################################################################
# CLEANUP
#  * Test for the expected output. This should be the initial
#    image name with any routine suffixes appended.
#  * If the expected output is present, move it to the target path.
#  * If the expected output is absent, notify the user.
###################################################################
if is_image ${intermediate_root}${buffer}.nii.gz
   then
   subroutine                 @0.3
   processed=$(readlink -f    ${intermediate}.nii.gz)
   exec_sys imcp ${processed} ${struct[cxt]}
   ################################################################
   # Ensure that a mask is available for future modules. If one
   # hasn't been generated, assume that the input was already
   # masked.
   ################################################################
   if ! is_image ${mask[cxt]}
      then
      subroutine                 @0.2
      exec_fsl fslmaths ${struct[cxt]} \
         -bin  ${mask[cxt]}
   fi
   completion
else
   subroutine                 @0.4
   abort_stream \
"Expected output not present.]
[Expected: ${buffer}]
[Check the log to verify that processing]
[completed as intended."
fi
