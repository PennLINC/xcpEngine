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
   write_derivative  alff
   write_derivative  alffZ
   
   for k in ${kernel[${cxt}]}
      do
      write_derivative  alff_sm${k}
      write_derivative  alffZ_sm${k}
      write_derivative  img_sm${k}
   done
   
   source ${XCPEDIR}/core/auditComplete
   source ${XCPEDIR}/core/updateQuality
   source ${XCPEDIR}/core/moduleEnd
}





###################################################################
# OUTPUTS
###################################################################
derivative  alff                    ${prefix}_alff
derivative  alffZ                   ${prefix}_alffZ

configure   kernel                  ${alff_smo[${cxt}]//,/ }

for k in ${kernel[${cxt}]}
   do
   derivative        alff_sm${k}    ${prefix}_alff_sm${k}
   derivative        alffZ_sm${k}   ${prefix}_alffZ_sm${k}
   derivative        img_sm${k}     ${prefix}_sm${k}
   derivative_config img_sm${k}     Type     timeseries
done

derivative_config    alff           Statistic         mean
derivative_config    alffZ          Statistic         mean

add_reference        referenceVolume[${subjidx}]   ${prefix}_referenceVolume

<< DICTIONARY

alff
   An unsmoothed voxelwise map of the amplitude of low-frequency
   fluctuations.
alff_sm
   Voxelwise maps of the amplitude of low-frequency fluctuations,
   computed over the smoothed timeseries.
kernel
   An array of all smoothing kernels to be applied to the
   timeseries, measured in mm.
img_sm
   The smoothed input timeseries.

DICTIONARY










###################################################################
# Apply the desired smoothing kernel to the BOLD timeseries.
###################################################################
routine                       @1    Spatially filtering image
kernels=${img}'#0'
for k in ${kernel[${cxt}]}
   do
   sm_sub=img_sm${k}[${subjidx}]
   sm_mod=img_sm${k}[${cxt}]
   ################################################################
   # Determine whether an image with the specified smoothing kernel
   # already exists
   ################################################################
   if is_image ${!sm_sub}
      then
      subroutine              @1.1a
      kernels="${kernels} ${!sm_sub}#${k}"
   elif is_image ${!sm_mod} \
   && ! rerun
      then
      subroutine              @1.1b
      kernels="${kernels} ${!sm_mod}#${k}"
   ################################################################
   # If no spatial filtering has been specified by the user, then
   # bypass this step.
   ################################################################
   elif [[ ${alff_sptf[${cxt}]} == none ]]
      then
      subroutine              @1.2
      kernels=${img}
      break
   elif (( ${k} == 0 ))
      then
      subroutine              @1.3
   else
      subroutine              @1.4a Filter: ${alff_sptf[${cxt}]}
      subroutine              @1.4a Smoothing kernel: ${k} mm
      #############################################################
	   # Obtain the mask over which smoothing is to be applied.
	   # Begin by searching for the subject mask; if this does
	   # not exist, then search for a mask created by this
	   # module.
      #############################################################
      if is_image ${mask[${subjidx}]}
         then
         subroutine           @1.5
         mask=${mask[${subjidx}]}
      else
         subroutine           @1.6b Generating a mask using 3dAutomask
         exec_afni 3dAutomask -prefix ${outbase}_fmask${ext} \
            -dilate 3 \
            -q \
            ${img}${ext}
         mask=${outbase}_fmask${ext}
      fi
      #############################################################
	   # Prime the inputs to sfilter for SUSAN filtering
      #############################################################
      if [[ ${alff_sptf[${cxt}]} == susan ]]
         then
         if is_image ${alff_usan[${cxt}]}
            then
            subroutine        @1.7  Warping USAN
            load_transforms
            source ${XCPEDIR}/core/mapToSpace \
               ${alff_usan_space[${cxt}]}2${space} \
               ${alff_usan[${cxt}]} \
               ${intermediate}usan.nii.gz \
               NearestNeighbor
            usan="-u ${intermediate}usan"
            hardseg=-h
         ##########################################################
	      # Ensure that an example functional image exists.
	      #  * If it does not, then you are probably doing
	      #    something stupid.
	      #  * In this case, force a switch to uniform
	      #    smoothing to mitigate the catastrophe.
         ##########################################################
	      elif is_image ${referenceVolumeBrain[${subjidx}]}
            then
            subroutine        @1.8
            usan="-u ${referenceVolumeBrain[${subjidx}]}"
         else
            subroutine        @1.9a No appropriate USAN: reconfiguring pipeline
            subroutine        @1.9b to smooth to uniformity instead
            configure            alff_sptf   uniform
            write_config         alff_sptf
         fi
      fi
      ##########################################################
	   # Engage the sfilter routine to filter the image.
	   #  * This is essentially a wrapper around the three
	   #    implemented smoothing routines: gaussian, susan,
	   #    and uniform.
      ##########################################################
      subroutine              @1.10
	   exec_xcp sfilter \
	      -i ${img} \
	      -o ${!sm_mod} \
	      -s ${alff_sptf[${cxt}]} \
	      -k ${alff_smo[${cxt}]} \
	      -m ${mask} \
	      ${usan} \
	      ${trace_prop}
      #############################################################
      # Update image pointer, and write the smoothed image path to
      # the design file and derivatives index so that it may be used
      # by additional modules.
      #############################################################
      kernels="${kernels} ${!sm_mod}#${k}"
   fi
done
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
         exec_fsl \
            fslroi ${i} \
            ${intermediate}EVEN.nii.gz \
            1 \
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
      if [[ ${alff_lopass[${cxt}]} == nyquist ]]
         then
         subroutine           @2.6a
         configure            alff_lopass       99999
      fi
      n_hp=$(arithmetic ${alff_hipass[${cxt}]}*${nvol}*${trep})
      n_lp=$(arithmetic ${alff_lopass[${cxt}]}*${nvol}*${trep})
      n1=$(  arithmetic ${n_hp}-1         |xargs printf "%1.0f")
      n2=$(  arithmetic ${n_lp}-${n_hp}+1 |xargs printf "%1.0f")
      subroutine              @2.7a ${alff_hipass[${cxt}]} Hz is approximately position ${n1}
      subroutine              @2.7b of the power spectrum. There are about ${n2} frequency
      subroutine              @2.7d "positions corresponding to the passband (${alff_lopass[${cxt}]} - ${alff_hipass[${cxt}]} Hz)"
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
      subroutine              @2.8  Computing the amplitude of low-frequency fluctuations (ALFF)
      exec_fsl fslmaths ${intermediate}PS-SLOW.nii.gz -Tmean -mul ${n2} ${!output_var}
      ################################################################
      # Convert the raw ALFF output values to standard scores.
      ################################################################
      subroutine              @2.9  Standardising ALFF values
      zscore_image            ${!output_var} ${!output_zvar}   ${mask[${subjidx}]}
   fi
done
routine_end





subroutine                    @0.1
completion
