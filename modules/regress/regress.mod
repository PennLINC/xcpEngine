#!/usr/bin/env bash

###################################################################
#  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  #
###################################################################

###################################################################
# SPECIFIC MODULE HEADER
# This module executes confound regression and censoring.
###################################################################
mod_name_short=regress
mod_name='CONFOUND REGRESSION MODULE'
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
   processed         residualised
   
   write_output      confmat
   write_output      confcor
   write_output      uncensored
   
   quality_metric    nVolCensored            n_volumes_censored

   for k in ${kernel[cxt]}
      do
      write_derivative  img_sm${k}
   done
   
   apply_exec        timeseries              ${prefix}_%NAME \
      sys            ls %OUTPUT              >/dev/null 2>&1
   apply_exec        timeseries              ${prefix}_%NAME \
      sys            write_derivative        %NAME 2>/dev/null
   
   source ${XCPEDIR}/core/auditComplete
   source ${XCPEDIR}/core/updateQuality
   source ${XCPEDIR}/core/moduleEnd
}





###################################################################
# OUTPUTS
###################################################################
output      confmat                 ${prefix}_confmat.1D
output      confcor                 ${prefix}_confcor.txt
output      n_volumes_censored      ${prefix}_nVolumesCensored.txt
output      tmask                   ${prefix}_tmask.1D
output      uncensored              ${prefix}_uncensored.nii.gz

configure   confproc                ${confmat[sub]}
configure   censor                  ${censor[sub]}
configure   kernel                  ${regress_smo[cxt]//,/ }

for k in ${kernel[cxt]}
   do
   derivative        img_sm${k}     ${prefix}_img_sm${k}
   derivative_config img_sm${k}     Type     timeseries
done

process     residualised            ${prefix}_residualised

<< DICTIONARY

censor
   A set of instructions specifying the type of censoring to be
   performed in the current pipeline: 'none', 'iter[ative]', or
   'final'. This instruction is inherited from the prestats module,
   which selects volumes for censoring.
confcor
   A matrix of correlations among confound timeseries.
confmat
   The confound matrix after filtering and censoring.
confproc
   A pointer to the working version of the confound matrix.
img_sm
   The residualised timeseries, after it has undergone spatial
   smoothing.
kernel
   An array of all smoothing kernels to be applied to the
   timeseries, measured in mm.
n_volumes_censored
   The number of volumes excised from the timeseries during the
   confound regression procedure.
residualised
   The residualised timeseries, indicating the successful
   completion of the module.
tmask
   A temporal mask of binary values, indicating whether each
   volume survives motion censorship.
uncensored
   If censoring is enabled, then the pre-censoring residuals
   will be written here. This is not declared as a derivative so
   that it does not consume unnecessary disk space at
   normalisation.

DICTIONARY










###################################################################
# The variable 'buffer' stores the processing steps that are
# already complete; it becomes the expected ending for the final
# image name and is used to verify that prestats has completed
# successfully.
###################################################################
unset buffer

subroutine                    @0.1

###################################################################
# Parse the control sequence to determine what routine to run next.
# Available routines include:
#  * DSP: despike time series
#  * TMP: temporal filter
#  * REG: apply the final censor and execute the regression
###################################################################
rem=${prestats_process[cxt]}
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
   
   
   
   
   
   DSP)
      #############################################################
      # Despike all timeseries, if DSP is in the control sequence:
      #  * The primary analyte timeseries
      #  * Local regressors
      #  * Global regressors
      #############################################################
      routine                 @1    Despiking BOLD timeseries
      #############################################################
      # First, verify that this step has not already run to
      # completion by searching for expected output.
      #############################################################
      if ! is_image ${intermediate}_${cur}.nii.gz \
      || rerun
         then
         exec_sys rm -rf         ${intermediate}_${cur}.nii.gz
         t_rep=$(exec_fsl fslval ${intermediate}      pixdim4)
         ##########################################################
         # Primary image
         ##########################################################
         subroutine           @1.1  Primary analyte image
         exec_afni   3dDespike \
            -prefix  ${intermediate}_${cur}.nii.gz \
            -nomask  -quiet \
            -NEW     ${intermediate}.nii.gz
         ##########################################################
         # Derivatives
         ##########################################################
         subroutine           @1.2
         apply_exec  timeseries  ${intermediate}_%NAME_${cur}  ECHO:Name \
            afni     3dDespike \
            -prefix  %OUTPUT \
            -nomask  -quiet \
            -NEW     %INPUT
         ##########################################################
         # Confound matrix
         ##########################################################
         subroutine           @1.3
         exec_xcp 1dDespike \
            -i    ${confproc[cxt]} \
            -x    ${intermediate}_1dDespike \
            -o    ${intermediate}_${cur}_confmat.1D \
            -r    ${t_rep} \
            -n    -q
      fi
      #############################################################
      # Update image pointers
      #############################################################
      subroutine              @1.4
      configure   confproc    ${intermediate}_${cur}_confmat.1D
      intermediate=${intermediate}_${cur}
      routine_end
      ;;
   
   
   
   
   
   TMP)
      #############################################################
      # Apply a temporal filter to the BOLD timeseries, the
      # confound matrix, and any local regressors.
      #
      # Any timeseries to be used in regression should by now be in
      # the confound matrix.
      #############################################################
      routine                 @2    Temporally filtering image and confounds
      #############################################################
      # If no temporal filtering has been specified by the user,
      # then bypass this step.
      #############################################################
      if [[ ${regress_tmpf[cxt]} == none ]]
         then
         subroutine           @2.1
         exec_sys ln -s ${intermediate}.nii.gz  ${intermediate}_${cur}.nii.gz
         exec_sys cp    ${confproc[cxt]}        ${intermediate}_${cur}_confmat.1D
      #############################################################
      # Ensure that this step has not already run to completion by
      # checking for the existence of a filtered image and confound
      # matrix.
      #############################################################
      elif ! is_image ${intermediate}_${cur}.nii.gz \
      ||   ! is_1D    ${confmat[cxt]} \
      || rerun
         then
         subroutine           @2.2
         ##########################################################
         # OBTAIN MASKS: SPATIAL
         # Obtain the spatial mask over which filtering is to be
         # applied, if a subject mask has been generated. If not,
         # perform filtering without a mask.
         ##########################################################
         if is_image ${mask[sub]}
            then
            subroutine        @2.3.1
            mask="-m ${mask[sub]}"
         else
            subroutine        @2.3.2
            unset mask
         fi
         ##########################################################
         # OBTAIN MASKS: TEMPORAL
         # Obtain the path to the temporal mask over which
         # filtering is to be executed.
         #
         # If iterative censoring has been specified, then it will
         # be necessary to interpolate over high-motion epochs to
         # ensure that they do not exert inordinate influence upon
         # the temporal filter, resulting in corruption of adjacent
         # volumes by motion-related variance.
         ##########################################################
         if [[ ${censor[cxt]} == iter ]] \
         && is_1D ${tmask[sub]}
            then
            subroutine        @2.4.1
            tmask="-n ${tmask[sub]}"
         elif [[ ${censor[cxt]} == final ]] \
         && is_1D ${tmask[sub]}
            then
            subroutine        @2.4.2
            tmask="-k ${tmask[sub]}"
         elif [[ ${censor[cxt]} != none ]]
            then
            subroutine        @2.4.3
            echo \
"WARNING: Censoring of high-motion volumes requires a
temporal mask, but the regression module has failed
to find one. You are advised to inspect your pipeline
to ensure that this is intentional.

Overriding user input:
No censoring will be performed."
            configure            censor   none
            write_output         censor
            unset tmask
         elif (( ${regress_spkreg[cxt]} == 0 ))
            then
            subroutine        @2.4.4
            unset tmask
         fi
         ################################################################
         # DERIVATIVE IMAGES AND TIMESERIES
         # (CONFOUND MATRIX AND LOCAL REGRESSORS)
         # Prime the index of derivative images, as well as any 1D
         # timeseries (e.g. realignment parameters) that should be
         # filtered so that they can be used in linear models without
         # reintroducing the frequencies removed from the primary BOLD
         # timeseries.
         ################################################################
         subroutine           @2.5
         unset derivs ts1d
         if is_1D ${confproc[cxt]}
            then
            subroutine        @2.6
            ts1d="confmat:${confproc[cxt]}"
         fi
         ################################################################
         # FILTER-SPECIFIC ARGUMENTS
         # Next, set arguments specific to each filter class.
         ################################################################
         unset tforder tfdirec tfprip tfsrip
         case ${regress_tmpf[cxt]} in
         butterworth)
            subroutine        @2.7
            tforder="-r ${regress_tmpf_order[cxt]}"
            tfdirec="-d ${regress_tmpf_pass[cxt]}"
            ;;
         chebyshev1)
            subroutine        @2.8
            tforder="-r ${regress_tmpf_order[cxt]}"
            tfdirec="-d ${regress_tmpf_pass[cxt]}"
            tfprip="-p ${regress_tmpf_ripple[cxt]}"
            ;;
         chebyshev2)
            subroutine        @2.9
            tforder="-r ${regress_tmpf_order[cxt]}"
            tfdirec="-d ${regress_tmpf_pass[cxt]}"
            tfsrip="-s ${regress_tmpf_ripple2[cxt]}"
            ;;
         elliptic)
            subroutine        @2.10
            tforder="-r ${regress_tmpf_order[cxt]}"
            tfdirec="-d ${regress_tmpf_pass[cxt]}"
            tfprip="-p ${regress_tmpf_ripple[cxt]}"
            tfsrip="-s ${regress_tmpf_ripple2[cxt]}"
            ;;
         esac
         ##########################################################
         # Engage the tfilter routine to filter the image.
         #  * This is essentially a wrapper around the three
         #    implemented filtering routines: fslmaths, 3dBandpass,
         #    and genfilter
         ##########################################################
         subroutine           @2.11a   [${regress_tmpf[cxt]} filter]
         subroutine           @2.11b   [High pass frequency: ${regress_hipass[cxt]}]
         subroutine           @2.11c   [Low pass frequency: ${regress_lopass[cxt]}]
         exec_xcp tfilter \
            -i    ${intermediate}.nii.gz \
            -o    ${intermediate}_${cur}.nii.gz \
            -f    ${regress_tmpf[cxt]} \
            -h    ${regress_hipass[cxt]} \
            -l    ${regress_lopass[cxt]} \
            ${mask}     ${tmask}    ${tforder}  ${tfdirec} \
            ${tfprip}   ${tfsrip}   ${ts1d}
         apply_exec     timeseries  ${intermediate}_%NAME_${cur} \
            xcp   tfilter \
            -i    %INPUT \
            -o    %OUTPUT \
            -f    ${regress_tmpf[cxt]} \
            -h    ${regress_hipass[cxt]} \
            -l    ${regress_lopass[cxt]} \
            ${mask}     ${tmask}    ${tforder}  ${tfdirec} \
            ${tfprip}   ${tfsrip}
         ##########################################################
         # Reorganise outputs
         ##########################################################
         is_1D ${intermediate}_${cur}_tmask.1D  \
            && exec_sys mv -f ${intermediate}_${cur}_tmask.1D ${tmask[cxt]}
      fi
      #############################################################
      # Update image pointer
      #############################################################
      intermediate=${intermediate}_${cur}
      configure   confproc    ${intermediate}_confmat.1D
      routine_end
      ;;
   
   
   
   
   
   REG)
      #############################################################
      # Regress and censor.
      # Begin by adding spike regressors into the model to ensure
      # that the model fit ignores high-motion volumes.
      #############################################################
      if [[       ${censor[cxt]} != none ]] \
      && is_1D    ${tmask[sub]}
         then
         routine              @3    Censoring: preparing spike regressors
         subroutine           @3.1  Adding delta functions to model
         exec_xcp tmask2spkreg.R \
            -t    ${tmask[sub]} \
            -r    ${confproc[cxt]} \
            >>    ${intermediate}_SPKREG
         exec_sys mv ${intermediate}_SPKREG ${confproc[cxt]}
         subroutine           @3.2  Masking high-motion epochs from correlation
         cormask="-m ${tmask[sub]}"
         routine_end
      fi
      #############################################################
      # Compute the residual BOLD timeseries by fitting a linear
      # model incorporating all nuisance variables.
      #############################################################
      routine                 @4    Converting BOLD timeseries to confound residuals
      if ! is_image ${intermediate}_${cur}.nii.gz \
      || rerun
         then
         subroutine           @4.2
         if [[ -e ${confproc[cxt]} ]]
            then
            subroutine        @4.3
            exec_sys mv ${confproc[cxt]} ${confmat[cxt]}
            configure         confproc   ${confmat[cxt]}
         else
            subroutine        @4.4
            configure         confproc   ${confmat[sub]}
         fi
         ################################################################
         # Compute the internal correlations within the confound
         # matrix.
         ################################################################
         subroutine           @4.5  [Computing confound correlations]
         exec_xcp ts2adjmat.R \
            -t    ${confproc[cxt]} ${cormask} \
            >>    ${confcor[cxt]}
         ################################################################
         # Update paths to any local regressors.
         ################################################################
         load_derivatives
         for derivative in    ${derivatives[@]}
            do
            derivative_parse  ${derivative}
            if contains       ${d[Type]}     confound
               then
               locals="${locals}-dsort       ${d[Map]} "
            fi
         done
         subroutine           @4.6  [Executing detrend]
         proc_afni   ${intermediate}_${cur} \
         3dTproject                         \
            -input   ${intermediate}.nii.gz \
            -ort     ${confproc[cxt]}       \
            ${locals}                       \
            -prefix  %OUTPUT
         intermediate=${intermediate}_${cur}
      fi
      routine_end
      ###################################################################
      # Next, verify that the temporal mask exists before censoring.
      ###################################################################
      if [[ ${censor[cxt]} != none ]]
         then
         routine              @5    Censoring BOLD timeseries
         if is_1D     ${tmask[sub]}
            then
            subroutine        @5.2
            tmaskpath=${tmask[sub]}
         else
            subroutine        @5.3
            echo \
"WARNING: Censoring of high-motion volumes requires a
temporal mask, but the regression module has failed
to find one. You are advised to inspect your pipeline
to ensure that this is intentional.

Overriding user input:
No censoring will be performed."
            configure            censor   none
            write_config         censor
            routine_end
         fi
      fi
      ###################################################################
      # Censor the BOLD timeseries.
      # Check the conditional again in case the value of censoring has
      # been changed due to a failure to locate the temporal mask.
      ###################################################################
      if [[ ${censor[cxt]} != none ]]
         then
         subroutine           @5.4  [${censor[cxt]} censoring]
         cur=CEN
         buffer=${buffer}_${cur}
         exec_fsl imcp ${intermediate}.nii.gz ${uncensored[cxt]}
         ################################################################
         # Use the temporal mask to determine which volumes are to be
         # left intact.
         #
         # Censoring is performed using the censor utility.
         ################################################################
         subroutine           @5.5  [Applying the final censor]
         exec_xcp censor.R               \
            -t    ${tmaskpath}           \
            -i    ${intermediate}.nii.gz \
            -o    ${intermediate}_${cur}.nii.gz
         apply_exec  timeseries  ${intermediate}_%NAME_${cur} \
            xcp   censor.R     \
            -t    ${tmaskpath} \
            -i    %INPUT       \
            -o    %OUTPUT
         intermediate=${intermediate}_${cur}
         nvol_pre=$( exec_fsl fslnvols       ${uncensored[cxt]})
         nvol_post=$(exec_fsl fslnvols       ${intermediate}.nii.gz)
         nvol_censored=$(( ${nvol_pre}   -   ${nvol_post} ))
         subroutine           @5.6  [${nvol_censored} volumes censored]
         echo ${nvol_censored}   >>    ${n_volumes_censored[cxt]}
         routine_end
      fi
      ;;
      
   *)
      subroutine              @E.1     Invalid option detected: ${cur}
      ;;
         
   esac
done





###################################################################
# INTERIM CLEANUP
#  * Test for the expected output. This should be the initial
#    image name with any routine suffixes appended.
#  * If the expected output is present, move it to the target path.
#  * If the expected output is absent, notify the user.
###################################################################
apply_exec        timeseries              ${prefix}_%NAME \
   fsl            imcp %INPUT %OUTPUT
if is_image ${intermediate_root}${buffer}.nii.gz
   then
   subroutine                 @0.2
   processed=$(readlink -f    ${intermediate}.nii.gz)
   exec_fsl immv ${processed} ${residualised[cxt]}
else
   subroutine                 @0.3
   echo \
   "


XCP-ERROR: Expected output not present.
Expected: ${prefix}${buffer}
Check the log to verify that processing
completed as intended.
"
   exit 1
fi





###################################################################
# Apply the desired smoothing kernels to the BOLD time series.
# * This does not replace the primary BOLD time series. Instead,
#   it creates a derivative for each kernel.
###################################################################
routine                       @6    Spatially filtering image
###################################################################
# SUSAN setup
###################################################################
if [[ ${regress_sptf[cxt]} == susan ]] \
&& [[ -n ${kernel[cxt]} ]]
   then
   subroutine                 @6.1  [Configuring SUSAN]
   ################################################################
   # Determine whether a custom USAN is being used, and register
   # it to analyte space if so.
   ################################################################
   if is_image ${regress_usan[cxt]}
      then
      subroutine              @6.2  Warping USAN
      warpspace               \
         ${regress_usan[cxt]} \
         ${intermediate}usan.nii.gz \
         ${regress_usan_space[cxt]}:${space} \
         NearestNeighbor
      usan="-u ${intermediate}usan"
      hardseg=-h
   ################################################################
   # Otherwise, ensure that an example functional image exists.
   #  * If it does not, force a switch to uniform smoothing to
   #    prevent a catastrophe.
   ################################################################
   elif is_image ${referenceVolumeBrain[sub]}
      then
      subroutine              @6.3
      usan="-u ${referenceVolumeBrain[sub]}"
   else
      subroutine              @6.4a No appropriate USAN: reconfiguring pipeline
      subroutine              @6.4b to smooth to uniformity instead
      configure               regress_sptf   uniform
      write_config            regress_sptf
   fi
fi
###################################################################
# * First, identify all kernels to apply.
###################################################################
for k in ${kernel[cxt]}
   do
   subroutine                 @6.5
   img_sm_name=sm${k}
   smoothed='img_sm'${k}'['${cxt}']'
   if is_image ${!smoothed}
      then
      subroutine              @6.7
      write_derivative        img_sm${ker}
   ################################################################
   # If no spatial filtering has been specified by the user, then
   # bypass this step.
   ################################################################
   elif [[ ${regress_sptf[cxt]} == none ]] \
   || [[ ${k} == 0 ]]
      then
      subroutine              @6.8
   else
      subroutine              @6.9a [Filter: ${regress_sptf[cxt]}]
      subroutine              @6.9b [Smoothing kernel: ${k} mm]
      #############################################################
      # Ensure that this step has not already run to completion
      # by checking for the existence of a smoothed image. First,
      # obtain the mask for filtering. Then, engage the sfilter
      # routine.
      #############################################################
      if ! is_image ${!smoothed} \
      || rerun
         then
         subroutine           @6.10
         if is_image ${mask[sub]}
            then
            subroutine        @6.11
            mask=${mask[sub]}
         else
            subroutine        @6.12 Generating a mask using 3dAutomask
            exec_afni   3dAutomask \
               -prefix  ${intermediate}_fmask.nii.gz \
               -dilate  3 \
               -q       ${intermediate}.nii.gz
            mask=${intermediate}_fmask.nii.gz
         fi
         exec_xcp sfilter \
            -i    ${intermediate}.nii.gz \
            -o    ${!smoothed} \
            -s    ${regress_sptf[cxt]} \
            -k    ${k} \
            -m    ${mask} \
            ${usan} ${hardseg}
      fi
   fi
done
routine_end






completion
