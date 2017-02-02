#!/usr/bin/env bash

###################################################################
#  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  #
###################################################################

###################################################################
# Constants
# None yet
###################################################################





###################################################################
###################################################################
# BEGIN GENERAL MODULE HEADER
###################################################################
###################################################################
# Read in:
#  * path to localised design file
#  * overall context in pipeline
#  * whether to explicitly trace all commands
# Trace status is, by default, set to 0 (no trace)
###################################################################
trace=0
while getopts "d:c:t:" OPTION
   do
   case $OPTION in
   d)
      design_local=${OPTARG}
      ;;
   c)
      cxt=${OPTARG}
      ! [[ ${cxt} =~ $POSINT ]] && ${XCPEDIR}/xcpModusage mod && exit
      ;;
   t)
      trace=${OPTARG}
      if [[ ${trace} != "0" ]] && [[ ${trace} != "1" ]]
         then
         ${XCPEDIR}/xcpModusage mod
         exit
      fi
      ;;
   *)
      echo "Option not recognised: ${OPTARG}"
      ${XCPEDIR}/xcpModusage mod
      exit
   esac
done
shift $((OPTIND-1))
###################################################################
# Ensure that the compulsory design_local variable has been defined
###################################################################
[[ -z ${design_local} ]] && ${XCPEDIR}/xcpModusage mod && exit
[[ ! -e ${design_local} ]] && ${XCPEDIR}/xcpModusage mod && exit
###################################################################
# Set trace status, if applicable
# If trace is set to 1, then all commands called by the pipeline
# will be echoed back in the log file.
###################################################################
[[ ${trace} == "1" ]] && set -x
###################################################################
# Initialise the module.
###################################################################
echo ""; echo ""; echo ""
echo "################################################################### "
echo "#  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  #"
echo "#                                                                 #"
echo "#  ☭            EXECUTING VOXELWISE CONFOUND MODULE            ☭  #"
echo "#                                                                 #"
echo "#  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  #"
echo "###################################################################"
echo ""
###################################################################
# Source the design file.
###################################################################
source ${design_local}
###################################################################
# Verify that all compulsory inputs are present.
###################################################################
if [[ $(imtest ${out}/${prefix}) != 1 ]]
   then
   echo "::XCP-ERROR: The primary input is absent."
   exit 666
fi
###################################################################
# Create a directory for intermediate outputs.
###################################################################
[[ ${NUMOUT} == 1 ]] && prep=${cxt}_
outdir=${out}/${prep}locreg
[[ ! -e ${outdir} ]] && mkdir -p ${outdir}
echo "Output directory is $outdir"
###################################################################
# Define paths to all potential outputs.

# For the locreg module, potential outputs include:
#  * gmmask : The final extracted, eroded, and transformed grey
#    matter mask in subject functional space. Use to ensure
#    quality.
#  * gm_loc : A voxelwise confound based on the mean local grey
#    matter timeseries.
#  * wmmask : The final extracted, eroded, and transformed white
#    matter mask in subject functional space. Use to ensure
#    quality.
#  * wm_loc : A voxelwise confound based on the mean local white
#    matter timeseries.
#  * csfmask : The final extracted, eroded, and transformed
#    cerebrospinal fluid mask in subject functional space. Use to
#    ensure quality.
#  * csf_loc : A voxelwise confound based on the mean local
#    cerebrospinal fluid timeseries.
#  * lms_loc : A voxelwise confound based on the mean local
#    timeseries.
#TODO
#  * difmo_loc : A voxelwise confound based on the difference
#    between the realigned timeseries and the acquired timeseries.
#  * locregs : An index of paths to all voxelwise confound
#    timeseries.
###################################################################
gm_mask[${cxt}]=${outdir}/${prefix}_maskgm
wm_mask[${cxt}]=${outdir}/${prefix}_maskwm
csf_mask[${cxt}]=${outdir}/${prefix}_maskcsf
gm_loc[${cxt}]=${outdir}/${prefix}_locGM
wm_loc[${cxt}]=${outdir}/${prefix}_locWM
csf_loc[${cxt}]=${outdir}/${prefix}_locCSF
lms_loc[${cxt}]=${outdir}/${prefix}_locLMS
difmo_loc[${cxt}]=${outdir}/${prefix}_locDifMo
locregs[${cxt}]=${outdir}/${prefix}_locregs
rm -f ${locregs[${cxt}]}
###################################################################
# * Initialise a pointer to the image.
# * Ensure that the pointer references an image, and not something
#   else such as a design file.
# * On the basis of this, define the image extension to be used for
#   this module (for operations, such as AFNI, that require an
#   extension).
# * Localise the image using a symlink, if applicable.
# * Define the base output path for intermediate files.
###################################################################
img=${out}/${prefix}
imgpath=$(ls ${img}.*)
for i in ${imgpath}
   do
   [[ $(imtest ${i}) == 1 ]] && imgpath=${i} && break
done
ext=$(echo ${imgpath}|sed s@${img}@@g)
[[ ${ext} == ".nii.gz" ]] && export FSLOUTPUTTYPE=NIFTI_GZ
[[ ${ext} == ".nii" ]] && export FSLOUTPUTTYPE=NIFTI
[[ ${ext} == ".hdr" ]] && export FSLOUTPUTTYPE=NIFTI_PAIR
[[ ${ext} == ".img" ]] && export FSLOUTPUTTYPE=NIFTI_PAIR
[[ ${ext} == ".hdr.gz" ]] && export FSLOUTPUTTYPE=NIFTI_PAIR_GZ
[[ ${ext} == ".img.gz" ]] && export FSLOUTPUTTYPE=NIFTI_PAIR_GZ
outbase=${outdir}/${prefix}~TEMP~
###################################################################
# Prime the localised design file so that any outputs from this
# module appear beneath the correct header.
###################################################################
echo "" >> $design_local
echo "# *** outputs from locreg[${cxt}] *** #" >> $design_local
echo "" >> $design_local
###################################################################
# It is always assumed that this module should re-run.
#
# Each local confound is checked separately to determine whether
# it should be recalculated.
###################################################################
###################################################################
# END GENERAL MODULE HEADER
###################################################################
###################################################################





###################################################################
# Obtain all transforms required to ensure that tissue
# segmentations are in the analytic space.
###################################################################
coreg="-t ${seq2struct[${subjidx}]}"
icoreg="-t ${struct2seq[${subjidx}]}"
if [[ ! -z ${xfm_warp} ]] \
   && [[ $(imtest "${xfm_warp}") == 1 ]]
   then
	warp="-t ${xfm_warp}"
	iwarp="-t ${ixfm_warp}"
fi
if [[ ! -z ${xfm_affine} ]]
	then
	affine="-t ${xfm_affine}"
	iaffine="-t [${xfm_affine},1]"
fi
if [[ ! -z ${xfm_rigid} ]]
	then
	rigid="-t ${xfm_rigid}"
	irigid="-t [${xfm_rigid},1]"
fi
if [[ ! -z ${xfm_resample} ]]
	then
	resample="-t ${xfm_resample}"
	iresample="-t [${xfm_resample},1]"
fi





###################################################################
# Grey matter
#  -> Compute mask
###################################################################
if [[ "${locreg_gm[${cxt}]}" == "Y" ]] \
   && [[ $(imtest ${gm_mask[${cxt}]}) != 1 || ${locreg_rerun[${cxt}]} == Y ]]
   then
   echo "Including mean grey matter signal in confound model."
   echo " * Generating tissue mask in analytic space."
   ################################################################
   # 1. Extract relevant values
   ################################################################
   rm -f ${gm_mask[${cxt}]}${ext}
   ${XCPEDIR}/utils/val2mask.R \
      -i ${locreg_gm_path[${cxt}]} \
      -v ${locreg_gm_val[${cxt}]} \
      -o ${outbase}_gm${ext}
   gmmask=${outbase}_gm
   ################################################################
   # 2. Apply erosions, if requested
   ################################################################
   if [[ ${locreg_gm_ero[${cxt}]} -gt 0 ]]
      then
      [[ ${trace} == 1 ]] && traceprop="-t"
      ${XCPEDIR}/utils/erodespare \
         -i ${outbase}_gm${ext} \
         -o ${outbase}_gm_ero${ext} \
         -e ${locreg_gm_ero[${cxt}]} \
         ${traceprop}
      gmmask=${outbase}_gm_ero
   fi
   ################################################################
   # 3. Align image space
   ################################################################
   case ${space} in
   ################################################################
   # If the analyte image is in native space, then only the
   # inverse coregistration is necessary to move the structural
   # segmentation into analytic space.
   ################################################################
   native)
      rm -f ${gm_mask[${cxt}]}${ext}
      ${ANTSPATH}/antsApplyTransforms \
         -e 3 -d 3 \
         -i ${gmmask}${ext} \
         -o ${gm_mask[${cxt}]}${ext} \
         -r ${referenceVolumeBrain[${subjidx}]}${ext} \
         $icoreg \
         -n NearestNeighbor
      ;;
   ################################################################
   # If the analyte image is in standard space, then all forward
   # transformations other than the coregistration are necessary
   # to move the structural segmentation into analytic space.
   ################################################################
   standard)
      rm -f ${gm_mask[${cxt}]}${ext}
      ${ANTSPATH}/antsApplyTransforms \
         -e 3 -d 3 \
         -i ${gmmask}${ext} \
         -o ${gm_mask[${cxt}]}${ext} \
         -r ${template} \
         $rigid \
         $affine \
         $warp \
         $resample \
         -n NearestNeighbor
      ;;
   esac
fi
###################################################################
# Grey matter
#  -> Generate voxelwise confound
###################################################################
if [[ "${locreg_gm[${cxt}]}" == "Y" ]] \
   && [[ $(imtest ${gm_loc[${cxt}]}) != 1 || ${locreg_rerun[${cxt}]} == Y ]]
   then
   echo " * Generating local tissue-based regressor"
   echo " * Radius of influence: ${locreg_gm_rad[${cxt}]}"
   rm -f ${lms_gm[${cxt}]}${ext}
   3dLocalstat \
      -prefix ${gm_loc[${cxt}]}${ext} \
      -nbhd 'SPHERE('"${locreg_gm_rad[${cxt}]}"')' \
      -stat mean \
      -mask ${gm_mask[${cxt}]}${ext} \
      -use_nonmask \
      ${img}${ext} \
      2>/dev/null
fi
###################################################################
# Grey matter
#  -> Write output
###################################################################
if [[ "${locreg_gm[${cxt}]}" == "Y" ]] \
   && [[ $(imtest ${gm_loc[${cxt}]}) == 1 ]]
   then
   echo "#locGM#${gm_loc[${cxt}]}" >> ${auxImgs[${subjidx}]}
   echo ${gm_loc[${cxt}]} >> ${locregs[${cxt}]}
fi





###################################################################
# White matter
#  -> Compute mask
###################################################################
if [[ "${locreg_wm[${cxt}]}" == "Y" ]] \
   && [[ $(imtest ${wm_mask[${cxt}]}) != 1 || ${locreg_rerun[${cxt}]} == Y ]]
   then
   echo "Including mean white matter signal in confound model."
   echo " * Generating tissue mask in analytic space."
   ################################################################
   # 1. Extract relevant values
   ################################################################
   rm -f ${wm_mask[${cxt}]}${ext}
   ${XCPEDIR}/utils/val2mask.R \
      -i ${locreg_wm_path[${cxt}]} \
      -v ${locreg_wm_val[${cxt}]} \
      -o ${outbase}_wm${ext}
   wmmask=${outbase}_wm
   ################################################################
   # 2. Apply erosions, if requested
   ################################################################
   if [[ ${locreg_wm_ero[${cxt}]} -gt 0 ]]
      then
      [[ ${trace} == 1 ]] && traceprop="-t"
      ${XCPEDIR}/utils/erodespare \
         -i ${outbase}_wm${ext} \
         -o ${outbase}_wm_ero${ext} \
         -e ${locreg_wm_ero[${cxt}]} \
         ${traceprop}
      wmmask=${outbase}_wm_ero
   fi
   ################################################################
   # 3. Align image space
   ################################################################
   case ${space} in
   ################################################################
   # If the analyte image is in native space, then only the
   # inverse coregistration is necessary to move the structural
   # segmentation into analytic space.
   ################################################################
   native)
      rm -f ${wm_mask[${cxt}]}${ext}
      ${ANTSPATH}/antsApplyTransforms \
         -e 3 -d 3 \
         -i ${wmmask}${ext} \
         -o ${wm_mask[${cxt}]}${ext} \
         -r ${referenceVolumeBrain[${subjidx}]}${ext} \
         $icoreg \
         -n NearestNeighbor
      ;;
   ################################################################
   # If the analyte image is in standard space, then all forward
   # transformations other than the coregistration are necessary
   # to move the structural segmentation into analytic space.
   ################################################################
   standard)
      rm -f ${wm_mask[${cxt}]}${ext}
      ${ANTSPATH}/antsApplyTransforms \
         -e 3 -d 3 \
         -i ${wmmask}${ext} \
         -o ${wm_mask[${cxt}]}${ext} \
         -r ${template} \
         $rigid \
         $affine \
         $warp \
         $resample \
         -n NearestNeighbor
      ;;
   esac
fi
###################################################################
# White matter
#  -> Generate voxelwise confound
###################################################################
if [[ "${locreg_wm[${cxt}]}" == "Y" ]] \
   && [[ $(imtest ${wm_loc[${cxt}]}) != 1 || ${locreg_rerun[${cxt}]} == Y ]]
   then
   echo " * Generating local tissue-based regressor"
   echo " * Radius of influence: ${locreg_wm_rad[${cxt}]}"
   rm -f ${wm_loc[${cxt}]}${ext}
   3dLocalstat \
      -prefix ${wm_loc[${cxt}]}${ext} \
      -nbhd 'SPHERE('"${locreg_wm_rad[${cxt}]}"')' \
      -stat mean \
      -mask ${wm_mask[${cxt}]}${ext} \
      -use_nonmask \
      ${img}${ext} \
      2>/dev/null
fi
###################################################################
# White matter
#  -> Write output
###################################################################
if [[ "${locreg_wm[${cxt}]}" == "Y" ]] \
   && [[ $(imtest ${wm_loc[${cxt}]}) == 1 ]]
   then
   echo "#locWM#${wm_loc[${cxt}]}" >> ${auxImgs[${subjidx}]}
   echo ${wm_loc[${cxt}]}${ext} >> ${locregs[${cxt}]}
fi





###################################################################
# Cerebrospinal fluid
#  -> Compute mask
###################################################################
if [[ "${locreg_csf[${cxt}]}" == "Y" ]] \
   && [[ $(imtest ${csf_mask[${cxt}]}) != 1 || ${locreg_rerun[${cxt}]} == Y ]]
   then
   echo "Including mean cerebrospinal fluid signal in confound model."
   echo " * Generating tissue mask in analytic space."
   ################################################################
   # 1. Extract relevant values
   ################################################################
   rm -f ${csf_mask[${cxt}]}${ext}
   ${XCPEDIR}/utils/val2mask.R \
      -i ${locreg_csf_path[${cxt}]} \
      -v ${locreg_csf_val[${cxt}]} \
      -o ${outbase}_csf${ext}
   csfmask=${outbase}_csf
   ################################################################
   # 2. Apply erosions, if requested
   ################################################################
   if [[ ${locreg_csf_ero[${cxt}]} -gt 0 ]]
      then
      [[ ${trace} == 1 ]] && traceprop="-t"
      ${XCPEDIR}/utils/erodespare \
         -i ${outbase}_csf${ext} \
         -o ${outbase}_csf_ero${ext} \
         -e ${locreg_csf_ero[${cxt}]} \
         ${traceprop}
      csfmask=${outbase}_csf_ero
   fi
   ################################################################
   # 3. Align image space
   ################################################################
   case ${space} in
   ################################################################
   # If the analyte image is in native space, then only the
   # inverse coregistration is necessary to move the structural
   # segmentation into analytic space.
   ################################################################
   native)
      rm -f ${csf_mask[${cxt}]}${ext}
      ${ANTSPATH}/antsApplyTransforms \
         -e 3 -d 3 \
         -i ${csfmask}${ext} \
         -o ${csf_mask[${cxt}]}${ext} \
         -r ${referenceVolumeBrain[${subjidx}]}${ext} \
         $icoreg \
         -n NearestNeighbor
      ;;
   ################################################################
   # If the analyte image is in standard space, then all forward
   # transformations other than the coregistration are necessary
   # to move the structural segmentation into analytic space.
   ################################################################
   standard)
      rm -f ${csf_mask[${cxt}]}${ext}
      ${ANTSPATH}/antsApplyTransforms \
         -e 3 -d 3 \
         -i ${csfmask}${ext} \
         -o ${csf_mask[${cxt}]}${ext} \
         -r ${template} \
         $rigid \
         $affine \
         $warp \
         $resample \
         -n NearestNeighbor
      ;;
   esac
fi
###################################################################
# Cerebrospinal fluid
#  -> Generate voxelwise confound
###################################################################
if [[ "${locreg_csf[${cxt}]}" == "Y" ]] \
   && [[ $(imtest ${csf_loc[${cxt}]}) != 1 || ${locreg_rerun[${cxt}]} == Y ]]
   then
   echo " * Generating local tissue-based regressor"
   echo " * Radius of influence: ${locreg_csf_rad[${cxt}]}"
   rm -f ${csf_loc[${cxt}]}${ext}
   3dLocalstat \
      -prefix ${csf_loc[${cxt}]}${ext} \
      -nbhd 'SPHERE('"${locreg_csf_rad[${cxt}]}"')' \
      -stat mean \
      -mask ${csf_mask[${cxt}]}${ext} \
      -use_nonmask \
      ${img}${ext} \
      2>/dev/null
fi
###################################################################
# Cerebrospinal fluid
#  -> Write output
###################################################################
if [[ "${locreg_csf[${cxt}]}" == "Y" ]] \
   && [[ $(imtest ${csf_loc[${cxt}]}) == 1 ]]
   then
   echo "#locCSF#${csf_loc[${cxt}]}" >> ${auxImgs[${subjidx}]}
   echo ${csf_loc[${cxt}]}${ext} >> ${locregs[${cxt}]}
fi





###################################################################
# Local mean signal
#  -> Generate voxelwise confound
###################################################################
if [[ "${locreg_lms[${cxt}]}" == "Y" ]] \
   && [[ $(imtest ${lms_loc[${cxt}]}) != 1 || ${locreg_rerun[${cxt}]} == Y ]]
   then
   echo "Including mean local signal in confound model."
   echo " * Generating local regressor: All voxels"
   echo " * Radius of influence: ${locreg_lms_rad[${cxt}]}"
   rm -f ${lms_loc[${cxt}]}${ext}
   3dLocalstat \
      -prefix ${lms_loc[${cxt}]}${ext} \
      -nbhd 'SPHERE('"${locreg_lms_rad[${cxt}]}"')' \
      -stat mean \
      -mask ${mask[${subjidx}]}${ext} \
      -use_nonmask \
      ${img}${ext} \
      2>/dev/null
fi
###################################################################
# Local mean signal
#  -> Write output
###################################################################
if [[ "${locreg_lms[${cxt}]}" == "Y" ]] \
   && [[ $(imtest ${lms_loc[${cxt}]}) == 1 ]]
   then
   echo "#locLMS#${lms_loc[${cxt}]}" >> ${auxImgs[${subjidx}]}
   echo ${lms_loc[${cxt}]}${ext} >> ${locregs[${cxt}]}
fi





###################################################################
# write remaining output paths to local design file so that
# they may be used further along the pipeline
###################################################################
echo ""; echo ""; echo ""
echo "Writing outputs..."
echo "locregs[${subjidx}]=${locregs[${cxt}]}" >> $design_local





###################################################################
# CLEANUP
#  * Remove any temporary files if cleanup is enabled.
#  * Update the audit file to reflect completion of the module.
###################################################################
img=$(readlink -f ${img}${ext})
if [[ "${locreg_cleanup[${cxt}]}" == "Y" ]]
   then
   echo ""; echo ""; echo ""
   echo "Cleaning up..."
   rm -rf ${outdir}/*~TEMP~*
fi
prefields=$(echo $(grep -o "_" <<< $prefix|wc -l) + 1|bc)
modaudit=$(expr ${prefields} + ${cxt} + 1)
subjaudit=$(grep -i $(echo ${prefix}|sed s@'_'@','@g) ${audit})
replacement=$(echo ${subjaudit}\
   |sed s@[^,]*@@${modaudit}\
   |sed s@',,'@',1,'@ \
   |sed s@',$'@',1'@g)
sed -i s@${subjaudit}@${replacement}@g ${audit}

echo "Module complete"
