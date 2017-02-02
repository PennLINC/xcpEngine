#!/usr/bin/env bash

###################################################################
#  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  #
###################################################################

###################################################################
# This group-level module computes denoising benchmarks for a
# pipeline
###################################################################

###################################################################
# Constants
###################################################################
# none yet





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
      design_group=${OPTARG}
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
# Ensure that the compulsory design_group variable has been defined
###################################################################
[[ -z ${design_group} ]] && ${XCPEDIR}/xcpModusage mod && exit
[[ ! -e ${design_group} ]] && ${XCPEDIR}/xcpModusage mod && exit
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
echo "#  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  #"
echo "#                                                                 #"
echo "#  ☭                 EXECUTING BENCHMARK MODULE                ☭  #"
echo "#                                                                 #"
echo "#  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  #"
echo "###################################################################"
echo ""
###################################################################
# Source the design file.
###################################################################
source ${design_group}
###################################################################
# Create a directory for intermediate outputs.
###################################################################
[[ ${NUMOUT} == 1 ]] && prep=${cxt}_
outdir=${out_group}/${prep}benchmark
[[ ! -e ${outdir} ]] && mkdir -p ${outdir}
echo "Output directory is $outdir"
###################################################################
# Define paths to all potential outputs.

# For the benchmark module, potential outputs include:
#  * metric: comma-separated index of benchmark metrics
#  * mat: adjacency matrix with edges weighted according to
#    subjectwise correlation between motion and connectivity
#  * matthr: as above, thresholded at significance
#  * matdist: adjacency matrix with edges weighted according to
#    centre-of-mass distance in physical space
###################################################################
outbase=${outdir}/~TEMP~
benchMetric[${cxt}]=${outdir}/${analysis}_benchmarks.csv
benchMat[${cxt}]=${outdir}/${analysis}_fcCorrelation
benchMatthr[${cxt}]=${outdir}/${analysis}_fcCorrelationThresh
benchMatdist[${cxt}]=${outdir}/${analysis}_distance
###################################################################
# Obtain paths to all localised design files.
###################################################################
cohort=$(cat ${path_cohort} 2>/dev/null)
for subject in ${cohort}
   do
   subjid=$subject
   remfield=$subject
   iter=0
   while [[ ! -z ${remfield} ]]
      do
      curfield=$(echo ${remfield}|cut -d"," -f1)
      remfield=$(echo ${remfield}|sed s@^[^,]*@@)
      remfield=$(echo ${remfield}|sed s@^,@@)
      subject[${iter}]=${curfield}
      iter=$(expr ${iter} + 1)
   done
   nfield=${iter}
   source ${design}
   designs="${designs} ${out}/${prefix}.dsn"
done
###################################################################
# Prime the group design file so that any outputs from this
# module appear beneath the correct header.
###################################################################
echo "" >> $design_group
echo "# *** outputs from benchmark[${cxt}] *** #" >> $design_group
echo "" >> $design_group
###################################################################
###################################################################
# END GENERAL MODULE HEADER
###################################################################
###################################################################





###################################################################
# Obtain the list of parcellations, and cycle through them.
# confcor indicates whether the confound file has been re-ordered.
###################################################################
rm -f ${outbase}confound
pars=$(grep -i '^#' ${benchmark_lib[${cxt}]})
confcor=0
for par in ${pars}
   do
   set +x
   ################################################################
   # Note that there is an involuntary cleanup step at the
   # beginning here.
   ################################################################
   parName=$(echo $par|cut -d"#" -f2)
   parPath=$(echo $par|cut -d"#" -f3)
   parName=$(eval echo ${parName})
   parPath=$(eval echo ${parPath})
   parPath=$(ls -d1 ${parPath} 2>/dev/null)
   ################################################################
   # Cycle through subjects. Obtain, for each, a list comprising:
   # * prefix identifiers
   # * path to adjacency matrix
   # * motion value
   # * modularity quality
   # * a priori specificity (within/between)
   ################################################################
   rm -f ${outbase}subjects
   for dsn in ${designs}
      do
      [[ ! -e ${dsn} ]] \
         && echo "${dsn} missing" \
         && echo "" >> ${outbase}subjects \
         && continue
      source ${dsn}
      net=$(grep -i '#NM,'${parName}'#' ${out}/${prefix}_networks)
      adjmat=$(echo ${net}\
         |sed s@'#'@'\n'@g\
         |grep -i '^AM,'\
         |cut -d',' -f2)
      motion=${mcdir[${subjidx}]}/${prefix}_relMeanRMS.txt
      motion=$(cat ${motion})
      pfx=$(echo ${prefix}|sed s@'_'@' '@g)
      apr=$(echo ${adjmat}\
         |rev\
         |cut -d'_' -f2-\
         |rev)
      modq=$(ls -d1 ${apr}_apriori_quality.txt)
      wbspec=$(ls -d1 ${apr}_apriori_specOverall.txt)
      modq=$(cat ${modq})
      wbspec=$(cat ${wbspec})
      #############################################################
      # Ensure that subject order in the confound list conforms to
      # that in the cohort.
      #
      # This only need be done once, regardless of the number of
      # networks, so the confcor flag should be turned on to
      # minimise redundancy.
      #############################################################
      if [[ -e ${benchmark_confmat[${cxt}]} ]] \
         && [[ $confcor == 0 ]]
         then
         q=$(cat ${benchmark_confmat[${cxt}]})
         for f in ${pfx}
            do
            q=$(echo "${q}"|grep ${f})
         done
         echo "${q}" >> ${outbase}confound
      fi
      pfx=$(echo ${prefix}|sed s@'_'@','@g)
      echo ${pfx},${adjmat},${motion},${wbspec},${modq} >> ${outbase}subjects
   done
   confcor=1
   [[ -e ${outbase}confound ]] \
      && benchmark_confmat[${cxt}]=${outbase}confound
   source ${design_group}
   
   
   
   
   set -x
   ################################################################
   # Build the edgewise FC correlation matrix.
   # Pass in confounds if they have been provided.
   ################################################################
   rm -f ${outbase}quality
   [[ -e ${benchmark_confmat[${cxt}]} ]] \
      && confound="-a ${benchmark_confmat[${cxt}]}"
   ${XCPEDIR}/utils/mocor.R \
      -c ${outbase}subjects \
      -s ${benchmark_sig[${cxt}]} \
      -n ${parName} \
      ${confound} \
      -o ${benchMat[${cxt}]}_${parName} \
      -r ${benchMatthr[${cxt}]}_${parName} \
      -f ${benchMat[${cxt}]}_${parName} \
      -q ${outbase}quality





   ################################################################
   # Obtain the centres of mass for each network node.
   ################################################################
   rm -f ${outbase}cmass.sclib
   ${XCPEDIR}/utils/cmass.R \
      -r ${parPath} \
      >> ${outbase}cmass.sclib





   ################################################################
   # Build the edgewise distance matrix.
   ################################################################
   rm -f ${benchMatdist[${cxt}]}_${parName}
   ${XCPEDIR}/utils/lib2mat.R \
      -c ${outbase}cmass.sclib \
      >> ${benchMatdist[${cxt}]}_${parName}





   ################################################################
   # Compute the overall correlation between distance and motion
   # effects to infer distance-dependence of motion effects.
   ################################################################
   rm -f ${outbase}quality2
   echo distDependMotion >> ${outbase}quality2
   ${XCPEDIR}/utils/simil.R \
      -i ${benchMatdist[${cxt}]}_${parName},${benchMat[${cxt}]}_${parName} \
      -l 'Inter-node distance (mm),FC-motion correlation (r)' \
      -f ${outdir}/${analysis}_distDepend_${parName}.svg \
      |cut -d' ' -f2 \
      |head -n1 \
      >> ${outbase}quality2





   ################################################################
   # Community structure: closeness of the community partition to
   # an a priori standard.
   ################################################################





   ################################################################
   # Community structure: quality of the data-driven partition.
   ################################################################





   ################################################################
   # Collate all benchmarks for the current network.
   ################################################################
   rm -f ${outdir}/${analysis}_${parName}_quality
   qvars=$(head -n1 ${outbase}quality|sed s@'"'@@g|sed s@'\t'@','@g),$(head -n1 ${outbase}quality2)
   qvars=$(echo ${qvars}|sed s@','@' '@g)
   unset qvn
   for qv in ${qvars}
      do
      qv=${qv}_${parName}
      [[ -n ${qvn} ]] && qvn=${qvn},${qv}
      [[ -z ${qvn} ]] && qvn=${qv}
   done
   qvars=${qvn}
   qvals=$(tail -n1 ${outbase}quality|sed s@'"'@@g|sed s@'\t'@','@g),$(tail -n1 ${outbase}quality2)
   echo ${qvars} >> ${outdir}/${analysis}_${parName}_quality
   echo ${qvals} >> ${outdir}/${analysis}_${parName}_quality
done





###################################################################
# Estimate the number of degrees of freedom lost.
###################################################################





###################################################################
# If desired, iterate through subjects to produce rug plots for
# exemplars.
###################################################################
scount=0
for dsn in ${designs}
   do
   set +x
   ################################################################
   # If plots have been produced for at least as many subjects as
   # requested, then stop producing them.
   ################################################################
   [[ ${scount} -ge ${benchmark_nsubj[${cxt}]} ]] && break
   [[ ! -e ${dsn} ]] \
      && echo "${dsn} missing" \
      && continue
   source ${dsn}
   img=${out}/${prefix}
   imgpath=$(ls ${img}.*)
   for i in ${imgpath}
      do
      [[ $(imtest ${i}) == 1 ]] && imgpath=${i} && break
   done
   ext=$(echo ${imgpath}|sed s@${img}@@g)
   ################################################################
   # If the segmentation is to be used to classify voxels, then
   # move it into the same coordinate space as the subject image.
   ################################################################
   set -x
   if [[ $(imtest ${benchmark_mask[${cxt}]}) == 1 ]]
      then
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
      #############################################################
      # Move the segmentation from subject structural space to
      # subject EPI space. If the BOLD timeseries is already
      # standardised, then instead move it to standard space.
      #############################################################
      rm -f ${outbase}seg${ext}
      if [[ "${space}" == "standard" ]]
         then
         ${ANTSPATH}/antsApplyTransforms \
            -i ${benchmark_mask[${cxt}]} \
            -o ${outbase}seg${ext} \
            -r ${template} \
            -n NearestNeighbor \
            ${rigid} \
            ${affine} \
            ${warp} \
            ${resample}
      else
         ${ANTSPATH}/antsApplyTransforms \
            -i ${benchmark_mask[${cxt}]} \
            -o ${outbase}seg${ext} \
            -r ${referenceVolumeBrain[${subjidx}]}${ext} \
            -n NearestNeighbor \
            -t ${struct2seq[${subjidx}]}
      fi
      benchmark_mask[${cxt}]=${outbase}seg${ext}
   fi
   ################################################################
   # Prepare a rug plot for the example subject.
   ################################################################
   [[ $(imtest ${benchmark_mask[${cxt}]}) == 0 ]] \
      && benchmark_mask[${cxt}]=${mask[${subjidx}]}
   ${XCPEDIR}/utils/voxts.R \
      -i ${imgpath} \
      -r ${benchmark_mask[${cxt}]} \
      -t ${relrms[${subjidx}]} \
      -f ${outdir}/${analysis}_${prefix}_voxTS.png
   ################################################################
   # Increment the number of complete subjects.
   ################################################################
   scount=$(expr ${scount} + 1)
done









###################################################################
# Clean up intermediate files.
###################################################################
if [[ ${benchmark_cleanup[${cxt}]} == Y ]]
   then
   rm -f ${outdir}/*~TEMP~*
fi
