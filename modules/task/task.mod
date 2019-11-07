#!/usr/bin/env bash

###################################################################
#  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  #
###################################################################

###################################################################
# SPECIFIC MODULE HEADER
# This module runs an FSL design for task activation statistics.
###################################################################
mod_name_short=task
mod_name='TASK-CONSTRAINED ACTIVATION MODULE'
mod_head=${XCPEDIR}/core/CONSOLE_MODULE_RC

#######################
############################################
# GENERAL MODULE HEADER
###################################################################
source ${XCPEDIR}/core/constants
source ${XCPEDIR}/core/functions/library.sh
source ${XCPEDIR}/core/functions/library_func.sh
source ${XCPEDIR}/core/parseArgsMod

###################################################################
# MODULE COMPLETION
###################################################################
completion() {
   if is_image ${referenceVolumeBrain[cxt]}
      then
      space_set   ${spaces[sub]}    ${space[sub]} \
            Map   ${referenceVolumeBrain[cxt]}
   fi
   
   output   featdir                 ${featdir[cxt]}.feat
   source   ${XCPEDIR}/core/auditComplete
   source   ${XCPEDIR}/core/updateQuality
   source   ${XCPEDIR}/core/moduleEnd
}

###################################################################
# HELPER FUNCTION -- for FEAT reorganisation
###################################################################
reorg(){
   mv    ${1} ${2} 2>/dev/null
   rln   ${2} ${1}
}





###################################################################
# OUTPUTS
###################################################################
derivative  referenceVolumeBrain    ${prefix}_referenceVolumeBrain
derivative  meanIntensityBrain      ${prefix}_meanIntensityBrain
derivative  mask                    ${prefix}_mask

derivative_set    mask Type         Mask

output      referenceVolume         ${prefix}_referenceVolume.nii.gz
output      meanIntensity           ${prefix}_meanIntensity.nii.gz
output      confmat                 ${prefix}_confmat.1D
output      fsf                     model/${prefix}_design.fsf
output      mcdir                   mc
output      rps                     mc/${prefix}_realignment.1D
output      abs_rms                 mc/${prefix}_absRMS.1D
output      abs_mean_rms            mc/${prefix}_absMeanRMS.txt
output      rel_rms                 mc/${prefix}_relRMS.1D
output      rmat                    mc/${prefix}.mat

define      featdir                 ${outdir}/fsl/${prefix}

qc rel_max_rms  relMaxRMSMotion     mc/${prefix}_relMaxRMS.txt
qc rel_mean_rms relMeanRMSMotion    mc/${prefix}_relMeanRMS.txt
qc coreg_cross_corr  coregCrossCorr ${prefix}_coregCrossCorr.txt
qc coreg_coverage    coregCoverage  ${prefix}_coregCoverage.txt
qc coreg_jaccard     coregJaccard   ${prefix}_coregJaccard.txt
qc coreg_dice        coregDice      ${prefix}_coregDice.txt

temporal_mask_prime

declare_copes() {
for i in ${!cpe[@]}
   do
   derivative     contrast${i}_${cpe[i]}                 \
                  copes/${prefix}_contrast${i}_${cpe[i]}
   derivative     sigchange_contrast${i}_${cpe[i]}       \
                  sigchange/${prefix}_sigchange_contrast${i}_${cpe[i]}
   derivative     varcope${i}_${cpe[i]}                  \
                  varcopes/${prefix}_varcope${i}_${cpe[i]}
   derivative     zstat${i}_${cpe[i]}                    \
                  stats/${prefix}_zstat${i}
   derivative_set sigchange_contrast${i}_${cpe[i]}       \
                  Statistic      mean
   derivative_set zstat${i}_${cpe[i]}                    \
                  Statistic      mean
done
}

process     processed               ${prefix}_processed

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


# check if the design is subject specific or group 
if [[ -f ${task_design[sub]} ]]; then 
     task_design[cxt]=${task_design[sub]}
fi

###################################################################
# Localise the FSL design file.
###################################################################
routine                       @1    Localising FEAT design
exec_sys mkdir -p ${outdir}/model
printx            ${task_design[cxt]} >> ${intermediate}-fsf.dsn
mapfile           fsf_design           < ${intermediate}-fsf.dsn


native_orientation=$(${AFNI_PATH}/3dinfo -orient ${img})
template_orientation=$(${AFNI_PATH}/3dinfo -orient ${template})

echo "NATIVE:${native_orientation} TEMPLATE:${template_orientation}"
full_intermediate=$(ls ${img} | head -n 1)
if [ "${native_orientation}" != "${template_orientation}" ]
then

    subroutine @0.1d "${native_orientation} -> ${template_orientation}"
    ${AFNI_PATH}/3dresample -orient ${template_orientation} \
              -inset ${full_intermediate} \
              -prefix ${intermediate}_${template_orientation}.nii.gz -overwrite
    intermediate=${intermediate}_${template_orientation}
    intermediate_root=${intermediate}
    img=${intermediate}.nii.gz
    
else

    subroutine  @0.1d "NOT re-orienting native"

fi


if (( ${task_fmriprep[cxt]} == 1 ))
   then 
        ########################################
        # to obtain fmriprep mask etc and struct
  
        ########################################
        
         routine @ getting data from frmiprep directory 
                  
        imgprt=${img1[sub]%_*_*_*}; conf="_desc-confounds_regressors.tsv"
        exec_sys cp ${imgprt}${conf} ${out}/task/${prefix}_fmriconf.tsv
        imgprt2=${img1[sub]%_*_*}; mskpart="_desc-brain_mask.nii.gz"
        mask1=${imgprt2}${mskpart}; maskpart2=${mask1#*_*_*_*}
        refpart="_boldref.nii.gz"; refvol=${imgprt2}${refpart}
         
       output fmriprepconf  ${out}/task/${prefix}_fmriconf.tsv 
       output    rps       ${out}/task/${prefix}_motion.1D
        exec_xcp generate_confmat.R \
         -i ${fmriprepconf[cxt]} \
         -j rps \
         -o ${rps[cxt]}




         strucn="${img1[sub]%/*/*}";
         strucfile=$(ls -f ${strucn}/anat/*h5 2>/dev/null)
         strucfile1=$(echo $strucfile | cut --delimiter " " --fields 1) 

         if [[ -f ${strucfile1}  ]]; then  
                  strucn=${strucn}
         else

          anatdir=$strucn/../
          
          strucn=${anatdir}

         fi
         
         if [[ -d ${antsct[sub]} ]]; then
               subroutine @ generate mask and structural head/mask 
              
               structmask=$(ls -d ${strucn}/anat/*${maskpart2})

               subroutine @ reoreint the reference volume/mask to template orientation
               exec_afni 3dresample -orient ${template_orientation} -inset ${refvol} -prefix  \
                   ${out}/task/${prefix}_referenceVolume.nii.gz -overwrite
             
               output referenceVolume  ${out}/task/${prefix}_referenceVolume.nii.gz
               
               exec_afni 3dresample -orient ${template_orientation} \
                  -inset ${mask1} -prefix ${prefix}_imgmask.nii.gz -overwrite

               exec_afni 3dresample -master ${out}/task/${prefix}_referenceVolume.nii.gz \
                  -inset ${structmask}  -prefix ${prefix}_structmask.nii.gz -overwrite

               exec_fsl fslmaths ${prefix}_imgmask.nii.gz -mul ${prefix}_structmask.nii.gz \
                      ${out}/task/${prefix}_mask.nii.gz

                output mask  ${out}/task/${prefix}_mask.nii.gz
                
                rm ${prefix}_imgmask.nii.gz

               exec_afni 3dresample -master ${mask[cxt]} \
                   -inset ${segmentation[sub]}  \
                  -prefix ${out}/task/${prefix}_segmentation.nii.gz -overwrite

               output segmentation  ${out}/task/${prefix}_segmentation.nii.gz

               exec_fsl fslmaths  ${mask[cxt]} -mul \
                   ${referenceVolume[cxt]} \
                   ${out}/task/${prefix}_referenceVolumeBrain.nii.gz 
                   
               output referenceVolumeBrain ${out}/task/${prefix}_referenceVolumeBrain.nii.gz
   
             
               exec_afni 3dresample -master ${referenceVolume[cxt]} \
                   -inset ${struct[sub]}   -prefix ${out}/task/${prefix}_struct.nii.gz -overwrite
 
               output struct  ${out}/task/${prefix}_struct.nii.gz
               exec_fsl  fslmaths ${mask[cxt]} -mul ${out}/task/${prefix}_struct.nii.gz \
                ${out}/task/${prefix}_structbrain.nii.gz
               
               output struct_head ${out}/task/${prefix}_structbrain.nii.gz  
               exec_sys rm -rf ${prefix}_structmask.nii.gz

               subroutine        @  generate new ${spaces[sub]} with spaceMetadata

               rm -f ${spaces[sub]}
               echo '{}'  >> ${spaces[sub]} 2>/dev/null 
               mnitoas="    $(ls -d ${XCPEDIR}/space/OASIS/OASIS_transforms/MNI-OASIS_0Affine.mat)
                           $(ls -d ${XCPEDIR}/space/OASIS/OASIS_transforms/MNI-OASIS_1Warp.nii.gz)"
                oas2mni="  $(ls -d ${XCPEDIR}/space/OASIS/OASIS_transforms/OASIS-MNI_0Warp.nii.gz)
                          $(ls -d ${XCPEDIR}/space/OASIS/OASIS_transforms/OASIS-MNI_1Affine.mat)"
                       
                       mnitoas=$( echo ${mnitoas})
                       oas2mni=$(echo ${oas2mni})
                       mnitoas=${mnitoas// /,}
                       oas2mni=${oas2mni// /,}

                       ${XCPEDIR}/utils/spaceMetadata  \
                         -o ${spaces[sub]}                 \
                         -f MNI%2x2x2:${XCPEDIR}/space/MNI/MNI-2x2x2.nii.gz        \
                         -m OASIS%2x2x2:${XCPEDIR}/space/OASIS/OASIS-2x2x2.nii.gz \
                         -x ${oas2mni} -i ${mnitoas}     \
                         -s ${spaces[sub]} 2>/dev/null

               mnitopnc=" $(ls -d ${XCPEDIR}/space/PNC/PNC_transforms/MNI-PNC_0Affine.mat)
                        $(ls -d ${XCPEDIR}/space/PNC/PNC_transforms/MNI-PNC_1Warp.nii.gz)"
               pnc2mni=" $(ls -d ${XCPEDIR}/space/PNC/PNC_transforms/PNC-MNI_0Warp.nii.gz)
                        $(ls -d ${XCPEDIR}/space/PNC/PNC_transforms/PNC-MNI_1Affine.mat)"
               mnitopnc=$( echo ${mnitopnc})
               pnc2mni=$(echo ${pnc2mni})
               mnitopnc=${mnitopnc// /,}
               pnc2mni=${pnc2mni// /,}

               ${XCPEDIR}/utils/spaceMetadata          \
                    -o ${spaces[sub]}                 \
                    -f MNI%2x2x2:${XCPEDIR}/space/MNI/MNI-2x2x2.nii.gz        \
                    -m PNC%2x2x2:${XCPEDIR}/space/PNC/PNC-2x2x2.nii.gz \
                    -x ${pnc2mni}                               \
                    -i ${mnitopnc}                               \
                    -s ${spaces[sub]} 2>/dev/null


              hd=',MapHead='${struct_head[cxt]}
              subj2temp="   $(ls -d ${antsct[sub]}/*SubjectToTemplate0GenericAffine.mat)
                           $(ls -d ${antsct[sub]}/*SubjectToTemplate1Warp.nii.gz)"
              temp2subj="   $(ls -d ${antsct[sub]}/*TemplateToSubject0Warp.nii.gz) 
                          $(ls -d ${antsct[sub]}/*TemplateToSubject1GenericAffine.mat)"
              subj2temp=$( echo ${subj2temp})
              temp2subj=$(echo ${temp2subj})
              subj2temp=${subj2temp// /,}
              temp2subj=${temp2subj// /,}

              ${XCPEDIR}/utils/spaceMetadata          \
                    -o ${spaces[sub]}                 \
                    -f ${standard}:${template}        \
                    -m ${structural[sub]}:${struct[cxt]}${hd} \
                    -x ${subj2temp}                               \
                    -i ${temp2subj}                               \
                    -s ${spaces[sub]} 2>/dev/null
               
             
                intermediate=${intermediate}_${cur} 
               

         
               
          else 
               #  find which template is present 
               b1=${img1[sub]##*space-}; 
               if [[ ${b1} == ${img1[sub]} ]]; then 
                echo \
                "The bold is in native space, xcpEngine is not 
                supporting native space now.  
                "
                exit 1
               fi 
               
               template_label=${b1%%_*} 
               if [[ ${template_label} != 'T1w' ]]; then 

                   struct1=$( ls -d $strucn/anat/*${template_label}*desc-preproc_T1w.nii.gz)
                   segmentation1=$(ls -d  $strucn/anat/*${template_label}*dseg.nii.gz)
                   structmask=$(ls -d  $strucn/anat/*${template_label}*desc-brain_mask.nii.gz)
                   onetran=${XCPEDIR}/utils/oneratiotransform.txt

                   subroutine        @ checking refvolume and structural orientation
                   exec_afni 3dresample -orient  ${template_orientation} \
                           -inset ${refvol} -prefix  ${out}/task/${prefix}_referenceVolume.nii.gz -overwrite

                  output referenceVolume  ${out}/task/${prefix}_referenceVolume.nii.gz
   
                  exec_afni 3dresample -master  ${referenceVolume[cxt]} \
                           -inset ${struct1} -prefix  ${out}/task/${prefix}_struct.nii.gz -overwrite

                      #output struct_head ${out}/task/${prefix}_struct.nii.gz
                  output struct  ${out}/task/${prefix}_struct.nii.gz
                  output struct_head  ${out}/task/${prefix}_struct.nii.gz

                  exec_afni 3dresample -master  ${referenceVolume[cxt]} \
                           -inset ${struct[cxt]} -prefix  ${out}/task/${prefix}_struct.nii.gz -overwrite
                       
                  exec_afni 3dresample -master  ${referenceVolume[cxt]} \
                           -inset ${segmentation1} -prefix  ${out}/task/${prefix}_segmentation.nii.gz -overwrite

                  output segmentation  ${out}/task/${prefix}_segmentation.nii.gz

                  subroutine        @  generate mask and referenceVolumeBrain 
                  exec_afni 3dresample -master ${referenceVolume[cxt]} \
                          -inset ${structmask}  -prefix ${prefix}_structmask.nii.gz -overwrite
                  exec_fsl fslmaths ${mask1} -mul ${prefix}_structmask.nii.gz \
                      ${out}/task/${prefix}_mask.nii.gz
                  output mask  ${out}/task/${prefix}_mask.nii.gz
                  exec_afni 3dresample -master  ${referenceVolume[cxt]} \
                      -inset ${mask[cxt]} -prefix  ${out}/task/${prefix}_mask.nii.gz -overwrite
                  exec_fsl fslmaths  ${mask[cxt]} -mul ${referenceVolume[cxt]} \
                          ${out}/task/${prefix}_referenceVolumeBrain.nii.gz       
                  output referenceVolumeBrain ${out}/task/${prefix}_referenceVolumeBrain.nii.gz 

                  rm -f ${spaces[sub]}
                       echo '{}'  >> ${spaces[sub]}
                       mnitoas="    $(ls -d ${XCPEDIR}/space/OASIS/OASIS_transforms/MNI-OASIS_0Affine.mat)
                           $(ls -d ${XCPEDIR}/space/OASIS/OASIS_transforms/MNI-OASIS_1Warp.nii.gz)"
                      oas2mni="  $(ls -d ${XCPEDIR}/space/OASIS/OASIS_transforms/OASIS-MNI_0Warp.nii.gz)
                          $(ls -d ${XCPEDIR}/space/OASIS/OASIS_transforms/OASIS-MNI_1Affine.mat)"
                       
                       mnitoas=$( echo ${mnitoas})
                       oas2mni=$(echo ${oas2mni})
                       mnitoas=${mnitoas// /,}
                       oas2mni=${oas2mni// /,}

                       ${XCPEDIR}/utils/spaceMetadata  \
                         -o ${spaces[sub]}                 \
                         -f MNI%2x2x2:${XCPEDIR}/space/MNI/MNI-2x2x2.nii.gz        \
                         -m OASIS%2x2x2:${XCPEDIR}/space/OASIS/OASIS-2x2x2.nii.gz \
                         -x ${oas2mni} -i ${mnitoas}     \
                         -s ${spaces[sub]} 2>/dev/null

                       mnitopnc=" $(ls -d ${XCPEDIR}/space/PNC/PNC_transforms/MNI-PNC_0Affine.mat)
                                    $(ls -d ${XCPEDIR}/space/PNC/PNC_transforms/MNI-PNC_1Warp.nii.gz)"
                       pnc2mni=" $(ls -d ${XCPEDIR}/space/PNC/PNC_transforms/PNC-MNI_0Warp.nii.gz)
                                    $(ls -d ${XCPEDIR}/space/PNC/PNC_transforms/PNC-MNI_1Affine.mat)"
                       mnitopnc=$( echo ${mnitopnc})
                       pnc2mni=$(echo ${pnc2mni})
                       mnitopnc=${mnitopnc// /,}
                       pnc2mni=${pnc2mni// /,}

                       ${XCPEDIR}/utils/spaceMetadata          \
                         -o ${spaces[sub]}                 \
                         -f MNI%2x2x2:${XCPEDIR}/space/MNI/MNI-2x2x2.nii.gz        \
                         -m PNC%2x2x2:${XCPEDIR}/space/PNC/PNC-2x2x2.nii.gz \
                         -x ${pnc2mni}                               \
                         -i ${mnitopnc}                               \
                         -s ${spaces[sub]} 2>/dev/null
                       hd=',MapHead='${struct_head[cxt]}
                   
                       ${XCPEDIR}/utils/spaceMetadata          \
                         -o ${spaces[sub]}                 \
                         -f ${standard}:${template}        \
                         -m ${structural[sub]}:${struct[cxt]}${hd} \
                         -x ${onetran}                               \
                         -i ${onetran}                               \
                         -s ${spaces[sub]} 2>/dev/null

                         
                         intermediate=${intermediate}_${cur} 
                
                else 
                  
                  template_label1=${standard%'%'*}
                  temptot1w1=$(find $strucn/anat/ -type f -name "*${template_label1}*to-T1w_mode-image_xfm.h5")
                  t1wtotemp1=$(find $strucn/anat/ -type f -name "*from-T1w_to*${template_label1}*_mode-image_xfm.h5")

                  temptot1w=$(echo $temptot1w1 | cut --delimiter " " --fields 1) 
                  t1wtotemp=$(echo $t1wtotemp1 | cut --delimiter " " --fields 1) 
                   
                   echo \
                   "
                   The template is ${template_label1}
                   xcpEngine only support MNI, PNC and OASIS templates for now
                   "

                  struct1=$(find $strucn/anat/ -type f -name "*desc-preproc_T1w.nii.gz" -not -path  "*MNI*" -not -path "*space*" ) 
                  segmentation1=$(find $strucn/anat/ -type f -name "*dseg.nii.gz" -not -path  "*MNI*" -not -path "*aseg*" -not -path "*space*")
                  structmask=$(find $strucn/anat/ -type f -name "*desc-brain_mask.nii.gz" -not -path  "*MNI*" -not -path  "*space*")
                    
                 exec_afni 3dresample -orient ${template_orientation} -inset ${refvol} \
                       -prefix  ${out}/task/${prefix}_referenceVolume.nii.gz -overwrite
                    output referenceVolume  ${out}/task/${prefix}_referenceVolume.nii.gz
                   

                   exec_afni 3dresample -orient ${template_orientation} \
                    -inset ${mask1} -prefix  ${prefix}_imgmask.nii.gz -overwrite
                   

                   exec_afni 3dresample -master ${referenceVolume[cxt]} \
                     -inset ${structmask} -prefix $out/task/${prefix}_structmask.nii.gz -overwrite

                   exec_fsl fslmaths  ${prefix}_imgmask.nii.gz -mul $out/task/${prefix}_structmask.nii.gz  ${out}/task/${prefix}_mask.nii.gz
                   output mask  ${out}/task/${prefix}_mask.nii.gz
                    rm  ${prefix}_imgmask.nii.gz

                  exec_afni 3dresample -master ${referenceVolume[cxt]} -inset ${segmentation1}   \
                         -prefix ${out}/task/${prefix}_segmentation.nii.gz -overwrite
              
                  output segmentation  ${out}/task/${prefix}_segmentation.nii.gz

                  exec_afni 3dresample -master ${referenceVolume[cxt]} -inset ${struct1}   \
                                -prefix ${out}/task/${prefix}_struct.nii.gz -overwrite

                  output struct_head ${out}/task/${prefix}_struct.nii.gz
                  output struct ${out}/task/${prefix}_struct.nii.gz
                
                   exec_fsl fslmaths  ${mask[cxt]} -mul ${referenceVolume[cxt]} \
                         ${out}/task/${prefix}_referenceVolumeBrain.nii.gz 
                   output referenceVolumeBrain ${out}/task/${prefix}_referenceVolumeBrain.nii.gz
                 
                   exec_fsl  fslmaths ${mask[cxt]} -mul ${out}/task/${prefix}_struct.nii.gz \
                   ${out}/task/${prefix}_structbrain.nii.gz
               
                   output struct_head ${out}/task/${prefix}_structbrain.nii.gz 

                   exec_sys rm -rf $out/task/${prefix}_structmask.nii.gz
                
                   subroutine        @  generate new ${spaces[sub]} with spaceMetadata
                   rm -f ${spaces[sub]}
                echo '{}'  >> ${spaces[sub]}


                mnitoas="    $(ls -d ${XCPEDIR}/space/OASIS/OASIS_transforms/MNI-OASIS_0Affine.mat)
                           $(ls -d ${XCPEDIR}/space/OASIS/OASIS_transforms/MNI-OASIS_1Warp.nii.gz)"
                oas2mni="  $(ls -d ${XCPEDIR}/space/OASIS/OASIS_transforms/OASIS-MNI_0Warp.nii.gz)
                          $(ls -d ${XCPEDIR}/space/OASIS/OASIS_transforms/OASIS-MNI_1Affine.mat)"
                       
                       mnitoas=$( echo ${mnitoas})
                       oas2mni=$(echo ${oas2mni})
                       mnitoas=${mnitoas// /,}
                       oas2mni=${oas2mni// /,}

                       ${XCPEDIR}/utils/spaceMetadata  \
                         -o ${spaces[sub]}                 \
                         -f MNI%2x2x2:${XCPEDIR}/space/MNI/MNI-2x2x2.nii.gz        \
                         -m OASIS%2x2x2:${XCPEDIR}/space/OASIS/OASIS-2x2x2.nii.gz \
                         -x ${oas2mni} -i ${mnitoas}     \
                         -s ${spaces[sub]} 2>/dev/null


                mnitopnc="    $(ls -d ${XCPEDIR}/space/PNC/PNC_transforms/MNI-PNC_0Affine.mat)
                           $(ls -d ${XCPEDIR}/space/PNC/PNC_transforms/MNI-PNC_1Warp.nii.gz)"
                pnc2mni="  $(ls -d ${XCPEDIR}/space/PNC/PNC_transforms/PNC-MNI_0Warp.nii.gz)
                          $(ls -d ${XCPEDIR}/space/PNC/PNC_transforms/PNC-MNI_1Affine.mat)"
                       
                       mnitopnc=$(echo ${mnitopnc})
                       pnc2mni=$(echo ${pnc2mni})
                       mnitopnc=${mnitopnc// /,}
                       pnc2mni=${pnc2mni// /,}

                       ${XCPEDIR}/utils/spaceMetadata  \
                         -o ${spaces[sub]}                 \
                         -f MNI%2x2x2:${XCPEDIR}/space/MNI/MNI-2x2x2.nii.gz        \
                         -m PNC%2x2x2:${XCPEDIR}/space/PNC/PNC-2x2x2.nii.gz \
                         -x ${pnc2mni} -i ${mnitopnc}     \
                         -s ${spaces[sub]} 2>/dev/null




                hd=',MapHead='${struct_head[cxt]}

               ${XCPEDIR}/utils/spaceMetadata          \
                         -o ${spaces[sub]}                         \
                         -f ${standard}:${template}                \
                         -m ${structural[sub]}:${struct[cxt]}${hd} \
                         -i ${temptot1w}                                \
                         -x ${t1wtotemp}                               \
                         -s ${spaces[sub]} 2>/dev/null

                intermediate=${intermediate}_${cur} 
                
                
            fi 

       fi
    subroutine        @  Quality assessment
    
   
    registration_quality=( $(exec_xcp \
      maskOverlap.R           \
      -m ${segmentation[cxt]}   \
      -r ${referenceVolumeBrain[cxt]}) )
    echo  ${registration_quality[0]} > ${coreg_cross_corr[cxt]}
    echo  ${registration_quality[1]} > ${coreg_coverage[cxt]}
    echo  ${registration_quality[2]} > ${coreg_jaccard[cxt]}
    echo  ${registration_quality[3]} > ${coreg_dice[cxt]}

      routine_end 
fi
      

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
trep=$(exec_fsl               fslval ${img} pixdim4)
nvol=$(exec_fsl               fslval ${img} dim4)
for l in "${!fsf_design[@]}"
   do
   line="${fsf_design[l]}"
   [[ -z $(echo ${line}) ]]   && continue
   
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
   chk_FTW=( "${line}"        'set fmri\(featwatcher_yn'    )

   
 
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
   contains  "${chk_TDX[@]}"        \
             && line=${line//set fmri\(deriv_yn/} \
             && indx=${line/%\)*/}  \
             && name=${line#*\ }    \
             && tdx[indx]=${name//\"/} \
             && continue
   
   contains  "${chk_OUT[@]}" \
             && fsf_design[l]='set fmri(outputdir) '${featdir[cxt]}'\n' \
             && continue
   contains  "${chk_STD[@]}" \
             && fsf_design[l]='set fmri(regstandard) '${template}'\n' \
             && continue
   contains  "${chk_IMG[@]}" \
             && fsf_design[l]='set feat_files(1) '${img}'\n' \
             && continue
   contains  "${chk_REF[@]}" \
             && fsf_design[l]='set fmri(alternative_example_func) '${referenceVolume[cxt]}'\n' \
             && continue
   contains  "${chk_MSK[@]}" \
             && fsf_design[l]='set fmri(alternative_mask) '${mask[cxt]}'\n' \
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
             && coni=${l}    \
             && conf_include=${line//set fmri(confoundevs) /} \
             && continue
   contains  "${chk_COF[@]}" \
             && conf=${l}    \
             && continue
   contains  "${chk_FTW[@]}" \
             && fsf_design[l]='set fmri(featwatcher_yn) 0' \
             && continue
done





if (( ${conf_include} == 1 ))
   then
   subroutine                 @1.2  Importing confounds
   if (( ${task_rpsd[cxt]} > 0)); then 
   subroutine                 @1.2.1a  remvoing the first ${task_rpsd[cxt]} confound
   exec_xcp removetaskpnts.R -n  ${task_rpsd[cxt]} -t ${rps[cxt]} -p ${rps[cxt]}
   fi

   if is+numeric ${conf}
      then
      subroutine              @1.2.1
      fsf_design[conf]='set confoundev_files(1) '${rps[cxt]}'\n'
   else
      subroutine              @1.2.2
      fsf_design[coni]='set fmri(confoundevs) 1\n\n# Confound EVs text file for analysis 1\nset confoundev_files(1) '${rps[cxt]}'\n'
   fi
fi
exec_sys    rm -f ${fsf[cxt]}
printf      '%b' "${fsf_design[@]}"                 >>  ${fsf[cxt]}
routine_end





###################################################################
# Declare each contrast and % signal change map as a derivative.
###################################################################
declare_copes





###################################################################
# Execute analysis in FEAT. Deactivate autosubmission before
# calling FEAT, and reactivate after FEAT is complete.
###################################################################
if ! is_image ${featdir[cxt]}.feat/filtered_func_data.nii.gz \
|| rerun
   then
   routine                    @2    Executing FEAT analysis
   subroutine                 @2.1  Preparing environment
   buffer=${SGE_ROOT}
   unset    SGE_ROOT
   exec_sys rm -rf            ${featdir[cxt]}.feat
   subroutine                 @2.2a Processing FEAT design:
   subroutine                 @2.2b ${fsf[cxt]}
   exec_fsl feat                    ${fsf[cxt]}          >/dev/null
   SGE_ROOT=${buffer}
   featout=$(ls -d1 ${featdir[cxt]}.feat 2>/dev/null)
   routine_end
else
   featout=$(ls -d1 ${featdir[cxt]}.feat 2>/dev/null)
fi





###################################################################
# Reorganise the FEAT output.
###################################################################
if [[ -d ${featout} ]]
   then
   routine                    @3    Reorganising FEAT output
   ################################################################
   # * Image localisation
   ################################################################
   exec_sys reorg ${featout}/mask.nii.gz         ${mask[cxt]}
   exec_sys reorg ${featout}/example_func.nii.gz ${referenceVolume[cxt]}
   exec_sys reorg ${featout}/mean_func.nii.gz    ${meanIntensity[cxt]}
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
      exec_sys reorg ${featout}/confoundevs.txt   ${confmat[cxt]}
   fi

   ################################################################
   # * Motion variables
   ################################################################
   if [[ -e ${featout}/mc/ ]]
      then
      subroutine              @3.4  Re-localising motion metrics
      [[ -d ${rmat[cxt]} ]] && exec_sys rm -rf     ${rmat[cxt]}
      exec_sys mkdir -p ${mcdir[cxt]}
      exec_sys reorg ${featout}/mc/*mcf.par       ${rps[cxt]}
      exec_sys reorg ${featout}/mc/*mcf_rel.rms   ${rel_rms[cxt]}
      exec_sys reorg ${featout}/mc/*rel_mean.rms  ${rel_mean_rms[cxt]}
      exec_sys reorg ${featout}/mc/*abs.rms       ${abs_rms[cxt]}
      exec_sys reorg ${featout}/mc/*abs_mean.rms  ${abs_mean_rms[cxt]}
      exec_sys reorg ${featout}/mc/*.mat          ${rmat[cxt]}
      exec_sys reorg ${featout}/mc/*.png          ${mcdir[cxt]}
     
   exec_xcp 1dTool.R             \
         -i    ${rel_rms[cxt]}      \
         -o    max                  \
         -f    ${rel_max_rms[cxt]}

   #temporal_mask  --SIGNPOST=${signpost}        \
                     #--INPUT=${featout}/filtered_func_data.nii.gz \
                     #--RPS=${rps[cxt]}             \
                     #--RMS=${rel_rms[cxt]}         \
                     #--THRESH=${task_framewise[cxt]}
   fi

   ################################################################
   #  * FEAT design and model
   ################################################################
   subroutine                 @3.5  Re-localising model design
   dsnfiles=$(exec_sys ls -d ${featout}/design*)
   for i in ${dsnfiles}
      do
      fname=${i//${featout}\//}
      exec_sys reorg ${i} ${outdir}/model/${prefix}_${fname}
   done

   ################################################################
   #  * Logs
   ################################################################
   if [[ -d ${featout}/logs ]]
      then
      subroutine              @3.6
      exec_sys reorg ${featout}/logs               ${outdir}/logs
      exec_sys reorg ${featout}/report_log.html    ${outdir}/logs/report_log.html
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
   done                       <     ${outdir}/model/${prefix}_design.mat
   mag=(        ${line}       )
   unset        mag[0]

   if [[ -n $(ls ${featout}/stats/pe* 2>/dev/null) ]]
      then
      subroutine              @4.2  Raw parameter estimates
      exec_sys                mkdir -p ${outdir}/pes
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
         par_out=${outdir}/pes/${prefix}_pe${cidx}
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
            is_dx=$(echo ${tdx[fidx]})
            cname=$(echo ${par[fidx]})
            [[ -z ${cname}       ]] && cname=confound && is_dx=0
            par_pe=${par_out}${cname}.nii.gz
            psc_pe=${psc_out}${cname}.nii.gz
            par_dx=${par_out}${cname}_tderiv.nii.gz
            psc_dx=${psc_out}${cname}_tderiv.nii.gz
            
            exec_sys reorg   ${pe} ${par_pe}
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
            exec_sys reorg    ${pe} ${par_dx}
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
      chk_MAG=(   "${line}"            '/PPheights'   )
      contains    "${chk_MAG[@]}"      && break
   done                       <        ${outdir}/model/${prefix}_design.con
   mag=(          ${line}       )
   unset          mag[0]

   if [[ -n $(ls ${featout}/stats/cope* 2>/dev/null) ]]
      then
      subroutine              @4.7  Contrasts
      exec_sys                mkdir -p ${outdir}/copes
      exec_sys                mkdir -p ${outdir}/varcopes
      exec_sys                mkdir -p ${outdir}/sigchange
      #############################################################
      # Loop over contrasts.
      #############################################################
      for i in ${!cpe[@]}
         do
         subroutine           @4.8  ${cpe[i]}
         cname=$(echo ${cpe[i]//[![:alnum:]|_]})
         [[ -z ${cname} ]] && cname=unknown && is_dx=0
         con_i=${featout}/stats/cope${i}.nii.gz
         var_i=${featout}/stats/varcope${i}.nii.gz
         con_o='contrast'${i}'_'${cname}'['${cxt}']'
         var_o='varcope'${i}'_'${cname}'['${cxt}']'
         psc_o='sigchange_contrast'${i}'_'${cname}'['${cxt}']'
         exec_sys reorg       ${con_i}    ${!con_o}
         exec_sys reorg       ${var_i}    ${!var_o}
         ##########################################################
         # Convert raw contrast to percent signal change.
         ##########################################################
         exec_fsl fslmaths    ${!con_o} \
            -mul  ${mag[i]} \
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
      exec_sys mkdir -p ${outdir}/stats
      statimgs=$(exec_sys ls -d1 ${featout}/stats/*)
      for i in ${statimgs}
         do
         contains $i 'pe[0-9]+.nii.gz' && continue
         fname=${i//${featout}\/stats\//}
         exec_sys reorg  ${i} ${outdir}/stats/${prefix}_${fname}
      done
   fi

   ###################################################################
   # Finish the module with the processed image
   ###################################################################
   if is_image ${featout}/filtered_func_data.nii.gz
      then
      subroutine              @4.10
      exec_sys reorg  ${featout}/filtered_func_data.nii.gz ${processed[cxt]}
   fi
   routine_end
fi





completion
