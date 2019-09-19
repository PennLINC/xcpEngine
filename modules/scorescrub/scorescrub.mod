#!/usr/bin/env bash

###################################################################
#  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  #
###################################################################

###################################################################
# SPECIFIC MODULE HEADER
# This module aligns the analyte image to a high-resolution target.
###################################################################
mod_name_short=scorescrub
mod_name='CBF score and scrubbing'
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

##################################################################
# OUTPUTS
###################################################################
derivative            cbfscrub                 ${prefix}_cbfscrub.nii.gz
derivative            cbfscorets               ${prefix}_cbfscore_ts.nii.gz   
derivative            cbfscore                 ${prefix}_cbfscore.nii.gz
derivative            relativecbfscore          ${prefix}_cbfscoreR.nii.gz 
derivative            relativecbfscrub          ${prefix}_cbfscrubR.nii.gz
derivative            zscorecbfscrub           ${prefix}_cbfscrubZ.nii.gz
derivative            zscorecbfscore           ${prefix}_cbfscoreZ.nii.gz
derivative            cbfscore_tsnr            ${prefix}_cbfscore_tsnr.nii.gz 

output                cbfscorets      ${prefix}_cbfscore_ts.nii.gz   
output                cbfscore        ${prefix}_cbfscore.nii.gz
output                cbfscrub        ${prefix}_cbfscrub.nii.gz
output                relativecbfscore         ${prefix}_cbfscoreR.nii.gz
output                relativecbfscrub         ${prefix}_cbfscrubR.nii.gz
output                zscorecbfscrub           ${prefix}_cbfscrubZ.nii.gz
output                zscorecbfscore           ${prefix}_cbfscoreZ.nii.gz
output                cbfscore_tsnr            ${prefix}_cbfscore_tsnr.nii.gz 

qc nvoldel  nvoldel  ${prefix}_nvoldel.txt 


derivative_set       cbfscrub            Statistic         mean
derivative_set       cbfscore            Statistic         mean
derivative_set       relativecbfscore    Statistic         mean
derivative_set       relativecbfscrub    Statistic         mean
derivative_set       cbfscore_tsnr       Statistic         mean
derivative_set       zscorecbfscore      Statistic         mean 
derivative_set       zscorecbfscrub      Statistic         mean 

process              cbfscorets        ${prefix}_cbfscore_ts


    

    subroutine  @1.2 computing cbf score
  # obtain the score 
        exec_xcp score.R                 \
             -i     ${perfusion[sub]}       \
             -y     ${gm2seq[sub]}          \
             -w     ${wm2seq[sub]}           \
             -c     ${csf2seq[sub]}          \
             -t     ${scorescrub_thresh[cxt]} \
             -o     ${outdir}/${prefix}

     output cbfscorets  ${prefix}_cbfscore_ts.nii.gz

    subroutine  @1.3 computing cbf scrubbing
 # compute the scrub 
        exec_xcp  scrub_cbf.R           \
            -i     ${cbfscorets[cxt]} \
            -y     ${gm2seq[sub]}           \
            -w     ${wm2seq[sub]}         \
            -c     ${csf2seq[sub]}          \
            -m     ${mask[sub]} \
            -t     ${scorescrub_thresh[cxt]} \
            -o     ${outdir}/${prefix}

   #aslqc 
   exec_xcp  aslqc.py -i ${cbfscorets[cxt]}  -m ${mask[sub]} -g ${gm2seq[sub]} \
          -w ${wm2seq[sub]} -c ${csf2seq[sub]} -o ${outdir}/${prefix}_cbfscore
   
   output  cbfscore_tsnr ${prefix}_cbfscore_tsnr.nii.gz
   qc cbf_tsnr  cbf_tsnr  ${prefix}_cbfscore_meantsnr.txt
   qc cbfscore_qei   cbfscore_qei   ${prefix}_cbfscore_QEI.txt

   exec_xcp  aslqc.py -i ${cbfscrub[cxt]}  -m ${mask[sub]} -g ${gm2seq[sub]} \
          -w ${wm2seq[sub]} -c ${csf2seq[sub]} -o ${outdir}/${prefix}_cbfscrub
   
   qc cbfscrub_qei   cbfscrub_qei   ${prefix}_cbfscrub_QEI.txt
   #compute relative CBF 

   zscore_image ${cbfscrub[cxt]} ${zscorecbfscrub[cxt]} ${mask[sub]} 
   zscore_image ${cbfscore[cxt]} ${zscorecbfscore[cxt]} ${mask[sub]} 


   qc meanZcbfscore  meanZcbfscore ${prefix}_cbfscoreZ.txt 
   meanzcbfscore=$(fslstats ${zscorecbfscore[cxt]} -k  ${gm2seq[sub]} -M)
   echo ${meanzcbfscore} >> ${meanZcbfscore[cxt]}

   qc meanZcbfscrub  meanZcbfscrub ${prefix}_cbfscrubZ.txt 
   meanzcbfscrub=$(fslstats ${zscorecbfscrub[cxt]} -k  ${gm2seq[sub]} -M)
   echo ${meanzcbfscrub} >> ${meanZcbfscrub[cxt]}

  
routine_end  

completion