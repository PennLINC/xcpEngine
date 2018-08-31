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
   atlas_set   ${a[Name]}   CommunityPartitionRes${gamma_x}  ${community[cxt]}
}

completion() {
   write_atlas

   source ${XCPEDIR}/core/auditComplete
   source ${XCPEDIR}/core/updateQuality
   source ${XCPEDIR}/core/moduleEnd
}

community_detection_matlab() {
   verbose && echo_cmd "matlab : addpath(genpath('${XCPEDIR}/thirdparty/'))"
   verbose && echo_cmd "matlab : addpath(genpath('${XCPEDIR}/utils/'))"
   verbose && echo_cmd "matlab : glconsensusCL('${adjacency}','${com_root[cxt]}','gamma',${gamma},'nreps',${net_consensus[cxt]}${missing_arg})"
   matlab -nodesktop \
      -nosplash \
      -nojvm \
      -r "addpath(genpath('${XCPEDIR}/thirdparty/')); addpath(genpath('${XCPEDIR}/utils/')); glconsensusCL('${adjacency}','${com_root[cxt]}','gamma',${gamma},'nreps',${net_consensus[cxt]}${missing_arg}); exit"\
      2>/dev/null 1>&2
   verbose && echo_cmd "matlab : exit"
}

community_detection_octave() {
   verbose && echo_cmd "octave : addpath(genpath('${XCPEDIR}/thirdparty/'))"
   verbose && echo_cmd "octave : addpath(genpath('${XCPEDIR}/utils/'))"
   verbose && echo_cmd "octave : glconsensusCL('${adjacency}','${com_root[cxt]}','gamma',${gamma},'nreps',${net_consensus[cxt]}${missing_arg})"
   octave \
      --no-gui \
      --eval "addpath(genpath('${XCPEDIR}/thirdparty/')); addpath(genpath('${XCPEDIR}/utils/')); glconsensusCL('${adjacency}','${com_root[cxt]}','gamma',${gamma},'nreps',${net_consensus[cxt]}${missing_arg}); exit"\
      2>/dev/null 1>&2
   verbose && echo_cmd "octave : exit"
}

community_detection() {
  if [[ -n $(which matlab) ]]
  then
      community_detection_matlab
  else
    community_detection_octave
  fi

}


###################################################################
# OUTPUTS
###################################################################
declare_atlas_outputs() {
   define      net_dir              ${outdir}/${a[Name]}
   define      net_root             ${net_dir[cxt]}/${prefix}_${a[Name]}
   exec_sys    mkdir -p             ${net_dir[cxt]}
}
declare_community_outputs() {
   define      com_dir              ${net_dir[cxt]}/${1}
   define      com_root             ${com_dir[cxt]}/${prefix}_${1}
   define      community            ${com_root[cxt]}_partition.1D
   define      wbOverall            ${com_root[cxt]}_wbOverall.csv
   define      modularity           ${com_root[cxt]}_modularity.txt
   exec_sys    mkdir -p             ${com_dir[cxt]}
   [[ -z       ${a[${1}]} ]] &&     a[${1}]=${community[cxt]}
}

<< DICTIONARY

com_dir/com_root

net_dir/net_root


DICTIONARY










###################################################################
# Retrieve all the networks for which analysis should be run, and
# prime the analysis.
###################################################################
if [[ -n ${net_atlas[cxt]} ]]
   then
   subroutine                 @0.1
   load_atlas        ${atlas_orig}
   load_atlas        ${atlas[sub]}
else
   echo \
"
::XCP-WARNING: Network analysis has been requested, but no network
  maps have been provided.

  Skipping module"
   exit 1
fi





###################################################################
# Parse gamma values
###################################################################
gammas=()
giv=${net_gamma[cxt]//,/ }
for i in $giv
   do i=(${i//:/ })
   case ${#i[@]} in
   ################################################################
   # Single gamma value
   ################################################################
   1)
      gammas=( ${gammas[@]} ${i} )
      ;;
   ################################################################
   # Sequence with increment of 1 (e.g., 1:7)
   ################################################################
   2)
      ll=${i[0]}
      ul=${i[1]}
      g=${ll}
      while (( $(arithmetic "${g} <= ${ul}" ) == 1 ))
         do gammas=( ${gammas[@]} ${g} )
         g=$(arithmetic $g + 1)
         while contains $g '0$';  do g=${g%0}; done
         while contains $g '\.$'; do g=${g%.}; done
      done
      ;;
   3)
   ################################################################
   # Sequence with user-specified increment (e.g., 1:0.1:7)
   ################################################################
      ll=${i[0]}
      iv=${i[1]}
      ul=${i[2]}
      g=${ll}
      while (( $(arithmetic "${g} <= ${ul}") == 1 ))
         do gammas=( ${gammas[@]} ${g} )
         g=$(arithmetic $g + ${iv})
         while contains $g '0$';  do g=${g%0}; done
         while contains $g '\.$'; do g=${g%.}; done
      done
      ;;
   esac
done





###################################################################
# Iterate through all networks.
#
# In brief, the network analysis process consists of the
# following steps:
#        . . .
#  ~ TO ~ BE ~ EXPANDED ~
#        . . .
#  X. Perform consensus-community detection on the adjacency
#     matrix to partition it into subgraphs.
###################################################################
for net in ${atlas_names[@]}
   do
   atlas_parse ${net}
   atlas_check
   unset matrix communities
   matrix=(      $(matching ^Matrix             ${!a[@]}) )
   communities=( $(matching ^CommunityPartition ${!a[@]}) )
   [[ -z ${matrix} ]] && continue
   routine                    @1    Network analysis: ${a[Name]}
   declare_atlas_outputs





   for adjacency in ${matrix[@]}
      do
      adjacency=${a[$adjacency]}
      #############################################################
      # Compute the community partition.
      #############################################################
      case ${net_com[cxt]} in
      genlouvain)
         subroutine           @1.1.1   Detecting community structure
         for gamma in ${gammas[@]}
            do
            gamma_x=${gamma//\./x}
            declare_community_outputs CommunityPartitionRes${gamma_x}
            if [[ ! -s  ${community[cxt]} ]] \
            || rerun
               then
               subroutine     @1.1.2
               community_detection
            fi
            update_networks
            communities=( ${communities[@]} CommunityPartitionRes${gamma_x} )
         done
         ;;
      none)
         subroutine           @1.1.3
         ;;
      esac
      #############################################################
      # Include a priori partitions if requested.
      #############################################################
      subroutine              @1.2  Computing community statistics
      for com in ${communities[@]}
         do
         subroutine           @1.2.1
         declare_community_outputs ${com}
         if [[ ! -s ${wbOverall[cxt]} ]] \
         || rerun
            then
            subroutine        @1.2.2
            exec_sys rm -f ${modularity[cxt]}
            exec_xcp quality.R \
               -m    ${adjacency} \
               -c    ${a[$com]} \
               >>    ${modularity[cxt]}
            exec_xcp withinBetween.R \
               -m    ${adjacency} \
               -c    ${a[$com]} \
               -o    ${com_root[cxt]}
         fi
      done
   done
   routine_end
done

completion
