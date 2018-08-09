#!/bin/bash

neurodocker \
  generate singularity \
  --base=neurodebian:stretch \
  --pkg-manager=apt \
  --fsl version=5.0.11 \
  --convert3d version=1.0.0 method=binaries \
  --afni version=latest install_r=true install_r_pkgs=true \
  --ants version=2.2.0 \
  --convert3d version=nightly \
  --miniconda create_env=neuro \
      conda_install='python=3.6 numpy pandas traits' \
      pip_install='nipype' \
  --env XCPEDIR=/xcpEngine-master FSLDIR=/opt/fsl-5.0.11 \
        AFNI_PATH=/opt/afni-latest C3D_PATH=/opt/convert3d-nightly/bin \
  --add-to-entrypoint 'export XCPEDIR=/xcpEngine-master' \
  --add-to-entrypoint 'export AFNI_PATH=/opt/afni-latest' \
  --add-to-entrypoint 'export C3D_PATH=/opt/convert3d-nightly/bin' \
  --add-to-entrypoint 'export ANTSPATH=/opt/ants-2.2.0' \
  --run-bash 'wget https://github.com/PennBBL/xcpEngine/archive/master.zip && unzip master.zip && cd xcpEngine-master && bash xcpReset && chmod +x xcpEngine' \
  --run-bash "/opt/afni-latest/rPkgsInstall -pkgs 'optparse,pracma,RNiftisvglite,signal,reshape2,ggplot2,svglite,lme4'" \
  --entrypoint "/neurodocker/startup.sh /xcpEngine-master/xcpEngine" > Singularity



