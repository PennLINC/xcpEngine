#!/usr/bin/env bash

###################################################################
#  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  #
###################################################################

###################################################################
# SPECIFIC MODULE HEADER
# This module computes regional homogeneity maps using Kendall's
# coefficient of concordance over voxel neighbourhoods.
###################################################################
mod_name_short=reho
mod_name='REGIONAL HOMOGENEITY MODULE'
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
   write_derivative  reho
   write_derivative  rehoZ
   
   for k in ${kernel[cxt]}
      do
      write_derivative  reho_sm${k}
      write_derivative  rehoZ_sm${k}
   done
   
   source ${XCPEDIR}/core/auditComplete
   source ${XCPEDIR}/core/updateQuality
   source ${XCPEDIR}/core/moduleEnd
}





###################################################################
# OUTPUTS
###################################################################
derivative  reho                    ${prefix}_reho
derivative  rehoZ                   ${prefix}_rehoZ

configure   kernel                  ${reho_smo[cxt]//,/ }

for k in ${kernel[cxt]}
   do
   derivative     reho_sm${k}       ${prefix}_reho_sm${k}
   derivative     rehoZ_sm${k}      ${prefix}_rehoZ_sm${k}
done

add_reference     referenceVolume[$sub]   ${prefix}_referenceVolume

derivative_config reho              Statistic         mean
derivative_config rehoZ             Statistic         mean

<< DICTIONARY

kernel
   An array of all smoothing kernels to be applied to the voxelwise
   map, measured in mm.
reho
   An unsmoothed voxelwise map of regional homogeneity.
reho_sm
   Smoothed voxelwise maps of regional homogeneity.

DICTIONARY










###################################################################
# Determine whether the voxelwise ReHo map needs to be computed
###################################################################
if ! is_image ${reho[cxt]} \
|| rerun
   then
   routine                    @1    Computing voxelwise ReHo
   ################################################################
   # Translate from neighbourhood type to number of neighbours
   ################################################################
   subroutine                 @1.1  Determining voxel neighbourhood
   case ${reho_nhood[cxt]} in
   faces)
      subroutine              @1.2a Faces
      nneigh='-nneigh 7'
      ;;
   edges)
      subroutine              @1.2b Edges
      nneigh='-nneigh 19'
      ;;
   vertices)
      subroutine              @1.2c Vertices
      nneigh='-nneigh 27'
      ;;
   esac
   if contains ${reho_nhood[cxt]} sphere
      then
      mmrad=$(strslice  ${reho_nhood[cxt]} 2)
      subroutine              @1.2d Sphere of radius ${mmrad}
      xdim=$(exec_fsl   fslval      ${img} pixdim1)
      ydim=$(exec_fsl   fslval      ${img} pixdim2)
      zdim=$(exec_fsl   fslval      ${img} pixdim3)
      xdim=$(arithmetic ${mmrad} /  ${xdim})
      ydim=$(arithmetic ${mmrad} /  ${ydim})
      zdim=$(arithmetic ${mmrad} /  ${zdim})
      nneigh="-neigh_X ${xdim} -neigh_Y ${ydim} -neigh_Z ${zdim}"
   fi
   subroutine                 @1.3 "Computing regional homogeneity (ReHo)"
   exec_afni 3dReHo \
      -prefix ${reho[cxt]} \
      -inset ${img} \
      ${nneigh}
   ################################################################
   # Convert the raw ReHo output values to standard scores.
   ################################################################
   subroutine              @1.4  Standardising ReHo values
   zscore_image            ${reho[cxt]}   ${rehoZ[cxt]}  ${mask[sub]}
   routine_end
   
   
   
   
   
   ################################################################
   # Apply the desired smoothing kernel to the voxelwise ReHo map.
   #
   # If no spatial filtering has been specified by the user, then
   # bypass this step.
   ################################################################
   if [[ ${reho_sptf[cxt]} != none ]] \
   && (( ${reho_smo[cxt]}  != 0 ))
      then
      routine                 @2    Spatially filtering ReHo map
      for k in ${kernel[cxt]}
         do
         subroutine           @2.1a Filter: ${reho_sptf[cxt]}
         subroutine           @2.2b Smoothing kernel: ${k} mm
         output_var='reho_sm'${k}'['${cxt}']'
         output_zvar='rehoZ_sm'${k}'['${cxt}']'
         ##########################################################
         # Obtain the mask over which smoothing is to be applied
         # Begin by searching for the subject mask; if this does
         # not exist, then search for a mask created by this
         # module.
         ##########################################################
         if is_image ${mask[sub]}
            then
            subroutine        @2.2
            mask=${mask[sub]}
         else
            subroutine        @2.3  Generating a mask using 3dAutomask
            exec_afni 3dAutomask -prefix ${intermediate}_fmask.nii.gz \
               -dilate 3 \
               -q \
               ${img}
            mask=${intermediate}_fmask.nii.gz
         fi
         ##########################################################
         # Prime the inputs to sfilter for SUSAN filtering:  Ensure
         # that an example functional image exists. If it does not,
         # force a switch to uniform smoothing to mitigate the
         # catastrophe.
         ##########################################################
         if [[ ${reho_sptf[cxt]} == susan ]] \
         && [[ -z ${usan} ]]
            then
            subroutine        @2.4
            if is_image ${reho_usan[cxt]}
               then
               subroutine     @2.4.1  Warping USAN
               warpspace \
                  ${reho_usan[cxt]} \
                  ${intermediate}usan.nii.gz \
                  ${reho_usan_space[cxt]}:${space[sub]} \
                  NearestNeighbor
               usan="-u ${intermediate}usan.nii.gz"
               hardseg=-h
            fi
            if is_image ${referenceVolumeBrain[sub]}
               then
               subroutine     @2.4.2
               usan="-u ${referenceVolume[sub]}"
            else
               subroutine     @2.4.3
               configure      reho_sptf      uniform
               write_config   reho_sptf
            fi
         fi
         ##########################################################
         # Engage the sfilter routine to filter the ReHo map.
         #  * This is essentially a wrapper around the three
         #    implemented smoothing routines: gaussian, susan,
         #    and uniform.
         ##########################################################
         exec_xcp sfilter \
            -i    ${reho[cxt]} \
            -o    ${!output_var} \
            -s    ${reho_sptf[cxt]} \
            -k    ${k} \
            -m    ${mask} \
            ${usan} ${hardseg}
         ##########################################################
         # Convert the raw ReHo output values to standard scores.
         ##########################################################
         subroutine           @2.5  Standardising ReHo values
         zscore_image         ${!output_var} ${!output_zvar}   ${mask[sub]}
      done
      routine_end
   fi
fi





subroutine                    @0.1
completion
