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
#  * biasCorrected: N4 bias field corrected image
#  * skullStrippedImage: output image from antsBrainExtraction.sh
#  * brainExtractionMask: output image used for extraction from antsBrainExtraction.sh
#  * brainNormalizedToTemplate: The skull stripped strucutal image in template space
#  * antsCorticalMap: Output from antsCT
#  * brainSegmentation[0%d]: Output from ANts CT 6 class segmentation
#  * jlfLabels: output from ants JLF
#  * atropos3classprob[0%2d]: A soft segmentation from the output of Atropos
#  * atropos3dlcassseg: A hard 3 class tissue class segmentation
###################################################################
## ANTsCT OUTPUT ##
brainExtractionMask[${cxt}]=${outdir}/antsCT/${prefix}_BrainExtractionMask
brainNormalizedToTemplate[${cxt}]=${outdir}/antsCT/${prefix}_BrainNormalizedToTemplate
biasCorrected[${cxt}]=${outdir}/antsCT/${prefix}_BrainSegmentation0N4
brainSegmentation[${cxt}]=${outdir}/antsCT/${prefix}_BrainSegmentation
brainSegmentationPosteriors1[${cxt}]=${outdir}/antsCT/${prefix}_BrainSegmentationPosteriors1 
brainSegmentationPosteriors2[${cxt}]=${outdir}/antsCT/${prefix}_BrainSegmentationPosteriors2 
brainSegmentationPosteriors3[${cxt}]=${outdir}/antsCT/${prefix}_BrainSegmentationPosteriors3
brainSegmentationPosteriors4[${cxt}]=${outdir}/antsCT/${prefix}_BrainSegmentationPosteriors4
brainSegmentationPosteriors5[${cxt}]=${outdir}/antsCT/${prefix}_BrainSegmentationPosteriors5
brainSegmentationPosteriors6[${cxt}]=${outdir}/antsCT/${prefix}_BrainSegmentationPosteriors6
corticalThickness[${cxt}]=${outdir}/antsCT/${prefix}_CorticalThickness
corticalThicknessNormalizedToTemplate[${cxt}]=${outdir}/antsCT/${prefix}_CorticalThicknessNormalizedToTemplate
extractedBrain[${cxt}]=${outdir}/antsCT/${prefix}_ExtractedBrain0N4

## ANTsCT Transofrmations ##
xfm_warp=${outdir}/antsCT/${prefix}_SubjectToTemplate1Warp.nii.gz
ixfm_warp=${outdir}/antsCT/${prefix}_TemplateToSubject0Warp.nii.gz
xfm_affine=${outdir}/antsCT/${prefix}_SubjectToTemplate0GenericAffine.mat
ixfm_affine=${outdir}/antsCT/${prefix}_TemplateToSubject1GenericAffine.mat

## ANTsGMD OUTPUT ##
normalizedGmdInput[${cxt}]=${outdir}/atropos3class/${prefix}_ExtractedBrain0N4_Norm
gmdProbSkeloton[${cxt}]=${outdir}/antsGMD/${prefix}_prob
gmdProbability1[${cxt}]=${outdir}/antsGMD/${prefix}_prob01
gmdProbability2[${cxt}]=${outdir}/antsGMD/${prefix}_prob02
gmdProbability3[${cxt}]=${outdir}/antsGMD/${prefix}_prob03
gmdSegmentation[${cxt}]=${outdir}/antsGMD/${prefix}_seg
subjectToTempJacob[${cxt}]=${outdir}/antsGMD/${prefix}_SubjectToTemplateJacobian

## ROI quant Required Variables ##
referenceVolume[${cxt}]=${outdir}/antsCT/${prefix}_BrainSegmentation0N4
referenceVolumeBrain[${cxt}]=${outdir}/antsCT/${prefix}_ExtractedBrain0N4
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
if [[ $(imtest ${jlfLabels[${cxt}]}${ext}) == "1" ]] \
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
     echo "#corticalThickness#${corticalThickness[${cxt}]}#CT,${cxt}" \
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
  ###################################################################
  # OUTPUT: GMD Values
  # Test whether the ANTs GMD image was created.
  # If it does exist then add it to the index of derivatives and 
  # to the localised design file
  ###################################################################
  if [[ $(imtest "${gmdProbability2[${cxt}]}") == "1" ]]
     then
     echo "gmdProbability2[${subjidx}]=${gmdProbability2[${cxt}]}"\
        >> $design_local
     echo "#gmdProbability2#${gmdProbability2[${cxt}]},#GMD,${cxt}" \
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
#  * AGD: ANTs Atropos GMD pipeline
###################################################################

rem=${structural_process[${cxt}]}
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
  [[ ${cur} != SNR ]] && buffer=${buffer}_${cur}
  case $cur in



    ACT)
        ###################################################################
        ###################################################################
        # * Run ANTsCT
        ###################################################################
        ###################################################################
        echo ""; echo ""; echo ""
        echo "Current processing step:"
        echo "Running ANTs N4 Bias Field Correction"
        mkdir -p ${outdir}/antsCT/
        ###################################################################
        # Define any inputs if non were provided | not present
        ###################################################################
        if [[ ! -f "${templateExtracted}" ]] \
           || [[ ! -f "${templateNonExtracted}" ]]
            then
            echo "No template - ANTsCT pipeline can not wrong"
            exit 16
        fi
        if [[ "X${templateWeight}" == "X" ]]
            then
            templateWeight=".2"
        fi
        ###################################################################
        # Now run the ANTsCT pipeline
        ###################################################################
        antsCMD="${ANTSPATH}antsCorticalThickness.sh -d 3 -a ${img}${ext} -e ${templateNonExtracted} -m ${templateMask} -f ${templateMaskDil} -p ${templatePriors} -w ${templateWeight} -t ${templateExtracted} -o ${outdir}/antsCT/${prefix}_"
        ${antsCMD}
        ###################################################################
        # Now point img to the correct output
        ###################################################################
        img=${outdir}/antsCT/${prefix}_ExtractedBrain0N4
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
        mkdir -p ${outdir}/antsN4/
        ###################################################################
        # Define any inputs if non were provided | not present
        ###################################################################
        if [[ "X ${ N4_CONVERGENCE}" == "X"]]
            N4_CONVERGENCE="-c [50x50x50x50,0.0000001]"
        fi
        if [[ "X${N4_SHRINK_FACTOR}" == "X" ]]
            N4_SHRINK_FACTOR="-s 2"
        fi
        if [[ "X${N4_BSPLINE_PARAMS}" == "X" ]]
            N4_BSPLINE_PARAMS="-b [200]"
        fi
        ###################################################################
        # Now run the ANTs N4 Bias Field Correction Command
        ###################################################################
        n4CMD="${ANTSPATH}/N4BiasFieldCorrection -d 3 -i ${img}${ext} ${N4_CONVERGENCE} ${N4_SHRINK_FACTOR} ${N4_BSPLINE_PARAMS} -o ${outdir}/antsN4/${prefix}_N4Corrected"
        ${n4CMD}
        ###################################################################
        # Now point img to the correct output
        ###################################################################
        img=${outdir}/antsN4/${prefix}_N4Corrected
        echo "done with ANTs Bias Field Correction"
        ;;
    AGD)
        ###################################################################
        ###################################################################
        # * Run ANTs Atropos GMD pipeline
        # GMD is computed from the native structural, typically bias field corrected and
        # skull stripped image, It is run through atropos 3 times and the soft segmentation
        # is used to compute GMD values
        ###################################################################
        ###################################################################
        echo ""; echo ""; echo ""
        echo "Current processing step:"
        echo "Running ANTsGMD"
        mkdir -p ${outdir}/antsGMD/
        ###################################################################
        # Now lets produce our soft segmentation images
        ###################################################################
        for i in 1 2 3 ; do
            if [ ${i} -eq 1 ] ; then
              ${ANTSPATH}Atropos -d 3 -a ${normalizedGmdInput[${cxt}]}${ext} -i KMeans[3] \
              -c [ 5,0] -m [ 0,1x1x1] -x ${brainExtractionMask[${cxt}]}${ext} \
              -o [ ${gmdSegmentation[${cxt}]}${ext}, ${gmdProbSkeloton[${cxt}]}%02d${ext}]
          else
              ${ANTSPATH}Atropos -d 3 -a ${normalizedGmdInput[${cxt}]}${ext} \
              -i PriorProbabilitImages[ 3,${gmdProbSkeloton[${cxt}]}%02d${ext},0.0] \
              -k Gaussian -p Socrates[1] --use-partial-volume-likelihoods 0 \
              -c [ 12, 0.00001] \
              -x ${brainExtractionMask[${cxt}]}${ext} \
              -m [ 0,1x1x1] \
              -o [ ${gmdSegmentation[${cxt}]}${ext}, ${gmdProbSkeloton[${cxt}]}%02d${ext}] ;
          fi
          echo "Done with $i iteration of atropos"
        done



    esac
done
###################################################################
# Write any remaining output paths to local design file so that
# they may be used further along the pipeline.
###################################################################
echo ""; echo ""; echo ""
echo "Writing outputs..."
rm -f ${out}/${prefix}${ext}
ln -s ${extractedBrain[${cxt}]}${ext} ${out}/${prefix}${ext}
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
   echo "#corticalThickness#${corticalThickness[${cxt}]}#CT,${cxt}" \
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
###################################################################
# OUTPUT: GMD Values
# Test whether the ANTs GMD image was created.
# If it does exist then add it to the index of derivatives and 
# to the localised design file
###################################################################
if [[ $(imtest "${gmdProbability2[${cxt}]}") == "1" ]]
   then
   echo "gmdProbability2[${subjidx}]=${gmdProbability2[${cxt}]}"\
      >> $design_local
   echo "#gmdProbability2#${gmdProbability2[${cxt}]},#GMD,${cxt}" \
      >> ${auxImgs[${subjidx}]}
fi
###################################################################
# OUTPUT: JLF Labels
# Test whether the ANTs GMD image was created.
# If it does exist then add it to the index of derivatives and 
# to the localised design file
###################################################################
if [[ $(imtest "${jlfLabels[${cxt}]}") == "1" ]]
   then
   echo "jlfLabels[${subjidx}]=${jlfLabels[${cxt}]}"\
      >> $design_local
   echo "#jlfLabels#${jlfLabels[${cxt}]}" \
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


###################################################################
# CLEANUP
#  * Remove any temporary files if cleanup is enabled.
#  * Update the audit file and quality index.
###################################################################
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
