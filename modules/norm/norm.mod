#!/usr/bin/env bash

###################################################################
#  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  #
###################################################################

###################################################################
# Constants: none yet
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
echo "###################################################################"
echo "#  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  #"
echo "#                                                                 #"
echo "#  ☭              EXECUTING NORMALISATION MODULE               ☭  #"
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
outdir=${out}/${prep}norm
[[ ! -e ${outdir} ]] && mkdir -p ${outdir}
echo "Output directory is $outdir"
###################################################################
# Define paths to all potential outputs.
#
# For the norm module, potential outputs include:
#  * std : the primary BOLD timeseries, in standard space
#  * quality : a comma-separated list of values for quality-control
#    variables; can be used as an aid to determine the quality of
#    normalisation
#  * auxImgs : a path to an index of derivative images, after they
#    have been processed by this module (and consequently moved)
#    into standard space
###################################################################
std[${cxt}]=${outdir}/${prefix}_std
quality[${cxt}]=${outdir}/${prefix}_normQuality.csv
auxImgs[${cxt}]=${out}/${prefix}_derivsNorm
rm -f ${auxImgs[${cxt}]}
###################################################################
# Remnants of the legacy version: should affect nothing unless
# you manually add them to your design file.
#
# Support for these parameters will probably be dropped in the
# future as we switch into an ANTs-based system.
###################################################################
coreg[${cxt}]=${outdir}/${prefix}_coreg.txt
referenceVolume[${cxt}]=${outdir}/${prefix}_referenceVolumeStd
meanIntensity[${cxt}]=${outdir}/${prefix}_meanIntensityStd
mask[${cxt}]=${outdir}/${prefix}_maskStd
combined[${cxt}]=${outdir}/ep2mni_warp
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
   || [ "${norm_rerun[${cxt}]}" == "Y" ]
   then
   rm -f ${img}${ext}
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
echo "# *** outputs from norm[${cxt}] *** #" >> $design_local
echo "" >> $design_local
###################################################################
# Verify that the module should be run:
#  * Test whether the final output already exists.
#  * Determine whether the user requested the module to be re-run.
# If it is determined that the module should not be run, then any
#  outputs must be written to the local design file.
#
# This has been replaced with a system wherein the primary image
# and each derivative is checked separately.
###################################################################
#if [[ $(imtest ${std[${cxt}]}) == 1 ]] \
#   && [[ ${norm_rerun[${cxt}]} == "N" ]]
#   then
#   echo "Normalisation has already run to completion."
#   echo "Writing outputs..."
#   rm -f ${out}/${prefix}${ext}
#   ln -s ${std[${cxt}]}${ext} ${out}/${prefix}${ext}
#   echo "space=standard" >> $design_local
#   echo "auxImgs[${subjidx}]=${auxImgs[${cxt}]}" >> $design_local
#   if [[ -e "${quality[${cxt}]}" ]]
#      then
#      echo "coreg_quality[${subjidx}]=${quality[${cxt}]}" \
#         >> $design_local
#   fi
   ################################################################
   # Since it has been determined that the module does not need to
   # be executed, update the audit file and exit the module.
   ################################################################
#   prefields=$(echo $(grep -o "_" <<< $prefix|wc -l) + 1|bc)
#   modaudit=$(expr ${prefields} + ${cxt} + 1)
#   subjaudit=$(grep -i $(echo ${prefix}|sed s@'_'@','@g) ${audit})
#   replacement=$(echo ${subjaudit}\
#      |sed s@[^,]*@@${modaudit}\
#      |sed s@',,'@',1,'@ \
#      |sed s@',$'@',1'@g)
#   sed -i s@${subjaudit}@${replacement}@g ${audit}
#   echo "Module complete"
#   exit 0
#fi
###################################################################
###################################################################
# END GENERAL MODULE HEADER
###################################################################
###################################################################





###################################################################
# If the user has specified normalisation to MNI but has not
# provided a path to the MNI templates, then use the MNI paths in
# the alias dictionary to translate the template name into a
# path.
#
#TODO
# If the user has done this, then the pipeline is probably already
# broken since none of the derivatives modules have this feature
# in their normalisation steps.
###################################################################
if [[ $(imtest "${norm_template[${cxt}]}") == "0" ]]
   then
   norm_template[${cxt}]=$(grep -i \
      "${norm_template[${cxt}]}" ${XCPEDIR}/template_alias \
      |cut -d"," -f2)
   ################################################################
   # The above does not evaluate variables in the path, so we
   # must run this extra command.
   ################################################################
   norm_template[${cxt}]=$(eval echo ${norm_template[${cxt}]})
   echo "norm_template[${cxt}]=${norm_template[${cxt}]}" \
      >> ${design_local}
fi





###################################################################
# Determine what program the user has specified for normalisation.
#  * At this point in time, only ANTs-based normalisation has been
#    tested, and the remaining options are no longer supported.
###################################################################
case ${norm_prog[${cxt}]} in
   
   ants)
      echo ""; echo ""; echo ""
      echo "Current processing step:"
      echo "Normalising using ANTs"
      #############################################################
      # Add an argument for the coregistration.
      #############################################################
		coreg="-t ${seq2struct[${subjidx}]}"
      #############################################################
		# Determine which transforms need to be applied. At this
		# time, the module-scope norm variables are redundant copies
		# of the analysis-scope xfm variables. Only warps and affine
		# transforms will need to be applied unless the user has
		# manually added rigid or resample transforms.
      #############################################################
		echo "Selecting transforms to apply"
		if [[ $(imtest "${norm_warp[${cxt}]}") == 1 ]]
		   then
		   warp="-t ${norm_warp[${cxt}]}"
		else
		   warp=""
		fi
		if [[ ! -z ${norm_affine[${cxt}]} ]]
		   then
		   affine="-t ${norm_affine[${cxt}]}"
		else
		   affine=""
		fi
		if [[ ! -z ${norm_rigid[${cxt}]} ]]
		   then
		   rigid="-t ${norm_rigid[${cxt}]}"
		else
		   rigid=""
		fi
		if [[ ! -z ${norm_resample[${cxt}]} ]]
		   then
		   resample="-t ${norm_resample[${cxt}]}"
		else
		   resample=""
		fi
      #############################################################
		# Apply the transforms to the primary BOLD timeseries.
      #############################################################
      if [[ $(imtest ${std[${cxt}]}) != 1 ]] \
         || [[ ${norm_rerun[${cxt}]} == "Y" ]]
         then
		   echo "Applying composite diffeomorphism to primary BOLD timeseries"
         ${ANTSPATH}/antsApplyTransforms \
            -e 3 -d 3 \
            -i ${img}${ext} \
            -o ${std[${cxt}]}${ext} \
            -r ${norm_template[${cxt}]} \
            $resample \
            $warp \
            $affine \
            $rigid \
            $coreg
      fi
      #############################################################
      # Iterate through all derivative images, and apply
      # the computed transforms to each.
      #############################################################
      derivs=$(cat ${auxImgs[${subjidx}]})
		echo "Applying composite diffeomorphism to derivative images:"
      for curImg in ${derivs}
         do
         imgName=$(echo $curImg|cut -d"#" -f2)
         curImg=$(echo $curImg|cut -d"#" -f3)
		   echo " * ${imgName}"
         ##########################################################
         # Determine the extension of the current derivative
         # image.
         ##########################################################
         curpath=$(ls -d1 ${curImg}.*)
         [[ -z ${curpath} ]] && curpath=${curImg}
         for i in ${curpath}
            do
            [[ $(imtest ${i}) == 1 ]] && curpath=${i} && break
         done
         ##########################################################
         # If the image is a mask, apply nearest neighbour
         # interpolation to prevent introduction of intermediate
         # values
         ##########################################################
         interpol=""
         [[ -n $(echo ${imgName}|grep -i "mask") ]] && interpol="-n NearestNeighbor"
         ##########################################################
         # Warp
         ##########################################################
         if [[ $(imtest ${outdir}/${prefix}_${imgName}Std) != 1 ]] \
            || [[ ${norm_rerun[${cxt}]} == "Y" ]]
            then
            ${ANTSPATH}/antsApplyTransforms \
               -e 3 -d 3 \
               -i ${curImg}${ext} \
               -o ${outdir}/${prefix}_${imgName}Std${ext} \
               -r ${norm_template[${cxt}]} \
               $interpol \
               $resample \
               $warp \
               $affine \
               $rigid \
               $coreg
         fi
         echo "${imgName}[${subjidx}]=${outdir}/${prefix}_${imgName}Std" \
            >> $design_local
         echo "#${imgName}#${outdir}/${prefix}_${imgName}Std" \
            >> ${auxImgs[${cxt}]}
      done
      #############################################################
      # Prepare quality variables and a cross-sectional view for
      # the example functional brain
      #############################################################
      if [[ -e ${outdir}/${prefix}_referenceVolumeBrainStd${ext} \
         && ! -e ${outdir}/${prefix}_ep2std.png ]] \
         || [[ ${norm_rerun[${cxt}]} != N ]]
         then
         echo ""; echo ""; echo ""
         echo "Current processing step:"
         echo "Quality control"
         ln -s ${template} ${outdir}/template${ext}
         rm -f ${quality[${cxt}]}
         xfunc2std=${outdir}/${prefix}_referenceVolumeBrainStd
         fslmaths ${xfunc2std} -bin ${img}ep2std_mask
         fslmaths ${template} -bin ${img}template_mask
#         fslmaths ${img}ep2std_mask \
#            -sub ${img}template_mask \
#            -thr 0 \
#            -bin \
#            ${img}ep2std_maskdiff
         fslmaths ${img}template_mask \
            -sub ${img}ep2std_mask \
            -thr 0 \
            -bin \
            ${img}std_maskdiff
         qa_vol_std=$(fslstats ${img}template_mask -V\
            |awk '{print $2}')
#         qa_vol_ep2std=$(fslstats ${img}ep2std_mask -V\
#            |awk '{print $2}')
         qa_vol_diff=$(fslstats ${img}std_maskdiff -V\
            |awk '{print $2}')
         qa_cov_obs=$(echo "scale=10; 1 - ${qa_vol_diff} / ${qa_vol_std}"|bc)
#         qa_cov_max=$(echo "scale=10; ${qa_vol_seq2struct} / ${qa_vol_struct}"|bc)
#         [[ $(echo "${qa_cov_max} > 1"|bc -l) == 1 ]] && qa_cov_max=1
         qa_cov_max=1
         qa_coverage=$(echo "scale=10; ${qa_cov_obs} / ${qa_cov_max}"|bc)
         qa_cc=$(fslcc -p 8 ${img}ep2std_mask ${img}template_mask\
            |awk '{print $3}')
         echo "Cross-correlation: ${qa_cc}"
         echo "Coverage: ${qa_coverage}"
         echo "normCrossCorr,normCoverage"\
            >> ${quality[${cxt}]}
         echo "${qa_cc},${qa_coverage}"\
            >> ${quality[${cxt}]}
#         qa_miss_struct=$(fslstats ${img}ep2std_maskdiff -V\
#            |awk '{print $2}')
#         qa_miss_seq2struct=$(fslstats ${img}std_maskdiff -V\
#            |awk '{print $2}')
#         qa_miss_vox=$(echo ${qa_miss_struct} \* ${qa_miss_seq2struct}\
#            |bc)
#         echo "normCrossCorr,norm_nvoxel_ep2std_not_covered,norm_nvoxel_std_not_covered,norm_coverage_product"\
#            >> ${quality[${cxt}]}
#         echo ${qa_cc},${qa_miss_struct},${qa_miss_seq2struct},${qa_miss_vox}\
#            >> ${quality[${cxt}]}
         slicer ${xfunc2std} ${template} \
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
            ${outdir}/${prefix}_ep2std1.png
         slicer ${template} ${xfunc2std} \
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
            ${outdir}/${prefix}_ep2std2.png
         pngappend ${outdir}/${prefix}_ep2std1.png \
            - ${outdir}/${prefix}_ep2std2.png \
            ${outdir}/${prefix}_ep2std.png
         rm -f ${outdir}/${prefix}_sl*.png \
            ${outdir}/${prefix}_ep2std1.png \
            ${outdir}/${prefix}_ep2std2.png
         echo "Processing step complete:"
         echo "Quality control"
      fi
      ;;
      
   dramms)
      echo ""; echo ""; echo ""
      echo "DRAMMS-based normalisation is not supported at this"
      echo "time. Please use ANTs-based normalisation instead."
      ;;
      
   fnirt)
      echo ""; echo ""; echo ""
      echo "FNIRT-based normalisation is not supported at this"
      echo "time. Please use ANTs-based normalisation instead."
      ;;
      
esac

###################################################################
# write remaining output paths to local design file so that
# they may be used further along the pipeline
###################################################################
echo ""; echo ""; echo ""
echo "Writing outputs..."
# move standardised image to output
rm -f ${out}/${prefix}${ext}
ln -s ${std[${cxt}]}${ext} ${out}/${prefix}${ext}
echo "space=standard" >> $design_local
echo "auxImgs[${subjidx}]=${auxImgs[${cxt}]}" >> $design_local
if [[ -e "${quality[${cxt}]}" ]]
   then
   qvars=${qvars},$(head -n1 ${quality[${cxt}]})
   qvals=${qvals},$(tail -n1 ${quality[${cxt}]})
   echo "norm_quality[${subjidx}]=${quality[${cxt}]}" \
      >> $design_local
fi





###################################################################
# CLEANUP
#  * Remove any temporary files if cleanup is enabled.
#  * Update the audit file and quality index.
###################################################################
if [[ "${norm_cleanup[${cxt}]}" == "Y" ]]
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
