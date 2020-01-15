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
output      magmask               ${prefix}_magmask.nii.gz
output      img                   ${prefix}_img_dico.nii.gz
output      img1                   ${prefix}_img_dico.nii.gz

## determine if the fieldmap is phasediff or topup 

if [[ -d ${dico_fmapdir[cxt]} ]]; then 
echo " there is fieldmap"
    phase=$(ls -f ${dico_fmapdir[cxt]}/*phase*nii.gz 2>/dev/null) 
    if [[ -f ${phase} ]]; then 
       # run the phasediff.py
    else 
       # run the topup 
    fi
else 
   echo " no fieldmap"
fi 




### reognanize the  outputs 




 ### apply the filedmap on the image to correct for dist