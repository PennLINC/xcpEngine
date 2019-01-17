#!/usr/bin/env bash

###################################################################
#  ⊗⊗ ⊗⊗⊗⊗ ⊗⊗⊗⊗⊗⊗⊗⊗⊗ ⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗ ⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗⊗ ⊗⊗⊗⊗⊗⊗⊗⊗ ⊗⊗⊗⊗ ⊗⊗ #
###################################################################

###################################################################
# Combine all text file output
###################################################################
# This script will be used to find the intersection between JLF segmentations and ANTsCT GM segmentations.
# The required inputs will be our JLF segmentation and the ANTsCT segmentation image.
# It will be used to produce more correct JLF segmentation values. 

###################################################################
# Usage function
###################################################################
usage(){
echo
echo
echo
echo "${0} <jlfSegmentation.nii.gz> <ANTsCTSegmentation.nii.gz> <outputImageName>"
echo 
echo "This script will be used to find the intersection between JLF segmentations and ANTsCT GM segmentations."
echo "The required inputs will be our JLF segmentation and the ANTsCT segmentation image."
echo "It will be used to produce more correct JLF segmentation values."
echo
echo "Should any issues arise trying to use this script eamil: adrose@mail.med.upenn.edu"
exit 1
}


###################################################################
# Parse arguments
###################################################################
createBinMask="$XCPEDIR/utils/val2mask.R"
valsToBin="2:6"
csfValsToBin="4,11,46,51,52"
jlfParcel=${1}
antsCTSeg=${2}
outputImage=${3}
workDir=`dirname ${outputImage}`

###################################################################
# Ensure that all compulsory arguments have been defined
###################################################################
if [ ! -f ${jlfParcel} ] ; then
  echo "**"
  echo "**"
  echo "No JLF Parcel present"
  echo "**"
  echo "**"
  usage;
fi

if [ ! -f ${antsCTSeg} ] ; then 
  echo "**"
  echo "**"
  echo "No ANTsCT Parcel present"
  echo "**"
  echo "**"
  usage;
fi 

if [ "X${outputImage}" == "X" ] ; then
  echo "**"
  echo "**"
  echo "No outputImage Name provided!"
  echo "**"
  echo "**"
  usage;
fi  

###################################################################
# Now find the intersection image!
###################################################################
${createBinMask} -i ${antsCTSeg} -v ${valsToBin} -o ${workDir}/thresholdedImage.nii.gz 
${createBinMask} -i ${jlfParcel} -v ${csfValsToBin} -o ${workDir}/binMaskCSF.nii.gz
${createBinMask} -i ${jlfParcel} -v "61,62" -o ${workDir}/binMaskVD.nii.gz

# Now fix the csf image
3dmask_tool -input ${workDir}/binMaskCSF.nii.gz -prefix ${workDir}/binMaskCSF_dil.nii.gz -dilate_input 2 -quiet

# Now multiply our values together 
fslmaths ${workDir}/thresholdedImage.nii.gz -add ${workDir}/binMaskCSF_dil.nii.gz -add ${workDir}/binMaskVD.nii.gz -bin ${workDir}/thresholdedImage.nii.gz
fslmaths ${workDir}/thresholdedImage.nii.gz -mul ${jlfParcel} ${outputImage}

# Now exit
exit 0
