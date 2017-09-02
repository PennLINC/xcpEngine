#!/usr/bin/env bash

###################################################################
#  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  #
###################################################################

###################################################################
# SPECIFIC MODULE HEADER
# This module aligns the analyte image to a high-resolution target.
###################################################################
mod_name_short=roiquant
mod_name='ATLAS-BASED QUANTIFICATION MODULE'
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
   atlas_config   ${a[Name]}   Map                 ${nodemap[cxt]}
   atlas_config   ${a[Name]}   Space               ${space[sub]}
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
configure      mapbase                 ${out}/${prefix}_atlas

<< DICTIONARY

THE OUTPUTS OF ATLAS-DERIVED QUANTIFICATION ARE PRIMARILY DEFINED
IN THE LOOP OVER NETWORKS.

mapbase
   The base path to any parcellations or ROI atlantes that have
   been transformed into analyte space.

DICTIONARY










###################################################################
# Retrieve all the networks for which analysis should be run, and
# prime the analysis.
###################################################################
if [[ -s ${roiquant_atlas[cxt]} ]]
   then
   subroutine                 @0.1
   add_reference     referenceVolume[$sub]   ${prefix}_referenceVolume
   load_atlas        ${roiquant_atlas[cxt]}
   load_atlas        ${atlas[sub]}
   load_derivatives
   [[ -n ${sequence} ]] && sequence=${sequence}_
else
   echo \
"
::XCP-WARNING: Atlas-based quantification has been requested, but
  no network maps have been provided.
  
  Skipping module"
   exit 1
fi





###################################################################
# Iterate through each ROI atlas. Compute the appropriate scores
# within each RoI in each map.
# * Determine all RoI atlantes to be run through the module.
# * The below loop is re-used (with several modifications) across
#   RoI-wise analyses, so any module-dependent variables should be
#   reassigned to module-independent names here as well.
# * Retrieve all the parcellations for which analysis should be
#   run.
###################################################################
for map in ${atlas_names[@]}
   do
   atlas_parse ${map}
   [[ -z ${a[Map]} ]] && continue
   routine                    @1    Regional quantification: ${a[Name]}
   ################################################################
   # Define the paths to the potential outputs of the current
   # network analysis.
   ################################################################
   configure   rstatdir             ${outdir}/${a[Name]}
   configure   rstatbase            ${rstatdir[cxt]}/${prefix}_${a[Name]}
   configure   nodemap              ${mapbase[cxt]}/${prefix}_${a[Name]}.nii.gz
   
   
   
   
   
   ################################################################
   # [1]
   # Conform the atlas into the space of the analyte image.
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
   mkdir -p ${rstatdir[cxt]}
   case ${a[Type]} in
   Map)
      subroutine              @1.2.2
      #############################################################
      # Ensure that the network has more than one node, then map
      # it into the analyte space.
      #############################################################
      rm -f ${nodemap[cxt]}
      warpspace atlas:${a[Name]} ${nodemap[cxt]} ${space[sub]} MultiLabel
      ;;
   Coordinates)
      subroutine              @1.2.3
      output      node_sclib           ${mapbase[cxt]}${a[Name]}.sclib
      if (( ${a[NodeCount]} <= 1 ))
         then
         subroutine           @1.2.4
         continue
      fi
      #############################################################
      # If the primary BOLD timeseries is in native space, use
      # ANTs to transform spatial coordinates into native space.
      # This process is much less intuitive than it sounds,
      # largely because of the stringent orientation requirements
      # within ANTs, and it is wrapped in the warpspace function.
      #############################################################
      subroutine              @1.2.5
      warpspace \
         ${a[Map]} \
         ${node_sclib[cxt]} \
         ${a[Space]}:${space[sub]} \
         ${a[VoxelCoordinates]}
      #############################################################
      # Use the (warped) coordinates and radius to generate a map
      # of the network.
      #############################################################
      subroutine              @1.2.6
      exec_xcp coor2map \
         -i    ${node_sclib[cxt]} \
         -t    ${referenceVolumeBrain[sub]} \
         -o    ${nodemap[cxt]}
      ;;
   done)
      subroutine              @1.2.7
      ;;
   esac
   ################################################################
   # Update the path to the network map
   ################################################################
   add_reference nodemap[cxt] ${a[Name]}/${prefix}_${a[Name]}
   
   
   
   
   
   ################################################################
   # [2]
   # Compute the value of the statistic of interest for each
   # RoI in the parcellation.
   # Determine whether each node is sufficiently covered. If over
   # 50 percent is not covered, remove it from computation.
   ################################################################
   subroutine              @1.3.3
   cover=( $(exec_xcp nodeCoverage.R \
      -i    ${mask[sub]} \
      -r    ${nodemap[cxt]} \
      -x    ${a[NodeIndex]} \
      -n    ${a[NodeNames]}) )
   ################################################################
   # Perform the quantification: Initialise
   ################################################################
   echo ${cover[0]//,/ } >> ${intermediate}_${a[Name]}_idx.1D
   echo ${cover[1]//,/ } >> ${intermediate}_${a[Name]}_names.1D
   unset qargs
   qargs="
      -a       ${nodemap[cxt]}
      -n       ${a[Name]}
      -i       ${intermediate}_${a[Name]}_idx.1D
      -r       ${intermediate}_${a[Name]}_names.1D
      -p       ${prefix//_/,}"
   ################################################################
   # Perform the quantification: Mean
   ################################################################
   subroutine              @1.3.4   Computing atlas statistics
   apply_exec  Statistic:mean       /dev/null \
      xcp      quantifyAtlas \
      -v       %INPUT \
      -s       mean \
      -o       ${rstatbase[cxt]}_mean_%NAME.csv \
      -t       ${intermediate}_${a[Name]}_mean_%NAME \
      -d       ${sequence}%NAME \
      ${qargs}
   ################################################################
   # Perform the quantification: Median
   ################################################################
   subroutine              @1.3.5
   apply_exec  Statistic:median     /dev/null \
      xcp      quantifyAtlas \
      -v       %INPUT \
      -s       median \
      -o       ${rstatbase[cxt]}_median_%NAME.csv \
      -t       ${intermediate}_${a[Name]}_median_%NAME \
      -d       ${sequence}%NAME \
      ${qargs}
   ################################################################
   # Perform the quantification: Mode
   ################################################################
   subroutine              @1.3.6
   apply_exec  Statistic:mode       /dev/null \
      xcp      quantifyAtlas \
      -v       %INPUT \
      -s       mode \
      -o       ${rstatbase[cxt]}_mode_%NAME.csv \
      -t       ${intermediate}_${a[Name]}_mode_%NAME \
      -d       ${sequence}%NAME \
      ${qargs}
   ################################################################
   # Perform the quantification: Min/Max
   ################################################################
   subroutine              @1.3.7
   apply_exec  Statistic:minmax     /dev/null \
      xcp      quantifyAtlas \
      -v       %INPUT \
      -s       minmax \
      -o       ${rstatbase[cxt]}_minmax_%NAME.csv \
      -t       ${intermediate}_${a[Name]}_minmax_%NAME \
      -d       ${sequence}%NAME \
      ${qargs}
   ################################################################
   # Perform the quantification: Standard deviation
   ################################################################
   subroutine              @1.3.8
   apply_exec  Statistic:stdev      /dev/null \
      xcp      quantifyAtlas \
      -v       %INPUT \
      -s       stdev \
      -o       ${rstatbase[cxt]}_stdev_%NAME.csv \
      -t       ${intermediate}_${a[Name]}_stdev_%NAME \
      -d       ${sequence}%NAME \
      ${qargs}
   ################################################################
   # Perform the quantification: Volume
   ################################################################
   if (( ${roiquant_vol[cxt]} == 1 ))
      then
      subroutine           @1.3.9
      exec_xcp quantifyAtlas \
      -s       vol \
      -o       ${rstatbase[cxt]}_vol.csv \
      -t       ${intermediate}_${a[Name]}_vol_%NAME \
      ${qargs}
   fi
   update_networks
   routine_end
done

completion
