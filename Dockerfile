FROM pennbbl/baseimages:common

RUN sed -i '$iexport XCPEDIR=/xcpEngine-master' $ND_ENTRYPOINT

RUN sed -i '$iexport PATH=$PATH:$XCPEDIR' $ND_ENTRYPOINT

RUN bash -c 'cd / \
    && wget -nv https://github.com/PennBBL/xcpEngine/archive/master.zip \
    && unzip master.zip \
    && rm master.zip'


RUN bash -c \
    'cd  /xcpEngine-master \
    && wget -nv https://upenn.box.com/shared/static/i30llenk6s37kv8nkqxgulwylaxp928g.xz \
    && tar xvfJm i30llenk6s37kv8nkqxgulwylaxp928g.xz \
    && rm i30llenk6s37kv8nkqxgulwylaxp928g.xz'


RUN bash -c 'BRAINATLAS=/xcpEngine-master/atlas BRAINSPACE=/xcpEngine-master/space XCPEDIR=/xcpEngine-master FSLDIR=/opt/fsl-5.0.10 AFNI_PATH=/opt/afni-latest C3D_PATH=/opt/convert3d-nightly/bin ANTSPATH=/opt/ants-2.2.0 /xcpEngine-master/xcpReset \
    && BRAINATLAS=/xcpEngine-master/atlas BRAINSPACE=/xcpEngine-master/space XCPEDIR=/xcpEngine-master /xcpEngine-master/utils/repairMetadata'

RUN bash -c 'echo R_ENVIRON_USER\="" >> /usr/lib/R/etc/Renviron \
          && echo R_PROFILE_USER\="" >> /usr/lib/R/etc/Renviron'

ENTRYPOINT ["/neurodocker/startup.sh", "/xcpEngine-master/xcpEngine", "\"$@\""]
