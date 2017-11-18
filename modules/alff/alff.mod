#!/usr/bin/env bash

###################################################################
#  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  #
###################################################################

###################################################################
# SPECIFIC MODULE HEADER
# This pipeline module computes the amplitude of low-frequency
# fluctuations.
# Based on work by Xi-Nian Zuo, Maarten Mennes & Michael Milham
# for NITRC
###################################################################
mod_name_short=alff
mod_name='AMPLITUDE OF LOW-FREQUENCY FLUCTUATIONS MODULE'
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
derivative     alff                    ${prefix}_alff
derivative     alffZ                   ${prefix}_alffZ

derivative_set alff     Statistic      mean
derivative_set alffZ    Statistic      mean

smooth_spatial_prime ${alff_smo[cxt]//,/ }            alff alffZ

add_reference        referenceVolume[$sub]   ${prefix}_referenceVolume

<< DICTIONARY

alff
   An unsmoothed voxelwise map of the amplitude of low-frequency
   fluctuations.
alff_sm
   Voxelwise maps of the amplitude of low-frequency fluctuations,
   computed over the smoothed time series.
kernel
   An array of all smoothing kernels to be applied to the
   time series, measured in mm.
img_sm
   The smoothed input time series.

DICTIONARY










###################################################################
# Apply the desired smoothing kernel to the BOLD timeseries.
# Start a list of kernels and smoothed images.
###################################################################
routine                       @1    Spatially filtering image
smooth_spatial                --SIGNPOST=${signpost}              \
                              --FILTER=alff_sptf[cxt]             \
                              --INPUT=${img}                      \
                              --USAN=${alff_usan[cxt]}            \
                              --USPACE=${alff_usan_space[cxt]}
routine_end





###################################################################
# Determine whether the voxelwise ALFF map needs to be computed
###################################################################
routine                       @2    Amplitude of low-frequency fluctuations
for k in ${kernels}
   do
   i=$(strslice ${k} 1 '#')
   k=$(strslice ${k} 2 '#')
   subroutine                 @2.0  At smoothness ${k} mm
   if (( ${k} == 0 ))
      then
      output_var='alff['${cxt}']'
      output_zvar='alffZ['${cxt}']'
   else
      output_var='alff_sm'${k}'['${cxt}']'
      output_zvar='alffZ_sm'${k}'['${cxt}']'
   fi
   if ! is_image ${!output_zvar} \
   || rerun
      then
      ################################################################
      # * Compute number of volumes: An even number is required by
      #   FSLpSpec
      # * Also obtain the repetition time
      ################################################################
      subroutine              @2.1  Ensuring integer periods
      exec_sys  rm -f         ${intermediate}EVEN.nii.gz
      nvol=$(exec_fsl         fslnvols   ${i})
      trep=$(exec_fsl         fslval     ${i} pixdim4)
      isOdd=$((               ${nvol} % 2 ))
      nvol=$((                ${nvol} / 2 * 2 ))
      ################################################################
      # If odd, remove the first volume
      ################################################################
      if (( ${isOdd} == 1 ))
         then
         subroutine           @2.2  Odd volume count: Excising first volume
         exec_fsl             \
            fslroi ${i}       \
            ${intermediate}EVEN.nii.gz \
            1                 \
            ${nvol}
      else
         subroutine           @2.3
         exec_sys             ln -s ${i} ${intermediate}EVEN.nii.gz
      fi
      i=${intermediate}EVEN.nii.gz
      
      
      ################################################################
      # Compute the power spectrum
      ################################################################
      subroutine              @2.4  Computing power spectrum
      exec_fsl fslpspec       ${i}  ${intermediate}PS.nii.gz
      subroutine              @2.5  Computing square root of amplitudes
      exec_fsl fslmaths       ${intermediate}PS.nii.gz \
                              -sqrt ${intermediate}PS-SQRT.nii.gz


      ################################################################
      # Compute the fractional frequency corresponding to the highpass
      # and lowpass cutoff frequencies
      ################################################################
      subroutine              @2.6  Extracting power spectrum at the low frequency band
      if [[ ${alff_lopass[cxt]} == nyquist ]]
         then
         subroutine           @2.6a
         configure            alff_lopass       99999
      fi
      n_hp=$(arithmetic ${alff_hipass[cxt]}*${nvol}*${trep})
      n_lp=$(arithmetic ${alff_lopass[cxt]}*${nvol}*${trep})
      n1=$(  arithmetic ${n_hp}-1         |xargs printf "%1.0f")
      n2=$(  arithmetic ${n_lp}-${n_hp}+1 |xargs printf "%1.0f")
      subroutine              @2.7a ${alff_hipass[cxt]} Hz is approximately position ${n1}
      subroutine              @2.7b of the power spectrum. There are about ${n2} frequency
      subroutine              @2.7d "positions corresponding to the passband (${alff_lopass[cxt]} - ${alff_hipass[cxt]} Hz)"
      subroutine              @2.7e "in the power spectrum."
      ################################################################
      # Extract the data corresponding to the passband from the power
      # spectrum square root of amplitudes
      ################################################################
      exec_fsl fslroi ${intermediate}PS-SQRT.nii.gz ${intermediate}PS-SLOW.nii.gz ${n1} ${n2}
      ################################################################
      # Compute ALFF; this is the sum of the amplitudes across all
      # frequencies in the passband
      ################################################################
      subroutine              @2.8  "Computing the amplitude of low-frequency fluctuations (ALFF)"
      exec_fsl fslmaths ${intermediate}PS-SLOW.nii.gz -Tmean -mul ${n2} ${!output_var}
      ################################################################
      # Convert the raw ALFF output values to standard scores.
      ################################################################
      subroutine              @2.9  Standardising ALFF values
      zscore_image            ${!output_var} ${!output_zvar}   ${mask[sub]}
   fi
done
routine_end





subroutine                    @0.1
completion
