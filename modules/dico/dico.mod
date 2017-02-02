#!/usr/bin/env bash

###################################################################
#  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  #
###################################################################

###################################################################
# Constants
###################################################################

readonly SIGMA=2.35482004503
readonly INT='^-?[0-9]+$'
readonly POSINT='^[0-9]+$'
readonly MOTIONTHR=0.2
readonly MINCONTIG=5
readonly POSNUM='^[0-9]+([.][0-9]+)?$'





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
echo "#  ✡✡ ✡✡✡✡ ✡✡✡✡✡✡✡✡✡ ✡✡✡✡✡✡✡✡✡✡✡✡✡ ✡✡✡✡✡✡✡✡✡✡✡✡✡ ✡✡✡✡✡✡✡✡ ✡✡✡✡ ✡✡ #"
echo "#                                                                 #"
echo "#  ☭                  EXECUTING DICO MODULE                    ☭  #"
echo "#                                                                 #"
echo "#  ✡✡ ✡✡✡✡ ✡✡✡✡✡✡✡✡✡ ✡✡✡✡✡✡✡✡✡✡✡✡✡ ✡✡✡✡✡✡✡✡✡✡✡✡✡ ✡✡✡✡✡✡✡✡ ✡✡✡✡ ✡✡ #"
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
outdir=${out}/${prep}dico
[[ ! -e ${outdir} ]] && mkdir -p ${outdir}
echo "Output directory is $outdir"
###################################################################
# Define paths to all potential outputs.
#
# For the dico module, potential outputs include:
#  * dico : The output time series with distortion correction
#  * shiftmap : The output shift map - the direction and magnitude
#    of the shift applied
#  * shims : A output text file containing information about the
#    shims performed for the functional series
#  * nclips : 
#  * clipsMask : a spatial mask indicating whether each voxel is
#    clipped 
#  * clipsMaskDico : Dico'ed clipsMask
#  * quality : the temporal signal-to-noise ratio, where signal is
#    defined as the mean intensity over time and noise is defined
#    as the variation in the image intensity over time
#       AND
#    the number of voxels with "clipped" intensity
#    values; that is, the number of voxels with intensity values
#    that equal or exceed the maximum that can be recorded by the
#    scanner
###################################################################
dico[${cxt}]=${outdir}/${prefix}_dico
shiftmap[${cxt}]=${outdir}/${prefix}_shiftmap
shiftmapclips[${cxt}]=${outdir}/${prefix}_clipsShiftmap
shims[${cxt}]=${outdir}/${prefix}_shims.txt
clipsMask[${cxt}]=${outdir}/${prefix}_clipsMask
clipsMaskDico[${cxt}]=${outdir}/${prefix}_clipsMaskDico
quality[${cxt}]=${outdir}/${prefix}_rawQuality.csv
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
img=${outdir}/${prefix}~TEMP~
if [[ $(imtest ${img}) != "1" ]] || [ "${dico_rerun[${cxt}]}" == "Y" ] ; then
   rm -f ${img}*
   ln -s ${out}/${prefix}${ext} ${img}${ext}
fi
imgpath=$(ls ${img}${ext})
###################################################################
# Parse quality variables.
###################################################################
qvars=$(head -n1 ${quality} 2>/dev/null)
qvals=$(tail -n1 ${quality} 2>/dev/null)
###################################################################
# Prime the localised design file so that any outputs from this
# module appear beneath the correct header.
###################################################################
echo "" >> $design_local
echo "# *** outputs from dico[${cxt}] *** #" >> $design_local
echo "" >> $design_local
###################################################################
# Verify that the module should be run:
#  * Test whether the final output already exists.
#  * Determine whether the user requested the module to be re-run.
# If it is determined that the module should not be run, then any
#  outputs must be written to the local design file.
###################################################################
if [[ $(imtest ${dico[${cxt}]}) == "1" ]] \
   && [[ "${dico_rerun[${cxt}]}" == "N" ]]
   then
   echo "[dico] has already run to completion."
   echo "Writing outputs..."
   rm -f ${out}/${prefix}${ext}
   ln -s ${dico[${cxt}]}${ext} ${out}/${prefix}${ext}
   ################################################################
   # OUTPUT: clipsMaskDico
   # Test whether the mask of dico'ed clipped values exists as an
   # image. If it does, then add it to the index of derivatives and
   # to the localised design file.
   ################################################################
   if [[ $(imtest ${clipsMaskDico[${cxt}]}) == 1 ]]
      then
      echo "#clipsMaskDico#${clipsMaskDico[${cxt}]}" \
         >> ${auxImgs[${subjidx}]}
      echo "clipsMaskDico[${subjidx}]=${clipsMaskDico[${cxt}]}" \
         >> $design_local
   fi
   ################################################################
   # OUTPUT: tsnr
   # Test whether the temporal SNR has been computed. If it has,
   # then add it to the index of quality variables and to the
   # localised design file.
   ################################################################
   if [[ -e ${quality[${cxt}]} ]]
      then
      qvars=${qvars},$(head -n1 ${quality[${cxt}]})
      qvals=${qvals},$(tail -n1 ${quality[${cxt}]})
   fi
   if [[ "${dico_cleanup[${cxt}]}" == "Y" ]]
      then
      echo ""; echo ""; echo ""
      echo "Cleaning up..."
      rm -rf ${outdir}/*~TEMP~*
   fi
   ################################################################
   # Since it has been determined that the module does not need to
   # be executed, update the audit file and quality index, and
   # exit the module.
   ################################################################
   rm -f ${quality}
   echo ${qvars} >> ${quality}
   echo ${qvals} >> ${quality}
   prefields=$(echo $(grep -o "_" <<< $prefix|wc -l) + 1|bc)
   modaudit=$(expr ${prefields} + ${cxt} + 1)
   subjaudit=$(grep -i $(echo ${prefix}|sed s@'_'@','@g) ${audit})
   replacement=$(echo ${subjaudit}\
      |sed s@[^,]*@@${modaudit}\
      |sed s@',,'@',1,'@ \
      |sed s@',$'@',1'@g)
   sed -i s@${subjaudit}@${replacement}@g ${audit}
   echo "Module complete"
   exit 0
fi
###################################################################
###################################################################
# END GENERAL MODULE HEADER
###################################################################
###################################################################





echo "Processing image: $img"





###################################################################
###################################################################
# * Compute tSNR and Clips
###################################################################
###################################################################
###################################################################
# SNR computes quality metrics, including the temporal
# signal-to-noise ratio.
###################################################################
echo ""; echo ""; echo ""
echo "Current processing step:"
echo "Computing temporal signal-to-noise ratio"
if [[ -z $(cat ${quality[${cxt}]} 2>/dev/null) ]]
   then
   ################################################################
   # Determine whether a mask exists for the current subject.
   # If one does not (for instance, if this is run before 
   # motion correxion), then automatically spawn a temporary
   # mask.
   ################################################################
   snrmask=${img}_tsnr_mask
   if [[ $(imtest ${mask[${subject}]}) == 1 ]]
      then
      fslmaths ${mask[${subject}]} ${snrmask}
   elif [[ $(imtest ${mask[${cxt}]}) == 1 ]]
      then
      fslmaths ${mask[${cxt}]} ${snrmask}
   else
      snrmask=${img}_snr_mask
      3dAutomask \
         -prefix ${snrmask}${ext} \
         ${img}${ext} \
         2>/dev/null
   fi
   ################################################################
   # Determine whether the image is clipped at a maximal
   # intensity.
   ################################################################
   if [[ "${dico_clip[${cxt}]}" =~ ${POSNUM} ]]
      then
      #############################################################
      # If the image is clipped, create a mask of voxels
      # where the signal intensity at any point in time
      # exceeds the maximal intensity.
      #############################################################
      if [[ ! -e ${clipsMask[${cxt}]} ]] \
         || [[ "${dico_rerun[${cxt}]}" == "Y" ]]
         then
         fslmaths ${img} \
            -Tmax \
            -thr ${dico_clip[${cxt}]} \
            -bin \
            ${clipsMask[${cxt}]}
         ##########################################################
         # Remove the clipped voxels from the tSNR mask so
         # that they do not bias the results.
         ##########################################################
         fslmaths ${clipsMask[${cxt}]} \
            -sub 1 \
            -abs \
            -mul ${snrmask} \
            ${snrmask}
         nclips=$(fslstats ${clipsMask[${cxt}]} -V \
            |awk '{print $1}')
         snrvars=nvoxel_clipped,
         snrvals=${nclips},
      fi
   fi
   ################################################################
   # Determine whether this has already been done.
   ################################################################
   if [[ ! -e ${quality[${cxt}]} ]] \
      || [[ "${dico_rerun[${cxt}]}" == "Y" ]]
      then
      [[ -e ${quality[${cxt}]} ]] && rm -f ${quality[${cxt}]}
      #############################################################
      # Compute the tSNR of each voxelwise timeseries.
      #############################################################
      rm -f ${img}_${cur}${ext}
      3dTstat \
         -cvarinv \
         -prefix ${img}_${cur}${ext} \
         ${img}${ext} \
         2>/dev/null
      tsnr_final=$(fslstats \
         ${img}_${cur} \
         -k ${snrmask} \
         -n \
         -m)
      snrvars=${snrvars}temporalSignalNoiseRatio
      snrvals=${snrvals}${tsnr_final}
      echo ${snrvars} >> ${quality[${cxt}]}
      echo ${snrvals} >> ${quality[${cxt}]}
   fi
fi
echo "Processing step complete:"
echo "Temporal SNR"





###################################################################
###################################################################
# * Apply the distortion correction
###################################################################
###################################################################
echo ""; echo ""; echo ""
echo "Current processing step:"
echo "Applying RPS map to time series"
###################################################################
# * Check to see if a example dicom is supplied
###################################################################
if [[ ! -e ${dico_exampleDicom[${cxt}]} ]] \
   || [[ -z ${dico_exampleDicom[${cxt}]} ]]
   then
   echo "XCP-WARNING: [ABORT] Example DICOM does not exist."
   [[ "${dico_cleanup[${cxt}]}" == "Y" ]] \
      && rm -rf ${outdir}/*~TEMP~*
   err=1
   #qvars=${qvars},dicoComplete
   #qvals=${qvals},0
fi
if [[ ! -e ${dico_magImage[${cxt}]} ]] \
   || [[ -z ${dico_magImage[${cxt}]} ]]
   then
   echo "XCP-WARNING: [ABORT] B0 magnitude map missing."
   [[ "${dico_cleanup[${cxt}]}" == "Y" ]] \
      && rm -rf ${outdir}/*~TEMP~*
   err=1
fi
if [[ ! -e ${dico_rpsImage[${cxt}]} ]] \
   || [[ -z ${dico_rpsImage[${cxt}]} ]]
   then
   echo "XCP-WARNING: [ABORT] B0 RPS map missing."
   [[ "${dico_cleanup[${cxt}]}" == "Y" ]] \
      && rm -rf ${outdir}/*~TEMP~*
   err=1
fi
###################################################################
# OUTPUT: quality
# Test whether the temporal SNR has been computed. If it has, then
# add it to the index of quality variables and to the localised
# design file.
#
# This is done here to ensure that the quality file is updated if
# there is no dico to be run.
###################################################################
if [[ -e ${quality[${cxt}]} ]] && [[ ${err} == 1 ]]
   then
   qvars=${qvars},$(head -n1 ${quality[${cxt}]})
   qvals=${qvals},$(tail -n1 ${quality[${cxt}]})
   rm -f ${quality}
   echo ${qvars} >> ${quality}
   echo ${qvals} >> ${quality}
fi
if [[ ${err} == 1 ]]
   then
   exit 666
fi
###################################################################
# * Now create the dico'ed nclip mask
# * If the clips mask exists
# * First, prepare the RPS mask.
###################################################################
rpsMaskImage=${img}rpsMask
if [[ $(imtest ${rpsMaskImage}) != 1 ]] \
   || [[ ${dico_rerun[${cxt}]} == Y ]]
   then
   fslmaths ${dico_rpsImage[${cxt}]} \
      -abs \
      -bin \
      ${rpsMaskImage}
fi
if [[ $(imtest ${clipsMask[${cxt}]}) == 1 ]]
   then
   ${dico_script[${cxt}]} -n \
      -FS \
      -e ${dico_exampleDicom[${cxt}]} \
      -f ${dico_magImage[${cxt}]} \
      ${outdir}/${prefix} \
      ${dico_rpsImage[${cxt}]} \
      ${rpsMaskImage}${ext} \
      ${clipsMask[${cxt}]}${ext}
   ################################################################
   # * Now convert the images back to the input file type
   # * Melliott's scripts only output nii images
   ################################################################
   buffer=${FSLOUTPUTTYPE}
   fslchfiletype ${buffer} ${dico[${cxt}]}.nii
   fslchfiletype ${buffer} ${shiftmap[${cxt}]}.nii
   export FSLOUTPUTTYPE=${buffer}
   ################################################################
   # * Now apply the threshold and rebinarize the clips mask
   # * Also mv the nclips shift mask to a new file
   ################################################################
   fslmaths ${dico[${cxt}]} \
      -thr .5 \
      -bin \
      ${clipsMaskDico[${cxt}]}
   rm -f ${dico[${cxt}]}${ext}
   mv ${shiftmap[${cxt}]}${ext} ${shiftmapclips[${cxt}]}${ext}
fi

###################################################################
# * Now create the dico'ed time series
###################################################################
if [[ $(imtest ${dico[${cxt}]}) != 1 ]]
   then
   ${dico_script[${cxt}]} -n \
      -FS \
      -e ${dico_exampleDicom[${cxt}]} \
      -f ${dico_magImage[${cxt}]} \
      ${outdir}/${prefix} \
      ${dico_rpsImage[${cxt}]} \
      ${rpsMaskImage}${ext} \
      ${img}${ext}
   ################################################################
   # * Now convert the images back to the input file type
   # * Melliott's scripts only output nii images
   ################################################################
   buffer=${FSLOUTPUTTYPE}
   fslchfiletype ${buffer} ${dico[${cxt}]}
   fslchfiletype ${buffer} ${shiftmap[${cxt}]}
   export FSLOUTPUTTYPE=${buffer}
fi


###################################################################
# Write any remaining output paths to local design file so that
# they may be used further along the pipeline.
###################################################################
echo ""; echo ""; echo ""
echo "Writing outputs..."
rm -f ${out}/${prefix}${ext}
ln -s ${dico[${cxt}]}${ext} ${out}/${prefix}${ext}
###################################################################
# OUTPUT: quality
# Test whether the temporal SNR has been computed. If it has, then
# add it to the index of quality variables and to the localised
# design file.
###################################################################
if [[ -e ${quality[${cxt}]} ]]
   then
   qvars=${qvars},$(head -n1 ${quality[${cxt}]})
   qvals=${qvals},$(tail -n1 ${quality[${cxt}]})
fi
###################################################################
# OUTPUT: clipsMaskDico
# Test whether the mask of dico'ed clipped values exists as an
# image. If it does, then add it to the index of derivatives and
# to the localised design file.
###################################################################
if [[ $(imtest ${clipsMaskDico[${cxt}]}) == 1 ]]
   then
   echo "#clipsMaskDico#${clipsMaskDico[${cxt}]}" \
      >> ${auxImgs[${subjidx}]}
   echo "clipsMaskDico[${subjidx}]=${clipsMaskDico[${cxt}]}" \
      >> $design_local
fi





###################################################################
# CLEANUP
#  * Remove any temporary files if cleanup is enabled.
#  * Update the audit file and quality index.
###################################################################
echo ""; echo ""; echo ""
if [[ "${dico_cleanup[${cxt}]}" == "Y" ]]
   then
   echo ""; echo ""; echo ""
   echo "Cleaning up..."
   rm -rf ${outdir}/*~TEMP~*
fi
rm -f ${quality}
echo ${qvars} >> ${quality}
echo ${qvals} >> ${quality}
prefields=$(echo $(grep -o "_" <<< $prefix|wc -l) + 1|bc)
modaudit=$(expr ${prefields} + ${cxt} + 1)
subjaudit=$(grep -i $(echo ${prefix}|sed s@'_'@','@g) ${audit})
replacement=$(echo ${subjaudit}\
   |sed s@[^,]*@@${modaudit}\
   |sed s@',,'@',1,'@ \
   |sed s@',$'@',1'@g)
sed -i s@${subjaudit}@${replacement}@g ${audit}

echo "Module complete"
