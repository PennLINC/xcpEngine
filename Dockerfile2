
FROM ubuntu:xenial-20200706

FROM rocker/rstudio:3.6.3

COPY docker/files/neurodebian.gpg /usr/local/etc/neurodebian.gpg

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
                    curl \
                    bzip2 \
                    ca-certificates \
                    xvfb \
                    build-essential \
                    autoconf \
                    libtool \
                    pkg-config \
                    git && \
    curl -sL https://deb.nodesource.com/setup_10.x | bash - && \
    apt-get install -y --no-install-recommends \
                    nodejs && \
    apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

ENV FSL_DIR="/usr/share/fsl/5.0" \
    OS="Linux" \
    FS_OVERRIDE=0 \
    FIX_VERTEX_AREA="" \
    FSF_OUTPUT_FORMAT="nii.gz" 

RUN curl -sSL "http://neuro.debian.net/lists/$( lsb_release -c | cut -f2 ).us-ca.full" >> /etc/apt/sources.list.d/neurodebian.sources.list && \
    apt-key add /usr/local/etc/neurodebian.gpg && \
    (apt-key adv --refresh-keys --keyserver hkp://ha.pool.sks-keyservers.net 0xA5D32F012649A5A9 || true)

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
                    afni=16.2.07~dfsg.1-5~nd16.04+1 \
                    git-annex-standalone && \
    apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN apt-get update -qq \
    && apt-get install -y -q --no-install-recommends \
           wget \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \
    && echo "Downloading FSL ..." \
    && mkdir -p /usr/share/fsl/5.0 \
    && curl -fsSL --retry 5 https://fsl.fmrib.ox.ac.uk/fsldownloads/fsl-5.0.10-centos6_64.tar.gz \
    | tar -xz -C /usr/share/fsl/5.0 --strip-components 1 \
    && sed -i '$iecho Some packages in this Docker container are non-free' $ND_ENTRYPOINT \
    && sed -i '$iecho If you are considering commercial use of this container, please consult the relevant license:' $ND_ENTRYPOINT \
    && sed -i '$iecho https://fsl.fmrib.ox.ac.uk/fsl/fslwiki/Licence' $ND_ENTRYPOINT \
    && sed -i '$isource $FSLDIR/etc/fslconf/fsl.sh' $ND_ENTRYPOINT \
    && echo "Installing FSL conda environment ..." \
    && bash /usr/share/fsl/5.0/etc/fslconf/fslpython_install.sh -f /usr/share/fsl/5.0

ENV FSLDIR="/usr/share/fsl/5.0" \
    FSLOUTPUTTYPE="NIFTI_GZ" \
    FSLMULTIFILEQUIT="TRUE" \
    POSSUMDIR="/usr/share/fsl/5.0" \
    LD_LIBRARY_PATH="/usr/lib/fsl/5.0:$LD_LIBRARY_PATH" \
    FSLTCLSH="/usr/bin/tclsh" \
    FSLWISH="/usr/bin/wish" \
    AFNI_MODELPATH="/usr/lib/afni/models" \
    AFNI_IMSAVE_WARNINGS="NO" \
    AFNI_TTATLAS_DATASET="/usr/share/afni/atlases" \
    AFNI_PLUGINPATH="/usr/lib/afni/plugins"
ENV PATH="/usr/lib/fsl/5.0:/usr/lib/afni/bin:$PATH"

ENV C3DPATH="/usr/lib/convert3d-nightly" \
    PATH="/usr/lib/convert3d-nightly/bin:$PATH"
RUN echo "Downloading Convert3D ..." \
    && mkdir -p /usr/lib/convert3d-nightly \
    && curl -fsSL --retry 5 https://sourceforge.net/projects/c3d/files/c3d/Nightly/c3d-nightly-Linux-x86_64.tar.gz/download \
    | tar -xz -C //usr/lib/convert3d-nightly --strip-components 1

ENV ANTSPATH=/usr/lib/ants
RUN mkdir -p $ANTSPATH && \
    curl -sSL "https://dl.dropbox.com/s/gwf51ykkk5bifyj/ants-Linux-centos6_x86_64-v2.3.4.tar.gz" \
    | tar -xzC $ANTSPATH --strip-components 1
ENV PATH=$ANTSPATH:$PATH

# Installing and setting up miniconda
RUN curl -sSLO https://repo.continuum.io/miniconda/Miniconda3-4.5.11-Linux-x86_64.sh && \
    bash Miniconda3-4.5.11-Linux-x86_64.sh -b -p /usr/local/miniconda && \
    rm Miniconda3-4.5.11-Linux-x86_64.sh

# Set CPATH for packages relying on compiled libs (e.g. indexed_gzip)
ENV PATH="/usr/local/miniconda/bin:$PATH" \
    CPATH="/usr/local/miniconda/include/:$CPATH" \
    LANG="C.UTF-8" \
    LC_ALL="C.UTF-8" \
    PYTHONNOUSERSITE=1

# Installing precomputed python packages
RUN conda install -y python=3.7.4 \
                     pip=20.1.1 \
                     mkl=2018.0.3 \
                     mkl-service \
                     numpy=1.18.5 \
                     scipy=1.5.0 \
                     scikit-learn=0.23.1 \
                     pandas=1.0.5 \
                     libxml2=2.9.8 \
                     libxslt=1.1.32 \
                     pandoc \
                     matplotlib \
                     graphviz=2.40.1 \
                     traits=4.6.0 \
                     zlib; sync && \
    chmod -R a+rX /usr/local/miniconda; sync && \
    chmod +x /usr/local/miniconda/bin/*; sync && \
    conda build purge-all; sync && \
    conda clean -tipsy && sync
RUN pip install --no-cache-dir flywheel-sdk numpy pandas scipy sentry_sdk psutil 
# Unless otherwise specified each process should only use one thread - nipype
# will handle parallelization
ENV MKL_NUM_THREADS=1 \
    OMP_NUM_THREADS=1


# freesurfer 
RUN curl -sSL https://surfer.nmr.mgh.harvard.edu/pub/dist/freesurfer/6.0.1/freesurfer-Linux-centos6_x86_64-stable-pub-v6.0.1.tar.gz | tar zxv --no-same-owner \
    -C /usr/lib \
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

## install R with  conda 
RUN apt-get install -y -q --no-install-recommends procps 
ENV USER=root

RUN sed -i '$iexport XCPEDIR=/xcpEngine' $ND_ENTRYPOINT

RUN sed -i '$iexport PATH=$PATH:$XCPEDIR' $ND_ENTRYPOINT
RUN echo 'export USER="${USER:=`whoami`}"' >> "$ND_ENTRYPOINT"

RUN  pip install --no-cache-dir nipype nibabel niworkflows==1.1.10 nilearn matplotlib 
RUN  pip install --no-cache-dir numpy pandas traits scikit-learn svgutils==0.3.1
RUN  rm -rf ~/.cache/pip/* && sync
RUN  apt-get update
RUN  R -e "install.packages(c('optparse', 'pracma', 'RNifti', \
               'svglite','signal','reshape2','ggplot2','lme4'), \ 
                repos='http://cran.rstudio.com/')"

ADD . /xcpEngine

RUN bash -c \
    'cd  /xcpEngine \
    && wget -nv  https://upenn.box.com/shared/static/x95ygarwv14sv608muz06tfrmlmo222z.xz \
    && tar -xf x95ygarwv14sv608muz06tfrmlmo222z.xz \
    && rm x95ygarwv14sv608muz06tfrmlmo222z.xz'
    

RUN bash -c 'BRAINATLAS=/xcpEngine/atlas BRAINSPACE=/xcpEngine/space XCPEDIR=/xcpEngine FSLDIR=/usr/share/fsl/5.0 AFNI_PATH=/usr/lib/afni/ C3D_PATH=/usr/lib/convert3d-nightly/bin/ ANTSPATH=/usr/lib/ants/bin /xcpEngine/xcpReset \
    && BRAINATLAS=/xcpEngine/atlas BRAINSPACE=/xcpEngine/space XCPEDIR=/xcpEngine /xcpEngine/utils/repairMetadata'

RUN bash -c 'echo R_ENVIRON_USER\="" >> /usr/lib/R/etc/Renviron \
          && echo R_PROFILE_USER\="" >> /usr/lib/R/etc/Renviron \
          && chmod a+rx /xcpEngine/xcpEngine'

ENV workbench="/xcpEngine/thirdparty/workbench/bin_rh_linux64" \
    PATH="/xcpEngine/thirdparty/workbench/bin_rh_linux64:$PATH"


ENV XCPEDIR="/xcpEngine" \
    AFNI_PATH="/usr/lib/afni" \
    FREESURFER_HOME="/usr/lib/freesurfer" \
    workbench="/xcpEngine/thirdparty/workbench/bin_rh_linux64"  \
    C3D_PATH="/usr/lib//convert3d-nightly/bin/" \
    PATH="$PATH:/xcpEngine" 

RUN bash -c 'cp /xcpEngine/utils/license.txt /usr/lib/freesurfer/'


RUN bash -c '/xcpEngine/xcpReset'


ENTRYPOINT ["/xcpEngine/xcpEngine"]


