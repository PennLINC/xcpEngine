#!/usr/bin/env python
# -*- coding: utf-8 -*-
# emacs: -*- mode: python; py-indent-offset: 4; indent-tabs-mode: nil -*-
# vi: set ft=python sts=4 ts=4 sw=4 et:
# Azeez Adebimpe penn bbl sept 2019
import nibabel as nib
import numpy as np
import pandas as pd 
import os as os 
import sys as sys
import seaborn as sns
from nibabel.processing import smooth_image
from scipy.stats import gmean
from argparse import (ArgumentParser, RawTextHelpFormatter)

def get_parser():

    parser = ArgumentParser(
        formatter_class=RawTextHelpFormatter,
        description='ASL QC from Dolui et al and other ')
    parser.add_argument(
        '-i', '--img', action='store', required=True,
        help='[required]'
             '\nPath to the 3D or 4D CBF timeseries.')
    parser.add_argument(
        '-o', '--out', action='store', required=True,
        help='[required]'
             '\n Output path.')
    parser.add_argument(
        '-g', '--gm', action='store', required=False,
        help='grey matter')
    parser.add_argument(
        '-w', '--wm', action='store',required=False,
        help='white matter')
    parser.add_argument(
        '-c', '--csf', action='store',required=False,
        help='CSF')
    parser.add_argument(
        '-m', '--mask', action='store',required=True,
        help='cbf mask')
  
    
    return parser

opts            =   get_parser().parse_args()

gm=opts.gm
wm=opts.wm
mask=opts.mask
out=opts.out
img=opts.img
csf=opts.csf

def fun1(x,xdata):
    d1=np.exp(-(x[0])*np.power(xdata,x[1]))
    return(d1)
    
def fun2(x,xdata):
    d1=1-np.exp(-(x[0])*np.power(xdata,x[1]))
    return(d1)

x1 = [0.054,0.9272]
x2 = [2.8478,0.5196]
x4 = [3.0126, 2.4419]

img1=nib.load(img)
img_data=img1.get_fdata()
mas=nib.load(mask).get_fdata()
logmask         =   np.isclose(mas, 1)
imgts=img_data[logmask]
#check if the image is 3D or 4D 



# compute relative cbf 

cbf=img1.get_fdata()
cbf1=cbf[logmask]/np.mean(cbf[logmask])
img2=np.zeros(shape=[img1.shape[0],img1.shape[1],img1.shape[2]])
img2[logmask]=cbf1
img_rel        =   nib.Nifti1Image(dataobj=img2,
                                                affine=img1.affine,
                                                header=img1.header)
out3=out+'R.nii.gz'                                            
nib.save(img_rel,out3)
    

if gm and wm and csf:
   img_3        =   nib.Nifti1Image(dataobj=cbf,
                                                affine=img1.affine,
                                                header=img1.header)
   scbf=smooth_image(img_3,fwhm=5)
   cbf=scbf.get_fdata() 
   out3=out+'_QEI.txt'
   
   gm0=nib.load(gm).get_fdata(); 
   if len(gm0.shape)==4:
      gmm=gm0[...,-1]
      wm0=nib.load(wm).get_fdata(); wmm=wm0[...,-1]
      cm0=nib.load(csf).get_fdata(); ccf=cm0[...,-1]
   else:
      gmm=gm0; wmm=nib.load(wm).get_fdata(); ccf=nib.load(csf).get_fdata()
  

   pbcf=2.5*gmm+wmm
   msk=np.array((cbf!= 0)&(cbf != np.nan )&(pbcf != np.nan )).astype(int)

   gm1=np.array(gmm>0.8)
   wm1=np.array(wmm>0.8)
   cc1=np.array(ccf>0.8)
   r1=np.array([0,np.corrcoef(cbf[msk==1],pbcf[msk==1])[1,0]]).max()
   
   V=((np.sum(gm1)-1)*np.var(cbf[gm1>0])+(np.sum(wm1)-1)*np.var(cbf[wm1>0])+(np.sum(cc1)-1)*np.var(cbf[cc1>0])) \
         /(np.sum(gm1>0)+np.sum(wm1>0)+np.sum(cc1>0)-3)
    
   negGM=np.sum(cbf[gm1]<0)/(np.sum(gm1))
   GMCBF=np.mean(cbf[gm1])
   CV=V/np.abs(GMCBF)
   Q = [fun1(x1,CV),fun1(x2,negGM),fun2(x4,r1)]
   np.savetxt(out3,[gmean(Q)],delimiter='\t',fmt="%5.5f")

 