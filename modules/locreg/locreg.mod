#!/usr/bin/env bash

###################################################################
#  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  #
###################################################################

###################################################################
# SPECIFIC MODULE HEADER
# This module prepares voxelwise confounds.
###################################################################
mod_name_short=locreg
mod_name='VOXELWISE CONFOUND MODEL MODULE'
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
   write_derivative  gmMask
   write_derivative  wmMask
   write_derivative  csfMask
   write_derivative  gmLocal
   write_derivative  wmLocal
   write_derivative  csfLocal
   write_derivative  lmsLocal
   write_derivative  diffProcLocal
   
   source ${XCPEDIR}/core/auditComplete
   source ${XCPEDIR}/core/updateQuality
   source ${XCPEDIR}/core/moduleEnd
}





###################################################################
# OUTPUTS
###################################################################
derivative  gmMask                  ${prefix}_gmMask
derivative  wmMask                  ${prefix}_wmMask
derivative  csfMask                 ${prefix}_csfMask
derivative  gmLocal                 ${prefix}_gmLocal
derivative  wmLocal                 ${prefix}_wmLocal
derivative  csfLocal                ${prefix}_csfLocal
derivative  lmsLocal                ${prefix}_meanLocal
derivative  diffProcLocal           ${prefix}_diffProcLocal

derivative_config   gmLocal         Type              timeseries,confound
derivative_config   wmLocal         Type              timeseries,confound
derivative_config   csfLocal        Type              timeseries,confound
derivative_config   lmsLocal        Type              timeseries,confound
derivative_config   difmoLocal      Type              timeseries,confound

<<DICTIONARY

csfLocal
   A voxelwise confound based on the mean local cerebrospinal
   fluid timeseries.
csfMask
   The final extracted, eroded, and transformed cerebrospinal 
   fluid mask in subject functional space.
diffProcLocal
   [NYI] A voxelwise confound based on the difference between 
   the realigned timeseries and the acquired timeseries.
gmLocal
   A voxelwise confound based on the mean local grey matter 
   timeseries.
gmMask
   The final extracted, eroded, and transformed grey matter mask 
   in subject functional space.
lmsLocal
   A voxelwise confound based on the mean local timeseries.
wmLocal
   A voxelwise confound based on the mean local white matter 
   timeseries.
wmMask
   The final extracted, eroded, and transformed white matter mask 
   in subject functional space.

DICTIONARY










###################################################################
# Determine whether the user has specified any tissue-specific
# local nuisance timecourses. If so, those timecourses must
# be computed as the mean BOLD timeseries over nearby voxels
# comprising the tissue class of interest.
###################################################################
subroutine                    @0.1
load_transforms
tissue_classes=( gm wm csf )
tissue_classes_long=( 'grey matter' 'white matter' 'cerebrospinal fluid' )
for c in $(eval echo {0..${#tissue_classes}})
   do
   class=${tissue_classes[${c}]}
   class_name=${tissue_classes_long[${c}]}
   class_include='locreg_'${class}'['${cxt}']'
   if [[ ${!class_include} == Y ]]
      then
      routine                 @1    "Including local ${class_name} signal"
      
      class_val='locreg_'${class}'_val['${cxt}']'
      class_ero='locreg_'${class}'_ero['${cxt}']'
      class_path='locreg_'${class}'_path['${cxt}']'
      class_mask=${class}'Mask['${cxt}']'
      class_local=${class}'Local['${cxt}']'
      
      mask=${intermediate}_${class}
      #############################################################
      # Generate a binary mask if necessary.
      #############################################################
      if ! is_image ${mask}.nii.gz \
      || rerun
         then
         subroutine           @1.1  Determining tissue boundaries
         exec_sys rm -f ${mask}.nii.gz
         exec_xcp val2mask.R \
            -i ${!class_path} \
            -v ${!class_val} \
            -o ${mask}.nii.gz
      fi
      #############################################################
      # Erode the mask iteratively, ensuring that the result of
      # applying the specified erosion is non-empty.
      #############################################################
      if (( ${!class_ero} > 0 ))
         then
         subroutine           @1.2  Excluding superficial regions
         exec_xcp erodespare \
            -i ${mask}.nii.gz \
            -o ${mask}_ero.nii.gz \
            -e ${!class_ero} \
            ${traceprop}
         mask=${mask}_ero
      fi
      #############################################################
      # Move the mask from subject structural space to subject
      # EPI space. If the BOLD timeseries is already standardised,
      # then instead move it to standard space.
      #############################################################
      source ${XCPEDIR}/core/mapToSpace \
         str2${space} \
         ${mask}.nii.gz \
         ${!class_mask} \
         NearestNeighbor
      if ! is_image ${!class_local} \
      || rerun
         then
         subroutine           @1.3a Modelling voxelwise ${class_name} signal
         subroutine           @1.3b Radius of influence: ${locreg_gm_rad[${cxt}]} mm
         exec_sys rm -f ${!class_local}
         exec_afni 3dLocalstat \
            -prefix ${!class_local} \
            -nbhd 'SPHERE('"${locreg_gm_rad[${cxt}]}"')' \
            -stat mean \
            -mask ${!class_mask} \
            -use_nonmask \
            ${img}
         ##########################################################
         # . . . and confine the nuisance signal to the existing
         # brain mask.
         ##########################################################
         exec_fsl fslmaths ${!class_local} \
            -mul ${mask[${subjidx}]} \
            ${!class_local}
      fi
      routine_end
   fi
done





###################################################################
# Local mean signal
###################################################################
if [[ ${locreg_lms[${cxt}]} == Y ]]
   then
   if ! is_image ${lmsLoc[${cxt}]} \
   || rerun
      then
      routine                 @2    "Including mean local signal in confound model."
      subroutine              @2.1  "Modelling local signal: All voxels"
      subroutine              @2.2  Radius of influence: ${locreg_lms_rad[${cxt}]}
      exec_sys rm -f ${lmsLocal[${cxt}]}
      exec_afni 3dLocalstat \
         -prefix ${lmsLocal[${cxt}]} \
         -nbhd 'SPHERE('"${locreg_lms_rad[${cxt}]}"')' \
         -stat mean \
         -mask ${mask[${subjidx}]} \
         -use_nonmask \
         ${img}
      #############################################################
      # . . . and confine the nuisance signal to the existing
      # brain mask.
      #############################################################
      exec_fsl fslmaths ${lmsLocal[${cxt}]} \
         -mul ${mask[${subjidx}]} \
         ${lmsLocal[${cxt}]}
      routine_end
   fi
fi





subroutine                    @0.2
completion
