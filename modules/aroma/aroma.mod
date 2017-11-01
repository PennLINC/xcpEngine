#!/usr/bin/env bash

###################################################################
#  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  #
###################################################################

###################################################################
# SPECIFIC MODULE HEADER
# This module implements an ICA-AROMA-inspired denoising procedure.
###################################################################
mod_name_short=aroma
mod_name='ICA-AROMA DENOISING MODULE'
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
derivative  ic_maps                 melodic/melodic_IC
derivative  ic_maps_thr             melodic/melodic_IC_thr
derivative  ic_maps_thr_mni         melodic/melodic_IC_thr_mni

output      melodir                 melodic
output      ic_mix                  melodic/melodic_mix
output      ic_ft                   ${prefix}_ic_ft.1D
output      ic_ts                   ${prefix}_ic_ts.1D
output      ic_confmat              ${prefix}_ic_confmat.1D
output      ic_class                ${prefix}_ic_class.csv

qc          ic_noise nICsNoise      ${prefix}_nICsNoise.txt

derivative_set   ic_maps            Type              maps
derivative_set   ic_maps_thr        Type              maps
derivative_set   ic_maps_thr_mni    Type              maps
derivative_set   ic_maps_thr_mni    Space             MNI

configure   demeaned                0
input       demeaned
input       confmat as confproc

smooth_spatial_prime                ${aroma_smo[cxt]}

final       icaDenoised             ${prefix}_icaDenoised

<< DICTIONARY

confmat
   The confound matrix after filtering and censoring.
confproc
   A pointer to the working version of the confound matrix.
demeaned
   A Boolean indicator of whether the analyte image is demeaned.
ic_class
   A matrix cataloguing the features used to classify MELODIC
   components as signal or noise.
ic_confmat
   A matrix of 72 realignment parameter time courses. Includes
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
ic_maps_thr_mni
   Spatial maps of all components identified by the MELODIC
   decomposition, thresholded and normalised to the MNI template.
ic_mix
   The time domain of the IC time series. Also called the MELODIC
   mixing matrix.
ic_noise
   The number of MELODIC components classified as noise.
ic_ts
   The time domain of the IC time series, along with the squares
   of the IC time series. The correlation between these and the
   realignment parameter time courses is used as an input to the
   classifier.
icaDenoised
   The denoised map. The final output of the module.
melodir
   The MELODIC output directory.

DICTIONARY










###################################################################
# Apply the desired smoothing kernel to the BOLD timeseries. If
# smoothing is performed in the module, it is also contained in
# the module: the smoothed image is used to obtain the MELODIC
# components, but de-noising is performed on the unsmoothed data,
# and the unsmoothed data is propagated to the primary analyte.
###################################################################
if [[ ${aroma_sptf[cxt]} != none ]] \
&& (( ${aroma_smo[cxt]}  != 0 ))
   then
   routine                    @1    Spatially filtering image
   smooth_spatial             --SIGNPOST=${signpost}           \
                              --FILTER=aroma_sptf[$cxt]        \
                              --INPUT=${intermediate}          \
                              --USAN=${aroma_usan[cxt]}        \
                              --USPACE=${aroma_usan_space[cxt]}
   ################################################################
   # Update image pointer for the purpose of MELODIC.
   ################################################################
   smoothed='img_sm'${aroma_smo[cxt]}'['${cxt}']'
   img_in=${!smoothed}
   routine_end
else
   img_in=${img}
fi





###################################################################
# Use MELODIC to decompose the data into independent components.
# First, determine whether the user has specified the model order.
# If not, then MELODIC will automatically estimate it.
###################################################################
routine                       @2    "ICA decomposition (MELODIC)"
if [[ ${aroma_dim[cxt]} != auto ]]
   then
   subroutine                 @2.1
   melodim="--dim=${aroma_dim[cxt]}"
fi
###################################################################
# Obtain the repetition time.
###################################################################
trep=$(exec_fsl fslval ${img} pixdim4)
###################################################################
# Determine whether it is necessary to run MELODIC.
###################################################################
if ! is_image ${ic_maps[cxt]} \
|| [[ ! -e ${ic_mix[cxt]} ]] \
|| rerun
   then
   subroutine                 @2.2  Model order: ${aroma_dim[cxt]}
   ################################################################
   # Preclude autosubmission to the grid, MELODIC may be
   # configured for autosubmission
   ################################################################
   buffer=${SGE_ROOT}
   unset SGE_ROOT
   exec_fsl melodic              \
      --in=${img_in}             \
      --outdir=${melodir[cxt]}   \
      --mask=${mask[sub]}        \
      ${melodim}                 \
      --Ostats                   \
      --nobet                    \
      --mmthresh=0.5             \
      --report                   \
      --tr=${trep}
   SGE_ROOT=${buffer}
fi
exec_sys mv -f ${outdir}/*.ica ${melodir[cxt]} 2>/dev/null
###################################################################
# Read in the dimension of the results (number of components
# obtained).
###################################################################
icdim=$(exec_fsl fslval ${ic_maps[cxt]} dim4)
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
   zmapIn=${melodir[cxt]}/stats/thresh_zstat${curidx}
   zmapOut=${melodir[cxt]}/stats/thresh_zstat_${padidx}
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
exec_fsl fslmerge    -t ${ic_maps_thr[cxt]} ${toMerge}
cleanup  && exec_sys rm -f ${toMerge}
###################################################################
# Mask the thresholded component maps.
###################################################################
exec_fsl fslmaths    ${ic_maps_thr[cxt]} \
   -mas  ${mask[sub]} \
   ${ic_maps_thr[cxt]}
routine_end





###################################################################
# Prepare masks for component classification.
# * Obtain all transforms.
###################################################################
routine                       @3    Extracting features: CSF and edge fractions
###################################################################
# * Move the IC maps into MNI space.
###################################################################
if ! is_image ${ic_maps_thr_mni[cxt]} \
|| rerun
   then
   subroutine                 @3.1  Standardising component maps
   exec_sys rm -f ${ic_maps_thr_mni[cxt]}
   warpspace \
      ${ic_maps_thr[cxt]} \
      ${ic_maps_thr_mni[cxt]} \
      ${space[sub]}:MNI%2x2x2
   ! is_image ${ic_maps_thr_mni[cxt]} && abort_stream
fi
###################################################################
# Import the edge, CSF, and background masks.
###################################################################
configure                     csf      ${XCPEDIR}/thirdparty/aroma/mask_csf.nii.gz
configure                     edge     ${XCPEDIR}/thirdparty/aroma/mask_edge.nii.gz
configure                     bg       ${XCPEDIR}/thirdparty/aroma/mask_bg.nii.gz
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
   exec_fsl fslroi ${ic_maps_thr_mni[cxt]} ${intermediate}IC ${i} 1
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
   totSum=$(arithmetic   "${totVox[0]}*${totMean}")
   ################################################################
   # * Obtain the total z-score within the CSF compartment.
   ################################################################
   csfMean=0
   csfVox=($( exec_fsl fslstats ${intermediate}IC -k ${csf[cxt]} -V) )
   csfMean=$( exec_fsl fslstats ${intermediate}IC -k ${csf[cxt]} -M)
   csfSum=$(arithmetic   "${csfVox[0]}*${csfMean}")
   ################################################################
   # * Obtain the total z-score within the edge mask.
   ################################################################
   edgeMean=0
   edgeVox=($( exec_fsl fslstats ${intermediate}IC -k ${edge[cxt]} -V) )
   edgeMean=$( exec_fsl fslstats ${intermediate}IC -k ${edge[cxt]} -M)
   edgeSum=$(arithmetic "${edgeVox[0]}*${edgeMean}")
   ################################################################
   # * Obtain the total z-score located in the background mask.
   ################################################################
   bgMean=0
   bgVox=($( exec_fsl fslstats ${intermediate}IC -k ${bg[cxt]} -V) )
   bgMean=$( exec_fsl fslstats ${intermediate}IC -k ${bg[cxt]} -M)
   bgSum=$(arithmetic     "${bgVox[0]}*${bgMean}")
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
   -y ${rps[sub]} \
   -o ${ic_confmat[cxt]}
exec_xcp mbind.R \
   -x ${ic_confmat[cxt]} \
   -y OPdx1 \
   -o ${ic_confmat[cxt]}
exec_xcp mbind.R \
   -x ${ic_confmat[cxt]} \
   -y OPprev1,-1 \
   -o ${ic_confmat[cxt]}
exec_xcp mbind.R \
   -x ${ic_confmat[cxt]} \
   -y OPpower2 \
   -o ${ic_confmat[cxt]}
###################################################################
# * Assemble IC timeseries.
#   Also obtain the square of each.
###################################################################
subroutine                    @4.2  Obtaining IC timeseries and squares
exec_xcp mbind.R \
   -x ${ic_mix[cxt]} \
   -y OPpower2 \
   -o ${ic_ts[cxt]}
###################################################################
# * Obtain the maximum absolute correlation between each IC
#   timeseries and the realignment parameters. Squared realignment
#   parameters should be matched to squared IC timeseries.
# * This should be computed as a robust correlation; 90 percent
#   of each timeseries is randomly sampled, and the correlations
#   between such sampled timeseries are computed 1000 times.
###################################################################
subroutine                    @4.3  Computing IC-RP correlations
verbose && echo_cmd \
${XCPEDIR}/modules/aroma/aromaRPCOR.R \
   -i ${ic_ts[cxt]} \
   -r ${ic_confmat[cxt]}
classRPCOR=($(${XCPEDIR}/modules/aroma/aromaRPCOR.R \
   -i ${ic_ts[cxt]} \
   -r ${ic_confmat[cxt]}))
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
exec_sys ln -s ${melodir[cxt]}/melodic_FTmix ${ic_ft[cxt]}
verbose && echo_cmd \
${XCPEDIR}/modules/aroma/aromaHIFRQ.R \
   -i ${ic_ft[cxt]} \
   -t ${trep}
classHIFRQ=($(${XCPEDIR}/modules/aroma/aromaHIFRQ.R \
   -i ${ic_ft[cxt]} \
   -t ${trep}))
routine_end





###################################################################
# Write all componentwise features to a classification table.
###################################################################
routine                       @6    Component classification
subroutine                    @6.1  Assembling feature table
i=0
echo "ICID,RPCOR,FEDGE,FCSF,HFC" >> ${ic_class[cxt]}
while (( ${i} < ${icdim} ))
   do
   subroutine                 @6.2
   echo ${i},${classRPCOR[${i}]},${classFEDGE[${i}]},${classFCSF[${i}]},${classHIFRQ[${i}]} >> ${ic_class[cxt]}
   (( i++ ))
done
###################################################################
# Apply the classification algorithm.
###################################################################
subroutine                    @6.3  Applying the classifier
verbose && echo_cmd \
${XCPEDIR}/modules/aroma/aromaCLASS.R \
   -m ${ic_class[cxt]}
noiseIdx=$(${XCPEDIR}/modules/aroma/aromaCLASS.R \
   -m ${ic_class[cxt]})
noiseComponents=( ${noiseIdx} )
echo ${#noiseComponents[@]} >> ${ic_noise[cxt]}
routine_end





###################################################################
# Denoise the image based on IC classes.
###################################################################
routine                       @7    Denoising
noiseIdx=${noiseIdx// /,}
subroutine                    @7.1  Non-aggressive filter
proc_fsl ${outdir}/${prefix}_icaDenoised_nonaggr.nii.gz \
fsl_regfilt                \
   --in=${img}             \
   --design=${ic_mix[cxt]} \
   --filter=${noiseIdx}    \
   --out=%OUTPUT
subroutine                    @7.2  Aggressive filter
proc_fsl ${outdir}/${prefix}_icaDenoised_aggr.nii.gz \
fsl_regfilt                \
   --in=${img}             \
   --design=${ic_mix[cxt]} \
   --filter=${noiseIdx}    \
   -a                      \
   --out=%OUTPUT
if [[ ${aroma_dtype[cxt]} == aggr ]]
   then
   subroutine                 @7.3  Using aggressive filter
   exec_sys ln -sf ${outdir}/${prefix}_icaDenoised_aggr.nii.gz     ${icaDenoised[cxt]}
elif [[ ${aroma_dtype[cxt]} == nonaggr ]]
   then
   subroutine                 @7.4  Using non-aggressive filter
   exec_sys ln -sf ${outdir}/${prefix}_icaDenoised_nonaggr.nii.gz  ${icaDenoised[cxt]}
fi
routine_end





###################################################################
# Detrend the denoised timeseries if detrending is requested.
#
# This should be run if you are applying a filter that is
# sensitive to such things.
###################################################################
if (( ${demeaned[cxt]} == 0 ))
   then
   routine                    @8    Demeaning and detrending BOLD timeseries
   demean_detrend             --SIGNPOST=${signpost}           \
                              --ORDER=${aroma_dmdt[cxt]}       \
                              --INPUT=${icaDenoised[cxt]}      \
                              --OUTPUT=${icaDenoised[cxt]}     \
                              --CONFIN=${confproc[cxt]}        \
                              --CONFOUT=${confmat[cxt]}
   routine_end
fi





subroutine                    @0.1
completion
