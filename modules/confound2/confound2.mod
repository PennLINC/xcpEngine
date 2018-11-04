#!/usr/bin/env bash

###################################################################
#  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  #
###################################################################

###################################################################
# SPECIFIC MODULE HEADER
# This module assembles a model of nuisance timeseries.
###################################################################
mod_name_short=confound2
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
   source ${XCPEDIR}/core/auditComplete
   source ${XCPEDIR}/core/updateQuality
   source ${XCPEDIR}/core/moduleEnd
}





###################################################################
# OUTPUTS
###################################################################
output      confmat                 null


qc nuisance_ct nNuisanceParameters  ${prefix}_modelParameterCount.txt


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


#output      confmat                 null


###################################################################
# REALIGNMENT PARAMETERS
# Realignment parameters should have been computed using the MPR
# subroutine of the prestats module prior to their use in the
# confound matrix here.
###################################################################

if (( ${confound2_rps[cxt]} == 1 ))
   then
   subroutine                 @1    [Including realignment parameters]
   rps_path=${outdir}/${prefix}_rps.1D
   exec_xcp generate_confmat.R \
           -i ${fmriprepconf[sub]} \
           -j rps  \
           -o ${rps_path}
    output rps  ${prefix}_rps.1D

   exec_xcp mbind.R           \
      -x ${confmat[cxt]}      \
      -y ${rps[cxt]}          \
      -o ${confmat_path}
   output confmat             ${prefix}_confmat.1D
fi





###################################################################
# RMS MOTION
###################################################################
if (( ${confound2_rms[cxt]} == 1 ))
   then
   subroutine                 @2    Including relative RMS displacement
   rms_path=${outdir}/${prefix}_rms.1D
    exec_xcp generate_confmat.R \
           -i ${fmriprepconf[sub]} \
           -j rms  \
           -o ${rms_path}
 
   output rms  ${prefix}_rms.1D

   exec_xcp mbind.R            \
      -x ${confmat[cxt]}       \
      -y ${rms[cxt]}        \
      -o ${confmat_path}
   output confmat             ${prefix}_confmat.1D
fi



###################################################################
# aCompCor
###################################################################
if (( ${confound2_acompcor[cxt]} == 1 ))
   then
   subroutine                 @2    Including  acompcor
   acompcor_path=${outdir}/${prefix}_acompcor.1D
    exec_xcp generate_confmat.R \
           -i ${fmriprepconf[sub]} \
           -j aCompCor  \
           -o ${acompcor_path}
   
 output acompcor  ${prefix}_acompcor.1D

   exec_xcp mbind.R            \
      -x ${confmat[cxt]}       \
      -y ${acompcor[cxt]}        \
      -o ${confmat_path}
   output confmat             ${prefix}_confmat.1D
fi

###################################################################
# CSF 
###################################################################

if (( ${confound2_csf[cxt]} == 1 ))
   then
   subroutine                 @2    Including csf
    csf_path=${outdir}/${prefix}_csf.1D
    exec_xcp generate_confmat.R \
           -i ${fmriprepconf[sub]} \
           -j csf  \
           -o ${csf_path}
  output csf  ${prefix}_csf.1D

   exec_xcp mbind.R            \
      -x ${confmat[cxt]}       \
      -y ${csf[cxt]}        \
      -o ${confmat_path}
   output confmat             ${prefix}_confmat.1D
fi


###################################################################
# tCompCor
###################################################################
if (( ${confound2_tcompcor[cxt]} == 1 ))
   then
   subroutine                 @2    Including tcompcor
   tcompcor_path=${outdir}/${prefix}_tcompcor.1D
    exec_xcp generate_confmat.R \
           -i ${fmriprepconf[sub]} \
           -j tCompCor  \
           -o ${tcompcor_path}
   
 output tcompcor  ${prefix}_tcompcor.1D

   exec_xcp mbind.R            \
      -x ${confmat[cxt]}       \
      -y ${tcompcor[cxt]}        \
      -o ${confmat_path}
   output confmat             ${prefix}_confmat.1D
fi


###################################################################
# MEAN GLOBAL SIGNAL
###################################################################

if (( ${confound2_gsr[cxt]} == 1 ))
   then
   subroutine                 @2    Including gsr
    gsr_path=${outdir}/${prefix}_gsr.1D
    exec_xcp generate_confmat.R \
           -i ${fmriprepconf[sub]} \
           -j gsr  \
           -o ${gsr_path}
  output gsr  ${prefix}_gsr.1D
   exec_xcp mbind.R            \
      -x ${confmat[cxt]}       \
      -y ${gsr[cxt]}        \
      -o ${confmat_path}
   output confmat             ${prefix}_confmat.1D
fi

###################################################################
# whitematter 
###################################################################

if (( ${confound2_wm[cxt]} == 1 ))
   then
   subroutine                 @2    Including wm
    wm_path=${outdir}/${prefix}_wm.1D
    exec_xcp generate_confmat.R \
           -i ${fmriprepconf[sub]} \
           -j wm  \
           -o ${wm_path}
  output wm  ${prefix}_wm.1D

   exec_xcp mbind.R            \
      -x ${confmat[cxt]}       \
      -y ${wm[cxt]}        \
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
if (( ${confound2_past[cxt]} > 0 ))
   then
   subroutine                 @5    "Including ${confound2_past[cxt]} prior time point(s)"
   exec_xcp mbind.R                 \
      -x    ${confmat[cxt]}         \
      -y    OPprev${confound2_past[cxt]} \
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
if (( ${confound2_dx[cxt]} > 0 ))
   then
   subroutine                 @6    "[Including ${confound2_dx[cxt]} derivative(s)]"
   exec_xcp mbind.R                 \
      -x    ${confmat[cxt]}         \
      -y    OPdx${confound2_dx[cxt]} \
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
if (( ${confound2_sq[cxt]} > 1 ))
   then
   subroutine                 @7    "[Including ${confound2_sq[cxt]} power(s)]"
   exec_xcp mbind.R                 \
      -x    ${confmat[cxt]}         \
      -y    OPpower${confound2_sq[cxt]} \
      -o    ${confmat_path}
   output   confmat           ${prefix}_confmat.1D
fi


routine                       @11   Validating confound model
###################################################################
# Verify that the confound matrix produced by the confound module
# contains the expected number of time series.
###################################################################
read -ra    obs      < ${confmat[cxt]}
obs=${#obs[@]}
exp=0
(( ${confound2_rps[cxt]}  == 1     )) && exp=$(( ${exp} + 6 ))
(( ${confound2_rms[cxt]} == 1     )) && exp=$(( ${exp} + 1 ))
[[ ${confound2_wm[cxt]}  == 1  ]] && exp=$(( ${exp} + 1 ))
[[ ${confound2_csf[cxt]} == 1  ]] && exp=$(( ${exp} + 1 ))
[[ ${confound2_gsr[cxt]} == 1  ]] && exp=$(( ${exp} + 1 ))

(( ${confound2_sq[cxt]} == 0 )) && confound2_sq[cxt]=1
past=$((    ${confound2_past[cxt]}      + 1 ))
dx=$((      ${confound2_dx[cxt]}        + 1 ))
exp=$((     ${exp} * ${past} * ${dx}   * ${confound2_sq[cxt]} ))
exp=$((     ${exp} + ${confound2_acompcor[cxt]} ))

for cts in ${confound2_custom_ts}
   do
   read     -ra ctsn       < ${cts}
   exp=$((  ${exp} +       ${#ctsn[@]} ))
done
subroutine                    @11.1a   [Expected confounds: ${exp}]


routine_end

completion
