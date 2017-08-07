#!/usr/bin/env bash

###################################################################
#  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  #
###################################################################

###################################################################
# SPECIFIC MODULE HEADER
# This module normalises images and derivatives to an atlas.
###################################################################
mod_name_short=norm
mod_name='IMAGE NORMALISATION MODULE'
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
   processed         std
   
   set_space         standard
   
   quality_metric    normCoverage            norm_coverage
   quality_metric    normCrossCorr           norm_cross_corr
   quality_metric    normJaccard             norm_jaccard
   quality_metric    normDice                norm_dice
   
   source ${XCPEDIR}/core/auditComplete
   source ${XCPEDIR}/core/updateQuality
   source ${XCPEDIR}/core/moduleEnd
}





###################################################################
# OUTPUTS
###################################################################
derivative  e2smask                 ${prefix}_seq2structMask

output      norm_cross_corr         ${prefix}_normCrossCorr.txt
output      norm_coverage           ${prefix}_normCoverage.txt
output      norm_jaccard            ${prefix}_normJaccard.txt
output      norm_dice               ${prefix}_normDice.txt

process     std                     ${prefix}_std

<< DICTIONARY

e2smask
   The reference volume from the analyte sequence, aligned into
   structural space and binarised. Used to estimate the quality
   of normalisation.
norm_coverage
   The percentage of the template image that is covered by the
   normalised analyte image.
norm_cross_corr
   The spatial cross-correlation between the template image mask
   and the normalised analyte mask.
norm_dice
   The Dice coefficient between template and analyte.
norm_jaccard
   The Jaccard coefficient between template and analyte.
std
   The analyte image, normalised to template space.

DICTIONARY










###################################################################
# Determine what program the user has specified for normalisation.
#  * At this point in time, only ANTs-based normalisation has been
#    tested, and the remaining options are no longer supported.
###################################################################
add_reference        template       template
case ${norm_prog[${cxt}]} in
   
   ants)
      routine              @1    Normalising using ANTs
      #############################################################
      # Determine which transforms need to be applied.
      #############################################################
      subroutine           @1.1  [Selecting transforms to apply]
      load_transforms
      #############################################################
      # Apply the transforms to the primary BOLD timeseries.
      #############################################################
      case ${space} in
      native)
         subroutine        @1.2.1
         space_code=nat
         ;;
      structural)
         subroutine        @1.2.2
         space_code=str
         ;;
      standard)
         subroutine        @1.2.3
         space_code=std
         ;;
      esac
      if ! is_image ${std[${cxt}]} \
      || rerun
         then
         subroutine        @1.3  [Applying composite diffeomorphism to primary dataset]
         source ${XCPEDIR}/core/mapToSpace \
            ${space_code}2standard \
            ${img} \
            ${std[${cxt}]}
      fi
      #############################################################
      # Iterate through all derivative images, and apply
      # the computed transforms to each.
      #############################################################
      load_derivatives
      subroutine           @1.4  [Applying composite diffeomorphism to derivative images:]
      mv    ${aux_imgs[${subjidx}]} \
            ${out}/${prefix}_derivatives-${space}.json
      echo  '{}'     >>        ${aux_imgs[${subjidx}]}
      for derivative in ${derivatives[@]}
         do
         derivative_parse  ${derivative}
         subroutine        @1.5  [${d_name}]
         derivative              ${d_name}      ${prefix}_${d_name}Std
         derivative_config       ${d_name}      Space    standard
         d_call=${d_name}'['${cxt}']'
         ##########################################################
         # If the image is a mask, apply nearest neighbour
         # interpolation to prevent introduction of intermediate
         # values
         ##########################################################
         unset interpol
         if [[ ${d_name} != ${d_name//mask} ]] \
         || [[ ${d_name} != ${d_name//Mask} ]]
            then
            subroutine     @1.6
            interpol=NearestNeighbor
         fi
         if ! is_image ${!d_call} \
         || rerun
            then
            subroutine     @1.7
            source ${XCPEDIR}/core/mapToSpace \
               ${space_code}2standard \
               ${d_map} \
               ${!d_call} \
               ${interpol}
         fi
         write_derivative        ${d_name}
      done
      routine_end
      #############################################################
      # Prepare quality variables and a cross-sectional view for
      # the example functional brain
      #############################################################
      if is_image ${referenceVolumeBrain[${cxt}]} \
      || rerun
      then
      subroutine           @2.0
      if [[ ! -e ${outdir}/${prefix}_ep2std.png ]] \
      || rerun
         then
         routine           @2    Quality assessment
         exec_fsl fslmaths ${referenceVolumeBrain[${cxt}]} -bin ${e2smask[${cxt}]}
         subroutine        @2.1  [Computing registration quality metrics]
         registration_quality=( $(exec_xcp \
            maskOverlap.R \
            -m ${e2smask[${cxt}]} \
            -r ${template}) )
         echo  ${registration_quality[0]} > ${norm_cross_corr[${cxt}]}
         echo  ${registration_quality[1]} > ${norm_coverage[${cxt}]}
         echo  ${registration_quality[2]} > ${norm_jaccard[${cxt}]}
         echo  ${registration_quality[3]} > ${norm_dice[${cxt}]}
         subroutine        @2.2  [Preparing slicewise rendering]
         exec_xcp \
            regslicer \
            -s ${referenceVolumeBrain[${cxt}]} \
            -t ${template} \
            -i ${intermediate} \
            -o ${outdir}/${prefix}_ep2std
         routine_end
      fi
      fi
      ;;
      
   dramms)
      echo \
"


DRAMMS-based normalisation is not supported at this
time. Please use ANTs-based normalisation instead.
"
      ;;
      
   fnirt)
      echo \
"


FNIRT-based normalisation is not supported at this
time. Please use ANTs-based normalisation instead.
"
      ;;
      
esac





completion
