#!/usr/bin/env bash

###################################################################
#  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  #
###################################################################

###################################################################
# SPECIFIC MODULE HEADER
# This module assesses quality of functional connectivity data
###################################################################
mod_name_short=fcqa
mod_name='FUNCTIONAL QUALITY ASSESSMENT MODULE'
mod_head=${XCPEDIR}/core/CONSOLE_MODULE_RC

###################################################################
# GENERAL GROUP MODULE HEADER
###################################################################
source ${XCPEDIR}/core/constants
source ${XCPEDIR}/core/functions/library.sh
source ${XCPEDIR}/core/xcpDelocaliser

###################################################################
# MODULE COMPLETION
###################################################################
completion() {
   write_output      placeholder
   
   source ${XCPEDIR}/core/auditComplete
   source ${XCPEDIR}/core/updateQuality
   source ${XCPEDIR}/core/moduleEnd
}





###################################################################
# OUTPUTS
###################################################################
output      qcfc_n_sig_edges        ${prefix}_QC-FC_nSigEdges.txt
output      qcfc_abs_med_cor        ${prefix}_QC-FC_absMedCor.txt
output      qcfc_dist_dependence    ${prefix}_QC-FC_distanceDependence.csv
output      qcfc_correlation        ${prefix}_QC-FC_correlation.csv
output      qcfc_correlation_thr    ${prefix}_QC-FC_correlation_thr.csv
output      node_distance           ${prefix}_node_distance.csv

<<DICTIONARY

placeholder
   placeholder

DICTIONARY










###################################################################
# Retrieve all the networks for which quality assessment should be
# run, and prime the analysis.
###################################################################
if [[ -s ${fcqa_atlas[cxt]} ]]
   then
   subroutine                 @0.1
   load_atlas        ${fcqa_atlas[cxt]}
else
   echo \
"
::XCP-WARNING: Quality assessment of functional connectivity data
  has been requested, but no functional connectivity data have been
  provided.
  
  Skipping module"
   exit 1
fi





###################################################################
# Retrieve all motion estimates.
# qm should probably be a hash table.
###################################################################
unset    v     motion
for i in ${!quality[@]}
   do
   unset    qa
   mapfile  qa < ${quality[i]}
   qvarsub=( ${qa[0]//,/ } )
   qvalsub=( ${qa[1]//,/ } )
   if [[ -z ${v} ]]
      then
      for v in ${!qvarsub[@]}; do contains ${qvarsub[v]} relMeanRMSMotion && break; done
   fi
   motion[i]=${qvalsub[v]}
done





###################################################################
# Iterate through each brain atlas. Compute the QC-FC measures for
# each.
###################################################################
for map in ${atlas_names[@]}
   do
   unset edges
   ################################################################
   # Iterate over all subjects's atlantes.
   ################################################################
   for i in ${!atlas[@]}
      do
      load_atlas     ${atlas[i]}
      atlas_parse    ${map}
      edges[i]=${a[MatrixFC]}
      
      echo ${ids[i]},${edges[i]},${motion[i]} >> ${intermediate}-subjects.csv
   done
   load_atlas        ${fcqa_atlas[cxt]}
   atlas_parse       ${map}





   ################################################################
   # Build the edgewise FC correlation matrix.
   # Pass in confounds if they have been provided.
   ################################################################
   rm -f ${outbase}quality
   [[ -e ${fcqa_confmat[cxt]} ]] \
      && confound="-a ${fcqa_confmat[cxt]}"
   exec_xcp mocor.R                                   \
      -c    ${intermediate}-subjects.csv              \
      -s    ${fcqa_sig[cxt]}                          \
      -n    ${parName}                                \
      -o    ${qcfc_correlation[cxt]}_${a[Name]}.txt   \
      -r    ${qcfc_correlation_thr[cxt]}_${a[Name]}.txt \
      -f    ${qcfc_correlation[cxt]}_${a[Name]}       \
      -q    ${qcfc_n_sig_edges[cxt]}                  \
      ${confound}





   ################################################################
   # Obtain the centres of mass for each network node.
   ################################################################
   exec_sys rm -f ${intermediate}-cmass.sclib
   exec_xcp cmass.R                                   \
      -r    ${a[Map]}                                 \
      >>    ${intermediate}-cmass.sclib





   ################################################################
   # Build the edgewise distance matrix.
   ################################################################
   exec_sys rm -f ${node_distance[cxt]}_${a[Name]}
   exec_xcp lib2mat.R                                 \
      -c    ${intermediate}-cmass.sclib               \
      >>    ${node_distance[cxt]}_${a[Name]}





   ################################################################
   # Compute the overall correlation between distance and motion
   # effects to infer distance-dependence of motion effects.
   ################################################################
   exec_sys rm -f ${intermediate}-quality2
   echo distDependMotion >> ${intermediate}-quality2
   exec_xcp simil.R                                   \
      -i    ${node_distance[cxt]}_${a[Name]},${qcfc_correlation[cxt]}_${a[Name]} \
      -l    'Inter-node distance (mm),FC-motion correlation (r)' \
      -f    ${outdir}/${analysis}_distDepend_${parName}.svg \
      |cut -d' ' -f2                                  \
      |head -n1                                       \
      >> ${intermediate}-quality2
done





###################################################################
# Estimate the number of degrees of freedom lost.
###################################################################





completion
