#!/usr/bin/env bash

###################################################################
#  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  #
###################################################################

###################################################################
# SPECIFIC MODULE HEADER
# This module preprocesses fMRI data.
###################################################################
mod_name_short=confound
mod_name='CONFOUND MODEL MODULE'
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
   
   write_output      confmat
   
   source ${XCPEDIR}/core/auditComplete
   source ${XCPEDIR}/core/updateQuality
   source ${XCPEDIR}/core/moduleEnd
}





###################################################################
# OUTPUTS
###################################################################
configure   confmat                 null

derivative  gmMask                  ${prefix}_gmMask
derivative  wmMask                  ${prefix}_wmMask
derivative  csfMask                 ${prefix}_csfMask

<< DICTIONARY

confmat
   A 1D file containing all global nuisance timeseries for the
   current subject, including any user-specified timeseries
   and previous time points, derivatives, and powers. While a 
   confound matrix file does not exist at the target path,
   confmat will store the string 'null' for the purposes
   of the mbind utility.
csfMask
   The final extracted, eroded, and transformed cerebrospinal
   fluid mask in subject functional space. Use to ensure
   quality.
gmMask
   The final extracted, eroded, and transformed grey matter
   mask in subject functional space. Use to ensure quality.
wmMask
   The final extracted, eroded, and transformed white matter
   mask in subject functional space. Use to ensure quality.

DICTIONARY










###################################################################
# Pool any transforms necessary for moving between standard and
# native space.
###################################################################
load_transforms
confmat_path=${outdir}/${prefix}_confmat.1D
routine                       @0    Generating confound matrix





###################################################################
# REALIGNMENT PARAMETERS
# Realignment parameters should have been computed using the MPR
# subroutine of the prestats module prior to their use in the
# confound matrix here.
###################################################################
if [[ ${confound_rp[${cxt}]} == Y ]]
   then
   subroutine                 @1    Including realignment parameters
   exec_xcp mbind.R \
      -x ${confmat[${cxt}]} \
      -y ${rps[${subjidx}]} \
      -o ${confmat_path}
   output confmat             ${prefix}_confmat.1D
fi





###################################################################
# RMS MOTION
# Relative RMS motion should have been computed during the MPR
# subroutine of the prestats module prior to its use here.
###################################################################
if [[ ${confound_rms[${cxt}]} == Y ]]
   then
   subroutine                 @2    Including relative RMS displacement
   exec_xcp mbind.R \
      -x ${confmat[${cxt}]} \
      -y ${relrms[${subjidx}]} \
      -o ${confmat_path}
   output confmat             ${prefix}_confmat.1D
fi





###################################################################
# Next, determine whether the user has specified any tissue-
# specific nuisance timecourses. If so, those timecourses must
# be computed as the mean BOLD timeseries over all voxels
# comprising the tissue class of interest.
#
# GREY MATTER
# First, determine whether to include the mean grey matter
# timeseries in the confound model. If the grey matter mask is to
# be included, then it must be conformed to user specifications:
#  * Extract the GM mask from the user-specified segmentation
#  * Erode the GM mask according to user specifications
#  * Move the GM mask into the same space as the primary BOLD
#    timeseries.
###################################################################
tissue_classes=( gm wm csf )
tissue_classes_long=( 'grey matter' 'white matter' 'cerebrospinal fluid' )
cc_components=0
for c in $(seq 1 ${#tissue_classes})
   do
   class=${tissue_classes[${c}]}
   class_name=${tissue_classes_long[${c}]}
   class_include='confound_'${class}'['${cxt}']'
   
   if [[ ${!class_include} == Y ]] \
   || is+numeric ${!class_include}
      then
      subroutine              @3    Including mean ${class_name} signal
      
      class_val='confound_'${class}'_val['${cxt}']'
      class_ero='confound_'${class}'_ero['${cxt}']'
      class_path='confound_'${class}'_path['${cxt}']'
      class_mask=${class}'Mask['${cxt}']'
      
      mask=${intermediate}_${class}
      #############################################################
      # Generate a binary mask if necessary.
      #############################################################
      if ! is_image ${mask}.nii.gz \
      || rerun
         then
         subroutine           @3.1
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
      if (( ${confound_gm_ero[${cxt}]} > 0 ))
         then
         subroutine           @3.2
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
      if [[ ${space} == standard ]]
         then
         subroutine           @3.3
         exec_ants antsApplyTransforms \
            -i ${mask}.nii.gz \
            -o ${!class_mask} \
            -r ${template} \
            -n NearestNeighbor \
            ${rigid} \
            ${affine} \
            ${warp} \
            ${resample}
      elif [[ ${space} == structural ]]
         then
         subroutine           @3.4
         exec_fsl immv ${mask}.nii.gz ${!class_mask}
      else
         subroutine           @3.5
         exec_ants antsApplyTransforms \
            -i ${mask}.nii.gz \
            -o ${!class_mask} \
            -r ${referenceVolumeBrain[${subjidx}]} \
            -n NearestNeighbor \
            -t ${struct2seq[${subjidx}]}
      fi
      
      #############################################################
      # Determine whether to extract a mean timecourse or to apply
      # aCompCor to extract PC timecourses.
      #############################################################
      ts=${intermediate}_phys_${class}
      if [[ ${!class_include} == Y ]]
         then
         ##########################################################
         # Extract the mean timecourse from the eroded and
         # transformed mask.
         ##########################################################
         subroutine           @3.6
         exec_fsl \
            fslmeants -i ${img} \
            -o ${ts}.1D \
            -m ${!class_mask}
         exec_xcp mbind.R \
            -x ${confmat[${cxt}]} \
            -y ${ts}.1D \
            -o ${confmat_path}
         output confmat       ${prefix}_confmat.1D
      elif is+integer ${!class_include}
         then
         ##########################################################
         # Use aCompCor to extract PC timecourses from the mask:
         # Fixed number of PCs.
         ##########################################################
         subroutine           @3.7
         exec_afni 3dpc \
            -prefix ${ts} \
            -pcsave ${!class_include} \
            -mask ${!class_mask} \
            ${img}
         (( cc_components++ ))
      elif [[ ${!class_include} == all ]]
         then
         ##########################################################
         # Use aCompCor to extract PC timecourses from the mask:
         # All principal components.
         # Please don't do this?
         ##########################################################
         subroutine           @3.8
         exec_afni 3dpc \
            -prefix ${ts} \
            -pcsave 99999 \
            -mask ${!class_mask} \
            ${img}
         vidx=$(tail -n1 ${ts}.1D|wc -w)
         cc_components=$(( ${cc_components} + ${vidx} ))
      elif is+numeric ${!class_include}
         then
         ##########################################################
         # Use aCompCor to extract PC timecourses from the mask:
         # Cumulative variance explained.
         ##########################################################
         subroutine           @3.9
         exec_afni 3dpc \
            -prefix ${ts} \
            -mask ${!class_mask} \
            ${img}
         variance_explained=$(tail -n+2 ${ts}_eig.1D|awk '{print $4}')
         vidx=1
         for v in ${variance_explained}
            do
            chk=$(arithmetic ${v}'>'${!class_include})
            (( ${chk} == 1 )) && break
            (( vidx++ ))
         done
         subroutine           @3.9a Retaining ${vidx} components from ${class_name}
         exec_afni 3dpc \
            -prefix ${ts} \
            -pcsave ${vidx} \
            -mask ${!class_mask} \
            ${img}
         cc_components=$(( ${cc_components} + ${vidx} ))
      fi
   else
         subroutine           @3.10
   fi
done





###################################################################
# MEAN GLOBAL SIGNAL
###################################################################
if [[ ${confound_gsr[${cxt}]} == Y ]]
   then
   subroutine                 @4    Including mean global signal
   ################################################################
   # Determine whether a brain mask exists for the current subject.
   #  * If one does, use it as the basis for computing the mean
   #    global timeseries.
   #  * If no mask exists, generate one using AFNI's 3dAutomask
   #    utility. This may yield unexpected results if data has
   #    been demeaned or standard-scored.
   ################################################################
   if is_image ${mask[${subjidx}]}
      then
      subroutine              @4.1
      maskpath=${mask[${subjidx}]}
   else
      subroutine              @4.2a Unable to identify mask
      subroutine              @4.2b Generating a mask using 3dAutomask
      maskpath=${intermediate}_mask.nii.gz
      exec_afni 3dAutomask \
         -prefix ${maskpath} \
         -dilate 3 \
         -q \
         ${referenceVolume[${subjidx}]}
   fi
   ################################################################
   # Extract the mean timecourse from the global (whole-brain)
   # mask, and catenate it into the confound matrix.
   ################################################################
   ts=${intermediate}_phys_gsr
   exec_fsl fslmeants -i ${img} -o ${ts} -m ${maskpath}
   exec_xcp mbind.R \
      -x ${confmat[${cxt}]} \
      -y ${ts} \
      -o ${confmat_path}
   output confmat             ${prefix}_confmat.1D
fi





###################################################################
# PRIOR TIME POINTS
# Prior time points are computed by passing the OPprev command to
# the mbind utility.
#
# Note the order in which supplementary timeseries are added to
# the confound matrix:
#   1. prior time points
#   2. temporal derivatives
#   3. powers
# So, be advised that adding temporal derivatives will also add
# temporal derivatives of previous time points, and adding powers
# will also add powers of derivatives (and powers of derivatives
# of previous time points)!
###################################################################
if (( ${confound_past[${cxt}]} > 0 ))
   then
   subroutine                 @5    "Including ${confound_past[${cxt}]} prior time point(s)"
   exec_xcp mbind.R \
      -x ${confmat[${cxt}]} \
      -y OPprev${confound_past[${cxt}]} \
      -o ${confmat_path}
   output confmat             ${prefix}_confmat.1D
fi





###################################################################
# TEMPORAL DERIVATIVES
# Temporal derivatives are computed by passing the OPdx command to
# the mbind utility.
#
# Note the order in which supplementary timeseries are added to
# the confound matrix:
#   1. prior time points
#   2. temporal derivatives
#   3. powers
# So, be advised that adding temporal derivatives will also add
# temporal derivatives of previous time points, and adding powers
# will also add powers of derivatives (and powers of derivatives
# of previous time points)!
###################################################################
if (( ${confound_dx[${cxt}]} > 0 ))
   then
   subroutine                 @6    "Including ${confound_dx[${cxt}]} derivative(s)"
   exec_xcp mbind.R \
      -x ${confmat[${cxt}]} \
      -y OPdx${confound_dx[${cxt}]} \
      -o ${confmat_path}
   output confmat             ${prefix}_confmat.1D
fi





###################################################################
# POWERS
# Powers of observations are computed by passing the OPpower
# command to the mbind utility.
#
# Note the order in which supplementary timeseries are added to
# the confound matrix:
#   1. prior time points
#   2. temporal derivatives
#   3. powers
# So, be advised that adding temporal derivatives will also add
# temporal derivatives of previous time points, and adding powers
# will also add powers of derivatives (and powers of derivatives
# of previous time points)!
###################################################################
if (( ${confound_sq[${cxt}]} > 1 ))
   then
   subroutine                 @7    "Including ${confound_sq[${cxt}]} power(s)"
   exec_xcp mbind.R \
      -x ${confmat[${cxt}]} \
      -y OPpower${confound_sq[${cxt}]} \
      -o ${confmat_path}
   output confmat             ${prefix}_confmat.1D
fi





###################################################################
# COMPONENT CORRECTION (COMPCOR)
###################################################################
if (( ${confound_cc[${cxt}]} > 0 ))
   then
   subroutine                 @8    "Including ${confound_cc[${cxt}]} CompCor signal(s)"
   ################################################################
   # Determine whether a brain mask exists for the current subject.
   #  * If one does, use it as the basis for computing nuisance
   #    components.
   #  * If no mask exists, generate one using AFNI's 3dAutomask
   #    utility. This may yield unexpected results if data has
   #    been demeaned or standard-scored.
   ################################################################
   if is_image ${mask[${subjidx}]}
      then
      subroutine              @8.1
      maskpath=${mask[${subjidx}]}
   elif ! is_image ${maskpath}
      then
      subroutine              @8.2  Unable to identify mask.
      subroutine              @8.3  Generating a mask using 3dAutomask
      maskpath=${intermediate}_mask.nii.gz
      exec_afni 3dAutomask \
         -prefix ${maskpath} \
         -dilate 3 \
         -q \
         ${referenceVolume[${subjidx}]}
   fi
   ################################################################
   # Perform CompCor using the ANTs ImageMath utility.
   #
   # ImageMath automatically includes global signal along with
   # CompCor; XCP Engine, by contrast, does not assume that a user
   # who includes CompCor necessarily also wishes to include the
   # global signal.
   ################################################################
   cc=${intermediate}_compcor.1D
   exec_ants ImageMath 4 ${intermediate}_confound.nii.gz \
      CompCorrAuto ${img} \
      ${maskpath} \
      ${confound_cc[${cxt}]}
   tail -n+2 ${intermediate}_confound_compcorr.csv \
      |cut -d"," -f1 --complement \
      |sed 's@,@\t@g' > ${cc}
   ################################################################
   # Add the component timeseries to the confound matrix.
   ################################################################
   exec_xcp mbind.R \
      -x ${confmat[${cxt}]} \
      -y ${cc} \
      -o ${confmat_path}
   output confmat             ${prefix}_confmat.1D
fi





###################################################################
# If aCompCor has been selected, bind the PC timeseries into the
# main confound matrix here so as not to add derivatives and
# power terms.
# TODO
# The limited customisability here will need to be
# addressed in the near future.
###################################################################
if is+numeric ${confound_gm[${cxt}]}
   then
   subroutine                 @9.1  "Including ${confound_gm[${cxt}]} GM aCompCor signal(s)"
   exec_xcp mbind.R \
      -x ${confmat[${cxt}]} \
      -y ${gm} \
      -o ${confmat_path}
   output confmat             ${prefix}_confmat.1D
fi
if is+numeric ${confound_wm[${cxt}]}
   then
   subroutine                 @9.2  "Including ${confound_wm[${cxt}]} WM aCompCor signal(s)"
   exec_xcp mbind.R \
      -x ${confmat[${cxt}]} \
      -y ${wm} \
      -o ${confmat_path}
   output confmat             ${prefix}_confmat.1D
fi
if is+numeric ${confound_csf[${cxt}]}
   then
   subroutine                 @9.3  "Including ${confound_csf[${cxt}]} CSF aCompCor signal(s)"
   exec_xcp mbind.R \
      -x ${confmat[${cxt}]} \
      -y ${csf} \
      -o ${confmat_path}
   output confmat             ${prefix}_confmat.1D
fi




###################################################################
# CUSTOM TIMESERIES
# * If none are specified, skip over this section.
# * These may include convolved or unconvolved stick/delta
#   functions encoding stimulus onset, duration, and magnitude.
# * These may be obtained directly from FSL's utilities as a
#   design matrix. If they are, only the timeseries (and not 
#   supplementary information such as peak magnitudes and total
#   duration) should be bound into the confound matrix.
# * Note that this is the very last step of confound matrix
#   assembly. Thus, any temporal derivatives, powers, previous
#   time points of custom timeseries should be included as custom
#   timeseries.
###################################################################
IFS='#' read -ra ${confound_custom_ts}<<<${confound_custom[${cxt}]}
nvol=$(exec_fsl fslnvols ${img})
for cts in ${confound_custom_ts[@]}
   do
   subroutine                 @10   "Custom timeseries: ${cts}"
   ################################################################
   # Determine whether the input is a three-column stick function
   # or an explicit timeseries. If it is a stick function, then
   # apply a convolution and convert it to a design matrix.
   ################################################################
   nlines=( $(exec_sys wc -l ${cts}) )
   stick=$(arithmetic ${nlines[0]}'<'${nvol})
   if (( ${stick} == 1 ))
      then
      subroutine              @10.1
      exec_xcp stick2lm.R \
         -i ${img} \
         -s ${cts} \
         -d FALSE \
         >> ${intermediate}convts.1D
   else
      subroutine              @10.2
      exec_sys cp ${cts} ${intermediate}convts.1D
   fi
   cts=${intermediate}convts.1D
   ################################################################
   # Identify the row in which the timeseries matrix proper
   # begins if the input is an FSL-style design matrix.
   ################################################################
   exec_xcp mbind.R \
      -x ${confmat[${cxt}]} \
      -y ${cts} \
      -o ${confmat_path}
   output confmat             ${prefix}_confmat.1D
   exec_sys rm -f ${outbase}convts.1D
done
routine_end





###################################################################
# Verify that the confound matrix produced by the confound module
# contains the expected number of time series.
###################################################################
obs=$(head -n1 ${confmat[${cxt}]}|wc -w)
exp=0
[[ ${confound_rp[${cxt}]}  == Y ]] && exp=$(( ${exp} + 6 ))
[[ ${confound_rms[${cxt}]} == Y ]] && exp=$(( ${exp} + 1 ))
[[ ${confound_gm[${cxt}]}  == Y ]] && exp=$(( ${exp} + 1 ))
[[ ${confound_wm[${cxt}]}  == Y ]] && exp=$(( ${exp} + 1 ))
[[ ${confound_csf[${cxt}]} == Y ]] && exp=$(( ${exp} + 1 ))
[[ ${confound_gsr[${cxt}]} == Y ]] && exp=$(( ${exp} + 1 ))
exp=$((  ${exp} + ${confound_cc[${cxt}]} ))
past=$(( ${confound_past[${cxt}]} + 1 ))
dx=$((   ${confound_dx[${cxt}]} + 1 ))
exp=$((  ${exp} * ${past} * ${dx} * ${confound_sq[${cxt}]} ))
exp=$((  ${exp} + ${cc_components} ))
for cts in ${confound_custom_ts[@]}
   do
   ctsn=$(tail -n1 ${cts}|wc -w)
   exp=$(( ${exp} + ${ctsn} ))
done
if (( ${obs} == ${exp} ))
   then
   subroutine                 @0.1
else
   subroutine                 @0.2  Dimensions of the existing confound matrix are incorrect
fi





subroutine                    @0.3
completion
