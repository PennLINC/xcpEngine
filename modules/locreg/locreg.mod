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
   processed         final
   
   write_derivative  ic_maps
   write_derivative  ic_maps_thr
   write_derivative  ic_maps_thr_std
   
   write_output      melodir
   write_output      ic_class
   write_output      ic_mix
   
   quality_metric    numICsNoise             ic_noise
   
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
derivative  gmLoc                   ${prefix}_gmLocal
derivative  wmLoc                   ${prefix}_wmLocal
derivative  csfLoc                  ${prefix}_csfLocal
derivative  lmsLoc                  ${prefix}_meanLocal
derivative  difmoLoc               ${prefix}_diffProcLocal

derivative_config   gm_loc          Type              timeseries,confound
derivative_config   wm_loc          Type              timeseries,confound
derivative_config   csf_loc         Type              timeseries,confound
derivative_config   lms_loc         Type              timeseries,confound
derivative_config   difmo_loc       Type              timeseries,confound

<<DICTIONARY

csf_loc
   A voxelwise confound based on the mean local cerebrospinal
   fluid timeseries.
csf_mask
   The final extracted, eroded, and transformed cerebrospinal 
   fluid mask in subject functional space.
difmo_loc
   [NYI] A voxelwise confound based on the difference between 
   the realigned timeseries and the acquired timeseries.
gm_loc
   A voxelwise confound based on the mean local grey matter 
   timeseries.
gm_mask
   The final extracted, eroded, and transformed grey matter mask 
   in subject functional space.
lms_loc
   A voxelwise confound based on the mean local timeseries.
wm_loc
   A voxelwise confound based on the mean local white matter 
   timeseries.
wm_mask
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
for c in $(eval_echo {0..${#tissue_classes}})
   do
   class=${tissue_classes[${c}]}
   class_name=${tissue_classes_long[${c}]}
   class_include='locreg_'${class}'['${cxt}']'
   if [[ ${!class_include} == Y ]]
      then
      routine                 @1    "Including local ${!class_name} signal"
      
      class_val='locreg_'${class}'_val['${cxt}']'
      class_ero='locreg_'${class}'_ero['${cxt}']'
      class_path='locreg_'${class}'_path['${cxt}']'
      class_mask=${class}'Mask['${cxt}']'
      class_local=${class}'Loc['${cxt}']'
      
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
         subroutine           @1.3a Computing voxelwise tissue signal
         subroutine           @1.3b Radius of influence: ${locreg_gm_rad[${cxt}]}
         exec_sys rm -f ${!class_local}
         exec_afni 3dLocalstat \
            -prefix ${!class_local} \
            -nbhd 'SPHERE('"${locreg_gm_rad[${cxt}]}"')' \
            -stat mean \
            -mask ${!class_mask} \
            -use_nonmask \
            ${img} \
            2>/dev/null
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
   if ! is_image ${lmsLoc[${cxt}]} \
   || rerun
      then
      routine                 @2    "Including mean local signal in confound model."
      subroutine              @2.1  "Generating local regressor: All voxels"
      subroutine              @2.2  Radius of influence: ${locreg_lms_rad[${cxt}]}
      exec_sys rm -f ${lmsLoc[${cxt}]}
      exec_afni 3dLocalstat \
         -prefix ${lmsLoc[${cxt}]} \
         -nbhd 'SPHERE('"${locreg_lms_rad[${cxt}]}"')' \
         -stat mean \
         -mask ${mask[${subjidx}]} \
         -use_nonmask \
         ${img} \
         2>/dev/null
      #############################################################
      # . . . and confine the nuisance signal to the existing
      # brain mask.
      #############################################################
      exec_fsl fslmaths ${lmsLoc[${cxt}]} \
         -mul ${mask[${subjidx}]} \
         ${lmsLoc[${cxt}]}
      routine_end
   fi
fi





subroutine                    @0.2
completion
