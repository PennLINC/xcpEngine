#!/usr/bin/env bash

###################################################################
#   ⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗   #
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

   exec_xcp spaceMetadata                       \
      -o    ${spaces[sub]}                      \
      -f    ${standard}:${template}             \
      -m    ${space[sub]}:${struct[cxt]}        \
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
derivative  corticalThickness       ${prefix}_CorticalThickness
derivative  mask                    ${prefix}_BrainExtractionMask
derivative  segmentation            ${prefix}_BrainSegmentation

for i in {1..6}
   do
   output   segmentationPosteriors  ${prefix}_BrainSegmentationPosteriors${i}.nii.gz
done

derivative_set corticalThickness    Statistic        mean
derivative_set mask                 Type             Mask

output      struct_std              ${prefix}_BrainNormalizedToTemplate.nii.gz
output      corticalThickness_std   ${prefix}_CorticalThicknessNormalizedToTemplate.nii.gz
output      ctroot                  ${prefix}_
output      referenceVolume         ${prefix}_BrainSegmentation0N4.nii.gz
output      referenceVolumeBrain    ${prefix}_ExtractedBrain0N4.nii.gz
output      meanIntensity           ${prefix}_BrainSegmentation0N4.nii.gz
output      meanIntensityBrain      ${prefix}_ExtractedBrain0N4.nii.gz
output      str2stdmask             ${prefix}_str2stdmask.nii.gz
output      xfm_affine              ${prefix}_SubjectToTemplate0GenericAffine.mat
output      xfm_warp                ${prefix}_SubjectToTemplate1Warp.nii.gz
output      ixfm_affine             ${prefix}_TemplateToSubject1GenericAffine.mat
output      ixfm_warp               ${prefix}_TemplateToSubject0Warp.nii.gz

configure   template_priors         $(space_get ${standard} Priors)
configure   template_head           $(space_get ${standard} MapHead)
configure   template_mask           $(space_get ${standard} Mask)
configure   template_mask_dil       $(space_get ${standard} MaskDilated)
configure   template_brain_prior    $(space_get ${standard} BrainPrior)

qc reg_cross_corr regCrossCorr      ${prefix}_regCrossCorr.txt
qc reg_coverage   regCoverage       ${prefix}_regCoverage.txt
qc reg_jaccard    regJaccard        ${prefix}_regJaccard.txt
qc reg_dice       regDice           ${prefix}_regDice.txt
qc euler_number   eulernumber       ${prefix}_eulernumber.txt

input image mask
input image segmentation

add_reference                       template template

final       struct                  ${prefix}_ExtractedBrain0N4

<< DICTIONARY

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
   The subject brain following normalisation to a standard or
   template space. This should not be processed as a derivative.
xfm_affine
   A matrix that defines an affine transformation from anatomical
   space to standard space.
xfm_warp
   A distortion field that defines a nonlinear diffeomorphic warp
   from anatomical space to standard space.

DICTIONARY










#(( ${trace} > 1 )) && ants_verbose=1 || ants_verbose=0
priors_get=$(echo ${template_priors[cxt]//\%03d/\?\?\?})
priors_get=( $(eval ls ${priors_get}) )
for i in ${!priors_get[@]}
   do
   (( i++ ))
   priors[i]=$(printf ${template_priors[cxt]} ${i})
done
prior_space=${standard}
###################################################################
# The variable 'buffer' stores the processing steps that are
# already complete; it becomes the expected ending for the final
# image name and is used to verify that prestats has completed
# successfully.
###################################################################
unset buffer

subroutine                    @0.1

###################################################################
# Ensure that the input image is stored in the same orientation
# as the template. If not, reorient it to match
###################################################################
routine                 @0    Ensure matching orientation
subroutine              @0.1a Input: ${intermediate}.nii.gz
subroutine              @0.1b Template: ${template}
subroutine              @0.1c Output root: ${ctroot[cxt]}

native_orientation=$(${AFNI_PATH}/3dinfo -orient ${intermediate}.nii.gz)
template_orientation=$(${AFNI_PATH}/3dinfo -orient ${template})

echo "NATIVE:${native_orientation} TEMPLATE:${template_orientation}"
full_intermediate=$(ls ${intermediate}.nii* | head -n 1)
if [ "${native_orientation}" != "${template_orientation}" ]
then

    subroutine @0.1d "${native_orientation} -> ${template_orientation}"
    ${AFNI_PATH}/3dresample -orient ${template_orientation} \
              -inset ${full_intermediate} \
              -prefix ${intermediate}_${template_orientation}.nii.gz
    intermediate=${intermediate}_${template_orientation}
    intermediate_root=${intermediate}
else

    subroutine  @0.1d "NOT re-orienting T1w"

fi

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
      proc_ants   ${struct[cxt]}                   \
                  antsCorticalThickness.sh         \
         -d       3                                \
         -a       ${intermediate}.nii.gz           \
         -e       ${template_head[cxt]}            \
         -m       ${template_brain_prior[cxt]}     \
         -p       ${template_priors[cxt]}          \
         -o       ${ctroot[cxt]}                   \
         -s       'nii.gz'                         \
         -t       ${template}                      \
         -f       ${template_mask_dil[cxt]}        \
         -g       ${struc_denoise_anat[cxt]}       \
         -w       ${struc_prior_weight[cxt]}       \
         -b       ${struc_posterior_formulation[cxt]} \
         -j       ${struc_floating_point[cxt]}     \
         -u       ${struc_random_seed[cxt]}        \
         -v       ${struc_bspline[cxt]}            \
         -q       ${struc_quick[cxt]}              \
         ${additional_images}                      \
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
      if ! is_image ${intermediate}_${cur}.nii.gz \
      || rerun
         then
         subroutine           @2.1a Correcting inhomogeneities
         subroutine           @2.1b Delegating control to N4BiasFieldCorrection
         proc_ants   ${intermediate}_${cur}.nii.gz    \
                     N4BiasFieldCorrection            \
            -d       3                                \
            -i       ${intermediate}.nii.gz           \
            -o       %OUTPUT                          \
            --verbose 1
      else
         subroutine           @2.2  Bias field correction already complete
      fi
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
         subroutine           @3.1c Output: ${outdir}/${prefix}_BrainExtractionBrain.nii.gz
         subroutine           @3.1d Delegating control to antsBrainExtraction
         proc_ants   ${intermediate}_${cur}_BrainExtractionMask.nii.gz \
                     antsBrainExtraction.sh           \
            -d       3                                \
            -a       ${intermediate}.nii.gz           \
            -e       ${template_head[cxt]}            \
            -f       ${template_mask_dil[cxt]}        \
            -m       ${template_brain_prior[cxt]}     \
            -o       ${intermediate}_${cur}_          \
            -s       'nii.gz'                         \
            -q       ${struc_floating_point[cxt]}     \
            -u       ${struc_random_seed[cxt]}        \
            -z       0
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
      #############################################################
      # SEG runs ANTs tissue-class segmentation via antsAtroposN4
      #############################################################
      routine                 @5    ANTs Atropos segmentation
      anat[0]=${intermediate}.nii.gz
      if ! is_image ${segmentation[cxt]}
         then
         if (( ${struc_seg_priors[cxt]} == 1 ))
            then
            subroutine        @5.1.1 Warping ${#priors[@]} template priors to anatomical space
            for i in ${!priors[@]}
               do
               warprior=$(printf ${intermediate}'-priorWarped%03d.nii.gz' ${i})
               warpspace   ${priors[i]}   \
                  ${warprior}             \
                  ${prior_space}:${space[sub]} \
                  Gaussian
               (( i == 1 )) && continue
               priors_include=( "${priors_include[@]}" -y ${i} )
            done
            nclass=${#priors[@]}
            priors_arg='-p '${intermediate}'-priorWarped%03d.nii.gz'
            priors_wt=${struc_prior_weight[cxt]}
         else
            subroutine        @5.1.2 Initialising 3-class priorless segmentation
            unset priors_include priors_arg
            nclass=3
            priors_wt=0
         fi
         subroutine           @5.2a Atropos segmentation
         subroutine           @5.2b Input: ${intermediate}.nii.gz
         subroutine           @5.2c Output: ${segmentation[cxt]}
         subroutine           @5.2d Delegating control to antsAtroposN4
         exec_ants   antsAtroposN4.sh                    \
            -d       3                                   \
            -b       ${struc_posterior_formulation[cxt]} \
            -a       ${intermediate}.nii.gz              \
            -x       ${mask[cxt]}                        \
            -m       3                                   \
            -n       5                                   \
            -c       ${nclass}                           \
            "${priors_include[@]}"                       \
            ${priors_arg}                                \
            -w       ${priors_wt}                        \
            -u       ${struc_random_seed[cxt]}           \
            -g       ${struc_denoise_anat[cxt]}          \
            -s       'nii.gz'                            \
            ${label_propagation}                         \
            -o       ${intermediate}_${cur}_             \
            -z       0
         exec_ants   antsAtroposN4.sh                    \
            -d       3                                   \
            -b       ${struc_posterior_formulation[cxt]} \
            -a       ${intermediate}_${cur}_Segmentation$0N4.nii.gz \
            -x       ${mask[cxt]}                        \
            -m       2                                   \
            -n       5                                   \
            -c       ${nclass}                           \
            "${priors_include[@]}"                       \
            ${priors_arg}                                \
            -w       ${priors_wt}                        \
            -u       ${struc_random_seed[cxt]}           \
            -g       ${struc_denoise_anat[cxt]}          \
            -s       'nii.gz'                            \
            ${label_propagation}                         \
            -o       ${intermediate}_${cur}_             \
            -z       0
         subroutine           @5.3  Reorganising output
         imgct=${#anat[@]}
         echo ${anat[@]}
         for (( i=1; i <= imgct; i++ ))
            do
            echo $i
            exec_fsl immv  ${intermediate}_${cur}_Segmentation${i}N4.nii.gz \
                           ${outdir}/${prefix}_BrainSegmentation${i}N4.nii.gz
            anat[i]=${outdir}/${prefix}_BrainSegmentation${i}N4.nii.gz
            additional_images="${additional_images} ${anat[i]}"
         done
         if (( ${struc_seg_priors[cxt]} == 1 ))
            then
            for i in ${!priors[@]}
               do
               exec_fsl immv  ${intermediate}_${cur}_SegmentationPosteriors${i}.nii.gz \
                              ${outdir}/${prefix}_BrainSegmentationPosteriors${i}.nii.gz
               priors[i]=${outdir}/${prefix}_BrainSegmentationPosteriors${i}.nii.gz
               prior_space=${space[sub]}
            done
         fi
         exec_sys    mv -f ${intermediate}_${cur}_SegmentationTiledMosaic.png \
                           ${outdir}/${prefix}_BrainSegmentationTiledMosaic.png
         exec_sys    mv -f ${intermediate}_${cur}_SegmentationConvergence.txt \
                           ${outdir}/${prefix}_BrainSegmentationConvergence.txt
         exec_fsl fslmaths ${intermediate}_${cur}_Segmentation0N4.nii.gz \
                           -mul ${mask[cxt]}                             \
                           ${struct[cxt]}
         exec_fsl    immv  ${intermediate}_${cur}_Segmentation.nii.gz \
                           ${segmentation[cxt]}
      else
         subroutine           @5.4  Segmentation already complete
      fi
      exec_sys    ln -sf   ${struct[cxt]} \
                           ${intermediate}_${cur}.nii.gz
      intermediate=${intermediate}_${cur}
      routine_end
      ;;
    
   FSF)
   #############################################################
    # FREESURFER preprocessing 
   #############################################################
   exec_sys mkdir -p ${outdir}/freesurfer 
   
   freesurferdir=${outdir}/freesurfer 
    if [[  -d ${struc_fmriprepdir[cxt]}/ ]]
     then 
         fmriprepout=${struc_fmriprepdir[cxt]} 
         
    elif [[ -d ${struc_fmriprepdir[sub]}/ ]] 
       then
         fmriprepout=${struc_fmriprepdir[sub]} 
    fi 


    if [[  -d ${fmriprepout} ]] 
       then  
       exec_sys cp -r ${fmriprepout} ${freesurferdir}/
       subjectid=$(basename ${freesurferdir}/* )
       fmripo=$fmriprepout/../
       exec_sys cp -r $FREESURFER_HOME/subjects/fsavg* $SUBJECTS_DIR/
       source $FREESURFER_HOME/SetUpFreeSurfer.sh
       exec_sys export  SUBJECTS_DIR=${freesurferdir}
       ${FREESURFER_HOME}/bin/mris_euler_number -o  /tmp/text_lh.tsv  ${SUBJECTS_DIR}/${subjectid}/surf/lh.white
       ${FREESURFER_HOME}/bin/mris_euler_number -o  /tmp/text_rh.tsv  ${SUBJECTS_DIR}/${subjectid}/surf/rh.white
       eulernumber=$(expr $(cat /tmp/text_lh.tsv)  +  $(cat /tmp/text_rh.tsv))
       exec_sys echo ${eulernumber} > ${euler_number[cxt]}
       exec_sys rm  -rf /tmp/text_*.tsv

    else 
      
      #run the freesurfer
      source $FREESURFER_HOME/SetUpFreeSurfer.sh
      exec_sys export  SUBJECTS_DIR=${freesurferdir}
      subjectid=${prefix}
      source $FREESURFER_HOME/SetUpFreeSurfer.sh
      ${FREESURFER_HOME}/bin/recon-all -subjid ${subjectid} \
      -i ${img[sub]} -all -sd ${SUBJECTS_DIR}
      exec_sys cp -r $FREESURFER_HOME/subjects/fsavg* $SUBJECTS_DIR/
       ${FREESURFER_HOME}/bin/mris_euler_number -o  /tmp/text_lh.tsv  ${SUBJECTS_DIR}/${subjectid}/surf/lh.white
       ${FREESURFER_HOME}/bin/mris_euler_number -o  /tmp/text_rh.tsv  ${SUBJECTS_DIR}/${subjectid}/surf/rh.white
       eulernumber=$(expr $(cat /tmp/text_lh.tsv)  +  $(cat /tmp/text_rh.tsv))
       exec_sys echo ${eulernumber} > ${euler_number[cxt]}
       exec_sys rm  -rf /tmp/text_*.tsv

   fi 

    output freesuferdir ${SUBJECTS_DIR}/${subjectid} 

    #convert cortical thickness to surface  
    if [[  -f ${corticalThickness[cxt]}  ]]
         then 
     
      for hem in lh rh
          do
           ${FREESURFER_HOME}/bin/mri_vol2surf --mov ${corticalThickness[cxt]} --regheader ${subjectid} --hemi ${hem} \
               --o ${outdir}/${hem}_surface.nii.gz --projfrac-avg 0 1 0.1 --surf white

           ${FREESURFER_HOME}/bin/mri_surf2surf  --srcsubject ${subjectid} --trgsubject  fsaverage5 --trgsurfval ${outdir}/${hem}_surface2fsav.nii.gz \
                    --hemi ${hem}   --srcsurfval ${outdir}/${hem}_surface.nii.gz --cortex --reshape

           ${FREESURFER_HOME}/bin/mris_convert -f ${outdir}/${hem}_surface2fsav.nii.gz   ${SUBJECTS_DIR}/fsaverage5/surf/${hem}.sphere  \
                   ${outdir}/${prefix}_corticalthickness_${hem}.cort.gii

      done

      exec_sys  wb_command -cifti-create-dense-scalar ${outdir}/${prefix}_corticalthickness.dscalar.nii  \
               -left-metric ${prefix}_corticalthickness_lh.cort.gii  -right-metric ${outdir}/${prefix}_corticalthickness_rh.cort.gii 

      exec_sys rm -rf  ${outdir}/*surface.nii.gz  ${outdir}/regis*  ${outdir}/*surface2fsav.nii.gz 
    fi
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
      if (( ${struc_floating_point[cxt]} == 1 ))
         then
         subroutine           @6.3  Using floating point precision
         precision_arg='-p f'
      fi
      if ! is_image ${struct_std[cxt]} \
      || rerun
         then
         subroutine           @6.43a Input: ${intermediate}.nii.gz
         subroutine           @6.4b Output warp: ${xfm_warp[cxt]}
         subroutine           @6.4c Template: ${template}
         exec_ants   ${registration_prog}                   \
            -d       3                                      \
            -f       ${template}                            \
            -m       ${intermediate}.nii.gz                 \
            -o       ${intermediate}_${cur}                 \
            -t       ${registration_mode}                   \
                     ${precision_arg}
         subroutine           @6.5  Reorganising output
         exec_sys mv -f ${intermediate}_${cur}0GenericAffine.mat \
                        ${xfm_affine[cxt]}
         exec_fsl immv  ${intermediate}_${cur}1Warp.nii.gz \
                        ${xfm_warp[cxt]}
         exec_fsl immv  ${intermediate}_${cur}1InverseWarp.nii.gz \
                        ${ixfm_warp[cxt]}
         exec_fsl immv  ${intermediate}_${cur}Warped.nii.gz \
                        ${struct_std[cxt]}
      else
         subroutine           @6.6  Registration already completed
      fi
      if [[ ! -s ${ixfm_affine[cxt]} ]]            \
      || rerun
         then
         subroutine           @6.7  Inverting affine transform
         exec_ants   antsApplyTransforms           \
            -d       3                             \
            -o       Linear[${ixfm_affine[cxt]},1] \
            -t       ${xfm_affine[cxt]}
      fi
      #############################################################
      # Set up provisional spatial metadata
      #############################################################
      exec_sys ln -sf ${intermediate}.nii.gz       \
                      ${intermediate}_${cur}.nii.gz
      intermediate=${intermediate}_${cur}
      exec_xcp spaceMetadata                       \
         -o    ${spaces[sub]}                      \
         -f    ${standard}:${template}             \
         -m    ${space[sub]}:${intermediate}.nii.gz\
         -x    ${xfm_affine[cxt]},${xfm_warp[cxt]} \
         -i    ${ixfm_warp[cxt]},${ixfm_affine[cxt]} \
         -s    ${spaces[sub]}
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
   routine                    @8    Quality assessment
   exec_fsl fslmaths ${struct_std[cxt]} -bin ${str2stdmask[cxt]}
   subroutine                 @8.1  [Computing registration quality metrics]
   registration_quality=( $(exec_xcp \
      maskOverlap.R \
      -m ${str2stdmask[cxt]} \
      -r ${template}) )
   echo  ${registration_quality[0]} > ${reg_cross_corr[cxt]}
   echo  ${registration_quality[1]} > ${reg_coverage[cxt]}
   echo  ${registration_quality[2]} > ${reg_jaccard[cxt]}
   echo  ${registration_quality[3]} > ${reg_dice[cxt]}
   subroutine                 @8.2  [Preparing slicewise rendering]
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
   # hasnt been generated, assume that the input was already
   # masked.
   ################################################################
   if ! is_image ${mask[cxt]}
      then
      subroutine              @0.2
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
