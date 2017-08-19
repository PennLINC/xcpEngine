#!/usr/bin/env bash

###################################################################
#  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  #
###################################################################

###################################################################
# SPECIFIC MODULE HEADER
# This module assembles a model of nuisance timeseries.
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
   write_derivative  gmLocal
   write_derivative  wmLocal
   write_derivative  csfLocal
   write_derivative  lmsLocal
   
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
derivative  gmLocal                 ${prefix}_gmLocal
derivative  wmLocal                 ${prefix}_wmLocal
derivative  csfLocal                ${prefix}_csfLocal
derivative  lmsLocal                ${prefix}_meanLocal

derivative_config   gmLocal         Type              timeseries-confound
derivative_config   wmLocal         Type              timeseries-confound
derivative_config   csfLocal        Type              timeseries-confound
derivative_config   lmsLocal        Type              timeseries-confound

<< DICTIONARY

confmat
   A 1D file containing all global nuisance timeseries for the
   current subject, including any user-specified timeseries
   and previous time points, derivatives, and powers. While a 
   confound matrix file does not exist at the target path,
   confmat will store the string 'null' for the purposes
   of the mbind utility.
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










confmat_path=${outdir}/${prefix}_confmat.1D
routine                       @0    Generating confound matrix





###################################################################
# REALIGNMENT PARAMETERS
# Realignment parameters should have been computed using the MPR
# subroutine of the prestats module prior to their use in the
# confound matrix here.
###################################################################
if (( ${confound_rp[cxt]} == 1 ))
   then
   subroutine                 @1    [Including realignment parameters]
   exec_xcp mbind.R \
      -x ${confmat[cxt]} \
      -y ${rps[sub]} \
      -o ${confmat_path}
   output confmat             ${prefix}_confmat.1D
fi





###################################################################
# RMS MOTION
# Relative RMS motion should have been computed during the MPR
# subroutine of the prestats module prior to its use here.
###################################################################
if (( ${confound_rms[cxt]} == 1 ))
   then
   subroutine                 @2    Including relative RMS displacement
   exec_xcp mbind.R \
      -x ${confmat[cxt]} \
      -y ${relrms[sub]} \
      -o ${confmat_path}
   output confmat             ${prefix}_confmat.1D
fi





###################################################################
# Next, determine whether the user has specified any tissue-
# specific nuisance timecourses. If so, those timecourses must
# be computed as the mean BOLD timeseries over all voxels
# comprising the tissue class of interest.
#
# First, determine whether to include the mean tissue confound
# timeseries in the confound model. If the tissue mask is to
# be included, then it must be conformed to user specifications:
#  * Extract the mask from the user-specified segmentation
#  * Erode the mask according to user specifications
#  * Move the mask into the same space as the primary BOLD
#    timeseries.
###################################################################
declare           -A tissue_classes
tissue_classes=(  [gm]="grey matter"
                  [wm]="white matter"
                 [csf]="cerebrospinal fluid" )
cc_components=0
for class in "${!tissue_classes[@]}"
   do
   class_name=${tissue_classes[$class]}
   class_include='confound_'${class}'['${cxt}']'
   
   if [[ ${!class_include} != N ]]
      then
      subroutine              @3    [Including ${class_name} signal]
      
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
         exec_sys    rm -f    ${mask}.nii.gz
         exec_xcp    val2mask.R \
            -i       ${!class_path} \
            -v       ${!class_val} \
            -o       ${mask}.nii.gz
      fi
      #############################################################
      # Erode the mask iteratively, ensuring that the result of
      # applying the specified erosion is non-empty.
      #############################################################
      if (( ${!class_ero} > 0 ))
         then
         subroutine           @3.2
         exec_xcp erodespare \
            -i    ${mask}.nii.gz \
            -o    ${mask}_ero.nii.gz \
            -e    ${!class_ero} \
            ${traceprop}
         mask=${mask}_ero
      fi
      #############################################################
      # Move the mask from subject structural space to subject
      # EPI space. If the BOLD timeseries is already standardised,
      # then instead move it to standard space.
      #############################################################
      warpspace \
         ${mask}.nii.gz \
         ${!class_mask} \
         ${structural[sub]}:${space[sub]} \
         NearestNeighbor
      #############################################################
      # Determine whether to extract a mean timecourse or to apply
      # aCompCor to extract PC timecourses.
      #############################################################
      ts=${intermediate}_phys_${class}
      eval  "${class}=${ts}.1D"
      if [[ ${!class_include} == mean ]]
         then
         ##########################################################
         # Extract the mean timecourse from the eroded and
         # transformed mask.
         ##########################################################
         subroutine           @3.6
         exec_fsl \
            fslmeants   -i ${img} \
            -o          ${ts}.1D \
            -m          ${!class_mask}
         exec_xcp mbind.R \
            -x    ${confmat[cxt]} \
            -y    ${ts}.1D \
            -o    ${confmat_path}
         output   confmat        ${prefix}_confmat.1D
      elif is+integer ${!class_include}
         then
         ##########################################################
         # Use aCompCor to extract PC timecourses from the mask:
         # Fixed number of PCs.
         ##########################################################
         subroutine           @3.7
         exec_afni      3dpc \
            -prefix     ${ts} \
            -pcsave     ${!class_include} \
            -mask       ${!class_mask} \
            ${img}
         cc_components=$(( ${cc_components} + ${!class_include} ))
      elif [[ ${!class_include} == all ]]
         then
         ##########################################################
         # Use aCompCor to extract PC timecourses from the mask:
         # All principal components.
         # Please don't do this?
         ##########################################################
         subroutine           @3.8
         exec_afni      3dpc \
            -prefix     ${ts} \
            -pcsave     99999 \
            -mask       ${!class_mask} \
            ${img}
         vidx=$(tail    -n1 ${ts}.1D|wc -w)
         cc_components=$(( ${cc_components} + ${vidx} ))
      elif is+numeric ${!class_include}
         then
         ##########################################################
         # Use aCompCor to extract PC timecourses from the mask:
         # Cumulative variance explained.
         ##########################################################
         subroutine           @3.9
         exec_afni      3dpc \
            -prefix     ${ts} \
            -mask       ${!class_mask} \
            ${img}
         readarray      variance_explained < ${ts}_eig.1D
         vidx=1
         while (( ${vidx} < ${#variance_explained[@]} ))
            do
            v=(      ${variance_explained[${vidx}]}   )
            chk=$(   arithmetic        ${v[3]}'>'${!class_include})
            ((       ${chk} == 1 ))    && break
            ((       vidx++      ))
         done
         subroutine           @3.9a [Retaining ${vidx} components from ${class_name}]
         exec_afni      3dpc \
            -prefix     ${ts} \
            -pcsave     ${vidx} \
            -mask       ${!class_mask} \
            ${img}
         cc_components=$(( ${cc_components} + ${vidx} ))
      elif [[ ${!class_include} == "local" ]]
         then
         subroutine           @3.10 Modelling voxelwise ${class_name} signal
         class_radius='confound_'${class}'_rad['${cxt}']'
         class_local=${class}'Local['${cxt}']'
         if ! is_image        ${!class_local} \
         || rerun
            then
            subroutine        @3.11 Radius of influence: ${!class_radius} mm
            exec_sys          rm -f ${!class_local}
            exec_afni         3dLocalstat \
               -prefix        ${!class_local} \
               -nbhd          'SPHERE('"${!class_radius}"')' \
               -stat          mean \
               -mask          ${!class_mask} \
               -use_nonmask \
               ${img}
            #######################################################
            # . . . and confine the nuisance signal to the existing
            # brain mask.
            #######################################################
            exec_fsl fslmaths ${!class_local} \
               -mul ${mask[sub]} \
               ${!class_local}
         fi
      fi
   else
         subroutine           @3.12
   fi
done





###################################################################
# MEAN GLOBAL SIGNAL
###################################################################
if [[ ${confound_gsr[cxt]} != N ]]
   then
   subroutine                 @4    [Global/local signals]
   ################################################################
   # Determine whether a brain mask exists for the current subject.
   #  * If one does, use it as the basis for computing the mean
   #    global timeseries.
   #  * If no mask exists, generate one using AFNI's 3dAutomask
   #    utility. This may yield unexpected results if data has
   #    been demeaned or standard-scored.
   ################################################################
   if is_image ${mask[sub]}
      then
      subroutine              @4.1
      maskpath=${mask[sub]}
   else
      subroutine              @4.2a Unable to identify mask
      subroutine              @4.2b Generating a mask using 3dAutomask
      maskpath=${intermediate}_mask.nii.gz
      exec_afni   3dAutomask \
         -prefix  ${maskpath} \
         -dilate  3 \
         -q \
         ${referenceVolume[sub]}
   fi
   ################################################################
   # Extract the mean timecourse from the global (whole-brain)
   # mask, and catenate it into the confound matrix.
   ################################################################
   if [[ ${confound_gsr[cxt]}   ==  mean ]]
      then
      subroutine              @4.3  Including mean global signal
      ts=${intermediate}_phys_gsr
      exec_fsl fslmeants   -i ${img} -o ${ts} -m ${maskpath}
      exec_xcp mbind.R \
         -x    ${confmat[cxt]} \
         -y    ${ts} \
         -o    ${confmat_path}
      output   confmat                 ${prefix}_confmat.1D
   elif [[ ${confound_gsr[cxt]} ==  local ]]
      then
      routine                 @4.4  "Including mean local signal in confound model."
      if ! is_image ${lmsLocal[cxt]} \
      || rerun
         then
         subroutine           @4.5  "Modelling local signal: All voxels"
         subroutine           @4.6  Radius of influence: ${confound_gsr_rad[cxt]}
         exec_sys             rm -f ${lmsLocal[cxt]}
         exec_afni            3dLocalstat \
            -prefix           ${lmsLocal[cxt]} \
            -nbhd             'SPHERE('"${confound_lms_rad[cxt]}"')' \
            -stat             mean \
            -mask             ${mask[sub]} \
            -use_nonmask \
            ${img}
         ##########################################################
         # . . . and confine the nuisance signal to the existing
         # brain mask.
         ##########################################################
         exec_fsl fslmaths ${lmsLocal[cxt]} \
            -mul  ${mask[sub]} \
            ${lmsLocal[cxt]}
         routine_end
      fi
   fi
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
if (( ${confound_past[cxt]} > 0 ))
   then
   subroutine                 @5    "Including ${confound_past[cxt]} prior time point(s)"
   exec_xcp mbind.R \
      -x    ${confmat[cxt]} \
      -y    OPprev${confound_past[cxt]} \
      -o    ${confmat_path}
   output   confmat           ${prefix}_confmat.1D
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
if (( ${confound_dx[cxt]} > 0 ))
   then
   subroutine                 @6    "[Including ${confound_dx[cxt]} derivative(s)]"
   exec_xcp mbind.R \
      -x    ${confmat[cxt]} \
      -y    OPdx${confound_dx[cxt]} \
      -o    ${confmat_path}
   output   confmat           ${prefix}_confmat.1D
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
if (( ${confound_sq[cxt]} > 1 ))
   then
   subroutine                 @7    "[Including ${confound_sq[cxt]} power(s)]"
   exec_xcp mbind.R \
      -x    ${confmat[cxt]} \
      -y    OPpower${confound_sq[cxt]} \
      -o    ${confmat_path}
   output   confmat           ${prefix}_confmat.1D
fi





###################################################################
# COMPONENT CORRECTION (COMPCOR)
###################################################################
if (( ${confound_cc[cxt]} > 0 ))
   then
   subroutine                 @8    "[Including ${confound_cc[cxt]} CompCor signal(s)]"
   ################################################################
   # Determine whether a brain mask exists for the current subject.
   #  * If one does, use it as the basis for computing nuisance
   #    components.
   #  * If no mask exists, generate one using AFNI's 3dAutomask
   #    utility. This may yield unexpected results if data has
   #    been demeaned or standard-scored.
   ################################################################
   if is_image ${mask[sub]}
      then
      subroutine              @8.1
      maskpath=${mask[sub]}
   elif ! is_image ${maskpath}
      then
      subroutine              @8.2  Unable to identify mask.
      subroutine              @8.3  Generating a mask using 3dAutomask
      maskpath=${intermediate}_mask.nii.gz
      exec_afni   3dAutomask \
         -prefix  ${maskpath} \
         -dilate  3 \
         -q \
         ${referenceVolume[sub]}
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
   exec_sys          rm       -f ${cc}
   exec_ants         ImageMath 4 ${intermediate}_confound.nii.gz \
      CompCorrAuto   ${img} \
      ${maskpath} \
      ${confound_cc[cxt]}
   readarray      ccdata   <  ${intermediate}_confound_compcorr.csv
   for (( cidx=1; ${cidx}  <= $(( ${#ccdata[@]} - 1));   cidx++ ))
      do
      ccc=(             ${ccdata[cidx]//,/\ } )
      ccc=${ccc[@]:1}
      echo              "${ccc}"       >>       ${cc}
   done
   ################################################################
   # Add the component timeseries to the confound matrix.
   ################################################################
   exec_xcp mbind.R \
      -x    ${confmat[cxt]} \
      -y    ${cc} \
      -o    ${confmat_path}
   output   confmat           ${prefix}_confmat.1D
fi





###################################################################
# If aCompCor has been selected, bind the PC timeseries into the
# main confound matrix here so as not to add derivatives and
# power terms.
# TODO
# The limited customisability here will need to be
# addressed in the near future.
###################################################################
if is+numeric ${confound_gm[cxt]}
   then
   subroutine                 @9.1  "[Including ${confound_gm[cxt]} GM aCompCor signal(s)]"
   exec_xcp mbind.R \
      -x    ${confmat[cxt]} \
      -y    ${gm} \
      -o    ${confmat_path}
   output   confmat           ${prefix}_confmat.1D
fi
if is+numeric ${confound_wm[cxt]}
   then
   subroutine                 @9.2  "[Including ${confound_wm[cxt]} WM aCompCor signal(s)]"
   exec_xcp mbind.R \
      -x    ${confmat[cxt]} \
      -y    ${wm} \
      -o    ${confmat_path}
   output   confmat           ${prefix}_confmat.1D
fi
if is+numeric ${confound_csf[cxt]}
   then
   subroutine                 @9.3  "Including ${confound_csf[cxt]} CSF aCompCor signal(s)"
   exec_xcp mbind.R \
      -x    ${confmat[cxt]} \
      -y    ${csf} \
      -o    ${confmat_path}
   output   confmat           ${prefix}_confmat.1D
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
confound_custom_ts=${confound_custom[cxt]//,/ }
nvol=$(  exec_fsl             fslnvols ${img})
for cts  in ${confound_custom_ts}
   do
   subroutine                 @10   "Custom timeseries: ${cts}"
   ################################################################
   # Determine whether the input is a three-column stick function
   # or an explicit timeseries. If it is a stick function, then
   # apply a convolution and convert it to a design matrix.
   ################################################################
   readarray nlines < ${cts}
   stick=$(arithmetic ${#nlines[@]}'<'${nvol})
   if (( ${stick} == 1 ))
      then
      subroutine              @10.1
      exec_xcp stick2lm.R \
         -i    ${img} \
         -s    ${cts} \
         -d    FALSE \
         >>    ${intermediate}convts.1D
   else
      subroutine              @10.2
      exec_sys cp ${cts}      ${intermediate}convts.1D
   fi
   cts=${intermediate}convts.1D
   ################################################################
   # Identify the row in which the timeseries matrix proper
   # begins if the input is an FSL-style design matrix.
   ################################################################
   exec_xcp mbind.R \
      -x    ${confmat[cxt]} \
      -y    ${cts} \
      -o    ${confmat_path}
   output   confmat           ${prefix}_confmat.1D
   exec_sys rm -f             ${intermediate}convts.1D
done
routine_end




routine                       @11   Validating confound model
###################################################################
# Verify that the confound matrix produced by the confound module
# contains the expected number of time series.
###################################################################
read -ra    obs      < ${confmat[cxt]}
obs=${#obs[@]}
exp=0
(( ${confound_rp[cxt]}  == 1     )) && exp=$(( ${exp} + 6 ))
(( ${confound_rms[cxt]} == 1     )) && exp=$(( ${exp} + 1 ))
[[ ${confound_gm[cxt]}  == mean  ]] && exp=$(( ${exp} + 1 ))
[[ ${confound_wm[cxt]}  == mean  ]] && exp=$(( ${exp} + 1 ))
[[ ${confound_csf[cxt]} == mean  ]] && exp=$(( ${exp} + 1 ))
[[ ${confound_gsr[cxt]} == mean  ]] && exp=$(( ${exp} + 1 ))

past=$((    ${confound_past[cxt]}      + 1 ))
dx=$((      ${confound_dx[cxt]}        + 1 ))
exp=$((     ${exp} * ${past} * ${dx}   * ${confound_sq[cxt]} ))
exp=$((     ${exp} + ${confound_cc[cxt]} ))
exp=$((     ${exp} + ${cc_components} ))
for cts in ${confound_custom_ts}
   do
   read     -ra ctsn       < ${cts}
   exp=$((  ${exp} +       ${#ctsn[@]} ))
done
subroutine                    @11.1a   [Expected confounds: ${exp}]
subroutine                    @11.1b   [Observed confounds: ${obs}]
if (( ${obs} == ${exp} ))
   then
   subroutine                 @11.1 [Confound matrix dimensions validated]
else
   subroutine                 @11.2 [Dimensions of the existing confound matrix are incorrect]
   exit 1
fi
routine_end





completion
