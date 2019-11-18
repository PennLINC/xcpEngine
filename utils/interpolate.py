#!/usr/bin/env python
# -*- coding: utf-8 -*-
# emacs: -*- mode: python; py-indent-offset: 4; indent-tabs-mode: nil -*-
# vi: set ft=python sts=4 ts=4 sw=4 et:
from argparse import (ArgumentParser, RawTextHelpFormatter)
import numpy as np
import nibabel as nib

def get_parser():

    parser = ArgumentParser(
        formatter_class=RawTextHelpFormatter,
        description='Interpolate data in an unevenly sampled '
                    '4-dimensional time series using least '
                    '\nsquares spectral analysis based on the '
                    'Lomb-Scargle periodogram. This functionality '
                    '\nis useful for interpolating over censored '
                    'epochs before applying a temporal filter. '
                    '\nIf you use this code in your paper, cite '
                    'Power et al., 2014: '
                    '\nhttps://www.ncbi.nlm.nih.gov/pubmed/23994314 ')
    parser.add_argument(
        '-i', '--img', action='store', required=True,
        help='[required]'
             '\nPath to the 4D timeseries to be masked and interpolated.')
    parser.add_argument(
        '-o', '--out', action='store', required=True,
        help='[required]'
             '\nOutput path.')
    parser.add_argument(
        '-t', '--tmask', action='store', required=True,
        help='[required]'
             '\nTemporal mask indicating whether each volume is seen or '
             '\nunseen. For instance, 1 could indicate that a volume '
             '\nshould be retained, while 0 would indicate that the '
             '\nvolume should be censored.')
    parser.add_argument(
        '-m', '--mask', action='store',
        help='\nSpatial mask indicating the voxels of the input image '
             '\nto which the interpolation should be applied.')
    parser.add_argument(
        '-a', '--reptime', action='store',
        help='\nrepitiion time.'
             '\nto which the interpolation should be applied.')
    parser.add_argument(
        '-s', '--ofreq', action='store', default=8, type=float,
        help='[default 8]'
             '\nOversampling frequency; a value of at least 4 is '
             '\nrecommended')
    parser.add_argument(
        '-f', '--hifreq', action='store', default=1, type=float,
        help='[default 1 : Nyquist]'
             '\nThe maximum frequency permitted, as a fraction of the '
             '\nNyquist frequency')
    parser.add_argument(
        '-v', '--voxbin', action='store', default=3000, type=int,
        help='[default 5000]'
             '\nNumber of voxels to transform at one time; a higher '
             '\nnumber increases computational speed but also increases '
             '\nmemory usage')
    
    return parser


opts            =   get_parser().parse_args()
print(opts.img)

img             =   nib.load(opts.img)
#t_rep           =   img.header['pixdim'][4]
t_rep=np.asarray(opts.reptime, dtype='float64')
mask = nib.load(opts.mask)
mask_data       =   mask.get_fdata()
logmask         =   np.isclose(mask_data, 1)
img_data            =   img.get_fdata()
img_data            =   img_data[logmask]
nvox                =   img_data.shape[0]
nvol                =   img_data.shape[1]




tmask  = np.loadtxt(opts.tmask) 
indices = tmask.shape[-1]
t_obs=np.array(np.where(tmask==1))

tmask2=np.where(tmask==1)
    ##########################################################################
    # Total timespan of seen observations, in seconds
    ##########################################################################
seen_samples            =   (t_obs + 1) * t_rep
timespan                =   np.max(seen_samples) - np.min(seen_samples)
if timespan == 0:
     img_data1            =   img.get_fdata()
     img_out2        =   nib.Nifti1Image(dataobj=img_data1,
                                                affine=img.affine,
                                                header=img.header)
     nib.save(img_out2, opts.out) 
     raise ValueError('Only one volume is flagged.')

n_samples_seen          =   seen_samples.shape[-1]
if n_samples_seen == nvol:
     raise ValueError('No interpolation is necessary for this dataset.')
    ##########################################################################
    # Temoral indices of all observations, seen and unseen
    ##########################################################################
all_samples             =   np.arange(start=t_rep,stop=t_rep*(nvol+1),step=t_rep)
        
    ##########################################################################
    # Calculate sampling frequencies
    ##########################################################################
sampling_frequencies    =   np.arange(
                                    start=1/(timespan*opts.ofreq),
                                    step=1/(timespan*opts.ofreq),
                                    stop=(opts.hifreq*n_samples_seen/
                                        (2*timespan)+
                                        1/(timespan*opts.ofreq)))
    ##########################################################################
    # Angular frequencies
    ##########################################################################
angular_frequencies     =   2 * np.pi * sampling_frequencies
    ##########################################################################
    # Constant offsets
    ##########################################################################
offsets =   np.arctan2(
                    np.sum(
                        np.sin(2*np.outer(angular_frequencies, seen_samples)),
                        1),
                    np.sum(
                        np.cos(2*np.outer(angular_frequencies, seen_samples)),
                        1)
                    ) / (2 * angular_frequencies)
    
    ##########################################################################
    # Prepare sin and cos basis terms
    ##########################################################################
from numpy import matlib 
cosine_term             =   np.cos(np.outer(angular_frequencies, 
                                seen_samples) -
                                matlib.repmat(angular_frequencies*offsets, 
                                    n_samples_seen, 1).T)
sine_term               =   np.sin(np.outer(angular_frequencies, 
                                seen_samples) -
                                matlib.repmat(angular_frequencies*offsets, 
                                    n_samples_seen, 1).T)


n_voxel_bins            =   int(np.ceil(nvox /opts.voxbin))

for current_bin in range(1,n_voxel_bins+2):
    print('Voxel bin ' + str(current_bin) + ' out of ' + 
              str(n_voxel_bins+1))
    
        ######################################################################
        # Extract the seen samples for the current bin
        ######################################################################
    bin_index           =   np.arange(start=(current_bin-1)*(opts.voxbin-1),
                                          stop=current_bin*opts.voxbin)
    bin_index           =   np.intersect1d(bin_index, range(0,nvox))

    voxel_bin           =   img_data[bin_index,:][:,t_obs.ravel()]
   

    n_features              =   voxel_bin.shape[0]
    ##########################################################################
    # Compute the transform from seen data as follows for sin and cos terms:
    # termfinal = sum(termmult,2)./sum(term.^2,2)
    # Compute numerators and denominators, then divide
    ##########################################################################
    
    mult                =   np.zeros(shape=(angular_frequencies.shape[0],
                                                n_samples_seen,
                                                n_features))

    for obs in range(0,n_samples_seen):
             mult[:,obs,:]   = np.outer(cosine_term[:,obs],voxel_bin[:,obs])
            
    numerator           =   np.sum(mult,1)
    denominator         =   np.sum(cosine_term**2,1)
    c                =   (numerator.T/denominator).T
         
    for obs in range(0,n_samples_seen):
             mult[:,obs,:]   = np.outer(sine_term[:,obs],voxel_bin[:,obs])
            
    numerator           =   np.sum(mult,1)
    denominator         =   np.sum(sine_term**2,1)
    s               =   (numerator.T/denominator).T
    
    
    ##########################################################################
    # Interpolate over unseen epochs, reconstruct the time series
    ##########################################################################
    
    term_prod           =   np.sin(np.outer(angular_frequencies, all_samples))
    term_recon          =   np.zeros(shape=(angular_frequencies.shape[0],
                                                nvol,n_features))
    for i in range(angular_frequencies.shape[0]):
            term_recon[i,:,:] = np.outer(term_prod[i,:],s[i,:])

    s_recon          =   np.sum(term_recon,0)

    term_prod           =   np.cos(np.outer(angular_frequencies, all_samples))
    term_recon          =   np.zeros(shape=(angular_frequencies.shape[0],
                                                nvol,n_features))
    for i in range(angular_frequencies.shape[0]):
            term_recon[i,:,:] = np.outer(term_prod[i,:],c[i,:])
    c_recon          =   np.sum(term_recon,0)   
    
    recon                   =   (c_recon + s_recon).T
    del c_recon, s_recon
        
    ##########################################################################
    # Normalise the reconstructed spectrum. This is necessary when the
    # oversampling frequency exceeds 1.
    ##########################################################################
    std_recon               =   np.std(recon,1,ddof=1)
    std_orig                =   np.std(voxel_bin,1,ddof=1)
    norm_fac                =   std_recon/std_orig
    del std_recon, std_orig
    recon                   =   (recon.T/norm_fac).T
    del norm_fac
        ##################################################################
        # Write the current bin into the image matrix. Replace only unseen
        # observations with their interpolated values.
        ######################################################################
    img_data[np.ix_(bin_index,t_obs.ravel())] \
             = recon[:,t_obs.ravel()]
    del recon

img_data_out            =   np.zeros(shape=img.shape)
img_data_out[logmask]   =   img_data
    
img_interpolated        =   nib.Nifti1Image(dataobj=img_data_out,
                                                affine=img.affine,
                                                header=img.header)
nib.save(img_interpolated, opts.out)
