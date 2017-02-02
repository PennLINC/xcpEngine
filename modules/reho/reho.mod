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
echo "###################################################################"
echo "#  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  #"
echo "#                                                                 #"
echo "#  ☭                   EXECUTING REHO MODULE                   ☭  #"
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
###################################################################
# Create a directory for intermediate outputs.
###################################################################
[[ ${NUMOUT} == 1 ]] && prep=${cxt}_
outdir=${out}/${prep}reho
[[ ! -e ${outdir} ]] && mkdir -p ${outdir}
echo "Output directory is $outdir"
###################################################################
# Define paths to all potential outputs.

# For the reho module, potential outputs include:
#  * reho : the voxelwise ReHo map
# For the reho module, there may exist an unlimited number of
# potential outputs, depending on the number of parcellations
# provided by the user for analysis:
#  * rehobase : Base name for all outputs of the ReHo analysis;
#    the name of each parcellation will be appended to this base
#    name
###################################################################
reho[${cxt}]=${outdir}/${prefix}_reho
rehobase=${outdir}/${prefix}_
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
echo "# *** outputs from reho[${cxt}] *** #" >> $design_local
echo "" >> $design_local
###################################################################
# It is always assumed that this module should re-run.
#
# Each set of RoI statistics for ReHo is checked separately to
# determine whether each should be computed.
###################################################################
###################################################################
# END GENERAL MODULE HEADER
###################################################################
###################################################################





###################################################################
# Determine whether the voxelwise ReHo map needs to be computed
###################################################################
if [[ $(imtest ${reho[${cxt}]}) != 1 ]] \
   || [[ ${reho_rerun[${cxt}]} == Y ]]
   then
   echo ""; echo ""; echo ""
   echo "Current processing step:"
   echo "Computing voxelwise ReHo"
   ################################################################
   # Translate from neighbourhood type to number of neighbours
   ################################################################
   echo " * Determining voxel neighbourhood"
   [[ ${reho_nhood[${cxt}]} == faces ]] && nneigh="-nneigh 7"
   [[ ${reho_nhood[${cxt}]} == edges ]] && nneigh="-nneigh 19"
   [[ ${reho_nhood[${cxt}]} == vertices ]] && nneigh="-nneigh 27"
   [[ -n $(echo ${reho_nhood[${cxt}]}|grep "sphere") ]] \
      && mmrad=$(echo ${reho_nhood[${cxt}]}|cut -d"," -f2) \
      && xdim=$(fslval ${img} pixdim1) \
      && ydim=$(fslval ${img} pixdim2) \
      && zdim=$(fslval ${img} pixdim3) \
      && xdim=$(echo "scale=10; ${mmrad} / ${xdim}"|bc) \
      && ydim=$(echo "scale=10; ${mmrad} / ${ydim}"|bc) \
      && zdim=$(echo "scale=10; ${mmrad} / ${zdim}"|bc) \
      && nneigh="-neigh_X ${xdim} -neigh_Y ${ydim} -neigh_Z ${zdim}"
   echo " * Computing regional homogeneity(ReHo)"
   3dReHo \
      -prefix ${reho[${cxt}]}${ext} \
      -inset ${img}${ext} \
      ${nneigh} \
      2>/dev/null
   echo "Processing step complete:"
   echo "Computing voxelwise ReHo"





   ################################################################
   # Apply the desired smoothing kernel to the voxelwise ReHo map.
   #
   # If no spatial filtering has been specified by the user, then
   # bypass this step.
   ################################################################
   if [[ ${reho_sptf[${cxt}]} == none ]] \
      || [[ ${reho_smo[${cxt}]} == 0 ]]
      then
      reho[${cxt}]=${reho[${cxt}]}
   else
      echo ""; echo ""; echo ""
      echo "Current processing step:"
      echo "Spatially filtering ReHo map"
      echo "Filter: ${reho_sptf[${cxt}]}"
      echo "Smoothing kernel: ${reho_smo[${cxt}]} mm"
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
         3dAutomask -prefix ${outbase}_fmask${ext} \
            -dilate 3 \
            -q \
            ${img}${ext}
         susanmask=${outbase}_fmask${ext}
      fi
      #############################################################
	   # Prime the inputs to sfilter for SUSAN filtering
      #############################################################
      if [[ "${reho_sptf[${cxt}]}" == susan ]]
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
            usan="-u ${referenceVolume[${subjidx}]}"
         else
            ${reho_sptf[${cxt}]}=uniform
            echo "reho_sptf[${cxt}]=${reho_sptf[${cxt}]}" \
               >> ${design_local}
         fi
      fi
      #############################################################
	   # If the user has requested command tracing, propagate
	   # that request into the sfilter routine.
      #############################################################
	   [[ ${trace} == 1 ]] && trace_prop="-t"
      #############################################################
	   # Engage the sfilter routine to filter the ReHo map.
	   #  * This is essentially a wrapper around the three
	   #    implemented smoothing routines: gaussian, susan,
	   #    and uniform.
      #############################################################
	   ${XCPEDIR}/utils/sfilter \
	      -i ${reho[${cxt}]} \
	      -o ${outbase}sm${reho_smo[${cxt}]} \
	      -s ${reho_sptf[${cxt}]} \
	      -k ${reho_smo[${cxt}]} \
	      -m ${mask} \
	      ${usan} \
	      ${trace_prop}
	   immv ${outbase}sm${reho_smo[${cxt}]} ${reho[${cxt}]}
   fi





   ################################################################
   # Convert the raw ReHo output values to standard scores.
   ################################################################
   echo ""; echo ""; echo ""
   echo "Current processing step:"
   echo "Standardising ReHo values"
   mean=$(fslstats ${reho[${cxt}]} \
         -k ${mask[${subjidx}]} \
         -M)
   std=$(fslstats ${reho[${cxt}]} \
         -k ${mask[${subjidx}]} \
         -S)
   fslmaths ${reho[${cxt}]} \
      -sub ${mean} \
      -div ${std} \
      -mas ${mask[${subjidx}]} \
      ${reho[${cxt}]}_Z
   echo "Processing step complete:"
   echo "Standardising ReHo values"
fi





###################################################################
# Write outputs to design file and index of derivatives
###################################################################
echo "reho[${subjidx}]=${reho[${cxt}]}" >> ${design_local}
unset rq
if [[ ${reho_roikw[${cxt}]} == Y ]]
   then
   rq=kw
fi
if [[ ${reho_roimean[${cxt}]} == Y ]]
   then
   rq=${rq},m
   [[ -z ${rq} ]] && rq=m
fi
echo "#reho#${reho[${cxt}]}#reho,${cxt},${rq}" >> ${auxImgs[${subjidx}]}
echo "#rehoZ#${reho[${cxt}]}_Z#reho,${cxt},${rq}" >> ${auxImgs[${subjidx}]}





###################################################################
# CLEANUP
#  * Remove any temporary files if cleanup is enabled.
#  * Update the audit file to reflect completion of the module.
###################################################################
img=$(readlink -f ${img}${ext})
if [[ "${reho_cleanup[${cxt}]}" == "Y" ]]
   then
   echo ""; echo ""; echo ""
   echo "Cleaning up..."
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
