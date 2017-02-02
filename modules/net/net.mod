#!/usr/bin/env bash

###################################################################
#  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  #
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
echo "################################################################### "
echo "#  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  #"
echo "#                                                                 #"
echo "#  ☭             EXECUTING NETWORK ANALYSIS MODULE             ☭  #"
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
if [[ ! -e ${net_lib[${cxt}]} ]]
   then
   echo "::XCP-WARNING: Network analysis has been requested, "
   echo "  but no network maps have been provided."
   exit 1
fi
###################################################################
# Create a directory for intermediate outputs.
###################################################################
[[ ${NUMOUT} == 1 ]] && prep=${cxt}_
outdir=${out}/${prep}net
if [[ ${net_name[${cxt}]} != "net" ]] \
   && [[ ${net_name[${cxt}]} != "NULL" ]] \
   && [[ ! -z ${net_name[${cxt}]} ]]
   then
   outdir=${outdir}${net_name[${cxt}]}
fi
[[ ! -e ${outdir} ]] && mkdir -p ${outdir}
[[ ! -e ${out}/${prefix}_roi ]] && mkdir -p ${out}/${prefix}_roi
echo "Output directory is $outdir"
###################################################################
# Define paths to all potential outputs.
#  * nets : If this already exists in the design file, it may have
#    been created either by a previous net module or by infomax
#    with streg. If it already exists, update the pointer to
#    indicate the same file; otherwise, prime a new networks file.
#
# For the network module, there may exist an unlimited number
# of potential outputs, depending on the number of networks
# provided by the user for analysis:
#  * netbase : Base name for all outputs of the network analysis;
#    the name of each network will be appended to the base name
#  * This is defined in the loop body below.
###################################################################
if [[ -n ${nets[${subjidx}]} ]]
   then
   nets[${cxt}]=${nets[${subjidx}]}
else
   nets[${cxt}]=${out}/${prefix}_networks
   rm -f ${nets[${cxt}]}
   netsHdr=$(cat ${XCPEDIR}/settings/networks_out\
      |sed s@'//SUBJECT//'@"${prefix}"@g)
   echo "${netsHdr}" >> ${nets[${cxt}]}
fi
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
echo "# *** outputs from net[${cxt}] *** #" >> $design_local
echo "" >> $design_local
###################################################################
# It is always assumed that this module should re-run.
#
# Each network analysis is checked separately to determine whether
# it should be run.
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
# Retrieve all the networks for which analysis should be run.
###################################################################
nets=$(grep -i '^#' ${net_lib[${cxt}]})
###################################################################
# Iterate through all networks.
#
# In brief, the network analysis process consists of the
# following steps:
#  1. Generate a map of the current network if it does not already
#     exist, and move the map from anatomical space into BOLD
#     space.
#  2. Extract mean timeseries from each node of the network.
#     Output: ${netTs}
#  3. Compute the adjacency matrix from the mean node timeseries.
#     Output: ${netMat}
#  4. Perform consensus-community detection on the adjacency
#     matrix to partition it into subgraphs.
#     Output: ${netCom}
###################################################################
echo ""; echo ""; echo ""
echo "Current processing step:"
echo "Network analysis"
for net in $nets
   do
   ################################################################
   # Parse the current network's information.
   #  * netName stores the name of the current network.
   #  * netPath stores the path to the current network.
   #  * netSpace stores the space in which the network is situated.
   #  * Determine whether it is a seed coordinate library or an
   #    image of nodes based on the path extension.
   ################################################################
   netName=$(echo $net|cut -d"#" -f2)
   netPath=$(echo $net|cut -d"#" -f3)
   netSpace=$(echo $net|cut -d"#" -f4)
   netName=$(eval echo ${netName})
   netPath=$(eval echo ${netPath})
   netPath=$(ls -d1 ${netPath} 2>/dev/null)
   [[ -z ${netPath} ]] && continue
   printf " * ${netName}::"
   ################################################################
   # Define the paths to the potential outputs of the current
   # network analysis.
   ################################################################
   netbase=${outdir}/${netName}/${prefix}_
   mapbase=${out}/${prefix}_roi/${prefix}_
   netTs=${netbase}${netName}_ts.1D
   netMat=${netbase}${netName}_network.txt
   netPajek=${netbase}${netName}.net
   ################################################################
   # First, determine whether the analysis has already been
   # completed for the current network by checking for the
   # community partition (the last output of each analysis).
   #  * If analysis has already completed, then add the network's
   #    processed files to the catalogue of networks and move on
   #    to the next analysis.
   #  * Unless, of course, the user has explicitly requested
   #    full re-analysis.
   ################################################################
   if [[ -e ${netPajek} ]] \
      && [[ ${net_rerun[${cxt}]} == "N" ]]
      then
      echo "[already run]"
      [[ $(imtest ${mapbase}${netName})==1 ]] \
         && netPath=${mapbase}${netName}${ext}
      netInfo="#NM,${netName}#MP,${netPath}#SP,${netSpace}#TS,${netTs}#AM,${netMat}#PJ,${netPajek}"
      gammas=$(echo ${net_gamma[${cxt}]}|sed s@','@' '@g)
      for gamma in ${gammas}
         do
         gammapr=$(echo ${gamma}|sed s@'\.'@','@g)
         netComRt=${netbase}${netName}_gamma${gammapr}
         netCom=${netComRt}_community.1D
         rm -f ${netbase}${netName}_missing.txt
         unset missing
         badnodes=$(grep -nE '^[NaN ]*(1)?[NaN ]*$' ${netMat}\
            |cut -d':' -f1)
         [[ -n ${badnodes} ]] \
            && echo "${badnodes}" >> ${netbase}${netName}_missing.txt \
            && missing=",'missing','${netbase}${netName}_missing.txt'"
         if [[ -z $(cat ${netCom} 2>/dev/null) ]]
            then
            matlab -nodesktop \
               -nosplash \
               -nojvm \
               -r "addpath(genpath('${XCPEDIR}/thirdparty/')); addpath(genpath('${XCPEDIR}/utils/')); glconsensusCL('${netMat}','${netComRt}','gamma',${gamma},'nreps',${net_consensus[${cxt}]}${missing}); exit"\
               2>/dev/null 1>&2
         fi
         netInfo="${netInfo}#${gamma}CM,${netCom}"
      done
      echo ${netInfo} >> ${nets[${cxt}]}
      continue
   fi
   ################################################################
   # Now that it has been determined that analysis needs to be run
   # on the current network, determine whether the current network
   # map is defined in an image or in a coordinate library.
   ################################################################
   [[ $(imtest ${netPath}) == 1 ]] \
      && netType=image \
      || netType=sclib
   ################################################################
   # [1]
   # Based on the type of network map and the space of the primary
   # BOLD timeseries, decide what is necessary to move the map
   # into the BOLD timeseries space.
   ################################################################
   printf "map::"
   ################################################################
   # If the network map has already been computed in this space,
   # then move on to the next stage.
   ################################################################
   [[ $(imtest ${mapbase}${netName}) == 1 ]] && netType=done
   [[ ! -d ${outdir}/${netName} ]] && mkdir -p ${outdir}/${netName}
   case ${netType} in
   image)
      #############################################################
      # Ensure that the network has more than one node. If the
      # network has only one node, there is no point in running
      # this analysis on it.
      #
      # TODO
      # Note that this is deeply flawed as written. It should be
      # modified to use a utility function that returns all unique
      # values present in an image.
      #############################################################
      max1=$(fslstats ${netPath} -R|awk '{print $2}')
      max2=$(fslstats ${netPath} -r|awk '{print $2}')
      if [[ $(echo ${max1} '<='  1|bc) == 1 ]] \
         && [[ $(echo ${max2} '<='  1|bc) == 1 ]]
         then
         continue
      fi
      case ${netSpace}2${space} in
      #############################################################
      # If the map and the image are both in native BOLD space,
      # then no transformations need be applied
      #############################################################
      nat2native)
         rm -f ${mapbase}${netName}${ext}
         ln -s ${netPath} ${mapbase}${netName}${ext}
         ;;
      #############################################################
      # If the map is in native BOLD space and the image is in
      # standard space, then all forward transformations must be
      # applied.
      #############################################################
      nat2standard)
         rm -f ${mapbase}${netName}${ext}
         ${ANTSPATH}/antsApplyTransforms \
            -e 3 -d 3 \
            -i ${netPath} \
            -o ${mapbase}${netName}${ext} \
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
         rm -f ${mapbase}${netName}${ext}
         ${ANTSPATH}/antsApplyTransforms \
            -e 3 -d 3 \
            -i ${netPath} \
            -o ${mapbase}${netName}${ext} \
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
         rm -f ${mapbase}${netName}${ext}
         ${ANTSPATH}/antsApplyTransforms \
            -e 3 -d 3 \
            -i ${netPath} \
            -o ${mapbase}${netName}${ext} \
            -r ${template} \
            $resample \
            $warp \
            $affine \
            $rigid \
            -n MultiLabel
         ;;
      #############################################################
      # If the map is in standard space and the image in native
      # space, then all inverse transforms must be applied
      #############################################################
      std2native)
         rm -f ${mapbase}${netName}${ext}
         ${ANTSPATH}/antsApplyTransforms \
            -e 3 -d 3 \
            -i ${netPath} \
            -o ${mapbase}${netName}${ext} \
            -r ${referenceVolume[${subjidx}]}${ext} \
            $icoreg \
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
         rm -f ${mapbase}${netName}${ext}
         ln -s ${netPath} ${mapbase}${netName}${ext}
         ;;
      esac
      ;;
   sclib)
      #############################################################
      # Ensure that the network has more than one node. If the
      # network has only one node, there is no point in running
      # this analysis on it.
      #############################################################
      numnodes=$(grep -i '^#' ${netPath}|wc -l)
      if [[ ${numnodes} -le 1 ]]
         then
         continue
      fi
      #libspace=$(grep -i '^SPACE::' ${netPath}|cut -d":" -f3)
      #############################################################
      # If the primary BOLD timeseries is in native space, use
      # ANTs to transform spatial coordinates into native space.
      # This process is much less intuitive than it sounds,
      # largely because of the stringent orientation requirements
      # within ANTs, and it is cleverly tucked away behind a
      # utility script called pointTransform.
      #
      # Also, note that antsApplyTransformsToPoints (and
      # consequently pointTransform) requires the inverse of the
      # transforms that you would intuitively expect it to
      # require.
      #############################################################
      case std2${space} in
      std2native)
         ##########################################################
         # Apply the required transforms.
         ##########################################################
         netPathIn=${netPath}
         netPath=${outbase}${netName}_warped.sclib
         rm -f ${netPath}
         [[ ${trace} == 1 ]] && trace_prop=-x
         ${XCPEDIR}/utils/pointTransform \
            -v \
            -i ${netPathIn} \
            -s ${template} \
            -r ${referenceVolume[${subjidx}]}${ext} \
            $coreg \
            $rigid \
            $affine \
            $warp \
            $resample \
            $trace_prop \
            >> ${netPath}
         ;;
      #############################################################
      # Coordinates are always in standard space, so if the
      # primary BOLD timeseries has already been normalised, then
      # there is no need for any further manipulations.
      #############################################################
      std2standard)
         space=standard
         ;;
      esac
      #############################################################
      # Use the (warped) coordinates and radius to generate a map
      # of the network.
      #############################################################
      [[ ${trace} == 1 ]] && traceprop="-x"
      ${XCPEDIR}/utils/coor2map \
         ${traceprop} \
         -i ${netPath} \
         -t ${referenceVolumeBrain[${subjidx}]} \
         -o ${mapbase}${netName}
      ;;
   done)
      netType=done
      ;;
   esac
   ################################################################
   # Update the path to the network map
   ################################################################
   netPath=${mapbase}${netName}${ext}
   ln -s ${netPath} ${netbase}${netName}${ext}
   ################################################################
   # Update the information for the current network
   ################################################################
   netInfo="#NM,${netName}#MP,${netPath}#SP,${netSpace}"
   ################################################################
   # [2]
   # Compute the mean local timeseries for each node in the
   # network.
   ################################################################
   rm -f ${netTs}
   printf "ts::"
   ${XCPEDIR}/utils/roi2ts.R \
      -i "${img}${ext}" \
      -r "${netPath}" \
      >> ${netTs}
   netInfo="${netInfo}#TS,${netTs}"
   ################################################################
   # [3]
   # Compute the adjacency matrix based on the mean local
   # timeseries.
   ################################################################
   printf "mat::"
   rm -f ${netMat}
   rm -f ${netPajek}
   ${XCPEDIR}/utils/ts2adjmat.R \
      -t "${netTs}" \
      |sed s@'NA'@'NaN'@g \
      >> ${netMat}
   ${XCPEDIR}/utils/adjmat2pajek.R \
      -a "${netMat}" \
      -t "${net_thr[${cxt}]}" \
      >> ${netPajek}
   netInfo="${netInfo}#AM,${netMat}#PJ,${netPajek}"
   ################################################################
   # Determine whether any of the network's nodes failed to
   # capture any variation, and print the indices of any such
   # nodes.
   ################################################################
   rm -f ${netbase}${netName}_missing.txt
   unset missing
   badnodes=$(grep -nE '^[NaN ]*(1)?[NaN ]*$' ${netMat}\
      |cut -d':' -f1)
   [[ -n ${badnodes} ]] \
      && echo "${badnodes}" >> ${netbase}${netName}_missing.txt \
      && missing=",'missing','${netbase}${netName}_missing.txt'"
   ################################################################
   # [4]
   # Compute the community partition.
   ################################################################
   printf "com::"
   case ${net_com[${cxt}]} in
   genlouvain)
      gammas=$(echo ${net_gamma[${cxt}]}|sed s@','@' '@g)
      for gamma in ${gammas}
         do
         gammapr=$(echo ${gamma}|sed s@'\.'@'-'@g)
         netComRt=${netbase}${netName}_gamma${gammapr}
         netCom=${netComRt}_community.1D
         rm -f ${netbase}${netName}_gamma${gammapr}*
         matlab -nodesktop \
            -nosplash \
            -nojvm \
            -r "addpath(genpath('${XCPEDIR}/thirdparty/')); addpath(genpath('${XCPEDIR}/utils/')); glconsensusCL('${netMat}','${netComRt}','gamma',${gamma},'nreps',${net_consensus[${cxt}]}${missing}); exit"\
            2>/dev/null 1>&2
         netInfo="${netInfo}#${gamma}CM,${netCom}"
         ##########################################################
         # Obtain the within-/between-network connectivity values
         # if they are requested
         ##########################################################
         if [[ ${net_wb[${cxt}]} == Y ]]
            then
            ${XCPEDIR}/utils/withinBetween.R \
               -m ${netMat} \
               -c ${netCom} \
               -o ${netbase}${netName}_gamma${gammapr}
         fi
      done
      ;;
   none)
      gammas=1
      ;;
   esac
   ################################################################
   # Include a priori partitions if requested.
   ################################################################
   netApriori=$(echo ${net}|cut -d'#' -f5)
   if [[ ${net_comh[${cxt}]} == Y ]] \
      && [[ -n ${netApriori} ]]
      then
      netInfo="${netInfo}#aprCM,${netApriori}"
      rm -f ${netbase}${netName}_apriori_quality
      ${XCPEDIR}/utils/quality.R \
         -m ${netMat} \
         -c ${netApriori} \
         >> ${netbase}${netName}_apriori_quality.txt
      #############################################################
      # Obtain the within-/between-network connectivity values if
      # they are requested
      #############################################################
      if [[ ${net_wb[${cxt}]} == Y ]]
         then
         ${XCPEDIR}/utils/withinBetween.R \
            -m ${netMat} \
            -c ${netApriori} \
            -o ${netbase}${netName}_apriori
      fi
   fi
   ################################################################
   # Compute within/between network connectivity and
   # reproducibility measures.
   ################################################################
   ################################################################
   # Write the network information into the collated output.
   ################################################################
   echo "${netInfo}" >> ${nets[${cxt}]}
   echo "END"
done
echo "Processing step complete: network analysis"





###################################################################
# Write the path to the file that indexes all networks to the
# design file.
###################################################################
if [[ -e ${nets[${cxt}]} ]]
   then
   echo "nets[${subjidx}]=${nets[${cxt}]}" \
      >> $design_local
fi





###################################################################
# CLEANUP
#  * Remove any temporary files if cleanup is enabled.
#  * Update the audit file to reflect completion of the module.
###################################################################
img=$(readlink -f ${img}${ext})
if [[ "${net_cleanup[${cxt}]}" == "Y" ]]
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
exit 0
