#!/usr/bin/env bash

###################################################################
#   ✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡   #
###################################################################

###################################################################
# SPECIFIC MODULE HEADER
# This module performs volumetric structural quality assessment.
###################################################################
mod_name_short=strucqa
mod_name='VOLUMETRIC STRUCTURAL QUALITY ASSESSMENT MODULE'
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
completion(){
   
   quality_metric    fgbgEnergyRatio         fber
   quality_metric    signalToNoiseRatio      snr
   quality_metric    contrastToNoiseRatio    cnr
   quality_metric    corticalContrasts       cortical_contrasts
   quality_metric    entropyFocusCriterion   efc
   quality_metric    gmKurtosis              gm_kurtosis
   
}





###################################################################
# OUTPUTS
###################################################################
derivative     csfMask                 ${prefix}_csfMask
derivative     gmMask                  ${prefix}_gmMask
derivative     wmMask                  ${prefix}_wmMask
derivative     cortexMask              ${prefix}_cortexMask
derivative     segmentationQA          ${prefix}_segmentationQA

output         coor_csv                ${prefix}_landmarksCoords.csv
output         affine_transform        ${prefix}_0GenericAffine.mat
output         foreground              ${prefix}_foreground

input image    segmentation            \
   or          segmentation3class      \
   as          segmentationQA

<<DICTIONARY

foreground
   A binary mask indicating foreground voxels in subject anatomical
   space.
csfMask
   A binary mask of cerebrospinal fluid in subject anatomical
   space.
gmMask
   A binary mask of grey matter in subject anatomical space.
wmMask
   A binary mask of white matter in subject anatomical space.
cortexMask
   A binary mask of cortical tissue in subject anatomical space.
segmentation3class
   A deterministic segmentation of the brain into 3 tissue classes:
   cerebrospinal fluid, grey matter, and white matter.
coor_csv
   A csv specifying 3 MNI landmarks in subject anatomical space.
affine_transform
   A coarse transformation computed from MNI space to subject
   anatomical space.

DICTIONARY










###################################################################
# See if we have a segmentation image
# If none provided then run segmentation using either FAST or
# Atropos
###################################################################
allValsCheck=0
declare           -A tissue_classes
tissue_classes=(  [gm]="grey matter"
                  [wm]="white matter"
                 [csf]="cerebrospinal fluid"
                 [ctx]="cortex" )
for class in "${!tissue_classes[@]}"
   do
   ################################################################
   # Generate a binary mask if necessary.
   # This mask will be based on a user-specified input value
   # and a user-specified image in the subject's structural space.
   ################################################################
   class_val='strucQA_'${class}'_val['${cxt}']'
   class_mask=${class}'Mask['${cxt}']'
   if is_image ${segmentationQA[cxt]} \
   && [[ -n ${!class_val} ]]
      then
      exec_xcp val2mask.R              \
         -i    ${strucQA_seg[cxt]}     \
         -v    ${!class_val}           \
         -o    ${!class_mask}
      (( allValsCheck++ ))
   fi
done





###################################################################
# See if we have 3 segmentation masks
# If we don't have three run FAST | Atropos to create a quick seg
###################################################################
if (( ${allValsCheck} < 3))
   then
   if [[ ${strucQASeg[${cxt}]} == "FAST" ]] 
      then
      exec_fsl fast -g \
         -o    ${outdir}/${prefix}_ \
         ${struct[sub]}
      exec_sys mv ${outdir}/${prefix}_seg_0.nii.gz \
                  ${csfMask[cxt]}
      exec_sys mv ${outdir}/${prefix}_seg_1.nii.gz \
                  ${gmMask[cxt]}
      exec_sys mv ${outdir}/${prefix}_seg_2.nii.gz \
                  ${wmMask[cxt]}
   else
      if ! is_image ${mask[sub]} ]]
         then
         exec_fsl bet ${struct[sub]} \
            ${intermediate}_BEmask.nii.gz
         exec_fsl fslmaths ${intermediate}_BEmask.nii.gz \
            -bin  ${intermediate}_BEmask.nii.gz
         mask[cxt]=${intermediate}_BEmask.nii.gz
      else
         require  image mask
      fi
      atroposOut=${outdir}/${prefix}_seg.nii.gz
      exec_ants   Atropos        \
         -d       3              \
         -a       ${struct[sub]} \
         -i       KMeans[3]      \
         -c       [5,0]          \
         -m       [0,1x1x1]      \
         -x       ${mask[cxt]}   \
         -o       [${atroposOut}]
      exec_xcp    val2mask.R     \
         -i       ${atroposOut}  \
         -v       1              \
         -o       ${csfMask[cxt]}
      exec_xcp    val2mask.R     \
         -i       ${atroposOut}  \
         -v       2              \
         -o       ${gmMask[cxt]}
      exec_xcp    val2mask.R     \
         -i       ${atroposOut}  \
         -v       3              \
         -o       ${wmMask[cxt]}
    fi
fi

###################################################################
# Now we need to create our foreground segmentation
# we need to make sure we have a transformation from MNI to our
# subject in order to perform this
###################################################################
exec_ants   antsRegistration           \
   -d       3                          \
   -v       0                          \
   -u       1                          \
   -w       [0.01,0.99]                \
   -o       ${outdir}/${prefix}_       \
   -c       [1000x500x250x100,1e-8,10] \
   -t       Affine[0.1]                \
   -f       8x4x2x1                    \
   -s       4x2x1x0                    \
   -r       [${struc[sub]},${XCPEDIR}/space/MNI/MNI-1x1x1.nii.gz,1] \
   -m       MI[${struc[sub]},${XCPEDIR}/space/MNI/MNI-1x1x1.nii.gz,1,32,Regular,0.25] \
   --float  1 \
   --verbose 1

###################################################################
# Now apply the transformation to the MNI points
###################################################################
exec_ants   antsApplyTransformsToPoints \
   -d       3                           \
   -i       ${XCPEDIR}/modules/strucQA/mniCoords.csv \
   -o       ${coordsCSV[cxt]}           \
   -t       ${affineFiles[cxt]}
  
###################################################################
# Now apply this transformation to the MNI mask
###################################################################  
exec_ants   antsApplyTransforms  \
   -d       3                    \
   -i       ${XCPEDIR}/modules/strucQA/mniForeGroundMask.nii.gz \
   -o       ${foreground[cxt]}   \
   -r       ${img[sub]}          \
   -n       MultiLabel           \
   -t       ${affineFiles[${cxt}]}
  
###################################################################
# Now mask out the neck and nose from the background
###################################################################   
exec_fsl fslmaths ${foreground[cxt]} \
   -add  1 \
   -bin  ${intermediate}_allMask~TEMP~
exec_xcp extendMaskInferior.R \
   -i    ${foreground[cxt]} \
   -o    ${foreground[cxt]}2 \
   -c    ${coordsCSV[cxt]} \
   -s    ${intermediate}_allMask~TEMP~

###################################################################
# Ensure that the sinuses are in the background 
###################################################################
exec_fsl    fslmaths ${foreground[cxt]}.nii.gz  \
   -mul     ${foreground[cxt]}2.nii.gz          \
   -sub     1                                   \
   -abs     ${foreground[cxt]}3.nii.gz
exec_ants   ImageMath 3         ${foreground[cxt]}4.nii.gz \
            GetLargestComponent ${foreground[cxt]}3.nii.gz
exec_fsl    fslmaths ${foreground[cxt]}3.nii.gz \
   -sub     ${foreground[cxt]}4.nii.gz          \
   ${foreground[cxt]}5
exec_fsl    fslmaths ${foreground[cxt]}2.nii.gz \
   -sub     ${foreground[cxt]}5.nii.gz          \
   ${foreground[cxt]}.nii.gz
exec_sys    rm -f ${foreground[cxt]}5.nii.gz \
                  ${foreground[cxt]}4.nii.gz \
                  ${foreground[cxt]}3.nii.gz \
                  ${foreground[cxt]}2.nii.gz

###################################################################
# Now calculate the quality metrics 
###################################################################
if is_image ${cortMask[cxt]}
   then
   argCortMask="-c ${cortMask[cxt]}"
fi
exec_xcp strucQA.R \
   -i    ${img[sub]} \
   -o    ${outdir}/${prefix}_qualityMetrics.csv \
   -m    ${gmMask[cxt]} \
   -w    ${wmMask[cxt]} \
   -f    ${foreGround[cxt]} \
   ${argCortMask}
###################################################################
# Now append quality metrics to global quality variables
###################################################################
qualityHeader=`head ${outdir}/${prefix}_qualityMetrics.csv -n 1`
qualityValues=`tail ${outdir}/${prefix}_qualityMetrics.csv -n 1`
