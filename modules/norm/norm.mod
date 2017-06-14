#!/usr/bin/env bash

###################################################################
#  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  #
###################################################################

###################################################################
# SPECIFIC MODULE HEADER
# This module preprocesses fMRI data.
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
output      aux_imgs                ${prefix}_derivsNorm
output      norm_cross_corr         ${prefix}_normCrossCorr.txt
output      norm_coverage           ${prefix}_normCoverage.txt
output      norm_jaccard            ${prefix}_normJaccard.txt
output      norm_dice               ${prefix}_normDice.txt

process     std                     ${prefix}_std

<< DICTIONARY

aux_imgs
   An index of derivatives that have been normalised to the
   template.
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
case ${norm_prog[${cxt}]} in
   
   ants)
      routine              @1    Normalising using ANTs
      #############################################################
		# Determine which transforms need to be applied.
      #############################################################
      subroutine           @1.1  Selecting transforms to apply
		load_transforms
      #############################################################
		# Apply the transforms to the primary BOLD timeseries.
      #############################################################
      if ! is_image ${std[${cxt}]} \
      || rerun
         then
		   subroutine        @1.2  Applying composite diffeomorphism to primary dataset
         ${XCPEDIR}/core/mapToSpace \
            ${space_code}2standard \
            ${img} \
            ${std[${cxt}]}
      fi
      #############################################################
      # Iterate through all derivative images, and apply
      # the computed transforms to each.
      #############################################################
      load_derivatives
		subroutine           @1.3  Applying composite diffeomorphism to derivative images:
      aux_imgs[${subjidx}]=${aux_imgs[${cxt}]}
      for derivative in ${derivatives}
         do
         derivative_parse  ${derivative}
		   subroutine        @1.4  ${d_name}
		   derivative              ${d_name}      ${outdir}/${prefix}_${imgName}Std
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
            subroutine     @1.5
            interpol=NearestNeighbor
         fi
         ##########################################################
         # Warp
         ##########################################################
         case space in
         native)
            subroutine     @1.6.1
            space_code=nat
            ;;
         structural)
            subroutine     @1.6.2
            space_code=str
            ;;
         standard)
            subroutine     @1.6.3
            space_code=std
            ;;
         esac
         if ! is_image ${!d_call} \
         || rerun
            then
            subroutine     @1.7
            ${XCPEDIR}/core/mapToSpace \
               ${space_code}2standard \
               ${d_path} \
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
         exec_sys ln -s ${template} ${outdir}/template.nii.gz
         fslmaths ${referenceVolumeBrain[${cxt}]} -bin ${img}ep2std_mask
         fslmaths ${template} -bin ${img}template_mask
         subroutine        @2.1  Computing registration quality metrics
         registration_quality=( $(exec_xcp \
            maskOverlap.R \
            -m ${e2smask[${cxt}]} \
            -r ${struct[${subjidx}]}) )
         echo  ${registration_quality[0]} > ${norm_cross_corr[${cxt}]}
         echo  ${registration_quality[1]} > ${norm_coverage[${cxt}]}
         echo  ${registration_quality[2]} > ${norm_jaccard[${cxt}]}
         echo  ${registration_quality[3]} > ${norm_dice[${cxt}]}
         subroutine        @2.2  Preparing slicewise rendering
         exec_xcp \
            regslicer \
            -s ${referenceVolumeBrain[${cxt}]} \
            -t ${template}
            -i ${intermediate}
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
