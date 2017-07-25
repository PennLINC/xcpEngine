#!/usr/bin/env bash

###################################################################
#  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  #
###################################################################

###################################################################
# Constants
# TODO
# Consider moving PERSIST to a design variable.
###################################################################

readonly SIGMA=2.35482004503
readonly INT='^-?[0-9]+$'
readonly POSINT='^[0-9]+$'
readonly MOTIONTHR=0.2
readonly MINCONTIG=0
readonly PERSIST=0





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
echo "#  ☭                 EXECUTING PRESTATS MODULE                 ☭  #"
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
outdir=${out}/${prep}prestats
[[ ! -e ${outdir} ]] && mkdir -p ${outdir}
echo "Output directory is $outdir"
###################################################################
# Define paths to all potential outputs.
#
# For the prestats module, potential outputs include:
#  * referenceVolume : an example volume extracted from EPI data,
#    typically one of the middle volumes, though another may be
#    selected if the middle volume is corrupted by motion-related
#    noise; this is used as the reference volume during motion
#    correction
#  * meanIntensity : the mean intensity over time of functional data,
#    after it has been realigned with the example volume
#  * mcdir : the directory containing motion correction output
#  * rps : the 6 realignment parameters computed in the motion
#    correction procedure
#  * relrms : relative root mean square motion, computed in the
#    motion correction procedure
#  * relmeanrms : mean relative RMS motion, computed in the
#    motion correction procedure
#  * absrms : absolute root mean square displacement, computed in
#    the motion correction procedure
#  * absmeanrms : mean absolute RMS displacement, computed in the
#    motion correction procedure
#  * rmat : a directory containing rigid transforms applied to each
#    volume in order to realign it with the reference volume
#  * fd : Framewise displacement values, computed as the absolute
#    sum of realignment parameter first derivatives
#  * tmask : A temporal mask of binary values, indicating whether
#    the volume survives motion censorship
#  * qavol : A quality control file that specifies the number of
#    volumes that exceeded the maximum motion criterion. If
#    censoring is enabled, then this will be the same number of
#    volumes that are to be censored.
#  * mask : A spatial mask of binary values, indicating whether
#    a voxel should be analysed as part of the brain; this is often
#    fairly liberal
#  * auxImgs : a path to an index of derivative images, after they
#    have been processed by this module; this is necessary only if
#    smoothing or temporal filtering is included
#  * final : The final output of the module, indicating its
#    successful completion
###################################################################
referenceVolume[${cxt}]=${outdir}/${prefix}_referenceVolume
referenceVolumeBrain[${cxt}]=${outdir}/${prefix}_referenceVolumeBrain
meanIntensity[${cxt}]=${outdir}/${prefix}_meanIntensity
meanIntensityBrain[${cxt}]=${outdir}/${prefix}_meanIntensityBrain
mcdir[${cxt}]=${outdir}/mc
rps[${cxt}]=${outdir}/mc/${prefix}_realignment.1D
relrms[${cxt}]=${outdir}/mc/${prefix}_relRMS.1D
relmeanrms[${cxt}]=${outdir}/mc/${prefix}_relMeanRMS.txt
absrms[${cxt}]=${outdir}/mc/${prefix}_absRMS.1D
absmeanrms[${cxt}]=${outdir}/mc/${prefix}_absMeanRMS.txt
rmat[${cxt}]=${outdir}/mc/${prefix}.mat
fd[${cxt}]=${outdir}/mc/${prefix}_fd.1D
tmask[${cxt}]=${outdir}/mc/${prefix}_tmask.1D
qavol[${cxt}]=${outdir}/mc/${prefix}_${prestats_censor_cr[${cxt}]}_nvolFailQA.txt
mask[${cxt}]=${outdir}/${prefix}_mask
auxImgs[${cxt}]=${outdir}/${prefix}_derivs
final[${cxt}]=${outdir}/${prefix}_preprocessed
rm -f ${auxImgs[${cxt}]}
###################################################################
# * Initialise a pointer to the image.
# * Ensure that the pointer references an image, and not something
#   else such as a design file.
# * On the basis of this, define the image extension to be used for
#   this module (for operations, such as AFNI, that require an
#   extension).
# * Localise the image using a symlink, if applicable.
# * In the prestats module, the image name is used as the base name
#   of intermediate outputs.
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
if [[ $(imtest ${img}) != "1" ]] \
   || [ "${prestats_rerun[${cxt}]}" == "Y" ]
   then
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
echo "# *** outputs from prestats[${cxt}] *** #" >> $design_local
echo "" >> $design_local
###################################################################
# Verify that the module should be run:
#  * Test whether the final output already exists.
#  * Determine whether the user requested the module to be re-run.
# If it is determined that the module should not be run, then any
#  outputs must be written to the local design file.
###################################################################
if [[ $(imtest ${final[${cxt}]}) == "1" ]] \
   && [[ "${prestats_rerun[${cxt}]}" == "N" ]]
   then
   echo "Prestats has already run to completion."
   echo "Writing outputs..."
   if [[ "${prestats_cleanup[${cxt}]}" == "Y" ]]
      then
      rm -rf ${outdir}/*~TEMP~*
   fi
   rm -f ${out}/${prefix}${ext}
   ln -s ${final[${cxt}]}${ext} ${out}/${prefix}${ext}
   ################################################################
   # OUTPUT: meanIntensity
   # Test whether the mean of functional volumes exists as an
   # image. If it does, add it to the index of derivatives and to
   # the localised design file.
   ################################################################
   if [[ $(imtest ${meanIntensity[${cxt}]}) == "1" ]]
      then
      echo "#meanIntensity#${meanIntensity[${cxt}]}" \
         >> ${auxImgs[${subjidx}]}
      echo "meanIntensity[${subjidx}]=${meanIntensity[${cxt}]}" \
         >> $design_local
   fi
   ################################################################
   # OUTPUT: referenceVolume
   # Test whether an example functional volume exists as an
   # image. If it does, add it to the index of derivatives and to
   # the localised design file.
   ################################################################
   if [[ $(imtest ${referenceVolume[${cxt}]}) == "1" ]]
      then
      echo "referenceVolume[${subjidx}]=${referenceVolume[${cxt}]}" \
         >> $design_local
      echo "#referenceVolume#${referenceVolume[${cxt}]}" \
         >> ${auxImgs[${subjidx}]}
   fi
   ################################################################
   # OUTPUT: brain-extracted referenceVolume and meanIntensity
   # Test whether brain-extracted mean or example functional volume
   # exist. If either does, add it to the index of derivatives and
   # to the localised design file.
   ################################################################
   if [[ $(imtest ${referenceVolumeBrain[${cxt}]}) == "1" ]]
      then
      echo "referenceVolumeBrain[${subjidx}]=${referenceVolumeBrain[${cxt}]}" \
         >> $design_local
      echo "#referenceVolumeBrain#${referenceVolumeBrain[${cxt}]}" \
         >> ${auxImgs[${subjidx}]}
   fi
   if [[ $(imtest ${meanIntensityBrain[${cxt}]}) == "1" ]]
      then
      echo "meanIntensityBrain[${subjidx}]=${meanIntensityBrain[${cxt}]}" \
         >> $design_local
      echo "#meanIntensityBrain#${meanIntensityBrain[${cxt}]}" \
         >> ${auxImgs[${subjidx}]}
   fi
   ################################################################
   # OUTPUT: mask
   # Test whether a binary mask denoting brain voxels exists as an
   # image. If it does, add it to the index of derivatives and to
   # the localised design file.
   ################################################################
   if [[ $(imtest ${mask[${cxt}]}) == "1" ]]
      then
      echo "mask[${subjidx}]=${mask[${cxt}]}" >> $design_local
      echo "#mask#${mask[${cxt}]}" >> ${auxImgs[${subjidx}]}
   fi
   ################################################################
   # OUTPUT: mcdir
   # Test whether the motion-correction directory exists. If it
   # does, add it to the localised design file. Then, search for
   # other motion-related variables.
   ################################################################
   if [[ -d "${mcdir[${cxt}]}" ]]
      then
      echo "mcdir[${subjidx}]=${mcdir[${cxt}]}" >> $design_local
      #############################################################
      # OUTPUT: rps, relrms
      # Realignment parameters may exist either in a filtered or
      # in an unfiltered state. Under any circumstances, they
      # should exist at the output specified above.
      #############################################################
      if [[ -e "${rps[${cxt}]}" ]]
         then
         echo "rps[${subjidx}]=${rps[${cxt}]}" >> $design_local
         echo "relrms[${subjidx}]=${relrms[${cxt}]}" >> \
            $design_local
         qvars=${qvars},relMeanRMSmotion
	      qvals="${qvals},$(cat ${relmeanrms[${cxt}]})"
      fi
      #############################################################
      # OUTPUT: fd, tmask, censor
      # Volumes to be censored should only be determined once in
      # the course of an analysis. If, for some unknown reason,
      # you run motion correction multiple times, only the first
      # time will produce censorship variables.
      #############################################################
      if [[ -z "${censor[${subjidx}]}" ]]
         then
         ##########################################################
         # Even if no censorship is being performed, framewise
         # displacement is computed and written to the design
         # file. It may be used for QA purposes, etc.
         ##########################################################
         echo "fd[${subjidx}]=${fd[${cxt}]}" >> $design_local
         echo "motionvols[${subjidx}]=${qavol[${cxt}]}" >> $design_local
         mthr=$(echo ${prestats_censor[${cxt}]}|cut -d"," -f2)
         [[ ${mthr} == none ]] && mthr=${MOTIONTHR}
	      qvars=${qvars},nframesHighMotion${prestats_censor_cr[${cxt}]}${mthr}
	      qvals="${qvals},$(cat ${qavol[${cxt}]})"
         ##########################################################
         # If the user has requested censorship of volumes on
         # the basis of subject motion, a temporal mask is
         # written to the design file. In the REGRESS module,
         # this mask will determine what volumes to take into
         # account when estimating linear model parameters.
         # Furthermore, volumes with 0 values are discarded from
         # the timeseries.
         ##########################################################
         if [[ "${prestats_censor[${cxt}]}" != "none" ]]
            then
            echo "tmask[${subjidx}]=${tmask[${cxt}]}" >> \
               $design_local
	         censor[${cxt}]=$(echo ${prestats_censor[${cxt}]}|cut -d"," -f1)
            echo "censor[${subjidx}]=${censor[${cxt}]}" >> \
               $design_local
         ##########################################################
         # If the user has not requested censorship, then only
         # the censorship status is written to the design file.
         # This prevents future runs of prestats from
         # overwriting framewise displacement and censorship-
         # related variables.
         ##########################################################
         else
            echo "censor[${subjidx}]=none" >> $design_local
         fi
	   fi
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





###################################################################
# The variable 'buffer' stores the processing steps that are
# already complete; it becomes the expected ending for the final
# image name and is used to verify that prestats has completed
# successfully.
###################################################################
buffer=""

echo "Processing image: $img"

###################################################################
# Parse the processing code to determine what analysis to run next.
# Current options include:
#  * DVO: discard volumes
#  * MPR: compute motion-related variables, including RPs
#  * MCO: correct for subject motion
#  * STM: slice timing correction
#  * BXT: brain extraction
#  * DMT: demean and detrend timeseries
#  * SPT: spatial filter
#  * TMP: temporal filter
###################################################################
rem=${prestats_process[${cxt}]}
while [[ "${#rem}" -gt "0" ]]
   do
   ################################################################
   # * Extract the first three letters from the user-specified
   #   processing command. 
   # * This three-letter code determines what analysis is run
   #   next.
   # * Remove them from the list of remaining analyses.
   ################################################################
   cur=${rem:0:3}
   rem=${rem:3:${#rem}}
   [[ ${cur} != SNR ]] && buffer=${buffer}_${cur}
   case $cur in
      
      
      
      
      
      DVO)
         ##########################################################
         # DVO discards the first n volumes of the scan, as
         # specified by user input.
         ##########################################################
         echo ""; echo ""; echo ""
         echo "Current processing step:"
         echo "Discarding ${prestats_dvols[${cxt}]} volumes"
	      ##########################################################
	      # Determine whether this has already been done, and 
	      # compute the number of volumes to retain.
	      ##########################################################
         if [[ ! $(imtest ${img}_${cur}) == "1" ]] \
            || [[ "${prestats_rerun[${cxt}]}" == "Y" ]]
            then
            nvol=$(fslnvols $img)
            echo "Total original volumes = $nvol"
	         #######################################################
	         # If dvols is positive, discard the first n volumes
	         # from the BOLD timeseries.
	         #######################################################
	         if [[ ${prestats_dvols[${cxt}]} =~ ${POSINT} ]]
	            then
	            fslroi $img \
	               ${img}_${cur} \
	               ${prestats_dvols[${cxt}]} \
	               $(expr $nvol - ${prestats_dvols[${cxt}]})
	            echo "First ${prestats_dvols[${cxt}]} volumes discarded"
	         #######################################################
	         # If dvols is negative, discard the last n volumes
	         # from the BOLD timeseries.
	         #######################################################
	         else
	            fslroi $img \
	               ${img}_${cur} \
	               0 \
	               $(expr $nvol + ${prestats_dvols[${cxt}]})
	            echo "Last ${prestats_dvols[${cxt}]} volumes discarded"
	         fi
         fi
	      ##########################################################
	      # Repeat for any derivatives of the BOLD tiemseries, if
	      # they contain the same number of volumes as the original
	      # timeseries.
	      #
	      # Why? Unless the number of volumes in the BOLD timeseries
	      # and in derivative timeseries -- for instance, local
	      # regressors -- is identical, any linear model
	      # incorporating the derivatives as predictors would
	      # introduce a frameshift error; this may result in
	      # incorrect estimates or even a failure to compute parameter
	      # estimates for the model.
	      #
	      # In many cases, discarding of initial volumes represents
	      # the first stage of fMRI processing. In these cases,
	      # the derivatives index will be empty, and the prestats
	      # module should never enter the conditional block below.
	      ##########################################################
         [[ -e "${auxImgs[${subjidx}]}" ]] \
            && auxImgs=$(cat ${auxImgs[${subjidx}]})
	      for aimg in ${auxImgs}
            do
	         #######################################################
	         # Parse the derivative image.
	         #######################################################
	         aName=$(echo "$aimg"|cut -d'#' -f2)
	         aPath=$(echo "$aimg"|cut -d'#' -f3)
	         #######################################################
	         # * Determine the number of volumes in the derivative
	         #   image.
	         # * If it is identical to the number of volumes in
	         #   the untruncated BOLD timeseries, discard an equal
	         #   number of volumes from the derivative image.
	         #######################################################
	         aVols=$(fslnvols ${aPath})
	         if [[ "${aVols}" == "${nvol}" ]]
	            then
	            echo "Discarding initial volumes from ${aName}"
	            fslroi ${aPath} \
	               ${outdir}/${aName} \
	               ${prestats_dvols[${cxt}]} \
	               $nvol
	            ####################################################
	            # Write information about the updated derivative
	            # image to a local version of the derivatives index.
	            # If volumes have been discarded from the derivative
	            # image, then also update its path in the design
	            # file.
	            ####################################################
               echo "#${aName}#${outdir}/${aName}" \
                  >> ${auxImgs[${cxt}]}
               echo "${aName}"'['"${subjidx}"']='"${outdir}/${aName}"\
                  >> ${design_local}
	         else
               echo "#${aName}#${aPath}" \
                  >> ${auxImgs[${cxt}]}
	         fi
	      done
	      ##########################################################
	      # Overwrite the derivatives index with the paths to the
	      # updated derivatives.
	      ##########################################################
         [[ -e "${auxImgs[${subjidx}]}" ]] \
            && mv ${auxImgs[${cxt}]} ${auxImgs[${subjidx}]}
	      ##########################################################
	      # Compute the updated volume count.
	      ##########################################################
	      img=${img}_${cur}
	      nvol=$(fslnvols $img)
	      echo "New total volumes = $nvol"
	      echo "Processing step complete:"
	      echo "Discarding initial volumes"
         ;;
      
      
      
      
      
      MPR)
         ##########################################################
         # MPR computes motion-related variables, such as
         # realignment parameters and framewise displacement.
         #
         # Prime the analytic pipeline for motion censoring, if
         # the user has requested it.
         #
         # Why is this step separate from motion correction?
         #  * Recent analyses have suggested that correction for
         #    slice timing can introduce error into motion
         #    parameter estimates.
         #  * Therefore, it is desirable to compute realignment
         #    parameters prior to slice timing correction.
         #  * However, slice timing correction should probably be
         #    performed on data that has not undergone realignment,
         #    since realignment will move brain regions into slices
         #    different from the ones in which they were acquired.
         #  * Therefore, the recommended processing order is:
         #    MPR STM MCO
         #
         # This step introduces a degree of redundancy to pipelines
         # that do not include slice timing correction.
         ##########################################################
         echo ""; echo ""; echo ""
         echo "Current processing step:"
         echo "Computing realignment parameters"
         ##########################################################
         # Determine whether a reference functional image already
         # exists. If it does not, extract it from the timeseries
         # midpoint.
         ##########################################################
         if [[ $(imtest ${referenceVolume[${cxt}]}) != "1" ]] \
            || [[ "${prestats_rerun[${cxt}]}" == "Y" ]]
            then
            echo "Extracting reference volume"
            #######################################################
            # Compute the number of volumes...
            #######################################################
            nvol=$(fslnvols $img)
            #######################################################
            # ...then use this to obtain the timeseries midpoint.
            # expr should always return integer values.
            #######################################################
            midpt=$(expr $nvol / 2)
            #######################################################
            # Finally, extract the indicated volume for use as a
            # reference in realignment.
            #######################################################
	         fslroi $img ${referenceVolume[${cxt}]} $midpt 1
	      fi
         ##########################################################
         # Determine whether this step has already completed: if
         # it has, then an associated image symlink should exist.
         ##########################################################
	      if [[ $(imtest ${img}_${cur}) != "1" ]] \
            || [[ "${prestats_rerun[${cxt}]}" == "Y" ]]
            then
            #######################################################
            # Run MCFLIRT targeting the reference volume to compute
            # the realignment parameters.
            #
            # Output is temporarily placed into the main prestats
            # module output directory; it will be moved into the
            # MC directory.
            #######################################################
	         echo "Computing realignment parameters..."
	         mcflirt -in $img \
	            -out ${outdir}/${prefix}~TEMP~_mc \
	            -plots \
	            -reffile ${referenceVolume[${cxt}]} \
	            -rmsrel \
	            -rmsabs \
	            -spline_final
	         #######################################################
	         # Create the MC directory, and move outputs to their
	         # targets.
	         #######################################################
	         rm -rf ${mcdir[${cxt}]}
	         mkdir -p ${mcdir[${cxt}]}
	         mv -f ${outdir}/${prefix}~TEMP~_mc.par \
	            ${rps[${cxt}]}
	         mv -f ${outdir}/${prefix}~TEMP~_mc_abs_mean.rms \
	            ${absmeanrms[${cxt}]}
	         mv -f ${outdir}/${prefix}~TEMP~_mc_abs.rms \
	            ${absrms[${cxt}]}
	         mv -f ${outdir}/${prefix}~TEMP~_mc_rel_mean.rms \
	            ${relmeanrms[${cxt}]}
	         #######################################################
	         # Append relative mean RMS motion to the index of
	         # quality variables
	         #######################################################
	         qvars=${qvars},relMeanRMSmotion
	         qvals="${qvals},$(cat ${relmeanrms[${cxt}]})"
	         #######################################################
	         # For relative root mean square motion, prepend a
	         # value of 0 by convention for the first volume.
	         # FSL may change its pipeline in the future so that
	         # it automatically does this. If this occurs, then
	         # this must be changed.
	         #######################################################
	         #mv -f ${outdir}/${prefix}~TEMP~_mc_rel.rms \
	         #   ${relrms[${cxt}]}
	         rm -f ${relrms[${cxt}]}
	         echo "0" >> ${relrms[${cxt}]}
	         cat "${outdir}/${prefix}~TEMP~_mc_rel.rms" \
	            >> ${relrms[${cxt}]}
	         #######################################################
	         # Generate summary plots for motion correction.
	         #######################################################
	         echo "Preparing summary plots..."
	         echo "1/3"
	         fsl_tsplot -i ${rps[${cxt}]} \
	            -t 'MCFLIRT estimated rotations (radians)' \
	            -u 1 --start=1 --finish=3 \
		         -a x,y,z \
		         -w 640 \
		         -h 144 \
		         -o ${mcdir[${cxt}]}/rot.png
		      echo "2/3"
	         fsl_tsplot -i ${rps[${cxt}]} \
	            -t 'MCFLIRT estimated translations (mm)' \
	            -u 1 --start=4 --finish=6 \
		         -a x,y,z \
		         -w 640 \
		         -h 144 \
		         -o ${mcdir[${cxt}]}/trans.png
		      echo "3/3"
	         fsl_tsplot \
	            -i "${absrms[${cxt}]},${relrms[${cxt}]}" \
	            -t 'MCFLIRT estimated mean displacement (mm)' \
	            -u 1 \
	            -w 640 \
	            -h 144 \
		         -a "absolute,relative" \
		         -o ${mcdir[${cxt}]}/disp.png
	         echo "Realignment parameter plots prepared."
	         #######################################################
	         # Compute framewise displacement using the realignment
	         # parameters.
	         #######################################################
	         echo "Computing framewise displacement..."
	         ${XCPEDIR}/utils/fd.R \
               -r "${rps[${cxt}]}" \
               -o "${fd[${cxt}]}"
	         #######################################################
	         # Determine whether motion censoring is enabled. If it
	         # is, then prepare to create a temporal mask indicating
	         # whether each volume survives censoring.
	         #
	         # Censoring information is stored in a single, comma-
	         # separated variable.
	         #  * The first element indicates the type of censoring:
	         #    none, final (e.g. Power et al., 2012), or
	         #    iterative (e.g., Power et al., 2014).
	         #  * The second element indicates the FD cutoff for
	         #    censoring: volumes with FD above the cutoff do not
	         #    survive censoring.
	         #######################################################
	         censor_type=$(echo ${prestats_censor[${cxt}]}\
	            |cut -d"," -f1)
	         censor_fd=$(echo ${prestats_censor[${cxt}]}\
	            |cut -d"," -f2)
	         #######################################################
	         # Before creating a temporal mask, ensure that
	         # censoring has not already been primed in the course
	         # of this analysis.
	         #  * It is critical that this step only be performed
	         #    once in the course of each analysis.
	         #  * If censoring has already been primed, then the
	         #    type of censoring requested will be stored in one
	         #    of the variables: censor[cxt] or censor[subjidx]
	         #######################################################
	         if [[ ! -z "$censor_type" ]] \
	            && [[ "${censor[${subjidx}]}" != "iter" ]] \
	            && [[ "${censor[${subjidx}]}" != "final" ]] \
	            && [[ "${censor[${cxt}]}" != "iter" ]] \
	            && [[ "${censor[${cxt}]}" != "final" ]]
	            then
	            echo "Determining volumes to be censored..."
	            ####################################################
	            # Create and write the temporal mask.
	            # Use the criterion dimension and threshold
	            # specified by the user to determine whether each
	            # volume should be masked out.
	            ####################################################
	            censor[${cxt}]=$censor_type
	            if [[ ${prestats_censor_cr[${cxt}]} == fd ]]
	               then
	               ${XCPEDIR}/utils/tmask.R \
	                  -s "${fd[${cxt}]}" \
	                  -t "$censor_fd" \
	                  -o "${tmask[${cxt}]}" \
	                  -m ${MINCONTIG} \
	                  -p ${PERSIST}
	            elif [[ ${prestats_censor_cr[${cxt}]} == rms ]]
	               then
	               ${XCPEDIR}/utils/tmask.R \
	                  -s "${relrms[${cxt}]}" \
	                  -t "$censor_fd" \
	                  -o "${tmask[${cxt}]}" \
	                  -m ${MINCONTIG} \
	                  -p ${PERSIST}
	            fi
	         fi
	         #######################################################
	         # Determine the number of volumes that fail the motion
	         # criterion and print this to another QA file.
	         #######################################################
	         echo "Evaluating data quality..."
	         [[ ${prestats_censor_cr[${cxt}]} == fd ]] \
	            && sIn=${fd[${cxt}]}
	         [[ ${prestats_censor_cr[${cxt}]} == rms ]] \
	            && sIn=${relrms[${cxt}]}
	         censor_lim=${censor_fd}
	         [[ ${censor_lim} == none ]] && censor_lim=${MOTIONTHR}
	         num_censor=$(${XCPEDIR}/utils/tmask.R \
	                     -s "${sIn}" \
	                     -t "$censor_lim" \
	                     |grep -o 0 \
	                     |wc -l)
	         echo ${num_censor} >> ${qavol[${cxt}]}
            mthr=$(echo ${prestats_censor[${cxt}]}|cut -d"," -f2)
            [[ ${mthr} == none ]] && mthr=${MOTIONTHR}
	         qvars=${qvars},nframesHighMotion${prestats_censor_cr[${cxt}]}${mthr}
	         qvals="${qvals},$(cat ${qavol[${cxt}]})"
	      fi # run check statement
         ##########################################################
         # * Remove the motion corrected image: this step should
         #   only compute parameters, not use them.
         # * Discard realignment transforms, since they are not
         #   used in this step.
         # * Symlink to the previous image in the chain so that
         #   the final check can verify that this step completed
         #   successfully.
         # * Update the image pointer.
         ##########################################################
	      [[ -e ${img}_${cur}${ext} ]] && rm -f ${img}_${cur}${ext}
	      rm -rf ${outdir}/${prefix}~TEMP~_mc*.mat
	      rm -f ${referenceVolume[${cxt}]}
	      ln -s ${img}${ext} ${img}_${cur}${ext}
	      img=${img}_${cur}
	      echo "Processing step complete:"
	      echo "computing realignment parameters"
         ;;
      
      
      
      
      
      MCO)
         ##########################################################
         # MCO computes the realignment parameters and uses them
         # to realign all volumes to the reference.
         #
         # MPR is intended to be run prior to slice timing
         # correction, and MCO after slice timing correction.
         ##########################################################
         echo ""; echo ""; echo ""
         echo "Current processing step:"
         echo "Correcting for subject motion"
         ##########################################################
         # Determine whether a reference functional image already
         # exists. If it does not, extract it from the timeseries
         # midpoint.
         ##########################################################
         if [[ $(imtest ${referenceVolume[${cxt}]}) != "1" ]] \
            || [[ "${prestats_rerun[${cxt}]}" == "Y" ]]
            then
            echo "Extracting reference volume"
            #######################################################
            # If the framewise displacement has not been
            # calculated, then use the timeseries midpoint as the
            # reference volume.
            #######################################################
            if [[ ! -e ${fd[${cxt}]} ]]
               then
               ####################################################
               # Compute the number of volumes...
               ####################################################
               nvol=$(fslnvols $img)
               ####################################################
               # ...then use this to obtain the timeseries
               # midpoint. expr should always return integer
               # values.
               ####################################################
               midpt=$(expr $nvol / 2)
               ####################################################
               # Finally, extract the indicated volume for use as
               # a reference in realignment.
               ####################################################
	            fslroi $img ${referenceVolume[${cxt}]} $midpt 1
            #######################################################
            # Otherwise, use the volume with minimal framewise
            # displacement.
            #######################################################
	         else
	            nvol=$(cat ${fd[${cxt}]}|wc -l)
	            volmin=2
	            minfd=$(sed -n 2p ${fd[${cxt}]})
               ####################################################
               # Iterate through all volumes; if the FD value at
               # the current volume is less than the minimum
               # observed value so far, it becomes the minimum
               # observed value and the candidate for becoming
               # the reference volume.
               ####################################################
	            for i in $(seq 3 $nvol)
	               do
	               curfd=$(sed -n ${i}p ${fd[${cxt}]})
	               [[ $(echo $curfd'<'$minfd | bc -l) == 1 ]] \
	                  && minfd=${curfd} \
	                  && volmin=${i}
	            done
               ####################################################
               # Extract the volume with minimal FD for use as a
               # reference in realignment.
               ####################################################
	            fslroi $img ${referenceVolume[${cxt}]} $volmin 1
	         fi
	      fi
         ##########################################################
         # Create the motion correction directory if it does not
         # already exist.
         ##########################################################
	      [[ ! -e "${mcdir[${cxt}]}" ]] && mkdir -p ${mcdir[${cxt}]}
         ##########################################################
         # Verify that this step has not already completed; if it
         # has, then an associated image should exist.
         ##########################################################
	      if [[ $(imtest ${img}_${cur}) != "1" ]] \
            || [[ "${prestats_rerun[${cxt}]}" == "Y" ]]
            then
	         echo "Executing motion correction..."
	         mcflirt -in $img \
	            -out ${outdir}/${prefix}~TEMP~_mc \
	            -mats \
	            -reffile ${referenceVolume[${cxt}]} \
	            -spline_final
	      fi # run check statement
         ##########################################################
         # Realignment transforms are always retained from this
         # step and discarded from MPR.
         ##########################################################
	      mv -f ${outdir}/${prefix}~TEMP~_mc*.mat ${rmat[${cxt}]}
         ##########################################################
         # Update image pointer
         ##########################################################
         ln -s ${outdir}/${prefix}~TEMP~_mc${ext} ${img}_${cur}${ext}
	      img=${img}_${cur}
	      echo "Processing step complete: motion correction"
         ;;
      
      
      
      
      
      STM)
         ##########################################################
         # STM corrects images for timing of slice acquisition
         # based upon user input.
         ##########################################################
         echo ""; echo ""; echo ""
         echo "Current processing step:"
         echo "Slice timing correction"
         echo "Acquisition: ${prestats_stime[${cxt}]}"
         echo "Acquisition axis: ${prestats_sdir[${cxt}]}"
         ##########################################################
         # Ensure that this submodule has not already run to
         # completion; if it has, then an associated image should
         # exist.
         ##########################################################
         if [[ ! $(imtest ${img}_${cur}) == "1" ]] \
            || [[ "${prestats_rerun[${cxt}]}" == "Y" ]]
            then
            #######################################################
            # Read in the acquisition axis; translate axes from
            # common names to FSL terminology.
            #######################################################
            case "${prestats_sdir[${cxt}]}" in 
            X)
               sdir=1
               ;;
            Y)
               sdir=2
               ;;
            Z)
               sdir=3
               ;;
            *)
               sdir=3 # set default so as to prevent errors
               echo "Slice timing correction:"
               echo "Unrecognised acquisition axis/direction:"
               echo "${prestats_sdir[${cxt}]}"
               ;;
            esac
            #######################################################
            # Read in the direction of acquisition to determine
            # the order in which slices were acquired.
            #######################################################
            case "${prestats_stime[${cxt}]}" in
            up)
               ####################################################
               # For bottom-up acquisition, slicetimer is called
               # with the default settings.
               ####################################################
               slicetimer \
                  -i $img \
                  -o ${img}_${cur} \
                  -d $sdir
               img=${img}_${cur}
               ;;
            down)
               ####################################################
               # For top-down acquisition, slicetimer is called
               # with the --down flag.
               ####################################################
               slicetimer \
                  -i $img \
                  -o ${img}_${cur} \
                  --down \
                  -d $sdir
               img=${img}_${cur}
               ;;
            interleaved)
               ####################################################
               # For interleaved acquisition, slicetimer is called
               # with the --odd flag.
               ####################################################
               slicetimer \
                  -i $img \
                  -o ${img}_${cur} \
                  --odd \
                  -d $sdir
               img=${img}_${cur}
               ;;
            custom)
               tpath=${prestats_stime_tpath[${cxt}]}
               opath=${prestats_stime_opath[${cxt}]}
               ####################################################
               # If you are using both a custom order file and a
               # custom timing file, then congratulations -- you've
               # broken the pipeline. Just select one.
               #
               # The call is still here, but should it become
               # active, the very fabric of the world will unravel.
               ####################################################
               if [[ "${prestats_stime_order[${cxt}]}" == "true" ]] \
                  && [[ "${prestats_stime_timing[${cxt}]}" == "true" ]]
                  then
                  slicetimer \
                     -i $img \
                     -o ${img}_${cur} \
                     -d $sdir \
                     -ocustom $opath \
                     -tcustom $tpath
                  img=${img}_${cur}
               ####################################################
               # If a custom slice order file is used, call
               # slicetimer with the -ocustom flag pointed at the
               # file.
               ####################################################
               elif [[ "${prestats_stime_order[${cxt}]}" == "true" ]]
                  then
                  slicetimer \
                     -i $img \
                     -o ${img}_${cur} \
                     -d $sdir \
                     -ocustom $opath
                  img=${img}_${cur}
               ####################################################
               # If a custom slice timing file is used, call
               # slicetimer with the -tcustom flag pointed at the
               # file.
               ####################################################
               elif [[ "${prestats_stime_timing[${cxt}]}" == "true" ]]
                  then
                  slicetimer \
                     -i $img \
                     -o ${img}_${cur} \
                     -d $sdir \
                     -tcustom $tpath
                  img=${img}_${cur}
               fi
               ;;
            none)
	            ####################################################
               # Create a symlink to ensure that this step is
               # counted as complete by the final check, even if
               # no slice timing correction has actually been
               # performed.
               #
               # If you are entering this code, you may as well
               # have removed STM from your pipeline. But I sure
               # made that sound quite scary, didn't I?
	            ####################################################
               ln -s ${img}${ext} ${img}_${cur}${ext}
               img=${img}_${cur}
               ;;
            *)
               echo "Slice timing correction:"
               echo "Unrecognised option ${prestats_stime[${cxt}]}"
               ;;
            esac
         ##########################################################
         # If the output of slice timing already exists, then
         # update the image pointer.
         ##########################################################
         else
            img=${img}_${cur}
         fi # run check statement
	      echo "Processing step complete: slice timing correction"
         ;;
      
      
      
      
      
      BXT)
         ##########################################################
         # BXT computes a mask over the whole brain and excludes
         # non-brain voxels from further analyses.
         ##########################################################
         echo ""; echo ""; echo ""
         echo "Current processing step:"
         echo "Brain extraction"
         echo "Fractional intensity threshold ${prestats_fit[${cxt}]}"
	      ##########################################################
         # Generate a mean functional image by averaging voxel
         # intensity over time. This mean functional image will be
         # used as the priamry reference for establishing the
         # boundary between brain and background.
	      ##########################################################
	      fslmaths $img -Tmean ${meanIntensity[${cxt}]}
	      echo "Mean functional image generated"
         ##########################################################
         # Brain extraction proceeds in two passes.
         #  * The first pass uses BET to generate a conservative
         #    estimate of the brain-background boundary.
         #  * The second pass uses fslmaths to dilate the initial
         #    mask, producing a more inclusive brain mask.
         #
         # First, verify that the first pass has not already
         # completed. The first pass writes its output to:
         # ${img}_${cur}_1
         ##########################################################
	      if [[ $(imtest ${img}_${cur}_1) != "1" ]] || \
            [[ "${prestats_rerun[${cxt}]}" == "Y" ]]
            then
	         echo "Initialising brain extraction..."
	         #######################################################
	         # Use BET to generate a preliminary mask. This should
	         # be written out to the mask[cxt] variable.
	         #######################################################
	         bet ${meanIntensity[${cxt}]} \
	            ${outdir}/${prefix} \
	            -f ${prestats_fit[${cxt}]} \
	            -n \
	            -m \
	            -R
	         echo "Binary brain mask generated"
	         immv ${outdir}/${prefix} ${meanIntensityBrain[${cxt}]}
	         #######################################################
	         # Additionally, prepare a brain-extracted version of
	         # the example functional image; this will later be
	         # necessary for coregistration of functional and
	         # structural acquisitions.
	         #######################################################
	         if [[ $(imtest ${referenceVolume[${subjidx}]}) == 1 ]]
	         then
	         bet ${referenceVolume[${subjidx}]} \
	            ${referenceVolumeBrain[${cxt}]} \
	            -f ${prestats_fit[${cxt}]}
	         else
	         bet ${referenceVolume[${cxt}]} \
	            ${referenceVolumeBrain[${cxt}]} \
	            -f ${prestats_fit[${cxt}]}
	         fi
	         #######################################################
	         # Use the preliminary mask to extract brain tissue.
	         #######################################################
	         fslmaths $img -mas ${mask[${cxt}]} ${img}_${cur}_1
	         echo "Brain extraction first pass complete"
	      fi
         ##########################################################
         # Now, verify that the second pass has not already
         # completed. The second pass writes its output to:
         # ${img}_${cur}_2
         ##########################################################
	      if [[ $(imtest ${img}_${cur}_2) != "1" ]] || \
            [[ "${prestats_rerun[${cxt}]}" == "Y" ]]
            then
            echo "Thresholding and dilating image"
            echo "Brain-background threshold:"
            #######################################################
            # Use the user-specified brain-background threshold
            # to determine what parts of the image to count as
            # brain.
            #  * First, compute an image-specific threshold by
            #    multiplying the 98th percentile of image
            #    intensities by the brain-background threshold.
            #  * Next, use this image-specific threshold to obtain
            #    a binary mask from the volume computed in the
            #    first pass.
            #  * Then, dilate the binary mask.
            #  * Finally, use the new, dilated mask for the second
            #    pass of brain extraction.
            #######################################################
            echo "${prestats_bbgthr[${cxt}]}"
	         perc98=$(fslstats $img -p 98)
	         newthr=$(echo $perc98 ${prestats_bbgthr[${cxt}]} \
	            | awk '{printf $1*$2}')
	         fslmaths ${img}_${cur}_1 \
	            -thr $newthr \
	            -Tmin \
	            -bin \
	            ${mask[${cxt}]} \
	            -odt char
	         fslmaths ${mask[${cxt}]} -dilF ${mask[${cxt}]}
	         fslmaths $img -mas ${mask[${cxt}]} ${img}_${cur}_2
	      fi
	      ##########################################################
         # Now that brain extraction is complete, the image is
         # rescaled according to a grand mean.
         #
         # Specifically, the median intensity in the brain voxels
         # is rescaled to a value of 10000.
         #
         # This might not be particularly useful if you are
         # demeaning the data in a later step, but it is retained
         # here, as it was a part of the FSL FEAT processing
         # pipeline.
	      ##########################################################
         if [[ $(imtest ${img}_${cur}) != "1" ]] || \
            [[ "${prestats_rerun[${cxt}]}" == "Y" ]]
            then
	         #######################################################
	         # Use the -k flag to ensure that only brain voxels are
	         # taken into consideration when computing median
	         # intensity.
	         #######################################################
	         perc50=$(fslstats ${img}_${cur}_2 \
	            -k ${mask[${cxt}]} \
	            -p 50)
	         gmscale=$(echo $perc50 | awk '{printf 10000/$1}')
	         gmscale=1
	         fslmaths ${img}_${cur}_2 -mul $gmscale ${img}_${cur}
	      fi
	      ##########################################################
	      # Update the image pointer.
	      ##########################################################
	      img=${img}_${cur}
	      echo "Processing step complete: brain extraction"
         ;;
      
      
      
      
      
      DMT)
         ##########################################################
         # DMT removes the mean from a timeseries and additionally
         # removes polynomial trends up to an order specified by
         # the user.
         #
         # DMT uses a general linear model with y = 1 and all
         # polynomials as predictor variables, then retains the
         # residuals of the model as the processed timeseries.
         ##########################################################
         echo ""; echo ""; echo ""
         echo "Current processing step:"
         echo "Demeaning and detrending BOLD timeseries"
         echo "Polynomial order: ${prestats_dmdt[${cxt}]}"
         ##########################################################
         # Verify that this step has not already run to completion:
         # check for the associated image.
         ##########################################################
         if [[ $(imtest ${img}_${cur}) != "1" ]] \
            || [[ "${prestats_rerun[${cxt}]}" == "Y" ]]
            then
	         #######################################################
            # DMT uses a utility R script called DMDT to compute
            # the linear model residuals using ANTsR and pracma.
            # First, the inputs to DMDT must be obtained.
            # The first of these is the path to the image in its
            # currently processed state.
	         #######################################################
            imgpath=$(ls -d1 ${img}.*)
	         #######################################################
            # Second, a spatial mask of the brain is necessary
            # for ANTsR to read in the image.
            #
            # If this mask was computed in a previous run or as
            # part of BXT above, then that mask can be used in
            # this step.
	         #######################################################
            if [[ $(imtest ${mask[${subjidx}]}) == "1" ]]
               then
               echo "Using previously determined mask"
               maskpath=$(ls -d1 ${mask[${subjidx}]}.*)
            elif [[ $(imtest ${mask[${cxt}]}) == "1" ]]
               then
               echo "Using mask from this preprocessing run"
               maskpath=$(ls -d1 ${mask[${cxt}]}.*)
	         #######################################################
	         # If no mask has yet been computed for the subject,
	         # then a new mask can be computed quickly using
	         # AFNI's 3dAutomask tool.
	         #######################################################
            else
               echo "Unable to locate mask."
               echo "Generating a mask using 3dAutomask"
               3dAutomask -prefix ${img}_fmask${ext} \
                  -dilate 3 \
                  -q \
                  ${img}${ext}
               maskpath=${img}_fmask${ext}
            fi
	         #######################################################
	         # If the user has requested iterative censoring of
	         # motion-corrupted volumes, then the demean/detrend
	         # step should exclude the corrupted volumes from the
	         # linear model. In this case, a temporal mask is
	         # required for the demean/detrend step.
	         #
            # If motion correction was run for the first time
            # during this module, then the censoring requested by
            # the user should be defined in censor[cxt]. If it is
            # not, then set it to the global subject value.
	         #######################################################
            if [[ -z "${censor[${cxt}]}" ]]
               then
               censor[${cxt}]=${censor[${subjidx}]}
            fi
	         #######################################################
	         # The temporal mask must be stored either in the
	         # module-specific censor[cxt] variable or in the
	         # subject-specific censor[subjidx] variable.
	         #######################################################
            if [[ ! -z "${tmask[${cxt}]}" ]] \
               && [[ "${censor[${cxt}]}" == "iter" ]]
               then
               tmaskpath=$(ls -d1 ${tmask[${cxt}]})
            elif [[ ! -z "${tmask[${subjidx}]}" ]] \
               && [[ "${censor[${cxt}]}" == "iter" ]]
               then
               tmaskpath=$(ls -d1 ${tmask[${subjidx}]})
            else
	            ####################################################
               # If iterative censoring has not been specified or
               # if no temporal mask exists yet, then all time
               # points must be used in the linear model.
	            ####################################################
               tmaskpath=ones
            fi
	         #######################################################
	         # AFNI's afni_proc.py pipeline uses a formula to
	         # automatically determine an appropriate order of
	         # polynomial detrend to apply to the data.
	         #
	         #        floor(1 + TR*nVOLS / 150)
	         #
	         # In summary, the detrend order is based upon the
	         # overall duration of the scan. If the user has
	         # requested automatic determination of detrend order,
	         # then it is computed here. Note that there are a
	         # number of assumptions in this computation, and it
	         # may not always be appropriate.
	         #######################################################
	         if [[ "${prestats_dmdt[${cxt}]}" == "auto" ]]
	            then
	            nvol=$(fslnvols $img)
               trep=$(fslinfo $img \
                  |grep pixdim4 \
                  |awk '{print $2}' )
               prestats_dmdt[${cxt}]=$(echo $trep $nvol \
                  |awk '{print 1 + $1 * $2 / 150}' \
                  |cut -d"." -f1)
               echo "Automatically determined a"
               echo "   polynomial order of ${prestats_dmdt[${cxt}]}"
	         fi
	         #######################################################
	         # Now, pass the inputs computed above to the detrend
	         # function itself.
	         #######################################################
            echo "Applying polynomial detrend"
            3dDetrend -prefix "${img}_${cur}${ext}" -polort "${prestats_dmdt[${cxt}]}" "${imgpath}"
         fi
	      ##########################################################
	      # Update image pointer
	      ##########################################################
         img=${img}_${cur}
	      echo "Processing step complete: demeaning/detrending"
         ;;
      
      
      
      
      
      DSP)
	      ##########################################################
	      # DSP uses AFNI's 3dDespike to remove any intensity
	      # outliers ("spikes") from the BOLD timeseries and to
	      # interpolate over outlier epochs.
	      ##########################################################
         echo ""; echo ""; echo ""
         echo "Current processing step:"
         echo "Despiking BOLD timeseries"
	      ##########################################################
	      # First, verify that this step has not already run to
	      # completion by searching for expected output.
	      ##########################################################
         if [[ $(imtest ${img}_${cur}) != "1" ]] \
            || [[ "${prestats_rerun[${cxt}]}" == "Y" ]]
            then
            rm -rf ${img}_${cur}${ext} #AFNI will not overwrite
	         #######################################################
            # Determine whether to run new or old 3dDespike.
            # This is based on the number of volumes.
            # If the timeseries has more than 200 volumes,
            # the old method will be incredibly slow, so the
            # new method should be run.
	         #######################################################
            nvol=$(fslnvols $img)
	         #######################################################
            # need extension to work with AFNI; will otherwise
            # default to brickheads
	         #######################################################
            if [[ "$nvol" -ge "200" ]]
               then
               3dDespike \
                  -prefix ${img}_${cur}${ext} \
                  -nomask \
                  -quiet \
                  -NEW \
                  ${img}${ext} \
                  > /dev/null
            else
               3dDespike \
                  -prefix ${img}_${cur}${ext} \
                  -nomask \
                  -quiet \
                  ${img}${ext} \
                  > /dev/null
            fi
         fi
	      ##########################################################
	      # Update image pointer
	      ##########################################################
         img=${img}_${cur}
	      echo "Processing step complete: despiking timeseries"
         ;;
      
      
      
      
      
      SPT)
	      ##########################################################
	      # SPT applies a smoothing kernel to the image. It calls
	      # the utility script sfilter, which is also used by a
	      # number of other modules.
	      ##########################################################
         echo ""; echo ""; echo ""
         echo "Current processing step:"
         echo "Spatially filtering image"
         echo "Filter: ${prestats_sptf[${cxt}]}"
         echo "Smoothing kernel: ${prestats_smo[${cxt}]} mm"
	      ##########################################################
	      # If no spatial filtering has been specified by the user,
	      # then bypass this step.
	      ##########################################################
	      if [[ ${prestats_sptf[${cxt}]} == none ]]
	         then
	         ln -s ${img}${ext} ${img}_${cur}${ext}
	      ##########################################################
	      # Ensure that this step has not already run to completion
	      # by checking for the existence of a smoothed image.
	      ##########################################################
         elif [[ $(imtest ${img}_${cur}) != "1" ]] \
            || [[ "${prestats_rerun[${cxt}]}" == "Y" ]]
            then
	         #######################################################
	         # Obtain the mask over which smoothing is to be applied
	         # Begin by searching for the subject mask; if this does
	         # not exist, then search for a mask created by this
	         # module.
	         #######################################################
            if [[ $(imtest ${mask[${subjidx}]}) == "1" ]]
               then
               mask=${mask[${subjidx}]}
            elif [[ $(imtest ${mask[${cxt}]}) == "1" ]]
               then
               mask=${mask[${cxt}]}
	         #######################################################
	         # If prestats fails to find a mask, then generate one
	         # using AFNI's 3dAutomask utility. This may not work
	         # particularly well if the BOLD timeseries has already
	         # been demeaned or detrended.
	         #######################################################
            else
               echo "Unable to locate mask."
               echo "Generating a mask using 3dAutomask"
               imgpath=$(ls -d1 ${img}.*)
               ext=$(echo $imgpath|sed "s@$img@@")
               3dAutomask -prefix ${img}_fmask${ext} \
                  -dilate 3 \
                  -q \
                  ${img}${ext}
               susanmask=${img}_fmask${ext}
            fi
	         #######################################################
	         # Prime the inputs to sfilter for SUSAN filtering
	         #######################################################
            if [[ "${prestats_sptf[${cxt}]}" == susan ]]
               then
	            ####################################################
	            # Ensure that an example functional image exists.
	            #  * If it does not, then you are probably doing
	            #    something stupid.
	            #  * In this case, force a switch to uniform
	            #    smoothing to mitigate the catastrophe.
	            ####################################################
	            if [[ $(imtest ${referenceVolumeBrain[${subjidx}]}) == 1 ]]
                  then
                  usan="-u ${referenceVolumeBrain[${subjidx}]}"
	            elif [[ $(imtest ${referenceVolumeBrain[${cxt}]}) == 1 ]]
                  then
                  usan="-u ${referenceVolumeBrain[${cxt}]}"
	            elif [[ $(imtest ${referenceVolume[${subjidx}]}) == 1 ]]
                  then
                  usan="-u ${referenceVolume[${subjidx}]}"
               elif [[ $(imtest ${referenceVolume[${cxt}]}) == 1 ]]
                  then
                  usan="-u ${referenceVolume[${cxt}]}"
               else
                  ${prestats_sptf[${cxt}]}=uniform
                  echo "prestats_sptf[${cxt}]=${prestats_sptf[${cxt}]}" \
                     >> ${design_local}
               fi
            fi
	         #######################################################
	         # If the user has requested command tracing, propagate
	         # that request into the sfilter routine.
	         #######################################################
	         [[ ${trace} == 1 ]] && trace_prop="-t"
	         #######################################################
	         # Engage the sfilter routine to filter the image.
	         #  * This is essentially a wrapper around the three
	         #    implemented smoothing routines: gaussian, susan,
	         #    and uniform.
	         #######################################################
	         ${XCPEDIR}/utils/sfilter \
	            -i ${img} \
	            -o ${img}_${cur} \
	            -s ${prestats_sptf[${cxt}]} \
	            -k ${prestats_smo[${cxt}]} \
	            -m ${mask} \
	            ${usan} \
	            ${trace_prop}
	      fi
	      ##########################################################
	      # Update image pointer
	      ##########################################################
         img=${img}_${cur}
	      echo "Processing step complete: spatial filtering"
	      ;;
      
      
      
      
      
      TMP)
	      ##########################################################
	      # TMP applies a temporal filter to:
	      #  * the 4D BOLD timeseries
	      #  * any derivative images that have the same number of
	      #    volumes as the 4D timeseries
	      #  * any 1D timeseries that might function as potential
	      #    regressors: for instance, realignment parameters
	      # TMP makes use of the utility function tfilter, which
	      # itself calls fslmaths, 3dBandpass, or the R script
	      # genfilter to enable a wide array of filters.
	      ##########################################################
         echo ""; echo ""; echo ""
         echo "Current processing step:"
         echo "Temporally filtering image"
         echo "${prestats_tmpf[${cxt}]} filter"
         echo "High pass frequency: ${prestats_hipass[${cxt}]}"
         echo "Low pass frequency: ${prestats_lopass[${cxt}]}"
         
	      ##########################################################
	      # If no temporal filtering has been specified by the user,
	      # then bypass this step.
	      ##########################################################
	      if [[ ${prestats_tmpf[${cxt}]} == none ]]
	         then
	         ln -s ${img}${ext} ${img}_${cur}${ext}
	      ##########################################################
	      # Ensure that this step has not already run to completion
	      # by checking for the existence of a filtered image.
	      ##########################################################
         elif [[ $(imtest ${img}_${cur}) != "1" ]] \
            || [[ "${prestats_rerun[${cxt}]}" == "Y" ]]
            then
	         #######################################################
	         # OBTAIN MASKS: SPATIAL
	         # Obtain the spatial mask over which filtering is to be
	         # applied. Begin by searching for the subject mask; if
	         # this does not exist, then search for a mask created
	         # by this module.
	         #######################################################
            if [[ $(imtest ${mask[${subjidx}]}) == "1" ]]
               then
               mask="-m ${mask[${subjidx}]}"
            elif [[ $(imtest ${mask[${cxt}]}) == "1" ]]
               then
               mask="-m ${mask[${cxt}]}"
	         #######################################################
	         # If prestats fails to find a mask, then prepare to
	         # call tfilter without a mask argument.
	         #######################################################
            else
               mask=""
            fi
	         #######################################################
	         # OBTAIN MASKS: TEMPORAL
	         # Obtain the path to the temporal mask over which
	         # filtering is to be executed. Begin by searching for
	         # the subject mask; if this does not exist, then
	         # search for a mask created by this module.
	         #######################################################
	         censor_type=none
            if [[ -e "${tmask[${subjidx}]}" ]]
               then
               tmaskpath=$(ls -d1 ${tmask[${subjidx}]})
               censor_type=${censor[${subjidx}]}
	         elif [[ -e "${tmask[${cxt}]}" ]]
               then
               tmaskpath=$(ls -d1 ${tmask[${cxt}]})
               censor_type=${censor[${cxt}]}
            else
               tmaskpath=ones
            fi
	         #######################################################
	         # Next, determine whether the user has enabled
	         # censoring of high-motion volumes.
	         #  * If iterative censoring is enabled, the temporal
	         #    mask should be passed to tfilter with the -n
	         #    flag. This will enable interpolation over volumes
	         #    corrupted by motion.
	         #  * If final censoring is enabled, the temporal mask
	         #    should be passed to tfilter with the -k flag.
	         #    This will ensure that volumes discarded from
	         #    the BOLD timeseries are also discarded from the
	         #    temporal mask, but will not interpolate over
	         #    censored volumes.
	         #  * If censoring is enabled, but no temporal mask
	         #    exists yet, no additional argument is passed
	         #    to tfilter. This is functionally identical to
	         #    final censoring.
	         #  * If censoring is disabled, no additional argument
	         #    is passed to tfilter.
	         #######################################################
	         if [[ "${censor_type}" == "iter" ]] \
	            && [[ ${tmaskpath} != ones ]]
	            then
	            tmask="-n ${tmaskpath}"
	         elif [[ "${censor_type}" == "final" ]] \
	            && [[ ${tmaskpath} != ones ]]
	            then
	            tmask="-k ${tmaskpath}"
	         else
	            tmask=""
	         fi
	         #######################################################
	         # DERIVATIVE IMAGES AND TIMESERIES
	         # Prime the index of derivative images, as well as
	         # any 1D timeseries (e.g. realignment parameters)
	         # that should be filtered so that they can be used in
	         # linear models without reintroducing the frequencies
	         # removed from the BOLD timeseries.
	         #######################################################
	         derivs=""
	         ts1d=""
	         [[ -e ${auxImgs[${subjidx}]} ]] \
	            && derivs="-x ${auxImgs[${subjidx}]}"
	         #######################################################
	         # Realignment parameters...
	         #######################################################
	         if [[ -e ${rps[${subjidx}]} ]]
	            then
	            ts1d="${ts1d} ${rps[${subjidx}]}"
	         elif  [[ -e ${rps[${cxt}]} ]]
	            then
	            ts1d="${ts1d} ${rps[${cxt}]}"
	         fi
	         #######################################################
	         # Relative RMS motion...
	         #######################################################
	         if [[ -e ${relrms[${subjidx}]} ]]
	            then
	            ts1d="${ts1d} ${relrms[${subjidx}]}"
	         elif  [[ -e ${relrms[${cxt}]} ]]
	            then
	            ts1d="${ts1d} ${relrms[${cxt}]}"
	         fi
	         #######################################################
	         # Absolute RMS motion...
	         #######################################################
	         if [[ -e ${absrms[${subjidx}]} ]]
	            then
	            ts1d="${ts1d} ${absrms[${subjidx}]}"
	         elif  [[ -e ${absrms[${cxt}]} ]]
	            then
	            ts1d="${ts1d} ${absrms[${cxt}]}"
	         fi
	         #######################################################
	         # Replace any whitespace characters in the 1D
	         # timeseries list with commas, and prepend the -l flag
	         # for input as an argument to tfilter
	         #######################################################
	         ts1d=$(echo ${ts1d}|sed s@' '@','@g)
	         [[ ! -z ${ts1d} ]] && ts1d="-1 ${ts1d}"
	         #######################################################
	         # FILTER-SPECIFIC ARGUMENTS
	         # Next, set arguments specific to each filter class.
	         #######################################################
	         tforder=""
	         tfdirec=""
	         tfprip=""
	         tfsrip=""
	         case ${prestats_tmpf[${cxt}]} in
	         butterworth)
	            tforder="-r ${prestats_tmpf_order[${cxt}]}"
	            tfdirec="-d ${prestats_tmpf_pass[${cxt}]}"
	            ;;
	         chebyshev1)
	            tforder="-r ${prestats_tmpf_order[${cxt}]}"
	            tfdirec="-d ${prestats_tmpf_pass[${cxt}]}"
	            tfprip="-p ${prestats_tmpf_ripple[${cxt}]}"
	            ;;
	         chebyshev2)
	            tforder="-r ${prestats_tmpf_order[${cxt}]}"
	            tfdirec="-d ${prestats_tmpf_pass[${cxt}]}"
	            tfsrip="-s ${prestats_tmpf_ripple2[${cxt}]}"
	            ;;
	         elliptic)
	            tforder="-r ${prestats_tmpf_order[${cxt}]}"
	            tfdirec="-d ${prestats_tmpf_pass[${cxt}]}"
	            tfprip="-p ${prestats_tmpf_ripple[${cxt}]}"
	            tfsrip="-s ${prestats_tmpf_ripple2[${cxt}]}"
	            ;;
	         esac
	         #######################################################
	         # If the user has requested discarding of initial
	         # and/or final volumes from the filtered timeseries,
	         # the request should be passed to tfilter.
	         #######################################################
	         tfdvol=""
	         [[ ! -z ${prestats_tmpf_dvols[${cxt}]} ]] \
	            && tfdvol="-v ${prestats_tmpf_dvols[${cxt}]}"
	         #######################################################
	         # If the user has requested command tracing, propagate
	         # that request into the tfilter routine.
	         #######################################################
	         [[ ${trace} == 1 ]] && trace_prop="-t"
	         #######################################################
	         # Engage the tfilter routine to filter the image.
	         #  * This is essentially a wrapper around the three
	         #    implemented filtering routines: fslmaths,
	         #    3dBandpass, and genfilter
	         #######################################################
	         ${XCPEDIR}/utils/tfilter \
	            -i ${img} \
	            -o ${img}_${cur} \
	            -f ${prestats_tmpf[${cxt}]} \
	            -h ${prestats_hipass[${cxt}]} \
	            -l ${prestats_lopass[${cxt}]} \
	            ${mask} \
	            ${tmask} \
	            ${tforder} \
	            ${tfdirec} \
	            ${tfprip} \
	            ${tfsrip} \
	            ${tfdvol} \
	            ${derivs} \
	            ${ts1d} \
	            ${trace_prop}
	         #######################################################
	         # Move outputs to target
	         #######################################################
	         [[ -e ${img}_${cur}_realignment.1D ]] \
	            && mv -f ${img}_${cur}_${prefix}_realignment.1D \
	            ${rps[${cxt}]}
	         [[ -e ${img}_${cur}_abs_rms.1D ]] \
	            && mv -f ${img}_${cur}_${prefix}_abs_rms.1D \
	            ${absrms[${cxt}]}
	         [[ -e ${img}_${cur}_rel_rms.1D ]] \
	            && mv -f ${img}_${cur}_${prefix}_rel_rms.1D \
	            ${relrms[${cxt}]}
	         [[ -e ${img}_${cur}_tmask.1D ]] \
	            && mv -f ${img}_${cur}_tmask.1D ${tmask[${cxt}]}
	         [[ -e ${img}_${cur}_derivs ]] \
	            && mv -f ${img}_${cur}_derivs ${auxImgs[${subjidx}]}
         fi
	      ##########################################################
	      # Update image pointer
	      ##########################################################
         img=${img}_${cur}
	      echo "Processing step complete: temporal filtering"
         ;;
      
      *)
         echo "Invalid option detected: ${cur}"
         ;;
         
   esac
done





################################################################### 
# Write any remaining output paths to local design file so that
# they may be used further along the pipeline.
################################################################### 
echo ""; echo ""; echo ""
echo "Writing outputs..."
###################################################################
# OUTPUT: meanIntensity
# Test whether the mean of functional volumes exists as an
# image. If it does, add it to the index of derivatives and to
# the localised design file.
###################################################################
if [[ $(imtest ${meanIntensity[${cxt}]}) == "1" ]]
   then
   echo "#meanIntensity#${meanIntensity[${cxt}]}" \
      >> ${auxImgs[${subjidx}]}
   echo "meanIntensity[${subjidx}]=${meanIntensity[${cxt}]}" \
      >> $design_local
fi
###################################################################
# OUTPUT: referenceVolume
# Test whether an example functional volume exists as an
# image. If it does, add it to the index of derivatives and to
# the localised design file.
###################################################################
if [[ $(imtest ${referenceVolume[${cxt}]}) == "1" ]]
   then
   echo "referenceVolume[${subjidx}]=${referenceVolume[${cxt}]}" \
      >> $design_local
   echo "#referenceVolume#${referenceVolume[${cxt}]}" \
      >> ${auxImgs[${subjidx}]}
fi
###################################################################
# OUTPUT: brain-extracted referenceVolume and meanIntensity
# Test whether brain-extracted mean or example functional volume
# exist. If either does, add it to the index of derivatives and
# to the localised design file.
###################################################################
if [[ $(imtest ${referenceVolumeBrain[${cxt}]}) == "1" ]]
   then
   echo "referenceVolumeBrain[${subjidx}]=${referenceVolumeBrain[${cxt}]}" \
      >> $design_local
   echo "#referenceVolumeBrain#${referenceVolumeBrain[${cxt}]}" \
      >> ${auxImgs[${subjidx}]}
fi
if [[ $(imtest ${meanIntensityBrain[${cxt}]}) == "1" ]]
   then
   echo "meanIntensityBrain[${subjidx}]=${meanIntensityBrain[${cxt}]}" \
      >> $design_local
   echo "#meanIntensityBrain#${meanIntensityBrain[${cxt}]}" \
      >> ${auxImgs[${subjidx}]}
fi
###################################################################
# OUTPUT: mask
# Test whether a binary mask denoting brain voxels exists as an
# image. If it does, add it to the index of derivatives and to
# the localised design file.
###################################################################
if [[ $(imtest ${mask[${cxt}]}) == "1" ]]
   then
   echo "mask[${subjidx}]=${mask[${cxt}]}" >> $design_local
   echo "#mask#${mask[${cxt}]}" >> ${auxImgs[${subjidx}]}
fi
###################################################################
# OUTPUT: mcdir
# Test whether the motion-correction directory exists. If it
# does, add it to the localised design file. Then, search for
# other motion-related variables.
###################################################################
if [[ -d "${mcdir[${cxt}]}" ]]
   then
   echo "mcdir[${subjidx}]=${mcdir[${cxt}]}" >> $design_local
   ################################################################
   # OUTPUT: rps, relrms
   # Realignment parameters may exist either in a filtered or
   # in an unfiltered state. Under any circumstances, they
   # should exist at the output specified above.
   ################################################################
   if [[ -e "${rps[${cxt}]}" ]]
      then
      echo "rps[${subjidx}]=${rps[${cxt}]}" >> $design_local
      echo "relrms[${subjidx}]=${relrms[${cxt}]}" >> \
         $design_local
   fi
   ################################################################
   # OUTPUT: fd, tmask, censor
   # Volumes to be censored should only be determined once in
   # the course of an analysis. If, for some unknown reason,
   # you run motion correction multiple times, only the first
   # time will produce censorship variables.
   ################################################################
   if [[ -z "${censor[${subjidx}]}" ]]
      then
      #############################################################
      # Even if no censorship is being performed, framewise
      # displacement is computed and written to the design
      # file. It may be used for QA purposes, etc.
      #############################################################
      echo "fd[${subjidx}]=${fd[${cxt}]}" >> $design_local
      echo "motionvols[${subjidx}]=${qavol[${cxt}]}" >> $design_local
      #############################################################
      # If the user has requested censorship of volumes on
      # the basis of subject motion, a temporal mask is
      # written to the design file. In the REGRESS module,
      # this mask will determine what volumes to take into
      # account when estimating linear model parameters.
      # Furthermore, volumes with 0 values are discarded from
      # the timeseries.
      #############################################################
      if [[ "${prestats_censor[${cxt}]}" != "none" ]]
         then
         echo "tmask[${subjidx}]=${tmask[${cxt}]}" >> \
            $design_local
         echo "censor[${subjidx}]=${censor[${cxt}]}" >> \
            $design_local
      #############################################################
      # If the user has not requested censorship, then only
      # the censorship status is written to the design file.
      # This prevents future runs of prestats from
      # overwriting framewise displacement and censorship-
      # related variables.
      #############################################################
      else
         echo "censor[${subjidx}]=none" >> $design_local
      fi
	fi
fi





###################################################################
# CLEANUP
#  * Test for the expected output. This should be the initial
#    image name with any subroutine suffixes appended.
#  * If the expected output is present, move it to the target path.
#  * Remove any temporary files if cleanup is enabled.
#  * Update the audit file to reflect successful completion of the
#    module.
#  * If the expected output is absent, notify the user.
###################################################################
img=$(readlink -f ${img}${ext})
if [[ "${prestats_cleanup[${cxt}]}" == "Y" ]] \
   && [[ $(imtest ${outdir}/${prefix}~TEMP~${buffer}) == "1" ]]
   then
   echo ""; echo ""; echo ""
   echo "Cleaning up..."
   rm -f ${out}/${prefix}${ext}
   immv ${img} ${final[${cxt}]}
   ln -s ${final[${cxt}]}${ext} ${out}/${prefix}${ext}
   rm -rf ${outdir}/*~TEMP~*
   ################################################################
   # Update audit file and quality index
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
elif [[ $(imtest ${outdir}/${prefix}~TEMP~${buffer}) == "1" ]]
   then
   rm -f ${out}/${prefix}${ext}
   immv ${img} ${final[${cxt}]}
   ln -s ${final[${cxt}]}${ext} ${out}/${prefix}${ext}
   ################################################################
   # Update audit file and quality index
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
else
   rm -f ${quality}
   echo ${qvars} >> ${quality}
   echo ${qvals} >> ${quality}
   rm -f ${out}/${prefix}${ext}
   ln -s ${img} ${out}/${prefix}${ext}
   echo "Expected: ${outdir}/${prefix}${buffer}"
   echo "Expected output not present."
   echo "Check the log to verify that processing"
   echo "completed as intended."
   exit 1
fi

echo "Module complete"
