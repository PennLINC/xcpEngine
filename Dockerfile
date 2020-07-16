FROM neurodebian:stretch

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
           python3-dev \
           gcc \
           curl \
           locales \
           unzip \
           wget \
           zlib1g-dev \
           libnifti-dev \
           libxml2-dev \
           libssl-dev \
           libcurl4-openssl-dev \
           libssl-dev \
           libcairo2-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \
    && sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen \
    && dpkg-reconfigure --frontend=noninteractive locales \
    && update-locale LANG="en_US.UTF-8" \
    && chmod 777 /opt && chmod a+s /opt \
    && mkdir -p /neurodocker \
    && if [ ! -f "$ND_ENTRYPOINT" ]; then \
         echo '#!/usr/bin/env bash' >> "$ND_ENTRYPOINT"; \
    fi \
    && chmod -R 777 /neurodocker && chmod a+s /neurodocker

RUN curl -sSLO https://repo.continuum.io/miniconda/Miniconda3-4.5.11-Linux-x86_64.sh && \
    bash Miniconda3-4.5.11-Linux-x86_64.sh -b -p /usr/local/miniconda && \
    rm Miniconda3-4.5.11-Linux-x86_64.sh

ENV PATH="/usr/local/miniconda/bin:$PATH" \
    CPATH="/usr/local/miniconda/include/:$CPATH" \
    LANG="C.UTF-8" \
    LC_ALL="C.UTF-8" \
    PYTHONNOUSERSITE=1

RUN conda install -y python=3.7.1 \
                     pip=19.1 \
                     mkl=2018.0.3 \
                     mkl-service \
                     scipy \
                     libxml2=2.9.8 \
                     libxslt=1.1.32 \
                     zlib; sync && \
    chmod -R a+rX /usr/local/miniconda; sync && \
    chmod +x /usr/local/miniconda/bin/*; sync && \
    conda build purge-all; sync && \
    conda clean -tipsy && sync

RUN  pip install --no-cache-dir numpy pandas traits scikit-learn 
RUN  pip install --no-cache-dir nipype nibabel niworkflows nilearn matplotlib 
RUN  rm -rf ~/.cache/pip/* && sync
RUN  apt-get update

ENV FSLDIR="/opt/fsl-5.0.10" \
    PATH="/opt/fsl-5.0.10/bin:$PATH"
RUN apt-get update -qq \
    && apt-get install -y -q --no-install-recommends \
           bc \
           git \
           wget \
           dc \
           file \
           libfontconfig1 \
           libfreetype6 \
           libgl1-mesa-dev \
           libglu1-mesa-dev \
           libgomp1 \
           libice6 \
           libmng1 \
           libxcursor1 \
           libxft2 \
           libxinerama1 \
           libxrandr2 \
           libxrender1 \
           libxt6 \
           wget \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \
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
           libnlopt-dev \
           libxm4 \
           netpbm \
           r-base \
           r-base-dev \
           tcsh \
           xfonts-base \
           xvfb \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \
    && curl -sSL --retry 5 -o /tmp/libxp6_1.0.2-2_amd64.deb http://mirrors.kernel.org/debian/pool/main/libx/libxp/libxp6_1.0.2-2_amd64.deb \
    && dpkg -i /tmp/libxp6_1.0.2-2_amd64.deb \
    && rm /tmp/libxp6_1.0.2-2_amd64.deb \
    && apt-get clean && apt-get update && apt-get -f install &&  dpkg --configure -a && apt-get update \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \
    && curl -o /tmp/libpng12-0_1.2.50-2+deb8u3_amd64.deb -sSL http://mirrors.kernel.org/debian/pool/main/libp/libpng/libpng12-0_1.2.50-2+deb8u3_amd64.deb \
    && dpkg -i /tmp/libpng12-0_1.2.50-2+deb8u3_amd64.deb \
    && rm /tmp/libpng12-0_1.2.50-2+deb8u3_amd64.deb \
    && apt-get install -f \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \
    && gsl2_path="$(find / -name 'libgsl.so.19' || printf '')" \
    && if [ -n "$gsl2_path" ]; then \
         ln -sfv "$gsl2_path" "$(dirname $gsl2_path)/libgsl.so.0"; \
    fi \
    && ldconfig \
    && echo "Downloading AFNI ..." \
    && mkdir -p /opt/afni-latest \
    && curl -fsSL --retry 5 https://afni.nimh.nih.gov/pub/dist/tgz/linux_openmp_64.tgz \
    | tar -xz -C /opt/afni-latest --strip-components 1 \
    && PATH=$PATH:/opt/afni-latest rPkgsInstall -pkgs ALL

RUN bash -c 'export PATH=/opt/afni-latest:$PATH && rPkgsInstall -pkgs ALL && rPkgsInstall -pkgs optparse,pracma,RNifti,svglite,signal,reshape2,ggplot2,lme4'

# Installing ANTs latest from source
ARG ANTS_SHA=51855944553a73960662d3e4f7c1326e584b23b2
ADD https://cmake.org/files/v3.11/cmake-3.11.4-Linux-x86_64.sh /cmake-3.11.4-Linux-x86_64.sh
ENV ANTSPATH="/opt/ants-latest/bin" \
    PATH="/opt/ants-latest/bin:$PATH" \
    LD_LIBRARY_PATH="/opt/ants-latest/lib:$LD_LIBRARY_PATH"
RUN mkdir /opt/cmake \
    && sh /cmake-3.11.4-Linux-x86_64.sh --prefix=/opt/cmake --skip-license \
    && ln -s /opt/cmake/bin/cmake /usr/local/bin/cmake \
    && apt-get update -qq \
    && apt-get install -y -q --no-install-recommends \
    g++ \
    gcc \
    make \
    zlib1g-dev \
    imagemagick \
    && mkdir /tmp/ants \
    && cd /tmp \
    && curl -sSLO https://github.com/ANTsX/ANTs/archive/${ANTS_SHA}.zip \
    && unzip ${ANTS_SHA}.zip \
    && mv ANTs-${ANTS_SHA} /tmp/ants/source \
    && rm ${ANTS_SHA}.zip \
    && mkdir -p /tmp/ants/build \
    && cd /tmp/ants/build \
    && git config --global url."https://".insteadOf git:// \
    && cmake -DBUILD_SHARED_LIBS=ON /tmp/ants/source \
    && make -j1 \
    && mkdir -p /opt/ants-latest \
    && mv bin lib /opt/ants-latest/ \
    && mv /tmp/ants/source/Scripts/* /opt/ants-latest/bin \
    && rm -rf /tmp/ants \
    && rm -rf /opt/cmake /usr/local/bin/cmake

ENV C3DPATH="/opt/convert3d-nightly" \
    PATH="/opt/convert3d-nightly/bin:$PATH"
RUN echo "Downloading Convert3D ..." \
    && mkdir -p /opt/convert3d-nightly \
    && curl -fsSL --retry 5 https://sourceforge.net/projects/c3d/files/c3d/Nightly/c3d-nightly-Linux-x86_64.tar.gz/download \
    | tar -xz -C /opt/convert3d-nightly --strip-components 1

RUN curl -sSL https://surfer.nmr.mgh.harvard.edu/pub/dist/freesurfer/6.0.1/freesurfer-Linux-centos6_x86_64-stable-pub-v6.0.1.tar.gz | tar zxv --no-same-owner -C /opt \
    --exclude='freesurfer/diffusion' \
    --exclude='freesurfer/docs' \
    --exclude='freesurfer/fsfast' \
    --exclude='freesurfer/lib/cuda' \
    --exclude='freesurfer/lib/qt' \
    --exclude='freesurfer/matlab' \
    --exclude='freesurfer/mni/share/man' \
    --exclude='freesurfer/subjects/fsaverage_sym' \
    --exclude='freesurfer/subjects/fsaverage3' \
    --exclude='freesurfer/subjects/fsaverage4' \
    --exclude='freesurfer/subjects/cvs_avg35' \
    --exclude='freesurfer/subjects/cvs_avg35_inMNI152' \
    --exclude='freesurfer/subjects/bert' \
    --exclude='freesurfer/subjects/lh.EC_average' \
    --exclude='freesurfer/subjects/rh.EC_average' \
    --exclude='freesurfer/subjects/sample-*.mgz' \
    --exclude='freesurfer/subjects/V1_average' \
    --exclude='freesurfer/trctrain'

RUN apt-get install -y -q --no-install-recommends procps 
ENV USER=root

RUN sed -i '$iexport XCPEDIR=/xcpEngine' $ND_ENTRYPOINT

RUN sed -i '$iexport PATH=$PATH:$XCPEDIR' $ND_ENTRYPOINT


RUN echo 'export USER="${USER:=`whoami`}"' >> "$ND_ENTRYPOINT"

ADD . /xcpEngine

RUN bash -c \
    'cd  /xcpEngine \
    && wget -nv  https://upenn.box.com/shared/static/rrfyffnyzdybokex5tu83iav0k2yak2m.xz \
    && tar xvfJm rrfyffnyzdybokex5tu83iav0k2yak2m.xz \
    && rm rrfyffnyzdybokex5tu83iav0k2yak2m.xz'
    

RUN bash -c 'BRAINATLAS=/xcpEngine/atlas BRAINSPACE=/xcpEngine/space XCPEDIR=/xcpEngine FSLDIR=/opt/fsl-5.0.10 AFNI_PATH=/opt/afni-latest C3D_PATH=/opt/convert3d-nightly/bin ANTSPATH=/opt/ants-latest/bin /xcpEngine/xcpReset \
    && BRAINATLAS=/xcpEngine/atlas BRAINSPACE=/xcpEngine/space XCPEDIR=/xcpEngine /xcpEngine/utils/repairMetadata'

RUN bash -c 'echo R_ENVIRON_USER\="" >> /usr/lib/R/etc/Renviron \
          && echo R_PROFILE_USER\="" >> /usr/lib/R/etc/Renviron \
          && chmod a+rx /xcpEngine/xcpEngine'

ENV workbench="/xcpEngine/thirdparty/workbench/bin_rh_linux64" \
    PATH="/xcpEngine/thirdparty/workbench/bin_rh_linux64:$PATH"

ENV FREESURFER_HOME="/opt/freesurfer" \
    PATH="/opt/freesurfer:$PATH"

ENV XCPEDIR="/xcpEngine" \
    AFNI_PATH="/opt/afni-latest/" \
    FREESURFER_HOME="/opt/freesurfer" \
    workbench="/xcpEngine/thirdparty/workbench/bin_rh_linux64"  \
    C3D_PATH="/opt/convert3d-nightly/bin/" \
    PATH="$PATH:/xcpEngine" 
RUN mkdir /data /out /work /design /cohort
   
RUN mkdir /run/uuidd
RUN apt-get install -y -q --no-install-recommends uuid-runtime 

RUN pip install --no-cache-dir flywheel-sdk numpy pandas scipy sentry_sdk psutil

RUN bash -c 'cp /xcpEngine/utils/license.txt /opt/freesurfer/'

RUN bash -c '/xcpEngine/xcpReset'



ENTRYPOINT ["/xcpEngine/xcpEngine"]
