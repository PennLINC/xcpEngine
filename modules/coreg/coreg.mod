#!/usr/bin/env bash

###################################################################
#  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  #
###################################################################

###################################################################
# Constants
# FIT will only be used if brain extraction has not already been
# performed on the reference volume.
###################################################################
FIT=0.3
readonly POSNUM='^[0-9]+([.][0-9]+)?$'
readonly ALTREG1=corratio
readonly ALTREG2=mutualinfo
readonly QADECIDE=qa_coverage




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
echo "#  ☭              EXECUTING COREGISTRATION MODULE              ☭  #"
echo "#                                                                 #"
echo "#  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  #"
echo "###################################################################"
echo ""
###################################################################
# Source the design file.
###################################################################
source ${design_local}
###################################################################
# Verify that all required inputs are present.
###################################################################
if [[ ${coreg_cfunc[${cxt}]} == bbr ]] \
   && [[ $(imtest ${coreg_seg[${cxt}]}) != 1 ]]
   then
   echo "::XCP-ERROR: BBR is selected as the cost function for"
   echo "  coregistration, but the segmentation provided is"
   echo "  invalid."
   exit 666
fi
if [[ $(imtest ${out}/${prefix}) != 1 ]] \
   && [[ $(imtest ${referenceVolume[${subjidx}]}) != 1 ]]
   then
   echo "::XCP-ERROR: A required input (reference volume) is "
   echo "  absent, as are the resources required to generate "
   echo "  this input."
   exit 666
fi
###################################################################
# Create a directory for intermediate outputs.
###################################################################
[[ ${NUMOUT} == 1 ]] && prep=${cxt}_
outdir=${out}/${prep}coreg
[[ ! -e ${outdir} ]] && mkdir -p ${outdir}
echo "Output directory is $outdir"
###################################################################
# Define paths to all potential outputs.

# For the coregistration module, potential outputs include:
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
#  * referenceVolumeBrain : The brain-extracted version of the
#    subject's example reference volume; this will probably
#    already have been obtained in prestats
###################################################################
seq2struct[${cxt}]=${outdir}/${prefix}_seq2struct.txt
struct2seq[${cxt}]=${outdir}/${prefix}_struct2seq.txt
e2smat[${cxt}]=${outdir}/${prefix}_seq2struct.mat
s2emat[${cxt}]=${outdir}/${prefix}_struct2seq.mat
e2simg[${cxt}]=${outdir}/${prefix}_seq2struct
s2eimg[${cxt}]=${outdir}/${prefix}_struct2seq
e2smask[${cxt}]=${outdir}/${prefix}_seq2structMask
s2emask[${cxt}]=${outdir}/${prefix}_struct2seqMask
quality[${cxt}]=${outdir}/${prefix}_coregQuality.csv
referenceVolume[${cxt}]=${outdir}/${prefix}_referenceVolume
referenceVolumeBrain[${cxt}]=${outdir}/${prefix}_referenceVolumeBrain
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
# Parse quality variables.
###################################################################
qvars=$(head -n1 ${quality} 2>/dev/null)
qvals=$(tail -n1 ${quality} 2>/dev/null)
###################################################################
# Prime the localised design file so that any outputs from this
# module appear beneath the correct header.
###################################################################
echo "" >> $design_local
echo "# *** outputs from coreg[${cxt}] *** #" >> $design_local
echo "" >> $design_local
###################################################################
# Verify that the module should be run:
#  * Test whether the final output already exists.
#  * Determine whether the user requested the module to be re-run.
# If it is determined that the module should not be run, then any
#  outputs must be written to the local design file.
###################################################################
if [[ -e ${seq2struct[${cxt}]} ]] \
   && [[ -e ${struct2seq[${cxt}]} ]] \
   && [[ -n $(cat ${quality[${cxt}]} 2>/dev/null) ]] \
   && [[ $(tail -n1 ${quality[${cxt}]}) != ',' ]] \
   && [[ ${coreg_rerun[${cxt}]} == "N" ]]
   then
   echo "Coregistration has already run to completion."
   echo "Writing outputs..."
   if [[ "${coreg_cleanup[${cxt}]}" == "Y" ]]
      then
      rm -rf ${outdir}/*~TEMP~*
   fi
   ################################################################
   # OUTPUT: seq2struct
   # Write the affine transform from reference to target
   # space to the localised design file.
   ################################################################
   echo "seq2struct[${subjidx}]=${seq2struct[${cxt}]}" \
      >> $design_local
   ################################################################
   # OUTPUT: struct2seq
   # Test whether the inverse transform from target to reference
   # space exists. If it does, add it to the localised design
   # file.
   ################################################################
   if [[ -e "${struct2seq[${cxt}]}" ]]
      then
      echo "struct2seq[${subjidx}]=${struct2seq[${cxt}]}" \
         >> $design_local
   fi
   ################################################################
   # OUTPUT: quality
   # Test whether a text file containing metrics of coregistration
   # quality exists. If it does, then add it to the localised
   # design file.
   ################################################################
   if [[ -e "${quality[${cxt}]}" ]]
      then
      echo "coreg_quality[${subjidx}]=${quality[${cxt}]}" \
         >> $design_local
      qvars=${qvars},$(head -n1 ${quality[${cxt}]})
	   qvals=${qvals},$(tail -n1 ${quality[${cxt}]})
   fi
   ################################################################
   # OUTPUT: e2simg e2smask s2eimg s2emask
   # Test whether each warped volume and each binarised mask exists
   # as an image. If it does, then add it to the localised design
   # file.
   ################################################################
   if [[ $(imtest ${s2eimg[${cxt}]}) == "1" ]]
      then
      echo "s2eimg[${subjidx}]=${s2eimg[${cxt}]}" >> $design_local
   fi
   if [[ $(imtest ${e2simg[${cxt}]}) == "1" ]]
      then
      echo "e2simg[${subjidx}]=${e2simg[${cxt}]}" >> $design_local
   fi
   if [[ $(imtest ${s2emask[${cxt}]}) == "1" ]]
      then
      echo "s2emask[${subjidx}]=${s2emask[${cxt}]}" >> $design_local
   fi
   if [[ $(imtest ${e2smask[${cxt}]}) == "1" ]]
      then
      echo "e2smask[${subjidx}]=${e2smask[${cxt}]}" >> $design_local
   fi
   ################################################################
   # OUTPUT: referenceVolume
   # Test whether a reference volume exists as an image. If
   # it does, add it to the index of derivatives and to
   # the localised design file.
   #
   # THIS SHOULD NOT EXIST IN NEARLY ANY CASE. If it does, ensure
   # that your pipeline is behaving as intended.
   ################################################################
   if [[ $(imtest ${referenceVolume[${cxt}]}) == "1" ]]
      then
      echo "referenceVolume[${subjidx}]=${referenceVolume[${cxt}]}" \
         >> $design_local
      echo "#referenceVolume#${referenceVolume[${cxt}]}" \
         >> ${auxImgs[${subjidx}]}
   fi
   ################################################################
   # OUTPUT: brain-extracted referenceVolume
   # Test whether a local brain-extracted reference volume exists.
   # In most cases, it will not, as the coregistration module only
   # performs brain extraction on the reference volume if
   # prestats or another module has not already done so. If it
   # does, add it to the index of derivatives and to the localised
   # design file.
   ################################################################
   if [[ $(imtest "${referenceVolumeBrain[${cxt}]}") == "1" ]]
      then
      echo "referenceVolumeBrain[${subjidx}]=${referenceVolumeBrain[${cxt}]}"\
         >> $design_local
      echo "#referenceVolumeBrain#${referenceVolumeBrain[${cxt}]}" \
         >> ${auxImgs[${subjidx}]}
   fi
   ################################################################
   # Since it has been determined that the module does not need to
   # be executed, update the audit file and exit the module.
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
# Coregistration is computed using a source reference volume
# and using the subject's structural scan as a target. Here,
# the source reference volume is an example volume,
# typically selected as the reference during the motion
# realignment phase of analysis.
#
# Before coregistration can be performed, the coregistration
# module must obtain a pointer to this source volume.
###################################################################
echo ""; echo ""; echo ""
echo "Current processing step:"
echo "Identifying reference volume"
###################################################################
# Determine whether a brain-extracted version of the source
# reference volume already exists.
###################################################################
existRVol=$(imtest "${referenceVolumeBrain[${subjidx}]}")
case $existRVol in
1)
   ################################################################
   # If it does, the pointer should be identical to the path to
   # that brain-extracted volume.
   ################################################################
   echo " * Existing reference image recognised"
   rVolBrain=${referenceVolumeBrain[${subjidx}]}
   ;;
0)
   ################################################################
   # If it does not, this could be either because the source
   # volume itself does not exist, or because brain extraction
   # has not yet been run on the reference volume.
   ################################################################
   rVol=${referenceVolume[${subjidx}]}
   if [[ $(imtest "${rVol}") != 1 ]]
      then
      #############################################################
      # * If the source volume does not exist, this reflects an
      #   unconventional decision in the pipeline, since motion
      #   realignment should always create a source volume.
      # * If this is the case, the coregistration module will
      #   generate a new source volume. Be advised that this
      #   might lead to unexpected or catastrophic results if, for
      #   instance, the primary BOLD timeseries has been demeaned.
      #############################################################
      echo "XCP-WARNING: No reference volume detected."
      echo " * This probably means that you are doing something"
      echo "   unconventional (for instance, computing"
      echo "   coregistration prior to alignment of volumes)."
      echo "   You are advised to inspect your pipeline to ensure"
      echo "   that this is intentional."
      echo " * Preparing reference volume"
      nvol=$(fslnvols ${img})
      midpt=$(expr $nvol / 2)
      fslroi ${out}/${prefix} ${referenceVolume[${cxt}]} $midpt 1
      rVol=${referenceVolume[${cxt}]}
   fi
   if [[ $(imtest "${referenceVolumeBrain[${cxt}]}") != 1 ]] \
      && [[ "${coreg_rerun[${cxt}]}" != "N" ]]
      then
      #############################################################
      # * If the source volume exists but brain extraction has
      #   not yet been performed, then the coregistration module
      #   will automatically identify and isolate brain tissue in
      #   the reference volume using BET.
      #############################################################
      echo "No brain-extracted reference volume detected."
      echo " * Extracting brain from reference volume"
      bet ${rVol} \
         ${referenceVolumeBrain[${cxt}]} \
         -f $FIT
   fi
   rVolBrain=${referenceVolumeBrain[${cxt}]}
   ;;
esac





###################################################################
# If BBR is the cost function being used, a white matter mask
# must be extracted from the user-specified tissue segmentation.
#  * This mask is written to the path ${outbase}_t1wm. It is
#    considered a temporary file, so it will be deleted in the
#    cleanup phase.
###################################################################
if [[ "${coreg_cfunc[${cxt}]}" == "bbr" ]]
   then
   wmmask=${outbase}_t1wm
   if [[ $(imtest "${wmmask}") != 1 ]] \
      || [[ "${coreg_rerun[${cxt}]}" != "N" ]]
      then
      echo ""; echo ""; echo ""
      echo "Current processing step:"
	   echo "Extracting white matter mask from segmentation"
	   case ${coreg_wm[${cxt}]} in
      #############################################################
      # * If the user-specified tissue segmentation includes only
      #   white matter, then it only needs to be binarised.
      #############################################################
	   all)
	      echo "All nonzero voxels correspond to white matter."
	      echo "Binarising image..."
	      fslmaths ${coreg_seg[${cxt}]} -bin ${wmmask}
	      ;;
      #############################################################
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
      #############################################################
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
   ################################################################
   # Prime an additional input argument to FLIRT, containing
   # the path to the new mask.
   ################################################################
   wmmaskincl="-wmseg $wmmask"
   echo "Processing step complete:"
   echo "White matter mask"
fi





###################################################################
# Determine whether the user has specified weights for the cost
# function, and set up the coregistration to factor them into its
# optimisiation if they are specified.
#
# * refwt : weights in the reference/target/structural space
# * inwt : weights in the input/registrand/analyte space
###################################################################
if [[ "${coreg_refwt[${cxt}]}" != "NULL" ]] \
   && [[ $(imtest ${coreg_refwt[${cxt}]}) == 1 ]]
   then
   refwt="-refweight ${coreg_refwt[${cxt}]}"
else
   refwt=""
fi
if [[ "${coreg_inwt[${cxt}]}" != "NULL" ]] \
   && [[ $(imtest ${coreg_inwt[${cxt}]}) == 1 ]]
   then
   inwt="-inweight ${coreg_inwt[${cxt}]}"
else
   inwt=""
fi





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
      ${refwt} \
      ${inwt} \
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
#   fslmaths ${outbase}_seq2struct_mask \
#      -sub ${outbase}_struct_mask \
#      -thr 0 \
#      -bin \
#      ${outbase}_seq2struct_maskdiff
   fslmaths ${outbase}_struct_mask \
      -sub ${e2smask[${cxt}]} \
      -thr 0 \
      -bin \
      ${outbase}_struct_maskdiff
   qa_vol_struct=$(fslstats ${outbase}_struct_mask -V\
      |awk '{print $2}')
#   qa_vol_seq2struct=$(fslstats ${outbase}_seq2struct_mask -V\
#      |awk '{print $2}')
   qa_vol_diff=$(fslstats ${outbase}_struct_maskdiff -V\
      |awk '{print $2}')
   qa_cov_obs=$(echo "scale=10; 1 - ${qa_vol_diff} / ${qa_vol_struct}"|bc)
#   qa_cov_max=$(echo "scale=10; ${qa_vol_seq2struct} / ${qa_vol_struct}"|bc)
#   [[ $(echo "${qa_cov_max} > 1"|bc -l) == 1 ]] && qa_cov_max=1
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
   #qa_miss_struct=$(fslstats ${outbase}_seq2struct_maskdiff -V\
   #   |awk '{print $2}')
   #qa_miss_seq2struct=$(fslstats ${outbase}_struct_maskdiff -V\
   #   |awk '{print $2}')
   #qa_miss_vox=$(echo ${qa_miss_struct} \* ${qa_miss_seq2struct}\
   #   |bc)
   #echo "coregCrossCorr,coreg_nvoxel_seq2struct_not_covered,coreg_nvoxel_struct_not_covered,coregCoverage_product"\
   #   >> ${quality[${cxt}]}
   #echo ${qa_cc},${qa_miss_struct},${qa_miss_seq2struct},${qa_miss_vox}\
   #   >> ${quality[${cxt}]}
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
#qa_miss_struct_max=$(echo ${coreg_qacut[${cxt}]}|cut -d"," -f2)
#qa_miss_seq2struct_max=$(echo ${coreg_qacut[${cxt}]}|cut -d"," -f3)
#qa_miss_vox_max=$(echo ${coreg_qacut[${cxt}]}|cut -d"," -f4)
###################################################################
# Then, parse the observed quality metrics.
###################################################################
flag=0
qa_obs=$(tail -n1 ${quality[${cxt}]})
qa_cc=$(echo ${qa_obs}|cut -d"," -f1)
qa_coverage=$(echo ${qa_obs}|cut -d"," -f2)
#qa_miss_struct=$(echo ${qa_obs}|cut -d"," -f2)
#qa_miss_seq2struct=$(echo ${qa_obs}|cut -d"," -f3)
#qa_miss_vox=$(echo ${qa_obs}|cut -d"," -f4)
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
#[[ $(echo $qa_miss_struct_max'<'$qa_miss_struct | bc -l) == 1 ]] \
#   && [[ $qa_miss_struct_max =~ ${POSNUM} ]] \
#   && flag=1
#[[ $(echo $qa_miss_seq2struct_max'<'$qa_miss_seq2struct | bc -l) == 1 ]] \
#   && [[ $qa_miss_seq2struct_max =~ ${POSNUM} ]] \
#   && flag=1
#[[ $(echo $qa_miss_vox_max'<'$qa_miss_vox | bc -l) == 1 ]] \
#   && [[ $qa_miss_vox_max =~ ${POSNUM} ]] \
#   && flag=1
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
#   fslmaths ${outbase}_seq2struct_alt_mask \
#      -sub ${outbase}_struct_mask \
#      -thr 0 \
#      -bin \
#      ${outbase}_seq2struct_alt_maskdiff
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
#   qa_miss_struct_alt=$(fslstats ${outbase}_seq2struct_alt_maskdiff -V\
#      |awk '{print $2}')
#   qa_miss_seq2struct_alt=$(fslstats ${outbase}_struct_alt_maskdiff -V\
#      |awk '{print $2}')
#   qa_miss_vox_alt=$(echo ${qa_miss_struct_alt} \* ${qa_miss_seq2struct_alt}\
#      |bc)
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
#      echo "coregCrossCorr,coreg_nvoxel_seq2struct_not_covered,coreg_nvoxel_struct_not_covered,coregCoverage_product"\
#         >> ${quality[${cxt}]}
#      echo ${qa_cc_alt},${qa_miss_struct_alt},${qa_miss_seq2struct_alt},${qa_miss_vox_alt}\
#         >> ${quality[${cxt}]}
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





###################################################################
# write remaining output paths to local design file so that
# they may be used further along the pipeline
###################################################################
echo ""; echo ""; echo ""
echo "Writing outputs..."
###################################################################
   # OUTPUT: seq2struct
   # Write the affine transform from sequence to structural
   # space to the localised design file.
###################################################################
echo "seq2struct[${subjidx}]=${seq2struct[${cxt}]}" \
   >> $design_local
###################################################################
# OUTPUT: struct2seq
# Test whether the transform from structural to sequence
# space exists. If it does, add it to the localised design
# file.
###################################################################
if [[ -e "${struct2seq[${cxt}]}" ]]
   then
   echo "struct2seq[${subjidx}]=${struct2seq[${cxt}]}" \
      >> $design_local
fi
###################################################################
# OUTPUT: quality
# Test whether a text file containing metrics of coregistration
# quality exists. If it does, then add it to the localised
# design file.
###################################################################
if [[ -e "${quality[${cxt}]}" ]]
   then
   echo "coreg_quality[${subjidx}]=${quality[${cxt}]}" \
      >> $design_local
   qvars=${qvars},$(head -n1 ${quality[${cxt}]})
   qvals=${qvals},$(tail -n1 ${quality[${cxt}]})
fi
###################################################################
# OUTPUT: e2simg e2smask s2eimg s2emask
# Test whether each warped volume and each binarised mask exists
# as an image. If it does, then add it to the localised design
# file.
###################################################################
if [[ $(imtest ${s2eimg[${cxt}]}) == "1" ]]
   then
   echo "s2eimg[${subjidx}]=${s2eimg[${cxt}]}" >> $design_local
fi
if [[ $(imtest ${e2simg[${cxt}]}) == "1" ]]
   then
   echo "e2simg[${subjidx}]=${e2simg[${cxt}]}" >> $design_local
fi
if [[ $(imtest ${s2emask[${cxt}]}) == "1" ]]
   then
   echo "s2emask[${subjidx}]=${s2emask[${cxt}]}" >> $design_local
fi
if [[ $(imtest ${e2smask[${cxt}]}) == "1" ]]
   then
   echo "e2smask[${subjidx}]=${e2smask[${cxt}]}" >> $design_local
fi
###################################################################
# OUTPUT: referenceVolume
# Test whether a reference volume exists as an image. If
# it does, add it to the index of derivatives and to
# the localised design file.
#
# THIS SHOULD NOT EXIST IN NEARLY ANY CASE. If it does, ensure
# that your pipeline is behaving as intended.
###################################################################
if [[ $(imtest ${referenceVolume[${cxt}]}) == "1" ]]
   then
   echo "referenceVolume[${subjidx}]=${referenceVolume[${cxt}]}" \
      >> $design_local
   echo "#referenceVolume#${referenceVolume[${cxt}]}" \
      >> ${auxImgs[${subjidx}]}
fi
###################################################################
# OUTPUT: brain-extracted referenceVolume
# Test whether a brain-extracted reference volume exists.
# In most cases, it will not, as the coregistration module only
# performs brain extraction on the reference volume if
# prestats or another module has not already done so. If it
# does, add it to the index of derivatives and to the localised
# design file.
###################################################################
if [[ $(imtest "${referenceVolumeBrain[${cxt}]}") == "1" ]]
   then
   echo "referenceVolumeBrain[${subjidx}]=${referenceVolumeBrain[${cxt}]}"\
      >> $design_local
   echo "#referenceVolumeBrain#${referenceVolumeBrain[${cxt}]}" \
      >> ${auxImgs[${subjidx}]}
fi





###################################################################
# CLEANUP
#  * Remove any temporary files if cleanup is enabled.
#  * Update the quality index.
#  * Update the audit file.
###################################################################
if [[ "${coreg_cleanup[${cxt}]}" == "Y" ]]
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
