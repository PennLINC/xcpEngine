#!/usr/bin/env bash

###################################################################
#   ⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗   #
###################################################################

###################################################################
# SPECIFIC MODULE HEADER
# This module computes a grey matter density map following:
#
# Gennatas ED et al. (2017) Age-related effects and sex differences
# in gray matter density, volume, mass, and cortical thickness
# from childhood to young adulthood.
###################################################################
mod_name_short=gmd
mod_name='GREY MATTER DENSITY MODULE'
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
   !  is_image    ${segmentation[sub]}                         \
   && derivative    segmentation       ${segmentation3class[cxt]}
   
   source ${XCPEDIR}/core/auditComplete
   source ${XCPEDIR}/core/updateQuality
   source ${XCPEDIR}/core/moduleEnd
}





###################################################################
# OUTPUTS
###################################################################
derivative  probabilityCSF          ${prefix}_probabilityCSF
derivative  probabilityGM           ${prefix}_probabilityGM
derivative  probabilityWM           ${prefix}_probabilityWM
derivative  segmentation3class      ${prefix}_segmentation3class
derivative  gmd                     ${prefix}_gmd

derivative_set    gmd Statistic     mean

qc          mean_gmd meanGMD        ${prefix}_mean_gmd

add_reference                       img[$sub] ${prefix}_raw

require     image mask

<<DICTIONARY

gmd
   The intersection of the deterministic grey matter boundary and
   the probabilistic grey matter map -- the grey matter density
   following Gennatas et al. (2017).
mean_gmd
   The average grey matter density over all grey matter voxels.
probability~
   Probabilistic maps of 3 tissue classes: cerebrospinal fluid,
   grey matter, and white matter.
segmentation3class
   A deterministic segmentation of the brain into 3 tissue classes:
   cerebrospinal fluid, grey matter, and white matter.

DICTIONARY










###################################################################
# Calculate GMD in an iterative procedure
###################################################################
routine                       @1    Computing 3-class segmentation
if ! is_image ${segmentation3class[cxt]} \
|| rerun
   then
   subroutine                 @1.1  Performing 3 Atropos iterations
   for (( i=0; i<3; i++ ))
      do
      proot=${intermediate}-atropos${i}-priorImage0%02d.nii.gz
      if (( i == 0 ))
         then
         subroutine           @1.2  Iteration 1: initialising segmentation
         exec_ants   Atropos                    \
            -d       3                          \
            -a       ${img}                     \
            -i       KMeans[3]                  \
            -c       [5,0]                      \
            -m       [0,1x1x1]                  \
            -x       ${mask[cxt]}               \
            -o       [${intermediate}-atropos${i}.nii.gz,${proot}]
      else
         subroutine           @1.3  Iteration $((i+1)): refining segmentation
         exec_ants   Atropos                    \
            -d       3                          \
            -a       ${img}                     \
            -i       PriorProbabilityImages[3,${pr_in},0.0] \
            -k       Gaussian                   \
            -p       Socrates[1]                \
            --use-partial-volume-likelihoods 0  \
            -c       [12,0.00001]               \
            -x       ${mask[cxt]}               \
            -m       [0,1x1x1]                  \
            -o       [${intermediate}-atropos${i}.nii.gz,${proot}]
      fi
      pr_in=${intermediate}-atropos${i}-priorImage0%02d.nii.gz
   done
   subroutine                 @1.4  Reorganising output
   exec_fsl immv  ${intermediate}-atropos2.nii.gz \
                  ${segmentation3class[cxt]}
   exec_fsl immv  ${intermediate}-atropos2-priorImage001.nii.gz \
                  ${probabilityCSF[cxt]}
   #exec_fsl immv  ${intermediate}-atropos2-priorImage002.nii.gz \
                  #${probabilityGM[cxt]}
   exec_ants ImageMath 3  ${probabilityGM[cxt]}  Normalize \
          ${intermediate}-atropos2-priorImage002.nii.gz               
   exec_fsl immv  ${intermediate}-atropos2-priorImage003.nii.gz \
                  ${probabilityWM[cxt]}
else
   subroutine                 @1.5  GMD computed
fi
routine_end

###################################################################
# Create isolated GM-GMD prior image
###################################################################
routine                       @2    Mapping grey matter density
if ! is_image ${gmd[${cxt}]}  \
|| rerun
   then
   subroutine                 @2.1  Defining tissue boundaries
   exec_fsl fslmaths ${segmentation3class[cxt]} \
      -thr  2                 \
      -uthr 2                 \
      -bin -mul               \
      ${probabilityGM[cxt]}   \
      ${gmd[${cxt}]}
   ################################################################
   # Calculate mean GMD in GM compartment
   ################################################################
   subroutine                 @2.2  Estimating mean GMD
   exec_fsl fslstats ${gmd[cxt]} -M >> ${mean_gmd[cxt]}
else
   subroutine                 @2.3  GMD already computed
fi
routine_end


if [[ -d ${freesuferdir[sub]} ]] 
   then  
    if [[  -f ${gmd[cxt]}  ]]
     then 
      subroutine @7.8 convert gmd  to surface
      subjid=$(basename ${freesuferdir[sub]})
      SUBJECTS_DIR=${freesuferdir[sub]}/../
      exec_sys cp -r ${FREESURFER_HOME}/subjects/fsaverage5  ${SUBJECTS_DIR}/
      for hem in lh rh
          do
           ${FREESURFER_HOME}/bin/mri_vol2surf --mov ${gmd[cxt]} --regheader ${subjid} --hemi ${hem} \
               --o ${outdir}/${hem}_surface.nii.gz --projfrac-avg 0 1 0.1 --surf white

           ${FREESURFER_HOME}/bin/mri_surf2surf  --srcsubject ${subjid} --trgsubject  fsaverage5 --trgsurfval ${outdir}/${hem}_surface2fsav.nii.gz \
                    --hemi ${hem}   --srcsurfval ${outdir}/${hem}_surface.nii.gz --cortex --reshape

           ${FREESURFER_HOME}/bin/mris_convert -f ${outdir}/${hem}_surface2fsav.nii.gz   ${SUBJECTS_DIR}/fsaverage5/surf/${hem}.sphere  \
                   ${outdir}/${prefix}_gmd_${hem}.cort.gii

      done

      exec_sys  wb_command -cifti-create-dense-scalar ${outdir}/${prefix}_gmd.dscalar.nii  \
               -left-metric ${prefix}_gmd_lh.cort.gii  -right-metric ${outdir}/${prefix}_gmd_rh.cort.gii 

      exec_sys rm -rf  ${outdir}/*surface.nii.gz  ${outdir}/regis*  ${outdir}/*surface2fsav.nii.gz 
    fi
fi



completion
