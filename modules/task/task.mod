#!/usr/bin/env bash

###################################################################
#  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  #
###################################################################

###################################################################
# SPECIFIC MODULE HEADER
# This module runs an FSL design for task activation statistics.
###################################################################
mod_name_short=task
mod_name='TASK-CONSTRAINED ACTIVATION MODULE'
mod_head=${XCPEDIR}/core/CONSOLE_MODULE_RC

###################################################################
# GENERAL MODULE HEADER
###################################################################
source ${XCPEDIR}/core/constants
source ${XCPEDIR}/core/functions/library.sh
source ${XCPEDIR}/core/parseArgsMod

###################################################################
# MODULE COMPLETION
###################################################################
completion() {
   processed         processed
   
   write_derivative  meanIntensity
   write_derivative  meanIntensityBrain
   write_derivative  referenceVolume
   write_derivative  referenceVolumeBrain
   write_derivative  mask
   
   write_output      mcdir
   write_output      rps
   write_output      rel_rms
   write_output      fd
   
   for i in ${!cpe[@]}
      do
      write_derivative  contrast${i}_${cpe[i]}
      write_derivative  sigchange_contrast${i}_${cpe[i]}
      write_derivative  varcope${i}_${cpe[i]}
   done
   if is_image ${referenceVolumeBrain[cxt]}
      then
      space_config   ${spaces[sub]}   ${space[sub]} \
               Map   ${referenceVolumeBrain[cxt]}
   fi
   
   quality_metric    relMeanRMSMotion        rel_mean_rms
   quality_metric    relMaxRMSMotion         rel_max_rms
   quality_metric    nFramesHighMotion       motion_vols
   
   source ${XCPEDIR}/core/auditComplete
   source ${XCPEDIR}/core/updateQuality
   source ${XCPEDIR}/core/moduleEnd
}





###################################################################
# OUTPUTS
###################################################################
derivative  referenceVolume         ${prefix}_referenceVolume
derivative  referenceVolumeBrain    ${prefix}_referenceVolumeBrain
derivative  meanIntensity           ${prefix}_meanIntensity
derivative  meanIntensityBrain      ${prefix}_meanIntensityBrain
derivative  mask                    ${prefix}_mask

output      confmat                 ${prefix}_confmat.1D
output      fsf                     model/${prefix}_design.fsf
output      mcdir                   mc
output      rps                     mc/${prefix}_realignment.1D
output      abs_rms                 mc/${prefix}_absRMS.1D
output      abs_mean_rms            mc/${prefix}_absMeanRMS.txt
output      rel_rms                 mc/${prefix}_relRMS.1D
output      rel_max_rms             mc/${prefix}_relMaxRMS.txt
output      rel_mean_rms            mc/${prefix}_relMeanRMS.txt
output      rmat                    mc/${prefix}.mat
output      fd                      mc/${prefix}_fd.1D
output      motion_vols             mc/${prefix}_nFramesHighMotion.txt

final       processed               ${prefix}_processed

<< DICTIONARY

abs_mean_rms
   The absolute RMS displacement, averaged over all volumes.
abs_rms
   Absolute root mean square displacement.
confmat
   A 1D file containing all global nuisance timeseries for the
   current subject, including any user-specified timeseries
   and previous time points, derivatives, and powers.
contrast
   Contrasts of parameter estimates.
fd
   Framewise displacement values, computed as the absolute sum of
   realignment parameter first derivatives.
fsf
   The design file for FEAT analysis in FSL.
mcdir
   The directory containing motion realignment output.
mask
   A spatial mask of binary values, indicating whether a voxel
   should be analysed as part of the brain; the definition of brain
   tissue is often fairly liberal.
meanIntensity
   The mean intensity over time of functional data, after it has
   been realigned to the example volume
motion_vols
   A quality control file that specifies the number of volumes that
   exceeded the maximum motion criterion. If censoring is enabled,
   then this will be the same number of volumes that are to be
   censored.
processed
   The final output of the module, indicating its successful
   completion.
referenceVolume
   An example volume extracted from EPI data, typically one of the
   middle volumes, though another may be selected if the middle
   volume is corrupted by motion-related noise. This is used as the
   reference volume during motion realignment.
rel_max_rms
   The maximum single-volume value of relative RMS displacement.
rel_mean_rms
   The relative RMS displacement, averaged over all volumes.
rel_rms
   Relative root mean square displacement.
rmat
   A directory containing rigid transforms applied to each volume
   in order to realign it with the reference volume
rps
   Framewise values of the 6 realignment parameters.
sigchange_contrast
   Contrasts of parameter estimates, converted to percentage
   signal change.
varcope
   The variance in each contrast of parameter estimates.

DICTIONARY





###################################################################
# Localise the FSL design file.
###################################################################
routine                       @1    Localising FEAT design
exec_sys mkdir -p ${outdir}/model
printx            ${task_design[cxt]} >> ${intermediate}-fsf.dsn
mapfile           fsf_design           < ${intermediate}-fsf.dsn





###################################################################
# Variable import and search:
# Substitute the relevant lines of text in the design file.
# OUT: The FEAT output directory
# STD: The template for normalisation (please turn this off)
# REF: The reference volume
# MSK: The mask
# CON: Boolean value indicating whether to import confounds
# TRP: The repetition time
# NVO: The number of volumes
# IMG: The BOLD time series
# HRS: The structural image
# COF: The imported confounds
# PAR: The explanatory variables
# TDX: Boolean value indicating whether to include temporal deriv
# CPE: Contrasts of the explanatory variables
###################################################################
subroutine                    @1.1a Importing analysis variables
subroutine                    @1.1b Parsing design and contrasts
for l in "${!fsf_design[@]}"
   do
   line="${fsf_design[l]}"
   
   chk_OUT=( "${line}"        'set fmri\(outputdir\)'       )
   chk_STD=( "${line}"        'set fmri\(regstandard\)'     )
   chk_REF=( "${line}"        'set fmri\(alternative_example_func\)')
   chk_MSK=( "${line}"        'set fmri\(alternative_mask\)')
   chk_CON=( "${line}"        'set fmri\(confoundevs\)'     )
   chk_TRP=( "${line}"        'set fmri\(tr\)'              )
   chk_NVO=( "${line}"        'set fmri\(npts\)'            )
   chk_IMG=( "${line}"        'set feat_files\(1\)'         )
   chk_HRS=( "${line}"        'set highres_files\(1\)'      )
   chk_COF=( "${line}"        'set confoundev_files\(1\)'   )
   chk_PAR=( "${line}"        'set fmri\(evtitle'           )
   chk_TDX=( "${line}"        'set fmri\(deriv_yn'          )
   chk_CPE=( "${line}"        'set fmri\(conname_real'      )
   
   contains  "${chk_PAR[@]}" \
             && line=${line//set fmri\(evtitle/} \
             && indx=${line/%\)*/}  \
             && name=${line#*\"}    \
             && name=${name//\"/}   \
             && name=${name// /_}   \
             && par[indx]=${name//\./_} \
             && continue
   contains  "${chk_CPE[@]}" \
             && line=${line//set fmri\(conname_real\./} \
             && indx=${line/%\)*/}  \
             && name=${line#*\"}    \
             && name=${name//\"/}   \
             && name=${name// /_}   \
             && cpe[indx]=${name//\./_} \
             && continue
   contains  "${chk_TDX[@]}" \
             && line=${line//set fmri\(deriv_yn/} \
             && indx=${line/%\)*/}  \
             && name=${line#*\ }    \
             && tdx[indx]=${name//\"/} \
             && continue
   
   contains  "${chk_OUT[@]}" \
             && fsf_design[l]='set fmri(outputdir) '${intermediate}'-feat\n' \
             && continue
   contains  "${chk_STD[@]}" \
             && fsf_design[l]='set fmri(regstandard) '${template}'\n' \
             && continue
   contains  "${chk_IMG[@]}" \
             && fsf_design[l]='set feat_files(1) '${img}'\n' \
             && continue
   contains  "${chk_REF[@]}" \
             && fsf_design[l]='set fmri(alternative_example_func) "'${referenceVolume[sub]}'"\n' \
             && continue
   contains  "${chk_MSK[@]}" \
             && fsf_design[l]='set fmri(alternative_mask) "'${mask[sub]}'"\n' \
             && continue
   contains  "${chk_TRP[@]}" \
             && fsf_design[l]='set fmri(tr) '${trep}'\n' \
             && continue
   contains  "${chk_NVO[@]}" \
             && fsf_design[l]='set fmri(npts) '${nvol}'\n' \
             && continue
   contains  "${chk_HRS[@]}" \
             && fsf_design[l]='set highres_files(1) '${struct[sub]}'\n' \
             && continue
   contains  "${chk_CON[@]}" \
             && coni=${l} \
             && conf_include=${line//set fmri(confoundevs) /} \
             && continue
   contains  "${chk_COF[@]}" \
             && conf=${l} \
             && continue
done
if (( ${conf_include} == 1 ))
   then
   subroutine                 @1.2  Importing confounds
   if is+numeric ${conf}
      then
      subroutine              @1.2.1
      fsf_design[conf]='set confoundev_files(1) '${rps[sub]}'\n'
   else
      subroutine              @1.2.2
      fsf_design[coni]='set fmri(confoundevs) 1\n\n# Confound EVs text file for analysis 1\nset confoundev_files(1) '${rps[sub]}'\n'
   fi
fi
printf      "${fsf_design[@]}"                      >>  ${fsf[cxt]}
routine_end





###################################################################
# Declare each contrast and % signal change map as a derivative.
###################################################################
for i in ${!cpe[@]}
   do
   derivative  contrast${i}_${cpe[i]} \
               contrasts/${prefix}_contrast${i}_${cpe[i]}
   derivative  sigchange_contrast${i}_${cpe[i]} \
               sigchange/${prefix}_sigchange_contrast${i}_${cpe[i]}
   derivative  varcope${i}_${cpe[i]} \
               varcopes/${prefix}_varcope${i}_${cpe[i]}
   derivative_config sigchange_contrast${i}_${cpe[i]} \
               Statistic      mean
done





###################################################################
# Execute analysis in FEAT. Deactivate autosubmission before
# calling FEAT, and reactivate after FEAT is complete.
###################################################################
routine                       @2    Executing FEAT analysis
if ! is_image ${processed[cxt]} \
|| rerun
   then
   subroutine                 @2.1  Preparing environment
   buffer=${SGE_ROOT}
   unset    SGE_ROOT
   exec_sys rm -rf            ${intermediate}-feat*
   subroutine                 @2.2a Processing FEAT design:
   subroutine                 @2.2b ${fsf[cxt]}
   exec_fsl feat              ${fsf[cxt]}
   SGE_ROOT=${buffer}
fi
routine_end





###################################################################
# Reorganise the FEAT output.
###################################################################
featout=$(ls -d1 ${intermediate}-feat* 2>/dev/null)





if [[ -d ${featout} ]]
   then
   routine                    @3    Reorganising FEAT output
   ################################################################
   # * Image localisation
   ################################################################
   exec_fsl immv ${featout}/mask                ${mask[cxt]}
   exec_fsl immv ${featout}/example_func.nii.gz ${referenceVolume[cxt]}
   exec_fsl immv ${featout}/mean_func.nii.gz    ${meanIntensity[cxt]}
   ################################################################
   # * Brain extraction
   ################################################################
   if ! is_image ${referenceVolumeBrain[cxt]}
      then
      subroutine              @3.1  Extracting reference brain
      exec_fsl fslmaths ${referenceVolume[cxt]} \
         -mul  ${mask[cxt]} \
         ${referenceVolumeBrain[cxt]}
   fi
   if ! is_image ${meanIntensityBrain[cxt]}
      then
      subroutine              @3.2  Extracting mean brain
      exec_fsl fslmaths ${meanIntensity[cxt]} \
         -mul  ${mask[cxt]} \
         ${meanIntensityBrain[cxt]}
   fi

   ################################################################
   # * Confound time series
   ################################################################
   if [[ -s ${featout}/confoundevs.txt ]]
      then
      subroutine              @3.3
      exec_sys mv -f ${featout}/confoundevs.txt    ${confmat[cxt]}
   fi

   ################################################################
   # * Motion variables
   ################################################################
   if [[ -e ${featout}/mc/ ]]
      then
      subroutine              @3.4  Re-localising motion metrics
      exec_sys mkdir -p ${mcdir[cxt]}
      exec_sys mv -f ${featout}/mc/mcf.par         ${rps[cxt]}
      exec_sys mv -f ${featout}/mc/*rel.rms        ${relrms[cxt]}
      exec_sys mv -f ${featout}/mc/*rel_mean.rms   ${relmeanrms[cxt]}
      exec_sys mv -f ${featout}/mc/*abs.rms        ${absrms[cxt]}
      exec_sys mv -f ${featout}/mc/*abs_mean.rms   ${absmeanrms[cxt]}
      exec_sys mv -f ${featout}/mc/*.mat           ${rmat[cxt]}
      exec_sys mv -f ${featout}/mc/*.png           ${mcdir[cxt]}
      exec_xcp 1dTool.R \
         -i    ${rel_rms[cxt]} \
         -o    max \
         -f    ${rel_max_rms[cxt]}
      exec_xcp fd.R \
         -r    ${rps[cxt]} \
         -o    ${fd[cxt]}
      exec_xcp tmask.R \
         -s    ${!censor_criterion} \
         -t    ${censor_threshold} \
         -o    ${intermediate}-tmask.1D \
         -m    ${prestats_censor_contig[cxt]}
      censor_ts=$(  echo               $(<${intermediate}-tmask.1D))
      n_spikes=$(ninstances 0             ${censor_ts// /})
      echo  ${n_spikes}             >> ${motion_vols[cxt]}
   fi

   ################################################################
   #  * FEAT design and model
   ################################################################
   subroutine                 @3.5  Re-localising model design
   exec_sys    mv -f ${featout}/design*            ${outdir}/model/

   ################################################################
   #  * Logs
   ################################################################
   if [[ -d ${featout}/logs ]]
      then
      subroutine              @3.6
      exec_sys mv -f ${featout}/logs               ${outdir}/logs
      exec_sys mv -f ${featout}/report_log.html    ${outdir}/logs
   fi
   routine_end

   ################################################################
   # Process the parameter estimates and compute percent signal
   # change.
   ################################################################
   routine                    @4    Processing parameter estimates
   
   subroutine                 @4.1  Obtaining peak magnitudes: PEs
   while read -r line
      do
      chk_MAG=( "${line}"           '/PPheights'   )
      contains  "${chk_MAG[@]}"     && break
   done                       <     ${outdir}/model/design.mat
   mag=(        ${line}       )
   unset        mag[0]

   if [[ -n $(ls ${featout}/stats/pe* 2>/dev/null) ]]
      then
      subroutine              @4.2  Raw parameter estimates
      exec_sys                mkdir -p ${outdir}/pe
      exec_sys                mkdir -p ${outdir}/sigchange
      paramest=( $(exec_sys ls -d1 ${featout}/stats/pe*.nii.gz) )
      #############################################################
      # is_dx indicates whether the next PE is a derivative
      # fidx is the PE index according to the FSF file
      # cidx is the PE index according to the output
      # npes is the total number of PEs in the output
      #############################################################
      is_dx=0
      fidx=1
      npes=${#paramest[@]}
      #############################################################
      # Loop over parameter estimates.
      #############################################################
      for (( cidx=1; cidx <= ${npes}; cidx++ ))
         do
         par_out=${outdir}/pe/${prefix}_pe${cidx}
         psc_out=${outdir}/sigchange/${prefix}_pe${cidx}
         pe=${featout}/stats/pe${cidx}.nii.gz
         subroutine           @4.3
         ##########################################################
         # FEAT creates parameter estimates in the order:
         # (1) Each parameter estimate, followed by its derivative
         #     if deriv_yn was set to 1
         # (2) Confounds
         # Decide whether the current PE is a temporal derivative.
         ##########################################################
         if (( ${is_dx} == 0 ))
            then
            subroutine        @4.4
            #######################################################
            # Store deriv_yn in is_dx so that the conditional can
            # determine whether the next PE is a derivative.
            #######################################################
            is_dx=${tdx[fidx]}
            cname=${par[fidx]}
            par_pe=${par_out}_${cname}.nii.gz
            psc_pe=${par_out}_${cname}.nii.gz
            par_dx=${par_out}_${cname}_tderiv.nii.gz
            psc_dx=${psc_out}_${cname}_tderiv.nii.gz
            [[ -z ${cname}  ]] && cname=confound && is_dx=0
            
            exec_fsl immv     ${pe} ${par_pe}
            #######################################################
            # Convert raw PE to percent signal change.
            #######################################################
            exec_fsl fslmaths ${par_pe} \
               -mul  ${mag[cidx]} \
               -mul  100 \
               -div  ${meanIntensity[cxt]} \
               ${psc_pe}
            (( fidx++ ))
            
         else
            subroutine        @4.5
            exec_fsl immv     ${pe} ${par_dx}
            is_dx=0
            #######################################################
            # Convert raw PE to percent signal change.
            #######################################################
            exec_fsl fslmaths ${par_dx} \
               -mul  ${mag[cidx]} \
               -mul  100 \
               -div  ${meanIntensity[cxt]} \
               ${psc_dx}
         fi
      done
   fi

   ################################################################
   # Contrasts of parameter estimates
   ################################################################
   subroutine                 @4.6  Obtaining peak magnitudes: contrasts
   unset  mag
   while read -r  line
      do
      chk_MAG=(   "${line}"           '/PPheights'   )
      contains    "${chk_MAG[@]}"     && break
   done                       <     ${outdir}/model/design.con
   mag=(          ${line}       )
   unset          mag[0]

   if [[ -n $(ls ${featout}/stats/cope* 2>/dev/null) ]]
      then
      subroutine              @4.7  Contrasts
      exec_sys                mkdir -p ${outdir}/cope
      exec_sys                mkdir -p ${outdir}/sigchange
      #############################################################
      # Loop over contrasts.
      #############################################################
      for i in ${!cpe[@]}
         do
         subroutine           @4.8  ${cpe[i]}
         con_i=${featout}/stats/cope${i}
         var_i=${featout}/stats/varcope${i}
         con_o='contrast'${i}'_'${cpe[i]}'['${cxt}']'
         var_o='varcope'${i}'_'${cpe[i]}'['${cxt}']'
         psc_o='sigchange_contrast'${i}'_'${cpe[i]}'['${cxt}']'
         exec_fsl immv        ${!con_i} ${!con_o}
         exec_fsl immv        ${!var_i} ${!var_o}
         ##########################################################
         # Convert raw contrast to percent signal change.
         ##########################################################
         exec_fsl fslmaths    ${!con_o} \
            -mul  ${mag[cidx]} \
            -mul  100 \
            -div  ${meanIntensity[cxt]} \
            ${!psc_o}
      done
   fi

   ###################################################################
   # Other statistical maps
   ###################################################################
   if [[ -d ${featout}/stats/ ]]
      then
      subroutine              @4.9
      exec_sys mkdir -p ${outdir}/${prefix}_stats
      mv ${featout}/stats/* ${outdir}/${prefix}_stats/
   fi

   ###################################################################
   # Finish the module with the processed image
   ###################################################################
   if is_image ${featout}/filtered_func_data.nii.gz
      then
      subroutine              @4.10
      immv ${featout}/filtered_func_data.nii.gz ${processed[cxt]}
   fi
   routine_end
fi





completion
