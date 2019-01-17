#!/usr/bin/env bash

###################################################################
#  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  #
###################################################################

###################################################################
# SPECIFIC MODULE HEADER
# This module performs regional quantification of voxelwise maps.
###################################################################
mod_name_short=roiquant
mod_name='ATLAS-BASED QUANTIFICATION MODULE'
mod_head=${XCPEDIR}/core/CONSOLE_MODULE_RC

###################################################################
# GENERAL GROUP MODULE HEADER
###################################################################
source ${XCPEDIR}/core/constants
source ${XCPEDIR}/core/functions/library.sh
source ${XCPEDIR}/core/parseArgsGroup

###################################################################
# MODULE COMPLETION AND ANCILLARY FUNCTIONS
###################################################################
completion() {
   quality[sub]=${quality_group}
   source ${XCPEDIR}/core/updateQuality
   source ${XCPEDIR}/core/moduleEnd
}










###################################################################
# Retrieve all the networks for which regional quantification has
# been run, and prime the analysis.
###################################################################
if [[ -s ${atlas_orig} ]]
   then
   subroutine                 @0.1
   load_atlas        ${atlas_orig}
else
   exit 1
fi





###################################################################
# Iterate through each brain atlas. Collate the regional values for
# each.
###################################################################
for map in ${atlas_names[@]}
   do
   atlas_parse       ${map}
   atlas_check       || continue
   exec_sys mkdir -p ${outdir}/${a[Name]}
   ################################################################
   # Iterate over all subjects's atlantes.
   ################################################################
   routine                    @1    Collating regional values: ${a[Name]}
   subroutine                 @1.1  Atlas: ${a[Name]}
   subroutine                 @1.2  Scanning subject-level regional values
   unset       V
   declare -A  V
   for sub in ${subjects[@]}
      do
      load_atlas     ${atlas[sub]}
      atlas_parse    ${map}
      regional=(     $(matching ^Regional    ${!a[@]}) )
      #############################################################
      # Iterate over the available regional values, and append
      # each to the list of that type of value.
      #############################################################
      for r in "${regional[@]}"
         do
         V[$r]="${V[$r]} ${a[$r]}"
      done
   done
   for r in ${!V[@]}
      do
      if [[ ! -s ${outdir}/${a[Name]}/${sequence}${a[Name]^}${r^}.csv ]] \
      || rerun
         then
         subroutine           @1.3  Collating ${r}
         vallist=$(join_by ',' ${V[$r]})
         exec_xcp combineOutput.R   \
            -i    ${vallist}        \
            -o    ${outdir}/${a[Name]}/${sequence}${a[Name]^}${r^}.csv
      fi
   done
   routine_end
done
