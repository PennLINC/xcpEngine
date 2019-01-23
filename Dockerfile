FROM pennbbl/baseimages:latest

RUN sed -i '$iexport XCPEDIR=/xcpEngine' $ND_ENTRYPOINT

RUN sed -i '$iexport PATH=$PATH:$XCPEDIR' $ND_ENTRYPOINT

ADD . /xcpEngine

RUN bash -c \
    'cd  /xcpEngine \
    && wget -nv https://upenn.box.com/shared/static/i30llenk6s37kv8nkqxgulwylaxp928g.xz \
    && tar xvfJm i30llenk6s37kv8nkqxgulwylaxp928g.xz \
    && rm i30llenk6s37kv8nkqxgulwylaxp928g.xz'


RUN bash -c 'BRAINATLAS=/xcpEngine/atlas BRAINSPACE=/xcpEngine/space XCPEDIR=/xcpEngine FSLDIR=/opt/fsl-5.0.10 AFNI_PATH=/opt/afni-latest C3D_PATH=/opt/convert3d-nightly/bin ANTSPATH=/opt/ants-latest/bin /xcpEngine/xcpReset \
    && BRAINATLAS=/xcpEngine/atlas BRAINSPACE=/xcpEngine/space XCPEDIR=/xcpEngine /xcpEngine/utils/repairMetadata'

RUN bash -c 'echo R_ENVIRON_USER\="" >> /usr/lib/R/etc/Renviron \
          && echo R_PROFILE_USER\="" >> /usr/lib/R/etc/Renviron'

ENTRYPOINT ["/neurodocker/startup.sh", "/xcpEngine/xcpEngine", "\"$@\""]
