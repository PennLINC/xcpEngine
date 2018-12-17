#!/usr/bin/env bash

###################################################################
#   ✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡   #
###################################################################

###################################################################
# SPECIFIC MODULE HEADER
# This module performs volumetric structural quality assessment.
###################################################################
mod_name_short=qcanat
mod_name='VOLUMETRIC ANATOMICAL QUALITY ASSESSMENT MODULE'
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
   source ${XCPEDIR}/core/auditComplete
   source ${XCPEDIR}/core/updateQuality
   source ${XCPEDIR}/core/moduleEnd
}





###################################################################
# OUTPUTS
###################################################################
define         csfMask                 ${outdir}/${prefix}_csfMask.nii.gz
define         gmMask                  ${outdir}/${prefix}_gmMask.nii.gz
define         wmMask                  ${outdir}/${prefix}_wmMask.nii.gz
define         cortMask                ${outdir}/${prefix}_cortexMask.nii.gz
define		   dgmMask				   ${outdir}/${prefix}_dgmMask.nii.gz
define         segmentationQA          ${outdir}/${prefix}_segmentationQA.nii.gz
define         mniFGMask               ${XCPEDIR}/modules/qcanat/mniForeGroundMask.nii.gz
define         coordsCSV               ${outdir}/${prefix}_landmarksCoords.csv
define         affine_mni2sub          ${outdir}/${prefix}_0GenericAffine.mat
define         foreground              ${outdir}/${prefix}_foreground.nii.gz
define         mniCoords               ${XCPEDIR}/modules/qcanat/mniCoords.sclib
define         subCoords               ${outdir}/${prefix}_mniCoords.sclib

qc FBER        FGBGEnergyRatio         ${prefix}_qc_FBER.txt
qc SNR         SignalToNoiseRatio      ${prefix}_qc_SNR.txt
qc CNR         ContrastToNoiseRatio    ${prefix}_qc_CNR.txt
qc CORTCON     CorticalContrasts       ${prefix}_qc_CORTCON.txt
qc EFC         EntropyFocusCriterion   ${prefix}_qc_EFC.txt
qc GMKURT      GreyMatterKurtosis      ${prefix}_qc_GMKURT.txt
qc GMSKEW      GreyMatterSkewness      ${prefix}_qc_GMSKEW.txt
qc WMKURT      WhiteMatterKurtosis     ${prefix}_qc_WMKURT.txt
qc WMSKEW      WhiteMatterSkewness     ${prefix}_qc_WMSKEW.txt
qc BGKURT      BackgroundKurtosis      ${prefix}_qc_BGKURT.txt
qc BGSKEW      BackgroundSkewness      ${prefix}_qc_BGSKEW.txt

input image    segmentation as segmentationQA

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
cortMask
   A binary mask of cortical tissue in subject anatomical space.
segmentation3class
   A deterministic segmentation of the brain into 3 tissue classes:
   cerebrospinal fluid, grey matter, and white matter.
coordsCSV
   A csv specifying 3 MNI landmarks in subject anatomical space.
affine_transform
   A coarse transformation computed from MNI space to subject
   anatomical space. UNDER NO CIRCUMSTANCES IS THIS TO BE ENTERED
   TO SPATIAL METADATA. Do this and you'll get the worst networks
   in the world.

DICTIONARY










###################################################################
# See if we have a segmentation image
# If none provided then run segmentation using either FAST or
# Atropos
###################################################################
routine                       @1   Extracting tissue masks
allValsCheck=0
declare           -A tissue_classes
tissue_classes=(  [gm]="grey matter"
                  [wm]="white matter"
                 [csf]="cerebrospinal fluid"
                [cort]="cerebral cortex" 
                [dgm]="deep gray matter")
for class in "${!tissue_classes[@]}"
   do
   ################################################################
   # Generate a binary mask if necessary.
   # This mask will be based on a user-specified input value and an
   # anatomical segmentation.
   ################################################################
   class_val='qcanat_'${class}'_val['${cxt}']'
   class_mask=${class}'Mask['${cxt}']'
   if is_image ${segmentationQA[cxt]} \
   && [[ -n ${!class_val} ]]
      then
      subroutine              @1.1a Successfully identified ${tissue_classes[$class]}
      if ! is_image ${!class_mask} \
      || rerun
         then
         subroutine           @1.1b Extracting ${tissue_classes[$class]}
         exec_xcp val2mask.R              \
            -i    ${segmentationQA[cxt]}  \
            -v    ${!class_val}           \
            -o    ${!class_mask}
      fi
      (( allValsCheck++ ))
   fi
done





###################################################################
# See if we have 3 segmentation masks
# If we don't have three run FAST | Atropos to create a quick seg
###################################################################
if (( ${allValsCheck} < 3))
   then
   subroutine                 @1.2a Failed to identify at least 3 tissue classes
   subroutine                 @1.2b Switching to automatic segmentation
   if [[ ${qcanat_seg[${cxt}]} == "FAST" ]] 
      then
      subroutine              @1.3  "Three-class priorless segmentation (FAST)"
      exec_fsl fast -g \
         -o    ${intermediate}-segmentation \
         ${struct[sub]}
      exec_sys mv ${intermediate}-segmentation_seg_0.nii.gz \
                  ${csfMask[cxt]}
      exec_sys mv ${intermediate}-segmentation_seg_1.nii.gz \
                  ${gmMask[cxt]}
      exec_sys mv ${intermediate}-segmentation_seg_2.nii.gz \
                  ${wmMask[cxt]}
   else
      subroutine              @1.4  "Three-class priorless segmentation (Atropos)"
      if ! is_image ${mask[sub]} ]]
         then
         subroutine           @1.5  Executing brain extraction
         exec_fsl bet ${struct[sub]} \
            ${intermediate}_BEmask.nii.gz
         exec_fsl fslmaths ${intermediate}_BEmask.nii.gz \
            -bin  ${intermediate}_BEmask.nii.gz
         define mask ${intermediate}_BEmask.nii.gz
      else
         subroutine           @1.6  Brain boundary located
         require  image mask
      fi
      subroutine              @1.7  Segmenting image
      atroposOut=${intermediate}-segmentation.nii.gz
      exec_ants   Atropos        \
         -d       3              \
         -a       ${struct[sub]} \
         -i       KMeans[3]      \
         -c       [5,0]          \
         -m       [0,1x1x1]      \
         -x       ${mask[cxt]}   \
         -o       [${atroposOut}]
      subroutine              @1.8  Extracting tissue classes
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
routine_end

###################################################################
# Now we need to create our foreground segmentation
# we need to make sure we have a transformation from MNI to our
# subject in order to perform this
###################################################################
if ! is_image ${foreground[cxt]} \
|| rerun
   then
   routine                    @2    Determining image foreground/background
   subroutine                 @2.1  Attempting warp to subject space
   exec_sys rm ${subCoords[cxt]}
   warpspace   ${mniCoords[cxt]}          \
               ${subCoords[cxt]}          \
               MNI%1x1x1:${space[sub]}    \
               0
   warpspace   ${mniFGMask[cxt]}          \
               ${intermediate}-fg.nii.gz  \
               MNI:${space[sub]}          \
               NearestNeighbor

   if ! is_image ${intermediate}-fg.nii.gz
      then
      subroutine              @2.2  Warp failed -- computing affine alignment to MNI
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
         -r       [${struc[sub]},${BRAINSPACE}/MNI/MNI-1x1x1.nii.gz,1] \
         -m       MI[${struc[sub]},${BRAINSPACE}/MNI/MNI-1x1x1.nii.gz,1,32,Regular,0.25] \
         --float  1 \
         --verbose 1

      #############################################################
      # Now apply the transformation to the MNI points
      #############################################################
      subroutine              @2.3  Aligning neck/nasal reference points
      exec_ants   antsApplyTransformsToPoints\
         -d       3                          \
         -i       ${XCPEDIR}/modules/qcanat/mniCoords.csv \
         -o       ${coordsCSV[cxt]}          \
         -t       ${affine_mni2sub[cxt]}
        
      #############################################################
      # Now apply this transformation to the MNI mask
      #############################################################
      subroutine              @2.4  Aligning MNI mask
      exec_ants   antsApplyTransforms        \
         -d       3                          \
         -i       ${mniFGMask[cxt]}          \
         -o       ${intermediate}-fg.nii.gz  \
         -r       ${struc[sub]}              \
         -n       NearestNeighbor            \
         -t       ${affine_mni2sub[${cxt}]}
   else
      exec_xcp    sclib2csv.R                \
         -i       ${subCoords[cxt]}          \
         -c       sclib2csv                  \
         -o       ${coordsCSV[cxt]}
   fi
     
   ################################################################
   # Now mask out the neck and nose from the background
   ################################################################
   subroutine                 @2.5  Removing neck and nose from background
   exec_xcp extendMaskInferior.R             \
      -i    ${intermediate}-fg.nii.gz        \
      -o    ${intermediate}-fg-extend.nii.gz \
      -c    ${coordsCSV[cxt]}

   ################################################################
   # Ensure that the sinuses are in the background 
   ################################################################
   subroutine                 @2.6  Classifying sinuses as background
   exec_fsl    fslmaths ${intermediate}-fg.nii.gz  \
      -mul     ${intermediate}-fg-extend.nii.gz    \
      -sub     1                                   \
      -abs     ${intermediate}-fg-3.nii.gz
   exec_ants   ImageMath 3         ${intermediate}-fg-4.nii.gz \
               GetLargestComponent ${intermediate}-fg-3.nii.gz
   exec_fsl    fslmaths ${intermediate}-fg-3.nii.gz \
      -sub              ${intermediate}-fg-4.nii.gz \
                        ${intermediate}-fg-5.nii.gz
   exec_fsl    fslmaths ${intermediate}-fg-extend.nii.gz \
      -sub              ${intermediate}-fg-5.nii.gz      \
                        ${foreground[cxt]}
   routine_end
fi

###################################################################
# Now calculate the quality metrics 
###################################################################
routine                       @3    Computing measures of anatomical quality
if is_image ${cortMask[cxt]}
   then
   subroutine                 @3.1  Using cortical mask
   argCortMask="-c ${cortMask[cxt]}"
fi
if is_image ${dgmMask[cxt]}
   then
   subroutine				  @3.2 Using DGM mask
   argDGMMask="-d ${dgmMask[cxt]}"
fi
qcvals=( $(exec_xcp qcanat.R  \
   -i    ${img_raw}           \
   -m    ${gmMask[cxt]}       \
   -w    ${wmMask[cxt]}       \
   -f    ${foreground[cxt]}   \
   ${argCortMask}) )		  \
   ${argDGMMask}
   
subroutine                    @3.2  Organising estimates
declare -A qcanat
for i in ${qcvals[@]}
   do
   var=$(strslice ${i} 1 :)
   val=$(strslice ${i} 2 :)
   qcanat[$var]=${val}
done
for i in ${!qcanat[@]}
   do
   qcfile=${i}'['${cxt}']'
   rm -f                   ${!qcfile}
   echo ${qcanat[$i]} >>   ${!qcfile}
done
routine_end





completion
