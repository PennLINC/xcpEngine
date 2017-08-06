#!/usr/bin/env bash

###################################################################
#  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  #
###################################################################

###################################################################
# SPECIFIC MODULE HEADER
# This module performs elementary network analyses.
###################################################################
mod_name_short=net
mod_name='NETWORK ANALYSIS MODULE'
mod_head=${XCPEDIR}/core/CONSOLE_MODULE_RC

###################################################################
# GENERAL MODULE HEADER
###################################################################
source ${XCPEDIR}/core/constants
source ${XCPEDIR}/core/functions/library.sh
source ${XCPEDIR}/core/parseArgsMod

#################################################################f##
# MODULE COMPLETION AND ANCILLARY FUNCTIONS
###################################################################
update_networks() {
   atlas_add      ${a_name}   Map               ${nodemap[${cxt}]}
   atlas_add      ${a_name}   Timeseries        ${ts[${cxt}]}
   atlas_add      ${a_name}   Matrix            ${adjacency[${cxt}]}
   atlas_add      ${a_name}   Pajek             ${pajek[${cxt}]}
   atlas_add      ${a_name}   MissingCoverage   ${missing[${cxt}]}
   atlas_config   ${a_name}   Space             ${space}
   
   for g in ${gammas[@]}
      do
      gf=${g//\./-}
      atlas_add   ${a_name}   CommunityRes${g}  ${netbase[${cxt}]}_CommunityRes${gf}_community.1D
   done
}

completion() {
   write_atlas
   
   source ${XCPEDIR}/core/auditComplete
   source ${XCPEDIR}/core/updateQuality
   source ${XCPEDIR}/core/moduleEnd
}

community_detection() {
   echo_cmd "matlab : addpath(genpath('${XCPEDIR}/thirdparty/'))"
   echo_cmd "matlab : addpath(genpath('${XCPEDIR}/utils/'))"
   echo_cmd "matlab : glconsensusCL('${adjacency[${cxt}]}','${com_root[${cxt}]}','gamma',${gamma},'nreps',${net_consensus[${cxt}]}${missing_arg})"
   matlab -nodesktop \
      -nosplash \
      -nojvm \
      -r "addpath(genpath('${XCPEDIR}/thirdparty/')); addpath(genpath('${XCPEDIR}/utils/')); glconsensusCL('${adjacency[${cxt}]}','${com_root[${cxt}]}','gamma',${gamma},'nreps',${net_consensus[${cxt}]}${missing_arg}); exit"\
      2>/dev/null 1>&2
   echo_cmd "matlab : exit"
}





###################################################################
# OUTPUTS
###################################################################
configure      mapbase                 ${out}/${prefix}_atlas
gammas=( ${net_gamma[${cxt}]//,/ } )

<< DICTIONARY

gammas
   Not strictly an output. An array specifying all resolution
   parameters for the community detection procedure.
mapbase
   Not strictly an output. The base path to any parcellations or
   ROI atlantes that have been transformed into analyte space.

DICTIONARY










###################################################################
# Retrieve all the networks for which analysis should be run, and
# prime the analysis.
###################################################################
if [[ -e ${net_atlas[${cxt}]} ]]
   then
   subroutine                 @0.1
   add_reference     referenceVolume[${subjidx}]   ${prefix}_referenceVolume
   load_atlas        ${net_atlas[${cxt}]}
   load_atlas        ${atlas[${subjidx}]}
   load_transforms
else
   echo \
"
::XCP-WARNING: Network analysis has been requested, 
  but no network maps have been provided.
  
  Skipping module"
   exit 1
fi





###################################################################
# Iterate through all networks.
#
# In brief, the network analysis process consists of the
# following steps:
#  1. Generate a map of the current network if it does not already
#     exist, and move the map from anatomical space into BOLD
#     space.
#  2. Extract mean timeseries from each node of the network.
#  3. Compute the adjacency matrix from the mean node timeseries.
#  4. Perform consensus-community detection on the adjacency
#     matrix to partition it into subgraphs.
###################################################################
for net in ${atlas_names[@]}
   do
   atlas_parse ${net}
   [[ -z ${a_map} ]] && continue
   routine                    @1    Network analysis: ${a_name}
   ################################################################
   # Define the paths to the potential outputs of the current
   # network analysis.
   ################################################################
   configure   netdir               ${outdir}/${a_name}
   configure   netbase              ${netdir[${cxt}]}/${prefix}_${a_name}
   configure   nodemap              ${mapbase[${cxt}]}/${prefix}_${a_name}.nii.gz
   configure   ts                   ${netbase[${cxt}]}_ts.1D
   configure   adjacency            ${netbase[${cxt}]}_network.txt
   configure   pajek                ${netbase[${cxt}]}.net
   configure   missing              ${netbase[${cxt}]}_missing.txt
   ################################################################
   # [1]
   # Based on the type of network map and the space of the primary
   # BOLD timeseries, decide what is necessary to move the map
   # into the BOLD timeseries space.
   ################################################################
   subroutine                 @1.2  Mapping network to image space
   echo $a_type
   ################################################################
   # If the network map has already been computed in this space,
   # then move on to the next stage.
   ################################################################
   if is_image ${nodemap[${cxt}]} \
   && ! rerun
      then
      subroutine              @1.2.1
      a_type=done
   fi
   mkdir -p ${netdir[${cxt}]}
   case ${a_type} in
   Map)
      subroutine              @1.2.2
      #############################################################
      # Ensure that the network has more than one node, then map
      # it into the analyte space.
      #############################################################
      rm -f ${nodemap[${cxt}]}
      range=( $(exec_fsl fslstats ${a_map} -R) )
      if (( $(arithmetic ${range[1]}\<=1) == 1 ))
         then
         subroutine           @1.2.3   Skipping ${a_name}: Not a well-formed node system
         continue
      fi
      source ${XCPEDIR}/core/mapToSpace ${a_space}2${space} ${a_map} ${nodemap[${cxt}]} MultiLabel
      ;;
   Coordinates)
      subroutine              @1.2.4
      output      node_sclib           ${mapbase[${cxt}]}${a_name}.sclib
      if (( ${a_nodes} <= 1 ))
         then
         subroutine           @1.2.5
         continue
      fi
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
         subroutine           @1.2.6
         ##########################################################
         # Apply the required transforms.
         ##########################################################
         rm -f ${node_sclib[${cxt}]}
         exec_xcp pointTransform \
            -v \
            -i ${a_map} \
            -s ${template} \
            -r ${referenceVolume[${subjidx}]} \
            $coreg \
            $rigid \
            $affine \
            $warp \
            $resample \
            $trace_prop \
            >> ${node_sclib[${cxt}]}
         ;;
      #############################################################
      # Coordinates are always in standard space, so if the
      # primary BOLD timeseries has already been normalised, then
      # there is no need for any further manipulations.
      #############################################################
      std2standard)
         subroutine           @1.2.7
         ;;
      esac
      #############################################################
      # Use the (warped) coordinates and radius to generate a map
      # of the network.
      #############################################################
      subroutine              @1.2.8
      exec_xcp coor2map \
         ${traceprop} \
         -i ${node_sclib[${cxt}]} \
         -t ${referenceVolumeBrain[${subjidx}]} \
         -o ${nodemap[${cxt}]}
      ;;
   done)
      subroutine              @1.2.9
      ;;
   esac
   ################################################################
   # Update the path to the network map
   ################################################################
   add_reference nodemap[${cxt}] ${a_name}/${prefix}_${a_name}
   
   
   
   
   
   ################################################################
   # [2]
   # Compute the mean local timeseries for each node in the
   # network.
   ################################################################
   if [[ ! -s ${ts[${cxt}]} ]] \
   || rerun
      then
      subroutine              @1.3  Computing network timeseries
      exec_sys rm -f ${ts[${cxt}]}
      exec_xcp roi2ts.R \
         -i ${img} \
         -r ${nodemap[${cxt}]} \
         >> ${ts[${cxt}]}
   fi





   ################################################################
   # [3]
   # Compute the adjacency matrix based on the mean local
   # timeseries.
   ################################################################
   if [[ ! -s ${pajek[${cxt}]} ]] \
   || rerun
      then
      subroutine              @1.4  Computing adjacency matrix
      exec_sys rm -f ${adjacency[${cxt}]}
      exec_sys rm -f ${pajek[${cxt}]}
      exec_sys rm -f ${missing[${cxt}]}
      exec_xcp ts2adjmat.R -t ${ts[${cxt}]} >> ${adjacency[${cxt}]}
      exec_xcp adjmat2pajek.R \
         -a ${adjacency[${cxt}]} \
         -t ${net_thr[${cxt}]} \
         >> ${pajek[${cxt}]}
      ################################################################
      # Flag nodes that fail to capture any signal variance.
      ################################################################
      subroutine              @1.5  Determining node coverage
      unset missing_arg
      badnodes=$(exec_xcp missingIdx.R -i ${adjacency[${cxt}]})
      if [[ -n ${badnodes} ]]
         then
         echo "${badnodes}" >> ${missing[${cxt}]} \
         missing_arg=",'missing','${missing[${cxt}]}'"
      fi
   fi





   ################################################################
   # [4]
   # Compute the community partition.
   ################################################################
   case ${net_com[${cxt}]} in
   genlouvain)
      subroutine              @1.6.1   Detecting community structure
      for gamma in ${gammas[@]}
         do
         gamma_filename=${gamma//\./-}
         configure   com_root       ${netbase[${cxt}]}_CommunityRes${gamma_filename}
         configure   community      ${com_root[${cxt}]}_community.1D
         if [[ ! -s  ${community[${cxt}]} ]] \
         || rerun
            then
            subroutine        @1.6.2
            community_detection
         fi
         exec_xcp withinBetween.R \
            -m ${adjacency[${cxt}]} \
            -c ${community[${cxt}]} \
            -o ${com_root[${cxt}]}
      done
      ;;
   none)
      subroutine              @1.6.3
      ;;
   esac
   ################################################################
   # Include a priori partitions if requested.
   ################################################################
   subroutine                 @1.7  Computing community statistics
   for i in $(seq ${#a_community_names[@]})
      do
      subroutine              @1.7.1
      (( i-- ))
      partition_name=${a_community_names[i]}
      if [[ ! -s ${netbase[${cxt}]}_${partition_name}_wbOverall.csv ]] \
      ||rerun
         then
         subroutine           @1.7.1
         exec_sys rm -f ${netbase[${cxt}]}_${partition_name}Quality.txt
         exec_xcp quality.R \
            -m ${adjacency[${cxt}]} \
            -c ${a_community[i]} \
            >> ${netbase[${cxt}]}_${partition_name}Quality.txt
         exec_xcp withinBetween.R \
            -m ${adjacency[${cxt}]} \
            -c ${a_community} \
            -o ${netbase[${cxt}]}_${partition_name}
      fi
   done
   update_networks
   routine_end
done

completion
