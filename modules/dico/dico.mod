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
source ${XCPEDIR}/core/functions/library_func.sh
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
output      fieldmap              ${prefix}_fieldmap.nii.gz
output      magnitude             ${prefix}_magnitude.nii.gz 
output      img                   ${prefix}_img_dico.nii.gz
output      img1                  ${prefix}_img_dico.nii.gz


process     img           ${prefix}_img_dico.nii.gz

routine
exec_sys mkdir -p ${out}/dico 
outdir=${out}/dico
#get phasenoding direction from image

## determine if the fieldmap is phasediff or topup 
if [[ ! ${dico_pedir[cxt]} ]]; then 
    dico_pedir=j
else
dico_pedir=${dico_pedir[cxt]}
fi 

nvol=$(exec_fsl fslnvols ${intermediate}.nii.gz)
midpt=$(( ${nvol} / 2))
exec_fsl fslroi ${intermediate}.nii.gz \
               ${intermediate}-reference.nii.gz ${midpt} 1

exec_fsl bet ${intermediate}-reference.nii.gz \
                  ${intermediate}-referencebrain.nii.gz      \
                  -f 0.5



if [[ -d ${dico_fmapdir[cxt]} ]]; then 
echo " there is fieldmap directory"
    phase=$(ls -f ${dico_fmapdir[cxt]}/*phase*nii.gz 2>/dev/null) 
    if [[ -f ${phase} ]]; then 
       # run the phasediff.pye
       exec_sys mkdir -p ${outdir}/dico
       python ${XCPEDIR}/core/phasediff.py -f ${dico_fmapdir[cxt]}  -i ${intermediate}-referencebrain.nii.gz   -o ${outdir}/dico/ 
       exec_fsl immv ${outdir}/dico/sdc_warp.nii.gz  ${outdir}/${prefix}_fieldmap.nii.gz
       exec_fsl immv ${outdir}/dico/mag_warped.nii.gz  ${outdir}/${prefix}_magnitude.nii.gz 

    else 
       exec_sys mkdir -p ${outdir}/dico
       python ${XCPEDIR}/core/topup.py -f ${dico_fmapdir[cxt]} -o ${outdir}/dico/  -p ${dico_pedir}
       exec_fsl immv ${outdir}/dico/fieldmapto_rads.nii.gz  ${outdir}/${prefix}_fieldmap.nii.gz
       exec_fsl immv ${outdir}/dico/matched_warped.nii.gz ${outdir}/${prefix}_magnitude.nii.gz 
    fi
else 
   echo " no fieldmap"
fi 


#clean the file file 
exec_sys rm -rf ${outdir}/dico/

routine_end
completion