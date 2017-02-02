#!/usr/bin/env bash

###################################################################
#  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  #
###################################################################

###################################################################
# This pipeline module computes ALFF.
# Based on work by Xi-Nian Zuo, Maarten Mennes & Michael Milham
# for NITRC
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
echo "#  ☭                   EXECUTING ALFF MODULE                   ☭  #"
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
outdir=${out}/${prep}alff
[[ ! -e ${outdir} ]] && mkdir -p ${outdir}
echo "Output directory is $outdir"
###################################################################
# Define paths to all potential outputs.

# For the alff module, potential outputs include:
#  * alff : the voxelwise ALFF map
# For the alff module, there may exist an unlimited number of
# potential outputs, depending on the number of parcellations
# provided by the user for analysis:
#  * alffbase : Base name for all outputs of the ALFF analysis;
#    the name of each parcellation will be appended to this base
#    name
###################################################################
alff[${cxt}]=${outdir}/${prefix}_alff
alffbase=${outdir}/${prefix}_
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
echo "# *** outputs from alff[${cxt}] *** #" >> $design_local
echo "" >> $design_local
###################################################################
# It is always assumed that this module should re-run.
#
# Each ALFF map is checked separately to determine whether each
# ALFF should be run.
###################################################################
###################################################################
# END GENERAL MODULE HEADER
###################################################################
###################################################################





###################################################################
# Apply the desired smoothing kernel to the BOLD timeseries.
###################################################################
img_sm_name=sm${alff_smo[${cxt}]}
img_sm=img_sm${alff_smo[${cxt}]}[${subjidx}]
if [[ $(imtest ${!img_sm}) == 1 ]]
   then
   img=${!img_sm}
###################################################################
# Determine whether an image with the specified smoothing kernel
# already exists
###################################################################
elif [[ $(imtest ${alffbase}sm${alff_smo[${cxt}]}) == 1 ]]
   then
   img=${alffbase}sm${alff_smo[${cxt}]}
   echo "img_sm${alff_smo[${cxt}]}[${subjidx}]=${img}" >> ${design_local}
   echo "#${img_sm_name}#${img}" >> ${auxImgs[${subjidx}]}
###################################################################
# If no spatial filtering has been specified by the user, then
# bypass this step.
###################################################################
elif [[ ${alff_sptf[${cxt}]} == none ]] \
   || [[ ${alff_smo[${cxt}]} == 0 ]]
   then
   img=${img}
else
   echo ""; echo ""; echo ""
   echo "Current processing step:"
   echo "Spatially filtering image"
   echo "Filter: ${alff_sptf[${cxt}]}"
   echo "Smoothing kernel: ${alff_smo[${cxt}]} mm"
   ################################################################
	# Ensure that this step has not already run to completion
	# by checking for the existence of a smoothed image.
   ################################################################
   if [[ $(imtest ${img}_${cur}) != "1" ]] \
      || [[ "${alff_rerun[${cxt}]}" == "Y" ]]
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
         3dAutomask -prefix ${outbase}_fmask${ext} \
            -dilate 3 \
            -q \
            ${img}${ext}
         susanmask=${outbase}_fmask${ext}
      fi
      #############################################################
	   # Prime the inputs to sfilter for SUSAN filtering
      #############################################################
      if [[ "${alff_sptf[${cxt}]}" == susan ]]
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
            ${alff_sptf[${cxt}]}=uniform
            echo "alff_sptf[${cxt}]=${alff_sptf[${cxt}]}" \
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
	      -o ${outbase}sm${alff_smo[${cxt}]} \
	      -s ${alff_sptf[${cxt}]} \
	      -k ${alff_smo[${cxt}]} \
	      -m ${mask} \
	      ${usan} \
	      ${trace_prop}
	   immv ${outbase}sm${alff_smo[${cxt}]} ${alffbase}sm${alff_smo[${cxt}]}
	fi
   ################################################################
   # Update image pointer, and write the smoothed image path to
   # the design file and derivatives index so that it may be used
   # by additional modules.
   ################################################################
   img=${alffbase}sm${alff_smo[${cxt}]}
   echo "img_sm${alff_smo[${cxt}]}[${subjidx}]=${img}" >> ${design_local}
   echo "#${img_sm_name}#${img}" >> ${auxImgs[${subjidx}]}
   echo "Processing step complete: spatial filtering"
fi





###################################################################
# Determine whether the voxelwise ALFF map needs to be computed
###################################################################
if [[ $(imtest ${alff[${cxt}]}) != 1 ]] \
   || [[ ${alff_rerun[${cxt}]} == Y ]]
   then
   ################################################################
   # * Compute number of volumes: An even number is required by
   #   FSLpSpec
   # * Also obtain the repetition time
   ################################################################
   echo ""; echo ""; echo ""
   echo "Current processing step:"
   echo "Ensuring integer periods"
   nvol=$(fslnvols ${img})
   isOdd=$(expr ${nvol} % 2)
   trep=$(fslval ${img} pixdim4)
   ################################################################
   # If odd, remove the first volume
   ################################################################
   if [[ ${isOdd} -eq 1 ]]
      then
      echo " * Odd volume count: Excising first volume"
       fslroi ${img} \
         ${outbase}dvo \
         1 \
         $(expr ${nvol} - 1)
   else
      rm -f ${outbase}dvo${ext}
      ln -s ${img}${ext} ${outbase}dvo${ext}
   fi
   img=${outbase}dvo
   nvol=$(expr ${nvol} / 2 \* 2) # According to expr, 31 / 2 * 2 = 30
   echo "Processing step complete:"
   echo "Ensuring integer periods"





   ################################################################
   # Compute the power spectrum
   ################################################################
   echo ""; echo ""; echo ""
   echo "Current processing step:"
   echo "Computing power spectrum"
   fslpspec ${img} ${img}_ps
   echo " * Computing square root of amplitudes"
   fslmaths ${img}_ps -sqrt ${img}_ps_sqrt





   ################################################################
   # Calculate ALFF
   ################################################################
   echo ""; echo ""; echo ""
   echo "Current processing step:"
   echo "Computing voxelwise ALFF"
   echo " * Extracting power spectrum at the low frequency band"
   ################################################################
   # Compute the fractional frequency corresponding to the highpass
   # cutoff frequency
   ################################################################
   n_hp=$(echo "scale=10; ${alff_hipass[${cxt}]}*${nvol}*${trep}"|bc)
   n1=$(echo "${n_hp}-1"|bc|xargs printf "%1.0f")
   echo " * ${alff_hipass[${cxt}]} Hz is approximately position ${n1}"
   echo "   of the power spectrum."
   ################################################################
   # Compute the fractional frequency corresponding to the lowpass
   # cutoff frequency
   ################################################################
   [[ ${alff_lopass[${cxt}]} == nyquist ]] && alff_lopass[${cxt}]=99999
   n_lp=$(echo "scale=10; ${alff_lopass[${cxt}]}*${nvol}*${trep}"|bc)
   n2=$(echo "${n_lp}-${n_hp}+1"|bc|xargs printf "%1.0f") ; 
   echo " * There are about ${n2} frequency positions corresponding to "
   echo "   the passband (${alff_lopass[${cxt}]} - ${alff_hipass[${cxt}]} Hz) in the power "
   echo "   spectrum."
   ################################################################
   # Extract the data corresponding to the passband from the power
   # spectrum square root of amplitudes
   ################################################################
   fslroi ${img}_ps_sqrt ${img}_ps_slow ${n1} ${n2}
   ################################################################
   # Compute ALFF; this is the sum of the amplitudes across all
   # frequencies in the passband
   ################################################################
   echo " * Computing the amplitude of low-frequency fluctuations (ALFF)"
   fslmaths ${img}_ps_slow -Tmean -mul ${n2} ${alff[${cxt}]}
   echo "Processing step complete:"
   echo "Computing voxelwise ALFF"





   ################################################################
   # Convert the raw ALFF output values to standard scores.
   ################################################################
   echo ""; echo ""; echo ""
   echo "Current processing step:"
   echo "Standardising ALFF values"
   mean=$(fslstats ${alff[${cxt}]} \
         -k ${mask[${subjidx}]} \
         -M)
   std=$(fslstats ${alff[${cxt}]} \
         -k ${mask[${subjidx}]} \
         -S)
   fslmaths ${alff[${cxt}]} \
      -sub ${mean} \
      -div ${std} \
      -mas ${mask[${subjidx}]} \
      ${alff[${cxt}]}_Z
   echo "Processing step complete:"
   echo "Standardising ALFF values"
fi





###################################################################
# Write outputs to design file and index of derivatives
###################################################################
echo "alff[${subjidx}]=${alff[${cxt}]}" >> ${design_local}
echo "#alff#${alff[${cxt}]}#alff,${cxt}" >> ${auxImgs[${subjidx}]}
echo "#alffZ#${alff[${cxt}]}_Z#alff,${cxt}" >> ${auxImgs[${subjidx}]}





###################################################################
# CLEANUP
#  * Remove any temporary files if cleanup is enabled.
#  * Update the audit file to reflect completion of the module.
###################################################################
img=$(readlink -f ${img}${ext})
if [[ "${alff_cleanup[${cxt}]}" == "Y" ]]
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
