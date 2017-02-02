#!/usr/bin/env bash

###################################################################
#  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  #
###################################################################

###################################################################
# ICA-AROMA-like denoising procedure
###################################################################

###################################################################
# Constants
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
echo "#  ☭                EXECUTING ICA-AROMA MODULE                 ☭  #"
echo "#                                                                 #"
echo "#  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  #"
echo "###################################################################"
echo ""
###################################################################
# Source the design file.
###################################################################
source ${design_local}
###################################################################
# Create a directory for intermediate outputs.
###################################################################
[[ ${NUMOUT} == 1 ]] && prep=${cxt}_
outdir=${out}/${prep}aroma
[[ ! -e ${outdir} ]] && mkdir -p ${outdir}
echo "Output directory is $outdir"
###################################################################
# Define paths to all potential outputs.

# For the ICA-AROMA module, potential outputs include:
#  * 
#  * final : The final output of the module, indicating its
#    successful completion. This is the data after it is denoised
#    using the ICA-AROMA procedure.
###################################################################
melodir[${cxt}]=${outdir}/melodic
icmaps[${cxt}]=${outdir}/melodic/melodic_IC
icmaps_thr[${cxt}]=${outdir}/melodic/melodic_IC_thr
icmaps_thr_std[${cxt}]=${outdir}/melodic/melodic_IC_thr_std
icmix[${cxt}]=${outdir}/melodic/melodic_mix
classmat[${cxt}]=${outdir}/${prefix}_class.csv
final[${cxt}]=${outdir}/${prefix}_icaDenoised
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
outbase=${outdir}/${prefix}~TEMP~
if [[ $(imtest ${img}) != "1" ]] \
   || [[ "${aroma_rerun[${cxt}]}" == "Y" ]]
   then
   rm -f ${img}
   ln -s ${out}/${prefix}${ext} ${img}${ext}
fi
imgpath=$(ls ${img}${ext})
###################################################################
# Prime the localised design file so that any outputs from this
# module appear beneath the correct header.
###################################################################
echo "" >> $design_local
echo "# *** outputs from aroma[${cxt}] *** #" >> $design_local
echo "" >> $design_local
###################################################################
# Verify that the module should be run:
#  * Test whether the final output already exists.
#  * Determine whether the user requested the module to be re-run.
# If it is determined that the module should not be run, then any
#  outputs must be written to the local design file.
###################################################################
if [[ $(imtest ${final[${cxt}]}) == 1 ]] \
   && [[ ${aroma_rerun[${cxt}]} == "N" ]]
   then
   echo "ICA-AROMA has already run to completion."
   echo "Writing outputs..."
   rm -f ${out}/${prefix}${ext}
   ln -s ${final[${cxt}]}${ext} ${out}/${prefix}${ext}
   
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
# Apply the desired smoothing kernel to the BOLD timeseries.
###################################################################
if [[ -n ${aroma_smo[${cxt}]} ]] \
   && [[ ${aroma_smo[${cxt}]} -gt 0 ]]
   then
   echo ""; echo ""; echo ""
   echo "Current processing step:"
   echo "Spatially filtering image"
   echo "Filter: ${aroma_sptf[${cxt}]}"
   echo "Smoothing kernel: ${aroma_smo[${cxt}]} mm"
   ################################################################
	# Ensure that this step has not already run to completion
	# by checking for the existence of a smoothed image.
   ################################################################
   img_sm=${outdir}/${prefix}_sm${sca_smo[${cxt}]}
   if [[ $(imtest ${img_sm}) != "1" ]] \
      || [[ "${aroma_rerun[${cxt}]}" == "Y" ]]
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
      if [[ "${aroma_sptf[${cxt}]}" == susan ]]
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
            ${aroma_sptf[${cxt}]}=uniform
            echo "aroma_sptf[${cxt}]=${aroma_sptf[${cxt}]}" \
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
	      -o ${img_sm} \
	      -s ${aroma_sptf[${cxt}]} \
	      -k ${aroma_smo[${cxt}]} \
	      -m ${mask} \
	      ${usan} \
	      ${trace_prop}
	fi
   ################################################################
   # Update image pointer for the purpose of MELODIC.
   ################################################################
   img_in=${img_sm}
   echo "Processing step complete: spatial filtering"
else
   img_in=${img}
fi





###################################################################
# Use MELODIC to decompose the data into independent components.
# First, determine whether the user has specified the model order.
# If not, then MELODIC will automatically estimate it.
###################################################################
echo ""; echo ""; echo ""
echo "Current processing step:"
echo "ICA decomposition (MELODIC)"
[[ ${aroma_dim[${cxt}]} != auto ]] \
   && melodim="--dim=${aroma_dim[${cxt}]}"
###################################################################
# Obtain the repetition time.
###################################################################
trep=$(fslval ${img} pixdim4)
###################################################################
# Determine whether it is necessary to run MELODIC.
###################################################################
if [[ $(imtest ${icmaps[${cxt}]}) != 1  || ! -e ${icmix[${cxt}]} ]] \
   || [[ ${aroma_rerun[${cxt}]} == Y ]]
   then
   ################################################################
   # Preclude autosubmission to the grid, MELODIC may be
   # configured for autosubmission
   ################################################################
   buffer=${SGE_ROOT}
   unset SGE_ROOT
   melodic \
      --in=${img_in} \
      --outdir=${melodir[${cxt}]} \
      --mask=${mask[${subjidx}]} \
      ${melodim} \
      --Ostats \
      --nobet \
      --mmthresh=0.5 \
      --report \
      --tr=${trep}
   SGE_ROOT=${buffer}
fi
extname=$(ls ${outdir}/*.ica 2>/dev/null)
[[ -n ${extname} ]] && mv -f ${extname} ${melodir[${cxt}]}
###################################################################
# Read in the dimension of the results (number of components
# obtained).
###################################################################
icdim=$(fslval ${icmaps[${cxt}]} dim4)
###################################################################
# Concatenate the mixture-modelled, thresholded spatial maps of
# the independent components.
#
# Iterate through all components.
###################################################################
curidx=1
while [[ ${curidx} -le ${icdim} ]]
   do
   ################################################################
   # Obtain the thresholded standard-scored spatial map of the
   # current component.
   # * If there are multiple maps for this IC, then extract only
   #   the last. According to the original implementation of
   #   ICA-AROMA, this occurs if the mixture modelling step fails
   #   to converge.
   ################################################################
   padidx=$(zeropad ${curidx} 4)
   zmapIn=${melodir[${cxt}]}/stats/thresh_zstat${curidx}
   zmapOut=${melodir[${cxt}]}/stats/thresh_zstat_${padidx}
   iclength=$(fslval ${zmapIn} dim4|cut -d'.' -f1)
   finalMapIdx=$(expr ${iclength} - 1)
   fslroi ${zmapIn} ${zmapOut} ${finalMapIdx} 1
   ################################################################
   # * Add the updated standard-scored map to the list of images
   #   to be concatenated.
   ################################################################
   toMerge="${toMerge} ${zmapOut}"
   curidx=$(expr ${curidx} + 1)
done
###################################################################
# Concatenate and delete temporary files.
###################################################################
fslmerge -t ${icmaps_thr[${cxt}]} ${toMerge}
[[ ${aroma_cleanup[${cxt}]} == Y ]] && rm -f ${toMerge}
###################################################################
# Mask the thresholded component maps.
###################################################################
fslmaths ${icmaps_thr[${cxt}]} \
   -mas ${mask[${subjidx}]} \
   ${icmaps_thr[${cxt}]}
echo "Processing step complete: ICA decomposition"





###################################################################
# Prepare masks for component classification.
# * Obtain all transforms.
###################################################################
echo ""; echo ""; echo ""
echo "Current processing step:"
echo "Extracting features: CSF and edge fractions"
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
# * Move the edge, CSF, and background masks into the same space as
#   the image.
###################################################################
if [[ ${space} == native ]]
   then
   if [[ $(imtest ${icmaps_thr_std[${cxt}]}) != 1 ]] \
      || [[ ${aroma_rerun[${cxt}]} == Y ]]
      then
      rm -f ${icmaps_thr_std[${cxt}]}${ext}
      ${ANTSPATH}/antsApplyTransforms \
         -e 3 -d 3 \
         -i ${icmaps_thr[${cxt}]}${ext} \
         -o ${icmaps_thr_std[${cxt}]}${ext} \
         -r ${template} \
         $resample \
         $warp \
         $affine \
         $rigid \
         $coreg \
         -n NearestNeighbor
   fi
else
   icmaps_thr_std[${cxt}]=${icmaps_thr[${cxt}]}
fi
###################################################################
# TODO (or perhaps not)
# Subject-specific mask generation. Absolutely not validated,
# and no a priori evidence that this is a good idea, so I may not
# come back to it. The following steps are listed here as a vague
# guideline for how this might be done.
# * Generate the CSF mask. Restrict this to the ventricles by
#   intersecting it with an eroded whole-brain mask. Dilate to
#   smooth the surface. Or perhaps simply erode then dilate to
#   trim periphery.
# * Subtract the CSF mask from a conservative whole-brain mask as
#   the initial basis for an edge mask.
# * Erode the edge mask precursor.
# * Subtract the eroded precursor from the preliminary precursor
#   to obtain a finalised edge mask.
###################################################################
csf[${cxt}]=${aroma_csf[${cxt}]}
edge[${cxt}]=${aroma_edge[${cxt}]}
bg[${cxt}]=${aroma_bg[${cxt}]}





###################################################################
# Obtain the CSF and edge fraction features for each IC.
###################################################################
i=0
while [[ ${i} -lt ${icdim} ]]
   do
   ################################################################
   # * Extract the current z-scored IC.
   ################################################################
   fslroi ${icmaps_thr_std[${cxt}]} ${outbase}IC ${i} 1
   ################################################################
   # * Change to absolute value of z-score.
   ################################################################
   fslmaths ${outbase}IC -abs ${outbase}IC
   ################################################################
   # * Obtain the total absolute z-score for this component.
   ################################################################
   totMean=0
   totVox=$(fslstats ${outbase}IC -V|awk '{print $1}')
   [[ ${totVox} != 0 ]] \
      && totMean=$(fslstats ${outbase}IC -M)
   totSum=$(echo "${totVox} * ${totMean}"|bc -l)
   ################################################################
   # * Obtain the total z-score within the CSF compartment.
   ################################################################
   csfMean=0
   csfVox=$(fslstats ${outbase}IC \
      -k ${csf[${cxt}]} \
      -V|awk '{print $1}')
   [[ ${csfVox} != 0 ]] \
      && csfMean=$(fslstats ${outbase}IC -k ${csf[${cxt}]} -M)
   csfSum=$(echo "${csfVox} * ${csfMean}"|bc -l)
   ################################################################
   # * Obtain the total z-score within the edge mask.
   ################################################################
   edgeMean=0
   edgeVox=$(fslstats ${outbase}IC \
      -k ${edge[${cxt}]} \
      -V|awk '{print $1}')
   [[ ${edgeVox} != 0 ]] \
      && edgeMean=$(fslstats ${outbase}IC -k ${edge[${cxt}]} -M)
   edgeSum=$(echo "${edgeVox} * ${edgeMean}"|bc -l)
   ################################################################
   # * Obtain the total z-score located in the background mask.
   ################################################################
   bgMean=0
   bgVox=$(fslstats ${outbase}IC \
      -k ${bg[${cxt}]} \
      -V|awk '{print $1}')
   [[ ${bgVox} != 0 ]] \
      && bgMean=$(fslstats ${outbase}IC -k ${bg[${cxt}]} -M)
   bgSum=$(echo "${bgVox} * ${bgMean}"|bc -l)
   ################################################################
   # * Obtain the fractional z-score with CSF and edge/out masks.
   ################################################################
   if [[ ${totVox} == 0 ]]
      then
      classFCSF[${i}]=0
      classFEDGE[${i}]=0
   else
      classFCSF[${i}]=$(echo "${csfSum} / ${totSum}"|bc -l)
      classFEDGE[${i}]=$(echo "(${bgSum} + ${edgeSum}) / (${totSum} - ${csfSum})"|bc -l)
   fi
   ################################################################
   # * Cleanup: delete the extracted IC. Collate the fractional
   #   scores. Increment the IC index.
   ################################################################
   rm -f ${outbase}IC
   i=$(expr ${i} + 1)
done
echo "Processing step complete: extracting mask features"





###################################################################
# Obtain the maximum realignment parameter correlation feature
# for each IC.
# * Assemble realignment parameters into a 72-parameter model
#   that contains:
#   (6) realignment parameters;
#   (12) their temporal derivatives;
#   (36) forward- and reverse-shifted timeseries;
#   (72) squares of each.
###################################################################
echo ""; echo ""; echo ""
echo "Current processing step:"
echo "Extracting feature: maximum correlation with "
echo "   realignment parameters,"
confmat[${cxt}]=null
confmat_path=${outdir}/${prefix}_confmat.1D
${XCPEDIR}/utils/mbind.R \
   -x 'null' \
   -y ${rps[${subjidx}]} \
   -o ${confmat_path}
confmat[${cxt}]=${confmat_path}
${XCPEDIR}/utils/mbind.R \
   -x ${confmat[${cxt}]} \
   -y OPdx1 \
   -o ${confmat[${cxt}]}
${XCPEDIR}/utils/mbind.R \
   -x ${confmat[${cxt}]} \
   -y OPprev1 \
   -o ${confmat[${cxt}]}
${XCPEDIR}/utils/mbind.R \
   -x ${confmat[${cxt}]} \
   -y OPprev-1 \
   -o ${confmat[${cxt}]}
${XCPEDIR}/utils/mbind.R \
   -x ${confmat[${cxt}]} \
   -y OPpower2 \
   -o ${confmat[${cxt}]}
###################################################################
# * Assemble IC timeseries.
#   Also obtain the square of each.
###################################################################
icts=$(ls -d1 ${melodir[${cxt}]}/melodic_mix)
icts[${cxt}]=${outdir}/${prefix}_icts.1D
${XCPEDIR}/utils/mbind.R \
   -x ${icts} \
   -y OPpower2 \
   -o ${icts[${cxt}]}
###################################################################
# * Obtain the maximum absolute correlation between each IC
#   timeseries and the realignment parameters. Squared realignment
#   parameters should be matched to squared IC timeseries.
# * This should be computed as a robust correlation; 90 percent
#   of each timeseries is randomly sampled, and the correlations
#   between such sampled timeseries are computed 1000 times.
###################################################################
classRPCOR=($(${XCPEDIR}/modules/aroma/aromaRPCOR.R \
   -i ${icts[${cxt}]} \
   -r ${confmat[${cxt}]}))
echo "Processing step complete: RP correlation"





###################################################################
# Obtain the high-frequency content feature for each IC.
# This is the frequency (as a fraction of Nyquist) at which higher
# frequencies explain 50 percent of the total sampled power.
#
# NOTE: It is important to perform this prior to any filtering
# step.
###################################################################
echo ""; echo ""; echo ""
echo "Current processing step:"
echo "Extracting feature: high-frequency content"
icft=$(ls -d1 ${melodir[${cxt}]}/melodic_FTmix)
icft[${cxt}]=${outdir}/${prefix}_icft.1D
ln -s ${icft} ${icft[${cxt}]}
classHIFRQ=($(${XCPEDIR}/modules/aroma/aromaHIFRQ.R \
   -i ${icft[${cxt}]} \
   -t ${trep}))
echo "Processing step complete: high-frequency content"





###################################################################
# Write all componentwise features to a classification table.
###################################################################
echo ""; echo ""; echo ""
echo "Current processing step:"
echo "Component classification"
i=0
echo "ICID,RPCOR,FEDGE,FCSF,HFC" >> ${classmat[${cxt}]}
while [[ ${i} -lt ${icdim} ]]
   do
   echo ${i},${classRPCOR[${i}]},${classFEDGE[${i}]},${classFCSF[${i}]},${classHIFRQ[${i}]} >> ${classmat[${cxt}]}
   i=$(expr ${i} + 1)
done





###################################################################
# Apply the classification algorithm.
###################################################################
noiseIdx=$(${XCPEDIR}/modules/aroma/aromaCLASS.R \
   -m ${classmat[${cxt}]})
noiseComponents=$(echo ${noiseIdx}|wc -w)
echo "Processing step complete: classification"





###################################################################
# Denoise the image based on IC classes.
###################################################################
echo ""; echo ""; echo ""
echo "Current processing step:"
echo "Denoising"
noiseIdx=$(echo '"'${noiseIdx}'"'|sed s@' '@','@g)
fsl_regfilt \
   --in=${img} \
   --design=${icts[${cxt}]} \
   --filter=${noiseIdx} \
   --out=${outdir}/${prefix}_icaDenoised_nonaggr
fsl_regfilt \
   --in=${img} \
   --design=${icts[${cxt}]} \
   --filter=${noiseIdx} \
   -a \
   --out=${outdir}/${prefix}_icaDenoised_aggr
if [[ ${aroma_dtype[${cxt}]} == 'aggr' ]]
   then
   immv ${outdir}/${prefix}_icaDenoised_aggr ${final[${cxt}]}
elif [[ ${aroma_dtype[${cxt}]} == 'nonaggr' ]]
   then
   immv ${outdir}/${prefix}_icaDenoised_nonaggr ${final[${cxt}]}
fi
echo "Processing step complete: denoising"





###################################################################
# Detrend the denoised timeseries if detrending is requested.
#
# This should be run if you are applying a filter that is not
# 
###################################################################
echo ""; echo ""; echo ""
echo "Current processing step:"
echo "Demeaning and detrending BOLD timeseries"
echo "Polynomial order: ${aroma_dmdt[${cxt}]}"
###################################################################
# Verify that this step has not already run to completion:
# check for the associated image.
###################################################################
if [[ "${aroma_dmdt[${cxt}]}" != "N" ]] \
   || [[ "${aroma_rerun[${cxt}]}" == "Y" ]]
   then
   ################################################################
   # DMT uses a utility R script called DMDT to compute
   # the linear model residuals using ANTsR and pracma.
   # First, the inputs to DMDT must be obtained.
   # The first of these is the path to the image in its
   # currently processed state.
   ################################################################
   imgpath=$(ls -d1 ${final[${cxt}]}.*)
   ################################################################
   # Second, a spatial mask of the brain is necessary
   # for ANTsR to read in the image.
   #
   # If this mask was computed in a previous run or as
   # part of BXT above, then that mask can be used in
   # this step.
   ################################################################
   if [[ $(imtest ${mask[${subjidx}]}) == "1" ]]
      then
      echo "Using previously determined mask"
      maskpath=$(ls -d1 ${mask[${subjidx}]}.*)
   elif [[ $(imtest ${mask[${cxt}]}) == "1" ]]
      then
      echo "Using mask from this preprocessing run"
      maskpath=$(ls -d1 ${mask[${cxt}]}.*)
   ################################################################
	# If no mask has yet been computed for the subject,
	# then a new mask can be computed quickly using
	# AFNI's 3dAutomask tool.
   ################################################################
   else
      echo "Unable to locate mask."
      echo "Generating a mask using 3dAutomask"
      3dAutomask -prefix ${img}_fmask${ext} \
         -dilate 3 \
         -q \
         ${final[${cxt}]}${ext}
      maskpath=${img}_fmask${ext}
   fi
   ################################################################
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
   ################################################################
   if [[ -z "${censor[${cxt}]}" ]]
      then
      censor[${cxt}]=${censor[${subjidx}]}
   fi
   ################################################################
	# The temporal mask must be stored either in the
	# module-specific censor[cxt] variable or in the
	# subject-specific censor[subjidx] variable.
   ################################################################
   if [[ ! -z "${tmask[${cxt}]}" ]] \
      && [[ "${censor[${cxt}]}" == "iter" ]]
      then
      tmaskpath=$(ls -d1 ${tmask[${cxt}]})
   elif [[ ! -z "${tmask[${subjidx}]}" ]] \
      && [[ "${censor[${cxt}]}" == "iter" ]]
      then
      tmaskpath=$(ls -d1 ${tmask[${subjidx}]})
   ################################################################
   # If iterative censoring has not been specified or
   # if no temporal mask exists yet, then all time
   # points must be used in the linear model.
   ################################################################
   else
      tmaskpath=ones
   fi
   ################################################################
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
   ################################################################
	if [[ "${aroma_dmdt[${cxt}]}" == "auto" ]]
	   then
	   nvol=$(fslnvols ${final[${cxt}]})
      trep=$(fslinfo ${final[${cxt}]} \
         |grep pixdim4 \
         |awk '{print $2}' )
      aroma_dmdt[${cxt}]=$(echo $trep $nvol \
         |awk '{print 1 + $1 * $2 / 150}' \
         |cut -d"." -f1)
      echo "Automatically determined a"
      echo "   polynomial order of ${aroma_dmdt[${cxt}]}"
	fi
   ################################################################
	# Now, pass the inputs computed above to the detrend
	# function itself.
   ################################################################
   echo "Applying polynomial detrend"
   ${XCPEDIR}/utils/dmdt.R \
      -d "${aroma_dmdt[${cxt}]}" \
      -i "${final[${cxt}]}${ext}" \
      -m "${maskpath}" \
      -t "${tmaskpath}" \
      -o "${final[${cxt}]}${ext}"
fi
###################################################################
# Update image pointer
###################################################################
echo "Processing step complete: demeaning/detrending"





###################################################################
# write output paths to local design file so that
# they may be used further along the pipeline
###################################################################
echo ""; echo ""; echo ""
echo "Writing outputs..."
rm -f ${out}/${prefix}${ext}
ln -s ${final[${cxt}]}${ext} ${out}/${prefix}${ext}
echo "aromaClassmat[${subjidx}]=${classmat[${cxt}]}" >> ${design_local}
if [[ -n ${noiseComponents} ]]
   then
   qvars=${qvars},noiseComponents
   qvals=${qvals},${noiseComponents}
fi





###################################################################
# CLEANUP
#  * Remove any temporary files if cleanup is enabled.
#  * Update the audit file and quality index.
###################################################################
if [[ "${aroma_cleanup[${cxt}]}" == "Y" ]]
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
