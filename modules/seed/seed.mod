 #!/usr/bin/env bash

###################################################################
#  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  #
###################################################################

##################################################################
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
#no_seeds() {
 #  echo \
#"
#[WARNING: Seed-based correlation analysis has been requested,]
#[but no valid seed libraries have been provided.]
  
#[Skipping module]"
  # exit 1
#}




###################################################################
# OUTPUTS
###################################################################
#[[ ! -s ${seed_lib[cxt]} ]] &&   seed_lib[cxt]=${BRAINATLAS}/coor/${seed_lib[cxt]}.sclib
#[[ ! -s ${seed_lib[cxt]} ]] &&   no_seeds

#define   seeds                   $(grep -i '^#' ${seed_lib[cxt]} 2>/dev/null)
define   kernel                  ${seed_smo[cxt]//,/ }





rem1=${seed_names[cxt]}

while (( ${#rem1} > 0 ))
   do
   ################################################################
   # * Extract the three-letter routine code -
   # for seed identification 
   ################################################################
   cur=${rem1:0:3}
   rem1=${rem1:4:${#rem1}}
   echo $cur
   
   define            mapdir               ${outdir}/${cur}/
   exec_sys          mkdir -p             ${mapdir[cxt]}
   define            mapbase              ${mapdir[cxt]}/${prefix}_connectivity
   define            ${cur}_ts            ${mapbase[cxt]}_${cur}_ts.1D
   output            ${cur}_seed          ${mapbase[cxt]}_${cur}_seed.nii.gz
   derivative        ${cur}               ${mapbase[cxt]}_${cur}
   derivative        ${cur}Z              ${mapbase[cxt]}_${cur}Z
   exec_sys          mkdir -p             ${mapdir[cxt]}
        
done

rem1=${seed_names[cxt]}

for k in ${kernel[cxt]}
   do
   while (( ${#rem1} > 0 ))
      do
  cur=${rem1:0:3}
  rem1=${rem1:4:${#rem1}}
    
      define         mapbase              ${outdir}/${cur}/${prefix}_connectivity
      derivative     ${cur}_sm${k}    ${mapbase[cxt]}_${cur}_sm${k}
      derivative     ${cur}Z_sm${k}   ${mapbase[cxt]}_${cur}Z_sm${k}
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
if [[ ${#seed_points[cxt]} > 0 ]] \
|| [[ -s ${seed_mask[cxt]} ]]
   then
   subroutine                 @0.1
   add_reference     referenceVolume[$sub]   ${prefix}_referenceVolume
else
echo " no seed points or seed mask"
exit 1

fi

if [[ ! ${seed_radius[cxt]}  ]] 
   then
   {seed_radius[cxt]}=5
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
#libspace=$(grep -i '^SPACE::' ${seed_lib[cxt]})
#libspace=${libspace//SPACE\:\:/}
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

rem1=${seed_names[cxt]}
rem2=(${seed_points[cxt]//#/ }) 
ii=0
echo $rem1 $rem2 
while (( ${#rem1} > 0 ))
   do
   cur=${rem1:0:3}
   rem1=${rem1:4:${#rem1}}
   
   ################################################################
  
   sca_seed=${cur}_seed'['${cxt}']'
   sca_map=${cur}'['${cxt}']'
   sca_ts=${cur}_ts'['${cxt}']'
   routine                    @2    ${cur}
   ################################################################
   # Determine whether the current seed is a coordinate entry in a
   # seed library or a 3D mask image.
   ################################################################
   
   
 
  if  [[ ${#seed_points[cxt]} > 0 ]]
      then
      subroutine              @2.2.1
      seedType=coor
      seedpoint=${rem2[ii]}
      ii=$((ii+1))
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
      #
      # If the primary BOLD timeseries is in native space, use
      # ANTs to transform seed coordinates into native space.
      # This process is much less intuitive than it sounds,
      # largely because of the stringent orientation requirements
      # within ANTs, and it is wrapped in the warpspace function.
      ##############################################################  
   subroutine              @2.3.2
       exec_xcp coor2nifti \
           -i ${seedpoint} -t ${template} \
           -r ${seed_radius[cxt]} -o ${intermediate}_coor_${cur}.nii.gz
      
  subroutine              @2.3.3
     warpspace                    \
         ${intermediate}_coor_${cur}.nii.gz \
         ${intermediate}_coor1_${cur}.nii.gz  \
         ${standard}:${space[sub]}  \
         NearestNeighbor

    subroutine              @2.3.4
     exec_ants  antsApplyTransforms \
     -i ${intermediate}_coor1_${cur}.nii.gz  \
     -r ${referenceVolumeBrain[sub]} -n Linear \
     -o ${!sca_seed}
      ;;

   mask)
      subroutine              @2.4.1
      import_image            ${seed_mask[cxt]} ${intermediate}-${cur}.nii.gz
      subroutine              @2.4.2 Warping seed into target space
      #############################################################
      
      #############################################################
      warpspace                     \
         $${seed_mask[cxt]}                 \
         ${intermediate}_coor1_${cur}.nii.gz               \
         ${standard}:${space}   \
         NearestNeighbor

    exec_ants  antsApplyTransforms \
     -i ${intermediate}_coor1_${cur}.nii.gz  \
     -r ${referenceVolumeBrain[sub]} -n Linear \
     -o ${!sca_seed}
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
      sca_map=${cur}'_sm'${k}'['${cxt}']'
      sca_zmap=${cur}'Z_sm'${k}'['${cxt}']'
      if ! is_image ${!sca_zmap}
         then
         subroutine           @4    SCA at smoothness ${k} mm
         exec_sys             rm -f    ${sca_map}
         exec_afni            3dTcorr1D   \
            -prefix           ${!sca_map} \
            -mask             ${mask[sub]}\
                              ${i}        \
                              ${!sca_ts}
         ##########################################################
         # Fisher transform
         ##########################################################
         exec_sys             rm -f ${!sca_zmap}
         exec_afni            3dcalc               \
            -a                ${!sca_map}          \
            -expr             'log((1+a)/(1-a))/2' \
            -prefix           ${!sca_zmap}
      fi
   done
   routine_end
done





completion
