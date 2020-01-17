#!/usr/bin/env python
# -*- coding: utf-8 -*-
# emacs: -*- mode: python; py-indent-offset: 4; indent-tabs-mode: nil -*-
# vi: set ft=python sts=4 ts=4 sw=4 et:

from fmapprocessing import phdiff2fmap,au2rads, maskdata,n4_correction, fslbet,_demean,vsm2dm,antsregistration
from fmapprocessing import _despike2d,_torads, _unwrap, substractimage,substractphaseimage,_recenter,applytransform
from nipype.interfaces import fsl
import os,sys,glob,json
import numpy as np
from argparse import (ArgumentParser, RawTextHelpFormatter)

def get_parser():
    parser = ArgumentParser(
        formatter_class=RawTextHelpFormatter,
        description=' write the report for xcpEngine ')
    parser.add_argument(
        '-f', '--fmapdir', action='store', required=True,
        help='fmapdir')
    parser.add_argument(
        '-i', '--reference', action='store', required=True,
        help='reference')
    parser.add_argument(
        '-o', '--out', action='store', required=True,
        help='outdir')
    return parser
opts = get_parser().parse_args()
fmapdir=opts.fmapdir
outdir=opts.out
ref=opts.reference
#check if phasediff or phase1 and phase2 
phasedifc=glob.glob(fmapdir+'/*phasediff.nii.gz')
phase1=glob.glob(fmapdir+'/*phase1.nii.gz')
phase2=glob.glob(fmapdir+'/*phase2.nii.gz')

if os.path.isfile(phasedifc[0]):
    phaseon=phasedifc[0]
    au2rads(phaseon,outdir)
    phasediff=glob.glob(outdir+'/*rads.nii.gz')[0]
elif os.path.isfile(phase1[0]):
    phase1=phase1[0]; phase2=phase2[0]
    ph1=au2rads(phase1); ph2=au2rads(phase2)
    phasediff=outdir+'/phasediff.nii.gz'
    pha=substractphaseimage(ph1,ph2,phasediff)
 
mag=glob.glob(fmapdir+'/*magnitude1.nii.gz')[0]
import shutil
shutil.copy2(mag,outdir+'/mag.nii.gz')
mag1=outdir+'/mag.nii.gz'
mag_bias=n4_correction(in_file=mag1)
mag_brain=outdir+'/mag1_brain.nii.gz'
mag_mask=outdir+'/mag1_mask.nii.gz'
mag_brain=fslbet(in_file=mag_bias,out_file=mag_brain)
maskdata(mag_brain,mag_mask)

magbrain_warped=outdir+'/mag_warped.nii.gz'
phase_warped=outdir+'/phase_warped.nii.gz'
opposed_regis=antsregistration(fixed=ref,moving=mag_brain,output_warped=magbrain_warped,
transform_prefix=outdir+'/trans_')
applytransform(in_file=phasediff,reference=ref,out_file=phase_warped,
         transformfile=outdir+'/trans_Composite.h5',interpolation='LanczosWindowedSinc')




#unwarp withe predule 
unwrapped=outdir+'/unwrapped.nii.gz'
prefsl=fsl.PRELUDE()
prefsl.inputs.magnitude_file=magbrain_warped
prefsl.inputs.phase_file=phase_warped
prefsl.inputs.mask_file=mag_mask
prefsl.inputs.unwrapped_phase_file=unwrapped
prefsl.run()
#denoise demean recenter the fieldmap and 
#recentre
recentered=_recenter(unwrapped,newpath=outdir+'/')
# denoise with fsl spatial filter 
denoised=outdir+'/unwrapped_denoise.nii.gz'
denoise=fsl.SpatialFilter()
denoise.inputs.in_file=recentered
denoise.inputs.kernel_shape='sphere'
denoise.inputs.kernel_size=3
denoise.inputs.operation='median'
denoise.inputs.out_file=denoised
denoise.run()

demeamed=_demean(in_file=denoised,newpath=outdir+'/')

# get delta te 
if os.path.isfile(phasedifc[0]):
    with open(glob.glob(fmapdir+'/*phasediff.json')[0],'r')  as jsonfile:
        obj=jsonfile.read()
    dpdat=json.loads(obj)
    delta_te=np.abs(dpdat['EchoTime2']-dpdat['EchoTime1'])
elif os.path.isfile(glob.glob(fmapdir+'/*phase1.nii.gz')[0]):
    with open(glob.glob(fmapdir+'/*phase1.json')[0],'r') as jsonfile1:
        obj1=jsonfile1.read()
    dt1=json.loads(obj1)
    with open(glob.glob(fmapdir+'/*phase2.json')[0],'r') as jsonfile2:
        obj2=jsonfile2.read()
    dt2=json.loads(obj2)
    delta_te=np.abs(dt2['EchoTime']-dt1['EchoTime'])


outfile=phdiff2fmap(in_file=demeamed,delta_te=delta_te,newpath=outdir+'/')

out_file=_torads(in_file=outfile,out_file=outdir+'/fieldmapto_rads.nii.gz')
if dpdat: 
    phasedir=dpdat['PhaseEncodingDirection']
    if phasedir == 'j':
        phaseEncDim=1; phaseEncSign=1
    else:
        phaseEncDim=1; phaseEncSign=-1
elif dt1:
    phasedir=dt1['PhaseEncodingDirection']
    if phasedir == 'j':
        phaseEncDim=1; phaseEncSign=1
    else:
        phaseEncDim=1; phaseEncSign=-1

field_sdcwarp=vsm2dm(in_file=out_file,phaseEncDim=phaseEncDim,phaseEncSign=phaseEncSign,
fieldmapout=outdir+'/fieldmap.nii.gz',field_sdcwarp=outdir+'/sdc_warp.nii.gz')

outfile=_demean(field_sdcwarp,newpath=outdir+'/')
#final required outpu is sdc_warp_demean.nii.gz 
# convert to fieldmap