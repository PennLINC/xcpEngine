#!/usr/bin/env bash

###################################################################
#  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  #
###################################################################
###################################################################
# SPECIFIC MODULE HEADER
# This module executes confound regression and censoring.
###################################################################
mod_name_short=regress
mod_name='CONFOUND REGRESSION MODULE'
mod_head=${XCPEDIR}/core/CONSOLE_MODULE_RC
source ${XCPEDIR}/core/functions/library_func.sh

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
output      confmat                 ${prefix}_confmat.1D
output      confcor                 ${prefix}_confcor.txt
output      tmask                   ${prefix}_tmask.1D
output      uncensored              ${prefix}_uncensored.nii.gz

qc n_volumes_censored nVolCensored  ${prefix}_nVolumesCensored.txt

input       confmat as confproc
input       censor


if [[ -n ${spatialsmooth} ]]; then 

   regress_smo[cxt]=${spatialsmooth}

fi

smooth_spatial_prime                ${regress_smo[cxt]}
ts_process_prime

process     denoised                ${prefix}_residualised

<< DICTIONARY

censor
   A set of instructions specifying the type of censoring to be
   performed in the current pipeline: 0 (none), 1 (iterative), or
   'final'. This instruction is inherited from the prestats module,
   which selects volumes for censoring.
confcor
   A matrix of correlations among confound timeseries.
confmat
   The confound matrix after filtering and censoring.
confproc
   A pointer to the working version of the confound matrix.
denoised
   The residualised timeseries, indicating the successful
   completion of the module.
img_sm
   The residualised timeseries, after it has undergone spatial
   smoothing.
kernel
   An array of all smoothing kernels to be applied to the
   timeseries, measured in mm.
n_volumes_censored
   The number of volumes excised from the timeseries during the
   confound regression procedure.
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
# image name and is used to verify that regression has completed
# successfully.
###################################################################
if ! is_image ${denoised[cxt]} \
|| rerun
then
unset buffer

subroutine                    @0.1

if [[ -n ${spatialsmooth} ]]; then 

   regress_smo[cxt]=${spatialsmooth}

fi

if [[ ${regress} == despike ]]; then 
      regress_process[cxt]=DMT-DSP-TMP-REG 
    elif [[ ${regress} == censor ]]; then 
     censor[cxt]=1
     else 
     echo "Design files  "
fi

if [[ -n ${temporalfilter} ]]; then
  
   regress_hipass[cxt]=$( echo ${temporalfilter} |  cut -d, -f1)
   regress_lopass[cxt]=$( echo ${temporalfilter} |  cut -d, -f2)

fi

tr=`fslinfo ${img[sub]}  | grep ^pixdim4`
TR=${tr##* }
echo $TR
###################################################################
# Parse the control sequence to determine what routine to run next.
# Available routines include:
#  * DMT: demean and detrend time series
#  * DSP: despike time series
#  * TMP: temporal filter
#  * REG: apply the final censor and execute the regression
###################################################################
rem=${regress_process[cxt]}
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
      remove_outliers         --SIGNPOST=${signpost}              \
                              --INPUT=${intermediate}             \
                              --OUTPUT=${intermediate}_${cur}     \
                              --CONFIN=${confproc[cxt]}           \
                              --CONFOUT=${intermediate}_${cur}_confmat.1D
      #############################################################
      # Update image pointers
      #############################################################
      subroutine              @1.4
      configure   confproc    ${intermediate}_${cur}_confmat.1D
      intermediate=${intermediate}_${cur}
      routine_end
      ;;
      
      
      
      
      
   DMT)
      #############################################################
      # DMT removes the mean from a timeseries and additionally
      # removes polynomial trends up to an order specified by
      # the user.
      #
      # DMT uses a general linear model with y = 1 and all
      # polynomials as predictor variables, then retains the
      # residuals of the model as the processed timeseries.
      #############################################################
      routine                 @7    Demeaning and detrending BOLD timeseries
      demean_detrend       --SIGNPOST=${signpost}           \
                           --ORDER=${regress_dmdt[cxt]}     \
                           --INPUT=${img}          \
                           --OUTPUT=${intermediate}_${cur}  \
                           --1DDT=${regress_1ddt[cxt]}      \
                           --CONFIN=${confproc[cxt]}        \
                           --CONFOUT=${intermediate}_${cur}_confmat.1D
      exec_fsl fslmaths ${mask[sub]} -mul ${intermediate}_${cur} ${intermediate}_${cur}
      intermediate=${intermediate}_${cur}
      configure            confproc  ${intermediate}_confmat.1D
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
      filter_temporal         --SIGNPOST=${signpost}              \
                              --FILTER=${regress_tmpf[cxt]}       \
                              --INPUT=${intermediate}.nii.gz             \
                              --TR=${TR} \
                              --OUTPUT=${intermediate}_${cur}     \
                              --CONFIN=${confproc[cxt]}           \
                              --CONFOUT=${intermediate}_${cur}_confmat.1D \
                              --HIPASS=${regress_hipass[cxt]}     \
                              --LOPASS=${regress_lopass[cxt]}     \
                              --ORDER=${regress_tmpf_order[cxt]}  \
                              --DIRECTIONS=${regress_tmpf_pass[cxt]} \
                              --RIPPLE_PASS=${regress_tmpf_ripple[cxt]} \
                              --RIPPLE_STOP=${regress_tmpf_ripple2[cxt]}
      #############################################################
      # Update image pointer
      #############################################################
      exec_fsl fslmaths ${mask[sub]} -mul ${intermediate}_${cur} ${intermediate}_${cur}
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
      if ((       ${censor[cxt]} != 0 )) \
      && is_1D    ${tmask[sub]}
         then
         routine              @3    Censoring: preparing spike regressors
         subroutine           @3.1  Adding delta functions to model
         exec_xcp tmask2spkreg.R    \
            -t    ${tmask[sub]}     \
            -r    ${confproc[cxt]}  \
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
         ##########################################################
         # Compute the internal correlations within the confound
         # matrix.
         ##########################################################
         subroutine           @4.5  [Computing confound correlations]
         exec_xcp ts2adjmat.R                 \
            -t    ${confproc[cxt]} ${cormask} \
            >>    ${confcor[cxt]}
         ##########################################################
         # Update paths to any local regressors.
         ##########################################################
         load_derivatives
         for derivative in    ${derivatives[@]}
            do
            derivative_parse  ${derivative}
            if contains       ${d[Type]}     [Cc]onfound
               then
               locals="${locals}-dsort       ${d[Map]} "
            fi
         done
         subroutine           @4.6  [Executing detrend]
         proc_afni   ${intermediate}_${cur}.nii.gz \
         3dTproject                         \
            -input   ${intermediate}.nii.gz \
            -ort     ${confproc[cxt]}       \
            ${locals}                       \
            -prefix  %OUTPUT
 
        exec_fsl fslmaths ${mask[sub]} -mul ${intermediate}_${cur} ${intermediate}_${cur}
         intermediate=${intermediate}_${cur}
      fi
      routine_end
      ;;
      
   *)
      subroutine              @E.1     Invalid option detected: ${cur}
      ;;
      
   esac
done





###################################################################
# CENSORING: First, verify that the temporal mask exists.
###################################################################
if (( ${censor[cxt]} != 0 ))
   then
   routine                    @5    Censoring BOLD timeseries
   if is_1D     ${tmask[sub]}
      then
      subroutine              @5.2
      tmaskpath=${tmask[sub]}
   else
      subroutine              @5.3
      echo \
"WARNING: Censoring of high-motion volumes requires a
temporal mask, but the regression module has failed
to find one. You are advised to inspect your pipeline
to ensure that this is intentional.

Overriding user input:
No censoring will be performed."
      configure               censor   0
      routine_end
   fi
fi
###################################################################
# Censor the BOLD timeseries.
# Check the conditional again in case the value of censoring has
# been changed due to a failure to locate the temporal mask.
###################################################################
if (( ${censor[cxt]} != 0 ))
   then
   subroutine                 @5.4  [Preparing the final censor]
   cur=CEN
   buffer=${buffer}_${cur}
   exec_fsl imcp ${intermediate}.nii.gz ${uncensored[cxt]}
   ################################################################
   # Use the temporal mask to determine which volumes are to be
   # left intact. Censoring is performed using the censor utility.
   ################################################################
   subroutine                 @5.5  [Applying the final censor]
   proc_xcp ${intermediate}_${cur}.nii.gz \
      censor.R                     \
      -t    ${tmaskpath}           \
      -i    ${intermediate}.nii.gz \
      -o    %OUTPUT
   apply_exec  timeseries  ${intermediate}_%NAME_${cur} \
      xcp   censor.R     \
      -t    ${tmaskpath} \
      -i    %INPUT       \
      -o    %OUTPUT
   intermediate=${intermediate}_${cur}
   nvol_pre=$( exec_fsl fslnvols       ${uncensored[cxt]})
   nvol_post=$(exec_fsl fslnvols       ${intermediate}.nii.gz)
   nvol_censored=$(( ${nvol_pre}   -   ${nvol_post} ))
   subroutine                 @5.6  [${nvol_censored} volumes censored]
   echo ${nvol_censored}            >> ${n_volumes_censored[cxt]}

   routine_end
   else 
   
   nvol_censored=0
   echo ${nvol_censored}         >> ${n_volumes_censored[cxt]}

   routine_end
fi





###################################################################
# INTERIM CLEANUP
#  * Test for the expected output. This should be the initial
#    image name with any routine suffixes appended.
#  * If the expected output is present, move it to the target path.
#  * If the expected output is absent, notify the user.
###################################################################
if is_image ${intermediate_root}${buffer}.nii.gz
   then
   subroutine                 @0.2
   processed=$(readlink -f    ${intermediate}.nii.gz)
   exec_fsl immv ${processed} ${denoised[cxt]}
   trep=$(exec_fsl fslval ${img[sub]} pixdim4)
   exec_xcp addTR.py -i ${denoised[cxt]} -o ${denoised[cxt]} -t ${trep} 
else
   subroutine                 @0.3
   abort_stream \
"Expected output not present.]
[Expected: ${buffer}]
[Check the log to verify that processing]
[completed as intended."
fi
fi # check for denoised (residualised)





###################################################################
# Apply the desired smoothing kernels to the BOLD time series.
# * This does not replace the primary BOLD time series. Instead,
#   it creates a derivative for each kernel.
###################################################################
routine                       @6    Spatially filtering image
smooth_spatial                --SIGNPOST=${signpost}              \
                              --FILTER=regress_sptf[$cxt]         \
                              --INPUT=${denoised[cxt]//.nii.gz}   \
                              --USAN=${regress_usan[cxt]}         \
                              --USPACE=${regress_usan_space[cxt]}


# do the surface processing 
imgname=$(basename ${img1[sub]})
                              
if [[ "$imgname" == *_res-* ]]; then
   imgprt=${img1[sub]%_*_*_*_*}
   else
   imgprt=${img1[sub]%_*_*_*}
fi
 
ciftifile=$(ls -f ${imgprt}*bold.dtseries.nii)
giftifile=$(ls -f ${imgprt}*fsnative_hemi-L_bold.func.gii)

if [[ -f ${ciftifile} ]]; then 
  python ${XCPEDIR}/utils/surfaceprocessing.py  -p ${prefix} -o ${out[sub]}/regress -f ${out[sub]}/confound2/mc/${prefix}_fd.1D  \
  -d ${out[sub]}/confound2/mc/${prefix}_dvars-std.1D -t ${trep}  -c ${out[sub]}/confound2/${prefix}_confmat.1D  \
  -g ${ciftifile} -r ${regress_process[cxt]}  -l ${regress_lopass[cxt]} -s ${regress_hipass[cxt]}
fi 

if [[ -f ${giftifile} ]]; then

 giftifiles=$(ls -f ${imgprt}*fsnative_hemi-*_bold.func.gii)

 for i in ${giftifiles}; do 
 python ${XCPEDIR}/utils/surfaceprocessing.py  -p ${prefix} -o ${out[sub]}/regress -f ${out[sub]}/confound2/mc/${prefix}_fd.1D  \
  -d ${out[sub]}/confound2/mc/${prefix}_dvars-std.1D -t ${trep}  -c ${out[sub]}/confound2/${prefix}_confmat.1D  \
  -g ${i} -r ${regress_process[cxt]}  -l ${regress_lopass[cxt]} -s ${regress_hipass[cxt]}
 done 

fi 
  
exec_sys mv  $(ls -f ${out[sub]}/regress/*svg) ${out[sub]}/figures/ 2>/dev/null


routine_end





completion


