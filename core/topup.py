from fmapprocessing import _fix_hdr,maskdata,n4_correction,meanimage
from fmapprocessing import  antsregistration, afni3dQwarp,_torads,vsm2dm
from nipype.interfaces import fsl,afni
import os,sys,glob,json
import numpy as np
from argparse import (ArgumentParser, RawTextHelpFormatter)
def get_parser():
    parser = ArgumentParser(
        formatter_class=RawTextHelpFormatter,
        description=' write the report for xcpEngine ')
    parser.add_argument(
        '-f', '--fmapdir', action='store', required=True,
        help='fmap directory')
    parser.add_argument(
        '-p', '--pedir', action='store', required=True,
        help='image phase encoding direction')   
    parser.add_argument(
        '-o', '--out', action='store', required=True,
        help='outdir')
    return parser
opts = get_parser().parse_args()
fmapdir=opts.fmapdir
outdir=opts.out
#let assume image phase encidng direction is j
imgphasedir=opts.pedir

#get json file to read get the diretcion 
with open(glob.glob(fmapdir+'/*dir-AP_epi.json')[0],'r')  as jsonfile1:
        obj1=jsonfile1.read() 
dt1=json.loads(obj1)
with open(glob.glob(fmapdir+'/*dir-PA_epi.json')[0],'r')  as jsonfile2: 
        obj2=jsonfile2.read() 
dt2=json.loads(obj2)

#AP is j- and PA is j (j+)

if imgphasedir == 'j':
    matched_pe=glob.glob(fmapdir+'/*dir-PA_epi.nii.gz')[0]
    opposed_pe=glob.glob(fmapdir+'/*dir-AP_epi.nii.gz')[0]
else:
    matched_pe=glob.glob(fmapdir+'/*dir-AP_epi.nii.gz')[0]
    opposed_pe=glob.glob(fmapdir+'/*dir-PA_epi.nii.gz')[0]

import shutil
shutil.copy2(matched_pe,outdir+'/magmatchpe.nii.gz')
shutil.copy2(opposed_pe,outdir+'/opposepe.nii.gz')
matched_pe=outdir+'/magmatchpe.nii.gz'
opposed_pe=outdir+'/opposepe.nii.gz'

#find the mean,
matched_mean=outdir+'/meanmatchpe.nii.gz'
opposed_mean=outdir+'/meanoppppe.nii.gz'
meanimage(matched_pe,matched_mean)
meanimage(opposed_pe,opposed_mean)

matched_bias=n4_correction(in_file=matched_mean)
opposed_bias=n4_correction(in_file=opposed_mean)

matched_brain=outdir+'/matchpe_brain.nii.gz'
#afni 3dskulkstrip is better
matched_brain=outdir+'/matchpe_brain.nii.gz' 
opposed_brain=outdir+'/opppe_brain.nii.gz' 
matched_mask=outdir+'/matchpe_mask.nii.gz' 
opposed_mask=outdir+'/opppe_mask.nii.gz'
skultri=afni.SkullStrip()
skultri.inputs.in_file=matched_bias
skultri.inputs.out_file=matched_brain
skultri.run()

skultri.inputs.in_file=opposed_mean
skultri.inputs.out_file=opposed_brain
skultri.run()
#generate mask 
maskdata(matched_brain,matched_mask)
maskdata(opposed_brain,opposed_mask)
opposed_warped=outdir+'/opposewd_warped.nii.gz'
opposed_regis=antsregistration(fixed=matched_brain,moving=opposed_brain,output_warped=opposed_warped,
transform_prefix=outdir+'/trans_')
sourcewarp=afni3dQwarp(oppose_pe=opposed_warped,matched_pe=matched_brain,source_warp=outdir+'/sourcewarp')
fixhdr=_fix_hdr(in_file=sourcewarp,newpath=outdir+'/')
out_file=_torads(in_file=fixhdr,out_file=outdir+'/fieldmapto_rads.nii.gz')








  