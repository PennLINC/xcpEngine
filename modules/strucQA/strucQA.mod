#!/usr/bin/env bash

###################################################################
#   ✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡   #
###################################################################

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
echo "#  ✡✡ ✡✡✡✡ ✡✡✡✡✡✡✡✡✡ ✡✡✡✡✡✡✡✡✡✡✡✡✡ ✡✡✡✡✡✡✡✡✡✡✡✡✡ ✡✡✡✡✡✡✡✡ ✡✡✡✡ ✡✡ #"
echo "#                                                                 #"
echo "#  ☭           EXECUTING Structural QA MODULE                  ☭  #"
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
outdir=${out}/${prep}strucQA
[[ ! -e ${outdir} ]] && mkdir -p ${outdir}
echo "Output directory is $outdir"
###################################################################
# Define paths to all potential outputs.
#
# For the structural module, potential outputs include:
# Define paths to all potential outputs.
#
# For the strucQA module, potential outputs include:
#  * foreGround: A foreground mask of the input anatomical image
#  * coordCSV: A csv of the three MNI landmarks in subject space
#  * gmMask: A binary mask containing all of the GM for the input image
#  * wmMask: A binary mask containing all of the WM for the input image
#  * csfMask: A binary mask containing all of the CSF for the input image
#  Optional outputs:
#  * affineTransform: A coarse transformation calculated from the MNI template to subject
#  * diffeoTransform: A diffeomorphic registration calculated from the MNI template to the subject
#  * segmentation: A coarse three class segmentation
###################################################################
foreGround[${cxt}]=${outdir}/${prefix}_foreGround
coordsCSV[${cxt}]=${outdir}/${prefix}_landmarksCoords.csv
gmMask[${cxt}]=${outdir}/${prefix}_gmMask
wmMask[${cxt}]=${outdir}/${prefix}_wmMask
csfMask[${cxt}]=${outdir}/${prefix}_csfMask
## Optional output ##
affineFiles[${cxt}]=${outdir}/${prefix}_0GenericAffine.mat
diffeoTransform[${cxt}]=${outdir}/${prefix}_1Warp
segmentation[${cxt}]=${outdir}/${prefix}_seg
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
ext=".nii.gz"
export FSLOUTPUTTYPE=NIFTI_GZ
img=${outdir}/${prefix}~TEMP~
if [[ $(imtest ${img}) != "1" ]] \
|| [ "${structural_rerun[${cxt}]}" == "Y" ]
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
echo "# *** outputs from strucQA[${cxt}] *** #" >> $design_local
echo "" >> $design_local
###################################################################
# Verify that the module should be run:
#  * Test whether the final output already exists.
#  * Determine whether the user requested the module to be re-run.
# If it is determined that the module should not be run, then any
#  outputs must be written to the local design file.
###################################################################
if [[ $(imtest ${foreGround[${cxt}]}${ext}) == "1" ]] \
&& [[ "${strucQA_rerun[${cxt}]}" == "N" ]]
then
echo "strucQA has already run to completion."
echo "Writing outputs..."
  ###################################################################
  # OUTPUT: Foreground Image
  # Test whether the foreground image was created.
  # If it does exist then add it to the index of derivatives and
  # to the localised design file
  ###################################################################
  if [[ $(imtest "${foreGround[${cxt}]}") == "1" ]]
    then
    echo "foreGround[${subjidx}]=${foreGround[${cxt}]}" \
    >> $design_local
    echo "#foreGround#${foreGround[${cxt}]}" \
    >> ${auxImgs[${subjidx}]}
  fi
  ###################################################################
  # OUTPUT: Gray matter mask
  # Test whether the gray matter mask image was created.
  # If it does exist then add it to the index of derivatives and
  # to the localised design file
  ###################################################################
  if [[ $(imtest "${gmMask[${cxt}]}") == "1" ]]
    then
    echo "gmMask[${subjidx}]=${gmMask[${cxt}]}" \
      >> $design_local
    echo "#gmMask#${gmMask[${cxt}]}" \
      >> ${auxImgs[${subjidx}]}
  fi
  ###################################################################
  # OUTPUT: White matter mask
  # Test whether the white matter mask image was created.
  # If it does exist then add it to the index of derivatives and
  # to the localised design file
  ###################################################################
  if [[ $(imtest "${wmMask[${cxt}]}") == "1" ]]
    then
    echo "wmMask[${subjidx}]=${wmMask[${cxt}]}" \
      >> $design_local
    echo "#wmMask#${csfMask[${cxt}]}" \
      >> ${auxImgs[${subjidx}]}
  fi
  ###################################################################
  # OUTPUT: CSF matter mask
  # Test whether the white matter mask image was created.
  # If it does exist then add it to the index of derivatives and
  # to the localised design file
  ###################################################################
  if [[ $(imtest "${csfMask[${cxt}]}") == "1" ]]
    then
    echo "csfMask[${subjidx}]=${csfMask[${cxt}]}" \
      >> $design_local
    echo "#csfMask#${csfMask[${cxt}]}" \
      >> ${auxImgs[${subjidx}]}
  fi
  ###################################################################
  # OUTPUT: Segmentation image
  # Test whether the three class segmentation image was created.
  # If it does exist then add it to the index of derivatives and
  # to the localised design file
  ###################################################################
  if [[ $(imtest "${segmentation[${cxt}]}") == "1" ]]
    then
    echo "segmentation[${subjidx}]=${segmentation[${cxt}]}" \
      >> $design_local
    echo "#segmentation#${segmentation[${cxt}]}" \
      >> ${auxImgs[${subjidx}]}
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
  exit 0 
fi

###################################################################
###################################################################
# END GENERAL MODULE HEADER
###################################################################
###################################################################

###################################################################
# See if we have a segmentation image
# If none provided then run segmentation using either FAST or Atropos
###################################################################
allValsCheck=0
if [[ "${strucQA_gm[${cxt}]}" == "Y" ]]
   then
  ################################################################
  # Generate a binary mask if necessary.
  # This mask will be based on a user-specified input value
  # and a user-specified image in the subject's structural space.
  ################################################################
  ${XCPEDIR}/utils/val2mask.R \
    -i ${strucQA_seg[${cxt}]}${ext} \
    -v ${strucQA_gm_val[${cxt}]} \
    -o ${gmMask}${ext}
  allValsCheck=`echo ${allValsCheck} + 1 | bc`
fi
if [[ "${strucQA_wm[${cxt}]}" == "Y" ]]
   then
  ################################################################
  # Generate a binary mask if necessary.
  # This mask will be based on a user-specified input value
  # and a user-specified image in the subject's structural space.
  ################################################################
  ${XCPEDIR}/utils/val2mask.R \
    -i ${strucQA_seg[${cxt}]}${ext} \
    -v ${strucQA_wm_val[${cxt}]} \
    -o ${wmMask}${ext}
  allValsCheck=`echo ${allValsCheck} + 1 | bc`
fi
if [[ "${strucQA_csf[${cxt}]}" == "Y" ]]
   then
  ################################################################
  # Generate a binary mask if necessary.
  # This mask will be based on a user-specified input value
  # and a user-specified image in the subject's structural space.
  ################################################################
  ${XCPEDIR}/utils/val2mask.R \
    -i ${strucQA_seg[${cxt}]}${ext} \
    -v ${strucQA_csf_val[${cxt}]} \
    -o ${csfMask}${ext}
  allValsCheck=`echo ${allValsCheck} + 1 | bc`
fi
###################################################################
# See if we have 3 segmentation masks
# If we don't have three run FAST | Atropos to create a quick seg
###################################################################
if [[ ${allValsCheck} -lt 3 ]] \
    || [[ ! -z ${strucQASeg[${cxt}]} ]]
  then
    if [[ ${strucQASeg[${cxt}]} == "FAST" ]] 
      then
      $FSLDIR/bin/fast -o ${outdir}/${prefix}_ ${img}${ext}
    fi
if [[ ${strucQASeg[${cxt}]} == "ATROPOS" ]]
      then
      if [[ -z ${brainExtractionMask[${subjidx}]} ]]
        then
        ${FSLDIR}/bin/bet ${img[${subjidx}]} ${outdir}/${prefix}_BEmask~TEMP~.nii.gz
        ${FSLDIR}/bin/fslmaths ${outdir}/${prefix}_BEmask~TEMP~.nii.gz -bin ${outdir}/${prefix}_BEmask~TEMP~.nii.gz
        brainExtractionMask[${subjidx}]=${outdir}/${prefix}_BEmask~TEMP~.nii.gz
      fi
      ${ANTSPATH}/Atropos -d 3 -a ${img}${ext} -i KMeans[3] \
        -c [ 5,0] -m [ 0,1x1x1] -x ${brainExtractionMask[${subjidx}]} \
        -o [ ${outdir}/${prefix}_seg${ext} ]
    fi
fi

###################################################################
# Now we need to create our foreground segmentation
# we need to make sure we have a transformation from MNI to our subject 
# in order to perform this
###################################################################
${ANTSPATH}/antsRegistration -d 3 -v 0 -u 1 -w [0.01,0.99] -o ${outdir}/${prefix}_ \
  -r [${img}${ext},${FSLDIR}/data/standard/MNI152_T1_1mm.nii.gz,1] --float 1 -m MI[${img}${ext},${FSLDIR}/data/standard/MNI152_T1_1mm.nii.gz,1,32,Regular,0.25] \
  -c [1000x500x250x100,1e-8,10] -t Affine[0.1] -f 8x4x2x1 -s 4x2x1x0 -m CC[${img}${ext},${FSLDIR}/data/standard/MNI152_T1_1mm.nii.gz,1,4] -c [100x100x70x20,1e-9,15] -t SyN[0.1,3,0] -f 6x4x2x1 -s 3x2x1x0

###################################################################
# Now apply the transformation to the MNI points
###################################################################
${ANTSPATH}/antsApplyTransformsToPoints -d 3 -i ${XCPEDIR}/thirdparty/strucQA/mni1mmCoords/mniCoords.csv \
  -o ${coordsCSV[${cxt}]} -t ${affineFiles[${cxt}]} -t ${diffeoTransform[${cxt}]}
  
###################################################################
# Now apply this transformation to the MNI mask
###################################################################  
${ANTSPATH}/antsApplyTransforms -d 3 -e ${XCPEDIR}/thirdparty/strucQA/mniMask/mniForeGroundMask.nii.gz -o ${foreGround[${cxt}]} \
  -r ${img[${subjidx}]} -n MultiLabel -t ${affineFiles[${cxt}]} -t ${diffeoTransform[${cxt}]}
  
###################################################################
# Now mask out the neck and nose from the background
###################################################################   
fslmaths ${foreGround[${cxt}]} -add 1 -bin ${outdir}/${prefix}_allMask~TEMP~
${XCPEDIR}/utils/extendMaskInferior.R -i {foreGround[${cxt}]} -o {foreGround[${cxt}]} -c ${coordsCSV[${cxt}]} -s ${outdir}/${prefix}_allMask~TEMP~

###################################################################
# Now compute all of our quality metrics 
################################################################### 
