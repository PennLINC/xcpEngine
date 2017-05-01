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
echo "#  ☭              EXECUTING Strucutral MODULE                  ☭  #"
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
outdir=${out}/${prep}structural
[[ ! -e ${outdir} ]] && mkdir -p ${outdir}
echo "Output directory is $outdir"
###################################################################
# Define paths to all potential outputs.
#
# For the structural module, potential outputs include:
# Define paths to all potential outputs.
#
# For the structural module, potential outputs include:
#  * brainExtractionMask: Mask used to remove skull from image
#  * brainNormalizedToTemplate: Brain in template space
#  * biasCorrected: Bias field corrected image used for segmentation
#  * brainExtractionMask: Mask used to remove skull from image
#  * brainSegmentationPosterior[%02d]: Soft segmentation coresponding to zspecfific tissue class
#  * corticalThickness: A voxel wise map of cortical thickness in subject space
#  * corticalThicknessNormalizedToTemplaye: A voxel wise map of cortical thickness in template space
#  * extractedBrain: A bias field corrected extracted subject space brain

###################################################################
## ANTsCT OUTPUT ##
brainExtractionMask[${cxt}]=${outdir}/${prefix}_BrainExtractionMask
brainNormalizedToTemplate[${cxt}]=${outdir}/${prefix}_BrainNormalizedToTemplate
biasCorrected[${cxt}]=${outdir}/${prefix}_BrainSegmentation0N4
brainSegmentation[${cxt}]=${outdir}/${prefix}_BrainSegmentation
brainSegmentationPosteriors1[${cxt}]=${outdir}/${prefix}_BrainSegmentationPosteriors1 
brainSegmentationPosteriors2[${cxt}]=${outdir}/${prefix}_BrainSegmentationPosteriors2 
brainSegmentationPosteriors3[${cxt}]=${outdir}/${prefix}_BrainSegmentationPosteriors3
brainSegmentationPosteriors4[${cxt}]=${outdir}/${prefix}_BrainSegmentationPosteriors4
brainSegmentationPosteriors5[${cxt}]=${outdir}/${prefix}_BrainSegmentationPosteriors5
brainSegmentationPosteriors6[${cxt}]=${outdir}/${prefix}_BrainSegmentationPosteriors6
corticalThickness[${cxt}]=${outdir}/${prefix}_CorticalThickness
corticalThicknessNormalizedToTemplate[${cxt}]=${outdir}/${prefix}_CorticalThicknessNormalizedToTemplate
extractedBrain[${cxt}]=${outdir}/${prefix}_ExtractedBrain0N4

## ANTsCT Transofrmations ##
xfm_warp=${outdir}/${prefix}_SubjectToTemplate1Warp
ixfm_warp=${outdir}/${prefix}_TemplateToSubject0Warp
xfm_affine=${outdir}/${prefix}_SubjectToTemplate0GenericAffine.mat
ixfm_affine=${outdir}/${prefix}_TemplateToSubject1GenericAffine.mat

## ROI quant Required Variables ##
referenceVolume[${cxt}]=${outdir}/${prefix}_BrainSegmentation0N4
referenceVolumeBrain[${cxt}]=${outdir}/${prefix}_ExtractedBrain0N4

## Structural QA Output ##
fgMask[${cxt}]=${outdir}/${prefix}_foreGroundMask
threeClassSeg[${cxt}]=${outdir}/${prefix}_threeClassSeg
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
echo "# *** outputs from structural[${cxt}] *** #" >> $design_local
echo "" >> $design_local
###################################################################
# Verify that the module should be run:
#  * Test whether the final output already exists.
#  * Determine whether the user requested the module to be re-run.
# If it is determined that the module should not be run, then any
#  outputs must be written to the local design file.
###################################################################
if [[ $(imtest ${extractedBrain[${cxt}]}${ext}) == "1" ]] \
  && [[ "${structural_rerun[${cxt}]}" == "N" ]]
  then
  echo "Structural has already run to completion."
  echo "Writing outputs..."
  if [[ "${structural_cleanup[${cxt}]}" == Y ]]
    then
    rm -rf ${outdir}/*~TEMP~*
  fi
  rm -f ${out}/${prefix}${ext}
  ln -s ${extractedBrain[${cxt}]}${ext} ${out}/${prefix}${ext} ; 
  ###################################################################
  # OUTPUT: Brain Extraction Mask
  # Test whether the brain extraction mask was created.
  # If it does exist then add it to the index of derivatives and 
  # to the localised design file
  ###################################################################
  if [[ $(imtest "${brainExtractionMask[${cxt}]}") == "1" ]]
     then
     echo "brainExtractionMask[${subjidx}]=${brainExtractionMask[${cxt}]}"\
        >> $design_local
     echo "#brainExtractionMask#${brainExtractionMask[${cxt}]}" \
        >> ${auxImgs[${subjidx}]}
  fi
  ###################################################################
  # OUTPUT: Brain Normalized To Template
  # Test whether the normalized brain was created.
  # If it does exist then add it to the index of derivatives and 
  # to the localised design file
  ###################################################################
  if [[ $(imtest "${brainNormalizedToTemplate[${cxt}]}") == "1" ]]
     then
     echo "brainNormalizedToTemplate[${subjidx}]=${brainNormalizedToTemplate[${cxt}]}"\
        >> $design_local
     echo "#brainNormalizedToTemplate#${brainNormalizedToTemplate[${cxt}]}" \
        >> ${auxImgs[${subjidx}]}
  fi
  ###################################################################
  # OUTPUT: Bias Corrected Anatomical
  # Test whether the bias field corrected raw anatomical image was created.
  # If it does exist then add it to the index of derivatives and 
  # to the localised design file
  ###################################################################
  if [[ $(imtest "${biasCorrected[${cxt}]}") == "1" ]]
     then
     echo "biasCorrected[${subjidx}]=${biasCorrected[${cxt}]}"\
        >> $design_local
     echo "#biasCorrected#${biasCorrected[${cxt}]}" \
        >> ${auxImgs[${subjidx}]}
  fi
  ###################################################################
  # OUTPUT: Brain Segmentation
  # Test whether the ANTsCT segmentation image was created.
  # If it does exist then add it to the index of derivatives and 
  # to the localised design file
  ###################################################################
  if [[ $(imtest "${brainSegmentation[${cxt}]}") == "1" ]]
     then
     echo "brainSegmentation[${subjidx}]=${brainSegmentation[${cxt}]}"\
        >> $design_local
     echo "#brainSegmentation#${brainSegmentation[${cxt}]}" \
        >> ${auxImgs[${subjidx}]}
  fi
  ###################################################################
  # OUTPUT: Cortical Thickness
  # Test whether the ANTsCT cortical thickness image was created.
  # If it does exist then add it to the index of derivatives and 
  # to the localised design file
  ###################################################################
  if [[ $(imtest "${corticalThickness[${cxt}]}") == "1" ]]
     then
     echo "corticalThickness[${subjidx}]=${corticalThickness[${cxt}]}"\
        >> $design_local
     echo "#corticalThickness#${corticalThickness[${cxt}]}#antsCT,${cxt}" \
        >> ${auxImgs[${subjidx}]}
  fi
  ###################################################################
  # OUTPUT: Brain Extracted Image
  # Test whether the ANTsCT BE and N4 bias field corrected image was created.
  # If it does exist then add it to the index of derivatives and 
  # to the localised design file
  ###################################################################
  if [[ $(imtest "${extractedBrain[${cxt}]}") == "1" ]]
     then
     echo "struct[${subjidx}]=${extractedBrain[${cxt}]}"\
        >> $design_local
     echo "#struct#${extractedBrain[${cxt}]}" \
        >> ${auxImgs[${subjidx}]}
  fi
   ################################################################
   # OUTPUT: brain-extracted referenceVolume
   # Use the brain extracted image from the output of antsCT 
   # as our reference volume. This is used in order to succesfully run roi quant
   ################################################################
   if [[ $(imtest ${referenceVolumeBrain[${cxt}]}) == "1" ]]
      then
      echo "referenceVolumeBrain[${subjidx}]=${referenceVolumeBrain[${cxt}]}" \
         >> $design_local
      echo "#referenceVolumeBrain#${referenceVolumeBrain[${cxt}]}" \
         >> ${auxImgs[${subjidx}]}
   fi
   ################################################################
   # OUTPUT: referenceVolume
   # Test whether an example functional volume exists as an
   # image. If it does, add it to the index of derivatives and to
   # the localised design file. Again this is used to run the roiquant module
   ################################################################
   if [[ $(imtest ${referenceVolume[${cxt}]}) == "1" ]]
      then
      echo "referenceVolume[${subjidx}]=${referenceVolume[${cxt}]}" \
         >> $design_local
      echo "#referenceVolume#${referenceVolume[${cxt}]}" \
         >> ${auxImgs[${subjidx}]}
   fi
   ################################################################
   # OUTPUT: Transformations
   # Now export the transformations computed during the antsCT processing   
   ################################################################ 
   if [[ $(imtest ${xfm_warp}) == "1" ]]
     then
     echo "xfm_warp=${xfm_warp}" \
        >> $design_local
   fi
   if [[ $(imtest ${ixfm_warp}) == "1" ]]
    then
    echo "ixfm_warp=${ixfm_warp}" \
       >> $design_local
   fi
   if [[ -f ${xfm_affine} ]] 
      then
      echo "xfm_affine=${xfm_affine}" \
       >> $design_local
   fi
   if [[ -f ${ixfm_affine} ]]
      then
      echo "ixfm_affine=${ixfm_affine}" \
       >> $design_local
   fi

  echo ""; echo ""; echo ""
  if [[ "${strucutral_cleanup[${cxt}]}" == "Y" ]]
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
  exit 0 
fi



###################################################################
###################################################################
# END GENERAL MODULE HEADER
###################################################################
###################################################################

###################################################################
# The variable 'buffer' stores the processing steps that are
# already complete; it becomes the expected ending for the final
# image name and is used to verify that prestats has completed
# successfully.
###################################################################
buffer=""


echo "Processing image: $img"

###################################################################
# Parse the processing code to determine what analysis to run next.
# Current options include:
#  * ACT: ANTs CT pipeline
#  * ABF: ANTs N4 bias field correction
#  * ABE: ANTs Brain Extraction
#  * FBE: FSL Brain Extraction using BET
###################################################################

rem=${structural_process[${cxt}]}
i=0
while [[ "${#rem}" -gt "0" ]]
  do
  ################################################################
  # * Extract the first three letters from the user-specified
  #   processing command.
  # * This three-letter code determines what analysis is run
  #   next.
  # * Remove them from the list of remaining analyses.
  ################################################################
  cur=${rem:0:3}
  rem=${rem:3:${#rem}}
  case $cur in  
    ACT)
        ###################################################################
        ###################################################################
        # * Run ANTsCT
        ###################################################################
        ###################################################################
        echo ""; echo ""; echo ""
        echo "Current processing step:"
        echo "Running ANTs Cortical Thickness Pipeline"
        ###################################################################
        # Now find the latest structural image processed and ensure that
	# is our input image
        ###################################################################
	if [ ${i} -gt 0 ] ; then 
	  # Find the latest structural image output
	  if [ ${buffer} == "ACT" ] ; then 
		img=${outdir}/${prefix}_ExtractedBrain0N4 ; 
	  fi
	  if [ ${buffer} == "ABE" ] ; then  
		img=${outdir}/${prefix}_BrainExtractionBrain ; 
	  fi 
	  if [ ${buffer} == "ABF" ] ; then
		t=`echo "${i} - 1" | bc`
		img=${outdir}/${prefix}_N4Corrected${t} ; 
          fi
	  if [ ${buffer} == "FBE" ] ; then 
		img=${outdir}/${prefix}_BrainExtractionBrain ;
          fi
	fi 
        ###################################################################
        # Now run the ANTsCT pipeline
        ###################################################################
        templateExtracted="${template}"
        antsCMD="${ANTSPATH}antsCorticalThickness.sh -d 3 -a ${img}${ext} \
                 -e ${templateNonExtracted} -m ${templateMask} \
                 -f ${templateMaskDil} -p ${templatePriors} \
                 -w ${EXTRACTION_PRIOR[${cxt}]} -t ${templateExtracted} \
                 -o ${outdir}/${prefix}_ -s ${antsExt}"
        ${antsCMD}
	buffer=ACT
        echo "done with ANTsCT pipeline"
        ;;
    ABF)
        ###################################################################
        ###################################################################
        # * Run N4 Bias Field Correction
        ###################################################################
        ###################################################################
        echo ""; echo ""; echo ""
        echo "Current processing step:"
        echo "Running ANTs N4 Bias Field Correction"        
        ###################################################################
        # Now find the latest structural image processed and ensure that
	# is our input image
        ###################################################################
	if [ ${i} -gt 0 ] ; then 
	  # Find the latest structural image output
	  if [ ${buffer} == "ACT" ] ; then 
		img=${outdir}/${prefix}_ExtractedBrain0N4 ; 
	  fi
	  if [ ${buffer} == "ABE" ] ; then  
		img=${outdir}/${prefix}_BrainExtractionBrain ; 
	  fi 
	  if [ ${buffer} == "ABF" ] ; then
		t=`echo "${i} - 1" | bc`
		img=${outdir}/${prefix}_N4Corrected${t} ; 
          fi
	  if [ ${buffer} == "FBE" ] ; then 
		img=${outdir}/${prefix}_BrainExtractionBrain ;
          fi
	fi 	  
        ###################################################################
        # Now run the ANTs N4 Bias Field Correction Command
        ###################################################################
        n4CMD="${ANTSPATH}/N4BiasFieldCorrection -d 3 -i ${img}${ext} \
               -c ${N4_CONVERGENCE[${cxt}]} -s ${N4_SHRINK_FACTOR[${cxt}]} -b ${N4_BSPLINE_PARAMS[${cxt}]} \
               -o ${outdir}/${prefix}_N4Corrected${i}${ext} --verbose 1"
        ${n4CMD}
	buffer=ABF
        echo "done with ANTs Bias Field Correction"
        ###################################################################
        # Now make sure we preserve each bias field correction step
	# while we keep the proper nomencalture for steps through other pipelines
        ###################################################################
	echo ${rem} | grep -e "ABE" -e "ACT" > /dev/null
	if [ $? -eq 0 ] && [ ${i} -gt 0 ] ; then 
          ln -f ${img}${ext} ${outdir}/${prefix}_N4Corrected0${ext} ; 
        fi
        ;;
    ABE)
        ###################################################################
        ###################################################################
        # * Run ANTs Brain Extraction
        ###################################################################
        ###################################################################
        echo ""; echo ""; echo ""
        echo "Current processing step:"
        echo "Running ANTs BE"
        ###################################################################
        # Now find the latest structural image processed and ensure that
	# is our input image
        ###################################################################
	if [ ${i} -gt 0 ] ; then 
	  # Find the latest structural image output
	  if [ ${buffer} == "ACT" ] ; then 
		img=${outdir}/${prefix}_ExtractedBrain0N4 ; 
	  fi
	  if [ ${buffer} == "ABE" ] ; then  
		img=${outdir}/${prefix}_BrainExtractionBrain ; 
	  fi 
	  if [ ${buffer} == "ABF" ] ; then
		t=`echo "${i} - 1" | bc`
		img=${outdir}/${prefix}_N4Corrected${t} ; 
          fi
	  if [ ${buffer} == "FBE" ] ; then 
		img=${outdir}/${prefix}_BrainExtractionBrain ;
          fi
	fi 	
        ###################################################################
        # Now run the ANTs BE Command
        ###################################################################
        beCMD="${ANTSPATH}/antsBrainExtraction.sh -d 3 -a ${img}${ext} \
              -e ${templateExtracted} ${EXTRACTION_PRIOR[${cxt}]} ${KEEP_BE_IMAGES[${cxt}]} \
              ${USE_BE_FLOAT[${cxt}]} ${USE_BE_RANDOM_SEED[${cxt}]} \
              -o ${outdir}/${prefix}_ -s ${antsExt}"
        ${beCMD}
	buffer=ABE
        echo "done with ANTs Brain Extraction"
        ;;
    FBE)
        ###################################################################
        ###################################################################
        # * Run FSL Brain Extraction
        ###################################################################
        ###################################################################
        echo ""; echo ""; echo ""
        echo "Current processing step:"
        echo "Running FSL BE"
	echo "Fractional intensity threshold: ${structural_fit[${cxt}]}"
        ###################################################################
        # Now find the latest structural image processed and ensure that
	# is our input image
        ###################################################################
	if [ ${i} -gt 0 ] ; then 
	  # Find the latest structural image output
	  if [ ${buffer} == "ACT" ] ; then 
		img=${outdir}/${prefix}_ExtractedBrain0N4 ; 
	  fi
	  if [ ${buffer} == "ABE" ] ; then  
		img=${outdir}/${prefix}_BrainExtractionBrain ; 
	  fi 
	  if [ ${buffer} == "ABF" ] ; then
		t=`echo "${i} - 1" | bc`
		img=${outdir}/${prefix}_N4Corrected${t} ; 
          fi
	  if [ ${buffer} == "FBE" ] ; then 
		img=${outdir}/${prefix}_BrainExtractionBrain ;
          fi
	fi       
        ###################################################################
        # Now run the FSL BE Command
        ###################################################################
        beCMD="bet ${img}${ext} ${outdir}/${prefix} -f ${structural_fit[${cxt}]} -m"
	${beCMD}
        ###################################################################
        # Now organize the files to meet ANTsCT nomenclature
        ###################################################################
	immv ${outdir}/${prefix} ${outdir}/${prefix}_BrainExtractionBrain	
	immv ${outdir}/${prefix}_mask ${outdir}/${prefix}_BrainExtractionMask
	buffer=FBE
        echo "done with FSL Brain Extraction"
        ;;	
    esac
    i=`echo "${i} + 1" | bc` 
done
###################################################################
# Calculate cross corellation 
###################################################################
qa_cc=$(fslcc -p 8 ${templateExtracted} ${brainNormalizedToTemplate[${cxt}]}\
            |awk '{print $3}')
qvars=`echo "${qvars},NormCrossCor"`
qvals=`echo "${qvals},${qa_cc}"`
###################################################################
# Write any remaining output paths to local design file so that
# they may be used further along the pipeline.
###################################################################
echo ""; echo ""; echo ""
echo "Writing outputs..."
rm -f ${out}/${prefix}${ext}
ln -s ${img}${ext} ${out}/${prefix}${ext}
###################################################################
# OUTPUT: Brain Extraction Mask
# Test whether the brain extraction mask was created.
# If it does exist then add it to the index of derivatives and 
# to the localised design file
###################################################################
if [[ $(imtest "${brainExtractionMask[${cxt}]}") == "1" ]]
   then
   echo "brainExtractionMask[${subjidx}]=${brainExtractionMask[${cxt}]}"\
      >> $design_local
   echo "#brainExtractionMask#${brainExtractionMask[${cxt}]}" \
      >> ${auxImgs[${subjidx}]}
fi
###################################################################
# OUTPUT: Brain Normalized To Template
# Test whether the normalized brain was created.
# If it does exist then add it to the index of derivatives and 
# to the localised design file
###################################################################
if [[ $(imtest "${brainNormalizedToTemplate[${cxt}]}") == "1" ]]
   then
   echo "brainNormalizedToTemplate[${subjidx}]=${brainNormalizedToTemplate[${cxt}]}"\
      >> $design_local
   echo "#brainNormalizedToTemplate#${brainNormalizedToTemplate[${cxt}]}" \
      >> ${auxImgs[${subjidx}]}
fi
###################################################################
# OUTPUT: Bias Corrected Anatomical
# Test whether the bias field corrected raw anatomical image was created.
# If it does exist then add it to the index of derivatives and 
# to the localised design file
###################################################################
if [[ $(imtest "${biasCorrected[${cxt}]}") == "1" ]]
   then
   echo "biasCorrected[${subjidx}]=${biasCorrected[${cxt}]}"\
      >> $design_local
   echo "#biasCorrected#${biasCorrected[${cxt}]}" \
      >> ${auxImgs[${subjidx}]}
fi
###################################################################
# OUTPUT: Brain Segmentation
# Test whether the ANTsCT segmentation image was created.
# If it does exist then add it to the index of derivatives and 
# to the localised design file
###################################################################
if [[ $(imtest "${brainSegmentation[${cxt}]}") == "1" ]]
   then
   echo "brainSegmentation[${subjidx}]=${brainSegmentation[${cxt}]}"\
      >> $design_local
   echo "#brainSegmentation#${brainSegmentation[${cxt}]}" \
      >> ${auxImgs[${subjidx}]}
fi
###################################################################
# OUTPUT: Cortical Thickness
# Test whether the ANTsCT cortical thickness image was created.
# If it does exist then add it to the index of derivatives and 
# to the localised design file
###################################################################
if [[ $(imtest "${corticalThickness[${cxt}]}") == "1" ]]
   then
   echo "corticalThickness[${subjidx}]=${corticalThickness[${cxt}]}"\
      >> $design_local
   echo "#corticalThickness#${corticalThickness[${cxt}]}#antsCT,${cxt}" \
      >> ${auxImgs[${subjidx}]}
fi
###################################################################
# OUTPUT: Brain Extracted Image
# Test whether the ANTsCT BE and N4 bias field corrected image was created.
# If it does exist then add it to the index of derivatives and 
# to the localised design file
###################################################################
if [[ $(imtest "${extractedBrain[${cxt}]}") == "1" ]]
   then
   echo "struct[${subjidx}]=${extractedBrain[${cxt}]}"\
      >> $design_local
   echo "#struct#${extractedBrain[${cxt}]}" \
      >> ${auxImgs[${subjidx}]}
fi
################################################################
# OUTPUT: brain-extracted referenceVolume
# Use the brain extracted image  
# as our reference volume. This is used in order to succesfully run roi quant
################################################################
if [[ $(imtest ${referenceVolumeBrain[${cxt}]}) == "1" ]]
   then
   echo "referenceVolumeBrain[${subjidx}]=${referenceVolumeBrain[${cxt}]}" \
      >> $design_local
   echo "#referenceVolumeBrain#${referenceVolumeBrain[${cxt}]}" \
      >> ${auxImgs[${subjidx}]}
fi
################################################################
# OUTPUT: Transformations
# Now export the transformations computed during the antsCT processing   
################################################################ 
if [[ $(imtest ${xfm_warp}) == "1" ]]
  then
  echo "xfm_warp=${xfm_warp}" \
     >> $design_local
fi
if [[ $(imtest ${ixfm_warp}) == "1" ]]
 then
 echo "ixfm_warp=${ixfm_warp}" \
    >> $design_local
fi
if [[ -f ${xfm_affine} ]] 
   then
   echo "xfm_affine=${xfm_affine}" \
    >> $design_local
fi
if [[ -f ${ixfm_affine} ]]
   then
   echo "ixfm_affine=${ixfm_affine}" \
    >> $design_local
fi


###################################################################
# CLEANUP
#  * Remove any temporary files if cleanup is enabled.
#  * Update the audit file and quality index.
###################################################################
echo ""; echo ""; echo ""
img=$(readlink -f ${img}${ext})
ln -s ${extractedBrain[${cxt}]}${ext} ${out}/${prefix}${ext}
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
