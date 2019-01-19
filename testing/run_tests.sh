#!/bin/bash

cd $TMPDIR
34gjb9nlm8toouh42fgwip2mpvm5ofg7.xz
wget https://upenn.box.com/shared/static/34gjb9nlm8toouh42fgwip2mpvm5ofg7.xz
tar xvfJ 34gjb9nlm8toouh42fgwip2mpvm5ofg7.xz
rm 34gjb9nlm8toouh42fgwip2mpvm5ofg7.xz

FMP_OUTPUT=`pwd`/downsampled/sub-1
ANAT_COHORT=`pwd`/anat_cohort.csv
MNI_BOLD_COHORT=`pwd`/mni_bold_cohort.csv
T1_BOLD_COHORT=`pwd`/T1w_bold_cohort.csv
OUTPUT=`pwd`/xcp_output
WORKDIR=`pwd`/work

# Prepare a cohort for the anatomical test
echo "id0,img" > ${ANAT_COHORT}
echo "sub-1,${FMP_OUTPUT}/anat/sub-1_desc-preproc_T1w.nii.gz" >> ${ANAT_COHORT}

# test that the anatomical preprocessing works
${XCPEDIR}/xcpEngine \
    -d ${XCPEDIR}/testing/anat-testing.dsn \
    -c ${ANAT_COHORT} \
    -o ${OUTPUT}/anat \
    -i ${WORKDIR}/anat


# Prepare some MNI-space bold data
echo "id0,img" > ${MNI_BOLD_COHORT}
echo "sub-1,${FMP_OUTPUT}/func/sub-1_task-rest_space-MNI152NLin2009cAsym_desc-preproc_bold.nii.gz" >> ${MNI_BOLD_COHORT}

# Run MNI BOLD through the pipeline: no struc
${XCPEDIR}/xcpEngine \
    -d ${XCPEDIR}/testing/fc-36p.dsn \
    -c ${MNI_BOLD_COHORT} \
    -o ${OUTPUT}/MNI \
    -i ${WORKDIR}/MNI

# Prepare native space cohort
echo "id0,img" > ${T1_BOLD_COHORT}
echo "sub-1,${FMP_OUTPUT}/func/sub-1_task-rest_space-T1w_desc-preproc_bold.nii.gz" >> ${T1_BOLD_COHORT}


# Run T1w BOLD through the pipeline: no struc
${XCPEDIR}/xcpEngine \
    -d ${XCPEDIR}/testing/fc-36p.dsn \
    -c ${T1_BOLD_COHORT} \
    -o ${OUTPUT}/T1w \
    -i ${WORKDIR}/T1w


