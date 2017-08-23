#!/usr/bin/env bash

###################################################################
#  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  #
###################################################################

###################################################################
# SPECIFIC MODULE HEADER
# This module performs seed-based correlation analyses.
###################################################################
mod_name_short=seed
mod_name='SEED-BASED CORRELATION MODULE'
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
   for seed in ${seeds[cxt]}
      do
      seed=(               ${seed//\#/ } )
      seed[0]=$(           eval echo            ${seed[0]})
      write_output         ${seed[0]}_ts
      write_derivative     ${seed[0]}_seed
      write_derivative     ${seed[0]}
      write_derivative     ${seed[0]}Z
   done
   for k in ${kernel[cxt]}
      do
      for seed in ${seeds[cxt]}
         do
         seed=(            ${seed//\#/ } )
         seed[0]=$(        eval echo            ${seed[0]})
         write_derivative  ${seed[0]}_sm${k}
         write_derivative  ${seed[0]}Z_sm${k}
      done
      write_derivative     img_sm${k}
   done
   
   source ${XCPEDIR}/core/auditComplete
   source ${XCPEDIR}/core/updateQuality
   source ${XCPEDIR}/core/moduleEnd
}





###################################################################
# OUTPUTS
###################################################################
configure   seeds                   $(grep -i '^#' ${seed_lib[cxt]})
configure   kernel                  ${seed_smo[cxt]//,/ }

for seed in ${seeds[cxt]}
   do
   seed=(            ${seed//\#/ } )
   seed[0]=$(        eval echo            ${seed[0]})
   configure         mapdir               ${outdir}/${seed[0]}/
   exec_sys          mkdir -p             ${mapdir[cxt]}
   configure         mapbase              ${mapdir[cxt]}/${prefix}_connectivity
   output            ${seed[0]}_ts        ${mapbase[cxt]}_${seed[0]}_ts.1D
   derivative        ${seed[0]}_seed      ${mapbase[cxt]}_${seed[0]}_seed
   derivative        ${seed[0]}           ${mapbase[cxt]}_${seed[0]}
   derivative        ${seed[0]}Z          ${mapbase[cxt]}_${seed[0]}Z
done
for k in ${kernel[cxt]}
   do
   for seed in ${seeds[cxt]}
      do
      seed=(         ${seed//\#/ } )
      seed[0]=$(     eval echo            ${seed[0]})
      configure      mapbase              ${outdir}/${seed[0]}/${prefix}_connectivity
      derivative     ${seed[0]}_sm${k}    ${mapbase[cxt]}_${seed[0]}_sm${k}
      derivative     ${seed[0]}Z_sm${k}   ${mapbase[cxt]}_${seed[0]}Z_sm${k}
   done
   derivative        img_sm${k}           ${prefix}_sm${k}
   derivative_config img_sm${k}           Type     timeseries
done

<< DICTIONARY

THE OUTPUTS OF SEED-BASED CORRELATION ANALYSIS ARE PRIMARILY
DEFINED IN THE LOOP OVER SEEDS.

img_sm
   The smoothed input timeseries.
kernel
   An array of all smoothing kernels to be applied to the
   timeseries, measured in mm.
mapbase
   The base path to any seed-based connectivity maps.
seeds
   An index of seeds to be analysed.

DICTIONARY










###################################################################
# Retrieve all the seeds for which analysis should be run, and
# prime the analysis.
###################################################################
if [[ -s ${seed_lib[cxt]} ]]
   then
   subroutine                 @0.1
   add_reference     referenceVolume[$sub]   ${prefix}_referenceVolume
else
   echo \
"
::XCP-WARNING: Seed-based correlation analysis has been requested,
  but no seed libraries have been provided.
  
  Skipping module"
   exit 1
fi





###################################################################
# Apply the desired smoothing kernel to the BOLD timeseries.
###################################################################
routine                       @1    Spatially filtering image
kernels=${img}'#0'
for k in ${kernel[cxt]}
   do
   sm_sub=img_sm${k}[$sub]
   sm_mod=img_sm${k}[$cxt]
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
   elif [[ ${seed_sptf[cxt]} == none ]]
      then
      subroutine              @1.2
      kernels=${img}'#0'
      break
   elif (( ${k} == 0 ))
      then
      subroutine              @1.3
   else
      subroutine              @1.4a Filter: ${seed_sptf[cxt]}
      subroutine              @1.4b Smoothing kernel: ${k} mm
      #############################################################
      # Obtain the mask over which smoothing is to be applied.
      # Begin by searching for the subject mask; if this does
      # not exist, then search for a mask created by this
      # module.
      #############################################################
      if is_image ${mask[sub]}
         then
         subroutine           @1.5
         mask=${mask[sub]}
      else
         subroutine           @1.6b Generating a mask using 3dAutomask
         exec_afni 3dAutomask -prefix ${intermediate}_fmask.nii.gz \
            -dilate 3 \
            -q \
            ${img}
         mask=${intermediate}_fmask.nii.gz
      fi
      #############################################################
      # Prime the inputs to sfilter for SUSAN filtering
      #############################################################
      if [[ ${seed_sptf[cxt]} == susan ]] \
      && [[ -z ${usan} ]]
         then
         if is_image ${seed_usan[cxt]}
            then
            subroutine        @1.7  Warping USAN
            warpspace \
               ${seed_usan[cxt]} \
               ${intermediate}usan.nii.gz \
               ${seed_usan_space[cxt]}:${space[sub]} \
               NearestNeighbor
            usan="-u ${intermediate}usan.nii.gz"
            hardseg=-h
         ##########################################################
         # Ensure that an example functional image exists.
         #  * If it does not, then you are probably doing
         #    something stupid.
         #  * In this case, force a switch to uniform
         #    smoothing to mitigate the catastrophe.
         ##########################################################
         elif is_image ${referenceVolumeBrain[sub]}
            then
            subroutine        @1.8
            usan="-u ${referenceVolumeBrain[sub]}"
         else
            subroutine        @1.9a No appropriate USAN: reconfiguring pipeline
            subroutine        @1.9b to smooth to uniformity instead
            configure         seed_sptf      uniform
            write_config      seed_sptf
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
         -i    ${img} \
         -o    ${!sm_mod} \
         -s    ${seed_sptf[cxt]} \
         -k    ${seed_smo[cxt]} \
         -m    ${mask} \
         ${usan} ${hardseg}
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
# Retrieve all the seeds for which SCA should be run from the
# analysis's seed library.
###################################################################
libspace=$(grep -i '^SPACE::' ${seed_lib[cxt]})
libspace=${libspace//SPACE\:\:/}
###################################################################
# Iterate through all seeds.
#
# In brief, the seed-based correlation process consists of the
# following steps:
#  1. Generate a map of the current seed in whatever space the
#     subject image is currently situated.
#  2. Extract the (weighted) mean timeseries from voxels in the
#     current seed region.
#  3. Compute the voxelwise correlation of the primary BOLD
#     timeseries with the seed's mean timeseries.
###################################################################
for seed in ${seeds[cxt]}
   do
   ################################################################
   # Parse the current seed's information.
   #  * seed[1] variable is overloaded; it stores either voxel
   #    coordinates or a path to the seed mask.
   #  * seed[2] stores either the seed radius in mm or the space
   #    in which the seed mask is situated.
   ################################################################
   seed=( ${seed//\#/ } )
   seed[0]=$(eval echo ${seed[0]})
   seed[1]=$(eval echo ${seed[1]})
   seed[2]=$(eval echo ${seed[2]})
   sca_seed=${seed[0]}_seed'['${cxt}']'
   sca_map=${seed[0]}'['${cxt}']'
   sca_ts=${seed[0]}_ts'['${cxt}']'
   routine                    @2    ${seed[0]}
   ################################################################
   # Determine whether the current seed is a coordinate entry in a
   # seed library or a 3D mask image.
   ################################################################
   if contains ${seed[1]} ','
      then
      subroutine              @2.2.1
      seedType=coor
   else
      subroutine              @2.2.2
      seedType=mask
   fi
   ################################################################
   # [1]
   # Based on the seed type and the space of the primary BOLD
   # timeseries, decide what is necessary to move the seed into
   # the BOLD timeseries space.
   ################################################################
   case ${seedType} in
   coor)
      subroutine              @2.3.1   Transforming coordinates to image
      #############################################################
      # seed[1] stores the coordinates of the seed.
      # seed[2] stores the radius of the seed.
      #
      # If the primary BOLD timeseries is in native space, use
      # ANTs to transform seed coordinates into native space.
      # This process is much less intuitive than it sounds,
      # largely because of the stringent orientation requirements
      # within ANTs, and it is wrapped in the warpspace function.
      #############################################################
      warpspace \
         ${seed[1]} \
         ${intermediate}_coor_${seed[0]}.sclib \
         ${libspace}:${space[sub]} \
         ${seed_voxel[cxt]}
      #############################################################
      # Obtain the warped coordinates.
      #############################################################
      subroutine              @2.3.2
      coor=$(tail -n+2 ${intermediate}_coor_${seed[0]}.sclib)
      coor=( ${coor//\#/ } )
      seed[1]=${coor[1]}
      #############################################################
      # Use the warped coordinates and radius to generate a map
      # of the seed region.
      #############################################################
      subroutine              @2.3.3
      rm -f ${intermediate}_coor_${seed[0]}.sclib
      echo \
"SPACE::${space[sub]}
:#ROIName#X,Y,Z#radius
#""${seed[0]}#${seed[1]}#${seed[2]}" \
         >> ${intermediate}_coor_${seed[0]}.sclib
      exec_xcp coor2map \
         -i ${intermediate}_coor_${seed[0]}.sclib \
         -t ${referenceVolumeBrain[sub]} \
         -o ${!sca_seed}
      ;;
   mask)
      subroutine              @2.4  Warping seed into target space
      #############################################################
      # seed[1] stores the path to the seed mask.
      # seed[2] stores the space of the seed mask.
      #############################################################
      warpspace \
         ${seed[1]} \
         ${!sca_seed} \
         ${seed[2]}:${space[sub]} \
         NearestNeighbor
      ;;
   esac
   ################################################################
   # [2]
   # Now that the seed map has been created in BOLD space, the
   # next stage is extracting a (weighted) mean timeseries from
   # the seed map.
   ################################################################
   if [[ ! -s ${!sca_ts} ]] \
   || rerun
      then
      subroutine              @3    Extracting mean timeseries
      exec_sys rm -f ${!sca_ts}
      exec_xcp tswmean.R \
         -i    ${img} \
         -r    ${!sca_seed} \
         >>    ${!sca_ts}
   fi
   ################################################################
   # [3]
   # Using the mean timeseries, it is now possible to perform
   # voxelwise SCA.
   ################################################################
   for k in ${kernels}
      do
      i=$(strslice ${k} 1 '#')
      k=$(strslice ${k} 2 '#')
      sca_map=${seed[0]}'_sm'${k}'['${cxt}']'
      sca_zmap=${seed[0]}'Z_sm'${k}'['${cxt}']'
      if ! is_image ${!sca_zmap}
         then
         subroutine           @4    SCA at smoothness ${k} mm
         exec_sys             rm -f    ${!sca_map}
         exec_afni            3dfim+ \
            -input            ${i} \
            -ideal_file       ${!sca_ts} \
            -out              Correlation \
            -bucket           ${!sca_map}
         ##########################################################
         # Fisher transform: not certain why the signs are
         # reversed, but it has worked this way
         ##########################################################
         exec_sys             rm -f ${!sca_zmap}
         exec_afni            3dcalc \
            -a                ${!sca_map} \
            -expr             'log((a+1)/(a-1))/2' \
            -prefix           ${!sca_zmap}
      fi
   done
   routine_end
done





completion
