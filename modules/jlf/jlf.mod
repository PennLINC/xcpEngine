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
echo "#  ☭                    EXECUTING JLF MODULE                   ☭  #"
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
outdir=${out}/${prep}jlf
[[ ! -e ${outdir} ]] && mkdir -p ${outdir}
echo "Output directory is $outdir"
###################################################################
# Define paths to all potential outputs.
#
# For the structural module, potential outputs include:
# Define paths to all potential outputs.
#
# For the structural module, potential outputs include:
#  * labelImage: The image with the associated labels from the output of the JLF procedure
#  * intensityImage: The average intensity image from the the JLF procedure.
#
###################################################################
labelImage[${cxt}]=${outdir}/${prefix}_Labels.nii.gz
intensityImage[${cxt}]=${outdir}/${prefix}_Intensity.nii.gz
###################################################################
# * Initialise a pointer to the image.
# * Ensure that the pointer references an image, and not something
#   else such as a design file.
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
img=${outdir}/${prefix}~TEMP~
if [[ $(imtest ${img}) != "1" ]] \
   || [ "${jlf_rerun[${cxt}]}" == "Y" ]
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
echo "# *** outputs from jlf[${cxt}] *** #" >> $design_local
echo "" >> $design_local
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
echo "# *** outputs from jlf[${cxt}] *** #" >> $design_local
echo "" >> $design_local
###################################################################
# Verify that the module should be run:
#  * Test whether the final output already exists.
#  * Determine whether the user requested the module to be re-run.
# If it is determined that the module should not be run, then any
#  outputs must be written to the local design file.
###################################################################
if [[ $(imtest ${labelImage[${cxt}]}) == "1" ]] \
  && [[ "${jlf_rerun[${cxt}]}" == "N" ]]
  then
  echo "jlf has already run to completion."
  echo "Writing outputs..."
  ###################################################################
  # OUTPUT: Label image
  # Test whether the JLF label image was created.
  # If it does exist then add it to the index of derivatives and 
  # to the localised design file
  ###################################################################
  if [[ $(imtest "${labelImage[${cxt}]}") == "1" ]] 
    then
    echo "labelImage[${subjidx}]=${labelImage[${cxt}]}" \ 
      >> $design_local
    echo "#labelImage#${labelImage[${cxt}]}#jlf,${cxt}" \ 
      >> ${auxImgs[${subjidx}]}
  fi
  ###################################################################
  # OUTPUT: Intensity image
  # Test whether the JLF Intensity image was created.
  # If it does exist then add it to the index of derivatives and 
  # to the localised design file
  ###################################################################
  if [[ $(imtest "${intensityImage[${cxt}]}") == "1" ]] 
    then
    echo "intensityImage[${subjidx}]=${intensityImage[${cxt}]}" \ 
      >> $design_local
    echo "#intensityImage#${intensityImage[${cxt}]}" \ 
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
# * Run ANTs JLF w/ OASIS label set
###################################################################
###################################################################
echo ""; echo ""; echo ""
echo "Current processing step:"
echo "ANTs Joint Label Fusion"        	  
###################################################################
# Now prepare everything to run the JLF command
# special teps must be taken to prepare the ANTSPATH
###################################################################
antsOrig=$ANTSPATH
export ANTSPATH=${newAntsPath[${cxt}]}
###################################################################
# Now create and declare the call to run the JLF pipeline
###################################################################	
oasis=$(cat $XCPEDIR/thirdparty/oasis30/Cohorts/${jlfCohort[${cxt}]})
brainDir=$XCPEDIR/thirdparty/oasis30/Heads/
labelDir=$XCPEDIR/thirdparty/oasis30/MICCAI2012ChallangeLabels/
if [[ ${jlfExtract[${cxt}]} -eq 1 ]]
  then
  brainDir=$XCPEDIR/thirdparty/oasis30/Brains/
fi

for o in ${oasis}
  do
  jlfReg="${jlfReg} -g ${brainDir}${o}.nii.gz"
  jlfReg="${jlfReg} -l ${labelDir}${o}.nii.gz"
done

jlfCMD="${ANTSPATH}/antsJointLabelFusion.sh \
  -d 3 \
  -q 0 \
  -f 0 \
  -j 2 \
  -k ${keepJLFWarps[${cxt}]} \
  -t ${img}.nii.gz \
  -o ${outdir}t/${prefix}_ \
  -c 0 \
  ${jlfReg}"
${jlfCMD}

export ANTSPATH=${antsOrig}

###################################################################
# Write any remaining output paths to local design file so that
# they may be used further along the pipeline.
###################################################################
###################################################################
# OUTPUT: Label image
# Test whether the JLF label image was created.
# If it does exist then add it to the index of derivatives and 
# to the localised design file
###################################################################
if [[ $(imtest "${labelImage[${cxt}]}") == "1" ]] 
  then
  echo "labelImage[${subjidx}]=${labelImage[${cxt}]}" \ 
    >> $design_local
  echo "#labelImage#${labelImage[${cxt}]}#jlf,${cxt}" \ 
    >> ${auxImgs[${subjidx}]}
fi
###################################################################
# OUTPUT: Intensity image
# Test whether the JLF Intensity image was created.
# If it does exist then add it to the index of derivatives and 
# to the localised design file
###################################################################
if [[ $(imtest "${intensityImage[${cxt}]}") == "1" ]] 
  then
  echo "intensityImage[${subjidx}]=${intensityImage[${cxt}]}" \ 
    >> $design_local
  echo "#intensityImage#${intensityImage[${cxt}]}" \ 
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
