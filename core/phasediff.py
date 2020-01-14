#!/usr/bin/env python
# -*- coding: utf-8 -*-
# emacs: -*- mode: python; py-indent-offset: 4; indent-tabs-mode: nil -*-
# vi: set ft=python sts=4 ts=4 sw=4 et:

from fmapprocessing import phdiff2fmap,au2rads, maskdata,n4_correction, fslbet
from fmapprocessing import _despike2d, _unwrap, substractimage,substractphaseimage
from nipype.interfaces.process import fsl
import os,sys,glob,json

from argparse import (ArgumentParser, RawTextHelpFormatter)

def get_parser():
    parser = ArgumentParser(
        formatter_class=RawTextHelpFormatter,
        description=' write the report for xcpEngine ')
    parser.add_argument(
        '-f', '--fmapdir', action='store', required=True,
        help='fmapdir')
    parser.add_argument(
        '-o', '--out', action='store', required=True,
        help='outdir')
    return parser

fmapdir=opts.fmapdir
outdir=opts.out
#check if phasediff or phase1 and phase2 
phasedifc=glob.glob(fmapdir+'/*phasediff.nii.gz')
phase1=glog.glob(fmapdir+'/*phase1.nii.gz')
phase2=glog.glob(fmapdir+'/*phase2.nii.gz')
if os.path.exists(phasedifc[0]):
    phasediff=phasedifc[0]
elif os.path.exists(phase1[0]):
    phase1=phase1[0]; phase2=phase2[0]
    ph1=au2rads(phase1); ph2=au2rads(phase2)
    phasediff=outdir+'/phasediff.nii.gz'
    pha=substractphaseimage(phi1,phi2,phasediff)
 
mag=glog.glob(fmapdir+'/*magnitude1.nii.gz')[0]
mag_bias=n4_correction(in_file=mag)
mag_brain=outdir+'/mag1_brain.nii.gz'
mag_mask=outdir+'/mag1_mask.nii.gz'
fslbet(in_file=mag_bias,out_file=mag_brain)
maskdata(mag_brain,mag_mask)
#unwarp withe predule 
unwrapped=outdir+'/unwrapped.nii.gz'
prefsl=fsl.predule()
prefsl.magnitude_file=mag_brain
prefsl.phase_file=phasediff
prefsl.mask_file=mag_mask
prefsl.unwrapped_phase_file=unwrapped
prefsl.run()
#denoise demean recenter the fieldmap and 
#recentre
recentered=fmapprocessing._recenter(unwrapped)
# denoise with fsl spatial filter 
denoised='unwrapped_denoise.nii.gz'
denoise=fsl.SpatialFilter()
denoise.inputs.in_file=recentered
denoise.inputs.kernel_shape='sphere'
denoise.inputs.kernel_size=3
denoise.inputs.operation='median'
denoise.inputs.out_file=denoised
denoise.run()

demeamed=fmapprocessing._demean(in_file=denoised)

# get delta te 
if os.path.exists(phasedifc[0]):
    with open(glob.glob(fmapdir+'/*phasediff.json')[0],'r')  as jsonfile:
        obj=jsonfile.read()
    delta_te=np.abs(obj['EchoTime2']-obj['EchoTime1'])
elif os.path.exists(glog.glob(fmapdir+'/*phase1.nii.gz')[0]):
    with open(glog.glob(fmapdir+'/*phase1.json')[0],'r') as jsonfile1:
        obj1=jsonfile1.read()
    with open(glog.glob(fmapdir+'/*phase2.json')[0],'r') as jsonfile2:
        obj2=jsonfile2.read()
    delta_te=np.abs(obj2['EchoTime']-obj1['EchoTime'])


outfile=phdiff2fmap(in_file=demeamed,delta_te=delta_te)

# convert to fieldmap