
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
           python-dev \
           python-subprocess32 \
           ca-certificates \
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

ENV CONDA_DIR="/opt/miniconda-latest" \
    PATH="/opt/miniconda-latest/bin:$PATH"
RUN export PATH="/opt/miniconda-latest/bin:$PATH" \
    && echo "Downloading Miniconda installer ..." \
    && conda_installer="/tmp/miniconda.sh" \
    && curl -fsSL --retry 5 -o "$conda_installer" https://repo.continuum.io/miniconda/Miniconda3-latest-Linux-x86_64.sh \
    && bash "$conda_installer" -b -p /opt/miniconda-latest \
    && rm -f "$conda_installer" \
    && conda update -yq -nbase conda \
    && conda config --system --prepend channels conda-forge \
    && conda config --system --set auto_update_conda false \
    && conda config --system --set show_channel_urls true \
    && sync && conda clean -tipsy && sync \
    && conda create -y -q --name neuro \
    && conda install -y -q --name neuro \
           python=3 \
           numpy \
           pandas \
           traits \
           scikit-learn \
    && conda install -y -q --name neuro libgfortran==1 \
    && sync && conda clean -tipsy && sync \
    && bash -c "source activate neuro \
    &&   pip install  --no-cache-dir \
             nipype \
             nibabel \
             niworkflows" \
    && rm -rf ~/.cache/pip/* \
    && sync

ENV FSLDIR="/opt/fsl-5.0.10" \
    PATH="/opt/fsl-5.0.10/bin:$PATH"
RUN apt-get update -qq \
    && apt-get install -y -q --no-install-recommends \
           bc \
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
           git \
           make \
           zlib1g-dev \
           imagemagick \
           procps \
    && mkdir -p /tmp/ants/build \
    && git config --global url."https://".insteadOf git:// \
    && git clone https://github.com/ANTsX/ANTs.git /tmp/ants/source \
    && cd /tmp/ants/build \
    && cmake -DBUILD_SHARED_LIBS=ON /tmp/ants/source \
    && make -j1 \
    && mkdir -p /opt/ants-latest \
    && mv bin lib /opt/ants-latest/ \
    && mv /tmp/ants/source/Scripts/* /opt/ants-latest/bin \
    && rm -rf /tmp/ants \
    && rm -rf /opt/cmake /usr/local/bin/cmake \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*


ENV C3DPATH="/opt/convert3d-nightly" \
    PATH="/opt/convert3d-nightly/bin:$PATH"
RUN echo "Downloading Convert3D ..." \
    && mkdir -p /opt/convert3d-nightly \
    && curl -fsSL --retry 5 https://sourceforge.net/projects/c3d/files/c3d/Nightly/c3d-nightly-Linux-x86_64.tar.gz/download \
    | tar -xz -C /opt/convert3d-nightly --strip-components 1

RUN sed -i '$iexport XCPEDIR=/xcpEngine' $ND_ENTRYPOINT

RUN sed -i '$iexport PATH=$PATH:$XCPEDIR' $ND_ENTRYPOINT

ADD . /xcpEngine

#RUN bash -c 'cd / &&  wget https://github.com/PennBBL/xcpEngine/archive/master.zip && unzip master.zip && rm master.zip && mv xcpEngine-master/* /xcpEngine/'

RUN bash -c \
    'cd  /xcpEngine \
    && wget -nv https://upenn.box.com/shared/static/i30llenk6s37kv8nkqxgulwylaxp928g.xz \
    && tar xvfJm i30llenk6s37kv8nkqxgulwylaxp928g.xz \
    && rm i30llenk6s37kv8nkqxgulwylaxp928g.xz'


RUN bash -c 'BRAINATLAS=/xcpEngine/atlas BRAINSPACE=/xcpEngine/space XCPEDIR=/xcpEngine FSLDIR=/opt/fsl-5.0.10 AFNI_PATH=/opt/afni-latest C3D_PATH=/opt/convert3d-nightly/bin ANTSPATH=/opt/ants-latest/bin /xcpEngine/xcpReset \
    && BRAINATLAS=/xcpEngine/atlas BRAINSPACE=/xcpEngine/space XCPEDIR=/xcpEngine /xcpEngine/utils/repairMetadata'

RUN bash -c 'echo R_ENVIRON_USER\="" >> /usr/lib/R/etc/Renviron \
          && echo R_PROFILE_USER\="" >> /usr/lib/R/etc/Renviron \
          && chmod a+rx /xcpEngine/xcpEngine'

ENV XCPEDIR="/xcpEngine" \
    AFNI_PATH="/opt/afni-latest/" \
    C3D_PATH="/opt/convert3d-nightly/bin/" \
    PATH="$PATH:/xcpEngine"

RUN mkdir /data /out /work /design /cohort

ENTRYPOINT ["/xcpEngine/xcpEngine"]
