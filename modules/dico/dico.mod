#!/usr/bin/env bash

###################################################################
#  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  #
###################################################################

###################################################################
# SPECIFIC MODULE HEADER
# This module performs regional quantification of voxelwise maps.
###################################################################
mod_name_short=dico
mod_name='DISTORTION CORRECTION'
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


###################################################################
# MODULE COMPLETION
###################################################################
completion() {
   source ${XCPEDIR}/core/auditComplete
   source ${XCPEDIR}/core/updateQuality
   source ${XCPEDIR}/core/moduleEnd
}

###################################################################
# OUTPUTS
###################################################################
output      fieldmmap             ${prefix}_fieldmap.nii.gz
output      magnitude             ${prefix}_magnitude.nii.gz 
output      img                   ${prefix}_img_dico.nii.gz
output      img1                  ${prefix}_img_dico.nii.gz


final      img           ${prefix}_img_dico.nii.gz


#get phasenoding direction from image

## determine if the fieldmap is phasediff or topup 
if [[ ! ${dico_pedir[cxt]} ]]; then 
    dico_pedir='j'
else
dico_pedir=${dico_pedir[cxt]}

fi 


if [[ -d ${dico_fmapdir[cxt]} ]]; then 
echo " there is fieldmap"
    phase=$(ls -f ${dico_fmapdir[cxt]}/*phase*nii.gz 2>/dev/null) 
    if [[ -f ${phase} ]]; then 
       # run the phasediff.pye
       exec_sys make -p ${outdir}/dico
       python ${XCPEDIR}/core/phasediff.py -f ${dico_fmapdir[cxt]} -o ${outdir}/dico/ 
       magbrain=${outdir}/dico/mag1_brain.nii.gz
       fmap=${outdir}/dico/sdc_warp_demean.nii.gz
    else 
       python ${XCPEDIR}/core/topup.py -f ${dico_fmapdir[cxt]} -o ${outdir}/dico/  -p ${dico_pedir}
       magbrain=${outdir}/dico/matchpe_brain.nii.gz
       fmap=${outdir}/dico/fieldmapto_rads.nii.gz
    fi
else 
   echo " no fieldmap"
fi 

### get refereence volume from image, 
#skullsttrip with afni


nvol=$(exec_fsl fslnvols ${intermediate}.nii.gz)
            midpt=$(( ${nvol} / 2))
exec_fsl fslroi ${intermediate}.nii.gz \
               ${intermediate}-reference.nii.gz ${midpt} 1
exec_afni 3dSkullStrip -input ${intermediate}-reference.nii.gz \
   -prefix   ${intermediate}-referencebrain.nii.gz 

#regsiter fielmap magnitude to refvolume
exec_ants antsRegistrationSyN.sh -d 3 -f ${intermediate}-referencebrain.nii.gz  \
      -m $mag1_brain  -o ${outdir}/dico/fmap2ref_

#apply transformation to fieldmap, mask 

exec_ants   antsApplyTransforms -d 3 -i ${magbrain} -r  ${intermediate}-referencebrain.nii.gz \
-t ${outdir}/dico/fmap2ref_0GenericAffine.mat  -t ${outdir}/dico/fmap2ref_1Warp.nii.gz  \
-o ${prefix}_magnitude.nii.gz -n LanczosWindowedSinc

exec_ants   antsApplyTransforms -d 3 -i ${fmap} -r  ${intermediate}-referencebrain.nii.gz \
-t ${outdir}/dico/fmap2ref_0GenericAffine.mat  -t ${outdir}/dico/fmap2ref_1Warp.nii.gz  \
-o ${prefix}_fieldmap.nii.gz -n LanczosWindowedSinc


 ### apply the fieldmap on the image to correct for dist
 exec_ants   antsApplyTransforms -d 3 -i ${img[sub]} -r  ${intermediate}-referencebrain.nii.gz \
-t ${prefix}_fieldmap.nii.gz  -o ${prefix}_img_dico.nii.gz -n LanczosWindowedSinc

#clean the file file 
exec_sys rm -rf ${outdir}/dico/