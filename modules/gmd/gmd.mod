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
echo "#  ☭                    EXECUTING GMD MODULE                   ☭  #"
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
outdir=${out}/${prep}gmd
[[ ! -e ${outdir} ]] && mkdir -p ${outdir}
echo "Output directory is $outdir"
###################################################################
# Define paths to all potential outputs.
#
# For the structural module, potential outputs include:
# Define paths to all potential outputs.
#
# For the structural module, potential outputs include:
#  * priorImage%02d: 3 class soft segmentation images from the output of Atropos
#  * segmentationImage: 3 class hard segmentation image
#  * gmSegmentationIntersect: Intersection between prior GM image and hard GM segmentation
#
###################################################################
priorImage01[${cxt}]=${outdir}/${prefix}_priorImage001
priorImage02[${cxt}]=${outdir}/${prefix}_priorImage002
priorImage03[${cxt}]=${outdir}/${prefix}_priorImage003
segmentationImage[${cxt}]=${outdir}/${prefix}_segmentationImage
gmSegIntersect[${cxt}]=${outdir}/${prefix}_gmSegIntersect
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
###################################################################
# Now determine output suffix
###################################################################
[[ ${ext} == ".nii.gz" ]] && antsExt="nii.gz"
[[ ${ext} == ".nii" ]] && antsExt="nii"
[[ ${ext} == ".hdr" ]] && antsExt="img"
[[ ${ext} == ".img" ]] && antsExt="img"
[[ ${ext} == ".hdr.gz" ]] && antsExt="img.gz"
[[ ${ext} == ".img.gz" ]] && antsExt="img.gz"

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
echo "# *** outputs from gmd[${cxt}] *** #" >> $design_local
echo "" >> $design_local
###################################################################
# Verify that the module should be run:
#  * Test whether the final output already exists.
#  * Determine whether the user requested the module to be re-run.
# If it is determined that the module should not be run, then any
#  outputs must be written to the local design file.
###################################################################
if [[ $(imtest ${gmSegIntersect[${cxt}]}${ext}) == "1" ]] \
  && [[ "${gmd_rerun[${cxt}]}" == "N" ]]
  then
  echo "gmd has already run to completion."
  echo "Writing outputs..."
  ###################################################################
  # OUTPUT: Prior image 1
  # Test whether the csf soft segmentaiton image was created.
  # If it does exist then add it to the index of derivatives and 
  # to the localised design file
  ###################################################################
  if [[ $(imtest "${priorImage01[${cxt}]}") == "1" ]] 
    then
    echo "priorImage01[${subjidx}]=${priorImage01[${cxt}]}" \ 
      >> $design_local
    echo "#priorImage01#${priorImage01[${cxt}]}" \ 
      >> ${auxImgs[${subjidx}]}
  fi
  ###################################################################
  # OUTPUT: Prior image 2
  # Test whether the gm soft segmentaiton image was created.
  # If it does exist then add it to the index of derivatives and 
  # to the localised design file
  ###################################################################
  if [[ $(imtest "${priorImage02[${cxt}]}") == "1" ]] 
    then
    echo "priorImage02[${subjidx}]=${priorImage02[${cxt}]}" \ 
      >> $design_local
    echo "#priorImage02#${priorImage02[${cxt}]}" \ 
      >> ${auxImgs[${subjidx}]}
  fi
  ###################################################################
  # OUTPUT: Prior image 3
  # Test whether the wm soft segmentaiton image was created.
  # If it does exist then add it to the index of derivatives and 
  # to the localised design file
  ###################################################################
  if [[ $(imtest "${priorImage03[${cxt}]}") == "1" ]] 
    then
    echo "priorImage03[${subjidx}]=${priorImage03[${cxt}]}" \ 
      >> $design_local
    echo "#priorImage03#${priorImage03[${cxt}]}" \ 
      >> ${auxImgs[${subjidx}]}
  fi
  ###################################################################
  # OUTPUT: Segmentation Image
  # Test whether the hard segmentaiton image was created.
  # If it does exist then add it to the index of derivatives and 
  # to the localised design file
  ###################################################################
  if [[ $(imtest "${segmentationImage[${cxt}]}") == "1" ]] 
    then
    echo "segmentationImage[${subjidx}]=${segmentationImage[${cxt}]}" \ 
      >> $design_local
    echo "#segmentationImage#${segmentationImage[${cxt}]}" \ 
      >> ${auxImgs[${subjidx}]}
  fi
  ###################################################################
  # OUTPUT: gmSegIntersect
  # Test whether the gm soft and hard segmentaiton intersection image was created.
  # If it does exist then add it to the index of derivatives and 
  # to the localised design file
  ###################################################################
  if [[ $(imtest "${segmentationImage[${cxt}]}") == "1" ]] 
    then
    echo "segmentationImage[${subjidx}]=${segmentationImage[${cxt}]}" \ 
      >> $design_local
    echo "#gmdIntersect#${segmentationImage[${cxt}]}#gmdIntersect,${cxt}" \ 
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
# Check to see if we have an input mask - if none binarize 
# the input img
###################################################################
if [[ $(imtest "${gmdMask[${cxt}]}") == "0" ]] 
   then
   fslmaths ${img} -bin ${outdir}/${prefix}_brainMask
   gmdMask[${cxt}]=${outdir}/${prefix}_brainMask ; 
fi

###################################################################
# Calculate GMD in an iterative procedure
###################################################################
for i in 1 2 3 ; do
  if [ ${i} -eq 1 ] ; then
    Atropos -d 3 -a ${img}${ext} -i KMeans[3] \
                 -c [ 5,0] -m [ 0,1x1x1] -x ${gmdMask[${cxt}]}${ext} \
                 -o [ ${outdir}/${prefix}_segmentationImage${ext}, ${outdir}/${prefix}_priorImage0%02d${ext}]
  else
    Atropos -d 3 -a ${img}${ext} \
                 -i PriorProbabilityImages[ 3,${outdir}/${prefix}_priorImage0%02d${ext},0.0] \
                 -k Gaussian -p Socrates[1] --use-partial-volume-likelihoods 0 \
                 -c [ 12, 0.00001] \
                 -x ${gmdMask[${cxt}]}${ext} \
                 -m [ 0,1x1x1] \
                 -o [ ${outdir}/${prefix}_segmentationImage${ext}, ${outdir}/${prefix}_priorImage0%02d${ext}] ; 
  fi ; 
done 

###################################################################
# Create isolated GM-GMD prior image
###################################################################
fslmaths ${outdir}/${prefix}_segmentationImage${ext} -thr 2 -uthr 2 -bin -mul ${outdir}/${prefix}_priorImage002 ${gmSegIntersect[${cxt}]}

###################################################################
# Write any remaining output paths to local design file so that
# they may be used further along the pipeline.
###################################################################
###################################################################
# OUTPUT: Prior image 1
# Test whether the csf soft segmentaiton image was created. 
# If it does exist then add it to the index of derivatives and 
# to the localised design file
###################################################################
if [[ $(imtest "${priorImage01[${cxt}]}") == "1" ]] 
  then
  echo "priorImage01[${subjidx}]=${priorImage01[${cxt}]}" \
    >> $design_local
  echo "#priorImage01#${priorImage01[${cxt}]}" \
    >> ${auxImgs[${subjidx}]}
fi
###################################################################
# OUTPUT: Prior image 2
# Test whether the gm soft segmentaiton image was created.
# If it does exist then add it to the index of derivatives and 
# to the localised design file
###################################################################
if [[ $(imtest "${priorImage02[${cxt}]}") == "1" ]] 
  then
  echo "priorImage02[${subjidx}]=${priorImage02[${cxt}]}" \
    >> $design_local
  echo "#priorImage02#${priorImage02[${cxt}]}" \
    >> ${auxImgs[${subjidx}]}
fi
###################################################################
# OUTPUT: Prior image 3
# Test whether the wm soft segmentaiton image was created.
# If it does exist then add it to the index of derivatives and 
# to the localised design file
###################################################################
if [[ $(imtest "${priorImage03[${cxt}]}") == "1" ]] 
  then
  echo "priorImage03[${subjidx}]=${priorImage03[${cxt}]}" \
    >> $design_local
  echo "#priorImage03#${priorImage03[${cxt}]}" \
    >> ${auxImgs[${subjidx}]}
fi
###################################################################
# OUTPUT: Segmentation Image
# Test whether the hard segmentaiton image was created.
# If it does exist then add it to the index of derivatives and 
# to the localised design file
###################################################################
if [[ $(imtest "${segmentationImage[${cxt}]}") == "1" ]] 
  then
  echo "segmentationImage[${subjidx}]=${segmentationImage[${cxt}]}" \
    >> $design_local
  echo "#segmentationImage#${segmentationImage[${cxt}]}" \
    >> ${auxImgs[${subjidx}]}
fi
###################################################################
# OUTPUT: gmSegIntersect
# Test whether the gm soft and hard segmentaiton intersection image was created.
# If it does exist then add it to the index of derivatives and 
# to the localised design file
###################################################################
if [[ $(imtest "${gmSegIntersect[${cxt}]}") == "1" ]] 
  then
  echo "gmSegIntersect[${subjidx}]=${segmentationImage[${cxt}]}" \
    >> $design_local
  echo "#gmSegIntersect#${gmSegIntersect[${cxt}]}#gmd,${cxt}" \
    >> ${auxImgs[${subjidx}]}
fi
###################################################################
# CLEANUP
#  * Remove any temporary files if cleanup is enabled.
#  * Update the audit file and quality index.
###################################################################
echo ""; echo ""; echo ""
img=$(readlink -f ${img}${ext})
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
