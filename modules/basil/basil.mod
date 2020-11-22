#!/usr/bin/env bash

###################################################################
#  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  #
###################################################################

###################################################################
# SPECIFIC MODULE HEADER
# This module produce basil cbf
###################################################################
mod_name_short=basil
mod_name='BASIL   CBF'
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

derivative            cbfbasil                 ${prefix}_cbfbasil.nii.gz
derivative            cbfspatial               ${prefix}_cbfspatial.nii.gz
derivative            cbfpv                    ${prefix}_cbfpv.nii.gz
derivative            cbfbasilR                ${prefix}_cbfbasilR.nii.gz 
derivative            cbfspatialR              ${prefix}_cbfspatialR.nii.gz 
derivative            cbfpvR                   ${prefix}_cbfpvR.nii.gz
derivative            cbfbasilZ                ${prefix}_cbfbasilZ.nii.gz 
derivative            cbfspatialZ              ${prefix}_cbfspatialZ.nii.gz 
derivative            cbfpvZ                   ${prefix}_cbfpvZ.nii.gz


output           logfile              ${prefix}_logfile
output           basil_option         ${prefix}_basil_option.txt
output           logfile2             ${prefix}_logfile_spatial

output           cbfbasil            ${prefix}_cbfbasil.nii.gz
output           cbfpatial           ${prefix}_cbfspatial.nii.gz
output           cbfpv               ${prefix}_cbfpv.nii.gz





derivative_set       cbfbasil            Statistic         mean
derivative_set       cbfbasilspatial     Statistic         mean
derivative_set       cbfbasilpv          Statistic         mean
derivative_set       cbfbasilR           Statistic         mean
derivative_set       cbfspatialR         Statistic         mean
derivative_set       cbfpvR              Statistic         mean
derivative_set       cbfbasilZ           Statistic         mean
derivative_set       cbfspatialZ         Statistic         mean
derivative_set       cbfpvZ              Statistic         mean



qc negative_voxels_basil    negativeVoxels_basil   ${prefix}_negativeVoxels.txt


<<DICTIONARY


DICTIONARY

## generate m0
subroutine @1.0 Generate m0

if ! is_image ${m0[sub]} 
   then 
   m0=${out}/basil/${prefix}_m0.nii.gz
   if (( ${basil_inputformat[cxt]} == tc ))
   then
      exec_afni 3dcalc -prefix ${m0}  -a ${intermediate}.nii.gz'[0..$(2)]' -expr "a" 2>/dev/null   
      else
      exec_afni 3dcalc -prefix ${m0}  -a ${intermediate}.nii.gz'[1..$(2)]' -expr "a" 2>/dev/null 
   fi
   exec_fsl fslmaths ${m0} -Tmean ${m0}
   output m0  ${out}/basil/${prefix}_m0.nii.gz
else
   m0=${out}/basil/${prefix}_m0.nii.gz
   exec_fsl fslmaths ${m0[sub]} -Tmean ${m0}
   output m0  ${out}/basil/${prefix}_m0.nii.gz
fi




###################################################################
# Compute cerebral blood flow with basil.
###################################################################
   
if ! is_image ${cbfbasil[cxt]}
 then 
   case ${basil_perfusion[cxt]} in
   
   casl)
      subroutine              @1.1a PCASL/CASL -- Pseudocontinuous ASL
      subroutine              @1.1b Input: ${preprocessed[sub]}
      subroutine              @1.1c M0: ${m0[cxt]}
      subroutine              @1.1d mask: ${mask[sub]}
      subroutine              @1.1e M0 scale: ${basil_m0_scale[cxt]}
      subroutine              @1.1f Partition coefficient: ${basil_lambda[cxt]}
      subroutine              @1.1g Post-labelling delay: ${basil_pld[cxt]}
      subroutine              @1.1i Blood T1: ${basil_t1blood[cxt]}
      subroutine              @1.1j Labelling efficiency: ${basil_alpha[cxt]}
      subroutine              @1.1k Template: ${template}
      subroutine              @1.1n pvgm  : ${gm2seq[sub]}
      subroutine              @1.1o pvwm  : ${wm2seq[sub]}
      

      if [  ${basil_pvc[cxt]} == 1 ]; then
          
          routine @2.1  compute CBF
           exec_xcp perf_asl -i ${preprocessed[sub]}      \
               -m ${mask[sub]}                 \
               -o ${out}/basil                 \
               --struct=${struct2seq_img[sub]}   \
               --casl                          \
               --M0=${m0[cxt]}                 \
               --cgain=${basil_m0_scale[cxt]}  \
               --alpha=${basil_alpha[cxt]}     \
               --iaf=${basil_inputformat[cxt]} \
               --tis=${basil_tis[cxt]}         \
               --spatial                       \
               --tr=${basil_MOTR[cxt]}         \
               --pvgm=${gm2seq[sub]}               \
               --pvwm=${wm2seq[sub]}               \
               --pvcorr 

        elif [ ${basil_pvc[cxt]} == 0 ]; then 

          routine @2.1  compute CBF
         exec_xcp perf_asl -i ${preprocessed[sub]}      \
               -m ${mask[sub]}                 \
               -o ${out}/basil                 \
               --struct=${struct2seq_img[sub]}   \
               --casl                          \
               --M0=${m0[cxt]}                 \
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
      subroutine              @1.1n pvgm  : ${gm2seq[sub]}
      subroutine              @1.1o pvwm  : ${wm2seq[sub]}
      

      if [  ${basil_pvc[cxt]} == 1 ]; then
          
          routine @2.1  compute CBF
           exec_xcp perf_asl -i ${preprocessed[sub]}      \
               -m ${mask[sub]}                 \
               -o ${out}/basil                 \
               --struct=${struct2seq_img[sub]}   \
               --M0=${m0[cxt]}                 \
               --cgain=${basil_m0_scale[cxt]}  \
               --alpha=${basil_alpha[cxt]}     \
               --iaf=${basil_inputformat[cxt]} \
               --tis=${basil_tis[cxt]}         \
               --spatial                       \
               --tr=${basil_MOTR[cxt]}         \
               --pvgm=${gm2seq[sub]}               \
               --pvwm=${wm2seq[sub]}               \
               --pvcorr 


        elif [ ${basil_pvc[cxt]} == 0 ]; then 

          routine @2.1  compute CBF

        exec_xcp perf_asl -i ${preprocessed[sub]}      \
               -m ${mask[sub]}                 \
               -o ${out}/basil                 \
               --struct=${struct2seq_img[sub]}   \
               --M0=${m0[cxt]}                 \
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
    
    exec_fsl immv  $out/basil/cbf_calib   $out/basil/${prefix}_cbfbasil
    exec_fsl immv  $out/basil/cbf   $out/basil/${prefix}_cbf
    exec_fsl immv  $out/basil/cbf_pv_gm_calib   $out/basil/${prefix}_cbfpv
    exec_fsl immv  $out/basil/cbf_pv_wm_calib   $out/basil/${prefix}_cbf_pv_wm_calib
    exec_fsl immv  $out/basil/cbf_pv   $out/basil/${prefix}_cbf_pv
    exec_fsl immv  $out/basil/cbf_pv_gm   $out/basil/${prefix}_cbf_pv_gm
    exec_fsl immv  $out/basil/cbf_pv_wm   $out/basil/${prefix}_cbf_pv_wm
    exec_fsl immv  $out/basil/cbf_spatial_calib   $out/basil/${prefix}_cbfspatial
    exec_fsl immv  $out/basil/cbf_spatial  $out/basil/${prefix}_cbf_spatial
    exec_fsl immv  $out/basil/M0   $out/basil/${prefix}_M0
    exec_fsl immv  $out/basil/mask   $out/basil/${prefix}_mask
    exec_sys mv    $out/basil/basil_option.txt  $out/basil/${prefix}_basil_option.txt
    exec_sys mv    $out/basil/logfile  $out/basil/${prefix}_logfile
    exec_sys mv    $out/basil/logfile_spatial  $out/basil/${prefix}_logfile_spatial
    exec_sys rm -rf $out/basil/${prefix}_cbf.nii.gz $out/basil/${prefix}_cbf_pv_gm_calib.nii.gz 
    exec_sys rm -rf $out/basil/${prefix}_cbf_pv_wm_calib.nii.gz $out/basil/${prefix}_cbf_pv.nii.gz
    exec_sys rm -rf $out/basil/${prefix}_cbf_spatial.nii.gz $out/basil/${prefix}_cbf_pv_gm.nii.gz 
    exec_sys rm -rf $out/basil/${prefix}_cbf_pv_wm.nii.gz $out/basil/cbf_pv_calib.nii.gz
    
 
  elif [ ${basil_pvc[cxt]} == 0 ]; then
  
    exec_fsl immv  $out/basil/acbv   $out/basil/${prefix}_acbv
    exec_fsl immv  $out/basil/acbv_spatial   $out/basil/${prefix}_acbv_spatial
    exec_fsl immv  $out/basil/cbf   $out/basil/${prefix}_cbf
    exec_fsl immv  $out/basil/cbf_calib   $out/basil/${prefix}_cbfbasil
    exec_fsl immv  $out/basil/cbf_spatial_calib   $out/basil/${prefix}_cbfspatial
    exec_fsl immv  $out/basil/cbf_spatial  $out/basil/${prefix}_cbf_spatial
    exec_fsl immv  $out/basil/M0   $out/basil/${prefix}_M0
    exec_fsl immv  $out/basil/mask   $out/basil/${prefix}_mask
    exec_sys mv  $out/basil/basil_option.txt  $out/basil/${prefix}_basil_option.txt
    exec_sys mv  $out/basil/logfile  $out/basil/${prefix}_logfile
    exec_sys mv  $out/basil/logfile_spatial  $out/basil/${prefix}_logfile_spatial
    exec_sys rm -rf $out/basil/${prefix}_cbf.nii.gz $out/basil/${prefix}_cbf_pv_gm_calib.nii.gz 
    exec_sys rm -rf $out/basil/${prefix}_cbf_pv_wm_calib.nii.gz $out/basil/${prefix}_cbf_pv.nii.gz
    exec_sys rm -rf $out/basil/${prefix}_cbf_spatial.nii.gz $out/basil/${prefix}_cbf_pv_gm.nii.gz 
    exec_sys rm -rf $out/basil/${prefix}_cbf_pv_wm.nii.gz $out/basil/${prefix}_cbf.nii.gz
    
 
   fi 
   
   

  exec_sys rm -rf $out/basil/${prefix}_mask_asl.nii.gz
  exec_sys rm -rf $out/basil/${prefix}_M0.nii.gz
  exec_sys rm -rf $out/basil/${prefix}_m0.nii.gz
 
   neg=( $(exec_fsl fslstats $out/basil/${prefix}_cbfbasil.nii.gz          \
              -k    $out/basil/${prefix}_mask.nii.gz  \
              -u    0                                       \
              -V) )
   echo ${neg[0]}   >> ${negative_voxels_basil[cxt]}

 #aslqc 
 if [[ -f ${cbfbasil[cxt]} ]]; then 
   exec_xcp  aslqc.py -i ${cbfbasil[cxt]}  -m ${mask[sub]} -g ${gm2seq[sub]} \
          -w ${wm2seq[sub]} -c ${csf2seq[sub]} -o ${outdir}/${prefix}_cbfbasil
   
   qc cbfbasil_qei   cbfbasil_qei   ${prefix}_cbfbasil_QEI.txt

   zscore_image ${cbfbasil[cxt]} ${cbfbasilZ[cxt]} ${mask[sub]}
   
   
 fi


 if [[ -f ${cbfspatial[cxt]} ]]; then 
   exec_xcp  aslqc.py -i ${cbfspatial[cxt]}  -m ${mask[sub]} -g ${gm2seq[sub]} \
          -w ${wm2seq[sub]} -c ${csf2seq[sub]} -o ${outdir}/${prefix}_cbfspatial
   
   qc cbfspatial_qei   cbfspatial_qei   ${prefix}_cbfspatial_QEI.txt

   zscore_image ${cbfspatial[cxt]} ${cbfspatialZ[cxt]} ${mask[sub]}
   
 fi

  if [[ -f ${cbfpv[cxt]} ]]; then 
   exec_xcp  aslqc.py -i ${cbfpv[cxt]}   -m ${mask[sub]} -g ${gm2seq[sub]} \
          -w ${wm2seq[sub]} -c ${csf2seq[sub]} -o ${outdir}/${prefix}_cbfpv
   
   qc cbfpv_qei   cbfpv_qei   ${prefix}_cbfpv_QEI.txt
   
   zscore_image ${cbfpv[cxt]}  ${cbfpvZ[cxt]} ${mask[sub]}

 fi

fi 
routine_end

completion
