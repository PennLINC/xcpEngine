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
echo "#  ☭         EXECUTING ROI-WISE QUANTIFICATION MODULE          ☭  #"
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
if [[ ! -e ${roiquant_roi[${cxt}]} ]]
   then
   echo "::XCP-WARNING: ROI-wise analysis has been requested, "
   echo "  but no ROIs have been specified in the roiquant module. "
   echo "  Now searching other modules for ROIs..."
fi
###################################################################
# Create a directory for intermediate outputs.
###################################################################
[[ ${NUMOUT} == 1 ]] && prep=${cxt}_
outdir=${out}/${prep}roiquant
[[ ! -e ${outdir} ]] && mkdir -p ${outdir}
[[ ! -e ${out}/${prefix}_roi ]] && mkdir -p ${out}/${prefix}_roi
echo "Output directory is $outdir"
###################################################################
# Define paths to all potential outputs.

# For the RoI-wise quantification module, there may exist an
# unlimited number of potential outputs, depending on the number
# of parcellations provided by the user:
#  * qbase : Base name for all outputs of the ROI-wise
#    quantification; the name of each parcellation will be
#    appended to this base name
###################################################################
qbase=${outdir}/${prefix}_
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
ln -s ${referenceVolume[${subjidx}]}${ext} \
   ${outdir}/${prefix}_referenceVolume${ext}
[[ $(imtest ${out}/${prefix}_roi/${prefix}_referenceVolume) != 1 ]] \
   && ln -s ${referenceVolume[${subjidx}]}${ext} \
   ${out}/${prefix}_roi/${prefix}_referenceVolume${ext}
###################################################################
# Prime the localised design file so that any outputs from this
# module appear beneath the correct header.
###################################################################
echo "" >> $design_local
echo "# *** outputs from roiquant[${cxt}] *** #" >> $design_local
echo "" >> $design_local
###################################################################
# It is always assumed that this module should re-run.
#
# For RoI-wise quantification of FTI statistics.
###################################################################
###################################################################
# END GENERAL MODULE HEADER
###################################################################
###################################################################





###################################################################
# Iterate through all RoI maps and compute the mean scores for
# each RoI in each map.
###################################################################
###################################################################
# * Determine all RoIs to be run through the module.
# * The below loop is re-used (with several modifications) across
#   RoI-wise analyses, so any module-dependent variables should be
#   reassigned to module-independent names here as well.
# * Retrieve all the parcellations for which analysis should be
#   run.
###################################################################
echo ""; echo ""; echo ""
echo "Current processing step:"
echo "RoI-wise quantification"
rerun=${roiquant_rerun[${cxt}]}
roilist=${roiquant_roi[${cxt}]}
auxImgs=$(grep -i '^#' ${auxImgs[${subjidx}]})
unset mods
pars=$(grep -i '^#' ${roilist})
for deriv in ${auxImgs}
   do
   unset rqtest
   rqtest=$(echo ${deriv}|cut -d'#' -f4)
   if [[ -n ${rqtest} ]]
      then
      voxelwise="${voxelwise} ${deriv}"
      added=$(echo ${mods}|grep ${rqtest})
      if [[ -z ${added} ]]
         then
         mods="${mods} ${rqtest}"
         cMod=$(echo ${rqtest}|cut -d',' -f1)
         cIdx=$(echo ${rqtest}|cut -d',' -f2)
         modrois=${cMod}_roi[${cIdx}]
         [[ -e ${!modrois} ]] \
            && newrois=$(grep -i '^#' ${!modrois})
         pars="${pars} ${newrois}"
      fi
   fi
done
###################################################################
# * Obtain transforms for moving parcellations into the target
#   space.
###################################################################
if [[ ! -z ${seq2struct[${subjidx}]} ]]
   then
   coreg="-t ${seq2struct[${subjidx}]}"
fi
if [[ ! -z ${struct2seq[${subjidx}]} ]]
   then
   icoreg="-t ${struct2seq[${subjidx}]}"
fi
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
# Iterate through all parcellations.
#
# In brief, the RoI-wise analysis process consists of the
# following steps:
#  1. Generate a map of the current parcellation if it does not
#     already exist, and move the map from anatomical space into
#     analytic space.
#  2. Compute the value of the statistic of interest in each RoI
#     of the parcellation.
###################################################################
for par in $pars
   do
   ################################################################
   # Parse the current parcellation's information.
   #  * parName stores the name of the current parcellation.
   #  * parPath stores the path to the current parcellation.
   #  * parSpace stores the space in which the parcellation is
   #    situated.
   #  * Determine whether it is a seed coordinate library or an
   #    image of nodes based on the path extension.
   ################################################################
   parName=$(echo $par|cut -d"#" -f2)
   parPath=$(echo $par|cut -d"#" -f3)
   parSpace=$(echo $par|cut -d"#" -f4)
   parName=$(eval echo ${parName})
   parPath=$(eval echo ${parPath})
   parPath=$(ls -d1 ${parPath} 2>/dev/null)
   [[ ! -e ${parPath} ]] && continue
   printf " * ${parName}::"
   ################################################################
   # Define the paths to the potential outputs of the current
   # RoI-wise analysis.
   ################################################################
   parbase=${out}/${prefix}_roi/${prefix}_
   parValBase=${outdir}/${parName}/${prefix}_${parName}_val_
   [[ ! -d ${outdir}/${parName} ]] && mkdir -p ${outdir}/${parName}
   ################################################################
   # Now determine whether the current parcellation is defined in
   # an image or in a coordinate library.
   ################################################################
   [[ $(imtest ${parPath}) == 1 ]] \
      && parType=image \
      || parType=sclib
   ################################################################
   # [1]
   # Based on the type of parcellation and the space of the
   # primary analyte, decide what is necessary to move the
   # parcellation into the analytic space.
   ################################################################
   printf "map::"
   ################################################################
   # If the parcellation has already been computed in this space,
   # then move on to the next stage.
   ################################################################
   [[ $(imtest ${parbase}${parName}) == 1 ]] && parType=done
   case ${parType} in
   image)
      case ${parSpace}2${space} in
      #############################################################
      # If the map and the image are both in native analyte space,
      # then no transformations need be applied
      #############################################################
      nat2native)
         rm -f ${parbase}${parName}${ext}
         ln -s ${parPath} ${parbase}${parName}${ext}
         ;;
      #############################################################
      # If the map is in native analyte space and the image is in
      # standard space, then all forward transformations must be
      # applied.
      #############################################################
      nat2standard)
         rm -f ${parbase}${parName}${ext}
         ${ANTSPATH}/antsApplyTransforms \
            -e 3 -d 3 \
            -i ${parPath} \
            -o ${parbase}${parName}${ext} \
            -r ${template} \
            $resample \
            $warp \
            $affine \
            $rigid \
            $coreg \
            -n MultiLabel
         ;;
      #############################################################
      # If the map is in native structural space and the image in
      # native space, then only the inverse coregistration must
      # be applied
      #############################################################
      str2native)
         rm -f ${parbase}${parName}${ext}
         ${ANTSPATH}/antsApplyTransforms \
            -e 3 -d 3 \
            -i ${parPath} \
            -o ${parbase}${parName}${ext} \
            -r ${referenceVolume[${subjidx}]}${ext} \
            $icoreg \
            -n MultiLabel
         ;;
      #############################################################
      # If the map is in native structural space and the image in
      # standard space, then all forward ANTsCT transforms (but
      # not the coregistration) must be applied
      #############################################################
      str2standard)
         rm -f ${parbase}${parName}${ext}
         ${ANTSPATH}/antsApplyTransforms \
            -e 3 -d 3 \
            -i ${parPath} \
            -o ${parbase}${parName}${ext} \
            -r ${template} \
            $resample \
            $warp \
            $affine \
            $rigid \
            -n MultiLabel
         ;;
      #############################################################
      # If the map and the image are both in native structural
      # space, then no transformations need be applied
      #############################################################
      str2structural)
         rm -f ${parbase}${parName}${ext}
         ln -s ${parPath} ${parbase}${parName}${ext}
         ;;
      #############################################################
      # If the map is in standard space and the image in native
      # space, then all inverse transforms must be applied
      #############################################################
      std2native)
         rm -f ${parbase}${parName}${ext}
         ${ANTSPATH}/antsApplyTransforms \
            -e 3 -d 3 \
            -i ${parPath} \
            -o ${parbase}${parName}${ext} \
            -r ${referenceVolume[${subjidx}]}${ext} \
            $icoreg \
            $irigid \
            $iaffine \
            $iwarp \
            $iresample \
            -n MultiLabel
         ;;
      #############################################################
      # If the map is in standard space and the image in native
      # structural space, then all inverse ANTsCT transforms (but
      # not the coregistration) must be applied
      #############################################################
      std2structural)
         rm -f ${parbase}${parName}${ext}
         ${ANTSPATH}/antsApplyTransforms \
            -e 3 -d 3 \
            -i ${parPath} \
            -o ${parbase}${parName}${ext} \
            -r ${referenceVolume[${subjidx}]}${ext} \
            $irigid \
            $iaffine \
            $iwarp \
            $iresample \
            -n MultiLabel
         ;;
      #############################################################
      # If the map and image are both in standard space, then
      # no transforms are necessary
      #############################################################
      std2standard)
         rm -f ${parbase}${parName}${ext}
         ln -s ${parPath} ${parbase}${parName}${ext}
         ;;
      esac
      ;;
   sclib)
      ############################################################
      # If the primary analyte is in native space, use ANTs
      # to transform spatial coordinates into native space.
      # This process is much less intuitive than it sounds,
      # largely because of the stringent orientation requirements
      # within ANTs, and it is cleverly tucked away behind a
      # utility script called pointTransform.
      #
      # Also, note that antsApplyTransformsToPoints (and
      # consequently pointTransform) requires the inverse of the
      # transforms that you would intuitively expect it to
      # require.
      ############################################################
      case std2${space} in
      std2native)
         ##########################################################
         # Apply the required transforms.
         ##########################################################
         parPathIn=${parPath}
         parPath=${parbase}${parName}_warped.sclib
         rm -f ${parPath}
         [[ ${trace} == 1 ]] && trace_prop=-x
         ${XCPEDIR}/utils/pointTransform \
            -v \
            -i ${parPathIn} \
            -s ${template} \
            -r ${referenceVolume[${subjidx}]}${ext} \
            $coreg \
            $rigid \
            $affine \
            $warp \
            $resample \
            $trace_prop \
            >> ${parPath}
         ;;
      #############################################################
      # Coordinates are always in standard space, so if the
      # analyte image has already been normalised, then
      # there is no need for any further manipulations.
      #############################################################
      std2standard)
         space=standard
         ;;
      esac
      #############################################################
      # Use the (warped) coordinates and radius to generate a map
      # of the coordinate library.
      #############################################################
      [[ ${trace} == 1 ]] && traceprop="-x"
      ${XCPEDIR}/utils/coor2map \
         ${traceprop} \
         -i ${parPath} \
         -t ${referenceVolumeBrain[${subjidx}]} \
         -o ${parbase}${parName}
      ;;
   done)
      parType=done
      ;;
   esac
   ################################################################
   # Update the path to the parcellation map so that it indicates
   # a parcellation in the same space as the primary analyte.
   # Symlink the map into the ROI-quant output directory.
   ################################################################
   parPath=${parbase}${parName}${ext}
   
   
   
   
   
   ################################################################
   # [2]
   # Compute the value of the statistic of interest for each
   # RoI in the parcellation.
   ################################################################
   pfxtab=$(echo ${prefix}|sed s@'_'@'\t'@g)
   intensityRange=$(fslstats ${parPath} -R\
      |cut -d' ' -f2\
      |cut -d'.' -f1)
   for map in ${voxelwise}
      do
      unset mapStats
      mapName=$(echo ${map}|cut -d'#' -f2)
      mapPath=$(echo ${map}|cut -d'#' -f3)
      mapMod=$(echo ${map}|cut -d'#' -f4|cut -d',' -f1)
      mapModIdx=$(echo ${map}|cut -d'#' -f4|cut -d',' -f2)
      mapStats=$(echo ${map}|cut -d'#' -f4|cut -d',' -f3-)
      if [[ ${NUMOUT} == 0 ]]
         then
         modout=${out}/${mapMod}
      else
         modout=${out}/${mapModIdx}_${mapMod}
      fi
      #############################################################
      # Determine whether the quantification should be done for
      # this voxelwise map for this parcellation.
      # * If the parcellation is in the roiquant library, quantify
      #   all voxelwise maps.
      # * Otherwise, test for the parcellation in the library for
      #   the voxelwise map's module.
      # * If the parcellation is in neither library, then skip
      #   quantification for that voxelwise map.
      #############################################################
      unset rqtest
      unset mqtest
      rqtest=$(grep -i '^#'${parName} ${roiquant_roi[${cxt}]})
      if [[ -z ${rqtest} ]]
         then
         modrois=${mapMod}_roi[${mapModIdx}]
         mqtest=$(grep -i '^#'${parName} ${!modrois})
         if [[ -z ${mqtest} ]]
            then
            continue
         fi
      fi
      #############################################################
      # Perform the quantification.
      #############################################################
      mapStats=$(echo ${mapStats}|sed s@','@' '@g)
      [[ -z ${mapStats} ]] && mapStats=mean
      for mapStat in ${mapStats}
         do
         ##########################################################
         # Determine the statistic to be computed within each
         # region of interest.
         ##########################################################
         case ${mapStat} in
         ##########################################################
         # Kendall's W (regional homogeneity/ReHo) computed
         # ROI-wise.
         ##########################################################
         kw)
            statName=kw_
            [[ ${roiquant_rerun[${cxt}]} == Y ]] \
               && rm -f ${modout}/roi/${parName}/${prefix}_${parName}_val_${statName}${mapName}.1D
            [[ -e ${modout}/roi/${parName}/${prefix}_${parName}_val_${statName}${mapName}.1D ]] && continue
            rm -f ${parValBase}${statName}${mapName}.1D
            vs=$(${XCPEDIR}/utils/unique.R -i ${parPath})
            for v in $vs
               do
               printf "KendallW${v}\t" \
                  >> ${parValBase}${statName}${mapName}.1D
            done
            echo "" >> ${parValBase}${statName}${mapName}.1D
            3dReHo \
               -prefix ${outbase}${ext} \
               -inset ${out}/${prefix}${ext} \
               -in_rois ${parPath} \
               2>/dev/null
            [[ ! -e ${outbase}${ext}_ROI_reho.vals ]] \
               && echo "   ::ERROR: The provided ROI map may contain regions " \
               && echo "       with too few voxels for ReHo computation." \
               && continue
            rm -f ${outbase}${ext}
            cat ${outbase}${ext}_ROI_reho.vals \
               >> ${parValBase}${statName}${mapName}.1D
            ;;
         ##########################################################
         # Compute the volume of each ROI.
         ##########################################################
         vol)
            unset rs
            unset vols
            statname=vol_
            ROIf=$(fslstats ${parPath} -R|awk '{print $2}')
            numROI=$(echo "${ROIf} + 1"|bc)
            voxCt=$(fslstats ${parPath} -H ${numROI} 0 ${ROIf})
            #######################################################
            # Compute a conversion factor between voxel count
            # and volume, and reorganise the output information.
            #######################################################
            cf=$(echo "scale=100; \
               $(fslval ${parPath} pixdim1) \
               * $(fslval ${parPath} pixdim2) \
               * $(fslval ${parPath} pixdim3)"\
               |bc)
            for r in $(seq $ROIi $ROIf)
               do
               rs="${rs}\tVol${r}"
               cvol=$(echo "$voxCt"|sed ${i}'q;d')
               cvol=$(echo "scale=100; ${cvol} * ${cf}"|bc)
               vs="${vs}\t${cvol}"
            done
            printf "${rs}" >> ${parValBase}${mapName}.1D
            echo "" >> ${parValBase}${mapName}.1D
            printf "${vs}" >> ${parValBase}${mapName}.1D
            ;;
         ##########################################################
         # Compute the mean value within each ROI.
         ##########################################################
         *)
            unset statName
            [[ ${roiquant_rerun[${cxt}]} == Y ]] \
               && rm -f ${modout}/roi/${parName}/${prefix}_${parName}_val_${statName}${mapName}.1D
            [[ -e ${modout}/roi/${parName}/${prefix}_${parName}_val_${statName}${mapName}.1D ]] && continue
            rm -f ${parValBase}${statName}${mapName}.1D
            #######################################################
            # Determine whether each node is sufficiently covered.
            # If over 50 percent is not covered, remove it from
            # computation.
            #######################################################
            cover=$(${XCPEDIR}/utils/coverage.R \
               -i ${mapPath}${ext}\
               -r ${parPath} \
               2>/dev/null)
            statval=$(3dROIstats \
               -1DRformat \
               -mask ${parPath} \
               -nzmean \
               -nomeanout \
               -numROI ${intensityRange} \
               -zerofill NA \
               ${mapPath}${ext}\
               2>/dev/null)
            statname=$(echo "${statval}"|head -n1)
            statval=$(echo "${statval}"|tail -n1)
            cover=(1 $cover)
            echo "${statname}" >> ${parValBase}${mapName}.1D
            j=0
            for sval in ${statval}
               do
               if [[ $(echo ${cover[${j}]} '< 0.5'|bc 2>/dev/null) == 1 ]]
                  then
                  printf "NA\t" >> ${parValBase}${mapName}.1D
               else
                  printf "%s\t" ${sval} >> ${parValBase}${mapName}.1D
               fi
               j=$(expr ${j} + 1)
            done
            ;;
         esac
         ##########################################################
         # Revise the file header to include the subject
         # identifier.
         ##########################################################
         unset idVars
         for val in ${pfxtab}
            do
            varname=$(grep -i ']='${val}'$' ${design_local}|cut -d'=' -f1)
            idVars="${idVars},${varname}"
         done
         idVars=$(echo ${idVars}|sed s@'^,'@@|sed s@','@'\t'@g)
         parVals=$(cat ${parValBase}${statName}${mapName}.1D \
            |sed s@'^name'@"${idVars}"@g \
            |sed s@'^/[^\t]*'@"${pfxtab}"@g)
         rm -f ${parValBase}${statName}${mapName}.1D
         echo "${parVals}" >> ${parValBase}${statName}${mapName}.1D
         ##########################################################
         # Symlink into the voxelwise map's module output
         # directory.
         ##########################################################
         [[ ! -e ${modout}/roi/${parName} ]] && mkdir -p ${modout}/roi/${parName}
         rm -f ${modout}/roi/s${parName}/${prefix}_${parName}_val_${statName}${mapName}.1D \
            ${modout}/roi/${parName}/${prefix}_${parName}${ext} \
            ${outdir}/${parName}/${prefix}_${parName}${ext}
         [[ ! -e ${modout}/roi/${parName}/${parName}${ext} ]] \
            && ln -s ${parPath} ${modout}/roi/${parName}/${prefix}_${parName}${ext}
         [[ ! -e ${modout}/${prefix}_referenceVolume${ext} ]] \
            && ln -s ${referenceVolume[${subjidx}]}${ext} \
            ${modout}/${prefix}_referenceVolume${ext}
         [[ ! -e ${outdir}/${parName}/${parName}${ext} ]] \
            && ln -s ${parPath} ${outdir}/${parName}/${prefix}_${parName}${ext}
         ln -s ${parValBase}${statName}${mapName}.1D \
            ${modout}/roi/${parName}/${prefix}_${parName}_val_${statName}${mapName}.1D
      done
   done
   
   echo "END"
done
echo "Processing step complete:"
echo "RoI-wise quantification"





###################################################################
# CLEANUP
#  * Remove any temporary files if cleanup is enabled.
#  * Update the audit file to reflect completion of the module.
###################################################################
img=$(readlink -f ${img}${ext})
if [[ "${roiquant_cleanup[${cxt}]}" == "Y" ]]
   then
   rm -rf ${outdir}/*~TEMP~*
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
