#!/usr/bin/env bash

###################################################################
#  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  #
###################################################################

###################################################################
# SPECIFIC MODULE HEADER
# This module performs functional connectivity analyses.
###################################################################
mod_name_short=fcon
mod_name='FUNCTIONAL CONNECTOME MODULE'
mod_head=${XCPEDIR}/core/CONSOLE_MODULE_RC

###################################################################
# GENERAL MODULE HEADER
###################################################################
source ${XCPEDIR}/core/constants
source ${XCPEDIR}/core/functions/library.sh
source ${XCPEDIR}/core/parseArgsMod

###################################################################
# MODULE COMPLETION AND ANCILLARY FUNCTIONS
###################################################################
update_networks() {
   atlas_set      ${a[Name]}   Map               ${nodemap[cxt]}
   atlas_set      ${a[Name]}   Timeseries        ${ts[cxt]}
   atlas_set      ${a[Name]}   MatrixFC          ${adjacency[cxt]}
   atlas_set      ${a[Name]}   Pajek             ${pajek[cxt]}
   atlas_set      ${a[Name]}   MissingCoverage   ${missing[cxt]}
   atlas_set      ${a[Name]}   DynamicFC         ${ts_edge[cxt]}
   atlas_set      ${a[Name]}   Space             ${space[sub]}
}

completion() {
   write_atlas

   source ${XCPEDIR}/core/auditComplete
   source ${XCPEDIR}/core/updateQuality
   source ${XCPEDIR}/core/moduleEnd
}





###################################################################
# OUTPUTS
###################################################################
define      mapbase              ${out}/${prefix}_atlas

declare_atlas_outputs() {
   define   fcdir                ${outdir}/${a[Name]}
   define   fcbase               ${fcdir[cxt]}/${prefix}_${a[Name]}
   define   nodemap              ${mapbase[cxt]}/${prefix}_${a[Name]}.nii.gz
   define   ts                   ${fcbase[cxt]}_ts.1D
   define   adjacency            ${fcbase[cxt]}_network.txt
   define   pajek                ${fcbase[cxt]}.net
   define   missing              ${fcbase[cxt]}_missing.txt
   define   ts_edge              ${fcbase[cxt]}_tsEdge.1D
}

<< DICTIONARY

adjacency
   The connectivity matrix or functional connectome.
mapbase
   The base path to any parcellations or ROI atlantes that have
   been transformed into analyte space.
missing
   An index of network nodes that are insufficiently covered and
   consequently do not produce meaningful output.
nodemap
   The map of the network's nodes, warped into analyte space.
pajek
   A representation of the network as a sparse matrix. Used by
   some network science software packages.
ts
   The mean local timeseries computed in each network node.
ts_edge
   The timeseries computed in each network edge using the
   multiplication of temporal derivatives (MTD).

DICTIONARY










###################################################################
# Retrieve all the networks for which analysis should be run, and
# prime the analysis.
###################################################################
if [[ -n ${fcon_atlas[cxt]} ]]
   then
   subroutine                 @0.1
   add_reference     referenceVolume[sub]   ${prefix}_referenceVolume
   load_atlas        ${atlas_orig}
   load_atlas        ${atlas[sub]}
else
   echo \
"
::XCP-WARNING: Functional connectome analysis has been requested,
  but no network maps have been provided.

  Skipping module"
   exit 1
fi





###################################################################
# Iterate through all networks.
#
# In brief, the functional connectome analysis process consists of
# the following steps:
#  1. Generate a map of the current network if it does not already
#     exist, and move the map from anatomical space into BOLD
#     space.
#  2. Extract mean timeseries from each node of the network.
#  3. Compute the adjacency matrix from the mean node timeseries.
###################################################################
for net in ${atlas_names[@]}
   do
   atlas_parse ${net}
   atlas_check || continue
   [[ ! -s    ${a[Map]} ]]                   \
   && json_rm ${a[Name]} from atlas[${cxt}]  \
   && continue
   routine                    @1    Functional connectome: ${a[Name]}
   ################################################################
   # Define the paths to the potential outputs of the current
   # network analysis.
   ################################################################
   declare_atlas_outputs
   ################################################################
   # [1]
   # Based on the type of network map and the space of the primary
   # BOLD timeseries, decide what is necessary to move the map
   # into the BOLD timeseries space.
   ################################################################
   subroutine                 @1.2  Mapping network to image space
   ################################################################
   # If the network map has already been computed in this space,
   # then move on to the next stage.
   ################################################################

  if is_image ${nodemap[cxt]} \
   && ! rerun
      then
      subroutine              @1.2.1
      a[Type]=done
   fi

   mkdir -p ${fcdir[cxt]}
   case  ${a[Type]} in
   Map)
      subroutine              @1.2.2
      #############################################################
      # Ensure that the network has more than one node, then map
      # it into the analyte space.
      #############################################################
      range=( $(exec_fsl fslstats ${a[Map]} -R) )
      if (( $(arithmetic ${range[1]}\<=1) == 1 ))
         then
         subroutine           @1.2.3   Skipping ${a[Name]}: Not a well-formed node system
         continue
      fi
      import_image            a[Map]   ${intermediate}-${a[Name]}.nii.gz
      warpspace               ${a[Map]}                  \
                              ${nodemap[cxt]}            \
                              ${a[Space]}:${space[sub]}  \
                              MultiLabel
      ;;
   Coor)
      subroutine              @1.2.4
      output      node_sclib           ${mapbase[cxt]}/${a[Name]}.sclib
      #############################################################
      # If the primary BOLD timeseries is in native space, use
      # ANTs to transform spatial coordinates into native space.
      # This process is much less intuitive than it sounds,
      # largely because of the stringent orientation requirements
      # within ANTs, and it is wrapped in the warpspace function.
      #############################################################
      subroutine              @1.2.6
      warpspace                    \
         ${a[Map]}                 \
         ${node_sclib[cxt]}        \
         ${a[Space]}:${space[sub]} \
         ${a[VoxelCoordinates]}
      #############################################################
      # Use the (warped) coordinates and radius to generate a map
      # of the network.
      #############################################################
      subroutine              @1.2.7
      exec_xcp coor2map                      \
         -i    ${node_sclib[cxt]}            \
         -t    ${referenceVolumeBrain[sub]}  \
         -o    ${nodemap[cxt]}
      ;;
   done)
      subroutine              @1.2.8
      ;;
   esac
   ################################################################
   # Update the path to the network map
   ################################################################
   add_reference nodemap[$cxt] ${a[Name]}/${prefix}_${a[Name]}





   ################################################################
   # [2]
   # Compute the mean local timeseries for each node in the
   # network.
   ################################################################
   if [[ ! -s ${ts[cxt]} ]] \
   || rerun
      then
      subroutine              @1.3  Computing network timeseries
      exec_sys rm -f ${ts[cxt]}
      exec_xcp roi2ts.R                      \
         -i    ${img}                        \
         -r    ${nodemap[cxt]}               \
         -l    ${a[NodeIndex]}               \
         >>    ${ts[cxt]}
   fi





   ################################################################
   # [3]
   # Compute the adjacency matrix based on the mean local
   # timeseries.
   ################################################################
   if [[ ! -s ${pajek[cxt]} ]]   \
   || rerun
      then
      subroutine              @1.4  Computing adjacency matrix
      exec_sys rm -f ${adjacency[cxt]}
      exec_sys rm -f ${pajek[cxt]}
      exec_sys rm -f ${missing[cxt]}
      exec_xcp ts2adjmat.R -t ${ts[cxt]} >> ${adjacency[cxt]}
      exec_xcp adjmat2pajek.R    \
         -a    ${adjacency[cxt]} \
         -t    ${fcon_thr[cxt]}  \
         >>    ${pajek[cxt]}
      ################################################################
      # Flag nodes that fail to capture any signal variance.
      ################################################################
      subroutine              @1.5  Determining node coverage
      unset missing_arg
      badnodes=$(exec_xcp missingIdx.R -i ${adjacency[cxt]})
      if [[ -n ${badnodes} ]]
         then
         echo "${badnodes}" >> ${missing[cxt]}
         missing_arg=",'missing','${missing[cxt]}'"
      fi
   fi


   update_networks
   routine_end
done

completion
