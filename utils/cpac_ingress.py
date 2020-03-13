#!/usr/bin/env python
# -*- coding: utf-8 -*-
# emacs: -*- mode: python; py-indent-offset: 4; indent-tabs-mode: nil -*-
# vi: set ft=python sts=4 ts=4 sw=4 et:

import os,glob, pathlib,shutil
import numpy as np 
import pandas as pd
from argparse import (ArgumentParser, RawTextHelpFormatter)

def get_parser():

    parser = ArgumentParser(
        formatter_class=RawTextHelpFormatter,
        description='ingress cpc'
                    )
    parser.add_argument(
        '-i', '--img', action='store', required=True,
        help='[required]'
             '\nPath of img  .')
    parser.add_argument(
        '-o', '--out', action='store', required=True,
        help='[required]'
             '\nOutput path.')
    return parser


opts            =   get_parser().parse_args()

pp = pathlib.Path(opts.img)
outputdir= opts.out
gendir=str(pp.parents[2]) #central directory 
scandid=pp.parts[-2] # particlular task id 
subjid=pp.parts[-1].split('_')[0] # subject id 



#extract functional and anatomical 
shutil.copyfile(glob.glob(gendir+'/anatomical_brain/'+'*nii.gz')[0],outputdir+'/'+subjid+'_T1wbrain.nii.gz')
shutil.copyfile(glob.glob(gendir+'/anatomical_brain_mask/'+'*nii.gz')[0],outputdir+'/'+subjid+'_T1wmask.nii.gz')
shutil.copyfile(glob.glob(gendir+'/seg_partial_volume_map/'+'*nii.gz')[0],outputdir+'/'+subjid+'_segmentation.nii.gz')

shutil.copyfile(glob.glob(gendir+'/anatomical_to_mni_nonlinear_xfm/'+'*nii.gz')[0],outputdir+'/'+subjid+'_from-T1w_to-MNI_warp.nii.gz')
shutil.copyfile(glob.glob(gendir+'/ants_affine_xfm/'+'*.mat')[0],outputdir+'/'+subjid+'_from-T1w_to-MNI_affine2.mat')
shutil.copyfile(glob.glob(gendir+'/ants_rigid_xfm/'+'*.mat')[0],outputdir+'/'+subjid+'_from-T1w_to-MNI_rigid_affine1.mat')
shutil.copyfile(glob.glob(gendir+'/ants_initial_xfm/'+'*.mat')[0],outputdir+'/'+subjid+'_from-T1w_to-MNI_initial_affine0.mat')

shutil.copyfile(glob.glob(gendir+'/functional_brain_mask/'+scandid+'/*.nii.gz')[0],outputdir+'/'+subjid+scandid+'_brainmask.nii.gz')
shutil.copyfile(glob.glob(gendir+'/mean_functional/'+scandid+'/*.nii.gz')[0],outputdir+'/'+subjid+scandid+'_referenceVolume.nii.gz')
shutil.copyfile(glob.glob(gendir+'/functional_to_anat_linear_xfm/'+scandid+'/*.mat')[0],outputdir+'/'+subjid+scandid+'_from-func_to-T1w_affine.mat')

#regressor

regressor=pd.read_csv(glob.glob(gendir+'/functional_nuisance_regressors/'+scandid+'/'+'/*/*.1D')[0],skiprows=2,sep='\t')
if 'X' in regressor.columns:
    regressor.rename(columns={'# RotY':'rot_y','RotX':'rot_x','RotZ':'rot_z', 'X': 'trans_x', 'Y':'trans_y', 'Z':'trans_z'},inplace=True)
if 'GlobalSignalMean0' in regressor.columns: 
    regressor.rename(columns={'GlobalSignalMean0':'global_signal'},inplace=True)
if 'WhiteMatterMean0' in regressor.columns:
    regressor.rename(columns={'WhiteMatterMean0':'white_matter'},inplace=True)
if 'CerebrospinalFluidMean0' in regressor.columns:
    regressor.rename(columns={'CerebrospinalFluidMean0':'csf'},inplace=True)
if 'aCompCorDetrendPC0' in regressor.columns:
    regressor.rename(columns={'aCompCorDetrendPC0':'a_comp_cor_00','aCompCorDetrendPC1':'a_comp_cor_01','aCompCorDetrendPC2':'a_comp_cor_02',
    'aCompCorDetrendPC3':'a_comp_cor_03','aCompCorDetrendPC4':'a_comp_cor_04'},inplace=True)
if 'tCompCorDetrendPC0' in regressor.columns:
    regressor.rename(columns={'tCompCorDetrendPC0':'t_comp_cor_00','tCompCorDetrendPC1':'t_comp_cor_01','tCompCorDetrendPC2':'t_comp_cor_02',
    'tCompCorDetrendPC3':'t_comp_cor_03','tCompCorDetrendPC4':'t_comp_cor_04'},inplace=True)
# ask for aroma and ICA 
fd=pd.read_csv(glob.glob(gendir+'/frame_wise_displacement_power/'+scandid+'/*.1D')[0],header=None,names=['framewise_displacement'])
regressors=pd.concat([regressor, fd], axis=1)
regressors.to_csv(outputdir+'/'+subjid+'_regressors.tsv',index=False,sep='\t',encoding='utf-8')

# print resampling the T1w to bold 
os.chdir(outputdir)
from niworkflows.interfaces.utils import GenerateSamplingReference
gen=GenerateSamplingReference()
gen.inputs.fixed_image=outputdir+'/'+subjid+'_T1wbrain.nii.gz'
gen.inputs.moving_image=outputdir+'/'+subjid+scandid+'_referenceVolume.nii.gz'
gen.inputs.fov_mask=outputdir+'/'+subjid+'_T1wmask.nii.gz'
gen.inputs.keep_native=True
gen.inputs.xform_code=None
gen.run()

print('done')