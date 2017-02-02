#!/usr/bin/env bash

###################################################################
#  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  #
###################################################################

###################################################################
# This module essentially wraps the functionality of prestats,
# coreg, confound, and regress into a single package. It is less
# customisable than the four separated modules (it enforces the
# BBL's internal denoising regime) but should be easier to
# configure and use.
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
echo "#  ☭                 EXECUTING DENOISE MODULE                  ☭  #"
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
outdir=${out}/${prep}denoise
[[ ! -e ${outdir} ]] && mkdir -p ${outdir}
echo "Output directory is $outdir"
###################################################################
# Define paths to all potential outputs.
#
# For the denoising module, potential outputs include:
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

#  * seq2struct : Affine coregistration whose application to the
#    subject's reference volume will output a reference volume
#    that is aligned with the subject's structural acquisition
#  * struct2seq : Affine coregistration whose application to the
#    subject's structural image will output a structural image
#    that is aligned with the subject's reference acquisition
#  * Also included are the structural and analyte images warped
#    into one another's spaces, as well as the binarised versions
#    of those images (used as masks for quality control)
#  * quality : A comma-delimited list of coregistration quality
#    variables

#  * gmmask : The final extracted, eroded, and transformed grey
#    matter mask in subject functional space. Use to ensure
#    quality.
#  * wmmask : The final extracted, eroded, and transformed white
#    matter mask in subject functional space. Use to ensure
#    quality.
#  * csfmask : The final extracted, eroded, and transformed
#    cerebrospinal fluid mask in subject functional space. Use to
#    ensure quality.
#  * confmat : A 1D file containing all global nuisance timeseries
#    for the current subject, including any user-specified
#    timeseries and previous time points, derivatives, and powers.
#  * While a confound matrix file does not exist at the target
#    path, confmat will store the string 'null' for the purposes
#    of the mbind utility. As mbind is updated, this may change.

#  * auxImgs : A path to an index of derivative images, after they
#    have been processed by this module; this incorporates the
#    effects of any temporal filtering or volume censoring.
#    (NO LONGER NEEDED, BUT MAY BE BROUGHT BACK)
#  * confmat : The confound matrix following filtering and
#    censoring.
#  * confcor : A matrix of correlations among confound variables.
#  * qavol : A quality control file specifying the number of
#    volumes censored.
#  * final : The final output of the module, indicating its
#    successful completion.

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
qavol[${cxt}]=${outdir}/mc/${prefix}_${denoise_censor_cr[${cxt}]}_nvolFailQA.txt
mask[${cxt}]=${outdir}/${prefix}_mask
auxImgs[${cxt}]=${outdir}/${prefix}_derivs
preproc[${cxt}]=${outdir}/${prefix}_preprocessed

seq2struct[${cxt}]=${outdir}/${prefix}_seq2struct.txt
struct2seq[${cxt}]=${outdir}/${prefix}_struct2seq.txt
e2smat[${cxt}]=${outdir}/${prefix}_seq2struct.mat
s2emat[${cxt}]=${outdir}/${prefix}_struct2seq.mat
e2simg[${cxt}]=${outdir}/${prefix}_seq2struct
s2eimg[${cxt}]=${outdir}/${prefix}_struct2seq
e2smask[${cxt}]=${outdir}/${prefix}_seq2structMask
s2emask[${cxt}]=${outdir}/${prefix}_struct2seqMask
quality[${cxt}]=${outdir}/${prefix}_coregQuality.csv

gmMask[${cxt}]=${outdir}/${prefix}_maskGM
wmMask[${cxt}]=${outdir}/${prefix}_maskWM
csfMask[${cxt}]=${outdir}/${prefix}_maskCSF
confmat_path=${outdir}/${prefix}_confmat.1D
confmat[${cxt}]=null

confmat[${cxt}]=${outdir}/${prefix}_confmatFiltered.1D
confcor[${cxt}]=${outdir}/${prefix}_confcor.txt
qavol[${cxt}]=${outdir}/${prefix}_nvolCensored.txt
final[${cxt}]=${outdir}/${prefix}_residualised

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
   || [ "${denoise_rerun[${cxt}]}" == "Y" ]
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
echo "# *** outputs from denoise[${cxt}] *** #" >> $design_local
echo "" >> $design_local
###################################################################
# Verify that the module should be run:
#  * Test whether the final output already exists.
#  * Determine whether the user requested the module to be re-run.
# If it is determined that the module should not be run, then any
#  outputs must be written to the local design file.
###################################################################





















###################################################################
###################################################################
# END GENERAL MODULE HEADER
###################################################################
###################################################################





###################################################################
# Discard the first n volumes of the scan, as specified by user
# input.
###################################################################
cur=DVO
echo ""; echo ""; echo ""
echo "Current processing step:"
echo "Discarding ${denoise_dvols[${cxt}]} volumes"
###################################################################
# Determine whether this has already been done, and 
# compute the number of volumes to retain.
###################################################################
if [[ ! $(imtest ${preproc[${cxt}]}) == "1" ]] \
   || [[ "${denoise_rerun[${cxt}]}" == "Y" ]]
   then
   nvol=$(fslnvols $img)
   echo "Total original volumes = $nvol"
   ################################################################
   # If dvols is positive, discard the first n volumes
   # from the BOLD timeseries.
   ################################################################
   if [[ ${prestats_dvols[${cxt}]} =~ ${POSINT} ]]
      then
      fslroi $img \
      ${img}_${cur} \
      ${prestats_dvols[${cxt}]} \
      $(expr $nvol - ${prestats_dvols[${cxt}]})
      echo "First ${prestats_dvols[${cxt}]} volumes discarded"
   ################################################################
   # If dvols is negative, discard the last n volumes
   # from the BOLD timeseries.
   ################################################################
   else
      fslroi $img \
         ${img}_${cur} \
         0 \
         $(expr $nvol + ${prestats_dvols[${cxt}]})
      echo "Last ${prestats_dvols[${cxt}]} volumes discarded"
   fi
fi
img=${img}_${cur}
nvol=$(fslnvols $img)
echo "New total volumes = $nvol"
echo "Processing step complete:"
echo "Discarding initial volumes"





###################################################################
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
###################################################################
cur=MPR
echo ""; echo ""; echo ""
echo "Current processing step:"
echo "Computing realignment parameters"
###################################################################
# Determine whether a reference functional image already
# exists. If it does not, extract it from the timeseries
# midpoint.
###################################################################
if [[ $(imtest ${referenceVolume[${cxt}]}) != "1" ]] \
   || [[ "${denoise_rerun[${cxt}]}" == "Y" ]]
   then
   echo "Extracting reference volume"
   ################################################################
   # Compute the number of volumes...
   ################################################################
   nvol=$(fslnvols $img)
   ################################################################
   # ...then use this to obtain the timeseries midpoint.
   # expr should always return integer values.
   ################################################################
   midpt=$(expr $nvol / 2)
   ################################################################
   # Finally, extract the indicated volume for use as a
   # reference in realignment.
   ################################################################
	fslroi $img ${referenceVolume[${cxt}]} $midpt 1
fi
###################################################################
# Determine whether this step has already completed: if
# it has, then an associated image symlink should exist.
###################################################################
if [[ $(imtest ${preproc[${cxt}]}) != "1" ]] \
   || [[ "${prestats_rerun[${cxt}]}" == "Y" ]]
   then
   ################################################################
   # Run MCFLIRT targeting the reference volume to compute
   # the realignment parameters.
   #
   # Output is temporarily placed into the main prestats
   # module output directory; it will be moved into the
   # MC directory.
   ################################################################
	echo "Computing realignment parameters..."
	mcflirt -in $img \
	   -out ${outdir}/${prefix}~TEMP~_mc \
	   -plots \
	   -reffile ${referenceVolume[${cxt}]} \
	   -rmsrel \
	   -rmsabs \
	   -spline_final
   ################################################################
	# Create the MC directory, and move outputs to their
	# targets.
   ################################################################
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
   ################################################################
	# Append relative mean RMS motion to the index of
	# quality variables
   ################################################################
	qvars=${qvars},relMeanRMSmotion
	qvals="${qvals},$(cat ${relmeanrms[${cxt}]})"
   ################################################################
   # For relative root mean square motion, prepend a
   # value of 0 by convention for the first volume.
   # FSL may change its pipeline in the future so that
	# it automatically does this. If this occurs, then
	# this must be changed.
   ################################################################
	#mv -f ${outdir}/${prefix}~TEMP~_mc_rel.rms \
	#   ${relrms[${cxt}]}
	rm -f ${relrms[${cxt}]}
	echo "0" >> ${relrms[${cxt}]}
	cat "${outdir}/${prefix}~TEMP~_mc_rel.rms" \
	   >> ${relrms[${cxt}]}
   ################################################################
	# Generate summary plots for motion correction.
   ################################################################
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
   ################################################################
	# Compute framewise displacement using the realignment
	# parameters.
   ################################################################
	echo "Computing framewise displacement..."
	${XCPEDIR}/utils/fd.R \
      -r "${rps[${cxt}]}" \
      -o "${fd[${cxt}]}"
   ################################################################
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
   ################################################################
	censor_type=$(echo ${prestats_censor[${cxt}]}\
	   |cut -d"," -f1)
	censor_fd=$(echo ${prestats_censor[${cxt}]}\
	   |cut -d"," -f2)
   ################################################################
	# Before creating a temporal mask, ensure that
	# censoring has not already been primed in the course
	# of this analysis.
	#  * It is critical that this step only be performed
	#    once in the course of each analysis.
	#  * If censoring has already been primed, then the
	#    type of censoring requested will be stored in one
	#    of the variables: censor[cxt] or censor[subjidx]
   ################################################################
	if [[ ! -z "$censor_type" ]]
	   then
	   echo "Determining volumes to be censored..."
      #############################################################
	   # Create and write the temporal mask.
	   # Use the criterion dimension and threshold
	   # specified by the user to determine whether each
	   # volume should be masked out.
      #############################################################
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
   ################################################################
	# Determine the number of volumes that fail the motion
	# criterion and print this to another QA file.
   ################################################################
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
###################################################################
# * Remove the motion corrected image: this step should
#   only compute parameters, not use them.
# * Discard realignment transforms, since they are not
#   used in this step.
# * Symlink to the previous image in the chain so that
#   the final check can verify that this step completed
#   successfully.
# * Update the image pointer.
###################################################################
[[ -e ${img}_${cur}${ext} ]] && rm -f ${img}_${cur}${ext}
rm -rf ${outdir}/${prefix}~TEMP~_mc*.mat
rm -f ${referenceVolume[${cxt}]}
ln -s ${img}${ext} ${img}_${cur}${ext}
img=${img}_${cur}
echo "Processing step complete:"
echo "computing realignment parameters"





###################################################################
# Correct images for timing of slice acquisition
# based upon user input.
###################################################################
echo ""; echo ""; echo ""
echo "Current processing step:"
echo "Slice timing correction"
echo "Acquisition: ${prestats_stime[${cxt}]}"
echo "Acquisition axis: ${prestats_sdir[${cxt}]}"
###################################################################
# Ensure that this submodule has not already run to
# completion; if it has, then an associated image should
# exist.
###################################################################
if [[ ! $(imtest ${img}_${cur}) == "1" ]] \
   || [[ "${prestats_rerun[${cxt}]}" == "Y" ]]
   then
   ################################################################
   # Read in the acquisition axis; translate axes from
   # common names to FSL terminology.
   ################################################################
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
   ################################################################
   # Read in the direction of acquisition to determine
   # the order in which slices were acquired.
   ################################################################
   case "${prestats_stime[${cxt}]}" in
   up)
      #############################################################
      # For bottom-up acquisition, slicetimer is called
      # with the default settings.
      #############################################################
      slicetimer \
         -i $img \
         -o ${img}_${cur} \
         -d $sdir
      img=${img}_${cur}
      ;;
   down)
      #############################################################
      # For top-down acquisition, slicetimer is called
      # with the --down flag.
      #############################################################
      slicetimer \
         -i $img \
         -o ${img}_${cur} \
         --down \
         -d $sdir
      img=${img}_${cur}
      ;;
   interleaved)
      #############################################################
      # For interleaved acquisition, slicetimer is called
      # with the --odd flag.
      #############################################################
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
      #############################################################
      # If a custom slice order file is used, call
      # slicetimer with the -ocustom flag pointed at the
      # file.
      #############################################################
      if [[ "${prestats_stime_order[${cxt}]}" == "true" ]]
         then
         slicetimer \
            -i $img \
            -o ${img}_${cur} \
            -d $sdir \
            -ocustom $opath
         img=${img}_${cur}
      #############################################################
      # If a custom slice timing file is used, call
      # slicetimer with the -tcustom flag pointed at the
      # file.
      #############################################################
      elif [[ "${prestats_stime_timing[${cxt}]}" == "true" ]]
         slicetimer \
            -i $img \
            -o ${img}_${cur} \
            -d $sdir \
            -tcustom $tpath
         img=${img}_${cur}
      fi
      ;;
   none)
      #############################################################
      # Create a symlink to ensure that this step is
      # counted as complete by the final check, even if
      # no slice timing correction has actually been
      # performed.
      #
      # If you are entering this code, you may as well
      # have removed STM from your pipeline. But I sure
      # made that sound quite scary, didn't I?
      #############################################################
      ln -s ${img}${ext} ${img}_${cur}${ext}
      img=${img}_${cur}
      ;;
   *)
      echo "Slice timing correction:"
      echo "Unrecognised option ${prestats_stime[${cxt}]}"
      ;;
   esac
###################################################################
# If the output of slice timing already exists, then
# update the image pointer.
###################################################################
else
   img=${img}_${cur}
fi # run check statement
echo "Processing step complete: slice timing correction"





###################################################################
# MCO computes the realignment parameters and uses them
# to realign all volumes to the reference.
#
# MPR is intended to be run prior to slice timing
# correction, and MCO after slice timing correction.
###################################################################
echo ""; echo ""; echo ""
echo "Current processing step:"
echo "Correcting for subject motion"
###################################################################
# Determine whether a reference functional image already
# exists. If it does not, extract it from the timeseries
# midpoint.
###################################################################
if [[ $(imtest ${referenceVolume[${cxt}]}) != "1" ]] \
   || [[ "${prestats_rerun[${cxt}]}" == "Y" ]]
   then
   echo "Extracting reference volume"
   ################################################################
   # If the framewise displacement has not been
   # calculated, then use the timeseries midpoint as the
   # reference volume.
   ################################################################
   if [[ ! -e ${fd[${cxt}]} ]]
      then
      #############################################################
      # Compute the number of volumes...
      #############################################################
      nvol=$(fslnvols $img)
      #############################################################
      # ...then use this to obtain the timeseries
      # midpoint. expr should always return integer
      # values.
      #############################################################
      midpt=$(expr $nvol / 2)
      #############################################################
      # Finally, extract the indicated volume for use as
      # a reference in realignment.
      #############################################################
	fslroi $img ${referenceVolume[${cxt}]} $midpt 1
   ################################################################
   # Otherwise, use the volume with minimal framewise
   # displacement.
   ################################################################
	else
	   nvol=$(cat ${fd[${cxt}]}|wc -l)
	   volmin=2
	   minfd=$(sed -n 2p ${fd[${cxt}]})
      #############################################################
      # Iterate through all volumes; if the FD value at
      # the current volume is less than the minimum
      # observed value so far, it becomes the minimum
      # observed value and the candidate for becoming
      # the reference volume.
      #############################################################
	   for i in $(seq 3 $nvol)
	      do
	      curfd=$(sed -n ${i}p ${fd[${cxt}]})
	      [[ $(echo $curfd'<'$minfd | bc -l) == 1 ]] \
	      && minfd=${curfd} \
	      && volmin=${i}
	   done
      #############################################################
      # Extract the volume with minimal FD for use as a
      # reference in realignment.
      #############################################################
	   fslroi $img ${referenceVolume[${cxt}]} $volmin 1
   fi
fi
###################################################################
# Verify that this step has not already completed; if it
# has, then an associated image should exist.
###################################################################
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
###################################################################
# Save the realignment transforms.
###################################################################
mv -f ${outdir}/${prefix}~TEMP~_mc*.mat ${rmat[${cxt}]}
###################################################################
# Update image pointer
###################################################################
ln -s ${outdir}/${prefix}~TEMP~_mc${ext} ${img}_${cur}${ext}
img=${img}_${cur}
echo "Processing step complete: motion correction"





###################################################################
# Remove any intensity outliers ("spikes") from the BOLD
# timeseries and interpolate over outlier epochs.
###################################################################
echo ""; echo ""; echo ""
echo "Current processing step:"
echo "Despiking BOLD timeseries"
###################################################################
	      # First, verify that this step has not already run to
	      # completion by searching for expected output.
###################################################################
if [[ $(imtest ${img}_${cur}) != "1" ]] \
   || [[ "${prestats_rerun[${cxt}]}" == "Y" ]]
   then
   rm -rf ${img}_${cur}${ext} #AFNI will not overwrite
   ################################################################
   # Determine whether to run new or old 3dDespike.
   # This is based on the number of volumes.
   # If the timeseries has more than 200 volumes,
   # the old method will be incredibly slow, so the
   # new method should be run.
   ################################################################
   nvol=$(fslnvols $img)
   ################################################################
   # need extension to work with AFNI; will otherwise
   # default to brickheads
   ################################################################
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
###################################################################
# Update image pointer
###################################################################
img=${img}_${cur}
echo "Processing step complete: despiking timeseries"





###################################################################
# BXT computes a mask over the whole brain and excludes
# non-brain voxels from further analyses.
###################################################################
echo ""; echo ""; echo ""
echo "Current processing step:"
         echo "Brain extraction"
         echo "Fractional intensity threshold ${prestats_fit[${cxt}]}"
###################################################################
# Generate a mean functional image by averaging voxel
# intensity over time. This mean functional image will be
# used as the priamry reference for establishing the
# boundary between brain and background.
###################################################################
	      fslmaths $img -Tmean ${meanIntensity[${cxt}]}
	      echo "Mean functional image generated"
###################################################################
# Brain extraction proceeds in two passes.
#  * The first pass uses BET to generate a conservative
#    estimate of the brain-background boundary.
#  * The second pass uses fslmaths to dilate the initial
#    mask, producing a more inclusive brain mask.
#
# First, verify that the first pass has not already
# completed. The first pass writes its output to:
# ${img}_${cur}_1
###################################################################
if [[ $(imtest ${img}_${cur}_1) != "1" ]] || \
   [[ "${prestats_rerun[${cxt}]}" == "Y" ]]
   then
	echo "Initialising brain extraction..."
   ################################################################
	# Use BET to generate a preliminary mask. This should
	# be written out to the mask[cxt] variable.
   ################################################################
   bet ${meanIntensity[${cxt}]} \
      ${outdir}/${prefix} \
      -f ${prestats_fit[${cxt}]} \
      -n \
      -m \
      -R
   echo "Binary brain mask generated"
   immv ${outdir}/${prefix} ${meanIntensityBrain[${cxt}]}
   ################################################################
   # Additionally, prepare a brain-extracted version of
   # the example functional image; this will later be
   # necessary for coregistration of functional and
   # structural acquisitions.
   ################################################################
   bet ${referenceVolume[${cxt}]} \
      ${referenceVolumeBrain[${cxt}]} \
      -f ${prestats_fit[${cxt}]}
   ################################################################
   # Use the preliminary mask to extract brain tissue.
   ################################################################
   fslmaths $img -mas ${mask[${cxt}]} ${img}_${cur}_1
   echo "Brain extraction first pass complete"
fi
###################################################################
# Now, verify that the second pass has not already
# completed. The second pass writes its output to:
# ${img}_${cur}_2
###################################################################
if [[ $(imtest ${img}_${cur}_2) != "1" ]] \
   || [[ "${prestats_rerun[${cxt}]}" == "Y" ]]
   then
   echo "Thresholding and dilating image"
   echo "Brain-background threshold:"
   ################################################################
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
   ################################################################
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
###################################################################
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
###################################################################
if [[ $(imtest ${img}_${cur}) != "1" ]] || \
   [[ "${prestats_rerun[${cxt}]}" == "Y" ]]
   then
   ################################################################
   # Use the -k flag to ensure that only brain voxels are
   # taken into consideration when computing median
   # intensity.
   ################################################################
   perc50=$(fslstats ${img}_${cur}_2 \
      -k ${mask[${cxt}]} \
      -p 50)
   gmscale=$(echo $perc50 | awk '{printf 10000/$1}')
   fslmaths ${img}_${cur}_2 -mul $gmscale ${img}_${cur}
fi
###################################################################
# Update the image pointer.
###################################################################
img=${img}_${cur}
echo "Processing step complete: brain extraction"





###################################################################
# A white matter mask must be extracted from the user-specified
# tissue segmentation.
#  * This mask is written to the path ${outbase}_t1wm. It is
#    considered a temporary file, so it will be deleted in the
#    cleanup phase.
###################################################################
wmmask=${outbase}_t1wm
if [[ $(imtest "${wmmask}") != 1 ]] \
   || [[ "${coreg_rerun[${cxt}]}" != "N" ]]
   then
   echo ""; echo ""; echo ""
   echo "Current processing step:"
   echo "Extracting white matter mask from segmentation"
   case ${coreg_wm[${cxt}]} in
   ################################################################
   # * If the user-specified tissue segmentation includes only
   #   white matter, then it only needs to be binarised.
   ################################################################
	   all)
	      echo "All nonzero voxels correspond to white matter."
	      echo "Binarising image..."
	      fslmaths ${coreg_seg[${cxt}]} -bin ${wmmask}
	      ;;
   ################################################################
   # * If the user has provided specific values in the
   #   segmentation that correspond to white matter, then
   #   a mask must be created that comprises only the voxels
   #   in which the user-specified segmentation takes one of
   #   the user-specified intensity values.
   # * This will be the case if the user provides the ANTsCT
   #   segmentation or intensity values in a bias-corrected
   #   structural image.
   # * The coregistration module uses the utility script
   #   val2mask to convert the specified values to a binary
   #   mask.
   ################################################################
   *)
      echo "Voxels with value ${coreg_wm[${cxt}]} correspond to"
      echo "white matter. Thresholding out all other voxels"
      echo "and binarising image..."
      ${XCPEDIR}/utils/val2mask.R \
         -i ${coreg_seg[${cxt}]} \
         -v ${coreg_wm[${cxt}]} \
         -o ${wmmask}${ext}
      ;;
   esac
fi
###################################################################
# Prime an additional input argument to FLIRT, containing
# the path to the new mask.
###################################################################
wmmaskincl="-wmseg $wmmask"
echo "Processing step complete:"
echo "White matter mask"





###################################################################
# Perform the affine coregistration using FLIRT and user
# specifications.
###################################################################
echo ""; echo ""; echo ""
echo "Current processing step:"
echo "Executing affine coregistration"
echo "Cost function: ${coreg_cfunc[${cxt}]}"
echo "Input volume ${rVolBrain}"
echo "Reference volume ${struct[${subjidx}]}"
echo "Output volume ${e2simg[${cxt}]}"
if [[ ! -e ${e2smat[${cxt}]} ]] \
   || [[ "${coreg_rerun[${cxt}]}" != "N" ]]
   then
   flirt -in ${rVolBrain} \
      -ref ${struct[${subjidx}]} \
      -dof 6 \
      -out ${outbase}_seq2struct \
      -omat ${outbase}_seq2struct.mat \
      -cost ${coreg_cfunc[${cxt}]} \
      ${wmmaskincl}
fi
echo "Processing step complete:"
echo "Affine coregistration"
###################################################################
# Move outputs.
###################################################################
[[ $(imtest ${outbase}_seq2struct) == 1 ]] \
   && immv ${outbase}_seq2struct ${e2simg[${cxt}]}
[[ ! -e ${e2smat[${cxt}]} ]] \
   && mv -f ${outbase}_seq2struct.mat ${e2smat[${cxt}]}





###################################################################
# Compute metrics of coregistration quality:
#  * Spatial correlation of structural and seq -> structural masks
#  * Coverage: structural brain <=> sequence -> structural
###################################################################
echo ""; echo ""; echo ""
echo "Current processing step:"
echo "Quality control"
if [[ ! -e ${quality[${cxt}]} ]] \
   || [[ "${coreg_rerun[${cxt}]}" != "N" ]] \
   || [[ $(tail -n1 /data/joy/BBL/studies/pnc/processedData/dtiXCPtest/100031/20100918x3818/coreg/100031_20100918x3818_coregQuality.csv) == ',' ]]
   then
   rm -f ${quality[${cxt}]}
   fslmaths ${e2simg[${cxt}]} -bin ${e2smask[${cxt}]}
   fslmaths ${struct[${subjidx}]} -bin ${outbase}_struct_mask
   fslmaths ${outbase}_struct_mask \
      -sub ${e2smask[${cxt}]} \
      -thr 0 \
      -bin \
      ${outbase}_struct_maskdiff
   qa_vol_struct=$(fslstats ${outbase}_struct_mask -V\
      |awk '{print $2}')
   qa_vol_diff=$(fslstats ${outbase}_struct_maskdiff -V\
      |awk '{print $2}')
   qa_cov_obs=$(echo "scale=10; 1 - ${qa_vol_diff} / ${qa_vol_struct}"|bc)
   qa_cov_max=1
   qa_coverage=$(echo "scale=10; ${qa_cov_obs} / ${qa_cov_max}"|bc)
   qa_cc=$(fslcc -p 8 ${e2smask[${cxt}]} ${outbase}_struct_mask\
      |awk '{print $3}')
   echo "coregCrossCorr,coregCoverage"\
      >> ${quality[${cxt}]}
   echo "${qa_cc},${qa_coverage}"\
      >> ${quality[${cxt}]}
   echo "Cross-correlation: ${qa_cc}"
   echo "Coverage: ${qa_coverage}"
fi





###################################################################
# If the subject fails quality control, then repeat coregistration
# using an alternative metric: crosscorrelation. Unless
# crosscorrelation has been specified and failed, in which case
# mutual information is used instead.
#
# First, parse the quality control cutoffs.
###################################################################
qa_cc_min=$(echo ${coreg_qacut[${cxt}]}|cut -d"," -f1)
qa_coverage_min=$(echo ${coreg_qacut[${cxt}]}|cut -d"," -f2)
###################################################################
# Then, parse the observed quality metrics.
###################################################################
flag=0
qa_obs=$(tail -n1 ${quality[${cxt}]})
qa_cc=$(echo ${qa_obs}|cut -d"," -f1)
qa_coverage=$(echo ${qa_obs}|cut -d"," -f2)
###################################################################
# Determine whether each warrants flagging the coregistration
# for poor quality.
#
# A negative or nonsense input for any value indicates never to
# flag.
###################################################################
[[ $(echo $qa_cc'<'$qa_cc_min | bc -l) == 1 ]] \
   && [[ $qa_cc_min =~ ${POSNUM} ]] \
   && flag=1
[[ $(echo $qa_coverage'<'$qa_coverage_min | bc -l) == 1 ]] \
   && [[ $qa_coverage_min =~ ${POSNUM} ]] \
   && flag=1
###################################################################
# If coregistration was flagged for poor quality, repeat it.
###################################################################
if [[ ${flag} == 1 ]]
   then
   echo "WARNING: Coregistration was flagged using"
   echo "         cost function ${coreg_cfunc[${cxt}]}"
   ################################################################
   # First, determine what cost function to use.
   ################################################################
   [[ ${coreg_cfunc[${cxt}]} == ${ALTREG1} ]] \
      && coreg_cfunc[${cxt}]=${ALTREG2} \
      || coreg_cfunc[${cxt}]=${ALTREG1}
   echo "Coregistration will be repeated using"
   echo "  cost function ${coreg_cfunc[${cxt}]}"
   echo "All other parameters remain the same."
   echo "Only the coregistration with better results on"
   echo "  the ${QADECIDE} metric will be retained."
   ################################################################
   # Re-compute coregistration.
   ################################################################
   flirt -in ${rVolBrain} \
      -ref ${struct[${subjidx}]} \
      -dof 6 \
      -out ${outbase}_seq2struct_alt \
      -omat ${outbase}_seq2struct_alt.mat \
      -cost ${coreg_cfunc[${cxt}]} \
      ${refwt} \
      ${inwt}
   ################################################################
   # Compute the quality metrics for the new registration.
   ################################################################
   fslmaths ${outbase}_seq2struct_alt -bin ${outbase}_seq2struct_alt_mask
   fslmaths ${struct[${subjidx}]} -bin ${outbase}_struct_mask
   fslmaths ${outbase}_struct_mask \
      -sub ${outbase}_seq2struct_alt_mask \
      -thr 0 \
      -bin \
      ${outbase}_struct_alt_maskdiff
   qa_vol_struct_alt=$(fslstats ${outbase}_struct_mask -V\
      |awk '{print $2}')
   qa_vol_seq2struct_alt=$(fslstats ${outbase}_seq2struct_alt_mask -V\
      |awk '{print $2}')
   qa_vol_diff_alt=$(fslstats ${outbase}_struct_alt_maskdiff -V\
      |awk '{print $2}')
   qa_cov_obs_alt=$(echo "scale=10; 1 - ${qa_vol_diff_alt} / ${qa_vol_struct_alt}"|bc)
   qa_cov_max_alt=$(echo "scale=10; ${qa_vol_seq2struct_alt} / ${qa_vol_struct_alt}"|bc)
   [[ $(echo "${qa_cov_max} > 1"|bc -l) == 1 ]] && qa_cov_max=1
   qa_coverage_alt=$(echo "scale=10; ${qa_cov_obs_alt} / ${qa_cov_max_alt}"|bc)
   qa_cc_alt=$(fslcc -p 8 ${outbase}_seq2struct_alt_mask ${outbase}_struct_mask\
      |awk '{print $3}')
   echo "Recomputed cross-correlation: ${qa_cc_alt}"
   echo "Recomputed coverage: ${qa_coverage_alt}"
   ################################################################
   # Compare the metrics to the old ones. The decision is made
   # based on the QADECIDE constant if coregistration is repeated
   # due to failing quality control.
   ################################################################
   ineq=gt
   [[ ${QADECIDE} == qa_NOTUSEDANYMOREBUTITMIGHTBEINTHEFUTURE ]] && ineq=lt
   QADECIDE_ALT=${QADECIDE}_alt
   if [[ ${ineq} == gt ]]
      then
      decision=$(echo ${!QADECIDE_ALT}'>'${!QADECIDE}|bc -l)
   else
      decision=$(echo ${!QADECIDE_ALT}'<'${!QADECIDE}|bc -l)
   fi
   if [[ ${decision} == 1 ]]
      then
      mv ${outbase}_seq2struct_alt.mat ${e2smat[${cxt}]}
      immv ${outbase}_seq2struct_alt ${e2simg[${cxt}]}
      immv ${outbase}_seq2struct_alt_mask ${e2smask[${cxt}]}
      echo "coreg_cfunc[${cxt}]=${coreg_cfunc[${cxt}]}" \
         >> $design_local
      rm -f ${quality[${cxt}]}
      echo "coregCrossCorr,coregCoverage"\
         >> ${quality[${cxt}]}
      echo "${qa_cc_alt},${qa_coverage_alt}"\
         >> ${quality[${cxt}]}
      echo "The coregistration result improved; however, there"
      echo "  is a chance that it still failed. You are encouraged "
      echo "  to verify the results."
   else
      echo "Coregistration failed to improve with a change in"
      echo "  the cost function. This may be attributable to"
      echo "  incomplete coverage in the acquisitions."
   fi
else
   echo "Coregistration passed quality control!"
fi
echo "Processing step complete:"
echo "Quality control"





###################################################################
# Prepare slice graphics as an additional assessor of
# coregistration quality.
###################################################################
echo ""; echo ""; echo ""
echo "Current processing step:"
echo "Preparing visual aids for coregistration quality"
[[ -e ${outdir}/${prefix}_targetVolume${ext} ]] \
   && unlink ${outdir}/${prefix}_targetVolume${ext}
ln -s ${struct[${subjidx}]} ${outdir}/${prefix}_targetVolume${ext}
slicer ${e2simg[${cxt}]} ${struct[${subjidx}]} \
   -s 2 \
   -x 0.35 ${outdir}/${prefix}_sla.png \
   -x 0.45 ${outdir}/${prefix}_slb.png \
   -x 0.55 ${outdir}/${prefix}_slc.png \
   -x 0.65 ${outdir}/${prefix}_sld.png \
   -y 0.35 ${outdir}/${prefix}_sle.png \
   -y 0.45 ${outdir}/${prefix}_slf.png \
   -y 0.55 ${outdir}/${prefix}_slg.png \
   -y 0.65 ${outdir}/${prefix}_slh.png \
   -z 0.35 ${outdir}/${prefix}_sli.png \
   -z 0.45 ${outdir}/${prefix}_slj.png \
   -z 0.55 ${outdir}/${prefix}_slk.png \
   -z 0.65 ${outdir}/${prefix}_sll.png
pngappend ${outdir}/${prefix}_sla.png \
   + ${outdir}/${prefix}_slb.png \
   + ${outdir}/${prefix}_slc.png \
   + ${outdir}/${prefix}_sld.png \
   + ${outdir}/${prefix}_sle.png \
   + ${outdir}/${prefix}_slf.png \
   + ${outdir}/${prefix}_slg.png \
   + ${outdir}/${prefix}_slh.png \
   + ${outdir}/${prefix}_sli.png \
   + ${outdir}/${prefix}_slj.png \
   + ${outdir}/${prefix}_slk.png \
   + ${outdir}/${prefix}_sll.png \
   ${outdir}/${prefix}_seq2struct1.png
slicer ${struct[${subjidx}]} ${e2simg[${cxt}]} \
   -s 2 \
   -x 0.35 ${outdir}/${prefix}_sla.png \
   -x 0.45 ${outdir}/${prefix}_slb.png \
   -x 0.55 ${outdir}/${prefix}_slc.png \
   -x 0.65 ${outdir}/${prefix}_sld.png \
   -y 0.35 ${outdir}/${prefix}_sle.png \
   -y 0.45 ${outdir}/${prefix}_slf.png \
   -y 0.55 ${outdir}/${prefix}_slg.png \
   -y 0.65 ${outdir}/${prefix}_slh.png \
   -z 0.35 ${outdir}/${prefix}_sli.png \
   -z 0.45 ${outdir}/${prefix}_slj.png \
   -z 0.55 ${outdir}/${prefix}_slk.png \
   -z 0.65 ${outdir}/${prefix}_sll.png
pngappend ${outdir}/${prefix}_sla.png \
   + ${outdir}/${prefix}_slb.png \
   + ${outdir}/${prefix}_slc.png \
   + ${outdir}/${prefix}_sld.png \
   + ${outdir}/${prefix}_sle.png \
   + ${outdir}/${prefix}_slf.png \
   + ${outdir}/${prefix}_slg.png \
   + ${outdir}/${prefix}_slh.png \
   + ${outdir}/${prefix}_sli.png \
   + ${outdir}/${prefix}_slj.png \
   + ${outdir}/${prefix}_slk.png \
   + ${outdir}/${prefix}_sll.png \
   ${outdir}/${prefix}_seq2struct2.png
pngappend ${outdir}/${prefix}_seq2struct1.png \
   - ${outdir}/${prefix}_seq2struct2.png \
   ${outdir}/${prefix}_seq2struct.png
rm -f ${outdir}/${prefix}_sl*.png \
   ${outdir}/${prefix}_seq2struct1.png \
   ${outdir}/${prefix}_seq2struct2.png
echo "Processing step complete:"
echo "Coregistration visuals"





###################################################################
# Use the forward transformation to compute the reverse
# transformation. This is critical for moving (inter alia)
# standard-space network maps and RoI coordinates into
# the subject's native analyte space, allowing for accelerated
# pipelines and reduced disk usage.
###################################################################
echo ""; echo ""; echo ""
echo "Current processing step:"
echo "Derivative transformations"
echo " * Computing inverse transformation"
convert_xfm \
   -omat ${outbase}_struct2seq.mat \
   -inverse ${e2smat[${cxt}]}
###################################################################
# The XCP Engine uses ANTs-based registration; the
# coregistration module uses an ITK-based helper script to 
# convert the FSL output into a format that can be read by ANTs.
###################################################################
if [[ ! -e ${seq2struct[${cxt}]} ]] \
   || [[ "${coreg_rerun[${cxt}]}" != "N" ]]
   then
   structpath=$(\ls ${struct[${subjidx}]}*)
   for i in ${structpath}
      do
      [[ $(imtest ${i}) == 1 ]] && structpath=${i} && break
   done
   echo " * Converting coregistration .mat to ANTs format"
	c3d_affine_tool \
	   -src ${rVolBrain}${ext} \
	   -ref ${structpath} \
	   ${e2smat[${cxt}]} \
		-fsl2ras \
		-oitk ${seq2struct[${cxt}]}
fi
###################################################################
# The XCP Engine uses ANTs-based registration; the
# coregistration module uses an ITK-based helper script to 
# convert the FSL output into a format that can be read by ANTs.
###################################################################
if [[ ! -e ${struct2seq[${cxt}]} ]] \
   || [[ "${coreg_rerun[${cxt}]}" != "N" ]]
   then
   structpath=$(\ls ${struct[${subjidx}]}*)
   for i in ${structpath}
      do
      [[ $(imtest ${i}) == 1 ]] && structpath=${i} && break
   done
   echo " * Converting inverse coregistration .mat to ANTs format"
	c3d_affine_tool \
	   -src ${structpath} \
	   -ref ${rVolBrain}${ext} \
	   ${outbase}_struct2seq.mat \
		-fsl2ras \
		-oitk ${struct2seq[${cxt}]}
   mv -f ${outbase}_struct2seq.mat ${s2emat[${cxt}]}
fi
###################################################################
# Compute the structural image in analytic space, and generate
# a mask for that image.
###################################################################
if [[ ! -e ${s2emask[${cxt}]} ]] \
   || [[ "${coreg_rerun[${cxt}]}" != "N" ]]
   then
   ${ANTSPATH}/antsApplyTransforms \
      -e 3 -d 3 \
      -r ${referenceVolumeBrain[${subjidx}]}${ext} \
      -o ${s2eimg[${cxt}]}${ext} \
      -i ${struct[${subjidx}]} \
      -t ${struct2seq[${cxt}]}
   fslmaths ${s2eimg[${cxt}]} -bin ${s2emask[${cxt}]}
fi
echo "Processing step complete:"
echo "Derivative transforms"




if [[ "${confound_rp[${cxt}]}" == "Y" ]]
   then
   
   
   
   
   
   ################################################################
   # REALIGNMENT PARAMETERS
   # Realignment parameters should have been computed using the MPR
   # subroutine of the prestats module prior to their use in the
   # confound matrix here.
   ################################################################
   echo "Including realignment parameters in confound model."
   ################################################################
   # Add the RPs to the confound matrix.
   ################################################################
   ${XCPEDIR}/utils/mbind.R \
      -x ${confmat[${cxt}]} \
      -y ${rps[${subjidx}]} \
      -o ${confmat_path}
   confmat[${cxt}]=$confmat_path
   
   
   
   
   
   ################################################################
   # GREY MATTER
   # First, determine whether to include the mean grey matter
   # timeseries in the confound model. If the grey matter mask is
   # to be included, then it must be conformed to user
   # specifications:
   #  * Extract the GM mask from the user-specified segmentation
   #  * Erode the GM mask according to user specifications
   #  * Move the GM mask into the same space as the primary BOLD
   #    timeseries.
   ################################################################
   echo "Including mean grey matter signal in confound model."
   gmMask=${outbase}_gm
   ################################################################
   # Generate a binary mask if necessary.
   # This mask will be based on a user-specified input value
   # and a user-specified image in the subject's structural space.
   ################################################################
   if [[ $(imtest "$gmMask") != "1" ]] \
      || [[ "${confound_rerun[${cxt}]}" != "N" ]]
      then
      rm -f ${gmMask}${ext}
      ${XCPEDIR}/utils/val2mask.R \
         -i ${confound_gm_path[${cxt}]} \
         -v ${confound_gm_val[${cxt}]} \
         -o ${gmMask}${ext}
   fi
   ################################################################
   # Erode the mask iteratively using the erodespare utility.
   #  * erodespare ensures that the result of applying the
   #    specified erosion is non-empty; if an empty result is
   #    obtained, the degree of erosion is decremented until the
   #    result is non-empty.
   ################################################################
   if [[ ${confound_gm_ero[${cxt}]} -gt 0 ]]
      then
      [[ ${trace} == 1 ]] && traceprop="-t"
      ${XCPEDIR}/utils/erodespare \
         -i ${gmMask}${ext} \
         -o ${gmMask}_ero${ext} \
         -e ${confound_gm_ero[${cxt}]} \
         ${traceprop}
      gmMask=${gmMask}_ero
   fi
   
   ${ANTSPATH}/antsApplyTransforms \
      -i ${gmMask}${ext} \
      -o ${gmMask}${ext} \
      -r ${referenceVolumeBrain[${subjidx}]}${ext} \
      -n NearestNeighbor \
      -t ${struct2seq[${subjidx}]}
      
   ################################################################
   # Extract the mean timecourse from the eroded and transformed
   # mask.
   ################################################################
   fslmeants -i ${img} -o ${outbase}_phys_gm -m ${gmMask}
   immv ${gmMask} ${gmMask[${cxt}]}
   gm=$(ls -d1 ${outbase}_phys_gm)
   ${XCPEDIR}/utils/mbind.R \
      -x ${confmat[${cxt}]} \
      -y ${gm} \
      -o ${confmat_path}
   confmat[${cxt}]=$confmat_path
   
   
   
   
   
   ################################################################
   # WHITE MATTER
   # First, determine whether to include the mean white matter
   # timeseries in the confound model. If the white matter mask is
   # to be included, then it must be conformed to user
   # specifications:
   #  * Extract the WM mask from the user-specified segmentation
   #  * Erode the WM mask according to user specifications
   #  * Move the WM mask into the same space as the primary BOLD
   #    timeseries.
   ################################################################
fi
