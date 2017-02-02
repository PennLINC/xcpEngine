#!/usr/bin/env bash

###################################################################
#  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  #
###################################################################

###################################################################
# Constants
###################################################################
readonly SIGMA=2.35482004503




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
echo "#  ☭           EXECUTING DIFFUSION PREPARATION MODULE          ☭  #"
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
outdir=${out}/${prep}dti2xcp
rm -rf ${outdir}
mkdir -p ${outdir}
echo "Output directory is $outdir"
###################################################################
# Define paths to all potential outputs.

# For the dti2xcp module, outputs include:
# * anisotropyMode
# * axialDiffusivity
# * fractionalAnisotropy
# * eigenvalue1
# * eigenvalue2
# * eigenvalue3
# * eigenvector1
# * eigenvector2
# * eigenvector3
# * referenceVolume
# * meanDiffusivity
# * radialDiffusivity
# * referenceVolume (T2 without diffusion weighting)
# * mask (binarised reference volume)
###################################################################
anisotropyMode[${cxt}]=${outdir}/${prefix}_anisotropyMode
axialDiffusivity[${cxt}]=${outdir}/${prefix}_axialDiffusivity
fractionalAnisotropy[${cxt}]=${outdir}/${prefix}_fractionalAnisotropy
eigenvalue1[${cxt}]=${outdir}/${prefix}_eigenvalue1
eigenvalue2[${cxt}]=${outdir}/${prefix}_eigenvalue2
eigenvalue3[${cxt}]=${outdir}/${prefix}_eigenvalue3
eigenvector1[${cxt}]=${outdir}/${prefix}_eigenvector1
eigenvector2[${cxt}]=${outdir}/${prefix}_eigenvector2
eigenvector3[${cxt}]=${outdir}/${prefix}_eigenvector3
meanDiffusivity[${cxt}]=${outdir}/${prefix}_meanDiffusivity
mask[${cxt}]=${outdir}/${prefix}_mask
radialDiffusivity[${cxt}]=${outdir}/${prefix}_radialDiffusivity
referenceVolume[${cxt}]=${outdir}/${prefix}_referenceVolume
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
###################################################################
# Prime the localised design file so that any outputs from this
# module appear beneath the correct header.
###################################################################
echo "" >> $design_local
echo "# *** outputs from dti2xcp[${cxt}] *** #" >> $design_local
echo "" >> $design_local
###################################################################
# This module should be incredibly quick. It will always be re-run.
###################################################################
###################################################################
# END GENERAL MODULE HEADER
###################################################################
###################################################################





echo "Configuring XCP Engine to process DTI data"





if [[ -e ${dti2xcp_dir[${cxt}]} ]] \
   && [[ -n ${dti2xcp_dir[${cxt}]} ]]
   then
   dtiquality[${cxt}]=$(ls -d1 ${dti2xcp_dir[${cxt}]}/qa/*quality.csv)
   qvars=$(head -n1 ${quality} 2>/dev/null)
   qvals=$(tail -n1 ${quality} 2>/dev/null)
   ################################################################
   # These variables are rather disorganised and ragged
   # Now, conform them to XCP standard
   ################################################################
   qvars=${qvars},$(head -n1 ${dtiquality[${cxt}]}\
      |sed s@', '@','@g\
      |sed s@' '@','@g\
      |cut -d',' -f4-14)
	qvals=${qvals},$(tail -n1 ${dtiquality[${cxt}]}\
	   |sed s@', '@','@g\
	   |sed s@' '@','@g\
	   |cut -d',' -f3-13)
   rm -f ${quality}
   echo ${qvars} >> ${quality}
   echo ${qvals} >> ${quality}
   
   ln -s $(ls -d1 ${dti2xcp_dir[${cxt}]}/dtifit/*MO${ext}) \
      ${anisotropyMode[${cxt}]}${ext}
   echo "anisotropyMode[${subjidx}]=${anisotropyMode[${cxt}]}" \
      >> ${design_local}
   echo "#anisotropyMode#${anisotropyMode[${cxt}]}#dti2xcp,${cxt}" \
      >> ${auxImgs[${subjidx}]}
   
   ln -s $(ls -d1 ${dti2xcp_dir[${cxt}]}/dtifit/*AD${ext}) \
      ${axialDiffusivity[${cxt}]}${ext}
   echo "axialDiffusivity[${subjidx}]=${axialDiffusivity[${cxt}]}" \
      >> ${design_local}
   echo "#axialDiffusivity#${axialDiffusivity[${cxt}]}#dti2xcp,${cxt}" \
      >> ${auxImgs[${subjidx}]}
   
   ln -s $(ls -d1 ${dti2xcp_dir[${cxt}]}/dtifit/*FA${ext}) \
      ${fractionalAnisotropy[${cxt}]}${ext}
   echo "fractionalAnisotropy[${subjidx}]=${fractionalAnisotropy[${cxt}]}" \
      >> ${design_local}
   echo "#fractionalAnisotropy#${fractionalAnisotropy[${cxt}]}#dti2xcp,${cxt}" \
      >> ${auxImgs[${subjidx}]}
   
   ln -s $(ls -d1 ${dti2xcp_dir[${cxt}]}/dtifit/*L1${ext}) \
      ${eigenvalue1[${cxt}]}${ext}
   echo "eigenvalue1[${subjidx}]=${eigenvalue1[${cxt}]}" \
      >> ${design_local}
   echo "#eigenvalue1#${eigenvalue1[${cxt}]}" \
      >> ${auxImgs[${subjidx}]}
   
   ln -s $(ls -d1 ${dti2xcp_dir[${cxt}]}/dtifit/*L2${ext}) \
      ${eigenvalue2[${cxt}]}${ext}
   echo "eigenvalue2[${subjidx}]=${eigenvalue2[${cxt}]}" \
      >> ${design_local}
   echo "#eigenvalue2#${eigenvalue2[${cxt}]}" \
      >> ${auxImgs[${subjidx}]}
   
   ln -s $(ls -d1 ${dti2xcp_dir[${cxt}]}/dtifit/*L3${ext}) \
      ${eigenvalue3[${cxt}]}${ext}
   echo "eigenvalue3[${subjidx}]=${eigenvalue3[${cxt}]}" \
      >> ${design_local}
   echo "#eigenvalue3#${eigenvalue3[${cxt}]}" \
      >> ${auxImgs[${subjidx}]}
   
   ln -s $(ls -d1 ${dti2xcp_dir[${cxt}]}/dtifit/*V1${ext}) \
      ${eigenvector1[${cxt}]}${ext}
   echo "eigenvector1[${subjidx}]=${eigenvector1[${cxt}]}" \
      >> ${design_local}
   echo "#eigenvector1#${eigenvector1[${cxt}]}" \
      >> ${auxImgs[${subjidx}]}
   
   ln -s $(ls -d1 ${dti2xcp_dir[${cxt}]}/dtifit/*V2${ext}) \
      ${eigenvector2[${cxt}]}${ext}
   echo "eigenvector2[${subjidx}]=${eigenvector2[${cxt}]}" \
      >> ${design_local}
   echo "#eigenvector2#${eigenvector2[${cxt}]}" \
      >> ${auxImgs[${subjidx}]}
   
   ln -s $(ls -d1 ${dti2xcp_dir[${cxt}]}/dtifit/*V3${ext}) \
      ${eigenvector3[${cxt}]}${ext}
   echo "eigenvector3[${subjidx}]=${eigenvector3[${cxt}]}" \
      >> ${design_local}
   echo "#eigenvector3#${eigenvector3[${cxt}]}" \
      >> ${auxImgs[${subjidx}]}
   
   ln -s $(ls -d1 ${dti2xcp_dir[${cxt}]}/dtifit/*MD${ext}) \
      ${meanDiffusivity[${cxt}]}${ext}
   echo "meanDiffusivity[${subjidx}]=${meanDiffusivity[${cxt}]}" \
      >> ${design_local}
   echo "#meanDiffusivity#${meanDiffusivity[${cxt}]}#dti2xcp,${cxt}" \
      >> ${auxImgs[${subjidx}]}
   
   ln -s $(ls -d1 ${dti2xcp_dir[${cxt}]}/dtifit/*RD${ext}) \
      ${radialDiffusivity[${cxt}]}${ext}
   echo "radialDiffusivity[${subjidx}]=${radialDiffusivity[${cxt}]}" \
      >> ${design_local}
   echo "#radialDiffusivity#${radialDiffusivity[${cxt}]}#dti2xcp,${cxt}" \
      >> ${auxImgs[${subjidx}]}

   ln -s $(ls -d1 ${dti2xcp_dir[${cxt}]}/dtifit/*S0${ext}) \
      ${referenceVolume[${cxt}]}${ext}
   echo "referenceVolume[${subjidx}]=${referenceVolume[${cxt}]}" \
      >> ${design_local}
   echo "#referenceVolume#${referenceVolume[${cxt}]}" \
      >> ${auxImgs[${subjidx}]}
   echo "referenceVolumeBrain[${subjidx}]=${referenceVolume[${cxt}]}" \
      >> ${design_local}
   echo "#referenceVolumeBrain#${referenceVolume[${cxt}]}" \
      >> ${auxImgs[${subjidx}]}
   
   fslmaths ${referenceVolume[${cxt}]} -bin ${mask[${cxt}]}
   echo "mask[${subjidx}]=${mask[${cxt}]}" \
      >> ${design_local}
   echo "#mask#${mask[${cxt}]}" \
      >> ${auxImgs[${subjidx}]}
else
   echo "::XCP-ERROR: The primary input is absent."
   exit 666
fi





echo "Module complete"
