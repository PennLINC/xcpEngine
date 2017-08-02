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
   processed         final
   
   write_output      confmat
   write_output      confcor
   
   quality_metric    nVolCensored            n_volumes_censored
   
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

configure   confproc                ${confmat[${subjidx}]}
configure   censor                  ${censor[${subjidx}]}

process     final                   ${prefix}_residualised

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
final
   The residualised timeseries, indicating the successful
   completion of the module.
n_volumes_censored
   The number of volumes excised from the timeseries during the
   confound regression procedure.
tmask
   A temporal mask of binary values, indicating whether each
   volume survives motion censorship.

DICTIONARY










###################################################################
# Read in any local regressors, if they are present.
###################################################################
if [[ ! -z "${locregs[${subjidx}]}" ]]
   then
   subroutine              @0.1
   locregs=$(cat ${locregs[${subjidx}]})
fi





###################################################################
# Despike all timeseries, if the user has requested this option:
#  * The primary analyte timeseries
#  * Local regressors
#  * Global regressors
###################################################################
if [[ ${regress_despike[${cxt}]} == Y ]]
   then
   routine                 @1    Despiking BOLD timeseries
	################################################################
	# First, verify that this step has not already run to
	# completion by searching for expected output.
	################################################################
   if ! is_image ${intermediate}_despike.nii.gz \
   || rerun
      then
      exec_sys rm -rf ${intermediate}_despike.nii.gz
      nvol=$(exec_fsl fslnvols ${intermediate}.nii.gz)
      t_rep=$(exec_fsl fslval ${intermediate} pixdim4)
      if (( ${nvol} > 500 ))
         then
         subroutine        @1.1  
         ds_arguments="-NEW"
         oneD_arguments="-n"
      else
         subroutine        @1.2
      fi
	   #############################################################
	   # Primary image
	   #############################################################
	   subroutine           @1.3
      exec_afni 3dDespike \
         -prefix ${intermediate}_despike.nii.gz \
         -nomask \
         -quiet \
         ${ds_arguments} \
         ${intermediate}.nii.gz
	   #############################################################
	   # Derivatives
	   #############################################################
      load_derivatives
      for derivative in ${derivatives}
         do
         derivative_parse ${derivative}
         if [[ ${d_type} == timeseries ]]
            then
            subroutine     @1.4
            derivative     ${d_name}   ${prefix}_${d_name}_despike
            derivative=${d_name}'['${cxt}']'
            exec_afni 3dDespike \
               -prefix ${!derivative} \
               -nomask \
               -quiet \
               ${ds_arguments} \
               ${intermediate}.nii.gz
            write_derivative  ${d_name}
         else
            subroutine     @1.5
         fi
      done
      ##########################################################
      # Confound matrix
      ##########################################################
      subroutine           @1.6
      exec_xcp 1dDespike \
         -i ${confproc[${cxt}]} \
         -x ${intermediate}_1dDespike \
         -o ${intermediate}_despike_confmat.1D \
         -r ${t_rep} \
         ${oneD_arguments} \
         -q
   fi
	################################################################
	# Update image pointers
	################################################################
	subroutine              @1.7
   configure   confproc    ${intermediate}_despike_confmat.1D
   locregs=$(exec_sys ls -d1 ${outdir}/*loc*despike* 2>/dev/null)
   intermediate=${intermediate}_despike
	routine_end
fi





###################################################################
# Apply a temporal filter to the BOLD timeseries, the confound
# matrix, and any local regressors.
#
# Any timeseries to be used in regression should by now be in
# the confound matrix.
#
#  * If no local regression is being used and the user has
#    specified a FFT filter, then filtering and regression can
#    be combined into a single step using 3dBandpass.
###################################################################
routine                    @2    Temporally filtering image and confounds
###################################################################
# If no temporal filtering has been specified by the user, then
# bypass this step.
###################################################################
if [[ ${regress_tmpf[${cxt}]} == none ]]
   then
   subroutine              @2.1
   exec_sys ln -s ${intermediate}.nii.gz ${intermediate}_filtered.nii.gz
   cp ${confproc[${cxt}]}  ${intermediate}_confmat.1D
###################################################################
# Ensure that this step has not already run to completion by
# checking for the existence of a filtered image and confound
# matrix.
###################################################################
elif ! is_image ${intermediate}_filtered.nii.gz \
|| [[ ! -e ${confmat[${cxt}]} ]] \
|| rerun
   then
   subroutine              @2.2
	################################################################
	# OBTAIN MASKS: SPATIAL
	# Obtain the spatial mask over which filtering is to be
	# applied, if a subject mask has been generated. Otherwise,
	# perform filtering without a mask.
	################################################################
   if is_image ${mask[${subjidx}]}
      then
      subroutine           @2.3.1
      mask="-m ${mask[${subjidx}]}"
   else
      subroutine           @2.3.2
      unset mask
   fi
	################################################################
	# OBTAIN MASKS: TEMPORAL
	# Obtain the path to the temporal mask over which filtering is
	# to be executed.
	#
	# If iterative censoring has been specified, then it will be
	# necessary to interpolate over high-motion epochs in order to
	# ensure that they do not exert inordinate influence upon the
	# temporal filter, resulting in corruption of adjacent volumes
	# by motion-related variance.
	################################################################
	if is_1D ${tmask[${subjidx}]}
      then
      subroutine           @2.4.1
      tmaskpath=${tmask[${subjidx}]}
	else
	   subroutine           @2.4.2
      tmaskpath=ones
   fi
	if [[ ${censor[${cxt}]} == iter ]] \
	&& [[ ${tmaskpath} != ones ]]
	   then
	   subroutine           @2.5.1
	   tmask="-n ${tmaskpath}"
	elif [[ ${censor[${cxt}]} == final ]] \
	&& [[ ${tmaskpath} != ones ]]
	   then
	   subroutine           @2.5.2
	   tmask="-k ${tmaskpath}"
	elif [[ ${censor[${cxt}]} != none ]]
	   then
	   subroutine           @2.5.3
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
	elif [[ ${regress_spkreg[${cxt}]} == N ]]
	   then
	   subroutine           @2.5.4
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
	subroutine              @2.6
	unset derivs ts1d
	derivs="-x ${aux_imgs[${subjidx}]}"
	if is_1D ${confproc[${cxt}]}
	   then
	   subroutine           @2.7
	   ts1d="${confproc[${cxt}]}"
	fi
	[[ -n ${ts1d} ]] && ts1d="-1 ${ts1d// /,}"
	################################################################
	# FILTER-SPECIFIC ARGUMENTS
	# Next, set arguments specific to each filter class.
	################################################################
	unset tforder tfdirec tfprip tfsrip tfdvol
	case ${regress_tmpf[${cxt}]} in
	butterworth)
	   subroutine           @2.8
	   tforder="-r ${regress_tmpf_order[${cxt}]}"
	   tfdirec="-d ${regress_tmpf_pass[${cxt}]}"
	   ;;
	chebyshev1)
	   subroutine           @2.9
	   tforder="-r ${regress_tmpf_order[${cxt}]}"
	   tfdirec="-d ${regress_tmpf_pass[${cxt}]}"
	   tfprip="-p ${regress_tmpf_ripple[${cxt}]}"
	   ;;
	chebyshev2)
	   subroutine           @2.10
	   tforder="-r ${regress_tmpf_order[${cxt}]}"
	   tfdirec="-d ${regress_tmpf_pass[${cxt}]}"
	   tfsrip="-s ${regress_tmpf_ripple2[${cxt}]}"
	   ;;
	elliptic)
	   subroutine           @2.11
	   tforder="-r ${regress_tmpf_order[${cxt}]}"
	   tfdirec="-d ${regress_tmpf_pass[${cxt}]}"
	   tfprip="-p ${regress_tmpf_ripple[${cxt}]}"
	   tfsrip="-s ${regress_tmpf_ripple2[${cxt}]}"
	   ;;
	esac
	################################################################
	# If the user has requested discarding of initial and/or final
	# volumes from the filtered timeseries, the request should be
	# passed to tfilter.
	################################################################
	if [[ -n ${regress_tmpf_dvols[${cxt}]} ]] \
	&& (( ${regress_tmpf_dvols[${cxt}]} != 0 ))
	   then
	   subroutine           @2.12
	   tfdvol="-v ${regress_tmpf_dvols[${cxt}]}"
	fi
	################################################################
	# Determine whether filtering and regression can be combined
	# into a single step.
	#  * If so, then tfilter can be bypassed.
	#  * This is only the case if a FFT-based filter is being used,
	#    no local regressors are present in the model, iterative
	#    censoring is not being run, and no volumes are to be
	#    discarded from the timeseries.
	################################################################
   subroutine              @2.13a   [${regress_tmpf[${cxt}]} filter]
   subroutine              @2.13b   [High pass frequency: ${regress_hipass[${cxt}]}]
   subroutine              @2.13c   [Low pass frequency: ${regress_lopass[${cxt}]}]
	if [[ ${regress_tmpf[${cxt}]} == fft ]] \
	&& [[ -z ${locregs} ]] \
	&& [[ ${censor[${cxt}]} != iter ]] \
	&& [[ -z ${tfdvol} ]]
	   then
	   subroutine           @2.14    Combining filtering and regression
	   exec_afni \
	      3dBandpass \
         -prefix ${final[${cxt}]}.nii.gz \
         -nodetrend -quiet \
         -ort ${confmat[${subjidx}]} \
         ${regress_hipass[${cxt}]} \
         ${regress_lopass[${cxt}]} \
         ${intermediate}.nii.gz \
         2>/dev/null
      has_residuals=1
	################################################################
	# Engage the tfilter routine to filter the image.
	#  * This is essentially a wrapper around the three implemented
	#    filtering routines: fslmaths, 3dBandpass, and genfilter
	################################################################
	else
	   subroutine           @2.15
	   exec_xcp \
	      tfilter \
	      -i ${intermediate}.nii.gz \
	      -o ${intermediate}_filtered.nii.gz \
	      -f ${regress_tmpf[${cxt}]} \
	      -h ${regress_hipass[${cxt}]} \
	      -l ${regress_lopass[${cxt}]} \
	      ${mask} \
	      ${tmask} \
	      ${tforder} \
	      ${tfdirec} \
	      ${tfprip} \
	      ${tfsrip} \
	      ${tfdvol} \
	      ${derivs} \
	      ${ts1d} \
	      ${trace_prop}
	   #############################################################
	   # Reorganise outputs
	   #############################################################
	   has_residuals=0
	   cmat_filtered=$(exec_sys \
	      ls -d1 ${intermediate}_filtered_${prefix}*_confmat.1D 2>/dev/null)
	   is_1D ${cmat_filtered} \
	      && exec_sys mv -f ${cmat_filtered}  \
	      ${intermediate}_filtered_confmat.1D
	   [[ -e ${intermediate}_filtered_tmask.1D ]] \
	      && exec_sys mv -f ${intermediate}_filtered_tmask.1D ${tmask[${cxt}]}
	   [[ -e ${intermediate}_filtered_derivs ]] \
	      && exec_sys mv -f ${intermediate}_filtered_derivs ${aux_imgs[${subjidx}]}
	fi
fi
###################################################################
# Update image pointer
###################################################################
intermediate=${intermediate}_filtered
configure   confproc    ${intermediate}_confmat.1D
routine_end





###################################################################
# Next, verify that the temporal mask exists before censoring.
###################################################################
if [[ ${censor[${cxt}]} != none ]] \
|| [[ ${regress_spkreg[${cxt}]} == Y ]]
	then
	routine                 @3    Censoring BOLD timeseries
	if is_1D ${tmask[${cxt}]}
	   then
	   subroutine           @3.1
	   tmaskpath=$(ls -d1 ${tmask[${cxt}]})
	elif is_1D ${tmask[${subjidx}]}
	   then
	   subroutine           @3.2
	   tmaskpath=$(ls -d1 ${tmask[${subjidx}]})
	else
	   subroutine           @3.3
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
if [[ ${censor[${cxt}]} != none ]]
	then
   subroutine              @3.4  [${censor[${cxt}]} censoring]
	exec_sys imcp ${intermediate}.nii.gz ${outdir}/${prefix}_uncensored.nii.gz
	exec_sys cp ${confproc[${cxt}]} ${outdir}/${prefix}_confmat_uncensored.1D
	################################################################
	# Use the temporal mask to determine which volumes are to be
	# left intact.
	#
	# Censoring is performed using the censor utility.
	################################################################
   subroutine              @3.5  [Applying the final censor]
	exec_xcp censor.R \
	   -t ${tmaskpath} \
	   -i ${intermediate}.nii.gz \
	   -o ${intermediate}_censored.nii.gz \
	   -d ${aux_imgs[${subjidx}]} \
	   -s ${confproc[${cxt}]}
	intermediate=${intermediate}_censored
	configure   confproc    ${intermediate}_confmat.1D
	exec_sys mv ${intermediate}_derivs ${aux_imgs[${subjidx}]}
	exec_sys mv ${intermediate}*confmat*.1D ${confproc[${cxt}]}
	nvol_pre=$(exec_fsl fslnvols ${outdir}/${prefix}_uncensored.nii.gz)
	nvol_post=$(exec_fsl fslnvols ${intermediate}.nii.gz)
	nvol_censored=$(( ${nvol_pre} - ${nvol_post} ))
	subroutine              @3.6  [${nvol_censored} volumes censored]
	echo ${nvol_censored} >> ${n_volumes_censored[${cxt}]}
   if [[ ${regress_spkreg[${cxt}]} == Y ]]
      then
      subroutine           @3.7  [Censoring executed: deactivating spike regression]
      configure            regress_spkreg    N
   fi
   routine_end
fi





###################################################################
# Alternatively, add spike regressors into the model. First
# ensure that there are any spikes to regress.
###################################################################
if [[ ${regress_spkreg[${cxt}]} == Y ]] \
&& [[ -e ${tmask[${subjidx}]} ]]
   then
   routine                 @4    Preparing spike regression
   if [[ $(cat ${tmask[${subjidx}]}|grep -i 0|wc -l) == 0 ]]
      then
      subroutine           @4.1  No spikes detected
      configure            regress_spkreg    N
   else
      subroutine           @4.2  Adding motion spikes
      exec_xcp tmask2spkreg.R \
         -t ${tmask[${subjidx}]} \
         -r ${confproc[${cxt}]} \
         >> ${confproc[${cxt}]}~TEMP~
      exec_sys mv ${confproc[${cxt}]}~TEMP~ \
         ${confproc[${cxt}]}
   fi
   routine_end
fi





###################################################################
# Finally, compute the residual BOLD timeseries by computing a
# linear model incorporating all nuisance variables.
###################################################################
routine                    @5    Converting BOLD timeseries to confound residuals
if (( ${has_residuals} == 1 ))
   then
   subroutine              @5.1  Confound residuals have already been computed
###################################################################
# Determine whether it is necessary to run the linear model.
###################################################################
elif ! is_image ${intermediate}_residuals.nii.gz \
|| rerun
   then
   subroutine              @5.2
	if [[ -e ${confproc[${cxt}]} ]]
	   then
	   subroutine           @5.3
	   exec_sys mv ${confproc[${cxt}]} ${confmat[${cxt}]}
	   configure            confproc   ${confmat[${cxt}]}
	else
	   subroutine           @5.4
	   configure            confproc   ${confmat[${subjidx}]}
	fi
	################################################################
	# Compute the internal correlations within the confound
	# matrix.
	################################################################
	subroutine              @5.5  [Computing confound correlations]
	exec_xcp ts2adjmat.R \
	   -t ${confproc[${cxt}]} \
	   >> ${confcor[${cxt}]}
	################################################################
	# Update paths to any local regressors.
	################################################################
	locregs=$(ls -d1 ${outdir}/*filtered_loc* 2>/dev/null)
   subroutine              @5.6  [Executing detrend]
   rm -f ${intermediate}_residuals.nii.gz
   for lr in ${locregs}
      do
      locreg_opts="${locreg_opts} -dsort ${lr}"
   done
   exec_afni 3dTproject \
      -input ${intermediate}.nii.gz \
      -ort ${confproc[${cxt}]} \
      ${locreg_opts} \
      -prefix ${intermediate}_residuals.nii.gz
fi
if is_image ${intermediate}_residuals.nii.gz
   then
   subroutine              @5.7
   intermediate=${intermediate}_residuals
else
   subroutine              @5.8  ::XCP-ERROR: The confound regression procedure failed.
   exit 666
fi
routine_end





###################################################################
# Apply the desired smoothing kernels to the BOLD timeseries.
#  * First, identify all kernels to apply.
###################################################################
routine                    @6    Spatially filtering image
smo=${regress_smo[${cxt}]//, }
###################################################################
# SUSAN setup
###################################################################
if [[ ${regress_sptf[${cxt}]} == susan ]] \
&& [[ -n ${smo} ]]
   then
   subroutine              @6.1  [Configuring SUSAN]
   ################################################################
   # Determine whether a custom USAN is being used, and register
   # it to analyte space if so.
   ################################################################
   if is_image ${regress_usan[${cxt}]}
      then
      subroutine           @6.2  Warping USAN
      load_transforms
      source ${XCPEDIR}/core/mapToSpace \
         ${regress_usan_space[${cxt}]}2${space} \
         ${regress_usan[${cxt}]} \
         ${intermediate}usan.nii.gz \
         NearestNeighbor
      usan="-u ${intermediate}usan"
      hardseg=-h
   ################################################################
	# Otherwise, ensure that an example functional image exists.
	#  * If it does not, force a switch to uniform smoothing to
	#    prevent a catastrophe.
   ################################################################
   elif is_image ${referenceVolumeBrain[${subjidx}]}
      then
      subroutine           @6.3
      usan="-u ${referenceVolumeBrain[${subjidx}]}"
   else
      subroutine           @6.4a No appropriate USAN: reconfiguring pipeline
      subroutine           @6.4b to smooth to uniformity instead
      configure            regress_sptf   uniform
   fi
fi
for ker in ${smo}
   do
   subroutine              @6.5
   derivative              img_sm${ker}   ${prefix}_sm${ker}
   img_sm_name=sm${ker}
   smoothed='img_sm'${ker}'['${cxt}']'
   if is_image ${!smoothed}
      then
      subroutine           @6.7
      write_derivative     img_sm${ker}
   ################################################################
   # If no spatial filtering has been specified by the user, then
   # bypass this step.
   ################################################################
   elif [[ ${regress_sptf[${cxt}]} == none ]] \
   || [[ ${ker} == 0 ]]
      then
      subroutine           @6.8
   else
      subroutine           @6.9a [Filter: ${regress_sptf[${cxt}]}]
      subroutine           @6.9b [Smoothing kernel: ${ker} mm]
      #############################################################
	   # Ensure that this step has not already run to completion
	   # by checking for the existence of a smoothed image. First,
	   # obtain the mask for filtering. Then, engage the sfilter
	   # routine.
      #############################################################
      if ! is_image ${!smoothed} \
      || rerun
         then
         subroutine        @6.10
         if is_image ${mask[${subjidx}]}
            then
            subroutine     @6.11
            mask=${mask[${subjidx}]}
         else
            subroutine     @6.12 Generating a mask using 3dAutomask
            exec_afni 3dAutomask \
               -prefix ${intermediate}_fmask.nii.gz \
               -dilate 3 \
               -q \
               ${intermediate}.nii.gz \
               2>/dev/null
            mask=${intermediate}_fmask.nii.gz
         fi
	      exec_xcp \
	         sfilter \
	         -i ${intermediate}.nii.gz \
	         -o ${!smoothed} \
	         -s ${regress_sptf[${cxt}]} \
	         -k ${ker} \
	         -m ${mask} \
	         ${usan} \
	         ${hardseg} \
	         ${trace_prop}
	   fi
      #############################################################
      # Update image pointer, and write the smoothed image path to
      # the design file and derivatives index so that it may be used
      # by additional modules.
      #############################################################
      write_derivative     img_sm${ker}
   fi
done
routine_end





exec_fsl immv ${intermediate}.nii.gz ${final[${cxt}]}
completion
