#!/usr/bin/env bash

###################################################################
#  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  #
###################################################################

###################################################################
# Constants
###################################################################
readonly SIGMA=2.35482004503




###################################################################
###################################################################
# BEGIN GENERAL MODULE HEADER
###################################################################
###################################################################
# Read in:
#  * path to localised design file
#  * overall context in pipeline
#  * whether to explicitly trace all commands
# Trace status is, by default, set to 0 (no trace)
###################################################################
trace=0
while getopts "d:c:t:" OPTION
   do
   case $OPTION in
   d)
      design_local=${OPTARG}
      ;;
   c)
      cxt=${OPTARG}
      ! [[ ${cxt} =~ $POSINT ]] && ${XCPEDIR}/xcpModusage mod && exit
      ;;
   t)
      trace=${OPTARG}
      if [[ ${trace} != "0" ]] && [[ ${trace} != "1" ]]
         then
         ${XCPEDIR}/xcpModusage mod
         exit
      fi
      ;;
   *)
      echo "Option not recognised: ${OPTARG}"
      ${XCPEDIR}/xcpModusage mod
      exit
   esac
done
shift $((OPTIND-1))
###################################################################
# Ensure that the compulsory design_local variable has been defined
###################################################################
[[ -z ${design_local} ]] && ${XCPEDIR}/xcpModusage mod && exit
[[ ! -e ${design_local} ]] && ${XCPEDIR}/xcpModusage mod && exit
###################################################################
# Set trace status, if applicable
# If trace is set to 1, then all commands called by the pipeline
# will be echoed back in the log file.
###################################################################
[[ ${trace} == "1" ]] && set -x
###################################################################
# Initialise the module.
###################################################################
echo ""; echo ""; echo ""
echo "################################################################### "
echo "#  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  #"
echo "#                                                                 #"
echo "#  ☭     EXECUTING SEED-BASED CORRELATION ANALYSIS MODULE      ☭  #"
echo "#                                                                 #"
echo "#  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  #"
echo "###################################################################"
echo ""
###################################################################
# Source the design file.
###################################################################
source ${design_local}
###################################################################
# Verify that all compulsory inputs are present.
###################################################################
if [[ $(imtest ${out}/${prefix}) != 1 ]]
   then
   echo "::XCP-ERROR: The primary input is absent."
   exit 666
fi
if [[ ! -e ${sca_lib[${cxt}]} ]]
   then
   echo "::XCP-WARNING: Seed-based correlation analysis has been "
   echo "  requested, but no seeds have been provided."
   exit 1
fi
###################################################################
# Create a directory for intermediate outputs.
###################################################################
[[ ${NUMOUT} == 1 ]] && prep=${cxt}_
outdir=${out}/${prep}seed
[[ ! -e ${outdir} ]] && mkdir -p ${outdir}
echo "Output directory is $outdir"
###################################################################
# Define paths to all potential outputs.

# For the seed-based module, there may exist an unlimited number
# of potential outputs, depending on the number of seed-based
# correlation analyses requested by the user:
#  * scabase : Base name for derivative maps obtained from seed-
#    based correlation analysis; seed names will be appended to
#    base names
###################################################################
scabase=${outdir}/${prefix}_
###################################################################
# * Initialise a pointer to the image.
# * Ensure that the pointer references an image, and not something
#   else such as a design file.
# * On the basis of this, define the image extension to be used for
#   this module (for operations, such as AFNI, that require an
#   extension).
# * Localise the image using a symlink, if applicable.
# * Define the base output path for intermediate files.
###################################################################
img=${out}/${prefix}
imgpath=$(ls ${img}.*)
for i in ${imgpath}
   do
   [[ $(imtest ${i}) == 1 ]] && imgpath=${i} && break
done
ext=$(echo ${imgpath}|sed s@${img}@@g)
[[ ${ext} == ".nii.gz" ]] && export FSLOUTPUTTYPE=NIFTI_GZ
[[ ${ext} == ".nii" ]] && export FSLOUTPUTTYPE=NIFTI
[[ ${ext} == ".hdr" ]] && export FSLOUTPUTTYPE=NIFTI_PAIR
[[ ${ext} == ".img" ]] && export FSLOUTPUTTYPE=NIFTI_PAIR
[[ ${ext} == ".hdr.gz" ]] && export FSLOUTPUTTYPE=NIFTI_PAIR_GZ
[[ ${ext} == ".img.gz" ]] && export FSLOUTPUTTYPE=NIFTI_PAIR_GZ
outbase=${outdir}/${prefix}~TEMP~
[[ -e ${outdir}/${prefix}_referenceVolume${ext} ]] \
   && rm -f ${outdir}/${prefix}_referenceVolume${ext}
ln -s ${referenceVolume[${subjidx}]}${ext} ${outdir}/${prefix}_referenceVolume${ext}
###################################################################
# Prime the localised design file so that any outputs from this
# module appear beneath the correct header.
###################################################################
echo "" >> $design_local
echo "# *** outputs from seed[${cxt}] *** #" >> $design_local
echo "" >> $design_local
###################################################################
# It is always assumed that this module should re-run.
#
# Each SCA map is checked separately to determine whether each
# SCA should be run.
###################################################################
###################################################################
# END GENERAL MODULE HEADER
###################################################################
###################################################################





###################################################################
# Apply the desired smoothing kernel to the BOLD timeseries.
###################################################################
img_sm_name=sm${sca_smo[${cxt}]}
img_sm=img_sm${sca_smo[${cxt}]}[${subjidx}]
if [[ $(imtest ${!img_sm}) == 1 ]]
   then
   img_sm=${!img_sm}
###################################################################
# Determine whether an image with the specified smoothing kernel
# already exists
###################################################################
elif [[ $(imtest ${scabase}sm${sca_smo[${cxt}]}) == 1 ]]
   then
   img_sm=${scabase}sm${sca_smo[${cxt}]}
   echo "img_sm${sca_smo[${cxt}]}[${subjidx}]=${img_sm}" >> ${design_local}
   echo "#${img_sm_name}#${img}" >> ${auxImgs[${subjidx}]}
###################################################################
# If no spatial filtering has been specified by the user, then
# bypass this step.
###################################################################
elif [[ ${sca_sptf[${cxt}]} == none ]] \
   || [[ ${sca_smo[${cxt}]} == 0 ]]
   then
   img_sm=${img}
else
   echo ""; echo ""; echo ""
   echo "Current processing step:"
   echo "Spatially filtering image"
   echo "Filter: ${sca_sptf[${cxt}]}"
   echo "Smoothing kernel: ${sca_smo[${cxt}]} mm"
   ################################################################
	# Ensure that this step has not already run to completion
	# by checking for the existence of a smoothed image.
   ################################################################
   if [[ $(imtest ${scabase}sm${sca_smo[${cxt}]}) != "1" ]] \
      || [[ "${sca_rerun[${cxt}]}" == "Y" ]]
      then
      #############################################################
	   # Obtain the mask over which smoothing is to be applied
	   # Begin by searching for the subject mask; if this does
	   # not exist, then search for a mask created by this
	   # module.
      #############################################################
      if [[ $(imtest ${mask[${subjidx}]}) == "1" ]]
         then
         mask=${mask[${subjidx}]}
      else
         echo "Unable to locate mask."
         echo "Generating a mask using 3dAutomask"
         3dAutomask -prefix ${img}_fmask${ext} \
            -dilate 3 \
            -q \
            ${img}${ext}
         susanmask=${img}_fmask${ext}
      fi
      #############################################################
	   # Prime the inputs to sfilter for SUSAN filtering
      #############################################################
      if [[ "${sca_sptf[${cxt}]}" == susan ]]
         then
         ##########################################################
	      # Ensure that an example functional image exists.
	      #  * If it does not, then you are probably doing
	      #    something stupid.
	      #  * In this case, force a switch to uniform
	      #    smoothing to mitigate the catastrophe.
         ##########################################################
	      if [[ $(imtest ${referenceVolumeBrain[${subjidx}]}) == 1 ]]
            then
            usan="-u ${referenceVolumeBrain[${subjidx}]}"
         else
            ${sca_sptf[${cxt}]}=uniform
            echo "sca_sptf[${cxt}]=${sca_sptf[${cxt}]}" \
               >> ${design_local}
         fi
      fi
      #############################################################
	   # If the user has requested command tracing, propagate
	   # that request into the sfilter routine.
      #############################################################
	   [[ ${trace} == 1 ]] && trace_prop="-t"
      #############################################################
	   # Engage the sfilter routine to filter the image.
	   #  * This is essentially a wrapper around the three
	   #    implemented smoothing routines: gaussian, susan,
	   #    and uniform.
      #############################################################
	   ${XCPEDIR}/utils/sfilter \
	      -i ${img} \
	      -o ${outbase}sm${sca_smo[${cxt}]} \
	      -s ${sca_sptf[${cxt}]} \
	      -k ${sca_smo[${cxt}]} \
	      -m ${mask} \
	      ${usan} \
	      ${trace_prop}
	   immv ${outbase}sm${sca_smo[${cxt}]} ${scabase}sm${sca_smo[${cxt}]}
	fi
   ################################################################
   # Update image pointer, and write the smoothed image path to
   # the design file and derivatives index so that it may be used
   # by additional modules.
   ################################################################
   img_sm=${scabase}sm${sca_smo[${cxt}]}
   echo "img_sm${sca_smo[${cxt}]}[${subjidx}]=${img_sm}" >> ${design_local}
   echo "#${img_sm_name}#${img_sm}" >> ${auxImgs[${subjidx}]}
   echo "Processing step complete: spatial filtering"
fi





###################################################################
# Pool any transforms necessary for moving between standard and
# native space. Determine which transforms need to be applied for
# such a move.
###################################################################
coreg="-t ${seq2struct[${subjidx}]}"
icoreg="-t ${struct2seq[${subjidx}]}"
if [[ ! -z ${xfm_warp} ]] \
   && [[ $(imtest "${xfm_warp}") == 1 ]]
   then
	warp="-t ${xfm_warp}"
	iwarp="-t ${ixfm_warp}"
fi
if [[ ! -z ${xfm_affine} ]]
	then
	affine="-t ${xfm_affine}"
	iaffine="-t [${xfm_affine},1]"
fi
if [[ ! -z ${xfm_rigid} ]]
	then
	rigid="-t ${xfm_rigid}"
	irigid="-t [${xfm_rigid},1]"
fi
if [[ ! -z ${xfm_resample} ]]
	then
	resample="-t ${xfm_resample}"
	iresample="-t [${xfm_resample},1]"
fi





###################################################################
# Retrieve all the seeds for which SCA should be run from the
# analysis's seed library.
###################################################################
seeds=$(grep -i '^#' ${sca_lib[${cxt}]})
libspace=$(grep -i '^SPACE::' ${sca_lib[${cxt}]}|cut -d":" -f3)
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
echo ""; echo ""; echo ""
echo "Current processing step:"
echo "Seed-based correlation analysis"
for seed in $seeds
   do
   ################################################################
   # Parse the current seed's information.
   #  * The sdCoor variable is overloaded; it stores either voxel
   #    coordinates or a path to the seed mask.
   #  * The sdRad variable stores either the seed radius in mm
   #    or the space in which the seed mask is situated.
   ################################################################
   sdName=$(echo $seed|cut -d"#" -f2)
   sdCoor=$(echo $seed|cut -d"#" -f3)
   sdRad=$(echo $seed|cut -d"#" -f4)
   sdName=$(eval echo ${sdName})
   printf " * ${sdName}::"
   ################################################################
   # First, determine whether the SCA has already been completed
   # for the current seed.
   #  * If SCA has already run, then add the SCA map to the list
   #    of derivative images and skip the analysis.
   #  * Unless, of course, the user has explicitly requested
   #    full re-analysis.
   ################################################################
   if [[ $(imtest ${scabase}${sdName}_zr_sca) == 1 ]] \
      && [[ ${sca_rerun[${cxt}]} == "N" ]]
      then
      echo "[already run]"
      echo "#sca_zr_${sdName}#${scabase}${sdName}_zr_sca" \
         >> ${auxImgs[${subjidx}]}
      echo "#sca_r_${sdName}#${scabase}${sdName}_r_sca" \
         >> ${auxImgs[${subjidx}]}
      continue
   fi
   ################################################################
   # Now that it has been determined that SCA needs to be run on
   # the current seed, determine whether the current seed is a
   # coordinate entry in a seed library or a 3D mask image.
   ################################################################
   numDelim=$(grep -o "," <<< "${sdCoor}" | wc -l)
   [[ ${numDelim} == 2 ]] && seedType=coor || seedType=mask
   ################################################################
   # [1]
   # Based on the seed type and the space of the primary BOLD
   # timeseries, decide what is necessary to move the seed into
   # the BOLD timeseries space.
   ################################################################
   printf "map::"
   case ${seedType} in
   coor)
      xcoor=$(echo ${sdCoor}|cut -d"," -f1)
      ycoor=$(echo ${sdCoor}|cut -d"," -f2)
      zcoor=$(echo ${sdCoor}|cut -d"," -f3)
      case std2${space} in
      ############################################################
      # If the primary BOLD timeseries is in native space, use
      # ANTs to transform seed coordinates into native space.
      # This process is much less intuitive than it sounds,
      # largely because of the stringent orientation requirements
      # within ANTs, and it is cleverly tucked away behind a
      # utility script called pointTransform.
      #
      # Also, note that antsApplyTransformsToPoints (and
      # consequently pointTransform) requires the inverse of the
      # transforms that you would intuitively expect it to
      # require.
      ############################################################
      std2native)
         ##########################################################
         # pointTransform expects input in image space rather than
         # voxel space as of now. Convert the input.
         ##########################################################
         if [[ ${libspace} == VOXEL ]]
            then
            sdCoor=$(echo ${sdCoor}|sed s@','@' '@g\
               |img2stdcoord -img ${template} -std ${template})
            sdCoor=$(echo ${sdCoor}|sed s@' '@','@g)
            xcoor=$(echo ${sdCoor}|cut -d"," -f1)
            ycoor=$(echo ${sdCoor}|cut -d"," -f2)
            zcoor=$(echo ${sdCoor}|cut -d"," -f3)
         fi
         ##########################################################
         # Apply the required transforms.
         ##########################################################
         rm -f ${outbase}coords_warped.sclib
         [[ ${trace} == 1 ]] && trace_prop=-x
         ${XCPEDIR}/utils/pointTransform \
            -v \
            -i ${xcoor},${ycoor},${zcoor} \
            -s ${template} \
            -r ${referenceVolume[${subjidx}]}${ext} \
            $coreg \
            $rigid \
            $affine \
            $warp \
            $resample \
            $trace_prop \
            >> ${outbase}coords_warped.sclib
         ##########################################################
         # Obtain the warped coordinates.
         ##########################################################
         sdCoor=$(cat ${outbase}coords_warped.sclib|tail -n+2)
         xcoor=$(echo ${sdCoor}|cut -d"," -f1)
         ycoor=$(echo ${sdCoor}|cut -d"," -f2)
         zcoor=$(echo ${sdCoor}|cut -d"," -f3)
         xres=$(fslval ${img} pixdim1)
         yres=$(fslval ${img} pixdim2)
         zres=$(fslval ${img} pixdim3)
         ;;
      #############################################################
      # Coordinates are always in standard space, so if the
      # primary BOLD timeseries has already been normalised, then
      # there is no need for any further manipulations.
      #############################################################
      std2standard)
         res=$(grep -i "^SPACE::" ${sca_lib[${cxt}]}|cut -d":" -f5)
         xres=$(echo ${res}|cut -d"," -f1)
         yres=$(echo ${res}|cut -d"," -f2)
         zres=$(echo ${res}|cut -d"," -f3)
         ;;
      esac
      #############################################################
      # Use the warped coordinates and radius to generate a map
      # of the seed region.
      #############################################################
      [[ ! -d ${outbase}maps ]] && mkdir -p ${outbase}maps
      rm -f ${outbase}maps/${sdName}.sclib
      echo "SPACE::VOXEL::${xres},${yres},${zres}::${img}" \
         >> ${outbase}maps/${sdName}.sclib
      echo ":#ROIName#X,Y,Z#radius" \
         >> ${outbase}maps/${sdName}.sclib
      echo "#${sdName}#${xcoor},${ycoor},${zcoor}#${sdRad}" \
         >> ${outbase}maps/${sdName}.sclib
      [[ ${trace} == 1 ]] && traceprop="-x"
      ${XCPEDIR}/utils/coor2map \
         ${traceprop} \
         -i ${outbase}maps/${sdName}.sclib \
         -t ${referenceVolumeBrain[${subjidx}]} \
         -o ${outbase}maps/${sdName}
      sdPath=${outbase}maps/${sdName}${ext}
      ;;
   mask)
      sdCoor=$(eval echo ${sdCoor})
      [[ ! -d ${outbase}maps ]] && mkdir -p ${outbase}maps
      #############################################################
      # sdRad here stores the space of the seed mask, one of
      #  * nat (native analyte)
      #  * str (native structural)
      #  * std (template standard)
      #
      # Use NN interpolation for any masks.
      #############################################################
      case ${sdRad}2${space} in
      #############################################################
      # If the mask and the image are both in native BOLD space,
      # then no transformations need be applied
      #############################################################
      nat2native)
         rm -f ${outbase}maps/${sdName}${ext}
         ln -s ${sdCoor} ${outbase}maps/${sdName}${ext}
         ;;
      #############################################################
      # If the map is in native BOLD space and the image is in
      # standard space, then all forward transformations must be
      # applied.
      #############################################################
      nat2standard)
         rm -f ${outbase}maps/${sdName}${ext}
         ${ANTSPATH}/antsApplyTransforms \
            -e 3 -d 3 \
            -i ${sdCoor} \
            -o ${outbase}maps/${sdName}${ext} \
            -r ${referenceVolume[${subjidx}]}${ext} \
            $resample \
            $warp \
            $affine \
            $rigid \
            $coreg \
            -n NearestNeighbor
         ;;
      #############################################################
      # If the seed mask is in native structural space and the
      # image in native space, then only the inverse coregistration
      # must be applied
      #############################################################
      str2native)
         rm -f ${outbase}maps/${sdName}${ext}
         ${ANTSPATH}/antsApplyTransforms \
            -e 3 -d 3 \
            -i ${sdCoor} \
            -o ${outbase}maps/${sdName}${ext} \
            -r ${referenceVolume[${subjidx}]}${ext} \
            $icoreg \
            -n NearestNeighbor
         ;;
      #############################################################
      # If the seed mask is in native structural space and the
      # image in standard space, then all forward ANTsCT transforms
      # (but not the coregistration) must be applied
      #############################################################
      str2standard)
         rm -f ${outbase}maps/${sdName}${ext}
         ${ANTSPATH}/antsApplyTransforms \
            -e 3 -d 3 \
            -i ${sdCoor} \
            -o ${outbase}maps/${sdName}${ext} \
            -r ${referenceVolume[${subjidx}]}${ext} \
            $resample \
            $warp \
            $affine \
            $rigid \
            -n NearestNeighbor
         ;;
      #############################################################
      # If the seed mask is in standard space and the image in
      # native space, then all inverse transforms must be applied
      #############################################################
      std2native)
         rm -f ${outbase}maps/${sdName}${ext}
         ${ANTSPATH}/antsApplyTransforms \
            -e 3 -d 3 \
            -i ${sdCoor} \
            -o ${outbase}maps/${sdName}${ext} \
            -r ${referenceVolume[${subjidx}]}${ext} \
            $icoreg \
            $irigid \
            $iaffine \
            $iwarp \
            $iresample \
            -n NearestNeighbor
         ;;
      #############################################################
      # If the seed mask and image are both in standard space,
      # then no transforms are necessary
      #############################################################
      std2standard)
         rm -f ${outbase}maps/${sdName}${ext}
         ln -s ${sdCoor} ${outbase}maps/${sdName}${ext}
         ;;
      esac
      #############################################################
      # Update the path to the seed map
      #############################################################
      sdPath=${outbase}maps/${sdName}${ext}
      ;;
   esac
   ################################################################
   # [2]
   # Now that the seed map has been created in BOLD space, the
   # next stage is extracting a (weighted) mean timeseries from
   # the seed map.
   ################################################################
   printf "ts::"
   [[ ! -d ${outbase}ts ]] && mkdir -p ${outbase}ts
   rm -f ${outbase}ts/${sdName}.1D
   ${XCPEDIR}/utils/tswmean.R \
      -i ${img}${ext} \
      -r ${sdPath} \
      >> ${outbase}ts/${sdName}.1D
   ################################################################
   # [3]
   # Using the mean timeseries, it is now possible to perform
   # voxelwise SCA.
   ################################################################
   printf "sca::"
   rm -f ${scabase}${sdName}_r_sca${ext}
   3dfim+ \
      -input ${img_sm}${ext} \
      -ideal_file ${outbase}ts/${sdName}.1D \
      -out Correlation \
      -bucket ${scabase}${sdName}_r_sca${ext} \
      > /dev/null 2>&1
   ################################################################
   # Fisher transform: not certain why the signs are reversed,
   # but it has worked this way
   ################################################################
   rm -f ${scabase}${sdName}_zr_sca${ext}
   3dcalc \
      -a ${scabase}${sdName}_r_sca${ext} \
      -expr 'log((a+1)/(a-1))/2' \
      -prefix ${scabase}${sdName}_zr_sca${ext} \
      > /dev/null 2>&1
   ################################################################
   # Complete the analysis for the current seed by writing its
   # SCA map into the derivatives index.
   ################################################################
   echo "#sca_zr_${sdName}#${scabase}${sdName}_zr_sca" \
      >> ${auxImgs[${subjidx}]}
   echo "#sca_r_${sdName}#${scabase}${sdName}_r_sca" \
      >> ${auxImgs[${subjidx}]}
   echo "END"
done
echo "Processing step complete: seed-based correlation analysis"





###################################################################
# CLEANUP
#  * Remove any temporary files if cleanup is enabled.
#  * Update the audit file to reflect completion of the module.
###################################################################
img=$(readlink -f ${img}${ext})
if [[ "${sca_cleanup[${cxt}]}" == "Y" ]]
   then
   rm -rf ${outdir}/*~TEMP~*
fi
prefields=$(echo $(grep -o "_" <<< $prefix|wc -l) + 1|bc)
modaudit=$(expr ${prefields} + ${cxt} + 1)
subjaudit=$(grep -i $(echo ${prefix}|sed s@'_'@','@g) ${audit})
replacement=$(echo ${subjaudit}\
   |sed s@[^,]*@@${modaudit}\
   |sed s@',,'@',1,'@ \
   |sed s@',$'@',1'@g)
sed -i s@${subjaudit}@${replacement}@g ${audit}

echo "Module complete"
