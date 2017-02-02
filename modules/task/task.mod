#!/usr/bin/env bash

###################################################################
#  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  #
###################################################################

###################################################################
# Constants
###################################################################

readonly SIGMA=2.35482004503
readonly POSINT='^[0-9]+$'





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
echo "###################################################################"
echo "#  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  #"
echo "#                                                                 #"
echo "#  ☭             EXECUTING TASK ACTIVATION MODULE              ☭  #"
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
if [[ ! -e ${task_design[${cxt}]} ]]
   then
   echo "::XCP-ERROR: The task activation module requires a "
   echo "  FEAT design file (.fsf) to complete, but the FEAT "
   echo "  design file is undefined or absent."
   exit 666
fi
###################################################################
# Create a directory for intermediate outputs.
###################################################################
[[ ${NUMOUT} == 1 ]] && prep=${cxt}_
outdir=${out}/${prep}task
[[ ! -e ${outdir} ]] && mkdir -p ${outdir}
echo "Output directory is $outdir"
###################################################################
# Define paths to all potential outputs.

# For the task module, potential outputs include:
#  * fsf : The FSL GLM design file, in .fsf format.
#  * referenceVolume : an example volume extracted from EPI data,
#    typically one of the middle volumes, though another may be
#    selected if the middle volume is corrupted by motion-related
#    noise; this is used as the reference volume during motion
#    correction
#  * meanIntensity : the mean intensity over time of functional data,
#    after it has been realigned with the example volume
#  * mcdir : the directory containing motion correction output
#  * rps : the 6 realignment parameters computed in the motion
#    correction procedure
#  * relrms : relative root mean square motion, computed in the
#    motion correction procedure
#  * relmeanrms : mean relative RMS motion, computed in the
#    motion correction procedure
#  * absrms : absolute root mean square displacement, computed in
#    the motion correction procedure
#  * absmeanrms : mean absolute RMS displacement, computed in the
#    motion correction procedure
#  * rmat : a directory containing rigid transforms applied to each
#    volume in order to realign it with the reference volume
###################################################################
task_fsf[${cxt}]=${outdir}/model/design.fsf
referenceVolume[${cxt}]=${outdir}/${prefix}_referenceVolume
mask[${cxt}]=${outdir}/${prefix}_mask
referenceVolumeBrain[${cxt}]=${outdir}/${prefix}_referenceVolumeBrain
meanIntensity[${cxt}]=${outdir}/${prefix}_meanIntensity
meanIntensityBrain[${cxt}]=${outdir}/${prefix}_meanIntensityBrain
mcdir[${cxt}]=${outdir}/mc
rps[${cxt}]=${outdir}/mc/${prefix}_realignment.1D
relrms[${cxt}]=${outdir}/mc/${prefix}_rel_rms.1D
relmeanrms[${cxt}]=${outdir}/mc/${prefix}_rel_mean_rms.txt
absrms[${cxt}]=${outdir}/mc/${prefix}_abs_rms.1D
absmeanrms[${cxt}]=${outdir}/mc/${prefix}_abs_mean_rms.txt
rmat[${cxt}]=${outdir}/mc/${prefix}.mat
confmat[${cxt}]=${outdir}/${prefix}_confmat.1D
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
img=${outdir}/${prefix}~TEMP~
if [[ $(imtest ${img}) != "1" ]] \
   || [[ "${regress_rerun[${cxt}]}" == "Y" ]]
   then
   rm -f ${img}
   ln -s ${out}/${prefix}${ext} ${img}${ext}
fi
imgpath=$(ls ${img}${ext})
###################################################################
# Parse quality variables.
###################################################################
qvars=$(head -n1 ${quality} 2>/dev/null)
qvals=$(tail -n1 ${quality} 2>/dev/null)
###################################################################
# Prime the localised design file so that any outputs from this
# module appear beneath the correct header.
###################################################################
echo "" >> $design_local
echo "# *** outputs from task[${cxt}] *** #" >> $design_local
echo "" >> $design_local
###################################################################
# Verify that the module should be run:
#  * Test whether the final output already exists.
#  * Determine whether the user requested the module to be re-run.
# If it is determined that the module should not be run, then any
#  outputs must be written to the local design file.
###################################################################



###################################################################
###################################################################
# END GENERAL MODULE HEADER
###################################################################
###################################################################





###################################################################
# Localise the FSL design file.
###################################################################
mkdir -p ${outdir}/model
cp -f ${task_design[${cxt}]} ${task_fsf[${cxt}]}





###################################################################
# Iterate through all fields and substitute.
###################################################################
numfield=$(echo ${#subject[@]})
curidx=0
while [[ ${curidx} -lt ${numfield} ]]
   do
   curfield=${subject[${curidx}]}
   search=~XID${curidx}
   sed s@${search}@${curfield}@g ${task_fsf[${cxt}]} \
      >> ${task_fsf[${cxt}]}~TEMP~
   mv -f ${task_fsf[${cxt}]}~TEMP~ ${task_fsf[${cxt}]}
   curidx=$(expr ${curidx} + 1)
done
###################################################################
# Substitute the output directory variable so that it points to
# the module output.
###################################################################
sed s@'set fmri(outputdir).*'@'set fmri(outputdir) '${img}@g \
   ${task_fsf[${cxt}]} >> ${task_fsf[${cxt}]}~TEMP~
mv -f ${task_fsf[${cxt}]}~TEMP~ ${task_fsf[${cxt}]}
###################################################################
# Substitute the standard variable so that it points to the
# template.
###################################################################
sed s@'set fmri(regstandard).*'@'set fmri(regstandard) '${template}@g \
   ${task_fsf[${cxt}]} >> ${task_fsf[${cxt}]}~TEMP~
mv -f ${task_fsf[${cxt}]}~TEMP~ ${task_fsf[${cxt}]}
###################################################################
# Substitute the feat_files variable so that it points to the
# BOLD timeseries.
###################################################################
sed s@'set feat_files(1).*'@'set feat_files(1) '${img}@g \
   ${task_fsf[${cxt}]} >> ${task_fsf[${cxt}]}~TEMP~
mv -f ${task_fsf[${cxt}]}~TEMP~ ${task_fsf[${cxt}]}
###################################################################
# Substitute the highres_files variable so that it points to the
# structural image.
###################################################################
sed s@'set highres_files(1).*'@'set highres_files(1) '${struct[${subjidx}]}@g \
   ${task_fsf[${cxt}]} >> ${task_fsf[${cxt}]}~TEMP~
mv -f ${task_fsf[${cxt}]}~TEMP~ ${task_fsf[${cxt}]}
###################################################################
# Substitute the alternative variables so that they point to the
# appropriate images (if prestats is performed in XCP rather than
# as part of the FSL procedure).
###################################################################
sed s@'set fmri(alternative_example_func).*'@'set fmri(alternative_example_func) "'${referenceVolume[${subjidx}]}'"'@g \
   ${task_fsf[${cxt}]} >> ${task_fsf[${cxt}]}~TEMP~
mv -f ${task_fsf[${cxt}]}~TEMP~ ${task_fsf[${cxt}]}
sed s@'set fmri(alternative_mask).*'@'set fmri(alternative_mask) "'${mask[${subjidx}]}'"'@g \
   ${task_fsf[${cxt}]} >> ${task_fsf[${cxt}]}~TEMP~
mv -f ${task_fsf[${cxt}]}~TEMP~ ${task_fsf[${cxt}]}
###################################################################
# Determine whether confound EVs must be imported from the XCP
# Engine.
###################################################################
confincl=$(grep -i 'set fmri(confoundevs)' ${task_fsf[${cxt}]}\
   |rev\
   |cut -d' ' -f1\
   |rev)
###################################################################
# Some FEAT files may not contain this option by default. If they
# do not, attempt to add it. This may be unstable.
###################################################################
confopt=$(grep -i 'set confoundev_files' ${task_fsf[${cxt}]})
if [[ ${confincl} == 1 ]] && [[ ${confopt} == 1 ]]
   then
   sed s@'set confoundev_files(1).*'@'set confoundev_files(1) '${rps[${subjidx}]}@g \
      ${task_fsf[${cxt}]} >> ${task_fsf[${cxt}]}~TEMP~
   mv -f ${task_fsf[${cxt}]}~TEMP~ ${task_fsf[${cxt}]}
elif [[ ${confincl} == 1 ]] && [[ ${confopt} == 0 ]]
   then
   sed s@'set fmri(confoundevs).*'@'set fmri(confoundevs) 1\n\n# Confound EVs text file for analysis 1\nset confoundev_files(1) '${rps[${subjidx}]}@g \
      ${task_fsf[${cxt}]} >> ${task_fsf[${cxt}]}~TEMP~
   mv -f ${task_fsf[${cxt}]}~TEMP~ ${task_fsf[${cxt}]}
fi
###################################################################
# Substitute the tr variable so that it contains the correct
# repetition time.
###################################################################
trep=$(fslval ${img} pixdim4|sed s@' '@@g)
sed s@'set fmri(tr).*'@'set fmri(tr) '${trep}@g \
   ${task_fsf[${cxt}]} >> ${task_fsf[${cxt}]}~TEMP~
mv -f ${task_fsf[${cxt}]}~TEMP~ ${task_fsf[${cxt}]}
###################################################################
# Substitute the npts variable so that it contains the correct
# number of data points
###################################################################
nvol=$(fslval ${img} dim4|sed s@' '@@g)
sed s@'set fmri(npts).*'@'set fmri(npts) '${nvol}@g \
   ${task_fsf[${cxt}]} >> ${task_fsf[${cxt}]}~TEMP~
mv -f ${task_fsf[${cxt}]}~TEMP~ ${task_fsf[${cxt}]}





###################################################################
# Execute analysis in FEAT. Deactivate autosubmission before
# calling FEAT, and reactivate after FEAT is complete.
###################################################################
echo ""; echo ""; echo ""
echo "Current processing step:"
echo "Executing analysis in FEAT"
if [[ -z $(ls ${outdir}/*.feat 2>/dev/null)  \
   && $(imtest ${outdir}/${prefix}_preprocessed) != 1 ]] \
   || [[ ${task_rerun[${cxt}]} == Y ]]
   then
   rm -rf ${outdir}/*.feat
   buffer=${SGE_ROOT}
   unset SGE_ROOT
   feat ${task_fsf[${cxt}]}
   SGE_ROOT=${buffer}
fi





###################################################################
# Reorganise the FEAT output.
###################################################################
echo "Reorganising output"
featout=$(ls -d1 ${outdir}/*.feat 2>/dev/null)
[[ -z ${featout} ]] && featout=${outdir}

###################################################################
# * Mask
###################################################################
if [[ $(imtest ${featout}/mask) == 1 ]]
   then
   immv ${featout}/mask ${mask[${cxt}]}
fi
if [[ $(imtest ${mask[${cxt}]}) == 1 ]]
   then
   echo "mask[${subjidx}]=${mask[${cxt}]}" >> $design_local
   echo "#mask#${mask[${cxt}]}" >> ${auxImgs[${subjidx}]}
fi

###################################################################
# * Example functional image
###################################################################
if [[ $(imtest ${featout}/example_func) == 1 ]]
   then
   immv ${featout}/example_func ${referenceVolume[${cxt}]}
fi
if [[ $(imtest ${referenceVolume[${cxt}]}) == 1 ]]
   then
   echo "referenceVolume[${subjidx}]=${referenceVolume[${cxt}]}" \
      >> $design_local
   echo "#referenceVolume#${referenceVolume[${cxt}]}" >> ${auxImgs[${subjidx}]}
fi
###################################################################
# * Brain-extracted
###################################################################
if [[ $(imtest ${referenceVolumeBrain[${cxt}]}) != 1 ]]
   then
   fslmaths ${referenceVolume[${cxt}]} \
      -mul ${mask[${cxt}]} \
      ${referenceVolumeBrain[${cxt}]}
fi
if [[ $(imtest ${referenceVolumeBrain[${cxt}]}) == 1 ]]
   then
   echo "referenceVolumeBrain[${subjidx}]=${referenceVolumeBrain[${cxt}]}" \
      >> $design_local
   echo "#referenceVolumeBrain#${referenceVolumeBrain[${cxt}]}" >> ${auxImgs[${subjidx}]}
fi

###################################################################
# * Mean functional image
###################################################################
if [[ $(imtest ${featout}/mean_func) == 1 ]]
   then
   immv ${featout}/mean_func ${meanIntensity[${cxt}]}
fi
if [[ $(imtest ${meanIntensity[${cxt}]}) == 1 ]]
   then
   echo "meanIntensity[${subjidx}]=${meanIntensity[${cxt}]}" \
      >> $design_local
   echo "#meanIntensity#${meanIntensity[${cxt}]}" >> ${auxImgs[${subjidx}]}
fi
###################################################################
# * Brain-extracted
###################################################################
if [[ $(imtest ${meanIntensityBrain[${cxt}]}) != 1 ]]
   then
   fslmaths ${meanIntensity[${cxt}]} \
      -mul ${mask[${cxt}]} \
      ${meanIntensityBrain[${cxt}]}
fi
if [[ $(imtest ${meanIntensityBrain[${cxt}]}) == 1 ]]
   then
   echo "meanIntensityBrain[${subjidx}]=${meanIntensityBrain[${cxt}]}" \
      >> $design_local
   echo "#meanIntensityBrain#${meanIntensityBrain[${cxt}]}" >> ${auxImgs[${subjidx}]}
fi

###################################################################
# * Confound timeseries
###################################################################
if [[ -e ${featout}/confoundevs.txt ]]
   then   
   mv -f ${featout}/confoundevs.txt ${confmat[${cxt}]}
   echo "confmat[${subjidx}]=${confmat[${cxt}]}" >> $design_local
fi

###################################################################
# * Motion variables
###################################################################
if [[ -e ${featout}/mc/ ]]
   then
   mkdir -p ${mcdir[${cxt}]}
   [[ -n $(ls ${featout}/mc/*mcf.par) ]] \
      && mv -f ${featout}/mc/*mcf.par  ${rps[${cxt}]}
   [[ -n $(ls ${featout}/mc/*rel.rms) ]] \
      && mv -f ${featout}/mc/*rel.rms  ${relrms[${cxt}]}
   [[ -n $(ls ${featout}/mc/*rel_mean.rms) ]] \
      && mv -f ${featout}/mc/*rel_mean.rms ${relmeanrms[${cxt}]}
   [[ -n $(ls ${featout}/mc/*abs.rms) ]] \
      && mv -f ${featout}/mc/*abs.rms  ${absrms[${cxt}]}
   [[ -n $(ls ${featout}/mc/*abs_mean.rms) ]] \
      && mv -f ${featout}/mc/*abs_mean.rms  ${absmeanrms[${cxt}]}
   [[ -n $(ls ${featout}/mc/*.mat) ]] \
      && mv -f ${featout}/mc/*.mat ${rmat[${cxt}]}
   [[ -n $(ls ${featout}/mc/*.png) ]] \
      && mv -f ${featout}/mc/*.png ${mcdir[${cxt}]}
fi
if [[ -e ${rps[${cxt}]} ]]
   then
   echo "mcdir[${subjidx}]=${mcdir[${cxt}]}" >> $design_local
   echo "rps[${subjidx}]=${rps[${cxt}]}" >> $design_local
   echo "relrms[${subjidx}]=${relrms[${cxt}]}" >> \
      $design_local
   qvars=${qvars},rel_mean_rms_motion
	qvals="${qvals},$(cat ${relmeanrms[${cxt}]})"
fi

###################################################################
#  * FEAT design and model
###################################################################
if [[ -n $(ls ${featout}/design* 2>/dev/null) ]]
   then
   mv -f ${featout}/design* ${outdir}/model/
fi

###################################################################
#  * Logs
###################################################################
if [[ -d ${featout}/logs ]]
   then
   mv -f ${featout}/logs ${outdir}/logs
   mv -f ${featout}/report_log.html ${outdir}/logs
fi

###################################################################
#  * Parameter estimates
###################################################################
echo " * Parameter estimates"
penames=$(grep -i 'evtitle' ${task_fsf[${cxt}]}\
   |cut -d' ' -f3-\
   |sed s@'"'@@g\
   |sed s@' '@'_'@g\
   |sed s@'\.'@','@g)
pederiv=$(grep -i "deriv_yn" ${task_fsf[${cxt}]}\
   |cut -d' ' -f3)
pemag=$(grep -i "PPheights" ${outdir}/model/design.mat\
   |sed s@'^.*PPheights'@@g)
rm -f ${outdir}/model/magnitude_pe.txt
for mag in ${pemag}
   do
   echo ${mag} >> ${outdir}/model/magnitude_pe.txt
done
echo "${penames}" >> ${outdir}/~TEMP~names
echo "${pederiv}" >> ${outdir}/~TEMP~deriv

if [[ -n $(ls ${featout}/stats/pe* 2>/dev/null) ]]
   then
   mkdir -p ${outdir}/pe
   mkdir -p ${outdir}/sigchange
   deriv=0
   fidx=1
   paramest=$(ls -d1 ${featout}/stats/pe*${ext})
   npes=$(echo "${paramest}"|wc -l)
   cidx=1
   while [[ ${cidx} -le ${npes} ]]
      do
      pe=$(echo "${paramest}"|grep -i 'pe'${cidx}${ext})
      mag=$(sed "${cidx}q;d" ${outdir}/model/magnitude_pe.txt)
      if [[ ${deriv} == 0 ]]
         then
         cname=$(sed "${fidx}q;d" ${outdir}/~TEMP~names)
         deriv=$(sed "${fidx}q;d" ${outdir}/~TEMP~deriv)
         [[ -z ${cname} ]] && cname=confound && deriv=0
         immv ${pe} ${outdir}/pe/${prefix}_pe${cidx}_${cname}
         fidx=$(expr ${fidx} + 1)
         ##########################################################
         # Convert raw PE to percent signal change.
         ##########################################################
         fslmaths ${outdir}/pe/${prefix}_pe${cidx}_${cname} \
            -mul ${mag} \
            -mul 100 \
            -div ${meanIntensity[${cxt}]} \
            ${outdir}/sigchange/${prefix}_pe${cidx}_${cname}
      else
         immv ${pe} ${outdir}/pe/${prefix}_pe${cidx}_${cname}_tderiv
         deriv=0
         ##########################################################
         # Convert raw PE to percent signal change.
         ##########################################################
         fslmaths ${outdir}/pe/${prefix}_pe${cidx}_${cname}_tderiv \
            -mul ${mag} \
            -mul 100 \
            -div ${meanIntensity[${cxt}]} \
            ${outdir}/pe/${prefix}_pe${cidx}_${cname}_tderiv
      fi
      cidx=$(expr ${cidx} + 1)
   done
   rm -f ${outdir}/~TEMP~names ${outdir}/~TEMP~deriv
fi

###################################################################
#  * Contrasts of parameter estimates
###################################################################
echo " * Contrasts"
copenames=$(grep -i 'conname_real' ${task_fsf[${cxt}]}\
   |cut -d' ' -f3-\
   |sed s@'"'@@g\
   |sed s@' '@'_'@g\
   |sed s@'\.'@','@g)
copemag=$(grep -i "PPheights" ${outdir}/model/design.con\
   |sed s@'^.*PPheights'@@g)
rm -f ${outdir}/model/magnitude_cope.txt
for mag in ${copemag}
   do
   echo ${mag} >> ${outdir}/model/magnitude_cope.txt
done
echo "${copenames}" >> ${outdir}/~TEMP~names

if [[ -n $(ls ${featout}/stats/cope* 2>/dev/null) ]]
   then
   mkdir -p ${outdir}/cope
   mkdir -p ${outdir}/sigchange
   contrasts=$(ls -d1 ${featout}/stats/cope*${ext})
   for cope in ${contrasts}
      do
      cidx=$(basename $cope|sed s@'^cope'@@g|sed s@${ext}@@g)
      cname="$(sed "${cidx}q;d" ${outdir}/~TEMP~names)"
      mag=$(sed "${cidx}q;d" ${outdir}/model/magnitude_cope.txt)
      immv ${cope} ${outdir}/cope/${prefix}_cope${cidx}_${cname}
      #############################################################
      # Convert raw contrast to percent signal change.
      #############################################################
      fslmaths ${outdir}/cope/${prefix}_cope${cidx}_${cname} \
         -mul ${mag} \
         -mul 100 \
         -div ${meanIntensity[${cxt}]} \
         ${outdir}/sigchange/${prefix}_cope${cidx}_${cname}
      echo "#cope${cidx}_${cname}#${outdir}/cope/${prefix}_cope${cidx}_${cname}" \
         >> ${auxImgs[${subjidx}]}
      echo "#sigchange_cope${cidx}_${cname}#${outdir}/sigchange/${prefix}_cope${cidx}_${cname}#task,${cxt}" \
         >> ${auxImgs[${subjidx}]}
   done
else
   contrasts=$(ls -d1 ${outdir}/cope/${prefix}_cope*${ext})
   for cope in ${contrasts}
      do
      cidx=$(basename $cope|sed s@'^.*cope'@@g|sed s@'_.*$'@@g)
      cname=$(basename $cope|cut -d'.' -f1|sed s@'^'"${prefix}".*cope[0-9]*_*@@g)
      echo "#cope${cidx}_${cname}#${outdir}/cope/${prefix}_cope${cidx}_${cname}" \
         >> ${auxImgs[${subjidx}]}
      echo "#sigchange_cope${cidx}_${cname}#${outdir}/sigchange/${prefix}_cope${cidx}_${cname}#task,${cxt}" \
         >> ${auxImgs[${subjidx}]}
   done
fi

###################################################################
#  * VarCoPEs
###################################################################
echo " * Uncertainty terms"
if [[ -n $(ls ${featout}/stats/varcope* 2>/dev/null) ]]
   then
   mkdir -p ${outdir}/varcope
   varcopes=$(ls -d1 ${featout}/stats/varcope*${ext})
   for varcope in ${varcopes}
      do
      cidx=$(basename $varcope|sed s@'^varcope'@@g|sed s@${ext}@@g)
      cname="$(sed "${cidx}q;d" ${outdir}/~TEMP~names)"
      immv ${varcope} ${outdir}/varcope/${prefix}_varcope${cidx}_${cname}
      echo "#varcope${cidx}_${cname}#${outdir}/varcope/${prefix}_varcope${cidx}_${cname}" \
         >> ${auxImgs[${subjidx}]}
   done
else
   varcopes=$(ls -d1 ${outdir}/varcope/${prefix}_varcope*${ext})
   for varcope in ${varcopes}
      do
      cidx=$(basename $varcope|sed s@'^.*varcope'@@g|sed s@'_.*$'@@g)
      cname=$(basename $varcope|cut -d'.' -f1|sed s@'^'"${prefix}".*varcope[0-9]*_*@@g)
      echo "#varcope${cidx}_${cname}#${outdir}/varcope/${prefix}_varcope${cidx}_${cname}" \
         >> ${auxImgs[${subjidx}]}
   done
fi

###################################################################
#  * Other statistical maps
###################################################################
if [[ -d ${featout}/stats/ ]]
   then
   mkdir -p ${outdir}/${prefix}_stats
   mv ${featout}/stats/* ${outdir}/${prefix}_stats/
fi

###################################################################
#  * Processed image
###################################################################
if [[ $(imtest ${featout}/filtered_func_data) == 1 ]]
   then
   immv ${featout}/filtered_func_data ${outdir}/${prefix}_preprocessed
fi
if [[ $(imtest ${outdir}/${prefix}_preprocessed) == 1 ]]
   then
   rm -f ${out}/${prefix}${ext}
   ln -s ${outdir}/${prefix}_preprocessed${ext} ${out}/${prefix}${ext}
fi
echo "Processing step complete"
echo "Task analysis"





###################################################################
# CLEANUP
#  * Remove any temporary files if cleanup is enabled.
#  * Update the audit file to reflect completion of the module.
###################################################################
img=$(readlink -f ${img}${ext})
if [[ "${task_cleanup[${cxt}]}" == "Y" ]]
   then
   echo ""; echo ""; echo ""
   echo "Cleaning up..."
   rm -rf ${outdir}/*~TEMP~*
fi
rm -f ${quality}
echo ${qvars} >> ${quality}
echo ${qvals} >> ${quality}
prefields=$(echo $(grep -o "_" <<< $prefix|wc -l) + 1|bc)
modaudit=$(expr ${prefields} + ${cxt} + 1)
subjaudit=$(grep -i $(echo ${prefix}|sed s@'_'@','@g) ${audit})
replacement=$(echo ${subjaudit}\
   |sed s@[^,]*@@${modaudit}\
   |sed s@',,'@',1,'@ \
   |sed s@',$'@',1'@g)
sed -i s@${subjaudit}@${replacement}@g ${audit}

echo "Module complete"
