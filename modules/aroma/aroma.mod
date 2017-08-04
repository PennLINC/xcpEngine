#!/usr/bin/env bash

###################################################################
#  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  #
###################################################################

###################################################################
# SPECIFIC MODULE HEADER
# ICA-AROMA-like denoising procedure without MNI-space requirement.
###################################################################
mod_name_short=aroma
mod_name='ICA-AROMA DENOISING MODULE'
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
derivative  ic_maps                 melodic/melodic_IC
derivative  ic_maps_thr             melodic/melodic_IC_thr
derivative  ic_maps_thr_std         melodic/melodic_IC_thr_std
derivative  sm${aroma_smo[${cxt}]}  ${prefix}_sm${aroma_smo[${cxt}]}

output      melodir                 melodic
output      ic_mix                  melodic/melodic_mix
output      ic_ft                   ${prefix}_ic_ft.1D
output      ic_ts                   ${prefix}_ic_ts.1D
output      ic_confmat              ${prefix}_ic_confmat.1D
output      ic_class                ${prefix}_ic_class.csv
output      ic_noise                ${prefix}_nICsNoise.txt

derivative_config   ic_maps         Type              maps
derivative_config   ic_maps_thr     Type              maps
derivative_config   ic_maps_thr_std Type              maps

process     final                   ${prefix}_icaDenoised

<< DICTIONARY

final
   The final output of the module, indicating its successful
   completion.
ic_class
   A matrix cataloguing the features used to classify MELODIC
   components as signal or noise.
ic_confmat
   A matrix of realignment parameter time courses. Includes
   6 realignment parameters, 6 temporal derivatives, 12 forward-
   shifted versions of the previous, 12 reverse-shifted versions
   of the previous, and 36 squared versions of all the previous.
ic_ft
   The frequency domain of the IC time series, separated into
   discrete bins. Used to determine the high-frequency content of
   each component.
ic_maps
   Spatial maps of all components identified by the MELODIC
   decomposition.
ic_maps_thr
   Spatial maps of all components identified by the MELODIC
   decomposition, thresholded.
ic_maps_thr_std
   Spatial maps of all components identified by the MELODIC
   decomposition, thresholded and normalised to a template.
ic_mix
   The time domain of the IC time series. Also called the MELODIC
   mixing matrix.
ic_noise
   The number of MELODIC components classified as noise.
ic_ts
   The time domain of the IC time series, along with the squares
   of the IC time series. The correlation between these 
melodir
   The MELODIC output directory.

DICTIONARY










###################################################################
# Apply the desired smoothing kernel to the BOLD timeseries.
###################################################################
if [[ -n ${aroma_smo[${cxt}]} ]] \
&& (( ${aroma_smo[${cxt}]} != 0 ))
   then
   routine                    @1    Spatially filtering image
   ################################################################
	# Ensure that this step has not already run to completion
	# by checking for the existence of a smoothed image.
   ################################################################
   img_sm=sm${aroma_smo[${cxt}]}
   if ! is_image ${!img_sm} \
   || rerun
      then
      subroutine              @1.1
      #############################################################
	   # Obtain the mask over which smoothing is to be applied
	   # Begin by searching for the subject mask; if this does
	   # not exist, then search for a mask created by this
	   # module.
      #############################################################
      if is_image ${mask[${subjidx}]}
         then
         subroutine           @1.2
         mask=${mask[${subjidx}]}
      else
         subroutine           @1.3  Generating a mask using 3dAutomask
         exec_afni 3dAutomask -prefix ${intermediate}_fmask.nii.gz \
            -dilate 3 \
            -q \
            ${img}
         mask=${intermediate}_fmask.nii.gz
      fi
      #############################################################
	   # Prime the inputs to sfilter for SUSAN filtering
      #############################################################
      if [[ ${aroma_sptf[${cxt}]} == susan ]]
         then
         ##########################################################
	      # Ensure that an example functional image exists. If it
	      # does not, then force a switch to uniform smoothing to
	      # mitigate the catastrophe.
         ##########################################################
	      if is_image ${referenceVolumeBrain[${subjidx}]}
            then
            subroutine        @1.4
            usan="-u ${referenceVolume[${subjidx}]}"
         else
            subroutine        @1.5
            configure         aroma_sptf        uniform
            write_config      aroma_aptf
         fi
      fi
      #############################################################
	   # Engage the sfilter routine to filter the image.
	   #  * This is essentially a wrapper around the three
	   #    implemented smoothing routines: gaussian, susan,
	   #    and uniform.
      #############################################################
      subroutine              @1.6a Filter: ${aroma_sptf[${cxt}]}
      subroutine              @1.6b Smoothing kernel: ${aroma_smo[${cxt}]} mm
	   exec_xcp sfilter \
	      -i ${img} \
	      -o ${!img_sm} \
	      -s ${aroma_sptf[${cxt}]} \
	      -k ${aroma_smo[${cxt}]} \
	      -m ${mask} \
	      ${usan}
	fi
   ################################################################
   # Update image pointer for the purpose of MELODIC.
   ################################################################
   img_in=${!img_sm}
   routine_end
else
   img_in=${img}
fi





###################################################################
# Use MELODIC to decompose the data into independent components.
# First, determine whether the user has specified the model order.
# If not, then MELODIC will automatically estimate it.
###################################################################
routine                       @2    ICA decomposition (MELODIC)
if [[ ${aroma_dim[${cxt}]} != auto ]]
   then
   subroutine                 @2.1
   melodim="--dim=${aroma_dim[${cxt}]}"
fi
###################################################################
# Obtain the repetition time.
###################################################################
trep=$(exec_fsl fslval ${img} pixdim4)
###################################################################
# Determine whether it is necessary to run MELODIC.
###################################################################
if ! is_image ${icmaps[${cxt}]} \
|| [[ ! -e ${icmix[${cxt}]} ]] \
|| rerun
   then
   subroutine                 @2.2  Model order: ${aroma_dim[${cxt}]}
   ################################################################
   # Preclude autosubmission to the grid, MELODIC may be
   # configured for autosubmission
   ################################################################
   buffer=${SGE_ROOT}
   unset SGE_ROOT
   exec_fsl melodic \
      --in=${img_in} \
      --outdir=${melodir[${cxt}]} \
      --mask=${mask[${subjidx}]} \
      ${melodim} \
      --Ostats \
      --nobet \
      --mmthresh=0.5 \
      --report \
      --tr=${trep}
   SGE_ROOT=${buffer}
fi
exec_sys mv -f ${outdir}/*.ica ${melodir[${cxt}]}
###################################################################
# Read in the dimension of the results (number of components
# obtained).
###################################################################
icdim=$(exec_fsl fslval ${icmaps[${cxt}]} dim4)
###################################################################
# Concatenate the mixture-modelled, thresholded spatial maps of
# the independent components.
#
# Iterate through all components.
###################################################################
curidx=1
while (( ${curidx} <= ${icdim} ))
   do
   subroutine                 @2.3
   ################################################################
   # Obtain the thresholded standard-scored spatial map of the
   # current component.
   # * If there are multiple maps for this IC, then extract only
   #   the last. According to the original implementation of
   #   ICA-AROMA, this occurs if the mixture modelling step fails
   #   to converge.
   ################################################################
   padidx=$(exec_fsl zeropad ${curidx} 4)
   zmapIn=${melodir[${cxt}]}/stats/thresh_zstat${curidx}
   zmapOut=${melodir[${cxt}]}/stats/thresh_zstat_${padidx}
   iclength=$(exec_fsl fslval ${zmapIn} dim4)
   finalMapIdx=$(( ${iclength} - 1 ))
   exec_fsl fslroi ${zmapIn} ${zmapOut} ${finalMapIdx} 1
   ################################################################
   # * Add the updated standard-scored map to the list of images
   #   to be concatenated.
   ################################################################
   toMerge="${toMerge} ${zmapOut}"
   (( curidx++ ))
done
###################################################################
# Concatenate and delete temporary files.
###################################################################
exec_fsl fslmerge -t ${icmaps_thr[${cxt}]} ${toMerge}
cleanup && exec_sys rm -f ${toMerge}
###################################################################
# Mask the thresholded component maps.
###################################################################
exec_fsl fslmaths ${icmaps_thr[${cxt}]} \
   -mas ${mask[${subjidx}]} \
   ${icmaps_thr[${cxt}]}
routine_end





###################################################################
# Prepare masks for component classification.
# * Obtain all transforms.
###################################################################
routine                       @3    Extracting features: CSF and edge fractions
load_transforms
###################################################################
# * Move the IC maps into the same space as the edge, CSF, and
#   background masks.
###################################################################
if ! is_image ${icmaps_thr_std[${cxt}]} \
|| rerun
   then
   subroutine                 @3.1  Standardising component maps
   spa=${space:0:3}
   [[ ${spa} == sta ]] && spa=std
   exec_sys rm -f ${icmaps_thr_std[${cxt}]}
   source ${XCPEDIR}/core/mapToSpace \
      ${spa}2standard \
      ${icmaps_thr[${cxt}]} \
      ${icmaps_thr_std[${cxt}]}
fi
###################################################################
# TODO (or perhaps not)
# Subject-specific mask generation. Absolutely not validated,
# and no a priori evidence that this is a good idea, so I may not
# come back to it. The following steps are listed here as a vague
# guideline for how this might be done.
# * Generate the CSF mask. Restrict this to the ventricles by
#   intersecting it with an eroded whole-brain mask. Dilate to
#   smooth the surface. Or perhaps simply erode then dilate to
#   trim periphery.
# * Subtract the CSF mask from a conservative whole-brain mask as
#   the initial basis for an edge mask.
# * Erode the edge mask precursor.
# * Subtract the eroded precursor from the preliminary precursor
#   to obtain a finalised edge mask.
###################################################################
configure                     csf      ${aroma_csf[${cxt}]}
configure                     edge     ${aroma_edge[${cxt}]}
configure                     bg       ${aroma_bg[${cxt}]}
###################################################################
# Obtain the CSF and edge fraction features for each IC.
###################################################################
i=0
while (( ${i} < ${icdim} ))
   do
   subroutine                 @3.2
   ################################################################
   # * Extract the current z-scored IC.
   ################################################################
   exec_fsl fslroi ${icmaps_thr_std[${cxt}]} ${intermediate}IC ${i} 1
   ################################################################
   # * Change to absolute value of z-score.
   ################################################################
   exec_fsl fslmaths ${intermediate}IC -abs ${intermediate}IC
   ################################################################
   # * Obtain the total absolute z-score for this component.
   ################################################################
   totMean=0
   totVox=($( exec_fsl fslstats ${intermediate}IC -V) )
   totMean=$( exec_fsl fslstats ${intermediate}IC -M)
   totSum=$(arithmetic   ${totVox[0]}*${totMean})
   ################################################################
   # * Obtain the total z-score within the CSF compartment.
   ################################################################
   csfMean=0
   csfVox=($( exec_fsl fslstats ${intermediate}IC -k ${csf[${cxt}]} -V) )
   csfMean=$( exec_fsl fslstats ${intermediate}IC -k ${csf[${cxt}]} -M)
   csfSum=$(arithmetic   ${csfVox[0]}*${csfMean})
   ################################################################
   # * Obtain the total z-score within the edge mask.
   ################################################################
   edgeMean=0
   edgeVox=($( exec_fsl fslstats ${intermediate}IC -k ${edge[${cxt}]} -V) )
   edgeMean=$( exec_fsl fslstats ${intermediate}IC -k ${edge[${cxt}]} -M)
   edgeSum=$(arithmetic ${edgeVox[0]}*${edgeMean})
   ################################################################
   # * Obtain the total z-score located in the background mask.
   ################################################################
   bgMean=0
   bgVox=($( exec_fsl fslstats ${intermediate}IC -k ${bg[${cxt}]} -V) )
   bgMean=$( exec_fsl fslstats ${intermediate}IC -k ${bg[${cxt}]} -M)
   bgSum=$(arithmetic     ${bgVox[0]}*${bgMean})
   ################################################################
   # * Obtain the fractional z-score with CSF and edge/out masks.
   ################################################################
   if (( ${totVox} == 0 ))
      then
      subroutine              @3.3
      classFCSF[${i}]=0
      classFEDGE[${i}]=0
   else
      subroutine              @3.4
      classFCSF[${i}]=$( arithmetic ${csfSum}/${totSum})
      classFEDGE[${i}]=$(arithmetic "(${bgSum} + ${edgeSum})/(${totSum} - ${csfSum})")
   fi
   ################################################################
   # * Cleanup: delete the extracted IC. Collate the fractional
   #   scores. Increment the IC index.
   ################################################################
   exec_sys rm -f ${intermediate}IC
   (( i++ ))
done
routine_end





###################################################################
# Obtain the maximum realignment parameter correlation feature
# for each IC.
# * Assemble realignment parameters into a 72-parameter model
#   that contains:
#   (6) realignment parameters;
#   (12) their temporal derivatives;
#   (36) forward- and reverse-shifted timeseries;
#   (72) squares of each.
###################################################################
routine                       @4    Extracting feature: maximum correlation with RPs
subroutine                    @4.1  Generating 72-parameter RP model
exec_xcp mbind.R \
   -x 'null' \
   -y ${rps[${subjidx}]} \
   -o ${ic_confmat[${cxt}]}
exec_xcp mbind.R \
   -x ${ic_confmat[${cxt}]} \
   -y OPdx1 \
   -o ${ic_confmat[${cxt}]}
exec_xcp mbind.R \
   -x ${ic_confmat[${cxt}]} \
   -y OPprev1,-1 \
   -o ${ic_confmat[${cxt}]}
exec_xcp mbind.R \
   -x ${ic_confmat[${cxt}]} \
   -y OPpower2 \
   -o ${ic_confmat[${cxt}]}
###################################################################
# * Assemble IC timeseries.
#   Also obtain the square of each.
###################################################################
subroutine                    @4.2  Obtaining IC timeseries and squares
exec_xcp mbind.R \
   -x ${ic_mix[${cxt}]} \
   -y OPpower2 \
   -o ${ic_ts[${cxt}]}
###################################################################
# * Obtain the maximum absolute correlation between each IC
#   timeseries and the realignment parameters. Squared realignment
#   parameters should be matched to squared IC timeseries.
# * This should be computed as a robust correlation; 90 percent
#   of each timeseries is randomly sampled, and the correlations
#   between such sampled timeseries are computed 1000 times.
###################################################################
subroutine                    @4.3  Computing IC-RP correlations
echo_cmd ${XCPEDIR}/modules/aroma/aromaRPCOR.R \
   -i ${ic_ts[${cxt}]} \
   -r ${ic_confmat[${cxt}]}
classRPCOR=($(${XCPEDIR}/modules/aroma/aromaRPCOR.R \
   -i ${ic_ts[${cxt}]} \
   -r ${ic_confmat[${cxt}]}))
routine_end





###################################################################
# Obtain the high-frequency content feature for each IC.
# This is the frequency (as a fraction of Nyquist) at which higher
# frequencies explain 50 percent of the total sampled power.
#
# NOTE: It is important to perform this prior to any filtering
# step.
###################################################################
routine                       @5    Extracting feature: high-frequency content
subroutine                    @5.1a Computing midpoints of IC power spectra
subroutine                    @5.1b Ensure that you have not performed any filtering,
subroutine                    @5.1c as filtering will cause incorrect classifications
exec_sys ln -s ${melodir[${cxt}]}/melodic_FTmix ${ic_ft[${cxt}]}
echo_cmd ${XCPEDIR}/modules/aroma/aromaHIFRQ.R \
   -i ${ic_ft[${cxt}]} \
   -t ${trep}
classHIFRQ=($(${XCPEDIR}/modules/aroma/aromaHIFRQ.R \
   -i ${ic_ft[${cxt}]} \
   -t ${trep}))
routine_end





###################################################################
# Write all componentwise features to a classification table.
###################################################################
routine                       @6    Component classification
subroutine                    @6.1  Assembling feature table
i=0
echo "ICID,RPCOR,FEDGE,FCSF,HFC" >> ${ic_class[${cxt}]}
while (( ${i} < ${icdim} ))
   do
   subroutine                 @6.2
   echo ${i},${classRPCOR[${i}]},${classFEDGE[${i}]},${classFCSF[${i}]},${classHIFRQ[${i}]} >> ${ic_class[${cxt}]}
   (( i++ ))
done
###################################################################
# Apply the classification algorithm.
###################################################################
subroutine                    @6.3  Applying the classifier
echo_cmd ${XCPEDIR}/modules/aroma/aromaCLASS.R \
   -m ${classmat[${cxt}]}
noiseIdx=$(${XCPEDIR}/modules/aroma/aromaCLASS.R \
   -m ${classmat[${cxt}]})
noiseComponents=( ${noiseIdx} )
echo ${#noiseComponents[@]} >> ${ic_noise[${cxt}]}
routine_end





###################################################################
# Denoise the image based on IC classes.
###################################################################
routine                       @7    Denoising
noiseIdx=${noiseIdx// /,}
subroutine                    @7.1  Non-aggressive filter
exec_fsl fsl_regfilt \
   --in=${img} \
   --design=${ic_mix[${cxt}]} \
   --filter=${noiseIdx} \
   --out=${outdir}/${prefix}_icaDenoised_nonaggr
subroutine                    @7.2  Aggressive filter
fsl_regfilt \
   --in=${img} \
   --design=${ic_mix[${cxt}]} \
   --filter=${noiseIdx} \
   -a \
   --out=${outdir}/${prefix}_icaDenoised_aggr
if [[ ${aroma_dtype[${cxt}]} == aggr ]]
   then
   subroutine                 @7.3  Using aggressive filter
   exec_sys immv ${outdir}/${prefix}_icaDenoised_aggr    ${final[${cxt}]}
elif [[ ${aroma_dtype[${cxt}]} == nonaggr ]]
   then
   subroutine                 @7.4  Using non-aggressive filter
   exec_sys immv ${outdir}/${prefix}_icaDenoised_nonaggr ${final[${cxt}]}
fi
routine_end





###################################################################
# Detrend the denoised timeseries if detrending is requested.
#
# This should be run if you are applying a filter that is
# sensitive to such things.
###################################################################
routine                       @8    Demeaning and detrending BOLD timeseries
if [[ ${aroma_dmdt[${cxt}]} != N ]]
   then
   ################################################################
   # A spatial mask of the brain is necessary for ANTsR to read
   # the image.
   ################################################################
   if is_image ${mask[${subjidx}]}
      then
      subroutine              @8.1  Using previously determined mask
      mask_dmdt=${mask[${subjidx}]}
   ################################################################
	# If no mask has yet been computed for the subject,
	# then a new mask can be computed quickly using
	# AFNI's 3dAutomask tool.
   ################################################################
   else
      subroutine              @8.2  Generating a mask using 3dAutomask
      exec_afni 3dAutomask -prefix ${intermediate}_fmask.nii.gz \
         -dilate 3 \
         -q \
         ${final[${cxt}]}
      mask_dmdt=${intermediate}_fmask.nii.gz
   fi
   ################################################################
	# If the user has requested iterative censoring of
	# motion-corrupted volumes, then the demean/detrend
	# step should exclude the corrupted volumes from the
	# linear model. In this case, a temporal mask is
	# required for the demean/detrend step.
	#
   # If motion correction was run for the first time
   # during this module, then the censoring requested by
   # the user should be defined in censor[cxt]. If it is
   # not, then set it to the global subject value.
   ################################################################
   if [[ -z ${censor[${cxt}]} ]]
      then
      subroutine              @8.3
      configure               censor      ${censor[${subjidx}]}
   fi
   ################################################################
	# The temporal mask must be stored either in the
	# module-specific censor[cxt] variable or in the
	# subject-specific censor[subjidx] variable.
   ################################################################
   if is_1D ${tmask[${subjidx}]} \
   && [[ ${censor[${cxt}]} == iter ]]
      then
      subroutine              @8.4.1
      tmask_dmdt=${tmask[${subjidx}]}
   ################################################################
   # If iterative censoring has not been specified or
   # if no temporal mask exists yet, then all time
   # points must be used in the linear model.
   ################################################################
   else
      subroutine              @8.4.2
      tmask_dmdt=ones
   fi
   ################################################################
   # AFNI's afni_proc.py pipeline uses a formula to
   # automatically determine an appropriate order of
   # polynomial detrend to apply to the data.
   #
   #        floor(1 + TR*nVOLS / 150)
   #
   # In summary, the detrend order is based upon the
   # overall duration of the scan. If the user has
   # requested automatic determination of detrend order,
   # then it is computed here. Note that there are a
   # number of assumptions in this computation, and it
   # may not always be appropriate.
   ################################################################
	if ! is+integer ${aroma_dmdt[${cxt}]}
	   then
      subroutine           @8.5.1 Estimating polynomial order
	   nvol=$(exec_fsl fslnvols ${final[${cxt}]})
      trep=$(exec_fsl fslval   ${final[${cxt}]} pixdim4)
      dmdt_order=$(arithmetic 1 + ${trep}\*${nvol}/150)
	else
	   subroutine           @8.5.2
	   dmdt_order=${aroma_dmdt[${cxt}]}
	fi
   ################################################################
	# Now, pass the inputs computed above to the detrend
	# function itself.
   ################################################################
   subroutine              @8.6a Applying polynomial detrend
   subroutine              @8.6b Order: ${dmdt_order}
   exec_xcp dmdt.R \
      -d ${dmdt_order} \
      -i ${final[${cxt}]} \
      -m ${mask_dmdt} \
      -t ${tmask_dmdt} \
      -o ${final[${cxt}]}
fi
###################################################################
# Update image pointer
###################################################################
routine_end





subroutine                    @0.1
completion
