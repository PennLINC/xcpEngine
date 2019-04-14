#!/usr/bin/env bash

###################################################################
#  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  #
###################################################################

###################################################################
# SPECIFIC MODULE HEADER
# This module produce basil cbf
###################################################################
mod_name_short=basil
mod_name='BASIL CBF'
mod_head=${XCPEDIR}/core/CONSOLE_MODULE_RC

###################################################################
# GENERAL MODULE HEADER
###################################################################
source ${XCPEDIR}/core/constants
source ${XCPEDIR}/core/functions/library.sh
source ${XCPEDIR}/core/parseArgsMod

###################################################################
# MODULE COMPLETIO
###################################################################
completion() {
   source ${XCPEDIR}/core/auditComplete
   source ${XCPEDIR}/core/updateQuality
   source ${XCPEDIR}/core/moduleEnd
}

###################################################################
# OUTPUTS
###################################################################
derivative            cbf                  ${prefix}_cbf.nii.gz
derivative            cbf_calib            ${prefix}_cbf_calib.nii.gz
derivative            cbf_spatial          ${prefix}_cbf_spatial.nii.gz
derivative            cbf_spatial_calib    ${prefix}_cbf_spatial_calib.nii.gz
derivative            acbv                 ${prefix}_acbv.nii.gz
derivative            acbv_spatial         ${prefix}_acbv_spatial.nii.gz
derivative            cbf_pv_calib         ${prefix}_cbf_pv_calib.nii.gz
derivative            cbf_pvgm_calib       ${prefix}_cbf_pv_gm_calib.nii.gz
derivative            cbf_pvwm_calib       ${prefix}_cbf_pv_wm_calib.nii.gz
derivative            cbf_pv               ${prefix}_cbf_pv.nii.gz
derivative            cbf_pvgm             ${prefix}_cbf_pv_gm.nii.gz
derivative            cbf_pvwm             ${prefix}_cbf_pv_wm.nii.gz

output           logfile              ${prefix}_logfile
output           basil_option         ${prefix}_basil_option.txt
output           logfile2             ${prefix}_logfile_spatial
output           cbf                  ${prefix}_cbf.nii.gz
output           cbf_calib            ${prefix}_cbf_calib.nii.gz
output           cbf_spatial          ${prefix}_cbf_spatial.nii.gz
output           cbf_spatial_calib    ${prefix}_cbf_spatial_calib.nii.gz
output           acbv                 ${prefix}_acbv.nii.gz
output           acbv_spatial         ${prefix}_acbv_spatial.nii.gz
output           cbf_pv_calib         ${prefix}_cbf_pv_calib.nii.gz
output           cbf_pvgm_calib       ${prefix}_cbf_pv_gm_calib.nii.gz
output           cbf_pvwm_calib       ${prefix}_cbf_pv_wm_calib.nii.gz
output           cbf_pv               ${prefix}_cbf_pv.nii.gz
output           cbf_pvgm             ${prefix}_cbf_pv_gm.nii.gz
output           cbf_pvwm             ${prefix}_cbf_pv_wm.nii.gz




derivative_set       cbf                Statistic         mean
derivative_set       cbf_calib          Statistic         mean
derivative_set       cbf_spatial        Statistic         mean
derivative_set       cbf_spatial_calib  Statistic         mean
derivative_set       acbv               Statistic         mean
derivative_set       acbv_spatial       Statistic         mean
derivative_set       cbf_pv_calib       Statistic         mean
derivative_set       cbf_pvgm_calib     Statistic         mean
derivative_set       cbf_pvwm_calib     Statistic         mean
derivative_set       cbf_pv             Statistic         mean
derivative_set       cbf_pvgm           Statistic         mean
derivative_set       cbf_pvwm           Statistic         mean

qc negative_voxels    negativeVoxels   ${prefix}_negativeVoxels.txt

process               perfusion        ${prefix}_cbf.nii.gz

<<DICTIONARY


DICTIONARY

## generate m0

if ! is_image ${m0[sub]} \
   then 
   m0=${out}/cbf/${prefix}_m0.nii.gz
   basil_m0_scale=1
   if (( ${cbf_first_tagged[cxt]} == 1 ))
      exec_afni 3dcalc -prefix ${m0}  -a ${intermediate}'[0..$(2)]' -expr "a" 2>/dev/null   
      else
      exec_afni 3dcalc -prefix ${m0}  -a ${intermediate}'[1..$(2)]' -expr "a" 2>/dev/null 
   fi
   exec_fsl fslmaths ${m0} -Tmean ${m0}
   output m0  ${out}/cbf/${prefix}_m0.nii.gz
else
   m0=${out}/cbf/${prefix}_m0.nii.gz
   exec_fsl fslmaths ${m0[sub]} -Tmean ${m0}
   output m0  ${out}/cbf/${prefix}_m0.nii.gz
fi

# register the cbf and m0 to struct 
rawcbf=${out}/basil/${prefix}_rawcbf.nii.gz 
m0_s=${out}/basil/${prefix}_m0_struct.nii.gz 
mask1=${out}/basil/${prefix}_mask.nii.gz
  if is_image ${struct[sub]}
   exec_ants antsApplyTransforms -r ${struct[sub]} \
        -i ${processed[sub]} -t ${seq2struct[sub]} \
        -o ${rawcbf} -n NearestNeighbor
   exec_ants antsApplyTransforms -r ${struct[sub]} \
        -i ${m0[cxt]} -t ${seq2struct[sub]} \
        -o ${m0_s} -n NearestNeighbor
   output M0 ${out}/basil/${prefix}_m0_struct.nii.gz
   exec_ants antsApplyTransforms -r ${struct[sub]} \
        -i ${mask[sub]} -t ${seq2struct[sub]} \
        -o ${mask1} -n NearestNeighbor
   output MASK ${out}/basil/${prefix}_mask.nii.gz
fi
# get the extratced brain with afni skullstrip 
exec_fsl  fslmaths  ${struct[sub]} -mul ${struct_mask} \
      ${out}/basil/${prefix}_struct_brain.nii.gz
output struct_brain ${out}/basil/${prefix}_struct_brain.nii.gz 

###################################################################
# Compute cerebral blood flow with basil.
###################################################################
   


   case ${basil_perfusion[cxt]} in
   
   casl)
      subroutine              @1.1a PCASL/CASL -- Pseudocontinuous ASL
      subroutine              @1.1b Input: ${rawcbf}
      subroutine              @1.1c M0: ${M0[cxt]}
      subroutine              @1.1d mask: ${MASK[cxt]}
      subroutine              @1.1e M0 scale: ${basil_m0_scale[cxt]}
      subroutine              @1.1f Partition coefficient: ${basil_lambda[cxt]}
      subroutine              @1.1g Post-labelling delay: ${basil_pld[cxt]}
      subroutine              @1.1i Blood T1: ${basil_t1blood[cxt]}
      subroutine              @1.1j Labelling efficiency: ${basil_alpha[cxt]}
      subroutine              @1.1k Template: ${template}
      subroutine              @1.1n pvgm  : ${gm[sub]}
      subroutine              @1.1o pvwm  : ${wm[sub]}
      

      if [  ${basil_pvc[cxt]} == 1 ]; then
          
          routine @2.1  compute CBF
           exec_xcp perf_asl -i ${rawcbf}      \
               -m ${MASK[cxt]}                 \
               -o ${out}/basil                 \
               --struct=${struct_brain[cxt]}   \
               --casl                          \
               --M0=${M0[cxt]}                 \
               --cgain=${basil_m0_scale[cxt]}  \
               --alpha=${basil_alpha[cxt]}     \
               --iaf=${basil_inputformat[cxt]} \
               --tis=${basil_tis[cxt]}         \
               --spatial                       \
               --tr=${basil_MOTR[cxt]}         \
               --pvgm=${gm[sub]}               \
               --pvwm=${wm[sub]}               \
               --pvcorr 

        elif [ ${basil_pvc[cxt]} == 0 ]; then 

          routine @2.1  compute CBF
         exec_xcp perf_asl -i ${rawcbf}      \
               -m ${MASK[cxt]}                 \
               -o ${out}/basil                 \
               --struct=${struct_brain[cxt]}   \
               --casl                          \
               --M0=${M0[cxt]}                 \
               --cgain=${basil_m0_scale[cxt]}  \
               --alpha=${basil_alpha[cxt]}     \
               --iaf=${basil_inputformat[cxt]} \
               --tis=${basil_tis[cxt]}         \
               --spatial                       \
               --tr=${basil_MOTR[cxt]}         
      fi
      ;;
      
   pasl)
      subroutine              @1.1a PASL
      subroutine              @1.1b Input: ${rawcbf}
      subroutine              @1.1c M0: ${M0[cxt]}
      subroutine              @1.1d mask: ${MASK[cxt]}
      subroutine              @1.1e M0 scale: ${basil_m0_scale[cxt]}
      subroutine              @1.1f Partition coefficient: ${basil_lambda[cxt]}
      subroutine              @1.1g Post-labelling delay: ${basil_pld[cxt]}
      subroutine              @1.1i Blood T1: ${basil_t1blood[cxt]}
      subroutine              @1.1j Labelling efficiency: ${basil_alpha[cxt]}
      subroutine              @1.1k Template: ${template}
      subroutine              @1.1n pvgm  : ${gm[sub]}
      subroutine              @1.1o pvwm  : ${wm[sub]}
      

      if [  ${basil_pvc[cxt]} == 1 ]; then
          
          routine @2.1  compute CBF
           exec_xcp perf_asl -i ${rawcbf}      \
               -m ${MASK[cxt]}                 \
               -o ${out}/basil                 \
               --struct=${struct_brain[cxt]}   \
               --M0=${M0[cxt]}                 \
               --cgain=${basil_m0_scale[cxt]}  \
               --alpha=${basil_alpha[cxt]}     \
               --iaf=${basil_inputformat[cxt]} \
               --tis=${basil_tis[cxt]}         \
               --spatial                       \
               --tr=${basil_MOTR[cxt]}         \
               --pvgm=${gm[sub]}               \
               --pvwm=${wm[sub]}               \
               --pvcorr 

        elif [ ${basil_pvc[cxt]} == 0 ]; then 

          routine @2.1  compute CBF
         exec_xcp perf_asl -i ${rawcbf}       \
               -m ${MASK[cxt]}                 \
               -o ${out}/basil                 \
               --struct=${struct_brain[cxt]}   \
               --M0=${M0[cxt]}                 \
               --cgain=${basil_m0_scale[cxt]}  \
               --alpha=${basil_alpha[cxt]}     \
               --iaf=${basil_inputformat[cxt]} \
               --tis=${basil_tis[cxt]}         \
               --spatial                       \
               --tr=${basil_MOTR[cxt]}         
      fi
      ;;
     
   esac

###################################################################
# organize the ouput
###################################################################
routine @3 Orgainizing the output 

  if [ ${basil_pvc[cxt]} == 1 ]; then 
    exec_fsl immv $out/basil/acbv  $out/basil/${prefix}_acbv
    exec_fsl immv $out/basil/acbv_spatial  $out/basil/${prefix}_acbv_spatial
    exec_fsl immv  $out/basil/cbf_calib   $out/basil/${prefix}_cbf_calib
    exec_fsl immv  $out/basil/cbf   $out/basil/${prefix}_cbf
    exec_fsl immv  $out/basil/cbf_pv_calib   $out/basil/${prefix}_cbf_pv_calib
    exec_fsl immv  $out/basil/cbf_pv_gm_calib   $out/basil/${prefix}_cbf_pv_gm_calib
    exec_fsl immv  $out/basil/cbf_pv_wm_calib   $out/basil/${prefix}_cbf_pv_wm_calib
    exec_fsl immv  $out/basil/cbf_pv   $out/basil/${prefix}_cbf_pv
    exec_fsl immv  $out/basil/cbf_pv_gm   $out/basil/${prefix}_cbf_pv_gm
    exec_fsl immv  $out/basil/cbf_pv_wm   $out/basil/${prefix}_cbf_pv_wm
    exec_fsl immv  $out/basil/cbf_spatial_calib   $out/basil/${prefix}_cbf_spatial_calib
    exec_fsl immv  $out/basil/cbf_spatial  $out/basil/${prefix}_cbf_spatial
    exec_fsl immv  $out/basil/M0   $out/basil/${prefix}_M0
    exec_fsl immv  $out/basil/mask   $out/basil/${prefix}_mask
    exec_sys mv    $out/basil/basil_option.txt  $out/basil/${prefix}_basil_option.txt
    exec_sys mv    $out/basil/logfile  $out/basil/${prefix}_logfile
    exec_sys mv    $out/basil/logfile_spatial  $out/basil/${prefix}_logfile_spatial
 
  elif [ ${basil_pvc[cxt]} == 0 ]; then
  
    exec_fsl immv  $out/basil/acbv   $out/basil/${prefix}_acbv
    exec_fsl immv  $out/basil/acbv_spatial   $out/basil/${prefix}_acbv_spatial
    exec_fsl immv  $out/basil/cbf   $out/basil/${prefix}_cbf
    exec_fsl immv  $out/basil/cbf_calib   $out/basil/${prefix}_cbf_calib
    exec_fsl immv  $out/basil/cbf_spatial_calib   $out/basil/${prefix}_cbf_spatial_calib
    exec_fsl immv  $out/basil/cbf_spatial  $out/basil/${prefix}_cbf_spatial
    exec_fsl immv  $out/basil/M0   $out/basil/${prefix}_M0
    exec_fsl immv  $out/basil/mask   $out/basil/${prefix}_mask
    exec_sys mv  $out/basil/basil_option.txt  $out/basil/${prefix}_basil_option.txt
    exec_sys mv  $out/basil/logfile  $out/basil/${prefix}_logfile
    exec_sys mv  $out/basil/logfile_spatial  $out/basil/${prefix}_logfile_spatial
 fi 
 
   neg=( $(exec_fsl fslstats $out/basil/${prefix}_cbf.nii.gz          \
              -k    $out/basil/${prefix}_mask.nii.gz  \
              -u    0                                       \
              -V) )
   echo ${neg[0]}   >> ${negative_voxels[cxt]}



  #exec_fsl imcp  $out/basil/${prefix}_cbf.nii.gz  $out/${prefix}.nii.gz
  
  
routine_end

completion
