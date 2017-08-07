#!/usr/bin/env bash

###################################################################
#  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  #
###################################################################

###################################################################
# Constants
# None yet
###################################################################





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
echo "#  ☭                EXECUTING REGRESSION MODULE                ☭  #"
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
outdir=${out}/${prep}regress
[[ ! -e ${outdir} ]] && mkdir -p ${outdir}
echo "Output directory is $outdir"
###################################################################
# Define paths to all potential outputs.

# For the regress module, potential outputs include:
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
###################################################################
# auxImgs[${cxt}]=${outdir}/${prefix}_derivs
confmat[${cxt}]=${outdir}/${prefix}_confmatFiltered.1D
confcor[${cxt}]=${outdir}/${prefix}_confcor.txt
qavol[${cxt}]=${outdir}/${prefix}_nvolCensored.txt
final[${cxt}]=${outdir}/${prefix}_residualised
# rm -f ${auxImgs[${cxt}]}
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
if [[ $(imtest ${img}) != "1" ]] \
   || [[ "${regress_rerun[${cxt}]}" == "Y" ]]
   then
   rm -f ${img}
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
echo "# *** outputs from regress[${cxt}] *** #" >> $design_local
echo "" >> $design_local
###################################################################
# Verify that the module should be run:
#  * Test whether the final output already exists.
#  * Determine whether the user requested the module to be re-run.
# If it is determined that the module should not be run, then any
#  outputs must be written to the local design file.
###################################################################
if [[ $(imtest ${final[${cxt}]}) == 1 ]] \
   && [[ ${regress_rerun[${cxt}]} == "N" ]]
   then
   echo "Nuisance regression has already run to completion."
   echo "Writing outputs..."
   if [[ "${regress_cleanup[${cxt}]}" == "Y" ]]
      then
      rm -rf ${outdir}/*~TEMP~*
   fi
   rm -f ${out}/${prefix}${ext}
   ln -s ${final[${cxt}]}${ext} ${out}/${prefix}${ext}
   echo "confmat[${subjidx}]=${confmat[${cxt}]}" >> $design_local
   imgs_sm=$(ls -d1 ${final[${cxt}]}_sm*)
   for img_sm in ${imgs_sm}
      do
      img_sm=$(echo $img_sm|cut -d'.' -f1)
      ker=$(echo ${img_sm}|rev|cut -d'_' -f1|rev|sed s@'^sm'@@g)
      echo "img_sm${ker}[${subjidx}]=${img_sm}" >> ${design_local}
      echo "#sm${ker}#${img_sm}" >> ${auxImgs[${subjidx}]}
   done
   if [[ -e ${qavol[${cxt}]} ]]
      then
      qvars=${qvars},nframesCensored
      qvals=${qvals},$(cat ${qavol[${cxt}]})
   fi
   ################################################################
   # Since it has been determined that the module does not need to
   # be executed, update the audit file and exit the module.
   ################################################################
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
# Read in any local regressors, if they are present.
###################################################################
if [[ ! -z "${locregs[${subjidx}]}" ]]
   then
   locregs=$(cat ${locregs[${subjidx}]})
fi





###################################################################
# Despike all timeseries, if the user has requested this option:
#  * The primary analyte timeseries
#  * Local regressors
#  * Global regressors
###################################################################
if [[ ${regress_despike[${cxt}]} == Y ]]
   then
   echo ""; echo ""; echo ""
   echo "Current processing step:"
   echo "Despiking BOLD timeseries"
	################################################################
	# First, verify that this step has not already run to
	# completion by searching for expected output.
	################################################################
   if [[ $(imtest ${img}_despike) != "1" ]] \
      || [[ "${prestats_rerun[${cxt}]}" == "Y" ]]
      then
      rm -rf ${img}_${cur}${ext} #AFNI will not overwrite
	   #############################################################
      # Determine whether to run new or old 3dDespike.
      # This is based on the number of volumes.
      # If the timeseries has more than 500 volumes,
      # the old method will be incredibly slow, so the
      # new method should be run.
	   #############################################################
      nvol=$(fslnvols $img)
	   #############################################################
      # need extension to work with AFNI; will otherwise
      # default to brickheads
	   #############################################################
      if [[ "$nvol" -ge "500" ]]
         then
         nieuw="-NEW"
         new1d="-n"
      else
         nieuw=""
         new1d=""
      fi
	   #############################################################
	   # Primary image
	   #############################################################
      3dDespike \
         -prefix ${img}_despike${ext} \
         -nomask \
         -quiet \
         ${nieuw} \
         ${img}${ext} \
         > /dev/null
	   #############################################################
	   # Derivatives
	   #############################################################
      derivimg=$(cat ${auxImgs[${subjidx}]})
      for dimg in ${derivimg}
         do
         #######################################################
         # * Parse the derivative image.
         #######################################################
         dName=$(echo ${dimg}|cut -d'#' -f2)
         dPath=$(echo ${dimg}|cut -d'#' -f3)
         #######################################################
         # * Only despike the derivative image if it has the
         #   same number of volumes as the primary image.
         #######################################################
         cvol=$(fslnvols ${dPath})
         if [[ "${nvol}" == "${cvol}" ]]
            then
            3dDespike \
               -prefix ${outdir}/${prefix}_${dname}_despike${ext} \
               -nomask \
               -quiet \
               ${nieuw} \
               ${img}${ext} \
               > /dev/null
            echo "#${dName}#${outdir}/${prefix}_${dname}_despike${ext}" \
               >> ${img}_dsp_derivs
         else
            echo "#${dName}#${dPath}" \
               >> ${img}_dsp_derivs
         fi
      done
      ##########################################################
      # Confound matrix
      ##########################################################
      [[ ${trace} == 1 ]] && traceprop="-t"
      ${XCPEDIR}/utils/1dDespike \
         -i ${confmat[${subjidx}]} \
         -o ${confmat[${cxt}]} \
         ${new1d} \
         -q \
         ${traceprop}
   fi
	################################################################
	# Update image pointers
	################################################################
   [[ -e ${img}_dsp_derivs ]] \
      && mv -f ${img}_dsp_derivs ${auxImgs[${subjidx}]}
   img=${img}_despike
   locregs=$(ls -d1 ${outdir}/*loc*despike* 2>/dev/null)
   confmat[${subjidx}]=${confmat[${cxt}]}
	echo "Processing step complete: despiking timeseries"
fi




###################################################################
# Apply a temporal filter to the BOLD timeseries, the confound
# matrix, and any local regressors.
#
# Any timeseries to be used in regression should by now be in
# the confound matrix.
#
#  * If no local regression is being used and the user has
#    specified a FFT filter, then filtering and regression can
#    be combined into a single step using 3dBandpass.
###################################################################
echo ""; echo ""; echo ""
echo "Current processing step:"
echo "Temporally filtering image and confounds"
echo "${regress_tmpf[${cxt}]} filter"
echo "High pass frequency: ${regress_hipass[${cxt}]}"
echo "Low pass frequency: ${regress_lopass[${cxt}]}"
###################################################################
# If no temporal filtering has been specified by the user, then
# bypass this step.
###################################################################
if [[ ${regress_tmpf[${cxt}]} == none ]]
   then
   ln -s ${img}${ext} ${img}_filtered${ext}
   cp ${confmat[${subjidx}]} ${confmat[${cxt}]}
###################################################################
# Ensure that this step has not already run to completion by
# checking for the existence of a filtered image and confound
# matrix.
###################################################################
elif [[ $(imtest ${img}_filtered) != "1" ]] \
   || [[ ! -e ${confmat[${cxt}]} ]] \
   || [[ "${regress_rerun[${cxt}]}" == "Y" ]]
   then
	################################################################
	# OBTAIN MASKS: SPATIAL
	# Obtain the spatial mask over which filtering is to be
	# applied, if a subject mask has been generated. Otherwise,
	# perform filtering without a mask.
	################################################################
   if [[ $(imtest ${mask[${subjidx}]}) == "1" ]]
      then
      mask="-m ${mask[${subjidx}]}"
	################################################################
	# If regress fails to find a mask, then prepare to
	# call tfilter without a mask argument.
	#######################################################
   else
      mask=""
   fi
	################################################################
	# OBTAIN MASKS: TEMPORAL
	# Obtain the path to the temporal mask over which filtering is
	# to be executed.
	#
	# If iterative censoring has been specified, then it will be
	# necessary to interpolate over high-motion epochs in order to
	# ensure that they do not exert inordinate influence upon the
	# temporal filter, resulting in corruption of adjacent volumes
	# by motion-related variance.
	################################################################
	censor_type=${censor[${subjidx}]}
	if [[ -e "${tmask[${subjidx}]}" ]]
      then
      tmaskpath=$(ls -d1 ${tmask[${subjidx}]})
	else
      tmaskpath=ones
   fi
	################################################################
	# Next, determine whether the user has enabled censoring of
	# high-motion volumes.
	#  * If iterative censoring is enabled, the temporal mask
	#    should be passed to tfilter with the -n flag. This will
	#    enable interpolation over volumes corrupted by motion.
	#  * If final censoring is enabled, the temporal mask should
	#    be passed to tfilter with the -k flag. This will ensure
	#    that volumes discarded from the BOLD timeseries are also
	#    discarded from the temporal mask, but will not interpolate
	#    over censored volumes.
	#  * If censoring is enabled, but no temporal mask exists yet,
	#    something has probably not completed as intended. Notify
	#    the user of the situation.
	#  * If censoring is disabled, no additional argument is passed
	#    to tfilter.
	################################################################
	if [[ "${censor_type}" == "iter" ]] \
	   && [[ ${tmaskpath} != ones ]]
	   then
	   tmask="-n ${tmaskpath}"
	elif [[ "${censor_type}" == "final" ]] \
	   && [[ ${tmaskpath} != ones ]]
	   then
	   tmask="-k ${tmaskpath}"
	elif [[ "${censor_type}" != "none" ]]
	   then
	   echo "WARNING: Censoring of high-motion volumes requires a"
	   echo "temporal mask, but the regression module has failed"
	   echo "to find one. You are advised to inspect your pipeline"
	   echo "to ensure that this is intentional."
	   echo ""
	   echo "Overriding user input:"
	   echo "No censoring will be performed."
	   censor[${subjidx}]=none
	   echo "censor[${subjidx}]=${censor[${subjidx}]}" \
	      >> ${design_local}
	   tmask=""
	else
	   tmask=""
	fi
	################################################################
	# DERIVATIVE IMAGES AND TIMESERIES
	# (CONFOUND MATRIX AND LOCAL REGRESSORS)
	# Prime the index of derivative images, as well as any 1D
	# timeseries (e.g. realignment parameters) that should be
	# filtered so that they can be used in linear models without
	# reintroducing the frequencies removed from the primary BOLD
	# timeseries.
	################################################################
	derivs=""
	ts1d=""
	[[ -e ${auxImgs[${subjidx}]} ]] \
	   && derivs="-x ${auxImgs[${subjidx}]}"
	################################################################
	# ...and the confound matrix
	################################################################
	if [[ -e ${confmat[${subjidx}]} ]]
	   then
	   ts1d="${confmat[${subjidx}]}"
	fi
	################################################################
	# Replace any whitespace characters in the 1D timeseries list
	# with commas, and prepend the -l flag for input as an argument
	# to tfilter.
	################################################################
	ts1d=$(echo ${ts1d}|sed s@' '@','@g)
	[[ ! -z ${ts1d} ]] && ts1d="-1 ${ts1d}"
	################################################################
	# FILTER-SPECIFIC ARGUMENTS
	# Next, set arguments specific to each filter class.
	################################################################
	tforder=""
	tfdirec=""
	tfprip=""
	tfsrip=""
	case ${prestats_tmpf[${cxt}]} in
	butterworth)
	   tforder="-r ${regress_tmpf_order[${cxt}]}"
	   tfdirec="-d ${regress_tmpf_pass[${cxt}]}"
	   ;;
	chebyshev1)
	   tforder="-r ${regress_tmpf_order[${cxt}]}"
	   tfdirec="-d ${regress_tmpf_pass[${cxt}]}"
	   tfprip="-p ${regress_tmpf_ripple[${cxt}]}"
	   ;;
	chebyshev2)
	   tforder="-r ${regress_tmpf_order[${cxt}]}"
	   tfdirec="-d ${regress_tmpf_pass[${cxt}]}"
	   tfsrip="-s ${regress_tmpf_ripple2[${cxt}]}"
	   ;;
	elliptic)
	   tforder="-r ${regress_tmpf_order[${cxt}]}"
	   tfdirec="-d ${regress_tmpf_pass[${cxt}]}"
	   tfprip="-p ${regress_tmpf_ripple[${cxt}]}"
	   tfsrip="-s ${regress_tmpf_ripple2[${cxt}]}"
	   ;;
	esac
	################################################################
	# If the user has requested discarding of initial and/or final
	# volumes from the filtered timeseries, the request should be
	# passed to tfilter.
	################################################################
	tfdvol=""
	[[ ! -z ${regress_tmpf_dvols[${cxt}]} ]] \
	   && [[ ${regress_tmpf_dvols[${cxt}]} != 0 ]] \
	   && tfdvol="-v ${regress_tmpf_dvols[${cxt}]}"
	################################################################
	# If the user has requested command tracing, propagate
	# that request into the tfilter routine.
	################################################################
	[[ ${trace} == 1 ]] && trace_prop="-t"
	################################################################
	# Determine whether filtering and regression can be combined
	# into a single step.
	#  * If so, then tfilter can be bypassed.
	#  * This is only the case if a FFT-based filter is being used,
	#    no local regressors are present in the model, iterative
	#    censoring is not being run, and no volumes are to be
	#    discarded from the timeseries.
	################################################################
	if [[ ${regress_tmpf[${cxt}]} == fft ]] \
	   && [[ -z ${locregs} ]] \
	   && [[ ${censor_type} != iter ]] \
	   && [[ -z ${tfdvol} ]]
	   then
	   3dBandpass \
         -prefix ${final[${cxt}]}${ext} \
         -nodetrend -quiet \
         -ort ${confmat[${subjidx}]} \
         ${regress_hipass[${cxt}]} \
         ${regress_lopass[${cxt}]} \
         ${img}${ext} \
         2>/dev/null
      has_residuals=1
	################################################################
	# Engage the tfilter routine to filter the image.
	#  * This is essentially a wrapper around the three implemented
	#    filtering routines: fslmaths, 3dBandpass, and genfilter
	################################################################
	else
	   ${XCPEDIR}/utils/tfilter \
	      -i ${img} \
	      -o ${img}_filtered \
	      -f ${regress_tmpf[${cxt}]} \
	      -h ${regress_hipass[${cxt}]} \
	      -l ${regress_lopass[${cxt}]} \
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
	   #############################################################
	   # Move outputs to target
	   #############################################################
	   [[ -e ${img}_filtered_${prefix}_confmat.1D ]] \
	      && mv -f ${img}_filtered_${prefix}_confmat.1D \
	      ${confmat[${cxt}]}
	   [[ -e ${img}_filtered_tmask.1D ]] \
	      && mv -f ${img}_filtered_tmask.1D ${tmask[${cxt}]}
	   [[ -e ${img}_filtered_derivs ]] \
	      && mv -f ${img}_filtered_derivs ${auxImgs[${subjidx}]}
	fi
fi
###################################################################
# Update image pointer
###################################################################
img=${img}_filtered
echo "Processing step complete: temporal filtering"





###################################################################
# Next, censor the BOLD timeseries for the last time according to
# user instructions.
###################################################################
if [[ "${censor[${subjidx}]}" != "none" ]]
	then
	echo ""; echo ""
   echo "Current processing step:"
   echo "Censoring BOLD timeseries"
   echo "${censor[${subjidx}]} censoring"
   echo "Applying the final censor..."
	################################################################
	# Retrieve the temporal mask that indicates whether each
	# volume should be censored or left intact.
	#  * If a temporal mask has been generated by this module, then
	#    it should be the most up-to-date version of the temporal
	#    mask.
	#  * Otherwise, the subject-level temporal mask is used.
	#  * Notify the user if censoring has been requested but the
	#    module is unable to locate a temporal mask.
	################################################################
	if [[ -e ${tmask[${cxt}]} ]]
	   then
	   tmaskpath=$(ls -d1 ${tmask[${cxt}]})
	elif [[ -e ${tmask[${subjidx}]} ]]
	   then
	   tmaskpath=$(ls -d1 ${tmask[${subjidx}]})
	else
	   echo "WARNING: Censoring of high-motion volumes requires a"
	   echo "temporal mask, but the regression module has failed"
	   echo "to find one. You are advised to inspect your pipeline"
	   echo "to ensure that this is intentional."
	   echo ""
	   echo "Overriding user input:"
	   echo "No censoring will be performed."
	   censor[${subjidx}]=none
	   echo "censor[${subjidx}]=${censor[${subjidx}]}" \
	      >> ${design_local}
	fi
fi
###################################################################
# Check the conditional again in case the value of censoring has
# been changed due to a failure to locate the temporal mask.
###################################################################
if [[ "${censor[${subjidx}]}" != "none" ]]
	then
	################################################################
	# Create copies of the precensored timeseries for reference.
	################################################################
	cp ${img}${ext} ${outdir}/${prefix}_uncensored${ext}
	cp ${confmat[${cxt}]} ${outdir}/${prefix}_confmat_uncensored.1D
	################################################################
	# Use the temporal mask to determine which volumes are to be
	# left intact.
	#
	# Censoring is performed using the censor utility.
	################################################################
	${XCPEDIR}/utils/censor.R \
	   -t ${tmaskpath} \
	   -i ${img}${ext} \
	   -o ${img}_censored${ext} \
	   -d ${auxImgs[${subjidx}]} \
	   -s ${confmat[${cxt}]}
	################################################################
	# Move the outputs of the censor utility to appropriate
	# destinations, and update the path to the image.
	################################################################
	mv ${img}_censored_derivs ${auxImgs[${subjidx}]}
	mv ${img}_censored*confmat*.1D ${confmat[${cxt}]}
	img=${img}_censored
	################################################################
	# Compute and write the number of volumes censored.
	################################################################
	nvol_pre=$(fslval ${outdir}/${prefix}_uncensored dim4)
	nvol_post=$(fslval ${img} dim4)
	nvol_censored=$(expr ${nvol_pre} - ${nvol_post})
	echo ${nvol_censored} >> ${qavol[${cxt}]}
fi





###################################################################
# Alternatively, add spike regressors into the model.
###################################################################
if [[ ${regress_spkreg[${cxt}]} == Y ]] \
   && [[ -e ${tmask[${subjidx}]} ]]
   then
   ################################################################
   # Make sure that there are any spikes to regress.
   ################################################################
   if [[ $(cat ${tmask[${subjidx}]}|grep -i 0|wc -l) == 0 ]]
      then
      regress_spkreg[${cxt}]=N
      echo "regress_spkreg[${cxt}]=N" >> ${design_local}
   else
      ${XCPEDIR}/utils/tmask2spkreg.R \
         -t ${tmask[${subjidx}]} \
         -r ${confmat[${cxt}]} \
         >> ${confmat[${cxt}]}~TEMP~
      mv ${confmat[${cxt}]}~TEMP~ \
         ${confmat[${cxt}]}
   fi
fi





###################################################################
# Finally, compute the residual BOLD timeseries by computing a
# linear model incorporating all nuisance variables.
###################################################################
echo ""; echo ""; echo ""
echo "Current processing step:"
echo "Converting BOLD timeseries to confound residuals"
###################################################################
# If the conditions required to bypass tfilter were satisfied,
# then filtering and the linear model would have been combined
# into a single step, and residuals would already be present.
###################################################################
if [[ ${has_residuals} == 1 ]]
   then
   echo "But confound residuals have already been computed!"
###################################################################
# Otherwise, determine whether it is necessary to run the linear
# model.
###################################################################
elif [[ $(imtest "${img}_residuals") != "1" ]] \
   || [ "${regress_rerun[${cxt}]}" != "N" ]
   then
	################################################################
	# Obtain the confound matrix. If the confound matrix has been
	# processed in any way, then there should exist a module-
	# specific version of the file. Otherwise, the subject-level
	# version in the design file can be used.
	################################################################
	if [[ -e ${confmat[${cxt}]} ]]
	   then
	   confmat=${confmat[${cxt}]}
	else
	   confmat=${confmat[${subjidx}]}
	fi
	################################################################
	# Compute the internal correlations within the confound
	# matrix.
	################################################################
	${XCPEDIR}/utils/ts2adjmat.R \
	   -t ${confmat} \
	   >> ${confcor[${cxt}]}
	################################################################
	# Update paths to any local regressors.
	################################################################
	locregs=$(ls -d1 ${outdir}/*filtered_loc* 2>/dev/null)
	################################################################
   # Compute the best fit for any timeseries in the confound
   # model.
	################################################################
#   echo "Computing beta weights..."
#   3dTfitter -overwrite \
#      -polort 4 \
#      -RHS ${img}${ext} \
#      -LHS ${confmat} \
#         ${locregs} \
#      -fitts ${img}_predictedFit${ext} \
#      -prefix ${img}_paramest${ext}
	################################################################
   # Execute the detrend
	################################################################
   echo "Executing detrend..."
#   3dcalc -overwrite \
#      -float \
#      -a ${img}${ext} \
#      -b ${img}_predictedFit${ext} \
#      -expr 'a-b' \
#      -prefix ${img}_residuals${ext}
   rm -f ${img}_residuals${ext}
   for lr in ${locregs}
      do
      locregopt="${locregopt} -dsort ${lr}"
   done
   3dTproject \
      -input ${img}${ext} \
      -ort ${confmat} \
      ${locregopt} \
      -prefix ${img}_residuals${ext} \
      2>/dev/null
   if [[ $(imtest ${img}_residuals) == 1 ]]
      then
      img=${img}_residuals
   else
      echo "::XCP-ERROR: The confound regression procedure failed."
      exit 666
   fi
fi
echo "Processing step complete: motion residuals"





###################################################################
# Apply the desired smoothing kernels to the BOLD timeseries.
#  * First, identify all kernels to apply.
###################################################################
smo=$(echo ${regress_smo[${cxt}]}|sed s@','@' '@g)
###################################################################
# SUSAN setup
###################################################################
if [[ "${regress_sptf[${cxt}]}" == susan ]] \
   && [[ -n ${smo} ]]
   then
   ################################################################
   # Determine whether a custom USAN is being used.
   ################################################################
   if [[ $(imtest ${regress_usan[${cxt}]}) == 1 ]]
      then
      #############################################################
      # Acquire all transforms
      #############################################################
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
      #############################################################
      # Use the space in which the USAN is situated and
      # the space in which the analyte is situated to determine
      # how to register the USAN to analyte space.
      #############################################################
      case ${regress_usan_space[${cxt}]}2${space} in
      nat2native)
         rm -f ${img}usan${ext}
         ln -s ${regress_usan[${cxt}]} ${img}usan${ext}
         ;;
      str2native)
         rm -f ${img}usan${ext}
         ${ANTSPATH}/antsApplyTransforms \
            -e 3 -d 3 \
            -i ${regress_usan[${cxt}]} \
            -o ${img}usan${ext} \
            -r ${referenceVolume[${subjidx}]}${ext} \
            $icoreg \
            -n NearestNeighbor
         ;;
      std2native)
         rm -f ${img}usan${ext}
         ${ANTSPATH}/antsApplyTransforms \
            -e 3 -d 3 \
            -i ${regress_usan[${cxt}]} \
            -o ${img}usan${ext} \
            -r ${referenceVolume[${subjidx}]}${ext} \
            $icoreg \
            $irigid \
            $iaffine \
            $iwarp \
            $iresample \
            -n NearestNeighbor
         ;;
      nat2standard)
         rm -f ${img}usan${ext}
         ${ANTSPATH}/antsApplyTransforms \
            -e 3 -d 3 \
            -i ${regress_usan[${cxt}]} \
            -o ${img}usan${ext} \
            -r ${template} \
            $resample \
            $warp \
            $affine \
            $rigid \
            $coreg \
            -n NearestNeighbor
         ;;
      str2standard)
         rm -f ${img}usan${ext}
         ${ANTSPATH}/antsApplyTransforms \
            -e 3 -d 3 \
            -i ${regress_usan[${cxt}]} \
            -o ${img}usan${ext} \
            -r ${template} \
            $resample \
            $warp \
            $affine \
            $rigid \
            -n NearestNeighbor
         ;;
      std2standard)
         rm -f ${img}usan${ext}
         ln -s ${regress_usan[${cxt}]} ${img}usan${ext}
         ;;
      esac
      usan="-u ${img}usan"
      hardseg="-h"
   ################################################################
	# Otherwise, ensure that an example functional image exists.
	#  * If it does not, then you are probably doing
	#    something stupid.
	#  * In this case, force a switch to uniform
	#    smoothing to mitigate the catastrophe.
   ################################################################
   elif [[ $(imtest ${referenceVolumeBrain[${subjidx}]}) == 1 ]]
      then
      usan="-u ${referenceVolumeBrain[${subjidx}]}"
   else
      regress_sptf[${cxt}]=uniform
      echo "regress_sptf[${cxt}]=${regress_sptf[${cxt}]}" \
         >> ${design_local}
   fi
fi
###################################################################
#  * Next, iterate through all kernels and apply them.
###################################################################
for ker in ${smo}
   do
   img_sm_name=sm${ker}
   img_sm=img_sm${ker}[${subjidx}]
   if [[ $(imtest ${!img_sm}) == 1 ]]
      then
      img_sm=${!img_sm}
   ################################################################
   # Determine whether an image with the specified smoothing
   # kernel already exists
   ################################################################
   elif [[ $(imtest ${final[${cxt}]}_sm${ker}) == 1 ]]
      then
      img_sm=${final[${cxt}]}_sm${ker}
      echo "img_sm${ker}[${subjidx}]=${img_sm}" >> ${design_local}
      echo "#${img_sm_name}#${img}" >> ${auxImgs[${subjidx}]}
   ################################################################
   # If no spatial filtering has been specified by the user, then
   # bypass this step.
   ################################################################
   elif [[ ${regress_sptf[${cxt}]} == none ]] \
      || [[ ${ker} == 0 ]]
      then
      img_sm=${img}
   else
      echo ""; echo ""; echo ""
      echo "Current processing step:"
      echo "Spatially filtering image"
      echo "Filter: ${regress_sptf[${cxt}]}"
      echo "Smoothing kernel: ${ker} mm"
      #############################################################
	   # Ensure that this step has not already run to completion
	   # by checking for the existence of a smoothed image.
      #############################################################
      if [[ $(imtest ${img}_${cur}) != "1" ]] \
         || [[ "${regress_rerun[${cxt}]}" == "Y" ]]
         then
         ##########################################################
	      # Obtain the mask over which smoothing is to be applied
	      # Begin by searching for the subject mask; if this does
	      # not exist, then search for a mask created by this
	      # module.
         ##########################################################
         if [[ $(imtest ${mask[${subjidx}]}) == "1" ]]
            then
            mask=${mask[${subjidx}]}
         else
            echo "Unable to locate mask."
            echo "Generating a mask using 3dAutomask"
            3dAutomask -prefix ${img}_fmask${ext} \
               -dilate 3 \
               -q \
               ${img}${ext} \
               2>/dev/null
            susanmask=${img}_fmask${ext}
         fi
         ##########################################################
	      # If the user has requested command tracing, propagate
	      # that request into the sfilter routine.
         ##########################################################
	      [[ ${trace} == 1 ]] && trace_prop="-t"
         ##########################################################
	      # Engage the sfilter routine to filter the image.
	      #  * This is essentially a wrapper around the three
	      #    implemented smoothing routines: gaussian, susan,
	      #    and uniform.
         ##########################################################
	      ${XCPEDIR}/utils/sfilter \
	         -i ${img} \
	         -o ${img}sm${ker} \
	         -s ${regress_sptf[${cxt}]} \
	         -k ${ker} \
	         -m ${mask} \
	         ${usan} \
	         ${hardseg} \
	         ${trace_prop}
	      immv ${img}sm${ker} ${final[${cxt}]}_sm${ker}
	   fi
      #############################################################
      # Update image pointer, and write the smoothed image path to
      # the design file and derivatives index so that it may be used
      # by additional modules.
      #############################################################
      img_sm=${final[${cxt}]}_sm${ker}
      echo "img_sm${ker}[${subjidx}]=${img_sm}" >> ${design_local}
      echo "#${img_sm_name}#${img_sm}" >> ${auxImgs[${subjidx}]}
      echo "Processing step complete: spatial filtering"
   fi
done





immv ${img} ${final[${cxt}]}





###################################################################
# write remaining output paths to local design file so that
# they may be used further along the pipeline
###################################################################
echo ""; echo ""; echo ""
echo "Writing outputs..."
rm -f ${out}/${prefix}${ext}
ln -s ${final[${cxt}]}${ext} ${out}/${prefix}${ext}
echo "confmat[${subjidx}]=${confmat[${cxt}]}" >> ${design_local}
echo "confcor[${subjidx}]=${confcor[${cxt}]}" >> ${design_local}
if [[ -e ${qavol[${cxt}]} ]]
   then
   qvars=${qvars},nframesCensored
   qvals=${qvals},$(cat ${qavol[${cxt}]})
fi





###################################################################
# CLEANUP
#  * Remove any temporary files if cleanup is enabled.
#  * Update the audit file and quality index.
###################################################################
if [[ "${regress_cleanup[${cxt}]}" == "Y" ]]
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
