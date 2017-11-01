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
source ${XCPEDIR}/core/functions/library_func.sh

###################################################################
# GENERAL MODULE HEADER
###################################################################
source ${XCPEDIR}/core/constants
source ${XCPEDIR}/core/functions/library.sh
source ${XCPEDIR}/core/parseArgsMod

###################################################################
# MODULE COMPLETION AND ANCILLARY FUNCTIONS
###################################################################
completion() {
   source ${XCPEDIR}/core/auditComplete
   source ${XCPEDIR}/core/updateQuality
   source ${XCPEDIR}/core/moduleEnd
}
no_seeds() {
   echo \
"
[WARNING: Seed-based correlation analysis has been requested,]
[but no seed libraries have been provided.]
  
[Skipping module]"
   exit 1
}





###################################################################
# OUTPUTS
###################################################################
[[ ! -s ${seed_lib[cxt]} ]] &&   no_seeds
define   seeds                   $(grep -i '^#' ${seed_lib[cxt]} 2>/dev/null)
define   kernel                  ${seed_smo[cxt]//,/ }

for seed in ${seeds[cxt]}
   do
   seed=(            ${seed//\#/ } )
   seed[0]=$(        eval echo            ${seed[0]})
   define            mapdir               ${outdir}/${seed[0]}/
   define            mapbase              ${mapdir[cxt]}/${prefix}_connectivity
   define            ${seed[0]}_ts        ${mapbase[cxt]}_${seed[0]}_ts.1D
   output            ${seed[0]}_seed      ${mapbase[cxt]}_${seed[0]}_seed
   derivative        ${seed[0]}           ${mapbase[cxt]}_${seed[0]}
   derivative        ${seed[0]}Z          ${mapbase[cxt]}_${seed[0]}Z
   exec_sys          mkdir -p             ${mapdir[cxt]}
done
for k in ${kernel[cxt]}
   do
   for seed in ${seeds[cxt]}
      do
      seed=(         ${seed//\#/ } )
      seed[0]=$(     eval echo            ${seed[0]})
      define         mapbase              ${outdir}/${seed[0]}/${prefix}_connectivity
      derivative     ${seed[0]}_sm${k}    ${mapbase[cxt]}_${seed[0]}_sm${k}
      derivative     ${seed[0]}Z_sm${k}   ${mapbase[cxt]}_${seed[0]}Z_sm${k}
   done
   derivative        img_sm${k}           ${prefix}_sm${k}
   derivative_set    img_sm${k}           Type     TimeSeries
done

<< DICTIONARY

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
   no_seeds
fi





###################################################################
# Apply the desired smoothing kernel to the BOLD timeseries.
###################################################################
routine                       @1    Spatially filtering image
smooth_spatial                --SIGNPOST=${signpost}              \
                              --FILTER=seed_sptf[$cxt]            \
                              --INPUT=${img}                      \
                              --USAN=${seed_usan[cxt]}            \
                              --USPACE=${seed_usan_space[cxt]}
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
      warpspace                     \
         ${seed[1]}                 \
         ${intermediate}_coor_${seed[0]}.sclib \
         ${libspace}:${space[sub]}  \
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
      echo                                         \
"SPACE::${space[sub]}
:#ROIName#X,Y,Z#radius
#""${seed[0]}#${seed[1]}#${seed[2]}"               \
         >> ${intermediate}_coor_${seed[0]}.sclib
      exec_xcp coor2map                            \
         -i ${intermediate}_coor_${seed[0]}.sclib  \
         -t ${referenceVolumeBrain[sub]}           \
         -o ${!sca_seed}
      ;;
   mask)
      subroutine              @2.4.1
      import_image            seed[1] ${intermediate}-${seed[0]}.nii.gz
      subroutine              @2.4.2 Warping seed into target space
      #############################################################
      # seed[1] stores the path to the seed mask.
      # seed[2] stores the space of the seed mask.
      #############################################################
      warpspace                     \
         ${seed[1]}                 \
         ${!sca_seed}               \
         ${seed[2]}:${space[sub]}   \
         NearestNeighbor
      ;;
   esac
   ################################################################
   # [2]
   # Now that the seed map has been created in BOLD space, the
   # next stage is extracting a (weighted) mean timeseries from
   # the seed map.
   ################################################################
   if [[ ! -s ${!sca_ts} ]]   \
   || rerun
      then
      subroutine              @3    Extracting mean timeseries
      exec_sys rm -f ${!sca_ts}
      exec_xcp tswmean.R      \
         -i    ${img}         \
         -r    ${!sca_seed}   \
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
         exec_afni            3dfim+      \
            -input            ${i}        \
            -ideal_file       ${!sca_ts}  \
            -out              Correlation \
            -bucket           ${!sca_map}
         ##########################################################
         # Fisher transform: not certain why the signs are
         # reversed, but it has worked this way
         ##########################################################
         exec_sys             rm -f ${!sca_zmap}
         exec_afni            3dcalc               \
            -a                ${!sca_map}          \
            -expr             'log((a+1)/(a-1))/2' \
            -prefix           ${!sca_zmap}
      fi
   done
   routine_end
done





completion
