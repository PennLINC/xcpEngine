#!/bin/bash

neurodocker \
  generate singularity \
  --base=neurodebian:stretch \
  --pkg-manager=apt \
  --install wget \
  --fsl version=5.0.11 \
  --convert3d version=1.0.0 method=binaries \
  --afni version=latest install_r=true install_r_pkgs=true \
  --ants version=2.2.0 \
  --convert3d version=nightly \
  --env XCPEDIR=/xcpEngine-master FSLDIR=/opt/fsl-5.0.11 \
        AFNI_PATH=/opt/afni-latest C3D_PATH=/opt/convert3d-nightly/bin \
  --add-to-entrypoint 'export XCPEDIR=/xcpEngine-master' \
  --add-to-entrypoint 'export FSLDIR=/opt/fsl-5.0.11' \
  --add-to-entrypoint 'export AFNI_PATH=/opt/afni-latest' \
  --add-to-entrypoint 'export C3D_PATH=/opt/convert3d-nightly/bin' \
  --add-to-entrypoint 'export ANTSPATH=/opt/ants-2.2.0' \
  --add-to-entrypoint 'export PATH=$PATH:$XCPEDIR' \
  --run-bash 'cd / && wget https://github.com/PennBBL/xcpEngine/archive/master.zip && unzip master.zip' \
  --run-bash 'XCPEDIR=/xcpEngine-master FSLDIR=/opt/fsl-5.0.11 AFNI_PATH=/opt/afni-latest C3D_PATH=/opt/convert3d-nightly/bin ANTSPATH=/opt/ants-2.2.0 /xcpEngine-master/xcpReset' \
  --run-bash 'export PATH=/opt/afni-latest:$PATH && rPkgsInstall -pkgs ALL && rPkgsInstall -pkgs optparse,pracma,RNifti,svglite,signal,reshape2,ggplot2,lme4' \
  --run-bash ' echo ==========================' \
  --run-bash 'cat $ND_ENTRYPOINT' \
  --run-bash ' echo ==========================' \
  --entrypoint "/neurodocker/startup.sh /xcpEngine-master/xcpEngine" > Singularity



