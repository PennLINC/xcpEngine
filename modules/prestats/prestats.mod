#!/usr/bin/env bash

###################################################################
#  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  #
###################################################################

###################################################################
# SPECIFIC MODULE HEADER
# This module preprocesses fMRI data.
###################################################################
mod_name_short=prestats
mod_name='FMRI PREPROCESSING MODULE'
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
   processed         final
   
   write_derivative  meanIntensity
   write_derivative  meanIntensityBrain
   write_derivative  referenceVolume
   write_derivative  referenceVolumeBrain
   write_derivative  mask
   
   write_output      mcdir
   write_output      rps
   write_output      rel_rms
   write_output      fd
   write_output      tmask
   
   write_config_safe censor
   if is_1D ${tmask[${cxt}]}
      then
      configure      censored       1
      write_config   censored
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

output      aux_imgs                ${prefix}_derivs
output      mcdir                   mc
output      rps                     mc/${prefix}_realignment.1D
output      abs_rms                 mc/${prefix}_absRMS.1D
output      abs_mean_rms            mc/${prefix}_absMeanRMS.txt
output      rel_rms                 mc/${prefix}_relRMS.1D
output      rel_max_rms             mc/${prefix}_relMaxRMS.txt
output      rel_mean_rms            mc/${prefix}_relMeanRMS.txt
output      rmat                    mc/${prefix}.mat
output      fd                      mc/${prefix}_fd.1D
output      tmask                   mc/${prefix}_tmask.1D
output      motion_vols             mc/${prefix}_${prestats_censor_cr[${cxt}]}_nvolFailQA.txt

configure   censor                  $(return_field ${prestats_censor[${cxt}]} 1)
configure   censored                0

if [[ -n    ${censor[${subjidx}]} ]]
   then
   configure   censor               ${censor[${subjidx}]}
fi
if [[ -n    ${censored[${subjidx}]} ]]
   then
   configure   censored             ${censored[${subjidx}]}
fi

process     final                   ${prefix}_preprocessed

<< DICTIONARY

abs_mean_rms
   The absolute RMS displacement, averaged over all volumes.
abs_rms
   Absolute root mean square displacement.
aux_imgs
   A path to an index of derivative images, after they have been
   processed by this module; this is necessary only if smoothing or
   temporal filtering is included
censor
   A set of instructions specifying the type of censoring to be
   performed in the current pipeline: 'none', 'iter[ative]', or
   'final'. This instruction is passed to the regress module,
   which handles the censoring protocol.
censored
   A variable that specifies whether censoring has been primed in
   the current module.
fd
   Framewise displacement values, computed as the absolute sum of
   realignment parameter first derivatives.
final
   The final output of the module, indicating its successful
   completion.
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
tmask
   A temporal mask of binary values, indicating whether the volume
   survives motion censorship.
   
DICTIONARY










###################################################################
# The variable 'buffer' stores the processing steps that are
# already complete; it becomes the expected ending for the final
# image name and is used to verify that prestats has completed
# successfully.
###################################################################
unset buffer

subroutine                    @0.1

###################################################################
# Parse the processing code to determine what analysis to run next.
# Current options include:
#  * DVO: discard volumes
#  * MPR: compute motion-related variables, including RPs
#  * MCO: correct for subject motion
#  * STM: slice timing correction
#  * BXT: brain extraction
#  * DMT: demean and detrend timeseries
#  * DSP: despike timeseries
#  * SPT: spatial filter
#  * TMP: temporal filter
###################################################################
rem=${prestats_process[${cxt}]}
while (( ${#rem} > 0 ))
   do
   ################################################################
   # * Extract the first three letters from the user-specified
   #   processing command. 
   # * This three-letter code determines what analysis is run
   #   next.
   # * Remove them from the list of remaining analyses.
   ################################################################
   cur=${rem:0:3}
   rem=${rem:3:${#rem}}
   buffer=${buffer}_${cur}
   case ${cur} in
      
      
      
      
      
      DVO)
         ##########################################################
         # DVO discards the first n volumes of the scan, as
         # specified by user input.
         #
         # If dvols is positive, discard the first n volumes
         # from the BOLD timeseries.
         # If dvols is negative, discard the last n volumes
         # from the BOLD timeseries.
         ##########################################################
         routine              @1    Discarding ${prestats_dvols[${cxt}]} volumes
         if ! is_image ${intermediate}_${cur}.nii.gz \
         || rerun
            then
            nvol=$(exec_fsl fslnvols ${intermediate}.nii.gz)
            subroutine        @1.1  [Total original volumes = ${nvol}]
            if is+integer ${prestats_dvols[${cxt}]}
               then
               subroutine     @1.2  [Discarding initial volumes]
               vol_begin=${prestats_dvols[${cxt}]}
               vol_end=$(( ${nvol} - ${prestats_dvols[${cxt}]} ))
            elif is_integer ${prestats_dvols[${cxt}]}
               then
               subroutine     @1.3  [Discarding final volumes]
               vol_begin=0
               vol_end=$(( ${nvol} + ${prestats_dvols[${cxt}]} ))
            fi
            subroutine        @1.4  [Primary analyte image]
            exec_fsl \
               fslroi ${intermediate}.nii.gz \
               ${intermediate}_${cur}.nii.gz \
               ${vol_begin} \
               ${vol_end}
         fi
         ##########################################################
         # Repeat for any derivatives of the BOLD timeseries, if
         # they contain the same number of volumes as the original
         # timeseries.
         #
         # Why? Unless the number of volumes in the BOLD timeseries
         # and in derivative timeseries -- for instance, local
         # regressors -- is identical, any linear model
         # incorporating the derivatives as predictors would
         # introduce a frameshift error; this may result in
         # incorrect estimates or even a failure to compute parameter
         # estimates for the model.
         #
         # In many cases, discarding of initial volumes represents
         # the first stage of fMRI processing. In these cases,
         # the derivatives index will be empty, and the prestats
         # module should never enter the conditional block below.
         ##########################################################
         load_derivatives
         for derivative in ${derivatives}
            do
            derivative_parse ${derivative}
            if [[ ${d_type} == timeseries ]]
               then
               subroutine     @1.5  [${d_name}]
               exec_fsl \
                  fslroi ${d_map} \
                  ${outdir}/${prefix}_${d_name} \
                  ${vol_begin} \
                  ${vol_end}
               derivative        ${d_name}   ${prefix}_${d_name}
               write_derivative  ${d_name}
            else
               subroutine     @1.6
            fi
         done
         ##########################################################
         # Compute the updated volume count.
         ##########################################################
         intermediate=${intermediate}_${cur}
         nvol=$(exec_fsl fslnvols ${intermediate}.nii.gz)
         subroutine           @1.7  [New total volumes = ${nvol}]
         routine_end
         ;;
      
      
      
      
      
      MPR)
         ##########################################################
         # MPR computes motion-related variables, such as
         # realignment parameters and framewise displacement.
         #
         # Prime the analytic pipeline for motion censoring, if
         # the user has requested it.
         #
         # Why is this step separate from motion correction?
         #  * Recent analyses have suggested that correction for
         #    slice timing can introduce error into motion
         #    parameter estimates.
         #  * Therefore, it is desirable to compute realignment
         #    parameters prior to slice timing correction.
         #  * However, slice timing correction should probably be
         #    performed on data that has not undergone realignment,
         #    since realignment will move brain regions into slices
         #    different from the ones in which they were acquired.
         #  * Therefore, the recommended processing order is:
         #    MPR STM MCO
         #
         # This step introduces a degree of redundancy to pipelines
         # that do not include slice timing correction.
         ##########################################################
         routine              @2    Computing realignment parameters
         ##########################################################
         # Determine whether a reference functional image already
         # exists. If it does not, extract it from the timeseries
         # midpoint for use as a reference in realignment.
         ##########################################################
         if ! is_image ${referenceVolume[${cxt}]} \
         || rerun
            then
            subroutine        @2.1  [Extracting reference volume]
            nvol=$(exec_fsl fslnvols ${intermediate}.nii.gz)
            midpt=$(( ${nvol} / 2))
            exec_fsl \
               fslroi ${intermediate}.nii.gz \
               ${referenceVolume[${cxt}]} \
               ${midpt} 1
         fi
         if ! is_image ${intermediate}_${cur}.nii.gz \
         || rerun
            then
            #######################################################
            # Run MCFLIRT targeting the reference volume to compute
            # the realignment parameters.
            #
            # Output is temporarily placed into the main prestats
            # module output directory; it will be moved into the
            # MC directory.
            #######################################################
            subroutine        @2.2  [Computing realignment parameters]
            exec_fsl \
               mcflirt -in ${intermediate}.nii.gz \
               -out ${intermediate}_mc \
               -plots \
               -reffile ${referenceVolume[${cxt}]} \
               -rmsrel \
               -rmsabs \
               -spline_final
            #######################################################
            # Create the MC directory, and move outputs to their
            # targets.
            #
            # For relative root mean square motion, prepend a
            # value of 0 by convention for the first volume.
            # FSL may change its pipeline in the future so that
            # it automatically does this. If this occurs, then
            # this must be changed.
            #######################################################
            subroutine        @2.3
            exec_sys rm -rf ${mcdir[${cxt}]}
            exec_sys mkdir -p ${mcdir[${cxt}]}
            exec_sys mv -f ${intermediate}_mc.par \
               ${rps[${cxt}]}
            exec_sys mv -f ${intermediate}_mc_abs_mean.rms \
               ${abs_mean_rms[${cxt}]}
            exec_sys mv -f ${intermediate}_mc_abs.rms \
               ${abs_rms[${cxt}]}
            exec_sys mv -f ${intermediate}_mc_rel_mean.rms \
               ${rel_mean_rms[${cxt}]}
            exec_sys rm -f ${relrms[${cxt}]}
            exec_sys echo 0                         >> ${rel_rms[${cxt}]}
            exec_sys cat ${intermediate}_mc_rel.rms >> ${rel_rms[${cxt}]}
            #######################################################
            # Compute the maximum value of motion.
            #######################################################
            subroutine        @2.4
            exec_xcp \
               1dTool.R \
               -i ${rel_rms[${cxt}]} \
               -o max \
               -f ${rel_max_rms[${cxt}]}
            #######################################################
            # Generate summary plots for motion correction.
            #######################################################
            subroutine        @2.5  [Preparing summary plots]
            subroutine      @2.5.1  [1/3]
            exec_fsl fsl_tsplot -i ${rps[${cxt}]} \
               -t 'MCFLIRT_estimated_rotations_(radians)' \
               -u 1 --start=1 --finish=3 \
               -a x,y,z \
               -w 640 \
               -h 144 \
               -o ${mcdir[${cxt}]}/rot.png
            subroutine      @2.5.2  [2/3]
            exec_fsl fsl_tsplot -i ${rps[${cxt}]} \
               -t 'MCFLIRT_estimated_translations_(mm)' \
               -u 1 --start=4 --finish=6 \
               -a x,y,z \
               -w 640 \
               -h 144 \
               -o ${mcdir[${cxt}]}/trans.png
            subroutine      @2.5.3  [3/3]
            exec_fsl fsl_tsplot \
               -i "${abs_rms[${cxt}]},${rel_rms[${cxt}]}" \
               -t 'MCFLIRT_estimated_mean_displacement_(mm)' \
               -u 1 \
               -w 640 \
               -h 144 \
               -a 'absolute,relative' \
               -o ${mcdir[${cxt}]}/disp.png
            #######################################################
            # Compute framewise displacement using the realignment
            # parameters.
            #######################################################
            subroutine        @2.6  [Computing framewise displacement]
            exec_xcp fd.R \
               -r ${rps[${cxt}]} \
               -o ${fd[${cxt}]}
            if [[ ${prestats_censor_cr[${cxt}]} == fd ]]
               then
               subroutine     @2.7  [Quality criterion: FD]
               censor_criterion='fd['${cxt}']'
            elif [[ ${prestats_censor_cr[${cxt}]} == rms ]]
               then
               subroutine     @2.8  [Quality criterion: RMS]
               censor_criterion='rel_rms['${cxt}']'
            fi
            #######################################################
            # Determine whether motion censoring is enabled. If it
            # is, then prepare to create a temporal mask indicating
            # whether each volume survives censoring.
            #
            # Before creating a temporal mask, ensure that
            # censoring has not already been primed in the course
            # of this analysis.
            #  * It is critical that this step only be performed
            #    once in the course of each analysis.
            #  * If censoring has already been primed, then the
            #    type of censoring requested will be stored in one
            #    of the variables: censor[cxt] or censor[subjidx]
            #######################################################
            censor_threshold=$(return_field ${prestats_censor[${cxt}]} 2)
            if (( ${censored[${cxt}]} != 1 ))
               then
               subroutine     @2.9  [Applying motion threshold to volumes]
               ####################################################
               # Create and write the temporal mask.
               # Use the criterion dimension and threshold
               # specified by the user to determine whether each
               # volume should be masked out.
               ####################################################
               exec_xcp \
                  tmask.R \
                  -s ${!censor_criterion} \
                  -t ${censor_threshold} \
                  -o ${tmask[${cxt}]} \
                  -m ${prestats_censor_contig[${cxt}]}
               configure      censored    1
               ####################################################
               # Determine the number of volumes that fail the
               # motion criterion and print this.
               ####################################################
               subroutine        @2.10 [Evaluating data quality]
               num_censor=$(exec_sys cat ${tmask[${cxt}]} \
                  |grep -o 0 \
                  |wc -l)
               echo ${num_censor} >> ${motion_vols[${cxt}]}
            fi
            exec_sys rm -f ${referenceVolume[${cxt}]}
         fi # run check statement
         ##########################################################
         # * Remove the motion corrected image: this step should
         #   only compute parameters, not use them.
         # * Discard realignment transforms, since they are not
         #   used in this step.
         # * Symlink to the previous image in the chain so that
         #   the final check can verify that this step completed
         #   successfully.
         # * Update the image pointer.
         ##########################################################
         exec_sys rm -f ${intermediate}_${cur}.nii.gz
         exec_sys rm -rf ${intermediate}_mc*.mat
         exec_sys ln -s ${intermediate}.nii.gz ${intermediate}_${cur}.nii.gz
         intermediate=${intermediate}_${cur}
         routine_end
         ;;
      
      
      
      
      
      MCO)
         ##########################################################
         # MCO computes the realignment parameters and uses them
         # to realign all volumes to the reference.
         #
         # MPR is intended to be run prior to slice timing
         # correction, and MCO after slice timing correction.
         ##########################################################
         routine              @3    Realigning functional volumes
         if ! is_image ${referenceVolume[${cxt}]} \
         || rerun
            then
            subroutine        @3.1  [Extracting reference volume]
            nvol=$(exec_fsl fslnvols ${intermediate}.nii.gz)
            #######################################################
            # If the framewise displacement has not been
            # calculated, then use the timeseries midpoint as the
            # reference volume.
            #######################################################
            if ! is_1D ${fd[${cxt}]}
               then
               subroutine     @3.2
               midpt=$(( ${nvol} / 2 ))
               exec_fsl \
                  fslroi ${intermediate}.nii.gz \
                  ${referenceVolume[${cxt}]} \
                  ${midpt} 1
            #######################################################
            # Otherwise, use the volume with minimal framewise
            # displacement.
            #######################################################
            else
               subroutine     @3.3
               vol_min_fd=$(exec_xcp \
                  1dTool.R -i ${fd[${cxt}]} -o which_min -r T)
               exec_fsl \
                  fslroi ${intermediate}.nii.gz \
                  ${referenceVolume[${cxt}]} \
                  ${vol_min_fd} 1
            fi
         fi
         ##########################################################
         # Create the motion correction directory if it does not
         # already exist.
         ##########################################################
         exec_sys mkdir -p ${mcdir[${cxt}]}
         exec_sys mkdir -p ${rmat[${cxt}]}
         ##########################################################
         # Verify that this step has not already completed; if it
         # has, then an associated image should exist.
         ##########################################################
         if ! is_image ${intermediate}_${cur}.nii.gz \
         || rerun
            then
            subroutine        @3.4  [Executing motion realignment]
            exec_fsl \
               mcflirt -in ${intermediate}.nii.gz \
               -out ${intermediate}_mc \
               -mats \
               -reffile ${referenceVolume[${cxt}]} \
               -spline_final
         fi
         ##########################################################
         # Realignment transforms are always retained from this
         # step and discarded from MPR.
         ##########################################################
         [[ -e ${intermediate}_mc*.mat ]] && exec_sys \
            mv -f ${intermediate}_mc*.mat \
            ${rmat[${cxt}]}
         ##########################################################
         # Update image pointer
         ##########################################################
         exec_fsl immv ${intermediate}_mc.nii.gz ${intermediate}_${cur}.nii.gz
         intermediate=${intermediate}_${cur}
         routine_end
         ;;
      
      
      
      
      
      STM)
         ##########################################################
         # STM corrects images for timing of slice acquisition
         # based upon user input.
         ##########################################################
         routine              @4    Slice timing correction
         subroutine           @4.1a Acquisition: ${prestats_stime[${cxt}]}
         subroutine           @4.1b Acquisition axis: ${prestats_sdir[${cxt}]}
         if ! is_image ${intermediate}_${cur}.nii.gz \
         || rerun
            then
            st_perform=1
            #######################################################
            # Read in the acquisition axis; translate axes from
            # common names to FSL terminology.
            #######################################################
            case "${prestats_sdir[${cxt}]}" in 
            X)
               subroutine     @4.2a
               sdir=1
               ;;
            Y)
               subroutine     @4.2b
               sdir=2
               ;;
            Z)
               subroutine     @4.2c
               sdir=3
               ;;
            *)
               sdir=3 # set default so as to prevent errors
               subroutine     @4.2d Slice timing correction:
               subroutine     @4.2e Unrecognised acquisition axis/direction:
               subroutine     @4.2f ${prestats_sdir[${cxt}]}
               ;;
            esac
            #######################################################
            # Read in the direction of acquisition to determine
            # the order in which slices were acquired.
            #######################################################
            unset st_arguments
            case "${prestats_stime[${cxt}]}" in
            up)
               subroutine     @4.3
               ;;
            down)
               subroutine     @4.4
               st_arguments='--down'
               ;;
            interleaved)
               subroutine     @4.5
               st_arguments='--odd'
               ;;
            custom)
               subroutine     @4.6
               st_custom_time=${prestats_stime_tpath[${cxt}]}
               st_custom_order=${prestats_stime_opath[${cxt}]}
               ####################################################
               # If you are using both a custom order file and a
               # custom timing file, then congratulations -- you've
               # broken the pipeline. Just select one.
               #
               # The call is still here, but should it become
               # active, the very fabric of the world will unravel.
               ####################################################
               if [[ "${prestats_stime_order[${cxt}]}" == "true" ]]
                  then
                  subroutine  @4.6.1
                  st_arguments="${st_arguments} -ocustom ${st_custom_order}"
               fi
               if [[ "${prestats_stime_timing[${cxt}]}" == "true" ]]
                  then
                  subroutine  @4.6.2
                  st_arguments="${st_arguments} -tcustom ${st_custom_time}"
               fi
               ;;
            none)
               ####################################################
               # If you are entering this code, you may as well
               # have removed STM from your pipeline. But I sure
               # made that sound quite scary, didn't I?
               ####################################################
               st_perform=0
               ;;
            *)
               subroutine     @4.7  Unrecognised option ${prestats_stime[${cxt}]}
               st_perform=0
               ;;
            esac
            if (( ${st_perform} == 1 ))
               then
               subroutine     @4.8
               exec_fsl \
                  slicetimer \
                  -i ${intermediate}.nii.gz \
                  -o ${intermediate}_${cur}.nii.gz \
                  -d $st_direction \
                  ${st_arguments}
            else
               subroutine     @4.9
               exec_sys ln -s ${intermediate}.nii.gz ${intermediate}_${cur}.nii.gz
            fi
         fi # run check statement
         intermediate=${intermediate}_${cur}
         routine_end
         ;;
      
      
      
      
      
      BXT)
         ##########################################################
         # BXT computes a mask over the whole brain and excludes
         # non-brain voxels from further analyses.
         ##########################################################
         routine              @5    Brain extraction
         subroutine           @5.1  [Generating mean functional image]
         ##########################################################
         # Generate a mean functional image by averaging voxel
         # intensity over time. This mean functional image will be
         # used as the primary reference for establishing the
         # boundary between brain and background.
         ##########################################################
         exec_fsl fslmaths ${intermediate}.nii.gz -Tmean ${meanIntensity[${cxt}]}
         if ! is_image ${intermediate}_${cur}_1.nii.gz \
         || rerun
            then
            subroutine        @5.2a [Initialising brain extraction]
            subroutine        @5.2b [Fractional intensity threshold:]
            subroutine        @5.2c [${prestats_fit[${cxt}]}]
            #######################################################
            # Use BET to generate a preliminary mask. This should
            # be written out to the mask[cxt] variable.
            #######################################################
            exec_fsl \
               bet ${meanIntensity[${cxt}]} \
               ${outdir}/${prefix} \
               -f ${prestats_fit[${cxt}]} \
               -n \
               -m \
               -R
            exec_fsl immv ${outdir}/${prefix}.nii.gz ${meanIntensityBrain[${cxt}]}
            #######################################################
            # Additionally, prepare a brain-extracted version of
            # the example functional image; this will later be
            # necessary for coregistration of functional and
            # structural acquisitions.
            #######################################################
            if is_image ${referenceVolume[${subjidx}]}
               then
               subroutine     @5.3a
               bet ${referenceVolume[${subjidx}]} \
                  ${referenceVolumeBrain[${cxt}]} \
                  -f ${prestats_fit[${cxt}]}
            else
               subroutine     @5.3b
               bet ${referenceVolume[${cxt}]} \
                  ${referenceVolumeBrain[${cxt}]} \
                  -f ${prestats_fit[${cxt}]}
            fi
            subroutine        @5.4  [Initial estimate]
            #######################################################
            # Use the preliminary mask to extract brain tissue.
            #######################################################
            exec_fsl \
               fslmaths ${intermediate}.nii.gz \
               -mas ${mask[${cxt}]} \
               ${intermediate}_${cur}_1.nii.gz
         fi
         if ! is_image ${intermediate}_${cur}_2 \
         || rerun
            then
            subroutine        @5.5a [Thresholding and dilating image]
            subroutine        @5.5b [Brain-background threshold:]
            subroutine        @5.5c [${prestats_bbgthr[${cxt}]}]
            #######################################################
            # Use the user-specified brain-background threshold
            # to determine what parts of the image to count as
            # brain.
            #  * First, compute an image-specific threshold by
            #    multiplying the 98th percentile of image
            #    intensities by the brain-background threshold.
            #  * Next, use this image-specific threshold to obtain
            #    a binary mask from the volume computed in the
            #    first pass.
            #  * Then, dilate the binary mask.
            #  * Finally, use the new, dilated mask for the second
            #    pass of brain extraction.
            #######################################################
            perc_98=$(exec_fsl fslstats ${intermediate}.nii.gz -p 98)
            new_thresh=$(arithmetic ${perc_98}\*${prestats_bbgthr[${cxt}]})
            exec_fsl \
               fslmaths ${intermediate}_${cur}_1.nii.gz \
               -thr ${new_thresh} \
               -Tmin \
               -bin \
               ${mask[${cxt}]} \
               -odt char
            subroutine        @5.6
            exec_fsl fslmaths ${mask[${cxt}]} -dilF ${mask[${cxt}]}
            exec_fsl \
               fslmaths ${intermediate}.nii.gz \
               -mas ${mask[${cxt}]} \
               ${intermediate}_${cur}.nii.gz
         fi
         intermediate=${intermediate}_${cur}
         routine_end
         ;;
      
      
      
      
      
      DMT)
         ##########################################################
         # DMT removes the mean from a timeseries and additionally
         # removes polynomial trends up to an order specified by
         # the user.
         #
         # DMT uses a general linear model with y = 1 and all
         # polynomials as predictor variables, then retains the
         # residuals of the model as the processed timeseries.
         ##########################################################
         routine              @6    Demeaning and detrending BOLD timeseries
         if ! is_image ${intermediate}_${cur} \
         || rerun
            then
            #######################################################
            # DMT uses a utility R script called DMDT to compute
            # the linear model residuals using ANTsR and pracma.
            #
            # A spatial mask of the brain is necessary
            # for ANTsR to read in the image.
            #
            # If no mask has yet been computed for the subject,
            # then a new mask can be computed quickly using
            # AFNI's 3dAutomask tool.
            #######################################################
            if is_image ${mask[${subjidx}]}
               then
               subroutine     @6.1a [Using previously determined mask]
               mask_dmdt=${mask[${subjidx}]}
            elif is_image ${mask[${cxt}]}
               then
               subroutine     @6.1b [Using mask from this preprocessing run]
               mask_dmdt=${mask[${cxt}]}
            else
               subroutine     @6.2  [Generating a mask using 3dAutomask]
               exec_afni \
                  3dAutomask -prefix ${intermediate}_${cur}_mask.nii.gz \
                  -dilate 3 \
                  -q \
                  ${intermediate}.nii.gz
               mask_dmdt=${intermediate}_${cur}_mask.nii.gz
            fi
            #######################################################
            # If the user has requested iterative censoring of
            # motion-corrupted volumes, then the demean/detrend
            # step should exclude the corrupted volumes from the
            # linear model. In this case, a temporal mask is
            # required for the demean/detrend step.
            #
            # If iterative censoring has not been specified or
            # if no temporal mask exists yet, then all time
            # points must be used in the linear model.
            #######################################################
            subroutine        @6.3
            if is_1D ${tmask[${cxt}]} \
            && [[ ${censor[${cxt}]} == iter ]]
               then
               subroutine     @6.3.1
               tmask_dmdt=${tmask[${cxt}]}
            else
               subroutine     @6.3.2
               tmask_dmdt=ones
            fi
            #######################################################
            # AFNI's afni_proc.py pipeline uses a formula to
            # automatically determine an appropriate order of
            # polynomial detrend to apply to the data.
            #
            #        floor(1 + TR*nVOLS / 150)
            #
            # In summary, the detrend order is based upon the
            # overall duration of the scan.
            #######################################################
            if ! is+integer ${prestats_dmdt[${cxt}]}
               then
               subroutine     @6.4  [Estimating polynomial order]
               nvol=$(exec_fsl fslnvols ${intermediate}.nii.gz)
               trep=$(exec_fsl fslval   ${intermediate}.nii.gz pixdim4)
               dmdt_order=$(arithmetic 1 + ${trep}\*${nvol}/150)
               dmdt_order=$(return_field ${dmdt_order} 1 '.')
            else
               dmdt_order=${prestats_dmdt[${cxt}]}
            fi
            subroutine        @6.5  [Applying polynomial detrend]
            subroutine        @6.6  [Order: ${dmdt_order}]
            exec_xcp \
               dmdt.R \
               -d ${dmdt_order} \
               -i ${intermediate}.nii.gz \
               -m ${mask_dmdt} \
               -t ${tmask_dmdt} \
               -o ${intermediate}_${cur}.nii.gz
         fi
         intermediate=${intermediate}_${cur}
         routine_end
         ;;
      
      
      
      
      
      DSP)
         ##########################################################
         # DSP uses AFNI's 3dDespike to remove any intensity
         # outliers ("spikes") from the BOLD timeseries and to
         # interpolate over outlier epochs.
         ##########################################################
         routine              @7    Despiking BOLD timeseries
         if ! is_image ${intermediate}_${cur}.nii.gz \
         || rerun
            then
            subroutine        @7.1
            exec_sys rm -rf ${intermediate}_${cur}.nii.gz
            unset ds_arguments
            #######################################################
            # Determine whether to run new or old 3dDespike.
            # This is based on the number of volumes.
            # If the timeseries has more than 200 volumes,
            # the old method will be incredibly slow, so the
            # new method should be run.
            #######################################################
            nvol=$(exec_fsl fslnvols ${intermediate}.nii.gz)
            if (( ${nvol} >= 200 ))
               then
               subroutine     @7.2  [Long timeseries configuration]
               ds_arguments='-NEW'
            else
               subroutine     @7.3  [Short timeseries configuration]
            fi
            exec_afni \
               3dDespike \
               -prefix ${intermediate}_${cur}.nii.gz \
               -nomask \
               -quiet \
               ${ds_arguments} \
               ${intermediate}.nii.gz
         fi
         intermediate=${intermediate}_${cur}
         routine_end
         ;;
      
      
      
      
      
      SPT)
         ##########################################################
         # SPT applies a smoothing kernel to the image. It calls
         # the utility script sfilter, which is also used by a
         # number of other modules.
         ##########################################################
         routine              @8    Spatially filtering image
         ##########################################################
         # If no spatial filtering has been specified by the user,
         # then bypass this step.
         ##########################################################
         if [[ ${prestats_sptf[${cxt}]} == none ]]
            then
            subroutine        @8.1
            exec_sys ln -s ${intermediate}.nii.gz ${intermediate}_${cur}.nii.gz
         ##########################################################
         # Ensure that this step has not already run to completion
         # by checking for the existence of a smoothed image.
         ##########################################################
         elif ! is_image ${intermediate}_${cur}.nii.gz \
         || rerun
            then
            #######################################################
            # Obtain the mask over which smoothing is to be applied
            # Begin by searching for the subject mask; if this does
            # not exist, then search for a mask created by this
            # module.
            #
            # If prestats fails to find a mask, then generate one
            # using AFNI's 3dAutomask utility. This may not work
            # particularly well if the BOLD timeseries has already
            # been demeaned or detrended.
            #######################################################
            if is_image ${mask[${subjidx}]}
               then
               subroutine     @8.2
               mask_spt=${mask[${subjidx}]}
            elif is_image ${mask[${cxt}]}
               then
               subroutine     @8.3
               mask_spt=${mask[${cxt}]}
            else
               subroutine     @8.4  Generating a mask using 3dAutomask
               exec_afni \
                  3dAutomask -prefix ${intermediate}_${cur}_mask.nii.gz \
                  -dilate 3 \
                  -q \
                  ${intermediate}.nii.gz
               mask_spt=${intermediate}_${cur}_mask.nii.gz
            fi
            #######################################################
            # Prime the inputs to sfilter for SUSAN filtering
            #######################################################
            if [[ "${prestats_sptf[${cxt}]}" == susan ]]
               then
               if is_image ${referenceVolumeBrain[${subjidx}]}
                  then
                  subroutine  @8.5.1
                  usan="-u ${referenceVolumeBrain[${subjidx}]}"
               elif is_image ${referenceVolumeBrain[${cxt}]}
                  then
                  subroutine  @8.5.2
                  usan="-u ${referenceVolumeBrain[${cxt}]}"
               elif is_image ${referenceVolume[${subjidx}]}
                  then
                  subroutine  @8.5.3
                  usan="-u ${referenceVolume[${subjidx}]}"
               elif is_image ${referenceVolume[${cxt}]}
                  then
                  subroutine  @8.5.4
                  usan="-u ${referenceVolume[${cxt}]}"
               else
                  subroutine  @8.6a SUSAN requires a reference volume, and none
                  subroutine  @8.6b was located. Switching to UNIFORM smoothing.
                  ${prestats_sptf[${cxt}]}=uniform
                  write_output   prestats_sptf
               fi
            fi
            #######################################################
            # Engage the sfilter routine to filter the image.
            #  * This is essentially a wrapper around the three
            #    implemented smoothing routines: gaussian, susan,
            #    and uniform.
            #######################################################
            subroutine        @8.7a [Filter: ${prestats_sptf[${cxt}]}]
            subroutine        @8.7b [Smoothing kernel: ${prestats_smo[${cxt}]} mm]
            exec_xcp \
               sfilter \
               -i ${intermediate}.nii.gz \
               -o ${intermediate}_${cur}.nii.gz \
               -s ${prestats_sptf[${cxt}]} \
               -k ${prestats_smo[${cxt}]} \
               -m ${mask_spt} \
               ${usan} \
               ${trace_prop}
         fi
         intermediate=${intermediate}_${cur}
         routine_end
         ;;
      
      
      
      
      
      TMP)
         ##########################################################
         # TMP applies a temporal filter to:
         #  * the 4D BOLD timeseries
         #  * any derivative images that have the same number of
         #    volumes as the 4D timeseries
         #  * any 1D timeseries that might function as potential
         #    regressors: for instance, realignment parameters
         # TMP makes use of the utility function tfilter, which
         # itself calls fslmaths, 3dBandpass, or the R script
         # genfilter to enable a wide array of filters.
         ##########################################################
         routine              @9    Temporally filtering image
         ##########################################################
         # If no temporal filtering has been specified by the user,
         # then bypass this step.
         ##########################################################
         if [[ ${prestats_tmpf[${cxt}]} == none ]]
            then
            subroutine        @9.1
            ln -s ${intermediate}.nii.gz ${intermediate}_${cur}.nii.gz
         elif ! is_image ${intermediate}_${cur} \
         || rerun
            then
            #######################################################
            # OBTAIN MASKS: SPATIAL
            #######################################################
            if is_image ${mask[${subjidx}]}
               then
               subroutine     @9.2.1
               mask="-m ${mask[${subjidx}]}"
            elif is_image ${mask[${cxt}]}
               then
               subroutine     @9.2.2
               mask="-m ${mask[${cxt}]}"
            else
               subroutine     @9.3
               mask=''
            fi
            #######################################################
            # OBTAIN MASKS: TEMPORAL
            #######################################################
            censor_type=${censor[${cxt}]}
            if is_1D ${tmask[${subjidx}]}
               then
               subroutine     @9.4.1
               tmask_tmp=${tmask[${subjidx}]}
            elif is_1D ${tmask[${cxt}]}
               then
               subroutine     @9.4.2
               tmask_tmp=${tmask[${cxt}]}
            else
               subroutine     @9.5
               tmask_tmp=ones
               censor_type=none
            fi
            #######################################################
            # Next, determine whether the user has enabled
            # censoring of high-motion volumes in order to pass
            # the most appropriate temporal mask to the child
            # script.
            #######################################################
            if [[ ${censor_type} == iter ]] \
            && [[ ${tmask_tmp} != ones ]]
               then
               subroutine     @9.6.1
               tmask_tmp="-n ${tmask_tmp}"
            elif [[ ${censor_type} == final ]] \
            && [[ ${tmask_tmp} != ones ]]
               then
               subroutine     @9.6.2
               tmask_tmp="-k ${tmask_tmp}"
            else
               subroutine     @9.7
               unset tmask_tmp
            fi
            #######################################################
            # DERIVATIVE IMAGES AND TIMESERIES
            # Prime the index of derivative images, as well as
            # any 1D timeseries (e.g. realignment parameters)
            # that should be filtered so that they can be used in
            # linear models without reintroducing the frequencies
            # removed from the BOLD timeseries.
            #######################################################
            derivs="-x ${aux_imgs[${subjidx}]}"
            unset ts1d
            #######################################################
            # Realignment parameters...
            #######################################################
            if is_1D ${rps[${subjidx}]}
               then
               subroutine     @9.8.1
               ts1d="${ts1d} ${rps[${subjidx}]}"
            elif is_1D ${rps[${cxt}]}
               then
               subroutine     @9.8.2
               ts1d="${ts1d} ${rps[${cxt}]}"
            fi
            #######################################################
            # Relative RMS motion...
            #######################################################
            if is_1D ${rel_rms[${subjidx}]}
               then
               subroutine     @9.9.1
               ts1d="${ts1d} ${rel_rms[${subjidx}]}"
            elif is_1D ${rel_rms[${cxt}]}
               then
               subroutine     @9.9.2
               ts1d="${ts1d} ${rel_rms[${cxt}]}"
            fi
            #######################################################
            # Absolute RMS motion...
            #######################################################
            if is_1D ${abs_rms[${subjidx}]}
               then
               subroutine     @9.10.1
               ts1d="${ts1d} ${abs_rms[${subjidx}]}"
            elif is_1D ${abs_rms[${cxt}]}
               then
               subroutine     @9.10.2
               ts1d="${ts1d} ${abs_rms[${cxt}]}"
            fi
            #######################################################
            # Replace any whitespace characters in the 1D
            # timeseries list with commas, and prepend the -l flag
            # for input as an argument to tfilter
            #######################################################
            if [[ ! -z ${ts1d} ]]
               then
               subroutine     @9.11
               ts1d="-1 ${ts1d// /,}"
            fi
            #######################################################
            # FILTER-SPECIFIC ARGUMENTS
            # Next, set arguments specific to each filter class.
            #######################################################
            unset tf_order tf_direc tf_p_rip tf_s_rip
            case ${prestats_tmpf[${cxt}]} in
            butterworth)
               subroutine     @9.12
               tf_order="-r ${prestats_tmpf_order[${cxt}]}"
               tf_direc="-d ${prestats_tmpf_pass[${cxt}]}"
               ;;
            chebyshev1)
               subroutine     @9.13
               tf_order="-r ${prestats_tmpf_order[${cxt}]}"
               tf_direc="-d ${prestats_tmpf_pass[${cxt}]}"
               tf_p_rip="-p ${prestats_tmpf_ripple[${cxt}]}"
               ;;
            chebyshev2)
               subroutine     @9.14
               tf_order="-r ${prestats_tmpf_order[${cxt}]}"
               tf_direc="-d ${prestats_tmpf_pass[${cxt}]}"
               tf_s_rip="-s ${prestats_tmpf_ripple2[${cxt}]}"
               ;;
            elliptic)
               subroutine     @9.15
               tf_order="-r ${prestats_tmpf_order[${cxt}]}"
               tf_direc="-d ${prestats_tmpf_pass[${cxt}]}"
               tf_p_rip="-p ${prestats_tmpf_ripple[${cxt}]}"
               tf_s_rip="-s ${prestats_tmpf_ripple2[${cxt}]}"
               ;;
            esac
            #######################################################
            # If the user has requested discarding of initial
            # and/or final volumes from the filtered timeseries,
            # the request should be passed to tfilter.
            #######################################################
            unset tf_dvol
            if [[ -n ${prestats_tmpf_dvols[${cxt}]} ]]
               then
               subroutine     @9.16
               tf_dvol="-v ${prestats_tmpf_dvols[${cxt}]}"
            fi
            #######################################################
            # Engage the tfilter routine to filter the image.
            #  * This is essentially a wrapper around the three
            #    implemented filtering routines: fslmaths,
            #    3dBandpass, and genfilter
            #######################################################
            subroutine        @9.17a   ${prestats_tmpf[${cxt}]} filter
            subroutine        @9.17b   High pass frequency: ${prestats_hipass[${cxt}]}
            subroutine        @9.17c   Low pass frequency: ${prestats_lopass[${cxt}]}
            exec_xcp \
               tfilter \
               -i ${intermediate}.nii.gz \
               -o ${intermediate}_${cur}.nii.gz \
               -f ${prestats_tmpf[${cxt}]} \
               -h ${prestats_hipass[${cxt}]} \
               -l ${prestats_lopass[${cxt}]} \
               ${mask} \
               ${tmask_tmp} \
               ${tf_order} \
               ${tf_direc} \
               ${tf_p_rip} \
               ${tf_s_rip} \
               ${tf_dvol} \
               ${derivs} \
               ${ts1d} \
               ${trace_prop}
            #######################################################
            # Move outputs to target
            #######################################################
            is_1D ${intermediate}_${cur}_realignment.1D \
            && mv -f ${intermediate}_${cur}_${prefix}_realignment.1D \
               ${rps[${cxt}]}
            is_1D ${intermediate}_${cur}_abs_rms.1D \
            && mv -f ${intermediate}_${cur}_${prefix}_abs_rms.1D \
               ${absrms[${cxt}]}
            is_1D ${intermediate}_${cur}_rel_rms.1D \
            && mv -f ${intermediate}_${cur}_${prefix}_rel_rms.1D \
               ${relrms[${cxt}]}
            is_1D ${intermediate}_${cur}_tmask.1D \
            && mv -f ${intermediate}_${cur}_tmask.1D \
               ${tmask[${cxt}]}
            [[ -e ${intermediate}_${cur}_derivs ]] \
            && mv -f ${intermediate}_${cur}_derivs \
               ${aux_imgs[${subjidx}]}
         fi
         ##########################################################
         # Update image pointer
         ##########################################################
         intermediate=${intermediate}_${cur}
         routine_end
         ;;
      
      *)
         subroutine           @E.1     Invalid option detected: ${cur}
         ;;
         
   esac
done





###################################################################
# CLEANUP
#  * Test for the expected output. This should be the initial
#    image name with any routine suffixes appended.
#  * If the expected output is present, move it to the target path.
#  * Remove any temporary files if cleanup is enabled.
#  * Update the audit file to reflect successful completion of the
#    module.
#  * If the expected output is absent, notify the user.
###################################################################
if is_image ${intermediate_root}${buffer}.nii.gz
   then
   subroutine                 @0.2
   processed=$(readlink -f ${intermediate}.nii.gz)
   exec_fsl immv ${processed} ${final[${cxt}]}
   completion
else
   subroutine                 @0.3
   echo \
   "


XCP-ERROR: Expected output not present.
Expected: ${prefix}${buffer}
Check the log to verify that processing
completed as intended.
"
   exit 1
fi
