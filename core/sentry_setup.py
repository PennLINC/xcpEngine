#!/usr/bin/env python
# -*- coding: utf-8 -*-
# emacs: -*- mode: python; py-indent-offset: 4; indent-tabs-mode: nil -*-
# vi: set ft=python sts=4 ts=4 sw=4 et:

import platform
import os
import sentry_sdk
import psutil
from os import cpu_count
import pandas as pd
from argparse import (ArgumentParser, RawTextHelpFormatter)
def get_parser():
    parser = ArgumentParser(
        formatter_class=RawTextHelpFormatter,
        description=' write the report for xcpEngine ')
    parser.add_argument(
        '-p', '--prefix', action='store', required=True,
        help='prefix id')
    parser.add_argument(
        '-o', '--out', action='store', required=True,
        help='outdir')
    parser.add_argument(
        '-m', '--modules', action='store', required=True,
        help='list of modules run')

    return parser
opts = get_parser().parse_args()
prefix=opts.prefix
pipeline=opts.modules
output=opts.out

enviomnet=platform.platform() # will get all platform
systemv=platform.system()
release=platform.release()
version1=platform.version()

event={'complete':['yes','no']}
def strip_sensitive_data(event, hints):
    # modify event here
    return event
sentry_sdk.init("https://34b713b3ba2240329b2b671685006e94@sentry.io/1854243",

release=release,environment=enviomnet,server_name=platform.node())

#sentry_sdk.add_breadcrumb(message='xcpengine started', level='info')
#sentry_sdk.capture_message('xcpengine started', level='info')

with sentry_sdk.configure_scope() as scope:
    scope.user = {"email": "azeez.adebimpe@outlook.com"}
    scope.set_tag('exec_env',platform.system())
    free_mem_at_start = round(psutil.virtual_memory().free / 1024**3, 1)
    scope.set_tag('free_mem_at_start', free_mem_at_start)
    scope.set_tag('cpu_count', cpu_count())

modules=pd.read_csv(pipeline)
#sentry_sdk.capture_message('xcp complete', ':)')  
modules1 = []
for j in modules:
    modules1.append(j)
# initiate the setup
with sentry_sdk.configure_scope() as scope:
        scope.set_tag('exec_env',platform.system())
        free_mem_at_start = round(psutil.virtual_memory().free / 1024**3, 1)
        scope.set_tag('free_mem_at_start', free_mem_at_start)
        scope.set_tag('cpu_count', cpu_count())
        dir_path = os.path.dirname(os.path.realpath(output+'/'+modules1[0]))
        if not dir_path:
            scope.set_tag('xcp_start','no')
            scope.level = 'fatal'
            sentry_sdk.capture_message('xcp did not start', 'fatal')
        else:
            scope.set_tag('xcp_start','yes')
        for j in modules1:
            if j == 'prestats':
                if os.path.isfile(output+'/prestats/'+prefix+'_preprocessed.nii.gz'):
                    scope.set_extra('prestats','successful')
                else:
                    scope.set_extra('prestats','not successful')
            if j == 'confound2':
                if os.path.isfile(output+'/confound2/'+prefix+'_confmat.1D'):
                    scope.set_extra('confound2','successful')
                else:
                    scope.set_extra('confound2','not successful')
            if j == 'regress':
                if os.path.isfile(output+'/regress/'+prefix+'_residualised.nii.gz'):
                    scope.set_extra('regress','successful')
                else:
                    scope.set_extra('regress','not successful')
            if j == 'norm':
                if os.path.isfile(output+'/norm/'+prefix+'_seq2std.png'):
                    scope.set_extra('norm','successful')
                else:
                    scope.set_extra('norm','not successful')
            if j == 'qcfc':
                if os.path.isfile(output+'/qcfc/'+prefix+'_voxts.png'):
                    scope.set_extra('qcfc','successful')
                else:
                    scope.set_extra('qcfc','not successful')
            if j == 'cbf':
                if os.path.isfile(output+'/cbf/'+prefix+'_cbf.nii.gz'):
                    scope.set_extra('cbf','successful')
                else:
                    scope.set_extra('cbf','not successful')
            if j == 'basil':
                if os.path.isfile(output+'/basil/'+prefix+'_cbfbasil.nii.gz'):
                    scope.set_extra('basil','successful')
                else:
                    scope.set_extra('basil','not successful')
            if j == 'coreg':
                if os.path.isfile(output+'/coreg/'+prefix+'_struct2seq.nii.gz'):
                    scope.set_extra('coreg','successful')
                else:
                    scope.set_extra('coreg','not successful')
            if j == 'scorescrub':
                if os.path.isfile(output+'/scorescrub/'+prefix+'_cbfscrub.nii.gz'):
                    scope.set_extra('scorescrub','successful')
                else:
                    scope.set_extra('scorescrub','not successful')
            if j == 'struc':
                if os.path.isfile(output+'/struc/'+prefix+'_ExtractedBrain0N4.nii.gz'):
                    scope.set_extra('struc','successful')
                else:
                    scope.set_extra('struc','not successful')
            if j == 'gmd':
                if os.path.isfile(output+'/struc/'+prefix+'_gmd.gz'):
                    scope.set_extra('gmd','successful')
                else:
                    scope.set_extra('gmd','not successful')
            if j == 'jlf':
                if os.path.isfile(output+'/jlf/'+prefix+'_Labels.nii.gz'):
                    scope.set_extra('jlf','successful')
                else:
                    scope.set_extra('jlf','not successful')


if os.path.isfile(output+'_report.html'):
    sentry_sdk.add_breadcrumb(message='Incomplete outputs', level='fatal')
    sentry_sdk.capture_message('Incomplete outputs', 'fatal') 
else:
    sentry_sdk.add_breadcrumb(message='xcp ran successfuly', level='info')
    sentry_sdk.capture_message('xcp complete', level='info') 
