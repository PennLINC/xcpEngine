#!/usr/bin/env bash

###################################################################
#  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  #
###################################################################

###################################################################
# Constants
###################################################################
readonly POSINT='^[0-9]+$'
readonly POSNUM='^[0-9]+([.][0-9]+)?$'





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
echo "#  ☭                 EXECUTING CONFOUND MODULE                 ☭  #"
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
outdir=${out}/${prep}confound
[[ ! -e ${outdir} ]] && mkdir -p ${outdir}
echo "Output directory is $outdir"
###################################################################
# Define paths to all potential outputs.
#
# For the confound module, potential outputs include:
#  * gmmask : The final extracted, eroded, and transformed grey
#    matter mask in subject functional space. Use to ensure
#    quality.
#  * wmmask : The final extracted, eroded, and transformed white
#    matter mask in subject functional space. Use to ensure
#    quality.
#  * csfmask : The final extracted, eroded, and transformed
#    cerebrospinal fluid mask in subject functional space. Use to
#    ensure quality.
#  * confmat : A 1D file containing all global nuisance timeseries
#    for the current subject, including any user-specified
#    timeseries and previous time points, derivatives, and powers.
#  * While a confound matrix file does not exist at the target
#    path, confmat will store the string 'null' for the purposes
#    of the mbind utility. As mbind is updated, this may change.
###################################################################
gmMask[${cxt}]=${outdir}/${prefix}_maskGM
wmMask[${cxt}]=${outdir}/${prefix}_maskWM
csfMask[${cxt}]=${outdir}/${prefix}_maskCSF
confmat_path=${outdir}/${prefix}_confmat.1D
confmat[${cxt}]=null
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
###################################################################
# Prime the localised design file so that any outputs from this
# module appear beneath the correct header.
###################################################################
echo "" >> $design_local
echo "# *** outputs from confound[${cxt}] *** #" >> $design_local
echo "" >> $design_local
###################################################################
# Verify that the module should be run:
#  * Test whether the final output already exists.
#  * Ensure that the final output has the expected number of
#    columns/timeseries.
#  * Determine whether the user requested the module to be re-run.
# If it is determined that the module should not be run, then any
#  outputs must be written to the local design file.
###################################################################
if [[ -e ${confmat_path} ]]
   then
   obs=$(head -n1 ${confmat_path}|wc -w)
   exp=0
   [[ ${confound_rp[${cxt}]} == Y ]] && exp=$(echo ${exp} + 6|bc)
   [[ ${confound_rms[${cxt}]} == Y ]] && exp=$(echo ${exp} + 1|bc)
   [[ ${confound_gm[${cxt}]} == Y ]] && exp=$(echo ${exp} + 1|bc)
   [[ ${confound_wm[${cxt}]} == Y ]] && exp=$(echo ${exp} + 1|bc)
   [[ ${confound_csf[${cxt}]} == Y ]] && exp=$(echo ${exp} + 1|bc)
   [[ ${confound_gsr[${cxt}]} == Y ]] && exp=$(echo ${exp} + 1|bc)
   exp=$(echo ${exp} + ${confound_cc[${cxt}]}|bc)
   past=$(echo ${confound_past[${cxt}]} + 1|bc)
   dx=$(echo ${confound_dx[${cxt}]} + 1|bc)
   exp=$(echo ${exp} \* ${past} \* ${dx} \* ${confound_sq[${cxt}]}|bc)
   for cts in ${confound_custom[${cxt}]}
      do
      ctsn=$(tail -n1 ${cts}|wc -w)
      exp=$(echo ${exp} + ${ctsn}|bc)
   done
   [[ ${obs} == ${exp} ]] \
      && completion=match \
      || echo "Dimensions of the existing confound matrix are incorrect"
fi
###################################################################
# If it is determined that the module does not need to be
# executed, update the audit file and exit the module.
###################################################################
if [[ ${completion} == "match" ]] \
   && [[ ${confound_rerun[${cxt}]} == "N" ]]
   then
   echo "Confound assembly has already run to completion."
   echo "Writing outputs..."
   if [[ "${confound_cleanup[${cxt}]}" == "Y" ]]
      then
      rm -rf ${outdir}/*~TEMP~*
   fi
   echo "confmat[${subjidx}]=$confmat_path" >> $design_local
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
# helper functions
# This is no longer used.
###################################################################
#standardise () {
#
#   ################################################################
#   # If the brain is in standard space, it will be necessary
#   # to standardise tissue masks prior to mean signal extraction
#   # Here, we create a dummy design file and run a single-step
#   # norm mod without coregistration (since the masks should be
#   # in structural space to begin with)
#   ################################################################
#   echo "Standardising $tissue"
#   to_std=$1
#   tissue=$2
#   printout=${outdir}/${tissue}_normseg
#   subdesign=${printout}/${tissue}_design.sh
#   mkdir -p $printout
#   struct=$(grep -i "struct[" $design_local)
#   normvars=$(grep -i "norm_" $design_local\
#      |sed -E s@[0-9]+\]@1\]@g)
#   normvars=$(echo $normvars\
#      |sed -E s@'rerun\[1\]=.*$'@'rerun\[1\]=Y'@g)
#   globals=$(cat global.sh)
#   globals=$(echo "$globals"|sed s/^#.*$//g)
#   globals=$(echo "$globals"|sed s/^sequence.*$/sequence=norm/g)
#   globals=$(echo "$globals"|sed s/^startdir.*$//g)
#   echo "$globals" >> $subdesign
#   echo "design=${subdesign}" >> $subdesign
#   echo "subject=${subject}" >> $subdesign
#   echo "prefix=${prefix}" >> $subdesign
#   echo "out=${printout}" >> $subdesign
#   echo "$struct" >> $subdesign
#   echo "$normvars" >> $subdesign
#   fslmaths $to_std ${printout}/${prefix}
#   ./normMOD.sh $subdesign 1 > /dev/null
#   fslmaths ${printout}/${prefix} $to_std
#   
#}
###################################################################
###################################################################
# END GENERAL MODULE HEADER
###################################################################
###################################################################





###################################################################
# Pool any transforms necessary for moving between standard and
# native space. Determine which transforms need to be applied for
# such a move.
###################################################################
coreg="-t ${seq2struct[${subjidx}]}"
icoreg="-t ${struct2seq[${subjidx}]}"
if [[ ! -z ${xfm_warp} ]] \
   && [[ $(imtest "${xfm_warp}") == 1 ]]
   then
	warp="-t ${xfm_warp}"
	iwarp="-t ${ixfm_warp}"
fi
if [[ ! -z ${xfm_affine} ]]
	then
	affine="-t ${xfm_affine}"
	iaffine="-t [${xfm_affine},1]"
fi
if [[ ! -z ${xfm_rigid} ]]
	then
	rigid="-t ${xfm_rigid}"
	irigid="-t [${xfm_rigid},1]"
fi
if [[ ! -z ${xfm_resample} ]]
	then
	resample="-t ${xfm_resample}"
	iresample="-t [${xfm_resample},1]"
fi





###################################################################
# REALIGNMENT PARAMETERS
# Realignment parameters should have been computed using the MPR
# subroutine of the prestats module prior to their use in the
# confound matrix here.
###################################################################
if [[ "${confound_rp[${cxt}]}" == "Y" ]]
   then
   echo "Including realignment parameters in confound model."
   ################################################################
   # Add the RPs to the confound matrix.
   ################################################################
   ${XCPEDIR}/utils/mbind.R \
      -x ${confmat[${cxt}]} \
      -y ${rps[${subjidx}]} \
      -o ${confmat_path}
   confmat[${cxt}]=$confmat_path
fi





###################################################################
# RMS MOTION
# Relative RMS motion should have been computed during the MPR
# subroutine of the prestats module prior to its use here.
###################################################################
if [[ "${confound_rms[${cxt}]}" == "Y" ]]
   then
   echo "Including relative RMS displacement in confound model."
   ################################################################
   # Add relative RMS to the confound matrix.
   ################################################################
   ${XCPEDIR}/utils/mbind.R \
      -x ${confmat[${cxt}]} \
      -y ${relrms[${subjidx}]} \
      -o ${confmat_path}
   confmat[${cxt}]=$confmat_path
fi





###################################################################
# Next, determine whether the user has specified any tissue-
# specific nuisance timecourses. If so, those timecourses must
# be computed as the mean BOLD timeseries over all voxels
# comprising the tissue class of interest.
#
# GREY MATTER
# First, determine whether to include the mean grey matter
# timeseries in the confound model. If the grey matter mask is to
# be included, then it must be conformed to user specifications:
#  * Extract the GM mask from the user-specified segmentation
#  * Erode the GM mask according to user specifications
#  * Move the GM mask into the same space as the primary BOLD
#    timeseries.
###################################################################
if [[ "${confound_gm[${cxt}]}" == "Y" ]] \
   || [[ ${confound_gm[${cxt}]} =~ ${POSINT} ]] \
   || [[ ${confound_gm[${cxt}]} =~ ${POSNUM} ]]
   then
   echo "Including mean grey matter signal in confound model."
   gmMask=${outbase}_gm
   ################################################################
   # Generate a binary mask if necessary.
   # This mask will be based on a user-specified input value
   # and a user-specified image in the subject's structural space.
   ################################################################
   if [[ $(imtest "$gmMask") != "1" ]] \
      || [[ "${confound_rerun[${cxt}]}" != "N" ]]
      then
      rm -f ${gmMask}${ext}
      ${XCPEDIR}/utils/val2mask.R \
         -i ${confound_gm_path[${cxt}]} \
         -v ${confound_gm_val[${cxt}]} \
         -o ${gmMask}${ext}
   fi
   ################################################################
   # Erode the mask iteratively using the erodespare utility.
   #  * erodespare ensures that the result of applying the
   #    specified erosion is non-empty; if an empty result is
   #    obtained, the degree of erosion is decremented until the
   #    result is non-empty.
   ################################################################
   if [[ ${confound_gm_ero[${cxt}]} -gt 0 ]]
      then
      [[ ${trace} == 1 ]] && traceprop="-t"
      ${XCPEDIR}/utils/erodespare \
         -i ${gmMask}${ext} \
         -o ${gmMask}_ero${ext} \
         -e ${confound_gm_ero[${cxt}]} \
         ${traceprop}
      gmMask=${gmMask}_ero
   fi
   ################################################################
   # Move the mask from subject structural space to subject
   # EPI space. If the BOLD timeseries is already standardised,
   # then instead move it to standard space.
   ################################################################
   if [[ "${space}" == "standard" ]]
      then
      ${ANTSPATH}/antsApplyTransforms \
         -i ${gmMask}${ext} \
         -o ${gmMask}${ext} \
         -r ${template} \
         -n NearestNeighbor \
         ${rigid} \
         ${affine} \
         ${warp} \
         ${resample}
   else
      ${ANTSPATH}/antsApplyTransforms \
         -i ${gmMask}${ext} \
         -o ${gmMask}${ext} \
         -r ${referenceVolumeBrain[${subjidx}]}${ext} \
         -n NearestNeighbor \
         -t ${struct2seq[${subjidx}]}
   fi
   ################################################################
   # Determine whether to extract a mean timecourse or to apply
   # aCompCor to extract PC timecourses.
   ################################################################
   if [[ "${confound_gm[${cxt}]}" == "Y" ]]
      then
      #############################################################
      # Extract the mean timecourse from the eroded and transformed
      # mask.
      #############################################################
      fslmeants -i ${img} -o ${outbase}_phys_gm -m ${gmMask}
      immv ${gmMask} ${gmMask[${cxt}]}
      gm=$(ls -d1 ${outbase}_phys_gm)
      ${XCPEDIR}/utils/mbind.R \
         -x ${confmat[${cxt}]} \
         -y ${gm} \
         -o ${confmat_path}
      confmat[${cxt}]=$confmat_path
   elif  [[ $(echo "${confound_gm[${cxt}]} > 1"|bc) == 1 ]]
      then
      #############################################################
      # Use aCompCor to extract PC timecourses from the mask:
      # Fixed number of PCs.
      #############################################################
      3dpc \
         -prefix ${outbase}_phys_gm \
         -pcsave ${confound_gm[${cxt}]} \
         -mask ${gmMask}${ext} \
         ${img}${ext}
      gm=$(ls -d1 ${outbase}_phys_gm.1D)
   elif  [[ $(echo "${confound_gm[${cxt}]} == 1"|bc) == 1 ]]
      #############################################################
      # Use aCompCor to extract PC timecourses from the mask:
      # All principal components.
      # Please don't do this?
      #############################################################
      then
      3dpc \
         -prefix ${outbase}_phys_gm \
         -pcsave ${vidx} \
         -mask ${gmMask}${ext} \
         ${img}${ext}
      gm=$(ls -d1 ${outbase}_phys_gm.1D)
   elif  [[ $(echo "${confound_gm[${cxt}]} > 0"|bc) == 1 ]]
      #############################################################
      # Use aCompCor to extract PC timecourses from the mask:
      # Cumulative variance explained.
      #############################################################
      then
      3dpc \
         -prefix ${outbase}_phys_gm \
         -mask ${gmMask}${ext} \
         ${img}${ext}
      varExp=$(tail -n+2 ${outbase}_phys_gm_eig.1D|awk '{print $4}')
      vidx=1
      for v in $varExp
         do
         chk=$(echo "$v > ${confound_gm[${cxt}]}"|bc)
         [[ $chk == 1 ]] && break
         vidx=$(echo $vidx + 1|bc)
      done
      echo "Retaining ${vidx} component timeseries."
      3dpc \
         -prefix ${outbase}_phys_gm \
         -pcsave ${vidx} \
         -mask ${gmMask}${ext} \
         ${img}${ext}
      gm=$(ls -d1 ${outbase}_phys_gm.1D)
   fi
fi

###################################################################
# WHITE MATTER
# First, determine whether to include the mean white matter
# timeseries in the confound model. If the white matter mask is to
# be included, then it must be conformed to user specifications:
#  * Extract the WM mask from the user-specified segmentation
#  * Erode the WM mask according to user specifications
#  * Move the WM mask into the same space as the primary BOLD
#    timeseries.
###################################################################
if [[ "${confound_wm[${cxt}]}" == "Y" ]] \
   || [[ ${confound_wm[${cxt}]} =~ ${POSINT} ]] \
   || [[ ${confound_wm[${cxt}]} =~ ${POSNUM} ]]
   then
   echo "Including mean white matter signal in confound model."
   wmMask=${outbase}_wm
   ################################################################
   # Generate a binary mask if necessary.
   # This mask will be based on a user-specified input value
   # and a user-specified image in the subject's structural space.
   ################################################################
   if [[ $(imtest "$wmMask") != "1" ]] \
      || [[ "${confound_rerun[${cxt}]}" != "N" ]]
      then
      rm -f ${wmMask}${ext}
      ${XCPEDIR}/utils/val2mask.R \
         -i ${confound_wm_path[${cxt}]} \
         -v ${confound_wm_val[${cxt}]} \
         -o ${wmMask}${ext}
   fi
   ################################################################
   # Erode the mask iteratively using the erodespare utility.
   #  * erodespare ensures that the result of applying the
   #    specified erosion is non-empty; if an empty result is
   #    obtained, the degree of erosion is decremented until the
   #    result is non-empty.
   ################################################################
   if [[ ${confound_wm_ero[${cxt}]} -gt 0 ]]
      then
      [[ ${trace} == 1 ]] && traceprop="-t"
      ${XCPEDIR}/utils/erodespare \
         -i ${wmMask}${ext} \
         -o ${wmMask}_ero${ext} \
         -e ${confound_wm_ero[${cxt}]} \
         ${traceprop}
      wmMask=${wmMask}_ero
   fi
   ################################################################
   # Move the mask from subject structural space to subject
   # EPI space. If the BOLD timeseries is already standardised,
   # then instead move it to standard space.
   ################################################################
   if [[ "${space}" == "standard" ]]
      then
      ${ANTSPATH}/antsApplyTransforms \
         -i ${wmMask}${ext} \
         -o ${wmMask}${ext} \
         -r ${template} \
         -n NearestNeighbor \
         ${rigid} \
         ${affine} \
         ${warp} \
         ${resample}
   else
      ${ANTSPATH}/antsApplyTransforms \
         -i ${wmMask}${ext} \
         -o ${wmMask}${ext} \
         -r ${referenceVolumeBrain[${subjidx}]}${ext} \
         -n NearestNeighbor \
         -t ${struct2seq[${subjidx}]}
   fi
   ################################################################
   # Determine whether to extract a mean timecourse or to apply
   # aCompCor to extract PC timecourses.
   ################################################################
   if [[ "${confound_wm[${cxt}]}" == "Y" ]]
      then
      #############################################################
      # Extract the mean timecourse from the eroded and transformed
      # mask.
      #############################################################
      fslmeants -i ${img} -o ${outbase}_phys_wm -m ${wmMask}
      immv ${wmMask} ${wmMask[${cxt}]}
      wm=$(ls -d1 ${outbase}_phys_wm)
      ${XCPEDIR}/utils/mbind.R \
         -x ${confmat[${cxt}]} \
         -y ${wm} \
         -o ${confmat_path}
      confmat[${cxt}]=$confmat_path
   elif  [[ $(echo "${confound_wm[${cxt}]} > 1"|bc) == 1 ]]
      then
      #############################################################
      # Use aCompCor to extract PC timecourses from the mask:
      # Fixed number of PCs.
      #############################################################
      3dpc \
         -prefix ${outbase}_phys_wm \
         -pcsave ${confound_wm[${cxt}]} \
         -mask ${wmMask}${ext} \
         ${img}${ext}
      wm=$(ls -d1 ${outbase}_phys_wm.1D)
   elif  [[ $(echo "${confound_wm[${cxt}]} == 1"|bc) == 1 ]]
      #############################################################
      # Use aCompCor to extract PC timecourses from the mask:
      # All principal components.
      # Please don't do this?
      #############################################################
      then
      3dpc \
         -prefix ${outbase}_phys_wm \
         -pcsave ${vidx} \
         -mask ${wmMask}${ext} \
         ${img}${ext}
      wm=$(ls -d1 ${outbase}_phys_wm.1D)
   elif  [[ $(echo "${confound_wm[${cxt}]} > 0"|bc) == 1 ]]
      #############################################################
      # Use aCompCor to extract PC timecourses from the mask:
      # Cumulative variance explained.
      #############################################################
      then
      3dpc \
         -prefix ${outbase}_phys_wm \
         -mask ${wmMask}${ext} \
         ${img}${ext}
      varExp=$(tail -n+2 ${outbase}_phys_wm_eig.1D|awk '{print $4}')
      vidx=1
      for v in $varExp
         do
         chk=$(echo "$v > ${confound_wm[${cxt}]}"|bc)
         [[ $chk == 1 ]] && break
         vidx=$(echo $vidx + 1|bc)
      done
      echo "Retaining ${vidx} component timeseries."
      3dpc \
         -prefix ${outbase}_phys_wm \
         -pcsave ${vidx} \
         -mask ${wmMask}${ext} \
         ${img}${ext}
      wm=$(ls -d1 ${outbase}_phys_wm.1D)
   fi
fi


###################################################################
# CEREBROSPINAL FLUID
# First, determine whether to include the mean white matter
# timeseries in the confound model. If the white matter mask is to
# be included, then it must be conformed to user specifications:
#  * Extract the CSF mask from the user-specified segmentation
#  * Erode the CSF mask according to user specifications
#  * Move the CSF mask into the same space as the primary BOLD
#    timeseries.
###################################################################
if [[ "${confound_csf[${cxt}]}" == "Y" ]] \
   || [[ ${confound_csf[${cxt}]} =~ ${POSINT} ]] \
   || [[ ${confound_csf[${cxt}]} =~ ${POSNUM} ]]
   then
   echo "Including cerebrospinal fluid signal in confound model."
   csfMask=${outbase}_csf
   ################################################################
   # Generate a binary mask if necessary.
   # This mask will be based on a user-specified input value
   # and a user-specified image in the subject's structural space.
   ################################################################
   if [[ $(imtest "$csfMask") != "1" ]] \
      || [[ "${confound_rerun[${cxt}]}" != "N" ]]
      then
      rm -f ${csfMask}${ext}
      ${XCPEDIR}/utils/val2mask.R \
         -i ${confound_csf_path[${cxt}]} \
         -v ${confound_csf_val[${cxt}]} \
         -o ${csfMask}${ext}
   fi
   ################################################################
   # Erode the mask iteratively using the erodespare utility.
   #  * erodespare ensures that the result of applying the
   #    specified erosion is non-empty; if an empty result is
   #    obtained, the degree of erosion is decremented until the
   #    result is non-empty.
   ################################################################
   if [[ ${confound_csf_ero[${cxt}]} -gt 0 ]]
      then
      [[ ${trace} == 1 ]] && traceprop="-t"
      ${XCPEDIR}/utils/erodespare \
         -i ${csfMask}${ext} \
         -o ${csfMask}_ero${ext} \
         -e ${confound_csf_ero[${cxt}]} \
         ${traceprop}
      csfMask=${csfMask}_ero
   fi
   ################################################################
   # Move the mask from subject structural space to subject
   # EPI space. If the BOLD timeseries is already standardised,
   # then instead move it to standard space.
   ################################################################
   if [[ "${space}" == "standard" ]]
      then
      ${ANTSPATH}/antsApplyTransforms \
         -i ${csfMask}${ext} \
         -o ${csfMask}${ext} \
         -r ${template} \
         -n NearestNeighbor \
         ${rigid} \
         ${affine} \
         ${warp} \
         ${resample}
   else
      ${ANTSPATH}/antsApplyTransforms \
         -i ${csfMask}${ext} \
         -o ${csfMask}${ext} \
         -r ${referenceVolumeBrain[${subjidx}]}${ext} \
         -n NearestNeighbor \
         -t ${struct2seq[${subjidx}]}
   fi
   ################################################################
   # Determine whether to extract a mean timecourse or to apply
   # aCompCor to extract PC timecourses.
   ################################################################
   if [[ "${confound_csf[${cxt}]}" == "Y" ]]
      then
      #############################################################
      # Extract the mean timecourse from the eroded and transformed
      # mask.
      #############################################################
      fslmeants -i ${img} -o ${outbase}_phys_csf -m ${csfMask}
      immv ${csfMask} ${csfMask[${cxt}]}
      csf=$(ls -d1 ${outbase}_phys_csf)
      ${XCPEDIR}/utils/mbind.R \
         -x ${confmat[${cxt}]} \
         -y ${csf} \
         -o ${confmat_path}
      confmat[${cxt}]=$confmat_path
   elif  [[ $(echo "${confound_csf[${cxt}]} > 1"|bc) == 1 ]]
      then
      #############################################################
      # Use aCompCor to extract PC timecourses from the mask:
      # Fixed number of PCs.
      #############################################################
      3dpc \
         -prefix ${outbase}_phys_csf \
         -pcsave ${confound_csf[${cxt}]} \
         -mask ${csfMask}${ext} \
         ${img}${ext}
      csf=$(ls -d1 ${outbase}_phys_csf.1D)
   elif  [[ $(echo "${confound_csf[${cxt}]} == 1"|bc) == 1 ]]
      #############################################################
      # Use aCompCor to extract PC timecourses from the mask:
      # All principal components.
      # Please don't do this?
      #############################################################
      then
      3dpc \
         -prefix ${outbase}_phys_csf \
         -pcsave ${vidx} \
         -mask ${csfMask}${ext} \
         ${img}${ext}
      csf=$(ls -d1 ${outbase}_phys_csf.1D)
   elif  [[ $(echo "${confound_csf[${cxt}]} > 0"|bc) == 1 ]]
      #############################################################
      # Use aCompCor to extract PC timecourses from the mask:
      # Cumulative variance explained.
      #############################################################
      then
      3dpc \
         -prefix ${outbase}_phys_csf \
         -mask ${csfMask}${ext} \
         ${img}${ext}
      varExp=$(tail -n+2 ${outbase}_phys_csf_eig.1D|awk '{print $4}')
      vidx=1
      for v in $varExp
         do
         chk=$(echo "$v > ${confound_csf[${cxt}]}"|bc)
         [[ $chk == 1 ]] && break
         vidx=$(echo $vidx + 1|bc)
      done
      echo "Retaining ${vidx} component timeseries."
      3dpc \
         -prefix ${outbase}_phys_csf \
         -pcsave ${vidx} \
         -mask ${csfMask}${ext} \
         ${img}${ext}
      csf=$(ls -d1 ${outbase}_phys_csf.1D)
   fi
fi





###################################################################
# MEAN GLOBAL SIGNAL
###################################################################
if [[ "${confound_gsr[${cxt}]}" == "Y" ]]
   then
   echo "Including mean global signal in confound model."
   ################################################################
   # Determine whether a brain mask exists for the current subject.
   #  * If one does, use it as the basis for computing the mean
   #    global timeseries.
   #  * If no mask exists, generate one using AFNI's 3dAutomask
   #    utility. This may yield unexpected results if data has
   #    been demeaned or standard-scored.
   ################################################################
   if [[ $(imtest "${mask[${subjidx}]}") == "1" ]]
      then
      maskpath=${mask[${subjidx}]}${ext}
   else
      echo "Unable to locate mask."
      echo "Generating a mask using 3dAutomask"
      3dAutomask \
         -prefix ${outbase}_mask${ext} \
         -dilate 3 \
         -q \
         ${referenceVolume[${subjidx}]}
      maskpath=${outbase}_mask${ext}
   fi
   ################################################################
   # Extract the mean timecourse from the global (whole-brain)
   # mask, and catenate it into the confound matrix.
   ################################################################
   fslmaths ${maskpath} -thr 0.5 -bin $maskpath
   fslmeants -i ${img} -o ${outbase}_phys_gsr -m ${maskpath}
   gsr=$(ls -d1 ${outbase}_phys_gsr)
   ${XCPEDIR}/utils/mbind.R \
      -x ${confmat[${cxt}]} \
      -y ${gsr} \
      -o ${confmat_path}
   confmat[${cxt}]=$confmat_path
fi





###################################################################
# PRIOR TIME POINTS
# Prior time points are computed by passing the OPprev command to
# the mbind utility.
#
# Note the order in which supplementary timeseries are added to
# the confound matrix:
#   1. prior time points
#   2. temporal derivatives
#   3. powers
# So, be advised that adding temporal derivatives will also add
# temporal derivatives of previous time points, and adding powers
# will also add powers of derivatives (and powers of derivatives
# of previous time points)!
###################################################################
if [[ "${confound_past[${cxt}]}" -gt "0" ]]
   then
   echo "Including ${confound_past[${cxt}]} prior time point(s)"
   echo "  in confound model."
   ${XCPEDIR}/utils/mbind.R \
      -x ${confmat[${cxt}]} \
      -y OPprev${confound_past[${cxt}]} \
      -o ${confmat_path}
   confmat[${cxt}]=$confmat_path
fi





###################################################################
# TEMPORAL DERIVATIVES
# Temporal derivatives are computed by passing the OPdx command to
# the mbind utility.
#
# Note the order in which supplementary timeseries are added to
# the confound matrix:
#   1. prior time points
#   2. temporal derivatives
#   3. powers
# So, be advised that adding temporal derivatives will also add
# temporal derivatives of previous time points, and adding powers
# will also add powers of derivatives (and powers of derivatives
# of previous time points)!
###################################################################
if [[ "${confound_dx[${cxt}]}" -gt "0" ]]
   then
   echo "Including ${confound_dx[${cxt}]} derivative(s)"
   echo "  in confound model."
   ${XCPEDIR}/utils/mbind.R \
      -x ${confmat[${cxt}]} \
      -y OPdx${confound_dx[${cxt}]} \
      -o ${confmat_path}
   confmat[${cxt}]=$confmat_path
fi





###################################################################
# POWERS
# Powers of observations are computed by passing the OPpower
# command to the mbind utility.
#
# Note the order in which supplementary timeseries are added to
# the confound matrix:
#   1. prior time points
#   2. temporal derivatives
#   3. powers
# So, be advised that adding temporal derivatives will also add
# temporal derivatives of previous time points, and adding powers
# will also add powers of derivatives (and powers of derivatives
# of previous time points)!
###################################################################
if [[ "${confound_sq[${cxt}]}" -gt "1" ]]
   then
   echo "Including ${confound_sq[${cxt}]} power(s)"
   echo "  in confound model."
   ${XCPEDIR}/utils/mbind.R \
      -x ${confmat[${cxt}]} \
      -y OPpower${confound_sq[${cxt}]} \
      -o ${confmat_path}
   confmat[${cxt}]=$confmat_path
fi





###################################################################
# COMPONENT CORRECTION (COMPCOR)
###################################################################
if [[ "${confound_cc[${cxt}]}" -gt "0" ]]
   then
   echo "Including ${confound_cc[${cxt}]} CompCor signal(s)"
   echo "  in confound model."
   ################################################################
   # Determine whether a brain mask exists for the current subject.
   #  * If one does, use it as the basis for computing nuisance
   #    components.
   #  * If no mask exists, generate one using AFNI's 3dAutomask
   #    utility. This may yield unexpected results if data has
   #    been demeaned or standard-scored.
   ################################################################
   if [ $(imtest "${mask[${subjidx}]}") == "1" ]
      then
      maskpath=${mask[${subjidx}]}${ext}
   elif [[ $(imtest "${maskpath}") != "1" ]]
      then
      echo "Unable to locate mask."
      echo "Generating a mask using 3dAutomask"
      3dAutomask \
         -prefix ${outbase}_mask${ext} \
         -dilate 3 \
         -q \
         ${referenceVolume[${subjidx}]}
      maskpath=${outbase}_mask${ext}
   fi
   ################################################################
   # Perform CompCor using the ANTs ImageMath utility.
   ################################################################
   ImageMath 4 ${outbase}_confound${ext} \
      CompCorrAuto ${img}${ext} \
      ${maskpath} \
      ${confound_cc[${cxt}]}
   ################################################################
   # ImageMath automatically includes global signal along with
   # CompCor; XCP Engine, by contrast, does not assume that a user
   # who includes CompCor necessarily also wishes to include the
   # global signal.
   #
   # Here, the confound module trims away the header from the ANTs
   # output and removes the first column, which corresponds to
   # global signal.
   #
   # ANTs outputs a .csv of component timeseries, while mbind
   # reads tab- or space-delimited files, so an appropriate
   # substitution is made here to ensure compatibility.
   ################################################################
   tail -n +2 ${outbase}_confound_compcorr.csv| \
      cut -d"," -f1 --complement| \
      sed 's@,@\t@g' > ${outbase}_compcor
   cc=$(ls -d1 ${outbase}_compcor)
   ################################################################
   # Add the component timeseries to the confound matrix.
   ################################################################
   ${XCPEDIR}/utils/mbind.R \
      -x ${confmat[${cxt}]} \
      -y ${cc} \
      -o ${confmat_path}
   confmat[${cxt}]=$confmat_path
fi





###################################################################
# If aCompCor has been selected, bind the PC timeseries into the
# main confound matrix here so as not to add derivatives and
# power terms.
# TODO
# The limited customisability here will need to be
# addressed in the near future.
###################################################################
if [[ ${confound_gm[${cxt}]} =~ ${POSNUM} ]]
   then
   echo "Including ${confound_gm[${cxt}]} GM aCompCor signal(s)"
   echo "  in confound model."
   ${XCPEDIR}/utils/mbind.R \
      -x ${confmat[${cxt}]} \
      -y ${gm} \
      -o ${confmat_path}
   confmat[${cxt}]=$confmat_path
fi
if [[ ${confound_wm[${cxt}]} =~ ${POSNUM} ]]
   then
   echo "Including ${confound_wm[${cxt}]} WM aCompCor signal(s)"
   echo "  in confound model."
   ${XCPEDIR}/utils/mbind.R \
      -x ${confmat[${cxt}]} \
      -y ${wm} \
      -o ${confmat_path}
   confmat[${cxt}]=$confmat_path
fi
if [[ ${confound_csf[${cxt}]} =~ ${POSNUM} ]]
   then
   echo "Including ${confound_csf[${cxt}]} CSF aCompCor signal(s)"
   echo "  in confound model."
   ${XCPEDIR}/utils/mbind.R \
      -x ${confmat[${cxt}]} \
      -y ${csf} \
      -o ${confmat_path}
   confmat[${cxt}]=$confmat_path
fi




###################################################################
# CUSTOM TIMESERIES
# * If none are specified, skip over this section.
# * These may include convolved or unconvolved stick/delta
#   functions encoding stimulus onset, duration, and magnitude.
# * These may be obtained directly from FSL's utilities as a
#   design matrix. If they are, only the timeseries (and not 
#   supplementary information such as peak magnitudes and total
#   duration) should be bound into the confound matrix.
# * Note that this is the very last step of confound matrix
#   assembly. Thus, any temporal derivatives, powers, previous
#   time points of custom timeseries should be included as custom
#   timeseries.
###################################################################
confound_custom[${cxt}]=$(echo ${confound_custom[${cxt}]}|sed s@'#'@' '@g)
nvol=$(fslnvols ${img})
for cts in ${confound_custom[${cxt}]}
   do
   echo "Including custom timeseries in confound model:"
   echo "  ${cts}"
   ################################################################
   # Determine whether the input is a three-column stick function
   # or an explicit timeseries. If it is a stick function, then
   # apply a convolution and convert it to a design matrix.
   ################################################################
   stick=0
   [[ $(cat ${cts}|wc -l) -lt ${nvol} ]] && stick=1
   if [[ ${stick} == 1 ]]
      then
      ${XCPEDIR}/utils/stick2lm.R \
         -i ${img} \
         -s ${cts} \
         -d FALSE \
         >> ${outbase}convts
      cts=${outbase}convts
   fi
   ################################################################
   # Identify the row in which the timeseries matrix proper
   # begins if the input is an FSL-style design matrix.
   ################################################################
   startln=$(grep -i '/Matrix' ${cts})
   [[ -z ${startln} ]] && startln=0
   startln=$(expr ${startln} + 1)
   cts=$(tail -n +${startln} ${cts})
   rm -f ${outbase}convts
   echo "${cts}" >> ${outbase}convts
   cts=${outbase}convts
   ${XCPEDIR}/utils/mbind.R \
      -x ${confmat[${cxt}]} \
      -y ${outbase}convts \
      -o ${confmat_path}
   confmat[${cxt}]=$confmat_path
   rm -f ${outbase}convts
done
echo "Processing step complete: generating confound matrix"





###################################################################
# Verify that the confound matrix produced by the confound module
# contains the expected number of time series.
###################################################################
obs=$(head -n1 ${confmat_path}|wc -w)
exp=0
[[ ${confound_rp[${cxt}]} == Y ]] && exp=$(echo ${exp} + 6|bc)
[[ ${confound_rms[${cxt}]} == Y ]] && exp=$(echo ${exp} + 1|bc)
[[ ${confound_gm[${cxt}]} == Y ]] && exp=$(echo ${exp} + 1|bc)
[[ ${confound_wm[${cxt}]} == Y ]] && exp=$(echo ${exp} + 1|bc)
[[ ${confound_csf[${cxt}]} == Y ]] && exp=$(echo ${exp} + 1|bc)
[[ ${confound_gsr[${cxt}]} == Y ]] && exp=$(echo ${exp} + 1|bc)
exp=$(echo ${exp} + ${confound_cc[${cxt}]}|bc)
past=$(echo ${confound_past[${cxt}]} + 1|bc)
dx=$(echo ${confound_dx[${cxt}]} + 1|bc)
exp=$(echo ${exp} \* ${past} \* ${dx} \* ${confound_sq[${cxt}]}|bc)
for cts in ${confound_custom[${cxt}]}
   do
   ctsn=$(tail -n1 ${cts}|wc -w)
   exp=$(echo ${exp} + ${ctsn}|bc)
done
[[ ${obs} == ${exp} ]] \
   && completion=match1 \
   || echo "Dimensions of the existing confound matrix are incorrect"





###################################################################
# write remaining output paths to local design file so that
# they may be used further along the pipeline
###################################################################
echo ""; echo ""; echo ""
echo "Writing outputs..."
echo "confmat[${subjidx}]=$confmat_path" >> $design_local





###################################################################
# CLEANUP
#  * Remove any temporary files if cleanup is enabled.
#  * Update the audit file.
###################################################################
if [[ "${confound_cleanup[${cxt}]}" == "Y" ]] \
   && [[ ${completion} == match1 ]]
   then
   echo ""; echo ""; echo ""
   echo "Cleaning up..."
   rm -rf ${outdir}/*~TEMP~*
elif [[ ${completion} != match1 ]]
   then
   echo "Expected output not present."
   echo "Check the log to verify that processing"
   echo "completed as intended."
   exit 1
fi
prefields=$(echo $(grep -o "_" <<< $prefix|wc -l) + 1|bc)
modaudit=$(expr ${prefields} + ${cxt} + 1)
subjaudit=$(grep -i $(echo ${prefix}|sed s@'_'@','@g) ${audit})
replacement=$(echo ${subjaudit}\
   |sed s@[^,]*@@${modaudit}\
   |sed s@',,'@',1,'@ \
   |sed s@',$'@',1'@g)
sed -i s@${subjaudit}@${replacement}@g ${audit}

echo "Module complete"
