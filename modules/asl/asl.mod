#!/usr/bin/env bash

###################################################################
#    ✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡      #
###################################################################

###################################################################
# Constants
###################################################################

###################################################################
# Module contributed by Adon Rosen
# (Brain Behavior Lab, University of Pennsylvania)
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
echo "#  ✡✡ ✡✡✡✡ ✡✡✡✡✡✡✡✡✡ ✡✡✡✡✡✡✡✡✡✡✡✡✡ ✡✡✡✡✡✡✡✡✡✡✡✡✡ ✡✡✡✡✡✡✡✡ ✡✡✡✡ ✡✡ #"
echo "#                                                                 #"
echo "#  ☭                   EXECUTING ASL MODULE                    ☭  #"
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
if [[ ! -e ${asl_QuantScript[${cxt}]} ]]
   then
   echo "::XCP-ERROR: The script to be used for quantification "
   echo "  of perfusion is absent."
   exit 666
fi
if [[ ! -e ${asl_xml[${cxt}]} ]]
   then
   echo "::XCP-ERROR: The DICOM-derived XML file containing "
   echo "  subject variables for perfusion correction is absent."
   exit 666
fi
###################################################################
# Create a directory for intermediate outputs.
###################################################################
[[ ${NUMOUT} == 1 ]] && prep=${cxt}_
outdir=${out}/${prep}asl
[[ ! -e ${outdir} ]] && mkdir -p ${outdir}
echo "Output directory is $outdir"
###################################################################
###################################################################
# Quick hack to fix rerun issues
# TODO
# Make this more targeted
###################################################################
###################################################################
if [[ "${asl_rerun[${cxt}]}" == "Y" ]]
   then
   rm -rf ${outdir}/*
fi
###################################################################
# Define paths to all potential outputs.
# 
# For the asl module, potential outputs include:
#  * asl_quant : The output from melliots asl_quant script
#  * asl_quant_no_T1_mod : The output from melliots asl_quant script w/o 
#                          the age and sex inputs
#  * asl_qa_csv : Outputs # of clips, # of negative voxels, and
#                   Tsnr into a csv in the module directory
#  * gm_mask : Used to compute # of negative voxels from output
#                  of the quantified asl images
###################################################################
asl_quant[${cxt}]=${outdir}/${prefix}_aslQuantSST1
asl_quant_no_T1_mod[${cxt}]=${outdir}/${prefix}_aslQuantStdT1
gm_mask[${cxt}]=${outdir}/${prefix}_GMqaMask
asl_qa_csv[${cxt}]=${outdir}/${prefix}_aslQuality.csv
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
   || [ "${asl_rerun[${cxt}]}" == "Y" ]
   then
   rm -f ${img}${ext}
   ln -s ${out}/${prefix}${ext} ${img}${ext}
fi
imgpath=$(ls ${img}${ext})
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
echo "# *** outputs from asl[${cxt}] *** #" \
   >> $design_local
echo "" >> $design_local
###################################################################
# Verify that the module should be run:
#  * Test whether the final output already exists.
#  * Determine whether the user requested the module to be re-run.
# If it is determined that the module should not be run, then any
#  outputs must be written to the local design file.
###################################################################
#if [[ $(imtest ${asl_quant[${cxt}]}) == "1" ]] \
#   && [[ "${asl_rerun[${cxt}]}" == "N" ]]
#   then
#   echo "[asl] has already run to completion."
#   echo "Writing outputs..."
   ################################################################
   # OUTPUT: asl_quant
   ################################################################
#   if [[ $(imtest ${asl_quant[${cxt}]}) == "1" ]]
#      then
#      echo "#asl_quant#${asl_quant[${cxt}]}" \
#         >> ${auxImgs[${subjidx}]}
#      echo "asl_quant[${subjidx}]=${asl_quant[${cxt}]}" \
#         >> $design_local
#   fi
   ################################################################
   # OUTPUT: asl_quant_no_T1_mod
   ################################################################
#   if [[ $(imtest ${asl_quant_no_T1_mod[${cxt}]}) == "1" ]]
#      then
#      echo "#asl_quant#${asl_quant_no_T1_mod[${cxt}]}" \
#         >> ${auxImgs[${subjidx}]}
#      echo "asl_quant[${subjidx}]=${asl_quant_no_T1_mod[${cxt}]}" \
#         >> $design_local
#   fi
#   qvars=${qvars},$(head -n1 ${asl_qa_csv[${cxt}]})
#   qvals=${qvals},$(tail -n1 ${asl_qa_csv[${cxt}]})
   ################################################################
   # Since it has been determined that the module does not need to
   # be executed, update the audit file and exit the module.
   ################################################################
#   rm -f ${quality}
#   echo ${qvars} >> ${quality}
#   echo ${qvals} >> ${quality}
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





echo "Processing image: $img"

###################################################################
###################################################################
# * Quantify the filtered ASL image
###################################################################
###################################################################
echo ""; echo ""; echo ""
echo "Current processing step:"
echo "Quantifying ASL Image"
#############################################################
	# Call melliot's asl quant script
        # inputs include:
        # 1.) filtered 4d asl image
        # 2.) xml output from melliot's dicom_dump.sh script
        # 3.) Output binary T1 
        # 4.) Output image
        # 5.) Blood T1 option (-1 requests script to gather T1 time from xml file)
#############################################################
if [[ $(imtest ${asl_quant[${cxt}]}) != 1 ]] \
   || [[ ${asl_rerun[${cxt}]} != N ]]
   then
   buffer=${FSLOUTPUTTYPE}
   ${asl_QuantScript[${cxt}]} \
      ${img}${ext} \
      ${asl_xml[${cxt}]} \
      ${s2emask[${subjidx}]}${ext} \
      ${asl_quant[${cxt}]} \
      -1
      
   fslchfiletype ${buffer} ${asl_quant[${cxt}]}
   export FSLOUTPUTTYPE=${buffer}
fi

###################################################################
###################################################################
# * Quantify the filtered ASL image w/o T1 modifications
###################################################################
###################################################################
echo ""; echo ""; echo ""
echo "Current processing step:"
echo "Quantifying ASL Image w/o T1 modifications"
#############################################################
	# Call melliot's asl quant script
        # inputs include:
        # 1.) filtered 4d asl image
        # 2.) xml output from melliot's dicom_dump.sh script
        # 3.) Output binary T1 
        # 4.) Output image
        # 5.) Blood T1 option (-1 requests script to gather T1 time from xml file)
#############################################################
if [[ $(imtest ${asl_quant_no_T1_mod[${cxt}]}) != 1 ]] \
   || [[ ${asl_rerun[${cxt}]} != N ]]
   then
   buffer=${FSLOUTPUTTYPE}
   ${asl_QuantScript[${cxt}]} \
      ${img}${ext} \
      ${asl_xml[${cxt}]} \
      ${s2emask[${subjidx}]}${ext} \
      ${asl_quant_no_T1_mod[${cxt}]} \
      0

   fslchfiletype ${buffer} ${asl_quant_no_T1_mod[${cxt}]}
   export FSLOUTPUTTYPE=${buffer}
fi
###################################################################
###################################################################
# * QA The quantified images
###################################################################
###################################################################
echo ""; echo ""; echo ""
echo "Current processing step:"
echo "Quality control"
###################################################################
###################################################################
# Now find the number of negative gray matter voxels
# This requires extracting a gm mask &
# Registering it to asl space
###################################################################
if [[ $(imtest ${gm_mask[${cxt}]}) != 1 ]] \
   || [[ ${asl_rerun[${cxt}]} != N ]]
   then
   ${XCPEDIR}/utils/val2mask.R \
      -i ${asl_gm_path[${cxt}]} \
      -v ${asl_gm_val[${cxt}]} \
      -o ${gm_mask[${cxt}]}${ext}

   ${ANTSPATH}/antsApplyTransforms \
      -i ${gm_mask[${cxt}]}${ext} \
      -o ${gm_mask[${cxt}]}${ext} \
      -r ${referenceVolumeBrain[${subjidx}]}${ext} \
      -n NearestNeighbor \
      -t ${struct2seq[${subjidx}]}
fi

negative_voxels_ss=`fslstats ${asl_quant[${cxt}]} -k ${gm_mask[${cxt}]} -u 0 -V | cut -d " " -f 1 | sed s/" "//`
negative_voxels_std=`fslstats ${asl_quant_no_T1_mod[${cxt}]} -k ${gm_mask[${cxt}]} -u 0 -V | cut -d " " -f 1 | sed s/" "//`

###################################################################
# Now output QA metrics to the QA csv
###################################################################
rm -f ${asl_qa_csv[${cxt}]}
echo "negativeVoxelsSST1, negativeVoxelsStdT1" > ${asl_qa_csv[${cxt}]}
echo "${negative_voxels_ss},${negative_voxels_std}" >> ${asl_qa_csv[${cxt}]}





################################################################### 
# Write any remaining output paths to local design file so that
# they may be used further along the pipeline.
################################################################### 
echo ""; echo ""; echo ""
echo "Writing outputs..."
###################################################################
# OUTPUT: asl_xml
###################################################################
if [[ -e ${asl_xml[${cxt}]} ]]
   then
   echo "asl_xml[${subjidx}]=${asl_quant[${cxt}]}" \
      >> $design_local
fi
###################################################################
# OUTPUT: asl_quant
###################################################################
if [[ $(imtest ${asl_quant[${cxt}]}) == "1" ]]
   then
   echo "#asl_quant_ssT1#${asl_quant[${cxt}]}#asl,${cxt}" \
      >> ${auxImgs[${subjidx}]}
   echo "asl_quant_ssT1[${subjidx}]=${asl_quant[${cxt}]}" \
      >> $design_local
fi
###################################################################
# OUTPUT: asl_quant_no_T1_mod
###################################################################
if [[ $(imtest ${asl_quant_no_T1_mod[${cxt}]}) == "1" ]]
   then
   echo "#asl_quant_stdT1#${asl_quant_no_T1_mod[${cxt}]}#asl,${cxt}" \
      >> ${auxImgs[${subjidx}]}
   echo "asl_quant_stdT1[${subjidx}]=${asl_quant_no_T1_mod[${cxt}]}" \
      >> $design_local
fi
###################################################################
# OUTPUT: QA
###################################################################
if [[ -n $(cat ${asl_qa_csv[${cxt}]}) ]]
   then
   qvars=${qvars},$(head -n1 ${asl_qa_csv[${cxt}]})
   qvals=${qvals},$(tail -n1 ${asl_qa_csv[${cxt}]})
fi





###################################################################
# CLEANUP
#  * Remove any temporary files if cleanup is enabled.
#  * Update the audit file.
###################################################################
if [[ "${asl_cleanup[${cxt}]}" == "Y" ]]
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
