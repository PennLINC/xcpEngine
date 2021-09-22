FROM debian:stretch

FROM rocker/rstudio:3.6.3

USER root

ARG DEBIAN_FRONTEND="noninteractive"

ENV LANG="en_US.UTF-8" \
    LC_ALL="en_US.UTF-8" \
    ND_ENTRYPOINT="/neurodocker/startup.sh"
RUN export ND_ENTRYPOINT="/neurodocker/startup.sh" \
    && apt-get update -qq \
    && apt-get install -y -q --no-install-recommends \
           apt-utils \
           bzip2 \
           ca-certificates \
           curl \
           locales \
           unzip \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen \
    && dpkg-reconfigure --frontend=noninteractive locales \
    && update-locale LANG="en_US.UTF-8" \
    && chmod 777 /opt && chmod a+s /opt \
    && mkdir -p /neurodocker \
    && if [ ! -f "$ND_ENTRYPOINT" ]; then \
         echo '#!/usr/bin/env bash' >> "$ND_ENTRYPOINT" \
    &&   echo 'set -e' >> "$ND_ENTRYPOINT" \
    &&   echo 'export USER="${USER:=`whoami`}"' >> "$ND_ENTRYPOINT" \
    &&   echo 'if [ -n "$1" ]; then "$@"; else /usr/bin/env bash; fi' >> "$ND_ENTRYPOINT"; \
    fi \
    && chmod -R 777 /neurodocker && chmod a+s /neurodocker

ENV C3DPATH="/opt/convert3d-1.0.0" \
    PATH="/opt/convert3d-1.0.0/bin:$PATH"
RUN echo "Downloading Convert3D ..." \
    && mkdir -p /opt/convert3d-1.0.0 \
    && curl -fsSL --retry 5 https://sourceforge.net/projects/c3d/files/c3d/1.0.0/c3d-1.0.0-Linux-x86_64.tar.gz/download \
    | tar -xz -C /opt/convert3d-1.0.0 --strip-components 1

ENV PATH="/opt/afni-latest:$PATH" \
    AFNI_PLUGINPATH="/opt/afni-latest"
RUN apt-get update -qq \
    && apt-get install -y -q --no-install-recommends \
           ed \
           gsl-bin \
           libglib2.0-0 \
           libglu1-mesa-dev \
           libglw1-mesa \
           libgomp1 \
           libjpeg62 \
           libxm4 \
           netpbm \
           tcsh \
           xfonts-base \
           xvfb \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && curl -sSL --retry 5 -o /tmp/toinstall.deb http://mirrors.kernel.org/debian/pool/main/libx/libxp/libxp6_1.0.2-2_amd64.deb \
    && dpkg -i /tmp/toinstall.deb \
    && rm /tmp/toinstall.deb \
    && curl -sSL --retry 5 -o /tmp/toinstall.deb http://snapshot.debian.org/archive/debian-security/20160113T213056Z/pool/updates/main/libp/libpng/libpng12-0_1.2.49-1%2Bdeb7u2_amd64.deb \
    && dpkg -i /tmp/toinstall.deb \
    && rm /tmp/toinstall.deb \
    && apt-get install -f \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && gsl2_path="$(find / -name 'libgsl.so.23' || printf '')" \
    && if [ -n "$gsl2_path" ]; then \
         ln -sfv "$gsl2_path" "$(dirname $gsl2_path)/libgsl.so.0"; \
    fi \
    && ldconfig \
    && echo "Downloading AFNI ..." \
    && mkdir -p /opt/afni-latest \
    && curl -fsSL --retry 5 https://afni.nimh.nih.gov/pub/dist/tgz/linux_openmp_64.tgz \
    | tar -xz -C /opt/afni-latest --strip-components 1

# Installing ANTs latest from source
# Installing ANTs latest from source
ARG ANTS_SHA=e00e8164d7a92f048e5d06e388a15c1ee8e889c4
ADD https://cmake.org/files/v3.11/cmake-3.11.4-Linux-x86_64.sh /cmake-3.11.4-Linux-x86_64.sh
ENV ANTSPATH="/opt/ants-latest/bin" \
    PATH="/opt/ants-latest/bin:$PATH" \
    LD_LIBRARY_PATH="/opt/ants-latest/lib:$LD_LIBRARY_PATH"
RUN bash -c  "ZLIB_LIBRARY=/usr/local/zlib/lib && ZLIB_INCLUDE_DIR=/urs/local/zlib/include"
RUN mkdir /opt/cmake \
  && sh /cmake-3.11.4-Linux-x86_64.sh --prefix=/opt/cmake --skip-license \
  && ln -s /opt/cmake/bin/cmake /usr/local/bin/cmake \
  && apt-get update -qq \
    && mkdir /tmp/ants \
    && cd /tmp \
    && git clone https://github.com/ANTsX/ANTs.git \
    && mv ANTs /tmp/ants/source \
    && cd /tmp/ants/source \
    && git checkout ${ANTS_SHA} \
    && mkdir -p /tmp/ants/build \
    && cd /tmp/ants/build \
    && mkdir -p /opt/ants-latest \
    && git config --global url."https://".insteadOf git:// \
    && cmake -DBUILD_TESTING=OFF -DBUILD_SHARED_LIBS=ON -DCMAKE_INSTALL_PREFIX=/opt/ants-latest /tmp/ants/source \
    && make -j2 \
    && cd ANTS-build \
    && make install \
    && rm -rf /tmp/ants \
    && rm -rf /opt/cmake /usr/local/bin/cmake /cmake-3.11.4-Linux-x86_64.sh


ENV FREESURFER_HOME="/opt/freesurfer-6.0.0" \
    PATH="/opt/freesurfer-6.0.0/bin:$PATH"
RUN apt-get update -qq \
    && apt-get install -y -q --no-install-recommends \
           bc \
           libgomp1 \
           libxmu6 \
           libxt6 \
           perl \
           tcsh \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && echo "Downloading FreeSurfer ..." \
    && mkdir -p /opt/freesurfer-6.0.0 \
    && curl -fsSL --retry 5 ftp://surfer.nmr.mgh.harvard.edu/pub/dist/freesurfer/6.0.0/freesurfer-Linux-centos6_x86_64-stable-pub-v6.0.0.tar.gz \
    | tar -xz -C /opt/freesurfer-6.0.0 --strip-components 1 \
         --exclude='freesurfer/average/mult-comp-cor' \
         --exclude='freesurfer/lib/cuda' \
         --exclude='freesurfer/lib/qt' \
         --exclude='freesurfer/subjects/V1_average' \
         --exclude='freesurfer/subjects/bert' \
         --exclude='freesurfer/subjects/cvs_avg35' \
         --exclude='freesurfer/subjects/cvs_avg35_inMNI152' \
         --exclude='freesurfer/subjects/fsaverage3' \
         --exclude='freesurfer/subjects/fsaverage4' \
         --exclude='freesurfer/subjects/fsaverage5' \
         --exclude='freesurfer/subjects/fsaverage6' \
         --exclude='freesurfer/subjects/fsaverage_sym' \
         --exclude='freesurfer/trctrain' \
    && sed -i '$isource "/opt/freesurfer-6.0.0/SetUpFreeSurfer.sh"' "$ND_ENTRYPOINT"


ENV FSLDIR="/opt/fsl-5.0.10" \
    PATH="/opt/fsl-5.0.10/bin:$PATH" \
    FSLOUTPUTTYPE="NIFTI_GZ" \
    FSLMULTIFILEQUIT="TRUE" \
    FSLTCLSH="/opt/fsl-5.0.10/bin/fsltclsh" \
    FSLWISH="/opt/fsl-5.0.10/bin/fslwish" \
    FSLLOCKDIR="" \
    FSLMACHINELIST="" \
    FSLREMOTECALL="" \
    FSLGECUDAQ="cuda.q"
RUN apt-get update -qq \
    && apt-get install -y -q --no-install-recommends \
           bc \
           dc \
           file \
           libfontconfig1 \
           libfreetype6 \
           libgl1-mesa-dev \
           libgl1-mesa-dri \
           libglu1-mesa-dev \
           libgomp1 \
           libice6 \
           libxcursor1 \
           libxft2 \
           libxinerama1 \
           libxrandr2 \
           libxrender1 \
           libxt6 \
           sudo \
           wget \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && echo "Downloading FSL ..." \
    && mkdir -p /opt/fsl-5.0.10 \
    && curl -fsSL --retry 5 https://fsl.fmrib.ox.ac.uk/fsldownloads/fsl-5.0.10-centos6_64.tar.gz \
    | tar -xz -C /opt/fsl-5.0.10 --strip-components 1 \
    && sed -i '$iecho Some packages in this Docker container are non-free' $ND_ENTRYPOINT \
    && sed -i '$iecho If you are considering commercial use of this container, please consult the relevant license:' $ND_ENTRYPOINT \
    && sed -i '$iecho https://fsl.fmrib.ox.ac.uk/fsl/fslwiki/Licence' $ND_ENTRYPOINT \
    && sed -i '$isource $FSLDIR/etc/fslconf/fsl.sh' $ND_ENTRYPOINT \
    && echo "Installing FSL conda environment ..." \
    && bash /opt/fsl-5.0.10/etc/fslconf/fslpython_install.sh -f /opt/fsl-5.0.10


RUN curl -sSLO https://repo.continuum.io/miniconda/Miniconda3-4.5.11-Linux-x86_64.sh && \
    bash Miniconda3-4.5.11-Linux-x86_64.sh -b -p /usr/local/miniconda && \
    rm Miniconda3-4.5.11-Linux-x86_64.sh

ENV PATH="/usr/local/miniconda/bin:$PATH" \
    CPATH="/usr/local/miniconda/include/:$CPATH" \
    LANG="C.UTF-8" \
    LC_ALL="C.UTF-8" \
    PYTHONNOUSERSITE=1

RUN conda install -y python=3.7.1 \
                     mkl=2018.0.3 \
                     mkl-service \
                     numpy\
                     pandas \
                     numpy=1.18.5 \
                     scipy=1.5.0 \
                     scikit-learn=0.23.1 \
                     pandoc  \
                     matplotlib \
                     graphviz=2.40.1 \
                     traits=4.6.0 \
                     libxml2=2.9.8 \
                     libxslt=1.1.32 \
                     zlib; sync && \
    chmod -R a+rX /usr/local/miniconda; sync && \
    chmod +x /usr/local/miniconda/bin/*; sync && \
    conda build purge-all; sync && \
    conda clean -tipsy && sync

RUN echo 'export USER="${USER:=`whoami`}"' >> "$ND_ENTRYPOINT"

RUN  pip install --no-cache-dir nipype nibabel niworkflows==1.1.10 nilearn matplotlib \
        numpy pandas traits scikit-learn svgutils==0.3.1 \
        flywheel-sdk numpy pandas scipy sentry_sdk psutil
RUN  apt-get update

RUN  R -e "install.packages(c('optparse', 'pracma', 'RNifti', \
               'svglite','signal','reshape2','ggplot2','lme4'), \ 
                repos='http://cran.rstudio.com/')"

## make some directorie
RUN mkdir /data /out /work /design /cohort
RUN mkdir /run/uuidd
RUN apt-get install -y -q --no-install-recommends uuid-runtime procps 

RUN sed -i '$iexport XCPEDIR=/xcpEngine' $ND_ENTRYPOINT

RUN sed -i '$iexport PATH=$PATH:$XCPEDIR' $ND_ENTRYPOINT


ADD . /xcpEngine

# template 

RUN bash -c \
    'cd  /xcpEngine \
    && wget -nv  https://upenn.box.com/shared/static/x95ygarwv14sv608muz06tfrmlmo222z.xz \
    && tar -xf x95ygarwv14sv608muz06tfrmlmo222z.xz \
    && rm x95ygarwv14sv608muz06tfrmlmo222z.xz'
    

RUN bash -c 'BRAINATLAS=/xcpEngine/atlas BRAINSPACE=/xcpEngine/space XCPEDIR=/xcpEngine FSLDIR=/opt/fsl-5.0.10 AFNI_PATH=/opt/afni-latest C3D_PATH=/opt/convert3d-nightly/bin ANTSPATH=/opt/ants-latest/bin /xcpEngine/xcpReset \
    && BRAINATLAS=/xcpEngine/atlas LD_LIBRARY_PATH=$gsl2_path BRAINSPACE=/xcpEngine/space XCPEDIR=/xcpEngine /xcpEngine/utils/repairMetadata'

RUN bash -c 'chmod a+rx /xcpEngine/xcpEngine'


ENV workbench="/xcpEngine/thirdparty/workbench/bin_rh_linux64" \
    PATH="/xcpEngine/thirdparty/workbench/bin_rh_linux64:$PATH"

RUN bash -c 'cp /xcpEngine/utils/license.txt /opt/freesurfer-6.0.0/'


ENV XCPEDIR="/xcpEngine" \
    AFNI_PATH="/opt/afni-latest/" \
    FREESURFER_HOME="/opt/freesurfer-6.0.0/" \
    workbench="/xcpEngine/thirdparty/workbench/bin_rh_linux64"  \
    C3D_PATH="/opt/convert3d-1.0.0/bin/" \
    PATH="$PATH:/xcpEngine"

#RUN bash -c 'cp /xcpEngine/utils/license.txt /opt/freesurfer-6.0.0/'

RUN bash -c '/xcpEngine/xcpReset'

ENTRYPOINT ["/xcpEngine/xcpEngine"]